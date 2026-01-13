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
  type GraphInput,
  type ObjectInput,
  type Point,
  type SequenceFragmentInput,
  type ShapeType,
  type StyleInput,
  type StyleValue,
}

///|
/// The main graph structure
#warnings("-unused_field")
priv struct Graph {
  name : String
  root : Object
  objects : Array[Object]
  edges : Array[Edge]
  /// Activation boxes for sequence diagrams (actor_id, bounding box)
  activation_boxes : Array[(String, Box)]
  /// Notes for sequence diagrams (actor_id, text, bounding box)
  sequence_notes : Array[(String, String, Box)]
  /// Sequence diagram fragments (combined fragments like alt, opt, loop)
  sequence_fragments : Array[SequenceFragment]
  /// Named layers - multiple diagram variants (for layers: {...})
  layers : Array[Layer]
  /// Named scenarios - diagram variations with base + delta (for scenarios: {...})
  scenarios : Array[Scenario]
  /// Named steps - animation frames (for steps: {...})
  steps : Array[Step]
  /// Legend configuration
  legend : @graph.LegendInput?
}

///|
/// A named layer in the diagram
#warnings("-unused_field")
priv struct Layer {
  name : String
  graph : Graph
}

///|
/// A scenario variant
#warnings("-unused_field")
priv struct Scenario {
  name : String
  graph : Graph
}

///|
/// An animation step
#warnings("-unused_field")
priv struct Step {
  name : String
  graph : Graph
}

///|
/// A sequence diagram combined fragment (alt, opt, loop, par, etc.)
#warnings("-unused_field")
priv struct SequenceFragment {
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
}

///|
/// An operand within a combined fragment (e.g., one branch of an "alt")
#warnings("-unused_field")
priv struct FragmentOperand {
  /// Condition for this operand (e.g., "[else]")
  condition : String?
  /// Y position of the operand separator line
  separator_y : Double
}

