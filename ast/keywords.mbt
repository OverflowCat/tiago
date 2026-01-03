///|
/// Reserved keywords in D2

///|
/// Simple reserved keywords (non-style, non-composite)
pub let simple_reserved_keywords : Array[String] = [
  "label", "shape", "icon", "constraint", "tooltip", "link", "near", "width", "height",
  "direction", "top", "left", "grid-rows", "grid-columns", "grid-gap", "vertical-gap",
  "horizontal-gap", "class", "vars",
]

///|
/// Style keywords (must be inside "style" block)
pub let style_keywords : Array[String] = [
  "opacity", "stroke", "fill", "fill-pattern", "stroke-width", "stroke-dash", "border-radius",
  "font", "font-size", "font-color", "bold", "italic", "underline", "text-transform",
  "shadow", "multiple", "double-border", "3d", "animated", "filled", "sketch", "curved",
]

///|
/// Keywords that hold composites
pub let composite_keywords : Array[String] = [
  "style", "source-arrowhead", "target-arrowhead", "classes", "constraint", "label",
  "icon", "tooltip", "layers", "scenarios", "steps",
]

///|
/// Board keywords (create new boards)
pub let board_keywords : Array[String] = ["layers", "scenarios", "steps"]

///|
/// Check if a string is a reserved keyword
pub fn is_reserved_keyword(s : String) -> Bool {
  simple_reserved_keywords.contains(s) ||
  style_keywords.contains(s) ||
  composite_keywords.contains(s)
}

///|
/// Check if a string is a style keyword
pub fn is_style_keyword(s : String) -> Bool {
  style_keywords.contains(s)
}

///|
/// Check if a string is a board keyword
pub fn is_board_keyword(s : String) -> Bool {
  board_keywords.contains(s)
}

///|
/// Valid fill patterns
pub let fill_patterns : Array[String] = [
  "none", "dots", "lines", "grain", "paper",
]

///|
/// Valid text transforms
pub let text_transforms : Array[String] = [
  "none", "uppercase", "lowercase", "capitalize",
]

///|
/// Near constant positions
pub let near_constants : Array[String] = [
  "top-left", "top-center", "top-right", "center-left", "center-right", "bottom-left",
  "bottom-center", "bottom-right",
]

///|
/// Label positions
pub let label_positions : Array[String] = [
  "top-left", "top-center", "top-right", "center-left", "center-center", "center-right",
  "bottom-left", "bottom-center", "bottom-right", "outside-top-left", "outside-top-center",
  "outside-top-right", "outside-left-top", "outside-left-center", "outside-left-bottom",
  "outside-right-top", "outside-right-center", "outside-right-bottom", "outside-bottom-left",
  "outside-bottom-center", "outside-bottom-right",
]
