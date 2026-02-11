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
/// Engine API: layout contract shared between layout engines and exporters.
///
/// The layout pipeline is intentionally functional:
/// - engines take an immutable graph
/// - engines return a `@graph.LayoutPatch`
/// - callers apply the patch to obtain a new graph

///|
/// Layout configuration
pub struct LayoutConfig {
  /// Horizontal spacing between objects
  horizontal_spacing : Double
  /// Vertical spacing between objects
  vertical_spacing : Double
  /// Padding inside containers
  container_padding : Double
  /// Default object width
  default_width : Double
  /// Default object height
  default_height : Double
  /// Edge padding from objects
  edge_padding : Double
} derive(Show)

///|
/// Layout direction
pub(all) enum Direction {
  Down
  Right
  Up
  Left
} derive(Eq, Show)

///|
/// Layout error
pub(all) suberror LayoutError {
  InvalidGraph(String)
  CycleDetected(String)
  Unsupported(String)
} derive(Eq, Show)

///|
/// Construct an `engine_api.LayoutError` from outside this package.
pub fn invalid_graph(message : String) -> LayoutError {
  LayoutError::InvalidGraph(message)
}

///|
pub fn cycle_detected(message : String) -> LayoutError {
  LayoutError::CycleDetected(message)
}

///|
pub fn unsupported(message : String) -> LayoutError {
  LayoutError::Unsupported(message)
}

///|
pub fn LayoutConfig::new() -> LayoutConfig {
  {
    horizontal_spacing: 60.0,
    vertical_spacing: 100.0,
    container_padding: 50.0,
    default_width: 100.0,
    default_height: 60.0,
    edge_padding: 20.0,
  }
}

///|
pub fn LayoutConfig::with_spacing(
  horizontal : Double,
  vertical : Double,
) -> LayoutConfig {
  let config = LayoutConfig::new()
  { ..config, horizontal_spacing: horizontal, vertical_spacing: vertical }
}

///|
/// Layout engine interface.
///
/// Engines must not mutate their input graph. They return a patch that can be
/// applied by the caller.
pub(open) trait LayoutEngine {
  layout(Self, @graph.GraphInput, LayoutConfig, Direction) -> @graph.LayoutPatch raise LayoutError
}

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
fn get_parent_id(id : String) -> String? {
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
fn normalize_sequence_root(graph : @graph.GraphInput) -> @graph.GraphInput {
  if graph.root.shape_type != @graph.SequenceDiagram {
    return graph
  }
  let child_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    for child_id in obj.child_ids {
      child_ids[child_id] = true
    }
  }
  let root_child_ids : Array[String] = []
  for obj in graph.objects {
    if not(child_ids.contains(obj.id)) {
      root_child_ids.push(obj.id)
    }
  }
  let r = graph.root
  let root = @graph.ObjectInput::from_parts(
    r.id,
    r.label,
    r.shape_type,
    r.style,
    r.box,
    r.label_box,
    root_child_ids,
    r.z_index,
    r.icon,
    r.tooltip,
    r.link,
    r.classes,
    r.grid_rows,
    r.grid_columns,
    r.grid_gap,
    r.horizontal_gap,
    r.vertical_gap,
    r.grid_column_span,
    r.grid_row_span,
    r.near,
    r.top,
    r.left,
  )
  @graph.GraphInput::from_parts(
    graph.name,
    root,
    graph.objects,
    graph.edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
  )
}

