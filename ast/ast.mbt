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
/// AST nodes for the diago diagram language
///
/// The AST closely follows the diago language structure:
/// - Map is the root node and represents nested containers
/// - Key represents key-value pairs and edge declarations
/// - Edge represents connections between nodes

///|
/// A diago file is represented as a Map at the root level
pub struct Map {
  range : @lexer.Range
  nodes : Array[MapNode]
} derive(Eq, Show)

///|
/// Nodes that can appear inside a Map
pub(all) enum MapNode {
  Comment(@lexer.Range, String)
  BlockComment(@lexer.Range, String)
  Substitution(Substitution)
  Import(Import)
  Key(Key)
} derive(Eq, Show)

///|
/// A key declaration in a map
///
/// Examples:
/// - `x` (simple key)
/// - `x: value` (key with value)
/// - `x -> y` (edge)
/// - `container.child` (nested key path)
/// - `(x -> y).label` (edge with property)
pub struct Key {
  range : @lexer.Range
  ampersand : Bool
  not_ampersand : Bool
  key : KeyPath?
  edges : Array[Edge]
  edge_index : EdgeIndex?
  edge_key : KeyPath?
  primary : Scalar?
  value : Value?
} derive(Eq, Show)

///|
/// A path of identifiers separated by dots
/// Example: container.child.grandchild
pub struct KeyPath {
  range : @lexer.Range
  path : Array[StringValue]
} derive(Eq, Show)

///|
/// An edge between two nodes
pub struct Edge {
  range : @lexer.Range
  src : KeyPath
  src_arrow : String
  dst : KeyPath
  dst_arrow : String
} derive(Eq, Show)

///|
/// Index into an edge group
pub struct EdgeIndex {
  range : @lexer.Range
  index : Int?
  glob : Bool
} derive(Eq, Show)

///|
/// Values that can appear on the right side of a colon
pub(all) enum Value {
  Scalar(Scalar)
  Array(ArrayValue)
  Map(Map)
  Import(Import)
  /// Scalar label followed by a map block: `name: Label { props }`
  BlockScalar(Value, Map)
} derive(Eq, Show)

///|
/// An array value
pub struct ArrayValue {
  range : @lexer.Range
  nodes : Array[ArrayNode]
} derive(Eq, Show)

///|
/// Nodes that can appear inside an array
pub(all) enum ArrayNode {
  Comment(@lexer.Range, String)
  BlockComment(@lexer.Range, String)
  Substitution(Substitution)
  Import(Import)
  Value(Value)
} derive(Eq, Show)

///|
/// Scalar values
pub(all) enum Scalar {
  Null(@lexer.Range)
  Boolean(@lexer.Range, Bool)
  Number(@lexer.Range, String)
  String(StringValue)
} derive(Eq, Show)

///|
/// String values with their quote style
pub(all) enum StringValue {
  Unquoted(UnquotedString)
  SingleQuoted(@lexer.Range, String)
  DoubleQuoted(DoubleQuotedString)
  Block(BlockString)
} derive(Eq, Show)

///|
/// Unquoted string that may contain substitutions
pub struct UnquotedString {
  range : @lexer.Range
  value : Array[Interpolation]
  pattern : Array[String]
} derive(Eq, Show)

///|
/// Double-quoted string that may contain substitutions
pub struct DoubleQuotedString {
  range : @lexer.Range
  value : Array[Interpolation]
} derive(Eq, Show)

///|
/// Block string (|md, |sh, etc.)
pub struct BlockString {
  range : @lexer.Range
  quote : String
  tag : String
  value : String
} derive(Eq, Show)

///|
/// Part of an interpolated string
pub(all) enum Interpolation {
  Text(String)
  Sub(Substitution)
} derive(Eq, Show)

///|
/// Variable substitution ($var or ${var})
pub struct Substitution {
  range : @lexer.Range
  spread : Bool
  path : Array[StringValue]
} derive(Eq, Show)

///|
/// Import declaration (@path/to/file)
pub struct Import {
  range : @lexer.Range
  spread : Bool
  pre : String
  path : Array[StringValue]
} derive(Eq, Show)

// ============================================================================
// Constructor helpers
// ============================================================================

///|
pub fn Map::new(range : @lexer.Range, nodes : Array[MapNode]) -> Map {
  { range, nodes }
}

///|
pub fn Key::new(
  range : @lexer.Range,
  ampersand : Bool,
  not_ampersand : Bool,
  key : KeyPath?,
  edges : Array[Edge],
  edge_index : EdgeIndex?,
  edge_key : KeyPath?,
  primary : Scalar?,
  value : Value?,
) -> Key {
  {
    range,
    ampersand,
    not_ampersand,
    key,
    edges,
    edge_index,
    edge_key,
    primary,
    value,
  }
}

///|
pub fn KeyPath::new(range : @lexer.Range, path : Array[StringValue]) -> KeyPath {
  { range, path }
}

