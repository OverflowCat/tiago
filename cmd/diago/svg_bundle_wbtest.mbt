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
  let bundled = bundle_local_svg_images(svg, Some("."))
  remove_test_file(icon_path)
  assert_eq(bundled.error, None)
  assert_true(bundled.svg.contains("data:image/svg+xml;base64,"))
  assert_false(bundled.svg.contains("href=\".diago_bundle_test_icon.svg\""))
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
  let bundled = bundle_local_svg_images(svg, Some("."))
  remove_test_file(icon_path)
  assert_eq(bundled.error, None)
  assert_true(bundled.svg.contains("href=\"data:image/svg+xml;base64,"))
  assert_true(bundled.svg.contains("xlink:href=\"data:image/svg+xml;base64,"))
}

///|
test "bundle keeps pre-bundled data uri unchanged" {
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="data:image/png;base64,AAAA"/></svg>
  let bundled = bundle_local_svg_images(svg, Some("."))
  assert_eq(bundled.error, None)
  assert_eq(bundled.svg, svg)
}

///|
test "bundle local image resolves relative paths from base path" {
  let dir = ".diago_bundle_nested"
  let icon_path = dir + "/test_svg.svg"
  let icon_svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>
  remove_test_file(icon_path)
  remove_test_dir(dir)
  @fs.create_dir(dir)
  @fs.write_string_to_file(icon_path, icon_svg)
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="./test_svg.svg"/></svg>
  let bundled = bundle_local_svg_images(svg, Some(dir))
  remove_test_file(icon_path)
  remove_test_dir(dir)
  assert_eq(bundled.error, None)
  assert_true(bundled.svg.contains("data:image/svg+xml;base64,"))
}

///|
test "bundle local image keeps svg and reports invalid relative base path" {
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="./missing.svg"/></svg>
  let bundled = bundle_local_svg_images(svg, Some(".diago_missing_bundle_dir"))
  assert_eq(
    bundled.error,
    Some("failed to bundle local images: [./missing.svg]"),
  )
  assert_eq(bundled.svg, svg)
}

///|
test "bundle remote duplicate url is fetched once per run" {
  reset_bundle_test_state()
  let url = "https://example.com/icon.svg"
  test_remote_fetch_ok_overrides[url] = (ascii_bytes(test_svg_payload), "")
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/icon.svg"/><image href="https://example.com/icon.svg"/></svg>
  let bundled = bundle_remote_svg_images(svg)
  assert_eq(bundled.error, None)
  assert_eq(test_remote_fetch_count.get_or_default(url, 0), 1)
  assert_false(bundled.svg.contains(url))
  assert_eq(count_occurrences(bundled.svg, "data:image/svg+xml;base64,"), 2)
  reset_bundle_test_state()
}

///|
test "bundle remote cache reuses fetched image across runs when enabled" {
  reset_bundle_test_state()
  let url = "https://example.com/icon.svg"
  test_remote_fetch_ok_overrides[url] = (
    ascii_bytes(test_svg_payload),
    "image/svg+xml",
  )
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/icon.svg"/></svg>
  ignore(bundle_remote_svg_images(svg, cache_images=true))
  ignore(bundle_remote_svg_images(svg, cache_images=true))
  assert_eq(test_remote_fetch_count.get_or_default(url, 0), 1)
  test_remote_fetch_count.clear()
  persistent_bundle_cache.clear()
  ignore(bundle_remote_svg_images(svg, cache_images=false))
  ignore(bundle_remote_svg_images(svg, cache_images=false))
  assert_eq(test_remote_fetch_count.get_or_default(url, 0), 2)
  reset_bundle_test_state()
}

///|
test "bundle remote image keeps svg and reports oversized response" {
  reset_bundle_test_state()
  let url = "https://example.com/huge.bin"
  test_remote_fetch_ok_overrides[url] = (
    Bytes::makei(max_bundle_image_size + 1, fn(_i) { b'a' }),
    "application/octet-stream",
  )
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/huge.bin"/></svg>
  let bundled = bundle_remote_svg_images(svg)
  assert_eq(
    bundled.error,
    Some("failed to bundle remote images: [https://example.com/huge.bin]"),
  )
  assert_eq(bundled.svg, svg)
  reset_bundle_test_state()
}

///|
test "bundle remote image keeps svg and reports fetch errors" {
  reset_bundle_test_state()
  let url = "https://example.com/error.svg"
  test_remote_fetch_error_overrides[url] = "expected status 200 but got 500 Internal Server Error"
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/error.svg"/></svg>
  let bundled = bundle_remote_svg_images(svg)
  assert_eq(
    bundled.error,
    Some("failed to bundle remote images: [https://example.com/error.svg]"),
  )
  assert_eq(bundled.svg, svg)
  reset_bundle_test_state()
}

///|
test "bundle remote image requires command execution support" {
  if command_exec_is_supported() {
    return
  }
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/icon.svg"/></svg>
  let bundled = bundle_remote_svg_images(svg)
  assert_eq(
    bundled.error,
    Some("failed to bundle remote images: [https://example.com/icon.svg]"),
  )
  assert_eq(bundled.svg, svg)
}

///|
test "bundle remote image preserves successful replacements when another fetch fails" {
  reset_bundle_test_state()
  let ok_url = "https://example.com/ok.svg"
  let bad_url = "https://example.com/error.svg"
  test_remote_fetch_ok_overrides[ok_url] = (ascii_bytes(test_svg_payload), "")
  test_remote_fetch_error_overrides[bad_url] = "expected status 200 but got 500 Internal Server Error"
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/ok.svg"/><image href="https://example.com/error.svg"/></svg>
  let bundled = bundle_remote_svg_images(svg)
  assert_eq(
    bundled.error,
    Some("failed to bundle remote images: [https://example.com/error.svg]"),
  )
  assert_true(bundled.svg.contains("data:image/svg+xml;base64,"))
  assert_true(bundled.svg.contains(bad_url))
  assert_false(bundled.svg.contains(ok_url))
  assert_eq(test_remote_fetch_count.get_or_default(ok_url, 0), 1)
  assert_eq(test_remote_fetch_count.get_or_default(bad_url, 0), 1)
  reset_bundle_test_state()
}

///|
fn remove_test_file(path : String) -> Unit {
  @fs.remove_file(path) catch {
    _ => ()
  }
}

///|
fn remove_test_dir(path : String) -> Unit {
  @fs.remove_dir(path) catch {
    _ => ()
  }
}

///|
fn ascii_bytes(text : String) -> Bytes {
  Bytes::makei(text.length(), fn(i) { text.code_unit_at(i).to_int().to_byte() })
}

///|
fn reset_bundle_test_state() -> Unit {
  persistent_bundle_cache.clear()
  test_remote_fetch_ok_overrides.clear()
  test_remote_fetch_error_overrides.clear()
  test_remote_fetch_count.clear()
}

///|
fn count_occurrences(s : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start < s.length() {
    match find_substring_from(s, needle, start) {
      Some(i) => {
        count = count + 1
        start = i + needle.length()
      }
      None => break
    }
  }
  count
}

///|
let test_svg_payload =
  #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>
