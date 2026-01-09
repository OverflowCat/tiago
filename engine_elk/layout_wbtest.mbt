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
test "layout config defaults" {
  let config = LayoutConfig::new()
  assert_eq(config.horizontal_spacing, 60.0)
  assert_eq(config.vertical_spacing, 60.0)
  assert_eq(config.container_padding, 20.0)
  assert_eq(config.default_width, 100.0)
  assert_eq(config.default_height, 60.0)
}

///|
test "layout config with_spacing" {
  let config = LayoutConfig::with_spacing(100.0, 80.0)
  assert_eq(config.horizontal_spacing, 100.0)
  assert_eq(config.vertical_spacing, 80.0)
}

///|
fn layout_to_graph(
  graph : @graph.Graph,
  config : LayoutConfig,
  direction : Direction,
) -> @graph.Graph raise LayoutError {
  let outputs = layout(graph, config, direction)
  let input = @graph.GraphInput::from_graph(graph)
  let laid_out = @graph.Graph::from_input(input)
  outputs.layout.apply_to_graph(laid_out)
  laid_out
}

///|
test "layout single object" {
  let graph = @graph.Graph::new("test")
  graph.add_object(@graph.Object::new("a"))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  // Object should have a box
  let obj = laid_out.find_object("a").unwrap()
  guard obj.get_box() is Some(box) else { fail("expected box") }
  // Position should be at container padding
  assert_eq(box.x, 20.0)
  assert_eq(box.y, 20.0)
  // Size should be at least default
  assert_true(box.width >= 100.0)
  assert_eq(box.height, 60.0)
}

///|
test "layout multiple objects horizontally" {
  let graph = @graph.Graph::new("test")
  graph.add_object(@graph.Object::new("a"))
  graph.add_object(@graph.Object::new("b"))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Right) catch {
    e => fail("layout failed: \{e}")
  }
  // Both should have boxes
  let obj_a = laid_out.find_object("a").unwrap()
  let obj_b = laid_out.find_object("b").unwrap()
  guard obj_a.get_box() is Some(box_a) else { fail("expected box a") }
  guard obj_b.get_box() is Some(box_b) else { fail("expected box b") }
  // B should be to the right of A (horizontal layout with Direction::Right)
  assert_true(box_b.x > box_a.x)
}

