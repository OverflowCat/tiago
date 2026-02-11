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
/// Immutable graph input types for layout engines.
///
/// Engines must treat their inputs as read-only. To enforce this at the type
/// level, the engine-facing graph type (`GraphInput`) and all nested types must
/// not contain `mut` fields.

///|
pub struct GraphInput {
  name : String
  root : ObjectInput
  objects : Array[ObjectInput]
  edges : Array[EdgeInput]
  sequence_fragments : Array[SequenceFragmentInput]
  activation_boxes : Array[(String, Box)]
  sequence_notes : Array[(String, String, Box)]
  sequence_fragments_layout : Array[SequenceFragmentLayout]
  layers : Array[LayerInput]
  scenarios : Array[ScenarioInput]
  steps : Array[StepInput]
  legend : LegendInput?
} derive(Show)

///|
pub fn GraphInput::new(name : String) -> GraphInput {
  let root = ObjectInput::new("root")
  {
    name,
    root,
    objects: [],
    edges: [],
    sequence_fragments: [],
    activation_boxes: [],
    sequence_notes: [],
    sequence_fragments_layout: [],
    layers: [],
    scenarios: [],
    steps: [],
    legend: None,
  }
}

///|
pub fn GraphInput::from_parts(
  name : String,
  root : ObjectInput,
  objects : Array[ObjectInput],
  edges : Array[EdgeInput],
  sequence_fragments : Array[SequenceFragmentInput],
  activation_boxes : Array[(String, Box)],
  sequence_notes : Array[(String, String, Box)],
  sequence_fragments_layout : Array[SequenceFragmentLayout],
  layers : Array[LayerInput],
  scenarios : Array[ScenarioInput],
  steps : Array[StepInput],
  legend : LegendInput?,
) -> GraphInput {
  {
    name,
    root,
    objects,
    edges,
    sequence_fragments,
    activation_boxes,
    sequence_notes,
    sequence_fragments_layout,
    layers,
    scenarios,
    steps,
    legend,
  }
}

///|
pub fn GraphInput::find_object(self : GraphInput, id : String) -> ObjectInput? {
  if self.root.id == id {
    return Some(self.root)
  }
  for obj in self.objects {
    if obj.id == id {
      return Some(obj)
    }
  }
  None
}

///|
pub fn GraphInput::children_of(
  self : GraphInput,
  obj : ObjectInput,
) -> Array[ObjectInput] {
  let children : Array[ObjectInput] = []
  for child_id in obj.child_ids {
    match self.find_object(child_id) {
      Some(child) => children.push(child)
      None => ()
    }
  }
  children
}

///|
pub fn GraphInput::get_objects(self : GraphInput) -> Array[ObjectInput] {
  self.objects
}

///|
pub fn GraphInput::get_edges(self : GraphInput) -> Array[EdgeInput] {
  self.edges
}

///|
pub struct LayerInput {
  name : String
  graph : GraphInput
} derive(Show)

///|
pub fn LayerInput::new(name : String, graph : GraphInput) -> LayerInput {
  { name, graph }
}

///|
pub struct ScenarioInput {
  name : String
  graph : GraphInput
} derive(Show)

///|
pub fn ScenarioInput::new(name : String, graph : GraphInput) -> ScenarioInput {
  { name, graph }
}

///|
pub struct StepInput {
  name : String
  graph : GraphInput
} derive(Show)

///|
pub fn StepInput::new(name : String, graph : GraphInput) -> StepInput {
  { name, graph }
}

///|
pub struct SequenceFragmentInput {
  fragment_type : String
  condition : String?
  start_index : Int
  end_index : Int
  operands : Array[FragmentOperandInput]
} derive(Show)

///|
pub fn SequenceFragmentInput::new(
  fragment_type : String,
  condition : String?,
  start_index : Int,
  end_index : Int,
  operands : Array[FragmentOperandInput],
) -> SequenceFragmentInput {
  { fragment_type, condition, start_index, end_index, operands }
}

///|
pub struct FragmentOperandInput {
  condition : String?
} derive(Show)

