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

///|
test "compile object with icon" {
  // Create IR with icon field
  let inner = @ir.Map::new()
  inner.add_field(
    @ir.Field::new("icon", Some(@ir.Scalar::string("test-icon.png")), None, []),
  )
  let ir = @ir.Map::new()
  ir.add_field(
    @ir.Field::new("server", None, Some(@ir.Composite::Map(inner)), []),
  )
  let graph = compile("test", ir)
  assert_eq(graph.objects.length(), 1)
  assert_eq(graph.objects[0].icon, Some("test-icon.png"))
}

///|
test "compile object with near" {
  // Create IR with near field
  let inner = @ir.Map::new()
  inner.add_field(
    @ir.Field::new("near", Some(@ir.Scalar::string("top-left")), None, []),
  )
  let ir = @ir.Map::new()
  ir.add_field(
    @ir.Field::new("title", None, Some(@ir.Composite::Map(inner)), []),
  )
  let graph = compile("test", ir)
  assert_eq(graph.objects.length(), 1)
  assert_eq(graph.objects[0].near, Some("top-left"))
}

///|
test "compile object with near object reference" {
  let inner = @ir.Map::new()
  inner.add_field(
    @ir.Field::new("near", Some(@ir.Scalar::string("server")), None, []),
  )
  let ir = @ir.Map::new()
  ir.add_field(@ir.Field::simple("server"))
  ir.add_field(
    @ir.Field::new("info", None, Some(@ir.Composite::Map(inner)), []),
  )
  let graph = compile("test", ir)
  assert_eq(graph.objects.length(), 2)
  if graph.find_object("info") is Some(info) {
    assert_eq(info.near, Some("server"))
  } else {
    fail("expected info object")
  }
}

///|
test "compile layers" {
  // Create IR with layers
  let ir = @ir.Map::new()
  ir.add_field(@ir.Field::simple("server"))
  ir.add_field(@ir.Field::simple("database"))
  // Create layers block
  let layers_map = @ir.Map::new()
  // Layer 1: network
  let network_map = @ir.Map::new()
  network_map.add_field(@ir.Field::simple("router"))
  network_map.add_field(@ir.Field::simple("switch"))
  layers_map.add_field(
    @ir.Field::new("network", None, Some(@ir.Composite::Map(network_map)), []),
  )
  // Layer 2: security
  let security_map = @ir.Map::new()
  security_map.add_field(@ir.Field::simple("firewall"))
  layers_map.add_field(
    @ir.Field::new("security", None, Some(@ir.Composite::Map(security_map)), []),
  )
  ir.add_field(
    @ir.Field::new("layers", None, Some(@ir.Composite::Map(layers_map)), []),
  )
  let graph = compile("test", ir)
  // Base graph should have 2 objects
  assert_eq(graph.objects.length(), 2)
  // Should have 2 layers
  assert_eq(graph.layers.length(), 2)
  assert_eq(graph.layers[0].name, "network")
  assert_eq(graph.layers[0].graph.objects.length(), 2)
  assert_eq(graph.layers[1].name, "security")
  assert_eq(graph.layers[1].graph.objects.length(), 1)
}

///|
test "compile scenarios" {
  // Create IR with scenarios
  let ir = @ir.Map::new()
  ir.add_field(@ir.Field::simple("user"))
  ir.add_field(@ir.Field::simple("app"))
  // Create scenarios block
  let scenarios_map = @ir.Map::new()
  // Scenario 1: happy path
  let happy_map = @ir.Map::new()
  happy_map.add_field(@ir.Field::simple("success"))
  scenarios_map.add_field(
    @ir.Field::new("happy_path", None, Some(@ir.Composite::Map(happy_map)), []),
  )
  // Scenario 2: error path
  let error_map = @ir.Map::new()
  error_map.add_field(@ir.Field::simple("error"))
  error_map.add_field(@ir.Field::simple("retry"))
  scenarios_map.add_field(
    @ir.Field::new("error_path", None, Some(@ir.Composite::Map(error_map)), []),
  )
  ir.add_field(
    @ir.Field::new("scenarios", None, Some(@ir.Composite::Map(scenarios_map)), []),
  )
  let graph = compile("test", ir)
  // Base graph should have 2 objects
  assert_eq(graph.objects.length(), 2)
  // Should have 2 scenarios
  assert_eq(graph.scenarios.length(), 2)
  assert_eq(graph.scenarios[0].name, "happy_path")
  assert_eq(graph.scenarios[0].graph.objects.length(), 1)
  assert_eq(graph.scenarios[1].name, "error_path")
  assert_eq(graph.scenarios[1].graph.objects.length(), 2)
}

