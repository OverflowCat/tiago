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
/// Dagre-backed layout engine.
///
/// Uses moon_dagre for graph layout.

///|
pub struct DagreEngine {
  _marker : Unit
} derive(Show)

///|
pub fn DagreEngine::new() -> DagreEngine {
  { _marker: () }
}

///|
priv struct EdgeLayoutInfo {
  edge_index : Int
  src_id : String
  dst_id : String
  src_arrow : Bool
  dst_arrow : Bool
}

///|
const D2_EDGE_LABEL_GAP : Double = 20.0

///|
const D2_LABEL_PADDING : Double = 5.0

///|
const D2_MAX_ICON_SIZE : Double = 64.0

///|
const D2_THREE_DEE_OFFSET : Double = 15.0

///|
const D2_MULTIPLE_OFFSET : Double = 10.0

///|
const D2_MIN_SEGMENT_LEN : Double = 10.0

///|
const D2_MIN_SHAPE_SIZE : Double = 5.0

///|
const D2_INNER_LABEL_PADDING : Double = 5.0

///|
const D2_DEFAULT_PADDING : Double = 40.0

///|
const D2_CONTAINER_PADDING : Double = 30.0

///|
const D2_CONTAINER_MIN_SPACING : Double = 10.0

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
const D2_DEFAULT_ARC_DEPTH : Double = 24.0

///|
const D2_PARALLELOGRAM_WEDGE_WIDTH : Double = 26.0

///|
const D2_STORED_DATA_WEDGE_WIDTH : Double = 15.0

///|
const D2_STEP_WEDGE_WIDTH : Double = 35.0

///|
const D2_PACKAGE_TOP_MIN_WIDTH : Double = 50.0

///|
const D2_PACKAGE_TOP_MAX_WIDTH : Double = 150.0

