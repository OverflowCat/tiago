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
/// Public facade API for parsing and compiling diago sources.

///|
pub(all) enum OutputMode {
  Svg
  Ascii
  Unicode
} derive(Show, Eq)

///|
pub(all) enum LayoutEngine {
  Auto
  Dagre
  Railway
} derive(Show, Eq)

///|
pub struct ParseOptions {
  base_path : String?
  import_resolver : @ir.ImportResolver?
}

///|
pub fn ParseOptions::new() -> ParseOptions {
  { base_path: None, import_resolver: None }
}

///|
pub fn ParseOptions::with_base_path(
  self : ParseOptions,
  base_path : String?,
) -> ParseOptions {
  { ..self, base_path, }
}

///|
pub fn ParseOptions::with_import_resolver(
  self : ParseOptions,
  import_resolver : @ir.ImportResolver?,
) -> ParseOptions {
  { ..self, import_resolver, }
}

///|
pub struct LayoutPlugin(
  (@graph.GraphInput, @engine_api.LayoutConfig, @engine_api.Direction) -> Result[
    @graph.GraphInput,
    String,
  ]
)

///|
pub fn LayoutPlugin::new(
  f : (@graph.GraphInput, @engine_api.LayoutConfig, @engine_api.Direction) -> Result[
    @graph.GraphInput,
    String,
  ],
) -> LayoutPlugin {
  LayoutPlugin(f)
}

