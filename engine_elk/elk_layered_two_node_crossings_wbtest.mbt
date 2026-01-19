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
/// Two-node between-layer crossing tests ported from elk-reference
/// `BetweenLayerEdgeTwoNodeCrossingsCounterTest`.

///|
fn port_rank_local(node : LNode, port_id : String?) -> Int {
  match port_id {
    Some(pid) => {
      for i, p in node.ports {
        if p.id == pid {
          return i
        }
      }
      0
    }
    None => 0
  }
}

///|
fn build_pos_map(nodes : Array[LNode]) -> Map[String, Int] {
  let pos : Map[String, Int] = {}
  for i, n in nodes {
    pos[n.id] = i
  }
  pos
}

///|
fn between_layer_crossings_for_two_nodes(
  prev : Array[LNode]?,
  curr : Array[LNode],
  next : Array[LNode]?,
  upper_idx : Int,
  lower_idx : Int,
) -> (Int, Int, Int) {
  // Returns (both, west/incoming, east/outgoing)
  let upper = curr[upper_idx]
  let lower = curr[lower_idx]
  let scale = 10_000
  let mut incoming = 0
  match prev {
    Some(prev_nodes) => {
      let prev_pos = build_pos_map(prev_nodes)
      // crossings determined by source order inversion.
      for e_u in upper.incoming_edges {
        match prev_pos.get(e_u.source_id) {
          Some(su) => {
            let src_u = prev_nodes[su]
            let ru = su * scale + port_rank_local(src_u, e_u.source_port_id)
            for e_l in lower.incoming_edges {
              match prev_pos.get(e_l.source_id) {
                Some(sl) => {
                  let src_l = prev_nodes[sl]
                  let rl = sl * scale +
                    port_rank_local(src_l, e_l.source_port_id)
                  if ru > rl {
                    incoming = incoming + 1
                  }
                }
                None => ()
              }
            }
          }
          None => ()
        }
      }
    }
    None => ()
  }
  let mut outgoing = 0
  match next {
    Some(next_nodes) => {
      let next_pos = build_pos_map(next_nodes)
      // crossings determined by target order inversion.
      for e_u in upper.outgoing_edges {
        match next_pos.get(e_u.target_id) {
          Some(tu) => {
            let tgt_u = next_nodes[tu]
            let ru = tu * scale + port_rank_local(tgt_u, e_u.target_port_id)
            for e_l in lower.outgoing_edges {
              match next_pos.get(e_l.target_id) {
                Some(tl) => {
                  let tgt_l = next_nodes[tl]
                  let rl = tl * scale +
                    port_rank_local(tgt_l, e_l.target_port_id)
                  if ru > rl {
                    outgoing = outgoing + 1
                  }
                }
                None => ()
              }
            }
          }
          None => ()
        }
      }
    }
    None => ()
  }
  (incoming + outgoing, incoming, outgoing)
}

///|
fn add_port_two_node(node : LNode, side : ElkPortSide) -> LPort {
  let port = LPort::new(node.id + "_p" + node.ports.length().to_string())
  port.side = side
  node.ports.push(port)
  port
}

///|
fn add_edge_between_nodes(graph : LGraph, src : LNode, dst : LNode) -> Unit {
  let sp = add_port_two_node(src, East)
  let tp = add_port_two_node(dst, West)
  let e = LEdge::new("e" + graph.edges.length().to_string(), src.id, dst.id)
  e.source_port_id = Some(sp.id)
  e.target_port_id = Some(tp.id)
  src.outgoing_edges.push(e)
  dst.incoming_edges.push(e)
  graph.edges.push(e)
}

///|
fn add_self_loop(graph : LGraph, node : LNode) -> Unit {
  let sp = add_port_two_node(node, East)
  let tp = add_port_two_node(node, East)
  let e = LEdge::new("e" + graph.edges.length().to_string(), node.id, node.id)
  e.source_port_id = Some(sp.id)
  e.target_port_id = Some(tp.id)
  node.outgoing_edges.push(e)
  node.incoming_edges.push(e)
  graph.edges.push(e)
}

