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
/// E2E regression tests for the example `.d2` inputs.
///
/// These tests compile the example sources using the in-repo ELK engine and
/// compare the rendered SVG output against checked-in reference SVGs.

///|
fn read_file(path : String) -> Result[String, String] {
  let content = Some(@fs.read_file_to_string(path)) catch { _ => None }
  match content {
    Some(s) => Ok(s)
    None => Err("failed to read file '" + path + "'")
  }
}

///|
fn normalize_newlines(s : String) -> String {
  // Convert CRLF to LF for stable comparisons across environments.
  let sb = StringBuilder::new()
  for c in s {
    if c != '\r' {
      sb.write_char(c)
    }
  }
  let out = sb.to_string()
  if out.has_suffix("\n") {
    out
  } else {
    out + "\n"
  }
}

///|
fn first_diff_summary(a : String, b : String) -> String {
  if a == b {
    return "no diff"
  }
  "contents differ"
}

///|
test "examples: svg matches reference" {
  // Keep this list explicit so missing/extra example files are intentional.
  let names : Array[String] = [
    "architecture", "arrowheads", "basic", "c4", "classes", "containers", "directions",
    "grid", "hello", "layers", "legend_auto", "legend_custom", "sequence", "shapes",
    "sql_tables", "styles", "variables",
  ]
  for name in names {
    let input_path = "examples/" + name + ".d2"
    let expected_path = "examples/reference/" + name + ".svg"
    let source = read_file(input_path).unwrap()
    let got_svg = normalize_newlines(compile(source).unwrap())
    let expected_svg = normalize_newlines(read_file(expected_path).unwrap())
    if got_svg != expected_svg {
      fail(
        "svg mismatch for '" +
        name +
        "': " +
        first_diff_summary(got_svg, expected_svg),
      )
    }
  }
}
