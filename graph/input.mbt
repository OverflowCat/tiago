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
  layers : Array[LayerInput]
  scenarios : Array[ScenarioInput]
  steps : Array[StepInput]
  legend : LegendInput?
} derive(Show)

///|
pub struct LayerInput {
  name : String
  graph : GraphInput
} derive(Show)

///|
pub struct ScenarioInput {
  name : String
  graph : GraphInput
} derive(Show)

///|
pub struct StepInput {
  name : String
  graph : GraphInput
} derive(Show)

///|
pub struct SequenceFragmentInput {
  fragment_type : String
  condition : String?
  start_index : Int
  end_index : Int
  operands : Array[FragmentOperandInput]
} derive(Show)

///|
pub struct FragmentOperandInput {
  condition : String?
} derive(Show)

///|
/// Immutable representation of a graph object for layout engines.
///
/// Fields:
///
/// * `id` : Unique identifier for the object.
/// * `label` : Display text for the object.
/// * `shape_type` : Visual shape of the object.
/// * `style` : Visual styling properties.
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
///
pub struct ObjectInput {
  id : String
  label : String
  shape_type : ShapeType
  style : StyleInput
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
  bend_points : Array[Point]?
  is_curve : Bool
  z_index : Int
  reference_count : Int
  src_column_index : Int?
  dst_column_index : Int?
} derive(Show)

