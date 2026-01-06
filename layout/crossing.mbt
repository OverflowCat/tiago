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
/// Crossing Minimization using Barycenter Heuristic
///
/// Implements the third phase of the Sugiyama framework.
/// Reorders nodes within each layer to minimize edge crossings.
/// Uses the barycenter heuristic: position each node at the average
/// position of its neighbors in adjacent layers.

///|
/// Result of crossing minimization
pub(all) struct CrossingResult {
  /// Nodes ordered by layer (layer index -> ordered node IDs)
  ordered_layers : Array[Array[String]]
}

///|
/// Minimize edge crossings using the Barycenter heuristic
/// Performs alternating up/down sweeps to iteratively improve ordering
/// Preserves original definition order as tie-breaker for nodes with equal barycenters
pub fn minimize_crossings(
  graph : @graph.Graph,
  layer_result : LayerAssignment,
  cycle_result : CycleBreakResult,
) -> CrossingResult {
  // Build adjacency lists (respecting cycle breaking)
  let (upper_neighbors, lower_neighbors) = build_layer_adjacency(
    graph, layer_result, cycle_result,
  )
  // Build original order map: node -> definition order
  // This preserves user's intended order for nodes without edge constraints
  let original_order : Map[String, Int] = {}
  let mut order_idx = 0
  for layer in layer_result.nodes_by_layer {
    for node in layer {
      original_order[node] = order_idx
      order_idx = order_idx + 1
    }
  }
  // Copy initial layer ordering
  let layers : Array[Array[String]] = []
  for layer in layer_result.nodes_by_layer {
    layers.push(layer.copy())
  }
  // Perform multiple sweeps
  let max_iterations = 24 // Dagre uses 24 iterations
  for iter = 0; iter < max_iterations; iter = iter + 1 {
    // Alternate between down sweep and up sweep
    if iter % 2 == 0 {
      sweep_down(layers, upper_neighbors, original_order)
    } else {
      sweep_up(layers, lower_neighbors, original_order)
    }
  }
  { ordered_layers: layers }
}

///|
/// Build adjacency lists between layers
/// Returns (upper_neighbors, lower_neighbors) maps
fn build_layer_adjacency(
  graph : @graph.Graph,
  layer_result : LayerAssignment,
  cycle_result : CycleBreakResult,
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let upper : Map[String, Array[String]] = {}
  let lower : Map[String, Array[String]] = {}
  // Initialize empty neighbor lists for all nodes
  for layer in layer_result.nodes_by_layer {
    for node in layer {
      upper[node] = []
      lower[node] = []
    }
  }
  // Add edges
  for edge in graph.edges {
    let src = get_effective_src(edge, cycle_result)
    let dst = get_effective_dst(edge, cycle_result)
    let src_layer = match layer_result.layers.get(src) {
      Some(l) => l
      None => continue
    }
    let dst_layer = match layer_result.layers.get(dst) {
      Some(l) => l
      None => continue
    }
    // src is in upper layer, dst is in lower layer
    if src_layer < dst_layer {
      // dst's upper neighbor is src
      match upper.get(dst) {
        Some(neighbors) => neighbors.push(src)
        None => upper[dst] = [src]
      }
      // src's lower neighbor is dst
      match lower.get(src) {
        Some(neighbors) => neighbors.push(dst)
        None => lower[src] = [dst]
      }
    }
  }
  (upper, lower)
}

///|
/// Sweep down: reorder each layer based on upper neighbors
fn sweep_down(
  layers : Array[Array[String]],
  upper_neighbors : Map[String, Array[String]],
  original_order : Map[String, Int],
) -> Unit {
  // Skip first layer (no upper neighbors)
  for i = 1; i < layers.length(); i = i + 1 {
    let upper_layer = layers[i - 1]
    let current_layer = layers[i]
    reorder_by_barycenter(
      current_layer, upper_layer, upper_neighbors, original_order,
    )
  }
}

