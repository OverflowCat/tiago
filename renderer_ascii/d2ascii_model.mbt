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
/// Shared constants and helper types for the d2-compatible ASCII renderer.

///|
const DEFAULT_FONT_WIDTH = 9.75

///|
const DEFAULT_FONT_HEIGHT = 18.0

///|
const DEFAULT_SCALE = 1.0

///|
const MIN_LABEL_PADDING = 2

///|
const MAX_ROUTE_ATTEMPTS = 200

///|
const HEAD_HEIGHT = 2

///|
const MIN_STORED_DATA_HEIGHT = 5

///|
const MAX_CURVE_HEIGHT = 3

///|
priv struct Boundary {
  tl_x : Int
  tl_y : Int
  br_x : Int
  br_y : Int
}

///|
fn Boundary::contains(self : Boundary, x : Int, y : Int) -> Bool {
  x >= self.tl_x && x <= self.br_x && y >= self.tl_y && y <= self.br_y
}

///|
priv struct RoutePoint {
  x : Double
  y : Double
}

///|
priv struct RouteLabelPosition {
  i : Int
  x : Int
  max_diff : Double
}

///|
priv struct ShapeDrawContext {
  canvas : @ascii.Grid
  chars : @ascii.CharSet
  font_width : Double
  font_height : Double
  scale : Double
}

///|
fn ShapeDrawContext::calibrate(
  self : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> (Int, Int, Int, Int) {
  let x_c = round_int(x / self.font_width * self.scale)
  let y_c = round_int(y / self.font_height * self.scale)
  let w_c = round_int(w / self.font_width * self.scale)
  let h_c = round_int(h / self.font_height * self.scale)
  (x_c, y_c, w_c, h_c)
}

///|
fn connection_route_points(conn : @diagram.Connection) -> Array[@graph.Point] {
  conn.route
}

///|
fn connection_has_arrow(conn : @diagram.Connection) -> Bool {
  conn.src_arrow || conn.dst_arrow
}

///|
fn sign(v : Double) -> Int {
  if v > 0.0 {
    1
  } else if v < 0.0 {
    -1
  } else {
    0
  }
}

///|
fn round_double(v : Double) -> Double {
  if v >= 0.0 {
    (v + 0.5).to_int().to_double()
  } else {
    (v - 0.5).to_int().to_double()
  }
}

///|
fn round_int(v : Double) -> Int {
  round_double(v).to_int()
}

///|
fn abs_int(v : Int) -> Int {
  if v < 0 {
    -v
  } else {
    v
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
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn short_id(id : String) -> String {
  @graph.syntax_path_last_display(id)
}

///|
fn string_slice(s : String, start : Int, end : Int) -> String {
  let sb = StringBuilder::new()
  let mut i = start
  while i < end && i < s.length() {
    sb.write_char(s.code_unit_at(i).to_int().unsafe_to_char())
    i += 1
  }
  sb.to_string()
}

///|
fn style_is_multiple(style : @graph.StyleInput) -> Bool {
  match style.multiple {
    Some(v) =>
      match v.as_bool() {
        Some(flag) => flag
        None => false
      }
    None => false
  }
}

///|
