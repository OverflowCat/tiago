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
  @xml_emit.Element::new("rect")
  .attr_num("x", x)
  .attr_num("y", y)
  .attr_num("width", width)
  .attr_num("height", height)
  .attr_num_if("rx", rx, rx > 0.0)
  .attr_num_if("ry", ry, ry > 0.0)
  .attr("fill", fill)
  .attr("stroke", stroke)
  .attr_num("stroke-width", stroke_width)
  .self_close()
  .build()
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
  @xml_emit.Element::new("ellipse")
  .attr_num("cx", cx)
  .attr_num("cy", cy)
  .attr_num("rx", rx)
  .attr_num("ry", ry)
  .attr("fill", fill)
  .attr("stroke", stroke)
  .attr_num("stroke-width", stroke_width)
  .self_close()
  .build()
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
  @xml_emit.Element::new("circle")
  .attr_num("cx", cx)
  .attr_num("cy", cy)
  .attr_num("r", r)
  .attr("fill", fill)
  .attr("stroke", stroke)
  .attr_num("stroke-width", stroke_width)
  .self_close()
  .build()
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
  @xml_emit.Element::new("line")
  .attr_num("x1", x1)
  .attr_num("y1", y1)
  .attr_num("x2", x2)
  .attr_num("y2", y2)
  .attr("stroke", stroke)
  .attr_num("stroke-width", stroke_width)
  .self_close()
  .build()
}

///|
/// Build a polyline element
pub fn polyline(
  points : Array[(Double, Double)],
  fill? : String = "none",
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
) -> String {
  let points_str = points_to_string(points)
  @xml_emit.Element::new("polyline")
  .attr("points", points_str)
  .attr("fill", fill)
  .attr("stroke", stroke)
  .attr_num("stroke-width", stroke_width)
  .self_close()
  .build()
}

///|
/// Build a polygon element
pub fn polygon(
  points : Array[(Double, Double)],
  fill? : String = "none",
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
) -> String {
  let points_str = points_to_string(points)
  @xml_emit.Element::new("polygon")
  .attr("points", points_str)
  .attr("fill", fill)
  .attr("stroke", stroke)
  .attr_num("stroke-width", stroke_width)
  .self_close()
  .build()
}

///|
/// Convert array of points to SVG points string
fn points_to_string(points : Array[(Double, Double)]) -> String {
  let sb = StringBuilder::new()
  for i, pt in points {
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string("\{pt.0},\{pt.1}")
  }
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
  @xml_emit.Element::new("path")
  .attr("d", d)
  .attr("fill", fill)
  .attr("stroke", stroke)
  .attr_num("stroke-width", stroke_width)
  .attr_if("marker-start", marker_start)
  .attr_if("marker-end", marker_end)
  .self_close()
  .build()
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
  @xml_emit.Element::new("text")
  .attr_num("x", x)
  .attr_num("y", y)
  .attr("text-anchor", text_anchor)
  .attr("dominant-baseline", dominant_baseline)
  .attr("font-family", font_family)
  .attr_int("font-size", font_size)
  .text(content)
  .build()
}

///|
/// Build a styled text element with support for text-transform and extra styles
pub fn styled_text(
  x : Double,
  y : Double,
  content : String,
  font_family? : String = "Arial, sans-serif",
  font_size? : Int = 14,
  text_anchor? : String = "middle",
  dominant_baseline? : String = "middle",
  text_transform? : String = "",
  extra_style? : String = "",
) -> String {
  // Build style attribute
  let style_parts : Array[String] = []
  if text_transform != "" {
    style_parts.push("text-transform: \{text_transform}")
  }
  if extra_style != "" {
    style_parts.push(extra_style)
  }
  let style_value = style_parts.join("; ")
  @xml_emit.Element::new("text")
  .attr_num("x", x)
  .attr_num("y", y)
  .attr("text-anchor", text_anchor)
  .attr("dominant-baseline", dominant_baseline)
  .attr("font-family", font_family)
  .attr_int("font-size", font_size)
  .attr_if("style", style_value)
  .text(content)
  .build()
}