///|
/// Sweep up: reorder each layer based on lower neighbors
fn sweep_up(
  layers : Array[Array[String]],
  lower_neighbors : Map[String, Array[String]],
  original_order : Map[String, Int],
) -> Unit {
  // Skip last layer (no lower neighbors)
  for i = layers.length() - 2; i >= 0; i = i - 1 {
    let lower_layer = layers[i + 1]
    let current_layer = layers[i]
    reorder_by_barycenter(
      current_layer, lower_layer, lower_neighbors, original_order,
    )
  }
}

///|
/// Reorder nodes in current layer by barycenter of their neighbors
fn reorder_by_barycenter(
  current_layer : Array[String],
  adjacent_layer : Array[String],
  neighbors : Map[String, Array[String]],
  original_order : Map[String, Int],
) -> Unit {
  // Build position map for adjacent layer
  let positions : Map[String, Int] = {}
  for i, node in adjacent_layer {
    positions[node] = i
  }
  // Compute barycenter for each node in current layer
  // Store (node, barycenter, original_order) for sorting
  let entries : Array[(String, Double, Int)] = []
  for node in current_layer {
    let bc = compute_barycenter(node, positions, neighbors, original_order)
    let orig = original_order.get(node).unwrap_or(0)
    entries.push((node, bc, orig))
  }
  // Sort by (barycenter, original_order) - uses original order as tie-breaker
  sort_by_barycenter_and_order(entries)
  // Update current layer with new order
  for i, entry in entries {
    let (node, _, _) = entry
    current_layer[i] = node
  }
}

///|
/// Compute barycenter for a node
/// Returns average position of neighbors, or a position based on original order if no neighbors
fn compute_barycenter(
  node : String,
  adjacent_positions : Map[String, Int],
  neighbors : Map[String, Array[String]],
  original_order : Map[String, Int],
) -> Double {
  let node_neighbors = match neighbors.get(node) {
    Some(n) => n
    None =>
      // No neighbors: use original order scaled to be in the middle of the layer
      // This ensures nodes without edges stay near their original position
      return original_order.get(node).unwrap_or(0).to_double()
  }
  if node_neighbors.length() == 0 {
    // No neighbors: use original order
    return original_order.get(node).unwrap_or(0).to_double()
  }
  // Sum positions of neighbors
  let mut sum = 0.0
  let mut count = 0
  for neighbor in node_neighbors {
    match adjacent_positions.get(neighbor) {
      Some(pos) => {
        sum = sum + pos.to_double()
        count = count + 1
      }
      None => ()
    }
  }
  if count == 0 {
    // Neighbors exist but not in adjacent layer: use original order
    original_order.get(node).unwrap_or(0).to_double()
  } else {
    sum / count.to_double()
  }
}

///|
/// Sort entries by (barycenter, original_order)
/// Uses original order as tie-breaker when barycenters are equal
fn sort_by_barycenter_and_order(entries : Array[(String, Double, Int)]) -> Unit {
  let n = entries.length()
  for i = 1; i < n; i = i + 1 {
    let key = entries[i]
    let (_, key_bc, key_order) = key
    let mut j = i - 1
    while j >= 0 {
      let (_, j_bc, j_order) = entries[j]
      // Compare by barycenter first, then by original order
      let should_swap = if j_bc > key_bc {
        true
      } else if j_bc == key_bc && j_order > key_order {
        true
      } else {
        false
      }
      if should_swap {
        entries[j + 1] = entries[j]
        j = j - 1
      } else {
        break
      }
    }
    entries[j + 1] = key
  }
}

///|
/// Count edge crossings between two adjacent layers
/// Useful for testing and debugging
pub fn count_crossings(
  upper_layer : Array[String],
  lower_layer : Array[String],
  edges : Array[(String, String)],
) -> Int {
  // Build position maps
  let upper_pos : Map[String, Int] = {}
  let lower_pos : Map[String, Int] = {}
  for i, node in upper_layer {
    upper_pos[node] = i
  }
  for i, node in lower_layer {
    lower_pos[node] = i
  }
  // Count crossings: for each pair of edges, check if they cross
  let mut crossings = 0
  let n = edges.length()
  for i = 0; i < n; i = i + 1 {
    let (u1, v1) = edges[i]
    let u1_pos = match upper_pos.get(u1) {
      Some(p) => p
      None => continue
    }
    let v1_pos = match lower_pos.get(v1) {
      Some(p) => p
      None => continue
    }
    for j = i + 1; j < n; j = j + 1 {
      let (u2, v2) = edges[j]
      let u2_pos = match upper_pos.get(u2) {
        Some(p) => p
        None => continue
      }
      let v2_pos = match lower_pos.get(v2) {
        Some(p) => p
        None => continue
      }
      // Edges cross if (u1 < u2 and v1 > v2) or (u1 > u2 and v1 < v2)
      if (u1_pos < u2_pos && v1_pos > v2_pos) ||
        (u1_pos > u2_pos && v1_pos < v2_pos) {
        crossings = crossings + 1
      }
    }
  }
  crossings
}

