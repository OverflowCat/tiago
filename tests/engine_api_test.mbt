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
/// Engine API regression tests

///|
struct FakeEngine {
  _marker : Unit
} derive(Show)

///|
fn FakeEngine::new() -> FakeEngine {
  { _marker: () }
}

///|
impl @engine_api.LayoutEngine for FakeEngine with layout(
  _self,
  graph,
  _config,
  _direction,
) -> @engine_api.LayoutResult raise @engine_api.LayoutError {
  let result = @engine_api.LayoutResult::new()
  let mut i = 0
  for obj in graph.objects {
    let x = (i * 10).to_double()
    let y = (i * 7).to_double()
    result.nodes[obj.id] = @engine_api.NodeLayout::from_box(
      @graph.Box::new(x, y, 10.0, 6.0),
    )
    i = i + 1
  }
  result
}

///|
test "layout_with_engine applies to variants" {
  let graph = @graph.Graph::new("base")
  graph.add_object(@graph.Object::new("a"))
  let layer_graph = @graph.Graph::new("layer")
  layer_graph.add_object(@graph.Object::new("b"))
  graph.add_layer(@graph.Layer::new("L1", layer_graph))
  let scenario_graph = @graph.Graph::new("scenario")
  scenario_graph.add_object(@graph.Object::new("c"))
  graph.add_scenario(@graph.Scenario::new("S1", scenario_graph))
  let step_graph = @graph.Graph::new("step")
  step_graph.add_object(@graph.Object::new("d"))
  graph.add_step(@graph.Step::new("step1", step_graph))
  let engine = FakeEngine::new()
  let config = @engine_api.LayoutConfig::new()
  let input = @graph.GraphInput::from_graph(graph)
  let outputs = @engine_api.layout_with_engine(
    engine,
    input,
    config,
    @engine_api.Direction::Down,
  )
  assert_true(outputs.layout.nodes.get("a") is Some(_))
  assert_true(outputs.layers[0].1.layout.nodes.get("b") is Some(_))
  assert_true(outputs.scenarios[0].1.layout.nodes.get("c") is Some(_))
  assert_true(outputs.steps[0].1.layout.nodes.get("d") is Some(_))
}

///|
test "layout result roundtrips via graph" {
  let graph = @graph.Graph::new("roundtrip")
  let a = @graph.Object::new("a")
  let b = @graph.Object::new("b")
  a.set_box(@graph.Box::new(1.0, 2.0, 3.0, 4.0))
  b.set_box(@graph.Box::new(10.0, 20.0, 30.0, 40.0))
  graph.add_object(a)
  graph.add_object(b)
  let edge = @graph.Edge::new(7, "a", "b", false, true)
  edge.add_route_point(@graph.Point::new(1.0, 1.0))
  edge.add_route_point(@graph.Point::new(2.0, 2.0))
  edge.set_label_box(@graph.Box::new(5.0, 6.0, 7.0, 8.0))
  graph.add_edge(edge)
  graph.activation_boxes.push(("a", @graph.Box::new(9.0, 9.0, 1.0, 2.0)))
  graph.sequence_notes.push(("a", "note", @graph.Box::new(3.0, 4.0, 5.0, 6.0)))
  let layout = @engine_api.LayoutResult::from_graph(graph)
  let input = @graph.GraphInput::from_graph(graph)
  let materialized = layout.materialize(input)
  match materialized.find_object("a").unwrap().get_box() {
    Some(box) => assert_eq(box, @graph.Box::new(1.0, 2.0, 3.0, 4.0))
    None => fail("a should have a box")
  }
  match materialized.find_object("b").unwrap().get_box() {
    Some(box) => assert_eq(box, @graph.Box::new(10.0, 20.0, 30.0, 40.0))
    None => fail("b should have a box")
  }
  let e = materialized.get_edges()[0]
  assert_eq(e.index, 7)
  assert_eq(e.get_route().length(), 2)
  match e.get_label_box() {
    Some(box) => assert_eq(box, @graph.Box::new(5.0, 6.0, 7.0, 8.0))
    None => fail("edge should have label box")
  }
  assert_eq(materialized.activation_boxes.length(), 1)
  assert_eq(materialized.sequence_notes.length(), 1)
}

///|
test "engine implementations must not mutate input graph" {
  let graph = @graph.Graph::new("pure")
  graph.add_object(@graph.Object::new("a"))
  graph.add_object(@graph.Object::new("b"))
  graph.add_edge(@graph.Edge::new(0, "a", "b", false, true))

  // Snapshot relevant layout state before calling engine.layout(...)
  let boxes_before : Array[@graph.Box?] = []
  for obj in graph.get_objects() {
    boxes_before.push(obj.get_box())
  }
  let routes_before : Array[Int] = []
  let labels_before : Array[@graph.Box?] = []
  let src_ports_before : Array[@graph.Port?] = []
  let dst_ports_before : Array[@graph.Port?] = []
  for e in graph.get_edges() {
    routes_before.push(e.get_route().length())
    labels_before.push(e.get_label_box())
    src_ports_before.push(e.src_port)
    dst_ports_before.push(e.dst_port)
  }
  let activation_before = graph.activation_boxes.length()
  let notes_before = graph.sequence_notes.length()
  let engine = @engine_elk.ElkEngine::new()
  let config = @engine_api.LayoutConfig::new()
  let input = @graph.GraphInput::from_graph(graph)
  ignore(engine.layout(input, config, @engine_api.Direction::Down)) catch {
    e => fail("engine.layout should not fail: \{e}")
  }

  // Input graph must remain unchanged after engine.layout(...)
  let mut i = 0
  for obj in graph.get_objects() {
    assert_eq(obj.get_box(), boxes_before[i])
    i = i + 1
  }
  let mut j = 0
  for e in graph.get_edges() {
    assert_eq(e.get_route().length(), routes_before[j])
    assert_eq(e.get_label_box(), labels_before[j])
    assert_eq(e.src_port, src_ports_before[j])
    assert_eq(e.dst_port, dst_ports_before[j])
    j = j + 1
  }
  assert_eq(graph.activation_boxes.length(), activation_before)
  assert_eq(graph.sequence_notes.length(), notes_before)
}
