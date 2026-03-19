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
/// ELK engine implementation backed by `Milky2018/moon_elk`.
///
/// The adapter follows the same bridge architecture as `engine_dagre`:
/// 1. convert `@graph.GraphInput` to ELK JSON
/// 2. invoke ELK layout
/// 3. convert ELK JSON to `@graph.LayoutPatch`

///|
pub struct ElkEngine {
  _marker : Unit
} derive(Show)

///|
pub fn ElkEngine::new() -> ElkEngine {
  { _marker: () }
}

///|
pub fn debug_build_elk_input_json(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> Json {
  let (elk_graph, _, _, _, _) = build_elk_graph(graph, config, direction)
  elk_graph
}

///|
const D2_INNER_LABEL_PADDING : Double = 5.0

///|
const D2_LABEL_PADDING : Double = 5.0

///|
const D2_SEQUENCE_HORIZONTAL_PAD : Double = 40.0

///|
const D2_SEQUENCE_LABEL_HORIZONTAL_PAD : Double = 60.0

///|
const D2_SEQUENCE_VERTICAL_PAD : Double = 40.0

///|
const D2_SEQUENCE_MIN_ACTOR_DISTANCE : Double = 150.0

///|
const D2_SEQUENCE_MIN_ACTOR_WIDTH : Double = 100.0

///|
const D2_SEQUENCE_MIN_ACTOR_HEIGHT : Double = 66.0

///|
const D2_SEQUENCE_SELF_MESSAGE_HORIZONTAL_TRAVEL : Double = 80.0

///|
const D2_SEQUENCE_GROUP_CONTAINER_PADDING : Double = 12.0

///|
const D2_SEQUENCE_MIN_MESSAGE_DISTANCE : Double = 30.0

///|
const D2_SEQUENCE_SPAN_BASE_WIDTH : Double = 12.0

///|
const D2_SEQUENCE_SPAN_DEPTH_GROWTH : Double = 8.0

///|
const D2_SEQUENCE_MIN_SPAN_HEIGHT : Double = 30.0

///|
const D2_SEQUENCE_SPAN_MESSAGE_PAD : Double = 10.0

///|
const D2_MAX_ICON_SIZE : Double = 64.0

///|
const D2_THREE_DEE_OFFSET : Double = 15.0

///|
const D2_MULTIPLE_OFFSET : Double = 10.0

///|
const D2_MIN_SHAPE_SIZE : Double = 5.0

///|
const D2_DEFAULT_PADDING : Double = 40.0

///|
const D2_PORT_SPACING : Double = 40.0

///|
const D2_NEAR_PAD : Double = 20.0

///|
const D2_SQL_TABLE_NAME_PADDING : Double = 10.0

///|
const D2_SQL_TABLE_TYPE_PADDING : Double = 20.0

///|
const D2_SQL_TABLE_CONSTRAINT_PADDING : Double = 20.0

///|
const D2_SQL_TABLE_HEADER_PADDING : Double = 10.0

///|
const D2_SQL_TABLE_HEADER_FONT_ADD : Int = 4

///|
const D2_CLASS_PREFIX_PADDING : Double = 10.0

///|
const D2_CLASS_PREFIX_WIDTH : Double = 20.0

///|
const D2_CLASS_CENTER_PADDING : Double = 50.0

///|
const D2_CLASS_HEADER_FONT_ADD : Int = 4

///|
const D2_CLASS_TYPE_PADDING : Double = 20.0

///|
const D2_CLASS_VERTICAL_PADDING : Double = 20.0

///|
const D2_DEFAULT_ARC_DEPTH : Double = 24.0

///|
const D2_MIN_SEGMENT_LEN : Double = 10.0

///|
const D2_PARALLELOGRAM_WEDGE_WIDTH : Double = 26.0

///|
const D2_STORED_DATA_WEDGE_WIDTH : Double = 15.0

///|
const D2_STEP_WEDGE_WIDTH : Double = 35.0

///|
const D2_PACKAGE_TOP_MAX_HEIGHT : Double = 55.0

///|
const D2_PACKAGE_TOP_MIN_WIDTH : Double = 50.0

///|
const D2_PACKAGE_TOP_MAX_WIDTH : Double = 150.0

///|
const D2_PACKAGE_HORIZONTAL_SCALAR : Double = 0.5

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
const CLOUD_WIDE_ASPECT_BOUNDARY : Double = (
    1.0 + CLOUD_WIDE_INNER_WIDTH / CLOUD_WIDE_INNER_HEIGHT
  ) /
  2.0

///|
const CLOUD_TALL_INNER_WIDTH : Double = 0.549

///|
const CLOUD_TALL_INNER_HEIGHT : Double = 0.820

///|
const CLOUD_TALL_ASPECT_BOUNDARY : Double = (
    1.0 + CLOUD_TALL_INNER_WIDTH / CLOUD_TALL_INNER_HEIGHT
  ) /
  2.0

///|
const CLOUD_SQUARE_INNER_WIDTH : Double = 0.663

///|
const CLOUD_SQUARE_INNER_HEIGHT : Double = 0.663

///|
const D2_HEXAGON_HALF_Y_FACTOR : Double = 43.6 / 87.3

///|
const D2_CYLINDER_BEZIER_MULTIPLIER : Double = 0.45

///|
const D2_CUBIC_TRACE_SAMPLES : Int = 160

///|
const D2_GEO_PRECISION : Double = 0.0001

///|
priv struct LayoutSpacing {
  top : Double
  left : Double
  bottom : Double
  right : Double
}

///|
priv enum DefaultLabelPosition {
  OutsideTop
  OutsideBottom
  InsideTop
  InsideMiddle
}

///|
pub impl @engine_api.LayoutEngine for ElkEngine with layout(
  _self,
  graph,
  config,
  direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  let graph = canonicalize_layout_graph(graph)
  if graph.root.shape_type == @graph.SequenceDiagram {
    return layout_sequence_diagram(graph, config)
  }

  ensure_moon_elk_json_bootstrap_linked()
  let patch = @graph.LayoutPatch::new()
  copy_passthrough_layout_data(patch, graph)

  let (
    elk_graph,
    edge_id_by_index,
    edge_endpoints_by_index,
    node_size_by_id,
    node_margin_by_id,
  ) = build_elk_graph(graph, config, direction)

  let laid_out_json = @moon_elk_core.new_elk_engine().layout(graph=elk_graph) catch {
    e => raise @engine_api.unsupported("elk layout failed: \{e}")
  }

  let node_box_by_id : Map[String, @graph.Box] = {}
  collect_node_boxes(laid_out_json, 0.0, 0.0, node_box_by_id)
  let routes_by_edge_id : Map[String, Array[@graph.Point]] = {}
  collect_edge_routes(
    laid_out_json, 0.0, 0.0, node_box_by_id, routes_by_edge_id,
  )
  apply_margin_adjustments_like_d2(
    graph, edge_id_by_index, routes_by_edge_id, node_box_by_id, node_margin_by_id,
  )
  fill_patch_nodes(patch, graph, node_box_by_id, node_size_by_id, config)
  fill_patch_edges(
    patch, graph, edge_id_by_index, edge_endpoints_by_index, node_box_by_id, routes_by_edge_id,
    direction,
  )
  apply_root_grid_positions_like_d2(patch, graph)
  apply_constant_near_positions(patch, graph)
  recompute_edge_label_boxes(patch, graph)

  patch
}

///|
pub impl @engine_api.LayoutEngine for ElkEngine with engine_name(_self) -> String {
  "elk"
}

///|
pub impl @engine_api.LayoutEngine for ElkEngine with features(_self) -> Array[
  @engine_api.LayoutFeature,
] {
  [
    @engine_api.LayoutFeature::ContainerDimensions,
    @engine_api.LayoutFeature::DescendantEdges,
  ]
}

///|
fn layout_sequence_diagram(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
) -> @graph.LayoutPatch {
  let patch = @graph.LayoutPatch::new()
  copy_passthrough_layout_data(patch, graph)

  let participant_ids = sequence_participant_ids(graph)
  if participant_ids.is_empty() {
    return patch
  }

  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.id] = graph.root
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  let parent_id_by_child_id = sequence_parent_id_by_child_id(graph)

  let participant_rank_by_id : Map[String, Int] = {}
  let participant_exists : Map[String, Bool] = {}

  let widths : Array[Double] = []
  let heights : Array[Double] = []
  let mut max_actor_height = 0.0
  for id in participant_ids {
    let rank = widths.length()
    participant_rank_by_id[id] = rank
    participant_exists[id] = true
    match object_by_id.get(id) {
      Some(obj) => {
        let (w0, h0) = sequence_object_size(obj, config, object_by_id)
        let (width, height) = sequence_actor_size(obj.shape_type, w0, h0)
        widths.push(width)
        heights.push(height)
        if height > max_actor_height {
          max_actor_height = height
        }
      }
      None => {
        widths.push(D2_SEQUENCE_MIN_ACTOR_WIDTH)
        heights.push(D2_SEQUENCE_MIN_ACTOR_HEIGHT)
        if D2_SEQUENCE_MIN_ACTOR_HEIGHT > max_actor_height {
          max_actor_height = D2_SEQUENCE_MIN_ACTOR_HEIGHT
        }
      }
    }
  }

  let actor_x_step : Array[Double] = []
  if participant_ids.length() >= 2 {
    for i = 0; i < participant_ids.length() - 1; i = i + 1 {
      let actor_hw = widths[i] / 2.0
      let next_actor_hw = widths[i + 1] / 2.0
      let base_step = actor_hw + next_actor_hw + D2_SEQUENCE_HORIZONTAL_PAD
      let step = if base_step < D2_SEQUENCE_MIN_ACTOR_DISTANCE {
        D2_SEQUENCE_MIN_ACTOR_DISTANCE
      } else {
        base_step
      }
      actor_x_step.push(step)
    }
  }

  let ordered_edges = sequence_edges_in_render_order(graph)
  for edge in ordered_edges {
    let src_rank = match
      participant_rank_by_id.get(
        sequence_top_participant_id(
          edge.src_id,
          participant_exists,
          parent_id_by_child_id,
        ),
      ) {
      Some(v) => v
      None => continue
    }
    let dst_rank = match
      participant_rank_by_id.get(
        sequence_top_participant_id(
          edge.dst_id,
          participant_exists,
          parent_id_by_child_id,
        ),
      ) {
      Some(v) => v
      None => continue
    }

    let (label_width, _) = sequence_edge_text_size(edge)
    let rank_diff = if src_rank > dst_rank {
      src_rank - dst_rank
    } else {
      dst_rank - src_rank
    }
    if rank_diff != 0 {
      let distributed_label_width = label_width / rank_diff.to_double()
      let left = if src_rank < dst_rank { src_rank } else { dst_rank }
      let right = if src_rank < dst_rank { dst_rank } else { src_rank }
      for rank = left; rank < right; rank = rank + 1 {
        let required = distributed_label_width +
          D2_SEQUENCE_LABEL_HORIZONTAL_PAD
        if required > actor_x_step[rank] {
          actor_x_step[rank] = required
        }
      }
    } else if src_rank < actor_x_step.length() {
      let label_adjust = label_width + D2_LABEL_PADDING * 4.0
      if label_adjust > actor_x_step[src_rank] {
        actor_x_step[src_rank] = label_adjust
      }
    }
  }

  let centers : Array[Double] = []
  if !widths.is_empty() {
    centers.push(D2_SEQUENCE_GROUP_CONTAINER_PADDING + widths[0] / 2.0)
    for i = 1; i < widths.length(); i = i + 1 {
      centers.push(centers[i - 1] + actor_x_step[i - 1])
    }
  }

  let max_actor_height = max_actor_height +
    D2_SEQUENCE_VERTICAL_PAD +
    sequence_root_label_height(graph)
  let y_shift = D2_SEQUENCE_GROUP_CONTAINER_PADDING
  for i, id in participant_ids {
    let width = widths[i]
    let height = heights[i]
    let mut y = max_actor_height - height + y_shift
    match object_by_id.get(id) {
      Some(obj) =>
        if has_outside_bottom_label(obj.shape_type) {
          y = y - sequence_label_height(obj)
        }
      None => ()
    }
    patch.nodes[id] = @graph.Box::new(
      centers[i] - width / 2.0,
      y,
      width,
      height,
    )
  }

  let y_step = D2_SEQUENCE_MIN_MESSAGE_DISTANCE + D2_SEQUENCE_VERTICAL_PAD
  let mut message_offset = max_actor_height + y_step + y_shift
  for edge in ordered_edges {
    let src_x = match
      sequence_center_x_for_object(edge.src_id, patch, parent_id_by_child_id) {
      Some(v) => v
      None => continue
    }
    let dst_x = match
      sequence_center_x_for_object(edge.dst_id, patch, parent_id_by_child_id) {
      Some(v) => v
      None => continue
    }

    let src_top = sequence_top_participant_id(
      edge.src_id,
      participant_exists,
      parent_id_by_child_id,
    )
    let dst_top = sequence_top_participant_id(
      edge.dst_id,
      participant_exists,
      parent_id_by_child_id,
    )
    let is_to_descendant = is_descendant_of(
      edge.dst_id,
      edge.src_id,
      parent_id_by_child_id,
    )
    let is_from_descendant = is_descendant_of(
      edge.src_id,
      edge.dst_id,
      parent_id_by_child_id,
    )
    let is_self_message = edge.src_id == edge.dst_id
    let is_to_sibling = src_top == dst_top

    let (_, text_height) = sequence_edge_text_size(edge)
    if is_self_message ||
      is_to_descendant ||
      is_from_descendant ||
      is_to_sibling {
      let (label_width, _) = sequence_edge_text_size(edge)
      let mid_x = src_x +
        (if D2_SEQUENCE_SELF_MESSAGE_HORIZONTAL_TRAVEL >
          label_width / 2.0 + D2_LABEL_PADDING * 2.0 {
          D2_SEQUENCE_SELF_MESSAGE_HORIZONTAL_TRAVEL
        } else {
          label_width / 2.0 + D2_LABEL_PADDING * 2.0
        })
      let start_y = message_offset
      let end_y = start_y +
        (if text_height > D2_SEQUENCE_MIN_MESSAGE_DISTANCE {
          text_height * 1.5
        } else {
          D2_SEQUENCE_MIN_MESSAGE_DISTANCE * 1.5
        })
      patch.edges[edge.index] = [
        @graph.Point::new(src_x, start_y),
        @graph.Point::new(mid_x, start_y),
        @graph.Point::new(mid_x, end_y),
        @graph.Point::new(dst_x, end_y),
      ]
      message_offset = end_y + y_step
    } else {
      let start_y = message_offset + text_height / 2.0
      patch.edges[edge.index] = [
        @graph.Point::new(src_x, start_y),
        @graph.Point::new(dst_x, start_y),
      ]
      message_offset = start_y + text_height / 2.0 + y_step
    }
  }

  for edge in ordered_edges {
    let route = match patch.edges.get(edge.index) {
      Some(v) => v
      None => continue
    }
    if route.is_empty() {
      continue
    }
    let src_top = sequence_top_participant_id(
      edge.src_id,
      participant_exists,
      parent_id_by_child_id,
    )
    let dst_top = sequence_top_participant_id(
      edge.dst_id,
      participant_exists,
      parent_id_by_child_id,
    )
    let src_rank = match participant_rank_by_id.get(src_top) {
      Some(v) => v
      None => continue
    }
    let dst_rank = match participant_rank_by_id.get(dst_top) {
      Some(v) => v
      None => continue
    }
    if !participant_exists.contains(edge.src_id) {
      let src_width = sequence_object_width(
        edge.src_id,
        patch,
        object_by_id,
        config,
      )
      let first = route[0]
      if src_rank <= dst_rank {
        route[0] = @graph.Point::new(first.x + src_width / 2.0, first.y)
      } else {
        route[0] = @graph.Point::new(first.x - src_width / 2.0, first.y)
      }
    }
    if !participant_exists.contains(edge.dst_id) {
      let dst_width = sequence_object_width(
        edge.dst_id,
        patch,
        object_by_id,
        config,
      )
      let last = route.length() - 1
      let last_point = route[last]
      if src_rank < dst_rank {
        route[last] = @graph.Point::new(
          last_point.x - dst_width / 2.0,
          last_point.y,
        )
      } else {
        route[last] = @graph.Point::new(
          last_point.x + dst_width / 2.0,
          last_point.y,
        )
      }
    }
  }

  let object_by_abs_id : Map[String, @graph.ObjectInput] = {}
  object_by_abs_id[graph.root.abs_id_syntax] = graph.root
  for obj in graph.objects {
    object_by_abs_id[obj.abs_id_syntax] = obj
  }
  sequence_place_nested_objects_like_d2(
    patch, graph, ordered_edges, participant_exists, parent_id_by_child_id, object_by_id,
    object_by_abs_id, config, max_actor_height, y_step,
  )

  recompute_edge_label_boxes(patch, graph)
  patch
}

///|
fn recompute_edge_label_boxes(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  for edge in graph.edges {
    if edge.label == "" {
      continue
    }
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
    let label_x = round_double(center.x - width / 2.0)
    let label_y = round_double(center.y - height / 2.0)
    patch.edge_labels[edge.index] = @graph.Box::new(
      label_x, label_y, width, height,
    )
  }
}

///|
fn sequence_parent_id_by_child_id(
  graph : @graph.GraphInput,
) -> Map[String, String] {
  let out : Map[String, String] = {}
  for child_id in graph.root.child_ids {
    out[child_id] = graph.root.id
  }
  for obj in graph.objects {
    for child_id in obj.child_ids {
      out[child_id] = obj.id
    }
  }
  out
}

///|
fn sequence_edges_in_render_order(
  graph : @graph.GraphInput,
) -> Array[@graph.EdgeInput] {
  let out : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    out.push(edge)
  }
  out.sort_by(fn(a, b) { a.index.compare(b.index) })
  out
}

///|
fn sequence_actor_size(
  shape_type : @graph.ShapeType,
  width : Double,
  height : Double,
) -> (Double, Double) {
  let mut w = width
  let mut h = height
  if w < D2_SEQUENCE_MIN_ACTOR_WIDTH {
    match shape_type {
      @graph.Person | @graph.Oval | @graph.Square | @graph.Circle =>
        if w > 0.0 {
          h = h * D2_SEQUENCE_MIN_ACTOR_WIDTH / w
        }
      _ => ()
    }
    w = D2_SEQUENCE_MIN_ACTOR_WIDTH
  }
  if h < D2_SEQUENCE_MIN_ACTOR_HEIGHT {
    h = D2_SEQUENCE_MIN_ACTOR_HEIGHT
  }
  (w, h)
}

///|
fn sequence_label_height(obj : @graph.ObjectInput) -> Double {
  match obj.label_box {
    Some(box) => if box.height > 0.0 { box.height } else { 0.0 }
    None =>
      if obj.label == "" {
        0.0
      } else {
        let font_size = match obj.style.font_size {
          Some(v) => v.as_int().unwrap_or(16)
          None => 16
        }
        let is_bold = style_bool(obj.style.bold, false)
        let is_italic = style_bool(obj.style.italic, false)
        let is_mono = style_is_mono(obj.style.font_family)
        let dims = @text_metrics.measure_label(
          obj.label,
          font_size,
          is_mono,
          is_bold,
          is_italic,
        )
        if dims.height > 0.0 {
          dims.height
        } else {
          font_size.to_double() + 5.0
        }
      }
  }
}

///|
fn sequence_root_label_height(graph : @graph.GraphInput) -> Double {
  if graph.root.label == "" || graph.root.label == graph.root.id_val {
    0.0
  } else {
    sequence_label_height(graph.root)
  }
}

///|
fn sequence_center_x_for_object(
  id : String,
  patch : @graph.LayoutPatch,
  parent_id_by_child_id : Map[String, String],
) -> Double? {
  let mut current = id
  let visited : Map[String, Bool] = {}
  while !visited.contains(current) {
    visited[current] = true
    match patch.nodes.get(current) {
      Some(box) => return Some(box.x + box.width / 2.0)
      None =>
        match parent_id_by_child_id.get(current) {
          Some(parent_id) => current = parent_id
          None => return None
        }
    }
  }
  None
}

///|
fn sequence_top_participant_id(
  id : String,
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
) -> String {
  if participant_exists.contains(id) {
    return id
  }
  let mut current = id
  let visited : Map[String, Bool] = {}
  while !visited.contains(current) {
    visited[current] = true
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => {
        if participant_exists.contains(parent_id) {
          return parent_id
        }
        current = parent_id
      }
      None => return id
    }
  }
  id
}

///|
fn sequence_edge_text_size(edge : @graph.EdgeInput) -> (Double, Double) {
  let (label_width, label_height) = sequence_edge_label_size(edge)
  if label_width <= 0.0 || label_height <= 0.0 {
    return (0.0, 0.0)
  }
  let width = if label_width > 4.0 { label_width - 4.0 } else { label_width }
  let height = if label_height > 1.0 {
    label_height - 1.0
  } else {
    label_height
  }
  (width, height)
}

///|
fn sequence_object_width(
  id : String,
  patch : @graph.LayoutPatch,
  object_by_id : Map[String, @graph.ObjectInput],
  config : @engine_api.LayoutConfig,
) -> Double {
  match patch.nodes.get(id) {
    Some(box) => box.width
    None =>
      match object_by_id.get(id) {
        Some(obj) => {
          let (width, _) = sequence_object_size(obj, config, object_by_id)
          width
        }
        None => config.default_width
      }
  }
}

///|
fn sequence_place_nested_objects_like_d2(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  ordered_edges : Array[@graph.EdgeInput],
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  object_by_id : Map[String, @graph.ObjectInput],
  object_by_abs_id : Map[String, @graph.ObjectInput],
  config : @engine_api.LayoutConfig,
  max_actor_height : Double,
  y_step : Double,
) -> Unit {
  let notes : Array[@graph.ObjectInput] = []
  let spans : Array[@graph.ObjectInput] = []
  let note_line_by_id : Map[String, Int] = {}
  let participant_ids = sequence_participant_ids(graph)
  for participant_id in participant_ids {
    let participant = match object_by_abs_id.get(participant_id) {
      Some(obj) => obj
      None => continue
    }
    let queue : Array[String] = []
    for child_id in participant.child_ids {
      if object_by_abs_id.contains(child_id) {
        queue.push(child_id)
      }
    }
    let mut index = 0
    while index < queue.length() {
      let child_id = queue[index]
      index += 1
      let child = match object_by_abs_id.get(child_id) {
        Some(obj) => obj
        None => continue
      }
      if sequence_is_note_like_d2(child, graph) {
        notes.push(child)
        note_line_by_id[child.abs_id_syntax] = sequence_object_earliest_line_like_d2(
          child,
        )
      } else {
        spans.push(child)
      }
      for grandchild_id in child.child_ids {
        if object_by_abs_id.contains(grandchild_id) {
          queue.push(grandchild_id)
        }
      }
    }
  }
  sequence_place_notes_like_d2(
    patch, notes, ordered_edges, note_line_by_id, participant_exists, parent_id_by_child_id,
    object_by_id, config, max_actor_height, y_step,
  )
  sequence_place_spans_like_d2(
    patch, spans, ordered_edges, participant_exists, parent_id_by_child_id,
  )
}

