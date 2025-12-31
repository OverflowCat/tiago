///|
/// Import Resolution for D2 IR
///
/// Handles `@path/to/file.d2` import statements.
/// Imports are resolved by a user-provided resolver function.

///|
/// Import resolver function type
/// Takes an import path and returns the file content, or None if not found
pub struct ImportResolver((String) -> String?)

///|
/// Compile an AST Map with import resolution
pub fn compile_with_imports(
  ast : @ast.Map,
  resolver : ImportResolver,
) -> Map raise CompileError {
  let ir = Map::new()
  compile_map_nodes_with_imports(ir, ast.nodes, resolver)
  // Resolve variable substitutions
  ir.resolve_substitutions()
  ir
}

///|
fn compile_map_nodes_with_imports(
  ir : Map,
  nodes : Array[@ast.MapNode],
  resolver : ImportResolver,
) -> Unit raise CompileError {
  for node in nodes {
    match node {
      @ast.MapNode::Comment(_, _) => ()
      @ast.MapNode::BlockComment(_, _) => ()
      @ast.MapNode::Substitution(_) => ()
      @ast.MapNode::Import(imp) => compile_import(ir, imp, resolver)
      @ast.MapNode::Key(key) => compile_key_with_imports(ir, key, resolver)
    }
  }
}

///|
/// Compile an import statement
fn compile_import(
  ir : Map,
  imp : @ast.Import,
  resolver : ImportResolver,
) -> Unit raise CompileError {
  // Build the import path
  let path = build_import_path(imp)
  // Resolve the import
  match (resolver.0)(path) {
    Some(content) => {
      // Parse the imported content
      let (import_ast, errors) = @parser.parse(content)
      if !errors.is_empty() {
        raise CompileError::ImportError(
          "parse error in imported file '\{path}': \{errors}",
        )
      }
      // Compile and merge the imported content
      if imp.spread {
        // Spread import: merge all fields at current level
        compile_map_nodes_with_imports(ir, import_ast.nodes, resolver)
      } else {
        // Normal import: create a field with the imported content
        let import_ir = Map::new()
        compile_map_nodes_with_imports(import_ir, import_ast.nodes, resolver)
        // Use filename as field name (without extension)
        let field_name = extract_filename(path)
        let field = ir.ensure_field(field_name)
        field.composite = Some(Composite::Map(import_ir))
      }
    }
    None =>
      raise CompileError::ImportError("could not resolve import '\{path}'")
  }
}

///|
/// Build import path from AST Import
fn build_import_path(imp : @ast.Import) -> String {
  let buf = StringBuilder::new()
  buf.write_string(imp.pre)
  for i, s in imp.path {
    if i > 0 {
      buf.write_char('/')
    }
    buf.write_string(s.content())
  }
  buf.to_string()
}

