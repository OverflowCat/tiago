///|
pub struct Point {
  mut x : Double
  mut y : Double
}

///|
pub struct EdgeObj {
  v : String
  w : String
  name : String?
}

///|
pub enum Attr {
  Bool(Bool)
  Int(Int)
  Float(Double)
  String(String)
  Val(Value)
  Point(Point)
  Points(Array[Point])
  Edge(EdgeObj)
  Edges(Array[EdgeObj])
  Strings(Array[String])
  Ints(Array[Int])
}

///|
pub struct Attrs {
  map : Map[String, Attr]
}

///|
pub enum Value {
  VNull
  VBool(Bool)
  VInt(Int)
  VFloat(Double)
  VString(String)
  VAttrs(Attrs)
}

///|
pub fn point(x : Double, y : Double) -> Point {
  { x, y }
}

///|
pub fn edge_obj(v : String, w : String, name? : String) -> EdgeObj {
  { v, w, name }
}

///|
pub fn empty_attrs() -> Attrs {
  { map: Map::new() }
}

///|
pub fn clone_attrs(attrs : Attrs) -> Attrs {
  { map: attrs.map.copy() }
}

///|
pub fn attrs_value(attrs : Attrs) -> Value {
  Value::VAttrs(attrs)
}

///|
pub fn value_null() -> Value {
  Value::VNull
}

///|
pub fn value_bool(v : Bool) -> Value {
  Value::VBool(v)
}

///|
pub fn value_int(v : Int) -> Value {
  Value::VInt(v)
}

///|
pub fn value_float(v : Double) -> Value {
  Value::VFloat(v)
}

///|
pub fn value_string(v : String) -> Value {
  Value::VString(v)
}

///|
pub fn clone_value(value : Value) -> Value {
  match value {
    Value::VNull => Value::VNull
    Value::VBool(v) => Value::VBool(v)
    Value::VInt(v) => Value::VInt(v)
    Value::VFloat(v) => Value::VFloat(v)
    Value::VString(v) => Value::VString(v)
    Value::VAttrs(attrs) => Value::VAttrs(clone_attrs(attrs))
  }
}

///|
pub fn value_as_attrs(value : Value?) -> Attrs? {
  match value {
    Some(Value::VAttrs(attrs)) => Some(attrs)
    _ => None
  }
}

///|
pub fn value_as_int(value : Value?) -> Int? {
  match value {
    Some(Value::VInt(v)) => Some(v)
    Some(Value::VFloat(v)) => Some(v.to_int())
    _ => None
  }
}

///|
pub fn value_as_float(value : Value?) -> Double? {
  match value {
    Some(Value::VInt(v)) => Some(v.to_double())
    Some(Value::VFloat(v)) => Some(v)
    _ => None
  }
}

///|
pub fn value_as_string(value : Value?) -> String? {
  match value {
    Some(Value::VString(v)) => Some(v)
    _ => None
  }
}

