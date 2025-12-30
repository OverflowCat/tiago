///|
/// Pure SVG Builder Library
///
/// Build SVG documents programmatically without dependencies.

///|
/// SVG document builder
pub struct Svg {
  width : Double
  height : Double
  elements : Array[String]
  defs : Array[String]
}

///|
/// Create a new SVG document
pub fn Svg::new(width : Double, height : Double) -> Svg {
  { width, height, elements: [], defs: [] }
}

///|
/// Add an element to the SVG
pub fn Svg::add(self : Svg, element : String) -> Unit {
  self.elements.push(element)
}

///|
/// Add a definition (marker, gradient, etc.)
pub fn Svg::add_def(self : Svg, def : String) -> Unit {
  self.defs.push(def)
}

///|
/// Open a group with transform
pub fn Svg::open_group(self : Svg, transform : String) -> Unit {
  if transform == "" {
    self.elements.push("<g>")
  } else {
    self.elements.push("<g transform=\"\{transform}\">")
  }
}

///|
/// Close a group
pub fn Svg::close_group(self : Svg) -> Unit {
  self.elements.push("</g>")
}

///|
/// Render to string
pub fn Svg::to_string(self : Svg) -> String {
  let sb = StringBuilder::new()
  sb.write_string("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_string("<svg xmlns=\"http://www.w3.org/2000/svg\" ")
  sb.write_string("width=\"\{self.width}\" height=\"\{self.height}\" ")
  sb.write_string("viewBox=\"0 0 \{self.width} \{self.height}\">\n")
  // Defs
  if self.defs.length() > 0 {
    sb.write_string("<defs>\n")
    for def in self.defs {
      sb.write_string(def)
      sb.write_char('\n')
    }
    sb.write_string("</defs>\n")
  }
  // Elements
  for elem in self.elements {
    sb.write_string(elem)
    sb.write_char('\n')
  }
  sb.write_string("</svg>")
  sb.to_string()
}

///|
pub impl Show for Svg with output(self, logger) {
  logger.write_string(self.to_string())
}

// =============================================================================
// Shape builders
// =============================================================================

///|
/// Build a rectangle element
pub fn rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  fill? : String = "none",
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
  rx? : Double = 0.0,
  ry? : Double = 0.0,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{width}\" height=\"\{height}\"",
  )
  if rx > 0.0 {
    sb.write_string(" rx=\"\{rx}\"")
  }
  if ry > 0.0 {
    sb.write_string(" ry=\"\{ry}\"")
  }
  sb.write_string(
    " fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\"/>",
  )
  sb.to_string()
}

///|
/// Build an ellipse element
pub fn ellipse(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  fill? : String = "none",
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
) -> String {
  "<ellipse cx=\"\{cx}\" cy=\"\{cy}\" rx=\"\{rx}\" ry=\"\{ry}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\"/>"
}

///|
/// Build a circle element
pub fn circle(
  cx : Double,
  cy : Double,
  r : Double,
  fill? : String = "none",
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
) -> String {
  "<circle cx=\"\{cx}\" cy=\"\{cy}\" r=\"\{r}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\"/>"
}

///|
/// Build a line element
pub fn line(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
) -> String {
  "<line x1=\"\{x1}\" y1=\"\{y1}\" x2=\"\{x2}\" y2=\"\{y2}\" stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\"/>"
}

///|
/// Build a polyline element
pub fn polyline(
  points : Array[(Double, Double)],
  fill? : String = "none",
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string("<polyline points=\"")
  for i, pt in points {
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string("\{pt.0},\{pt.1}")
  }
  sb.write_string(
    "\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\"/>",
  )
  sb.to_string()
}

///|
/// Build a polygon element
pub fn polygon(
  points : Array[(Double, Double)],
  fill? : String = "none",
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string("<polygon points=\"")
  for i, pt in points {
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string("\{pt.0},\{pt.1}")
  }
  sb.write_string(
    "\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\"/>",
  )
  sb.to_string()
}

///|
/// Build a path element
pub fn path(
  d : String,
  fill? : String = "none",
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
  marker_start? : String = "",
  marker_end? : String = "",
) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "<path d=\"\{d}\" fill=\"\{fill}\" stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\"",
  )
  if marker_start != "" {
    sb.write_string(" marker-start=\"\{marker_start}\"")
  }
  if marker_end != "" {
    sb.write_string(" marker-end=\"\{marker_end}\"")
  }
  sb.write_string("/>")
  sb.to_string()
}

