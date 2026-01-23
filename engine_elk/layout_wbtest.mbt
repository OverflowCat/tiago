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
  assert_eq(config.horizontal_spacing, 20.0)
  assert_eq(config.vertical_spacing, 70.0)
  assert_eq(config.container_padding, 50.0)
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
fn style_to_input(style : Style) -> @graph.StyleInput {
  @graph.StyleInput::from_parts(
    style.opacity,
    style.stroke,
    style.fill,
    style.stroke_width,
    style.stroke_dash,
    style.border_radius,
    style.shadow,
    style.three_d,
    style.multiple,
    style.font,
    style.font_size,
    style.font_color,
    style.bold,
    style.italic,
    style.underline,
    style.animated,
    style.filled,
    style.double_border,
    style.text_transform,
    style.font_family,
    style.fill_pattern,
    style.sketch,
    style.curved,
  )
}

///|
fn object_to_input(obj : Object) -> @graph.ObjectInput {
  let child_ids : Array[String] = []
  for child in obj.children {
    child_ids.push(child.id)
  }
  let classes : Array[String] = []
  for c in obj.classes {
    classes.push(c)
  }
  @graph.ObjectInput::from_parts(
    obj.id,
    obj.label,
    obj.shape_type,
    style_to_input(obj.style),
    obj.box,
    obj.label_box,
    child_ids,
    obj.z_index,
    obj.icon,
    obj.tooltip,
    obj.link,
    classes,
    obj.grid_rows,
    obj.grid_columns,
    obj.grid_gap,
    obj.horizontal_gap,
    obj.vertical_gap,
    obj.grid_column_span,
    obj.grid_row_span,
    obj.near,
  )
}

///|
fn edge_to_input(edge : Edge) -> @graph.EdgeInput {
  @graph.EdgeInput::from_parts(
    edge.index,
    edge.src_id,
    edge.dst_id,
    edge.src_arrow,
    edge.dst_arrow,
    edge.src_arrowhead,
    edge.dst_arrowhead,
    edge.src_anchor,
    edge.dst_anchor,
    edge.label,
    style_to_input(edge.style),
    [],
    edge.bend_points,
    edge.is_curve,
    edge.z_index,
    edge.reference_count,
    edge.label_box,
    edge.src_column_index,
    edge.dst_column_index,
  )
}

///|
fn fragment_to_input(
  fragment : SequenceFragment,
) -> @graph.SequenceFragmentInput {
  let operands : Array[@graph.FragmentOperandInput] = []
  for op in fragment.operands {
    operands.push(@graph.FragmentOperandInput::new(op.condition))
  }
  @graph.SequenceFragmentInput::new(
    fragment.fragment_type,
    fragment.condition,
    fragment.start_index,
    fragment.end_index,
    operands,
  )
}

///|
fn graph_to_input(graph : Graph) -> @graph.GraphInput {
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    objects.push(object_to_input(obj))
  }
  let edges : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    edges.push(edge_to_input(edge))
  }
  let fragments : Array[@graph.SequenceFragmentInput] = []
  for fragment in graph.sequence_fragments {
    fragments.push(fragment_to_input(fragment))
  }
  @graph.GraphInput::from_parts(
    graph.name,
    object_to_input(graph.root),
    objects,
    edges,
    fragments,
    [],
    [],
    [],
    [],
    [],
    [],
    graph.legend,
  )
}

///|
fn new_graph(name : String) -> Graph {
  Graph::from_input(@graph.GraphInput::new(name))
}

///|
fn new_graph_with_root_shape(name : String, shape : String) -> Graph {
  let root = @graph.ObjectInput::from_parts(
    "root",
    "root",
    ShapeType::from_string(shape),
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
  )
  let input = @graph.GraphInput::from_parts(
    name,
    root,
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    None,
  )
  Graph::from_input(input)
}

///|
fn object_with_label(id : String, label : String) -> Object {
  let obj = Object::new(id)
  obj.label = label
  obj
}

///|
fn with_shape(obj : Object, shape : String) -> Object {
  { ..obj, shape_type: ShapeType::from_string(shape) }
}

