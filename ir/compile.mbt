///|
/// Compile AST to IR
///
/// This module converts the parsed AST into IR, resolving:
/// - Variable substitutions
/// - Import statements
/// - Glob patterns

///|
/// Compilation error
pub(all) suberror CompileError {
  InvalidKey(String)
  InvalidValue(String)
  DuplicateField(String)
  InvalidSubstitution(String)
  ImportError(String)
} derive(Eq, Show)

///|
/// Compile an AST Map to IR Map
pub fn compile(ast : @ast.Map) -> Map raise CompileError {
  let ir = Map::new()
  compile_map_nodes(ir, ast.nodes)
  // Resolve variable substitutions
  ir.resolve_substitutions()
  ir
}

///|
fn compile_map_nodes(
  ir : Map,
  nodes : Array[@ast.MapNode],
) -> Unit raise CompileError {
  for node in nodes {
    match node {
      @ast.MapNode::Comment(_, _) => () // Skip comments
      @ast.MapNode::BlockComment(_, _) => () // Skip block comments
      @ast.MapNode::Substitution(_) => () // Handle at field level
      @ast.MapNode::Import(_) => () // TODO: handle imports
      @ast.MapNode::Key(key) => compile_key(ir, key)
    }
  }
}

///|
fn compile_key(ir : Map, key : @ast.Key) -> Unit raise CompileError {
  // Handle ampersand filters (they are evaluated during glob expansion)
  if key.ampersand || key.not_ampersand {
    // Filters are collected and applied during glob expansion
    // They don't create fields themselves
    return
  }
  // Handle edges first
  if key.edges.length() > 0 {
    compile_edges(ir, key)
    return
  }
  // Handle regular key
  guard key.key is Some(key_path) else { return }
  // Check for glob pattern
  if key_path.has_glob() {
    compile_glob_key(ir, key_path, key)
    return
  }
  let path = key_path.to_strings()
  if path.length() == 0 {
    return
  }
  // Navigate/create the field path
  let mut current_map = ir
  for i = 0; i < path.length() - 1; i = i + 1 {
    let name = path[i]
    let field = current_map.ensure_field(name)
    // Ensure field has a map composite
    match field.composite {
      Some(Composite::Map(m)) => current_map = m
      None => {
        let new_map = Map::new()
        field.composite = Some(Composite::Map(new_map))
        current_map = new_map
      }
      Some(_) =>
        raise CompileError::InvalidKey("field already has non-map value")
    }
  }
  // Set the final field
  let final_name = path[path.length() - 1]
  let field = current_map.ensure_field(final_name)
  // Set primary value
  match key.primary {
    Some(scalar) => field.primary = Some(compile_scalar(scalar))
    None => ()
  }
  // Set value
  match key.value {
    Some(value) => compile_value(field, value)
    None => ()
  }
}

///|
/// Compile a key with glob pattern
fn compile_glob_key(ir : Map, key_path : @ast.KeyPath, key : @ast.Key) -> Unit {
  // Find the glob element and extract pattern
  let (pattern, remaining_path) = extract_glob_and_path(key_path)
  if pattern.length() == 0 {
    return // No valid glob pattern
  }
  // Collect filters from the value map if present
  let filters = collect_filters_from_value(key)
  // Build properties map from the remaining path and value
  let properties = build_nested_properties(remaining_path, key)
  // Apply glob pattern with filters
  ir.apply_glob_properties(pattern, properties, filters)
}

///|
/// Extract glob pattern and remaining path from key path
/// Returns (pattern, remaining_path) where pattern is from the glob element
/// and remaining_path is the rest of the key path after the glob
fn extract_glob_and_path(
  key_path : @ast.KeyPath,
) -> (Array[String], Array[String]) {
  let path = key_path.path
  let mut glob_index = -1
  let mut pattern : Array[String] = []
  // Find the first element with a glob pattern
  for i, elem in path {
    match elem {
      @ast.StringValue::Unquoted(us) =>
        if us.pattern.length() > 0 {
          pattern = us.pattern
          glob_index = i
          break
        }
      _ => ()
    }
  }
  if glob_index < 0 {
    return ([], [])
  }
  // Collect remaining path elements after the glob
  let remaining : Array[String] = []
  for i = glob_index + 1; i < path.length(); i = i + 1 {
    remaining.push(path[i].content())
  }
  (pattern, remaining)
}

