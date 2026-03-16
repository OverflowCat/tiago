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
const CLI_VERSION : String = "0.2.3"

///|
fn run_cli(raw_args : Array[String], env : Map[String, String]) -> Unit {
  let request = match parse_cli_request(raw_args, env) {
    Ok(req) => req
    Err(err) => {
      println(err)
      @sys.exit(1)
      return
    }
  }
  match execute_cli_request(request) {
    Ok(_) => ()
    Err(err) => {
      println("Error: \{err}")
      @sys.exit(1)
    }
  }
}

///|
fn execute_cli_request(request : CliRequest) -> Result[Unit, String] {
  match request.command {
    CliCommand::Render =>
      match request.render {
        Some(render_req) => execute_render(render_req)
        None => Err("internal error: missing render request")
      }
    CliCommand::Fmt =>
      match request.fmt {
        Some(fmt_req) => execute_fmt(fmt_req)
        None => Err("internal error: missing fmt request")
      }
    CliCommand::Validate =>
      match request.validate {
        Some(validate_req) => execute_validate(validate_req)
        None => Err("internal error: missing validate request")
      }
    CliCommand::Layout =>
      match request.layout {
        Some(layout_req) => execute_layout(layout_req)
        None => Err("internal error: missing layout request")
      }
    CliCommand::Themes => {
      list_themes()
      Ok(())
    }
    CliCommand::Version => {
      println(CLI_VERSION)
      Ok(())
    }
    CliCommand::InternalDumpInput =>
      match request.dump_input {
        Some(dump_req) => execute_internal_dump_input(dump_req)
        None => Err("internal error: missing dump-input request")
      }
  }
}

///|
fn execute_render(request : RenderRequest) -> Result[Unit, String] {
  if request.watch {
    execute_render_watch(request)
  } else {
    execute_render_once(request)
  }
}