///|
fn with_grid_rows(obj : Object, rows : Int) -> Object {
  { ..obj, grid_rows: Some(rows) }
}

///|
fn with_grid_columns(obj : Object, columns : Int) -> Object {
  { ..obj, grid_columns: Some(columns) }
}

///|
fn with_grid_column_span(obj : Object, span : Int) -> Object {
  { ..obj, grid_column_span: Some(span) }
}

///|
fn with_grid_row_span(obj : Object, span : Int) -> Object {
  { ..obj, grid_row_span: Some(span) }
}

///|
fn layout_to_graph(
  graph : Graph,
  config : LayoutConfig,
  direction : Direction,
) -> Graph raise LayoutError {
  let input = graph_to_input(graph)
  let patch = ElkEngine::new().layout(input, config, direction)
  let laid_out_input = @graph.apply_layout(input, patch)
  Graph::from_input(laid_out_input)
}

///|
#warnings("-unused_value")
fn apply_layout_result_for_layout(
  _patch : @graph.LayoutPatch,
  _graph : Graph,
) -> Unit {
  ()
}

///|
test "layout single object" {
  let graph = new_graph("test")
  graph.add_object(Object::new("a"))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  // Object should have a box
  let obj = laid_out.find_object("a").unwrap()
  guard obj.box is Some(box) else { fail("expected box") }
  // D2 uses ELK layered's default graph padding (12) for the root graph.
  let eps = 1.0
  assert_true((box.x - 12.0).abs() <= eps)
  assert_true((box.y - 12.0).abs() <= eps)
  // Size should reflect D2 size-to-content defaults.
  assert_eq(box.width, 53.0)
  assert_eq(box.height, 66.0)
}

///|
test "layout multiple objects horizontally" {
  let graph = new_graph("test")
  graph.add_object(Object::new("a"))
  graph.add_object(Object::new("b"))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Right) catch {
    e => fail("layout failed: \{e}")
  }
  // Both should have boxes
  let obj_a = laid_out.find_object("a").unwrap()
  let obj_b = laid_out.find_object("b").unwrap()
  guard obj_a.box is Some(box_a) else { fail("expected box a") }
  guard obj_b.box is Some(box_b) else { fail("expected box b") }
  // B should be to the right of A (horizontal layout with Direction::Right)
  assert_true(box_b.x > box_a.x)
}

