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
/// Virtual/Dummy Nodes for Long Edge Routing
///
/// In Sugiyama layout, edges that span multiple layers are split by
/// inserting virtual (dummy) nodes at each intermediate layer. This:
/// 1. Improves edge crossing minimization
/// 2. Creates better edge routing paths
/// 3. Produces more aesthetically pleasing diagrams

///|
/// Result of virtual node insertion
pub(all) struct VirtualNodeResult {
  /// Updated layer assignment including virtual nodes
  layer_assignment : LayerAssignment
  /// Map from edge index to list of virtual node IDs for that edge
  edge_virtual_nodes : Map[Int, Array[String]]
  /// Set of virtual node IDs (for identification during routing)
  virtual_nodes : Map[String, Bool]
}

///|
/// Insert virtual nodes for edges spanning multiple layers
pub fn insert_virtual_nodes(
  graph : @graph.GraphInput,
  layer_result : LayerAssignment,
  cycle_result : CycleBreakResult,
) -> VirtualNodeResult {
  let edge_virtual_nodes : Map[Int, Array[String]] = {}
  let virtual_nodes : Map[String, Bool] = {}
  // Copy the existing layer structures
  let layers : Map[String, Int] = {}
  for entry in layer_result.layers {
    layers[entry.0] = entry.1
  }
  let nodes_by_layer : Array[Array[String]] = []
  for layer in layer_result.nodes_by_layer {
    nodes_by_layer.push(layer.copy())
  }
  // Ensure we have enough layers
  while nodes_by_layer.length() < layer_result.layer_count {
    nodes_by_layer.push([])
  }
  // Process each edge
  for edge in graph.edges {
    let src = get_effective_src(edge, cycle_result)
    let dst = get_effective_dst(edge, cycle_result)
    let src_layer = layers.get(src).unwrap_or(0)
    let dst_layer = layers.get(dst).unwrap_or(0)
    // Check if edge spans multiple layers
    let span = dst_layer - src_layer
    if span > 1 {
      // Create virtual nodes for intermediate layers
      let virtual_ids : Array[String] = []
      for layer_idx = src_layer + 1
          layer_idx < dst_layer
          layer_idx = layer_idx + 1 {
        let virtual_id = "__virtual_\{edge.index}_\{layer_idx}"
        virtual_ids.push(virtual_id)
        virtual_nodes[virtual_id] = true
        layers[virtual_id] = layer_idx
        // Add to the layer
        if layer_idx < nodes_by_layer.length() {
          nodes_by_layer[layer_idx].push(virtual_id)
        }
      }
      edge_virtual_nodes[edge.index] = virtual_ids
    }
  }
  // Build updated layer assignment
  let new_layer_result = LayerAssignment::{
    layers,
    layer_count: layer_result.layer_count,
    nodes_by_layer,
  }
  { layer_assignment: new_layer_result, edge_virtual_nodes, virtual_nodes }
}

///|
/// Check if a node ID is a virtual node
pub fn is_virtual_node(node_id : String) -> Bool {
  node_id.has_prefix("__virtual_")
}

///|
/// Get the edge index from a virtual node ID
pub fn get_virtual_edge_index(node_id : String) -> Int? {
  if not(node_id.has_prefix("__virtual_")) {
    return None
  }
  // Format: __virtual_{edge_index}_{layer}
  let parts = split_string(node_id, '_')
  if parts.length() >= 3 {
    parse_int(parts[2])
  } else {
    None
  }
}

///|
/// Split a string by a delimiter character
fn split_string(s : String, delim : Char) -> Array[String] {
  let parts : Array[String] = []
  let buf = StringBuilder::new()
  for c in s {
    if c == delim {
      parts.push(buf.to_string())
      buf.reset()
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    parts.push(buf.to_string())
  }
  parts
}

///|
/// Parse an integer from a string
fn parse_int(s : String) -> Int? {
  let mut result = 0
  let mut has_digit = false
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
      has_digit = true
    } else {
      return None
    }
  }
  if has_digit {
    Some(result)
  } else {
    None
  }
}
