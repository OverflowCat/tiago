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
priv struct AttributeSpan {
  value_start : Int
  value_end : Int
}

///|
priv enum BundleScope {
  Local
  Remote
}

///|
priv struct SvgBundleResult {
  svg : String
  error : String?
}

///|
priv struct ImageTagBundleResult {
  tag : String
  error_href : String?
}

///|
let max_bundle_image_size : Int = 1 << 25

///|
let persistent_bundle_cache : Map[String, String] = {}

///|
// Whitebox tests use these maps to mirror D2's mockable HTTP transport.
let test_remote_fetch_ok_overrides : Map[String, (Bytes, String)] = {}

///|
let test_remote_fetch_error_overrides : Map[String, String] = {}

///|
let test_remote_fetch_count : Map[String, Int] = {}

///|
fn bundle_local_svg_images(
  svg : String,
  base_path : String?,
  cache_images? : Bool = false,
) -> SvgBundleResult {
  bundle_svg_images_in_scope(svg, base_path, BundleScope::Local, cache_images)
}

///|
fn bundle_remote_svg_images(
  svg : String,
  cache_images? : Bool = false,
) -> SvgBundleResult {
  bundle_svg_images_in_scope(svg, None, BundleScope::Remote, cache_images)
}

///|
fn bundle_svg_images_in_scope(
  svg : String,
  base_path : String?,
  scope : BundleScope,
  cache_images : Bool,
) -> SvgBundleResult {
  let cache : Array[(String, String)] = []
  let failed_cache : Array[(String, String)] = []
  let error_hrefs : Array[String] = []
  let out = StringBuilder::new()
  let mut cursor = 0
  while cursor < svg.length() {
    let image_start = match find_substring_from(svg, "<image", cursor) {
      Some(i) => i
      None => {
        out.write_string(slice_string(svg, cursor, svg.length()))
        break
      }
    }
    out.write_string(slice_string(svg, cursor, image_start))
    let image_end = match find_tag_end(svg, image_start + 6) {
      Some(i) => i
      None => {
        out.write_string(slice_string(svg, image_start, svg.length()))
        break
      }
    }
    let tag = slice_string(svg, image_start, image_end + 1)
    let bundled = bundle_image_tag(
      tag, base_path, scope, cache, failed_cache, cache_images,
    )
    out.write_string(bundled.tag)
    match bundled.error_href {
      Some(href) => error_hrefs.push(href)
      None => ()
    }
    cursor = image_end + 1
  }
  { svg: out.to_string(), error: bundle_scope_error(scope, error_hrefs) }
}

///|
fn bundle_image_tag(
  tag : String,
  base_path : String?,
  scope : BundleScope,
  cache : Array[(String, String)],
  failed_cache : Array[(String, String)],
  cache_images : Bool,
) -> ImageTagBundleResult {
  let href_raw = match read_image_href(tag) {
    Some(value) => value
    None => return { tag, error_href: None }
  }
  let href = decode_xml_attr_entities(href_raw).trim().to_string()
  if href == "" || href.has_prefix("data:") {
    return { tag, error_href: None }
  }
  let normalized = normalize_source_reference(href)
  let is_remote = is_http_source(normalized)
  match scope {
    BundleScope::Local => if is_remote { return { tag, error_href: None } }
    BundleScope::Remote => if !is_remote { return { tag, error_href: None } }
  }
  let key = bundle_cache_key(normalized, base_path)
  if lookup_bundle_failure_cache(failed_cache, key) is Some(_) {
    return { tag, error_href: None }
  }
  let data_uri = match lookup_bundle_cache(cache, key) {
    Some(uri) => Some(uri)
    None =>
      match lookup_persistent_bundle_cache(key, cache_images) {
        Some(uri) => {
          cache.push((key, uri))
          Some(uri)
        }
        None =>
          match build_image_data_uri(normalized, base_path) {
            Ok(v) => {
              cache.push((key, v))
              store_persistent_bundle_cache(key, v, cache_images)
              Some(v)
            }
            Err(_) => {
              failed_cache.push((key, normalized))
              None
            }
          }
      }
  }
  match data_uri {
    Some(uri) => { tag: apply_bundled_href(tag, uri), error_href: None }
    None => { tag, error_href: Some(normalized) }
  }
}

