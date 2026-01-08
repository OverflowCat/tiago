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

// ============================================================================
// Port Assignment Phase
// ============================================================================
//
// This phase assigns ports (connection points) to edges BEFORE edge routing.
// By determining connection sides proactively, we can guarantee:
// 1. Edges connect perpendicular to node boundaries
// 2. Multiple edges on the same node side are evenly distributed
// 3. Consistent behavior across all routing code paths

///|
/// Assign ports for all edges in the graph
/// Called after positioning (Phase 5/6), before routing (Phase 7)
pub fn assign_ports(
  graph : @graph.Graph,
  layers : Array[Array[String]],
  _config : LayoutConfig,
) -> Unit {
  // Build layer index for each node
  let layer_idx : Map[String, Int] = {}
  for i, layer in layers {
    for node in layer {
      layer_idx[node] = i
    }
  }
  // Step 1: For each edge, determine which side it connects to on each node
  for edge in graph.edges {
    let src_obj = graph.find_object(edge.src_id)
    let dst_obj = graph.find_object(edge.dst_id)
    match (src_obj, dst_obj) {
      (Some(src), Some(dst)) => {
        let src_layer = layer_idx.get(edge.src_id).unwrap_or(0)
        let dst_layer = layer_idx.get(edge.dst_id).unwrap_or(0)
        // Determine port sides based on layer relationship
        let (src_side, dst_side) = determine_port_sides(
          src, dst, src_layer, dst_layer,
        )
        // Create ports with initial position (will be adjusted later)
        edge.src_port = Some(@graph.Port::new(src_side, 0.5))
        edge.dst_port = Some(@graph.Port::new(dst_side, 0.5))
      }
      _ => ()
    }
  }
  // Step 2: Group edges by node and side, then distribute positions
  distribute_ports_on_nodes(graph)
  // Step 2.5: Distribute parallel edge ports (edges between same src/dst pair)
  distribute_parallel_edge_ports(graph)
  // Step 3: Compute absolute coordinates for each port
  compute_port_coordinates(graph)
}

///|
/// Determine which sides the edge should connect to based on layer positions
/// In Sugiyama layout, edges typically go from bottom of source to top of destination
fn determine_port_sides(
  src : @graph.Object,
  dst : @graph.Object,
  src_layer : Int,
  dst_layer : Int,
) -> (@graph.PortSide, @graph.PortSide) {
  match (src.box, dst.box) {
    (Some(src_box), Some(dst_box)) =>
      if src_layer < dst_layer {
        // Source is above destination (normal downward flow)
        // Source connects from BOTTOM, destination connects from TOP
        (@graph.Bottom, @graph.Top)
      } else if src_layer > dst_layer {
        // Source is below destination (upward edge, reversed)
        // Source connects from TOP, destination connects from BOTTOM
        (@graph.Top, @graph.Bottom)
      } else {
        // Same layer - use horizontal connection based on x-position
        let src_cx = src_box.x + src_box.width / 2.0
        let dst_cx = dst_box.x + dst_box.width / 2.0
        if src_cx < dst_cx {
          // Source is to the left
          (@graph.Right, @graph.Left)
        } else {
          (
            // Source is to the right
            @graph.Left,
            @graph.Right,
          )
        }
      }
    _ =>
      // Fallback: use bottom/top for missing boxes
      (@graph.Bottom, @graph.Top)
  }
}