///|
test "compile steps" {
  // Create IR with steps
  let ir = @ir.Map::new()
  ir.add_field(@ir.Field::simple("start"))
  // Create steps block
  let steps_map = @ir.Map::new()
  // Step 1
  let step1_map = @ir.Map::new()
  step1_map.add_field(@ir.Field::simple("middle"))
  steps_map.add_field(
    @ir.Field::new("step1", None, Some(@ir.Composite::Map(step1_map)), []),
  )
  // Step 2
  let step2_map = @ir.Map::new()
  step2_map.add_field(@ir.Field::simple("end"))
  steps_map.add_field(
    @ir.Field::new("step2", None, Some(@ir.Composite::Map(step2_map)), []),
  )
  ir.add_field(
    @ir.Field::new("steps", None, Some(@ir.Composite::Map(steps_map)), []),
  )
  let graph = compile("test", ir)
  // Base graph should have 1 object
  assert_eq(graph.objects.length(), 1)
  // Should have 2 steps
  assert_eq(graph.steps.length(), 2)
  assert_eq(graph.steps[0].name, "step1")
  assert_eq(graph.steps[0].graph.objects.length(), 1)
  assert_eq(graph.steps[1].name, "step2")
  assert_eq(graph.steps[1].graph.objects.length(), 1)
}

///|
test "graph has_layers has_scenarios has_steps" {
  let graph = Graph::new("test")
  assert_false(graph.has_layers())
  assert_false(graph.has_scenarios())
  assert_false(graph.has_steps())
  // Add a layer
  let layer_graph = Graph::new("layer1")
  graph.add_layer(Layer::new("layer1", layer_graph))
  assert_true(graph.has_layers())
  // Add a scenario
  let scenario_graph = Graph::new("scenario1")
  graph.add_scenario(Scenario::new("scenario1", scenario_graph))
  assert_true(graph.has_scenarios())
  // Add a step
  let step_graph = Graph::new("step1")
  graph.add_step(Step::new("step1", step_graph))
  assert_true(graph.has_steps())
}

///|
test "compile layers with edges" {
  // Create IR with layers containing edges
  let ir = @ir.Map::new()
  ir.add_field(@ir.Field::simple("main"))
  // Create layers block
  let layers_map = @ir.Map::new()
  // Layer with nodes and edges
  let layer_map = @ir.Map::new()
  layer_map.add_field(@ir.Field::simple("a"))
  layer_map.add_field(@ir.Field::simple("b"))
  // Add edge a -> b
  let edge = @ir.Edge::new(
    @ir.EdgeID::new(["a"], ["b"], false, true),
    Some(@ir.Scalar::string("connects")),
    None,
    [],
  )
  layer_map.add_edge(edge)
  layers_map.add_field(
    @ir.Field::new("connected", None, Some(@ir.Composite::Map(layer_map)), []),
  )
  ir.add_field(
    @ir.Field::new("layers", None, Some(@ir.Composite::Map(layers_map)), []),
  )
  let graph = compile("test", ir)
  // Layer should have edge
  assert_eq(graph.layers.length(), 1)
  assert_eq(graph.layers[0].graph.edges.length(), 1)
  assert_eq(graph.layers[0].graph.edges[0].label, "connects")
}

///|
test "render SVG with layers includes tabs" {
  // Create a graph with layers
  let graph = Graph::new("test")
  let obj = Object::new("main")
  obj.box = Some(Box::new(10.0, 10.0, 100.0, 50.0))
  graph.add_object(obj)
  // Add a layer
  let layer_graph = Graph::new("network")
  let layer_obj = Object::new("router")
  layer_obj.box = Some(Box::new(10.0, 10.0, 100.0, 50.0))
  layer_graph.add_object(layer_obj)
  graph.add_layer(Layer::new("network", layer_graph))
  // Render to SVG
  let config = SvgConfig::new()
  let svg = render_svg(graph, config)
  // Verify tabs are present
  assert_true(svg.contains("layer-tab"))
  assert_true(svg.contains("Base"))
  assert_true(svg.contains("network"))
  // Verify layer groups exist
  assert_true(svg.contains("id=\"base-layer\""))
  assert_true(svg.contains("id=\"layer-0\""))
  // Verify JavaScript is included
  assert_true(svg.contains("switchLayer"))
}

///|
test "render SVG with scenarios includes selector" {
  // Create a graph with scenarios
  let graph = Graph::new("test")
  let obj = Object::new("main")
  obj.box = Some(Box::new(10.0, 10.0, 100.0, 50.0))
  graph.add_object(obj)
  // Add a scenario
  let scenario_graph = Graph::new("happy_path")
  let scenario_obj = Object::new("success")
  scenario_obj.box = Some(Box::new(10.0, 10.0, 100.0, 50.0))
  scenario_graph.add_object(scenario_obj)
  graph.add_scenario(Scenario::new("happy_path", scenario_graph))
  // Render to SVG
  let config = SvgConfig::new()
  let svg = render_svg(graph, config)
  // Verify scenario selector is present
  assert_true(svg.contains("scenario-btn"))
  assert_true(svg.contains("Scenario:"))
  assert_true(svg.contains("happy_path"))
  // Verify scenario groups exist
  assert_true(svg.contains("id=\"base-layer\""))
  assert_true(svg.contains("id=\"scenario-0\""))
  // Verify JavaScript is included
  assert_true(svg.contains("switchScenario"))
}

