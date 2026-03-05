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
fn object_size(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
) -> (Double, Double) {
  object_size_with_objects(obj, config, {})
}

///|
fn object_size_with_objects(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
  object_by_id : Map[String, @graph.ObjectInput],
) -> (Double, Double) {
  if obj.shape_type == @graph.SqlTable && !object_by_id.is_empty() {
    let (estimated_w, estimated_h) = estimate_sql_table_size(obj, object_by_id)
    let (base_w, base_h) = match obj.box {
      Some(b) => (b.width, b.height)
      None => (0.0, 0.0)
    }
    return (
      @cmp.maximum(config.default_width, @cmp.maximum(base_w, estimated_w)),
      @cmp.maximum(config.default_height, @cmp.maximum(base_h, estimated_h)),
    )
  }
  match obj.box {
    Some(b) => (b.width, b.height)
    None => {
      let font_size = match obj.style.font_size {
        Some(v) => v.as_int().unwrap_or(16)
        None => 16
      }
      let is_bold = style_bool(
        obj.style.bold,
        default_object_bold_for_sizing(obj),
      )
      let is_italic = style_bool(obj.style.italic, false)
      let is_mono = style_is_mono(obj.style.font_family)
      let dims = @text_metrics.measure_label(
        obj.label,
        font_size,
        is_mono,
        is_bold,
        is_italic,
      )
      let label_width = if dims.width > 0.0 {
        dims.width + 24.0
      } else {
        config.default_width
      }
      let label_height = if dims.height > 0.0 {
        dims.height + 16.0
      } else {
        config.default_height
      }
      let queue_min_width = if obj.shape_type == @graph.Queue {
        // Queue labels are placed in a narrower inner box.
        // Keep width generous enough to avoid clipping/overflow.
        dims.width + 80.0
      } else {
        0.0
      }
      (
        @cmp.maximum(
          config.default_width,
          @cmp.maximum(label_width, queue_min_width),
        ),
        @cmp.maximum(config.default_height, label_height),
      )
    }
  }
}

///|
fn default_object_bold_for_sizing(obj : @graph.ObjectInput) -> Bool {
  // Keep sizing assumptions aligned with SVG object-label defaults.
  obj.child_ids.is_empty() &&
  obj.shape_type != @graph.Text &&
  obj.shape_type != @graph.Class &&
  obj.shape_type != @graph.SqlTable
}

///|
const SQL_TABLE_NAME_PADDING : Double = 10.0

///|
const SQL_TABLE_TYPE_PADDING : Double = 20.0

///|
const SQL_TABLE_CONSTRAINT_PADDING : Double = 20.0

///|
const SQL_TABLE_HEADER_PADDING : Double = 10.0

///|
const SQL_TABLE_HEADER_FONT_ADD : Int = 4

///|
const SQL_CONSTRAINT_PREFIX : String = "sql_constraint:"

///|
fn estimate_sql_table_size(
  obj : @graph.ObjectInput,
  object_by_id : Map[String, @graph.ObjectInput],
) -> (Double, Double) {
  let row_font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(20)
    None => 20
  }
  let header_font_size = row_font_size + SQL_TABLE_HEADER_FONT_ADD
  let header_dims = @text_metrics.measure_text(
      obj.label,
      header_font_size,
      false,
      true,
      false,
    ).dimensions
  let padded_header_width = header_dims.width + 5.0
  let padded_header_height = header_dims.height + 5.0

  let mut max_name_width = 0.0
  let mut max_type_width = 0.0
  let mut max_constraint_width = 0.0
  let mut row_count = 1

  for child_id in obj.child_ids {
    let child = match object_by_id.get(child_id) {
      Some(v) => v
      None => continue
    }
    row_count = row_count + 1
    let name_width = @text_metrics.measure_text(
        short_name_from_id(child.id),
        row_font_size,
        false,
        false,
        false,
      ).dimensions.width
    if name_width > max_name_width {
      max_name_width = name_width
    }
    let type_width = @text_metrics.measure_text(
        child.label,
        row_font_size,
        false,
        false,
        false,
      ).dimensions.width
    if type_width > max_type_width {
      max_type_width = type_width
    }
    let constraint = sql_table_constraint_abbr_from_object(child)
    if constraint != "" {
      let constraint_width = @text_metrics.measure_text(
          constraint, row_font_size, false, false, false,
        ).dimensions.width
      if constraint_width > max_constraint_width {
        max_constraint_width = constraint_width
      }
    }
  }

  let header_width = SQL_TABLE_HEADER_PADDING +
    padded_header_width +
    SQL_TABLE_HEADER_PADDING
  let mut rows_width = SQL_TABLE_NAME_PADDING +
    max_name_width +
    SQL_TABLE_TYPE_PADDING +
    max_type_width +
    SQL_TABLE_TYPE_PADDING +
    max_constraint_width
  if max_constraint_width > 0.0 {
    rows_width = rows_width + SQL_TABLE_CONSTRAINT_PADDING
  }
  let mut width = if header_width > rows_width {
    header_width
  } else {
    rows_width
  }
  let mut height = padded_header_height * row_count.to_double()
  if width < 12.0 {
    width = 12.0
  }
  if height < 12.0 {
    height = 12.0
  }
  (width.ceil(), height.ceil())
}

