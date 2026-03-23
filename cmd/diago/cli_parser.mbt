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
fn normalize_cli_argv(raw_args : Array[String]) -> Array[String] {
  let argv : Array[String] = []
  if raw_args.length() > 1 {
    for arg in raw_args[1:] {
      argv.push(arg)
    }
  }
  argv
}

///|
fn first_match_value(matches : @argparse.Matches, key : String) -> String? {
  match matches.values.get(key) {
    Some(values) => if values.length() > 0 { Some(values[0]) } else { None }
    None => None
  }
}

///|
fn match_values(matches : @argparse.Matches, key : String) -> Array[String] {
  match matches.values.get(key) {
    Some(values) => values.copy()
    None => []
  }
}

///|
fn build_cli_command() -> @argparse.Command {
  @argparse.Command(
    "diago",
    about="Diago diagram compiler",
    subcommand_required=true,
    arg_required_else_help=true,
    subcommands=[
      build_render_subcommand(),
      build_fmt_subcommand(),
      build_validate_subcommand(),
      build_layout_subcommand(),
      @argparse.Command("themes", about="List all available themes"),
      @argparse.Command("version", about="Print diago version"),
      build_internal_dump_input_subcommand(),
    ],
  )
}

///|
fn build_render_subcommand() -> @argparse.Command {
  @argparse.Command(
    "render",
    about="Render diagram to svg/ascii/unicode",
    flags=[
      @argparse.FlagArg(
        "stdin",
        long="stdin",
        about="Read diago source from stdin",
      ),
      @argparse.FlagArg(
        "watch",
        long="watch",
        about="Watch input file and rebuild on changes",
      ),
      @argparse.FlagArg(
        "center",
        short='c',
        long="center",
        about="Center the SVG in the containing viewbox",
        env="DIAGO_CENTER",
      ),
      @argparse.FlagArg(
        "sketch",
        short='s',
        long="sketch",
        about="Render the diagram in global sketch mode",
        env="DIAGO_SKETCH",
      ),
      @argparse.FlagArg(
        "bundle",
        long="bundle",
        about="Bundle image hrefs as data URIs (default: true)",
        negatable=true,
        env="DIAGO_BUNDLE",
      ),
      @argparse.FlagArg(
        "no-xml-tag",
        long="no-xml-tag",
        about="Omit XML declaration in SVG output",
        env="DIAGO_NO_XML_TAG",
      ),
      @argparse.FlagArg(
        "omit-version",
        long="omit-version",
        about="Omit the version attribute in SVG output",
        env="DIAGO_OMIT_VERSION",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "format",
        long="format",
        about="Output format: svg|ascii|unicode",
        env="DIAGO_FORMAT",
      ),
      @argparse.OptionArg(
        "layout",
        short='l',
        about="Layout engine: dagre|elk|railway (default: dagre)",
        env="DIAGO_LAYOUT",
      ),
      @argparse.OptionArg(
        "target",
        long="target",
        about="Render specific board path (e.g. layers.core)",
        env="DIAGO_TARGET",
      ),
      @argparse.OptionArg(
        "theme",
        short='t',
        about="Use specified theme (SVG mode)",
        env="DIAGO_THEME",
      ),
      @argparse.OptionArg(
        "pad",
        long="pad",
        about="Pixels padded around the rendered diagram",
        env="DIAGO_PAD",
      ),
      @argparse.OptionArg(
        "dark-theme",
        long="dark-theme",
        about="Use dark theme ID when no light theme is set",
        env="DIAGO_DARK_THEME",
      ),
      @argparse.OptionArg(
        "dark-theme-id",
        long="dark-theme-id",
        about="Alias of --dark-theme",
      ),
      @argparse.OptionArg(
        "theme-overrides",
        long="theme-overrides",
        about="Override light theme colors (comma-separated K=V pairs)",
        action=@argparse.OptionAction::Append,
        env="DIAGO_THEME_OVERRIDES",
      ),
      @argparse.OptionArg(
        "dark-theme-overrides",
        long="dark-theme-overrides",
        about="Override dark theme colors (comma-separated K=V pairs)",
        action=@argparse.OptionAction::Append,
        env="DIAGO_DARK_THEME_OVERRIDES",
      ),
      @argparse.OptionArg(
        "scale",
        long="scale",
        about="Scale SVG width/height by factor N",
        env="DIAGO_SCALE",
      ),
      @argparse.OptionArg(
        "salt",
        long="salt",
        about="Salt SVG marker/pattern IDs",
        env="DIAGO_SALT",
      ),
      @argparse.OptionArg(
        "interval",
        short='i',
        long="interval",
        about="Watch poll interval in milliseconds (default: 500)",
        env="DIAGO_WATCH_INTERVAL",
      ),
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="Output file path. Use '-' to write stdout",
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "paths",
        num_args=@argparse.ValueRange(lower=0, upper=2),
      ),
    ],
  )
}

