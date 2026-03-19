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
test "d2 nested_layout_bug root grid keeps nested container as a grid cell" {
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
test "d2 nested_diagram_types keeps nested sequence descendants inside their containers" {
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
test "d2 grid_nested_simple_edges preserves nested grid child order" {
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
test "d2 grid_nested_gap0 matches stable nested grid boxes" {
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
    #|    D2
    #|    Cloud
    #|  }
    #|  D2.width: 200
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

  assert_grid_nested_gap0_like_d2(dagre, "dagre")
  assert_grid_nested_gap0_like_d2(elk, "elk")
}

///|
fn assert_grid_nested_gap0_like_d2(
  graph : @graph.GraphInput,
  engine_name : String,
) -> Unit raise {
  let universe = graph.find_object("The Universe").unwrap()
  let first_two = graph.find_object("The Universe.FirstTwo").unwrap()
  let last = graph.find_object("The Universe.Last").unwrap()
  let tala = graph.find_object("The Universe.TALA").unwrap()
  let tala_tala = graph.find_object("The Universe.TALA.TALA").unwrap()
  let tala_d2 = graph.find_object("The Universe.TALA.D2").unwrap()
  let tala_cloud = graph.find_object("The Universe.TALA.Cloud").unwrap()
  let d2 = graph.find_object("The Universe.D2").unwrap()
  let cloud = graph.find_object("The Universe.Cloud").unwrap()
  let terrastruct = graph.find_object("The Universe.Terrastruct").unwrap()

  match
    (
      universe.get_box(),
      first_two.get_box(),
      last.get_box(),
      tala.get_box(),
      tala_tala.get_box(),
      tala_d2.get_box(),
      tala_cloud.get_box(),
      d2.get_box(),
      cloud.get_box(),
      terrastruct.get_box(),
    ) {
    (
      Some(universe_box),
      Some(first_two_box),
      Some(last_box),
      Some(tala_box),
      Some(tala_tala_box),
      Some(tala_d2_box),
      Some(tala_cloud_box),
      Some(d2_box),
      Some(cloud_box),
      Some(terrastruct_box),
    ) =>
      if engine_name == "dagre" {
        assert_eq(universe_box, @graph.Box::new(0.0, 0.0, 400.0, 366.0))
        assert_eq(first_two_box, @graph.Box::new(0.0, 46.0, 300.0, 66.0))
        assert_eq(last_box, @graph.Box::new(300.0, 46.0, 100.0, 66.0))
        assert_eq(tala_box, @graph.Box::new(0.0, 112.0, 100.0, 193.0))
        assert_eq(tala_tala_box, @graph.Box::new(0.0, 112.0, 100.0, 61.0))
        assert_eq(tala_d2_box, @graph.Box::new(0.0, 173.0, 100.0, 66.0))
        assert_eq(tala_cloud_box, @graph.Box::new(0.0, 239.0, 100.0, 66.0))
        assert_eq(d2_box, @graph.Box::new(100.0, 112.0, 200.0, 193.0))
        assert_eq(cloud_box, @graph.Box::new(300.0, 112.0, 100.0, 193.0))
        assert_eq(terrastruct_box, @graph.Box::new(0.0, 305.0, 400.0, 61.0))
      } else {
        assert_eq(universe_box, @graph.Box::new(12.0, 12.0, 400.0, 366.0))
        assert_eq(first_two_box, @graph.Box::new(12.0, 58.0, 300.0, 66.0))
        assert_eq(last_box, @graph.Box::new(312.0, 58.0, 100.0, 66.0))
        assert_eq(tala_box, @graph.Box::new(12.0, 124.0, 100.0, 193.0))
        assert_eq(tala_tala_box, @graph.Box::new(12.0, 124.0, 100.0, 61.0))
        assert_eq(tala_d2_box, @graph.Box::new(12.0, 185.0, 100.0, 66.0))
        assert_eq(tala_cloud_box, @graph.Box::new(12.0, 251.0, 100.0, 66.0))
        assert_eq(d2_box, @graph.Box::new(112.0, 124.0, 200.0, 193.0))
        assert_eq(cloud_box, @graph.Box::new(312.0, 124.0, 100.0, 193.0))
        assert_eq(terrastruct_box, @graph.Box::new(12.0, 317.0, 400.0, 61.0))
      }
    _ =>
      fail("\{engine_name} expected boxes for grid_nested_gap0 fixture objects")
  }
}

///|
test "d2 grid_nested grid-with-container matches stable boxes" {
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
test "d2 grid_nested grid-in-grid matches stable boxes" {
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
test "d2 grid_nested grid-with-nested-containers matches stable boxes" {
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
test "d2 grid_nested grid-with-grid-with-grid matches stable boxes" {
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
test "d2 empty_nested_grid matches stable boxes" {
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
test "d2 empty_sequence matches stable boxes" {
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
test "d2 nested_steps matches stable boxes" {
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
test "d2 multiple_constant_nears matches stable target geometry" {
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
test "d2 constant_near_title matches stable target geometry" {
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
        assert_true(
          (title_box.x + title_box.width / 2.0 - 165.5).abs() <= 1.0,
          msg="\{engine_name} expected constant-near title to stay centered like D2",
        )
        assert_true(
          (title_box.y + title_box.height - -20.0).abs() <= 1.0,
          msg="\{engine_name} expected constant-near title bottom to match D2 placement",
        )
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
        assert_true(
          (title_box.x + title_box.width / 2.0 - 157.5).abs() <= 1.0,
          msg="\{engine_name} expected constant-near title to stay centered like D2",
        )
        assert_true(
          (title_box.y + title_box.height - -8.0).abs() <= 1.0,
          msg="\{engine_name} expected constant-near title bottom to match D2 placement",
        )
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
test "d2 grid_in_constant_near matches stable target geometry" {
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