///|
pub fn FragmentOperandInput::new(condition : String?) -> FragmentOperandInput {
  { condition, }
}

///|
/// Immutable representation of a graph object for layout engines.
///
/// Fields:
///
/// * `id` : Unique identifier for the object.
/// * `label` : Display text for the object.
/// * `shape_type` : Visual shape of the object.
/// * `style` : Visual styling properties.
/// * `box` : Optional precomputed bounding box.
/// * `label_box` : Optional precomputed label bounding box.
/// * `child_ids` : Array of child object identifiers.
/// * `z_index` : Layer ordering for visual stacking.
/// * `icon` : Optional icon identifier.
/// * `tooltip` : Optional tooltip text.
/// * `link` : Optional hyperlink URL.
/// * `classes` : Array of CSS class names for styling.
/// * `grid_rows` : Optional number of grid rows for layout.
/// * `grid_columns` : Optional number of grid columns for layout.
/// * `grid_gap` : Optional spacing between grid items.
/// * `horizontal_gap` : Optional horizontal spacing between children.
/// * `vertical_gap` : Optional vertical spacing between children.
/// * `grid_column_span` : Optional number of columns this object spans.
/// * `grid_row_span` : Optional number of rows this object spans.
/// * `near` : Optional identifier of object to position near.
/// * `top` : Optional fixed top coordinate in pixels.
/// * `left` : Optional fixed left coordinate in pixels.
///
pub struct ObjectInput {
  id : String
  label : String
  shape_type : ShapeType
  style : StyleInput
  box : Box?
  label_box : Box?
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
  top : Int?
  left : Int?
} derive(Show)

///|
pub fn ObjectInput::new(id : String) -> ObjectInput {
  {
    id,
    label: id,
    shape_type: Rectangle,
    style: StyleInput::new(),
    box: None,
    label_box: None,
    child_ids: [],
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
    top: None,
    left: None,
  }
}

///|
pub fn ObjectInput::from_parts(
  id : String,
  label : String,
  shape_type : ShapeType,
  style : StyleInput,
  box : Box?,
  label_box : Box?,
  child_ids : Array[String],
  z_index : Int,
  icon : String?,
  tooltip : String?,
  link : String?,
  classes : Array[String],
  grid_rows : Int?,
  grid_columns : Int?,
  grid_gap : Double?,
  horizontal_gap : Double?,
  vertical_gap : Double?,
  grid_column_span : Int?,
  grid_row_span : Int?,
  near : String?,
  top : Int?,
  left : Int?,
) -> ObjectInput {
  {
    id,
    label,
    shape_type,
    style,
    box,
    label_box,
    child_ids,
    z_index,
    icon,
    tooltip,
    link,
    classes,
    grid_rows,
    grid_columns,
    grid_gap,
    horizontal_gap,
    vertical_gap,
    grid_column_span,
    grid_row_span,
    near,
    top,
    left,
  }
}

///|
pub fn ObjectInput::get_box(self : ObjectInput) -> Box? {
  self.box
}

///|
pub fn ObjectInput::get_label_box(self : ObjectInput) -> Box? {
  self.label_box
}

///|
pub struct EdgeInput {
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
  style : StyleInput
  route : Array[Point]
  bend_points : Array[Point]?
  is_curve : Bool
  z_index : Int
  reference_count : Int
  label_box : Box?
  src_column_index : Int?
  dst_column_index : Int?
} derive(Show)

///|
pub fn EdgeInput::new(
  index : Int,
  src_id : String,
  dst_id : String,
  src_arrow : Bool,
  dst_arrow : Bool,
) -> EdgeInput {
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
    style: StyleInput::new(),
    route: [],
    bend_points: None,
    is_curve: false,
    z_index: 0,
    reference_count: 1,
    label_box: None,
    src_column_index: None,
    dst_column_index: None,
  }
}

