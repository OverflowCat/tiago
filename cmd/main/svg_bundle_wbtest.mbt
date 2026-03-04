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
test "bundle local image href to data uri" {
  let icon_path = ".diago_bundle_test_icon.svg"
  remove_test_file(icon_path)
  let icon_svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>
  @fs.write_string_to_file(icon_path, icon_svg)
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href=".diago_bundle_test_icon.svg" x="0" y="0" width="1" height="1"/></svg>
  let bundled = bundle_svg_images(svg, Some(".")).unwrap()
  remove_test_file(icon_path)
  assert_true(bundled.contains("data:image/svg+xml;base64,"))
  assert_false(bundled.contains("href=\".diago_bundle_test_icon.svg\""))
}

///|
test "bundle updates href and xlink:href together" {
  let icon_path = ".diago_bundle_test_icon_xlink.svg"
  remove_test_file(icon_path)
  let icon_svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>
  @fs.write_string_to_file(icon_path, icon_svg)
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href=".diago_bundle_test_icon_xlink.svg" xlink:href=".diago_bundle_test_icon_xlink.svg"/></svg>
  let bundled = bundle_svg_images(svg, Some(".")).unwrap()
  remove_test_file(icon_path)
  assert_true(bundled.contains("href=\"data:image/svg+xml;base64,"))
  assert_true(bundled.contains("xlink:href=\"data:image/svg+xml;base64,"))
}

///|
test "bundle keeps pre-bundled data uri unchanged" {
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="data:image/png;base64,AAAA"/></svg>
  let bundled = bundle_svg_images(svg, Some(".")).unwrap()
  assert_eq(bundled, svg)
}

///|
test "bundle remote image requires command execution support" {
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/icon.svg"/></svg>
  match bundle_svg_images(svg, None) {
    Ok(_) =>
      if command_exec_is_supported() {
        // native targets may fetch successfully depending on network, keep non-flaky.
        ()
      } else {
        fail("expected command execution support error")
      }
    Err(msg) =>
      if !command_exec_is_supported() {
        assert_true(msg.contains("requires native command execution support"))
      }
  }
}

///|
fn remove_test_file(path : String) -> Unit {
  @fs.remove_file(path) catch {
    _ => ()
  }
}