///|
fn SequenceFragment::new(
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
/// A node/shape in the diagram
#warnings("-unused_field")
priv struct Object {
  /// Unique identifier
  id : String
  /// Display label
  mut label : String
  /// Shape type
  shape_type : ShapeType
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
  icon : String?
  /// Tooltip text
  tooltip : String?
  /// Link URL
  link : String?
  /// CSS classes
  classes : Array[String]
  /// Grid layout: number of rows
  grid_rows : Int?
  /// Grid layout: number of columns
  grid_columns : Int?
  /// Grid layout: gap between cells
  grid_gap : Double?
  /// Grid layout: horizontal gap between cells
  horizontal_gap : Double?
  /// Grid layout: vertical gap between cells
  vertical_gap : Double?
  /// Grid cell spanning: number of columns this cell spans
  grid_column_span : Int?
  /// Grid cell spanning: number of rows this cell spans
  grid_row_span : Int?
  /// Near positioning: object ID or constant position (top-left, center, etc.)
  near : String?
}

///|
/// An edge/connection between objects
#warnings("-unused_field")
priv struct Edge {
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
  src_arrowhead : ArrowheadType
  /// Destination arrowhead type
  dst_arrowhead : ArrowheadType
  /// Source anchor position (top, bottom, left, right, center)
  src_anchor : String?
  /// Destination anchor position (top, bottom, left, right, center)
  dst_anchor : String?
  /// Edge label
  label : String
  /// Visual style
  style : Style
  /// Route points for the edge path
  route : Array[Point]
  /// User-specified bend points (excluding endpoints)
  bend_points : Array[Point]?
  /// Whether edge is curved
  is_curve : Bool
  /// Z-index for layering
  z_index : Int
  /// Number of times this edge is declared (for parallel rendering)
  reference_count : Int
  /// Computed label bounding box (for automatic label positioning)
  mut label_box : Box?
  /// Source SQL table column index (for field-level connections)
  src_column_index : Int?
  /// Destination SQL table column index (for field-level connections)
  dst_column_index : Int?
  /// Assigned source port (computed during port assignment phase)
  mut src_port : Port?
  /// Assigned destination port (computed during port assignment phase)
  mut dst_port : Port?
}

///|
/// Port side for edge connections
priv enum PortSide {
  Top
  Bottom
  Left
  Right
} derive(Eq)

///|
#warnings("-unused_field")
priv struct Port {
  /// Which side of the node this port is on
  side : PortSide
  /// Position along the side (0.0 = start, 1.0 = end)
  position : Double
  /// Computed absolute coordinates (filled after assignment)
  mut point : Point?
}

///|
/// Visual styling properties
#warnings("-unused_field")
priv struct Style {
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
  /// Text transformation: uppercase, lowercase, capitalize, none
  text_transform : StyleValue?
  /// Custom font family
  font_family : StyleValue?
  /// Fill pattern: dots, lines, cross-hatch, grain
  fill_pattern : StyleValue?
  /// Sketch mode: hand-drawn appearance
  sketch : StyleValue?
  /// Curved edges: use smooth bezier curves instead of straight lines
  curved : StyleValue?
}

// ============================================================================
// Constructors
// ============================================================================

///|
/// Materialize a mutable graph from immutable input.
fn Graph::from_input(input : GraphInput) -> Graph {
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
  let graph = {
    name: input.name,
    root,
    objects,
    edges,
    activation_boxes: input.activation_boxes,
    sequence_notes: input.sequence_notes,
    sequence_fragments: fragments,
    layers,
    scenarios,
    steps,
    legend: input.legend,
  }
  touch_graph_fields(graph)
  graph
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
fn touch_style_fields(style : Style) -> Unit {
  let _ = style.opacity
  let _ = style.stroke
  let _ = style.fill
  let _ = style.stroke_width
  let _ = style.stroke_dash
  let _ = style.border_radius
  let _ = style.shadow
  let _ = style.three_d
  let _ = style.multiple
  let _ = style.font
  let _ = style.font_size
  let _ = style.font_color
  let _ = style.bold
  let _ = style.italic
  let _ = style.underline
  let _ = style.animated
  let _ = style.filled
  let _ = style.double_border
  let _ = style.text_transform
  let _ = style.font_family
  let _ = style.fill_pattern
  let _ = style.sketch
  let _ = style.curved

}

///|
fn touch_object_fields(obj : Object) -> Unit {
  let _ = obj.z_index
  let _ = obj.icon
  let _ = obj.tooltip
  let _ = obj.link
  let _ = obj.classes
  touch_style_fields(obj.style)
}

///|
fn touch_edge_fields(edge : Edge) -> Unit {
  let _ = edge.src_arrow
  let _ = edge.dst_arrow
  let _ = edge.src_arrowhead
  let _ = edge.dst_arrowhead
  let _ = edge.is_curve
  let _ = edge.z_index
  let _ = edge.reference_count
  touch_style_fields(edge.style)
}

///|
fn touch_layer_fields(layer : Layer) -> Unit {
  let _ = layer.name
  let _ = layer.graph

}

///|
fn touch_scenario_fields(scenario : Scenario) -> Unit {
  let _ = scenario.name
  let _ = scenario.graph

}

///|
fn touch_step_fields(step : Step) -> Unit {
  let _ = step.name
  let _ = step.graph

}

///|
fn touch_graph_fields(graph : Graph) -> Unit {
  let _ = graph.name
  let _ = graph.legend
  for layer in graph.layers {
    touch_layer_fields(layer)
  }
  for scenario in graph.scenarios {
    touch_scenario_fields(scenario)
  }
  for step in graph.steps {
    touch_step_fields(step)
  }
  for obj in graph.objects {
    touch_object_fields(obj)
  }
  for edge in graph.edges {
    touch_edge_fields(edge)
  }
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
    route: input.route,
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
fn Graph::add_fragment(self : Graph, fragment : SequenceFragment) -> Unit {
  self.sequence_fragments.push(fragment)
}

///|
fn Layer::new(name : String, graph : Graph) -> Layer {
  { name, graph }
}

///|
fn Scenario::new(name : String, graph : Graph) -> Scenario {
  { name, graph }
}

///|
fn Step::new(name : String, graph : Graph) -> Step {
  { name, graph }
}

///|
fn Object::new(id : String) -> Object {
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
fn Edge::new(
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
fn Port::new(side : PortSide, position : Double) -> Port {
  { side, position, point: None }
}

///|
fn Style::new() -> Style {
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
fn Graph::add_object(self : Graph, obj : Object) -> Unit {
  self.objects.push(obj)
}

///|
/// Add an edge to the graph
fn Graph::add_edge(self : Graph, edge : Edge) -> Unit {
  self.edges.push(edge)
}

///|
/// Find an object by ID
fn Graph::find_object(self : Graph, id : String) -> Object? {
  for obj in self.objects {
    if obj.id == id {
      return Some(obj)
    }
  }
  None
}

// ============================================================================
// Object operations
// ============================================================================

///|
/// Check if this object is a grid diagram (has grid-rows or grid-columns)
fn Object::is_grid_diagram(self : Object) -> Bool {
  self.grid_rows is Some(_) || self.grid_columns is Some(_)
}

///|
/// Check if this object is a container
fn Object::is_container(self : Object) -> Bool {
  not(self.children.is_empty())
}

// ============================================================================
// Edge operations
// ============================================================================

///|
/// Add a point to the route
fn Edge::add_route_point(self : Edge, p : Point) -> Unit {
  self.route.push(p)
}

///|
/// Get the midpoint of the edge route
fn Edge::midpoint(self : Edge) -> Point? {
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
