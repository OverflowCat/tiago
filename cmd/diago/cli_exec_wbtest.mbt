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
test "write_render_output writes svg before returning bundling warning" {
  let out_path = ".diago_cli_exec_bundle_warning.svg"
  remove_cli_exec_test_file(out_path)
  let compiled : CompiledSourceResult = {
    output: "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>",
    warning: Some("failed to bundle local images: [./missing.svg]"),
  }
  match
    write_render_output(
      OutputMode::Svg,
      Some(out_path),
      compiled,
      announce_write=false,
    ) {
    Ok(_) => fail("expected bundling warning after writing svg")
    Err(msg) => assert_eq(msg, "failed to bundle local images: [./missing.svg]")
  }
  let written = @fs.read_file_to_string(out_path) catch {
    e => fail("expected svg output file to exist: \{e}")
  }
  remove_cli_exec_test_file(out_path)
  assert_eq(written, compiled.output)
}

///|
test "write_render_output does not write binary targets when bundling warns" {
  let out_path = ".diago_cli_exec_bundle_warning.png"
  remove_cli_exec_test_file(out_path)
  let compiled : CompiledSourceResult = {
    output: "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>",
    warning: Some(
      "failed to bundle remote images: [https://example.com/icon.svg]",
    ),
  }
  match
    write_render_output(
      OutputMode::Png,
      Some(out_path),
      compiled,
      announce_write=false,
    ) {
    Ok(_) => fail("expected bundling warning to stop binary conversion")
    Err(msg) =>
      assert_eq(
        msg, "failed to bundle remote images: [https://example.com/icon.svg]",
      )
  }
  assert_false(@fs.path_exists(out_path))
}

///|
fn remove_cli_exec_test_file(path : String) -> Unit {
  @fs.remove_file(path) catch {
    _ => ()
  }
}
