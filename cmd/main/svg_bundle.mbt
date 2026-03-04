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
fn bundle_svg_images(
  svg : String,
  base_path : String?,
) -> Result[String, String] {
  let cache : Array[(String, String)] = []
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
    let bundled_tag = match bundle_image_tag(tag, base_path, cache) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    out.write_string(bundled_tag)
    cursor = image_end + 1
  }
  Ok(out.to_string())
}

///|
fn bundle_image_tag(
  tag : String,
  base_path : String?,
  cache : Array[(String, String)],
) -> Result[String, String] {
  let href_raw = match read_image_href(tag) {
    Some(value) => value
    None => return Ok(tag)
  }
  let href = decode_xml_attr_entities(href_raw).trim().to_string()
  if href == "" || href.has_prefix("data:") {
    return Ok(tag)
  }
  let key = bundle_cache_key(href, base_path)
  let data_uri = match lookup_bundle_cache(cache, key) {
    Some(uri) => uri
    None => {
      let built = match build_image_data_uri(href, base_path) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      cache.push((key, built))
      built
    }
  }
  Ok(apply_bundled_href(tag, data_uri))
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
fn build_image_data_uri(
  source : String,
  base_path : String?,
) -> Result[String, String] {
  let normalized = normalize_source_reference(source)
  let (bytes, mime_hint) = if is_http_source(normalized) {
    let fetched = match fetch_remote_image_bytes(normalized) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    (fetched, normalized)
  } else {
    let path = resolve_local_image_path(normalized, base_path)
    let bytes = @fs.read_file_to_bytes(path) catch {
      e => return Err("failed to read image file '\{path}': \{e}")
    }
    (bytes, path)
  }
  let encoded = @base64.encode(bytes)
  let mime_type = detect_mime_type(mime_hint)
  Ok("data:\{mime_type};base64,\{encoded}")
}

///|
fn fetch_remote_image_bytes(url : String) -> Result[Bytes, String] {
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
  bundle_remove_file_quiet(tmp_path)
  let cmd = "curl -L --fail --silent --show-error --max-time 20 --output " +
    bundle_shell_quote(tmp_path) +
    " " +
    bundle_shell_quote(url)
  let exit_code = command_exec(cmd)
  if exit_code != 0 {
    bundle_remove_file_quiet(tmp_path)
    return Err("failed to fetch image '\{url}' (curl exit code \{exit_code})")
  }
  let bytes = @fs.read_file_to_bytes(tmp_path) catch {
    e => {
      bundle_remove_file_quiet(tmp_path)
      return Err("failed to read fetched image '\{tmp_path}': \{e}")
    }
  }
  bundle_remove_file_quiet(tmp_path)
  Ok(bytes)
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
fn detect_mime_type(source_hint : String) -> String {
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
  } else {
    "application/octet-stream"
  }
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