///|
fn find_sql_column_index(
  object_by_id : Map[String, @graph.ObjectInput],
  field_id : String,
) -> Int? {
  let parent_id = match get_parent_id(field_id) {
    Some(p) => p
    None => return None
  }
  let parent = match object_by_id.get(parent_id) {
    Some(p) => p
    None => return None
  }
  if parent.shape_type != @graph.SqlTable {
    return None
  }
  let field_name = get_short_id(field_id)
  let mut i = 0
  for child_id in parent.child_ids {
    if get_short_id(child_id) == field_name {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn assign_sql_column_indices(graph : @graph.GraphInput) -> @graph.GraphInput {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.id] = graph.root
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  let edges : Array[@graph.EdgeInput] = []
  for e in graph.edges {
    let src_column_index = find_sql_column_index(object_by_id, e.src_id)
    let dst_column_index = find_sql_column_index(object_by_id, e.dst_id)
    edges.push(
      @graph.EdgeInput::from_parts(
        e.index,
        e.src_id,
        e.dst_id,
        e.src_arrow,
        e.dst_arrow,
        e.src_arrowhead,
        e.dst_arrowhead,
        e.src_anchor,
        e.dst_anchor,
        e.label,
        e.style,
        e.route,
        e.bend_points,
        e.is_curve,
        e.z_index,
        e.reference_count,
        e.label_box,
        src_column_index,
        dst_column_index,
      ),
    )
  }
  @graph.GraphInput::from_parts(
    graph.name,
    graph.root,
    graph.objects,
    edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
  )
}

///|
fn prepare_graph_for_layout(graph : @graph.GraphInput) -> @graph.GraphInput {
  let graph = normalize_sequence_root(graph)
  assign_sql_column_indices(graph)
}

///|
fn ensure_orthogonal_route(route : Array[@graph.Point]) -> Array[@graph.Point] {
  if route.length() != 2 {
    return route
  }
  let p0 = route[0]
  let p1 = route[1]
  let dx = (p1.x - p0.x).abs()
  let dy = (p1.y - p0.y).abs()
  if dx < 1.0 || dy < 1.0 {
    return route
  }
  [p0, @graph.Point::new(p0.x, p1.y), p1]
}

///|
fn normalize_routes(graph : @graph.GraphInput) -> @graph.GraphInput {
  let edges : Array[@graph.EdgeInput] = []
  for e in graph.edges {
    let route = if edge_prefers_curved(e) {
      e.route
    } else {
      ensure_orthogonal_route(e.route)
    }
    edges.push(
      @graph.EdgeInput::from_parts(
        e.index,
        e.src_id,
        e.dst_id,
        e.src_arrow,
        e.dst_arrow,
        e.src_arrowhead,
        e.dst_arrowhead,
        e.src_anchor,
        e.dst_anchor,
        e.label,
        e.style,
        route,
        e.bend_points,
        e.is_curve,
        e.z_index,
        e.reference_count,
        e.label_box,
        e.src_column_index,
        e.dst_column_index,
      ),
    )
  }
  @graph.GraphInput::from_parts(
    graph.name,
    graph.root,
    graph.objects,
    edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
  )
}

///|
fn edge_prefers_curved(edge : @graph.EdgeInput) -> Bool {
  match edge.style.curved {
    Some(v) => v.as_bool().unwrap_or(true)
    None => true
  }
}

///|
priv struct GridSemanticPlan {
  rows : Int
  cols : Int
  column_widths : Array[Double]
  row_heights : Array[Double]
  hgap : Double
  vgap : Double
  pad_x : Double
  pad_top : Double
  width : Double
  height : Double
}

///|
priv struct GridSemanticContext {
  groups : Map[String, Array[String]]
  child_ids : Map[String, Bool]
}

///|
fn prepare_layout_semantics(
  graph : @graph.GraphInput,
) -> (@graph.GraphInput, GridSemanticContext) {
  let groups = collect_grid_semantic_groups(graph)
  if groups.is_empty() {
    return (graph, { groups, child_ids: {} })
  }
  let child_ids : Map[String, Bool] = {}
  for _, ids in groups {
    for id in ids {
      child_ids[id] = true
    }
  }
  (detach_grid_children(graph, groups), { groups, child_ids })
}

///|
fn restore_layout_semantics(
  original_graph : @graph.GraphInput,
  laid_out_graph : @graph.GraphInput,
  context : GridSemanticContext,
  config : LayoutConfig,
) -> @graph.GraphInput {
  if context.groups.is_empty() {
    laid_out_graph
  } else {
    restore_grid_semantics(original_graph, laid_out_graph, context, config)
  }
}

///|
fn collect_grid_semantic_groups(
  graph : @graph.GraphInput,
) -> Map[String, Array[String]] {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  let incident_ids : Map[String, Bool] = {}
  for edge in graph.edges {
    incident_ids[edge.src_id] = true
    incident_ids[edge.dst_id] = true
  }
  let groups : Map[String, Array[String]] = {}
  for parent in graph.objects {
    if parent.grid_rows is None && parent.grid_columns is None {
      continue
    }
    let child_ids : Array[String] = []
    let mut blocked = false
    for child_id in parent.child_ids {
      guard object_by_id.contains(child_id) else { continue }
      if incident_ids.contains(child_id) {
        blocked = true
        break
      }
      child_ids.push(child_id)
    }
    if blocked || child_ids.is_empty() {
      continue
    }
    groups[parent.id] = child_ids
  }
  groups
}

///|
fn detach_grid_children(
  graph : @graph.GraphInput,
  groups : Map[String, Array[String]],
) -> @graph.GraphInput {
  let group_child_ids : Map[String, Bool] = {}
  for _, child_ids in groups {
    for child_id in child_ids {
      group_child_ids[child_id] = true
    }
  }
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if group_child_ids.contains(obj.id) {
      continue
    }
    let child_ids = match groups.get(obj.id) {
      Some(filtered) => {
        let removed : Map[String, Bool] = {}
        for id in filtered {
          removed[id] = true
        }
        let kept : Array[String] = []
        for id in obj.child_ids {
          if !removed.contains(id) {
            kept.push(id)
          }
        }
        kept
      }
      None => obj.child_ids
    }
    objects.push(clone_object_with_parts(obj, obj.box, child_ids))
  }
  @graph.GraphInput::from_parts(
    graph.name,
    graph.root,
    objects,
    graph.edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
  )
}

///|
fn estimate_grid_semantic_plan(
  parent : @graph.ObjectInput,
  child_ids : Array[String],
  child_size_by_id : Map[String, (Double, Double)],
) -> GridSemanticPlan? {
  if child_ids.is_empty() {
    return None
  }
  let n = child_ids.length()
  let rows = match parent.grid_rows {
    Some(v) => if v > 0 { v } else { 0 }
    None => 0
  }
  let cols = match parent.grid_columns {
    Some(v) => if v > 0 { v } else { 0 }
    None => 0
  }
  let (rows, cols) = if rows > 0 && cols > 0 {
    (rows, cols)
  } else if rows > 0 {
    (rows, ceil_div(n, rows))
  } else if cols > 0 {
    (ceil_div(n, cols), cols)
  } else {
    return None
  }
  if rows <= 0 || cols <= 0 {
    return None
  }

  let column_widths : Array[Double] = []
  for _ in 0..<cols {
    column_widths.push(0.0)
  }
  let row_heights : Array[Double] = []
  for _ in 0..<rows {
    row_heights.push(0.0)
  }
  let limit = min_int(n, rows * cols)
  for i in 0..<limit {
    let (child_w, child_h) = match child_size_by_id.get(child_ids[i]) {
      Some(v) => v
      None => continue
    }
    let row = i / cols
    let col = i % cols
    if child_w > column_widths[col] {
      column_widths[col] = child_w
    }
    if child_h > row_heights[row] {
      row_heights[row] = child_h
    }
  }

  let (hgap, vgap) = grid_semantic_gaps(parent)
  let (pad_x, pad_top, pad_bottom) = grid_semantic_paddings(parent, hgap, vgap)
  let width = sum_double(column_widths) +
    hgap * (cols - 1).to_double() +
    pad_x * 2.0
  let height = sum_double(row_heights) +
    vgap * (rows - 1).to_double() +
    pad_top +
    pad_bottom
  Some({
    rows,
    cols,
    column_widths,
    row_heights,
    hgap,
    vgap,
    pad_x,
    pad_top,
    width,
    height,
  })
}

///|
fn grid_semantic_gaps(parent : @graph.ObjectInput) -> (Double, Double) {
  let fallback = match parent.grid_gap {
    Some(v) => positive_or(v, 10.0)
    None => 40.0
  }
  let hgap = match parent.horizontal_gap {
    Some(v) => positive_or(v, fallback)
    None => fallback
  }
  let vgap = match parent.vertical_gap {
    Some(v) => positive_or(v, fallback)
    None => fallback
  }
  (hgap, vgap)
}

///|
fn grid_semantic_paddings(
  parent : @graph.ObjectInput,
  hgap : Double,
  vgap : Double,
) -> (Double, Double, Double) {
  match parent.grid_gap {
    Some(v) => {
      let pad = positive_or(v, 10.0)
      (pad, pad + 36.0, pad)
    }
    None => {
      let pad = max_double(60.0, max_double(hgap, vgap))
      (pad, pad, pad)
    }
  }
}

///|
fn restore_grid_semantics(
  original_graph : @graph.GraphInput,
  laid_out_graph : @graph.GraphInput,
  context : GridSemanticContext,
  config : LayoutConfig,
) -> @graph.GraphInput {
  let original_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in original_graph.objects {
    original_by_id[obj.id] = obj
  }
  let laid_out_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in laid_out_graph.objects {
    laid_out_by_id[obj.id] = obj
  }

  let override_boxes : Map[String, @graph.Box] = {}
  for parent_id, child_ids in context.groups {
    let parent = match laid_out_by_id.get(parent_id) {
      Some(v) => v
      None => continue
    }
    let parent_box = match parent.box {
      Some(v) => v
      None => continue
    }
    let child_size_by_id : Map[String, (Double, Double)] = {}
    for child_id in child_ids {
      let child = match original_by_id.get(child_id) {
        Some(v) => v
        None => continue
      }
      child_size_by_id[child_id] = semantic_object_size(child, config)
    }
    let plan = match
      estimate_grid_semantic_plan(parent, child_ids, child_size_by_id) {
      Some(v) => v
      None => continue
    }

    let center_x = parent_box.x + parent_box.width / 2.0
    let center_y = parent_box.y + parent_box.height / 2.0
    let parent_new = @graph.Box::new(
      center_x - plan.width / 2.0,
      center_y - plan.height / 2.0,
      plan.width,
      plan.height,
    )
    override_boxes[parent_id] = parent_new

    let mut y = parent_new.y + plan.pad_top
    for row in 0..<plan.rows {
      let mut x = parent_new.x + plan.pad_x
      for col in 0..<plan.cols {
        let idx = row * plan.cols + col
        if idx >= child_ids.length() {
          break
        }
        let child_id = child_ids[idx]
        let (child_w, child_h) = match child_size_by_id.get(child_id) {
          Some(v) => v
          None => continue
        }
        let cell_w = plan.column_widths[col]
        let cell_h = plan.row_heights[row]
        override_boxes[child_id] = @graph.Box::new(
          x + (cell_w - child_w) / 2.0,
          y + (cell_h - child_h) / 2.0,
          child_w,
          child_h,
        )
        x = x + cell_w + plan.hgap
      }
      y = y + plan.row_heights[row] + plan.vgap
    }
  }
  pack_top_level_grid_groups(override_boxes, context, original_graph)
  normalize_override_boxes_origin(override_boxes)

  let objects : Array[@graph.ObjectInput] = []
  for obj in original_graph.objects {
    if context.child_ids.contains(obj.id) {
      let box = match override_boxes.get(obj.id) {
        Some(v) => Some(v)
        None => obj.box
      }
      objects.push(clone_object_with_parts(obj, box, obj.child_ids))
      continue
    }
    let laid_out_obj = match laid_out_by_id.get(obj.id) {
      Some(v) => v
      None => obj
    }
    let box = match override_boxes.get(obj.id) {
      Some(v) => Some(v)
      None => laid_out_obj.box
    }
    let child_ids = if context.groups.contains(obj.id) {
      obj.child_ids
    } else {
      laid_out_obj.child_ids
    }
    objects.push(clone_object_with_parts(laid_out_obj, box, child_ids))
  }

  @graph.GraphInput::from_parts(
    laid_out_graph.name,
    laid_out_graph.root,
    objects,
    laid_out_graph.edges,
    laid_out_graph.sequence_fragments,
    laid_out_graph.activation_boxes,
    laid_out_graph.sequence_notes,
    laid_out_graph.sequence_fragments_layout,
    laid_out_graph.layers,
    laid_out_graph.scenarios,
    laid_out_graph.steps,
    laid_out_graph.legend,
  )
}

///|
fn pack_top_level_grid_groups(
  override_boxes : Map[String, @graph.Box],
  context : GridSemanticContext,
  original_graph : @graph.GraphInput,
) -> Unit {
  let top_parents : Array[String] = []
  for obj in original_graph.objects {
    if context.groups.contains(obj.id) && !obj.id.contains(".") {
      top_parents.push(obj.id)
    }
  }
  if top_parents.is_empty() {
    return
  }
  let gap = 60.0
  let mut cursor_x = 0.0
  for parent_id in top_parents {
    let parent_box = match override_boxes.get(parent_id) {
      Some(v) => v
      None => continue
    }
    let dx = cursor_x - parent_box.x
    let shifted_parent = @graph.Box::new(
      parent_box.x + dx,
      parent_box.y,
      parent_box.width,
      parent_box.height,
    )
    override_boxes[parent_id] = shifted_parent
    match context.groups.get(parent_id) {
      Some(child_ids) =>
        for child_id in child_ids {
          match override_boxes.get(child_id) {
            Some(child_box) =>
              override_boxes[child_id] = @graph.Box::new(
                child_box.x + dx,
                child_box.y,
                child_box.width,
                child_box.height,
              )
            None => ()
          }
        }
      None => ()
    }
    cursor_x = cursor_x + shifted_parent.width + gap
  }
}

///|
fn normalize_override_boxes_origin(
  override_boxes : Map[String, @graph.Box],
) -> Unit {
  if override_boxes.is_empty() {
    return
  }
  let mut min_x = 1000000000.0
  let mut min_y = 1000000000.0
  for _, box in override_boxes {
    if box.x < min_x {
      min_x = box.x
    }
    if box.y < min_y {
      min_y = box.y
    }
  }
  let shift_x = if min_x < 0.0 { -min_x } else { 0.0 }
  let shift_y = if min_y < 0.0 { -min_y } else { 0.0 }
  if shift_x == 0.0 && shift_y == 0.0 {
    return
  }
  let ids : Array[String] = []
  for id, _ in override_boxes {
    ids.push(id)
  }
  for id in ids {
    if override_boxes.get(id) is Some(box) {
      override_boxes[id] = @graph.Box::new(
        box.x + shift_x,
        box.y + shift_y,
        box.width,
        box.height,
      )
    }
  }
}

///|
fn clone_object_with_parts(
  obj : @graph.ObjectInput,
  box : @graph.Box?,
  child_ids : Array[String],
) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    obj.id,
    obj.label,
    obj.shape_type,
    obj.style,
    box,
    obj.label_box,
    child_ids,
    obj.z_index,
    obj.icon,
    obj.tooltip,
    obj.link,
    obj.classes,
    obj.grid_rows,
    obj.grid_columns,
    obj.grid_gap,
    obj.horizontal_gap,
    obj.vertical_gap,
    obj.grid_column_span,
    obj.grid_row_span,
    obj.near,
    obj.top,
    obj.left,
  )
}

