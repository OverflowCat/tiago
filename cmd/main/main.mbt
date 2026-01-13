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
/// Diago - diago diagram compiler
///
/// A MoonBit implementation of the diago diagram language.
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
  if first_arg == "watch" {
    run_watch(args)
    return
  }
  // Parse arguments for compile
  let mut ascii_mode = false
  let mut theme_name : String? = None
  let input_files : Array[String] = []
  let mut output_path : String? = None
  let mut from_stdin = false
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
    } else if arg == "-" || arg == "--stdin" {
      from_stdin = true
    } else if arg.has_suffix(".d2") {
      // Collect all .d2 files
      input_files.push(arg)
    } else if input_files.length() == 1 && output_path is None {
      // Single file with explicit output
      output_path = Some(arg)
    }
    i = i + 1
  }
  // Handle stdin mode
  if from_stdin {
    let stdin_content = @fs.read_file_to_string("/dev/stdin") catch {
      e => {
        println("Error reading from stdin: \{e}")
        @sys.exit(1)
        return
      }
    }
    let result = if ascii_mode {
      compile_diago_ascii(stdin_content, None)
    } else {
      compile_diago_svg(stdin_content, theme_name, None)
    }
    match result {
      Ok(output) =>
        match output_path {
          Some(path) => write_output(path, output)
          None => println(output)
        }
      Err(e) => {
        println("Error: \{e}")
        @sys.exit(1)
      }
    }
    return
  }
  // Handle file(s) mode
  if input_files.length() == 0 {
    print_usage()
    @sys.exit(1)
    return
  }
  // Single file: use explicit output or stdout
  if input_files.length() == 1 {
    let input = input_files[0]
    let source = @fs.read_file_to_string(input) catch {
      e => {
        println("Error reading file '\{input}': \{e}")
        @sys.exit(1)
        return
      }
    }
    let base_path = get_dir_path(input)
    let result = if ascii_mode {
      compile_diago_ascii(source, base_path)
    } else {
      compile_diago_svg(source, theme_name, base_path)
    }
    match result {
      Ok(output) =>
        match output_path {
          Some(path) => write_output(path, output)
          None => println(output)
        }
      Err(e) => {
        println("Error: \{e}")
        @sys.exit(1)
      }
    }
    return
  }
  // Multiple files: auto-generate output names
  let ext = if ascii_mode { ".txt" } else { ".svg" }
  for input in input_files {
    let source = @fs.read_file_to_string(input) catch {
      e => {
        println("Error reading file '\{input}': \{e}")
        continue
      }
    }
    let base_path = get_dir_path(input)
    let result = if ascii_mode {
      compile_diago_ascii(source, base_path)
    } else {
      compile_diago_svg(source, theme_name, base_path)
    }
    match result {
      Ok(output) => {
        let out_path = replace_extension(input, ext)
        write_output(out_path, output)
      }
      Err(e) => println("Error in '\{input}': \{e}")
    }
  }
}

///|
fn write_output(path : String, content : String) -> Unit {
  @fs.write_string_to_file(path, content) catch {
    e => {
      println("Error writing file '\{path}': \{e}")
      return
    }
  }
  println("Written to \{path}")
}

///|
fn replace_extension(path : String, new_ext : String) -> String {
  // Find last dot
  let mut last_dot = -1
  for i in 0..<path.length() {
    if path.code_unit_at(i) == '.'.to_int().to_uint16() {
      last_dot = i
    }
  }
  if last_dot > 0 {
    // Build base string manually
    let buf = StringBuilder::new()
    for j in 0..<last_dot {
      buf.write_char(path.code_unit_at(j).to_int().unsafe_to_char())
    }
    buf.to_string() + new_ext
  } else {
    path + new_ext
  }
}

///|
fn print_usage() -> Unit {
  println("Usage: diago [command] [options] <input.d2> [output]")
  println("")
  println("Commands:")
  println("  validate          Check diago source for errors")
  println("  fmt               Format diago source file")
  println("  watch             Auto-rebuild on file changes")
  println("")
  println("Compile Options:")
  println("  --ascii, -a       Output ASCII art instead of SVG")
  println("  --theme, -t NAME  Use specified theme (default: Neutral Default)")
  println("  --list-themes     List all available themes")
  println("  -, --stdin        Read diago source from stdin")
  println("  --help, -h        Show this help message")
  println("")
  println("Watch Options (watch command):")
  println("  -i, --interval MS Poll interval in milliseconds (default: 500)")
  println("")
  println("Format Options (fmt command):")
  println("  -w, --write       Write formatted output to file in-place")
  println("  --check           Exit non-zero if file is not formatted (for CI)")
  println("  --diff            Show diff between original and formatted")
  println("")
  println("Arguments:")
  println("  input.d2          diago diagram source file (use - for stdin)")
  println("  output            Output file (default: stdout)")
}

