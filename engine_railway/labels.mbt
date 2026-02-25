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
      let is_bold = style_bool(obj.style.bold, false)
      let is_italic = style_bool(obj.style.italic, true)
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
      (
        @cmp.maximum(config.default_width, label_width),
        @cmp.maximum(config.default_height, label_height),
      )
    }
  }
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
