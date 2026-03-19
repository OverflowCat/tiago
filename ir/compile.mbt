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
priv struct ResolvedPath {
  names : Array[String]
  syntax : Array[@ast.StringValue]
}

///|
fn ResolvedPath::new(
  names : Array[String],
  syntax : Array[@ast.StringValue],
) -> ResolvedPath {
  { names, syntax }
}

///|
/// Compile an AST Map to IR Map
pub fn compile(ast : @ast.Map) -> Map raise CompileError {
  let ir = Map::from_ast(ast)
  compile_map_nodes(ir, ast, ast.nodes)
  // Resolve variable substitutions
  ir.resolve_substitutions()
  ir.reindex_paths()
}

///|
fn compile_map_nodes(
  ir : Map,
  scope_ast : @ast.Map,
  nodes : Array[@ast.MapNode],
  source_path? : String? = None,
) -> Unit raise CompileError {
  for node in nodes {
    match node {
      @ast.MapNode::Comment(_, _) => () // Skip comments
      @ast.MapNode::BlockComment(_, _) => () // Skip block comments
      @ast.MapNode::Substitution(sub) =>
        // Placeholder field to be resolved during substitution pass.
        // We use an empty name to represent "no key" (reference behavior).
        ir.add_field(
          Field::new("", Some(substitution_scalar(sub, source_path)), None, []),
        )
      @ast.MapNode::Import(_) =>
        raise CompileError::ImportError(
          "imports require a resolver; use compile_with_imports",
        )
      @ast.MapNode::Key(key) => compile_key(ir, key, scope_ast, source_path)
    }
  }
}

///|
fn record_field_reference(
  m : Map,
  f : Field,
  elem : @ast.StringValue,
  key_path : @ast.KeyPath,
  context : RefContext,
  key_path_index : Int,
  primary : Bool,
  due_to_glob? : Bool = false,
  due_to_lazy_glob? : Bool = false,
) -> Field {
  let refs = f.references.copy()
  refs.push(
    FieldReference::from_ast(
      elem,
      key_path,
      key_path_index,
      primary,
      context,
      due_to_glob~,
      due_to_lazy_glob~,
    ),
  )
  let updated = Field::new(
    f.name,
    f.primary,
    f.composite,
    refs,
    name_syntax=f.name_syntax(),
  )
  m.set_field(updated)
  updated
}

