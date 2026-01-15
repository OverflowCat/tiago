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
/// Brandes-Koepf Node Placement Algorithm
///
/// This algorithm assigns y-coordinates to nodes to minimize edge bends
/// while respecting layer structure. It uses a four-direction approach:
/// (UP/DOWN) x (LEFT/RIGHT), then selects the best result.
///
/// Based on "Fast and Simple Horizontal Coordinate Assignment" (2002)

// ============================================================================
// Block and Root Structures
// ============================================================================

///|
/// Direction for vertical alignment
enum VDirection {
  Up
  Down
} derive(Show, Eq)

///|
/// Direction for horizontal alignment
enum HDirection {
  Left
  Right
} derive(Show, Eq)

///|
/// Block information for a node
struct BlockInfo {
  mut root : String // Root of the block this node belongs to
  mut align : String // Next node in the block
  sink : String // Sink of the block (unused but kept for completeness)
  shift : Double // Shift value for block positioning (unused but kept for completeness)
  mut x : Double // X coordinate (used for horizontal compaction)
} derive(Show)

// ============================================================================
// Brandes-Koepf Algorithm Implementation
// ============================================================================

///|
/// Run Brandes-Koepf node placement
fn run_brandes_koepf(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
) -> Unit {
  if graph.nodes.length() == 0 {
    return
  }
  let node_spacing = options.node_node_spacing.unwrap_or(20.0)
  let layer_spacing = options.node_node_between_layers_spacing.unwrap_or(40.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let is_horizontal = direction.is_horizontal()

  // Determine whether to favor straight edges (ELK default depends on edge routing).
  let edge_routing = options.edge_routing.unwrap_or(Orthogonal)
  let favor_straight_edges = edge_routing == Orthogonal

  // Choose which BK alignment(s) to compute.
  let requested = options.bk_fixed_alignment
  let produce_balanced_layout = match requested {
    Some(Average) => true
    Some(_) => false
    None => !favor_straight_edges
  }
  let layouts : Array[Map[String, Double]] = []
  match requested {
    Some(LeftDown) =>
      layouts.push(
        compute_layout(graph, Down, Left, node_spacing, is_horizontal),
      )
    Some(LeftUp) =>
      layouts.push(compute_layout(graph, Up, Left, node_spacing, is_horizontal))
    Some(RightDown) =>
      layouts.push(
        compute_layout(graph, Down, Right, node_spacing, is_horizontal),
      )
    Some(RightUp) =>
      layouts.push(
        compute_layout(graph, Up, Right, node_spacing, is_horizontal),
      )
    Some(Average) | None => {
      // Try all four direction combinations.
      let v_dirs : Array[VDirection] = [Up, Down]
      let h_dirs : Array[HDirection] = [Left, Right]
      for vdir in v_dirs {
        for hdir in h_dirs {
          let positions = compute_layout(
            graph, vdir, hdir, node_spacing, is_horizontal,
          )
          layouts.push(positions)
        }
      }
    }
  }

  // Select the final layout.
  // Reference ELK favors straight edges for orthogonal routing.
  let chosen_layout = if produce_balanced_layout {
    create_balanced_layout(layouts, graph, is_horizontal)
  } else if favor_straight_edges && requested is None {
    select_favor_straight_layout(layouts, graph, is_horizontal)
  } else {
    select_smallest_layout(layouts, graph, is_horizontal)
  }

  // Apply the selected layout.
  apply_layout(
    graph, chosen_layout, layer_spacing, padding, is_horizontal, direction,
  )
}

///|
/// Compute layout for a specific direction combination
fn compute_layout(
  graph : LGraph,
  vdir : VDirection,
  hdir : HDirection,
  node_spacing : Double,
  is_horizontal : Bool,
) -> Map[String, Double] {
  // Initialize block info for all nodes
  let info : Map[String, BlockInfo] = {}
  for node in graph.nodes {
    info[node.id] = {
      root: node.id,
      align: node.id,
      sink: node.id,
      shift: @double.infinity,
      x: @double.neg_infinity,
    }
  }

  // Step 1: Vertical alignment - group nodes into blocks
  vertical_alignment(graph, info, vdir, hdir)

  // Step 2: Horizontal compaction - assign x coordinates
  horizontal_compaction(graph, info, hdir, node_spacing)

  // Step 3: shift nodes inside blocks so that their port anchors align.
  // This helps avoid unnecessary bends for orthogonal routing when node sizes differ.
  let inner_shift : Map[String, Double] = {}
  for node in graph.nodes {
    inner_shift[node.id] = 0.0
  }
  fn anchor_cross(node : LNode, port_id : String?) -> Double {
    match port_id {
      Some(pid) => {
        for port in node.ports {
          if port.id == pid {
            let has_size = port.width > 0.0 || port.height > 0.0
            if has_size {
              return if is_horizontal {
                port.y + port.height / 2.0
              } else {
                port.x + port.width / 2.0
              }
            }
            let has_pos = port.x != 0.0 || port.y != 0.0
            if is_horizontal {
              // Horizontal layouts connect via East/West; cross axis is Y.
              match port.side {
                West | East =>
                  return if has_pos { port.y } else { node.height / 2.0 }
                _ => return if has_pos { port.y } else { node.height / 2.0 }
              }
            } else {
              // Vertical layouts connect via North/South; cross axis is X.
              match port.side {
                North | South =>
                  return if has_pos { port.x } else { node.width / 2.0 }
                _ => return if has_pos { port.x } else { node.width / 2.0 }
              }
            }
          }
        }
        if is_horizontal {
          node.height / 2.0
        } else {
          node.width / 2.0
        }
      }
      None => if is_horizontal { node.height / 2.0 } else { node.width / 2.0 }
    }
  }

  fn find_edge_between(graph : LGraph, a : String, b : String) -> LEdge? {
    for e in graph.edges {
      if (e.source_id == a && e.target_id == b) ||
        (e.source_id == b && e.target_id == a) {
        return Some(e)
      }
    }
    None
  }

  // Compute inside-block shifts by following alignment pointers.
  // `align` points to a node in the already-processed adjacent layer.
  let layer_order : Array[Int] = if vdir == Down {
    let order : Array[Int] = []
    for i = 0; i < graph.layers.length(); i = i + 1 {
      order.push(i)
    }
    order
  } else {
    let order : Array[Int] = []
    for i = graph.layers.length() - 1; i >= 0; i = i - 1 {
      order.push(i)
    }
    order
  }
  for layer_idx in layer_order {
    let layer = graph.layers[layer_idx]
    for node in layer.nodes {
      let parent_id = info.get(node.id).unwrap().align
      if parent_id == node.id {
        continue
      }
      match graph.get_node(parent_id) {
        Some(parent) =>
          match find_edge_between(graph, node.id, parent_id) {
            Some(e) => {
              let (parent_port, node_port) = if e.source_id == parent_id &&
                e.target_id == node.id {
                (e.source_port_id, e.target_port_id)
              } else {
                (e.target_port_id, e.source_port_id)
              }
              let parent_anchor = anchor_cross(parent, parent_port)
              let node_anchor = anchor_cross(node, node_port)
              let parent_shift = inner_shift.get(parent_id).unwrap_or(0.0)
              inner_shift[node.id] = parent_shift +
                (parent_anchor - node_anchor)
            }
            None =>
              inner_shift[node.id] = inner_shift.get(parent_id).unwrap_or(0.0)
          }
        None => ()
      }
    }
  }

  // Resolve overlaps by shifting whole blocks (block roots).
  // This keeps the relative alignment inside blocks intact.
  let root_pos : Map[String, Double] = {}
  for node in graph.nodes {
    match info.get(node.id) {
      Some(b) => {
        let rid = b.root
        if !root_pos.contains(rid) {
          let ri = info.get(rid).unwrap_or(b)
          root_pos[rid] = ri.x
        }
      }
      None => ()
    }
  }
  let max_iters = graph.layers.length() * 4 + 8
  for _iter = 0; _iter < max_iters; _iter = _iter + 1 {
    let mut changed = false
    for layer in graph.layers {
      let layer_nodes = layer.nodes.copy()
      layer_nodes.sort_by(fn(a, b) {
        let a_pos = match info.get(a.id) {
          Some(ai) =>
            root_pos.get(ai.root).unwrap_or(0.0) +
            inner_shift.get(a.id).unwrap_or(0.0)
          None => inner_shift.get(a.id).unwrap_or(0.0)
        }
        let b_pos = match info.get(b.id) {
          Some(bi) =>
            root_pos.get(bi.root).unwrap_or(0.0) +
            inner_shift.get(b.id).unwrap_or(0.0)
          None => inner_shift.get(b.id).unwrap_or(0.0)
        }
        if a_pos < b_pos {
          -1
        } else if a_pos > b_pos {
          1
        } else {
          a.id.compare(b.id)
        }
      })
      for i = 1; i < layer_nodes.length(); i = i + 1 {
        let prev = layer_nodes[i - 1]
        let curr = layer_nodes[i]
        let prev_info = info.get(prev.id)
        let curr_info = info.get(curr.id)
        guard prev_info is Some(pi) && curr_info is Some(ci) else { continue }
        if pi.root == ci.root {
          continue
        }
        let prev_root_pos = root_pos.get(pi.root).unwrap_or(0.0)
        let curr_root_pos = root_pos.get(ci.root).unwrap_or(0.0)
        let prev_pos = prev_root_pos + inner_shift.get(prev.id).unwrap_or(0.0)
        let curr_pos = curr_root_pos + inner_shift.get(curr.id).unwrap_or(0.0)
        let prev_size = if is_horizontal { prev.height } else { prev.width }
        let required = prev_pos + prev_size + node_spacing
        if curr_pos < required {
          root_pos[ci.root] = curr_root_pos + (required - curr_pos)
          changed = true
        }
      }
    }
    if !changed {
      break
    }
  }

  // Extract final positions (block root position + per-node inner shift).
  let positions : Map[String, Double] = {}
  for node in graph.nodes {
    match info.get(node.id) {
      Some(block_info) => {
        let shift = inner_shift.get(node.id).unwrap_or(0.0)
        positions[node.id] = root_pos.get(block_info.root).unwrap_or(0.0) +
          shift
      }
      None => positions[node.id] = 0.0
    }
  }
  positions
}

///|
/// Vertical alignment phase - create blocks of aligned nodes
fn vertical_alignment(
  graph : LGraph,
  info : Map[String, BlockInfo],
  vdir : VDirection,
  hdir : HDirection,
) -> Unit {
  // Process layers in order based on vertical direction
  let layer_order = if vdir == Up {
    // Process from bottom to top
    let order : Array[Int] = []
    for i = graph.layers.length() - 1; i >= 0; i = i - 1 {
      order.push(i)
    }
    order
  } else {
    // Process from top to bottom
    let order : Array[Int] = []
    for i = 0; i < graph.layers.length(); i = i + 1 {
      order.push(i)
    }
    order
  }
  for layer_idx in layer_order {
    let layer = graph.layers[layer_idx]

    // Process nodes in order based on horizontal direction
    let node_order = if hdir == Left {
      // Left to right
      let order : Array[Int] = []
      for i = 0; i < layer.nodes.length(); i = i + 1 {
        order.push(i)
      }
      order
    } else {
      // Right to left
      let order : Array[Int] = []
      for i = layer.nodes.length() - 1; i >= 0; i = i - 1 {
        order.push(i)
      }
      order
    }
    let mut r = -1 // Rightmost position of aligned neighbor
    for pos in node_order {
      let node = layer.nodes[pos]

      // Find neighbors in adjacent layer
      let neighbors = get_neighbors(graph, node, vdir)
      if neighbors.length() > 0 {
        // Get median neighbor(s)
        let medians = get_medians(neighbors, hdir)
        for median in medians {
          match info.get(node.id) {
            Some(node_info) =>
              if node_info.align == node.id {
                // Node not yet aligned
                let median_pos = median.position
                if (hdir == Left && median_pos > r) ||
                  (hdir == Right && median_pos < r) ||
                  r < 0 {
                  // Align with median
                  match info.get(median.id) {
                    Some(median_info) => {
                      // Align this node with the median neighbor.
                      node_info.align = median.id
                      node_info.root = median_info.root
                      r = median_pos
                      // Put modified values back in map
                      info[median.id] = median_info
                      info[node.id] = node_info
                    }
                    None => ()
                  }
                }
              }
            None => ()
          }
        }
      }
    }
  }
}

///|
/// Get neighbors in the adjacent layer based on direction
fn get_neighbors(
  graph : LGraph,
  node : LNode,
  vdir : VDirection,
) -> Array[LNode] {
  let neighbors : Array[LNode] = []
  if vdir == Down {
    // Down sweep (top -> bottom): look at incoming edges from previous layer.
    for edge in node.incoming_edges {
      match graph.get_node(edge.source_id) {
        Some(source) =>
          if source.layer == node.layer - 1 {
            neighbors.push(source)
          }
        None => ()
      }
    }
  } else {
    // Up sweep (bottom -> top): look at outgoing edges to next layer.
    for edge in node.outgoing_edges {
      match graph.get_node(edge.target_id) {
        Some(target) =>
          if target.layer == node.layer + 1 {
            neighbors.push(target)
          }
        None => ()
      }
    }
  }

  // Sort by position
  neighbors.sort_by(fn(a, b) { a.position - b.position })
  neighbors
}

///|
/// Get median neighbor(s) from sorted list
fn get_medians(neighbors : Array[LNode], hdir : HDirection) -> Array[LNode] {
  let n = neighbors.length()
  if n == 0 {
    return []
  }
  let mid = n / 2
  if n % 2 == 1 {
    // Odd number - single median
    [neighbors[mid]]
  } else if hdir == Left {
    // Even number - left median
    [neighbors[mid - 1]]
  } else {
    // Even number - right median
    [neighbors[mid]]
  }
}

///|
/// Horizontal compaction phase - assign x coordinates to blocks
fn horizontal_compaction(
  graph : LGraph,
  info : Map[String, BlockInfo],
  hdir : HDirection,
  node_spacing : Double,
) -> Unit {
  // Find all root nodes (nodes where root == self)
  let roots : Array[LNode] = []
  for node in graph.nodes {
    match info.get(node.id) {
      Some(block_info) => if block_info.root == node.id { roots.push(node) }
      None => ()
    }
  }

  // Sort roots by layer and position
  roots.sort_by(fn(a, b) {
    if a.layer != b.layer {
      a.layer - b.layer
    } else {
      a.position - b.position
    }
  })

  // Assign x coordinates to roots
  // Process layer by layer
  let layer_x : Map[Int, Double] = {}
  for root in roots {
    match info.get(root.id) {
      Some(root_info) => {
        // Get minimum x based on previous nodes in same layer
        let min_x = layer_x.get(root.layer).unwrap_or(0.0)

        // Set x coordinate and put back in map
        root_info.x = min_x
        info[root.id] = root_info

        // Update layer_x for next node
        let node_size = if root.width > 0.0 { root.width } else { 60.0 }
        layer_x[root.layer] = min_x + node_size + node_spacing
      }
      None => ()
    }
  }

  // If processing right-to-left, we need to flip coordinates
  if hdir == Right {
    let mut max_x = 0.0
    for node in graph.nodes {
      match info.get(node.id) {
        Some(block_info) => {
          let root_info = info.get(block_info.root).unwrap_or(block_info)
          if root_info.x > max_x {
            max_x = root_info.x + node.width
          }
        }
        None => ()
      }
    }

    // Flip all coordinates
    for root in roots {
      match info.get(root.id) {
        Some(root_info) => {
          root_info.x = max_x - root_info.x - root.width
          info[root.id] = root_info
        }
        None => ()
      }
    }
  }
}

///|
fn layout_span(
  positions : Map[String, Double],
  graph : LGraph,
  is_horizontal : Bool,
) -> (Double, Double, Double) {
  let mut min_pos = @double.infinity
  let mut max_pos = @double.neg_infinity
  for node in graph.nodes {
    let p = positions.get(node.id).unwrap_or(0.0)
    let size = if is_horizontal { node.height } else { node.width }
    if p < min_pos {
      min_pos = p
    }
    if p + size > max_pos {
      max_pos = p + size
    }
  }
  if min_pos == @double.infinity {
    (0.0, 0.0, 0.0)
  } else {
    (min_pos, max_pos, max_pos - min_pos)
  }
}

///|
fn anchor_cross_for_straightness(
  node : LNode,
  port_id : String?,
  is_horizontal : Bool,
) -> Double {
  match port_id {
    Some(pid) => {
      for port in node.ports {
        if port.id == pid {
          let has_size = port.width > 0.0 || port.height > 0.0
          if has_size {
            return if is_horizontal {
              port.y + port.height / 2.0
            } else {
              port.x + port.width / 2.0
            }
          }
          let has_pos = port.x != 0.0 || port.y != 0.0
          if is_horizontal {
            return if has_pos { port.y } else { node.height / 2.0 }
          }
          return if has_pos { port.x } else { node.width / 2.0 }
        }
      }
      if is_horizontal {
        node.height / 2.0
      } else {
        node.width / 2.0
      }
    }
    None => if is_horizontal { node.height / 2.0 } else { node.width / 2.0 }
  }
}

///|
fn straight_edge_score(
  positions : Map[String, Double],
  graph : LGraph,
  is_horizontal : Bool,
) -> Int {
  let eps = 0.5
  let mut score = 0
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source = graph.get_node(edge.source_id)
    let target = graph.get_node(edge.target_id)
    guard source is Some(src) && target is Some(tgt) else { continue }
    if src.is_dummy() || tgt.is_dummy() {
      continue
    }
    if src.layer == tgt.layer {
      continue
    }
    let src_pos = positions.get(src.id).unwrap_or(0.0)
    let tgt_pos = positions.get(tgt.id).unwrap_or(0.0)
    let src_anchor = anchor_cross_for_straightness(
      src,
      edge.source_port_id,
      is_horizontal,
    )
    let tgt_anchor = anchor_cross_for_straightness(
      tgt,
      edge.target_port_id,
      is_horizontal,
    )
    let src_center = src_pos + src_anchor
    let tgt_center = tgt_pos + tgt_anchor
    if (src_center - tgt_center).abs() <= eps {
      score = score + 1
    }
  }
  score
}

