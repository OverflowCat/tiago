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
test "railway layout offsets overlapping gap rails" {
  let x1 = @graph.ObjectInput::new("x1")
  let x2 = @graph.ObjectInput::new("x2")
  let y1 = @graph.ObjectInput::new("y1")
  let y2 = @graph.ObjectInput::new("y2")
  let mut edge_counter = 0
  fn make_edge_between(
    src : @graph.ObjectInput,
    dst : @graph.ObjectInput,
  ) -> @graph.EdgeInput {
    edge_counter = edge_counter + 1
    @graph.EdgeInput::new(edge_counter - 1, src.id, dst.id, false, true)
  }

  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([x1, x2, y1, y2])
  // Two crossing edges between adjacent levels; their horizontal gap segments
  // would overlap unless we assign distinct lanes (rail_y offsets).
  let e_x1_y1 = make_edge_between(x1, y1)
  let e_x2_y2 = make_edge_between(x2, y2)
  let e_x1_y2 = make_edge_between(x1, y2)
  let e_x2_y1 = make_edge_between(x2, y1)
  g.edges.append([e_x1_y1, e_x2_y2, e_x1_y2, e_x2_y1])
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Down)
  let r_a = patch.edges.get(e_x1_y2.index).unwrap_or([])
  let r_b = patch.edges.get(e_x2_y1.index).unwrap_or([])
  assert_true(
    r_a.length() >= 4 && r_b.length() >= 4,
    msg="expected gap-routed edges to have rail points",
  )
  // The second point is the first rail point: (src.x, rail_y).
  let rail_y_a = r_a[1].y
  let rail_y_b = r_b[1].y
  assert_true(rail_y_a != rail_y_b, msg="gap rails should be offset")
}

///|
test "railway lane optimizer minimizes fanout rail crossings" {
  let x1 = @graph.ObjectInput::new("x1")
  let x2 = @graph.ObjectInput::new("x2")
  let y1 = @graph.ObjectInput::new("y1")
  let y2 = @graph.ObjectInput::new("y2")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([x1, x2, y1, y2])
  let e_x1_y1 = @graph.EdgeInput::new(0, "x1", "y1", false, true)
  let e_x2_y2 = @graph.EdgeInput::new(1, "x2", "y2", false, true)
  let e_x1_y2 = @graph.EdgeInput::new(2, "x1", "y2", false, true)
  let e_x2_y1 = @graph.EdgeInput::new(3, "x2", "y1", false, true)
  g.edges.append([e_x1_y1, e_x2_y2, e_x1_y2, e_x2_y1])

  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  let left_route = patch.edges.get(e_x1_y2.index).unwrap_or([])
  let right_route = patch.edges.get(e_x2_y1.index).unwrap_or([])
  assert_true(left_route.length() >= 4 && right_route.length() >= 4)

  fn between_open(v : Double, a : Double, b : Double) -> Bool {
    let lo = @cmp.minimum(a, b)
    let hi = @cmp.maximum(a, b)
    v > lo + 1.0e-6 && v < hi - 1.0e-6
  }

  fn crossings_between(
    r1 : Array[@graph.Point],
    r2 : Array[@graph.Point],
  ) -> Int {
    let mut count = 0
    for i in 0..<(r1.length() - 1) {
      let a0 = r1[i]
      let a1 = r1[i + 1]
      let a_vertical = (a0.x - a1.x).abs() <= 1.0e-6
      let a_horizontal = (a0.y - a1.y).abs() <= 1.0e-6
      if !(a_vertical || a_horizontal) {
        continue
      }
      for j in 0..<(r2.length() - 1) {
        let b0 = r2[j]
        let b1 = r2[j + 1]
        let b_vertical = (b0.x - b1.x).abs() <= 1.0e-6
        let b_horizontal = (b0.y - b1.y).abs() <= 1.0e-6
        if !(b_vertical || b_horizontal) {
          continue
        }
        if a_vertical == b_vertical {
          continue
        }
        let vertical = if a_vertical { (a0, a1) } else { (b0, b1) }
        let horizontal = if a_vertical { (b0, b1) } else { (a0, a1) }
        let x = vertical.0.x
        let y = horizontal.0.y
        if between_open(x, horizontal.0.x, horizontal.1.x) &&
          between_open(y, vertical.0.y, vertical.1.y) {
          count = count + 1
        }
      }
    }
    count
  }

  let crossings = crossings_between(left_route, right_route)
  assert_true(
    crossings == 0,
    msg="crossing fanout rails should be untangled, got \{crossings}",
  )
}

