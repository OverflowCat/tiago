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
/// - Uses pre-generated glyph bounds and advances from D2's embedded fonts

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
/// Approximation for D2's line height scaling.
///
/// D2's `textmeasure.Ruler` computes line heights from font metrics at each size
/// (with hinting), which is not perfectly linear. For the embedded Source Sans
/// Pro / Source Code Pro fonts, the measured line height for a single line is
/// well-approximated by `ceil(font_size * 101 / 80)`.
///
/// This constant is chosen to match D2's `ruler.Measure` heights across common
/// sizes (e.g. 16 -> 21, 24 -> 31).
const LINE_HEIGHT_FACTOR : Double = 101.0 / 80.0

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
priv struct GlyphMetrics {
  x_min : Int
  x_max : Int
  advance_fixed : Int
}

///|
priv struct GlyphScale {
  metrics : GlyphMetrics
  scale : Double
  fixed_scale : Double
}

///|
fn lookup_kerning_fixed(
  kind : FontKind,
  left_codepoint : Int,
  right_codepoint : Int,
) -> Int {
  if left_codepoint < 0 ||
    left_codepoint >= 256 ||
    right_codepoint < 0 ||
    right_codepoint >= 256 {
    0
  } else {
    let idx = left_codepoint * 256 + right_codepoint
    match kind {
      SansRegular => kernings_fixed_sans_regular[idx]
      SansBold => kernings_fixed_sans_bold[idx]
      SansItalic => kernings_fixed_sans_italic[idx]
      MonoRegular => kernings_fixed_mono_regular[idx]
    }
  }
}

///|
fn lookup_base_glyph_metrics(kind : FontKind, codepoint : Int) -> GlyphMetrics {
  if codepoint >= 0 && codepoint < 256 {
    match kind {
      SansRegular =>
        {
          x_min: glyph_x_mins_sans_regular[codepoint],
          x_max: glyph_x_maxs_sans_regular[codepoint],
          advance_fixed: glyph_advances_fixed_sans_regular[codepoint],
        }
      SansBold =>
        {
          x_min: glyph_x_mins_sans_bold[codepoint],
          x_max: glyph_x_maxs_sans_bold[codepoint],
          advance_fixed: glyph_advances_fixed_sans_bold[codepoint],
        }
      SansItalic =>
        {
          x_min: glyph_x_mins_sans_italic[codepoint],
          x_max: glyph_x_maxs_sans_italic[codepoint],
          advance_fixed: glyph_advances_fixed_sans_italic[codepoint],
        }
      MonoRegular =>
        {
          x_min: glyph_x_mins_mono_regular[codepoint],
          x_max: glyph_x_maxs_mono_regular[codepoint],
          advance_fixed: glyph_advances_fixed_mono_regular[codepoint],
        }
    }
  } else if codepoint >= GEO_START && codepoint <= GEO_END {
    let idx = codepoint - GEO_START
    match kind {
      SansRegular =>
        {
          x_min: glyph_x_mins_sans_regular_geo[idx],
          x_max: glyph_x_maxs_sans_regular_geo[idx],
          advance_fixed: glyph_advances_fixed_sans_regular_geo[idx],
        }
      SansBold =>
        {
          x_min: glyph_x_mins_sans_bold_geo[idx],
          x_max: glyph_x_maxs_sans_bold_geo[idx],
          advance_fixed: glyph_advances_fixed_sans_bold_geo[idx],
        }
      SansItalic =>
        {
          x_min: glyph_x_mins_sans_italic_geo[idx],
          x_max: glyph_x_maxs_sans_italic_geo[idx],
          advance_fixed: glyph_advances_fixed_sans_italic_geo[idx],
        }
      MonoRegular =>
        {
          x_min: glyph_x_mins_mono_regular_geo[idx],
          x_max: glyph_x_maxs_mono_regular_geo[idx],
          advance_fixed: glyph_advances_fixed_mono_regular_geo[idx],
        }
    }
  } else {
    // Use "M" as a conservative fallback for unknown glyphs.
    lookup_base_glyph_metrics(kind, 'M'.to_int())
  }
}

