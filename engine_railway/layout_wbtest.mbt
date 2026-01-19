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
  assert_true(patch.nodes.get(forward_virtual_node_label(1)) is None)
  assert_true(patch.nodes.get(backward_virtual_node_label(1)) is None)

  // The spanning edge should use the rail anchor, but the virtual node center
  // itself must NOT be a waypoint. Only rail points are waypoints.
  let a_box = patch.nodes.get("A").unwrap()
  let b_box = patch.nodes.get("B").unwrap()
  let c_box = patch.nodes.get("C").unwrap()
  let rail_0_1 = (a_box.y + a_box.height + b_box.y) / 2.0
  let rail_1_2 = (b_box.y + b_box.height + c_box.y) / 2.0
  let virt_x = config.default_width / 2.0
  let virt_center = @graph.Point::new(virt_x, b_box.y + b_box.height / 2.0)
  let points = patch.edges.get(e_ac.index).unwrap_or([])
  let mut has_rail_0_1 = false
  let mut has_rail_1_2 = false
  let mut has_virt_center = false
  for p in points {
    if p == virt_center {
      has_virt_center = true
    }
    if p.x == virt_x && p.y == rail_0_1 {
      has_rail_0_1 = true
    }
    if p.x == virt_x && p.y == rail_1_2 {
      has_rail_1_2 = true
    }
  }
  assert_true(has_rail_0_1)
  assert_true(has_rail_1_2)
  assert_true(!has_virt_center)
}

///|
test "railway layout back edge avoids per-level waypoints" {
  let x = @graph.ObjectInput::new("x")
  let y = @graph.ObjectInput::new("y")
  let z = @graph.ObjectInput::new("z")
  let c = @graph.ObjectInput::new("c")
  let mut edge_counter = 0
  fn make_edge_between(
    src : @graph.ObjectInput,
    dst : @graph.ObjectInput,
  ) -> @graph.EdgeInput {
    edge_counter = edge_counter + 1
    @graph.EdgeInput::new(edge_counter - 1, src.id, dst.id, false, true)
  }

  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([x, y, z, c])
  // Create a cycle so one edge is reversed by MFAS; then route that back edge.
  let e_xy = make_edge_between(x, y)
  let e_yz = make_edge_between(y, z)
  let e_zc = make_edge_between(z, c)
  let e_cx = make_edge_between(c, x)
  g.edges.append([e_xy, e_yz, e_zc, e_cx])
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Down)
  let plan = els_tarjan_plan(g)
  let (_self_loop, reversed) = dag_edge_index_sets(plan)
  // Pick any reversed edge (a back edge) and assert it doesn't include a
  // per-level intermediate waypoint at the outer rail for each level.
  let mut target = -1
  for e in g.edges {
    if reversed.contains(e.index) {
      target = e.index
      break
    }
  }
  assert_true(target >= 0, msg="expected at least one reversed edge")
  let points = patch.edges.get(target).unwrap_or([])
  // For a long back edge, we should not emit more than one outer-rail Y waypoint.
  // Route is: start, (rail_x, start.y), (rail_x, last_rail_y), (dst_x, last_rail_y), end
  // so at most 2 points with x near the outer rail.
  let mut max_x = 0.0
  for entry in patch.nodes {
    let b = entry.1
    if b.x + b.width > max_x {
      max_x = b.x + b.width
    }
  }
  let mut rail_hits = 0
  for p in points {
    if p.x > max_x + 1.0 {
      rail_hits = rail_hits + 1
    }
  }
  assert_true(rail_hits <= 2, msg="too many outer-rail waypoints: \{rail_hits}")
}

///|
test "railway layout offsets overlapping back edges" {
  // Two disjoint directed cycles => at least two back edges after MFAS.
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let c = @graph.ObjectInput::new("c")
  let d = @graph.ObjectInput::new("d")
  let e = @graph.ObjectInput::new("e")
  let f = @graph.ObjectInput::new("f")
  let mut edge_counter = 0
  fn make_edge_between(
    src : @graph.ObjectInput,
    dst : @graph.ObjectInput,
  ) -> @graph.EdgeInput {
    edge_counter = edge_counter + 1
    @graph.EdgeInput::new(edge_counter - 1, src.id, dst.id, false, true)
  }

  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b, c, d, e, f])
  // Cycle 1: a -> b -> c -> a
  let e_ab = make_edge_between(a, b)
  let e_bc = make_edge_between(b, c)
  let e_ca = make_edge_between(c, a)
  // Cycle 2: d -> e -> f -> d
  let e_de = make_edge_between(d, e)
  let e_ef = make_edge_between(e, f)
  let e_fd = make_edge_between(f, d)
  g.edges.append([e_ab, e_bc, e_ca, e_de, e_ef, e_fd])
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Down)
  let plan = els_tarjan_plan(g)
  let (_self_loop, reversed) = dag_edge_index_sets(plan)
  let reversed_edges : Array[Int] = []
  for edge in g.edges {
    if reversed.contains(edge.index) {
      reversed_edges.push(edge.index)
    }
  }
  assert_true(reversed_edges.length() >= 2, msg="expected >=2 reversed edges")
  let r1 = patch.edges.get(reversed_edges[0]).unwrap_or([])
  let r2 = patch.edges.get(reversed_edges[1]).unwrap_or([])
  fn max_x(points : Array[@graph.Point]) -> Double {
    let mut mx = 0.0
    for p in points {
      if p.x > mx {
        mx = p.x
      }
    }
    mx
  }
  // Each back edge should get a different outer rail x coordinate.
  assert_true(max_x(r1) != max_x(r2), msg="back edges share the same rail x")
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
    content="{0: [{x: 210, y: 60}, {x: 210, y: 120}], 1: [{x: 370, y: 60}, {x: 370, y: 120}], 2: [{x: 210, y: 180}, {x: 210, y: 240}], 3: [{x: 370, y: 180}, {x: 370, y: 210}, {x: 210, y: 210}, {x: 210, y: 240}]}",
  )
  inspect(
    patch.nodes,
    content=(
      #|{"Alice": {x: 160, y: 0, width: 100, height: 60}, "Bob": {x: 320, y: 0, width: 100, height: 60}, "WebServer1": {x: 160, y: 120, width: 100, height: 60}, "WebServer2": {x: 320, y: 120, width: 100, height: 60}, "Storage": {x: 160, y: 240, width: 100, height: 60}}
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
