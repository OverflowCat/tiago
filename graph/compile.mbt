///|
/// Compile IR to Graph
///
/// Converts the IR representation into a Graph suitable for
/// layout and rendering.

///|
/// Compilation error
pub(all) suberror GraphCompileError {
  InvalidShape(String)
  InvalidStyle(String)
  MissingObject(String)
} derive(Eq, Show)

///|
/// Compile an IR Map to Graph
pub fn compile(name : String, ir : @ir.Map) -> Graph raise GraphCompileError {
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
  graph
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
    "layers", "scenarios", "steps",
  ]
  keywords.contains(name.to_lower())
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