///|
test "layout edge routing" {
  let graph = @graph.Graph::new("test")
  graph.add_object(@graph.Object::new("a"))
  graph.add_object(@graph.Object::new("b"))
  graph.add_edge(@graph.Edge::new(0, "a", "b", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  // Edge should have route points
  let edge = laid_out.get_edges()[0]
  assert_eq(edge.route.length(), 2)
}

///|
test "layout container with children" {
  let graph = @graph.Graph::new("test")
  let parent = @graph.Object::new("parent")
  let child1 = @graph.Object::new("child1")
  let child2 = @graph.Object::new("child2")
  parent.add_child(child1)
  parent.add_child(child2)
  graph.add_object(parent)
  graph.add_object(child1)
  graph.add_object(child2)
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  // Parent should have box large enough for children
  let parent = laid_out.find_object("parent").unwrap()
  let child1 = laid_out.find_object("child1").unwrap()
  let child2 = laid_out.find_object("child2").unwrap()
  guard parent.get_box() is Some(parent_box) else {
    fail("expected parent box")
  }
  guard child1.get_box() is Some(child1_box) else {
    fail("expected child1 box")
  }
  guard child2.get_box() is Some(child2_box) else {
    fail("expected child2 box")
  }
  // Children should be positioned inside parent
  assert_true(child1_box.x >= parent_box.x)
  assert_true(child1_box.y >= parent_box.y)
  // Child2 should be below child1
  assert_true(child2_box.y > child1_box.y)
}

///|
test "estimate label width" {
  let config = LayoutConfig::new()
  // Short label
  let short_width = estimate_label_width("a", config)
  assert_true(short_width >= config.default_width)
  // Longer label should be wider
  let long_width = estimate_label_width("This is a longer label", config)
  assert_true(long_width > short_width)
}

///|
test "find edge intersection" {
  let box = @graph.Box::new(0.0, 0.0, 100.0, 60.0)
  let center = box.center()
  // Target to the right
  let target_right = @graph.Point::new(200.0, 30.0)
  let intersection = find_edge_intersection(box, center, target_right)
  // Should be on the right edge
  assert_eq(intersection.x, 100.0)
  // Target below
  let target_below = @graph.Point::new(50.0, 200.0)
  let intersection2 = find_edge_intersection(box, center, target_below)
  // Should be on the bottom edge
  assert_eq(intersection2.y, 60.0)
}

///|
test "max helper" {
  assert_eq(max(5.0, 10.0), 10.0)
  assert_eq(max(10.0, 5.0), 10.0)
  assert_eq(max(5.0, 5.0), 5.0)
}

///|
test "grid layout with rows" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("grid")
  container.set_grid_rows(2)
  // Add 4 children
  for i in 0..<4 {
    let child = @graph.Object::new("c\{i}")
    container.add_child(child)
    graph.add_object(child)
  }
  graph.add_object(container)
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  // Container should be a grid
  assert_true(container.is_grid_diagram())
  // Children should have boxes
  let container = laid_out.find_object("grid").unwrap()
  for child in container.children {
    let laid_child = laid_out.find_object(child.id).unwrap()
    assert_true(laid_child.get_box() is Some(_))
  }
}

///|
test "grid layout with columns" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("grid")
  container.set_grid_columns(3)
  // Add 6 children
  for i in 0..<6 {
    let child = @graph.Object::new("c\{i}")
    container.add_child(child)
    graph.add_object(child)
  }
  graph.add_object(container)
  let config = LayoutConfig::new()
  ignore(layout_to_graph(graph, config, Direction::Down)) catch {
    e => fail("layout failed: \{e}")
  }
  // Should have 2 rows (6 children / 3 columns)
  let (rows, cols, _) = compute_grid_dimensions(container, 6)
  assert_eq(rows, 2)
  assert_eq(cols, 3)
}

///|
test "grid dimensions calculation" {
  // Test grid-rows only
  let obj1 = @graph.Object::new("test1")
  obj1.set_grid_rows(2)
  let (rows1, cols1, dir1) = compute_grid_dimensions(obj1, 5)
  assert_eq(rows1, 2)
  assert_eq(cols1, 3) // ceil(5/2) = 3
  assert_true(dir1) // row directed
  // Test grid-columns only
  let obj2 = @graph.Object::new("test2")
  obj2.set_grid_columns(3)
  let (rows2, cols2, dir2) = compute_grid_dimensions(obj2, 5)
  assert_eq(rows2, 2) // ceil(5/3) = 2
  assert_eq(cols2, 3)
  assert_true(!dir2) // column directed
  // Test both rows and columns
  let obj3 = @graph.Object::new("test3")
  obj3.set_grid_rows(2)
  obj3.set_grid_columns(3)
  let (rows3, cols3, dir3) = compute_grid_dimensions(obj3, 6)
  assert_eq(rows3, 2)
  assert_eq(cols3, 3)
  assert_true(dir3) // row directed when both specified
}

