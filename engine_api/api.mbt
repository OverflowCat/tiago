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
  layout(Self, @d2graph.Graph, LayoutConfig, Direction) -> LayoutResult raise LayoutError
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
  points : Array[@d2graph.Point]
} derive(Show)

///|
pub struct LayoutResult {
  nodes : Map[String, NodeLayout]
  edges : Map[Int, EdgeLayout]
  edge_labels : Map[Int, NodeLayout]
  activation_boxes : Array[(String, NodeLayout)]
  sequence_notes : Array[(String, String, NodeLayout)]
  sequence_fragments : Array[@d2graph.SequenceFragment]
} derive(Show)

///|
pub fn NodeLayout::from_box(box : @d2graph.Box) -> NodeLayout {
  { x: box.x, y: box.y, width: box.width, height: box.height }
}

///|
pub fn NodeLayout::to_box(self : NodeLayout) -> @d2graph.Box {
  @d2graph.Box::new(self.x, self.y, self.width, self.height)
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
pub fn LayoutResult::from_graph(graph : @d2graph.Graph) -> LayoutResult {
  let result = LayoutResult::new()
  for obj in graph.objects {
    match obj.box {
      Some(b) => result.nodes[obj.id] = NodeLayout::from_box(b)
      None => ()
    }
  }
  for edge in graph.edges {
    let points : Array[@d2graph.Point] = []
    for p in edge.route {
      points.push(@d2graph.Point::new(p.x, p.y))
    }
    result.edges[edge.index] = { points, }
    match edge.get_label_box() {
      Some(b) => result.edge_labels[edge.index] = NodeLayout::from_box(b)
      None => ()
    }
  }
  for ab in graph.activation_boxes {
    result.activation_boxes.push((ab.0, NodeLayout::from_box(ab.1)))
  }
  for note in graph.sequence_notes {
    result.sequence_notes.push((note.0, note.1, NodeLayout::from_box(note.2)))
  }
  for fragment in graph.sequence_fragments {
    result.sequence_fragments.push(fragment)
  }
  result
}

///|
fn reset_graph_layout_state(graph : @d2graph.Graph) -> Unit {
  for obj in graph.objects {
    obj.box = None
  }
  for edge in graph.edges {
    edge.route.clear()
    edge.label_box = None
    edge.src_port = None
    edge.dst_port = None
  }
  graph.activation_boxes.clear()
  graph.sequence_notes.clear()
  graph.sequence_fragments.clear()
}

///|
pub fn LayoutResult::apply_to_graph(
  self : LayoutResult,
  graph : @d2graph.Graph,
) -> Unit {
  reset_graph_layout_state(graph)
  for obj in graph.objects {
    match self.nodes.get(obj.id) {
      Some(layout) => obj.set_box(layout.to_box())
      None => ()
    }
  }
  for edge in graph.edges {
    match self.edges.get(edge.index) {
      Some(layout) => {
        edge.route.clear()
        for p in layout.points {
          edge.route.push(p)
        }
      }
      None => ()
    }
    match self.edge_labels.get(edge.index) {
      Some(layout) => edge.label_box = Some(layout.to_box())
      None => ()
    }
  }
  graph.activation_boxes.clear()
  for box in self.activation_boxes {
    graph.activation_boxes.push((box.0, box.1.to_box()))
  }
  graph.sequence_notes.clear()
  for note in self.sequence_notes {
    graph.sequence_notes.push((note.0, note.1, note.2.to_box()))
  }
  graph.sequence_fragments.clear()
  for fragment in self.sequence_fragments {
    graph.sequence_fragments.push(fragment)
  }
}

///|
/// Perform layout on a graph with a specific engine.
pub fn[Engine : LayoutEngine] layout_with_engine(
  engine : Engine,
  graph : @d2graph.Graph,
  config : LayoutConfig,
  direction : Direction,
) -> LayoutResult raise LayoutError {
  let result = engine.layout(graph, config, direction)
  result.apply_to_graph(graph)
  for layer in graph.layers {
    ignore(layout_with_engine(engine, layer.graph, config, direction))
  }
  for scenario in graph.scenarios {
    ignore(layout_with_engine(engine, scenario.graph, config, direction))
  }
  for step in graph.steps {
    ignore(layout_with_engine(engine, step.graph, config, direction))
  }
  result
}
