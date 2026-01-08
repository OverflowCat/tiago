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
/// Arrowhead rendering functions
///
/// This module provides centralized rendering for arrowhead markers
/// in both SVG and ASCII formats.

///|
/// Add all arrowhead marker definitions to an SVG
/// This should be called once during SVG setup
pub fn add_arrowhead_markers_to_svg(
  svg : @svg.Svg,
  size : Double,
  stroke : String,
) -> Unit {
  // Triangle (default arrow)
  svg.add_def(@svg.arrow_marker("arrow-triangle", size, stroke))
  svg.add_def(
    @svg.arrow_marker("arrow-triangle-reverse", size, stroke, reverse=true),
  )
  // Diamond
  svg.add_def(@svg.diamond_marker("arrow-diamond", size, stroke))
  svg.add_def(
    @svg.diamond_marker("arrow-diamond-reverse", size, stroke, reverse=true),
  )
  // Circle
  svg.add_def(@svg.circle_marker("arrow-circle", size, stroke))
  svg.add_def(
    @svg.circle_marker("arrow-circle-reverse", size, stroke, reverse=true),
  )
  // Crow's foot: one
  svg.add_def(@svg.cf_one_marker("arrow-cf-one", size, stroke))
  svg.add_def(
    @svg.cf_one_marker("arrow-cf-one-reverse", size, stroke, reverse=true),
  )
  // Crow's foot: many
  svg.add_def(@svg.cf_many_marker("arrow-cf-many", size, stroke))
  svg.add_def(
    @svg.cf_many_marker("arrow-cf-many-reverse", size, stroke, reverse=true),
  )
  // Crow's foot: one-required
  svg.add_def(
    @svg.cf_one_required_marker("arrow-cf-one-required", size, stroke),
  )
  svg.add_def(
    @svg.cf_one_required_marker(
      "arrow-cf-one-required-reverse",
      size,
      stroke,
      reverse=true,
    ),
  )
  // Crow's foot: many-required
  svg.add_def(
    @svg.cf_many_required_marker("arrow-cf-many-required", size, stroke),
  )
  svg.add_def(
    @svg.cf_many_required_marker(
      "arrow-cf-many-required-reverse",
      size,
      stroke,
      reverse=true,
    ),
  )
  // Crow's foot: one-optional
  svg.add_def(
    @svg.cf_one_optional_marker("arrow-cf-one-optional", size, stroke),
  )
  svg.add_def(
    @svg.cf_one_optional_marker(
      "arrow-cf-one-optional-reverse",
      size,
      stroke,
      reverse=true,
    ),
  )
  // Crow's foot: many-optional
  svg.add_def(
    @svg.cf_many_optional_marker("arrow-cf-many-optional", size, stroke),
  )
  svg.add_def(
    @svg.cf_many_optional_marker(
      "arrow-cf-many-optional-reverse",
      size,
      stroke,
      reverse=true,
    ),
  )
  // Line terminator
  svg.add_def(@svg.line_marker("arrow-line", size, stroke))
  svg.add_def(
    @svg.line_marker("arrow-line-reverse", size, stroke, reverse=true),
  )
  // Open triangle
  svg.add_def(@svg.open_marker("arrow-open", size, stroke))
  svg.add_def(
    @svg.open_marker("arrow-open-reverse", size, stroke, reverse=true),
  )
  // Aliases for backward compatibility
  svg.add_def(@svg.arrow_marker("arrow", size, stroke))
  svg.add_def(@svg.arrow_marker("arrow-reverse", size, stroke, reverse=true))
}

///|
/// Get the SVG marker URL for an arrowhead type
pub fn get_arrowhead_marker_url(
  arrowhead : ArrowheadType,
  reverse : Bool,
) -> String {
  arrowhead.marker_url(reverse)
}

///|
/// Get ASCII representation of an arrowhead
pub fn arrowhead_to_ascii(arrowhead : ArrowheadType, reverse : Bool) -> String {
  arrowhead.to_ascii(reverse)
}

///|
/// Render a connection (edge) with arrowheads to ASCII
/// Returns the string representation like "-->" or "<-->" etc.
pub fn render_connection_ascii(
  src : ArrowheadType,
  dst : ArrowheadType,
  line_style : String,
) -> String {
  let src_str = src.to_ascii(true)
  let dst_str = dst.to_ascii(false)
  let line = match line_style {
    "dashed" => ".."
    "dotted" => ":"
    _ => "--"
  }
  src_str + line + dst_str
}

///|
/// Check if an edge line needs marker-start attribute
pub fn needs_start_marker(arrowhead : ArrowheadType) -> Bool {
  arrowhead != @d2graph.None
}

///|
/// Check if an edge line needs marker-end attribute
pub fn needs_end_marker(arrowhead : ArrowheadType) -> Bool {
  arrowhead != @d2graph.None
}

///|
/// Build SVG line attributes for edge markers
pub fn build_marker_attributes(
  src : ArrowheadType,
  dst : ArrowheadType,
) -> String {
  let mut attrs = ""
  if needs_start_marker(src) {
    attrs = attrs +
      " marker-start=\"" +
      get_arrowhead_marker_url(src, true) +
      "\""
  }
  if needs_end_marker(dst) {
    attrs = attrs +
      " marker-end=\"" +
      get_arrowhead_marker_url(dst, false) +
      "\""
  }
  attrs
}