///|
fn sql_table_constraint_abbr_from_object(obj : @graph.ObjectInput) -> String {
  let constraints : Array[String] = []
  for cls in obj.classes {
    if cls.has_prefix(SQL_CONSTRAINT_PREFIX) {
      let buf = StringBuilder::new()
      for i = SQL_CONSTRAINT_PREFIX.length(); i < cls.length(); i = i + 1 {
        match cls[i].to_char() {
          Some(ch) => buf.write_char(ch)
          None => ()
        }
      }
      constraints.push(buf.to_string())
    }
  }
  let out : Array[String] = []
  for c in constraints {
    out.push(
      match c {
        "primary_key" => "PK"
        "foreign_key" => "FK"
        "unique" => "UNQ"
        _ => c
      },
    )
  }
  out.join(", ")
}

///|
fn short_name_from_id(id : String) -> String {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot < 0 || last_dot >= id.length() - 1 {
    id
  } else {
    let out = StringBuilder::new()
    for i = last_dot + 1; i < id.length(); i = i + 1 {
      match id[i].to_char() {
        Some(ch) => out.write_char(ch)
        None => ()
      }
    }
    out.to_string()
  }
}

///|
fn recompute_edge_label_boxes(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  lane_by_edge : Map[Int, Int],
) -> Unit {
  let label_boxes : Map[Int, @graph.Box] = {}
  for edge in graph.edges {
    let route = match patch.edges.get(edge.index) {
      Some(v) => v
      None => continue
    }
    if route.is_empty() {
      continue
    }
    let (width, height) = match edge_label_size(edge) {
      Some(v) => v
      None => continue
    }
    let center = route_point_at_percent(route, 0.5)
    label_boxes[edge.index] = @graph.Box::new(
      center.x - width / 2.0,
      center.y - height / 2.0,
      width,
      height,
    )
  }
  resolve_edge_label_collisions(label_boxes, direction, config, lane_by_edge)
  resolve_edge_label_obstacles(label_boxes, patch, graph, config)
  resolve_edge_label_collisions(label_boxes, direction, config, lane_by_edge)
  for entry in label_boxes {
    patch.edge_labels[entry.0] = entry.1
  }
}

///|
priv struct LabelInterval {
  edge_index : Int
  minor_start : Double
  minor_end : Double
  major_span : Double
}

