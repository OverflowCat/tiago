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
enum OutputMode {
  Svg
  Ascii
  Unicode
  Txt
  Png
  Pdf
  Pptx
  Gif
}

///|
enum AsciiMode {
  Standard
  Extended
}

///|
fn output_extension(mode : OutputMode) -> String {
  match mode {
    OutputMode::Svg => ".svg"
    OutputMode::Ascii => ".txt"
    OutputMode::Unicode => ".txt"
    OutputMode::Txt => ".txt"
    OutputMode::Png => ".png"
    OutputMode::Pdf => ".pdf"
    OutputMode::Pptx => ".pptx"
    OutputMode::Gif => ".gif"
  }
}

///|
fn output_mode_name(mode : OutputMode) -> String {
  match mode {
    OutputMode::Svg => "svg"
    OutputMode::Ascii => "ascii"
    OutputMode::Unicode => "unicode"
    OutputMode::Txt => "txt"
    OutputMode::Png => "png"
    OutputMode::Pdf => "pdf"
    OutputMode::Pptx => "pptx"
    OutputMode::Gif => "gif"
  }
}

///|
fn source_compile_mode(mode : OutputMode) -> OutputMode {
  match mode {
    OutputMode::Png | OutputMode::Pdf | OutputMode::Pptx | OutputMode::Gif =>
      OutputMode::Svg
    _ => mode
  }
}

///|
fn parse_ascii_mode(value : String) -> AsciiMode? {
  match value.to_lower() {
    "standard" => Some(AsciiMode::Standard)
    "extended" => Some(AsciiMode::Extended)
    _ => None
  }
}

///|
fn parse_stdout_format(value : String) -> OutputMode? {
  match value.to_lower() {
    "svg" => Some(OutputMode::Svg)
    "ascii" => Some(OutputMode::Ascii)
    "unicode" => Some(OutputMode::Unicode)
    "txt" => Some(OutputMode::Txt)
    "png" => Some(OutputMode::Png)
    "pdf" => Some(OutputMode::Pdf)
    "pptx" => Some(OutputMode::Pptx)
    "gif" => Some(OutputMode::Gif)
    _ => None
  }
}

///|
fn infer_output_mode_from_path(path : String) -> OutputMode? {
  if path.has_suffix(".svg") {
    Some(OutputMode::Svg)
  } else if path.has_suffix(".ascii.txt") {
    Some(OutputMode::Ascii)
  } else if path.has_suffix(".unicode.txt") {
    Some(OutputMode::Unicode)
  } else if path.has_suffix(".txt") {
    Some(OutputMode::Txt)
  } else if path.has_suffix(".png") {
    Some(OutputMode::Png)
  } else if path.has_suffix(".pdf") {
    Some(OutputMode::Pdf)
  } else if path.has_suffix(".pptx") {
    Some(OutputMode::Pptx)
  } else if path.has_suffix(".gif") {
    Some(OutputMode::Gif)
  } else {
    None
  }
}

///|
fn is_stdout_output_path(path : String) -> Bool {
  path == "-"
}

///|
fn is_stdout_format_request_compatible(
  from_stdin : Bool,
  input_files_count : Int,
  output_path : String?,
) -> Bool {
  if from_stdin {
    output_path is None
  } else {
    input_files_count == 1 && output_path is None
  }
}

///|
enum LayoutEngineChoice {
  Dagre
  Railway
}

///|
fn parse_layout_engine(name : String) -> LayoutEngineChoice? {
  match name.to_lower() {
    "dagre" => Some(LayoutEngineChoice::Dagre)
    "railway" => Some(LayoutEngineChoice::Railway)
    _ => None
  }
}

