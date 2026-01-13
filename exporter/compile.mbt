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
  stroke_dash : Double?
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
  style : Style
  children : Array[Object]
  z_index : Int
  mut icon : String?
  mut tooltip : String?
  mut link : String?
  classes : Array[String]
  mut grid_rows : Int?
  mut grid_columns : Int?
  mut grid_gap : Double?
  mut horizontal_gap : Double?
  mut vertical_gap : Double?
  mut grid_column_span : Int?
  mut grid_row_span : Int?
  mut near : String?
} derive(Show)

///|
fn Object::new(id : String) -> Object {
  {
    id,
    label: id,
    shape_type: Rectangle,
    style: Style::new(),
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
  mut src_anchor : String?
  mut dst_anchor : String?
  mut label : String
  style : Style
  mut bend_points : Array[Point]?
  is_curve : Bool
  z_index : Int
  mut reference_count : Int
  mut src_column_index : Int?
  mut dst_column_index : Int?
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
fn Graph::find_object(self : Graph, id : String) -> Object? {
  for obj in self.objects {
    if obj.id == id {
      return Some(obj)
    }
  }
  None
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
  @graph.ObjectInput::from_parts(
    obj.id,
    obj.label,
    obj.shape_type,
    style_to_input(obj.style),
    None,
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
  )
}

///|
fn edge_to_input(edge : Edge) -> @graph.EdgeInput {
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
    edge.src_arrowhead,
    edge.dst_arrowhead,
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
    object_to_input(graph.root),
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
} derive(Eq, Show)

///|
/// Compile an IR Map to GraphInput
pub fn compile(
  name : String,
  ir : @ir.Map,
) -> @graph.GraphInput raise GraphCompileError {
  let graph = Graph::new(name)
  // Extract class definitions
  let classes = extract_classes(ir)
  // First pass: create all objects
  compile_objects(graph, ir, "", classes)
  // Second pass: create all edges
  compile_edges(graph, ir)
  // Third pass: compile layers, scenarios, and steps
  compile_layers(graph, ir, classes)
  compile_scenarios(graph, ir, classes)
  compile_steps(graph, ir, classes)
  // Handle root-level shape (e.g., shape: sequence_diagram)
  handle_root_shape(graph, ir)
  // Compile legend configuration (and/or auto-generate legend)
  compile_legend(graph, ir)
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
fn compile_objects(
  graph : Graph,
  ir : @ir.Map,
  prefix : String,
  classes : Map[String, @ir.Map],
) -> Unit raise GraphCompileError {
  for field in ir.fields {
    // Skip reserved keywords (like 'classes', 'vars', etc.)
    if is_reserved_keyword(field.name) {
      continue
    }
    let id = if prefix == "" { field.name } else { "\{prefix}.\{field.name}" }
    let obj = Object::new(id)
    // Set label from primary value
    match field.primary {
      Some(scalar) => obj.label = scalar.to_string()
      None => ()
    }
    // Process composite (nested objects)
    match field.composite {
      Some(@ir.Composite::Map(inner)) => {
        // Apply class properties first (if specified)
        apply_class(obj, inner, classes)
        // Check for special fields (can override class)
        process_special_fields(obj, inner)
        // Recursively compile children
        compile_children(graph, obj, inner, id, classes)
      }
      _ => ()
    }
    graph.add_object(obj)
  }
}

///|
/// Apply class properties to an object
fn apply_class(
  obj : Object,
  ir : @ir.Map,
  classes : Map[String, @ir.Map],
) -> Unit {
  match ir.get_field("class") {
    Some(f) =>
      match f.primary {
        Some(s) =>
          match classes.get(s.to_string()) {
            Some(class_def) => process_special_fields(obj, class_def)
            None => ()
          }
        None => ()
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
    if is_reserved_keyword(field.name) {
      continue
    }
    let id = "\{prefix}.\{field.name}"
    let child = Object::new(id)
    // Set label - use field name as default, or primary value if provided
    match field.primary {
      Some(scalar) => child.label = scalar.to_string()
      None => child.label = field.name // Use field name, not full path
    }
    // Process nested composites
    match field.composite {
      Some(@ir.Composite::Map(inner)) => {
        // Apply class properties first (if specified)
        apply_class(child, inner, classes)
        // Check for special fields (can override class)
        process_special_fields(child, inner)
        // Recursively compile children
        compile_children(graph, child, inner, id, classes)
      }
      _ => ()
    }
    parent.add_child(child)
    graph.add_object(child)
  }
}

///|
fn process_special_fields(obj : Object, ir : @ir.Map) -> Unit {
  // Process shape
  match ir.get_field("shape") {
    Some(f) =>
      match f.primary {
        Some(s) => obj.shape_type = ShapeType::from_string(s.to_string())
        None => ()
      }
    None => ()
  }
  // Process label (override)
  match ir.get_field("label") {
    Some(f) =>
      match f.primary {
        Some(s) => obj.label = s.to_string()
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
        Some(@ir.Composite::Map(style_map)) =>
          process_style(obj.style, style_map)
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
  match ir.get_field("3d") {
    Some(f) =>
      match f.primary {
        Some(s) => style.three_d = Some(s.to_string() == "true")
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
/// Get the parent ID from a dotted field ID (e.g., "users.id" -> "users")
fn get_parent_id(id : String) -> String? {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot <= 0 {
    return None
  }
  let buf = StringBuilder::new()
  for i = 0; i < last_dot; i = i + 1 {
    buf.write_char(id[i].to_int().unsafe_to_char())
  }
  Some(buf.to_string())
}

///|
/// Get the field name from a dotted field ID (e.g., "users.id" -> "id")
fn get_field_name(id : String) -> String {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot < 0 || last_dot >= id.length() - 1 {
    return id
  }
  let buf = StringBuilder::new()
  for i = last_dot + 1; i < id.length(); i = i + 1 {
    buf.write_char(id[i].to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Find column index for a field ID within a SQL table
fn find_sql_column_index(graph : Graph, field_id : String) -> Int? {
  // Get parent ID
  let parent_id = match get_parent_id(field_id) {
    Some(p) => p
    None => return None
  }
  // Find parent object
  let parent = match graph.find_object(parent_id) {
    Some(p) => p
    None => return None
  }
  // Check if parent is SQL table
  if parent.shape_type != SqlTable {
    return None
  }
  // Get field name
  let field_name = get_field_name(field_id)
  // Find matching child index
  for i, child in parent.children {
    let child_name = get_field_name(child.id)
    if child_name == field_name {
      return Some(i)
    }
  }
  None
}

///|
fn compile_edges(graph : Graph, ir : @ir.Map) -> Unit {
  for i, edge in ir.edges {
    let src_id = edge.id.src_path.join(".")
    let dst_id = edge.id.dst_path.join(".")
    let graph_edge = Edge::new(
      i,
      src_id,
      dst_id,
      edge.id.src_arrow,
      edge.id.dst_arrow,
    )
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
        // Process style
        match m.get_field("style") {
          Some(f) =>
            match f.composite {
              Some(@ir.Composite::Map(style_map)) =>
                process_style(graph_edge.style, style_map)
              _ => ()
            }
          None => ()
        }
        // Process source-arrowhead
        if m.get_field("source-arrowhead") is Some(f) {
          if f.composite is Some(@ir.Composite::Map(arrowhead_map)) {
            if arrowhead_map.get_field("shape") is Some(shape_f) {
              if shape_f.primary is Some(s) {
                graph_edge.src_arrowhead = ArrowheadType::from_string(
                  s.to_string(),
                )
              }
            }
          } else if f.primary is Some(s) {
            // Simple value (shape directly)
            graph_edge.src_arrowhead = ArrowheadType::from_string(s.to_string())
          }
        }
        // Process target-arrowhead
        if m.get_field("target-arrowhead") is Some(f) {
          if f.composite is Some(@ir.Composite::Map(arrowhead_map)) {
            if arrowhead_map.get_field("shape") is Some(shape_f) {
              if shape_f.primary is Some(s) {
                graph_edge.dst_arrowhead = ArrowheadType::from_string(
                  s.to_string(),
                )
              }
            }
          } else if f.primary is Some(s) {
            // Simple value (shape directly)
            graph_edge.dst_arrowhead = ArrowheadType::from_string(s.to_string())
          }
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
    // Set SQL table column indices for field-level connections
    graph_edge.src_column_index = find_sql_column_index(graph, src_id)
    graph_edge.dst_column_index = find_sql_column_index(graph, dst_id)
    graph.add_edge(graph_edge)
  }
}

///|
fn is_reserved_keyword(name : String) -> Bool {
  let keywords = [
    "label", "shape", "icon", "style", "tooltip", "link", "near", "width", "height",
    "direction", "constraint", "class", "classes", "vars", "grid-rows", "grid-columns",
    "grid-gap", "horizontal-gap", "vertical-gap", "grid-column-span", "grid-row-span",
    "layers", "scenarios", "steps", "legend",
  ]
  keywords.contains(name.to_lower())
}

///|
/// Compile legend configuration from root IR.
///
/// Supported root-level syntaxes:
/// - `legend: true` (auto)
/// - `legend: "Title"` (auto with title)
/// - `legend: { position: ..., title: ..., auto: true, entries: [...] }`
fn compile_legend(graph : Graph, ir : @ir.Map) -> Unit {
  let legend_field = ir.get_field("legend")
  guard legend_field is Some(f) else { return }

  // Parse config from scalar/map/array forms.
  let mut title : String? = None
  let mut position = LegendPosition::from_string("bottom-right")
  let mut auto = true
  let mut fill : String? = None
  let mut stroke : String? = None
  let mut padding : Double? = None
  let mut entry_gap : Double? = None
  let mut icon_size : Double? = None
  let mut explicit_entries : Array[LegendEntry] = []
  match f.primary {
    Some(p) => {
      let s = p.to_string()
      match s.to_lower() {
        "false" | "none" | "hidden" => {
          auto = false
          position = LegendPosition::from_string("hidden")
        }
        "true" => ()
        _ => title = Some(s)
      }
    }
    None => ()
  }
  match f.composite {
    Some(@ir.Composite::Array(arr)) => {
      explicit_entries = parse_legend_entries(arr)
      auto = false
    }
    Some(@ir.Composite::Map(m)) => {
      // title
      match m.get_field("title") {
        Some(tf) =>
          match tf.primary {
            Some(t) => title = Some(t.to_string())
            None => ()
          }
        None => ()
      }
      // position
      match m.get_field("position") {
        Some(pf) =>
          match pf.primary {
            Some(p) => position = LegendPosition::from_string(p.to_string())
            None => ()
          }
        None => ()
      }
      // auto
      match m.get_field("auto") {
        Some(af) =>
          match af.primary {
            Some(a) => auto = parse_bool(a.to_string()).unwrap_or(auto)
            None => ()
          }
        None => ()
      }
      // fill/stroke
      match m.get_field("fill") {
        Some(ff) =>
          match ff.primary {
            Some(v) => fill = Some(v.to_string())
            None => ()
          }
        None => ()
      }
      match m.get_field("stroke") {
        Some(sf) =>
          match sf.primary {
            Some(v) => stroke = Some(v.to_string())
            None => ()
          }
        None => ()
      }
      // padding/entry-gap/icon-size
      match m.get_field("padding") {
        Some(pf) =>
          match pf.primary {
            Some(v) => padding = parse_double(v.to_string())
            None => ()
          }
        None => ()
      }
      match m.get_field("entry-gap") {
        Some(gf) =>
          match gf.primary {
            Some(v) => entry_gap = parse_double(v.to_string())
            None => ()
          }
        None => ()
      }
      match m.get_field("icon-size") {
        Some(isf) =>
          match isf.primary {
            Some(v) => icon_size = parse_double(v.to_string())
            None => ()
          }
        None => ()
      }
      // entries
      match m.get_field("entries") {
        Some(ef) =>
          match ef.array() {
            Some(arr) => explicit_entries = parse_legend_entries(arr)
            None => ()
          }
        None => ()
      }
    }
    None => ()
  }

  // Build final legend.
  let title = if title is None &&
    position != LegendPosition::from_string("hidden") &&
    (auto || explicit_entries.is_empty()) {
    Some("Legend")
  } else {
    title
  }
  let legend = make_legend_with_overrides(
    title, position, fill, stroke, padding, entry_gap, icon_size,
  )
  if auto || explicit_entries.is_empty() {
    let entries = auto_generate_legend_entries(graph)
    for e in entries {
      legend.add_entry(e)
    }
  } else {
    for e in explicit_entries {
      legend.add_entry(e)
    }
  }
  graph.set_legend(legend)
}

///|
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
fn collect_legend_entries_into(
  g : Graph,
  shapes : Map[String, Bool],
  conns : Map[String, (ArrowheadType, ArrowheadType)],
) -> Unit {
  for obj in g.objects {
    shapes[obj.shape_type.to_shape_string()] = true
  }
  for e in g.edges {
    let key = "\{e.src_arrowhead.to_arrowhead_string()}|\{e.dst_arrowhead.to_arrowhead_string()}"
    conns[key] = (e.src_arrowhead, e.dst_arrowhead)
  }
}

///|
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
                // Compile this layer as a separate graph
                let layer_graph = Graph::new(field.name)
                compile_objects(layer_graph, layer_ir, "", classes)
                compile_edges(layer_graph, layer_ir)
                // Recursively compile nested layers/scenarios/steps
                compile_layers(layer_graph, layer_ir, classes)
                compile_scenarios(layer_graph, layer_ir, classes)
                compile_steps(layer_graph, layer_ir, classes)
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
                // Compile this scenario as a graph
                // Note: scenarios inherit from base graph + apply modifications
                let scenario_graph = Graph::new(field.name)
                compile_objects(scenario_graph, scenario_ir, "", classes)
                compile_edges(scenario_graph, scenario_ir)
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
                // Compile this step as a graph
                let step_graph = Graph::new(field.name)
                compile_objects(step_graph, step_ir, "", classes)
                compile_edges(step_graph, step_ir)
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
/// Handle root-level shape declaration (e.g., shape: sequence_diagram)
/// When the root has a special shape like sequence_diagram, we need to:
/// 1. Set the shape on graph.root
/// 2. Make all top-level objects children of graph.root
fn handle_root_shape(graph : Graph, ir : @ir.Map) -> Unit {
  match ir.get_field("shape") {
    Some(f) =>
      match f.primary {
        Some(s) => {
          let shape = s.to_string()
          graph.root.shape_type = ShapeType::from_string(shape)
          // For sequence diagrams, make all top-level objects children of root
          if shape == "sequence_diagram" {
            // Find all objects that are not children of other objects
            let root_obj_ids : Array[String] = []
            let child_ids : Array[String] = []
            // Collect all child IDs
            for obj in graph.objects {
              for child in obj.children {
                child_ids.push(child.id)
              }
            }
            // Find root objects (not children of any other object)
            for obj in graph.objects {
              if not(child_ids.contains(obj.id)) {
                root_obj_ids.push(obj.id)
              }
            }
            // Make root objects children of graph.root
            for id in root_obj_ids {
              for obj in graph.objects {
                if obj.id == id {
                  graph.root.add_child(obj)
                  break
                }
              }
            }
          }
        }
        None => ()
      }
    None => ()
  }
}
