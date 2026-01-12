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
/// ELK.js Port for MoonBit - Bridge Functions
/// Convert between GraphInput and ELK types

///|
/// Convert a diago GraphInput to an ELK graph structure
pub fn from_graph(graph : @graph.GraphInput) -> ElkNode {
  let root = ElkNode::new(graph.name)
  for obj in graph.objects {
    let node = ElkNode::new(obj.id)
    root.add_child(node)
  }
  for edge in graph.edges {
    let elk_edge = ElkEdge::new(
      "e" + edge.index.to_string(),
      edge.src_id,
      edge.dst_id,
    )
    root.add_edge(elk_edge)
  }
  root
}

///|
/// Apply ELK layout results back to a diago GraphInput (no-op placeholder).
pub fn to_graph(_elk_node : ElkNode, _graph : @graph.GraphInput) -> Unit {
  ()
}
