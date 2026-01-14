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
