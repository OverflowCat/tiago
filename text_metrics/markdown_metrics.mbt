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
/// Markdown measurement approximating the reference markdown sizing logic.
///
/// The upstream implementation renders Markdown into HTML and measures the
/// resulting block tree. Diago does not yet have the same HTML measurement
/// stack, so this package mirrors the reference block-level constants and composition
/// rules over the parsed CommonMark AST. This keeps layout and SVG
/// `foreignObject` sizing aligned with upstream fixtures such as
/// `constant_near_title`.

///|
const D2_MARKDOWN_LINE_HEIGHT : Double = 1.5

///|
const D2_MARKDOWN_LINE_HEIGHT_HEADING : Double = 1.25

///|
const D2_MARKDOWN_UL_OL_PADDING_LEFT_EM : Double = 2.0

///|
const D2_MARKDOWN_UL_MARGIN_BOTTOM : Double = 16.0

///|
const D2_MARKDOWN_LI_P_MARGIN_TOP : Double = 16.0

///|
const D2_MARKDOWN_LI_MARGIN_TOP_EM : Double = 0.25

///|
const D2_MARKDOWN_P_MARGIN_BOTTOM : Double = 16.0

///|
const D2_MARKDOWN_H_MARGIN_TOP : Double = 24.0

///|
const D2_MARKDOWN_H_MARGIN_BOTTOM : Double = 16.0

///|
const D2_MARKDOWN_H1_H2_PADDING_BOTTOM_EM : Double = 0.3

///|
const D2_MARKDOWN_H1_H2_BORDER_BOTTOM : Double = 1.0

///|
priv struct MarkdownBlockMetrics {
  width : Double
  height : Double
  margin_top : Double
  margin_bottom : Double
}

///|
fn markdown_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn markdown_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn markdown_block_metrics_empty() -> MarkdownBlockMetrics {
  { width: 0.0, height: 0.0, margin_top: 0.0, margin_bottom: 0.0 }
}

///|
fn markdown_header_font_size(base_font_size : Int, level : Int) -> Int {
  let base = base_font_size.to_double()
  let scaled = match level {
    1 => base * 2.0
    2 => base * 1.5
    3 => base * 1.25
    4 => base * 1.0
    5 => base * 0.875
    6 => base * 0.85
    _ => base
  }
  let out = scaled.to_int()
  if out > 0 {
    out
  } else {
    1
  }
}

///|
fn markdown_inline_dimensions(
  inline : @cmark.Inline,
  font_size : Int,
  line_height : Double,
  kind : FontKind,
) -> (Double, Double) {
  let lines = inline.to_plain_text(break_on_soft=false).to_array()
  let mut max_width = 0.0
  let mut line_count = 0
  for line in lines {
    let text = line.to_array().join("")
    let measured = measure_text_with_dot_bounds_kind(text, font_size, kind)
    if measured.max_line_width > max_width {
      max_width = measured.max_line_width
    }
    line_count = line_count + 1
  }
  if line_count == 0 {
    line_count = 1
  }
  (max_width, line_height * font_size.to_double() * line_count.to_double())
}

///|
fn markdown_combine_blocks(
  blocks : Array[MarkdownBlockMetrics],
) -> MarkdownBlockMetrics {
  if blocks.is_empty() {
    return markdown_block_metrics_empty()
  }
  let mut width = 0.0
  let mut height = 0.0
  let mut margin_top = 0.0
  let mut margin_bottom = 0.0
  let mut prev_margin_bottom = 0.0
  for i in 0..<blocks.length() {
    let block = blocks[i]
    if i == 0 {
      margin_top = markdown_max_double(margin_top, block.margin_top)
    } else {
      let margin_diff = block.margin_top - prev_margin_bottom
      if margin_diff > 0.0 {
        height = height + margin_diff
      }
    }
    if i == blocks.length() - 1 {
      margin_bottom = markdown_max_double(margin_bottom, block.margin_bottom)
    } else {
      height = height + block.margin_bottom
      prev_margin_bottom = block.margin_bottom
    }
    height = height + block.height
    width = markdown_max_double(width, block.width)
  }
  { width, height, margin_top, margin_bottom }
}

