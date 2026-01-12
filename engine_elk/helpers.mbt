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
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn ensure_text_dimensions(graph : Graph) -> Unit {
  for obj in graph.objects {
    ensure_object_text_dimensions(obj)
  }
  for child in graph.root.children {
    ensure_object_text_dimensions(child)
  }
  ensure_object_text_dimensions(graph.root)
  for edge in graph.edges {
    ensure_edge_text_dimensions(edge)
  }
}

///|
fn ensure_object_text_dimensions(obj : Object) -> Unit {
  if obj.label.length() > 0 && obj.label_box is None {
    let label_dims = @text_metrics.measure_label(
      obj.label,
      obj.style.font_size.unwrap_or(16),
      false,
      obj.style.bold.unwrap_or(false),
      obj.style.italic.unwrap_or(false),
    )
    obj.label_box = Some(
      @graph.Box::new(0.0, 0.0, label_dims.width, label_dims.height),
    )
  }
  match obj.box {
    Some(_) => ()
    None =>
      if obj.label.length() > 0 {
        let label_dims = @text_metrics.measure_label(
          obj.label,
          obj.style.font_size.unwrap_or(16),
          false,
          obj.style.bold.unwrap_or(false),
          obj.style.italic.unwrap_or(false),
        )
        let min_width = 100.0
        let min_height = 60.0
        let width = if label_dims.width > min_width {
          label_dims.width
        } else {
          min_width
        }
        let height = if label_dims.height > min_height {
          label_dims.height
        } else {
          min_height
        }
        obj.box = Some(@graph.Box::new(0.0, 0.0, width, height))
      } else {
        obj.box = Some(@graph.Box::new(0.0, 0.0, 100.0, 60.0))
      }
  }
  for child in obj.children {
    ensure_object_text_dimensions(child)
  }
}

///|
fn ensure_edge_text_dimensions(edge : Edge) -> Unit {
  if edge.label.length() > 0 && edge.label_box is None {
    let label_dims = @text_metrics.measure_edge_label(
      edge.label,
      edge.style.font_size.unwrap_or(14),
    )
    edge.label_box = Some(
      @graph.Box::new(0.0, 0.0, label_dims.width, label_dims.height),
    )
  }
}

///|
fn compute_sizes(graph : Graph, config : LayoutConfig) -> Unit {
  for obj in graph.objects {
    compute_object_size(obj, config)
  }
}

///|
fn compute_object_size(obj : Object, config : LayoutConfig) -> Unit {
  // SQL tables use compact row-based sizing (not container spacing)
  if obj.shape_type == @graph.SqlTable {
    let line_height = 18.0 // font_size (14) + 4
    let padding = 8.0
    let header_height = line_height + padding // 26
    let columns_height = obj.children.length().to_double() * line_height +
      padding
    let total_height = header_height + columns_height
    // Width: max of label and column labels (use precomputed label boxes)
    let mut max_width = match obj.label_box {
      Some(b) => b.width
      None =>
        abort(
          "Sql table '\{obj.id}' has no label_box; sizes must be precomputed",
        )
    }
    for child in obj.children {
      match child.label_box {
        Some(b) => if b.width > max_width { max_width = b.width }
        None =>
          abort(
            "Sql table column '\{child.id}' has no label_box; sizes must be precomputed",
          )
      }
    }
    obj.set_box(@graph.Box::new(0.0, 0.0, max_width, total_height))
  } else if obj.is_container() {
    // Container: compute based on children
    let mut max_width = 0.0
    let mut total_height = 0.0
    for child in obj.children {
      compute_object_size(child, config)
      match child.get_box() {
        Some(b) => {
          if b.width > max_width {
            max_width = b.width
          }
          total_height = total_height + b.height + config.vertical_spacing
        }
        None =>
          abort(
            "Container child '\{child.id}' has no box; sizes must be precomputed",
          )
      }
    }
    // Remove last spacing
    if total_height > 0.0 {
      total_height = total_height - config.vertical_spacing
    }
    // Add padding
    let width = max_width + config.container_padding * 2.0
    let height = total_height + config.container_padding * 2.0
    obj.set_box(
      @graph.Box::new(
        0.0,
        0.0,
        max(width, config.default_width),
        max(height, config.default_height),
      ),
    )
  } else {
    // Leaf node: use precomputed size
    match obj.get_box() {
      Some(b) =>
        obj.set_box(
          @graph.Box::new(
            0.0,
            0.0,
            max(b.width, config.default_width),
            max(b.height, config.default_height),
          ),
        )
      None => abort("Object '\{obj.id}' has no box; sizes must be precomputed")
    }
  }
}

///|
fn find_root_objects(graph : Graph) -> Array[Object] {
  let child_ids : Array[String] = []
  for obj in graph.objects {
    for child in obj.children {
      child_ids.push(child.id)
    }
  }
  let roots : Array[Object] = []
  for obj in graph.objects {
    if not(child_ids.contains(obj.id)) {
      roots.push(obj)
    }
  }
  roots
}

///|
fn get_anchor_point(
  box : @graph.Box,
  anchor : String,
  offset : Double,
) -> @graph.Point {
  let cx = box.center().get_x()
  let cy = box.center().get_y()
  match anchor.to_lower() {
    "top" => @graph.Point::new(cx + offset, box.y)
    "bottom" => @graph.Point::new(cx + offset, box.y + box.height)
    "left" => @graph.Point::new(box.x, cy + offset)
    "right" => @graph.Point::new(box.x + box.width, cy + offset)
    "center" => @graph.Point::new(cx + offset, cy)
    "top-left" => @graph.Point::new(box.x, box.y)
    "top-right" => @graph.Point::new(box.x + box.width, box.y)
    "bottom-left" => @graph.Point::new(box.x, box.y + box.height)
    "bottom-right" => @graph.Point::new(box.x + box.width, box.y + box.height)
    _ => @graph.Point::new(cx + offset, cy)
  }
}

