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
struct RouteDrawContext {
  canvas : @ascii.Grid
  chars : @ascii.CharSet
  diagram : @diagram.Diagram
  shape_ctx : ShapeDrawContext
}

///|
fn calibrate_xy(
  ctx : RouteDrawContext,
  x : Double,
  y : Double,
) -> (Double, Double) {
  (
    round_double(x / ctx.shape_ctx.font_width * ctx.shape_ctx.scale),
    round_double(y / ctx.shape_ctx.font_height * ctx.shape_ctx.scale),
  )
}

///|
fn draw_connection_route(
  ctx : RouteDrawContext,
  conn : @diagram.Connection,
  x_offset : Int,
  y_offset : Int,
) -> Unit {
  let raw_source_route = connection_route_points(conn)
  if raw_source_route.length() < 2 {
    return
  }
  let source_routes = route_points_from_graph(
    raw_source_route, x_offset, y_offset,
  )
  let routes_input = route_points_from_graph(
    raw_source_route, x_offset, y_offset,
  )
  let (from_boundary, to_boundary) = get_connection_boundaries(
    ctx,
    conn.src_id,
    conn.dst_id,
  )
  let routes = process_route(ctx, routes_input, from_boundary, to_boundary)
  let turn_dir = calculate_turn_directions(routes)

  let label_pos = if conn.label.trim() != "" {
    calculate_best_label_position(ctx, routes, conn.label)
  } else {
    None
  }

  let corners = build_corner_map(ctx.chars)
  let arrows = build_arrow_map(ctx.chars)

  for i = 1; i < routes.length(); i = i + 1 {
    draw_segment_between_points(
      ctx,
      routes[i - 1],
      routes[i],
      i,
      source_routes.length(),
      source_routes,
      conn,
      corners,
      arrows,
      turn_dir,
      from_boundary,
      to_boundary,
      label_pos,
    )
  }
}

///|
fn route_points_from_graph(
  points : Array[@graph.Point],
  x_offset : Int,
  y_offset : Int,
) -> Array[RoutePoint] {
  let routes : Array[RoutePoint] = []
  for p in points {
    routes.push({ x: p.x + x_offset.to_double(), y: p.y + y_offset.to_double() })
  }
  routes
}

///|
fn process_route(
  ctx : RouteDrawContext,
  routes : Array[RoutePoint],
  from_boundary : Boundary,
  to_boundary : Boundary,
) -> Array[RoutePoint] {
  let mut routes = merge_routes(routes)
  calibrate_routes(ctx, routes)
  routes = force_horizontal_vertical_route(routes)
  if routes.length() >= 2 {
    adjust_route_start_point(ctx, routes, from_boundary)
    routes = adjust_route_end_point(ctx, routes, to_boundary)
  }
  routes
}

///|
fn merge_routes(routes : Array[RoutePoint]) -> Array[RoutePoint] {
  if routes.length() < 2 {
    return routes
  }
  let merged : Array[RoutePoint] = [routes[0]]
  let mut pt = routes[0]
  let mut dir = sign(routes[0].x - routes[1].x) +
    sign(routes[0].y - routes[1].y) * 2
  for j = 1; j < routes.length(); j = j + 1 {
    let current = routes[j]
    let new_dir = sign(pt.x - current.x) + sign(pt.y - current.y) * 2
    if dir != new_dir {
      merged.push(pt)
      dir = new_dir
    }
    pt = current
  }
  let last = merged[merged.length() - 1]
  if last.x != pt.x || last.y != pt.y {
    merged.push(pt)
  }
  merged
}

///|
fn calibrate_routes(ctx : RouteDrawContext, routes : Array[RoutePoint]) -> Unit {
  for i, p in routes {
    let (x, y) = calibrate_xy(ctx, p.x, p.y)
    routes[i] = { x, y }
  }
}

