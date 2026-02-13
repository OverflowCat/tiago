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
/// d2-compatible ASCII renderer.

///|
pub struct AsciiConfig {
  charset : @ascii.CharSet
  font_width : Double
  font_height : Double
  scale : Double
} derive(Show)

///|
pub fn AsciiConfig::new() -> AsciiConfig {
  {
    charset: @ascii.CharSet::ascii(),
    font_width: DEFAULT_FONT_WIDTH,
    font_height: DEFAULT_FONT_HEIGHT,
    scale: DEFAULT_SCALE,
  }
}

///|
pub fn AsciiConfig::unicode() -> AsciiConfig {
  {
    charset: @ascii.CharSet::unicode(),
    font_width: DEFAULT_FONT_WIDTH,
    font_height: DEFAULT_FONT_HEIGHT,
    scale: DEFAULT_SCALE,
  }
}

///|
pub fn render_ascii(diagram : @diagram.Diagram, config : AsciiConfig) -> String {
  let (min_x0, min_y0, max_x0, max_y0) = calculate_extended_bounds(
    diagram,
    config.font_width,
    config.font_height,
  )
  let mut min_x = min_x0
  let mut min_y = min_y0
  let mut max_x = max_x0
  let mut max_y = max_y0

  let mut x_offset = 0
  let mut y_offset = 0
  if min_x < 0 {
    x_offset = -min_x
    max_x += -min_x
    min_x = 0
  }
  if min_y < 0 {
    y_offset = -min_y
    max_y += -min_y
    min_y = 0
  }

  let width = max_x - min_x
  let height = max_y - min_y
  let width_chars = round_int(
    width.to_double() / config.font_width * config.scale,
  )
  let height_chars = round_int(
    height.to_double() / config.font_height * config.scale,
  )

  let mut max_label_len = 0
  for shape in diagram.shapes {
    if shape.label.length() > max_label_len {
      max_label_len = shape.label.length()
    }
  }
  let padding = max_label_len + MIN_LABEL_PADDING
  let canvas = @ascii.Grid::new(
    width_chars + padding + 1,
    height_chars + padding + 1,
  )

  let shape_ctx = {
    canvas,
    chars: config.charset,
    font_width: config.font_width,
    font_height: config.font_height,
    scale: config.scale,
  }

  for shape in diagram.shapes {
    draw_diagram_shape(
      shape_ctx,
      shape,
      diagram.shapes,
      diagram.connections,
      x_offset,
      y_offset,
    )
  }

  let route_ctx = { canvas, chars: config.charset, diagram, shape_ctx }
  for conn in diagram.connections {
    if not(connection_has_arrow(conn)) {
      draw_connection_route(route_ctx, conn, x_offset, y_offset)
    }
  }
  for conn in diagram.connections {
    if connection_has_arrow(conn) {
      draw_connection_route(route_ctx, conn, x_offset, y_offset)
    }
  }

  canvas.to_compact_string(config.charset)
}

