///|
/// Arrowhead types for D2 diagram edges
///
/// This enum represents all supported arrowhead types in D2 diagrams.
/// Each arrowhead has its own marker rendering for SVG output.

///|
/// All supported arrowhead types
pub enum ArrowheadType {
  /// No arrowhead
  None
  /// Default filled triangle arrow
  Triangle
  /// Filled diamond shape
  Diamond
  /// Filled circle
  Circle
  /// Open (unfilled) triangle arrow
  Open
  /// Simple line terminator
  Line
  /// Crow's foot: exactly one (vertical line)
  CfOne
  /// Crow's foot: zero or more (crow's foot)
  CfMany
  /// Crow's foot: exactly one, required (line with perpendicular)
  CfOneRequired
  /// Crow's foot: one or more, required (crow's foot with line)
  CfManyRequired
  /// Crow's foot: zero or one, optional (line with circle)
  CfOneOptional
  /// Crow's foot: zero or more, optional (crow's foot with circle)
  CfManyOptional
} derive(Eq, Show)

///|
/// Parse an arrowhead type from a string
pub fn ArrowheadType::from_string(s : String) -> ArrowheadType {
  match s.to_lower() {
    "none" | "" => None
    "triangle" | "arrow" => Triangle
    "diamond" => Diamond
    "circle" => Circle
    "open" => Open
    "line" => Line
    "cf-one" | "cfone" => CfOne
    "cf-many" | "cfmany" => CfMany
    "cf-one-required" | "cfonerequired" => CfOneRequired
    "cf-many-required" | "cfmanyrequired" => CfManyRequired
    "cf-one-optional" | "cfoneoptional" => CfOneOptional
    "cf-many-optional" | "cfmanyoptional" => CfManyOptional
    _ => Triangle // Default to triangle for unknown types
  }
}

///|
/// Convert arrowhead type to canonical string representation
pub fn ArrowheadType::to_arrowhead_string(self : ArrowheadType) -> String {
  match self {
    None => "none"
    Triangle => "triangle"
    Diamond => "diamond"
    Circle => "circle"
    Open => "open"
    Line => "line"
    CfOne => "cf-one"
    CfMany => "cf-many"
    CfOneRequired => "cf-one-required"
    CfManyRequired => "cf-many-required"
    CfOneOptional => "cf-one-optional"
    CfManyOptional => "cf-many-optional"
  }
}

///|
/// Get the SVG marker ID for this arrowhead type
pub fn ArrowheadType::marker_id(self : ArrowheadType, reverse : Bool) -> String {
  let base = match self {
    None => return "" // No marker needed
    Triangle => "arrow-triangle"
    Diamond => "arrow-diamond"
    Circle => "arrow-circle"
    Open => "arrow-open"
    Line => "arrow-line"
    CfOne => "arrow-cf-one"
    CfMany => "arrow-cf-many"
    CfOneRequired => "arrow-cf-one-required"
    CfManyRequired => "arrow-cf-many-required"
    CfOneOptional => "arrow-cf-one-optional"
    CfManyOptional => "arrow-cf-many-optional"
  }
  if reverse {
    base + "-reverse"
  } else {
    base
  }
}

///|
/// Get the marker URL for SVG use
pub fn ArrowheadType::marker_url(
  self : ArrowheadType,
  reverse : Bool,
) -> String {
  let id = self.marker_id(reverse)
  if id.is_empty() {
    ""
  } else {
    "url(#" + id + ")"
  }
}

///|
/// Check if this is a crow's foot notation type
pub fn ArrowheadType::is_crows_foot(self : ArrowheadType) -> Bool {
  match self {
    CfOne
    | CfMany
    | CfOneRequired
    | CfManyRequired
    | CfOneOptional
    | CfManyOptional => true
    _ => false
  }
}

///|
/// Get ASCII representation of this arrowhead
pub fn ArrowheadType::to_ascii(self : ArrowheadType, reverse : Bool) -> String {
  match self {
    None => if reverse { "-" } else { "-" }
    Triangle => if reverse { "<" } else { ">" }
    Diamond => if reverse { "<>" } else { "<>" }
    Circle => if reverse { "o" } else { "o" }
    Open => if reverse { "<" } else { ">" }
    Line => if reverse { "|" } else { "|" }
    CfOne => if reverse { "|" } else { "|" }
    CfMany => if reverse { "<" } else { ">" }
    CfOneRequired => if reverse { "||" } else { "||" }
    CfManyRequired => if reverse { "<|" } else { "|>" }
    CfOneOptional => if reverse { "o|" } else { "|o" }
    CfManyOptional => if reverse { "o<" } else { ">o" }
  }
}
