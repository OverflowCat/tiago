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
/// Library-layer orchestration for layout and rendering.

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
pub struct DiagramOptions {
  layout_engine : LayoutEngine
  direction : @engine_api.Direction
  target_spec : String?
  layout_plugin : ((
    @graph.GraphInput,
    @engine_api.LayoutConfig,
    @engine_api.Direction,
  ) -> Result[@graph.GraphInput, String])?
  route_plugin : ((@graph.GraphInput) -> Result[@graph.GraphInput, String])?
}

///|
pub fn DiagramOptions::new() -> DiagramOptions {
  {
    layout_engine: Auto,
    direction: @engine_api.Down,
    target_spec: None,
    layout_plugin: None,
    route_plugin: None,
  }
}

///|
pub fn DiagramOptions::with_layout_engine(
  self : DiagramOptions,
  layout_engine : LayoutEngine,
) -> DiagramOptions {
  { ..self, layout_engine, }
}

///|
pub fn DiagramOptions::with_direction(
  self : DiagramOptions,
  direction : @engine_api.Direction,
) -> DiagramOptions {
  { ..self, direction, }
}

///|
pub fn DiagramOptions::with_target_spec(
  self : DiagramOptions,
  target_spec : String?,
) -> DiagramOptions {
  { ..self, target_spec, }
}

///|
pub fn DiagramOptions::with_layout_plugin(
  self : DiagramOptions,
  layout_plugin : ((
    @graph.GraphInput,
    @engine_api.LayoutConfig,
    @engine_api.Direction,
  ) -> Result[@graph.GraphInput, String])?,
) -> DiagramOptions {
  { ..self, layout_plugin, }
}

///|
pub fn DiagramOptions::with_route_plugin(
  self : DiagramOptions,
  route_plugin : ((@graph.GraphInput) -> Result[@graph.GraphInput, String])?,
) -> DiagramOptions {
  { ..self, route_plugin, }
}

