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
