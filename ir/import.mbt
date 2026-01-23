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
/// Import Resolution for diago IR
///
/// Handles `@path/to/file.d2` import statements.
/// Imports are resolved by a user-provided resolver function.

///|
/// Import resolver function type
/// Takes an import path and returns the file content, or None if not found
pub struct ImportResolver((String) -> String?)

///|
/// Create a new import resolver from a function
pub fn ImportResolver::new(f : (String) -> String?) -> ImportResolver {
  ImportResolver(f)
}

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
        let field = Field::new(
          field.name,
          field.primary,
          Some(Composite::Map(import_ir)),
          field.references,
        )
        ir.set_field(field)
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
    let elem = key_path.path[i]
    let field = record_field_reference(
      current_map,
      current_map.ensure_field(name),
      elem,
      i,
      false,
    )
    match field.composite {
      Some(Composite::Map(m)) => current_map = m
      None => {
        let new_map = Map::new()
        let field = Field::new(
          field.name,
          field.primary,
          Some(Composite::Map(new_map)),
          field.references,
        )
        current_map.set_field(field)
        current_map = new_map
      }
      Some(_) =>
        raise CompileError::InvalidKey("field already has non-map value")
    }
  }
  // Set the final field
  let last_index = path.length() - 1
  let final_name = path[last_index]
  let last_elem = key_path.path[last_index]
  let field0 = current_map.ensure_field(final_name)
  let field1 = if key.primary is Some(_) {
    record_field_reference(current_map, field0, last_elem, last_index, true)
  } else {
    field0
  }
  let field = if key.value is Some(_) {
    record_field_reference(current_map, field1, last_elem, last_index, false)
  } else {
    field1
  }
  // Set primary value
  let field = match key.primary {
    Some(scalar) =>
      Field::new(
        field.name,
        Some(compile_scalar(scalar)),
        field.composite,
        field.references,
      )
    None => field
  }
  // Set value (with import handling)
  let field = match key.value {
    Some(value) => compile_value_with_imports(field, value, resolver)
    None => field
  }
  current_map.set_field(field)
}

///|
fn compile_value_with_imports(
  field : Field,
  value : @ast.Value,
  resolver : ImportResolver,
) -> Field raise CompileError {
  match value {
    @ast.Value::Scalar(s) =>
      Field::new(
        field.name,
        Some(compile_scalar(s)),
        field.composite,
        field.references,
      )
    @ast.Value::Map(m) => {
      let ir_map = Map::new()
      compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
      Field::new(
        field.name,
        field.primary,
        Some(Composite::Map(ir_map)),
        field.references,
      )
    }
    @ast.Value::Array(a) => {
      let ir_array = compile_array_with_imports(a, resolver)
      Field::new(
        field.name,
        field.primary,
        Some(Composite::Array(ir_array)),
        field.references,
      )
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
          Field::new(
            field.name,
            field.primary,
            Some(Composite::Map(import_ir)),
            field.references,
          )
        }
        None =>
          raise CompileError::ImportError("could not resolve import '\{path}'")
      }
    }
    @ast.Value::BlockScalar(label, m) => {
      let field = match label {
        @ast.Value::Scalar(s) =>
          Field::new(
            field.name,
            Some(compile_scalar(s)),
            field.composite,
            field.references,
          )
        _ => field
      }
      let ir_map = Map::new()
      compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
      Field::new(
        field.name,
        field.primary,
        Some(Composite::Map(ir_map)),
        field.references,
      )
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
    let base_id = EdgeID::new(
      src_path,
      dst_path,
      edge.src_arrow == "<",
      edge.dst_arrow == ">",
    )

    fn next_index_for_group(ir : Map, base_id : EdgeID) -> Int {
      let existing = ir.find_edges(base_id)
      let mut max_idx = -1
      for e in existing {
        match e.id.index {
          Some(i) => if i > max_idx { max_idx = i }
          None => if max_idx < 0 { max_idx = 0 }
        }
      }
      max_idx + 1
    }

    fn find_exact_edge(ir : Map, id : EdgeID) -> Edge? {
      for e in ir.edges {
        if e.id == id {
          return Some(e)
        }
      }
      None
    }

    fn compile_edge_value(
      existing : Edge?,
      value : @ast.Value?,
      resolver : ImportResolver,
    ) -> (Scalar?, Map?) raise CompileError {
      match (existing, value) {
        (Some(e), Some(v)) =>
          match v {
            @ast.Value::Scalar(s) => (Some(compile_scalar(s)), e.map)
            @ast.Value::Map(m) => {
              let ir_map = Map::new()
              compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
              (e.primary, Some(ir_map))
            }
            @ast.Value::BlockScalar(label, m) => {
              let updated_primary = match label {
                @ast.Value::Scalar(s) => Some(compile_scalar(s))
                _ => e.primary
              }
              let ir_map = Map::new()
              compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
              (updated_primary, Some(ir_map))
            }
            _ => (e.primary, e.map)
          }
        (Some(e), None) => (e.primary, e.map)
        (None, Some(v)) =>
          match v {
            @ast.Value::Scalar(s) => (Some(compile_scalar(s)), None)
            @ast.Value::Map(m) => {
              let ir_map = Map::new()
              compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
              (None, Some(ir_map))
            }
            @ast.Value::BlockScalar(label, m) => {
              let mut primary : Scalar? = None
              match label {
                @ast.Value::Scalar(s) => primary = Some(compile_scalar(s))
                _ => ()
              }
              let ir_map = Map::new()
              compile_map_nodes_with_imports(ir_map, m.nodes, resolver)
              (primary, Some(ir_map))
            }
            _ => (None, None)
          }
        (None, None) => (None, None)
      }
    }

    match key.edge_index {
      Some(ei) =>
        if ei.glob {
          let existing = ir.find_edges(base_id)
          for e in existing {
            e.references.push(EdgeReference::new(edge.range, e.id.index.unwrap_or(0), true))
            let (primary, edge_map) = compile_edge_value(Some(e), key.value, resolver)
            ir.set_edge(Edge::new(e.id, primary, edge_map, e.references))
          }
        } else {
          let idx = ei.index.unwrap_or(0)
          let edge_id = EdgeID::with_index(
            base_id.src_path,
            base_id.dst_path,
            base_id.src_arrow,
            base_id.dst_arrow,
            idx,
          )
          match find_exact_edge(ir, edge_id) {
            Some(e) => {
              e.references.push(EdgeReference::new(edge.range, idx, true))
              let (primary, edge_map) = compile_edge_value(Some(e), key.value, resolver)
              ir.set_edge(Edge::new(e.id, primary, edge_map, e.references))
            }
            None => {
              let (primary, edge_map) = compile_edge_value(None, key.value, resolver)
              let new_edge = Edge::new(edge_id, primary, edge_map, [
                EdgeReference::new(edge.range, idx, true),
              ])
              ir.add_edge(new_edge)
              ensure_field_path(ir, src_path)
              ensure_field_path(ir, dst_path)
            }
          }
        }
      None => {
        let idx = next_index_for_group(ir, base_id)
        let edge_id = EdgeID::with_index(
          base_id.src_path,
          base_id.dst_path,
          base_id.src_arrow,
          base_id.dst_arrow,
          idx,
        )
        let (primary, edge_map) = compile_edge_value(None, key.value, resolver)
        let new_edge = Edge::new(edge_id, primary, edge_map, [
          EdgeReference::new(edge.range, idx, true),
        ])
        ir.add_edge(new_edge)
        ensure_field_path(ir, src_path)
        ensure_field_path(ir, dst_path)
      }
    }
  }
}