///|
test "railway layout respects Right direction" {
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b])
  g.edges.push(@graph.EdgeInput::new(0, "a", "b", false, true))
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Right)
  let a_box = patch.nodes.get("a").unwrap()
  let b_box = patch.nodes.get("b").unwrap()
  assert_true(b_box.x > a_box.x, msg="b should be to the right of a")
}

///|
test "railway layout respects Left direction" {
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b])
  g.edges.push(@graph.EdgeInput::new(0, "a", "b", false, true))
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Left)
  let a_box = patch.nodes.get("a").unwrap()
  let b_box = patch.nodes.get("b").unwrap()
  assert_true(b_box.x < a_box.x, msg="b should be to the left of a")
}

///|
test "railway layout respects Up direction" {
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b])
  g.edges.push(@graph.EdgeInput::new(0, "a", "b", false, true))
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Up)
  let a_box = patch.nodes.get("a").unwrap()
  let b_box = patch.nodes.get("b").unwrap()
  assert_true(b_box.y < a_box.y, msg="b should be above a")
}

///|
test "railway layout fans out shared source ports" {
  let x = @graph.ObjectInput::new("x")
  let y1 = @graph.ObjectInput::new("y1")
  let y2 = @graph.ObjectInput::new("y2")
  let mut edge_counter = 0
  fn make_edge_between(
    src : @graph.ObjectInput,
    dst : @graph.ObjectInput,
  ) -> @graph.EdgeInput {
    edge_counter = edge_counter + 1
    @graph.EdgeInput::new(edge_counter - 1, src.id, dst.id, false, true)
  }

  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([x, y1, y2])
  let e0 = make_edge_between(x, y1)
  let e1 = make_edge_between(x, y2)
  g.edges.append([e0, e1])
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Down)
  let r0 = patch.edges.get(e0.index).unwrap_or([])
  let r1 = patch.edges.get(e1.index).unwrap_or([])
  assert_true(r0.length() >= 2 && r1.length() >= 2)
  assert_true(
    r0[0].x != r1[0].x,
    msg="shared source should have distinct exit x",
  )
  assert_true(
    (r0[0].x - r1[0].x).abs() >= 12.0,
    msg="shared source port fan-out should be visually separated",
  )
}

///|
test "railway layout keeps endpoint tangents vertical" {
  let x = @graph.ObjectInput::new("x")
  let x1 = @graph.ObjectInput::new("x1")
  let y = @graph.ObjectInput::new("y")
  let z = @graph.ObjectInput::new("z")
  let mut edge_counter = 0
  fn make_edge_between(
    src : @graph.ObjectInput,
    dst : @graph.ObjectInput,
  ) -> @graph.EdgeInput {
    edge_counter = edge_counter + 1
    @graph.EdgeInput::new(edge_counter - 1, src.id, dst.id, false, true)
  }

  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([x, x1, y, z])
  let e_xy = make_edge_between(x, y)
  let e_xz = make_edge_between(x, z)
  let e_x1y = make_edge_between(x1, y)
  let e_x1z = make_edge_between(x1, z)
  g.edges.append([e_xy, e_xz, e_x1y, e_x1z])
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph(g, config, @engine_api.Down)
  let r_xy = patch.edges.get(e_xy.index).unwrap_or([])
  let r_x1z = patch.edges.get(e_x1z.index).unwrap_or([])
  assert_true(r_xy.length() >= 2 && r_x1z.length() >= 2)
  // With dagre-driven node placement, we only require vertical tangents at
  // endpoints, not fully straight columns.
  assert_true(
    (r_xy[0].x - r_xy[1].x).abs() <= 0.000001,
    msg="x->y should start vertically",
  )
  assert_true(
    (r_x1z[0].x - r_x1z[1].x).abs() <= 0.000001,
    msg="x1->z should start vertically",
  )
  let n_xy = r_xy.length()
  let n_x1z = r_x1z.length()
  assert_true(
    (r_xy[n_xy - 1].x - r_xy[n_xy - 2].x).abs() <= 0.000001,
    msg="x->y should end vertically",
  )
  assert_true(
    (r_x1z[n_x1z - 1].x - r_x1z[n_x1z - 2].x).abs() <= 0.000001,
    msg="x1->z should end vertically",
  )
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
  let r2 = patch.edges.get(e2.index).unwrap_or([])
  let r3 = patch.edges.get(e3.index).unwrap_or([])
  assert_true(r2.length() >= 2 && r3.length() >= 2)
  let end2 = r2[r2.length() - 1]
  let end3 = r3[r3.length() - 1]
  // Fan-in ports on Storage should be distinct.
  assert_true(end2.y == end3.y, msg="Storage fan-in should share row")
  assert_true(end2.x != end3.x, msg="Storage entry ports should differ")
  let alice_box = patch.nodes.get("Alice").unwrap()
  let bob_box = patch.nodes.get("Bob").unwrap()
  let ws1_box = patch.nodes.get("WebServer1").unwrap()
  let ws2_box = patch.nodes.get("WebServer2").unwrap()
  let storage_box = patch.nodes.get("Storage").unwrap()
  assert_true(alice_box.y == bob_box.y)
  assert_true(ws1_box.y == ws2_box.y)
  assert_true(storage_box.y > ws1_box.y)
  assert_true(alice_box.x != bob_box.x)
  assert_true(ws1_box.x != ws2_box.x)
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
  let route = patch.edges.get(e0.index).unwrap_or([])
  assert_true(route.length() >= 2)
  let start = route[0]
  let end = route[route.length() - 1]
  assert_true(start.x == end.x, msg="single edge should stay vertical")
  assert_true(start.y < end.y)
  let a_box = patch.nodes.get("A").unwrap()
  let b_box = patch.nodes.get("B").unwrap()
  assert_true(a_box.x == b_box.x)
  assert_true(a_box.y < b_box.y)
  assert_true(start.y == a_box.y + a_box.height)
  assert_true(end.y == b_box.y)
}

