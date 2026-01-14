// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Improved Orthogonal Edge Routing
///
/// This module implements orthogonal edge routing with:
/// - Routing slots between layers to avoid edge crossings
/// - Proper bend point calculation
/// - Support for edges spanning multiple layers (via dummy nodes)
///
/// Based on ELK's OrthogonalRoutingGenerator concepts

// ============================================================================
// Improved Orthogonal Routing
// ============================================================================

///|
/// Route edges orthogonally with proper slot assignment
fn route_edges_orthogonal(
  graph : LGraph,
  direction : LayoutDirection,
  edge_spacing : Double,
) -> Unit {
  let is_vertical = direction.is_vertical()

  // Process edges layer by layer
  if is_vertical {
    route_vertical_layout(graph, direction, edge_spacing)
  } else {
    route_horizontal_layout(graph, direction, edge_spacing)
  }
}

///|
/// Route edges for vertical (top-to-bottom) layouts
fn route_vertical_layout(
  graph : LGraph,
  direction : LayoutDirection,
  edge_spacing : Double,
) -> Unit {
  fn default_anchor(
    node : LNode,
    direction : LayoutDirection,
    is_source : Bool,
  ) -> (Double, Double) {
    let cx = node.x + node.width / 2.0
    let cy = node.y + node.height / 2.0
    match direction {
      Down => if is_source { (cx, node.y + node.height) } else { (cx, node.y) }
      Up => if is_source { (cx, node.y) } else { (cx, node.y + node.height) }
      Right => if is_source { (node.x + node.width, cy) } else { (node.x, cy) }
      Left => if is_source { (node.x, cy) } else { (node.x + node.width, cy) }
      Undefined =>
        if is_source {
          (cx, node.y + node.height)
        } else {
          (cx, node.y)
        }
    }
  }

  fn anchor_with_port(
    node : LNode,
    port_id : String?,
    direction : LayoutDirection,
    is_source : Bool,
  ) -> (Double, Double) {
    match port_id {
      Some(pid) => {
        for port in node.ports {
          if port.id == pid {
            let has_size = port.width > 0.0 || port.height > 0.0
            if has_size {
              return (
                node.x + port.x + port.width / 2.0,
                node.y + port.y + port.height / 2.0,
              )
            }
            let has_pos = port.x != 0.0 || port.y != 0.0
            let border = port.properties.get_double_or(
              "diago.layered.portBorderOffset", 0.0,
            )
            let anchor = match port.side {
              North =>
                if has_pos {
                  (node.x + port.x, node.y + border)
                } else {
                  (node.x + node.width / 2.0, node.y + border)
                }
              South =>
                if has_pos {
                  (node.x + port.x, node.y + node.height - border)
                } else {
                  (node.x + node.width / 2.0, node.y + node.height - border)
                }
              West =>
                if has_pos {
                  (node.x + border, node.y + port.y)
                } else {
                  (node.x + border, node.y + node.height / 2.0)
                }
              East =>
                if has_pos {
                  (node.x + node.width - border, node.y + port.y)
                } else {
                  (node.x + node.width - border, node.y + node.height / 2.0)
                }
              _ => (node.x + port.x, node.y + port.y)
            }
            return anchor
          }
        }
        default_anchor(node, direction, is_source)
      }
      None => default_anchor(node, direction, is_source)
    }
  }

  // First, group parallel edges deterministically.
  // Use normalized keys so (A->B) and (B->A) are counted together.
  let edge_groups : Map[String, Array[LEdge]] = {}
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source = graph.get_node(edge.source_id)
    let target = graph.get_node(edge.target_id)
    guard source is Some(src) && target is Some(tgt) else { continue }
    if src.layer == tgt.layer {
      continue
    }
    let key = if edge.source_id < edge.target_id {
      edge.source_id + "->" + edge.target_id
    } else {
      edge.target_id + "->" + edge.source_id
    }
    if !edge_groups.contains(key) {
      edge_groups[key] = []
    }
    match edge_groups.get(key) {
      Some(arr) => arr.push(edge)
      None => ()
    }
  }
  let parallel_count_by_key : Map[String, Int] = {}
  let parallel_index_by_edge : Map[String, Int] = {}
  for key, edges in edge_groups {
    edges.sort_by(fn(a, b) { a.id.compare(b.id) })
    parallel_count_by_key[key] = edges.length()
    for i, e in edges {
      parallel_index_by_edge[e.id] = i
    }
  }
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source = graph.get_node(edge.source_id)
    let target = graph.get_node(edge.target_id)
    guard source is Some(src) && target is Some(tgt) else { continue }

    // Skip edges within the same layer
    if src.layer == tgt.layer {
      continue
    }

    // Clear existing bend points
    edge.bend_points.clear()

    // Calculate source and target connection points (from ports if present)
    let (src_x, src_y) = anchor_with_port(
      src,
      edge.source_port_id,
      direction,
      true,
    )
    let (tgt_x, tgt_y) = anchor_with_port(
      tgt,
      edge.target_port_id,
      direction,
      false,
    )

    // Deterministic parallel edge index using normalized key.
    let key = if edge.source_id < edge.target_id {
      edge.source_id + "->" + edge.target_id
    } else {
      edge.target_id + "->" + edge.source_id
    }
    let parallel_count = parallel_count_by_key.get(key).unwrap_or(1)
    let parallel_index = parallel_index_by_edge.get(edge.id).unwrap_or(0)

    // Calculate offset for parallel edges - ALWAYS non-zero for parallel edges
    // This ensures all parallel edges have distinct routes from start to end
    let parallel_offset = if parallel_count > 1 {
      // Use alternating offsets that are always non-zero
      // Sequence: -0.5*spacing, +0.5*spacing, -1.5*spacing, +1.5*spacing, ...
      let half_spacing = edge_spacing / 2.0
      let slot = (parallel_index / 2).to_double() + 0.5
      if parallel_index % 2 == 0 {
        -slot * half_spacing
      } else {
        slot * half_spacing
      }
    } else {
      0.0
    }

    // Store the parallel offset so apply_to_elk_graph can use it for start/end points
    edge.parallel_offset = parallel_offset

    // Calculate routing
    if (src_x - tgt_x).abs() < 1.0 && parallel_count == 1 {
      // Nodes are aligned and single edge - straight edge, no bend points needed
      // Bend points will be empty, edge goes straight
    } else {
      // Need orthogonal routing with bends
      // Find midpoint Y between layers
      let mid_y = (src_y + tgt_y) / 2.0

      // For aligned nodes with parallel edges, create a detour with X offset
      if (src_x - tgt_x).abs() < 1.0 {
        // Parallel edge on aligned nodes - route with horizontal offset
        // Create a route that doesn't share start/end with other parallel edges
        // Start vertical segment offset from center
        edge.bend_points.push(ElkPoint::new(src_x + parallel_offset, src_y))
        edge.bend_points.push(ElkPoint::new(src_x + parallel_offset, tgt_y))
      } else {
        // Non-aligned nodes - Z-shape routing
        // Apply offset to the horizontal segment's Y position for parallel edges
        let offset_mid_y = mid_y + parallel_offset
        edge.bend_points.push(
          ElkPoint::new(src_x + parallel_offset, offset_mid_y),
        )
        edge.bend_points.push(
          ElkPoint::new(tgt_x + parallel_offset, offset_mid_y),
        )
      }
    }
  }

  // Assign routing slots to avoid overlaps
  assign_routing_slots(graph, edge_spacing, true)
}

