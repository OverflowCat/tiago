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
/// Variable substitution for diago IR (d2 parity)
///
/// This pass resolves `${var}` substitution segments that the parser stores in
/// `@ast.StringValue::Unquoted` interpolation segments, and also handles
/// spread substitutions (`...$var`) compiled as placeholder nodes.

///|
fn Map::resolve_substitutions(self : Map) -> Unit raise CompileError {
  self.resolve_substitutions_with_stack([], false)
}

///|
fn Map::resolve_substitutions_with_stack(
  self : Map,
  vars_stack : Array[Map],
  in_vars_map : Bool,
) -> Unit raise CompileError {
  let local_stack = prepend_vars_stack(self, vars_stack)

  // Fields (allow removal for spread placeholders)
  let mut i = 0
  while i < self.fields.length() {
    let name_lower = self.fields[i].name.to_lower()
    if name_lower == "vars" {
      // Still resolve substitutions inside vars blocks (with itself at top of stack).
      match self.fields[i].composite {
        Some(Composite::Map(m)) =>
          m.resolve_substitutions_with_stack(local_stack, true)
        Some(Composite::Array(a)) =>
          a.resolve_substitutions_with_stack(local_stack)
        None => ()
      }
      i = i + 1
      continue
    }

    // Resolve primary substitutions first. Spread substitutions can remove the field.
    if self.fields[i].primary is Some(_) {
      let removed = resolve_field_primary_substitutions(
        self, i, local_stack, in_vars_map,
      )
      if removed {
        continue
      }
    }

    // Recurse into composite after primary resolution.
    match self.fields[i].composite {
      Some(Composite::Map(m)) =>
        m.resolve_substitutions_with_stack(local_stack, false)
      Some(Composite::Array(a)) =>
        a.resolve_substitutions_with_stack(local_stack)
      None => ()
    }
    i = i + 1
  }

  // Edges
  for ei, edge in self.edges {
    let (primary, map) = resolve_edge_primary_and_map(
      edge.primary,
      edge.map,
      local_stack,
    )
    match map {
      Some(m) => m.resolve_substitutions_with_stack(local_stack, false)
      None => ()
    }
    self.edges[ei] = Edge::new(edge.id, primary, map, edge.references)
  }
}

///|
fn IRArray::resolve_substitutions_with_stack(
  self : IRArray,
  vars_stack : Array[Map],
) -> Unit raise CompileError {
  let mut i = 0
  while i < self.values.length() {
    match self.values[i] {
      Value::Scalar(s) => {
        let action = resolve_scalar_in_array(self, i, s, vars_stack)
        if action {
          // Element was replaced/removed, stay at same index.
          continue
        }
      }
      Value::Map(m) => m.resolve_substitutions_with_stack(vars_stack, false)
      Value::Array(a) => a.resolve_substitutions_with_stack(vars_stack)
    }
    i = i + 1
  }
}

// ============================================================================
// Field substitution resolution
// ============================================================================

///|
fn resolve_field_primary_substitutions(
  m : Map,
  field_index : Int,
  vars_stack : Array[Map],
  in_vars_map : Bool,
) -> Bool raise CompileError {
  let field = m.fields[field_index]
  guard field.primary is Some(p) else { return false }
  let (removed, updated_field) = resolve_scalar_in_field(
    m,
    field_index,
    field.name,
    p,
    field.composite,
    vars_stack,
    in_vars_map,
  )
  if removed {
    return true
  }
  m.fields[field_index] = Field::new(
    field.name,
    updated_field.0,
    updated_field.1,
    field.references,
  )
  false
}

