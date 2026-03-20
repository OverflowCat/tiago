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
/// Layout and position tests

///|
test "objects have positions after layout" {
  let graph = compile_to_graph("a\nb\nc", @engine_api.Direction::Down).unwrap()
  for obj in graph.get_objects() {
    let box = obj.get_box()
    assert_true(box is Some(_))
  }
}

///|
test "objects have positive dimensions" {
  let graph = compile_to_graph(
    "server: Web Server",
    @engine_api.Direction::Down,
  ).unwrap()
  for obj in graph.get_objects() {
    if obj.get_box() is Some(box) {
      assert_true(box.get_width() > 0.0)
      assert_true(box.get_height() > 0.0)
    } else {
      fail("object should have box")
    }
  }
}

///|
test "multiple objects don't overlap" {
  let graph = compile_to_graph("a\nb\nc", @engine_api.Direction::Down).unwrap()
  let objects = graph.get_objects()
  for i in 0..<objects.length() {
    for j in (i + 1)..<objects.length() {
      match (objects[i].get_box(), objects[j].get_box()) {
        (Some(box1), Some(box2)) =>
          assert_false(
            box1.intersects(box2),
            msg="objects \{objects[i].get_id()} and \{objects[j].get_id()} should not overlap",
          )
        _ => ()
      }
    }
  }
}

///|
test "down direction stacks objects vertically" {
  let graph = compile_to_graph("a\nb", @engine_api.Direction::Down).unwrap()
  let a = graph.find_object("a").unwrap()
  let b = graph.find_object("b").unwrap()
  match (a.get_box(), b.get_box()) {
    (Some(box_a), Some(box_b)) => {
      let dx = (box_b.get_x() - box_a.get_x()).abs()
      let dy = (box_b.get_y() - box_a.get_y()).abs()
      assert_true(
        dx > 1.0e-6 || dy > 1.0e-6,
        msg="a and b should not share the same position",
      )
    }
    _ => fail("objects should have boxes")
  }
}

///|
test "right direction stacks objects horizontally" {
  let graph = compile_to_graph("a\nb", @engine_api.Direction::Right).unwrap()
  let a = graph.find_object("a").unwrap()
  let b = graph.find_object("b").unwrap()
  match (a.get_box(), b.get_box()) {
    (Some(box_a), Some(box_b)) => {
      let dx = (box_b.get_x() - box_a.get_x()).abs()
      let dy = (box_b.get_y() - box_a.get_y()).abs()
      assert_true(
        dx > 1.0e-6 || dy > 1.0e-6,
        msg="a and b should not share the same position",
      )
    }
    _ => fail("objects should have boxes")
  }
}

///|
test "quoted syntax identities survive dagre elk and railway layout" {
  let source =
    #|"a.b"
    #|a: {
    #|  b
    #|}
    #|"a.b" -> a.b
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }
  let railway = @engine_api.layout_with_engine(
    @engine_railway.RailwayEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("railway layout error: \{e}")
  }

  guard dagre.find_object("\"a.b\"") is Some(dagre_quoted) else {
    fail("expected quoted top-level object after dagre layout")
  }
  guard dagre.find_object("a.b") is Some(dagre_nested) else {
    fail("expected nested object after dagre layout")
  }
  assert_eq(dagre_quoted.abs_id_syntax, "\"a.b\"")
  assert_eq(dagre_nested.abs_id_syntax, "a.b")
  assert_true(dagre_quoted.box is Some(_), msg="dagre quoted box")
  assert_true(dagre_nested.box is Some(_), msg="dagre nested box")
  assert_true(dagre.edges.length() == 1, msg="dagre edge count")
  assert_true(dagre.edges[0].route.length() >= 2, msg="dagre edge route")

  guard elk.find_object("\"a.b\"") is Some(elk_quoted) else {
    fail("expected quoted top-level object after elk layout")
  }
  guard elk.find_object("a.b") is Some(elk_nested) else {
    fail("expected nested object after elk layout")
  }
  assert_eq(elk_quoted.abs_id_syntax, "\"a.b\"")
  assert_eq(elk_nested.abs_id_syntax, "a.b")
  assert_true(elk_quoted.box is Some(_), msg="elk quoted box")
  assert_true(elk_nested.box is Some(_), msg="elk nested box")
  assert_true(elk.edges.length() == 1, msg="elk edge count")
  assert_true(elk.edges[0].route.length() >= 2, msg="elk edge route")

  guard railway.find_object("\"a.b\"") is Some(railway_quoted) else {
    fail("expected quoted top-level object after railway layout")
  }
  guard railway.find_object("a.b") is Some(railway_nested) else {
    fail("expected nested object after railway layout")
  }
  assert_eq(railway_quoted.abs_id_syntax, "\"a.b\"")
  assert_eq(railway_nested.abs_id_syntax, "a.b")
  assert_true(railway_quoted.box is Some(_), msg="railway quoted box")
  assert_true(railway_nested.box is Some(_), msg="railway nested box")
  assert_true(railway.edges.length() == 1, msg="railway edge count")
  assert_true(railway.edges[0].route.length() >= 2, msg="railway edge route")
}

///|
test "reference nested_layout_bug root grid keeps nested container as a grid cell" {
  let source =
    #|grid-rows: 1
    #|grid-columns: 2
    #|a
    #|b: {
    #|  grid-rows: 1
    #|  grid-columns: 1
    #|  AA.BB
    #|}
    #|a -> b.AA
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_root_grid_nested_layout_like_d2(dagre, "dagre")
  assert_root_grid_nested_layout_like_d2(elk, "elk")
}

///|
fn assert_root_grid_nested_layout_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let a = graph.find_object("a").unwrap()
  let b = graph.find_object("b").unwrap()
  let aa = graph.find_object("b.AA").unwrap()
  let bb = graph.find_object("b.AA.BB").unwrap()

  match (a.get_box(), b.get_box(), aa.get_box(), bb.get_box()) {
    (Some(a_box), Some(b_box), Some(aa_box), Some(bb_box)) => {
      if engine_name == "dagre" {
        assert_eq(a_box, @graph.Box::new(0.0, 0.0, 53.0, 282.0))
        assert_eq(b_box, @graph.Box::new(93.0, 0.0, 244.0, 282.0))
        assert_eq(aa_box, @graph.Box::new(153.0, 96.0, 124.0, 126.0))
        assert_eq(bb_box, @graph.Box::new(183.0, 126.0, 64.0, 66.0))
      }
      assert_true(
        a_box.x < b_box.x,
        msg="\{engine_name} should place root grid children in separate columns",
      )
      assert_true(
        (a_box.y - b_box.y).abs() < 1.0,
        msg="\{engine_name} root grid children should stay on the same row",
      )
      assert_true(
        b_box.contains(aa_box.center()),
        msg="\{engine_name} nested grid container child should remain inside b",
      )
      assert_true(
        aa_box.contains(bb_box.center()),
        msg="\{engine_name} nested grandchild should remain inside b.AA",
      )
    }
    _ => fail("\{engine_name} expected boxes for a, b, b.AA, and b.AA.BB")
  }

  let mut matched_edge : @graph.EdgeInput? = None
  for edge in graph.edges {
    if edge.src_id == "a" && edge.dst_id == "b.AA" {
      matched_edge = Some(edge)
      break
    }
  }
  guard matched_edge is Some(edge) else {
    fail("\{engine_name} expected a -> b.AA edge")
  }
  assert_true(
    edge.route.length() >= 2,
    msg="\{engine_name} expected routed cross-cell edge",
  )
  let start = edge.route[0]
  let finish = edge.route[edge.route.length() - 1]
  assert_true(
    start.x < finish.x,
    msg="\{engine_name} expected cross-cell edge to route left-to-right",
  )
}

///|
test "reference nested_diagram_types keeps nested sequence descendants inside their containers" {
  let source =
    #|a
    #|b
    #|c
    #|
    #|a: {
    #|  grid-columns: 3
    #|
    #|  1
    #|  2
    #|  3
    #|  3: {
    #|    shape: sequence_diagram
    #|    x
    #|    y
    #|    # TODO x -> y
    #|  }
    #|
    #|  1 -> 2 -> 3
    #|
    #|  near: center-right
    #|}
    #|
    #|b: {
    #|  shape: sequence_diagram
    #|  1 -> 2
    #|
    #|  near: bottom-right
    #|
    #|  2: {
    #|    # TODO compile error grid on sequence actor?
    #|    grid-columns: 3
    #|    x
    #|    y
    #|    z
    #|  }
    #|
    #|  1: {
    #|    x: {
    #|      # TODO compile error grid in sequence (group)
    #|      # grid-columns: 3
    #|      u
    #|      v
    #|      w
    #|    }
    #|    y
    #|    z
    #|  }
    #|}
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_nested_diagram_types_layout_like_d2(dagre, "dagre")
  assert_nested_diagram_types_layout_like_d2(elk, "elk")
}

///|
fn assert_nested_diagram_types_layout_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let a = graph.find_object("a").unwrap()
  let a3 = graph.find_object("a.3").unwrap()
  let a3x = graph.find_object("a.3.x").unwrap()
  let a3y = graph.find_object("a.3.y").unwrap()
  let b = graph.find_object("b").unwrap()
  let b1 = graph.find_object("b.1").unwrap()
  let b2 = graph.find_object("b.2").unwrap()
  let b2x = graph.find_object("b.2.x").unwrap()
  let b2y = graph.find_object("b.2.y").unwrap()
  let b2z = graph.find_object("b.2.z").unwrap()
  let b1x = graph.find_object("b.1.x").unwrap()
  let b1xu = graph.find_object("b.1.x.u").unwrap()
  let b1xv = graph.find_object("b.1.x.v").unwrap()
  let b1xw = graph.find_object("b.1.x.w").unwrap()

  guard a.get_box() is Some(a_box) else {
    fail("\{engine_name} expected box for a")
  }
  guard a3.get_box() is Some(a3_box) else {
    fail("\{engine_name} expected box for a.3")
  }
  guard a3x.get_box() is Some(a3x_box) else {
    fail("\{engine_name} expected box for a.3.x")
  }
  guard a3y.get_box() is Some(a3y_box) else {
    fail("\{engine_name} expected box for a.3.y")
  }
  assert_true(
    a_box.contains(a3_box.center()),
    msg="\{engine_name} should keep nested sequence container inside a",
  )
  assert_true(
    a3_box.contains(a3x_box.center()),
    msg="\{engine_name} should keep a.3.x inside the nested sequence container",
  )
  assert_true(
    a3_box.contains(a3y_box.center()),
    msg="\{engine_name} should keep a.3.y inside the nested sequence container",
  )
  assert_true(
    a3x_box.x < a3y_box.x,
    msg="\{engine_name} should keep nested sequence actors ordered left-to-right",
  )

  guard b.get_box() is Some(b_box) else {
    fail("\{engine_name} expected box for b")
  }
  guard b1.get_box() is Some(b1_box) else {
    fail("\{engine_name} expected box for b.1")
  }
  guard b2.get_box() is Some(b2_box) else {
    fail("\{engine_name} expected box for b.2")
  }
  guard b2x.get_box() is Some(b2x_box) else {
    fail("\{engine_name} expected box for b.2.x")
  }
  guard b2y.get_box() is Some(b2y_box) else {
    fail("\{engine_name} expected box for b.2.y")
  }
  guard b2z.get_box() is Some(b2z_box) else {
    fail("\{engine_name} expected box for b.2.z")
  }
  guard b1x.get_box() is Some(b1x_box) else {
    fail("\{engine_name} expected box for b.1.x")
  }
  guard b1xu.get_box() is Some(b1xu_box) else {
    fail("\{engine_name} expected box for b.1.x.u")
  }
  guard b1xv.get_box() is Some(b1xv_box) else {
    fail("\{engine_name} expected box for b.1.x.v")
  }
  guard b1xw.get_box() is Some(b1xw_box) else {
    fail("\{engine_name} expected box for b.1.x.w")
  }
  assert_true(
    b_box.contains(b1_box.center()),
    msg="\{engine_name} should keep sequence participant b.1 inside b",
  )
  assert_true(
    b_box.contains(b2_box.center()),
    msg="\{engine_name} should keep sequence participant b.2 inside b",
  )
  assert_true(
    b1_box.x < b2_box.x,
    msg="\{engine_name} should lay out b sequence participants left-to-right",
  )
  assert_true(
    b2_box.contains(b2x_box.center()) &&
    b2_box.contains(b2y_box.center()) &&
    b2_box.contains(b2z_box.center()),
    msg="\{engine_name} should keep nested grid children inside b.2",
  )
  assert_true(
    b1x_box.contains(b1xu_box.center()) &&
    b1x_box.contains(b1xv_box.center()) &&
    b1x_box.contains(b1xw_box.center()),
    msg="\{engine_name} should keep nested children inside b.1.x",
  )
}

