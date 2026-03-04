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
/// Dagre SVG E2E tests against committed snapshots.
///
/// This suite validates all bundled examples:
/// 1) Diago Dagre output is snapshot-stable (`examples/diago-dagre-output`)
/// 2) Diago SVG semantic snapshots (labels + coordinates + edge curve params)
///    are aligned to D2 Dagre reference SVGs (`examples/d2-dagre-output`)

///|
test "examples: dagre svg e2e snapshots and d2 semantic parity" {
  let dagre_example_names = e2e_example_names().unwrap()
  for name in dagre_example_names {
    let source = read_required_file("examples/" + name + ".d2").unwrap()
    let actual_svg = compile(source).unwrap()
    assert_true(
      actual_svg.contains("<svg"),
      msg="diago svg missing <svg> for \{name}",
    )
    assert_true(
      actual_svg.contains("</svg>"),
      msg="diago svg missing </svg> for \{name}",
    )

    let snapshot_svg = read_required_file(
      "examples/diago-dagre-output/" + name + ".svg",
    ).unwrap()
    assert_eq(
      normalize_svg_snapshot(actual_svg),
      normalize_svg_snapshot(snapshot_svg),
    )

    let d2_svg = read_required_file("examples/d2-dagre-output/" + name + ".svg").unwrap()
    let label_mismatches = d2_label_coverage_mismatches(actual_svg, d2_svg)
    let mismatch_text = label_mismatches.join(", ")
    assert_true(
      label_mismatches.is_empty(),
      msg="\{name}: missing d2 labels in diago svg: \{mismatch_text}",
    )

    let diago_semantic_snapshot = d2_semantic_snapshot(actual_svg)
    let d2_semantic = d2_semantic_snapshot(d2_svg)
    let semantic_diff = semantic_snapshot_mismatch_summary(
      diago_semantic_snapshot, d2_semantic,
    )
    assert_eq(
      diago_semantic_snapshot,
      d2_semantic,
      msg="\{name}: semantic snapshot diverges from d2 dagre output (\{semantic_diff})",
    )

    let diago_visual_snapshot = d2_visual_style_snapshot(actual_svg)
    let d2_visual = d2_visual_style_snapshot(d2_svg)
    let visual_diff = semantic_snapshot_mismatch_summary(
      diago_visual_snapshot, d2_visual,
    )
    assert_eq(
      diago_visual_snapshot,
      d2_visual,
      msg="\{name}: visual style snapshot diverges from d2 dagre output (\{visual_diff})",
    )
  }
}

///|
fn e2e_example_names() -> Result[Array[String], String] {
  let entries = @fs.read_dir("examples") catch {
    e => return Err("failed to read examples directory: \{e}")
  }
  let names : Array[String] = []
  for entry in entries {
    if entry.has_suffix(".d2") {
      names.push(slice_string(entry, 0, entry.length() - 3))
    }
  }
  if names.is_empty() {
    return Err("no .d2 example files found in examples/")
  }
  Ok(sort_strings(names))
}

///|
fn d2_semantic_snapshot(svg : String) -> String {
  let labels = extract_text_positions(svg)
  let edges = extract_edge_endpoints_and_cubic(svg)
  let (min_x, min_y, max_x, max_y) = semantic_bounds(labels, edges)
  let width = if max_x > min_x { max_x - min_x } else { 1.0 }
  let height = if max_y > min_y { max_y - min_y } else { 1.0 }
  let scale = if width > height { width } else { height }
  let tokens : Array[String] = []

  for label, points in labels {
    for point in points {
      let nx = normalize_coord(point.0, min_x, scale)
      let ny = normalize_coord(point.1, min_y, scale)
      tokens.push("T|\{label}|x=\{quantize(nx)}|y=\{quantize(ny)}")
    }
  }

  for edge in edges {
    let kind = if edge.1 { "C" } else { "L" }
    let (sx, sy, ex, ey) = edge.0
    let nsx = normalize_coord(sx, min_x, scale)
    let nsy = normalize_coord(sy, min_y, scale)
    let nex = normalize_coord(ex, min_x, scale)
    let ney = normalize_coord(ey, min_y, scale)
    let params : Array[String] = []
    let mut i = 0
    for value in edge.2 {
      let normalized = if i % 2 == 0 {
        normalize_coord(value, min_x, scale)
      } else {
        normalize_coord(value, min_y, scale)
      }
      params.push(quantize(normalized))
      i = i + 1
    }
    let params_signature = params.join(",")
    tokens.push(
      "E|\{kind}|s=\{quantize(nsx)},\{quantize(nsy)}|e=\{quantize(nex)},\{quantize(ney)}|p=\{params_signature}",
    )
  }

  sort_strings(tokens).join("\n")
}

