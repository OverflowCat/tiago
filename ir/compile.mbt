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
      @ast.MapNode::Substitution(sub) =>
        // Placeholder field to be resolved during substitution pass.
        // We use an empty name to represent "no key" (d2 parity).
        ir.add_field(Field::new("", Some(substitution_scalar(sub)), None, []))
      @ast.MapNode::Import(_) =>
        raise CompileError::ImportError(
          "imports require a resolver; use compile_with_imports",
        )
      @ast.MapNode::Key(key) => compile_key(ir, key)
    }
  }
}

///|
fn record_field_reference(
  m : Map,
  f : Field,
  elem : @ast.StringValue,
  key_path_index : Int,
  primary : Bool,
) -> Field {
  let refs = f.references.copy()
  refs.push(
    FieldReference::new(elem.range(), elem.content(), key_path_index, primary),
  )
  let updated = Field::new(f.name, f.primary, f.composite, refs)
  m.set_field(updated)
  updated
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
    let elem = key_path.path[i]
    let field = record_field_reference(
      current_map,
      current_map.ensure_field(name),
      elem,
      i,
      false,
    )
    // Ensure field has a map composite
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
  // Set value
  let field = match key.value {
    Some(value) => compile_value(field, value)
    None => field
  }
  current_map.set_field(field)
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
                      let prop_field = match prop_key.value {
                        Some(@ast.Value::Scalar(sv)) =>
                          Field::new(
                            prop_field.name,
                            Some(compile_scalar(sv)),
                            prop_field.composite,
                            prop_field.references,
                          )
                        _ => prop_field
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
      let field = Field::new(
        field.name,
        field.primary,
        Some(Composite::Map(inner)),
        field.references,
      )
      current.add_field(field)
      current = inner
    }
    // Set the final value
    let final_name = remaining_path[remaining_path.length() - 1]
    let final_field = Field::simple(final_name)
    // Try key.primary first, then key.value for scalar
    let final_field = match key.primary {
      Some(scalar) =>
        Field::new(
          final_field.name,
          Some(compile_scalar(scalar)),
          final_field.composite,
          final_field.references,
        )
      None =>
        // Check if value is a scalar
        match key.value {
          Some(@ast.Value::Scalar(sv)) =>
            Field::new(
              final_field.name,
              Some(compile_scalar(sv)),
              final_field.composite,
              final_field.references,
            )
          _ => final_field
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
fn edge_endpoint_paths(
  ir : Map,
  key_path : @ast.KeyPath,
) -> Array[Array[String]] {
  if !key_path.has_glob() {
    return [key_path.to_strings()]
  }
  let out : Array[Array[String]] = []
  expand_edge_endpoint_paths(ir, key_path.path, 0, [], out)
  out
}

///|
fn expand_edge_endpoint_paths(
  current_map : Map,
  segments : Array[@ast.StringValue],
  index : Int,
  current_path : Array[String],
  out : Array[Array[String]],
) -> Unit {
  if index >= segments.length() {
    out.push(current_path)
    return
  }
  let segment = segments[index]
  let is_last = index == segments.length() - 1
  match segment {
    @ast.StringValue::Unquoted(us) =>
      if us.pattern.length() > 0 {
        let candidates = current_map.single_glob(us.pattern)
        for field in candidates {
          let next_path = append_path_segment(current_path, field.name)
          if is_last {
            out.push(next_path)
          } else {
            match field.composite {
              Some(Composite::Map(m)) =>
                expand_edge_endpoint_paths(
                  m,
                  segments,
                  index + 1,
                  next_path,
                  out,
                )
              _ => ()
            }
          }
        }
      } else {
        let segment_name = segment.content()
        match current_map.get_field(segment_name) {
          Some(field) => {
            let next_path = append_path_segment(current_path, segment_name)
            if is_last {
              out.push(next_path)
            } else {
              match field.composite {
                Some(Composite::Map(m)) =>
                  expand_edge_endpoint_paths(
                    m,
                    segments,
                    index + 1,
                    next_path,
                    out,
                  )
                _ => ()
              }
            }
          }
          None => ()
        }
      }
    _ => {
      let segment_name = segment.content()
      match current_map.get_field(segment_name) {
        Some(field) => {
          let next_path = append_path_segment(current_path, segment_name)
          if is_last {
            out.push(next_path)
          } else {
            match field.composite {
              Some(Composite::Map(m)) =>
                expand_edge_endpoint_paths(
                  m,
                  segments,
                  index + 1,
                  next_path,
                  out,
                )
              _ => ()
            }
          }
        }
        None => ()
      }
    }
  }
}

///|
fn append_path_segment(path : Array[String], segment : String) -> Array[String] {
  let out : Array[String] = []
  for p in path {
    out.push(p)
  }
  out.push(segment)
  out
}

///|
fn string_path_equal(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn compile_edges(ir : Map, key : @ast.Key) -> Unit raise CompileError {
  for edge in key.edges {
    let src_paths = edge_endpoint_paths(ir, edge.src)
    let dst_paths = edge_endpoint_paths(ir, edge.dst)
    let src_has_glob = edge.src.has_glob()
    let dst_has_glob = edge.dst.has_glob()
    if src_paths.is_empty() || dst_paths.is_empty() {
      continue
    }
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
    ) -> (Scalar?, Map?) raise CompileError {
      match (existing, value) {
        (Some(e), Some(v)) =>
          match v {
            @ast.Value::Scalar(s) => (Some(compile_scalar(s)), e.map)
            @ast.Value::Map(m) => {
              let ir_map = Map::new()
              compile_map_nodes(ir_map, m.nodes)
              (e.primary, Some(ir_map))
            }
            @ast.Value::BlockScalar(label, m) => {
              let updated_primary = match label {
                @ast.Value::Scalar(s) => Some(compile_scalar(s))
                _ => e.primary
              }
              let ir_map = Map::new()
              compile_map_nodes(ir_map, m.nodes)
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
              compile_map_nodes(ir_map, m.nodes)
              (None, Some(ir_map))
            }
            @ast.Value::BlockScalar(label, m) => {
              let mut primary : Scalar? = None
              match label {
                @ast.Value::Scalar(s) => primary = Some(compile_scalar(s))
                _ => ()
              }
              let ir_map = Map::new()
              compile_map_nodes(ir_map, m.nodes)
              (primary, Some(ir_map))
            }
            _ => (None, None)
          }
        (None, None) => (None, None)
      }
    }

    for src_path in src_paths {
      for dst_path in dst_paths {
        if (src_has_glob || dst_has_glob) &&
          string_path_equal(src_path, dst_path) {
          continue
        }
        let base_id = EdgeID::new(
          src_path,
          dst_path,
          edge.src_arrow == "<",
          edge.dst_arrow == ">",
        )
        // D2 preserves multiple edges between the same endpoints. When no explicit
        // `[index]` is given, allocate the next index and create a new edge.
        // When `[index]` is provided, update that edge if it exists; otherwise
        // create it at that index.
        match key.edge_index {
          Some(ei) =>
            if ei.glob {
              // Apply the value block to all edges in the group.
              let existing = ir.find_edges(base_id)
              for e in existing {
                e.references.push(
                  EdgeReference::new(edge.range, e.id.index.unwrap_or(0), true),
                )
                let (primary, edge_map) = compile_edge_value(Some(e), key.value)
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
                  let (primary, edge_map) = compile_edge_value(
                    Some(e),
                    key.value,
                  )
                  ir.set_edge(Edge::new(e.id, primary, edge_map, e.references))
                }
                None => {
                  let (primary, edge_map) = compile_edge_value(None, key.value)
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
            let (primary, edge_map) = compile_edge_value(None, key.value)
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
        let field = Field::new(
          field.name,
          field.primary,
          Some(Composite::Map(new_map)),
          field.references,
        )
        current.set_field(field)
        current = new_map
      }
      Some(_) => break // Field has non-map composite, stop
    }
  }
}

///|
fn compile_value(field : Field, value : @ast.Value) -> Field raise CompileError {
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
      compile_map_nodes(ir_map, m.nodes)
      Field::new(
        field.name,
        field.primary,
        Some(Composite::Map(ir_map)),
        field.references,
      )
    }
    @ast.Value::Array(a) => {
      let ir_array = compile_array(a)
      Field::new(
        field.name,
        field.primary,
        Some(Composite::Array(ir_array)),
        field.references,
      )
    }
    @ast.Value::Import(_) =>
      raise CompileError::ImportError(
        "imports require a resolver; use compile_with_imports",
      )
    @ast.Value::BlockScalar(label, m) => {
      // "name: Label { props }" - Label is primary, props is composite
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
      compile_map_nodes(ir_map, m.nodes)
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
fn compile_array(arr : @ast.ArrayValue) -> IRArray raise CompileError {
  let values : Array[Value] = []
  for node in arr.nodes {
    match node {
      @ast.ArrayNode::Comment(_, _) => ()
      @ast.ArrayNode::BlockComment(_, _) => ()
      @ast.ArrayNode::Substitution(sub) =>
        values.push(Value::Scalar(substitution_scalar(sub)))
      @ast.ArrayNode::Import(_) =>
        raise CompileError::ImportError(
          "imports require a resolver; use compile_with_imports",
        )
      @ast.ArrayNode::Value(v) => values.push(compile_ast_value(v))
    }
  }
  IRArray::new(values)
}

///|
fn substitution_scalar(sub : @ast.Substitution) -> Scalar {
  Scalar::at(
    sub.range,
    ScalarValue::String(
      @ast.StringValue::Unquoted(
        @ast.UnquotedString::new(sub.range, [@ast.Interpolation::Sub(sub)], []),
      ),
    ),
  )
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
    @ast.Value::Import(_) =>
      raise CompileError::ImportError(
        "imports require a resolver; use compile_with_imports",
      )
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
    @ast.Scalar::Null(r) => Scalar::at(r, ScalarValue::Null)
    @ast.Scalar::Boolean(r, b) =>
      Scalar::at(r, ScalarValue::Bool(if b { "true" } else { "false" }))
    @ast.Scalar::Number(r, n) => Scalar::at(r, ScalarValue::Number(n))
    @ast.Scalar::String(sv) => Scalar::at(sv.range(), ScalarValue::String(sv))
  }
}