///|
fn calculate_extended_bounds(
  diagram : @diagram.Diagram,
  fw : Double,
  fh : Double,
) -> (Int, Int, Int, Int) {
  let mut min_x = 2147483647
  let mut min_y = 2147483647
  let mut max_x = -2147483648
  let mut max_y = -2147483648

  for shape in diagram.shapes {
    match shape.box {
      Some(box) => {
        let stroke_width = style_stroke_width(shape.style, 2)
        let stroke_half = ceil_int(stroke_width.to_double() / 2.0)

        let shape_left = floor_int(box.x) - stroke_half
        let shape_top = floor_int(box.y) - stroke_half
        let shape_right = ceil_int(box.x + box.width) + stroke_half
        let shape_bottom = ceil_int(box.y + box.height) + stroke_half
        min_x = min_int(min_x, shape_left)
        min_y = min_int(min_y, shape_top)
        max_x = max_int(max_x, shape_right)
        max_y = max_int(max_y, shape_bottom)

        if shape.shape_type == @graph.Person {
          let head_radius = (box.width * 0.22).to_int()
          let head_center_y = (box.height * 0.18).to_int()
          let head_top = box.y.to_int() + head_center_y - head_radius
          min_y = min_int(min_y, head_top - stroke_width)
        }

        if style_bool_local(shape.style.shadow, false) {
          max_x = max_int(max_x, ceil_int(box.x + box.width) + stroke_half + 3)
          max_y = max_int(max_y, ceil_int(box.y + box.height) + stroke_half + 5)
        }

        if style_bool_local(shape.style.three_d, false) {
          let offset_y = if shape.shape_type == @graph.Hexagon { 7 } else { 15 }
          min_y = min_int(min_y, floor_int(box.y) - offset_y - stroke_width)
          max_x = max_int(
            max_x,
            ceil_int(box.x + box.width) + 15 + stroke_width,
          )
        }

        if style_is_multiple(shape.style) {
          min_y = min_int(min_y, floor_int(box.y) - 10 - stroke_width)
          max_x = max_int(
            max_x,
            ceil_int(box.x + box.width) + 10 + stroke_width,
          )
        }

        match shape.label_box {
          Some(lb) => {
            min_x = min_int(min_x, floor_int(lb.x))
            min_y = min_int(min_y, floor_int(lb.y))
            max_x = max_int(max_x, ceil_int(lb.x + lb.width))
            max_y = max_int(max_y, ceil_int(lb.y + lb.height))
          }
          None => ()
        }
      }
      None => ()
    }
  }

  if min_x == 2147483647 {
    return (0, 0, 0, 0)
  }

  for conn in diagram.connections {
    let route = connection_route_points(conn)
    let stroke_width = style_stroke_width(conn.style, 2)
    let stroke_half = ceil_int(stroke_width.to_double() / 2.0)
    for point in route {
      min_x = min_int(min_x, floor_int(point.x) - stroke_half)
      min_y = min_int(min_y, floor_int(point.y) - stroke_half)
      max_x = max_int(max_x, ceil_int(point.x) + stroke_half)
      max_y = max_int(max_y, ceil_int(point.y) + stroke_half)
    }

    match conn.label_box {
      Some(lb) => {
        min_x = min_int(min_x, floor_int(lb.x))
        min_y = min_int(min_y, floor_int(lb.y))
        max_x = max_int(max_x, ceil_int(lb.x + lb.width))
        max_y = max_int(max_y, ceil_int(lb.y + lb.height))
      }
      None => ()
    }

    let route = connection_route_points(conn)
    if conn.label != "" && route.length() > 1 {
      let mut max_diff = 0.0
      let mut best_x = 0.0
      for i = 0; i < route.length() - 1; i = i + 1 {
        let dy = (route[i].y - route[i + 1].y).abs()
        let dx = (route[i].x - route[i + 1].x).abs()
        let diff = max_double(dy, dx)
        if diff > max_diff {
          max_diff = diff
          best_x = route[i].x
          if diff == dx {
            let direction = if route[i + 1].x >= route[i].x {
              1.0
            } else {
              -1.0
            }
            best_x = route[i].x + direction * diff / 2.0
          }
        }
      }
      let label_x = best_x - conn.label.length().to_double() / 2.0 * fw
      let label_x2 = best_x + conn.label.length().to_double() / 2.0 * fw
      let mid_y = (route[0].y + route[route.length() - 1].y) / 2.0
      let label_y = mid_y - fh
      let label_y2 = mid_y + fh

      if label_x.to_int() < min_x {
        min_x = label_x.to_int()
      }
      if label_x2.to_int() > max_x {
        max_x = label_x2.to_int()
      }
      if label_y.to_int() < min_y {
        min_y = label_y.to_int()
      }
      if label_y2.to_int() > max_y {
        max_y = label_y2.to_int()
      }
    }
  }

  (min_x, min_y, max_x, max_y)
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
fn ceil_int(v : Double) -> Int {
  let i = v.to_int()
  if i.to_double() < v {
    i + 1
  } else {
    i
  }
}

///|
fn floor_int(v : Double) -> Int {
  let i = v.to_int()
  if i.to_double() > v {
    i - 1
  } else {
    i
  }
}

///|
fn style_bool_local(value : @graph.StyleValue?, default : Bool) -> Bool {
  match value {
    Some(v) => v.as_bool().unwrap_or(default)
    None => default
  }
}

///|
fn style_stroke_width(style : @graph.StyleInput, default : Int) -> Int {
  match style.stroke_width {
    Some(v) =>
      match v.as_int() {
        Some(i) => if i > 0 { i } else { default }
        None =>
          match v.as_double() {
            Some(d) => {
              let i = d.to_int()
              if i > 0 {
                i
              } else {
                default
              }
            }
            None => default
          }
      }
    None => default
  }
}
