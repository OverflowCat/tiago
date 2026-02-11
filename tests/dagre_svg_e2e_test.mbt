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
/// 2) Text labels from D2 Dagre reference SVGs are covered by Diago output
///    (`examples/d2-dagre-output`)

///|
let dagre_example_names : Array[String] = [
  "architecture", "arrowheads", "basic", "c4", "classes", "containers", "directions",
  "grid", "hello", "layers", "legend_auto", "legend_custom", "sequence", "shapes",
  "sql_tables", "styles", "variables",
]

///|
/// Budgets are pinned from current best-effort parity against D2 Dagre output.
/// Tuple layout:
/// (label_p95_distance, label_max_distance, edge_endpoint_max_l1, cubic_count_gap, cubic_param_p95)
let d2_parity_budgets : Map[String, (Double, Double, Double, Int, Double)] = {
  "architecture": (132.765, 176.495, 326.174, 0, 1838.214),
  "arrowheads": (40.000, 40.323, 82.500, 0, 144.500),
  "basic": (51.500, 60.459, 19.950, 0, 490.333),
  "c4": (119.128, 127.803, 202.961, 0, 865.374),
  "classes": (197.500, 203.882, 117.500, 0, 487.050),
  "containers": (248.500, 268.500, 431.500, 0, 1224.030),
  "directions": (1802.950, 1830.944, 3649.500, 0, 6636.500),
  "grid": (1458.484, 1501.241, 0.500, 0, 0.500),
  "hello": (2.001, 2.501, 10.500, 0, 14.500),
  "layers": (143.500, 168.500, 37.111, 0, 449.709),
  "legend_auto": (89.250, 99.750, 98.637, 0, 675.000),
  "legend_custom": (25.625, 43.664, 12.000, 0, 66.000),
  "sequence": (340.557, 345.341, 771.506, 6, 0.500),
  "shapes": (199.463, 204.339, 434.500, 0, 760.700),
  "sql_tables": (347.565, 554.587, 552.311, 0, 1064.042),
  "styles": (224.184, 227.295, 164.500, 0, 522.645),
  "variables": (194.500, 224.500, 44.753, 0, 459.979),
}

///|
test "examples: dagre svg e2e snapshots and d2 label parity" {
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

    let (label_p95, label_max, edge_endpoint_max, cubic_gap, cubic_param_p95) = d2_parity_metrics(
      actual_svg, d2_svg,
    )
    let budget = d2_parity_budgets.get(name).unwrap()
    assert_true(
      label_p95 <= budget.0,
      msg="\{name}: label p95 distance too large (\{label_p95} > \{budget.0})",
    )
    assert_true(
      label_max <= budget.1,
      msg="\{name}: label max distance too large (\{label_max} > \{budget.1})",
    )
    assert_true(
      edge_endpoint_max <= budget.2,
      msg="\{name}: edge endpoint max distance too large (\{edge_endpoint_max} > \{budget.2})",
    )
    assert_true(
      cubic_gap <= budget.3,
      msg="\{name}: cubic count gap too large (\{cubic_gap} > \{budget.3})",
    )
    assert_true(
      cubic_param_p95 <= budget.4,
      msg="\{name}: cubic param p95 too large (\{cubic_param_p95} > \{budget.4})",
    )
  }
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
  svg
  .replace(old="\r\n", new="\n")
  .replace(old="\r", new="\n")
  .trim()
  .to_string()
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
    mismatches.push("<d2 has no text labels>")
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
