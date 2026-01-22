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
/// Tests for the layered layout algorithm
test "simple graph layout" {
  // Create a simple graph: A -> B -> C
  let root = ElkNode::new("root")
  root.width = 200.0
  root.height = 200.0
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  let node_c = ElkNode::with_size("c", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_child(node_c)
  let edge_ab = ElkEdge::new("e1", "a", "b")
  let edge_bc = ElkEdge::new("e2", "b", "c")
  root.add_edge(edge_ab)
  root.add_edge(edge_bc)

  // Run layout
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)

  // Verify nodes are positioned (y increases for each layer in Down direction)
  assert_true(node_a.y < node_b.y)
  assert_true(node_b.y < node_c.y)
}

///|
test "barycenter ordering updates node positions" {
  let root = ElkNode::new("root")
  let u0 = ElkNode::with_size("u0", 10.0, 10.0)
  let u1 = ElkNode::with_size("u1", 10.0, 10.0)
  let v0 = ElkNode::with_size("v0", 10.0, 10.0)
  let v1 = ElkNode::with_size("v1", 10.0, 10.0)
  root.add_child(u0)
  root.add_child(u1)
  root.add_child(v0)
  root.add_child(v1)
  root.add_edge(ElkEdge::new("e0", "u0", "v1"))
  root.add_edge(ElkEdge::new("e1", "u1", "v0"))
  let graph = LGraph::from_elk_node(root)
  graph.get_node("u0").unwrap().layer = 0
  graph.get_node("u1").unwrap().layer = 0
  graph.get_node("v0").unwrap().layer = 1
  graph.get_node("v1").unwrap().layer = 1
  graph.initialize_layers()
  order_layer_by_barycenter(
    graph,
    graph.layers[1],
    graph.layers[0],
    true,
    0,
    1,
    false,
    false,
    None,
  )
  assert_true(graph.layers[1].nodes[0].id == "v1")
  assert_true(graph.layers[1].nodes[0].position == 0)
  assert_true(graph.layers[1].nodes[1].position == 1)
}

///|
test "layer sweep: keep best intermediate ordering" {
  fn total_crossings(graph : LGraph) -> Int {
    let mut total = 0
    for i = 0; i < graph.layers.length() - 1; i = i + 1 {
      total = total +
        count_crossings_between_layers(graph.layers[i], graph.layers[i + 1])
    }
    total
  }

  fn build_graph(mask : Int) -> LGraph {
    let root = ElkNode::new("root")
    let a0 = ElkNode::with_size("a0", 10.0, 10.0)
    let a1 = ElkNode::with_size("a1", 10.0, 10.0)
    let b0 = ElkNode::with_size("b0", 10.0, 10.0)
    let b1 = ElkNode::with_size("b1", 10.0, 10.0)
    let c0 = ElkNode::with_size("c0", 10.0, 10.0)
    let c1 = ElkNode::with_size("c1", 10.0, 10.0)
    root.add_child(a0)
    root.add_child(a1)
    root.add_child(b0)
    root.add_child(b1)
    root.add_child(c0)
    root.add_child(c1)
    let bits : Array[Int] = [1, 2, 4, 8, 16, 32, 64, 128]
    // a{0,1} -> b{0,1}
    for i = 0; i < 4; i = i + 1 {
      if mask / bits[i] % 2 == 1 {
        let src = if i / 2 == 0 { "a0" } else { "a1" }
        let dst = if i % 2 == 0 { "b0" } else { "b1" }
        root.add_edge(ElkEdge::new("ab" + i.to_string(), src, dst))
      }
    }
    // b{0,1} -> c{0,1}
    for i = 0; i < 4; i = i + 1 {
      if mask / bits[i + 4] % 2 == 1 {
        let src = if i / 2 == 0 { "b0" } else { "b1" }
        let dst = if i % 2 == 0 { "c0" } else { "c1" }
        root.add_edge(ElkEdge::new("bc" + i.to_string(), src, dst))
      }
    }
    let graph = LGraph::from_elk_node(root)
    graph.get_node("a0").unwrap().layer = 0
    graph.get_node("a1").unwrap().layer = 0
    graph.get_node("b0").unwrap().layer = 1
    graph.get_node("b1").unwrap().layer = 1
    graph.get_node("c0").unwrap().layer = 2
    graph.get_node("c1").unwrap().layer = 2
    graph.initialize_layers()
    graph
  }

  fn run_old(graph : LGraph, thoroughness : Int) -> Int {
    // Old behavior: run all sweeps, keep the last ordering.
    for sweep = 0; sweep < thoroughness; sweep = sweep + 1 {
      for i = 1; i < graph.layers.length(); i = i + 1 {
        order_layer_by_barycenter(
          graph,
          graph.layers[i],
          graph.layers[i - 1],
          true,
          sweep,
          1,
          true,
          false,
          None,
        )
      }
      for i = graph.layers.length() - 2; i >= 0; i = i - 1 {
        order_layer_by_barycenter(
          graph,
          graph.layers[i],
          graph.layers[i + 1],
          false,
          sweep,
          1,
          true,
          false,
          None,
        )
      }
    }
    for layer in graph.layers {
      for i, node in layer.nodes {
        node.position = i
      }
    }
    total_crossings(graph)
  }

  fn run_new(graph : LGraph, thoroughness : Int) -> Int {
    layer_sweep_barycenter_best(
      graph,
      { ..LayoutOptions::layered(), random_seed: Some(1) },
      thoroughness,
    )
    total_crossings(graph)
  }

  for mask = 0; mask < 256; mask = mask + 1 {
    let old_crossings = run_old(build_graph(mask), 2)
    let new_crossings = run_new(build_graph(mask), 2)
    assert_true(new_crossings <= old_crossings)
  }
}

