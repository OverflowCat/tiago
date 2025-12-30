///|
/// Diago - D2 diagram compiler
///
/// A MoonBit implementation of the D2 diagram language.
/// Usage: diago <input.d2> [output.svg]

///|
fn main {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    println("Usage: diago <input.d2> [output.svg]")
    println("  input.d2   - D2 diagram source file")
    println("  output.svg - Output SVG file (default: stdout)")
    @sys.exit(1)
  }
  let input_path = args[1]
  let output_path : String? = if args.length() >= 3 {
    Some(args[2])
  } else {
    None
  }
  // Read input file
  let source = @fs.read_file_to_string(input_path) catch {
    e => {
      println("Error reading file '\{input_path}': \{e}")
      @sys.exit(1)
      return
    }
  }
  // Compile the diagram
  match compile_d2(source) {
    Ok(svg) =>
      match output_path {
        Some(path) => {
          @fs.write_string_to_file(path, svg) catch {
            e => {
              println("Error writing file '\{path}': \{e}")
              @sys.exit(1)
            }
          }
          println("Written to \{path}")
        }
        None => println(svg)
      }
    Err(e) => {
      println("Error: \{e}")
      @sys.exit(1)
    }
  }
}

///|
/// Compile D2 source to SVG
fn compile_d2(source : String) -> Result[String, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph = @graph.compile("diagram", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @layout.LayoutConfig::new()
  @layout.layout(graph, config, @layout.Direction::Down)
  let render_config = @svg.RenderConfig::new()
  Ok(@svg.render(graph, render_config))
}
