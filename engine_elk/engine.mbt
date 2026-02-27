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
pub impl @engine_api.LayoutEngine for ElkEngine with layout(
  _self,
  graph,
  config,
  direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
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

  let node_json_by_id : Map[String, Map[String, Json]] = {}
  let node_ids : Map[String, Bool] = {}
  let node_size_by_id : Map[String, (Double, Double)] = {}

  for obj in graph.objects {
    let (width, height) = object_size(obj, config)
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

    if !obj.child_ids.is_empty() {
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

    node_json_by_id[obj.id] = node_json
    node_ids[obj.id] = true
  }

  let attached_to_parent : Map[String, Bool] = {}
  for obj in graph.objects {
    let parent_node = match node_json_by_id.get(obj.id) {
      Some(node) => node
      None => continue
    }
    let children_json = json_array_field(parent_node, "children")
    for child_id in obj.child_ids {
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
    match node_json_by_id.get(child_id) {
      Some(child_node) => {
        root_children.push(Json::object(child_node))
        attached_to_root[child_id] = true
      }
      None => ()
    }
  }
  for obj in graph.objects {
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

    let edge_json : Map[String, Json] = {
      "id": Json::string(edge_id),
      "sources": Json::array([Json::string(src_id)]),
      "targets": Json::array([Json::string(dst_id)]),
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
fn fill_patch_nodes(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  node_box_by_id : Map[String, @graph.Box],
  node_size_by_id : Map[String, (Double, Double)],
  config : @engine_api.LayoutConfig,
) -> Unit {
  for obj in graph.objects {
    match node_box_by_id.get(obj.id) {
      Some(box) => patch.nodes[obj.id] = box
      None => {
        let (width, height) = match node_size_by_id.get(obj.id) {
          Some(v) => v
          None => object_size(obj, config)
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
  for edge in graph.edges {
    let mut route : Array[@graph.Point] = []

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

    match edge_endpoints_by_index.get(edge.index) {
      Some((src_id, dst_id)) =>
        route = clip_route_endpoints(route, node_box_by_id, src_id, dst_id)
      None => ()
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
) -> (Double, Double) {
  match obj.box {
    Some(box) =>
      (
        positive_or(box.width, config.default_width),
        positive_or(box.height, config.default_height),
      )
    None => estimate_object_size(obj, config)
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