///|
fn resolve_edge_label_collisions(
  label_boxes : Map[Int, @graph.Box],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  lane_by_edge : Map[Int, Int],
) -> Unit {
  let vertical = match direction {
    Down | Up => true
    Right | Left => false
  }
  let bucket_size = @cmp.maximum(16.0, config.edge_padding)
  let grouped : Map[Int, Array[LabelInterval]] = {}
  for entry in label_boxes {
    let edge_index = entry.0
    let box = entry.1
    let major_center = if vertical {
      box.y + box.height / 2.0
    } else {
      box.x + box.width / 2.0
    }
    let minor_start = if vertical { box.x } else { box.y }
    let minor_end = if vertical {
      box.x + box.width
    } else {
      box.y + box.height
    }
    let major_span = if vertical { box.height } else { box.width }
    let bucket = (major_center / bucket_size + 0.5).to_int()
    let interval = { edge_index, minor_start, minor_end, major_span }
    match grouped.get(bucket) {
      Some(items) => items.push(interval)
      None => grouped[bucket] = [interval]
    }
  }
  for bucket_entry in grouped {
    let items = bucket_entry.1
    if items.length() <= 1 {
      continue
    }
    let ordered = items.copy()
    ordered.sort_by(fn(a, b) {
      if a.minor_start < b.minor_start {
        -1
      } else if a.minor_start > b.minor_start {
        1
      } else if a.minor_end < b.minor_end {
        -1
      } else if a.minor_end > b.minor_end {
        1
      } else {
        let lane_a = lane_by_edge.get(a.edge_index).unwrap_or(0)
        let lane_b = lane_by_edge.get(b.edge_index).unwrap_or(0)
        if lane_a != lane_b {
          lane_a - lane_b
        } else {
          a.edge_index - b.edge_index
        }
      }
    })
    let lane_ends : Array[Double] = []
    let lane_by_edge : Map[Int, Int] = {}
    let mut max_major_span = 0.0
    for item in ordered {
      if item.major_span > max_major_span {
        max_major_span = item.major_span
      }
      let mut lane = -1
      for i in 0..<lane_ends.length() {
        if lane_ends[i] <= item.minor_start + 1.0e-6 {
          lane = i
          break
        }
      }
      if lane == -1 {
        lane = lane_ends.length()
        lane_ends.push(item.minor_end)
      } else {
        lane_ends[lane] = item.minor_end
      }
      lane_by_edge[item.edge_index] = lane
    }
    let lane_count = lane_ends.length()
    if lane_count <= 1 {
      continue
    }
    let center = (lane_count - 1).to_double() / 2.0
    let spacing = @cmp.maximum(max_major_span + 4.0, config.edge_padding / 2.0)
    for lane_entry in lane_by_edge {
      let edge_index = lane_entry.0
      let lane = lane_entry.1
      let shift = (lane.to_double() - center) * spacing
      match label_boxes.get(edge_index) {
        Some(box) =>
          label_boxes[edge_index] = if vertical {
            @graph.Box::new(box.x, box.y + shift, box.width, box.height)
          } else {
            @graph.Box::new(box.x + shift, box.y, box.width, box.height)
          }
        None => ()
      }
    }
  }
}

///|
fn resolve_edge_label_obstacles(
  label_boxes : Map[Int, @graph.Box],
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
) -> Unit {
  if label_boxes.is_empty() {
    return
  }
  let edge_by_index : Map[Int, @graph.EdgeInput] = {}
  for edge in graph.edges {
    edge_by_index[edge.index] = edge
  }
  let order : Array[Int] = []
  for entry in label_boxes {
    order.push(entry.0)
  }
  order.sort()
  let route_by_edge : Map[Int, Array[@graph.Point]] = {}
  for entry in patch.edges {
    route_by_edge[entry.0] = entry.1
  }
  let step = @cmp.maximum(8.0, config.edge_padding * 0.55)
  let max_rings = 14
  for edge_index in order {
    let base = match label_boxes.get(edge_index) {
      Some(box) => box
      None => continue
    }
    let edge = match edge_by_index.get(edge_index) {
      Some(v) => v
      None => continue
    }
    let route = route_by_edge.get(edge_index).unwrap_or([])
    let anchors : Array[@graph.Point] = []
    anchors.push(
      @graph.Point::new(base.x + base.width / 2.0, base.y + base.height / 2.0),
    )
    if route.length() >= 2 {
      anchors.push(route_point_at_percent(route, 0.35))
      anchors.push(route_point_at_percent(route, 0.5))
      anchors.push(route_point_at_percent(route, 0.65))
    }

    let mut best = base
    let mut best_score = label_obstacle_score(
      edge_index, base, base, edge, label_boxes, patch,
    )
    let mut best_feasible = base
    let mut best_feasible_score = 0.0
    let mut has_feasible = false
    for anchor in anchors {
      for ring in 0..<=max_rings {
        let d = ring.to_double() * step
        let candidates : Array[(Double, Double)] = if ring == 0 {
          [(0.0, 0.0)]
        } else {
          [
            (d, 0.0),
            (-d, 0.0),
            (0.0, d),
            (0.0, -d),
            (d, d),
            (d, -d),
            (-d, d),
            (-d, -d),
            (2.0 * d, 0.0),
            (-2.0 * d, 0.0),
            (0.0, 2.0 * d),
            (0.0, -2.0 * d),
          ]
        }
        for candidate in candidates {
          let center_x = anchor.x + candidate.0
          let center_y = anchor.y + candidate.1
          let trial = @graph.Box::new(
            center_x - base.width / 2.0,
            center_y - base.height / 2.0,
            base.width,
            base.height,
          )
          let score = label_obstacle_score(
            edge_index, trial, base, edge, label_boxes, patch,
          )
          if score < best_score {
            best = trial
            best_score = score
          }
          if label_candidate_is_feasible(
              edge_index, trial, edge, label_boxes, patch,
            ) {
            let feasible_score = label_feasible_cost(trial, base)
            if !has_feasible || feasible_score < best_feasible_score {
              has_feasible = true
              best_feasible = trial
              best_feasible_score = feasible_score
            }
          }
        }
      }
    }
    label_boxes[edge_index] = if has_feasible { best_feasible } else { best }
  }
}

