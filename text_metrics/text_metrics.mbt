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
/// D2's TAB_SIZE constant (from lib/textmeasure/textmeasure.go:19)
const TAB_SIZE : Double = 4.0

///|
/// D2 space advances (from lib/textmeasure via ruler.Measure at font size 16)
const SPACE_WIDTH_SANS : Int = 3

///|
const SPACE_WIDTH_MONO : Int = 10

///|
priv enum FontKind {
  SansRegular
  SansBold
  SansItalic
  MonoRegular
}

///|
fn select_font_kind(
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> FontKind {
  if is_mono {
    MonoRegular
  } else if is_bold {
    SansBold
  } else if is_italic {
    SansItalic
  } else {
    SansRegular
  }
}

///|
fn lookup_width(kind : FontKind, codepoint : Int) -> Int {
  if codepoint >= 0 && codepoint < 256 {
    match kind {
      SansRegular => widths_sans_regular[codepoint]
      SansBold => widths_sans_bold[codepoint]
      SansItalic => widths_sans_italic[codepoint]
      MonoRegular => widths_mono_regular[codepoint]
    }
  } else if codepoint >= GEO_START && codepoint <= GEO_END {
    let idx = codepoint - GEO_START
    match kind {
      SansRegular => widths_sans_regular_geo[idx]
      SansBold => widths_sans_bold_geo[idx]
      SansItalic => widths_sans_italic_geo[idx]
      MonoRegular => widths_mono_regular_geo[idx]
    }
  } else {
    0
  }
}

///|
fn fallback_width(kind : FontKind) -> Int {
  // Use "M" as a conservative fallback for unknown glyphs.
  lookup_width(kind, 'M'.to_int())
}

///|
fn space_width_for(kind : FontKind) -> Int {
  match kind {
    MonoRegular => SPACE_WIDTH_MONO
    _ => SPACE_WIDTH_SANS
  }
}

///|
fn line_height_for(font_size : Int, is_mono : Bool) -> Double {
  let base = if is_mono {
    BASE_MONO_LINE_HEIGHT.to_double()
  } else {
    BASE_LINE_HEIGHT.to_double()
  }
  let mut height = base * font_size.to_double() / BASE_FONT_SIZE.to_double()
  if is_mono {
    height = height * CODE_LINE_HEIGHT
  }
  height
}

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
  let kind = select_font_kind(is_mono, is_bold, is_italic)
  let scale = font_size.to_double() / BASE_FONT_SIZE.to_double()
  let space_width = space_width_for(kind)
  let tab_width = space_width.to_double() * scale * TAB_SIZE
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
      Some('\r') =>
        // Carriage return moves to line origin without advancing lines.
        current_line_width = 0.0
      Some('\t') => {
        let rem = current_line_width % tab_width
        let advance = if rem == 0.0 { tab_width } else { tab_width - rem }
        current_line_width = current_line_width + advance
      }
      Some(' ') =>
        current_line_width = current_line_width +
          space_width.to_double() * scale
      Some(c) => {
        let cp = c.to_int()
        let w = lookup_width(kind, cp)
        let base = if w == 0 { fallback_width(kind) } else { w }
        current_line_width = current_line_width + base.to_double() * scale
      }
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
  let line_height = line_height_for(font_size, is_mono)
  let mut total_height = (line_count + 1).to_double() * line_height
  if is_mono {
    // D2: if hasLeading && numTrailing < len(lines) { h += t.FontSize }
    if has_leading {
      total_height = total_height + base_height
    }

    // D2: h += int(math.Ceil(textmeasure.CODE_LINE_HEIGHT * float64(t.FontSize*numTrailing)))
    let trailing_height = CODE_LINE_HEIGHT *
      base_height *
      num_trailing.to_double()
    total_height = total_height + trailing_height
  }

  // D2 text measurement returns raw text dimensions.
  // Shape padding / size-to-fit is applied later by the shape sizing layer.
  let width = max_line_width
  let height = total_height
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
