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
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  let patch = @graph.LayoutPatch::new()
  let mut i = 0
  for obj in graph.objects {
    let x = (i * 10).to_double()
    let y = (i * 7).to_double()
    patch.nodes[obj.id] = @graph.Box::new(x, y, 10.0, 6.0)
    i = i + 1
  }
  patch
}

///|
impl @engine_api.LayoutEngine for FakeEngine with engine_name(_self) -> String {
  "fake"
}

///|
impl @engine_api.LayoutEngine for FakeEngine with features(_self) -> Array[
  @engine_api.LayoutFeature,
] {
  [
    @engine_api.LayoutFeature::NearObject,
    @engine_api.LayoutFeature::ContainerDimensions,
    @engine_api.LayoutFeature::TopLeft,
    @engine_api.LayoutFeature::DescendantEdges,
  ]
}

///|
fn root_input(child_ids : Array[String]) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    "root",
    "root",
    @graph.Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    child_ids,
    0,
    None,
    None,
    None,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
}

///|
fn object_input(id : String, box : @graph.Box?) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    id,
    id,
    @graph.Rectangle,
    @graph.StyleInput::new(),
    box,
    None,
    [],
    0,
    None,
    None,
    None,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
}

///|
fn graph_input(
  name : String,
  child_ids : Array[String],
  objects : Array[@graph.ObjectInput],
  edges : Array[@graph.EdgeInput],
  layers : Array[@graph.LayerInput],
  scenarios : Array[@graph.ScenarioInput],
  steps : Array[@graph.StepInput],
) -> @graph.GraphInput {
  @graph.GraphInput::from_parts(
    name,
    root_input(child_ids),
    objects,
    edges,
    [],
    [],
    [],
    [],
    layers,
    scenarios,
    steps,
    None,
  )
}

