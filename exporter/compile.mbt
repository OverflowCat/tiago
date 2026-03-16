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
  mut label : String
  mut shape_type : ShapeType
  mut raw_shape : String?
  style : Style
  children : Array[Object]
  z_index : Int
  mut icon : String?
  mut tooltip : String?
  mut link : String?
  classes : Array[String]
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
fn Object::new(id : String) -> Object {
  {
    id,
    label: id,
    shape_type: Rectangle,
    raw_shape: None,
    style: Style::new(),
    children: [],
    z_index: 0,
    icon: None,
    tooltip: None,
    link: None,
    classes: [],
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
    stroke: Some("#cccccc"),
    padding: 12.0,
    entry_gap: 8.0,
    icon_size: 20.0,
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
    child_ids.push(child.id)
  }
  let classes : Array[String] = []
  for c in obj.classes {
    classes.push(c)
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
  )
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
      nested_child_ids[child.id] = true
    }
  }
  let root_child_ids : Array[String] = []
  for obj in graph.objects {
    if !nested_child_ids.contains(obj.id) {
      root_child_ids.push(obj.id)
    }
  }
  let root_classes : Array[String] = []
  for c in graph.root.classes {
    root_classes.push(c)
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
  // D2 parity: SQL table column endpoints are represented as table endpoints
  // with source/target column indices.
  normalize_sql_table_edge_endpoints_recursive(graph)
  // Semantic validation pass aligned with D2 compiler behavior.
  validate_semantics(graph)
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
  compile_objects(graph, ir, "", classes)
  compile_edges(graph, ir)
  compile_layers(graph, ir, classes)
  compile_scenarios(graph, ir, classes)
  compile_steps(graph, ir, classes)
  handle_root_shape(graph, ir)
  apply_d2_text_defaults(graph)
  apply_sequence_defaults(graph)
  apply_d2_color_defaults(graph)
  compile_legend(graph, ir, classes)
}

///|
fn compile_objects(
  graph : Graph,
  ir : @ir.Map,
  prefix : String,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  for field in ir.fields {
    // Skip reserved keywords (like 'classes', 'vars', etc.)
    if field.is_reserved_keyword_name() {
      continue
    }
    let id = if prefix == "" { field.name } else { "\{prefix}.\{field.name}" }
    let obj = Object::new(id)
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
        process_special_fields(obj, inner)
        // D2 registers objects in encounter order before descending.
        graph.add_object(obj)
        // Recursively compile children
        compile_children(graph, obj, inner, id, classes)
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
          Some(class_def) => process_special_fields(obj, class_def)
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
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  for field in ir.fields {
    // Skip reserved keywords
    if field.is_reserved_keyword_name() {
      continue
    }
    let id = "\{prefix}.\{field.name}"
    let child = Object::new(id)
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
        process_special_fields(child, inner)
        if parent.shape_type == ShapeType::SqlTable {
          let constraints = extract_sql_constraints(inner)
          for c in constraints {
            if c.length() > 0 {
              child.classes.push("sql_constraint:" + c)
            }
          }
        }
        parent.add_child(child)
        graph.add_object(child)
        // Recursively compile children
        compile_children(graph, child, inner, id, classes)
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
    Some(f) =>
      match f.primary {
        Some(s) => set_object_label_from_scalar(obj, s)
        None => ()
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
    Some(f) =>
      match f.primary {
        Some(s) => obj.icon = Some(s.to_string())
        None => ()
      }
    None => ()
  }
  // Process tooltip
  match ir.get_field("tooltip") {
    Some(f) =>
      match f.primary {
        Some(s) => obj.tooltip = Some(s.to_string())
        None => ()
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
fn compile_edges_in_map(
  graph : Graph,
  ir : @ir.Map,
  prefix : String,
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
        next_index = compile_edges_in_map(
          graph, inner, child_prefix, next_index,
        )
      }
      _ => ()
    }
  }
  for edge in ir.edges {
    let src_id = join_path(prefix, edge.id.src_path)
    let dst_id = join_path(prefix, edge.id.dst_path)
    let graph_edge = Edge::new(
      next_index,
      src_id,
      dst_id,
      edge.id.src_arrow,
      edge.id.dst_arrow,
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
  compile_edges_in_map(graph, ir, "", 0) |> ignore
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
  let object_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    object_ids[obj.id] = true
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
        if !object_ids.contains(near_raw) {
          raise Semantic(
            "near key \"\{near_raw}\" must be the absolute path to a shape or one of the following constants: \{near_constants_message()}",
          )
        }
        if near_raw == obj.id || obj.id.has_prefix(near_raw + ".") {
          raise Semantic("near keys cannot be set to an ancestor")
        }
        if near_raw.has_prefix(obj.id + ".") {
          raise Semantic("near keys cannot be set to an descendant")
        }
      }
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
  compile_objects(legend_graph, legend_map, "", classes)
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
    match edge.style.opacity {
      Some(op) => if op == 0.0 { continue }
      None => ()
    }
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
        if edge.label.length() == 0 {
          connection_label(src_arrowhead, dst_arrowhead)
        } else {
          edge.label
        },
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
  match ir.get_field("layers") {
    Some(f) =>
      match f.composite {
        Some(@ir.Composite::Map(layers_map)) =>
          for field in layers_map.fields {
            match field.composite {
              Some(@ir.Composite::Map(layer_ir)) => {
                let layer_graph = Graph::new(field.name)
                compile_board_graph(layer_graph, layer_ir, classes)
                graph.add_layer(Layer::new(field.name, layer_graph))
              }
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
}

///|
/// Compile scenarios from IR
fn compile_scenarios(
  graph : Graph,
  ir : @ir.Map,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  match ir.get_field("scenarios") {
    Some(f) =>
      match f.composite {
        Some(@ir.Composite::Map(scenarios_map)) =>
          for field in scenarios_map.fields {
            match field.composite {
              Some(@ir.Composite::Map(scenario_ir)) => {
                let scenario_graph = Graph::new(field.name)
                compile_board_graph(scenario_graph, scenario_ir, classes)
                graph.add_scenario(Scenario::new(field.name, scenario_graph))
              }
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
}

///|
/// Compile steps from IR
fn compile_steps(
  graph : Graph,
  ir : @ir.Map,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  match ir.get_field("steps") {
    Some(f) =>
      match f.composite {
        Some(@ir.Composite::Map(steps_map)) =>
          for field in steps_map.fields {
            match field.composite {
              Some(@ir.Composite::Map(step_ir)) => {
                let step_graph = Graph::new(field.name)
                compile_board_graph(step_graph, step_ir, classes)
                graph.add_step(Step::new(field.name, step_graph))
              }
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
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
