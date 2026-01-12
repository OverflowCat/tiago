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
/// Graph representation for diago diagrams
///
/// The Graph is the final representation used for layout and rendering.
/// It contains Objects (nodes) and Edges (connections) with their
/// visual properties.

///|
using @graph {
  type ArrowheadType,
  type Box,
  type EdgeInput,
  type FragmentOperandInput,
  type GraphInput,
  type ObjectInput,
  type Point,
  type SequenceFragmentInput,
  type ShapeType,
  type StyleInput,
}

///|
/// The main graph structure
pub(all) struct Graph {
  name : String
  root : Object
  objects : Array[Object]
  edges : Array[Edge]
  /// Activation boxes for sequence diagrams (actor_id, bounding box)
  mut activation_boxes : Array[(String, Box)]
  /// Notes for sequence diagrams (actor_id, text, bounding box)
  mut sequence_notes : Array[(String, String, Box)]
  /// Sequence diagram fragments (combined fragments like alt, opt, loop)
  sequence_fragments : Array[SequenceFragment]
  /// Named layers - multiple diagram variants (for layers: {...})
  layers : Array[Layer]
  /// Named scenarios - diagram variations with base + delta (for scenarios: {...})
  scenarios : Array[Scenario]
  /// Named steps - animation frames (for steps: {...})
  steps : Array[Step]
  /// Legend configuration
  mut legend : @graph.LegendInput?
} derive(Show)

///|
/// A named layer in the diagram
pub(all) struct Layer {
  name : String
  graph : Graph
} derive(Show)

///|
/// A scenario variant
pub(all) struct Scenario {
  name : String
  graph : Graph
} derive(Show)

///|
/// An animation step
pub(all) struct Step {
  name : String
  graph : Graph
} derive(Show)

///|
/// A sequence diagram combined fragment (alt, opt, loop, par, etc.)
pub(all) struct SequenceFragment {
  /// Fragment type: "alt", "opt", "loop", "par", "break", "critical"
  fragment_type : String
  /// Guard condition text (e.g., "[condition]")
  mut condition : String?
  /// Bounding box computed during layout
  mut bbox : Box?
  /// Start message index (first message in this fragment)
  start_index : Int
  /// End message index (last message in this fragment)
  end_index : Int
  /// Operands for multi-branch fragments like "alt" (each operand has a condition)
  operands : Array[FragmentOperand]
} derive(Show)

///|
/// An operand within a combined fragment (e.g., one branch of an "alt")
pub(all) struct FragmentOperand {
  /// Condition for this operand (e.g., "[else]")
  condition : String?
  /// Y position of the operand separator line
  mut separator_y : Double
} derive(Show)

