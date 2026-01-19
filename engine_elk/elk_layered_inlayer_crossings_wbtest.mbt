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
/// In-layer crossing counting tests ported from elk-reference.

///|
fn add_port_on_side_inlayer(node : LNode, side : ElkPortSide) -> LPort {
  let port = LPort::new(node.id + "_p" + node.ports.length().to_string())
  port.side = side
  node.ports.push(port)
  port
}

///|
fn add_in_layer_edge(
  graph : LGraph,
  src : LNode,
  dst : LNode,
  side : ElkPortSide,
) -> Unit {
  let sp = add_port_on_side_inlayer(src, side)
  let tp = add_port_on_side_inlayer(dst, side)
  let e = LEdge::new("e" + graph.edges.length().to_string(), src.id, dst.id)
  e.source_port_id = Some(sp.id)
  e.target_port_id = Some(tp.id)
  src.outgoing_edges.push(e)
  dst.incoming_edges.push(e)
  graph.edges.push(e)
}

///|
test "elk-reference: longInLayerCrossings" {
  // CrossingsCounterTest#longInLayerCrossings
  let graph = LGraph::new("g")
  let nodes : Array[LNode] = []
  for i = 0; i < 5; i = i + 1 {
    let n = LNode::new("n" + i.to_string(), Normal)
    n.layer = 0
    graph.add_node(n)
    nodes.push(n)
  }
  add_in_layer_edge(graph, nodes[0], nodes[1], East)
  add_in_layer_edge(graph, nodes[1], nodes[3], East)
  add_in_layer_edge(graph, nodes[2], nodes[4], East)
  graph.initialize_layers()
  let count = count_in_layer_crossings_on_side(graph.layers[0].nodes, East)
  assert_eq(count, 1)
}