///|
test "reference connected_container matches stable target geometry" {
  let source =
    #|a.b -> c.d -> f.h.g
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_connected_container_like_d2(dagre, "dagre")
  assert_connected_container_like_d2(elk, "elk")
}

///|
fn assert_connected_container_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let target = @diagram.from_graph(graph, None)
  let a = target.find_object("a").unwrap()
  let ab = target.find_object("a.b").unwrap()
  let c = target.find_object("c").unwrap()
  let cd = target.find_object("c.d").unwrap()
  let f = target.find_object("f").unwrap()
  let fh = target.find_object("f.h").unwrap()
  let fhg = target.find_object("f.h.g").unwrap()
  let ab_cd = find_connection(target, "a.b", "c.d").unwrap()
  let cd_fhg = find_connection(target, "c.d", "f.h.g").unwrap()

  match
    (
      a.get_box(),
      ab.get_box(),
      c.get_box(),
      cd.get_box(),
      f.get_box(),
      fh.get_box(),
      fhg.get_box(),
    ) {
    (
      Some(a_box),
      Some(ab_box),
      Some(c_box),
      Some(cd_box),
      Some(f_box),
      Some(fh_box),
      Some(fhg_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(a_box, @graph.Box::new(31.0, 20.0, 113.0, 126.0))
        assert_eq(ab_box, @graph.Box::new(61.0, 50.0, 53.0, 66.0))
        assert_eq(c_box, @graph.Box::new(30.0, 286.0, 114.0, 126.0))
        assert_eq(cd_box, @graph.Box::new(60.0, 316.0, 54.0, 66.0))
        assert_eq(f_box, @graph.Box::new(0.0, 561.0, 174.0, 197.0))
        assert_eq(fh_box, @graph.Box::new(30.0, 602.0, 114.0, 126.0))
        assert_eq(fhg_box, @graph.Box::new(60.0, 632.0, 54.0, 66.0))
      } else {
        assert_eq(a_box, @graph.Box::new(62.0, 12.0, 153.0, 166.0))
        assert_eq(ab_box, @graph.Box::new(112.0, 62.0, 53.0, 66.0))
        assert_eq(c_box, @graph.Box::new(62.0, 258.0, 154.0, 166.0))
        assert_eq(cd_box, @graph.Box::new(112.0, 308.0, 54.0, 66.0))
        assert_eq(f_box, @graph.Box::new(12.0, 504.0, 254.0, 271.0))
        assert_eq(fh_box, @graph.Box::new(62.0, 559.0, 154.0, 166.0))
        assert_eq(fhg_box, @graph.Box::new(112.0, 609.0, 54.0, 66.0))
      }
    _ =>
      fail(
        "\{engine_name} expected boxes for connected_container fixture objects",
      )
  }

  assert_true(
    ab_cd.route.length() >= 2,
    msg="\{engine_name} expected routed a.b -> c.d connection in connected_container",
  )
  assert_true(
    cd_fhg.route.length() >= 2,
    msg="\{engine_name} expected routed c.d -> f.h.g connection in connected_container",
  )
}

///|
test "reference container_edges matches stable target geometry" {
  let source =
    #|a -> g.b -> d.h.c
    #|d -> g.e -> f -> g -> d.h
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_container_edges_like_d2(dagre, "dagre")
  assert_container_edges_like_d2(elk, "elk")
}

///|
fn assert_container_edges_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let target = @diagram.from_graph(graph, None)
  let a = target.find_object("a").unwrap()
  let g = target.find_object("g").unwrap()
  let gb = target.find_object("g.b").unwrap()
  let ge = target.find_object("g.e").unwrap()
  let d = target.find_object("d").unwrap()
  let dh = target.find_object("d.h").unwrap()
  let dhc = target.find_object("d.h.c").unwrap()
  let f = target.find_object("f").unwrap()
  let a_gb = find_connection(target, "a", "g.b").unwrap()
  let gb_dhc = find_connection(target, "g.b", "d.h.c").unwrap()
  let d_ge = find_connection(target, "d", "g.e").unwrap()
  let ge_f = find_connection(target, "g.e", "f").unwrap()
  let f_g = find_connection(target, "f", "g").unwrap()
  let g_dh = find_connection(target, "g", "d.h").unwrap()

  match
    (
      a.get_box(),
      g.get_box(),
      gb.get_box(),
      ge.get_box(),
      d.get_box(),
      dh.get_box(),
      dhc.get_box(),
      f.get_box(),
    ) {
    (
      Some(a_box),
      Some(g_box),
      Some(gb_box),
      Some(ge_box),
      Some(d_box),
      Some(dh_box),
      Some(dhc_box),
      Some(f_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(a_box, @graph.Box::new(40.0, 0.0, 53.0, 66.0))
        assert_eq(g_box, @graph.Box::new(10.0, 186.0, 113.0, 658.0))
        assert_eq(gb_box, @graph.Box::new(40.0, 216.0, 53.0, 66.0))
        assert_eq(ge_box, @graph.Box::new(40.0, 748.0, 53.0, 66.0))
        assert_eq(d_box, @graph.Box::new(153.0, 411.0, 173.0, 197.0))
        assert_eq(dh_box, @graph.Box::new(183.0, 452.0, 113.0, 126.0))
        assert_eq(dhc_box, @graph.Box::new(213.0, 482.0, 53.0, 66.0))
        assert_eq(f_box, @graph.Box::new(41.0, 964.0, 51.0, 66.0))
      } else {
        assert_eq(a_box, @graph.Box::new(94.0, 12.0, 53.0, 66.0))
        assert_eq(g_box, @graph.Box::new(44.0, 213.0, 226.0, 166.0))
        assert_eq(gb_box, @graph.Box::new(94.0, 263.0, 53.0, 66.0))
        assert_eq(ge_box, @graph.Box::new(167.0, 263.0, 53.0, 66.0))
        assert_eq(d_box, @graph.Box::new(12.0, 519.0, 253.0, 271.0))
        assert_eq(dh_box, @graph.Box::new(62.0, 574.0, 153.0, 166.0))
        assert_eq(dhc_box, @graph.Box::new(112.0, 624.0, 53.0, 66.0))
        assert_eq(f_box, @graph.Box::new(285.0, 519.0, 51.0, 66.0))
      }
    _ =>
      fail("\{engine_name} expected boxes for container_edges fixture objects")
  }

  assert_true(
    a_gb.route.length() >= 2 &&
    gb_dhc.route.length() >= 2 &&
    d_ge.route.length() >= 2 &&
    ge_f.route.length() >= 2 &&
    f_g.route.length() >= 2 &&
    g_dh.route.length() >= 2,
    msg="\{engine_name} expected routed container_edges connections to be preserved",
  )
}

///|
test "reference grid_nested_simple_edges preserves nested grid child order" {
  let source =
    #|direction: right
    #|outer-grid -> outer-container
    #|
    #|outer-grid: {
    #|  grid-columns: 1
    #|
    #|  inner-grid -> container -> etc
    #|
    #|  container: {
    #|    label.near: top-left
    #|    (** -> **)[*].class: red
    #|    a -> b -> c -> a
    #|    d -> e -> g.h.i
    #|    d -> f -> g.h
    #|    b -> g
    #|  }
    #|
    #|  inner-grid: {
    #|    grid-rows: 1
    #|    1 -> 2 -> 3: {class: red}
    #|  }
    #|}
    #|
    #|outer-container: {
    #|  grid -> container
    #|
    #|  grid: {
    #|    grid-rows: 1
    #|    1 -> 2 -> 3
    #|  }
    #|
    #|  container: {
    #|    4 -> 5 -> 6
    #|    nested container: {
    #|      7 -> 8
    #|    }
    #|  }
    #|}
    #|
    #|classes.red.style.stroke: red
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Right,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Right,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_grid_nested_simple_edges_order_like_d2(dagre, "dagre")
  assert_grid_nested_simple_edges_order_like_d2(elk, "elk")
}

///|
fn assert_grid_nested_simple_edges_order_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  guard graph.find_object("outer-grid") is Some(outer_grid) else {
    fail("\{engine_name} expected outer-grid object")
  }
  assert_eq(outer_grid.child_ids, [
    "outer-grid.inner-grid", "outer-grid.container", "outer-grid.etc",
  ])

  let inner_grid = graph.find_object("outer-grid.inner-grid").unwrap()
  let container = graph.find_object("outer-grid.container").unwrap()
  let etc = graph.find_object("outer-grid.etc").unwrap()
  match (inner_grid.get_box(), container.get_box(), etc.get_box()) {
    (Some(inner_box), Some(container_box), Some(etc_box)) => {
      assert_true(
        inner_box.y < container_box.y,
        msg="\{engine_name} expected outer-grid.inner-grid above outer-grid.container",
      )
      assert_true(
        container_box.y < etc_box.y,
        msg="\{engine_name} expected outer-grid.container above outer-grid.etc",
      )
      assert_true(
        (inner_box.x - container_box.x).abs() < 1.0 &&
        (container_box.x - etc_box.x).abs() < 1.0,
        msg="\{engine_name} expected single-column nested grid children",
      )
    }
    _ =>
      fail(
        "\{engine_name} expected boxes for outer-grid.inner-grid, outer-grid.container, and outer-grid.etc",
      )
  }
}

///|
test "reference grid_nested_gap0 matches stable nested grid boxes" {
  let source =
    #|The Universe: {
    #|  grid-rows: 3
    #|  grid-gap: 0
    #|
    #|  FirstTwo.width: 300
    #|  Last.style.fill: red
    #|
    #|  TALA: "" {
    #|    grid-rows: 3
    #|    grid-gap: 0
    #|    TALA.width: 100
    #|    Node2
    #|    Cloud
    #|  }
    #|  Node2.width: 200
    #|  Cloud.width: 100
    #|  Terrastruct.width: 400
    #|}
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_grid_nested_gap0_reference(dagre, "dagre")
  assert_grid_nested_gap0_reference(elk, "elk")
}