///|
fn sequence_place_notes_like_d2(
  patch : @graph.LayoutPatch,
  notes : Array[@graph.ObjectInput],
  ordered_edges : Array[@graph.EdgeInput],
  note_line_by_id : Map[String, Int],
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  object_by_id : Map[String, @graph.ObjectInput],
  config : @engine_api.LayoutConfig,
  max_actor_height : Double,
  y_step : Double,
) -> Unit {
  for note in notes {
    let vertical_index = note_line_by_id.get_or_default(
      note.abs_id_syntax,
      sequence_object_earliest_line_like_d2(note),
    )
    let mut y = max_actor_height + y_step
    for edge in ordered_edges {
      if sequence_edge_earliest_line_like_d2(edge) >= vertical_index {
        continue
      }
      let (_, text_height) = sequence_edge_text_size(edge)
      let extra = if sequence_message_has_vertical_turn_like_d2(
          edge, participant_exists, parent_id_by_child_id,
        ) {
        if text_height > D2_SEQUENCE_MIN_MESSAGE_DISTANCE {
          text_height * 1.5
        } else {
          D2_SEQUENCE_MIN_MESSAGE_DISTANCE * 1.5
        }
      } else {
        text_height
      }
      y = y + extra + y_step
    }
    for other_note in notes {
      if other_note.abs_id_syntax == note.abs_id_syntax {
        continue
      }
      if note_line_by_id.get_or_default(
          other_note.abs_id_syntax,
          sequence_object_earliest_line_like_d2(other_note),
        ) >=
        vertical_index {
        continue
      }
      let (_, note_height) = sequence_object_size(
        other_note, config, object_by_id,
      )
      y = y + note_height + y_step
    }
    let center_x = match
      sequence_center_x_for_object(
        note.abs_id_syntax,
        patch,
        parent_id_by_child_id,
      ) {
      Some(value) => value
      None => continue
    }
    let (width, height) = sequence_object_size(note, config, object_by_id)
    patch.nodes[note.abs_id_syntax] = @graph.Box::new(
      center_x - width / 2.0,
      y,
      width,
      height,
    )
  }
}

///|
fn sequence_place_spans_like_d2(
  patch : @graph.LayoutPatch,
  spans : Array[@graph.ObjectInput],
  ordered_edges : Array[@graph.EdgeInput],
  _participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
) -> Unit {
  let first_message_by_id : Map[String, @graph.EdgeInput] = {}
  let last_message_by_id : Map[String, @graph.EdgeInput] = {}
  for edge in ordered_edges {
    if !first_message_by_id.contains(edge.src_id_syntax) {
      first_message_by_id[edge.src_id_syntax] = edge
    }
    if !first_message_by_id.contains(edge.dst_id_syntax) {
      first_message_by_id[edge.dst_id_syntax] = edge
    }
    last_message_by_id[edge.src_id_syntax] = edge
    last_message_by_id[edge.dst_id_syntax] = edge
  }

  let sorted_spans = sequence_sort_spans_most_nested(
    spans, parent_id_by_child_id,
  )
  for span in sorted_spans {
    let mut min_child_y = 1000000000.0
    let mut max_child_y = -1000000000.0
    let mut saw_child = false
    for child_id in span.child_ids {
      match patch.nodes.get(child_id) {
        Some(box) => {
          saw_child = true
          if box.y < min_child_y {
            min_child_y = box.y
          }
          if box.y + box.height > max_child_y {
            max_child_y = box.y + box.height
          }
        }
        None => ()
      }
    }

    let mut min_message_y = 1000000000.0
    match first_message_by_id.get(span.abs_id_syntax) {
      Some(first_message) =>
        if !first_message.route.is_empty() {
          if first_message.src_id_syntax == first_message.dst_id_syntax ||
            first_message.src_id_syntax == span.abs_id_syntax {
            min_message_y = first_message.route[0].y
          } else {
            min_message_y = first_message.route[first_message.route.length() - 1].y
          }
        }
      None => ()
    }

    let mut max_message_y = -1000000000.0
    match last_message_by_id.get(span.abs_id_syntax) {
      Some(last_message) =>
        if !last_message.route.is_empty() {
          if last_message.src_id_syntax == last_message.dst_id_syntax ||
            last_message.dst_id_syntax == span.abs_id_syntax {
            max_message_y = last_message.route[last_message.route.length() - 1].y
          } else {
            max_message_y = last_message.route[0].y
          }
        }
      None => ()
    }

    let min_y = if saw_child || min_message_y < 1000000000.0 {
      if min_child_y < min_message_y {
        min_child_y
      } else {
        min_message_y
      }
    } else {
      continue
    }
    let max_y = if saw_child || max_message_y > -1000000000.0 {
      if max_child_y > max_message_y {
        max_child_y
      } else {
        max_message_y
      }
    } else {
      continue
    }

    let mut padded_min_y = min_y
    if approx_eq(min_y, min_child_y) || approx_eq(min_y, min_message_y) {
      padded_min_y = padded_min_y - D2_SEQUENCE_SPAN_MESSAGE_PAD
    }
    let mut padded_max_y = max_y
    if approx_eq(max_y, max_child_y) || approx_eq(max_y, max_message_y) {
      padded_max_y = padded_max_y + D2_SEQUENCE_SPAN_MESSAGE_PAD
    }

    let mut height = padded_max_y - padded_min_y
    if height < D2_SEQUENCE_MIN_SPAN_HEIGHT {
      height = D2_SEQUENCE_MIN_SPAN_HEIGHT
    }
    let width = D2_SEQUENCE_SPAN_BASE_WIDTH +
      sequence_span_depth_like_d2(span, parent_id_by_child_id).to_double() *
      D2_SEQUENCE_SPAN_DEPTH_GROWTH
    let center_x = match
      sequence_center_x_for_object(
        span.abs_id_syntax,
        patch,
        parent_id_by_child_id,
      ) {
      Some(value) => value
      None => continue
    }
    patch.nodes[span.abs_id_syntax] = @graph.Box::new(
      center_x - width / 2.0,
      padded_min_y,
      width,
      height,
    )
  }
}

///|
fn sequence_sort_spans_most_nested(
  spans : Array[@graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> Array[@graph.ObjectInput] {
  let sorted : Array[@graph.ObjectInput] = []
  for span in spans {
    sorted.push(span)
  }
  for i in 0..<sorted.length() {
    for j in (i + 1)..<sorted.length() {
      if sequence_span_depth_like_d2(sorted[j], parent_id_by_child_id) >
        sequence_span_depth_like_d2(sorted[i], parent_id_by_child_id) {
        let tmp = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = tmp
      }
    }
  }
  sorted
}

///|
fn sequence_span_depth_like_d2(
  span : @graph.ObjectInput,
  parent_id_by_child_id : Map[String, String],
) -> Int {
  let mut depth = 0
  let mut current = span.abs_id_syntax
  while true {
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => {
        depth += 1
        current = parent_id
      }
      None => break
    }
  }
  if depth > 2 {
    depth - 2
  } else {
    0
  }
}

///|
fn sequence_message_has_vertical_turn_like_d2(
  edge : @graph.EdgeInput,
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
) -> Bool {
  let src_top = sequence_top_participant_id(
    edge.src_id_syntax,
    participant_exists,
    parent_id_by_child_id,
  )
  let dst_top = sequence_top_participant_id(
    edge.dst_id_syntax,
    participant_exists,
    parent_id_by_child_id,
  )
  edge.src_id_syntax == edge.dst_id_syntax ||
  is_descendant_of(
    edge.dst_id_syntax,
    edge.src_id_syntax,
    parent_id_by_child_id,
  ) ||
  is_descendant_of(
    edge.src_id_syntax,
    edge.dst_id_syntax,
    parent_id_by_child_id,
  ) ||
  src_top == dst_top
}

///|
fn sequence_is_note_like_d2(
  obj : @graph.ObjectInput,
  graph : @graph.GraphInput,
) -> Bool {
  !sequence_object_has_incident_edge_like_d2(obj, graph) &&
  !sequence_object_contains_any_edge_like_d2(obj, graph) &&
  obj.child_ids.is_empty()
}

///|
fn sequence_object_has_incident_edge_like_d2(
  obj : @graph.ObjectInput,
  graph : @graph.GraphInput,
) -> Bool {
  for edge in graph.edges {
    if edge.src_id_syntax == obj.abs_id_syntax ||
      edge.dst_id_syntax == obj.abs_id_syntax ||
      edge.src_id == obj.id ||
      edge.dst_id == obj.id {
      return true
    }
  }
  false
}

///|
fn sequence_object_contains_any_edge_like_d2(
  obj : @graph.ObjectInput,
  graph : @graph.GraphInput,
) -> Bool {
  for edge in graph.edges {
    if sequence_edge_contained_by_like_d2(edge, obj.abs_id_syntax) {
      return true
    }
  }
  false
}

///|
fn sequence_edge_contained_by_like_d2(
  edge : @graph.EdgeInput,
  abs_id_syntax : String,
) -> Bool {
  for reference in edge.references {
    if reference.contained_by(abs_id_syntax) {
      return true
    }
  }
  let prefix = abs_id_syntax + "."
  edge.src_id_syntax.has_prefix(prefix) || edge.dst_id_syntax.has_prefix(prefix)
}

///|
fn sequence_object_earliest_line_like_d2(obj : @graph.ObjectInput) -> Int {
  let mut min_line = 1073741824
  for reference in obj.references {
    if reference.due_to_glob || reference.due_to_lazy_glob {
      continue
    }
    if reference.range.start.line < min_line {
      min_line = reference.range.start.line
    }
  }
  min_line
}

///|
fn sequence_edge_earliest_line_like_d2(edge : @graph.EdgeInput) -> Int {
  let mut min_line = 1073741824
  for reference in edge.references {
    if reference.due_to_glob || reference.due_to_lazy_glob {
      continue
    }
    if reference.range.start.line < min_line {
      min_line = reference.range.start.line
    }
  }
  min_line
}

///|
fn is_descendant_of(
  obj_id : String,
  ancestor_id : String,
  parent_id_by_child_id : Map[String, String],
) -> Bool {
  let mut current = obj_id
  while true {
    if current == ancestor_id {
      return true
    }
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => current = parent_id
      None => break
    }
  }
  false
}

///|
fn sequence_object_size(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
  object_by_id : Map[String, @graph.ObjectInput],
) -> (Double, Double) {
  let estimate_auto_size = () => {
    if obj.shape_type == @graph.SqlTable {
      let (width, height) = estimate_sql_table_size(obj, object_by_id)
      (
        clamp_positive(width, config.default_width),
        clamp_positive(height, config.default_height),
      )
    } else if obj.shape_type == @graph.Class {
      let (width, height) = estimate_class_size(obj, object_by_id)
      (
        clamp_positive(width, config.default_width),
        clamp_positive(height, config.default_height),
      )
    } else {
      estimate_sequence_object_size(obj, config)
    }
  }
  match obj.box {
    Some(box) => {
      let (auto_width, auto_height) = estimate_auto_size()
      let width = if box.width > 0.0 { box.width } else { auto_width }
      let height = if box.height > 0.0 { box.height } else { auto_height }
      (
        clamp_positive(width, config.default_width),
        clamp_positive(height, config.default_height),
      )
    }
    None => estimate_auto_size()
  }
}

///|
fn estimate_sequence_object_size(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
) -> (Double, Double) {
  let font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(obj.style.bold, false)
  let is_italic = style_bool(obj.style.italic, false)
  let is_mono = obj.shape_type == @graph.Code ||
    style_is_mono(obj.style.font_family)
  let label_dims = if obj.shape_type == @graph.Code {
    @text_metrics.measure_label_code(obj.label, font_size, is_bold, is_italic)
  } else {
    @text_metrics.measure_label(
      obj.label,
      font_size,
      is_mono,
      is_bold,
      is_italic,
    )
  }
  let mut content_width = label_dims.width
  let mut content_height = label_dims.height

  if obj.shape_type == @graph.Code {
    content_width = content_width + font_size.to_double()
    content_height = content_height + font_size.to_double()
    return (content_width, content_height)
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

  let base_padding = shape_default_padding(obj.shape_type)
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

  let fitted = shape_dimensions_to_fit(
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
    let fit = limit_aspect_ratio(width, height, D2_PERSON_AR_LIMIT)
    width = fit.0
    height = fit.1
  } else if obj.shape_type == @graph.Oval {
    let fit = limit_aspect_ratio(width, height, D2_OVAL_AR_LIMIT)
    width = fit.0
    height = fit.1
  } else if obj.shape_type == @graph.C4Person {
    let fit = limit_aspect_ratio(width, height, D2_C4_PERSON_AR_LIMIT)
    width = fit.0
    height = fit.1
  }

  (
    clamp_positive(width, config.default_width),
    clamp_positive(height, config.default_height),
  )
}

///|
fn sequence_participant_ids(graph : @graph.GraphInput) -> Array[String] {
  if !graph.root.child_ids.is_empty() {
    let ids : Array[String] = []
    let object_by_id : Map[String, @graph.ObjectInput] = {}
    for obj in graph.objects {
      object_by_id[obj.id] = obj
    }
    for id in graph.root.child_ids {
      if object_by_id.contains(id) {
        ids.push(id)
      }
    }
    if !ids.is_empty() {
      ids.sort_by(fn(a, b) {
        let line_a = match object_by_id.get(a) {
          Some(obj) => sequence_object_earliest_line_like_d2(obj)
          None => 1073741824
        }
        let line_b = match object_by_id.get(b) {
          Some(obj) => sequence_object_earliest_line_like_d2(obj)
          None => 1073741824
        }
        let cmp = line_a.compare(line_b)
        if cmp != 0 {
          cmp
        } else {
          0
        }
      })
      return ids
    }
  }
  let child_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    for child_id in obj.child_ids {
      child_ids[child_id] = true
    }
  }
  let ids : Array[String] = []
  for obj in graph.objects {
    if !child_ids.contains(obj.id) {
      ids.push(obj.id)
    }
  }
  ids
}

///|
fn sequence_edge_label_size(edge : @graph.EdgeInput) -> (Double, Double) {
  match edge.label_box {
    Some(box) =>
      if box.width > 0.0 && box.height > 0.0 {
        (box.width, box.height)
      } else {
        fallback_sequence_edge_label_size(edge)
      }
    None => fallback_sequence_edge_label_size(edge)
  }
}

///|
fn fallback_sequence_edge_label_size(
  edge : @graph.EdgeInput,
) -> (Double, Double) {
  if edge.label.is_empty() {
    return (0.0, 0.0)
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
    dims.width + 4.0
  } else {
    edge.label.length().to_double() * 7.0 + 12.0
  }
  let text_height = if dims.height > 0.0 {
    dims.height
  } else {
    font_size.to_double() + 5.0
  }
  let min_height = font_size.to_double() + 5.0
  let height = if text_height < min_height { min_height } else { text_height }
  (width, height)
}

///|
fn ensure_moon_elk_json_bootstrap_linked() -> Unit {
  // `moon_elk/graph/json` registers the core layout delegate in package init.
  // Keep a direct reference so tree-shaking does not drop the import.
  ignore(@moon_elk_json.new_json_adapter)
}

///|
fn canonicalize_layout_object(obj : @graph.ObjectInput) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    obj.lookup_id(),
    obj.label,
    obj.shape_type,
    obj.style,
    obj.box,
    obj.label_box,
    obj.child_ids,
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
    direction=obj.direction,
    language=obj.language,
    sql_constraints=obj.sql_constraints,
    id_val=obj.id_val,
    id_syntax=obj.id_syntax,
    abs_id_syntax=obj.abs_id_syntax,
    references=obj.references,
  )
}

///|
fn canonicalize_layout_edge(edge : @graph.EdgeInput) -> @graph.EdgeInput {
  let src_id = edge.lookup_src_id()
  let dst_id = edge.lookup_dst_id()
  @graph.EdgeInput::from_parts(
    edge.index,
    src_id,
    dst_id,
    edge.src_arrow,
    edge.dst_arrow,
    edge.src_arrowhead,
    edge.dst_arrowhead,
    edge.src_arrowhead_label,
    edge.dst_arrowhead_label,
    edge.src_arrowhead_label_color,
    edge.dst_arrowhead_label_color,
    edge.src_anchor,
    edge.dst_anchor,
    edge.label,
    edge.style,
    edge.route,
    edge.bend_points,
    edge.is_curve,
    edge.z_index,
    edge.reference_count,
    edge.label_box,
    edge.src_column_index,
    edge.dst_column_index,
    src_id_syntax=src_id,
    dst_id_syntax=dst_id,
    references=edge.references,
  )
}

///|
fn canonicalize_layout_graph(graph : @graph.GraphInput) -> @graph.GraphInput {
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    objects.push(canonicalize_layout_object(obj))
  }
  let edges : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    edges.push(canonicalize_layout_edge(edge))
  }
  @graph.GraphInput::from_parts(
    graph.name,
    canonicalize_layout_object(graph.root),
    objects,
    edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
    is_folder_only=graph.is_folder_only,
    data=graph.data,
  )
}

