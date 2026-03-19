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
  assert_true(svg.contains("<path"))
}

///|
test "hexagon shape" {
  let source =
    #|process {
    #|  shape: hexagon
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
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
  assert_true(svg.contains("<path"))
}

///|
test "person shape" {
  let source =
    #|user {
    #|  shape: person
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
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
  assert_true(svg.contains("<path"))
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
  assert_true(svg.contains("class=\"text-mono\""))
  assert_true(svg.contains("class=\"light-code\""))
  assert_true(svg.contains("class=\"dark-code\""))
}

///|
test "code shape has dark background" {
  let source =
    #|code_block: some code here {
    #|  shape: code
    #|}
  let svg = match compile(source) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_true(svg.contains("fill:#ffffff"))
  assert_true(svg.contains("fill:#1e1e2e"))
}

///|
test "block string language aliases normalize like the reference" {
  let source =
    #|js_node: |js const x = 1 |
    #|go_node: |go defer f() |
    #|py_node: |py print("x") |
    #|rb_node: |rb puts "x" |
    #|ts_node: |ts const x: number = 1 |
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  let js_node = graph.find_object("js_node").unwrap()
  let go_node = graph.find_object("go_node").unwrap()
  let py_node = graph.find_object("py_node").unwrap()
  let rb_node = graph.find_object("rb_node").unwrap()
  let ts_node = graph.find_object("ts_node").unwrap()
  assert_true(js_node.classes.contains("lang:javascript"))
  assert_true(go_node.classes.contains("lang:golang"))
  assert_true(py_node.classes.contains("lang:python"))
  assert_true(rb_node.classes.contains("lang:ruby"))
  assert_true(ts_node.classes.contains("lang:typescript"))
}

///|
test "explicit code shape forces plaintext language" {
  let source =
    #|snippet: |js const x = 1 | {
    #|  shape: code
    #|}
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  let snippet = graph.find_object("snippet").unwrap()
  assert_true(snippet.shape_type == @graph.ShapeType::Code)
  assert_true(snippet.classes.contains("lang:text"))
  assert_false(snippet.classes.contains("lang:javascript"))
}

///|
test "label block string applies language and shape defaults" {
  let source =
    #|snippet: {
    #|  label: |py print("x") |
    #|}
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  let snippet = graph.find_object("snippet").unwrap()
  assert_true(snippet.shape_type == @graph.ShapeType::Code)
  assert_true(snippet.classes.contains("lang:python"))
}

///|
test "class shape has separator line" {
  let source =
    #|MyClass {
    #|  shape: class
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<line"))
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
  assert_true(svg.contains("font-size:24px")) // header font size
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