///|
pub fn value_as_bool(value : Value?) -> Bool? {
  match value {
    Some(Value::VBool(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::contains(self : Attrs, key : String) -> Bool {
  self.map.contains(key)
}

///|
pub fn Attrs::remove(self : Attrs, key : String) -> Unit {
  self.map.remove(key)
}

///|
pub fn Attrs::get(self : Attrs, key : String) -> Attr? {
  self.map.get(key)
}

///|
pub fn Attrs::set(self : Attrs, key : String, value : Attr) -> Unit {
  self.map.set(key, value)
}

///|
pub fn Attrs::keys(self : Attrs) -> Array[String] {
  self.map.keys().to_array()
}

///|
pub fn Attrs::length(self : Attrs) -> Int {
  self.map.length()
}

///|
pub fn Attrs::set_int(self : Attrs, key : String, value : Int) -> Unit {
  self.set(key, Attr::Int(value))
}

///|
pub fn Attrs::set_float(self : Attrs, key : String, value : Double) -> Unit {
  self.set(key, Attr::Float(value))
}

///|
pub fn Attrs::set_bool(self : Attrs, key : String, value : Bool) -> Unit {
  self.set(key, Attr::Bool(value))
}

///|
pub fn Attrs::set_string(self : Attrs, key : String, value : String) -> Unit {
  self.set(key, Attr::String(value))
}

///|
pub fn Attrs::set_point(self : Attrs, key : String, value : Point) -> Unit {
  self.set(key, Attr::Point(value))
}

///|
pub fn Attrs::set_value(self : Attrs, key : String, value : Value) -> Unit {
  self.set(key, Attr::Val(value))
}

///|
pub fn Attrs::set_points(
  self : Attrs,
  key : String,
  value : Array[Point],
) -> Unit {
  self.set(key, Attr::Points(value))
}

///|
pub fn Attrs::set_edge(self : Attrs, key : String, value : EdgeObj) -> Unit {
  self.set(key, Attr::Edge(value))
}

///|
pub fn Attrs::set_edges(
  self : Attrs,
  key : String,
  value : Array[EdgeObj],
) -> Unit {
  self.set(key, Attr::Edges(value))
}

///|
pub fn Attrs::set_strings(
  self : Attrs,
  key : String,
  value : Array[String],
) -> Unit {
  self.set(key, Attr::Strings(value))
}

///|
pub fn Attrs::set_ints(self : Attrs, key : String, value : Array[Int]) -> Unit {
  self.set(key, Attr::Ints(value))
}

///|
pub fn Attrs::get_int(self : Attrs, key : String) -> Int? {
  match self.get(key) {
    Some(Attr::Int(v)) => Some(v)
    Some(Attr::Float(v)) => Some(v.to_int())
    _ => None
  }
}

///|
pub fn Attrs::get_float(self : Attrs, key : String) -> Double? {
  match self.get(key) {
    Some(Attr::Int(v)) => Some(v.to_double())
    Some(Attr::Float(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::get_bool(self : Attrs, key : String) -> Bool? {
  match self.get(key) {
    Some(Attr::Bool(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::get_string(self : Attrs, key : String) -> String? {
  match self.get(key) {
    Some(Attr::String(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::get_point(self : Attrs, key : String) -> Point? {
  match self.get(key) {
    Some(Attr::Point(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::get_value(self : Attrs, key : String) -> Value? {
  match self.get(key) {
    Some(Attr::Val(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::get_points(self : Attrs, key : String) -> Array[Point]? {
  match self.get(key) {
    Some(Attr::Points(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::get_edge(self : Attrs, key : String) -> EdgeObj? {
  match self.get(key) {
    Some(Attr::Edge(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::get_edges(self : Attrs, key : String) -> Array[EdgeObj]? {
  match self.get(key) {
    Some(Attr::Edges(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::get_strings(self : Attrs, key : String) -> Array[String]? {
  match self.get(key) {
    Some(Attr::Strings(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::get_ints(self : Attrs, key : String) -> Array[Int]? {
  match self.get(key) {
    Some(Attr::Ints(v)) => Some(v)
    _ => None
  }
}

///|
pub fn Attrs::get_int_or(self : Attrs, key : String, fallback : Int) -> Int {
  if self.get_int(key) is Some(v) {
    v
  } else {
    fallback
  }
}

///|
pub fn Attrs::get_float_or(
  self : Attrs,
  key : String,
  fallback : Double,
) -> Double {
  if self.get_float(key) is Some(v) {
    v
  } else {
    fallback
  }
}

///|
pub fn Attrs::get_string_or(
  self : Attrs,
  key : String,
  fallback : String,
) -> String {
  if self.get_string(key) is Some(v) {
    v
  } else {
    fallback
  }
}

///|
pub fn Attrs::get_bool_or(self : Attrs, key : String, fallback : Bool) -> Bool {
  if self.get_bool(key) is Some(v) {
    v
  } else {
    fallback
  }
}
