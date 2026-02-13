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
  let width_chars = round_int((width.to_double() / config.font_width) * config.scale)
  let height_chars = round_int((height.to_double() / config.font_height) * config.scale)

  let mut max_label_len = 0
  for shape in diagram.shapes {
    if shape.label.length() > max_label_len {
      max_label_len = shape.label.length()
    }
  }
  let padding = max_label_len + MIN_LABEL_PADDING
  let canvas = @ascii.Grid::new(width_chars + padding + 1, height_chars + padding + 1)

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
  let mut first = true
  let mut min_x = 0
  let mut min_y = 0
  let mut max_x = 0
  let mut max_y = 0

  for shape in diagram.shapes {
    match shape.box {
      Some(box) => {
        let mut x = box.x.to_int()
        let y = box.y.to_int()
        let mut w = box.width.to_int()
        let mut h = box.height.to_int()
        if style_is_multiple(shape.style) {
          x -= 10
          w += 10
          h += 10
        }
        let left = x
        let top = y
        let right = x + w
        let bottom = y + h
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

  if first {
    return (0, 0, 0, 0)
  }

  for conn in diagram.connections {
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