///|
fn layout_engine_name(engine : LayoutEngineChoice) -> String {
  match engine {
    LayoutEngineChoice::Dagre => "dagre"
    LayoutEngineChoice::Railway => "railway"
  }
}

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
  let mut output_mode = OutputMode::Svg
  let mut output_mode_explicit = false
  let mut stdout_format_requested = false
  let mut ascii_mode = AsciiMode::Extended
  let mut theme_name : String? = None
  let mut dark_theme_id : Int? = None
  let theme_overrides : Map[String, String] = {}
  let dark_theme_overrides : Map[String, String] = {}
  let mut scale : Double? = None
  let mut no_xml_tag : Bool? = None
  let mut salt : String? = None
  let mut omit_version : Bool? = None
  let mut layout_engine = LayoutEngineChoice::Dagre
  let mut layout_explicit = false
  let mut target_spec : String? = None
  let input_files : Array[String] = []
  let mut output_path : String? = None
  let mut from_stdin = false
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--ascii" || arg == "-a" {
      output_mode = OutputMode::Ascii
      output_mode_explicit = true
    } else if arg == "--unicode" || arg == "-u" {
      output_mode = OutputMode::Unicode
      output_mode_explicit = true
    } else if arg == "--stdout-format" {
      i = i + 1
      if i < args.length() {
        match parse_stdout_format(args[i]) {
          Some(mode) => {
            output_mode = mode
            output_mode_explicit = true
            stdout_format_requested = true
          }
          None => {
            println(
              "Error: unsupported --stdout-format '\{args[i]}'. Expected svg, png, ascii, txt, pdf, pptx, gif, or unicode.",
            )
            @sys.exit(1)
            return
          }
        }
      }
    } else if arg.has_prefix("--stdout-format=") {
      let value = extract_value_after_eq(arg)
      match parse_stdout_format(value) {
        Some(mode) => {
          output_mode = mode
          output_mode_explicit = true
          stdout_format_requested = true
        }
        None => {
          println(
            "Error: unsupported --stdout-format '\{value}'. Expected svg, png, ascii, txt, pdf, pptx, gif, or unicode.",
          )
          @sys.exit(1)
          return
        }
      }
    } else if arg == "--ascii-mode" {
      i = i + 1
      if i < args.length() {
        match parse_ascii_mode(args[i]) {
          Some(mode) => ascii_mode = mode
          None => {
            println(
              "Error: unsupported --ascii-mode '\{args[i]}'. Expected standard or extended.",
            )
            @sys.exit(1)
            return
          }
        }
      }
    } else if arg.has_prefix("--ascii-mode=") {
      let value = extract_value_after_eq(arg)
      match parse_ascii_mode(value) {
        Some(mode) => ascii_mode = mode
        None => {
          println(
            "Error: unsupported --ascii-mode '\{value}'. Expected standard or extended.",
          )
          @sys.exit(1)
          return
        }
      }
    } else if arg == "--layout" || arg == "-l" {
      i = i + 1
      if i < args.length() {
        match parse_layout_engine(args[i]) {
          Some(engine) => {
            layout_engine = engine
            layout_explicit = true
          }
          None => {
            println(
              "Error: unsupported layout engine '\{args[i]}'. Expected dagre or railway.",
            )
            @sys.exit(1)
            return
          }
        }
      }
    } else if arg.has_prefix("--layout=") {
      let value = extract_value_after_eq(arg)
      match parse_layout_engine(value) {
        Some(engine) => {
          layout_engine = engine
          layout_explicit = true
        }
        None => {
          println(
            "Error: unsupported layout engine '\{value}'. Expected dagre or railway.",
          )
          @sys.exit(1)
          return
        }
      }
    } else if arg == "--target" {
      i = i + 1
      if i < args.length() {
        target_spec = Some(args[i])
      }
    } else if arg.has_prefix("--target=") {
      target_spec = Some(extract_value_after_eq(arg))
    } else if arg == "--theme" || arg == "-t" {
      i = i + 1
      if i < args.length() {
        theme_name = Some(args[i])
      }
    } else if arg.has_prefix("--theme=") {
      theme_name = Some(extract_theme_name(arg))
    } else if arg == "--dark-theme" || arg == "--dark-theme-id" {
      i = i + 1
      if i < args.length() {
        dark_theme_id = parse_theme_id_option(args[i], dark_theme_id)
      }
    } else if arg.has_prefix("--dark-theme=") {
      let value = extract_value_after_eq(arg)
      dark_theme_id = parse_theme_id_option(value, dark_theme_id)
    } else if arg.has_prefix("--dark-theme-id=") {
      let value = extract_value_after_eq(arg)
      dark_theme_id = parse_theme_id_option(value, dark_theme_id)
    } else if arg == "--theme-overrides" {
      i = i + 1
      if i < args.length() {
        merge_theme_overrides(theme_overrides, parse_override_pairs(args[i]))
      }
    } else if arg.has_prefix("--theme-overrides=") {
      merge_theme_overrides(
        theme_overrides,
        parse_override_pairs(extract_value_after_eq(arg)),
      )
    } else if arg == "--dark-theme-overrides" {
      i = i + 1
      if i < args.length() {
        merge_theme_overrides(
          dark_theme_overrides,
          parse_override_pairs(args[i]),
        )
      }
    } else if arg.has_prefix("--dark-theme-overrides=") {
      merge_theme_overrides(
        dark_theme_overrides,
        parse_override_pairs(extract_value_after_eq(arg)),
      )
    } else if arg == "--scale" {
      i = i + 1
      if i < args.length() {
        scale = parse_scale_option(args[i], scale)
      }
    } else if arg.has_prefix("--scale=") {
      scale = parse_scale_option(extract_value_after_eq(arg), scale)
    } else if arg == "--no-xml-tag" {
      no_xml_tag = Some(true)
    } else if arg.has_prefix("--no-xml-tag=") {
      no_xml_tag = parse_bool_option(extract_value_after_eq(arg), no_xml_tag)
    } else if arg == "--salt" {
      i = i + 1
      if i < args.length() {
        salt = Some(args[i])
      }
    } else if arg.has_prefix("--salt=") {
      salt = Some(extract_value_after_eq(arg))
    } else if arg == "--omit-version" {
      omit_version = Some(true)
    } else if arg.has_prefix("--omit-version=") {
      omit_version = parse_bool_option(
        extract_value_after_eq(arg),
        omit_version,
      )
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
  match output_path {
    Some(path) =>
      if is_stdout_output_path(path) {
        output_path = None
      } else if !output_mode_explicit {
        match infer_output_mode_from_path(path) {
          Some(inferred) => output_mode = inferred
          None => ()
        }
      }
    None => ()
  }
  if stdout_format_requested &&
    !is_stdout_format_request_compatible(
      from_stdin,
      input_files.length(),
      output_path,
    ) {
    println(
      "Error: --stdout-format is only supported when writing to stdout ('-').",
    )
    @sys.exit(1)
    return
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
    let result = compile_source(
      stdin_content,
      source_compile_mode(output_mode),
      theme_name,
      None,
      layout_engine,
      layout_explicit,
      target_spec,
      ascii_mode~,
      dark_theme_id~,
      theme_overrides~,
      dark_theme_overrides~,
      scale~,
      no_xml_tag~,
      salt~,
      omit_version~,
    )
    match result {
      Ok(output) =>
        match write_compiled_output(output_mode, output_path, output) {
          Ok(_) => ()
          Err(e) => {
            println("Error: \{e}")
            @sys.exit(1)
          }
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
    let result = compile_source(
      source,
      source_compile_mode(output_mode),
      theme_name,
      base_path,
      layout_engine,
      layout_explicit,
      target_spec,
      ascii_mode~,
      dark_theme_id~,
      theme_overrides~,
      dark_theme_overrides~,
      scale~,
      no_xml_tag~,
      salt~,
      omit_version~,
    )
    match result {
      Ok(output) =>
        match write_compiled_output(output_mode, output_path, output) {
          Ok(_) => ()
          Err(e) => {
            println("Error: \{e}")
            @sys.exit(1)
          }
        }
      Err(e) => {
        println("Error: \{e}")
        @sys.exit(1)
      }
    }
    return
  }
  // Multiple files: auto-generate output names
  let ext = output_extension(output_mode)
  for input in input_files {
    let source = @fs.read_file_to_string(input) catch {
      e => {
        println("Error reading file '\{input}': \{e}")
        continue
      }
    }
    let base_path = get_dir_path(input)
    let result = compile_source(
      source,
      source_compile_mode(output_mode),
      theme_name,
      base_path,
      layout_engine,
      layout_explicit,
      target_spec,
      ascii_mode~,
      dark_theme_id~,
      theme_overrides~,
      dark_theme_overrides~,
      scale~,
      no_xml_tag~,
      salt~,
      omit_version~,
    )
    match result {
      Ok(output) => {
        let out_path = replace_extension(input, ext)
        match write_compiled_output(output_mode, Some(out_path), output) {
          Ok(_) => ()
          Err(e) => println("Error in '\{input}': \{e}")
        }
      }
      Err(e) => println("Error in '\{input}': \{e}")
    }
  }
}

///|
fn write_compiled_output(
  output_mode : OutputMode,
  output_path : String?,
  output : String,
) -> Result[Unit, String] {
  match output_path {
    Some(path) =>
      match output_mode {
        OutputMode::Png
        | OutputMode::Pdf
        | OutputMode::Pptx
        | OutputMode::Gif => write_svg_binary_output(path, output, output_mode)
        _ => write_output(path, output)
      }
    None =>
      match output_mode {
        OutputMode::Png
        | OutputMode::Pdf
        | OutputMode::Pptx
        | OutputMode::Gif =>
          if !command_exec_is_supported() {
            Err(
              "Output format '" +
              output_mode_name(output_mode) +
              "' requires native command execution support.",
            )
          } else {
            write_svg_binary_stdout(output_mode, output)
          }
        _ => {
          println(output)
          Ok(())
        }
      }
  }
}

///|
fn write_output(path : String, content : String) -> Result[Unit, String] {
  @fs.write_string_to_file(path, content) catch {
    e => return Err("Error writing file '\{path}': \{e}")
  }
  println("Written to \{path}")
  Ok(())
}

///|
fn write_svg_binary_output(
  path : String,
  svg : String,
  output_mode : OutputMode,
  announce_write? : Bool = true,
) -> Result[Unit, String] {
  if !command_exec_is_supported() {
    return Err(
      "Output format '" +
      output_mode_name(output_mode) +
      "' requires native command execution support.",
    )
  }
  if command_exec("command -v rsvg-convert >/dev/null 2>&1") != 0 {
    return Err(
      "rsvg-convert is required for native \{output_mode_name(output_mode)} export.",
    )
  }
  let tmp_svg = path + ".diago_tmp.svg"
  @fs.write_string_to_file(tmp_svg, svg) catch {
    e => return Err("Error writing temporary SVG file '\{tmp_svg}': \{e}")
  }
  let mut exit_code = 0
  let mut failed_stage = ""
  match output_mode {
    OutputMode::Png => {
      let format = "png"
      let command = "rsvg-convert --format=\{format} -o " +
        shell_quote(path) +
        " " +
        shell_quote(tmp_svg)
      exit_code = command_exec(command)
      failed_stage = "rsvg-convert"
    }
    OutputMode::Pdf => {
      let format = "pdf"
      let command = "rsvg-convert --format=\{format} -o " +
        shell_quote(path) +
        " " +
        shell_quote(tmp_svg)
      exit_code = command_exec(command)
      failed_stage = "rsvg-convert"
    }
    OutputMode::Pptx => {
      let tmp_png = path + ".diago_tmp.png"
      let tmp_py = path + ".diago_tmp_pptx.py"
      let render_png_command = "rsvg-convert --format=png -o " +
        shell_quote(tmp_png) +
        " " +
        shell_quote(tmp_svg)
      let render_png_exit = command_exec(render_png_command)
      if render_png_exit != 0 {
        remove_file_quiet(tmp_svg)
        remove_file_quiet(tmp_png)
        return Err(
          "rsvg-convert failed for pptx export (exit code \{render_png_exit}).",
        )
      }
      if command_exec("command -v python3 >/dev/null 2>&1") != 0 {
        remove_file_quiet(tmp_svg)
        remove_file_quiet(tmp_png)
        return Err("python3 is required for native pptx export.")
      }
      if command_exec(
          "python3 -c " + shell_quote("import pptx") + " >/dev/null 2>&1",
        ) !=
        0 {
        remove_file_quiet(tmp_svg)
        remove_file_quiet(tmp_png)
        return Err("python-pptx is required for native pptx export.")
      }
      let script =
        #|from pptx import Presentation
        #|import sys
        #|
        #|png_path = sys.argv[1]
        #|out_path = sys.argv[2]
        #|
        #|prs = Presentation()
        #|blank_layout = prs.slide_layouts[6]
        #|slide = prs.slides.add_slide(blank_layout)
        #|slide.shapes.add_picture(
        #|    png_path,
        #|    0,
        #|    0,
        #|    width=prs.slide_width,
        #|    height=prs.slide_height,
        #|)
        #|prs.save(out_path)
      @fs.write_string_to_file(tmp_py, script) catch {
        e => {
          remove_file_quiet(tmp_svg)
          remove_file_quiet(tmp_png)
          return Err("Error writing temporary Python file '\{tmp_py}': \{e}")
        }
      }
      exit_code = command_exec(
        "python3 " +
        shell_quote(tmp_py) +
        " " +
        shell_quote(tmp_png) +
        " " +
        shell_quote(path),
      )
      failed_stage = "python3-pptx"
      remove_file_quiet(tmp_py)
      remove_file_quiet(tmp_png)
    }
    OutputMode::Gif => {
      let tmp_png = path + ".diago_tmp.png"
      let render_png_command = "rsvg-convert --format=png -o " +
        shell_quote(tmp_png) +
        " " +
        shell_quote(tmp_svg)
      let render_png_exit = command_exec(render_png_command)
      if render_png_exit != 0 {
        remove_file_quiet(tmp_svg)
        remove_file_quiet(tmp_png)
        return Err(
          "rsvg-convert failed for gif export (exit code \{render_png_exit}).",
        )
      }
      if command_exec("command -v magick >/dev/null 2>&1") == 0 {
        exit_code = command_exec(
          "magick " + shell_quote(tmp_png) + " " + shell_quote(path),
        )
        failed_stage = "magick"
      } else if command_exec("command -v ffmpeg >/dev/null 2>&1") == 0 {
        exit_code = command_exec(
          "ffmpeg -y -loglevel error -i " +
          shell_quote(tmp_png) +
          " " +
          shell_quote(path),
        )
        failed_stage = "ffmpeg"
      } else {
        remove_file_quiet(tmp_svg)
        remove_file_quiet(tmp_png)
        return Err("magick or ffmpeg is required for native gif export.")
      }
      remove_file_quiet(tmp_png)
    }
    _ => {
      remove_file_quiet(tmp_svg)
      return Err("internal error: unsupported binary output mode")
    }
  }
  remove_file_quiet(tmp_svg)
  if exit_code != 0 {
    return Err(
      failed_stage +
      " failed for \{output_mode_name(output_mode)} export (exit code \{exit_code}).",
    )
  }
  if announce_write {
    println("Written to \{path}")
  }
  Ok(())
}

///|
fn write_svg_binary_stdout(
  output_mode : OutputMode,
  svg : String,
) -> Result[Unit, String] {
  let tmp_path = ".diago_stdout_tmp" + output_extension(output_mode)
  let converted = write_svg_binary_output(
    tmp_path,
    svg,
    output_mode,
    announce_write=false,
  )
  match converted {
    Err(e) => Err(e)
    Ok(_) => {
      let cat_exit = command_exec("cat " + shell_quote(tmp_path))
      remove_file_quiet(tmp_path)
      if cat_exit != 0 {
        return Err(
          "failed to stream \{output_mode_name(output_mode)} output to stdout (exit code \{cat_exit}).",
        )
      }
      Ok(())
    }
  }
}

///|
fn remove_file_quiet(path : String) -> Unit {
  @fs.remove_file(path) catch {
    _ => ()
  }
}

///|
fn shell_quote(s : String) -> String {
  let sb = StringBuilder::new()
  sb.write_char('\'')
  for c in s {
    if c == '\'' {
      sb.write_string("'\"'\"'")
    } else {
      sb.write_char(c)
    }
  }
  sb.write_char('\'')
  sb.to_string()
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
  println("  --ascii, -a       Output ASCII art (.txt) instead of SVG")
  println("  --unicode, -u     Output Unicode box-drawing text (.txt)")
  println(
    "  --ascii-mode M    Text mode charset: standard|extended (default: extended)",
  )
  println(
    "  --stdout-format F Output format for stdout: svg|png|ascii|txt|pdf|pptx|gif|unicode",
  )
  println("  --layout, -l NAME Layout engine: dagre, railway (default: dagre)")
  println(
    "  --target PATH     Render a specific board path (e.g., layers.core)",
  )
  println("  --theme, -t NAME  Use specified theme (SVG mode)")
  println("  --dark-theme ID   Use dark theme ID when no light theme is set")
  println("  --theme-overrides K=V[,..]       Override light theme colors")
  println("  --dark-theme-overrides K=V[,..]  Override dark theme colors")
  println("  --scale N         Scale SVG width/height by factor N")
  println("  --no-xml-tag      Omit XML declaration in SVG output")
  println("  --salt TEXT       Salt SVG marker/pattern IDs")
  println("  --omit-version    Omit data-d2-version attribute in SVG output")
  println("  --list-themes     List all available themes")
  println("  -, --stdin        Read diago source from stdin")
  println("  --help, -h        Show this help message")
  println("")
  println("Watch Options (watch command):")
  println("  -i, --interval MS Poll interval in milliseconds (default: 500)")
  println(
    "  --preview/--no-preview         Toggle local preview server (default: on)",
  )
  println(
    "  --preview-host HOST            Preview server host (default: 127.0.0.1)",
  )
  println(
    "  --preview-port PORT            Preview server port (default: 17396)",
  )
  println(
    "  --no-preview-open              Do not auto-open browser for preview URL",
  )
  println(
    "  watch supports --ascii/--unicode/--layout/--target/--theme and SVG render flags",
  )
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
fn dirname_or_dot(path : String) -> String {
  let dir = @path.Path(path).dirname().to_string()
  if dir.length() == 0 {
    "."
  } else {
    dir
  }
}

///|
fn basename_string(path : String) -> String {
  @path.Path(path).basename().to_string()
}

///|
fn build_watch_preview_html(
  asset_file : String,
  version_file : String,
  error_file : String,
) -> String {
  let template =
    #|<!doctype html>
    #|<html>
    #|<head>
    #|  <meta charset="utf-8" />
    #|  <meta name="viewport" content="width=device-width, initial-scale=1" />
    #|  <title>diago watch preview</title>
    #|  <style>
    #|    html, body { margin: 0; padding: 0; height: 100%; font-family: ui-sans-serif, system-ui, sans-serif; background: #0b1220; color: #e5edf8; }
    #|    #toolbar { display: flex; justify-content: space-between; align-items: center; gap: 12px; padding: 10px 12px; background: #111a2f; border-bottom: 1px solid #2a3552; }
    #|    #status { font-size: 13px; opacity: 0.85; }
    #|    #error-box { white-space: pre-wrap; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; color: #ffb4b4; background: #2a1014; border: 1px solid #5a1f27; margin: 10px 12px; padding: 10px; border-radius: 8px; display: none; }
    #|    #frame-wrap { height: calc(100% - 54px); padding: 8px 10px 10px 10px; box-sizing: border-box; }
    #|    #preview-frame { width: 100%; height: 100%; border: 1px solid #2a3552; border-radius: 8px; background: #fff; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <div id="toolbar">
    #|    <div>diago watch preview</div>
    #|    <div id="status">waiting for updates...</div>
    #|  </div>
    #|  <div id="error-box"></div>
    #|  <div id="frame-wrap">
    #|    <iframe id="preview-frame" src="__ASSET_SRC__?v=0"></iframe>
    #|  </div>
    #|  <script>
    #|    const asset = "__ASSET_JS__";
    #|    const versionFile = "__VERSION_FILE__";
    #|    const errorFile = "__ERROR_FILE__";
    #|    const frame = document.getElementById("preview-frame");
    #|    const status = document.getElementById("status");
    #|    const errorBox = document.getElementById("error-box");
    #|    let lastVersion = "";
    #|    async function poll() {
    #|      const ts = Date.now();
    #|      try {
    #|        const versionRes = await fetch(versionFile + "?t=" + ts, { cache: "no-store" });
    #|        const versionText = (await versionRes.text()).trim();
    #|        if (versionText.length > 0 && versionText !== lastVersion) {
    #|          lastVersion = versionText;
    #|          frame.src = asset + "?v=" + encodeURIComponent(versionText);
    #|          status.textContent = "updated at " + new Date().toLocaleTimeString();
    #|        }
    #|      } catch (e) {
    #|        status.textContent = "preview polling failed";
    #|      }
    #|      try {
    #|        const errRes = await fetch(errorFile + "?t=" + ts, { cache: "no-store" });
    #|        const errText = await errRes.text();
    #|        if (errText.trim().length === 0) {
    #|          errorBox.style.display = "none";
    #|          errorBox.textContent = "";
    #|        } else {
    #|          errorBox.style.display = "block";
    #|          errorBox.textContent = errText;
    #|        }
    #|      } catch (_e) {
    #|      }
    #|      setTimeout(poll, 500);
    #|    }
    #|    poll();
    #|  </script>
    #|</body>
    #|</html>
  template
  .replace(old="__ASSET_SRC__", new=asset_file)
  .replace(old="__ASSET_JS__", new=asset_file)
  .replace(old="__VERSION_FILE__", new=version_file)
  .replace(old="__ERROR_FILE__", new=error_file)
}

///|
fn maybe_open_preview_url(url : String) -> Unit {
  if command_exec("command -v open >/dev/null 2>&1") == 0 {
    let _ = command_exec("open " + shell_quote(url) + " >/dev/null 2>&1 &")
    return
  }
  if command_exec("command -v xdg-open >/dev/null 2>&1") == 0 {
    let _ = command_exec("xdg-open " + shell_quote(url) + " >/dev/null 2>&1 &")
  }
}

///|
fn start_watch_preview(
  out_path : String,
  host : String,
  port : Int,
  open_browser : Bool,
) -> Result[(String, String), String] {
  if !command_exec_is_supported() {
    return Err("command execution is not supported on this target")
  }
  if command_exec("command -v python3 >/dev/null 2>&1") != 0 {
    return Err("python3 is required for watch preview server")
  }
  let dir = dirname_or_dot(out_path)
  let asset_file = basename_string(out_path)
  let preview_file = asset_file + ".watch.html"
  let version_file = asset_file + ".watch.version"
  let error_file = asset_file + ".watch.error.txt"
  let preview_path = @path.Path(dir).join(@path.Path(preview_file)).to_string()
  let version_path = @path.Path(dir).join(@path.Path(version_file)).to_string()
  let error_path = @path.Path(dir).join(@path.Path(error_file)).to_string()
  @fs.write_string_to_file(
    preview_path,
    build_watch_preview_html(asset_file, version_file, error_file),
  ) catch {
    e => return Err("failed to write watch preview page: \{e}")
  }
  @fs.write_string_to_file(version_path, "0") catch {
    e => return Err("failed to write watch version file: \{e}")
  }
  @fs.write_string_to_file(error_path, "") catch {
    e => return Err("failed to write watch error file: \{e}")
  }
  let serve_cmd = "python3 -m http.server " +
    port.to_string() +
    " --bind " +
    shell_quote(host) +
    " --directory " +
    shell_quote(dir) +
    " >/dev/null 2>&1 &"
  let serve_exit = command_exec(serve_cmd)
  if serve_exit != 0 {
    return Err("failed to start preview server (exit code \{serve_exit})")
  }
  let url = "http://\{host}:\{port.to_string()}/\{preview_file}"
  println("Preview: \{url}")
  if open_browser {
    maybe_open_preview_url(url)
  }
  Ok((version_path, error_path))
}

///|
fn publish_watch_preview_state(
  version_path : String?,
  error_path : String?,
  tick : Int,
  error_message : String?,
) -> Unit {
  guard version_path is Some(version_file) else { return }
  guard error_path is Some(error_file) else { return }
  @fs.write_string_to_file(version_file, tick.to_string()) catch {
    _ => ()
  }
  let err = match error_message {
    Some(e) => e
    None => ""
  }
  @fs.write_string_to_file(error_file, err) catch {
    _ => ()
  }
}

///|
/// Run the watch subcommand
fn run_watch(args : Array[String]) -> Unit {
  if !sleep_is_supported() {
    println("Error: watch mode is not supported on this target.")
    @sys.exit(1)
    return
  }
  let mut output_mode = OutputMode::Svg
  let mut output_mode_explicit = false
  let mut ascii_mode = AsciiMode::Extended
  let mut theme_name : String? = None
  let mut dark_theme_id : Int? = None
  let theme_overrides : Map[String, String] = {}
  let dark_theme_overrides : Map[String, String] = {}
  let mut scale : Double? = None
  let mut no_xml_tag : Bool? = None
  let mut salt : String? = None
  let mut omit_version : Bool? = None
  let mut layout_engine = LayoutEngineChoice::Dagre
  let mut layout_explicit = false
  let mut target_spec : String? = None
  let mut interval_ms = 500
  let mut preview_enabled = true
  let mut preview_host = "127.0.0.1"
  let mut preview_port = 17396
  let mut preview_open_browser = true
  let mut input_path : String? = None
  let mut output_path : String? = None
  let mut i = 2
  while i < args.length() {
    let arg = args[i]
    if arg == "--ascii" || arg == "-a" {
      output_mode = OutputMode::Ascii
      output_mode_explicit = true
    } else if arg == "--unicode" || arg == "-u" {
      output_mode = OutputMode::Unicode
      output_mode_explicit = true
    } else if arg == "--ascii-mode" {
      i = i + 1
      if i < args.length() {
        match parse_ascii_mode(args[i]) {
          Some(mode) => ascii_mode = mode
          None => {
            println(
              "Error: unsupported --ascii-mode '\{args[i]}'. Expected standard or extended.",
            )
            @sys.exit(1)
            return
          }
        }
      }
    } else if arg.has_prefix("--ascii-mode=") {
      let value = extract_value_after_eq(arg)
      match parse_ascii_mode(value) {
        Some(mode) => ascii_mode = mode
        None => {
          println(
            "Error: unsupported --ascii-mode '\{value}'. Expected standard or extended.",
          )
          @sys.exit(1)
          return
        }
      }
    } else if arg == "--layout" || arg == "-l" {
      i = i + 1
      if i < args.length() {
        match parse_layout_engine(args[i]) {
          Some(engine) => {
            layout_engine = engine
            layout_explicit = true
          }
          None => {
            println(
              "Error: unsupported layout engine '\{args[i]}'. Expected dagre or railway.",
            )
            @sys.exit(1)
            return
          }
        }
      }
    } else if arg.has_prefix("--layout=") {
      let value = extract_value_after_eq(arg)
      match parse_layout_engine(value) {
        Some(engine) => {
          layout_engine = engine
          layout_explicit = true
        }
        None => {
          println(
            "Error: unsupported layout engine '\{value}'. Expected dagre or railway.",
          )
          @sys.exit(1)
          return
        }
      }
    } else if arg == "--target" {
      i = i + 1
      if i < args.length() {
        target_spec = Some(args[i])
      }
    } else if arg.has_prefix("--target=") {
      target_spec = Some(extract_value_after_eq(arg))
    } else if arg == "--theme" || arg == "-t" {
      i = i + 1
      if i < args.length() {
        theme_name = Some(args[i])
      }
    } else if arg.has_prefix("--theme=") {
      theme_name = Some(extract_theme_name(arg))
    } else if arg == "--dark-theme" || arg == "--dark-theme-id" {
      i = i + 1
      if i < args.length() {
        dark_theme_id = parse_theme_id_option(args[i], dark_theme_id)
      }
    } else if arg.has_prefix("--dark-theme=") {
      dark_theme_id = parse_theme_id_option(
        extract_value_after_eq(arg),
        dark_theme_id,
      )
    } else if arg.has_prefix("--dark-theme-id=") {
      dark_theme_id = parse_theme_id_option(
        extract_value_after_eq(arg),
        dark_theme_id,
      )
    } else if arg == "--theme-overrides" {
      i = i + 1
      if i < args.length() {
        merge_theme_overrides(theme_overrides, parse_override_pairs(args[i]))
      }
    } else if arg.has_prefix("--theme-overrides=") {
      merge_theme_overrides(
        theme_overrides,
        parse_override_pairs(extract_value_after_eq(arg)),
      )
    } else if arg == "--dark-theme-overrides" {
      i = i + 1
      if i < args.length() {
        merge_theme_overrides(
          dark_theme_overrides,
          parse_override_pairs(args[i]),
        )
      }
    } else if arg.has_prefix("--dark-theme-overrides=") {
      merge_theme_overrides(
        dark_theme_overrides,
        parse_override_pairs(extract_value_after_eq(arg)),
      )
    } else if arg == "--scale" {
      i = i + 1
      if i < args.length() {
        scale = parse_scale_option(args[i], scale)
      }
    } else if arg.has_prefix("--scale=") {
      scale = parse_scale_option(extract_value_after_eq(arg), scale)
    } else if arg == "--no-xml-tag" {
      no_xml_tag = Some(true)
    } else if arg.has_prefix("--no-xml-tag=") {
      no_xml_tag = parse_bool_option(extract_value_after_eq(arg), no_xml_tag)
    } else if arg == "--salt" {
      i = i + 1
      if i < args.length() {
        salt = Some(args[i])
      }
    } else if arg.has_prefix("--salt=") {
      salt = Some(extract_value_after_eq(arg))
    } else if arg == "--omit-version" {
      omit_version = Some(true)
    } else if arg.has_prefix("--omit-version=") {
      omit_version = parse_bool_option(
        extract_value_after_eq(arg),
        omit_version,
      )
    } else if arg == "--interval" || arg == "-i" {
      i = i + 1
      if i < args.length() {
        interval_ms = parse_interval_ms(args[i], interval_ms)
      }
    } else if arg.has_prefix("--interval=") {
      let value = extract_value_after_eq(arg)
      interval_ms = parse_interval_ms(value, interval_ms)
    } else if arg == "--preview" {
      preview_enabled = true
    } else if arg == "--no-preview" {
      preview_enabled = false
    } else if arg == "--no-preview-open" {
      preview_open_browser = false
    } else if arg == "--preview-host" {
      i = i + 1
      if i < args.length() {
        preview_host = args[i]
      }
    } else if arg.has_prefix("--preview-host=") {
      preview_host = extract_value_after_eq(arg)
    } else if arg == "--preview-port" {
      i = i + 1
      if i < args.length() {
        match parse_uint(args[i]) {
          Some(v) => if v > 0 { preview_port = v }
          None => ()
        }
      }
    } else if arg.has_prefix("--preview-port=") {
      match parse_uint(extract_value_after_eq(arg)) {
        Some(v) => if v > 0 { preview_port = v }
        None => ()
      }
    } else if input_path is None {
      input_path = Some(arg)
    } else if output_path is None {
      output_path = Some(arg)
    }
    i = i + 1
  }
  match output_path {
    Some(path) =>
      if is_stdout_output_path(path) {
        println("Error: watch output path cannot be stdout ('-').")
        @sys.exit(1)
        return
      } else if !output_mode_explicit {
        match infer_output_mode_from_path(path) {
          Some(inferred) => output_mode = inferred
          None => ()
        }
      }
    None => ()
  }
  guard input_path is Some(input) else {
    println(
      "Usage: diago watch [--ascii|--unicode] [--ascii-mode MODE] [--layout NAME] [--target PATH] [--theme NAME] [--dark-theme ID] [--scale N] [--no-xml-tag] [--salt TEXT] [--omit-version] [-i MS] [--preview|--no-preview] [--preview-host HOST] [--preview-port PORT] [--no-preview-open] <input.d2> [output]",
    )
    @sys.exit(1)
    return
  }
  let base_path = get_dir_path(input)
  let ext = output_extension(output_mode)
  let out_path = match output_path {
    Some(path) => path
    None => replace_extension(input, ext)
  }
  let mut preview_version_path : String? = None
  let mut preview_error_path : String? = None
  if preview_enabled {
    match
      start_watch_preview(
        out_path, preview_host, preview_port, preview_open_browser,
      ) {
      Ok((version_path, error_path)) => {
        preview_version_path = Some(version_path)
        preview_error_path = Some(error_path)
      }
      Err(e) => println("Warning: watch preview disabled: \{e}")
    }
  }
  let mut preview_tick = 0
  let mut last_source = @fs.read_file_to_string(input) catch {
    e => {
      println("Error reading file '\{input}': \{e}")
      @sys.exit(1)
      return
    }
  }
  // Initial compile
  let initial = compile_source(
    last_source,
    source_compile_mode(output_mode),
    theme_name,
    base_path,
    layout_engine,
    layout_explicit,
    target_spec,
    ascii_mode~,
    dark_theme_id~,
    theme_overrides~,
    dark_theme_overrides~,
    scale~,
    no_xml_tag~,
    salt~,
    omit_version~,
  )
  let mut initial_error : String? = None
  match initial {
    Ok(output) =>
      match write_compiled_output(output_mode, Some(out_path), output) {
        Ok(_) => ()
        Err(e) => {
          println("Error: \{e}")
          initial_error = Some(e)
        }
      }
    Err(e) => {
      println("Error: \{e}")
      initial_error = Some(e)
    }
  }
  preview_tick = preview_tick + 1
  publish_watch_preview_state(
    preview_version_path, preview_error_path, preview_tick, initial_error,
  )
  let selected_layout = if layout_explicit {
    layout_engine_name(layout_engine)
  } else {
    "auto(d2-config|default)"
  }
  println(
    "Watching \{input} (interval=\{interval_ms}ms, layout=\{selected_layout})...",
  )
  // Poll loop
  while true {
    sleep_ms(interval_ms)
    let maybe_source = Some(@fs.read_file_to_string(input)) catch {
      e => {
        println("Error reading file '\{input}': \{e}")
        preview_tick = preview_tick + 1
        publish_watch_preview_state(
          preview_version_path,
          preview_error_path,
          preview_tick,
          Some("Error reading file '\{input}': \{e}"),
        )
        None
      }
    }
    guard maybe_source is Some(source) else { continue }
    if source == last_source {
      continue
    }
    last_source = source
    let result = compile_source(
      last_source,
      source_compile_mode(output_mode),
      theme_name,
      base_path,
      layout_engine,
      layout_explicit,
      target_spec,
      ascii_mode~,
      dark_theme_id~,
      theme_overrides~,
      dark_theme_overrides~,
      scale~,
      no_xml_tag~,
      salt~,
      omit_version~,
    )
    let mut compile_error : String? = None
    match result {
      Ok(output) =>
        match write_compiled_output(output_mode, Some(out_path), output) {
          Ok(_) => ()
          Err(e) => {
            println("Error: \{e}")
            compile_error = Some(e)
          }
        }
      Err(e) => {
        println("Error: \{e}")
        compile_error = Some(e)
      }
    }
    preview_tick = preview_tick + 1
    publish_watch_preview_state(
      preview_version_path, preview_error_path, preview_tick, compile_error,
    )
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
fn parse_theme_id_option(value : String, fallback : Int?) -> Int? {
  match parse_uint(value.trim().to_string()) {
    Some(v) => Some(v)
    None => fallback
  }
}

///|
fn parse_scale_option(value : String, fallback : Double?) -> Double? {
  let parsed = parse_non_negative_double(value.trim().to_string())
  match parsed {
    Some(v) => if v > 0.0 { Some(v) } else { fallback }
    None => fallback
  }
}

///|
fn parse_bool_option(value : String, fallback : Bool?) -> Bool? {
  match value.trim().to_string().to_lower() {
    "true" | "1" | "yes" => Some(true)
    "false" | "0" | "no" => Some(false)
    _ => fallback
  }
}

///|
fn merge_theme_overrides(
  dst : Map[String, String],
  src : Map[String, String],
) -> Unit {
  for key, value in src {
    dst[key.to_upper()] = value
  }
}

///|
fn parse_override_pairs(raw : String) -> Map[String, String] {
  let out : Map[String, String] = {}
  let mut s = raw.trim().to_string()
  if s.has_prefix("{") {
    s = s.strip_prefix("{").unwrap().to_string()
  }
  if s.has_suffix("}") {
    s = s.strip_suffix("}").unwrap().to_string()
  }
  for pair_raw in s.split(",") {
    let pair = pair_raw.trim().to_string()
    if pair == "" {
      continue
    }
    let sep = find_pair_separator(pair)
    if sep <= 0 {
      continue
    }
    let key = normalize_override_component(string_slice(pair, 0, sep))
    let value = normalize_override_component(
      string_slice(pair, sep + 1, pair.length()),
    )
    if key != "" && value != "" {
      out[key.to_upper()] = value
    }
  }
  out
}

///|
fn find_pair_separator(s : String) -> Int {
  for i in 0..<s.length() {
    let ch = s.code_unit_at(i).to_int().unsafe_to_char()
    if ch == '=' || ch == ':' {
      return i
    }
  }
  -1
}

///|
fn normalize_override_component(s : String) -> String {
  let mut out = s.trim().to_string()
  if out.has_prefix("\"") && out.has_suffix("\"") && out.length() >= 2 {
    out = string_slice(out, 1, out.length() - 1)
  } else if out.has_prefix("'") && out.has_suffix("'") && out.length() >= 2 {
    out = string_slice(out, 1, out.length() - 1)
  }
  out.trim().to_string()
}

///|
fn string_slice(s : String, start : Int, end : Int) -> String {
  if start < 0 || end < start || end > s.length() {
    return ""
  }
  let sb = StringBuilder::new()
  for i in start..<end {
    sb.write_char(s.code_unit_at(i).to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
fn parse_non_negative_double(s : String) -> Double? {
  if s.length() == 0 {
    return None
  }
  let mut int_part = 0
  let mut frac_part = 0
  let mut frac_scale = 1
  let mut seen_dot = false
  for c in s {
    if c == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
      continue
    }
    if c < '0' || c > '9' {
      return None
    }
    let digit = c.to_int() - '0'.to_int()
    if seen_dot {
      frac_part = frac_part * 10 + digit
      frac_scale = frac_scale * 10
    } else {
      int_part = int_part * 10 + digit
    }
  }
  Some(int_part.to_double() + frac_part.to_double() / frac_scale.to_double())
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
fn compile_source(
  source : String,
  output_mode : OutputMode,
  theme_name : String?,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
  ascii_mode? : AsciiMode = AsciiMode::Extended,
  dark_theme_id? : Int? = None,
  theme_overrides? : Map[String, String] = {},
  dark_theme_overrides? : Map[String, String] = {},
  scale? : Double? = None,
  no_xml_tag? : Bool? = None,
  salt? : String? = None,
  omit_version? : Bool? = None,
) -> Result[String, String] {
  match output_mode {
    OutputMode::Svg =>
      compile_diago_svg(
        source,
        theme_name,
        base_path,
        layout_engine,
        layout_explicit,
        target_spec,
        dark_theme_id~,
        theme_overrides~,
        dark_theme_overrides~,
        scale~,
        no_xml_tag~,
        salt~,
        omit_version~,
      )
    OutputMode::Ascii =>
      compile_diago_ascii(
        source,
        base_path,
        layout_engine,
        layout_explicit,
        target_spec,
        ascii_mode=AsciiMode::Standard,
      )
    OutputMode::Unicode =>
      compile_diago_unicode(
        source, base_path, layout_engine, layout_explicit, target_spec,
      )
    OutputMode::Txt =>
      compile_diago_ascii(
        source,
        base_path,
        layout_engine,
        layout_explicit,
        target_spec,
        ascii_mode~,
      )
    OutputMode::Png | OutputMode::Pdf | OutputMode::Pptx | OutputMode::Gif =>
      Err(
        "Output format '" +
        output_mode_name(output_mode) +
        "' is not supported yet in native export pipeline.",
      )
  }
}

///|
/// Compile diago source to SVG
fn compile_diago_svg(
  source : String,
  theme_name : String?,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
  dark_theme_id? : Int? = None,
  theme_overrides? : Map[String, String] = {},
  dark_theme_overrides? : Map[String, String] = {},
  scale? : Double? = None,
  no_xml_tag? : Bool? = None,
  salt? : String? = None,
  omit_version? : Bool? = None,
) -> Result[String, String] {
  match
    compile_to_diagram(
      source, base_path, layout_engine, layout_explicit, target_spec,
    ) {
    Ok(diagram) => {
      let render_config = resolve_svg_config(
        theme_name,
        diagram.config,
        dark_theme_id~,
        theme_overrides~,
        dark_theme_overrides~,
        scale~,
        no_xml_tag~,
        salt~,
        omit_version~,
      )
      try @renderer_svg.render(diagram, render_config) catch {
        e => Err(e.to_string())
      } noraise {
        v => Ok(v)
      }
    }
    Err(e) => Err(e)
  }
}

///|
/// Compile diago source to ASCII art
fn compile_diago_ascii(
  source : String,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
  ascii_mode? : AsciiMode = AsciiMode::Standard,
) -> Result[String, String] {
  match
    compile_to_diagram(
      source, base_path, layout_engine, layout_explicit, target_spec,
    ) {
    Ok(diagram) => {
      let render_config = ascii_render_config(ascii_mode)
      Ok(@renderer_ascii.render(diagram, render_config))
    }
    Err(e) => Err(e)
  }
}

///|
fn ascii_render_config(mode : AsciiMode) -> @renderer_ascii.AsciiConfig {
  match mode {
    AsciiMode::Standard => @renderer_ascii.AsciiConfig::new()
    AsciiMode::Extended => @renderer_ascii.AsciiConfig::unicode()
  }
}

///|
/// Compile diago source to Unicode box-drawing text
fn compile_diago_unicode(
  source : String,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
) -> Result[String, String] {
  match
    compile_to_diagram(
      source, base_path, layout_engine, layout_explicit, target_spec,
    ) {
    Ok(diagram) => Ok(@renderer_unicode.render(diagram))
    Err(e) => Err(e)
  }
}

///|
/// Compile diago source to a render-ready diagram
fn compile_to_diagram(
  source : String,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
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
  let source_config = match extract_source_config(ir) {
    Ok(config) => config
    Err(e) => return Err("Config error: \{e}")
  }
  let effective_layout_engine = match
    resolve_layout_engine(layout_engine, layout_explicit, source_config) {
    Ok(engine) => engine
    Err(e) => return Err(e)
  }
  let graph_input = @exporter.to_graph("diagram", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @engine_api.LayoutConfig::new()
  let laid_out_graph = match effective_layout_engine {
    LayoutEngineChoice::Dagre =>
      @engine_api.layout_with_engine(
        @engine_dagre.DagreEngine::new(),
        graph_input,
        config,
        @engine_api.Down,
      ) catch {
        e => return Err("Layout error: \{e}")
      }
    LayoutEngineChoice::Railway =>
      @engine_api.layout_with_engine(
        @engine_railway.RailwayEngine::new(),
        graph_input,
        config,
        @engine_api.Down,
      ) catch {
        e => return Err("Layout error: \{e}")
      }
  }
  let diagram = @diagram.from_graph(laid_out_graph, source_config)
  select_target_board(diagram, target_spec)
}

///|
fn resolve_svg_config(
  theme_name : String?,
  source_config : @diagram.Config?,
  dark_theme_id? : Int? = None,
  theme_overrides? : Map[String, String] = {},
  dark_theme_overrides? : Map[String, String] = {},
  scale? : Double? = None,
  no_xml_tag? : Bool? = None,
  salt? : String? = None,
  omit_version? : Bool? = None,
) -> @renderer_svg.SvgConfig {
  let source_theme_id = match source_config {
    Some(config) => config.theme_id
    None => None
  }
  let source_dark_theme_id = match source_config {
    Some(config) => config.dark_theme_id
    None => None
  }
  let effective_dark_theme_id = match dark_theme_id {
    Some(v) => Some(v)
    None => source_dark_theme_id
  }
  let mut resolved = match theme_name {
    Some(name) => @renderer_svg.SvgConfig::with_theme_name(name)
    None =>
      match source_theme_id {
        Some(theme_id) => @renderer_svg.SvgConfig::with_theme(theme_id)
        None => @renderer_svg.SvgConfig::new()
      }
  }
  match source_config {
    Some(config) =>
      match config.pad {
        Some(pad_value) => resolved = resolved.with_padding(pad_value)
        None => ()
      }
    None => ()
  }

  let merged_theme_overrides : Map[String, String] = {}
  let merged_dark_theme_overrides : Map[String, String] = {}
  match source_config {
    Some(config) => {
      merge_theme_overrides(merged_theme_overrides, config.theme_overrides)
      merge_theme_overrides(
        merged_dark_theme_overrides,
        config.dark_theme_overrides,
      )
    }
    None => ()
  }
  merge_theme_overrides(merged_theme_overrides, theme_overrides)
  merge_theme_overrides(merged_dark_theme_overrides, dark_theme_overrides)

  let effective_scale = match scale {
    Some(v) => Some(v)
    None =>
      match source_config {
        Some(config) => config.scale
        None => None
      }
  }
  let effective_no_xml_tag = match no_xml_tag {
    Some(v) => v
    None =>
      match source_config {
        Some(config) => config.no_xml_tag.unwrap_or(false)
        None => false
      }
  }
  let effective_salt = match salt {
    Some(v) => Some(v)
    None =>
      match source_config {
        Some(config) => config.salt
        None => None
      }
  }
  let effective_omit_version = match omit_version {
    Some(v) => v
    None =>
      match source_config {
        Some(config) => config.omit_version.unwrap_or(false)
        None => false
      }
  }

  resolved.with_render_options(
    effective_dark_theme_id, merged_theme_overrides, merged_dark_theme_overrides,
    effective_scale, effective_no_xml_tag, effective_salt, effective_omit_version,
  )
}

///|
fn resolve_layout_engine(
  cli_layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  source_config : @diagram.Config?,
) -> Result[LayoutEngineChoice, String] {
  if layout_explicit {
    return Ok(cli_layout_engine)
  }
  match source_config {
    Some(config) =>
      match config.layout_engine {
        Some(layout_name) =>
          match parse_layout_engine(layout_name) {
            Some(engine) => Ok(engine)
            None =>
              Err(
                "Error: unsupported layout engine '\{layout_name}' from vars.d2-config.layout-engine. Expected dagre or railway.",
              )
          }
        None => Ok(cli_layout_engine)
      }
    None => Ok(cli_layout_engine)
  }
}

///|
fn compile_theme_overrides_map(
  overrides_map : @ir.Map,
) -> Result[Map[String, String], String] {
  let overrides : Map[String, String] = {}
  let errors : Array[String] = []
  for field in overrides_map.fields {
    if field.primary is Some(value) {
      let raw_key = field.name
      let key = raw_key.to_upper()
      if not(is_valid_theme_override_key(key)) {
        errors.push("\"\{raw_key}\" is not a valid theme code")
        continue
      }
      let color_value = value.to_string()
      if not(is_valid_theme_override_color(color_value)) {
        errors.push(
          "expected \"\{raw_key}\" to be a valid named color (\"orange\") or a hex code (\"#f0ff3a\")",
        )
        continue
      }
      overrides[key] = color_value
    }
  }
  if not(errors.is_empty()) {
    return Err(errors.join("; "))
  }
  Ok(overrides)
}

///|
fn is_valid_theme_override_key(key : String) -> Bool {
  match key {
    "N1"
    | "N2"
    | "N3"
    | "N4"
    | "N5"
    | "N6"
    | "N7"
    | "B1"
    | "B2"
    | "B3"
    | "B4"
    | "B5"
    | "B6"
    | "AA2"
    | "AA4"
    | "AA5"
    | "AB4"
    | "AB5" => true
    _ => false
  }
}

///|
fn is_valid_theme_override_color(value : String) -> Bool {
  is_css_named_color(value) || is_hex_color(value)
}

///|
fn is_css_named_color(value : String) -> Bool {
  let lower = value.to_lower()
  for color in css_named_colors {
    if lower == color {
      return true
    }
  }
  false
}

///|
fn is_hex_color(value : String) -> Bool {
  if not(value.has_prefix("#")) {
    return false
  }
  let n = value.length()
  if n != 4 && n != 7 {
    return false
  }
  for i in 1..<n {
    match value[i].to_char() {
      Some(c) => if not(is_hex_digit(c)) { return false }
      None => return false
    }
  }
  true
}

///|
fn is_hex_digit(c : Char) -> Bool {
  ('0' <= c && c <= '9') || ('a' <= c && c <= 'f') || ('A' <= c && c <= 'F')
}

///|
let css_named_colors : Array[String] = [
  "currentcolor", "transparent", "aliceblue", "antiquewhite", "aqua", "aquamarine",
  "azure", "beige", "bisque", "black", "blanchedalmond", "blue", "blueviolet", "brown",
  "burlywood", "cadetblue", "chartreuse", "chocolate", "coral", "cornflowerblue",
  "cornsilk", "crimson", "cyan", "darkblue", "darkcyan", "darkgoldenrod", "darkgray",
  "darkgrey", "darkgreen", "darkkhaki", "darkmagenta", "darkolivegreen", "darkorange",
  "darkorchid", "darkred", "darksalmon", "darkseagreen", "darkslateblue", "darkslategray",
  "darkslategrey", "darkturquoise", "darkviolet", "deeppink", "deepskyblue", "dimgray",
  "dimgrey", "dodgerblue", "firebrick", "floralwhite", "forestgreen", "fuchsia",
  "gainsboro", "ghostwhite", "gold", "goldenrod", "gray", "grey", "green", "greenyellow",
  "honeydew", "hotpink", "indianred", "indigo", "ivory", "khaki", "lavender", "lavenderblush",
  "lawngreen", "lemonchiffon", "lightblue", "lightcoral", "lightcyan", "lightgoldenrodyellow",
  "lightgray", "lightgrey", "lightgreen", "lightpink", "lightsalmon", "lightseagreen",
  "lightskyblue", "lightslategray", "lightslategrey", "lightsteelblue", "lightyellow",
  "lime", "limegreen", "linen", "magenta", "maroon", "mediumaquamarine", "mediumblue",
  "mediumorchid", "mediumpurple", "mediumseagreen", "mediumslateblue", "mediumspringgreen",
  "mediumturquoise", "mediumvioletred", "midnightblue", "mintcream", "mistyrose",
  "moccasin", "navajowhite", "navy", "oldlace", "olive", "olivedrab", "orange", "orangered",
  "orchid", "palegoldenrod", "palegreen", "paleturquoise", "palevioletred", "papayawhip",
  "peachpuff", "peru", "pink", "plum", "powderblue", "purple", "rebeccapurple", "red",
  "rosybrown", "royalblue", "saddlebrown", "salmon", "sandybrown", "seagreen", "seashell",
  "sienna", "silver", "skyblue", "slateblue", "slategray", "slategrey", "snow", "springgreen",
  "steelblue", "tan", "teal", "thistle", "tomato", "turquoise", "violet", "wheat",
  "white", "whitesmoke", "yellow", "yellowgreen",
]

///|
fn extract_source_config(ir_map : @ir.Map) -> Result[@diagram.Config?, String] {
  let vars_map = match ir_map.get_field("vars") {
    Some(field) =>
      match field.map() {
        Some(map) => map
        None => return Ok(None)
      }
    None => return Ok(None)
  }
  let config_map = match vars_map.get_field("d2-config") {
    Some(field) =>
      match field.map() {
        Some(map) => map
        None => return Ok(None)
      }
    None => return Ok(None)
  }
  let mut sketch : Bool? = None
  let mut theme_id : Int? = None
  let mut dark_theme_id : Int? = None
  let theme_overrides : Map[String, String] = {}
  let dark_theme_overrides : Map[String, String] = {}
  let mut pad : Double? = None
  let mut center : Bool? = None
  let mut layout_engine : String? = None
  let mut scale : Double? = None
  let mut no_xml_tag : Bool? = None
  let mut salt : String? = None
  let mut omit_version : Bool? = None
  let data : Map[String, String] = {}
  if config_map.get_field("sketch") is Some(field) {
    if field.primary is Some(value) {
      sketch = value.as_bool()
    }
  }
  if config_map.get_field("theme-id") is Some(field) {
    if field.primary is Some(value) {
      theme_id = value.as_int()
    }
  }
  if config_map.get_field("dark-theme-id") is Some(field) {
    if field.primary is Some(value) {
      dark_theme_id = value.as_int()
    }
  }
  if config_map.get_field("theme-overrides") is Some(theme_overrides_field) {
    if theme_overrides_field.map() is Some(overrides_map) {
      let overrides = match compile_theme_overrides_map(overrides_map) {
        Ok(parsed) => parsed
        Err(e) => return Err(e)
      }
      merge_theme_overrides(theme_overrides, overrides)
    }
  }
  if config_map.get_field("dark-theme-overrides")
    is Some(dark_theme_overrides_field) {
    if dark_theme_overrides_field.map() is Some(overrides_map) {
      let overrides = match compile_theme_overrides_map(overrides_map) {
        Ok(parsed) => parsed
        Err(e) => return Err(e)
      }
      merge_theme_overrides(dark_theme_overrides, overrides)
    }
  }
  if config_map.get_field("pad") is Some(field) {
    if field.primary is Some(value) {
      if value.as_int() is Some(int_pad) {
        pad = Some(int_pad.to_double())
      }
    }
  }
  if config_map.get_field("center") is Some(field) {
    if field.primary is Some(value) {
      center = value.as_bool()
    }
  }
  if config_map.get_field("layout-engine") is Some(field) {
    if field.primary is Some(value) {
      layout_engine = Some(value.to_string())
    }
  }
  if config_map.get_field("scale") is Some(field) {
    if field.primary is Some(value) {
      scale = value.as_double()
    }
  }
  if config_map.get_field("no-xml-tag") is Some(field) {
    if field.primary is Some(value) {
      no_xml_tag = value.as_bool()
    }
  }
  if config_map.get_field("salt") is Some(field) {
    if field.primary is Some(value) {
      salt = Some(value.to_string())
    }
  }
  if config_map.get_field("omit-version") is Some(field) {
    if field.primary is Some(value) {
      omit_version = value.as_bool()
    }
  }
  if config_map.get_field("data") is Some(data_field) {
    if data_field.map() is Some(data_map) {
      for field in data_map.fields {
        if field.primary is Some(value) {
          data[field.name] = value.to_string()
        }
      }
    }
  }
  Ok(
    Some(
      @diagram.Config::from_parts(
        sketch, theme_id, dark_theme_id, theme_overrides, dark_theme_overrides, pad,
        center, layout_engine, scale, no_xml_tag, salt, omit_version, data,
      ),
    ),
  )
}

///|
fn select_target_board(
  diagram : @diagram.Diagram,
  target_spec : String?,
) -> Result[@diagram.Diagram, String] {
  match target_spec {
    None => Ok(diagram)
    Some(spec) => {
      let path = parse_target_path(spec)
      if path.length() == 0 {
        return Ok(diagram)
      }
      match diagram.get_board(path) {
        Some(board) => Ok(board)
        None => Err("Target board not found: \{spec}")
      }
    }
  }
}

///|
fn parse_target_path(spec : String) -> Array[String] {
  let segments : Array[String] = []
  let current = StringBuilder::new()
  for c in spec {
    if c == '.' {
      push_target_segment(segments, current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  push_target_segment(segments, current.to_string())
  segments
}

///|
fn push_target_segment(segments : Array[String], segment : String) -> Unit {
  if segment.length() == 0 || segment == "*" {
    return
  }
  segments.push(segment)
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