///|
/// Build an arrow marker definition (triangle)
pub fn arrow_marker(
  id : String,
  size : Double,
  fill : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let (refX, d) = if reverse {
    (0.0, "M\{size},0 L0,\{half} L\{size},\{size} Z")
  } else {
    (size, "M0,0 L\{size},\{half} L0,\{size} Z")
  }
  let path_elem = @xml_emit.Element::new("path")
    .attr("d", d)
    .attr("fill", fill)
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(path_elem)
  .build()
}

///|
/// Build a diamond marker definition
pub fn diamond_marker(
  id : String,
  size : Double,
  fill : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let refX = if reverse { 0.0 } else { size }
  let d = "M0,\{half} L\{half},0 L\{size},\{half} L\{half},\{size} Z"
  let path_elem = @xml_emit.Element::new("path")
    .attr("d", d)
    .attr("fill", fill)
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(path_elem)
  .build()
}

///|
/// Build a circle marker definition
pub fn circle_marker(
  id : String,
  size : Double,
  fill : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let r = half * 0.8
  let refX = if reverse { r } else { size - r }
  let circle_elem = @xml_emit.Element::new("circle")
    .attr_num("cx", half)
    .attr_num("cy", half)
    .attr_num("r", r)
    .attr("fill", fill)
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(circle_elem)
  .build()
}

///|
/// Build a crow's foot "one" marker (single line)
pub fn cf_one_marker(
  id : String,
  size : Double,
  stroke : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let refX = if reverse { 0.0 } else { size }
  let x = if reverse { 0.0 } else { size }
  let line_elem = @xml_emit.Element::new("line")
    .attr_num("x1", x)
    .attr_num("y1", 0.0)
    .attr_num("x2", x)
    .attr_num("y2", size)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(line_elem)
  .build()
}

///|
/// Build a crow's foot "many" marker (three lines spreading out)
pub fn cf_many_marker(
  id : String,
  size : Double,
  stroke : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let (refX, d) = if reverse {
    (
      0.0,
      "M\{size},\{half} L0,0 M\{size},\{half} L0,\{half} M\{size},\{half} L0,\{size}",
    )
  } else {
    (
      size,
      "M0,\{half} L\{size},0 M0,\{half} L\{size},\{half} M0,\{half} L\{size},\{size}",
    )
  }
  let path_elem = @xml_emit.Element::new("path")
    .attr("d", d)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .attr("fill", "none")
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(path_elem)
  .build()
}

///|
/// Build a crow's foot "one-required" marker (line with bar)
pub fn cf_one_required_marker(
  id : String,
  size : Double,
  stroke : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let bar_x = if reverse { size * 0.3 } else { size * 0.7 }
  let line_x = if reverse { 0.0 } else { size }
  let refX = if reverse { 0.0 } else { size }
  let line1 = @xml_emit.Element::new("line")
    .attr_num("x1", line_x)
    .attr_num("y1", 0.0)
    .attr_num("x2", line_x)
    .attr_num("y2", size)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .self_close()
    .build()
  let line2 = @xml_emit.Element::new("line")
    .attr_num("x1", bar_x)
    .attr_num("y1", 0.0)
    .attr_num("x2", bar_x)
    .attr_num("y2", size)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(line1 + line2)
  .build()
}

///|
/// Build a crow's foot "many-required" marker (three lines with bar)
pub fn cf_many_required_marker(
  id : String,
  size : Double,
  stroke : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let bar_x = if reverse { size * 0.7 } else { size * 0.3 }
  let (refX, d) = if reverse {
    (
      0.0,
      "M\{size},\{half} L0,0 M\{size},\{half} L0,\{half} M\{size},\{half} L0,\{size}",
    )
  } else {
    (
      size,
      "M0,\{half} L\{size},0 M0,\{half} L\{size},\{half} M0,\{half} L\{size},\{size}",
    )
  }
  let path_elem = @xml_emit.Element::new("path")
    .attr("d", d)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .attr("fill", "none")
    .self_close()
    .build()
  let line_elem = @xml_emit.Element::new("line")
    .attr_num("x1", bar_x)
    .attr_num("y1", 0.0)
    .attr_num("x2", bar_x)
    .attr_num("y2", size)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(path_elem + line_elem)
  .build()
}

