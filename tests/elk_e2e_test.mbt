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
/// 2) SVG label coverage is aligned to D2 ELK SVG references

///|
let elk_example_names : Array[String] = [
  "architecture", "arrowheads", "basic", "c4", "classes", "containers", "directions",
  "grid", "hello", "layers", "legend_auto", "legend_custom", "sequence", "shapes",
  "sql_tables", "styles", "variables",
]

///|
test "examples: elk svg e2e snapshots and d2 semantic parity" {
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

    let d2_svg = read_required_file(
      "examples/d2-elk-svg-output/" + name + ".svg",
    ).unwrap()
    let label_mismatches = d2_label_coverage_mismatches(actual_svg, d2_svg)
    let mismatch_text = label_mismatches.join(", ")
    assert_true(
      label_mismatches.is_empty(),
      msg="\{name}: missing d2 labels in diago elk svg: \{mismatch_text}",
    )

    assert_true(
      d2_svg.contains("<svg"),
      msg="\{name}: d2 elk svg reference missing <svg>",
    )
  }
}

///|
test "examples: elk ascii e2e snapshots" {
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
      "examples/d2-elk-ascii-output/" + name + ".txt",
    ).unwrap()
    assert_true(not(normalize_text_snapshot(d2_ascii).is_empty()))
  }
}

///|
test "examples: elk unicode e2e snapshots" {
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
      "examples/d2-elk-unicode-output/" + name + ".txt",
    ).unwrap()
    assert_true(not(normalize_text_snapshot(d2_unicode).is_empty()))
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
