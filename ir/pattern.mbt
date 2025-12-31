///|
/// Glob patterns and filters for D2 IR
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
  "grid-columns", "grid-gap", "horizontal-gap", "vertical-gap", "constraint", "layers",
  "scenarios", "steps",
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
pub fn is_double_glob(pattern : Array[String]) -> Bool {
  pattern.length() == 1 && pattern[0] == "**"
}

///|
/// Check if pattern represents a triple glob (***)
pub fn is_triple_glob(pattern : Array[String]) -> Bool {
  pattern.length() == 1 && pattern[0] == "***"
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
  // Collect matching fields
  let fields = if is_double_glob(pattern) {
    self.double_glob()
  } else if is_triple_glob(pattern) {
    self.triple_glob()
  } else {
    self.single_glob(pattern)
  }
  // Apply properties to each matching field that passes filters
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
      apply_properties_to_field(f, properties)
    }
  }
}

///|
/// Apply properties from a source map to a field
fn apply_properties_to_field(field : Field, properties : Map) -> Unit {
  // Ensure field has a composite map
  let field_map = match field.composite {
    Some(Composite::Map(m)) => m
    None => {
      let m = Map::new()
      field.composite = Some(Composite::Map(m))
      m
    }
    Some(_) => return // Can't apply to arrays
  }
  // Copy properties
  for prop in properties.fields {
    match field_map.get_field(prop.name) {
      Some(existing) => {
        // Update existing property
        if prop.primary is Some(_) {
          existing.primary = prop.primary
        }
        if prop.composite is Some(_) {
          existing.composite = prop.composite
        }
      }
      None =>
        // Add new property
        field_map.add_field(
          Field::new(prop.name, prop.primary, prop.composite, []),
        )
    }
  }
}
