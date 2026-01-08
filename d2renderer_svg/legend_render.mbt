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
/// Legend rendering for SVG and ASCII output
///
/// This module provides rendering functions for legends in both
/// SVG and ASCII formats.

///|
/// Render a legend to SVG
pub fn render_legend_svg(
  svg : @svg.Svg,
  legend : Legend,
  graph_bounds : (Double, Double, Double, Double),
  config : SvgConfig,
) -> Unit {
  if legend.is_empty() || legend.position == @d2graph.Hidden {
    return
  }
  let (min_x, min_y, max_x, max_y) = graph_bounds
  let (width, height) = legend.calculate_size(config.font_size)
  // Calculate position based on legend.position
  let margin = 20.0
  let (x, y) = match legend.position {
    @d2graph.TopLeft => (min_x + margin, min_y + margin)
    @d2graph.TopRight => (max_x - width - margin, min_y + margin)
    @d2graph.BottomLeft => (min_x + margin, max_y - height - margin)
    @d2graph.BottomRight | @d2graph.Hidden =>
      (max_x - width - margin, max_y - height - margin)
  }
  // Render legend background
  let fill = legend.fill.unwrap_or("#ffffff")
  let stroke = legend.stroke.unwrap_or("#cccccc")
  svg.add(
    @svg.rect(
      x,
      y,
      width,
      height,
      fill~,
      stroke~,
      stroke_width=1.0,
      rx=Some(4.0),
      ry=Some(4.0),
    ),
  )
  // Render title if present
  let mut current_y = y + legend.padding
  match legend.title {
    Some(title) => {
      let title_x = x + legend.padding
      let title_y = current_y + config.font_size.to_double() * 0.8
      svg.add(
        "<text x=\"\{title_x}\" y=\"\{title_y}\" font-family=\"Arial, sans-serif\" font-size=\"\{config.font_size}\" font-weight=\"bold\" fill=\"\{config.default_stroke}\">\{@svg.escape_xml(title)}</text>",
      )
      current_y = current_y + config.font_size.to_double() + legend.entry_gap
    }
    None => ()
  }
  // Render each entry
  for entry in legend.entries {
    match entry {
      ShapeEntry(shape~, label~, style~) =>
        render_legend_shape_entry(
          svg,
          x + legend.padding,
          current_y,
          shape,
          label,
          style,
          legend,
          config,
        )
      ConnectionEntry(src_arrow~, dst_arrow~, label~, style~) =>
        render_legend_connection_entry(
          svg,
          x + legend.padding,
          current_y,
          src_arrow,
          dst_arrow,
          label,
          style,
          legend,
          config,
        )
      CustomEntry(icon~, label~) =>
        render_legend_custom_entry(
          svg,
          x + legend.padding,
          current_y,
          icon,
          label,
          legend,
          config,
        )
      Separator => {
        // Draw a horizontal line
        let line_y = current_y + 2.0
        svg.add(
          "<line x1=\"\{x + legend.padding}\" y1=\"\{line_y}\" x2=\"\{x + width - legend.padding}\" y2=\"\{line_y}\" stroke=\"#cccccc\" stroke-width=\"1\"/>",
        )
      }
    }
    // Update y position for next entry
    current_y = current_y +
      (match entry {
        Separator => 4.0
        _ => legend.icon_size
      }) +
      legend.entry_gap
  }
}