///|
pub fn SequenceFragment::new(
  fragment_type : String,
  start_index : Int,
  end_index : Int,
) -> SequenceFragment {
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
pub fn FragmentOperand::new(condition : String?) -> FragmentOperand {
  { condition, separator_y: 0.0 }
}

///|
/// A node/shape in the diagram
pub(all) struct Object {
  /// Unique identifier
  id : String
  /// Display label
  mut label : String
  /// Shape type
  mut shape_type : ShapeType
  /// Visual style
  style : Style
  /// Position and size
  mut box : Box?
  /// Computed label bounding box (for layout engines)
  mut label_box : Box?
  /// Child objects (for containers)
  children : Array[Object]
  /// Z-index for layering
  z_index : Int
  /// Icon URL if any
  mut icon : String?
  /// Tooltip text
  mut tooltip : String?
  /// Link URL
  mut link : String?
  /// CSS classes
  classes : Array[String]
  /// Grid layout: number of rows
  mut grid_rows : Int?
  /// Grid layout: number of columns
  mut grid_columns : Int?
  /// Grid layout: gap between cells
  mut grid_gap : Double?
  /// Grid layout: horizontal gap between cells
  mut horizontal_gap : Double?
  /// Grid layout: vertical gap between cells
  mut vertical_gap : Double?
  /// Grid cell spanning: number of columns this cell spans
  mut grid_column_span : Int?
  /// Grid cell spanning: number of rows this cell spans
  mut grid_row_span : Int?
  /// Near positioning: object ID or constant position (top-left, center, etc.)
  mut near : String?
} derive(Show)

///|
/// An edge/connection between objects
pub(all) struct Edge {
  /// Index in the graph's edge list
  index : Int
  /// Source object ID
  src_id : String
  /// Destination object ID
  dst_id : String
  /// Has arrow at source
  src_arrow : Bool
  /// Has arrow at destination
  dst_arrow : Bool
  /// Source arrowhead type
  mut src_arrowhead : ArrowheadType
  /// Destination arrowhead type
  mut dst_arrowhead : ArrowheadType
  /// Source anchor position (top, bottom, left, right, center)
  mut src_anchor : String?
  /// Destination anchor position (top, bottom, left, right, center)
  mut dst_anchor : String?
  /// Edge label
  mut label : String
  /// Visual style
  style : Style
  /// Route points for the edge path
  route : Array[Point]
  /// User-specified bend points (excluding endpoints)
  mut bend_points : Array[Point]?
  /// Whether edge is curved
  is_curve : Bool
  /// Z-index for layering
  z_index : Int
  /// Number of times this edge is declared (for parallel rendering)
  mut reference_count : Int
  /// Computed label bounding box (for automatic label positioning)
  mut label_box : Box?
  /// Source SQL table column index (for field-level connections)
  mut src_column_index : Int?
  /// Destination SQL table column index (for field-level connections)
  mut dst_column_index : Int?
  /// Assigned source port (computed during port assignment phase)
  mut src_port : Port?
  /// Assigned destination port (computed during port assignment phase)
  mut dst_port : Port?
} derive(Show)

///|
/// Port side for edge connections
pub(all) enum PortSide {
  Top
  Bottom
  Left
  Right
} derive(Eq, Show)

///|
/// A port on a node where an edge connects
pub(all) struct Port {
  /// Which side of the node this port is on
  side : PortSide
  /// Position along the side (0.0 = start, 1.0 = end)
  position : Double
  /// Computed absolute coordinates (filled after assignment)
  mut point : Point?
} derive(Eq, Show)

///|
/// Visual styling properties
pub(all) struct Style {
  mut opacity : Double?
  mut stroke : String?
  mut fill : String?
  mut stroke_width : Double?
  mut stroke_dash : Double?
  mut border_radius : Double?
  mut shadow : Bool?
  mut three_d : Bool?
  multiple : Bool?
  font : String?
  mut font_size : Int?
  mut font_color : String?
  mut bold : Bool?
  mut italic : Bool?
  underline : Bool?
  mut animated : Bool?
  filled : Bool?
  mut double_border : Bool?
  /// Text transformation: uppercase, lowercase, capitalize, none
  mut text_transform : String?
  /// Custom font family
  mut font_family : String?
  /// Fill pattern: dots, lines, cross-hatch, grain
  mut fill_pattern : String?
  /// Sketch mode: hand-drawn appearance
  mut sketch : Bool?
  /// Curved edges: use smooth bezier curves instead of straight lines
  mut curved : Bool?
} derive(Eq, Show)

// ============================================================================
// Constructors
// ============================================================================

///|
pub fn Graph::new(name : String) -> Graph {
  let root = Object::new("root")
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
/// Materialize a mutable graph from immutable input.
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
    legend: input.legend,
  }
}