///|
fn force_horizontal_vertical_route(
  routes : Array[RoutePoint],
) -> Array[RoutePoint] {
  if routes.length() < 2 {
    return routes
  }
  let mut has_diagonals = false
  for i = 1; i < routes.length(); i = i + 1 {
    let prev = routes[i - 1]
    let curr = routes[i]
    let dx = (curr.x - prev.x).abs()
    let dy = (curr.y - prev.y).abs()
    if dx > 0.5 && dy > 0.5 {
      has_diagonals = true
      break
    }
  }
  if not(has_diagonals) {
    return routes
  }

  let adjusted : Array[RoutePoint] = [routes[0]]
  for i = 1; i < routes.length(); i = i + 1 {
    let prev = adjusted[adjusted.length() - 1]
    let curr = routes[i]
    let dx = (curr.x - prev.x).abs()
    let dy = (curr.y - prev.y).abs()
    if dx > 0.5 && dy > 0.5 {
      adjusted.push({ x: curr.x, y: prev.y })
    }
    adjusted.push(curr)
  }
  adjusted
}

///|
fn get_connection_boundaries(
  ctx : RouteDrawContext,
  src_id : String,
  dst_id : String,
) -> (Boundary, Boundary) {
  let resolved_src_id = resolve_boundary_shape_id(ctx.diagram.shapes, src_id)
  let resolved_dst_id = resolve_boundary_shape_id(ctx.diagram.shapes, dst_id)
  let mut from_boundary = { tl_x: 0, tl_y: 0, br_x: 0, br_y: 0 }
  let mut to_boundary = { tl_x: 0, tl_y: 0, br_x: 0, br_y: 0 }
  for shape in ctx.diagram.shapes {
    if shape.id == resolved_src_id {
      match get_shape_boundary(ctx.shape_ctx, shape, ctx.diagram.connections) {
        Some(b) => from_boundary = b
        None => ()
      }
    } else if shape.id == resolved_dst_id {
      match get_shape_boundary(ctx.shape_ctx, shape, ctx.diagram.connections) {
        Some(b) => to_boundary = b
        None => ()
      }
    }
  }
  (from_boundary, to_boundary)
}

///|
fn resolve_boundary_shape_id(
  shapes : Array[@diagram.Shape],
  id : String,
) -> String {
  if shape_id_exists(shapes, id) {
    return id
  }
  let original_id = id
  let mut candidate = id
  while true {
    let parent = parent_id(candidate)
    match parent {
      Some(pid) =>
        if shape_id_exists(shapes, pid) {
          return pid
        } else {
          candidate = pid
        }
      None => break
    }
  }
  original_id
}

///|
fn shape_id_exists(shapes : Array[@diagram.Shape], id : String) -> Bool {
  for shape in shapes {
    if shape.id == id {
      return true
    }
  }
  false
}

///|
fn parent_id(id : String) -> String? {
  let mut last_dot = -1
  let mut i = 0
  while i < id.length() {
    if id.code_unit_at(i).to_int() == '.'.to_int() {
      last_dot = i
    }
    i = i + 1
  }
  if last_dot <= 0 {
    None
  } else {
    let sb = StringBuilder::new()
    let mut j = 0
    while j < last_dot {
      sb.write_char(id.code_unit_at(j).to_int().unsafe_to_char())
      j = j + 1
    }
    Some(sb.to_string())
  }
}

///|
fn adjust_route_start_point(
  ctx : RouteDrawContext,
  routes : Array[RoutePoint],
  from_boundary : Boundary,
) -> Unit {
  if routes.length() < 2 {
    return
  }
  let first = routes[0]
  let second = routes[1]
  if from_boundary.contains(round_int(first.x), round_int(first.y)) {
    let mut vector_x = second.x - first.x
    let mut vector_y = second.y - first.y
    let length = (vector_x * vector_x + vector_y * vector_y).sqrt()
    if length > 0.0 {
      vector_x /= length
      vector_y /= length
      let mut x = first.x
      let mut y = first.y
      while from_boundary.contains(round_int(x), round_int(y)) {
        x += vector_x
        y += vector_y
      }
      routes[0] = { x, y }
    }
    return
  }

  if (first.y - second.y).abs() < 0.1 {
    let delta_x = if second.x > first.x {
      1.0
    } else if second.x < first.x {
      -1.0
    } else {
      0.0
    }
    if delta_x != 0.0 {
      let (x, y) = shift_point_until_empty(ctx, first.x, first.y, delta_x, 0.0)
      routes[0] = { x, y }
    }
  } else if (first.x - second.x).abs() < 0.1 {
    let delta_y = if second.y > first.y {
      1.0
    } else if second.y < first.y {
      -1.0
    } else {
      0.0
    }
    if delta_y != 0.0 {
      let (x, y) = shift_point_until_empty(ctx, first.x, first.y, 0.0, delta_y)
      routes[0] = { x, y }
    }
  }
}