///|
test "cycle breaking - simple cycle" {
  // Create a graph with a cycle: A -> B -> C -> A
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  let node_c = ElkNode::with_size("c", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_child(node_c)
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  root.add_edge(ElkEdge::new("e2", "b", "c"))
  root.add_edge(ElkEdge::new("e3", "c", "a")) // Back edge
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)

  // Should complete without error - cycle is broken
  assert_true(root.children.length() == 3)
}

///|
test "diamond graph" {
  // Create a diamond: A -> B, A -> C, B -> D, C -> D
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  let node_c = ElkNode::with_size("c", 60.0, 40.0)
  let node_d = ElkNode::with_size("d", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_child(node_c)
  root.add_child(node_d)
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  root.add_edge(ElkEdge::new("e2", "a", "c"))
  root.add_edge(ElkEdge::new("e3", "b", "d"))
  root.add_edge(ElkEdge::new("e4", "c", "d"))
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)

  // A should be above B and C, which should be above D
  assert_true(node_a.y < node_b.y)
  assert_true(node_a.y < node_c.y)
  assert_true(node_b.y < node_d.y)
  assert_true(node_c.y < node_d.y)
}

///|
test "horizontal layout direction" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  let options = LayoutOptions::layered().with_direction(LayoutDirection::Right)
  elk_layered_layout(root, options)

  // In Right direction, x should increase
  assert_true(node_a.x < node_b.x)
}

///|
test "horizontal layout direction: Left" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  let options = LayoutOptions::layered().with_direction(LayoutDirection::Left)
  elk_layered_layout(root, options)

  // In Left direction, x should decrease across layers
  assert_true(node_a.x > node_b.x)
}

///|
test "routing slots: first edge keeps midpoint" {
  let graph = LGraph::new("g")
  let s0 = LNode::new("s0", Normal)
  s0.layer = 0
  s0.x = 0.0
  s0.y = 0.0
  s0.width = 10.0
  s0.height = 10.0
  let s1 = LNode::new("s1", Normal)
  s1.layer = 0
  s1.x = 100.0
  s1.y = 0.0
  s1.width = 10.0
  s1.height = 10.0
  let t0 = LNode::new("t0", Normal)
  t0.layer = 1
  t0.x = 0.0
  t0.y = 100.0
  t0.width = 10.0
  t0.height = 10.0
  graph.add_node(s0)
  graph.add_node(s1)
  graph.add_node(t0)
  let e0 = LEdge::new("e0", "s0", "t0")
  s0.outgoing_edges.push(e0)
  t0.incoming_edges.push(e0)
  e0.bend_points.push(ElkPoint::new(0.0, 50.0))
  e0.bend_points.push(ElkPoint::new(0.0, 60.0))
  graph.edges.push(e0)
  let e1 = LEdge::new("e1", "s1", "t0")
  s1.outgoing_edges.push(e1)
  t0.incoming_edges.push(e1)
  e1.bend_points.push(ElkPoint::new(0.0, 50.0))
  e1.bend_points.push(ElkPoint::new(0.0, 60.0))
  graph.edges.push(e1)
  graph.initialize_layers()
  assign_routing_slots(graph, 10.0, true)
  assert_true((e0.bend_points[0].y - 50.0).abs() < 0.001)
  assert_true((e1.bend_points[0].y - 45.0).abs() < 0.001)
}

///|
test "vertical layout direction: Up" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  let options = LayoutOptions::layered().with_direction(LayoutDirection::Up)
  elk_layered_layout(root, options)

  // In Up direction, y should decrease across layers
  assert_true(node_a.y > node_b.y)
}

///|
test "node auto-sizing from labels" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::new("a")
  node_a.add_label(ElkLabel::new("a_label", "HelloWorld"))
  let node_b = ElkNode::new("b")
  node_b.add_label(ElkLabel::new("b_label", "X"))
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)
  assert_true(node_a.width >= 90.0)
  assert_true(node_a.height >= 40.0)
  assert_true(node_b.width >= 60.0)
  assert_true(node_b.height >= 40.0)
}

///|
test "edge label placement on long edge (label dummy)" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  let node_c = ElkNode::with_size("c", 60.0, 40.0)
  let node_d = ElkNode::with_size("d", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_child(node_c)
  root.add_child(node_d)
  root.add_edge(ElkEdge::new("e_ab", "a", "b"))
  root.add_edge(ElkEdge::new("e_bc", "b", "c"))
  root.add_edge(ElkEdge::new("e_cd", "c", "d"))
  let edge_ad = ElkEdge::new("e_ad", "a", "d")
  edge_ad.labels.push(ElkLabel::new("e_ad_label", "LABEL"))
  root.add_edge(edge_ad)
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)
  assert_true(edge_ad.labels.length() == 1)
  let label = edge_ad.labels[0]
  assert_true(label.width > 0.0)
  assert_true(label.height > 0.0)
  assert_true(label.x >= 0.0)
  assert_true(label.y >= 0.0)
}

///|
test "self-loop edge routing" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  root.add_child(node_a)
  let edge_loop = ElkEdge::new("e_loop", "a", "a")
  root.add_edge(edge_loop)
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)
  assert_true(edge_loop.sections.length() == 1)
  let section = edge_loop.sections[0]
  assert_true(section.bend_points.length() >= 4)
}

///|
test "edge end label placement: Head" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge = ElkEdge::new("e_ab", "a", "b")
  edge.labels.push(ElkLabel::new("l1", "H"))
  root.add_edge(edge)
  let options = { ..LayoutOptions::layered(), edge_label_placement: Some(Head) }
  elk_layered_layout(root, options)
  let label = edge.labels[0]
  assert_true(label.x != 0.0 || label.y != 0.0)
}

