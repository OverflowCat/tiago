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
fn parse_err(args : Array[String], env : Map[String, String]) -> String {
  match parse_cli_request(args, env) {
    Ok(_) => {
      panic()
      ""
    }
    Err(err) => err
  }
}

///|
fn parse_render(
  args : Array[String],
  env : Map[String, String],
) -> RenderRequest {
  match parse_cli_request(args, env) {
    Ok(req) =>
      match req.render {
        Some(render_req) => render_req
        None => {
          panic()
          {
            input_path: None,
            output_path: None,
            from_stdin: false,
            output_mode: OutputMode::Svg,
            ascii_mode: AsciiMode::Extended,
            layout_engine: LayoutEngineChoice::Dagre,
            layout_explicit: false,
            target_spec: None,
            theme_name: None,
            dark_theme_id: None,
            sketch: None,
            pad: None,
            center: None,
            theme_overrides: None,
            dark_theme_overrides: None,
            scale: None,
            bundle: true,
            no_xml_tag: None,
            salt: None,
            omit_version: None,
            watch: false,
            watch_interval_ms: 500,
            preview_enabled: true,
            preview_host: "127.0.0.1",
            preview_port: 17396,
            preview_open_browser: true,
          }
        }
      }
    Err(err) => {
      println(err)
      panic()
      {
        input_path: None,
        output_path: None,
        from_stdin: false,
        output_mode: OutputMode::Svg,
        ascii_mode: AsciiMode::Extended,
        layout_engine: LayoutEngineChoice::Dagre,
        layout_explicit: false,
        target_spec: None,
        theme_name: None,
        dark_theme_id: None,
        sketch: None,
        pad: None,
        center: None,
        theme_overrides: None,
        dark_theme_overrides: None,
        scale: None,
        bundle: true,
        no_xml_tag: None,
        salt: None,
        omit_version: None,
        watch: false,
        watch_interval_ms: 500,
        preview_enabled: true,
        preview_host: "127.0.0.1",
        preview_port: 17396,
        preview_open_browser: true,
      }
    }
  }
}

///|
fn cleanup_file(path : String) -> Unit {
  @fs.remove_file(path) catch {
    _ => ()
  }
}

///|
test "render default output path is input.svg" {
  let req = parse_render(["diago", "render", "demo.d2"], {})
  assert_eq(req.input_path, Some("demo.d2"))
  assert_eq(req.output_path, Some("demo.svg"))
  assert_eq(req.output_mode, OutputMode::Svg)
}

///|
test "render stdin only with --stdin" {
  let req = parse_render(["diago", "render", "--stdin"], {})
  assert_true(req.from_stdin)
  assert_eq(req.input_path, None)
  assert_eq(req.output_path, None)
}

///|
test "render rejects positional input with --stdin" {
  let err = parse_err(["diago", "render", "--stdin", "demo.d2"], {})
  assert_true(err.contains("cannot be used with --stdin"))
}

///|
test "render rejects dash input shorthand" {
  let err = parse_err(["diago", "render", "-"], {})
  assert_true(err.contains("Use --stdin instead"))
}

///|
test "validate rejects dash input shorthand" {
  let err = parse_err(["diago", "validate", "-"], {})
  assert_true(err.contains("Use --stdin instead"))
}

///|
test "render rejects duplicate output path sources" {
  let err = parse_err(
    ["diago", "render", "demo.d2", "a.svg", "--output", "b.svg"],
    {},
  )
  assert_true(err.contains("positionally and with --output"))
}

///|
test "render format/output extension mismatch fails" {
  let err = parse_err(
    ["diago", "render", "demo.d2", "--format", "ascii", "--output", "out.svg"],
    {},
  )
  assert_true(err.contains("extension conflicts with --format"))
}

///|
test "render watch cannot be combined with stdin" {
  let err = parse_err(["diago", "render", "--stdin", "--watch"], {})
  assert_true(err.contains("--watch cannot be used with --stdin"))
}

///|
test "precedence: cli overrides env for layout" {
  let req = parse_render(["diago", "render", "demo.d2", "--layout", "dagre"], {
    "DIAGO_LAYOUT": "elk",
  })
  assert_eq(req.layout_engine, LayoutEngineChoice::Dagre)
  assert_true(req.layout_explicit)
}

///|
test "precedence: env overrides defaults for layout" {
  let req = parse_render(["diago", "render", "demo.d2"], {
    "DIAGO_LAYOUT": "elk",
  })
  assert_eq(req.layout_engine, LayoutEngineChoice::Elk)
  assert_true(req.layout_explicit)
}

///|
test "render parses compatibility pad and center svg options" {
  let req = parse_render(
    ["diago", "render", "demo.d2", "--pad", "24", "--center"],
    {},
  )
  assert_eq(req.pad, Some(24.0))
  assert_eq(req.center, Some(true))
}

///|
test "render parses compatibility sketch flag" {
  let req = parse_render(["diago", "render", "demo.d2", "--sketch"], {})
  assert_eq(req.sketch, Some(true))
}