///|
fn adjust_route_end_point(
  ctx : RouteDrawContext,
  routes : Array[RoutePoint],
  to_boundary : Boundary,
) -> Array[RoutePoint] {
  if routes.length() < 2 {
    return routes
  }
  let last_idx = routes.length() - 1
  let second_last_idx = last_idx - 1
  let last = routes[last_idx]
  let second_last = routes[second_last_idx]

  if to_boundary.contains(round_int(last.x), round_int(last.y)) {
    let mut vector_x = last.x - second_last.x
    let mut vector_y = last.y - second_last.y
    let length = (vector_x * vector_x + vector_y * vector_y).sqrt()
    if length > 0.0 {
      vector_x /= length
      vector_y /= length
      let mut x = last.x
      let mut y = last.y
      while to_boundary.contains(round_int(x), round_int(y)) {
        x -= vector_x
        y -= vector_y
      }
      routes[last_idx] = { x, y }
    }
    return routes
  }

  if (last.y - second_last.y).abs() < 0.1 {
    let delta_x = if second_last.x > last.x {
      1.0
    } else if second_last.x < last.x {
      -1.0
    } else {
      0.0
    }
    if delta_x != 0.0 {
      let (x, y) = shift_point_until_empty(ctx, last.x, last.y, delta_x, 0.0)
      routes[last_idx] = { x, y }
    }
  } else if (last.x - second_last.x).abs() < 0.1 {
    let delta_y = if second_last.y > last.y {
      1.0
    } else if second_last.y < last.y {
      -1.0
    } else {
      0.0
    }
    if delta_y != 0.0 {
      let (x, y) = shift_point_until_empty(ctx, last.x, last.y, 0.0, delta_y)
      routes[last_idx] = { x, y }
    }
  }
  routes
}

///|
fn shift_point_until_empty(
  ctx : RouteDrawContext,
  start_x : Double,
  start_y : Double,
  delta_x : Double,
  delta_y : Double,
) -> (Double, Double) {
  let mut x = start_x
  let mut y = start_y
  while true {
    let xi = round_int(x)
    let yi = round_int(y)
    if not(ctx.canvas.is_in_bounds(xi, yi)) {
      break
    }
    if ctx.canvas.get(xi, yi) == ' ' {
      break
    }
    x += delta_x
    y += delta_y
  }
  (x, y)
}

///|
fn calculate_turn_directions(routes : Array[RoutePoint]) -> Map[String, String] {
  let turns : Map[String, String] = {}
  if routes.length() < 3 {
    return turns
  }
  for i = 1; i < routes.length() - 1; i = i + 1 {
    let curr = routes[i]
    let prev = routes[i - 1]
    let next = routes[i + 1]
    let key = point_key(round_int(curr.x), round_int(curr.y))
    let dir = "\{sign(curr.x - prev.x)}\{sign(curr.y - prev.y)}\{sign(next.x - curr.x)}\{sign(next.y - curr.y)}"
    turns[key] = dir
  }
  turns
}

///|
fn build_corner_map(chars : @ascii.CharSet) -> Map[String, Char] {
  {
    "-100-1": chars.bottom_left(),
    "0110": chars.bottom_left(),
    "-1001": chars.top_left(),
    "0-110": chars.top_left(),
    "0-1-10": chars.top_right(),
    "1001": chars.top_right(),
    "01-10": chars.bottom_right(),
    "100-1": chars.bottom_right(),
  }
}