///|
fn compile_key(
  ir : Map,
  key : @ast.Key,
  scope_ast : @ast.Map,
  source_path : String?,
) -> Unit raise CompileError {
  // Handle ampersand filters (they are evaluated during glob expansion)
  if key.ampersand || key.not_ampersand {
    // Filters are collected and applied during glob expansion
    // They don't create fields themselves
    return
  }
  // Handle edges first
  if key.edges.length() > 0 {
    compile_edges(ir, key, scope_ast, source_path)
    return
  }
  // Handle regular key
  guard key.key is Some(key_path) else { return }
  // Check for glob pattern
  if key_path.has_glob() {
    compile_glob_key(ir, key_path, key, scope_ast, source_path)
    return
  }
  let context = RefContext::new(None, Some(key), Some(scope_ast), source_path~)
  let path = key_path.to_strings()
  if path.length() == 0 {
    return
  }
  // Navigate/create the field path
  let mut current_map = ir
  for i = 0; i < path.length() - 1; i = i + 1 {
    let elem = key_path.path[i]
    let field = record_field_reference(
      current_map,
      current_map.ensure_field_by_syntax(elem),
      elem,
      key_path,
      context,
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
          name_syntax=field.name_syntax(),
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
  let last_elem = key_path.path[last_index]
  let field0 = current_map.ensure_field_by_syntax(last_elem)
  let field1 = if key.primary is Some(_) || key.value is None {
    record_field_reference(
      current_map,
      field0,
      last_elem,
      key_path,
      context,
      last_index,
      key.primary is Some(_),
    )
  } else {
    field0
  }
  let field = if key.value is Some(_) {
    record_field_reference(
      current_map, field1, last_elem, key_path, context, last_index, true,
    )
  } else {
    field1
  }
  // Set primary value
  let field = match key.primary {
    Some(scalar) =>
      Field::new(
        field.name,
        Some(compile_scalar(scalar, source_path)),
        field.composite,
        field.references,
        name_syntax=field.name_syntax(),
      )
    None => field
  }
  // Set value
  let field = match key.value {
    Some(value) => compile_value(field, value, source_path)
    None => field
  }
  current_map.set_field(field)
}

///|
/// Compile a key with glob pattern
fn compile_glob_key(
  ir : Map,
  key_path : @ast.KeyPath,
  key : @ast.Key,
  scope_ast : @ast.Map,
  source_path : String?,
) -> Unit {
  // Find the glob element and extract pattern
  let (pattern, glob_index) = extract_glob_and_path(key_path)
  if pattern.length() == 0 || glob_index < 0 {
    return // No valid glob pattern
  }
  // Collect filters from the value map if present
  let filters = collect_filters_from_value(key)
  // Build properties map from the remaining path and value
  let context = RefContext::new(None, Some(key), Some(scope_ast), source_path~)
  let properties = build_nested_properties(
    key_path, glob_index, key, context, source_path,
  )
  // Apply glob pattern with filters
  ir.apply_glob_properties(pattern, properties, filters)
}

///|
/// Extract glob pattern and remaining path from key path
/// Returns (pattern, remaining_path) where pattern is from the glob element
/// and remaining_path is the rest of the key path after the glob
fn extract_glob_and_path(key_path : @ast.KeyPath) -> (Array[String], Int) {
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
    return ([], -1)
  }
  (pattern, glob_index)
}

///|
/// Build nested properties map from remaining path and key value
fn build_nested_properties(
  key_path : @ast.KeyPath,
  glob_index : Int,
  key : @ast.Key,
  context : RefContext,
  source_path : String?,
) -> Map {
  let props = Map::new()
  let remaining_path : Array[@ast.StringValue] = []
  for i = glob_index + 1; i < key_path.path.length(); i = i + 1 {
    remaining_path.push(key_path.path[i])
  }
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
                      let prop_field = Field::new(
                        prop_names[0],
                        None,
                        None,
                        [],
                        name_syntax=Some(pk.path[0]),
                      )
                      let prop_field = match prop_key.value {
                        Some(@ast.Value::Scalar(sv)) =>
                          Field::new(
                            prop_field.name,
                            Some(compile_scalar(sv, source_path)),
                            prop_field.composite,
                            prop_field.references,
                            name_syntax=prop_field.name_syntax(),
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
      let elem = remaining_path[i]
      let name = elem.content()
      let field = Field::new(
        name,
        None,
        None,
        [
          FieldReference::from_ast(
            elem,
            key_path,
            glob_index + 1 + i,
            false,
            context,
            due_to_glob=true,
          ),
        ],
        name_syntax=Some(elem),
      )
      let inner = Map::new()
      let field = Field::new(
        field.name,
        field.primary,
        Some(Composite::Map(inner)),
        field.references,
        name_syntax=field.name_syntax(),
      )
      current.add_field(field)
      current = inner
    }
    // Set the final value
    let final_elem = remaining_path[remaining_path.length() - 1]
    let final_name = final_elem.content()
    let final_index = glob_index + remaining_path.length()
    let final_field = Field::new(
      final_name,
      None,
      None,
      [
        FieldReference::from_ast(
          final_elem,
          key_path,
          final_index,
          true,
          context,
          due_to_glob=true,
        ),
      ],
      name_syntax=Some(final_elem),
    )
    // Try key.primary first, then key.value for scalar
    let final_field = match key.primary {
      Some(scalar) =>
        Field::new(
          final_field.name,
          Some(compile_scalar(scalar, source_path)),
          final_field.composite,
          {
            let refs = final_field.references.copy()
            refs.push(
              FieldReference::from_ast(
                final_elem,
                key_path,
                final_index,
                true,
                context,
                due_to_glob=true,
              ),
            )
            refs
          },
          name_syntax=final_field.name_syntax(),
        )
      None =>
        // Check if value is a scalar
        match key.value {
          Some(@ast.Value::Scalar(sv)) =>
            Field::new(
              final_field.name,
              Some(compile_scalar(sv, source_path)),
              final_field.composite,
              final_field.references,
              name_syntax=final_field.name_syntax(),
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
                  let filter_value = compile_scalar(sv, None).to_string()
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
) -> Array[ResolvedPath] {
  if !key_path.has_glob() {
    return [ResolvedPath::new(key_path.to_strings(), key_path.path.copy())]
  }
  let out : Array[ResolvedPath] = []
  expand_edge_endpoint_paths(
    ir,
    key_path.path,
    0,
    ResolvedPath::new([], []),
    out,
  )
  out
}

///|
fn expand_edge_endpoint_paths(
  current_map : Map,
  segments : Array[@ast.StringValue],
  index : Int,
  current_path : ResolvedPath,
  out : Array[ResolvedPath],
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
          let next_path = append_path_segment(
            current_path,
            field.name,
            match field.name_syntax() {
              Some(name_syntax) => name_syntax
              None => synthetic_unquoted_string(field.name)
            },
          )
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
        match current_map.get_field_by_syntax(segment) {
          Some(field) => {
            let next_path = append_path_segment(
              current_path, segment_name, segment,
            )
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
      match current_map.get_field_by_syntax(segment) {
        Some(field) => {
          let next_path = append_path_segment(
            current_path, segment_name, segment,
          )
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
fn append_path_segment(
  path : ResolvedPath,
  segment : String,
  syntax : @ast.StringValue,
) -> ResolvedPath {
  let names : Array[String] = []
  for p in path.names {
    names.push(p)
  }
  names.push(segment)
  let syntax_path : Array[@ast.StringValue] = []
  for part in path.syntax {
    syntax_path.push(part)
  }
  syntax_path.push(syntax)
  ResolvedPath::new(names, syntax_path)
}

///|
fn string_path_equal(a : ResolvedPath, b : ResolvedPath) -> Bool {
  if a.names.length() != b.names.length() {
    return false
  }
  for i = 0; i < a.names.length(); i = i + 1 {
    if a.names[i] != b.names[i] {
      return false
    }
  }
  true
}

///|
fn compile_edges(
  ir : Map,
  key : @ast.Key,
  scope_ast : @ast.Map,
  source_path : String?,
) -> Unit raise CompileError {
  for edge in key.edges {
    let edge_context = RefContext::new(
      Some(edge),
      Some(key),
      Some(scope_ast),
      source_path~,
    )
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
            @ast.Value::Scalar(s) =>
              (Some(compile_scalar(s, source_path)), e.map)
            @ast.Value::Map(m) => {
              let ir_map = Map::from_ast(m, source_path~)
              compile_map_nodes(ir_map, m, m.nodes, source_path~)
              (e.primary, Some(ir_map))
            }
            @ast.Value::BlockScalar(label, m) => {
              let updated_primary = match label {
                @ast.Value::Scalar(s) => Some(compile_scalar(s, source_path))
                _ => e.primary
              }
              let ir_map = Map::from_ast(m, source_path~)
              compile_map_nodes(ir_map, m, m.nodes, source_path~)
              (updated_primary, Some(ir_map))
            }
            _ => (e.primary, e.map)
          }
        (Some(e), None) => (e.primary, e.map)
        (None, Some(v)) =>
          match v {
            @ast.Value::Scalar(s) =>
              (Some(compile_scalar(s, source_path)), None)
            @ast.Value::Map(m) => {
              let ir_map = Map::from_ast(m, source_path~)
              compile_map_nodes(ir_map, m, m.nodes, source_path~)
              (None, Some(ir_map))
            }
            @ast.Value::BlockScalar(label, m) => {
              let mut primary : Scalar? = None
              match label {
                @ast.Value::Scalar(s) =>
                  primary = Some(compile_scalar(s, source_path))
                _ => ()
              }
              let ir_map = Map::from_ast(m, source_path~)
              compile_map_nodes(ir_map, m, m.nodes, source_path~)
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
          src_path.names,
          dst_path.names,
          edge.src_arrow == "<",
          edge.dst_arrow == ">",
          src_path_syntax=Some(src_path.syntax),
          dst_path_syntax=Some(dst_path.syntax),
        )
        // The reference preserves multiple edges between the same endpoints. When no explicit
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
                  EdgeReference::from_ast(
                    edge,
                    e.id.index.unwrap_or(0),
                    true,
                    edge_context,
                    due_to_glob=true,
                  ),
                )
                ensure_field_path(ir, src_path)
                ensure_field_path(ir, dst_path)
                append_field_references_for_path(
                  ir, src_path, edge_context, true,
                )
                append_field_references_for_path(
                  ir, dst_path, edge_context, true,
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
                src_path_syntax=Some(base_id.src_path_syntax),
                dst_path_syntax=Some(base_id.dst_path_syntax),
              )
              match find_exact_edge(ir, edge_id) {
                Some(e) => {
                  e.references.push(
                    EdgeReference::from_ast(
                      edge,
                      idx,
                      true,
                      edge_context,
                      due_to_glob=src_has_glob || dst_has_glob,
                    ),
                  )
                  ensure_field_path(ir, src_path)
                  ensure_field_path(ir, dst_path)
                  append_field_references_for_path(
                    ir,
                    src_path,
                    edge_context,
                    src_has_glob || dst_has_glob,
                  )
                  append_field_references_for_path(
                    ir,
                    dst_path,
                    edge_context,
                    src_has_glob || dst_has_glob,
                  )
                  let (primary, edge_map) = compile_edge_value(
                    Some(e),
                    key.value,
                  )
                  ir.set_edge(Edge::new(e.id, primary, edge_map, e.references))
                }
                None => {
                  let (primary, edge_map) = compile_edge_value(None, key.value)
                  let new_edge = Edge::new(edge_id, primary, edge_map, [
                    EdgeReference::from_ast(
                      edge,
                      idx,
                      true,
                      edge_context,
                      due_to_glob=src_has_glob || dst_has_glob,
                    ),
                  ])
                  ir.add_edge(new_edge)
                  ensure_field_path(ir, src_path)
                  ensure_field_path(ir, dst_path)
                  append_field_references_for_path(
                    ir,
                    src_path,
                    edge_context,
                    src_has_glob || dst_has_glob,
                  )
                  append_field_references_for_path(
                    ir,
                    dst_path,
                    edge_context,
                    src_has_glob || dst_has_glob,
                  )
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
              src_path_syntax=Some(base_id.src_path_syntax),
              dst_path_syntax=Some(base_id.dst_path_syntax),
            )
            let (primary, edge_map) = compile_edge_value(None, key.value)
            let new_edge = Edge::new(edge_id, primary, edge_map, [
              EdgeReference::from_ast(
                edge,
                idx,
                true,
                edge_context,
                due_to_glob=src_has_glob || dst_has_glob,
              ),
            ])
            ir.add_edge(new_edge)
            ensure_field_path(ir, src_path)
            ensure_field_path(ir, dst_path)
            append_field_references_for_path(
              ir,
              src_path,
              edge_context,
              src_has_glob || dst_has_glob,
            )
            append_field_references_for_path(
              ir,
              dst_path,
              edge_context,
              src_has_glob || dst_has_glob,
            )
          }
        }
      }
    }
  }
}

///|
fn ensure_field_path(ir : Map, path : ResolvedPath) -> Unit {
  let mut current = ir
  for i, _ in path.names {
    let field = current.ensure_field_by_syntax(path.syntax[i])
    match field.composite {
      Some(Composite::Map(m)) => current = m
      None => {
        let new_map = Map::new()
        let field = Field::new(
          field.name,
          field.primary,
          Some(Composite::Map(new_map)),
          field.references,
          name_syntax=field.name_syntax(),
        )
        current.set_field(field)
        current = new_map
      }
      Some(_) => break // Field has non-map composite, stop
    }
  }
}

///|
fn append_field_references_for_path(
  ir : Map,
  path : ResolvedPath,
  context : RefContext,
  due_to_glob : Bool,
) -> Unit {
  if path.syntax.is_empty() {
    return
  }
  let key_path = @ast.KeyPath::new(path.syntax[0].range(), path.syntax.copy())
  append_field_references_for_path_at(
    ir, path, key_path, context, 0, due_to_glob,
  )
}

///|
fn append_field_references_for_path_at(
  current : Map,
  path : ResolvedPath,
  key_path : @ast.KeyPath,
  context : RefContext,
  index : Int,
  due_to_glob : Bool,
) -> Unit {
  if index >= path.syntax.length() {
    return
  }
  let field = match current.get_field_by_syntax(path.syntax[index]) {
    Some(field) => field
    None => return
  }
  let updated = record_field_reference(
    current,
    field,
    path.syntax[index],
    key_path,
    context,
    index,
    false,
    due_to_glob~,
  )
  if index + 1 >= path.syntax.length() {
    return
  }
  match updated.composite {
    Some(Composite::Map(next)) =>
      append_field_references_for_path_at(
        next,
        path,
        key_path,
        context,
        index + 1,
        due_to_glob,
      )
    _ => ()
  }
}

///|
fn compile_value(
  field : Field,
  value : @ast.Value,
  source_path : String?,
) -> Field raise CompileError {
  match value {
    @ast.Value::Scalar(s) =>
      Field::new(
        field.name,
        Some(compile_scalar(s, source_path)),
        field.composite,
        field.references,
        name_syntax=field.name_syntax(),
      )
    @ast.Value::Map(m) => {
      let ir_map = Map::from_ast(m, source_path~)
      compile_map_nodes(ir_map, m, m.nodes, source_path~)
      Field::new(
        field.name,
        field.primary,
        Some(Composite::Map(ir_map)),
        field.references,
        name_syntax=field.name_syntax(),
      )
    }
    @ast.Value::Array(a) => {
      let ir_array = compile_array(a, source_path)
      Field::new(
        field.name,
        field.primary,
        Some(Composite::Array(ir_array)),
        field.references,
        name_syntax=field.name_syntax(),
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
            Some(compile_scalar(s, source_path)),
            field.composite,
            field.references,
            name_syntax=field.name_syntax(),
          )
        _ => field
      }
      let ir_map = Map::from_ast(m, source_path~)
      compile_map_nodes(ir_map, m, m.nodes, source_path~)
      Field::new(
        field.name,
        field.primary,
        Some(Composite::Map(ir_map)),
        field.references,
        name_syntax=field.name_syntax(),
      )
    }
  }
}

///|
fn compile_array(
  arr : @ast.ArrayValue,
  source_path : String?,
) -> IRArray raise CompileError {
  let values : Array[Value] = []
  for node in arr.nodes {
    match node {
      @ast.ArrayNode::Comment(_, _) => ()
      @ast.ArrayNode::BlockComment(_, _) => ()
      @ast.ArrayNode::Substitution(sub) =>
        values.push(Value::Scalar(substitution_scalar(sub, source_path)))
      @ast.ArrayNode::Import(_) =>
        raise CompileError::ImportError(
          "imports require a resolver; use compile_with_imports",
        )
      @ast.ArrayNode::Value(v) => values.push(compile_ast_value(v, source_path))
    }
  }
  IRArray::from_ast(arr, values, source_path~)
}

///|
fn substitution_scalar(
  sub : @ast.Substitution,
  source_path : String?,
) -> Scalar {
  Scalar::from_ast(
    @ast.Node::Substitution(sub),
    ScalarValue::String(
      @ast.StringValue::Unquoted(
        @ast.UnquotedString::new(sub.range, [@ast.Interpolation::Sub(sub)], []),
      ),
    ),
    source_path~,
  )
}

///|
fn compile_ast_value(
  value : @ast.Value,
  source_path : String?,
) -> Value raise CompileError {
  match value {
    @ast.Value::Scalar(s) => Value::Scalar(compile_scalar(s, source_path))
    @ast.Value::Map(m) => {
      let ir_map = Map::from_ast(m, source_path~)
      compile_map_nodes(ir_map, m, m.nodes, source_path~)
      Value::Map(ir_map)
    }
    @ast.Value::Array(a) => Value::Array(compile_array(a, source_path))
    @ast.Value::Import(_) =>
      raise CompileError::ImportError(
        "imports require a resolver; use compile_with_imports",
      )
    @ast.Value::BlockScalar(_, m) => {
      // For arrays, just use the map part (label is ignored in array context)
      let ir_map = Map::from_ast(m, source_path~)
      compile_map_nodes(ir_map, m, m.nodes, source_path~)
      Value::Map(ir_map)
    }
  }
}

///|
fn compile_scalar(scalar : @ast.Scalar, source_path : String?) -> Scalar {
  match scalar {
    @ast.Scalar::Null(_r) =>
      Scalar::from_ast(
        @ast.Node::Scalar(scalar),
        ScalarValue::Null,
        source_path~,
      )
    @ast.Scalar::Boolean(_r, b) =>
      Scalar::from_ast(
        @ast.Node::Scalar(scalar),
        ScalarValue::Bool(if b { "true" } else { "false" }),
        source_path~,
      )
    @ast.Scalar::Number(_r, n) =>
      Scalar::from_ast(
        @ast.Node::Scalar(scalar),
        ScalarValue::Number(n),
        source_path~,
      )
    @ast.Scalar::String(sv) =>
      Scalar::from_ast(
        @ast.Node::StringValue(sv),
        ScalarValue::String(sv),
        source_path~,
      )
  }
}
