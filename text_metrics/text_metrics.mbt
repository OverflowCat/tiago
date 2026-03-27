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
/// This implementation intentionally uses a coarse heuristic instead of
/// font-specific glyph metrics to keep the WASM payload small.

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
/// Reference CODE_LINE_HEIGHT constant.
const CODE_LINE_HEIGHT : Double = 1.3

///|
/// Reference TAB_SIZE constant.
const TAB_SIZE : Double = 4.0

///|
const REGULAR_LINE_HEIGHT : Double = 1.25

///|
priv enum FontKind {
  SansRegular
  SansBold
  SansSemibold
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
fn base_char_width_factor(kind : FontKind) -> Double {
  match kind {
    MonoRegular => 0.62
    SansRegular => 0.56
    SansBold => 0.60
    SansSemibold => 0.59
    SansItalic => 0.57
  }
}

///|
fn char_width_multiplier(cp : Int) -> Double {
  if cp == ' '.to_int() {
    0.55
  } else if cp == '\t'.to_int() {
    TAB_SIZE
  } else if cp <= 0x7F {
    match cp.unsafe_to_char() {
      'i' | 'l' | 'I' | '.' | ',' | '\'' | '`' | '!' | '|' | ':' | ';' => 0.55
      '(' | ')' | '[' | ']' | '{' | '}' | '/' | '\\' => 0.7
      'm' | 'w' | 'M' | 'W' | '@' | '#' | '%' | '&' => 1.35
      _ => 1.0
    }
  } else if is_cjk_codepoint(cp) {
    1.9
  } else {
    1.2
  }
}

///|
fn is_cjk_codepoint(cp : Int) -> Bool {
  (cp >= 0x2E80 && cp <= 0x9FFF) ||
  (cp >= 0xAC00 && cp <= 0xD7AF) ||
  (cp >= 0xF900 && cp <= 0xFAFF) ||
  (cp >= 0xFF01 && cp <= 0xFF60) ||
  (cp >= 0xFFE0 && cp <= 0xFFE6)
}

///|
fn line_height_for(font_size : Int, is_code : Bool) -> Double {
  if is_code {
    font_size.to_double() * CODE_LINE_HEIGHT
  } else {
    font_size.to_double() * REGULAR_LINE_HEIGHT
  }
}

///|
fn split_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    lines.push(line.to_string())
  }
  if lines.is_empty() {
    lines.push("")
  }
  lines
}

///|
fn line_width_heuristic(
  line : String,
  font_size : Int,
  kind : FontKind,
) -> Double {
  let base_width = font_size.to_double() * base_char_width_factor(kind)
  let mut width = 0.0
  let len = line.length()
  let mut i = 0
  while i < len {
    match line[i].to_char() {
      Some(c) => {
        width = width + base_width * char_width_multiplier(c.to_int())
      }
      None => ()
    }
    i = i + 1
  }
  width
}

///|
fn measure_text_with_mode(
  text : String,
  font_size : Int,
  kind : FontKind,
  _bounds_with_dot : Bool,
  use_code_line_height : Bool,
) -> MeasuredText {
  let lines = split_lines(text)
  let mut max_line_width = 0.0
  for line in lines {
    let line_width = line_width_heuristic(line, font_size, kind)
    if line_width > max_line_width {
      max_line_width = line_width
    }
  }
  let line_count = lines.length() - 1
  let height = @math.ceil(
    line_height_for(font_size, use_code_line_height) * lines.length().to_double(),
  )
  let width = @math.ceil(max_line_width)
  { dimensions: { width, height }, line_count, max_line_width }
}

///|
pub fn measure_text(
  text : String,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> MeasuredText {
  let kind = select_font_kind(is_mono, is_bold, is_italic)
  measure_text_with_mode(text, font_size, kind, is_mono, false)
}

///|
fn trailing_dot_delta_for_line(
  _line : String,
  _font_size : Int,
  _kind : FontKind,
) -> Double {
  0.0
}

///|
pub fn measure_text_with_dot_bounds(
  text : String,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> MeasuredText {
  let kind = select_font_kind(is_mono, is_bold, is_italic)
  measure_text_with_dot_bounds_kind(text, font_size, kind)
}

///|
fn measure_text_with_dot_bounds_kind(
  text : String,
  font_size : Int,
  kind : FontKind,
) -> MeasuredText {
  let is_mono = match kind {
    MonoRegular => true
    _ => false
  }
  let base = measure_text_with_mode(text, font_size, kind, is_mono, false)
  let mut max_line_width = 0.0
  for line in text.split("\n") {
    let line_text = line.to_string()
    let line_measured = measure_text_with_mode(
      line_text, font_size, kind, is_mono, false,
    )
    let line_width = line_measured.max_line_width +
      trailing_dot_delta_for_line(line_text, font_size, kind)
    if line_width > max_line_width {
      max_line_width = line_width
    }
  }
  let width = @math.ceil(max_line_width)
  {
    dimensions: { width, height: base.dimensions.height },
    line_count: base.line_count,
    max_line_width,
  }
}

///|
pub fn measure_text_code(
  text : String,
  font_size : Int,
  is_bold : Bool,
  is_italic : Bool,
) -> MeasuredText {
  let kind = select_font_kind(true, is_bold, is_italic)
  measure_text_with_mode(text, font_size, kind, true, true)
}

///|
pub fn measure_text_mono_plain(text : String, font_size : Int) -> MeasuredText {
  measure_text_with_mode(text, font_size, MonoRegular, false, false)
}

///|
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
pub fn measure_label_code(
  text : String,
  font_size : Int,
  is_bold : Bool,
  is_italic : Bool,
) -> TextDimensions {
  measure_text_code(text, font_size, is_bold, is_italic).dimensions
}

///|
pub fn measure_edge_label(text : String, font_size : Int) -> TextDimensions {
  measure_label(text, font_size, false, false, false)
}