///|
fn d2_visual_style_snapshot(svg : String) -> String {
  let tokens : Array[String] = []
  collect_text_style_tokens(svg, tokens)
  collect_shape_style_tokens(svg, "path", tokens)
  collect_shape_style_tokens(svg, "rect", tokens)
  collect_shape_style_tokens(svg, "circle", tokens)
  collect_shape_style_tokens(svg, "ellipse", tokens)
  collect_shape_style_tokens(svg, "line", tokens)
  collect_shape_style_tokens(svg, "polygon", tokens)
  collect_shape_style_tokens(svg, "polyline", tokens)
  sort_strings(tokens).join("\n")
}

///|
fn collect_text_style_tokens(svg : String, out : Array[String]) -> Unit {
  let parts = svg.split("<text").collect()
  if parts.length() < 2 {
    return
  }
  for i in 1..<parts.length() {
    let part = parts[i].to_string()
    let gt_parts = part.split(">").collect()
    if gt_parts.length() < 2 {
      continue
    }
    let attrs = gt_parts[0].to_string()
    let tail = gt_parts[1].to_string()
    let text_parts = tail.split("</text>").collect()
    if text_parts.length() == 0 {
      continue
    }
    let label = normalize_inline_text(strip_xml_tags(text_parts[0].to_string()))
    if label.length() == 0 {
      continue
    }
    let style_sig = visual_style_signature(attrs)
    out.push("TEXT|\{label}|\{style_sig}")
  }
}

///|
fn collect_shape_style_tokens(
  svg : String,
  tag : String,
  out : Array[String],
) -> Unit {
  let parts = svg.split("<" + tag).collect()
  if parts.length() < 2 {
    return
  }
  for i in 1..<parts.length() {
    let part = parts[i].to_string()
    let close_index = match find_substring(part, ">") {
      Some(v) => v
      None => continue
    }
    let attrs = slice_string(part, 0, close_index).trim().to_string()
    if attrs.length() == 0 {
      continue
    }
    let style_sig = visual_style_signature(attrs)
    out.push("SHAPE|\{tag}|\{style_sig}")
  }
}

///|
fn visual_style_signature(attrs : String) -> String {
  let style_map : Map[String, String] = {}
  match parse_attr_string(attrs, "style") {
    Some(style_raw) => merge_inline_style(style_map, style_raw)
    None => ()
  }
  let keys = visual_style_keys()
  for key in keys {
    match parse_attr_string(attrs, key) {
      Some(v) =>
        match normalize_visual_style_value(key, v) {
          Some(normalized) => style_map[key] = normalized
          None => ()
        }
      None => ()
    }
  }
  let pairs : Array[String] = []
  for key in keys {
    match style_map.get(key) {
      Some(v) => pairs.push("\{key}=\{v}")
      None => ()
    }
  }
  if pairs.is_empty() {
    "-"
  } else {
    pairs.join("|")
  }
}

///|
fn merge_inline_style(
  style_map : Map[String, String],
  raw_style : String,
) -> Unit {
  let declarations = raw_style.split(";").collect()
  for declaration in declarations {
    let item = declaration.to_string().trim().to_string()
    if item.is_empty() {
      continue
    }
    let colon = match find_substring(item, ":") {
      Some(v) => v
      None => continue
    }
    let key = slice_string(item, 0, colon).trim().to_string().to_lower()
    let value = slice_string(item, colon + 1, item.length()).trim().to_string()
    if value.is_empty() || !is_visual_style_key(key) {
      continue
    }
    match normalize_visual_style_value(key, value) {
      Some(normalized) => style_map[key] = normalized
      None => ()
    }
  }
}

///|
fn visual_style_keys() -> Array[String] {
  [
    "fill", "stroke", "stroke-width", "opacity", "fill-opacity", "stroke-opacity",
    "stroke-dasharray", "stroke-linecap", "stroke-linejoin", "font-size", "text-anchor",
  ]
}