///|
pub fn LayoutPlugin::run(
  self : LayoutPlugin,
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> Result[@graph.GraphInput, String] {
  let LayoutPlugin(f) = self
  f(graph, config, direction)
}

///|
pub struct RoutePlugin((@graph.GraphInput) -> Result[@graph.GraphInput, String])

///|
pub fn RoutePlugin::new(
  f : (@graph.GraphInput) -> Result[@graph.GraphInput, String],
) -> RoutePlugin {
  RoutePlugin(f)
}

///|
pub fn RoutePlugin::run(
  self : RoutePlugin,
  graph : @graph.GraphInput,
) -> Result[@graph.GraphInput, String] {
  let RoutePlugin(f) = self
  f(graph)
}

///|
pub struct CompileOptions {
  output_mode : OutputMode
  layout_engine : LayoutEngine
  direction : @engine_api.Direction
  target_spec : String?
  layout_plugin : LayoutPlugin?
  route_plugin : RoutePlugin?
  parse_options : ParseOptions
  theme_name : String?
  dark_theme_id : Int?
  theme_overrides : Map[String, String]
  dark_theme_overrides : Map[String, String]
  scale : Double?
  no_xml_tag : Bool?
  salt : String?
  omit_version : Bool?
}

///|
pub fn CompileOptions::new() -> CompileOptions {
  {
    output_mode: Svg,
    layout_engine: Auto,
    direction: @engine_api.Down,
    target_spec: None,
    layout_plugin: None,
    route_plugin: None,
    parse_options: ParseOptions::new(),
    theme_name: None,
    dark_theme_id: None,
    theme_overrides: {},
    dark_theme_overrides: {},
    scale: None,
    no_xml_tag: None,
    salt: None,
    omit_version: None,
  }
}

///|
pub fn CompileOptions::with_output_mode(
  self : CompileOptions,
  output_mode : OutputMode,
) -> CompileOptions {
  { ..self, output_mode, }
}

///|
pub fn CompileOptions::with_layout_engine(
  self : CompileOptions,
  layout_engine : LayoutEngine,
) -> CompileOptions {
  { ..self, layout_engine, }
}

///|
pub fn CompileOptions::with_direction(
  self : CompileOptions,
  direction : @engine_api.Direction,
) -> CompileOptions {
  { ..self, direction, }
}

///|
pub fn CompileOptions::with_target_spec(
  self : CompileOptions,
  target_spec : String?,
) -> CompileOptions {
  { ..self, target_spec, }
}

///|
pub fn CompileOptions::with_layout_plugin(
  self : CompileOptions,
  layout_plugin : LayoutPlugin?,
) -> CompileOptions {
  { ..self, layout_plugin, }
}

///|
pub fn CompileOptions::with_route_plugin(
  self : CompileOptions,
  route_plugin : RoutePlugin?,
) -> CompileOptions {
  { ..self, route_plugin, }
}

///|
pub fn CompileOptions::with_parse_options(
  self : CompileOptions,
  parse_options : ParseOptions,
) -> CompileOptions {
  { ..self, parse_options, }
}

///|
pub fn CompileOptions::with_theme_name(
  self : CompileOptions,
  theme_name : String?,
) -> CompileOptions {
  { ..self, theme_name, }
}

///|
pub fn CompileOptions::with_dark_theme_id(
  self : CompileOptions,
  dark_theme_id : Int?,
) -> CompileOptions {
  { ..self, dark_theme_id, }
}

///|
pub fn CompileOptions::with_theme_overrides(
  self : CompileOptions,
  theme_overrides : Map[String, String],
) -> CompileOptions {
  { ..self, theme_overrides, }
}

///|
pub fn CompileOptions::with_dark_theme_overrides(
  self : CompileOptions,
  dark_theme_overrides : Map[String, String],
) -> CompileOptions {
  { ..self, dark_theme_overrides, }
}

///|
pub fn CompileOptions::with_scale(
  self : CompileOptions,
  scale : Double?,
) -> CompileOptions {
  { ..self, scale, }
}

///|
pub fn CompileOptions::with_no_xml_tag(
  self : CompileOptions,
  no_xml_tag : Bool?,
) -> CompileOptions {
  { ..self, no_xml_tag, }
}

///|
pub fn CompileOptions::with_salt(
  self : CompileOptions,
  salt : String?,
) -> CompileOptions {
  { ..self, salt, }
}

///|
pub fn CompileOptions::with_omit_version(
  self : CompileOptions,
  omit_version : Bool?,
) -> CompileOptions {
  { ..self, omit_version, }
}

///|
pub(all) suberror DiagoError {
  ParseError(String)
  IOError(String)
  IrError(String)
  GraphError(String)
  LayoutError(String)
  RenderError(String)
  ConfigError(String)
  TargetError(String)
} derive(Eq, Show)

///|
pub fn parse(
  source : String,
  options? : ParseOptions = ParseOptions::new(),
) -> @ir.Map raise DiagoError {
  let (ast, errors) = @compiler.parse(source)
  if !errors.is_empty() {
    raise ParseError("Parse errors: \{errors}")
  }
  let resolver = match options.import_resolver {
    Some(resolver) => resolver
    None => default_import_resolver(options.base_path)
  }
  @ir.compile_with_imports(ast, resolver) catch {
    e => raise IrError(e.to_string())
  }
}

///|
pub fn parse_file(
  file_path : String,
  options? : ParseOptions = ParseOptions::new(),
) -> @ir.Map raise DiagoError {
  let source = @fs.read_file_to_string(file_path) catch {
    e => raise IOError("Error reading file '\{file_path}': \{e}")
  }
  let resolved_options = if options.base_path is Some(_) {
    options
  } else {
    { ..options, base_path: get_dir_path(file_path) }
  }
  parse(source, options=resolved_options)
}

///|
pub fn compile_diagram(
  source : String,
  options? : CompileOptions = CompileOptions::new(),
) -> @diagram.Diagram raise DiagoError {
  let ir_map = parse(source, options=options.parse_options)
  let source_config = extract_source_config(ir_map)
  let effective_layout_engine = resolve_layout_engine(
    options.layout_engine,
    source_config,
  )
  let graph_input = @exporter.to_graph("diagram", ir_map) catch {
    e => raise GraphError(e.to_string())
  }
  let config = @engine_api.LayoutConfig::new()
  let laid_out_graph = match options.layout_plugin {
    Some(plugin) =>
      match plugin.run(graph_input, config, options.direction) {
        Ok(graph) => graph
        Err(e) => raise LayoutError("Layout plugin error: \{e}")
      }
    None =>
      match effective_layout_engine {
        Auto | Dagre =>
          @engine_api.layout_with_engine(
            @engine_dagre.DagreEngine::new(),
            graph_input,
            config,
            options.direction,
          ) catch {
            e => raise LayoutError(e.to_string())
          }
        Railway =>
          @engine_api.layout_with_engine(
            @engine_railway.RailwayEngine::new(),
            graph_input,
            config,
            options.direction,
          ) catch {
            e => raise LayoutError(e.to_string())
          }
      }
  }
  let routed_graph = match options.route_plugin {
    Some(plugin) =>
      match plugin.run(laid_out_graph) {
        Ok(graph) => graph
        Err(e) => raise LayoutError("Route plugin error: \{e}")
      }
    None => laid_out_graph
  }
  let diagram = @diagram.from_graph(routed_graph, source_config)
  match select_target_board(diagram, options.target_spec) {
    Ok(board) => board
    Err(e) => raise TargetError(e)
  }
}

///|
pub fn compile(
  source : String,
  options? : CompileOptions = CompileOptions::new(),
) -> String raise DiagoError {
  let diagram = compile_diagram(source, options~)
  match options.output_mode {
    Svg => {
      let render_config = resolve_svg_config(options, diagram.config)
      @renderer_svg.render(diagram, render_config) catch {
        e => raise RenderError(e.to_string())
      }
    }
    Ascii => @renderer_ascii.render(diagram, @renderer_ascii.AsciiConfig::new())
    Unicode => @renderer_unicode.render(diagram)
  }
}

///|
pub fn compile_file(
  file_path : String,
  options? : CompileOptions = CompileOptions::new(),
) -> String raise DiagoError {
  let source = @fs.read_file_to_string(file_path) catch {
    e => raise IOError("Error reading file '\{file_path}': \{e}")
  }
  let parse_options = if options.parse_options.base_path is Some(_) {
    options.parse_options
  } else {
    { ..options.parse_options, base_path: get_dir_path(file_path) }
  }
  let resolved_options = { ..options, parse_options, }
  compile(source, options=resolved_options)
}

///|
fn resolve_layout_engine(
  requested_layout_engine : LayoutEngine,
  source_config : @diagram.Config?,
) -> LayoutEngine raise DiagoError {
  if requested_layout_engine != Auto {
    return requested_layout_engine
  }
  match source_config {
    Some(config) =>
      match config.layout_engine {
        Some(layout_name) =>
          match parse_layout_engine_name(layout_name) {
            Some(engine) => engine
            None =>
              raise ConfigError(
                "unsupported layout engine '\{layout_name}' from vars.d2-config.layout-engine. Expected dagre or railway.",
              )
          }
        None => Dagre
      }
    None => Dagre
  }
}

///|
fn parse_layout_engine_name(name : String) -> LayoutEngine? {
  match name.to_lower() {
    "auto" => Some(Auto)
    "dagre" => Some(Dagre)
    "railway" => Some(Railway)
    _ => None
  }
}

///|
fn resolve_svg_config(
  options : CompileOptions,
  source_config : @diagram.Config?,
) -> @renderer_svg.SvgConfig {
  let source_dark_theme_id = match source_config {
    Some(config) => config.dark_theme_id
    None => None
  }
  let effective_dark_theme_id = match options.dark_theme_id {
    Some(v) => Some(v)
    None => source_dark_theme_id
  }
  let resolved = match options.theme_name {
    Some(name) => @renderer_svg.SvgConfig::with_theme_name(name)
    None =>
      match source_config {
        Some(config) =>
          match config.theme_id {
            Some(theme_id) => @renderer_svg.SvgConfig::with_theme(theme_id)
            None =>
              match effective_dark_theme_id {
                Some(theme_id) => @renderer_svg.SvgConfig::with_theme(theme_id)
                None => @renderer_svg.SvgConfig::new()
              }
          }
        None =>
          match effective_dark_theme_id {
            Some(theme_id) => @renderer_svg.SvgConfig::with_theme(theme_id)
            None => @renderer_svg.SvgConfig::new()
          }
      }
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
  merge_theme_overrides(merged_theme_overrides, options.theme_overrides)
  merge_theme_overrides(
    merged_dark_theme_overrides,
    options.dark_theme_overrides,
  )
  let effective_scale = match options.scale {
    Some(v) => Some(v)
    None =>
      match source_config {
        Some(config) => config.scale
        None => None
      }
  }
  let effective_no_xml_tag = match options.no_xml_tag {
    Some(v) => v
    None =>
      match source_config {
        Some(config) => config.no_xml_tag.unwrap_or(false)
        None => false
      }
  }
  let effective_salt = match options.salt {
    Some(v) => Some(v)
    None =>
      match source_config {
        Some(config) => config.salt
        None => None
      }
  }
  let effective_omit_version = match options.omit_version {
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
fn merge_theme_overrides(
  dst : Map[String, String],
  src : Map[String, String],
) -> Unit {
  for key, value in src {
    dst[key] = value
  }
}

///|
fn extract_source_config(ir_map : @ir.Map) -> @diagram.Config? {
  let vars_map = match ir_map.get_field("vars") {
    Some(field) =>
      match field.map() {
        Some(map) => map
        None => return None
      }
    None => return None
  }
  let config_map = match vars_map.get_field("d2-config") {
    Some(field) =>
      match field.map() {
        Some(map) => map
        None => return None
      }
    None => return None
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
      for field in overrides_map.fields {
        if field.primary is Some(value) {
          theme_overrides[field.name.to_upper()] = value.to_string()
        }
      }
    }
  }
  if config_map.get_field("dark-theme-overrides")
    is Some(dark_theme_overrides_field) {
    if dark_theme_overrides_field.map() is Some(overrides_map) {
      for field in overrides_map.fields {
        if field.primary is Some(value) {
          dark_theme_overrides[field.name.to_upper()] = value.to_string()
        }
      }
    }
  }
  if config_map.get_field("pad") is Some(field) {
    if field.primary is Some(value) {
      pad = value.as_double()
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
  Some(
    @diagram.Config::from_parts(
      sketch, theme_id, dark_theme_id, theme_overrides, dark_theme_overrides, pad,
      center, layout_engine, scale, no_xml_tag, salt, omit_version, data,
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
fn default_import_resolver(base_path : String?) -> @ir.ImportResolver {
  @ir.ImportResolver::new(fn(import_path) {
    let full_path = match base_path {
      Some(base) => @path.Path(base).join(@path.Path(import_path)).to_string()
      None => import_path
    }
    let path_with_ext = if full_path.has_suffix(".d2") {
      full_path
    } else {
      full_path + ".d2"
    }
    Some(@fs.read_file_to_string(path_with_ext)) catch {
      _ => None
    }
  })
}

///|
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
