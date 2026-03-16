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
fn merge_theme_overrides(
  dst : Map[String, String],
  src : Map[String, String],
) -> Unit {
  for key, value in src {
    dst[key] = value
  }
}

///|
fn compile_theme_overrides_map(
  overrides_map : @ir.Map,
) -> Result[Map[String, String], CompileError] {
  let overrides : Map[String, String] = {}
  let errors : Array[String] = []
  for field in overrides_map.fields {
    if field.primary is Some(value) {
      let raw_key = field.name
      let key = raw_key.to_upper()
      if not(is_valid_theme_override_key(key)) {
        errors.push("\"\{raw_key}\" is not a valid theme code")
        continue
      }
      let color_value = value.to_string()
      if not(is_valid_theme_override_color(color_value)) {
        errors.push(
          "expected \"\{raw_key}\" to be a valid named color (\"orange\") or a hex code (\"#f0ff3a\")",
        )
        continue
      }
      overrides[key] = color_value
    }
  }
  if not(errors.is_empty()) {
    return Err(ConfigError(errors.join("; ")))
  }
  Ok(overrides)
}

///|
fn is_valid_theme_override_key(key : String) -> Bool {
  match key {
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
    | "AB5" => true
    _ => false
  }
}

///|
fn is_valid_theme_override_color(value : String) -> Bool {
  is_css_named_color(value) || is_hex_color(value)
}

///|
fn is_css_named_color(value : String) -> Bool {
  let lower = value.to_lower()
  for color in css_named_colors {
    if lower == color {
      return true
    }
  }
  false
}

///|
fn is_hex_color(value : String) -> Bool {
  if not(value.has_prefix("#")) {
    return false
  }
  let n = value.length()
  if n != 4 && n != 7 {
    return false
  }
  for i in 1..<n {
    match value[i].to_char() {
      Some(c) => if not(is_hex_digit(c)) { return false }
      None => return false
    }
  }
  true
}

///|
fn is_hex_digit(c : Char) -> Bool {
  ('0' <= c && c <= '9') || ('a' <= c && c <= 'f') || ('A' <= c && c <= 'F')
}

///|
let css_named_colors : Array[String] = [
  "currentcolor", "transparent", "aliceblue", "antiquewhite", "aqua", "aquamarine",
  "azure", "beige", "bisque", "black", "blanchedalmond", "blue", "blueviolet", "brown",
  "burlywood", "cadetblue", "chartreuse", "chocolate", "coral", "cornflowerblue",
  "cornsilk", "crimson", "cyan", "darkblue", "darkcyan", "darkgoldenrod", "darkgray",
  "darkgrey", "darkgreen", "darkkhaki", "darkmagenta", "darkolivegreen", "darkorange",
  "darkorchid", "darkred", "darksalmon", "darkseagreen", "darkslateblue", "darkslategray",
  "darkslategrey", "darkturquoise", "darkviolet", "deeppink", "deepskyblue", "dimgray",
  "dimgrey", "dodgerblue", "firebrick", "floralwhite", "forestgreen", "fuchsia",
  "gainsboro", "ghostwhite", "gold", "goldenrod", "gray", "grey", "green", "greenyellow",
  "honeydew", "hotpink", "indianred", "indigo", "ivory", "khaki", "lavender", "lavenderblush",
  "lawngreen", "lemonchiffon", "lightblue", "lightcoral", "lightcyan", "lightgoldenrodyellow",
  "lightgray", "lightgrey", "lightgreen", "lightpink", "lightsalmon", "lightseagreen",
  "lightskyblue", "lightslategray", "lightslategrey", "lightsteelblue", "lightyellow",
  "lime", "limegreen", "linen", "magenta", "maroon", "mediumaquamarine", "mediumblue",
  "mediumorchid", "mediumpurple", "mediumseagreen", "mediumslateblue", "mediumspringgreen",
  "mediumturquoise", "mediumvioletred", "midnightblue", "mintcream", "mistyrose",
  "moccasin", "navajowhite", "navy", "oldlace", "olive", "olivedrab", "orange", "orangered",
  "orchid", "palegoldenrod", "palegreen", "paleturquoise", "palevioletred", "papayawhip",
  "peachpuff", "peru", "pink", "plum", "powderblue", "purple", "rebeccapurple", "red",
  "rosybrown", "royalblue", "saddlebrown", "salmon", "sandybrown", "seagreen", "seashell",
  "sienna", "silver", "skyblue", "slateblue", "slategray", "slategrey", "snow", "springgreen",
  "steelblue", "tan", "teal", "thistle", "tomato", "turquoise", "violet", "wheat",
  "white", "whitesmoke", "yellow", "yellowgreen",
]