///|
fn normalize_visual_style_value(key : String, raw : String) -> String? {
  let value = normalize_inline_text(raw)
  if value.is_empty() {
    return None
  }
  if key == "stroke" && value.to_lower() == "none" {
    return None
  }
  if key == "font-size" {
    if value.has_suffix("px") {
      return Some(value)
    }
    return Some(value + "px")
  }
  Some(value)
}

///|
fn is_visual_style_key(key : String) -> Bool {
  for k in visual_style_keys() {
    if k == key {
      return true
    }
  }
  false
}

///|
fn normalize_coord(v : Double, min_v : Double, scale : Double) -> Double {
  (v - min_v) / scale
}

///|
fn semantic_bounds(
  labels : Map[String, Array[(Double, Double)]],
  edges : Array[((Double, Double, Double, Double), Bool, Array[Double])],
) -> (Double, Double, Double, Double) {
  let mut min_x = 1000000000000.0
  let mut min_y = 1000000000000.0
  let mut max_x = -1000000000000.0
  let mut max_y = -1000000000000.0
  let mut seen = false

  for _, points in labels {
    for p in points {
      seen = true
      if p.0 < min_x {
        min_x = p.0
      }
      if p.1 < min_y {
        min_y = p.1
      }
      if p.0 > max_x {
        max_x = p.0
      }
      if p.1 > max_y {
        max_y = p.1
      }
    }
  }

  for edge in edges {
    let (sx, sy, ex, ey) = edge.0
    seen = true
    if sx < min_x {
      min_x = sx
    }
    if sy < min_y {
      min_y = sy
    }
    if sx > max_x {
      max_x = sx
    }
    if sy > max_y {
      max_y = sy
    }
    if ex < min_x {
      min_x = ex
    }
    if ey < min_y {
      min_y = ey
    }
    if ex > max_x {
      max_x = ex
    }
    if ey > max_y {
      max_y = ey
    }
  }

  if !seen {
    (0.0, 0.0, 1.0, 1.0)
  } else {
    (min_x, min_y, max_x, max_y)
  }
}

///|
fn quantize(v : Double) -> String {
  // Keep parity strict while tolerating tiny float noise.
  // Step = 0.01 in normalized coordinates.
  let scaled = v * 100.0
  let rounded = if scaled >= 0.0 {
    (scaled + 0.5).to_int()
  } else {
    (scaled - 0.5).to_int()
  }
  rounded.to_string()
}

///|
fn sort_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    out.push(value)
  }
  let mut i = 0
  while i < out.length() {
    let mut j = i + 1
    while j < out.length() {
      if out[j] < out[i] {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
      j = j + 1
    }
    i = i + 1
  }
  out
}

///|
fn semantic_snapshot_mismatch_summary(a : String, b : String) -> String {
  if a == b {
    return "equal"
  }
  let a_counts = snapshot_line_counts(a)
  let b_counts = snapshot_line_counts(b)
  let issues : Array[String] = []
  for line, expected in b_counts {
    let actual = match a_counts.get(line) {
      Some(v) => v
      None => 0
    }
    if actual < expected {
      issues.push("missing:\{line} x\{expected - actual}")
      if issues.length() >= 6 {
        break
      }
    }
  }
  if issues.length() < 6 {
    for line, actual in a_counts {
      let expected = match b_counts.get(line) {
        Some(v) => v
        None => 0
      }
      if actual > expected {
        issues.push("extra:\{line} x\{actual - expected}")
        if issues.length() >= 6 {
          break
        }
      }
    }
  }
  if issues.is_empty() {
    "line-count differs"
  } else {
    issues.join(" ; ")
  }
}

///|
fn snapshot_line_counts(snapshot : String) -> Map[String, Int] {
  let counts : Map[String, Int] = {}
  for line in snapshot.split("\n").collect() {
    let key = line.to_string()
    if key.length() == 0 {
      continue
    }
    let current = match counts.get(key) {
      Some(v) => v
      None => 0
    }
    counts[key] = current + 1
  }
  counts
}

///|
fn read_required_file(path : String) -> Result[String, String] {
  try @fs.read_file_to_string(path) catch {
    e => Err("failed to read '\{path}': \{e}")
  } noraise {
    content => Ok(content)
  }
}

