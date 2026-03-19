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
/// SVG Renderer for Diagram
///
/// Renders a laid-out Diagram to SVG using the pure svg library.

///|
/// Render pass for two-layer rendering
/// Background: shapes, fills, borders (rendered first, behind edges)
/// Foreground: text, labels, content (rendered last, on top of edges)
pub enum RenderPass {
  Background
  Foreground
}

///|
/// SVG rendering configuration
pub struct SvgConfig {
  /// Padding around the entire diagram
  padding : Double
  /// Center the outer SVG viewbox like D2's render option.
  center : Bool
  /// Apply global sketch rendering mode.
  sketch : Bool
  /// Default font family
  font_family : String
  /// Default font size
  font_size : Int
  /// Background color
  background : String
  /// Default stroke color
  default_stroke : String
  /// Default fill color
  default_fill : String
  /// Default stroke width
  default_stroke_width : Double
  /// Arrow size
  arrow_size : Double
  /// Theme ID (0 = default)
  theme_id : Int
  /// Optional dark theme ID.
  dark_theme_id : Int?
  /// Light theme color overrides.
  theme_overrides : @diagram.ThemeOverrides?
  /// Dark theme color overrides.
  dark_theme_overrides : @diagram.ThemeOverrides?
  /// Optional output scale factor.
  scale : Double?
  /// Omit XML declaration when true.
  no_xml_tag : Bool
  /// Optional salt for namespacing SVG definition IDs.
  salt : String?
  /// Omit version metadata on root element.
  omit_version : Bool
} derive(Show)

///|
pub fn SvgConfig::new() -> SvgConfig {
  let theme = @themes.get_theme(0)
  {
    padding: 100.0,
    center: false,
    sketch: false,
    font_family: "Arial, sans-serif",
    font_size: 16,
    background: theme.background_color(),
    default_stroke: theme.stroke_color(),
    default_fill: theme.fill_color(),
    default_stroke_width: 2.0,
    arrow_size: 10.0,
    theme_id: 0,
    dark_theme_id: None,
    theme_overrides: None,
    dark_theme_overrides: None,
    scale: None,
    no_xml_tag: false,
    salt: None,
    omit_version: false,
  }
}

///|
/// Create config with a specific theme
pub fn SvgConfig::with_theme(theme_id : Int) -> SvgConfig {
  let theme = @themes.get_theme(theme_id)
  let font = if theme.rules.mono { "monospace" } else { "Arial, sans-serif" }
  {
    padding: 100.0,
    center: false,
    sketch: false,
    font_family: font,
    font_size: 16,
    background: theme.background_color(),
    default_stroke: theme.stroke_color(),
    default_fill: theme.fill_color(),
    default_stroke_width: 2.0,
    arrow_size: 10.0,
    theme_id,
    dark_theme_id: None,
    theme_overrides: None,
    dark_theme_overrides: None,
    scale: None,
    no_xml_tag: false,
    salt: None,
    omit_version: false,
  }
}

///|
pub fn SvgConfig::with_padding(self : SvgConfig, padding : Double) -> SvgConfig {
  { ..self, padding, }
}

///|
/// Create config with theme by name
pub fn SvgConfig::with_theme_name(name : String) -> SvgConfig {
  let theme = @themes.get_theme_by_name(name)
  SvgConfig::with_theme(theme.get_id())
}

///|
/// Apply render-time options on top of a base theme config.
pub fn SvgConfig::with_render_options(
  self : SvgConfig,
  dark_theme_id : Int?,
  theme_overrides : @diagram.ThemeOverrides?,
  dark_theme_overrides : @diagram.ThemeOverrides?,
  center : Bool,
  sketch : Bool,
  scale : Double?,
  no_xml_tag : Bool,
  salt : String?,
  omit_version : Bool,
) -> SvgConfig {
  let active_light_theme = @themes.get_theme(self.theme_id).with_overrides(
    theme_overrides,
  )
  let font_family = if active_light_theme.rules.mono {
    "monospace"
  } else {
    "Arial, sans-serif"
  }
  {
    ..self,
    center,
    sketch,
    font_family,
    background: active_light_theme.background_color(),
    default_stroke: active_light_theme.stroke_color(),
    default_fill: active_light_theme.fill_color(),
    dark_theme_id,
    theme_overrides,
    dark_theme_overrides,
    scale,
    no_xml_tag,
    salt,
    omit_version,
  }
}

///|
/// List all available theme names
pub fn list_themes() -> Array[String] {
  @themes.list_themes()
}

///|
fn style_string(value : @graph.StyleValue?, default : String) -> String {
  match value {
    Some(v) => v.get_value()
    None => default
  }
}

///|
fn style_string_opt(value : @graph.StyleValue?) -> String? {
  match value {
    Some(v) => Some(v.get_value())
    None => None
  }
}

///|
fn style_double(value : @graph.StyleValue?, default : Double) -> Double {
  match value {
    Some(v) => v.as_double().unwrap_or(default)
    None => default
  }
}

///|
fn style_int(value : @graph.StyleValue?, default : Int) -> Int {
  match value {
    Some(v) => v.as_int().unwrap_or(default)
    None => default
  }
}

///|
fn style_bool(value : @graph.StyleValue?, default : Bool) -> Bool {
  match value {
    Some(v) => v.as_bool().unwrap_or(default)
    None => default
  }
}

///|
fn sketch_enabled(style_value : @graph.StyleValue?, config : SvgConfig) -> Bool {
  style_bool(style_value, config.sketch)
}

///|
fn style_is_mono(value : @graph.StyleValue?) -> Bool {
  match value {
    Some(v) =>
      match v.get_value().to_lower() {
        "mono" | "monospace" | "code" => true
        _ => false
      }
    None => false
  }
}

///|
fn container_label_size(level : Int) -> Int {
  if level <= 1 {
    28
  } else if level == 2 {
    24
  } else if level == 3 {
    20
  } else {
    16
  }
}

///|
fn default_object_font_size(obj : Shape, config : SvgConfig) -> Int {
  if obj.shape_type == Class || obj.shape_type == SqlTable {
    20
  } else if is_container(obj) && obj.shape_type != Text {
    container_label_size(get_object_depth(obj.id))
  } else {
    config.font_size
  }
}

///|
fn default_object_bold(obj : Shape) -> Bool {
  !is_container(obj) &&
  obj.shape_type != Text &&
  obj.shape_type != Class &&
  obj.shape_type != SqlTable
}

///|
fn has_outside_bottom_label(obj : Shape) -> Bool {
  obj.shape_type == Image || obj.shape_type == Person
}

///|
fn label_outside_anchor_box(obj : Shape, box : Box) -> Box {
  let x = box.x
  let mut y = box.y
  let mut width = box.width
  let mut height = box.height
  if style_bool(obj.style.three_d, false) {
    let offset_y = if obj.shape_type == Hexagon {
      THREE_DEE_OFFSET / 2.0
    } else {
      THREE_DEE_OFFSET
    }
    y = y - offset_y
    height = height + offset_y
    width = width + THREE_DEE_OFFSET
  } else if style_bool(obj.style.multiple, false) {
    y = y - MULTIPLE_OFFSET
    height = height + MULTIPLE_OFFSET
    width = width + MULTIPLE_OFFSET
  }
  Box::new(x, y, width, height)
}

///|
fn d2_label_position_is_outside(position : String) -> Bool {
  position.has_prefix("OUTSIDE_")
}

///|
fn d2_label_position_is_border(position : String) -> Bool {
  position.has_prefix("BORDER_")
}

///|
fn d2_box_for_label_position(
  obj : Shape,
  box : Box,
  position : String,
  label_width : Double,
  label_height : Double,
) -> Box {
  if d2_label_position_is_outside(position) ||
    d2_label_position_is_border(position) {
    label_outside_anchor_box(obj, box)
  } else {
    shape_inner_box_for_label(obj, box, label_width, label_height)
  }
}

///|
fn shape_inner_box_for_label(
  obj : Shape,
  box : Box,
  label_width : Double,
  label_height : Double,
) -> Box {
  let mut x = box.x
  let mut y = box.y
  let mut width = box.width
  let mut height = box.height
  match obj.shape_type {
    Hexagon => {
      x = x + width / 6.0
      y = y + height / 6.0
      width = width / 1.5
      height = height / 1.5
    }
    Cloud => {
      let aspect = if label_height > 0.0 {
        label_width / label_height
      } else {
        1.0
      }
      let wide_boundary = (1.0 + 0.819 / 0.548) / 2.0
      let tall_boundary = (1.0 + 0.549 / 0.820) / 2.0
      if aspect > wide_boundary {
        x = x + (width * 0.085).ceil()
        y = y + (height * 0.409).ceil()
        width = width * 0.819
        height = height * 0.548
      } else if aspect < tall_boundary {
        x = x + (width * 0.228).ceil()
        y = y + (height * 0.179).ceil()
        width = width * 0.549
        height = height * 0.820
      } else {
        x = x + (width * 0.167).ceil()
        y = y + (height * 0.335).ceil()
        width = width * 0.663
        height = height * 0.663
      }
    }
    Cylinder => {
      let mut arc = 24.0
      if height < arc * 2.0 {
        arc = height / 2.0
      }
      y = y + 2.0 * arc
      height = height - 3.0 * arc
    }
    Queue => {
      let mut arc = 24.0
      if width < arc * 2.0 {
        arc = width / 2.0
      }
      x = x + arc
      width = width - 3.0 * arc
    }
    StoredData => {
      x = x + 15.0
      width = width - 30.0
    }
    Document => height = height * 14.0 / 18.925
    Package => {
      let top_h = if 55.0 < height * 0.2 { 55.0 } else { height * 0.2 }
      y = y + top_h
      height = height - top_h
    }
    Callout => {
      let tip_h = if height < 90.0 { height / 2.0 } else { 45.0 }
      height = height - tip_h
    }
    Person => {
      let shoulder = 20.2 / 68.3 * width
      x = x + shoulder
      width = width - shoulder * 2.0
    }
    C4Person => {
      let head_radius = width * 0.22
      let body_top = head_radius + head_radius * 0.8
      let h_padding = width * 0.05
      let v_padding = height * 0.03
      x = x + h_padding
      y = y + body_top + v_padding
      width = width - h_padding * 2.0
      height = height - body_top - v_padding * 2.0
    }
    _ => ()
  }
  if width <= 0.0 || height <= 0.0 {
    box
  } else {
    Box::new(x, y, width, height)
  }
}

///|
fn shape_inner_box_for_icon(obj : Shape, box : Box) -> Box {
  let mut x = box.x
  let mut y = box.y
  let mut width = box.width
  let mut height = box.height
  match obj.shape_type {
    Hexagon => {
      x = x + width / 6.0
      y = y + height / 6.0
      width = width / 1.5
      height = height / 1.5
    }
    Cloud => {
      x = x + (width * 0.167).ceil()
      y = y + (height * 0.335).ceil()
      width = width * 0.663
      height = height * 0.663
    }
    Cylinder => {
      let mut arc = 24.0
      if height < arc * 2.0 {
        arc = height / 2.0
      }
      y = y + 2.0 * arc
      height = height - 3.0 * arc
    }
    Queue => {
      let mut arc = 24.0
      if width < arc * 2.0 {
        arc = width / 2.0
      }
      x = x + arc
      width = width - 3.0 * arc
    }
    StoredData => {
      x = x + 15.0
      width = width - 30.0
    }
    Document => height = height * 14.0 / 18.925
    Package => {
      let top_h = if 55.0 < height * 0.2 { 55.0 } else { height * 0.2 }
      y = y + top_h
      height = height - top_h
    }
    Callout => {
      let tip_h = if height < 90.0 { height / 2.0 } else { 45.0 }
      height = height - tip_h
    }
    Person => {
      let shoulder = 20.2 / 68.3 * width
      x = x + shoulder
      width = width - shoulder * 2.0
    }
    C4Person => {
      let head_radius = width * 0.22
      let body_top = head_radius + head_radius * 0.8
      let h_padding = width * 0.05
      let v_padding = height * 0.03
      x = x + h_padding
      y = y + body_top + v_padding
      width = width - h_padding * 2.0
      height = height - body_top - v_padding * 2.0
    }
    _ => ()
  }
  if width <= 0.0 || height <= 0.0 {
    box
  } else {
    Box::new(x, y, width, height)
  }
}

///|
fn object_precomputed_label_dims(obj : Shape) -> (Double, Double)? {
  match (obj.label_width, obj.label_height) {
    (Some(width), Some(height)) =>
      if width > 0.0 && height > 0.0 {
        Some((width, height))
      } else {
        None
      }
    _ => None
  }
}

///|
fn object_label_dims(
  obj : Shape,
  text : String,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> (Double, Double) {
  match object_precomputed_label_dims(obj) {
    Some(dims) => dims
    None => {
      let dims = @text_metrics.measure_label(
        text, font_size, is_mono, is_bold, is_italic,
      )
      (dims.width, dims.height)
    }
  }
}

///|
fn plain_object_label_layout(
  obj : Shape,
  box : Box,
  label_width : Double,
  label_height : Double,
) -> (Double, Double, Double) {
  match obj.label_position {
    Some(position) => {
      let label_box = d2_box_for_label_position(
        obj, box, position, label_width, label_height,
      )
      let label_tl = d2_point_on_box(
        position,
        label_box,
        LABEL_PADDING,
        label_width,
        label_height,
      )
      return (label_tl.x, label_tl.y, label_width)
    }
    None => ()
  }
  let inner_box = shape_inner_box_for_label(obj, box, label_width, label_height)
  let label_overflows = label_width > box.width || label_height > box.height
  let is_grid_container = is_container(obj) &&
    (obj.grid_rows is Some(_) || obj.grid_columns is Some(_))
  match obj.label_box {
    Some(label_box) =>
      (
        label_box.x,
        label_box.y,
        if label_box.width > 0.0 {
          label_box.width
        } else {
          label_width
        },
      )
    None =>
      if is_container(obj) && !is_grid_container {
        let anchor_box = label_outside_anchor_box(obj, box)
        (
          anchor_box.x + (anchor_box.width - label_width) / 2.0,
          anchor_box.y - LABEL_PADDING - label_height,
          label_width,
        )
      } else if is_grid_container {
        (
          inner_box.x + (inner_box.width - label_width) / 2.0,
          inner_box.y + LABEL_PADDING,
          label_width,
        )
      } else if has_outside_bottom_label(obj) || label_overflows {
        let anchor_box = label_outside_anchor_box(obj, box)
        (
          anchor_box.x + (anchor_box.width - label_width) / 2.0,
          anchor_box.y + anchor_box.height + LABEL_PADDING,
          label_width,
        )
      } else if obj.icon is Some(_) && obj.shape_type != Image {
        (
          inner_box.x + (inner_box.width - label_width) / 2.0,
          inner_box.y + LABEL_PADDING,
          label_width,
        )
      } else {
        (
          inner_box.x + (inner_box.width - label_width) / 2.0,
          inner_box.y + (inner_box.height - label_height) / 2.0,
          label_width,
        )
      }
  }
}

///|
fn markdown_label_layout(obj : Shape, box : Box) -> (Double, Double, Int, Int) {
  let width_px = match object_precomputed_label_dims(obj) {
    Some((width, _)) => width.ceil().to_int()
    None => ceil_double(box.width).to_int()
  }
  let height_px = match object_precomputed_label_dims(obj) {
    Some((_, height)) => height.ceil().to_int()
    None => ceil_double(box.height).to_int()
  }
  match obj.label_position {
    Some(position) => {
      let label_box = d2_box_for_label_position(
        obj,
        box,
        position,
        width_px.to_double(),
        height_px.to_double(),
      )
      let label_tl = d2_point_on_box(
        position,
        label_box,
        LABEL_PADDING,
        width_px.to_double(),
        height_px.to_double(),
      )
      return (label_tl.x, label_tl.y, width_px, height_px)
    }
    None => ()
  }
  let (x, y) = match obj.label_box {
    Some(label_box) => (label_box.x, label_box.y)
    None => (box.x, box.y)
  }
  (x, y, width_px, height_px)
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn d2_icon_position_is_outside(position : String) -> Bool {
  position.has_prefix("OUTSIDE_")
}

///|
fn d2_get_icon_size(box : Box, position : String) -> Int {
  let min_dimension = min_int(box.width.to_int(), box.height.to_int())
  let half_min_dimension = (min_dimension + 1) / 2
  let mut size = if position == D2_DEFAULT_ICON_POSITION {
    half_min_dimension
  } else {
    min_int(min_dimension, max_int(D2_DEFAULT_ICON_SIZE, half_min_dimension))
  }
  size = min_int(size, D2_MAX_ICON_SIZE)
  if !d2_icon_position_is_outside(position) {
    let padding = LABEL_PADDING.to_int()
    let max_width = max_int(box.width.to_int() - padding * 2, 0)
    let max_height = max_int(box.height.to_int() - padding * 2, 0)
    size = min_int(size, min_int(max_width, max_height))
  }
  size
}

///|
fn d2_point_on_box(
  position : String,
  box : Box,
  padding : Double,
  width : Double,
  height : Double,
) -> @graph.Point {
  let box_center = box.center()
  let mut x = box.x
  let mut y = box.y
  match position {
    "OUTSIDE_TOP_LEFT" => {
      x = x + padding
      y = y - padding - height
    }
    "OUTSIDE_TOP_CENTER" => {
      x = box_center.x - width / 2.0
      y = y - padding - height
    }
    "OUTSIDE_TOP_RIGHT" => {
      x = x + box.width - width - padding
      y = y - padding - height
    }
    "OUTSIDE_LEFT_TOP" => {
      x = x - padding - width
      y = y + padding
    }
    "OUTSIDE_LEFT_MIDDLE" => {
      x = x - padding - width
      y = box_center.y - height / 2.0
    }
    "OUTSIDE_LEFT_BOTTOM" => {
      x = x - padding - width
      y = y + box.height - height - padding
    }
    "OUTSIDE_RIGHT_TOP" => {
      x = x + box.width + padding
      y = y + padding
    }
    "OUTSIDE_RIGHT_MIDDLE" => {
      x = x + box.width + padding
      y = box_center.y - height / 2.0
    }
    "OUTSIDE_RIGHT_BOTTOM" => {
      x = x + box.width + padding
      y = y + box.height - height - padding
    }
    "OUTSIDE_BOTTOM_LEFT" => {
      x = x + padding
      y = y + box.height + padding
    }
    "OUTSIDE_BOTTOM_CENTER" => {
      x = box_center.x - width / 2.0
      y = y + box.height + padding
    }
    "OUTSIDE_BOTTOM_RIGHT" => {
      x = x + box.width - width - padding
      y = y + box.height + padding
    }
    "INSIDE_TOP_LEFT" => {
      x = x + padding
      y = y + padding
    }
    "INSIDE_TOP_CENTER" => {
      x = box_center.x - width / 2.0
      y = y + padding
    }
    "INSIDE_TOP_RIGHT" => {
      x = x + box.width - width - padding
      y = y + padding
    }
    "INSIDE_MIDDLE_LEFT" => {
      x = x + padding
      y = box_center.y - height / 2.0
    }
    "INSIDE_MIDDLE_CENTER" => {
      x = box_center.x - width / 2.0
      y = box_center.y - height / 2.0
    }
    "INSIDE_MIDDLE_RIGHT" => {
      x = x + box.width - width - padding
      y = box_center.y - height / 2.0
    }
    "INSIDE_BOTTOM_LEFT" => {
      x = x + padding
      y = y + box.height - height - padding
    }
    "INSIDE_BOTTOM_CENTER" => {
      x = box_center.x - width / 2.0
      y = y + box.height - height - padding
    }
    "INSIDE_BOTTOM_RIGHT" => {
      x = x + box.width - width - padding
      y = y + box.height - height - padding
    }
    "BORDER_TOP_LEFT" => {
      x = x + padding
      y = y - height / 2.0
    }
    "BORDER_TOP_CENTER" => {
      x = box_center.x - width / 2.0
      y = y - height / 2.0
    }
    "BORDER_TOP_RIGHT" => {
      x = x + box.width - width - padding
      y = y - height / 2.0
    }
    "BORDER_LEFT_TOP" => {
      x = x - width / 2.0
      y = y + padding
    }
    "BORDER_LEFT_MIDDLE" => {
      x = x - width / 2.0
      y = box_center.y - height / 2.0
    }
    "BORDER_LEFT_BOTTOM" => {
      x = x - width / 2.0
      y = y + box.height - height - padding
    }
    "BORDER_RIGHT_TOP" => {
      x = x + box.width - width / 2.0
      y = y + padding
    }
    "BORDER_RIGHT_MIDDLE" => {
      x = x + box.width - width / 2.0
      y = box_center.y - height / 2.0
    }
    "BORDER_RIGHT_BOTTOM" => {
      x = x + box.width - width / 2.0
      y = y + box.height - height - padding
    }
    "BORDER_BOTTOM_LEFT" => {
      x = x + padding
      y = y + box.height - height / 2.0
    }
    "BORDER_BOTTOM_CENTER" => {
      x = box_center.x - width / 2.0
      y = y + box.height - height / 2.0
    }
    "BORDER_BOTTOM_RIGHT" => {
      x = x + box.width - width - padding
      y = y + box.height - height / 2.0
    }
    _ => ()
  }
  @graph.Point::new(x, y)
}

///|
fn theme_token(value : String) -> String? {
  match value.to_upper() {
    "N1"
    | "N2"
    | "N3"
    | "N4"
    | "N5"
    | "N6"
    | "N7"
    | "B1"
    | "B2"
    | "B3"
    | "B4"
    | "B5"
    | "B6"
    | "AA2"
    | "AA4"
    | "AA5"
    | "AB4"
    | "AB5" => Some(value.to_upper())
    _ => None
  }
}

///|
fn theme_css_var(token : String) -> String {
  "var(--d2-\{token})"
}

///|
fn resolve_theme_color(
  value : String,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> String {
  match theme_token(value) {
    Some(token) =>
      if use_css_theme_vars {
        theme_css_var(token)
      } else {
        theme.resolve(token)
      }
    None => value
  }
}

///|
fn style_color(
  value : @graph.StyleValue?,
  default : String,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> String {
  let raw = style_string(value, default)
  resolve_theme_color(raw, theme, use_css_theme_vars)
}

///|
fn hex_digit_value(c : Char) -> Int? {
  let code = c.to_int()
  if code >= '0'.to_int() && code <= '9'.to_int() {
    Some(code - '0'.to_int())
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    Some(10 + code - 'a'.to_int())
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    Some(10 + code - 'A'.to_int())
  } else {
    None
  }
}

///|
fn parse_hex_byte(high : Char, low : Char) -> Int? {
  match hex_digit_value(high) {
    Some(hi) =>
      match hex_digit_value(low) {
        Some(lo) => Some(hi * 16 + lo)
        None => None
      }
    None => None
  }
}

///|
fn char_at(s : String, index : Int) -> Char? {
  if index < 0 || index >= s.length() {
    return None
  }
  s[index].to_char()
}

///|
fn starts_with_hash(s : String) -> Bool {
  match char_at(s, 0) {
    Some('#') => true
    _ => false
  }
}

///|
fn parse_hex_pair_at(s : String, index : Int) -> Int? {
  match char_at(s, index) {
    Some(high) =>
      match char_at(s, index + 1) {
        Some(low) => parse_hex_byte(high, low)
        None => None
      }
    None => None
  }
}

///|
fn parse_hex_nibble_at(s : String, index : Int) -> Int? {
  match char_at(s, index) {
    Some(c) => hex_digit_value(c)
    None => None
  }
}

///|
fn parse_hex_color(color : String) -> (Int, Int, Int)? {
  if color.length() == 7 && starts_with_hash(color) {
    match parse_hex_pair_at(color, 1) {
      Some(r) =>
        match parse_hex_pair_at(color, 3) {
          Some(g) =>
            match parse_hex_pair_at(color, 5) {
              Some(b) => Some((r, g, b))
              None => None
            }
          None => None
        }
      None => None
    }
  } else if color.length() == 4 && starts_with_hash(color) {
    match parse_hex_nibble_at(color, 1) {
      Some(r0) =>
        match parse_hex_nibble_at(color, 2) {
          Some(g0) =>
            match parse_hex_nibble_at(color, 3) {
              Some(b0) => Some((r0 * 17, g0 * 17, b0 * 17))
              None => None
            }
          None => None
        }
      None => None
    }
  } else {
    None
  }
}

///|
fn hex_digit_char(v : Int) -> Char {
  match v {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    15 => 'f'
    _ => '0'
  }
}

///|
fn hex_byte_string(v : Int) -> String {
  let clamped = if v < 0 { 0 } else if v > 255 { 255 } else { v }
  let hi = clamped / 16
  let lo = clamped % 16
  let sb = StringBuilder::new()
  sb.write_char(hex_digit_char(hi))
  sb.write_char(hex_digit_char(lo))
  sb.to_string()
}

///|
fn hue_to_rgb(p : Double, q : Double, t0 : Double) -> Double {
  let mut t = t0
  if t < 0.0 {
    t = t + 1.0
  }
  if t > 1.0 {
    t = t - 1.0
  }
  if t < 1.0 / 6.0 {
    p + (q - p) * 6.0 * t
  } else if t < 1.0 / 2.0 {
    q
  } else if t < 2.0 / 3.0 {
    p + (q - p) * (2.0 / 3.0 - t) * 6.0
  } else {
    p
  }
}

///|
fn darken_theme_color_token(token : String) -> String? {
  match token {
    "B1" | "B2" => Some("B1")
    "B3" => Some("B2")
    "B4" => Some("B3")
    "B5" => Some("B4")
    "B6" => Some("B5")
    "AA2" | "AA4" => Some("AA2")
    "AA5" => Some("AA4")
    "AB4" => Some("AB4")
    "AB5" => Some("AB5")
    "N1" | "N2" => Some("N1")
    "N3" => Some("N2")
    "N4" => Some("N3")
    "N5" => Some("N4")
    "N6" => Some("N5")
    "N7" => Some("N6")
    _ => None
  }
}

///|
fn css_named_color_rgb(color : String) -> (Int, Int, Int)? {
  match color {
    "aliceblue" => Some((240, 248, 255))
    "antiquewhite" => Some((250, 235, 215))
    "aqua" => Some((0, 255, 255))
    "aquamarine" => Some((127, 255, 212))
    "azure" => Some((240, 255, 255))
    "beige" => Some((245, 245, 220))
    "bisque" => Some((255, 228, 196))
    "black" => Some((0, 0, 0))
    "blanchedalmond" => Some((255, 235, 205))
    "blue" => Some((0, 0, 255))
    "blueviolet" => Some((138, 43, 226))
    "brown" => Some((165, 42, 42))
    "burlywood" => Some((222, 184, 135))
    "cadetblue" => Some((95, 158, 160))
    "chartreuse" => Some((127, 255, 0))
    "chocolate" => Some((210, 105, 30))
    "coral" => Some((255, 127, 80))
    "cornflowerblue" => Some((100, 149, 237))
    "cornsilk" => Some((255, 248, 220))
    "crimson" => Some((220, 20, 60))
    "cyan" => Some((0, 255, 255))
    "darkblue" => Some((0, 0, 139))
    "darkcyan" => Some((0, 139, 139))
    "darkgoldenrod" => Some((184, 134, 11))
    "darkgray" => Some((169, 169, 169))
    "darkgreen" => Some((0, 100, 0))
    "darkgrey" => Some((169, 169, 169))
    "darkkhaki" => Some((189, 183, 107))
    "darkmagenta" => Some((139, 0, 139))
    "darkolivegreen" => Some((85, 107, 47))
    "darkorange" => Some((255, 140, 0))
    "darkorchid" => Some((153, 50, 204))
    "darkred" => Some((139, 0, 0))
    "darksalmon" => Some((233, 150, 122))
    "darkseagreen" => Some((143, 188, 143))
    "darkslateblue" => Some((72, 61, 139))
    "darkslategray" => Some((47, 79, 79))
    "darkslategrey" => Some((47, 79, 79))
    "darkturquoise" => Some((0, 206, 209))
    "darkviolet" => Some((148, 0, 211))
    "deeppink" => Some((255, 20, 147))
    "deepskyblue" => Some((0, 191, 255))
    "dimgray" => Some((105, 105, 105))
    "dimgrey" => Some((105, 105, 105))
    "dodgerblue" => Some((30, 144, 255))
    "firebrick" => Some((178, 34, 34))
    "floralwhite" => Some((255, 250, 240))
    "forestgreen" => Some((34, 139, 34))
    "fuchsia" => Some((255, 0, 255))
    "gainsboro" => Some((220, 220, 220))
    "ghostwhite" => Some((248, 248, 255))
    "gold" => Some((255, 215, 0))
    "goldenrod" => Some((218, 165, 32))
    "gray" => Some((128, 128, 128))
    "green" => Some((0, 128, 0))
    "greenyellow" => Some((173, 255, 47))
    "grey" => Some((128, 128, 128))
    "honeydew" => Some((240, 255, 240))
    "hotpink" => Some((255, 105, 180))
    "indianred" => Some((205, 92, 92))
    "indigo" => Some((75, 0, 130))
    "ivory" => Some((255, 255, 240))
    "khaki" => Some((240, 230, 140))
    "lavender" => Some((230, 230, 250))
    "lavenderblush" => Some((255, 240, 245))
    "lawngreen" => Some((124, 252, 0))
    "lemonchiffon" => Some((255, 250, 205))
    "lightblue" => Some((173, 216, 230))
    "lightcoral" => Some((240, 128, 128))
    "lightcyan" => Some((224, 255, 255))
    "lightgoldenrodyellow" => Some((250, 250, 210))
    "lightgray" => Some((211, 211, 211))
    "lightgreen" => Some((144, 238, 144))
    "lightgrey" => Some((211, 211, 211))
    "lightpink" => Some((255, 182, 193))
    "lightsalmon" => Some((255, 160, 122))
    "lightseagreen" => Some((32, 178, 170))
    "lightskyblue" => Some((135, 206, 250))
    "lightslategray" => Some((119, 136, 153))
    "lightslategrey" => Some((119, 136, 153))
    "lightsteelblue" => Some((176, 196, 222))
    "lightyellow" => Some((255, 255, 224))
    "lime" => Some((0, 255, 0))
    "limegreen" => Some((50, 205, 50))
    "linen" => Some((250, 240, 230))
    "magenta" => Some((255, 0, 255))
    "maroon" => Some((128, 0, 0))
    "mediumaquamarine" => Some((102, 205, 170))
    "mediumblue" => Some((0, 0, 205))
    "mediumorchid" => Some((186, 85, 211))
    "mediumpurple" => Some((147, 112, 219))
    "mediumseagreen" => Some((60, 179, 113))
    "mediumslateblue" => Some((123, 104, 238))
    "mediumspringgreen" => Some((0, 250, 154))
    "mediumturquoise" => Some((72, 209, 204))
    "mediumvioletred" => Some((199, 21, 133))
    "midnightblue" => Some((25, 25, 112))
    "mintcream" => Some((245, 255, 250))
    "mistyrose" => Some((255, 228, 225))
    "moccasin" => Some((255, 228, 181))
    "navajowhite" => Some((255, 222, 173))
    "navy" => Some((0, 0, 128))
    "oldlace" => Some((253, 245, 230))
    "olive" => Some((128, 128, 0))
    "olivedrab" => Some((107, 142, 35))
    "orange" => Some((255, 165, 0))
    "orangered" => Some((255, 69, 0))
    "orchid" => Some((218, 112, 214))
    "palegoldenrod" => Some((238, 232, 170))
    "palegreen" => Some((152, 251, 152))
    "paleturquoise" => Some((175, 238, 238))
    "palevioletred" => Some((219, 112, 147))
    "papayawhip" => Some((255, 239, 213))
    "peachpuff" => Some((255, 218, 185))
    "peru" => Some((205, 133, 63))
    "pink" => Some((255, 192, 203))
    "plum" => Some((221, 160, 221))
    "powderblue" => Some((176, 224, 230))
    "purple" => Some((128, 0, 128))
    "rebeccapurple" => Some((102, 51, 153))
    "red" => Some((255, 0, 0))
    "rosybrown" => Some((188, 143, 143))
    "royalblue" => Some((65, 105, 225))
    "saddlebrown" => Some((139, 69, 19))
    "salmon" => Some((250, 128, 114))
    "sandybrown" => Some((244, 164, 96))
    "seagreen" => Some((46, 139, 87))
    "seashell" => Some((255, 245, 238))
    "sienna" => Some((160, 82, 45))
    "silver" => Some((192, 192, 192))
    "skyblue" => Some((135, 206, 235))
    "slateblue" => Some((106, 90, 205))
    "slategray" => Some((112, 128, 144))
    "slategrey" => Some((112, 128, 144))
    "snow" => Some((255, 250, 250))
    "springgreen" => Some((0, 255, 127))
    "steelblue" => Some((70, 130, 180))
    "tan" => Some((210, 180, 140))
    "teal" => Some((0, 128, 128))
    "thistle" => Some((216, 191, 216))
    "tomato" => Some((255, 99, 71))
    "turquoise" => Some((64, 224, 208))
    "violet" => Some((238, 130, 238))
    "wheat" => Some((245, 222, 179))
    "white" => Some((255, 255, 255))
    "whitesmoke" => Some((245, 245, 245))
    "yellow" => Some((255, 255, 0))
    "yellowgreen" => Some((154, 205, 50))
    _ => None
  }
}

///|
fn parse_css_rgb(color : String) -> (Int, Int, Int)? {
  let normalized = color.trim().to_lower().to_string()
  if normalized == "transparent" {
    return Some((0, 0, 0))
  }
  match parse_hex_color(normalized) {
    Some(rgb) => Some(rgb)
    None => css_named_color_rgb(normalized)
  }
}

///|
fn darken_color_like_d2(color : String) -> String {
  match theme_token(color) {
    Some(token) =>
      match darken_theme_color_token(token) {
        Some(darker) => return darker
        None => return color
      }
    None => ()
  }
  let (r_i, g_i, b_i) = match parse_css_rgb(color) {
    Some(rgb) => rgb
    None => return color
  }
  let r = r_i.to_double() / 255.0
  let g = g_i.to_double() / 255.0
  let b = b_i.to_double() / 255.0
  let mut max_v = r
  if g > max_v {
    max_v = g
  }
  if b > max_v {
    max_v = b
  }
  let mut min_v = r
  if g < min_v {
    min_v = g
  }
  if b < min_v {
    min_v = b
  }
  let mut h = 0.0
  let mut s = 0.0
  let mut l = (max_v + min_v) / 2.0
  if max_v != min_v {
    let d = max_v - min_v
    if l > 0.5 {
      s = d / (2.0 - max_v - min_v)
    } else {
      s = d / (max_v + min_v)
    }
    if max_v == r {
      h = (g - b) / d
      if g < b {
        h = h + 6.0
      }
    } else if max_v == g {
      h = (b - r) / d + 2.0
    } else {
      h = (r - g) / d + 4.0
    }
    h = h / 6.0
  }
  l = l - 0.1
  if l < 0.0 {
    l = 0.0
  }
  if l > 1.0 {
    l = 1.0
  }
  let (r2, g2, b2) = if s == 0.0 {
    (l, l, l)
  } else {
    let q = if l < 0.5 { l * (1.0 + s) } else { l + s - l * s }
    let p = 2.0 * l - q
    (
      hue_to_rgb(p, q, h + 1.0 / 3.0),
      hue_to_rgb(p, q, h),
      hue_to_rgb(p, q, h - 1.0 / 3.0),
    )
  }
  let r_out = (r2 * 255.0 + 0.5).to_int()
  let g_out = (g2 * 255.0 + 0.5).to_int()
  let b_out = (b2 * 255.0 + 0.5).to_int()
  "#\{hex_byte_string(r_out)}\{hex_byte_string(g_out)}\{hex_byte_string(b_out)}"
}

///|
fn graph_has_markdown_shape(graph : Diagram) -> Bool {
  for shape in graph.shapes {
    if has_class(shape, "lang:markdown") {
      return true
    }
  }
  false
}

///|
fn hash_u32(s : String) -> Int {
  d2_fnv32a(s)
}

///|
fn style_scope_class(graph : Diagram, config : SvgConfig) -> String {
  diagram_scope_class(graph, config)
}

///|
fn defs_prefix(config : SvgConfig) -> String {
  match config.salt {
    Some(s) => if s == "" { "" } else { "s\{hash_u32(s).to_string()}-" }
    None => ""
  }
}

///|
fn defs_id(config : SvgConfig, base : String) -> String {
  defs_prefix(config) + base
}

///|
fn ceil_double(x : Double) -> Double {
  let n = x.to_int()
  let n_double = n.to_double()
  if n_double == x {
    x
  } else if x > n_double {
    (n + 1).to_double()
  } else {
    n_double
  }
}

///|
fn round_double(x : Double) -> Double {
  if x >= 0.0 {
    (x + 0.5).to_int().to_double()
  } else {
    (x - 0.5).to_int().to_double()
  }
}

///|
const LABEL_PADDING : Double = 5.0

///|
const D2_DEFAULT_ICON_SIZE : Int = 32

///|
const D2_MAX_ICON_SIZE : Int = 64

///|
const D2_DEFAULT_ICON_POSITION : String = "INSIDE_MIDDLE_CENTER"

///|
const ARROWHEAD_PADDING : Double = 2.0

///|
const MIN_ARROWHEAD_STROKE_WIDTH : Double = 2.0

///|
const DIAGO_VERSION : String = "0.2.0"

///|
const MULTIPLE_OFFSET : Double = 10.0

///|
const THREE_DEE_OFFSET : Double = 15.0

///|
const SHADOW_SIZE_X : Double = 3.0

///|
const SHADOW_SIZE_Y : Double = 5.0

///|
fn transform_label_text(text : String, text_transform : String) -> String {
  if text_transform == "" {
    return text
  }
  fn is_whitespace(ch : Char) -> Bool {
    ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
  }
  fn capitalize_words(input : String) -> String {
    let out = StringBuilder::new()
    let mut at_word_start = true
    for ch in input {
      if is_whitespace(ch) {
        out.write_char(ch)
        at_word_start = true
      } else {
        let piece = ch.to_string()
        out.write_string(
          if at_word_start {
            piece.to_upper()
          } else {
            piece.to_lower()
          },
        )
        at_word_start = false
      }
    }
    out.to_string()
  }
  match text_transform.to_lower() {
    "uppercase" => text.to_upper()
    "lowercase" => text.to_lower()
    "capitalize" => capitalize_words(text)
    _ => text
  }
}

///|
const ROOT_INNER_BORDER_OFFSET : Double = 5.0

///|
fn floor_to_int(v : Double) -> Int {
  @math.floor(v).to_int()
}

///|
fn ceil_to_int(v : Double) -> Int {
  ceil_double(v).to_int()
}

///|
fn d2_base_dimensions(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
  padding : Double,
) -> (Int, Int, Int, Int) {
  let left = floor_to_int(min_x - padding)
  let top = floor_to_int(min_y - padding)
  let right = ceil_to_int(max_x + padding)
  let bottom = ceil_to_int(max_y + padding)
  (left, top, right - left, bottom - top)
}

///|
priv struct RootCanvasMetrics {
  viewbox_x : Double
  viewbox_y : Double
  viewbox_width : Double
  viewbox_height : Double
  inner_x : Double
  inner_y : Double
  inner_width : Double
  inner_height : Double
  outer_x : Double?
  outer_y : Double?
  outer_width : Double?
  outer_height : Double?
  fill : String
  fill_pattern_class : String?
  stroke : String
  stroke_width : Double
  border_radius : Double
  stroke_dash : Double
}

///|
fn style_fill_pattern_key(fill_pattern : @graph.StyleValue?) -> String? {
  match style_string_opt(fill_pattern) {
    Some(pattern_raw) =>
      match pattern_raw.trim().to_lower() {
        "dots" => Some("dots")
        "lines" => Some("lines")
        "cross-hatch" | "crosshatch" => Some("crosshatch")
        "grain" => Some("grain")
        "none" | "" => None
        _ => None
      }
    None => None
  }
}

///|
fn pattern_def_id(pattern : String, diagram_hash : String) -> String {
  "\{pattern}-\{diagram_hash}"
}

///|
fn pattern_overlay_class(pattern : String) -> String {
  "\{pattern}-overlay"
}

///|
fn resolve_fill_with_pattern(
  base_fill : String,
  fill_pattern : @graph.StyleValue?,
  config : SvgConfig,
  diagram_hash : String,
) -> String {
  let _ = config
  match style_fill_pattern_key(fill_pattern) {
    Some(pattern) => "url(#\{pattern_def_id(pattern, diagram_hash)})"
    None => base_fill
  }
}

///|
const APPENDIX_ICON_RADIUS : Int = 16

///|
const APPENDIX_ICON_DIAMETER : Int = 32

///|
fn non_empty_string(value : String?) -> String? {
  match value {
    Some(v) => if v.trim() == "" { None } else { Some(v) }
    None => None
  }
}

///|
fn d2_svg_base32(bytes : Bytes) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  let out = StringBuilder::new()
  let mut acc = 0
  let mut bits = 0
  for b in bytes {
    acc = (acc << 8) | b.to_int()
    bits = bits + 8
    while bits >= 5 {
      let idx = (acc >> (bits - 5)) & 31
      out.write_char(alphabet[idx].to_char().unwrap())
      bits = bits - 5
    }
  }
  if bits > 0 {
    let idx = (acc << (5 - bits)) & 31
    out.write_char(alphabet[idx].to_char().unwrap())
  }
  out.to_string()
}

///|
fn d2_svg_id(id : String) -> String {
  d2_svg_base32(@utf8.encode(id[:]))
}

///|
fn tooltip_icon_svg(clip_id : String) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "<svg width=\"32\" height=\"32\" viewBox=\"0 0 32 32\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n",
  )
  sb.write_string("<g clip-path=\"url(#\{clip_id})\">\n")
  sb.write_string(
    "<path d=\"M16 31.1109C24.3456 31.1109 31.1111 24.3454 31.1111 15.9998C31.1111 7.65415 24.3456 0.888672 16 0.888672C7.65436 0.888672 0.888885 7.65415 0.888885 15.9998C0.888885 24.3454 7.65436 31.1109 16 31.1109Z\" fill=\"white\" stroke=\"#DEE1EB\"/>\n",
  )
  sb.write_string(
    "<path d=\"M16 26C21.5228 26 26 21.5228 26 16C26 10.4772 21.5228 6 16 6C10.4772 6 6 10.4772 6 16C6 21.5228 10.4772 26 16 26Z\" stroke=\"#2E3346\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n",
  )
  sb.write_string(
    "<path d=\"M16 19.998V15.998\" stroke=\"#2E3346\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n",
  )
  sb.write_string(
    "<path d=\"M16 12H16.0098\" stroke=\"#2E3346\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n",
  )
  sb.write_string("</g>\n")
  sb.write_string("<defs>\n")
  sb.write_string("<clipPath id=\"\{clip_id}\">\n")
  sb.write_string("<rect width=\"32\" height=\"32\" fill=\"white\"/>\n")
  sb.write_string("</clipPath>\n")
  sb.write_string("</defs>\n")
  sb.write_string("</svg>")
  sb.to_string()
}

///|
fn link_icon_svg(clip_id : String) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "<svg width=\"32\" height=\"32\" viewBox=\"0 0 32 32\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n",
  )
  sb.write_string("<g clip-path=\"url(#\{clip_id})\">\n")
  sb.write_string(
    "<path d=\"M16 31.1109C24.3456 31.1109 31.1111 24.3454 31.1111 15.9998C31.1111 7.65415 24.3456 0.888672 16 0.888672C7.65436 0.888672 0.888885 7.65415 0.888885 15.9998C0.888885 24.3454 7.65436 31.1109 16 31.1109Z\" fill=\"white\" stroke=\"#DEE1EB\"/>\n",
  )
  sb.write_string(
    "<path d=\"M14.3909 16.7965C14.7364 17.2584 15.1772 17.6406 15.6834 17.9171C16.1896 18.1938 16.7494 18.3582 17.3248 18.3993C17.9001 18.4405 18.4777 18.3575 19.0181 18.1559C19.5586 17.9543 20.0492 17.6389 20.4571 17.2309L22.8708 14.8173C23.6036 14.0586 24.0089 13.0425 23.9998 11.9877C23.9906 10.933 23.5676 9.92404 22.8217 9.17821C22.0759 8.43237 21.067 8.00931 20.0123 8.00015C18.9575 7.99098 17.9413 8.39644 17.1827 9.1292L15.7988 10.505\" stroke=\"#2E3346\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n",
  )
  sb.write_string(
    "<path d=\"M17.609 15.1874C17.2635 14.7255 16.8227 14.3433 16.3165 14.0667C15.8103 13.7902 15.2505 13.6257 14.6752 13.5845C14.0998 13.5433 13.5223 13.6263 12.9819 13.8279C12.4414 14.0295 11.9506 14.345 11.5428 14.753L9.1292 17.1666C8.39644 17.9252 7.99098 18.9414 8.00015 19.9962C8.00931 21.0509 8.43237 22.0598 9.17821 22.8056C9.92405 23.5515 10.933 23.9745 11.9877 23.9837C13.0425 23.9928 14.0586 23.5875 14.8173 22.8547L16.193 21.4788\" stroke=\"#2E3346\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n",
  )
  sb.write_string("</g>\n")
  sb.write_string("<defs>\n")
  sb.write_string("<clipPath id=\"\{clip_id}\">\n")
  sb.write_string("<rect width=\"32\" height=\"32\" fill=\"white\"/>\n")
  sb.write_string("</clipPath>\n")
  sb.write_string("</defs>\n")
  sb.write_string("</svg>")
  sb.to_string()
}