///|
test "end labels: anchor honors port_border_offset" {
  let root1 = ElkNode::new("root1")
  let node_a1 = ElkNode::with_size("a", 60.0, 40.0)
  let node_b1 = ElkNode::with_size("b", 60.0, 40.0)
  let port_a1 : ElkPort = {
    id: "pa",
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: South,
    labels: [],
    properties: ElkProperties::new(),
  }
  node_a1.add_port(port_a1)
  root1.add_child(node_a1)
  root1.add_child(node_b1)
  let edge1 = ElkEdge::new("e1", "a", "b")
  edge1.properties.set("elk.sourcePort", String("pa"))
  let l1 = ElkLabel::new("l1", "H")
  l1.properties.set("elk.edgeLabel.placement", String("HEAD"))
  edge1.labels.push(l1)
  root1.add_edge(edge1)
  elk_layered_layout(root1, {
    ..LayoutOptions::layered(),
    port_border_offset: Some(10.0),
  })
  let y_with = l1.y
  let root2 = ElkNode::new("root2")
  let node_a2 = ElkNode::with_size("a", 60.0, 40.0)
  let node_b2 = ElkNode::with_size("b", 60.0, 40.0)
  let port_a2 : ElkPort = {
    id: "pa",
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: South,
    labels: [],
    properties: ElkProperties::new(),
  }
  node_a2.add_port(port_a2)
  root2.add_child(node_a2)
  root2.add_child(node_b2)
  let edge2 = ElkEdge::new("e2", "a", "b")
  edge2.properties.set("elk.sourcePort", String("pa"))
  let l2 = ElkLabel::new("l2", "H")
  l2.properties.set("elk.edgeLabel.placement", String("HEAD"))
  edge2.labels.push(l2)
  root2.add_edge(edge2)
  elk_layered_layout(root2, LayoutOptions::layered())
  let y_default = l2.y
  assert_true((y_with - y_default + 10.0).abs() < 0.001)
}

///|
test "end labels: label_label_spacing adds extra gap" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge1 = ElkEdge::new("e1", "a", "b")
  let l1 = ElkLabel::new("l1", "H1")
  l1.properties.set("elk.edgeLabel.placement", String("HEAD"))
  let l2 = ElkLabel::new("l2", "H2")
  l2.properties.set("elk.edgeLabel.placement", String("HEAD"))
  edge1.labels.push(l1)
  edge1.labels.push(l2)
  root.add_edge(edge1)
  let options1 = { ..LayoutOptions::layered(), label_label_spacing: Some(10.0) }
  elk_layered_layout(root, options1)
  let dy_with = (l2.y - l1.y).abs()
  let edge2 = ElkEdge::new("e2", "a", "b")
  let m1 = ElkLabel::new("m1", "H1")
  m1.properties.set("elk.edgeLabel.placement", String("HEAD"))
  let m2 = ElkLabel::new("m2", "H2")
  m2.properties.set("elk.edgeLabel.placement", String("HEAD"))
  edge2.labels.push(m1)
  edge2.labels.push(m2)
  root.edges.clear()
  root.add_edge(edge2)
  elk_layered_layout(root, LayoutOptions::layered())
  let dy_default = (m2.y - m1.y).abs()
  assert_true(dy_with > dy_default + 9.0)
}

///|
test "end labels: label_port_horizontal_spacing affects perpendicular offset" {
  let root1 = ElkNode::new("root1")
  let node_a1 = ElkNode::with_size("a", 60.0, 40.0)
  let node_b1 = ElkNode::with_size("b", 60.0, 40.0)
  root1.add_child(node_a1)
  root1.add_child(node_b1)
  let edge1 = ElkEdge::new("e1", "a", "b")
  let l1 = ElkLabel::new("l1", "H")
  l1.properties.set("elk.edgeLabel.placement", String("HEAD"))
  edge1.labels.push(l1)
  root1.add_edge(edge1)
  elk_layered_layout(root1, {
    ..LayoutOptions::layered(),
    label_port_horizontal_spacing: Some(20.0),
    edge_label_spacing: Some(0.0),
    label_node_spacing: Some(0.0),
    edge_label_side_selection: Some(AlwaysUp),
  })
  let x_with = l1.x
  let root2 = ElkNode::new("root2")
  let node_a2 = ElkNode::with_size("a", 60.0, 40.0)
  let node_b2 = ElkNode::with_size("b", 60.0, 40.0)
  root2.add_child(node_a2)
  root2.add_child(node_b2)
  let edge2 = ElkEdge::new("e2", "a", "b")
  let l2 = ElkLabel::new("l2", "H")
  l2.properties.set("elk.edgeLabel.placement", String("HEAD"))
  edge2.labels.push(l2)
  root2.add_edge(edge2)
  elk_layered_layout(root2, {
    ..LayoutOptions::layered(),
    label_port_horizontal_spacing: Some(0.0),
    edge_label_spacing: Some(0.0),
    label_node_spacing: Some(0.0),
    edge_label_side_selection: Some(AlwaysUp),
  })
  let x_default = l2.x
  assert_true((x_with - x_default).abs() > 15.0)
}