///|
fn execute_render_once(request : RenderRequest) -> Result[Unit, String] {
  if request.from_stdin {
    let source = @fs.read_file_to_string("/dev/stdin") catch {
      e => return Err("Error reading from stdin: \{e}")
    }
    let output = match
      compile_source(
        source,
        source_compile_mode(request.output_mode),
        request.theme_name,
        None,
        request.layout_engine,
        request.layout_explicit,
        request.target_spec,
        ascii_mode=request.ascii_mode,
        dark_theme_id=request.dark_theme_id,
        theme_overrides=request.theme_overrides,
        dark_theme_overrides=request.dark_theme_overrides,
        scale=request.scale,
        bundle=request.bundle,
        no_xml_tag=request.no_xml_tag,
        salt=request.salt,
        omit_version=request.omit_version,
      ) {
      Ok(v) => v
      Err(err) => return Err(err)
    }
    let output_target = normalize_output_target(request.output_path)
    return write_compiled_output(request.output_mode, output_target, output)
  }

  let input_path = match request.input_path {
    Some(path_raw) => normalize_input_path(path_raw)
    None => return Err("internal error: missing input path")
  }
  let source = @fs.read_file_to_string(input_path) catch {
    e => return Err("Error reading file '\{input_path}': \{e}")
  }
  let output = match
    compile_source(
      source,
      source_compile_mode(request.output_mode),
      request.theme_name,
      get_dir_path(input_path),
      request.layout_engine,
      request.layout_explicit,
      request.target_spec,
      ascii_mode=request.ascii_mode,
      dark_theme_id=request.dark_theme_id,
      theme_overrides=request.theme_overrides,
      dark_theme_overrides=request.dark_theme_overrides,
      scale=request.scale,
      bundle=request.bundle,
      no_xml_tag=request.no_xml_tag,
      salt=request.salt,
      omit_version=request.omit_version,
    ) {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let output_target = normalize_output_target(request.output_path)
  write_compiled_output(request.output_mode, output_target, output)
}

///|
fn normalize_output_target(output_path : String?) -> String? {
  match output_path {
    Some(path) => if is_stdout_output_path(path) { None } else { Some(path) }
    None => None
  }
}

///|
fn normalize_input_path(input_path : String) -> String {
  if @fs.path_exists(input_path) {
    let is_dir = @fs.is_dir(input_path) catch { _ => false }
    if is_dir {
      @path.Path(input_path).join("index.d2").to_string()
    } else {
      input_path
    }
  } else {
    input_path
  }
}

///|
fn execute_render_watch(request : RenderRequest) -> Result[Unit, String] {
  if !sleep_is_supported() {
    return Err("watch mode is not supported on this target.")
  }
  if request.from_stdin {
    return Err("--watch cannot be used with --stdin.")
  }
  let input = match request.input_path {
    Some(path_raw) => normalize_input_path(path_raw)
    None => return Err("internal error: missing input path for watch mode")
  }
  let out_path = match request.output_path {
    Some(path) =>
      if is_stdout_output_path(path) {
        return Err("--watch output path cannot be stdout ('-').")
      } else {
        path
      }
    None => replace_extension(input, output_extension(request.output_mode))
  }
  let base_path = get_dir_path(input)
  let mut preview_version_path : String? = None
  let mut preview_error_path : String? = None
  if request.preview_enabled {
    match
      start_watch_preview(
        out_path,
        request.preview_host,
        request.preview_port,
        request.preview_open_browser,
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
    e => return Err("Error reading file '\{input}': \{e}")
  }
  let initial = compile_source(
    last_source,
    source_compile_mode(request.output_mode),
    request.theme_name,
    base_path,
    request.layout_engine,
    request.layout_explicit,
    request.target_spec,
    ascii_mode=request.ascii_mode,
    dark_theme_id=request.dark_theme_id,
    theme_overrides=request.theme_overrides,
    dark_theme_overrides=request.dark_theme_overrides,
    scale=request.scale,
    bundle=request.bundle,
    no_xml_tag=request.no_xml_tag,
    salt=request.salt,
    omit_version=request.omit_version,
  )
  let mut initial_error : String? = None
  match initial {
    Ok(output) =>
      match write_compiled_output(request.output_mode, Some(out_path), output) {
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
  let selected_layout = if request.layout_explicit {
    layout_engine_name(request.layout_engine)
  } else {
    "auto(d2-config|default)"
  }
  println(
    "Watching \{input} (interval=\{request.watch_interval_ms}ms, layout=\{selected_layout})...",
  )

  while true {
    sleep_ms(request.watch_interval_ms)
    let maybe_source = Some(@fs.read_file_to_string(input)) catch {
      e => {
        let message = "Error reading file '\{input}': \{e}"
        println(message)
        preview_tick = preview_tick + 1
        publish_watch_preview_state(
          preview_version_path,
          preview_error_path,
          preview_tick,
          Some(message),
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
      source_compile_mode(request.output_mode),
      request.theme_name,
      base_path,
      request.layout_engine,
      request.layout_explicit,
      request.target_spec,
      ascii_mode=request.ascii_mode,
      dark_theme_id=request.dark_theme_id,
      theme_overrides=request.theme_overrides,
      dark_theme_overrides=request.dark_theme_overrides,
      scale=request.scale,
      bundle=request.bundle,
      no_xml_tag=request.no_xml_tag,
      salt=request.salt,
      omit_version=request.omit_version,
    )
    let mut compile_error : String? = None
    match result {
      Ok(output) =>
        match
          write_compiled_output(request.output_mode, Some(out_path), output) {
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
  Ok(())
}

///|
fn execute_fmt(request : FmtRequest) -> Result[Unit, String] {
  let mut unformatted_count = 0
  for file_path in request.files {
    let normalized = normalize_input_path(file_path)
    let source = @fs.read_file_to_string(normalized) catch {
      e => return Err("Error reading file '\{normalized}': \{e}")
    }
    let (ast, parse_errors) = @compiler.parse(source)
    if !parse_errors.is_empty() {
      return Err("Parse errors in \{normalized}:\n  \{parse_errors}")
    }
    let formatted = @formatter.format(ast, @formatter.FormatConfig::new())
    if source != formatted {
      if request.check {
        unformatted_count = unformatted_count + 1
      } else {
        @fs.write_string_to_file(normalized, formatted) catch {
          e => return Err("Error writing file '\{normalized}': \{e}")
        }
      }
    }
  }
  if request.check && unformatted_count > 0 {
    let noun = if unformatted_count == 1 { "file" } else { "files" }
    return Err(
      "found \{unformatted_count} unformatted \{noun}. Run diago fmt to fix.",
    )
  }
  Ok(())
}

///|
fn execute_validate(request : ValidateRequest) -> Result[Unit, String] {
  let source = if request.from_stdin {
    @fs.read_file_to_string("/dev/stdin") catch {
      e => return Err("Error reading from stdin: \{e}")
    }
  } else {
    let path_raw = match request.input_path {
      Some(path) => path
      None => return Err("internal error: missing validate input path")
    }
    let path = normalize_input_path(path_raw)
    @fs.read_file_to_string(path) catch {
      e => return Err("Error reading file '\{path}': \{e}")
    }
  }
  let (ast, parse_errors) = @compiler.parse(source)
  if !parse_errors.is_empty() {
    return Err("Parse errors: \{parse_errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("Semantic error: \{e}") }
  let _ = @exporter.to_graph("diagram", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let display = if request.from_stdin {
    "Input"
  } else {
    request.input_path.unwrap_or("Input")
  }
  println("Success! [\{display}] is valid D2.")
  Ok(())
}

///|
priv struct LayoutEngineInfo {
  name : String
  short_help : String
  long_help : String
}

///|
let layout_engine_infos : Array[LayoutEngineInfo] = [
  {
    name: "dagre",
    short_help: "Layered graph layout via moon_dagre",
    long_help: (
      #|dagre:
      #|  Layered DAG-oriented layout engine.
      #|  Best for standard directed graph diagrams.
    ),
  },
  {
    name: "elk",
    short_help: "Layered graph layout via moon_elk",
    long_help: (
      #|elk:
      #|  Layered ELK layout engine.
      #|  Supports hierarchy-aware orthogonal routing for complex containers.
    ),
  },
  {
    name: "railway",
    short_help: "Custom railway-style orthogonal layout",
    long_help: (
      #|railway:
      #|  Diago-native experimental orthogonal railway layout engine.
      #|  Useful for deterministic local track routing experiments.
    ),
  },
]

///|
fn execute_layout(request : LayoutRequest) -> Result[Unit, String] {
  match request.engine_name {
    None => {
      println("Available layout engines:")
      for info in layout_engine_infos {
        println("  \{info.name} - \{info.short_help}")
      }
      println("")
      println("Usage:")
      println("  diago render --layout <name> ...")
      println("  diago layout <name>")
      Ok(())
    }
    Some(name) => {
      for info in layout_engine_infos {
        if info.name == name {
          println(info.long_help)
          return Ok(())
        }
      }
      Err(
        "unsupported layout engine '\{name}'. Expected dagre, elk, or railway.",
      )
    }
  }
}

///|
fn execute_internal_dump_input(
  request : DumpInputRequest,
) -> Result[Unit, String] {
  let input_sources = if request.input_paths.is_empty() {
    match collect_default_dump_input_sources() {
      Ok(paths) => paths
      Err(e) => return Err(e)
    }
  } else {
    request.input_paths
  }
  match ensure_dir_recursive(request.out_dir) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  for input in input_sources {
    let dumped = match
      dump_input_for_file(input, request.out_dir, request.engine) {
      Ok(path) => path
      Err(e) => return Err(e)
    }
    println("dumped \{input} -> \{dumped}")
  }
  Ok(())
}
