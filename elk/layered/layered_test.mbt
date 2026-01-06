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
  let root = @elk.ElkNode::new("root")
  root.width = 200.0
  root.height = 200.0
  let node_a = @elk.ElkNode::with_size("a", 60.0, 40.0)
  let node_b = @elk.ElkNode::with_size("b", 60.0, 40.0)
  let node_c = @elk.ElkNode::with_size("c", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_child(node_c)
  let edge_ab = @elk.ElkEdge::new("e1", "a", "b")
  let edge_bc = @elk.ElkEdge::new("e2", "b", "c")
  root.add_edge(edge_ab)
  root.add_edge(edge_bc)

  // Run layout
  let options = @elk.LayoutOptions::layered()
  layout(root, options)

  // Verify nodes are positioned (y increases for each layer in Down direction)
  assert_true(node_a.y < node_b.y)
  assert_true(node_b.y < node_c.y)
}

///|
test "cycle breaking - simple cycle" {
  // Create a graph with a cycle: A -> B -> C -> A
  let root = @elk.ElkNode::new("root")
  let node_a = @elk.ElkNode::with_size("a", 60.0, 40.0)
  let node_b = @elk.ElkNode::with_size("b", 60.0, 40.0)
  let node_c = @elk.ElkNode::with_size("c", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_child(node_c)
  root.add_edge(@elk.ElkEdge::new("e1", "a", "b"))
  root.add_edge(@elk.ElkEdge::new("e2", "b", "c"))
  root.add_edge(@elk.ElkEdge::new("e3", "c", "a")) // Back edge
  let options = @elk.LayoutOptions::layered()
  layout(root, options)

  // Should complete without error - cycle is broken
  assert_true(root.children.length() == 3)
}

///|
test "diamond graph" {
  // Create a diamond: A -> B, A -> C, B -> D, C -> D
  let root = @elk.ElkNode::new("root")
  let node_a = @elk.ElkNode::with_size("a", 60.0, 40.0)
  let node_b = @elk.ElkNode::with_size("b", 60.0, 40.0)
  let node_c = @elk.ElkNode::with_size("c", 60.0, 40.0)
  let node_d = @elk.ElkNode::with_size("d", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_child(node_c)
  root.add_child(node_d)
  root.add_edge(@elk.ElkEdge::new("e1", "a", "b"))
  root.add_edge(@elk.ElkEdge::new("e2", "a", "c"))
  root.add_edge(@elk.ElkEdge::new("e3", "b", "d"))
  root.add_edge(@elk.ElkEdge::new("e4", "c", "d"))
  let options = @elk.LayoutOptions::layered()
  layout(root, options)

  // A should be above B and C, which should be above D
  assert_true(node_a.y < node_b.y)
  assert_true(node_a.y < node_c.y)
  assert_true(node_b.y < node_d.y)
  assert_true(node_c.y < node_d.y)
}

///|
test "horizontal layout direction" {
  let root = @elk.ElkNode::new("root")
  let node_a = @elk.ElkNode::with_size("a", 60.0, 40.0)
  let node_b = @elk.ElkNode::with_size("b", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_edge(@elk.ElkEdge::new("e1", "a", "b"))
  let options = @elk.LayoutOptions::layered().with_direction(@elk.Right)
  layout(root, options)

  // In Right direction, x should increase
  assert_true(node_a.x < node_b.x)
}