///|
fn label_candidate_is_feasible(
  edge_index : Int,
  box : @graph.Box,
  edge : @graph.EdgeInput,
  label_boxes : Map[Int, @graph.Box],
  patch : @graph.LayoutPatch,
) -> Bool {
  for entry in label_boxes {
    let other_edge = entry.0
    if other_edge == edge_index {
      continue
    }
    if overlap_area(box, entry.1) > 0.0 {
      return false
    }
  }
  for entry in patch.nodes {
    let node_id = entry.0
    if node_id == edge.src_id || node_id == edge.dst_id {
      continue
    }
    if overlap_area(box, entry.1) > 0.0 {
      return false
    }
  }
  for entry in patch.node_labels {
    let node_id = entry.0
    if node_id == edge.src_id || node_id == edge.dst_id {
      continue
    }
    let buffered = expanded_box(entry.1, 6.0)
    if overlap_area(box, buffered) > 0.0 {
      return false
    }
  }
  for entry in patch.edges {
    let other_edge = entry.0
    if other_edge == edge_index {
      continue
    }
    let route = entry.1
    if route.length() < 2 {
      continue
    }
    for i in 0..<(route.length() - 1) {
      if segment_intersects_box(route[i], route[i + 1], box) {
        return false
      }
    }
  }
  true
}

///|
fn label_feasible_cost(box : @graph.Box, base : @graph.Box) -> Double {
  ((box.x - base.x).abs() + (box.y - base.y).abs()) * 0.8
}

///|
fn label_obstacle_score(
  edge_index : Int,
  box : @graph.Box,
  base : @graph.Box,
  edge : @graph.EdgeInput,
  label_boxes : Map[Int, @graph.Box],
  patch : @graph.LayoutPatch,
) -> Double {
  let mut score = 0.0
  // Keep labels near original midpoint unless a collision forces movement.
  score += ((box.x - base.x).abs() + (box.y - base.y).abs()) * 0.2

  for entry in label_boxes {
    let other_edge = entry.0
    if other_edge == edge_index {
      continue
    }
    let other = entry.1
    let area = overlap_area(box, other)
    if area > 0.0 {
      score += 1200.0 + area * 8.0
    }
  }

  for entry in patch.nodes {
    let node_id = entry.0
    if node_id == edge.src_id || node_id == edge.dst_id {
      continue
    }
    let node_box = entry.1
    let area = overlap_area(box, node_box)
    if area > 0.0 {
      score += 1600.0 + area * 10.0
    }
  }
  for entry in patch.node_labels {
    let node_id = entry.0
    if node_id == edge.src_id || node_id == edge.dst_id {
      continue
    }
    let label_box = expanded_box(entry.1, 6.0)
    let area = overlap_area(box, label_box)
    if area > 0.0 {
      score += 2200.0 + area * 12.0
    }
  }

  for entry in patch.edges {
    let other_edge = entry.0
    let route = entry.1
    if route.length() < 2 {
      continue
    }
    for i in 0..<(route.length() - 1) {
      let a = route[i]
      let b = route[i + 1]
      if segment_intersects_box(a, b, box) {
        if other_edge == edge_index {
          score += 4.0
        } else {
          score += 280.0
        }
      }
    }
  }
  score
}