///|
fn build_elk_graph(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> (
  Json,
  Map[Int, String],
  Map[Int, (String, String)],
  Map[String, (Double, Double)],
  Map[String, LayoutSpacing],
) {
  let graph = canonicalize_layout_graph(graph)
  let (object_by_id, parent_id_by_child_id) = build_object_maps(graph)
  let excluded_node_ids = build_excluded_layout_node_ids(
    graph, parent_id_by_child_id, object_by_id,
  )

  let node_json_by_id : Map[String, Map[String, Json]] = {}
  let node_ids : Map[String, Bool] = {}
  let node_size_by_id : Map[String, (Double, Double)] = {}
  let node_margin_by_id : Map[String, LayoutSpacing] = {}
  let endpoint_degree_counts = build_endpoint_degree_counts(
    graph, excluded_node_ids,
  )

  for obj in graph.objects {
    if excluded_node_ids.contains(obj.id) {
      continue
    }
    let (auto_width, auto_height) = object_size(obj, config, object_by_id)
    let (incoming, outgoing) = match endpoint_degree_counts.get(obj.id) {
      Some(v) => v
      None => (0, 0)
    }
    let (base_width0, base_height0) = apply_multi_edge_min_size_like_d2(
      obj, direction, auto_width, auto_height, incoming, outgoing,
    )
    let (base_width, base_height) = apply_label_icon_height_boost_like_d2(
      obj, config, base_width0, base_height0,
    )
    let box = @graph.Box::new(0.0, 0.0, base_width, base_height)
    let (margin, _) = object_layout_spacing(obj, box)
    let width = base_width + margin.left + margin.right
    let height = base_height + margin.top + margin.bottom
    node_size_by_id[obj.id] = (base_width, base_height)
    node_margin_by_id[obj.id] = margin

    let node_json : Map[String, Json] = {
      "id": Json::string(obj.id),
      "x": Json::number(0.0),
      "y": Json::number(0.0),
      "width": Json::number(width),
      "height": Json::number(height),
    }

    if !obj.label.is_empty() {
      node_json["labels"] = Json::array([
        Json::object({
          "text": Json::string(obj.label),
          "x": Json::number(0.0),
          "y": Json::number(0.0),
          "width": Json::number(label_width(obj, config)),
          "height": Json::number(label_height(obj, config)),
        }),
      ])
    }

    let has_layout_children = has_layout_children(obj, excluded_node_ids)
    if has_layout_children {
      let self_loop_spacing = self_loop_spacing_for_parent(
        graph,
        obj.child_ids,
        direction,
      )
      node_json["layoutOptions"] = Json::object(
        make_container_layout_options(
          config, direction, width, height, self_loop_spacing,
        ),
      )
    } else {
      node_json["layoutOptions"] = Json::object(make_leaf_layout_options())
    }

    if obj.shape_type == @graph.SqlTable {
      let layout_options = json_object_field(node_json, "layoutOptions")
      layout_options["elk.portConstraints"] = Json::string("FIXED_POS")
      node_json["layoutOptions"] = Json::object(layout_options)
      let ports = build_sql_table_ports(obj, direction, height)
      node_json["ports"] = Json::array(ports)
    }

    node_json_by_id[obj.id] = node_json
    node_ids[obj.id] = true
  }

  let attached_to_parent : Map[String, Bool] = {}
  for obj in graph.objects {
    if excluded_node_ids.contains(obj.id) {
      continue
    }
    let parent_node = match node_json_by_id.get(obj.id) {
      Some(node) => node
      None => continue
    }
    let children_json : Array[Json] = []
    for child_id in obj.child_ids {
      if excluded_node_ids.contains(child_id) {
        continue
      }
      match node_json_by_id.get(child_id) {
        Some(child_node) => {
          children_json.push(Json::object(child_node))
          attached_to_parent[child_id] = true
        }
        None => ()
      }
    }
    if !children_json.is_empty() {
      parent_node["children"] = Json::array(children_json)
      node_json_by_id[obj.id] = parent_node
    }
  }

  let root_children : Array[Json] = []
  let attached_to_root : Map[String, Bool] = {}
  for child_id in graph.root.child_ids {
    if excluded_node_ids.contains(child_id) {
      continue
    }
    match node_json_by_id.get(child_id) {
      Some(child_node) => {
        root_children.push(Json::object(child_node))
        attached_to_root[child_id] = true
      }
      None => ()
    }
  }
  for obj in graph.objects {
    if excluded_node_ids.contains(obj.id) {
      continue
    }
    if attached_to_parent.contains(obj.id) || attached_to_root.contains(obj.id) {
      continue
    }
    match node_json_by_id.get(obj.id) {
      Some(child_node) => root_children.push(Json::object(child_node))
      None => ()
    }
  }

  let edge_id_by_index : Map[Int, String] = {}
  let edge_endpoints_by_index : Map[Int, (String, String)] = {}
  let edges_json : Array[Json] = []
  let edge_repeat_indices = d2_edge_repeat_indices(graph.edges)
  let (default_sql_src_side, default_sql_dst_side) = sql_root_port_sides(
    direction,
  )
  let sql_root_port_ids_by_group : Map[String, Array[String]] = {}

  for i, edge in graph.edges {
    let src_id = match
      resolve_edge_endpoint_id(
        edge.src_id,
        node_ids,
        object_by_id,
        parent_id_by_child_id,
      ) {
      Some(id) => id
      None => continue
    }
    let dst_id = match
      resolve_edge_endpoint_id(
        edge.dst_id,
        node_ids,
        object_by_id,
        parent_id_by_child_id,
      ) {
      Some(id) => id
      None => continue
    }

    let edge_id = elk_edge_id(edge, edge_repeat_indices[i])
    edge_id_by_index[edge.index] = edge_id
    edge_endpoints_by_index[edge.index] = (src_id, dst_id)

    let source_endpoint = edge_endpoint_with_sql_port(
      edge.src_column_index,
      src_id,
      true,
      i,
      default_sql_src_side,
      object_by_id,
      node_json_by_id,
      sql_root_port_ids_by_group,
    )
    let target_endpoint = edge_endpoint_with_sql_port(
      edge.dst_column_index,
      dst_id,
      false,
      i,
      default_sql_dst_side,
      object_by_id,
      node_json_by_id,
      sql_root_port_ids_by_group,
    )

    let edge_json : Map[String, Json] = {
      "id": Json::string(edge_id),
      "sources": Json::array([Json::string(source_endpoint)]),
      "targets": Json::array([Json::string(target_endpoint)]),
      "container": Json::string(""),
    }

    match edge_label_size(edge) {
      Some((label_w, label_h)) =>
        edge_json["labels"] = Json::array([
          Json::object({
            "text": Json::string(edge.label),
            "x": Json::number(0.0),
            "y": Json::number(0.0),
            "width": Json::number(label_w),
            "height": Json::number(label_h),
            "layoutOptions": Json::object({
              "elk.direction": Json::string(""),
              "elk.edgeLabels.inline": Json::boolean(true),
              "elk.spacing.nodeSelfLoop": Json::number(0.0),
            }),
          }),
        ])
      None => ()
    }

    edges_json.push(Json::object(edge_json))
  }

  assign_sql_root_port_x_positions(node_json_by_id, sql_root_port_ids_by_group)

  let root_self_loop_spacing = self_loop_spacing_for_parent(
    graph,
    graph.root.child_ids,
    direction,
  )
  let root_json : Map[String, Json] = {
    "id": Json::string(""),
    "layoutOptions": Json::object(
      make_root_layout_options(config, direction, root_self_loop_spacing),
    ),
    "children": Json::array(root_children),
    "edges": Json::array(edges_json),
  }

  (
    Json::object(root_json),
    edge_id_by_index,
    edge_endpoints_by_index,
    node_size_by_id,
    node_margin_by_id,
  )
}

///|
fn apply_margin_adjustments_like_d2(
  graph : @graph.GraphInput,
  edge_id_by_index : Map[Int, String],
  routes_by_edge_id : Map[String, Array[@graph.Point]],
  node_box_by_id : Map[String, @graph.Box],
  node_margin_by_id : Map[String, LayoutSpacing],
) -> Unit {
  let child_ids_by_id : Map[String, Array[String]] = {}
  for obj in graph.objects {
    child_ids_by_id[obj.id] = obj.child_ids
  }

  for obj in graph.objects {
    let margin = match node_margin_by_id.get(obj.id) {
      Some(v) => v
      None => continue
    }
    if approx_zero(margin.left) &&
      approx_zero(margin.right) &&
      approx_zero(margin.top) &&
      approx_zero(margin.bottom) {
      continue
    }
    let mut box = match node_box_by_id.get(obj.id) {
      Some(v) => v
      None => continue
    }

    if margin.left > 0.0 {
      for edge in graph.edges {
        let edge_id = match edge_id_by_index.get(edge.index) {
          Some(v) => v
          None => continue
        }
        let route = match routes_by_edge_id.get(edge_id) {
          Some(v) => v
          None => continue
        }
        if route.is_empty() {
          continue
        }
        let last = route.length() - 1
        if edge.src_id == obj.id && route[0].x == box.x {
          route[0] = @graph.Point::new(route[0].x + margin.left, route[0].y)
        }
        if edge.dst_id == obj.id && route[last].x == box.x {
          route[last] = @graph.Point::new(
            route[last].x + margin.left,
            route[last].y,
          )
        }
      }
      box = @graph.Box::new(box.x + margin.left, box.y, box.width, box.height)
      shift_descendant_boxes(
        node_box_by_id,
        child_ids_by_id,
        obj.id,
        margin.left / 2.0,
        0.0,
      )
      box = @graph.Box::new(box.x, box.y, box.width - margin.left, box.height)
    }

    if margin.right > 0.0 {
      for edge in graph.edges {
        let edge_id = match edge_id_by_index.get(edge.index) {
          Some(v) => v
          None => continue
        }
        let route = match routes_by_edge_id.get(edge_id) {
          Some(v) => v
          None => continue
        }
        if route.is_empty() {
          continue
        }
        let last = route.length() - 1
        let right_x = box.x + box.width
        if edge.src_id == obj.id && route[0].x == right_x {
          route[0] = @graph.Point::new(route[0].x - margin.right, route[0].y)
        }
        if edge.dst_id == obj.id && route[last].x == right_x {
          route[last] = @graph.Point::new(
            route[last].x - margin.right,
            route[last].y,
          )
        }
      }
      shift_descendant_boxes(
        node_box_by_id,
        child_ids_by_id,
        obj.id,
        -margin.right / 2.0,
        0.0,
      )
      box = @graph.Box::new(box.x, box.y, box.width - margin.right, box.height)
    }

    if margin.top > 0.0 {
      for edge in graph.edges {
        let edge_id = match edge_id_by_index.get(edge.index) {
          Some(v) => v
          None => continue
        }
        let route = match routes_by_edge_id.get(edge_id) {
          Some(v) => v
          None => continue
        }
        if route.is_empty() {
          continue
        }
        let last = route.length() - 1
        if edge.src_id == obj.id && route[0].y == box.y {
          route[0] = @graph.Point::new(route[0].x, route[0].y + margin.top)
        }
        if edge.dst_id == obj.id && route[last].y == box.y {
          route[last] = @graph.Point::new(
            route[last].x,
            route[last].y + margin.top,
          )
        }
      }
      box = @graph.Box::new(box.x, box.y + margin.top, box.width, box.height)
      shift_descendant_boxes(
        node_box_by_id,
        child_ids_by_id,
        obj.id,
        0.0,
        margin.top / 2.0,
      )
      box = @graph.Box::new(box.x, box.y, box.width, box.height - margin.top)
    }

    if margin.bottom > 0.0 {
      for edge in graph.edges {
        let edge_id = match edge_id_by_index.get(edge.index) {
          Some(v) => v
          None => continue
        }
        let route = match routes_by_edge_id.get(edge_id) {
          Some(v) => v
          None => continue
        }
        if route.is_empty() {
          continue
        }
        let last = route.length() - 1
        let bottom_y = box.y + box.height
        if edge.src_id == obj.id && route[0].y == bottom_y {
          route[0] = @graph.Point::new(route[0].x, route[0].y - margin.bottom)
        }
        if edge.dst_id == obj.id && route[last].y == bottom_y {
          route[last] = @graph.Point::new(
            route[last].x,
            route[last].y - margin.bottom,
          )
        }
      }
      shift_descendant_boxes(
        node_box_by_id,
        child_ids_by_id,
        obj.id,
        0.0,
        -margin.bottom / 2.0,
      )
      box = @graph.Box::new(box.x, box.y, box.width, box.height - margin.bottom)
    }

    node_box_by_id[obj.id] = box
  }
}

///|
fn shift_descendant_boxes(
  node_box_by_id : Map[String, @graph.Box],
  child_ids_by_id : Map[String, Array[String]],
  parent_id : String,
  dx : Double,
  dy : Double,
) -> Unit {
  let child_ids = match child_ids_by_id.get(parent_id) {
    Some(v) => v
    None => return
  }
  for child_id in child_ids {
    match node_box_by_id.get(child_id) {
      Some(child_box) =>
        node_box_by_id[child_id] = @graph.Box::new(
          child_box.x + dx,
          child_box.y + dy,
          child_box.width,
          child_box.height,
        )
      None => ()
    }
    shift_descendant_boxes(node_box_by_id, child_ids_by_id, child_id, dx, dy)
  }
}

///|
fn build_object_maps(
  graph : @graph.GraphInput,
) -> (Map[String, @graph.ObjectInput], Map[String, String]) {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.id] = graph.root
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }

  let parent_id_by_child_id : Map[String, String] = {}
  for child_id in graph.root.child_ids {
    parent_id_by_child_id[child_id] = graph.root.id
  }
  for obj in graph.objects {
    for child_id in obj.child_ids {
      parent_id_by_child_id[child_id] = obj.id
    }
  }

  (object_by_id, parent_id_by_child_id)
}

///|
fn build_excluded_layout_node_ids(
  graph : @graph.GraphInput,
  parent_id_by_child_id : Map[String, String],
  object_by_id : Map[String, @graph.ObjectInput],
) -> Map[String, Bool] {
  let excluded : Map[String, Bool] = {}
  let constant_near_root_ids : Array[String] = []
  for obj in graph.objects {
    if @graph.syntax_path_depth(obj.id) != 1 {
      continue
    }
    match obj.near {
      Some(raw) => {
        let key = raw.to_lower()
        if is_constant_near_key(key) {
          constant_near_root_ids.push(obj.id)
        }
      }
      None => ()
    }
  }
  for obj in graph.objects {
    if is_sql_or_class_member_node(obj.id, parent_id_by_child_id, object_by_id) {
      excluded[obj.id] = true
      continue
    }
    for near_root_id in constant_near_root_ids {
      if obj.id == near_root_id || obj.id.has_prefix(near_root_id + ".") {
        excluded[obj.id] = true
        break
      }
    }
  }
  excluded
}

///|
fn apply_constant_near_positions(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  let near_key_by_id : Map[String, String] = {}
  for obj in graph.objects {
    if @graph.syntax_path_depth(obj.id) != 1 {
      continue
    }
    match obj.near {
      Some(raw) => {
        let key = raw.to_lower()
        if is_constant_near_key(key) {
          near_key_by_id[obj.id] = key
        }
      }
      None => ()
    }
  }
  if near_key_by_id.is_empty() {
    return
  }

  let placed_near : Map[String, Bool] = {}
  for key_set in [0, 1, 2] {
    let current_set_ids : Array[String] = []
    for obj in graph.objects {
      let near_key = match near_key_by_id.get(obj.id) {
        Some(v) => v
        None => continue
      }
      if !near_key_matches_set(near_key, key_set) {
        continue
      }
      let box = match patch.nodes.get(obj.id) {
        Some(v) => v
        None => continue
      }
      let bounds = near_bounding_box(patch, graph, near_key_by_id, placed_near)
      let min_x = bounds.0
      let min_y = bounds.1
      let max_x = bounds.2
      let max_y = bounds.3
      let width = max_x - min_x
      let height = max_y - min_y
      let (x, y) = place_constant_near_box(
        obj,
        near_key,
        min_x,
        min_y,
        width,
        height,
        box.width,
        box.height,
      )
      let dx = x - box.x
      let dy = y - box.y
      shift_constant_near_subtree(patch, graph, obj.id, dx, dy)
      current_set_ids.push(obj.id)
    }
    for id in current_set_ids {
      placed_near[id] = true
    }
  }
  reroute_constant_near_cross_edges(patch, graph, near_key_by_id)
  clip_patch_routes_after_constant_near(patch, graph)
}

///|
fn apply_root_grid_positions_like_d2(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  if graph.root.grid_rows is None && graph.root.grid_columns is None {
    return
  }
  let root_child_ids = graph.root.child_ids
  if root_child_ids.is_empty() {
    return
  }

  let (object_by_id, parent_id_by_child_id) = build_object_maps(graph)
  let child_size_by_id : Map[String, (Double, Double)] = {}
  for child_id in root_child_ids {
    guard object_by_id.contains(child_id) else { return }
    match patch.nodes.get(child_id) {
      Some(box) => child_size_by_id[child_id] = (box.width, box.height)
      None => return
    }
  }

  let child_boxes = match
    @engine_api.estimate_root_grid_child_boxes(
      graph.root,
      root_child_ids,
      child_size_by_id,
    ) {
    Some(v) => v
    None => return
  }

  for child_id in root_child_ids {
    let new_box = match child_boxes.get(child_id) {
      Some(v) => v
      None => continue
    }
    let old_box = match patch.nodes.get(child_id) {
      Some(v) => v
      None => continue
    }
    let dx = new_box.x - old_box.x
    let dy = new_box.y - old_box.y
    if approx_eq(dx, 0.0) && approx_eq(dy, 0.0) {
      continue
    }
    patch.nodes[child_id] = new_box
    match patch.node_labels.get(child_id) {
      Some(label_box) =>
        patch.node_labels[child_id] = shift_box(label_box, dx, dy)
      None => ()
    }
    shift_root_grid_subtree(
      patch, graph, child_id, dx, dy, parent_id_by_child_id,
    )
  }

  reroute_root_grid_cross_edges(
    patch, graph, object_by_id, parent_id_by_child_id,
  )
  clip_patch_routes_after_constant_near(patch, graph)
}

///|
fn shift_root_grid_subtree(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  root_child_id : String,
  dx : Double,
  dy : Double,
  parent_id_by_child_id : Map[String, String],
) -> Unit {
  if approx_eq(dx, 0.0) && approx_eq(dy, 0.0) {
    return
  }
  for obj in graph.objects {
    if obj.id == root_child_id ||
      !is_inside_root_grid_subtree(obj.id, root_child_id, parent_id_by_child_id) {
      continue
    }
    match patch.nodes.get(obj.id) {
      Some(box) => patch.nodes[obj.id] = shift_box(box, dx, dy)
      None => ()
    }
    match patch.node_labels.get(obj.id) {
      Some(label_box) =>
        patch.node_labels[obj.id] = shift_box(label_box, dx, dy)
      None => ()
    }
  }
  for edge in graph.edges {
    if !belongs_to_root_grid_subtree(
        edge.src_id,
        root_child_id,
        parent_id_by_child_id,
      ) ||
      !belongs_to_root_grid_subtree(
        edge.dst_id,
        root_child_id,
        parent_id_by_child_id,
      ) {
      continue
    }
    match patch.edges.get(edge.index) {
      Some(route) => patch.edges[edge.index] = shift_route(route, dx, dy)
      None => ()
    }
    match patch.edge_bend_points.get(edge.index) {
      Some(bend_points) =>
        patch.edge_bend_points[edge.index] = shift_route(bend_points, dx, dy)
      None => ()
    }
  }
}

