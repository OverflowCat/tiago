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
  Elk
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
  theme_overrides : @diagram.ThemeOverrides?
  dark_theme_overrides : @diagram.ThemeOverrides?
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
    theme_overrides: None,
    dark_theme_overrides: None,
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
  theme_overrides : @diagram.ThemeOverrides?,
) -> CompileOptions {
  { ..self, theme_overrides, }
}

///|
pub fn CompileOptions::with_dark_theme_overrides(
  self : CompileOptions,
  dark_theme_overrides : @diagram.ThemeOverrides?,
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
  match
    @compiler.compile_ir(
      source,
      options=to_compiler_parse_options(resolve_parse_options(options)),
    ) {
    Ok(ir_map) => ir_map
    Err(err) => raise_diago_compiler_error(err)
  }
}

///|
pub fn parse_file(
  file_path : String,
  options? : ParseOptions = ParseOptions::new(),
) -> @ir.Map raise DiagoError {
  let source = read_source_file(file_path)
  match
    @compiler.compile_ir(
      source,
      options=to_compiler_parse_options(
        resolve_parse_options_for_file(file_path, options),
      ),
    ) {
    Ok(ir_map) => ir_map
    Err(err) => raise_diago_compiler_error(err)
  }
}

///|
pub fn compile_diagram(
  source : String,
  options? : CompileOptions = CompileOptions::new(),
) -> @diagram.Diagram raise DiagoError {
  let compiled = match
    @compiler.compile_graph(
      "diagram",
      source,
      options=to_compiler_parse_options(
        resolve_parse_options(options.parse_options),
      ),
    ) {
    Ok(compiled) => compiled
    Err(err) => raise_diago_compiler_error(err)
  }
  match
    @lib.compile_diagram(
      compiled.graph_input(),
      compiled.source_config(),
      options=to_lib_diagram_options(options),
    ) {
    Ok(diagram) => diagram
    Err(err) => raise_diago_lib_error(err)
  }
}

///|
pub fn compile(
  source : String,
  options? : CompileOptions = CompileOptions::new(),
) -> String raise DiagoError {
  let diagram = compile_diagram(source, options~)
  match @lib.render(diagram, options=to_lib_render_options(options)) {
    Ok(rendered) => rendered
    Err(err) => raise_diago_lib_error(err)
  }
}

///|
pub fn compile_file(
  file_path : String,
  options? : CompileOptions = CompileOptions::new(),
) -> String raise DiagoError {
  let source = read_source_file(file_path)
  let compiled = match
    @compiler.compile_graph(
      "diagram",
      source,
      options=to_compiler_parse_options(
        resolve_parse_options_for_file(file_path, options.parse_options),
      ),
    ) {
    Ok(compiled) => compiled
    Err(err) => raise_diago_compiler_error(err)
  }
  let diagram = match
    @lib.compile_diagram(
      compiled.graph_input(),
      compiled.source_config(),
      options=to_lib_diagram_options(options),
    ) {
    Ok(diagram) => diagram
    Err(err) => raise_diago_lib_error(err)
  }
  match @lib.render(diagram, options=to_lib_render_options(options)) {
    Ok(rendered) => rendered
    Err(err) => raise_diago_lib_error(err)
  }
}

///|
fn to_compiler_parse_options(options : ParseOptions) -> @compiler.ParseOptions {
  @compiler.ParseOptions::new().with_import_resolver(options.import_resolver)
}

///|
fn to_lib_diagram_options(options : CompileOptions) -> @lib.DiagramOptions {
  let mut resolved = @lib.DiagramOptions::new()
    .with_layout_engine(to_lib_layout_engine(options.layout_engine))
    .with_direction(options.direction)
    .with_target_spec(options.target_spec)
  match options.layout_plugin {
    Some(plugin) =>
      resolved = resolved.with_layout_plugin(
        Some(fn(
          graph : @graph.GraphInput,
          config : @engine_api.LayoutConfig,
          direction : @engine_api.Direction,
        ) -> Result[@graph.GraphInput, String] {
          plugin.run(graph, config, direction)
        }),
      )
    None => ()
  }
  match options.route_plugin {
    Some(plugin) =>
      resolved = resolved.with_route_plugin(
        Some(fn(
          graph : @graph.GraphInput,
        ) -> Result[@graph.GraphInput, String] {
          plugin.run(graph)
        }),
      )
    None => ()
  }
  resolved
}

///|
fn to_lib_render_options(options : CompileOptions) -> @lib.RenderOptions {
  @lib.RenderOptions::new()
  .with_output_mode(to_lib_output_mode(options.output_mode))
  .with_theme_name(options.theme_name)
  .with_dark_theme_id(options.dark_theme_id)
  .with_theme_overrides(options.theme_overrides)
  .with_dark_theme_overrides(options.dark_theme_overrides)
  .with_scale(options.scale)
  .with_no_xml_tag(options.no_xml_tag)
  .with_salt(options.salt)
  .with_omit_version(options.omit_version)
}

///|
fn to_lib_layout_engine(layout_engine : LayoutEngine) -> @lib.LayoutEngine {
  match layout_engine {
    Auto => @lib.Auto
    Dagre => @lib.Dagre
    Elk => @lib.Elk
    Railway => @lib.Railway
  }
}

///|
fn to_lib_output_mode(output_mode : OutputMode) -> @lib.OutputMode {
  match output_mode {
    Svg => @lib.Svg
    Ascii => @lib.Ascii
    Unicode => @lib.Unicode
  }
}

///|
fn[T] raise_diago_compiler_error(
  err : @compiler.CompileError,
) -> T raise DiagoError {
  match err {
    @compiler.ParseError(message) => raise ParseError(message)
    @compiler.IOError(message) => raise IOError(message)
    @compiler.IrError(message) => raise IrError(message)
    @compiler.GraphError(message) => raise GraphError(message)
    @compiler.ConfigError(message) => raise ConfigError(message)
  }
}

///|
fn[T] raise_diago_lib_error(err : @lib.LibError) -> T raise DiagoError {
  match err {
    @lib.LayoutError(message) => raise LayoutError(message)
    @lib.RenderError(message) => raise RenderError(message)
    @lib.ConfigError(message) => raise ConfigError(message)
    @lib.TargetError(message) => raise TargetError(message)
  }
}
