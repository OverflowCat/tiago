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
/// Exporter regression tests for variants + stable IDs

///|
fn compile_graph_no_layout(source : String) -> Result[@graph.Graph, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph = @exporter.compile("test", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  Ok(graph)
}

///|
test "exporter compiles layers/scenarios/steps" {
  let source =
    #|a
    #|layers: {
    #|  L1: { b }
    #|}
    #|scenarios: {
    #|  S1: { c }
    #|}
    #|steps: {
    #|  step1: { d }
    #|}
  let graph = compile_graph_no_layout(source).unwrap()
  assert_false(graph.find_object("layers") is Some(_))
  assert_false(graph.find_object("scenarios") is Some(_))
  assert_false(graph.find_object("steps") is Some(_))
  assert_eq(graph.layer_names(), ["L1"])
  assert_eq(graph.scenario_names(), ["S1"])
  assert_eq(graph.step_names(), ["step1"])
  assert_true(graph.get_layer("L1").unwrap().find_object("b") is Some(_))
  assert_true(graph.get_scenario("S1").unwrap().find_object("c") is Some(_))
  assert_true(
    graph.get_step_by_name("step1").unwrap().find_object("d") is Some(_),
  )
}

///|
test "exporter object IDs are deterministic" {
  let source =
    #|a
    #|b
    #|a -> b
  let g1 = compile_graph_no_layout(source).unwrap()
  let g2 = compile_graph_no_layout(source).unwrap()
  let ids1 : Array[String] = []
  for o in g1.get_objects() {
    ids1.push(o.get_id())
  }
  let ids2 : Array[String] = []
  for o in g2.get_objects() {
    ids2.push(o.get_id())
  }
  assert_eq(ids1, ids2)
  let e1 = g1.get_edges()[0]
  let e2 = g2.get_edges()[0]
  assert_eq(e1.index, e2.index)
  assert_eq(e1.get_src_id(), e2.get_src_id())
  assert_eq(e1.get_dst_id(), e2.get_dst_id())
}
