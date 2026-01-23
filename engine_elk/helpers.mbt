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
const FONT_SIZE_M : Int = 16

///|
const FONT_SIZE_L : Int = 20

///|
const FONT_SIZE_XL : Int = 24

///|
const FONT_SIZE_XXL : Int = 28

///|
const HEADER_FONT_ADD : Int = 4

///|
const SQL_TABLE_NAME_PADDING : Double = 10.0

///|
const SQL_TABLE_TYPE_PADDING : Double = 20.0

///|
const SQL_TABLE_CONSTRAINT_PADDING : Double = 20.0

///|
const SQL_TABLE_HEADER_PADDING : Double = 10.0

///|
const SQL_TABLE_MIN_SIZE : Double = 12.0

///|
const SQL_CONSTRAINT_PREFIX : String = "sql_constraint:"

///|
fn label_size_for_level(level : Int) -> Int {
  // D2 ContainerLevel.LabelSize: 1->XXL, 2->XL, 3->L, else M.
  if level == 1 {
    FONT_SIZE_XXL
  } else if level == 2 {
    FONT_SIZE_XL
  } else if level == 3 {
    FONT_SIZE_L
  } else {
    FONT_SIZE_M
  }
}

///|
fn is_container(obj : Object) -> Bool {
  obj.children.length() > 0
}

///|
fn is_container_for_label_size(obj : Object) -> Bool {
  let has_grid = obj.grid_rows is Some(_) || obj.grid_columns is Some(_)
  (obj.children.length() > 0 || has_grid) &&
  obj.shape_type != @graph.SqlTable &&
  obj.shape_type != @graph.Class
}

///|
fn collect_container_levels(graph : Graph, levels : Map[String, Int]) -> Unit {
  let roots = if graph.root.children.is_empty() {
    find_root_objects(graph)
  } else {
    graph.root.children
  }
  for obj in roots {
    assign_level_rec(obj, 1, levels)
  }
}

///|
fn assign_level_rec(
  obj : Object,
  level : Int,
  levels : Map[String, Int],
) -> Unit {
  levels[obj.id] = level
  for child in obj.children {
    assign_level_rec(child, level + 1, levels)
  }
}

///|
fn get_label_font_info(
  obj : Object,
  levels : Map[String, Int],
) -> (Int, Bool, Bool, Bool) {
  let mut is_bold = !is_container(obj) && obj.shape_type != @graph.Text
  let mut is_italic = false
  if obj.style.bold is Some(v) && v.as_bool().unwrap_or(false) {
    is_bold = true
  }
  if obj.style.italic is Some(v) && v.as_bool().unwrap_or(false) {
    is_italic = true
  }
  let mut font_size = FONT_SIZE_M
  if obj.shape_type == @graph.Class || obj.shape_type == @graph.SqlTable {
    font_size = FONT_SIZE_L
  }
  if is_container_for_label_size(obj) && obj.shape_type != @graph.Text {
    let level = levels.get(obj.id).unwrap_or(1)
    font_size = label_size_for_level(level)
  }
  if obj.style.font_size is Some(v) {
    font_size = v.as_int().unwrap_or(font_size)
  }
  if obj.shape_type == @graph.Class || obj.shape_type == @graph.SqlTable {
    font_size = font_size + HEADER_FONT_ADD
  }
  if obj.shape_type == @graph.Class || obj.shape_type == @graph.SqlTable {
    is_bold = false
  }
  let is_mono = match obj.style.font {
    Some(v) => v.get_value().to_lower() == "mono"
    None => obj.shape_type == @graph.Code
  }
  (font_size, is_bold, is_italic, is_mono)
}

///|
fn get_edge_label_font_info(edge : Edge) -> (Int, Bool, Bool) {
  let mut font_size = FONT_SIZE_M
  if edge.style.font_size is Some(v) {
    font_size = v.as_int().unwrap_or(font_size)
  }
  let is_bold = match edge.style.bold {
    Some(v) => v.as_bool().unwrap_or(false)
    None => false
  }
  // D2 defaults edge labels to italic.
  (font_size, is_bold, true)
}

///|
fn ensure_text_dimensions(graph : Graph) -> Unit {
  let levels : Map[String, Int] = {}
  collect_container_levels(graph, levels)
  for obj in graph.objects {
    ensure_object_text_dimensions(obj, levels)
  }
  for child in graph.root.children {
    ensure_object_text_dimensions(child, levels)
  }
  ensure_object_text_dimensions(graph.root, levels)
  for edge in graph.edges {
    ensure_edge_text_dimensions(edge)
  }
}

///|
fn ensure_object_text_dimensions(
  obj : Object,
  levels : Map[String, Int],
) -> Unit {
  if obj.label.length() > 0 && obj.label_box is None {
    let (font_size, bold, italic, is_mono) = get_label_font_info(obj, levels)
    let label_dims = @text_metrics.measure_label(
      obj.label,
      font_size,
      is_mono,
      bold,
      italic,
    )
    obj.label_box = Some(
      @graph.Box::new(0.0, 0.0, label_dims.width, label_dims.height),
    )
  }
  match obj.box {
    Some(_) => ()
    None =>
      if obj.label.length() > 0 {
        let (font_size, bold, italic, is_mono) = get_label_font_info(
          obj, levels,
        )
        let label_dims = @text_metrics.measure_label(
          obj.label,
          font_size,
          is_mono,
          bold,
          italic,
        )
        let size = d2_size_object_to_content(obj, {
          width: label_dims.width,
          height: label_dims.height,
        })
        obj.box = Some(@graph.Box::new(0.0, 0.0, size.width, size.height))
      } else {
        obj.box = Some(@graph.Box::new(0.0, 0.0, 100.0, 60.0))
      }
  }
  for child in obj.children {
    ensure_object_text_dimensions(child, levels)
  }
}