///|
pub fn EdgeInput::from_parts(
  index : Int,
  src_id : String,
  dst_id : String,
  src_arrow : Bool,
  dst_arrow : Bool,
  src_arrowhead : ArrowheadType,
  dst_arrowhead : ArrowheadType,
  src_anchor : String?,
  dst_anchor : String?,
  label : String,
  style : StyleInput,
  route : Array[Point],
  bend_points : Array[Point]?,
  is_curve : Bool,
  z_index : Int,
  reference_count : Int,
  label_box : Box?,
  src_column_index : Int?,
  dst_column_index : Int?,
) -> EdgeInput {
  {
    index,
    src_id,
    dst_id,
    src_arrow,
    dst_arrow,
    src_arrowhead,
    dst_arrowhead,
    src_anchor,
    dst_anchor,
    label,
    style,
    route,
    bend_points,
    is_curve,
    z_index,
    reference_count,
    label_box,
    src_column_index,
    dst_column_index,
  }
}

///|
pub fn EdgeInput::get_src_id(self : EdgeInput) -> String {
  self.src_id
}

///|
pub fn EdgeInput::get_dst_id(self : EdgeInput) -> String {
  self.dst_id
}

///|
pub fn EdgeInput::get_label_box(self : EdgeInput) -> Box? {
  self.label_box
}

///|
/// A style value with its source range.
///
/// The value is preserved as a string. Consumers may parse it as needed.
pub struct StyleValue {
  value : String
  range : @lexer.Range
} derive(Eq, Show)

///|
pub fn StyleValue::new(value : String, range : @lexer.Range) -> StyleValue {
  { value, range }
}

///|
/// Create a style value without a concrete source location.
pub fn StyleValue::synthetic(value : String) -> StyleValue {
  let p = @lexer.Position::zero()
  { value, range: @lexer.Range::new(p, p) }
}

///|
pub fn StyleValue::as_bool(self : StyleValue) -> Bool? {
  match self.value.to_lower() {
    "true" => Some(true)
    "false" => Some(false)
    _ => None
  }
}

///|
pub fn StyleValue::as_int(self : StyleValue) -> Int? {
  Some(@strconv.parse_int(self.value)) catch {
    _ => None
  }
}

///|
pub fn StyleValue::as_double(self : StyleValue) -> Double? {
  Some(@strconv.parse_double(self.value)) catch {
    _ => None
  }
}

///|
pub fn StyleValue::get_value(self : StyleValue) -> String {
  self.value
}

///|
pub fn StyleValue::get_range(self : StyleValue) -> @lexer.Range {
  self.range
}

///|
pub fn StyleValue::from_string(value : String) -> StyleValue {
  StyleValue::synthetic(value)
}

///|
pub fn StyleValue::from_bool(value : Bool) -> StyleValue {
  let s = if value { "true" } else { "false" }
  StyleValue::synthetic(s)
}

///|
pub fn StyleValue::from_int(value : Int) -> StyleValue {
  StyleValue::synthetic("\{value}")
}

///|
pub fn StyleValue::from_double(value : Double) -> StyleValue {
  StyleValue::synthetic("\{value}")
}

///|
pub fn StyleValue::from_string_opt(value : String?) -> StyleValue? {
  match value {
    Some(v) => Some(StyleValue::from_string(v))
    None => None
  }
}

///|
pub fn StyleValue::from_bool_opt(value : Bool?) -> StyleValue? {
  match value {
    Some(v) => Some(StyleValue::from_bool(v))
    None => None
  }
}

///|
pub fn StyleValue::from_int_opt(value : Int?) -> StyleValue? {
  match value {
    Some(v) => Some(StyleValue::from_int(v))
    None => None
  }
}

///|
pub fn StyleValue::from_double_opt(value : Double?) -> StyleValue? {
  match value {
    Some(v) => Some(StyleValue::from_double(v))
    None => None
  }
}

///|
pub struct StyleInput {
  opacity : StyleValue?
  stroke : StyleValue?
  fill : StyleValue?
  stroke_width : StyleValue?
  stroke_dash : StyleValue?
  border_radius : StyleValue?
  shadow : StyleValue?
  three_d : StyleValue?
  multiple : StyleValue?
  font : StyleValue?
  font_size : StyleValue?
  font_color : StyleValue?
  bold : StyleValue?
  italic : StyleValue?
  underline : StyleValue?
  animated : StyleValue?
  filled : StyleValue?
  double_border : StyleValue?
  text_transform : StyleValue?
  font_family : StyleValue?
  fill_pattern : StyleValue?
  sketch : StyleValue?
  curved : StyleValue?
} derive(Eq, Show)