///|
test "grid cell allocation with spanning" {
  // Create children with various spans
  let child1 = @graph.Object::new("header") // Header spans all 3 columns
  child1.set_grid_column_span(3)
  let child2 = @graph.Object::new("sidebar") // Sidebar spans 2 rows
  child2.set_grid_row_span(2)
  let child3 = @graph.Object::new("content")
  // Default 1x1 span
  let child4 = @graph.Object::new("footer") // Footer spans 2 columns
  child4.set_grid_column_span(2)
  let children = [child1, child2, child3, child4]
  // Allocate cells in a 3x3 grid
  let positions = allocate_grid_cells(children, 3, 3, true)
  // Verify positions
  assert_eq(positions.length(), 4)
  // Header should be at row 0, col 0, spanning 3 columns
  assert_eq(positions[0].row, 0)
  assert_eq(positions[0].col, 0)
  assert_eq(positions[0].col_span, 3)
  assert_eq(positions[0].row_span, 1)
  // Sidebar should be at row 1, col 0, spanning 2 rows
  assert_eq(positions[1].row, 1)
  assert_eq(positions[1].col, 0)
  assert_eq(positions[1].row_span, 2)
  // Content should be at row 1, col 1 (next to sidebar)
  assert_eq(positions[2].row, 1)
  assert_eq(positions[2].col, 1)
  // Footer should be at row 1, col 2 or row 2, col 1
  // (depends on available space after content)
}

///|
test "sum_with_gap" {
  // Empty array
  let empty : Array[Double] = []
  assert_eq(sum_with_gap(empty, 10.0), 0.0)
  // Single value
  let single = [100.0]
  assert_eq(sum_with_gap(single, 10.0), 100.0)
  // Multiple values
  let multiple = [100.0, 100.0, 100.0]
  assert_eq(sum_with_gap(multiple, 10.0), 320.0) // 100 + 10 + 100 + 10 + 100
}

///|
test "is_sequence_diagram" {
  let obj = @graph.Object::new("test")
  assert_true(!is_sequence_diagram(obj)) // default is rectangle
  obj.set_shape("sequence_diagram")
  assert_true(is_sequence_diagram(obj))
}

///|
test "sequence layout basic" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("seq")
  container.set_shape("sequence_diagram")
  // Add actors
  let alice = @graph.Object::new("alice")
  let bob = @graph.Object::new("bob")
  container.add_child(alice)
  container.add_child(bob)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(bob)
  let config = LayoutConfig::new()
  // Run sequence layout
  layout_sequence(container, config)
  // Container should have a box
  assert_true(container.get_box() is Some(_))
  // Actors should have boxes
  assert_true(alice.get_box() is Some(_))
  assert_true(bob.get_box() is Some(_))
  // Alice should be to the left of Bob
  guard alice.get_box() is Some(alice_box) else { fail("expected alice box") }
  guard bob.get_box() is Some(bob_box) else { fail("expected bob box") }
  assert_true(bob_box.x > alice_box.x)
}

///|
test "sequence layout with messages" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("seq")
  container.set_shape("sequence_diagram")
  // Add actors as children of container
  let alice = @graph.Object::new("seq.alice")
  let bob = @graph.Object::new("seq.bob")
  container.add_child(alice)
  container.add_child(bob)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(bob)
  // Add a message edge from alice to bob
  let msg = @graph.Edge::new(0, "seq.alice", "seq.bob", false, true)
  graph.add_edge(msg)
  let config = LayoutConfig::new()
  // Run sequence layout with messages
  layout_sequence_with_messages(container, graph, config)
  // Container should have a box
  assert_true(container.get_box() is Some(_))
  // Message should have route points
  let route = msg.get_route()
  assert_true(route.length() >= 2)
  // Route should be horizontal (same y for start and end)
  if route.length() >= 2 {
    assert_eq(route[0].get_y(), route[1].get_y())
  }
}

///|
test "sequence layout self-referential message" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("seq")
  container.set_shape("sequence_diagram")
  // Add single actor
  let alice = @graph.Object::new("seq.alice")
  container.add_child(alice)
  graph.add_object(container)
  graph.add_object(alice)
  // Add a self-referential message
  let msg = @graph.Edge::new(0, "seq.alice", "seq.alice", false, true)
  graph.add_edge(msg)
  let config = LayoutConfig::new()
  // Run sequence layout with messages
  layout_sequence_with_messages(container, graph, config)
  // Message should have 4 route points (forming a loop)
  let route = msg.get_route()
  assert_true(route.length() == 4)
}

