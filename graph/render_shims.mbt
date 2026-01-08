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
/// Temporary compatibility shims for rendering APIs.
///
/// Long-term these move to `d2diagram` + `d2renderer_*`.
pub type AsciiConfig = @d2renderer_ascii.AsciiConfig

///|
pub type RenderPass = @d2renderer_svg.RenderPass

///|
pub type SvgConfig = @d2renderer_svg.SvgConfig

///|
pub type SvgShapeContext = @d2renderer_svg.SvgShapeContext

///|
pub fn list_themes() -> Array[String] {
  @d2renderer_svg.list_themes()
}

///|
pub fn render_svg(graph : Graph, config : SvgConfig) -> String {
  @d2renderer_svg.render_svg(graph, config)
}

///|
pub fn render_ascii(graph : Graph, config : AsciiConfig) -> String {
  @d2renderer_ascii.render_ascii(graph, config)
}

///|
pub fn add_arrowhead_markers_to_svg(
  svg : @svg.Svg,
  size : Double,
  stroke : String,
) -> Unit {
  @d2renderer_svg.add_arrowhead_markers_to_svg(svg, size, stroke)
}

///|
pub fn get_arrowhead_marker_url(
  arrowhead : ArrowheadType,
  reverse : Bool,
) -> String {
  @d2renderer_svg.get_arrowhead_marker_url(arrowhead, reverse)
}

///|
pub fn arrowhead_to_ascii(arrowhead : ArrowheadType, reverse : Bool) -> String {
  @d2renderer_svg.arrowhead_to_ascii(arrowhead, reverse)
}

///|
pub fn render_connection_ascii(
  src : ArrowheadType,
  dst : ArrowheadType,
  line_style : String,
) -> String {
  @d2renderer_svg.render_connection_ascii(src, dst, line_style)
}

///|
pub fn needs_start_marker(arrowhead : ArrowheadType) -> Bool {
  @d2renderer_svg.needs_start_marker(arrowhead)
}

///|
pub fn needs_end_marker(arrowhead : ArrowheadType) -> Bool {
  @d2renderer_svg.needs_end_marker(arrowhead)
}

///|
pub fn build_marker_attributes(
  src : ArrowheadType,
  dst : ArrowheadType,
) -> String {
  @d2renderer_svg.build_marker_attributes(src, dst)
}

///|
pub fn render_shape_svg(shape : ShapeType, ctx : SvgShapeContext) -> Unit {
  @d2renderer_svg.render_shape_svg(shape, ctx)
}

///|
pub fn render_legend_svg(
  svg : @svg.Svg,
  legend : Legend,
  graph_bounds : (Double, Double, Double, Double),
  config : SvgConfig,
) -> Unit {
  @d2renderer_svg.render_legend_svg(svg, legend, graph_bounds, config)
}

///|
pub fn render_legend_ascii(
  grid : @ascii.Grid,
  legend : Legend,
  x : Int,
  y : Int,
  charset : @ascii.CharSet,
) -> Unit {
  @d2renderer_ascii.render_legend_ascii(grid, legend, x, y, charset)
}