///|
pub fn StyleInput::new() -> StyleInput {
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
pub fn StyleInput::from_parts(
  opacity : StyleValue?,
  stroke : StyleValue?,
  fill : StyleValue?,
  stroke_width : StyleValue?,
  stroke_dash : StyleValue?,
  border_radius : StyleValue?,
  shadow : StyleValue?,
  three_d : StyleValue?,
  multiple : StyleValue?,
  font : StyleValue?,
  font_size : StyleValue?,
  font_color : StyleValue?,
  bold : StyleValue?,
  italic : StyleValue?,
  underline : StyleValue?,
  animated : StyleValue?,
  filled : StyleValue?,
  double_border : StyleValue?,
  text_transform : StyleValue?,
  font_family : StyleValue?,
  fill_pattern : StyleValue?,
  sketch : StyleValue?,
  curved : StyleValue?,
) -> StyleInput {
  {
    opacity,
    stroke,
    fill,
    stroke_width,
    stroke_dash,
    border_radius,
    shadow,
    three_d,
    multiple,
    font,
    font_size,
    font_color,
    bold,
    italic,
    underline,
    animated,
    filled,
    double_border,
    text_transform,
    font_family,
    fill_pattern,
    sketch,
    curved,
  }
}

///|
pub enum LegendEntryInput {
  ShapeEntry(shape~ : ShapeType, label~ : String, style~ : StyleInput?)
  ConnectionEntry(
    src_arrow~ : ArrowheadType,
    dst_arrow~ : ArrowheadType,
    label~ : String,
    style~ : StyleInput?
  )
  CustomEntry(icon~ : String, label~ : String)
  Separator
} derive(Show)

///|
pub fn LegendEntryInput::shape(
  shape : ShapeType,
  label : String,
  style : StyleInput?,
) -> LegendEntryInput {
  ShapeEntry(shape~, label~, style~)
}

///|
pub fn LegendEntryInput::connection(
  src_arrow : ArrowheadType,
  dst_arrow : ArrowheadType,
  label : String,
  style : StyleInput?,
) -> LegendEntryInput {
  ConnectionEntry(src_arrow~, dst_arrow~, label~, style~)
}

///|
pub fn LegendEntryInput::custom(
  icon : String,
  label : String,
) -> LegendEntryInput {
  CustomEntry(icon~, label~)
}

///|
pub fn LegendEntryInput::separator() -> LegendEntryInput {
  Separator
}

///|
pub struct LegendInput {
  title : String?
  position : LegendPosition
  entries : Array[LegendEntryInput]
  fill : String?
  stroke : String?
  padding : Double
  entry_gap : Double
  icon_size : Double
} derive(Show)

///|
pub fn LegendInput::from_parts(
  title : String?,
  position : LegendPosition,
  entries : Array[LegendEntryInput],
  fill : String?,
  stroke : String?,
  padding : Double,
  entry_gap : Double,
  icon_size : Double,
) -> LegendInput {
  { title, position, entries, fill, stroke, padding, entry_gap, icon_size }
}

///|
pub fn LegendInput::is_empty(self : LegendInput) -> Bool {
  self.entries.is_empty()
}

///|
pub fn LegendInput::entry_count(self : LegendInput) -> Int {
  let mut count = 0
  for entry in self.entries {
    match entry {
      Separator => ()
      _ => count += 1
    }
  }
  count
}

///|
pub fn GraphInput::from_model(graph : GraphModel) -> GraphInput {
  let objects : Array[ObjectInput] = []
  for obj in graph.objects {
    objects.push(ObjectInput::from_model(obj))
  }
  let edges : Array[EdgeInput] = []
  for e in graph.edges {
    edges.push(EdgeInput::from_model(e))
  }
  let fragments : Array[SequenceFragmentInput] = []
  for f in graph.sequence_fragments {
    fragments.push(SequenceFragmentInput::from_model(f))
  }
  let layers : Array[LayerInput] = []
  for layer in graph.layers {
    layers.push(
      LayerInput::new(layer.name, GraphInput::from_model(layer.graph)),
    )
  }
  let scenarios : Array[ScenarioInput] = []
  for scenario in graph.scenarios {
    scenarios.push(
      ScenarioInput::new(scenario.name, GraphInput::from_model(scenario.graph)),
    )
  }
  let steps : Array[StepInput] = []
  for step in graph.steps {
    steps.push(StepInput::new(step.name, GraphInput::from_model(step.graph)))
  }
  {
    name: graph.name,
    root: ObjectInput::from_model(graph.root),
    objects,
    edges,
    sequence_fragments: fragments,
    activation_boxes: [],
    sequence_notes: [],
    sequence_fragments_layout: [],
    layers,
    scenarios,
    steps,
    legend: match graph.legend {
      Some(l) => Some(LegendInput::from_model(l))
      None => None
    },
  }
}

///|
pub fn ObjectInput::from_model(obj : ObjectModel) -> ObjectInput {
  let child_ids : Array[String] = []
  for child in obj.children {
    child_ids.push(child.id)
  }
  let classes : Array[String] = []
  for c in obj.classes {
    classes.push(c)
  }
  ObjectInput::from_parts(
    obj.id,
    obj.label,
    obj.shape_type,
    StyleInput::from_model(obj.style),
    obj.box,
    obj.label_box,
    child_ids,
    obj.z_index,
    obj.icon,
    obj.tooltip,
    obj.link,
    classes,
    obj.grid_rows,
    obj.grid_columns,
    obj.grid_gap,
    obj.horizontal_gap,
    obj.vertical_gap,
    obj.grid_column_span,
    obj.grid_row_span,
    obj.near,
    obj.top,
    obj.left,
  )
}

///|
pub fn EdgeInput::from_model(edge : EdgeModel) -> EdgeInput {
  let bend_points = match edge.bend_points {
    Some(ps) => {
      let copied : Array[Point] = []
      for p in ps {
        copied.push(p)
      }
      Some(copied)
    }
    None => None
  }
  EdgeInput::from_parts(
    edge.index,
    edge.src_id,
    edge.dst_id,
    edge.src_arrow,
    edge.dst_arrow,
    edge.src_arrowhead,
    edge.dst_arrowhead,
    edge.src_anchor,
    edge.dst_anchor,
    edge.label,
    StyleInput::from_model(edge.style),
    [],
    bend_points,
    edge.is_curve,
    edge.z_index,
    edge.reference_count,
    edge.label_box,
    edge.src_column_index,
    edge.dst_column_index,
  )
}

///|
pub fn StyleInput::from_model(style : StyleModel) -> StyleInput {
  StyleInput::from_parts(
    style.opacity,
    style.stroke,
    style.fill,
    style.stroke_width,
    style.stroke_dash,
    style.border_radius,
    style.shadow,
    style.three_d,
    style.multiple,
    style.font,
    style.font_size,
    style.font_color,
    style.bold,
    style.italic,
    style.underline,
    style.animated,
    style.filled,
    style.double_border,
    style.text_transform,
    style.font_family,
    style.fill_pattern,
    style.sketch,
    style.curved,
  )
}

///|
pub fn SequenceFragmentInput::from_model(
  fragment : SequenceFragmentModel,
) -> SequenceFragmentInput {
  let operands : Array[FragmentOperandInput] = []
  for op in fragment.operands {
    operands.push({ condition: op.condition })
  }
  {
    fragment_type: fragment.fragment_type,
    condition: fragment.condition,
    start_index: fragment.start_index,
    end_index: fragment.end_index,
    operands,
  }
}

///|
pub fn LegendInput::from_model(legend : LegendModel) -> LegendInput {
  let entries : Array[LegendEntryInput] = []
  for entry in legend.entries {
    entries.push(entry)
  }
  LegendInput::from_parts(
    legend.title,
    legend.position,
    entries,
    legend.fill,
    legend.stroke,
    legend.padding,
    legend.entry_gap,
    legend.icon_size,
  )
}
