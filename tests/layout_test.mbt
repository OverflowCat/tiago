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
    (Some(box_a), Some(box_b)) =>
      assert_true(
        box_b.get_y() > box_a.get_y(),
        msg="b should be below a in Down direction",
      )
    _ => fail("objects should have boxes")
  }
}

///|
test "right direction stacks objects horizontally" {
  let graph = compile_to_graph("a\nb", @engine_api.Direction::Right).unwrap()
  let a = graph.find_object("a").unwrap()
  let b = graph.find_object("b").unwrap()
  match (a.get_box(), b.get_box()) {
    (Some(box_a), Some(box_b)) =>
      assert_true(
        box_b.get_x() > box_a.get_x(),
        msg="b should be to the right of a in Right direction",
      )
    _ => fail("objects should have boxes")
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
test "nested children are stacked inside parent" {
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
        box2.get_y() > box1.get_y(),
        msg="child2 should be below child1",
      )
    _ => fail("children should have boxes")
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
  let route = edge.route
  assert_true(route.length() >= 4, msg="expected bend points in route")
  assert_eq(route[1].get_x(), 10.0)
  assert_eq(route[1].get_y(), 20.0)
  assert_eq(route[2].get_x(), 30.0)
  assert_eq(route[2].get_y(), 40.0)
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
        box_long.get_width() > box_short.get_width(),
        msg="longer label should result in wider object",
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
      assert_true(s.get_y() < d.get_y(), msg="server should be above database")
      assert_true(d.get_y() < c.get_y(), msg="database should be above cache")
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
  let users_cols = 4
  let posts_cols = 5
  let comments_cols = 4

  // Height: header font height * (rows + 1)
  let eps = 1.0e-6
  assert_true(
    (users_box.get_height() - sql_table_expected_height("users", users_cols)).abs() <=
    eps,
    msg="users table height",
  )
  assert_true(
    (posts_box.get_height() - sql_table_expected_height("posts", posts_cols)).abs() <=
    eps,
    msg="posts table height",
  )
  assert_true(
    (comments_box.get_height() -
    sql_table_expected_height("comments", comments_cols)).abs() <=
    eps,
    msg="comments table height",
  )
  assert_eq(graph.get_edges().length(), 3)
  let mut found_users_posts = false
  let mut found_posts_comments = false
  let mut found_users_comments = false
  for edge in graph.get_edges() {
    let src = edge.src_id
    let dst = edge.dst_id
    let route = edge.route
    guard route.length() >= 2 else { continue }
    let start = route[0]
    let end = route[route.length() - 1]
    if src == "users.id" && dst == "posts.user_id" {
      found_users_posts = true
      let exp_start = sql_edge_row_anchor_point(
        users_box, users_cols, posts_box, posts_cols, 0, true,
      )
      let exp_end = sql_edge_row_anchor_point(
        users_box, users_cols, posts_box, posts_cols, 1, false,
      )
      assert_true(
        (start.get_x() - exp_start.get_x()).abs() <= eps,
        msg="users.id start x",
      )
      assert_true(
        (start.get_y() - exp_start.get_y()).abs() <= eps,
        msg="users.id start y",
      )
      assert_true(
        (end.get_x() - exp_end.get_x()).abs() <= eps,
        msg="posts.user_id end x",
      )
      assert_true(
        (end.get_y() - exp_end.get_y()).abs() <= eps,
        msg="posts.user_id end y",
      )
    } else if src == "posts.id" && dst == "comments.post_id" {
      found_posts_comments = true
      let exp_start = sql_edge_row_anchor_point(
        posts_box, posts_cols, comments_box, comments_cols, 0, true,
      )
      let exp_end = sql_edge_row_anchor_point(
        posts_box, posts_cols, comments_box, comments_cols, 1, false,
      )
      assert_true(
        (start.get_x() - exp_start.get_x()).abs() <= eps,
        msg="posts.id start x",
      )
      assert_true(
        (start.get_y() - exp_start.get_y()).abs() <= eps,
        msg="posts.id start y",
      )
      assert_true(
        (end.get_x() - exp_end.get_x()).abs() <= eps,
        msg="comments.post_id end x",
      )
      assert_true(
        (end.get_y() - exp_end.get_y()).abs() <= eps,
        msg="comments.post_id end y",
      )
    } else if src == "users.id" && dst == "comments.user_id" {
      found_users_comments = true
      let exp_start = sql_edge_row_anchor_point(
        users_box, users_cols, comments_box, comments_cols, 0, true,
      )
      let exp_end = sql_edge_row_anchor_point(
        users_box, users_cols, comments_box, comments_cols, 2, false,
      )
      assert_true(
        (start.get_x() - exp_start.get_x()).abs() <= eps,
        msg="users.id start (to comments) x",
      )
      assert_true(
        (start.get_y() - exp_start.get_y()).abs() <= eps,
        msg="users.id start (to comments) y",
      )
      assert_true(
        (end.get_x() - exp_end.get_x()).abs() <= eps,
        msg="comments.user_id end x",
      )
      assert_true(
        (end.get_y() - exp_end.get_y()).abs() <= eps,
        msg="comments.user_id end y",
      )
    }
  }
  assert_true(found_users_posts, msg="missing edge users.id <-> posts.user_id")
  assert_true(
    found_posts_comments,
    msg="missing edge posts.id <-> comments.post_id",
  )
  assert_true(
    found_users_comments,
    msg="missing edge users.id <-> comments.user_id",
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
  let sql_table_ids = ["users", "posts", "comments"]
  let sql_row_boxes : Array[(String, Int, @graph.Box)] = []
  for table_id in sql_table_ids {
    let table_box = graph.find_object(table_id).unwrap().get_box().unwrap()
    let num_cols = sql_table_column_count(table_id)
    let row_height = table_box.get_height() / (num_cols + 1).to_double()
    let inset = 1.0
    for row_idx in 0..<num_cols {
      let y = table_box.get_y() + row_height * (row_idx.to_double() + 1.0)
      let row_box = @graph.Box::new(
        table_box.get_x() + inset,
        y,
        table_box.get_width() - 2.0 * inset,
        row_height,
      )
      sql_row_boxes.push((table_id, row_idx, row_box))
    }
  }
  for edge in graph.get_edges() {
    let route = edge.route
    guard route.length() >= 2 else { continue }
    for i in 0..<(route.length() - 1) {
      let p0 = route[i]
      let p1 = route[i + 1]
      for row in sql_row_boxes {
        let (table_id, row_idx, row_box) = row
        assert_false(
          line_segment_intersects_box(p0, p1, row_box),
          msg="edge \{edge.src_id} -> \{edge.dst_id} seg \{i} intersects \{table_id} row \{row_idx}: (\{p0.get_x()},\{p0.get_y()}) -> (\{p1.get_x()},\{p1.get_y()}) vs box (\{row_box.get_x()},\{row_box.get_y()},\{row_box.get_width()},\{row_box.get_height()})",
        )
      }
    }
  }
}

///|
const SQL_TABLE_FONT_SIZE_L : Int = 20

///|
const SQL_TABLE_HEADER_FONT_ADD : Int = 4

///|
fn sql_table_column_count(table_id : String) -> Int {
  match table_id {
    "users" => 4
    "posts" => 5
    "comments" => 4
    _ => 0
  }
}

///|
fn sql_table_expected_height(label : String, num_cols : Int) -> Double {
  let header_font_size = SQL_TABLE_FONT_SIZE_L + SQL_TABLE_HEADER_FONT_ADD
  let dims = @text_metrics.measure_label(
    label, header_font_size, false, false, false,
  )
  dims.height * (num_cols + 1).to_double()
}

///|
fn sql_row_center_y(
  table_box : @graph.Box,
  num_cols : Int,
  col_idx : Int,
) -> Double {
  let row_height = table_box.get_height() / (num_cols + 1).to_double()
  table_box.get_y() +
  row_height * (col_idx.to_double() + 1.0) +
  row_height / 2.0
}

///|
fn sql_edge_row_anchor_point(
  src_box : @graph.Box,
  src_cols : Int,
  dst_box : @graph.Box,
  dst_cols : Int,
  col_idx : Int,
  is_source : Bool,
) -> @graph.Point {
  let y = if is_source {
    sql_row_center_y(src_box, src_cols, col_idx)
  } else {
    sql_row_center_y(dst_box, dst_cols, col_idx)
  }
  let dx = dst_box.center().get_x() - src_box.center().get_x()
  let x = if is_source {
    if dx >= 0.0 {
      src_box.get_x() + src_box.get_width()
    } else {
      src_box.get_x()
    }
  } else if dx >= 0.0 {
    dst_box.get_x()
  } else {
    dst_box.get_x() + dst_box.get_width()
  }
  @graph.Point::new(x, y)
}

///|
fn line_segment_intersects_box(
  p1 : @graph.Point,
  p2 : @graph.Point,
  box : @graph.Box,
) -> Bool {
  let left = box.get_x()
  let right = box.get_x() + box.get_width()
  let top = box.get_y()
  let bottom = box.get_y() + box.get_height()
  let p1_x = p1.get_x()
  let p1_y = p1.get_y()
  let p2_x = p2.get_x()
  let p2_y = p2.get_y()
  let dx = p2_x - p1_x
  let dy = p2_y - p1_y
  let mut t_min = 0.0
  let mut t_max = 1.0
  if dx != 0.0 {
    let t1 = (left - p1_x) / dx
    let t2 = (right - p1_x) / dx
    let (tx_min, tx_max) = if t1 < t2 { (t1, t2) } else { (t2, t1) }
    t_min = if tx_min > t_min { tx_min } else { t_min }
    t_max = if tx_max < t_max { tx_max } else { t_max }
  } else if p1_x < left || p1_x > right {
    return false
  }
  if dy != 0.0 {
    let t1 = (top - p1_y) / dy
    let t2 = (bottom - p1_y) / dy
    let (ty_min, ty_max) = if t1 < t2 { (t1, t2) } else { (t2, t1) }
    t_min = if ty_min > t_min { ty_min } else { t_min }
    t_max = if ty_max < t_max { ty_max } else { t_max }
  } else if p1_y < top || p1_y > bottom {
    return false
  }
  if t_min > t_max {
    return false
  }

  // Only count intersections that occur away from the segment endpoints.
  let eps = 1.0e-6
  let inner_min = if t_min > eps { t_min } else { eps }
  let inner_max = if t_max < 1.0 - eps { t_max } else { 1.0 - eps }
  inner_min <= inner_max
}