///|
/// Group edges by their endpoint nodes and distribute port positions evenly
fn distribute_ports_on_nodes(graph : @graph.Graph) -> Unit {
  // Build map of (node_id, side) -> list of edges
  // For source side
  let src_edges : Map[String, Array[@graph.Edge]] = {}
  // For destination side
  let dst_edges : Map[String, Array[@graph.Edge]] = {}
  for edge in graph.edges {
    match edge.src_port {
      Some(port) => {
        let key = edge.src_id + "_" + port_side_to_string(port.side)
        match src_edges.get(key) {
          Some(arr) => arr.push(edge)
          None => src_edges[key] = [edge]
        }
      }
      None => ()
    }
    match edge.dst_port {
      Some(port) => {
        let key = edge.dst_id + "_" + port_side_to_string(port.side)
        match dst_edges.get(key) {
          Some(arr) => arr.push(edge)
          None => dst_edges[key] = [edge]
        }
      }
      None => ()
    }
  }
  // Distribute source ports
  for entry in src_edges {
    let edges = entry.1
    if edges.length() <= 1 {
      continue
    }
    // Sort edges by destination x-position for consistent ordering
    let sorted_edges = sort_edges_by_dst_x(edges, graph)
    distribute_port_positions_src(sorted_edges, edges.length())
  }
  // Distribute destination ports
  for entry in dst_edges {
    let edges = entry.1
    if edges.length() <= 1 {
      continue
    }
    // Sort edges by source x-position for consistent ordering
    let sorted_edges = sort_edges_by_src_x(edges, graph)
    distribute_port_positions_dst(sorted_edges, edges.length())
  }
}

///|
/// Convert port side to string for map keys
fn port_side_to_string(side : @graph.PortSide) -> String {
  match side {
    @graph.Top => "top"
    @graph.Bottom => "bottom"
    @graph.Left => "left"
    @graph.Right => "right"
  }
}

///|
/// Sort edges by destination x-coordinate
fn sort_edges_by_dst_x(
  edges : Array[@graph.Edge],
  graph : @graph.Graph,
) -> Array[@graph.Edge] {
  let result = edges.copy()
  // Insertion sort by destination x
  for i = 1; i < result.length(); i = i + 1 {
    let key = result[i]
    let key_x = get_obj_center_x(graph, key.dst_id)
    let mut j = i - 1
    while j >= 0 {
      let j_x = get_obj_center_x(graph, result[j].dst_id)
      if j_x > key_x {
        result[j + 1] = result[j]
        j = j - 1
      } else {
        break
      }
    }
    result[j + 1] = key
  }
  result
}

///|
/// Sort edges by source x-coordinate
fn sort_edges_by_src_x(
  edges : Array[@graph.Edge],
  graph : @graph.Graph,
) -> Array[@graph.Edge] {
  let result = edges.copy()
  // Insertion sort by source x
  for i = 1; i < result.length(); i = i + 1 {
    let key = result[i]
    let key_x = get_obj_center_x(graph, key.src_id)
    let mut j = i - 1
    while j >= 0 {
      let j_x = get_obj_center_x(graph, result[j].src_id)
      if j_x > key_x {
        result[j + 1] = result[j]
        j = j - 1
      } else {
        break
      }
    }
    result[j + 1] = key
  }
  result
}

///|
/// Get the x-coordinate of an object's center
fn get_obj_center_x(graph : @graph.Graph, id : String) -> Double {
  match graph.find_object(id) {
    Some(obj) =>
      match obj.box {
        Some(b) => b.x + b.width / 2.0
        None => 0.0
      }
    None => 0.0
  }
}

///|
/// Distribute port positions evenly along the side for source ports
fn distribute_port_positions_src(
  edges : Array[@graph.Edge],
  count : Int,
) -> Unit {
  for i, edge in edges {
    match edge.src_port {
      Some(port) => {
        // Distribute from 0.2 to 0.8 to leave margins
        let position = 0.2 + 0.6 * i.to_double() / (count - 1).to_double()
        edge.src_port = Some(@graph.Port::new(port.side, position))
      }
      None => ()
    }
  }
}

///|
/// Distribute port positions evenly along the side for destination ports
fn distribute_port_positions_dst(
  edges : Array[@graph.Edge],
  count : Int,
) -> Unit {
  for i, edge in edges {
    match edge.dst_port {
      Some(port) => {
        // Distribute from 0.2 to 0.8 to leave margins
        let position = 0.2 + 0.6 * i.to_double() / (count - 1).to_double()
        edge.dst_port = Some(@graph.Port::new(port.side, position))
      }
      None => ()
    }
  }
}

