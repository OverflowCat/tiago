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
/// SVG-specific legend layout.
///
/// This package computes legend geometry so the SVG renderer only draws.

///|
using @graph {
  type ArrowheadType,
  type Box,
  type LegendInput,
  type ShapeType,
  type StyleInput,
}

///|
pub struct LegendLayoutConfig {
  font_size : Int
  margin : Double
} derive(Show)

///|
pub fn LegendLayoutConfig::new(font_size : Int) -> LegendLayoutConfig {
  { font_size, margin: 20.0 }
}

///|
pub struct LegendLayout {
  x : Double
  y : Double
  width : Double
  height : Double
  fill : String
  stroke : String
  title : TitleLayout?
  entries : Array[LegendEntryLayout]
} derive(Show)

///|
pub struct TitleLayout {
  x : Double
  y : Double
  text : String
} derive(Show)

///|
/// Pre-positioned legend entry layout.
///
/// The renderer should not compute positions (label alignment, icon placement,
/// separators). It only renders based on this layout.
pub enum LegendEntryLayout {
  Shape(
    icon_box~ : Box,
    shape~ : ShapeType,
    label~ : String,
    style~ : StyleInput?,
    label_x~ : Double,
    label_y~ : Double
  )
  Connection(
    line_start_x~ : Double,
    line_end_x~ : Double,
    line_y~ : Double,
    src_arrow~ : ArrowheadType,
    dst_arrow~ : ArrowheadType,
    label~ : String,
    style~ : StyleInput?,
    label_x~ : Double,
    label_y~ : Double
  )
  Custom(
    icon_x~ : Double,
    icon_y~ : Double,
    icon_size~ : Double,
    icon~ : String,
    label~ : String,
    label_x~ : Double,
    label_y~ : Double
  )
  Separator(x1~ : Double, x2~ : Double, y~ : Double)
} derive(Show)

///|
fn estimate_text_width(text : String, font_size : Int) -> Double {
  text.length().to_double() * font_size.to_double() * 0.6
}

///|
fn calculate_size(legend : LegendInput, font_size : Int) -> (Double, Double) {
  if legend.is_empty() {
    return (0.0, 0.0)
  }
  let mut max_label_width = 0.0
  let mut total_height = legend.padding * 2.0
  match legend.title {
    Some(t) => {
      max_label_width = estimate_text_width(t, font_size)
      total_height = total_height + font_size.to_double() + legend.entry_gap
    }
    None => ()
  }
  for entry in legend.entries {
    match entry {
      ShapeEntry(label~, ..)
      | ConnectionEntry(label~, ..)
      | CustomEntry(label~, ..) => {
        let label_width = estimate_text_width(label, font_size)
        max_label_width = if label_width > max_label_width {
          label_width
        } else {
          max_label_width
        }
        total_height = total_height + legend.icon_size + legend.entry_gap
      }
      Separator => total_height = total_height + 4.0 + legend.entry_gap
    }
  }
  let width = legend.padding * 2.0 +
    legend.icon_size +
    legend.entry_gap +
    max_label_width
  (width, total_height)
}

///|
/// Compute legend layout in SVG coordinates.
///
/// The bounds should be the diagram bounds in the same coordinate system.
pub fn compute_legend_layout(
  legend : LegendInput,
  bounds : (Double, Double, Double, Double),
  config : LegendLayoutConfig,
) -> LegendLayout? {
  if legend.is_empty() || legend.position == @graph.Hidden {
    return None
  }
  let (min_x, min_y, max_x, max_y) = bounds
  let (width, height) = calculate_size(legend, config.font_size)
  let margin = config.margin
  let (x, y) = match legend.position {
    @graph.TopLeft => (min_x + margin, min_y + margin)
    @graph.TopRight => (max_x - width - margin, min_y + margin)
    @graph.BottomLeft => (min_x + margin, max_y - height - margin)
    @graph.BottomRight | @graph.Hidden =>
      (max_x - width - margin, max_y - height - margin)
  }
  let fill = legend.fill.unwrap_or("#ffffff")
  let stroke = legend.stroke.unwrap_or("#cccccc")
  let mut current_y = y + legend.padding
  let title = match legend.title {
    Some(t) => {
      let title_x = x + legend.padding
      let title_y = current_y + config.font_size.to_double() * 0.8
      current_y = current_y + config.font_size.to_double() + legend.entry_gap
      Some({ x: title_x, y: title_y, text: t })
    }
    None => None
  }
  let entries : Array[LegendEntryLayout] = []
  for entry in legend.entries {
    match entry {
      ShapeEntry(shape~, label~, style~) => {
        let icon_box = Box::new(
          x + legend.padding,
          current_y,
          legend.icon_size,
          legend.icon_size,
        )
        let label_x = x + legend.padding + legend.icon_size + legend.entry_gap
        let label_y = current_y +
          legend.icon_size / 2.0 +
          config.font_size.to_double() * 0.35
        entries.push(
          LegendEntryLayout::Shape(
            icon_box~,
            shape~,
            label~,
            style~,
            label_x~,
            label_y~,
          ),
        )
        current_y = current_y + legend.icon_size + legend.entry_gap
      }
      ConnectionEntry(src_arrow~, dst_arrow~, label~, style~) => {
        let line_y = current_y + legend.icon_size / 2.0
        let line_start_x = x + legend.padding
        let line_end_x = x + legend.padding + legend.icon_size
        let label_x = x + legend.padding + legend.icon_size + legend.entry_gap
        let label_y = current_y +
          legend.icon_size / 2.0 +
          config.font_size.to_double() * 0.35
        entries.push(
          LegendEntryLayout::Connection(
            line_start_x~,
            line_end_x~,
            line_y~,
            src_arrow~,
            dst_arrow~,
            label~,
            style~,
            label_x~,
            label_y~,
          ),
        )
        current_y = current_y + legend.icon_size + legend.entry_gap
      }
      CustomEntry(icon~, label~) => {
        let icon_x = x + legend.padding
        let icon_y = current_y
        let icon_size = legend.icon_size
        let label_x = x + legend.padding + icon_size + legend.entry_gap
        let label_y = current_y +
          icon_size / 2.0 +
          config.font_size.to_double() * 0.35
        entries.push(
          LegendEntryLayout::Custom(
            icon_x~,
            icon_y~,
            icon_size~,
            icon~,
            label~,
            label_x~,
            label_y~,
          ),
        )
        current_y = current_y + legend.icon_size + legend.entry_gap
      }
      Separator => {
        let y = current_y + 2.0
        let x1 = x + legend.padding
        let x2 = x + width - legend.padding
        entries.push(LegendEntryLayout::Separator(x1~, x2~, y~))
        current_y = current_y + 4.0 + legend.entry_gap
      }
    }
  }
  Some({ x, y, width, height, fill, stroke, title, entries })
}
