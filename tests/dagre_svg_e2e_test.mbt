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