///|
fn build_arrow_map(chars : @ascii.CharSet) -> Map[String, Char] {
  {
    "0-1": chars.arrow_up(),
    "10": chars.arrow_right(),
    "01": chars.arrow_down(),
    "-10": chars.arrow_left(),
  }
}

///|
fn point_key(x : Int, y : Int) -> String {
  "\{x}_\{y}"
}

///|
fn draw_segment_between_points(
  ctx : RouteDrawContext,
  start : RoutePoint,
  end : RoutePoint,
  segment_index : Int,
  source_route_count : Int,
  source_routes : Array[RoutePoint],
  conn : @diagram.Connection,
  corners : Map[String, Char],
  arrows : Map[String, Char],
  turn_dir : Map[String, String],
  from_boundary : Boundary,
  to_boundary : Boundary,
  label_pos : RouteLabelPosition?,
) -> Unit {
  let ax = start.x
  let ay = start.y
  let cx = end.x
  let cy = end.y

  let mut sx = cx - ax
  let mut sy = cy - ay
  let step = max_double(sx.abs(), sy.abs())
  if step == 0.0 {
    return
  }
  sx /= step
  sy /= step

  let mut fx = ax
  let mut fy = ay
  let mut attempt = 0
  let mut x = round_int(ax)
  let mut y = round_int(ay)

  while true {
    attempt += 1
    if (x == round_int(cx) && y == round_int(cy)) ||
      attempt == MAX_ROUTE_ATTEMPTS {
      break
    }
    x = round_int(fx)
    y = round_int(fy)

    if not(ctx.canvas.is_in_bounds(x, y)) {
      fx += sx
      fy += sy
      continue
    }
    if ctx.canvas.contains_alphanumeric(x, y) {
      fx += sx
      fy += sy
      continue
    }

    draw_route_point(
      ctx, x, y, sx, sy, segment_index, source_route_count, ax, ay, cx, cy, conn,
      corners, arrows, turn_dir, from_boundary, to_boundary,
    )

    match label_pos {
      Some(pos) =>
        if should_draw_label_at(pos, segment_index - 1, x, y, ax, ay, sx, sy) {
          draw_connection_label(
            ctx,
            pos,
            conn.label,
            "",
            x,
            y,
            sx,
            sy,
            source_routes,
            segment_index,
          )
        }
      None => ()
    }
    fx += sx
    fy += sy
  }
}

///|
fn draw_route_point(
  ctx : RouteDrawContext,
  x : Int,
  y : Int,
  sx : Double,
  sy : Double,
  segment_index : Int,
  route_len : Int,
  ax : Double,
  ay : Double,
  cx : Double,
  cy : Double,
  conn : @diagram.Connection,
  corners : Map[String, Char],
  arrows : Map[String, Char],
  turn_dir : Map[String, String],
  from_boundary : Boundary,
  to_boundary : Boundary,
) -> Unit {
  let key = point_key(x, y)
  match turn_dir.get(key) {
    Some(dir_key) =>
      match corners.get(dir_key) {
        Some(ch) => {
          ctx.canvas.set(x, y, ch)
          return
        }
        None => ()
      }
    None => ()
  }

  if segment_index == route_len - 1 &&
    x == round_int(cx) &&
    y == round_int(cy) &&
    conn.dst_arrow {
    draw_arrowhead(ctx, x, y, sx, sy, arrows)
    return
  }

  if segment_index == 1 &&
    x == round_int(ax) &&
    y == round_int(ay) &&
    conn.src_arrow {
    let arrow_key = "\{sign(sx) * -1}\{sign(sy) * -1}"
    match arrows.get(arrow_key) {
      Some(ch) => ctx.canvas.set(x, y, ch)
      None => ()
    }
    return
  }

  draw_route_segment(ctx, x, y, sx, sy, from_boundary, to_boundary)
}

