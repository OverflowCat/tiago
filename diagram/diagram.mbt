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
/// Temporary `diagram` skeleton.

///|
pub struct Diagram {
  graph : @graph.GraphInput
  layout : @engine_api.LayoutOutputs
} derive(Show)

///|
pub fn build(
  graph : @graph.GraphInput,
  layout : @engine_api.LayoutOutputs,
) -> Diagram {
  { graph, layout }
}

///|
/// Materialize a diagram into a render-focused graph snapshot.
pub fn materialize(diagram : Diagram) -> RenderGraph {
  build_render_graph(diagram.graph, diagram.layout)
}

///|
/// Convenience: run layout engine and build a diagram from immutable input.
pub fn[Engine : @engine_api.LayoutEngine] layout_with_engine(
  engine : Engine,
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> Diagram raise @engine_api.LayoutError {
  let outputs = @engine_api.layout_with_engine(engine, graph, config, direction)
  build(graph, outputs)
}

///|