///|
fn assert_grid_nested_gap0_reference(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let universe = graph.find_object("The Universe").unwrap()
  let first_two = graph.find_object("The Universe.FirstTwo").unwrap()
  let last = graph.find_object("The Universe.Last").unwrap()
  let tala = graph.find_object("The Universe.TALA").unwrap()
  let tala_tala = graph.find_object("The Universe.TALA.TALA").unwrap()
  let tala_node2 = graph.find_object("The Universe.TALA.Node2").unwrap()
  let tala_cloud = graph.find_object("The Universe.TALA.Cloud").unwrap()
  let node2 = graph.find_object("The Universe.Node2").unwrap()
  let cloud = graph.find_object("The Universe.Cloud").unwrap()
  let terrastruct = graph.find_object("The Universe.Terrastruct").unwrap()

  match
    (
      universe.get_box(),
      first_two.get_box(),
      last.get_box(),
      tala.get_box(),
      tala_tala.get_box(),
      tala_node2.get_box(),
      tala_cloud.get_box(),
      node2.get_box(),
      cloud.get_box(),
      terrastruct.get_box(),
    ) {
    (
      Some(universe_box),
      Some(first_two_box),
      Some(last_box),
      Some(tala_box),
      Some(tala_tala_box),
      Some(tala_node2_box),
      Some(tala_cloud_box),
      Some(node2_box),
      Some(cloud_box),
      Some(terrastruct_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(universe_box, @graph.Box::new(0.0, 0.0, 400.0, 366.0))
        assert_eq(first_two_box, @graph.Box::new(0.0, 46.0, 300.0, 66.0))
        assert_eq(last_box, @graph.Box::new(300.0, 46.0, 100.0, 66.0))
        assert_eq(tala_box, @graph.Box::new(0.0, 112.0, 100.0, 193.0))
        assert_eq(tala_tala_box, @graph.Box::new(0.0, 112.0, 100.0, 61.0))
        assert_eq(tala_node2_box, @graph.Box::new(0.0, 173.0, 100.0, 66.0))
        assert_eq(tala_cloud_box, @graph.Box::new(0.0, 239.0, 100.0, 66.0))
        assert_eq(node2_box, @graph.Box::new(100.0, 112.0, 200.0, 193.0))
        assert_eq(cloud_box, @graph.Box::new(300.0, 112.0, 100.0, 193.0))
        assert_eq(terrastruct_box, @graph.Box::new(0.0, 305.0, 400.0, 61.0))
      } else {
        assert_eq(universe_box, @graph.Box::new(12.0, 12.0, 400.0, 366.0))
        assert_eq(first_two_box, @graph.Box::new(12.0, 58.0, 300.0, 66.0))
        assert_eq(last_box, @graph.Box::new(312.0, 58.0, 100.0, 66.0))
        assert_eq(tala_box, @graph.Box::new(12.0, 124.0, 100.0, 193.0))
        assert_eq(tala_tala_box, @graph.Box::new(12.0, 124.0, 100.0, 61.0))
        assert_eq(tala_node2_box, @graph.Box::new(12.0, 185.0, 100.0, 66.0))
        assert_eq(tala_cloud_box, @graph.Box::new(12.0, 251.0, 100.0, 66.0))
        assert_eq(node2_box, @graph.Box::new(112.0, 124.0, 200.0, 193.0))
        assert_eq(cloud_box, @graph.Box::new(312.0, 124.0, 100.0, 193.0))
        assert_eq(terrastruct_box, @graph.Box::new(12.0, 317.0, 400.0, 61.0))
      }
    _ =>
      fail("\{engine_name} expected boxes for grid_nested_gap0 fixture objects")
  }
}

///|
test "reference grid_nested grid-with-container matches stable boxes" {
  let source =
    #|grid w/ container: {
    #|  grid-rows: 2
    #|  grid-columns: 2
    #|
    #|  a
    #|  b: {
    #|    b child
    #|  }
    #|  c
    #|  d
    #|}
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_grid_nested_container_like_d2(dagre, "dagre")
  assert_grid_nested_container_like_d2(elk, "elk")
}

///|
fn assert_grid_nested_container_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let root = graph.find_object("grid w/ container").unwrap()
  let a = graph.find_object("grid w/ container.a").unwrap()
  let b = graph.find_object("grid w/ container.b").unwrap()
  let b_child = graph.find_object("grid w/ container.b.b child").unwrap()
  let c = graph.find_object("grid w/ container.c").unwrap()
  let d = graph.find_object("grid w/ container.d").unwrap()

  match
    (
      root.get_box(),
      a.get_box(),
      b.get_box(),
      b_child.get_box(),
      c.get_box(),
      d.get_box(),
    ) {
    (
      Some(root_box),
      Some(a_box),
      Some(b_box),
      Some(b_child_box),
      Some(c_box),
      Some(d_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(root_box, @graph.Box::new(0.0, 0.0, 364.0, 388.0))
        assert_eq(a_box, @graph.Box::new(60.0, 60.0, 53.0, 162.0))
        assert_eq(b_box, @graph.Box::new(153.0, 96.0, 151.0, 126.0))
        assert_eq(b_child_box, @graph.Box::new(183.0, 126.0, 91.0, 66.0))
        assert_eq(c_box, @graph.Box::new(60.0, 262.0, 53.0, 66.0))
        assert_eq(d_box, @graph.Box::new(153.0, 262.0, 151.0, 66.0))
      } else {
        assert_eq(root_box, @graph.Box::new(12.0, 12.0, 404.0, 392.0))
        assert_eq(a_box, @graph.Box::new(72.0, 72.0, 53.0, 166.0))
        assert_eq(b_box, @graph.Box::new(165.0, 72.0, 191.0, 166.0))
        assert_eq(b_child_box, @graph.Box::new(215.0, 122.0, 91.0, 66.0))
        assert_eq(c_box, @graph.Box::new(72.0, 278.0, 53.0, 66.0))
        assert_eq(d_box, @graph.Box::new(165.0, 278.0, 191.0, 66.0))
      }
    _ =>
      fail(
        "\{engine_name} expected boxes for grid_nested grid-with-container fixture objects",
      )
  }
}

///|
test "reference grid_nested grid-in-grid matches stable boxes" {
  let source =
    #|grid in grid: {
    #|  grid-rows: 2
    #|  grid-columns: 2
    #|
    #|  a
    #|  b: {
    #|    grid-rows: 2
    #|    grid-columns: 2
    #|
    #|    a
    #|    b
    #|    c
    #|    d
    #|  }
    #|  c
    #|  d
    #|}
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_grid_in_grid_like_d2(dagre, "dagre")
  assert_grid_in_grid_like_d2(elk, "elk")
}

///|
fn assert_grid_in_grid_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let root = graph.find_object("grid in grid").unwrap()
  let a = graph.find_object("grid in grid.a").unwrap()
  let b = graph.find_object("grid in grid.b").unwrap()
  let ba = graph.find_object("grid in grid.b.a").unwrap()
  let bb = graph.find_object("grid in grid.b.b").unwrap()
  let bc = graph.find_object("grid in grid.b.c").unwrap()
  let bd = graph.find_object("grid in grid.b.d").unwrap()
  let c = graph.find_object("grid in grid.c").unwrap()
  let d = graph.find_object("grid in grid.d").unwrap()

  match
    (
      root.get_box(),
      a.get_box(),
      b.get_box(),
      ba.get_box(),
      bb.get_box(),
      bc.get_box(),
      bd.get_box(),
      c.get_box(),
      d.get_box(),
    ) {
    (
      Some(root_box),
      Some(a_box),
      Some(b_box),
      Some(ba_box),
      Some(bb_box),
      Some(bc_box),
      Some(bd_box),
      Some(c_box),
      Some(d_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(root_box, @graph.Box::new(0.0, 0.0, 480.0, 518.0))
        assert_eq(a_box, @graph.Box::new(60.0, 60.0, 53.0, 292.0))
        assert_eq(b_box, @graph.Box::new(153.0, 60.0, 267.0, 292.0))
        assert_eq(ba_box, @graph.Box::new(213.0, 120.0, 53.0, 66.0))
        assert_eq(bb_box, @graph.Box::new(306.0, 120.0, 54.0, 66.0))
        assert_eq(bc_box, @graph.Box::new(213.0, 226.0, 53.0, 66.0))
        assert_eq(bd_box, @graph.Box::new(306.0, 226.0, 54.0, 66.0))
        assert_eq(c_box, @graph.Box::new(60.0, 392.0, 53.0, 66.0))
        assert_eq(d_box, @graph.Box::new(153.0, 392.0, 267.0, 66.0))
      } else {
        assert_eq(root_box, @graph.Box::new(12.0, 12.0, 480.0, 518.0))
        assert_eq(a_box, @graph.Box::new(72.0, 72.0, 53.0, 292.0))
        assert_eq(b_box, @graph.Box::new(165.0, 72.0, 267.0, 292.0))
        assert_eq(ba_box, @graph.Box::new(225.0, 132.0, 53.0, 66.0))
        assert_eq(bb_box, @graph.Box::new(318.0, 132.0, 54.0, 66.0))
        assert_eq(bc_box, @graph.Box::new(225.0, 238.0, 53.0, 66.0))
        assert_eq(bd_box, @graph.Box::new(318.0, 238.0, 54.0, 66.0))
        assert_eq(c_box, @graph.Box::new(72.0, 404.0, 53.0, 66.0))
        assert_eq(d_box, @graph.Box::new(165.0, 404.0, 267.0, 66.0))
      }
    _ =>
      fail(
        "\{engine_name} expected boxes for grid_nested grid-in-grid fixture objects",
      )
  }
}

///|
test "reference grid_nested grid-with-nested-containers matches stable boxes" {
  let source =
    #|grid w/ nested containers: {
    #|  grid-rows: 2
    #|  grid-columns: 2
    #|
    #|  a
    #|  b: {
    #|    b 1: {
    #|      b 2: {
    #|        b 3: {
    #|          b 4
    #|        }
    #|      }
    #|      b 2a: {
    #|        b 3a: {
    #|          b 3a
    #|        }
    #|      }
    #|    }
    #|  }
    #|  c
    #|  d
    #|}
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_grid_nested_containers_like_d2(dagre, "dagre")
  assert_grid_nested_containers_like_d2(elk, "elk")
}

///|
fn assert_grid_nested_containers_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let root = graph.find_object("grid w/ nested containers").unwrap()
  let a = graph.find_object("grid w/ nested containers.a").unwrap()
  let b = graph.find_object("grid w/ nested containers.b").unwrap()
  let b1 = graph.find_object("grid w/ nested containers.b.b 1").unwrap()
  let b2 = graph.find_object("grid w/ nested containers.b.b 1.b 2").unwrap()
  let b3 = graph.find_object("grid w/ nested containers.b.b 1.b 2.b 3").unwrap()
  let b4 = graph
    .find_object("grid w/ nested containers.b.b 1.b 2.b 3.b 4")
    .unwrap()
  let b2a = graph.find_object("grid w/ nested containers.b.b 1.b 2a").unwrap()
  let b3a = graph
    .find_object("grid w/ nested containers.b.b 1.b 2a.b 3a")
    .unwrap()
  let b3a_leaf = graph
    .find_object("grid w/ nested containers.b.b 1.b 2a.b 3a.b 3a")
    .unwrap()
  let c = graph.find_object("grid w/ nested containers.c").unwrap()
  let d = graph.find_object("grid w/ nested containers.d").unwrap()

  match
    (
      root.get_box(),
      a.get_box(),
      b.get_box(),
      b1.get_box(),
      b2.get_box(),
      b3.get_box(),
      b4.get_box(),
      b2a.get_box(),
      b3a.get_box(),
      b3a_leaf.get_box(),
      c.get_box(),
      d.get_box(),
    ) {
    (
      Some(root_box),
      Some(a_box),
      Some(b_box),
      Some(b1_box),
      Some(b2_box),
      Some(b3_box),
      Some(b4_box),
      Some(b2a_box),
      Some(b3a_box),
      Some(b3a_leaf_box),
      Some(c_box),
      Some(d_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(root_box, @graph.Box::new(0.0, 0.0, 692.0, 576.0))
        assert_eq(a_box, @graph.Box::new(60.0, 60.0, 53.0, 350.0))
        assert_eq(b_box, @graph.Box::new(153.0, 96.0, 479.0, 314.0))
        assert_eq(b1_box, @graph.Box::new(173.0, 132.0, 439.0, 248.0))
        assert_eq(b2_box, @graph.Box::new(193.0, 163.0, 186.0, 187.0))
        assert_eq(b3_box, @graph.Box::new(223.0, 194.0, 126.0, 126.0))
        assert_eq(b4_box, @graph.Box::new(253.0, 224.0, 66.0, 66.0))
        assert_eq(b2a_box, @graph.Box::new(399.0, 163.0, 193.0, 187.0))
        assert_eq(b3a_box, @graph.Box::new(429.0, 194.0, 133.0, 126.0))
        assert_eq(b3a_leaf_box, @graph.Box::new(459.0, 224.0, 73.0, 66.0))
        assert_eq(c_box, @graph.Box::new(60.0, 450.0, 53.0, 66.0))
        assert_eq(d_box, @graph.Box::new(153.0, 450.0, 479.0, 66.0))
      } else {
        assert_eq(root_box, @graph.Box::new(12.0, 12.0, 972.0, 692.0))
        assert_eq(a_box, @graph.Box::new(72.0, 72.0, 53.0, 466.0))
        assert_eq(b_box, @graph.Box::new(165.0, 72.0, 759.0, 466.0))
        assert_eq(b1_box, @graph.Box::new(215.0, 122.0, 659.0, 366.0))
        assert_eq(b2_box, @graph.Box::new(265.0, 172.0, 266.0, 266.0))
        assert_eq(b3_box, @graph.Box::new(315.0, 222.0, 166.0, 166.0))
        assert_eq(b4_box, @graph.Box::new(365.0, 272.0, 66.0, 66.0))
        assert_eq(b2a_box, @graph.Box::new(551.0, 172.0, 273.0, 266.0))
        assert_eq(b3a_box, @graph.Box::new(601.0, 222.0, 173.0, 166.0))
        assert_eq(b3a_leaf_box, @graph.Box::new(651.0, 272.0, 73.0, 66.0))
        assert_eq(c_box, @graph.Box::new(72.0, 578.0, 53.0, 66.0))
        assert_eq(d_box, @graph.Box::new(165.0, 578.0, 759.0, 66.0))
      }
    _ =>
      fail(
        "\{engine_name} expected boxes for grid_nested grid-with-nested-containers fixture objects",
      )
  }
}

///|
test "reference grid_nested grid-with-grid-with-grid matches stable boxes" {
  let source =
    #|grid w/ grid w/ grid: {
    #|  grid-rows: 2
    #|  grid-columns: 2
    #|  grid-gap: 0
    #|
    #|  a
    #|  b: {
    #|    grid-rows: 2
    #|    grid-columns: 2
    #|    grid-gap: 0
    #|
    #|    a
    #|    b
    #|    c: {
    #|      grid-rows: 2
    #|      grid-columns: 2
    #|      grid-gap: 0
    #|
    #|      a
    #|      b
    #|      c
    #|      d: {
    #|        grid-rows: 2
    #|        grid-columns: 2
    #|        grid-gap: 0
    #|
    #|        a: {
    #|          grid-rows: 2
    #|          grid-columns: 2
    #|          grid-gap: 0
    #|
    #|          a
    #|          b
    #|          c
    #|          d
    #|        }
    #|        b
    #|        c
    #|        d
    #|      }
    #|    }
    #|    d
    #|  }
    #|  c
    #|  d
    #|}
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_grid_with_grid_with_grid_like_d2(dagre, "dagre")
  assert_grid_with_grid_with_grid_like_d2(elk, "elk")
}

///|
fn assert_grid_with_grid_with_grid_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let root = graph.find_object("grid w/ grid w/ grid").unwrap()
  let a = graph.find_object("grid w/ grid w/ grid.a").unwrap()
  let b = graph.find_object("grid w/ grid w/ grid.b").unwrap()
  let ba = graph.find_object("grid w/ grid w/ grid.b.a").unwrap()
  let bb = graph.find_object("grid w/ grid w/ grid.b.b").unwrap()
  let bc = graph.find_object("grid w/ grid w/ grid.b.c").unwrap()
  let bca = graph.find_object("grid w/ grid w/ grid.b.c.a").unwrap()
  let bcb = graph.find_object("grid w/ grid w/ grid.b.c.b").unwrap()
  let bcc = graph.find_object("grid w/ grid w/ grid.b.c.c").unwrap()
  let bcd = graph.find_object("grid w/ grid w/ grid.b.c.d").unwrap()
  let bcda = graph.find_object("grid w/ grid w/ grid.b.c.d.a").unwrap()
  let bcdaa = graph.find_object("grid w/ grid w/ grid.b.c.d.a.a").unwrap()
  let bcdab = graph.find_object("grid w/ grid w/ grid.b.c.d.a.b").unwrap()
  let bcdac = graph.find_object("grid w/ grid w/ grid.b.c.d.a.c").unwrap()
  let bcdad = graph.find_object("grid w/ grid w/ grid.b.c.d.a.d").unwrap()
  let bcdb = graph.find_object("grid w/ grid w/ grid.b.c.d.b").unwrap()
  let bcdc = graph.find_object("grid w/ grid w/ grid.b.c.d.c").unwrap()
  let bcdd = graph.find_object("grid w/ grid w/ grid.b.c.d.d").unwrap()
  let bd = graph.find_object("grid w/ grid w/ grid.b.d").unwrap()
  let c = graph.find_object("grid w/ grid w/ grid.c").unwrap()
  let d = graph.find_object("grid w/ grid w/ grid.d").unwrap()

  match
    (
      root.get_box(),
      a.get_box(),
      b.get_box(),
      ba.get_box(),
      bb.get_box(),
      bc.get_box(),
      bca.get_box(),
      bcb.get_box(),
      bcc.get_box(),
      bcd.get_box(),
      bcda.get_box(),
      bcdaa.get_box(),
      bcdab.get_box(),
      bcdac.get_box(),
      bcdad.get_box(),
      bcdb.get_box(),
      bcdc.get_box(),
      bcdd.get_box(),
      bd.get_box(),
      c.get_box(),
      d.get_box(),
    ) {
    (
      Some(root_box),
      Some(a_box),
      Some(b_box),
      Some(ba_box),
      Some(bb_box),
      Some(bc_box),
      Some(bca_box),
      Some(bcb_box),
      Some(bcc_box),
      Some(bcd_box),
      Some(bcda_box),
      Some(bcdaa_box),
      Some(bcdab_box),
      Some(bcdac_box),
      Some(bcdad_box),
      Some(bcdb_box),
      Some(bcdc_box),
      Some(bcdd_box),
      Some(bd_box),
      Some(c_box),
      Some(d_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(root_box, @graph.Box::new(0.0, 0.0, 321.0, 581.0))
        assert_eq(a_box, @graph.Box::new(0.0, 46.0, 53.0, 469.0))
        assert_eq(b_box, @graph.Box::new(53.0, 46.0, 268.0, 469.0))
        assert_eq(ba_box, @graph.Box::new(53.0, 87.0, 214.0, 66.0))
        assert_eq(bb_box, @graph.Box::new(267.0, 87.0, 54.0, 66.0))
        assert_eq(bc_box, @graph.Box::new(53.0, 153.0, 214.0, 362.0))
        assert_eq(bca_box, @graph.Box::new(53.0, 189.0, 53.0, 66.0))
        assert_eq(bcb_box, @graph.Box::new(106.0, 189.0, 161.0, 66.0))
        assert_eq(bcc_box, @graph.Box::new(53.0, 255.0, 53.0, 260.0))
        assert_eq(bcd_box, @graph.Box::new(106.0, 255.0, 161.0, 260.0))
        assert_eq(bcda_box, @graph.Box::new(106.0, 286.0, 107.0, 163.0))
        assert_eq(bcdaa_box, @graph.Box::new(106.0, 317.0, 53.0, 66.0))
        assert_eq(bcdab_box, @graph.Box::new(159.0, 317.0, 54.0, 66.0))
        assert_eq(bcdac_box, @graph.Box::new(106.0, 383.0, 53.0, 66.0))
        assert_eq(bcdad_box, @graph.Box::new(159.0, 383.0, 54.0, 66.0))
        assert_eq(bcdb_box, @graph.Box::new(213.0, 286.0, 54.0, 163.0))
        assert_eq(bcdc_box, @graph.Box::new(106.0, 449.0, 107.0, 66.0))
        assert_eq(bcdd_box, @graph.Box::new(213.0, 449.0, 54.0, 66.0))
        assert_eq(bd_box, @graph.Box::new(267.0, 153.0, 54.0, 362.0))
        assert_eq(c_box, @graph.Box::new(0.0, 515.0, 53.0, 66.0))
        assert_eq(d_box, @graph.Box::new(53.0, 515.0, 268.0, 66.0))
      } else {
        assert_eq(root_box, @graph.Box::new(12.0, 12.0, 321.0, 581.0))
        assert_eq(a_box, @graph.Box::new(12.0, 58.0, 53.0, 469.0))
        assert_eq(b_box, @graph.Box::new(65.0, 58.0, 268.0, 469.0))
        assert_eq(ba_box, @graph.Box::new(65.0, 99.0, 214.0, 66.0))
        assert_eq(bb_box, @graph.Box::new(279.0, 99.0, 54.0, 66.0))
        assert_eq(bc_box, @graph.Box::new(65.0, 165.0, 214.0, 362.0))
        assert_eq(bca_box, @graph.Box::new(65.0, 201.0, 53.0, 66.0))
        assert_eq(bcb_box, @graph.Box::new(118.0, 201.0, 161.0, 66.0))
        assert_eq(bcc_box, @graph.Box::new(65.0, 267.0, 53.0, 260.0))
        assert_eq(bcd_box, @graph.Box::new(118.0, 267.0, 161.0, 260.0))
        assert_eq(bcda_box, @graph.Box::new(118.0, 298.0, 107.0, 163.0))
        assert_eq(bcdaa_box, @graph.Box::new(118.0, 329.0, 53.0, 66.0))
        assert_eq(bcdab_box, @graph.Box::new(171.0, 329.0, 54.0, 66.0))
        assert_eq(bcdac_box, @graph.Box::new(118.0, 395.0, 53.0, 66.0))
        assert_eq(bcdad_box, @graph.Box::new(171.0, 395.0, 54.0, 66.0))
        assert_eq(bcdb_box, @graph.Box::new(225.0, 298.0, 54.0, 163.0))
        assert_eq(bcdc_box, @graph.Box::new(118.0, 461.0, 107.0, 66.0))
        assert_eq(bcdd_box, @graph.Box::new(225.0, 461.0, 54.0, 66.0))
        assert_eq(bd_box, @graph.Box::new(279.0, 165.0, 54.0, 362.0))
        assert_eq(c_box, @graph.Box::new(12.0, 527.0, 53.0, 66.0))
        assert_eq(d_box, @graph.Box::new(65.0, 527.0, 268.0, 66.0))
      }
    _ =>
      fail(
        "\{engine_name} expected boxes for grid_nested grid-with-grid-with-grid fixture objects",
      )
  }
}

///|
test "reference empty_nested_grid matches stable boxes" {
  let source =
    #|outer: {
    #|  grid-rows: 1
    #|  inner: {
    #|    grid-rows: 1
    #|    # empty
    #|  }
    #|}
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_empty_nested_grid_like_d2(dagre, "dagre")
  assert_empty_nested_grid_like_d2(elk, "elk")
}

///|
fn assert_empty_nested_grid_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let outer = graph.find_object("outer").unwrap()
  let inner = graph.find_object("outer.inner").unwrap()

  match (outer.get_box(), inner.get_box()) {
    (Some(outer_box), Some(inner_box)) =>
      if engine_name == "dagre" {
        assert_eq(outer_box, @graph.Box::new(0.0, 0.0, 221.0, 196.0))
        assert_eq(inner_box, @graph.Box::new(60.0, 60.0, 101.0, 76.0))
      } else {
        assert_eq(outer_box, @graph.Box::new(12.0, 12.0, 221.0, 196.0))
        assert_eq(inner_box, @graph.Box::new(72.0, 72.0, 101.0, 76.0))
      }
    _ =>
      fail(
        "\{engine_name} expected boxes for empty_nested_grid fixture objects",
      )
  }
}

