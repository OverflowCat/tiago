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
/// Unicode (box-drawing) renderer built on top of the ASCII renderer.

///|
/// Unicode renderer
pub struct UnicodeRenderer {
  _marker : Unit
} derive(Show)

///|
pub fn UnicodeRenderer::new() -> UnicodeRenderer {
  { _marker: () }
}

///|
/// Implement the Renderer trait for UnicodeRenderer
pub impl @render_api.Renderer for UnicodeRenderer with render(
  _self,
  diagram : @diagram.Diagram,
) -> String raise @render_api.RenderError {
  @renderer_ascii.render(diagram, @renderer_ascii.AsciiConfig::unicode())
}

///|
pub impl @render_api.Renderer for UnicodeRenderer with format_name(_self) -> String {
  "unicode"
}

///|
/// Legacy render function (for backward compatibility)
pub fn render(diagram : @diagram.Diagram) -> String {
  @renderer_ascii.render(diagram, @renderer_ascii.AsciiConfig::unicode())
}
