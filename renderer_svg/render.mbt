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
/// Diagram-oriented SVG renderer entrypoint.

///|
/// SVG renderer
pub struct SvgRenderer {
  _marker : Unit
} derive(Show)

///|
pub fn SvgRenderer::new() -> SvgRenderer {
  { _marker: () }
}

///|
/// Implement the Renderer trait for SvgRenderer
pub impl @render_api.Renderer for SvgRenderer with render(
  _self,
  diagram : @diagram.Diagram,
) -> String raise @render_api.RenderError {
  render_svg(diagram.materialize(), SvgConfig::new())
}

///|
pub impl @render_api.Renderer for SvgRenderer with format_name(
  _self,
) -> String {
  "svg"
}

///|
/// Render with custom configuration
pub fn render(diagram : @diagram.Diagram, config : SvgConfig) -> String {
  render_svg(diagram.materialize(), config)
}

