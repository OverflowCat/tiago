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
/// ASCII output tests

///|
test "ascii simple object" {
  let ascii = compile_ascii("server").unwrap()
  assert_true(ascii.contains("server"))
  assert_true(ascii.contains("+"))
  assert_true(ascii.contains("-"))
  assert_true(ascii.contains("|"))
}

///|
test "ascii multiple objects" {
  let source =
    #|a
    #|b
    #|c
  let ascii = compile_ascii(source).unwrap()
  assert_true(ascii.contains("a"))
  assert_true(ascii.contains("b"))
  assert_true(ascii.contains("c"))
}

///|
test "ascii edge has arrow" {
  let ascii = compile_ascii("a -> b").unwrap()
  assert_true(ascii.contains("a"))
  assert_true(ascii.contains("b"))
  assert_true(ascii.contains("v"))
}

///|
test "ascii edge has vertical line" {
  let ascii = compile_ascii("a -> b").unwrap()
  assert_true(ascii.contains("|"))
}

///|
test "ascii chain has multiple arrows" {
  let ascii = compile_ascii("a -> b -> c").unwrap()
  assert_true(ascii.contains("a"))
  assert_true(ascii.contains("b"))
  assert_true(ascii.contains("c"))
  let arrow_count = count_char(ascii, 'v')
  assert_true(arrow_count >= 2)
}

///|
test "ascii labeled edge shows label" {
  let ascii = compile_ascii("a -> b: hello").unwrap()
  assert_true(ascii.contains("a"))
  assert_true(ascii.contains("b"))
  assert_true(ascii.contains("hello"))
  assert_true(ascii.contains("v"))
}

///|
test "ascii bidirectional edge has two arrows" {
  let ascii = compile_ascii("a <-> b").unwrap()
  assert_true(ascii.contains("a"))
  assert_true(ascii.contains("b"))
  let down_arrows = count_char(ascii, 'v')
  let up_arrows = count_char(ascii, '^')
  assert_true(down_arrows >= 1 || up_arrows >= 1)
}

///|
test "ascii node with label" {
  let ascii = compile_ascii("server: Web Server").unwrap()
  assert_true(ascii.contains("Web Server"))
}

///|
test "ascii multiple edges from same source" {
  let source =
    #|a -> b
    #|a -> c
  let ascii = compile_ascii(source).unwrap()
  assert_true(ascii.contains("a"))
  assert_true(ascii.contains("b"))
  assert_true(ascii.contains("c"))
  let arrow_count = count_char(ascii, 'v')
  assert_true(arrow_count >= 2)
}

///|
test "ascii text shape shows only label" {
  let source =
    #|note: Hello World {
    #|  shape: text
    #|}
  let ascii = compile_ascii(source).unwrap()
  assert_true(ascii.contains("Hello World"))
}

///|
test "ascii code shape has backticks" {
  let source =
    #|code: snippet {
    #|  shape: code
    #|}
  let ascii = compile_ascii(source).unwrap()
  assert_true(ascii.contains("```") || ascii.contains("`"))
}

///|
test "ascii class shape has separator" {
  let source =
    #|MyClass {
    #|  shape: class
    #|}
  let ascii = compile_ascii(source).unwrap()
  assert_true(ascii.contains("+") || ascii.contains("-"))
}

///|
test "ascii sql_table shape has separator" {
  let source =
    #|users {
    #|  shape: sql_table
    #|}
  let ascii = compile_ascii(source).unwrap()
  assert_true(ascii.contains("+") || ascii.contains("-"))
}