///|
fn compile_config_data_map(
  data_map : @ir.Map,
) -> Map[String, @diagram.ConfigDataValue] {
  let data : Map[String, @diagram.ConfigDataValue] = {}
  for field in data_map.fields {
    if field.primary is Some(value) {
      data[field.name] = @diagram.ConfigDataValue::Text(value.to_string())
    } else if field.array() is Some(array) {
      let values : Array[String] = []
      for item in array.values {
        if item.as_scalar() is Some(scalar) {
          values.push(scalar.to_string())
        }
      }
      data[field.name] = @diagram.ConfigDataValue::StringArray(values)
    } else if field.has_composite() {
      data[field.name] = @diagram.ConfigDataValue::StringArray([])
    }
  }
  data
}

///|
fn graph_data_from_source_config(
  config : @diagram.Config?,
) -> Map[String, @graph.GraphDataValue] {
  let data : Map[String, @graph.GraphDataValue] = {}
  match config {
    Some(config) =>
      for key, value in config.data {
        data[key] = match value {
          @diagram.ConfigDataValue::Text(text) =>
            @graph.GraphDataValue::Text(text)
          @diagram.ConfigDataValue::StringArray(items) => {
            let copied : Array[String] = []
            for item in items {
              copied.push(item)
            }
            @graph.GraphDataValue::StringArray(copied)
          }
        }
      }
    None => ()
  }
  data
}

///|
fn extract_source_config(
  ir_map : @ir.Map,
) -> Result[@diagram.Config?, CompileError] {
  let vars_map = match ir_map.get_field("vars") {
    Some(field) =>
      match field.map() {
        Some(map) => map
        None => return Ok(None)
      }
    None => return Ok(None)
  }
  let config_map = match vars_map.get_field("d2-config") {
    Some(field) =>
      match field.map() {
        Some(map) => map
        None => return Ok(None)
      }
    None => return Ok(None)
  }
  let mut sketch : Bool? = None
  let mut theme_id : Int? = None
  let mut dark_theme_id : Int? = None
  let theme_overrides : Map[String, String] = {}
  let dark_theme_overrides : Map[String, String] = {}
  let mut pad : Double? = None
  let mut center : Bool? = None
  let mut layout_engine : String? = None
  let mut scale : Double? = None
  let mut no_xml_tag : Bool? = None
  let mut salt : String? = None
  let mut omit_version : Bool? = None
  let data : Map[String, @diagram.ConfigDataValue] = {}
  if config_map.get_field("sketch") is Some(field) {
    if field.primary is Some(value) {
      sketch = value.as_bool()
    }
  }
  if config_map.get_field("theme-id") is Some(field) {
    if field.primary is Some(value) {
      theme_id = value.as_int()
    }
  }
  if config_map.get_field("dark-theme-id") is Some(field) {
    if field.primary is Some(value) {
      dark_theme_id = value.as_int()
    }
  }
  if config_map.get_field("theme-overrides") is Some(theme_overrides_field) {
    if theme_overrides_field.map() is Some(overrides_map) {
      let overrides = match compile_theme_overrides_map(overrides_map) {
        Ok(parsed) => parsed
        Err(err) => return Err(err)
      }
      merge_theme_overrides(theme_overrides, overrides)
    }
  }
  if config_map.get_field("dark-theme-overrides")
    is Some(dark_theme_overrides_field) {
    if dark_theme_overrides_field.map() is Some(overrides_map) {
      let overrides = match compile_theme_overrides_map(overrides_map) {
        Ok(parsed) => parsed
        Err(err) => return Err(err)
      }
      merge_theme_overrides(dark_theme_overrides, overrides)
    }
  }
  if config_map.get_field("pad") is Some(field) {
    if field.primary is Some(value) {
      if value.as_int() is Some(int_pad) {
        pad = Some(int_pad.to_double())
      }
    }
  }
  if config_map.get_field("center") is Some(field) {
    if field.primary is Some(value) {
      center = value.as_bool()
    }
  }
  if config_map.get_field("layout-engine") is Some(field) {
    if field.primary is Some(value) {
      layout_engine = Some(value.to_string())
    }
  }
  if config_map.get_field("scale") is Some(field) {
    if field.primary is Some(value) {
      scale = value.as_double()
    }
  }
  if config_map.get_field("no-xml-tag") is Some(field) {
    if field.primary is Some(value) {
      no_xml_tag = value.as_bool()
    }
  }
  if config_map.get_field("salt") is Some(field) {
    if field.primary is Some(value) {
      salt = Some(value.to_string())
    }
  }
  if config_map.get_field("omit-version") is Some(field) {
    if field.primary is Some(value) {
      omit_version = value.as_bool()
    }
  }
  if config_map.get_field("data") is Some(data_field) {
    if data_field.map() is Some(data_map) {
      for key, value in compile_config_data_map(data_map) {
        data[key] = value
      }
    }
  }
  Ok(
    Some(
      @diagram.Config::from_parts(
        sketch, theme_id, dark_theme_id, theme_overrides, dark_theme_overrides, pad,
        center, layout_engine, scale, no_xml_tag, salt, omit_version, data,
      ),
    ),
  )
}
