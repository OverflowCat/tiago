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
/// Text measurement module
///
/// This module implements text dimension calculation following D2's approach:
/// - Uses D2's constant CODE_LINE_HEIGHT = 1.3
/// - Handles empty lines (leading/trailing) as D2 does
/// - Considers font styles (bold/italic) for width adjustment
///
/// Note: D2 uses actual font metrics from TrueType files via freetype.
/// Since MoonBit doesn't have a freetype binding, we use a simplified
/// estimation that follows D2's constants and logic as closely as possible.

///|
/// Text dimensions (width and height)
pub struct TextDimensions {
  width : Double
  height : Double
} derive(Eq, Show)

///|
/// Text measurement result with line information
pub struct MeasuredText {
  dimensions : TextDimensions
  line_count : Int
  max_line_width : Double
} derive(Eq, Show)

///|
/// D2's CODE_LINE_HEIGHT constant (from lib/textmeasure/textmeasure.go:20)
const CODE_LINE_HEIGHT : Double = 1.3

///|
/// D2's default line height factor (from textmeasure.Ruler initialization)
const DEFAULT_LINE_HEIGHT_FACTOR : Double = 1.0

///|
/// Calculate text dimensions following D2's approach (from d2graph.GetTextDimensionsWithMono)
///
/// Key aspects from D2 implementation:
/// 1. For code/mono text: use CODE_LINE_HEIGHT (1.3)
/// 2. For regular text: use DEFAULT_LINE_HEIGHT_FACTOR (1.0)
/// 3. Handle empty lines (leading/trailing) by adding font_size for each
/// 4. Consider font style: bold adds ~10% width, italic adds ~5%
pub fn measure_text(
  text : String,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> MeasuredText {
  let line_height_factor = if is_mono {
    CODE_LINE_HEIGHT
  } else {
    DEFAULT_LINE_HEIGHT_FACTOR
  }
  let base_char_width = 6.0 // Simplified estimation (D2 uses actual font glyph advance)
  let bold_factor = if is_bold { 1.1 } else { 1.0 }
  let italic_factor = if is_italic { 1.05 } else { 1.0 }
  let effective_char_width = base_char_width * bold_factor * italic_factor
  let mut max_line_width = 0.0
  let mut line_count = 0
  let mut current_line_width = 0.0

  // Analyze each character (D2's ruler.drawBuf approach)
  let len = text.length()
  let mut i = 0
  while i < len {
    match text[i].to_char() {
      Some('\n') => {
        // Line break: update max and reset
        if current_line_width > max_line_width {
          max_line_width = current_line_width
        }
        current_line_width = 0.0
        line_count = line_count + 1
      }
      Some(_) =>
        // Add character width (simplified from D2's glyph.advance)
        current_line_width = current_line_width + effective_char_width
      None => ()
    }
    i = i + 1
  }

  // Last line
  if current_line_width > max_line_width {
    max_line_width = current_line_width
  }

  // Handle empty lines (D2's logic from d2graph.GetTextDimensionsWithMono:1459-1476)
  let lines_iter = text.split("\n")
  let lines : Array[String] = []

  // Convert iter to array for indexing
  for line in lines_iter {
    lines.push(line.to_string())
  }

  // D2 checks if first line after split is empty (leading empty line)
  let mut has_leading = false
  let mut first_line = ""
  if lines.length() > 0 {
    first_line = lines[0]
    has_leading = first_line.trim() == ""
  }

  // Count trailing empty lines
  let mut num_trailing = 0
  if lines.length() > 0 {
    let mut j = lines.length() - 1
    while j >= 0 {
      if lines[j].trim() == "" {
        num_trailing = num_trailing + 1
      } else {
        break
      }
      j = j - 1
    }
  }

  // Calculate height following D2's formula
  let base_height = font_size.to_double()
  let line_height = base_height * line_height_factor
  let mut total_height = (line_count + 1).to_double() * line_height

  // D2: if hasLeading && numTrailing < len(lines) { h += t.FontSize }
  if has_leading {
    total_height = total_height + base_height
  }

  // D2: h += int(math.Ceil(textmeasure.CODE_LINE_HEIGHT * float64(t.FontSize*numTrailing)))
  let trailing_height = CODE_LINE_HEIGHT *
    base_height *
    num_trailing.to_double()
  total_height = total_height + trailing_height

  // Calculate width with padding (D2 uses padding in shape rendering)
  let padding = 20.0
  let width = max_line_width + padding * 2.0
  let height = total_height + padding * 2.0
  { dimensions: { width, height }, line_count, max_line_width }
}

///|
/// Measure label width with padding
pub fn measure_label(
  text : String,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> TextDimensions {
  measure_text(text, font_size, is_mono, is_bold, is_italic).dimensions
}

///|
/// Measure edge label width
pub fn measure_edge_label(text : String, font_size : Int) -> TextDimensions {
  measure_label(text, font_size, false, false, false)
}