///|
/// Select the layout that maximizes straight edges.
fn select_favor_straight_layout(
  layouts : Array[Map[String, Double]],
  graph : LGraph,
  is_horizontal : Bool,
) -> Map[String, Double] {
  if layouts.length() == 0 {
    return {}
  }
  let mut best = layouts[0]
  let mut best_score = straight_edge_score(best, graph, is_horizontal)
  let mut best_span = layout_span(best, graph, is_horizontal).2
  for i = 1; i < layouts.length(); i = i + 1 {
    let score = straight_edge_score(layouts[i], graph, is_horizontal)
    let span = layout_span(layouts[i], graph, is_horizontal).2
    if score > best_score || (score == best_score && span < best_span) {
      best = layouts[i]
      best_score = score
      best_span = span
    }
  }
  best
}

///|
/// Select the smallest of the computed layouts.
fn select_smallest_layout(
  layouts : Array[Map[String, Double]],
  graph : LGraph,
  is_horizontal : Bool,
) -> Map[String, Double] {
  if layouts.length() == 0 {
    return {}
  }
  let mut best = layouts[0]
  let mut best_span = layout_span(best, graph, is_horizontal).2
  for i = 1; i < layouts.length(); i = i + 1 {
    let span = layout_span(layouts[i], graph, is_horizontal).2
    if span < best_span {
      best = layouts[i]
      best_span = span
    }
  }
  best
}

