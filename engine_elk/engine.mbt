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
  let (elk_graph, _, _, _) = build_elk_graph(graph, config, direction)
  elk_graph
}

///|
const D2_INNER_LABEL_PADDING : Double = 5.0

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

  let (elk_graph, edge_id_by_index, edge_endpoints_by_index, node_size_by_id) = build_elk_graph(
    graph, config, direction,
  )

  let laid_out_json = @moon_elk_core.new_elk_engine().layout(graph=elk_graph) catch {
    e => raise @engine_api.unsupported("elk layout failed: \{e}")
  }

  let node_box_by_id : Map[String, @graph.Box] = {}
  collect_node_boxes(laid_out_json, 0.0, 0.0, node_box_by_id)
  fill_patch_nodes(patch, graph, node_box_by_id, node_size_by_id, config)

  let routes_by_edge_id : Map[String, Array[@graph.Point]] = {}
  collect_edge_routes(
    laid_out_json, 0.0, 0.0, node_box_by_id, routes_by_edge_id,
  )
  fill_patch_edges(
    patch, graph, edge_id_by_index, edge_endpoints_by_index, node_box_by_id, routes_by_edge_id,
    direction,
  )

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

  let centers : Array[Double] = []
  if !widths.is_empty() {
    centers.push(12.0 + widths[0] / 2.0)
    for i = 1; i < widths.length(); i = i + 1 {
      let base_gap = widths[i - 1] / 2.0 + widths[i] / 2.0 + 50.0
      centers.push(centers[i - 1] + base_gap)
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
    let left = if src_index < dst_index { src_index } else { dst_index }
    let right = if src_index < dst_index { dst_index } else { src_index }
    let (label_width, _) = sequence_edge_label_size(edge)
    let required_span = if label_width > 0.0 { label_width + 56.0 } else { 0.0 }
    let current_span = centers[right] - centers[left]
    if required_span > current_span {
      let delta = required_span - current_span
      for i = right; i < centers.length(); i = i + 1 {
        centers[i] = centers[i] + delta
      }
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
) {
  let (object_by_id, parent_id_by_child_id) = build_object_maps(graph)
  let excluded_node_ids = build_excluded_layout_node_ids(
    graph, parent_id_by_child_id, object_by_id,
  )

  let node_json_by_id : Map[String, Map[String, Json]] = {}
  let node_ids : Map[String, Bool] = {}
  let node_size_by_id : Map[String, (Double, Double)] = {}

  for obj in graph.objects {
    if excluded_node_ids.contains(obj.id) {
      continue
    }
    let (width, height) = object_size(obj, config, object_by_id)
    node_size_by_id[obj.id] = (width, height)

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

    let edge_id = elk_edge_id(edge.index)
    edge_id_by_index[edge.index] = edge_id
    edge_endpoints_by_index[edge.index] = (src_id, dst_id)

    let source_endpoint = edge_endpoint_with_sql_port(
      edge.src_column_index,
      src_id,
      true,
      object_by_id,
    )
    let target_endpoint = edge_endpoint_with_sql_port(
      edge.dst_column_index,
      dst_id,
      false,
      object_by_id,
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

  let root_id = if graph.name.is_empty() { graph.root.id } else { graph.name }
  let root_self_loop_spacing = self_loop_spacing_for_parent(
    graph,
    graph.root.child_ids,
    direction,
  )
  let root_json : Map[String, Json] = {
    "id": Json::string(root_id),
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
  )
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
  for obj in graph.objects {
    if is_sql_or_class_member_node(obj.id, parent_id_by_child_id, object_by_id) {
      excluded[obj.id] = true
    }
  }
  excluded
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
  object_by_id : Map[String, @graph.ObjectInput],
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
    None => resolved_id
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
    match node_box_by_id.get(obj.id) {
      Some(box) => patch.nodes[obj.id] = box
      None => {
        let (width, height) = match node_size_by_id.get(obj.id) {
          Some(v) => v
          None => object_size(obj, config, object_by_id)
        }
        patch.nodes[obj.id] = object_fallback_box(obj, width, height)
      }
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
  let routes_by_index : Map[Int, Array[@graph.Point]] = {}

  for edge in graph.edges {
    let mut route : Array[@graph.Point] = []
    let mut from_elk = false

    match edge_id_by_index.get(edge.index) {
      Some(edge_id) =>
        match routes_by_edge_id.get(edge_id) {
          Some(points) => {
            route = points
            from_elk = true
          }
          None => ()
        }
      None => ()
    }

    if route.length() < 2 {
      match edge_endpoints_by_index.get(edge.index) {
        Some((src_id, dst_id)) =>
          route = fallback_route_from_boxes(
            node_box_by_id, src_id, dst_id, direction,
          )
        None => ()
      }
    }

    if route.length() < 2 {
      route = edge.route
    }

    if route.length() < 2 {
      continue
    }

    if !from_elk {
      match edge_endpoints_by_index.get(edge.index) {
        Some((src_id, dst_id)) =>
          route = clip_route_endpoints(route, node_box_by_id, src_id, dst_id)
        None => ()
      }
    }

    routes_by_index[edge.index] = route
  }

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
  positive_int(config.container_padding, 40)
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

  clip_route_endpoints(route, node_box_by_id, src_id, dst_id)
}

///|
fn clip_route_endpoints(
  route : Array[@graph.Point],
  node_box_by_id : Map[String, @graph.Box],
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

  clipped[0] = box_border_point_towards(src_box, clipped[1])
  let last_index = clipped.length() - 1
  clipped[last_index] = box_border_point_towards(
    dst_box,
    clipped[last_index - 1],
  )

  clipped
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

  let replacement = trace_box_border_like_d2(endpoint_box, probe, end)
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
                if delta < 1.0 {
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
  max_a >= min_b && max_b >= min_a
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
fn trace_box_border_like_d2(
  box : @graph.Box,
  from : @graph.Point,
  to : @graph.Point,
) -> @graph.Point {
  let hit = first_box_intersection_from_point(box, from, to)
  match hit {
    Some(p) => p
    None => box_border_point_towards(box, to)
  }
}

///|
fn first_box_intersection_from_point(
  box : @graph.Box,
  from : @graph.Point,
  to : @graph.Point,
) -> @graph.Point? {
  let sides : Array[(@graph.Point, @graph.Point)] = [
    (box.top_left(), box.top_right()),
    (box.top_right(), box.bottom_right()),
    (box.bottom_right(), box.bottom_left()),
    (box.bottom_left(), box.top_left()),
  ]
  let mut best_t = 1000000000000000000.0
  let mut best : @graph.Point? = None
  for side in sides {
    match segment_intersection_point(from, to, side.0, side.1) {
      Some((p, t)) =>
        if t >= 0.0 && t <= 1.0 && t < best_t {
          best_t = t
          best = Some(p)
        }
      None => ()
    }
  }
  best
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
  if t < -0.000001 || t > 1.000001 || u < -0.000001 || u > 1.000001 {
    return None
  }
  Some((@graph.Point::new(a.x + t * r_x, a.y + t * r_y), t))
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
  match obj.box {
    Some(box) =>
      (
        positive_or(box.width, config.default_width),
        positive_or(box.height, config.default_height),
      )
    None =>
      if obj.shape_type == @graph.SqlTable {
        let (width, height) = estimate_sql_table_size(obj, object_by_id)
        (
          positive_or(width, config.default_width),
          positive_or(height, config.default_height),
        )
      } else {
        estimate_object_size(obj, config)
      }
  }
}

///|
fn estimate_object_size(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
) -> (Double, Double) {
  let font_size = match obj.style.font_size {
    Some(value) => value.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(obj.style.bold, false)
  let is_italic = style_bool(obj.style.italic, true)
  let is_mono = style_is_mono(obj.style.font_family)
  let label_dims = @text_metrics.measure_label(
    obj.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )

  let mut width = config.default_width
  let mut height = config.default_height

  if !obj.label.is_empty() {
    width = max_double(width, label_dims.width + 24.0)
    height = max_double(height, label_dims.height + 24.0)
  }

  if obj.shape_type == @graph.Text {
    width = max_double(label_dims.width, 1.0)
    height = max_double(label_dims.height, 1.0)
  }

  (positive_or(width, 1.0), positive_or(height, 1.0))
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
  let is_italic = style_bool(obj.style.italic, true)
  let is_mono = style_is_mono(obj.style.font_family)
  let dims = @text_metrics.measure_label(
    obj.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  positive_or(dims.width, config.default_width / 2.0)
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
  let is_italic = style_bool(obj.style.italic, true)
  let is_mono = style_is_mono(obj.style.font_family)
  let dims = @text_metrics.measure_label(
    obj.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  positive_or(dims.height, config.default_height / 3.0)
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
fn elk_edge_id(index : Int) -> String {
  "e:\{index}"
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
