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
test "vars d2-config theme-id applies when cli theme absent" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-id: 300
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  assert_true(svg.contains("text-mono"))
}

///|
test "cli theme overrides vars d2-config theme-id" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-id: 300
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(
    source,
    OutputMode::Svg,
    Some("Neutral Default"),
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  assert_true(not(svg.contains("text-mono")))
}

///|
test "vars d2-config layout-engine applies when cli layout is not explicit" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    layout-engine: dagre
    #|  }
    #|}
    #|a -> b
    #|a -> c
    #|b -> d
    #|c -> d
  let auto_svg = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  let dagre_svg = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    true,
    None,
  ).unwrap()
  assert_eq(auto_svg, dagre_svg)
}

///|
test "cli layout overrides invalid vars d2-config layout-engine" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    layout-engine: not-a-layout
    #|  }
    #|}
    #|a -> b
  let cli_result = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    true,
    None,
  )
  assert_true(cli_result is Ok(_))

  let auto_result = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  )
  match auto_result {
    Ok(_) => fail("expected invalid vars.d2-config layout-engine to fail")
    Err(msg) => assert_true(msg.contains("vars.d2-config.layout-engine"))
  }
}

///|
test "extract vars d2-config into diagram config" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    sketch: true
    #|    theme-id: 4
    #|    dark-theme-id: 200
    #|    theme-overrides: {
    #|      B1: red
    #|    }
    #|    dark-theme-overrides: {
    #|      N1: white
    #|    }
    #|    pad: 16
    #|    center: true
    #|    layout-engine: dagre
    #|    scale: 1.5
    #|    no-xml-tag: true
    #|    salt: custom-salt
    #|    omit-version: true
    #|    data: {
    #|      owner: platform
    #|    }
    #|  }
    #|}
    #|a -> b
  let diagram = compile_to_diagram(
    source,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  match diagram.config {
    None => fail("expected diagram config")
    Some(config) => {
      assert_eq(config.sketch, Some(true))
      assert_eq(config.theme_id, Some(4))
      assert_eq(config.dark_theme_id, Some(200))
      assert_eq(config.theme_overrides["B1"], "red")
      assert_eq(config.dark_theme_overrides["N1"], "white")
      assert_eq(config.pad, Some(16.0))
      assert_eq(config.center, Some(true))
      assert_eq(config.layout_engine, Some("dagre"))
      assert_eq(config.scale, Some(1.5))
      assert_eq(config.no_xml_tag, Some(true))
      assert_eq(config.salt, Some("custom-salt"))
      assert_eq(config.omit_version, Some(true))
      assert_eq(config.data["owner"], "platform")
    }
  }
}

///|
test "vars d2-config no-xml-tag omits XML declaration" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    no-xml-tag: true
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  assert_true(not(svg.contains("<?xml")))
}

///|
test "theme-overrides applies to theme tokens in style" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-overrides: {
    #|      B1: red
    #|    }
    #|  }
    #|}
    #|a: {
    #|  style: {
    #|    fill: B1
    #|  }
    #|}
  let svg = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  assert_true(svg.contains("fill=\"red\""))
}

///|
test "invalid theme-overrides key fails config parsing" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-overrides: {
    #|      ZZ9: red
    #|    }
    #|  }
    #|}
    #|a -> b
  match
    compile_source(
      source,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected invalid theme-overrides key to fail")
    Err(msg) => assert_true(msg.contains("\"ZZ9\" is not a valid theme code"))
  }
}

///|
test "invalid theme-overrides color fails config parsing" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-overrides: {
    #|      B1: definitely-not-a-color
    #|    }
    #|  }
    #|}
    #|a -> b
  match
    compile_source(
      source,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected invalid theme-overrides color to fail")
    Err(msg) =>
      assert_true(
        msg.contains(
          "expected \"B1\" to be a valid named color (\"orange\") or a hex code (\"#f0ff3a\")",
        ),
      )
  }
}

///|
test "dark-theme-id does not replace base light theme when theme-id is absent" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    dark-theme-id: 300
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  assert_true(not(svg.contains("text-mono")))
}

///|
test "vars d2-config pad is applied to svg config padding" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    pad: 16
    #|  }
    #|}
    #|a -> b
  let diagram = compile_to_diagram(
    source,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  let svg_config = resolve_svg_config(None, diagram.config)
  assert_eq(svg_config.padding, 16.0)
}

///|
test "vars d2-config dark-theme-id emits dark media css" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    dark-theme-id: 200
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  assert_true(svg.contains("@media screen and (prefers-color-scheme:dark)"))
  assert_true(svg.contains("var(--d2-N7)"))
}

///|
test "salt namespaces SVG marker IDs" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    salt: custom-salt
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  assert_true(svg.contains("id=\"mk-d2-"))
  assert_true(svg.contains("url(#mk-d2-"))
}

