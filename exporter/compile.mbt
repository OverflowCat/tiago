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
/// Compile IR to Graph
///
/// Converts the IR representation into a Graph suitable for
/// layout and rendering.

///|
priv struct Style {
  mut opacity : Double?
  mut stroke : String?
  mut fill : String?
  mut stroke_width : Double?
  mut stroke_dash : Double?
  mut border_radius : Double?
  mut shadow : Bool?
  mut three_d : Bool?
  mut multiple : Bool?
  mut font : String?
  mut font_size : Int?
  mut font_color : String?
  mut bold : Bool?
  mut italic : Bool?
  mut underline : Bool?
  mut animated : Bool?
  mut filled : Bool?
  mut double_border : Bool?
  mut text_transform : String?
  mut font_family : String?
  mut fill_pattern : String?
  mut sketch : Bool?
  mut curved : Bool?
} derive(Show)

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

///|
priv struct Object {
  id : String
  id_val : String
  id_syntax : String
  abs_id_syntax : String
  mut references : Array[@graph.ObjectReference]
  mut label : String
  mut shape_type : ShapeType
  mut raw_shape : String?
  style : Style
  children : Array[Object]
  z_index : Int
  mut icon : String?
  mut icon_position : String?
  mut tooltip : String?
  mut tooltip_position : String?
  mut link : String?
  mut label_position : String?
  classes : Array[String]
  mut language : String?
  sql_constraints : Array[String]
  mut width : Double?
  mut height : Double?
  mut grid_rows : Int?
  mut grid_columns : Int?
  mut grid_gap : Double?
  mut horizontal_gap : Double?
  mut vertical_gap : Double?
  mut grid_column_span : Int?
  mut grid_row_span : Int?
  mut near : String?
  mut top : Int?
  mut left : Int?
  mut direction : String?
} derive(Show)

///|
fn Object::new(
  id : String,
  id_val? : String = id,
  id_syntax? : String = id,
  abs_id_syntax? : String = id,
) -> Object {
  {
    id,
    id_val,
    id_syntax,
    abs_id_syntax,
    references: [],
    label: id_val,
    shape_type: Rectangle,
    raw_shape: None,
    style: Style::new(),
    children: [],
    z_index: 0,
    icon: None,
    icon_position: None,
    tooltip: None,
    tooltip_position: None,
    link: None,
    label_position: None,
    classes: [],
    language: None,
    sql_constraints: [],
    width: None,
    height: None,
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
    direction: None,
  }
}

///|
fn Object::add_child(self : Object, child : Object) -> Unit {
  self.children.push(child)
}

///|
priv struct Edge {
  index : Int
  src_id : String
  dst_id : String
  src_id_syntax : String
  dst_id_syntax : String
  mut references : Array[@graph.EdgeReference]
  src_arrow : Bool
  dst_arrow : Bool
  mut src_arrowhead : ArrowheadType
  mut dst_arrowhead : ArrowheadType
  mut src_arrowhead_label : String?
  mut dst_arrowhead_label : String?
  mut src_arrowhead_label_color : String?
  mut dst_arrowhead_label_color : String?
  mut src_anchor : String?
  mut dst_anchor : String?
  mut label : String
  style : Style
  mut bend_points : Array[Point]?
  is_curve : Bool
  z_index : Int
  mut reference_count : Int
  src_column_index : Int?
  dst_column_index : Int?
} derive(Show)

///|
fn Edge::new(
  index : Int,
  src_id : String,
  dst_id : String,
  src_arrow : Bool,
  dst_arrow : Bool,
  src_id_syntax? : String = src_id,
  dst_id_syntax? : String = dst_id,
) -> Edge {
  {
    index,
    src_id,
    dst_id,
    src_id_syntax,
    dst_id_syntax,
    references: [],
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
    src_arrowhead_label: None,
    dst_arrowhead_label: None,
    src_arrowhead_label_color: None,
    dst_arrowhead_label_color: None,
    src_anchor: None,
    dst_anchor: None,
    label: "",
    style: Style::new(),
    bend_points: None,
    is_curve: false,
    z_index: 0,
    reference_count: 1,
    src_column_index: None,
    dst_column_index: None,
  }
}

///|
priv enum LegendEntry {
  ShapeEntry(shape~ : ShapeType, label~ : String, style~ : Style?)
  ConnectionEntry(
    src_arrow~ : ArrowheadType,
    dst_arrow~ : ArrowheadType,
    label~ : String,
    style~ : Style?
  )
  CustomEntry(icon~ : String, label~ : String)
  Separator
} derive(Show)

///|
fn LegendEntry::shape(
  shape : ShapeType,
  label : String,
  style : Style?,
) -> LegendEntry {
  ShapeEntry(shape~, label~, style~)
}

///|
fn LegendEntry::connection(
  src_arrow : ArrowheadType,
  dst_arrow : ArrowheadType,
  label : String,
  style : Style?,
) -> LegendEntry {
  ConnectionEntry(src_arrow~, dst_arrow~, label~, style~)
}

///|
fn LegendEntry::custom(icon : String, label : String) -> LegendEntry {
  CustomEntry(icon~, label~)
}

///|
fn LegendEntry::separator() -> LegendEntry {
  Separator
}

///|
priv struct Legend {
  mut title : String?
  mut position : LegendPosition
  entries : Array[LegendEntry]
  mut fill : String?
  mut stroke : String?
  mut padding : Double
  mut entry_gap : Double
  mut icon_size : Double
} derive(Show)

///|
fn Legend::new() -> Legend {
  {
    title: None,
    position: BottomRight,
    entries: [],
    fill: Some("#ffffff"),
    stroke: Some("#DEE1EB"),
    padding: 20.0,
    entry_gap: 15.0,
    icon_size: 24.0,
  }
}

///|
fn Legend::with_position(position : LegendPosition) -> Legend {
  let legend = Legend::new()
  legend.position = position
  legend
}

///|
fn Legend::add_entry(self : Legend, entry : LegendEntry) -> Unit {
  self.entries.push(entry)
}

///|
fn Legend::set_title(self : Legend, title : String) -> Unit {
  self.title = Some(title)
}

///|
fn Legend::set_fill(self : Legend, fill : String) -> Unit {
  self.fill = Some(fill)
}

///|
fn Legend::set_stroke(self : Legend, stroke : String) -> Unit {
  self.stroke = Some(stroke)
}

///|
fn Legend::set_padding(self : Legend, padding : Double) -> Unit {
  self.padding = padding
}

///|
fn Legend::set_entry_gap(self : Legend, entry_gap : Double) -> Unit {
  self.entry_gap = entry_gap
}

///|
fn Legend::set_icon_size(self : Legend, icon_size : Double) -> Unit {
  self.icon_size = icon_size
}

///|
priv struct Graph {
  name : String
  root : Object
  objects : Array[Object]
  edges : Array[Edge]
  layers : Array[Layer]
  scenarios : Array[Scenario]
  steps : Array[Step]
  mut legend : Legend?
  mut is_folder_only : Bool
} derive(Show)

///|
priv struct Layer {
  name : String
  graph : Graph
} derive(Show)

///|
priv struct Scenario {
  name : String
  graph : Graph
} derive(Show)

///|
priv struct Step {
  name : String
  graph : Graph
} derive(Show)

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
fn Graph::new(name : String) -> Graph {
  let root = Object::new("root")
  {
    name,
    root,
    objects: [],
    edges: [],
    layers: [],
    scenarios: [],
    steps: [],
    legend: None,
    is_folder_only: false,
  }
}

///|
fn Graph::add_object(self : Graph, obj : Object) -> Unit {
  self.objects.push(obj)
}

///|
fn Graph::add_edge(self : Graph, edge : Edge) -> Unit {
  self.edges.push(edge)
}

///|
fn Graph::add_layer(self : Graph, layer : Layer) -> Unit {
  self.layers.push(layer)
}

///|
fn Graph::add_scenario(self : Graph, scenario : Scenario) -> Unit {
  self.scenarios.push(scenario)
}

///|
fn Graph::add_step(self : Graph, step : Step) -> Unit {
  self.steps.push(step)
}

///|
fn Graph::set_legend(self : Graph, legend : Legend) -> Unit {
  self.legend = Some(legend)
}

///|
fn style_to_input(style : Style) -> @graph.StyleInput {
  @graph.StyleInput::from_parts(
    @graph.StyleValue::from_double_opt(style.opacity),
    @graph.StyleValue::from_string_opt(style.stroke),
    @graph.StyleValue::from_string_opt(style.fill),
    @graph.StyleValue::from_double_opt(style.stroke_width),
    @graph.StyleValue::from_double_opt(style.stroke_dash),
    @graph.StyleValue::from_double_opt(style.border_radius),
    @graph.StyleValue::from_bool_opt(style.shadow),
    @graph.StyleValue::from_bool_opt(style.three_d),
    @graph.StyleValue::from_bool_opt(style.multiple),
    @graph.StyleValue::from_string_opt(style.font),
    @graph.StyleValue::from_int_opt(style.font_size),
    @graph.StyleValue::from_string_opt(style.font_color),
    @graph.StyleValue::from_bool_opt(style.bold),
    @graph.StyleValue::from_bool_opt(style.italic),
    @graph.StyleValue::from_bool_opt(style.underline),
    @graph.StyleValue::from_bool_opt(style.animated),
    @graph.StyleValue::from_bool_opt(style.filled),
    @graph.StyleValue::from_bool_opt(style.double_border),
    @graph.StyleValue::from_string_opt(style.text_transform),
    @graph.StyleValue::from_string_opt(style.font_family),
    @graph.StyleValue::from_string_opt(style.fill_pattern),
    @graph.StyleValue::from_bool_opt(style.sketch),
    @graph.StyleValue::from_bool_opt(style.curved),
  )
}

///|
fn legend_entry_to_input(entry : LegendEntry) -> @graph.LegendEntryInput {
  match entry {
    ShapeEntry(shape~, label~, style~) => {
      let style_input = match style {
        Some(s) => Some(style_to_input(s))
        None => None
      }
      @graph.LegendEntryInput::shape(shape, label, style_input)
    }
    ConnectionEntry(src_arrow~, dst_arrow~, label~, style~) => {
      let style_input = match style {
        Some(s) => Some(style_to_input(s))
        None => None
      }
      @graph.LegendEntryInput::connection(
        src_arrow, dst_arrow, label, style_input,
      )
    }
    CustomEntry(icon~, label~) => @graph.LegendEntryInput::custom(icon, label)
    Separator => @graph.LegendEntryInput::separator()
  }
}