///|
/// Extract filename without extension from path
fn extract_filename(path : String) -> String {
  // Find last /
  let mut last_slash = -1
  for i in 0..<path.length() {
    if path.code_unit_at(i) == '/'.to_int().to_uint16() {
      last_slash = i
    }
  }
  let start = last_slash + 1
  // Find last .
  let mut last_dot = path.length()
  for i in start..<path.length() {
    if path.code_unit_at(i) == '.'.to_int().to_uint16() {
      last_dot = i
    }
  }
  // Extract filename
  let buf = StringBuilder::new()
  for i in start..<last_dot {
    buf.write_char(path.code_unit_at(i).to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Compile a key with import handling for values
fn compile_key_with_imports(
  ir : Map,
  key : @ast.Key,
  resolver : ImportResolver,
) -> Unit raise CompileError {
  // Handle ampersand filters
  if key.ampersand || key.not_ampersand {
    return
  }
  // Handle edges first
  if key.edges.length() > 0 {
    compile_edges_with_imports(ir, key, resolver)
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
  // Set value (with import handling)
  match key.value {
    Some(value) => compile_value_with_imports(field, value, resolver)
    None => ()
  }
}

///|
fn compile_value_with_imports(
  field : Field,
  value : @ast.Value,
  resolver : ImportResolver,
) -> Unit raise CompileError {
  match value {
    @ast.Value::Scalar(s) => field.primary = Some(compile_scalar(s))
    @ast.Value::Map(m) => {
      let ir_map = Map::new()
      compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
      field.composite = Some(Composite::Map(ir_map))
    }
    @ast.Value::Array(a) => {
      let ir_array = compile_array_with_imports(a, resolver)
      field.composite = Some(Composite::Array(ir_array))
    }
    @ast.Value::Import(imp) => {
      // Value-level import
      let path = build_import_path(imp)
      match (resolver.0)(path) {
        Some(content) => {
          let (import_ast, errors) = @parser.parse(content)
          if !errors.is_empty() {
            raise CompileError::ImportError(
              "parse error in imported file '\{path}'",
            )
          }
          let import_ir = Map::new()
          compile_map_nodes_with_imports(import_ir, import_ast.nodes, resolver)
          field.composite = Some(Composite::Map(import_ir))
        }
        None =>
          raise CompileError::ImportError("could not resolve import '\{path}'")
      }
    }
    @ast.Value::BlockScalar(label, m) => {
      match label {
        @ast.Value::Scalar(s) => field.primary = Some(compile_scalar(s))
        _ => ()
      }
      let ir_map = Map::new()
      compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
      field.composite = Some(Composite::Map(ir_map))
    }
  }
}

///|
fn compile_array_with_imports(
  arr : @ast.ArrayValue,
  resolver : ImportResolver,
) -> IRArray raise CompileError {
  let values : Array[Value] = []
  for node in arr.nodes {
    match node {
      @ast.ArrayNode::Comment(_, _) => ()
      @ast.ArrayNode::BlockComment(_, _) => ()
      @ast.ArrayNode::Substitution(_) => ()
      @ast.ArrayNode::Import(imp) => {
        // Import in array context
        let path = build_import_path(imp)
        match (resolver.0)(path) {
          Some(content) => {
            let (import_ast, errors) = @parser.parse(content)
            if !errors.is_empty() {
              continue
            }
            let import_ir = Map::new()
            compile_map_nodes_with_imports(
              import_ir,
              import_ast.nodes,
              resolver,
            )
            values.push(Value::Map(import_ir))
          }
          None => ()
        }
      }
      @ast.ArrayNode::Value(v) => {
        let compiled = compile_ast_value_with_imports(v, resolver)
        values.push(compiled)
      }
    }
  }
  IRArray::new(values)
}

///|
fn compile_ast_value_with_imports(
  value : @ast.Value,
  resolver : ImportResolver,
) -> Value raise CompileError {
  match value {
    @ast.Value::Scalar(s) => Value::Scalar(compile_scalar(s))
    @ast.Value::Map(m) => {
      let ir_map = Map::new()
      compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
      Value::Map(ir_map)
    }
    @ast.Value::Array(a) =>
      Value::Array(compile_array_with_imports(a, resolver))
    @ast.Value::Import(imp) => {
      let path = build_import_path(imp)
      match (resolver.0)(path) {
        Some(content) => {
          let (import_ast, errors) = @parser.parse(content)
          if !errors.is_empty() {
            return Value::Scalar(Scalar::null())
          }
          let import_ir = Map::new()
          compile_map_nodes_with_imports(import_ir, import_ast.nodes, resolver)
          Value::Map(import_ir)
        }
        None => Value::Scalar(Scalar::null())
      }
    }
    @ast.Value::BlockScalar(_, m) => {
      let ir_map = Map::new()
      compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
      Value::Map(ir_map)
    }
  }
}

///|
fn compile_edges_with_imports(
  ir : Map,
  key : @ast.Key,
  resolver : ImportResolver,
) -> Unit raise CompileError {
  for edge in key.edges {
    let src_path = edge.src.to_strings()
    let dst_path = edge.dst.to_strings()
    let edge_id = EdgeID::new(
      src_path,
      dst_path,
      edge.src_arrow == "<",
      edge.dst_arrow == ">",
    )
    let existing = ir.find_edges(edge_id)
    if existing.length() > 0 {
      let e = existing[0]
      e.references.push(EdgeReference::new(0, true))
      match key.value {
        Some(value) =>
          match value {
            @ast.Value::Scalar(s) => e.primary = Some(compile_scalar(s))
            @ast.Value::Map(m) => {
              let ir_map = Map::new()
              compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
              e.map = Some(ir_map)
            }
            @ast.Value::BlockScalar(label, m) => {
              match label {
                @ast.Value::Scalar(s) => e.primary = Some(compile_scalar(s))
                _ => ()
              }
              let ir_map = Map::new()
              compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
              e.map = Some(ir_map)
            }
            _ => ()
          }
        None => ()
      }
    } else {
      let mut primary : Scalar? = None
      let mut edge_map : Map? = None
      match key.value {
        Some(value) =>
          match value {
            @ast.Value::Scalar(s) => primary = Some(compile_scalar(s))
            @ast.Value::Map(m) => {
              let ir_map = Map::new()
              compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
              edge_map = Some(ir_map)
            }
            @ast.Value::BlockScalar(label, m) => {
              match label {
                @ast.Value::Scalar(s) => primary = Some(compile_scalar(s))
                _ => ()
              }
              let ir_map = Map::new()
              compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
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
      ensure_field_path(ir, src_path)
      ensure_field_path(ir, dst_path)
    }
  }
}
