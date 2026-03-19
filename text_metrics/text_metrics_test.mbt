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
test "measure text width - short" {
  let dims = @text_metrics.measure_text("Hello", 16, false, false, false)
  assert_true(dims.dimensions.width >= 30.0)
  assert_true(dims.dimensions.height > 10.0)
  assert_eq(dims.line_count, 0)
}

///|
test "measure text width - long" {
  let dims = @text_metrics.measure_text(
    "This is a longer text for testing", 16, false, false, false,
  )
  assert_true(dims.dimensions.width > 100.0)
  assert_eq(dims.line_count, 0)
}

///|
test "measure text with newlines" {
  let dims = @text_metrics.measure_text(
    "Line 1\nLine 2\nLine 3", 14, false, false, false,
  )
  // 2 newline characters = line_count = 2
  assert_eq(dims.line_count, 2)
  assert_true(dims.max_line_width > 0.0)
  // With DEFAULT_LINE_HEIGHT_FACTOR=1.0, each line should be ~14px
  assert_true(dims.dimensions.height > 35.0)
}

///|
test "measure text with leading empty line" {
  let dims = @text_metrics.measure_text("\nLine 1", 14, false, false, false)
  // D2 adds font_size for leading empty line
  assert_eq(dims.line_count, 1)
  assert_true(dims.dimensions.height > 28.0)
}

///|
test "measure text with trailing empty lines" {
  let dims = @text_metrics.measure_text("Line 1\n\n", 14, false, false, false)
  // D2 adds CODE_LINE_HEIGHT * font_size * numTrailing
  assert_eq(dims.line_count, 2)
  assert_true(dims.dimensions.height > 30.0)
}

///|
test "measure label probe for empty nested grid parity" {
  inspect(
    @text_metrics.measure_label("inner", 24, false, true, false),
    content="{width: 56, height: 31}",
  )
}

///|