///|
fn normalize_svg_snapshot(svg : String) -> String {
  normalize_image_href_payloads(
    svg.replace(old="\r\n", new="\n").replace(old="\r", new="\n"),
  )
  .trim()
  .to_string()
}

///|
fn normalize_image_href_payloads(svg : String) -> String {
  let parts = svg.split("<image").collect()
  if parts.length() < 2 {
    return svg
  }
  let out = StringBuilder::new()
  out.write_string(parts[0].to_string())
  for i in 1..<parts.length() {
    let part = parts[i].to_string()
    let close_index = match find_substring(part, "/>") {
      Some(v) => v
      None =>
        match find_substring(part, ">") {
          Some(v) => v
          None => {
            out.write_string("<image")
            out.write_string(part)
            continue
          }
        }
    }
    let attrs = slice_string(part, 0, close_index)
    let suffix = slice_string(part, close_index, part.length())
    out.write_string("<image")
    out.write_string(normalize_single_image_attrs(attrs))
    out.write_string(suffix)
  }
  out.to_string()
}

///|
fn normalize_single_image_attrs(attrs : String) -> String {
  let mut normalized = attrs
  match parse_attr_string(attrs, "href") {
    Some(v) =>
      if should_normalize_image_href(v) {
        normalized = replace_attr_string_value(normalized, "href", "__IMAGE__")
      }
    None => ()
  }
  match parse_attr_string(attrs, "xlink:href") {
    Some(v) =>
      if should_normalize_image_href(v) {
        normalized = replace_attr_string_value(
          normalized, "xlink:href", "__IMAGE__",
        )
      }
    None => ()
  }
  normalized
}

///|
fn should_normalize_image_href(href : String) -> Bool {
  let lower = href.to_lower()
  lower.has_prefix("data:") ||
  lower.has_prefix("http://") ||
  lower.has_prefix("https://")
}

///|
fn replace_attr_string_value(
  attrs : String,
  name : String,
  new_value : String,
) -> String {
  let pattern = name + "=\""
  let start = match find_substring(attrs, pattern) {
    Some(i) => i
    None => return attrs
  }
  let value_start = start + pattern.length()
  let rest = slice_string(attrs, value_start, attrs.length())
  let end_rel = match find_substring(rest, "\"") {
    Some(i) => i
    None => return attrs
  }
  let value_end = value_start + end_rel
  slice_string(attrs, 0, value_start) +
  new_value +
  slice_string(attrs, value_end, attrs.length())
}

///|
fn d2_label_coverage_mismatches(
  diago_svg : String,
  d2_svg : String,
) -> Array[String] {
  let diago_counts = extract_text_counts(diago_svg)
  let d2_counts = extract_text_counts(d2_svg)
  let mismatches : Array[String] = []

  let mut d2_total = 0
  for _, count in d2_counts {
    d2_total = d2_total + count
  }
  if d2_total == 0 {
    return mismatches
  }

  for label, expected_count in d2_counts {
    let actual_count = match diago_counts.get(label) {
      Some(v) => v
      None => 0
    }
    if actual_count < expected_count {
      mismatches.push("\{label} (diago=\{actual_count}, d2=\{expected_count})")
    }
  }
  mismatches
}

///|
#warnings("-unused_value")
fn d2_parity_metrics(
  diago_svg : String,
  d2_svg : String,
) -> (Double, Double, Double, Int, Double) {
  let diago_labels = extract_text_positions(diago_svg)
  let d2_labels = extract_text_positions(d2_svg)
  let label_distances : Array[Double] = []

  for label, d2_points in d2_labels {
    let diago_points = match diago_labels.get(label) {
      Some(v) => v
      None => []
    }
    for target in d2_points {
      if diago_points.is_empty() {
        label_distances.push(999.0)
      } else {
        let mut best = 1000000000000.0
        for actual in diago_points {
          let dist = euclidean_distance(actual, target)
          if dist < best {
            best = dist
          }
        }
        label_distances.push(best)
      }
    }
  }

  let label_p95 = percentile95(label_distances)
  let label_max = array_max_double(label_distances)

  let diago_edges = extract_edge_endpoints_and_cubic(diago_svg)
  let d2_edges = extract_edge_endpoints_and_cubic(d2_svg)
  let mut edge_endpoint_max = 0.0
  let cubic_param_distances : Array[Double] = []
  for d2_edge in d2_edges {
    let target = d2_edge.0
    let mut best = 1000000000000.0
    let mut best_index = -1
    let mut j = 0
    for diago_edge in diago_edges {
      let dist = endpoint_l1_distance(diago_edge.0, target)
      if dist < best {
        best = dist
        best_index = j
      }
      j = j + 1
    }
    if best > edge_endpoint_max {
      edge_endpoint_max = best
    }
    if d2_edge.1 {
      if best_index >= 0 {
        let matched = diago_edges[best_index]
        if matched.1 {
          cubic_param_distances.push(
            cubic_param_l1_distance(matched.2, d2_edge.2),
          )
        } else {
          cubic_param_distances.push(999.0)
        }
      } else {
        cubic_param_distances.push(999.0)
      }
    }
  }
  let cubic_gap = (count_cubic(diago_edges) - count_cubic(d2_edges)).abs()
  let cubic_param_p95 = percentile95(cubic_param_distances)
  (label_p95, label_max, edge_endpoint_max, cubic_gap, cubic_param_p95)
}

