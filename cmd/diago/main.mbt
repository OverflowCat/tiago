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
/// Usage: diago [options] <input> [output]

///|
enum OutputMode {
  Svg
  Ascii
  Unicode
} derive(Show, Eq)

///|
fn output_extension(mode : OutputMode) -> String {
  match mode {
    OutputMode::Svg => ".svg"
    OutputMode::Ascii => ".ascii.txt"
    OutputMode::Unicode => ".unicode.txt"
  }
}

///|
fn output_mode_name(mode : OutputMode) -> String {
  match mode {
    OutputMode::Svg => "svg"
    OutputMode::Ascii => "ascii"
    OutputMode::Unicode => "unicode"
  }
}

///|
fn parse_stdout_format(value : String) -> OutputMode? {
  match value.to_lower() {
    "svg" => Some(OutputMode::Svg)
    "ascii" => Some(OutputMode::Ascii)
    "unicode" => Some(OutputMode::Unicode)
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
  } else {
    None
  }
}

///|
fn is_stdout_output_path(path : String) -> Bool {
  path == "-"
}

///|
enum LayoutEngineChoice {
  Dagre
  Elk
  Railway
} derive(Show, Eq)

///|
enum DumpInputEngine {
  Dagre
  Elk
} derive(Show, Eq)

///|
priv struct CompiledSourceResult {
  output : String
  warning : String?
}

///|
fn parse_layout_engine(name : String) -> LayoutEngineChoice? {
  match name.to_lower() {
    "dagre" => Some(LayoutEngineChoice::Dagre)
    "elk" => Some(LayoutEngineChoice::Elk)
    "railway" => Some(LayoutEngineChoice::Railway)
    _ => None
  }
}

///|
fn layout_engine_name(engine : LayoutEngineChoice) -> String {
  match engine {
    LayoutEngineChoice::Dagre => "dagre"
    LayoutEngineChoice::Elk => "elk"
    LayoutEngineChoice::Railway => "railway"
  }
}

///|
fn parse_dump_input_engine(name : String) -> DumpInputEngine? {
  match name.to_lower() {
    "dagre" => Some(DumpInputEngine::Dagre)
    "elk" => Some(DumpInputEngine::Elk)
    _ => None
  }
}

///|
fn main {
  run_cli(@sys.get_cli_args(), @sys.get_env_vars())
}