///|
fn get_parent_id_from_field(id : String) -> String? {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot <= 0 {
    return None
  }
  let buf = StringBuilder::new()
  for i = 0; i < last_dot; i = i + 1 {
    match id[i].to_char() {
      Some(c) => buf.write_char(c)
      None => ()
    }
  }
  Some(buf.to_string())
}

///|
fn get_sql_row_anchor_point(
  table_box : @graph.Box,
  column_index : Int,
  _num_columns : Int,
  is_left_side : Bool,
) -> @graph.Point {
  let line_height = 18.0
  let header_height = 26.0
  let row_center_y = table_box.y +
    header_height +
    line_height * (column_index.to_double() + 0.7)
  let x = if is_left_side { table_box.x } else { table_box.x + table_box.width }
  @graph.Point::new(x, row_center_y)
}

///|
fn position_sql_table_children(graph : Graph) -> Unit {
  let line_height = 18.0
  let header_height = 26.0
  for obj in graph.objects {
    if obj.shape_type != @graph.SqlTable {
      continue
    }
    guard obj.get_box() is Some(table_box) else { continue }
    for i, child in obj.children {
      let row_center_y = table_box.y +
        header_height +
        line_height * (i.to_double() + 0.7)
      child.set_box(
        @graph.Box::new(
          table_box.x,
          row_center_y - line_height / 2.0,
          table_box.width,
          line_height,
        ),
      )
    }
  }
}

///|
fn calculate_best_anchors(
  src_box : @graph.Box,
  dst_box : @graph.Box,
) -> (String, String) {
  let src_cx = src_box.center().get_x()
  let src_cy = src_box.center().get_y()
  let dst_cx = dst_box.center().get_x()
  let dst_cy = dst_box.center().get_y()
  let dx_center = dst_cx - src_cx
  let dy_center = dst_cy - src_cy
  let src_anchor = if dy_center.abs() >= dx_center.abs() {
    if dy_center > 0.0 {
      "bottom"
    } else {
      "top"
    }
  } else if dx_center > 0.0 {
    "right"
  } else {
    "left"
  }
  let src_point = get_anchor_point(src_box, src_anchor, 0.0)
  let dx_to_dst = dst_cx - src_point.x
  let dy_to_dst = dst_cy - src_point.y
  let dst_anchor = if dy_to_dst.abs() >= dx_to_dst.abs() {
    if dy_to_dst > 0.0 {
      "top"
    } else {
      "bottom"
    }
  } else if dx_to_dst > 0.0 {
    "left"
  } else {
    "right"
  }
  (src_anchor, dst_anchor)
}

///|
pub fn find_edge_intersection(
  box : @graph.Box,
  center : @graph.Point,
  target : @graph.Point,
) -> @graph.Point {
  let dx = target.x - center.x
  let dy = target.y - center.y
  if dx == 0.0 && dy == 0.0 {
    return center
  }
  let half_width = box.width / 2.0
  let half_height = box.height / 2.0
  let mut t = 1.0
  if dx != 0.0 {
    let tx = if dx > 0.0 { half_width / dx } else { -half_width / dx }
    if tx < t {
      t = tx
    }
  }
  if dy != 0.0 {
    let ty = if dy > 0.0 { half_height / dy } else { -half_height / dy }
    if ty < t {
      t = ty
    }
  }
  @graph.Point::new(center.x + dx * t, center.y + dy * t)
}

///|
fn fix_node_overlaps(graph : Graph, config : LayoutConfig) -> Unit {
  let objects = graph.get_objects()
  let min_spacing = config.horizontal_spacing
  let mut changed = true
  let mut iterations = 0
  let max_iterations = objects.length() * 2
  while changed && iterations < max_iterations {
    changed = false
    iterations += 1
    for i in 0..<objects.length() {
      for j in (i + 1)..<objects.length() {
        let obj1 = objects[i]
        let obj2 = objects[j]
        guard obj1.get_box() is Some(box1) else { continue }
        guard obj2.get_box() is Some(box2) else { continue }
        if is_child_of_obj(obj1, obj2) || is_child_of_obj(obj2, obj1) {
          continue
        }
        if box1.intersects(box2) {
          let dx = box2.x - box1.x
          let dy = box2.y - box1.y
          if dy.abs() > dx.abs() {
            if dy >= 0.0 {
              let new_y = box1.y + box1.height + min_spacing
              obj2.set_box(
                @graph.Box::new(box2.x, new_y, box2.width, box2.height),
              )
            } else {
              let new_y = box2.y + box2.height + min_spacing
              obj1.set_box(
                @graph.Box::new(box1.x, new_y, box1.width, box1.height),
              )
            }
          } else if dx >= 0.0 {
            let new_x = box1.x + box1.width + min_spacing
            obj2.set_box(
              @graph.Box::new(new_x, box2.y, box2.width, box2.height),
            )
          } else {
            let new_x = box2.x + box2.width + min_spacing
            obj1.set_box(
              @graph.Box::new(new_x, box1.y, box1.width, box1.height),
            )
          }
          changed = true
        }
      }
    }
  }
}

///|
fn is_child_of_obj(obj1 : Object, obj2 : Object) -> Bool {
  for child in obj2.children {
    if child.id == obj1.id {
      return true
    }
    if is_child_of_obj(obj1, child) {
      return true
    }
  }
  false
}