///|
fn resolve_scalar_in_field(
  parent_map : Map,
  field_index : Int,
  field_name : String,
  primary : Scalar,
  composite : Composite?,
  vars_stack : Array[Map],
  in_vars_map : Bool,
) -> (Bool, (Scalar?, Composite?)) raise CompileError {
  match primary.value {
    ScalarValue::String(sv) =>
      match sv {
        @ast.StringValue::Unquoted(us) =>
          resolve_unquoted_in_field(
            parent_map,
            field_index,
            field_name,
            primary.range,
            us,
            composite,
            vars_stack,
            in_vars_map,
          )
        @ast.StringValue::DoubleQuoted(dqs) => {
          let resolved = resolve_double_quoted_in_field(
            primary.range,
            dqs,
            vars_stack,
            field_name,
            in_vars_map,
          )
          (false, (Some(resolved), composite))
        }
        _ => (false, (Some(primary), composite))
      }
    _ => (false, (Some(primary), composite))
  }
}

///|
fn resolve_double_quoted_in_field(
  range : @lexer.Range,
  dqs : @ast.DoubleQuotedString,
  vars_stack : Array[Map],
  field_name : String,
  in_vars_map : Bool,
) -> Scalar raise CompileError {
  // d2 parity: substitutions in quotes always resolve to a string; composites are invalid.
  let buf = StringBuilder::new()
  for seg in dqs.value {
    match seg {
      @ast.Interpolation::Text(s) => buf.write_string(s)
      @ast.Interpolation::Sub(sub) => {
        let resolved = resolve_from_stack(
          vars_stack,
          sub,
          Some(field_name),
          in_vars_map,
        )
        match resolved.primary {
          Some(rp) => buf.write_string(rp.to_string())
          None =>
            match resolved.composite {
              Some(_) =>
                raise CompileError::InvalidSubstitution(
                  "cannot substitute map variable \"\{sub_path_string(sub)}\" in quotes",
                )
              None =>
                raise CompileError::InvalidSubstitution(
                  "cannot substitute variable without value: \"\{sub_path_string(sub)}\"",
                )
            }
        }
      }
    }
  }
  let new_sv = @ast.StringValue::DoubleQuoted(
    @ast.DoubleQuotedString::new(range, [
      @ast.Interpolation::Text(buf.to_string()),
    ]),
  )
  Scalar::at(range, ScalarValue::String(new_sv))
}

///|
fn resolve_unquoted_in_field(
  parent_map : Map,
  field_index : Int,
  field_name : String,
  range : @lexer.Range,
  us : @ast.UnquotedString,
  composite : Composite?,
  vars_stack : Array[Map],
  in_vars_map : Bool,
) -> (Bool, (Scalar?, Composite?)) raise CompileError {
  // Whole substitution (`${x}`) is handled specially (may set composite or spread).
  if us.value.length() == 1 {
    match us.value[0] {
      @ast.Interpolation::Sub(sub) =>
        return resolve_single_sub_in_field(
          parent_map, field_index, field_name, range, sub, composite, vars_stack,
          in_vars_map,
        )
      _ => ()
    }
  }

  // Otherwise, treat it as a string with substitutions inside.
  let buf = StringBuilder::new()
  let mut updated_composite = composite
  for seg in us.value {
    match seg {
      @ast.Interpolation::Text(s) => buf.write_string(s)
      @ast.Interpolation::Sub(sub) => {
        let resolved = resolve_from_stack(
          vars_stack,
          sub,
          Some(field_name),
          in_vars_map,
        )
        guard resolved.primary is Some(rp) else {
          if resolved.composite is None {
            raise CompileError::InvalidSubstitution(
              "cannot substitute variable without value: \"\{sub_path_string(sub)}\"",
            )
          }
          raise CompileError::InvalidSubstitution(
            "cannot substitute composite variable \"\{sub_path_string(sub)}\" as part of a string",
          )
        }
        buf.write_string(rp.to_string())
        match resolved.composite {
          Some(c) => updated_composite = Some(clone_composite(c))
          None => ()
        }
      }
    }
  }
  let new_sv = @ast.StringValue::Unquoted(
    @ast.UnquotedString::new(
      range,
      [@ast.Interpolation::Text(buf.to_string())],
      [],
    ),
  )
  (
    false,
    (Some(Scalar::at(range, ScalarValue::String(new_sv))), updated_composite),
  )
}

