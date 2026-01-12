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
/// Engine API: layout contract shared between Diago engines and renderers.

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
pub(open) trait LayoutEngine {
  layout(Self, @graph.GraphInput, LayoutConfig, Direction) -> LayoutResult raise LayoutError
}

///|
/// Layout result for a single graph.
///
/// This is the "contract" between layout engines and renderers: engines compute
/// geometry without requiring callers to understand how graph internals store
/// boxes/routes.
pub struct NodeLayout {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Show)

///|
pub struct EdgeLayout {
  points : Array[@graph.Point]
} derive(Show)

///|
pub fn EdgeLayout::new(points : Array[@graph.Point]) -> EdgeLayout {
  { points, }
}

///|
/// Sequence diagram fragment layout operand.
pub struct FragmentOperandLayout {
  condition : String?
  separator_y : Double
} derive(Show)

///|
pub fn FragmentOperandLayout::new(
  condition : String?,
  separator_y : Double,
) -> FragmentOperandLayout {
  { condition, separator_y }
}

///|
/// Sequence diagram fragment layout information.
pub struct SequenceFragmentLayout {
  fragment_type : String
  condition : String?
  bbox : @graph.Box?
  start_index : Int
  end_index : Int
  operands : Array[FragmentOperandLayout]
} derive(Show)

///|
pub fn SequenceFragmentLayout::new(
  fragment_type : String,
  condition : String?,
  bbox : @graph.Box?,
  start_index : Int,
  end_index : Int,
  operands : Array[FragmentOperandLayout],
) -> SequenceFragmentLayout {
  { fragment_type, condition, bbox, start_index, end_index, operands }
}

///|
/// Complete layout information for a rendered diagram graph.
///
/// This structure contains all the geometric information needed by renderers to
/// draw a graph, including node positions, edge routing, labels, and special
/// sequence diagram elements. It serves as the contract between layout engines
/// and renderers.
///
/// Fields:
///
/// * `nodes` : Position and size information for each graph node, keyed by node
///   ID.
/// * `edges` : Routing points for each graph edge, keyed by edge index.
/// * `edge_labels` : Position and size information for edge labels, keyed by
///   edge index.
/// * `activation_boxes` : Sequence diagram activation boxes with their
///   associated node IDs and layout information.
/// * `sequence_notes` : Sequence diagram notes with source ID, target ID, and
///   layout information.
/// * `sequence_fragments` : Sequence diagram fragment elements.
///
pub struct LayoutResult {
  nodes : Map[String, NodeLayout]
  edges : Map[Int, EdgeLayout]
  edge_labels : Map[Int, NodeLayout]
  activation_boxes : Array[(String, NodeLayout)]
  sequence_notes : Array[(String, String, NodeLayout)]
  sequence_fragments : Array[SequenceFragmentLayout]
} derive(Show)

///|
/// Layout outputs for a graph and all of its variants.
pub struct LayoutOutputs {
  layout : LayoutResult
  layers : Array[(String, LayoutOutputs)]
  scenarios : Array[(String, LayoutOutputs)]
  steps : Array[(String, LayoutOutputs)]
} derive(Show)

///|
pub fn NodeLayout::from_box(box : @graph.Box) -> NodeLayout {
  { x: box.x, y: box.y, width: box.width, height: box.height }
}

///|
pub fn NodeLayout::to_box(self : NodeLayout) -> @graph.Box {
  @graph.Box::new(self.x, self.y, self.width, self.height)
}

///|
pub fn LayoutResult::new() -> LayoutResult {
  {
    nodes: {},
    edges: {},
    edge_labels: {},
    activation_boxes: [],
    sequence_notes: [],
    sequence_fragments: [],
  }
}

///|
/// Perform layout on a graph (including variants) with a specific engine.
pub fn[Engine : LayoutEngine] layout_with_engine(
  engine : Engine,
  graph : @graph.GraphInput,
  config : LayoutConfig,
  direction : Direction,
) -> LayoutOutputs raise LayoutError {
  let layout = engine.layout(graph, config, direction)
  let layers : Array[(String, LayoutOutputs)] = []
  for layer in graph.layers {
    layers.push(
      (layer.name, layout_with_engine(engine, layer.graph, config, direction)),
    )
  }
  let scenarios : Array[(String, LayoutOutputs)] = []
  for scenario in graph.scenarios {
    scenarios.push(
      (
        scenario.name,
        layout_with_engine(engine, scenario.graph, config, direction),
      ),
    )
  }
  let steps : Array[(String, LayoutOutputs)] = []
  for step in graph.steps {
    steps.push(
      (step.name, layout_with_engine(engine, step.graph, config, direction)),
    )
  }
  { layout, layers, scenarios, steps }
}