///|
fn lookup_sized_glyph_metrics(
  kind : FontKind,
  codepoint : Int,
  font_size : Int,
  default_scale : Double,
  default_fixed_scale : Double,
) -> GlyphScale {
  let base = {
    metrics: lookup_base_glyph_metrics(kind, codepoint),
    scale: default_scale,
    fixed_scale: default_fixed_scale,
  }
  if codepoint < 0 || codepoint >= 256 {
    base
  } else {
    match kind {
      SansRegular =>
        if font_size == 20 {
          {
            metrics: {
              x_min: glyph_x_mins_sans_regular_sz20[codepoint],
              x_max: glyph_x_maxs_sans_regular_sz20[codepoint],
              advance_fixed: glyph_advances_fixed_sans_regular_sz20[codepoint],
            },
            scale: 1.0,
            fixed_scale: 1.0 / 64.0,
          }
        } else if font_size == 24 {
          {
            metrics: {
              x_min: glyph_x_mins_sans_regular_sz24[codepoint],
              x_max: glyph_x_maxs_sans_regular_sz24[codepoint],
              advance_fixed: glyph_advances_fixed_sans_regular_sz24[codepoint],
            },
            scale: 1.0,
            fixed_scale: 1.0 / 64.0,
          }
        } else if font_size == 28 {
          {
            metrics: {
              x_min: glyph_x_mins_sans_regular_sz28[codepoint],
              x_max: glyph_x_maxs_sans_regular_sz28[codepoint],
              advance_fixed: glyph_advances_fixed_sans_regular_sz28[codepoint],
            },
            scale: 1.0,
            fixed_scale: 1.0 / 64.0,
          }
        } else {
          base
        }
      SansBold =>
        if font_size == 29 {
          {
            metrics: {
              x_min: glyph_x_mins_sans_bold_sz29[codepoint],
              x_max: glyph_x_maxs_sans_bold_sz29[codepoint],
              advance_fixed: glyph_advances_fixed_sans_bold_sz29[codepoint],
            },
            scale: 1.0,
            fixed_scale: 1.0 / 64.0,
          }
        } else if font_size == 32 {
          {
            metrics: {
              x_min: glyph_x_mins_sans_bold_sz32[codepoint],
              x_max: glyph_x_maxs_sans_bold_sz32[codepoint],
              advance_fixed: glyph_advances_fixed_sans_bold_sz32[codepoint],
            },
            scale: 1.0,
            fixed_scale: 1.0 / 64.0,
          }
        } else {
          base
        }
      MonoRegular =>
        if font_size == 20 {
          {
            metrics: {
              x_min: glyph_x_mins_mono_regular_sz20[codepoint],
              x_max: glyph_x_maxs_mono_regular_sz20[codepoint],
              advance_fixed: glyph_advances_fixed_mono_regular_sz20[codepoint],
            },
            scale: 1.0,
            fixed_scale: 1.0 / 64.0,
          }
        } else {
          base
        }
      SansItalic => base
    }
  }
}

///|
fn line_height_for(font_size : Int, is_mono : Bool) -> Double {
  let mut height = font_size.to_double() * LINE_HEIGHT_FACTOR
  if is_mono {
    height = height * CODE_LINE_HEIGHT
  }
  height
}

