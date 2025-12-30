///|
test "render config defaults" {
  let config = RenderConfig::new()
  assert_eq(config.padding, 20.0)
  assert_eq(config.font_size, 14)
  assert_eq(config.default_stroke_width, 2.0)
  assert_eq(config.arrow_size, 10.0)
}

///|
test "render empty graph" {
  let graph = @graph.Graph::new("test")
  let config = RenderConfig::new()
  let svg = render(graph, config)
  assert_true(svg.contains("<?xml"))
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))
  assert_true(svg.contains("<defs>"))
}

///|
test "render single object" {
  let graph = @graph.Graph::new("test")
  let obj = @graph.Object::new("server")
  obj.set_box(@graph.Box::new(20.0, 20.0, 100.0, 60.0))
  graph.add_object(obj)
  let config = RenderConfig::new()
  let svg = render(graph, config)
  assert_true(svg.contains("<rect"))
  assert_true(svg.contains("server"))
}

///|
test "render object with circle shape" {
  let graph = @graph.Graph::new("test")
  let obj = @graph.Object::new("node")
  obj.set_shape("circle")
  obj.set_box(@graph.Box::new(20.0, 20.0, 80.0, 80.0))
  graph.add_object(obj)
  let config = RenderConfig::new()
  let svg = render(graph, config)
  assert_true(svg.contains("<ellipse"))
}

///|
test "render object with cylinder shape" {
  let graph = @graph.Graph::new("test")
  let obj = @graph.Object::new("db")
  obj.set_shape("cylinder")
  obj.set_box(@graph.Box::new(20.0, 20.0, 80.0, 100.0))
  graph.add_object(obj)
  let config = RenderConfig::new()
  let svg = render(graph, config)
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("<ellipse"))
}

///|
test "render object with diamond shape" {
  let graph = @graph.Graph::new("test")
  let obj = @graph.Object::new("decision")
  obj.set_shape("diamond")
  obj.set_box(@graph.Box::new(20.0, 20.0, 80.0, 80.0))
  graph.add_object(obj)
  let config = RenderConfig::new()
  let svg = render(graph, config)
  assert_true(svg.contains("<polygon"))
}

///|
test "render edge" {
  let graph = @graph.Graph::new("test")
  let obj_a = @graph.Object::new("a")
  let obj_b = @graph.Object::new("b")
  obj_a.set_box(@graph.Box::new(20.0, 20.0, 100.0, 60.0))
  obj_b.set_box(@graph.Box::new(200.0, 20.0, 100.0, 60.0))
  graph.add_object(obj_a)
  graph.add_object(obj_b)
  let edge = @graph.Edge::new(0, "a", "b", false, true)
  edge.add_route_point(@graph.Point::new(120.0, 50.0))
  edge.add_route_point(@graph.Point::new(200.0, 50.0))
  graph.add_edge(edge)
  let config = RenderConfig::new()
  let svg = render(graph, config)
  assert_true(svg.contains("marker-end"))
  assert_true(svg.contains("<path d=\"M"))
}

///|
test "render edge with label" {
  let graph = @graph.Graph::new("test")
  let obj_a = @graph.Object::new("a")
  let obj_b = @graph.Object::new("b")
  obj_a.set_box(@graph.Box::new(20.0, 20.0, 100.0, 60.0))
  obj_b.set_box(@graph.Box::new(200.0, 20.0, 100.0, 60.0))
  graph.add_object(obj_a)
  graph.add_object(obj_b)
  let edge = @graph.Edge::new(0, "a", "b", false, true)
  edge.set_label("connects to")
  edge.add_route_point(@graph.Point::new(120.0, 50.0))
  edge.add_route_point(@graph.Point::new(200.0, 50.0))
  graph.add_edge(edge)
  let config = RenderConfig::new()
  let svg = render(graph, config)
  assert_true(svg.contains("connects to"))
}

///|
test "escape xml special chars" {
  let result = escape_xml("<hello & \"world\">")
  assert_eq(result, "&lt;hello &amp; &quot;world&quot;&gt;")
}

///|
test "render bidirectional edge" {
  let graph = @graph.Graph::new("test")
  let obj_a = @graph.Object::new("a")
  let obj_b = @graph.Object::new("b")
  obj_a.set_box(@graph.Box::new(20.0, 20.0, 100.0, 60.0))
  obj_b.set_box(@graph.Box::new(200.0, 20.0, 100.0, 60.0))
  graph.add_object(obj_a)
  graph.add_object(obj_b)
  let edge = @graph.Edge::new(0, "a", "b", true, true)
  edge.add_route_point(@graph.Point::new(120.0, 50.0))
  edge.add_route_point(@graph.Point::new(200.0, 50.0))
  graph.add_edge(edge)
  let config = RenderConfig::new()
  let svg = render(graph, config)
  assert_true(svg.contains("marker-end"))
  assert_true(svg.contains("marker-start"))
}