///|
/// Build nested properties map from remaining path and key value
fn build_nested_properties(
  remaining_path : Array[String],
  key : @ast.Key,
) -> Map {
  let props = Map::new()
  if remaining_path.length() == 0 {
    // No remaining path, use value directly
    match key.value {
      Some(@ast.Value::Map(m)) =>
        for node in m.nodes {
          match node {
            @ast.MapNode::Key(prop_key) =>
              if !prop_key.ampersand && !prop_key.not_ampersand {
                match prop_key.key {
                  Some(pk) => {
                    let prop_names = pk.to_strings()
                    if prop_names.length() > 0 {
                      let prop_field = Field::simple(prop_names[0])
                      match prop_key.value {
                        Some(@ast.Value::Scalar(sv)) =>
                          prop_field.primary = Some(compile_scalar(sv))
                        _ => ()
                      }
                      props.add_field(prop_field)
                    }
                  }
                  None => ()
                }
              }
            _ => ()
          }
        }
      _ => ()
    }
  } else {
    // Build nested structure: style.fill: red -> { style: { fill: red } }
    let mut current = props
    for i = 0; i < remaining_path.length() - 1; i = i + 1 {
      let name = remaining_path[i]
      let field = Field::simple(name)
      let inner = Map::new()
      field.composite = Some(Composite::Map(inner))
      current.add_field(field)
      current = inner
    }
    // Set the final value
    let final_name = remaining_path[remaining_path.length() - 1]
    let final_field = Field::simple(final_name)
    // Try key.primary first, then key.value for scalar
    match key.primary {
      Some(scalar) => final_field.primary = Some(compile_scalar(scalar))
      None =>
        // Check if value is a scalar
        match key.value {
          Some(@ast.Value::Scalar(sv)) =>
            final_field.primary = Some(compile_scalar(sv))
          _ => ()
        }
    }
    current.add_field(final_field)
  }
  props
}

///|
/// Collect filter conditions from the key's value map
fn collect_filters_from_value(key : @ast.Key) -> Array[(Bool, String, String)] {
  let filters : Array[(Bool, String, String)] = []
  match key.value {
    Some(@ast.Value::Map(m)) =>
      for node in m.nodes {
        match node {
          @ast.MapNode::Key(filter_key) =>
            if filter_key.ampersand || filter_key.not_ampersand {
              // This is a filter
              match (filter_key.key, filter_key.value) {
                (Some(fk), Some(@ast.Value::Scalar(sv))) => {
                  let filter_name = fk.to_strings().last().unwrap_or("")
                  let filter_value = compile_scalar(sv).to_string()
                  filters.push(
                    (filter_key.not_ampersand, filter_name, filter_value),
                  )
                }
                _ => ()
              }
            }
          _ => ()
        }
      }
    _ => ()
  }
  filters
}

///|
fn compile_edges(ir : Map, key : @ast.Key) -> Unit raise CompileError {
  for edge in key.edges {
    let src_path = edge.src.to_strings()
    let dst_path = edge.dst.to_strings()
    let edge_id = EdgeID::new(
      src_path,
      dst_path,
      edge.src_arrow == "<",
      edge.dst_arrow == ">",
    )
    // Check for existing edge
    let existing = ir.find_edges(edge_id)
    if existing.length() > 0 {
      // Add reference to existing edge
      let e = existing[0]
      e.references.push(EdgeReference::new(0, true))
      // Update value if provided
      match key.value {
        Some(value) =>
          match value {
            @ast.Value::Scalar(s) => e.primary = Some(compile_scalar(s))
            @ast.Value::Map(m) => {
              let ir_map = Map::new()
              compile_map_nodes(ir_map, m.nodes)
              e.map = Some(ir_map)
            }
            @ast.Value::BlockScalar(label, m) => {
              match label {
                @ast.Value::Scalar(s) => e.primary = Some(compile_scalar(s))
                _ => ()
              }
              let ir_map = Map::new()
              compile_map_nodes(ir_map, m.nodes)
              e.map = Some(ir_map)
            }
            _ => ()
          }
        None => ()
      }
    } else {
      // Create new edge
      let mut primary : Scalar? = None
      let mut edge_map : Map? = None
      match key.value {
        Some(value) =>
          match value {
            @ast.Value::Scalar(s) => primary = Some(compile_scalar(s))
            @ast.Value::Map(m) => {
              let ir_map = Map::new()
              compile_map_nodes(ir_map, m.nodes)
              edge_map = Some(ir_map)
            }
            @ast.Value::BlockScalar(label, m) => {
              match label {
                @ast.Value::Scalar(s) => primary = Some(compile_scalar(s))
                _ => ()
              }
              let ir_map = Map::new()
              compile_map_nodes(ir_map, m.nodes)
              edge_map = Some(ir_map)
            }
            _ => ()
          }
        None => ()
      }
      let new_edge = Edge::new(edge_id, primary, edge_map, [
        EdgeReference::new(0, true),
      ])
      ir.add_edge(new_edge)
      // Ensure source and destination fields exist
      ensure_field_path(ir, src_path)
      ensure_field_path(ir, dst_path)
    }
  }
}

