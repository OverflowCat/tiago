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
/// IR (Intermediate Representation) for diago
///
/// The IR is a tree data structure that keeps track of resolved values
/// of diago keys after processing variable substitutions, imports, and globs.

///|
/// A scalar value in the IR.
///
/// Scalars carry a source `range` for error reporting and reference tracking.
pub struct Scalar {
  value : ScalarValue
  range : @lexer.Range
} derive(Eq, Show)

///|
/// Types of scalar values
pub(all) enum ScalarValue {
  Null
  Bool(String)
  Number(String)
  String(@ast.StringValue)
} derive(Eq, Show)

///|
/// An IR Map containing fields and edges
pub struct Map {
  fields : Array[Field]
  edges : Array[Edge]
} derive(Eq, Show)

///|
/// A field in the IR map
pub struct Field {
  name : String
  primary : Scalar?
  composite : Composite?
  references : Array[FieldReference]
} derive(Eq, Show)

///|
/// Composite values (Array or Map)
pub(all) enum Composite {
  Array(IRArray)
  Map(Map)
} derive(Eq, Show)

///|
/// An array of values
pub struct IRArray {
  values : Array[Value]
} derive(Eq, Show)

///|
/// Value types in IR
pub(all) enum Value {
  Scalar(Scalar)
  Array(IRArray)
  Map(Map)
} derive(Eq, Show)

///|
/// An edge in the IR
pub struct Edge {
  id : EdgeID
  primary : Scalar?
  map : Map?
  references : Array[EdgeReference]
} derive(Eq, Show)

///|
/// Unique identifier for an edge
pub struct EdgeID {
  src_path : Array[String]
  src_arrow : Bool
  dst_path : Array[String]
  dst_arrow : Bool
  index : Int?
  glob : Bool
} derive(Eq, Show)

///|
/// Reference to a field from the AST
pub struct FieldReference {
  range : @lexer.Range
  string : String
  key_path_index : Int
  primary : Bool
  due_to_glob : Bool
  due_to_lazy_glob : Bool
} derive(Eq, Show)

///|
/// Reference to an edge from the AST
pub struct EdgeReference {
  range : @lexer.Range
  edge_index : Int
  primary : Bool
  due_to_glob : Bool
  due_to_lazy_glob : Bool
} derive(Eq, Show)

///|
/// Boxed IR node for generic traversal.
pub(all) enum Node {
  Scalar(Scalar)
  Field(Field)
  Edge(Edge)
  IRArray(IRArray)
  Map(Map)
  Composite(Composite)
  Value(Value)
} derive(Eq, Show)

///|
pub fn Node::node_type(self : Node) -> String {
  match self {
    Scalar(_) => "Scalar"
    Field(_) => "Field"
    Edge(_) => "Edge"
    IRArray(_) => "IRArray"
    Map(_) => "Map"
    Composite(_) => "Composite"
    Value(_) => "Value"
  }
}

///|
pub fn Node::children(self : Node) -> Array[Node] {
  let out : Array[Node] = []
  match self {
    Scalar(_) => ()
    Field(f) => {
      match f.primary {
        Some(s) => out.push(Scalar(s))
        None => ()
      }
      match f.composite {
        Some(c) => out.push(Composite(c))
        None => ()
      }
    }
    Edge(e) => {
      match e.primary {
        Some(s) => out.push(Scalar(s))
        None => ()
      }
      match e.map {
        Some(m) => out.push(Map(m))
        None => ()
      }
    }
    IRArray(a) =>
      for v in a.values {
        out.push(Value(v))
      }
    Map(m) => {
      for f in m.fields {
        out.push(Field(f))
      }
      for e in m.edges {
        out.push(Edge(e))
      }
    }
    Composite(c) =>
      match c {
        Array(a) => out.push(IRArray(a))
        Map(m) => out.push(Map(m))
      }
    Value(v) =>
      match v {
        Scalar(s) => out.push(Scalar(s))
        Array(a) => out.push(IRArray(a))
        Map(m) => out.push(Map(m))
      }
  }
  out
}

// ============================================================================
// Constructors
// ============================================================================

///|
fn default_range() -> @lexer.Range {
  let p = @lexer.Position::zero()
  @lexer.Range::new(p, p)
}

///|
pub fn Scalar::at(range : @lexer.Range, value : ScalarValue) -> Scalar {
  { value, range }
}

///|
pub fn Scalar::new(value : ScalarValue) -> Scalar {
  Scalar::at(default_range(), value)
}

///|
pub fn Scalar::null() -> Scalar {
  Scalar::at(default_range(), ScalarValue::Null)
}

///|
pub fn Scalar::bool(b : Bool) -> Scalar {
  let s = if b { "true" } else { "false" }
  Scalar::at(default_range(), ScalarValue::Bool(s))
}