///|
/// Create a balanced (median) layout across the computed layouts.
fn create_balanced_layout(
  layouts : Array[Map[String, Double]],
  graph : LGraph,
  is_horizontal : Bool,
) -> Map[String, Double] {
  if layouts.length() == 0 {
    return {}
  }

  // Use the smallest layout as baseline and shift others to match its minimum.
  let mut min_idx = 0
  let mut min_span = layout_span(layouts[0], graph, is_horizontal).2
  for i = 1; i < layouts.length(); i = i + 1 {
    let span = layout_span(layouts[i], graph, is_horizontal).2
    if span < min_span {
      min_span = span
      min_idx = i
    }
  }
  let (base_min, _, _) = layout_span(layouts[min_idx], graph, is_horizontal)
  let mins : Array[Double] = []
  for layout in layouts {
    let (mn, _, _) = layout_span(layout, graph, is_horizontal)
    mins.push(mn)
  }
  let balanced : Map[String, Double] = {}
  for node in graph.nodes {
    let values : Array[Double] = []
    for i = 0; i < layouts.length(); i = i + 1 {
      let p = layouts[i].get(node.id).unwrap_or(0.0)
      values.push(p + (base_min - mins[i]))
    }
    values.sort_by(fn(a, b) { if a < b { -1 } else if a > b { 1 } else { 0 } })
    if values.length() == 0 {
      balanced[node.id] = 0.0
    } else if values.length() == 4 {
      balanced[node.id] = (values[1] + values[2]) / 2.0
    } else {
      balanced[node.id] = values[values.length() / 2]
    }
  }
  balanced
}