///|
fn draw_route_segment(
  ctx : RouteDrawContext,
  x : Int,
  y : Int,
  sx : Double,
  sy : Double,
  from_boundary : Boundary,
  to_boundary : Boundary,
) -> Unit {
  if not(ctx.canvas.is_in_bounds(x, y)) {
    return
  }
  let existing = ctx.canvas.get(x, y)
  let overwrite = existing != ' '
  if sx == 0.0 {
    if overwrite &&
      should_draw_t_junction(ctx, x, y, from_boundary, to_boundary, true) {
      if sy > 0.0 {
        ctx.canvas.set(x, y, ctx.chars.t_down())
      } else {
        ctx.canvas.set(x, y, ctx.chars.t_up())
      }
    } else if overwrite &&
      should_skip_overwrite(ctx, x, y, from_boundary, to_boundary) {
      ()
    } else {
      ctx.canvas.set(x, y, ctx.chars.vertical())
    }
  } else if overwrite &&
    should_draw_t_junction(ctx, x, y, from_boundary, to_boundary, false) {
    if sx > 0.0 {
      ctx.canvas.set(x, y, ctx.chars.t_right())
    } else {
      ctx.canvas.set(x, y, ctx.chars.t_left())
    }
  } else {
    ctx.canvas.set(x, y, ctx.chars.horizontal())
  }
}

///|
fn draw_arrowhead(
  ctx : RouteDrawContext,
  x : Int,
  y : Int,
  sx : Double,
  sy : Double,
  arrows : Map[String, Char],
) -> Unit {
  let key = "\{sign(sx)}\{sign(sy)}"
  let ch = match arrows.get(key) {
    Some(v) => v
    None => ' '
  }
  if ctx.canvas.is_in_bounds(x, y) &&
    is_shape_boundary_char(ctx.chars, ctx.canvas.get(x, y)) {
    let arrow_x = x - round_int(sx)
    let arrow_y = y - round_int(sy)
    if ctx.canvas.is_in_bounds(arrow_x, arrow_y) {
      ctx.canvas.set(arrow_x, arrow_y, ch)
    } else {
      ctx.canvas.set(x, y, ch)
    }
  } else {
    ctx.canvas.set(x, y, ch)
  }
}

///|
fn is_shape_boundary_char(chars : @ascii.CharSet, ch : Char) -> Bool {
  ch == chars.horizontal() ||
  ch == chars.vertical() ||
  ch == chars.top_left() ||
  ch == chars.top_right() ||
  ch == chars.bottom_left() ||
  ch == chars.bottom_right() ||
  ch == chars.top_left_arc() ||
  ch == chars.top_right_arc() ||
  ch == chars.bottom_left_arc() ||
  ch == chars.bottom_right_arc()
}

///|
fn should_draw_t_junction(
  ctx : RouteDrawContext,
  x : Int,
  y : Int,
  from_boundary : Boundary,
  to_boundary : Boundary,
  is_vertical : Bool,
) -> Bool {
  if is_vertical {
    if (y == from_boundary.br_y || y == from_boundary.tl_y) &&
      ctx.canvas.get(x, y) == ctx.chars.horizontal() {
      return true
    }
    if (y == to_boundary.br_y || y == to_boundary.tl_y) &&
      ctx.canvas.get(x, y) == ctx.chars.horizontal() {
      return true
    }
  } else {
    if (x == from_boundary.br_x - 1 || x == from_boundary.tl_x - 1) &&
      ctx.canvas.get(x, y) == ctx.chars.vertical() {
      return true
    }
    if (x == to_boundary.br_x - 1 || x == to_boundary.tl_x - 1) &&
      ctx.canvas.get(x, y) == ctx.chars.vertical() {
      return true
    }
  }
  false
}

///|
fn should_skip_overwrite(
  ctx : RouteDrawContext,
  x : Int,
  y : Int,
  from_boundary : Boundary,
  to_boundary : Boundary,
) -> Bool {
  (
    ctx.canvas.get(x, y) == ctx.chars.underscore() &&
    (y == from_boundary.br_y || y == to_boundary.br_y)
  ) ||
  (
    ctx.canvas.get(x, y) == ctx.chars.overline() &&
    (y == from_boundary.tl_y || y == to_boundary.tl_y)
  )
}