///|
pub fn Scalar::number(n : String) -> Scalar {
  Scalar::at(default_range(), ScalarValue::Number(n))
}

///|
pub fn Scalar::string(s : String) -> Scalar {
  let r = default_range()
  Scalar::at(
    r,
    ScalarValue::String(
      @ast.StringValue::Unquoted(
        @ast.UnquotedString::new(r, [@ast.Interpolation::Text(s)], []),
      ),
    ),
  )
}

///|
pub fn Map::new() -> Map {
  { fields: [], edges: [] }
}

///|
pub fn Field::new(
  name : String,
  primary : Scalar?,
  composite : Composite?,
  references : Array[FieldReference],
) -> Field {
  { name, primary, composite, references }
}

///|
pub fn Field::simple(name : String) -> Field {
  { name, primary: None, composite: None, references: [] }
}

///|
pub fn IRArray::new(values : Array[Value]) -> IRArray {
  { values, }
}

///|
pub fn Edge::new(
  id : EdgeID,
  primary : Scalar?,
  map : Map?,
  references : Array[EdgeReference],
) -> Edge {
  { id, primary, map, references }
}

///|
pub fn EdgeID::new(
  src_path : Array[String],
  dst_path : Array[String],
  src_arrow : Bool,
  dst_arrow : Bool,
) -> EdgeID {
  { src_path, src_arrow, dst_path, dst_arrow, index: None, glob: false }
}

///|
pub fn EdgeID::with_index(
  src_path : Array[String],
  dst_path : Array[String],
  src_arrow : Bool,
  dst_arrow : Bool,
  index : Int,
) -> EdgeID {
  { src_path, src_arrow, dst_path, dst_arrow, index: Some(index), glob: false }
}

///|
pub fn EdgeID::with_glob(
  src_path : Array[String],
  dst_path : Array[String],
  src_arrow : Bool,
  dst_arrow : Bool,
) -> EdgeID {
  { src_path, src_arrow, dst_path, dst_arrow, index: None, glob: true }
}

///|
pub fn FieldReference::new(
  range : @lexer.Range,
  string : String,
  key_path_index : Int,
  primary : Bool,
) -> FieldReference {
  {
    range,
    string,
    key_path_index,
    primary,
    due_to_glob: false,
    due_to_lazy_glob: false,
  }
}

///|
pub fn EdgeReference::new(
  range : @lexer.Range,
  edge_index : Int,
  primary : Bool,
) -> EdgeReference {
  { range, edge_index, primary, due_to_glob: false, due_to_lazy_glob: false }
}

// ============================================================================
// Map operations
// ============================================================================

///|
/// Get a field by name (case-insensitive)
pub fn Map::get_field(self : Map, name : String) -> Field? {
  let lower = name.to_lower()
  for f in self.fields {
    if f.name.to_lower() == lower {
      return Some(f)
    }
  }
  None
}

///|
/// Check if map has a field with given name
pub fn Map::has_field(self : Map, name : String) -> Bool {
  self.get_field(name) is Some(_)
}

///|
/// Add a field to the map
pub fn Map::add_field(self : Map, field : Field) -> Unit {
  self.fields.push(field)
}

///|
fn Map::set_field(self : Map, field : Field) -> Unit {
  let lower = field.name.to_lower()
  for i, f in self.fields {
    if f.name.to_lower() == lower {
      self.fields[i] = field
      return
    }
  }
  self.fields.push(field)
}

///|
/// Add an edge to the map
pub fn Map::add_edge(self : Map, edge : Edge) -> Unit {
  self.edges.push(edge)
}

///|
fn Map::set_edge(self : Map, edge : Edge) -> Unit {
  for i, e in self.edges {
    if e.id == edge.id {
      self.edges[i] = edge
      return
    }
  }
  self.edges.push(edge)
}

///|
/// Get or create a field by name
pub fn Map::ensure_field(self : Map, name : String) -> Field {
  match self.get_field(name) {
    Some(f) => f
    None => {
      let f = Field::simple(name)
      self.fields.push(f)
      f
    }
  }
}

///|
/// Delete a field by name, returning it if found
pub fn Map::delete_field(self : Map, name : String) -> Field? {
  let lower = name.to_lower()
  for i, f in self.fields {
    if f.name.to_lower() == lower {
      // Remove and return
      let removed = self.fields.remove(i)
      return Some(removed)
    }
  }
  None
}

///|
/// Find edges matching an EdgeID
pub fn Map::find_edges(self : Map, id : EdgeID) -> Array[Edge] {
  let result : Array[Edge] = []
  for e in self.edges {
    if e.id.matches(id) {
      result.push(e)
    }
  }
  result
}

// ============================================================================
// EdgeID operations
// ============================================================================

