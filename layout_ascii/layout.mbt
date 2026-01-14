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
/// ASCII layout adapter.
///
/// Computes character-grid geometry (box placement, edge routes, legend layout)
/// from a laid-out `diagram.Diagram`. Rendering is handled separately.

///|
using @diagram {type Connection, type Diagram, type Shape}

///|
using @graph {
  type ArrowheadType,
  type LegendInput,
  type LegendPosition,
  type ShapeType,
}

///|
pub struct AsciiLayoutConfig {
  min_box_width : Int
  box_height : Int
  h_padding : Int
  v_spacing : Int
  h_spacing : Int
  min_width : Int
  min_height : Int
} derive(Show)

///|
pub fn AsciiLayoutConfig::new() -> AsciiLayoutConfig {
  {
    min_box_width: 6,
    box_height: 4,
    h_padding: 1,
    v_spacing: 4,
    h_spacing: 2,
    min_width: 40,
    min_height: 10,
  }
}

///|
pub fn AsciiLayoutConfig::from_parts(
  min_box_width : Int,
  box_height : Int,
  h_padding : Int,
  v_spacing : Int,
  h_spacing : Int,
  min_width : Int,
  min_height : Int,
) -> AsciiLayoutConfig {
  {
    min_box_width,
    box_height,
    h_padding,
    v_spacing,
    h_spacing,
    min_width,
    min_height,
  }
}

///|
/// ASCII box position and size in character coordinates.
///
/// `children` is used for structured shapes like sql_table.
pub struct AsciiBox {
  id : String
  x : Int
  y : Int
  width : Int
  height : Int
  label : String
  shape : String
  is_container : Bool
  children : Array[AsciiBox]
} derive(Show)

///|
pub struct GridPoint {
  x : Int
  y : Int
} derive(Show)

///|
pub enum ArrowDir {
  Up
  Down
  Left
  Right
} derive(Eq, Show)

///|
pub struct EdgePlan {
  index : Int
  ref_idx : Int
  points : Array[GridPoint]
  arrow : (GridPoint, ArrowDir)?
  label : String
  label_pos : GridPoint?
} derive(Show)

///|
pub struct LegendPlan {
  x : Int
  y : Int
  width : Int
  height : Int
  title : String?
  rows : Array[(Int, Int, String)]
  separators : Array[(Int, Int, Int)]
} derive(Show)

///|
pub struct AsciiPlan {
  canvas_width : Int
  canvas_height : Int
  boxes : Array[AsciiBox]
  edges : Array[EdgePlan]
  legend : (LegendInput, LegendPlan)?
} derive(Show)