///|
const D2_PACKAGE_HORIZONTAL_SCALAR : Double = 0.5

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
pub impl @engine_api.LayoutEngine for DagreEngine with layout(
  _self,
  graph,
  config,
  direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  if graph.root.shape_type == @graph.SequenceDiagram {
    return layout_sequence_diagram(graph, config)
  }
  let (
    dagre_graph,
    edge_layout_by_key,
    node_size_by_id,
    dagre_node_id_by_object_id,
    parent_id_by_child_id,
  ) = build_dagre_graph(graph, config, direction)
  let laid_out_graph = @moon_dagre.layout(dagre_graph)
  let patch = @graph.LayoutPatch::new()
  copy_passthrough_layout_data(patch, graph)
  fill_patch_nodes(
    patch, laid_out_graph, graph, node_size_by_id, dagre_node_id_by_object_id, config,
  )
  fill_patch_edges(patch, laid_out_graph, edge_layout_by_key, direction)
  orient_edge_routes_to_semantic_direction(patch, graph, parent_id_by_child_id)
  let mirrored_pre = maybe_unmirror_layout(
    patch, graph, direction, parent_id_by_child_id,
  )
  adjust_rank_spacing(
    patch,
    graph,
    parent_id_by_child_id,
    d2_ranksep(graph, direction),
    direction == Right || direction == Left,
  )
  adjust_cross_rank_spacing(
    patch,
    graph,
    parent_id_by_child_id,
    !(direction == Right || direction == Left),
  )
  fit_container_boxes(patch, graph, parent_id_by_child_id)
  if !mirrored_pre {
    ignore(
      maybe_unmirror_layout(patch, graph, direction, parent_id_by_child_id),
    )
  }
  trace_routes_to_object_boundaries(patch, graph)
  convert_dagre_routes_to_d2_curves(patch, graph)
  recompute_edge_label_boxes(patch, graph)
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
    let start_x = src_x
    let end_x = dst_x
    patch.edges[edge.index] = [
      @graph.Point::new(start_x, y),
      @graph.Point::new(end_x, y),
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
fn copy_passthrough_layout_data(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  for ab in graph.activation_boxes {
    patch.activation_boxes.push(ab)
  }
  for note in graph.sequence_notes {
    patch.sequence_notes.push(note)
  }
  for fragment in graph.sequence_fragments_layout {
    patch.sequence_fragments.push(fragment)
  }
}

///|
fn build_dagre_graph(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> (
  @moon_dagre.Graph,
  Map[String, EdgeLayoutInfo],
  Map[String, (Double, Double)],
  Map[String, String],
  Map[String, String],
) raise @engine_api.LayoutError {
  let dagre_graph = @moon_dagre.new_graph(multigraph=true, compound=true)
  dagre_graph.set_graph(make_dagre_graph_attrs(config, graph, direction))

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

  let node_ids : Map[String, Bool] = {}
  let node_size_by_id : Map[String, (Double, Double)] = {}
  let dagre_node_id_by_object_id : Map[String, String] = {}
  for i, obj in graph.objects {
    if collapse_sql_or_class_endpoint_id(
        obj.id,
        object_by_id,
        parent_id_by_child_id,
      ) !=
      obj.id {
      continue
    }
    node_ids[obj.id] = true
    let dagre_id = dagre_node_id(i, obj.id)
    dagre_node_id_by_object_id[obj.id] = dagre_id
    let (width, height) = object_size(obj, config, object_by_id)
    node_size_by_id[obj.id] = (width, height)
    let node_attrs = @moon_dagre.empty_attrs()
    node_attrs.set_float("width", width)
    node_attrs.set_float("height", height)
    dagre_graph.set_node(dagre_id, label=node_attrs)
  }

  for parent in graph.objects {
    let parent_dagre_id = match dagre_node_id_by_object_id.get(parent.id) {
      Some(v) => v
      None => continue
    }
    for child_id in parent.child_ids {
      if child_id == parent.id || !node_ids.contains(child_id) {
        continue
      }
      match dagre_node_id_by_object_id.get(child_id) {
        Some(child_dagre_id) =>
          dagre_graph.set_parent(child_dagre_id, parent=parent_dagre_id)
        None => ()
      }
    }
  }

  let layout_endpoints_by_edge_index : Map[Int, (String, String)] = {}
  let parallel_edge_count_by_pair : Map[String, Int] = {}
  for edge in graph.edges {
    let resolved_endpoints = resolve_edge_layout_endpoints(
      graph, edge, object_by_id, parent_id_by_child_id,
    )
    let layout_endpoints = if edge.src_arrow && !edge.dst_arrow {
      (resolved_endpoints.1, resolved_endpoints.0)
    } else {
      resolved_endpoints
    }
    layout_endpoints_by_edge_index[edge.index] = layout_endpoints
    let pair_key = unordered_edge_pair_key(
      layout_endpoints.0,
      layout_endpoints.1,
    )
    parallel_edge_count_by_pair[pair_key] = parallel_edge_count_by_pair.get_or_default(
        pair_key, 0,
      ) +
      1
  }

  let edge_layout_by_key : Map[String, EdgeLayoutInfo] = {}
  for edge in graph.edges {
    let (layout_src_id, layout_dst_id) = match
      layout_endpoints_by_edge_index.get(edge.index) {
      Some(v) => v
      None => {
        let resolved = resolve_edge_layout_endpoints(
          graph, edge, object_by_id, parent_id_by_child_id,
        )
        if edge.src_arrow && !edge.dst_arrow {
          (resolved.1, resolved.0)
        } else {
          resolved
        }
      }
    }
    if !node_ids.contains(layout_src_id) || !node_ids.contains(layout_dst_id) {
      raise @engine_api.invalid_graph(
        "dagre edge endpoint not found: \{layout_src_id} -> \{layout_dst_id}",
      )
    }
    let src_dagre_id = match dagre_node_id_by_object_id.get(layout_src_id) {
      Some(v) => v
      None =>
        raise @engine_api.invalid_graph(
          "dagre edge endpoint not found: \{layout_src_id} -> \{layout_dst_id}",
        )
    }
    let dst_dagre_id = match dagre_node_id_by_object_id.get(layout_dst_id) {
      Some(v) => v
      None =>
        raise @engine_api.invalid_graph(
          "dagre edge endpoint not found: \{layout_src_id} -> \{layout_dst_id}",
        )
    }
    let arrow = if edge.src_arrow && !edge.dst_arrow {
      "<-"
    } else if edge.src_arrow && edge.dst_arrow {
      "<->"
    } else {
      "->"
    }
    let edge_name = "(\{edge.src_id} \{arrow} \{edge.dst_id})[\{edge.index}]"
    let pair_key = unordered_edge_pair_key(layout_src_id, layout_dst_id)
    let parallel_edge_count = parallel_edge_count_by_pair.get_or_default(
      pair_key, 1,
    )
    let edge_attrs = make_dagre_edge_attrs(edge, direction, parallel_edge_count)
    dagre_graph.set_edge(
      src_dagre_id,
      dst_dagre_id,
      label=@moon_dagre.attrs_value(edge_attrs),
      name=edge_name,
    )
    let semantic_src_id = collapse_sql_or_class_endpoint_id(
      edge.src_id,
      object_by_id,
      parent_id_by_child_id,
    )
    let semantic_dst_id = collapse_sql_or_class_endpoint_id(
      edge.dst_id,
      object_by_id,
      parent_id_by_child_id,
    )
    edge_layout_by_key[dagre_edge_key(
      src_dagre_id,
      dst_dagre_id,
      Some(edge_name),
    )] = {
      edge_index: edge.index,
      src_id: semantic_src_id,
      dst_id: semantic_dst_id,
      src_arrow: edge.src_arrow,
      dst_arrow: edge.dst_arrow,
    }
  }

  (
    dagre_graph, edge_layout_by_key, node_size_by_id, dagre_node_id_by_object_id,
    parent_id_by_child_id,
  )
}

///|
fn make_dagre_graph_attrs(
  config : @engine_api.LayoutConfig,
  graph : @graph.GraphInput,
  direction : @engine_api.Direction,
) -> @moon_dagre.Attrs {
  let attrs = @moon_dagre.empty_attrs()
  let (nodesep, ranksep) = spacing_for_direction(config, graph, direction)
  attrs.set_string("rankdir", rankdir_from_direction(direction))
  attrs.set_float("nodesep", nodesep)
  attrs.set_float("ranksep", ranksep)
  attrs.set_float("edgesep", clamp_positive(config.edge_padding, 20.0))
  // D2 dagre output does not add graph-level margin here.
  attrs.set_float("marginx", 0.0)
  attrs.set_float("marginy", 0.0)
  attrs
}

///|
fn spacing_for_direction(
  config : @engine_api.LayoutConfig,
  graph : @graph.GraphInput,
  direction : @engine_api.Direction,
) -> (Double, Double) {
  let nodesep = d2_nodesep(config.horizontal_spacing)
  let ranksep = d2_ranksep(graph, direction)
  (nodesep, ranksep)
}

///|
fn d2_nodesep(value : Double) -> Double {
  let base = clamp_positive(value, 60.0)
  if base < 60.0 {
    60.0
  } else {
    base
  }
}

///|
fn d2_ranksep(
  graph : @graph.GraphInput,
  direction : @engine_api.Direction,
) -> Double {
  let mut max_label_width = 0.0
  let mut max_label_height = 0.0
  for edge in graph.edges {
    match edge_label_size(edge) {
      Some((width, height)) => {
        if width > max_label_width {
          max_label_width = width
        }
        if height > max_label_height {
          max_label_height = height
        }
      }
      None => ()
    }
  }
  let base = match direction {
    Right | Left => max_label_width + 40.0
    Down | Up => max_label_height + 40.0
  }
  if base < 100.0 {
    100.0
  } else {
    base
  }
}

///|
fn rankdir_from_direction(direction : @engine_api.Direction) -> String {
  match direction {
    Down => "tb"
    Right => "lr"
    Up => "bt"
    Left => "rl"
  }
}

///|
fn resolve_edge_layout_endpoints(
  graph : @graph.GraphInput,
  edge : @graph.EdgeInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> (String, String) {
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
  let src = resolve_container_endpoint(
    graph, src_id, true, object_by_id, parent_id_by_child_id,
  )
  let dst = resolve_container_endpoint(
    graph, dst_id, false, object_by_id, parent_id_by_child_id,
  )
  (src, dst)
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
fn resolve_container_endpoint(
  graph : @graph.GraphInput,
  id : String,
  source : Bool,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> String {
  let mut endpoint = id
  while true {
    let obj = match object_by_id.get(endpoint) {
      Some(v) => v
      None => break
    }
    if !is_layout_container_candidate(obj) {
      break
    }
    let next = if source {
      get_longest_edge_chain_tail_id(
        graph, obj, object_by_id, parent_id_by_child_id,
      )
    } else {
      get_longest_edge_chain_head_id(
        graph, obj, object_by_id, parent_id_by_child_id,
      )
    }
    if next == endpoint {
      break
    }
    endpoint = next
  }
  endpoint
}

///|
fn is_layout_container_candidate(obj : @graph.ObjectInput) -> Bool {
  !obj.child_ids.is_empty() &&
  obj.shape_type != @graph.Class &&
  obj.shape_type != @graph.SqlTable
}

///|
fn get_longest_edge_chain_head_id(
  graph : @graph.GraphInput,
  container : @graph.ObjectInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> String {
  let children : Array[String] = []
  let child_set : Map[String, Bool] = {}
  for child_id in container.child_ids {
    if object_by_id.contains(child_id) {
      children.push(child_id)
      child_set[child_id] = true
    }
  }
  if children.is_empty() {
    return container.id
  }

  let rank : Map[String, Int] = {}
  let chain_length : Map[String, Int] = {}
  for child_id in children {
    let mut is_head = true
    for edge in graph.edges {
      if in_container(edge.src_id, container.id, parent_id_by_child_id)
        is Some(_) &&
        in_container(edge.dst_id, child_id, parent_id_by_child_id) is Some(_) {
        is_head = false
        break
      }
    }
    if !is_head {
      continue
    }
    rank[child_id] = 1
    chain_length[child_id] = 1
    let queue : Array[String] = [child_id]
    let visited : Map[String, Bool] = {}
    let mut i = 0
    while i < queue.length() {
      let curr = queue[i]
      i = i + 1
      if visited.contains(curr) {
        continue
      }
      visited[curr] = true
      let curr_rank = rank.get_or_default(curr, 1)
      for edge in graph.edges {
        let child = match
          in_container(edge.dst_id, container.id, parent_id_by_child_id) {
          Some(v) => v
          None => continue
        }
        if child == curr || child == container.id || !child_set.contains(child) {
          continue
        }
        if in_container(edge.src_id, curr, parent_id_by_child_id) is Some(_) {
          let candidate_rank = curr_rank + 1
          if candidate_rank > rank.get_or_default(child, 0) {
            rank[child] = candidate_rank
            let best_for_head = chain_length.get_or_default(child_id, 1)
            if candidate_rank > best_for_head {
              chain_length[child_id] = candidate_rank
            }
          }
          queue.push(child)
        }
      }
    }
  }

  let mut max_chain = 0
  for child_id in children {
    let chain = chain_length.get_or_default(child_id, 0)
    if chain > max_chain {
      max_chain = chain
    }
  }
  let heads : Array[String] = []
  for child_id in children {
    if rank.get_or_default(child_id, 0) == 1 &&
      chain_length.get_or_default(child_id, 0) == max_chain {
      heads.push(child_id)
    }
  }
  if heads.is_empty() {
    children[0]
  } else {
    heads[heads.length() / 2]
  }
}

///|
fn get_longest_edge_chain_tail_id(
  graph : @graph.GraphInput,
  container : @graph.ObjectInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> String {
  let children : Array[String] = []
  let child_set : Map[String, Bool] = {}
  for child_id in container.child_ids {
    if object_by_id.contains(child_id) {
      children.push(child_id)
      child_set[child_id] = true
    }
  }
  if children.is_empty() {
    return container.id
  }

  let rank : Map[String, Int] = {}
  for child_id in children {
    let mut is_head = true
    for edge in graph.edges {
      if in_container(edge.src_id, container.id, parent_id_by_child_id)
        is Some(_) &&
        in_container(edge.dst_id, child_id, parent_id_by_child_id) is Some(_) {
        is_head = false
        break
      }
    }
    if !is_head {
      continue
    }
    rank[child_id] = 1
    let queue : Array[String] = [child_id]
    let visited : Map[String, Bool] = {}
    let mut i = 0
    while i < queue.length() {
      let curr = queue[i]
      i = i + 1
      if visited.contains(curr) {
        continue
      }
      visited[curr] = true
      let curr_rank = rank.get_or_default(curr, 1)
      for edge in graph.edges {
        let child = match
          in_container(edge.dst_id, container.id, parent_id_by_child_id) {
          Some(v) => v
          None => continue
        }
        if child == curr || child == container.id || !child_set.contains(child) {
          continue
        }
        if in_container(edge.src_id, curr, parent_id_by_child_id) is Some(_) {
          let candidate_rank = curr_rank + 1
          if candidate_rank > rank.get_or_default(child, 0) {
            rank[child] = candidate_rank
          }
          queue.push(child)
        }
      }
    }
  }

  let mut max_rank = 0
  for child_id in children {
    let value = rank.get_or_default(child_id, 0)
    if value > max_rank {
      max_rank = value
    }
  }
  let tails : Array[String] = []
  for child_id in children {
    if rank.get_or_default(child_id, 0) == max_rank {
      tails.push(child_id)
    }
  }
  if tails.is_empty() {
    children[0]
  } else {
    tails[tails.length() / 2]
  }
}

///|
fn in_container(
  obj_id : String,
  container_id : String,
  parent_id_by_child_id : Map[String, String],
) -> String? {
  if obj_id == container_id {
    return Some(obj_id)
  }
  let mut curr = obj_id
  while true {
    let parent = match parent_id_by_child_id.get(curr) {
      Some(v) => v
      None => return None
    }
    if parent == container_id {
      return Some(curr)
    }
    curr = parent
  }
  None
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
        clamp_positive(box.width, config.default_width),
        clamp_positive(box.height, config.default_height),
      )
    None =>
      if obj.shape_type == @graph.SqlTable {
        let (width, height) = estimate_sql_table_size(obj, object_by_id)
        (
          clamp_positive(width, config.default_width),
          clamp_positive(height, config.default_height),
        )
      } else {
        estimate_object_size(obj, config, object_by_id)
      }
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
fn make_dagre_edge_attrs(
  edge : @graph.EdgeInput,
  direction : @engine_api.Direction,
  parallel_edge_count : Int,
) -> @moon_dagre.Attrs {
  let attrs = @moon_dagre.empty_attrs()
  attrs.set_string("labelpos", "c")
  attrs.set_float(
    "weight",
    clamp_positive(edge.reference_count.to_double(), 1.0),
  )
  match edge_label_size(edge) {
    Some((base_width, base_height)) => {
      let mut width = base_width
      let mut height = base_height
      if parallel_edge_count > 1 {
        match direction {
          Down | Up => width = width + D2_EDGE_LABEL_GAP
          Right | Left => height = height + D2_EDGE_LABEL_GAP
        }
      }
      attrs.set_float("width", width)
      attrs.set_float("height", height)
    }
    None => ()
  }
  attrs
}

///|
fn unordered_edge_pair_key(a : String, b : String) -> String {
  if a <= b {
    a + "\u0003" + b
  } else {
    b + "\u0003" + a
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
fn fill_patch_nodes(
  patch : @graph.LayoutPatch,
  dagre_graph : @moon_dagre.Graph,
  graph : @graph.GraphInput,
  node_size_by_id : Map[String, (Double, Double)],
  dagre_node_id_by_object_id : Map[String, String],
  config : @engine_api.LayoutConfig,
) -> Unit {
  for obj in graph.objects {
    let dagre_id = match dagre_node_id_by_object_id.get(obj.id) {
      Some(v) => v
      None => continue
    }
    match dagre_graph.node_opt(dagre_id) {
      Some(node_attrs) => {
        let (fallback_width, fallback_height) = match
          node_size_by_id.get(obj.id) {
          Some(size) => size
          None =>
            (
              clamp_positive(config.default_width, 100.0),
              clamp_positive(config.default_height, 60.0),
            )
        }
        match box_from_dagre_node(node_attrs, fallback_width, fallback_height) {
          Some(box) => patch.nodes[obj.id] = box
          None => ()
        }
      }
      None => ()
    }
  }
}

///|
fn box_from_dagre_node(
  attrs : @moon_dagre.Attrs,
  fallback_width : Double,
  fallback_height : Double,
) -> @graph.Box? {
  guard attrs.get_float("x") is Some(x) && attrs.get_float("y") is Some(y) else {
    return None
  }
  let raw_width = clamp_positive(
    attrs.get_float_or("width", fallback_width),
    fallback_width,
  )
  let raw_height = clamp_positive(
    attrs.get_float_or("height", fallback_height),
    fallback_height,
  )
  let width = raw_width.ceil()
  let height = raw_height.ceil()
  // Match d2dagrelayout: round center-offset computed from raw dagre size.
  let left = round_double(x - raw_width / 2.0)
  let top = round_double(y - raw_height / 2.0)
  Some(@graph.Box::new(left, top, width, height))
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
fn dagre_node_id(order : Int, obj_id : String) -> String {
  let _ = obj_id
  order.to_string()
}

///|
fn fill_patch_edges(
  patch : @graph.LayoutPatch,
  dagre_graph : @moon_dagre.Graph,
  edge_layout_by_key : Map[String, EdgeLayoutInfo],
  direction : @engine_api.Direction,
) -> Unit {
  let routes_by_pair : Map[String, Array[(Int, Array[@graph.Point])]] = {}
  for edge_obj in dagre_graph.edges() {
    let key = dagre_edge_key(edge_obj.v, edge_obj.w, edge_obj.name)
    match edge_layout_by_key.get(key) {
      Some(info) => {
        let edge_attrs = @moon_dagre.value_as_attrs(
          dagre_graph.edge_obj(edge_obj),
        )
        match edge_attrs {
          Some(attrs) =>
            match attrs.get_points("points") {
              Some(points) => {
                let route = points_to_route(points)
                let normalized_route = if info.src_arrow && !info.dst_arrow {
                  reverse_route(route)
                } else {
                  route
                }
                let chopped = chop_route_to_endpoint_boxes(
                  normalized_route,
                  patch.nodes,
                  info.src_id,
                  info.dst_id,
                )
                patch.edges[info.edge_index] = chopped
                let pair_key = unordered_edge_pair_key(info.src_id, info.dst_id)
                let group = routes_by_pair.get_or_default(pair_key, [])
                group.push((info.edge_index, chopped))
                routes_by_pair[pair_key] = group
              }
              None => ()
            }
          None => ()
        }
      }
      None => ()
    }
  }
  stabilize_parallel_edge_routes(patch, routes_by_pair, direction)
}

///|
fn orient_edge_routes_to_semantic_direction(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  parent_id_by_child_id : Map[String, String],
) -> Unit {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  for edge in graph.edges {
    let route = match patch.edges.get(edge.index) {
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
    let src_box = match patch.nodes.get(src_id) {
      Some(v) => v
      None => continue
    }
    let dst_box = match patch.nodes.get(dst_id) {
      Some(v) => v
      None => continue
    }
    let src_center = @graph.Point::new(
      src_box.x + src_box.width / 2.0,
      src_box.y + src_box.height / 2.0,
    )
    let dst_center = @graph.Point::new(
      dst_box.x + dst_box.width / 2.0,
      dst_box.y + dst_box.height / 2.0,
    )
    let start = route[0]
    let end = route[route.length() - 1]
    let forward_score = point_distance(start, src_center) +
      point_distance(end, dst_center)
    let reverse_score = point_distance(start, dst_center) +
      point_distance(end, src_center)
    if reverse_score + 0.000001 < forward_score {
      patch.edges[edge.index] = reverse_route(route)
    }
  }
}

///|
fn reverse_route(route : Array[@graph.Point]) -> Array[@graph.Point] {
  let out : Array[@graph.Point] = []
  let mut i = route.length()
  while i > 0 {
    i = i - 1
    out.push(route[i])
  }
  out
}

///|
fn stabilize_parallel_edge_routes(
  patch : @graph.LayoutPatch,
  routes_by_pair : Map[String, Array[(Int, Array[@graph.Point])]],
  direction : @engine_api.Direction,
) -> Unit {
  for _, group in routes_by_pair {
    if group.length() <= 1 {
      continue
    }
    let edge_indices : Array[Int] = []
    let route_entries : Array[(Double, Array[@graph.Point])] = []
    for entry in group {
      let edge_index = entry.0
      let route = entry.1
      let axis = parallel_route_axis(route, direction)
      edge_indices.push(edge_index)
      route_entries.push((axis, route))
    }
    let sorted_edge_indices = sort_ints_asc(edge_indices)
    let sorted_routes = sort_route_entries_by_axis(route_entries)
    let mut i = 0
    while i < sorted_edge_indices.length() && i < sorted_routes.length() {
      patch.edges[sorted_edge_indices[i]] = sorted_routes[i].1
      i = i + 1
    }
  }
}

///|
fn maybe_unmirror_layout(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  direction : @engine_api.Direction,
  parent_id_by_child_id : Map[String, String],
) -> Bool {
  if direction != Down && direction != Up {
    return false
  }

  let object_index : Map[String, Int] = {}
  for i, obj in graph.objects {
    object_index[obj.id] = i
  }

  let mut should_mirror = false

  let top_level_ids : Array[String] = []
  for obj in graph.objects {
    if parent_id_by_child_id.contains(obj.id) {
      continue
    }
    if patch.nodes.contains(obj.id) {
      top_level_ids.push(obj.id)
    }
  }

  let ids_by_rank : Map[Int, Array[String]] = {}
  for id in top_level_ids {
    match patch.nodes.get(id) {
      Some(box) => {
        let rank_key = round_double(box.y).to_int()
        let group = ids_by_rank.get_or_default(rank_key, [])
        group.push(id)
        ids_by_rank[rank_key] = group
      }
      None => ()
    }
  }

  let mut saw_multi_rank = false
  let mut all_rank_reversed = true
  for _, ids in ids_by_rank {
    if ids.length() <= 1 {
      continue
    }
    saw_multi_rank = true
    let x_order = ids.copy()
    x_order.sort_by((a, b) => {
      let a_box = patch.nodes.get(a).unwrap()
      let b_box = patch.nodes.get(b).unwrap()
      let ax = a_box.x + a_box.width / 2.0
      let bx = b_box.x + b_box.width / 2.0
      if ax < bx {
        -1
      } else if ax > bx {
        1
      } else {
        object_index.get_or_default(a, 0) - object_index.get_or_default(b, 0)
      }
    })

    let def_order = ids.copy()
    def_order.sort_by((a, b) => {
      object_index.get_or_default(a, 0) - object_index.get_or_default(b, 0)
    })
    let def_rev = reverse_ids(def_order)
    if !ids_equal(x_order, def_rev) {
      all_rank_reversed = false
      break
    }
  }
  if saw_multi_rank && all_rank_reversed {
    should_mirror = true
  }

  if !should_mirror && top_level_ids.length() > 1 {
    let first_id = top_level_ids[0]
    let last_id = top_level_ids[top_level_ids.length() - 1]
    if patch.nodes.contains(first_id) && patch.nodes.contains(last_id) {
      let first_box = patch.nodes.get(first_id).unwrap()
      let last_box = patch.nodes.get(last_id).unwrap()
      let first_center = first_box.x + first_box.width / 2.0
      let last_center = last_box.x + last_box.width / 2.0
      if first_center > last_center + 1.0 {
        should_mirror = true
      }
    }
  }

  if !should_mirror {
    let mut min_depth = 1000000
    for parent in graph.objects {
      if parent.child_ids.length() <= 1 {
        continue
      }
      let child_ids : Array[String] = []
      for child_id in parent.child_ids {
        if patch.nodes.contains(child_id) {
          child_ids.push(child_id)
        }
      }
      if child_ids.length() <= 1 {
        continue
      }
      let depth = object_depth_from_id(parent.id)
      if depth < min_depth {
        min_depth = depth
      }
    }

    if min_depth < 1000000 {
      let mut reversed_groups = 0
      let mut forward_groups = 0
      for parent in graph.objects {
        if object_depth_from_id(parent.id) != min_depth {
          continue
        }
        if parent.child_ids.length() <= 1 {
          continue
        }
        let child_ids : Array[String] = []
        for child_id in parent.child_ids {
          if patch.nodes.contains(child_id) {
            child_ids.push(child_id)
          }
        }
        if child_ids.length() <= 1 {
          continue
        }

        let first_id = child_ids[0]
        let last_id = child_ids[child_ids.length() - 1]
        let first_box = patch.nodes.get(first_id).unwrap()
        let last_box = patch.nodes.get(last_id).unwrap()
        let first_center = first_box.x + first_box.width / 2.0
        let last_center = last_box.x + last_box.width / 2.0
        if first_center > last_center + 1.0 {
          reversed_groups = reversed_groups + 1
        } else if first_center + 1.0 < last_center {
          forward_groups = forward_groups + 1
        }
      }
      if reversed_groups > forward_groups {
        should_mirror = true
      }
    }
  }

  if !should_mirror {
    let object_by_id : Map[String, @graph.ObjectInput] = {}
    for obj in graph.objects {
      object_by_id[obj.id] = obj
    }
    let targets_by_src : Map[String, Array[String]] = {}
    for edge in graph.edges {
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
      if src_id == dst_id ||
        !patch.nodes.contains(src_id) ||
        !patch.nodes.contains(dst_id) {
        continue
      }
      let targets = targets_by_src.get_or_default(src_id, [])
      let mut exists = false
      for id in targets {
        if id == dst_id {
          exists = true
          break
        }
      }
      if !exists {
        targets.push(dst_id)
        targets_by_src[src_id] = targets
      }
    }
    let mut reversed_fanout = 0
    let mut forward_fanout = 0
    for _, targets in targets_by_src {
      if targets.length() <= 1 {
        continue
      }
      let x_order = targets.copy()
      x_order.sort_by((a, b) => {
        let a_box = patch.nodes.get(a).unwrap()
        let b_box = patch.nodes.get(b).unwrap()
        let ax = a_box.x + a_box.width / 2.0
        let bx = b_box.x + b_box.width / 2.0
        if ax < bx {
          -1
        } else if ax > bx {
          1
        } else {
          object_index.get_or_default(a, 0) - object_index.get_or_default(b, 0)
        }
      })
      let def_order = targets.copy()
      def_order.sort_by((a, b) => {
        object_index.get_or_default(a, 0) - object_index.get_or_default(b, 0)
      })
      let def_rev = reverse_ids(def_order)
      if ids_equal(x_order, def_rev) {
        reversed_fanout = reversed_fanout + 1
      } else if ids_equal(x_order, def_order) {
        forward_fanout = forward_fanout + 1
      }
    }
    if reversed_fanout > forward_fanout && reversed_fanout > 0 {
      should_mirror = true
    }
  }

  if !should_mirror {
    return false
  }

  let mut min_x = 1000000000000.0
  let mut max_x = -1000000000000.0
  let mut seen = false
  for _, box in patch.nodes {
    seen = true
    if box.x < min_x {
      min_x = box.x
    }
    let right = box.x + box.width
    if right > max_x {
      max_x = right
    }
  }
  if !seen {
    return false
  }
  let axis_sum = min_x + max_x

  for id, box in patch.nodes {
    patch.nodes[id] = @graph.Box::new(
      axis_sum - box.x - box.width,
      box.y,
      box.width,
      box.height,
    )
  }
  for edge_index, route in patch.edges {
    let mirrored : Array[@graph.Point] = []
    for p in route {
      mirrored.push(@graph.Point::new(axis_sum - p.x, p.y))
    }
    patch.edges[edge_index] = mirrored
  }
  for edge_index, label_box in patch.edge_labels {
    patch.edge_labels[edge_index] = @graph.Box::new(
      axis_sum - label_box.x - label_box.width,
      label_box.y,
      label_box.width,
      label_box.height,
    )
  }

  let object_by_id : Map[String, @graph.ObjectInput] = {}
  let mut has_container_object = false
  for obj in graph.objects {
    object_by_id[obj.id] = obj
    if !obj.child_ids.is_empty() {
      has_container_object = true
    }
  }
  if !has_container_object {
    for id, box in patch.nodes {
      match object_by_id.get(id) {
        Some(obj) => {
          let mut nudge_x = 0.0
          if obj.shape_type == @graph.Person {
            nudge_x = 1.0
          } else if obj.shape_type == @graph.Cylinder {
            let incoming = incoming_edge_count(graph, id)
            if incoming >= 2 && round_double(box.width).to_int() % 2 != 0 {
              nudge_x = 1.0
            }
          }
          if nudge_x != 0.0 {
            patch.nodes[id] = @graph.Box::new(
              box.x + nudge_x,
              box.y,
              box.width,
              box.height,
            )
          }
        }
        None => ()
      }
    }
  } else {
    let axis_center = axis_sum / 2.0
    for id, box in patch.nodes {
      match object_by_id.get(id) {
        Some(obj) =>
          if obj.shape_type == @graph.Rectangle &&
            obj.child_ids.is_empty() &&
            object_depth_from_id(id) <= 2 &&
            round_double(box.width).to_int() % 2 != 0 &&
            box.x + box.width / 2.0 < axis_center {
            patch.nodes[id] = @graph.Box::new(
              box.x + 1.0,
              box.y,
              box.width,
              box.height,
            )
          }
        None => ()
      }
    }
  }

  true
}

///|
fn incoming_edge_count(graph : @graph.GraphInput, obj_id : String) -> Int {
  let mut count = 0
  for edge in graph.edges {
    if edge.dst_id == obj_id {
      count = count + 1
    }
  }
  count
}

///|
fn reverse_ids(ids : Array[String]) -> Array[String] {
  let out : Array[String] = []
  let mut i = ids.length()
  while i > 0 {
    i = i - 1
    out.push(ids[i])
  }
  out
}

///|
fn ids_equal(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut i = 0
  while i < a.length() {
    if a[i] != b[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|

///|
fn parallel_route_axis(
  route : Array[@graph.Point],
  direction : @engine_api.Direction,
) -> Double {
  if route.is_empty() {
    return 0.0
  }
  let start = route[0]
  let end = route[route.length() - 1]
  match direction {
    Down | Up => (start.x + end.x) / 2.0
    Right | Left => (start.y + end.y) / 2.0
  }
}

///|
fn sort_route_entries_by_axis(
  entries : Array[(Double, Array[@graph.Point])],
) -> Array[(Double, Array[@graph.Point])] {
  let out = entries.copy()
  let mut i = 0
  while i < out.length() {
    let mut j = i + 1
    while j < out.length() {
      if out[j].0 < out[i].0 {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
      j = j + 1
    }
    i = i + 1
  }
  out
}

///|
priv struct LayoutSpacing {
  mut top : Double
  mut right : Double
  mut bottom : Double
  mut left : Double
}

///|
priv enum DefaultLabelPosition {
  OutsideTop
  OutsideBottom
  InsideTop
  InsideMiddle
}

///|
fn zero_layout_spacing() -> LayoutSpacing {
  { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 }
}

///|
fn approx_eq(a : Double, b : Double) -> Bool {
  abs_double(a - b) < 0.000001
}

///|
fn sort_ints_asc(values : Array[Int]) -> Array[Int] {
  let out = values.copy()
  let mut i = 0
  while i < out.length() {
    let mut j = i + 1
    while j < out.length() {
      if out[j] < out[i] {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
      j = j + 1
    }
    i = i + 1
  }
  out
}

///|
fn sort_ids_by_value(
  ids : Array[String],
  values : Map[String, Double],
  ascending : Bool,
) -> Array[String] {
  let out = ids.copy()
  let mut i = 0
  while i < out.length() {
    let mut j = i + 1
    while j < out.length() {
      let vi = values.get_or_default(out[i], 0.0)
      let vj = values.get_or_default(out[j], 0.0)
      let should_swap = if ascending { vj < vi } else { vi < vj }
      if should_swap {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
      j = j + 1
    }
    i = i + 1
  }
  out
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
  let is_grid_container = is_container &&
    (obj.grid_rows is Some(_) || obj.grid_columns is Some(_))
  let mut pos = if is_container {
    if is_grid_container {
      InsideTop
    } else {
      OutsideTop
    }
  } else if has_outside_bottom_label(obj.shape_type) {
    OutsideBottom
  } else if obj.icon is Some(_) {
    InsideTop
  } else {
    InsideMiddle
  }
  if label_width > box.width || label_height > box.height {
    pos = if is_container {
      if is_grid_container {
        InsideTop
      } else {
        OutsideTop
      }
    } else {
      OutsideBottom
    }
  }
  pos
}

///|
fn object_layout_spacing(
  obj : @graph.ObjectInput,
  box : @graph.Box,
) -> (LayoutSpacing, LayoutSpacing) {
  let margin = zero_layout_spacing()
  let padding = zero_layout_spacing()

  if obj.label != "" {
    let font_size = match obj.style.font_size {
      Some(v) => v.as_int().unwrap_or(16)
      None => 16
    }
    let is_bold = style_bool(obj.style.bold, false)
    let is_italic = style_bool(obj.style.italic, false)
    let is_mono = obj.shape_type == @graph.Code ||
      style_is_mono(obj.style.font_family)
    let dims = @text_metrics.measure_label(
      obj.label,
      font_size,
      is_mono,
      is_bold,
      is_italic,
    )
    let label_width = if dims.width > 0.0 {
      dims.width + D2_LABEL_PADDING * 2.0
    } else {
      obj.label.length().to_double() * 7.0 + D2_LABEL_PADDING * 2.0
    }
    let label_height = if dims.height > 0.0 {
      dims.height + D2_LABEL_PADDING * 2.0
    } else {
      font_size.to_double() + D2_LABEL_PADDING * 2.0
    }

    match default_label_position(obj, box, label_width, label_height) {
      OutsideTop => margin.top = label_height
      OutsideBottom => margin.bottom = label_height
      InsideTop => padding.top = label_height
      InsideMiddle => ()
    }
  }

  if obj.icon is Some(_) {
    let icon_size = D2_MAX_ICON_SIZE + D2_LABEL_PADDING * 2.0
    let icon_pos = if !obj.child_ids.is_empty() ||
      obj.shape_type == @graph.Class ||
      obj.shape_type == @graph.SqlTable ||
      obj.shape_type == @graph.Code {
      OutsideTop
    } else {
      InsideMiddle
    }
    match icon_pos {
      OutsideTop => if icon_size > margin.top { margin.top = icon_size }
      OutsideBottom =>
        if icon_size > margin.bottom {
          margin.bottom = icon_size
        }
      InsideTop => if icon_size > padding.top { padding.top = icon_size }
      InsideMiddle => ()
    }
  }
  if style_bool(obj.style.three_d, false) {
    margin.right = margin.right + D2_THREE_DEE_OFFSET
    margin.top = margin.top +
      (if obj.shape_type == @graph.Hexagon {
        D2_THREE_DEE_OFFSET / 2.0
      } else {
        D2_THREE_DEE_OFFSET
      })
  } else if style_bool(obj.style.multiple, false) {
    margin.right = margin.right + D2_MULTIPLE_OFFSET
    margin.top = margin.top + D2_MULTIPLE_OFFSET
  }

  (margin, padding)
}

///|
fn get_layout_ranks(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  parent_id_by_child_id : Map[String, String],
  is_horizontal : Bool,
) -> (
  Array[Array[String]],
  Map[String, Int],
  Map[String, Int],
  Map[String, Int],
) {
  let aligned : Map[Int, Array[String]] = {}
  for obj in graph.objects {
    if !obj.child_ids.is_empty() {
      continue
    }
    match patch.nodes.get(obj.id) {
      Some(box) => {
        let center = if is_horizontal {
          box.x + box.width / 2.0
        } else {
          box.y + box.height / 2.0
        }
        let level = center.ceil().to_int()
        let group = aligned.get_or_default(level, [])
        group.push(obj.id)
        aligned[level] = group
      }
      None => ()
    }
  }

  let levels : Array[Int] = []
  for level, _ in aligned {
    levels.push(level)
  }
  let sorted_levels = sort_ints_asc(levels)
  let ranks : Array[Array[String]] = []
  let object_ranks : Map[String, Int] = {}
  for i, level in sorted_levels {
    let members = aligned.get_or_default(level, [])
    for id in members {
      object_ranks[id] = i
    }
    ranks.push(members)
  }

  let starting_parent_ranks : Map[String, Int] = {}
  let ending_parent_ranks : Map[String, Int] = {}
  for obj in graph.objects {
    if !obj.child_ids.is_empty() {
      continue
    }
    match object_ranks.get(obj.id) {
      Some(rank) => {
        let mut current = obj.id
        while true {
          let parent = match parent_id_by_child_id.get(current) {
            Some(v) => v
            None => break
          }
          let prev_start = starting_parent_ranks.get_or_default(
            parent, 2147483647,
          )
          if rank < prev_start {
            starting_parent_ranks[parent] = rank
          }
          let prev_end = ending_parent_ranks.get_or_default(parent, -1)
          if rank > prev_end {
            ending_parent_ranks[parent] = rank
          }
          current = parent
        }
      }
      None => ()
    }
  }

  (ranks, object_ranks, starting_parent_ranks, ending_parent_ranks)
}

///|
fn shift_down_layout(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  start : Double,
  distance : Double,
  is_horizontal : Bool,
) -> Unit {
  for edge in graph.edges {
    match patch.edges.get(edge.index) {
      Some(route) => {
        if route.is_empty() {
          continue
        }
        let src_box = patch.nodes.get(edge.src_id)
        let dst_box = patch.nodes.get(edge.dst_id)
        let new_route : Array[@graph.Point] = []
        let last_index = route.length() - 1
        for i, p in route {
          let mut nx = p.x
          let mut ny = p.y
          if is_horizontal {
            if i == 0 {
              if start <= p.x {
                let on_static = match src_box {
                  Some(box) =>
                    approx_eq(p.x, box.x + box.width) && box.x < start
                  None => false
                }
                if !on_static {
                  nx = nx + distance
                }
              }
            } else if i == last_index {
              if start <= p.x {
                let on_static = match dst_box {
                  Some(box) =>
                    approx_eq(p.x, box.x + box.width) && box.x < start
                  None => false
                }
                if !on_static {
                  nx = nx + distance
                }
              }
            } else if p.x >= start {
              nx = nx + distance
            }
          } else if i == 0 {
            if start <= p.y {
              let on_static = match src_box {
                Some(box) => approx_eq(p.y, box.y + box.height) && box.y < start
                None => false
              }
              if !on_static {
                ny = ny + distance
              }
            }
          } else if i == last_index {
            if start <= p.y {
              let on_static = match dst_box {
                Some(box) => approx_eq(p.y, box.y + box.height) && box.y < start
                None => false
              }
              if !on_static {
                ny = ny + distance
              }
            }
          } else if p.y >= start {
            ny = ny + distance
          }
          new_route.push(@graph.Point::new(nx, ny))
        }
        patch.edges[edge.index] = new_route
      }
      None => ()
    }
  }

  for obj in graph.objects {
    match patch.nodes.get(obj.id) {
      Some(box) =>
        if is_horizontal {
          if box.x >= start {
            patch.nodes[obj.id] = @graph.Box::new(
              box.x + distance,
              box.y,
              box.width,
              box.height,
            )
          }
        } else if box.y >= start {
          patch.nodes[obj.id] = @graph.Box::new(
            box.x,
            box.y + distance,
            box.width,
            box.height,
          )
        }
      None => ()
    }
  }
}

///|
fn shift_up_layout(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  start : Double,
  distance : Double,
  is_horizontal : Bool,
) -> Unit {
  for edge in graph.edges {
    match patch.edges.get(edge.index) {
      Some(route) => {
        if route.is_empty() {
          continue
        }
        let src_box = patch.nodes.get(edge.src_id)
        let dst_box = patch.nodes.get(edge.dst_id)
        let new_route : Array[@graph.Point] = []
        let last_index = route.length() - 1
        for i, p in route {
          let mut nx = p.x
          let mut ny = p.y
          if is_horizontal {
            if i == 0 {
              if p.x <= start {
                let on_static = match src_box {
                  Some(box) =>
                    approx_eq(p.x, box.x) && start < box.x + box.width
                  None => false
                }
                if !on_static {
                  nx = nx - distance
                }
              }
            } else if i == last_index {
              if p.x <= start {
                let on_static = match dst_box {
                  Some(box) =>
                    approx_eq(p.x, box.x) && start < box.x + box.width
                  None => false
                }
                if !on_static {
                  nx = nx - distance
                }
              }
            } else if p.x <= start {
              nx = nx - distance
            }
          } else if i == 0 {
            if p.y <= start {
              let on_static = match src_box {
                Some(box) => approx_eq(p.y, box.y) && start < box.y + box.height
                None => false
              }
              if !on_static {
                ny = ny - distance
              }
            }
          } else if i == last_index {
            if p.y <= start {
              let on_static = match dst_box {
                Some(box) => approx_eq(p.y, box.y) && start < box.y
                None => false
              }
              if !on_static {
                ny = ny - distance
              }
            }
          } else if p.y <= start {
            ny = ny - distance
          }
          new_route.push(@graph.Point::new(nx, ny))
        }
        patch.edges[edge.index] = new_route
      }
      None => ()
    }
  }

  for obj in graph.objects {
    match patch.nodes.get(obj.id) {
      Some(box) =>
        if is_horizontal {
          if box.x <= start {
            patch.nodes[obj.id] = @graph.Box::new(
              box.x - distance,
              box.y,
              box.width,
              box.height,
            )
          }
        } else if box.y <= start {
          patch.nodes[obj.id] = @graph.Box::new(
            box.x,
            box.y - distance,
            box.width,
            box.height,
          )
        }
      None => ()
    }
  }
}

///|
fn adjust_rank_spacing(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  parent_id_by_child_id : Map[String, String],
  rank_sep : Double,
  is_horizontal : Bool,
) -> Unit {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  let (ranks, object_ranks, starting_parent_ranks, ending_parent_ranks) = get_layout_ranks(
    patch, graph, parent_id_by_child_id, is_horizontal,
  )
  if ranks.is_empty() {
    return
  }

  let mut rank = ranks.length() - 1
  while rank >= 0 {
    let starting_parent_set : Map[String, Bool] = {}
    let ending_parent_set : Map[String, Bool] = {}
    for obj_id in ranks[rank] {
      match parent_id_by_child_id.get(obj_id) {
        Some(parent_id) => {
          if ending_parent_ranks.get_or_default(parent_id, -1) == rank {
            ending_parent_set[parent_id] = true
          }
          if starting_parent_ranks.get_or_default(parent_id, -1) == rank {
            starting_parent_set[parent_id] = true
          }
        }
        None => ()
      }
    }

    let starting_ancestor_positions : Map[String, Double] = {}
    let starting_parents : Array[String] = []
    for parent_id, _ in starting_parent_set {
      starting_parents.push(parent_id)
    }
    let mut pending_start = starting_parents
    while !pending_start.is_empty() {
      let next : Array[String] = []
      let next_seen : Map[String, Bool] = {}
      for parent_id in pending_start {
        guard object_by_id.get(parent_id) is Some(parent_obj) &&
          patch.nodes.get(parent_id) is Some(parent_box) else {
          continue
        }
        let (_, padding) = object_layout_spacing(parent_obj, parent_box)
        if !starting_ancestor_positions.contains(parent_id) {
          starting_ancestor_positions[parent_id] = 1000000000000.0
        }
        let mut start_position = if is_horizontal {
          parent_box.x -
          (if padding.left > rank_sep / 2.0 {
            padding.left - rank_sep / 2.0
          } else {
            0.0
          })
        } else {
          parent_box.y -
          (if padding.top > rank_sep / 2.0 {
            padding.top - rank_sep / 2.0
          } else {
            0.0
          })
        }
        if start_position <
          starting_ancestor_positions.get_or_default(parent_id, 1000000000000.0) {
          starting_ancestor_positions[parent_id] = start_position
        }
        for child_id in parent_obj.child_ids {
          let should_consider = match object_ranks.get(child_id) {
            Some(r) => r == rank
            None => starting_parent_ranks.get_or_default(child_id, -1) == rank
          }
          if !should_consider {
            continue
          }
          guard object_by_id.get(child_id) is Some(child_obj) &&
            patch.nodes.get(child_id) is Some(child_box) else {
            continue
          }
          let (margin, _) = object_layout_spacing(child_obj, child_box)
          start_position = if is_horizontal {
            child_box.x - margin.left - padding.left
          } else {
            child_box.y - margin.top - padding.top
          }
          if start_position <
            starting_ancestor_positions.get_or_default(
              parent_id, 1000000000000.0,
            ) {
            starting_ancestor_positions[parent_id] = start_position
          }
        }
        match parent_id_by_child_id.get(parent_id) {
          Some(ancestor_id) =>
            if !next_seen.contains(ancestor_id) {
              next_seen[ancestor_id] = true
              next.push(ancestor_id)
            }
          None => ()
        }
      }
      pending_start = next
    }

    let ending_ancestor_positions : Map[String, Double] = {}
    let ending_parents : Array[String] = []
    for parent_id, _ in ending_parent_set {
      ending_parents.push(parent_id)
    }
    let mut pending_end = ending_parents
    while !pending_end.is_empty() {
      let next : Array[String] = []
      let next_seen : Map[String, Bool] = {}
      for parent_id in pending_end {
        guard object_by_id.get(parent_id) is Some(parent_obj) &&
          patch.nodes.get(parent_id) is Some(parent_box) else {
          continue
        }
        let (_, padding) = object_layout_spacing(parent_obj, parent_box)
        if !ending_ancestor_positions.contains(parent_id) {
          ending_ancestor_positions[parent_id] = -1000000000000.0
        }
        let mut end_position = if is_horizontal {
          parent_box.x + parent_box.width + padding.right - rank_sep / 2.0
        } else {
          parent_box.y + parent_box.height + padding.bottom - rank_sep / 2.0
        }
        if end_position >
          ending_ancestor_positions.get_or_default(parent_id, -1000000000000.0) {
          ending_ancestor_positions[parent_id] = end_position
        }
        for child_id in parent_obj.child_ids {
          let should_consider = match object_ranks.get(child_id) {
            Some(r) => r == rank
            None => ending_parent_ranks.get_or_default(child_id, -1) == rank
          }
          if !should_consider {
            continue
          }
          guard object_by_id.get(child_id) is Some(child_obj) &&
            patch.nodes.get(child_id) is Some(child_box) else {
            continue
          }
          let (margin, _) = object_layout_spacing(child_obj, child_box)
          end_position = if is_horizontal {
            child_box.x + child_box.width + margin.right + padding.right
          } else {
            child_box.y + child_box.height + margin.bottom + padding.bottom
          }
          if end_position >
            ending_ancestor_positions.get_or_default(
              parent_id, -1000000000000.0,
            ) {
            ending_ancestor_positions[parent_id] = end_position
          }
        }
        match parent_id_by_child_id.get(parent_id) {
          Some(ancestor_id) =>
            if !next_seen.contains(ancestor_id) {
              next_seen[ancestor_id] = true
              next.push(ancestor_id)
            }
          None => ()
        }
      }
      pending_end = next
    }

    let starting_ids : Array[String] = []
    for id, _ in starting_ancestor_positions {
      starting_ids.push(id)
    }
    let starting_adjustment_order = sort_ids_by_value(
      starting_ids, starting_ancestor_positions, true,
    )
    let ending_ids : Array[String] = []
    for id, _ in ending_ancestor_positions {
      ending_ids.push(id)
    }
    let ending_adjustment_order = sort_ids_by_value(
      ending_ids, ending_ancestor_positions, false,
    )

    for ancestor_id in ending_adjustment_order {
      guard patch.nodes.get(ancestor_id) is Some(ancestor_box) else { continue }
      let position = if is_horizontal {
        ancestor_box.x + ancestor_box.width
      } else {
        ancestor_box.y + ancestor_box.height
      }
      let end_delta = ending_ancestor_positions.get_or_default(
          ancestor_id, position,
        ) -
        position
      if end_delta > 0.0 {
        for obj in graph.objects {
          if obj.child_ids.is_empty() {
            continue
          }
          let start_rank = match starting_parent_ranks.get(obj.id) {
            Some(v) => v
            None => continue
          }
          let end_rank = match ending_parent_ranks.get(obj.id) {
            Some(v) => v
            None => continue
          }
          if start_rank <= rank && rank <= end_rank {
            match patch.nodes.get(obj.id) {
              Some(box) =>
                if is_horizontal && position <= box.x + box.width {
                  patch.nodes[obj.id] = @graph.Box::new(
                    box.x,
                    box.y,
                    box.width + end_delta,
                    box.height,
                  )
                } else if !is_horizontal && position <= box.y + box.height {
                  patch.nodes[obj.id] = @graph.Box::new(
                    box.x,
                    box.y,
                    box.width,
                    box.height + end_delta,
                  )
                }
              None => ()
            }
          }
        }
        shift_down_layout(patch, graph, position, end_delta, is_horizontal)
      }
    }

    for ancestor_id in starting_adjustment_order {
      guard patch.nodes.get(ancestor_id) is Some(ancestor_box) else { continue }
      let position = if is_horizontal { ancestor_box.x } else { ancestor_box.y }
      let start_delta = position -
        starting_ancestor_positions.get_or_default(ancestor_id, position)
      if start_delta > 0.0 {
        for obj in graph.objects {
          if obj.child_ids.is_empty() {
            continue
          }
          let start_rank = match starting_parent_ranks.get(obj.id) {
            Some(v) => v
            None => continue
          }
          let end_rank = match ending_parent_ranks.get(obj.id) {
            Some(v) => v
            None => continue
          }
          if start_rank <= rank && rank <= end_rank {
            match patch.nodes.get(obj.id) {
              Some(box) =>
                if is_horizontal && box.x <= position {
                  patch.nodes[obj.id] = @graph.Box::new(
                    box.x,
                    box.y,
                    box.width + start_delta,
                    box.height,
                  )
                } else if !is_horizontal && box.y <= position {
                  patch.nodes[obj.id] = @graph.Box::new(
                    box.x,
                    box.y,
                    box.width,
                    box.height + start_delta,
                  )
                }
              None => ()
            }
          }
        }
        shift_up_layout(patch, graph, position, start_delta, is_horizontal)
      }
    }

    rank = rank - 1
  }
}

///|
fn is_grid_diagram_object(obj : @graph.ObjectInput) -> Bool {
  obj.grid_rows is Some(_) || obj.grid_columns is Some(_)
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
fn build_children_by_parent_id(
  parent_id_by_child_id : Map[String, String],
) -> Map[String, Array[String]] {
  let children_by_parent_id : Map[String, Array[String]] = {}
  for child_id, parent_id in parent_id_by_child_id {
    let children = children_by_parent_id.get_or_default(parent_id, [])
    children.push(child_id)
    children_by_parent_id[parent_id] = children
  }
  children_by_parent_id
}

///|
fn build_edge_semantic_endpoints(
  graph : @graph.GraphInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> Map[Int, (String, String)] {
  let endpoints : Map[Int, (String, String)] = {}
  for edge in graph.edges {
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
    endpoints[edge.index] = (src_id, dst_id)
  }
  endpoints
}

///|
fn shift_reachable_down_layout(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  obj_id : String,
  start : Double,
  distance : Double,
  is_horizontal : Bool,
  is_margin : Bool,
  parent_id_by_child_id : Map[String, String],
  children_by_parent_id : Map[String, Array[String]],
  edge_semantic_endpoints : Map[Int, (String, String)],
) -> Map[String, Bool] {
  let q : Array[String] = [obj_id]
  let needs_move : Map[String, Bool] = {}
  let seen : Map[String, Bool] = {}
  let shifted : Map[String, Bool] = {}
  let shifted_edges : Map[Int, Bool] = {}
  let grown : Map[String, Bool] = {}
  let threshold = 100.0

  let queue_obj = (id : String) => if !seen.contains(id) { q.push(id) }

  let check_below = (curr_id : String) => {
    guard patch.nodes.get(curr_id) is Some(curr_box) else { return }
    let curr_bottom = curr_box.y + curr_box.height
    let curr_right = curr_box.x + curr_box.width
    if is_horizontal {
      let mut original_right = curr_right
      if shifted.contains(curr_id) {
        original_right = original_right - distance
      }
      for other in graph.objects {
        if other.id == curr_id ||
          is_descendant_of(curr_id, other.id, parent_id_by_child_id) {
          continue
        }
        guard patch.nodes.get(other.id) is Some(other_box) else { continue }
        if original_right < other_box.x &&
          other_box.x < original_right + distance + threshold &&
          curr_box.y < other_box.y + other_box.height &&
          other_box.y < curr_bottom {
          queue_obj(other.id)
        }
      }
    } else {
      let mut original_bottom = curr_bottom
      if shifted.contains(curr_id) {
        original_bottom = original_bottom - distance
      }
      for other in graph.objects {
        if other.id == curr_id ||
          is_descendant_of(curr_id, other.id, parent_id_by_child_id) {
          continue
        }
        guard patch.nodes.get(other.id) is Some(other_box) else { continue }
        if original_bottom < other_box.y &&
          other_box.y < original_bottom + distance + threshold &&
          curr_box.x < other_box.x + other_box.width &&
          other_box.x < curr_right {
          queue_obj(other.id)
        }
      }
    }
  }

  let process_queue = () => {
    let mut i = 0
    while i < q.length() {
      let curr_id = q[i]
      i = i + 1
      if seen.contains(curr_id) {
        continue
      }
      guard patch.nodes.get(curr_id) is Some(curr_box0) else {
        seen[curr_id] = true
        continue
      }
      let mut curr_box = curr_box0

      if curr_id != obj_id && !needs_move.contains(curr_id) {
        if is_horizontal {
          if curr_box.x < start {
            continue
          }
        } else if curr_box.y < start {
          continue
        }
      }

      let mut shift = needs_move.contains(curr_id)
      if !shift {
        if !is_margin {
          shift = if is_horizontal {
            start < curr_box.x
          } else {
            start < curr_box.y
          }
        } else {
          shift = if is_horizontal {
            start <= curr_box.x
          } else {
            start <= curr_box.y
          }
        }
      }
      if shift {
        curr_box = if is_horizontal {
          @graph.Box::new(
            curr_box.x + distance,
            curr_box.y,
            curr_box.width,
            curr_box.height,
          )
        } else {
          @graph.Box::new(
            curr_box.x,
            curr_box.y + distance,
            curr_box.width,
            curr_box.height,
          )
        }
        patch.nodes[curr_id] = curr_box
        shifted[curr_id] = true
      }
      seen[curr_id] = true

      match parent_id_by_child_id.get(curr_id) {
        Some(parent_id) =>
          if parent_id != graph.root.id &&
            !is_descendant_of(curr_id, obj_id, parent_id_by_child_id) {
            queue_obj(parent_id)
          }
        None => ()
      }
      for child_id in children_by_parent_id.get_or_default(curr_id, []) {
        queue_obj(child_id)
      }

      for edge in graph.edges {
        if shifted_edges.contains(edge.index) {
          continue
        }
        let (edge_src_id, edge_dst_id) = match
          edge_semantic_endpoints.get(edge.index) {
          Some(v) => v
          None => (edge.src_id, edge.dst_id)
        }
        let route = match patch.edges.get(edge.index) {
          Some(v) => v.copy()
          None => continue
        }
        if route.is_empty() {
          continue
        }
        if edge_src_id == curr_id && edge_dst_id == curr_id {
          for j, p in route {
            route[j] = if is_horizontal {
              @graph.Point::new(p.x + distance, p.y)
            } else {
              @graph.Point::new(p.x, p.y + distance)
            }
          }
          patch.edges[edge.index] = route
          shifted_edges[edge.index] = true
          continue
        } else if edge_src_id == curr_id {
          let last = route[route.length() - 1]
          if is_horizontal {
            match patch.nodes.get(edge_dst_id) {
              Some(dst_box) =>
                if start <= last.x &&
                  dst_box.x + dst_box.width < last.x + distance {
                  needs_move[edge_dst_id] = true
                }
              None => ()
            }
          } else {
            match patch.nodes.get(edge_dst_id) {
              Some(dst_box) =>
                if start <= last.y &&
                  dst_box.y + dst_box.height < last.y + distance {
                  needs_move[edge_dst_id] = true
                }
              None => ()
            }
          }
          queue_obj(edge_dst_id)

          let mut start_index = 0
          let first = route[0]
          let was_shifted = shifted.contains(curr_id)
          if is_horizontal {
            if was_shifted && first.x < curr_box.x && first.x < start {
              route[0] = @graph.Point::new(first.x + distance, first.y)
              start_index = 1
            }
            for j in start_index..<route.length() {
              let p = route[j]
              if start <= p.x {
                route[j] = @graph.Point::new(p.x + distance, p.y)
              }
            }
          } else {
            if was_shifted && first.y < curr_box.y && first.y < start {
              route[0] = @graph.Point::new(first.x, first.y + distance)
              start_index = 1
            }
            for j in start_index..<route.length() {
              let p = route[j]
              if start <= p.y {
                route[j] = @graph.Point::new(p.x, p.y + distance)
              }
            }
          }
          patch.edges[edge.index] = route
          shifted_edges[edge.index] = true
        } else if edge_dst_id == curr_id {
          let first = route[0]
          if is_horizontal {
            match patch.nodes.get(edge_src_id) {
              Some(src_box) =>
                if start <= first.x &&
                  src_box.x + src_box.width < first.x + distance {
                  needs_move[edge_src_id] = true
                }
              None => ()
            }
          } else {
            match patch.nodes.get(edge_src_id) {
              Some(src_box) =>
                if start <= first.y &&
                  src_box.y + src_box.height < first.y + distance {
                  needs_move[edge_src_id] = true
                }
              None => ()
            }
          }
          queue_obj(edge_src_id)

          let mut end_index = route.length()
          let last = route[route.length() - 1]
          let was_shifted = shifted.contains(curr_id)
          if is_horizontal {
            if was_shifted && last.x < curr_box.x && last.x < start {
              route[route.length() - 1] = @graph.Point::new(
                last.x + distance,
                last.y,
              )
              end_index = end_index - 1
            }
            for j in 0..<end_index {
              let p = route[j]
              if start <= p.x {
                route[j] = @graph.Point::new(p.x + distance, p.y)
              }
            }
          } else {
            if was_shifted && last.y < curr_box.y && last.y < start {
              route[route.length() - 1] = @graph.Point::new(
                last.x,
                last.y + distance,
              )
              end_index = end_index - 1
            }
            for j in 0..<end_index {
              let p = route[j]
              if start <= p.y {
                route[j] = @graph.Point::new(p.x, p.y + distance)
              }
            }
          }
          patch.edges[edge.index] = route
          shifted_edges[edge.index] = true
        }
      }

      check_below(curr_id)
    }
  }

  process_queue()

  for seen_id, _ in seen {
    let parent_id0 = match parent_id_by_child_id.get(seen_id) {
      Some(v) => v
      None => continue
    }
    if parent_id0 == graph.root.id ||
      shifted.contains(parent_id0) ||
      grown.contains(parent_id0) {
      continue
    }
    let mut parent_id = parent_id0
    while parent_id != graph.root.id {
      if shifted.contains(parent_id) || grown.contains(parent_id) {
        break
      }
      guard patch.nodes.get(parent_id) is Some(parent_box) else { break }
      if is_horizontal {
        if parent_box.x < start {
          patch.nodes[parent_id] = @graph.Box::new(
            parent_box.x,
            parent_box.y,
            parent_box.width + distance,
            parent_box.height,
          )
          grown[parent_id] = true
          check_below(parent_id)
          process_queue()
        }
      } else if parent_box.y < start {
        patch.nodes[parent_id] = @graph.Box::new(
          parent_box.x,
          parent_box.y,
          parent_box.width,
          parent_box.height + distance,
        )
        grown[parent_id] = true
        check_below(parent_id)
        process_queue()
      }
      parent_id = match parent_id_by_child_id.get(parent_id) {
        Some(v) => v
        None => break
      }
    }
  }

  let moved_ids : Array[String] = []
  for id, _ in shifted {
    moved_ids.push(id)
  }
  for id, _ in grown {
    moved_ids.push(id)
  }
  let increased_margins : Map[String, Bool] = {}
  for moved_id in moved_ids {
    guard patch.nodes.get(moved_id) is Some(moved_box) else { continue }
    let mut counts = true
    for other_id in moved_ids {
      if other_id == moved_id {
        continue
      }
      guard patch.nodes.get(other_id) is Some(other_box) else { continue }
      if is_horizontal {
        if other_box.y + other_box.height < moved_box.y ||
          moved_box.y + moved_box.height < other_box.y {
          continue
        }
        if other_box.x < moved_box.x &&
          moved_box.x < other_box.x + other_box.width + threshold {
          counts = false
          break
        }
      } else {
        if other_box.x + other_box.width < moved_box.x ||
          moved_box.x + moved_box.width < other_box.x {
          continue
        }
        if other_box.y < moved_box.y &&
          moved_box.y < other_box.y + other_box.height + threshold {
          counts = false
          break
        }
      }
    }
    if counts {
      increased_margins[moved_id] = true
    }
  }

  increased_margins
}

///|
fn adjust_cross_rank_spacing(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  parent_id_by_child_id : Map[String, String],
  is_horizontal : Bool,
) -> Unit {
  let children_by_parent_id = build_children_by_parent_id(parent_id_by_child_id)
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  let edge_semantic_endpoints = build_edge_semantic_endpoints(
    graph, object_by_id, parent_id_by_child_id,
  )
  let prev_margin_top : Map[String, Double] = {}
  let prev_margin_bottom : Map[String, Double] = {}
  let prev_margin_left : Map[String, Double] = {}
  let prev_margin_right : Map[String, Double] = {}

  for obj in graph.objects {
    if is_grid_diagram_object(obj) {
      continue
    }
    guard patch.nodes.get(obj.id) is Some(base_box) else { continue }
    let (margin0, padding) = object_layout_spacing(obj, base_box)
    let margin = margin0
    if !is_horizontal {
      margin.bottom = margin.bottom -
        prev_margin_bottom.get_or_default(obj.id, 0.0)
      if margin.bottom > 0.0 {
        guard patch.nodes.get(obj.id) is Some(box) else { continue }
        let increased = shift_reachable_down_layout(
          patch,
          graph,
          obj.id,
          box.y + box.height,
          margin.bottom,
          is_horizontal,
          true,
          parent_id_by_child_id,
          children_by_parent_id,
          edge_semantic_endpoints,
        )
        for shifted_id, _ in increased {
          let prev = prev_margin_bottom.get_or_default(shifted_id, 0.0)
          if margin.bottom > prev {
            prev_margin_bottom[shifted_id] = margin.bottom
          }
        }
      }
      if padding.bottom > 0.0 {
        guard patch.nodes.get(obj.id) is Some(box) else { continue }
        ignore(
          shift_reachable_down_layout(
            patch,
            graph,
            obj.id,
            box.y + box.height,
            padding.bottom,
            is_horizontal,
            false,
            parent_id_by_child_id,
            children_by_parent_id,
            edge_semantic_endpoints,
          ),
        )
        patch.nodes[obj.id] = @graph.Box::new(
          box.x,
          box.y,
          box.width,
          box.height + padding.bottom,
        )
      }

      margin.top = margin.top - prev_margin_top.get_or_default(obj.id, 0.0)
      if margin.top > 0.0 {
        guard patch.nodes.get(obj.id) is Some(box) else { continue }
        let increased = shift_reachable_down_layout(
          patch,
          graph,
          obj.id,
          box.y,
          margin.top,
          is_horizontal,
          true,
          parent_id_by_child_id,
          children_by_parent_id,
          edge_semantic_endpoints,
        )
        for shifted_id, _ in increased {
          let prev = prev_margin_top.get_or_default(shifted_id, 0.0)
          if margin.top > prev {
            prev_margin_top[shifted_id] = margin.top
          }
        }
      }
      if padding.top > 0.0 {
        guard patch.nodes.get(obj.id) is Some(box) else { continue }
        ignore(
          shift_reachable_down_layout(
            patch,
            graph,
            obj.id,
            box.y,
            padding.top,
            is_horizontal,
            false,
            parent_id_by_child_id,
            children_by_parent_id,
            edge_semantic_endpoints,
          ),
        )
        patch.nodes[obj.id] = @graph.Box::new(
          box.x,
          box.y,
          box.width,
          box.height + padding.top,
        )
      }
    } else {
      margin.right = margin.right -
        prev_margin_right.get_or_default(obj.id, 0.0)
      if margin.right > 0.0 {
        guard patch.nodes.get(obj.id) is Some(box) else { continue }
        let increased = shift_reachable_down_layout(
          patch,
          graph,
          obj.id,
          box.x + box.width,
          margin.right,
          is_horizontal,
          true,
          parent_id_by_child_id,
          children_by_parent_id,
          edge_semantic_endpoints,
        )
        for shifted_id, _ in increased {
          let prev = prev_margin_right.get_or_default(shifted_id, 0.0)
          if margin.right > prev {
            prev_margin_right[shifted_id] = margin.right
          }
        }
      }
      if padding.right > 0.0 {
        guard patch.nodes.get(obj.id) is Some(box) else { continue }
        ignore(
          shift_reachable_down_layout(
            patch,
            graph,
            obj.id,
            box.x + box.width,
            padding.right,
            is_horizontal,
            false,
            parent_id_by_child_id,
            children_by_parent_id,
            edge_semantic_endpoints,
          ),
        )
        patch.nodes[obj.id] = @graph.Box::new(
          box.x,
          box.y,
          box.width + padding.right,
          box.height,
        )
      }

      margin.left = margin.left - prev_margin_left.get_or_default(obj.id, 0.0)
      if margin.left > 0.0 {
        guard patch.nodes.get(obj.id) is Some(box) else { continue }
        let increased = shift_reachable_down_layout(
          patch,
          graph,
          obj.id,
          box.x,
          margin.left,
          is_horizontal,
          true,
          parent_id_by_child_id,
          children_by_parent_id,
          edge_semantic_endpoints,
        )
        for shifted_id, _ in increased {
          let prev = prev_margin_left.get_or_default(shifted_id, 0.0)
          if margin.left > prev {
            prev_margin_left[shifted_id] = margin.left
          }
        }
      }
      if padding.left > 0.0 {
        guard patch.nodes.get(obj.id) is Some(box) else { continue }
        ignore(
          shift_reachable_down_layout(
            patch,
            graph,
            obj.id,
            box.x,
            padding.left,
            is_horizontal,
            false,
            parent_id_by_child_id,
            children_by_parent_id,
            edge_semantic_endpoints,
          ),
        )
        patch.nodes[obj.id] = @graph.Box::new(
          box.x,
          box.y,
          box.width + padding.left,
          box.height,
        )
      }
    }
  }
}

///|
fn fit_container_boxes(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  parent_id_by_child_id : Map[String, String],
) -> Unit {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  let edge_semantic_endpoints = build_edge_semantic_endpoints(
    graph, object_by_id, parent_id_by_child_id,
  )
  let containers : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if obj.child_ids.is_empty() {
      continue
    }
    if obj.shape_type != @graph.Rectangle && obj.shape_type != @graph.Square {
      continue
    }
    containers.push(obj)
  }
  // Fit inner containers first so parent containers can wrap the updated boxes.
  let mut i = 0
  while i < containers.length() {
    let mut j = i + 1
    while j < containers.length() {
      if object_depth_from_id(containers[j].id) >
        object_depth_from_id(containers[i].id) {
        let tmp = containers[i]
        containers[i] = containers[j]
        containers[j] = tmp
      }
      j = j + 1
    }
    i = i + 1
  }

  for container in containers {
    let mut box = match patch.nodes.get(container.id) {
      Some(v) => v
      None => continue
    }
    let (_, raw_padding) = object_layout_spacing(container, box)
    let padding = zero_layout_spacing()
    padding.top = if raw_padding.top > D2_CONTAINER_PADDING {
      raw_padding.top
    } else {
      D2_CONTAINER_PADDING
    }
    padding.bottom = if raw_padding.bottom > D2_CONTAINER_PADDING {
      raw_padding.bottom
    } else {
      D2_CONTAINER_PADDING
    }
    padding.left = if raw_padding.left > D2_CONTAINER_PADDING {
      raw_padding.left
    } else {
      D2_CONTAINER_PADDING
    }
    padding.right = if raw_padding.right > D2_CONTAINER_PADDING {
      raw_padding.right
    } else {
      D2_CONTAINER_PADDING
    }

    let mut inner_top = 1000000000000.0
    let mut inner_bottom = -1000000000000.0
    let mut inner_left = 1000000000000.0
    let mut inner_right = -1000000000000.0
    let mut seen = false

    for child_id in container.child_ids {
      match patch.nodes.get(child_id) {
        Some(box) => {
          let (child_margin, _) = match object_by_id.get(child_id) {
            Some(obj) => object_layout_spacing(obj, box)
            None => (zero_layout_spacing(), zero_layout_spacing())
          }
          let top_pad = if child_margin.top > padding.top {
            child_margin.top
          } else {
            padding.top
          }
          let bottom_pad = if child_margin.bottom > padding.bottom {
            child_margin.bottom
          } else {
            padding.bottom
          }
          let left_pad = if child_margin.left > padding.left {
            child_margin.left
          } else {
            padding.left
          }
          let right_pad = if child_margin.right > padding.right {
            child_margin.right
          } else {
            padding.right
          }
          seen = true
          if box.y - top_pad < inner_top {
            inner_top = box.y - top_pad
          }
          if box.y + box.height + bottom_pad > inner_bottom {
            inner_bottom = box.y + box.height + bottom_pad
          }
          if box.x - left_pad < inner_left {
            inner_left = box.x - left_pad
          }
          if box.x + box.width + right_pad > inner_right {
            inner_right = box.x + box.width + right_pad
          }
        }
        None => ()
      }
    }

    for edge in graph.edges {
      let src_in = in_container(
        edge.src_id,
        container.id,
        parent_id_by_child_id,
      )
      let dst_in = in_container(
        edge.dst_id,
        container.id,
        parent_id_by_child_id,
      )
      if src_in is None || dst_in is None {
        continue
      }
      match patch.edges.get(edge.index) {
        Some(route) =>
          for point in route {
            seen = true
            if point.y - padding.top < inner_top {
              inner_top = point.y - padding.top
            }
            if point.y + padding.bottom > inner_bottom {
              inner_bottom = point.y + padding.bottom
            }
            if point.x - padding.left < inner_left {
              inner_left = point.x - padding.left
            }
            if point.x + padding.right > inner_right {
              inner_right = point.x + padding.right
            }
          }
        None => ()
      }
      match patch.edge_labels.get(edge.index) {
        Some(label_box) => {
          seen = true
          if label_box.y - padding.top < inner_top {
            inner_top = label_box.y - padding.top
          }
          if label_box.y + label_box.height + padding.bottom > inner_bottom {
            inner_bottom = label_box.y + label_box.height + padding.bottom
          }
          if label_box.x - padding.left < inner_left {
            inner_left = label_box.x - padding.left
          }
          if label_box.x + label_box.width + padding.right > inner_right {
            inner_right = label_box.x + label_box.width + padding.right
          }
        }
        None => ()
      }
    }

    if !seen {
      continue
    }

    let top_delta = inner_top - box.y
    if top_delta > 0.0 {
      let adjusted = fit_adjust_delta_for_edges(
        container.id,
        graph,
        patch,
        box,
        box.y,
        top_delta,
        false,
        edge_semantic_endpoints,
      )
      if adjusted > 0.0 {
        fit_adjust_edges(
          container.id,
          graph,
          patch,
          box,
          box.y,
          adjusted,
          false,
          edge_semantic_endpoints,
        )
        box = @graph.Box::new(
          box.x,
          box.y + adjusted,
          box.width,
          box.height - adjusted,
        )
      }
    }

    let bottom = box.y + box.height
    let bottom_delta = bottom - inner_bottom
    if bottom_delta > 0.0 {
      let adjusted = fit_adjust_delta_for_edges(
        container.id,
        graph,
        patch,
        box,
        bottom,
        -bottom_delta,
        false,
        edge_semantic_endpoints,
      )
      if adjusted > 0.0 {
        fit_adjust_edges(
          container.id,
          graph,
          patch,
          box,
          bottom,
          -adjusted,
          false,
          edge_semantic_endpoints,
        )
        box = @graph.Box::new(box.x, box.y, box.width, box.height - adjusted)
      }
    }

    let left_delta = inner_left - box.x
    if left_delta > 0.0 {
      let adjusted = fit_adjust_delta_for_edges(
        container.id,
        graph,
        patch,
        box,
        box.x,
        left_delta,
        true,
        edge_semantic_endpoints,
      )
      if adjusted > 0.0 {
        fit_adjust_edges(
          container.id,
          graph,
          patch,
          box,
          box.x,
          adjusted,
          true,
          edge_semantic_endpoints,
        )
        box = @graph.Box::new(
          box.x + adjusted,
          box.y,
          box.width - adjusted,
          box.height,
        )
      }
    }

    let right = box.x + box.width
    let right_delta = right - inner_right
    if right_delta > 0.0 {
      let adjusted = fit_adjust_delta_for_edges(
        container.id,
        graph,
        patch,
        box,
        right,
        -right_delta,
        true,
        edge_semantic_endpoints,
      )
      if adjusted > 0.0 {
        fit_adjust_edges(
          container.id,
          graph,
          patch,
          box,
          right,
          -adjusted,
          true,
          edge_semantic_endpoints,
        )
        box = @graph.Box::new(box.x, box.y, box.width - adjusted, box.height)
      }
    }

    patch.nodes[container.id] = box
  }
}

///|
fn fit_adjust_delta_for_edges(
  container_id : String,
  graph : @graph.GraphInput,
  patch : @graph.LayoutPatch,
  box : @graph.Box,
  obj_position : Double,
  delta : Double,
  is_horizontal : Bool,
  edge_semantic_endpoints : Map[Int, (String, String)],
) -> Double {
  let mut has_edge_on_collapsing_side = false
  let mut outermost = obj_position + delta
  for edge in graph.edges {
    let (edge_src_id, edge_dst_id) = match
      edge_semantic_endpoints.get(edge.index) {
      Some(v) => v
      None => (edge.src_id, edge.dst_id)
    }
    match patch.edges.get(edge.index) {
      Some(route) => {
        if route.is_empty() {
          continue
        }
        if edge_src_id == container_id {
          let p = route[0]
          if fit_is_on_collapsing_side(
              p, box, obj_position, delta, is_horizontal,
            ) {
            has_edge_on_collapsing_side = true
            let position = if is_horizontal { p.x } else { p.y }
            if delta < 0.0 {
              if position > outermost {
                outermost = position
              }
            } else if position < outermost {
              outermost = position
            }
          }
        }
        if edge_dst_id == container_id {
          let p = route[route.length() - 1]
          if fit_is_on_collapsing_side(
              p, box, obj_position, delta, is_horizontal,
            ) {
            has_edge_on_collapsing_side = true
            let position = if is_horizontal { p.x } else { p.y }
            if delta < 0.0 {
              if position > outermost {
                outermost = position
              }
            } else if position < outermost {
              outermost = position
            }
          }
        }
      }
      None => ()
    }
  }

  let mut magnitude = abs_double(delta)
  if has_edge_on_collapsing_side {
    if delta < 0.0 {
      let candidate = obj_position - (outermost + D2_CONTAINER_PADDING)
      magnitude = if candidate > 0.0 { candidate } else { 0.0 }
    } else {
      let candidate = outermost - D2_CONTAINER_PADDING - obj_position
      magnitude = if candidate > 0.0 { candidate } else { 0.0 }
    }
  }
  magnitude
}

///|
fn fit_is_on_collapsing_side(
  p : @graph.Point,
  box : @graph.Box,
  obj_position : Double,
  delta : Double,
  is_horizontal : Bool,
) -> Bool {
  let position = if is_horizontal { p.x } else { p.y }
  if precision_eq_with_tol(position, obj_position, 1.0) {
    return false
  }
  let is_on_side = if is_horizontal {
    precision_eq_with_tol(p.y, box.y, 1.0) ||
    precision_eq_with_tol(p.y, box.y + box.height, 1.0)
  } else {
    precision_eq_with_tol(p.x, box.x, 1.0) ||
    precision_eq_with_tol(p.x, box.x + box.width, 1.0)
  }
  if !is_on_side {
    return false
  }
  if delta > 0.0 {
    obj_position <= position &&
    position <= obj_position + delta + D2_CONTAINER_MIN_SPACING
  } else {
    obj_position + delta - D2_CONTAINER_MIN_SPACING <= position &&
    position <= obj_position
  }
}

///|
fn fit_adjust_edges(
  container_id : String,
  graph : @graph.GraphInput,
  patch : @graph.LayoutPatch,
  box : @graph.Box,
  obj_position : Double,
  delta : Double,
  is_horizontal : Bool,
  edge_semantic_endpoints : Map[Int, (String, String)],
) -> Unit {
  for edge in graph.edges {
    let (edge_src_id, edge_dst_id) = match
      edge_semantic_endpoints.get(edge.index) {
      Some(v) => v
      None => (edge.src_id, edge.dst_id)
    }
    match patch.edges.get(edge.index) {
      Some(route) => {
        if route.is_empty() {
          continue
        }
        let updated_route : Array[@graph.Point] = []
        for p in route {
          updated_route.push(p)
        }
        let mut changed = false
        if edge_src_id == container_id {
          updated_route[0] = fit_adjust_endpoint(
            updated_route[0],
            box,
            obj_position,
            delta,
            is_horizontal,
          )
          changed = true
        }
        if edge_dst_id == container_id {
          let last = updated_route.length() - 1
          updated_route[last] = fit_adjust_endpoint(
            updated_route[last],
            box,
            obj_position,
            delta,
            is_horizontal,
          )
          changed = true
        }
        if changed {
          patch.edges[edge.index] = updated_route
        }
      }
      None => ()
    }
  }
}

///|
fn fit_adjust_endpoint(
  p : @graph.Point,
  box : @graph.Box,
  obj_position : Double,
  delta : Double,
  is_horizontal : Bool,
) -> @graph.Point {
  let position = if is_horizontal { p.x } else { p.y }
  if precision_eq_with_tol(position, obj_position, 1.0) {
    if is_horizontal {
      return @graph.Point::new(p.x + delta, p.y)
    }
    return @graph.Point::new(p.x, p.y + delta)
  }

  let is_on_side = if is_horizontal {
    precision_eq_with_tol(p.y, box.y, 1.0) ||
    precision_eq_with_tol(p.y, box.y + box.height, 1.0)
  } else {
    precision_eq_with_tol(p.x, box.x, 1.0) ||
    precision_eq_with_tol(p.x, box.x + box.width, 1.0)
  }
  if !is_on_side {
    return p
  }

  let is_in_range = if delta > 0.0 {
    obj_position < position && position < obj_position + delta
  } else {
    obj_position + delta < position && position < obj_position
  }
  if !is_in_range {
    return p
  }

  if is_horizontal {
    @graph.Point::new(obj_position + delta, p.y)
  } else {
    @graph.Point::new(p.x, obj_position + delta)
  }
}

///|
fn precision_eq_with_tol(a : Double, b : Double, tol : Double) -> Bool {
  abs_double(a - b) <= tol
}

///|
fn object_depth_from_id(id : String) -> Int {
  let mut depth = 1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      depth = depth + 1
    }
  }
  depth
}

///|
fn points_to_route(points : Array[@moon_dagre.Point]) -> Array[@graph.Point] {
  let route : Array[@graph.Point] = []
  for point in points {
    route.push(@graph.Point::new(point.x, point.y))
  }
  route
}

///|
fn chop_route_to_endpoint_boxes(
  route : Array[@graph.Point],
  node_boxes : Map[String, @graph.Box],
  src_id : String,
  dst_id : String,
) -> Array[@graph.Point] {
  if route.length() < 2 || src_id == dst_id {
    return route
  }
  let src_box = match node_boxes.get(src_id) {
    Some(v) => v
    None => return route
  }
  let dst_box = match node_boxes.get(dst_id) {
    Some(v) => v
    None => return route
  }
  let mut start_index = 0
  let mut end_index = route.length() - 1
  let mut start_point = route[start_index]
  let mut end_point = route[end_index]
  for i in 1..<route.length() {
    let p0 = route[i - 1]
    let p1 = route[i]
    match first_box_intersection(src_box, p0, p1) {
      Some(p) => {
        start_point = p
        start_index = i - 1
      }
      None => ()
    }
    match first_box_intersection(dst_box, p0, p1) {
      Some(p) => {
        end_point = p
        end_index = i
        break
      }
      None => ()
    }
  }
  if end_index < start_index {
    return route
  }
  let trimmed : Array[@graph.Point] = []
  let mut i = start_index
  while i <= end_index {
    trimmed.push(route[i])
    i = i + 1
  }
  if trimmed.is_empty() {
    return route
  }
  trimmed[0] = start_point
  trimmed[trimmed.length() - 1] = end_point
  trimmed
}

///|
fn first_box_intersection(
  box : @graph.Box,
  p0 : @graph.Point,
  p1 : @graph.Point,
) -> @graph.Point? {
  let x0 = box.x
  let x1 = box.x + box.width
  let y0 = box.y
  let y1 = box.y + box.height

  // Keep the same edge-check order as D2 geo.Box.Intersections:
  // top -> right -> bottom -> left. D2 then takes intersections[0].
  match segment_intersection_at_y(p0, p1, y0, x0, x1) {
    Some(hit) => return Some(hit.1)
    None => ()
  }
  match segment_intersection_at_x(p0, p1, x1, y0, y1) {
    Some(hit) => return Some(hit.1)
    None => ()
  }
  match segment_intersection_at_y(p0, p1, y1, x0, x1) {
    Some(hit) => return Some(hit.1)
    None => ()
  }
  match segment_intersection_at_x(p0, p1, x0, y0, y1) {
    Some(hit) => return Some(hit.1)
    None => ()
  }
  None
}

///|
fn segment_intersection_at_x(
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
  let rx = p0.x + round_nearest_int_double(t * (p1.x - p0.x))
  let ry = p0.y + round_nearest_int_double(t * (p1.y - p0.y))
  Some((t, @graph.Point::new(rx, ry)))
}

///|
fn segment_intersection_at_y(
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
  let rx = p0.x + round_nearest_int_double(t * (p1.x - p0.x))
  let ry = p0.y + round_nearest_int_double(t * (p1.y - p0.y))
  Some((t, @graph.Point::new(rx, ry)))
}

///|
fn round_nearest_int_double(v : Double) -> Double {
  if v >= 0.0 {
    (v + 0.5).to_int().to_double()
  } else {
    (v - 0.5).to_int().to_double()
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
fn is_rectangular_shape(shape_type : @graph.ShapeType) -> Bool {
  shape_type == @graph.Rectangle ||
  shape_type == @graph.Square ||
  shape_type == @graph.SqlTable ||
  shape_type == @graph.Class ||
  shape_type == @graph.Text ||
  shape_type == @graph.Code ||
  shape_type == @graph.Image
}

///|
const D2_HEXAGON_HALF_Y_FACTOR : Double = 43.6 / 87.3

///|
const D2_CYLINDER_BEZIER_MULTIPLIER : Double = 0.45

///|
const D2_CUBIC_TRACE_SAMPLES : Int = 160

///|
fn trace_to_shape_border(
  shape_type : @graph.ShapeType,
  box : @graph.Box,
  rect_border_point : @graph.Point,
  prev_point : @graph.Point,
) -> @graph.Point {
  if is_rectangular_shape(shape_type) {
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
  let scale_size = if abs_double(prev_point.x - rect_border_point.x) <= 0.000001 {
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
        @graph.Point::new(box.x + box.width * 0.25, box.y),
        @graph.Point::new(box.x, box.y + box.height * D2_HEXAGON_HALF_Y_FACTOR),
        @graph.Point::new(box.x + box.width * 0.25, box.y + box.height),
        @graph.Point::new(box.x + box.width * 0.75, box.y + box.height),
        @graph.Point::new(
          box.x + box.width,
          box.y + box.height * D2_HEXAGON_HALF_Y_FACTOR,
        ),
        @graph.Point::new(box.x + box.width * 0.75, box.y),
      ]
      polygon_intersections(points, segment_start, segment_end)
    }
    @graph.Diamond => {
      let points = [
        @graph.Point::new(box.x + box.width / 2.0, box.y),
        @graph.Point::new(box.x + box.width, box.y + box.height / 2.0),
        @graph.Point::new(box.x + box.width / 2.0, box.y + box.height),
        @graph.Point::new(box.x, box.y + box.height / 2.0),
      ]
      polygon_intersections(points, segment_start, segment_end)
    }
    @graph.Callout => {
      let tip_w = if box.width < 60.0 { box.width / 2.0 } else { 30.0 }
      let tip_h = if box.height < 90.0 { box.height / 2.0 } else { 45.0 }
      let main_h = box.height - tip_h
      let mid_x = round_double(box.x + box.width / 2.0)
      let points = [
        @graph.Point::new(box.x, box.y),
        @graph.Point::new(box.x, box.y + main_h),
        @graph.Point::new(mid_x, box.y + main_h),
        @graph.Point::new(mid_x, box.y + box.height),
        @graph.Point::new(mid_x + tip_w, box.y + main_h),
        @graph.Point::new(box.x + box.width, box.y + main_h),
        @graph.Point::new(box.x + box.width, box.y),
      ]
      polygon_intersections(points, segment_start, segment_end)
    }
    @graph.Package => {
      let (top_width, top_height) = package_top_dimensions(box)
      let points = [
        @graph.Point::new(box.x, box.y),
        @graph.Point::new(box.x + top_width, box.y),
        @graph.Point::new(box.x + top_width, box.y + top_height),
        @graph.Point::new(box.x + box.width, box.y + top_height),
        @graph.Point::new(box.x + box.width, box.y + box.height),
        @graph.Point::new(box.x, box.y + box.height),
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
        @graph.Point::new(box.x, box.y),
        @graph.Point::new(box.x + box.width - wedge, box.y),
        @graph.Point::new(box.x + box.width, box.y + box.height / 2.0),
        @graph.Point::new(box.x + box.width - wedge, box.y + box.height),
        @graph.Point::new(box.x, box.y + box.height),
        @graph.Point::new(box.x + wedge, box.y + box.height / 2.0),
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
          @graph.Point::new(x0, y0),
          @graph.Point::new(x1, y0),
          segment_start,
          segment_end,
        ) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      match
        segment_segment_intersection(
          @graph.Point::new(x0, y0),
          @graph.Point::new(x0, base_y),
          segment_start,
          segment_end,
        ) {
        Some(hit) => push_unique_point(out, hit)
        None => ()
      }
      match
        segment_segment_intersection(
          @graph.Point::new(x1, y0),
          @graph.Point::new(x1, base_y),
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
          @graph.Point::new(x1, base_y),
          @graph.Point::new(box.x + box.width * (5.0 / 6.0), cp1_y),
          @graph.Point::new(box.x + box.width * (2.0 / 3.0), cp1_y),
          @graph.Point::new(mid_x, base_y),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          @graph.Point::new(mid_x, base_y),
          @graph.Point::new(box.x + box.width * (1.0 / 3.0), cp2_y),
          @graph.Point::new(box.x + box.width * (1.0 / 6.0), cp2_y),
          @graph.Point::new(x0, base_y),
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
          @graph.Point::new(start_x, y0),
          @graph.Point::new(end_x, y0),
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
          @graph.Point::new(end_x, y0),
          @graph.Point::new(x1, y0),
          @graph.Point::new(x1, y0 + box.height * m),
          @graph.Point::new(x1, y0 + box.height / 2.0),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          @graph.Point::new(x1, y0 + box.height / 2.0),
          @graph.Point::new(x1, y1 - box.height * m),
          @graph.Point::new(x1, y1),
          @graph.Point::new(end_x, y1),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      match
        segment_segment_intersection(
          @graph.Point::new(end_x, y1),
          @graph.Point::new(start_x, y1),
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
          @graph.Point::new(start_x, y1),
          @graph.Point::new(x0, y1),
          @graph.Point::new(x0, y1 - box.height * m),
          @graph.Point::new(x0, y0 + box.height / 2.0),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          @graph.Point::new(x0, y0 + box.height / 2.0),
          @graph.Point::new(x0, y0 + box.height * m),
          @graph.Point::new(x0, y0),
          @graph.Point::new(start_x, y0),
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
          @graph.Point::new(left_x, y0),
          @graph.Point::new(x1, y0),
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
          @graph.Point::new(x1, y0),
          @graph.Point::new(x1 - wedge * m, y0),
          @graph.Point::new(right_x, y0 + box.height * m),
          @graph.Point::new(right_x, y0 + box.height / 2.0),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          @graph.Point::new(right_x, y0 + box.height / 2.0),
          @graph.Point::new(right_x, y1 - box.height * m),
          @graph.Point::new(x1 - wedge * m, y1),
          @graph.Point::new(x1, y1),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      match
        segment_segment_intersection(
          @graph.Point::new(x1, y1),
          @graph.Point::new(left_x, y1),
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
          @graph.Point::new(left_x, y1),
          @graph.Point::new(left_x - wedge * m, y1),
          @graph.Point::new(x0, y1 - box.height * m),
          @graph.Point::new(x0, y0 + box.height / 2.0),
          D2_CUBIC_TRACE_SAMPLES,
        ) {
        push_unique_point(out, hit)
      }
      for
        hit in cubic_polyline_intersections(
          segment_start,
          segment_end,
          @graph.Point::new(x0, y0 + box.height / 2.0),
          @graph.Point::new(x0, y0 + box.height * m),
          @graph.Point::new(left_x - wedge * m, y0),
          @graph.Point::new(left_x, y0),
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
  if abs_double(denom) <= 0.000001 {
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
  let out : Array[@graph.Point] = []
  if samples <= 0 {
    return out
  }
  let roots = cubic_line_roots_on_unit(
    segment_start, segment_end, p0, p1, p2, p3, samples,
  )
  for t in roots {
    let point = cubic_point(p0, p1, p2, p3, t)
    if point_on_segment_box(point, segment_start, segment_end) {
      push_unique_point(out, point)
    }
  }
  out
}

///|
fn cubic_point(
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  p3 : @graph.Point,
  t : Double,
) -> @graph.Point {
  let u = 1.0 - t
  let uu = u * u
  let uuu = uu * u
  let tt = t * t
  let ttt = tt * t
  @graph.Point::new(
    uuu * p0.x + 3.0 * uu * t * p1.x + 3.0 * u * tt * p2.x + ttt * p3.x,
    uuu * p0.y + 3.0 * uu * t * p1.y + 3.0 * u * tt * p2.y + ttt * p3.y,
  )
}

///|
fn cubic_line_roots_on_unit(
  line_start : @graph.Point,
  line_end : @graph.Point,
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  p3 : @graph.Point,
  samples : Int,
) -> Array[Double] {
  let roots : Array[Double] = []
  let eps = 0.000001
  let mut prev_t = 0.0
  let mut prev_f = cubic_line_value(
    line_start, line_end, p0, p1, p2, p3, prev_t,
  )
  if abs_double(prev_f) <= eps {
    roots.push(0.0)
  }
  for i in 1..<=samples {
    let t = i.to_double() / samples.to_double()
    let f = cubic_line_value(line_start, line_end, p0, p1, p2, p3, t)
    if abs_double(f) <= eps {
      roots.push(t)
    }
    if prev_f * f < 0.0 {
      let root = bisect_cubic_line_root(
        line_start, line_end, p0, p1, p2, p3, prev_t, t,
      )
      roots.push(root)
    }
    prev_t = t
    prev_f = f
  }
  dedupe_roots(roots)
}

///|
fn cubic_line_value(
  line_start : @graph.Point,
  line_end : @graph.Point,
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  p3 : @graph.Point,
  t : Double,
) -> Double {
  let point = cubic_point(p0, p1, p2, p3, t)
  let dx = line_end.x - line_start.x
  let dy = line_end.y - line_start.y
  (point.x - line_start.x) * dy - (point.y - line_start.y) * dx
}

///|
fn bisect_cubic_line_root(
  line_start : @graph.Point,
  line_end : @graph.Point,
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  p3 : @graph.Point,
  t0 : Double,
  t1 : Double,
) -> Double {
  let eps = 0.000001
  let mut lo = t0
  let mut hi = t1
  let mut flo = cubic_line_value(line_start, line_end, p0, p1, p2, p3, lo)
  let fhi = cubic_line_value(line_start, line_end, p0, p1, p2, p3, hi)
  if abs_double(flo) <= eps {
    return lo
  }
  if abs_double(fhi) <= eps {
    return hi
  }
  for _ in 0..<50 {
    let mid = (lo + hi) / 2.0
    let fm = cubic_line_value(line_start, line_end, p0, p1, p2, p3, mid)
    if abs_double(fm) <= eps {
      return mid
    }
    if flo * fm <= 0.0 {
      hi = mid
    } else {
      lo = mid
      flo = fm
    }
  }
  (lo + hi) / 2.0
}

///|
fn dedupe_roots(roots : Array[Double]) -> Array[Double] {
  if roots.is_empty() {
    return roots
  }
  let out : Array[Double] = []
  for root in roots {
    if root < -0.000001 || root > 1.000001 {
      continue
    }
    let clamped = if root < 0.0 { 0.0 } else if root > 1.0 { 1.0 } else { root }
    let mut exists = false
    for existing in out {
      if abs_double(existing - clamped) <= 0.0001 {
        exists = true
        break
      }
    }
    if !exists {
      out.push(clamped)
    }
  }
  out
}

///|
fn point_on_segment_box(
  point : @graph.Point,
  segment_start : @graph.Point,
  segment_end : @graph.Point,
) -> Bool {
  let base_min_x = if segment_start.x < segment_end.x {
    segment_start.x
  } else {
    segment_end.x
  }
  let base_max_x = if segment_start.x > segment_end.x {
    segment_start.x
  } else {
    segment_end.x
  }
  let base_min_y = if segment_start.y < segment_end.y {
    segment_start.y
  } else {
    segment_end.y
  }
  let base_max_y = if segment_start.y > segment_end.y {
    segment_start.y
  } else {
    segment_end.y
  }
  let min_x = base_min_x - 0.000001
  let max_x = base_max_x + 0.000001
  let min_y = base_min_y - 0.000001
  let max_y = base_max_y + 0.000001
  point.x >= min_x && point.x <= max_x && point.y >= min_y && point.y <= max_y
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
fn trace_routes_to_object_boundaries(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
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
    let route = match patch.edges.get(edge.index) {
      Some(v) => v
      None => continue
    }
    if route.length() < 2 {
      continue
    }
    let src_box = match patch.nodes.get(src_id) {
      Some(v) => v
      None => continue
    }
    let dst_box = match patch.nodes.get(dst_id) {
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

    // Mirror d2 short-segment handling before trace-to-shape.
    if start_index + 2 < points.length() &&
      point_distance(points[start_index], points[start_index + 1]) <
      D2_MIN_SEGMENT_LEN {
      let next_start = points[start_index + 1]
      let next_end = points[start_index + 2]
      match extend_segment_from_end(next_start, next_end, D2_MIN_SEGMENT_LEN) {
        Some(extended_start) =>
          match first_box_intersection(src_box, next_end, extended_start) {
            Some(hit) => {
              start_index = start_index + 1
              points[start_index] = hit
            }
            None => ()
          }
        None => ()
      }
    }
    if end_index >= 2 &&
      point_distance(points[end_index - 1], points[end_index]) <
      D2_MIN_SEGMENT_LEN {
      let prev_start = points[end_index - 2]
      let prev_end = points[end_index - 1]
      match
        extend_segment_from_start(prev_start, prev_end, D2_MIN_SEGMENT_LEN) {
        Some(extended_end) =>
          match first_box_intersection(dst_box, prev_start, extended_end) {
            Some(hit) => {
              end_index = end_index - 1
              points[end_index] = hit
            }
            None => ()
          }
        None => ()
      }
    }

    // Match d2dagrelayout: if an edge enters the offset region of 3D/multiple
    // shapes, trace against the modifier-adjusted box.
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
      patch.edges[edge.index] = traced
    }
  }
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
  let dims = @text_metrics.measure_label(
    obj.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  let width = if dims.width > 0.0 {
    dims.width
  } else {
    obj.label.length().to_double() * 7.0
  }
  let height = if dims.height > 0.0 {
    dims.height
  } else {
    font_size.to_double() + 5.0
  }
  Some((width, height))
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

  match segment_intersection_at_y(p0, p1, y0, x0, x1) {
    Some(hit) => add_hit(hit.1)
    None => ()
  }
  match segment_intersection_at_x(p0, p1, x1, y0, y1) {
    Some(hit) => add_hit(hit.1)
    None => ()
  }
  match segment_intersection_at_y(p0, p1, y1, x0, x1) {
    Some(hit) => add_hit(hit.1)
    None => ()
  }
  match segment_intersection_at_x(p0, p1, x0, y0, y1) {
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
fn extend_segment_from_end(
  start : @graph.Point,
  end : @graph.Point,
  extra_len : Double,
) -> @graph.Point? {
  let vx = end.x - start.x
  let vy = end.y - start.y
  let length = (vx * vx + vy * vy).sqrt()
  if length <= 0.000001 {
    return None
  }
  let unit_x = vx / length
  let unit_y = vy / length
  let extended_len = length + extra_len
  Some(
    @graph.Point::new(
      end.x + unit_x * extended_len,
      end.y + unit_y * extended_len,
    ),
  )
}

///|
fn extend_segment_from_start(
  start : @graph.Point,
  end : @graph.Point,
  extra_len : Double,
) -> @graph.Point? {
  let vx = end.x - start.x
  let vy = end.y - start.y
  let length = (vx * vx + vy * vy).sqrt()
  if length <= 0.000001 {
    return None
  }
  let unit_x = vx / length
  let unit_y = vy / length
  let extended_len = length + extra_len
  Some(
    @graph.Point::new(
      start.x + unit_x * extended_len,
      start.y + unit_y * extended_len,
    ),
  )
}

///|

///|
fn convert_dagre_routes_to_d2_curves(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  for edge in graph.edges {
    let route = match patch.edges.get(edge.index) {
      Some(v) => v
      None => continue
    }
    let (curve_route, is_curve) = d2_curve_route(route)
    patch.edges[edge.index] = curve_route
    patch.edge_curves[edge.index] = is_curve
  }
}

///|
fn d2_curve_route(route : Array[@graph.Point]) -> (Array[@graph.Point], Bool) {
  if route.length() < 2 {
    return (route, false)
  }
  let vectors : Array[(Double, Double)] = []
  for i in 1..<route.length() {
    let p0 = route[i - 1]
    let p1 = route[i]
    vectors.push((p1.x - p0.x, p1.y - p0.y))
  }

  let path : Array[@graph.Point] = []
  path.push(route[0])
  let mut is_curve = false
  if vectors.length() > 1 {
    let first = route[0]
    let first_v = vectors[0]
    path.push(
      @graph.Point::new(first.x + first_v.0 * 0.8, first.y + first_v.1 * 0.8),
    )

    let mut i = 1
    while i < vectors.length() - 2 {
      let p = route[i]
      let v = vectors[i]
      path.push(@graph.Point::new(p.x + v.0 * 0.2, p.y + v.1 * 0.2))
      path.push(@graph.Point::new(p.x + v.0 * 0.5, p.y + v.1 * 0.5))
      path.push(@graph.Point::new(p.x + v.0 * 0.8, p.y + v.1 * 0.8))
      i = i + 1
    }

    let second_last = route[route.length() - 2]
    let last_v = vectors[vectors.length() - 1]
    path.push(
      @graph.Point::new(
        second_last.x + last_v.0 * 0.2,
        second_last.y + last_v.1 * 0.2,
      ),
    )
    is_curve = true
  }

  path.push(route[route.length() - 1])
  (path, is_curve)
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
    let seg = point_distance(p0, p1)
    if seg <= 0.000001 {
      continue
    }
    if walked + seg >= target {
      let t = (target - walked) / seg
      let x = p0.x + (p1.x - p0.x) * t
      let y = p0.y + (p1.y - p0.y) * t
      return @graph.Point::new(x, y)
    }
    walked = walked + seg
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
fn dagre_edge_key(
  src_id : String,
  dst_id : String,
  edge_name : String?,
) -> String {
  let name = match edge_name {
    Some(name) => name
    None => ""
  }
  src_id + "\u0001" + dst_id + "\u0001" + name
}
