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
  /// Light theme color overrides by token (e.g. B1, N7).
  theme_overrides : Map[String, String]
  /// Dark theme color overrides by token.
  dark_theme_overrides : Map[String, String]
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
    font_family: "Arial, sans-serif",
    font_size: 16,
    background: theme.background_color(),
    default_stroke: theme.stroke_color(),
    default_fill: theme.fill_color(),
    default_stroke_width: 2.0,
    arrow_size: 10.0,
    theme_id: 0,
    dark_theme_id: None,
    theme_overrides: {},
    dark_theme_overrides: {},
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
    font_family: font,
    font_size: 16,
    background: theme.background_color(),
    default_stroke: theme.stroke_color(),
    default_fill: theme.fill_color(),
    default_stroke_width: 2.0,
    arrow_size: 10.0,
    theme_id,
    dark_theme_id: None,
    theme_overrides: {},
    dark_theme_overrides: {},
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
  theme_overrides : Map[String, String],
  dark_theme_overrides : Map[String, String],
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
fn shape_inner_box_for_label(
  obj : Shape,
  box : Box,
  label_dims : @text_metrics.TextDimensions,
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
      let aspect = if label_dims.height > 0.0 {
        label_dims.width / label_dims.height
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
fn theme_css_lines(theme : @themes.Theme, indent : String) -> Array[String] {
  [
    "\{indent}svg {",
    "\{indent}  --d2-N1: \{theme.colors.n1};",
    "\{indent}  --d2-N2: \{theme.colors.n2};",
    "\{indent}  --d2-N3: \{theme.colors.n3};",
    "\{indent}  --d2-N4: \{theme.colors.n4};",
    "\{indent}  --d2-N5: \{theme.colors.n5};",
    "\{indent}  --d2-N6: \{theme.colors.n6};",
    "\{indent}  --d2-N7: \{theme.colors.n7};",
    "\{indent}  --d2-B1: \{theme.colors.b1};",
    "\{indent}  --d2-B2: \{theme.colors.b2};",
    "\{indent}  --d2-B3: \{theme.colors.b3};",
    "\{indent}  --d2-B4: \{theme.colors.b4};",
    "\{indent}  --d2-B5: \{theme.colors.b5};",
    "\{indent}  --d2-B6: \{theme.colors.b6};",
    "\{indent}  --d2-AA2: \{theme.colors.aa2};",
    "\{indent}  --d2-AA4: \{theme.colors.aa4};",
    "\{indent}  --d2-AA5: \{theme.colors.aa5};",
    "\{indent}  --d2-AB4: \{theme.colors.ab4};",
    "\{indent}  --d2-AB5: \{theme.colors.ab5};",
    "\{indent}}",
  ]
}

///|
fn add_theme_styles(
  svg : @svg.Svg,
  light_theme : @themes.Theme,
  dark_theme : @themes.Theme?,
) -> Unit {
  let lines : Array[String] = []
  for line in theme_css_lines(light_theme, "") {
    lines.push(line)
  }
  lines.push("svg text { fill: var(--d2-N1); }")
  match dark_theme {
    Some(theme) => {
      lines.push("@media screen and (prefers-color-scheme: dark) {")
      for line in theme_css_lines(theme, "  ") {
        lines.push(line)
      }
      lines.push("}")
    }
    None => ()
  }
  let css = lines.join("\n")
  svg.add(
    @xml_emit.Element::new("style")
    .attr("type", "text/css")
    .cdata(css + "\n")
    .build(),
  )
}

///|
fn hash_u32(s : String) -> Int {
  let mut h : Int = 216613626
  for i in 0..<s.length() {
    let b = s.code_unit_at(i).to_int()
    h = h ^ b
    h = (h * 16777619) & 0x7fffffff
  }
  h
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
fn defs_url(config : SvgConfig, base : String) -> String {
  "url(#\{defs_id(config, base)})"
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
fn transform_label_text(text : String, text_transform : String) -> String {
  if text_transform == "" {
    return text
  }
  match text_transform.to_lower() {
    "uppercase" => text.to_upper()
    "lowercase" => text.to_lower()
    _ => text
  }
}

///|
const ROOT_INNER_BORDER_OFFSET : Double = 5.0

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
fn pattern_def_key(pattern : String) -> String {
  "pattern-\{pattern}"
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
) -> String {
  match style_fill_pattern_key(fill_pattern) {
    Some(pattern) => defs_url(config, pattern_def_key(pattern))
    None => base_fill
  }
}

///|
fn has_non_empty_link(link : String?) -> Bool {
  match link {
    Some(v) => v.trim() != ""
    None => false
  }
}

///|
fn graph_has_links(graph : Diagram) -> Bool {
  if has_non_empty_link(graph.root.link) {
    return true
  }
  for obj in graph.shapes {
    if has_non_empty_link(obj.link) {
      return true
    }
  }
  false
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
fn tooltip_icon_svg(clip_id : String) -> String {
  let outline = @xml_emit.Element::new("path")
    .attr(
      "d", "M16 31.1109C24.3456 31.1109 31.1111 24.3454 31.1111 15.9998C31.1111 7.65415 24.3456 0.888672 16 0.888672C7.65436 0.888672 0.888885 7.65415 0.888885 15.9998C0.888885 24.3454 7.65436 31.1109 16 31.1109Z",
    )
    .attr("fill", "white")
    .attr("stroke", "#DEE1EB")
    .self_close()
    .build()
  let circle = @xml_emit.Element::new("path")
    .attr(
      "d", "M16 26C21.5228 26 26 21.5228 26 16C26 10.4772 21.5228 6 16 6C10.4772 6 6 10.4772 6 16C6 21.5228 10.4772 26 16 26Z",
    )
    .attr("stroke", "#2E3346")
    .attr_num("stroke-width", 2)
    .attr("stroke-linecap", "round")
    .attr("stroke-linejoin", "round")
    .self_close()
    .build()
  let stem = @xml_emit.Element::new("path")
    .attr("d", "M16 19.998V15.998")
    .attr("stroke", "#2E3346")
    .attr_num("stroke-width", 2)
    .attr("stroke-linecap", "round")
    .attr("stroke-linejoin", "round")
    .self_close()
    .build()
  let dot = @xml_emit.Element::new("path")
    .attr("d", "M16 12H16.0098")
    .attr("stroke", "#2E3346")
    .attr_num("stroke-width", 2)
    .attr("stroke-linecap", "round")
    .attr("stroke-linejoin", "round")
    .self_close()
    .build()
  let g = @xml_emit.Element::new("g")
    .attr("clip-path", "url(#\{clip_id})")
    .child(outline)
    .child(circle)
    .child(stem)
    .child(dot)
    .build()
  let clip_rect = @xml_emit.Element::new("rect")
    .attr_num("width", APPENDIX_ICON_DIAMETER.to_double())
    .attr_num("height", APPENDIX_ICON_DIAMETER.to_double())
    .attr("fill", "white")
    .self_close()
    .build()
  let clip_path = @xml_emit.Element::new("clipPath")
    .attr("id", clip_id)
    .child(clip_rect)
    .build()
  let defs = @xml_emit.Element::new("defs").child(clip_path).build()
  @xml_emit.Element::new("svg")
  .attr_num("width", APPENDIX_ICON_DIAMETER.to_double())
  .attr_num("height", APPENDIX_ICON_DIAMETER.to_double())
  .attr("viewBox", "0 0 32 32")
  .attr("fill", "none")
  .attr("xmlns", "http://www.w3.org/2000/svg")
  .child(g)
  .child(defs)
  .build()
}

///|
fn link_icon_svg(clip_id : String) -> String {
  let outline = @xml_emit.Element::new("path")
    .attr(
      "d", "M16 31.1109C24.3456 31.1109 31.1111 24.3454 31.1111 15.9998C31.1111 7.65415 24.3456 0.888672 16 0.888672C7.65436 0.888672 0.888885 7.65415 0.888885 15.9998C0.888885 24.3454 7.65436 31.1109 16 31.1109Z",
    )
    .attr("fill", "white")
    .attr("stroke", "#DEE1EB")
    .self_close()
    .build()
  let chain_a = @xml_emit.Element::new("path")
    .attr(
      "d", "M14.3909 16.7965C14.7364 17.2584 15.1772 17.6406 15.6834 17.9171C16.1896 18.1938 16.7494 18.3582 17.3248 18.3993C17.9001 18.4405 18.4777 18.3575 19.0181 18.1559C19.5586 17.9543 20.0492 17.6389 20.4571 17.2309L22.8708 14.8173C23.6036 14.0586 24.0089 13.0425 23.9998 11.9877C23.9906 10.933 23.5676 9.92404 22.8217 9.17821C22.0759 8.43237 21.067 8.00931 20.0123 8.00015C18.9575 7.99098 17.9413 8.39644 17.1827 9.1292L15.7988 10.505",
    )
    .attr("stroke", "#2E3346")
    .attr_num("stroke-width", 2)
    .attr("stroke-linecap", "round")
    .attr("stroke-linejoin", "round")
    .self_close()
    .build()
  let chain_b = @xml_emit.Element::new("path")
    .attr(
      "d", "M17.609 15.1874C17.2635 14.7255 16.8227 14.3433 16.3165 14.0667C15.8103 13.7902 15.2505 13.6257 14.6752 13.5845C14.0998 13.5433 13.5223 13.6263 12.9819 13.8279C12.4414 14.0295 11.9506 14.345 11.5428 14.753L9.1292 17.1666C8.39644 17.9252 7.99098 18.9414 8.00015 19.9962C8.00931 21.0509 8.43237 22.0598 9.17821 22.8056C9.92405 23.5515 10.933 23.9745 11.9877 23.9837C13.0425 23.9928 14.0586 23.5875 14.8173 22.8547L16.193 21.4788",
    )
    .attr("stroke", "#2E3346")
    .attr_num("stroke-width", 2)
    .attr("stroke-linecap", "round")
    .attr("stroke-linejoin", "round")
    .self_close()
    .build()
  let g = @xml_emit.Element::new("g")
    .attr("clip-path", "url(#\{clip_id})")
    .child(outline)
    .child(chain_a)
    .child(chain_b)
    .build()
  let clip_rect = @xml_emit.Element::new("rect")
    .attr_num("width", APPENDIX_ICON_DIAMETER.to_double())
    .attr_num("height", APPENDIX_ICON_DIAMETER.to_double())
    .attr("fill", "white")
    .self_close()
    .build()
  let clip_path = @xml_emit.Element::new("clipPath")
    .attr("id", clip_id)
    .child(clip_rect)
    .build()
  let defs = @xml_emit.Element::new("defs").child(clip_path).build()
  @xml_emit.Element::new("svg")
  .attr_num("width", APPENDIX_ICON_DIAMETER.to_double())
  .attr_num("height", APPENDIX_ICON_DIAMETER.to_double())
  .attr("viewBox", "0 0 32 32")
  .attr("fill", "none")
  .attr("xmlns", "http://www.w3.org/2000/svg")
  .child(g)
  .child(defs)
  .build()
}

///|
fn render_object_appendix_icons(
  svg : @svg.Svg,
  obj : Shape,
  box : @graph.Box,
) -> Unit {
  let tooltip_text = non_empty_string(obj.tooltip)
  let link_href = non_empty_string(obj.link)
  if tooltip_text is None && link_href is None {
    return
  }
  let anchor_x = (box.x + box.width).ceil().to_int()
  let anchor_y = box.y.ceil().to_int()
  let tooltip_slot_offset = 0
  let link_slot_offset = if tooltip_text is Some(_) {
    APPENDIX_ICON_DIAMETER
  } else {
    0
  }

  match tooltip_text {
    Some(text) => {
      let x = anchor_x - APPENDIX_ICON_RADIUS - tooltip_slot_offset
      let y = anchor_y - APPENDIX_ICON_RADIUS
      let tooltip_clip_seed = "tt|\{obj.id}"
      let clip_id = "clip0_3427_35082111-\{hash_u32(tooltip_clip_seed)}-\{hash_u32(obj.id)}"
      let icon_svg = tooltip_icon_svg(clip_id)
      svg.add(
        @xml_emit.Element::new("g")
        .attr("transform", "translate(\{x} \{y})")
        .attr("class", "appendix-icon")
        .child(@xml_emit.Element::new("title").text(text).build())
        .raw(icon_svg)
        .build(),
      )
    }
    None => ()
  }

  match link_href {
    Some(_) => {
      let x = anchor_x - APPENDIX_ICON_RADIUS - link_slot_offset
      let y = anchor_y - APPENDIX_ICON_RADIUS
      let link_clip_seed = "ln|\{obj.id}"
      let clip_id = "clip0_3440_35088111-\{hash_u32(link_clip_seed)}-\{hash_u32(obj.id)}"
      let icon_svg = link_icon_svg(clip_id)
      svg.add(
        @xml_emit.Element::new("g")
        .attr("transform", "translate(\{x} \{y})")
        .attr("class", "appendix-icon")
        .raw(icon_svg)
        .build(),
      )
    }
    None => ()
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
  base_viewbox_x : Double,
  base_viewbox_y : Double,
  base_viewbox_width : Double,
  base_viewbox_height : Double,
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
  let half_stroke = ceil_double(stroke_width / 2.0)
  let inner_x = base_viewbox_x - half_stroke
  let inner_y = base_viewbox_y - half_stroke
  let inner_width = base_viewbox_width + half_stroke * 2.0
  let inner_height = base_viewbox_height + half_stroke * 2.0
  let mut viewbox_x = inner_x - half_stroke
  let mut viewbox_y = inner_y - half_stroke
  let mut viewbox_width = inner_width + half_stroke * 2.0
  let mut viewbox_height = inner_height + half_stroke * 2.0
  let mut outer_x : Double? = None
  let mut outer_y : Double? = None
  let mut outer_width : Double? = None
  let mut outer_height : Double? = None
  if style_bool(graph.root.style.double_border, false) {
    let outer_left = viewbox_x - half_stroke - ROOT_INNER_BORDER_OFFSET
    let outer_top = viewbox_y - half_stroke - ROOT_INNER_BORDER_OFFSET
    let outer_w = viewbox_width +
      half_stroke * 2.0 +
      ROOT_INNER_BORDER_OFFSET * 2.0
    let outer_h = viewbox_height +
      half_stroke * 2.0 +
      ROOT_INNER_BORDER_OFFSET * 2.0
    outer_x = Some(outer_left)
    outer_y = Some(outer_top)
    outer_width = Some(outer_w)
    outer_height = Some(outer_h)
    viewbox_x = outer_left - half_stroke
    viewbox_y = outer_top - half_stroke
    viewbox_width = outer_w + half_stroke * 2.0
    viewbox_height = outer_h + half_stroke * 2.0
  }
  {
    viewbox_x,
    viewbox_y,
    viewbox_width,
    viewbox_height,
    inner_x,
    inner_y,
    inner_width,
    inner_height,
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
  class_name? : String? = None,
) -> Unit {
  let mut rect = @xml_emit.Element::new("rect")
    .attr_num("x", x)
    .attr_num("y", y)
    .attr_num("width", width)
    .attr_num("height", height)
    .attr_num("rx", border_radius)
    .attr("fill", fill)
    .attr_num("stroke-width", stroke_width)
  match class_name {
    Some(class_name) => rect = rect.attr("class", class_name)
    None => ()
  }
  if stroke != "" && stroke != "none" {
    rect = rect.attr("stroke", stroke)
  }
  if stroke_dash > 0.0 {
    rect = rect.attr("stroke-dasharray", stroke_dash.to_string())
  }
  svg.add(rect.self_close().build())
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
    Some(class_name) =>
      svg.add(
        @xml_emit.Element::new("rect")
        .attr_num("x", x)
        .attr_num("y", y)
        .attr_num("width", width)
        .attr_num("height", height)
        .attr_num("rx", border_radius)
        .attr_num("stroke-width", stroke_width)
        .attr("class", class_name)
        .self_close()
        .build(),
      )
    None => ()
  }
}

///|
fn render_root_background(svg : @svg.Svg, metrics : RootCanvasMetrics) -> Unit {
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
  // D2 parity: do not reserve extra height for custom interactive controls.
  let control_height = 0.0
  // Calculate bounds (include all layers/scenarios/steps for max size)
  let (base_min_x, base_min_y, base_max_x, base_max_y) = compute_graph_bounds(
    graph,
  )
  let mut min_x = base_min_x
  let mut min_y = base_min_y
  let mut max_x = base_max_x
  let mut max_y = base_max_y
  for layer in graph.layers {
    let (lmin_x, lmin_y, lmax_x, lmax_y) = compute_graph_bounds(layer)
    if lmin_x < min_x {
      min_x = lmin_x
    }
    if lmin_y < min_y {
      min_y = lmin_y
    }
    if lmax_x > max_x {
      max_x = lmax_x
    }
    if lmax_y > max_y {
      max_y = lmax_y
    }
  }
  for scenario in graph.scenarios {
    let (smin_x, smin_y, smax_x, smax_y) = compute_graph_bounds(scenario)
    if smin_x < min_x {
      min_x = smin_x
    }
    if smin_y < min_y {
      min_y = smin_y
    }
    if smax_x > max_x {
      max_x = smax_x
    }
    if smax_y > max_y {
      max_y = smax_y
    }
  }
  for step in graph.steps {
    let (smin_x, smin_y, smax_x, smax_y) = compute_graph_bounds(step)
    if smin_x < min_x {
      min_x = smin_x
    }
    if smin_y < min_y {
      min_y = smin_y
    }
    if smax_x > max_x {
      max_x = smax_x
    }
    if smax_y > max_y {
      max_y = smax_y
    }
  }
  let bounds = (min_x, min_y, max_x, max_y)
  // Calculate dimensions accounting for negative coordinates
  let content_width = max_x - min_x
  let content_height = max_y - min_y
  let base_viewbox_width = content_width + config.padding * 2.0
  let base_viewbox_height = content_height +
    config.padding * 2.0 +
    control_height
  let base_viewbox_x = min_x - config.padding
  let base_viewbox_y = min_y - config.padding - control_height
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
  let root_canvas = compute_root_canvas_metrics(
    graph, config, light_theme, use_css_theme_vars, base_viewbox_x, base_viewbox_y,
    base_viewbox_width, base_viewbox_height,
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
  if not(config.omit_version) {
    svg.add_root_attr("data-d2-version", DIAGO_VERSION)
  }
  if graph_has_links(graph) {
    svg.add_root_attr("xmlns:xlink", "http://www.w3.org/1999/xlink")
  }
  if use_css_theme_vars {
    add_theme_styles(svg, light_theme, dark_theme)
  }
  // Add fill patterns
  add_fill_patterns(svg, graph, config, light_theme, use_css_theme_vars)
  // Add sketch filter if needed
  add_sketch_filter(svg, graph, config)
  // D2 parity: all connection labels are cut out via a shared mask.
  let edge_label_mask_url = defs_url(config, "edge-label-mask")
  svg.add_def(
    edge_label_mask_def(
      graph, config, viewbox_x, viewbox_y, viewbox_width, viewbox_height,
    ),
  )
  let edge_marker_ids : Map[String, String] = {}
  // Background
  render_root_background(svg, root_canvas)
  // D2 parity: skip custom control bar rendering.
  // Main content group with offset to shift content into positive coordinate space
  svg.open_group_with_id("base-layer", "")
  // Three-pass rendering for all diagrams (sequence diagrams are now format-agnostic)
  // Lifelines are rendered as dashed edges, activation boxes as regular objects
  let sorted_objects = sort_objects_by_depth(graph.shapes)
  // Pass 1: Render object backgrounds (shapes, fills, borders)
  for obj in sorted_objects {
    render_svg_object(
      svg,
      obj,
      graph.shapes,
      config,
      light_theme,
      use_css_theme_vars,
      pass=Background,
    )
  }
  if graph.root.shape_type == @graph.SequenceDiagram {
    render_sequence_lifelines(svg, graph, light_theme, use_css_theme_vars)
  }
  // Pass 2: Render edges (on top of backgrounds, behind text)
  for edge in graph.connections {
    render_svg_edge(
      svg,
      edge,
      graph.shapes,
      edge_label_mask_url,
      edge_marker_ids,
      config,
      light_theme,
      use_css_theme_vars,
    )
  }
  // Pass 3: Render object foregrounds (text, labels, content)
  for obj in sorted_objects {
    render_svg_object(
      svg,
      obj,
      graph.shapes,
      config,
      light_theme,
      use_css_theme_vars,
      pass=Foreground,
    )
  }
  // Render sequence diagram notes (using page shape)
  for note in graph.sequence_notes {
    let text = note.1
    let box = note.2
    render_svg_sequence_note(svg, box, text, config)
  }
  // Render sequence diagram fragments (combined fragments like alt, opt, loop)
  render_svg_sequence_fragments(svg, graph, config)
  svg.close_group()
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
  svg.to_string()
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
  graph : Diagram,
  config : SvgConfig,
  mask_x : Double,
  mask_y : Double,
  mask_width : Double,
  mask_height : Double,
) -> String {
  let sb = StringBuilder::new()
  let mask_id = defs_id(config, "edge-label-mask")
  sb.write_string(
    "<mask id=\"\{mask_id}\" maskUnits=\"userSpaceOnUse\" x=\"\{mask_x}\" y=\"\{mask_y}\" width=\"\{mask_width}\" height=\"\{mask_height}\">",
  )
  sb.write_string(
    "<rect x=\"\{mask_x}\" y=\"\{mask_y}\" width=\"\{mask_width}\" height=\"\{mask_height}\" fill=\"white\"></rect>",
  )
  for edge in graph.connections {
    if edge.label == "" {
      continue
    }
    match edge.label_box {
      Some(label_box) => {
        let label_x = round_double(label_box.x) - 2.0
        let label_y = round_double(label_box.y)
        let label_width = label_box.width + 4.0
        sb.write_string(
          "<rect x=\"\{label_x}\" y=\"\{label_y}\" width=\"\{label_width}\" height=\"\{label_box.height}\" fill=\"black\"></rect>",
        )
      }
      None => ()
    }
  }
  sb.write_string("</mask>")
  sb.to_string()
}

///|
fn marker_key(
  arrowhead : ArrowheadType,
  is_target : Bool,
  stroke : String,
  stroke_width : Double,
) -> String {
  "\{arrowhead.to_arrowhead_string()}|\{is_target}|\{stroke}|\{stroke_width}"
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
) -> String {
  match arrowhead {
    @graph.None => ""
    @graph.Triangle => {
      let points = if is_target {
        "0,0 \{width},\{height / 2.0} 0,\{height}"
      } else {
        "\{width},0 0,\{height / 2.0} \{width},\{height}"
      }
      @xml_emit.Element::new("polygon")
      .attr("points", points)
      .attr("fill", stroke)
      .attr_num("stroke-width", stroke_width)
      .self_close()
      .build()
    }
    @graph.Open => {
      let inset = stroke_width / 2.0
      let points = if is_target {
        "\{inset},\{inset} \{width - inset},\{height / 2.0} \{inset},\{height - inset}"
      } else {
        "\{width - inset},\{inset} \{inset},\{height / 2.0} \{width - inset},\{height - inset}"
      }
      @xml_emit.Element::new("polygon")
      .attr("points", points)
      .attr("fill", "#FFFFFF")
      .attr("stroke", stroke)
      .attr_num("stroke-width", stroke_width)
      .self_close()
      .build()
    }
    @graph.Line => {
      let points = if is_target {
        "\{stroke_width / 2.0},\{stroke_width / 2.0} \{width - stroke_width / 2.0},\{height / 2.0} \{stroke_width / 2.0},\{height - stroke_width / 2.0}"
      } else {
        "\{width - stroke_width / 2.0},\{stroke_width / 2.0} \{stroke_width / 2.0},\{height / 2.0} \{width - stroke_width / 2.0},\{height - stroke_width / 2.0}"
      }
      @xml_emit.Element::new("polyline")
      .attr("points", points)
      .attr("fill", "none")
      .attr("stroke", stroke)
      .attr_num("stroke-width", stroke_width)
      .self_close()
      .build()
    }
    @graph.Diamond => {
      let points = if is_target {
        "0,\{height / 2.0} \{width / 2.0},\{height / 8.0} \{width},\{height / 2.0} \{width / 2.0},\{height * 0.9}"
      } else {
        "\{width / 8.0},\{height / 2.0} \{width * 0.6},\{height / 8.0} \{width * 1.1},\{height / 2.0} \{width * 0.6},\{height * 7.0 / 8.0}"
      }
      @xml_emit.Element::new("polygon")
      .attr("points", points)
      .attr("fill", "#FFFFFF")
      .attr("stroke", stroke)
      .attr_num("stroke-width", stroke_width)
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
      .attr_num("cx", cx)
      .attr_num("cy", radius)
      .attr_num("r", inner_radius)
      .attr("fill", "#FFFFFF")
      .attr("stroke", stroke)
      .attr_num("stroke-width", stroke_width)
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
        .attr("d", "M\{offset},0 \{offset},\{height}")
        .attr("fill", "#FFFFFF")
        .attr("stroke", stroke)
        .attr_num("stroke-width", stroke_width)
        .self_close()
        .build()
      } else {
        @xml_emit.Element::new("circle")
        .attr_num("cx", offset / 2.0 + 2.0)
        .attr_num("cy", height / 2.0)
        .attr_num("r", offset / 2.0)
        .attr("fill", "#FFFFFF")
        .attr("stroke", stroke)
        .attr_num("stroke-width", stroke_width)
        .self_close()
        .build()
      }

      let crow_path = if is_many {
        "M\{width - 3.0},\{height / 2.0} \{width + offset},\{height / 2.0} M\{offset + 3.0},\{height / 2.0} \{width + offset},0 M\{offset + 3.0},\{height / 2.0} \{width + offset},\{height}"
      } else {
        "M\{width - 3.0},\{height / 2.0} \{width + offset},\{height / 2.0} M\{offset * 2.0},0 \{offset * 2.0},\{height}"
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
      .attr("fill", "#FFFFFF")
      .attr("stroke", stroke)
      .attr_num("stroke-width", stroke_width)
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
  @xml_emit.Element::new("marker")
  .attr("id", id)
  .attr_num("markerWidth", marker_width)
  .attr_num("markerHeight", marker_height)
  .attr_num("refX", ref_x)
  .attr_num("refY", marker_height / 2.0)
  .attr("viewBox", "0 0 \{marker_width} \{marker_height}")
  .attr("orient", "auto")
  .attr("markerUnits", "userSpaceOnUse")
  .child(
    marker_body(
      arrowhead, is_target, stroke, stroke_width, width_raw, marker_height,
    ),
  )
  .build()
}

///|
fn marker_url_for_edge(
  svg : @svg.Svg,
  config : SvgConfig,
  marker_ids : Map[String, String],
  arrowhead : ArrowheadType,
  is_target : Bool,
  stroke : String,
  stroke_width : Double,
) -> String {
  if arrowhead == @graph.None {
    return ""
  }
  let key = marker_key(arrowhead, is_target, stroke, stroke_width)
  match marker_ids.get(key) {
    Some(id) => "url(#\{id})"
    None => {
      let id = defs_id(config, "mk-\{hash_u32(key)}")
      let def = marker_def(id, arrowhead, is_target, stroke, stroke_width)
      if def != "" {
        svg.add_def(def)
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
  svg : @svg.Svg,
  graph : Diagram,
  config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> Unit {
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
        svg.add_def(
          @svg.dots_pattern(
            defs_id(config, pattern_def_key(pattern)),
            stroke_color,
            bg_color,
          ),
        )
      "lines" =>
        svg.add_def(
          @svg.lines_pattern(
            defs_id(config, pattern_def_key(pattern)),
            stroke_color,
            bg_color,
          ),
        )
      "crosshatch" =>
        svg.add_def(
          @svg.crosshatch_pattern(
            defs_id(config, pattern_def_key(pattern)),
            stroke_color,
            bg_color,
          ),
        )
      "grain" =>
        svg.add_def(
          @svg.grain_pattern(
            defs_id(config, pattern_def_key(pattern)),
            stroke_color,
            bg_color,
          ),
        )
      _ => ()
    }
    overlay_rules.push(
      ".\{pattern_overlay_class(pattern)} {\n  fill: \{defs_url(config, pattern_def_key(pattern))};\n  mix-blend-mode: multiply;\n}",
    )
  }
  if !overlay_rules.is_empty() {
    let css = overlay_rules.join("\n")
    svg.add(
      @xml_emit.Element::new("style")
      .attr("type", "text/css")
      .cdata(css)
      .build(),
    )
  }
}

///|
/// Add sketch filter if any object uses sketch mode
fn add_sketch_filter(
  svg : @svg.Svg,
  graph : Diagram,
  config : SvgConfig,
) -> Unit {
  // Check if any object uses sketch mode
  let mut needs_sketch = false
  for obj in graph.shapes {
    if style_bool(obj.style.sketch, false) {
      needs_sketch = true
      break
    }
  }
  // Also check edges
  if not(needs_sketch) {
    for edge in graph.connections {
      if style_bool(edge.style.sketch, false) {
        needs_sketch = true
        break
      }
    }
  }
  if needs_sketch {
    svg.add_def(@svg.sketch_filter(defs_id(config, "sketch-filter")))
  }
}

///|
fn compute_graph_bounds(graph : Diagram) -> (Double, Double, Double, Double) {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  for obj in graph.shapes {
    match obj.box {
      Some(b) => {
        let left = b.x
        let top = b.y
        let right = b.x + b.width
        let bottom = b.y + b.height
        if first {
          min_x = left
          min_y = top
          max_x = right
          max_y = bottom
          first = false
        } else {
          if left < min_x {
            min_x = left
          }
          if top < min_y {
            min_y = top
          }
          if right > max_x {
            max_x = right
          }
          if bottom > max_y {
            max_y = bottom
          }
        }
      }
      None => ()
    }
  }
  // Include activation boxes (for sequence diagrams)
  for ab in graph.activation_boxes {
    let b = ab.1
    let left = b.x
    let top = b.y
    let right = b.x + b.width
    let bottom = b.y + b.height
    if first {
      min_x = left
      min_y = top
      max_x = right
      max_y = bottom
      first = false
    } else {
      if left < min_x {
        min_x = left
      }
      if top < min_y {
        min_y = top
      }
      if right > max_x {
        max_x = right
      }
      if bottom > max_y {
        max_y = bottom
      }
    }
  }
  // Include edge routes
  for edge in graph.connections {
    for point in edge.route {
      if first {
        min_x = point.x
        min_y = point.y
        max_x = point.x
        max_y = point.y
        first = false
      } else {
        if point.x < min_x {
          min_x = point.x
        }
        if point.y < min_y {
          min_y = point.y
        }
        if point.x > max_x {
          max_x = point.x
        }
        if point.y > max_y {
          max_y = point.y
        }
      }
    }
  }
  (min_x, min_y, max_x, max_y)
}

///|
/// Get the depth of an object ID (number of dots + 1)
/// e.g., "aws" = 1, "aws.vpc" = 2, "aws.vpc.subnet" = 3
fn get_object_depth(id : String) -> Int {
  let mut depth = 1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      depth = depth + 1
    }
  }
  depth
}

///|
fn is_container(obj : Shape) -> Bool {
  obj.child_ids.length() > 0
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
/// Sort objects by depth (parents before children) for proper SVG layering
fn sort_objects_by_depth(objects : Array[Shape]) -> Array[Shape] {
  let sorted = objects.copy()
  // Simple bubble sort by depth (shallow objects first)
  for i = 0; i < sorted.length(); i = i + 1 {
    for j = i + 1; j < sorted.length(); j = j + 1 {
      let depth_i = get_object_depth(sorted[i].id)
      let depth_j = get_object_depth(sorted[j].id)
      if depth_i > depth_j {
        let temp = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = temp
      }
    }
  }
  sorted
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
fn render_svg_markdown_label(svg : @svg.Svg, obj : Shape, box : Box) -> Unit {
  if obj.label == "" {
    return
  }
  let (x, y, width, height) = match obj.label_box {
    Some(label_box) =>
      (
        label_box.x,
        label_box.y,
        if label_box.width > 0.0 {
          label_box.width
        } else {
          box.width
        },
        if label_box.height > 0.0 {
          label_box.height
        } else {
          box.height
        },
      )
    None => (box.x, box.y, box.width, box.height)
  }
  if width <= 0.0 || height <= 0.0 {
    return
  }
  let md_html = @cmark_html.render(safe=false, strict=false, obj.label) catch {
    _ => obj.label
  }
  let div = @xml_emit.Element::new("div")
    .attr("xmlns", "http://www.w3.org/1999/xhtml")
    .attr("class", "md")
    .raw(md_html)
    .build()
  let foreign = @xml_emit.Element::new("foreignObject")
    .attr(
      "requiredFeatures", "http://www.w3.org/TR/SVG11/feature#Extensibility",
    )
    .attr_num("x", x)
    .attr_num("y", y)
    .attr_num("width", width)
    .attr_num("height", height)
    .raw(div)
    .build()
  svg.add(@xml_emit.Element::new("g").raw(foreign).build())
}

///|
fn render_svg_object(
  svg : @svg.Svg,
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
  // For background pass, only open groups in foreground pass
  let is_foreground = match pass {
    Foreground => true
    Background => false
  }
  let link_href = match obj.link {
    Some(v) => if v.trim() == "" { None } else { Some(v) }
    None => None
  }
  let has_link = link_href is Some(_)
  let should_wrap_link = has_link &&
    (if is_foreground {
      obj.shape_type == Text || obj.shape_type == Image
    } else {
      obj.shape_type != Text && obj.shape_type != Image
    })
  if should_wrap_link {
    let href = link_href.unwrap()
    svg.add(
      @xml_emit.Element::new("a")
      .attr("href", href)
      .attr("xlink:href", href)
      .open_tag(),
    )
  }
  // Apply tooltip if present (only in foreground pass to avoid double-wrapping)
  let has_tooltip = obj.tooltip is Some(_) && is_foreground
  if has_tooltip {
    svg.open_group_with_tooltip(obj.tooltip.unwrap())
  }
  // Apply sketch filter if enabled (only in foreground pass)
  let use_sketch = style_bool(obj.style.sketch, false) && is_foreground
  if use_sketch {
    svg.open_group_with_filter(defs_id(config, "sketch-filter"))
  }
  // Get style values
  let raw_fill = style_string(obj.style.fill, "N7")
  let base_fill = resolve_theme_color(raw_fill, theme, use_css_theme_vars)
  // Apply fill pattern if specified
  let fill = resolve_fill_with_pattern(
    base_fill,
    obj.style.fill_pattern,
    config,
  )
  let raw_stroke = style_string(obj.style.stroke, "N1")
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
  match shape_type_name(obj.shape_type) {
    "text" =>
      // Text shape - no border, just the label (foreground only)
      ()
    "image" =>
      // Image shape - render external image (foreground only)
      if is_foreground && obj.icon is Some(url) {
        svg.add(
          @xml_emit.Element::new("image")
          .attr("href", url)
          .attr_num("x", box.x)
          .attr_num("y", box.y)
          .attr_num("width", box.width)
          .attr_num("height", box.height)
          .attr("preserveAspectRatio", "xMidYMid meet")
          .self_close()
          .build(),
        )
      }
    "code" => {
      // Code shape - render in appropriate pass
      render_svg_code(
        svg,
        box,
        obj.label,
        fill,
        stroke,
        stroke_width,
        config,
        pass~,
      )
      if is_foreground {
        if use_sketch {
          svg.close_group()
        }
        if has_tooltip {
          svg.close_group()
        }
      }
      if should_wrap_link {
        svg.add(@xml_emit.Element::new("a").close_tag())
      }
      return // Don't render the default label
    }
    "class" => {
      // UML class shape - render in appropriate pass
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
        pass~,
      )
      if is_foreground {
        if use_sketch {
          svg.close_group()
        }
        if has_tooltip {
          svg.close_group()
        }
      }
      if should_wrap_link {
        svg.add(@xml_emit.Element::new("a").close_tag())
      }
      return // Don't render the default label
    }
    "sql_table" => {
      // SQL table shape with header and columns - render in appropriate pass
      render_svg_sql_table(
        svg,
        box,
        obj.label,
        object_children(obj, all_objects),
        obj.style,
        fill,
        stroke,
        stroke_width,
        pass~,
        config,
        theme,
        use_css_theme_vars,
      )
      if is_foreground {
        if use_sketch {
          svg.close_group()
        }
        if has_tooltip {
          svg.close_group()
        }
      }
      if should_wrap_link {
        svg.add(@xml_emit.Element::new("a").close_tag())
      }
      return // Don't render the default label
    }
    "circle" | "oval" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          let mcx = mbox.x + mbox.width / 2.0
          let mcy = mbox.y + mbox.height / 2.0
          svg.add(
            @svg.ellipse(
              mcx,
              mcy,
              mbox.width / 2.0,
              mbox.height / 2.0,
              fill~,
              stroke~,
              stroke_width~,
            ),
          )
        }
        let cx = box.x + box.width / 2.0
        let cy = box.y + box.height / 2.0
        svg.add(
          @svg.ellipse(
            cx,
            cy,
            box.width / 2.0,
            box.height / 2.0,
            fill~,
            stroke~,
            stroke_width~,
          ),
        )
      }
    "cylinder" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_cylinder(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_cylinder(svg, box, fill, stroke, stroke_width)
      }
    "diamond" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_diamond(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_diamond(svg, box, fill, stroke, stroke_width)
      }
    "hexagon" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_hexagon(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_hexagon(svg, box, fill, stroke, stroke_width)
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
          render_svg_parallelogram(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_parallelogram(svg, box, fill, stroke, stroke_width)
      }
    "person" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_person(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_person(svg, box, fill, stroke, stroke_width)
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
          render_svg_cloud(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_cloud(svg, box, fill, stroke, stroke_width)
      }
    "document" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_document(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_document(svg, box, fill, stroke, stroke_width)
      }
    "queue" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_queue(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_queue(svg, box, fill, stroke, stroke_width)
      }
    "stored_data" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_stored_data(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_stored_data(svg, box, fill, stroke, stroke_width)
      }
    "page" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_page(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_page(svg, box, fill, stroke, stroke_width)
      }
    "package" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_package(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_package(svg, box, fill, stroke, stroke_width)
      }
    "step" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_step(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_step(svg, box, fill, stroke, stroke_width)
      }
    "callout" =>
      if not(is_foreground) {
        if is_multiple {
          let mbox = shifted_multiple_box(box)
          render_svg_callout(svg, mbox, fill, stroke, stroke_width)
        }
        render_svg_callout(svg, box, fill, stroke, stroke_width)
      }
    _ =>
      if not(is_foreground) {
        if is_three_d {
          render_svg_3d_rect(
            svg,
            obj.id,
            box,
            fill,
            side_fill,
            stroke,
            stroke_width,
            config,
          )
        } else {
          if is_multiple {
            let mbox = shifted_multiple_box(box)
            svg.add(
              @svg.rect(
                mbox.x,
                mbox.y,
                mbox.width,
                mbox.height,
                fill~,
                stroke~,
                stroke_width~,
                rx=Some(border_radius),
                ry=Some(border_radius),
              ),
            )
          }
          svg.add(
            @svg.rect(
              box.x,
              box.y,
              box.width,
              box.height,
              fill~,
              stroke~,
              stroke_width~,
              rx=Some(border_radius),
              ry=Some(border_radius),
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
        @svg.rect(
          box.x + inset,
          box.y + inset,
          box.width - inset * 2.0,
          box.height - inset * 2.0,
          fill="none",
          stroke~,
          stroke_width~,
          rx=Some(border_radius),
          ry=Some(border_radius),
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
  // Foreground pass: render icon and label
  if is_foreground {
    let cx = box.x + box.width / 2.0
    let cy = box.y + box.height / 2.0
    // Check if icon is present (non-image shapes)
    let has_icon = obj.icon is Some(_) && obj.shape_type != Image
    if has_icon {
      // Render icon above label
      let icon_size = 24.0
      let icon_y = cy - config.font_size.to_double() / 2.0 - icon_size / 2.0
      let icon_url = obj.icon.unwrap()
      let icon_x = cx - icon_size / 2.0
      let icon_top = icon_y - icon_size / 2.0
      svg.add(
        @xml_emit.Element::new("image")
        .attr("href", icon_url)
        .attr_num("x", icon_x)
        .attr_num("y", icon_top)
        .attr_num("width", icon_size)
        .attr_num("height", icon_size)
        .attr("preserveAspectRatio", "xMidYMid meet")
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
      // Use custom font-family if specified in style, otherwise use config
      let font_family = style_string(obj.style.font_family, config.font_family)
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
        style_is_mono(obj.style.font_family)
      let label_text = transform_label_text(obj.label, text_transform)
      let label_dims = @text_metrics.measure_label(
        label_text, font_size, is_mono, is_bold, is_italic,
      )
      let label_overflows = label_dims.width > box.width ||
        label_dims.height > box.height
      let inner_box = shape_inner_box_for_label(obj, box, label_dims)
      let is_grid_container = is_container(obj) &&
        (obj.grid_rows is Some(_) || obj.grid_columns is Some(_))
      let (label_tl_x, label_tl_y, label_box_width) = match obj.label_box {
        Some(label_box) =>
          (
            label_box.x,
            label_box.y,
            if label_box.width > 0.0 {
              label_box.width
            } else {
              label_dims.width
            },
          )
        None =>
          if is_container(obj) && !is_grid_container {
            (
              box.x + (box.width - label_dims.width) / 2.0,
              box.y - LABEL_PADDING - label_dims.height,
              label_dims.width,
            )
          } else if is_grid_container {
            (
              inner_box.x + (inner_box.width - label_dims.width) / 2.0,
              inner_box.y + LABEL_PADDING,
              label_dims.width,
            )
          } else if has_outside_bottom_label(obj) || label_overflows {
            (
              box.x + (box.width - label_dims.width) / 2.0,
              box.y + box.height + LABEL_PADDING,
              label_dims.width,
            )
          } else if has_icon {
            (
              inner_box.x + (inner_box.width - label_dims.width) / 2.0,
              inner_box.y + LABEL_PADDING,
              label_dims.width,
            )
          } else {
            (
              inner_box.x + (inner_box.width - label_dims.width) / 2.0,
              inner_box.y + (inner_box.height - label_dims.height) / 2.0,
              label_dims.width,
            )
          }
      }
      let label_x = label_tl_x + label_box_width / 2.0
      let label_baseline_y = label_tl_y + font_size.to_double()
      let text_styles : Array[String] = ["fill: \{text_color}"]
      if is_italic {
        text_styles.push("font-style: italic")
      }
      if is_bold {
        text_styles.push("font-weight: 700")
      }
      svg.add(
        @svg.styled_text(
          label_x,
          label_baseline_y,
          label_text,
          font_family~,
          font_size~,
          dominant_baseline="alphabetic",
          text_transform~,
          extra_style=text_styles.join("; "),
        ),
      )
    }
    // Close sketch filter group if opened
    if use_sketch {
      svg.close_group()
    }
    // Close tooltip group if opened
    if has_tooltip {
      svg.close_group()
    }
  }
  if is_foreground {
    render_object_appendix_icons(svg, obj, box)
  }
  if should_wrap_link {
    svg.add(@xml_emit.Element::new("a").close_tag())
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
  let constraints : Array[String] = []
  for cls in child.classes {
    match strip_prefix(cls, SQL_CONSTRAINT_PREFIX) {
      Some(v) => constraints.push(v)
      None => ()
    }
  }
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
  config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> Unit {
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
      // Background pass: render shapes (rectangles, lines)
      // Draw main rectangle
      svg.add(
        @svg.rect(
          box.x,
          box.y,
          box.width,
          box.height,
          fill~,
          stroke~,
          stroke_width~,
        ),
      )
      // Draw header background using the border color, matching D2 SQL table style.
      svg.add(
        @xml_emit.Element::new("rect")
        .attr_num("x", box.x)
        .attr_num("y", box.y)
        .attr_num("width", box.width)
        .attr_num("height", row_height)
        .attr("fill", stroke)
        .self_close()
        .build(),
      )
      // Draw row separators
      let mut y = box.y + row_height
      for i in 0..<children.length() {
        svg.add(
          @svg.line(box.x, y, box.x + box.width, y, stroke~, stroke_width=2.0),
        )
        y = y + row_height
      }
    }
    Foreground => {
      // Foreground pass: render text (table name, column names)
      let header_center_y = box.y + row_height / 2.0
      let header_text_y = header_center_y + header_dims.height / 4.0
      svg.add(
        @xml_emit.Element::new("text")
        .attr_num("x", box.x + SQL_TABLE_HEADER_PADDING)
        .attr_num("y", header_text_y)
        .attr("text-anchor", "start")
        .attr("font-family", config.font_family)
        .attr_int("font-size", header_font_size)
        .attr("fill", header_text_color)
        .text(label)
        .build(),
      )
      let name_x = box.x + SQL_TABLE_NAME_PADDING
      let type_x = name_x + longest_name_width + SQL_TABLE_TYPE_PADDING
      let constraint_x = box.x + box.width - SQL_TABLE_NAME_PADDING
      for i, child in children {
        let row_center_y = box.y +
          row_height * (i.to_double() + 1.0) +
          row_height / 2.0
        let text_y = row_center_y + base_font_size.to_double() / 4.0
        let col_name = get_short_name(child.id)
        svg.add(
          @xml_emit.Element::new("text")
          .attr_num("x", name_x)
          .attr_num("y", text_y)
          .attr("text-anchor", "start")
          .attr("font-family", config.font_family)
          .attr_int("font-size", base_font_size)
          .attr("fill", name_text_color)
          .text(col_name)
          .build(),
        )
        svg.add(
          @xml_emit.Element::new("text")
          .attr_num("x", type_x)
          .attr_num("y", text_y)
          .attr("text-anchor", "start")
          .attr("font-family", config.font_family)
          .attr_int("font-size", base_font_size)
          .attr("fill", type_text_color)
          .text(child.label)
          .build(),
        )
        let constraint = sql_table_constraint_abbr(child)
        if constraint.length() > 0 {
          svg.add(
            @xml_emit.Element::new("text")
            .attr_num("x", constraint_x)
            .attr_num("y", text_y)
            .attr("text-anchor", "end")
            .attr("font-family", config.font_family)
            .attr_int("font-size", base_font_size)
            .attr("fill", constraint_text_color)
            .text(constraint)
            .build(),
          )
        }
      }
    }
  }
}

///|
/// Get the short name from a dotted ID (e.g., "users.id" -> "id")
fn get_short_name(id : String) -> String {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot >= 0 && last_dot < id.length() - 1 {
    let buf = StringBuilder::new()
    for i = last_dot + 1; i < id.length(); i = i + 1 {
      match id[i].to_char() {
        Some(c) => buf.write_char(c)
        None => ()
      }
    }
    buf.to_string()
  } else {
    id
  }
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
  let raw_name = trim_double_quotes(get_short_name(child.id))
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
  let visibility_color = style_color(None, "B2", theme, use_css_theme_vars)
  let name_color = style_color(None, "N1", theme, use_css_theme_vars)
  let type_color = style_color(None, "AA2", theme, use_css_theme_vars)
  let visibility_x = box.x + CLASS_PREFIX_PADDING
  let name_x = visibility_x + CLASS_PREFIX_WIDTH
  let type_x = box.x + box.width - CLASS_TYPE_PADDING
  match pass {
    Background => {
      svg.add(
        @svg.rect(
          box.x,
          box.y,
          box.width,
          box.height,
          fill~,
          stroke~,
          stroke_width~,
        ),
      )
      svg.add(
        @xml_emit.Element::new("rect")
        .attr_num("x", box.x)
        .attr_num("y", box.y)
        .attr_num("width", box.width)
        .attr_num("height", header_height)
        .attr("fill", stroke)
        .self_close()
        .build(),
      )
    }
    Foreground => {
      let header_text_top = box.y + (header_height - label_dims.height) / 2.0
      let name_y = header_text_top + base_font_size.to_double()
      svg.add(
        @xml_emit.Element::new("text")
        .attr_num("x", box.x + box.width / 2.0)
        .attr_num("y", name_y)
        .attr("text-anchor", "middle")
        .attr("font-family", "'SF Mono', 'Fira Code', 'Consolas', monospace")
        .attr_int("font-size", header_font_size)
        .attr("fill", style_color(None, "N7", theme, use_css_theme_vars))
        .text(label)
        .build(),
      )
      let mut row_top = box.y + header_height
      for m in fields {
        let text_y = row_top +
          row_height / 2.0 +
          base_font_size.to_double() / 4.0
        svg.add(
          @xml_emit.Element::new("text")
          .attr_num("x", visibility_x)
          .attr_num("y", text_y)
          .attr("text-anchor", "start")
          .attr("font-family", "'SF Mono', 'Fira Code', 'Consolas', monospace")
          .attr_int("font-size", base_font_size)
          .attr("fill", visibility_color)
          .text(m.visibility)
          .build(),
        )
        svg.add(
          @xml_emit.Element::new("text")
          .attr_num("x", name_x)
          .attr_num("y", text_y)
          .attr("text-anchor", "start")
          .attr("font-family", "'SF Mono', 'Fira Code', 'Consolas', monospace")
          .attr_int("font-size", base_font_size)
          .attr("fill", name_color)
          .attr(
            "text-decoration",
            if m.underline {
              "underline"
            } else {
              "none"
            },
          )
          .text(m.name)
          .build(),
        )
        if m.type_name != "" {
          svg.add(
            @xml_emit.Element::new("text")
            .attr_num("x", type_x)
            .attr_num("y", text_y)
            .attr("text-anchor", "end")
            .attr(
              "font-family", "'SF Mono', 'Fira Code', 'Consolas', monospace",
            )
            .attr_int("font-size", base_font_size)
            .attr("fill", type_color)
            .text(m.type_name)
            .build(),
          )
        }
        row_top = row_top + row_height
      }
      let border_radius = style_double(style.border_radius, 0.0)
      let (sep_x1, sep_x2) = if border_radius > 0.0 && methods.is_empty() {
        (box.x + border_radius, box.x + box.width - border_radius)
      } else {
        (box.x, box.x + box.width)
      }
      svg.add(
        @svg.line(sep_x1, row_top, sep_x2, row_top, stroke~, stroke_width=1.0),
      )
      for m in methods {
        let text_y = row_top +
          row_height / 2.0 +
          base_font_size.to_double() / 4.0
        svg.add(
          @xml_emit.Element::new("text")
          .attr_num("x", visibility_x)
          .attr_num("y", text_y)
          .attr("text-anchor", "start")
          .attr("font-family", "'SF Mono', 'Fira Code', 'Consolas', monospace")
          .attr_int("font-size", base_font_size)
          .attr("fill", visibility_color)
          .text(m.visibility)
          .build(),
        )
        svg.add(
          @xml_emit.Element::new("text")
          .attr_num("x", name_x)
          .attr_num("y", text_y)
          .attr("text-anchor", "start")
          .attr("font-family", "'SF Mono', 'Fira Code', 'Consolas', monospace")
          .attr_int("font-size", base_font_size)
          .attr("fill", name_color)
          .attr(
            "text-decoration",
            if m.underline {
              "underline"
            } else {
              "none"
            },
          )
          .text(m.name)
          .build(),
        )
        if m.type_name != "" {
          svg.add(
            @xml_emit.Element::new("text")
            .attr_num("x", type_x)
            .attr_num("y", text_y)
            .attr("text-anchor", "end")
            .attr(
              "font-family", "'SF Mono', 'Fira Code', 'Consolas', monospace",
            )
            .attr_int("font-size", base_font_size)
            .attr("fill", type_color)
            .text(m.type_name)
            .build(),
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
  _fill : String,
  stroke : String,
  stroke_width : Double,
  _config : SvgConfig,
  pass? : RenderPass = Foreground,
) -> Unit {
  // D2 parity: render both light and dark code groups and switch visibility via CSS.
  let code_bgs = [("light-code", "#ffffff"), ("dark-code", "#1e1e2e")]
  let padding = 8.0
  match pass {
    Background => ()
    Foreground => {
      let lines = split_lines(label)
      for code_bg in code_bgs {
        svg.add(
          @xml_emit.Element::new("g")
          .attr("transform", "translate(\{box.x},\{box.y})")
          .attr("class", code_bg.0)
          .open_tag(),
        )
        svg.add(
          @xml_emit.Element::new("rect")
          .attr_num("width", box.width)
          .attr_num("height", box.height)
          .attr("stroke", stroke)
          .attr("class", "shape")
          .attr("style", "fill:\{code_bg.1};stroke-width:\{stroke_width};")
          .self_close()
          .build(),
        )
        svg.open_group("translate(\{padding},\{padding})")
        for i, line in lines {
          let y_em = "\{1.0 + i.to_double() * 1.3}em"
          let raw = if code_bg.0 == "dark-code" {
            code_line_svg_raw_dark(line)
          } else {
            code_line_svg_raw(line)
          }
          let text = @xml_emit.Element::new("text")
            .attr("class", "text-mono")
            .attr("x", "0")
            .attr("y", y_em)
            .raw(raw)
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
fn code_line_svg_raw(line : String) -> String {
  match code_find_substring(line, ":=") {
    Some(idx) => {
      let prefix = code_slice(line, 0, idx)
      let suffix = code_slice(line, idx + 2, line.length())
      code_svg_escape(prefix) +
      "<tspan fill=\"#000000\" class=\"text-mono-bold\">:=</tspan>" +
      code_svg_escape(suffix)
    }
    None =>
      if line.has_prefix("defer ") {
        let suffix = code_slice(line, 5, line.length())
        "<tspan fill=\"#000000\" class=\"text-mono-bold\">defer</tspan>" +
        code_svg_escape(suffix)
      } else {
        code_svg_escape(line)
      }
  }
}

///|
fn code_line_svg_raw_dark(line : String) -> String {
  if line == "" {
    return ""
  }
  "<tspan fill=\"#cdd6f4\">\{code_svg_escape(line)}</tspan>"
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
fn code_find_substring(s : String, pattern : String) -> Int? {
  if pattern.length() == 0 {
    return Some(0)
  }
  if pattern.length() > s.length() {
    return None
  }
  let limit = s.length() - pattern.length()
  for i = 0; i <= limit; i = i + 1 {
    if code_slice(s, i, i + pattern.length()) == pattern {
      return Some(i)
    }
  }
  None
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
fn render_svg_cylinder(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let arc_depth = 24.0
  let arc_height = if box.height < arc_depth * 2.0 {
    box.height / 2.0
  } else {
    arc_depth
  }
  let multiplier = 0.45
  let x0 = box.x
  let y0 = box.y
  let w = box.width
  let h = box.height
  let top_y = y0 + arc_height
  let bottom_y = y0 + h - arc_height
  let outer = @svg.PathBuilder::new()
    .move_to(x0, top_y)
    .cubic_to(x0, y0, x0 + w * multiplier, y0, x0 + w / 2.0, y0)
    .cubic_to(x0 + w - w * multiplier, y0, x0 + w, y0, x0 + w, top_y)
    .line_to(x0 + w, bottom_y)
    .cubic_to(
      x0 + w,
      y0 + h,
      x0 + w - w * multiplier,
      y0 + h,
      x0 + w / 2.0,
      y0 + h,
    )
    .cubic_to(x0 + w * multiplier, y0 + h, x0, y0 + h, x0, bottom_y)
    .line_to(x0, top_y)
    .close()
    .build()
  svg.add(@svg.path(outer, fill~, stroke~, stroke_width~))
  let inner = @svg.PathBuilder::new()
    .move_to(x0, top_y)
    .cubic_to(
      x0,
      y0 + arc_height * 2.0,
      x0 + w * multiplier,
      y0 + arc_height * 2.0,
      x0 + w / 2.0,
      y0 + arc_height * 2.0,
    )
    .cubic_to(
      x0 + w - w * multiplier,
      y0 + arc_height * 2.0,
      x0 + w,
      y0 + arc_height * 2.0,
      x0 + w,
      top_y,
    )
    .build()
  svg.add(@svg.path(inner, fill~, stroke~, stroke_width~))
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
) -> Unit {
  // Ported from ../d2/lib/shape/shape_diamond.go (diamondPath).
  let sx = box.width / 77.0
  let sy = box.height / 76.9
  let px = fn(v : Double) { box.x + v * sx }
  let py = fn(v : Double) { box.y + v * sy }
  let pb = @svg.PathBuilder::new()
    .move_to(px(38.5), py(76.9))
    .cubic_to(px(38.2), py(76.9), px(38.0), py(76.8), px(37.8), py(76.6))
    .line_to(px(0.3), py(39.2))
    .cubic_to(px(-0.1), py(38.8), px(-0.1), py(38.2), px(0.3), py(37.8))
    .line_to(px(37.8), py(0.3))
    .cubic_to(px(38.2), py(-0.1), px(38.8), py(-0.1), px(39.2), py(0.3))
    .line_to(px(76.7), py(37.8))
    .cubic_to(px(77.1), py(38.2), px(77.1), py(38.8), px(76.7), py(39.2))
    .line_to(px(39.2), py(76.6))
    .cubic_to(px(39.0), py(76.8), px(38.8), py(76.9), px(38.5), py(76.9))
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_hexagon(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let inset = box.width * 0.25
  let pb = @svg.PathBuilder::new()
    .move_to(box.x + inset, box.y)
    .line_to(box.x + box.width - inset, box.y)
    .line_to(box.x + box.width, box.y + box.height / 2.0)
    .line_to(box.x + box.width - inset, box.y + box.height)
    .line_to(box.x + inset, box.y + box.height)
    .line_to(box.x, box.y + box.height / 2.0)
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_parallelogram(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let wedge = if box.width < 52.0 { box.width / 2.0 } else { 26.0 }
  let pb = @svg.PathBuilder::new()
    .move_to(box.x + wedge, box.y)
    .line_to(box.x + box.width, box.y)
    .line_to(box.x + box.width - wedge, box.y + box.height)
    .line_to(box.x, box.y + box.height)
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_person(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // diago-style person shape based on 68.3 x 77.4 coordinate system
  let sx = box.width / 68.3
  let sy = box.height / 77.4
  let x = box.x
  let y = box.y
  // Build path using PathBuilder
  // The path draws: bottom line, left leg, left shoulder, head circle, right shoulder, right leg
  let path_data = @svg.PathBuilder::new()
    // Start at bottom right
    .move_to(x + 68.3 * sx, y + 77.4 * sy)
    // Bottom line
    .h_to(x)
    // Left leg
    .v_rel(-1.1 * sy)
    .cubic_rel(0.0, -13.2 * sy, 7.5 * sx, -25.1 * sy, 19.3 * sx, -30.8 * sy)
    // Left shoulder curve
    .cubic_to(
      x + 12.8 * sx,
      y + 40.9 * sy,
      x + 8.9 * sx,
      y + 33.4 * sy,
      x + 8.9 * sx,
      y + 25.2 * sy,
    )
    // Head left half
    .cubic_to(
      x + 8.9 * sx,
      y + 11.3 * sy,
      x + 20.2 * sx,
      y + 0.0 * sy,
      x + 34.1 * sx,
      y + 0.0 * sy,
    )
    // Head right half
    .cubic_rel(13.9 * sx, 0.0, 25.2 * sx, 11.3 * sy, 25.2 * sx, 25.2 * sy)
    // Right shoulder
    .cubic_rel(0.0, 8.2 * sy, -3.8 * sx, 15.6 * sy, -10.4 * sx, 20.4 * sy)
    // Right leg
    .cubic_rel(11.8 * sx, 5.7 * sy, 19.3 * sx, 17.6 * sy, 19.3 * sx, 30.8 * sy)
    .v_rel(1.0 * sy)
    .close()
    .build()
  svg.add(@svg.path(path_data, fill~, stroke~, stroke_width~))
}

///|
fn render_svg_cloud(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // D2 cloud path (scaled from 834x523 reference box).
  let sx = box.width / 834.0
  let sy = box.height / 523.0
  let mut cur_x = box.x + 137.833 * sx
  let mut cur_y = box.y + 182.833 * sy
  let mut pb = @svg.PathBuilder::new().move_to(cur_x, cur_y)
  fn rel(
    cur_x : Double,
    cur_y : Double,
    dx : Double,
    dy : Double,
    sx : Double,
    sy : Double,
  ) -> (Double, Double) {
    (cur_x + dx * sx, cur_y + dy * sy)
  }

  fn abs(
    box_x : Double,
    box_y : Double,
    x : Double,
    y : Double,
    sx : Double,
    sy : Double,
  ) -> (Double, Double) {
    (box_x + x * sx, box_y + y * sy)
  }

  let (x1, y1) = rel(cur_x, cur_y, 0.0, 5.556, sx, sy)
  let (x2, y2) = rel(cur_x, cur_y, -5.556, 11.111, sx, sy)
  let (x3, y3) = rel(cur_x, cur_y, -11.111, 11.111, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3)
  cur_x = x3
  cur_y = y3
  let (x1, y1) = rel(cur_x, cur_y, -70.833, 6.944, sx, sy)
  let (x2, y2) = rel(cur_x, cur_y, -126.389, 77.778, sx, sy)
  let (x3, y3) = rel(cur_x, cur_y, -126.389, 163.889, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3)
  cur_x = x3
  cur_y = y3
  let (x1, y1) = rel(cur_x, cur_y, 0.0, 91.667, sx, sy)
  let (x2, y2) = rel(cur_x, cur_y, 62.5, 165.278, sx, sy)
  let (x3, y3) = rel(cur_x, cur_y, 141.667, 165.278, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3)
  cur_x = x3
  cur_y = y3
  cur_x = cur_x + 537.5 * sx
  pb = pb.h_to(cur_x)
  let (x1, y1) = rel(cur_x, cur_y, 84.723, 0.0, sx, sy)
  let (x2, y2) = rel(cur_x, cur_y, 154.167, -79.167, sx, sy)
  let (x3, y3) = rel(cur_x, cur_y, 154.167, -175.0, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3)
  cur_x = x3
  cur_y = y3
  let (x1, y1) = rel(cur_x, cur_y, 0.0, -91.667, sx, sy)
  let (x2, y2) = rel(cur_x, cur_y, -63.89, -168.056, sx, sy)
  let (x3, y3) = rel(cur_x, cur_y, -144.444, -173.611, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3)
  cur_x = x3
  cur_y = y3
  let (x1, y1) = rel(cur_x, cur_y, -5.556, 0.0, sx, sy)
  let (x2, y2) = rel(cur_x, cur_y, -11.111, -4.167, sx, sy)
  let (x3, y3) = rel(cur_x, cur_y, -12.5, -11.111, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3)
  cur_x = x3
  cur_y = y3
  let (x1, y1) = rel(cur_x, cur_y, -18.056, -93.055, sx, sy)
  let (x2, y2) = rel(cur_x, cur_y, -101.39, -162.5, sx, sy)
  let (x3, y3) = rel(cur_x, cur_y, -198.611, -162.5, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3)
  cur_x = x3
  cur_y = y3
  let (x1, y1) = rel(cur_x, cur_y, -63.889, 0.0, sx, sy)
  let (x2, y2) = rel(cur_x, cur_y, -120.834, 29.167, sx, sy)
  let (x3, y3) = rel(cur_x, cur_y, -156.944, 75.0, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3)
  cur_x = x3
  cur_y = y3
  let (x1, y1) = rel(cur_x, cur_y, -4.167, 5.556, sx, sy)
  let (x2, y2) = rel(cur_x, cur_y, -11.111, 6.945, sx, sy)
  let (x3, y3) = rel(cur_x, cur_y, -15.278, 5.556, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3)
  cur_x = x3
  cur_y = y3
  let (x1, y1) = rel(cur_x, cur_y, -13.889, -5.556, sx, sy)
  let (x2, y2) = rel(cur_x, cur_y, -29.166, -8.333, sx, sy)
  let (x3, y3) = rel(cur_x, cur_y, -45.833, -8.333, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3)
  cur_x = x3
  cur_y = y3
  let (x1, y1) = abs(box.x, box.y, 196.167, 71.722, sx, sy)
  let (x2, y2) = abs(box.x, box.y, 143.389, 120.333, sx, sy)
  let (x3, y3) = abs(box.x, box.y, 137.833, 182.833, sx, sy)
  pb = pb.cubic_to(x1, y1, x2, y2, x3, y3).close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_document(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let base_y = box.height * (16.3 / 18.925)
  let cp1_y = box.height * (12.8 / 18.925)
  let cp2_y = box.height * (19.8 / 18.925)
  let pb = @svg.PathBuilder::new()
    .move_to(box.x, box.y + base_y)
    .line_to(box.x, box.y)
    .line_to(box.x + box.width, box.y)
    .line_to(box.x + box.width, box.y + base_y)
    .cubic_to(
      box.x + box.width * (5.0 / 6.0),
      box.y + cp1_y,
      box.x + box.width * (2.0 / 3.0),
      box.y + cp1_y,
      box.x + box.width * 0.5,
      box.y + base_y,
    )
    .cubic_to(
      box.x + box.width * (1.0 / 3.0),
      box.y + cp2_y,
      box.x + box.width * (1.0 / 6.0),
      box.y + cp2_y,
      box.x,
      box.y + base_y,
    )
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_queue(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Ported from ../d2/lib/shape/shape_queue.go (queueOuterPath/queueInnerPath).
  let arc_w = if box.width < 48.0 { box.width / 2.0 } else { 24.0 }
  let m = 0.45
  let outer = @svg.PathBuilder::new()
    .move_to(box.x + arc_w, box.y)
    .line_to(box.x + box.width - arc_w, box.y)
    .cubic_to(
      box.x + box.width,
      box.y,
      box.x + box.width,
      box.y + box.height * m,
      box.x + box.width,
      box.y + box.height * 0.5,
    )
    .cubic_to(
      box.x + box.width,
      box.y + box.height - box.height * m,
      box.x + box.width,
      box.y + box.height,
      box.x + box.width - arc_w,
      box.y + box.height,
    )
    .line_to(box.x + arc_w, box.y + box.height)
    .cubic_to(
      box.x + arc_w * m,
      box.y + box.height,
      box.x,
      box.y + box.height - box.height * m,
      box.x,
      box.y + box.height * 0.5,
    )
    .cubic_to(
      box.x,
      box.y + box.height * m,
      box.x + arc_w * m,
      box.y,
      box.x + arc_w,
      box.y,
    )
    .close()
  svg.add(@svg.path(outer.build(), fill~, stroke~, stroke_width~))
  let inner = @svg.PathBuilder::new()
    .move_to(box.x + box.width - arc_w, box.y)
    .cubic_to(
      box.x + box.width - 2.0 * arc_w,
      box.y,
      box.x + box.width - 2.0 * arc_w,
      box.y + box.height * m,
      box.x + box.width - 2.0 * arc_w,
      box.y + box.height * 0.5,
    )
    .cubic_to(
      box.x + box.width - 2.0 * arc_w,
      box.y + box.height - box.height * m,
      box.x + box.width - 2.0 * arc_w,
      box.y + box.height,
      box.x + box.width - arc_w,
      box.y + box.height,
    )
  svg.add(@svg.path(inner.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_stored_data(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Stored data (curved sides)
  let wedge = if box.width < 30.0 { box.width / 2.0 } else { 15.0 }
  let m = 0.27
  let pb = @svg.PathBuilder::new()
    .move_to(box.x + wedge, box.y)
    .line_to(box.x + box.width - wedge, box.y)
    .cubic_to(
      box.x + box.width - wedge * m,
      box.y,
      box.x + box.width,
      box.y + box.height * 0.25,
      box.x + box.width,
      box.y + box.height * 0.5,
    )
    .cubic_to(
      box.x + box.width,
      box.y + box.height * 0.75,
      box.x + box.width - wedge * m,
      box.y + box.height,
      box.x + box.width - wedge,
      box.y + box.height,
    )
    .line_to(box.x + wedge, box.y + box.height)
    .cubic_to(
      box.x + wedge * m,
      box.y + box.height,
      box.x,
      box.y + box.height * 0.75,
      box.x,
      box.y + box.height * 0.5,
    )
    .cubic_to(
      box.x,
      box.y + box.height * 0.25,
      box.x + wedge * m,
      box.y,
      box.x + wedge,
      box.y,
    )
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_page(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Page with folded corner
  let fold = if box.width < 40.0 { box.width * 0.25 } else { 20.0 }
  let pb = @svg.PathBuilder::new()
    .move_to(box.x, box.y)
    .line_to(box.x + box.width - fold, box.y)
    .line_to(box.x + box.width, box.y + fold)
    .line_to(box.x + box.width, box.y + box.height)
    .line_to(box.x, box.y + box.height)
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
  // Fold line
  let fold_pb = @svg.PathBuilder::new()
    .move_to(box.x + box.width, box.y + box.height)
    .line_to(box.x, box.y + box.height)
    .line_to(box.x, box.y)
    .line_to(box.x + box.width - fold, box.y)
    .line_to(box.x + box.width - fold, box.y + fold)
    .line_to(box.x + box.width, box.y + fold)
    .line_to(box.x + box.width, box.y + box.height)
    .close()
  svg.add(@svg.path(fold_pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_package(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // UML package with top flap
  let mut tab_w = box.width * 0.5
  if box.width >= 100.0 {
    if tab_w < 50.0 {
      tab_w = 50.0
    } else if tab_w > 150.0 {
      tab_w = 150.0
    }
  }
  let h20 = box.height * 0.2
  let tab_h = if 55.0 < h20 { 55.0 } else { h20 }
  let pb = @svg.PathBuilder::new()
    .move_to(box.x, box.y)
    .line_to(box.x + tab_w, box.y)
    .line_to(box.x + tab_w, box.y + tab_h)
    .line_to(box.x + box.width, box.y + tab_h)
    .line_to(box.x + box.width, box.y + box.height)
    .line_to(box.x, box.y + box.height)
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_step(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Chevron/arrow pointing right
  let wedge = if box.width < 70.0 { box.width / 2.0 } else { 35.0 }
  let pb = @svg.PathBuilder::new()
    .move_to(box.x, box.y)
    .line_to(box.x + box.width - wedge, box.y)
    .line_to(box.x + box.width, box.y + box.height / 2.0)
    .line_to(box.x + box.width - wedge, box.y + box.height)
    .line_to(box.x, box.y + box.height)
    .line_to(box.x + wedge, box.y + box.height / 2.0)
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_callout(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let tip_w = if box.width < 60.0 { box.width / 2.0 } else { 30.0 }
  let tip_h = if box.height < 90.0 { box.height / 2.0 } else { 45.0 }
  let main_h = box.height - tip_h
  let mid_x = (box.x + box.width / 2.0 + 0.5).to_int().to_double()
  let pb = @svg.PathBuilder::new()
    .move_to(box.x, box.y)
    .line_to(box.x, box.y + main_h)
    .line_to(mid_x, box.y + main_h)
    .line_to(mid_x, box.y + box.height)
    .line_to(mid_x + tip_w, box.y + main_h)
    .line_to(box.x + box.width, box.y + main_h)
    .line_to(box.x + box.width, box.y)
    .line_to(box.x, box.y)
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
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
  obj_id : String,
  box : Box,
  fill : String,
  side_fill : String,
  stroke : String,
  stroke_width : Double,
  config : SvgConfig,
) -> Unit {
  // Ported from ../d2/d2renderers/d2svg/d2svg.go (render3DRect).
  let x = box.x
  let y = box.y
  let w = box.width
  let h = box.height
  let border = @svg.PathBuilder::new()
    .move_to(x, y)
    .line_to(x + THREE_DEE_OFFSET, y - THREE_DEE_OFFSET)
    .line_to(x + w + THREE_DEE_OFFSET, y - THREE_DEE_OFFSET)
    .line_to(x + w + THREE_DEE_OFFSET, y + h - THREE_DEE_OFFSET)
    .line_to(x + w, y + h)
    .line_to(x, y + h)
    .line_to(x, y)
    .line_to(x + w, y)
    .line_to(x + w, y + h)
    .move_to(x + w, y)
    .line_to(x + w + THREE_DEE_OFFSET, y - THREE_DEE_OFFSET)
    .build()
  let mask_id = defs_id(config, "border-mask-\{hash_u32(obj_id).to_string()}")
  let mask_x = x
  let mask_y = y - THREE_DEE_OFFSET
  let mask_w = w + THREE_DEE_OFFSET
  let mask_h = h + THREE_DEE_OFFSET
  let mask_style = "stroke-width:\{stroke_width};stroke:#000;fill:none;opacity:1;"
  let mask_def = "<mask id=\"\{mask_id}\" maskUnits=\"userSpaceOnUse\" x=\"\{mask_x}\" y=\"\{mask_y}\" width=\"\{mask_w}\" height=\"\{mask_h}\"><rect x=\"\{mask_x}\" y=\"\{mask_y}\" width=\"\{mask_w}\" height=\"\{mask_h}\" fill=\"white\"></rect><path d=\"\{border}\" style=\"\{mask_style}\"/></mask>"
  svg.add_def(mask_def)
  svg.add(
    @xml_emit.Element::new("rect")
    .attr_num("x", x)
    .attr_num("y", y)
    .attr_num("width", w)
    .attr_num("height", h)
    .attr("mask", "url(#\{mask_id})")
    .attr("stroke", "none")
    .attr("fill", fill)
    .attr_num("stroke-width", stroke_width)
    .self_close()
    .build(),
  )
  let side_points = "\{x},\{y} \{x + THREE_DEE_OFFSET},\{y - THREE_DEE_OFFSET} \{x + w + THREE_DEE_OFFSET},\{y - THREE_DEE_OFFSET} \{x + w + THREE_DEE_OFFSET},\{y + h - THREE_DEE_OFFSET} \{x + w},\{y + h} \{x + w},\{y}"
  svg.add(
    @xml_emit.Element::new("polygon")
    .attr("mask", "url(#\{mask_id})")
    .attr("points", side_points)
    .attr("fill", side_fill)
    .attr("stroke", "none")
    .attr_num("stroke-width", stroke_width)
    .self_close()
    .build(),
  )
  svg.add(@svg.path(border, fill="none", stroke~, stroke_width~))
}

///|
fn compress_collinear_points(points : Array[Point]) -> Array[Point] {
  if points.length() <= 2 {
    return points
  }
  let compressed : Array[Point] = [points[0]]
  for i = 1; i < points.length() - 1; i = i + 1 {
    let prev = compressed[compressed.length() - 1]
    let curr = points[i]
    let next = points[i + 1]
    let dx1 = curr.x - prev.x
    let dy1 = curr.y - prev.y
    let dx2 = next.x - curr.x
    let dy2 = next.y - curr.y
    let cross = dx1 * dy2 - dy1 * dx2
    if cross.abs() >= 0.001 {
      compressed.push(curr)
    }
  }
  compressed.push(points[points.length() - 1])
  compressed
}

///|
/// Build a polyline path with rounded corners.
fn build_rounded_path(pb : @svg.PathBuilder, raw_points : Array[Point]) -> Unit {
  let points = compress_collinear_points(raw_points)
  if points.length() < 2 {
    return
  }
  let _ = pb.move_to(points[0].x, points[0].y)
  if points.length() == 2 {
    let _ = pb.line_to(points[1].x, points[1].y)
    return
  }
  let radius = 10.0
  let mut i = 1
  while i < points.length() - 1 {
    let prev_source = points[i - 1]
    let prev_target = points[i]
    let curr_target = points[i + 1]
    let prev_dx = prev_target.x - prev_source.x
    let prev_dy = prev_target.y - prev_source.y
    let curr_dx = curr_target.x - prev_target.x
    let curr_dy = curr_target.y - prev_target.y
    let prev_len = (prev_dx * prev_dx + prev_dy * prev_dy).sqrt()
    let curr_len = (curr_dx * curr_dx + curr_dy * curr_dy).sqrt()
    if prev_len < 0.001 || curr_len < 0.001 {
      let _ = pb.line_to(prev_target.x, prev_target.y)
      i = i + 1
      continue
    }
    let dist = curr_len
    let units = @cmp.minimum(radius, dist / 2.0)
    let prev_tx = prev_dx / prev_len * units
    let prev_ty = prev_dy / prev_len * units
    let curr_tx = curr_dx / curr_len * units
    let curr_ty = curr_dy / curr_len * units

    let _ = pb.line_to(prev_target.x - prev_tx, prev_target.y - prev_ty)

    if units < radius && i < points.length() - 2 {
      let next_target = points[i + 2]
      let next_dx = next_target.x - curr_target.x
      let next_dy = next_target.y - curr_target.y
      let next_len = (next_dx * next_dx + next_dy * next_dy).sqrt()
      if next_len >= 0.001 {
        i = i + 1
        let next_tx = next_dx / next_len * units
        let next_ty = next_dy / next_len * units
        let _ = pb.cubic_to(
          prev_target.x + prev_tx,
          prev_target.y + prev_ty,
          curr_target.x - next_tx,
          curr_target.y - next_ty,
          curr_target.x + next_tx,
          curr_target.y + next_ty,
        )
      } else {
        let _ = pb.smooth_cubic_to(
          prev_target.x,
          prev_target.y,
          prev_target.x + curr_tx,
          prev_target.y + curr_ty,
        )
      }
    } else {
      let _ = pb.smooth_cubic_to(
        prev_target.x,
        prev_target.y,
        prev_target.x + curr_tx,
        prev_target.y + curr_ty,
      )
    }
    i = i + 1
  }
  let last = points[points.length() - 1]
  let _ = pb.line_to(last.x, last.y)
}

///|
fn build_polyline_path(pb : @svg.PathBuilder, points : Array[Point]) -> Unit {
  if points.length() < 2 {
    return
  }
  let _ = pb.move_to(points[0].x, points[0].y)
  for i = 1; i < points.length(); i = i + 1 {
    let p = points[i]
    let _ = pb.line_to(p.x, p.y)
  }
}

///|
fn build_d2_curve_path(pb : @svg.PathBuilder, points : Array[Point]) -> Unit {
  if points.length() < 2 {
    return
  }
  if points.length() < 4 {
    build_polyline_path(pb, points)
    return
  }
  let _ = pb.move_to(points[0].x, points[0].y)
  let mut i = 1
  while i + 2 < points.length() {
    let c1 = points[i]
    let c2 = points[i + 1]
    let p = points[i + 2]
    let _ = pb.cubic_to(c1.x, c1.y, c2.x, c2.y, p.x, p.y)
    i = i + 3
  }
}

///|
fn adjusted_route_for_arrowheads(
  edge : Connection,
  shapes : Array[Shape],
  edge_stroke_width : Double,
  default_shape_stroke_width : Double,
) -> Array[Point] {
  if edge.route.length() < 2 {
    return edge.route
  }
  let out = edge.route.copy()
  let src_shape_stroke = shape_stroke_width(
    shapes,
    edge.src_id,
    default_shape_stroke_width,
  )
  let dst_shape_stroke = shape_stroke_width(
    shapes,
    edge.dst_id,
    default_shape_stroke_width,
  )
  let src_adj = arrowhead_adjustment(
    out[1],
    out[0],
    edge.src_arrowhead,
    edge_stroke_width,
    src_shape_stroke,
  )
  let last = out.length() - 1
  let dst_adj = arrowhead_adjustment(
    out[last - 1],
    out[last],
    edge.dst_arrowhead,
    edge_stroke_width,
    dst_shape_stroke,
  )
  out[0] = @graph.Point::new(out[0].x + src_adj.0, out[0].y + src_adj.1)
  out[last] = @graph.Point::new(
    out[last].x + dst_adj.0,
    out[last].y + dst_adj.1,
  )
  out
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
  default_value
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
  if distance <= 0.0 {
    return (points[0], 0)
  }
  let total = route_length(points)
  if distance >= total {
    return (points[points.length() - 1], points.length() - 2)
  }
  let mut walked = 0.0
  for i = 0; i < points.length() - 1; i = i + 1 {
    let p0 = points[i]
    let p1 = points[i + 1]
    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    let seg = (dx * dx + dy * dy).sqrt()
    if seg <= 0.000001 {
      continue
    }
    if walked + seg >= distance {
      let t = (distance - walked) / seg
      return (Point::new(p0.x + dx * t, p0.y + dy * t), i)
    }
    walked = walked + seg
  }
  (points[points.length() - 1], points.length() - 2)
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
  (Point::new(center_x - width / 2.0, center_y - height / 2.0), segment_index)
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
  let is_mono = style_is_mono(edge.style.font_family)
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
        @svg.styled_text(
          x,
          y,
          text,
          font_family=config.font_family,
          font_size~,
          dominant_baseline="alphabetic",
          extra_style="fill: \{fill}; font-style: italic",
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
  shapes : Array[Shape],
  edge_label_mask_url : String,
  edge_marker_ids : Map[String, String],
  config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> Unit raise @render_api.RenderError {
  if is_synthetic_sequence_lifeline(edge) {
    return
  }
  if edge.route.length() < 2 {
    return
  }
  // Apply sketch filter if enabled
  let use_sketch = style_bool(edge.style.sketch, false)
  if use_sketch {
    svg.open_group_with_filter(defs_id(config, "sketch-filter"))
  }
  // Get style values
  let stroke = style_color(edge.style.stroke, "B1", theme, use_css_theme_vars)
  let stroke_width = style_double(
    edge.style.stroke_width,
    config.default_stroke_width,
  )
  let stroke_dash = style_double(edge.style.stroke_dash, 0.0)
  let adjusted_route = adjusted_route_for_arrowheads(
    edge,
    shapes,
    stroke_width,
    config.default_stroke_width,
  )
  let pb = @svg.PathBuilder::new()
  if edge.is_curve {
    build_d2_curve_path(pb, adjusted_route)
  } else if style_bool(edge.style.curved, true) {
    // Route points are provided by the layout pipeline.
    // Only apply rounded corner transitions at bends here.
    build_rounded_path(pb, adjusted_route)
  } else {
    build_polyline_path(pb, adjusted_route)
  }
  // Determine markers based on arrowhead types
  let marker_start = marker_url_for_edge(
    svg,
    config,
    edge_marker_ids,
    edge.src_arrowhead,
    false,
    stroke,
    stroke_width,
  )
  let marker_end = marker_url_for_edge(
    svg,
    config,
    edge_marker_ids,
    edge.dst_arrowhead,
    true,
    stroke,
    stroke_width,
  )
  // Use animated path if animated style is enabled
  if style_bool(edge.style.animated, false) {
    svg.add(
      @svg.animated_path(
        pb.build(),
        stroke~,
        stroke_width~,
        marker_start~,
        marker_end~,
        mask=edge_label_mask_url,
      ),
    )
  } else {
    svg.add(
      @svg.path(
        pb.build(),
        stroke~,
        stroke_width~,
        stroke_dash~,
        marker_start~,
        marker_end~,
        mask=edge_label_mask_url,
      ),
    )
  }
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
        let text_styles : Array[String] = ["fill: \{text_color}"]
        if style_bool(edge.style.italic, true) {
          text_styles.push("font-style: italic")
        }
        if style_bool(edge.style.bold, false) {
          text_styles.push("font-weight: 700")
        }
        svg.add(
          @svg.styled_text(
            cx,
            baseline_y,
            edge.label,
            font_family=config.font_family,
            font_size=label_font_size,
            dominant_baseline="alphabetic",
            extra_style=text_styles.join("; "),
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
}

///|
fn sequence_participant_ids_for_render(graph : Diagram) -> Array[String] {
  let object_ids : Map[String, Bool] = {}
  for obj in graph.shapes {
    object_ids[obj.id] = true
  }
  if !graph.root.child_ids.is_empty() {
    let ids : Array[String] = []
    for id in graph.root.child_ids {
      if object_ids.contains(id) {
        ids.push(id)
      }
    }
    if !ids.is_empty() {
      return ids
    }
  }
  let child_ids : Map[String, Bool] = {}
  for obj in graph.shapes {
    for child_id in obj.child_ids {
      child_ids[child_id] = true
    }
  }
  let ids : Array[String] = []
  for obj in graph.shapes {
    if !child_ids.contains(obj.id) {
      ids.push(obj.id)
    }
  }
  ids
}

///|
fn is_synthetic_sequence_lifeline(conn : Connection) -> Bool {
  !conn.src_arrow &&
  !conn.dst_arrow &&
  conn.label == "" &&
  conn.dst_id.contains("-lifeline-end-")
}

///|
fn render_sequence_lifelines(
  svg : @svg.Svg,
  graph : Diagram,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> Unit {
  let ids = sequence_participant_ids_for_render(graph)
  if ids.is_empty() {
    return
  }
  let object_by_id : Map[String, Shape] = {}
  for obj in graph.shapes {
    object_by_id[obj.id] = obj
  }
  let mut max_message_y = -1.0
  for edge in graph.connections {
    if is_synthetic_sequence_lifeline(edge) {
      continue
    }
    for p in edge.route {
      if p.y > max_message_y {
        max_message_y = p.y
      }
    }
  }
  let stroke = resolve_theme_color("B2", theme, use_css_theme_vars)
  for id in ids {
    match object_by_id.get(id) {
      Some(obj) =>
        match obj.box {
          Some(box) => {
            let x = box.x + box.width / 2.0
            let start_y = box.y + box.height + 2.0
            let end_y = if max_message_y >= 0.0 {
              max_message_y + 69.0
            } else {
              start_y + 120.0
            }
            let d = @svg.PathBuilder::new()
              .move_to(x, start_y)
              .line_to(x, end_y)
              .build()
            svg.add(
              @xml_emit.Element::new("path")
              .attr("d", d)
              .attr("stroke", stroke)
              .attr("fill", "none")
              .attr_num("stroke-width", 2.0)
              .attr("stroke-dasharray", "12.000000,11.838767")
              .self_close()
              .build(),
            )
          }
          None => ()
        }
      None => ()
    }
  }
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
  // Use page shape for notes (with folded corner)
  render_svg_page(svg, box, fill, stroke, stroke_width)
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
