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
fn compile_graph_no_layout(source : String) -> Result[@graph.GraphInput, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph_input = @exporter.compile("test", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  Ok(graph_input)
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
  let layer_names : Array[String] = []
  for layer in graph.layers {
    layer_names.push(layer.name)
  }
  let scenario_names : Array[String] = []
  for scenario in graph.scenarios {
    scenario_names.push(scenario.name)
  }
  let step_names : Array[String] = []
  for step in graph.steps {
    step_names.push(step.name)
  }
  assert_eq(layer_names, ["L1"])
  assert_eq(scenario_names, ["S1"])
  assert_eq(step_names, ["step1"])
  assert_true(
    graph.layers[0].graph.find_object("b") is Some(_),
  )
  assert_true(
    graph.scenarios[0].graph.find_object("c") is Some(_),
  )
  assert_true(
    graph.steps[0].graph.find_object("d") is Some(_),
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
    ids1.push(o.id)
  }
  let ids2 : Array[String] = []
  for o in g2.get_objects() {
    ids2.push(o.id)
  }
  assert_eq(ids1, ids2)
  let e1 = g1.get_edges()[0]
  let e2 = g2.get_edges()[0]
  assert_eq(e1.index, e2.index)
  assert_eq(e1.src_id, e2.src_id)
  assert_eq(e1.dst_id, e2.dst_id)
}