///|
fn positioned_tooltip_size(
  obj : Shape,
  config : SvgConfig,
  theme : @themes.Theme,
) -> (Int, Int) {
  let font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(default_object_font_size(obj, config))
    None => default_object_font_size(obj, config)
  }
  let is_mono = obj.shape_type == Code ||
    theme.rules.mono ||
    style_is_mono(obj.style.font_family)
  let dims = @text_metrics.measure_text(
    obj.tooltip.unwrap_or(""),
    font_size,
    is_mono,
    false,
    false,
  )
  (
    dims.dimensions.width.ceil().to_int() + 20,
    dims.dimensions.height.ceil().to_int() + 20,
  )
}

///|
fn d2_calculate_tooltip_position(
  shape_x : Double,
  shape_y : Double,
  shape_width : Double,
  shape_height : Double,
  tooltip_width : Int,
  tooltip_height : Int,
  position : String,
) -> (Double, Double) {
  let padding = 10.0
  match position {
    "top-left" => (shape_x, shape_y - tooltip_height.to_double() - padding)
    "top-center" =>
      (
        shape_x + shape_width / 2.0 - tooltip_width.to_double() / 2.0,
        shape_y - tooltip_height.to_double() - padding,
      )
    "top-right" =>
      (
        shape_x + shape_width - tooltip_width.to_double(),
        shape_y - tooltip_height.to_double() - padding,
      )
    "center-left" =>
      (
        shape_x - tooltip_width.to_double() - padding,
        shape_y + shape_height / 2.0 - tooltip_height.to_double() / 2.0,
      )
    "center-right" =>
      (
        shape_x + shape_width + padding,
        shape_y + shape_height / 2.0 - tooltip_height.to_double() / 2.0,
      )
    "bottom-left" => (shape_x, shape_y + shape_height + padding)
    "bottom-center" =>
      (
        shape_x + shape_width / 2.0 - tooltip_width.to_double() / 2.0,
        shape_y + shape_height + padding,
      )
    "bottom-right" =>
      (
        shape_x + shape_width - tooltip_width.to_double(),
        shape_y + shape_height + padding,
      )
    _ =>
      (
        shape_x + shape_width / 2.0 - tooltip_width.to_double() / 2.0,
        shape_y - tooltip_height.to_double() - padding,
      )
  }
}

///|
fn positioned_tooltip_bounds(
  obj : Shape,
  box : Box,
  config : SvgConfig,
  theme : @themes.Theme,
) -> (Double, Double, Double, Double)? {
  match obj.tooltip_position {
    Some(position) =>
      if non_empty_string(obj.tooltip) is Some(_) {
        let (tooltip_width, tooltip_height) = positioned_tooltip_size(
          obj, config, theme,
        )
        let (x, y) = d2_calculate_tooltip_position(
          box.x,
          box.y,
          box.width,
          box.height,
          tooltip_width,
          tooltip_height,
          position,
        )
        Some(
          (
            @math.floor(x),
            @math.floor(y),
            ceil_double(x) + tooltip_width.to_double(),
            ceil_double(y) + tooltip_height.to_double(),
          ),
        )
      } else {
        None
      }
    None => None
  }
}

///|
fn positioned_tooltip_tail(
  tail_direction : String,
  tail_x : Double,
  tail_y : Double,
) -> String {
  let tail_size = 8.0
  match tail_direction {
    "top" =>
      "<path d=\"M \{d2_fixed6(tail_x - tail_size / 2.0)} \{d2_fixed6(tail_y)} L \{d2_fixed6(tail_x + tail_size / 2.0)} \{d2_fixed6(tail_y)} L \{d2_fixed6(tail_x)} \{d2_fixed6(tail_y - tail_size)} Z\" fill=\"white\" stroke=\"#DEE1EB\" stroke-width=\"1\"/>"
    "bottom" =>
      "<path d=\"M \{d2_fixed6(tail_x - tail_size / 2.0)} \{d2_fixed6(tail_y)} L \{d2_fixed6(tail_x + tail_size / 2.0)} \{d2_fixed6(tail_y)} L \{d2_fixed6(tail_x)} \{d2_fixed6(tail_y + tail_size)} Z\" fill=\"white\" stroke=\"#DEE1EB\" stroke-width=\"1\"/>"
    "left" =>
      "<path d=\"M \{d2_fixed6(tail_x)} \{d2_fixed6(tail_y - tail_size / 2.0)} L \{d2_fixed6(tail_x)} \{d2_fixed6(tail_y + tail_size / 2.0)} L \{d2_fixed6(tail_x - tail_size)} \{d2_fixed6(tail_y)} Z\" fill=\"white\" stroke=\"#DEE1EB\" stroke-width=\"1\"/>"
    "right" =>
      "<path d=\"M \{d2_fixed6(tail_x)} \{d2_fixed6(tail_y - tail_size / 2.0)} L \{d2_fixed6(tail_x)} \{d2_fixed6(tail_y + tail_size / 2.0)} L \{d2_fixed6(tail_x + tail_size)} \{d2_fixed6(tail_y)} Z\" fill=\"white\" stroke=\"#DEE1EB\" stroke-width=\"1\"/>"
    _ => ""
  }
}

///|
fn render_positioned_tooltip(
  obj : Shape,
  box : Box,
  config : SvgConfig,
  theme : @themes.Theme,
) -> String? {
  let tooltip_text = non_empty_string(obj.tooltip)
  match (tooltip_text, obj.tooltip_position) {
    (Some(text), Some(position)) => {
      let (tooltip_width, tooltip_height) = positioned_tooltip_size(
        obj, config, theme,
      )
      let (x, y) = d2_calculate_tooltip_position(
        box.x,
        box.y,
        box.width,
        box.height,
        tooltip_width,
        tooltip_height,
        position,
      )
      let (tail_direction, tail_x, tail_y) = match position {
        "top-left" => ("bottom", 20.0, tooltip_height.to_double())
        "top-center" =>
          (
            "bottom",
            tooltip_width.to_double() / 2.0,
            tooltip_height.to_double(),
          )
        "top-right" =>
          (
            "bottom",
            tooltip_width.to_double() - 20.0,
            tooltip_height.to_double(),
          )
        "center-left" =>
          ("right", tooltip_width.to_double(), tooltip_height.to_double() / 2.0)
        "center-right" => ("left", 0.0, tooltip_height.to_double() / 2.0)
        "bottom-left" => ("top", 20.0, 0.0)
        "bottom-center" => ("top", tooltip_width.to_double() / 2.0, 0.0)
        "bottom-right" => ("top", tooltip_width.to_double() - 20.0, 0.0)
        _ =>
          (
            "bottom",
            tooltip_width.to_double() / 2.0,
            tooltip_height.to_double(),
          )
      }
      let md_html = @cmark_html.render(safe=false, strict=false, text) catch {
        _ => @svg.escape_xml(text)
      }
      let foreign = @xml_emit.Element::new("foreignObject")
        .attr("x", d2_fixed6(x + 10.0))
        .attr("y", d2_fixed6(y + 10.0))
        .attr_int("width", tooltip_width - 20)
        .attr_int("height", tooltip_height - 20)
        .raw(
          @xml_emit.Element::new("div")
          .attr("xmlns", "http://www.w3.org/1999/xhtml")
          .attr("class", "md color-N1")
          .raw(md_html)
          .build(),
        )
        .build()
      Some(
        "<g class=\"positioned-tooltip\"><rect x=\"\{d2_fixed6(x)}\" y=\"\{d2_fixed6(y)}\" width=\"\{tooltip_width}\" height=\"\{tooltip_height}\" rx=\"4\" ry=\"4\" fill=\"white\" stroke=\"#DEE1EB\" stroke-width=\"1\"/>\{positioned_tooltip_tail(tail_direction, tail_x + x, tail_y + y)}\{foreign}</g>",
      )
    }
    _ => None
  }
}

///|
fn render_object_appendix_icons(
  diagram_hash : String,
  obj : Shape,
  box : @graph.Box,
  config : SvgConfig,
  theme : @themes.Theme,
) -> Array[String] {
  let elements : Array[String] = []
  let tooltip_text = non_empty_string(obj.tooltip)
  let link_href = non_empty_string(obj.link)
  let has_tooltip_icon = tooltip_text is Some(_) && obj.tooltip_position is None
  if !has_tooltip_icon && link_href is None && obj.tooltip_position is None {
    return elements
  }
  let anchor_x = (box.x + box.width).ceil().to_int()
  let anchor_y = box.y.ceil().to_int()
  let tooltip_slot_offset = 0
  let link_slot_offset = if has_tooltip_icon {
    APPENDIX_ICON_DIAMETER
  } else {
    0
  }

  match render_positioned_tooltip(obj, box, config, theme) {
    Some(rendered) => elements.push(rendered)
    None => ()
  }

  match tooltip_text {
    Some(text) =>
      if obj.tooltip_position is None {
        let x = anchor_x - APPENDIX_ICON_RADIUS - tooltip_slot_offset
        let y = anchor_y - APPENDIX_ICON_RADIUS
        let clip_id = "clip0_3427_35082111-\{diagram_hash}-\{d2_svg_id(d2_output_abs_id(obj.id))}"
        let icon_svg = tooltip_icon_svg(clip_id)
        elements.push(
          "<g transform=\"translate(\{x} \{y})\" class=\"appendix-icon\"><title>\{@svg.escape_xml(text)}</title>\{icon_svg}\n</g>",
        )
      }
    None => ()
  }

  match link_href {
    Some(_) => {
      let x = anchor_x - APPENDIX_ICON_RADIUS - link_slot_offset
      let y = anchor_y - APPENDIX_ICON_RADIUS
      let clip_id = "clip0_3440_35088111-\{diagram_hash}-\{d2_svg_id(d2_output_abs_id(obj.id))}"
      let icon_svg = link_icon_svg(clip_id)
      elements.push(
        "<g transform=\"translate(\{x} \{y})\" class=\"appendix-icon\">\{icon_svg}\n</g>",
      )
    }
    None => ()
  }
  elements
}

///|
fn append_object_appendix_icons(
  diagram_hash : String,
  appendix_items : Array[String],
  obj : Shape,
  box : @graph.Box,
  config : SvgConfig,
  theme : @themes.Theme,
) -> Unit {
  for
    item in render_object_appendix_icons(diagram_hash, obj, box, config, theme) {
    appendix_items.push(item)
  }
}

///|
fn append_object_title(
  svg : @svg.Svg,
  obj : Shape,
  object_pass_active : Bool,
) -> Unit {
  if !object_pass_active {
    return
  }
  match (non_empty_string(obj.tooltip), obj.tooltip_position) {
    (Some(text), None) =>
      svg.add(@xml_emit.Element::new("title").text(text).build())
    _ => ()
  }
}

///|
fn root_has_stroke(style : @graph.StyleInput) -> Bool {
  match style_string_opt(style.stroke) {
    Some(value) => {
      let normalized = value.trim().to_lower()
      normalized != "" && normalized != "none"
    }
    None => false
  }
}

///|
fn root_stroke_width(style : @graph.StyleInput, config : SvgConfig) -> Double {
  match style.stroke_width {
    Some(v) => v.as_double().unwrap_or(0.0)
    None =>
      if root_has_stroke(style) {
        config.default_stroke_width
      } else {
        0.0
      }
  }
}

///|
fn compute_root_canvas_metrics(
  graph : Diagram,
  config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  base_left : Int,
  base_top : Int,
  base_width : Int,
  base_height : Int,
) -> RootCanvasMetrics {
  let fill = style_color(graph.root.style.fill, "N7", theme, use_css_theme_vars)
  let fill_pattern_class = match
    style_fill_pattern_key(graph.root.style.fill_pattern) {
    Some(pattern) => Some(pattern_overlay_class(pattern))
    None => None
  }
  let stroke = if root_has_stroke(graph.root.style) {
    style_color(graph.root.style.stroke, "N1", theme, use_css_theme_vars)
  } else {
    "none"
  }
  let stroke_width = root_stroke_width(graph.root.style, config)
  let border_radius = if theme.rules.no_corner_radius {
    0.0
  } else {
    style_double(graph.root.style.border_radius, 0.0)
  }
  let stroke_dash = style_double(graph.root.style.stroke_dash, 0.0)
  let half_stroke = ceil_to_int(stroke_width / 2.0)
  let inner_left = base_left - half_stroke
  let inner_top = base_top - half_stroke
  let inner_width_int = base_width + half_stroke * 2
  let inner_height_int = base_height + half_stroke * 2
  let mut viewbox_left = inner_left - half_stroke
  let mut viewbox_top = inner_top - half_stroke
  let mut viewbox_width_int = inner_width_int + half_stroke * 2
  let mut viewbox_height_int = inner_height_int + half_stroke * 2
  let mut outer_x : Double? = None
  let mut outer_y : Double? = None
  let mut outer_width : Double? = None
  let mut outer_height : Double? = None
  if style_bool(graph.root.style.double_border, false) {
    let inner_border_offset = ROOT_INNER_BORDER_OFFSET.to_int()
    let outer_left = viewbox_left - half_stroke - inner_border_offset
    let outer_top = viewbox_top - half_stroke - inner_border_offset
    let outer_w = viewbox_width_int + half_stroke * 2 + inner_border_offset * 2
    let outer_h = viewbox_height_int + half_stroke * 2 + inner_border_offset * 2
    outer_x = Some(outer_left.to_double())
    outer_y = Some(outer_top.to_double())
    outer_width = Some(outer_w.to_double())
    outer_height = Some(outer_h.to_double())
    viewbox_left = outer_left - half_stroke
    viewbox_top = outer_top - half_stroke
    viewbox_width_int = outer_w + half_stroke * 2
    viewbox_height_int = outer_h + half_stroke * 2
  }
  {
    viewbox_x: viewbox_left.to_double(),
    viewbox_y: viewbox_top.to_double(),
    viewbox_width: viewbox_width_int.to_double(),
    viewbox_height: viewbox_height_int.to_double(),
    inner_x: inner_left.to_double(),
    inner_y: inner_top.to_double(),
    inner_width: inner_width_int.to_double(),
    inner_height: inner_height_int.to_double(),
    outer_x,
    outer_y,
    outer_width,
    outer_height,
    fill,
    fill_pattern_class,
    stroke,
    stroke_width,
    border_radius,
    stroke_dash,
  }
}

