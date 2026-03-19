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
/// ELK E2E tests against committed snapshots.
///
/// This suite validates all bundled examples:
/// 1) Diago ELK output is snapshot-stable
/// 2) Diago outputs are strictly aligned to committed ELK references

///|
test "examples: elk svg e2e snapshots and reference semantic parity" {
  let elk_example_names = e2e_example_names().unwrap()
  for name in elk_example_names {
    let source = read_required_file("examples/" + name + ".d2").unwrap()
    let actual_svg = compile_elk_svg(source).unwrap()
    assert_true(
      actual_svg.contains("<svg"),
      msg="diago elk svg missing <svg> for \{name}",
    )
    assert_true(
      actual_svg.contains("</svg>"),
      msg="diago elk svg missing </svg> for \{name}",
    )

    let snapshot_svg = read_required_file(
      "examples/diago-elk-svg-output/" + name + ".svg",
    ).unwrap()
    assert_eq(
      normalize_svg_snapshot(actual_svg),
      normalize_svg_snapshot(snapshot_svg),
    )

    let reference_svg = read_required_file(
      "examples/reference-elk-svg-output/" + name + ".svg",
    ).unwrap()
    let label_mismatches = reference_label_coverage_mismatches(
      actual_svg, reference_svg,
    )
    let mismatch_text = label_mismatches.join(", ")
    assert_true(
      label_mismatches.is_empty(),
      msg="\{name}: missing reference labels in diago elk svg: \{mismatch_text}",
    )

    let diago_semantic_snapshot = svg_semantic_snapshot(actual_svg)
    let reference_semantic = svg_semantic_snapshot(reference_svg)
    let semantic_diff = semantic_snapshot_mismatch_summary(
      diago_semantic_snapshot, reference_semantic,
    )
    assert_eq(
      diago_semantic_snapshot,
      reference_semantic,
      msg="\{name}: semantic snapshot diverges from reference elk output (\{semantic_diff})",
    )

    let diago_visual_snapshot = svg_visual_style_snapshot(actual_svg)
    let reference_visual = svg_visual_style_snapshot(reference_svg)
    let visual_diff = semantic_snapshot_mismatch_summary(
      diago_visual_snapshot, reference_visual,
    )
    assert_eq(
      diago_visual_snapshot,
      reference_visual,
      msg="\{name}: visual style snapshot diverges from reference elk output (\{visual_diff})",
    )

    assert_true(
      reference_svg.contains("<svg"),
      msg="\{name}: reference elk svg missing <svg>",
    )
  }
}

///|
test "examples: elk ascii e2e snapshots" {
  let elk_example_names = e2e_example_names().unwrap()
  for name in elk_example_names {
    let source = read_required_file("examples/" + name + ".d2").unwrap()
    let actual_ascii = compile_elk_ascii(source).unwrap()

    let snapshot_ascii = read_required_file(
      "examples/diago-elk-ascii-output/" + name + ".txt",
    ).unwrap()
    assert_eq(
      normalize_text_snapshot(actual_ascii),
      normalize_text_snapshot(snapshot_ascii),
      msg="\{name}: diago elk ascii snapshot mismatch",
    )

    let d2_ascii = read_required_file(
      "examples/reference-elk-ascii-output/" + name + ".txt",
    ).unwrap()
    assert_eq(
      normalize_text_snapshot(actual_ascii),
      normalize_text_snapshot(d2_ascii),
      msg="\{name}: elk ascii diverges from reference output",
    )
  }
}

///|
test "examples: elk unicode e2e snapshots" {
  let elk_example_names = e2e_example_names().unwrap()
  for name in elk_example_names {
    let source = read_required_file("examples/" + name + ".d2").unwrap()
    let actual_unicode = compile_elk_unicode(source).unwrap()

    let snapshot_unicode = read_required_file(
      "examples/diago-elk-unicode-output/" + name + ".txt",
    ).unwrap()
    assert_eq(
      normalize_text_snapshot(actual_unicode),
      normalize_text_snapshot(snapshot_unicode),
      msg="\{name}: diago elk unicode snapshot mismatch",
    )

    let d2_unicode = read_required_file(
      "examples/reference-elk-unicode-output/" + name + ".txt",
    ).unwrap()
    assert_eq(
      normalize_text_snapshot(actual_unicode),
      normalize_text_snapshot(d2_unicode),
      msg="\{name}: elk unicode diverges from reference output",
    )
  }
}

///|
fn compile_elk_svg(source : String) -> Result[String, String] {
  match compile_elk_diagram(source, @engine_api.Direction::Down) {
    Ok(diagram) => {
      let render_config = @renderer_svg.SvgConfig::new()
      try @renderer_svg.render(diagram, render_config) catch {
        e => Err(e.to_string())
      } noraise {
        v => Ok(v)
      }
    }
    Err(e) => Err(e)
  }
}

///|
fn compile_elk_ascii(source : String) -> Result[String, String] {
  match compile_elk_diagram(source, @engine_api.Direction::Down) {
    Ok(diagram) =>
      Ok(@renderer_ascii.render(diagram, @renderer_ascii.AsciiConfig::new()))
    Err(e) => Err(e)
  }
}

///|
fn compile_elk_unicode(source : String) -> Result[String, String] {
  match compile_elk_diagram(source, @engine_api.Direction::Down) {
    Ok(diagram) => Ok(@renderer_unicode.render(diagram))
    Err(e) => Err(e)
  }
}

///|
fn compile_elk_diagram(
  source : String,
  direction : @engine_api.Direction,
) -> Result[@diagram.Diagram, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph_input = @exporter.compile("test", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @engine_api.LayoutConfig::new()
  let laid_out_graph = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    direction,
  ) catch {
    e => return Err("Layout error: \{e}")
  }
  Ok(@diagram.from_graph(laid_out_graph, None))
}

///|
fn normalize_text_snapshot(text : String) -> String {
  text
  .replace(old="\r\n", new="\n")
  .replace(old="\r", new="\n")
  .trim()
  .to_string()
}