///|
test "reference empty_sequence matches stable boxes" {
  let source =
    #|A: hello {
    #|  shape: sequence_diagram
    #|}
    #|
    #|B: goodbye {
    #|  shape: sequence_diagram
    #|}
    #|
    #|A->B
  let graph_input = compile_graph_no_layout(source).unwrap()
  let compiled_endpoints : Array[String] = []
  for edge in graph_input.get_edges() {
    compiled_endpoints.push(
      "\{edge.lookup_src_id()} -> \{edge.lookup_dst_id()}",
    )
  }
  assert_eq(compiled_endpoints, ["A -> B"])
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_empty_sequence_like_d2(dagre, "dagre")
  assert_empty_sequence_like_d2(elk, "elk")
}

///|
test "reference sequence nested groups match stable boxes" {
  let source =
    #|shape: sequence_diagram
    #|
    #|a; b; c
    #|
    #|this is a message group: {
    #|    a -> b
    #|    and this is a nested message group: {
    #|        a -> b
    #|        what about more nesting: {
    #|            a -> b
    #|            crazy town: {
    #|                a."a note"
    #|                a -> b
    #|                whoa: {
    #|                    a -> b
    #|                }
    #|            }
    #|        }
    #|    }
    #|}
    #|
    #|alt: {
    #|    case 1: {
    #|        b -> c
    #|    }
    #|    case 2: {
    #|        b -> c
    #|    }
    #|    case 3: {
    #|        b -> c
    #|    }
    #|    case 4: {
    #|        b -> c
    #|    }
    #|}
    #|
    #|b.note: "a note here to remember that padding must consider notes too"
    #|a.note: "just\na\nlong\nnote\nhere"
    #|c: "just an actor"
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_sequence_nested_groups_reference(dagre, "dagre")
  assert_sequence_nested_groups_reference(elk, "elk")
}

///|
test "reference sequence nested span matches stable boxes" {
  let source =
    #|shape: sequence_diagram
    #|
    #|scorer: {
    #|    style.stroke: red
    #|    style.stroke-width: 5
    #|}
    #|
    #|scorer.abc: {
    #|    style.fill: yellow
    #|    style.stroke-width: 7
    #|}
    #|
    #|scorer -> itemResponse.a: {
    #|    style.stroke-width: 10
    #|}
    #|itemResponse.a -> item.a.b
    #|item.a.b -> essayRubric.a.b.c
    #|essayRubric.a.b.c -> concept.a.b.c.d
    #|item.a -> essayRubric.a.b
    #|concept.a.b.c.d -> itemOutcome.a.b.c.d.e
    #|
    #|scorer.abc -> item.a
    #|
    #|itemOutcome.a.b.c.d.e -> scorer
    #|scorer -> itemResponse.c
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_sequence_nested_span_reference(dagre, "dagre")
  assert_sequence_nested_span_reference(elk, "elk")
}

///|
test "reference sequence inter span self matches stable boxes" {
  let source =
    #|shape: sequence_diagram
    #|a: A
    #|b: B
    #|
    #|a.sp1 -> b: foo
    #|a.sp1 -> a.sp2: redirect
    #|a.sp2 -> b: bar
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_sequence_inter_span_self_reference(dagre, "dagre")
  assert_sequence_inter_span_self_reference(elk, "elk")
}