///|
fn read_image_href(tag : String) -> String? {
  match read_attr_value(tag, "href") {
    Some(v) => Some(v)
    None => read_attr_value(tag, "xlink:href")
  }
}

///|
fn apply_bundled_href(tag : String, data_uri : String) -> String {
  let mut out = tag
  if read_attr_value(out, "href") is Some(_) {
    out = set_attr_value(out, "href", data_uri)
  }
  if read_attr_value(out, "xlink:href") is Some(_) {
    out = set_attr_value(out, "xlink:href", data_uri)
  }
  out
}

///|
fn set_attr_value(tag : String, name : String, value : String) -> String {
  match find_attr_span(tag, name) {
    Some(span) =>
      slice_string(tag, 0, span.value_start) +
      value +
      slice_string(tag, span.value_end, tag.length())
    None => tag
  }
}

///|
fn read_attr_value(tag : String, name : String) -> String? {
  match find_attr_span(tag, name) {
    Some(span) => Some(slice_string(tag, span.value_start, span.value_end))
    None => None
  }
}

///|
fn find_attr_span(tag : String, name : String) -> AttributeSpan? {
  let mut i = 0
  while i < tag.length() {
    let ch = char_at(tag, i)
    if is_space(ch) || ch == '<' || ch == '>' || ch == '/' {
      i = i + 1
      continue
    }
    if ch == '"' || ch == '\'' {
      i = skip_quoted(tag, i + 1, ch)
      continue
    }
    let name_start = i
    while i < tag.length() && is_attr_name_char(char_at(tag, i)) {
      i = i + 1
    }
    if i == name_start {
      i = i + 1
      continue
    }
    let attr_name = slice_string(tag, name_start, i)
    while i < tag.length() && is_space(char_at(tag, i)) {
      i = i + 1
    }
    if i >= tag.length() || char_at(tag, i) != '=' {
      continue
    }
    i = i + 1
    while i < tag.length() && is_space(char_at(tag, i)) {
      i = i + 1
    }
    if i >= tag.length() {
      break
    }
    let quote = char_at(tag, i)
    if quote != '"' && quote != '\'' {
      while i < tag.length() {
        let c = char_at(tag, i)
        if is_space(c) || c == '>' {
          break
        }
        i = i + 1
      }
      continue
    }
    let value_start = i + 1
    i = value_start
    while i < tag.length() && char_at(tag, i) != quote {
      i = i + 1
    }
    if i >= tag.length() {
      break
    }
    let value_end = i
    i = i + 1
    if attr_name == name {
      return Some({ value_start, value_end })
    }
  }
  None
}

///|
fn skip_quoted(s : String, start : Int, quote : Char) -> Int {
  let mut i = start
  while i < s.length() {
    if char_at(s, i) == quote {
      return i + 1
    }
    i = i + 1
  }
  i
}

///|
fn bundle_cache_key(source : String, base_path : String?) -> String {
  if is_http_source(source) {
    source
  } else {
    resolve_local_image_path(source, base_path)
  }
}

