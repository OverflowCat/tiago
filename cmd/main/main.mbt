///|
/// Diago - D2 diagram compiler
///
/// A MoonBit implementation of the D2 diagram language.
/// Usage: diago <input.d2>

///|
fn main {
  // Example D2 diagram
  let source =
    #|server: Web Server
    #|database: Database {
    #|  shape: cylinder
    #|}
    #|cache: Cache {
    #|  shape: oval
    #|}
    #|server -> database: queries
    #|server -> cache: reads
    #|cache -> database: fallback
  // Compile the diagram
  let result = compile_d2(source)
  match result {
    Ok(svg) => println(svg)
    Err(e) => println("Error: \{e}")
  }
}

///|
/// Compile D2 source to SVG
fn compile_d2(source : String) -> Result[String, String] {
  // Stage 1 & 2: Parse source to AST
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  // Stage 3: Compile to IR
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  // Stage 4: Compile to Graph
  let graph = @graph.compile("diagram", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  // Stage 5: Layout
  let config = @layout.LayoutConfig::new()
  @layout.layout(graph, config, @layout.Direction::Down)
  // Stage 6: Render to SVG
  let render_config = @svg.RenderConfig::new()
  let svg = @svg.render(graph, render_config)
  Ok(svg)
}
