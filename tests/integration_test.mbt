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
/// Integration tests: diago source to SVG and ASCII
/// This file contains helper functions and basic object tests.
/// Other tests are in separate files:
/// - shape_test.mbt: Shape rendering tests
/// - class_test.mbt: Class definition tests
/// - edge_test.mbt: Edge and arrowhead tests
/// - layout_test.mbt: Position and layout tests
/// - ascii_test.mbt: ASCII output tests

///|
/// Compile diago source to SVG
fn compile(source : String) -> Result[String, String] {
  match compile_to_diagram(source, @engine_api.Direction::Down) {
    Ok(diagram) => {
      let render_config = @renderer_svg.SvgConfig::new()
      Ok(@renderer_svg.render(diagram, render_config))
    }
    Err(e) => Err(e)
  }
}

///|
/// Compile diago source to a diagram (graph input + layout outputs)
fn compile_to_diagram(
  source : String,
  direction : @engine_api.Direction,
) -> Result[@diagram.Diagram, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph_input = @exporter.compile("test", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @engine_api.LayoutConfig::new()
  let laid_out_graph = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    direction,
  ) catch {
    e => return Err("Layout error: \{e}")
  }
  Ok(@diagram.from_graph(laid_out_graph, None))
}

///|
/// Compile diago source to laid-out render graph (for position testing)
fn compile_to_graph(
  source : String,
  direction : @engine_api.Direction,
) -> Result[@diagram.Diagram, String] {
  compile_to_diagram(source, direction)
}