///|
test "end labels: label_port_vertical_spacing affects perpendicular offset" {
  let root1 = ElkNode::new("root1")
  let node_a1 = ElkNode::with_size("a", 60.0, 40.0)
  let node_b1 = ElkNode::with_size("b", 60.0, 40.0)
  root1.add_child(node_a1)
  root1.add_child(node_b1)
  let edge1 = ElkEdge::new("e1", "a", "b")
  let l1 = ElkLabel::new("l1", "H")
  l1.properties.set("elk.edgeLabel.placement", String("HEAD"))
  edge1.labels.push(l1)
  root1.add_edge(edge1)
  elk_layered_layout(root1, {
    ..LayoutOptions::layered(),
    direction: Some(Right),
    label_port_vertical_spacing: Some(20.0),
    edge_label_spacing: Some(0.0),
    label_node_spacing: Some(0.0),
    edge_label_side_selection: Some(AlwaysUp),
  })
  let y_with = l1.y
  let root2 = ElkNode::new("root2")
  let node_a2 = ElkNode::with_size("a", 60.0, 40.0)
  let node_b2 = ElkNode::with_size("b", 60.0, 40.0)
  root2.add_child(node_a2)
  root2.add_child(node_b2)
  let edge2 = ElkEdge::new("e2", "a", "b")
  let l2 = ElkLabel::new("l2", "H")
  l2.properties.set("elk.edgeLabel.placement", String("HEAD"))
  edge2.labels.push(l2)
  root2.add_edge(edge2)
  elk_layered_layout(root2, {
    ..LayoutOptions::layered(),
    direction: Some(Right),
    label_port_vertical_spacing: Some(0.0),
    edge_label_spacing: Some(0.0),
    label_node_spacing: Some(0.0),
    edge_label_side_selection: Some(AlwaysUp),
  })
  let y_default = l2.y
  assert_true((y_with - y_default).abs() > 15.0)
}

///|
test "center labels: label_label_spacing adds extra gap" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge1 = ElkEdge::new("e1", "a", "b")
  let l1 = ElkLabel::new("l1", "C1")
  l1.properties.set("elk.edgeLabel.placement", String("CENTER"))
  let l2 = ElkLabel::new("l2", "C2")
  l2.properties.set("elk.edgeLabel.placement", String("CENTER"))
  edge1.labels.push(l1)
  edge1.labels.push(l2)
  root.add_edge(edge1)
  let options1 = { ..LayoutOptions::layered(), label_label_spacing: Some(10.0) }
  elk_layered_layout(root, options1)
  let dy_with = (l2.y - l1.y).abs()
  let edge2 = ElkEdge::new("e2", "a", "b")
  let m1 = ElkLabel::new("m1", "C1")
  m1.properties.set("elk.edgeLabel.placement", String("CENTER"))
  let m2 = ElkLabel::new("m2", "C2")
  m2.properties.set("elk.edgeLabel.placement", String("CENTER"))
  edge2.labels.push(m1)
  edge2.labels.push(m2)
  root.edges.clear()
  root.add_edge(edge2)
  elk_layered_layout(root, LayoutOptions::layered())
  let dy_default = (m2.y - m1.y).abs()
  assert_true(dy_with > dy_default + 9.0)
}

///|
test "center labels: label_port_horizontal_spacing affects perpendicular offset" {
  let root1 = ElkNode::new("root1")
  let node_a1 = ElkNode::with_size("a", 60.0, 40.0)
  let node_b1 = ElkNode::with_size("b", 60.0, 40.0)
  root1.add_child(node_a1)
  root1.add_child(node_b1)
  let edge1 = ElkEdge::new("e1", "a", "b")
  let l1 = ElkLabel::new("l1", "C")
  l1.properties.set("elk.edgeLabel.placement", String("CENTER"))
  edge1.labels.push(l1)
  root1.add_edge(edge1)
  elk_layered_layout(root1, {
    ..LayoutOptions::layered(),
    label_port_horizontal_spacing: Some(20.0),
    edge_label_spacing: Some(0.0),
    edge_label_side_selection: Some(AlwaysUp),
  })
  let x_with = l1.x
  let root2 = ElkNode::new("root2")
  let node_a2 = ElkNode::with_size("a", 60.0, 40.0)
  let node_b2 = ElkNode::with_size("b", 60.0, 40.0)
  root2.add_child(node_a2)
  root2.add_child(node_b2)
  let edge2 = ElkEdge::new("e2", "a", "b")
  let l2 = ElkLabel::new("l2", "C")
  l2.properties.set("elk.edgeLabel.placement", String("CENTER"))
  edge2.labels.push(l2)
  root2.add_edge(edge2)
  elk_layered_layout(root2, {
    ..LayoutOptions::layered(),
    label_port_horizontal_spacing: Some(0.0),
    edge_label_spacing: Some(0.0),
    edge_label_side_selection: Some(AlwaysUp),
  })
  let x_default = l2.x
  assert_true((x_with - x_default).abs() > 15.0)
}

///|
test "mixed edge labels: head + center" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge = ElkEdge::new("e_ab", "a", "b")
  let head = ElkLabel::new("l_head", "H")
  head.properties.set("elk.edgeLabel.placement", String("HEAD"))
  let center = ElkLabel::new("l_center", "C")
  edge.labels.push(head)
  edge.labels.push(center)
  root.add_edge(edge)
  elk_layered_layout(root, LayoutOptions::layered())

  // Both labels get concrete positions, and should not coincide.
  assert_true(head.x != 0.0 || head.y != 0.0)
  assert_true(center.x != 0.0 || center.y != 0.0)
  assert_true(head.y != center.y || head.x != center.x)
}

///|
test "node labels: Outside Top places label above node" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  let label_a = ElkLabel::new("la", "A")
  node_a.add_label(label_a)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  elk_layered_layout(root, {
    ..LayoutOptions::layered(),
    node_label_placement: Some([Outside, Top]),
    label_node_spacing: Some(5.0),
  })
  assert_true(label_a.y < node_a.y)
}