///|
fn legend_to_input(legend : Legend) -> @graph.LegendInput {
  let entries : Array[@graph.LegendEntryInput] = []
  for entry in legend.entries {
    entries.push(legend_entry_to_input(entry))
  }
  @graph.LegendInput::from_parts(
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

///|
fn object_to_input(obj : Object) -> @graph.ObjectInput {
  let child_ids : Array[String] = []
  for child in obj.children {
    child_ids.push(child.abs_id_syntax)
  }
  let classes : Array[String] = []
  for c in obj.classes {
    classes.push(c)
  }
  let sql_constraints : Array[String] = []
  for constraint in obj.sql_constraints {
    sql_constraints.push(constraint)
  }
  let references : Array[@graph.ObjectReference] = []
  for reference in obj.references {
    references.push(reference)
  }
  let box = match (obj.width, obj.height) {
    (None, None) => None
    (Some(w), Some(h)) => Some(@graph.Box::new(0.0, 0.0, w, h))
    (Some(w), None) => Some(@graph.Box::new(0.0, 0.0, w, 0.0))
    (None, Some(h)) => Some(@graph.Box::new(0.0, 0.0, 0.0, h))
  }
  @graph.ObjectInput::from_parts(
    obj.id,
    obj.label,
    obj.shape_type,
    style_to_input(obj.style),
    box,
    None,
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
    direction=obj.direction,
    language=obj.language,
    sql_constraints~,
    id_val=obj.id_val,
    id_syntax=obj.id_syntax,
    abs_id_syntax=obj.abs_id_syntax,
    references~,
    icon_position=obj.icon_position,
    tooltip_position=obj.tooltip_position,
    label_position=obj.label_position,
  )
}

///|
fn edge_to_input(edge : Edge) -> @graph.EdgeInput {
  let effective_src_arrowhead = if edge.src_arrow {
    edge.src_arrowhead
  } else {
    None
  }
  let effective_dst_arrowhead = if edge.dst_arrow {
    edge.dst_arrowhead
  } else {
    None
  }
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
  let references : Array[@graph.EdgeReference] = []
  for reference in edge.references {
    references.push(reference)
  }
  @graph.EdgeInput::from_parts(
    edge.index,
    edge.src_id,
    edge.dst_id,
    edge.src_arrow,
    edge.dst_arrow,
    effective_src_arrowhead,
    effective_dst_arrowhead,
    edge.src_arrowhead_label,
    edge.dst_arrowhead_label,
    edge.src_arrowhead_label_color,
    edge.dst_arrowhead_label_color,
    edge.src_anchor,
    edge.dst_anchor,
    edge.label,
    style_to_input(edge.style),
    [],
    bend_points,
    edge.is_curve,
    edge.z_index,
    edge.reference_count,
    None,
    edge.src_column_index,
    edge.dst_column_index,
    src_id_syntax=edge.src_id_syntax,
    dst_id_syntax=edge.dst_id_syntax,
    references~,
  )
}

///|
fn compare_reference_ranges(a : @lexer.Range, b : @lexer.Range) -> Int {
  if a.path != b.path {
    return a.path.compare(b.path)
  }
  if a.start.offset != b.start.offset {
    return a.start.offset - b.start.offset
  }
  if a.end.offset != b.end.offset {
    return a.end.offset - b.end.offset
  }
  0
}

///|
fn sort_object_array_by_references(objects : Array[Object]) -> Unit {
  let original_index_by_id : Map[String, Int] = {}
  for i, obj in objects {
    original_index_by_id[obj.abs_id_syntax] = i
  }
  objects.sort_by(fn(a, b) {
    let cmp = if a.references.length() > 0 && b.references.length() > 0 {
      compare_reference_ranges(a.references[0].range, b.references[0].range)
    } else {
      0
    }
    if cmp != 0 {
      return cmp
    }
    original_index_by_id.get_or_default(a.abs_id_syntax, 0) -
    original_index_by_id.get_or_default(b.abs_id_syntax, 0)
  })
}

///|
fn sort_edge_array_by_references(edges : Array[Edge]) -> Unit {
  let original_index_by_edge : Map[Int, Int] = {}
  for i, edge in edges {
    original_index_by_edge[edge.index] = i
  }
  edges.sort_by(fn(a, b) {
    let cmp = if a.references.length() > 0 && b.references.length() > 0 {
      compare_reference_ranges(a.references[0].range, b.references[0].range)
    } else {
      0
    }
    if cmp != 0 {
      return cmp
    }
    original_index_by_edge.get_or_default(a.index, 0) -
    original_index_by_edge.get_or_default(b.index, 0)
  })
}

///|
fn sort_children_by_references(obj : Object) -> Unit {
  sort_object_array_by_references(obj.children)
  for child in obj.children {
    sort_children_by_references(child)
  }
}

///|
fn sort_graph_by_references(graph : Graph) -> Unit {
  sort_object_array_by_references(graph.objects)
  sort_edge_array_by_references(graph.edges)
  sort_children_by_references(graph.root)
  for obj in graph.objects {
    sort_children_by_references(obj)
  }
  for layer in graph.layers {
    sort_graph_by_references(layer.graph)
  }
  for scenario in graph.scenarios {
    sort_graph_by_references(scenario.graph)
  }
  for step in graph.steps {
    sort_graph_by_references(step.graph)
  }
}

///|
fn graph_to_input(graph : Graph) -> @graph.GraphInput {
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    objects.push(object_to_input(obj))
  }
  let nested_child_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    for child in obj.children {
      nested_child_ids[child.abs_id_syntax] = true
    }
  }
  let root_child_ids : Array[String] = []
  for obj in graph.objects {
    if !nested_child_ids.contains(obj.abs_id_syntax) {
      root_child_ids.push(obj.abs_id_syntax)
    }
  }
  let root_classes : Array[String] = []
  for c in graph.root.classes {
    root_classes.push(c)
  }
  let root_sql_constraints : Array[String] = []
  for constraint in graph.root.sql_constraints {
    root_sql_constraints.push(constraint)
  }
  let root_references : Array[@graph.ObjectReference] = []
  for reference in graph.root.references {
    root_references.push(reference)
  }
  let root_box = match (graph.root.width, graph.root.height) {
    (None, None) => None
    (Some(w), Some(h)) => Some(@graph.Box::new(0.0, 0.0, w, h))
    (Some(w), None) => Some(@graph.Box::new(0.0, 0.0, w, 0.0))
    (None, Some(h)) => Some(@graph.Box::new(0.0, 0.0, 0.0, h))
  }
  let root = @graph.ObjectInput::from_parts(
    graph.root.id,
    graph.root.label,
    graph.root.shape_type,
    style_to_input(graph.root.style),
    root_box,
    None,
    root_child_ids,
    graph.root.z_index,
    graph.root.icon,
    graph.root.tooltip,
    graph.root.link,
    root_classes,
    graph.root.grid_rows,
    graph.root.grid_columns,
    graph.root.grid_gap,
    graph.root.horizontal_gap,
    graph.root.vertical_gap,
    graph.root.grid_column_span,
    graph.root.grid_row_span,
    graph.root.near,
    graph.root.top,
    graph.root.left,
    direction=graph.root.direction,
    language=graph.root.language,
    sql_constraints=root_sql_constraints,
    id_val=graph.root.id_val,
    id_syntax=graph.root.id_syntax,
    abs_id_syntax=graph.root.abs_id_syntax,
    references=root_references,
  )
  let edges : Array[@graph.EdgeInput] = []
  for e in graph.edges {
    edges.push(edge_to_input(e))
  }
  let layers : Array[@graph.LayerInput] = []
  for layer in graph.layers {
    layers.push(@graph.LayerInput::new(layer.name, graph_to_input(layer.graph)))
  }
  let scenarios : Array[@graph.ScenarioInput] = []
  for scenario in graph.scenarios {
    scenarios.push(
      @graph.ScenarioInput::new(scenario.name, graph_to_input(scenario.graph)),
    )
  }
  let steps : Array[@graph.StepInput] = []
  for step in graph.steps {
    steps.push(@graph.StepInput::new(step.name, graph_to_input(step.graph)))
  }
  let legend = match graph.legend {
    Some(l) => Some(legend_to_input(l))
    None => None
  }
  @graph.GraphInput::from_parts(
    graph.name,
    root,
    objects,
    edges,
    [],
    [],
    [],
    [],
    layers,
    scenarios,
    steps,
    legend,
    is_folder_only=graph.is_folder_only,
  )
}

///|
/// Compilation error
pub(all) suberror GraphCompileError {
  InvalidShape(String)
  InvalidStyle(String)
  MissingObject(String)
  Semantic(String)
} derive(Eq, Show)

///|
/// Compile an IR Map to GraphInput
pub fn compile(
  name : String,
  ir : @ir.Map,
) -> @graph.GraphInput raise GraphCompileError {
  let graph = Graph::new(name)
  let classes = extract_classes(ir)
  compile_board_graph(graph, ir, classes)
  canonicalize_board_links_recursive(graph, graph, ["root"])
  // D2 parity: SQL table column endpoints are represented as table endpoints
  // with source/target column indices.
  normalize_sql_table_edge_endpoints_recursive(graph)
  // Semantic validation pass aligned with D2 compiler behavior.
  validate_semantics(graph)
  // D2 parity: preserve source order using object and edge references.
  sort_graph_by_references(graph)
  graph_to_input(graph)
}