///|
fn compile_graph_input(source : String) -> Result[@graph.GraphInput, String] {
  let (ast, errors) = @parser.parse(source)
  if !errors.is_empty() {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  try @exporter.compile("engine-api-test", ir) catch {
    e => Err("Graph error: \{e}")
  } noraise {
    graph => Ok(graph)
  }
}

///|
fn edge_input(index : Int, curved : Bool?) -> @graph.EdgeInput {
  let style = @graph.StyleInput::from_parts(
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    @graph.StyleValue::from_bool_opt(curved),
  )
  @graph.EdgeInput::from_parts(
    index,
    "a",
    "b",
    false,
    true,
    @graph.None,
    @graph.Triangle,
    None,
    None,
    None,
    None,
    None,
    None,
    "",
    style,
    [],
    None,
    false,
    0,
    1,
    None,
    None,
    None,
  )
}

///|
struct RoundtripEngine {
  _marker : Unit
} derive(Show)

///|
fn RoundtripEngine::new() -> RoundtripEngine {
  { _marker: () }
}

///|
impl @engine_api.LayoutEngine for RoundtripEngine with layout(
  _self,
  _graph,
  _config,
  _direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  let patch = @graph.LayoutPatch::new()
  patch.nodes["a"] = @graph.Box::new(1.0, 2.0, 3.0, 4.0)
  patch.nodes["b"] = @graph.Box::new(10.0, 20.0, 30.0, 40.0)
  patch.edges[7] = [@graph.Point::new(1.0, 1.0), @graph.Point::new(2.0, 2.0)]
  patch.edge_labels[7] = @graph.Box::new(5.0, 6.0, 7.0, 8.0)
  patch.activation_boxes.push(("a", @graph.Box::new(9.0, 9.0, 1.0, 2.0)))
  patch.sequence_notes.push(("a", "note", @graph.Box::new(3.0, 4.0, 5.0, 6.0)))
  patch
}

///|
impl @engine_api.LayoutEngine for RoundtripEngine with engine_name(_self) -> String {
  "roundtrip"
}

///|
impl @engine_api.LayoutEngine for RoundtripEngine with features(_self) -> Array[
  @engine_api.LayoutFeature,
] {
  [
    @engine_api.LayoutFeature::NearObject,
    @engine_api.LayoutFeature::ContainerDimensions,
    @engine_api.LayoutFeature::TopLeft,
    @engine_api.LayoutFeature::DescendantEdges,
  ]
}

///|
test "layout_with_engine applies to variants" {
  let base_objects = [object_input("a", None)]
  let layer_graph = graph_input(
    "layer",
    ["b"],
    [object_input("b", None)],
    [],
    [],
    [],
    [],
  )
  let scenario_graph = graph_input(
    "scenario",
    ["c"],
    [object_input("c", None)],
    [],
    [],
    [],
    [],
  )
  let step_graph = graph_input(
    "step",
    ["d"],
    [object_input("d", None)],
    [],
    [],
    [],
    [],
  )
  let graph = graph_input(
    "base",
    ["a"],
    base_objects,
    [],
    [@graph.LayerInput::new("L1", layer_graph)],
    [@graph.ScenarioInput::new("S1", scenario_graph)],
    [@graph.StepInput::new("step1", step_graph)],
  )
  let engine = FakeEngine::new()
  let config = @engine_api.LayoutConfig::new()
  let laid_out = @engine_api.layout_with_engine(
    engine,
    graph,
    config,
    @engine_api.Direction::Down,
  )
  assert_true(laid_out.find_object("a").unwrap().box is Some(_))
  assert_true(laid_out.layers[0].graph.find_object("b").unwrap().box is Some(_))
  assert_true(
    laid_out.scenarios[0].graph.find_object("c").unwrap().box is Some(_),
  )
  assert_true(laid_out.steps[0].graph.find_object("d").unwrap().box is Some(_))
}

///|
test "layout result roundtrips via graph" {
  let objects = [object_input("a", None), object_input("b", None)]
  let edges = [edge_input(7, None)]
  let graph = graph_input("roundtrip", ["a", "b"], objects, edges, [], [], [])
  let engine = RoundtripEngine::new()
  let laid_out_graph = @engine_api.layout_with_engine(
    engine,
    graph,
    @engine_api.LayoutConfig::new(),
    @engine_api.Direction::Down,
  )
  let diagram = @diagram.from_graph(laid_out_graph, None)
  match diagram.find_object("a").unwrap().get_box() {
    Some(box) => assert_eq(box, @graph.Box::new(1.0, 2.0, 3.0, 4.0))
    None => fail("a should have a box")
  }
  match diagram.find_object("b").unwrap().get_box() {
    Some(box) => assert_eq(box, @graph.Box::new(10.0, 20.0, 30.0, 40.0))
    None => fail("b should have a box")
  }
  let e = diagram.get_edges()[0]
  assert_eq(e.index, 7)
  assert_eq(e.route.length(), 2)
  match e.label_box {
    Some(box) => assert_eq(box, @graph.Box::new(5.0, 6.0, 7.0, 8.0))
    None => fail("edge should have label box")
  }
  assert_eq(diagram.activation_boxes.length(), 1)
  assert_eq(diagram.sequence_notes.length(), 1)
}

///|
test "layout result keeps orthogonalization when curved=false" {
  let objects = [object_input("a", None), object_input("b", None)]
  let edges = [edge_input(7, Some(false))]
  let graph = graph_input(
    "roundtrip-orth",
    ["a", "b"],
    objects,
    edges,
    [],
    [],
    [],
  )
  let engine = RoundtripEngine::new()
  let laid_out_graph = @engine_api.layout_with_engine(
    engine,
    graph,
    @engine_api.LayoutConfig::new(),
    @engine_api.Direction::Down,
  )
  let diagram = @diagram.from_graph(laid_out_graph, None)
  let e = diagram.get_edges()[0]
  assert_eq(e.route.length(), 3)
  match e.label_box {
    Some(box) => assert_eq(box, @graph.Box::new(5.0, 6.0, 7.0, 8.0))
    None => fail("edge should have label box")
  }
}

///|
test "engine implementations must not mutate input graph" {
  let objects = [
    object_input("a", Some(@graph.Box::new(1.0, 1.0, 2.0, 2.0))),
    object_input("b", Some(@graph.Box::new(3.0, 3.0, 4.0, 4.0))),
  ]
  let edges = [@graph.EdgeInput::new(0, "a", "b", false, true)]
  let graph = graph_input("pure", ["a", "b"], objects, edges, [], [], [])

  // Snapshot relevant layout state before calling engine.layout(...)
  let boxes_before : Array[@graph.Box?] = []
  for obj in graph.get_objects() {
    boxes_before.push(obj.box)
  }
  let labels_before : Array[@graph.Box?] = []
  for e in graph.get_edges() {
    labels_before.push(e.label_box)
  }
  let engine = @engine_dagre.DagreEngine::new()
  let config = @engine_api.LayoutConfig::new()
  ignore(engine.layout(graph, config, @engine_api.Direction::Down)) catch {
    e => fail("engine.layout should not fail: \{e}")
  }

  // Input graph must remain unchanged after engine.layout(...)
  let mut i = 0
  for obj in graph.get_objects() {
    assert_eq(obj.box, boxes_before[i])
    i = i + 1
  }
  let mut j = 0
  for e in graph.get_edges() {
    assert_eq(e.label_box, labels_before[j])
    j = j + 1
  }
}

///|
test "dagre rejects object near like the reference feature checks" {
  let source =
    #|a
    #|b: {
    #|  near: a
    #|}
  let graph = compile_graph_input(source).unwrap()
  ignore(
    @engine_api.layout_with_engine(
      @engine_dagre.DagreEngine::new(),
      graph,
      @engine_api.LayoutConfig::new(),
      @engine_api.Direction::Down,
    ),
  ) catch {
    e => {
      assert_eq(
        e,
        @engine_api.unsupported(
          "Object \"b\" has \"near\" set to another object, but layout engine \"dagre\" only supports constant values for \"near\". See https://d2lang.com/tour/layouts/#layout-specific-functionality for more.",
        ),
      )
      return
    }
  }
  fail("expected dagre to reject object near")
}

///|
test "dagre rejects container dimensions like the reference feature checks" {
  let source =
    #|container: {
    #|  width: 320
    #|  a
    #|}
  let graph = compile_graph_input(source).unwrap()
  ignore(
    @engine_api.layout_with_engine(
      @engine_dagre.DagreEngine::new(),
      graph,
      @engine_api.LayoutConfig::new(),
      @engine_api.Direction::Down,
    ),
  ) catch {
    e => {
      assert_eq(
        e,
        @engine_api.unsupported(
          "Object \"container\" has attribute \"width\" and/or \"height\" set, but layout engine \"dagre\" does not support dimensions set on containers. See https://d2lang.com/tour/layouts/#layout-specific-functionality for more.",
        ),
      )
      return
    }
  }
  fail("expected dagre to reject explicit container dimensions")
}

///|
test "dagre rejects descendant edges like the reference feature checks" {
  let source =
    #|aaa: {
    #|  ccc
    #|}
    #|aaa.ccc -- aaa
  let graph = compile_graph_input(source).unwrap()
  ignore(
    @engine_api.layout_with_engine(
      @engine_dagre.DagreEngine::new(),
      graph,
      @engine_api.LayoutConfig::new(),
      @engine_api.Direction::Down,
    ),
  ) catch {
    e => {
      assert_eq(
        e,
        @engine_api.unsupported(
          "Connection \"(aaa.ccc -- aaa)[0]\" goes from a container to a descendant, but layout engine \"dagre\" does not support this. See https://d2lang.com/tour/layouts/#layout-specific-functionality for more.",
        ),
      )
      return
    }
  }
  fail("expected dagre to reject descendant edges")
}

///|
test "elk accepts supported container dimensions and descendant edges" {
  let container_source =
    #|container: {
    #|  width: 320
    #|  a
    #|}
  let container_graph = compile_graph_input(container_source).unwrap()
  let laid_out_container = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    container_graph,
    @engine_api.LayoutConfig::new(),
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk should support container dimensions: \{e}")
  }
  assert_true(
    laid_out_container.find_object("container").unwrap().box is Some(_),
    msg="container should be laid out by elk",
  )

  let descendant_source =
    #|aaa: {
    #|  ccc
    #|}
    #|aaa.ccc -- aaa
  let descendant_graph = compile_graph_input(descendant_source).unwrap()
  let laid_out_descendant = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    descendant_graph,
    @engine_api.LayoutConfig::new(),
    @engine_api.Direction::Down,
  ) catch {
    e => fail("elk should support descendant edges: \{e}")
  }
  assert_true(
    laid_out_descendant.edges[0].route.length() >= 2,
    msg="elk descendant edge should be routed",
  )
}