///|
test "port labels: Outside East places label right of node" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 80.0, 60.0)
  let node_b = ElkNode::with_size("b", 80.0, 60.0)
  let pl = ElkLabel::new("pl", "P")
  let port_a : ElkPort = {
    id: "pa",
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: East,
    labels: [pl],
    properties: ElkProperties::new(),
  }
  node_a.add_port(port_a)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge = ElkEdge::new("e1", "a", "b")
  edge.properties.set("elk.sourcePort", String("pa"))
  root.add_edge(edge)
  elk_layered_layout(root, {
    ..LayoutOptions::layered(),
    port_label_placement: Some([Outside]),
    label_node_spacing: Some(6.0),
    port_border_offset: Some(0.0),
  })
  assert_true(pl.x > node_a.x + node_a.width)
}

///|
test "port constraints: FixedPos keeps port anchors" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 80.0, 60.0)
  let node_b = ElkNode::with_size("b", 80.0, 60.0)
  let port_a : ElkPort = {
    id: "pa",
    x: 0.0,
    y: 10.0,
    width: 0.0,
    height: 0.0,
    side: East,
    labels: [],
    properties: ElkProperties::new(),
  }
  let port_b : ElkPort = {
    id: "pb",
    x: 0.0,
    y: 30.0,
    width: 0.0,
    height: 0.0,
    side: West,
    labels: [],
    properties: ElkProperties::new(),
  }
  node_a.add_port(port_a)
  node_b.add_port(port_b)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge = ElkEdge::new("e_ab", "a", "b")
  edge.properties.set("elk.sourcePort", String("pa"))
  edge.properties.set("elk.targetPort", String("pb"))
  root.add_edge(edge)
  let options = { ..LayoutOptions::layered(), port_constraints: Some(FixedPos) }
  elk_layered_layout(root, options)
  let section = edge.sections[0]
  // Anchor with port uses absolute node+port offsets.
  assert_true((section.start_point.y - node_a.y - 10.0).abs() < 0.001)
  assert_true((section.end_point.y - node_b.y - 30.0).abs() < 0.001)
}

///|
test "port constraints: FixedOrder preserves model port order" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 80.0, 60.0)
  let node_b = ElkNode::with_size("b", 80.0, 60.0)

  // Intentionally add ports in non-lexical order.
  let port_1 : ElkPort = {
    id: "p1",
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: South,
    labels: [],
    properties: ElkProperties::new(),
  }
  let port_0 : ElkPort = {
    id: "p0",
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: South,
    labels: [],
    properties: ElkProperties::new(),
  }
  node_a.add_port(port_1)
  node_a.add_port(port_0)
  root.add_child(node_a)
  root.add_child(node_b)
  let e1 = ElkEdge::new("e1", "a", "b")
  e1.properties.set("elk.sourcePort", String("p1"))
  let e2 = ElkEdge::new("e2", "a", "b")
  e2.properties.set("elk.sourcePort", String("p0"))
  root.add_edge(e1)
  root.add_edge(e2)
  let options = {
    ..LayoutOptions::layered(),
    port_constraints: Some(FixedOrder),
  }
  elk_layered_layout(root, options)

  // With FixedOrder, we preserve model port list order, so "p1" is placed
  // before "p0" along the same side.
  assert_true(e1.sections[0].start_point.x < e2.sections[0].start_point.x)
}

///|
test "port constraints: FixedRatio keeps relative port ratios" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 200.0, 60.0)
  let node_b = ElkNode::with_size("b", 200.0, 60.0)
  let port_a : ElkPort = {
    id: "pa",
    x: 0.25,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: South,
    labels: [],
    properties: ElkProperties::new(),
  }
  let port_b : ElkPort = {
    id: "pb",
    x: 0.75,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: North,
    labels: [],
    properties: ElkProperties::new(),
  }
  node_a.add_port(port_a)
  node_b.add_port(port_b)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge = ElkEdge::new("e_ab", "a", "b")
  edge.properties.set("elk.sourcePort", String("pa"))
  edge.properties.set("elk.targetPort", String("pb"))
  root.add_edge(edge)
  let options = {
    ..LayoutOptions::layered(),
    port_constraints: Some(FixedRatio),
    port_border_offset: Some(10.0),
  }
  elk_layered_layout(root, options)
  let section = edge.sections[0]
  let border = 10.0
  let usable = node_a.width - 2.0 * border
  let expected_start_x = node_a.x + border + 0.25 * usable
  let expected_end_x = node_b.x + border + 0.75 * usable
  assert_true((section.start_point.x - expected_start_x).abs() < 0.01)
  assert_true((section.end_point.x - expected_end_x).abs() < 0.01)
  assert_true(
    (section.start_point.y - (node_a.y + node_a.height - border)).abs() < 0.01,
  )
  assert_true((section.end_point.y - (node_b.y + border)).abs() < 0.01)
}

///|
test "port alignment: Justified spreads ports to border" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 200.0, 60.0)
  let node_b0 = ElkNode::with_size("b0", 60.0, 40.0)
  let node_b1 = ElkNode::with_size("b1", 60.0, 40.0)
  let node_b2 = ElkNode::with_size("b2", 60.0, 40.0)
  node_a.add_port(ElkPort::with_side("p0", South))
  node_a.add_port(ElkPort::with_side("p1", South))
  node_a.add_port(ElkPort::with_side("p2", South))
  root.add_child(node_a)
  root.add_child(node_b0)
  root.add_child(node_b1)
  root.add_child(node_b2)
  let e0 = ElkEdge::new("e0", "a", "b0")
  e0.properties.set("elk.sourcePort", String("p0"))
  let e1 = ElkEdge::new("e1", "a", "b1")
  e1.properties.set("elk.sourcePort", String("p1"))
  let e2 = ElkEdge::new("e2", "a", "b2")
  e2.properties.set("elk.sourcePort", String("p2"))
  root.add_edge(e0)
  root.add_edge(e1)
  root.add_edge(e2)
  elk_layered_layout(root, {
    ..LayoutOptions::layered(),
    port_constraints: Some(FixedOrder),
    port_alignment: Some(Justified),
    port_border_offset: Some(10.0),
  })
  let border = 10.0
  let expected_min = node_a.x + border
  let expected_mid = node_a.x + node_a.width / 2.0
  let expected_max = node_a.x + node_a.width - border
  assert_true((e0.sections[0].start_point.x - expected_min).abs() < 0.01)
  assert_true((e1.sections[0].start_point.x - expected_mid).abs() < 0.01)
  assert_true((e2.sections[0].start_point.x - expected_max).abs() < 0.01)
}

