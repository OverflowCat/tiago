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
/// Variable Substitution for diago IR
///
/// Handles `${var}` and `$var` substitution in diago diagrams.
/// Variables are defined in `vars` blocks and can be nested.

///|
/// Resolve all substitutions in a map
fn Map::resolve_substitutions(self : Map) -> Unit {
  // Build vars stack from this map
  let vars_stack : Array[Map] = []
  self.resolve_substitutions_with_stack(vars_stack)
}

///|
/// Resolve substitutions with a vars stack for scoping
fn Map::resolve_substitutions_with_stack(
  self : Map,
  vars_stack : Array[Map],
) -> Unit {
  // Check if this map has a vars field and add it to stack
  let local_vars_stack = match self.get_field("vars") {
    Some(vars_field) =>
      match vars_field.composite {
        Some(Composite::Map(vars_map)) => {
          // Prepend to stack (local scope first)
          let new_stack : Array[Map] = [vars_map]
          for v in vars_stack {
            new_stack.push(v)
          }
          new_stack
        }
        _ => vars_stack
      }
    None => vars_stack
  }
  // Resolve substitutions in each field
  for i, field in self.fields {
    let mut field = field
    // Skip the vars field itself
    if field.name.to_lower() == "vars" {
      // But still process nested vars for nested scopes
      match field.composite {
        Some(Composite::Map(m)) =>
          m.resolve_substitutions_with_stack(local_vars_stack)
        _ => ()
      }
      continue
    }
    // Resolve primary value substitutions
    if field.primary is Some(_) {
      field = Field::new(
        field.name,
        resolve_scalar_substitutions(field.primary, local_vars_stack),
        field.composite,
        field.references,
      )
    }
    // Recurse into composite
    match field.composite {
      Some(Composite::Map(m)) =>
        m.resolve_substitutions_with_stack(local_vars_stack)
      Some(Composite::Array(a)) =>
        a.resolve_substitutions_with_stack(local_vars_stack)
      None => ()
    }
    self.fields[i] = field
  }
  // Resolve substitutions in edges
  for i, edge in self.edges {
    let mut edge = edge
    if edge.primary is Some(_) {
      edge = Edge::new(
        edge.id,
        resolve_scalar_substitutions(edge.primary, local_vars_stack),
        edge.map,
        edge.references,
      )
    }
    match edge.map {
      Some(m) => m.resolve_substitutions_with_stack(local_vars_stack)
      None => ()
    }
    self.edges[i] = edge
  }
}

///|
/// Resolve substitutions in an array
fn IRArray::resolve_substitutions_with_stack(
  self : IRArray,
  vars_stack : Array[Map],
) -> Unit {
  for i, value in self.values {
    match value {
      Value::Scalar(s) => {
        let resolved = resolve_scalar_substitutions(Some(s), vars_stack)
        match resolved {
          Some(rs) => self.values[i] = Value::Scalar(rs)
          None => ()
        }
      }
      Value::Map(m) => m.resolve_substitutions_with_stack(vars_stack)
      Value::Array(a) => a.resolve_substitutions_with_stack(vars_stack)
    }
  }
}

///|
/// Resolve substitutions in a scalar value
/// Returns the resolved scalar (may be same as input if no substitution)
fn resolve_scalar_substitutions(
  scalar : Scalar?,
  vars_stack : Array[Map],
) -> Scalar? {
  guard scalar is Some(s) else { return None }
  // Check if this is a string that might contain substitutions
  match s.value {
    ScalarValue::String(str) =>
      // Look for ${...} or $name patterns
      match parse_substitution_in_string(str) {
        Some((var_path, is_complete)) =>
          // Resolve the variable
          match resolve_variable(var_path, vars_stack) {
            Some(value) =>
              if is_complete {
                // Entire string is a substitution, replace with resolved value
                Some(Scalar::at(s.range, ScalarValue::String(value)))
              } else {
                // Partial substitution, replace in string
                let resolved = replace_substitution(str, var_path, value)
                Some(Scalar::at(s.range, ScalarValue::String(resolved)))
              }
            None =>
              // Variable not found, keep original
              scalar
          }
        None => scalar
      }
    _ => scalar
  }
}

