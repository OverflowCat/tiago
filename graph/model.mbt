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
/// Immutable data model for functional architecture

///|
/// Immutable legend configuration
pub struct LegendModel {
  title : String?
  position : LegendPosition
  entries : Array[LegendEntry]
  fill : String?
  stroke : String?
  padding : Double
  entry_gap : Double
  icon_size : Double
} derive(Show)

///|
pub fn LegendModel::new() -> LegendModel {
  {
    title: None,
    position: BottomRight,
    entries: [],
    fill: Some("#ffffff"),
    stroke: Some("#cccccc"),
    padding: 12.0,
    entry_gap: 8.0,
    icon_size: 20.0,
  }
}

///|
/// Immutable sequence fragment operand
pub struct FragmentOperandModel {
  condition : String?
  separator_y : Double
} derive(Show)

///|
/// Immutable sequence fragment
pub struct SequenceFragmentModel {
  fragment_type : String
  condition : String?
  bbox : Box?
  start_index : Int
  end_index : Int
  operands : Array[FragmentOperandModel]
} derive(Show)

///|
pub fn SequenceFragmentModel::new(
  fragment_type : String,
  start_index : Int,
  end_index : Int,
) -> SequenceFragmentModel {
  {
    fragment_type,
    condition: None,
    bbox: None,
    start_index,
    end_index,
    operands: [],
  }
}

///|
/// Immutable style model
pub struct StyleModel {
  opacity : Double?
  stroke : String?
  fill : String?
  stroke_width : Double?
  stroke_dash : Double?
  border_radius : Double?
  shadow : Bool?
  three_d : Bool?
  multiple : Bool?
  font : String?
  font_size : Int?
  font_color : String?
  bold : Bool?
  italic : Bool?
  underline : Bool?
  animated : Bool?
  filled : Bool?
  double_border : Bool?
  text_transform : String?
  font_family : String?
  fill_pattern : String?
  sketch : Bool?
  curved : Bool?
} derive(Eq, Show)

///|
pub fn StyleModel::new() -> StyleModel {
  {
    opacity: None,
    stroke: None,
    fill: None,
    stroke_width: None,
    stroke_dash: None,
    border_radius: None,
    shadow: None,
    three_d: None,
    multiple: None,
    font: None,
    font_size: None,
    font_color: None,
    bold: None,
    italic: None,
    underline: None,
    animated: None,
    filled: None,
    double_border: None,
    text_transform: None,
    font_family: None,
    fill_pattern: None,
    sketch: None,
    curved: None,
  }
}

///|
/// Immutable object model
pub struct ObjectModel {
  id : String
  label : String
  shape_type : ShapeType
  style : StyleModel
  box : Box?
  label_box : Box?
  children : Array[ObjectModel]
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
pub fn ObjectModel::new(id : String) -> ObjectModel {
  {
    id,
    label: id,
    shape_type: Rectangle,
    style: StyleModel::new(),
    box: None,
    label_box: None,
    children: [],
    z_index: 0,
    icon: None,
    tooltip: None,
    link: None,
    classes: [],
    grid_rows: None,
    grid_columns: None,
    grid_gap: None,
    horizontal_gap: None,
    vertical_gap: None,
    grid_column_span: None,
    grid_row_span: None,
    near: None,
  }
}

///|
/// Immutable edge model
pub struct EdgeModel {
  index : Int
  src_id : String
  dst_id : String
  src_arrow : Bool
  dst_arrow : Bool
  src_arrowhead : ArrowheadType
  dst_arrowhead : ArrowheadType
  src_anchor : String?
  dst_anchor : String?
  label : String
  style : StyleModel
  route : Array[Point]
  bend_points : Array[Point]?
  is_curve : Bool
  z_index : Int
  reference_count : Int
  label_box : Box?
  src_column_index : Int?
  dst_column_index : Int?
  src_port : Port?
  dst_port : Port?
} derive(Show)

///|
pub fn EdgeModel::new(
  index : Int,
  src_id : String,
  dst_id : String,
  src_arrow : Bool,
  dst_arrow : Bool,
) -> EdgeModel {
  {
    index,
    src_id,
    dst_id,
    src_arrow,
    dst_arrow,
    src_arrowhead: if src_arrow {
      Triangle
    } else {
      None
    },
    dst_arrowhead: if dst_arrow {
      Triangle
    } else {
      None
    },
    src_anchor: None,
    dst_anchor: None,
    label: "",
    style: StyleModel::new(),
    route: [],
    bend_points: None,
    is_curve: false,
    z_index: 0,
    reference_count: 1,
    label_box: None,
    src_column_index: None,
    dst_column_index: None,
    src_port: None,
    dst_port: None,
  }
}

///|
/// Immutable graph model
pub struct GraphModel {
  name : String
  root : ObjectModel
  objects : Array[ObjectModel]
  edges : Array[EdgeModel]
  activation_boxes : Array[(String, Box)]
  sequence_notes : Array[(String, String, Box)]
  sequence_fragments : Array[SequenceFragmentModel]
  layers : Array[LayerModel]
  scenarios : Array[ScenarioModel]
  steps : Array[StepModel]
  legend : LegendModel?
} derive(Show)

///|
/// Immutable layer model
pub struct LayerModel {
  name : String
  graph : GraphModel
} derive(Show)

///|
/// Immutable scenario model
pub struct ScenarioModel {
  name : String
  graph : GraphModel
} derive(Show)

///|
/// Immutable step model
pub struct StepModel {
  name : String
  graph : GraphModel
} derive(Show)

///|
pub fn GraphModel::new(name : String) -> GraphModel {
  let root = ObjectModel::new("root")
  {
    name,
    root,
    objects: [],
    edges: [],
    activation_boxes: [],
    sequence_notes: [],
    sequence_fragments: [],
    layers: [],
    scenarios: [],
    steps: [],
    legend: None,
  }
}

///|
/// Functional helpers
pub fn ObjectModel::with_label(
  self : ObjectModel,
  label : String,
) -> ObjectModel {
  { ..self, label, }
}

///|
pub fn ObjectModel::with_box(self : ObjectModel, box : Box?) -> ObjectModel {
  { ..self, box, }
}

///|
pub fn ObjectModel::with_label_box(
  self : ObjectModel,
  label_box : Box?,
) -> ObjectModel {
  { ..self, label_box, }
}

///|
pub fn ObjectModel::add_child(
  self : ObjectModel,
  child : ObjectModel,
) -> ObjectModel {
  let children = self.children.copy()
  children.push(child)
  { ..self, children, }
}

///|
pub fn EdgeModel::with_label(self : EdgeModel, label : String) -> EdgeModel {
  { ..self, label, }
}

///|
pub fn EdgeModel::with_route(
  self : EdgeModel,
  route : Array[Point],
) -> EdgeModel {
  { ..self, route, }
}

///|
pub fn EdgeModel::with_label_box(
  self : EdgeModel,
  label_box : Box?,
) -> EdgeModel {
  { ..self, label_box, }
}

///|
pub fn GraphModel::add_object(
  self : GraphModel,
  obj : ObjectModel,
) -> GraphModel {
  let objects = self.objects.copy()
  objects.push(obj)
  { ..self, objects, }
}

///|
pub fn GraphModel::add_edge(self : GraphModel, edge : EdgeModel) -> GraphModel {
  let edges = self.edges.copy()
  edges.push(edge)
  { ..self, edges, }
}

///|
pub fn GraphModel::with_legend(
  self : GraphModel,
  legend : LegendModel?,
) -> GraphModel {
  { ..self, legend, }
}
