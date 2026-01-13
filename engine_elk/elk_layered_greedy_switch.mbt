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
/// Greedy Switch Heuristic for Crossing Minimization
///
/// This algorithm iteratively swaps adjacent nodes in a layer if the swap
/// reduces the number of edge crossings. It runs after barycenter ordering
/// to further optimize the layout.

// ============================================================================
// Crossing Counter
// ============================================================================

///|
/// Count crossings between two adjacent layers
/// Uses the algorithm from Barth, Mutzel, Jünger (2002)
fn count_crossings_between_layers(upper : LLayer, lower : LLayer) -> Int {
  if upper.nodes.length() == 0 || lower.nodes.length() == 0 {
    return 0
  }

  // Build position maps
  let upper_pos : Map[String, Int] = {}
  let lower_pos : Map[String, Int] = {}
  for i, node in upper.nodes {
    upper_pos[node.id] = i
  }
  for i, node in lower.nodes {
    lower_pos[node.id] = i
  }

  // Collect edges between layers as (upper_pos, lower_pos) pairs
  let edges : Array[(Int, Int)] = []
  for node in upper.nodes {
    for edge in node.outgoing_edges {
      // Check if target is in lower layer by looking up in lower_pos map
      match (upper_pos.get(node.id), lower_pos.get(edge.target_id)) {
        (Some(u), Some(l)) => edges.push((u, l))
        _ => ()
      }
    }
  }

  // Sort edges by upper position, then by lower position
  edges.sort_by(fn(a, b) {
    let (au, al) = a
    let (bu, bl) = b
    if au != bu {
      au - bu
    } else {
      al - bl
    }
  })

  // Count inversions using merge sort approach
  // For simplicity, use O(n^2) counting here
  let mut crossings = 0
  for i = 0; i < edges.length(); i = i + 1 {
    for j = i + 1; j < edges.length(); j = j + 1 {
      let (_, li) = edges[i]
      let (_, lj) = edges[j]
      if li > lj {
        crossings = crossings + 1
      }
    }
  }
  crossings
}

///|
/// Count crossings if two adjacent nodes were swapped
fn count_crossings_if_swapped(
  layer : LLayer,
  pos1 : Int,
  pos2 : Int,
  upper : LLayer?,
  lower : LLayer?,
) -> Int {
  // Temporarily swap
  let temp = layer.nodes[pos1]
  layer.nodes[pos1] = layer.nodes[pos2]
  layer.nodes[pos2] = temp

  // Count crossings with adjacent layers
  let mut crossings = 0
  match upper {
    Some(u) => crossings = crossings + count_crossings_between_layers(u, layer)
    None => ()
  }
  match lower {
    Some(l) => crossings = crossings + count_crossings_between_layers(layer, l)
    None => ()
  }

  // Swap back
  let temp2 = layer.nodes[pos1]
  layer.nodes[pos1] = layer.nodes[pos2]
  layer.nodes[pos2] = temp2
  crossings
}

///|
/// Count crossings without swapping
fn count_crossings_no_swap(
  layer : LLayer,
  upper : LLayer?,
  lower : LLayer?,
) -> Int {
  let mut crossings = 0
  match upper {
    Some(u) => crossings = crossings + count_crossings_between_layers(u, layer)
    None => ()
  }
  match lower {
    Some(l) => crossings = crossings + count_crossings_between_layers(layer, l)
    None => ()
  }
  crossings
}

// ============================================================================
// Greedy Switch Algorithm
// ============================================================================

///|
/// Apply greedy switch heuristic to a single layer
fn greedy_switch_layer(
  layer : LLayer,
  upper : LLayer?,
  lower : LLayer?,
) -> Bool {
  if layer.nodes.length() <= 1 {
    return false
  }
  let mut improved = false

  // Try swapping each pair of adjacent nodes
  for i = 0; i < layer.nodes.length() - 1; i = i + 1 {
    let crossings_before = count_crossings_no_swap(layer, upper, lower)
    let crossings_after = count_crossings_if_swapped(
      layer,
      i,
      i + 1,
      upper,
      lower,
    )
    if crossings_after < crossings_before {
      // Swap improves layout - do it permanently
      let temp = layer.nodes[i]
      layer.nodes[i] = layer.nodes[i + 1]
      layer.nodes[i + 1] = temp
      improved = true
    }
  }
  improved
}