///|
/// Build a crow's foot "one-optional" marker (line with circle)
pub fn cf_one_optional_marker(
  id : String,
  size : Double,
  stroke : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let r = size * 0.2
  let circle_x = if reverse { size * 0.3 } else { size * 0.7 }
  let line_x = if reverse { 0.0 } else { size }
  let refX = if reverse { 0.0 } else { size }
  let line_elem = @xml_emit.Element::new("line")
    .attr_num("x1", line_x)
    .attr_num("y1", 0.0)
    .attr_num("x2", line_x)
    .attr_num("y2", size)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .self_close()
    .build()
  let circle_elem = @xml_emit.Element::new("circle")
    .attr_num("cx", circle_x)
    .attr_num("cy", half)
    .attr_num("r", r)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .attr("fill", "white")
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(line_elem + circle_elem)
  .build()
}

///|
/// Build a crow's foot "many-optional" marker (three lines with circle)
pub fn cf_many_optional_marker(
  id : String,
  size : Double,
  stroke : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let r = size * 0.2
  let circle_x = if reverse { size * 0.7 } else { size * 0.3 }
  let (refX, d) = if reverse {
    (
      0.0,
      "M\{size},\{half} L0,0 M\{size},\{half} L0,\{half} M\{size},\{half} L0,\{size}",
    )
  } else {
    (
      size,
      "M0,\{half} L\{size},0 M0,\{half} L\{size},\{half} M0,\{half} L\{size},\{size}",
    )
  }
  let path_elem = @xml_emit.Element::new("path")
    .attr("d", d)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .attr("fill", "none")
    .self_close()
    .build()
  let circle_elem = @xml_emit.Element::new("circle")
    .attr_num("cx", circle_x)
    .attr_num("cy", half)
    .attr_num("r", r)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .attr("fill", "white")
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(path_elem + circle_elem)
  .build()
}

///|
/// Build a line terminator marker (simple perpendicular line)
pub fn line_marker(
  id : String,
  size : Double,
  stroke : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let x = if reverse { 0.0 } else { size }
  let refX = if reverse { 0.0 } else { size }
  let line_elem = @xml_emit.Element::new("line")
    .attr_num("x1", x)
    .attr_num("y1", 0.0)
    .attr_num("x2", x)
    .attr_num("y2", size)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(line_elem)
  .build()
}

///|
/// Build an open triangle marker (unfilled)
pub fn open_marker(
  id : String,
  size : Double,
  stroke : String,
  reverse? : Bool = false,
) -> String {
  let half = size / 2.0
  let (refX, d) = if reverse {
    (0.0, "M\{size},0 L0,\{half} L\{size},\{size}")
  } else {
    (size, "M0,0 L\{size},\{half} L0,\{size}")
  }
  let path_elem = @xml_emit.Element::new("path")
    .attr("d", d)
    .attr("stroke", stroke)
    .attr_int("stroke-width", 2)
    .attr("fill", "none")
    .self_close()
    .build()
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", size)
  .attr_num("markerHeight", size)
  .attr_num("refX", refX)
  .attr_num("refY", half)
  .attr("orient", "auto")
  .attr("markerUnits", "strokeWidth")
  .raw(path_elem)
  .build()
}

///|
/// Build a background rectangle
pub fn background(color : String) -> String {
  @xml_emit.Element::new("rect")
  .attr("width", "100%")
  .attr("height", "100%")
  .attr("fill", color)
  .self_close()
  .build()
}

// =============================================================================
// Fill patterns
// =============================================================================