///|
/// Minimize edge crossings with virtual node support
/// Virtual nodes are included in the layer ordering but need special handling
/// for neighbor computation (they connect to virtual chain neighbors)
pub fn minimize_crossings_with_virtual(
  graph : @graph.Graph,
  layer_result : LayerAssignment,
  cycle_result : CycleBreakResult,
  _virtual_nodes : Map[String, Bool],
) -> CrossingResult {
  // Build adjacency lists including virtual node chains
  let (upper_neighbors, lower_neighbors) = build_layer_adjacency_with_virtual(
    graph, layer_result, cycle_result, _virtual_nodes,
  )
  // Build original order map
  let original_order : Map[String, Int] = {}
  let mut order_idx = 0
  for layer in layer_result.nodes_by_layer {
    for node in layer {
      original_order[node] = order_idx
      order_idx = order_idx + 1
    }
  }
  // Copy initial layer ordering
  let layers : Array[Array[String]] = []
  for layer in layer_result.nodes_by_layer {
    layers.push(layer.copy())
  }
  // Perform multiple sweeps
  let max_iterations = 24
  for iter = 0; iter < max_iterations; iter = iter + 1 {
    if iter % 2 == 0 {
      sweep_down(layers, upper_neighbors, original_order)
    } else {
      sweep_up(layers, lower_neighbors, original_order)
    }
  }
  { ordered_layers: layers }
}

///|
/// Build adjacency lists including virtual node chains
fn build_layer_adjacency_with_virtual(
  graph : @graph.Graph,
  layer_result : LayerAssignment,
  cycle_result : CycleBreakResult,
  _virtual_nodes : Map[String, Bool],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let upper : Map[String, Array[String]] = {}
  let lower : Map[String, Array[String]] = {}
  // Initialize empty neighbor lists for all nodes (including virtual)
  for layer in layer_result.nodes_by_layer {
    for node in layer {
      upper[node] = []
      lower[node] = []
    }
  }
  // Process each edge
  for edge in graph.edges {
    let src = get_effective_src(edge, cycle_result)
    let dst = get_effective_dst(edge, cycle_result)
    let src_layer = layer_result.layers.get(src).unwrap_or(0)
    let dst_layer = layer_result.layers.get(dst).unwrap_or(0)
    if src_layer < dst_layer {
      let span = dst_layer - src_layer
      if span == 1 {
        // Direct edge
        if upper.get(dst) is Some(neighbors) {
          neighbors.push(src)
        }
        if lower.get(src) is Some(neighbors) {
          neighbors.push(dst)
        }
      } else {
        // Long edge with virtual nodes
        // Chain: src -> v1 -> v2 -> ... -> dst
        let mut prev = src
        for layer_idx = src_layer + 1
            layer_idx < dst_layer
            layer_idx = layer_idx + 1 {
          let virtual_id = "__virtual_\{edge.index}_\{layer_idx}"
          // prev -> virtual_id connection
          if lower.get(prev) is Some(neighbors) {
            neighbors.push(virtual_id)
          }
          if upper.get(virtual_id) is Some(neighbors) {
            neighbors.push(prev)
          }
          prev = virtual_id
        }
        // Last virtual -> dst connection
        if lower.get(prev) is Some(neighbors) {
          neighbors.push(dst)
        }
        if upper.get(dst) is Some(neighbors) {
          neighbors.push(prev)
        }
      }
    }
  }
  (upper, lower)
}