///|
/// Compile diago source to ASCII art
fn compile_ascii(source : String) -> Result[String, String] {
  match compile_to_diagram(source, @engine_api.Direction::Down) {
    Ok(diagram) => {
      let render_config = @renderer_ascii.AsciiConfig::new()
      Ok(@renderer_ascii.render(diagram, render_config))
    }
    Err(e) => Err(e)
  }
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

///|
test "animated edge" {
  let source =
    #|a -> b {
    #|  style.animated: true
    #|}
  let svg = compile(source).unwrap()
  // Should have animated elements
  assert_true(svg.contains("stroke-dasharray"))
  assert_true(svg.contains("<animate"))
  assert_true(svg.contains("stroke-dashoffset"))
  assert_true(svg.contains("repeatCount=\"indefinite\""))
}

///|
test "tooltip on object" {
  let source =
    #|box {
    #|  tooltip: "This is a helpful tooltip"
    #|}
  let svg = compile(source).unwrap()
  // Should have title element for tooltip
  assert_true(svg.contains("<title>"))
  assert_true(svg.contains("This is a helpful tooltip"))
  assert_true(svg.contains("</title>"))
}

///|
test "grid gaps" {
  let source =
    #|container {
    #|  grid-rows: 2
    #|  grid-gap: 20
    #|  a
    #|  b
    #|  c
    #|  d
    #|}
  let result = compile(source)
  assert_true(result is Ok(_))
}

///|
test "grid horizontal and vertical gaps" {
  let source =
    #|container {
    #|  grid-rows: 2
    #|  horizontal-gap: 30
    #|  vertical-gap: 15
    #|  a
    #|  b
    #|  c
    #|  d
    #|}
  let result = compile(source)
  assert_true(result is Ok(_))
}

///|
test "grid column span" {
  let source =
    #|dashboard {
    #|  grid-rows: 2
    #|  grid-columns: 3
    #|  header {
    #|    grid-column-span: 3
    #|  }
    #|  sidebar
    #|  content
    #|  footer
    #|}
  let result = compile(source)
  assert_true(result is Ok(_))
}

///|
test "grid row span" {
  let source =
    #|layout {
    #|  grid-rows: 3
    #|  grid-columns: 2
    #|  sidebar {
    #|    grid-row-span: 2
    #|  }
    #|  main
    #|  footer
    #|}
  let result = compile(source)
  assert_true(result is Ok(_))
}

///|
test "grid combined spans" {
  let source =
    #|page {
    #|  grid-rows: 3
    #|  grid-columns: 3
    #|  header {
    #|    grid-column-span: 3
    #|  }
    #|  nav {
    #|    grid-row-span: 2
    #|  }
    #|  content {
    #|    grid-column-span: 2
    #|  }
    #|  footer {
    #|    grid-column-span: 3
    #|  }
    #|}
  let result = compile(source)
  assert_true(result is Ok(_))
}

// =============================================================================
// Theme tests
// =============================================================================

///|
/// Compile diago source to SVG with a specific theme
fn compile_with_theme(
  source : String,
  theme_id : Int,
) -> Result[String, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph_input = @exporter.compile("test", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @engine_api.LayoutConfig::new()
  let laid_out_graph = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Direction::Down,
  ) catch {
    e => return Err("Layout error: \{e}")
  }
  let diagram = @diagram.from_graph(laid_out_graph, None)
  let render_config = @renderer_svg.SvgConfig::with_theme(theme_id)
  Ok(@renderer_svg.render(diagram, render_config))
}

///|
test "terminal theme monospace font" {
  let source = "box"
  let svg = compile_with_theme(source, 300).unwrap()
  // Terminal theme should use monospace font
  assert_true(svg.contains("monospace"))
}

///|
test "terminal theme uppercase text" {
  let source = "mybox"
  let svg = compile_with_theme(source, 300).unwrap()
  // Terminal theme caps_lock rule should transform text to uppercase
  assert_true(svg.contains("text-transform: uppercase"))
}

///|
test "terminal theme no corner radius" {
  let source =
    #|box {
    #|  style.border-radius: 10
    #|}
  let svg = compile_with_theme(source, 300).unwrap()
  // Terminal theme no_corner_radius should override border-radius to 0
  // Check that there's no rx="10" in the output
  assert_true(not(svg.contains("rx=\"10\"")))
}

///|
test "terminal theme container dots" {
  let source =
    #|container {
    #|  child
    #|}
  let svg = compile_with_theme(source, 300).unwrap()
  // Terminal theme container_dots should add circle elements at corners
  // Count circle elements - should have 4 for the container corners
  let circle_count = svg.split("<circle").collect().length() - 1
  assert_true(
    circle_count >= 4,
    msg="Expected at least 4 circles for container dots, got \{circle_count}",
  )
}

///|
test "terminal theme outer container double border" {
  let source =
    #|container {
    #|  child
    #|}
  let svg = compile_with_theme(source, 300).unwrap()
  // Terminal theme outer_container_double_border should add inner border
  let rect_count = svg.split("<rect").collect().length() - 1
  // At least 3 rects: background, container outer border, container inner border
  assert_true(
    rect_count >= 3,
    msg="Expected at least 3 rects for double border, got \{rect_count}",
  )
}

// =============================================================================
// Icon tests
// =============================================================================

///|
test "icon on shape" {
  // Test that icon compiles without error
  let source =
    #|server {
    #|  icon: test-icon.png
    #|}
  let result = compile(source)
  assert_true(result is Ok(_))
}

///|
test "icon does not affect image shape" {
  let source =
    #|photo {
    #|  shape: image
    #|  icon: https://example.com/photo.jpg
    #|}
  let svg = compile(source).unwrap()
  // Image shape uses icon as the main image, not as a separate icon
  assert_true(svg.contains("<image"))
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
// Glob pattern tests
// =============================================================================

///|
test "single glob style" {
  let source =
    #|a
    #|b
    #|c
    #|*.style.fill: red
  let svg = compile(source).unwrap()
  // All objects should have red fill
  assert_true(svg.contains("fill=\"red\""))
}

///|
test "double glob style" {
  let source =
    #|container {
    #|  child1
    #|  child2
    #|}
    #|**.style.fill: blue
  let svg = compile(source).unwrap()
  // All nested objects should have blue fill
  assert_true(svg.contains("fill=\"blue\""))
}

///|
test "glob with pattern" {
  let source =
    #|server1
    #|server2
    #|client
    #|server*.style.fill: green
  let result = compile(source)
  assert_true(result is Ok(_))
}
