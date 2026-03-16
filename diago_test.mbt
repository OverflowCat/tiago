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
test "compile default returns svg" {
  let source =
    #|a -> b
  let svg = compile(source)
  assert_true(svg.contains("<svg"))
}

///|
test "auto layout honors vars.d2-config layout-engine" {
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
  let auto_svg = compile(source)
  let dagre_svg = compile(
    source,
    options=CompileOptions::new().with_layout_engine(LayoutEngine::Dagre),
  )
  assert_eq(auto_svg, dagre_svg)
}

///|
test "elk layout can be selected from options and vars.d2-config" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    layout-engine: elk
    #|  }
    #|}
    #|a -> b
  let auto_svg = compile(source)
  let elk_svg = compile(
    source,
    options=CompileOptions::new().with_layout_engine(LayoutEngine::Elk),
  )
  assert_true(auto_svg.contains("<svg"))
  assert_eq(auto_svg, elk_svg)
}

///|
test "parse supports custom import resolver hook" {
  let source = "common: @common"
  let resolver = @ir.ImportResolver::new(fn(path) {
    if path == "common" || path == "common.d2" {
      Some("server\ndatabase")
    } else {
      None
    }
  })
  let ir_map = parse(
    source,
    options=ParseOptions::new().with_import_resolver(Some(resolver)),
  )
  guard ir_map.get_field("common") is Some(common) else {
    fail("no common field")
  }
  guard common.composite is Some(@ir.Composite::Map(common_map)) else {
    fail("common field has no map")
  }
  assert_true(common_map.has_field("server"))
  assert_true(common_map.has_field("database"))
}

