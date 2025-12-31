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
  // First pass: create all objects
  compile_objects(graph, ir, "")
  // Second pass: create all edges
  compile_edges(graph, ir)
  graph
}

///|
fn compile_objects(
  graph : Graph,
  ir : @ir.Map,
  prefix : String,
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
        // Check for special fields
        process_special_fields(obj, inner)
        // Recursively compile children
        compile_children(graph, obj, inner, id)
      }
      _ => ()
    }
    graph.add_object(obj)
  }
}

///|
fn compile_children(
  graph : Graph,
  parent : Object,
  ir : @ir.Map,
  prefix : String,
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
        process_special_fields(child, inner)
        compile_children(graph, child, inner, id)
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
        Some(s) => obj.shape = s.to_string()
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
    // Process edge style from map
    match edge.map {
      Some(m) =>
        match m.get_field("style") {
          Some(f) =>
            match f.composite {
              Some(@ir.Composite::Map(style_map)) =>
                process_style(graph_edge.style, style_map)
              _ => ()
            }
          None => ()
        }
      None => ()
    }
    graph.add_edge(graph_edge)
  }
}

///|
fn is_reserved_keyword(name : String) -> Bool {
  let keywords = [
    "label", "shape", "icon", "style", "tooltip", "link", "near", "width", "height",
    "direction", "constraint", "class", "classes", "vars", "grid-rows", "grid-columns",
    "grid-gap", "horizontal-gap", "vertical-gap",
  ]
  keywords.contains(name.to_lower())
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
