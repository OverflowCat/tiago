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
test "parse supports custom import resolver hook" {
  let source = "@common"
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
test "compile_diagram supports board target selection" {
  let source =
    #|layers: {
    #|  core: {
    #|    a -> b
    #|  }
    #|  extra: {
    #|    c -> d
    #|  }
    #|}
  let diagram = compile_diagram(
    source,
    options=CompileOptions::new().with_target_spec(Some("layers.core")),
  )
  assert_true(diagram.find_object("a") is Some(_))
  assert_true(diagram.find_object("c") is None)
}

///|
test "compile_file resolves imports from source directory by default" {
  let dir = "output/diago_api_tmp"
  @fs.create_dir(dir) catch {
    _ => ()
  }
  @fs.write_string_to_file(dir + "/common.d2", "x") catch {
    e => fail("write common failed: \{e}")
  }
  @fs.write_string_to_file(dir + "/main.d2", "...@common") catch {
    e => fail("write main failed: \{e}")
  }
  let svg = compile_file(dir + "/main.d2")
  assert_true(svg.contains(">x<"))
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
