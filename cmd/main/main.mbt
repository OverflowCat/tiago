///|
/// Diago - D2 diagram compiler
///
/// A MoonBit implementation of the D2 diagram language.
/// Usage: diago [--ascii] <input.d2> [output]

///|
fn main {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    print_usage()
    @sys.exit(1)
  }
  // Parse arguments
  let mut ascii_mode = false
  let mut input_path : String? = None
  let mut output_path : String? = None
  for i in 1..<args.length() {
    let arg = args[i]
    if arg == "--ascii" || arg == "-a" {
      ascii_mode = true
    } else if input_path is None {
      input_path = Some(arg)
    } else if output_path is None {
      output_path = Some(arg)
    }
  }
  guard input_path is Some(input) else {
    print_usage()
    @sys.exit(1)
    return
  }
  // Read input file
  let source = @fs.read_file_to_string(input) catch {
    e => {
      println("Error reading file '\{input}': \{e}")
      @sys.exit(1)
      return
    }
  }
  // Compile the diagram
  let result = if ascii_mode {
    compile_d2_ascii(source)
  } else {
    compile_d2_svg(source)
  }
  match result {
    Ok(output) =>
      match output_path {
        Some(path) => {
          @fs.write_string_to_file(path, output) catch {
            e => {
              println("Error writing file '\{path}': \{e}")
              @sys.exit(1)
            }
          }
          println("Written to \{path}")
        }
        None => println(output)
      }
    Err(e) => {
      println("Error: \{e}")
      @sys.exit(1)
    }
  }
}

///|
fn print_usage() -> Unit {
  println("Usage: diago [options] <input.d2> [output]")
  println("")
  println("Options:")
  println("  --ascii, -a  Output ASCII art instead of SVG")
  println("")
  println("Arguments:")
  println("  input.d2     D2 diagram source file")
  println("  output       Output file (default: stdout)")
}

///|
/// Compile D2 source to SVG
fn compile_d2_svg(source : String) -> Result[String, String] {
  match compile_to_graph(source) {
    Ok(graph) => {
      let render_config = @graph.SvgConfig::new()
      Ok(@graph.render_svg(graph, render_config))
    }
    Err(e) => Err(e)
  }
}

///|
/// Compile D2 source to ASCII art
fn compile_d2_ascii(source : String) -> Result[String, String] {
  match compile_to_graph(source) {
    Ok(graph) => {
      let render_config = @graph.AsciiConfig::new()
      Ok(@graph.render_ascii(graph, render_config))
    }
    Err(e) => Err(e)
  }
}

///|
/// Compile D2 source to laid-out graph
fn compile_to_graph(source : String) -> Result[@graph.Graph, String] {
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
  Ok(graph)
}