///|
/// Distribute port positions for parallel edges (edges between same src/dst pair)
/// This ensures multiple edges between the same nodes get different port positions
fn distribute_parallel_edge_ports(graph : @graph.Graph) -> Unit {
  // Group edges by normalized (src, dst) pair
  let edge_groups : Map[String, Array[@graph.Edge]] = {}
  for edge in graph.edges {
    // Create normalized key (smaller id first)
    let key = if edge.src_id < edge.dst_id {
      edge.src_id + "->" + edge.dst_id
    } else {
      edge.dst_id + "->" + edge.src_id
    }
    match edge_groups.get(key) {
      Some(arr) => arr.push(edge)
      None => edge_groups[key] = [edge]
    }
  }

  // For each group with multiple edges, distribute port positions
  for group in edge_groups.values() {
    if group.length() <= 1 {
      continue
    }

    // Sort by edge index for deterministic ordering
    group.sort_by(fn(a, b) { a.index.compare(b.index) })

    // Distribute port positions for both src and dst sides
    let count = group.length()
    for i, edge in group {
      // Calculate offset from center (0.5)
      // For 2 edges: 0.35, 0.65
      // For 3 edges: 0.25, 0.50, 0.75
      let position = if count == 1 {
        0.5
      } else {
        0.25 + 0.5 * i.to_double() / (count - 1).to_double()
      }

      // Update source port position (keep same side)
      match edge.src_port {
        Some(port) =>
          edge.src_port = Some(@graph.Port::new(port.side, position))
        None => ()
      }

      // Update destination port position (keep same side)
      match edge.dst_port {
        Some(port) =>
          edge.dst_port = Some(@graph.Port::new(port.side, position))
        None => ()
      }
    }
  }
}

///|
/// Compute absolute coordinates for each port based on node boxes
fn compute_port_coordinates(graph : @graph.Graph) -> Unit {
  for edge in graph.edges {
    // Compute source port coordinates
    match (edge.src_port, graph.find_object(edge.src_id)) {
      (Some(port), Some(obj)) =>
        match obj.box {
          Some(box) => {
            let point = compute_port_point(box, port.side, port.position)
            port.point = Some(point)
          }
          None => ()
        }
      _ => ()
    }
    // Compute destination port coordinates
    match (edge.dst_port, graph.find_object(edge.dst_id)) {
      (Some(port), Some(obj)) =>
        match obj.box {
          Some(box) => {
            let point = compute_port_point(box, port.side, port.position)
            port.point = Some(point)
          }
          None => ()
        }
      _ => ()
    }
  }
}

///|
/// Compute the absolute point for a port on a box
fn compute_port_point(
  box : @graph.Box,
  side : @graph.PortSide,
  position : Double,
) -> @graph.Point {
  match side {
    @graph.Top => {
      // Position along top edge (left to right)
      let x = box.x + box.width * position
      @graph.Point::new(x, box.y)
    }
    @graph.Bottom => {
      // Position along bottom edge (left to right)
      let x = box.x + box.width * position
      @graph.Point::new(x, box.y + box.height)
    }
    @graph.Left => {
      // Position along left edge (top to bottom)
      let y = box.y + box.height * position
      @graph.Point::new(box.x, y)
    }
    @graph.Right => {
      // Position along right edge (top to bottom)
      let y = box.y + box.height * position
      @graph.Point::new(box.x + box.width, y)
    }
  }
}

///|
/// Fix perpendicularity of edge connections after all post-processing
/// This ensures the first and last segments are perpendicular to node boundaries
pub fn fix_perpendicularity(graph : @graph.Graph) -> Unit {
  for edge in graph.edges {
    if edge.route.length() < 2 {
      continue
    }
    // Fix source perpendicularity
    fix_source_perpendicularity(edge, graph)
    // Fix destination perpendicularity
    fix_dest_perpendicularity(edge, graph)
  }
}