///|
/// Build a dots pattern definition
pub fn dots_pattern(id : String, color : String, bg_color : String) -> String {
  let size = 8.0
  let r = 1.5
  let rect_elem = @xml_emit.Element::new("rect")
    .attr_num("width", size)
    .attr_num("height", size)
    .attr("fill", bg_color)
    .self_close()
    .build()
  let circle_elem = @xml_emit.Element::new("circle")
    .attr_num("cx", size / 2.0)
    .attr_num("cy", size / 2.0)
    .attr_num("r", r)
    .attr("fill", color)
    .self_close()
    .build()
  @xml_emit.Element::new("pattern")
  .attr("id", id)
  .attr("patternUnits", "userSpaceOnUse")
  .attr_num("width", size)
  .attr_num("height", size)
  .raw(rect_elem + circle_elem)
  .build()
}

///|
/// Build a lines pattern definition (horizontal lines)
pub fn lines_pattern(id : String, color : String, bg_color : String) -> String {
  let size = 8.0
  let rect_elem = @xml_emit.Element::new("rect")
    .attr_num("width", size)
    .attr_num("height", size)
    .attr("fill", bg_color)
    .self_close()
    .build()
  let line_elem = @xml_emit.Element::new("line")
    .attr_num("x1", 0.0)
    .attr_num("y1", size / 2.0)
    .attr_num("x2", size)
    .attr_num("y2", size / 2.0)
    .attr("stroke", color)
    .attr_int("stroke-width", 1)
    .self_close()
    .build()
  @xml_emit.Element::new("pattern")
  .attr("id", id)
  .attr("patternUnits", "userSpaceOnUse")
  .attr_num("width", size)
  .attr_num("height", size)
  .raw(rect_elem + line_elem)
  .build()
}

///|
/// Build a cross-hatch pattern definition
pub fn crosshatch_pattern(
  id : String,
  color : String,
  bg_color : String,
) -> String {
  let size = 8.0
  let rect_elem = @xml_emit.Element::new("rect")
    .attr_num("width", size)
    .attr_num("height", size)
    .attr("fill", bg_color)
    .self_close()
    .build()
  let d = "M0,0 L\{size},\{size} M\{size},0 L0,\{size}"
  let path_elem = @xml_emit.Element::new("path")
    .attr("d", d)
    .attr("stroke", color)
    .attr_int("stroke-width", 1)
    .self_close()
    .build()
  @xml_emit.Element::new("pattern")
  .attr("id", id)
  .attr("patternUnits", "userSpaceOnUse")
  .attr_num("width", size)
  .attr_num("height", size)
  .raw(rect_elem + path_elem)
  .build()
}

///|
/// Build a grain/paper texture pattern definition
pub fn grain_pattern(id : String, color : String, bg_color : String) -> String {
  let size = 4.0
  let rect_elem = @xml_emit.Element::new("rect")
    .attr_num("width", size)
    .attr_num("height", size)
    .attr("fill", bg_color)
    .self_close()
    .build()
  let circle1 = @xml_emit.Element::new("circle")
    .attr_num("cx", 1.0)
    .attr_num("cy", 1.0)
    .attr_num("r", 0.5)
    .attr("fill", color)
    .attr("opacity", "0.3")
    .self_close()
    .build()
  let circle2 = @xml_emit.Element::new("circle")
    .attr_num("cx", 3.0)
    .attr_num("cy", 3.0)
    .attr_num("r", 0.5)
    .attr("fill", color)
    .attr("opacity", "0.3")
    .self_close()
    .build()
  @xml_emit.Element::new("pattern")
  .attr("id", id)
  .attr("patternUnits", "userSpaceOnUse")
  .attr_num("width", size)
  .attr_num("height", size)
  .raw(rect_elem + circle1 + circle2)
  .build()
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
/// Delegates to @xml_emit.escape for the actual implementation
pub fn escape_xml(s : String) -> String {
  @xml_emit.escape(s)
}