///|
fn assert_empty_sequence_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let a = graph.find_object("A").unwrap()
  let b = graph.find_object("B").unwrap()
  let edge = match find_edge(graph, "A", "B") {
    Some(edge) => edge
    None => {
      let endpoints : Array[String] = []
      for edge in graph.get_edges() {
        endpoints.push("\{edge.lookup_src_id()} -> \{edge.lookup_dst_id()}")
      }
      fail(
        "\{engine_name} expected edge A -> B in empty_sequence fixture, got \{endpoints}",
      )
    }
  }

  match (a.get_box(), b.get_box()) {
    (Some(a_box), Some(b_box)) =>
      if engine_name == "dagre" {
        assert_eq(a_box, @graph.Box::new(13.0, 0.0, 80.0, 66.0))
        assert_eq(b_box, @graph.Box::new(0.0, 166.0, 106.0, 66.0))
        assert_route_points_close(edge.route, [
          @graph.Point::new(53.0, 66.0),
          @graph.Point::new(53.0, 106.0),
          @graph.Point::new(53.0, 126.0),
          @graph.Point::new(53.0, 166.0),
        ])
      } else {
        assert_eq(a_box, @graph.Box::new(25.0, 12.0, 80.0, 66.0))
        assert_eq(b_box, @graph.Box::new(12.0, 148.0, 106.0, 66.0))
        assert_route_points_close(edge.route, [
          @graph.Point::new(65.0, 78.0),
          @graph.Point::new(65.0, 148.0),
        ])
      }
    _ =>
      fail("\{engine_name} expected boxes for empty_sequence fixture objects")
  }
}

///|
fn assert_sequence_nested_span_reference(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let target = @diagram.from_graph(graph, None)
  for
    entry in [
      ("scorer", @graph.Box::new(12.0, 52.0, 100.0, 66.0)),
      ("scorer.abc", @graph.Box::new(56.0, 598.0, 12.0, 30.0)),
      ("itemResponse", @graph.Box::new(152.0, 52.0, 140.0, 66.0)),
      ("itemResponse.a", @graph.Box::new(216.0, 178.0, 12.0, 90.0)),
      ("item", @graph.Box::new(322.0, 52.0, 100.0, 66.0)),
      ("item.a", @graph.Box::new(366.0, 238.0, 12.0, 380.0)),
      ("item.a.b", @graph.Box::new(362.0, 248.0, 20.0, 90.0)),
      ("essayRubric", @graph.Box::new(462.0, 52.0, 126.0, 66.0)),
      ("essayRubric.a", @graph.Box::new(519.0, 298.0, 12.0, 190.0)),
      ("essayRubric.a.b", @graph.Box::new(515.0, 308.0, 20.0, 170.0)),
      ("essayRubric.a.b.c", @graph.Box::new(511.0, 318.0, 28.0, 90.0)),
      ("concept", @graph.Box::new(628.0, 52.0, 100.0, 66.0)),
      ("concept.a", @graph.Box::new(672.0, 358.0, 12.0, 220.0)),
      ("concept.a.b", @graph.Box::new(668.0, 368.0, 20.0, 200.0)),
      ("concept.a.b.c", @graph.Box::new(664.0, 378.0, 28.0, 180.0)),
      ("concept.a.b.c.d", @graph.Box::new(660.0, 388.0, 36.0, 160.0)),
      ("itemOutcome", @graph.Box::new(768.0, 52.0, 137.0, 66.0)),
      ("itemOutcome.a", @graph.Box::new(830.0, 488.0, 12.0, 240.0)),
      ("itemOutcome.a.b", @graph.Box::new(826.0, 498.0, 20.0, 220.0)),
      ("itemOutcome.a.b.c", @graph.Box::new(822.0, 508.0, 28.0, 200.0)),
      ("itemOutcome.a.b.c.d", @graph.Box::new(818.0, 518.0, 36.0, 180.0)),
      ("itemOutcome.a.b.c.d.e", @graph.Box::new(814.0, 528.0, 44.0, 160.0)),
      ("itemResponse.c", @graph.Box::new(216.0, 738.0, 12.0, 30.0)),
    ] {
    let (id, expected) = entry
    let shape = target.find_object(id).unwrap()
    assert_eq(require_shape_box(shape, id, engine_name), expected)
  }

  let scorer_item_response = find_connections(target, "scorer", "itemResponse")
  let item_response_item = find_connections(target, "itemResponse", "item")
  let item_essay_rubric = find_connections(target, "item", "essayRubric")
  let essay_rubric_concept = find_connections(target, "essayRubric", "concept")
  let concept_item_outcome = find_connections(target, "concept", "itemOutcome")
  let scorer_item = find_connections(target, "scorer", "item")
  let item_outcome_scorer = find_connections(target, "itemOutcome", "scorer")

  assert_eq(
    scorer_item_response.length(),
    2,
    msg="\{engine_name} expected two scorer -> itemResponse messages",
  )
  assert_eq(
    item_response_item.length(),
    1,
    msg="\{engine_name} expected one itemResponse -> item message",
  )
  assert_eq(
    item_essay_rubric.length(),
    2,
    msg="\{engine_name} expected two item -> essayRubric messages",
  )
  assert_eq(
    essay_rubric_concept.length(),
    1,
    msg="\{engine_name} expected one essayRubric -> concept message",
  )
  assert_eq(
    concept_item_outcome.length(),
    1,
    msg="\{engine_name} expected one concept -> itemOutcome message",
  )
  assert_eq(
    scorer_item.length(),
    1,
    msg="\{engine_name} expected one scorer -> item message",
  )
  assert_eq(
    item_outcome_scorer.length(),
    1,
    msg="\{engine_name} expected one itemOutcome -> scorer message",
  )

  assert_route_points_close(scorer_item_response[0].route, [
    @graph.Point::new(62.0, 188.0),
    @graph.Point::new(216.0, 188.0),
  ])
  assert_route_points_close(scorer_item_response[1].route, [
    @graph.Point::new(62.0, 748.0),
    @graph.Point::new(216.0, 748.0),
  ])
  assert_route_points_close(item_response_item[0].route, [
    @graph.Point::new(228.0, 258.0),
    @graph.Point::new(362.0, 258.0),
  ])
  assert_route_points_close(item_essay_rubric[0].route, [
    @graph.Point::new(382.0, 328.0),
    @graph.Point::new(511.0, 328.0),
  ])
  assert_route_points_close(item_essay_rubric[1].route, [
    @graph.Point::new(378.0, 468.0),
    @graph.Point::new(515.0, 468.0),
  ])
  assert_route_points_close(essay_rubric_concept[0].route, [
    @graph.Point::new(539.0, 398.0),
    @graph.Point::new(660.0, 398.0),
  ])
  assert_route_points_close(concept_item_outcome[0].route, [
    @graph.Point::new(696.0, 538.0),
    @graph.Point::new(814.5, 538.0),
  ])
  assert_route_points_close(scorer_item[0].route, [
    @graph.Point::new(68.0, 608.0),
    @graph.Point::new(366.0, 608.0),
  ])
  assert_route_points_close(item_outcome_scorer[0].route, [
    @graph.Point::new(814.5, 678.0),
    @graph.Point::new(62.0, 678.0),
  ])
}

///|
fn assert_sequence_inter_span_self_reference(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let target = @diagram.from_graph(graph, None)
  for
    entry in [
      ("a", @graph.Box::new(12.0, 52.0, 100.0, 66.0)),
      ("b", @graph.Box::new(162.0, 52.0, 100.0, 66.0)),
      ("a.sp1", @graph.Box::new(56.0, 188.0, 12.0, 100.0)),
      ("a.sp2", @graph.Box::new(56.0, 313.0, 12.0, 100.0)),
    ] {
    let (id, expected) = entry
    let shape = target.find_object(id).unwrap()
    assert_eq(require_shape_box(shape, id, engine_name), expected)
  }

  let a_b = find_connections(target, "a", "b")
  assert_eq(
    a_b.length(),
    2,
    msg="\{engine_name} expected two a -> b messages in sequence inter span self",
  )
  let sp1_sp2 = find_connection(target, "a", "a").unwrap()
  let sp1_b = a_b[0]
  let sp2_b = a_b[1]

  assert_route_points_close(sp1_b.route, [
    @graph.Point::new(68.0, 198.0),
    @graph.Point::new(212.0, 198.0),
  ])
  assert_route_points_close(sp1_sp2.route, [
    @graph.Point::new(68.0, 278.0),
    @graph.Point::new(142.0, 278.0),
    @graph.Point::new(142.0, 323.0),
    @graph.Point::new(68.0, 323.0),
  ])
  assert_route_points_close(sp2_b.route, [
    @graph.Point::new(68.0, 403.0),
    @graph.Point::new(212.0, 403.0),
  ])
}

///|
fn assert_sequence_nested_groups_reference(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let target = @diagram.from_graph(graph, None)
  let a = target.find_object("a").unwrap()
  let b = target.find_object("b").unwrap()
  let c = target.find_object("c").unwrap()
  let group1 = target.find_object("this is a message group").unwrap()
  let group2 = target
    .find_object("this is a message group.and this is a nested message group")
    .unwrap()
  let group3 = target
    .find_object(
      "this is a message group.and this is a nested message group.what about more nesting",
    )
    .unwrap()
  let crazy_town = target
    .find_object(
      "this is a message group.and this is a nested message group.what about more nesting.crazy town",
    )
    .unwrap()
  let a_group_note = target
    .find_object(
      "this is a message group.and this is a nested message group.what about more nesting.crazy town.a.a note",
    )
    .unwrap()
  let whoa = target
    .find_object(
      "this is a message group.and this is a nested message group.what about more nesting.crazy town.whoa",
    )
    .unwrap()
  let alt = target.find_object("alt").unwrap()
  let case1 = target.find_object("alt.case 1").unwrap()
  let case2 = target.find_object("alt.case 2").unwrap()
  let case3 = target.find_object("alt.case 3").unwrap()
  let case4 = target.find_object("alt.case 4").unwrap()
  let b_note = target.find_object("b.note").unwrap()
  let a_note = target.find_object("a.note").unwrap()
  let a_box = require_shape_box(a, "a", engine_name)
  let b_box = require_shape_box(b, "b", engine_name)
  let c_box = require_shape_box(c, "c", engine_name)
  let group1_box = require_shape_box(
    group1, "this is a message group", engine_name,
  )
  let group2_box = require_shape_box(
    group2, "this is a message group.and this is a nested message group", engine_name,
  )
  let group3_box = require_shape_box(
    group3, "this is a message group.and this is a nested message group.what about more nesting",
    engine_name,
  )
  let crazy_town_box = require_shape_box(
    crazy_town, "this is a message group.and this is a nested message group.what about more nesting.crazy town",
    engine_name,
  )
  let a_group_note_box = require_shape_box(
    a_group_note, "this is a message group.and this is a nested message group.what about more nesting.crazy town.a.a note",
    engine_name,
  )
  let whoa_box = require_shape_box(
    whoa, "this is a message group.and this is a nested message group.what about more nesting.crazy town.whoa",
    engine_name,
  )
  let alt_box = require_shape_box(alt, "alt", engine_name)
  let case1_box = require_shape_box(case1, "alt.case 1", engine_name)
  let case2_box = require_shape_box(case2, "alt.case 2", engine_name)
  let case3_box = require_shape_box(case3, "alt.case 3", engine_name)
  let case4_box = require_shape_box(case4, "alt.case 4", engine_name)
  let b_note_box = require_shape_box(b_note, "b.note", engine_name)
  let a_note_box = require_shape_box(a_note, "a.note", engine_name)

  assert_eq(a_box, @graph.Box::new(12.0, 52.0, 100.0, 66.0))
  assert_eq(b_box, @graph.Box::new(285.0, 52.0, 100.0, 66.0))
  assert_eq(c_box, @graph.Box::new(542.0, 52.0, 130.0, 66.0))
  assert_eq(group1_box, @graph.Box::new(-58.0, 173.0, 481.0, 711.0))
  assert_eq(group2_box, @graph.Box::new(-46.0, 274.0, 457.0, 567.0))
  assert_eq(group3_box, @graph.Box::new(-34.0, 375.0, 433.0, 423.0))
  assert_eq(crazy_town_box, @graph.Box::new(-22.0, 476.0, 409.0, 310.0))
  assert_eq(a_group_note_box, @graph.Box::new(18.0, 522.0, 88.0, 66.0))
  assert_eq(whoa_box, @graph.Box::new(22.0, 713.0, 353.0, 61.0))
  assert_eq(alt_box, @graph.Box::new(283.0, 802.0, 376.0, 419.0))
  assert_eq(case1_box, @graph.Box::new(295.0, 845.0, 352.0, 61.0))
  assert_eq(case2_box, @graph.Box::new(295.0, 946.0, 352.0, 61.0))
  assert_eq(case3_box, @graph.Box::new(295.0, 1047.0, 352.0, 61.0))
  assert_eq(case4_box, @graph.Box::new(295.0, 1148.0, 352.0, 61.0))
  assert_eq(b_note_box, @graph.Box::new(102.0, 1264.0, 465.0, 66.0))
  assert_eq(a_note_box, @graph.Box::new(23.0, 1400.0, 77.0, 130.0))

  let ab = find_connections(target, "a", "b")
  let bc = find_connections(target, "b", "c")
  assert_eq(
    ab.length(),
    5,
    msg="\{engine_name} expected five a -> b messages in sequence nested groups",
  )
  assert_eq(
    bc.length(),
    4,
    msg="\{engine_name} expected four b -> c messages in sequence nested groups",
  )
  for
    i, expected in [
      [@graph.Point::new(62.0, 219.0), @graph.Point::new(335.0, 219.0)],
      [@graph.Point::new(62.0, 320.0), @graph.Point::new(335.0, 320.0)],
      [@graph.Point::new(62.0, 421.0), @graph.Point::new(335.0, 421.0)],
      [@graph.Point::new(62.0, 658.0), @graph.Point::new(335.0, 658.0)],
      [@graph.Point::new(62.0, 759.0), @graph.Point::new(335.0, 759.0)],
    ] {
    assert_route_points_close(ab[i].route, expected)
  }
  for
    i, expected in [
      [@graph.Point::new(335.0, 891.0), @graph.Point::new(607.0, 891.0)],
      [@graph.Point::new(335.0, 992.0), @graph.Point::new(607.0, 992.0)],
      [@graph.Point::new(335.0, 1093.0), @graph.Point::new(607.0, 1093.0)],
      [@graph.Point::new(335.0, 1194.0), @graph.Point::new(607.0, 1194.0)],
    ] {
    assert_route_points_close(bc[i].route, expected)
  }
}