///|
fn reroute_root_grid_cross_edges(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> Unit {
  let root_child_ids : Map[String, Bool] = {}
  for child_id in graph.root.child_ids {
    root_child_ids[child_id] = true
  }
  let node_ids : Map[String, Bool] = {}
  for id, _ in patch.nodes {
    node_ids[id] = true
  }
  for edge in graph.edges {
    let src_root = root_grid_owner_id(
      edge.src_id,
      root_child_ids,
      parent_id_by_child_id,
    )
    let dst_root = root_grid_owner_id(
      edge.dst_id,
      root_child_ids,
      parent_id_by_child_id,
    )
    let needs_reroute = match (src_root, dst_root) {
      (Some(src_id), Some(dst_id)) => src_id != dst_id
      _ => false
    }
    if !needs_reroute {
      continue
    }
    let src_id = match
      resolve_edge_endpoint_id(
        edge.src_id,
        node_ids,
        object_by_id,
        parent_id_by_child_id,
      ) {
      Some(id) => id
      None => continue
    }
    let dst_id = match
      resolve_edge_endpoint_id(
        edge.dst_id,
        node_ids,
        object_by_id,
        parent_id_by_child_id,
      ) {
      Some(id) => id
      None => continue
    }
    let src_box = match patch.nodes.get(src_id) {
      Some(box) => box
      None => continue
    }
    let dst_box = match patch.nodes.get(dst_id) {
      Some(box) => box
      None => continue
    }
    patch.edges[edge.index] = [src_box.center(), dst_box.center()]
    patch.edge_bend_points.remove(edge.index)
    patch.edge_curves[edge.index] = false
  }
}

///|
fn belongs_to_root_grid_subtree(
  obj_id : String,
  root_child_id : String,
  parent_id_by_child_id : Map[String, String],
) -> Bool {
  obj_id == root_child_id ||
  is_inside_root_grid_subtree(obj_id, root_child_id, parent_id_by_child_id)
}

///|
fn is_inside_root_grid_subtree(
  obj_id : String,
  root_child_id : String,
  parent_id_by_child_id : Map[String, String],
) -> Bool {
  let mut current = obj_id
  while true {
    let parent_id = match parent_id_by_child_id.get(current) {
      Some(v) => v
      None => return false
    }
    if parent_id == root_child_id {
      return true
    }
    current = parent_id
  }
  false
}

///|
fn root_grid_owner_id(
  obj_id : String,
  root_child_ids : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
) -> String? {
  if root_child_ids.contains(obj_id) {
    return Some(obj_id)
  }
  let mut current = obj_id
  while true {
    let parent_id = match parent_id_by_child_id.get(current) {
      Some(v) => v
      None => return None
    }
    if root_child_ids.contains(parent_id) {
      return Some(parent_id)
    }
    current = parent_id
  }
  None
}

///|
fn shift_constant_near_subtree(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  near_id : String,
  dx : Double,
  dy : Double,
) -> Unit {
  if approx_eq(dx, 0.0) && approx_eq(dy, 0.0) {
    return
  }
  for obj in graph.objects {
    if !is_inside_constant_near_subtree(obj.id, near_id) {
      continue
    }
    match patch.nodes.get(obj.id) {
      Some(box) => patch.nodes[obj.id] = shift_box(box, dx, dy)
      None => ()
    }
    match patch.node_labels.get(obj.id) {
      Some(label_box) =>
        patch.node_labels[obj.id] = shift_box(label_box, dx, dy)
      None => ()
    }
  }
  for edge in graph.edges {
    if !is_inside_constant_near_subtree(edge.src_id, near_id) ||
      !is_inside_constant_near_subtree(edge.dst_id, near_id) {
      continue
    }
    match patch.edges.get(edge.index) {
      Some(route) => patch.edges[edge.index] = shift_route(route, dx, dy)
      None => ()
    }
    match patch.edge_bend_points.get(edge.index) {
      Some(bend_points) =>
        patch.edge_bend_points[edge.index] = shift_route(bend_points, dx, dy)
      None => ()
    }
  }
}

///|
fn reroute_constant_near_cross_edges(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  near_key_by_id : Map[String, String],
) -> Unit {
  let node_ids : Map[String, Bool] = {}
  for id, _ in patch.nodes {
    node_ids[id] = true
  }
  let (object_by_id, parent_id_by_child_id) = build_object_maps(graph)
  for edge in graph.edges {
    let src_near = outer_constant_near_id(edge.src_id, near_key_by_id)
    let dst_near = outer_constant_near_id(edge.dst_id, near_key_by_id)
    let needs_reroute = match (src_near, dst_near) {
      (Some(src_id), Some(dst_id)) => src_id != dst_id
      (Some(_), None) | (None, Some(_)) => true
      (None, None) => false
    }
    if !needs_reroute {
      continue
    }
    let src_id = match
      resolve_edge_endpoint_id(
        edge.src_id,
        node_ids,
        object_by_id,
        parent_id_by_child_id,
      ) {
      Some(id) => id
      None => continue
    }
    let dst_id = match
      resolve_edge_endpoint_id(
        edge.dst_id,
        node_ids,
        object_by_id,
        parent_id_by_child_id,
      ) {
      Some(id) => id
      None => continue
    }
    let src_box = match patch.nodes.get(src_id) {
      Some(box) => box
      None => continue
    }
    let dst_box = match patch.nodes.get(dst_id) {
      Some(box) => box
      None => continue
    }
    patch.edges[edge.index] = [src_box.center(), dst_box.center()]
    patch.edge_bend_points.remove(edge.index)
    patch.edge_curves[edge.index] = false
  }
}

///|
fn clip_patch_routes_after_constant_near(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  let edge_endpoints_by_index = build_patch_edge_endpoints_by_index(
    graph, patch,
  )
  trace_route_endpoints_like_d2(
    patch.edges,
    graph,
    edge_endpoints_by_index,
    patch.nodes,
  )
}

///|
fn build_patch_edge_endpoints_by_index(
  graph : @graph.GraphInput,
  patch : @graph.LayoutPatch,
) -> Map[Int, (String, String)] {
  let node_ids : Map[String, Bool] = {}
  for id, _ in patch.nodes {
    node_ids[id] = true
  }
  let (object_by_id, parent_id_by_child_id) = build_object_maps(graph)
  let edge_endpoints_by_index : Map[Int, (String, String)] = {}
  for edge in graph.edges {
    let src_id = match
      resolve_edge_endpoint_id(
        edge.src_id,
        node_ids,
        object_by_id,
        parent_id_by_child_id,
      ) {
      Some(id) => id
      None => continue
    }
    let dst_id = match
      resolve_edge_endpoint_id(
        edge.dst_id,
        node_ids,
        object_by_id,
        parent_id_by_child_id,
      ) {
      Some(id) => id
      None => continue
    }
    edge_endpoints_by_index[edge.index] = (src_id, dst_id)
  }
  edge_endpoints_by_index
}

///|
fn outer_constant_near_id(
  obj_id : String,
  near_key_by_id : Map[String, String],
) -> String? {
  for near_id, _ in near_key_by_id {
    if is_inside_constant_near_subtree(obj_id, near_id) {
      return Some(near_id)
    }
  }
  None
}

///|
fn is_inside_constant_near_subtree(obj_id : String, near_id : String) -> Bool {
  obj_id == near_id || obj_id.has_prefix(near_id + ".")
}

///|
fn shift_box(box : @graph.Box, dx : Double, dy : Double) -> @graph.Box {
  @graph.Box::new(box.x + dx, box.y + dy, box.width, box.height)
}

///|
fn shift_route(
  route : Array[@graph.Point],
  dx : Double,
  dy : Double,
) -> Array[@graph.Point] {
  let shifted : Array[@graph.Point] = []
  for point in route {
    shifted.push(@graph.Point::new(point.x + dx, point.y + dy))
  }
  shifted
}

///|
fn is_constant_near_key(key : String) -> Bool {
  match key {
    "top-left"
    | "top-center"
    | "top-right"
    | "center-left"
    | "center-right"
    | "bottom-left"
    | "bottom-center"
    | "bottom-right" => true
    _ => false
  }
}

///|
fn near_key_matches_set(key : String, key_set : Int) -> Bool {
  match key_set {
    0 => key == "top-center" || key == "bottom-center"
    1 => key == "center-left" || key == "center-right"
    _ =>
      key == "top-left" ||
      key == "top-right" ||
      key == "bottom-left" ||
      key == "bottom-right"
  }
}

///|
fn near_bounding_box(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  near_key_by_id : Map[String, String],
  placed_near : Map[String, Bool],
) -> (Double, Double, Double, Double) {
  let mut min_x = 1000000000000.0
  let mut min_y = 1000000000000.0
  let mut max_x = -1000000000000.0
  let mut max_y = -1000000000000.0
  let mut has_bounds = false

  for obj in graph.objects {
    let box = match patch.nodes.get(obj.id) {
      Some(v) => v
      None => continue
    }
    match near_key_by_id.get(obj.id) {
      Some(near_key) => {
        if !placed_near.contains(obj.id) {
          continue
        }
        // Top/bottom-center objects expand only X bounds; left/right-center only Y.
        match near_key {
          "top-center" | "bottom-center" => {
            min_x = if box.x < min_x { box.x } else { min_x }
            max_x = if box.x + box.width > max_x {
              box.x + box.width
            } else {
              max_x
            }
            has_bounds = true
          }
          "center-left" | "center-right" => {
            min_y = if box.y < min_y { box.y } else { min_y }
            max_y = if box.y + box.height > max_y {
              box.y + box.height
            } else {
              max_y
            }
            has_bounds = true
          }
          _ => ()
        }
      }
      None => {
        if has_outer_near_container(obj.id, near_key_by_id) {
          continue
        }
        min_x = if box.x < min_x { box.x } else { min_x }
        min_y = if box.y < min_y { box.y } else { min_y }
        max_x = if box.x + box.width > max_x {
          box.x + box.width
        } else {
          max_x
        }
        max_y = if box.y + box.height > max_y {
          box.y + box.height
        } else {
          max_y
        }
        has_bounds = true
      }
    }
  }

  for edge in graph.edges {
    if has_outer_near_container(edge.src_id, near_key_by_id) ||
      has_outer_near_container(edge.dst_id, near_key_by_id) {
      continue
    }
    let route = match patch.edges.get(edge.index) {
      Some(v) => v
      None => continue
    }
    for point in route {
      min_x = if point.x < min_x { point.x } else { min_x }
      min_y = if point.y < min_y { point.y } else { min_y }
      max_x = if point.x > max_x { point.x } else { max_x }
      max_y = if point.y > max_y { point.y } else { max_y }
      has_bounds = true
    }
  }

  if !has_bounds {
    return (0.0, 0.0, 0.0, 0.0)
  }

  if min_x > max_x {
    min_x = 0.0
    max_x = 0.0
  }
  if min_y > max_y {
    min_y = 0.0
    max_y = 0.0
  }
  (min_x, min_y, max_x, max_y)
}

///|
fn has_outer_near_container(
  obj_id : String,
  near_key_by_id : Map[String, String],
) -> Bool {
  for near_id, _ in near_key_by_id {
    if obj_id == near_id || obj_id.has_prefix(near_id + ".") {
      return true
    }
  }
  false
}

///|
fn place_constant_near_box(
  obj : @graph.ObjectInput,
  near_key : String,
  min_x : Double,
  min_y : Double,
  width : Double,
  height : Double,
  box_width : Double,
  box_height : Double,
) -> (Double, Double) {
  let (x, y) = match near_key {
    "top-left" =>
      (min_x - box_width - D2_NEAR_PAD, min_y - box_height - D2_NEAR_PAD)
    "top-center" =>
      (min_x + width / 2.0 - box_width / 2.0, min_y - box_height - D2_NEAR_PAD)
    "top-right" =>
      (min_x + width + D2_NEAR_PAD, min_y - box_height - D2_NEAR_PAD)
    "center-left" =>
      (min_x - box_width - D2_NEAR_PAD, min_y + height / 2.0 - box_height / 2.0)
    "center-right" =>
      (min_x + width + D2_NEAR_PAD, min_y + height / 2.0 - box_height / 2.0)
    "bottom-left" =>
      (min_x - box_width - D2_NEAR_PAD, min_y + height + D2_NEAR_PAD)
    "bottom-center" =>
      (min_x + width / 2.0 - box_width / 2.0, min_y + height + D2_NEAR_PAD)
    "bottom-right" =>
      (min_x + width + D2_NEAR_PAD, min_y + height + D2_NEAR_PAD)
    _ => (min_x, min_y)
  }
  adjust_constant_near_for_label(obj, near_key, x, y)
}

///|
fn adjust_constant_near_for_label(
  obj : @graph.ObjectInput,
  near_key : String,
  x : Double,
  y : Double,
) -> (Double, Double) {
  let label_position = match obj.label_position {
    Some(v) => v
    None => return (x, y)
  }
  if label_position.contains("INSIDE") {
    return (x, y)
  }
  let (label_width, label_height) = match object_label_dimensions(obj) {
    Some(v) => v
    None => return (x, y)
  }
  let x = x
  let y = y
  if label_position.contains("_TOP_") {
    if near_key.contains("bottom") {
      (x, y + label_height)
    } else {
      (x, y)
    }
  } else if label_position.contains("_LEFT_") {
    if near_key.contains("right") {
      (x + label_width, y)
    } else {
      (x, y)
    }
  } else if label_position.contains("_RIGHT_") {
    if near_key.contains("left") {
      (x - label_width, y)
    } else {
      (x, y)
    }
  } else if label_position.contains("_BOTTOM_") {
    if near_key.contains("top") {
      (x, y - label_height)
    } else {
      (x, y)
    }
  } else {
    (x, y)
  }
}

///|
fn build_endpoint_degree_counts(
  graph : @graph.GraphInput,
  excluded_node_ids : Map[String, Bool],
) -> Map[String, (Int, Int)] {
  let counts : Map[String, (Int, Int)] = {}
  for edge in graph.edges {
    let src_id = edge.src_id
    let dst_id = edge.dst_id

    if !excluded_node_ids.contains(src_id) {
      let (incoming, outgoing) = match counts.get(src_id) {
        Some(v) => v
        None => (0, 0)
      }
      counts[src_id] = (incoming, outgoing + 1)
    }
    if !excluded_node_ids.contains(dst_id) {
      let (incoming, outgoing) = match counts.get(dst_id) {
        Some(v) => v
        None => (0, 0)
      }
      counts[dst_id] = (incoming + 1, outgoing)
    }
  }
  counts
}

///|
fn apply_multi_edge_min_size_like_d2(
  obj : @graph.ObjectInput,
  direction : @engine_api.Direction,
  width : Double,
  height : Double,
  incoming : Int,
  outgoing : Int,
) -> (Double, Double) {
  let mut adjusted_width = width
  let mut adjusted_height = height
  if incoming >= 2 || outgoing >= 2 {
    let max_degree = if incoming > outgoing { incoming } else { outgoing }
    let required_size = max_degree.to_double() * D2_PORT_SPACING
    match direction {
      @engine_api.Right | @engine_api.Left =>
        if !has_explicit_object_height(obj) && adjusted_height < required_size {
          adjusted_height = required_size
        }
      _ =>
        if !has_explicit_object_width(obj) && adjusted_width < required_size {
          adjusted_width = required_size
        }
    }
  }
  (adjusted_width, adjusted_height)
}

///|
fn apply_label_icon_height_boost_like_d2(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
  width : Double,
  height : Double,
) -> (Double, Double) {
  if obj.label != "" && obj.icon is Some(_) && obj.shape_type != @graph.Image {
    (width, height + label_height(obj, config) + D2_LABEL_PADDING)
  } else {
    (width, height)
  }
}

///|
fn has_explicit_object_width(obj : @graph.ObjectInput) -> Bool {
  match obj.box {
    Some(box) => box.width > 0.0
    None => false
  }
}

///|
fn has_explicit_object_height(obj : @graph.ObjectInput) -> Bool {
  match obj.box {
    Some(box) => box.height > 0.0
    None => false
  }
}

///|
fn is_sql_or_class_member_node(
  id : String,
  parent_id_by_child_id : Map[String, String],
  object_by_id : Map[String, @graph.ObjectInput],
) -> Bool {
  let parent_id = match parent_id_by_child_id.get(id) {
    Some(v) => v
    None => return false
  }
  let parent = match object_by_id.get(parent_id) {
    Some(v) => v
    None => return false
  }
  parent.shape_type == @graph.SqlTable || parent.shape_type == @graph.Class
}

///|
fn has_layout_children(
  obj : @graph.ObjectInput,
  excluded_node_ids : Map[String, Bool],
) -> Bool {
  for child_id in obj.child_ids {
    if !excluded_node_ids.contains(child_id) {
      return true
    }
  }
  false
}

///|
fn build_sql_table_ports(
  obj : @graph.ObjectInput,
  direction : @engine_api.Direction,
  height : Double,
) -> Array[Json] {
  if obj.child_ids.is_empty() {
    return []
  }
  let ports : Array[Json] = []
  let row_height = height / (obj.child_ids.length().to_double() + 1.0)
  let (src_side, dst_side) = sql_table_port_sides(direction)
  for i, child_id in obj.child_ids {
    let column_name = short_name_from_id(child_id)
    let row_center = (i + 1).to_double() * row_height + row_height / 2.0
    ports.push(
      sql_port_json(
        sql_column_src_port_id(obj.id, column_name),
        row_center,
        src_side,
      ),
    )
    ports.push(
      sql_port_json(
        sql_column_dst_port_id(obj.id, column_name),
        row_center,
        dst_side,
      ),
    )
  }
  ports
}

///|
fn sql_table_port_sides(direction : @engine_api.Direction) -> (String, String) {
  match direction {
    @engine_api.Left => ("WEST", "EAST")
    _ => ("EAST", "WEST")
  }
}

///|
fn sql_port_json(id : String, y : Double, side : String) -> Json {
  Json::object({
    "id": Json::string(id),
    "y": Json::number(y),
    "layoutOptions": Json::object({ "elk.port.side": Json::string(side) }),
  })
}

///|
fn sql_column_src_port_id(table_id : String, column_name : String) -> String {
  "\{table_id}.\{column_name}.src"
}

///|
fn sql_column_dst_port_id(table_id : String, column_name : String) -> String {
  "\{table_id}.\{column_name}.dst"
}

///|
fn sql_column_name_by_index(
  obj : @graph.ObjectInput,
  column_index : Int,
) -> String {
  if column_index >= 0 && column_index < obj.child_ids.length() {
    short_name_from_id(obj.child_ids[column_index])
  } else {
    "__col\{column_index}"
  }
}

///|
fn edge_endpoint_with_sql_port(
  column_index : Int?,
  resolved_id : String,
  is_source : Bool,
  edge_order_index : Int,
  default_side : String,
  object_by_id : Map[String, @graph.ObjectInput],
  node_json_by_id : Map[String, Map[String, Json]],
  sql_root_port_ids_by_group : Map[String, Array[String]],
) -> String {
  let endpoint_obj = match object_by_id.get(resolved_id) {
    Some(v) => v
    None => return resolved_id
  }
  if endpoint_obj.shape_type != @graph.SqlTable {
    return resolved_id
  }
  match column_index {
    Some(i) => {
      let column_name = sql_column_name_by_index(endpoint_obj, i)
      if is_source {
        sql_column_src_port_id(resolved_id, column_name)
      } else {
        sql_column_dst_port_id(resolved_id, column_name)
      }
    }
    None => {
      let root_column = "__root__"
      let root_prefix = if is_source {
        sql_column_src_port_id(resolved_id, root_column)
      } else {
        sql_column_dst_port_id(resolved_id, root_column)
      }
      let root_port_id = if is_source {
        "\{root_prefix}.\{edge_order_index}"
      } else {
        "\{root_prefix}.\{edge_order_index}"
      }
      match node_json_by_id.get(resolved_id) {
        Some(node_json) => {
          let ports = json_array_field(node_json, "ports")
          ports.push(sql_port_json(root_port_id, 0.0, default_side))
          node_json["ports"] = Json::array(ports)
          node_json_by_id[resolved_id] = node_json
        }
        None => ()
      }
      let group_key = sql_root_port_group_key(resolved_id, default_side)
      let group = match sql_root_port_ids_by_group.get(group_key) {
        Some(v) => v
        None => []
      }
      group.push(root_port_id)
      sql_root_port_ids_by_group[group_key] = group
      root_port_id
    }
  }
}

///|
fn sql_root_port_sides(direction : @engine_api.Direction) -> (String, String) {
  match direction {
    @engine_api.Up => ("NORTH", "SOUTH")
    _ => ("SOUTH", "NORTH")
  }
}

///|
fn sql_root_port_group_key(obj_id : String, side : String) -> String {
  "\{obj_id}\u0000\{side}"
}

///|
fn sql_root_port_group_obj_id(group_key : String) -> String {
  let parts = group_key.split("\u0000").collect()
  if parts.is_empty() {
    group_key
  } else {
    parts[0].to_string()
  }
}

///|
fn assign_sql_root_port_x_positions(
  node_json_by_id : Map[String, Map[String, Json]],
  sql_root_port_ids_by_group : Map[String, Array[String]],
) -> Unit {
  let port_x_by_id : Map[String, Double] = {}
  for group_key, port_ids in sql_root_port_ids_by_group {
    if port_ids.is_empty() {
      continue
    }
    let obj_id = sql_root_port_group_obj_id(group_key)
    let node_json = match node_json_by_id.get(obj_id) {
      Some(v) => v
      None => continue
    }
    let width = json_double_field(node_json, "width", 0.0)
    if width <= 0.0 {
      continue
    }
    let spacing = width / (port_ids.length().to_double() + 1.0)
    for i, port_id in port_ids {
      port_x_by_id[port_id] = (i + 1).to_double() * spacing
    }
  }

  for obj_id, node_json in node_json_by_id {
    let ports = json_array_field(node_json, "ports")
    if ports.is_empty() {
      continue
    }
    let rewritten_ports : Array[Json] = []
    for port_json in ports {
      let mut out_port = port_json
      match port_json {
        Object(port_obj) =>
          match json_id_field(port_obj) {
            Some(port_id) =>
              match port_x_by_id.get(port_id) {
                Some(x) => {
                  port_obj["x"] = Json::number(x)
                  out_port = Json::object(port_obj)
                }
                None => ()
              }
            None => ()
          }
        _ => ()
      }
      rewritten_ports.push(out_port)
    }
    node_json["ports"] = Json::array(rewritten_ports)
    node_json_by_id[obj_id] = node_json
  }
}

///|
fn fill_patch_nodes(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  node_box_by_id : Map[String, @graph.Box],
  node_size_by_id : Map[String, (Double, Double)],
  config : @engine_api.LayoutConfig,
) -> Unit {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.id] = graph.root
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  for obj in graph.objects {
    let node_box = match node_box_by_id.get(obj.id) {
      Some(box) => box
      None => {
        let (width, height) = match node_size_by_id.get(obj.id) {
          Some(v) => v
          None => object_size(obj, config, object_by_id)
        }
        object_fallback_box(obj, width, height)
      }
    }
    patch.nodes[obj.id] = node_box
    match object_default_label_box(obj, node_box) {
      Some(label_box) => patch.node_labels[obj.id] = label_box
      None => ()
    }
  }
}

///|
fn fill_patch_edges(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  edge_id_by_index : Map[Int, String],
  edge_endpoints_by_index : Map[Int, (String, String)],
  node_box_by_id : Map[String, @graph.Box],
  routes_by_edge_id : Map[String, Array[@graph.Point]],
  direction : @engine_api.Direction,
) -> Unit {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.id] = graph.root
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }

  let routes_by_index : Map[Int, Array[@graph.Point]] = {}

  for edge in graph.edges {
    let mut route : Array[@graph.Point] = []
    let mut from_fallback = false

    match edge_id_by_index.get(edge.index) {
      Some(edge_id) =>
        match routes_by_edge_id.get(edge_id) {
          Some(points) => route = points
          None => ()
        }
      None => ()
    }

    if route.length() < 2 {
      match edge_endpoints_by_index.get(edge.index) {
        Some((src_id, dst_id)) =>
          route = fallback_route_from_boxes(
            node_box_by_id, object_by_id, src_id, dst_id, direction,
          )
        None => ()
      }
      from_fallback = true
    }

    if route.length() < 2 {
      route = edge.route
    }

    if route.length() < 2 {
      continue
    }

    if from_fallback {
      match edge_endpoints_by_index.get(edge.index) {
        Some((src_id, dst_id)) =>
          route = clip_route_endpoints(
            route, node_box_by_id, object_by_id, src_id, dst_id,
          )
        None => ()
      }
    }

    routes_by_index[edge.index] = route
  }

  trace_route_endpoints_like_d2(
    routes_by_index, graph, edge_endpoints_by_index, node_box_by_id,
  )
  delete_bends_like_d2(routes_by_index, graph, node_box_by_id)

  for edge in graph.edges {
    let route = match routes_by_index.get(edge.index) {
      Some(points) => points
      None => continue
    }

    patch.edges[edge.index] = route
    patch.edge_curves[edge.index] = false

    match edge_label_size(edge) {
      Some((label_w, label_h)) => {
        let center = route_point_at_percent(route, 0.5)
        patch.edge_labels[edge.index] = @graph.Box::new(
          center.x - label_w / 2.0,
          center.y - label_h / 2.0,
          label_w,
          label_h,
        )
      }
      None => ()
    }
  }
}

///|
fn trace_route_endpoints_like_d2(
  routes_by_index : Map[Int, Array[@graph.Point]],
  graph : @graph.GraphInput,
  edge_endpoints_by_index : Map[Int, (String, String)],
  node_box_by_id : Map[String, @graph.Box],
) -> Unit {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.id] = graph.root
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }

  for edge in graph.edges {
    let route = match routes_by_index.get(edge.index) {
      Some(v) => v
      None => continue
    }
    if route.length() < 2 {
      continue
    }
    let (src_id, dst_id) = match edge_endpoints_by_index.get(edge.index) {
      Some(v) => v
      None => continue
    }
    let src_box = match node_box_by_id.get(src_id) {
      Some(v) => v
      None => continue
    }
    let dst_box = match node_box_by_id.get(dst_id) {
      Some(v) => v
      None => continue
    }

    let src_obj = match object_by_id.get(src_id) {
      Some(v) => v
      None => continue
    }
    let dst_obj = match object_by_id.get(dst_id) {
      Some(v) => v
      None => continue
    }

    let points : Array[@graph.Point] = []
    for p in route {
      points.push(p)
    }
    let mut start_index = 0
    let mut end_index = points.length() - 1

    let mut trace_src_box = src_box
    let mut trace_dst_box = dst_box
    let (src_dx, src_dy) = modifier_element_adjustments(src_obj)
    if (src_dx != 0.0 || src_dy != 0.0) && start_index <= end_index {
      let start = points[start_index]
      if start.x > src_box.x + src_dx &&
        start.y < src_box.y + src_box.height - src_dy {
        trace_src_box = @graph.Box::new(
          src_box.x + src_dx,
          src_box.y - src_dy,
          src_box.width,
          src_box.height,
        )
      }
    }
    let (dst_dx, dst_dy) = modifier_element_adjustments(dst_obj)
    if (dst_dx != 0.0 || dst_dy != 0.0) && start_index <= end_index {
      let end = points[end_index]
      if end.x > dst_box.x + dst_dx &&
        end.y < dst_box.y + dst_box.height - dst_dy {
        trace_dst_box = @graph.Box::new(
          dst_box.x + dst_dx,
          dst_box.y - dst_dy,
          dst_box.width,
          dst_box.height,
        )
      }
    }

    let mut overlaps_src_outside_label = false
    if start_index + 1 <= end_index {
      match outside_label_box(src_obj, src_box) {
        Some((label_box, pos)) => {
          let intersections = box_intersections(
            label_box,
            points[start_index + 1],
            points[start_index],
          )
          if !intersections.is_empty() {
            overlaps_src_outside_label = true
            points[start_index] = pick_outside_intersection(pos, intersections)
            if start_index + 1 < end_index &&
              point_distance(points[start_index], points[start_index + 1]) <
              D2_MIN_SEGMENT_LEN {
              points[start_index + 1] = points[start_index]
              start_index = start_index + 1
            }
          }
        }
        None => ()
      }
    }

    if !overlaps_src_outside_label && start_index + 1 <= end_index {
      match
        first_box_intersection(
          trace_src_box,
          points[start_index + 1],
          points[start_index],
        ) {
        Some(hit) => {
          points[start_index] = hit
          if start_index + 1 < end_index &&
            point_distance(points[start_index], points[start_index + 1]) <
            D2_MIN_SEGMENT_LEN {
            points[start_index + 1] = points[start_index]
            start_index = start_index + 1
          }
        }
        None => ()
      }
      if start_index + 1 <= end_index {
        points[start_index] = trace_to_shape_border(
          src_obj.shape_type,
          trace_src_box,
          points[start_index],
          points[start_index + 1],
        )
      }
    }

    let mut overlaps_dst_outside_label = false
    if end_index >= 1 && end_index - 1 >= start_index {
      match outside_label_box(dst_obj, dst_box) {
        Some((label_box, pos)) => {
          let intersections = box_intersections(
            label_box,
            points[end_index - 1],
            points[end_index],
          )
          if !intersections.is_empty() {
            overlaps_dst_outside_label = true
            points[end_index] = pick_outside_intersection(pos, intersections)
            if end_index - 1 > start_index &&
              point_distance(points[end_index - 1], points[end_index]) <
              D2_MIN_SEGMENT_LEN {
              points[end_index - 1] = points[end_index]
              end_index = end_index - 1
            }
          }
        }
        None => ()
      }
    }

    if !overlaps_dst_outside_label &&
      end_index >= 1 &&
      end_index - 1 >= start_index {
      match
        first_box_intersection(
          trace_dst_box,
          points[end_index - 1],
          points[end_index],
        ) {
        Some(hit) => {
          points[end_index] = hit
          if end_index - 1 > start_index &&
            point_distance(points[end_index - 1], points[end_index]) <
            D2_MIN_SEGMENT_LEN {
            points[end_index - 1] = points[end_index]
            end_index = end_index - 1
          }
        }
        None => ()
      }
      if end_index >= 1 && end_index - 1 >= start_index {
        points[end_index] = trace_to_shape_border(
          dst_obj.shape_type,
          trace_dst_box,
          points[end_index],
          points[end_index - 1],
        )
      }
    }

    if end_index < start_index {
      continue
    }
    let traced : Array[@graph.Point] = []
    let mut i = start_index
    while i <= end_index {
      traced.push(points[i])
      i = i + 1
    }
    if traced.length() >= 2 {
      routes_by_index[edge.index] = traced
    }
  }
}

///|
fn is_rectangular_shape_like_d2(shape_type : @graph.ShapeType) -> Bool {
  shape_type == @graph.Rectangle ||
  shape_type == @graph.Square ||
  shape_type == @graph.SqlTable ||
  shape_type == @graph.Class ||
  shape_type == @graph.Text ||
  shape_type == @graph.Code ||
  shape_type == @graph.Image
}

///|
fn modifier_element_adjustments(obj : @graph.ObjectInput) -> (Double, Double) {
  if style_bool(obj.style.three_d, false) {
    (
      D2_THREE_DEE_OFFSET,
      if obj.shape_type == @graph.Hexagon {
        D2_THREE_DEE_OFFSET / 2.0
      } else {
        D2_THREE_DEE_OFFSET
      },
    )
  } else if style_bool(obj.style.multiple, false) {
    (D2_MULTIPLE_OFFSET, D2_MULTIPLE_OFFSET)
  } else {
    (0.0, 0.0)
  }
}