///|
test "properties: node portConstraints/portAlignment are applied" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 200.0, 60.0)
  let node_b0 = ElkNode::with_size("b0", 60.0, 40.0)
  let node_b1 = ElkNode::with_size("b1", 60.0, 40.0)
  let node_b2 = ElkNode::with_size("b2", 60.0, 40.0)
  node_a.properties.set("elk.portConstraints", String("FIXED_ORDER"))
  node_a.properties.set("elk.portAlignment", String("JUSTIFIED"))
  node_a.add_port(ElkPort::with_side("p0", South))
  node_a.add_port(ElkPort::with_side("p1", South))
  node_a.add_port(ElkPort::with_side("p2", South))
  root.add_child(node_a)
  root.add_child(node_b0)
  root.add_child(node_b1)
  root.add_child(node_b2)
  let e0 = ElkEdge::new("e0", "a", "b0")
  e0.properties.set("elk.sourcePort", String("p0"))
  let e1 = ElkEdge::new("e1", "a", "b1")
  e1.properties.set("elk.sourcePort", String("p1"))
  let e2 = ElkEdge::new("e2", "a", "b2")
  e2.properties.set("elk.sourcePort", String("p2"))
  root.add_edge(e0)
  root.add_edge(e1)
  root.add_edge(e2)
  elk_layered_layout(root, LayoutOptions::layered())
  let expected_min = node_a.x
  let expected_mid = node_a.x + node_a.width / 2.0
  let expected_max = node_a.x + node_a.width
  assert_true((e0.sections[0].start_point.x - expected_min).abs() < 0.01)
  assert_true((e1.sections[0].start_point.x - expected_mid).abs() < 0.01)
  assert_true((e2.sections[0].start_point.x - expected_max).abs() < 0.01)
}

///|
test "properties: port borderOffset affects anchors" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 80.0, 60.0)
  let node_b = ElkNode::with_size("b", 80.0, 60.0)
  let port_a = ElkPort::with_side("pa", South)
  port_a.properties.set("elk.port.borderOffset", Double(12.0))
  node_a.add_port(port_a)
  let port_b = ElkPort::with_side("pb", North)
  node_b.add_port(port_b)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge = ElkEdge::new("e", "a", "b")
  edge.properties.set("elk.sourcePort", String("pa"))
  edge.properties.set("elk.targetPort", String("pb"))
  root.add_edge(edge)
  elk_layered_layout(root, LayoutOptions::layered())
  let section = edge.sections[0]
  assert_true(
    (section.start_point.y - (node_a.y + node_a.height - 12.0)).abs() < 0.01,
  )
}

///|
test "port spacing: port_port_spacing increases gaps" {
  let mk = fn(id : String, spacing : Double) -> (ElkEdge, ElkEdge) {
    let root = ElkNode::new("root" + id)
    let node_a = ElkNode::with_size("a", 300.0, 60.0)
    let node_b0 = ElkNode::with_size("b0", 60.0, 40.0)
    let node_b1 = ElkNode::with_size("b1", 60.0, 40.0)
    node_a.add_port(ElkPort::with_side("p0", South))
    node_a.add_port(ElkPort::with_side("p1", South))
    node_a.add_port(ElkPort::with_side("p2", South))
    root.add_child(node_a)
    root.add_child(node_b0)
    root.add_child(node_b1)
    let e0 = ElkEdge::new("e0" + id, "a", "b0")
    e0.properties.set("elk.sourcePort", String("p0"))
    let e1 = ElkEdge::new("e1" + id, "a", "b1")
    e1.properties.set("elk.sourcePort", String("p1"))
    root.add_edge(e0)
    root.add_edge(e1)
    elk_layered_layout(root, {
      ..LayoutOptions::layered(),
      port_constraints: Some(FixedOrder),
      port_alignment: Some(Center),
      port_border_offset: Some(10.0),
      port_port_spacing: Some(spacing),
    })
    (e0, e1)
  }
  let (e0a, e1a) = mk("_a", 10.0)
  let (e0b, e1b) = mk("_b", 60.0)
  let gap_small = (e1a.sections[0].start_point.x - e0a.sections[0].start_point.x).abs()
  let gap_big = (e1b.sections[0].start_point.x - e0b.sections[0].start_point.x).abs()
  assert_true(gap_big > gap_small + 40.0)
}

///|
test "port border offset: inferred port anchors are inset" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 80.0, 60.0)
  let node_b = ElkNode::with_size("b", 80.0, 60.0)
  let port_a : ElkPort = {
    id: "pa",
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: Undefined,
    labels: [],
    properties: ElkProperties::new(),
  }
  let port_b : ElkPort = {
    id: "pb",
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: Undefined,
    labels: [],
    properties: ElkProperties::new(),
  }
  node_a.add_port(port_a)
  node_b.add_port(port_b)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge = ElkEdge::new("e_ab", "a", "b")
  edge.properties.set("elk.sourcePort", String("pa"))
  edge.properties.set("elk.targetPort", String("pb"))
  root.add_edge(edge)
  let options = { ..LayoutOptions::layered(), port_border_offset: Some(7.0) }
  elk_layered_layout(root, options)
  let section = edge.sections[0]
  assert_true(
    (section.start_point.y - (node_a.y + node_a.height - 7.0)).abs() < 0.001,
  )
  assert_true((section.end_point.y - (node_b.y + 7.0)).abs() < 0.001)
}