///|
fn should_draw_label_at(
  pos : RouteLabelPosition,
  current_index : Int,
  x : Int,
  y : Int,
  ax : Double,
  ay : Double,
  sx : Double,
  sy : Double,
) -> Bool {
  let _ = x
  if pos.i != current_index {
    return false
  }
  if sy != 0.0 {
    round_int(ay) + round_int(pos.max_diff / 2.0) * sign(sy) == y
  } else if sx != 0.0 {
    round_int(ax) + round_int(pos.max_diff / 2.0) * sign(sx) == x
  } else {
    false
  }
}

///|
fn calculate_best_label_position(
  ctx : RouteDrawContext,
  routes : Array[RoutePoint],
  label : String,
) -> RouteLabelPosition? {
  if routes.length() < 2 {
    return None
  }
  let fw = ctx.shape_ctx.font_width
  let fh = ctx.shape_ctx.font_height
  let mut max_diff = 0.0
  let mut best_index = -1
  let mut best_x = 0.0
  let mut scale_old = 0.0
  for i = 0; i < routes.length() - 1; i = i + 1 {
    let diff_y = (routes[i].y - routes[i + 1].y).abs()
    let diff_x = (routes[i].x - routes[i + 1].x).abs()
    let diff = max_double(diff_y, diff_x)
    let scale = sign(diff_x).to_double().abs() * fw +
      sign(diff_y).to_double().abs() * fh
    if diff * scale > max_diff * scale_old {
      max_diff = diff
      best_index = i
      best_x = routes[i].x
      if diff == diff_x && i + 1 < routes.length() {
        let direction = sign(routes[i + 1].x - routes[i].x)
        best_x = routes[i].x + direction.to_double() * diff / 2.0
      }
    }
    scale_old = scale
  }
  if best_index == -1 {
    return None
  }
  let lines = label.split("\n")
  let mut max_line_len = 0
  for line in lines {
    if line.length() > max_line_len {
      max_line_len = line.length()
    }
  }
  Some({
    i: best_index,
    x: round_int(best_x) - max_line_len / 2,
    y: round_int(max_diff / 2.0),
    max_diff,
  })
}

///|
fn draw_connection_label(
  ctx : RouteDrawContext,
  pos : RouteLabelPosition,
  label : String,
  label_position : String,
  x : Int,
  y : Int,
  sx : Double,
  sy : Double,
  routes : Array[RoutePoint],
  segment_index : Int,
) -> Unit {
  let _ = segment_index
  let lines = label.split("\n")
  if sy != 0.0 {
    if ctx.canvas.is_in_bounds(x, y) {
      ctx.canvas.set(x, y, ' ')
    }
    for line_idx, line in lines {
      for j, ch in line {
        if ctx.canvas.is_in_bounds(pos.x + j, y + line_idx) {
          ctx.canvas.set(pos.x + j, y + line_idx, ch)
        }
      }
    }
  } else if sx != 0.0 {
    let y_factor = if label_position.contains("TOP") {
      -1
    } else if label_position.contains("BOTTOM") {
      1
    } else {
      0
    }
    let mut x_pos = pos.x
    if label_position.contains("LEFT") {
      let idx = pos.i + abs_int((sign(sx) - 1) / 2)
      if idx >= 0 && idx < routes.length() {
        x_pos = routes[idx].x.to_int()
      }
    } else if label_position.contains("RIGHT") {
      let mut max_line_len = 0
      for line in lines {
        if line.length() > max_line_len {
          max_line_len = line.length()
        }
      }
      let idx = pos.i + (sign(sx) + 1) / 2
      if idx >= 0 && idx < routes.length() {
        x_pos = routes[idx].x.to_int() - max_line_len / 2
      }
    }
    for line_idx, line in lines {
      for j, ch in line {
        if ctx.canvas.is_in_bounds(x_pos + j, y + y_factor + line_idx) {
          ctx.canvas.set(x_pos + j, y + y_factor + line_idx, ch)
        }
      }
    }
  }
}