///|
fn markdown_measure_block(
  block : @cmark.Block,
  base_font_size : Int,
  list_depth : Int,
  in_list_item : Bool,
) -> MarkdownBlockMetrics {
  match block {
    @cmark.Block::BlankLine(_)
    | @cmark.Block::HtmlBlock(_)
    | @cmark.Block::LinkRefDefinition(_) => markdown_block_metrics_empty()
    @cmark.Block::Blocks(node) => {
      let parts : Array[MarkdownBlockMetrics] = []
      for child in node.v.to_array() {
        parts.push(
          markdown_measure_block(
            child, base_font_size, list_depth, in_list_item,
          ),
        )
      }
      markdown_combine_blocks(parts)
    }
    @cmark.Block::Paragraph(node) => {
      let (width, height) = markdown_inline_dimensions(
        node.v.inline,
        base_font_size,
        D2_MARKDOWN_LINE_HEIGHT,
        SansRegular,
      )
      {
        width,
        height,
        margin_top: if in_list_item {
          D2_MARKDOWN_LI_P_MARGIN_TOP
        } else {
          0.0
        },
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    @cmark.Block::Heading(node) => {
      let heading_font_size = markdown_header_font_size(
        base_font_size,
        node.v.level,
      )
      let (width, inline_height) = markdown_inline_dimensions(
        node.v.inline,
        heading_font_size,
        D2_MARKDOWN_LINE_HEIGHT_HEADING,
        SansSemibold,
      )
      let mut height = inline_height
      if node.v.level == 1 || node.v.level == 2 {
        height = height +
          D2_MARKDOWN_H1_H2_PADDING_BOTTOM_EM * heading_font_size.to_double() +
          D2_MARKDOWN_H1_H2_BORDER_BOTTOM
      }
      {
        width,
        height,
        margin_top: D2_MARKDOWN_H_MARGIN_TOP,
        margin_bottom: D2_MARKDOWN_H_MARGIN_BOTTOM,
      }
    }
    @cmark.Block::List(node) => {
      let item_blocks : Array[MarkdownBlockMetrics] = []
      for i in 0..<node.v.items.length() {
        let item = node.v.items[i].v
        let inner = markdown_measure_block(
          item.block,
          base_font_size,
          list_depth + 1,
          true,
        )
        item_blocks.push({
          width: inner.width +
          D2_MARKDOWN_UL_OL_PADDING_LEFT_EM * base_font_size.to_double(),
          height: inner.height,
          margin_top: if i == 0 {
            0.0
          } else {
            D2_MARKDOWN_LI_MARGIN_TOP_EM * base_font_size.to_double()
          },
          margin_bottom: 0.0,
        })
      }
      let merged = markdown_combine_blocks(item_blocks)
      if list_depth == 0 {
        return {
          ..merged,
          margin_bottom: markdown_max_double(
            merged.margin_bottom,
            D2_MARKDOWN_UL_MARGIN_BOTTOM,
          ),
        }
      }
      merged
    }
    @cmark.Block::CodeBlock(node) | @cmark.Block::ExtMathBlock(node) => {
      let mut line_count = 0
      let mut max_line_width = 0.0
      let code_font_size = markdown_max_int(
        1,
        (base_font_size.to_double() * 0.85).to_int(),
      )
      for line in node.v.code.to_array() {
        let measured = measure_text_with_dot_bounds(
          line.v,
          code_font_size,
          true,
          false,
          false,
        )
        if measured.max_line_width > max_line_width {
          max_line_width = measured.max_line_width
        }
        line_count = line_count + 1
      }
      if line_count == 0 {
        line_count = 1
      }
      {
        width: max_line_width + 32.0,
        height: line_count.to_double() *
        base_font_size.to_double() *
        0.85 *
        1.45 +
        32.0,
        margin_top: 0.0,
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    @cmark.Block::ThematicBreak(_) =>
      {
        width: 0.0,
        height: 0.25 * base_font_size.to_double(),
        margin_top: D2_MARKDOWN_H_MARGIN_TOP,
        margin_bottom: D2_MARKDOWN_H_MARGIN_TOP,
      }
    @cmark.Block::BlockQuote(node) => {
      let inner = markdown_measure_block(
        node.v.block,
        base_font_size,
        list_depth,
        false,
      )
      {
        width: inner.width + 2.25 * base_font_size.to_double(),
        height: inner.height,
        margin_top: 0.0,
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    @cmark.Block::ExtTable(node) => {
      let mut max_width = 0.0
      let mut total_height = 0.0
      let row_height = D2_MARKDOWN_LINE_HEIGHT * base_font_size.to_double()
      for row in node.v.rows.to_array() {
        total_height = total_height + row_height
        match row.0.v {
          @cmark.TableRow::Header(cols) | @cmark.TableRow::Data(cols) => {
            let mut row_width = 1.0
            for col in cols.to_array() {
              let (cell_width, _) = markdown_inline_dimensions(
                col.0,
                base_font_size,
                D2_MARKDOWN_LINE_HEIGHT,
                SansRegular,
              )
              row_width = row_width + cell_width + 17.0
            }
            if row_width > max_width {
              max_width = row_width
            }
          }
          @cmark.TableRow::Sep(cols) => {
            let row_width = cols.length().to_double() *
              (base_font_size.to_double() + 17.0)
            if row_width > max_width {
              max_width = row_width
            }
          }
        }
      }
      {
        width: max_width,
        height: total_height + 2.0,
        margin_top: 0.0,
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    @cmark.Block::ExtFootnoteDefinition(node) =>
      markdown_measure_block(node.v.block, base_font_size, list_depth, false)
  }
}

///|
/// Measure a markdown label using compatibility block layout constants.
pub fn measure_label_markdown(text : String, font_size : Int) -> TextDimensions {
  if text == "" {
    return { width: 1.0, height: 1.0 }
  }
  let doc = @cmark.Doc::from_string(strict=false, text)
  let metrics = markdown_measure_block(doc.block, font_size, 0, false)
  { width: @math.ceil(metrics.width), height: @math.ceil(metrics.height) }
}