///|
fn resolve_single_sub_in_field(
  parent_map : Map,
  field_index : Int,
  field_name : String,
  _range : @lexer.Range,
  sub : @ast.Substitution,
  composite : Composite?,
  vars_stack : Array[Map],
  in_vars_map : Bool,
) -> (Bool, (Scalar?, Composite?)) raise CompileError {
  let resolved = resolve_from_stack(
    vars_stack,
    sub,
    Some(field_name),
    in_vars_map,
  )
  if sub.spread {
    guard resolved.composite is Some(rc) else {
      raise CompileError::InvalidSubstitution("cannot spread non-composite")
    }
    match rc {
      Composite::Map(rm) => {
        let inserted = expand_substitution(parent_map, rm, field_index)
        let _ = parent_map.fields.remove(field_index + inserted)
        return (true, (None, None))
      }
      Composite::Array(_) => {
        // d2 parity: placeholder is removed even if nothing can be expanded into a map.
        let _ = parent_map.fields.remove(field_index)
        return (true, (None, None))
      }
    }
  }
  match resolved.primary {
    Some(rp) => {
      let new_primary = Some(clone_scalar(rp))
      let new_composite = match resolved.composite {
        Some(c) => Some(clone_composite(c))
        None => composite
      }
      (false, (new_primary, new_composite))
    }
    None =>
      match resolved.composite {
        Some(c) => (false, (None, Some(clone_composite(c))))
        None =>
          raise CompileError::InvalidSubstitution(
            "cannot substitute variable without value: \"\{sub_path_string(sub)}\"",
          )
      }
  }
}

// ============================================================================
// Edge substitution resolution
// ============================================================================

///|
fn resolve_edge_primary_and_map(
  primary : Scalar?,
  edge_map : Map?,
  vars_stack : Array[Map],
) -> (Scalar?, Map?) raise CompileError {
  let mut out_primary = primary
  let mut out_map = edge_map
  guard primary is Some(p) else { return (out_primary, out_map) }
  match p.value {
    ScalarValue::String(sv) =>
      match sv {
        @ast.StringValue::Unquoted(us) =>
          if us.value.length() == 1 {
            match us.value[0] {
              @ast.Interpolation::Sub(sub) => {
                let resolved = resolve_from_stack(vars_stack, sub, None, false)
                match resolved.primary {
                  Some(rp) => out_primary = Some(clone_scalar(rp))
                  None => out_primary = None
                }
                match resolved.composite {
                  Some(Composite::Map(m)) => out_map = Some(clone_map(m))
                  Some(Composite::Array(_)) =>
                    raise CompileError::InvalidSubstitution(
                      "cannot substitute array variable \"\{sub_path_string(sub)}\" to an edge",
                    )
                  None => ()
                }
                if resolved.primary is None && resolved.composite is None {
                  raise CompileError::InvalidSubstitution(
                    "cannot substitute variable without value: \"\{sub_path_string(sub)}\"",
                  )
                }
              }
              _ => ()
            }
          } else {
            let buf = StringBuilder::new()
            for seg in us.value {
              match seg {
                @ast.Interpolation::Text(s) => buf.write_string(s)
                @ast.Interpolation::Sub(sub) => {
                  let resolved = resolve_from_stack(
                    vars_stack,
                    sub,
                    None,
                    false,
                  )
                  guard resolved.primary is Some(rp) else {
                    if resolved.composite is None {
                      raise CompileError::InvalidSubstitution(
                        "cannot substitute variable without value: \"\{sub_path_string(sub)}\"",
                      )
                    }
                    raise CompileError::InvalidSubstitution(
                      "cannot substitute composite variable \"\{sub_path_string(sub)}\" as part of a string",
                    )
                  }
                  buf.write_string(rp.to_string())
                  match resolved.composite {
                    Some(Composite::Map(m)) => out_map = Some(clone_map(m))
                    Some(Composite::Array(_)) =>
                      raise CompileError::InvalidSubstitution(
                        "cannot substitute array variable \"\{sub_path_string(sub)}\" to an edge",
                      )
                    None => ()
                  }
                }
              }
            }
            let r = p.range
            out_primary = Some(
              Scalar::at(
                r,
                ScalarValue::String(
                  @ast.StringValue::Unquoted(
                    @ast.UnquotedString::new(
                      r,
                      [@ast.Interpolation::Text(buf.to_string())],
                      [],
                    ),
                  ),
                ),
              ),
            )
          }
        _ => ()
      }
    _ => ()
  }
  (out_primary, out_map)
}