///|
/// Fix the first segment to be perpendicular to the source node boundary
/// Strategy: Insert waypoint to create perpendicular first segment
/// For left/right sides: insert waypoint at (p1.x, p0.y) for horizontal first segment
/// For top/bottom sides: insert waypoint at (p0.x, p1.y) for vertical first segment
fn fix_source_perpendicularity(
  edge : @graph.Edge,
  graph : @graph.Graph,
) -> Unit {
  let src_obj = graph.find_object(edge.src_id)
  guard src_obj is Some(obj) else { return }
  guard obj.box is Some(box) else { return }
  guard edge.route.length() >= 2 else { return }
  let p0 = edge.route[0]
  let p1 = edge.route[1]
  let tolerance = 2.0
  // Determine which side p0 is on
  let on_left = (p0.x - box.x).abs() < tolerance
  let on_right = (p0.x - (box.x + box.width)).abs() < tolerance
  let on_top = (p0.y - box.y).abs() < tolerance
  let on_bottom = (p0.y - (box.y + box.height)).abs() < tolerance
  let on_vertical_side = on_left || on_right
  let on_horizontal_side = on_top || on_bottom
  // Check segment direction
  let dx = (p1.x - p0.x).abs()
  let dy = (p1.y - p0.y).abs()
  let is_horizontal = dy < tolerance && dx > tolerance
  let is_vertical = dx < tolerance && dy > tolerance
  // If on vertical side (left/right) and segment is not horizontal, add waypoint
  if on_vertical_side && !is_horizontal {
    // Insert waypoint at (p1.x, p0.y) to create horizontal first segment
    let waypoint = @graph.Point::new(p1.x, p0.y)
    let too_close_p0 = points_approximately_equal(waypoint, p0, tolerance)
    let too_close_p1 = points_approximately_equal(waypoint, p1, tolerance)
    if !too_close_p0 && !too_close_p1 {
      insert_waypoint_at(edge, 1, waypoint)
    } else if too_close_p0 {
      // Vertical segment from vertical side - need to step away first
      // Insert TWO waypoints: first step horizontal, then vertical
      let step = 20.0
      let step_x = if on_right { p0.x + step } else { p0.x - step }
      let w1 = @graph.Point::new(step_x, p0.y) // go horizontal from source
      let w2 = @graph.Point::new(step_x, p1.y) // go vertical
      // Insert in reverse order so they end up: p0 → w1 → w2 → p1 → ...
      insert_waypoint_at(edge, 1, w2)
      insert_waypoint_at(edge, 1, w1)
    }
  } else if on_horizontal_side && !is_vertical {
    // Insert waypoint at (p0.x, p1.y) to create vertical first segment
    let waypoint = @graph.Point::new(p0.x, p1.y)
    let too_close_p0 = points_approximately_equal(waypoint, p0, tolerance)
    let too_close_p1 = points_approximately_equal(waypoint, p1, tolerance)
    if !too_close_p0 && !too_close_p1 {
      insert_waypoint_at(edge, 1, waypoint)
    } else if too_close_p0 {
      // Horizontal segment from horizontal side - need to step away first
      // Insert TWO waypoints: first step perpendicular, then horizontal
      let step = 20.0
      let step_y = if on_bottom { p0.y + step } else { p0.y - step }
      let w1 = @graph.Point::new(p0.x, step_y) // go vertical from source
      let w2 = @graph.Point::new(p1.x, step_y) // go horizontal
      // Insert in reverse order so they end up: p0 → w1 → w2 → p1 → ...
      insert_waypoint_at(edge, 1, w2)
      insert_waypoint_at(edge, 1, w1)
    }
  }
}

