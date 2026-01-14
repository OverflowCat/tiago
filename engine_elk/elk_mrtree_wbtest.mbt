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
/// Tests for the MrTree (tree) layout algorithm.
test "mrtree: simple tree Down" {
  let root = ElkNode::new("root")
  let a = ElkNode::with_size("a", 60.0, 40.0)
  let b = ElkNode::with_size("b", 60.0, 40.0)
  let c = ElkNode::with_size("c", 60.0, 40.0)
  root.add_child(a)
  root.add_child(b)
  root.add_child(c)
  root.add_edge(ElkEdge::new("e_ab", "a", "b"))
  root.add_edge(ElkEdge::new("e_ac", "a", "c"))
  let options = LayoutOptions::tree().with_direction(LayoutDirection::Down)
  elk_mrtree_layout(root, options)
  assert_true(a.y < b.y)
  assert_true(a.y < c.y)
  assert_true(root.width > 0.0)
  assert_true(root.height > 0.0)

  // Edges have at least one section.
  assert_true(root.edges[0].sections.length() == 1)
  assert_true(root.edges[1].sections.length() == 1)
}

///|
test "mrtree: horizontal Right" {
  let root = ElkNode::new("root")
  let a = ElkNode::with_size("a", 60.0, 40.0)
  let b = ElkNode::with_size("b", 60.0, 40.0)
  root.add_child(a)
  root.add_child(b)
  root.add_edge(ElkEdge::new("e_ab", "a", "b"))
  let options = LayoutOptions::tree().with_direction(LayoutDirection::Right)
  elk_mrtree_layout(root, options)
  assert_true(a.x < b.x)
  assert_true(root.edges[0].sections.length() == 1)
}