///|
test "port side inference: geometry honors border offset" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 80.0, 60.0)
  let node_b = ElkNode::with_size("b", 80.0, 60.0)
  let port_a : ElkPort = {
    id: "pa",
    x: 4.0,
    y: 20.0,
    width: 0.0,
    height: 0.0,
    side: Undefined,
    labels: [],
    properties: ElkProperties::new(),
  }
  let port_b : ElkPort = {
    id: "pb",
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: Undefined,
    labels: [],
    properties: ElkProperties::new(),
  }
  node_a.add_port(port_a)
  node_b.add_port(port_b)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge = ElkEdge::new("e_ab", "a", "b")
  edge.properties.set("elk.sourcePort", String("pa"))
  edge.properties.set("elk.targetPort", String("pb"))
  root.add_edge(edge)
  let options = { ..LayoutOptions::layered(), port_border_offset: Some(6.0) }
  elk_layered_layout(root, options)
  let section = edge.sections[0]
  assert_true((section.start_point.x - node_a.x - 6.0).abs() < 0.001)
}

///|
test "ports: inferred side is inverted for Up direction" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 80.0, 60.0)
  let node_b = ElkNode::with_size("b", 80.0, 60.0)

  // Ports have no geometry and no explicit side.
  let port_a : ElkPort = {
    id: "pa",
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: Undefined,
    labels: [],
    properties: ElkProperties::new(),
  }
  let port_b : ElkPort = {
    id: "pb",
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: Undefined,
    labels: [],
    properties: ElkProperties::new(),
  }
  node_a.add_port(port_a)
  node_b.add_port(port_b)
  root.add_child(node_a)
  root.add_child(node_b)
  let edge = ElkEdge::new("e_ab", "a", "b")
  edge.properties.set("elk.sourcePort", String("pa"))
  edge.properties.set("elk.targetPort", String("pb"))
  root.add_edge(edge)
  let options = { ..LayoutOptions::layered(), direction: Some(Up) }
  elk_layered_layout(root, options)
  let section = edge.sections[0]
  // Up direction: source anchor should be at top, target at bottom.
  assert_true((section.start_point.y - node_a.y).abs() < 0.001)
  assert_true((section.end_point.y - (node_b.y + node_b.height)).abs() < 0.001)
}

///|
test "parallel edges: distinct routed endpoints" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 80.0, 60.0)
  let node_b = ElkNode::with_size("b", 80.0, 60.0)
  root.add_child(node_a)
  root.add_child(node_b)
  let e1 = ElkEdge::new("e1", "a", "b")
  let e2 = ElkEdge::new("e2", "a", "b")
  root.add_edge(e1)
  root.add_edge(e2)
  elk_layered_layout(root, LayoutOptions::layered())
  let s1 = e1.sections[0]
  let s2 = e2.sections[0]
  assert_true((s1.start_point.x - s2.start_point.x).abs() > 0.01)
  assert_true((s1.end_point.x - s2.end_point.x).abs() > 0.01)
}

///|
test "crossing: barycenter tie-break is deterministic" {
  // Fix random seed so the perturbation is deterministic across runs.

  let build = fn(suffix : String) -> (ElkNode, ElkNode, ElkNode) {
    let root = ElkNode::new("root" + suffix)
    let a = ElkNode::with_size("a", 60.0, 40.0)
    let b = ElkNode::with_size("b", 60.0, 40.0)
    let x = ElkNode::with_size("x", 60.0, 40.0)
    let y = ElkNode::with_size("y", 60.0, 40.0)
    // Input order within the same layer matters for tie-breaks.
    root.add_child(a)
    root.add_child(b)
    root.add_child(x)
    root.add_child(y)

    // x and y have identical barycenters: both connect to a and b.
    root.add_edge(ElkEdge::new("e_ax" + suffix, "a", "x"))
    root.add_edge(ElkEdge::new("e_bx" + suffix, "b", "x"))
    root.add_edge(ElkEdge::new("e_ay" + suffix, "a", "y"))
    root.add_edge(ElkEdge::new("e_by" + suffix, "b", "y"))
    (root, x, y)
  }
  let (root1, x1, y1) = build("_1")
  elk_layered_layout(root1, { ..LayoutOptions::layered(), random_seed: Some(1) })
  let order1 = x1.x < y1.x
  let (root2, x2, y2) = build("_2")
  elk_layered_layout(root2, { ..LayoutOptions::layered(), random_seed: Some(1) })
  let order2 = x2.x < y2.x
  assert_true(order1 == order2)
}

///|
test "crossing: forceNodeModelOrder preserves input order" {
  let root = ElkNode::new("root")
  root.properties.set(
    "org.eclipse.elk.alg.layered.crossingMinimization.forceNodeModelOrder",
    Bool(true),
  )
  root.properties.set(
    "org.eclipse.elk.alg.layered.considerModelOrder.strategy",
    String("NODES_AND_EDGES"),
  )
  let u0 = ElkNode::with_size("u0", 10.0, 10.0)
  let u1 = ElkNode::with_size("u1", 10.0, 10.0)
  let v0 = ElkNode::with_size("v0", 10.0, 10.0)
  let v1 = ElkNode::with_size("v1", 10.0, 10.0)

  // Add in order: v0 then v1.
  root.add_child(u0)
  root.add_child(u1)
  root.add_child(v0)
  root.add_child(v1)

  // This would normally cause v-layer to swap under barycenter.
  root.add_edge(ElkEdge::new("e0", "u0", "v1"))
  root.add_edge(ElkEdge::new("e1", "u1", "v0"))
  elk_layered_layout(root, { ..LayoutOptions::layered(), random_seed: Some(1) })

  // With forceNodeModelOrder=true, keep v0 before v1.
  assert_true(v0.x < v1.x)
}