///|
/// Run greedy switch crossing minimization on the entire graph
fn _greedy_switch(graph : LGraph, max_iterations : Int) -> Unit {
  if graph.layers.length() <= 1 {
    return
  }

  // Run multiple passes until no improvement
  for iter = 0; iter < max_iterations; iter = iter + 1 {
    let mut any_improved = false

    // Forward sweep
    for i = 0; i < graph.layers.length(); i = i + 1 {
      let upper = if i > 0 { Some(graph.layers[i - 1]) } else { None }
      let lower = if i < graph.layers.length() - 1 {
        Some(graph.layers[i + 1])
      } else {
        None
      }
      if greedy_switch_layer(graph.layers[i], upper, lower) {
        any_improved = true
      }
    }

    // Backward sweep
    for i = graph.layers.length() - 1; i >= 0; i = i - 1 {
      let upper = if i > 0 { Some(graph.layers[i - 1]) } else { None }
      let lower = if i < graph.layers.length() - 1 {
        Some(graph.layers[i + 1])
      } else {
        None
      }
      if greedy_switch_layer(graph.layers[i], upper, lower) {
        any_improved = true
      }
    }
    if !any_improved {
      break
    }
  }

  // Update node positions after all swaps
  for layer in graph.layers {
    for i, node in layer.nodes {
      node.position = i
    }
  }
}

// ============================================================================
// Two-Sided Greedy Switch (considers both adjacent layers)
// ============================================================================

///|
/// More sophisticated crossing counter for a pair of nodes
/// Considers crossings with edges to both upper and lower layers
fn crossing_difference_for_swap(
  layer : LLayer,
  pos1 : Int,
  pos2 : Int,
  graph : LGraph,
) -> Int {
  let layer_idx = layer.index
  let upper = if layer_idx > 0 {
    Some(graph.layers[layer_idx - 1])
  } else {
    None
  }
  let lower = if layer_idx < graph.layers.length() - 1 {
    Some(graph.layers[layer_idx + 1])
  } else {
    None
  }
  let before = count_crossings_no_swap(layer, upper, lower)
  let after = count_crossings_if_swapped(layer, pos1, pos2, upper, lower)
  after - before // Negative means improvement
}

///|
/// Two-sided greedy switch with more aggressive optimization
fn greedy_switch_two_sided(graph : LGraph, max_iterations : Int) -> Unit {
  if graph.layers.length() <= 1 {
    return
  }
  for iter = 0; iter < max_iterations; iter = iter + 1 {
    let mut any_improved = false
    for layer in graph.layers {
      if layer.nodes.length() <= 1 {
        continue
      }

      // Keep swapping until no more improvements in this layer
      let mut layer_improved = true
      while layer_improved {
        layer_improved = false

        // Find the best swap in this layer
        let mut best_i = -1
        let mut best_diff = 0
        for i = 0; i < layer.nodes.length() - 1; i = i + 1 {
          let diff = crossing_difference_for_swap(layer, i, i + 1, graph)
          if diff < best_diff {
            best_diff = diff
            best_i = i
          }
        }

        // Apply the best swap if it improves things
        if best_i >= 0 {
          let temp = layer.nodes[best_i]
          layer.nodes[best_i] = layer.nodes[best_i + 1]
          layer.nodes[best_i + 1] = temp
          layer_improved = true
          any_improved = true
        }
      }
    }
    if !any_improved {
      break
    }
  }

  // Update node positions
  for layer in graph.layers {
    for i, node in layer.nodes {
      node.position = i
    }
  }
}