///|
test "sequence layout activation boxes" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("seq")
  container.set_shape("sequence_diagram")
  // Add actors
  let alice = @graph.Object::new("seq.alice")
  let bob = @graph.Object::new("seq.bob")
  container.add_child(alice)
  container.add_child(bob)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(bob)
  // Add messages: alice -> bob, bob -> alice (creates activation box for bob)
  let msg1 = @graph.Edge::new(0, "seq.alice", "seq.bob", false, true)
  let msg2 = @graph.Edge::new(1, "seq.bob", "seq.alice", false, true)
  graph.add_edge(msg1)
  graph.add_edge(msg2)
  let config = LayoutConfig::new()
  // Run sequence layout with activations
  let result = layout_sequence_with_activations(container, graph, config)
  // Should have at least one activation box (for bob when receiving message)
  assert_true(result.activation_boxes.length() >= 1)
  // Check activation box has valid dimensions
  for box in result.activation_boxes {
    let bbox = box.get_box()
    assert_true(bbox.get_width() > 0.0)
    assert_true(bbox.get_height() > 0.0)
  }
}

///|
test "sequence layout self-message activation" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("seq")
  container.set_shape("sequence_diagram")
  // Add single actor
  let alice = @graph.Object::new("seq.alice")
  container.add_child(alice)
  graph.add_object(container)
  graph.add_object(alice)
  // Add a self-referential message
  let msg = @graph.Edge::new(0, "seq.alice", "seq.alice", false, true)
  graph.add_edge(msg)
  let config = LayoutConfig::new()
  // Run sequence layout with activations
  let result = layout_sequence_with_activations(container, graph, config)
  // Self-message should create an activation box
  assert_true(result.activation_boxes.length() == 1)
  // Self-message activation should be short
  let box = result.activation_boxes[0]
  let bbox = box.get_box()
  assert_true(bbox.get_height() <= min_message_distance)
}

///|
test "sequence layout with notes" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("seq")
  container.set_shape("sequence_diagram")
  // Add actors
  let alice = @graph.Object::new("seq.alice")
  let bob = @graph.Object::new("seq.bob")
  // Add a note as a child of alice
  let note = @graph.Object::with_label("seq.alice.note1", "This is a note")
  alice.add_child(note)
  container.add_child(alice)
  container.add_child(bob)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(bob)
  graph.add_object(note)
  // Add a message between alice and bob (so they are recognized as actors)
  let msg = @graph.Edge::new(0, "seq.alice", "seq.bob", false, true)
  graph.add_edge(msg)
  let config = LayoutConfig::new()
  // Run sequence layout with activations (which includes notes)
  let result = layout_sequence_with_activations(container, graph, config)
  // Should have one note
  assert_eq(result.notes.length(), 1)
  // Note should have a bounding box
  let note_result = result.notes[0]
  assert_eq(note_result.text, "This is a note")
  assert_true(note_result.bbox.get_width() > 0.0)
  assert_true(note_result.bbox.get_height() > 0.0)
}

///|
test "sequence layout multiple notes per actor" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("seq")
  container.set_shape("sequence_diagram")
  // Add actors
  let alice = @graph.Object::new("seq.alice")
  // Add two notes as children of alice
  let note1 = @graph.Object::with_label("seq.alice.note1", "First note")
  let note2 = @graph.Object::with_label("seq.alice.note2", "Second note")
  alice.add_child(note1)
  alice.add_child(note2)
  container.add_child(alice)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(note1)
  graph.add_object(note2)
  let config = LayoutConfig::new()
  // Run sequence layout with activations
  let result = layout_sequence_with_activations(container, graph, config)
  // Should have two notes
  assert_eq(result.notes.length(), 2)
  // Notes should be stacked vertically (second note below first)
  assert_true(result.notes[1].bbox.get_y() > result.notes[0].bbox.get_y())
}

