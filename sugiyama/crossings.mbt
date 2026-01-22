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
/// Efficient Edge Crossing Count using Fenwick Tree (Binary Indexed Tree)
///
/// Implements O(E log V) crossing count algorithm.
/// Used by the crossing minimization phase to efficiently evaluate
/// different node orderings.

///|
/// A Fenwick tree (Binary Indexed Tree) for efficient prefix sum queries
/// Used to count inversions (crossings) in O(n log n)
priv struct FenwickTree {
  tree : Array[Double]
  size : Int
}

///|
/// Create a new Fenwick tree with given size
fn FenwickTree::new(size : Int) -> FenwickTree {
  let tree : Array[Double] = []
  for _ in 0..<=size {
    tree.push(0.0)
  }
  { tree, size }
}

///|
/// Update value at index (1-indexed)
fn FenwickTree::update(self : FenwickTree, idx : Int, delta : Double) -> Unit {
  let mut i = idx
  while i <= self.size {
    self.tree[i] = self.tree[i] + delta
    i = i + (i & -i)
  } // Add lowest set bit
}

///|
/// Query prefix sum [1, idx] (1-indexed)
fn FenwickTree::query(self : FenwickTree, idx : Int) -> Double {
  let mut sum = 0.0
  let mut i = idx
  while i > 0 {
    sum = sum + self.tree[i]
    i = i - (i & -i)
  } // Remove lowest set bit
  sum
}

///|
/// Query range sum (idx, size] - elements strictly greater than idx
fn FenwickTree::query_greater(self : FenwickTree, idx : Int) -> Double {
  self.query(self.size) - self.query(idx)
}

///|
/// Count edge crossings between two adjacent layers using Fenwick tree
/// This is O(E log V) instead of naive O(E²)
///
/// An edge (u1, v1) crosses (u2, v2) when:
/// - u1 < u2 in north layer AND v1 > v2 in south layer, or
/// - u1 > u2 in north layer AND v1 < v2 in south layer
///
/// Algorithm: Process edges sorted by north position, then count inversions
/// in south positions using Fenwick tree
pub fn count_crossings_fenwick(
  north_layer : Array[String],
  south_layer : Array[String],
  edges : Array[(String, String, Double)],
) -> Double {
  if edges.length() == 0 || south_layer.length() == 0 {
    return 0.0
  }
  // Build position maps
  let north_pos : Map[String, Int] = {}
  let south_pos : Map[String, Int] = {}
  for i, node in north_layer {
    north_pos[node] = i
  }
  for i, node in south_layer {
    south_pos[node] = i
  }
  // Collect edges with their positions and weights
  // (north_position, south_position, weight)
  let edge_entries : Array[(Int, Int, Double)] = []
  for edge in edges {
    let (north, south, weight) = edge
    match (north_pos.get(north), south_pos.get(south)) {
      (Some(np), Some(sp)) => edge_entries.push((np, sp, weight))
      _ => ()
    }
  }
  // Sort edges by north position (stable sort preserves order for ties)
  sort_edges_by_north(edge_entries)
  // Use Fenwick tree to count inversions
  // Process edges from left to right in north layer
  // For each edge, count how many already-processed edges have a greater south position
  let tree = FenwickTree::new(south_layer.length())
  let mut crossings = 0.0
  for entry in edge_entries {
    let (_, sp, weight) = entry
    // sp is 0-indexed, Fenwick tree uses 1-indexed
    let pos = sp + 1
    // Count edges with south position > sp (already processed)
    crossings = crossings + weight * tree.query_greater(pos)
    // Add this edge to the tree
    tree.update(pos, weight)
  }
  crossings
}

///|
/// Count crossings between two layers (unweighted version)
/// Returns integer count for compatibility with existing code
pub fn count_crossings_fast(
  north_layer : Array[String],
  south_layer : Array[String],
  edges : Array[(String, String)],
) -> Int {
  // Convert to weighted edges (weight = 1.0)
  let weighted : Array[(String, String, Double)] = []
  for edge in edges {
    let (src, dst) = edge
    weighted.push((src, dst, 1.0))
  }
  count_crossings_fenwick(north_layer, south_layer, weighted).to_int()
}

///|
/// Count all crossings in a layered graph
pub fn count_all_crossings(
  layers : Array[Array[String]],
  upper_neighbors : Map[String, Array[String]],
) -> Int {
  let mut total = 0
  for i = 1; i < layers.length(); i = i + 1 {
    let north = layers[i - 1]
    let south = layers[i]
    // Collect edges between these layers
    let edges : Array[(String, String)] = []
    for node in south {
      match upper_neighbors.get(node) {
        Some(neighbors) =>
          for neighbor in neighbors {
            edges.push((neighbor, node))
          }
        None => ()
      }
    }
    total = total + count_crossings_fast(north, south, edges)
  }
  total
}

///|
/// Count all crossings with weighted edges
pub fn count_all_crossings_weighted(
  layers : Array[Array[String]],
  upper_neighbors : Map[String, Array[String]],
  edge_weights : Map[(String, String), Double],
) -> Double {
  let mut total = 0.0
  for i = 1; i < layers.length(); i = i + 1 {
    let north = layers[i - 1]
    let south = layers[i]
    // Collect edges with weights
    let edges : Array[(String, String, Double)] = []
    for node in south {
      match upper_neighbors.get(node) {
        Some(neighbors) =>
          for neighbor in neighbors {
            let weight = edge_weights.get((neighbor, node)).unwrap_or(1.0)
            edges.push((neighbor, node, weight))
          }
        None => ()
      }
    }
    total = total + count_crossings_fenwick(north, south, edges)
  }
  total
}

///|
/// Sort edges by north position (first element of tuple)
fn sort_edges_by_north(edges : Array[(Int, Int, Double)]) -> Unit {
  // Insertion sort for stability
  let n = edges.length()
  for i = 1; i < n; i = i + 1 {
    let key = edges[i]
    let (key_north, _, _) = key
    let mut j = i - 1
    while j >= 0 {
      let (j_north, _, _) = edges[j]
      if j_north > key_north {
        edges[j + 1] = edges[j]
        j = j - 1
      } else {
        break
      }
    }
    edges[j + 1] = key
  }
}

///|
/// Deep copy layers for storing best result
pub fn copy_layers(layers : Array[Array[String]]) -> Array[Array[String]] {
  let result : Array[Array[String]] = []
  for layer in layers {
    result.push(layer.copy())
  }
  result
}
