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
test "get_ref_ranges supports key references" {
  let source =
    #|a: 1
    #|a: 2
  let ranges = try! get_ref_ranges(source, "a")
  assert_eq(ranges.length(), 2)
  assert_eq(ranges[0].start.line, 0)
  assert_eq(ranges[1].start.line, 1)
}

///|
test "get_ref_ranges supports edge references" {
  let source =
    #|a -> b
    #|a -> b
  let ranges = try! get_ref_ranges(source, "a -> b")
  assert_eq(ranges.length(), 2)
  assert_eq(ranges[0].start.line, 0)
  assert_eq(ranges[1].start.line, 1)
}

///|
test "get_board_path_at_position returns board path" {
  let source =
    #|layers: {
    #|  core: {
    #|    service
    #|  }
    #|}
  let path = get_board_path_at_position(source, 2, 6)
  assert_eq(path.length(), 2)
  assert_eq(path[0], "layers")
  assert_eq(path[1], "core")
}

///|
test "get_completion_items suggests style keywords" {
  let items = get_completion_items("a.style.", 0, 8)
  assert_true(has_completion_label(items, "opacity"))
}

///|
test "get_completion_items suggests shape values" {
  let items = get_completion_items("a.shape:", 0, 8)
  assert_true(has_completion_label(items, "rectangle"))
}

///|
test "get_completion_items suggests near positions" {
  let items = get_completion_items("a.label.near:", 0, 13)
  assert_true(has_completion_label(items, "top-center"))
}

///|
test "get_completion_items provides numeric value hints" {
  let items = get_completion_items("a.width:", 0, 8)
  assert_true(has_completion_label(items, "(pixels)"))
}

///|
fn has_completion_label(items : Array[CompletionItem], label : String) -> Bool {
  for item in items {
    if item.label == label {
      return true
    }
  }
  false
}
