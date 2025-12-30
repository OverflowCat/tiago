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
  // Handle edges first
  if key.edges.length() > 0 {
    compile_edges(ir, key)
    return
  }
  // Handle regular key
  guard key.key is Some(key_path) else { return }
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