///|
fn write_compiled_output(
  _output_mode : OutputMode,
  output_path : String?,
  output : String,
) -> Result[Unit, String] {
  match output_path {
    Some(path) => write_output(path, output)
    None => {
      println(output)
      Ok(())
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
fn collect_default_dump_input_sources() -> Result[Array[String], String] {
  let entries = @fs.read_dir("examples") catch {
    e => return Err("Error reading directory 'examples': \{e}")
  }
  let paths : Array[String] = []
  for entry in entries {
    if entry.has_suffix(".d2") {
      paths.push(@path.Path("examples").join(@path.Path(entry)).to_string())
    }
  }
  paths.sort_by(fn(a, b) { a.compare(b) })
  Ok(paths)
}

///|
fn ensure_dir_recursive(path : String) -> Result[Unit, String] {
  if path.length() == 0 || path == "." {
    return Ok(())
  }
  if @fs.path_exists(path) {
    let exists_as_dir = @fs.is_dir(path) catch { _ => false }
    if exists_as_dir {
      return Ok(())
    }
    return Err("Path '\{path}' exists and is not a directory")
  }
  let parent = @path.Path(path).dirname().to_string()
  if parent.length() > 0 && parent != path {
    match ensure_dir_recursive(parent) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  @fs.create_dir(path) catch {
    e => {
      let exists_as_dir = if @fs.path_exists(path) {
        @fs.is_dir(path) catch {
          _ => false
        }
      } else {
        false
      }
      if exists_as_dir {
        return Ok(())
      }
      return Err("Error creating directory '\{path}': \{e}")
    }
  }
  Ok(())
}

///|
fn dump_input_for_file(
  input_path : String,
  out_dir : String,
  dump_engine : DumpInputEngine,
) -> Result[String, String] {
  let source = @fs.read_file_to_string(input_path) catch {
    e => return Err("Error reading file '\{input_path}': \{e}")
  }
  let (ast, parse_errors) = @compiler.parse(source)
  if !parse_errors.is_empty() {
    return Err("Parse errors in '\{input_path}': \{parse_errors}")
  }

  let resolver = create_import_resolver(get_dir_path(input_path))
  let ir = @ir.compile_with_imports(ast, resolver) catch {
    e => return Err("IR error in '\{input_path}': \{e}")
  }
  let graph_input = @exporter.to_graph("diagram", ir) catch {
    e => return Err("Graph error in '\{input_path}': \{e}")
  }

  let input_json = match dump_engine {
    DumpInputEngine::Elk =>
      @engine_elk.debug_build_elk_input_json(
        graph_input,
        @engine_api.LayoutConfig::new(),
        @engine_api.Down,
      )
    DumpInputEngine::Dagre =>
      @engine_dagre.debug_build_dagre_input_json(
        graph_input,
        @engine_api.LayoutConfig::new(),
        @engine_api.Down,
      ) catch {
        e => return Err("Dagre input build error in '\{input_path}': \{e}")
      }
  }
  let output_name = replace_extension(basename_string(input_path), ".json")
  let out_path = @path.Path(out_dir).join(@path.Path(output_name)).to_string()
  @fs.write_string_to_file(out_path, input_json.stringify(escape_slash=false)) catch {
    e => return Err("Error writing file '\{out_path}': \{e}")
  }
  Ok(out_path)
}

///|
fn basename_string(path : String) -> String {
  @path.Path(path).basename().to_string()
}

///|
/// Run the watch subcommand
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
fn merge_theme_overrides(
  dst : @diagram.ThemeOverrides?,
  src : @diagram.ThemeOverrides?,
) -> @diagram.ThemeOverrides? {
  @diagram.merge_theme_overrides(dst, src)
}

///|
fn parse_override_pairs(raw : String) -> @diagram.ThemeOverrides? {
  let mut out = @diagram.ThemeOverrides::new()
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
      out = out.with_code(key, value)
    }
  }
  if out.is_empty() {
    None
  } else {
    Some(out)
  }
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
fn list_themes() -> Unit {
  println("Available themes:")
  for name in @renderer_svg.list_themes() {
    println("  \{name}")
  }
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
  dark_theme_id? : Int? = None,
  sketch? : Bool? = None,
  pad? : Double? = None,
  center? : Bool? = None,
  theme_overrides? : @diagram.ThemeOverrides? = None,
  dark_theme_overrides? : @diagram.ThemeOverrides? = None,
  scale? : Double? = None,
  bundle? : Bool = false,
  no_xml_tag? : Bool? = None,
  salt? : String? = None,
  omit_version? : Bool? = None,
) -> Result[String, String] {
  match
    compile_source_with_warnings(
      source,
      output_mode,
      theme_name,
      base_path,
      layout_engine,
      layout_explicit,
      target_spec,
      dark_theme_id~,
      sketch~,
      pad~,
      center~,
      theme_overrides~,
      dark_theme_overrides~,
      scale~,
      bundle~,
      no_xml_tag~,
      salt~,
      omit_version~,
    ) {
    Ok(result) =>
      match result.warning {
        Some(warning) => Err(warning)
        None => Ok(result.output)
      }
    Err(err) => Err(err)
  }
}

///|
fn compile_source_with_warnings(
  source : String,
  output_mode : OutputMode,
  theme_name : String?,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
  dark_theme_id? : Int? = None,
  sketch? : Bool? = None,
  pad? : Double? = None,
  center? : Bool? = None,
  theme_overrides? : @diagram.ThemeOverrides? = None,
  dark_theme_overrides? : @diagram.ThemeOverrides? = None,
  scale? : Double? = None,
  bundle? : Bool = false,
  no_xml_tag? : Bool? = None,
  salt? : String? = None,
  omit_version? : Bool? = None,
) -> Result[CompiledSourceResult, String] {
  match output_mode {
    OutputMode::Svg =>
      compile_diago_svg_with_warnings(
        source,
        theme_name,
        base_path,
        layout_engine,
        layout_explicit,
        target_spec,
        dark_theme_id~,
        sketch~,
        pad~,
        center~,
        theme_overrides~,
        dark_theme_overrides~,
        scale~,
        bundle~,
        no_xml_tag~,
        salt~,
        omit_version~,
      )
    OutputMode::Ascii =>
      match
        compile_diago_ascii(
          source, base_path, layout_engine, layout_explicit, target_spec,
        ) {
        Ok(output) => Ok({ output, warning: None })
        Err(err) => Err(err)
      }
    OutputMode::Unicode =>
      match
        compile_diago_unicode(
          source, base_path, layout_engine, layout_explicit, target_spec,
        ) {
        Ok(output) => Ok({ output, warning: None })
        Err(err) => Err(err)
      }
  }
}

///|
fn compile_diago_svg_with_warnings(
  source : String,
  theme_name : String?,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
  dark_theme_id? : Int? = None,
  sketch? : Bool? = None,
  pad? : Double? = None,
  center? : Bool? = None,
  theme_overrides? : @diagram.ThemeOverrides? = None,
  dark_theme_overrides? : @diagram.ThemeOverrides? = None,
  scale? : Double? = None,
  bundle? : Bool = false,
  no_xml_tag? : Bool? = None,
  salt? : String? = None,
  omit_version? : Bool? = None,
) -> Result[CompiledSourceResult, String] {
  match
    compile_to_diagram(
      source, base_path, layout_engine, layout_explicit, target_spec,
    ) {
    Ok(diagram) => {
      let cache_images = bundle_cache_enabled()
      let render_config = resolve_svg_config(
        theme_name,
        diagram.config,
        dark_theme_id~,
        sketch~,
        pad~,
        center~,
        theme_overrides~,
        dark_theme_overrides~,
        scale~,
        no_xml_tag~,
        salt~,
        omit_version~,
      )
      let diagram = diagram.with_render_hash_config(
        render_config.theme_id,
        render_config.dark_theme_id,
        render_config.sketch,
      )
      try @renderer_svg.render(diagram, render_config) catch {
        e => Err(e.to_string())
      } noraise {
        v => {
          let local_result = bundle_local_svg_images(
            v,
            base_path,
            cache_images~,
          )
          let remote_result = if bundle {
            bundle_remote_svg_images(local_result.svg, cache_images~)
          } else {
            { svg: local_result.svg, error: None }
          }
          Ok({
            output: remote_result.svg,
            warning: combine_compilation_warning(
              local_result.error,
              remote_result.error,
            ),
          })
        }
      }
    }
    Err(e) => Err(e)
  }
}

///|
fn bundle_cache_enabled() -> Bool {
  match @sys.get_env_var("IMG_CACHE") {
    Some(value) => value == "1"
    None => false
  }
}

///|
fn combine_compilation_warning(first : String?, second : String?) -> String? {
  match first {
    Some(a) =>
      match second {
        Some(b) => Some(a + "; " + b)
        None => Some(a)
      }
    None => second
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
) -> Result[String, String] {
  match
    compile_to_diagram(
      source, base_path, layout_engine, layout_explicit, target_spec,
    ) {
    Ok(diagram) =>
      Ok(@renderer_ascii.render(diagram, @renderer_ascii.AsciiConfig::new()))
    Err(e) => Err(e)
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
  let base_graph_input = @exporter.to_graph("diagram", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let graph_input = @graph.GraphInput::from_parts(
    base_graph_input.name,
    base_graph_input.root,
    base_graph_input.objects,
    base_graph_input.edges,
    base_graph_input.sequence_fragments,
    base_graph_input.activation_boxes,
    base_graph_input.sequence_notes,
    base_graph_input.sequence_fragments_layout,
    base_graph_input.layers,
    base_graph_input.scenarios,
    base_graph_input.steps,
    base_graph_input.legend,
    is_folder_only=base_graph_input.is_folder_only,
    data=graph_data_from_source_config(source_config),
  )
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
    LayoutEngineChoice::Elk =>
      @engine_api.layout_with_engine(
        @engine_elk.ElkEngine::new(),
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
  sketch? : Bool? = None,
  pad? : Double? = None,
  center? : Bool? = None,
  theme_overrides? : @diagram.ThemeOverrides? = None,
  dark_theme_overrides? : @diagram.ThemeOverrides? = None,
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
  let effective_sketch = match sketch {
    Some(v) => v
    None =>
      match source_config {
        Some(config) => config.sketch.unwrap_or(false)
        None => false
      }
  }
  let mut resolved = match theme_name {
    Some(name) => @renderer_svg.SvgConfig::with_theme_name(name)
    None =>
      match source_theme_id {
        Some(theme_id) => @renderer_svg.SvgConfig::with_theme(theme_id)
        None => @renderer_svg.SvgConfig::new()
      }
  }
  let effective_pad = match pad {
    Some(v) => Some(v)
    None =>
      match source_config {
        Some(config) => config.pad
        None => None
      }
  }
  match effective_pad {
    Some(pad_value) => resolved = resolved.with_padding(pad_value)
    None => ()
  }

  let source_theme_overrides = match source_config {
    Some(config) => config.theme_overrides
    None => None
  }
  let source_dark_theme_overrides = match source_config {
    Some(config) => config.dark_theme_overrides
    None => None
  }
  let merged_theme_overrides = merge_theme_overrides(
    source_theme_overrides, theme_overrides,
  )
  let merged_dark_theme_overrides = merge_theme_overrides(
    source_dark_theme_overrides, dark_theme_overrides,
  )

  let effective_scale = match scale {
    Some(v) => Some(v)
    None =>
      match source_config {
        Some(config) => config.scale
        None => None
      }
  }
  let effective_center = match center {
    Some(v) => v
    None =>
      match source_config {
        Some(config) => config.center.unwrap_or(false)
        None => false
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
    effective_center, effective_sketch, effective_scale, effective_no_xml_tag, effective_salt,
    effective_omit_version,
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
                "Error: unsupported layout engine '\{layout_name}' from vars.d2-config.layout-engine. Expected dagre, elk, or railway.",
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
) -> Result[@diagram.ThemeOverrides?, String] {
  let mut overrides = @diagram.ThemeOverrides::new()
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
      overrides = overrides.with_code(key, color_value)
    }
  }
  if not(errors.is_empty()) {
    return Err(errors.join("; "))
  }
  if overrides.is_empty() {
    Ok(None)
  } else {
    Ok(Some(overrides))
  }
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
fn compile_config_data_map(
  data_map : @ir.Map,
) -> Map[String, @diagram.ConfigDataValue] {
  let data : Map[String, @diagram.ConfigDataValue] = {}
  for field in data_map.fields {
    if field.primary is Some(value) {
      data[field.name] = @diagram.ConfigDataValue::Text(value.to_string())
    } else if field.array() is Some(array) {
      let values : Array[String] = []
      for item in array.values {
        if item.as_scalar() is Some(scalar) {
          values.push(scalar.to_string())
        }
      }
      data[field.name] = @diagram.ConfigDataValue::StringArray(values)
    } else if field.has_composite() {
      data[field.name] = @diagram.ConfigDataValue::StringArray([])
    }
  }
  data
}

///|
fn graph_data_from_source_config(
  config : @diagram.Config?,
) -> Map[String, @graph.GraphDataValue] {
  let data : Map[String, @graph.GraphDataValue] = {}
  match config {
    Some(config) =>
      for key, value in config.data {
        data[key] = match value {
          @diagram.ConfigDataValue::Text(text) =>
            @graph.GraphDataValue::Text(text)
          @diagram.ConfigDataValue::StringArray(items) => {
            let copied : Array[String] = []
            for item in items {
              copied.push(item)
            }
            @graph.GraphDataValue::StringArray(copied)
          }
        }
      }
    None => ()
  }
  data
}

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
  let mut theme_overrides : @diagram.ThemeOverrides? = None
  let mut dark_theme_overrides : @diagram.ThemeOverrides? = None
  let mut pad : Double? = None
  let mut center : Bool? = None
  let mut layout_engine : String? = None
  let mut scale : Double? = None
  let mut no_xml_tag : Bool? = None
  let mut salt : String? = None
  let mut omit_version : Bool? = None
  let data : Map[String, @diagram.ConfigDataValue] = {}
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
      theme_overrides = merge_theme_overrides(theme_overrides, overrides)
    }
  }
  if config_map.get_field("dark-theme-overrides")
    is Some(dark_theme_overrides_field) {
    if dark_theme_overrides_field.map() is Some(overrides_map) {
      let overrides = match compile_theme_overrides_map(overrides_map) {
        Ok(parsed) => parsed
        Err(e) => return Err(e)
      }
      dark_theme_overrides = merge_theme_overrides(
        dark_theme_overrides, overrides,
      )
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
      for key, value in compile_config_data_map(data_map) {
        data[key] = value
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
      let selection = match parse_target_selection(spec) {
        Ok(selection) => selection
        Err(message) => return Err(message)
      }
      let target = if selection.path.length() == 0 {
        diagram
      } else {
        match diagram.get_board(selection.path) {
          Some(board) => board
          None => return Err("Target board not found: \{spec}")
        }
      }
      if selection.no_children {
        Ok(target.without_children())
      } else {
        Ok(target)
      }
    }
  }
}

///|
priv struct TargetSelection {
  path : Array[String]
  no_children : Bool
}

///|
fn parse_target_selection(spec : String) -> Result[TargetSelection, String] {
  if spec == "*" {
    return Ok({ path: [], no_children: false })
  }
  if spec.length() == 0 {
    return Ok({ path: [], no_children: true })
  }
  let no_children = !spec.has_suffix(".*")
  let target = if no_children {
    spec
  } else {
    spec[:spec.length() - 2].to_string()
  }
  if target.length() == 0 {
    return Ok({ path: [], no_children })
  }
  match @parser.parse_key_path(target) {
    Ok(key_path) => Ok({ path: key_path.to_strings(), no_children })
    Err(_) => Err("Invalid target: \{spec}")
  }
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
    // Add the default source extension if not present.
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