///|
fn measure_text_with_mode(
  text : String,
  font_size : Int,
  kind : FontKind,
  bounds_with_dot : Bool,
  use_code_line_height : Bool,
) -> MeasuredText {
  let scale = font_size.to_double() / BASE_FONT_SIZE.to_double()
  let fixed_scale = scale / 64.0
  let space = lookup_sized_glyph_metrics(
    kind,
    ' '.to_int(),
    font_size,
    scale,
    fixed_scale,
  )
  let tab_width = space.metrics.advance_fixed.to_double() *
    space.fixed_scale *
    TAB_SIZE
  let kerning_fixed_scale = space.fixed_scale
  let mut line_count = 0
  let mut has_area = false
  let mut bounds_left = 0.0
  let mut bounds_right = 0.0
  let mut dot_x = 0.0
  let mut prev_cp = -1

  // Analyze each character (D2's ruler.drawBuf approach)
  let len = text.length()
  let mut i = 0
  while i < len {
    match text[i].to_char() {
      Some('\n') => {
        dot_x = 0.0
        line_count = line_count + 1
      }
      Some('\r') =>
        // Carriage return moves to line origin without advancing lines.
        dot_x = 0.0
      Some('\t') => {
        // Mirror D2's controlRune tab behavior (lib/textmeasure/textmeasure.go:244-252).
        // NOTE: This does not reset `prevR`; keep kerning behavior aligned with D2.
        let mut rem = dot_x % tab_width
        rem = rem % (rem + tab_width)
        if rem == 0.0 {
          rem = tab_width
        }
        dot_x = dot_x + rem
      }
      Some(c) => {
        let cp = c.to_int()
        if prev_cp >= 0 {
          let k_fixed = lookup_kerning_fixed(kind, prev_cp, cp)
          dot_x = dot_x + k_fixed.to_double() * kerning_fixed_scale
        }
        let sized = lookup_sized_glyph_metrics(
          kind, cp, font_size, scale, fixed_scale,
        )
        let m = sized.metrics
        let left = dot_x + m.x_min.to_double() * sized.scale
        let right = dot_x + m.x_max.to_double() * sized.scale
        let is_area = left != right

        if bounds_with_dot {
          if left < bounds_left {
            bounds_left = left
          }
          if right > bounds_right {
            bounds_right = right
          }
        } else if !has_area {
          bounds_left = left
          bounds_right = right
          if is_area {
            has_area = true
          }
        } else {
          if left < bounds_left {
            bounds_left = left
          }
          if right > bounds_right {
            bounds_right = right
          }
        }

        dot_x = dot_x + m.advance_fixed.to_double() * sized.fixed_scale
        prev_cp = cp

        if bounds_with_dot {
          if dot_x < bounds_left {
            bounds_left = dot_x
          }
          if dot_x > bounds_right {
            bounds_right = dot_x
          }
        }
      }
      None => ()
    }
    i = i + 1
  }

  let max_line_width = bounds_right - bounds_left

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
  let line_height = if use_code_line_height {
    // D2 parity for language-tagged code snippets.
    font_size.to_double() * CODE_LINE_HEIGHT
  } else {
    line_height_for(font_size, bounds_with_dot)
  }
  let mut total_height = (line_count + 1).to_double() * line_height
  if use_code_line_height {
    // D2: if hasLeading && numTrailing < len(lines) { h += t.FontSize }
    if has_leading && num_trailing < lines.length() {
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
  // D2 rounds up (`math.Ceil`) the measured bounds.
  let width = @math.ceil(max_line_width)
  let height = @math.ceil(total_height)
  { dimensions: { width, height }, line_count, max_line_width }
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
  measure_text_with_mode(text, font_size, kind, is_mono, false)
}

///|
fn trailing_dot_delta_for_line(
  line : String,
  font_size : Int,
  kind : FontKind,
) -> Double {
  let scale = font_size.to_double() / BASE_FONT_SIZE.to_double()
  let fixed_scale = scale / 64.0
  let mut last_cp = -1
  let len = line.length()
  let mut i = 0
  while i < len {
    match line[i].to_char() {
      Some('\n') | Some('\r') | Some('\t') => ()
      Some(c) => last_cp = c.to_int()
      None => ()
    }
    i = i + 1
  }
  if last_cp < 0 {
    return 0.0
  }
  let glyph = lookup_sized_glyph_metrics(
    kind, last_cp, font_size, scale, fixed_scale,
  )
  let advance = glyph.metrics.advance_fixed.to_double() * glyph.fixed_scale
  let right = glyph.metrics.x_max.to_double() * glyph.scale
  let delta = advance - right
  if delta > 0.0 {
    delta
  } else {
    0.0
  }
}

///|
/// Measure text using precise bounds that include the pen position ("dot").
///
/// D2's Markdown measuring path sets `ruler.boundsWithDot = true`. In the
/// MoonBit metrics pipeline we apply the equivalent trailing-dot correction per
/// line without changing the base line-height behavior.
pub fn measure_text_with_dot_bounds(
  text : String,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> MeasuredText {
  let kind = select_font_kind(is_mono, is_bold, is_italic)
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
/// Measure code text using monospace font and CODE_LINE_HEIGHT semantics.
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
/// Measure text using monospace glyph metrics with regular (non-code) line height.
///
/// This matches D2's `ruler.Measure(SourceCodePro, ...)` behavior used by
/// UML class sizing: monospace font, but without code-block line-height logic.
pub fn measure_text_mono_plain(text : String, font_size : Int) -> MeasuredText {
  measure_text_with_mode(text, font_size, MonoRegular, false, false)
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
/// Measure label dimensions for code snippets (language-tagged block strings).
pub fn measure_label_code(
  text : String,
  font_size : Int,
  is_bold : Bool,
  is_italic : Bool,
) -> TextDimensions {
  measure_text_code(text, font_size, is_bold, is_italic).dimensions
}

///|
/// Measure edge label width
pub fn measure_edge_label(text : String, font_size : Int) -> TextDimensions {
  measure_label(text, font_size, false, false, false)
}
