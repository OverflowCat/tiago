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
/// Legend rendering for ASCII output.

///|
/// Render a legend to ASCII
pub fn render_legend_ascii(
  grid : @ascii.Grid,
  legend : Legend,
  x : Int,
  y : Int,
  charset : @ascii.CharSet,
) -> Unit {
  if legend.is_empty() || legend.position == @graph.Hidden {
    return
  }
  let width = 30 // Fixed width for ASCII legend
  let height = 3 + legend.entries.length() * 2
  // Draw legend box
  grid.box_rect(x, y, x + width, y + height, charset)
  // Draw title if present
  let mut current_y = y + 1
  match legend.title {
    Some(title) => {
      let title_x = x + 2
      let display_title = truncate_string(title, width - 4)
      grid.text(title_x, current_y, display_title)
      current_y = current_y + 1
      // Separator after title
      grid.hline(x + 1, x + width - 1, current_y, charset.horizontal())
      current_y = current_y + 1
    }
    None => ()
  }
  // Render each entry
  for entry in legend.entries {
    let entry_x = x + 2
    match entry {
      ShapeEntry(shape~, label~, ..) => {
        // Draw shape icon as ASCII character
        let icon = shape_to_ascii_icon(shape)
        grid.text(entry_x, current_y, icon)
        // Draw label
        let label_x = entry_x + 4
        let display_label = truncate_string(label, width - 8)
        grid.text(label_x, current_y, display_label)
      }
      ConnectionEntry(src_arrow~, dst_arrow~, label~, ..) => {
        // Draw connection as ASCII
        let icon = connection_to_ascii_icon(src_arrow, dst_arrow)
        grid.text(entry_x, current_y, icon)
        // Draw label
        let label_x = entry_x + 4
        grid.text(label_x, current_y, label)
      }
      CustomEntry(icon~, label~) => {
        grid.text(entry_x, current_y, icon)
        let label_x = entry_x + 4
        grid.text(label_x, current_y, label)
      }
      Separator =>
        grid.hline(x + 1, x + width - 1, current_y, charset.horizontal())
    }
    current_y = current_y + 1
  }
}

///|
fn truncate_string(s : String, max_len : Int) -> String {
  if s.length() <= max_len {
    return s
  }
  let buf = StringBuilder::new()
  let chars = s.to_array()
  for i = 0; i < max_len - 3; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.write_string("...")
  buf.to_string()
}

///|
fn shape_to_ascii_icon(shape : ShapeType) -> String {
  match shape {
    Rectangle | Square => "[]"
    Circle | Oval => "()"
    Diamond => "<>"
    Cylinder => "||"
    Person => "/\\"
    Cloud => "(~)"
    Document => "[~]"
    _ => "[]"
  }
}

///|
fn connection_to_ascii_icon(src : ArrowheadType, dst : ArrowheadType) -> String {
  let start = src.to_ascii(true)
  let end = dst.to_ascii(false)
  start + "--" + end
}
