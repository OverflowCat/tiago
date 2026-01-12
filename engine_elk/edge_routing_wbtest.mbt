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
/// Regression tests for edge routing perpendicularity

///|
fn layout_to_graph_for_routing(
  graph : @graph.Graph,
  config : LayoutConfig,
  direction : Direction,
) -> @graph.Graph raise LayoutError {
  let input = @graph.GraphInput::from_graph(graph)
  let outputs = layout(input, config, direction)
  outputs.layout.materialize(input)
}

///|
/// Helper to check if a segment is horizontal (dy < tolerance)
fn is_horizontal(
  p0 : @graph.Point,
  p1 : @graph.Point,
  tolerance : Double,
) -> Bool {
  let dy = (p1.y - p0.y).abs()
  let dx = (p1.x - p0.x).abs()
  dy < tolerance && dx > tolerance
}

///|
/// Helper to check if a segment is vertical (dx < tolerance)
fn is_vertical(
  p0 : @graph.Point,
  p1 : @graph.Point,
  tolerance : Double,
) -> Bool {
  let dx = (p1.x - p0.x).abs()
  let dy = (p1.y - p0.y).abs()
  dx < tolerance && dy > tolerance
}

///|
/// Helper to check if point is on node boundary
fn point_on_boundary(
  p : @graph.Point,
  box : @graph.Box,
  tolerance : Double,
) -> (Bool, Bool, Bool, Bool) {
  let on_left = (p.x - box.x).abs() < tolerance
  let on_right = (p.x - (box.x + box.width)).abs() < tolerance
  let on_top = (p.y - box.y).abs() < tolerance
  let on_bottom = (p.y - (box.y + box.height)).abs() < tolerance
  (on_left, on_right, on_top, on_bottom)
}

