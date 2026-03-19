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
/// compatibility ASCII renderer.

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
  let inline_child_shape_parent_ids = collect_inline_child_shape_parent_ids(
    diagram.shapes,
  )
  let inline_child_shape_ids = collect_inline_child_shape_ids_from_parent_ids(
    inline_child_shape_parent_ids,
  )
  let (min_x0, min_y0, max_x0, max_y0) = calculate_extended_bounds(
    diagram,
    inline_child_shape_ids,
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
    if is_inline_child_shape(shape.id, inline_child_shape_ids) {
      continue
    }
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
    if is_inline_child_shape(shape.id, inline_child_shape_ids) {
      continue
    }
    draw_diagram_shape(
      shape_ctx,
      shape,
      diagram.shapes,
      diagram.connections,
      x_offset,
      y_offset,
    )
  }

  let route_ctx = {
    canvas,
    chars: config.charset,
    diagram,
    shape_ctx,
    inline_child_shape_parent_ids,
  }
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
  inline_child_shape_ids : Map[String, Bool],
  fw : Double,
  fh : Double,
) -> (Int, Int, Int, Int) {
  let mut min_x = 2147483647
  let mut min_y = 2147483647
  let mut max_x = -2147483648
  let mut max_y = -2147483648

  for shape in diagram.shapes {
    if is_inline_child_shape(shape.id, inline_child_shape_ids) {
      continue
    }
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

        if shape.shape_type == @graph.ShapeType::C4Person {
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
          let offset_y = if shape.shape_type == @graph.ShapeType::Hexagon {
            7
          } else {
            15
          }
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

        // Keep text output bounds aligned with the reference appendix icon space for
        // linked/tooltip shapes, which affects y-offset calibration.
        let has_tooltip = match shape.tooltip {
          Some(t) => t != ""
          None => false
        }
        let has_link = match shape.link {
          Some(l) => l != ""
          None => false
        }
        if has_tooltip || has_link {
          min_y = min_int(min_y, floor_int(box.y) - stroke_width - 16)
          max_x = max_int(
            max_x,
            ceil_int(box.x + box.width) + stroke_width + 16,
          )
        }

        match shape.label_box {
          Some(lb) => {
            min_x = min_int(min_x, floor_int(lb.x))
            min_y = min_int(min_y, floor_int(lb.y))
            max_x = max_int(max_x, ceil_int(lb.x + lb.width))
            max_y = max_int(max_y, ceil_int(lb.y + lb.height))
          }
          None =>
            match estimate_shape_label_bounds(shape, box) {
              Some((lx1, ly1, lx2, ly2)) => {
                min_x = min_int(min_x, lx1)
                min_y = min_int(min_y, ly1)
                max_x = max_int(max_x, lx2)
                max_y = max_int(max_y, ly2)
              }
              None => ()
            }
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

    if route.length() > 0 {
      match conn.dst_arrowhead_label {
        Some(label) =>
          if label != "" {
            let last_route = route[route.length() - 1]
            let label_x = last_route.x - label.length().to_double() * fw
            let label_x2 = last_route.x + label.length().to_double() * fw
            let label_y = last_route.y - fh
            let label_y2 = last_route.y + fh
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
        None => ()
      }

      match conn.src_arrowhead_label {
        Some(label) =>
          if label != "" {
            let first_route = route[0]
            let label_x = first_route.x - label.length().to_double() * fw
            let label_x2 = first_route.x + label.length().to_double() * fw
            let label_y = first_route.y - fh
            let label_y2 = first_route.y + fh
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
        None => ()
      }
    }
  }

  (min_x, min_y, max_x, max_y)
}

///|
fn collect_inline_child_shape_parent_ids(
  shapes : Array[@diagram.Shape],
) -> Map[String, String] {
  let ids : Map[String, String] = {}
  for shape in shapes {
    if shape.shape_type == @graph.ShapeType::SqlTable ||
      shape.shape_type == @graph.ShapeType::Class {
      for child_id in shape.child_ids {
        ids[child_id] = shape.id
      }
    }
  }
  ids
}

///|
fn collect_inline_child_shape_ids_from_parent_ids(
  inline_child_shape_parent_ids : Map[String, String],
) -> Map[String, Bool] {
  let ids : Map[String, Bool] = {}
  for child_id, _ in inline_child_shape_parent_ids {
    ids[child_id] = true
  }
  ids
}

///|
fn is_inline_child_shape(
  id : String,
  inline_child_shape_ids : Map[String, Bool],
) -> Bool {
  match inline_child_shape_ids.get(id) {
    Some(_) => true
    None => false
  }
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

///|
const BOUNDS_LABEL_PADDING : Double = 5.0

///|
fn estimate_shape_label_bounds(
  shape : @diagram.Shape,
  box : @graph.Box,
) -> (Int, Int, Int, Int)? {
  if shape.label == "" {
    return None
  }

  let font_size = match shape.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool_local(shape.style.bold, false)
  let is_italic = style_bool_local(shape.style.italic, false)
  let is_mono = shape.shape_type == @graph.ShapeType::Code ||
    style_is_mono_local(shape.style.font_family)
  let dims = @text_metrics.measure_label(
    shape.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  let label_width = if dims.width > 0.0 {
    dims.width
  } else {
    shape.label.length().to_double() * 7.0
  }
  let label_height = if dims.height > 0.0 {
    dims.height
  } else {
    font_size.to_double()
  }

  let label_position = default_shape_label_position_for_bounds(shape, box)
  let (label_x, label_y) = label_top_left_for_position(
    label_position, box, label_width, label_height,
  )
  Some(
    (
      floor_int(label_x),
      floor_int(label_y),
      ceil_int(label_x + label_width),
      ceil_int(label_y + label_height),
    ),
  )
}

///|
fn style_is_mono_local(value : @graph.StyleValue?) -> Bool {
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
fn default_shape_label_position_for_bounds(
  shape : @diagram.Shape,
  box : @graph.Box,
) -> String {
  if shape.shape_type == @graph.ShapeType::SqlTable ||
    shape.shape_type == @graph.ShapeType::Class {
    return "INSIDE_TOP_CENTER"
  }
  let font_size = match shape.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool_local(shape.style.bold, false)
  let is_italic = style_bool_local(shape.style.italic, false)
  let is_mono = shape.shape_type == @graph.ShapeType::Code ||
    style_is_mono_local(shape.style.font_family)
  let dims = @text_metrics.measure_label(
    shape.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  let label_width = if dims.width > 0.0 {
    dims.width + BOUNDS_LABEL_PADDING * 2.0
  } else {
    shape.label.length().to_double() * 7.0 + BOUNDS_LABEL_PADDING * 2.0
  }
  let label_height = if dims.height > 0.0 {
    dims.height + BOUNDS_LABEL_PADDING * 2.0
  } else {
    font_size.to_double() + BOUNDS_LABEL_PADDING * 2.0
  }
  let is_container = !shape.child_ids.is_empty()
  let is_grid_container = is_container &&
    (shape.grid_rows is Some(_) || shape.grid_columns is Some(_))
  let mut pos = if is_container {
    if is_grid_container {
      "INSIDE_TOP_CENTER"
    } else {
      "OUTSIDE_TOP_CENTER"
    }
  } else if shape.shape_type == @graph.ShapeType::Person ||
    shape.shape_type == @graph.ShapeType::Image {
    "OUTSIDE_BOTTOM_CENTER"
  } else if shape.icon is Some(_) {
    "INSIDE_TOP_CENTER"
  } else {
    "INSIDE_MIDDLE_CENTER"
  }
  if label_width > box.width || label_height > box.height {
    pos = if is_container {
      if is_grid_container {
        "INSIDE_TOP_CENTER"
      } else {
        "OUTSIDE_TOP_CENTER"
      }
    } else {
      "OUTSIDE_BOTTOM_CENTER"
    }
  }
  pos
}

///|
fn label_top_left_for_position(
  label_position : String,
  box : @graph.Box,
  label_width : Double,
  label_height : Double,
) -> (Double, Double) {
  let x = if label_position.contains("LEFT") {
    if label_position.contains("OUTSIDE") {
      box.x - BOUNDS_LABEL_PADDING - label_width
    } else {
      box.x + BOUNDS_LABEL_PADDING
    }
  } else if label_position.contains("RIGHT") {
    if label_position.contains("OUTSIDE") {
      box.x + box.width + BOUNDS_LABEL_PADDING
    } else {
      box.x + box.width - BOUNDS_LABEL_PADDING - label_width
    }
  } else {
    box.x + (box.width - label_width) / 2.0
  }

  let y = if label_position.contains("TOP") {
    if label_position.contains("OUTSIDE") {
      box.y - BOUNDS_LABEL_PADDING - label_height
    } else {
      box.y + BOUNDS_LABEL_PADDING
    }
  } else if label_position.contains("BOTTOM") {
    if label_position.contains("OUTSIDE") {
      box.y + box.height + BOUNDS_LABEL_PADDING
    } else {
      box.y + box.height - BOUNDS_LABEL_PADDING - label_height
    }
  } else {
    box.y + (box.height - label_height) / 2.0
  }

  (x, y)
}
