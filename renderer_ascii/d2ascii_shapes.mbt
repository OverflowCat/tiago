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
const DEFAULT_LABEL_POSITION = "INSIDE_MIDDLE_CENTER"

///|
const D2_LABEL_PADDING : Double = 5.0

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
fn has_outside_bottom_label(shape_type : @graph.ShapeType) -> Bool {
  shape_type == @graph.ShapeType::Person ||
  shape_type == @graph.ShapeType::Image
}

///|
fn default_shape_label_position(
  shape : @diagram.Shape,
  box : @graph.Box,
) -> String {
  let font_size = match shape.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(shape.style.bold, false)
  let is_italic = style_bool(shape.style.italic, false)
  let is_mono = shape.shape_type == @graph.ShapeType::Code ||
    style_is_mono(shape.style.font_family)
  let dims = @text_metrics.measure_label(
    shape.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  let label_width = if dims.width > 0.0 {
    dims.width + D2_LABEL_PADDING * 2.0
  } else {
    shape.label.length().to_double() * 7.0 + D2_LABEL_PADDING * 2.0
  }
  let label_height = if dims.height > 0.0 {
    dims.height + D2_LABEL_PADDING * 2.0
  } else {
    font_size.to_double() + D2_LABEL_PADDING * 2.0
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
  } else if has_outside_bottom_label(shape.shape_type) {
    "OUTSIDE_BOTTOM_CENTER"
  } else if shape.icon is Some(_) {
    "INSIDE_TOP_CENTER"
  } else {
    DEFAULT_LABEL_POSITION
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
fn infer_label_position_from_boxes(
  box : @graph.Box,
  label_box : @graph.Box,
) -> String {
  let shape_left = box.x
  let shape_top = box.y
  let shape_right = box.x + box.width
  let shape_bottom = box.y + box.height

  let label_left = label_box.x
  let label_top = label_box.y
  let label_right = label_box.x + label_box.width
  let label_bottom = label_box.y + label_box.height
  let label_center_x = label_box.x + label_box.width / 2.0
  let label_center_y = label_box.y + label_box.height / 2.0

  let mut outside = false
  let vertical = if label_bottom <= shape_top {
    outside = true
    "TOP"
  } else if label_top >= shape_bottom {
    outside = true
    "BOTTOM"
  } else if label_center_y <= shape_top + box.height / 3.0 {
    "TOP"
  } else if label_center_y >= shape_bottom - box.height / 3.0 {
    "BOTTOM"
  } else {
    "MIDDLE"
  }

  let horizontal = if label_right <= shape_left {
    outside = true
    "LEFT"
  } else if label_left >= shape_right {
    outside = true
    "RIGHT"
  } else if label_center_x <= shape_left + box.width / 3.0 {
    "LEFT"
  } else if label_center_x >= shape_right - box.width / 3.0 {
    "RIGHT"
  } else {
    "CENTER"
  }

  if outside {
    "OUTSIDE_\{vertical}_\{horizontal}"
  } else {
    "INSIDE_\{vertical}_\{horizontal}"
  }
}

///|
fn resolve_shape_label_position(shape : @diagram.Shape) -> String {
  guard shape.label != "" else { return DEFAULT_LABEL_POSITION }
  guard shape.box is Some(box) else { return DEFAULT_LABEL_POSITION }
  match shape.label_box {
    Some(label_box) => infer_label_position_from_boxes(box, label_box)
    None => default_shape_label_position(shape, box)
  }
}

///|
fn draw_diagram_shape(
  ctx : ShapeDrawContext,
  shape : @diagram.Shape,
  all_shapes : Array[@diagram.Shape],
  connections : Array[@diagram.Connection],
  x_offset : Int,
  y_offset : Int,
) -> Unit {
  match shape.box {
    Some(box) => {
      let mut draw_x = box.x + x_offset.to_double()
      let draw_y = box.y + y_offset.to_double()
      let mut draw_w = box.width
      let mut draw_h = box.height
      let label_position = resolve_shape_label_position(shape)
      if style_is_multiple(shape.style) {
        draw_x -= 10.0
        draw_w += 10.0
        draw_h += 10.0
      }

      let preserve_width = has_connections_at_right_edge(
        shape,
        connections,
        ctx.font_width,
      )
      let preserve_height = has_connections_at_top_edge(
        shape,
        connections,
        ctx.font_height,
      )

      if preserve_width && shape.label != "" {
        let w_c = round_int(draw_w / ctx.font_width * ctx.scale)
        let available_space = w_c - shape.label.length()
        if available_space >= MIN_LABEL_PADDING && available_space % 2 == 1 {
          draw_w += (ctx.font_width / ctx.scale).to_int().to_double()
        }
      }

      match shape.shape_type {
        @graph.ShapeType::Rectangle | @graph.ShapeType::Square =>
          draw_rect(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
            "",
            preserve_height~,
          )
        @graph.ShapeType::Page =>
          draw_page(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Hexagon =>
          draw_hex(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Person =>
          draw_person(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::StoredData =>
          draw_stored_data(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Cylinder =>
          draw_cylinder(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Package =>
          draw_package(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Parallelogram =>
          draw_parallelogram(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Queue =>
          draw_queue(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Step =>
          draw_step(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Callout =>
          draw_callout(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Document =>
          draw_document(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Diamond =>
          draw_diamond(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
          )
        @graph.ShapeType::Class =>
          draw_class_shape(
            ctx, draw_x, draw_y, draw_w, draw_h, shape, all_shapes, label_position,
          )
        @graph.ShapeType::SqlTable =>
          draw_sql_table_shape(
            ctx, draw_x, draw_y, draw_w, draw_h, shape, all_shapes, label_position,
          )
        @graph.ShapeType::Cloud =>
          draw_rect(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
            ctx.chars.cloud().to_string(),
            preserve_height~,
          )
        @graph.ShapeType::Circle =>
          draw_rect(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
            ctx.chars.oval().to_string(),
            preserve_height~,
          )
        @graph.ShapeType::Oval =>
          draw_rect(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
            ctx.chars.oval().to_string(),
            preserve_height~,
          )
        _ =>
          draw_rect(
            ctx,
            draw_x,
            draw_y,
            draw_w,
            draw_h,
            shape.label,
            label_position,
            "",
            preserve_height~,
          )
      }
    }
    None => ()
  }
}

///|
fn get_shape_boundary(
  ctx : ShapeDrawContext,
  shape : @diagram.Shape,
  connections : Array[@diagram.Connection],
) -> Boundary? {
  match shape.box {
    Some(box) => {
      let mut x = box.x
      let y = box.y
      let mut w = box.width
      let mut h = box.height
      if style_is_multiple(shape.style) {
        x -= 10.0
        w += 10.0
        h += 10.0
      }
      let mut x1 = round_int(x / ctx.font_width * ctx.scale)
      let mut y1 = round_int(y / ctx.font_height * ctx.scale)
      let mut w_c = round_int(w / ctx.font_width * ctx.scale)
      let mut h_c = round_int(h / ctx.font_height * ctx.scale)

      let preserve_width = has_connections_at_right_edge(
        shape,
        connections,
        ctx.font_width,
      )
      let preserve_height = has_connections_at_top_edge(
        shape,
        connections,
        ctx.font_height,
      )
      if preserve_width && shape.label != "" {
        let available_space = w_c - shape.label.length()
        if available_space >= MIN_LABEL_PADDING && available_space % 2 == 1 {
          w += (ctx.font_width / ctx.scale).to_int().to_double()
          x1 = round_int(x / ctx.font_width * ctx.scale)
          y1 = round_int(y / ctx.font_height * ctx.scale)
          w_c = round_int(w / ctx.font_width * ctx.scale)
          h_c = round_int(h / ctx.font_height * ctx.scale)
        }
      }

      if shape.label != "" && h_c % 2 == 0 && not(preserve_height) {
        if h_c > 2 {
          h_c -= 1
          y1 += 1
        } else {
          h_c += 1
        }
      }
      w_c = adjust_width_for_label(w_c, shape.label)
      Some({ tl_x: x1, tl_y: y1, br_x: x1 + w_c, br_y: y1 + h_c })
    }
    None => None
  }
}

///|
fn has_connections_at_right_edge(
  shape : @diagram.Shape,
  connections : Array[@diagram.Connection],
  font_width : Double,
) -> Bool {
  match shape.box {
    Some(box) => {
      let shape_right = box.x + box.width
      let shape_top = box.y
      let shape_bottom = box.y + box.height
      let tolerance = font_width / 2.0

      for conn in connections {
        let route = connection_route_points(conn)
        if route.length() == 0 {
          continue
        }
        let first_point = route[0]
        let last_point = route[route.length() - 1]
        if (first_point.x - shape_right).abs() < tolerance &&
          first_point.y >= shape_top &&
          first_point.y <= shape_bottom {
          return true
        }
        if (last_point.x - shape_right).abs() < tolerance &&
          last_point.y >= shape_top &&
          last_point.y <= shape_bottom {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn has_connections_at_top_edge(
  shape : @diagram.Shape,
  connections : Array[@diagram.Connection],
  font_height : Double,
) -> Bool {
  match shape.box {
    Some(box) => {
      let shape_top = box.y
      let shape_left = box.x
      let shape_right = box.x + box.width
      for conn in connections {
        let route = connection_route_points(conn)
        if route.length() < 2 {
          continue
        }
        for i = 0; i < route.length() - 1; i = i + 1 {
          let p1 = route[i]
          let p2 = route[i + 1]
          if (p1.y - p2.y).abs() < 0.1 {
            let segment_y = p1.y
            let segment_left = min_double(p1.x, p2.x)
            let segment_right = max_double(p1.x, p2.x)
            if (segment_y - shape_top).abs() < font_height &&
              segment_right >= shape_left &&
              segment_left <= shape_right {
              return true
            }
          }
        }
      }
      false
    }
    None => false
  }
}

///|
fn label_y(
  y1 : Int,
  y2 : Int,
  h : Int,
  label : String,
  label_position : String,
) -> Int {
  let _ = label
  if label_position.contains("OUTSIDE") {
    if label_position.contains("BOTTOM") {
      y2 + 1
    } else if label_position.contains("TOP") {
      y1 - 1
    } else {
      -1
    }
  } else if label_position.contains("TOP") {
    y1 + 1
  } else if label_position.contains("MIDDLE") {
    y1 + h / 2
  } else if label_position.contains("BOTTOM") {
    y2 - 1
  } else {
    y1 + h / 2
  }
}

///|
fn draw_shape_label(
  ctx : ShapeDrawContext,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  width : Int,
  height : Int,
  label : String,
  label_position : String,
) -> Unit {
  let _ = x2
  let _ = y2
  if label == "" {
    return
  }
  let lines = label.split("\n")
  let mut max_len = 0
  for line in lines {
    if line.length() > max_len {
      max_len = line.length()
    }
  }
  let ly = label_y(y1, y2, height, label, label_position)
  let lx = x1 + (width - max_len) / 2
  ctx.canvas.draw_label(lx, ly, label)
}

///|
fn adjust_width_for_label(width : Int, label : String) -> Int {
  if label == "" {
    return width
  }
  let available_space = width - label.length()
  if available_space < MIN_LABEL_PADDING {
    label.length() + MIN_LABEL_PADDING
  } else if available_space % 2 == 1 {
    width - 1
  } else {
    width
  }
}

///|
fn draw_border(
  ctx : ShapeDrawContext,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  for xi = x1; xi <= x2; xi = xi + 1 {
    for yi = y1; yi <= y2; yi = yi + 1 {
      if xi == x1 && yi == y1 {
        ctx.canvas.set(xi, yi, ctx.chars.top_left())
      } else if xi == x2 && yi == y1 {
        ctx.canvas.set(xi, yi, ctx.chars.top_right())
      } else if xi == x1 && yi == y2 {
        ctx.canvas.set(xi, yi, ctx.chars.bottom_left())
      } else if xi == x2 && yi == y2 {
        ctx.canvas.set(xi, yi, ctx.chars.bottom_right())
      } else if xi == x1 || xi == x2 {
        ctx.canvas.set(xi, yi, ctx.chars.vertical())
      } else if yi == y1 || yi == y2 {
        ctx.canvas.set(xi, yi, ctx.chars.horizontal())
      }
    }
  }
}

///|
fn draw_header(
  ctx : ShapeDrawContext,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  width : Int,
  label : String,
) -> Int {
  let header_height = 2
  let header_y2 = y1 + header_height - 1

  for yi = y1; yi <= header_y2; yi = yi + 1 {
    for xi = x1 + 1; xi < x2; xi = xi + 1 {
      ctx.canvas.set(xi, yi, ' ')
    }
  }
  let label_x = x1 + (width - label.length()) / 2
  ctx.canvas.draw_label(label_x, y1, label)

  let current_y = header_y2 + 1
  draw_separator_line(ctx, x1, x2, current_y)
  current_y + 1
}

///|
fn draw_separator_line(
  ctx : ShapeDrawContext,
  x1 : Int,
  x2 : Int,
  y : Int,
) -> Unit {
  for xi = x1; xi <= x2; xi = xi + 1 {
    if xi == x1 {
      ctx.canvas.set(xi, y, ctx.chars.t_right())
    } else if xi == x2 {
      ctx.canvas.set(xi, y, ctx.chars.t_left())
    } else {
      ctx.canvas.set(xi, y, ctx.chars.horizontal())
    }
  }
}

///|
fn draw_field_with_type(
  ctx : ShapeDrawContext,
  x1 : Int,
  x2 : Int,
  y : Int,
  width : Int,
  name : String,
  field_type : String,
) -> Unit {
  ctx.canvas.draw_label(x1 + 1, y, name)
  if field_type != "" {
    let mut t = field_type
    let max_type_width = width - name.length() - 4
    if t.length() > max_type_width && max_type_width > 3 {
      t = string_slice(t, 0, max_type_width - 3) + "..."
    }
    let type_x = x2 - t.length() - 1
    ctx.canvas.draw_label(type_x, y, t)
  }
}

///|
fn draw_rect(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
  symbol : String,
  preserve_height? : Bool = false,
) -> Unit {
  let (x1_0, y1_0, w0, h0) = ctx.calibrate(x, y, w, h)
  let x1 = x1_0
  let mut y1 = y1_0
  let mut w_c = w0
  let mut h_c = h0
  if label != "" && h_c % 2 == 0 && not(preserve_height) {
    if h_c > 2 {
      h_c -= 1
      y1 += 1
    } else {
      h_c += 1
    }
  }
  w_c = adjust_width_for_label(w_c, label)
  let x2 = x1 + w_c
  let y2 = y1 + h_c

  for xi = x1; xi <= x2; xi = xi + 1 {
    for yi = y1; yi <= y2; yi = yi + 1 {
      if xi == x1 && yi == y1 {
        ctx.canvas.set(xi, yi, ctx.chars.top_left())
      } else if xi == x2 && yi == y1 {
        ctx.canvas.set(xi, yi, ctx.chars.top_right())
      } else if xi == x1 && yi == y2 {
        ctx.canvas.set(xi, yi, ctx.chars.bottom_left())
      } else if xi == x2 && yi == y2 {
        ctx.canvas.set(xi, yi, ctx.chars.bottom_right())
      } else if symbol.trim() != "" && yi == y1 && xi == x1 + 1 {
        ctx.canvas.draw_label(xi, yi, symbol)
      } else if xi == x1 || xi == x2 {
        ctx.canvas.set(xi, yi, ctx.chars.vertical())
      } else if yi == y1 || yi == y2 {
        ctx.canvas.set(xi, yi, ctx.chars.horizontal())
      }
    }
  }
  draw_shape_label(ctx, x1, y1, x2, y2, w_c, h_c, label, label_position)
}

///|
fn draw_page(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1_0, w0, h0) = ctx.calibrate(x, y, w, h)
  let mut y1 = y1_0
  let mut w_c = w0
  let mut h_c = h0
  if label != "" && h_c % 2 == 0 {
    if h_c > 2 {
      h_c -= 1
      y1 += 1
    } else {
      h_c += 1
    }
  }
  w_c = adjust_width_for_label(w_c, label)
  let x2 = x1 + w_c - 1
  let y2 = y1 + h_c - 1

  draw_border(ctx, x1, y1, x2, y2)
  ctx.canvas.set(x2, y1, ' ')
  ctx.canvas.set(x2 - 1, y1, ctx.chars.top_right())
  ctx.canvas.set(x2 - 1, y1 + 1, ctx.chars.backslash())
  ctx.canvas.set(x2, y1 + 1, ctx.chars.top_right())
  draw_shape_label(ctx, x1, y1, x2, y2, w_c, h_c, label, label_position)
}

///|
fn draw_hex(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w0, h_i) = ctx.calibrate(x, y, w, h)
  let w_i = w0
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1
  let h_offset = (h_i.to_double() / 2.0).ceil().to_int()

  for i = x1; i <= x2; i = i + 1 {
    for j = y1; j <= y2; j = j + 1 {
      if j == y1 && i >= x1 + h_offset && i <= x2 - h_offset {
        ctx.canvas.set(i, j, ctx.chars.overline())
      } else if j == y2 && i >= x1 + h_offset && i <= x2 - h_offset {
        ctx.canvas.set(i, j, ctx.chars.underscore())
      } else if h_offset % 2 == 1 &&
        (i == x1 || i == x2) &&
        y1 + h_offset - 1 == j {
        ctx.canvas.set(i, j, ctx.chars.cross())
      } else if j - y1 + (i - x1) + 1 == h_offset ||
        y2 - j + (x2 - i) + 1 == h_offset {
        ctx.canvas.set(i, j, ctx.chars.forwardslash())
      } else if j - y1 + (x2 - i) + 1 == h_offset ||
        y2 - j + (i - x1) + 1 == h_offset {
        ctx.canvas.set(i, j, ctx.chars.backslash())
      }
    }
  }
  draw_shape_label(ctx, x1, y1, x2, y2, w_i, h_i, label, label_position)
}

///|
fn draw_person(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w_i, h_i) = ctx.calibrate(x, y, w, h)
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1
  let head = HEAD_HEIGHT
  let body = h_i - 2
  let mut head_width = 2
  if w_i % 2 == 1 {
    head_width = 3
  }
  let h_offset = (w_i - head_width) / 2
  let s = body - 1

  for xx = x1; xx <= x2; xx = xx + 1 {
    for yy = y1; yy <= y2; yy = yy + 1 {
      let rel_x = xx - x1
      let rel_y = yy - y1
      let rel_x_body = rel_x
      let rel_y_body = rel_y - head

      if yy == y2 {
        ctx.canvas.set(xx, yy, ctx.chars.overline())
      } else if yy >= y1 + head && yy < y2 {
        if rel_x + rel_y == body {
          ctx.canvas.set(xx, yy, ctx.chars.forwardslash())
        } else if (rel_x_body - rel_y_body - 1).to_double().abs() ==
          (w_i - (h_i - head)).to_double().abs() {
          ctx.canvas.set(xx, yy, ctx.chars.backslash())
        } else if yy == y1 + head && xx >= x1 + s && xx <= x2 - s {
          ctx.canvas.set(xx, yy, ctx.chars.overline())
        }
      } else if yy < y1 + head {
        if yy == y1 && xx >= x1 + h_offset && xx <= x2 - h_offset {
          ctx.canvas.set(xx, yy, ctx.chars.overline())
        }
        if yy == y1 + head - 1 && xx >= x1 + h_offset && xx <= x2 - h_offset {
          ctx.canvas.set(xx, yy, ctx.chars.underscore())
        }
        if (yy == y1 && xx == x1 + h_offset - 1) ||
          (yy == y1 + head - 1 && xx == x2 - h_offset + 1) {
          ctx.canvas.set(xx, yy, ctx.chars.forwardslash())
        }
        if (yy == y1 + head - 1 && xx == x1 + h_offset - 1) ||
          (yy == y1 && xx == x2 - h_offset + 1) {
          ctx.canvas.set(xx, yy, ctx.chars.backslash())
        }
      }
    }
  }
  draw_shape_label(ctx, x1, y1, x2, y2, w_i, h_i, label, label_position)
}

///|
fn draw_stored_data(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w_i, h0) = ctx.calibrate(x, y, w, h)
  let mut h_i = h0
  if h_i < MIN_STORED_DATA_HEIGHT {
    h_i = MIN_STORED_DATA_HEIGHT
  } else if h_i % 2 == 0 {
    h_i += 1
  }
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1
  let h_offset = (h_i + 1) / 2

  for xx = x1; xx <= x2; xx = xx + 1 {
    for yy = y1; yy <= y2; yy = yy + 1 {
      let rel_x = xx - x1
      let rel_y = yy - y1
      if yy == y1 + h_offset - 1 && xx == x1 {
        ctx.canvas.set(xx, yy, ctx.chars.vertical())
      } else if xx < x1 + h_offset {
        if yy < y1 + h_offset && rel_x + rel_y == h_offset - 1 {
          ctx.canvas.set(xx, yy, ctx.chars.forwardslash())
        } else if yy >= y1 + h_offset &&
          (rel_x - rel_y).to_double().abs() == (h_offset - 1).to_double() {
          ctx.canvas.set(xx, yy, ctx.chars.backslash())
        }
      } else if xx >= x1 + h_offset {
        if yy == y1 && xx < x2 {
          ctx.canvas.set(xx, yy, ctx.chars.overline())
        } else if yy == y2 && xx < x2 {
          ctx.canvas.set(xx, yy, ctx.chars.underscore())
        } else if xx > x2 - h_offset {
          if yy == y1 + h_offset - 1 && xx == x2 - (h_offset - 1) {
            ctx.canvas.set(xx, yy, ctx.chars.vertical())
          } else if rel_x + rel_y == w_i - 1 {
            ctx.canvas.set(xx, yy, ctx.chars.forwardslash())
          } else if (rel_x - rel_y).to_double().abs() ==
            (w_i - h_i).to_double().abs() {
            ctx.canvas.set(xx, yy, ctx.chars.backslash())
          }
        }
      }
    }
  }
  draw_shape_label(ctx, x1, y1, x2, y2, w_i, h_i, label, label_position)
}

///|
fn draw_cylinder(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w0, h_i) = ctx.calibrate(x, y, w, h)
  let mut w_i = w0
  w_i = adjust_width_for_label(w_i, label)
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1

  for ix = x1; ix <= x2; ix = ix + 1 {
    for iy = y1; iy <= y2; iy = iy + 1 {
      if iy != y1 && iy != y2 && (ix == x1 || ix == x2) {
        ctx.canvas.set(ix, iy, ctx.chars.vertical())
      } else if iy == y1 || iy == y2 || iy == y1 + 1 {
        if iy == y1 {
          if ix == x1 + 1 || ix == x2 - 1 {
            ctx.canvas.set(ix, iy, ctx.chars.dot())
          } else if ix == x1 + 2 || ix == x2 - 2 {
            ctx.canvas.set(ix, iy, ctx.chars.hyphen())
          } else if ix > x1 + 2 && ix < x2 - 2 {
            ctx.canvas.set(ix, iy, ctx.chars.overline())
          }
        } else if iy == y2 || iy == y1 + 1 {
          if ix == x1 + 1 {
            ctx.canvas.set(ix, iy, ctx.chars.backslash())
          } else if ix == x2 - 1 {
            ctx.canvas.set(ix, iy, ctx.chars.forwardslash())
          } else if ix == x1 + 2 || ix == x2 - 2 {
            ctx.canvas.set(ix, iy, ctx.chars.hyphen())
          } else if ix > x1 + 2 && ix < x2 - 2 {
            ctx.canvas.set(ix, iy, ctx.chars.underscore())
          }
        }
      }
    }
  }

  if label != "" {
    let ly = label_y(y1 + 1, y2, h_i, label, label_position)
    let lx = x1 + (w_i - label.length()) / 2
    ctx.canvas.draw_label(lx, ly, label)
  }
}

///|
fn draw_package(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w_i, h_i) = ctx.calibrate(x, y, w, h)
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1
  let x3 = x1 + w_i / 2
  let y3 = y1 + 1

  for ix = x1; ix <= x2; ix = ix + 1 {
    for iy = y1; iy <= y2; iy = iy + 1 {
      if ix == x1 && iy == y1 {
        ctx.canvas.set(ix, iy, ctx.chars.top_left())
      } else if ix == x3 && iy == y1 {
        ctx.canvas.set(ix, iy, ctx.chars.top_right())
      } else if ix == x2 && iy == y3 {
        ctx.canvas.set(ix, iy, ctx.chars.top_right())
      } else if ix == x3 && iy == y3 {
        ctx.canvas.set(ix, iy, ctx.chars.bottom_left())
      } else if ix == x1 && iy == y2 {
        ctx.canvas.set(ix, iy, ctx.chars.bottom_left())
      } else if ix == x2 && iy == y2 {
        ctx.canvas.set(ix, iy, ctx.chars.bottom_right())
      } else if (iy == y1 && ix > x1 && ix < x3) ||
        (iy == y2 && ix > x1 && ix < x2) ||
        (iy == y3 && ix > x3 && ix < x2) {
        ctx.canvas.set(ix, iy, ctx.chars.horizontal())
      } else if (ix == x1 && iy > y1 && iy < y2) ||
        (ix == x2 && iy > y3 && iy < y2) {
        ctx.canvas.set(ix, iy, ctx.chars.vertical())
      }
    }
  }
  draw_shape_label(ctx, x1, y1, x2, y2, w_i, h_i, label, label_position)
}

///|
fn draw_parallelogram(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w_i, h_i) = ctx.calibrate(x, y, w, h)
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1
  for ix = x1; ix <= x2; ix = ix + 1 {
    for iy = y1; iy <= y2; iy = iy + 1 {
      let rx = ix - x1
      let ry = iy - y1
      if rx + ry == h_i - 1 || rx + ry == w_i - 1 {
        ctx.canvas.set(ix, iy, ctx.chars.forwardslash())
      } else if iy == y1 && ix >= x1 + h_i && ix < x2 {
        ctx.canvas.set(ix, iy, ctx.chars.overline())
      } else if iy == y2 && ix > x1 && ix <= x2 - h_i {
        ctx.canvas.set(ix, iy, ctx.chars.underscore())
      }
    }
  }
  draw_shape_label(ctx, x1, y1, x2, y2, w_i, h_i, label, label_position)
}

///|
fn draw_queue(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w_i, h_i) = ctx.calibrate(x, y, w, h)
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1
  for ix = x1; ix <= x2; ix = ix + 1 {
    for iy = y1; iy <= y2; iy = iy + 1 {
      if (iy == y1 && (ix == x1 + 1 || ix == x2 - 2)) ||
        (iy == y2 && ix == x2 - 1) {
        ctx.canvas.set(ix, iy, ctx.chars.forwardslash())
      } else if (iy == y1 && ix == x2 - 1) ||
        (iy == y2 && (ix == x1 + 1 || ix == x2 - 2)) {
        ctx.canvas.set(ix, iy, ctx.chars.backslash())
      } else if (ix == x1 || ix == x2 || ix == x2 - 3) && iy > y1 && iy < y2 {
        ctx.canvas.set(ix, iy, ctx.chars.vertical())
      } else if iy == y1 && ix > x1 + 1 && ix < x2 - 1 {
        ctx.canvas.set(ix, iy, ctx.chars.overline())
      } else if iy == y2 && ix > x1 + 1 && ix < x2 - 3 {
        ctx.canvas.set(ix, iy, ctx.chars.underscore())
      }
    }
  }
  draw_shape_label(ctx, x1, y1, x2, y2, w_i, h_i, label, label_position)
}

///|
fn draw_step(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w_i, h0) = ctx.calibrate(x, y, w, h)
  let mut h_i = h0
  if h_i % 2 == 1 {
    h_i += 1
  }
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1

  for xx = x1; xx <= x2; xx = xx + 1 {
    for yy = y1; yy <= y2; yy = yy + 1 {
      let rx = xx - x1
      let ry = yy - y1
      if (xx < x1 + h_i / 2 && rx - ry == 0) ||
        (xx > x2 - h_i / 2 && abs_int(rx - ry) == w_i - h_i / 2) {
        ctx.canvas.set(xx, yy, ctx.chars.backslash())
      } else if (xx < x1 + h_i / 2 && rx + ry == h_i - 1) ||
        (xx > x2 - h_i / 2 && rx + ry == w_i - 1 + h_i / 2) {
        ctx.canvas.set(xx, yy, ctx.chars.forwardslash())
      } else if yy == y1 && xx > x1 && xx < x2 - h_i / 2 {
        ctx.canvas.set(xx, yy, ctx.chars.overline())
      } else if yy == y2 && xx > x1 && xx < x2 - h_i / 2 {
        ctx.canvas.set(xx, yy, ctx.chars.underscore())
      }
    }
  }
  if label != "" {
    let ly = label_y(y1, y2, h_i, label, label_position)
    let lx = x1 + (w_i - label.length()) / 2
    ctx.canvas.draw_label(lx, ly, label)
  }
}

///|
fn draw_callout(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w_i, h_i) = ctx.calibrate(x, y, w, h)
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1
  let body = (h_i + 1) / 2
  let tail = h_i / 2

  for xx = x1; xx <= x2; xx = xx + 1 {
    for yy = y1; yy <= y2; yy = yy + 1 {
      let rx = xx - x1
      let ry = yy - y1
      if xx == x1 && yy == y1 {
        ctx.canvas.set(xx, yy, ctx.chars.top_left())
      } else if xx == x2 && yy == y1 {
        ctx.canvas.set(xx, yy, ctx.chars.top_right())
      } else if xx == x1 && yy == y2 - tail {
        ctx.canvas.set(xx, yy, ctx.chars.bottom_left())
      } else if xx == x2 && yy == y2 - tail {
        ctx.canvas.set(xx, yy, ctx.chars.bottom_right())
      } else if (yy == y1 || yy == y2 - tail) && xx > x1 && xx < x2 {
        ctx.canvas.set(xx, yy, ctx.chars.horizontal())
      } else if (xx == x1 || xx == x2) && yy > y1 && yy < y2 - tail {
        ctx.canvas.set(xx, yy, ctx.chars.vertical())
      } else if xx == x2 - (tail + 2) && yy > y2 - tail {
        ctx.canvas.set(xx, yy, ctx.chars.vertical())
      } else if yy > y2 - tail && rx + ry == w_i {
        ctx.canvas.set(xx, yy, ctx.chars.forwardslash())
      }
    }
  }
  if label != "" {
    let ly = label_y(y1, y2, body, label, label_position)
    let lx = x1 + (w_i - label.length()) / 2
    ctx.canvas.draw_label(lx, ly, label)
  }
}

///|
fn draw_document(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w_i, h_i) = ctx.calibrate(x, y, w, h)
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1
  let n = (w_i - 2) / 2
  let mut j = n / 2
  if j > MAX_CURVE_HEIGHT {
    j = MAX_CURVE_HEIGHT
  }
  let h_curve = j + 1
  let b_curve = "`-._"
  let t_curve = ".-`‾"
  let l_curve : Array[Char] = []
  let r_curve : Array[Char] = []
  for i = 0; i < n; i = i + 1 {
    if i < h_curve {
      l_curve.push(b_curve.code_unit_at(i).to_int().unsafe_to_char())
      r_curve.push(t_curve.code_unit_at(i).to_int().unsafe_to_char())
    } else if abs_int(i - n + 1) < h_curve {
      let idx = abs_int(i - n + 1)
      l_curve.push(b_curve.code_unit_at(idx).to_int().unsafe_to_char())
      r_curve.push(t_curve.code_unit_at(idx).to_int().unsafe_to_char())
    } else {
      l_curve.push(b_curve.code_unit_at(3).to_int().unsafe_to_char())
      r_curve.push(t_curve.code_unit_at(3).to_int().unsafe_to_char())
    }
  }

  for xx = x1; xx <= x2; xx = xx + 1 {
    for yy = y1; yy <= y2; yy = yy + 1 {
      let rel_x = xx - x1
      let curve_index = rel_x - 1
      if xx == x1 && yy == y1 {
        ctx.canvas.set(xx, yy, ctx.chars.top_left())
      } else if xx == x2 && yy == y1 {
        ctx.canvas.set(xx, yy, ctx.chars.top_right())
      } else if yy == y1 && xx > x1 && xx < x2 {
        ctx.canvas.set(xx, yy, ctx.chars.horizontal())
      } else if (xx == x1 || xx == x2) && yy > y1 && yy < y2 {
        ctx.canvas.set(xx, yy, ctx.chars.vertical())
      } else if yy == y2 &&
        xx > x1 &&
        rel_x <= n &&
        curve_index >= 0 &&
        curve_index < l_curve.length() {
        ctx.canvas.set(xx, yy, l_curve[curve_index])
      } else if yy == y2 - 1 &&
        rel_x > n &&
        xx < x2 &&
        rel_x - w_i / 2 < r_curve.length() {
        ctx.canvas.set(xx, yy, r_curve[rel_x - w_i / 2])
      }
    }
  }

  if label != "" {
    let ly = label_y(y1, y2, h_i - 2, label, label_position)
    let lx = x1 + (w_i - label.length()) / 2
    ctx.canvas.draw_label(lx, ly, label)
  }
}

///|
fn draw_diamond(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  label : String,
  label_position : String,
) -> Unit {
  let (x1, y1, w0, h0) = ctx.calibrate(x, y, w, h)
  let mut w_i = w0
  let mut h_i = h0
  if h_i % 2 == 0 {
    h_i += 1
  }
  if w_i % 2 == 0 {
    w_i += 1
  }
  let x2 = x1 + w_i - 1
  let y2 = y1 + h_i - 1
  let path : Array[(Int, Int)] = [
    (x1, y1 + h_i / 2),
    (x1 + w_i / 2, y1),
    (x2, y1 + h_i / 2),
    (x1 + w_i / 2, y2),
    (x1, y1 + h_i / 2),
  ]

  for xx = x1; xx <= x2; xx = xx + 1 {
    for yy = y1; yy <= y2; yy = yy + 1 {
      let rel_x = xx - x1
      let rel_y = yy - y1
      if (yy == y1 || yy == y2) && rel_x == w_i / 2 {
        ctx.canvas.set(xx, yy, ctx.chars.tilde())
      } else if (xx == x1 || xx == x2) && rel_y == h_i / 2 {
        ctx.canvas.set(xx, yy, ctx.chars.hyphen())
      }
    }
  }

  for i = 0; i < path.length() - 1; i = i + 1 {
    let a = path[i]
    let c = path[i + 1]
    let dx = c.0 - a.0
    let dy = c.1 - a.1
    let step = max_int(abs_int(dx), abs_int(dy))
    let sx = dx.to_double() / step.to_double()
    let sy = dy.to_double() / step.to_double()
    let mut fx = a.0.to_double()
    let mut fy = a.1.to_double()
    for j = 0; j < step; j = j + 1 {
      let _ = j
      fx += sx
      fy += sy
      ctx.canvas.set(round_int(fx), round_int(fy), ctx.chars.star())
    }
  }

  if label != "" {
    let ly = label_y(y1, y2, h_i, label, label_position)
    let lx = x1 + (w_i - label.length()) / 2
    ctx.canvas.draw_label(lx, ly, label)
  }
}

///|
fn object_children(
  obj : @diagram.Shape,
  all_shapes : Array[@diagram.Shape],
) -> Array[@diagram.Shape] {
  let result : Array[@diagram.Shape] = []
  for child_id in obj.child_ids {
    for shape in all_shapes {
      if shape.id == child_id {
        result.push(shape)
        break
      }
    }
  }
  result
}

///|
fn draw_class_shape(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  shape : @diagram.Shape,
  all_shapes : Array[@diagram.Shape],
  label_position : String,
) -> Unit {
  let (x1, y1, w_c, h_c) = ctx.calibrate(x, y, w, h)
  let x2 = x1 + w_c
  let y2 = y1 + h_c
  draw_border(ctx, x1, y1, x2, y2)
  let children = object_children(shape, all_shapes)
  if children.is_empty() {
    draw_shape_label(ctx, x1, y1, x2, y2, w_c, h_c, shape.label, label_position)
    return
  }
  let mut current_y = y1 + 1
  if shape.label != "" {
    current_y = draw_header(ctx, x1, current_y, x2, w_c, shape.label)
  }
  for child in children {
    if current_y >= y2 {
      break
    }
    let field_name = short_id(child.id)
    draw_field_with_type(ctx, x1, x2, current_y, w_c, field_name, child.label)
    current_y += 1
  }
}

///|
fn draw_sql_table_shape(
  ctx : ShapeDrawContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  shape : @diagram.Shape,
  all_shapes : Array[@diagram.Shape],
  label_position : String,
) -> Unit {
  let (x1, y1, w_c, h_c) = ctx.calibrate(x, y, w, h)
  let x2 = x1 + w_c
  let y2 = y1 + h_c
  draw_border(ctx, x1, y1, x2, y2)
  let children = object_children(shape, all_shapes)
  if children.is_empty() {
    draw_shape_label(ctx, x1, y1, x2, y2, w_c, h_c, shape.label, label_position)
    return
  }

  let mut current_y = y1 + 1
  if shape.label != "" {
    current_y = draw_header(ctx, x1, current_y, x2, w_c, shape.label)
  }
  for child in children {
    if current_y >= y2 {
      break
    }
    let name = short_id(child.id)
    draw_field_with_type(ctx, x1, x2, current_y, w_c, name, child.label)
    current_y += 1
  }
}