///|
pub fn Edge::new(
  range : @lexer.Range,
  src : KeyPath,
  dst : KeyPath,
  src_arrow : String,
  dst_arrow : String,
) -> Edge {
  { range, src, src_arrow, dst, dst_arrow }
}

///|
pub fn EdgeIndex::new(
  range : @lexer.Range,
  index : Int?,
  glob : Bool,
) -> EdgeIndex {
  { range, index, glob }
}

///|
pub fn ArrayValue::new(
  range : @lexer.Range,
  nodes : Array[ArrayNode],
) -> ArrayValue {
  { range, nodes }
}

///|
pub fn UnquotedString::new(
  range : @lexer.Range,
  value : Array[Interpolation],
  pattern : Array[String],
) -> UnquotedString {
  { range, value, pattern }
}

///|
pub fn DoubleQuotedString::new(
  range : @lexer.Range,
  value : Array[Interpolation],
) -> DoubleQuotedString {
  { range, value }
}

///|
pub fn BlockString::new(
  range : @lexer.Range,
  quote : String,
  tag : String,
  value : String,
) -> BlockString {
  { range, quote, tag, value }
}

///|
pub fn Substitution::new(
  range : @lexer.Range,
  spread : Bool,
  path : Array[StringValue],
) -> Substitution {
  { range, spread, path }
}

///|
pub fn Import::new(
  range : @lexer.Range,
  spread : Bool,
  pre : String,
  path : Array[StringValue],
) -> Import {
  { range, spread, pre, path }
}

///|
/// Boxed AST node for generic traversal.
///
/// This is intentionally a closed set of variants over the public AST structs/enums.
pub(all) enum Node {
  Map(Map)
  MapNode(MapNode)
  Key(Key)
  KeyPath(KeyPath)
  Edge(Edge)
  EdgeIndex(EdgeIndex)
  Value(Value)
  ArrayValue(ArrayValue)
  ArrayNode(ArrayNode)
  Scalar(Scalar)
  StringValue(StringValue)
  UnquotedString(UnquotedString)
  DoubleQuotedString(DoubleQuotedString)
  BlockString(BlockString)
  Substitution(Substitution)
  Import(Import)
} derive(Eq, Show)

// ============================================================================
// Helper methods
// ============================================================================

///|
pub fn MapNode::range(self : MapNode) -> @lexer.Range {
  match self {
    Comment(r, _) => r
    BlockComment(r, _) => r
    Substitution(s) => s.range
    Import(i) => i.range
    Key(k) => k.range
  }
}

///|
pub fn ArrayNode::range(self : ArrayNode) -> @lexer.Range {
  match self {
    Comment(r, _) => r
    BlockComment(r, _) => r
    Substitution(s) => s.range
    Import(i) => i.range
    Value(v) => v.range()
  }
}

///|
pub fn Node::range(self : Node) -> @lexer.Range {
  match self {
    Map(m) => m.range
    MapNode(n) => n.range()
    Key(k) => k.range
    KeyPath(kp) => kp.range
    Edge(e) => e.range
    EdgeIndex(ei) => ei.range
    Value(v) => v.range()
    ArrayValue(a) => a.range
    ArrayNode(n) => n.range()
    Scalar(s) => s.range()
    StringValue(s) => s.range()
    UnquotedString(s) => s.range
    DoubleQuotedString(s) => s.range
    BlockString(s) => s.range
    Substitution(s) => s.range
    Import(i) => i.range
  }
}

///|
pub fn Node::node_type(self : Node) -> String {
  match self {
    Map(_) => "Map"
    MapNode(_) => "MapNode"
    Key(_) => "Key"
    KeyPath(_) => "KeyPath"
    Edge(_) => "Edge"
    EdgeIndex(_) => "EdgeIndex"
    Value(_) => "Value"
    ArrayValue(_) => "ArrayValue"
    ArrayNode(_) => "ArrayNode"
    Scalar(_) => "Scalar"
    StringValue(_) => "StringValue"
    UnquotedString(_) => "UnquotedString"
    DoubleQuotedString(_) => "DoubleQuotedString"
    BlockString(_) => "BlockString"
    Substitution(_) => "Substitution"
    Import(_) => "Import"
  }
}