// ============================================================================
// Array substitution resolution (including spread)
// ============================================================================

///|
fn resolve_scalar_in_array(
  arr : IRArray,
  index : Int,
  scalar : Scalar,
  vars_stack : Array[Map],
) -> Bool raise CompileError {
  match scalar.value {
    ScalarValue::String(sv) =>
      match sv {
        @ast.StringValue::Unquoted(us) =>
          resolve_unquoted_in_array(arr, index, scalar.range, us, vars_stack)
        _ => false
      }
    _ => false
  }
}

///|
fn resolve_unquoted_in_array(
  arr : IRArray,
  index : Int,
  range : @lexer.Range,
  us : @ast.UnquotedString,
  vars_stack : Array[Map],
) -> Bool raise CompileError {
  if us.value.length() == 1 {
    match us.value[0] {
      @ast.Interpolation::Sub(sub) => {
        let resolved = resolve_from_stack(vars_stack, sub, None, false)
        if sub.spread {
          guard resolved.composite is Some(rc) else {
            raise CompileError::InvalidSubstitution(
              "cannot spread non-composite",
            )
          }
          match rc {
            Composite::Array(a) => {
              let out : Array[Value] = []
              for v in a.values {
                out.push(clone_value(v))
              }
              // Splice values into array in place of the placeholder element.
              let _ = arr.values.remove(index)
              for j, v in out {
                arr.values.insert(index + j, v)
              }
              return true
            }
            Composite::Map(_) =>
              raise CompileError::InvalidSubstitution(
                "cannot spread non-array into array",
              )
          }
        }
        match resolved.primary {
          Some(rp) => {
            arr.values[index] = Value::Scalar(clone_scalar(rp))
            false
          }
          None =>
            // d2 parity: composite variables substituted as a whole array element are ignored.
            false
        }
      }
      _ => false
    }
  } else {
    let buf = StringBuilder::new()
    for seg in us.value {
      match seg {
        @ast.Interpolation::Text(s) => buf.write_string(s)
        @ast.Interpolation::Sub(sub) => {
          let resolved = resolve_from_stack(vars_stack, sub, None, false)
          guard resolved.primary is Some(rp) else {
            if resolved.composite is None {
              raise CompileError::InvalidSubstitution(
                "cannot substitute variable without value: \"\{sub_path_string(sub)}\"",
              )
            }
            raise CompileError::InvalidSubstitution(
              "cannot substitute composite variable \"\{sub_path_string(sub)}\" as part of a string",
            )
          }
          buf.write_string(rp.to_string())
        }
      }
    }
    let new_sv = @ast.StringValue::Unquoted(
      @ast.UnquotedString::new(
        range,
        [@ast.Interpolation::Text(buf.to_string())],
        [],
      ),
    )
    arr.values[index] = Value::Scalar(
      Scalar::at(range, ScalarValue::String(new_sv)),
    )
    false
  }
}

// ============================================================================
// Vars lookup helpers (d2 resolveSubstitution parity)
// ============================================================================