///|
fn ensure_field_path(ir : Map, path : Array[String]) -> Unit {
  let mut current = ir
  for name in path {
    let field = current.ensure_field(name)
    match field.composite {
      Some(Composite::Map(m)) => current = m
      None => {
        let new_map = Map::new()
        field.composite = Some(Composite::Map(new_map))
        current = new_map
      }
      Some(_) => break // Field has non-map composite, stop
    }
  }
}

///|
fn compile_value(field : Field, value : @ast.Value) -> Unit raise CompileError {
  match value {
    @ast.Value::Scalar(s) => field.primary = Some(compile_scalar(s))
    @ast.Value::Map(m) => {
      let ir_map = Map::new()
      compile_map_nodes(ir_map, m.nodes)
      field.composite = Some(Composite::Map(ir_map))
    }
    @ast.Value::Array(a) => {
      let ir_array = compile_array(a)
      field.composite = Some(Composite::Array(ir_array))
    }
    @ast.Value::Import(_) => () // TODO: handle imports
    @ast.Value::BlockScalar(label, m) => {
      // "name: Label { props }" - Label is primary, props is composite
      match label {
        @ast.Value::Scalar(s) => field.primary = Some(compile_scalar(s))
        _ => ()
      }
      let ir_map = Map::new()
      compile_map_nodes(ir_map, m.nodes)
      field.composite = Some(Composite::Map(ir_map))
    }
  }
}

///|
fn compile_array(arr : @ast.ArrayValue) -> IRArray raise CompileError {
  let values : Array[Value] = []
  for node in arr.nodes {
    match node {
      @ast.ArrayNode::Comment(_, _) => ()
      @ast.ArrayNode::BlockComment(_, _) => ()
      @ast.ArrayNode::Substitution(_) => () // TODO: handle substitutions
      @ast.ArrayNode::Import(_) => () // TODO: handle imports
      @ast.ArrayNode::Value(v) => values.push(compile_ast_value(v))
    }
  }
  IRArray::new(values)
}

///|
fn compile_ast_value(value : @ast.Value) -> Value raise CompileError {
  match value {
    @ast.Value::Scalar(s) => Value::Scalar(compile_scalar(s))
    @ast.Value::Map(m) => {
      let ir_map = Map::new()
      compile_map_nodes(ir_map, m.nodes)
      Value::Map(ir_map)
    }
    @ast.Value::Array(a) => Value::Array(compile_array(a))
    @ast.Value::Import(_) => Value::Scalar(Scalar::null()) // TODO: handle imports
    @ast.Value::BlockScalar(_, m) => {
      // For arrays, just use the map part (label is ignored in array context)
      let ir_map = Map::new()
      compile_map_nodes(ir_map, m.nodes)
      Value::Map(ir_map)
    }
  }
}

///|
fn compile_scalar(scalar : @ast.Scalar) -> Scalar {
  match scalar {
    @ast.Scalar::Null(_) => Scalar::null()
    @ast.Scalar::Boolean(_, b) => Scalar::bool(b)
    @ast.Scalar::Number(_, n) => Scalar::number(n)
    @ast.Scalar::String(s) => Scalar::string(s.content())
  }
}