///|
fn extract_text_positions(svg : String) -> Map[String, Array[(Double, Double)]] {
  let positions : Map[String, Array[(Double, Double)]] = {}
  let parts = svg.split("<text").collect()
  if parts.length() < 2 {
    return positions
  }
  for i in 1..<parts.length() {
    let part = parts[i].to_string()
    let gt_parts = part.split(">").collect()
    if gt_parts.length() < 2 {
      continue
    }
    let attrs = gt_parts[0].to_string()
    let tail = gt_parts[1].to_string()
    let text_parts = tail.split("</text>").collect()
    if text_parts.length() == 0 {
      continue
    }
    let label = normalize_inline_text(strip_xml_tags(text_parts[0].to_string()))
    if label.length() == 0 {
      continue
    }
    let x = match parse_attr_double(attrs, "x") {
      Some(v) => v
      None => continue
    }
    let y = match parse_attr_double(attrs, "y") {
      Some(v) => v
      None => continue
    }
    let arr = match positions.get(label) {
      Some(v) => v
      None => []
    }
    arr.push((x, y))
    positions[label] = arr
  }
  positions
}

///|
fn extract_edge_endpoints_and_cubic(
  svg : String,
) -> Array[((Double, Double, Double, Double), Bool, Array[Double])] {
  let result : Array[((Double, Double, Double, Double), Bool, Array[Double])] = []
  let parts = svg.split("<path").collect()
  if parts.length() < 2 {
    return result
  }
  for i in 1..<parts.length() {
    let part = parts[i].to_string()
    let close_index = match find_substring(part, "/>") {
      Some(v) => v
      None => continue
    }
    let attrs = slice_string(part, 0, close_index)
    let has_marker = attrs.contains("marker-end=") ||
      attrs.contains("marker-start=")
    if !has_marker {
      continue
    }
    let d_value = match parse_attr_string(attrs, "d") {
      Some(v) => v
      None => continue
    }
    let nums = parse_numbers(d_value)
    if nums.length() < 4 {
      continue
    }
    let endpoints = (
      nums[0],
      nums[1],
      nums[nums.length() - 2],
      nums[nums.length() - 1],
    )
    let is_cubic = d_value.contains("C") || d_value.contains("c")
    result.push((endpoints, is_cubic, nums))
  }
  result
}

///|
fn count_cubic(
  edges : Array[((Double, Double, Double, Double), Bool, Array[Double])],
) -> Int {
  let mut count = 0
  for edge in edges {
    if edge.1 {
      count = count + 1
    }
  }
  count
}

///|
fn parse_attr_string(attrs : String, name : String) -> String? {
  let pattern = name + "=\""
  let start = match find_substring(attrs, pattern) {
    Some(i) => i + pattern.length()
    None => return None
  }
  let rest = slice_string(attrs, start, attrs.length())
  let end_rel = match find_substring(rest, "\"") {
    Some(i) => i
    None => return None
  }
  Some(slice_string(rest, 0, end_rel))
}

///|
fn parse_attr_double(attrs : String, name : String) -> Double? {
  match parse_attr_string(attrs, name) {
    Some(raw) => parse_double_safe(raw)
    None => None
  }
}

