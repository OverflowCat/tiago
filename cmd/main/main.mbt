///|
/// Diago - D2 diagram compiler
///
/// A MoonBit implementation of the D2 diagram language.
/// Usage: diago [options] <input.d2> [output]

///|
fn main {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    print_usage()
    @sys.exit(1)
  }
  // Check for subcommands
  let first_arg = args[1]
  if first_arg == "validate" {
    run_validate(args)
    return
  }
  if first_arg == "fmt" {
    run_fmt(args)
    return
  }
  // Parse arguments for compile
  let mut ascii_mode = false
  let mut theme_name : String? = None
  let mut input_path : String? = None
  let mut output_path : String? = None
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--ascii" || arg == "-a" {
      ascii_mode = true
    } else if arg == "--theme" || arg == "-t" {
      i = i + 1
      if i < args.length() {
        theme_name = Some(args[i])
      }
    } else if arg.has_prefix("--theme=") {
      theme_name = Some(extract_theme_name(arg))
    } else if arg == "--list-themes" {
      list_themes()
      return
    } else if arg == "--help" || arg == "-h" {
      print_usage()
      return
    } else if input_path is None {
      input_path = Some(arg)
    } else if output_path is None {
      output_path = Some(arg)
    }
    i = i + 1
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
  let base_path = get_dir_path(input)
  let result = if ascii_mode {
    compile_d2_ascii(source, base_path)
  } else {
    compile_d2_svg(source, theme_name, base_path)
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
  println("Usage: diago [command] [options] <input.d2> [output]")
  println("")
  println("Commands:")
  println("  validate          Check D2 source for errors")
  println("  fmt               Format D2 source file")
  println("")
  println("Options:")
  println("  --ascii, -a       Output ASCII art instead of SVG")
  println("  --theme, -t NAME  Use specified theme (default: Neutral Default)")
  println("  --list-themes     List all available themes")
  println("  --help, -h        Show this help message")
  println("")
  println("Arguments:")
  println("  input.d2          D2 diagram source file")
  println("  output            Output file (default: stdout)")
}

///|
/// Run the fmt subcommand
fn run_fmt(args : Array[String]) -> Unit {
  let mut write_in_place = false
  let mut input_path : String? = None
  let mut i = 2
  while i < args.length() {
    let arg = args[i]
    if arg == "-w" || arg == "--write" {
      write_in_place = true
    } else if input_path is None {
      input_path = Some(arg)
    }
    i = i + 1
  }
  guard input_path is Some(input) else {
    println("Usage: diago fmt [-w] <input.d2>")
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
  // Parse
  let (ast, parse_errors) = @parser.parse(source)
  if !parse_errors.is_empty() {
    println("Parse errors in \{input}:")
    println("  \{parse_errors}")
    @sys.exit(1)
    return
  }
  // Format
  let config = @formatter.FormatConfig::new()
  let formatted = @formatter.format(ast, config)
  if write_in_place {
    @fs.write_string_to_file(input, formatted) catch {
      e => {
        println("Error writing file '\{input}': \{e}")
        @sys.exit(1)
        return
      }
    }
    println("Formatted \{input}")
  } else {
    println(formatted)
  }
}

///|
/// Run the validate subcommand
fn run_validate(args : Array[String]) -> Unit {
  if args.length() < 3 {
    println("Usage: diago validate <input.d2>")
    @sys.exit(1)
    return
  }
  let input_path = args[2]
  // Read input file
  let source = @fs.read_file_to_string(input_path) catch {
    e => {
      println("Error reading file '\{input_path}': \{e}")
      @sys.exit(1)
      return
    }
  }
  // Parse
  let (ast, parse_errors) = @parser.parse(source)
  if !parse_errors.is_empty() {
    println("Parse errors in \{input_path}:")
    println("  \{parse_errors}")
    @sys.exit(1)
    return
  }
  // Compile to IR
  let ir = @ir.compile(ast) catch {
    e => {
      println("Semantic error in \{input_path}: \{e}")
      @sys.exit(1)
      return
    }
  }
  // Compile to graph
  let _ = @graph.compile("diagram", ir) catch {
    e => {
      println("Graph error in \{input_path}: \{e}")
      @sys.exit(1)
      return
    }
  }
  println("\{input_path}: OK")
}

///|
fn list_themes() -> Unit {
  println("Available themes:")
  for name in @graph.list_themes() {
    println("  \{name}")
  }
}

///|
fn extract_theme_name(arg : String) -> String {
  // Extract value after --theme=
  let sb = StringBuilder::new()
  let mut past_eq = false
  for c in arg {
    if past_eq {
      sb.write_char(c)
    } else if c == '=' {
      past_eq = true
    }
  }
  sb.to_string()
}

///|
/// Compile D2 source to SVG
fn compile_d2_svg(
  source : String,
  theme_name : String?,
  base_path : String?,
) -> Result[String, String] {
  match compile_to_graph(source, base_path) {
    Ok(graph) => {
      let render_config = match theme_name {
        Some(name) => @graph.SvgConfig::with_theme_name(name)
        None => @graph.SvgConfig::new()
      }
      Ok(@graph.render_svg(graph, render_config))
    }
    Err(e) => Err(e)
  }
}

///|
/// Compile D2 source to ASCII art
fn compile_d2_ascii(
  source : String,
  base_path : String?,
) -> Result[String, String] {
  match compile_to_graph(source, base_path) {
    Ok(graph) => {
      let render_config = @graph.AsciiConfig::new()
      Ok(@graph.render_ascii(graph, render_config))
    }
    Err(e) => Err(e)
  }
}

///|
/// Compile D2 source to laid-out graph
fn compile_to_graph(
  source : String,
  base_path : String?,
) -> Result[@graph.Graph, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  // Create import resolver based on base path
  let resolver = create_import_resolver(base_path)
  let ir = @ir.compile_with_imports(ast, resolver) catch {
    e => return Err("IR error: \{e}")
  }
  let graph = @graph.compile("diagram", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @layout.LayoutConfig::new()
  @layout.layout(graph, config, @layout.Direction::Down)
  Ok(graph)
}

///|
/// Create an import resolver that reads files relative to base path
fn create_import_resolver(base_path : String?) -> @ir.ImportResolver {
  @ir.ImportResolver::new(fn(import_path) {
    // Build full path
    let full_path = match base_path {
      Some(base) => @path.Path(base).join(@path.Path(import_path)).to_string()
      None => import_path
    }
    // Add .d2 extension if not present
    let path_with_ext = if full_path.has_suffix(".d2") {
      full_path
    } else {
      full_path + ".d2"
    }
    Some(
      // Try to read the file
      @fs.read_file_to_string(path_with_ext),
    ) catch {
      _ => None
    }
  })
}

///|
/// Get directory of a file path
fn get_dir_path(file_path : String) -> String? {
  let path = @path.Path(file_path)
  let dir = path.dirname()
  let dir_str = dir.to_string()
  if dir_str.length() > 0 {
    Some(dir_str)
  } else {
    None
  }
}