///|
test "elk-reference: twoNodeNoEdges" {
  let graph = LGraph::new("g")
  let a = LNode::new("a", Normal)
  a.layer = 0
  let b = LNode::new("b", Normal)
  b.layer = 0
  graph.add_node(a)
  graph.add_node(b)
  graph.initialize_layers()
  let (both, west, east) = between_layer_crossings_for_two_nodes(
    None,
    graph.layers[0].nodes,
    None,
    0,
    1,
  )
  assert_eq(both, 0)
  assert_eq(west, 0)
  assert_eq(east, 0)
}

///|
test "elk-reference: crossFormed" {
  // left: l0,l1 ; right: r0,r1
  // edges: l0->r1, l1->r0
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
  add_edge_between_nodes(graph, l0, r1)
  add_edge_between_nodes(graph, l1, r0)
  graph.initialize_layers()
  let left = graph.layers[0].nodes
  let right = graph.layers[1].nodes
  let (both_ul, west_ul, east_ul) = between_layer_crossings_for_two_nodes(
    Some(left),
    right,
    None,
    0,
    1,
  )
  assert_eq(both_ul, 1)
  assert_eq(west_ul, 1)
  assert_eq(east_ul, 0)
  let (both_lu, west_lu, east_lu) = between_layer_crossings_for_two_nodes(
    Some(left),
    right,
    None,
    1,
    0,
  )
  assert_eq(both_lu, 0)
  assert_eq(west_lu, 0)
  assert_eq(east_lu, 0)
}

///|
test "elk-reference: crossFormedMultipleEdgesBetweenSameNodes" {
  // Same as crossFormed, but 2 edges each => 4 crossings.
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
  add_edge_between_nodes(graph, l0, r1)
  add_edge_between_nodes(graph, l0, r1)
  add_edge_between_nodes(graph, l1, r0)
  add_edge_between_nodes(graph, l1, r0)
  graph.initialize_layers()
  let left = graph.layers[0].nodes
  let right = graph.layers[1].nodes
  let (both_ul, west_ul, east_ul) = between_layer_crossings_for_two_nodes(
    Some(left),
    right,
    None,
    0,
    1,
  )
  assert_eq(both_ul, 4)
  assert_eq(west_ul, 4)
  assert_eq(east_ul, 0)
}

///|
test "elk-reference: crossWithExtraEdgeInBetween" {
  // left nodes: l0,l1,l2 ; right nodes: r0,r1,r2
  // edges: l0->r2, l1->r1, l2->r0
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
  add_edge_between_nodes(graph, left[0], right[2])
  add_edge_between_nodes(graph, left[1], right[1])
  add_edge_between_nodes(graph, left[2], right[0])
  graph.initialize_layers()
  let l = graph.layers[0].nodes
  let r = graph.layers[1].nodes

  // Match elk-reference test: upper=0, lower=2 in the right layer.
  let (both, west, east) = between_layer_crossings_for_two_nodes(
    Some(l),
    r,
    None,
    0,
    2,
  )
  assert_eq(both, 1)
  assert_eq(west, 1)
  assert_eq(east, 0)
}

///|
test "elk-reference: ignoreSelfLoops" {
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
  add_edge_between_nodes(graph, l0, r1)
  add_edge_between_nodes(graph, l1, r0)
  add_self_loop(graph, l0)
  add_self_loop(graph, l1)
  add_self_loop(graph, r0)
  add_self_loop(graph, r1)
  graph.initialize_layers()
  let left = graph.layers[0].nodes
  let right = graph.layers[1].nodes
  let (both, west, east) = between_layer_crossings_for_two_nodes(
    Some(left),
    right,
    None,
    0,
    1,
  )
  assert_eq(both, 1)
  assert_eq(west, 1)
  assert_eq(east, 0)
}