///|
/// Check if this EdgeID matches another (for queries)
pub fn EdgeID::matches(self : EdgeID, other : EdgeID) -> Bool {
  // Check index if both have it
  match (self.index, other.index) {
    (Some(i1), Some(i2)) => if i1 != i2 { return false }
    _ => ()
  }
  // Check arrows
  if self.src_arrow != other.src_arrow {
    return false
  }
  if self.dst_arrow != other.dst_arrow {
    return false
  }
  // Check paths (case-insensitive)
  if self.src_path.length() != other.src_path.length() {
    return false
  }
  for i, s in self.src_path {
    if s.to_lower() != other.src_path[i].to_lower() {
      return false
    }
  }
  if self.dst_path.length() != other.dst_path.length() {
    return false
  }
  for i, s in self.dst_path {
    if s.to_lower() != other.dst_path[i].to_lower() {
      return false
    }
  }
  true
}

///|
/// Create a copy of this EdgeID
pub fn EdgeID::copy(self : EdgeID) -> EdgeID {
  {
    src_path: self.src_path.copy(),
    src_arrow: self.src_arrow,
    dst_path: self.dst_path.copy(),
    dst_arrow: self.dst_arrow,
    index: self.index,
    glob: self.glob,
  }
}

// ============================================================================
// Value operations
// ============================================================================

///|
/// Get the scalar value if this is a scalar
pub fn Value::as_scalar(self : Value) -> Scalar? {
  match self {
    Scalar(s) => Some(s)
    _ => None
  }
}

///|
/// Get the map if this is a map
pub fn Value::as_map(self : Value) -> Map? {
  match self {
    Map(m) => Some(m)
    _ => None
  }
}

///|
/// Get the array if this is an array
pub fn Value::as_array(self : Value) -> IRArray? {
  match self {
    Array(a) => Some(a)
    _ => None
  }
}

// ============================================================================
// Scalar operations
// ============================================================================

///|
/// Get the string representation of a scalar value
pub fn Scalar::to_string(self : Scalar) -> String {
  match self.value {
    Null => "null"
    Bool(s) => s
    Number(n) => n
    String(s) => s.content()
  }
}

///|
/// Get underlying string value (including block-string metadata) if present
pub fn Scalar::as_string_value(self : Scalar) -> @ast.StringValue? {
  match self.value {
    String(s) => Some(s)
    _ => None
  }
}

///|
/// Get block-string language tag if this scalar is a block string
pub fn Scalar::block_string_tag(self : Scalar) -> String? {
  match self.value {
    String(@ast.StringValue::Block(bs)) => Some(bs.tag)
    _ => None
  }
}

///|
/// Check if scalar is null
pub fn Scalar::is_null(self : Scalar) -> Bool {
  self.value is Null
}

///|
/// Check if scalar is a boolean
pub fn Scalar::is_bool(self : Scalar) -> Bool {
  self.value is Bool(_)
}

///|
/// Get boolean value if this is a boolean
pub fn Scalar::as_bool(self : Scalar) -> Bool? {
  match self.value {
    Bool(s) =>
      match s.to_lower() {
        "true" => Some(true)
        "false" => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
pub fn Scalar::as_int(self : Scalar) -> Int? {
  match self.value {
    Number(n) => Some(@strconv.parse_int(n)) catch { _ => None }
    String(s) => Some(@strconv.parse_int(s.content())) catch { _ => None }
    _ => None
  }
}

///|
pub fn Scalar::as_double(self : Scalar) -> Double? {
  match self.value {
    Number(n) => Some(@strconv.parse_double(n)) catch { _ => None }
    String(s) => Some(@strconv.parse_double(s.content())) catch { _ => None }
    _ => None
  }
}

///|
pub fn Scalar::get_range(self : Scalar) -> @lexer.Range {
  self.range
}

///|
/// Check if scalar is a number
pub fn Scalar::is_number(self : Scalar) -> Bool {
  self.value is Number(_)
}

///|
/// Check if scalar is a string
pub fn Scalar::is_string(self : Scalar) -> Bool {
  self.value is String(_)
}

// ============================================================================
// Field operations
// ============================================================================

///|
/// Get the map composite if this field has one
pub fn Field::map(self : Field) -> Map? {
  match self.composite {
    Some(Composite::Map(m)) => Some(m)
    _ => None
  }
}

///|
/// Get the array composite if this field has one
pub fn Field::array(self : Field) -> IRArray? {
  match self.composite {
    Some(Composite::Array(a)) => Some(a)
    _ => None
  }
}

///|
/// Check if this field has a primary value
pub fn Field::has_primary(self : Field) -> Bool {
  self.primary is Some(_)
}

///|
/// Check if this field has a composite value
pub fn Field::has_composite(self : Field) -> Bool {
  self.composite is Some(_)
}