///|
test "render parses typed theme override flags" {
  let req = parse_render(
    [
      "diago", "render", "demo.d2", "--theme-overrides", "B1:red,N1=white", "--dark-theme-overrides",
      "AA4:#f0ff3a",
    ],
    {},
  )
  assert_eq(req.theme_overrides.unwrap().get("B1"), Some("red"))
  assert_eq(req.theme_overrides.unwrap().get("N1"), Some("white"))
  assert_eq(req.dark_theme_overrides.unwrap().get("AA4"), Some("#f0ff3a"))
}

///|
test "only DIAGO_ env prefix is recognized" {
  let req = parse_render(["diago", "render", "demo.d2"], { "D2_LAYOUT": "elk" })
  assert_eq(req.layout_engine, LayoutEngineChoice::Dagre)
  assert_false(req.layout_explicit)
}

///|
test "legacy watch command returns migration hint" {
  let err = parse_err(["diago", "watch", "demo.d2"], {})
  assert_true(err.contains("render --watch"))
}

///|
test "legacy dump-input command returns migration hint" {
  let err = parse_err(["diago", "dump-input"], {})
  assert_true(err.contains("no longer a public CLI command"))
}

///|
test "legacy ascii flags return migration hint" {
  let err = parse_err(["diago", "render", "--ascii", "demo.d2"], {})
  assert_true(err.contains("render --format ascii|unicode"))
}

///|
test "legacy global version flag returns migration hint" {
  let err = parse_err(["diago", "--version"], {})
  assert_true(err.contains("Use: diago version"))
}

///|
test "legacy direct entry returns migration hint" {
  let err = parse_err(["diago", "demo.d2"], {})
  assert_true(err.contains("Use: diago render"))
}

///|
test "precedence: env layout overrides invalid vars config layout-engine" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    layout-engine: not-a-layout
    #|  }
    #|}
    #|a -> b
  let auto_result = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    None,
  )
  assert_true(auto_result is Err(_))

  let req = parse_render(["diago", "render", "demo.d2"], {
    "DIAGO_LAYOUT": "dagre",
  })
  let env_result = compile_source(
    source,
    source_compile_mode(req.output_mode),
    req.theme_name,
    None,
    req.layout_engine,
    req.layout_explicit,
    req.target_spec,
    ascii_mode=req.ascii_mode,
    dark_theme_id=req.dark_theme_id,
    sketch=req.sketch,
    theme_overrides=req.theme_overrides,
    dark_theme_overrides=req.dark_theme_overrides,
    scale=req.scale,
    bundle=req.bundle,
    no_xml_tag=req.no_xml_tag,
    salt=req.salt,
    omit_version=req.omit_version,
  )
  assert_true(env_result is Ok(_))
}

///|
test "compile_source reports invalid target syntax" {
  let source =
    #|layers: {
    #|  core: {
    #|    a -> b
    #|  }
    #|}
  let result = compile_source(
    source,
    OutputMode::Svg,
    None,
    None,
    LayoutEngineChoice::Dagre,
    false,
    Some("layers.\"core"),
  )
  match result {
    Err(message) => assert_true(message.contains("Invalid target"))
    Ok(_) => fail("expected invalid target error")
  }
}

///|
test "fmt default writes formatted output in place" {
  let path = ".diago_cli_v2_fmt_in_place.d2"
  cleanup_file(path)
  @fs.write_string_to_file(path, "a  ->  b\n")
  let result = execute_fmt({ check: false, files: [path] })
  assert_true(result is Ok(_))
  let formatted = @fs.read_file_to_string(path) catch {
    e => {
      cleanup_file(path)
      fail("failed to read formatted file: \{e}")
      ""
    }
  }
  cleanup_file(path)
  assert_true(formatted.contains("a -> b"))
}

///|
test "fmt check reports unformatted files without writing" {
  let path = ".diago_cli_v2_fmt_check.d2"
  cleanup_file(path)
  @fs.write_string_to_file(path, "a  ->  b\n")
  let result = execute_fmt({ check: true, files: [path] })
  let after = @fs.read_file_to_string(path) catch {
    e => {
      cleanup_file(path)
      fail("failed to read check file: \{e}")
      ""
    }
  }
  cleanup_file(path)
  match result {
    Ok(_) => fail("expected check mode to report unformatted file")
    Err(msg) => assert_true(msg.contains("unformatted"))
  }
  assert_eq(after, "a  ->  b\n")
}

///|
test "validate reports parse failures" {
  let path = ".diago_cli_v2_validate_invalid.d2"
  cleanup_file(path)
  @fs.write_string_to_file(path, "a ->")
  let result = execute_validate({ input_path: Some(path), from_stdin: false })
  cleanup_file(path)
  match result {
    Ok(_) => fail("expected validate to fail for invalid source")
    Err(msg) => assert_true(msg.contains("Parse errors"))
  }
}
