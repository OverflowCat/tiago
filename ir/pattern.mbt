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
/// Glob patterns and filters for diago IR
///
/// Supports:
/// - Single glob (*): matches any characters at one level
/// - Double glob (**): matches all descendants recursively
/// - Triple glob (***): matches all descendants including boards
/// - Filters (&key: value): conditionally apply properties

///|
/// Reserved keywords that shouldn't be matched by globs
let reserved_keywords : Array[String] = [
  "label", "shape", "icon", "style", "width", "height", "top", "left", "near", "tooltip",
  "link", "class", "vars", "source-arrowhead", "target-arrowhead", "direction", "grid-rows",
  "grid-columns", "grid-gap", "horizontal-gap", "vertical-gap", "grid-column-span",
  "grid-row-span", "constraint", "layers", "scenarios", "steps",
]

///|
/// Board keywords (for triple glob)
let board_keywords : Array[String] = ["layers", "scenarios", "steps"]

///|
/// Check if a keyword is reserved
pub fn is_reserved_keyword(name : String) -> Bool {
  let lower = name.to_lower()
  for kw in reserved_keywords {
    if kw == lower {
      return true
    }
  }
  false
}

///|
/// Check if a keyword is a board keyword
pub fn is_board_keyword(name : String) -> Bool {
  let lower = name.to_lower()
  for kw in board_keywords {
    if kw == lower {
      return true
    }
  }
  false
}

///|
/// Check if pattern represents a double glob (**)
/// Parser stores ** as ["*", "", "*"]
pub fn is_double_glob(pattern : Array[String]) -> Bool {
  if pattern.length() == 1 && pattern[0] == "**" {
    return true
  }
  // Parser format: ["*", "", "*"]
  if pattern.length() == 3 &&
    pattern[0] == "*" &&
    pattern[1] == "" &&
    pattern[2] == "*" {
    return true
  }
  false
}

///|
/// Check if pattern represents a triple glob (***)
/// Parser stores *** as ["*", "", "*", "", "*"]
pub fn is_triple_glob(pattern : Array[String]) -> Bool {
  if pattern.length() == 1 && pattern[0] == "***" {
    return true
  }
  // Parser format: ["*", "", "*", "", "*"]
  if pattern.length() == 5 &&
    pattern[0] == "*" &&
    pattern[1] == "" &&
    pattern[2] == "*" &&
    pattern[3] == "" &&
    pattern[4] == "*" {
    return true
  }
  false
}

///|
/// Collect all fields matching a double glob (**) pattern
/// This recursively collects all descendant fields except board keywords
pub fn Map::double_glob(self : Map) -> Array[Field] {
  let result : Array[Field] = []
  self.double_glob_helper(result)
  result
}

///|
fn Map::double_glob_helper(self : Map, result : Array[Field]) -> Unit {
  for f in self.fields {
    // Skip reserved keywords (but check if it's a board keyword)
    if is_reserved_keyword(f.name) {
      if is_board_keyword(f.name) {
        // Skip board keywords entirely for double glob
        continue
      }
      // For other reserved keywords, descend but don't add
      match f.composite {
        Some(Composite::Map(m)) => m.double_glob_helper(result)
        _ => ()
      }
      continue
    }
    // Add this field
    result.push(f)
    // Recursively collect from children
    match f.composite {
      Some(Composite::Map(m)) => m.double_glob_helper(result)
      _ => ()
    }
  }
}

///|
/// Collect all fields matching a triple glob (***) pattern
/// This recursively collects all descendant fields including boards
pub fn Map::triple_glob(self : Map) -> Array[Field] {
  let result : Array[Field] = []
  self.triple_glob_helper(result)
  result
}

///|
fn Map::triple_glob_helper(self : Map, result : Array[Field]) -> Unit {
  for f in self.fields {
    // Skip non-board reserved keywords
    if is_reserved_keyword(f.name) && !is_board_keyword(f.name) {
      match f.composite {
        Some(Composite::Map(m)) => m.triple_glob_helper(result)
        _ => ()
      }
      continue
    }
    // Add this field (including board fields)
    if !is_board_keyword(f.name) {
      result.push(f)
    }
    // Recursively collect from children
    match f.composite {
      Some(Composite::Map(m)) => m.triple_glob_helper(result)
      _ => ()
    }
  }
}

///|
/// Collect fields matching a multi-glob pattern (** or ***)
/// Returns (fields, is_glob_pattern)
pub fn Map::multi_glob(
  self : Map,
  pattern : Array[String],
) -> (Array[Field], Bool) {
  if is_double_glob(pattern) {
    (self.double_glob(), true)
  } else if is_triple_glob(pattern) {
    (self.triple_glob(), true)
  } else {
    ([], false)
  }
}