///|
test "elk still rejects unsupported feature-gated inputs" {
  let near_source =
    #|a
    #|b: {
    #|  near: a
    #|}
  let near_graph = compile_graph_input(near_source).unwrap()
  let mut near_rejected = false
  ignore(
    @engine_api.layout_with_engine(
      @engine_elk.ElkEngine::new(),
      near_graph,
      @engine_api.LayoutConfig::new(),
      @engine_api.Direction::Down,
    ),
  ) catch {
    e => {
      assert_eq(
        e,
        @engine_api.unsupported(
          "Object \"b\" has \"near\" set to another object, but layout engine \"elk\" only supports constant values for \"near\". See https://d2lang.com/tour/layouts/#layout-specific-functionality for more.",
        ),
      )
      near_rejected = true
    }
  }
  assert_true(near_rejected, msg="expected elk to reject object near")

  let pinned_source =
    #|a: {
    #|  top: 10
    #|  left: 20
    #|}
  let pinned_graph = compile_graph_input(pinned_source).unwrap()
  ignore(
    @engine_api.layout_with_engine(
      @engine_elk.ElkEngine::new(),
      pinned_graph,
      @engine_api.LayoutConfig::new(),
      @engine_api.Direction::Down,
    ),
  ) catch {
    e => {
      assert_eq(
        e,
        @engine_api.unsupported(
          "Object \"a\" has attribute \"top\" and/or \"left\" set, but layout engine \"elk\" does not support locked positions. See https://d2lang.com/tour/layouts/#layout-specific-functionality for more.",
        ),
      )
      return
    }
  }
  fail("expected elk to reject top/left")
}
