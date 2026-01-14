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
/// Legend rendering for SVG output.
///
/// Legend geometry (size/position/alignment) is computed in `layout_svg`.
/// This module only draws the pre-laid-out legend.

///|
using @layout_svg {type LegendLayout}

///|

///|
/// Render a pre-laid-out legend to SVG.
pub fn render_legend_svg(
  svg : @svg.Svg,
  layout : LegendLayout,
  config : SvgConfig,
) -> Unit {
  // Render legend background
  svg.add(
    @svg.rect(
      layout.x,
      layout.y,
      layout.width,
      layout.height,
      fill=layout.fill,
      stroke=layout.stroke,
      stroke_width=1.0,
      rx=Some(4.0),
      ry=Some(4.0),
    ),
  )

  // Render title if present
  match layout.title {
    Some(title) =>
      svg.add(
        "<text x=\"\{title.x}\" y=\"\{title.y}\" font-family=\"Arial, sans-serif\" font-size=\"\{config.font_size}\" font-weight=\"bold\" fill=\"\{config.default_stroke}\">\{@svg.escape_xml(title.text)}</text>",
      )
    None => ()
  }

  // Render each entry
  for entry in layout.entries {
    match entry {
      @layout_svg.LegendEntryLayout::Shape(
        icon_box~,
        shape~,
        label~,
        style~,
        label_x~,
        label_y~
      ) =>
        render_shape_entry(
          svg, icon_box, shape, label, style, label_x, label_y, config,
        )
      @layout_svg.LegendEntryLayout::Connection(
        line_start_x~,
        line_end_x~,
        line_y~,
        src_arrow~,
        dst_arrow~,
        label~,
        style~,
        label_x~,
        label_y~
      ) =>
        render_connection_entry(
          svg, line_start_x, line_end_x, line_y, src_arrow, dst_arrow, label, style,
          label_x, label_y, config,
        )
      @layout_svg.LegendEntryLayout::Custom(
        icon_x~,
        icon_y~,
        icon_size~,
        icon~,
        label~,
        label_x~,
        label_y~
      ) =>
        render_custom_entry(
          svg, icon_x, icon_y, icon_size, icon, label, label_x, label_y, config,
        )
      @layout_svg.LegendEntryLayout::Separator(x1~, x2~, y~) =>
        svg.add(
          "<line x1=\"\{x1}\" y1=\"\{y}\" x2=\"\{x2}\" y2=\"\{y}\" stroke=\"#cccccc\" stroke-width=\"1\"/>",
        )
    }
  }
}

///|
fn render_shape_entry(
  svg : @svg.Svg,
  icon_box : @graph.Box,
  shape : @graph.ShapeType,
  label : String,
  style : @graph.StyleInput?,
  label_x : Double,
  label_y : Double,
  config : SvgConfig,
) -> Unit {
  let fill = match style {
    Some(s) =>
      match s.fill {
        Some(f) => f.get_value()
        None => config.default_fill
      }
    None => config.default_fill
  }
  let stroke = match style {
    Some(s) =>
      match s.stroke {
        Some(f) => f.get_value()
        None => config.default_stroke
      }
    None => config.default_stroke
  }
  let ctx = SvgShapeContext::new(svg, icon_box, fill, stroke, 1.0, "", config)
  render_shape_svg(shape, ctx)
  svg.add(
    "<text x=\"\{label_x}\" y=\"\{label_y}\" font-family=\"Arial, sans-serif\" font-size=\"\{config.font_size}\" fill=\"\{config.default_stroke}\">\{@svg.escape_xml(label)}</text>",
  )
}

///|
fn render_connection_entry(
  svg : @svg.Svg,
  line_start_x : Double,
  line_end_x : Double,
  line_y : Double,
  src_arrow : @graph.ArrowheadType,
  dst_arrow : @graph.ArrowheadType,
  label : String,
  _style : @graph.StyleInput?,
  label_x : Double,
  label_y : Double,
  config : SvgConfig,
) -> Unit {
  let stroke = config.default_stroke
  let marker_start = src_arrow.marker_url(true)
  let marker_end = dst_arrow.marker_url(false)
  let mut line = "<line x1=\"\{line_start_x}\" y1=\"\{line_y}\" x2=\"\{line_end_x}\" y2=\"\{line_y}\" stroke=\"\{stroke}\" stroke-width=\"2\""
  if not(marker_start.is_empty()) {
    line = line + " marker-start=\"\{marker_start}\""
  }
  if not(marker_end.is_empty()) {
    line = line + " marker-end=\"\{marker_end}\""
  }
  line = line + "/>"
  svg.add(line)
  svg.add(
    "<text x=\"\{label_x}\" y=\"\{label_y}\" font-family=\"Arial, sans-serif\" font-size=\"\{config.font_size}\" fill=\"\{config.default_stroke}\">\{@svg.escape_xml(label)}</text>",
  )
}

///|
fn render_custom_entry(
  svg : @svg.Svg,
  icon_x : Double,
  icon_y : Double,
  icon_size : Double,
  icon : String,
  label : String,
  label_x : Double,
  label_y : Double,
  config : SvgConfig,
) -> Unit {
  if icon.has_prefix("http") || icon.contains(".") {
    svg.add(
      "<image href=\"\{@svg.escape_xml(icon)}\" x=\"\{icon_x}\" y=\"\{icon_y}\" width=\"\{icon_size}\" height=\"\{icon_size}\" preserveAspectRatio=\"xMidYMid meet\"/>",
    )
  } else {
    let cx = icon_x + icon_size / 2.0
    // Note: text y-position is provided by layout via label_y, so reuse the same baseline offset style.
    let cy = icon_y + icon_size / 2.0 + config.font_size.to_double() * 0.35
    svg.add(
      "<text x=\"\{cx}\" y=\"\{cy}\" font-family=\"Arial, sans-serif\" font-size=\"\{config.font_size + 4}\" fill=\"\{config.default_stroke}\" text-anchor=\"middle\">\{@svg.escape_xml(icon)}</text>",
    )
  }
  svg.add(
    "<text x=\"\{label_x}\" y=\"\{label_y}\" font-family=\"Arial, sans-serif\" font-size=\"\{config.font_size}\" fill=\"\{config.default_stroke}\">\{@svg.escape_xml(label)}</text>",
  )
}