///|
/// Route edges for horizontal (left-to-right) layouts
fn route_horizontal_layout(
  graph : LGraph,
  direction : LayoutDirection,
  edge_spacing : Double,
) -> Unit {
  fn default_anchor(
    node : LNode,
    direction : LayoutDirection,
    is_source : Bool,
  ) -> (Double, Double) {
    let cx = node.x + node.width / 2.0
    let cy = node.y + node.height / 2.0
    match direction {
      Down => if is_source { (cx, node.y + node.height) } else { (cx, node.y) }
      Up => if is_source { (cx, node.y) } else { (cx, node.y + node.height) }
      Right => if is_source { (node.x + node.width, cy) } else { (node.x, cy) }
      Left => if is_source { (node.x, cy) } else { (node.x + node.width, cy) }
      Undefined =>
        if is_source {
          (node.x + node.width, cy)
        } else {
          (node.x, cy)
        }
    }
  }

  fn anchor_with_port(
    node : LNode,
    port_id : String?,
    direction : LayoutDirection,
    is_source : Bool,
  ) -> (Double, Double) {
    match port_id {
      Some(pid) => {
        for port in node.ports {
          if port.id == pid {
            let has_size = port.width > 0.0 || port.height > 0.0
            if has_size {
              return (
                node.x + port.x + port.width / 2.0,
                node.y + port.y + port.height / 2.0,
              )
            }
            let has_pos = port.x != 0.0 || port.y != 0.0
            let border = port.properties.get_double_or(
              "diago.layered.portBorderOffset", 0.0,
            )
            let anchor = match port.side {
              North =>
                if has_pos {
                  (node.x + port.x, node.y + border)
                } else {
                  (node.x + node.width / 2.0, node.y + border)
                }
              South =>
                if has_pos {
                  (node.x + port.x, node.y + node.height - border)
                } else {
                  (node.x + node.width / 2.0, node.y + node.height - border)
                }
              West =>
                if has_pos {
                  (node.x + border, node.y + port.y)
                } else {
                  (node.x + border, node.y + node.height / 2.0)
                }
              East =>
                if has_pos {
                  (node.x + node.width - border, node.y + port.y)
                } else {
                  (node.x + node.width - border, node.y + node.height / 2.0)
                }
              _ => (node.x + port.x, node.y + port.y)
            }
            return anchor
          }
        }
        default_anchor(node, direction, is_source)
      }
      None => default_anchor(node, direction, is_source)
    }
  }

  // Deterministic parallel edge grouping.
  // Use normalized keys so (A->B) and (B->A) are counted together.
  let edge_groups : Map[String, Array[LEdge]] = {}
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source = graph.get_node(edge.source_id)
    let target = graph.get_node(edge.target_id)
    guard source is Some(src) && target is Some(tgt) else { continue }
    if src.layer == tgt.layer {
      continue
    }
    let key = if edge.source_id < edge.target_id {
      edge.source_id + "->" + edge.target_id
    } else {
      edge.target_id + "->" + edge.source_id
    }
    if !edge_groups.contains(key) {
      edge_groups[key] = []
    }
    match edge_groups.get(key) {
      Some(arr) => arr.push(edge)
      None => ()
    }
  }
  let parallel_count_by_key : Map[String, Int] = {}
  let parallel_index_by_edge : Map[String, Int] = {}
  for key, edges in edge_groups {
    edges.sort_by(fn(a, b) { a.id.compare(b.id) })
    parallel_count_by_key[key] = edges.length()
    for i, e in edges {
      parallel_index_by_edge[e.id] = i
    }
  }
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source = graph.get_node(edge.source_id)
    let target = graph.get_node(edge.target_id)
    guard source is Some(src) && target is Some(tgt) else { continue }

    // Skip edges within the same layer
    if src.layer == tgt.layer {
      continue
    }

    // Clear existing bend points
    edge.bend_points.clear()

    // Calculate source and target connection points (from ports if present)
    let (src_x, src_y) = anchor_with_port(
      src,
      edge.source_port_id,
      direction,
      true,
    )
    let (tgt_x, tgt_y) = anchor_with_port(
      tgt,
      edge.target_port_id,
      direction,
      false,
    )
    let key = if edge.source_id < edge.target_id {
      edge.source_id + "->" + edge.target_id
    } else {
      edge.target_id + "->" + edge.source_id
    }
    let parallel_count = parallel_count_by_key.get(key).unwrap_or(1)
    let parallel_index = parallel_index_by_edge.get(edge.id).unwrap_or(0)
    let parallel_offset = if parallel_count > 1 {
      let half_spacing = edge_spacing / 2.0
      let slot = (parallel_index / 2).to_double() + 0.5
      if parallel_index % 2 == 0 {
        -slot * half_spacing
      } else {
        slot * half_spacing
      }
    } else {
      0.0
    }
    edge.parallel_offset = parallel_offset

    // Calculate routing
    if (src_y - tgt_y).abs() < 1.0 && parallel_count == 1 {
      // Nodes are aligned and single edge - straight edge.
    } else if (src_y - tgt_y).abs() < 1.0 {
      // Aligned nodes with parallel edges: detour with Y offset.
      edge.bend_points.push(ElkPoint::new(src_x, src_y + parallel_offset))
      edge.bend_points.push(ElkPoint::new(tgt_x, tgt_y + parallel_offset))
    } else {
      // Need orthogonal routing.
      let mid_x = (src_x + tgt_x) / 2.0
      edge.bend_points.push(ElkPoint::new(mid_x, src_y + parallel_offset))
      edge.bend_points.push(ElkPoint::new(mid_x, tgt_y + parallel_offset))
    }
  }
  assign_routing_slots(graph, edge_spacing, false)
}