///|
fn prepend_vars_stack(m : Map, vars_stack : Array[Map]) -> Array[Map] {
  match m.get_field("vars") {
    Some(f) =>
      match f.composite {
        Some(Composite::Map(vm)) => {
          let out : Array[Map] = [vm]
          for v in vars_stack {
            out.push(v)
          }
          out
        }
        _ => vars_stack
      }
    None => vars_stack
  }
}

///|
fn resolve_from_stack(
  vars_stack : Array[Map],
  sub : @ast.Substitution,
  field_name : String?,
  in_vars_map : Bool,
) -> Field raise CompileError {
  let mut found : Field? = None
  for i, vars in vars_stack {
    match resolve_in_vars(vars, sub, field_name, in_vars_map, i == 0) {
      Some(f) => {
        // d2 parity: a found `null` shadows outer scopes and behaves like unresolved.
        match f.primary {
          Some(p) =>
            if p.value is ScalarValue::Null {
              raise CompileError::InvalidSubstitution(
                "could not resolve variable \"\{sub_path_string(sub)}\"",
              )
            }
          None => ()
        }
        found = Some(f)
        break
      }
      None => ()
    }
  }
  match found {
    Some(f) => f
    None =>
      raise CompileError::InvalidSubstitution(
        "could not resolve variable \"\{sub_path_string(sub)}\"",
      )
  }
}

///|
fn resolve_in_vars(
  vars : Map,
  sub : @ast.Substitution,
  field_name : String?,
  in_vars_map : Bool,
  is_current_scope_vars : Bool,
) -> Field? {
  let mut current = vars
  for i, part in sub.path {
    let key = part.content()
    match current.get_field(key) {
      Some(f) => {
        match field_name {
          Some(n) =>
            if in_vars_map &&
              is_current_scope_vars &&
              n.to_lower() == key.to_lower() {
              return None
            }
          None => ()
        }
        if i == sub.path.length() - 1 {
          return Some(f)
        }
        match f.composite {
          Some(Composite::Map(m)) => current = m
          _ => return None
        }
      }
      None => return None
    }
  }
  None
}

///|
fn sub_path_string(sub : @ast.Substitution) -> String {
  let parts = sub.path.map(fn(p) { p.content() })
  join(parts, ".")
}

///|
fn join(parts : Array[String], sep : String) -> String {
  let buf = StringBuilder::new()
  for i, s in parts {
    if i > 0 {
      buf.write_string(sep)
    }
    buf.write_string(s)
  }
  buf.to_string()
}

// ============================================================================
// Spread expansion (d2 ExpandSubstitution parity)
// ============================================================================

///|
fn expand_substitution(m : Map, resolved : Map, placeholder_index : Int) -> Int {
  let mut insert_at = placeholder_index
  let mut inserted = 0
  for of in resolved.fields {
    match find_field_index(m, of.name) {
      Some(bi) => {
        let base = m.fields[bi]
        m.fields[bi] = overlay_field(base, of)
      }
      None => {
        m.fields.insert(insert_at, clone_field(of))
        insert_at = insert_at + 1
        inserted = inserted + 1
      }
    }
  }
  for oe in resolved.edges {
    match find_edge_index(m, oe.id) {
      Some(ei) => m.edges[ei] = overlay_edge(m.edges[ei], oe)
      None => m.edges.push(clone_edge(oe))
    }
  }
  inserted
}

///|
fn find_field_index(m : Map, name : String) -> Int? {
  let lower = name.to_lower()
  for i, f in m.fields {
    if f.name.to_lower() == lower {
      return Some(i)
    }
  }
  None
}

///|
fn find_edge_index(m : Map, id : EdgeID) -> Int? {
  for i, e in m.edges {
    if e.id.matches(id) {
      return Some(i)
    }
  }
  None
}