///|
pub struct RenderOptions {
  output_mode : OutputMode
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
pub fn RenderOptions::new() -> RenderOptions {
  {
    output_mode: Svg,
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
pub fn RenderOptions::with_output_mode(
  self : RenderOptions,
  output_mode : OutputMode,
) -> RenderOptions {
  { ..self, output_mode, }
}

///|
pub fn RenderOptions::with_theme_name(
  self : RenderOptions,
  theme_name : String?,
) -> RenderOptions {
  { ..self, theme_name, }
}

///|
pub fn RenderOptions::with_dark_theme_id(
  self : RenderOptions,
  dark_theme_id : Int?,
) -> RenderOptions {
  { ..self, dark_theme_id, }
}

///|
pub fn RenderOptions::with_theme_overrides(
  self : RenderOptions,
  theme_overrides : Map[String, String],
) -> RenderOptions {
  { ..self, theme_overrides, }
}

///|
pub fn RenderOptions::with_dark_theme_overrides(
  self : RenderOptions,
  dark_theme_overrides : Map[String, String],
) -> RenderOptions {
  { ..self, dark_theme_overrides, }
}

///|
pub fn RenderOptions::with_scale(
  self : RenderOptions,
  scale : Double?,
) -> RenderOptions {
  { ..self, scale, }
}

///|
pub fn RenderOptions::with_no_xml_tag(
  self : RenderOptions,
  no_xml_tag : Bool?,
) -> RenderOptions {
  { ..self, no_xml_tag, }
}

///|
pub fn RenderOptions::with_salt(
  self : RenderOptions,
  salt : String?,
) -> RenderOptions {
  { ..self, salt, }
}

///|
pub fn RenderOptions::with_omit_version(
  self : RenderOptions,
  omit_version : Bool?,
) -> RenderOptions {
  { ..self, omit_version, }
}

///|
pub(all) enum LibError {
  LayoutError(String)
  RenderError(String)
  ConfigError(String)
  TargetError(String)
} derive(Eq, Show)

///|
pub fn compile_diagram(
  graph_input : @graph.GraphInput,
  source_config : @diagram.Config?,
  options? : DiagramOptions = DiagramOptions::new(),
) -> Result[@diagram.Diagram, LibError] {
  let effective_layout_engine = match
    resolve_layout_engine(options.layout_engine, source_config) {
    Ok(engine) => engine
    Err(err) => return Err(err)
  }
  let config = @engine_api.LayoutConfig::new()
  let laid_out_graph = match options.layout_plugin {
    Some(plugin) =>
      match plugin(graph_input, config, options.direction) {
        Ok(graph) => graph
        Err(e) => return Err(LayoutError("Layout plugin error: \{e}"))
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
            e => return Err(LayoutError(e.to_string()))
          }
        Elk =>
          @engine_api.layout_with_engine(
            @engine_elk.ElkEngine::new(),
            graph_input,
            config,
            options.direction,
          ) catch {
            e => return Err(LayoutError(e.to_string()))
          }
        Railway =>
          @engine_api.layout_with_engine(
            @engine_railway.RailwayEngine::new(),
            graph_input,
            config,
            options.direction,
          ) catch {
            e => return Err(LayoutError(e.to_string()))
          }
      }
  }
  let routed_graph = match options.route_plugin {
    Some(plugin) =>
      match plugin(laid_out_graph) {
        Ok(graph) => graph
        Err(e) => return Err(LayoutError("Route plugin error: \{e}"))
      }
    None => laid_out_graph
  }
  let diagram = @diagram.from_graph(routed_graph, source_config)
  select_target_board(diagram, options.target_spec)
}

///|
pub fn render(
  diagram : @diagram.Diagram,
  options? : RenderOptions = RenderOptions::new(),
) -> Result[String, LibError] {
  match options.output_mode {
    Svg => {
      let render_config = resolve_svg_config(options, diagram.config)
      Ok(@renderer_svg.render(diagram, render_config)) catch {
        e => Err(RenderError(e.to_string()))
      }
    }
    Ascii =>
      Ok(@renderer_ascii.render(diagram, @renderer_ascii.AsciiConfig::new()))
    Unicode => Ok(@renderer_unicode.render(diagram))
  }
}

///|
fn resolve_layout_engine(
  requested_layout_engine : LayoutEngine,
  source_config : @diagram.Config?,
) -> Result[LayoutEngine, LibError] {
  if requested_layout_engine != Auto {
    return Ok(requested_layout_engine)
  }
  match source_config {
    Some(config) =>
      match config.layout_engine {
        Some(layout_name) =>
          match parse_layout_engine_name(layout_name) {
            Some(engine) => Ok(engine)
            None =>
              Err(
                ConfigError(
                  "unsupported layout engine '\{layout_name}' from vars.d2-config.layout-engine. Expected dagre, elk, or railway.",
                ),
              )
          }
        None => Ok(Dagre)
      }
    None => Ok(Dagre)
  }
}

///|
fn parse_layout_engine_name(name : String) -> LayoutEngine? {
  match name.to_lower() {
    "auto" => Some(Auto)
    "dagre" => Some(Dagre)
    "elk" => Some(Elk)
    "railway" => Some(Railway)
    _ => None
  }
}

///|
fn resolve_svg_config(
  options : RenderOptions,
  source_config : @diagram.Config?,
) -> @renderer_svg.SvgConfig {
  let source_theme_id = match source_config {
    Some(config) => config.theme_id
    None => None
  }
  let source_dark_theme_id = match source_config {
    Some(config) => config.dark_theme_id
    None => None
  }
  let effective_dark_theme_id = match options.dark_theme_id {
    Some(v) => Some(v)
    None => source_dark_theme_id
  }
  let mut resolved = match options.theme_name {
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
fn select_target_board(
  diagram : @diagram.Diagram,
  target_spec : String?,
) -> Result[@diagram.Diagram, LibError] {
  match target_spec {
    None => Ok(diagram)
    Some(spec) => {
      let path = parse_target_path(spec)
      if path.length() == 0 {
        return Ok(diagram)
      }
      match diagram.get_board(path) {
        Some(board) => Ok(board)
        None => Err(TargetError("Target board not found: \{spec}"))
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