///|
/// Assign routing slots to edges to minimize crossings
fn assign_routing_slots(
  graph : LGraph,
  edge_spacing : Double,
  is_vertical : Bool,
) -> Unit {
  // Pre-compute source positions for sorting
  let edge_sort_keys : Map[String, Double] = {}
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    match graph.get_node(edge.source_id) {
      Some(src) =>
        if is_vertical {
          edge_sort_keys[edge.id] = src.x + src.width / 2.0
        } else {
          edge_sort_keys[edge.id] = src.y + src.height / 2.0
        }
      None => ()
    }
  }

  // Group edges by the layer pair they cross
  let layer_edges : Map[String, Array[LEdge]] = {}
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let src_node = graph.get_node(edge.source_id)
    let tgt_node = graph.get_node(edge.target_id)
    guard src_node is Some(src) && tgt_node is Some(tgt) else { continue }
    if src.layer != tgt.layer {
      let key = src.layer.to_string() + "_" + tgt.layer.to_string()
      if !layer_edges.contains(key) {
        layer_edges[key] = []
      }
      match layer_edges.get(key) {
        Some(arr) => arr.push(edge)
        None => ()
      }
    }
  }

  // For each layer pair, assign slots to avoid crossings
  for pair in layer_edges.iter() {
    let (_, edges) = pair
    if edges.length() <= 1 {
      continue
    }

    // Sort edges by their source position to minimize crossings
    edges.sort_by(fn(a, b) {
      let a_key = edge_sort_keys.get(a.id).unwrap_or(0.0)
      let b_key = edge_sort_keys.get(b.id).unwrap_or(0.0)
      if a_key < b_key {
        -1
      } else if a_key > b_key {
        1
      } else {
        a.id.compare(b.id)
      }
    })

    // Adjust bend points to use different routing slots
    // Use alternating offsets (0, -0.5, +0.5, -1.0, +1.0, ...) * edge_spacing.
    for i, edge in edges {
      if edge.bend_points.length() >= 2 {
        let offset = if i == 0 {
          0.0
        } else {
          let slot = ((i + 1) / 2).to_double() * edge_spacing * 0.5
          let sign = if i % 2 == 1 { -1.0 } else { 1.0 }
          sign * slot
        }
        // Create new bend points with adjusted coordinates
        let new_bends : Array[ElkPoint] = []
        for bp in edge.bend_points {
          if is_vertical {
            // Shift horizontal segment vertically
            new_bends.push(ElkPoint::new(bp.x, bp.y + offset))
          } else {
            // Shift vertical segment horizontally
            new_bends.push(ElkPoint::new(bp.x + offset, bp.y))
          }
        }
        // Replace bend points
        edge.bend_points.clear()
        for bp in new_bends {
          edge.bend_points.push(bp)
        }
      }
    }
  }
}