///|
/// Match a string against a glob pattern
/// Pattern is an array where elements are either:
/// - literal text to match
/// - "*" to match any characters
pub fn match_pattern(s : String, pattern : Array[String]) -> Bool {
  // Don't match reserved keywords
  if is_reserved_keyword(s) {
    return false
  }
  if pattern.length() == 0 {
    return true
  }
  let s_lower = s.to_lower()
  let mut remaining = s_lower
  let mut i = 0
  while i < pattern.length() {
    if pattern[i] == "*" {
      // Wildcard: match next literal if there is one
      if i != pattern.length() - 1 {
        let next_pattern = pattern[i + 1].to_lower()
        match string_index_of(remaining, next_pattern) {
          Some(j) => {
            remaining = string_substring(remaining, j + next_pattern.length())
            i = i + 2
          }
          None => return false
        }
      } else {
        // Trailing *, matches everything remaining
        i = i + 1
      }
    } else {
      // Literal match at start of remaining
      let pattern_lower = pattern[i].to_lower()
      if !remaining.has_prefix(pattern_lower) {
        return false
      }
      remaining = string_substring(remaining, pattern_lower.length())
      i = i + 1
    }
  }
  true
}

///|
/// Find index of substring in string (case-sensitive)
fn string_index_of(s : String, sub : String) -> Int? {
  if sub.length() == 0 {
    return Some(0)
  }
  if s.length() < sub.length() {
    return None
  }
  for i in 0..<(s.length() - sub.length() + 1) {
    let mut matches = true
    for j in 0..<sub.length() {
      if s.code_unit_at(i + j) != sub.code_unit_at(j) {
        matches = false
        break
      }
    }
    if matches {
      return Some(i)
    }
  }
  None
}

