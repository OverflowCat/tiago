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
/// Render-focused immutable graph model built from GraphInput + LayoutOutputs.

///|
pub struct RenderObject {
  id : String
  label : String
  shape_type : @graph.ShapeType
  style : @graph.StyleInput
  box : @graph.Box?
  label_box : @graph.Box?
  children : Array[RenderObject]
  z_index : Int
  icon : String?
  tooltip : String?
  link : String?
  classes : Array[String]
  grid_rows : Int?
  grid_columns : Int?
  grid_gap : Double?
  horizontal_gap : Double?
  vertical_gap : Double?
  grid_column_span : Int?
  grid_row_span : Int?
  near : String?
} derive(Show)

///|
pub fn RenderObject::is_container(self : RenderObject) -> Bool {
  self.children.length() > 0
}

///|
pub struct RenderEdge {
  index : Int
  src_id : String
  dst_id : String
  src_arrow : Bool
  dst_arrow : Bool
  src_arrowhead : @graph.ArrowheadType
  dst_arrowhead : @graph.ArrowheadType
  src_anchor : String?
  dst_anchor : String?
  label : String
  style : @graph.StyleInput
  route : Array[@graph.Point]
  bend_points : Array[@graph.Point]?
  is_curve : Bool
  z_index : Int
  reference_count : Int
  label_box : @graph.Box?
  src_column_index : Int?
  dst_column_index : Int?
} derive(Show)

///|
pub struct RenderLayer {
  name : String
  graph : RenderGraph
} derive(Show)

///|
pub struct RenderScenario {
  name : String
  graph : RenderGraph
} derive(Show)

///|
pub struct RenderStep {
  name : String
  graph : RenderGraph
} derive(Show)

///|
pub struct RenderGraph {
  name : String
  root : RenderObject
  objects : Array[RenderObject]
  edges : Array[RenderEdge]
  activation_boxes : Array[(String, @graph.Box)]
  sequence_notes : Array[(String, String, @graph.Box)]
  sequence_fragments : Array[@engine_api.SequenceFragmentLayout]
  layers : Array[RenderLayer]
  scenarios : Array[RenderScenario]
  steps : Array[RenderStep]
  legend : @graph.LegendInput?
} derive(Show)

///|
pub fn RenderGraph::has_layers(self : RenderGraph) -> Bool {
  self.layers.length() > 0
}

///|
pub fn RenderGraph::has_scenarios(self : RenderGraph) -> Bool {
  self.scenarios.length() > 0
}

///|
pub fn RenderGraph::has_steps(self : RenderGraph) -> Bool {
  self.steps.length() > 0
}

///|
pub fn build_render_graph(
  graph : @graph.GraphInput,
  outputs : @engine_api.LayoutOutputs,
) -> RenderGraph {
  let layout = outputs.layout
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.id] = graph.root
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  let root = build_render_object(graph.root, object_by_id, layout)
  let objects : Array[RenderObject] = []
  for obj in graph.objects {
    objects.push(build_render_object(obj, object_by_id, layout))
  }
  let edges : Array[RenderEdge] = []
  for edge in graph.edges {
    edges.push(build_render_edge(edge, layout))
  }
  let activation_boxes : Array[(String, @graph.Box)] = []
  for ab in layout.activation_boxes {
    activation_boxes.push((ab.0, ab.1.to_box()))
  }
  let sequence_notes : Array[(String, String, @graph.Box)] = []
  for note in layout.sequence_notes {
    sequence_notes.push((note.0, note.1, note.2.to_box()))
  }
  let layers : Array[RenderLayer] = []
  for i, layer in graph.layers {
    let (_, layer_outputs) = outputs.layers[i]
    layers.push({
      name: layer.name,
      graph: build_render_graph(layer.graph, layer_outputs),
    })
  }
  let scenarios : Array[RenderScenario] = []
  for i, scenario in graph.scenarios {
    let (_, scenario_outputs) = outputs.scenarios[i]
    scenarios.push({
      name: scenario.name,
      graph: build_render_graph(scenario.graph, scenario_outputs),
    })
  }
  let steps : Array[RenderStep] = []
  for i, step in graph.steps {
    let (_, step_outputs) = outputs.steps[i]
    steps.push({
      name: step.name,
      graph: build_render_graph(step.graph, step_outputs),
    })
  }
  {
    name: graph.name,
    root,
    objects,
    edges,
    activation_boxes,
    sequence_notes,
    sequence_fragments: layout.sequence_fragments,
    layers,
    scenarios,
    steps,
    legend: graph.legend,
  }
}

///|
fn build_render_object(
  obj : @graph.ObjectInput,
  object_by_id : Map[String, @graph.ObjectInput],
  layout : @engine_api.LayoutResult,
) -> RenderObject {
  let children : Array[RenderObject] = []
  for child_id in obj.child_ids {
    match object_by_id.get(child_id) {
      Some(child) =>
        children.push(build_render_object(child, object_by_id, layout))
      None => ()
    }
  }
  let box = match layout.nodes.get(obj.id) {
    Some(node_layout) => Some(node_layout.to_box())
    None => None
  }
  {
    id: obj.id,
    label: obj.label,
    shape_type: obj.shape_type,
    style: obj.style,
    box,
    label_box: None,
    children,
    z_index: obj.z_index,
    icon: obj.icon,
    tooltip: obj.tooltip,
    link: obj.link,
    classes: obj.classes,
    grid_rows: obj.grid_rows,
    grid_columns: obj.grid_columns,
    grid_gap: obj.grid_gap,
    horizontal_gap: obj.horizontal_gap,
    vertical_gap: obj.vertical_gap,
    grid_column_span: obj.grid_column_span,
    grid_row_span: obj.grid_row_span,
    near: obj.near,
  }
}

///|
fn build_render_edge(
  edge : @graph.EdgeInput,
  layout : @engine_api.LayoutResult,
) -> RenderEdge {
  let route = match layout.edges.get(edge.index) {
    Some(edge_layout) => edge_layout.points
    None => []
  }
  let label_box = match layout.edge_labels.get(edge.index) {
    Some(label_layout) => Some(label_layout.to_box())
    None => None
  }
  if edge.label.length() > 0 && label_box is None {
    abort(
      "Edge '\{edge.src_id} -> \{edge.dst_id}' has label but no computed label box",
    )
  }
  {
    index: edge.index,
    src_id: edge.src_id,
    dst_id: edge.dst_id,
    src_arrow: edge.src_arrow,
    dst_arrow: edge.dst_arrow,
    src_arrowhead: edge.src_arrowhead,
    dst_arrowhead: edge.dst_arrowhead,
    src_anchor: edge.src_anchor,
    dst_anchor: edge.dst_anchor,
    label: edge.label,
    style: edge.style,
    route,
    bend_points: edge.bend_points,
    is_curve: edge.is_curve,
    z_index: edge.z_index,
    reference_count: edge.reference_count,
    label_box,
    src_column_index: edge.src_column_index,
    dst_column_index: edge.dst_column_index,
  }
}
