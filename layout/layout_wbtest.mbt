///|
test "layout config defaults" {
  let config = LayoutConfig::new()
  assert_eq(config.horizontal_spacing, 60.0)
  assert_eq(config.vertical_spacing, 40.0)
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
test "layout single object" {
  let graph = @graph.Graph::new("test")
  let obj = @graph.Object::new("a")
  graph.add_object(obj)
  let config = LayoutConfig::new()
  layout(graph, config, Direction::Down)
  // Object should have a box
  guard obj.box is Some(box) else { fail("expected box") }
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
  let obj_a = @graph.Object::new("a")
  let obj_b = @graph.Object::new("b")
  graph.add_object(obj_a)
  graph.add_object(obj_b)
  let config = LayoutConfig::new()
  layout(graph, config, Direction::Right)
  // Both should have boxes
  guard obj_a.box is Some(box_a) else { fail("expected box a") }
  guard obj_b.box is Some(box_b) else { fail("expected box b") }
  // B should be to the right of A (horizontal layout with Direction::Right)
  assert_true(box_b.x > box_a.x)
}

///|
test "layout edge routing" {
  let graph = @graph.Graph::new("test")
  let obj_a = @graph.Object::new("a")
  let obj_b = @graph.Object::new("b")
  graph.add_object(obj_a)
  graph.add_object(obj_b)
  let edge = @graph.Edge::new(0, "a", "b", false, true)
  graph.add_edge(edge)
  let config = LayoutConfig::new()
  layout(graph, config, Direction::Down)
  // Edge should have route points
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
  layout(graph, config, Direction::Down)
  // Parent should have box large enough for children
  guard parent.box is Some(parent_box) else { fail("expected parent box") }
  guard child1.box is Some(child1_box) else { fail("expected child1 box") }
  guard child2.box is Some(child2_box) else { fail("expected child2 box") }
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
  container.grid_rows = Some(2)
  // Add 4 children
  for i in 0..<4 {
    let child = @graph.Object::new("c\{i}")
    container.add_child(child)
    graph.add_object(child)
  }
  graph.add_object(container)
  let config = LayoutConfig::new()
  layout(graph, config, Direction::Down)
  // Container should be a grid
  assert_true(container.is_grid_diagram())
  // Children should have boxes
  for child in container.children {
    assert_true(child.box is Some(_))
  }
}

///|
test "grid layout with columns" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("grid")
  container.grid_columns = Some(3)
  // Add 6 children
  for i in 0..<6 {
    let child = @graph.Object::new("c\{i}")
    container.add_child(child)
    graph.add_object(child)
  }
  graph.add_object(container)
  let config = LayoutConfig::new()
  layout(graph, config, Direction::Down)
  // Should have 2 rows (6 children / 3 columns)
  let (rows, cols, _) = compute_grid_dimensions(container, 6)
  assert_eq(rows, 2)
  assert_eq(cols, 3)
}

///|
test "grid dimensions calculation" {
  // Test grid-rows only
  let obj1 = @graph.Object::new("test1")
  obj1.grid_rows = Some(2)
  let (rows1, cols1, dir1) = compute_grid_dimensions(obj1, 5)
  assert_eq(rows1, 2)
  assert_eq(cols1, 3) // ceil(5/2) = 3
  assert_true(dir1) // row directed
  // Test grid-columns only
  let obj2 = @graph.Object::new("test2")
  obj2.grid_columns = Some(3)
  let (rows2, cols2, dir2) = compute_grid_dimensions(obj2, 5)
  assert_eq(rows2, 2) // ceil(5/3) = 2
  assert_eq(cols2, 3)
  assert_true(!dir2) // column directed
  // Test both rows and columns
  let obj3 = @graph.Object::new("test3")
  obj3.grid_rows = Some(2)
  obj3.grid_columns = Some(3)
  let (rows3, cols3, dir3) = compute_grid_dimensions(obj3, 6)
  assert_eq(rows3, 2)
  assert_eq(cols3, 3)
  assert_true(dir3) // row directed when both specified
}

///|
test "grid cell allocation with spanning" {
  // Create children with various spans
  let child1 = @graph.Object::new("header")
  child1.set_grid_column_span(3) // Header spans all 3 columns
  let child2 = @graph.Object::new("sidebar")
  child2.set_grid_row_span(2) // Sidebar spans 2 rows
  let child3 = @graph.Object::new("content")
  // Default 1x1 span
  let child4 = @graph.Object::new("footer")
  child4.set_grid_column_span(2) // Footer spans 2 columns
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
  obj.shape = "sequence_diagram"
  assert_true(is_sequence_diagram(obj))
}

///|
test "sequence layout basic" {
  let graph = @graph.Graph::new("test")
  let container = @graph.Object::new("seq")
  container.shape = "sequence_diagram"
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
  assert_true(container.box is Some(_))
  // Actors should have boxes
  assert_true(alice.box is Some(_))
  assert_true(bob.box is Some(_))
  // Alice should be to the left of Bob
  guard alice.box is Some(alice_box) else { fail("expected alice box") }
  guard bob.box is Some(bob_box) else { fail("expected bob box") }
  assert_true(bob_box.x > alice_box.x)
}