///|
test "SequenceNote constructor" {
  let bbox = @graph.Box::new(10.0, 20.0, 100.0, 50.0)
  let note = SequenceNote::new("alice", "Test note", bbox)
  assert_eq(note.actor_id, "alice")
  assert_eq(note.text, "Test note")
  assert_eq(note.bbox.get_x(), 10.0)
  assert_eq(note.bbox.get_y(), 20.0)
}

///|
test "sequence layout with opt group creates fragment" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("seq")
  container.set_shape("sequence_diagram")
  // Add actors
  let alice = @graph.Object::with_label("seq.alice", "Alice")
  let bob = @graph.Object::with_label("seq.bob", "Bob")
  // Add opt group (container with label starting with "opt")
  let opt_group = @graph.Object::with_label("seq.opt", "opt")
  // Add a dummy child to make it a container
  let dummy = @graph.Object::new("seq.opt.dummy")
  opt_group.add_child(dummy)
  container.add_child(alice)
  container.add_child(bob)
  container.add_child(opt_group)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(bob)
  graph.add_object(opt_group)
  graph.add_object(dummy)
  // Add edges - including one "inside" the opt group
  let edge1 = @graph.Edge::new(0, "seq.alice", "seq.bob", false, true)
  edge1.label = "Hello"
  let edge2 = @graph.Edge::new(1, "seq.opt.alice", "seq.opt.bob", false, true)
  edge2.label = "optional message"
  graph.add_edge(edge1)
  graph.add_edge(edge2)
  let config = LayoutConfig::new()
  // Run layout
  layout_sequence_with_activations(container, graph, config) |> ignore
  // Should have a fragment for the opt group
  assert_true(graph.has_fragments())
  assert_eq(graph.sequence_fragments.length(), 1)
  let fragment = graph.sequence_fragments[0]
  assert_eq(fragment.fragment_type, "opt")
}