///|
fn build_fmt_subcommand() -> @argparse.Command {
  @argparse.Command(
    "fmt",
    about="Format diagram files in place",
    flags=[
      @argparse.FlagArg(
        "check",
        long="check",
        about="Exit non-zero if files are not formatted",
        env="DIAGO_CHECK",
      ),
    ],
    positionals=[
      @argparse.PositionArg("files", num_args=@argparse.ValueRange(lower=1)),
    ],
  )
}

///|
fn build_validate_subcommand() -> @argparse.Command {
  @argparse.Command(
    "validate",
    about="Validate diago source",
    flags=[
      @argparse.FlagArg(
        "stdin",
        long="stdin",
        about="Read diago source from stdin",
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "paths",
        num_args=@argparse.ValueRange(lower=0, upper=1),
      ),
    ],
  )
}

///|
fn build_layout_subcommand() -> @argparse.Command {
  @argparse.Command(
    "layout",
    about="List layout engines or inspect one engine",
    positionals=[
      @argparse.PositionArg(
        "engine",
        num_args=@argparse.ValueRange(lower=0, upper=1),
      ),
    ],
  )
}

///|
fn build_internal_dump_input_subcommand() -> @argparse.Command {
  @argparse.Command(
    "__dump-input",
    about="Internal: dump layout engine input JSON",
    hidden=true,
    options=[
      @argparse.OptionArg(
        "engine",
        long="engine",
        about="Dump engine: elk|dagre",
      ),
      @argparse.OptionArg(
        "out-dir",
        long="out-dir",
        about="Output directory path",
        required=true,
      ),
    ],
    positionals=[
      @argparse.PositionArg("paths", num_args=@argparse.ValueRange(lower=0)),
    ],
  )
}

///|
fn parse_cli_request(
  raw_args : Array[String],
  env : Map[String, String],
) -> Result[CliRequest, String] {
  if legacy_cli_error(raw_args) is Some(err) {
    return Err(err)
  }
  let argv = normalize_cli_argv(raw_args)
  let matches = build_cli_command().parse(argv~, env~) catch {
    e => return Err(e.to_string())
  }
  guard matches.subcommand is Some((name, child)) else {
    return Err("No subcommand selected.")
  }
  match name {
    "render" =>
      match parse_render_request(child) {
        Ok(req) => Ok(CliRequest::render(req))
        Err(e) => Err(e)
      }
    "fmt" =>
      match parse_fmt_request(child) {
        Ok(req) => Ok(CliRequest::fmt(req))
        Err(e) => Err(e)
      }
    "validate" =>
      match parse_validate_request(child) {
        Ok(req) => Ok(CliRequest::validate(req))
        Err(e) => Err(e)
      }
    "layout" =>
      match parse_layout_request(child) {
        Ok(req) => Ok(CliRequest::layout(req))
        Err(e) => Err(e)
      }
    "themes" => Ok(CliRequest::themes())
    "version" => Ok(CliRequest::version())
    "__dump-input" =>
      match parse_internal_dump_input_request(child) {
        Ok(req) => Ok(CliRequest::dump_input(req))
        Err(e) => Err(e)
      }
    _ => Err("Unsupported subcommand '\{name}'.")
  }
}

