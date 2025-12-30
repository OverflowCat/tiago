///|
/// Integration tests: D2 source to SVG and ASCII

///|
/// Compile D2 source to SVG
fn compile(source : String) -> Result[String, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph = @graph.compile("test", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @layout.LayoutConfig::new()
  @layout.layout(graph, config, @layout.Direction::Down)
  let render_config = @graph.SvgConfig::new()
  Ok(@graph.render_svg(graph, render_config))
}

// =============================================================================
// Basic object tests
// =============================================================================

///|
test "simple object" {
  let svg = compile("server").unwrap()
  assert_true(svg.contains("<rect"))
  assert_true(svg.contains("server"))
}

///|
test "object with label" {
  let svg = compile("server: Web Server").unwrap()
  assert_true(svg.contains("<rect"))
  assert_true(svg.contains("Web Server"))
}

///|
test "multiple objects" {
  let source =
    #|a
    #|b
    #|c
  let svg = compile(source).unwrap()
  assert_true(svg.contains(">a<"))
  assert_true(svg.contains(">b<"))
  assert_true(svg.contains(">c<"))
}

// =============================================================================
// Shape tests
// =============================================================================

///|
test "circle shape" {
  let source =
    #|node {
    #|  shape: circle
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<ellipse"))
}

///|
test "oval shape" {
  let source =
    #|node {
    #|  shape: oval
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<ellipse"))
}

///|
test "cylinder shape" {
  let source =
    #|db {
    #|  shape: cylinder
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "diamond shape" {
  let source =
    #|decision {
    #|  shape: diamond
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<polygon"))
}

///|
test "hexagon shape" {
  let source =
    #|process {
    #|  shape: hexagon
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<polygon"))
}

///|
test "octagon shape" {
  let source =
    #|stop {
    #|  shape: octagon
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<polygon"))
}

///|
test "parallelogram shape" {
  let source =
    #|input {
    #|  shape: parallelogram
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<polygon"))
}

///|
test "person shape" {
  let source =
    #|user {
    #|  shape: person
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<circle"))
  assert_true(svg.contains("<line"))
}

///|
test "cloud shape" {
  let source =
    #|aws {
    #|  shape: cloud
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("C ")) // bezier curve
}

///|
test "document shape" {
  let source =
    #|doc {
    #|  shape: document
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "queue shape" {
  let source =
    #|queue {
    #|  shape: queue
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "stored_data shape" {
  let source =
    #|storage {
    #|  shape: stored_data
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "page shape" {
  let source =
    #|paper {
    #|  shape: page
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "package shape" {
  let source =
    #|pkg {
    #|  shape: package
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "step shape" {
  let source =
    #|process {
    #|  shape: step
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<polygon"))
}

///|
test "callout shape" {
  let source =
    #|note {
    #|  shape: callout
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

// =============================================================================
// Edge tests
// =============================================================================

///|
test "simple edge" {
  let svg = compile("a -> b").unwrap()
  assert_true(svg.contains("marker-end"))
  assert_true(svg.contains(">a<"))
  assert_true(svg.contains(">b<"))
}

///|
test "edge with label" {
  let svg = compile("a -> b: connects").unwrap()
  assert_true(svg.contains("connects"))
}

///|
test "bidirectional edge" {
  let svg = compile("a <-> b").unwrap()
  assert_true(svg.contains("marker-end"))
  assert_true(svg.contains("marker-start"))
}

///|
test "reverse edge" {
  let svg = compile("a <- b").unwrap()
  assert_true(svg.contains("marker-start"))
}

///|
test "line without arrows" {
  let svg = compile("a -- b").unwrap()
  assert_true(svg.contains(">a<"))
  assert_true(svg.contains(">b<"))
}

///|
test "edge chain" {
  let svg = compile("a -> b -> c").unwrap()
  assert_true(svg.contains(">a<"))
  assert_true(svg.contains(">b<"))
  assert_true(svg.contains(">c<"))
}

// =============================================================================
// Nested object tests
// =============================================================================

///|
test "nested object" {
  let source =
    #|container {
    #|  child
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("container"))
  assert_true(svg.contains("child"))
}

///|
test "deeply nested" {
  let source =
    #|a {
    #|  b {
    #|    c
    #|  }
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains(">a<"))
  assert_true(svg.contains(">b<"))
  assert_true(svg.contains(">c<"))
}

// =============================================================================
// Style tests
// =============================================================================

///|
test "object with fill" {
  let source =
    #|box {
    #|  style.fill: red
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("fill=\"red\""))
}

///|
test "object with stroke" {
  let source =
    #|box {
    #|  style.stroke: blue
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("stroke=\"blue\""))
}

// =============================================================================
// Complex diagram tests
// =============================================================================

///|
test "web architecture" {
  let source =
    #|client: Browser
    #|server: Web Server
    #|db: Database {
    #|  shape: cylinder
    #|}
    #|client -> server: HTTP
    #|server -> db: SQL
  let svg = compile(source).unwrap()
  assert_true(svg.contains("Browser"))
  assert_true(svg.contains("Web Server"))
  assert_true(svg.contains("Database"))
  assert_true(svg.contains("HTTP"))
  assert_true(svg.contains("SQL"))
}

///|
test "microservices" {
  let source =
    #|gateway: API Gateway
    #|auth: Auth Service
    #|users: User Service
    #|gateway -> auth
    #|gateway -> users
    #|auth <-> users
  let svg = compile(source).unwrap()
  assert_true(svg.contains("API Gateway"))
  assert_true(svg.contains("Auth Service"))
  assert_true(svg.contains("User Service"))
}

// =============================================================================
// Error handling tests
// =============================================================================

///|
test "parse error" {
  let result = compile("a -> ")
  assert_true(result is Err(_))
}

///|
test "empty input" {
  let result = compile("")
  assert_true(result is Ok(_))
}

// =============================================================================
// Position and Layout tests
// =============================================================================

///|
/// Compile D2 source to laid-out Graph (for position testing)
fn compile_to_graph(
  source : String,
  direction : @layout.Direction,
) -> Result[@graph.Graph, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph = @graph.compile("test", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @layout.LayoutConfig::new()
  @layout.layout(graph, config, direction)
  Ok(graph)
}

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
    match obj.get_box() {
      Some(box) => {
        assert_true(box.get_width() > 0.0)
        assert_true(box.get_height() > 0.0)
      }
      None => fail("object should have box")
    }
  }
}

///|
test "multiple objects don't overlap" {
  let graph = compile_to_graph("a\nb\nc", @layout.Direction::Down).unwrap()
  let objects = graph.get_objects()
  // Check no pair of objects overlap
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
      // b should be below a (higher y value)
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
      // b should be to the right of a (higher x value)
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
  match parent.get_box() {
    Some(parent_box) => {
      // Check children centers are inside parent box
      match child1.center() {
        Some(c1) =>
          assert_true(
            parent_box.contains(c1),
            msg="child1 center should be inside parent",
          )
        None => fail("child1 should have center")
      }
      match child2.center() {
        Some(c2) =>
          assert_true(
            parent_box.contains(c2),
            msg="child2 center should be inside parent",
          )
        None => fail("child2 should have center")
      }
    }
    None => fail("parent should have box")
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
      // child2 should be below child1
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
  // Edge should have at least start and end points
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
      // First route point should be near source
      let start = route[0]
      let a_center = box_a.center()
      let dist_to_a = start.distance(a_center)
      assert_true(
        dist_to_a < box_a.get_width(),
        msg="edge start should be near source object",
      )
      // Last route point should be near destination
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
      // In Down direction: server should be top, then database, then cache
      assert_true(s.get_y() < d.get_y(), msg="server should be above database")
      assert_true(d.get_y() < c.get_y(), msg="database should be above cache")
    }
    _ => fail("objects should have boxes")
  }
}

// =============================================================================
// ASCII output tests
// =============================================================================

///|
/// Compile D2 source to ASCII art
fn compile_ascii(source : String) -> Result[String, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph = @graph.compile("test", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @layout.LayoutConfig::new()
  @layout.layout(graph, config, @layout.Direction::Down)
  let render_config = @graph.AsciiConfig::new()
  Ok(@graph.render_ascii(graph, render_config))
}

///|
test "ascii simple object" {
  let ascii = compile_ascii("server").unwrap()
  assert_true(ascii.contains("server"))
  assert_true(ascii.contains("+"))
  assert_true(ascii.contains("-"))
  assert_true(ascii.contains("|"))
}

///|
test "ascii multiple objects" {
  let source =
    #|a
    #|b
    #|c
  let ascii = compile_ascii(source).unwrap()
  assert_true(ascii.contains("a"))
  assert_true(ascii.contains("b"))
  assert_true(ascii.contains("c"))
}

///|
test "ascii edge" {
  let ascii = compile_ascii("a -> b").unwrap()
  assert_true(ascii.contains("a"))
  assert_true(ascii.contains("b"))
  assert_true(ascii.contains("|"))
}

///|
test "ascii chain" {
  let ascii = compile_ascii("a -> b -> c").unwrap()
  assert_true(ascii.contains("a"))
  assert_true(ascii.contains("b"))
  assert_true(ascii.contains("c"))
}
