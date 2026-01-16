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
test "railway layout routes via virtual nodes" {
  let a = @graph.ObjectInput::new("A")
  let b = @graph.ObjectInput::new("B")
  let c = @graph.ObjectInput::new("C")
  let mut edge_counter = 0
  fn make_edge_between(
    src : @graph.ObjectInput,
    dst : @graph.ObjectInput,
  ) -> @graph.EdgeInput {
    edge_counter = edge_counter + 1
    @graph.EdgeInput::new(edge_counter - 1, src.id, dst.id, false, true)
  }

  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b, c])
  // A -> B -> C, and A -> C (spans 2 levels)
  let e_ab = make_edge_between(a, b)
  let e_bc = make_edge_between(b, c)
  let e_ac = make_edge_between(a, c)
  g.edges.append([e_ab, e_bc, e_ac])
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Down)

  // Virtual nodes are not emitted as node boxes.
  assert_true(patch.nodes.get("virtual:\{e_ac.index}:1") is None)

  // The spanning edge should pass through the expected virtual node location.
  // With the current placement, the virtual is placed after B on level 1.
  let virt_center = @graph.Point::new(180.0, 140.0)
  let points = patch.edges.get(e_ac.index).unwrap_or([])
  let mut found = false
  for p in points {
    if p.x == virt_center.x && p.y == virt_center.y {
      found = true
      break
    }
  }
  assert_true(found)
}

///|
test "simple DAG" {
  let mut edge_counter = 0
  fn make_edge_between(
    src : @graph.ObjectInput,
    dst : @graph.ObjectInput,
  ) -> @graph.EdgeInput {
    edge_counter = edge_counter + 1
    @graph.EdgeInput::new(edge_counter - 1, src.id, dst.id, false, true)
  }

  let alice = @graph.ObjectInput::new("Alice")
  let bob = @graph.ObjectInput::new("Bob")
  let ws1 = @graph.ObjectInput::new("WebServer1")
  let ws2 = @graph.ObjectInput::new("WebServer2")
  let storage = @graph.ObjectInput::new("Storage")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([alice, bob, ws1, ws2, storage])
  // A -> B -> C, and A -> C (spans 2 levels)
  let e0 = make_edge_between(alice, ws1)
  let e1 = make_edge_between(bob, ws2)
  let e2 = make_edge_between(ws1, storage)
  let e3 = make_edge_between(ws2, storage)
  g.edges.append([e0, e1, e2, e3])

  // 
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Down)
  inspect(
    patch.edges,
    content="{0: [{x: 210, y: 300}, {x: 210, y: 240}], 1: [{x: 210, y: 300}, {x: 210, y: 240}], 2: [{x: 210, y: 300}, {x: 210, y: 240}], 3: [{x: 210, y: 300}, {x: 210, y: 240}]}",
  )
  inspect(
    patch.nodes,
    content=(
      #|{"Alice": {x: 160, y: 240, width: 100, height: 60}, "Bob": {x: 160, y: 240, width: 100, height: 60}, "WebServer1": {x: 160, y: 240, width: 100, height: 60}, "WebServer2": {x: 160, y: 240, width: 100, height: 60}, "Storage": {x: 160, y: 240, width: 100, height: 60}}
    ),
  )
}

///|
test "A -> B" {
  let mut edge_counter = 0
  fn make_edge_between(
    src : @graph.ObjectInput,
    dst : @graph.ObjectInput,
  ) -> @graph.EdgeInput {
    edge_counter = edge_counter + 1
    @graph.EdgeInput::new(edge_counter - 1, src.id, dst.id, false, true)
  }

  let a = @graph.ObjectInput::new("A")
  let b = @graph.ObjectInput::new("B")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b])
  let e0 = make_edge_between(a, b)
  g.edges.append([e0])

  // 
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Down)
  inspect(patch.edges, content="{0: [{x: 210, y: 60}, {x: 210, y: 120}]}")
  inspect(
    patch.nodes,
    content=(
      #|{"A": {x: 160, y: 0, width: 100, height: 60}, "B": {x: 160, y: 120, width: 100, height: 60}}
    ),
  )
}