///|
/// Test: Simple two-node vertical arrangement (A above B)
test "edge routing: two nodes vertical - A above B" {
  let graph = @graph.Graph::new("test")
  let a = @graph.Object::with_label("A", "Node A")
  let b = @graph.Object::with_label("B", "Node B")
  graph.add_object(a)
  graph.add_object(b)
  graph.add_edge(@graph.Edge::new(0, "A", "B", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  // Get the edge route
  let edge = laid_out.edges[0]
  inspect(edge.route.length() >= 2, content="true")

  // Get node boxes
  let a_box = laid_out.find_object("A").unwrap().get_box().unwrap()

  // Check first segment
  let p0 = edge.route[0]
  let p1 = edge.route[1]
  let first_horiz = is_horizontal(p0, p1, 2.0)
  let first_vert = is_vertical(p0, p1, 2.0)

  // Check start point is on correct side
  let (on_left, on_right, on_top, on_bottom) = point_on_boundary(p0, a_box, 2.0)

  // For vertical first segment, start should be on top or bottom
  // For horizontal first segment, start should be on left or right
  if first_vert {
    inspect(on_top || on_bottom, content="true")
  }
  if first_horiz {
    inspect(on_left || on_right, content="true")
  }
}

///|
/// Test: Two nodes horizontal arrangement (A left of B)
test "edge routing: two nodes horizontal - A left of B" {
  let graph = @graph.Graph::new("test")
  let a = @graph.Object::with_label("A", "Node A")
  let b = @graph.Object::with_label("B", "Node B")
  graph.add_object(a)
  graph.add_object(b)
  graph.add_edge(@graph.Edge::new(0, "A", "B", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Right) catch {
    e => fail("layout failed: \{e}")
  }
  let edge = laid_out.edges[0]
  inspect(edge.route.length() >= 2, content="true")
  let a_box = laid_out.find_object("A").unwrap().get_box().unwrap()
  let p0 = edge.route[0]
  let p1 = edge.route[1]
  let first_horiz = is_horizontal(p0, p1, 2.0)
  let first_vert = is_vertical(p0, p1, 2.0)
  let (on_left, on_right, on_top, on_bottom) = point_on_boundary(p0, a_box, 2.0)
  if first_vert {
    inspect(on_top || on_bottom, content="true")
  }
  if first_horiz {
    inspect(on_left || on_right, content="true")
  }
}

///|
/// Test: Three nodes in chain (A -> B -> C)
test "edge routing: chain A -> B -> C" {
  let graph = @graph.Graph::new("test")
  graph.add_object(@graph.Object::with_label("A", "A"))
  graph.add_object(@graph.Object::with_label("B", "B"))
  graph.add_object(@graph.Object::with_label("C", "C"))
  graph.add_edge(@graph.Edge::new(0, "A", "B", false, true))
  graph.add_edge(@graph.Edge::new(1, "B", "C", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  // Verify all edges have routes
  inspect(laid_out.edges[0].route.length() >= 2, content="true")
  inspect(laid_out.edges[1].route.length() >= 2, content="true")
}

///|
/// Test: Cycle (A -> B, B -> A) - tests reversed edges
test "edge routing: cycle A <-> B" {
  let graph = @graph.Graph::new("test")
  graph.add_object(@graph.Object::with_label("A", "A"))
  graph.add_object(@graph.Object::with_label("B", "B"))
  graph.add_edge(@graph.Edge::new(0, "A", "B", false, true))
  graph.add_edge(@graph.Edge::new(1, "B", "A", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  let mut errors = 0
  for edge in laid_out.edges {
    if edge.route.length() >= 2 {
      let src_obj = laid_out.find_object(edge.src_id).unwrap()
      let src_box = src_obj.get_box().unwrap()
      let p0 = edge.route[0]
      let p1 = edge.route[1]
      let first_horiz = is_horizontal(p0, p1, 2.0)
      let first_vert = is_vertical(p0, p1, 2.0)
      let (on_left, on_right, on_top, on_bottom) = point_on_boundary(
        p0, src_box, 2.0,
      )

      // Check perpendicularity
      if first_vert && !(on_top || on_bottom) {
        errors = errors + 1
      }
      if first_horiz && !(on_left || on_right) {
        errors = errors + 1
      }
    }
  }
  inspect(errors, content="0")
}

///|
/// Test: Same layer nodes - this might cause horizontal segments from top/bottom
test "edge routing: same layer - multiple sources to one target" {
  // Create a graph where multiple nodes connect to the same target
  // This can cause nodes to be placed in the same layer
  let graph = @graph.Graph::new("test")
  graph.add_object(@graph.Object::with_label("A", "A"))
  graph.add_object(@graph.Object::with_label("B", "B"))
  graph.add_object(@graph.Object::with_label("C", "C"))
  // A and B both point to C
  graph.add_edge(@graph.Edge::new(0, "A", "C", false, true))
  graph.add_edge(@graph.Edge::new(1, "B", "C", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  let mut errors = 0
  for edge in laid_out.edges {
    if edge.route.length() >= 2 {
      let src_obj = laid_out.find_object(edge.src_id).unwrap()
      let src_box = src_obj.get_box().unwrap()
      let p0 = edge.route[0]
      let p1 = edge.route[1]
      let first_horiz = is_horizontal(p0, p1, 2.0)
      let first_vert = is_vertical(p0, p1, 2.0)
      let (on_left, on_right, on_top, on_bottom) = point_on_boundary(
        p0, src_box, 2.0,
      )
      if first_vert && !(on_top || on_bottom) {
        errors = errors + 1
      }
      if first_horiz && !(on_left || on_right) {
        errors = errors + 1
      }
    }
  }
  inspect(errors, content="0")
}

///|
/// Test: Complex graph with cycle - similar to failing property test
test "edge routing: complex with cycle" {
  let graph = @graph.Graph::new("test")
  // Create nodes similar to the failing test case
  graph.add_object(@graph.Object::with_label("N1", "N1"))
  graph.add_object(@graph.Object::with_label("N2", "N2"))
  graph.add_object(@graph.Object::with_label("N3", "N3"))
  // Create a cycle
  graph.add_edge(@graph.Edge::new(0, "N1", "N2", false, true))
  graph.add_edge(@graph.Edge::new(1, "N2", "N3", false, true))
  graph.add_edge(@graph.Edge::new(2, "N3", "N1", false, true)) // Back edge
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  let mut errors = 0
  for edge in laid_out.edges {
    if edge.route.length() >= 2 {
      let src_obj = laid_out.find_object(edge.src_id).unwrap()
      let src_box = src_obj.get_box().unwrap()
      let p0 = edge.route[0]
      let p1 = edge.route[1]
      let first_horiz = is_horizontal(p0, p1, 2.0)
      let first_vert = is_vertical(p0, p1, 2.0)
      let (on_left, on_right, on_top, on_bottom) = point_on_boundary(
        p0, src_box, 2.0,
      )
      if first_vert && !(on_top || on_bottom) {
        errors = errors + 1
      }
      if first_horiz && !(on_left || on_right) {
        errors = errors + 1
      }
    }
  }
  inspect(errors, content="0")
}

///|
/// Test: Parallel edges (A -> B and A -> B again)
test "edge routing: parallel edges" {
  let graph = @graph.Graph::new("test")
  graph.add_object(@graph.Object::with_label("A", "A"))
  graph.add_object(@graph.Object::with_label("B", "B"))
  graph.add_edge(@graph.Edge::new(0, "A", "B", false, true))
  graph.add_edge(@graph.Edge::new(1, "A", "B", false, true)) // Duplicate
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  // Check that boxes are assigned
  inspect(
    laid_out.find_object("A").unwrap().get_box() is Some(_),
    content="true",
  )
  inspect(
    laid_out.find_object("B").unwrap().get_box() is Some(_),
    content="true",
  )
  // Check that routes are assigned
  inspect(laid_out.edges[0].route.length() >= 2, content="true")
  inspect(laid_out.edges[1].route.length() >= 2, content="true")
}

///|
/// Test: Bidirectional edges (A -> B and B -> A)
test "edge routing: bidirectional edges" {
  let graph = @graph.Graph::new("test")
  graph.add_object(@graph.Object::with_label("A", "A"))
  graph.add_object(@graph.Object::with_label("B", "B"))
  graph.add_edge(@graph.Edge::new(0, "A", "B", false, true))
  graph.add_edge(@graph.Edge::new(1, "B", "A", false, true))
  graph.add_edge(@graph.Edge::new(2, "A", "B", false, true)) // Duplicate
  graph.add_edge(@graph.Edge::new(3, "B", "A", false, true)) // Duplicate
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  // Check that boxes are assigned
  inspect(
    laid_out.find_object("A").unwrap().get_box() is Some(_),
    content="true",
  )
  inspect(
    laid_out.find_object("B").unwrap().get_box() is Some(_),
    content="true",
  )
}

///|
/// Test: Diamond pattern (A -> B, A -> C, B -> D, C -> D)
test "edge routing: diamond pattern" {
  let graph = @graph.Graph::new("test")
  graph.add_object(@graph.Object::with_label("A", "A"))
  graph.add_object(@graph.Object::with_label("B", "B"))
  graph.add_object(@graph.Object::with_label("C", "C"))
  graph.add_object(@graph.Object::with_label("D", "D"))
  graph.add_edge(@graph.Edge::new(0, "A", "B", false, true))
  graph.add_edge(@graph.Edge::new(1, "A", "C", false, true))
  graph.add_edge(@graph.Edge::new(2, "B", "D", false, true))
  graph.add_edge(@graph.Edge::new(3, "C", "D", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  let mut errors = 0
  for edge in laid_out.edges {
    if edge.route.length() >= 2 {
      let src_obj = laid_out.find_object(edge.src_id).unwrap()
      let src_box = src_obj.get_box().unwrap()
      let p0 = edge.route[0]
      let p1 = edge.route[1]
      let first_horiz = is_horizontal(p0, p1, 2.0)
      let first_vert = is_vertical(p0, p1, 2.0)
      let (on_left, on_right, on_top, on_bottom) = point_on_boundary(
        p0, src_box, 2.0,
      )
      if first_vert && !(on_top || on_bottom) {
        errors = errors + 1
      }
      if first_horiz && !(on_left || on_right) {
        errors = errors + 1
      }
    }
  }
  inspect(errors, content="0")
}