///|
test "omit-version removes data-d2-version attribute" {
  let source_default =
    #|a -> b
  let default_svg = compile_source(
    source_default,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  assert_true(default_svg.contains("data-d2-version=\""))

  let source_omit =
    #|vars: {
    #|  d2-config: {
    #|    omit-version: true
    #|  }
    #|}
    #|a -> b
  let omit_svg = compile_source(
    source_omit,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  assert_true(not(omit_svg.contains("data-d2-version=\"")))
}

///|
test "invalid style keyword fails semantic validation" {
  let source =
    #|a: {
    #|  style: {
    #|    unknown-key: 1
    #|  }
    #|}
  match
    compile_source(
      source,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected invalid style keyword to fail")
    Err(msg) => assert_true(msg.contains("invalid style keyword"))
  }
}

///|
test "url tooltip with link fails semantic validation" {
  let source =
    #|a: {
    #|  link: https://example.com
    #|  tooltip: https://phishing.example
    #|}
  match
    compile_source(
      source,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected link + URL tooltip check to fail")
    Err(msg) => assert_true(msg.contains("Tooltip cannot be set to URL"))
  }
}

///|
test "near ancestor and edge map non-reserved are rejected" {
  let near_source =
    #|a: {
    #|  b: {
    #|    near: a
    #|  }
    #|}
  match
    compile_source(
      near_source,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected near ancestor check to fail")
    Err(msg) =>
      assert_true(msg.contains("near keys cannot be set to an ancestor"))
  }

  let edge_source =
    #|a -> b: hello {
    #|  note: not-allowed
    #|}
  match
    compile_source(
      edge_source,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected edge map reserved-key check to fail")
    Err(msg) =>
      assert_true(msg.contains("edge map keys must be reserved keywords"))
  }
}

///|
test "top/left fixed positioning applies to laid out object" {
  let source =
    #|a: {
    #|  top: 120
    #|  left: 240
    #|}
    #|b
    #|a -> b
  let diagram = compile_to_diagram(
    source,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  match diagram.find_object("a") {
    Some(shape) =>
      match shape.get_box() {
        Some(box) => {
          assert_eq(box.y, 120.0)
          assert_eq(box.x, 240.0)
        }
        None => fail("expected box for object a")
      }
    None => fail("expected object a")
  }
}

///|
test "top/left must be non-negative integers" {
  let non_integer_top =
    #|a: {
    #|  top: abc
    #|}
  match
    compile_source(
      non_integer_top,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected non-integer top to fail")
    Err(msg) => assert_true(msg.contains("non-integer top"))
  }

  let negative_left =
    #|a: {
    #|  left: -2
    #|}
  match
    compile_source(
      negative_left,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected negative left to fail")
    Err(msg) => assert_true(msg.contains("left must be a non-negative integer"))
  }
}

///|
test "top/left compatibility checks for hierarchy sequence and grid" {
  let hierarchy_source =
    #|x: {
    #|  shape: hierarchy
    #|  a: {
    #|    top: 20
    #|  }
    #|}
  match
    compile_source(
      hierarchy_source,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected hierarchy compatibility check to fail")
    Err(msg) =>
      assert_true(msg.contains("position keywords cannot be used with shape"))
  }

  let sequence_source =
    #|shape: sequence_diagram
    #|a: {
    #|  left: 20
    #|}
  match
    compile_source(
      sequence_source,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected sequence compatibility check to fail")
    Err(msg) =>
      assert_true(msg.contains("position keywords cannot be used inside shape"))
  }

  let grid_source =
    #|g: {
    #|  grid-rows: 1
    #|  a: {
    #|    left: 20
    #|  }
    #|}
  match
    compile_source(
      grid_source,
      OutputMode::Svg,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected grid compatibility check to fail")
    Err(msg) =>
      assert_true(msg.contains("position keywords cannot be used with grids"))
  }
}

///|
test "stdout-format parser supports d2-compatible format names" {
  guard parse_stdout_format("svg") is Some(OutputMode::Svg) else {
    fail("svg should parse")
  }
  guard parse_stdout_format("png") is Some(OutputMode::Png) else {
    fail("png should parse")
  }
  guard parse_stdout_format("txt") is Some(OutputMode::Txt) else {
    fail("txt should parse")
  }
  guard parse_stdout_format("unicode") is Some(OutputMode::Unicode) else {
    fail("unicode should parse")
  }
  guard parse_stdout_format("bad-format") is None else {
    fail("unknown format should fail")
  }
}

///|
test "output mode can be inferred from output extension" {
  guard infer_output_mode_from_path("diagram.svg") is Some(OutputMode::Svg) else {
    fail("svg extension should map to svg mode")
  }
  guard infer_output_mode_from_path("diagram.txt") is Some(OutputMode::Txt) else {
    fail("txt extension should map to txt mode")
  }
  guard infer_output_mode_from_path("diagram.pptx") is Some(OutputMode::Pptx) else {
    fail("pptx extension should map to pptx mode")
  }
  guard infer_output_mode_from_path("diagram") is None else {
    fail("unknown extension should not infer mode")
  }
}

///|
test "binary output modes compile through svg intermediate" {
  guard source_compile_mode(OutputMode::Png) is OutputMode::Svg else {
    fail("png should compile through svg intermediate")
  }
  guard source_compile_mode(OutputMode::Pdf) is OutputMode::Svg else {
    fail("pdf should compile through svg intermediate")
  }
  guard source_compile_mode(OutputMode::Pptx) is OutputMode::Svg else {
    fail("pptx should compile through svg intermediate")
  }
  guard source_compile_mode(OutputMode::Gif) is OutputMode::Svg else {
    fail("gif should compile through svg intermediate")
  }
}

///|
test "ascii-mode parser supports standard and extended" {
  guard parse_ascii_mode("standard") is Some(AsciiMode::Standard) else {
    fail("standard should parse")
  }
  guard parse_ascii_mode("extended") is Some(AsciiMode::Extended) else {
    fail("extended should parse")
  }
  guard parse_ascii_mode("bad-mode") is None else {
    fail("unknown ascii mode should fail")
  }
}

///|
test "layout parser supports dagre elk railway" {
  guard parse_layout_engine("dagre") is Some(LayoutEngineChoice::Dagre) else {
    fail("dagre should parse")
  }
  guard parse_layout_engine("elk") is Some(LayoutEngineChoice::Elk) else {
    fail("elk should parse")
  }
  guard parse_layout_engine("railway") is Some(LayoutEngineChoice::Railway) else {
    fail("railway should parse")
  }
  guard parse_layout_engine("bad-layout") is None else {
    fail("unknown layout should fail")
  }
  assert_eq(layout_engine_name(LayoutEngineChoice::Elk), "elk")
}

///|
test "txt output mode honors ascii-mode" {
  let source =
    #|a -> b
  let txt_default = compile_source(
    source,
    OutputMode::Txt,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  ).unwrap()
  let txt_standard = compile_source(
    source,
    OutputMode::Txt,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
    ascii_mode=AsciiMode::Standard,
  ).unwrap()
  assert_true(txt_default.contains("┌"))
  assert_true(txt_standard.contains("+"))
  assert_true(txt_default != txt_standard)
}

///|
test "unsupported binary output formats return explicit errors" {
  let source =
    #|a -> b
  match
    compile_source(
      source,
      OutputMode::Png,
      None,
      None,
      LayoutEngineChoice::Dagre,
      false,
      None,
    ) {
    Ok(_) => fail("expected png mode to be unsupported")
    Err(msg) => assert_true(msg.contains("not supported yet"))
  }
}

///|
test "binary stdout output is rejected in native pipeline" {
  match write_compiled_output(OutputMode::Png, None, "<svg/>") {
    Ok(_) => fail("expected png stdout to be rejected")
    Err(msg) =>
      assert_true(msg.contains("requires native command execution support"))
  }
  match write_compiled_output(OutputMode::Pptx, None, "<svg/>") {
    Ok(_) => fail("expected pptx stdout to be rejected")
    Err(msg) =>
      assert_true(msg.contains("requires native command execution support"))
  }
  match write_compiled_output(OutputMode::Gif, None, "<svg/>") {
    Ok(_) => fail("expected gif stdout to be rejected")
    Err(msg) =>
      assert_true(msg.contains("requires native command execution support"))
  }
}

///|
test "binary file output requires native command execution support" {
  match write_compiled_output(OutputMode::Png, Some("out.png"), "<svg/>") {
    Ok(_) => fail("expected png file export to require command execution")
    Err(msg) =>
      assert_true(msg.contains("requires native command execution support"))
  }
  match write_compiled_output(OutputMode::Pptx, Some("out.pptx"), "<svg/>") {
    Ok(_) => fail("expected pptx file export to require command execution")
    Err(msg) =>
      assert_true(msg.contains("requires native command execution support"))
  }
  match write_compiled_output(OutputMode::Gif, Some("out.gif"), "<svg/>") {
    Ok(_) => fail("expected gif file export to require command execution")
    Err(msg) =>
      assert_true(msg.contains("requires native command execution support"))
  }
}

///|
test "watch preview html embeds asset and control files" {
  let html = build_watch_preview_html(
    "diagram.svg", "diagram.svg.watch.version", "diagram.svg.watch.error.txt",
  )
  assert_true(html.contains("diagram.svg"))
  assert_true(html.contains("diagram.svg.watch.version"))
  assert_true(html.contains("diagram.svg.watch.error.txt"))
  assert_true(html.contains("setTimeout(poll, 500)"))
}

///|
test "watch preview path helpers resolve directory and basename" {
  assert_eq(dirname_or_dot("diagram.svg"), ".")
  assert_eq(basename_string("foo/bar/diagram.svg"), "diagram.svg")
}