///|
fn overlap_area(a : @graph.Box, b : @graph.Box) -> Double {
  let left = @cmp.maximum(a.x, b.x)
  let right = @cmp.minimum(a.x + a.width, b.x + b.width)
  let top = @cmp.maximum(a.y, b.y)
  let bottom = @cmp.minimum(a.y + a.height, b.y + b.height)
  if right <= left || bottom <= top {
    0.0
  } else {
    (right - left) * (bottom - top)
  }
}

///|
fn expanded_box(box : @graph.Box, padding : Double) -> @graph.Box {
  @graph.Box::new(
    box.x - padding,
    box.y - padding,
    box.width + padding * 2.0,
    box.height + padding * 2.0,
  )
}

///|
fn ranges_overlap(a0 : Double, a1 : Double, b0 : Double, b1 : Double) -> Bool {
  let lo_a = @cmp.minimum(a0, a1)
  let hi_a = @cmp.maximum(a0, a1)
  let lo_b = @cmp.minimum(b0, b1)
  let hi_b = @cmp.maximum(b0, b1)
  !(hi_a < lo_b || hi_b < lo_a)
}

///|
fn segment_intersects_box(
  a : @graph.Point,
  b : @graph.Point,
  box : @graph.Box,
) -> Bool {
  let left = box.x
  let right = box.x + box.width
  let top = box.y
  let bottom = box.y + box.height
  let tol = 1.0e-6
  if (a.x - b.x).abs() <= tol {
    // Vertical segment.
    a.x >= left - tol &&
    a.x <= right + tol &&
    ranges_overlap(a.y, b.y, top, bottom)
  } else if (a.y - b.y).abs() <= tol {
    // Horizontal segment.
    a.y >= top - tol &&
    a.y <= bottom + tol &&
    ranges_overlap(a.x, b.x, left, right)
  } else {
    // Defensive fallback for non-orthogonal segments.
    ranges_overlap(a.x, b.x, left, right) &&
    ranges_overlap(a.y, b.y, top, bottom)
  }
}

///|
fn edge_label_size(edge : @graph.EdgeInput) -> (Double, Double)? {
  match edge.label_box {
    Some(box) => {
      let width = if box.width > 0.0 { box.width } else { 0.0 }
      let height = if box.height > 0.0 { box.height } else { 0.0 }
      if width > 0.0 && height > 0.0 {
        Some((width, height))
      } else {
        fallback_edge_label_size(edge)
      }
    }
    None => fallback_edge_label_size(edge)
  }
}

