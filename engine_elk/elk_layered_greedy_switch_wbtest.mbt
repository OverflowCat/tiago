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
/// Greedy switch tests ported from elk-reference.

///|
fn build_cross_graph() -> LGraph {
  // Two-layer crossing graph:
  // layer0: a0, a1
  // layer1: b0, b1
  // edges: a0 -> b1, a1 -> b0
  let graph = LGraph::new("g")
  let a0 = LNode::new("a0", Normal)
  a0.layer = 0
  let a1 = LNode::new("a1", Normal)
  a1.layer = 0
  let b0 = LNode::new("b0", Normal)
  b0.layer = 1
  let b1 = LNode::new("b1", Normal)
  b1.layer = 1
  graph.add_node(a0)
  graph.add_node(a1)
  graph.add_node(b0)
  graph.add_node(b1)
  let e0 = LEdge::new("e0", "a0", "b1")
  a0.outgoing_edges.push(e0)
  b1.incoming_edges.push(e0)
  graph.edges.push(e0)
  let e1 = LEdge::new("e1", "a1", "b0")
  a1.outgoing_edges.push(e1)
  b0.incoming_edges.push(e1)
  graph.edges.push(e1)
  graph.initialize_layers()
  graph
}

///|
test "elk-reference: greedy switch (one-sided) switches second layer" {
  let graph = build_cross_graph()
  // Match elk-reference GreedySwitchProcessorTest#shouldSwitchCross expectation for
  // ONE_SIDED_GREEDY_SWITCH: keep layer0 order, switch layer1 order.
  _greedy_switch(graph, 10)
  assert_eq(graph.layers[0].nodes[0].id, "a0")
  assert_eq(graph.layers[0].nodes[1].id, "a1")
  assert_eq(graph.layers[1].nodes[0].id, "b1")
  assert_eq(graph.layers[1].nodes[1].id, "b0")
}

///|
test "elk-reference: greedy switch (two-sided) switches first layer" {
  let graph = build_cross_graph()
  // Match elk-reference GreedySwitchProcessorTest#shouldSwitchCross expectation for
  // TWO_SIDED_GREEDY_SWITCH: switch layer0 order, keep layer1 order.
  greedy_switch_two_sided(graph, 10)
  assert_eq(graph.layers[0].nodes[0].id, "a1")
  assert_eq(graph.layers[0].nodes[1].id, "a0")
  assert_eq(graph.layers[1].nodes[0].id, "b0")
  assert_eq(graph.layers[1].nodes[1].id, "b1")
}

///|
fn build_cross_graph_multiple_edges() -> LGraph {
  // elk-reference TestGraphCreator#getMultipleEdgesBetweenSameNodesGraph
  let graph = LGraph::new("g")
  let a0 = LNode::new("a0", Normal)
  a0.layer = 0
  let a1 = LNode::new("a1", Normal)
  a1.layer = 0
  let b0 = LNode::new("b0", Normal)
  b0.layer = 1
  let b1 = LNode::new("b1", Normal)
  b1.layer = 1
  graph.add_node(a0)
  graph.add_node(a1)
  graph.add_node(b0)
  graph.add_node(b1)
  fn add_edge(graph : LGraph, src : LNode, dst : LNode) -> Unit {
    let edge = LEdge::new(
      "e" + graph.edges.length().to_string(),
      src.id,
      dst.id,
    )
    src.outgoing_edges.push(edge)
    dst.incoming_edges.push(edge)
    graph.edges.push(edge)
  }

  add_edge(graph, a0, b1)
  add_edge(graph, a0, b1)
  add_edge(graph, a1, b0)
  add_edge(graph, a1, b0)
  graph.initialize_layers()
  graph
}

///|
test "elk-reference: greedy switch (one-sided) multiple edges" {
  let graph = build_cross_graph_multiple_edges()
  _greedy_switch(graph, 10)
  assert_eq(graph.layers[0].nodes[0].id, "a0")
  assert_eq(graph.layers[0].nodes[1].id, "a1")
  assert_eq(graph.layers[1].nodes[0].id, "b1")
  assert_eq(graph.layers[1].nodes[1].id, "b0")
}

///|
test "elk-reference: greedy switch (two-sided) multiple edges" {
  let graph = build_cross_graph_multiple_edges()
  greedy_switch_two_sided(graph, 10)
  assert_eq(graph.layers[0].nodes[0].id, "a1")
  assert_eq(graph.layers[0].nodes[1].id, "a0")
  assert_eq(graph.layers[1].nodes[0].id, "b0")
  assert_eq(graph.layers[1].nodes[1].id, "b1")
}

///|
fn build_cross_graph_with_self_loops() -> LGraph {
  // elk-reference TestGraphCreator#getCrossWithManySelfLoopsGraph (simplified)
  let graph = build_cross_graph()
  fn add_self_loops(graph : LGraph, node : LNode) -> Unit {
    for i = 0; i < 3; i = i + 1 {
      let edge = LEdge::new(
        "e" + graph.edges.length().to_string(),
        node.id,
        node.id,
      )
      node.outgoing_edges.push(edge)
      node.incoming_edges.push(edge)
      graph.edges.push(edge)
    }
  }

  add_self_loops(graph, graph.node_map["a0"])
  add_self_loops(graph, graph.node_map["a1"])
  add_self_loops(graph, graph.node_map["b0"])
  add_self_loops(graph, graph.node_map["b1"])
  graph
}

///|
test "elk-reference: greedy switch (one-sided) self loops" {
  let graph = build_cross_graph_with_self_loops()
  _greedy_switch(graph, 10)
  assert_eq(graph.layers[0].nodes[0].id, "a0")
  assert_eq(graph.layers[0].nodes[1].id, "a1")
  assert_eq(graph.layers[1].nodes[0].id, "b1")
  assert_eq(graph.layers[1].nodes[1].id, "b0")
}

///|
test "elk-reference: greedy switch (two-sided) self loops" {
  let graph = build_cross_graph_with_self_loops()
  greedy_switch_two_sided(graph, 10)
  assert_eq(graph.layers[0].nodes[0].id, "a1")
  assert_eq(graph.layers[0].nodes[1].id, "a0")
  assert_eq(graph.layers[1].nodes[0].id, "b0")
  assert_eq(graph.layers[1].nodes[1].id, "b1")
}
