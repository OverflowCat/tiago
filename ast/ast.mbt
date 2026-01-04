///|
/// AST nodes for the D2 diagram language
///
/// The AST closely follows the D2 language structure:
/// - Map is the root node and represents nested containers
/// - Key represents key-value pairs and edge declarations
/// - Edge represents connections between nodes

///|
/// A D2 file is represented as a Map at the root level
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
pub fn Value::range(self : Value) -> @lexer.Range {
  match self {
    Scalar(s) => s.range()
    Array(a) => a.range
    Map(m) => m.range
    Import(i) => i.range
    BlockScalar(v, m) => @lexer.Range::new(v.range().start, m.range.end)
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