///|
/// Get substring from start index
fn string_substring(s : String, start : Int) -> String {
  if start >= s.length() {
    return ""
  }
  let buf = StringBuilder::new()
  for i in start..<s.length() {
    let code = s.code_unit_at(i).to_int()
    buf.write_char(code.unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Collect fields at one level matching a single glob pattern
pub fn Map::single_glob(self : Map, pattern : Array[String]) -> Array[Field] {
  let result : Array[Field] = []
  for f in self.fields {
    if match_pattern(f.name, pattern) {
      result.push(f)
    }
  }
  result
}

///|
/// Filter context for evaluating ampersand filters
pub struct FilterContext {
  /// Current field being filtered
  field : Field
  /// Parent map containing the field
  parent_map : Map
}

///|
pub fn FilterContext::new(field : Field, parent_map : Map) -> FilterContext {
  { field, parent_map }
}

///|
/// Evaluate a filter condition against a field
/// Returns true if the field passes the filter
pub fn evaluate_filter(
  ctx : FilterContext,
  filter_key : String,
  filter_value : String,
) -> Bool {
  // Check simple property filters
  match filter_key.to_lower() {
    "shape" =>
      // Match against shape property
      match get_field_property(ctx.field, "shape") {
        Some(v) => v.to_lower() == filter_value.to_lower()
        None => filter_value.to_lower() == "rectangle" // default shape
      }
    "label" =>
      // Match against primary value (label)
      match ctx.field.primary {
        Some(s) => s.to_string().to_lower() == filter_value.to_lower()
        None => filter_value == "" || filter_value == ctx.field.name
      }
    "opacity" =>
      match get_field_property(ctx.field, "opacity") {
        Some(v) => v == filter_value
        None => filter_value == "1" // default opacity
      }
    "stroke-width" =>
      match get_field_property(ctx.field, "stroke-width") {
        Some(v) => v == filter_value
        None => filter_value == "2" // default stroke-width
      }
    "border-radius" | "stroke-dash" =>
      match get_field_property(ctx.field, filter_key) {
        Some(v) => v == filter_value
        None => filter_value == "0" // default
      }
    "shadow" | "multiple" | "3d" | "animated" | "filled" =>
      match get_field_property(ctx.field, filter_key) {
        Some(v) => v.to_lower() == filter_value.to_lower()
        None => filter_value.to_lower() == "false" // default
      }
    "icon" | "tooltip" | "link" =>
      match get_field_property(ctx.field, filter_key) {
        Some(v) => v == filter_value
        None => filter_value == "" // default
      }
    _ =>
      // Try to find the property in the field's map
      match get_field_property(ctx.field, filter_key) {
        Some(v) => v.to_lower() == filter_value.to_lower()
        None => false
      }
  }
}

///|
/// Get a property value from a field's composite map
fn get_field_property(field : Field, key : String) -> String? {
  match field.composite {
    Some(Composite::Map(m)) =>
      match m.get_field(key) {
        Some(f) =>
          match f.primary {
            Some(s) => Some(s.to_string())
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
/// Apply properties to fields matching a glob pattern
/// If filters are provided, only apply to fields that pass all filters
pub fn Map::apply_glob_properties(
  self : Map,
  pattern : Array[String],
  properties : Map,
  filters : Array[(Bool, String, String)],
) -> Unit {
  if is_double_glob(pattern) {
    self.apply_multi_glob_properties(properties, filters, false)
    return
  }
  if is_triple_glob(pattern) {
    self.apply_multi_glob_properties(properties, filters, true)
    return
  }

  // Single-level glob: apply only within this map
  let fields = self.single_glob(pattern)
  for f in fields {
    let ctx = FilterContext::new(f, self)
    let mut passes_all = true
    for filter in filters {
      let (negated, key, value) = filter
      let result = evaluate_filter(ctx, key, value)
      let passes = if negated { !result } else { result }
      if !passes {
        passes_all = false
        break
      }
    }
    if passes_all {
      let updated = apply_properties_to_field(f, properties)
      self.set_field(updated)
    }
  }
}

///|
/// Apply properties recursively for **/*** patterns.
/// `include_boards` matches the *** behavior: descend into boards but do not
/// apply to reserved keywords, and do not apply to the board field itself.
fn Map::apply_multi_glob_properties(
  self : Map,
  properties : Map,
  filters : Array[(Bool, String, String)],
  include_boards : Bool,
) -> Unit {
  // Snapshot fields so newly added properties (like `style`) aren't re-visited.
  let snapshot : Array[Field] = []
  for f in self.fields {
    snapshot.push(f)
  }
  for f in snapshot {
    // Capture original children before any mutation.
    let child_map = match f.composite {
      Some(Composite::Map(m)) => Some(m)
      _ => None
    }
    if include_boards {
      // Triple glob (***): descend into boards, but don't apply to reserved keywords.
      if is_board_keyword(f.name) {
        match child_map {
          Some(m) =>
            m.apply_multi_glob_properties(properties, filters, include_boards)
          None => ()
        }
        continue
      }
      if is_reserved_keyword(f.name) {
        continue
      }
      // Double glob (**): don't apply to reserved keywords (including `style`).
    } else if is_reserved_keyword(f.name) {
      continue
    }

    // Apply properties to this field if it passes filters.
    let ctx = FilterContext::new(f, self)
    let mut passes_all = true
    for filter in filters {
      let (negated, key, value) = filter
      let result = evaluate_filter(ctx, key, value)
      let passes = if negated { !result } else { result }
      if !passes {
        passes_all = false
        break
      }
    }
    if passes_all {
      let updated = apply_properties_to_field(f, properties)
      self.set_field(updated)
    }

    // Descend into original children (not newly added properties).
    match child_map {
      Some(m) =>
        m.apply_multi_glob_properties(properties, filters, include_boards)
      None => ()
    }
  }
}

///|
fn clone_value_for_properties(v : Value) -> Value {
  match v {
    Value::Scalar(s) => Value::Scalar(s)
    Value::Array(a) => Value::Array(clone_irarray_for_properties(a))
    Value::Map(m) => Value::Map(clone_map_for_properties(m))
  }
}

///|
fn clone_irarray_for_properties(a : IRArray) -> IRArray {
  let values : Array[Value] = []
  for v in a.values {
    values.push(clone_value_for_properties(v))
  }
  { values, ast: a.ast, source_path: a.source_path }
}

///|
fn clone_composite_for_properties(c : Composite) -> Composite {
  match c {
    Composite::Array(a) => Composite::Array(clone_irarray_for_properties(a))
    Composite::Map(m) => Composite::Map(clone_map_for_properties(m))
  }
}

///|
fn clone_field_for_properties(f : Field) -> Field {
  let composite = match f.composite {
    Some(c) => Some(clone_composite_for_properties(c))
    None => None
  }
  Field::new(f.name, f.primary, composite, f.references.copy())
}

///|
fn clone_map_for_properties(m : Map) -> Map {
  let out : Map = {
    fields: [],
    edges: [],
    ast: m.ast,
    source_path: m.source_path,
  }
  for f in m.fields {
    out.add_field(clone_field_for_properties(f))
  }
  // Edges are not expected in property maps.
  out
}

///|
fn merge_properties_into_map(target : Map, src : Map) -> Unit {
  for prop in src.fields {
    match target.get_field(prop.name) {
      Some(existing) => {
        let primary = if prop.primary is Some(_) {
          prop.primary
        } else {
          existing.primary
        }
        let composite = match prop.composite {
          Some(Composite::Map(src_map)) =>
            match existing.composite {
              Some(Composite::Map(dst_map)) => {
                merge_properties_into_map(dst_map, src_map)
                existing.composite
              }
              _ => Some(Composite::Map(clone_map_for_properties(src_map)))
            }
          Some(other) => Some(clone_composite_for_properties(other))
          None => existing.composite
        }
        let updated = Field::new(
          existing.name,
          primary,
          composite,
          {
            let refs = existing.references.copy()
            for reference in prop.references {
              refs.push(reference)
            }
            refs
          },
        )
        target.set_field(updated)
      }
      None => target.add_field(clone_field_for_properties(prop))
    }
  }
}

///|
/// Apply properties from a source map to a field
fn apply_properties_to_field(field : Field, properties : Map) -> Field {
  // Ensure field has a composite map
  let (field, field_map) = match field.composite {
    Some(Composite::Map(m)) => (field, m)
    None => {
      let m = Map::new()
      let field = Field::new(
        field.name,
        field.primary,
        Some(Composite::Map(m)),
        field.references,
      )
      (field, m)
    }
    Some(_) => return field // Can't apply to arrays
  }
  // Copy properties
  merge_properties_into_map(field_map, properties)
  field
}