///|
test "routing: fanout edges share lane" {
  // Regression for `direction: down; x -> y, y2, y3, y4`.
  // ELK routes these in the same routing slot (same lane).
  let root = ElkNode::new("root")
  root.properties.set("elk.direction", Enum("DOWN"))
  let x = ElkNode::with_size("x", 80.0, 60.0)
  let y = ElkNode::with_size("y", 80.0, 60.0)
  let y2 = ElkNode::with_size("y2", 80.0, 60.0)
  let y3 = ElkNode::with_size("y3", 80.0, 60.0)
  let y4 = ElkNode::with_size("y4", 80.0, 60.0)
  root.add_child(x)
  root.add_child(y)
  root.add_child(y2)
  root.add_child(y3)
  root.add_child(y4)
  let e_y = ElkEdge::new("e_y", "x", "y")
  let e_y2 = ElkEdge::new("e_y2", "x", "y2")
  let e_y3 = ElkEdge::new("e_y3", "x", "y3")
  let e_y4 = ElkEdge::new("e_y4", "x", "y4")
  root.add_edge(e_y)
  root.add_edge(e_y2)
  root.add_edge(e_y3)
  root.add_edge(e_y4)
  elk_layered_layout(root, {
    ..LayoutOptions::layered(),
    direction: Some(LayoutDirection::Down),
    edge_routing: Some(Orthogonal),
    edge_node_between_layers_spacing: Some(10.0),
    edge_edge_between_layers_spacing: Some(10.0),
  })
  let s3 = e_y3.sections[0]
  let s4 = e_y4.sections[0]
  assert_true(s3.bend_points.length() == 2)
  assert_true(s4.bend_points.length() == 2)
  assert_true((s3.bend_points[0].y - s4.bend_points[0].y).abs() < 0.01)
}

///|
test "routing: startPos respects edgeNodeSpacing" {
  // ELK places the first routing slot at:
  //   startPos = layerBoundary + edgeNodeSpacing
  // for Down direction.
  let root = ElkNode::new("root")
  root.properties.set("elk.direction", Enum("DOWN"))
  let x = ElkNode::with_size("x", 80.0, 60.0)
  let y = ElkNode::with_size("y", 80.0, 60.0)
  let y2 = ElkNode::with_size("y2", 80.0, 60.0)
  root.add_child(x)
  root.add_child(y)
  root.add_child(y2)
  let e_y = ElkEdge::new("e_y", "x", "y")
  let e_y2 = ElkEdge::new("e_y2", "x", "y2")
  root.add_edge(e_y)
  root.add_edge(e_y2)
  let edge_node_spacing = 30.0
  elk_layered_layout(root, {
    ..LayoutOptions::layered(),
    direction: Some(LayoutDirection::Down),
    edge_routing: Some(Orthogonal),
    edge_node_between_layers_spacing: Some(edge_node_spacing),
    edge_edge_between_layers_spacing: Some(10.0),
  })
  let s0 = e_y.sections[0]
  let s1 = e_y2.sections[0]
  let s = if s0.bend_points.length() == 2 { s0 } else { s1 }
  assert_true(s.bend_points.length() == 2)
  let expected = x.y + x.height + edge_node_spacing
  assert_true((s.bend_points[0].y - expected).abs() < 0.01)
}

///|
test "placement: chain centers align to avoid bends" {
  // Based on a minimal D2 flow where the upper nodes are narrower
  // than the server nodes; reference ELK aligns centers.
  let root = ElkNode::new("root")
  let web1 = ElkNode::with_size("web1", 112.0, 60.0)
  let web2 = ElkNode::with_size("web2", 112.0, 60.0)
  let db1 = ElkNode::with_size("db1", 100.0, 60.0)
  let db2 = ElkNode::with_size("db2", 100.0, 60.0)
  let alice = ElkNode::with_size("alice", 100.0, 60.0)
  let bob = ElkNode::with_size("bob", 100.0, 60.0)
  root.add_child(web1)
  root.add_child(web2)
  root.add_child(db1)
  root.add_child(db2)
  root.add_child(alice)
  root.add_child(bob)
  let e_alice = ElkEdge::new("e_alice", "alice", "web1")
  let e_bob = ElkEdge::new("e_bob", "bob", "web2")
  let e_web1 = ElkEdge::new("e_web1", "web1", "db1")
  let e_web2 = ElkEdge::new("e_web2", "web2", "db1")
  let e_rep = ElkEdge::new("e_rep", "db1", "db2")
  root.add_edge(e_alice)
  root.add_edge(e_bob)
  root.add_edge(e_web1)
  root.add_edge(e_web2)
  root.add_edge(e_rep)
  elk_layered_layout(root, LayoutOptions::layered())
  fn center_x(node : ElkNode) -> Double {
    node.x + node.width / 2.0
  }

  // Centers should align, avoiding bends.
  assert_true((center_x(alice) - center_x(web1)).abs() < 0.01)
  assert_true((center_x(bob) - center_x(web2)).abs() < 0.01)
  let s_alice = e_alice.sections[0]
  assert_true(s_alice.bend_points.is_empty())
  assert_true((s_alice.start_point.x - s_alice.end_point.x).abs() < 0.01)
  let s_bob = e_bob.sections[0]
  assert_true(s_bob.bend_points.is_empty())
  assert_true((s_bob.start_point.x - s_bob.end_point.x).abs() < 0.01)
}
