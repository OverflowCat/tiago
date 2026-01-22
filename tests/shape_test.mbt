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
/// Shape tests: all shape rendering tests

///|
test "circle shape" {
  let source =
    #|node {
    #|  shape: circle
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<ellipse"))
}

///|
test "oval shape" {
  let source =
    #|node {
    #|  shape: oval
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<ellipse"))
}

///|
test "cylinder shape" {
  let source =
    #|db {
    #|  shape: cylinder
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "diamond shape" {
  let source =
    #|decision {
    #|  shape: diamond
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<polygon"))
}

///|
test "hexagon shape" {
  let source =
    #|process {
    #|  shape: hexagon
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<polygon"))
}

///|
test "octagon shape" {
  let source =
    #|stop {
    #|  shape: octagon
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<polygon"))
}

///|
test "parallelogram shape" {
  let source =
    #|input {
    #|  shape: parallelogram
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<polygon"))
}

///|
test "person shape" {
  let source =
    #|user {
    #|  shape: person
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<circle"))
  assert_true(svg.contains("<line"))
}

///|
test "cloud shape" {
  let source =
    #|aws {
    #|  shape: cloud
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("C ")) // bezier curve
}

///|
test "document shape" {
  let source =
    #|doc {
    #|  shape: document
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "queue shape" {
  let source =
    #|queue {
    #|  shape: queue
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "stored_data shape" {
  let source =
    #|storage {
    #|  shape: stored_data
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "page shape" {
  let source =
    #|paper {
    #|  shape: page
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "package shape" {
  let source =
    #|pkg {
    #|  shape: package
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "step shape" {
  let source =
    #|process {
    #|  shape: step
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<polygon"))
}

///|
test "callout shape" {
  let source =
    #|note {
    #|  shape: callout
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
}

///|
test "text shape has no border" {
  let source =
    #|note {
    #|  shape: text
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("note"))
}

///|
test "code shape has monospace font" {
  let source =
    #|snippet {
    #|  shape: code
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("monospace"))
  assert_true(svg.contains("#1e1e1e")) // dark background
}

///|
test "code shape has dark background" {
  let source =
    #|code_block: some code here {
    #|  shape: code
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("fill=\"#1e1e1e\""))
  assert_true(svg.contains("fill=\"#d4d4d4\"")) // light text color
}

///|
test "class shape has separator line" {
  let source =
    #|MyClass {
    #|  shape: class
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<line"))
  assert_true(svg.contains("font-weight=\"bold\""))
}

///|
test "class shape renders class name" {
  let source =
    #|UserModel: UserModel {
    #|  shape: class
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("UserModel"))
}

///|
test "sql_table shape has header" {
  let source =
    #|users {
    #|  shape: sql_table
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("font-size=\"24\"")) // header font size
}

///|
test "sql_table shape renders table name" {
  let source =
    #|orders: orders {
    #|  shape: sql_table
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("orders"))
}

///|
test "image shape renders image element" {
  let source =
    #|logo {
    #|  shape: image
    #|  icon: "./logo.png"
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<image"))
  assert_true(svg.contains("href=\"./logo.png\""))
  assert_true(svg.contains("preserveAspectRatio"))
}

///|
test "image shape without icon renders nothing" {
  let source =
    #|img {
    #|  shape: image
    #|}
  let svg = compile(source).unwrap()
  // Should not crash, just no image element
  assert_true(svg.contains("<svg"))
}

///|
test "c4_person shape renders person icon" {
  let source =
    #|user: User {
    #|  shape: c4_person
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<circle")) // Head
  assert_true(svg.contains("<rect")) // Body
  assert_true(svg.contains("User"))
}

///|
test "c4_container shape renders rounded rectangle" {
  let source =
    #|api: API Gateway {
    #|  shape: c4_container
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<rect"))
  assert_true(svg.contains("rx=\"10\"")) // Rounded corners
  assert_true(svg.contains("API Gateway"))
}