///|
pub struct StyleInput {
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
pub fn LegendInput::calculate_size(
  self : LegendInput,
  font_size : Int,
) -> (Double, Double) {
  if self.is_empty() {
    return (0.0, 0.0)
  }
  let mut max_label_width = 0.0
  let mut total_height = self.padding * 2.0
  match self.title {
    Some(t) => {
      max_label_width = t.length().to_double() * font_size.to_double() * 0.6
      total_height = total_height + font_size.to_double() + self.entry_gap
    }
    None => ()
  }
  for entry in self.entries {
    match entry {
      ShapeEntry(label~, ..)
      | ConnectionEntry(label~, ..)
      | CustomEntry(label~, ..) => {
        let label_width = label.length().to_double() *
          font_size.to_double() *
          0.6
        max_label_width = if label_width > max_label_width {
          label_width
        } else {
          max_label_width
        }
        total_height = total_height + self.icon_size + self.entry_gap
      }
      Separator => total_height = total_height + 4.0 + self.entry_gap
    }
  }
  let width = self.padding * 2.0 +
    self.icon_size +
    self.entry_gap +
    max_label_width
  (width, total_height)
}

///|
pub fn GraphInput::from_graph(graph : Graph) -> GraphInput {
  let objects : Array[ObjectInput] = []
  for obj in graph.objects {
    objects.push(ObjectInput::from_object(obj))
  }
  let edges : Array[EdgeInput] = []
  for e in graph.edges {
    edges.push(EdgeInput::from_edge(e))
  }
  let fragments : Array[SequenceFragmentInput] = []
  for f in graph.sequence_fragments {
    fragments.push(SequenceFragmentInput::from_fragment(f))
  }
  let layers : Array[LayerInput] = []
  for layer in graph.layers {
    layers.push({ name: layer.name, graph: GraphInput::from_graph(layer.graph) })
  }
  let scenarios : Array[ScenarioInput] = []
  for scenario in graph.scenarios {
    scenarios.push({
      name: scenario.name,
      graph: GraphInput::from_graph(scenario.graph),
    })
  }
  let steps : Array[StepInput] = []
  for step in graph.steps {
    steps.push({ name: step.name, graph: GraphInput::from_graph(step.graph) })
  }
  {
    name: graph.name,
    root: ObjectInput::from_object(graph.root),
    objects,
    edges,
    sequence_fragments: fragments,
    layers,
    scenarios,
    steps,
    legend: match graph.legend {
      Some(l) => Some(LegendInput::from_legend(l))
      None => None
    },
  }
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
    layers.push({ name: layer.name, graph: GraphInput::from_model(layer.graph) })
  }
  let scenarios : Array[ScenarioInput] = []
  for scenario in graph.scenarios {
    scenarios.push({
      name: scenario.name,
      graph: GraphInput::from_model(scenario.graph),
    })
  }
  let steps : Array[StepInput] = []
  for step in graph.steps {
    steps.push({ name: step.name, graph: GraphInput::from_model(step.graph) })
  }
  {
    name: graph.name,
    root: ObjectInput::from_model(graph.root),
    objects,
    edges,
    sequence_fragments: fragments,
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
pub fn ObjectInput::from_object(obj : Object) -> ObjectInput {
  let child_ids : Array[String] = []
  for child in obj.children {
    child_ids.push(child.id)
  }
  let classes : Array[String] = []
  for c in obj.classes {
    classes.push(c)
  }
  {
    id: obj.id,
    label: obj.label,
    shape_type: obj.shape_type,
    style: StyleInput::from_style(obj.style),
    child_ids,
    z_index: obj.z_index,
    icon: obj.icon,
    tooltip: obj.tooltip,
    link: obj.link,
    classes,
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
pub fn ObjectInput::from_model(obj : ObjectModel) -> ObjectInput {
  let child_ids : Array[String] = []
  for child in obj.children {
    child_ids.push(child.id)
  }
  let classes : Array[String] = []
  for c in obj.classes {
    classes.push(c)
  }
  {
    id: obj.id,
    label: obj.label,
    shape_type: obj.shape_type,
    style: StyleInput::from_model(obj.style),
    child_ids,
    z_index: obj.z_index,
    icon: obj.icon,
    tooltip: obj.tooltip,
    link: obj.link,
    classes,
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
pub fn EdgeInput::from_edge(edge : Edge) -> EdgeInput {
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
    style: StyleInput::from_style(edge.style),
    bend_points,
    is_curve: edge.is_curve,
    z_index: edge.z_index,
    reference_count: edge.reference_count,
    src_column_index: edge.src_column_index,
    dst_column_index: edge.dst_column_index,
  }
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
    style: StyleInput::from_model(edge.style),
    bend_points,
    is_curve: edge.is_curve,
    z_index: edge.z_index,
    reference_count: edge.reference_count,
    src_column_index: edge.src_column_index,
    dst_column_index: edge.dst_column_index,
  }
}

///|
pub fn StyleInput::from_style(style : Style) -> StyleInput {
  {
    opacity: style.opacity,
    stroke: style.stroke,
    fill: style.fill,
    stroke_width: style.stroke_width,
    stroke_dash: style.stroke_dash,
    border_radius: style.border_radius,
    shadow: style.shadow,
    three_d: style.three_d,
    multiple: style.multiple,
    font: style.font,
    font_size: style.font_size,
    font_color: style.font_color,
    bold: style.bold,
    italic: style.italic,
    underline: style.underline,
    animated: style.animated,
    filled: style.filled,
    double_border: style.double_border,
    text_transform: style.text_transform,
    font_family: style.font_family,
    fill_pattern: style.fill_pattern,
    sketch: style.sketch,
    curved: style.curved,
  }
}

///|
pub fn StyleInput::from_model(style : StyleModel) -> StyleInput {
  {
    opacity: style.opacity,
    stroke: style.stroke,
    fill: style.fill,
    stroke_width: style.stroke_width,
    stroke_dash: style.stroke_dash,
    border_radius: style.border_radius,
    shadow: style.shadow,
    three_d: style.three_d,
    multiple: style.multiple,
    font: style.font,
    font_size: style.font_size,
    font_color: style.font_color,
    bold: style.bold,
    italic: style.italic,
    underline: style.underline,
    animated: style.animated,
    filled: style.filled,
    double_border: style.double_border,
    text_transform: style.text_transform,
    font_family: style.font_family,
    fill_pattern: style.fill_pattern,
    sketch: style.sketch,
    curved: style.curved,
  }
}

///|
pub fn SequenceFragmentInput::from_fragment(
  fragment : SequenceFragment,
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
pub fn LegendInput::from_legend(legend : Legend) -> LegendInput {
  let entries : Array[LegendEntryInput] = []
  for entry in legend.entries {
    entries.push(LegendEntryInput::from_entry(entry))
  }
  {
    title: legend.title,
    position: legend.position,
    entries,
    fill: legend.fill,
    stroke: legend.stroke,
    padding: legend.padding,
    entry_gap: legend.entry_gap,
    icon_size: legend.icon_size,
  }
}

///|
pub fn LegendInput::from_model(legend : LegendModel) -> LegendInput {
  let entries : Array[LegendEntryInput] = []
  for entry in legend.entries {
    entries.push(LegendEntryInput::from_entry(entry))
  }
  {
    title: legend.title,
    position: legend.position,
    entries,
    fill: legend.fill,
    stroke: legend.stroke,
    padding: legend.padding,
    entry_gap: legend.entry_gap,
    icon_size: legend.icon_size,
  }
}

///|
pub fn LegendEntryInput::from_entry(entry : LegendEntry) -> LegendEntryInput {
  match entry {
    ShapeEntry(shape~, label~, style~) => {
      let style = match style {
        Some(s) => Some(StyleInput::from_style(s))
        None => None
      }
      ShapeEntry(shape~, label~, style~)
    }
    ConnectionEntry(src_arrow~, dst_arrow~, label~, style~) => {
      let style = match style {
        Some(s) => Some(StyleInput::from_style(s))
        None => None
      }
      ConnectionEntry(src_arrow~, dst_arrow~, label~, style~)
    }
    CustomEntry(icon~, label~) => CustomEntry(icon~, label~)
    Separator => Separator
  }
}

///|
pub fn Graph::from_input(input : GraphInput) -> Graph {
  let objects : Array[Object] = []
  let object_by_id : Map[String, Object] = {}
  let root = Object::from_input_shallow(input.root)
  object_by_id[root.id] = root
  for obj in input.objects {
    let created = Object::from_input_shallow(obj)
    object_by_id[created.id] = created
    objects.push(created)
  }

  // Wire children by IDs to preserve identity.
  Object::wire_children(object_by_id, input.root)
  for obj in input.objects {
    Object::wire_children(object_by_id, obj)
  }
  let edges : Array[Edge] = []
  for e in input.edges {
    edges.push(Edge::from_input(e))
  }
  let fragments : Array[SequenceFragment] = []
  for f in input.sequence_fragments {
    fragments.push(SequenceFragment::from_input(f))
  }
  let layers : Array[Layer] = []
  for layer in input.layers {
    layers.push(Layer::new(layer.name, Graph::from_input(layer.graph)))
  }
  let scenarios : Array[Scenario] = []
  for scenario in input.scenarios {
    scenarios.push(
      Scenario::new(scenario.name, Graph::from_input(scenario.graph)),
    )
  }
  let steps : Array[Step] = []
  for step in input.steps {
    steps.push(Step::new(step.name, Graph::from_input(step.graph)))
  }
  let legend = match input.legend {
    Some(l) => Some(Legend::from_input(l))
    None => None
  }
  {
    name: input.name,
    root,
    objects,
    edges,
    activation_boxes: [],
    sequence_notes: [],
    sequence_fragments: fragments,
    layers,
    scenarios,
    steps,
    legend,
  }
}

///|
fn Object::from_input_shallow(input : ObjectInput) -> Object {
  {
    id: input.id,
    label: input.label,
    shape_type: input.shape_type,
    style: Style::from_input(input.style),
    box: None,
    label_box: None,
    children: [],
    z_index: input.z_index,
    icon: input.icon,
    tooltip: input.tooltip,
    link: input.link,
    classes: input.classes,
    grid_rows: input.grid_rows,
    grid_columns: input.grid_columns,
    grid_gap: input.grid_gap,
    horizontal_gap: input.horizontal_gap,
    vertical_gap: input.vertical_gap,
    grid_column_span: input.grid_column_span,
    grid_row_span: input.grid_row_span,
    near: input.near,
  }
}

///|
fn Object::wire_children(
  object_by_id : Map[String, Object],
  input : ObjectInput,
) -> Unit {
  match object_by_id.get(input.id) {
    Some(obj) => {
      obj.children.clear()
      for child_id in input.child_ids {
        match object_by_id.get(child_id) {
          Some(child) => obj.children.push(child)
          None => ()
        }
      }
    }
    None => ()
  }
}

///|
fn Edge::from_input(input : EdgeInput) -> Edge {
  {
    index: input.index,
    src_id: input.src_id,
    dst_id: input.dst_id,
    src_arrow: input.src_arrow,
    dst_arrow: input.dst_arrow,
    src_arrowhead: input.src_arrowhead,
    dst_arrowhead: input.dst_arrowhead,
    src_anchor: input.src_anchor,
    dst_anchor: input.dst_anchor,
    label: input.label,
    style: Style::from_input(input.style),
    route: [],
    bend_points: input.bend_points,
    is_curve: input.is_curve,
    z_index: input.z_index,
    reference_count: input.reference_count,
    label_box: None,
    src_column_index: input.src_column_index,
    dst_column_index: input.dst_column_index,
    src_port: None,
    dst_port: None,
  }
}

///|
fn Style::from_input(input : StyleInput) -> Style {
  {
    opacity: input.opacity,
    stroke: input.stroke,
    fill: input.fill,
    stroke_width: input.stroke_width,
    stroke_dash: input.stroke_dash,
    border_radius: input.border_radius,
    shadow: input.shadow,
    three_d: input.three_d,
    multiple: input.multiple,
    font: input.font,
    font_size: input.font_size,
    font_color: input.font_color,
    bold: input.bold,
    italic: input.italic,
    underline: input.underline,
    animated: input.animated,
    filled: input.filled,
    double_border: input.double_border,
    text_transform: input.text_transform,
    font_family: input.font_family,
    fill_pattern: input.fill_pattern,
    sketch: input.sketch,
    curved: input.curved,
  }
}

///|
fn SequenceFragment::from_input(
  input : SequenceFragmentInput,
) -> SequenceFragment {
  let operands : Array[FragmentOperand] = []
  for op in input.operands {
    operands.push({ condition: op.condition, separator_y: 0.0 })
  }
  {
    fragment_type: input.fragment_type,
    condition: input.condition,
    bbox: None,
    start_index: input.start_index,
    end_index: input.end_index,
    operands,
  }
}

///|
fn Legend::from_input(input : LegendInput) -> Legend {
  let entries : Array[LegendEntry] = []
  for e in input.entries {
    entries.push(LegendEntry::from_input(e))
  }
  {
    title: input.title,
    position: input.position,
    entries,
    fill: input.fill,
    stroke: input.stroke,
    padding: input.padding,
    entry_gap: input.entry_gap,
    icon_size: input.icon_size,
  }
}

///|
fn LegendEntry::from_input(input : LegendEntryInput) -> LegendEntry {
  match input {
    ShapeEntry(shape~, label~, style~) => {
      let style = match style {
        Some(s) => Some(Style::from_input(s))
        None => None
      }
      ShapeEntry(shape~, label~, style~)
    }
    ConnectionEntry(src_arrow~, dst_arrow~, label~, style~) => {
      let style = match style {
        Some(s) => Some(Style::from_input(s))
        None => None
      }
      ConnectionEntry(src_arrow~, dst_arrow~, label~, style~)
    }
    CustomEntry(icon~, label~) => CustomEntry(icon~, label~)
    Separator => Separator
  }
}