///|
/// Build a text element
pub fn text(
  x : Double,
  y : Double,
  content : String,
  font_family? : String = "Arial, sans-serif",
  font_size? : Int = 14,
  text_anchor? : String = "middle",
  dominant_baseline? : String = "middle",
) -> String {
  let escaped = escape_xml(content)
  "<text x=\"\{x}\" y=\"\{y}\" text-anchor=\"\{text_anchor}\" dominant-baseline=\"\{dominant_baseline}\" font-family=\"\{font_family}\" font-size=\"\{font_size}\">\{escaped}</text>"
}

///|
/// Build an arrow marker definition
pub fn arrow_marker(
  id : String,
  size : Double,
  fill : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  if reverse {
    "<marker id=\"\{id}\" markerWidth=\"\{size}\" markerHeight=\"\{size}\" refX=\"0\" refY=\"\{half}\" orient=\"auto\" markerUnits=\"strokeWidth\"><path d=\"M\{size},0 L0,\{half} L\{size},\{size} Z\" fill=\"\{fill}\"/></marker>"
  } else {
    "<marker id=\"\{id}\" markerWidth=\"\{size}\" markerHeight=\"\{size}\" refX=\"\{size}\" refY=\"\{half}\" orient=\"auto\" markerUnits=\"strokeWidth\"><path d=\"M0,0 L\{size},\{half} L0,\{size} Z\" fill=\"\{fill}\"/></marker>"
  }
}

///|
/// Build a background rectangle
pub fn background(color : String) -> String {
  "<rect width=\"100%\" height=\"100%\" fill=\"\{color}\"/>"
}

// =============================================================================
// Path builder helpers
// =============================================================================

///|
/// Path builder for complex paths
pub struct PathBuilder {
  commands : Array[String]
}

///|
pub fn PathBuilder::new() -> PathBuilder {
  { commands: [] }
}

///|
/// Move to position
pub fn PathBuilder::move_to(
  self : PathBuilder,
  x : Double,
  y : Double,
) -> PathBuilder {
  self.commands.push("M \{x} \{y}")
  self
}

///|
/// Line to position
pub fn PathBuilder::line_to(
  self : PathBuilder,
  x : Double,
  y : Double,
) -> PathBuilder {
  self.commands.push("L \{x} \{y}")
  self
}

///|
/// Arc to position
pub fn PathBuilder::arc_to(
  self : PathBuilder,
  rx : Double,
  ry : Double,
  x : Double,
  y : Double,
  large_arc? : Bool = false,
  sweep? : Bool = true,
) -> PathBuilder {
  let large = if large_arc { 1 } else { 0 }
  let sw = if sweep { 1 } else { 0 }
  self.commands.push("A \{rx} \{ry} 0 \{large} \{sw} \{x} \{y}")
  self
}

///|
/// Cubic bezier curve (absolute)
pub fn PathBuilder::cubic_to(
  self : PathBuilder,
  cx1 : Double,
  cy1 : Double,
  cx2 : Double,
  cy2 : Double,
  x : Double,
  y : Double,
) -> PathBuilder {
  self.commands.push("C \{cx1} \{cy1} \{cx2} \{cy2} \{x} \{y}")
  self
}

///|
/// Quadratic bezier curve (absolute)
pub fn PathBuilder::quad_to(
  self : PathBuilder,
  cx : Double,
  cy : Double,
  x : Double,
  y : Double,
) -> PathBuilder {
  self.commands.push("Q \{cx} \{cy} \{x} \{y}")
  self
}

///|
/// Horizontal line to (absolute)
pub fn PathBuilder::h_to(self : PathBuilder, x : Double) -> PathBuilder {
  self.commands.push("H \{x}")
  self
}

///|
/// Vertical line to (absolute)
pub fn PathBuilder::v_to(self : PathBuilder, y : Double) -> PathBuilder {
  self.commands.push("V \{y}")
  self
}

///|
/// Close path
pub fn PathBuilder::close(self : PathBuilder) -> PathBuilder {
  self.commands.push("Z")
  self
}

///|
/// Build the path string
pub fn PathBuilder::build(self : PathBuilder) -> String {
  self.commands.join(" ")
}

// =============================================================================
// Utilities
// =============================================================================

///|
/// Escape special XML characters
pub fn escape_xml(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    match c {
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '&' => sb.write_string("&amp;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&#39;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}