///|
fn overlay_field(base : Field, overlay : Field) -> Field {
  let mut primary = base.primary
  if overlay.primary is Some(op) {
    primary = Some(clone_scalar(op))
  }
  let mut composite = base.composite
  match overlay.composite {
    Some(oc) =>
      match oc {
        Composite::Map(om) =>
          match composite {
            Some(Composite::Map(bm)) => {
              overlay_map(bm, om)
              composite = Some(Composite::Map(bm))
            }
            _ => composite = Some(Composite::Map(clone_map(om)))
          }
        Composite::Array(oa) =>
          composite = Some(Composite::Array(clone_array(oa)))
      }
    None => ()
  }
  let refs = base.references.copy()
  for r in overlay.references {
    refs.push(r)
  }
  Field::new(base.name, primary, composite, refs)
}

///|
fn overlay_edge(base : Edge, overlay : Edge) -> Edge {
  let mut primary = base.primary
  if overlay.primary is Some(op) {
    primary = Some(clone_scalar(op))
  }
  let mut map = base.map
  match overlay.map {
    Some(om) =>
      match map {
        Some(bm) => {
          overlay_map(bm, om)
          map = Some(bm)
        }
        None => map = Some(clone_map(om))
      }
    None => ()
  }
  let refs = base.references.copy()
  for r in overlay.references {
    refs.push(r)
  }
  Edge::new(clone_edge_id(base.id), primary, map, refs)
}

///|
fn overlay_map(base : Map, overlay : Map) -> Unit {
  for of in overlay.fields {
    match find_field_index(base, of.name) {
      Some(i) => base.fields[i] = overlay_field(base.fields[i], of)
      None => base.fields.push(clone_field(of))
    }
  }
  for oe in overlay.edges {
    match find_edge_index(base, oe.id) {
      Some(i) => base.edges[i] = overlay_edge(base.edges[i], oe)
      None => base.edges.push(clone_edge(oe))
    }
  }
}

// ============================================================================
// Clone helpers
// ============================================================================

///|
fn clone_scalar(s : Scalar) -> Scalar {
  Scalar::at(s.range, s.value)
}

///|
fn clone_composite(c : Composite) -> Composite {
  match c {
    Composite::Map(m) => Composite::Map(clone_map(m))
    Composite::Array(a) => Composite::Array(clone_array(a))
  }
}

///|
fn clone_map(m : Map) -> Map {
  let out = Map::new()
  for f in m.fields {
    out.fields.push(clone_field(f))
  }
  for e in m.edges {
    out.edges.push(clone_edge(e))
  }
  out
}

///|
fn clone_field(f : Field) -> Field {
  let primary = match f.primary {
    Some(p) => Some(clone_scalar(p))
    None => None
  }
  let composite = match f.composite {
    Some(c) => Some(clone_composite(c))
    None => None
  }
  Field::new(f.name, primary, composite, f.references.copy())
}

///|
fn clone_edge_id(id : EdgeID) -> EdgeID {
  {
    src_path: id.src_path.copy(),
    src_arrow: id.src_arrow,
    dst_path: id.dst_path.copy(),
    dst_arrow: id.dst_arrow,
    index: id.index,
    glob: id.glob,
  }
}

///|
fn clone_edge(e : Edge) -> Edge {
  let primary = match e.primary {
    Some(p) => Some(clone_scalar(p))
    None => None
  }
  let map = match e.map {
    Some(m) => Some(clone_map(m))
    None => None
  }
  Edge::new(clone_edge_id(e.id), primary, map, e.references.copy())
}

///|
fn clone_value(v : Value) -> Value {
  match v {
    Value::Scalar(s) => Value::Scalar(clone_scalar(s))
    Value::Map(m) => Value::Map(clone_map(m))
    Value::Array(a) => Value::Array(clone_array(a))
  }
}

///|
fn clone_array(a : IRArray) -> IRArray {
  let values : Array[Value] = []
  for v in a.values {
    values.push(clone_value(v))
  }
  IRArray::new(values)
}