///|
fn first_box_intersection(
  box : @graph.Box,
  p0 : @graph.Point,
  p1 : @graph.Point,
) -> @graph.Point? {
  let tl = @graph.Point::new(box.x, box.y)
  let tr = @graph.Point::new(box.x + box.width, box.y)
  let br = @graph.Point::new(box.x + box.width, box.y + box.height)
  let bl = @graph.Point::new(box.x, box.y + box.height)
  match segment_segment_intersection(p0, p1, tl, tr) {
    Some(hit) => return Some(hit)
    None => ()
  }
  match segment_segment_intersection(p0, p1, tr, br) {
    Some(hit) => return Some(hit)
    None => ()
  }
  match segment_segment_intersection(p0, p1, br, bl) {
    Some(hit) => return Some(hit)
    None => ()
  }
  match segment_segment_intersection(p0, p1, bl, tl) {
    Some(hit) => return Some(hit)
    None => ()
  }
  None
}

///|
fn outside_label_box(
  obj : @graph.ObjectInput,
  box : @graph.Box,
) -> (@graph.Box, DefaultLabelPosition)? {
  if obj.shape_type == @graph.SqlTable || obj.shape_type == @graph.Class {
    return None
  }
  if obj.label == "" {
    return None
  }
  let (label_width, label_height) = match object_label_dimensions(obj) {
    Some(v) => v
    None => return None
  }
  let pos = default_label_position(
    obj,
    box,
    label_width + D2_LABEL_PADDING * 2.0,
    label_height + D2_LABEL_PADDING * 2.0,
  )
  let (x, y) = match pos {
    OutsideTop =>
      (
        box.x + (box.width - label_width) / 2.0,
        box.y - D2_LABEL_PADDING - label_height,
      )
    OutsideBottom =>
      (
        box.x + (box.width - label_width) / 2.0,
        box.y + box.height + D2_LABEL_PADDING,
      )
    _ => return None
  }
  Some(
    (
      @graph.Box::new(
        x - D2_LABEL_PADDING,
        y,
        label_width + D2_LABEL_PADDING * 2.0,
        label_height,
      ),
      pos,
    ),
  )
}

///|
fn box_intersections(
  box : @graph.Box,
  p0 : @graph.Point,
  p1 : @graph.Point,
) -> Array[@graph.Point] {
  let hits : Array[@graph.Point] = []
  let tl = @graph.Point::new(box.x, box.y)
  let tr = @graph.Point::new(box.x + box.width, box.y)
  let br = @graph.Point::new(box.x + box.width, box.y + box.height)
  let bl = @graph.Point::new(box.x, box.y + box.height)
  match segment_segment_intersection(p0, p1, tl, tr) {
    Some(hit) => hits.push(hit)
    None => ()
  }
  match segment_segment_intersection(p0, p1, tr, br) {
    Some(hit) => hits.push(hit)
    None => ()
  }
  match segment_segment_intersection(p0, p1, br, bl) {
    Some(hit) => hits.push(hit)
    None => ()
  }
  match segment_segment_intersection(p0, p1, bl, tl) {
    Some(hit) => hits.push(hit)
    None => ()
  }
  hits
}

///|
fn pick_outside_intersection(
  pos : DefaultLabelPosition,
  intersections : Array[@graph.Point],
) -> @graph.Point {
  if intersections.length() <= 1 {
    return intersections[0]
  }
  let mut best = intersections[0]
  for i in 1..<intersections.length() {
    let p = intersections[i]
    match pos {
      OutsideTop => if p.y < best.y { best = p }
      OutsideBottom => if p.y > best.y { best = p }
      _ => ()
    }
  }
  best
}

///|
fn copy_passthrough_layout_data(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  for fragment in graph.sequence_fragments_layout {
    patch.sequence_fragments.push(fragment)
  }
  for activation in graph.activation_boxes {
    patch.activation_boxes.push(activation)
  }
  for note in graph.sequence_notes {
    patch.sequence_notes.push(note)
  }
}

///|
fn make_root_layout_options(
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
  self_loop_spacing : Int,
) -> Map[String, Json] {
  let spacing = layout_node_spacing(config, direction)
  {
    "elk.algorithm": Json::string("layered"),
    "elk.direction": Json::string(elk_direction(direction)),
    "elk.hierarchyHandling": Json::string("INCLUDE_CHILDREN"),
    "elk.layered.nodePlacement.bk.fixedAlignment": Json::string("BALANCED"),
    "elk.layered.considerModelOrder.strategy": Json::string("NODES_AND_EDGES"),
    "elk.layered.cycleBreaking.strategy": Json::string("GREEDY_MODEL_ORDER"),
    "elk.layered.thoroughness": Json::number(8.0),
    "elk.layered.spacing.edgeEdgeBetweenLayers": Json::number(50.0),
    "elk.spacing.edgeNode": Json::number(40.0),
    "elk.nodeSize.constraints": Json::string("MINIMUM_SIZE"),
    "elk.contentAlignment": Json::string("H_CENTER V_CENTER"),
    "spacing.nodeNodeBetweenLayers": Json::number(spacing.to_double()),
    "spacing.edgeNodeBetweenLayers": Json::number(40.0),
    "elk.spacing.nodeSelfLoop": Json::number(self_loop_spacing.to_double()),
  }
}

///|
fn make_container_layout_options(
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
  width : Double,
  height : Double,
  self_loop_spacing : Int,
) -> Map[String, Json] {
  let spacing = layout_node_spacing(config, direction)
  let padding = layout_padding_value(config)
  {
    "elk.direction": Json::string(""),
    "elk.layered.crossingMinimization.forceNodeModelOrder": Json::boolean(true),
    "elk.hierarchyHandling": Json::string("INCLUDE_CHILDREN"),
    "elk.layered.nodePlacement.bk.fixedAlignment": Json::string("BALANCED"),
    "elk.layered.considerModelOrder.strategy": Json::string("NODES_AND_EDGES"),
    "elk.layered.cycleBreaking.strategy": Json::string("GREEDY_MODEL_ORDER"),
    "elk.layered.thoroughness": Json::number(8.0),
    "elk.layered.spacing.edgeEdgeBetweenLayers": Json::number(50.0),
    "elk.spacing.edgeNode": Json::number(40.0),
    "spacing.nodeNodeBetweenLayers": Json::number(spacing.to_double()),
    "spacing.edgeNodeBetweenLayers": Json::number(40.0),
    "elk.spacing.nodeSelfLoop": Json::number(self_loop_spacing.to_double()),
    "elk.nodeSize.constraints": Json::string("MINIMUM_SIZE"),
    "elk.nodeSize.minimum": Json::string(
      node_size_minimum(direction, width, height),
    ),
    "elk.contentAlignment": Json::string("H_CENTER V_CENTER"),
    "elk.padding": Json::string(
      "[top=\{padding},left=\{padding},bottom=\{padding},right=\{padding}]",
    ),
  }
}

///|
fn make_leaf_layout_options() -> Map[String, Json] {
  {
    "elk.direction": Json::string(""),
    "elk.layered.edgeRouting.selfLoopDistribution": Json::string("EQUALLY"),
    "elk.spacing.nodeSelfLoop": Json::number(0.0),
  }
}