///|
test "debug: simple linear graph" {
  // Simple case: 3 nodes, linear arrangement
  let graph = @graph.Graph::new("test")

  // 3 nodes with clear parent-child relationship
  graph.add_object(@graph.Object::with_label("A", "Node A"))
  graph.add_object(@graph.Object::with_label("B", "Node B"))
  graph.add_object(@graph.Object::with_label("C", "Node C"))

  // Simple chain: A -> B -> C
  graph.add_edge(@graph.Edge::new(0, "A", "B", false, true))
  graph.add_edge(@graph.Edge::new(1, "B", "C", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  // Get node boxes
  let objA = laid_out.find_object("A").unwrap()
  let objB = laid_out.find_object("B").unwrap()
  let objC = laid_out.find_object("C").unwrap()
  guard objA.get_box() is Some(boxA) else { fail("expected box for A") }
  guard objB.get_box() is Some(boxB) else { fail("expected box for B") }
  guard objC.get_box() is Some(boxC) else { fail("expected box for C") }

  // Debug: print positions
  inspect(
    (boxA.x, boxA.y, boxA.width, boxA.height),
    content="(20, 20, 100, 60)",
  )
  inspect(
    (boxB.x, boxB.y, boxB.width, boxB.height),
    content="(20, 180, 100, 60)",
  )
  inspect(
    (boxC.x, boxC.y, boxC.width, boxC.height),
    content="(20, 340, 100, 60)",
  )

  // In DOWN direction:
  // A should be at top (smallest y)
  // B should be in middle
  // C should be at bottom (largest y)
  assert_true(boxA.y < boxB.y)
  assert_true(boxB.y < boxC.y)

  // No overlaps
  fn boxes_overlap(b1 : @graph.Box, b2 : @graph.Box) -> Bool {
    b1.x < b2.x + b2.width &&
    b1.x + b1.width > b2.x &&
    b1.y < b2.y + b2.height &&
    b1.y + b1.height > b2.y
  }

  assert_false(boxes_overlap(boxA, boxB))
  assert_false(boxes_overlap(boxB, boxC))
  assert_false(boxes_overlap(boxA, boxC))
}

///|
test "debug: cyclic graph with bidirectional edges" {
  // Failing case from property tests: cyclic graph
  let graph = @graph.Graph::new("test")

  // 3 nodes
  graph.add_object(@graph.Object::with_label("5", "o"))
  graph.add_object(@graph.Object::with_label("I", "O"))
  graph.add_object(@graph.Object::with_label("A", "2"))

  // 6 edges (cyclic with bidirectional)
  graph.add_edge(@graph.Edge::new(0, "5", "I", false, true))
  graph.add_edge(@graph.Edge::new(1, "A", "5", false, true))
  graph.add_edge(@graph.Edge::new(2, "5", "A", false, true))
  graph.add_edge(@graph.Edge::new(3, "A", "I", false, true))
  graph.add_edge(@graph.Edge::new(4, "I", "5", false, true))
  graph.add_edge(@graph.Edge::new(5, "5", "I", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  // Get node boxes
  let obj5 = laid_out.find_object("5").unwrap()
  let objI = laid_out.find_object("I").unwrap()
  let objA = laid_out.find_object("A").unwrap()
  guard obj5.get_box() is Some(box5) else { fail("expected box for 5") }
  guard objI.get_box() is Some(boxI) else { fail("expected box for I") }
  guard objA.get_box() is Some(boxA) else { fail("expected box for A") }

  // Debug: print positions
  inspect(
    (box5.x, box5.y, box5.width, box5.height),
    content="(20, 20, 100, 60)",
  )
  inspect(
    (boxI.x, boxI.y, boxI.width, boxI.height),
    content="(20, 180, 100, 60)",
  )
  inspect(
    (boxA.x, boxA.y, boxA.width, boxA.height),
    content="(140, 180, 100, 60)",
  )

  // No overlaps - this is the key constraint
  fn boxes_overlap(b1 : @graph.Box, b2 : @graph.Box) -> Bool {
    b1.x < b2.x + b2.width &&
    b1.x + b1.width > b2.x &&
    b1.y < b2.y + b2.height &&
    b1.y + b1.height > b2.y
  }

  assert_false(boxes_overlap(box5, boxI))
  assert_false(boxes_overlap(box5, boxA))
  assert_false(boxes_overlap(boxI, boxA))
}

///|
test "root-level sequence diagram layout" {
  // Create a graph with root-level sequence diagram (no prefix on actors)
  let graph = @graph.Graph::new("test")
  // Set root to be a sequence diagram
  graph.root.set_shape("sequence_diagram")
  // Add actors (without "root." prefix - just like compiled from D2)
  let alice = @graph.Object::with_label("alice", "Alice")
  let bob = @graph.Object::with_label("bob", "Bob")
  // Make actors children of root
  graph.root.add_child(alice)
  graph.root.add_child(bob)
  graph.add_object(alice)
  graph.add_object(bob)
  // Add a message between actors
  let edge = @graph.Edge::new(0, "alice", "bob", false, true)
  edge.label = "Hello"
  graph.add_edge(edge)
  // Verify preconditions
  assert_true(is_sequence_diagram(graph.root))
  assert_true(graph.root.is_container())
  // Run full layout function
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  // Verify actors have boxes and are arranged horizontally
  let alice = laid_out.find_object("alice").unwrap()
  let bob = laid_out.find_object("bob").unwrap()
  guard alice.get_box() is Some(alice_box) else { fail("expected alice box") }
  guard bob.get_box() is Some(bob_box) else { fail("expected bob box") }
  // Bob should be to the right of Alice (horizontal arrangement)
  assert_true(bob_box.x > alice_box.x)
}