///|
/// Apply the computed layout to the graph
fn apply_layout(
  graph : LGraph,
  positions : Map[String, Double],
  layer_spacing : Double,
  padding : ElkPadding,
  is_horizontal : Bool,
  direction : LayoutDirection,
) -> Unit {
  // Calculate layer positions
  let mut layer_offset = if is_horizontal { padding.left } else { padding.top }
  let reverse_layers = match direction {
    Up => !is_horizontal
    Left => is_horizontal
    _ => false
  }
  let layers : Array[LLayer] = []
  if reverse_layers {
    for i = 0; i < graph.layers.length(); i = i + 1 {
      let idx = graph.layers.length() - 1 - i
      layers.push(graph.layers[idx])
    }
  } else {
    layers.append(graph.layers)
  }
  for layer in layers {
    // Calculate layer size
    let mut layer_size = 0.0
    for node in layer.nodes {
      layer_size = if is_horizontal {
        bk_max(layer_size, node.height)
      } else {
        bk_max(layer_size, node.width)
      }
    }

    // Position nodes within layer
    for node in layer.nodes {
      let cross_pos = positions.get(node.id).unwrap_or(0.0)
      if is_horizontal {
        node.x = layer_offset
        node.y = cross_pos + padding.top
      } else {
        node.x = cross_pos + padding.left
        node.y = layer_offset
      }
    }
    layer_offset = layer_offset + layer_size + layer_spacing
  }

  // Update graph size
  let mut max_x = 0.0
  let mut max_y = 0.0
  for node in graph.nodes {
    max_x = bk_max(max_x, node.x + node.width)
    max_y = bk_max(max_y, node.y + node.height)
  }
  graph.width = max_x + padding.right
  graph.height = max_y + padding.bottom
}

///|
fn bk_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