///|
pub fn Node::children(self : Node) -> Array[Node] {
  let out : Array[Node] = []
  match self {
    Map(m) =>
      for n in m.nodes {
        out.push(MapNode(n))
      }
    MapNode(n) =>
      match n {
        Comment(_, _) | BlockComment(_, _) => ()
        Substitution(s) => out.push(Substitution(s))
        Import(i) => out.push(Import(i))
        Key(k) => out.push(Key(k))
      }
    Key(k) => {
      match k.key {
        Some(kp) => out.push(KeyPath(kp))
        None => ()
      }
      for e in k.edges {
        out.push(Edge(e))
      }
      match k.edge_index {
        Some(ei) => out.push(EdgeIndex(ei))
        None => ()
      }
      match k.edge_key {
        Some(kp) => out.push(KeyPath(kp))
        None => ()
      }
      match k.primary {
        Some(s) => out.push(Scalar(s))
        None => ()
      }
      match k.value {
        Some(v) => out.push(Value(v))
        None => ()
      }
    }
    KeyPath(kp) =>
      for s in kp.path {
        out.push(StringValue(s))
      }
    Edge(e) => {
      out.push(KeyPath(e.src))
      out.push(KeyPath(e.dst))
    }
    EdgeIndex(_) => ()
    Value(v) =>
      match v {
        Scalar(s) => out.push(Scalar(s))
        Array(a) => out.push(ArrayValue(a))
        Map(m) => out.push(Map(m))
        Import(i) => out.push(Import(i))
        BlockScalar(v2, m2) => {
          out.push(Value(v2))
          out.push(Map(m2))
        }
      }
    ArrayValue(a) =>
      for n in a.nodes {
        out.push(ArrayNode(n))
      }
    ArrayNode(n) =>
      match n {
        Comment(_, _) | BlockComment(_, _) => ()
        Substitution(s) => out.push(Substitution(s))
        Import(i) => out.push(Import(i))
        Value(v) => out.push(Value(v))
      }
    Scalar(s) =>
      match s {
        String(str) => out.push(StringValue(str))
        _ => ()
      }
    StringValue(s) =>
      match s {
        Unquoted(u) => out.push(UnquotedString(u))
        DoubleQuoted(dq) => out.push(DoubleQuotedString(dq))
        Block(b) => out.push(BlockString(b))
        _ => ()
      }
    UnquotedString(u) =>
      for seg in u.value {
        match seg {
          Sub(sub) => out.push(Substitution(sub))
          _ => ()
        }
      }
    DoubleQuotedString(dq) =>
      for seg in dq.value {
        match seg {
          Sub(sub) => out.push(Substitution(sub))
          _ => ()
        }
      }
    BlockString(_) => ()
    Substitution(s) =>
      for p in s.path {
        out.push(StringValue(p))
      }
    Import(i) =>
      for p in i.path {
        out.push(StringValue(p))
      }
  }
  out
}

///|
pub fn Value::range(self : Value) -> @lexer.Range {
  match self {
    Scalar(s) => s.range()
    Array(a) => a.range
    Map(m) => m.range
    Import(i) => i.range
    BlockScalar(v, m) => @lexer.Range::between(v.range(), m.range)
  }
}

///|
pub fn Scalar::range(self : Scalar) -> @lexer.Range {
  match self {
    Null(r) => r
    Boolean(r, _) => r
    Number(r, _) => r
    String(s) => s.range()
  }
}

///|
pub fn StringValue::range(self : StringValue) -> @lexer.Range {
  match self {
    Unquoted(s) => s.range
    SingleQuoted(r, _) => r
    DoubleQuoted(s) => s.range
    Block(s) => s.range
  }
}

///|
pub fn StringValue::content(self : StringValue) -> String {
  match self {
    Unquoted(s) => s.to_string()
    SingleQuoted(_, v) => v
    DoubleQuoted(s) => s.to_string()
    Block(s) => s.value
  }
}

///|
pub fn UnquotedString::to_string(self : UnquotedString) -> String {
  let buf = StringBuilder::new()
  for seg in self.value {
    match seg {
      Text(s) => buf.write_string(s)
      Sub(sub) => {
        // Preserve substitution syntax for later resolution
        buf.write_string("${")
        for i, part in sub.path {
          if i > 0 {
            buf.write_char('.')
          }
          buf.write_string(part.content())
        }
        buf.write_string("}")
      }
    }
  }
  buf.to_string()
}

///|
pub fn DoubleQuotedString::to_string(self : DoubleQuotedString) -> String {
  let buf = StringBuilder::new()
  for seg in self.value {
    match seg {
      Text(s) => buf.write_string(s)
      Sub(sub) => {
        // Preserve substitution syntax for later resolution
        buf.write_string("${")
        for i, part in sub.path {
          if i > 0 {
            buf.write_char('.')
          }
          buf.write_string(part.content())
        }
        buf.write_string("}")
      }
    }
  }
  buf.to_string()
}

///|
pub fn KeyPath::has_glob(self : KeyPath) -> Bool {
  for s in self.path {
    match s {
      Unquoted(us) => if us.pattern.length() > 0 { return true }
      _ => ()
    }
  }
  false
}

///|
pub fn KeyPath::to_strings(self : KeyPath) -> Array[String] {
  self.path.map(fn(s) { s.content() })
}

///|
pub fn KeyPath::last(self : KeyPath) -> StringValue? {
  if self.path.length() > 0 {
    Some(self.path[self.path.length() - 1])
  } else {
    None
  }
}
