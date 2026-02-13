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
/// Render-ready diagram model.
///
/// This module mirrors the responsibilities of a "target" format in other
/// implementations: it is the only input type renderers should consume.

///|
/// Configuration extracted from source (vars/config).
///
/// Caller-provided options may override these values.
pub struct Config {
  sketch : Bool?
  theme_id : Int?
  dark_theme_id : Int?
  theme_overrides : Map[String, String]
  dark_theme_overrides : Map[String, String]
  pad : Double?
  center : Bool?
  layout_engine : String?
  scale : Double?
  no_xml_tag : Bool?
  salt : String?
  omit_version : Bool?
  data : Map[String, String]
} derive(Show)

///|
pub fn Config::new() -> Config {
  {
    sketch: None,
    theme_id: None,
    dark_theme_id: None,
    theme_overrides: {},
    dark_theme_overrides: {},
    pad: None,
    center: None,
    layout_engine: None,
    scale: None,
    no_xml_tag: None,
    salt: None,
    omit_version: None,
    data: {},
  }
}

///|
pub fn Config::from_parts(
  sketch : Bool?,
  theme_id : Int?,
  dark_theme_id : Int?,
  theme_overrides : Map[String, String],
  dark_theme_overrides : Map[String, String],
  pad : Double?,
  center : Bool?,
  layout_engine : String?,
  scale : Double?,
  no_xml_tag : Bool?,
  salt : String?,
  omit_version : Bool?,
  data : Map[String, String],
) -> Config {
  {
    sketch,
    theme_id,
    dark_theme_id,
    theme_overrides,
    dark_theme_overrides,
    pad,
    center,
    layout_engine,
    scale,
    no_xml_tag,
    salt,
    omit_version,
    data,
  }
}

