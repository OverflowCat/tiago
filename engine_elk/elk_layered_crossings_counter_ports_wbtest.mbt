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
/// Port-order-sensitive crossing counting tests ported from elk-reference
/// `CrossingsCounterTest`.

///|
fn add_port_on_side(node : LNode, side : ElkPortSide) -> LPort {
  let port = LPort::new(node.id + "_p" + node.ports.length().to_string())
  port.side = side
  node.ports.push(port)
  port
}

///|
fn add_east_west_edge(graph : LGraph, left : LNode, right : LNode) -> Unit {
  let lp = add_port_on_side(left, East)
  let rp = add_port_on_side(right, West)
  let e = LEdge::new("e" + graph.edges.length().to_string(), left.id, right.id)
  e.source_port_id = Some(lp.id)
  e.target_port_id = Some(rp.id)
  left.outgoing_edges.push(e)
  right.incoming_edges.push(e)
  graph.edges.push(e)
}

///|
fn add_edge_between_ports(
  graph : LGraph,
  src : (LNode, LPort),
  dst : (LNode, LPort),
) -> Unit {
  let (src_node, src_port) = src
  let (dst_node, dst_port) = dst
  let e = LEdge::new(
    "e" + graph.edges.length().to_string(),
    src_node.id,
    dst_node.id,
  )
  e.source_port_id = Some(src_port.id)
  e.target_port_id = Some(dst_port.id)
  src_node.outgoing_edges.push(e)
  dst_node.incoming_edges.push(e)
  graph.edges.push(e)
}

///|
test "elk-reference: countCrossingsBetweenPorts givenWesternCrossings" {
  let graph = LGraph::new("g")
  let l0 = LNode::new("l0", Normal)
  l0.layer = 0
  let l1 = LNode::new("l1", Normal)
  l1.layer = 0
  let r0 = LNode::new("r0", Normal)
  r0.layer = 1
  let r1 = LNode::new("r1", Normal)
  r1.layer = 1
  graph.add_node(l0)
  graph.add_node(l1)
  graph.add_node(r0)
  graph.add_node(r1)
  add_east_west_edge(graph, l0, r1)
  add_east_west_edge(graph, l1, r1)
  add_east_west_edge(graph, l1, r0)
  graph.initialize_layers()
  let counter = CrossingsCounter::new()
  counter.init_for_counting_between(
    graph.layers[0].nodes,
    graph.layers[1].nodes,
  )
  let (c, _) = counter.count_crossings_between_ports_in_both_orders(
    r1.ports[1],
    r1.ports[0],
  )
  assert_eq(c, 1)
}

///|
test "elk-reference: countCrossingsBetweenPorts GivenCrossingsOnEasternSide" {
  let graph = LGraph::new("g")
  let l0 = LNode::new("l0", Normal)
  l0.layer = 0
  let r0 = LNode::new("r0", Normal)
  r0.layer = 1
  let r1 = LNode::new("r1", Normal)
  r1.layer = 1
  graph.add_node(l0)
  graph.add_node(r0)
  graph.add_node(r1)
  add_east_west_edge(graph, l0, r1)
  add_east_west_edge(graph, l0, r0)
  graph.initialize_layers()
  let counter = CrossingsCounter::new()
  counter.init_for_counting_between(
    graph.layers[0].nodes,
    graph.layers[1].nodes,
  )
  let (c, _) = counter.count_crossings_between_ports_in_both_orders(
    l0.ports[0],
    l0.ports[1],
  )
  assert_eq(c, 1)
}

///|
test "elk-reference: countingTwoDifferentGraphs does not interfere" {
  let graph = LGraph::new("g")
  let left : Array[LNode] = []
  let right : Array[LNode] = []
  for i = 0; i < 3; i = i + 1 {
    let n = LNode::new("l" + i.to_string(), Normal)
    n.layer = 0
    graph.add_node(n)
    left.push(n)
  }
  for i = 0; i < 3; i = i + 1 {
    let n = LNode::new("r" + i.to_string(), Normal)
    n.layer = 1
    graph.add_node(n)
    right.push(n)
  }
  let left_node = left[1]
  let p0 = add_port_on_side(left_node, East)
  let p1 = add_port_on_side(left_node, East)

  // Edges in the same order as elk-reference.
  add_east_west_edge(graph, left[2], right[1])
  add_edge_between_ports(
    graph,
    (left_node, p0),
    (right[1], add_port_on_side(right[1], West)),
  )
  add_edge_between_ports(
    graph,
    (left_node, p1),
    (right[0], add_port_on_side(right[0], West)),
  )
  add_east_west_edge(graph, left[0], right[0])
  graph.initialize_layers()
  let counter = CrossingsCounter::new()
  counter.init_for_counting_between(left, right)
  let (before, _) = counter.count_crossings_between_ports_in_both_orders(
    left_node.ports[0],
    left_node.ports[1],
  )
  assert_eq(before, 1)
  counter.switch_ports(p0, p1)
  // Swap ports on the node.
  let tmp = left_node.ports[0]
  left_node.ports[0] = left_node.ports[1]
  left_node.ports[1] = tmp
  let (after, _) = counter.count_crossings_between_ports_in_both_orders(
    left_node.ports[0],
    left_node.ports[1],
  )
  assert_eq(after, 0)
}

///|
test "elk-reference: countCrossingsBetweenPorts twoEdgesIntoSamePort" {
  let graph = LGraph::new("g")
  let top_left = LNode::new("lt", Normal)
  top_left.layer = 0
  let bottom_left = LNode::new("lb", Normal)
  bottom_left.layer = 0
  let top_right = LNode::new("rt", Normal)
  top_right.layer = 1
  let bottom_right = LNode::new("rb", Normal)
  bottom_right.layer = 1
  graph.add_node(top_left)
  graph.add_node(bottom_left)
  graph.add_node(top_right)
  graph.add_node(bottom_right)
  add_east_west_edge(graph, top_left, bottom_right)
  let bottom_left_port = add_port_on_side(bottom_left, East)
  let top_right_port = add_port_on_side(top_right, West)
  add_edge_between_ports(
    graph,
    (bottom_left, bottom_left_port),
    (top_right, top_right_port),
  )
  add_edge_between_ports(
    graph,
    (bottom_left, bottom_left_port),
    (top_right, top_right_port),
  )
  graph.initialize_layers()
  let counter = CrossingsCounter::new()
  counter.init_for_counting_between(
    graph.layers[0].nodes,
    graph.layers[1].nodes,
  )

  // In our simplified model, top_left's first port is the one created by add_east_west_edge.
  let (c, _) = counter.count_crossings_between_ports_in_both_orders(
    bottom_left_port,
    top_left.ports[0],
  )
  assert_eq(c, 2)
}