///|
/// Parse a substitution pattern from a string
/// Returns (variable_path, is_complete_substitution)
fn parse_substitution_in_string(s : String) -> (Array[String], Bool)? {
  // Look for ${...} pattern
  let mut i = 0
  while i < s.length() {
    if s.code_unit_at(i) == '$'.to_int().to_uint16() {
      if i + 1 < s.length() && s.code_unit_at(i + 1) == '{'.to_int().to_uint16() {
        // Found ${, look for }
        let start = i + 2
        let mut end = start
        while end < s.length() &&
              s.code_unit_at(end) != '}'.to_int().to_uint16() {
          end = end + 1
        }
        if end < s.length() {
          // Extract variable path
          let var_str = substring(s, start, end)
          let path = split_dot_path(var_str)
          // Check if this is the entire string
          let is_complete = i == 0 && end == s.length() - 1
          return Some((path, is_complete))
        }
      } else if i + 1 < s.length() {
        // Simple $name pattern
        let start = i + 1
        let mut end = start
        while end < s.length() && is_identifier_char(s.code_unit_at(end)) {
          end = end + 1
        }
        if end > start {
          let var_str = substring(s, start, end)
          let path = [var_str]
          let is_complete = i == 0 && end == s.length()
          return Some((path, is_complete))
        }
      }
    }
    i = i + 1
  }
  None
}

///|
/// Check if a character is valid in an identifier
fn is_identifier_char(c : UInt16) -> Bool {
  let ch = c.to_int()
  (ch >= 'a'.to_int() && ch <= 'z'.to_int()) ||
  (ch >= 'A'.to_int() && ch <= 'Z'.to_int()) ||
  (ch >= '0'.to_int() && ch <= '9'.to_int()) ||
  ch == '_'.to_int() ||
  ch == '-'.to_int()
}

///|
/// Extract substring from start to end (exclusive)
fn substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i in start..<end {
    buf.write_char(s.code_unit_at(i).to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Split a dot-separated path into parts
fn split_dot_path(s : String) -> Array[String] {
  let parts : Array[String] = []
  let buf = StringBuilder::new()
  for c in s {
    if c == '.' {
      if buf.to_string().length() > 0 {
        parts.push(buf.to_string())
        buf.reset()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    parts.push(buf.to_string())
  }
  parts
}

///|
/// Resolve a variable path from the vars stack
fn resolve_variable(path : Array[String], vars_stack : Array[Map]) -> String? {
  for vars in vars_stack {
    match resolve_variable_in_map(path, vars) {
      Some(value) => return Some(value)
      None => continue
    }
  }
  None
}

///|
/// Resolve a variable path in a single vars map
fn resolve_variable_in_map(path : Array[String], vars : Map) -> String? {
  if path.length() == 0 {
    return None
  }
  // Navigate to the field
  let mut current = vars
  for i = 0; i < path.length() - 1; i = i + 1 {
    match current.get_field(path[i]) {
      Some(f) =>
        match f.composite {
          Some(Composite::Map(m)) => current = m
          _ => return None
        }
      None => return None
    }
  }
  // Get the final field value
  let final_name = path[path.length() - 1]
  match current.get_field(final_name) {
    Some(f) =>
      match f.primary {
        Some(s) => Some(s.to_string())
        None => None
      }
    None => None
  }
}

///|
/// Replace a substitution in a string with a value
fn replace_substitution(
  s : String,
  path : Array[String],
  value : String,
) -> String {
  // Build the pattern to replace
  // Use character concatenation to avoid JS template literal issues
  let dollar = '$'.to_string()
  let open_brace = '{'.to_string()
  let close_brace = '}'.to_string()
  let pattern_braced = dollar +
    open_brace +
    join_strings(path, ".") +
    close_brace
  let pattern_simple = dollar + path[0]
  // Try braced pattern first
  match string_replace(s, pattern_braced, value) {
    Some(replaced) => return replaced
    None => ()
  }
  // Try simple pattern
  match string_replace(s, pattern_simple, value) {
    Some(replaced) => replaced
    None => s
  }
}

///|
/// Join array of strings with separator
fn join_strings(arr : Array[String], sep : String) -> String {
  let buf = StringBuilder::new()
  for i, s in arr {
    if i > 0 {
      buf.write_string(sep)
    }
    buf.write_string(s)
  }
  buf.to_string()
}

///|
/// Replace first occurrence of pattern in string
fn string_replace(
  s : String,
  pattern : String,
  replacement : String,
) -> String? {
  if pattern.length() == 0 {
    return None
  }
  // Find pattern in s
  let mut found = false
  let mut found_at = 0
  for i in 0..<(s.length() - pattern.length() + 1) {
    let mut matches = true
    for j in 0..<pattern.length() {
      if s.code_unit_at(i + j) != pattern.code_unit_at(j) {
        matches = false
        break
      }
    }
    if matches {
      found = true
      found_at = i
      break
    }
  }
  if !found {
    return None
  }
  // Build replacement string
  let buf = StringBuilder::new()
  for i in 0..<found_at {
    buf.write_char(s.code_unit_at(i).to_int().unsafe_to_char())
  }
  buf.write_string(replacement)
  for i in (found_at + pattern.length())..<s.length() {
    buf.write_char(s.code_unit_at(i).to_int().unsafe_to_char())
  }
  Some(buf.to_string())
}