///|
/// Renderable shape.
///
/// This is derived from `@graph.ObjectInput` after layout has been applied.
pub struct Shape {
  id : String
  label : String
  shape_type : @graph.ShapeType
  style : @graph.StyleInput
  box : @graph.Box?
  label_box : @graph.Box?
  child_ids : Array[String]
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
/// Renderable connection.
///
/// This is derived from `@graph.EdgeInput` after layout has been applied.
pub struct Connection {
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
/// Render-ready diagram.
///
/// `shapes` does not include `root`.
pub struct Diagram {
  name : String
  config : Config?
  root : Shape
  shapes : Array[Shape]
  connections : Array[Connection]
  activation_boxes : Array[(String, @graph.Box)]
  sequence_notes : Array[(String, String, @graph.Box)]
  sequence_fragments : Array[@graph.SequenceFragmentLayout]
  layers : Array[Diagram]
  scenarios : Array[Diagram]
  steps : Array[Diagram]
  legend : @graph.LegendInput?
} derive(Show)

///|
pub fn Diagram::has_layers(self : Diagram) -> Bool {
  self.layers.length() > 0
}

///|
pub fn Diagram::has_scenarios(self : Diagram) -> Bool {
  self.scenarios.length() > 0
}

///|
pub fn Diagram::has_steps(self : Diagram) -> Bool {
  self.steps.length() > 0
}

///|
pub fn Diagram::has_legend(self : Diagram) -> Bool {
  match self.legend {
    Some(l) => not(l.is_empty()) && l.position != @graph.Hidden
    None => false
  }
}

///|
/// Get a board by path.
///
/// Supports both explicit and shorthand paths:
/// - Explicit: ["layers", "x", "scenarios", "y"]
/// - Shorthand: ["x", "y"]
pub fn Diagram::get_board(
  self : Diagram,
  board_path : Array[String],
) -> Diagram? {
  get_board_at(self, board_path, 0)
}

///|
fn get_board_at(
  current : Diagram,
  board_path : Array[String],
  index : Int,
) -> Diagram? {
  if index >= board_path.length() {
    return Some(current)
  }

  let head = board_path[index]
  if index == board_path.length() - 1 && current.name == head {
    return Some(current)
  }

  if head == "layers" || head == "scenarios" || head == "steps" {
    if index + 1 >= board_path.length() {
      return None
    }
    let board_name = board_path[index + 1]
    match find_named_board(current, head, board_name) {
      Some(child) => return get_board_at(child, board_path, index + 2)
      None => return None
    }
  }

  match find_named_board_any(current, head) {
    Some(child) => get_board_at(child, board_path, index + 1)
    None => None
  }
}

///|
fn find_named_board(
  current : Diagram,
  board_kind : String,
  board_name : String,
) -> Diagram? {
  if board_kind == "layers" {
    for board in current.layers {
      if board.name == board_name {
        return Some(board)
      }
    }
    return None
  }
  if board_kind == "scenarios" {
    for board in current.scenarios {
      if board.name == board_name {
        return Some(board)
      }
    }
    return None
  }
  if board_kind == "steps" {
    for board in current.steps {
      if board.name == board_name {
        return Some(board)
      }
    }
    return None
  }
  None
}

///|
fn find_named_board_any(current : Diagram, board_name : String) -> Diagram? {
  for board in current.layers {
    if board.name == board_name {
      return Some(board)
    }
  }
  for board in current.scenarios {
    if board.name == board_name {
      return Some(board)
    }
  }
  for board in current.steps {
    if board.name == board_name {
      return Some(board)
    }
  }
  None
}

///|
pub fn Diagram::get_objects(self : Diagram) -> Array[Shape] {
  self.shapes
}

///|
pub fn Diagram::get_edges(self : Diagram) -> Array[Connection] {
  self.connections
}

///|
pub fn Diagram::find_object(self : Diagram, id : String) -> Shape? {
  if self.root.id == id {
    return Some(self.root)
  }
  for obj in self.shapes {
    if obj.id == id {
      return Some(obj)
    }
  }
  None
}

///|
pub fn Shape::get_id(self : Shape) -> String {
  self.id
}

///|
pub fn Shape::get_box(self : Shape) -> @graph.Box? {
  self.box
}

///|
pub fn Shape::center(self : Shape) -> @graph.Point? {
  match self.box {
    Some(b) => Some(b.center())
    None => None
  }
}

///|
fn shape_from_object(obj : @graph.ObjectInput) -> Shape {
  {
    id: obj.id,
    label: obj.label,
    shape_type: obj.shape_type,
    style: obj.style,
    box: obj.box,
    label_box: obj.label_box,
    child_ids: obj.child_ids,
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
fn connection_from_edge(edge : @graph.EdgeInput) -> Connection {
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
    route: edge.route,
    bend_points: edge.bend_points,
    is_curve: edge.is_curve,
    z_index: edge.z_index,
    reference_count: edge.reference_count,
    label_box: edge.label_box,
    src_column_index: edge.src_column_index,
    dst_column_index: edge.dst_column_index,
  }
}

///|
fn sequence_participant_ids(graph : @graph.GraphInput) -> Array[String] {
  if !graph.root.child_ids.is_empty() {
    let ids : Array[String] = []
    let exists : Map[String, Bool] = {}
    for obj in graph.objects {
      exists[obj.id] = true
    }
    for id in graph.root.child_ids {
      if exists.contains(id) {
        ids.push(id)
      }
    }
    if !ids.is_empty() {
      return ids
    }
  }
  let child_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    for child_id in obj.child_ids {
      child_ids[child_id] = true
    }
  }
  let ids : Array[String] = []
  for obj in graph.objects {
    if !child_ids.contains(obj.id) {
      ids.push(obj.id)
    }
  }
  ids
}

///|
fn append_sequence_lifeline_connections(
  graph : @graph.GraphInput,
  shapes : Array[Shape],
  connections : Array[Connection],
) -> Unit {
  if graph.root.shape_type != @graph.SequenceDiagram {
    return
  }

  let box_by_id : Map[String, @graph.Box] = {}
  for shape in shapes {
    match shape.box {
      Some(box) => box_by_id[shape.id] = box
      None => ()
    }
  }

  let participant_ids = sequence_participant_ids(graph)
  if participant_ids.is_empty() {
    return
  }

  let mut max_route_y = 0.0
  for conn in connections {
    for point in conn.route {
      if point.y > max_route_y {
        max_route_y = point.y
      }
    }
  }

  let mut max_start_y = 0.0
  for id in participant_ids {
    match box_by_id.get(id) {
      Some(box) => {
        let start_y = box.y + box.height
        if start_y > max_start_y {
          max_start_y = start_y
        }
      }
      None => ()
    }
  }
  if max_start_y <= 0.0 {
    return
  }

  let lifeline_end_y = if max_route_y > 0.0 {
    max_route_y + 70.0
  } else {
    max_start_y + 120.0
  }

  let mut next_index = 0
  for conn in connections {
    if conn.index >= next_index {
      next_index = conn.index + 1
    }
  }

  for id in participant_ids {
    match box_by_id.get(id) {
      Some(box) => {
        let x = box.x + box.width / 2.0
        let start_y = box.y + box.height
        let dst_id = "\{id}-lifeline-end-\{next_index}"
        connections.push({
          index: next_index,
          src_id: id,
          dst_id,
          src_arrow: false,
          dst_arrow: false,
          src_arrowhead: @graph.None,
          dst_arrowhead: @graph.None,
          src_anchor: None,
          dst_anchor: None,
          label: "",
          style: @graph.StyleInput::new(),
          route: [@graph.Point::new(x, start_y), @graph.Point::new(x, lifeline_end_y)],
          bend_points: None,
          is_curve: false,
          z_index: 0,
          reference_count: 1,
          label_box: None,
          src_column_index: None,
          dst_column_index: None,
        })
        next_index += 1
      }
      None => ()
    }
  }
}

///|
/// Convert a laid-out graph to a render-ready diagram.
///
/// This is the only conversion renderers should need.
pub fn from_graph(graph : @graph.GraphInput, config : Config?) -> Diagram {
  let shapes : Array[Shape] = []
  for obj in graph.objects {
    shapes.push(shape_from_object(obj))
  }
  let connections : Array[Connection] = []
  for edge in graph.edges {
    connections.push(connection_from_edge(edge))
  }
  append_sequence_lifeline_connections(graph, shapes, connections)
  let layers : Array[Diagram] = []
  for layer in graph.layers {
    layers.push(from_graph(layer.graph, config))
  }
  let scenarios : Array[Diagram] = []
  for scenario in graph.scenarios {
    scenarios.push(from_graph(scenario.graph, config))
  }
  let steps : Array[Diagram] = []
  for step in graph.steps {
    steps.push(from_graph(step.graph, config))
  }
  {
    name: graph.name,
    config,
    root: shape_from_object(graph.root),
    shapes,
    connections,
    activation_boxes: graph.activation_boxes,
    sequence_notes: graph.sequence_notes,
    sequence_fragments: graph.sequence_fragments_layout,
    layers,
    scenarios,
    steps,
    legend: graph.legend,
  }
}
