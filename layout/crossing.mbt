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
pub fn minimize_crossings(
  graph : @graph.Graph,
  layer_result : LayerAssignment,
  cycle_result : CycleBreakResult,
) -> CrossingResult {
  // Build adjacency lists (respecting cycle breaking)
  let (upper_neighbors, lower_neighbors) = build_layer_adjacency(
    graph, layer_result, cycle_result,
  )
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
      sweep_down(layers, upper_neighbors)
    } else {
      sweep_up(layers, lower_neighbors)
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
) -> Unit {
  // Skip first layer (no upper neighbors)
  for i = 1; i < layers.length(); i = i + 1 {
    let upper_layer = layers[i - 1]
    let current_layer = layers[i]
    reorder_by_barycenter(current_layer, upper_layer, upper_neighbors)
  }
}

///|
/// Sweep up: reorder each layer based on lower neighbors
fn sweep_up(
  layers : Array[Array[String]],
  lower_neighbors : Map[String, Array[String]],
) -> Unit {
  // Skip last layer (no lower neighbors)
  for i = layers.length() - 2; i >= 0; i = i - 1 {
    let lower_layer = layers[i + 1]
    let current_layer = layers[i]
    reorder_by_barycenter(current_layer, lower_layer, lower_neighbors)
  }
}

///|
/// Reorder nodes in current layer by barycenter of their neighbors
fn reorder_by_barycenter(
  current_layer : Array[String],
  adjacent_layer : Array[String],
  neighbors : Map[String, Array[String]],
) -> Unit {
  // Build position map for adjacent layer
  let positions : Map[String, Int] = {}
  for i, node in adjacent_layer {
    positions[node] = i
  }
  // Compute barycenter for each node in current layer
  let barycenters : Array[(String, Double)] = []
  for i, node in current_layer {
    let bc = compute_barycenter(node, positions, neighbors, i)
    barycenters.push((node, bc))
  }
  // Sort by barycenter (stable sort to preserve order for equal values)
  sort_by_barycenter(barycenters)
  // Update current layer with new order
  for i, pair in barycenters {
    let (node, _) = pair
    current_layer[i] = node
  }
}

///|
/// Compute barycenter for a node
/// Returns average position of neighbors, or current position if no neighbors
fn compute_barycenter(
  node : String,
  adjacent_positions : Map[String, Int],
  neighbors : Map[String, Array[String]],
  current_pos : Int,
) -> Double {
  let node_neighbors = match neighbors.get(node) {
    Some(n) => n
    None => return current_pos.to_double()
  }
  if node_neighbors.length() == 0 {
    return current_pos.to_double()
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
    current_pos.to_double()
  } else {
    sum / count.to_double()
  }
}

///|
/// Sort pairs by barycenter value (insertion sort for stability)
fn sort_by_barycenter(pairs : Array[(String, Double)]) -> Unit {
  let n = pairs.length()
  for i = 1; i < n; i = i + 1 {
    let key = pairs[i]
    let (_, key_bc) = key
    let mut j = i - 1
    while j >= 0 {
      let (_, j_bc) = pairs[j]
      if j_bc > key_bc {
        pairs[j + 1] = pairs[j]
        j = j - 1
      } else {
        break
      }
    }
    pairs[j + 1] = key
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
