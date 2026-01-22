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
/// Renderer API: contract for diagram renderers.

///|
/// Renderer error
pub(all) suberror RenderError {
  UnsupportedFormat(String)
  RenderFailed(String)
  InvalidDiagram(String)
} derive(Eq, Show)

///|
/// Construct an error from outside this package
pub fn unsupported_format(message : String) -> RenderError {
  RenderError::UnsupportedFormat(message)
}

///|
pub fn render_failed(message : String) -> RenderError {
  RenderError::RenderFailed(message)
}

///|
pub fn invalid_diagram(message : String) -> RenderError {
  RenderError::InvalidDiagram(message)
}

///|
/// Base render configuration (common options)
pub struct RenderConfig {
  /// Padding around the diagram
  padding : Double
  /// Default font family (for text-based renderers, affects char choice)
  font_family : String
  /// Default font size
  font_size : Int
  /// Background color (format-specific: hex/name/none)
  background : String
  /// Whether to use dark mode
  dark_mode : Bool
} derive(Show)

///|
pub fn RenderConfig::new() -> RenderConfig {
  {
    padding: 20.0,
    font_family: "Arial, sans-serif",
    font_size: 16,
    background: "",
    dark_mode: false,
  }
}

///|
pub fn RenderConfig::with_padding(padding : Double) -> RenderConfig {
  let cfg = RenderConfig::new()
  { ..cfg, padding, }
}

///|
pub fn RenderConfig::dark() -> RenderConfig {
  let cfg = RenderConfig::new()
  { ..cfg, dark_mode: true, background: "#1a1a2e", font_family: "monospace" }
}

///|
/// Renderer interface.
///
/// Each renderer implements this trait to provide a default render
/// with sensible defaults. For custom configuration, use the
/// renderer-specific config types (e.g., SvgConfig, AsciiConfig).
pub(open) trait Renderer {
  /// Render a diagram to string output using default configuration.
  ///
  /// For custom configuration, use the renderer's config-specific
  /// render function (e.g., `render_svg(diagram, svg_config)`).
  render(Self, @diagram.Diagram) -> String raise RenderError

  /// Get the name of this renderer format.
  format_name(Self) -> String
}