///|
test "render SVG with steps includes controls" {
  // Create a graph with steps
  let graph = Graph::new("test")
  let obj = Object::new("main")
  obj.box = Some(Box::new(10.0, 10.0, 100.0, 50.0))
  graph.add_object(obj)
  // Add steps
  let step1_graph = Graph::new("step1")
  let step1_obj = Object::new("action1")
  step1_obj.box = Some(Box::new(10.0, 10.0, 100.0, 50.0))
  step1_graph.add_object(step1_obj)
  graph.add_step(Step::new("First", step1_graph))
  let step2_graph = Graph::new("step2")
  let step2_obj = Object::new("action2")
  step2_obj.box = Some(Box::new(10.0, 10.0, 100.0, 50.0))
  step2_graph.add_object(step2_obj)
  graph.add_step(Step::new("Second", step2_graph))
  // Render to SVG
  let config = SvgConfig::new()
  let svg = render_svg(graph, config)
  // Verify step controls are present
  assert_true(svg.contains("step-prev"))
  assert_true(svg.contains("step-play"))
  assert_true(svg.contains("step-next"))
  assert_true(svg.contains("Step:"))
  // Verify step groups exist
  assert_true(svg.contains("id=\"base-layer\""))
  assert_true(svg.contains("id=\"step-0\""))
  assert_true(svg.contains("id=\"step-1\""))
  // Verify JavaScript is included
  assert_true(svg.contains("stepNext"))
  assert_true(svg.contains("stepPrev"))
  assert_true(svg.contains("stepTogglePlay"))
}

///|
test "sequence fragment creation" {
  // Test SequenceFragment and FragmentOperand creation
  let fragment = SequenceFragment::new("alt", 0, 2)
  assert_eq(fragment.fragment_type, "alt")
  assert_eq(fragment.start_index, 0)
  assert_eq(fragment.end_index, 2)
  assert_true(fragment.condition is None)
  assert_true(fragment.bbox is None)
  assert_eq(fragment.operands.length(), 0)
}

///|
test "sequence fragment with condition" {
  let fragment = SequenceFragment::new("loop", 0, 5)
  fragment.condition = Some("[i < 10]")
  assert_eq(fragment.condition, Some("[i < 10]"))
}

///|
test "sequence fragment with operands" {
  let fragment = SequenceFragment::new("alt", 0, 4)
  fragment.operands.push(FragmentOperand::new(Some("[condition1]")))
  fragment.operands.push(FragmentOperand::new(Some("[else]")))
  assert_eq(fragment.operands.length(), 2)
  assert_eq(fragment.operands[0].condition, Some("[condition1]"))
  assert_eq(fragment.operands[1].condition, Some("[else]"))
}

///|
test "graph add and has fragments" {
  let graph = Graph::new("test")
  assert_false(graph.has_fragments())
  let fragment = SequenceFragment::new("opt", 0, 1)
  graph.add_fragment(fragment)
  assert_true(graph.has_fragments())
  assert_eq(graph.sequence_fragments.length(), 1)
}

///|
test "render SVG with sequence fragment" {
  // Create a graph with a sequence fragment
  let graph = Graph::new("test")
  let obj = Object::new("main")
  obj.box = Some(Box::new(10.0, 10.0, 100.0, 100.0))
  graph.add_object(obj)
  // Add a fragment with bbox
  let fragment = SequenceFragment::new("alt", 0, 1)
  fragment.condition = Some("[x > 0]")
  fragment.bbox = Some(Box::new(20.0, 50.0, 200.0, 100.0))
  fragment.operands.push(FragmentOperand::new(Some("[else]")))
  fragment.operands[0].separator_y = 100.0
  graph.add_fragment(fragment)
  // Render to SVG
  let config = SvgConfig::new()
  let svg = render_svg(graph, config)
  // Verify fragment is rendered
  assert_true(svg.contains("ALT"))
  // Note: > is XML-escaped to &gt; in text content
  assert_true(svg.contains("[x &gt; 0]"))
  assert_true(svg.contains("stroke-dasharray"))
}

///|
test "compile sequence diagram with root-level shape" {
  // Create IR with shape: sequence_diagram at root level
  let ir = @ir.Map::new()
  // Add shape field
  let shape_field = @ir.Field::new(
    "shape",
    Some(@ir.Scalar::string("sequence_diagram")),
    None,
    [],
  )
  ir.add_field(shape_field)
  // Add actors
  ir.add_field(
    @ir.Field::new("alice", Some(@ir.Scalar::string("Alice")), None, []),
  )
  ir.add_field(@ir.Field::new("bob", Some(@ir.Scalar::string("Bob")), None, []))
  // Compile
  let graph = compile("test", ir)
  // Verify root has sequence_diagram shape
  assert_eq(graph.root.shape, "sequence_diagram")
  // Verify root has children (actors)
  assert_eq(graph.root.children.length(), 2)
  // Verify root is a container
  assert_true(graph.root.is_container())
}