///|
fn lookup_bundle_cache(
  cache : Array[(String, String)],
  key : String,
) -> String? {
  for entry in cache {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn lookup_bundle_failure_cache(
  cache : Array[(String, String)],
  key : String,
) -> String? {
  for entry in cache {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn lookup_persistent_bundle_cache(key : String, cache_images : Bool) -> String? {
  if cache_images {
    persistent_bundle_cache.get(key)
  } else {
    None
  }
}

///|
fn store_persistent_bundle_cache(
  key : String,
  data_uri : String,
  cache_images : Bool,
) -> Unit {
  if cache_images {
    persistent_bundle_cache[key] = data_uri
  }
}

///|
fn build_image_data_uri(
  source : String,
  base_path : String?,
) -> Result[String, String] {
  let normalized = normalize_source_reference(source)
  let (bytes, mime_type) = if is_http_source(normalized) {
    let (remote_bytes, remote_content_type) = match
      fetch_remote_image_bytes(normalized) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    (
      remote_bytes,
      resolve_bundle_mime_type(normalized, remote_bytes, remote_content_type),
    )
  } else {
    let path = resolve_local_image_path(normalized, base_path)
    let bytes = @fs.read_file_to_bytes(path) catch {
      e => return Err("failed to read image file '\{path}': \{e}")
    }
    (bytes, resolve_bundle_mime_type(path, bytes, ""))
  }
  let encoded = @base64.encode(bytes)
  Ok("data:\{mime_type};base64,\{encoded}")
}

///|
fn bundle_scope_error(
  scope : BundleScope,
  error_hrefs : Array[String],
) -> String? {
  if error_hrefs.is_empty() {
    return None
  }
  let scope_name = match scope {
    BundleScope::Local => "local"
    BundleScope::Remote => "remote"
  }
  Some(
    "failed to bundle " +
    scope_name +
    " images: " +
    format_bundle_error_hrefs(error_hrefs),
  )
}

///|
fn format_bundle_error_hrefs(error_hrefs : Array[String]) -> String {
  if error_hrefs.is_empty() {
    return "[]"
  }
  let out = StringBuilder::new()
  out.write_char('[')
  let mut first = true
  for href in error_hrefs {
    if first {
      first = false
    } else {
      out.write_char(' ')
    }
    out.write_string(href)
  }
  out.write_char(']')
  out.to_string()
}

///|
fn resolve_bundle_mime_type(
  source_hint : String,
  bytes : Bytes,
  provided_content_type : String,
) -> String {
  let mime_type = if provided_content_type.trim() != "" {
    provided_content_type.trim().to_string()
  } else {
    detect_mime_type(source_hint, bytes)
  }
  let adjusted = mime_type.replace(old="text/xml", new="image/svg+xml")
  if adjusted == "application/octet-stream" && bytes_contains_svg(bytes) {
    "image/svg+xml"
  } else {
    adjusted
  }
}

///|
fn fetch_remote_image_bytes(url : String) -> Result[(Bytes, String), String] {
  match fetch_remote_image_bytes_override(url) {
    Some(result) => return result
    None => ()
  }
  if !command_exec_is_supported() {
    return Err(
      "remote image bundling requires native command execution support",
    )
  }
  if command_exec("command -v curl >/dev/null 2>&1") != 0 {
    return Err("curl is required for remote image bundling")
  }
  let tmp_path = "/tmp/diago_bundle_" +
    stable_string_hash(url).to_string() +
    ".bin"
  let header_path = "/tmp/diago_bundle_" +
    stable_string_hash(url).to_string() +
    ".headers"
  bundle_remove_file_quiet(tmp_path)
  bundle_remove_file_quiet(header_path)
  let cmd = "curl -L --fail --silent --show-error --max-time 20 " +
    "-H " +
    bundle_shell_quote(
      "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    ) +
    " -H " +
    bundle_shell_quote(
      "Accept: image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    ) +
    " -H " +
    bundle_shell_quote("Accept-Language: en-US,en;q=0.9") +
    " -H " +
    bundle_shell_quote("Accept-Encoding: gzip, deflate, br") +
    " -H " +
    bundle_shell_quote("DNT: 1") +
    " -H " +
    bundle_shell_quote("Upgrade-Insecure-Requests: 1") +
    " -H " +
    bundle_shell_quote("Sec-Fetch-Dest: image") +
    " -H " +
    bundle_shell_quote("Sec-Fetch-Mode: no-cors") +
    " -H " +
    bundle_shell_quote("Sec-Fetch-Site: cross-site") +
    " -D " +
    bundle_shell_quote(header_path) +
    " --output " +
    bundle_shell_quote(tmp_path) +
    " " +
    bundle_shell_quote(url)
  let exit_code = command_exec(cmd)
  if exit_code != 0 {
    bundle_remove_file_quiet(tmp_path)
    bundle_remove_file_quiet(header_path)
    return Err("failed to fetch image '\{url}' (curl exit code \{exit_code})")
  }
  let bytes = @fs.read_file_to_bytes(tmp_path) catch {
    e => {
      bundle_remove_file_quiet(tmp_path)
      bundle_remove_file_quiet(header_path)
      return Err("failed to read fetched image '\{tmp_path}': \{e}")
    }
  }
  if bytes.length() > max_bundle_image_size {
    bundle_remove_file_quiet(tmp_path)
    bundle_remove_file_quiet(header_path)
    return Err(
      "fetched image '\{url}' exceeds max size \{max_bundle_image_size} bytes",
    )
  }
  let header_text = @fs.read_file_to_string(header_path) catch { _ => "" }
  let content_type = parse_last_content_type_header(header_text).unwrap_or("")
  bundle_remove_file_quiet(tmp_path)
  bundle_remove_file_quiet(header_path)
  Ok((bytes, content_type))
}

///|
fn fetch_remote_image_bytes_override(
  url : String,
) -> Result[(Bytes, String), String]? {
  match test_remote_fetch_ok_overrides.get(url) {
    Some((bytes, content_type)) => {
      test_remote_fetch_count[url] = test_remote_fetch_count.get_or_default(
          url, 0,
        ) +
        1
      if bytes.length() > max_bundle_image_size {
        Some(
          Err(
            "fetched image '\{url}' exceeds max size \{max_bundle_image_size} bytes",
          ),
        )
      } else {
        Some(Ok((bytes, content_type)))
      }
    }
    None =>
      match test_remote_fetch_error_overrides.get(url) {
        Some(message) => {
          test_remote_fetch_count[url] = test_remote_fetch_count.get_or_default(
              url, 0,
            ) +
            1
          Some(Err(message))
        }
        None => None
      }
  }
}

///|
fn resolve_local_image_path(source : String, base_path : String?) -> String {
  let normalized = normalize_source_reference(source)
  if @path.Path(normalized).is_absolute() {
    return @path.Path(normalized).normalize().to_string()
  }
  match base_path {
    Some(base) =>
      @path.Path(base).join(@path.Path(normalized)).normalize().to_string()
    None => @path.Path(normalized).normalize().to_string()
  }
}

///|
fn normalize_source_reference(source : String) -> String {
  if source.has_prefix("file://") {
    if source.has_prefix("file:///") {
      return slice_string(source, 7, source.length())
    }
    return slice_string(source, 7, source.length())
  }
  source
}

///|
fn detect_mime_type(source_hint : String, bytes : Bytes) -> String {
  let lower = strip_query_and_fragment(source_hint).to_lower()
  if lower.has_suffix(".svg") || lower.has_suffix(".svgz") {
    "image/svg+xml"
  } else if lower.has_suffix(".png") {
    "image/png"
  } else if lower.has_suffix(".jpg") || lower.has_suffix(".jpeg") {
    "image/jpeg"
  } else if lower.has_suffix(".gif") {
    "image/gif"
  } else if lower.has_suffix(".webp") {
    "image/webp"
  } else if lower.has_suffix(".bmp") {
    "image/bmp"
  } else if lower.has_suffix(".ico") {
    "image/x-icon"
  } else if bytes_contains_svg(bytes) {
    "image/svg+xml"
  } else if bytes_has_prefix(bytes, [0x89, 0x50, 0x4e, 0x47]) {
    "image/png"
  } else if bytes_has_prefix(bytes, [0xff, 0xd8, 0xff]) {
    "image/jpeg"
  } else if bytes_has_prefix_ascii(bytes, "GIF87a") ||
    bytes_has_prefix_ascii(bytes, "GIF89a") {
    "image/gif"
  } else if bytes_has_prefix_ascii(bytes, "RIFF") &&
    bytes_window_equals_ascii(bytes, 8, "WEBP") {
    "image/webp"
  } else if bytes_has_prefix_ascii(bytes, "BM") {
    "image/bmp"
  } else if bytes_has_prefix(bytes, [0x00, 0x00, 0x01, 0x00]) {
    "image/x-icon"
  } else {
    "application/octet-stream"
  }
}

///|
fn parse_last_content_type_header(header_text : String) -> String? {
  if header_text == "" {
    return None
  }
  let lines = header_text.split("\n").collect()
  if lines.length() == 0 {
    return None
  }
  let mut i = lines.length() - 1
  while true {
    let line = lines[i].trim().to_string()
    if line.to_lower().has_prefix("content-type:") {
      return Some(slice_string(line, 13, line.length()).trim().to_string())
    }
    if i == 0 {
      break
    }
    i = i - 1
  }
  None
}

///|
fn bytes_has_prefix(bytes : Bytes, prefix : Array[Int]) -> Bool {
  if bytes.length() < prefix.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if bytes[i].to_int() != prefix[i] {
      return false
    }
  }
  true
}

///|
fn bytes_has_prefix_ascii(bytes : Bytes, text : String) -> Bool {
  if bytes.length() < text.length() {
    return false
  }
  for i in 0..<text.length() {
    if bytes[i].to_int() != text.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
fn bytes_window_equals_ascii(bytes : Bytes, start : Int, text : String) -> Bool {
  if start < 0 || bytes.length() < start + text.length() {
    return false
  }
  for i in 0..<text.length() {
    if bytes[start + i].to_int() != text.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
fn bytes_contains_svg(bytes : Bytes) -> Bool {
  if bytes.length() < 4 {
    return false
  }
  for i in 0..<(bytes.length() - 3) {
    if bytes[i].to_int() == '<'.to_int() &&
      bytes[i + 1].to_int() == 's'.to_int() &&
      bytes[i + 2].to_int() == 'v'.to_int() &&
      bytes[i + 3].to_int() == 'g'.to_int() {
      return true
    }
  }
  false
}

///|
fn strip_query_and_fragment(s : String) -> String {
  for i in 0..<s.length() {
    let c = char_at(s, i)
    if c == '?' || c == '#' {
      return slice_string(s, 0, i)
    }
  }
  s
}

///|
fn is_http_source(source : String) -> Bool {
  let lower = source.to_lower()
  lower.has_prefix("http://") || lower.has_prefix("https://")
}

///|
fn decode_xml_attr_entities(s : String) -> String {
  s
  .replace(old="&amp;", new="&")
  .replace(old="&quot;", new="\"")
  .replace(old="&apos;", new="'")
  .replace(old="&lt;", new="<")
  .replace(old="&gt;", new=">")
}

///|
fn find_tag_end(s : String, start : Int) -> Int? {
  let mut i = start
  let mut in_quote = '\u0000'
  while i < s.length() {
    let c = char_at(s, i)
    if in_quote != '\u0000' {
      if c == in_quote {
        in_quote = '\u0000'
      }
    } else if c == '"' || c == '\'' {
      in_quote = c
    } else if c == '>' {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn find_substring_from(s : String, pattern : String, start : Int) -> Int? {
  if pattern.length() == 0 {
    return Some(start)
  }
  if pattern.length() > s.length() {
    return None
  }
  let limit = s.length() - pattern.length()
  let mut i = if start < 0 { 0 } else { start }
  while i <= limit {
    let mut matched = true
    for j in 0..<pattern.length() {
      if s.code_unit_at(i + j) != pattern.code_unit_at(j) {
        matched = false
        break
      }
    }
    if matched {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn slice_string(s : String, start : Int, end_exclusive : Int) -> String {
  let sb = StringBuilder::new()
  let mut i = start
  while i < end_exclusive {
    sb.write_char(char_at(s, i))
    i = i + 1
  }
  sb.to_string()
}

///|
fn is_attr_name_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_' ||
  c == ':' ||
  c == '.'
}

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn char_at(s : String, i : Int) -> Char {
  s.code_unit_at(i).to_int().unsafe_to_char()
}

///|
fn stable_string_hash(s : String) -> Int {
  let mut hash = 1315423911
  for c in s {
    hash = (hash * 131 + c.to_int()) ^ (hash >> 7)
  }
  if hash < 0 {
    -hash
  } else {
    hash
  }
}

///|
fn bundle_shell_quote(s : String) -> String {
  let sb = StringBuilder::new()
  sb.write_char('\'')
  for c in s {
    if c == '\'' {
      sb.write_string("'\"'\"'")
    } else {
      sb.write_char(c)
    }
  }
  sb.write_char('\'')
  sb.to_string()
}

///|
fn bundle_remove_file_quiet(path : String) -> Unit {
  @fs.remove_file(path) catch {
    _ => ()
  }
}
