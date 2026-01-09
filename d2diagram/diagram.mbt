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
/// Temporary `d2diagram` skeleton.

///|
pub struct Diagram {
  graph : @d2graph.GraphInput
  layout : @engine_api.LayoutOutputs
} derive(Show)

///|
pub fn build(
  graph : @d2graph.GraphInput,
  layout : @engine_api.LayoutOutputs,
) -> Diagram {
  { graph, layout }
}

///|
pub fn Diagram::materialize(self : Diagram) -> @d2graph.Graph {
  materialize_graph(self.graph, self.layout)
}

///|
/// Convenience: run layout engine and build a diagram from a mutable graph.
pub fn[Engine : @engine_api.LayoutEngine] layout_with_engine(
  engine : Engine,
  graph : @d2graph.Graph,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> Diagram raise @engine_api.LayoutError {
  let input = @d2graph.GraphInput::from_graph(graph)
  let outputs = @engine_api.layout_with_engine(engine, input, config, direction)
  build(input, outputs)
}

///|
/// Bridge: wrap an already-laid-out `d2graph.Graph` as a `Diagram`.
///
/// This captures the graph’s current layout state into `LayoutOutputs` (including
/// variants) without running an engine.
pub fn from_laid_out_graph(graph : @d2graph.Graph) -> Diagram {
  let input = @d2graph.GraphInput::from_graph(graph)
  build(input, @engine_api.LayoutOutputs::from_graph(graph))
}

///|
fn materialize_graph(
  graph : @d2graph.GraphInput,
  outputs : @engine_api.LayoutOutputs,
) -> @d2graph.Graph {
  let materialized = @d2graph.Graph::from_input(graph)
  outputs.layout.apply_to_graph(materialized)
  materialized.layers.clear()
  for i, layer in graph.layers {
    let (_, layer_outputs) = outputs.layers[i]
    let sub = materialize_graph(layer.graph, layer_outputs)
    materialized.layers.push(@d2graph.Layer::new(layer.name, sub))
  }
  materialized.scenarios.clear()
  for i, scenario in graph.scenarios {
    let (_, scenario_outputs) = outputs.scenarios[i]
    let sub = materialize_graph(scenario.graph, scenario_outputs)
    materialized.scenarios.push(@d2graph.Scenario::new(scenario.name, sub))
  }
  materialized.steps.clear()
  for i, step in graph.steps {
    let (_, step_outputs) = outputs.steps[i]
    let sub = materialize_graph(step.graph, step_outputs)
    materialized.steps.push(@d2graph.Step::new(step.name, sub))
  }
  materialized
}

///|