///|
test "railway layout computes edge label boxes" {
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let base_edge = @graph.EdgeInput::new(0, "a", "b", false, true)
  let edge = @graph.EdgeInput::from_parts(
    base_edge.index,
    base_edge.src_id,
    base_edge.dst_id,
    base_edge.src_arrow,
    base_edge.dst_arrow,
    base_edge.src_arrowhead,
    base_edge.dst_arrowhead,
    base_edge.src_anchor,
    base_edge.dst_anchor,
    "hello",
    base_edge.style,
    base_edge.route,
    base_edge.bend_points,
    base_edge.is_curve,
    base_edge.z_index,
    base_edge.reference_count,
    base_edge.label_box,
    base_edge.src_column_index,
    base_edge.dst_column_index,
  )
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b])
  g.edges.push(edge)

  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  let label_box = patch.edge_labels
    .get(edge.index)
    .unwrap_or(@graph.Box::new(0.0, 0.0, 0.0, 0.0))
  assert_true(
    patch.edge_labels.contains(edge.index),
    msg="labeled edges should have computed label boxes",
  )
  assert_true(
    label_box.width > 0.0 && label_box.height > 0.0,
    msg="label box should have positive size",
  )
}

///|
test "railway layout separates reciprocal edge labels" {
  fn labeled_edge(
    index : Int,
    src : String,
    dst : String,
    label : String,
  ) -> @graph.EdgeInput {
    let base = @graph.EdgeInput::new(index, src, dst, false, true)
    @graph.EdgeInput::from_parts(
      base.index,
      base.src_id,
      base.dst_id,
      base.src_arrow,
      base.dst_arrow,
      base.src_arrowhead,
      base.dst_arrowhead,
      base.src_anchor,
      base.dst_anchor,
      label,
      base.style,
      base.route,
      base.bend_points,
      base.is_curve,
      base.z_index,
      base.reference_count,
      base.label_box,
      base.src_column_index,
      base.dst_column_index,
    )
  }

  fn overlap(a : @graph.Box, b : @graph.Box) -> Bool {
    !(a.x + a.width <= b.x ||
    b.x + b.width <= a.x ||
    a.y + a.height <= b.y ||
    b.y + b.height <= a.y)
  }

  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b])
  g.edges.push(labeled_edge(0, "a", "b", "request"))
  g.edges.push(labeled_edge(1, "b", "a", "response"))

  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  let l0 = patch.edge_labels
    .get(0)
    .unwrap_or(@graph.Box::new(0.0, 0.0, 0.0, 0.0))
  let l1 = patch.edge_labels
    .get(1)
    .unwrap_or(@graph.Box::new(0.0, 0.0, 0.0, 0.0))
  assert_true(l0.width > 0.0 && l0.height > 0.0)
  assert_true(l1.width > 0.0 && l1.height > 0.0)
  assert_true(!overlap(l0, l1), msg="reciprocal labels should not overlap")
}