///|
/// Convert a mutable graph back to immutable input.
pub fn Graph::to_input(self : Graph) -> GraphInput {
  let objects : Array[ObjectInput] = []
  for obj in self.objects {
    objects.push(Object::to_input(obj))
  }
  let edges : Array[EdgeInput] = []
  for edge in self.edges {
    edges.push(Edge::to_input(edge))
  }
  let fragments : Array[SequenceFragmentInput] = []
  for fragment in self.sequence_fragments {
    fragments.push(SequenceFragment::to_input(fragment))
  }
  let layers : Array[@graph.LayerInput] = []
  for layer in self.layers {
    layers.push(@graph.LayerInput::new(layer.name, layer.graph.to_input()))
  }
  let scenarios : Array[@graph.ScenarioInput] = []
  for scenario in self.scenarios {
    scenarios.push(
      @graph.ScenarioInput::new(scenario.name, scenario.graph.to_input()),
    )
  }
  let steps : Array[@graph.StepInput] = []
  for step in self.steps {
    steps.push(@graph.StepInput::new(step.name, step.graph.to_input()))
  }
  @graph.GraphInput::from_parts(
    self.name,
    Object::to_input(self.root),
    objects,
    edges,
    fragments,
    layers,
    scenarios,
    steps,
    self.legend,
  )
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
fn Style::to_input(style : Style) -> StyleInput {
  @graph.StyleInput::from_parts(
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
fn Object::to_input(obj : Object) -> ObjectInput {
  let child_ids : Array[String] = []
  for child in obj.children {
    child_ids.push(child.id)
  }
  let classes : Array[String] = []
  for c in obj.classes {
    classes.push(c)
  }
  @graph.ObjectInput::from_parts(
    obj.id,
    obj.label,
    obj.shape_type,
    Style::to_input(obj.style),
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
  )
}

///|
fn Edge::to_input(edge : Edge) -> EdgeInput {
  @graph.EdgeInput::from_parts(
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
    Style::to_input(edge.style),
    edge.bend_points,
    edge.is_curve,
    edge.z_index,
    edge.reference_count,
    edge.label_box,
    edge.src_column_index,
    edge.dst_column_index,
  )
}

///|
fn SequenceFragment::to_input(
  fragment : SequenceFragment,
) -> SequenceFragmentInput {
  let operands : Array[FragmentOperandInput] = []
  for op in fragment.operands {
    operands.push(@graph.FragmentOperandInput::new(op.condition))
  }
  @graph.SequenceFragmentInput::new(
    fragment.fragment_type,
    fragment.condition,
    fragment.start_index,
    fragment.end_index,
    operands,
  )
}

///|
fn Object::from_input_shallow(input : ObjectInput) -> Object {
  {
    id: input.id,
    label: input.label,
    shape_type: input.shape_type,
    style: Style::from_input(input.style),
    box: input.box,
    label_box: input.label_box,
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
    label_box: input.label_box,
    src_column_index: input.src_column_index,
    dst_column_index: input.dst_column_index,
    src_port: None,
    dst_port: None,
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
/// Add a sequence fragment to the graph
pub fn Graph::add_fragment(self : Graph, fragment : SequenceFragment) -> Unit {
  self.sequence_fragments.push(fragment)
}

///|
/// Check if graph has any sequence fragments
pub fn Graph::has_fragments(self : Graph) -> Bool {
  self.sequence_fragments.length() > 0
}

///|
/// Get the graph's legend
pub fn Graph::get_legend(self : Graph) -> @graph.LegendInput? {
  self.legend
}

///|
/// Set the graph's legend
pub fn Graph::set_legend(self : Graph, legend : @graph.LegendInput) -> Unit {
  self.legend = Some(legend)
}

///|
/// Check if the graph has a legend configured
pub fn Graph::has_legend(self : Graph) -> Bool {
  match self.legend {
    Some(l) => not(l.is_empty()) && l.position != @graph.Hidden
    None => false
  }
}

///|
/// Get a layer by name
pub fn Graph::get_layer(self : Graph, name : String) -> Graph? {
  for layer in self.layers {
    if layer.name == name {
      return Some(layer.graph)
    }
  }
  None
}

///|
/// Get a scenario by name
pub fn Graph::get_scenario(self : Graph, name : String) -> Graph? {
  for scenario in self.scenarios {
    if scenario.name == name {
      return Some(scenario.graph)
    }
  }
  None
}

///|
/// Get a step by index (1-indexed)
pub fn Graph::get_step(self : Graph, index : Int) -> Graph? {
  if index < 1 || index > self.steps.length() {
    return None
  }
  Some(self.steps[index - 1].graph)
}

///|
/// Get a step by name
pub fn Graph::get_step_by_name(self : Graph, name : String) -> Graph? {
  for step in self.steps {
    if step.name == name {
      return Some(step.graph)
    }
  }
  None
}

///|
/// Check if graph has any layers
pub fn Graph::has_layers(self : Graph) -> Bool {
  not(self.layers.is_empty())
}

///|
/// Check if graph has any scenarios
pub fn Graph::has_scenarios(self : Graph) -> Bool {
  not(self.scenarios.is_empty())
}

///|
/// Check if graph has any steps
pub fn Graph::has_steps(self : Graph) -> Bool {
  not(self.steps.is_empty())
}

///|
/// Check if graph has any variants (layers, scenarios, or steps)
pub fn Graph::has_variants(self : Graph) -> Bool {
  self.has_layers() || self.has_scenarios() || self.has_steps()
}

///|
/// Get layer names
pub fn Graph::layer_names(self : Graph) -> Array[String] {
  let names : Array[String] = []
  for layer in self.layers {
    names.push(layer.name)
  }
  names
}

///|
/// Get scenario names
pub fn Graph::scenario_names(self : Graph) -> Array[String] {
  let names : Array[String] = []
  for scenario in self.scenarios {
    names.push(scenario.name)
  }
  names
}

///|
/// Get step names
pub fn Graph::step_names(self : Graph) -> Array[String] {
  let names : Array[String] = []
  for step in self.steps {
    names.push(step.name)
  }
  names
}

///|
pub fn Layer::new(name : String, graph : Graph) -> Layer {
  { name, graph }
}

///|
pub fn Scenario::new(name : String, graph : Graph) -> Scenario {
  { name, graph }
}

///|
pub fn Step::new(name : String, graph : Graph) -> Step {
  { name, graph }
}

///|
pub fn Object::new(id : String) -> Object {
  {
    id,
    label: id,
    shape_type: Rectangle,
    style: Style::new(),
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
pub fn Object::with_label(id : String, label : String) -> Object {
  let obj = Object::new(id)
  obj.label = label
  obj
}

///|
pub fn Edge::new(
  index : Int,
  src_id : String,
  dst_id : String,
  src_arrow : Bool,
  dst_arrow : Bool,
) -> Edge {
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
    style: Style::new(),
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
pub fn Port::new(side : PortSide, position : Double) -> Port {
  { side, position, point: None }
}

///|
/// Get the port's side
pub fn Port::get_side(self : Port) -> PortSide {
  self.side
}

///|
/// Get the port's position along the side (0.0 to 1.0)
pub fn Port::get_position(self : Port) -> Double {
  self.position
}

///|
/// Get the port's absolute point coordinates
pub fn Port::get_point(self : Port) -> Point? {
  self.point
}

///|
/// Set the port's absolute point coordinates
pub fn Port::set_point(self : Port, p : Point) -> Unit {
  self.point = Some(p)
}

///|
/// Check if this port connects vertically (top or bottom side)
pub fn Port::is_vertical(self : Port) -> Bool {
  match self.side {
    Top | Bottom => true
    Left | Right => false
  }
}

///|
/// Check if this port connects horizontally (left or right side)
pub fn Port::is_horizontal(self : Port) -> Bool {
  match self.side {
    Left | Right => true
    Top | Bottom => false
  }
}

///|
pub fn Style::new() -> Style {
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

// ============================================================================
// Graph operations
// ============================================================================

///|
/// Add an object to the graph
pub fn Graph::add_object(self : Graph, obj : Object) -> Unit {
  self.objects.push(obj)
}

///|
/// Get all objects in the graph
pub fn Graph::get_objects(self : Graph) -> Array[Object] {
  self.objects
}

///|
/// Get all edges in the graph
pub fn Graph::get_edges(self : Graph) -> Array[Edge] {
  self.edges
}

///|
/// Add an edge to the graph
pub fn Graph::add_edge(self : Graph, edge : Edge) -> Unit {
  self.edges.push(edge)
}

///|
/// Find an object by ID
pub fn Graph::find_object(self : Graph, id : String) -> Object? {
  for obj in self.objects {
    if obj.id == id {
      return Some(obj)
    }
  }
  None
}

///|
/// Get all edges from a source object
pub fn Graph::edges_from(self : Graph, src_id : String) -> Array[Edge] {
  let result : Array[Edge] = []
  for edge in self.edges {
    if edge.src_id == src_id {
      result.push(edge)
    }
  }
  result
}

///|
/// Get all edges to a destination object
pub fn Graph::edges_to(self : Graph, dst_id : String) -> Array[Edge] {
  let result : Array[Edge] = []
  for edge in self.edges {
    if edge.dst_id == dst_id {
      result.push(edge)
    }
  }
  result
}

///|
/// Add a layer to the graph
pub fn Graph::add_layer(self : Graph, layer : Layer) -> Unit {
  self.layers.push(layer)
}

///|
/// Get all layers
pub fn Graph::get_layers(self : Graph) -> Array[Layer] {
  self.layers
}

///|
/// Add a scenario to the graph
pub fn Graph::add_scenario(self : Graph, scenario : Scenario) -> Unit {
  self.scenarios.push(scenario)
}

///|
/// Get all scenarios
pub fn Graph::get_scenarios(self : Graph) -> Array[Scenario] {
  self.scenarios
}

///|
/// Add a step to the graph
pub fn Graph::add_step(self : Graph, step : Step) -> Unit {
  self.steps.push(step)
}

///|
/// Get all steps
pub fn Graph::get_steps(self : Graph) -> Array[Step] {
  self.steps
}

// ============================================================================
// Object operations
// ============================================================================

///|
/// Add a child object
pub fn Object::add_child(self : Object, child : Object) -> Unit {
  self.children.push(child)
}

///|
/// Find a child by ID
pub fn Object::find_child(self : Object, id : String) -> Object? {
  for child in self.children {
    if child.id == id {
      return Some(child)
    }
  }
  None
}

///|
/// Check if this object is a container (has children)
pub fn Object::is_container(self : Object) -> Bool {
  self.children.length() > 0
}

///|
/// Check if this object is a grid diagram (has grid-rows or grid-columns)
pub fn Object::is_grid_diagram(self : Object) -> Bool {
  self.grid_rows is Some(_) || self.grid_columns is Some(_)
}

///|
/// Get grid rows count
pub fn Object::get_grid_rows(self : Object) -> Int? {
  self.grid_rows
}

///|
/// Get grid columns count
pub fn Object::get_grid_columns(self : Object) -> Int? {
  self.grid_columns
}

///|
/// Get horizontal gap (uses grid_gap as default)
pub fn Object::get_horizontal_gap(self : Object) -> Double {
  match self.horizontal_gap {
    Some(v) => v
    None =>
      match self.grid_gap {
        Some(v) => v
        None => 40.0 // Default gap
      }
  }
}

///|
/// Get vertical gap (uses grid_gap as default)
pub fn Object::get_vertical_gap(self : Object) -> Double {
  match self.vertical_gap {
    Some(v) => v
    None =>
      match self.grid_gap {
        Some(v) => v
        None => 40.0 // Default gap
      }
  }
}

///|
/// Set grid rows
pub fn Object::set_grid_rows(self : Object, rows : Int) -> Unit {
  self.grid_rows = Some(rows)
}

///|
/// Set grid columns
pub fn Object::set_grid_columns(self : Object, columns : Int) -> Unit {
  self.grid_columns = Some(columns)
}

///|
/// Set grid gap
pub fn Object::set_grid_gap(self : Object, gap : Double) -> Unit {
  self.grid_gap = Some(gap)
}

///|
/// Get column span (returns 1 if not set)
pub fn Object::get_grid_column_span(self : Object) -> Int {
  match self.grid_column_span {
    Some(v) => if v >= 1 { v } else { 1 }
    None => 1
  }
}

///|
/// Get row span (returns 1 if not set)
pub fn Object::get_grid_row_span(self : Object) -> Int {
  match self.grid_row_span {
    Some(v) => if v >= 1 { v } else { 1 }
    None => 1
  }
}

///|
/// Set column span
pub fn Object::set_grid_column_span(self : Object, span : Int) -> Unit {
  self.grid_column_span = Some(span)
}

///|
/// Set row span
pub fn Object::set_grid_row_span(self : Object, span : Int) -> Unit {
  self.grid_row_span = Some(span)
}

///|
/// Get near positioning target
pub fn Object::get_near(self : Object) -> String? {
  self.near
}

///|
/// Set near positioning target
pub fn Object::set_near(self : Object, near : String) -> Unit {
  self.near = Some(near)
}

///|
/// Check if this object uses near positioning
pub fn Object::has_near(self : Object) -> Bool {
  self.near is Some(_)
}

///|
/// Set the position and size of the object
pub fn Object::set_box(self : Object, box : Box) -> Unit {
  self.box = Some(box)
}

///|
/// Set the shape of the object (from string)
pub fn Object::set_shape(self : Object, shape : String) -> Unit {
  self.shape_type = ShapeType::from_string(shape)
}

///|
/// Set the shape type of the object
pub fn Object::set_shape_type(self : Object, shape_type : ShapeType) -> Unit {
  self.shape_type = shape_type
}

///|
/// Set the label of the object
pub fn Object::set_label(self : Object, label : String) -> Unit {
  self.label = label
}

///|
/// Get the object's ID
pub fn Object::get_id(self : Object) -> String {
  self.id
}

///|
/// Get the object's box (position and size)
pub fn Object::get_box(self : Object) -> Box? {
  self.box
}

///|
/// Get the object's children
pub fn Object::get_children(self : Object) -> Array[Object] {
  self.children
}

///|
/// Get the object's shape as string
pub fn Object::get_shape(self : Object) -> String {
  self.shape_type.to_shape_string()
}

///|
/// Get the object's shape type
pub fn Object::get_shape_type(self : Object) -> ShapeType {
  self.shape_type
}

///|
/// Get the object's label
pub fn Object::get_label(self : Object) -> String {
  self.label
}

///|
/// Get the center point of the object's box
pub fn Object::center(self : Object) -> Point? {
  match self.box {
    Some(b) => Some(Point::new(b.x + b.width / 2.0, b.y + b.height / 2.0))
    None => None
  }
}

// ============================================================================
// Edge operations
// ============================================================================

///|
/// Get the arrow string representation
pub fn Edge::arrow_string(self : Edge) -> String {
  if self.src_arrow && self.dst_arrow {
    "<->"
  } else if self.src_arrow {
    "<-"
  } else if self.dst_arrow {
    "->"
  } else {
    "--"
  }
}

///|
/// Set the label of the edge
pub fn Edge::set_label(self : Edge, label : String) -> Unit {
  self.label = label
}

///|
/// Get the source object ID
pub fn Edge::get_src_id(self : Edge) -> String {
  self.src_id
}

///|
/// Get the destination object ID
pub fn Edge::get_dst_id(self : Edge) -> String {
  self.dst_id
}

///|
/// Get the route points
pub fn Edge::get_route(self : Edge) -> Array[Point] {
  self.route
}

///|
/// Get user-specified bend points (excluding endpoints)
pub fn Edge::get_bend_points(self : Edge) -> Array[Point]? {
  self.bend_points
}

///|
/// Set user-specified bend points (excluding endpoints)
pub fn Edge::set_bend_points(self : Edge, points : Array[Point]) -> Unit {
  self.bend_points = Some(points)
}

///|
/// Add a point to the route
pub fn Edge::add_route_point(self : Edge, p : Point) -> Unit {
  self.route.push(p)
}

///|
/// Get the midpoint of the edge route
pub fn Edge::midpoint(self : Edge) -> Point? {
  let len = self.route.length()
  if len == 0 {
    return None
  }
  if len == 1 {
    return Some(self.route[0])
  }
  // For even number of points, average the two middle points
  let mid = len / 2
  if len % 2 == 0 {
    let p1 = self.route[mid - 1]
    let p2 = self.route[mid]
    Some(Point::new((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0))
  } else {
    Some(self.route[mid])
  }
}

///|
/// Set the computed label bounding box
pub fn Edge::set_label_box(self : Edge, box : Box) -> Unit {
  self.label_box = Some(box)
}

///|
/// Get the computed label bounding box
pub fn Edge::get_label_box(self : Edge) -> Box? {
  self.label_box
}
