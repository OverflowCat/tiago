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
        @xml_emit.Element::new("text")
        .attr_num("x", title.x)
        .attr_num("y", title.y)
        .attr("font-family", "Arial, sans-serif")
        .attr_int("font-size", config.font_size)
        .attr("font-weight", "bold")
        .attr("fill", config.default_stroke)
        .text(title.text)
        .build(),
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
          @xml_emit.Element::new("line")
          .attr_num("x1", x1)
          .attr_num("y1", y)
          .attr_num("x2", x2)
          .attr_num("y2", y)
          .attr("stroke", "#cccccc")
          .attr_num("stroke-width", 1.0)
          .self_close()
          .build(),
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
    @xml_emit.Element::new("text")
    .attr_num("x", label_x)
    .attr_num("y", label_y)
    .attr("font-family", "Arial, sans-serif")
    .attr_int("font-size", config.font_size)
    .attr("fill", config.default_stroke)
    .text(label)
    .build(),
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
  svg.add(
    @xml_emit.Element::new("line")
    .attr_num("x1", line_start_x)
    .attr_num("y1", line_y)
    .attr_num("x2", line_end_x)
    .attr_num("y2", line_y)
    .attr("stroke", stroke)
    .attr_num("stroke-width", 2.0)
    .attr_if("marker-start", marker_start)
    .attr_if("marker-end", marker_end)
    .self_close()
    .build(),
  )
  svg.add(
    @xml_emit.Element::new("text")
    .attr_num("x", label_x)
    .attr_num("y", label_y)
    .attr("font-family", "Arial, sans-serif")
    .attr_int("font-size", config.font_size)
    .attr("fill", config.default_stroke)
    .text(label)
    .build(),
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
      @xml_emit.Element::new("image")
      .attr("href", icon)
      .attr_num("x", icon_x)
      .attr_num("y", icon_y)
      .attr_num("width", icon_size)
      .attr_num("height", icon_size)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .self_close()
      .build(),
    )
  } else {
    let cx = icon_x + icon_size / 2.0
    // Note: text y-position is provided by layout via label_y, so reuse the same baseline offset style.
    let cy = icon_y + icon_size / 2.0 + config.font_size.to_double() * 0.35
    svg.add(
      @xml_emit.Element::new("text")
      .attr_num("x", cx)
      .attr_num("y", cy)
      .attr("font-family", "Arial, sans-serif")
      .attr_int("font-size", config.font_size + 4)
      .attr("fill", config.default_stroke)
      .attr("text-anchor", "middle")
      .text(icon)
      .build(),
    )
  }
  svg.add(
    @xml_emit.Element::new("text")
    .attr_num("x", label_x)
    .attr_num("y", label_y)
    .attr("font-family", "Arial, sans-serif")
    .attr_int("font-size", config.font_size)
    .attr("fill", config.default_stroke)
    .text(label)
    .build(),
  )
}
