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
const D2_PERSON_AR_LIMIT : Double = 1.5

///|
const D2_OVAL_AR_LIMIT : Double = 3.0

///|
const D2_MARKDOWN_LINE_HEIGHT : Double = 1.5

///|
const D2_MARKDOWN_LINE_HEIGHT_HEADING : Double = 1.25

///|
const D2_MARKDOWN_UL_OL_PADDING_LEFT_EM : Double = 2.0

///|
const D2_MARKDOWN_UL_MARGIN_BOTTOM : Double = 16.0

///|
const D2_MARKDOWN_LI_P_MARGIN_TOP : Double = 16.0

///|
const D2_MARKDOWN_LI_MARGIN_TOP_EM : Double = 0.25

///|
const D2_MARKDOWN_P_MARGIN_BOTTOM : Double = 16.0

///|
const D2_MARKDOWN_H_MARGIN_TOP : Double = 24.0

///|
const D2_MARKDOWN_H_MARGIN_BOTTOM : Double = 16.0

///|
const D2_MARKDOWN_H1_H2_PADDING_BOTTOM_EM : Double = 0.3

///|
const D2_MARKDOWN_H1_H2_BORDER_BOTTOM : Double = 1.0

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
  apply_constant_near_positions(patch, graph)

  patch
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
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }

  let widths : Array[Double] = []
  let heights : Array[Double] = []
  for id in participant_ids {
    match object_by_id.get(id) {
      Some(obj) => {
        let (w0, h0) = object_size(obj, config, object_by_id)
        let width = if w0 < 100.0 { 100.0 } else { w0 }
        let height = if h0 < 66.0 { 66.0 } else { h0 }
        widths.push(width)
        heights.push(height)
      }
      None => {
        widths.push(100.0)
        heights.push(66.0)
      }
    }
  }

  let actor_steps : Array[Double] = []
  if widths.length() > 1 {
    for i = 0; i < widths.length() - 1; i = i + 1 {
      let base_gap = widths[i] / 2.0 + widths[i + 1] / 2.0 + 40.0
      actor_steps.push(if base_gap < 150.0 { 150.0 } else { base_gap })
    }
  }

  let participant_index_by_id : Map[String, Int] = {}
  for i, id in participant_ids {
    participant_index_by_id[id] = i
  }

  for edge in graph.edges {
    let src_index = match participant_index_by_id.get(edge.src_id) {
      Some(v) => v
      None => continue
    }
    let dst_index = match participant_index_by_id.get(edge.dst_id) {
      Some(v) => v
      None => continue
    }
    if src_index == dst_index {
      continue
    }
    let label_width = sequence_edge_width_for_spacing(edge)
    if src_index == dst_index {
      if src_index < actor_steps.length() {
        let self_required = if label_width > 0.0 {
          label_width + 20.0
        } else {
          0.0
        }
        if self_required > actor_steps[src_index] {
          actor_steps[src_index] = self_required
        }
      }
      continue
    }
    let left = if src_index < dst_index { src_index } else { dst_index }
    let right = if src_index < dst_index { dst_index } else { src_index }
    let rank_diff = (right - left).to_double()
    if rank_diff <= 0.0 {
      continue
    }
    let distributed = label_width / rank_diff
    let required_step = distributed + 60.0
    for rank = left; rank < right; rank = rank + 1 {
      if rank < actor_steps.length() && required_step > actor_steps[rank] {
        actor_steps[rank] = required_step
      }
    }
  }

  let centers : Array[Double] = []
  if !widths.is_empty() {
    centers.push(12.0 + widths[0] / 2.0)
    for i = 1; i < widths.length(); i = i + 1 {
      centers.push(centers[i - 1] + actor_steps[i - 1])
    }
  }

  let participant_top = 52.0
  for i, id in participant_ids {
    let width = widths[i]
    let height = heights[i]
    patch.nodes[id] = @graph.Box::new(
      centers[i] - width / 2.0,
      participant_top,
      width,
      height,
    )
  }

  let max_participant_height = array_max(heights, 66.0)
  let lifeline_start_y = participant_top + max_participant_height + 2.0
  let first_message_y = lifeline_start_y + 78.0
  let message_gap = 90.0

  for i, edge in graph.edges {
    let src_index = match participant_index_by_id.get(edge.src_id) {
      Some(v) => v
      None => continue
    }
    let dst_index = match participant_index_by_id.get(edge.dst_id) {
      Some(v) => v
      None => continue
    }

    let src_x = centers[src_index]
    let dst_x = centers[dst_index]
    let y = first_message_y + i.to_double() * message_gap
    patch.edges[edge.index] = [
      @graph.Point::new(src_x, y),
      @graph.Point::new(dst_x, y),
    ]

    if edge.label != "" {
      let (label_width, label_height) = sequence_edge_label_size(edge)
      let center_x = (src_x + dst_x) / 2.0
      patch.edge_labels[edge.index] = @graph.Box::new(
        center_x - label_width / 2.0,
        y - 10.0,
        label_width,
        label_height,
      )
    }
  }

  patch
}

