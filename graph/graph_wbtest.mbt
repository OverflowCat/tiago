///|
test "compile simple object" {
  let ir = @ir.Map::new()
  ir.add_field(@ir.Field::simple("server"))
  let graph = compile("test", ir)
  assert_eq(graph.objects.length(), 1)
  assert_eq(graph.objects[0].id, "server")
  assert_eq(graph.objects[0].label, "server")
}

///|
test "compile object with label" {
  let ir = @ir.Map::new()
  let field = @ir.Field::new(
    "server",
    Some(@ir.Scalar::string("Web Server")),
    None,
    [],
  )
  ir.add_field(field)
  let graph = compile("test", ir)
  assert_eq(graph.objects.length(), 1)
  assert_eq(graph.objects[0].id, "server")
  assert_eq(graph.objects[0].label, "Web Server")
}

///|
test "compile nested objects" {
  let inner = @ir.Map::new()
  inner.add_field(@ir.Field::simple("child1"))
  inner.add_field(@ir.Field::simple("child2"))
  let ir = @ir.Map::new()
  let field = @ir.Field::new(
    "container",
    None,
    Some(@ir.Composite::Map(inner)),
    [],
  )
  ir.add_field(field)
  let graph = compile("test", ir)
  // Container + 2 children = 3 objects
  assert_eq(graph.objects.length(), 3)
  // Container should have children
  let container = graph.find_object("container")
  guard container is Some(c) else { fail("expected container") }
  assert_eq(c.children.length(), 2)
}

///|
test "compile edge" {
  let ir = @ir.Map::new()
  ir.add_field(@ir.Field::simple("a"))
  ir.add_field(@ir.Field::simple("b"))
  let edge = @ir.Edge::new(
    @ir.EdgeID::new(["a"], ["b"], false, true),
    None,
    None,
    [],
  )
  ir.add_edge(edge)
  let graph = compile("test", ir)
  assert_eq(graph.edges.length(), 1)
  assert_eq(graph.edges[0].src_id, "a")
  assert_eq(graph.edges[0].dst_id, "b")
  assert_false(graph.edges[0].src_arrow)
  assert_true(graph.edges[0].dst_arrow)
}

///|
test "compile edge with label" {
  let ir = @ir.Map::new()
  ir.add_field(@ir.Field::simple("x"))
  ir.add_field(@ir.Field::simple("y"))
  let edge = @ir.Edge::new(
    @ir.EdgeID::new(["x"], ["y"], false, true),
    Some(@ir.Scalar::string("connection")),
    None,
    [],
  )
  ir.add_edge(edge)
  let graph = compile("test", ir)
  assert_eq(graph.edges[0].label, "connection")
}

///|
test "compile object with shape" {
  let inner = @ir.Map::new()
  inner.add_field(
    @ir.Field::new("shape", Some(@ir.Scalar::string("cylinder")), None, []),
  )
  let ir = @ir.Map::new()
  let field = @ir.Field::new(
    "database",
    None,
    Some(@ir.Composite::Map(inner)),
    [],
  )
  ir.add_field(field)
  let graph = compile("test", ir)
  assert_eq(graph.objects[0].shape, "cylinder")
}

///|
test "graph operations" {
  let graph = Graph::new("test")
  let obj1 = Object::new("a")
  let obj2 = Object::new("b")
  graph.add_object(obj1)
  graph.add_object(obj2)
  assert_eq(graph.objects.length(), 2)
  // Find object
  guard graph.find_object("a") is Some(found) else { fail("expected object") }
  assert_eq(found.id, "a")
  assert_true(graph.find_object("c") is None)
  // Add edge
  let edge = Edge::new(0, "a", "b", false, true)
  graph.add_edge(edge)
  assert_eq(graph.edges.length(), 1)
  // Find edges
  let from_a = graph.edges_from("a")
  assert_eq(from_a.length(), 1)
  let to_b = graph.edges_to("b")
  assert_eq(to_b.length(), 1)
}

///|
test "object operations" {
  let parent = Object::new("parent")
  let child1 = Object::new("child1")
  let child2 = Object::new("child2")
  parent.add_child(child1)
  parent.add_child(child2)
  assert_true(parent.is_container())
  assert_eq(parent.children.length(), 2)
  guard parent.find_child("child1") is Some(found) else {
    fail("expected child")
  }
  assert_eq(found.id, "child1")
  assert_true(parent.find_child("notfound") is None)
}

///|
test "box operations" {
  let box = Box::new(10.0, 20.0, 100.0, 50.0)
  // Center
  let center = box.center()
  assert_eq(center.x, 60.0)
  assert_eq(center.y, 45.0)
  // Corners
  let tl = box.top_left()
  assert_eq(tl.x, 10.0)
  assert_eq(tl.y, 20.0)
  let br = box.bottom_right()
  assert_eq(br.x, 110.0)
  assert_eq(br.y, 70.0)
  // Contains
  assert_true(box.contains(Point::new(50.0, 40.0)))
  assert_false(box.contains(Point::new(0.0, 0.0)))
  // Intersects
  let box2 = Box::new(50.0, 30.0, 100.0, 50.0)
  assert_true(box.intersects(box2))
  let box3 = Box::new(200.0, 200.0, 10.0, 10.0)
  assert_false(box.intersects(box3))
}

///|
test "point operations" {
  let p1 = Point::new(3.0, 4.0)
  let p2 = Point::new(0.0, 0.0)
  // Distance
  assert_eq(p1.distance(p2), 5.0)
  // Add/sub
  let sum = p1.add(Point::new(1.0, 1.0))
  assert_eq(sum.x, 4.0)
  assert_eq(sum.y, 5.0)
  let diff = p1.sub(Point::new(1.0, 1.0))
  assert_eq(diff.x, 2.0)
  assert_eq(diff.y, 3.0)
  // Scale
  let scaled = p1.scale(2.0)
  assert_eq(scaled.x, 6.0)
  assert_eq(scaled.y, 8.0)
}

///|
test "edge operations" {
  let edge = Edge::new(0, "a", "b", false, true)
  assert_eq(edge.arrow_string(), "->")
  let edge2 = Edge::new(1, "a", "b", true, true)
  assert_eq(edge2.arrow_string(), "<->")
  let edge3 = Edge::new(2, "a", "b", true, false)
  assert_eq(edge3.arrow_string(), "<-")
  let edge4 = Edge::new(3, "a", "b", false, false)
  assert_eq(edge4.arrow_string(), "--")
}

///|
test "style defaults" {
  let style = Style::new()
  assert_true(style.opacity is None)
  assert_true(style.stroke is None)
  assert_true(style.fill is None)
}