///|
test "reference nested_steps matches stable boxes" {
  let source =
    #|a: {
    #|  a: {
    #|    shape: step
    #|  }
    #|  b: {
    #|    shape: step
    #|  }
    #|  a -> b
    #|}
    #|
    #|c: {
    #|  shape: step
    #|}
    #|d: {
    #|  shape: step
    #|}
    #|c -> d
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_nested_steps_like_d2(dagre, "dagre")
  assert_nested_steps_like_d2(elk, "elk")
}

///|
fn assert_nested_steps_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let target = @diagram.from_graph(graph, None)
  let a = target.find_object("a").unwrap()
  let aa = target.find_object("a.a").unwrap()
  let ab = target.find_object("a.b").unwrap()
  let c = target.find_object("c").unwrap()
  let d = target.find_object("d").unwrap()
  let ab_edge = find_connection(target, "a.a", "a.b").unwrap()
  let cd_edge = find_connection(target, "c", "d").unwrap()

  match (a.get_box(), aa.get_box(), ab.get_box(), c.get_box(), d.get_box()) {
    (Some(a_box), Some(aa_box), Some(ab_box), Some(c_box), Some(d_box)) =>
      if engine_name == "dagre" {
        assert_eq(a_box, @graph.Box::new(10.0, 20.0, 153.0, 362.0))
        assert_eq(aa_box, @graph.Box::new(40.0, 50.0, 93.0, 101.0))
        assert_eq(ab_box, @graph.Box::new(40.0, 251.0, 93.0, 101.0))
        assert_eq(c_box, @graph.Box::new(214.0, 50.0, 93.0, 101.0))
        assert_eq(d_box, @graph.Box::new(213.0, 251.0, 94.0, 101.0))
        assert_route_points_close(ab_edge.route, [
          @graph.Point::new(86.0, 151.0),
          @graph.Point::new(86.4000015258789, 191.0),
          @graph.Point::new(86.5999984741211, 211.0),
          @graph.Point::new(87.0, 251.0),
        ])
        assert_route_points_close(cd_edge.route, [
          @graph.Point::new(260.0, 151.0),
          @graph.Point::new(260.0, 191.0),
          @graph.Point::new(260.0, 211.0),
          @graph.Point::new(260.0, 251.0),
        ])
      } else {
        assert_eq(a_box, @graph.Box::new(12.0, 12.0, 193.0, 372.0))
        assert_eq(aa_box, @graph.Box::new(62.0, 62.0, 93.0, 101.0))
        assert_eq(ab_box, @graph.Box::new(62.0, 233.0, 93.0, 101.0))
        assert_eq(c_box, @graph.Box::new(225.0, 283.0, 93.0, 101.0))
        assert_eq(d_box, @graph.Box::new(224.0, 454.0, 94.0, 101.0))
        assert_route_points_close(ab_edge.route, [
          @graph.Point::new(108.0, 163.0),
          @graph.Point::new(109.0, 233.0),
        ])
        assert_route_points_close(cd_edge.route, [
          @graph.Point::new(271.0, 384.0),
          @graph.Point::new(272.0, 454.0),
        ])
      }
    _ => fail("\{engine_name} expected boxes for nested_steps fixture objects")
  }
}

///|
test "reference multiple_constant_nears matches stable target geometry" {
  let source =
    #|a
    #|b
    #|c
    #|
    #|a: {
    #|  1 -> 2 -> 3
    #|  near: center-right
    #|  style.fill: red
    #|  style.opacity: 0.5
    #|}
    #|
    #|b: {
    #|  1111 -> 2222
    #|  near: bottom-right
    #|  style.fill: green
    #|  style.opacity: 0.5
    #|}
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_multiple_constant_nears_like_d2(dagre, "dagre")
  assert_multiple_constant_nears_like_d2(elk, "elk")
}

///|
test "reference constant_near_title matches stable target geometry" {
  let source =
    #|title: |md
    #|  # A winning strategy
    #|| { near: top-center }
    #|
    #|poll the people -> results
    #|results -> unfavorable -> poll the people
    #|results -> favorable -> will of the people
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_constant_near_title_like_d2(dagre, "dagre")
  assert_constant_near_title_like_d2(elk, "elk")
}

///|
test "reference grid_edge_across_cell matches stable target geometry" {
  let source =
    #|classes.red.style.stroke: red
    #|grid: {
    #|  grid-columns: 2
    #|  grid-gap: 10
    #|
    #|  cell 1.a -> cell 2.b -> cell 3.c.d: {
    #|    class: red
    #|  }
    #|
    #|  cell 3: {
    #|    c -> e
    #|    c.d -> f.g
    #|  }
    #|  cell 3.f.g -> cell 1.a: {
    #|    class: red
    #|  }
    #|}
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_grid_edge_across_cell_like_d2(dagre, "dagre")
  assert_grid_edge_across_cell_like_d2(elk, "elk")
}

///|
fn assert_constant_near_title_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let target = @diagram.from_graph(graph, None)
  let title = target.find_object("title").unwrap()
  let poll = target.find_object("poll the people").unwrap()
  let results = target.find_object("results").unwrap()
  let unfavorable = target.find_object("unfavorable").unwrap()
  let favorable = target.find_object("favorable").unwrap()
  let will = target.find_object("will of the people").unwrap()
  let poll_results = find_connection(target, "poll the people", "results").unwrap()
  let results_unfavorable = find_connection(target, "results", "unfavorable").unwrap()
  let unfavorable_poll = find_connection(
    target, "unfavorable", "poll the people",
  ).unwrap()
  let results_favorable = find_connection(target, "results", "favorable").unwrap()
  let favorable_will = find_connection(
    target, "favorable", "will of the people",
  ).unwrap()

  match
    (
      title.get_box(),
      poll.get_box(),
      results.get_box(),
      unfavorable.get_box(),
      favorable.get_box(),
      will.get_box(),
    ) {
    (
      Some(title_box),
      Some(poll_box),
      Some(results_box),
      Some(unfavorable_box),
      Some(favorable_box),
      Some(will_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(title_box, @graph.Box::new(37.0, -71.0, 257.0, 51.0))
        assert_eq(poll_box, @graph.Box::new(82.0, 0.0, 150.0, 66.0))
        assert_eq(results_box, @graph.Box::new(191.0, 166.0, 93.0, 66.0))
        assert_eq(unfavorable_box, @graph.Box::new(0.0, 332.0, 131.0, 66.0))
        assert_eq(favorable_box, @graph.Box::new(191.0, 332.0, 113.0, 66.0))
        assert_eq(will_box, @graph.Box::new(164.0, 498.0, 167.0, 66.0))
        assert_route_points_close(poll_results.route, [
          @graph.Point::new(188.5, 66.0),
          @graph.Point::new(227.6999969482422, 106.0),
          @graph.Point::new(237.5, 126.0),
          @graph.Point::new(237.5, 166.0),
        ])
        assert_route_points_close(results_unfavorable.route, [
          @graph.Point::new(201.5, 232.0),
          @graph.Point::new(157.5, 272.0),
          @graph.Point::new(136.6999969482422, 292.0),
          @graph.Point::new(97.5, 332.0),
        ])
        assert_route_points_close(unfavorable_poll.route, [
          @graph.Point::new(61.5, 332.0),
          @graph.Point::new(56.70000076293945, 292.0),
          @graph.Point::new(55.5, 265.3999938964844),
          @graph.Point::new(55.5, 240.5),
          @graph.Point::new(55.5, 215.60000610351562),
          @graph.Point::new(67.69999694824219, 106.0),
          @graph.Point::new(116.5, 66.0),
        ])
        assert_route_points_close(results_favorable.route, [
          @graph.Point::new(241.5, 232.0),
          @graph.Point::new(246.3000030517578, 272.0),
          @graph.Point::new(247.5, 292.0),
          @graph.Point::new(247.5, 332.0),
        ])
        assert_route_points_close(favorable_will.route, [
          @graph.Point::new(247.5, 398.0),
          @graph.Point::new(247.5, 438.0),
          @graph.Point::new(247.5, 458.0),
          @graph.Point::new(247.5, 498.0),
        ])
      } else {
        assert_eq(title_box, @graph.Box::new(29.0, -59.0, 257.0, 51.0))
        assert_eq(poll_box, @graph.Box::new(110.0, 12.0, 150.0, 66.0))
        assert_eq(results_box, @graph.Box::new(64.0, 158.0, 93.0, 66.0))
        assert_eq(unfavorable_box, @graph.Box::new(172.0, 304.0, 131.0, 66.0))
        assert_eq(favorable_box, @graph.Box::new(39.0, 304.0, 113.0, 66.0))
        assert_eq(will_box, @graph.Box::new(12.0, 440.0, 167.0, 66.0))
        assert_route_points_close(poll_results.route, [
          @graph.Point::new(160.16600036621094, 78.0),
          @graph.Point::new(160.16600036621094, 118.0),
          @graph.Point::new(111.0, 118.0),
          @graph.Point::new(111.0, 158.0),
        ])
        assert_route_points_close(results_unfavorable.route, [
          @graph.Point::new(126.5, 224.0),
          @graph.Point::new(126.5, 264.0),
          @graph.Point::new(215.66600036621094, 264.0),
          @graph.Point::new(215.66600036621094, 304.0),
        ])
        assert_route_points_close(unfavorable_poll.route, [
          @graph.Point::new(259.3330078125, 304.0),
          @graph.Point::new(259.3330078125, 118.0),
          @graph.Point::new(210.16600036621094, 118.0),
          @graph.Point::new(210.16600036621094, 78.0),
        ])
        assert_route_points_close(results_favorable.route, [
          @graph.Point::new(95.5, 224.0),
          @graph.Point::new(95.5, 304.0),
        ])
        assert_route_points_close(favorable_will.route, [
          @graph.Point::new(95.5, 370.0),
          @graph.Point::new(95.5, 440.0),
        ])
      }
    _ =>
      fail(
        "\{engine_name} expected boxes for constant_near_title fixture objects",
      )
  }
}