///|
fn sequence_edge_width_for_spacing(edge : @graph.EdgeInput) -> Double {
  let width_with_padding = match edge.label_box {
    Some(box) if box.width > 0.0 => box.width
    _ => fallback_sequence_edge_label_size(edge).0
  }
  // D2 sequence spacing uses LabelDimensions.Width, while label boxes carry
  // an extra ~2px side padding on each side.
  if width_with_padding > 4.0 {
    width_with_padding - 4.0
  } else {
    width_with_padding
  }
}

///|
fn sequence_participant_ids(graph : @graph.GraphInput) -> Array[String] {
  if !graph.root.child_ids.is_empty() {
    let ids : Array[String] = []
    let exists : Map[String, Bool] = {}
    for obj in graph.objects {
      exists[obj.id] = true
    }
    for id in graph.root.child_ids {
      if exists.contains(id) {
        ids.push(id)
      }
    }
    if !ids.is_empty() {
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
fn array_max(values : Array[Double], fallback : Double) -> Double {
  if values.is_empty() {
    return fallback
  }
  let mut out = values[0]
  for v in values {
    if v > out {
      out = v
    }
  }
  out
}

///|
fn ensure_moon_elk_json_bootstrap_linked() -> Unit {
  // `moon_elk/graph/json` registers the core layout delegate in package init.
  // Keep a direct reference so tree-shaking does not drop the import.
  ignore(@moon_elk_json.new_json_adapter)
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
      "width": Json::number(width),
      "height": Json::number(height),
      "children": Json::array([]),
    }

    if !obj.label.is_empty() {
      node_json["labels"] = Json::array([
        Json::object({
          "text": Json::string(obj.label),
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
    let children_json = json_array_field(parent_node, "children")
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
    parent_node["children"] = Json::array(children_json)
    node_json_by_id[obj.id] = parent_node
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
    }

    match edge_label_size(edge) {
      Some((label_w, label_h)) =>
        edge_json["labels"] = Json::array([
          Json::object({
            "text": Json::string(edge.label),
            "width": Json::number(label_w),
            "height": Json::number(label_h),
            "layoutOptions": Json::object({
              "elk.edgeLabels.inline": Json::boolean(true),
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
        if edge.src_id == obj.id && approx_eq(route[0].x, box.x) {
          route[0] = @graph.Point::new(route[0].x + margin.left, route[0].y)
        }
        if edge.dst_id == obj.id && approx_eq(route[last].x, box.x) {
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
      box = @graph.Box::new(
        box.x,
        box.y,
        max_double(1.0, box.width - margin.left),
        box.height,
      )
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
        if edge.src_id == obj.id && approx_eq(route[0].x, right_x) {
          route[0] = @graph.Point::new(route[0].x - margin.right, route[0].y)
        }
        if edge.dst_id == obj.id && approx_eq(route[last].x, right_x) {
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
      box = @graph.Box::new(
        box.x,
        box.y,
        max_double(1.0, box.width - margin.right),
        box.height,
      )
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
        if edge.src_id == obj.id && approx_eq(route[0].y, box.y) {
          route[0] = @graph.Point::new(route[0].x, route[0].y + margin.top)
        }
        if edge.dst_id == obj.id && approx_eq(route[last].y, box.y) {
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
      box = @graph.Box::new(
        box.x,
        box.y,
        box.width,
        max_double(1.0, box.height - margin.top),
      )
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
        if edge.src_id == obj.id && approx_eq(route[0].y, bottom_y) {
          route[0] = @graph.Point::new(route[0].x, route[0].y - margin.bottom)
        }
        if edge.dst_id == obj.id && approx_eq(route[last].y, bottom_y) {
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
      box = @graph.Box::new(
        box.x,
        box.y,
        box.width,
        max_double(1.0, box.height - margin.bottom),
      )
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
    if obj.id.contains(".") {
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
    if obj.id.contains(".") {
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
        near_key,
        min_x,
        min_y,
        width,
        height,
        box.width,
        box.height,
      )
      patch.nodes[obj.id] = @graph.Box::new(x, y, box.width, box.height)
      current_set_ids.push(obj.id)
    }
    for id in current_set_ids {
      placed_near[id] = true
    }
  }
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
  near_key : String,
  min_x : Double,
  min_y : Double,
  width : Double,
  height : Double,
  box_width : Double,
  box_height : Double,
) -> (Double, Double) {
  match near_key {
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

  adjust_route_endpoints_for_outside_labels(
    routes_by_index, graph, node_box_by_id,
  )
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
fn adjust_route_endpoints_for_outside_labels(
  routes_by_index : Map[Int, Array[@graph.Point]],
  graph : @graph.GraphInput,
  node_box_by_id : Map[String, @graph.Box],
) -> Unit {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  let parent_id_by_child_id : Map[String, String] = {}
  for parent in graph.objects {
    for child_id in parent.child_ids {
      parent_id_by_child_id[child_id] = parent.id
    }
  }

  for edge in graph.edges {
    let route = match routes_by_index.get(edge.index) {
      Some(v) => v
      None => continue
    }
    if route.length() < 2 {
      continue
    }

    let src_id = collapse_sql_or_class_endpoint_id(
      edge.src_id,
      object_by_id,
      parent_id_by_child_id,
    )
    let dst_id = collapse_sql_or_class_endpoint_id(
      edge.dst_id,
      object_by_id,
      parent_id_by_child_id,
    )

    let src_obj = match object_by_id.get(src_id) {
      Some(v) => v
      None => continue
    }
    let dst_obj = match object_by_id.get(dst_id) {
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

    if route.length() >= 2 {
      match outside_label_box(src_obj, src_box) {
        Some((label_box, pos)) => {
          let intersections = box_intersections(label_box, route[1], route[0])
          if !intersections.is_empty() {
            route[0] = pick_outside_intersection(pos, intersections)
          }
        }
        None => ()
      }
    }

    if route.length() >= 2 {
      let last = route.length() - 1
      match outside_label_box(dst_obj, dst_box) {
        Some((label_box, pos)) => {
          let intersections = box_intersections(
            label_box,
            route[last - 1],
            route[last],
          )
          if !intersections.is_empty() {
            route[last] = pick_outside_intersection(pos, intersections)
          }
        }
        None => ()
      }
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

    let src_obj = object_by_id.get(src_id)
    let src_shape_type = match src_obj {
      Some(obj) => obj.shape_type
      None => @graph.Rectangle
    }
    let dst_obj = object_by_id.get(dst_id)
    let dst_shape_type = match dst_obj {
      Some(obj) => obj.shape_type
      None => @graph.Rectangle
    }
    let mut src_on_box = false
    let src_trace_box = shape_trace_intersection_box(
      src_obj, src_shape_type, src_box,
    )
    match first_box_intersection_like_d2(src_trace_box, route[0], route[1]) {
      Some(hit) => {
        route[0] = hit
        src_on_box = true
      }
      None => ()
    }
    if src_on_box {
      route[0] = trace_shape_border_like_d2(
        src_shape_type,
        src_box,
        route[0],
        route[1],
      )
    } else if src_shape_type == @graph.Callout {
      let tip_h = if src_box.height < 90.0 {
        src_box.height / 2.0
      } else {
        45.0
      }
      route[0] = @graph.Point::new(
        route[0].x,
        src_box.y + src_box.height - tip_h,
      )
    }

    let last = route.length() - 1
    let mut dst_on_box = false
    match
      first_box_intersection_like_d2(
        shape_trace_intersection_box(dst_obj, dst_shape_type, dst_box),
        route[last - 1],
        route[last],
      ) {
      Some(hit) => {
        route[last] = hit
        dst_on_box = true
      }
      None => ()
    }
    if dst_on_box {
      route[last] = trace_shape_border_like_d2(
        dst_shape_type,
        dst_box,
        route[last],
        route[last - 1],
      )
    } else if dst_shape_type == @graph.Callout {
      let tip_h = if dst_box.height < 90.0 {
        dst_box.height / 2.0
      } else {
        45.0
      }
      route[last] = @graph.Point::new(
        route[last].x,
        dst_box.y + dst_box.height - tip_h,
      )
    }
  }
}

///|
fn shape_trace_intersection_box(
  obj : @graph.ObjectInput?,
  shape_type : @graph.ShapeType,
  box : @graph.Box,
) -> @graph.Box {
  let mut adjusted = box
  match obj {
    Some(v) =>
      if style_bool(v.style.three_d, false) {
        let offset_y = if shape_type == @graph.Hexagon {
          D2_THREE_DEE_OFFSET / 2.0
        } else {
          D2_THREE_DEE_OFFSET
        }
        adjusted = @graph.Box::new(
          adjusted.x,
          adjusted.y - offset_y,
          adjusted.width + D2_THREE_DEE_OFFSET,
          adjusted.height + offset_y,
        )
      }
    None => ()
  }
  match shape_type {
    @graph.Callout => {
      let tip_h = if adjusted.height < 90.0 {
        adjusted.height / 2.0
      } else {
        45.0
      }
      @graph.Box::new(
        adjusted.x,
        adjusted.y,
        adjusted.width,
        adjusted.height - tip_h,
      )
    }
    _ => adjusted
  }
}

///|
fn first_box_intersection_like_d2(
  box : @graph.Box,
  p0 : @graph.Point,
  p1 : @graph.Point,
) -> @graph.Point? {
  let x0 = box.x
  let x1 = box.x + box.width
  let y0 = box.y
  let y1 = box.y + box.height

  match segment_intersection_at_y_for_box(p0, p1, y0, x0, x1) {
    Some(hit) => return Some(hit.1)
    None => ()
  }
  match segment_intersection_at_x_for_box(p0, p1, x1, y0, y1) {
    Some(hit) => return Some(hit.1)
    None => ()
  }
  match segment_intersection_at_y_for_box(p0, p1, y1, x0, x1) {
    Some(hit) => return Some(hit.1)
    None => ()
  }
  match segment_intersection_at_x_for_box(p0, p1, x0, y0, y1) {
    Some(hit) => return Some(hit.1)
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
  let pos = default_label_position(obj, box, label_width, label_height)
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

  let add_hit = fn(hit : @graph.Point) {
    for existing in hits {
      if abs_double(existing.x - hit.x) < 0.000001 &&
        abs_double(existing.y - hit.y) < 0.000001 {
        return
      }
    }
    hits.push(hit)
  }

  let x0 = box.x
  let x1 = box.x + box.width
  let y0 = box.y
  let y1 = box.y + box.height

  match segment_intersection_at_y_for_box(p0, p1, y0, x0, x1) {
    Some(hit) => add_hit(hit.1)
    None => ()
  }
  match segment_intersection_at_x_for_box(p0, p1, x1, y0, y1) {
    Some(hit) => add_hit(hit.1)
    None => ()
  }
  match segment_intersection_at_y_for_box(p0, p1, y1, x0, x1) {
    Some(hit) => add_hit(hit.1)
    None => ()
  }
  match segment_intersection_at_x_for_box(p0, p1, x0, y0, y1) {
    Some(hit) => add_hit(hit.1)
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
fn segment_intersection_at_x_for_box(
  p0 : @graph.Point,
  p1 : @graph.Point,
  x : Double,
  min_y : Double,
  max_y : Double,
) -> (Double, @graph.Point)? {
  let dx = p1.x - p0.x
  if abs_double(dx) < 0.000001 {
    return None
  }
  let t = (x - p0.x) / dx
  if t < 0.0 || t > 1.0 {
    return None
  }
  let y = p0.y + (p1.y - p0.y) * t
  if y < min_y - 0.000001 || y > max_y + 0.000001 {
    return None
  }
  let rx = p0.x + round_nearest_int_double_for_box(t * (p1.x - p0.x))
  let ry = p0.y + round_nearest_int_double_for_box(t * (p1.y - p0.y))
  Some((t, @graph.Point::new(rx, ry)))
}

///|
fn segment_intersection_at_y_for_box(
  p0 : @graph.Point,
  p1 : @graph.Point,
  y : Double,
  min_x : Double,
  max_x : Double,
) -> (Double, @graph.Point)? {
  let dy = p1.y - p0.y
  if abs_double(dy) < 0.000001 {
    return None
  }
  let t = (y - p0.y) / dy
  if t < 0.0 || t > 1.0 {
    return None
  }
  let x = p0.x + (p1.x - p0.x) * t
  if x < min_x - 0.000001 || x > max_x + 0.000001 {
    return None
  }
  let rx = p0.x + round_nearest_int_double_for_box(t * (p1.x - p0.x))
  let ry = p0.y + round_nearest_int_double_for_box(t * (p1.y - p0.y))
  Some((t, @graph.Point::new(rx, ry)))
}

///|
fn round_nearest_int_double_for_box(v : Double) -> Double {
  if v >= 0.0 {
    (v + 0.5).to_int().to_double()
  } else {
    (v - 0.5).to_int().to_double()
  }
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
  { "elk.layered.edgeRouting.selfLoopDistribution": Json::string("EQUALLY") }
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
    let child_w = positive_or(json_double_field(child_obj, "width", 0.0), 1.0)
    let child_h = positive_or(json_double_field(child_obj, "height", 0.0), 1.0)
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
  if point_in_box(a, expanded) || point_in_box(b, expanded) {
    return true
  }
  let tl = expanded.top_left()
  let tr = expanded.top_right()
  let bl = expanded.bottom_left()
  let br = expanded.bottom_right()
  segment_intersects(a, b, tl, tr) ||
  segment_intersects(a, b, tr, br) ||
  segment_intersects(a, b, br, bl) ||
  segment_intersects(a, b, bl, tl)
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
fn point_in_box(p : @graph.Point, box : @graph.Box) -> Bool {
  p.x >= box.x &&
  p.x <= box.x + box.width &&
  p.y >= box.y &&
  p.y <= box.y + box.height
}

///|
fn segment_intersects(
  a : @graph.Point,
  b : @graph.Point,
  c : @graph.Point,
  d : @graph.Point,
) -> Bool {
  let o1 = orientation(a, b, c)
  let o2 = orientation(a, b, d)
  let o3 = orientation(c, d, a)
  let o4 = orientation(c, d, b)

  if o1 != o2 && o3 != o4 {
    return true
  }
  if o1 == 0 && on_segment(a, c, b) {
    return true
  }
  if o2 == 0 && on_segment(a, d, b) {
    return true
  }
  if o3 == 0 && on_segment(c, a, d) {
    return true
  }
  if o4 == 0 && on_segment(c, b, d) {
    return true
  }
  false
}

///|
fn orientation(p : @graph.Point, q : @graph.Point, r : @graph.Point) -> Int {
  let value = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
  if approx_zero(value) {
    0
  } else if value > 0.0 {
    1
  } else {
    2
  }
}

///|
fn on_segment(p : @graph.Point, q : @graph.Point, r : @graph.Point) -> Bool {
  q.x <= max_double(p.x, r.x) &&
  q.x >= min_double(p.x, r.x) &&
  q.y <= max_double(p.y, r.y) &&
  q.y >= min_double(p.y, r.y)
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
  let perimeter_segments = shape_perimeter_segments_like_d2(shape_type, box)
  if perimeter_segments.is_empty() {
    return rect_border_point
  }

  let vx = rect_border_point.x - prev_point.x
  let vy = rect_border_point.y - prev_point.y
  if approx_zero(vx) && approx_zero(vy) {
    return rect_border_point
  }
  let length = (vx * vx + vy * vy).sqrt()
  if approx_zero(length) {
    return rect_border_point
  }
  let scale_size = if approx_zero(rect_border_point.x - prev_point.x) {
    box.height
  } else {
    box.width
  }
  let scale = (length + scale_size) / length
  let extended_end = @graph.Point::new(
    prev_point.x + vx * scale,
    prev_point.y + vy * scale,
  )

  let mut closest : @graph.Point? = None
  let mut closest_dist = 1000000000000000000.0
  for segment in perimeter_segments {
    match
      segment_intersection_point(prev_point, extended_end, segment.0, segment.1) {
      Some((hit, _)) => {
        let dx = rect_border_point.x - hit.x
        let dy = rect_border_point.y - hit.y
        let d = dx * dx + dy * dy
        if d < closest_dist {
          closest_dist = d
          closest = Some(hit)
        }
      }
      None => ()
    }
  }

  match closest {
    Some(hit) => @graph.Point::new(round_double(hit.x), round_double(hit.y))
    None => rect_border_point
  }
}

///|
fn shape_perimeter_segments_like_d2(
  shape_type : @graph.ShapeType,
  box : @graph.Box,
) -> Array[(@graph.Point, @graph.Point)] {
  match shape_type {
    @graph.Cylinder => cylinder_perimeter_segments_like_d2(box)
    @graph.Callout => callout_perimeter_segments_like_d2(box)
    @graph.Document => document_perimeter_segments_like_d2(box)
    _ => []
  }
}

///|
fn cylinder_perimeter_segments_like_d2(
  box : @graph.Box,
) -> Array[(@graph.Point, @graph.Point)] {
  let arc_h = if box.height < D2_DEFAULT_ARC_DEPTH * 2.0 {
    box.height / 2.0
  } else {
    D2_DEFAULT_ARC_DEPTH
  }
  let m = 0.45
  let x0 = box.x
  let x1 = box.x + box.width
  let y0 = box.y
  let y1 = box.y + box.height
  let top_left = @graph.Point::new(x0, y0 + arc_h)
  let top_mid = @graph.Point::new(x0 + box.width / 2.0, y0)
  let top_right = @graph.Point::new(x1, y0 + arc_h)
  let bottom_right = @graph.Point::new(x1, y1 - arc_h)
  let bottom_mid = @graph.Point::new(x0 + box.width / 2.0, y1)
  let bottom_left = @graph.Point::new(x0, y1 - arc_h)
  let segments : Array[(@graph.Point, @graph.Point)] = []

  let top_curve_left = sample_cubic_curve_segments(
    top_left,
    @graph.Point::new(x0, y0),
    @graph.Point::new(x0 + box.width * m, y0),
    top_mid,
    24,
  )
  for s in top_curve_left {
    segments.push(s)
  }
  let top_curve_right = sample_cubic_curve_segments(
    top_mid,
    @graph.Point::new(x1 - box.width * m, y0),
    @graph.Point::new(x1, y0),
    top_right,
    24,
  )
  for s in top_curve_right {
    segments.push(s)
  }

  segments.push((top_right, bottom_right))

  let bottom_curve_right = sample_cubic_curve_segments(
    bottom_right,
    @graph.Point::new(x1, y1),
    @graph.Point::new(x1 - box.width * m, y1),
    bottom_mid,
    24,
  )
  for s in bottom_curve_right {
    segments.push(s)
  }
  let bottom_curve_left = sample_cubic_curve_segments(
    bottom_mid,
    @graph.Point::new(x0 + box.width * m, y1),
    @graph.Point::new(x0, y1),
    bottom_left,
    24,
  )
  for s in bottom_curve_left {
    segments.push(s)
  }

  segments.push((bottom_left, top_left))
  segments
}

///|
fn callout_perimeter_segments_like_d2(
  box : @graph.Box,
) -> Array[(@graph.Point, @graph.Point)] {
  let tip_w = if box.width < 60.0 { box.width / 2.0 } else { 30.0 }
  let tip_h = if box.height < 90.0 { box.height / 2.0 } else { 45.0 }
  let main_h = box.height - tip_h
  let mid_x = box.x + box.width / 2.0
  let points : Array[@graph.Point] = [
    @graph.Point::new(box.x, box.y),
    @graph.Point::new(box.x, box.y + main_h),
    @graph.Point::new(mid_x, box.y + main_h),
    @graph.Point::new(mid_x, box.y + box.height),
    @graph.Point::new(mid_x + tip_w, box.y + main_h),
    @graph.Point::new(box.x + box.width, box.y + main_h),
    @graph.Point::new(box.x + box.width, box.y),
    @graph.Point::new(box.x, box.y),
  ]
  let segments : Array[(@graph.Point, @graph.Point)] = []
  for i in 0..<(points.length() - 1) {
    segments.push((points[i], points[i + 1]))
  }
  segments
}

///|
fn document_perimeter_segments_like_d2(
  box : @graph.Box,
) -> Array[(@graph.Point, @graph.Point)] {
  let base_y = box.y + box.height * (16.3 / 18.925)
  let cp1_y = box.y + box.height * (12.8 / 18.925)
  let cp2_y = box.y + box.height * (19.8 / 18.925)
  let x0 = box.x
  let x1 = box.x + box.width
  let p0 = @graph.Point::new(x1, base_y)
  let p1 = @graph.Point::new(box.x + box.width * (5.0 / 6.0), cp1_y)
  let p2 = @graph.Point::new(box.x + box.width * (2.0 / 3.0), cp1_y)
  let p3 = @graph.Point::new(box.x + box.width * 0.5, base_y)
  let p4 = @graph.Point::new(box.x + box.width * (1.0 / 3.0), cp2_y)
  let p5 = @graph.Point::new(box.x + box.width * (1.0 / 6.0), cp2_y)
  let p6 = @graph.Point::new(x0, base_y)

  let segments : Array[(@graph.Point, @graph.Point)] = [
    (@graph.Point::new(x0, box.y), @graph.Point::new(x1, box.y)),
    (@graph.Point::new(x1, box.y), @graph.Point::new(x1, base_y)),
    (@graph.Point::new(x0, box.y), @graph.Point::new(x0, base_y)),
  ]

  let wave1 = sample_cubic_curve_segments(p0, p1, p2, p3, 24)
  for s in wave1 {
    segments.push(s)
  }
  let wave2 = sample_cubic_curve_segments(p3, p4, p5, p6, 24)
  for s in wave2 {
    segments.push(s)
  }
  segments
}

///|
fn sample_cubic_curve_segments(
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  p3 : @graph.Point,
  n : Int,
) -> Array[(@graph.Point, @graph.Point)] {
  let segments : Array[(@graph.Point, @graph.Point)] = []
  if n <= 1 {
    segments.push((p0, p3))
    return segments
  }
  let mut prev = p0
  for i in 1..<=n {
    let t = i.to_double() / n.to_double()
    let point = cubic_point(p0, p1, p2, p3, t)
    segments.push((prev, point))
    prev = point
  }
  segments
}

///|
fn cubic_point(
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  p3 : @graph.Point,
  t : Double,
) -> @graph.Point {
  let omt = 1.0 - t
  let omt2 = omt * omt
  let t2 = t * t
  let x = omt2 * omt * p0.x +
    3.0 * omt2 * t * p1.x +
    3.0 * omt * t2 * p2.x +
    t2 * t * p3.x
  let y = omt2 * omt * p0.y +
    3.0 * omt2 * t * p1.y +
    3.0 * omt * t2 * p2.y +
    t2 * t * p3.y
  @graph.Point::new(x, y)
}

///|
fn segment_intersection_point(
  a : @graph.Point,
  b : @graph.Point,
  c : @graph.Point,
  d : @graph.Point,
) -> (@graph.Point, Double)? {
  let r_x = b.x - a.x
  let r_y = b.y - a.y
  let s_x = d.x - c.x
  let s_y = d.y - c.y
  let denom = r_x * s_y - r_y * s_x
  if approx_zero(denom) {
    return None
  }
  let cax = c.x - a.x
  let cay = c.y - a.y
  let t = (cax * s_y - cay * s_x) / denom
  let u = (cax * r_y - cay * r_x) / denom
  if t < 0.0 || t > 1.0 || u < 0.0 || u > 1.0 {
    return None
  }
  let ix = a.x + round_double(t * r_x)
  let iy = a.y + round_double(t * r_y)
  Some((@graph.Point::new(ix, iy), t))
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
  let is_bold = style_bool(obj.style.bold, false)
  let is_italic = style_bool(obj.style.italic, false)
  let is_mono = obj.shape_type == @graph.Code ||
    style_is_mono(obj.style.font_family)
  let (label_width, label_height) = measure_object_label_dims(
    obj, font_size, is_mono, is_bold, is_italic,
  )
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
  let raw_name = trim_double_quotes_for_class_member(
    short_name_from_id(child.id),
  )
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
  if last_dot == -1 {
    return id
  }
  let buf = StringBuilder::new()
  let mut i = last_dot + 1
  while i < id.length() {
    match id[i].to_char() {
      Some(ch) => buf.write_char(ch)
      None => ()
    }
    i = i + 1
  }
  buf.to_string()
}

///|
fn label_width(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
) -> Double {
  let font_size = match obj.style.font_size {
    Some(value) => value.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(obj.style.bold, false)
  let is_italic = style_bool(obj.style.italic, false)
  let is_mono = obj.shape_type == @graph.Code ||
    style_is_mono(obj.style.font_family)
  let (width, _) = measure_object_label_dims(
    obj, font_size, is_mono, is_bold, is_italic,
  )
  positive_or(width, config.default_width / 2.0)
}

///|
fn label_height(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
) -> Double {
  let font_size = match obj.style.font_size {
    Some(value) => value.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(obj.style.bold, false)
  let is_italic = style_bool(obj.style.italic, false)
  let is_mono = obj.shape_type == @graph.Code ||
    style_is_mono(obj.style.font_family)
  let (_, height) = measure_object_label_dims(
    obj, font_size, is_mono, is_bold, is_italic,
  )
  positive_or(height, config.default_height / 3.0)
}

///|
priv struct MarkdownBlockMetrics {
  width : Double
  height : Double
  margin_top : Double
  margin_bottom : Double
}

///|
fn markdown_block_metrics_empty() -> MarkdownBlockMetrics {
  { width: 0.0, height: 0.0, margin_top: 0.0, margin_bottom: 0.0 }
}

///|
fn markdown_has_class(obj : @graph.ObjectInput, class_name : String) -> Bool {
  for cls in obj.classes {
    if cls == class_name {
      return true
    }
  }
  false
}

///|
fn markdown_header_font_size(base_font_size : Int, level : Int) -> Int {
  let base = base_font_size.to_double()
  let scaled = match level {
    1 => base * 2.0
    2 => base * 1.5
    3 => base * 1.25
    4 => base * 1.0
    5 => base * 0.875
    6 => base * 0.85
    _ => base
  }
  let out = scaled.to_int()
  if out > 0 {
    out
  } else {
    1
  }
}

///|
fn markdown_inline_dimensions(
  inline : @cmark.Inline,
  font_size : Int,
  line_height : Double,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> (Double, Double) {
  let lines = inline.to_plain_text(break_on_soft=false).to_array()
  let mut max_width = 0.0
  let mut line_count = 0
  for line in lines {
    let text = line.to_array().join("")
    let dims = @text_metrics.measure_label(
      text, font_size, is_mono, is_bold, is_italic,
    )
    if dims.width > max_width {
      max_width = dims.width
    }
    line_count = line_count + 1
  }
  if line_count == 0 {
    line_count = 1
  }
  (max_width, line_height * font_size.to_double() * line_count.to_double())
}

///|
fn markdown_combine_blocks(
  blocks : Array[MarkdownBlockMetrics],
) -> MarkdownBlockMetrics {
  if blocks.is_empty() {
    return markdown_block_metrics_empty()
  }
  let mut width = 0.0
  let mut height = 0.0
  let mut margin_top = 0.0
  let mut margin_bottom = 0.0
  let mut prev_margin_bottom = 0.0
  for i in 0..<blocks.length() {
    let b = blocks[i]
    if i == 0 {
      margin_top = max_double(margin_top, b.margin_top)
    } else {
      let margin_diff = b.margin_top - prev_margin_bottom
      if margin_diff > 0.0 {
        height = height + margin_diff
      }
    }
    if i == blocks.length() - 1 {
      margin_bottom = max_double(margin_bottom, b.margin_bottom)
    } else {
      height = height + b.margin_bottom
      prev_margin_bottom = b.margin_bottom
    }
    height = height + b.height
    width = max_double(width, b.width)
  }
  { width, height, margin_top, margin_bottom }
}

///|
fn markdown_measure_block(
  block : @cmark.Block,
  base_font_size : Int,
  list_depth : Int,
  in_list_item : Bool,
) -> MarkdownBlockMetrics {
  match block {
    @cmark.Block::BlankLine(_)
    | @cmark.Block::HtmlBlock(_)
    | @cmark.Block::LinkRefDefinition(_) => markdown_block_metrics_empty()
    @cmark.Block::Blocks(node) => {
      let parts : Array[MarkdownBlockMetrics] = []
      for child in node.v.to_array() {
        parts.push(
          markdown_measure_block(
            child, base_font_size, list_depth, in_list_item,
          ),
        )
      }
      markdown_combine_blocks(parts)
    }
    @cmark.Block::Paragraph(node) => {
      let (width, height) = markdown_inline_dimensions(
        node.v.inline,
        base_font_size,
        D2_MARKDOWN_LINE_HEIGHT,
        false,
        false,
        false,
      )
      {
        width,
        height,
        margin_top: if in_list_item {
          D2_MARKDOWN_LI_P_MARGIN_TOP
        } else {
          0.0
        },
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    @cmark.Block::Heading(node) => {
      let heading_font_size = markdown_header_font_size(
        base_font_size,
        node.v.level,
      )
      let (width, inline_height) = markdown_inline_dimensions(
        node.v.inline,
        heading_font_size,
        D2_MARKDOWN_LINE_HEIGHT_HEADING,
        false,
        true,
        false,
      )
      let mut height = inline_height
      if node.v.level == 1 || node.v.level == 2 {
        height = height +
          D2_MARKDOWN_H1_H2_PADDING_BOTTOM_EM * heading_font_size.to_double() +
          D2_MARKDOWN_H1_H2_BORDER_BOTTOM
      }
      {
        width,
        height,
        margin_top: D2_MARKDOWN_H_MARGIN_TOP,
        margin_bottom: D2_MARKDOWN_H_MARGIN_BOTTOM,
      }
    }
    @cmark.Block::List(node) => {
      let item_blocks : Array[MarkdownBlockMetrics] = []
      for i in 0..<node.v.items.length() {
        let item = node.v.items[i].v
        let inner = markdown_measure_block(
          item.block,
          base_font_size,
          list_depth + 1,
          true,
        )
        item_blocks.push({
          width: inner.width +
          D2_MARKDOWN_UL_OL_PADDING_LEFT_EM * base_font_size.to_double(),
          height: inner.height,
          margin_top: if i == 0 {
            0.0
          } else {
            D2_MARKDOWN_LI_MARGIN_TOP_EM * base_font_size.to_double()
          },
          margin_bottom: 0.0,
        })
      }
      let merged = markdown_combine_blocks(item_blocks)
      if list_depth == 0 {
        return {
          ..merged,
          margin_bottom: max_double(
            merged.margin_bottom,
            D2_MARKDOWN_UL_MARGIN_BOTTOM,
          ),
        }
      }
      merged
    }
    @cmark.Block::CodeBlock(node) | @cmark.Block::ExtMathBlock(node) => {
      let mut line_count = 0
      let mut max_line_width = 0.0
      let code_font_size = max_int(
        1,
        (base_font_size.to_double() * 0.85).to_int(),
      )
      for line in node.v.code.to_array() {
        let dims = @text_metrics.measure_label(
          line.v,
          code_font_size,
          true,
          false,
          false,
        )
        if dims.width > max_line_width {
          max_line_width = dims.width
        }
        line_count = line_count + 1
      }
      if line_count == 0 {
        line_count = 1
      }
      {
        width: max_line_width + 32.0,
        height: line_count.to_double() *
        base_font_size.to_double() *
        0.85 *
        1.45 +
        32.0,
        margin_top: 0.0,
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    @cmark.Block::ThematicBreak(_) =>
      {
        width: 0.0,
        height: 0.25 * base_font_size.to_double(),
        margin_top: D2_MARKDOWN_H_MARGIN_TOP,
        margin_bottom: D2_MARKDOWN_H_MARGIN_TOP,
      }
    @cmark.Block::BlockQuote(node) => {
      let inner = markdown_measure_block(
        node.v.block,
        base_font_size,
        list_depth,
        false,
      )
      {
        width: inner.width + 2.25 * base_font_size.to_double(),
        height: inner.height,
        margin_top: 0.0,
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    @cmark.Block::ExtTable(node) => {
      let mut max_width = 0.0
      let mut total_height = 0.0
      let row_height = D2_MARKDOWN_LINE_HEIGHT * base_font_size.to_double()
      for row in node.v.rows.to_array() {
        total_height = total_height + row_height
        match row.0.v {
          @cmark.TableRow::Header(cols) | @cmark.TableRow::Data(cols) => {
            let mut row_width = 1.0
            for col in cols.to_array() {
              let (cell_width, _) = markdown_inline_dimensions(
                col.0,
                base_font_size,
                D2_MARKDOWN_LINE_HEIGHT,
                false,
                false,
                false,
              )
              row_width = row_width + cell_width + 17.0
            }
            if row_width > max_width {
              max_width = row_width
            }
          }
          @cmark.TableRow::Sep(cols) => {
            let row_width = cols.length().to_double() *
              (base_font_size.to_double() + 17.0)
            if row_width > max_width {
              max_width = row_width
            }
          }
        }
      }
      {
        width: max_width,
        height: total_height + 2.0,
        margin_top: 0.0,
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    @cmark.Block::ExtFootnoteDefinition(node) =>
      markdown_measure_block(node.v.block, base_font_size, list_depth, false)
  }
}

///|
fn markdown_measure_label_like_d2(
  label : String,
  font_size : Int,
) -> (Double, Double) {
  let doc = @cmark.Doc::from_string(strict=false, label)
  let metrics = markdown_measure_block(doc.block, font_size, 0, false)
  (metrics.width.ceil(), metrics.height.ceil())
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
  if markdown_has_class(obj, "lang:markdown") {
    return markdown_measure_label_like_d2(obj.label, font_size)
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
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
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