///|
fn ensure_edge_text_dimensions(edge : Edge) -> Unit {
  if edge.label.length() > 0 && edge.label_box is None {
    let (font_size, bold, italic) = get_edge_label_font_info(edge)
    let label_dims = @text_metrics.measure_label(
      edge.label,
      font_size,
      false,
      bold,
      italic,
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
    let (font_size, _bold, _italic, _is_mono) = get_label_font_info(obj, {})
    let label_dims : Size = match obj.label_box {
      Some(b) => { width: b.width, height: b.height }
      None => {
        let dims = @text_metrics.measure_label(
          obj.label,
          font_size,
          false,
          false,
          false,
        )
        obj.label_box = Some(@graph.Box::new(0.0, 0.0, dims.width, dims.height))
        { width: dims.width, height: dims.height }
      }
    }

    // Column font size follows D2: L unless overridden.
    let col_font_size = match obj.style.font_size {
      Some(v) => v.as_int().unwrap_or(FONT_SIZE_L)
      None => FONT_SIZE_L
    }
    let mut max_name_width = 0.0
    let mut max_type_width = 0.0
    let mut max_constraint_width = 0.0
    for child in obj.children {
      let name = get_short_name_from_id(child.id)
      let name_dims = @text_metrics.measure_label(
        name, col_font_size, false, false, false,
      )
      if name_dims.width > max_name_width {
        max_name_width = name_dims.width
      }
      let type_dims = @text_metrics.measure_label(
        child.label,
        col_font_size,
        false,
        false,
        false,
      )
      if type_dims.width > max_type_width {
        max_type_width = type_dims.width
      }
      let constraint = sql_table_constraint_abbr(child)
      if constraint.length() > 0 {
        let constraint_dims = @text_metrics.measure_label(
          constraint, col_font_size, false, false, false,
        )
        if constraint_dims.width > max_constraint_width {
          max_constraint_width = constraint_dims.width
        }
      }
    }
    let header_width = SQL_TABLE_HEADER_PADDING * 2.0 + label_dims.width
    let mut rows_width = SQL_TABLE_NAME_PADDING +
      max_name_width +
      SQL_TABLE_TYPE_PADDING +
      max_type_width +
      SQL_TABLE_TYPE_PADDING +
      max_constraint_width
    if max_constraint_width > 0.0 {
      rows_width = rows_width + SQL_TABLE_CONSTRAINT_PADDING
    }
    let width = max(SQL_TABLE_MIN_SIZE, max(header_width, rows_width))
    // D2 uses the header label's measured height (header font) as the base row
    // height for sql_table. Our text metrics are approximate; match D2's
    // row-height behavior by scaling from the header font size.
    let row_height = (@math.ceil(font_size.to_double() * 1.5))
    let total_height = max(
      SQL_TABLE_MIN_SIZE,
      row_height * (obj.children.length() + 1).to_double(),
    )
    obj.box = Some(@graph.Box::new(0.0, 0.0, width, total_height))
  } else {
    // For all non-sql_table objects, use the precomputed size. Compound nodes
    // (containers) are expanded later by the ELK layered algorithm itself.
    for child in obj.children {
      compute_object_size(child, config)
    }
    match obj.box {
      Some(_) => ()
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
fn get_short_name_from_id(id : String) -> String {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot >= 0 && last_dot < id.length() - 1 {
    let buf = StringBuilder::new()
    for i = last_dot + 1; i < id.length(); i = i + 1 {
      match id[i].to_char() {
        Some(c) => buf.write_char(c)
        None => ()
      }
    }
    buf.to_string()
  } else {
    id
  }
}

///|
fn strip_prefix(s : String, prefix : String) -> String? {
  if !s.has_prefix(prefix) {
    return None
  }
  let start = prefix.length()
  let buf = StringBuilder::new()
  for i = start; i < s.length(); i = i + 1 {
    match s[i].to_char() {
      Some(c) => buf.write_char(c)
      None => ()
    }
  }
  Some(buf.to_string())
}

///|
fn sql_table_constraint_abbr(child : Object) -> String {
  let constraints : Array[String] = []
  for cls in child.classes {
    match strip_prefix(cls, SQL_CONSTRAINT_PREFIX) {
      Some(v) => constraints.push(v)
      None => ()
    }
  }
  let abbrs : Array[String] = []
  for c in constraints {
    let abbr = match c {
      "primary_key" => "PK"
      "foreign_key" => "FK"
      "unique" => "UNQ"
      _ => c
    }
    abbrs.push(abbr)
  }
  abbrs.join(", ")
}

///|
fn get_sql_row_anchor_point(
  table_box : @graph.Box,
  column_index : Int,
  num_columns : Int,
  is_left_side : Bool,
) -> @graph.Point {
  let row_height = table_box.height / (num_columns + 1).to_double()
  let row_center_y = table_box.y +
    row_height * (column_index.to_double() + 1.0) +
    row_height / 2.0
  let x = if is_left_side { table_box.x } else { table_box.x + table_box.width }
  @graph.Point::new(x, row_center_y)
}

///|
fn position_sql_table_children(graph : Graph) -> Unit {
  for obj in graph.objects {
    if obj.shape_type != @graph.SqlTable {
      continue
    }
    guard obj.box is Some(table_box) else { continue }
    let row_height = table_box.height / (obj.children.length() + 1).to_double()
    for i, child in obj.children {
      child.box = Some(
        @graph.Box::new(
          table_box.x,
          table_box.y + row_height * (i.to_double() + 1.0),
          table_box.width,
          row_height,
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