///|
test "layout edge routing" {
  let graph = new_graph("test")
  graph.add_object(Object::new("a"))
  graph.add_object(Object::new("b"))
  graph.add_edge(Edge::new(0, "a", "b", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  // Edge should have route points
  let edge = laid_out.edges[0]
  assert_eq(edge.route.length(), 2)
}

///|
test "layout container with children" {
  let graph = new_graph("test")
  let parent = Object::new("parent")
  let child1 = Object::new("child1")
  let child2 = Object::new("child2")
  parent.children.push(child1)
  parent.children.push(child2)
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
  guard parent.box is Some(parent_box) else { fail("expected parent box") }
  guard child1.box is Some(child1_box) else { fail("expected child1 box") }
  guard child2.box is Some(childiago_box) else { fail("expected child2 box") }
  // Children should be positioned inside parent
  assert_true(child1_box.x >= parent_box.x)
  assert_true(child1_box.y >= parent_box.y)
  // Child2 should be to the right of child1 (D2/ELK packs no-edge children in one layer)
  assert_true(childiago_box.x > child1_box.x)
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
  let graph = new_graph("test")
  let container = with_grid_rows(Object::new("grid"), 2)
  // Add 4 children
  for i in 0..<4 {
    let child = Object::new("c\{i}")
    container.children.push(child)
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
    assert_true(laid_child.box is Some(_))
  }
}

///|
test "grid layout with columns" {
  let graph = new_graph("test")
  let container = with_grid_columns(Object::new("grid"), 3)
  // Add 6 children
  for i in 0..<6 {
    let child = Object::new("c\{i}")
    container.children.push(child)
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
  let obj1 = with_grid_rows(Object::new("test1"), 2)
  let (rows1, cols1, dir1) = compute_grid_dimensions(obj1, 5)
  assert_eq(rows1, 2)
  assert_eq(cols1, 3) // ceil(5/2) = 3
  assert_true(dir1) // row directed
  // Test grid-columns only
  let obj2 = with_grid_columns(Object::new("test2"), 3)
  let (rows2, cols2, dir2) = compute_grid_dimensions(obj2, 5)
  assert_eq(rows2, 2) // ceil(5/3) = 2
  assert_eq(cols2, 3)
  assert_true(!dir2) // column directed
  // Test both rows and columns
  let obj3 = with_grid_columns(with_grid_rows(Object::new("test3"), 2), 3)
  let (rows3, cols3, dir3) = compute_grid_dimensions(obj3, 6)
  assert_eq(rows3, 2)
  assert_eq(cols3, 3)
  assert_true(dir3) // row directed when both specified
}

///|
test "grid cell allocation with spanning" {
  // Create children with various spans
  let child1 = with_grid_column_span(Object::new("header"), 3)
  let child2 = with_grid_row_span(Object::new("sidebar"), 2)
  let child3 = Object::new("content")
  let child4 = with_grid_column_span(Object::new("footer"), 2)
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
  let obj = Object::new("test")
  assert_true(!is_sequence_diagram(obj)) // default is rectangle
  let obj = with_shape(obj, "sequence_diagram")
  assert_true(is_sequence_diagram(obj))
}

///|
test "sequence layout basic" {
  let graph = new_graph("test")
  let container = Object::new("seq")
  let container = with_shape(container, "sequence_diagram")
  // Add actors
  let alice = Object::new("alice")
  let bob = Object::new("bob")
  container.children.push(alice)
  container.children.push(bob)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(bob)
  let config = LayoutConfig::new()
  // Run sequence layout
  layout_sequence_with_activations(container, graph, config) |> ignore
  // Container should have a box
  assert_true(container.box is Some(_))
  // Actors should have boxes
  assert_true(alice.box is Some(_))
  assert_true(bob.box is Some(_))
  // Alice should be to the left of Bob
  guard alice.box is Some(alice_box) else { fail("expected alice box") }
  guard bob.box is Some(bob_box) else { fail("expected bob box") }
  assert_true(bob_box.x > alice_box.x)
}

///|
test "sequence layout with messages" {
  let graph = new_graph("test")
  let container = Object::new("seq")
  let container = with_shape(container, "sequence_diagram")
  // Add actors as children of container
  let alice = Object::new("seq.alice")
  let bob = Object::new("seq.bob")
  container.children.push(alice)
  container.children.push(bob)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(bob)
  // Add a message edge from alice to bob
  let msg = Edge::new(0, "seq.alice", "seq.bob", false, true)
  graph.add_edge(msg)
  let config = LayoutConfig::new()
  // Run sequence layout with messages
  layout_sequence_with_activations(container, graph, config) |> ignore
  // Container should have a box
  assert_true(container.box is Some(_))
  // Message should have route points
  let route = msg.route
  assert_true(route.length() >= 2)
  // Route should be horizontal (same y for start and end)
  if route.length() >= 2 {
    assert_eq(route[0].get_y(), route[1].get_y())
  }
}

///|
test "sequence layout self-referential message" {
  let graph = new_graph("test")
  let container = Object::new("seq")
  let container = with_shape(container, "sequence_diagram")
  // Add single actor
  let alice = Object::new("seq.alice")
  container.children.push(alice)
  graph.add_object(container)
  graph.add_object(alice)
  // Add a self-referential message
  let msg = Edge::new(0, "seq.alice", "seq.alice", false, true)
  graph.add_edge(msg)
  let config = LayoutConfig::new()
  // Run sequence layout with messages
  layout_sequence_with_activations(container, graph, config) |> ignore
  // Message should have 4 route points (forming a loop)
  let route = msg.route
  assert_true(route.length() == 4)
}

///|
test "sequence layout activation boxes" {
  let graph = new_graph("test")
  let container = Object::new("seq")
  let container = with_shape(container, "sequence_diagram")
  // Add actors
  let alice = Object::new("seq.alice")
  let bob = Object::new("seq.bob")
  container.children.push(alice)
  container.children.push(bob)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(bob)
  // Add messages: alice -> bob, bob -> alice (creates activation box for bob)
  let msg1 = Edge::new(0, "seq.alice", "seq.bob", false, true)
  let msg2 = Edge::new(1, "seq.bob", "seq.alice", false, true)
  graph.add_edge(msg1)
  graph.add_edge(msg2)
  let config = LayoutConfig::new()
  // Run sequence layout with activations
  layout_sequence_with_activations(container, graph, config) |> ignore

  // Activation boxes are shifted into the graph payload (after container padding
  // is applied). Assert invariant placement relative to actors/messages rather
  // than hard-coding absolute coordinates.
  assert_eq(graph.activation_boxes.length(), 2)
  let by_actor : Map[String, @graph.Box] = {}
  for pair in graph.activation_boxes {
    let (id, b) = pair
    by_actor[id] = b
  }
  let alice_ab = by_actor.get("seq.alice").unwrap()
  let bob_ab = by_actor.get("seq.bob").unwrap()
  guard alice.box is Some(alice_box) else { fail("expected alice box") }
  guard bob.box is Some(bob_box) else { fail("expected bob box") }
  let alice_center_x = alice_box.get_x() + alice_box.get_width() / 2.0
  let bob_center_x = bob_box.get_x() + bob_box.get_width() / 2.0
  assert_eq(alice_ab.get_width(), 16.0)
  assert_eq(bob_ab.get_width(), 16.0)
  assert_eq(alice_ab.get_x(), alice_center_x - 8.0)
  assert_eq(bob_ab.get_x(), bob_center_x - 8.0)

  // The activation for the callee starts at the message Y; both end at the same
  // final message offset.
  let y1 = msg1.route[0].get_y()
  let y2 = msg2.route[0].get_y()
  assert_eq(bob_ab.get_y(), y1)
  assert_eq(alice_ab.get_y(), y2)
  assert_true(bob_ab.get_height() > alice_ab.get_height())
  assert_eq(
    bob_ab.get_y() + bob_ab.get_height(),
    alice_ab.get_y() + alice_ab.get_height(),
  )
}

///|
test "sequence layout with notes" {
  let graph = new_graph("test")
  let container = Object::new("seq")
  let container = with_shape(container, "sequence_diagram")
  // Add actors
  let alice = Object::new("seq.alice")
  let bob = Object::new("seq.bob")
  // Add a note as a child of alice
  let note = object_with_label("seq.alice.note1", "This is a note")
  alice.children.push(note)
  container.children.push(alice)
  container.children.push(bob)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(bob)
  graph.add_object(note)
  // Add a message between alice and bob (so they are recognized as actors)
  let msg = Edge::new(0, "seq.alice", "seq.bob", false, true)
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
  let graph = new_graph("test")
  let container = Object::new("seq")
  let container = with_shape(container, "sequence_diagram")
  // Add actors
  let alice = Object::new("seq.alice")
  // Add two notes as children of alice
  let note1 = object_with_label("seq.alice.note1", "First note")
  let note2 = object_with_label("seq.alice.note2", "Second note")
  alice.children.push(note1)
  alice.children.push(note2)
  container.children.push(alice)
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
  let graph = new_graph("test")
  let container = Object::new("seq")
  let container = with_shape(container, "sequence_diagram")
  // Add actors
  let alice = object_with_label("seq.alice", "Alice")
  let bob = object_with_label("seq.bob", "Bob")
  // Add opt group (container with label starting with "opt")
  let opt_group = object_with_label("seq.opt", "opt")
  // Add a dummy child to make it a container
  let dummy = Object::new("seq.opt.dummy")
  opt_group.children.push(dummy)
  container.children.push(alice)
  container.children.push(bob)
  container.children.push(opt_group)
  graph.add_object(container)
  graph.add_object(alice)
  graph.add_object(bob)
  graph.add_object(opt_group)
  graph.add_object(dummy)
  // Add edges - including one "inside" the opt group
  let edge1 = {
    ..Edge::new(0, "seq.alice", "seq.bob", false, true),
    label: "Hello",
  }
  let edge2 = {
    ..Edge::new(1, "seq.opt.alice", "seq.opt.bob", false, true),
    label: "optional message",
  }
  graph.add_edge(edge1)
  graph.add_edge(edge2)
  let config = LayoutConfig::new()
  // Run layout
  layout_sequence_with_activations(container, graph, config) |> ignore
  // Should have a fragment for the opt group
  assert_true(graph.sequence_fragments.length() > 0)
  assert_eq(graph.sequence_fragments.length(), 1)
  let fragment = graph.sequence_fragments[0]
  assert_eq(fragment.fragment_type, "opt")
}

///|
test "debug: simple linear graph" {
  // Simple case: 3 nodes, linear arrangement
  let graph = new_graph("test")

  // 3 nodes with clear parent-child relationship
  graph.add_object(object_with_label("A", "Node A"))
  graph.add_object(object_with_label("B", "Node B"))
  graph.add_object(object_with_label("C", "Node C"))

  // Simple chain: A -> B -> C
  graph.add_edge(Edge::new(0, "A", "B", false, true))
  graph.add_edge(Edge::new(1, "B", "C", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  // Get node boxes
  let objA = laid_out.find_object("A").unwrap()
  let objB = laid_out.find_object("B").unwrap()
  let objC = laid_out.find_object("C").unwrap()
  guard objA.box is Some(boxA) else { fail("expected box for A") }
  guard objB.box is Some(boxB) else { fail("expected box for B") }
  guard objC.box is Some(boxC) else { fail("expected box for C") }

  // Debug: print positions
  inspect((boxA.x, boxA.y, boxA.width, boxA.height), content="(12, 12, 94, 66)")
  inspect(
    (boxB.x, boxB.y, boxB.width, boxB.height),
    content="(13, 148, 92, 66)",
  )
  inspect(
    (boxC.x, boxC.y, boxC.width, boxC.height),
    content="(13, 284, 92, 66)",
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
  let graph = new_graph("test")

  // 3 nodes
  graph.add_object(object_with_label("5", "o"))
  graph.add_object(object_with_label("I", "O"))
  graph.add_object(object_with_label("A", "2"))

  // 6 edges (cyclic with bidirectional)
  graph.add_edge(Edge::new(0, "5", "I", false, true))
  graph.add_edge(Edge::new(1, "A", "5", false, true))
  graph.add_edge(Edge::new(2, "5", "A", false, true))
  graph.add_edge(Edge::new(3, "A", "I", false, true))
  graph.add_edge(Edge::new(4, "I", "5", false, true))
  graph.add_edge(Edge::new(5, "5", "I", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  // Get node boxes
  let obj5 = laid_out.find_object("5").unwrap()
  let objI = laid_out.find_object("I").unwrap()
  let objA = laid_out.find_object("A").unwrap()
  guard obj5.box is Some(box5) else { fail("expected box for 5") }
  guard objI.box is Some(boxI) else { fail("expected box for I") }
  guard objA.box is Some(boxA) else { fail("expected box for A") }

  // Debug: print positions
  inspect(
    (box5.x, box5.y, box5.width, box5.height),
    content="(32, 12, 120, 66)",
  )
  inspect(
    (boxI.x, boxI.y, boxI.width, boxI.height),
    content="(72, 294, 120, 66)",
  )
  inspect(
    (boxA.x, boxA.y, boxA.width, boxA.height),
    content="(52, 148, 80, 66)",
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
}

///|
test "root-level sequence diagram layout" {
  // Create a graph with root-level sequence diagram (no prefix on actors)
  let graph = new_graph_with_root_shape("test", "sequence_diagram")
  // Add actors (without "root." prefix - just like compiled from diago)
  let alice = object_with_label("alice", "Alice")
  let bob = object_with_label("bob", "Bob")
  // Make actors children of root
  graph.root.children.push(alice)
  graph.root.children.push(bob)
  graph.add_object(alice)
  graph.add_object(bob)
  // Add a message between actors
  let edge = { ..Edge::new(0, "alice", "bob", false, true), label: "Hello" }
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
  guard alice.box is Some(alice_box) else { fail("expected alice box") }
  guard bob.box is Some(bob_box) else { fail("expected bob box") }
  // Bob should be to the right of Alice (horizontal arrangement)
  assert_true(bob_box.x > alice_box.x)
}