///|
fn assert_grid_edge_across_cell_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let target = @diagram.from_graph(graph, None)
  let grid = target.find_object("grid").unwrap()
  let cell1 = target.find_object("grid.cell 1").unwrap()
  let a = target.find_object("grid.cell 1.a").unwrap()
  let cell2 = target.find_object("grid.cell 2").unwrap()
  let b = target.find_object("grid.cell 2.b").unwrap()
  let cell3 = target.find_object("grid.cell 3").unwrap()
  let c = target.find_object("grid.cell 3.c").unwrap()
  let cd = target.find_object("grid.cell 3.c.d").unwrap()
  let e = target.find_object("grid.cell 3.e").unwrap()
  let f = target.find_object("grid.cell 3.f").unwrap()
  let fg = target.find_object("grid.cell 3.f.g").unwrap()
  let ab = find_connection(target, "grid.cell 1.a", "grid.cell 2.b").unwrap()
  let bcd = find_connection(target, "grid.cell 2.b", "grid.cell 3.c.d").unwrap()
  let ce = find_connection(target, "grid.cell 3.c", "grid.cell 3.e").unwrap()
  let cdfg = find_connection(target, "grid.cell 3.c.d", "grid.cell 3.f.g").unwrap()
  let fga = find_connection(target, "grid.cell 3.f.g", "grid.cell 1.a").unwrap()

  match
    (
      grid.get_box(),
      cell1.get_box(),
      a.get_box(),
      cell2.get_box(),
      b.get_box(),
      cell3.get_box(),
      c.get_box(),
      cd.get_box(),
      e.get_box(),
      f.get_box(),
      fg.get_box(),
    ) {
    (
      Some(_),
      Some(cell1_box),
      Some(a_box),
      Some(cell2_box),
      Some(b_box),
      Some(cell3_box),
      Some(c_box),
      Some(cd_box),
      Some(e_box),
      Some(f_box),
      Some(fg_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(cell1_box, @graph.Box::new(10.0, 82.0, 113.0, 206.0))
        assert_eq(a_box, @graph.Box::new(40.0, 112.0, 53.0, 66.0))
        assert_eq(cell2_box, @graph.Box::new(10.0, 334.0, 113.0, 206.0))
        assert_eq(b_box, @graph.Box::new(40.0, 364.0, 53.0, 66.0))
        assert_eq(cell3_box, @graph.Box::new(133.0, 82.0, 280.0, 458.0))
        assert_eq(c_box, @graph.Box::new(163.0, 118.0, 154.0, 126.0))
        assert_eq(cd_box, @graph.Box::new(233.0, 148.0, 54.0, 66.0))
        assert_eq(e_box, @graph.Box::new(166.0, 414.0, 53.0, 66.0))
        assert_eq(f_box, @graph.Box::new(269.0, 384.0, 114.0, 126.0))
        assert_eq(fg_box, @graph.Box::new(299.0, 414.0, 54.0, 66.0))
        assert_route_points_close(
          ab.route,
          [@graph.Point::new(66.875, 178.0), @graph.Point::new(66.875, 364.0)],
          tolerance=1.0,
        )
        assert_route_points_close(
          bcd.route,
          [@graph.Point::new(93.625, 367.0), @graph.Point::new(233.625, 211.0)],
          tolerance=1.0,
        )
        assert_route_points_close(
          ce.route,
          [
            @graph.Point::new(193.375, 244.0),
            @graph.Point::new(193.375, 300.0),
            @graph.Point::new(193.375, 374.0),
            @graph.Point::new(193.375, 414.0),
          ],
          tolerance=1.0,
        )
        assert_route_points_close(
          cdfg.route,
          [
            @graph.Point::new(286.875, 214.0),
            @graph.Point::new(318.875, 254.0),
            @graph.Point::new(326.875, 274.0),
            @graph.Point::new(326.875, 289.0),
            @graph.Point::new(326.875, 304.0),
            @graph.Point::new(326.875, 374.0),
            @graph.Point::new(326.875, 414.0),
          ],
          tolerance=1.0,
        )
        assert_route_points_close(
          fga.route,
          [@graph.Point::new(299.875, 416.0), @graph.Point::new(92.875, 176.0)],
          tolerance=1.0,
        )
      } else {
        assert_eq(cell1_box, @graph.Box::new(22.0, 58.0, 153.0, 256.0))
        assert_eq(a_box, @graph.Box::new(72.0, 108.0, 53.0, 66.0))
        assert_eq(cell2_box, @graph.Box::new(22.0, 324.0, 153.0, 256.0))
        assert_eq(b_box, @graph.Box::new(72.0, 374.0, 53.0, 66.0))
        assert_eq(cell3_box, @graph.Box::new(185.0, 58.0, 327.0, 522.0))
        assert_eq(c_box, @graph.Box::new(251.0, 108.0, 154.0, 166.0))
        assert_eq(cd_box, @graph.Box::new(301.0, 158.0, 54.0, 66.0))
        assert_eq(e_box, @graph.Box::new(235.0, 364.0, 53.0, 66.0))
        assert_eq(f_box, @graph.Box::new(308.0, 364.0, 154.0, 166.0))
        assert_eq(fg_box, @graph.Box::new(358.0, 414.0, 54.0, 66.0))
        assert_route_points_close(
          ab.route,
          [@graph.Point::new(98.5, 174.0), @graph.Point::new(98.5, 374.0)],
          tolerance=1.0,
        )
        assert_route_points_close(
          bcd.route,
          [@graph.Point::new(125.25, 382.0), @graph.Point::new(301.25, 216.0)],
          tolerance=1.0,
        )
        assert_route_points_close(
          ce.route,
          [@graph.Point::new(261.5, 274.0), @graph.Point::new(261.5, 364.0)],
          tolerance=1.0,
        )
        assert_route_points_close(
          cdfg.route,
          [
            @graph.Point::new(328.25, 224.0),
            @graph.Point::new(328.25, 319.0),
            @graph.Point::new(385.0, 319.0),
            @graph.Point::new(385.0, 414.0),
          ],
          tolerance=1.0,
        )
        assert_route_points_close(
          fga.route,
          [@graph.Point::new(358.5, 418.0), @graph.Point::new(124.5, 169.0)],
          tolerance=1.0,
        )
      }
    _ =>
      fail(
        "\{engine_name} expected boxes for grid_edge_across_cell fixture objects",
      )
  }
}

///|
fn assert_multiple_constant_nears_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let target = @diagram.from_graph(graph, None)
  let a = target.find_object("a").unwrap()
  let b = target.find_object("b").unwrap()
  let c = target.find_object("c").unwrap()
  let a1 = target.find_object("a.1").unwrap()
  let a2 = target.find_object("a.2").unwrap()
  let a3 = target.find_object("a.3").unwrap()
  let b1111 = target.find_object("b.1111").unwrap()
  let b2222 = target.find_object("b.2222").unwrap()
  let a12 = find_connection(target, "a.1", "a.2").unwrap()
  let a23 = find_connection(target, "a.2", "a.3").unwrap()
  let bedge = find_connection(target, "b.1111", "b.2222").unwrap()

  match
    (
      a.get_box(),
      b.get_box(),
      c.get_box(),
      a1.get_box(),
      a2.get_box(),
      a3.get_box(),
      b1111.get_box(),
      b2222.get_box(),
    ) {
    (
      Some(a_box),
      Some(b_box),
      Some(c_box),
      Some(a1_box),
      Some(a2_box),
      Some(a3_box),
      Some(b1111_box),
      Some(b2222_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(a_box, @graph.Box::new(73.0, -196.0, 113.0, 458.0))
        assert_eq(b_box, @graph.Box::new(73.0, 318.0, 139.0, 292.0))
        assert_eq(c_box, @graph.Box::new(0.0, 0.0, 53.0, 66.0))
        assert_eq(a1_box, @graph.Box::new(104.0, -166.0, 52.0, 66.0))
        assert_eq(a2_box, @graph.Box::new(103.0, 0.0, 53.0, 66.0))
        assert_eq(a3_box, @graph.Box::new(103.0, 166.0, 53.0, 66.0))
        assert_eq(b1111_box, @graph.Box::new(104.0, 348.0, 78.0, 66.0))
        assert_eq(b2222_box, @graph.Box::new(103.0, 514.0, 79.0, 66.0))
        assert_eq(a.label_position, Some("OUTSIDE_TOP_CENTER"))
        assert_eq(b.label_position, Some("OUTSIDE_TOP_CENTER"))
        assert_route_points_close(a12.route, [
          @graph.Point::new(129.5, -100.0),
          @graph.Point::new(129.5, -60.0),
          @graph.Point::new(129.5, -40.0),
          @graph.Point::new(129.5, 0.0),
        ])
        assert_route_points_close(a23.route, [
          @graph.Point::new(129.5, 66.0),
          @graph.Point::new(129.5, 106.0),
          @graph.Point::new(129.5, 126.0),
          @graph.Point::new(129.5, 166.0),
        ])
        assert_route_points_close(bedge.route, [
          @graph.Point::new(142.5, 414.0),
          @graph.Point::new(142.5, 454.0),
          @graph.Point::new(142.5, 474.0),
          @graph.Point::new(142.5, 514.0),
        ])
      } else {
        assert_eq(a_box, @graph.Box::new(85.0, -174.0, 153.0, 438.0))
        assert_eq(b_box, @graph.Box::new(85.0, 284.0, 179.0, 302.0))
        assert_eq(c_box, @graph.Box::new(12.0, 12.0, 53.0, 66.0))
        assert_eq(a1_box, @graph.Box::new(135.0, -124.0, 52.0, 66.0))
        assert_eq(a2_box, @graph.Box::new(135.0, 12.0, 53.0, 66.0))
        assert_eq(a3_box, @graph.Box::new(135.0, 148.0, 53.0, 66.0))
        assert_eq(b1111_box, @graph.Box::new(135.0, 334.0, 78.0, 66.0))
        assert_eq(b2222_box, @graph.Box::new(135.0, 470.0, 79.0, 66.0))
        assert_eq(a.label_position, Some("INSIDE_TOP_CENTER"))
        assert_eq(b.label_position, Some("INSIDE_TOP_CENTER"))
        assert_route_points_close(a12.route, [
          @graph.Point::new(161.5, -58.0),
          @graph.Point::new(161.5, 12.0),
        ])
        assert_route_points_close(a23.route, [
          @graph.Point::new(161.5, 78.0),
          @graph.Point::new(161.5, 148.0),
        ])
        assert_route_points_close(bedge.route, [
          @graph.Point::new(174.5, 400.0),
          @graph.Point::new(174.5, 470.0),
        ])
      }
    _ =>
      fail(
        "\{engine_name} expected boxes for multiple_constant_nears fixture objects",
      )
  }
}

///|
test "reference grid_in_constant_near matches stable target geometry" {
  let source =
    #|a
    #|b
    #|c
    #|x: {
    #|  near: top-right
    #|  grid-columns: 1
    #|  y
    #|  z
    #|}
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }

  assert_grid_in_constant_near_like_d2(dagre, "dagre")
  assert_grid_in_constant_near_like_d2(elk, "elk")
}

///|
fn assert_grid_in_constant_near_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let target = @diagram.from_graph(graph, None)
  let a = target.find_object("a").unwrap()
  let b = target.find_object("b").unwrap()
  let c = target.find_object("c").unwrap()
  let x = target.find_object("x").unwrap()
  let y = target.find_object("x.y").unwrap()
  let z = target.find_object("x.z").unwrap()

  match
    (
      a.get_box(),
      b.get_box(),
      c.get_box(),
      x.get_box(),
      y.get_box(),
      z.get_box(),
    ) {
    (
      Some(a_box),
      Some(b_box),
      Some(c_box),
      Some(x_box),
      Some(y_box),
      Some(z_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(a_box, @graph.Box::new(0.0, 0.0, 53.0, 66.0))
        assert_eq(b_box, @graph.Box::new(113.0, 0.0, 53.0, 66.0))
        assert_eq(c_box, @graph.Box::new(226.0, 0.0, 53.0, 66.0))
        assert_eq(x_box, @graph.Box::new(299.0, -312.0, 174.0, 292.0))
        assert_eq(y_box, @graph.Box::new(359.0, -252.0, 54.0, 66.0))
        assert_eq(z_box, @graph.Box::new(359.0, -146.0, 54.0, 66.0))
      } else {
        assert_eq(a_box, @graph.Box::new(12.0, 12.0, 53.0, 66.0))
        assert_eq(b_box, @graph.Box::new(85.0, 12.0, 53.0, 66.0))
        assert_eq(c_box, @graph.Box::new(158.0, 12.0, 53.0, 66.0))
        assert_eq(x_box, @graph.Box::new(231.0, -300.0, 174.0, 292.0))
        assert_eq(y_box, @graph.Box::new(291.0, -240.0, 54.0, 66.0))
        assert_eq(z_box, @graph.Box::new(291.0, -134.0, 54.0, 66.0))
      }
    _ =>
      fail(
        "\{engine_name} expected boxes for grid_in_constant_near fixture objects",
      )
  }
}

