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
/// Crossing counting tests ported from elk-reference `CrossingsCounterTest`.

///|
fn add_port(node : LNode, id : String) -> Unit {
  let port = LPort::new(id)
  node.ports.push(port)
}

///|
fn add_edge(
  graph : LGraph,
  src : LNode,
  dst : LNode,
  source_port_id : String?,
  target_port_id : String?,
) -> Unit {
  let edge = LEdge::new("e" + graph.edges.length().to_string(), src.id, dst.id)
  edge.source_port_id = source_port_id
  edge.target_port_id = target_port_id
  src.outgoing_edges.push(edge)
  dst.incoming_edges.push(edge)
  graph.edges.push(edge)
}

///|
fn build_cross_form() -> LGraph {
  // elk-reference TestGraphCreator#getCrossFormedGraph
  let graph = LGraph::new("g")
  let left_top = LNode::new("lt", Normal)
  left_top.layer = 0
  let left_bottom = LNode::new("lb", Normal)
  left_bottom.layer = 0
  let right_top = LNode::new("rt", Normal)
  right_top.layer = 1
  let right_bottom = LNode::new("rb", Normal)
  right_bottom.layer = 1
  graph.add_node(left_top)
  graph.add_node(left_bottom)
  graph.add_node(right_top)
  graph.add_node(right_bottom)
  // Ports are optional for node-level crossings.
  add_edge(graph, left_top, right_bottom, None, None)
  add_edge(graph, left_bottom, right_top, None, None)
  graph.initialize_layers()
  graph
}

///|
test "elk-reference: crossings between layers (crossFormed)" {
  let graph = build_cross_form()
  assert_eq(count_crossings_between_layers(graph.layers[0], graph.layers[1]), 1)
}

///|
test "elk-reference: crossings between layers (multiple edges between corners)" {
  // elk-reference CrossingsCounterTest#countCrossingsBetweenLayers_crossFormedMultipleEdgesBetweenSameNodes
  let graph = LGraph::new("g")
  let lt = LNode::new("lt", Normal)
  lt.layer = 0
  let lb = LNode::new("lb", Normal)
  lb.layer = 0
  let rt = LNode::new("rt", Normal)
  rt.layer = 1
  let rb = LNode::new("rb", Normal)
  rb.layer = 1
  graph.add_node(lt)
  graph.add_node(lb)
  graph.add_node(rt)
  graph.add_node(rb)

  // Two parallel edges in each direction.
  add_edge(graph, lt, rb, None, None)
  add_edge(graph, lt, rb, None, None)
  add_edge(graph, lb, rt, None, None)
  add_edge(graph, lb, rt, None, None)
  graph.initialize_layers()
  assert_eq(count_crossings_between_layers(graph.layers[0], graph.layers[1]), 4)
}

///|
test "elk-reference: crossings between layers (cross with extra edge in between)" {
  // elk-reference TestGraphCreator#getCrossWithExtraEdgeInBetweenGraph
  let graph = LGraph::new("g")
  let left0 = LNode::new("l0", Normal)
  left0.layer = 0
  let left1 = LNode::new("l1", Normal)
  left1.layer = 0
  let left2 = LNode::new("l2", Normal)
  left2.layer = 0
  let right0 = LNode::new("r0", Normal)
  right0.layer = 1
  let right1 = LNode::new("r1", Normal)
  right1.layer = 1
  let right2 = LNode::new("r2", Normal)
  right2.layer = 1
  graph.add_node(left0)
  graph.add_node(left1)
  graph.add_node(left2)
  graph.add_node(right0)
  graph.add_node(right1)
  graph.add_node(right2)
  add_edge(graph, left0, right2, None, None)
  add_edge(graph, left1, right1, None, None)
  add_edge(graph, left2, right0, None, None)
  graph.initialize_layers()
  assert_eq(count_crossings_between_layers(graph.layers[0], graph.layers[1]), 3)
}

///|
test "elk-reference: crossings between layers ignore self loops" {
  // elk-reference TestGraphCreator#getCrossWithManySelfLoopsGraph
  let graph = build_cross_form()
  let lt = graph.node_map["lt"]
  let lb = graph.node_map["lb"]
  let rt = graph.node_map["rt"]
  let rb = graph.node_map["rb"]
  fn add_self_loops(graph : LGraph, node : LNode) -> Unit {
    // Add a few self loops; between-layer crossing counter should ignore them.
    add_edge(graph, node, node, None, None)
    add_edge(graph, node, node, None, None)
    add_edge(graph, node, node, None, None)
  }

  add_self_loops(graph, lt)
  add_self_loops(graph, lb)
  add_self_loops(graph, rt)
  add_self_loops(graph, rb)
  assert_eq(count_crossings_between_layers(graph.layers[0], graph.layers[1]), 1)
}

///|
test "elk-reference: crossings between layers fixed port order on single source" {
  // elk-reference TestGraphCreator#getFixedPortOrderGraph
  let graph = LGraph::new("g")
  let left = LNode::new("left", Normal)
  left.layer = 0
  let right_top = LNode::new("rt", Normal)
  right_top.layer = 1
  let right_bottom = LNode::new("rb", Normal)
  right_bottom.layer = 1

  // Create ports on the left node in edge creation order.
  add_port(left, "p0")
  add_port(left, "p1")
  graph.add_node(left)
  graph.add_node(right_top)
  graph.add_node(right_bottom)

  // Create edges in the same order as elk-reference: bottom, then top.
  add_edge(graph, left, right_bottom, Some("p0"), None)
  add_edge(graph, left, right_top, Some("p1"), None)
  graph.initialize_layers()
  assert_eq(count_crossings_between_layers(graph.layers[0], graph.layers[1]), 1)
}

///|
test "elk-reference: crossings between layers intoSamePort" {
  // elk-reference CrossingsCounterTest#countCrossingsBetweenLayers_intoSamePort
  let graph = LGraph::new("g")
  let lt = LNode::new("lt", Normal)
  lt.layer = 0
  let lb = LNode::new("lb", Normal)
  lb.layer = 0
  let rt = LNode::new("rt", Normal)
  rt.layer = 1
  let rb = LNode::new("rb", Normal)
  rb.layer = 1
  add_port(lb, "lb_p0")
  add_port(lb, "lb_p1")
  add_port(rt, "rt_p0")
  graph.add_node(lt)
  graph.add_node(lb)
  graph.add_node(rt)
  graph.add_node(rb)
  add_edge(graph, lt, rb, None, None)
  add_edge(graph, lb, rt, Some("lb_p0"), Some("rt_p0"))
  add_edge(graph, lb, rt, Some("lb_p1"), Some("rt_p0"))
  graph.initialize_layers()
  assert_eq(count_crossings_between_layers(graph.layers[0], graph.layers[1]), 2)
}

///|
test "elk-reference: crossings between layers fixedPortOrderCrossingOnTwoNodes" {
  // elk-reference CrossingsCounterTest#countCrossingsBetweenLayers_fixedPortOrderCrossingOnTwoNodes
  let graph = LGraph::new("g")
  let left = LNode::new("left", Normal)
  left.layer = 0
  let right = LNode::new("right", Normal)
  right.layer = 1
  add_port(left, "l0")
  add_port(left, "l1")
  add_port(right, "r0")
  add_port(right, "r1")
  graph.add_node(left)
  graph.add_node(right)

  // Cross by connecting opposite port order.
  add_edge(graph, left, right, Some("l0"), Some("r1"))
  add_edge(graph, left, right, Some("l1"), Some("r0"))
  graph.initialize_layers()
  assert_eq(count_crossings_between_layers(graph.layers[0], graph.layers[1]), 1)
}
