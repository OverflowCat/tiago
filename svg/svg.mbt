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
/// Pure SVG Builder Library
///
/// Build SVG documents programmatically without dependencies.

///|
/// SVG document builder
pub struct Svg {
  width : Double
  height : Double
  mut viewbox_x : Double
  mut viewbox_y : Double
  mut viewbox_width : Double
  mut viewbox_height : Double
  mut include_xml_declaration : Bool
  elements : Array[String]
  defs : Array[String]
  scripts : Array[String]
  root_attrs : Array[(String, String)]
}

///|
/// Create a new SVG document
pub fn Svg::new(width : Double, height : Double) -> Svg {
  {
    width,
    height,
    viewbox_x: 0.0,
    viewbox_y: 0.0,
    viewbox_width: width,
    viewbox_height: height,
    include_xml_declaration: true,
    elements: [],
    defs: [],
    scripts: [],
    root_attrs: [],
  }
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
/// Set the viewBox bounds.
pub fn Svg::set_viewbox(
  self : Svg,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  self.viewbox_x = x
  self.viewbox_y = y
  self.viewbox_width = width
  self.viewbox_height = height
}

///|
/// Open a group with optional transform
pub fn Svg::open_group(self : Svg, transform : String) -> Unit {
  self.elements.push(
    @xml_emit.Element::new("g").attr_if("transform", transform).open_tag(),
  )
}

///|
/// Open a group with filter
pub fn Svg::open_group_with_filter(self : Svg, filter_id : String) -> Unit {
  let filter_url = "url(#\{filter_id})"
  self.elements.push(
    @xml_emit.Element::new("g").attr("filter", filter_url).open_tag(),
  )
}

///|
/// Open a group with tooltip (adds title element)
pub fn Svg::open_group_with_tooltip(self : Svg, tooltip : String) -> Unit {
  self.elements.push(@xml_emit.Element::new("g").open_tag())
  self.elements.push(@xml_emit.Element::new("title").text(tooltip).build())
}

///|
/// Open a group with id and transform
pub fn Svg::open_group_with_id(
  self : Svg,
  id : String,
  transform : String,
) -> Unit {
  self.elements.push(
    @xml_emit.Element::new("g")
    .attr("id", id)
    .attr_if("transform", transform)
    .open_tag(),
  )
}

///|
/// Open a group with id, transform, and style
pub fn Svg::open_group_with_id_style(
  self : Svg,
  id : String,
  transform : String,
  style : String,
) -> Unit {
  self.elements.push(
    @xml_emit.Element::new("g")
    .attr("id", id)
    .attr_if("transform", transform)
    .attr("style", style)
    .open_tag(),
  )
}

///|
/// Close a group
pub fn Svg::close_group(self : Svg) -> Unit {
  self.elements.push(@xml_emit.Element::new("g").close_tag())
}

///|
/// Add a script element
pub fn Svg::add_script(self : Svg, script : String) -> Unit {
  self.scripts.push(script)
}

///|
/// Enable or disable XML declaration output.
pub fn Svg::set_include_xml_declaration(self : Svg, enabled : Bool) -> Unit {
  self.include_xml_declaration = enabled
}

///|
/// Add an attribute to the root `<svg>` element.
pub fn Svg::add_root_attr(self : Svg, name : String, value : String) -> Unit {
  self.root_attrs.push((name, value))
}

///|
pub fn Svg::width(self : Svg) -> Double {
  self.width
}

///|
pub fn Svg::height(self : Svg) -> Double {
  self.height
}

///|
pub fn Svg::viewbox_x(self : Svg) -> Double {
  self.viewbox_x
}

///|
pub fn Svg::viewbox_y(self : Svg) -> Double {
  self.viewbox_y
}

///|
pub fn Svg::viewbox_width(self : Svg) -> Double {
  self.viewbox_width
}

///|
pub fn Svg::viewbox_height(self : Svg) -> Double {
  self.viewbox_height
}

///|
pub fn Svg::include_xml_declaration(self : Svg) -> Bool {
  self.include_xml_declaration
}

///|
pub fn Svg::elements(self : Svg) -> Array[String] {
  self.elements
}

///|
pub fn Svg::defs(self : Svg) -> Array[String] {
  self.defs
}

///|
pub fn Svg::scripts(self : Svg) -> Array[String] {
  self.scripts
}

///|
pub fn Svg::root_attrs(self : Svg) -> Array[(String, String)] {
  self.root_attrs
}

///|
/// Render to string
pub fn Svg::to_string(self : Svg) -> String {
  let view_box = "\{self.viewbox_x} \{self.viewbox_y} \{self.viewbox_width} \{self.viewbox_height}"
  let mut root = @xml_emit.Element::new("svg")
    .attr("xmlns", "http://www.w3.org/2000/svg")
    .attr_num("width", self.width)
    .attr_num("height", self.height)
    .attr("viewBox", view_box)
  let blocks : Array[String] = []
  for attr in self.root_attrs {
    root = root.attr(attr.0, attr.1)
  }
  if self.defs.length() > 0 {
    let mut defs = @xml_emit.Element::new("defs")
    for i, def in self.defs {
      if i > 0 {
        defs = defs.child("\n")
      }
      defs = defs.child(def)
    }
    defs = defs.child("\n")
    blocks.push(defs.build())
  }
  for elem in self.elements {
    blocks.push(elem)
  }
  if self.scripts.length() > 0 {
    let script_body = self.scripts.join("\n") + "\n"
    blocks.push(
      @xml_emit.Element::new("script")
      .attr("type", "text/javascript")
      .cdata(script_body)
      .build(),
    )
  }
  for block in blocks {
    root = root.child("\n").child(block)
  }
  if blocks.length() > 0 {
    root = root.child("\n")
  }
  let root = root.build()
  if self.include_xml_declaration {
    let doc = @xml_emit.Document::new()
    doc.add(root)
    doc.build()
  } else {
    root + "\n"
  }
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
  rx? : Double? = None,
  ry? : Double? = None,
  id? : String? = None,
  class? : String? = None,
  onclick? : String? = None,
) -> String {
  let elem = @xml_emit.Element::new("rect")
    .attr_num("x", x)
    .attr_num("y", y)
    .attr_num("width", width)
    .attr_num("height", height)
    .attr("fill", fill)
    .attr("stroke", stroke)
    .attr("stroke-width", d2_stroke_width_value(stroke_width))
  let elem = match rx {
    Some(v) => elem.attr_num("rx", v)
    None => elem
  }
  let elem = match ry {
    Some(v) => elem.attr_num("ry", v)
    None => elem
  }
  let elem = match id {
    Some(v) => elem.attr("id", v)
    None => elem
  }
  let elem = match class {
    Some(v) => elem.attr("class", v)
    None => elem
  }
  let elem = match onclick {
    Some(v) => elem.attr("onclick", v)
    None => elem
  }
  elem.self_close().build()
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
  .attr("stroke-width", d2_stroke_width_value(stroke_width))
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
  .attr("stroke-width", d2_stroke_width_value(stroke_width))
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
  .attr("stroke-width", d2_stroke_width_value(stroke_width))
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
  .attr("stroke-width", d2_stroke_width_value(stroke_width))
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
  .attr("stroke-width", d2_stroke_width_value(stroke_width))
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
fn stroke_dash_attributes(
  stroke_width : Double,
  dash_gap_size : Double,
) -> (Double, Double) {
  // Ported from ../d2/lib/svg/path.go GetStrokeDashAttributes.
  let scale = @math.log10(-0.6 * stroke_width + 10.6) * 0.5 + 0.5
  let scaled_dash_size = stroke_width * dash_gap_size
  let scaled_gap_size = scale * scaled_dash_size
  (scaled_dash_size, scaled_gap_size)
}

///|
fn fixed6(value : Double) -> String {
  let sign = if value < 0.0 { "-" } else { "" }
  let abs_value = if value < 0.0 { -value } else { value }
  let mut int_part = @math.floor(abs_value).to_int()
  let mut frac_part = ((abs_value - int_part.to_double()) * 1000000.0)
    .round()
    .to_int()
  if frac_part >= 1000000 {
    int_part = int_part + 1
    frac_part = frac_part - 1000000
  }
  let frac_raw = frac_part.to_string()
  let pad = 6 - frac_raw.length()
  let frac = StringBuilder::new()
  if pad > 0 {
    for _ in 0..<pad {
      frac.write_char('0')
    }
  }
  frac.write_string(frac_raw)
  "\{sign}\{int_part}.\{frac.to_string()}"
}

///|
fn path_number(value : Double) -> String {
  fixed6(value)
}

///|
fn d2_stroke_width_value(value : Double) -> String {
  if value.round() == value {
    value.to_int().to_string()
  } else {
    fixed6(value)
  }
}

///|
/// Build a path element
pub fn path(
  d : String,
  fill? : String = "none",
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
  stroke_dash? : Double = 0.0,
  marker_start? : String = "",
  marker_end? : String = "",
  mask? : String = "",
) -> String {
  let elem = @xml_emit.Element::new("path")
    .attr("d", d)
    .attr("fill", fill)
    .attr("stroke", stroke)
    .attr("stroke-width", d2_stroke_width_value(stroke_width))
    .attr_if("marker-start", marker_start)
    .attr_if("marker-end", marker_end)
    .attr_if("mask", mask)
  // Add stroke-dasharray if dash value is set
  if stroke_dash > 0.0 {
    let (dash_size, gap_size) = stroke_dash_attributes(
      stroke_width, stroke_dash,
    )
    elem
    .attr("stroke-dasharray", "\{fixed6(dash_size)},\{fixed6(gap_size)}")
    .self_close()
    .build()
  } else {
    elem.self_close().build()
  }
}

///|
/// Build an animated path element with marching ants effect
pub fn animated_path(
  d : String,
  fill? : String = "none",
  stroke? : String = "black",
  stroke_width? : Double = 1.0,
  marker_start? : String = "",
  marker_end? : String = "",
  mask? : String = "",
) -> String {
  // Create path with animation
  let path_elem = @xml_emit.Element::new("path")
    .attr("d", d)
    .attr("fill", fill)
    .attr("stroke", stroke)
    .attr("stroke-width", d2_stroke_width_value(stroke_width))
    .attr("stroke-dasharray", "5,5")
    .attr_if("marker-start", marker_start)
    .attr_if("marker-end", marker_end)
    .attr_if("mask", mask)
  // Add animate element for marching ants effect
  let animate = @xml_emit.Element::new("animate")
    .attr("attributeName", "stroke-dashoffset")
    .attr("from", "10")
    .attr("to", "0")
    .attr("dur", "0.5s")
    .attr("repeatCount", "indefinite")
    .self_close()
    .build()
  path_elem.child(animate).build()
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
  .child(path_elem)
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
  .child(path_elem)
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
  .child(circle_elem)
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
  .child(line_elem)
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
  .child(path_elem)
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
  .children([line1, line2])
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
  .children([path_elem, line_elem])
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
  .children([line_elem, circle_elem])
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
  .children([path_elem, circle_elem])
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
  .child(line_elem)
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
  .child(path_elem)
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
  let _ = bg_color
  let size = 15.0
  let points = [
    (2.0, 2.0),
    (12.0, 2.0),
    (12.0, 12.0),
    (2.0, 12.0),
    (2.0, 7.0),
    (12.0, 7.0),
    (7.0, 2.0),
    (7.0, 12.0),
    (7.0, 7.0),
  ]
  let children : Array[String] = []
  for point in points {
    let rect = @xml_emit.Element::new("rect")
      .attr_num("x", point.0)
      .attr_num("y", point.1)
      .attr_num("width", 1.0)
      .attr_num("height", 1.0)
      .attr("fill", color)
      .self_close()
      .build()
    let group = @xml_emit.Element::new("g")
      .attr("style", "mix-blend-mode:multiply")
      .attr("opacity", "0.1")
      .child(rect)
      .build()
    children.push(group)
  }
  @xml_emit.Element::new("pattern")
  .attr("id", id)
  .attr_int("x", 0)
  .attr_int("y", 0)
  .attr("patternUnits", "userSpaceOnUse")
  .attr_num("width", size)
  .attr_num("height", size)
  .children(children)
  .build()
}

///|
/// Build a lines pattern definition (horizontal lines)
pub fn lines_pattern(id : String, color : String, bg_color : String) -> String {
  let _ = bg_color
  let size = 15.0
  let rows = [2.0, 7.0, 12.0]
  let line_groups : Array[String] = []
  for y in rows {
    let rect = @xml_emit.Element::new("rect")
      .attr_num("y", y)
      .attr_num("width", size)
      .attr_num("height", 1.0)
      .attr("fill", color)
      .self_close()
      .build()
    line_groups.push(
      @xml_emit.Element::new("g")
      .attr("style", "mix-blend-mode:multiply")
      .attr("opacity", "0.05")
      .child(rect)
      .build(),
    )
  }
  let lines = @xml_emit.Element::new("g")
    .attr("style", "mix-blend-mode:multiply")
    .children(line_groups)
    .build()
  @xml_emit.Element::new("pattern")
  .attr("id", id)
  .attr_int("x", 0)
  .attr_int("y", 0)
  .attr("patternUnits", "userSpaceOnUse")
  .attr_num("width", size)
  .attr_num("height", size)
  .child(lines)
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
  .children([rect_elem, path_elem])
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
  .children([rect_elem, circle1, circle2])
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
  self.commands.push("M \{path_number(x)} \{path_number(y)}")
  self
}

///|
/// Line to position
pub fn PathBuilder::line_to(
  self : PathBuilder,
  x : Double,
  y : Double,
) -> PathBuilder {
  self.commands.push("L \{path_number(x)} \{path_number(y)}")
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
  self.commands.push(
    "A \{path_number(rx)} \{path_number(ry)} 0 \{large} \{sw} \{path_number(x)} \{path_number(y)}",
  )
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
  self.commands.push(
    "C \{path_number(cx1)} \{path_number(cy1)} \{path_number(cx2)} \{path_number(cy2)} \{path_number(x)} \{path_number(y)}",
  )
  self
}

///|
/// Smooth cubic bezier curve (absolute)
pub fn PathBuilder::smooth_cubic_to(
  self : PathBuilder,
  cx2 : Double,
  cy2 : Double,
  x : Double,
  y : Double,
) -> PathBuilder {
  self.commands.push(
    "S \{path_number(cx2)} \{path_number(cy2)} \{path_number(x)} \{path_number(y)}",
  )
  self
}

///|
/// Cubic bezier curve (relative)
pub fn PathBuilder::cubic_rel(
  self : PathBuilder,
  dx1 : Double,
  dy1 : Double,
  dx2 : Double,
  dy2 : Double,
  dx : Double,
  dy : Double,
) -> PathBuilder {
  self.commands.push(
    "c \{path_number(dx1)} \{path_number(dy1)} \{path_number(dx2)} \{path_number(dy2)} \{path_number(dx)} \{path_number(dy)}",
  )
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
  self.commands.push(
    "Q \{path_number(cx)} \{path_number(cy)} \{path_number(x)} \{path_number(y)}",
  )
  self
}

///|
/// Horizontal line to (absolute)
pub fn PathBuilder::h_to(self : PathBuilder, x : Double) -> PathBuilder {
  self.commands.push("H \{path_number(x)}")
  self
}

///|
/// Vertical line to (absolute)
pub fn PathBuilder::v_to(self : PathBuilder, y : Double) -> PathBuilder {
  self.commands.push("V \{path_number(y)}")
  self
}

///|
/// Vertical line (relative)
pub fn PathBuilder::v_rel(self : PathBuilder, dy : Double) -> PathBuilder {
  self.commands.push("v \{path_number(dy)}")
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
// Filters
// =============================================================================

///|
/// Build a sketch filter definition for hand-drawn appearance
pub fn sketch_filter(id : String) -> String {
  // Create turbulence effect for randomness
  let turbulence = @xml_emit.Element::new("feTurbulence")
    .attr("type", "turbulence")
    .attr("baseFrequency", "0.02")
    .attr("numOctaves", "3")
    .attr("seed", "1")
    .attr("result", "noise")
    .self_close()
    .build()
  // Create displacement map to distort paths
  let displacement = @xml_emit.Element::new("feDisplacementMap")
    .attr("in", "SourceGraphic")
    .attr("in2", "noise")
    .attr("scale", "2")
    .attr("xChannelSelector", "R")
    .attr("yChannelSelector", "G")
    .self_close()
    .build()
  @xml_emit.Element::new("filter")
  .attr("id", id)
  .attr("x", "-5%")
  .attr("y", "-5%")
  .attr("width", "110%")
  .attr("height", "110%")
  .children([turbulence, displacement])
  .build()
}

///|
/// Build a drop-shadow filter used by D2's `shadow: true` style.
pub fn shadow_filter(id : String) -> String {
  let blur = @xml_emit.Element::new("feGaussianBlur")
    .attr("stdDeviation", "1.7 ")
    .attr("in", "SourceGraphic")
    .build()
  let flood = @xml_emit.Element::new("feFlood")
    .attr("flood-color", "#3d4574")
    .attr("flood-opacity", "0.4")
    .attr("result", "ShadowFeFlood")
    .attr("in", "SourceGraphic")
    .build()
  let composite = @xml_emit.Element::new("feComposite")
    .attr("in", "ShadowFeFlood")
    .attr("in2", "SourceAlpha")
    .attr("operator", "in")
    .attr("result", "ShadowFeComposite")
    .build()
  let offset = @xml_emit.Element::new("feOffset")
    .attr("dx", "3")
    .attr("dy", "5")
    .attr("result", "ShadowFeOffset")
    .attr("in", "ShadowFeComposite")
    .build()
  let blend = @xml_emit.Element::new("feBlend")
    .attr("in", "SourceGraphic")
    .attr("in2", "ShadowFeOffset")
    .attr("mode", "normal")
    .attr("result", "ShadowFeBlend")
    .build()
  @xml_emit.Element::new("filter")
  .attr("id", id)
  .attr("width", "200%")
  .attr("height", "200%")
  .attr("x", "-50%")
  .attr("y", "-50%")
  .children([blur, flood, composite, offset, blend])
  .build()
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