///|
fn semantic_object_size(
  obj : @graph.ObjectInput,
  config : LayoutConfig,
) -> (Double, Double) {
  match obj.box {
    Some(box) =>
      (
        positive_or(box.width, config.default_width),
        positive_or(box.height, config.default_height),
      )
    None => estimate_semantic_object_size(obj, config)
  }
}

///|
fn estimate_semantic_object_size(
  obj : @graph.ObjectInput,
  config : LayoutConfig,
) -> (Double, Double) {
  let font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(obj.style.bold, false)
  let is_italic = style_bool(obj.style.italic, false)
  let is_mono = obj.shape_type == @graph.Code ||
    style_is_mono(obj.style.font_family)
  let label_dims = @text_metrics.measure_label(
    obj.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  let mut content_width = label_dims.width
  let mut content_height = label_dims.height

  if obj.shape_type == @graph.Code {
    content_width = content_width + font_size.to_double()
    content_height = content_height + font_size.to_double()
  } else if obj.label != "" && obj.shape_type != @graph.Text {
    content_width = content_width + D2_INNER_LABEL_PADDING
    content_height = content_height + D2_INNER_LABEL_PADDING
  }

  if obj.shape_type == @graph.Text {
    if content_width < D2_MIN_SHAPE_SIZE {
      content_width = D2_MIN_SHAPE_SIZE
    }
    if content_height < D2_MIN_SHAPE_SIZE {
      content_height = D2_MIN_SHAPE_SIZE
    }
    return (content_width, content_height)
  }

  if obj.shape_type == @graph.Image {
    return (128.0, 128.0)
  }

  let base_padding = semantic_shape_default_padding(obj.shape_type)
  let mut padding_x = base_padding.0
  let mut padding_y = base_padding.1
  if obj.icon is Some(_) &&
    obj.shape_type != @graph.SqlTable &&
    obj.shape_type != @graph.Class &&
    obj.shape_type != @graph.Code &&
    obj.shape_type != @graph.Text {
    let label_height = label_dims.height + D2_INNER_LABEL_PADDING
    padding_x = padding_x + label_height
    padding_y = padding_y + label_height
  }

  let fitted = semantic_shape_dimensions_to_fit(
    obj.shape_type,
    content_width,
    content_height,
    padding_x,
    padding_y,
  )
  let mut width = fitted.0
  let mut height = fitted.1

  if obj.shape_type == @graph.Circle || obj.shape_type == @graph.Square {
    let side = if width > height { width } else { height }
    width = side
    height = side
  } else if obj.shape_type == @graph.Person {
    let fit = limit_ar(width, height, D2_PERSON_AR_LIMIT)
    width = fit.0
    height = fit.1
  } else if obj.shape_type == @graph.Oval {
    let fit = limit_ar(width, height, D2_OVAL_AR_LIMIT)
    width = fit.0
    height = fit.1
  } else if obj.shape_type == @graph.C4Person {
    let fit = limit_ar(width, height, D2_C4_PERSON_AR_LIMIT)
    width = fit.0
    height = fit.1
  }

  (
    if width > 0.0 {
      width
    } else {
      positive_or(config.default_width, 1.0)
    },
    if height > 0.0 {
      height
    } else {
      positive_or(config.default_height, 1.0)
    },
  )
}

///|
const D2_DEFAULT_PADDING : Double = 40.0

///|
const D2_DEFAULT_ARC_DEPTH : Double = 24.0

///|
const D2_PARALLELOGRAM_WEDGE_WIDTH : Double = 26.0

///|
const D2_STORED_DATA_WEDGE_WIDTH : Double = 15.0

///|
const D2_STEP_WEDGE_WIDTH : Double = 35.0

///|
const D2_PACKAGE_TOP_MAX_HEIGHT : Double = 55.0

///|
const D2_PACKAGE_VERTICAL_SCALAR : Double = 0.2

///|
const D2_CALLOUT_DEFAULT_TIP_HEIGHT : Double = 45.0

///|
const D2_PAGE_CORNER_WIDTH : Double = 20.8164

///|
const D2_PAGE_CORNER_HEIGHT : Double = 20.348

///|
const D2_DOC_PATH_HEIGHT : Double = 18.925

///|
const D2_DOC_PATH_INNER_BOTTOM : Double = 14.0

///|
const D2_INNER_LABEL_PADDING : Double = 5.0

///|
const D2_MIN_SHAPE_SIZE : Double = 5.0

///|
const D2_PERSON_AR_LIMIT : Double = 1.5

///|
const D2_OVAL_AR_LIMIT : Double = 3.0

///|
const D2_C4_PERSON_AR_LIMIT : Double = 1.5

///|
const D2_C4_HEAD_RADIUS_FACTOR : Double = 0.22

///|
const D2_C4_BODY_TOP_FACTOR : Double = 0.8

///|
const CLOUD_WIDE_INNER_WIDTH : Double = 0.819

///|
const CLOUD_WIDE_INNER_HEIGHT : Double = 0.548

///|
const CLOUD_WIDE_ASPECT_BOUNDARY : Double = (1.0 + D2_DEFAULT_PADDING) /
  D2_DEFAULT_PADDING

///|
const CLOUD_TALL_INNER_WIDTH : Double = 0.549

///|
const CLOUD_TALL_INNER_HEIGHT : Double = 0.820

///|
const CLOUD_TALL_ASPECT_BOUNDARY : Double = D2_DEFAULT_PADDING /
  (1.0 + D2_DEFAULT_PADDING)

///|
const CLOUD_SQUARE_INNER_WIDTH : Double = 0.663

///|
const CLOUD_SQUARE_INNER_HEIGHT : Double = 0.663

///|
fn semantic_shape_default_padding(
  shape_type : @graph.ShapeType,
) -> (Double, Double) {
  match shape_type {
    @graph.Circle => {
      let p = D2_DEFAULT_PADDING / 2.0.sqrt()
      (p, p)
    }
    @graph.Diamond => (D2_DEFAULT_PADDING / 4.0, D2_DEFAULT_PADDING / 2.0)
    @graph.Hexagon => (D2_DEFAULT_PADDING / 2.0, D2_DEFAULT_PADDING / 2.0)
    @graph.Cylinder => (D2_DEFAULT_PADDING, D2_DEFAULT_PADDING / 2.0)
    @graph.Queue => (D2_DEFAULT_PADDING / 2.0, D2_DEFAULT_PADDING)
    @graph.StoredData => (D2_DEFAULT_PADDING - 10.0, D2_DEFAULT_PADDING)
    @graph.Person => (10.0, D2_DEFAULT_PADDING)
    @graph.C4Person => (10.0, D2_DEFAULT_PADDING)
    @graph.Page =>
      (D2_DEFAULT_PADDING, D2_PAGE_CORNER_HEIGHT + D2_DEFAULT_PADDING)
    @graph.Document =>
      (
        D2_DEFAULT_PADDING,
        D2_DEFAULT_PADDING * D2_DOC_PATH_INNER_BOTTOM / D2_DOC_PATH_HEIGHT,
      )
    @graph.Package => (D2_DEFAULT_PADDING, 0.8 * D2_DEFAULT_PADDING)
    @graph.Step =>
      (D2_DEFAULT_PADDING / 4.0, D2_DEFAULT_PADDING + D2_STEP_WEDGE_WIDTH)
    @graph.Callout => (D2_DEFAULT_PADDING, D2_DEFAULT_PADDING / 2.0)
    @graph.Cloud => (D2_DEFAULT_PADDING, D2_DEFAULT_PADDING / 2.0)
    _ => (D2_DEFAULT_PADDING, D2_DEFAULT_PADDING)
  }
}

///|
fn semantic_shape_dimensions_to_fit(
  shape_type : @graph.ShapeType,
  width : Double,
  height : Double,
  padding_x : Double,
  padding_y : Double,
) -> (Double, Double) {
  match shape_type {
    @graph.Circle => {
      let length = if width + padding_x > height + padding_y {
        width + padding_x
      } else {
        height + padding_y
      }
      let diameter = (2.0.sqrt() * length).ceil()
      (diameter, diameter)
    }
    @graph.Oval => {
      let theta = @math.atan2(height, width)
      let padded_width = width + padding_x * @math.cos(theta)
      let padded_height = height + padding_y * @math.sin(theta)
      let mut total_width = (2.0.sqrt() * padded_width).ceil()
      let mut total_height = (2.0.sqrt() * padded_height).ceil()
      let fit = limit_ar(total_width, total_height, D2_OVAL_AR_LIMIT)
      total_width = fit.0
      total_height = fit.1
      (total_width, total_height)
    }
    @graph.Diamond =>
      ((2.0 * (width + padding_x)).ceil(), (2.0 * (height + padding_y)).ceil())
    @graph.Hexagon =>
      ((1.5 * (width + padding_x)).ceil(), (1.5 * (height + padding_y)).ceil())
    @graph.Parallelogram =>
      (
        (width + padding_x + D2_PARALLELOGRAM_WEDGE_WIDTH * 2.0).ceil(),
        (height + padding_y).ceil(),
      )
    @graph.Cylinder =>
      (
        (width + padding_x).ceil(),
        (height + padding_y + 3.0 * D2_DEFAULT_ARC_DEPTH).ceil(),
      )
    @graph.Queue =>
      (
        (width + padding_x + 3.0 * D2_DEFAULT_ARC_DEPTH).ceil(),
        (height + padding_y).ceil(),
      )
    @graph.StoredData =>
      (
        (width + padding_x + 2.0 * D2_STORED_DATA_WEDGE_WIDTH).ceil(),
        (height + padding_y).ceil(),
      )
    @graph.Person => {
      let mut total_width = width + padding_x
      let mut total_height = height + padding_y
      let fit = limit_ar(total_width, total_height, D2_PERSON_AR_LIMIT)
      total_width = fit.0
      total_height = fit.1
      (total_width.ceil(), total_height.ceil())
    }
    @graph.C4Person => {
      let content_width = width + padding_x
      let content_height = height + padding_y
      let mut total_width = content_width / 0.9
      let head_radius = total_width * D2_C4_HEAD_RADIUS_FACTOR
      let body_top = head_radius + head_radius * D2_C4_BODY_TOP_FACTOR
      let vertical_padding = total_width * 0.06
      let mut total_height = content_height + body_top + vertical_padding
      let min_height = total_width * 0.95
      if total_height < min_height {
        total_height = min_height
      }
      let fit = limit_ar(total_width, total_height, D2_C4_PERSON_AR_LIMIT)
      total_width = fit.0
      total_height = fit.1
      (total_width.ceil(), total_height.ceil())
    }
    @graph.Cloud => {
      let total_width = width + padding_x
      let total_height = height + padding_y
      let aspect_ratio = total_width / total_height
      if aspect_ratio > CLOUD_WIDE_ASPECT_BOUNDARY {
        (
          (total_width / CLOUD_WIDE_INNER_WIDTH).ceil(),
          (total_height / CLOUD_WIDE_INNER_HEIGHT).ceil(),
        )
      } else if aspect_ratio < CLOUD_TALL_ASPECT_BOUNDARY {
        (
          (total_width / CLOUD_TALL_INNER_WIDTH).ceil(),
          (total_height / CLOUD_TALL_INNER_HEIGHT).ceil(),
        )
      } else {
        (
          (total_width / CLOUD_SQUARE_INNER_WIDTH).ceil(),
          (total_height / CLOUD_SQUARE_INNER_HEIGHT).ceil(),
        )
      }
    }
    @graph.Page => {
      let mut total_width = width + padding_x
      let mut total_height = height + padding_y
      if total_height < 3.0 * D2_PAGE_CORNER_HEIGHT {
        total_width = total_width + D2_PAGE_CORNER_WIDTH
      }
      if total_width < 2.0 * D2_PAGE_CORNER_WIDTH {
        total_width = 2.0 * D2_PAGE_CORNER_WIDTH
      }
      if total_height < D2_PAGE_CORNER_HEIGHT {
        total_height = D2_PAGE_CORNER_HEIGHT
      }
      (total_width.ceil(), total_height.ceil())
    }
    @graph.Document =>
      (
        (width + padding_x).ceil(),
        ((height + padding_y) * D2_DOC_PATH_HEIGHT / D2_DOC_PATH_INNER_BOTTOM).ceil(),
      )
    @graph.Package => {
      let inner_height = height + padding_y
      let top_height = inner_height *
        D2_PACKAGE_VERTICAL_SCALAR /
        (1.0 - D2_PACKAGE_VERTICAL_SCALAR)
      let total_height = inner_height +
        (if top_height < D2_PACKAGE_TOP_MAX_HEIGHT {
          top_height
        } else {
          D2_PACKAGE_TOP_MAX_HEIGHT
        })
      ((width + padding_x).ceil(), total_height.ceil())
    }
    @graph.Step =>
      (
        (width + padding_x + 2.0 * D2_STEP_WEDGE_WIDTH).ceil(),
        (height + padding_y).ceil(),
      )
    @graph.Callout => {
      let mut total_height = height + padding_y
      if total_height < D2_CALLOUT_DEFAULT_TIP_HEIGHT {
        total_height = total_height * 2.0
      } else {
        total_height = total_height + D2_CALLOUT_DEFAULT_TIP_HEIGHT
      }
      ((width + padding_x).ceil(), total_height.ceil())
    }
    _ => ((width + padding_x).ceil(), (height + padding_y).ceil())
  }
}

///|
fn limit_ar(
  width : Double,
  height : Double,
  aspect_ratio : Double,
) -> (Double, Double) {
  let mut w = width
  let mut h = height
  if w <= 0.0 && h <= 0.0 {
    return (1.0, 1.0)
  }
  if w <= 0.0 {
    w = h / aspect_ratio
  }
  if h <= 0.0 {
    h = w / aspect_ratio
  }
  if h > 0.0 && w / h > aspect_ratio {
    h = w / aspect_ratio
  } else if w > 0.0 && h / w > aspect_ratio {
    w = h / aspect_ratio
  }
  (w, h)
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
fn positive_or(value : Double, fallback : Double) -> Double {
  if value > 0.0 {
    value
  } else {
    fallback
  }
}

///|
fn ceil_div(n : Int, d : Int) -> Int {
  if n <= 0 || d <= 0 {
    0
  } else {
    (n + d - 1) / d
  }
}

///|
fn sum_double(values : Array[Double]) -> Double {
  let mut sum = 0.0
  for v in values {
    sum = sum + v
  }
  sum
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
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
/// Perform layout on a graph (including variants) with a specific engine.
///
/// Returns a new graph with layout applied.
pub fn[Engine : LayoutEngine] layout_with_engine(
  engine : Engine,
  graph : @graph.GraphInput,
  config : LayoutConfig,
  direction : Direction,
) -> @graph.GraphInput raise LayoutError {
  let prepared = prepare_graph_for_layout(graph)
  let (engine_graph, semantic_ctx) = prepare_layout_semantics(prepared)
  let laid_out_core = if engine_graph.objects.is_empty() {
    engine_graph
  } else {
    let patch = engine.layout(engine_graph, config, direction)
    @graph.apply_layout(engine_graph, patch)
  }
  let laid_out = restore_layout_semantics(
    prepared, laid_out_core, semantic_ctx, config,
  )
  let layers : Array[@graph.LayerInput] = []
  for layer in laid_out.layers {
    layers.push(
      @graph.LayerInput::new(
        layer.name,
        layout_with_engine(engine, layer.graph, config, direction),
      ),
    )
  }
  let scenarios : Array[@graph.ScenarioInput] = []
  for scenario in laid_out.scenarios {
    scenarios.push(
      @graph.ScenarioInput::new(
        scenario.name,
        layout_with_engine(engine, scenario.graph, config, direction),
      ),
    )
  }
  let steps : Array[@graph.StepInput] = []
  for step in laid_out.steps {
    steps.push(
      @graph.StepInput::new(
        step.name,
        layout_with_engine(engine, step.graph, config, direction),
      ),
    )
  }
  normalize_routes(
    @graph.GraphInput::from_parts(
      laid_out.name,
      laid_out.root,
      laid_out.objects,
      laid_out.edges,
      laid_out.sequence_fragments,
      laid_out.activation_boxes,
      laid_out.sequence_notes,
      laid_out.sequence_fragments_layout,
      layers,
      scenarios,
      steps,
      laid_out.legend,
    ),
  )
}