///|
fn get_short_id(id : String) -> String {
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
fn is_container(obj : Shape) -> Bool {
  obj.shape_type != @graph.SqlTable && obj.child_ids.length() > 0
}

///|
fn object_children(obj : Shape, all_objects : Array[Shape]) -> Array[Shape] {
  let children : Array[Shape] = []
  for child_id in obj.child_ids {
    let mut found = false
    for candidate in all_objects {
      if not(found) && candidate.id == child_id {
        children.push(candidate)
        found = true
      }
    }
  }
  children
}

///|
fn max_i(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn sort_shapes_by_y(objects : Array[Shape]) -> Unit {
  let n = objects.length()
  for i = 1; i < n; i = i + 1 {
    let key = objects[i]
    let key_y = match key.box {
      Some(b) => b.y
      None => 0.0
    }
    let mut j = i - 1
    while j >= 0 {
      let j_y = match objects[j].box {
        Some(b) => b.y
        None => 0.0
      }
      if j_y > key_y {
        objects[j + 1] = objects[j]
        j = j - 1
      } else {
        break
      }
    }
    objects[j + 1] = key
  }
}

///|
fn sort_shapes_by_x(objects : Array[Shape]) -> Unit {
  let n = objects.length()
  for i = 1; i < n; i = i + 1 {
    let key = objects[i]
    let key_x = match key.box {
      Some(b) => b.x
      None => 0.0
    }
    let mut j = i - 1
    while j >= 0 {
      let j_x = match objects[j].box {
        Some(b) => b.x
        None => 0.0
      }
      if j_x > key_x {
        objects[j + 1] = objects[j]
        j = j - 1
      } else {
        break
      }
    }
    objects[j + 1] = key
  }
}

///|
fn group_by_layer(objects : Array[Shape]) -> Array[Array[Shape]] {
  let layers : Array[Array[Shape]] = []
  if objects.length() == 0 {
    return layers
  }
  let mut current_layer : Array[Shape] = []
  let mut current_y = match objects[0].box {
    Some(b) => b.y
    None => 0.0
  }
  for obj in objects {
    let obj_y = match obj.box {
      Some(b) => b.y
      None => 0.0
    }
    if (obj_y - current_y).abs() < 1.0 {
      current_layer.push(obj)
    } else {
      if current_layer.length() > 0 {
        layers.push(current_layer)
      }
      current_layer = [obj]
      current_y = obj_y
    }
  }
  if current_layer.length() > 0 {
    layers.push(current_layer)
  }
  layers
}

///|
fn compute_object_size(
  obj : Shape,
  all_objects : Array[Shape],
  config : AsciiLayoutConfig,
  sizes : Map[String, (Int, Int)],
) -> (Int, Int) {
  match sizes.get(obj.id) {
    Some(size) => return size
    None => ()
  }
  if obj.shape_type == @graph.SqlTable {
    let children = object_children(obj, all_objects)
    let header_height = 3
    let num_columns = children.length()
    let footer_height = 1
    let total_height = header_height + num_columns + footer_height
    let mut max_width = obj.label.length() + config.h_padding * 2 + 2
    for child in children {
      let col_name = get_short_id(child.id)
      let col_label = if child.label.length() > 0 {
        col_name + ": " + child.label
      } else {
        col_name
      }
      let col_width = col_label.length() + config.h_padding * 2 + 2
      max_width = max_i(max_width, col_width)
    }
    max_width = max_i(max_width, config.min_box_width)
    sizes[obj.id] = (max_width, total_height)
    return (max_width, total_height)
  }
  if is_container(obj) {
    let children = object_children(obj, all_objects)
    let title_height = 2
    let padding = 2
    let mut children_height = 0
    let mut max_child_width = 0
    for child in children {
      let (cw, ch) = compute_object_size(child, all_objects, config, sizes)
      max_child_width = max_i(max_child_width, cw)
      children_height = children_height + ch + 1
    }
    if children.length() > 0 {
      children_height = children_height - 1
    }
    let content_width = max_i(
      max_child_width + padding * 2,
      obj.label.length() + config.h_padding * 2 + 2,
    )
    let content_height = title_height + children_height + padding
    sizes[obj.id] = (content_width, content_height)
    (content_width, content_height)
  } else {
    let width = max_i(
      config.min_box_width,
      obj.label.length() + config.h_padding * 2 + 2,
    )
    let height = config.box_height
    sizes[obj.id] = (width, height)
    (width, height)
  }
}

///|
fn create_positioned_box(
  obj : Shape,
  all_objects : Array[Shape],
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  config : AsciiLayoutConfig,
  sizes : Map[String, (Int, Int)],
) -> AsciiBox {
  if obj.shape_type == @graph.SqlTable {
    let child_objects = object_children(obj, all_objects)
    let columns : Array[AsciiBox] = []
    for child in child_objects {
      let col_name = get_short_id(child.id)
      let col_label = if child.label.length() > 0 {
        col_name + ": " + child.label
      } else {
        col_name
      }
      columns.push({
        id: child.id,
        x: 0,
        y: 0,
        width: 0,
        height: 0,
        label: col_label,
        shape: "sql_column",
        is_container: false,
        children: [],
      })
    }
    return {
      id: obj.id,
      x,
      y,
      width,
      height,
      label: obj.label,
      shape: obj.shape_type.to_shape_string(),
      is_container: false,
      children: columns,
    }
  }
  if is_container(obj) {
    let child_objects = object_children(obj, all_objects)
    let children : Array[AsciiBox] = []
    let title_height = 2
    let mut child_y = y + title_height
    for child in child_objects {
      match sizes.get(child.id) {
        Some((cw, ch)) => {
          let child_x = x + (width - cw) / 2
          let child_box = create_positioned_box(
            child, all_objects, child_x, child_y, cw, ch, config, sizes,
          )
          children.push(child_box)
          child_y = child_y + ch + 1
        }
        None => ()
      }
    }
    {
      id: obj.id,
      x,
      y,
      width,
      height,
      label: obj.label,
      shape: "container",
      is_container: true,
      children,
    }
  } else {
    {
      id: obj.id,
      x,
      y,
      width,
      height,
      label: obj.label,
      shape: obj.shape_type.to_shape_string(),
      is_container: false,
      children: [],
    }
  }
}

///|
fn flatten_boxes(boxes : Array[AsciiBox]) -> Array[AsciiBox] {
  let result : Array[AsciiBox] = []
  for box in boxes {
    result.push(box)
    for child in box.children {
      flatten_children(child, result)
    }
  }
  result
}

///|
fn flatten_children(box : AsciiBox, result : Array[AsciiBox]) -> Unit {
  if box.shape == "sql_column" {
    return
  }
  result.push(box)
  for child in box.children {
    flatten_children(child, result)
  }
}

///|
fn compute_canvas_size(
  boxes : Array[AsciiBox],
  config : AsciiLayoutConfig,
) -> (Int, Int) {
  let mut max_x = config.min_width
  let mut max_y = config.min_height
  for box in boxes {
    let right = box.x + box.width + 2
    let bottom = box.y + box.height + 2
    if right > max_x {
      max_x = right
    }
    if bottom > max_y {
      max_y = bottom
    }
  }
  (max_x, max_y)
}

///|
fn legend_size(legend : LegendInput) -> (Int, Int) {
  let width = 30
  let height = 3 + legend.entries.length() * 2
  (width, height)
}

///|
fn legend_offsets(
  position : LegendPosition,
  width : Int,
  height : Int,
) -> (Int, Int) {
  let dx = if position == @graph.TopLeft || position == @graph.BottomLeft {
    width + 4
  } else {
    0
  }
  let dy = if position == @graph.TopLeft || position == @graph.TopRight {
    height + 3
  } else {
    0
  }
  (dx, dy)
}

///|
fn shift_boxes(boxes : Array[AsciiBox], dx : Int, dy : Int) -> Array[AsciiBox] {
  if dx == 0 && dy == 0 {
    return boxes
  }
  let shifted : Array[AsciiBox] = []
  for b in boxes {
    shifted.push(shift_box(b, dx, dy))
  }
  shifted
}

///|
fn shift_box(box : AsciiBox, dx : Int, dy : Int) -> AsciiBox {
  let shifted_children : Array[AsciiBox] = []
  for child in box.children {
    shifted_children.push(shift_box(child, dx, dy))
  }
  {
    id: box.id,
    x: box.x + dx,
    y: box.y + dy,
    width: box.width,
    height: box.height,
    label: box.label,
    shape: box.shape,
    is_container: box.is_container,
    children: shifted_children,
  }
}

///|
fn find_box(boxes : Array[AsciiBox], id : String) -> AsciiBox? {
  for box in boxes {
    if box.id == id || box.id.has_suffix("." + id) {
      return Some(box)
    }
  }
  for box in boxes {
    if box.label == id {
      return Some(box)
    }
  }
  None
}

///|
fn plan_edge(
  edge : Connection,
  ref_idx : Int,
  boxes : Array[AsciiBox],
) -> EdgePlan? {
  let src_box = find_box(boxes, edge.src_id)
  let dst_box = find_box(boxes, edge.dst_id)
  match (src_box, dst_box) {
    (Some(src), Some(dst)) => {
      let dst_cx = dst.x + dst.width / 2
      let src_top = src.y - 1
      let src_bottom = src.y + src.height
      let dst_top = dst.y - 1
      let dst_bottom = dst.y + dst.height

      // Simple multi-edge separation.
      let offset = ref_idx - edge.reference_count / 2
      let points : Array[GridPoint] = []
      let mut arrow : (GridPoint, ArrowDir)? = None
      if dst.y > src.y {
        // Downward
        let x = dst_cx + offset
        let start = { x, y: src_bottom }
        let end = { x, y: dst_top }
        points.push(start)
        points.push(end)
        arrow = Some(({ x, y: dst_top }, Down))
      } else if src.y > dst.y {
        // Upward
        let x = dst_cx + offset
        let start = { x, y: dst_bottom }
        let end = { x, y: src_top }
        points.push(start)
        points.push(end)
        arrow = Some(({ x, y: src_top }, Up))
      } else if dst.x > src.x {
        // Right
        let y = src.y + src.height / 2 + offset
        let start = { x: src.x + src.width, y }
        let end = { x: dst.x - 1, y }
        points.push(start)
        points.push(end)
        arrow = Some(({ x: dst.x - 1, y }, Right))
      } else {
        // Left
        let y = src.y + src.height / 2 + offset
        let start = { x: src.x - 1, y }
        let end = { x: dst.x + dst.width, y }
        points.push(start)
        points.push(end)
        arrow = Some(({ x: dst.x + dst.width, y }, Left))
      }
      let label_pos = if edge.label != "" {
        match points {
          [p0, p1] =>
            if p0.x == p1.x {
              // Vertical: place label to the right of the line.
              Some({ x: p0.x + 2, y: (p0.y + p1.y) / 2 })
            } else if p0.y == p1.y {
              // Horizontal: place label above the line.
              Some({
                x: (p0.x + p1.x) / 2 - edge.label.length() / 2,
                y: p0.y - 1,
              })
            } else {
              Some(p1)
            }
          _ => Some(points[0])
        }
      } else {
        None
      }
      Some({
        index: edge.index,
        ref_idx,
        points,
        arrow,
        label: edge.label,
        label_pos,
      })
    }
    _ => None
  }
}

///|
fn truncate_string(s : String, max_len : Int) -> String {
  if s.length() <= max_len {
    return s
  }
  let buf = StringBuilder::new()
  let chars = s.to_array()
  for i = 0; i < max_len - 3; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.write_string("...")
  buf.to_string()
}

///|
fn shape_to_icon(shape : ShapeType) -> String {
  match shape {
    @graph.Rectangle | @graph.Square => "[]"
    @graph.Circle | @graph.Oval => "()"
    @graph.Diamond => "<>"
    @graph.Cylinder => "||"
    @graph.Person => "/\\"
    @graph.Cloud => "(~)"
    @graph.Document => "[~]"
    _ => "[]"
  }
}

///|
fn connection_to_icon(src : ArrowheadType, dst : ArrowheadType) -> String {
  let start = src.to_ascii(true)
  let end = dst.to_ascii(false)
  start + "--" + end
}

///|
fn plan_legend(legend : LegendInput, x : Int, y : Int) -> LegendPlan {
  let width = 30
  let height = 3 + legend.entries.length() * 2
  let rows : Array[(Int, Int, String)] = []
  let separators : Array[(Int, Int, Int)] = []
  let mut current_y = y + 1
  let title = match legend.title {
    Some(t) => {
      let title_x = x + 2
      let display_title = truncate_string(t, width - 4)
      rows.push((title_x, current_y, display_title))
      current_y = current_y + 1
      separators.push((x + 1, x + width - 1, current_y))
      current_y = current_y + 1
      Some(t)
    }
    None => None
  }
  for entry in legend.entries {
    let entry_x = x + 2
    match entry {
      ShapeEntry(shape~, label~, ..) => {
        rows.push((entry_x, current_y, shape_to_icon(shape)))
        let label_x = entry_x + 4
        let display_label = truncate_string(label, width - 8)
        rows.push((label_x, current_y, display_label))
      }
      ConnectionEntry(src_arrow~, dst_arrow~, label~, ..) => {
        rows.push(
          (entry_x, current_y, connection_to_icon(src_arrow, dst_arrow)),
        )
        let label_x = entry_x + 4
        rows.push((label_x, current_y, truncate_string(label, width - 8)))
      }
      CustomEntry(icon~, label~) => {
        rows.push((entry_x, current_y, truncate_string(icon, 3)))
        let label_x = entry_x + 4
        rows.push((label_x, current_y, truncate_string(label, width - 8)))
      }
      Separator => separators.push((x + 1, x + width - 1, current_y))
    }
    current_y = current_y + 1
  }
  { x, y, width, height, title, rows, separators }
}

///|
/// Compute an ASCII layout plan from a laid-out diagram.
pub fn plan(diagram : Diagram, config : AsciiLayoutConfig) -> AsciiPlan {
  // Determine root objects (not children of another object).
  let child_ids : Map[String, Bool] = {}
  for obj in diagram.shapes {
    for child_id in obj.child_ids {
      child_ids[child_id] = true
    }
  }
  let roots : Array[Shape] = []
  for obj in diagram.shapes {
    if not(child_ids.contains(obj.id)) {
      roots.push(obj)
    }
  }
  sort_shapes_by_y(roots)
  let sizes : Map[String, (Int, Int)] = {}
  for obj in diagram.shapes {
    compute_object_size(obj, diagram.shapes, config, sizes) |> ignore
  }
  let layers = group_by_layer(roots)
  let mut max_layer_width = config.min_width
  for layer in layers {
    let mut layer_width = 0
    for obj in layer {
      match sizes.get(obj.id) {
        Some((w, _)) => layer_width = layer_width + w + config.h_spacing
        None => ()
      }
    }
    if layer_width > 0 {
      layer_width = layer_width - config.h_spacing
    }
    max_layer_width = max_i(max_layer_width, layer_width)
  }
  let boxes_tree : Array[AsciiBox] = []
  let mut current_y = 1
  for layer in layers {
    sort_shapes_by_x(layer)
    let mut layer_width = 0
    let mut max_height = 0
    for obj in layer {
      match sizes.get(obj.id) {
        Some((w, h)) => {
          layer_width = layer_width + w + config.h_spacing
          max_height = max_i(max_height, h)
        }
        None => ()
      }
    }
    if layer_width > 0 {
      layer_width = layer_width - config.h_spacing
    }
    let start_x = (max_layer_width - layer_width) / 2
    let mut x = start_x
    for obj in layer {
      match sizes.get(obj.id) {
        Some((w, h)) => {
          let b = create_positioned_box(
            obj,
            diagram.shapes,
            x,
            current_y,
            w,
            h,
            config,
            sizes,
          )
          boxes_tree.push(b)
          x = x + w + config.h_spacing
        }
        None => ()
      }
    }
    current_y = current_y + max_height + config.v_spacing
  }
  let base_boxes = flatten_boxes(boxes_tree)

  // Legend layout and diagram shifting.
  let (boxes, legend_info) = match diagram.legend {
    Some(legend) if !(legend.is_empty() || legend.position == @graph.Hidden) => {
      let (lw, lh) = legend_size(legend)
      let (dx, dy) = legend_offsets(legend.position, lw, lh)
      (shift_boxes(base_boxes, dx, dy), Some((legend, lw, lh)))
    }
    _ => (base_boxes, None)
  }
  let (diagram_width, diagram_height) = compute_canvas_size(boxes, config)
  let (canvas_width, canvas_height) = match legend_info {
    Some((legend, lw, lh)) => {
      let extra_w = if legend.position == @graph.TopRight ||
        legend.position == @graph.BottomRight {
        lw + 4
      } else {
        0
      }
      let extra_h = if legend.position == @graph.BottomLeft ||
        legend.position == @graph.BottomRight {
        lh + 3
      } else {
        0
      }
      (diagram_width + extra_w, diagram_height + extra_h)
    }
    None => (diagram_width, diagram_height)
  }
  let edges : Array[EdgePlan] = []
  for edge in diagram.connections {
    for ref_idx = 0; ref_idx < edge.reference_count; ref_idx = ref_idx + 1 {
      match plan_edge(edge, ref_idx, boxes) {
        Some(p) => edges.push(p)
        None => ()
      }
    }
  }
  let legend = match legend_info {
    Some((legend, _lw, _lh)) => {
      let x = match legend.position {
        @graph.TopLeft | @graph.BottomLeft => 1
        @graph.TopRight | @graph.BottomRight => diagram_width + 2
        @graph.Hidden => 1
      }
      let y = match legend.position {
        @graph.TopLeft | @graph.TopRight => 0
        @graph.BottomLeft | @graph.BottomRight => diagram_height + 1
        @graph.Hidden => 0
      }
      Some((legend, plan_legend(legend, x, y)))
    }
    None => None
  }
  { canvas_width, canvas_height, boxes, edges, legend }
}
