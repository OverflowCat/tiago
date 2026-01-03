///|
/// Integration tests: D2 source to SVG and ASCII
/// This file contains helper functions and basic object tests.
/// Other tests are in separate files:
/// - shape_test.mbt: Shape rendering tests
/// - class_test.mbt: Class definition tests
/// - edge_test.mbt: Edge and arrowhead tests
/// - layout_test.mbt: Position and layout tests
/// - ascii_test.mbt: ASCII output tests

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
/// Count occurrences of a character in a string
fn count_char(s : String, ch : Char) -> Int {
  let mut count = 0
  for c in s {
    if c == ch {
      count = count + 1
    }
  }
  count
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
// Text styling tests
// =============================================================================

///|
test "text-transform uppercase" {
  let source =
    #|box {
    #|  style.text-transform: uppercase
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("text-transform: uppercase"))
}

///|
test "text-transform lowercase" {
  let source =
    #|BOX {
    #|  style.text-transform: lowercase
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("text-transform: lowercase"))
}

///|
test "text-transform capitalize" {
  let source =
    #|my_box {
    #|  style.text-transform: capitalize
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("text-transform: capitalize"))
}

///|
test "custom font-family" {
  let source =
    #|title {
    #|  style.font-family: "Georgia, serif"
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("Georgia, serif"))
}

///|
test "monospace font-family" {
  let source =
    #|code_block {
    #|  style.font-family: monospace
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("monospace"))
}

///|
test "fill-pattern dots" {
  let source =
    #|box {
    #|  style.fill-pattern: dots
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("pattern-dots"))
  assert_true(svg.contains("url(#pattern-dots)"))
}

///|
test "fill-pattern lines" {
  let source =
    #|box {
    #|  style.fill-pattern: lines
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("pattern-lines"))
  assert_true(svg.contains("url(#pattern-lines)"))
}

///|
test "fill-pattern cross-hatch" {
  let source =
    #|box {
    #|  style.fill-pattern: cross-hatch
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("pattern-crosshatch"))
  assert_true(svg.contains("url(#pattern-crosshatch)"))
}

///|
test "fill-pattern grain" {
  let source =
    #|box {
    #|  style.fill-pattern: grain
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("pattern-grain"))
  assert_true(svg.contains("url(#pattern-grain)"))
}

///|
test "double-border style" {
  let source =
    #|box {
    #|  style.double-border: true
    #|}
  let svg = compile(source).unwrap()
  // Should have two rect elements (outer and inner border)
  let rect_count = svg.split("<rect").collect().length() - 1
  assert_true(
    rect_count >= 2,
    msg="Expected at least 2 rects for double border, got \{rect_count}",
  )
}

///|
test "sketch mode style" {
  let source =
    #|box {
    #|  style.sketch: true
    #|}
  let svg = compile(source).unwrap()
  // Should have sketch filter definition
  assert_true(svg.contains("sketch-filter"))
  assert_true(svg.contains("feTurbulence"))
  assert_true(svg.contains("feDisplacementMap"))
  // Should apply filter to element
  assert_true(svg.contains("filter=\"url(#sketch-filter)\""))
}

///|
test "sketch mode on edge" {
  let source =
    #|a -> b {
    #|  style.sketch: true
    #|}
  let svg = compile(source).unwrap()
  // Should have sketch filter definition and apply it
  assert_true(svg.contains("sketch-filter"))
  assert_true(svg.contains("filter=\"url(#sketch-filter)\""))
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