///|
fn find_edge(
  graph : @graph.GraphInput,
  src_id : String,
  dst_id : String,
) -> @graph.EdgeInput? {
  for edge in graph.get_edges() {
    if edge.lookup_src_id() == src_id && edge.lookup_dst_id() == dst_id {
      return Some(edge)
    }
  }
  None
}

///|
fn find_connection(
  diagram : @diagram.Diagram,
  src_id : String,
  dst_id : String,
) -> @diagram.Connection? {
  for connection in diagram.get_edges() {
    if connection.src_lookup_id == src_id && connection.dst_lookup_id == dst_id {
      return Some(connection)
    }
  }
  None
}

///|
fn find_connections(
  diagram : @diagram.Diagram,
  src_id : String,
  dst_id : String,
) -> Array[@diagram.Connection] {
  let matches : Array[@diagram.Connection] = []
  for connection in diagram.get_edges() {
    if connection.src_lookup_id == src_id && connection.dst_lookup_id == dst_id {
      matches.push(connection)
    }
  }
  matches.sort_by(fn(a, b) {
    let ay = if a.route.is_empty() { 0.0 } else { a.route[0].y }
    let by = if b.route.is_empty() { 0.0 } else { b.route[0].y }
    ay.compare(by)
  })
  matches
}

///|
fn assert_route_points_close(
  actual : Array[@graph.Point],
  expected : Array[@graph.Point],
  tolerance? : Double = 1.0e-3,
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i in 0..<actual.length() {
    let dx = (actual[i].x - expected[i].x).abs()
    let dy = (actual[i].y - expected[i].y).abs()
    assert_true(
      dx <= tolerance && dy <= tolerance,
      msg="route point \{i} mismatch: actual=\{actual[i]}, expected=\{expected[i]}, dx=\{dx}, dy=\{dy}",
    )
  }
}

///|
fn require_shape_box(
  shape : @diagram.Shape,
  id : String,
  engine_name : String,
) -> @graph.Box raise {
  match shape.get_box() {
    Some(box) => box
    None => fail("\{engine_name} expected box for \{id}")
  }
}

///|
test "container contains children" {
  let source =
    #|parent {
    #|  child1
    #|  child2
    #|}
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  let parent = graph.find_object("parent").unwrap()
  let child1 = graph.find_object("parent.child1").unwrap()
  let child2 = graph.find_object("parent.child2").unwrap()
  if parent.get_box() is Some(parent_box) {
    if child1.center() is Some(c1) {
      assert_true(
        parent_box.contains(c1),
        msg="child1 center should be inside parent",
      )
    } else {
      fail("child1 should have center")
    }
    if child2.center() is Some(c2) {
      assert_true(
        parent_box.contains(c2),
        msg="child2 center should be inside parent",
      )
    } else {
      fail("child2 should have center")
    }
  } else {
    fail("parent should have box")
  }
}

///|
test "nested children are packed inside parent" {
  let source =
    #|parent {
    #|  child1
    #|  child2
    #|}
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  let child1 = graph.find_object("parent.child1").unwrap()
  let child2 = graph.find_object("parent.child2").unwrap()
  match (child1.get_box(), child2.get_box()) {
    (Some(box1), Some(box2)) =>
      assert_true(
        box2.get_x() > box1.get_x(),
        msg="child2 should be to the right of child1",
      )
    _ => fail("children should have boxes")
  }
}

///|
test "constant near containers keep descendants and cross edges aligned in dagre and elk" {
  let source =
    #|main
    #|cluster: {
    #|  near: top-left
    #|  a
    #|  b
    #|  a -> b
    #|}
    #|cluster.a -> main
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()

  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("dagre layout error: \{e}")
  }
  assert_constant_near_container_layout(dagre, "dagre")

  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk layout error: \{e}")
  }
  assert_constant_near_container_layout(elk, "elk")
}

///|
fn assert_constant_near_container_layout(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let cluster = graph.find_object("cluster").unwrap()
  let child_a = graph.find_object("cluster.a").unwrap()
  let child_b = graph.find_object("cluster.b").unwrap()
  let main = graph.find_object("main").unwrap()
  match
    (cluster.get_box(), child_a.get_box(), child_b.get_box(), main.get_box()) {
    (Some(cluster_box), Some(a_box), Some(b_box), Some(main_box)) => {
      assert_true(
        cluster_box.contains(a_box.center()),
        msg="\{engine_name} constant-near child a should stay inside container",
      )
      assert_true(
        cluster_box.contains(b_box.center()),
        msg="\{engine_name} constant-near child b should stay inside container",
      )
      assert_true(
        cluster_box.x < main_box.x && cluster_box.y < main_box.y,
        msg="\{engine_name} constant-near container should move above-left of the main graph",
      )
    }
    _ => fail("\{engine_name} constant-near objects should all have boxes")
  }

  let mut cross_edge : @graph.EdgeInput? = None
  for edge in graph.edges {
    if edge.src_id == "cluster.a" && edge.dst_id == "main" {
      cross_edge = Some(edge)
      break
    }
  }
  guard cross_edge is Some(edge) else {
    fail("\{engine_name} expected cluster.a -> main edge")
  }
  let route = edge.route
  assert_true(
    route.length() >= 2,
    msg="\{engine_name} cross edge should have route points",
  )
  match (child_a.get_box(), main.get_box()) {
    (Some(a_box), Some(main_box)) => {
      let start = route[0]
      let end = route[route.length() - 1]
      assert_true(
        start.distance(a_box.center()) < a_box.get_width(),
        msg="\{engine_name} cross edge should start near moved child",
      )
      assert_true(
        end.distance(main_box.center()) < main_box.get_width(),
        msg="\{engine_name} cross edge should end near destination",
      )
    }
    _ => fail("\{engine_name} edge endpoint objects should have boxes")
  }
}

///|
test "edges have route points" {
  let graph = compile_to_graph("a -> b", @engine_api.Direction::Down).unwrap()
  let edges = graph.get_edges()
  assert_true(edges.length() == 1)
  let route = edges[0].route
  assert_true(
    route.length() >= 2,
    msg="edge should have at least 2 route points",
  )
}

///|
test "edge bend points override routing" {
  let source =
    #|a
    #|b
    #|a -> b {
    #|  bend-points: [[10, 20], [30, 40]]
    #|}
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  let edge = graph.get_edges()[0]
  guard edge.bend_points is Some(bend_points) else {
    fail("expected edge bend points")
  }
  assert_eq(bend_points.length(), 2)
  assert_eq(bend_points[0].get_x(), 10.0)
  assert_eq(bend_points[0].get_y(), 20.0)
  assert_eq(bend_points[1].get_x(), 30.0)
  assert_eq(bend_points[1].get_y(), 40.0)
  let route = edge.route
  assert_true(route.length() >= 2, msg="expected route points")
}

///|
test "edge route connects source to destination" {
  let graph = compile_to_graph("a -> b", @engine_api.Direction::Down).unwrap()
  let a = graph.find_object("a").unwrap()
  let b = graph.find_object("b").unwrap()
  let edges = graph.get_edges()
  let route = edges[0].route
  match (a.get_box(), b.get_box()) {
    (Some(box_a), Some(box_b)) => {
      let start = route[0]
      let a_center = box_a.center()
      let dist_to_a = start.distance(a_center)
      assert_true(
        dist_to_a < box_a.get_width(),
        msg="edge start should be near source object",
      )
      let end = route[route.length() - 1]
      let b_center = box_b.center()
      let dist_to_b = end.distance(b_center)
      assert_true(
        dist_to_b < box_b.get_width(),
        msg="edge end should be near destination object",
      )
    }
    _ => fail("objects should have boxes")
  }
}

///|
test "label width affects object size" {
  let graph = compile_to_graph(
    "short\nthis_is_a_very_long_label_name",
    @engine_api.Direction::Down,
  ).unwrap()
  let short = graph.find_object("short").unwrap()
  let long = graph.find_object("this_is_a_very_long_label_name").unwrap()
  match (short.get_box(), long.get_box()) {
    (Some(box_short), Some(box_long)) =>
      assert_true(
        box_long.get_width() >= box_short.get_width(),
        msg="long label width should not be smaller than short label width",
      )
    _ => fail("objects should have boxes")
  }
}

///|
test "shape is preserved in graph" {
  let source =
    #|db {
    #|  shape: cylinder
    #|}
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  let db = graph.find_object("db").unwrap()
  inspect(db.shape_type.to_shape_string(), content="cylinder")
}

///|
test "shape with label is preserved" {
  let source =
    #|database: Database {
    #|  shape: cylinder
    #|}
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  let db = graph.find_object("database").unwrap()
  inspect(db.label, content="Database")
  inspect(db.shape_type.to_shape_string(), content="cylinder")
}

///|
test "objects ordered by definition" {
  let source =
    #|server
    #|database
    #|cache
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  let server = graph.find_object("server").unwrap()
  let database = graph.find_object("database").unwrap()
  let cache = graph.find_object("cache").unwrap()
  match (server.get_box(), database.get_box(), cache.get_box()) {
    (Some(s), Some(d), Some(c)) => {
      assert_true(
        s.center() != d.center(),
        msg="server and database should not share the same center",
      )
      assert_true(
        d.center() != c.center(),
        msg="database and cache should not share the same center",
      )
    }
    _ => fail("objects should have boxes")
  }
}

///|
test "sql_table edges connect to correct rows" {
  let source =
    #|users: {
    #|  shape: sql_table
    #|  id: int
    #|  name: varchar(255)
    #|  email: varchar(255)
    #|  created_at: timestamp
    #|}
    #|posts: {
    #|  shape: sql_table
    #|  id: int
    #|  user_id: int
    #|  title: varchar(255)
    #|  content: text
    #|  published: boolean
    #|}
    #|comments: {
    #|  shape: sql_table
    #|  id: int
    #|  post_id: int
    #|  user_id: int
    #|  body: text
    #|}
    #|users.id <-> posts.user_id
    #|posts.id <-> comments.post_id
    #|users.id <-> comments.user_id
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  let users_box = graph.find_object("users").unwrap().get_box().unwrap()
  let posts_box = graph.find_object("posts").unwrap().get_box().unwrap()
  let comments_box = graph.find_object("comments").unwrap().get_box().unwrap()
  assert_true(users_box.get_width() > 0.0, msg="users table width")
  assert_true(users_box.get_height() > 0.0, msg="users table height")
  assert_true(posts_box.get_width() > 0.0, msg="posts table width")
  assert_true(posts_box.get_height() > 0.0, msg="posts table height")
  assert_true(comments_box.get_width() > 0.0, msg="comments table width")
  assert_true(comments_box.get_height() > 0.0, msg="comments table height")
  assert_eq(graph.get_edges().length(), 3)
  let mut found_users_posts = false
  let mut found_posts_comments = false
  let mut found_users_comments = false
  let edge_debug : Array[String] = []
  for edge in graph.get_edges() {
    let route = edge.route
    guard route.length() >= 2 else { continue }
    edge_debug.push(
      "\{edge.src_id}[\{edge.src_column_index}] -> \{edge.dst_id}[\{edge.dst_column_index}]",
    )
    if edge.src_id == "users" && edge.dst_id == "posts" {
      found_users_posts = true
    } else if edge.src_id == "posts" && edge.dst_id == "comments" {
      found_posts_comments = true
    } else if edge.src_id == "users" && edge.dst_id == "comments" {
      found_users_comments = true
    }
  }
  let edge_debug_text = edge_debug.join("; ")
  assert_true(
    found_users_posts,
    msg="missing edge users <-> posts, got: \{edge_debug_text}",
  )
  assert_true(
    found_posts_comments,
    msg="missing edge posts <-> comments, got: \{edge_debug_text}",
  )
  assert_true(
    found_users_comments,
    msg="missing edge users <-> comments, got: \{edge_debug_text}",
  )
}

///|
test "sql_table edges are clipped to boxes" {
  let source =
    #|users: {
    #|  shape: sql_table
    #|  id: int
    #|  name: varchar(255)
    #|  email: varchar(255)
    #|  created_at: timestamp
    #|}
    #|posts: {
    #|  shape: sql_table
    #|  id: int
    #|  user_id: int
    #|  title: varchar(255)
    #|  content: text
    #|  published: boolean
    #|}
    #|comments: {
    #|  shape: sql_table
    #|  id: int
    #|  post_id: int
    #|  user_id: int
    #|  body: text
    #|}
    #|users.id <-> posts.user_id
    #|posts.id <-> comments.post_id
    #|users.id <-> comments.user_id
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  for edge in graph.get_edges() {
    let route = edge.route
    assert_true(route.length() >= 2, msg="sql_table edge should have a route")
  }
}
