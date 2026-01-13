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
/// Engine API: layout contract shared between layout engines and exporters.
///
/// The layout pipeline is intentionally functional:
/// - engines take an immutable graph
/// - engines return a `@graph.LayoutPatch`
/// - callers apply the patch to obtain a new graph

///|
/// Layout configuration
pub struct LayoutConfig {
  /// Horizontal spacing between objects
  horizontal_spacing : Double
  /// Vertical spacing between objects
  vertical_spacing : Double
  /// Padding inside containers
  container_padding : Double
  /// Default object width
  default_width : Double
  /// Default object height
  default_height : Double
  /// Edge padding from objects
  edge_padding : Double
} derive(Show)

///|
/// Layout direction
pub(all) enum Direction {
  Down
  Right
  Up
  Left
} derive(Eq, Show)

///|
/// Layout error
pub suberror LayoutError {
  InvalidGraph(String)
  CycleDetected(String)
  Unsupported(String)
} derive(Eq, Show)

///|
/// Construct an `engine_api.LayoutError` from outside this package.
pub fn invalid_graph(message : String) -> LayoutError {
  LayoutError::InvalidGraph(message)
}

///|
pub fn cycle_detected(message : String) -> LayoutError {
  LayoutError::CycleDetected(message)
}

///|
pub fn unsupported(message : String) -> LayoutError {
  LayoutError::Unsupported(message)
}

///|
pub fn LayoutConfig::new() -> LayoutConfig {
  {
    horizontal_spacing: 60.0,
    vertical_spacing: 60.0,
    container_padding: 20.0,
    default_width: 100.0,
    default_height: 60.0,
    edge_padding: 20.0,
  }
}

///|
pub fn LayoutConfig::with_spacing(
  horizontal : Double,
  vertical : Double,
) -> LayoutConfig {
  let config = LayoutConfig::new()
  { ..config, horizontal_spacing: horizontal, vertical_spacing: vertical }
}

///|
/// Layout engine interface.
///
/// Engines must not mutate their input graph. They return a patch that can be
/// applied by the caller.
pub(open) trait LayoutEngine {
  layout(Self, @graph.GraphInput, LayoutConfig, Direction) -> @graph.LayoutPatch raise LayoutError
}

///|
/// Perform layout on a graph (including variants) with a specific engine.
///
/// Returns a new graph with layout applied.
pub fn[Engine : LayoutEngine] layout_with_engine(
  engine : Engine,
  graph : @graph.GraphInput,
  config : LayoutConfig,
  direction : Direction,
) -> @graph.GraphInput raise LayoutError {
  let patch = engine.layout(graph, config, direction)
  let laid_out = @graph.apply_layout(graph, patch)
  let layers : Array[@graph.LayerInput] = []
  for layer in laid_out.layers {
    layers.push(
      @graph.LayerInput::new(
        layer.name,
        layout_with_engine(engine, layer.graph, config, direction),
      ),
    )
  }
  let scenarios : Array[@graph.ScenarioInput] = []
  for scenario in laid_out.scenarios {
    scenarios.push(
      @graph.ScenarioInput::new(
        scenario.name,
        layout_with_engine(engine, scenario.graph, config, direction),
      ),
    )
  }
  let steps : Array[@graph.StepInput] = []
  for step in laid_out.steps {
    steps.push(
      @graph.StepInput::new(
        step.name,
        layout_with_engine(engine, step.graph, config, direction),
      ),
    )
  }
  @graph.GraphInput::from_parts(
    laid_out.name,
    laid_out.root,
    laid_out.objects,
    laid_out.edges,
    laid_out.sequence_fragments,
    laid_out.activation_boxes,
    laid_out.sequence_notes,
    laid_out.sequence_fragments_layout,
    layers,
    scenarios,
    steps,
    laid_out.legend,
  )
}
