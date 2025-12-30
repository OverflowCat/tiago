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