///|
test "railway layout splits reciprocal edge channels at endpoints" {
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b])
  g.edges.push(@graph.EdgeInput::new(0, "a", "b", false, true))
  g.edges.push(@graph.EdgeInput::new(1, "b", "a", false, true))

  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  let r0 = patch.edges.get(0).unwrap_or([])
  let r1 = patch.edges.get(1).unwrap_or([])
  assert_true(r0.length() >= 2 && r1.length() >= 2)
  let start_dx = (r0[0].x - r1[r1.length() - 1].x).abs()
  let end_dx = (r0[r0.length() - 1].x - r1[0].x).abs()
  assert_true(
    start_dx >= 8.0 || end_dx >= 8.0,
    msg="reciprocal edges should not share exact endpoint channel",
  )
}

///|
test "railway layout splits reciprocal channels in legend_auto pattern" {
  let t = @graph.ObjectInput::new("true")
  let client = @graph.ObjectInput::new("client")
  let server = @graph.ObjectInput::new("server")
  let db = @graph.ObjectInput::from_parts(
    "db",
    "db",
    @graph.Cylinder,
    @graph.StyleInput::new(),
    None,
    None,
    [],
    0,
    None,
    None,
    None,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
  let g = @graph.GraphInput::new("legend_auto_like")
  g.objects.append([t, client, server, db])
  g.edges.push(@graph.EdgeInput::new(0, "client", "server", false, true))
  g.edges.push(@graph.EdgeInput::new(1, "server", "db", false, true))
  g.edges.push(@graph.EdgeInput::new(2, "db", "server", false, true))
  g.edges.push(@graph.EdgeInput::new(3, "server", "client", false, true))

  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  let forward = patch.edges.get(0).unwrap_or([])
  let backward = patch.edges.get(3).unwrap_or([])
  assert_true(forward.length() >= 2 && backward.length() >= 2)
  let client_channel_dx = (forward[0].x - backward[backward.length() - 1].x).abs()
  let server_channel_dx = (forward[forward.length() - 1].x - backward[0].x).abs()
  assert_true(
    client_channel_dx >= 8.0 || server_channel_dx >= 8.0,
    msg="legend_auto reciprocal edge should split channels (client=\{client_channel_dx}, server=\{server_channel_dx})",
  )
}

///|
test "railway layout keeps passthrough layout data" {
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b])
  g.edges.push(@graph.EdgeInput::new(0, "a", "b", false, true))
  g.activation_boxes.push(("a", @graph.Box::new(0.0, 0.0, 10.0, 10.0)))
  g.sequence_notes.push(("a", "note", @graph.Box::new(5.0, 5.0, 30.0, 20.0)))
  g.sequence_fragments_layout.push(
    @graph.SequenceFragmentLayout::new(
      "alt",
      Some("x"),
      Some(@graph.Box::new(0.0, 0.0, 60.0, 40.0)),
      0,
      0,
      [],
    ),
  )

  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  assert_true(patch.activation_boxes.length() == 1)
  assert_true(patch.sequence_notes.length() == 1)
  assert_true(patch.sequence_fragments.length() == 1)
}

///|
test "railway levels reduce simple bipartite crossing" {
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let c = @graph.ObjectInput::new("c")
  let d = @graph.ObjectInput::new("d")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b, c, d])
  g.edges.push(@graph.EdgeInput::new(0, "a", "d", false, true))
  g.edges.push(@graph.EdgeInput::new(1, "b", "c", false, true))

  let n = g.objects.length()
  let id_to_idx : Map[String, Int] = Map::new(capacity=n * 2)
  for i in 0..<n {
    id_to_idx[g.objects[i].id] = i
  }
  let plan = els_tarjan_plan(g)
  let (self_loop, reversed) = dag_edge_index_sets(plan)
  let depths = compute_depths(n, g, id_to_idx, plan, self_loop, reversed)
  let levels = make_levels(g, depths)
  assert_true(levels.length() == 2)
  let upper_pos : Map[String, Int] = {}
  let lower_pos : Map[String, Int] = {}
  for i, id in levels[0] {
    upper_pos[id] = i
  }
  for i, id in levels[1] {
    lower_pos[id] = i
  }
  let a_before_b = upper_pos.get("a").unwrap_or(0) <
    upper_pos.get("b").unwrap_or(0)
  let d_before_c = lower_pos.get("d").unwrap_or(0) <
    lower_pos.get("c").unwrap_or(0)
  assert_true(
    a_before_b == d_before_c,
    msg="layer ordering should align edge pairs to avoid the simple crossing",
  )
}

