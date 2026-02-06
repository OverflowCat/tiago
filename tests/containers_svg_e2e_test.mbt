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
/// Focused E2E regression for the `containers` example.
///
/// This isolates hierarchical container routing parity.

///|
test "example: containers svg matches D2 reference (semantic)" {
  let name = "containers"
  let input_path = "examples/" + name + ".d2"
  let expected_path = "examples/d2-output/" + name + ".svg"
  let source = read_file(input_path).unwrap()
  let got_svg = normalize_newlines(compile(source).unwrap())
  write_file("examples/diago-output/" + name + ".svg", got_svg)
  let expected_svg = normalize_newlines(read_file(expected_path).unwrap())
  match compare_boxes(name, got_svg, expected_svg) {
    Ok(_) => ()
    Err(msg) => {
      write_file("examples/diago-output/" + name + ".boxes.diff", msg)
      fail(msg)
    }
  }
  match compare_routes(name, got_svg, expected_svg) {
    Ok(_) => ()
    Err(msg) => {
      write_file("examples/diago-output/" + name + ".routes.diff", msg)
      fail(msg)
    }
  }
}