///|
fn parse_numbers(s : String) -> Array[Double] {
  let nums : Array[Double] = []
  let mut sb = StringBuilder::new()
  for c in s {
    if is_number_char(c) {
      sb.write_char(c)
    } else if sb.to_string().length() > 0 {
      match parse_double_safe(sb.to_string()) {
        Some(v) => nums.push(v)
        None => ()
      }
      sb = StringBuilder::new()
    }
  }
  if sb.to_string().length() > 0 {
    match parse_double_safe(sb.to_string()) {
      Some(v) => nums.push(v)
      None => ()
    }
  }
  nums
}

///|
fn is_number_char(c : Char) -> Bool {
  (c >= '0' && c <= '9') ||
  c == '.' ||
  c == '-' ||
  c == '+' ||
  c == 'e' ||
  c == 'E'
}

///|
fn percentile95(values : Array[Double]) -> Double {
  if values.is_empty() {
    return 0.0
  }
  let xs = values.copy()
  xs.sort_by((a, b) => a.compare(b))
  let index = (xs.length() - 1) * 95 / 100
  xs[index]
}

///|
fn array_max_double(values : Array[Double]) -> Double {
  if values.is_empty() {
    return 0.0
  }
  let mut best = values[0]
  for v in values {
    if v > best {
      best = v
    }
  }
  best
}

///|
fn euclidean_distance(a : (Double, Double), b : (Double, Double)) -> Double {
  let dx = a.0 - b.0
  let dy = a.1 - b.1
  (dx * dx + dy * dy).sqrt()
}

///|
fn endpoint_l1_distance(
  a : (Double, Double, Double, Double),
  b : (Double, Double, Double, Double),
) -> Double {
  (a.0 - b.0).abs() + (a.1 - b.1).abs() + (a.2 - b.2).abs() + (a.3 - b.3).abs()
}

///|
fn cubic_param_l1_distance(a : Array[Double], b : Array[Double]) -> Double {
  if a.is_empty() || b.is_empty() {
    return 999.0
  }
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0
  for i in 0..<n {
    sum = sum + (a[i] - b[i]).abs()
  }
  let gap = (a.length() - b.length()).abs().to_double()
  sum + gap * 25.0
}

///|
fn find_substring(s : String, pattern : String) -> Int? {
  if pattern.length() == 0 {
    return Some(0)
  }
  if pattern.length() > s.length() {
    return None
  }
  let limit = s.length() - pattern.length()
  for i = 0; i <= limit; i = i + 1 {
    if slice_string(s, i, i + pattern.length()) == pattern {
      return Some(i)
    }
  }
  None
}

///|
fn parse_double_safe(s : String) -> Double? {
  try @strconv.parse_double(s) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn slice_string(s : String, start : Int, end_exclusive : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<end_exclusive {
    match s[i].to_char() {
      Some(c) => sb.write_char(c)
      None => ()
    }
  }
  sb.to_string()
}

///|
fn extract_text_counts(svg : String) -> Map[String, Int] {
  let counts : Map[String, Int] = {}
  let parts = svg.split("<text").collect()
  if parts.length() < 2 {
    return counts
  }
  for i in 1..<parts.length() {
    let part = parts[i]
    let gt_parts = part.split(">").collect()
    if gt_parts.length() < 2 {
      continue
    }
    let tail = gt_parts[1]
    let text_parts = tail.split("</text>").collect()
    if text_parts.length() == 0 {
      continue
    }
    let label = normalize_inline_text(strip_xml_tags(text_parts[0].to_string()))
    if label.length() == 0 {
      continue
    }
    let current = match counts.get(label) {
      Some(v) => v
      None => 0
    }
    counts[label] = current + 1
  }
  counts
}

///|
fn strip_xml_tags(s : String) -> String {
  let sb = StringBuilder::new()
  let mut in_tag = false
  for c in s {
    if c == '<' {
      in_tag = true
    } else if c == '>' {
      in_tag = false
    } else if !in_tag {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn normalize_inline_text(s : String) -> String {
  let sb = StringBuilder::new()
  let mut prev_space = false
  for c in s {
    if is_svg_whitespace(c) {
      if !prev_space {
        sb.write_char(' ')
        prev_space = true
      }
    } else {
      sb.write_char(c)
      prev_space = false
    }
  }
  sb.to_string().trim().to_string()
}

///|
fn is_svg_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\t' || c == '\r'
}