///|
fn parse_render_request(
  matches : @argparse.Matches,
) -> Result[RenderRequest, String] {
  let from_stdin = matches.flags.get_or_default("stdin", false)
  let watch = matches.flags.get_or_default("watch", false)
  let mut output_mode = OutputMode::Svg
  let mut output_mode_explicit = false
  if first_match_value(matches, "format") is Some(value) {
    match parse_output_mode(value) {
      Some(mode) => {
        output_mode = mode
        output_mode_explicit = true
      }
      None =>
        return Err(
          "Error: unsupported --format '\{value}'. Expected svg, ascii, or unicode.",
        )
    }
  }
  let mut layout_engine = LayoutEngineChoice::Dagre
  let mut layout_explicit = false
  if first_match_value(matches, "layout") is Some(value) {
    match parse_layout_engine(value) {
      Some(engine) => {
        layout_engine = engine
        layout_explicit = true
      }
      None =>
        return Err(
          "Error: unsupported layout engine '\{value}'. Expected dagre, elk, or railway.",
        )
    }
  }
  let target_spec = first_match_value(matches, "target")
  let theme_name = first_match_value(matches, "theme")
  let mut dark_theme_id : Int? = None
  if first_match_value(matches, "dark-theme") is Some(value) {
    dark_theme_id = parse_theme_id_option(value, dark_theme_id)
  }
  if first_match_value(matches, "dark-theme-id") is Some(value) {
    dark_theme_id = parse_theme_id_option(value, dark_theme_id)
  }
  let sketch = matches.flags.get("sketch")
  let mut pad : Double? = None
  if first_match_value(matches, "pad") is Some(value) {
    match parse_uint(value) {
      Some(v) => pad = Some(v.to_double())
      None =>
        return Err(
          "Error: unsupported --pad '\{value}'. Expected a non-negative integer.",
        )
    }
  }
  let center = matches.flags.get("center")
  let mut theme_overrides : @diagram.ThemeOverrides? = None
  for value in match_values(matches, "theme-overrides") {
    theme_overrides = merge_theme_overrides(
      theme_overrides,
      parse_override_pairs(value),
    )
  }
  let mut dark_theme_overrides : @diagram.ThemeOverrides? = None
  for value in match_values(matches, "dark-theme-overrides") {
    dark_theme_overrides = merge_theme_overrides(
      dark_theme_overrides,
      parse_override_pairs(value),
    )
  }
  let mut scale : Double? = None
  if first_match_value(matches, "scale") is Some(value) {
    scale = parse_scale_option(value, scale)
  }
  let mut bundle = true
  if matches.flags.get("bundle") is Some(value) {
    bundle = value
  }
  let no_xml_tag = matches.flags.get("no-xml-tag")
  let salt = first_match_value(matches, "salt")
  let omit_version = matches.flags.get("omit-version")
  let mut watch_interval_ms = 500
  if first_match_value(matches, "interval") is Some(value) {
    watch_interval_ms = parse_interval_ms(value, watch_interval_ms)
  }
  let output_option = first_match_value(matches, "output")
  let paths = match_values(matches, "paths")
  if from_stdin && paths.length() > 0 {
    return Err("Error: positional input/output cannot be used with --stdin.")
  }
  let mut input_path : String? = None
  let mut output_path : String? = None
  if from_stdin {
    input_path = None
    output_path = output_option
  } else {
    if paths.length() == 0 {
      return Err("Error: render requires an input file, or use --stdin.")
    }
    input_path = Some(paths[0])
    if paths[0] == "-" {
      return Err("Error: '-' input is not supported. Use --stdin instead.")
    }
    if paths.length() > 1 {
      output_path = Some(paths[1])
    }
    if output_option is Some(option_output) {
      if output_path is Some(_) {
        return Err(
          "Error: output path cannot be provided both positionally and with --output.",
        )
      }
      output_path = Some(option_output)
    }
    if output_path is None {
      output_path = if output_mode_explicit {
        Some(replace_extension(paths[0], output_extension(output_mode)))
      } else {
        Some(replace_extension(paths[0], ".svg"))
      }
    }
  }
  if watch && from_stdin {
    return Err("Error: --watch cannot be used with --stdin.")
  }
  if watch && output_path is Some(path) && is_stdout_output_path(path) {
    return Err("Error: --watch output path cannot be stdout ('-').")
  }
  if output_path is Some(path) && !is_stdout_output_path(path) {
    if !output_mode_explicit {
      if infer_output_mode_from_path(path) is Some(mode) {
        output_mode = mode
      }
    } else if infer_output_mode_from_path(path) is Some(inferred) {
      if !is_output_mode_extension_compatible(output_mode, inferred) {
        return Err(
          "Error: output path extension conflicts with --format '\{output_mode_name(output_mode)}'.",
        )
      }
    }
  }
  let request : RenderRequest = {
    input_path,
    output_path,
    from_stdin,
    output_mode,
    layout_engine,
    layout_explicit,
    target_spec,
    theme_name,
    dark_theme_id,
    sketch,
    pad,
    center,
    theme_overrides,
    dark_theme_overrides,
    scale,
    bundle,
    no_xml_tag,
    salt,
    omit_version,
    watch,
    watch_interval_ms,
  }
  Ok(request)
}

