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
/// Legend support for diago diagrams
///
/// Legends provide a visual key explaining the meaning of shapes and
/// connections used in the diagram.

///|
/// Position of the legend in the diagram
pub(all) enum LegendPosition {
  TopLeft
  TopRight
  BottomLeft
  BottomRight
  /// Legend is not displayed
  Hidden
} derive(Eq, Show)

///|
/// Parse legend position from string
pub fn LegendPosition::from_string(s : String) -> LegendPosition {
  match s.to_lower() {
    "top-left" | "topleft" | "tl" => TopLeft
    "top-right" | "topright" | "tr" => TopRight
    "bottom-left" | "bottomleft" | "bl" => BottomLeft
    "bottom-right" | "bottomright" | "br" => BottomRight
    "hidden" | "none" => Hidden
    _ => BottomRight // Default position
  }
}

///|
/// Convert legend position to string
pub fn LegendPosition::to_position_string(self : LegendPosition) -> String {
  match self {
    TopLeft => "top-left"
    TopRight => "top-right"
    BottomLeft => "bottom-left"
    BottomRight => "bottom-right"
    Hidden => "hidden"
  }
}

///|
/// A single entry in the legend
pub(all) enum LegendEntry {
  /// A shape entry with optional custom style
  ShapeEntry(shape~ : ShapeType, label~ : String, style~ : StyleInput?)
  /// A connection/edge entry showing arrowheads
  ConnectionEntry(
    src_arrow~ : ArrowheadType,
    dst_arrow~ : ArrowheadType,
    label~ : String,
    style~ : StyleInput?
  )
  /// A custom entry with icon URL or symbol
  CustomEntry(icon~ : String, label~ : String)
  /// A visual separator line
  Separator
} derive(Show)

///|
/// Create a shape legend entry
pub fn LegendEntry::shape(
  shape : ShapeType,
  label : String,
  style : StyleInput?,
) -> LegendEntry {
  ShapeEntry(shape~, label~, style~)
}

///|
/// Create a connection legend entry
pub fn LegendEntry::connection(
  src_arrow : ArrowheadType,
  dst_arrow : ArrowheadType,
  label : String,
  style : StyleInput?,
) -> LegendEntry {
  ConnectionEntry(src_arrow~, dst_arrow~, label~, style~)
}

///|
/// Create a custom legend entry
pub fn LegendEntry::custom(icon : String, label : String) -> LegendEntry {
  CustomEntry(icon~, label~)
}

///|
/// Create a separator entry
pub fn LegendEntry::separator() -> LegendEntry {
  Separator
}

///|
/// The legend configuration for a diagram
pub struct Legend {
  /// Optional title for the legend
  title : String?
  /// Position of the legend in the diagram
  position : LegendPosition
  /// Legend entries
  entries : Array[LegendEntry]
  /// Background fill color
  fill : String?
  /// Border stroke color
  stroke : String?
  /// Padding inside the legend box
  padding : Double
  /// Gap between entries
  entry_gap : Double
  /// Size of shape icons in legend
  icon_size : Double
} derive(Show)

///|
/// Create a new legend with default settings
pub fn Legend::new() -> Legend {
  {
    title: None,
    position: BottomRight,
    entries: [],
    fill: Some("#ffffff"),
    stroke: Some("#cccccc"),
    padding: 12.0,
    entry_gap: 8.0,
    icon_size: 20.0,
  }
}

///|
/// Create a legend with a specific position
pub fn Legend::with_position(position : LegendPosition) -> Legend {
  let legend = Legend::new()
  { ..legend, position, }
}

///|
/// Add an entry to the legend
pub fn Legend::add_entry(self : Legend, entry : LegendEntry) -> Unit {
  self.entries.push(entry)
}

///|
/// Add a shape entry to the legend
pub fn Legend::add_shape(
  self : Legend,
  shape : ShapeType,
  label : String,
) -> Unit {
  self.entries.push(LegendEntry::shape(shape, label, None))
}

///|
/// Add a connection entry to the legend
pub fn Legend::add_connection(
  self : Legend,
  src_arrow : ArrowheadType,
  dst_arrow : ArrowheadType,
  label : String,
) -> Unit {
  self.entries.push(LegendEntry::connection(src_arrow, dst_arrow, label, None))
}

///|
/// Add a separator to the legend
pub fn Legend::add_separator(self : Legend) -> Unit {
  self.entries.push(LegendEntry::separator())
}

///|
pub fn Legend::set_title(self : Legend, title : String) -> Legend {
  { ..self, title: Some(title) }
}

///|
pub fn Legend::set_position(self : Legend, position : LegendPosition) -> Legend {
  { ..self, position, }
}

///|
pub fn Legend::set_fill(self : Legend, fill : String) -> Legend {
  { ..self, fill: Some(fill) }
}

///|
pub fn Legend::set_stroke(self : Legend, stroke : String) -> Legend {
  { ..self, stroke: Some(stroke) }
}

///|
pub fn Legend::set_padding(self : Legend, padding : Double) -> Legend {
  { ..self, padding, }
}

///|
pub fn Legend::set_entry_gap(self : Legend, entry_gap : Double) -> Legend {
  { ..self, entry_gap, }
}

///|
pub fn Legend::set_icon_size(self : Legend, icon_size : Double) -> Legend {
  { ..self, icon_size, }
}

///|
/// Check if legend has any entries
pub fn Legend::is_empty(self : Legend) -> Bool {
  self.entries.is_empty()
}

///|
/// Get the number of entries (excluding separators)
pub fn Legend::entry_count(self : Legend) -> Int {
  let mut count = 0
  for entry in self.entries {
    match entry {
      Separator => ()
      _ => count += 1
    }
  }
  count
}

///|
/// Calculate the bounding box size for the legend
pub fn Legend::calculate_size(
  self : Legend,
  font_size : Int,
) -> (Double, Double) {
  if self.is_empty() {
    return (0.0, 0.0)
  }
  let mut max_label_width = 0.0
  let mut total_height = self.padding * 2.0
  match self.title {
    Some(t) => {
      max_label_width = t.length().to_double() * font_size.to_double() * 0.6
      total_height = total_height + font_size.to_double() + self.entry_gap
    }
    None => ()
  }
  for entry in self.entries {
    match entry {
      ShapeEntry(label~, ..)
      | ConnectionEntry(label~, ..)
      | CustomEntry(label~, ..) => {
        let label_width = label.length().to_double() *
          font_size.to_double() *
          0.6
        max_label_width = if label_width > max_label_width {
          label_width
        } else {
          max_label_width
        }
        total_height = total_height + self.icon_size + self.entry_gap
      }
      Separator => total_height = total_height + 4.0 + self.entry_gap
    }
  }
  let width = self.padding * 2.0 +
    self.icon_size +
    self.entry_gap +
    max_label_width
  (width, total_height)
}