///|
/// Run the fmt subcommand
fn run_fmt(args : Array[String]) -> Unit {
  let mut write_in_place = false
  let mut check_mode = false
  let mut diff_mode = false
  let mut input_path : String? = None
  let mut i = 2
  while i < args.length() {
    let arg = args[i]
    if arg == "-w" || arg == "--write" {
      write_in_place = true
    } else if arg == "--check" {
      check_mode = true
    } else if arg == "--diff" {
      diff_mode = true
    } else if input_path is None {
      input_path = Some(arg)
    }
    i = i + 1
  }
  guard input_path is Some(input) else {
    println("Usage: diago fmt [-w] [--check] [--diff] <input.d2>")
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
  let (ast, parse_errors) = @compiler.parse(source)
  if !parse_errors.is_empty() {
    println("Parse errors in \{input}:")
    println("  \{parse_errors}")
    @sys.exit(1)
    return
  }
  // Format
  let config = @formatter.FormatConfig::new()
  let formatted = @formatter.format(ast, config)
  // Handle different modes
  if check_mode {
    // Check mode: exit non-zero if not formatted
    if source != formatted {
      println("\{input}: not formatted")
      @sys.exit(1)
    } else {
      println("\{input}: OK")
    }
    return
  }
  if diff_mode {
    // Diff mode: show unified diff
    if source == formatted {
      println("\{input}: already formatted")
    } else {
      // Simple diff output (line-by-line)
      println("--- \{input}")
      println("+++ \{input}.formatted")
      print_diff(source, formatted)
    }
    return
  }
  if write_in_place {
    if source == formatted {
      println("\{input}: already formatted")
    } else {
      @fs.write_string_to_file(input, formatted) catch {
        e => {
          println("Error writing file '\{input}': \{e}")
          @sys.exit(1)
          return
        }
      }
      println("Formatted \{input}")
    }
  } else {
    println(formatted)
  }
}

///|
/// Print a simple unified diff between two strings
fn print_diff(original : String, formatted : String) -> Unit {
  let orig_lines = split_lines(original)
  let fmt_lines = split_lines(formatted)
  // Simple line-by-line diff (not a full unified diff, but useful)
  let max_len = if orig_lines.length() > fmt_lines.length() {
    orig_lines.length()
  } else {
    fmt_lines.length()
  }
  for i = 0; i < max_len; i = i + 1 {
    let orig_line = if i < orig_lines.length() {
      Some(orig_lines[i])
    } else {
      None
    }
    let fmt_line = if i < fmt_lines.length() {
      Some(fmt_lines[i])
    } else {
      None
    }
    match (orig_line, fmt_line) {
      (Some(o), Some(f)) =>
        if o != f {
          println("-\{o}")
          println("+\{f}")
        }
      (Some(o), None) => println("-\{o}")
      (None, Some(f)) => println("+\{f}")
      (None, None) => ()
    }
  }
}

///|
/// Split a string into lines
fn split_lines(s : String) -> Array[String] {
  let lines : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == '\n' {
      lines.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  // Add last line if non-empty
  let last = current.to_string()
  if last.length() > 0 {
    lines.push(last)
  }
  lines
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
  let (ast, parse_errors) = @compiler.parse(source)
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
  // Compile to graph input
  let _ = @exporter.to_graph("diagram", ir) catch {
    e => {
      println("Graph error in \{input_path}: \{e}")
      @sys.exit(1)
      return
    }
  }
  println("\{input_path}: OK")
}

///|
/// Run the watch subcommand
fn run_watch(args : Array[String]) -> Unit {
  if !sleep_is_supported() {
    println("Error: watch mode is not supported on this target.")
    @sys.exit(1)
    return
  }
  let mut ascii_mode = false
  let mut theme_name : String? = None
  let mut interval_ms = 500
  let mut input_path : String? = None
  let mut output_path : String? = None
  let mut i = 2
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
    } else if arg == "--interval" || arg == "-i" {
      i = i + 1
      if i < args.length() {
        interval_ms = parse_interval_ms(args[i], interval_ms)
      }
    } else if arg.has_prefix("--interval=") {
      let value = extract_value_after_eq(arg)
      interval_ms = parse_interval_ms(value, interval_ms)
    } else if input_path is None {
      input_path = Some(arg)
    } else if output_path is None {
      output_path = Some(arg)
    }
    i = i + 1
  }
  guard input_path is Some(input) else {
    println(
      "Usage: diago watch [--ascii] [--theme NAME] [-i MS] <input.d2> [output]",
    )
    @sys.exit(1)
    return
  }
  let base_path = get_dir_path(input)
  let ext = if ascii_mode { ".txt" } else { ".svg" }
  let out_path = match output_path {
    Some(path) => path
    None => replace_extension(input, ext)
  }
  let mut last_source = @fs.read_file_to_string(input) catch {
    e => {
      println("Error reading file '\{input}': \{e}")
      @sys.exit(1)
      return
    }
  }
  // Initial compile
  let initial = if ascii_mode {
    compile_diago_ascii(last_source, base_path)
  } else {
    compile_diago_svg(last_source, theme_name, base_path)
  }
  match initial {
    Ok(output) => write_output(out_path, output)
    Err(e) => println("Error: \{e}")
  }
  println("Watching \{input} (interval=\{interval_ms}ms)...")
  // Poll loop
  while true {
    sleep_ms(interval_ms)
    let maybe_source = Some(@fs.read_file_to_string(input)) catch {
      e => {
        println("Error reading file '\{input}': \{e}")
        None
      }
    }
    guard maybe_source is Some(source) else { continue }
    if source == last_source {
      continue
    }
    last_source = source
    let result = if ascii_mode {
      compile_diago_ascii(last_source, base_path)
    } else {
      compile_diago_svg(last_source, theme_name, base_path)
    }
    match result {
      Ok(output) => write_output(out_path, output)
      Err(e) => println("Error: \{e}")
    }
  }
}