///|
fn is_output_mode_extension_compatible(
  explicit_mode : OutputMode,
  inferred_mode : OutputMode,
) -> Bool {
  explicit_mode == inferred_mode
}

///|
fn parse_fmt_request(matches : @argparse.Matches) -> Result[FmtRequest, String] {
  let files = match_values(matches, "files")
  if files.is_empty() {
    return Err("Error: fmt requires at least one file path.")
  }
  let request : FmtRequest = {
    check: matches.flags.get_or_default("check", false),
    files,
  }
  Ok(request)
}

///|
fn parse_validate_request(
  matches : @argparse.Matches,
) -> Result[ValidateRequest, String] {
  let from_stdin = matches.flags.get_or_default("stdin", false)
  let paths = match_values(matches, "paths")
  if from_stdin && paths.length() > 0 {
    return Err("Error: positional input cannot be used with --stdin.")
  }
  if !from_stdin && paths.length() != 1 {
    return Err("Error: validate requires one input path, or use --stdin.")
  }
  if !from_stdin && paths[0] == "-" {
    return Err("Error: '-' input is not supported. Use --stdin instead.")
  }
  let input_path = if from_stdin { None } else { Some(paths[0]) }
  let request : ValidateRequest = { input_path, from_stdin }
  Ok(request)
}

///|
fn parse_layout_request(
  matches : @argparse.Matches,
) -> Result[LayoutRequest, String] {
  let paths = match_values(matches, "engine")
  if paths.length() > 1 {
    return Err("Error: layout accepts at most one engine name.")
  }
  let engine_name = if paths.length() == 1 { Some(paths[0]) } else { None }
  if engine_name is Some(name) && parse_layout_engine(name) is None {
    return Err(
      "Error: unsupported layout engine '\{name}'. Expected dagre, elk, or railway.",
    )
  }
  let request : LayoutRequest = { engine_name, }
  Ok(request)
}

///|
fn parse_internal_dump_input_request(
  matches : @argparse.Matches,
) -> Result[DumpInputRequest, String] {
  let dump_engine = match first_match_value(matches, "engine") {
    Some(value) =>
      match parse_dump_input_engine(value) {
        Some(engine) => engine
        None =>
          return Err(
            "Error: unsupported dump engine '\{value}'. Expected elk or dagre.",
          )
      }
    None => DumpInputEngine::Elk
  }
  guard first_match_value(matches, "out-dir") is Some(out_dir) else {
    return Err("Error: --out-dir is required.")
  }
  let request : DumpInputRequest = {
    engine: dump_engine,
    out_dir,
    input_paths: match_values(matches, "paths"),
  }
  Ok(request)
}

///|
fn parse_output_mode(value : String) -> OutputMode? {
  parse_stdout_format(value)
}

///|
fn legacy_cli_error(raw_args : Array[String]) -> String? {
  if raw_args.length() <= 1 {
    return None
  }
  let command = raw_args[1]
  if command == "--version" || command == "-v" {
    return Some("Error: global --version was removed. Use: diago version")
  }
  if command == "watch" {
    return Some(
      "Error: 'watch' command has been removed. Use: diago render --watch <input> [output].",
    )
  }
  if command == "dump-input" {
    return Some(
      "Error: 'dump-input' is no longer a public CLI command. Use scripts/dump_layout_input.sh for internal diagnostics.",
    )
  }
  for arg in raw_args[1:] {
    if arg == "--ascii" || arg == "-a" || arg == "--unicode" || arg == "-u" {
      return Some(
        "Error: --ascii/--unicode were removed. Use: diago render --format ascii|unicode ...",
      )
    }
    if arg == "--stdout-format" || arg.has_prefix("--stdout-format=") {
      return Some(
        "Error: --stdout-format was removed. Use: diago render --format ...",
      )
    }
    if arg == "--list-themes" {
      return Some("Error: --list-themes was removed. Use: diago themes")
    }
  }
  if command != "render" &&
    command != "fmt" &&
    command != "validate" &&
    command != "layout" &&
    command != "themes" &&
    command != "version" &&
    command != "__dump-input" &&
    !command.has_prefix("-") {
    return Some(
      "Error: direct render entry was removed. Use: diago render <input> [output].",
    )
  }
  None
}