///|
test "railway object size expands for long labels" {
  let cfg = @engine_api.LayoutConfig::new()
  let obj = @graph.ObjectInput::new(
    "this_is_a_super_long_node_label_for_railway_engine",
  )
  let (w, h) = object_size(obj, cfg)
  assert_true(w > cfg.default_width)
  assert_true(h >= cfg.default_height)
}

///|
test "railway parallel vertical edges avoid endpoint zig-zag" {
  let user = @graph.ObjectInput::new("user")
  let client = @graph.ObjectInput::new("client")
  let server = @graph.ObjectInput::new("server")
  let database = @graph.ObjectInput::new("database")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([user, client, server, database])
  // user -> client -> server -> database
  g.edges.push(@graph.EdgeInput::new(0, "user", "client", false, true))
  g.edges.push(@graph.EdgeInput::new(1, "client", "server", true, true))
  g.edges.push(@graph.EdgeInput::new(2, "client", "server", false, true))
  g.edges.push(@graph.EdgeInput::new(3, "server", "database", false, true))
  g.edges.push(@graph.EdgeInput::new(4, "server", "database", false, true))

  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  fn route_is_straight_vertical(route : Array[@graph.Point]) -> Bool {
    if route.length() < 2 {
      return false
    }
    let start = route[0]
    let end = route[route.length() - 1]
    (start.x - end.x).abs() <= 0.000001
  }
  assert_true(route_is_straight_vertical(patch.edges.get(2).unwrap_or([])))
  assert_true(route_is_straight_vertical(patch.edges.get(4).unwrap_or([])))
}

///|
test "railway vertical flow keeps arrow tangent vertical" {
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let c = @graph.ObjectInput::new("c")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b, c])
  g.edges.push(@graph.EdgeInput::new(0, "a", "b", false, true))
  g.edges.push(@graph.EdgeInput::new(1, "b", "c", false, true))
  g.edges.push(@graph.EdgeInput::new(2, "c", "a", false, true))
  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  fn has_vertical_end_tangent(route : Array[@graph.Point]) -> Bool {
    if route.length() < 2 {
      return false
    }
    let n = route.length()
    let prev = route[n - 2]
    let end = route[n - 1]
    (prev.x - end.x).abs() <= 0.000001
  }
  fn has_vertical_start_tangent(route : Array[@graph.Point]) -> Bool {
    if route.length() < 2 {
      return false
    }
    let first = route[0]
    let second = route[1]
    (first.x - second.x).abs() <= 0.000001
  }
  for edge in g.edges {
    let route = patch.edges.get(edge.index).unwrap_or([])
    assert_true(
      has_vertical_end_tangent(route),
      msg="edge \{edge.index} should keep vertical tangent at end",
    )
    if route.length() >= 2 {
      let first = route[0]
      let last = route[route.length() - 1]
      if last.y >= first.y {
        assert_true(
          has_vertical_start_tangent(route),
          msg="forward edge \{edge.index} should keep vertical start tangent",
        )
      }
    }
  }
}

///|
test "railway keeps parallel same-endpoint edges separated" {
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([a, b])
  g.edges.push(@graph.EdgeInput::new(0, "a", "b", false, true))
  g.edges.push(@graph.EdgeInput::new(1, "a", "b", false, true))
  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  let r0 = patch.edges.get(0).unwrap_or([])
  let r1 = patch.edges.get(1).unwrap_or([])
  assert_true(r0.length() >= 2 && r1.length() >= 2)
  assert_true((r0[0].x - r1[0].x).abs() >= 12.0)
}

