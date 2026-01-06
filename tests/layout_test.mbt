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
  let graph = compile_to_graph("a\nb\nc", @layout.Direction::Down).unwrap()
  for obj in graph.get_objects() {
    let box = obj.get_box()
    assert_true(box is Some(_))
  }
}

///|
test "objects have positive dimensions" {
  let graph = compile_to_graph("server: Web Server", @layout.Direction::Down).unwrap()
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
  let graph = compile_to_graph("a\nb\nc", @layout.Direction::Down).unwrap()
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
  let graph = compile_to_graph("a\nb", @layout.Direction::Down).unwrap()
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
  let graph = compile_to_graph("a\nb", @layout.Direction::Right).unwrap()
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
  let graph = compile_to_graph(source, @layout.Direction::Down).unwrap()
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
  let graph = compile_to_graph(source, @layout.Direction::Down).unwrap()
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
  let graph = compile_to_graph("a -> b", @layout.Direction::Down).unwrap()
  let edges = graph.get_edges()
  assert_true(edges.length() == 1)
  let route = edges[0].get_route()
  assert_true(
    route.length() >= 2,
    msg="edge should have at least 2 route points",
  )
}

///|
test "edge route connects source to destination" {
  let graph = compile_to_graph("a -> b", @layout.Direction::Down).unwrap()
  let a = graph.find_object("a").unwrap()
  let b = graph.find_object("b").unwrap()
  let edges = graph.get_edges()
  let route = edges[0].get_route()
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
    @layout.Direction::Down,
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
  let graph = compile_to_graph(source, @layout.Direction::Down).unwrap()
  let db = graph.find_object("db").unwrap()
  inspect(db.get_shape(), content="cylinder")
}

///|
test "shape with label is preserved" {
  let source =
    #|database: Database {
    #|  shape: cylinder
    #|}
  let graph = compile_to_graph(source, @layout.Direction::Down).unwrap()
  let db = graph.find_object("database").unwrap()
  inspect(db.get_label(), content="Database")
  inspect(db.get_shape(), content="cylinder")
}

///|
test "objects ordered by definition" {
  let source =
    #|server
    #|database
    #|cache
  let graph = compile_to_graph(source, @layout.Direction::Down).unwrap()
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

// =============================================================================
// Near positioning tests
// =============================================================================

///|
test "near constant position top-left" {
  let source =
    #|a
    #|b
    #|title: Title {
    #|  near: top-left
    #|}
  let graph = compile_to_graph(source, @layout.Direction::Down).unwrap()
  let title = graph.find_object("title").unwrap()
  if title.get_box() is Some(box) {
    // Should be positioned near top-left of the diagram
    assert_true(box.get_x() < 100.0, msg="title should be near left edge")
    assert_true(box.get_y() < 100.0, msg="title should be near top edge")
  } else {
    fail("title should have box")
  }
}

///|
test "near object positioning" {
  let source =
    #|server
    #|info: Server Info {
    #|  near: server
    #|}
  let graph = compile_to_graph(source, @layout.Direction::Down).unwrap()
  let server = graph.find_object("server").unwrap()
  let info = graph.find_object("info").unwrap()
  if server.get_box() is Some(server_box) && info.get_box() is Some(info_box) {
    // Info should be positioned to the right of server
    assert_true(
      info_box.get_x() > server_box.get_x(),
      msg="info should be to the right of server",
    )
  } else {
    fail("objects should have boxes")
  }
}

///|
test "near bottom-right position" {
  let source =
    #|a
    #|b
    #|footer: Copyright {
    #|  near: bottom-right
    #|}
  let graph = compile_to_graph(source, @layout.Direction::Down).unwrap()
  let footer = graph.find_object("footer").unwrap()
  let a = graph.find_object("a").unwrap()
  if footer.get_box() is Some(footer_box) && a.get_box() is Some(a_box) {
    // Footer should be below and to the right of other elements
    assert_true(
      footer_box.get_y() > a_box.get_y(),
      msg="footer should be below other elements",
    )
  } else {
    fail("objects should have boxes")
  }
}