///|
/// Fix the last segment to be perpendicular to the destination node boundary
/// Strategy: Insert waypoint to create perpendicular last segment
/// For left/right sides: insert waypoint at (p1.x, p0.y) for horizontal last segment
/// For top/bottom sides: insert waypoint at (p0.x, p1.y) for vertical last segment
fn fix_dest_perpendicularity(edge : @graph.Edge, graph : @graph.Graph) -> Unit {
  let dst_obj = graph.find_object(edge.dst_id)
  guard dst_obj is Some(obj) else { return }
  guard obj.box is Some(box) else { return }
  guard edge.route.length() >= 2 else { return }
  let last_idx = edge.route.length() - 1
  let p0 = edge.route[last_idx - 1]
  let p1 = edge.route[last_idx]
  let tolerance = 2.0
  // Determine which side p1 is on
  let on_left = (p1.x - box.x).abs() < tolerance
  let on_right = (p1.x - (box.x + box.width)).abs() < tolerance
  let on_top = (p1.y - box.y).abs() < tolerance
  let on_bottom = (p1.y - (box.y + box.height)).abs() < tolerance
  let on_vertical_side = on_left || on_right
  let on_horizontal_side = on_top || on_bottom
  // Check segment direction
  let dx = (p1.x - p0.x).abs()
  let dy = (p1.y - p0.y).abs()
  let is_horizontal = dy < tolerance && dx > tolerance
  let is_vertical = dx < tolerance && dy > tolerance
  // If on vertical side (left/right) and segment is not horizontal, add waypoint
  if on_vertical_side && !is_horizontal {
    // Insert waypoint at (p0.x, p1.y) to create horizontal last segment
    // Segment from (p0.x, p1.y) to (p1.x, p1.y) is horizontal
    let waypoint = @graph.Point::new(p0.x, p1.y)
    let too_close_p0 = points_approximately_equal(waypoint, p0, tolerance)
    let too_close_p1 = points_approximately_equal(waypoint, p1, tolerance)
    if !too_close_p0 && !too_close_p1 {
      insert_waypoint_at(edge, last_idx, waypoint)
    } else if too_close_p1 {
      // Vertical segment to vertical side - need to step away first
      // Insert TWO waypoints: vertical detour, then horizontal approach
      let step = 20.0
      let step_x = if on_right { p1.x + step } else { p1.x - step }
      let w1 = @graph.Point::new(step_x, p0.y) // vertical from prev
      let w2 = @graph.Point::new(step_x, p1.y) // then horizontal to dest
      // Insert: ... → p0 → w1 → w2 → p1
      insert_waypoint_at(edge, last_idx, w2)
      insert_waypoint_at(edge, last_idx, w1)
    }
  } else if on_horizontal_side && !is_vertical {
    // Insert waypoint at (p1.x, p0.y) to create vertical last segment
    // Segment from (p1.x, p0.y) to (p1.x, p1.y) is vertical
    let waypoint = @graph.Point::new(p1.x, p0.y)
    let too_close_p0 = points_approximately_equal(waypoint, p0, tolerance)
    let too_close_p1 = points_approximately_equal(waypoint, p1, tolerance)
    if !too_close_p0 && !too_close_p1 {
      insert_waypoint_at(edge, last_idx, waypoint)
    } else if too_close_p1 {
      // Horizontal segment to horizontal side - need to step away first
      // Insert TWO waypoints: horizontal detour, then vertical approach
      let step = 20.0
      let step_y = if on_bottom { p1.y + step } else { p1.y - step }
      let w1 = @graph.Point::new(p0.x, step_y) // horizontal from prev
      let w2 = @graph.Point::new(p1.x, step_y) // then vertical to dest
      // Insert: ... → p0 → w1 → w2 → p1
      insert_waypoint_at(edge, last_idx, w2)
      insert_waypoint_at(edge, last_idx, w1)
    }
  }
}

///|
/// Check if two points are approximately equal within tolerance
fn points_approximately_equal(
  p1 : @graph.Point,
  p2 : @graph.Point,
  tolerance : Double,
) -> Bool {
  (p1.x - p2.x).abs() < tolerance && (p1.y - p2.y).abs() < tolerance
}

///|
/// Insert a waypoint at a specific index in the edge route
fn insert_waypoint_at(
  edge : @graph.Edge,
  index : Int,
  point : @graph.Point,
) -> Unit {
  let new_route : Array[@graph.Point] = []
  for i = 0; i < edge.route.length(); i = i + 1 {
    if i == index {
      new_route.push(point)
    }
    new_route.push(edge.route[i])
  }
  edge.route.clear()
  for pt in new_route {
    edge.route.push(pt)
  }
}