///|
test "railway fits container box around children" {
  let container = @graph.ObjectInput::from_parts(
    "container",
    "container",
    @graph.Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["a", "b"],
    0,
    None,
    None,
    None,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([container, a, b])
  g.edges.push(@graph.EdgeInput::new(0, "a", "b", false, true))
  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  let c_box = patch.nodes.get("container").unwrap()
  let a_box = patch.nodes.get("a").unwrap()
  let b_box = patch.nodes.get("b").unwrap()
  let child_min_x = @cmp.minimum(a_box.x, b_box.x)
  let child_max_x = @cmp.maximum(a_box.x + a_box.width, b_box.x + b_box.width)
  let child_min_y = @cmp.minimum(a_box.y, b_box.y)
  let child_max_y = @cmp.maximum(a_box.y + a_box.height, b_box.y + b_box.height)
  assert_true(c_box.x <= child_min_x)
  assert_true(c_box.y <= child_min_y)
  assert_true(c_box.x + c_box.width >= child_max_x)
  assert_true(c_box.y + c_box.height >= child_max_y)
}

///|
test "railway keeps external node outside container bounds" {
  let container = @graph.ObjectInput::from_parts(
    "container",
    "container",
    @graph.Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["a", "b"],
    0,
    None,
    None,
    None,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
  let a = @graph.ObjectInput::new("a")
  let b = @graph.ObjectInput::new("b")
  let c = @graph.ObjectInput::new("c")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([container, a, b, c])
  g.edges.push(@graph.EdgeInput::new(0, "a", "b", false, true))
  g.edges.push(@graph.EdgeInput::new(1, "b", "c", false, true))
  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  let ctn = patch.nodes.get("container").unwrap()
  let out = patch.nodes.get("c").unwrap()
  let overlap_x = !(out.x + out.width <= ctn.x || ctn.x + ctn.width <= out.x)
  let overlap_y = !(out.y + out.height <= ctn.y || ctn.y + ctn.height <= out.y)
  assert_true(!(overlap_x && overlap_y))
}

///|
test "railway spreads overlapping siblings in same container" {
  let container = @graph.ObjectInput::from_parts(
    "container",
    "container",
    @graph.Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["left", "right"],
    0,
    None,
    None,
    None,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
  let left = @graph.ObjectInput::new("left")
  let right = @graph.ObjectInput::new("right")
  let g = @graph.GraphInput::new("testgraph")
  g.objects.append([container, left, right])
  let (object_by_id, parent_id_by_child_id) = build_object_maps_railway(g)
  let boxes : Map[String, @graph.Box] = {}
  boxes["left"] = @graph.Box::new(100.0, 200.0, 120.0, 60.0)
  boxes["right"] = @graph.Box::new(150.0, 200.0, 100.0, 60.0)
  spread_sibling_boxes_railway(
    boxes,
    object_by_id,
    parent_id_by_child_id,
    @engine_api.Down,
    @engine_api.LayoutConfig::new(),
  )
  let l = boxes.get("left").unwrap()
  let r = boxes.get("right").unwrap()
  assert_true(r.x >= l.x + l.width + 12.0)
}

///|
test "railway readability gate on architecture style DAG" {
  let users = @graph.ObjectInput::new("users")
  let cdn = @graph.ObjectInput::new("cdn")
  let lb = @graph.ObjectInput::new("lb")
  let web1 = @graph.ObjectInput::new("web1")
  let web2 = @graph.ObjectInput::new("web2")
  let web3 = @graph.ObjectInput::new("web3")
  let app1 = @graph.ObjectInput::new("app1")
  let app2 = @graph.ObjectInput::new("app2")
  let cache = @graph.ObjectInput::new("cache")
  let primary = @graph.ObjectInput::new("primary")
  let queue = @graph.ObjectInput::new("queue")
  let worker1 = @graph.ObjectInput::new("worker1")
  let worker2 = @graph.ObjectInput::new("worker2")
  let storage = @graph.ObjectInput::new("storage")

  let g = @graph.GraphInput::new("architecture_gate")
  g.objects.append([
    users, cdn, lb, web1, web2, web3, app1, app2, cache, primary, queue, worker1,
    worker2, storage,
  ])
  g.edges.push(@graph.EdgeInput::new(0, "users", "cdn", false, true))
  g.edges.push(@graph.EdgeInput::new(1, "cdn", "lb", false, true))
  g.edges.push(@graph.EdgeInput::new(2, "lb", "web1", false, true))
  g.edges.push(@graph.EdgeInput::new(3, "lb", "web2", false, true))
  g.edges.push(@graph.EdgeInput::new(4, "lb", "web3", false, true))
  g.edges.push(@graph.EdgeInput::new(5, "web1", "app1", false, true))
  g.edges.push(@graph.EdgeInput::new(6, "web2", "app1", false, true))
  g.edges.push(@graph.EdgeInput::new(7, "web2", "app2", false, true))
  g.edges.push(@graph.EdgeInput::new(8, "web3", "app2", false, true))
  g.edges.push(@graph.EdgeInput::new(9, "app1", "cache", false, true))
  g.edges.push(@graph.EdgeInput::new(10, "app2", "cache", false, true))
  g.edges.push(@graph.EdgeInput::new(11, "app1", "primary", false, true))
  g.edges.push(@graph.EdgeInput::new(12, "app2", "primary", false, true))
  g.edges.push(@graph.EdgeInput::new(13, "app1", "queue", false, true))
  g.edges.push(@graph.EdgeInput::new(14, "app2", "queue", false, true))
  g.edges.push(@graph.EdgeInput::new(15, "queue", "worker1", false, true))
  g.edges.push(@graph.EdgeInput::new(16, "queue", "worker2", false, true))
  g.edges.push(@graph.EdgeInput::new(17, "worker1", "storage", false, true))
  g.edges.push(@graph.EdgeInput::new(18, "worker2", "storage", false, true))
  g.edges.push(@graph.EdgeInput::new(19, "worker1", "primary", false, true))

  let patch = layout_graph(g, @engine_api.LayoutConfig::new(), @engine_api.Down)
  let (
    crossing_count,
    label_overlap_count,
    node_overlap_count,
    long_detour_count,
    edge_total_length,
  ) = railway_readability_metrics(g, patch)
  assert_true(node_overlap_count == 0, msg="nodes should not overlap")
  assert_true(label_overlap_count == 0, msg="edge labels should not overlap")
  assert_true(
    crossing_count <= 12,
    msg="crossing gate exceeded: \{crossing_count}",
  )
  assert_true(
    long_detour_count <= 4,
    msg="detour gate exceeded: \{long_detour_count}",
  )
  assert_true(edge_total_length > 0.0)
}

///|
test "railway sequence layout keeps participants aligned and messages horizontal" {
  let root = @graph.ObjectInput::from_parts(
    "root",
    "root",
    @graph.SequenceDiagram,
    @graph.StyleInput::new(),
    None,
    None,
    ["alice", "bob", "server"],
    0,
    None,
    None,
    None,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
  let alice = @graph.ObjectInput::new("alice")
  let bob = @graph.ObjectInput::new("bob")
  let server = @graph.ObjectInput::new("server")
  fn seq_edge(
    index : Int,
    src : String,
    dst : String,
    label : String,
  ) -> @graph.EdgeInput {
    @graph.EdgeInput::from_parts(
      index,
      src,
      dst,
      false,
      true,
      @graph.None,
      @graph.Triangle,
      None,
      None,
      label,
      @graph.StyleInput::new(),
      [],
      None,
      false,
      0,
      1,
      None,
      None,
      None,
    )
  }

  let graph = @graph.GraphInput::from_parts(
    "sequence_test",
    root,
    [alice, bob, server],
    [
      seq_edge(0, "alice", "bob", "Hello"),
      seq_edge(1, "bob", "alice", "Hi there!"),
      seq_edge(2, "alice", "server", "Request data"),
      seq_edge(3, "server", "alice", "Response"),
    ],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    None,
  )
  let patch = layout_graph(
    graph,
    @engine_api.LayoutConfig::new(),
    @engine_api.Down,
  )
  let a = patch.nodes.get("alice").unwrap()
  let b = patch.nodes.get("bob").unwrap()
  let s = patch.nodes.get("server").unwrap()
  assert_true(a.y == b.y && b.y == s.y, msg="participants should share top y")
  assert_true(
    a.x < b.x && b.x < s.x,
    msg="participants should be in declared order",
  )

  for edge in graph.edges {
    let route = patch.edges.get(edge.index).unwrap_or([])
    assert_true(route.length() >= 2)
    assert_true(
      route[0].y == route[1].y,
      msg="message edge should start horizontal",
    )
  }

  let l0 = patch.edge_labels.get(0).unwrap()
  let l1 = patch.edge_labels.get(1).unwrap()
  let overlap = !(l0.x + l0.width <= l1.x ||
    l1.x + l1.width <= l0.x ||
    l0.y + l0.height <= l1.y ||
    l1.y + l1.height <= l0.y)
  assert_true(!overlap, msg="adjacent sequence labels should not overlap")
}
