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
/// Diagram-oriented ASCII renderer entrypoint.

///|
/// ASCII renderer
pub struct AsciiRenderer {
  _marker : Unit
} derive(Show)

///|
pub fn AsciiRenderer::new() -> AsciiRenderer {
  { _marker: () }
}

///|
/// Implement the Renderer trait for AsciiRenderer
pub impl @render_api.Renderer for AsciiRenderer with render(
  _self,
  diagram : @diagram.Diagram,
) -> String raise @render_api.RenderError {
  render_ascii(diagram.materialize(), AsciiConfig::new())
}

///|
pub impl @render_api.Renderer for AsciiRenderer with format_name(
  _self,
) -> String {
  "ascii"
}

///|
/// Render with custom configuration
pub fn render(diagram : @diagram.Diagram, config : AsciiConfig) -> String {
  render_ascii(diagram.materialize(), config)
}