///|
fn layout_node_spacing(
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> Int {
  let raw = match
    (direction, config.horizontal_spacing, config.vertical_spacing) {
    // Align default ELK spacing with d2 (70) while preserving explicit config overrides.
    (@engine_api.Down | @engine_api.Up, _, v) if approx_eq(v, 100.0) => 70.0
    (@engine_api.Right | @engine_api.Left, h, _) if approx_eq(h, 60.0) => 70.0
    (@engine_api.Down | @engine_api.Up, _, v) => v
    (@engine_api.Right | @engine_api.Left, h, _) => h
  }
  positive_int(raw, 70)
}

///|
fn layout_padding_value(config : @engine_api.LayoutConfig) -> Int {
  let raw = if approx_eq(config.container_padding, 40.0) {
    50.0
  } else {
    config.container_padding
  }
  positive_int(raw, 50)
}

///|
fn node_size_minimum(
  direction : @engine_api.Direction,
  width : Double,
  height : Double,
) -> String {
  let min_w = width.ceil().to_int()
  let min_h = height.ceil().to_int()
  match direction {
    @engine_api.Down | @engine_api.Up => "(\{min_h}, \{min_w})"
    @engine_api.Right | @engine_api.Left => "(\{min_w}, \{min_h})"
  }
}

///|
fn self_loop_spacing_for_parent(
  graph : @graph.GraphInput,
  child_ids : Array[String],
  direction : @engine_api.Direction,
) -> Int {
  let base = 50
  if child_ids.is_empty() {
    return base
  }
  let child_set : Map[String, Bool] = {}
  for child_id in child_ids {
    child_set[child_id] = true
  }
  let prefer_width = match direction {
    @engine_api.Down | @engine_api.Up => true
    @engine_api.Right | @engine_api.Left => false
  }
  let mut max_label = 0
  for edge in graph.edges {
    if edge.src_id != edge.dst_id {
      continue
    }
    if !child_set.contains(edge.src_id) || edge.label.is_empty() {
      continue
    }
    match edge_label_size(edge) {
      Some((w, h)) => {
        let candidate = if prefer_width {
          w.ceil().to_int()
        } else {
          h.ceil().to_int()
        }
        if candidate > max_label {
          max_label = candidate
        }
      }
      None => ()
    }
  }
  max_int(base, max_label / 2 + 5)
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn positive_int(value : Double, fallback : Int) -> Int {
  let rounded = value.round().to_int()
  if rounded > 0 {
    rounded
  } else {
    fallback
  }
}

///|
fn elk_direction(direction : @engine_api.Direction) -> String {
  match direction {
    @engine_api.Down => "DOWN"
    @engine_api.Right => "RIGHT"
    @engine_api.Up => "UP"
    @engine_api.Left => "LEFT"
  }
}

///|
fn resolve_edge_endpoint_id(
  id : String,
  node_ids : Map[String, Bool],
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> String? {
  let current = collapse_sql_or_class_endpoint_id(
    id, object_by_id, parent_id_by_child_id,
  )
  resolve_edge_endpoint_id_parent(current, node_ids, parent_id_by_child_id)
}

///|
fn resolve_edge_endpoint_id_parent(
  current : String,
  node_ids : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
) -> String? {
  if node_ids.contains(current) {
    return Some(current)
  }
  match parent_id_by_child_id.get(current) {
    Some(parent_id) =>
      resolve_edge_endpoint_id_parent(
        parent_id, node_ids, parent_id_by_child_id,
      )
    None => None
  }
}

///|
fn collapse_sql_or_class_endpoint_id(
  id : String,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> String {
  let mut current = id
  while true {
    let parent_id = match parent_id_by_child_id.get(current) {
      Some(v) => v
      None => break
    }
    let parent = match object_by_id.get(parent_id) {
      Some(v) => v
      None => break
    }
    if parent.shape_type != @graph.SqlTable && parent.shape_type != @graph.Class {
      break
    }
    current = parent_id
  }
  current
}

///|
fn collect_node_boxes(
  json_graph : Json,
  parent_x : Double,
  parent_y : Double,
  node_box_by_id : Map[String, @graph.Box],
) -> Unit {
  let graph_obj = match json_graph {
    Object(obj) => obj
    _ => return
  }
  let children = json_array_field(graph_obj, "children")
  for child_json in children {
    let child_obj = match child_json {
      Object(obj) => obj
      _ => continue
    }
    let child_x = json_double_field(child_obj, "x", 0.0)
    let child_y = json_double_field(child_obj, "y", 0.0)
    let child_w = positive_or(json_double_field(child_obj, "width", 0.0), 1.0).ceil()
    let child_h = positive_or(json_double_field(child_obj, "height", 0.0), 1.0).ceil()
    let abs_x = parent_x + child_x
    let abs_y = parent_y + child_y

    match json_id_field(child_obj) {
      Some(id) =>
        node_box_by_id[id] = @graph.Box::new(abs_x, abs_y, child_w, child_h)
      None => ()
    }

    collect_node_boxes(Json::object(child_obj), abs_x, abs_y, node_box_by_id)
  }
}

///|
fn collect_edge_routes(
  json_graph : Json,
  parent_x : Double,
  parent_y : Double,
  node_box_by_id : Map[String, @graph.Box],
  routes_by_edge_id : Map[String, Array[@graph.Point]],
) -> Unit {
  let graph_obj = match json_graph {
    Object(obj) => obj
    _ => return
  }

  let edges = json_array_field(graph_obj, "edges")
  for edge_json in edges {
    let edge_obj = match edge_json {
      Object(obj) => obj
      _ => continue
    }
    let edge_id = match json_id_field(edge_obj) {
      Some(id) => id
      None => continue
    }
    let (section_base_x, section_base_y) = edge_section_base_offset(
      edge_obj, parent_x, parent_y, node_box_by_id,
    )
    let route = parse_edge_route(edge_obj, section_base_x, section_base_y)
    if route.length() >= 2 {
      routes_by_edge_id[edge_id] = route
    }
  }

  let children = json_array_field(graph_obj, "children")
  for child_json in children {
    let child_obj = match child_json {
      Object(obj) => obj
      _ => continue
    }
    let child_x = json_double_field(child_obj, "x", 0.0)
    let child_y = json_double_field(child_obj, "y", 0.0)
    collect_edge_routes(
      Json::object(child_obj),
      parent_x + child_x,
      parent_y + child_y,
      node_box_by_id,
      routes_by_edge_id,
    )
  }
}

///|
fn edge_section_base_offset(
  edge_obj : Map[String, Json],
  parent_x : Double,
  parent_y : Double,
  node_box_by_id : Map[String, @graph.Box],
) -> (Double, Double) {
  match edge_container_id(edge_obj) {
    Some(container_id) =>
      match node_box_by_id.get(container_id) {
        Some(box) => (box.x, box.y)
        None => (parent_x, parent_y)
      }
    None => (parent_x, parent_y)
  }
}

///|
fn edge_container_id(edge_obj : Map[String, Json]) -> String? {
  match edge_obj.get("container") {
    Some(String(container_id)) if !container_id.is_empty() => Some(container_id)
    _ => None
  }
}

///|
fn parse_edge_route(
  edge_obj : Map[String, Json],
  section_base_x : Double,
  section_base_y : Double,
) -> Array[@graph.Point] {
  let points : Array[@graph.Point] = []
  let sections = json_array_field(edge_obj, "sections")
  for section_json in sections {
    let section_obj = match section_json {
      Object(obj) => obj
      _ => continue
    }
    match
      json_point_field(
        section_obj, "startPoint", section_base_x, section_base_y,
      ) {
      Some(point) => push_unique_route_point(points, point)
      None => ()
    }

    let bend_points = json_array_field(section_obj, "bendPoints")
    for bend_json in bend_points {
      match json_point_from_json(bend_json, section_base_x, section_base_y) {
        Some(point) => push_unique_route_point(points, point)
        None => ()
      }
    }

    match
      json_point_field(section_obj, "endPoint", section_base_x, section_base_y) {
      Some(point) => push_unique_route_point(points, point)
      None => ()
    }
  }
  points
}

///|
fn json_point_field(
  obj : Map[String, Json],
  key : String,
  parent_x : Double,
  parent_y : Double,
) -> @graph.Point? {
  match obj.get(key) {
    Some(json_value) => json_point_from_json(json_value, parent_x, parent_y)
    None => None
  }
}

///|
fn json_point_from_json(
  json_value : Json,
  parent_x : Double,
  parent_y : Double,
) -> @graph.Point? {
  let point_obj = match json_value {
    Object(obj) => obj
    _ => return None
  }
  let x = json_double_field(point_obj, "x", 0.0)
  let y = json_double_field(point_obj, "y", 0.0)
  Some(@graph.Point::new(parent_x + x, parent_y + y))
}

///|
fn json_array_field(obj : Map[String, Json], key : String) -> Array[Json] {
  match obj.get(key) {
    Some(Array(values)) => values
    _ => []
  }
}

///|
fn json_object_field(
  obj : Map[String, Json],
  key : String,
) -> Map[String, Json] {
  match obj.get(key) {
    Some(Object(value)) => value
    _ => {}
  }
}

///|
fn json_id_field(obj : Map[String, Json]) -> String? {
  match obj.get("id") {
    Some(String(value)) => Some(value)
    Some(Number(value, repr~)) => {
      ignore(repr)
      Some(value.to_int().to_string())
    }
    _ => None
  }
}

///|
fn json_double_field(
  obj : Map[String, Json],
  key : String,
  default : Double,
) -> Double {
  match obj.get(key) {
    Some(Number(value, repr~)) => {
      ignore(repr)
      value
    }
    _ => default
  }
}

///|
fn push_unique_route_point(
  points : Array[@graph.Point],
  point : @graph.Point,
) -> Unit {
  if points.is_empty() || points[points.length() - 1] != point {
    points.push(point)
  }
}

///|
fn object_fallback_box(
  obj : @graph.ObjectInput,
  width : Double,
  height : Double,
) -> @graph.Box {
  match obj.box {
    Some(box) => @graph.Box::new(box.x, box.y, width, height)
    None => @graph.Box::new(0.0, 0.0, width, height)
  }
}

///|
fn fallback_route_from_boxes(
  node_box_by_id : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  src_id : String,
  dst_id : String,
  direction : @engine_api.Direction,
) -> Array[@graph.Point] {
  let src_box = match node_box_by_id.get(src_id) {
    Some(box) => box
    None => return []
  }
  let dst_box = match node_box_by_id.get(dst_id) {
    Some(box) => box
    None => return []
  }
  let src_center = src_box.center()
  let dst_center = dst_box.center()

  let route : Array[@graph.Point] = []
  match direction {
    @engine_api.Down | @engine_api.Up =>
      if approx_eq(src_center.x, dst_center.x) {
        route.push(src_center)
        route.push(dst_center)
      } else {
        let mid_y = (src_center.y + dst_center.y) / 2.0
        route.push(src_center)
        route.push(@graph.Point::new(src_center.x, mid_y))
        route.push(@graph.Point::new(dst_center.x, mid_y))
        route.push(dst_center)
      }
    @engine_api.Right | @engine_api.Left =>
      if approx_eq(src_center.y, dst_center.y) {
        route.push(src_center)
        route.push(dst_center)
      } else {
        let mid_x = (src_center.x + dst_center.x) / 2.0
        route.push(src_center)
        route.push(@graph.Point::new(mid_x, src_center.y))
        route.push(@graph.Point::new(mid_x, dst_center.y))
        route.push(dst_center)
      }
  }

  clip_route_endpoints(route, node_box_by_id, object_by_id, src_id, dst_id)
}

///|
fn clip_route_endpoints(
  route : Array[@graph.Point],
  node_box_by_id : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  src_id : String,
  dst_id : String,
) -> Array[@graph.Point] {
  if route.length() < 2 {
    return route
  }

  let src_box = match node_box_by_id.get(src_id) {
    Some(box) => box
    None => return route
  }
  let dst_box = match node_box_by_id.get(dst_id) {
    Some(box) => box
    None => return route
  }

  let clipped : Array[@graph.Point] = []
  for p in route {
    clipped.push(p)
  }

  let src_shape_type = match object_by_id.get(src_id) {
    Some(obj) => obj.shape_type
    None => @graph.Rectangle
  }
  clipped[0] = shape_border_point_towards(src_shape_type, src_box, clipped[1])
  let last_index = clipped.length() - 1
  let dst_shape_type = match object_by_id.get(dst_id) {
    Some(obj) => obj.shape_type
    None => @graph.Rectangle
  }
  clipped[last_index] = shape_border_point_towards(
    dst_shape_type,
    dst_box,
    clipped[last_index - 1],
  )

  clipped
}

///|
fn shape_border_point_towards(
  _shape_type : @graph.ShapeType,
  box : @graph.Box,
  target : @graph.Point,
) -> @graph.Point {
  box_border_point_towards(box, target)
}

///|
fn delete_bends_like_d2(
  routes_by_index : Map[Int, Array[@graph.Point]],
  graph : @graph.GraphInput,
  node_box_by_id : Map[String, @graph.Box],
) -> Unit {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.id] = graph.root
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }

  for is_source in [true, false] {
    for edge in graph.edges {
      let route = match routes_by_index.get(edge.index) {
        Some(points) => points
        None => continue
      }
      let simplified = delete_endpoint_s_shape_like_d2(
        route, routes_by_index, edge, node_box_by_id, object_by_id, is_source,
      )
      routes_by_index[edge.index] = simplified
    }
  }

  let point_counts : Map[String, Int] = {}
  for edge in graph.edges {
    let route = match routes_by_index.get(edge.index) {
      Some(points) => points
      None => continue
    }
    for p in route {
      let key = point_key(p)
      let count = match point_counts.get(key) {
        Some(v) => v
        None => 0
      }
      point_counts[key] = count + 1
    }
  }

  for edge in graph.edges {
    let route = match routes_by_index.get(edge.index) {
      Some(points) => points
      None => continue
    }
    if route.length() < 6 || edge.src_id == edge.dst_id {
      continue
    }

    let mut i = 1
    while i < route.length() - 3 {
      let before = route[i - 1]
      let start = route[i]
      let corner = route[i + 1]
      let end = route[i + 2]
      let after = route[i + 3]

      let corner_count = match point_counts.get(point_key(corner)) {
        Some(v) => v
        None => 0
      }
      if corner_count > 1 {
        i = i + 1
        continue
      }

      let mut new_corner = corner
      if ceil_eq(start.x, corner.x) {
        new_corner = @graph.Point::new(end.x, start.y)
        if (end.x > start.x) != (start.x > before.x) {
          i = i + 1
          continue
        }
        if (end.y > start.y) != (after.y > end.y) {
          i = i + 1
          continue
        }
      } else {
        new_corner = @graph.Point::new(start.x, end.y)
        if (end.y > start.y) != (start.y > before.y) {
          i = i + 1
          continue
        }
        if (end.x > start.x) != (after.x > end.x) {
          i = i + 1
          continue
        }
      }

      let old_intersects = count_object_intersects(
          node_box_by_id,
          edge.src_id,
          edge.dst_id,
          start,
          corner,
        ) +
        count_object_intersects(
          node_box_by_id,
          edge.src_id,
          edge.dst_id,
          corner,
          end,
        )
      let new_intersects = count_object_intersects(
          node_box_by_id,
          edge.src_id,
          edge.dst_id,
          start,
          new_corner,
        ) +
        count_object_intersects(
          node_box_by_id,
          edge.src_id,
          edge.dst_id,
          new_corner,
          end,
        )

      if new_intersects > old_intersects {
        i = i + 1
        continue
      }

      let (old_cross_1, old_overlap_1, old_close_overlap_1, old_touch_1) = count_edge_intersects(
        routes_by_index,
        edge.index,
        start,
        corner,
      )
      let (old_cross_2, old_overlap_2, old_close_overlap_2, old_touch_2) = count_edge_intersects(
        routes_by_index,
        edge.index,
        corner,
        end,
      )
      let old_cross = old_cross_1 + old_cross_2
      let old_overlap = old_overlap_1 + old_overlap_2
      let old_close_overlap = old_close_overlap_1 + old_close_overlap_2
      let old_touch = old_touch_1 + old_touch_2

      let (new_cross_1, new_overlap_1, new_close_overlap_1, new_touch_1) = count_edge_intersects(
        routes_by_index,
        edge.index,
        start,
        new_corner,
      )
      let (new_cross_2, new_overlap_2, new_close_overlap_2, new_touch_2) = count_edge_intersects(
        routes_by_index,
        edge.index,
        new_corner,
        end,
      )
      let new_cross = new_cross_1 + new_cross_2
      let new_overlap = new_overlap_1 + new_overlap_2
      let new_close_overlap = new_close_overlap_1 + new_close_overlap_2
      let new_touch = new_touch_1 + new_touch_2

      if new_cross > old_cross ||
        new_overlap > old_overlap ||
        new_close_overlap > old_close_overlap ||
        new_touch > old_touch {
        i = i + 1
        continue
      }

      let updated : Array[@graph.Point] = []
      let mut j = 0
      while j < i {
        updated.push(route[j])
        j = j + 1
      }
      updated.push(new_corner)
      j = i + 3
      while j < route.length() {
        updated.push(route[j])
        j = j + 1
      }
      routes_by_index[edge.index] = updated
      break
    }
  }
}

///|
fn delete_endpoint_s_shape_like_d2(
  route : Array[@graph.Point],
  routes_by_index : Map[Int, Array[@graph.Point]],
  edge : @graph.EdgeInput,
  node_box_by_id : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  is_source : Bool,
) -> Array[@graph.Point] {
  if route.length() < 4 || edge.src_id == edge.dst_id {
    return route
  }

  let endpoint_id = if is_source { edge.src_id } else { edge.dst_id }
  let endpoint_box = match node_box_by_id.get(endpoint_id) {
    Some(box) => box
    None => return route
  }
  let endpoint_obj = object_by_id.get(endpoint_id)

  let last = route.length() - 1
  let (start, corner, end) = if is_source {
    (route[0], route[1], route[2])
  } else {
    (route[last], route[last - 1], route[last - 2])
  }

  let is_horizontal = ceil_eq(start.y, corner.y)
  let endpoint_column_index = if is_source {
    edge.src_column_index
  } else {
    edge.dst_column_index
  }
  match endpoint_column_index {
    Some(column_index) =>
      match endpoint_obj {
        Some(obj) => {
          let row_count = obj.child_ids.length() + 1
          if row_count > 0 {
            let row_height = endpoint_box.height / row_count.to_double()
            let row_center = endpoint_box.y +
              row_height * (column_index + 1).to_double() +
              row_height / 2.0
            if abs_double(end.y - row_center) > row_height / 3.0 {
              return route
            }
          }
        }
        None => ()
      }
    None =>
      if is_horizontal {
        if end.y <= endpoint_box.y + 10.0 ||
          end.y >= endpoint_box.y + endpoint_box.height - 10.0 {
          return route
        }
      } else if end.x <= endpoint_box.x + 10.0 ||
        end.x >= endpoint_box.x + endpoint_box.width - 10.0 {
        return route
      }
  }

  let probe = if is_horizontal {
    @graph.Point::new(start.x, end.y)
  } else {
    @graph.Point::new(end.x, start.y)
  }

  let endpoint_shape_type = match endpoint_obj {
    Some(obj) => obj.shape_type
    None => @graph.Rectangle
  }
  let replacement = trace_shape_border_like_d2(
    endpoint_shape_type, endpoint_box, probe, end,
  )
  let candidate = if is_source {
    let updated : Array[@graph.Point] = [replacement]
    let mut i = 3
    while i < route.length() {
      updated.push(route[i])
      i = i + 1
    }
    updated
  } else {
    let updated : Array[@graph.Point] = []
    let mut i = 0
    while i < route.length() - 3 {
      updated.push(route[i])
      i = i + 1
    }
    updated.push(replacement)
    updated
  }

  let old_object_intersects = count_object_intersects(
    node_box_by_id,
    edge.src_id,
    edge.dst_id,
    start,
    corner,
  )
  let new_object_intersects = count_object_intersects(
    node_box_by_id,
    edge.src_id,
    edge.dst_id,
    replacement,
    end,
  )
  if new_object_intersects > old_object_intersects {
    return route
  }

  let (old_cross, old_overlap, old_close_overlap, old_touch) = count_edge_intersects(
    routes_by_index,
    edge.index,
    start,
    corner,
  )
  let (new_cross, new_overlap, new_close_overlap, new_touch) = count_edge_intersects(
    routes_by_index,
    edge.index,
    replacement,
    end,
  )
  if new_cross > old_cross ||
    new_overlap > old_overlap ||
    new_close_overlap > old_close_overlap ||
    new_touch > old_touch {
    return route
  }

  candidate
}

///|
fn count_object_intersects(
  node_box_by_id : Map[String, @graph.Box],
  src_id : String,
  dst_id : String,
  a : @graph.Point,
  b : @graph.Point,
) -> Int {
  let mut count = 0
  for id, box in node_box_by_id {
    if id == src_id || id == dst_id {
      continue
    }
    if segment_intersects_expanded_box(a, b, box, 39.0) {
      count = count + 1
    }
  }
  count
}

///|
fn count_edge_intersects(
  routes_by_index : Map[Int, Array[@graph.Point]],
  current_edge_index : Int,
  a : @graph.Point,
  b : @graph.Point,
) -> (Int, Int, Int, Int) {
  let is_horizontal = ceil_eq(a.y, b.y)
  let mut crossings = 0
  let mut overlaps = 0
  let mut close_overlaps = 0
  let mut touching = 0

  for edge_index, route in routes_by_index {
    if edge_index == current_edge_index || route.length() < 2 {
      continue
    }
    let mut i = 0
    while i + 1 < route.length() {
      let c = route[i]
      let d = route[i + 1]
      let other_is_horizontal = ceil_eq(c.y, d.y)
      if is_horizontal == other_is_horizontal {
        if segments_overlap_on_axis(a, b, c, d, is_horizontal) {
          if is_horizontal {
            let delta = abs_double(a.y - c.y)
            if delta < 20.0 {
              overlaps = overlaps + 1
              if delta < 10.0 {
                close_overlaps = close_overlaps + 1
                if abs_double(a.y - c.y) < 1.0 {
                  touching = touching + 1
                }
              }
            }
          } else {
            let delta = abs_double(a.x - c.x)
            if delta < 20.0 {
              overlaps = overlaps + 1
              if delta < 10.0 {
                close_overlaps = close_overlaps + 1
                if abs_double(a.y - c.y) < 1.0 {
                  touching = touching + 1
                }
              }
            }
          }
        }
      } else if segment_intersects(a, b, c, d) {
        crossings = crossings + 1
      }
      i = i + 1
    }
  }

  (crossings, overlaps, close_overlaps, touching)
}

///|
fn segment_intersects_expanded_box(
  a : @graph.Point,
  b : @graph.Point,
  box : @graph.Box,
  padding : Double,
) -> Bool {
  let expanded = @graph.Box::new(
    box.x - padding,
    box.y - padding,
    box.width + padding * 2.0,
    box.height + padding * 2.0,
  )
  let tl = expanded.top_left()
  let tr = expanded.top_right()
  let bl = expanded.bottom_left()
  let br = expanded.bottom_right()
  segment_intersection_point_like_d2(a, b, tl, tr) is Some(_) ||
  segment_intersection_point_like_d2(a, b, tr, br) is Some(_) ||
  segment_intersection_point_like_d2(a, b, br, bl) is Some(_) ||
  segment_intersection_point_like_d2(a, b, bl, tl) is Some(_)
}

///|
fn segments_overlap_on_axis(
  a : @graph.Point,
  b : @graph.Point,
  c : @graph.Point,
  d : @graph.Point,
  is_horizontal : Bool,
) -> Bool {
  if is_horizontal {
    range_overlap(a.x, b.x, c.x, d.x)
  } else {
    range_overlap(a.y, b.y, c.y, d.y)
  }
}

///|
fn range_overlap(a1 : Double, a2 : Double, b1 : Double, b2 : Double) -> Bool {
  let min_a = if a1 < a2 { a1 } else { a2 }
  let max_a = if a1 > a2 { a1 } else { a2 }
  let min_b = if b1 < b2 { b1 } else { b2 }
  let max_b = if b1 > b2 { b1 } else { b2 }
  // Align d2 geo.Segment.Overlaps(..., buffer=0):
  // endpoint touching is NOT considered overlap.
  !(min_a - max_b >= 0.0 || min_b - max_a >= 0.0)
}

///|
fn segment_intersects(
  a : @graph.Point,
  b : @graph.Point,
  c : @graph.Point,
  d : @graph.Point,
) -> Bool {
  segment_intersection_point_like_d2(a, b, c, d) is Some(_)
}

///|
fn segment_intersection_point_like_d2(
  u0 : @graph.Point,
  u1 : @graph.Point,
  v0 : @graph.Point,
  v1 : @graph.Point,
) -> @graph.Point? {
  let udx = u1.x - u0.x
  let vdx = v1.x - v0.x
  let uvdx = v0.x - u0.x
  let udy = u1.y - u0.y
  let vdy = v1.y - v0.y
  let uvdy = v0.y - u0.y

  let denom = udy * vdx - udx * vdy
  if denom == 0.0 {
    return None
  }
  let s = (vdx * uvdy - vdy * uvdx) / denom
  let t = (udx * uvdy - udy * uvdx) / denom
  if s < 0.0 || s > 1.0 || t < 0.0 || t > 1.0 {
    return None
  }
  Some(
    @graph.Point::new(
      u0.x + round_double(s * udx),
      u0.y + round_double(s * udy),
    ),
  )
}

///|
fn point_key(p : @graph.Point) -> String {
  "\{p.x}|\{p.y}"
}

///|
fn ceil_eq(a : Double, b : Double) -> Bool {
  approx_eq(a.ceil(), b.ceil())
}

///|
fn trace_shape_border_like_d2(
  shape_type : @graph.ShapeType,
  box : @graph.Box,
  rect_border_point : @graph.Point,
  prev_point : @graph.Point,
) -> @graph.Point {
  trace_to_shape_border(shape_type, box, rect_border_point, prev_point)
}

///|
fn trace_to_shape_border(
  shape_type : @graph.ShapeType,
  box : @graph.Box,
  rect_border_point : @graph.Point,
  prev_point : @graph.Point,
) -> @graph.Point {
  if is_rectangular_shape_like_d2(shape_type) {
    return rect_border_point
  }
  if shape_type == @graph.Cylinder {
    return trace_cylinder_border(box, rect_border_point, prev_point)
  }
  let extended_end = extended_trace_segment_end(
    box, rect_border_point, prev_point,
  )
  let intersections = shape_border_intersections(
    shape_type, box, prev_point, extended_end,
  )
  if intersections.is_empty() {
    return rect_border_point
  }
  let mut closest = intersections[0]
  let mut closest_dist = point_distance(rect_border_point, closest)
  for p in intersections {
    let d = point_distance(rect_border_point, p)
    if d < closest_dist {
      closest_dist = d
      closest = p
    }
  }
  @graph.Point::new(
    round_double(truncate_float32(closest.x)),
    round_double(truncate_float32(closest.y)),
  )
}

///|
fn trace_cylinder_border(
  box : @graph.Box,
  rect_border_point : @graph.Point,
  prev_point : @graph.Point,
) -> @graph.Point {
  let segment_end = extended_trace_segment_end(
    box, rect_border_point, prev_point,
  )
  let arc = if box.height < D2_DEFAULT_ARC_DEPTH * 2.0 {
    box.height / 2.0
  } else {
    D2_DEFAULT_ARC_DEPTH
  }
  if arc <= 0.0 {
    return rect_border_point
  }
  let x0 = box.x
  let x1 = box.x + box.width
  let xmid = box.x + box.width / 2.0
  let top_y = box.y + arc
  let bottom_y = box.y + box.height - arc
  let m = D2_CYLINDER_BEZIER_MULTIPLIER
  let bottom = box.y + box.height

  let arc_hits : Array[@graph.Point] = []
  for
    hit in cubic_polyline_intersections(
      prev_point,
      segment_end,
      @graph.Point::new(x0, top_y),
      @graph.Point::new(x0, box.y),
      @graph.Point::new(x0 + box.width * m, box.y),
      @graph.Point::new(xmid, box.y),
      D2_CUBIC_TRACE_SAMPLES,
    ) {
    push_unique_point(arc_hits, hit)
  }
  for
    hit in cubic_polyline_intersections(
      prev_point,
      segment_end,
      @graph.Point::new(xmid, box.y),
      @graph.Point::new(x1 - box.width * m, box.y),
      @graph.Point::new(x1, box.y),
      @graph.Point::new(x1, top_y),
      D2_CUBIC_TRACE_SAMPLES,
    ) {
    push_unique_point(arc_hits, hit)
  }
  for
    hit in cubic_polyline_intersections(
      prev_point,
      segment_end,
      @graph.Point::new(x1, bottom_y),
      @graph.Point::new(x1, bottom),
      @graph.Point::new(x1 - box.width * m, bottom),
      @graph.Point::new(xmid, bottom),
      D2_CUBIC_TRACE_SAMPLES,
    ) {
    push_unique_point(arc_hits, hit)
  }
  for
    hit in cubic_polyline_intersections(
      prev_point,
      segment_end,
      @graph.Point::new(xmid, bottom),
      @graph.Point::new(x0 + box.width * m, bottom),
      @graph.Point::new(x0, bottom),
      @graph.Point::new(x0, bottom_y),
      D2_CUBIC_TRACE_SAMPLES,
    ) {
    push_unique_point(arc_hits, hit)
  }

  let side_hits : Array[@graph.Point] = []
  match
    segment_segment_intersection(
      @graph.Point::new(x0, top_y),
      @graph.Point::new(x0, bottom_y),
      prev_point,
      segment_end,
    ) {
    Some(hit) => push_unique_point(side_hits, hit)
    None => ()
  }
  match
    segment_segment_intersection(
      @graph.Point::new(x1, top_y),
      @graph.Point::new(x1, bottom_y),
      prev_point,
      segment_end,
    ) {
    Some(hit) => push_unique_point(side_hits, hit)
    None => ()
  }

  let candidates : Array[@graph.Point] = []
  for hit in arc_hits {
    candidates.push(hit)
  }
  for hit in side_hits {
    candidates.push(hit)
  }
  if candidates.is_empty() {
    return rect_border_point
  }
  let mut closest = candidates[0]
  let mut closest_dist = point_distance(rect_border_point, closest)
  for p in candidates {
    let d = point_distance(rect_border_point, p)
    if d < closest_dist {
      closest_dist = d
      closest = p
    }
  }
  @graph.Point::new(
    round_double(truncate_float32(closest.x)),
    round_double(truncate_float32(closest.y)),
  )
}

///|
fn extended_trace_segment_end(
  box : @graph.Box,
  rect_border_point : @graph.Point,
  prev_point : @graph.Point,
) -> @graph.Point {
  let vx = rect_border_point.x - prev_point.x
  let vy = rect_border_point.y - prev_point.y
  let length = (vx * vx + vy * vy).sqrt()
  if length <= 0.000001 {
    return prev_point
  }
  let scale_size = if prev_point.x == rect_border_point.x {
    box.height
  } else {
    box.width
  }
  let ux = vx / length
  let uy = vy / length
  @graph.Point::new(
    prev_point.x + ux * (length + scale_size),
    prev_point.y + uy * (length + scale_size),
  )
}

///|
fn d2_path_chop_precision_for_trace(value : Double) -> Double {
  // Match ../d2/lib/svg/path.go::chopPrecision used by shape perimeters.
  let rounded = (Float::from_double(value * 10000.0).to_double() / 10000.0).round()
  if rounded == 0.0 {
    0.0
  } else {
    rounded
  }
}

///|
fn d2_perimeter_point(x : Double, y : Double) -> @graph.Point {
  @graph.Point::new(
    d2_path_chop_precision_for_trace(x),
    d2_path_chop_precision_for_trace(y),
  )
}

///|
fn package_top_dimensions(box : @graph.Box) -> (Double, Double) {
  let mut top_width = box.width * D2_PACKAGE_HORIZONTAL_SCALAR
  if box.width >= 2.0 * D2_PACKAGE_TOP_MIN_WIDTH {
    if top_width < D2_PACKAGE_TOP_MIN_WIDTH {
      top_width = D2_PACKAGE_TOP_MIN_WIDTH
    }
    if top_width > D2_PACKAGE_TOP_MAX_WIDTH {
      top_width = D2_PACKAGE_TOP_MAX_WIDTH
    }
  }
  let top_height = if box.height * D2_PACKAGE_VERTICAL_SCALAR <
    D2_PACKAGE_TOP_MAX_HEIGHT {
    box.height * D2_PACKAGE_VERTICAL_SCALAR
  } else {
    D2_PACKAGE_TOP_MAX_HEIGHT
  }
  (top_width, top_height)
}

///|
fn shape_border_intersections(
  shape_type : @graph.ShapeType,
  box : @graph.Box,
  segment_start : @graph.Point,
  segment_end : @graph.Point,
) -> Array[@graph.Point] {
  match shape_type {
    @graph.Hexagon => {
      let points = [
        d2_perimeter_point(box.x + box.width * 0.25, box.y),
        d2_perimeter_point(box.x, box.y + box.height * D2_HEXAGON_HALF_Y_FACTOR),
        d2_perimeter_point(box.x + box.width * 0.25, box.y + box.height),
        d2_perimeter_point(box.x + box.width * 0.75, box.y + box.height),
        d2_perimeter_point(
          box.x + box.width,
          box.y + box.height * D2_HEXAGON_HALF_Y_FACTOR,
        ),
        d2_perimeter_point(box.x + box.width * 0.75, box.y),
      ]
      polygon_intersections(points, segment_start, segment_end)
    }
    @graph.Diamond => {
      let points = [
        d2_perimeter_point(box.x + box.width / 2.0, box.y),
        d2_perimeter_point(box.x + box.width, box.y + box.height / 2.0),
        d2_perimeter_point(box.x + box.width / 2.0, box.y + box.height),
        d2_perimeter_point(box.x, box.y + box.height / 2.0),
      ]
      polygon_intersections(points, segment_start, segment_end)
    }
    @graph.Callout => {
      let tip_w = if box.width < 60.0 { box.width / 2.0 } else { 30.0 }
      let tip_h = if box.height < 90.0 { box.height / 2.0 } else { 45.0 }
      let main_h = box.height - tip_h
      let mid_x = round_double(box.x + box.width / 2.0)
      let points = [
        d2_perimeter_point(box.x, box.y),
        d2_perimeter_point(box.x, box.y + main_h),
        d2_perimeter_point(mid_x, box.y + main_h),
        d2_perimeter_point(mid_x, box.y + box.height),
        d2_perimeter_point(mid_x + tip_w, box.y + main_h),
        d2_perimeter_point(box.x + box.width, box.y + main_h),
        d2_perimeter_point(box.x + box.width, box.y),
      ]
      polygon_intersections(points, segment_start, segment_end)
    }
    @graph.Package => {
      let (top_width, top_height) = package_top_dimensions(box)
      let points = [
        d2_perimeter_point(box.x, box.y),
        d2_perimeter_point(box.x + top_width, box.y),
        d2_perimeter_point(box.x + top_width, box.y + top_height),
        d2_perimeter_point(box.x + box.width, box.y + top_height),
        d2_perimeter_point(box.x + box.width, box.y + box.height),
        d2_perimeter_point(box.x, box.y + box.height),
      ]
      polygon_intersections(points, segment_start, segment_end)
    }
    @graph.Parallelogram => {
      let wedge = if box.width <= D2_PARALLELOGRAM_WEDGE_WIDTH {
        box.width / 2.0
      } else {
        D2_PARALLELOGRAM_WEDGE_WIDTH
      }
      let points = [
        d2_perimeter_point(box.x + wedge, box.y),
        d2_perimeter_point(box.x + box.width, box.y),
        d2_perimeter_point(box.x + box.width - wedge, box.y + box.height),
        d2_perimeter_point(box.x, box.y + box.height),
      ]
      polygon_intersections(points, segment_start, segment_end)
    }
    @graph.Step => {
      let wedge = if box.width <= D2_STEP_WEDGE_WIDTH {
        box.width / 2.0
      } else {
        D2_STEP_WEDGE_WIDTH
      }
      let points = [
        d2_perimeter_point(box.x, box.y),
        d2_perimeter_point(box.x + box.width - wedge, box.y),
        d2_perimeter_point(box.x + box.width, box.y + box.height / 2.0),
        d2_perimeter_point(box.x + box.width - wedge, box.y + box.height),
        d2_perimeter_point(box.x, box.y + box.height),
        d2_perimeter_point(box.x + wedge, box.y + box.height / 2.0),
      ]
      polygon_intersections(points, segment_start, segment_end)
    }
    @graph.Document => {
      let out : Array[@graph.Point] = []
      let x0 = box.x
      let y0 = box.y
      let x1 = box.x + box.width
      let base_y = box.y + box.height * (16.3 / 18.925)
      let cp1_y = box.y + box.height * (12.8 / 18.925)
      let cp2_y = box.y + box.height * (19.8 / 18.925)
      let mid_x = box.x + box.width * 0.5

      match
        segment_segment_intersection(
          d2_perimeter_point(x0, y0),
          d2_perimeter_point(x1, y0),
          segment_start,
          segment_end,
        ) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      match
        segment_segment_intersection(
          d2_perimeter_point(x0, y0),
          d2_perimeter_point(x0, base_y),
          segment_start,
          segment_end,
        ) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      match
        segment_segment_intersection(
          d2_perimeter_point(x1, y0),
          d2_perimeter_point(x1, base_y),
          segment_start,
          segment_end,
        ) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          d2_perimeter_point(x1, base_y),
          d2_perimeter_point(box.x + box.width * (5.0 / 6.0), cp1_y),
          d2_perimeter_point(box.x + box.width * (2.0 / 3.0), cp1_y),
          d2_perimeter_point(mid_x, base_y),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          d2_perimeter_point(mid_x, base_y),
          d2_perimeter_point(box.x + box.width * (1.0 / 3.0), cp2_y),
          d2_perimeter_point(box.x + box.width * (1.0 / 6.0), cp2_y),
          d2_perimeter_point(x0, base_y),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      out
    }
    @graph.Page => {
      let out : Array[@graph.Point] = []
      let x0 = box.x
      let y0 = box.y
      let p0 = d2_perimeter_point(x0 + 0.5, y0 + 0.0)
      let p1 = d2_perimeter_point(x0 + (box.width - 20.8164), y0 + 0.0)
      let p2 = d2_perimeter_point(x0 + (box.width - 19.6456), y0 + 0.0)
      let p3 = d2_perimeter_point(x0 + (box.width - 18.5210), y0 + 0.456297)
      let p4 = d2_perimeter_point(x0 + (box.width - 17.6811), y0 + 1.27202)
      let p5 = d2_perimeter_point(x0 + (box.width - 1.3647), y0 + 17.12)
      let p6 = d2_perimeter_point(x0 + (box.width - 0.4923), y0 + 17.9674)
      let p7 = d2_perimeter_point(x0 + box.width, y0 + 19.1318)
      let p8 = d2_perimeter_point(x0 + box.width, y0 + 20.348)
      let p9 = d2_perimeter_point(x0 + box.width, y0 + (box.height - 0.5))
      let p10 = d2_perimeter_point(x0 + box.width, y0 + (box.height - 0.2239))
      let p11 = d2_perimeter_point(x0 + (box.width - 0.2239), y0 + box.height)
      let p12 = d2_perimeter_point(x0 + (box.width - 0.5), y0 + box.height)
      let p13 = d2_perimeter_point(x0 + 0.499999, y0 + box.height)
      let p14 = d2_perimeter_point(x0 + 0.223857, y0 + box.height)
      let p15 = d2_perimeter_point(x0 + 0.0, y0 + (box.height - 0.2239))
      let p16 = d2_perimeter_point(x0 + 0.0, y0 + (box.height - 0.5))
      let p17 = d2_perimeter_point(x0 + 0.0, y0 + 0.499999)
      let p18 = d2_perimeter_point(x0 + 0.0, y0 + 0.223857)
      let p19 = d2_perimeter_point(x0 + 0.223857, y0 + 0.0)

      match segment_segment_intersection(p0, p1, segment_start, segment_end) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p1,
          p2,
          p3,
          p4,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      match segment_segment_intersection(p4, p5, segment_start, segment_end) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p5,
          p6,
          p7,
          p8,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      match segment_segment_intersection(p8, p9, segment_start, segment_end) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p9,
          p10,
          p11,
          p12,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      match segment_segment_intersection(p12, p13, segment_start, segment_end) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p13,
          p14,
          p15,
          p16,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      match segment_segment_intersection(p16, p17, segment_start, segment_end) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p17,
          p18,
          p19,
          p0,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      out
    }
    @graph.Queue => {
      let out : Array[@graph.Point] = []
      let arc = if box.width < D2_DEFAULT_ARC_DEPTH * 2.0 {
        box.width / 2.0
      } else {
        D2_DEFAULT_ARC_DEPTH
      }
      let m = D2_CYLINDER_BEZIER_MULTIPLIER
      let x0 = box.x
      let x1 = box.x + box.width
      let y0 = box.y
      let y1 = box.y + box.height
      let start_x = x0 + arc
      let end_x = x1 - arc

      match
        segment_segment_intersection(
          d2_perimeter_point(start_x, y0),
          d2_perimeter_point(end_x, y0),
          segment_start,
          segment_end,
        ) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          d2_perimeter_point(end_x, y0),
          d2_perimeter_point(x1, y0),
          d2_perimeter_point(x1, y0 + box.height * m),
          d2_perimeter_point(x1, y0 + box.height / 2.0),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          d2_perimeter_point(x1, y0 + box.height / 2.0),
          d2_perimeter_point(x1, y1 - box.height * m),
          d2_perimeter_point(x1, y1),
          d2_perimeter_point(end_x, y1),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      match
        segment_segment_intersection(
          d2_perimeter_point(end_x, y1),
          d2_perimeter_point(start_x, y1),
          segment_start,
          segment_end,
        ) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          d2_perimeter_point(start_x, y1),
          d2_perimeter_point(x0, y1),
          d2_perimeter_point(x0, y1 - box.height * m),
          d2_perimeter_point(x0, y0 + box.height / 2.0),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          d2_perimeter_point(x0, y0 + box.height / 2.0),
          d2_perimeter_point(x0, y0 + box.height * m),
          d2_perimeter_point(x0, y0),
          d2_perimeter_point(start_x, y0),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      out
    }
    @graph.StoredData => {
      let out : Array[@graph.Point] = []
      let wedge = if box.width < D2_STORED_DATA_WEDGE_WIDTH * 2.0 {
        box.width / 2.0
      } else {
        D2_STORED_DATA_WEDGE_WIDTH
      }
      let m = 0.27
      let x0 = box.x
      let x1 = box.x + box.width
      let y0 = box.y
      let y1 = box.y + box.height
      let left_x = x0 + wedge
      let right_x = x1 - wedge

      match
        segment_segment_intersection(
          d2_perimeter_point(left_x, y0),
          d2_perimeter_point(x1, y0),
          segment_start,
          segment_end,
        ) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          d2_perimeter_point(x1, y0),
          d2_perimeter_point(x1 - wedge * m, y0),
          d2_perimeter_point(right_x, y0 + box.height * m),
          d2_perimeter_point(right_x, y0 + box.height / 2.0),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          d2_perimeter_point(right_x, y0 + box.height / 2.0),
          d2_perimeter_point(right_x, y1 - box.height * m),
          d2_perimeter_point(x1 - wedge * m, y1),
          d2_perimeter_point(x1, y1),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      match
        segment_segment_intersection(
          d2_perimeter_point(x1, y1),
          d2_perimeter_point(left_x, y1),
          segment_start,
          segment_end,
        ) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          d2_perimeter_point(left_x, y1),
          d2_perimeter_point(left_x - wedge * m, y1),
          d2_perimeter_point(x0, y1 - box.height * m),
          d2_perimeter_point(x0, y0 + box.height / 2.0),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          d2_perimeter_point(x0, y0 + box.height / 2.0),
          d2_perimeter_point(x0, y0 + box.height * m),
          d2_perimeter_point(left_x - wedge * m, y0),
          d2_perimeter_point(left_x, y0),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      out
    }
    @graph.Cloud => {
      let out : Array[@graph.Point] = []
      let sx = box.width / 834.0
      let sy = box.height / 523.0
      let abs_pt = fn(x : Double, y : Double) {
        d2_perimeter_point(box.x + sx * x, box.y + sy * y)
      }
      let rel_pt = fn(base : @graph.Point, dx : Double, dy : Double) {
        d2_perimeter_point(base.x + sx * dx, base.y + sy * dy)
      }

      let p0 = abs_pt(137.833, 182.833)
      let c1 = rel_pt(p0, 0.0, 5.556)
      let c2 = rel_pt(p0, -5.556, 11.111)
      let p1 = rel_pt(p0, -11.111, 11.111)

      let c3 = rel_pt(p1, -70.833, 6.944)
      let c4 = rel_pt(p1, -126.389, 77.778)
      let p2 = rel_pt(p1, -126.389, 163.889)

      let c5 = rel_pt(p2, 0.0, 91.667)
      let c6 = rel_pt(p2, 62.5, 165.278)
      let p3 = rel_pt(p2, 141.667, 165.278)

      let p4 = d2_perimeter_point(p3.x + sx * 537.5, p3.y)

      let c7 = rel_pt(p4, 84.723, 0.0)
      let c8 = rel_pt(p4, 154.167, -79.167)
      let p5 = rel_pt(p4, 154.167, -175.0)

      let c9 = rel_pt(p5, 0.0, -91.667)
      let c10 = rel_pt(p5, -63.89, -168.056)
      let p6 = rel_pt(p5, -144.444, -173.611)

      let c11 = rel_pt(p6, -5.556, 0.0)
      let c12 = rel_pt(p6, -11.111, -4.167)
      let p7 = rel_pt(p6, -12.5, -11.111)

      let c13 = rel_pt(p7, -18.056, -93.055)
      let c14 = rel_pt(p7, -101.39, -162.5)
      let p8 = rel_pt(p7, -198.611, -162.5)

      let c15 = rel_pt(p8, -63.889, 0.0)
      let c16 = rel_pt(p8, -120.834, 29.167)
      let p9 = rel_pt(p8, -156.944, 75.0)

      let c17 = rel_pt(p9, -4.167, 5.556)
      let c18 = rel_pt(p9, -11.111, 6.945)
      let p10 = rel_pt(p9, -15.278, 5.556)

      let c19 = rel_pt(p10, -13.889, -5.556)
      let c20 = rel_pt(p10, -29.166, -8.333)
      let p11 = rel_pt(p10, -45.833, -8.333)

      let c21 = abs_pt(196.167, 71.722)
      let c22 = abs_pt(143.389, 120.333)
      let p12 = abs_pt(137.833, 182.833)

      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p0,
          c1,
          c2,
          p1,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p1,
          c3,
          c4,
          p2,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p2,
          c5,
          c6,
          p3,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      match segment_segment_intersection(p3, p4, segment_start, segment_end) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p4,
          c7,
          c8,
          p5,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p5,
          c9,
          c10,
          p6,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p6,
          c11,
          c12,
          p7,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p7,
          c13,
          c14,
          p8,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p8,
          c15,
          c16,
          p9,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p9,
          c17,
          c18,
          p10,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p10,
          c19,
          c20,
          p11,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          p11,
          c21,
          c22,
          p12,
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      out
    }
    @graph.Circle | @graph.Oval =>
      segment_ellipse_intersections(
        segment_start,
        segment_end,
        box.x + box.width / 2.0,
        box.y + box.height / 2.0,
        box.width / 2.0,
        box.height / 2.0,
      )
    _ => []
  }
}

///|
fn polygon_intersections(
  points : Array[@graph.Point],
  segment_start : @graph.Point,
  segment_end : @graph.Point,
) -> Array[@graph.Point] {
  let out : Array[@graph.Point] = []
  if points.length() < 2 {
    return out
  }
  for i in 0..<points.length() {
    let p0 = points[i]
    let p1 = points[(i + 1) % points.length()]
    match segment_segment_intersection(p0, p1, segment_start, segment_end) {
      Some(hit) => push_unique_point(out, hit)
      None => ()
    }
  }
  out
}

///|
fn push_unique_point(points : Array[@graph.Point], p : @graph.Point) -> Unit {
  for existing in points {
    if abs_double(existing.x - p.x) < 0.000001 &&
      abs_double(existing.y - p.y) < 0.000001 {
      return
    }
  }
  points.push(p)
}

///|
fn segment_segment_intersection(
  u0 : @graph.Point,
  u1 : @graph.Point,
  v0 : @graph.Point,
  v1 : @graph.Point,
) -> @graph.Point? {
  let udx = u1.x - u0.x
  let vdx = v1.x - v0.x
  let uvdx = v0.x - u0.x
  let udy = u1.y - u0.y
  let vdy = v1.y - v0.y
  let uvdy = v0.y - u0.y

  let denom = udy * vdx - udx * vdy
  if denom == 0.0 {
    return None
  }
  let s = (vdx * uvdy - vdy * uvdx) / denom
  let t = (udx * uvdy - udy * uvdx) / denom
  if s < 0.0 || s > 1.0 || t < 0.0 || t > 1.0 {
    return None
  }
  Some(
    @graph.Point::new(
      u0.x + round_double(s * udx),
      u0.y + round_double(s * udy),
    ),
  )
}

///|
fn cubic_polyline_intersections(
  segment_start : @graph.Point,
  segment_end : @graph.Point,
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  p3 : @graph.Point,
  samples : Int,
) -> Array[@graph.Point] {
  let _ = samples
  compute_cubic_line_intersections(segment_start, segment_end, p0, p1, p2, p3)
}

///|
fn compute_cubic_line_intersections(
  line_start : @graph.Point,
  line_end : @graph.Point,
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  p3 : @graph.Point,
) -> Array[@graph.Point] {
  let out : Array[@graph.Point] = []
  let a = line_end.y - line_start.y
  let b = line_start.x - line_end.x
  let c = line_start.x * (line_start.y - line_end.y) +
    line_start.y * (line_end.x - line_start.x)
  let bx = bezier_coeffs(p0.x, p1.x, p2.x, p3.x)
  let by = bezier_coeffs(p0.y, p1.y, p2.y, p3.y)
  let poly = [
    a * bx[0] + b * by[0],
    a * bx[1] + b * by[1],
    a * bx[2] + b * by[2],
    a * bx[3] + b * by[3] + c,
  ]
  let roots = cubic_roots(poly)
  for i in 0..<3 {
    let t = roots[i]
    let point = @graph.Point::new(
      bx[0] * t * t * t + bx[1] * t * t + bx[2] * t + bx[3],
      by[0] * t * t * t + by[1] * t * t + by[2] * t + by[3],
    )
    let s = if line_end.x - line_start.x != 0.0 {
      (point.x - line_start.x) / (line_end.x - line_start.x)
    } else {
      (point.y - line_start.y) / (line_end.y - line_start.y)
    }
    let t_lt0 = precision_compare(t, 0.0, D2_GEO_PRECISION) < 0
    let t_gt1 = precision_compare(t, 1.0, D2_GEO_PRECISION) > 0
    let s_lt0 = precision_compare(s, 0.0, D2_GEO_PRECISION) < 0
    let s_gt1 = precision_compare(s, 1.0, D2_GEO_PRECISION) > 0
    if !(t_lt0 || t_gt1 || s_lt0 || s_gt1) {
      out.push(point)
    }
  }
  out
}

///|
fn precision_compare(a : Double, b : Double, e : Double) -> Int {
  if abs_double(a - b) < e {
    0
  } else if a < b {
    -1
  } else {
    1
  }
}

///|
fn cubic_roots(poly : Array[Double]) -> Array[Double] {
  if precision_compare(poly[0], 0.0, D2_GEO_PRECISION) == 0 {
    if precision_compare(poly[1], 0.0, D2_GEO_PRECISION) == 0 {
      let out = [-1.0 * (poly[3] / poly[2]), -1.0, -1.0]
      for i in 0..<1 {
        let t_lt0 = precision_compare(out[i], 0.0, D2_GEO_PRECISION) < 0
        let t_gt1 = precision_compare(out[i], 1.0, D2_GEO_PRECISION) > 0
        if t_lt0 || t_gt1 {
          out[i] = -1.0
        }
      }
      return sort_special(out)
    }

    let mut dq = poly[2] * poly[2] - 4.0 * poly[1] * poly[3]
    if precision_compare(dq, 0.0, D2_GEO_PRECISION) >= 0 {
      dq = dq.sqrt()
      let out = [
        -1.0 * ((dq + poly[2]) / (2.0 * poly[1])),
        (dq - poly[2]) / (2.0 * poly[1]),
        -1.0,
      ]
      for i in 0..<2 {
        let t_lt0 = precision_compare(out[i], 0.0, D2_GEO_PRECISION) < 0
        let t_gt1 = precision_compare(out[i], 1.0, D2_GEO_PRECISION) > 0
        if t_lt0 || t_gt1 {
          out[i] = -1.0
        }
        return sort_special(out)
      }
    }
  }

  let a = poly[0]
  let b = poly[1]
  let c = poly[2]
  let d = poly[3]
  let aa = b / a
  let bb = c / a
  let cc = d / a
  let q = (3.0 * bb - aa * aa) / 9.0
  let r = (9.0 * aa * bb - 27.0 * cc - 2.0 * aa * aa * aa) / 54.0
  let disc = q * q * q + r * r

  let out = [-1.0, -1.0, -1.0]
  if precision_compare(disc, 0.0, D2_GEO_PRECISION) >= 0 {
    let s = signum(r + disc.sqrt()) * cube_root(abs_double(r + disc.sqrt()))
    let t = signum(r - disc.sqrt()) * cube_root(abs_double(r - disc.sqrt()))
    out[0] = -aa / 3.0 + (s + t)
    out[1] = -aa / 3.0 - (s + t) / 2.0
    out[2] = -aa / 3.0 - (s + t) / 2.0
    let imag = abs_double(3.0.sqrt() * (s - t) / 2.0)
    if precision_compare(imag, 0.0, D2_GEO_PRECISION) != 0 {
      out[1] = -1.0
      out[2] = -1.0
    }
  } else {
    let theta = @math.acos(r / (-q * q * q).sqrt())
    let pi = 3.141592653589793
    out[0] = 2.0 * (-q).sqrt() * @math.cos(theta / 3.0) - aa / 3.0
    out[1] = 2.0 * (-q).sqrt() * @math.cos((theta + 2.0 * pi) / 3.0) - aa / 3.0
    out[2] = 2.0 * (-q).sqrt() * @math.cos((theta + 4.0 * pi) / 3.0) - aa / 3.0
  }

  for i in 0..<3 {
    let t_lt0 = precision_compare(out[i], 0.0, D2_GEO_PRECISION) < 0
    let t_gt1 = precision_compare(out[i], 1.0, D2_GEO_PRECISION) > 0
    if t_lt0 || t_gt1 {
      out[i] = -1.0
    }
  }
  sort_special(out)
}

///|
fn sort_special(values : Array[Double]) -> Array[Double] {
  let out : Array[Double] = []
  for v in values {
    out.push(v)
  }
  while true {
    let mut flipped = false
    for i in 0..<(out.length() - 1) {
      let right_non_neg = precision_compare(out[i + 1], 0.0, D2_GEO_PRECISION) >=
        0
      let left_gt_right = precision_compare(
          out[i],
          out[i + 1],
          D2_GEO_PRECISION,
        ) >
        0
      let left_neg = precision_compare(out[i], 0.0, D2_GEO_PRECISION) < 0
      if (right_non_neg && left_gt_right) || (left_neg && right_non_neg) {
        flipped = true
        let tmp = out[i]
        out[i] = out[i + 1]
        out[i + 1] = tmp
      }
    }
    if !flipped {
      break
    }
  }
  out
}

///|
fn signum(v : Double) -> Double {
  if v < 0.0 {
    -1.0
  } else {
    1.0
  }
}

///|
fn cube_root(v : Double) -> Double {
  @math.pow(v, 1.0 / 3.0)
}

///|
fn bezier_coeffs(
  p0 : Double,
  p1 : Double,
  p2 : Double,
  p3 : Double,
) -> Array[Double] {
  [
    -p0 + 3.0 * p1 - 3.0 * p2 + p3,
    3.0 * p0 - 6.0 * p1 + 3.0 * p2,
    -3.0 * p0 + 3.0 * p1,
    p0,
  ]
}

///|
fn segment_ellipse_intersections(
  p0 : @graph.Point,
  p1 : @graph.Point,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
) -> Array[@graph.Point] {
  let out : Array[@graph.Point] = []
  if rx <= 0.0 || ry <= 0.0 {
    return out
  }

  let dx = p1.x - p0.x
  let dy = p1.y - p0.y
  let ax = dx / rx
  let ay = dy / ry
  let bx = (p0.x - cx) / rx
  let by = (p0.y - cy) / ry

  let a = ax * ax + ay * ay
  if abs_double(a) < 0.000001 {
    return out
  }
  let b = 2.0 * (ax * bx + ay * by)
  let c = bx * bx + by * by - 1.0
  let disc = b * b - 4.0 * a * c
  if disc < -0.000001 {
    return out
  }
  let sqrt_disc = if disc > 0.0 { disc.sqrt() } else { 0.0 }
  let t1 = (-b - sqrt_disc) / (2.0 * a)
  let t2 = (-b + sqrt_disc) / (2.0 * a)

  if t1 >= -0.000001 && t1 <= 1.000001 {
    out.push(@graph.Point::new(p0.x + dx * t1, p0.y + dy * t1))
  }
  if abs_double(t2 - t1) > 0.000001 && t2 >= -0.000001 && t2 <= 1.000001 {
    out.push(@graph.Point::new(p0.x + dx * t2, p0.y + dy * t2))
  }
  out
}

///|
fn box_border_point_towards(
  box : @graph.Box,
  target : @graph.Point,
) -> @graph.Point {
  let center = box.center()
  let dx = target.x - center.x
  let dy = target.y - center.y
  if approx_zero(dx) && approx_zero(dy) {
    return center
  }

  let large = 1000000000000000000.0

  let tx = if !approx_zero(dx) {
    if dx > 0.0 {
      (box.x + box.width - center.x) / dx
    } else {
      (box.x - center.x) / dx
    }
  } else {
    large
  }

  let ty = if !approx_zero(dy) {
    if dy > 0.0 {
      (box.y + box.height - center.y) / dy
    } else {
      (box.y - center.y) / dy
    }
  } else {
    large
  }

  let mut t = tx
  if ty < t {
    t = ty
  }
  if t < 0.0 {
    t = 0.0
  }

  @graph.Point::new(center.x + dx * t, center.y + dy * t)
}

///|
fn object_size(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
  object_by_id : Map[String, @graph.ObjectInput],
) -> (Double, Double) {
  let estimate_auto_size = () => {
    if obj.shape_type == @graph.SqlTable {
      let (width, height) = estimate_sql_table_size(obj, object_by_id)
      (
        clamp_positive(width, config.default_width),
        clamp_positive(height, config.default_height),
      )
    } else if obj.shape_type == @graph.Class {
      let (width, height) = estimate_class_size(obj, object_by_id)
      (
        clamp_positive(width, config.default_width),
        clamp_positive(height, config.default_height),
      )
    } else {
      estimate_object_size(obj, config, object_by_id)
    }
  }
  match obj.box {
    Some(box) => {
      let (auto_width, auto_height) = estimate_auto_size()
      let width = if box.width > 0.0 { box.width } else { auto_width }
      let height = if box.height > 0.0 { box.height } else { auto_height }
      (
        clamp_positive(width, config.default_width),
        clamp_positive(height, config.default_height),
      )
    }
    None => estimate_auto_size()
  }
}

///|
fn clamp_positive(value : Double, fallback : Double) -> Double {
  let base = if value > 0.0 { value } else { fallback }
  if base > 0.0 {
    base
  } else {
    1.0
  }
}

///|
fn estimate_object_size(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
  _object_by_id : Map[String, @graph.ObjectInput],
) -> (Double, Double) {
  let font_size = match obj.style.font_size {
    Some(value) => value.as_int().unwrap_or(16)
    None => 16
  }
  let (label_width, label_height) = match object_label_dimensions(obj) {
    Some((w, h)) => (w, h)
    None => (0.0, 0.0)
  }
  let mut content_width = label_width
  let mut content_height = label_height

  if obj.shape_type == @graph.Code {
    content_width = content_width + font_size.to_double()
    content_height = content_height + font_size.to_double()
    // D2 parity: code shape size is measured text + 0.5em padding each side only.
    return (content_width, content_height)
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

  let base_padding = shape_default_padding(obj.shape_type)
  let mut padding_x = base_padding.0
  let mut padding_y = base_padding.1
  if obj.icon is Some(_) &&
    obj.shape_type != @graph.SqlTable &&
    obj.shape_type != @graph.Class &&
    obj.shape_type != @graph.Code &&
    obj.shape_type != @graph.Text {
    let label_height_with_padding = label_height + D2_INNER_LABEL_PADDING
    padding_x = padding_x + label_height_with_padding
    padding_y = padding_y + label_height_with_padding
  }

  let fitted = shape_dimensions_to_fit(
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
    let fit = limit_aspect_ratio(width, height, D2_PERSON_AR_LIMIT)
    width = fit.0
    height = fit.1
  } else if obj.shape_type == @graph.Oval {
    let fit = limit_aspect_ratio(width, height, D2_OVAL_AR_LIMIT)
    width = fit.0
    height = fit.1
  } else if obj.shape_type == @graph.C4Person {
    let fit = limit_aspect_ratio(width, height, D2_C4_PERSON_AR_LIMIT)
    width = fit.0
    height = fit.1
  }

  (
    clamp_positive(width, config.default_width),
    clamp_positive(height, config.default_height),
  )
}

///|
priv struct ClassMemberInfo {
  name : String
  type_name : String
}

///|
fn trim_double_quotes_for_class_member(s : String) -> String {
  if s.length() >= 2 && s[0] == '"' && s[s.length() - 1] == '"' {
    let out = StringBuilder::new()
    for i = 1; i < s.length() - 1; i = i + 1 {
      match s[i].to_char() {
        Some(ch) => out.write_char(ch)
        None => ()
      }
    }
    out.to_string()
  } else {
    s
  }
}

///|
fn class_member_info_from_object(child : @graph.ObjectInput) -> ClassMemberInfo {
  let raw_name = @graph.syntax_path_last_display(child.id)
  let mut name = raw_name
  if raw_name.length() > 0 {
    let first = raw_name[0]
    if first == '+' || first == '-' || first == '#' {
      let name_buf = StringBuilder::new()
      for i = 1; i < raw_name.length(); i = i + 1 {
        match raw_name[i].to_char() {
          Some(ch) => name_buf.write_char(ch)
          None => ()
        }
      }
      name = name_buf.to_string()
    }
  }
  let is_method = name.contains("(")
  let raw_type = trim_double_quotes_for_class_member(child.label)
  let type_name = if raw_type == "" || raw_type == raw_name || raw_type == name {
    if is_method {
      "void"
    } else {
      ""
    }
  } else {
    raw_type
  }
  { name, type_name }
}

///|
fn estimate_class_size(
  obj : @graph.ObjectInput,
  object_by_id : Map[String, @graph.ObjectInput],
) -> (Double, Double) {
  let row_font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(20)
    None => 20
  }
  let header_measured = @text_metrics.measure_text_mono_plain(
    obj.label,
    row_font_size + D2_CLASS_HEADER_FONT_ADD,
  )
  let header_dims = header_measured.dimensions

  let mut max_width = if header_dims.width > 12.0 {
    header_dims.width
  } else {
    12.0
  }
  let mut row_count = 0
  let mut first_row_text : String? = None

  for child_id in obj.child_ids {
    let child = match object_by_id.get(child_id) {
      Some(v) => v
      None => continue
    }
    let info = class_member_info_from_object(child)
    let row_text = info.name + info.type_name
    if first_row_text is None {
      first_row_text = Some(row_text)
    }
    let row_measured = @text_metrics.measure_text_mono_plain(
      row_text, row_font_size,
    )
    let row_width = row_measured.dimensions.width
    if row_width > max_width {
      max_width = row_width
    }
    row_count = row_count + 1
  }

  let mut width = D2_CLASS_PREFIX_PADDING +
    D2_CLASS_PREFIX_WIDTH +
    max_width +
    D2_CLASS_CENTER_PADDING +
    D2_CLASS_TYPE_PADDING
  let mut height = 0.0

  match first_row_text {
    Some(any_row_text) => {
      let row_dims = @text_metrics.measure_text_mono_plain(
          any_row_text, row_font_size,
        ).dimensions
      let row_height = row_dims.height + D2_CLASS_VERTICAL_PADDING
      let header_height_min = if 2.0 * row_height >
        header_dims.height + D2_LABEL_PADDING * 2.0 {
        2.0 * row_height
      } else if obj.shape_type == @graph.Class {
        header_dims.height + D2_LABEL_PADDING * 2.0
      } else {
        D2_LABEL_PADDING * 2.0
      }
      height = row_height * row_count.to_double() + header_height_min
    }
    None => {
      let header_floor = if header_dims.height > 12.0 {
        header_dims.height
      } else {
        12.0
      }
      height = 2.0 * header_floor + D2_CLASS_VERTICAL_PADDING
    }
  }

  if width < 12.0 {
    width = 12.0
  }
  if height < 12.0 {
    height = 12.0
  }
  (width.ceil(), height.ceil())
}

///|
fn shape_default_padding(shape_type : @graph.ShapeType) -> (Double, Double) {
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
fn shape_dimensions_to_fit(
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
      let fit = limit_aspect_ratio(total_width, total_height, D2_OVAL_AR_LIMIT)
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
      let fit = limit_aspect_ratio(
        total_width,
        total_height,
        D2_PERSON_AR_LIMIT,
      )
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
      let fit = limit_aspect_ratio(
        total_width,
        total_height,
        D2_C4_PERSON_AR_LIMIT,
      )
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
fn limit_aspect_ratio(
  width : Double,
  height : Double,
  aspect_ratio : Double,
) -> (Double, Double) {
  let mut w = width
  let mut h = height
  if w > aspect_ratio * h {
    h = round_double(w / aspect_ratio)
  } else if h > aspect_ratio * w {
    w = round_double(h / aspect_ratio)
  }
  (w, h)
}

///|
fn round_double(v : Double) -> Double {
  if v >= 0.0 {
    (v + 0.5).to_int().to_double()
  } else {
    (v - 0.5).to_int().to_double()
  }
}

///|
fn truncate_float32(v : Double) -> Double {
  Float::from_double(v).to_double()
}

///|
fn has_outside_bottom_label(shape_type : @graph.ShapeType) -> Bool {
  shape_type == @graph.Person || shape_type == @graph.Image
}

///|
fn default_label_position(
  obj : @graph.ObjectInput,
  box : @graph.Box,
  label_width : Double,
  label_height : Double,
) -> DefaultLabelPosition {
  let is_container = !obj.child_ids.is_empty()
  let mut pos = if is_container {
    InsideTop
  } else if has_outside_bottom_label(obj.shape_type) {
    OutsideBottom
  } else if obj.icon is Some(_) {
    InsideTop
  } else {
    InsideMiddle
  }
  if label_width > box.width || label_height > box.height {
    pos = if is_container { OutsideTop } else { OutsideBottom }
  }
  pos
}

///|
fn object_layout_spacing(
  obj : @graph.ObjectInput,
  box : @graph.Box,
) -> (LayoutSpacing, LayoutSpacing) {
  let mut margin_top = 0.0
  let margin_left = 0.0
  let mut margin_bottom = 0.0
  let mut margin_right = 0.0
  let mut padding_top = 0.0
  let padding_left = 0.0
  let padding_bottom = 0.0
  let padding_right = 0.0

  if obj.label != "" {
    let font_size = match obj.style.font_size {
      Some(v) => v.as_int().unwrap_or(16)
      None => 16
    }
    let is_bold = style_bool(obj.style.bold, false)
    let is_italic = style_bool(obj.style.italic, false)
    let is_mono = obj.shape_type == @graph.Code ||
      style_is_mono(obj.style.font_family)
    let (measured_width, measured_height) = measure_object_label_dims(
      obj, font_size, is_mono, is_bold, is_italic,
    )
    let label_width = if measured_width > 0.0 {
      measured_width + D2_LABEL_PADDING
    } else {
      obj.label.length().to_double() * 7.0 + D2_LABEL_PADDING
    }
    let label_height = if measured_height > 0.0 {
      measured_height + D2_LABEL_PADDING
    } else {
      font_size.to_double() + D2_LABEL_PADDING
    }

    match default_label_position(obj, box, label_width, label_height) {
      OutsideTop => margin_top = label_height
      OutsideBottom => margin_bottom = label_height
      InsideTop => padding_top = label_height
      InsideMiddle => ()
    }
  }

  if obj.icon is Some(_) {
    let icon_size = D2_MAX_ICON_SIZE + D2_LABEL_PADDING
    let icon_pos = if !obj.child_ids.is_empty() ||
      obj.shape_type == @graph.Class ||
      obj.shape_type == @graph.SqlTable ||
      obj.shape_type == @graph.Code {
      if !obj.child_ids.is_empty() {
        InsideTop
      } else {
        OutsideTop
      }
    } else {
      InsideMiddle
    }
    match icon_pos {
      OutsideTop => if icon_size > margin_top { margin_top = icon_size }
      OutsideBottom =>
        if icon_size > margin_bottom {
          margin_bottom = icon_size
        }
      InsideTop => if icon_size > padding_top { padding_top = icon_size }
      InsideMiddle => ()
    }
  }

  if style_bool(obj.style.three_d, false) {
    margin_right = margin_right + D2_THREE_DEE_OFFSET
    margin_top = margin_top +
      (if obj.shape_type == @graph.Hexagon {
        D2_THREE_DEE_OFFSET / 2.0
      } else {
        D2_THREE_DEE_OFFSET
      })
  } else if style_bool(obj.style.multiple, false) {
    margin_right = margin_right + D2_MULTIPLE_OFFSET
    margin_top = margin_top + D2_MULTIPLE_OFFSET
  }

  (
    {
      top: margin_top,
      left: margin_left,
      bottom: margin_bottom,
      right: margin_right,
    },
    {
      top: padding_top,
      left: padding_left,
      bottom: padding_bottom,
      right: padding_right,
    },
  )
}

///|
fn object_default_label_box(
  obj : @graph.ObjectInput,
  box : @graph.Box,
) -> @graph.Box? {
  if obj.label == "" {
    return None
  }
  if obj.shape_type == @graph.SqlTable || obj.shape_type == @graph.Class {
    return None
  }
  let (label_width, label_height) = match object_label_dimensions(obj) {
    Some(v) => v
    None => return None
  }
  let pos = default_label_position(obj, box, label_width, label_height)
  let inner_box = shape_inner_box_for_label(obj, box, label_width, label_height)
  let (x, y) = match pos {
    OutsideTop =>
      (
        box.x + (box.width - label_width) / 2.0,
        box.y - D2_LABEL_PADDING - label_height,
      )
    OutsideBottom =>
      (
        box.x + (box.width - label_width) / 2.0,
        box.y + box.height + D2_LABEL_PADDING,
      )
    InsideTop =>
      (
        inner_box.x + (inner_box.width - label_width) / 2.0,
        inner_box.y + D2_LABEL_PADDING,
      )
    InsideMiddle =>
      (
        inner_box.x + (inner_box.width - label_width) / 2.0,
        inner_box.y + (inner_box.height - label_height) / 2.0,
      )
  }
  Some(@graph.Box::new(x, y, label_width, label_height))
}

///|
fn shape_inner_box_for_label(
  obj : @graph.ObjectInput,
  box : @graph.Box,
  label_width : Double,
  label_height : Double,
) -> @graph.Box {
  let mut x = box.x
  let mut y = box.y
  let mut width = box.width
  let mut height = box.height
  match obj.shape_type {
    @graph.Hexagon => {
      x = x + width / 6.0
      y = y + height / 6.0
      width = width / 1.5
      height = height / 1.5
    }
    @graph.Cloud => {
      let aspect = if label_height > 0.0 {
        label_width / label_height
      } else {
        1.0
      }
      if aspect > CLOUD_WIDE_ASPECT_BOUNDARY {
        x = x + (width * 0.085).ceil()
        y = y + (height * 0.409).ceil()
        width = width * CLOUD_WIDE_INNER_WIDTH
        height = height * CLOUD_WIDE_INNER_HEIGHT
      } else if aspect < CLOUD_TALL_ASPECT_BOUNDARY {
        x = x + (width * 0.228).ceil()
        y = y + (height * 0.179).ceil()
        width = width * CLOUD_TALL_INNER_WIDTH
        height = height * CLOUD_TALL_INNER_HEIGHT
      } else {
        x = x + (width * 0.167).ceil()
        y = y + (height * 0.335).ceil()
        width = width * CLOUD_SQUARE_INNER_WIDTH
        height = height * CLOUD_SQUARE_INNER_HEIGHT
      }
    }
    @graph.Cylinder => {
      let mut arc = D2_DEFAULT_ARC_DEPTH
      if height < arc * 2.0 {
        arc = height / 2.0
      }
      y = y + 2.0 * arc
      height = height - 3.0 * arc
    }
    @graph.Queue => {
      let mut arc = D2_DEFAULT_ARC_DEPTH
      if width < arc * 2.0 {
        arc = width / 2.0
      }
      x = x + arc
      width = width - 3.0 * arc
    }
    @graph.StoredData => {
      x = x + D2_STORED_DATA_WEDGE_WIDTH
      width = width - 2.0 * D2_STORED_DATA_WEDGE_WIDTH
    }
    @graph.Document =>
      height = height * D2_DOC_PATH_INNER_BOTTOM / D2_DOC_PATH_HEIGHT
    @graph.Package => {
      let top_h = if D2_PACKAGE_TOP_MAX_HEIGHT <
        height * D2_PACKAGE_VERTICAL_SCALAR {
        D2_PACKAGE_TOP_MAX_HEIGHT
      } else {
        height * D2_PACKAGE_VERTICAL_SCALAR
      }
      y = y + top_h
      height = height - top_h
    }
    @graph.Callout => {
      let tip_h = if height < 90.0 { height / 2.0 } else { 45.0 }
      height = height - tip_h
    }
    @graph.Person => {
      let shoulder = 20.2 / 68.3 * width
      x = x + shoulder
      width = width - shoulder * 2.0
    }
    @graph.C4Person => {
      let head_radius = width * D2_C4_HEAD_RADIUS_FACTOR
      let body_top = head_radius + head_radius * D2_C4_BODY_TOP_FACTOR
      let h_padding = width * 0.05
      let v_padding = height * 0.03
      x = x + h_padding
      y = y + body_top + v_padding
      width = width - h_padding * 2.0
      height = height - body_top - v_padding * 2.0
    }
    _ => ()
  }
  if width <= 0.0 || height <= 0.0 {
    box
  } else {
    @graph.Box::new(x, y, width, height)
  }
}

///|
fn object_label_dimensions(obj : @graph.ObjectInput) -> (Double, Double)? {
  if obj.label == "" {
    return None
  }
  match obj.label_box {
    Some(box) =>
      if box.width > 0.0 && box.height > 0.0 {
        return Some((round_double(box.width), round_double(box.height)))
      }
    None => ()
  }
  let font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(obj.style.bold, false)
  let is_italic = style_bool(obj.style.italic, false)
  let is_mono = obj.shape_type == @graph.Code ||
    style_is_mono(obj.style.font_family)
  let (measured_width, measured_height) = measure_object_label_dims(
    obj, font_size, is_mono, is_bold, is_italic,
  )
  let width = if measured_width > 0.0 {
    round_double(measured_width)
  } else {
    round_double(obj.label.length().to_double() * 7.0)
  }
  let height = if measured_height > 0.0 {
    round_double(measured_height)
  } else {
    round_double(font_size.to_double() + 5.0)
  }
  Some((width, height))
}

///|
fn estimate_sql_table_size(
  obj : @graph.ObjectInput,
  object_by_id : Map[String, @graph.ObjectInput],
) -> (Double, Double) {
  let row_font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(20)
    None => 20
  }
  let header_font_size = row_font_size + D2_SQL_TABLE_HEADER_FONT_ADD
  let header_measured = @text_metrics.measure_text(
    obj.label,
    header_font_size,
    false,
    true,
    false,
  )
  let header_dims = header_measured.dimensions
  let padded_header_width = header_dims.width + D2_INNER_LABEL_PADDING
  let padded_header_height = header_dims.height + D2_INNER_LABEL_PADDING

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
    let name_measure = @text_metrics.measure_text(
      short_name_from_id(child.id),
      row_font_size,
      false,
      false,
      false,
    )
    let name_width = name_measure.dimensions.width
    if name_width > max_name_width {
      max_name_width = name_width
    }

    let type_measure = @text_metrics.measure_text(
      child.label,
      row_font_size,
      false,
      false,
      false,
    )
    let type_width = type_measure.dimensions.width
    if type_width > max_type_width {
      max_type_width = type_width
    }

    let constraint = sql_table_constraint_abbr_from_object(child)
    if constraint != "" {
      let constraint_measure = @text_metrics.measure_text(
        constraint, row_font_size, false, false, false,
      )
      let constraint_width = constraint_measure.dimensions.width
      if constraint_width > max_constraint_width {
        max_constraint_width = constraint_width
      }
    }
  }

  let header_width = D2_SQL_TABLE_HEADER_PADDING +
    padded_header_width +
    D2_SQL_TABLE_HEADER_PADDING
  let mut rows_width = D2_SQL_TABLE_NAME_PADDING +
    max_name_width +
    D2_SQL_TABLE_TYPE_PADDING +
    max_type_width +
    D2_SQL_TABLE_TYPE_PADDING +
    max_constraint_width
  if max_constraint_width > 0.0 {
    rows_width = rows_width + D2_SQL_TABLE_CONSTRAINT_PADDING
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
  for constraint in obj.sql_constraints {
    constraints.push(constraint)
  }
  if constraints.is_empty() {
    let prefix = "sql_constraint:"
    for cls in obj.classes {
      if cls.has_prefix(prefix) {
        let buf = StringBuilder::new()
        for i = prefix.length(); i < cls.length(); i = i + 1 {
          match cls[i].to_char() {
            Some(ch) => buf.write_char(ch)
            None => ()
          }
        }
        constraints.push(buf.to_string())
      }
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
  @graph.syntax_path_last(id)
}

///|
fn label_width(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
) -> Double {
  let width = match object_label_dimensions(obj) {
    Some((w, _)) => w
    None => 0.0
  }
  positive_or(width, config.default_width / 2.0)
}

///|
fn label_height(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
) -> Double {
  let height = match object_label_dimensions(obj) {
    Some((_, h)) => h
    None => 0.0
  }
  positive_or(height, config.default_height / 3.0)
}

///|
fn object_is_markdown(obj : @graph.ObjectInput) -> Bool {
  match obj.language {
    Some(language) => language == "markdown"
    None => false
  }
}

///|
fn measure_object_label_dims(
  obj : @graph.ObjectInput,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> (Double, Double) {
  if obj.shape_type == @graph.Code {
    let dims = @text_metrics.measure_label_code(
      obj.label,
      font_size,
      is_bold,
      is_italic,
    )
    return (dims.width, dims.height)
  }
  if object_is_markdown(obj) {
    let dims = @text_metrics.measure_label_markdown(obj.label, font_size)
    return (dims.width, dims.height)
  }
  let dims = @text_metrics.measure_label(
    obj.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  (dims.width, dims.height)
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
fn route_point_at_percent(
  route : Array[@graph.Point],
  percent : Double,
) -> @graph.Point {
  if route.is_empty() {
    return @graph.Point::new(0.0, 0.0)
  }
  if route.length() == 1 {
    return route[0]
  }

  let clamped = if percent < 0.0 {
    0.0
  } else if percent > 1.0 {
    1.0
  } else {
    percent
  }

  let total = route_total_length(route)
  if total <= 0.000001 {
    return route[0]
  }

  let target = total * clamped
  let mut walked = 0.0
  for i in 1..<route.length() {
    let p0 = route[i - 1]
    let p1 = route[i]
    let segment_len = point_distance(p0, p1)
    if segment_len <= 0.000001 {
      continue
    }
    if walked + segment_len >= target {
      let t = (target - walked) / segment_len
      let x = p0.x + (p1.x - p0.x) * t
      let y = p0.y + (p1.y - p0.y) * t
      return @graph.Point::new(x, y)
    }
    walked = walked + segment_len
  }

  route[route.length() - 1]
}

///|
fn route_total_length(route : Array[@graph.Point]) -> Double {
  if route.length() < 2 {
    return 0.0
  }
  let mut total = 0.0
  for i in 1..<route.length() {
    total = total + point_distance(route[i - 1], route[i])
  }
  total
}

///|
fn point_distance(a : @graph.Point, b : @graph.Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  (dx * dx + dy * dy).sqrt()
}

///|
fn elk_edge_id(edge : @graph.EdgeInput, repeat_index : Int) -> String {
  d2_edge_abs_id(edge, repeat_index)
}

///|
fn d2_edge_repeat_indices(edges : Array[@graph.EdgeInput]) -> Array[Int] {
  let counts : Map[String, Int] = {}
  let out : Array[Int] = []
  for edge in edges {
    let key = d2_edge_repeat_key(edge)
    let index = counts.get(key).unwrap_or(0)
    out.push(index)
    counts[key] = index + 1
  }
  out
}

///|
fn d2_edge_repeat_key(edge : @graph.EdgeInput) -> String {
  "\{edge.src_id}\u0000\{edge.src_arrow.to_string()}\u0000\{edge.dst_id}\u0000\{edge.dst_arrow.to_string()}"
}

///|
fn d2_edge_abs_id(edge : @graph.EdgeInput, repeat_index : Int) -> String {
  let src_parts = d2_split_abs_id_parts(edge.src_id)
  let dst_parts = d2_split_abs_id_parts(edge.dst_id)
  let common : Array[String] = []
  let mut src_start = 0
  let mut dst_start = 0
  while src_parts.length() - src_start > 1 && dst_parts.length() - dst_start > 1 {
    if src_parts[src_start].to_lower() != dst_parts[dst_start].to_lower() {
      break
    }
    common.push(src_parts[src_start])
    src_start = src_start + 1
    dst_start = dst_start + 1
  }
  let common_key = if common.is_empty() { "" } else { common.join(".") + "." }
  let src_tail : Array[String] = []
  let dst_tail : Array[String] = []
  for i in src_start..<src_parts.length() {
    src_tail.push(src_parts[i])
  }
  for i in dst_start..<dst_parts.length() {
    dst_tail.push(dst_parts[i])
  }
  let src_join = src_tail.join(".")
  let dst_join = dst_tail.join(".")
  "\{common_key}(\{src_join} \{d2_edge_arrow_string(edge)} \{dst_join})[\{repeat_index}]"
}

///|
fn d2_split_abs_id_parts(id : String) -> Array[String] {
  let out : Array[String] = []
  if id == "" {
    return out
  }
  for part in id.split(".") {
    out.push(part.to_string())
  }
  out
}

///|
fn d2_edge_arrow_string(edge : @graph.EdgeInput) -> String {
  if edge.src_arrow && edge.dst_arrow {
    "<->"
  } else if edge.src_arrow {
    "<-"
  } else if edge.dst_arrow {
    "->"
  } else {
    "--"
  }
}

///|
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
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
fn approx_zero(value : Double) -> Bool {
  value.abs() <= 0.000001
}

///|
fn approx_eq(a : Double, b : Double) -> Bool {
  (a - b).abs() <= 0.000001
}
