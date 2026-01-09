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
pub(all) enum VDirection {
  Up
  Down
} derive(Show, Eq)

///|
/// Direction for horizontal alignment
pub(all) enum HDirection {
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
pub fn run_brandes_koepf(
  graph : LGraph,
  options : @elk.LayoutOptions,
  direction : @elk.LayoutDirection,
) -> Unit {
  if graph.nodes.length() == 0 {
    return
  }
  let node_spacing = options.node_node_spacing.unwrap_or(20.0)
  let layer_spacing = options.node_node_between_layers_spacing.unwrap_or(40.0)
  let padding = options.padding.unwrap_or(@elk.ElkPadding::uniform(12.0))
  let is_horizontal = direction.is_horizontal()

  // For each of 4 directions, compute a layout
  let layouts : Array[Map[String, Double]] = []

  // Try all four direction combinations
  let v_dirs : Array[VDirection] = [Up, Down]
  let h_dirs : Array[HDirection] = [Left, Right]
  for vdir in v_dirs {
    for hdir in h_dirs {
      let positions = compute_layout(graph, vdir, hdir, node_spacing)
      layouts.push(positions)
    }
  }

  // Select the best layout (smallest total width/height)
  let best_layout = select_best_layout(layouts, graph)

  // Apply the selected layout
  apply_layout(
    graph, best_layout, layer_spacing, padding, is_horizontal, direction,
  )
}

///|
/// Compute layout for a specific direction combination
fn compute_layout(
  graph : LGraph,
  vdir : VDirection,
  hdir : HDirection,
  node_spacing : Double,
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

  // Extract final positions
  let positions : Map[String, Double] = {}
  for node in graph.nodes {
    match info.get(node.id) {
      Some(block_info) => {
        let root_info = info.get(block_info.root).unwrap_or(block_info)
        positions[node.id] = root_info.x
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
                      median_info.align = node.id
                      node_info.root = median_info.root
                      node_info.align = median_info.root
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
  if vdir == Up {
    // Look at incoming edges (from upper layer)
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
    // Look at outgoing edges (to lower layer)
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
/// Select the best layout from the 4 computed layouts
fn select_best_layout(
  layouts : Array[Map[String, Double]],
  graph : LGraph,
) -> Map[String, Double] {
  if layouts.length() == 0 {
    return {}
  }

  // Use the balanced median approach: for each node, take median of 4 positions
  let balanced : Map[String, Double] = {}
  for node in graph.nodes {
    let positions : Array[Double] = []
    for layout in layouts {
      match layout.get(node.id) {
        Some(x) => positions.push(x)
        None => ()
      }
    }
    if positions.length() > 0 {
      positions.sort_by(fn(a, b) {
        if a < b {
          -1
        } else if a > b {
          1
        } else {
          0
        }
      })
      // Take median
      let mid = positions.length() / 2
      balanced[node.id] = positions[mid]
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
  padding : @elk.ElkPadding,
  is_horizontal : Bool,
  direction : @elk.LayoutDirection,
) -> Unit {
  // Calculate layer positions
  let mut layer_offset = if is_horizontal { padding.left } else { padding.top }
  let default_node_spacing = 20.0
  let reverse_layers = match direction {
    @elk.Up => !is_horizontal
    @elk.Left => is_horizontal
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

    // Safety net: ensure no overlapping nodes in this layer
    // Sort by cross position, then spread if overlapping
    if !is_horizontal {
      // For vertical layout, check x overlaps
      let layer_nodes = layer.nodes.copy()
      layer_nodes.sort_by(fn(a, b) {
        if a.x < b.x {
          -1
        } else if a.x > b.x {
          1
        } else {
          0
        }
      })
      for i = 1; i < layer_nodes.length(); i = i + 1 {
        let prev = layer_nodes[i - 1]
        let curr = layer_nodes[i]
        let min_x = prev.x + prev.width + default_node_spacing
        if curr.x < min_x {
          curr.x = min_x
        }
      }
    } else {
      // For horizontal layout, check y overlaps
      let layer_nodes = layer.nodes.copy()
      layer_nodes.sort_by(fn(a, b) {
        if a.y < b.y {
          -1
        } else if a.y > b.y {
          1
        } else {
          0
        }
      })
      for i = 1; i < layer_nodes.length(); i = i + 1 {
        let prev = layer_nodes[i - 1]
        let curr = layer_nodes[i]
        let min_y = prev.y + prev.height + default_node_spacing
        if curr.y < min_y {
          curr.y = min_y
        }
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