///|
/// Extract class definitions from the IR
fn extract_classes(ir : @ir.Map) -> Map[String, @ir.Map] {
  let classes : Map[String, @ir.Map] = {}
  match ir.get_field("classes") {
    Some(f) =>
      match f.composite {
        Some(@ir.Composite::Map(classes_map)) =>
          for field in classes_map.fields {
            match field.composite {
              Some(@ir.Composite::Map(class_def)) =>
                classes[field.name] = class_def
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
  classes
}

///|
/// Compile a board graph and all nested boards.
fn compile_board_graph(
  graph : Graph,
  ir : @ir.Map,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  compile_objects(graph, ir, "", "", classes)
  compile_edges(graph, ir)
  compile_layers(graph, ir, classes)
  compile_scenarios(graph, ir, classes)
  compile_steps(graph, ir, classes)
  handle_root_shape(graph, ir)
  apply_d2_text_defaults(graph)
  apply_sequence_defaults(graph)
  apply_d2_color_defaults(graph)
  compile_legend(graph, ir, classes)
  if graph.objects.is_empty() {
    graph.is_folder_only = true
  }
}

///|
fn compile_boards_field(
  graph : Graph,
  ir : @ir.Map,
  classes : Map[String, @ir.Map],
  field_name : String,
  inherit_base : Bool,
) -> Unit raise GraphCompileError {
  match ir.get_field(field_name) {
    Some(board_field_container) =>
      match board_field_container.composite {
        Some(@ir.Composite::Map(boards_map)) =>
          for board_field in boards_map.fields {
            if has_board_name(graph, board_field.name) {
              raise Semantic(
                "board name \{board_field.name} already used by another board",
              )
            }
            let board_ir = compile_board_ir(ir, board_field, inherit_base)
            let board_graph = Graph::new(board_field.name)
            compile_board_graph(board_graph, board_ir, classes)
            apply_board_primary_label(board_graph, board_field)
            add_board(graph, field_name, board_field.name, board_graph)
          }
        _ => ()
      }
    None => ()
  }
}

///|
fn compile_board_ir(
  current_ir : @ir.Map,
  board_field : @ir.Field,
  inherit_base : Bool,
) -> @ir.Map {
  let overlay = match board_field.composite {
    Some(@ir.Composite::Map(board_ir)) => board_ir.copy()
    _ => @ir.Map::new()
  }
  if !inherit_base {
    return overlay
  }
  inheritable_board_ir(current_ir).overlay(overlay)
}

///|
fn inheritable_board_ir(ir : @ir.Map) -> @ir.Map {
  let inherited = ir.copy()
  let _ = inherited.delete_field("label")
  let _ = inherited.delete_field("layers")
  let _ = inherited.delete_field("scenarios")
  let _ = inherited.delete_field("steps")
  inherited
}

///|
fn apply_board_primary_label(graph : Graph, board_field : @ir.Field) -> Unit {
  match board_field.primary {
    Some(s) => set_object_label_from_scalar(graph.root, s)
    None => ()
  }
}

///|
fn add_board(
  graph : Graph,
  field_name : String,
  board_name : String,
  board_graph : Graph,
) -> Unit {
  match field_name {
    "layers" => graph.add_layer(Layer::new(board_name, board_graph))
    "scenarios" => graph.add_scenario(Scenario::new(board_name, board_graph))
    "steps" => graph.add_step(Step::new(board_name, board_graph))
    _ => ()
  }
}

///|
fn has_board_name(graph : Graph, board_name : String) -> Bool {
  for layer in graph.layers {
    if layer.name == board_name {
      return true
    }
  }
  for scenario in graph.scenarios {
    if scenario.name == board_name {
      return true
    }
  }
  for step in graph.steps {
    if step.name == board_name {
      return true
    }
  }
  false
}

///|
fn canonicalize_board_links_recursive(
  graph : Graph,
  root_graph : Graph,
  board_path : Array[String],
) -> Unit {
  for obj in graph.objects {
    canonicalize_object_board_links(obj, root_graph, board_path)
  }
  for layer in graph.layers {
    canonicalize_board_links_recursive(
      layer.graph,
      root_graph,
      append_board_path(board_path, "layers", layer.name),
    )
  }
  for scenario in graph.scenarios {
    canonicalize_board_links_recursive(
      scenario.graph,
      root_graph,
      append_board_path(board_path, "scenarios", scenario.name),
    )
  }
  for step in graph.steps {
    canonicalize_board_links_recursive(
      step.graph,
      root_graph,
      append_board_path(board_path, "steps", step.name),
    )
  }
}

///|
fn canonicalize_object_board_links(
  obj : Object,
  root_graph : Graph,
  board_path : Array[String],
) -> Unit {
  match obj.link {
    Some(link) =>
      obj.link = canonicalize_board_link(link, root_graph, board_path)
    None => ()
  }
  for child in obj.children {
    canonicalize_object_board_links(child, root_graph, board_path)
  }
}

///|
fn canonicalize_board_link(
  link : String,
  root_graph : Graph,
  board_path : Array[String],
) -> String? {
  if is_remote_or_absolute_link(link) {
    return Some(link)
  }
  let key_path = match @parser.parse_key_path(link) {
    Ok(key_path) => key_path
    Err(_) => return Some(link)
  }
  let path = board_link_path_segments(key_path)
  if path.is_empty() {
    return Some(link)
  }
  let resolved_path = if is_relative_board_link_path(path) {
    match resolve_relative_board_link_path(path, board_path) {
      Some(resolved_path) => resolved_path
      None => return None
    }
  } else {
    path
  }
  if !is_root_board_link_path(resolved_path) {
    return None
  }
  if !has_board_path(root_graph, resolved_path, 0) {
    return None
  }
  if board_path_matches_link_path(board_path, resolved_path) {
    return None
  }
  Some(format_board_link_path(resolved_path))
}

///|
fn append_board_path(
  board_path : Array[String],
  board_kind : String,
  board_name : String,
) -> Array[String] {
  let next : Array[String] = []
  for segment in board_path {
    next.push(segment)
  }
  next.push(board_kind)
  next.push(board_name)
  next
}

///|
fn board_link_path_segments(key_path : @ast.KeyPath) -> Array[(String, Bool)] {
  let path : Array[(String, Bool)] = []
  for segment in key_path.path {
    let unquoted = match segment {
      @ast.StringValue::Unquoted(_) => true
      _ => false
    }
    let value = normalize_board_link_segment_value(segment.content(), unquoted)
    path.push((value, unquoted))
  }
  path
}

///|
fn normalize_board_link_segment_value(
  value : String,
  unquoted : Bool,
) -> String {
  if !unquoted {
    return value
  }
  let lower = value.to_lower()
  if lower == "root" ||
    lower == "layers" ||
    lower == "scenarios" ||
    lower == "steps" ||
    lower == "_" {
    lower
  } else {
    value
  }
}

///|
fn is_relative_board_link_path(path : Array[(String, Bool)]) -> Bool {
  if path.is_empty() {
    return false
  }
  let (head, unquoted) = path[0]
  unquoted &&
  (head == "layers" || head == "scenarios" || head == "steps" || head == "_")
}

///|
fn resolve_relative_board_link_path(
  path : Array[(String, Bool)],
  board_path : Array[String],
) -> Array[(String, Bool)]? {
  let resolved : Array[String] = []
  for segment in board_path {
    resolved.push(segment)
  }
  let mut index = 0
  while index < path.length() {
    let (segment, unquoted) = path[index]
    if segment == "_" && unquoted {
      if resolved.length() < 2 {
        return None
      }
      ignore(resolved.pop())
      ignore(resolved.pop())
      index += 1
      continue
    }
    break
  }
  let out : Array[(String, Bool)] = []
  for segment in resolved {
    out.push((segment, true))
  }
  for i = index; i < path.length(); i = i + 1 {
    let (segment, unquoted) = path[i]
    out.push((segment, unquoted))
  }
  Some(out)
}

///|
fn is_root_board_link_path(path : Array[(String, Bool)]) -> Bool {
  if path.is_empty() {
    return false
  }
  let (head, unquoted) = path[0]
  head == "root" && unquoted
}

///|
fn has_board_path(
  graph : Graph,
  path : Array[(String, Bool)],
  index : Int,
) -> Bool {
  if index >= path.length() {
    return true
  }
  let (head, head_unquoted) = path[index]
  if head == "root" && head_unquoted {
    return has_board_path(graph, path, index + 1)
  }
  if index == path.length() - 1 {
    return graph.name == head
  }
  if !head_unquoted || index + 1 >= path.length() {
    return false
  }
  let (board_name, _) = path[index + 1]
  match head {
    "layers" => {
      for layer in graph.layers {
        if layer.name == board_name {
          return has_board_path(layer.graph, path, index + 2)
        }
      }
      false
    }
    "scenarios" => {
      for scenario in graph.scenarios {
        if scenario.name == board_name {
          return has_board_path(scenario.graph, path, index + 2)
        }
      }
      false
    }
    "steps" => {
      for step in graph.steps {
        if step.name == board_name {
          return has_board_path(step.graph, path, index + 2)
        }
      }
      false
    }
    _ => false
  }
}

///|
fn board_path_matches_link_path(
  board_path : Array[String],
  link_path : Array[(String, Bool)],
) -> Bool {
  if board_path.length() != link_path.length() {
    return false
  }
  for i = 0; i < board_path.length(); i = i + 1 {
    let (segment, _) = link_path[i]
    if board_path[i] != segment {
      return false
    }
  }
  true
}

///|
fn format_board_link_path(path : Array[(String, Bool)]) -> String {
  let buf = StringBuilder::new()
  for i, entry in path {
    let (segment, _) = entry
    if i > 0 {
      buf.write_char('.')
    }
    if i == 0 {
      buf.write_string("root")
    } else if i % 2 == 1 {
      buf.write_string(segment.to_lower())
    } else {
      buf.write_string(d2_format_board_name_segment(segment))
    }
  }
  buf.to_string()
}

///|
fn d2_format_board_name_segment(s : String) -> String {
  if s.length() == 0 {
    return "\"\""
  }
  let key_specials = "#;\n\\{}[]'\"|:.-<>*&()@&"
  let chars = s.to_array()
  for i, r in chars {
    if r == '-' {
      if i + 1 < chars.length() && chars[i + 1] != '-' {
        continue
      }
    }
    if d2_contains_char(key_specials, r) {
      return d2_quote_key_segment(s)
    }
  }
  if d2_has_surrounding_whitespace(s) || d2_is_reserved_for_unquoted_key(s) {
    return d2_quote_key_segment(s)
  }
  d2_escape_unquoted_key_value(s)
}

///|
fn d2_quote_key_segment(s : String) -> String {
  if !d2_contains_char(s, '"') || d2_contains_char(s, '\n') {
    "\"\{d2_escape_double_quoted_value(s)}\""
  } else {
    "'\{d2_escape_single_quoted_value(s)}'"
  }
}

///|
fn is_remote_or_absolute_link(s : String) -> Bool {
  if s.has_prefix("/") {
    return true
  }
  match string_index_of_char(s, ':') {
    Some(index) => index > 0 && is_uri_scheme(s[:index].to_string())
    None => false
  }
}

///|
fn string_index_of_char(s : String, target : Char) -> Int? {
  let mut index = 0
  for ch in s {
    if ch == target {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn is_uri_scheme(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  let chars = s.to_array()
  if !is_ascii_alpha(chars[0]) {
    return false
  }
  for i = 1; i < chars.length(); i = i + 1 {
    let ch = chars[i]
    if !is_ascii_alpha(ch) &&
      !is_ascii_digit(ch) &&
      ch != '+' &&
      ch != '-' &&
      ch != '.' {
      return false
    }
  }
  true
}

///|
fn is_ascii_alpha(ch : Char) -> Bool {
  ('a' <= ch && ch <= 'z') || ('A' <= ch && ch <= 'Z')
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  '0' <= ch && ch <= '9'
}

///|
fn compile_objects(
  graph : Graph,
  ir : @ir.Map,
  prefix : String,
  prefix_syntax : String,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  for field in ir.fields {
    // Skip reserved keywords (like 'classes', 'vars', etc.)
    if field.is_reserved_keyword_name() {
      continue
    }
    let id_val = field.name
    let id_syntax = d2_format_key_segment(id_val)
    let id = if prefix == "" { id_val } else { "\{prefix}.\{id_val}" }
    let abs_id_syntax = if prefix_syntax == "" {
      id_syntax
    } else {
      "\{prefix_syntax}.\{id_syntax}"
    }
    let obj = Object::new(id, id_val~, id_syntax~, abs_id_syntax~)
    obj.references = object_references_from_field(
      field,
      graph.root.abs_id_syntax,
    )
    // Set label from primary value
    match field.primary {
      Some(scalar) => set_object_label_from_scalar(obj, scalar)
      None => ()
    }
    // Process composite (nested objects)
    match field.composite {
      Some(@ir.Composite::Map(inner)) => {
        // Apply class properties first (if specified)
        apply_class(obj, inner, classes)
        // Check for special fields (can override class)
        validate_board_root_scope(inner)
        process_special_fields(obj, inner)
        // D2 registers objects in encounter order before descending.
        graph.add_object(obj)
        // Recursively compile children
        compile_children(graph, obj, inner, id, abs_id_syntax, classes)
      }
      _ => graph.add_object(obj)
    }
  }
}

///|
fn class_names_from_field(class_field : @ir.Field) -> Array[String] {
  let class_names : Array[String] = []
  match class_field.primary {
    Some(s) => class_names.push(s.to_string())
    None => ()
  }
  match class_field.composite {
    Some(@ir.Composite::Array(arr)) =>
      for value in arr.values {
        match value {
          @ir.Value::Scalar(s) => class_names.push(s.to_string())
          _ => ()
        }
      }
    _ => ()
  }
  class_names
}

///|
/// Apply class properties to an object
fn apply_class(
  obj : Object,
  ir : @ir.Map,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  match ir.get_field("class") {
    Some(class_field) =>
      for class_name in class_names_from_field(class_field) {
        obj.classes.push(class_name)
        match classes.get(class_name) {
          Some(class_def) => {
            validate_board_root_scope(class_def)
            process_special_fields(obj, class_def)
          }
          None => ()
        }
      }
    None => ()
  }
}

///|
fn compile_children(
  graph : Graph,
  parent : Object,
  ir : @ir.Map,
  prefix : String,
  prefix_syntax : String,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  for field in ir.fields {
    // Skip reserved keywords
    if field.is_reserved_keyword_name() {
      continue
    }
    let id_val = field.name
    let id_syntax = d2_format_key_segment(id_val)
    let id = "\{prefix}.\{id_val}"
    let abs_id_syntax = "\{prefix_syntax}.\{id_syntax}"
    let child = Object::new(id, id_val~, id_syntax~, abs_id_syntax~)
    child.references = object_references_from_field(field, parent.abs_id_syntax)
    // Set label - use field name as default, or primary value if provided
    match field.primary {
      Some(scalar) => set_object_label_from_scalar(child, scalar)
      None => child.label = field.name // Use field name, not full path
    }
    // Process nested composites
    match field.composite {
      Some(@ir.Composite::Map(inner)) => {
        // Apply class properties first (if specified)
        apply_class(child, inner, classes)
        // Check for special fields (can override class)
        validate_board_root_scope(inner)
        process_special_fields(child, inner)
        if parent.shape_type == ShapeType::SqlTable {
          let constraints = extract_sql_constraints(inner)
          for c in constraints {
            if c.length() > 0 {
              child.sql_constraints.push(c)
              child.classes.push("sql_constraint:" + c)
            }
          }
        }
        parent.add_child(child)
        graph.add_object(child)
        // Recursively compile children
        compile_children(graph, child, inner, id, abs_id_syntax, classes)
      }
      _ => {
        parent.add_child(child)
        graph.add_object(child)
      }
    }
  }
}

///|
fn set_object_label_from_scalar(obj : Object, scalar : @ir.Scalar) -> Unit {
  obj.label = scalar.to_string()
  match scalar.block_string_tag() {
    Some(tag_raw) => {
      let tag = normalize_block_string_language(tag_raw)
      if tag.length() > 0 {
        set_object_language(obj, Some(tag))
        if tag == "latex" || tag == "markdown" {
          // D2 parity: markdown/latex default to text shape unless explicitly overridden.
          obj.shape_type = ShapeType::Text
        } else {
          obj.shape_type = ShapeType::Code
        }
      }
    }
    None => ()
  }
}

///|
fn normalize_block_string_language(tag : String) -> String {
  match tag.to_lower() {
    "js" => "javascript"
    "go" => "golang"
    "py" => "python"
    "rb" => "ruby"
    "ts" => "typescript"
    "tex" => "latex"
    "md" => "markdown"
    other => other
  }
}

///|
fn set_object_language(obj : Object, language : String?) -> Unit {
  obj.language = language
  let kept : Array[String] = []
  for c in obj.classes {
    if !c.has_prefix("lang:") {
      kept.push(c)
    }
  }
  obj.classes.clear()
  for c in kept {
    obj.classes.push(c)
  }
  match language {
    Some(lang) => if lang.length() > 0 { obj.classes.push("lang:" + lang) }
    None => ()
  }
}

///|
fn set_object_position(
  obj : Object,
  keyword : String,
  position : String?,
) -> Unit {
  match keyword {
    "label" => obj.label_position = position
    "icon" => obj.icon_position = position
    "tooltip" => obj.tooltip_position = position
    _ => ()
  }
}

///|
fn d2_target_label_position(raw : String) -> String? {
  match raw {
    "top-left" => Some("INSIDE_TOP_LEFT")
    "top-center" => Some("INSIDE_TOP_CENTER")
    "top-right" => Some("INSIDE_TOP_RIGHT")
    "center-left" => Some("INSIDE_MIDDLE_LEFT")
    "center-center" => Some("INSIDE_MIDDLE_CENTER")
    "center-right" => Some("INSIDE_MIDDLE_RIGHT")
    "bottom-left" => Some("INSIDE_BOTTOM_LEFT")
    "bottom-center" => Some("INSIDE_BOTTOM_CENTER")
    "bottom-right" => Some("INSIDE_BOTTOM_RIGHT")
    "outside-top-left" => Some("OUTSIDE_TOP_LEFT")
    "outside-top-center" => Some("OUTSIDE_TOP_CENTER")
    "outside-top-right" => Some("OUTSIDE_TOP_RIGHT")
    "outside-left-top" => Some("OUTSIDE_LEFT_TOP")
    "outside-left-center" => Some("OUTSIDE_LEFT_MIDDLE")
    "outside-left-bottom" => Some("OUTSIDE_LEFT_BOTTOM")
    "outside-right-top" => Some("OUTSIDE_RIGHT_TOP")
    "outside-right-center" => Some("OUTSIDE_RIGHT_MIDDLE")
    "outside-right-bottom" => Some("OUTSIDE_RIGHT_BOTTOM")
    "outside-bottom-left" => Some("OUTSIDE_BOTTOM_LEFT")
    "outside-bottom-center" => Some("OUTSIDE_BOTTOM_CENTER")
    "outside-bottom-right" => Some("OUTSIDE_BOTTOM_RIGHT")
    "border-top-left" => Some("BORDER_TOP_LEFT")
    "border-top-center" => Some("BORDER_TOP_CENTER")
    "border-top-right" => Some("BORDER_TOP_RIGHT")
    "border-left-top" => Some("BORDER_LEFT_TOP")
    "border-left-center" => Some("BORDER_LEFT_MIDDLE")
    "border-left-bottom" => Some("BORDER_LEFT_BOTTOM")
    "border-right-top" => Some("BORDER_RIGHT_TOP")
    "border-right-center" => Some("BORDER_RIGHT_MIDDLE")
    "border-right-bottom" => Some("BORDER_RIGHT_BOTTOM")
    "border-bottom-left" => Some("BORDER_BOTTOM_LEFT")
    "border-bottom-center" => Some("BORDER_BOTTOM_CENTER")
    "border-bottom-right" => Some("BORDER_BOTTOM_RIGHT")
    _ => None
  }
}

///|
fn process_composite_position_field(
  obj : Object,
  keyword : String,
  field : @ir.Field,
) -> Unit raise GraphCompileError {
  match field.composite {
    Some(@ir.Composite::Map(position_map)) => {
      for nested in position_map.fields {
        if nested.name == "near" && nested.name_is_unquoted() {
          match nested.primary {
            Some(value) =>
              if value.is_null() {
                set_object_position(obj, keyword, None)
              } else {
                let raw = value.to_string()
                let position = match keyword {
                  "label" | "icon" => d2_target_label_position(raw)
                  "tooltip" =>
                    if @ast.tooltip_positions.contains(raw) {
                      Some(raw)
                    } else {
                      None
                    }
                  _ => None
                }
                match position {
                  Some(v) => set_object_position(obj, keyword, Some(v))
                  None => raise Semantic("invalid \"near\" field")
                }
              }
            None => raise Semantic("invalid \"near\" field")
          }
        } else {
          raise Semantic("unexpected field \{nested.name}")
        }
      }
      if !position_map.edges.is_empty() {
        raise Semantic("unexpected edges in map")
      }
    }
    _ => ()
  }
}

///|
fn extract_sql_constraints(ir : @ir.Map) -> Array[String] {
  let out : Array[String] = []
  match ir.get_field("constraint") {
    Some(f) => {
      match f.primary {
        Some(s) => out.push(s.to_string())
        None => ()
      }
      match f.composite {
        Some(@ir.Composite::Array(arr)) =>
          for v in arr.values {
            match v {
              @ir.Value::Scalar(s) => out.push(s.to_string())
              _ => ()
            }
          }
        _ => ()
      }
    }
    None => ()
  }
  out
}

///|
fn process_special_fields(
  obj : Object,
  ir : @ir.Map,
) -> Unit raise GraphCompileError {
  validate_reserved_fields(ir)
  // Process shape
  match ir.get_field("shape") {
    Some(f) =>
      match f.primary {
        Some(s) => {
          let shape = s.to_string()
          obj.raw_shape = Some(shape)
          obj.shape_type = ShapeType::from_string(shape)
          if obj.shape_type == ShapeType::Code {
            // D2 parity: explicit code shape is plaintext.
            set_object_language(obj, Some("text"))
          }
        }
        None => ()
      }
    None => ()
  }
  // Process label (override)
  match ir.get_field("label") {
    Some(f) => {
      match f.primary {
        Some(s) => set_object_label_from_scalar(obj, s)
        None => ()
      }
      process_composite_position_field(obj, "label", f)
    }
    None => ()
  }
  // Process direction
  match ir.get_field("direction") {
    Some(f) =>
      match f.primary {
        Some(s) => {
          let raw = s.to_string()
          match parse_direction_keyword(raw) {
            Some(v) => obj.direction = Some(v)
            None =>
              raise Semantic(
                "direction must be one of up, down, right, left, got \"\{raw}\"",
              )
          }
        }
        None => ()
      }
    None => ()
  }
  // Process width
  match ir.get_field("width") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_double(s.to_string()) {
            Some(v) => obj.width = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Process height
  match ir.get_field("height") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_double(s.to_string()) {
            Some(v) => obj.height = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Process icon
  match ir.get_field("icon") {
    Some(f) => {
      match f.primary {
        Some(s) => obj.icon = Some(s.to_string())
        None => ()
      }
      process_composite_position_field(obj, "icon", f)
    }
    None => ()
  }
  // Process tooltip
  match ir.get_field("tooltip") {
    Some(f) => {
      match f.primary {
        Some(s) => obj.tooltip = Some(s.to_string())
        None => ()
      }
      process_composite_position_field(obj, "tooltip", f)
    }
    None => ()
  }
  // Process link
  match ir.get_field("link") {
    Some(f) =>
      match f.primary {
        Some(s) => obj.link = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  // Process style block
  match ir.get_field("style") {
    Some(f) =>
      match f.composite {
        Some(@ir.Composite::Map(style_map)) => {
          validate_style_keys(style_map)
          process_style(obj.style, style_map)
        }
        _ => ()
      }
    None => ()
  }
  // Process grid-rows
  match ir.get_field("grid-rows") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_int(s.to_string()) {
            Some(v) => obj.grid_rows = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Process grid-columns
  match ir.get_field("grid-columns") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_int(s.to_string()) {
            Some(v) => obj.grid_columns = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Process grid-gap
  match ir.get_field("grid-gap") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_double(s.to_string()) {
            Some(v) => obj.grid_gap = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Process horizontal-gap
  match ir.get_field("horizontal-gap") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_double(s.to_string()) {
            Some(v) => obj.horizontal_gap = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Process vertical-gap
  match ir.get_field("vertical-gap") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_double(s.to_string()) {
            Some(v) => obj.vertical_gap = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Process grid-column-span
  match ir.get_field("grid-column-span") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_int(s.to_string()) {
            Some(v) => obj.grid_column_span = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Process grid-row-span
  match ir.get_field("grid-row-span") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_int(s.to_string()) {
            Some(v) => obj.grid_row_span = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Process near positioning
  match ir.get_field("near") {
    Some(f) =>
      match f.primary {
        Some(s) => obj.near = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  // Process fixed top position
  match ir.get_field("top") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          obj.top = Some(parse_non_negative_position("top", s.to_string()))
        None => ()
      }
    None => ()
  }
  // Process fixed left position
  match ir.get_field("left") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          obj.left = Some(parse_non_negative_position("left", s.to_string()))
        None => ()
      }
    None => ()
  }

  normalize_object_dimensions_for_shape(obj)
  validate_link_safety(obj)
}

///|
fn normalize_object_dimensions_for_shape(obj : Object) -> Unit {
  if obj.shape_type == ShapeType::Circle || obj.shape_type == ShapeType::Square {
    match (obj.width, obj.height) {
      (Some(w), None) => obj.height = Some(w)
      (None, Some(h)) => obj.width = Some(h)
      _ => ()
    }
  }
}

///|
fn parse_non_negative_position(
  keyword : String,
  raw : String,
) -> Int raise GraphCompileError {
  match parse_int(raw) {
    Some(v) =>
      if v < 0 {
        raise Semantic("\{keyword} must be a non-negative integer: \"\{raw}\"")
      } else {
        v
      }
    None => raise Semantic("non-integer \{keyword} \"\{raw}\"")
  }
}

///|
fn process_style(style : Style, ir : @ir.Map) -> Unit {
  // Opacity
  match ir.get_field("opacity") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_double(s.to_string()) {
            Some(v) => style.opacity = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Stroke
  match ir.get_field("stroke") {
    Some(f) =>
      match f.primary {
        Some(s) => style.stroke = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  // Fill
  match ir.get_field("fill") {
    Some(f) =>
      match f.primary {
        Some(s) => style.fill = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  // Stroke width
  match ir.get_field("stroke-width") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_double(s.to_string()) {
            Some(v) => style.stroke_width = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Stroke dash
  match ir.get_field("stroke-dash") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_double(s.to_string()) {
            Some(v) => style.stroke_dash = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Border radius
  match ir.get_field("border-radius") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_double(s.to_string()) {
            Some(v) => style.border_radius = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Font
  match ir.get_field("font") {
    Some(f) =>
      match f.primary {
        Some(s) => style.font = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  // Font size
  match ir.get_field("font-size") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match parse_int(s.to_string()) {
            Some(v) => style.font_size = Some(v)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // Font color
  match ir.get_field("font-color") {
    Some(f) =>
      match f.primary {
        Some(s) => style.font_color = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  // Bold
  match ir.get_field("bold") {
    Some(f) =>
      match f.primary {
        Some(s) => style.bold = Some(s.to_string() == "true")
        None => ()
      }
    None => ()
  }
  // Underline
  match ir.get_field("underline") {
    Some(f) =>
      match f.primary {
        Some(s) => style.underline = Some(s.to_string() == "true")
        None => ()
      }
    None => ()
  }
  // Italic
  match ir.get_field("italic") {
    Some(f) =>
      match f.primary {
        Some(s) => style.italic = Some(s.to_string() == "true")
        None => ()
      }
    None => ()
  }
  // Shadow
  match ir.get_field("shadow") {
    Some(f) =>
      match f.primary {
        Some(s) => style.shadow = Some(s.to_string() == "true")
        None => ()
      }
    None => ()
  }
  // 3D
  let mut three_d_primary : String? = None
  match ir.get_field("3d") {
    Some(f) =>
      match f.primary {
        Some(s) => three_d_primary = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  if three_d_primary is None {
    match ir.get_field("3") {
      Some(f) => {
        match f.primary {
          Some(s) => three_d_primary = Some(s.to_string())
          None => ()
        }
        if three_d_primary is None {
          match f.map() {
            Some(m) =>
              match m.get_field("d") {
                Some(df) =>
                  match df.primary {
                    Some(s) => three_d_primary = Some(s.to_string())
                    None => ()
                  }
                None => ()
              }
            None => ()
          }
        }
      }
      None => ()
    }
  }
  if three_d_primary is None {
    match ir.get_field("d") {
      Some(f) =>
        match f.primary {
          Some(s) => three_d_primary = Some(s.to_string())
          None => ()
        }
      None => ()
    }
  }
  match three_d_primary {
    Some(s) => style.three_d = Some(s == "true")
    None => ()
  }
  // Multiple
  match ir.get_field("multiple") {
    Some(f) =>
      match f.primary {
        Some(s) => style.multiple = Some(s.to_string() == "true")
        None => ()
      }
    None => ()
  }
  // Animated
  match ir.get_field("animated") {
    Some(f) =>
      match f.primary {
        Some(s) => style.animated = Some(s.to_string() == "true")
        None => ()
      }
    None => ()
  }
  // Filled
  match ir.get_field("filled") {
    Some(f) =>
      match f.primary {
        Some(s) => style.filled = Some(s.to_string() == "true")
        None => ()
      }
    None => ()
  }
  // Text transform
  match ir.get_field("text-transform") {
    Some(f) =>
      match f.primary {
        Some(s) => style.text_transform = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  // Font family
  match ir.get_field("font-family") {
    Some(f) =>
      match f.primary {
        Some(s) => style.font_family = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  // Fill pattern
  match ir.get_field("fill-pattern") {
    Some(f) =>
      match f.primary {
        Some(s) => style.fill_pattern = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  // Double border
  match ir.get_field("double-border") {
    Some(f) =>
      match f.primary {
        Some(s) => style.double_border = Some(s.to_string() == "true")
        None => ()
      }
    None => ()
  }
  // Sketch mode
  match ir.get_field("sketch") {
    Some(f) =>
      match f.primary {
        Some(s) => style.sketch = Some(s.to_string() == "true")
        None => ()
      }
    None => ()
  }
  // Curved edges
  match ir.get_field("curved") {
    Some(f) =>
      match f.primary {
        Some(s) => style.curved = Some(s.to_string() == "true")
        None => ()
      }
    None => ()
  }
}

///|
fn d2_has_surrounding_whitespace(s : String) -> Bool {
  if s.length() == 0 {
    false
  } else {
    s.trim().length() != s.length()
  }
}

///|
fn d2_contains_char(s : String, target : Char) -> Bool {
  for c in s {
    if c == target {
      return true
    }
  }
  false
}

///|
fn d2_escape_single_quoted_value(s : String) -> String {
  let b = StringBuilder::new()
  for r in s {
    match r {
      '\'' => b.write_char('\'')
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
        continue
      }
      _ => ()
    }
    b.write_char(r)
  }
  b.to_string()
}

///|
fn d2_escape_double_quoted_value(s : String) -> String {
  let b = StringBuilder::new()
  for r in s {
    match r {
      '"' | '\\' => b.write_char('\\')
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
        continue
      }
      _ => ()
    }
    b.write_char(r)
  }
  b.to_string()
}

///|
fn d2_escape_unquoted_key_value(s : String) -> String {
  if s.length() == 0 {
    return "\"\""
  }
  if s.to_lower() == "null" {
    return "'null'"
  }
  let key_specials = "#;\n\\{}[]'\"|:.-<>*&()@&"
  let chars = s.to_array()
  let b = StringBuilder::new()
  for i, r in chars {
    match r {
      '\'' | '"' | '|' => if i == 0 { b.write_char('\\') } else { () }
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
        continue
      }
      _ =>
        if r == '-' {
          if i + 1 < chars.length() && chars[i + 1] == '-' {
            b.write_char('\\')
          }
        } else if r == '&' {
          if i == 0 {
            b.write_char('\\')
          }
        } else if d2_contains_char(key_specials, r) {
          b.write_char('\\')
        }
    }
    b.write_char(r)
  }
  b.to_string()
}

///|
fn d2_is_reserved_for_unquoted_key(s : String) -> Bool {
  let lower = s.to_lower()
  lower == "null" ||
  lower == "suspend" ||
  lower == "unsuspend" ||
  lower == "style" ||
  lower == "shape" ||
  lower == "icon" ||
  lower == "tooltip" ||
  lower == "link" ||
  lower == "near" ||
  lower == "width" ||
  lower == "height" ||
  lower == "top" ||
  lower == "left" ||
  lower == "direction" ||
  lower == "constraint" ||
  lower == "class" ||
  lower == "classes" ||
  lower == "vars" ||
  lower == "grid-rows" ||
  lower == "grid-columns" ||
  lower == "grid-gap" ||
  lower == "horizontal-gap" ||
  lower == "vertical-gap" ||
  lower == "grid-column-span" ||
  lower == "grid-row-span" ||
  lower == "layers" ||
  lower == "scenarios" ||
  lower == "steps"
}

///|
fn d2_format_key_segment(s : String) -> String {
  if s.length() == 0 {
    return "\"\""
  }
  let key_specials = "#;\n\\{}[]'\"|:.-<>*&()@&"
  let chars = s.to_array()
  for i, r in chars {
    if r == '-' {
      if i + 1 < chars.length() && chars[i + 1] != '-' {
        continue
      }
    }
    if d2_contains_char(key_specials, r) {
      if !d2_contains_char(s, '"') {
        return "\"\{d2_escape_double_quoted_value(s)}\""
      }
      if d2_contains_char(s, '\n') {
        return "\"\{d2_escape_double_quoted_value(s)}\""
      }
      return "'\{d2_escape_single_quoted_value(s)}'"
    }
  }
  if d2_has_surrounding_whitespace(s) {
    return "\"\{d2_escape_double_quoted_value(s)}\""
  }
  let mut out = d2_escape_unquoted_key_value(s)
  if d2_is_reserved_for_unquoted_key(out) {
    out = out.to_lower()
  }
  out
}

///|
fn join_path(prefix : String, path : Array[String]) -> String {
  let buf = StringBuilder::new()
  if prefix.length() > 0 {
    buf.write_string(prefix)
  }
  let mut first = prefix.length() == 0
  for segment in path {
    if !first {
      buf.write_char('.')
    }
    buf.write_string(segment)
    first = false
  }
  buf.to_string()
}

///|
fn join_path_syntax(prefix : String, path : Array[String]) -> String {
  let buf = StringBuilder::new()
  if prefix.length() > 0 {
    buf.write_string(prefix)
  }
  let mut first = prefix.length() == 0
  for segment in path {
    if !first {
      buf.write_char('.')
    }
    buf.write_string(d2_format_key_segment(segment))
    first = false
  }
  buf.to_string()
}

///|
fn object_references_from_field(
  field : @ir.Field,
  scope_abs_id_syntax : String,
) -> Array[@graph.ObjectReference] {
  let references : Array[@graph.ObjectReference] = []
  for reference in field.references {
    let context = reference.context()
    let source_path = match context {
      Some(ctx) => ctx.source_path
      None => None
    }
    references.push(
      @graph.ObjectReference::new(
        reference.range,
        reference.key_path_index,
        match context {
          Some(ctx) => ctx.edge is Some(_)
          None => false
        },
        Some(scope_abs_id_syntax),
        source_path,
        reference.primary,
        reference.due_to_glob,
        reference.due_to_lazy_glob,
      ),
    )
  }
  references
}

///|
fn edge_references_from_ir(
  edge : @ir.Edge,
  scope_abs_id_syntax : String,
) -> Array[@graph.EdgeReference] {
  let references : Array[@graph.EdgeReference] = []
  for reference in edge.references {
    let context = reference.context()
    let source_path = match context {
      Some(ctx) => ctx.source_path
      None => None
    }
    references.push(
      @graph.EdgeReference::new(
        reference.range,
        reference.edge_index,
        Some(scope_abs_id_syntax),
        source_path,
        reference.primary,
        reference.due_to_glob,
        reference.due_to_lazy_glob,
      ),
    )
  }
  references
}

///|
fn compile_edges_in_map(
  graph : Graph,
  ir : @ir.Map,
  prefix : String,
  prefix_syntax : String,
  next_index : Int,
) -> Int raise GraphCompileError {
  let mut next_index = next_index
  for field in ir.fields {
    if field.is_reserved_keyword_name() {
      continue
    }
    match field.composite {
      Some(@ir.Composite::Map(inner)) => {
        let child_prefix = if prefix == "" {
          field.name
        } else {
          prefix + "." + field.name
        }
        let child_prefix_syntax = if prefix_syntax == "" {
          d2_format_key_segment(field.name)
        } else {
          prefix_syntax + "." + d2_format_key_segment(field.name)
        }
        next_index = compile_edges_in_map(
          graph, inner, child_prefix, child_prefix_syntax, next_index,
        )
      }
      _ => ()
    }
  }
  for edge in ir.edges {
    let src_id = join_path(prefix, edge.id.src_path)
    let dst_id = join_path(prefix, edge.id.dst_path)
    let src_id_syntax = join_path_syntax(prefix_syntax, edge.id.src_path)
    let dst_id_syntax = join_path_syntax(prefix_syntax, edge.id.dst_path)
    let graph_edge = Edge::new(
      next_index,
      src_id,
      dst_id,
      edge.id.src_arrow,
      edge.id.dst_arrow,
      src_id_syntax~,
      dst_id_syntax~,
    )
    graph_edge.references = edge_references_from_ir(
      edge,
      if prefix_syntax == "" {
        graph.root.abs_id_syntax
      } else {
        prefix_syntax
      },
    )
    next_index = next_index + 1
    // Set reference count from IR edge references
    graph_edge.reference_count = edge.references.length()
    // Set label
    match edge.primary {
      Some(s) => graph_edge.label = s.to_string()
      None => ()
    }
    // Process edge properties from map
    match edge.map {
      Some(m) => {
        validate_edge_map_keys(m)
        // Process style
        match m.get_field("style") {
          Some(f) =>
            match f.composite {
              Some(@ir.Composite::Map(style_map)) => {
                validate_style_keys(style_map)
                process_style(graph_edge.style, style_map)
              }
              _ => ()
            }
          None => ()
        }
        // Process source-arrowhead / target-arrowhead using d2 semantics:
        // scalar can be either shape or label, map primary is label and shape
        // comes from `shape`.
        if m.get_field("source-arrowhead") is Some(f) {
          process_edge_arrowhead_field(graph_edge, f, true)
        }
        if m.get_field("target-arrowhead") is Some(f) {
          process_edge_arrowhead_field(graph_edge, f, false)
        }
        // Process source-anchor
        if m.get_field("source-anchor") is Some(f) {
          if f.primary is Some(s) {
            graph_edge.src_anchor = Some(s.to_string())
          }
        }
        // Process target-anchor
        if m.get_field("target-anchor") is Some(f) {
          if f.primary is Some(s) {
            graph_edge.dst_anchor = Some(s.to_string())
          }
        }

        // Process manual bend points for edge routing.
        // Supported:
        // - bend-points: [[x, y], [x, y]]
        // - route.points: [[x, y], [x, y]]
        // - route: [[x, y], [x, y]]
        if m.get_field("bend-points") is Some(f) {
          match f.array() {
            Some(arr) => {
              let points = parse_bend_points_array(arr)
              if !points.is_empty() {
                graph_edge.bend_points = Some(points)
              }
            }
            None => ()
          }
        } else if m.get_field("route") is Some(route_f) {
          // Prefer route.points if present
          let mut points : Array[Point] = []
          match route_f.map() {
            Some(route_map) =>
              match route_map.get_field("points") {
                Some(points_f) =>
                  match points_f.array() {
                    Some(arr) => points = parse_bend_points_array(arr)
                    None => ()
                  }
                None => ()
              }
            None => ()
          }
          if points.is_empty() {
            match route_f.array() {
              Some(arr) => points = parse_bend_points_array(arr)
              None => ()
            }
          }
          if !points.is_empty() {
            graph_edge.bend_points = Some(points)
          }
        }
      }
      None => ()
    }
    graph.add_edge(graph_edge)
  }
  next_index
}

///|
fn parse_arrowhead_shape_string(raw : String) -> ArrowheadType? {
  match raw.to_lower() {
    "none"
    | "triangle"
    | "arrow"
    | "diamond"
    | "circle"
    | "open"
    | "line"
    | "cf-one"
    | "cfone"
    | "cf-many"
    | "cfmany"
    | "cf-one-required"
    | "cfonerequired"
    | "cf-many-required"
    | "cfmanyrequired"
    | "cf-one-optional"
    | "cfoneoptional"
    | "cf-many-optional"
    | "cfmanyoptional" => Some(ArrowheadType::from_string(raw))
    _ => None
  }
}

///|
fn process_edge_arrowhead_field(
  edge : Edge,
  field : @ir.Field,
  is_source : Bool,
) -> Unit {
  match field.composite {
    Some(@ir.Composite::Map(arrowhead_map)) => {
      // In map form, primary value is treated as arrowhead label.
      if field.primary is Some(p) {
        if is_source {
          edge.src_arrowhead_label = Some(p.to_string())
        } else {
          edge.dst_arrowhead_label = Some(p.to_string())
        }
      }
      match arrowhead_map.get_field("shape") {
        Some(shape_f) =>
          match shape_f.primary {
            Some(s) =>
              match parse_arrowhead_shape_string(s.to_string()) {
                Some(shape) =>
                  if is_source {
                    edge.src_arrowhead = shape
                  } else {
                    edge.dst_arrowhead = shape
                  }
                None => ()
              }
            None => ()
          }
        None => ()
      }
      match arrowhead_map.get_field("style") {
        Some(style_f) =>
          match style_f.map() {
            Some(style_map) =>
              match style_map.get_field("font-color") {
                Some(color_f) =>
                  match color_f.primary {
                    Some(color) =>
                      if is_source {
                        edge.src_arrowhead_label_color = Some(color.to_string())
                      } else {
                        edge.dst_arrowhead_label_color = Some(color.to_string())
                      }
                    None => ()
                  }
                None => ()
              }
            None => ()
          }
        None => ()
      }
    }
    _ =>
      match field.primary {
        Some(s) => {
          let raw = s.to_string()
          match parse_arrowhead_shape_string(raw) {
            Some(shape) =>
              if is_source {
                edge.src_arrowhead = shape
              } else {
                edge.dst_arrowhead = shape
              }
            None =>
              if is_source {
                edge.src_arrowhead_label = Some(raw)
              } else {
                edge.dst_arrowhead_label = Some(raw)
              }
          }
        }
        None => ()
      }
  }
}

///|
fn compile_edges(graph : Graph, ir : @ir.Map) -> Unit raise GraphCompileError {
  compile_edges_in_map(graph, ir, "", "", 0) |> ignore
}

///|
fn validate_style_keys(style_map : @ir.Map) -> Unit raise GraphCompileError {
  for field in style_map.fields {
    if !field.name_is_unquoted() || !is_style_keyword(field.name) {
      raise InvalidStyle("invalid style keyword: \"\{field.name}\"")
    }
  }
}

///|
fn is_style_keyword(name : String) -> Bool {
  let keywords = [
    "opacity", "stroke", "fill", "stroke-width", "stroke-dash", "border-radius",
    "shadow", "3d", "3", "d", "multiple", "font", "font-size", "font-color", "bold",
    "italic", "underline", "animated", "filled", "double-border", "text-transform",
    "fill-pattern", "sketch", "curved",
  ]
  keywords.contains(name.to_lower())
}

///|
fn validate_edge_map_keys(edge_map : @ir.Map) -> Unit raise GraphCompileError {
  for field in edge_map.fields {
    if !field.name_is_unquoted() || !is_edge_reserved_keyword(field.name) {
      raise Semantic("edge map keys must be reserved keywords")
    }
  }
}

///|
fn is_edge_reserved_keyword(name : String) -> Bool {
  let keywords = [
    "style", "source-arrowhead", "target-arrowhead", "source-anchor", "target-anchor",
    "bend-points", "route",
  ]
  keywords.contains(name.to_lower())
}

///|
fn validate_reserved_fields(ir : @ir.Map) -> Unit raise GraphCompileError {
  for field in ir.fields {
    if !field.is_reserved_keyword_name() {
      continue
    }
    let keyword = field.name.to_lower()
    if keyword == "style" {
      match field.composite {
        Some(@ir.Composite::Map(style_map)) => validate_style_keys(style_map)
        _ =>
          if field.primary is None {
            raise Semantic("reserved field \"style\" must have a value")
          }
      }
      continue
    }
    if field.primary is None && field.composite is None {
      raise Semantic("reserved field \"\{field.name}\" must have a value")
    }
    if keyword == "shape" {
      if field.composite is Some(_) {
        raise Semantic("reserved field shape does not accept composite")
      }
    }
    if keyword == "near" {
      if field.composite is Some(_) {
        raise Semantic("invalid \"near\" field")
      }
    }
    if keyword == "top" || keyword == "left" {
      if field.composite is Some(_) {
        raise Semantic(
          "reserved field \"\{field.name}\" does not accept composite",
        )
      }
    }
    if keyword == "direction" {
      if field.composite is Some(_) {
        raise Semantic(
          "reserved field \"\{field.name}\" does not accept composite",
        )
      }
    }
  }
}

///|
fn validate_board_root_scope(ir : @ir.Map) -> Unit raise GraphCompileError {
  for field in ir.fields {
    if field.is_board_keyword_name() {
      raise Semantic("\{field.name} must be declared at a board root scope")
    }
  }
}

///|
fn is_http_url(s : String) -> Bool {
  let lower = s.to_lower()
  lower.has_prefix("http://") || lower.has_prefix("https://")
}

///|
fn validate_link_safety(obj : Object) -> Unit raise GraphCompileError {
  match obj.link {
    Some(link) =>
      if is_http_url(link) {
        if is_http_url(obj.label) {
          raise Semantic(
            "Label cannot be set to URL when link is also set (for security)",
          )
        }
        match obj.tooltip {
          Some(tooltip) =>
            if is_http_url(tooltip) {
              raise Semantic(
                "Tooltip cannot be set to URL when link is also set (for security)",
              )
            }
          None => ()
        }
      }
    None => ()
  }
}

///|
fn validate_semantics(graph : Graph) -> Unit raise GraphCompileError {
  validate_near_rules(graph)
  validate_edge_rules(graph)
  validate_position_rules(graph)
  for layer in graph.layers {
    validate_semantics(layer.graph)
  }
  for scenario in graph.scenarios {
    validate_semantics(scenario.graph)
  }
  for step in graph.steps {
    validate_semantics(step.graph)
  }
}

///|
fn validate_near_rules(graph : Graph) -> Unit raise GraphCompileError {
  let object_by_abs_id_syntax : Map[String, Object] = {}
  for obj in graph.objects {
    object_by_abs_id_syntax[obj.abs_id_syntax] = obj
  }
  for obj in graph.objects {
    match obj.near {
      None => ()
      Some(near_raw) => {
        let near = near_raw.to_lower()
        if is_near_constant(near) {
          if obj.id.contains(".") {
            raise Semantic(
              "constant near keys can only be set on root level shapes",
            )
          }
          continue
        }
        guard object_by_abs_id_syntax.get(near_raw) is Some(near_obj) else {
          raise Semantic(
            "near key \"\{near_raw}\" must be the absolute path to a shape or one of the following constants: \{near_constants_message()}",
          )
        }
        if is_descendant_or_same_abs_id_syntax(obj.abs_id_syntax, near_raw) {
          raise Semantic("near keys cannot be set to an ancestor")
        }
        if is_descendant_or_same_abs_id_syntax(near_raw, obj.abs_id_syntax) {
          raise Semantic("near keys cannot be set to an descendant")
        }
        if is_inside_sequence_diagram_by_abs_id_syntax(
            graph,
            object_by_abs_id_syntax,
            near_obj.abs_id_syntax,
          ) {
          raise Semantic(
            "near keys cannot be set to an object within sequence diagrams",
          )
        }
        match near_obj.near {
          Some(near_obj_near) =>
            if is_near_constant(near_obj_near.to_lower()) {
              raise Semantic(
                "near keys cannot be set to an object with a constant near key",
              )
            }
          None => ()
        }
        if has_grid_diagram_ancestor_by_abs_id_syntax(
            object_by_abs_id_syntax,
            near_obj.abs_id_syntax,
          ) {
          raise Semantic(
            "near keys cannot be set to descendants of special objects, like grid cells",
          )
        }
        if has_sequence_diagram_ancestor_by_abs_id_syntax(
            object_by_abs_id_syntax,
            near_obj.abs_id_syntax,
          ) {
          raise Semantic(
            "near keys cannot be set to descendants of special objects, like sequence diagram actors",
          )
        }
      }
    }
  }
}

///|
fn validate_edge_rules(graph : Graph) -> Unit raise GraphCompileError {
  let object_by_abs_id_syntax : Map[String, Object] = {}
  for obj in graph.objects {
    object_by_abs_id_syntax[obj.abs_id_syntax] = obj
  }
  for edge in graph.edges {
    guard object_by_abs_id_syntax.get(edge.src_id_syntax) is Some(src) else {
      continue
    }
    guard object_by_abs_id_syntax.get(edge.dst_id_syntax) is Some(dst) else {
      continue
    }
    if is_constant_near_object(src) &&
      is_descendant_or_same_abs_id_syntax(dst.abs_id_syntax, src.abs_id_syntax) {
      raise Semantic(
        "edge from constant near \"\{src.abs_id_syntax}\" cannot enter itself",
      )
    }
    if is_constant_near_object(dst) &&
      is_descendant_or_same_abs_id_syntax(src.abs_id_syntax, dst.abs_id_syntax) {
      raise Semantic(
        "edge from constant near \"\{dst.abs_id_syntax}\" cannot enter itself",
      )
    }
    if is_grid_diagram_object(src) &&
      is_descendant_or_same_abs_id_syntax(dst.abs_id_syntax, src.abs_id_syntax) {
      raise Semantic(
        "edge from grid diagram \"\{src.abs_id_syntax}\" cannot enter itself",
      )
    }
    if is_grid_diagram_object(dst) &&
      is_descendant_or_same_abs_id_syntax(src.abs_id_syntax, dst.abs_id_syntax) {
      raise Semantic(
        "edge from grid diagram \"\{dst.abs_id_syntax}\" cannot enter itself",
      )
    }
    if parent_is_grid_diagram_by_abs_id_syntax(
        object_by_abs_id_syntax,
        src.abs_id_syntax,
      ) &&
      is_descendant_or_same_abs_id_syntax(dst.abs_id_syntax, src.abs_id_syntax) {
      raise Semantic(
        "edge from grid cell \"\{src.abs_id_syntax}\" cannot enter itself",
      )
    }
    if parent_is_grid_diagram_by_abs_id_syntax(
        object_by_abs_id_syntax,
        dst.abs_id_syntax,
      ) &&
      is_descendant_or_same_abs_id_syntax(src.abs_id_syntax, dst.abs_id_syntax) {
      raise Semantic(
        "edge from grid cell \"\{dst.abs_id_syntax}\" cannot enter itself",
      )
    }
    if is_sequence_diagram_object(src) &&
      is_descendant_or_same_abs_id_syntax(dst.abs_id_syntax, src.abs_id_syntax) {
      raise Semantic(
        "edge from sequence diagram \"\{src.abs_id_syntax}\" cannot enter itself",
      )
    }
    if is_sequence_diagram_object(dst) &&
      is_descendant_or_same_abs_id_syntax(src.abs_id_syntax, dst.abs_id_syntax) {
      raise Semantic(
        "edge from sequence diagram \"\{dst.abs_id_syntax}\" cannot enter itself",
      )
    }
  }
}

///|
fn validate_position_rules(graph : Graph) -> Unit raise GraphCompileError {
  let object_by_id : Map[String, Object] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  for obj in graph.objects {
    if obj.top is None && obj.left is None {
      continue
    }
    let parent = lookup_parent_object(graph, object_by_id, obj.id)
    if is_hierarchy_shape(parent) {
      raise Semantic(
        "position keywords cannot be used with shape \"hierarchy\"",
      )
    }
    if parent.grid_columns is Some(_) || parent.grid_rows is Some(_) {
      raise Semantic("position keywords cannot be used with grids")
    }
    if is_inside_sequence_diagram(graph, object_by_id, obj.id) {
      raise Semantic(
        "position keywords cannot be used inside shape \"sequence_diagram\"",
      )
    }
  }
}

///|
fn is_hierarchy_shape(obj : Object) -> Bool {
  match obj.raw_shape {
    Some(shape) => shape.to_lower() == "hierarchy"
    None => false
  }
}

///|
fn is_inside_sequence_diagram(
  graph : Graph,
  object_by_id : Map[String, Object],
  id : String,
) -> Bool {
  if graph.root.shape_type == ShapeType::SequenceDiagram {
    return true
  }
  has_sequence_diagram_ancestor(object_by_id, id)
}

///|
fn has_sequence_diagram_ancestor(
  object_by_id : Map[String, Object],
  id : String,
) -> Bool {
  match parent_id_of(id) {
    None => false
    Some(parent_id) =>
      match object_by_id.get(parent_id) {
        Some(parent) =>
          if parent.shape_type == ShapeType::SequenceDiagram {
            true
          } else {
            has_sequence_diagram_ancestor(object_by_id, parent_id)
          }
        None => false
      }
  }
}

///|
fn is_descendant_or_same_abs_id_syntax(
  abs_id_syntax : String,
  ancestor_abs_id_syntax : String,
) -> Bool {
  if abs_id_syntax == ancestor_abs_id_syntax {
    return true
  }
  match parent_abs_id_syntax_of(abs_id_syntax) {
    Some(parent_abs_id_syntax) =>
      is_descendant_or_same_abs_id_syntax(
        parent_abs_id_syntax, ancestor_abs_id_syntax,
      )
    None => false
  }
}

///|
fn parent_abs_id_syntax_of(abs_id_syntax : String) -> String? {
  let segments = @graph.split_syntax_path(abs_id_syntax)
  if segments.length() <= 1 {
    return None
  }
  let out = StringBuilder::new()
  for i = 0; i < segments.length() - 1; i = i + 1 {
    if i > 0 {
      out.write_string(".")
    }
    out.write_string(segments[i])
  }
  Some(out.to_string())
}

///|
fn has_sequence_diagram_ancestor_by_abs_id_syntax(
  object_by_abs_id_syntax : Map[String, Object],
  abs_id_syntax : String,
) -> Bool {
  match parent_abs_id_syntax_of(abs_id_syntax) {
    None => false
    Some(parent_abs_id_syntax) =>
      match object_by_abs_id_syntax.get(parent_abs_id_syntax) {
        Some(parent) =>
          if is_sequence_diagram_object(parent) {
            true
          } else {
            has_sequence_diagram_ancestor_by_abs_id_syntax(
              object_by_abs_id_syntax, parent_abs_id_syntax,
            )
          }
        None => false
      }
  }
}

///|
fn is_inside_sequence_diagram_by_abs_id_syntax(
  graph : Graph,
  object_by_abs_id_syntax : Map[String, Object],
  abs_id_syntax : String,
) -> Bool {
  if graph.root.shape_type == ShapeType::SequenceDiagram {
    return true
  }
  has_sequence_diagram_ancestor_by_abs_id_syntax(
    object_by_abs_id_syntax, abs_id_syntax,
  )
}

///|
fn has_grid_diagram_ancestor_by_abs_id_syntax(
  object_by_abs_id_syntax : Map[String, Object],
  abs_id_syntax : String,
) -> Bool {
  match parent_abs_id_syntax_of(abs_id_syntax) {
    None => false
    Some(parent_abs_id_syntax) =>
      match object_by_abs_id_syntax.get(parent_abs_id_syntax) {
        Some(parent) =>
          if is_grid_diagram_object(parent) {
            true
          } else {
            has_grid_diagram_ancestor_by_abs_id_syntax(
              object_by_abs_id_syntax, parent_abs_id_syntax,
            )
          }
        None => false
      }
  }
}

///|
fn parent_is_grid_diagram_by_abs_id_syntax(
  object_by_abs_id_syntax : Map[String, Object],
  abs_id_syntax : String,
) -> Bool {
  match parent_abs_id_syntax_of(abs_id_syntax) {
    Some(parent_abs_id_syntax) =>
      match object_by_abs_id_syntax.get(parent_abs_id_syntax) {
        Some(parent) => is_grid_diagram_object(parent)
        None => false
      }
    None => false
  }
}

///|
fn is_grid_diagram_object(obj : Object) -> Bool {
  obj.grid_columns is Some(_) || obj.grid_rows is Some(_)
}

///|
fn is_sequence_diagram_object(obj : Object) -> Bool {
  obj.shape_type == ShapeType::SequenceDiagram
}

///|
fn is_constant_near_object(obj : Object) -> Bool {
  match obj.near {
    Some(near) => is_near_constant(near.to_lower())
    None => false
  }
}

///|
fn lookup_parent_object(
  graph : Graph,
  object_by_id : Map[String, Object],
  id : String,
) -> Object {
  match parent_id_of(id) {
    Some(parent_id) =>
      match object_by_id.get(parent_id) {
        Some(parent) => parent
        None => graph.root
      }
    None => graph.root
  }
}

///|
fn parent_id_of(id : String) -> String? {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot <= 0 {
    return None
  }
  let out = StringBuilder::new()
  for i = 0; i < last_dot; i = i + 1 {
    match id[i].to_char() {
      Some(c) => out.write_char(c)
      None => ()
    }
  }
  Some(out.to_string())
}

///|
fn is_near_constant(value : String) -> Bool {
  near_constants().contains(value)
}

///|
fn near_constants() -> Array[String] {
  [
    "top-left", "top-center", "top-right", "center-left", "center-right", "bottom-left",
    "bottom-center", "bottom-right",
  ]
}

///|
fn near_constants_message() -> String {
  near_constants().join(", ")
}

///|
/// Compile D2 legend from `vars.d2-legend` (see ../d2/d2compiler/compile.go).
///
/// Note: `legend` is not treated as a reserved keyword; it is compiled as a
/// normal object to match D2 semantics and the reference SVGs in this repo.
fn compile_legend(
  graph : Graph,
  ir : @ir.Map,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  let vars_field = ir.get_field("vars")
  guard vars_field is Some(vf) else { return }
  let vars_map = match vf.composite {
    Some(@ir.Composite::Map(m)) => m
    _ => return
  }
  let legend_field = vars_map.get_field("d2-legend")
  guard legend_field is Some(lf) else { return }
  let legend_map = match lf.composite {
    Some(@ir.Composite::Map(m)) => m
    _ => return
  }

  // Compile the legend map as a standalone graph, then turn its objects/edges
  // into legend entries.
  let legend_graph = Graph::new("d2-legend")
  compile_objects(legend_graph, legend_map, "", "", classes)
  compile_edges(legend_graph, legend_map)
  let legend = Legend::new()
  match lf.primary {
    Some(p) => legend.set_title(p.to_string())
    None => ()
  }
  let mut have_shapes = false
  for obj in legend_graph.objects {
    match obj.style.opacity {
      Some(op) => if op == 0.0 { continue }
      None => ()
    }
    have_shapes = true
    legend.add_entry(
      LegendEntry::shape(obj.shape_type, obj.label, Some(obj.style)),
    )
  }
  let mut have_edges = false
  let mut added_sep = false
  for edge in legend_graph.edges {
    if have_shapes && !added_sep {
      legend.add_entry(LegendEntry::separator())
      added_sep = true
    }
    let (src_arrowhead, dst_arrowhead) = effective_edge_arrowheads(edge)
    have_edges = true
    legend.add_entry(
      LegendEntry::connection(
        src_arrowhead,
        dst_arrowhead,
        edge.label,
        Some(edge.style),
      ),
    )
  }
  if have_shapes || have_edges {
    graph.set_legend(legend)
  }
}

///|
#warnings("-unused_value")
fn make_legend_with_overrides(
  title : String?,
  position : LegendPosition,
  fill : String?,
  stroke : String?,
  padding : Double?,
  entry_gap : Double?,
  icon_size : Double?,
) -> Legend {
  let legend = Legend::with_position(position)
  match title {
    Some(t) => legend.set_title(t)
    None => ()
  }
  match fill {
    Some(v) => legend.set_fill(v)
    None => ()
  }
  match stroke {
    Some(v) => legend.set_stroke(v)
    None => ()
  }
  match padding {
    Some(v) => legend.set_padding(v)
    None => ()
  }
  match entry_gap {
    Some(v) => legend.set_entry_gap(v)
    None => ()
  }
  match icon_size {
    Some(v) => legend.set_icon_size(v)
    None => ()
  }
  legend
}

///|
fn parse_bool(s : String) -> Bool? {
  match s.to_lower() {
    "true" => Some(true)
    "false" => Some(false)
    _ => None
  }
}

///|
#warnings("-unused_value")
fn parse_legend_entries(arr : @ir.IRArray) -> Array[LegendEntry] {
  let entries : Array[LegendEntry] = []
  for v in arr.values {
    match parse_legend_entry(v) {
      Some(e) => entries.push(e)
      None => ()
    }
  }
  entries
}

///|
fn parse_legend_entry(v : @ir.Value) -> LegendEntry? {
  match v {
    @ir.Value::Scalar(s) => {
      let text = s.to_string()
      if text == "---" || text.to_lower() == "separator" {
        Some(LegendEntry::separator())
      } else {
        Some(LegendEntry::custom("•", text))
      }
    }
    @ir.Value::Array(_) => None
    @ir.Value::Map(m) => {
      // Separator entry
      match m.get_field("separator") {
        Some(sf) =>
          match sf.primary {
            Some(p) =>
              if parse_bool(p.to_string()) is Some(true) {
                return Some(LegendEntry::separator())
              }
            None => ()
          }
        None => ()
      }

      // Optional style map for shape/connection entries
      let style = match m.get_field("style") {
        Some(f) =>
          match f.map() {
            Some(style_map) => {
              let s = Style::new()
              process_style(s, style_map)
              Some(s)
            }
            None => None
          }
        None => None
      }

      // Shape entry
      match m.get_field("shape") {
        Some(shf) =>
          match shf.primary {
            Some(p) => {
              let shape = ShapeType::from_string(p.to_string())
              let label = match m.get_field("label") {
                Some(lf) =>
                  match lf.primary {
                    Some(lp) => lp.to_string()
                    None => shape.to_shape_string()
                  }
                None => shape.to_shape_string()
              }
              return Some(LegendEntry::shape(shape, label, style))
            }
            None => ()
          }
        None => ()
      }

      // Custom entry
      let icon = match m.get_field("icon") {
        Some(f) =>
          match f.primary {
            Some(p) => Some(p.to_string())
            None => None
          }
        None => None
      }
      let label = match m.get_field("label") {
        Some(f) =>
          match f.primary {
            Some(p) => Some(p.to_string())
            None => None
          }
        None => None
      }
      if icon is Some(i) && label is Some(l) {
        return Some(LegendEntry::custom(i, l))
      }

      // Connection entry (prefer "connection" string, fall back to arrowhead fields).
      let mut src : ArrowheadType = ArrowheadType::from_string("none")
      let mut dst : ArrowheadType = ArrowheadType::from_string("triangle")
      let mut conn_label : String? = None
      match m.get_field("connection") {
        Some(cf) =>
          match cf.primary {
            Some(p) => {
              let s = p.to_string()
              match parse_connection_string(s) {
                Some((a, b)) => {
                  src = a
                  dst = b
                  conn_label = Some(s)
                }
                None => ()
              }
            }
            None => ()
          }
        None => ()
      }
      if conn_label is None {
        // Reuse arrowhead shapes (same syntax as edges)
        match m.get_field("source-arrowhead") {
          Some(f) =>
            match parse_arrowhead_field(f) {
              Some(v) => src = v
              None => ()
            }
          None => ()
        }
        match m.get_field("target-arrowhead") {
          Some(f) =>
            match parse_arrowhead_field(f) {
              Some(v) => dst = v
              None => ()
            }
          None => ()
        }
      }
      // Only emit connection entry if there is any signal that this is one
      if conn_label is Some(_) ||
        m.get_field("source-arrowhead") is Some(_) ||
        m.get_field("target-arrowhead") is Some(_) {
        let label = label.unwrap_or(connection_label(src, dst))
        return Some(LegendEntry::connection(src, dst, label, style))
      }
      None
    }
  }
}

///|
fn parse_arrowhead_field(f : @ir.Field) -> ArrowheadType? {
  if f.composite is Some(@ir.Composite::Map(arrowhead_map)) {
    match arrowhead_map.get_field("shape") {
      Some(shape_f) =>
        match shape_f.primary {
          Some(s) => Some(ArrowheadType::from_string(s.to_string()))
          None => None
        }
      None => None
    }
  } else {
    match f.primary {
      Some(s) => Some(ArrowheadType::from_string(s.to_string()))
      None => None
    }
  }
}

///|
fn parse_connection_string(s : String) -> (ArrowheadType, ArrowheadType)? {
  match s {
    "<->" =>
      Some(
        (
          ArrowheadType::from_string("triangle"),
          ArrowheadType::from_string("triangle"),
        ),
      )
    "->" =>
      Some(
        (
          ArrowheadType::from_string("none"),
          ArrowheadType::from_string("triangle"),
        ),
      )
    "<-" =>
      Some(
        (
          ArrowheadType::from_string("triangle"),
          ArrowheadType::from_string("none"),
        ),
      )
    "--" =>
      Some(
        (ArrowheadType::from_string("none"), ArrowheadType::from_string("none")),
      )
    _ => None
  }
}

///|
fn connection_label(src : ArrowheadType, dst : ArrowheadType) -> String {
  let src_has = src.to_arrowhead_string() != "none"
  let dst_has = dst.to_arrowhead_string() != "none"
  if src_has && dst_has {
    "<->"
  } else if src_has {
    "<-"
  } else if dst_has {
    "->"
  } else {
    "--"
  }
}

///|
fn effective_edge_arrowheads(edge : Edge) -> (ArrowheadType, ArrowheadType) {
  let src = if edge.src_arrow { edge.src_arrowhead } else { None }
  let dst = if edge.dst_arrow { edge.dst_arrowhead } else { None }
  (src, dst)
}

///|
fn collect_legend_entries_into(
  g : Graph,
  shapes : Map[String, Bool],
  conns : Map[String, (ArrowheadType, ArrowheadType)],
) -> Unit {
  for obj in g.objects {
    shapes[obj.shape_type.to_shape_string()] = true
  }
  for e in g.edges {
    let (src, dst) = effective_edge_arrowheads(e)
    let key = "\{src.to_arrowhead_string()}|\{dst.to_arrowhead_string()}"
    conns[key] = (src, dst)
  }
}

///|
#warnings("-unused_value")
fn auto_generate_legend_entries(graph : Graph) -> Array[LegendEntry] {
  let shapes : Map[String, Bool] = {}
  let conns : Map[String, (ArrowheadType, ArrowheadType)] = {}
  collect_legend_entries_into(graph, shapes, conns)
  for layer in graph.layers {
    collect_legend_entries_into(layer.graph, shapes, conns)
  }
  for scenario in graph.scenarios {
    collect_legend_entries_into(scenario.graph, shapes, conns)
  }
  for step in graph.steps {
    collect_legend_entries_into(step.graph, shapes, conns)
  }

  // Emit entries in stable, canonical order.
  let entries : Array[LegendEntry] = []
  let shape_order = [
    "rectangle", "square", "circle", "oval", "diamond", "hexagon", "parallelogram",
    "cylinder", "queue", "package", "step", "callout", "stored_data", "person", "cloud",
    "page", "document", "class", "sql_table", "text", "code", "image", "sequence_diagram",
  ]
  for key in shape_order {
    if shapes.contains(key) {
      entries.push(LegendEntry::shape(ShapeType::from_string(key), key, None))
    }
  }
  if !entries.is_empty() && !conns.is_empty() {
    entries.push(LegendEntry::separator())
  }

  // Prefer common arrow pairs first.
  let common : Array[(String, String)] = [
    ("none", "triangle"),
    ("triangle", "none"),
    ("triangle", "triangle"),
    ("none", "none"),
  ]
  let used : Map[String, Bool] = {}
  for pair in common {
    let src_s = pair.0
    let dst_s = pair.1
    let key = "\{src_s}|\{dst_s}"
    if conns.contains(key) {
      let src = ArrowheadType::from_string(src_s)
      let dst = ArrowheadType::from_string(dst_s)
      entries.push(
        LegendEntry::connection(src, dst, connection_label(src, dst), None),
      )
      used[key] = true
    }
  }
  for entry in conns {
    let key = entry.0
    let (src, dst) = entry.1
    if !used.contains(key) {
      entries.push(
        LegendEntry::connection(src, dst, connection_label(src, dst), None),
      )
    }
  }
  entries
}

///|
/// Compile layers from IR
fn compile_layers(
  graph : Graph,
  ir : @ir.Map,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  compile_boards_field(graph, ir, classes, "layers", false)
}

///|
/// Compile scenarios from IR
fn compile_scenarios(
  graph : Graph,
  ir : @ir.Map,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  compile_boards_field(graph, ir, classes, "scenarios", true)
}

///|
/// Compile steps from IR
fn compile_steps(
  graph : Graph,
  ir : @ir.Map,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  compile_boards_field(graph, ir, classes, "steps", true)
}

///|
fn parse_double(s : String) -> Double? {
  try @strconv.parse_double(s) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn parse_direction_keyword(raw : String) -> String? {
  match raw.to_lower() {
    "up" => Some("up")
    "down" => Some("down")
    "right" => Some("right")
    "left" => Some("left")
    _ => None
  }
}

///|
fn parse_point_string(s : String) -> Point? {
  // Strip whitespace and parentheses, then split on comma.
  let left = StringBuilder::new()
  let right = StringBuilder::new()
  let mut seen_comma = false
  for c in s {
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '(' || c == ')' {
      continue
    }
    if c == ',' {
      seen_comma = true
      continue
    }
    if !seen_comma {
      left.write_char(c)
    } else {
      right.write_char(c)
    }
  }
  guard seen_comma else { return None }
  match (parse_double(left.to_string()), parse_double(right.to_string())) {
    (Some(x), Some(y)) => Some(Point::new(x, y))
    _ => None
  }
}

///|
fn parse_point_value(v : @ir.Value) -> Point? {
  match v {
    @ir.Value::Array(arr) => {
      guard arr.values.length() >= 2 else { return None }
      let xs = match arr.values[0] {
        @ir.Value::Scalar(s) => s.to_string()
        _ => return None
      }
      let ys = match arr.values[1] {
        @ir.Value::Scalar(s) => s.to_string()
        _ => return None
      }
      match (parse_double(xs), parse_double(ys)) {
        (Some(x), Some(y)) => Some(Point::new(x, y))
        _ => None
      }
    }
    @ir.Value::Map(m) => {
      let xf = m.get_field("x")
      let yf = m.get_field("y")
      match (xf, yf) {
        (Some(xf), Some(yf)) =>
          match (xf.primary, yf.primary) {
            (Some(xp), Some(yp)) =>
              match
                (parse_double(xp.to_string()), parse_double(yp.to_string())) {
                (Some(x), Some(y)) => Some(Point::new(x, y))
                _ => None
              }
            _ => None
          }
        _ => None
      }
    }
    @ir.Value::Scalar(s) => parse_point_string(s.to_string())
  }
}

///|
fn parse_bend_points_array(arr : @ir.IRArray) -> Array[Point] {
  let points : Array[Point] = []
  for v in arr.values {
    match parse_point_value(v) {
      Some(p) => points.push(p)
      None => ()
    }
  }
  points
}

///|
fn parse_int(s : String) -> Int? {
  try @strconv.parse_int(s) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn normalize_sql_table_edge_endpoints_recursive(graph : Graph) -> Unit {
  normalize_sql_table_edge_endpoints(graph)
  for layer in graph.layers {
    normalize_sql_table_edge_endpoints_recursive(layer.graph)
  }
  for scenario in graph.scenarios {
    normalize_sql_table_edge_endpoints_recursive(scenario.graph)
  }
  for step in graph.steps {
    normalize_sql_table_edge_endpoints_recursive(step.graph)
  }
}

///|
fn normalize_sql_table_edge_endpoints(graph : Graph) -> Unit {
  let object_by_id : Map[String, Object] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  for i, edge in graph.edges {
    let mut normalized_src_id = edge.src_id
    let mut normalized_dst_id = edge.dst_id
    let mut normalized_src_column_index = edge.src_column_index
    let mut normalized_dst_column_index = edge.dst_column_index

    match sql_table_endpoint_info(object_by_id, normalized_src_id) {
      Some((table_id, column_index)) => {
        let dst_table_id = sql_table_id_for_endpoint(
          object_by_id, normalized_dst_id,
        )
        normalized_src_id = table_id
        match dst_table_id {
          Some(dst_table) =>
            if dst_table != table_id {
              normalized_src_column_index = Some(column_index)
            }
          None => normalized_src_column_index = Some(column_index)
        }
      }
      None => ()
    }
    match sql_table_endpoint_info(object_by_id, normalized_dst_id) {
      Some((table_id, column_index)) => {
        normalized_dst_id = table_id
        normalized_dst_column_index = Some(column_index)
      }
      None => ()
    }
    graph.edges[i] = {
      ..edge,
      src_id: normalized_src_id,
      dst_id: normalized_dst_id,
      src_column_index: normalized_src_column_index,
      dst_column_index: normalized_dst_column_index,
    }
  }
}

///|
fn sql_table_endpoint_info(
  object_by_id : Map[String, Object],
  endpoint_id : String,
) -> (String, Int)? {
  let parent_id = match parent_id_of(endpoint_id) {
    Some(v) => v
    None => return None
  }
  let parent = match object_by_id.get(parent_id) {
    Some(v) => v
    None => return None
  }
  if parent.shape_type != ShapeType::SqlTable {
    return None
  }
  for i, child in parent.children {
    if child.id == endpoint_id {
      return Some((parent.id, i))
    }
  }
  None
}

///|
fn sql_table_id_for_endpoint(
  object_by_id : Map[String, Object],
  endpoint_id : String,
) -> String? {
  match object_by_id.get(endpoint_id) {
    Some(obj) =>
      if obj.shape_type == ShapeType::SqlTable {
        Some(obj.id)
      } else {
        match sql_table_endpoint_info(object_by_id, endpoint_id) {
          Some((table_id, _)) => Some(table_id)
          None => None
        }
      }
    None =>
      match sql_table_endpoint_info(object_by_id, endpoint_id) {
        Some((table_id, _)) => Some(table_id)
        None => None
      }
  }
}

///|
/// Handle root-level shape declaration (e.g., shape: sequence_diagram).
///
/// Note: any structural normalization required for layout (like re-parenting
/// top-level nodes for sequence diagrams) is done in the layout pipeline.
fn handle_root_shape(
  graph : Graph,
  ir : @ir.Map,
) -> Unit raise GraphCompileError {
  process_special_fields(graph.root, ir)
}

///|
fn apply_sequence_defaults(graph : Graph) -> Unit {
  if graph.root.shape_type != ShapeType::SequenceDiagram {
    return
  }
  let child_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    for child in obj.children {
      child_ids[child.id] = true
    }
  }
  for obj in graph.objects {
    if child_ids.contains(obj.id) {
      continue
    }
    let has_messages = object_has_incident_edge(graph, obj.id)
    if obj.style.fill is None {
      obj.style.fill = Some(if has_messages { "B5" } else { "N7" })
    }
    if obj.style.stroke is None {
      obj.style.stroke = Some("B1")
    }
  }
  for edge in graph.edges {
    if edge.style.stroke is None {
      edge.style.stroke = Some("B1")
    }
    if edge.style.font_color is None {
      edge.style.font_color = Some("N2")
    }
    if edge.style.italic is None {
      edge.style.italic = Some(true)
    }
    if edge.style.curved is None {
      edge.style.curved = Some(false)
    }
  }
}

///|
fn object_has_incident_edge(graph : Graph, object_id : String) -> Bool {
  for edge in graph.edges {
    if edge.src_id == object_id || edge.dst_id == object_id {
      return true
    }
  }
  false
}

///|
fn apply_d2_color_defaults(graph : Graph) -> Unit {
  for obj in graph.objects {
    if obj.style.fill is None {
      obj.style.fill = Some(d2_default_object_fill(obj))
    }
    if obj.style.stroke is None {
      obj.style.stroke = Some(d2_default_object_stroke(obj))
    }
  }
  for edge in graph.edges {
    if edge.style.stroke is None {
      edge.style.stroke = Some(d2_default_edge_stroke(edge))
    }
  }
}

///|
fn d2_default_object_fill(obj : Object) -> String {
  let level = object_depth_from_id(obj.id)
  let shape = obj.shape_type
  if shape == ShapeType::SqlTable || shape == ShapeType::Class {
    return "N7"
  }
  if shape == ShapeType::Rectangle ||
    shape == ShapeType::Square ||
    shape == ShapeType::Circle ||
    shape == ShapeType::Oval ||
    shape == ShapeType::C4Container {
    if level == 1 {
      if obj.children.is_empty() {
        return "B6"
      }
      return "B4"
    }
    if level == 2 {
      return "B5"
    }
    if level == 3 {
      return "B6"
    }
    return "N7"
  }
  if shape == ShapeType::Cylinder ||
    shape == ShapeType::StoredData ||
    shape == ShapeType::Package {
    if level == 1 {
      return "AA4"
    }
    return "AA5"
  }
  if shape == ShapeType::Step ||
    shape == ShapeType::Page ||
    shape == ShapeType::Document {
    if level == 1 {
      return "AB4"
    }
    return "AB5"
  }
  if shape == ShapeType::Person || shape == ShapeType::C4Person {
    return "B3"
  }
  if shape == ShapeType::Diamond {
    return "N4"
  }
  if shape == ShapeType::Cloud || shape == ShapeType::Callout {
    return "N7"
  }
  if shape == ShapeType::Queue ||
    shape == ShapeType::Parallelogram ||
    shape == ShapeType::Hexagon {
    return "N5"
  }
  "N7"
}

///|
fn d2_default_object_stroke(obj : Object) -> String {
  let shape = obj.shape_type
  if shape == ShapeType::Code || shape == ShapeType::Text {
    return "N1"
  }
  if shape == ShapeType::Class || shape == ShapeType::SqlTable {
    return "N1"
  }
  let dash = match obj.style.stroke_dash {
    Some(v) => v
    None => 0.0
  }
  if dash != 0.0 {
    return "B2"
  }
  "B1"
}

///|
fn d2_default_edge_stroke(edge : Edge) -> String {
  let dash = match edge.style.stroke_dash {
    Some(v) => v
    None => 0.0
  }
  if dash != 0.0 {
    return "B2"
  }
  "B1"
}

///|
fn apply_d2_text_defaults(graph : Graph) -> Unit {
  let sequence_root = graph.root.shape_type == ShapeType::SequenceDiagram
  for obj in graph.objects {
    let is_container = !obj.children.is_empty()
    if obj.style.font_size is None {
      let default_font_size = if obj.shape_type == ShapeType::Class ||
        obj.shape_type == ShapeType::SqlTable {
        20
      } else if is_container && obj.shape_type != ShapeType::Text {
        container_level_label_size(object_depth_from_id(obj.id))
      } else {
        16
      }
      obj.style.font_size = Some(default_font_size)
    }
    if obj.style.bold is None {
      let default_bold = if sequence_root {
        false
      } else if obj.shape_type == ShapeType::Class ||
        obj.shape_type == ShapeType::SqlTable {
        false
      } else {
        !is_container && obj.shape_type != ShapeType::Text
      }
      obj.style.bold = Some(default_bold)
    }
    if obj.style.italic is None {
      obj.style.italic = Some(false)
    }
  }
}

///|
fn object_depth_from_id(id : String) -> Int {
  let mut depth = 1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      depth = depth + 1
    }
  }
  depth
}

///|
fn container_level_label_size(level : Int) -> Int {
  if level <= 1 {
    28
  } else if level == 2 {
    24
  } else if level == 3 {
    20
  } else {
    16
  }
}