///|
fn add_root_background_rect(
  svg : @svg.Svg,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  fill : String,
  stroke : String,
  stroke_width : Double,
  border_radius : Double,
  stroke_dash : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  class_name? : String? = None,
) -> Unit {
  let _ = stroke_dash
  svg.add(
    d2_root_background_rect(
      x,
      y,
      width,
      height,
      fill,
      stroke,
      stroke_width,
      border_radius,
      class_name,
      theme,
      !use_css_theme_vars,
    ),
  )
}

///|
fn add_root_overlay_rect(
  svg : @svg.Svg,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  border_radius : Double,
  stroke_width : Double,
  class_name : String?,
) -> Unit {
  match class_name {
    Some(class_name) => {
      let stroke_width_css = if stroke_width.round() == stroke_width {
        stroke_width.to_int().to_string()
      } else {
        d2_fixed6(stroke_width)
      }
      svg.add(
        "<rect x=\"\{d2_fixed6(x)}\" y=\"\{d2_fixed6(y)}\" width=\"\{d2_fixed6(width)}\" height=\"\{d2_fixed6(height)}\" rx=\"\{d2_fixed6(border_radius)}\" class=\"\{@svg.escape_xml(class_name)}\" stroke-width=\"\{stroke_width_css}\" />",
      )
    }
    None => ()
  }
}