///|
fn fallback_edge_label_size(edge : @graph.EdgeInput) -> (Double, Double)? {
  if edge.label.is_empty() {
    return None
  }
  let font_size = match edge.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(edge.style.bold, false)
  let is_italic = style_bool(edge.style.italic, true)
  let is_mono = style_is_mono(edge.style.font_family)
  let dims = @text_metrics.measure_label(
    edge.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  let width = if dims.width > 0.0 {
    dims.width
  } else {
    edge.label.length().to_double() * 7.0
  }
  let height = if dims.height > 0.0 {
    dims.height
  } else {
    font_size.to_double() + 5.0
  }
  Some((width, height))
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
const RAILWAY_LABEL_BOX_PADDING : Double = 2.0

///|
const RAILWAY_CONTAINER_LABEL_INSET : Double = 5.0

///|
fn recompute_container_label_boxes_railway(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  let bounds = patch_label_bounds_railway(patch)
  let placed_labels : Map[String, @graph.Box] = {}
  for obj in graph.objects {
    if !is_layout_container_candidate(obj) ||
      is_grid_container_candidate(obj) ||
      obj.label == "" {
      continue
    }
    let container_box = match patch.nodes.get(obj.id) {
      Some(v) => v
      None => continue
    }
    let (label_width, label_height) = match
      container_label_dimensions_railway(obj) {
      Some(v) => v
      None => continue
    }
    let candidates = container_label_candidates_railway(
      container_box, label_width, label_height,
    )
    if candidates.is_empty() {
      continue
    }
    let mut best_box = candidates[0]
    let mut best_score = container_label_score_railway(
      best_box,
      patch,
      obj.id,
      container_box,
      placed_labels,
      bounds,
      0,
    )
    for i in 1..<candidates.length() {
      let candidate = candidates[i]
      let score = container_label_score_railway(
        candidate,
        patch,
        obj.id,
        container_box,
        placed_labels,
        bounds,
        i,
      )
      if score < best_score {
        best_box = candidate
        best_score = score
      }
    }
    patch.node_labels[obj.id] = best_box
    placed_labels[obj.id] = best_box
  }
}

///|
fn patch_label_bounds_railway(
  patch : @graph.LayoutPatch,
) -> (Double, Double, Double, Double) {
  let mut seen = false
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  fn update_bounds(
    p_x : Double,
    p_y : Double,
    seen_ref : Bool,
    min_x_ref : Double,
    min_y_ref : Double,
    max_x_ref : Double,
    max_y_ref : Double,
  ) -> (Bool, Double, Double, Double, Double) {
    if !seen_ref {
      return (true, p_x, p_y, p_x, p_y)
    }
    (
      true,
      @cmp.minimum(min_x_ref, p_x),
      @cmp.minimum(min_y_ref, p_y),
      @cmp.maximum(max_x_ref, p_x),
      @cmp.maximum(max_y_ref, p_y),
    )
  }
  for entry in patch.nodes {
    let box = entry.1
    let r0 = update_bounds(box.x, box.y, seen, min_x, min_y, max_x, max_y)
    seen = r0.0
    min_x = r0.1
    min_y = r0.2
    max_x = r0.3
    max_y = r0.4
    let r1 = update_bounds(
      box.x + box.width,
      box.y + box.height,
      seen,
      min_x,
      min_y,
      max_x,
      max_y,
    )
    seen = r1.0
    min_x = r1.1
    min_y = r1.2
    max_x = r1.3
    max_y = r1.4
  }
  for entry in patch.edges {
    for p in entry.1 {
      let r = update_bounds(p.x, p.y, seen, min_x, min_y, max_x, max_y)
      seen = r.0
      min_x = r.1
      min_y = r.2
      max_x = r.3
      max_y = r.4
    }
  }
  if !seen {
    (0.0, 0.0, 0.0, 0.0)
  } else {
    (min_x, min_y, max_x, max_y)
  }
}

///|
fn container_label_candidates_railway(
  container_box : @graph.Box,
  label_width : Double,
  label_height : Double,
) -> Array[@graph.Box] {
  let candidates : Array[@graph.Box] = []
  let min_x = container_box.x + RAILWAY_CONTAINER_LABEL_INSET
  let max_x = container_box.x +
    container_box.width -
    RAILWAY_CONTAINER_LABEL_INSET -
    label_width
  let center_x = container_box.x + (container_box.width - label_width) / 2.0
  let clamped_center_x = clamp_label_x(center_x, min_x, max_x)
  let clamped_left_x = clamp_label_x(min_x, min_x, max_x)
  let clamped_right_x = clamp_label_x(max_x, min_x, max_x)
  let inside_y = container_box.y + RAILWAY_CONTAINER_LABEL_INSET
  let outside_y = container_box.y - RAILWAY_CONTAINER_LABEL_INSET - label_height
  candidates.push(
    @graph.Box::new(clamped_center_x, outside_y, label_width, label_height),
  )
  candidates.push(
    @graph.Box::new(clamped_left_x, outside_y, label_width, label_height),
  )
  candidates.push(
    @graph.Box::new(clamped_right_x, outside_y, label_width, label_height),
  )
  candidates.push(
    @graph.Box::new(clamped_center_x, inside_y, label_width, label_height),
  )
  candidates.push(
    @graph.Box::new(clamped_left_x, inside_y, label_width, label_height),
  )
  candidates.push(
    @graph.Box::new(clamped_right_x, inside_y, label_width, label_height),
  )
  candidates
}

///|
fn clamp_label_x(x : Double, lo : Double, hi : Double) -> Double {
  if hi < lo {
    return lo
  }
  if x < lo {
    lo
  } else if x > hi {
    hi
  } else {
    x
  }
}

///|
fn container_label_score_railway(
  candidate : @graph.Box,
  patch : @graph.LayoutPatch,
  container_id : String,
  container_box : @graph.Box,
  placed_labels : Map[String, @graph.Box],
  bounds : (Double, Double, Double, Double),
  candidate_order : Int,
) -> Double {
  let padded = @graph.Box::new(
    candidate.x - RAILWAY_LABEL_BOX_PADDING,
    candidate.y - RAILWAY_LABEL_BOX_PADDING,
    candidate.width + 2.0 * RAILWAY_LABEL_BOX_PADDING,
    candidate.height + 2.0 * RAILWAY_LABEL_BOX_PADDING,
  )
  let mut score = candidate_order.to_double() * 12.0
  let horizontal_left_overhang = container_box.x - candidate.x
  if horizontal_left_overhang > 0.0 {
    score = score + 500.0 + horizontal_left_overhang * 40.0
  }
  let horizontal_right_overhang = candidate.x +
    candidate.width -
    (container_box.x + container_box.width)
  if horizontal_right_overhang > 0.0 {
    score = score + 500.0 + horizontal_right_overhang * 40.0
  }
  let min_x = bounds.0
  let min_y = bounds.1
  let max_x = bounds.2
  let max_y = bounds.3
  let overflow_left = min_x - padded.x
  if overflow_left > 0.0 {
    score = score + 1200.0 + overflow_left * 40.0
  }
  let overflow_top = min_y - padded.y
  if overflow_top > 0.0 {
    score = score + 1200.0 + overflow_top * 40.0
  }
  let overflow_right = padded.x + padded.width - max_x
  if overflow_right > 0.0 {
    score = score + 1200.0 + overflow_right * 40.0
  }
  let overflow_bottom = padded.y + padded.height - max_y
  if overflow_bottom > 0.0 {
    score = score + 1200.0 + overflow_bottom * 40.0
  }
  for entry in patch.nodes {
    let node_id = entry.0
    if node_id == container_id {
      continue
    }
    let node_box = entry.1
    let overlap = overlap_area(padded, node_box)
    if overlap > 0.0 {
      score = score + 20000.0 + overlap * 10.0
    }
  }
  for entry in patch.edge_labels {
    let overlap = overlap_area(padded, entry.1)
    if overlap > 0.0 {
      score = score + 12000.0 + overlap * 8.0
    }
  }
  for entry in placed_labels {
    let overlap = overlap_area(padded, entry.1)
    if overlap > 0.0 {
      score = score + 30000.0 + overlap * 10.0
    }
  }
  for entry in patch.edges {
    let route = entry.1
    if route.length() <= 1 {
      continue
    }
    for i in 0..<(route.length() - 1) {
      score = score +
        edge_segment_label_overlap_penalty(route[i], route[i + 1], padded)
    }
  }
  score
}

///|
fn edge_segment_label_overlap_penalty(
  a : @graph.Point,
  b : @graph.Point,
  box : @graph.Box,
) -> Double {
  if !segment_intersects_box(a, b, box) {
    return 0.0
  }
  let left = box.x
  let right = box.x + box.width
  let top = box.y
  let bottom = box.y + box.height
  let tol = 1.0e-6
  if (a.x - b.x).abs() <= tol {
    let overlap = @cmp.minimum(@cmp.maximum(a.y, b.y), bottom) -
      @cmp.maximum(@cmp.minimum(a.y, b.y), top)
    let center_x = box.x + box.width / 2.0
    let half_width = @cmp.maximum(box.width / 2.0, 1.0)
    let norm = @cmp.minimum((a.x - center_x).abs() / half_width, 1.0)
    let center_factor = 1.0 - norm * 0.85
    6000.0 + overlap * (30.0 + 60.0 * center_factor)
  } else if (a.y - b.y).abs() <= tol {
    let overlap = @cmp.minimum(@cmp.maximum(a.x, b.x), right) -
      @cmp.maximum(@cmp.minimum(a.x, b.x), left)
    let center_y = box.y + box.height / 2.0
    let half_height = @cmp.maximum(box.height / 2.0, 1.0)
    let norm = @cmp.minimum((a.y - center_y).abs() / half_height, 1.0)
    let center_factor = 1.0 - norm * 0.85
    6000.0 + overlap * (30.0 + 60.0 * center_factor)
  } else {
    12000.0
  }
}
