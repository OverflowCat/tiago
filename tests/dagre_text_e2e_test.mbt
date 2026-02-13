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
/// Dagre text E2E tests against committed snapshots and d2 references.
///
/// Unlike SVG parity checks, text output is validated by strict string equality.
/// There is no semantic normalization.

///|
let dagre_text_example_names : Array[String] = [
  "architecture", "arrowheads", "basic", "c4", "classes", "containers", "directions",
  "grid", "hello", "layers", "legend_auto", "legend_custom", "sequence", "shapes",
  "sql_tables", "styles", "variables",
]

///|
test "examples: dagre ascii e2e strict parity with d2" {
  let options = @diago.CompileOptions::new()
    .with_layout_engine(@diago.LayoutEngine::Dagre)
    .with_output_mode(@diago.OutputMode::Ascii)
    .with_target_spec(Some(""))
  for name in dagre_text_example_names {
    let source = read_required_text_file("examples/" + name + ".d2").unwrap()
    let actual = @diago.compile(source, options~) catch {
      e => fail("ascii compile failed for \{name}: \{e}")
    }
    let diago_snapshot = read_required_text_file(
      "examples/diago-dagre-ascii-output/" + name + ".txt",
    ).unwrap()
    assert_eq(
      actual,
      diago_snapshot,
      msg="ascii snapshot mismatch for \{name}: \{strict_diff_summary(actual, diago_snapshot)}",
    )

    let d2_snapshot = read_required_text_file(
      "examples/d2-dagre-ascii-output/" + name + ".txt",
    ).unwrap()
    assert_eq(
      actual,
      d2_snapshot,
      msg="ascii strict mismatch with d2 for \{name}: \{strict_diff_summary(actual, d2_snapshot)}",
    )
  }
}

///|
test "examples: dagre unicode e2e strict parity with d2" {
  let options = @diago.CompileOptions::new()
    .with_layout_engine(@diago.LayoutEngine::Dagre)
    .with_output_mode(@diago.OutputMode::Unicode)
    .with_target_spec(Some(""))
  for name in dagre_text_example_names {
    let source = read_required_text_file("examples/" + name + ".d2").unwrap()
    let actual = @diago.compile(source, options~) catch {
      e => fail("unicode compile failed for \{name}: \{e}")
    }
    let diago_snapshot = read_required_text_file(
      "examples/diago-dagre-unicode-output/" + name + ".txt",
    ).unwrap()
    assert_eq(
      actual,
      diago_snapshot,
      msg="unicode snapshot mismatch for \{name}: \{strict_diff_summary(actual, diago_snapshot)}",
    )

    let d2_snapshot = read_required_text_file(
      "examples/d2-dagre-unicode-output/" + name + ".txt",
    ).unwrap()
    assert_eq(
      actual,
      d2_snapshot,
      msg="unicode strict mismatch with d2 for \{name}: \{strict_diff_summary(actual, d2_snapshot)}",
    )
  }
}

///|
fn read_required_text_file(path : String) -> Result[String, String] {
  Ok(@fs.read_file_to_string(path)) catch {
    _ => Err("required file missing: \{path}")
  }
}

///|
fn strict_diff_summary(actual : String, expected : String) -> String {
  if actual == expected {
    return "equal"
  }
  let actual_lines : Array[String] = []
  for line in actual.split("\n") {
    actual_lines.push(line.to_string())
  }
  let expected_lines : Array[String] = []
  for line in expected.split("\n") {
    expected_lines.push(line.to_string())
  }
  let min_len = if actual_lines.length() < expected_lines.length() {
    actual_lines.length()
  } else {
    expected_lines.length()
  }
  for i in 0..<min_len {
    if actual_lines[i] != expected_lines[i] {
      return "line=\{i + 1}, actual=\{actual_lines[i]}, expected=\{expected_lines[i]}"
    }
  }
  "line-count differs: actual=\{actual_lines.length()}, expected=\{expected_lines.length()}"
}