///|
fn render_root_background(
  svg : @svg.Svg,
  metrics : RootCanvasMetrics,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> Unit {
  match
    (
      metrics.outer_x,
      metrics.outer_y,
      metrics.outer_width,
      metrics.outer_height,
    ) {
    (Some(x), Some(y), Some(width), Some(height)) => {
      add_root_background_rect(
        svg,
        x,
        y,
        width,
        height,
        metrics.fill,
        metrics.stroke,
        metrics.stroke_width,
        metrics.border_radius,
        metrics.stroke_dash,
        theme,
        use_css_theme_vars,
      )
      add_root_overlay_rect(
        svg,
        x,
        y,
        width,
        height,
        metrics.border_radius,
        metrics.stroke_width,
        metrics.fill_pattern_class,
      )
      add_root_background_rect(
        svg,
        metrics.inner_x,
        metrics.inner_y,
        metrics.inner_width,
        metrics.inner_height,
        "transparent",
        metrics.stroke,
        metrics.stroke_width,
        metrics.border_radius,
        metrics.stroke_dash,
        theme,
        use_css_theme_vars,
      )
      add_root_overlay_rect(
        svg,
        metrics.inner_x,
        metrics.inner_y,
        metrics.inner_width,
        metrics.inner_height,
        metrics.border_radius,
        metrics.stroke_width,
        metrics.fill_pattern_class,
      )
    }
    _ => {
      add_root_background_rect(
        svg,
        metrics.inner_x,
        metrics.inner_y,
        metrics.inner_width,
        metrics.inner_height,
        metrics.fill,
        metrics.stroke,
        metrics.stroke_width,
        metrics.border_radius,
        metrics.stroke_dash,
        theme,
        use_css_theme_vars,
      )
      add_root_overlay_rect(
        svg,
        metrics.inner_x,
        metrics.inner_y,
        metrics.inner_width,
        metrics.inner_height,
        metrics.border_radius,
        metrics.stroke_width,
        metrics.fill_pattern_class,
      )
    }
  }
}

///|
/// Render a graph to SVG string
pub fn render_svg(
  graph : Diagram,
  config : SvgConfig,
) -> String raise @render_api.RenderError {
  // The base render always uses the light theme. Dark theme is applied through
  // CSS media rules when configured.
  let light_theme = @themes.get_theme(config.theme_id).with_overrides(
    config.theme_overrides,
  )
  let dark_theme = match config.dark_theme_id {
    Some(theme_id) =>
      Some(
        @themes.get_theme(theme_id).with_overrides(config.dark_theme_overrides),
      )
    None => None
  }
  let use_css_theme_vars = dark_theme is Some(_)
  // D2 parity: do not reserve extra height for custom interactive controls.
  let control_height = 0.0
  // D2 parity: SVG export renders the current board only.
  let (base_min_x, base_min_y, base_max_x, base_max_y) = compute_graph_bounds(
    graph, config, light_theme,
  )
  let min_x = base_min_x
  let min_y = base_min_y
  let max_x = base_max_x
  let max_y = base_max_y
  let bounds = (min_x, min_y, max_x, max_y)
  // D2 parity: dimensions are based on BoundingBox + pad.
  let (base_left, base_top, base_width, base_height) = d2_base_dimensions(
    min_x,
    min_y,
    max_x,
    max_y,
    config.padding + control_height,
  )
  let root_canvas = compute_root_canvas_metrics(
    graph, config, light_theme, use_css_theme_vars, base_left, base_top, base_width,
    base_height,
  )
  let viewbox_x = root_canvas.viewbox_x
  let viewbox_y = root_canvas.viewbox_y
  let viewbox_width = root_canvas.viewbox_width
  let viewbox_height = root_canvas.viewbox_height
  let (width, height) = match config.scale {
    Some(scale) =>
      (ceil_double(viewbox_width * scale), ceil_double(viewbox_height * scale))
    None => (viewbox_width, viewbox_height)
  }
  // Create SVG document
  let svg = @svg.Svg::new(width, height)
  svg.set_viewbox(viewbox_x, viewbox_y, viewbox_width, viewbox_height)
  if config.no_xml_tag {
    svg.set_include_xml_declaration(false)
  }
  let scope_class = style_scope_class(graph, config)
  let has_markdown_shape = graph_has_markdown_shape(graph)
  let emit_assets = SvgEmitAssets::new(
    scope_class, light_theme, dark_theme, has_markdown_shape,
  )
  // Add fill patterns
  add_fill_patterns(emit_assets, graph, config, light_theme, use_css_theme_vars)
  // Add sketch filter if needed
  add_sketch_filter(emit_assets, graph, config)
  // Add drop-shadow filter if any object uses `shadow: true`
  add_shadow_filter(emit_assets, graph)
  // D2 parity: all connection labels are cut out via a shared mask.
  let edge_label_mask_url = "url(#\{emit_assets.mask_id()})"
  emit_assets.add_tail(
    edge_label_mask_def(
      emit_assets.mask_id(),
      graph,
      base_left,
      base_top,
      base_width,
      base_height,
    ),
  )
  let edge_marker_ids : Map[String, String] = {}
  let appendix_items : Array[String] = []
  // Background
  render_root_background(svg, root_canvas, light_theme, use_css_theme_vars)
  // D2 parity: skip custom control bar rendering.
  // D2 parity: render in one combined z-ordered stream of shapes+connections.
  // Shapes still use internal background/foreground passes when needed, but are
  // emitted at their sorted position in the global object order.
  let sorted_objects = sort_render_objects(graph.shapes, graph.connections)
  let connection_repeat_indices = d2_connection_repeat_indices(
    graph.connections,
  )
  let repeat_index_by_edge_index : Map[Int, Int] = {}
  for i, edge in graph.connections {
    repeat_index_by_edge_index[edge.index] = connection_repeat_indices[i]
  }
  for obj in sorted_objects {
    match obj {
      ShapeObj(shape) => {
        render_svg_object(
          svg,
          scope_class,
          appendix_items,
          shape,
          graph.shapes,
          config,
          light_theme,
          use_css_theme_vars,
          pass=Background,
        )
        render_svg_object(
          svg,
          scope_class,
          appendix_items,
          shape,
          graph.shapes,
          config,
          light_theme,
          use_css_theme_vars,
          pass=Foreground,
        )
      }
      EdgeObj(edge) =>
        render_svg_edge(
          svg,
          edge,
          repeat_index_by_edge_index.get(edge.index).unwrap_or(0),
          graph.shapes,
          edge_label_mask_url,
          edge_marker_ids,
          scope_class,
          config,
          light_theme,
          use_css_theme_vars,
        )
    }
  }
  // Render sequence diagram notes (using page shape)
  for note in graph.sequence_notes {
    let text = note.1
    let box = note.2
    render_svg_sequence_note(svg, box, text, config)
  }
  // Render sequence diagram fragments (combined fragments like alt, opt, loop)
  render_svg_sequence_fragments(svg, graph, config)
  for item in appendix_items {
    svg.add(item)
  }
  // D2 parity: export only the active/base board in SVG output.

  // Render legend (always visible across layer/scenario/step switching)
  match graph.legend {
    Some(legend) =>
      match
        @layout_svg.compute_legend_layout(
          legend,
          bounds,
          @layout_svg.LegendLayoutConfig::new(config.font_size),
        ) {
        Some(layout) => render_legend_svg(svg, layout, config)
        None => ()
      }
    None => ()
  }

  // D2 parity: skip injecting custom control scripts.
  emit_svg_document(graph, svg, config, emit_assets)
}

///|
/// Estimate text width based on font size and character count
fn estimate_text_width(text : String, font_size : Int) -> Double {
  // Average character width is approximately 0.6 * font_size for proportional fonts
  text.length().to_double() * font_size.to_double() * 0.6
}

///|
/// Build the shared connection label mask definition.
fn edge_label_mask_def(
  mask_id : String,
  graph : Diagram,
  mask_x : Int,
  mask_y : Int,
  mask_width : Int,
  mask_height : Int,
) -> String {
  let sb = StringBuilder::new()
  let mx = mask_x
  let my = mask_y
  let mw = mask_width
  let mh = mask_height
  let mut label_count = 0
  sb.write_string(
    "<mask id=\"\{mask_id}\" maskUnits=\"userSpaceOnUse\" x=\"\{mx}\" y=\"\{my}\" width=\"\{mw}\" height=\"\{mh}\">\n",
  )
  sb.write_string(
    "<rect x=\"\{mx}\" y=\"\{my}\" width=\"\{mw}\" height=\"\{mh}\" fill=\"white\"></rect>\n",
  )
  for edge in graph.connections {
    if edge.label == "" {
      continue
    }
    match edge.label_box {
      Some(label_box) => {
        let label_x = round_double(label_box.x) - 2.0
        let label_y = round_double(label_box.y)
        let label_width = round_double(label_box.width).to_int() + 4
        let label_height = round_double(label_box.height).to_int()
        sb.write_string(
          "<rect x=\"\{d2_fixed6(label_x)}\" y=\"\{d2_fixed6(label_y)}\" width=\"\{label_width}\" height=\"\{label_height}\" fill=\"black\"></rect>\n",
        )
        label_count = label_count + 1
      }
      None => ()
    }
  }
  if label_count == 0 {
    sb.write_string("\n")
  }
  sb.write_string("</mask>")
  sb.to_string()
}

///|
fn marker_key(
  arrowhead : ArrowheadType,
  is_target : Bool,
  stroke_signature : String,
  stroke_width : Double,
) -> String {
  "\{d2_hash_arrowhead_value(arrowhead)}|\{is_target}|\{stroke_signature}|\{stroke_width.to_int()}"
}

///|
fn marker_dimensions(
  arrowhead : ArrowheadType,
  stroke_width : Double,
) -> (Double, Double) {
  let clipped_stroke_width = if stroke_width < MIN_ARROWHEAD_STROKE_WIDTH {
    MIN_ARROWHEAD_STROKE_WIDTH
  } else {
    stroke_width
  }
  let (base_width, base_height, width_multiplier, height_multiplier) = match
    arrowhead {
    @graph.Triangle => (4.0, 4.0, 3.0, 4.0)
    @graph.Open => (7.0, 7.0, 3.0, 4.0)
    @graph.Line => (0.0, 0.0, 5.0, 8.0)
    @graph.Diamond => (11.0, 9.0, 5.5, 4.5)
    @graph.Circle => (8.0, 8.0, 5.0, 5.0)
    @graph.CfOne
    | @graph.CfMany
    | @graph.CfOneRequired
    | @graph.CfManyRequired
    | @graph.CfOneOptional
    | @graph.CfManyOptional => (9.0, 9.0, 4.5, 4.5)
    @graph.None => (0.0, 0.0, 0.0, 0.0)
  }
  (
    base_width + clipped_stroke_width * width_multiplier,
    base_height + clipped_stroke_width * height_multiplier,
  )
}

///|
fn marker_body(
  arrowhead : ArrowheadType,
  is_target : Bool,
  stroke : String,
  stroke_width : Double,
  width : Double,
  height : Double,
  theme : @themes.Theme,
) -> String {
  let stroke_width_css = if stroke_width.round() == stroke_width {
    stroke_width.to_int().to_string()
  } else {
    d2_fixed6(stroke_width)
  }
  let connection_fill_class = match d2_theme_token(stroke, theme) {
    Some(token) => "connection fill-\{token}"
    None => "connection"
  }
  let connection_stroke_class = match d2_theme_token(stroke, theme) {
    Some(token) => "connection stroke-\{token}"
    None => "connection"
  }
  let bg_fill_class = match d2_theme_token("#FFFFFF", theme) {
    Some(token) => "fill-\{token}"
    None => ""
  }
  let stroke_and_bg_class = if bg_fill_class == "" {
    connection_stroke_class
  } else {
    "\{connection_stroke_class} \{bg_fill_class}"
  }
  let bg_stroke_class = match d2_theme_token(stroke, theme) {
    Some(token) =>
      if bg_fill_class == "" {
        " stroke-\{token}"
      } else {
        " stroke-\{token} \{bg_fill_class}"
      }
    None => if bg_fill_class == "" { "" } else { " \{bg_fill_class}" }
  }
  match arrowhead {
    @graph.None => ""
    @graph.Triangle => {
      let points = if is_target {
        "\{d2_fixed6(0.0)},\{d2_fixed6(0.0)} \{d2_fixed6(width)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(0.0)},\{d2_fixed6(height)}"
      } else {
        "\{d2_fixed6(width)},\{d2_fixed6(0.0)} \{d2_fixed6(0.0)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width)},\{d2_fixed6(height)}"
      }
      @xml_emit.Element::new("polygon")
      .attr("points", points)
      .attr("fill", stroke)
      .attr("class", connection_fill_class)
      .attr("stroke-width", stroke_width_css)
      .self_close()
      .build()
    }
    @graph.Open => {
      let inset = stroke_width / 2.0
      let points = if is_target {
        "\{d2_fixed6(inset)},\{d2_fixed6(inset)} \{d2_fixed6(width - inset)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(inset)},\{d2_fixed6(height - inset)}"
      } else {
        "\{d2_fixed6(width - inset)},\{d2_fixed6(inset)} \{d2_fixed6(inset)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width - inset)},\{d2_fixed6(height - inset)}"
      }
      @xml_emit.Element::new("polygon")
      .attr("points", points)
      .attr("fill", "#FFFFFF")
      .attr("stroke", stroke)
      .attr("class", stroke_and_bg_class)
      .attr("stroke-width", stroke_width_css)
      .self_close()
      .build()
    }
    @graph.Line => {
      let points = if is_target {
        "\{d2_fixed6(stroke_width / 2.0)},\{d2_fixed6(stroke_width / 2.0)} \{d2_fixed6(width - stroke_width / 2.0)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(stroke_width / 2.0)},\{d2_fixed6(height - stroke_width / 2.0)}"
      } else {
        "\{d2_fixed6(width - stroke_width / 2.0)},\{d2_fixed6(stroke_width / 2.0)} \{d2_fixed6(stroke_width / 2.0)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width - stroke_width / 2.0)},\{d2_fixed6(height - stroke_width / 2.0)}"
      }
      @xml_emit.Element::new("polyline")
      .attr("points", points)
      .attr("fill", "none")
      .attr("stroke", stroke)
      .attr("class", connection_stroke_class)
      .attr("stroke-width", stroke_width_css)
      .self_close()
      .build()
    }
    @graph.Diamond => {
      let points = if is_target {
        "\{d2_fixed6(0.0)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width / 2.0)},\{d2_fixed6(height / 8.0)} \{d2_fixed6(width)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width / 2.0)},\{d2_fixed6(height * 0.9)}"
      } else {
        "\{d2_fixed6(width / 8.0)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width * 0.6)},\{d2_fixed6(height / 8.0)} \{d2_fixed6(width * 1.1)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width * 0.6)},\{d2_fixed6(height * 7.0 / 8.0)}"
      }
      @xml_emit.Element::new("polygon")
      .attr("points", points)
      .attr("stroke", stroke)
      .attr("fill", "#FFFFFF")
      .attr("class", stroke_and_bg_class)
      .attr("stroke-width", stroke_width_css)
      .self_close()
      .build()
    }
    @graph.Circle => {
      let radius = width / 2.0
      let cx = if is_target {
        radius + stroke_width / 2.0
      } else {
        radius - stroke_width / 2.0
      }
      let inner_radius = radius - stroke_width
      @xml_emit.Element::new("circle")
      .attr("r", d2_fixed6(inner_radius))
      .attr("cx", d2_fixed6(cx))
      .attr("cy", d2_fixed6(radius))
      .attr("stroke", stroke)
      .attr("fill", "#FFFFFF")
      .attr("class", bg_stroke_class)
      .attr("stroke-width", stroke_width_css)
      .self_close()
      .build()
    }
    @graph.CfOne
    | @graph.CfMany
    | @graph.CfOneRequired
    | @graph.CfManyRequired
    | @graph.CfOneOptional
    | @graph.CfManyOptional => {
      let offset = 3.0 + stroke_width * 1.8
      let is_required = arrowhead == @graph.CfOneRequired ||
        arrowhead == @graph.CfManyRequired
      let is_many = arrowhead == @graph.CfMany ||
        arrowhead == @graph.CfManyRequired ||
        arrowhead == @graph.CfManyOptional

      let modifier = if is_required {
        @xml_emit.Element::new("path")
        .attr(
          "d",
          "M\{d2_fixed6(offset)},\{d2_fixed6(0.0)} \{d2_fixed6(offset)},\{d2_fixed6(height)}",
        )
        .attr("fill", "#FFFFFF")
        .attr("stroke", stroke)
        .attr("class", stroke_and_bg_class)
        .attr("stroke-width", stroke_width_css)
        .self_close()
        .build()
      } else {
        @xml_emit.Element::new("circle")
        .attr("r", d2_fixed6(offset / 2.0))
        .attr("cx", d2_fixed6(offset / 2.0 + 2.0))
        .attr("cy", d2_fixed6(height / 2.0))
        .attr("stroke", stroke)
        .attr("fill", "#FFFFFF")
        .attr("class", stroke_and_bg_class)
        .attr("stroke-width", stroke_width_css)
        .self_close()
        .build()
      }

      let crow_path = if is_many {
        "M\{d2_fixed6(width - 3.0)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width + offset)},\{d2_fixed6(height / 2.0)} M\{d2_fixed6(offset + 3.0)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width + offset)},\{d2_fixed6(0.0)} M\{d2_fixed6(offset + 3.0)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width + offset)},\{d2_fixed6(height)}"
      } else {
        "M\{d2_fixed6(width - 3.0)},\{d2_fixed6(height / 2.0)} \{d2_fixed6(width + offset)},\{d2_fixed6(height / 2.0)} M\{d2_fixed6(offset * 2.0)},\{d2_fixed6(0.0)} \{d2_fixed6(offset * 2.0)},\{d2_fixed6(height)}"
      }
      let crow = @xml_emit.Element::new("path")
        .attr("d", crow_path)
        .self_close()
        .build()
      let transform = if is_target {
        ""
      } else {
        "scale(-1) translate(-\{width}, -\{height})"
      }
      @xml_emit.Element::new("g")
      .attr_if("transform", transform)
      .attr("stroke", stroke)
      .attr("fill", "#FFFFFF")
      .attr("class", stroke_and_bg_class)
      .attr("stroke-width", stroke_width_css)
      .child(modifier)
      .child(crow)
      .build()
    }
  }
}

///|
fn marker_def(
  id : String,
  arrowhead : ArrowheadType,
  is_target : Bool,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
) -> String {
  let (width_raw, height_raw) = marker_dimensions(arrowhead, stroke_width)
  if width_raw <= 0.0 || height_raw <= 0.0 {
    return ""
  }
  let mut marker_width = width_raw
  let marker_height = height_raw
  let ref_x = if arrowhead == @graph.Diamond {
    if is_target {
      width_raw - 0.6 * stroke_width
    } else {
      width_raw / 8.0 + 0.6 * stroke_width
    }
  } else if is_target {
    width_raw - 1.5 * stroke_width
  } else {
    1.5 * stroke_width
  }
  if arrowhead == @graph.Diamond {
    marker_width = width_raw * 1.1
  }
  let body = marker_body(
    arrowhead, is_target, stroke, stroke_width, width_raw, marker_height, theme,
  )
  let sb = StringBuilder::new()
  sb.write_string("<marker")
  sb.write_string(" id=\"\{id}\"")
  sb.write_string(" markerWidth=\"\{d2_fixed6(marker_width)}\"")
  sb.write_string(" markerHeight=\"\{d2_fixed6(marker_height)}\"")
  sb.write_string(" refX=\"\{d2_fixed6(ref_x)}\"")
  sb.write_string(" refY=\"\{d2_fixed6(marker_height / 2.0)}\"")
  sb.write_string(
    " viewBox=\"\{d2_fixed6(0.0)} \{d2_fixed6(0.0)} \{d2_fixed6(marker_width)} \{d2_fixed6(marker_height)}\"",
  )
  sb.write_string(" orient=\"auto\"")
  sb.write_string(" markerUnits=\"userSpaceOnUse\"> ")
  sb.write_string(body)
  sb.write_string(" </marker>")
  sb.to_string()
}

///|
fn marker_url_for_edge(
  svg : @svg.Svg,
  diagram_hash : String,
  marker_ids : Map[String, String],
  arrowhead : ArrowheadType,
  is_target : Bool,
  stroke_signature : String,
  stroke_render : String,
  stroke_width : Double,
  theme : @themes.Theme,
) -> String {
  if arrowhead == @graph.None {
    return ""
  }
  let key = marker_key(arrowhead, is_target, stroke_signature, stroke_width)
  match marker_ids.get(key) {
    Some(id) => "url(#\{id})"
    None => {
      let id = marker_resource_id(
        diagram_hash, arrowhead, is_target, stroke_signature, stroke_width,
      )
      let def = marker_def(
        id, arrowhead, is_target, stroke_render, stroke_width, theme,
      )
      if def != "" {
        svg.add(def)
        marker_ids[key] = id
        "url(#\{id})"
      } else {
        ""
      }
    }
  }
}

///|
/// Add fill pattern definitions based on patterns used in the graph
fn add_fill_patterns(
  assets : SvgEmitAssets,
  graph : Diagram,
  config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> Unit {
  let _ = config
  // Collect unique patterns used
  let patterns_used : @hashset.HashSet[String] = @hashset.new()
  match style_fill_pattern_key(graph.root.style.fill_pattern) {
    Some(pattern) => patterns_used.add(pattern)
    None => ()
  }
  for obj in graph.shapes {
    match style_fill_pattern_key(obj.style.fill_pattern) {
      Some(pattern) => patterns_used.add(pattern)
      None => ()
    }
  }
  // Add pattern definitions for each used pattern
  let stroke_color = resolve_theme_color("N1", theme, use_css_theme_vars)
  let bg_color = resolve_theme_color("N7", theme, use_css_theme_vars)
  let pattern_list : Array[String] = []
  for pattern in patterns_used {
    pattern_list.push(pattern)
  }
  let overlay_rules : Array[String] = []
  pattern_list.sort()
  for pattern in pattern_list {
    match pattern {
      "dots" =>
        assets.add_def(
          @svg.dots_pattern(
            pattern_def_id(pattern, assets.diagram_hash),
            stroke_color,
            bg_color,
          ),
        )
      "lines" =>
        assets.add_def(
          @svg.lines_pattern(
            pattern_def_id(pattern, assets.diagram_hash),
            stroke_color,
            bg_color,
          ),
        )
      "crosshatch" =>
        assets.add_def(
          @svg.crosshatch_pattern(
            pattern_def_id(pattern, assets.diagram_hash),
            stroke_color,
            bg_color,
          ),
        )
      "grain" =>
        assets.add_def(
          @svg.grain_pattern(
            pattern_def_id(pattern, assets.diagram_hash),
            stroke_color,
            bg_color,
          ),
        )
      _ => ()
    }
    overlay_rules.push(
      "\n.\{pattern_overlay_class(pattern)} {\n\tfill: url(#\{pattern_def_id(pattern, assets.diagram_hash)});\n\tmix-blend-mode: multiply;\n}",
    )
  }
  if !overlay_rules.is_empty() {
    let css = overlay_rules.join("")
    assets.add_style(css)
  }
}

///|
/// Add sketch filter if any object uses sketch mode
fn add_sketch_filter(
  assets : SvgEmitAssets,
  graph : Diagram,
  config : SvgConfig,
) -> Unit {
  // Check if any object uses sketch mode
  let mut needs_sketch = config.sketch
  for obj in graph.shapes {
    if sketch_enabled(obj.style.sketch, config) {
      needs_sketch = true
      break
    }
  }
  // Also check edges
  if not(needs_sketch) {
    for edge in graph.connections {
      if sketch_enabled(edge.style.sketch, config) {
        needs_sketch = true
        break
      }
    }
  }
  if needs_sketch {
    assets.add_def(@svg.sketch_filter(defs_id(config, "sketch-filter")))
  }
}

///|
fn add_shadow_filter(assets : SvgEmitAssets, graph : Diagram) -> Unit {
  for obj in graph.shapes {
    if style_bool(obj.style.shadow, false) {
      assets.add_def(@svg.shadow_filter("shadow-filter"))
      return
    }
  }
}

///|
fn include_bounds(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
  first : Bool,
  left : Double,
  top : Double,
  right : Double,
  bottom : Double,
) -> (Double, Double, Double, Double, Bool) {
  if first {
    (left, top, right, bottom, false)
  } else {
    (
      if left < min_x {
        left
      } else {
        min_x
      },
      if top < min_y {
        top
      } else {
        min_y
      },
      if right > max_x {
        right
      } else {
        max_x
      },
      if bottom > max_y {
        bottom
      } else {
        max_y
      },
      false,
    )
  }
}

///|
fn compute_graph_bounds(
  graph : Diagram,
  config : SvgConfig,
  theme : @themes.Theme,
) -> (Double, Double, Double, Double) {
  let mut bounds = (0.0, 0.0, 0.0, 0.0, true)
  let inline_child_ids : @hashset.HashSet[String] = @hashset.new()
  for parent in graph.shapes {
    if parent.shape_type == Class || parent.shape_type == SqlTable {
      for child_id in parent.child_ids {
        inline_child_ids.add(child_id)
      }
    }
  }
  for obj in graph.shapes {
    if inline_child_ids.contains(obj.id) {
      continue
    }
    match obj.box {
      Some(b) => {
        let stroke_width = style_double(
          obj.style.stroke_width,
          config.default_stroke_width,
        )
        let half_stroke = ceil_double(stroke_width / 2.0)
        bounds = include_bounds(
          bounds.0,
          bounds.1,
          bounds.2,
          bounds.3,
          bounds.4,
          b.x - half_stroke,
          b.y - half_stroke,
          b.x + b.width + half_stroke,
          b.y + b.height + half_stroke,
        )

        if obj.shape_type == C4Person {
          let head_radius = b.width * 0.22
          let head_center_y = b.height * 0.18
          let head_top = b.y + head_center_y - head_radius
          bounds = include_bounds(
            bounds.0,
            bounds.1,
            bounds.2,
            bounds.3,
            bounds.4,
            b.x - half_stroke,
            head_top - stroke_width,
            b.x + b.width + half_stroke,
            b.y + b.height + half_stroke,
          )
        }

        let has_tooltip_icon = non_empty_string(obj.tooltip) is Some(_) &&
          obj.tooltip_position is None
        let has_link_icon = non_empty_string(obj.link) is Some(_)
        if has_tooltip_icon || has_link_icon {
          let appendix_padding = APPENDIX_ICON_RADIUS.to_double()
          bounds = include_bounds(
            bounds.0,
            bounds.1,
            bounds.2,
            bounds.3,
            bounds.4,
            b.x - half_stroke,
            b.y - stroke_width - appendix_padding,
            b.x + b.width + stroke_width + appendix_padding,
            b.y + b.height + half_stroke,
          )
        }

        match obj.tooltip_position {
          Some(_) =>
            match positioned_tooltip_bounds(obj, b, config, theme) {
              Some((min_x, min_y, max_x, max_y)) =>
                bounds = include_bounds(
                  bounds.0,
                  bounds.1,
                  bounds.2,
                  bounds.3,
                  bounds.4,
                  min_x,
                  min_y,
                  max_x,
                  max_y,
                )
              None => ()
            }
          None => ()
        }

        if style_bool(obj.style.shadow, false) {
          bounds = include_bounds(
            bounds.0,
            bounds.1,
            bounds.2,
            bounds.3,
            bounds.4,
            b.x - half_stroke,
            b.y - half_stroke,
            b.x + b.width + half_stroke + SHADOW_SIZE_X,
            b.y + b.height + half_stroke + SHADOW_SIZE_Y,
          )
        }

        if style_bool(obj.style.three_d, false) {
          let offset_y = if obj.shape_type == Hexagon {
            THREE_DEE_OFFSET / 2.0
          } else {
            THREE_DEE_OFFSET
          }
          bounds = include_bounds(
            bounds.0,
            bounds.1,
            bounds.2,
            bounds.3,
            bounds.4,
            b.x - half_stroke,
            b.y - offset_y - stroke_width,
            b.x + THREE_DEE_OFFSET + b.width + stroke_width,
            b.y + b.height + half_stroke,
          )
        }

        if style_bool(obj.style.multiple, false) {
          bounds = include_bounds(
            bounds.0,
            bounds.1,
            bounds.2,
            bounds.3,
            bounds.4,
            b.x - half_stroke,
            b.y - MULTIPLE_OFFSET - stroke_width,
            b.x + MULTIPLE_OFFSET + b.width + stroke_width,
            b.y + b.height + half_stroke,
          )
        }

        match obj.icon_position {
          Some(position) =>
            if obj.icon is Some(_) && d2_icon_position_is_outside(position) {
              let icon_size_int = d2_get_icon_size(b, position)
              let icon_size = icon_size_int.to_double()
              let icon_tl = d2_point_on_box(
                position,
                b,
                LABEL_PADDING,
                icon_size,
                icon_size,
              )
              bounds = include_bounds(
                bounds.0,
                bounds.1,
                bounds.2,
                bounds.3,
                bounds.4,
                icon_tl.x,
                icon_tl.y,
                icon_tl.x + icon_size,
                icon_tl.y + icon_size,
              )
            }
          None => ()
        }

        if obj.label != "" && has_class(obj, "lang:markdown") {
          let (label_x, label_y, label_w, label_h) = markdown_label_layout(
            obj, b,
          )
          if label_w > 0 && label_h > 0 {
            bounds = include_bounds(
              bounds.0,
              bounds.1,
              bounds.2,
              bounds.3,
              bounds.4,
              label_x,
              label_y,
              label_x + label_w.to_double(),
              label_y + label_h.to_double(),
            )
          }
        } else if obj.label != "" && !has_class(obj, "lang:latex") {
          let text_transform = if theme.rules.caps_lock {
            "uppercase"
          } else {
            style_string(obj.style.text_transform, "")
          }
          let default_font_size = default_object_font_size(obj, config)
          let font_size = match obj.style.font_size {
            Some(v) => v.as_int().unwrap_or(default_font_size)
            None => default_font_size
          }
          let is_bold = style_bool(obj.style.bold, default_object_bold(obj))
          let is_italic = style_bool(obj.style.italic, false)
          let is_mono = obj.shape_type == Code ||
            theme.rules.mono ||
            style_is_mono(obj.style.font_family)
          let label_text = transform_label_text(obj.label, text_transform)
          let (label_width, label_height) = object_label_dims(
            obj, label_text, font_size, is_mono, is_bold, is_italic,
          )
          let (label_tl_x, label_tl_y, label_box_width) = plain_object_label_layout(
            obj, b, label_width, label_height,
          )
          bounds = include_bounds(
            bounds.0,
            bounds.1,
            bounds.2,
            bounds.3,
            bounds.4,
            label_tl_x,
            label_tl_y,
            label_tl_x + label_box_width,
            label_tl_y + label_height,
          )
        }
      }
      None => ()
    }
  }
  for edge in graph.connections {
    let stroke_width = style_double(
      edge.style.stroke_width,
      config.default_stroke_width,
    )
    let half_stroke = ceil_double(stroke_width / 2.0)
    for point in edge.route {
      bounds = include_bounds(
        bounds.0,
        bounds.1,
        bounds.2,
        bounds.3,
        bounds.4,
        @math.floor(point.x) - half_stroke,
        @math.floor(point.y) - half_stroke,
        ceil_double(point.x) + half_stroke,
        ceil_double(point.y) + half_stroke,
      )
    }

    if edge.label != "" {
      match edge.label_box {
        Some(label_box) =>
          bounds = include_bounds(
            bounds.0,
            bounds.1,
            bounds.2,
            bounds.3,
            bounds.4,
            label_box.x,
            label_box.y,
            label_box.x + label_box.width,
            label_box.y + label_box.height,
          )
        None => ()
      }
    }

    let font_size = style_int(edge.style.font_size, config.font_size)
    let is_mono = theme.rules.mono || style_is_mono(edge.style.font_family)
    let is_bold = style_bool(edge.style.bold, false)
    match edge.src_arrowhead_label {
      Some(text) =>
        if text != "" {
          let dims = @text_metrics.measure_label(
            text, font_size, is_mono, is_bold, true,
          )
          match
            arrowhead_label_top_left(
              edge,
              false,
              dims.width,
              dims.height,
              stroke_width,
            ) {
            Some(label_tl) =>
              bounds = include_bounds(
                bounds.0,
                bounds.1,
                bounds.2,
                bounds.3,
                bounds.4,
                label_tl.x,
                label_tl.y,
                label_tl.x + dims.width,
                label_tl.y + dims.height,
              )
            None => ()
          }
        }
      None => ()
    }

    match edge.dst_arrowhead_label {
      Some(text) =>
        if text != "" {
          let dims = @text_metrics.measure_label(
            text, font_size, is_mono, is_bold, true,
          )
          match
            arrowhead_label_top_left(
              edge,
              true,
              dims.width,
              dims.height,
              stroke_width,
            ) {
            Some(label_tl) =>
              bounds = include_bounds(
                bounds.0,
                bounds.1,
                bounds.2,
                bounds.3,
                bounds.4,
                label_tl.x,
                label_tl.y,
                label_tl.x + dims.width,
                label_tl.y + dims.height,
              )
            None => ()
          }
        }
      None => ()
    }
  }
  // Include activation boxes (for sequence diagrams)
  for ab in graph.activation_boxes {
    let b = ab.1
    bounds = include_bounds(
      bounds.0,
      bounds.1,
      bounds.2,
      bounds.3,
      bounds.4,
      b.x,
      b.y,
      b.x + b.width,
      b.y + b.height,
    )
  }
  if bounds.4 {
    return (0.0, 0.0, 0.0, 0.0)
  }
  (bounds.0, bounds.1, bounds.2, bounds.3)
}

///|
/// Get the depth of an object ID (number of dots + 1)
fn get_object_depth(id : String) -> Int {
  @graph.syntax_path_depth(id)
}

///|
fn is_container(obj : Shape) -> Bool {
  obj.child_ids.length() > 0
}

///|
priv enum RenderObject {
  ShapeObj(Shape)
  EdgeObj(Connection)
}

///|
priv struct RenderObjectItem {
  obj : RenderObject
  original_index : Int
}

///|
fn render_object_z_index(obj : RenderObject) -> Int {
  match obj {
    ShapeObj(shape) => shape.z_index
    EdgeObj(edge) => edge.z_index
  }
}

///|
fn sort_render_objects(
  shapes : Array[Shape],
  connections : Array[Connection],
) -> Array[RenderObject] {
  // D2 parity: sort over the combined shape+connection stream:
  // 1) z-index asc
  // 2) shape vs shape: shallower(level) first
  // 3) shape before connection for same z-index
  // 4) stable by original export order
  let items : Array[RenderObjectItem] = []
  for shape in shapes {
    items.push(RenderObjectItem::{
      obj: ShapeObj(shape),
      original_index: items.length(),
    })
  }
  for connection in connections {
    items.push(RenderObjectItem::{
      obj: EdgeObj(connection),
      original_index: items.length(),
    })
  }
  items.sort_by(fn(a, b) {
    let z_a = render_object_z_index(a.obj)
    let z_b = render_object_z_index(b.obj)
    if z_a != z_b {
      return z_a - z_b
    }
    let shape_a = match a.obj {
      ShapeObj(shape) => Some(shape)
      EdgeObj(_) => None
    }
    let shape_b = match b.obj {
      ShapeObj(shape) => Some(shape)
      EdgeObj(_) => None
    }
    match shape_a {
      Some(sa) =>
        match shape_b {
          Some(sb) => {
            let level_a = get_object_depth(sa.id)
            let level_b = get_object_depth(sb.id)
            if level_a != level_b {
              return level_a - level_b
            }
            return a.original_index - b.original_index
          }
          None => return -1
        }
      None =>
        match shape_b {
          Some(_) => return 1
          None => return a.original_index - b.original_index
        }
    }
  })
  let out : Array[RenderObject] = []
  for item in items {
    out.push(item.obj)
  }
  out
}

///|
#warnings("-unused_value")
fn sort_objects_by_depth(objects : Array[Shape]) -> Array[Shape] {
  let sorted = sort_render_objects(objects, [])
  let out : Array[Shape] = []
  for item in sorted {
    match item {
      ShapeObj(shape) => out.push(shape)
      EdgeObj(_) => ()
    }
  }
  out
}

///|
fn object_children(obj : Shape, all_objects : Array[Shape]) -> Array[Shape] {
  let children : Array[Shape] = []
  for child_id in obj.child_ids {
    let mut found = false
    for candidate in all_objects {
      if not(found) && candidate.id == child_id {
        children.push(candidate)
        found = true
      }
    }
  }
  children
}

///|
fn shape_type_name(shape : ShapeType) -> String {
  match shape {
    Rectangle => "rectangle"
    Square => "square"
    Circle => "circle"
    Oval => "oval"
    Diamond => "diamond"
    Hexagon => "hexagon"
    Parallelogram => "parallelogram"
    Cylinder => "cylinder"
    Queue => "queue"
    Package => "package"
    Step => "step"
    Callout => "callout"
    StoredData => "stored_data"
    Person => "person"
    Cloud => "cloud"
    Page => "page"
    Document => "document"
    Class => "class"
    SqlTable => "sql_table"
    Text => "text"
    Code => "code"
    Image => "image"
    SequenceDiagram => "sequence_diagram"
    Octagon => "octagon"
    C4Person => "c4_person"
    C4Container => "c4_container"
  }
}

///|
/// Check if an object is a child of an inline-rendered container
/// (sql_table/class members should not be rendered as standalone shapes).
fn is_inline_container_child(obj : Shape, all_objects : Array[Shape]) -> Bool {
  // Check if object has a parent that is an sql_table or class
  // Parent ID is everything before the last dot
  let id = obj.id
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot <= 0 {
    return false // No parent
  }
  // Get parent ID
  let parent_id_buf = StringBuilder::new()
  for i = 0; i < last_dot; i = i + 1 {
    match id[i].to_char() {
      Some(c) => parent_id_buf.write_char(c)
      None => ()
    }
  }
  let parent_id = parent_id_buf.to_string()
  // Find parent object and check if it's inline-rendered
  for parent in all_objects {
    if parent.id == parent_id &&
      (parent.shape_type == SqlTable || parent.shape_type == Class) {
      return true
    }
  }
  false
}

///|
fn has_class(obj : Shape, class_name : String) -> Bool {
  for c in obj.classes {
    if c == class_name {
      return true
    }
  }
  false
}

///|
fn object_language(obj : Shape) -> String? {
  match obj.language {
    Some(language) => return Some(language)
    None => ()
  }
  for c in obj.classes {
    if c.has_prefix("lang:") {
      let tag = code_slice(c, 5, c.length())
      if tag.length() > 0 {
        return Some(tag)
      }
    }
  }
  None
}

///|
fn shape_sql_constraints(obj : Shape) -> Array[String] {
  let constraints : Array[String] = []
  for constraint in obj.sql_constraints {
    constraints.push(constraint)
  }
  if !constraints.is_empty() {
    return constraints
  }
  for cls in obj.classes {
    match strip_prefix(cls, SQL_CONSTRAINT_PREFIX) {
      Some(v) => constraints.push(v)
      None => ()
    }
  }
  constraints
}

///|
fn include_object_wrapper_class(cls : String) -> Bool {
  !cls.has_prefix("lang:")
}

///|
fn render_svg_markdown_label(svg : @svg.Svg, obj : Shape, box : Box) -> Unit {
  if obj.label == "" {
    return
  }
  let (x, y, width_px, height_px) = markdown_label_layout(obj, box)
  if width_px <= 0 || height_px <= 0 {
    return
  }
  let md_html = @cmark_html.render(safe=false, strict=false, obj.label) catch {
    _ => obj.label
  }
  let div = @xml_emit.Element::new("div")
    .attr("xmlns", "http://www.w3.org/1999/xhtml")
    .attr("class", "md color-N1")
    .raw(md_html)
    .build()
  let foreign = @xml_emit.Element::new("foreignObject")
    .attr(
      "requiredFeatures", "http://www.w3.org/TR/SVG11/feature#Extensibility",
    )
    .attr("x", d2_fixed6(x))
    .attr("y", d2_fixed6(y))
    .attr_int("width", width_px)
    .attr_int("height", height_px)
    .raw(div)
    .build()
  svg.add(@xml_emit.Element::new("g").raw(foreign).build())
}

///|
fn render_svg_object(
  svg : @svg.Svg,
  diagram_hash : String,
  appendix_items : Array[String],
  obj : Shape,
  all_objects : Array[Shape],
  config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  pass? : RenderPass = Foreground,
) -> Unit {
  guard obj.box is Some(box) else { return }
  // Skip inline-rendered children of sql_table/class.
  if is_inline_container_child(obj, all_objects) {
    return
  }
  let shape_name = shape_type_name(obj.shape_type)
  // D2 parity: most shapes are emitted in one pass (shape+label together).
  // Keep two-pass behavior only for special rich shapes.
  let use_single_pass_object = shape_name != "code" &&
    shape_name != "text" &&
    shape_name != "image"
  // For background pass, only open groups in foreground pass
  let is_foreground = match pass {
    Foreground => true
    Background => false
  }
  if use_single_pass_object && is_foreground {
    return
  }
  let object_pass_active = if use_single_pass_object {
    !is_foreground
  } else {
    is_foreground
  }
  let link_href = match obj.link {
    Some(v) => if v.trim() == "" { None } else { Some(v) }
    None => None
  }
  let has_link = link_href is Some(_)
  let should_wrap_link = has_link && object_pass_active
  let opacity_style = if style_double(obj.style.opacity, 1.0) != 1.0 {
    "opacity:\{d2_fixed6(style_double(obj.style.opacity, 1.0))}"
  } else {
    ""
  }
  let use_shadow = style_bool(obj.style.shadow, false) && object_pass_active
  let suppress_shadow_for_shape_group = shape_name == "text" ||
    shape_name == "code" ||
    shape_name == "class" ||
    shape_name == "sql_table"
  let shadow_filter = if use_shadow && !suppress_shadow_for_shape_group {
    "url(#shadow-filter)"
  } else {
    ""
  }
  if should_wrap_link {
    let href = link_href.unwrap()
    svg.add(
      @xml_emit.Element::new("a")
      .attr("href", href)
      .attr("xlink:href", href)
      .open_tag(),
    )
  }
  if object_pass_active {
    let classes : Array[String] = [d2_wrapper_class(obj.id)]
    if style_bool(obj.style.animated, false) {
      classes.push("animated-shape")
    }
    for cls in obj.classes {
      if include_object_wrapper_class(cls) {
        classes.push(cls)
      }
    }
    svg.add(d2_group_open(classes.join(" "), style=opacity_style))
    svg.add(
      d2_group_open(
        "shape",
        filter=shadow_filter,
        trailing_space_before_gt=true,
      ),
    )
  }
  // Apply sketch filter if enabled (only in foreground pass)
  let use_sketch = sketch_enabled(obj.style.sketch, config) &&
    object_pass_active
  if use_sketch {
    svg.open_group_with_filter(defs_id(config, "sketch-filter"))
  }
  // Get style values
  let raw_fill = style_string(obj.style.fill, "N7")
  let fill_class_token = d2_theme_token(raw_fill, theme)
  let base_fill = resolve_theme_color(raw_fill, theme, use_css_theme_vars)
  // Apply fill pattern if specified
  let fill = resolve_fill_with_pattern(
    base_fill,
    obj.style.fill_pattern,
    config,
    diagram_hash,
  )
  let raw_stroke = style_string(obj.style.stroke, "N1")
  let stroke_class_token = d2_theme_token(raw_stroke, theme)
  let stroke = resolve_theme_color(raw_stroke, theme, use_css_theme_vars)
  let stroke_width = style_double(
    obj.style.stroke_width,
    config.default_stroke_width,
  )
  let side_fill = resolve_theme_color(
    darken_color_like_d2(raw_fill),
    theme,
    use_css_theme_vars,
  )
  let is_multiple = style_bool(obj.style.multiple, false)
  let is_three_d = style_bool(obj.style.three_d, false)
  // Apply no_corner_radius special rule
  let border_radius = if theme.rules.no_corner_radius {
    0.0
  } else {
    style_double(obj.style.border_radius, 0.0)
  }
  // Render shape based on type
  match shape_name {
    "text" =>
      // Text shape - no border, just the label (foreground only)
      ()
    "image" =>
      // Image shape - render external image (foreground only)
      if is_foreground && obj.icon is Some(url) {
        let image_elem = StringBuilder::new()
        image_elem.write_string("<image")
        image_elem.write_string(" href=\"\{@svg.escape_xml(url)}\"")
        image_elem.write_string(" x=\"\{d2_fixed6(box.x)}\"")
        image_elem.write_string(" y=\"\{d2_fixed6(box.y)}\"")
        image_elem.write_string(" width=\"\{d2_fixed6(box.width)}\"")
        image_elem.write_string(" height=\"\{d2_fixed6(box.height)}\"")
        if !use_css_theme_vars || stroke_class_token is None {
          image_elem.write_string(" stroke=\"\{@svg.escape_xml(stroke)}\"")
        }
        if !use_css_theme_vars || fill_class_token is None {
          image_elem.write_string(" fill=\"\{@svg.escape_xml(fill)}\"")
        }
        let image_class = StringBuilder::new()
        match stroke_class_token {
          Some(token) => image_class.write_string(" stroke-\{token}")
          None => ()
        }
        match fill_class_token {
          Some(token) => image_class.write_string(" fill-\{token}")
          None => ()
        }
        let image_class_value = image_class.to_string()
        if image_class_value != "" {
          image_elem.write_string(
            " class=\"\{@svg.escape_xml(image_class_value)}\"",
          )
        }
        let stroke_width_css = if stroke_width.round() == stroke_width {
          stroke_width.to_int().to_string()
        } else {
          d2_fixed6(stroke_width)
        }
        image_elem.write_string(
          " style=\"stroke-width:\{@svg.escape_xml(stroke_width_css)};\"",
        )
        image_elem.write_string(" />")
        svg.add(image_elem.to_string())
      }
    "code" => {
      let default_font_size = default_object_font_size(obj, config)
      let font_size = match obj.style.font_size {
        Some(v) => v.as_int().unwrap_or(default_font_size)
        None => default_font_size
      }
      if object_pass_active {
        // D2 parity: code snippets are rendered outside the shape group,
        // while keeping an empty shape group for structural consistency.
        svg.close_group()
      }
      // Code shape - render in appropriate pass
      render_svg_code(
        svg,
        box,
        obj.label,
        object_language(obj),
        fill,
        stroke,
        stroke_width,
        config,
        theme,
        font_size,
        pass~,
      )
      if is_foreground {
        if use_sketch {
          svg.close_group()
        }
      }
      append_object_title(svg, obj, object_pass_active)
      if object_pass_active {
        svg.close_group()
      }
      if should_wrap_link {
        svg.add(@xml_emit.Element::new("a").close_tag())
      }
      if object_pass_active {
        append_object_appendix_icons(
          diagram_hash, appendix_items, obj, box, config, theme,
        )
      }
      return // Don't render the default label
    }
    "class" => {
      // UML class shape - render in appropriate pass
      if not(is_foreground) {
        render_svg_class(
          svg,
          box,
          obj.label,
          object_children(obj, all_objects),
          obj.style,
          fill,
          stroke,
          stroke_width,
          config,
          theme,
          use_css_theme_vars,
          pass=Background,
        )
        render_svg_class(
          svg,
          box,
          obj.label,
          object_children(obj, all_objects),
          obj.style,
          fill,
          stroke,
          stroke_width,
          config,
          theme,
          use_css_theme_vars,
          pass=Foreground,
        )
      }
      if object_pass_active {
        svg.close_group()
      }
      if is_foreground {
        if use_sketch {
          svg.close_group()
        }
      }
      append_object_title(svg, obj, object_pass_active)
      if object_pass_active {
        svg.close_group()
      }
      if should_wrap_link {
        svg.add(@xml_emit.Element::new("a").close_tag())
      }
      if object_pass_active {
        append_object_appendix_icons(
          diagram_hash, appendix_items, obj, box, config, theme,
        )
      }
      return // Don't render the default label
    }
    "sql_table" => {
      if not(is_foreground) {
        render_svg_sql_table(
          svg,
          box,
          obj.label,
          object_children(obj, all_objects),
          obj.style,
          fill,
          stroke,
          stroke_width,
          pass=Background,
          config,
          theme,
          use_css_theme_vars,
        )
        render_svg_sql_table(
          svg,
          box,
          obj.label,
          object_children(obj, all_objects),
          obj.style,
          fill,
          stroke,
          stroke_width,
          pass=Foreground,
          config,
          theme,
          use_css_theme_vars,
        )
      }
      if object_pass_active {
        svg.close_group()
      }
      if is_foreground {
        if use_sketch {
          svg.close_group()
        }
      }
      append_object_title(svg, obj, object_pass_active)
      if object_pass_active {
        svg.close_group()
      }
      if should_wrap_link {
        svg.add(@xml_emit.Element::new("a").close_tag())
      }
      if object_pass_active {
        append_object_appendix_icons(
          diagram_hash, appendix_items, obj, box, config, theme,
        )
      }
      return // Don't render the default label
    }
    "circle" | "oval" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          svg.add(
            d2_shape_ellipse(
              mbox.x + mbox.width / 2.0,
              mbox.y + mbox.height / 2.0,
              mbox.width / 2.0,
              mbox.height / 2.0,
              fill,
              stroke,
              stroke_width,
              theme,
              !use_css_theme_vars,
              fill_class_token~,
              stroke_class_token~,
            ),
          )
        }
        svg.add(
          d2_shape_ellipse(
            box.x + box.width / 2.0,
            box.y + box.height / 2.0,
            box.width / 2.0,
            box.height / 2.0,
            fill,
            stroke,
            stroke_width,
            theme,
            !use_css_theme_vars,
            fill_class_token~,
            stroke_class_token~,
          ),
        )
      }
    "cylinder" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_cylinder(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_cylinder(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "diamond" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_diamond(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_diamond(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "hexagon" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_hexagon(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_hexagon(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "octagon" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_octagon(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_octagon(svg, box, fill, stroke, stroke_width)
      }
    "parallelogram" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_parallelogram(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_parallelogram(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "person" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_person(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_person(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "c4_person" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_c4_person(
            svg,
            mbox,
            obj.label,
            fill,
            stroke,
            stroke_width,
            config,
          )
        }
        render_svg_c4_person(
          svg,
          box,
          obj.label,
          fill,
          stroke,
          stroke_width,
          config,
        )
      }
    "c4_container" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_c4_container(
            svg,
            mbox,
            obj.label,
            fill,
            stroke,
            stroke_width,
            config,
          )
        }
        render_svg_c4_container(
          svg,
          box,
          obj.label,
          fill,
          stroke,
          stroke_width,
          config,
        )
      }
    "cloud" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_cloud(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_cloud(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "document" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_document(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_document(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "queue" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_queue(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_queue(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "stored_data" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_stored_data(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_stored_data(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "page" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_page(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_page(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "package" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_package(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_package(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "step" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_step(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_step(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    "callout" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_callout(
            svg, mbox, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
            stroke_class_token,
          )
        }
        render_svg_callout(
          svg, box, fill, stroke, stroke_width, theme, use_css_theme_vars, fill_class_token,
          stroke_class_token,
        )
      }
    _ =>
      if not(is_foreground) {
        if is_three_d {
          render_svg_3d_rect(
            svg,
            diagram_hash,
            obj.id,
            box,
            fill,
            side_fill,
            stroke,
            stroke_width,
            theme,
            use_css_theme_vars,
          )
        } else {
          if is_multiple {
            let mbox = shifted_multiple_box(box)
            svg.add(
              d2_shape_rect(
                mbox.x,
                mbox.y,
                mbox.width,
                mbox.height,
                fill,
                stroke,
                stroke_width,
                border_radius,
                theme,
                !use_css_theme_vars,
                fill_class_token~,
                stroke_class_token~,
              ),
            )
          }
          svg.add(
            d2_shape_rect(
              box.x,
              box.y,
              box.width,
              box.height,
              fill,
              stroke,
              stroke_width,
              border_radius,
              theme,
              !use_css_theme_vars,
              fill_class_token~,
              stroke_class_token~,
            ),
          )
        }
      }
  }
  // Background pass: render decorations (double border, dots)
  if not(is_foreground) {
    // Add double border if specified by style or theme rule for outer containers
    let is_outer_container = is_container(obj) && not(obj.id.contains("."))
    let needs_double_border = style_bool(obj.style.double_border, false) ||
      (theme.rules.outer_container_double_border && is_outer_container)
    if needs_double_border {
      let inset = 4.0 // Gap between inner and outer border
      svg.add(
        d2_shape_rect(
          box.x + inset,
          box.y + inset,
          box.width - inset * 2.0,
          box.height - inset * 2.0,
          "none",
          stroke,
          stroke_width,
          border_radius,
          theme,
          !use_css_theme_vars,
          fill_class_token=None,
          stroke_class_token~,
        ),
      )
    }
    // Add container dots if theme rule is enabled
    if theme.rules.container_dots && is_container(obj) {
      let dot_r = 2.5
      let dot_offset = 8.0
      // Dots at each corner
      svg.add(
        @svg.circle(
          box.x + dot_offset,
          box.y + dot_offset,
          dot_r,
          fill=stroke,
          stroke="none",
        ),
      )
      svg.add(
        @svg.circle(
          box.x + box.width - dot_offset,
          box.y + dot_offset,
          dot_r,
          fill=stroke,
          stroke="none",
        ),
      )
      svg.add(
        @svg.circle(
          box.x + dot_offset,
          box.y + box.height - dot_offset,
          dot_r,
          fill=stroke,
          stroke="none",
        ),
      )
      svg.add(
        @svg.circle(
          box.x + box.width - dot_offset,
          box.y + box.height - dot_offset,
          dot_r,
          fill=stroke,
          stroke="none",
        ),
      )
    }
  }
  if object_pass_active {
    svg.close_group()
  }
  // Foreground pass: render icon and label
  if object_pass_active {
    // Check if icon is present (non-image shapes)
    let has_icon = obj.icon is Some(_) && obj.shape_type != Image
    if has_icon {
      let icon_position = obj.icon_position.unwrap_or(D2_DEFAULT_ICON_POSITION)
      let icon_box = if d2_icon_position_is_outside(icon_position) {
        box
      } else {
        shape_inner_box_for_icon(obj, box)
      }
      let icon_size_int = d2_get_icon_size(icon_box, icon_position)
      let icon_size = icon_size_int.to_double()
      let icon_url = obj.icon.unwrap()
      let icon_tl = d2_point_on_box(
        icon_position,
        icon_box,
        LABEL_PADDING,
        icon_size,
        icon_size,
      )
      svg.add(
        @xml_emit.Element::new("image")
        .attr("href", icon_url)
        .attr("x", d2_fixed6(icon_tl.x))
        .attr("y", d2_fixed6(icon_tl.y))
        .attr_int("width", icon_size_int)
        .attr_int("height", icon_size_int)
        .self_close()
        .build(),
      )
    }
    // Render label
    if obj.label != "" && has_class(obj, "lang:markdown") {
      render_svg_markdown_label(svg, obj, box)
    } else if obj.label != "" &&
      !has_class(obj, "lang:latex") &&
      !has_class(obj, "lang:markdown") {
      let text_color = style_color(
        obj.style.font_color,
        "N1",
        theme,
        use_css_theme_vars,
      )
      // Get text-transform if specified, or apply caps_lock rule
      let text_transform = if theme.rules.caps_lock {
        "uppercase"
      } else {
        style_string(obj.style.text_transform, "")
      }
      let default_font_size = default_object_font_size(obj, config)
      let font_size = match obj.style.font_size {
        Some(v) => v.as_int().unwrap_or(default_font_size)
        None => default_font_size
      }
      let is_bold = style_bool(obj.style.bold, default_object_bold(obj))
      let is_italic = style_bool(obj.style.italic, false)
      let is_mono = obj.shape_type == Code ||
        theme.rules.mono ||
        style_is_mono(obj.style.font_family)
      let label_text = transform_label_text(obj.label, text_transform)
      let (label_width, label_height) = object_label_dims(
        obj, label_text, font_size, is_mono, is_bold, is_italic,
      )
      let (label_tl_x, label_tl_y, label_box_width) = plain_object_label_layout(
        obj, box, label_width, label_height,
      )
      let label_x = label_tl_x + label_box_width / 2.0
      let label_baseline_y = label_tl_y + font_size.to_double()
      let font_class = d2_font_class_name(
        is_mono,
        is_bold,
        is_italic,
        style_bool(obj.style.underline, false),
      )
      svg.add(
        d2_text_element(
          label_x,
          label_baseline_y,
          label_text,
          label_height,
          text_color,
          font_class,
          font_size,
          theme,
          !use_css_theme_vars,
        ),
      )
    }
    // Close sketch filter group if opened
    if use_sketch {
      svg.close_group()
    }
  }
  append_object_title(svg, obj, object_pass_active)
  if object_pass_active {
    svg.close_group()
  }
  if should_wrap_link {
    svg.add(@xml_emit.Element::new("a").close_tag())
  }
  if object_pass_active {
    append_object_appendix_icons(
      diagram_hash, appendix_items, obj, box, config, theme,
    )
  }
}

///|
const SQL_TABLE_NAME_PADDING : Double = 10.0

///|
const SQL_TABLE_TYPE_PADDING : Double = 20.0

///|
const SQL_TABLE_HEADER_PADDING : Double = 10.0

///|
const SQL_TABLE_FONT_SIZE_L : Int = 20

///|
const SQL_TABLE_HEADER_FONT_ADD : Int = 4

///|
const SQL_CONSTRAINT_PREFIX : String = "sql_constraint:"

///|
fn strip_prefix(s : String, prefix : String) -> String? {
  if !s.has_prefix(prefix) {
    return None
  }
  let start = prefix.length()
  let buf = StringBuilder::new()
  for i = start; i < s.length(); i = i + 1 {
    match s[i].to_char() {
      Some(c) => buf.write_char(c)
      None => ()
    }
  }
  Some(buf.to_string())
}

///|
fn sql_table_constraint_abbr(child : Shape) -> String {
  let constraints = shape_sql_constraints(child)
  let abbrs : Array[String] = []
  for c in constraints {
    let abbr = match c {
      "primary_key" => "PK"
      "foreign_key" => "FK"
      "unique" => "UNQ"
      _ => c
    }
    abbrs.push(abbr)
  }
  abbrs.join(", ")
}

///|
fn render_svg_sql_table(
  svg : @svg.Svg,
  box : Box,
  label : String,
  children : Array[Shape],
  style : @graph.StyleInput,
  fill : String,
  stroke : String,
  stroke_width : Double,
  pass? : RenderPass = Foreground,
  _config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> Unit {
  let fill_token = d2_theme_token(style_string(style.fill, "N7"), theme)
  let stroke_token = d2_theme_token(style_string(style.stroke, "N1"), theme)
  let row_count = children.length() + 1
  let row_height = if row_count > 0 {
    box.height / row_count.to_double()
  } else {
    box.height
  }
  let base_font_size = match style.font_size {
    Some(v) => v.as_int().unwrap_or(SQL_TABLE_FONT_SIZE_L)
    None => SQL_TABLE_FONT_SIZE_L
  }
  let header_font_size = base_font_size + SQL_TABLE_HEADER_FONT_ADD
  let header_text_color = style_color(None, "N7", theme, use_css_theme_vars)
  let name_text_color = style_color(None, "B2", theme, use_css_theme_vars)
  let type_text_color = style_color(None, "N2", theme, use_css_theme_vars)
  let constraint_text_color = style_color(
    None,
    "AA2",
    theme,
    use_css_theme_vars,
  )
  let header_dims = @text_metrics.measure_label(
    label, header_font_size, false, true, false,
  )
  let mut longest_name_width = 0.0
  for child in children {
    let name = get_short_name(child.id)
    let dims = @text_metrics.measure_label(
      name, base_font_size, false, false, false,
    )
    if dims.width > longest_name_width {
      longest_name_width = dims.width
    }
  }
  match pass {
    Background => {
      let rect_classes : Array[String] = ["shape"]
      match stroke_token {
        Some(token) => rect_classes.push("stroke-\{token}")
        None => ()
      }
      match fill_token {
        Some(token) => rect_classes.push("fill-\{token}")
        None => ()
      }
      let stroke_width_css = if stroke_width.round() == stroke_width {
        stroke_width.to_int().to_string()
      } else {
        d2_fixed6(stroke_width)
      }
      svg.add(
        @xml_emit.Element::new("rect")
        .attr("x", d2_fixed6(box.x))
        .attr("y", d2_fixed6(box.y))
        .attr("width", d2_fixed6(box.width))
        .attr("height", d2_fixed6(box.height))
        .attr_if("stroke", stroke)
        .attr_if("fill", fill)
        .attr("class", rect_classes.join(" "))
        .attr("style", "stroke-width:\{stroke_width_css};")
        .self_close()
        .build(),
      )
      let header_classes : Array[String] = ["class_header"]
      match stroke_token {
        Some(token) => header_classes.push("fill-\{token}")
        None => ()
      }
      svg.add(
        @xml_emit.Element::new("rect")
        .attr("x", d2_fixed6(box.x))
        .attr("y", d2_fixed6(box.y))
        .attr("width", d2_fixed6(box.width))
        .attr("height", d2_fixed6(row_height))
        .attr_if("fill", stroke)
        .attr("class", header_classes.join(" "))
        .self_close()
        .build(),
      )

      // Header text
      let header_center_y = box.y + row_height / 2.0
      let header_text_y = header_center_y + header_dims.height / 4.0
      svg.add(
        d2_text_element(
          box.x + SQL_TABLE_HEADER_PADDING,
          header_text_y,
          label,
          header_dims.height,
          header_text_color,
          "text",
          header_font_size,
          theme,
          !use_css_theme_vars,
          text_anchor="start",
          fill_class_token=Some("N7"),
        ),
      )

      // Rows (separators + text)
      let name_x = box.x + SQL_TABLE_NAME_PADDING
      let type_x = name_x + longest_name_width + SQL_TABLE_TYPE_PADDING
      let constraint_x = box.x + box.width - SQL_TABLE_NAME_PADDING
      let mut row_top = box.y + row_height
      for child in children {
        let row_center_y = row_top + row_height / 2.0
        let text_y = row_center_y + base_font_size.to_double() / 4.0
        let col_name = get_short_name(child.id)
        svg.add(
          d2_text_element(
            name_x,
            text_y,
            col_name,
            base_font_size.to_double(),
            name_text_color,
            "text",
            base_font_size,
            theme,
            !use_css_theme_vars,
            text_anchor="start",
            fill_class_token=Some("B2"),
          ),
        )
        svg.add(
          d2_text_element(
            type_x,
            text_y,
            child.label,
            base_font_size.to_double(),
            type_text_color,
            "text",
            base_font_size,
            theme,
            !use_css_theme_vars,
            text_anchor="start",
            fill_class_token=Some("N2"),
          ),
        )
        let constraint = sql_table_constraint_abbr(child)
        svg.add(
          d2_text_element(
            constraint_x,
            text_y,
            constraint,
            base_font_size.to_double(),
            constraint_text_color,
            "text",
            base_font_size,
            theme,
            !use_css_theme_vars,
            text_anchor="end",
            fill_class_token=Some("AA2"),
          ),
        )
        row_top = row_top + row_height
        let line_class = match stroke_token {
          Some(token) => " stroke-\{token}"
          None => ""
        }
        svg.add(
          @xml_emit.Element::new("line")
          .attr("x1", d2_fixed6(box.x))
          .attr("x2", d2_fixed6(box.x + box.width))
          .attr("y1", d2_fixed6(row_top))
          .attr("y2", d2_fixed6(row_top))
          .attr_if("stroke", stroke)
          .attr_if("class", line_class)
          .attr("style", "stroke-width:2")
          .self_close()
          .build(),
        )
      }
    }
    Foreground => ()
  }
}

///|
/// Get the short name from a dotted ID (e.g., "users.id" -> "id")
fn get_short_name(id : String) -> String {
  @graph.syntax_path_last_display(id)
}

///|
const CLASS_PREFIX_PADDING : Double = 10.0

///|
const CLASS_PREFIX_WIDTH : Double = 20.0

///|
const CLASS_TYPE_PADDING : Double = 20.0

///|
const CLASS_HEADER_FONT_ADD : Int = 4

///|
priv struct ClassMember {
  visibility : String
  name : String
  type_name : String
  is_method : Bool
  underline : Bool
}

///|
fn trim_double_quotes(s : String) -> String {
  if s.length() >= 2 && s[0] == '"' && s[s.length() - 1] == '"' {
    let out = StringBuilder::new()
    for i = 1; i < s.length() - 1; i = i + 1 {
      match s[i].to_char() {
        Some(ch) => out.write_char(ch)
        None => ()
      }
    }
    out.to_string()
  } else {
    s
  }
}

///|
fn class_member_from_shape(child : Shape) -> ClassMember {
  let raw_name = get_short_name(child.id)
  let mut visibility = "+"
  let mut name = raw_name
  if raw_name.length() > 0 {
    let first = raw_name[0]
    if first == '+' || first == '-' || first == '#' {
      let vis_buf = StringBuilder::new()
      match raw_name[0].to_char() {
        Some(ch) => vis_buf.write_char(ch)
        None => ()
      }
      visibility = vis_buf.to_string()
      let name_buf = StringBuilder::new()
      for i = 1; i < raw_name.length(); i = i + 1 {
        match raw_name[i].to_char() {
          Some(ch) => name_buf.write_char(ch)
          None => ()
        }
      }
      name = name_buf.to_string()
    }
  }
  let is_method = name.contains("(")
  let raw_type = trim_double_quotes(child.label)
  let type_name = if raw_type == "" || raw_type == raw_name || raw_type == name {
    if is_method {
      "void"
    } else {
      ""
    }
  } else {
    raw_type
  }
  let underline = style_bool(child.style.underline, false)
  { visibility, name, type_name, is_method, underline }
}

///|
fn render_svg_class(
  svg : @svg.Svg,
  box : Box,
  label : String,
  children : Array[Shape],
  style : @graph.StyleInput,
  fill : String,
  stroke : String,
  stroke_width : Double,
  config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  pass? : RenderPass = Foreground,
) -> Unit {
  let members : Array[ClassMember] = []
  for child in children {
    members.push(class_member_from_shape(child))
  }
  let fields : Array[ClassMember] = []
  let methods : Array[ClassMember] = []
  for m in members {
    if m.is_method {
      methods.push(m)
    } else {
      fields.push(m)
    }
  }
  let row_height = box.height /
    (2 + fields.length() + methods.length()).to_double()
  let base_font_size = match style.font_size {
    Some(v) => v.as_int().unwrap_or(config.font_size)
    None => config.font_size
  }
  let header_font_size = base_font_size + CLASS_HEADER_FONT_ADD
  let label_dims = @text_metrics.measure_text_mono_plain(
      label, header_font_size,
    ).dimensions
  let header_height = if 2.0 * row_height >
    label_dims.height + LABEL_PADDING * 2.0 {
    2.0 * row_height
  } else {
    label_dims.height + LABEL_PADDING * 2.0
  }
  let border_radius = style_double(style.border_radius, 0.0)
  let visibility_color = style_color(None, "B2", theme, use_css_theme_vars)
  let visibility_token : String? = Some("B2")
  let name_color = style_color(None, "N1", theme, use_css_theme_vars)
  let name_token = d2_theme_token(name_color, theme)
  let type_color = style_color(None, "AA2", theme, use_css_theme_vars)
  let type_token = d2_theme_token(type_color, theme)
  let header_text_color = style_color(None, "N7", theme, use_css_theme_vars)
  let header_text_token = d2_theme_token(header_text_color, theme)
  let visibility_x = box.x + CLASS_PREFIX_PADDING
  let name_x = visibility_x + CLASS_PREFIX_WIDTH
  let type_x = box.x + box.width - CLASS_TYPE_PADDING
  match pass {
    Background => {
      svg.add(
        d2_shape_rect(
          box.x,
          box.y,
          box.width,
          box.height,
          fill,
          stroke,
          stroke_width,
          border_radius,
          theme,
          !use_css_theme_vars,
        ),
      )
      let header_fill_token = d2_theme_token(stroke, theme)
      let header_class = match header_fill_token {
        Some(token) => "class_header fill-\{token}"
        None => "class_header"
      }
      let header_rect = StringBuilder::new()
      header_rect.write_string("<rect")
      header_rect.write_string(" x=\"\{d2_fixed6(box.x)}\"")
      header_rect.write_string(" y=\"\{d2_fixed6(box.y)}\"")
      header_rect.write_string(" width=\"\{d2_fixed6(box.width)}\"")
      header_rect.write_string(" height=\"\{d2_fixed6(header_height)}\"")
      if !use_css_theme_vars || header_fill_token is None {
        header_rect.write_string(" fill=\"\{@svg.escape_xml(stroke)}\"")
      }
      if header_class != "" {
        header_rect.write_string(" class=\"\{@svg.escape_xml(header_class)}\"")
      }
      header_rect.write_string(" />")
      svg.add(header_rect.to_string())
    }
    Foreground => {
      let header_text_top = box.y + (header_height - label_dims.height) / 2.0
      let name_y = header_text_top + base_font_size.to_double()
      let header_text = StringBuilder::new()
      header_text.write_string("<text")
      header_text.write_string(" x=\"\{d2_fixed6(box.x + box.width / 2.0)}\"")
      header_text.write_string(" y=\"\{d2_fixed6(name_y)}\"")
      if !use_css_theme_vars || header_text_token is None {
        header_text.write_string(
          " fill=\"\{@svg.escape_xml(header_text_color)}\"",
        )
      }
      let header_class = match header_text_token {
        Some(token) => "text-mono fill-\{token}"
        None => "text-mono"
      }
      header_text.write_string(" class=\"\{@svg.escape_xml(header_class)}\"")
      header_text.write_string(
        " style=\"text-anchor:middle;font-size:\{header_font_size}px;\"",
      )
      header_text.write_string(">")
      header_text.write_string(@svg.escape_xml(label))
      header_text.write_string("</text>")
      svg.add(header_text.to_string())
      let mut row_top = box.y + header_height
      for m in fields {
        let text_y = row_top +
          row_height / 2.0 +
          base_font_size.to_double() / 4.0
        svg.add(
          d2_text_element(
            visibility_x,
            text_y,
            m.visibility,
            base_font_size.to_double(),
            visibility_color,
            "text-mono",
            base_font_size,
            theme,
            !use_css_theme_vars,
            text_anchor="start",
            fill_class_token=visibility_token,
          ),
        )
        let name_font_class = if m.underline {
          "text-mono text-underline"
        } else {
          "text-mono"
        }
        svg.add(
          d2_text_element(
            name_x,
            text_y,
            m.name,
            base_font_size.to_double(),
            name_color,
            name_font_class,
            base_font_size,
            theme,
            !use_css_theme_vars,
            text_anchor="start",
            fill_class_token=name_token,
          ),
        )
        if m.type_name != "" {
          svg.add(
            d2_text_element(
              type_x,
              text_y,
              m.type_name,
              base_font_size.to_double(),
              type_color,
              "text-mono",
              base_font_size,
              theme,
              !use_css_theme_vars,
              text_anchor="end",
              fill_class_token=type_token,
            ),
          )
        }
        row_top = row_top + row_height
      }
      let (sep_x1, sep_x2) = if border_radius > 0.0 && methods.is_empty() {
        (box.x + border_radius, box.x + box.width - border_radius)
      } else {
        (box.x, box.x + box.width)
      }
      let line_token = d2_theme_token(name_color, theme)
      let line_class = match line_token {
        Some(token) => " stroke-\{token}"
        None => ""
      }
      let line = StringBuilder::new()
      line.write_string("<line")
      line.write_string(" x1=\"\{d2_fixed6(sep_x1)}\"")
      line.write_string(" x2=\"\{d2_fixed6(sep_x2)}\"")
      line.write_string(" y1=\"\{d2_fixed6(row_top)}\"")
      line.write_string(" y2=\"\{d2_fixed6(row_top)}\"")
      if !use_css_theme_vars || line_token is None {
        line.write_string(" stroke=\"\{@svg.escape_xml(name_color)}\"")
      }
      if line_class != "" {
        line.write_string(" class=\"\{@svg.escape_xml(line_class)}\"")
      }
      line.write_string(" style=\"stroke-width:1\"")
      line.write_string(" />")
      svg.add(line.to_string())
      for m in methods {
        let text_y = row_top +
          row_height / 2.0 +
          base_font_size.to_double() / 4.0
        svg.add(
          d2_text_element(
            visibility_x,
            text_y,
            m.visibility,
            base_font_size.to_double(),
            visibility_color,
            "text-mono",
            base_font_size,
            theme,
            !use_css_theme_vars,
            text_anchor="start",
            fill_class_token=visibility_token,
          ),
        )
        let name_font_class = if m.underline {
          "text-mono text-underline"
        } else {
          "text-mono"
        }
        svg.add(
          d2_text_element(
            name_x,
            text_y,
            m.name,
            base_font_size.to_double(),
            name_color,
            name_font_class,
            base_font_size,
            theme,
            !use_css_theme_vars,
            text_anchor="start",
            fill_class_token=name_token,
          ),
        )
        if m.type_name != "" {
          svg.add(
            d2_text_element(
              type_x,
              text_y,
              m.type_name,
              base_font_size.to_double(),
              type_color,
              "text-mono",
              base_font_size,
              theme,
              !use_css_theme_vars,
              text_anchor="end",
              fill_class_token=type_token,
            ),
          )
        }
        row_top = row_top + row_height
      }
    }
  }
}

///|
fn render_svg_code(
  svg : @svg.Svg,
  box : Box,
  label : String,
  language : String?,
  _fill : String,
  stroke : String,
  stroke_width : Double,
  _config : SvgConfig,
  theme : @themes.Theme,
  font_size : Int,
  pass? : RenderPass = Foreground,
) -> Unit {
  // D2 parity: render both light and dark code groups and switch visibility via CSS.
  let code_bgs = [("light-code", "#ffffff"), ("dark-code", "#1e1e2e")]
  // D2 parity: code block has 0.5em inner padding.
  let padding = font_size.to_double() / 2.0
  match pass {
    Background => ()
    Foreground => {
      let lines = split_lines(label)
      for code_bg in code_bgs {
        let code_group = @xml_emit.Element::new("g")
          .attr(
            "transform",
            "translate(\{d2_fixed6(box.x)} \{d2_fixed6(box.y)})",
          )
          .attr("class", code_bg.0)
        if font_size != 16 {
          svg.add(code_group.attr("style", "font-size:\{font_size}").open_tag())
        } else {
          svg.add(code_group.open_tag())
        }
        svg.add(
          @xml_emit.Element::new("rect")
          .attr("width", d2_fixed6(box.width))
          .attr("height", d2_fixed6(box.height))
          .attr("stroke", stroke)
          .attr(
            "class",
            match d2_theme_token(stroke, theme) {
              Some(token) => "shape stroke-\{token}"
              None => "shape"
            },
          )
          .attr("style", "fill:\{code_bg.1};stroke-width:\{stroke_width};")
          .self_close()
          .build(),
        )
        svg.open_group("translate(\{d2_fixed6(padding)} \{d2_fixed6(padding)})")
        for i, line in lines {
          let y_em = "\{d2_fixed6(1.0 + i.to_double() * 1.3)}em"
          let raw = code_line_svg_raw(line, language, code_bg.0 == "dark-code")
          let raw_with_newline = if code_bg.0 == "dark-code" {
            let prefixed = if i > 0 {
              "<tspan fill=\"#cdd6f4\"></tspan>" + raw
            } else {
              raw
            }
            if i + 1 < lines.length() {
              prefixed + "<tspan fill=\"#cdd6f4\">\n</tspan>"
            } else {
              prefixed
            }
          } else if i + 1 < lines.length() {
            raw + "\n"
          } else {
            raw
          }
          let text = @xml_emit.Element::new("text")
            .attr("class", "text-mono")
            .attr("x", "0")
            .attr("y", y_em)
            .raw(raw_with_newline)
            .build()
          svg.add(text)
        }
        svg.close_group()
        svg.add(@xml_emit.Element::new("g").close_tag())
      }
    }
  }
}

///|
priv enum CodeTokenKind {
  Text
  Comment
  Keyword
  KeywordType
  NameFunction
  NameBuiltin
  NameClass
  NameAttribute
  NameTag
  LiteralString
  LiteralStringEscape
  LiteralNumber
  Operator
  OperatorWord
  Punctuation
  Bracket
}

///|
priv enum CodeLanguage {
  Unknown
  Go
  JavaScript
  TypeScript
  Python
  Rust
  Java
  C
  Cpp
  CSharp
  Kotlin
  Swift
  Php
  Ruby
  Bash
  Sql
  Json
  Yaml
  Toml
  Html
  Xml
  Markdown
  MoonBit
} derive(Eq)

///|
priv struct CodeToken {
  text : String
  kind : CodeTokenKind
}

///|
fn CodeToken::new(text : String, kind : CodeTokenKind) -> CodeToken {
  { text, kind }
}

///|
fn code_line_svg_raw(
  line : String,
  language : String?,
  is_dark : Bool,
) -> String {
  let normalized = code_language_from_tag(language)
  let sb = StringBuilder::new()
  for token in code_tokenize_line(line, normalized) {
    code_write_span(
      sb,
      token.text,
      code_token_fill(token.kind, is_dark),
      code_token_class(token.kind, is_dark),
    )
  }
  sb.to_string()
}

///|
fn code_tokenize_line(
  line : String,
  language : CodeLanguage,
) -> Array[CodeToken] {
  if line.length() == 0 {
    return []
  }
  if language == Html || language == Xml {
    return code_tokenize_markup_line(line)
  }
  let out : Array[CodeToken] = []
  let mut i = 0
  while i < line.length() {
    match char_at(line, i) {
      Some(c) =>
        if c == ' ' || c == '\t' {
          let start = i
          i = code_consume_while(line, i, fn(ch) { ch == ' ' || ch == '\t' })
          out.push(CodeToken::new(code_slice(line, start, i), Text))
        } else {
          match code_line_comment_prefix_len(line, i, language) {
            Some(prefix_len) => {
              let comment = code_slice(line, i, line.length())
              out.push(CodeToken::new(comment, Comment))
              i = line.length()
              ignore(prefix_len)
            }
            None =>
              match code_block_comment_bounds(line, i, language) {
                Some(end_index) => {
                  out.push(
                    CodeToken::new(code_slice(line, i, end_index), Comment),
                  )
                  i = end_index
                }
                None =>
                  match code_string_bounds(line, i, language) {
                    Some((end_index, has_escape)) => {
                      if has_escape {
                        code_push_string_with_escapes(
                          out,
                          code_slice(line, i, end_index),
                        )
                      } else {
                        out.push(
                          CodeToken::new(
                            code_slice(line, i, end_index),
                            LiteralString,
                          ),
                        )
                      }
                      i = end_index
                    }
                    None =>
                      if code_is_number_start(line, i) {
                        let end_index = code_number_end(line, i)
                        out.push(
                          CodeToken::new(
                            code_slice(line, i, end_index),
                            LiteralNumber,
                          ),
                        )
                        i = end_index
                      } else if code_is_ident_start(c) {
                        let start = i
                        i = code_consume_while(
                          line,
                          i + 1,
                          code_is_ident_continue,
                        )
                        let ident = code_slice(line, start, i)
                        let prev_non_space = code_prev_non_space_char(
                          line,
                          start - 1,
                        )
                        let next_non_space = code_next_non_space_char(line, i)
                        let kind = code_ident_kind(
                          ident, language, prev_non_space, next_non_space,
                        )
                        out.push(CodeToken::new(ident, kind))
                      } else if code_is_operator_char(c) {
                        let end_index = code_operator_end(line, i)
                        let op = code_slice(line, i, end_index)
                        out.push(CodeToken::new(op, Operator))
                        i = end_index
                      } else if code_is_punctuation_char(c) {
                        let token_kind = if language == MoonBit &&
                          code_is_bracket_char(c) {
                          Bracket
                        } else {
                          Punctuation
                        }
                        out.push(
                          CodeToken::new(code_slice(line, i, i + 1), token_kind),
                        )
                        i = i + 1
                      } else {
                        out.push(
                          CodeToken::new(code_slice(line, i, i + 1), Text),
                        )
                        i = i + 1
                      }
                  }
              }
          }
        }
      None => i = i + 1
    }
  }
  out
}

///|
fn code_tokenize_markup_line(line : String) -> Array[CodeToken] {
  let out : Array[CodeToken] = []
  let mut i = 0
  while i < line.length() {
    if code_starts_with_at(line, i, "<!--") {
      let end_index = code_find_substring_from(line, "-->", i + 4)
      let end = match end_index {
        Some(v) => v + 3
        None => line.length()
      }
      out.push(CodeToken::new(code_slice(line, i, end), Comment))
      i = end
      continue
    }
    match char_at(line, i) {
      Some('<') => {
        if code_starts_with_at(line, i, "</") {
          out.push(CodeToken::new("</", Punctuation))
          i = i + 2
        } else {
          out.push(CodeToken::new("<", Punctuation))
          i = i + 1
        }
        let tag_start = i
        i = code_consume_while(line, i, code_is_tag_ident_continue)
        if i > tag_start {
          out.push(CodeToken::new(code_slice(line, tag_start, i), NameTag))
        }
        while i < line.length() {
          match char_at(line, i) {
            Some('>') => {
              out.push(CodeToken::new(">", Punctuation))
              i = i + 1
              break
            }
            Some(' ') | Some('\t') => {
              let start = i
              i = code_consume_while(line, i, fn(ch) { ch == ' ' || ch == '\t' })
              out.push(CodeToken::new(code_slice(line, start, i), Text))
            }
            Some('=') => {
              out.push(CodeToken::new("=", Operator))
              i = i + 1
            }
            Some('"') | Some('\'') =>
              match code_string_bounds(line, i, Xml) {
                Some((end_index, has_escape)) => {
                  if has_escape {
                    code_push_string_with_escapes(
                      out,
                      code_slice(line, i, end_index),
                    )
                  } else {
                    out.push(
                      CodeToken::new(
                        code_slice(line, i, end_index),
                        LiteralString,
                      ),
                    )
                  }
                  i = end_index
                }
                None => {
                  out.push(
                    CodeToken::new(code_slice(line, i, i + 1), LiteralString),
                  )
                  i = i + 1
                }
              }
            Some('/') => {
              out.push(CodeToken::new("/", Punctuation))
              i = i + 1
            }
            Some(_) => {
              let start = i
              i = code_consume_while(line, i, code_is_tag_ident_continue)
              if i > start {
                out.push(
                  CodeToken::new(code_slice(line, start, i), NameAttribute),
                )
              } else {
                out.push(CodeToken::new(code_slice(line, i, i + 1), Text))
                i = i + 1
              }
            }
            None => break
          }
        }
      }
      Some(_) => {
        let start = i
        i = code_consume_until_char(line, i, '<')
        out.push(CodeToken::new(code_slice(line, start, i), Text))
      }
      None => i = i + 1
    }
  }
  out
}

///|
fn code_push_string_with_escapes(
  out : Array[CodeToken],
  quoted : String,
) -> Unit {
  if quoted.length() == 0 {
    return
  }
  let mut i = 0
  let mut segment_start = 0
  while i < quoted.length() {
    match char_at(quoted, i) {
      Some('\\') => {
        if i > segment_start {
          out.push(
            CodeToken::new(code_slice(quoted, segment_start, i), LiteralString),
          )
        }
        let escape_end = if i + 1 < quoted.length() { i + 2 } else { i + 1 }
        out.push(
          CodeToken::new(code_slice(quoted, i, escape_end), LiteralStringEscape),
        )
        i = escape_end
        segment_start = i
      }
      Some(_) => i = i + 1
      None => i = i + 1
    }
  }
  if segment_start < quoted.length() {
    out.push(
      CodeToken::new(
        code_slice(quoted, segment_start, quoted.length()),
        LiteralString,
      ),
    )
  }
}

///|
fn code_language_from_tag(language : String?) -> CodeLanguage {
  match language {
    Some(raw) =>
      match raw.to_lower() {
        "go" | "golang" => Go
        "js" | "jsx" | "javascript" | "node" => JavaScript
        "ts" | "tsx" | "typescript" => TypeScript
        "py" | "python" | "python3" => Python
        "rs" | "rust" => Rust
        "java" => Java
        "c" => C
        "cpp" | "c++" | "cc" | "cxx" => Cpp
        "cs" | "csharp" | "c#" => CSharp
        "kt" | "kotlin" => Kotlin
        "swift" => Swift
        "php" => Php
        "rb" | "ruby" => Ruby
        "bash" | "shell" | "sh" | "zsh" => Bash
        "sql" | "postgres" | "postgresql" | "mysql" => Sql
        "json" | "jsonc" => Json
        "yaml" | "yml" => Yaml
        "toml" => Toml
        "html" | "xhtml" => Html
        "xml" | "svg" => Xml
        "markdown" | "md" => Markdown
        "moonbit" | "mbt" => MoonBit
        _ => Unknown
      }
    None => Unknown
  }
}

///|
fn code_ident_kind(
  ident : String,
  language : CodeLanguage,
  prev_non_space : Char?,
  next_non_space : Char?,
) -> CodeTokenKind {
  if language == MoonBit {
    if code_is_keyword(ident, language) {
      return Keyword
    }
    return Text
  }
  if code_is_operator_word(ident, language) {
    return OperatorWord
  }
  if code_is_keyword(ident, language) {
    return Keyword
  }
  if code_is_keyword_type(ident, language) {
    return KeywordType
  }
  if code_is_builtin(ident, language) {
    return NameBuiltin
  }
  if next_non_space == Some('(') && !code_is_call_control_word(ident, language) {
    return NameFunction
  }
  if language == Html || language == Xml {
    if prev_non_space == Some('<') || prev_non_space == Some('/') {
      return NameTag
    }
  }
  if language != Go && code_is_probable_class_name(ident, language) {
    return NameClass
  }
  Text
}

///|
fn code_is_keyword(word : String, language : CodeLanguage) -> Bool {
  match language {
    Go =>
      match word {
        "break"
        | "case"
        | "chan"
        | "const"
        | "continue"
        | "default"
        | "defer"
        | "else"
        | "fallthrough"
        | "for"
        | "func"
        | "go"
        | "goto"
        | "if"
        | "import"
        | "interface"
        | "map"
        | "package"
        | "range"
        | "return"
        | "select"
        | "struct"
        | "switch"
        | "type"
        | "var" => true
        _ => false
      }
    JavaScript | TypeScript =>
      match word {
        "as"
        | "async"
        | "await"
        | "break"
        | "case"
        | "catch"
        | "class"
        | "const"
        | "continue"
        | "debugger"
        | "default"
        | "delete"
        | "do"
        | "else"
        | "export"
        | "extends"
        | "finally"
        | "for"
        | "from"
        | "function"
        | "if"
        | "import"
        | "in"
        | "instanceof"
        | "new"
        | "of"
        | "return"
        | "switch"
        | "throw"
        | "try"
        | "typeof"
        | "var"
        | "void"
        | "while"
        | "with"
        | "yield"
        | "let"
        | "implements"
        | "interface"
        | "namespace"
        | "private"
        | "protected"
        | "public"
        | "readonly"
        | "static"
        | "enum"
        | "declare" => true
        _ => false
      }
    Python =>
      match word {
        "and"
        | "as"
        | "assert"
        | "async"
        | "await"
        | "break"
        | "class"
        | "continue"
        | "def"
        | "del"
        | "elif"
        | "else"
        | "except"
        | "finally"
        | "for"
        | "from"
        | "global"
        | "if"
        | "import"
        | "in"
        | "is"
        | "lambda"
        | "nonlocal"
        | "not"
        | "or"
        | "pass"
        | "raise"
        | "return"
        | "try"
        | "while"
        | "with"
        | "yield" => true
        _ => false
      }
    Rust =>
      match word {
        "as"
        | "async"
        | "await"
        | "break"
        | "const"
        | "continue"
        | "crate"
        | "else"
        | "enum"
        | "extern"
        | "fn"
        | "for"
        | "if"
        | "impl"
        | "in"
        | "let"
        | "loop"
        | "match"
        | "mod"
        | "move"
        | "mut"
        | "pub"
        | "ref"
        | "return"
        | "self"
        | "Self"
        | "static"
        | "struct"
        | "super"
        | "trait"
        | "type"
        | "unsafe"
        | "use"
        | "where"
        | "while" => true
        _ => false
      }
    Java | C | Cpp | CSharp | Kotlin | Swift =>
      match word {
        "abstract"
        | "break"
        | "case"
        | "catch"
        | "class"
        | "const"
        | "continue"
        | "default"
        | "do"
        | "else"
        | "enum"
        | "extends"
        | "final"
        | "finally"
        | "for"
        | "if"
        | "implements"
        | "import"
        | "interface"
        | "new"
        | "override"
        | "package"
        | "private"
        | "protected"
        | "public"
        | "return"
        | "static"
        | "struct"
        | "switch"
        | "throw"
        | "throws"
        | "try"
        | "using"
        | "var"
        | "virtual"
        | "while" => true
        _ => false
      }
    Php =>
      match word {
        "abstract"
        | "as"
        | "break"
        | "case"
        | "catch"
        | "class"
        | "const"
        | "continue"
        | "declare"
        | "default"
        | "do"
        | "echo"
        | "else"
        | "elseif"
        | "extends"
        | "final"
        | "for"
        | "foreach"
        | "function"
        | "if"
        | "implements"
        | "interface"
        | "namespace"
        | "new"
        | "private"
        | "protected"
        | "public"
        | "return"
        | "static"
        | "switch"
        | "throw"
        | "trait"
        | "try"
        | "use"
        | "while" => true
        _ => false
      }
    Ruby =>
      match word {
        "BEGIN"
        | "END"
        | "alias"
        | "and"
        | "begin"
        | "break"
        | "case"
        | "class"
        | "def"
        | "defined?"
        | "do"
        | "else"
        | "elsif"
        | "end"
        | "ensure"
        | "for"
        | "if"
        | "in"
        | "module"
        | "next"
        | "or"
        | "redo"
        | "rescue"
        | "retry"
        | "return"
        | "super"
        | "then"
        | "undef"
        | "unless"
        | "until"
        | "when"
        | "while"
        | "yield" => true
        _ => false
      }
    Bash =>
      match word {
        "if"
        | "then"
        | "else"
        | "elif"
        | "fi"
        | "for"
        | "while"
        | "until"
        | "do"
        | "done"
        | "case"
        | "esac"
        | "function"
        | "select"
        | "in" => true
        _ => false
      }
    Sql =>
      match word.to_upper() {
        "SELECT"
        | "FROM"
        | "WHERE"
        | "JOIN"
        | "LEFT"
        | "RIGHT"
        | "INNER"
        | "OUTER"
        | "ON"
        | "GROUP"
        | "BY"
        | "ORDER"
        | "LIMIT"
        | "OFFSET"
        | "INSERT"
        | "INTO"
        | "VALUES"
        | "UPDATE"
        | "SET"
        | "DELETE"
        | "CREATE"
        | "TABLE"
        | "ALTER"
        | "DROP"
        | "INDEX"
        | "VIEW"
        | "DISTINCT"
        | "HAVING"
        | "UNION"
        | "ALL"
        | "AS"
        | "AND"
        | "OR"
        | "NOT"
        | "IN"
        | "EXISTS"
        | "BETWEEN"
        | "LIKE"
        | "IS"
        | "NULL" => true
        _ => false
      }
    Json | Yaml | Toml =>
      match word {
        "true" | "false" | "null" | "none" => true
        _ => false
      }
    MoonBit =>
      match word {
        "as"
        | "else"
        | "extern"
        | "fn"
        | "fnalias"
        | "if"
        | "let"
        | "const"
        | "match"
        | "using"
        | "mut"
        | "type"
        | "typealias"
        | "struct"
        | "enum"
        | "trait"
        | "traitalias"
        | "derive"
        | "while"
        | "break"
        | "continue"
        | "import"
        | "return"
        | "throw"
        | "raise"
        | "try"
        | "catch"
        | "pub"
        | "priv"
        | "readonly"
        | "true"
        | "false"
        | "_"
        | "test"
        | "loop"
        | "for"
        | "in"
        | "impl"
        | "with"
        | "guard"
        | "async"
        | "is"
        | "suberror"
        | "and"
        | "letrec"
        | "enumview"
        | "noraise"
        | "defer"
        | "where" => true
        _ => false
      }
    _ => false
  }
}

///|
fn code_is_keyword_type(word : String, language : CodeLanguage) -> Bool {
  match language {
    Go =>
      match word {
        "any"
        | "bool"
        | "byte"
        | "comparable"
        | "complex64"
        | "complex128"
        | "error"
        | "float32"
        | "float64"
        | "int"
        | "int8"
        | "int16"
        | "int32"
        | "int64"
        | "rune"
        | "string"
        | "uint"
        | "uint8"
        | "uint16"
        | "uint32"
        | "uint64"
        | "uintptr" => true
        _ => false
      }
    Java | C | Cpp | CSharp | Kotlin | Swift =>
      match word {
        "bool"
        | "boolean"
        | "byte"
        | "char"
        | "double"
        | "float"
        | "int"
        | "long"
        | "short"
        | "string"
        | "void"
        | "var" => true
        _ => false
      }
    TypeScript =>
      match word {
        "any"
        | "bigint"
        | "boolean"
        | "never"
        | "number"
        | "object"
        | "string"
        | "symbol"
        | "unknown"
        | "void" => true
        _ => false
      }
    Python =>
      match word {
        "bool"
        | "bytes"
        | "dict"
        | "float"
        | "int"
        | "list"
        | "set"
        | "str"
        | "tuple" => true
        _ => false
      }
    Rust =>
      match word {
        "bool"
        | "char"
        | "f32"
        | "f64"
        | "i8"
        | "i16"
        | "i32"
        | "i64"
        | "i128"
        | "isize"
        | "str"
        | "u8"
        | "u16"
        | "u32"
        | "u64"
        | "u128"
        | "usize" => true
        _ => false
      }
    Sql =>
      match word.to_upper() {
        "BIGINT"
        | "BOOLEAN"
        | "CHAR"
        | "DATE"
        | "DECIMAL"
        | "FLOAT"
        | "INT"
        | "INTEGER"
        | "NUMERIC"
        | "TEXT"
        | "TIMESTAMP"
        | "UUID"
        | "VARCHAR" => true
        _ => false
      }
    _ => false
  }
}

///|
fn code_is_builtin(word : String, language : CodeLanguage) -> Bool {
  match language {
    Go =>
      match word {
        "append"
        | "cap"
        | "clear"
        | "close"
        | "complex"
        | "copy"
        | "delete"
        | "imag"
        | "len"
        | "make"
        | "max"
        | "min"
        | "new"
        | "panic"
        | "print"
        | "println"
        | "real"
        | "recover" => true
        _ => false
      }
    JavaScript | TypeScript =>
      match word {
        "Array"
        | "Boolean"
        | "Date"
        | "Error"
        | "JSON"
        | "Map"
        | "Math"
        | "Number"
        | "Object"
        | "Promise"
        | "RegExp"
        | "Set"
        | "String"
        | "console"
        | "parseFloat"
        | "parseInt" => true
        _ => false
      }
    Python =>
      match word {
        "abs"
        | "all"
        | "any"
        | "dict"
        | "enumerate"
        | "filter"
        | "int"
        | "len"
        | "list"
        | "map"
        | "max"
        | "min"
        | "print"
        | "range"
        | "set"
        | "str"
        | "sum"
        | "tuple" => true
        _ => false
      }
    Rust =>
      match word {
        "Option"
        | "Result"
        | "String"
        | "Vec"
        | "format"
        | "panic"
        | "println" => true
        _ => false
      }
    Java | CSharp | Kotlin =>
      match word {
        "System" | "String" | "println" | "printf" => true
        _ => false
      }
    Bash =>
      match word {
        "echo" | "export" | "printf" | "read" | "source" | "test" => true
        _ => false
      }
    Sql =>
      match word.to_upper() {
        "COUNT" | "MAX" | "MIN" | "AVG" | "SUM" | "NOW" | "COALESCE" => true
        _ => false
      }
    _ => false
  }
}

///|
fn code_is_operator_word(word : String, language : CodeLanguage) -> Bool {
  match language {
    Python =>
      match word {
        "and" | "is" | "not" | "or" => true
        _ => false
      }
    Sql =>
      match word.to_upper() {
        "AND" | "OR" | "NOT" => true
        _ => false
      }
    _ => false
  }
}

///|
fn code_is_probable_class_name(word : String, language : CodeLanguage) -> Bool {
  if word.length() == 0 {
    return false
  }
  if language == Sql || language == Json || language == Yaml || language == Toml {
    return false
  }
  match char_at(word, 0) {
    Some(c) => c >= 'A' && c <= 'Z'
    None => false
  }
}

///|
fn code_is_call_control_word(word : String, language : CodeLanguage) -> Bool {
  if code_is_keyword(word, language) || code_is_keyword_type(word, language) {
    return true
  }
  match word {
    "assert" | "await" | "sizeof" | "typeof" => true
    _ => false
  }
}

///|
fn code_line_comment_prefix_len(
  line : String,
  index : Int,
  language : CodeLanguage,
) -> Int? {
  match language {
    Go
    | JavaScript
    | TypeScript
    | Rust
    | Java
    | C
    | Cpp
    | CSharp
    | Kotlin
    | Swift
    | Php
    | MoonBit =>
      if code_starts_with_at(line, index, "//") {
        Some(2)
      } else {
        None
      }
    Python | Ruby | Bash | Yaml | Toml =>
      if code_starts_with_at(line, index, "#") {
        Some(1)
      } else {
        None
      }
    Sql => if code_starts_with_at(line, index, "--") { Some(2) } else { None }
    _ => None
  }
}

///|
fn code_block_comment_bounds(
  line : String,
  index : Int,
  language : CodeLanguage,
) -> Int? {
  let supports = match language {
    Go
    | JavaScript
    | TypeScript
    | Rust
    | Java
    | C
    | Cpp
    | CSharp
    | Kotlin
    | Swift
    | Php
    | MoonBit
    | Sql => true
    _ => false
  }
  if !supports || !code_starts_with_at(line, index, "/*") {
    return None
  }
  match code_find_substring_from(line, "*/", index + 2) {
    Some(end_index) => Some(end_index + 2)
    None => Some(line.length())
  }
}

///|
fn code_string_bounds(
  line : String,
  index : Int,
  language : CodeLanguage,
) -> (Int, Bool)? {
  if index >= line.length() {
    return None
  }
  if language == Python {
    if code_starts_with_at(line, index, "\"\"\"") ||
      code_starts_with_at(line, index, "'''") {
      let triple = code_slice(line, index, index + 3)
      let end = code_find_substring_from(line, triple, index + 3)
      let triple_end = match end {
        Some(v) => v + 3
        None => line.length()
      }
      return Some((triple_end, true))
    }
  }
  match char_at(line, index) {
    Some('"') => code_parse_quoted_string(line, index, language, '"')
    Some('\'') => code_parse_quoted_string(line, index, language, '\'')
    Some('`') =>
      if code_language_supports_backtick(language) {
        code_parse_quoted_string(line, index, language, '`')
      } else {
        None
      }
    _ => None
  }
}

///|
fn code_parse_quoted_string(
  line : String,
  index : Int,
  language : CodeLanguage,
  quote_char : Char,
) -> (Int, Bool)? {
  let mut i = index + 1
  let mut has_escape = false
  while i < line.length() {
    match char_at(line, i) {
      Some('\\') =>
        if quote_char != '`' && language != Markdown {
          has_escape = true
          if i + 1 < line.length() {
            i = i + 2
          } else {
            i = i + 1
          }
        } else {
          i = i + 1
        }
      Some(c) =>
        if c == quote_char {
          return Some((i + 1, has_escape))
        } else {
          i = i + 1
        }
      None => i = i + 1
    }
  }
  Some((line.length(), has_escape))
}

///|
fn code_language_supports_backtick(language : CodeLanguage) -> Bool {
  match language {
    Go | JavaScript | TypeScript | Bash | Markdown => true
    _ => false
  }
}

///|
fn code_is_number_start(line : String, index : Int) -> Bool {
  if index >= line.length() {
    return false
  }
  match char_at(line, index) {
    Some(c) =>
      if c >= '0' && c <= '9' {
        true
      } else if c == '.' && index + 1 < line.length() {
        match char_at(line, index + 1) {
          Some(n) => n >= '0' && n <= '9'
          None => false
        }
      } else {
        false
      }
    None => false
  }
}

///|
fn code_number_end(line : String, start : Int) -> Int {
  let mut i = start
  let mut seen_dot = false
  let mut seen_exp = false
  while i < line.length() {
    match char_at(line, i) {
      Some(c) =>
        if c >= '0' && c <= '9' {
          i = i + 1
        } else if c == '_' {
          i = i + 1
        } else if c == '.' && !seen_dot && !seen_exp {
          seen_dot = true
          i = i + 1
        } else if (c == 'e' || c == 'E') && !seen_exp {
          seen_exp = true
          i = i + 1
          if i < line.length() {
            match char_at(line, i) {
              Some('+') | Some('-') => i = i + 1
              _ => ()
            }
          }
        } else {
          break
        }
      None => break
    }
  }
  i
}

///|
fn code_is_operator_char(c : Char) -> Bool {
  match c {
    '+'
    | '-'
    | '*'
    | '/'
    | '%'
    | '='
    | '!'
    | '<'
    | '>'
    | '&'
    | '|'
    | '^'
    | '~'
    | ':'
    | '?' => true
    _ => false
  }
}

///|
fn code_operator_end(line : String, start : Int) -> Int {
  code_consume_while(line, start, code_is_operator_char)
}

///|
fn code_is_punctuation_char(c : Char) -> Bool {
  match c {
    '(' | ')' | '[' | ']' | '{' | '}' | ',' | '.' | ';' => true
    _ => false
  }
}

///|
fn code_is_bracket_char(c : Char) -> Bool {
  match c {
    '(' | ')' | '[' | ']' | '{' | '}' => true
    _ => false
  }
}

///|
fn code_consume_while(
  s : String,
  start : Int,
  predicate : (Char) -> Bool,
) -> Int {
  let mut i = start
  while i < s.length() {
    match char_at(s, i) {
      Some(c) => if predicate(c) { i = i + 1 } else { break }
      None => break
    }
  }
  i
}

///|
fn code_consume_until_char(s : String, start : Int, ch : Char) -> Int {
  let mut i = start
  while i < s.length() {
    if char_at(s, i) == Some(ch) {
      break
    }
    i = i + 1
  }
  i
}

///|
fn code_starts_with_at(s : String, index : Int, prefix : String) -> Bool {
  if index < 0 || index + prefix.length() > s.length() {
    return false
  }
  code_slice(s, index, index + prefix.length()) == prefix
}

///|
fn code_find_substring_from(s : String, needle : String, start : Int) -> Int? {
  if needle.length() == 0 || start >= s.length() {
    return None
  }
  let mut i = if start < 0 { 0 } else { start }
  while i + needle.length() <= s.length() {
    if code_starts_with_at(s, i, needle) {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn code_is_tag_ident_continue(c : Char) -> Bool {
  code_is_ident_continue(c) || c == '-' || c == ':' || c == '_'
}

///|
fn code_token_fill(kind : CodeTokenKind, is_dark : Bool) -> String? {
  if is_dark {
    match kind {
      Text | Punctuation => Some("#cdd6f4")
      Bracket => Some("#89b4fa")
      Comment => Some("#6c7086")
      Keyword => Some("#cba6f7")
      KeywordType => Some("#f38ba8")
      NameFunction => Some("#89b4fa")
      NameBuiltin => Some("#89dceb")
      NameClass => Some("#f9e2af")
      NameAttribute => Some("#89b4fa")
      NameTag => Some("#cba6f7")
      LiteralString => Some("#a6e3a1")
      LiteralStringEscape => Some("#89b4fa")
      LiteralNumber => Some("#fab387")
      Operator | OperatorWord => Some("#89dceb")
    }
  } else {
    match kind {
      Text | Punctuation => None
      Bracket => Some("#0550ae")
      Comment => Some("#999988")
      Keyword => Some("#000000")
      KeywordType => Some("#445588")
      NameFunction => Some("#990000")
      NameBuiltin => Some("#0086b3")
      NameClass => Some("#445588")
      NameAttribute => Some("#008080")
      NameTag => Some("#000080")
      LiteralString => Some("#dd1144")
      LiteralStringEscape => Some("#dd1144")
      LiteralNumber => Some("#009999")
      Operator | OperatorWord => Some("#000000")
    }
  }
}

///|
fn code_token_class(kind : CodeTokenKind, is_dark : Bool) -> String? {
  if is_dark {
    match kind {
      Comment => Some("text-mono-italic")
      Operator | OperatorWord => Some("text-mono-bold")
      _ => None
    }
  } else {
    match kind {
      Comment => Some("text-mono-italic")
      Keyword
      | KeywordType
      | NameFunction
      | NameClass
      | Operator
      | OperatorWord => Some("text-mono-bold")
      _ => None
    }
  }
}

///|
fn code_write_span(
  sb : StringBuilder,
  raw_text : String,
  fill : String?,
  class_name : String?,
) -> Unit {
  let text = code_svg_escape(raw_text)
  match fill {
    Some(color) =>
      match class_name {
        Some(cls) =>
          sb.write_string(
            "<tspan fill=\"\{color}\" class=\"\{cls}\">\{text}</tspan>",
          )
        None => sb.write_string("<tspan fill=\"\{color}\">\{text}</tspan>")
      }
    None =>
      match class_name {
        Some(cls) => sb.write_string("<tspan class=\"\{cls}\">\{text}</tspan>")
        None => sb.write_string(text)
      }
  }
}

///|
fn code_is_ident_start(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn code_is_ident_continue(c : Char) -> Bool {
  code_is_ident_start(c) || (c >= '0' && c <= '9')
}

///|
fn code_next_non_space_char(s : String, start : Int) -> Char? {
  let mut i = start
  while i < s.length() {
    match char_at(s, i) {
      Some(' ') | Some('\t') => i = i + 1
      Some(c) => return Some(c)
      None => i = i + 1
    }
  }
  None
}

///|
fn code_prev_non_space_char(s : String, start : Int) -> Char? {
  let mut i = start
  while i >= 0 {
    match char_at(s, i) {
      Some(' ') | Some('\t') => i = i - 1
      Some(c) => return Some(c)
      None => i = i - 1
    }
  }
  None
}

///|
fn code_svg_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    match c {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '"' => sb.write_string("&quot;")
      ' ' => sb.write_string("&#160;")
      '\t' => sb.write_string("&#160;&#160;&#160;&#160;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn code_slice(s : String, start : Int, end_exclusive : Int) -> String {
  let sb = StringBuilder::new()
  for i in start..<end_exclusive {
    match s[i].to_char() {
      Some(c) => sb.write_char(c)
      None => ()
    }
  }
  sb.to_string()
}

///|
fn split_lines(s : String) -> Array[String] {
  let lines : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == '\n' {
      lines.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  let last = current.to_string()
  if last.length() > 0 || lines.length() == 0 {
    lines.push(last)
  }
  lines
}

///|
fn d2_shape_path(
  d : String,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  inline_theme : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> String {
  let classes = StringBuilder::new()
  let stroke_token = match stroke_class_token {
    Some(v) => Some(v)
    None => d2_theme_token(stroke, theme)
  }
  let fill_token = match fill_class_token {
    Some(v) => Some(v)
    None => d2_theme_token(fill, theme)
  }
  match stroke_token {
    Some(token) => classes.write_string(" stroke-\{token}")
    None => ()
  }
  match fill_token {
    Some(token) => classes.write_string(" fill-\{token}")
    None => ()
  }
  let stroke_width_css = if stroke_width.round() == stroke_width {
    stroke_width.to_int().to_string()
  } else {
    d2_fixed6(stroke_width)
  }
  let sb = StringBuilder::new()
  sb.write_string("<path")
  sb.write_string(" d=\"\{@svg.escape_xml(d)}\"")
  if inline_theme || stroke_token is None {
    sb.write_string(" stroke=\"\{@svg.escape_xml(stroke)}\"")
  }
  if inline_theme || fill_token is None {
    sb.write_string(" fill=\"\{@svg.escape_xml(fill)}\"")
  }
  let class_value = classes.to_string()
  if class_value != "" {
    sb.write_string(" class=\"\{@svg.escape_xml(class_value)}\"")
  }
  sb.write_string(
    " style=\"stroke-width:\{@svg.escape_xml(stroke_width_css)};\"",
  )
  sb.write_string(" />")
  sb.to_string()
}

///|
fn render_svg_cylinder(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  let arc_depth = 24.0
  let arc_height = if box.height < arc_depth * 2.0 {
    box.height / 2.0
  } else {
    arc_depth
  }
  let multiplier = 0.45
  let x0 = d2_path_chop_precision(box.x)
  let y0 = d2_path_chop_precision(box.y)
  let w = box.width
  let h = box.height
  let top_y = d2_path_chop_precision(y0 + arc_height)
  let mut current_y = top_y
  let outer : Array[String] = []
  outer.push("M \{d2_path_number(x0)} \{d2_path_number(top_y)}")
  outer.push(
    "C \{d2_path_number(x0)} \{d2_path_number(y0)} \{d2_path_number(x0 + w * multiplier)} \{d2_path_number(y0)} \{d2_path_number(x0 + w / 2.0)} \{d2_path_number(y0)}",
  )
  outer.push(
    "C \{d2_path_number(x0 + w - w * multiplier)} \{d2_path_number(y0)} \{d2_path_number(x0 + w)} \{d2_path_number(y0)} \{d2_path_number(x0 + w)} \{d2_path_number(top_y)}",
  )
  current_y = d2_path_chop_precision(current_y + (h - arc_height * 2.0))
  outer.push("V \{d2_path_number(current_y)}")
  outer.push(
    "C \{d2_path_number(x0 + w)} \{d2_path_number(y0 + h)} \{d2_path_number(x0 + w - w * multiplier)} \{d2_path_number(y0 + h)} \{d2_path_number(x0 + w / 2.0)} \{d2_path_number(y0 + h)}",
  )
  outer.push(
    "C \{d2_path_number(x0 + w * multiplier)} \{d2_path_number(y0 + h)} \{d2_path_number(x0)} \{d2_path_number(y0 + h)} \{d2_path_number(x0)} \{d2_path_number(y0 + h - arc_height)}",
  )
  current_y = d2_path_chop_precision(current_y - (h - arc_height * 2.0))
  outer.push("V \{d2_path_number(current_y)}")
  outer.push("Z")
  svg.add(
    d2_shape_path(
      outer.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )

  let inner : Array[String] = []
  inner.push("M \{d2_path_number(x0)} \{d2_path_number(top_y)}")
  inner.push(
    "C \{d2_path_number(x0)} \{d2_path_number(y0 + arc_height * 2.0)} \{d2_path_number(x0 + w * multiplier)} \{d2_path_number(y0 + arc_height * 2.0)} \{d2_path_number(x0 + w / 2.0)} \{d2_path_number(y0 + arc_height * 2.0)}",
  )
  inner.push(
    "C \{d2_path_number(x0 + w - w * multiplier)} \{d2_path_number(y0 + arc_height * 2.0)} \{d2_path_number(x0 + w)} \{d2_path_number(y0 + arc_height * 2.0)} \{d2_path_number(x0 + w)} \{d2_path_number(top_y)}",
  )
  svg.add(
    d2_shape_path(
      inner.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_octagon(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let inset = box.width * 0.29
  let inset_y = box.height * 0.29
  svg.add(
    @svg.polygon(
      [
        (box.x + inset, box.y),
        (box.x + box.width - inset, box.y),
        (box.x + box.width, box.y + inset_y),
        (box.x + box.width, box.y + box.height - inset_y),
        (box.x + box.width - inset, box.y + box.height),
        (box.x + inset, box.y + box.height),
        (box.x, box.y + box.height - inset_y),
        (box.x, box.y + inset_y),
      ],
      fill~,
      stroke~,
      stroke_width~,
    ),
  )
}

///|
fn render_svg_diamond(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_diamond.go (diamondPath).
  let sx = box.width / 77.0
  let sy = box.height / 76.9
  let abs = fn(x : Double, y : Double) {
    (
      d2_path_chop_precision(box.x + sx * x),
      d2_path_chop_precision(box.y + sy * y),
    )
  }
  let rel = fn(base_x : Double, base_y : Double, dx : Double, dy : Double) {
    (
      d2_path_chop_precision(base_x + sx * dx),
      d2_path_chop_precision(base_y + sy * dy),
    )
  }
  let commands : Array[String] = []
  let (start_x, start_y) = abs(38.5, 76.9)
  let mut current_x = start_x
  let mut current_y = start_y
  commands.push("M \{d2_path_number(current_x)} \{d2_path_number(current_y)}")

  let (c1x, c1y) = rel(current_x, current_y, -0.3, 0.0)
  let (c2x, c2y) = rel(current_x, current_y, -0.5, -0.1)
  let (c3x, c3y) = rel(current_x, current_y, -0.7, -0.3)
  commands.push(
    "C \{d2_path_number(c1x)} \{d2_path_number(c1y)} \{d2_path_number(c2x)} \{d2_path_number(c2y)} \{d2_path_number(c3x)} \{d2_path_number(c3y)}",
  )
  current_x = c3x
  current_y = c3y

  let (l1x, l1y) = abs(0.3, 39.2)
  commands.push("L \{d2_path_number(l1x)} \{d2_path_number(l1y)}")
  current_x = l1x
  current_y = l1y

  let (c4x, c4y) = rel(current_x, current_y, -0.4, -0.4)
  let (c5x, c5y) = rel(current_x, current_y, -0.4, -1.0)
  let (c6x, c6y) = rel(current_x, current_y, 0.0, -1.4)
  commands.push(
    "C \{d2_path_number(c4x)} \{d2_path_number(c4y)} \{d2_path_number(c5x)} \{d2_path_number(c5y)} \{d2_path_number(c6x)} \{d2_path_number(c6y)}",
  )
  current_x = c6x
  current_y = c6y

  let (l2x, l2y) = abs(37.8, 0.3)
  commands.push("L \{d2_path_number(l2x)} \{d2_path_number(l2y)}")
  current_x = l2x
  current_y = l2y

  let (c7x, c7y) = rel(current_x, current_y, 0.4, -0.4)
  let (c8x, c8y) = rel(current_x, current_y, 1.0, -0.4)
  let (c9x, c9y) = rel(current_x, current_y, 1.4, 0.0)
  commands.push(
    "C \{d2_path_number(c7x)} \{d2_path_number(c7y)} \{d2_path_number(c8x)} \{d2_path_number(c8y)} \{d2_path_number(c9x)} \{d2_path_number(c9y)}",
  )
  current_x = c9x
  current_y = c9y

  let (l3x, l3y) = rel(current_x, current_y, 37.5, 37.5)
  commands.push("L \{d2_path_number(l3x)} \{d2_path_number(l3y)}")
  current_x = l3x
  current_y = l3y

  let (c10x, c10y) = rel(current_x, current_y, 0.4, 0.4)
  let (c11x, c11y) = rel(current_x, current_y, 0.4, 1.0)
  let (c12x, c12y) = rel(current_x, current_y, 0.0, 1.4)
  commands.push(
    "C \{d2_path_number(c10x)} \{d2_path_number(c10y)} \{d2_path_number(c11x)} \{d2_path_number(c11y)} \{d2_path_number(c12x)} \{d2_path_number(c12y)}",
  )
  current_x = c12x
  current_y = c12y

  let (l4x, l4y) = abs(39.2, 76.6)
  commands.push("L \{d2_path_number(l4x)} \{d2_path_number(l4y)}")

  let (c13x, c13y) = abs(39.0, 76.8)
  let (c14x, c14y) = abs(38.8, 76.9)
  let (c15x, c15y) = abs(38.5, 76.9)
  commands.push(
    "C \{d2_path_number(c13x)} \{d2_path_number(c13y)} \{d2_path_number(c14x)} \{d2_path_number(c14y)} \{d2_path_number(c15x)} \{d2_path_number(c15y)}",
  )
  commands.push("Z")

  svg.add(
    d2_shape_path(
      commands.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_hexagon(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_hexagon.go (hexagonPath).
  let half_y_factor = 43.6 / 87.3
  let x0 = box.x
  let y0 = box.y
  let w = box.width
  let h = box.height
  let commands : Array[String] = []
  commands.push(
    "M \{d2_path_number(x0 + w * 0.25)} \{d2_path_number(y0 + h * 0.0)}",
  )
  commands.push(
    "L \{d2_path_number(x0 + w * 0.0)} \{d2_path_number(y0 + h * half_y_factor)}",
  )
  commands.push(
    "L \{d2_path_number(x0 + w * 0.25)} \{d2_path_number(y0 + h * 1.0)}",
  )
  commands.push(
    "L \{d2_path_number(x0 + w * 0.75)} \{d2_path_number(y0 + h * 1.0)}",
  )
  commands.push(
    "L \{d2_path_number(x0 + w * 1.0)} \{d2_path_number(y0 + h * half_y_factor)}",
  )
  commands.push(
    "L \{d2_path_number(x0 + w * 0.75)} \{d2_path_number(y0 + h * 0.0)}",
  )
  commands.push("Z")
  svg.add(
    d2_shape_path(
      commands.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_parallelogram(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_parallelogram.go (parallelogramPath).
  let wedge = if box.width <= 26.0 { box.width / 2.0 } else { 26.0 }
  let commands : Array[String] = []
  commands.push(
    "M \{d2_path_number(box.x + wedge)} \{d2_path_number(box.y + 0.0)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + box.width)} \{d2_path_number(box.y + 0.0)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + box.width - wedge)} \{d2_path_number(box.y + box.height)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + 0.0)} \{d2_path_number(box.y + box.height)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + 0.0)} \{d2_path_number(box.y + box.height)}",
  )
  commands.push("Z")
  svg.add(
    d2_shape_path(
      commands.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn d2_path_chop_precision(value : Double) -> Double {
  // Match upstream D2 lib/svg/path.go::chopPrecision.
  // D2 rounds to integer after bringing the value down to float32 precision.
  // Go reference:
  // math.Round(float64(float32(f*10000)) / 10000)
  let rounded = (Float::from_double(value * 10000.0).to_double() / 10000.0).round()
  if rounded == 0.0 {
    0.0
  } else {
    rounded
  }
}

///|
fn d2_path_number(value : Double) -> String {
  d2_path_chop_precision(value).to_string()
}

///|
fn render_svg_person(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_person.go (personPath) + lib/svg/path.go precision.
  let sx = box.width / 68.3
  let sy = box.height / 77.4
  let abs_point = fn(x : Double, y : Double) {
    (
      d2_path_chop_precision(box.x + sx * x),
      d2_path_chop_precision(box.y + sy * y),
    )
  }
  let rel_point = fn(
    base_x : Double,
    base_y : Double,
    dx : Double,
    dy : Double,
  ) {
    (
      d2_path_chop_precision(base_x + sx * dx),
      d2_path_chop_precision(base_y + sy * dy),
    )
  }

  let (start_x, start_y) = abs_point(68.3, 77.4)
  let mut current_x = start_x
  let mut current_y = start_y
  let commands : Array[String] = []
  commands.push("M \{d2_path_number(current_x)} \{d2_path_number(current_y)}")

  let (h_abs_x, _) = abs_point(0.0, 0.0)
  let h_target_x = h_abs_x
  commands.push("H \{d2_path_number(h_target_x)}")
  current_x = h_target_x

  let (_, v_target_y) = rel_point(current_x, current_y, 0.0, -1.1)
  commands.push("V \{d2_path_number(v_target_y)}")
  current_y = v_target_y

  let (c1x, c1y) = rel_point(current_x, current_y, 0.0, -13.2)
  let (c2x, c2y) = rel_point(current_x, current_y, 7.5, -25.1)
  let (c3x, c3y) = rel_point(current_x, current_y, 19.3, -30.8)
  commands.push(
    "C \{d2_path_number(c1x)} \{d2_path_number(c1y)} \{d2_path_number(c2x)} \{d2_path_number(c2y)} \{d2_path_number(c3x)} \{d2_path_number(c3y)}",
  )
  current_x = c3x
  current_y = c3y

  let (c4x1, c4y1) = abs_point(12.8, 40.9)
  let (c4x2, c4y2) = abs_point(8.9, 33.4)
  let (c4x3, c4y3) = abs_point(8.9, 25.2)
  commands.push(
    "C \{d2_path_number(c4x1)} \{d2_path_number(c4y1)} \{d2_path_number(c4x2)} \{d2_path_number(c4y2)} \{d2_path_number(c4x3)} \{d2_path_number(c4y3)}",
  )
  current_x = c4x3
  current_y = c4y3

  let (c5x1, c5y1) = abs_point(8.9, 11.3)
  let (c5x2, c5y2) = abs_point(20.2, 0.0)
  let (c5x3, c5y3) = abs_point(34.1, 0.0)
  commands.push(
    "C \{d2_path_number(c5x1)} \{d2_path_number(c5y1)} \{d2_path_number(c5x2)} \{d2_path_number(c5y2)} \{d2_path_number(c5x3)} \{d2_path_number(c5y3)}",
  )
  current_x = c5x3
  current_y = c5y3

  // Mirror of the omitted `s` command in d2.
  let (c6x1, c6y1) = rel_point(current_x, current_y, 13.9, 0.0)
  let (c6x2, c6y2) = rel_point(current_x, current_y, 25.2, 11.3)
  let (c6x3, c6y3) = rel_point(current_x, current_y, 25.2, 25.2)
  commands.push(
    "C \{d2_path_number(c6x1)} \{d2_path_number(c6y1)} \{d2_path_number(c6x2)} \{d2_path_number(c6y2)} \{d2_path_number(c6x3)} \{d2_path_number(c6y3)}",
  )
  current_x = c6x3
  current_y = c6y3

  let (c7x1, c7y1) = rel_point(current_x, current_y, 0.0, 8.2)
  let (c7x2, c7y2) = rel_point(current_x, current_y, -3.8, 15.6)
  let (c7x3, c7y3) = rel_point(current_x, current_y, -10.4, 20.4)
  commands.push(
    "C \{d2_path_number(c7x1)} \{d2_path_number(c7y1)} \{d2_path_number(c7x2)} \{d2_path_number(c7y2)} \{d2_path_number(c7x3)} \{d2_path_number(c7y3)}",
  )
  current_x = c7x3
  current_y = c7y3

  let (c8x1, c8y1) = rel_point(current_x, current_y, 11.8, 5.7)
  let (c8x2, c8y2) = rel_point(current_x, current_y, 19.3, 17.6)
  let (c8x3, c8y3) = rel_point(current_x, current_y, 19.3, 30.8)
  commands.push(
    "C \{d2_path_number(c8x1)} \{d2_path_number(c8y1)} \{d2_path_number(c8x2)} \{d2_path_number(c8y2)} \{d2_path_number(c8x3)} \{d2_path_number(c8y3)}",
  )
  current_x = c8x3
  current_y = c8y3

  let (_, v2_target_y) = rel_point(current_x, current_y, 0.0, 1.0)
  commands.push("V \{d2_path_number(v2_target_y)}")
  current_y = v2_target_y

  let (h2_abs_x, _) = abs_point(68.3, 0.0)
  commands.push("H \{d2_path_number(h2_abs_x)}")
  current_x = h2_abs_x

  commands.push("Z")

  svg.add(
    d2_shape_path(
      commands.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_cloud(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_cloud.go (cloudPath) and aligned to
  // upstream D2 lib/svg/path.go chopPrecision behavior.
  let sx = box.width / 834.0
  let sy = box.height / 523.0
  let abs = fn(x : Double, y : Double) {
    (
      d2_path_chop_precision(box.x + sx * x),
      d2_path_chop_precision(box.y + sy * y),
    )
  }
  let rel = fn(base_x : Double, base_y : Double, dx : Double, dy : Double) {
    (
      d2_path_chop_precision(base_x + sx * dx),
      d2_path_chop_precision(base_y + sy * dy),
    )
  }

  let commands : Array[String] = []
  let (start_x, start_y) = abs(137.833, 182.833)
  let mut current_x = start_x
  let mut current_y = start_y
  commands.push("M \{d2_path_number(current_x)} \{d2_path_number(current_y)}")

  let (c1x, c1y) = rel(current_x, current_y, 0.0, 5.556)
  let (c2x, c2y) = rel(current_x, current_y, -5.556, 11.111)
  let (c3x, c3y) = rel(current_x, current_y, -11.111, 11.111)
  commands.push(
    "C \{d2_path_number(c1x)} \{d2_path_number(c1y)} \{d2_path_number(c2x)} \{d2_path_number(c2y)} \{d2_path_number(c3x)} \{d2_path_number(c3y)}",
  )
  current_x = c3x
  current_y = c3y

  let (c4x, c4y) = rel(current_x, current_y, -70.833, 6.944)
  let (c5x, c5y) = rel(current_x, current_y, -126.389, 77.778)
  let (c6x, c6y) = rel(current_x, current_y, -126.389, 163.889)
  commands.push(
    "C \{d2_path_number(c4x)} \{d2_path_number(c4y)} \{d2_path_number(c5x)} \{d2_path_number(c5y)} \{d2_path_number(c6x)} \{d2_path_number(c6y)}",
  )
  current_x = c6x
  current_y = c6y

  let (c7x, c7y) = rel(current_x, current_y, 0.0, 91.667)
  let (c8x, c8y) = rel(current_x, current_y, 62.5, 165.278)
  let (c9x, c9y) = rel(current_x, current_y, 141.667, 165.278)
  commands.push(
    "C \{d2_path_number(c7x)} \{d2_path_number(c7y)} \{d2_path_number(c8x)} \{d2_path_number(c8y)} \{d2_path_number(c9x)} \{d2_path_number(c9y)}",
  )
  current_x = c9x
  current_y = c9y

  current_x = d2_path_chop_precision(current_x + sx * 537.5)
  commands.push("H \{d2_path_number(current_x)}")

  let (c10x, c10y) = rel(current_x, current_y, 84.723, 0.0)
  let (c11x, c11y) = rel(current_x, current_y, 154.167, -79.167)
  let (c12x, c12y) = rel(current_x, current_y, 154.167, -175.0)
  commands.push(
    "C \{d2_path_number(c10x)} \{d2_path_number(c10y)} \{d2_path_number(c11x)} \{d2_path_number(c11y)} \{d2_path_number(c12x)} \{d2_path_number(c12y)}",
  )
  current_x = c12x
  current_y = c12y

  let (c13x, c13y) = rel(current_x, current_y, 0.0, -91.667)
  let (c14x, c14y) = rel(current_x, current_y, -63.89, -168.056)
  let (c15x, c15y) = rel(current_x, current_y, -144.444, -173.611)
  commands.push(
    "C \{d2_path_number(c13x)} \{d2_path_number(c13y)} \{d2_path_number(c14x)} \{d2_path_number(c14y)} \{d2_path_number(c15x)} \{d2_path_number(c15y)}",
  )
  current_x = c15x
  current_y = c15y

  let (c16x, c16y) = rel(current_x, current_y, -5.556, 0.0)
  let (c17x, c17y) = rel(current_x, current_y, -11.111, -4.167)
  let (c18x, c18y) = rel(current_x, current_y, -12.5, -11.111)
  commands.push(
    "C \{d2_path_number(c16x)} \{d2_path_number(c16y)} \{d2_path_number(c17x)} \{d2_path_number(c17y)} \{d2_path_number(c18x)} \{d2_path_number(c18y)}",
  )
  current_x = c18x
  current_y = c18y

  let (c19x, c19y) = rel(current_x, current_y, -18.056, -93.055)
  let (c20x, c20y) = rel(current_x, current_y, -101.39, -162.5)
  let (c21x, c21y) = rel(current_x, current_y, -198.611, -162.5)
  commands.push(
    "C \{d2_path_number(c19x)} \{d2_path_number(c19y)} \{d2_path_number(c20x)} \{d2_path_number(c20y)} \{d2_path_number(c21x)} \{d2_path_number(c21y)}",
  )
  current_x = c21x
  current_y = c21y

  let (c22x, c22y) = rel(current_x, current_y, -63.889, 0.0)
  let (c23x, c23y) = rel(current_x, current_y, -120.834, 29.167)
  let (c24x, c24y) = rel(current_x, current_y, -156.944, 75.0)
  commands.push(
    "C \{d2_path_number(c22x)} \{d2_path_number(c22y)} \{d2_path_number(c23x)} \{d2_path_number(c23y)} \{d2_path_number(c24x)} \{d2_path_number(c24y)}",
  )
  current_x = c24x
  current_y = c24y

  let (c25x, c25y) = rel(current_x, current_y, -4.167, 5.556)
  let (c26x, c26y) = rel(current_x, current_y, -11.111, 6.945)
  let (c27x, c27y) = rel(current_x, current_y, -15.278, 5.556)
  commands.push(
    "C \{d2_path_number(c25x)} \{d2_path_number(c25y)} \{d2_path_number(c26x)} \{d2_path_number(c26y)} \{d2_path_number(c27x)} \{d2_path_number(c27y)}",
  )
  current_x = c27x
  current_y = c27y

  let (c28x, c28y) = rel(current_x, current_y, -13.889, -5.556)
  let (c29x, c29y) = rel(current_x, current_y, -29.166, -8.333)
  let (c30x, c30y) = rel(current_x, current_y, -45.833, -8.333)
  commands.push(
    "C \{d2_path_number(c28x)} \{d2_path_number(c28y)} \{d2_path_number(c29x)} \{d2_path_number(c29y)} \{d2_path_number(c30x)} \{d2_path_number(c30y)}",
  )

  let (c31x, c31y) = abs(196.167, 71.722)
  let (c32x, c32y) = abs(143.389, 120.333)
  let (c33x, c33y) = abs(137.833, 182.833)
  commands.push(
    "C \{d2_path_number(c31x)} \{d2_path_number(c31y)} \{d2_path_number(c32x)} \{d2_path_number(c32y)} \{d2_path_number(c33x)} \{d2_path_number(c33y)}",
  )
  commands.push("Z")

  svg.add(
    d2_shape_path(
      commands.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_document(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_document.go (documentPath).
  let doc_path_height = 18.925
  let doc_path_bottom = 16.3
  let sy = box.height
  let sx = box.width
  let x0 = box.x
  let y0 = box.y
  let bottom_ratio = doc_path_bottom / doc_path_height
  let cp_ratio = 12.8 / doc_path_height
  let cp2_ratio = 19.8 / doc_path_height
  let commands : Array[String] = []
  commands.push(
    "M \{d2_path_number(x0 + sx * 0.0)} \{d2_path_number(y0 + sy * bottom_ratio)}",
  )
  commands.push(
    "L \{d2_path_number(x0 + sx * 0.0)} \{d2_path_number(y0 + sy * 0.0)}",
  )
  commands.push(
    "L \{d2_path_number(x0 + sx * 1.0)} \{d2_path_number(y0 + sy * 0.0)}",
  )
  commands.push(
    "L \{d2_path_number(x0 + sx * 1.0)} \{d2_path_number(y0 + sy * bottom_ratio)}",
  )
  commands.push(
    "C \{d2_path_number(x0 + sx * (5.0 / 6.0))} \{d2_path_number(y0 + sy * cp_ratio)} \{d2_path_number(x0 + sx * (2.0 / 3.0))} \{d2_path_number(y0 + sy * cp_ratio)} \{d2_path_number(x0 + sx * 0.5)} \{d2_path_number(y0 + sy * bottom_ratio)}",
  )
  commands.push(
    "C \{d2_path_number(x0 + sx * (1.0 / 3.0))} \{d2_path_number(y0 + sy * cp2_ratio)} \{d2_path_number(x0 + sx * (1.0 / 6.0))} \{d2_path_number(y0 + sy * cp2_ratio)} \{d2_path_number(x0 + sx * 0.0)} \{d2_path_number(y0 + sy * bottom_ratio)}",
  )
  commands.push("Z")
  svg.add(
    d2_shape_path(
      commands.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_queue(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_queue.go (queueOuterPath/queueInnerPath).
  let arc_w = if box.width < 48.0 { box.width / 2.0 } else { 24.0 }
  let m = 0.45
  let x0 = box.x
  let y0 = box.y
  let w = box.width
  let h = box.height

  let mut current_x = d2_path_chop_precision(x0 + arc_w)
  let outer : Array[String] = []
  outer.push("M \{d2_path_number(current_x)} \{d2_path_number(y0)}")
  current_x = d2_path_chop_precision(current_x + (w - 2.0 * arc_w))
  outer.push("H \{d2_path_number(current_x)}")
  outer.push(
    "C \{d2_path_number(x0 + w)} \{d2_path_number(y0)} \{d2_path_number(x0 + w)} \{d2_path_number(y0 + h * m)} \{d2_path_number(x0 + w)} \{d2_path_number(y0 + h / 2.0)}",
  )
  outer.push(
    "C \{d2_path_number(x0 + w)} \{d2_path_number(y0 + h - h * m)} \{d2_path_number(x0 + w)} \{d2_path_number(y0 + h)} \{d2_path_number(x0 + w - arc_w)} \{d2_path_number(y0 + h)}",
  )
  current_x = d2_path_chop_precision(current_x - (w - 2.0 * arc_w))
  outer.push("H \{d2_path_number(current_x)}")
  outer.push(
    "C \{d2_path_number(x0)} \{d2_path_number(y0 + h)} \{d2_path_number(x0)} \{d2_path_number(y0 + h - h * m)} \{d2_path_number(x0)} \{d2_path_number(y0 + h / 2.0)}",
  )
  outer.push(
    "C \{d2_path_number(x0)} \{d2_path_number(y0 + h * m)} \{d2_path_number(x0)} \{d2_path_number(y0)} \{d2_path_number(x0 + arc_w)} \{d2_path_number(y0)}",
  )
  outer.push("Z")
  svg.add(
    d2_shape_path(
      outer.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )

  let inner : Array[String] = []
  inner.push("M \{d2_path_number(x0 + w - arc_w)} \{d2_path_number(y0)}")
  inner.push(
    "C \{d2_path_number(x0 + w - 2.0 * arc_w)} \{d2_path_number(y0)} \{d2_path_number(x0 + w - 2.0 * arc_w)} \{d2_path_number(y0 + h * m)} \{d2_path_number(x0 + w - 2.0 * arc_w)} \{d2_path_number(y0 + h / 2.0)}",
  )
  inner.push(
    "C \{d2_path_number(x0 + w - 2.0 * arc_w)} \{d2_path_number(y0 + h - h * m)} \{d2_path_number(x0 + w - 2.0 * arc_w)} \{d2_path_number(y0 + h)} \{d2_path_number(x0 + w - arc_w)} \{d2_path_number(y0 + h)}",
  )
  svg.add(
    d2_shape_path(
      inner.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_stored_data(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_stored_data.go (storedDataPath).
  let wedge = if box.width < 30.0 { box.width / 2.0 } else { 15.0 }
  let m = 0.27
  let x0 = box.x
  let y0 = box.y
  let w = box.width
  let h = box.height
  let mut current_x = d2_path_chop_precision(x0 + wedge)
  let pb : Array[String] = []
  pb.push("M \{d2_path_number(current_x)} \{d2_path_number(y0)}")
  current_x = d2_path_chop_precision(current_x + (w - wedge))
  pb.push("H \{d2_path_number(current_x)}")
  pb.push(
    "C \{d2_path_number(x0 + w - wedge * m)} \{d2_path_number(y0)} \{d2_path_number(x0 + w - wedge)} \{d2_path_number(y0 + h * m)} \{d2_path_number(x0 + w - wedge)} \{d2_path_number(y0 + h / 2.0)}",
  )
  pb.push(
    "C \{d2_path_number(x0 + w - wedge)} \{d2_path_number(y0 + h - h * m)} \{d2_path_number(x0 + w - wedge * m)} \{d2_path_number(y0 + h)} \{d2_path_number(x0 + w)} \{d2_path_number(y0 + h)}",
  )
  current_x = d2_path_chop_precision(current_x - (w - wedge))
  pb.push("H \{d2_path_number(current_x)}")
  pb.push(
    "C \{d2_path_number(x0 + wedge - wedge * m)} \{d2_path_number(y0 + h)} \{d2_path_number(x0)} \{d2_path_number(y0 + h - h * m)} \{d2_path_number(x0)} \{d2_path_number(y0 + h / 2.0)}",
  )
  pb.push(
    "C \{d2_path_number(x0)} \{d2_path_number(y0 + h * m)} \{d2_path_number(x0 + wedge - wedge * m)} \{d2_path_number(y0)} \{d2_path_number(x0 + wedge)} \{d2_path_number(y0)}",
  )
  pb.push("Z")
  svg.add(
    d2_shape_path(
      pb.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_page(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_page.go (pageOuterPath/pageInnerPath).
  let x0 = box.x
  let y0 = box.y
  let w = box.width
  let h = box.height

  let outer : Array[String] = []
  outer.push("M \{d2_path_number(x0 + 0.5)} \{d2_path_number(y0 + 0.0)}")
  outer.push("H \{d2_path_number(x0 + (w - 20.8164))}")
  outer.push(
    "C \{d2_path_number(x0 + (w - 19.6456))} \{d2_path_number(y0 + 0.0)} \{d2_path_number(x0 + (w - 18.5210))} \{d2_path_number(y0 + 0.456297)} \{d2_path_number(x0 + (w - 17.6811))} \{d2_path_number(y0 + 1.27202)}",
  )
  outer.push(
    "L \{d2_path_number(x0 + (w - 1.3647))} \{d2_path_number(y0 + 17.12)}",
  )
  outer.push(
    "C \{d2_path_number(x0 + (w - 0.4923))} \{d2_path_number(y0 + 17.9674)} \{d2_path_number(x0 + w)} \{d2_path_number(y0 + 19.1318)} \{d2_path_number(x0 + w)} \{d2_path_number(y0 + 20.348)}",
  )
  outer.push("V \{d2_path_number(y0 + (h - 0.5))}")
  outer.push(
    "C \{d2_path_number(x0 + w)} \{d2_path_number(y0 + (h - 0.2239))} \{d2_path_number(x0 + (w - 0.2239))} \{d2_path_number(y0 + h)} \{d2_path_number(x0 + (w - 0.5))} \{d2_path_number(y0 + h)}",
  )
  outer.push("H \{d2_path_number(x0 + 0.499999)}")
  outer.push(
    "C \{d2_path_number(x0 + 0.223857)} \{d2_path_number(y0 + h)} \{d2_path_number(x0 + 0.0)} \{d2_path_number(y0 + (h - 0.2239))} \{d2_path_number(x0 + 0.0)} \{d2_path_number(y0 + (h - 0.5))}",
  )
  outer.push("V \{d2_path_number(y0 + 0.499999)}")
  outer.push(
    "C \{d2_path_number(x0 + 0.0)} \{d2_path_number(y0 + 0.223857)} \{d2_path_number(x0 + 0.223857)} \{d2_path_number(y0 + 0.0)} \{d2_path_number(x0 + 0.5)} \{d2_path_number(y0 + 0.0)}",
  )
  outer.push("Z")
  svg.add(
    d2_shape_path(
      outer.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )

  let inner : Array[String] = []
  let mut current_x = d2_path_chop_precision(x0 + (w - 1.08197))
  let mut current_y = d2_path_chop_precision(y0 + h)
  inner.push("M \{d2_path_number(current_x)} \{d2_path_number(current_y)}")
  let h1 = d2_path_chop_precision(x0 + 1.08196)
  inner.push("H \{d2_path_number(h1)}")
  current_x = h1
  let (c1x, c1y) = (
    d2_path_chop_precision(current_x - 0.64918),
    d2_path_chop_precision(current_y + 0.0),
  )
  let (c2x, c2y) = (
    d2_path_chop_precision(current_x - 1.08196),
    d2_path_chop_precision(current_y - 0.43287),
  )
  let (c3x, c3y) = (
    d2_path_chop_precision(current_x - 1.08196),
    d2_path_chop_precision(current_y - 1.08219),
  )
  inner.push(
    "C \{d2_path_number(c1x)} \{d2_path_number(c1y)} \{d2_path_number(c2x)} \{d2_path_number(c2y)} \{d2_path_number(c3x)} \{d2_path_number(c3y)}",
  )
  current_x = c3x
  current_y = c3y
  let v1 = d2_path_chop_precision(y0 + 1.08219)
  inner.push("V \{d2_path_number(v1)}")
  current_y = v1
  let (c4x, c4y) = (
    d2_path_chop_precision(current_x + 0.0),
    d2_path_chop_precision(current_y - 0.64931),
  )
  let (c5x, c5y) = (
    d2_path_chop_precision(current_x + 0.43278),
    d2_path_chop_precision(current_y - 1.08219),
  )
  let (c6x, c6y) = (
    d2_path_chop_precision(current_x + 1.08196),
    d2_path_chop_precision(current_y - 1.08219),
  )
  inner.push(
    "C \{d2_path_number(c4x)} \{d2_path_number(c4y)} \{d2_path_number(c5x)} \{d2_path_number(c5y)} \{d2_path_number(c6x)} \{d2_path_number(c6y)}",
  )
  current_x = c6x
  current_y = c6y
  let h2 = d2_path_chop_precision(current_x + (w - 22.72132))
  inner.push("H \{d2_path_number(h2)}")
  current_x = h2
  let (c7x, c7y) = (
    d2_path_chop_precision(current_x + 0.64918),
    d2_path_chop_precision(current_y + 0.0),
  )
  let (c8x, c8y) = (
    d2_path_chop_precision(current_x + 1.08196),
    d2_path_chop_precision(current_y + 0.43287),
  )
  let (c9x, c9y) = (
    d2_path_chop_precision(current_x + 1.08196),
    d2_path_chop_precision(current_y + 1.08219),
  )
  inner.push(
    "C \{d2_path_number(c7x)} \{d2_path_number(c7y)} \{d2_path_number(c8x)} \{d2_path_number(c8y)} \{d2_path_number(c9x)} \{d2_path_number(c9y)}",
  )
  current_x = c9x
  current_y = c9y
  let v2 = d2_path_chop_precision(current_y + 17.09863)
  inner.push("V \{d2_path_number(v2)}")
  current_y = v2
  let (c10x, c10y) = (
    d2_path_chop_precision(current_x + 0.0),
    d2_path_chop_precision(current_y + 1.29863),
  )
  let (c11x, c11y) = (
    d2_path_chop_precision(current_x + 0.86557),
    d2_path_chop_precision(current_y + 2.38082),
  )
  let (c12x, c12y) = (
    d2_path_chop_precision(current_x + 2.38032),
    d2_path_chop_precision(current_y + 2.38082),
  )
  inner.push(
    "C \{d2_path_number(c10x)} \{d2_path_number(c10y)} \{d2_path_number(c11x)} \{d2_path_number(c11y)} \{d2_path_number(c12x)} \{d2_path_number(c12y)}",
  )
  current_x = c12x
  current_y = c12y
  let h3 = d2_path_chop_precision(x0 + (w - 1.08197))
  inner.push("H \{d2_path_number(h3)}")
  current_x = h3
  let (c13x, c13y) = (
    d2_path_chop_precision(current_x + 0.64918),
    d2_path_chop_precision(current_y + 0.0),
  )
  let (c14x, c14y) = (
    d2_path_chop_precision(current_x + 1.08196),
    d2_path_chop_precision(current_y + 0.43287),
  )
  let (c15x, c15y) = (
    d2_path_chop_precision(current_x + 1.08196),
    d2_path_chop_precision(current_y + 1.08196),
  )
  inner.push(
    "C \{d2_path_number(c13x)} \{d2_path_number(c13y)} \{d2_path_number(c14x)} \{d2_path_number(c14y)} \{d2_path_number(c15x)} \{d2_path_number(c15y)}",
  )
  current_x = c15x
  current_y = c15y
  let v3 = d2_path_chop_precision(y0 + (h - 1.0822))
  inner.push("V \{d2_path_number(v3)}")
  inner.push(
    "C \{d2_path_number(x0 + (w - 1.0))} \{d2_path_number(y0 + (h - 0.43288))} \{d2_path_number(x0 + (w - 0.43279))} \{d2_path_number(y0 + h)} \{d2_path_number(x0 + (w - 1.08197))} \{d2_path_number(y0 + h)}",
  )
  inner.push("Z")
  svg.add(
    d2_shape_path(
      inner.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_package(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_package.go (getTopDimensions/packagePath).
  let mut top_width = box.width * 0.5
  if box.width >= 100.0 {
    top_width = if top_width > 150.0 {
      150.0
    } else if top_width < 50.0 {
      50.0
    } else {
      top_width
    }
  }
  let top_height = if box.height * 0.2 < 55.0 { box.height * 0.2 } else { 55.0 }
  let commands : Array[String] = []
  commands.push(
    "M \{d2_path_number(box.x + 0.0)} \{d2_path_number(box.y + 0.0)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + top_width)} \{d2_path_number(box.y + 0.0)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + top_width)} \{d2_path_number(box.y + top_height)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + box.width)} \{d2_path_number(box.y + top_height)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + box.width)} \{d2_path_number(box.y + box.height)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + 0.0)} \{d2_path_number(box.y + box.height)}",
  )
  commands.push("Z")
  svg.add(
    d2_shape_path(
      commands.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_step(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_step.go (stepPath).
  let wedge = if box.width <= 35.0 { box.width / 2.0 } else { 35.0 }
  let commands : Array[String] = []
  commands.push("M \{d2_path_number(box.x)} \{d2_path_number(box.y)}")
  commands.push(
    "L \{d2_path_number(box.x + box.width - wedge)} \{d2_path_number(box.y)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + box.width)} \{d2_path_number(box.y + box.height / 2.0)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + box.width - wedge)} \{d2_path_number(box.y + box.height)}",
  )
  commands.push(
    "L \{d2_path_number(box.x)} \{d2_path_number(box.y + box.height)}",
  )
  commands.push(
    "L \{d2_path_number(box.x + wedge)} \{d2_path_number(box.y + box.height / 2.0)}",
  )
  commands.push("Z")
  svg.add(
    d2_shape_path(
      commands.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn render_svg_callout(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Unit {
  // Ported from upstream D2 lib/shape/shape_callout.go (calloutPath).
  let tip_w = if box.width < 60.0 { box.width / 2.0 } else { 30.0 }
  let tip_h = if box.height < 90.0 { box.height / 2.0 } else { 45.0 }
  let commands : Array[String] = []
  let mut current_x = d2_path_chop_precision(box.x)
  let mut current_y = d2_path_chop_precision(box.y)
  commands.push("M \{d2_path_number(current_x)} \{d2_path_number(current_y)}")

  current_y = d2_path_chop_precision(current_y + (box.height - tip_h))
  commands.push("V \{d2_path_number(current_y)}")

  current_x = d2_path_chop_precision(current_x + box.width / 2.0)
  commands.push("H \{d2_path_number(current_x)}")

  current_y = d2_path_chop_precision(current_y + tip_h)
  commands.push("V \{d2_path_number(current_y)}")

  current_x = d2_path_chop_precision(current_x + tip_w)
  current_y = d2_path_chop_precision(current_y - tip_h)
  commands.push("L \{d2_path_number(current_x)} \{d2_path_number(current_y)}")

  current_x = d2_path_chop_precision(current_x + (box.width / 2.0 - tip_w))
  commands.push("H \{d2_path_number(current_x)}")

  current_y = d2_path_chop_precision(current_y - (box.height - tip_h))
  commands.push("V \{d2_path_number(current_y)}")

  current_x = d2_path_chop_precision(current_x - box.width)
  commands.push("H \{d2_path_number(current_x)}")
  commands.push("Z")
  svg.add(
    d2_shape_path(
      commands.join(" "),
      fill,
      stroke,
      stroke_width,
      theme,
      !use_css_theme_vars,
      fill_class_token,
      stroke_class_token,
    ),
  )
}

///|
fn shifted_multiple_box(box : Box) -> Box {
  Box::new(
    box.x + MULTIPLE_OFFSET,
    box.y - MULTIPLE_OFFSET,
    box.width,
    box.height,
  )
}

///|
fn render_svg_3d_rect(
  svg : @svg.Svg,
  diagram_hash : String,
  obj_id : String,
  box : Box,
  fill : String,
  side_fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  _use_css_theme_vars : Bool,
) -> Unit {
  // Ported from upstream D2 d2renderers/d2svg/d2svg.go (render3DRect).
  let xi = round_double(box.x).to_int()
  let yi = round_double(box.y).to_int()
  let wi = round_double(box.width).to_int()
  let hi = round_double(box.height).to_int()
  let offset = round_double(THREE_DEE_OFFSET).to_int()
  let border_segments : Array[String] = [
    "M\{xi},\{yi}",
    "L\{xi + offset},\{yi - offset}",
    "L\{xi + wi + offset},\{yi - offset}",
    "L\{xi + wi + offset},\{yi + hi - offset}",
    "L\{xi + wi},\{yi + hi}",
    "L\{xi},\{yi + hi}",
    "L\{xi},\{yi}",
    "L\{xi + wi},\{yi}",
    "L\{xi + wi},\{yi + hi}",
    "M\{xi + wi},\{yi}",
    "L\{xi + wi + offset},\{yi - offset}",
  ]
  let border_path_mask = border_segments.join("")
  let border_path = border_segments.join(" ")
  let mask_id = "border-mask-\{diagram_hash}-\{@svg.escape_xml(obj_id)}"
  let stroke_width_css = if stroke_width.round() == stroke_width {
    stroke_width.to_int().to_string()
  } else {
    d2_fixed6(stroke_width)
  }
  let border_style = "stroke-width:\{stroke_width_css};"
  let mask_x = xi
  let mask_y = yi - offset
  let mask_w = wi + offset
  let mask_h = hi + offset
  svg.add(
    "<defs><mask id=\"\{mask_id}\" maskUnits=\"userSpaceOnUse\" x=\"\{mask_x}\" y=\"\{mask_y}\" width=\"\{mask_w}\" height=\"\{mask_h}\">\n<rect x=\"\{mask_x}\" y=\"\{mask_y}\" width=\"\{mask_w}\" height=\"\{mask_h}\" fill=\"white\"></rect>\n<path d=\"\{border_path_mask}\" style=\"\{border_style};stroke:#000;fill:none;opacity:1;\"/></mask></defs>",
  )
  svg.add(
    "<rect x=\"\{d2_fixed6(xi.to_double())}\" y=\"\{d2_fixed6(yi.to_double())}\" width=\"\{d2_fixed6(wi.to_double())}\" height=\"\{d2_fixed6(hi.to_double())}\" mask=\"url(#\{mask_id})\" stroke=\"none\" fill=\"\{@svg.escape_xml(fill)}\" style=\"\{border_style}\" />",
  )
  let side_points = "\{xi},\{yi} \{xi + offset},\{yi - offset} \{xi + wi + offset},\{yi - offset} \{xi + wi + offset},\{yi + hi - offset} \{xi + wi},\{yi + hi} \{xi + wi},\{yi}"
  svg.add(
    "<polygon mask=\"url(#\{mask_id})\" points=\"\{side_points}\" fill=\"\{@svg.escape_xml(side_fill)}\" style=\"\{border_style}\" />",
  )
  let stroke_class = match d2_theme_token(stroke, theme) {
    Some(token) => " class=\" stroke-\{token}\""
    None => ""
  }
  svg.add(
    "<path d=\"\{border_path}\" stroke=\"\{@svg.escape_xml(stroke)}\" fill=\"none\"\{stroke_class} style=\"\{border_style}\" />",
  )
}

///|
fn d2_path_data(
  edge : Connection,
  src_adj : (Double, Double),
  dst_adj : (Double, Double),
  connection_border_radius : Double,
) -> String {
  let route = edge.route
  if route.length() < 2 {
    return ""
  }
  let path : Array[String] = []
  path.push(
    "M \{d2_fixed6(route[0].x + src_adj.0)} \{d2_fixed6(route[0].y + src_adj.1)}",
  )

  if edge.is_curve {
    let mut i = 1
    while i < route.length() - 3 {
      path.push(
        "C \{d2_fixed6(route[i].x)} \{d2_fixed6(route[i].y)} \{d2_fixed6(route[i + 1].x)} \{d2_fixed6(route[i + 1].y)} \{d2_fixed6(route[i + 2].x)} \{d2_fixed6(route[i + 2].y)}",
      )
      i = i + 3
    }
    if i + 2 < route.length() {
      path.push(
        "C \{d2_fixed6(route[i].x)} \{d2_fixed6(route[i].y)} \{d2_fixed6(route[i + 1].x)} \{d2_fixed6(route[i + 1].y)} \{d2_fixed6(route[i + 2].x + dst_adj.0)} \{d2_fixed6(route[i + 2].y + dst_adj.1)}",
      )
    }
    return path.join(" ")
  }

  let mut i = 1
  while i < route.length() - 1 {
    let prev_source = route[i - 1]
    let prev_target = route[i]
    let curr_target = route[i + 1]
    let prev_vector_x = prev_target.x - prev_source.x
    let prev_vector_y = prev_target.y - prev_source.y
    let curr_vector_x = curr_target.x - prev_target.x
    let curr_vector_y = curr_target.y - prev_target.y
    let dist = @graph.Point::distance(prev_target, curr_target)
    let units = @cmp.minimum(connection_border_radius, dist / 2.0)
    let (prev_tx, prev_ty) = unit_vector_scaled(
      prev_vector_x, prev_vector_y, units,
    )
    let (curr_tx, curr_ty) = unit_vector_scaled(
      curr_vector_x, curr_vector_y, units,
    )

    path.push(
      "L \{d2_fixed6(prev_target.x - prev_tx)} \{d2_fixed6(prev_target.y - prev_ty)}",
    )

    if units < connection_border_radius && i < route.length() - 2 {
      let next_target = route[i + 2]
      let next_vector_x = next_target.x - curr_target.x
      let next_vector_y = next_target.y - curr_target.y
      i = i + 1
      let (next_tx, next_ty) = unit_vector_scaled(
        next_vector_x, next_vector_y, units,
      )
      path.push(
        "C \{d2_fixed6(prev_target.x + prev_tx)} \{d2_fixed6(prev_target.y + prev_ty)} \{d2_fixed6(curr_target.x - next_tx)} \{d2_fixed6(curr_target.y - next_ty)} \{d2_fixed6(curr_target.x + next_tx)} \{d2_fixed6(curr_target.y + next_ty)}",
      )
    } else {
      path.push(
        "S \{d2_fixed6(prev_target.x)} \{d2_fixed6(prev_target.y)} \{d2_fixed6(prev_target.x + curr_tx)} \{d2_fixed6(prev_target.y + curr_ty)}",
      )
    }
    i = i + 1
  }

  let last_point = route[route.length() - 1]
  path.push(
    "L \{d2_fixed6(last_point.x + dst_adj.0)} \{d2_fixed6(last_point.y + dst_adj.1)}",
  )
  path.join(" ")
}

///|
fn unit_vector_scaled(
  dx : Double,
  dy : Double,
  scale : Double,
) -> (Double, Double) {
  let length = (dx * dx + dy * dy).sqrt()
  if length <= 0.000001 {
    (0.0, 0.0)
  } else {
    (dx / length * scale, dy / length * scale)
  }
}

///|
fn get_arrowhead_adjustments(
  edge : Connection,
  shapes : Array[Shape],
  edge_stroke_width : Double,
  default_shape_stroke_width : Double,
) -> ((Double, Double), (Double, Double)) {
  if edge.route.length() < 2 {
    return ((0.0, 0.0), (0.0, 0.0))
  }
  let src_shape_stroke = shape_stroke_width(
    shapes,
    edge.src_lookup_id,
    default_shape_stroke_width,
  )
  let dst_shape_stroke = shape_stroke_width(
    shapes,
    edge.dst_lookup_id,
    default_shape_stroke_width,
  )
  let src_adj = arrowhead_adjustment(
    edge.route[1],
    edge.route[0],
    edge.src_arrowhead,
    edge_stroke_width,
    src_shape_stroke,
  )
  let last = edge.route.length() - 1
  let dst_adj = arrowhead_adjustment(
    edge.route[last - 1],
    edge.route[last],
    edge.dst_arrowhead,
    edge_stroke_width,
    dst_shape_stroke,
  )
  (src_adj, dst_adj)
}

///|
fn shape_stroke_width(
  shapes : Array[Shape],
  id : String,
  default_value : Double,
) -> Double {
  for shape in shapes {
    if shape.id == id {
      return style_double(shape.style.stroke_width, default_value)
    }
  }
  0.0
}

///|
fn arrowhead_adjustment(
  start : Point,
  end : Point,
  arrowhead : @graph.ArrowheadType,
  edge_stroke_width : Double,
  shape_stroke_width : Double,
) -> (Double, Double) {
  let mut distance = (edge_stroke_width + shape_stroke_width) / 2.0
  if arrowhead_requires_extra_gap(arrowhead) {
    distance = distance + edge_stroke_width
  }
  let vx = end.x - start.x
  let vy = end.y - start.y
  let length = (vx * vx + vy * vy).sqrt()
  if length <= 0.000001 {
    return (0.0, 0.0)
  }
  let ux = vx / length
  let uy = vy / length
  (-ux * distance, -uy * distance)
}

///|
fn arrowhead_requires_extra_gap(arrowhead : @graph.ArrowheadType) -> Bool {
  arrowhead != @graph.None
}

///|
fn route_length(points : Array[Point]) -> Double {
  let mut total = 0.0
  if points.length() < 2 {
    return total
  }
  for i = 0; i < points.length() - 1; i = i + 1 {
    let p0 = points[i]
    let p1 = points[i + 1]
    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    total = total + (dx * dx + dy * dy).sqrt()
  }
  total
}

///|
fn point_at_distance_on_route(
  points : Array[Point],
  distance : Double,
) -> (Point, Int) {
  if points.length() < 2 {
    return (Point::new(0.0, 0.0), 0)
  }
  // Match upstream D2 lib/geo/route.go::GetPointAtDistance:
  // do not clamp distance into [0, total], extrapolate on the last segment.
  let mut remaining = distance
  let mut curr = points[0]
  let mut next = points[1]
  let mut seg_len = 0.0
  for i = 0; i < points.length() - 1; i = i + 1 {
    curr = points[i]
    next = points[i + 1]
    let dx = next.x - curr.x
    let dy = next.y - curr.y
    seg_len = (dx * dx + dy * dy).sqrt()
    if remaining <= seg_len {
      if seg_len <= 0.000001 {
        return (curr, i)
      }
      let t = remaining / seg_len
      return (
        Point::new(
          curr.x * (1.0 - t) + next.x * t,
          curr.y * (1.0 - t) + next.y * t,
        ),
        i,
      )
    }
    remaining = remaining - seg_len
  }
  let last_index = points.length() - 2
  if seg_len <= 0.000001 {
    return (next, last_index)
  }
  let t = 1.0 + remaining / seg_len
  (
    Point::new(curr.x * (1.0 - t) + next.x * t, curr.y * (1.0 - t) + next.y * t),
    last_index,
  )
}

///|
fn unit_normal_vector(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> (Double, Double) {
  let normal_x = y1 - y2
  let normal_y = x2 - x1
  let dx = x2 - x1
  let dy = y2 - y1
  let len = (dx * dx + dy * dy).sqrt()
  if len <= 0.000001 {
    (0.0, 0.0)
  } else {
    (normal_x / len, normal_y / len)
  }
}

///|
fn unlocked_top_label_top_left(
  route : Array[Point],
  stroke_width : Double,
  label_percentage : Double,
  width : Double,
  height : Double,
) -> (Point, Int) {
  let total = route_length(route)
  let target_distance = label_percentage * total
  let (base_point, segment_index) = point_at_distance_on_route(
    route, target_distance,
  )
  let seg_start = route[segment_index]
  let seg_end = route[segment_index + 1]
  let (normal_x_raw, normal_y_raw) = unit_normal_vector(
    seg_start.x,
    seg_start.y,
    seg_end.x,
    seg_end.y,
  )
  // UnlockedTop uses the opposite side of the segment normal.
  let normal_x = -normal_x_raw
  let normal_y = -normal_y_raw
  let offset_x = stroke_width / 2.0 + LABEL_PADDING + width / 2.0
  let offset_y = stroke_width / 2.0 + LABEL_PADDING + height / 2.0
  let center_x = base_point.x + normal_x * offset_x
  let center_y = base_point.y + normal_y * offset_y
  (
    Point::new(
      d2_path_chop_precision(center_x - width / 2.0),
      d2_path_chop_precision(center_y - height / 2.0),
    ),
    segment_index,
  )
}

///|
fn arrowhead_dimensions(
  arrowhead : @graph.ArrowheadType,
  stroke_width : Double,
) -> (Double, Double) {
  let clipped_stroke = if stroke_width < MIN_ARROWHEAD_STROKE_WIDTH {
    MIN_ARROWHEAD_STROKE_WIDTH
  } else {
    stroke_width
  }
  let (base_width, base_height, width_mul, height_mul) = match arrowhead {
    @graph.Triangle => (4.0, 4.0, 3.0, 4.0)
    @graph.Open => (7.0, 7.0, 3.0, 4.0)
    @graph.Line => (0.0, 0.0, 5.0, 8.0)
    @graph.Diamond => (11.0, 9.0, 5.5, 4.5)
    @graph.Circle => (8.0, 8.0, 5.0, 5.0)
    @graph.CfOne
    | @graph.CfMany
    | @graph.CfOneRequired
    | @graph.CfManyRequired
    | @graph.CfOneOptional
    | @graph.CfManyOptional => (9.0, 9.0, 4.5, 4.5)
    @graph.None => (0.0, 0.0, 0.0, 0.0)
  }
  (
    base_width + clipped_stroke * width_mul,
    base_height + clipped_stroke * height_mul,
  )
}

///|
fn arrowhead_label_top_left(
  edge : Connection,
  is_dst : Bool,
  width : Double,
  height : Double,
  stroke_width : Double,
) -> Point? {
  if edge.route.length() < 2 {
    return None
  }

  let segment_index = if is_dst { edge.route.length() - 2 } else { 0 }
  let start = edge.route[segment_index]
  let end = edge.route[segment_index + 1]
  // Use the normal toward unlocked-top position near the end/start segment.
  let (normal_x, normal_y) = unit_normal_vector(end.x, end.y, start.x, start.y)
  let shift = normal_x.abs() * (height / 2.0 + LABEL_PADDING) +
    normal_y.abs() * (width / 2.0 + LABEL_PADDING)
  let length = route_length(edge.route)
  let mut position = if is_dst { 1.0 } else { 0.0 }
  if length > 0.0 {
    if is_dst {
      position = position - shift / length
    } else {
      position = position + shift / length
    }
  }

  let (label_tl0, _) = unlocked_top_label_top_left(
    edge.route,
    stroke_width,
    position,
    width,
    height,
  )
  let mut label_tl = label_tl0

  let (_, arrow_size) = if is_dst {
    arrowhead_dimensions(edge.dst_arrowhead, stroke_width)
  } else {
    arrowhead_dimensions(edge.src_arrowhead, stroke_width)
  }
  if arrow_size > 0.0 {
    let offset = arrow_size / 2.0 +
      ARROWHEAD_PADDING -
      stroke_width / 2.0 -
      LABEL_PADDING
    if offset > 0.0 {
      label_tl = Point::new(
        label_tl.x + normal_x * offset,
        label_tl.y + normal_y * offset,
      )
    }
  }

  Some(label_tl)
}

///|
fn render_edge_arrowhead_label(
  svg : @svg.Svg,
  edge : Connection,
  text : String,
  is_dst : Bool,
  label_color : String?,
  config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  stroke_width : Double,
) -> Unit {
  if text == "" {
    return
  }
  let font_size = style_int(edge.style.font_size, config.font_size)
  let is_mono = theme.rules.mono || style_is_mono(edge.style.font_family)
  let is_bold = style_bool(edge.style.bold, false)
  let dims = @text_metrics.measure_label(
    text, font_size, is_mono, is_bold, true,
  )
  match
    arrowhead_label_top_left(
      edge,
      is_dst,
      dims.width,
      dims.height,
      stroke_width,
    ) {
    Some(label_tl) => {
      let x = label_tl.x + dims.width / 2.0
      let y = label_tl.y + font_size.to_double()
      let fill = match label_color {
        Some(color_raw) =>
          resolve_theme_color(color_raw, theme, use_css_theme_vars)
        None => resolve_theme_color("N1", theme, use_css_theme_vars)
      }
      svg.add(
        d2_text_element(
          x,
          y,
          text,
          dims.height,
          fill,
          "text-italic",
          font_size,
          theme,
          !use_css_theme_vars,
        ),
      )
    }
    None => ()
  }
}

///|
fn render_svg_edge(
  svg : @svg.Svg,
  edge : Connection,
  repeat_index : Int,
  shapes : Array[Shape],
  edge_label_mask_url : String,
  edge_marker_ids : Map[String, String],
  diagram_hash : String,
  config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> Unit raise @render_api.RenderError {
  if edge.route.length() < 2 {
    return
  }
  let wrapper_style = if style_double(edge.style.opacity, 1.0) != 1.0 {
    "opacity:\{d2_fixed6(style_double(edge.style.opacity, 1.0))}"
  } else {
    ""
  }
  svg.add(
    d2_group_open(
      d2_connection_wrapper_class(d2_connection_abs_id(edge, repeat_index)),
      style=wrapper_style,
    ),
  )
  // Apply sketch filter if enabled
  let use_sketch = sketch_enabled(edge.style.sketch, config)
  if use_sketch {
    svg.open_group_with_filter(defs_id(config, "sketch-filter"))
  }
  // Get style values
  let stroke_default = default_edge_stroke_token(edge)
  let stroke_signature = style_string(edge.style.stroke, stroke_default)
  let stroke = style_color(
    edge.style.stroke,
    stroke_default,
    theme,
    use_css_theme_vars,
  )
  let stroke_width = style_double(
    edge.style.stroke_width,
    config.default_stroke_width,
  )
  let connection_border_radius = style_double(edge.style.border_radius, 10.0)
  let stroke_dash = style_double(edge.style.stroke_dash, 0.0)
  let (src_adj, dst_adj) = get_arrowhead_adjustments(
    edge,
    shapes,
    stroke_width,
    config.default_stroke_width,
  )
  let path_data = d2_path_data(edge, src_adj, dst_adj, connection_border_radius)
  // Determine markers based on arrowhead types
  let marker_start = marker_url_for_edge(
    svg,
    diagram_hash,
    edge_marker_ids,
    edge.src_arrowhead,
    false,
    stroke_signature,
    stroke,
    stroke_width,
    theme,
  )
  let marker_end = marker_url_for_edge(
    svg,
    diagram_hash,
    edge_marker_ids,
    edge.dst_arrowhead,
    true,
    stroke_signature,
    stroke,
    stroke_width,
    theme,
  )
  svg.add(
    d2_connection_path_element(
      path_data,
      stroke,
      stroke_signature,
      stroke_width,
      stroke_dash,
      marker_start,
      marker_end,
      edge_label_mask_url,
      style_bool(edge.style.animated, false),
      theme,
      !use_css_theme_vars,
    ),
  )
  // Render edge label
  if edge.label != "" {
    // Use precomputed label_box from the layout pipeline.
    match edge.label_box {
      Some(label_box) => {
        // Align with d2 SVG renderer behavior: edge label top-left is rounded
        // before calculating text baseline/center.
        let label_x = round_double(label_box.x)
        let label_y = round_double(label_box.y)
        let cx = label_x + label_box.width / 2.0
        let label_font_size = style_int(edge.style.font_size, config.font_size)
        let baseline_y = label_y + label_font_size.to_double()
        let text_color = style_color(
          edge.style.font_color,
          "N2",
          theme,
          use_css_theme_vars,
        )
        let font_class = d2_font_class_name(
          theme.rules.mono || style_is_mono(edge.style.font_family),
          style_bool(edge.style.bold, false),
          style_bool(edge.style.italic, true),
          style_bool(edge.style.underline, false),
        )
        svg.add(
          d2_text_element(
            cx,
            baseline_y,
            edge.label,
            label_box.height,
            text_color,
            font_class,
            label_font_size,
            theme,
            !use_css_theme_vars,
          ),
        )
      }
      None =>
        raise InvalidDiagram(
          "Connection '\{edge.src_id} -> \{edge.dst_id}' has no label_box; sizes must be precomputed",
        )
    }
  }
  match edge.src_arrowhead_label {
    Some(text) =>
      render_edge_arrowhead_label(
        svg,
        edge,
        text,
        false,
        edge.src_arrowhead_label_color,
        config,
        theme,
        use_css_theme_vars,
        stroke_width,
      )
    None => ()
  }
  match edge.dst_arrowhead_label {
    Some(text) =>
      render_edge_arrowhead_label(
        svg,
        edge,
        text,
        true,
        edge.dst_arrowhead_label_color,
        config,
        theme,
        use_css_theme_vars,
        stroke_width,
      )
    None => ()
  }
  // Close sketch filter group if opened
  if use_sketch {
    svg.close_group()
  }
  svg.close_group()
}

///|
/// Render C4 Person shape - person icon with label below
fn render_svg_c4_person(
  svg : @svg.Svg,
  box : Box,
  label : String,
  fill : String,
  stroke : String,
  stroke_width : Double,
  config : SvgConfig,
) -> Unit {
  let cx = box.x + box.width / 2.0
  // Person icon takes top 60%, label takes bottom 40%
  let icon_height = box.height * 0.6
  let label_height = box.height * 0.4
  // Head
  let head_r = icon_height * 0.25
  let head_cy = box.y + head_r + 5.0
  svg.add(@svg.circle(cx, head_cy, head_r, fill~, stroke~, stroke_width~))
  // Body (rounded rectangle representing torso)
  let body_width = box.width * 0.5
  let body_height = icon_height * 0.45
  let body_top = head_cy + head_r + 5.0
  svg.add(
    @svg.rect(
      cx - body_width / 2.0,
      body_top,
      body_width,
      body_height,
      fill~,
      stroke~,
      stroke_width~,
      rx=Some(8.0),
      ry=Some(8.0),
    ),
  )
  // Label below the icon
  let label_y = box.y + icon_height + label_height / 2.0
  svg.add(
    @svg.text(
      cx,
      label_y,
      label,
      font_family=config.font_family,
      font_size=config.font_size,
    ),
  )
}

///|
/// Render C4 Container shape - rounded rect with technology label
fn render_svg_c4_container(
  svg : @svg.Svg,
  box : Box,
  label : String,
  fill : String,
  stroke : String,
  stroke_width : Double,
  config : SvgConfig,
) -> Unit {
  // Main container rectangle with rounded corners
  let corner_radius = 10.0
  svg.add(
    @svg.rect(
      box.x,
      box.y,
      box.width,
      box.height,
      fill~,
      stroke~,
      stroke_width~,
      rx=Some(corner_radius),
      ry=Some(corner_radius),
    ),
  )
  // Parse label for name and technology
  let lines = split_lines(label)
  let name = if lines.length() > 0 { lines[0] } else { label }
  let tech = if lines.length() > 1 { lines[1] } else { "" }
  // Container name (centered)
  let name_y = box.y + box.height / 2.0
  svg.add(
    @svg.text(
      box.x + box.width / 2.0,
      name_y,
      name,
      font_family=config.font_family,
      font_size=config.font_size,
    ),
  )
  // Technology label below name (smaller, in brackets)
  if tech != "" {
    svg.add(
      @svg.styled_text(
        box.x + box.width / 2.0,
        name_y + config.font_size.to_double() + 5.0,
        "[\{tech}]",
        font_family=config.font_family,
        font_size=config.font_size - 2,
        extra_style="fill: #666666",
      ),
    )
  }
}

///|
fn default_edge_stroke_token(edge : Connection) -> String {
  if style_double(edge.style.stroke_dash, 0.0) != 0.0 {
    "B2"
  } else {
    "B1"
  }
}

///|
/// Render a sequence diagram note (uses page shape with folded corner)
fn render_svg_sequence_note(
  svg : @svg.Svg,
  box : Box,
  text : String,
  config : SvgConfig,
) -> Unit {
  let fill = "#ffffc0" // Light yellow for notes
  let stroke = config.default_stroke
  let stroke_width = config.default_stroke_width
  let theme = @themes.get_theme(config.theme_id)
  // Use page shape for notes (with folded corner)
  render_svg_page(
    svg,
    box,
    fill,
    stroke,
    stroke_width,
    theme,
    false,
    None,
    None,
  )
  // Render note text centered
  let cx = box.x + box.width / 2.0
  let cy = box.y + box.height / 2.0
  svg.add(
    @svg.text(
      cx,
      cy,
      text,
      font_family=config.font_family,
      font_size=config.font_size - 2,
    ),
  )
}

///|
/// Render sequence diagram fragments (combined fragments like alt, opt, loop)
fn render_svg_sequence_fragments(
  svg : @svg.Svg,
  graph : Diagram,
  config : SvgConfig,
) -> Unit {
  for fragment in graph.sequence_fragments {
    if fragment.bbox is Some(bbox) {
      render_svg_fragment(svg, fragment, bbox, config)
    }
  }
}

///|
/// Render a single sequence diagram fragment
fn render_svg_fragment(
  svg : @svg.Svg,
  fragment : SequenceFragmentLayout,
  bbox : Box,
  config : SvgConfig,
) -> Unit {
  let stroke = config.default_stroke
  let stroke_width = config.default_stroke_width
  let fill = "none"
  let label_height = 20.0
  let label_padding = 8.0
  // Draw the main fragment frame
  svg.add(
    @svg.rect(
      bbox.x,
      bbox.y,
      bbox.width,
      bbox.height,
      fill~,
      stroke~,
      stroke_width~,
    ),
  )
  // Draw the label box in the top-left corner
  let label_text = fragment.fragment_type.to_upper()
  let label_width = estimate_text_width(label_text, config.font_size) +
    label_padding * 2.0
  // Pentagon-like shape for the label
  let pb = @svg.PathBuilder::new()
    .move_to(bbox.x, bbox.y)
    .line_to(bbox.x + label_width, bbox.y)
    .line_to(bbox.x + label_width, bbox.y + label_height - 5.0)
    .line_to(bbox.x + label_width - 5.0, bbox.y + label_height)
    .line_to(bbox.x, bbox.y + label_height)
    .close()
  svg.add(@svg.path(pb.build(), fill="#f0f0f0", stroke~, stroke_width~))
  // Fragment type label
  svg.add(
    @svg.text(
      bbox.x + label_padding,
      bbox.y + label_height / 2.0 + 3.0,
      label_text,
      font_size=config.font_size - 1,
      font_family=config.font_family,
      text_anchor="start",
    ),
  )
  // Draw condition if present
  if fragment.condition is Some(cond) {
    svg.add(
      @svg.text(
        bbox.x + label_width + 10.0,
        bbox.y + label_height / 2.0 + 3.0,
        cond,
        font_size=config.font_size - 2,
        font_family=config.font_family,
        text_anchor="start",
      ),
    )
  }
  // Draw operand separators for multi-branch fragments (e.g., alt)
  for operand in fragment.operands {
    // Dashed horizontal line
    svg.add(
      @xml_emit.Element::new("line")
      .attr_num("x1", bbox.x)
      .attr_num("y1", operand.separator_y)
      .attr_num("x2", bbox.x + bbox.width)
      .attr_num("y2", operand.separator_y)
      .attr("stroke", stroke)
      .attr_num("stroke-width", stroke_width)
      .attr("stroke-dasharray", "5,5")
      .self_close()
      .build(),
    )
    // Operand condition label
    if operand.condition is Some(cond) {
      svg.add(
        @svg.text(
          bbox.x + label_padding,
          operand.separator_y + 15.0,
          cond,
          font_size=config.font_size - 2,
          font_family=config.font_family,
          text_anchor="start",
        ),
      )
    }
  }
}