// ============================================================================
// Self-Loop Routing
// ============================================================================

///|
/// Route self-loop edges on the given edge list.
fn route_self_loop_edges(
  graph : LGraph,
  edges : Array[LEdge],
  _direction : LayoutDirection,
) -> Unit {
  for edge in edges {
    if edge.source_id != edge.target_id {
      continue
    }
    match graph.get_node(edge.source_id) {
      Some(node) => {
        edge.bend_points.clear()

        // Route around the right side of the node.
        // Use parallel_offset (assigned by SELF_LOOP_ROUTER) to avoid overlap.
        let right_x = node.x + node.width + 20.0 + edge.parallel_offset
        let top_y = node.y
        let bottom_y = node.y + node.height

        // Create loop path: bottom-right, bottom-out, top-out, top-right.
        edge.bend_points.push(ElkPoint::new(node.x + node.width, bottom_y))
        edge.bend_points.push(ElkPoint::new(right_x, bottom_y))
        edge.bend_points.push(ElkPoint::new(right_x, top_y))
        edge.bend_points.push(ElkPoint::new(node.x + node.width, top_y))
      }
      None => ()
    }
  }
}

///|
/// Route self-loop edges present in the graph.
fn route_self_loops(graph : LGraph, direction : LayoutDirection) -> Unit {
  route_self_loop_edges(graph, graph.edges, direction)
}

// ============================================================================
// Edge Straightening
// ============================================================================

///|
/// Straighten edges by removing unnecessary bend points
fn straighten_edges(graph : LGraph) -> Unit {
  for edge in graph.edges {
    if edge.bend_points.length() < 2 {
      continue
    }

    // Remove collinear bend points
    let new_bends : Array[ElkPoint] = []
    let mut prev : ElkPoint? = None
    for bp in edge.bend_points {
      match prev {
        Some(p) =>
          // Check if this point is collinear with the previous segment
          if new_bends.length() > 0 {
            let last = new_bends[new_bends.length() - 1]
            // Check if all three points are collinear
            if !is_collinear(last, p, bp) {
              new_bends.push(p)
            }
          } else {
            new_bends.push(p)
          }
        None => ()
      }
      prev = Some(bp)
    }

    // Add the last point if needed
    match prev {
      Some(p) => new_bends.push(p)
      None => ()
    }

    // Update bend points
    edge.bend_points.clear()
    for bp in new_bends {
      edge.bend_points.push(bp)
    }
  }
}

///|
/// Check if three points are collinear
fn is_collinear(p1 : ElkPoint, p2 : ElkPoint, p3 : ElkPoint) -> Bool {
  let dx1 = p2.x - p1.x
  let dy1 = p2.y - p1.y
  let dx2 = p3.x - p2.x
  let dy2 = p3.y - p2.y

  // Check if the cross product is approximately zero
  let cross = dx1 * dy2 - dy1 * dx2
  cross.abs() < 0.001
}