///|
fn parse_interval_ms(s : String, default_value : Int) -> Int {
  match parse_uint(s) {
    Some(v) => if v <= 0 { default_value } else { v }
    None => default_value
  }
}

///|
fn parse_uint(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut acc = 0
  for c in s {
    if c < '0' || c > '9' {
      return None
    }
    acc = acc * 10 + (c.to_int() - '0'.to_int())
  }
  Some(acc)
}

///|
fn extract_value_after_eq(arg : String) -> String {
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
fn list_themes() -> Unit {
  println("Available themes:")
  for name in @renderer_svg.list_themes() {
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
/// Compile diago source to SVG
fn compile_diago_svg(
  source : String,
  theme_name : String?,
  base_path : String?,
) -> Result[String, String] {
  match compile_to_diagram(source, base_path) {
    Ok(diagram) => {
      let render_config = match theme_name {
        Some(name) => @renderer_svg.SvgConfig::with_theme_name(name)
        None => @renderer_svg.SvgConfig::new()
      }
      Ok(@renderer_svg.render(diagram, render_config))
    }
    Err(e) => Err(e)
  }
}

///|
/// Compile diago source to ASCII art
fn compile_diago_ascii(
  source : String,
  base_path : String?,
) -> Result[String, String] {
  match compile_to_diagram(source, base_path) {
    Ok(diagram) => {
      let render_config = @renderer_ascii.AsciiConfig::new()
      Ok(@renderer_ascii.render(diagram, render_config))
    }
    Err(e) => Err(e)
  }
}

///|
/// Compile diago source to a render-ready diagram
fn compile_to_diagram(
  source : String,
  base_path : String?,
) -> Result[@diagram.Diagram, String] {
  let (ast, errors) = @compiler.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  // Create import resolver based on base path
  let resolver = create_import_resolver(base_path)
  let ir = @ir.compile_with_imports(ast, resolver) catch {
    e => return Err("IR error: \{e}")
  }
  let graph_input = @exporter.to_graph("diagram", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @engine_api.LayoutConfig::new()
  let laid_out_graph = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    @engine_api.Down,
  ) catch {
    e => return Err("Layout error: \{e}")
  }
  Ok(@diagram.from_graph(laid_out_graph, None))
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