///|
fn remove_test_path(path : String) -> Unit {
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
test "parse resolves imports from base_path via facade file resolver" {
  let dir = ".diago_parse_base_path_test"
  let dep_path = dir + "/common.d2"
  remove_test_path(dep_path)
  remove_test_dir(dir)
  @fs.create_dir(dir)
  @fs.write_string_to_file(dep_path, "server\ndatabase")
  let ir_map = parse(
    "common: @common",
    options=ParseOptions::new().with_base_path(Some(dir)),
  )
  remove_test_path(dep_path)
  remove_test_dir(dir)
  guard ir_map.get_field("common") is Some(common) else {
    fail("no common field")
  }
  guard common.composite is Some(@ir.Composite::Map(common_map)) else {
    fail("common field has no map")
  }
  assert_true(common_map.has_field("server"))
  assert_true(common_map.has_field("database"))
}

///|
test "parse_file resolves imports relative to input file" {
  let dir = ".diago_parse_file_test"
  let main_path = dir + "/main.d2"
  let dep_path = dir + "/common.d2"
  remove_test_path(main_path)
  remove_test_path(dep_path)
  remove_test_dir(dir)
  @fs.create_dir(dir)
  @fs.write_string_to_file(main_path, "common: @common")
  @fs.write_string_to_file(dep_path, "server\ndatabase")
  let ir_map = parse_file(main_path)
  remove_test_path(main_path)
  remove_test_path(dep_path)
  remove_test_dir(dir)
  guard ir_map.get_field("common") is Some(common) else {
    fail("no common field")
  }
  guard common.composite is Some(@ir.Composite::Map(common_map)) else {
    fail("common field has no map")
  }
  assert_true(common_map.has_field("server"))
  assert_true(common_map.has_field("database"))
}

///|
test "compile_diagram supports board target selection" {
  let source =
    #|layers: {
    #|  core: {
    #|    a -> b
    #|    scenarios: {
    #|      variant: {
    #|        c -> d
    #|      }
    #|    }
    #|  }
    #|  extra: {
    #|    e -> f
    #|  }
    #|}
  let diagram = compile_diagram(
    source,
    options=CompileOptions::new().with_target_spec(Some("layers.core")),
  )
  assert_true(diagram.find_object("a") is Some(_))
  assert_true(diagram.find_object("e") is None)
  assert_eq(diagram.scenarios.length(), 0)
}

///|
test "compile_diagram target star keeps child boards while empty target trims root children" {
  let source =
    #|layers: {
    #|  core: {
    #|    a -> b
    #|    scenarios: {
    #|      variant: {
    #|        c -> d
    #|      }
    #|    }
    #|  }
    #|}
  let board = compile_diagram(
    source,
    options=CompileOptions::new().with_target_spec(Some("layers.core.*")),
  )
  let root_only = compile_diagram(
    source,
    options=CompileOptions::new().with_target_spec(Some("")),
  )
  assert_eq(board.scenarios.length(), 1)
  assert_eq(root_only.layers.length(), 0)
}

///|
test "compile_diagram target selection is quote-aware" {
  let source =
    #|layers: {
    #|  "cat.go": {
    #|    a -> b
    #|  }
    #|}
  let diagram = compile_diagram(
    source,
    options=CompileOptions::new().with_target_spec(Some("layers.\"cat.go\".*")),
  )
  assert_true(diagram.find_object("a") is Some(_))
  assert_true(diagram.find_object("b") is Some(_))
}

///|
test "compile_diagram reports invalid target syntax" {
  let source =
    #|layers: {
    #|  core: {
    #|    a -> b
    #|  }
    #|}
  let result = try? compile_diagram(
    source,
    options=CompileOptions::new().with_target_spec(Some("layers.\"core")),
  )
  match result {
    Err(TargetError(message)) => assert_true(message.contains("Invalid target"))
    _ => fail("expected invalid target error")
  }
}

///|
test "compile supports custom layout plugin hook" {
  let source =
    #|a -> b
  let layout_plugin = LayoutPlugin::new(fn(_graph, _config, _direction) {
    Err("layout-plugin-failed")
  })
  let result = try? compile(
    source,
    options=CompileOptions::new().with_layout_plugin(Some(layout_plugin)),
  )
  match result {
    Err(LayoutError(msg)) =>
      assert_true(msg.contains("Layout plugin error: layout-plugin-failed"))
    _ => fail("expected LayoutError from custom layout plugin")
  }
}

///|
test "compile supports custom route plugin hook" {
  let source =
    #|a -> b
  let route_plugin = RoutePlugin::new(fn(_graph) { Err("route-plugin-failed") })
  let result = try? compile(
    source,
    options=CompileOptions::new().with_route_plugin(Some(route_plugin)),
  )
  match result {
    Err(LayoutError(msg)) =>
      assert_true(msg.contains("Route plugin error: route-plugin-failed"))
    _ => fail("expected LayoutError from custom route plugin")
  }
}

///|
test "vars d2-config invalid theme-overrides key raises ConfigError" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-overrides: {
    #|      ZZ9: red
    #|    }
    #|  }
    #|}
    #|a -> b
  let result = try? compile(source)
  match result {
    Err(ConfigError(msg)) =>
      assert_true(msg.contains("\"ZZ9\" is not a valid theme code"))
    _ => fail("expected ConfigError for invalid theme override key")
  }
}

///|
test "vars d2-config invalid theme-overrides color raises ConfigError" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-overrides: {
    #|      B1: definitely-not-a-color
    #|    }
    #|  }
    #|}
    #|a -> b
  let result = try? compile(source)
  match result {
    Err(ConfigError(msg)) =>
      assert_true(
        msg.contains(
          "expected \"B1\" to be a valid named color (\"orange\") or a hex code (\"#f0ff3a\")",
        ),
      )
    _ => fail("expected ConfigError for invalid theme override color")
  }
}

///|
test "dark-theme-id alone does not replace base light theme" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    dark-theme-id: 300
    #|  }
    #|}
    #|a -> b
  let svg = compile(source)
  assert_true(not(svg.contains("text-mono")))
}

///|
test "vars d2-config pad is preserved in diagram config" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    pad: 16
    #|  }
    #|}
    #|a -> b
  let diagram = compile_diagram(source)
  match diagram.config {
    Some(config) => assert_eq(config.pad, Some(16.0))
    None => fail("expected diagram config")
  }
}

///|
test "dark-theme-id enables css media theme variables" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    dark-theme-id: 200
    #|  }
    #|}
    #|a -> b
  let svg = compile(source)
  assert_true(svg.contains("@media screen and (prefers-color-scheme:dark)"))
  assert_true(svg.contains("var(--d2-N7)"))
}

///|
test "without dark-theme-id svg keeps static theme colors" {
  let source =
    #|a -> b
  let svg = compile(source)
  assert_true(
    not(svg.contains("@media screen and (prefers-color-scheme: dark)")),
  )
}