///|
fn render_legend_shape_entry(
  svg : @svg.Svg,
  x : Double,
  y : Double,
  shape : ShapeType,
  label : String,
  style : Style?,
  legend : Legend,
  config : SvgConfig,
) -> Unit {
  let icon_size = legend.icon_size
  let fill = match style {
    Some(s) =>
      match s.fill {
        Some(f) => f
        None => config.default_fill
      }
    None => config.default_fill
  }
  let stroke = match style {
    Some(s) =>
      match s.stroke {
        Some(f) => f
        None => config.default_stroke
      }
    None => config.default_stroke
  }
  // Create a mini shape icon
  let icon_box = Box::new(x, y, icon_size, icon_size)
  let ctx = SvgShapeContext::new(svg, icon_box, fill, stroke, 1.0, "", config)
  render_shape_svg(shape, ctx)
  // Render label
  let label_x = x + icon_size + legend.entry_gap
  let label_y = y + icon_size / 2.0 + config.font_size.to_double() * 0.35
  svg.add(
    "<text x=\"\{label_x}\" y=\"\{label_y}\" font-family=\"Arial, sans-serif\" font-size=\"\{config.font_size}\" fill=\"\{config.default_stroke}\">\{@svg.escape_xml(label)}</text>",
  )
}

///|
fn render_legend_connection_entry(
  svg : @svg.Svg,
  x : Double,
  y : Double,
  src_arrow : ArrowheadType,
  dst_arrow : ArrowheadType,
  label : String,
  _style : Style?,
  legend : Legend,
  config : SvgConfig,
) -> Unit {
  let icon_size = legend.icon_size
  let stroke = config.default_stroke
  // Draw a line with arrowheads
  let line_y = y + icon_size / 2.0
  let line_start = x
  let line_end = x + icon_size
  // Get marker URLs
  let marker_start = src_arrow.marker_url(true)
  let marker_end = dst_arrow.marker_url(false)
  // Build line with markers
  let mut line = "<line x1=\"\{line_start}\" y1=\"\{line_y}\" x2=\"\{line_end}\" y2=\"\{line_y}\" stroke=\"\{stroke}\" stroke-width=\"2\""
  if not(marker_start.is_empty()) {
    line = line + " marker-start=\"\{marker_start}\""
  }
  if not(marker_end.is_empty()) {
    line = line + " marker-end=\"\{marker_end}\""
  }
  line = line + "/>"
  svg.add(line)
  // Render label
  let label_x = x + icon_size + legend.entry_gap
  let label_y = y + icon_size / 2.0 + config.font_size.to_double() * 0.35
  svg.add(
    "<text x=\"\{label_x}\" y=\"\{label_y}\" font-family=\"Arial, sans-serif\" font-size=\"\{config.font_size}\" fill=\"\{config.default_stroke}\">\{@svg.escape_xml(label)}</text>",
  )
}

///|
fn render_legend_custom_entry(
  svg : @svg.Svg,
  x : Double,
  y : Double,
  icon : String,
  label : String,
  legend : Legend,
  config : SvgConfig,
) -> Unit {
  let icon_size = legend.icon_size
  // Render icon (could be URL or text symbol)
  if icon.has_prefix("http") || icon.contains(".") {
    // URL - render as image
    svg.add(
      "<image href=\"\{@svg.escape_xml(icon)}\" x=\"\{x}\" y=\"\{y}\" width=\"\{icon_size}\" height=\"\{icon_size}\" preserveAspectRatio=\"xMidYMid meet\"/>",
    )
  } else {
    // Text symbol - render as text
    let icon_x = x + icon_size / 2.0
    let icon_y = y + icon_size / 2.0 + config.font_size.to_double() * 0.35
    svg.add(
      "<text x=\"\{icon_x}\" y=\"\{icon_y}\" font-family=\"Arial, sans-serif\" font-size=\"\{config.font_size + 4}\" fill=\"\{config.default_stroke}\" text-anchor=\"middle\">\{@svg.escape_xml(icon)}</text>",
    )
  }
  // Render label
  let label_x = x + icon_size + legend.entry_gap
  let label_y = y + icon_size / 2.0 + config.font_size.to_double() * 0.35
  svg.add(
    "<text x=\"\{label_x}\" y=\"\{label_y}\" font-family=\"Arial, sans-serif\" font-size=\"\{config.font_size}\" fill=\"\{config.default_stroke}\">\{@svg.escape_xml(label)}</text>",
  )
}
