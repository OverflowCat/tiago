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
}

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
  ) = build_dagre_graph(graph, config, direction)
  ignore(@moon_dagre.layout(dagre_graph))
  let patch = @graph.LayoutPatch::new()
  copy_passthrough_layout_data(patch, graph)
  fill_patch_nodes(
    patch, dagre_graph, graph, node_size_by_id, dagre_node_id_by_object_id, config,
  )
  fill_patch_edges(patch, dagre_graph, edge_layout_by_key)
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
        let (w0, h0) = object_size(obj, config)
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
    let start_x = if src_x < dst_x { src_x + 2.0 } else { src_x - 2.0 }
    let end_x = if src_x < dst_x { dst_x - 4.0 } else { dst_x + 4.0 }
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
) raise @engine_api.LayoutError {
  let dagre_graph = @moon_dagre.new_graph(multigraph=true, compound=true)
  dagre_graph.set_graph(make_dagre_graph_attrs(config, direction))

  let node_ids : Map[String, Bool] = {}
  let node_size_by_id : Map[String, (Double, Double)] = {}
  let dagre_node_id_by_object_id : Map[String, String] = {}
  for i, obj in graph.objects {
    node_ids[obj.id] = true
    let dagre_id = dagre_node_id(i, obj.id)
    dagre_node_id_by_object_id[obj.id] = dagre_id
    let (width, height) = object_size(obj, config)
    node_size_by_id[obj.id] = (width, height)
    let node_attrs = @moon_dagre.empty_attrs()
    node_attrs.set_float("width", width)
    node_attrs.set_float("height", height)
    dagre_graph.set_node(dagre_id, label=node_attrs)
  }

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

  let edge_layout_by_key : Map[String, EdgeLayoutInfo] = {}
  for edge in graph.edges {
    let (layout_src_id, layout_dst_id) = resolve_edge_layout_endpoints(
      graph, edge, object_by_id, parent_id_by_child_id,
    )
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
    let edge_name = "e\{edge.index}"
    let edge_attrs = make_dagre_edge_attrs(edge)
    dagre_graph.set_edge(
      src_dagre_id,
      dst_dagre_id,
      label=@moon_dagre.attrs_value(edge_attrs),
      name=edge_name,
    )
    edge_layout_by_key[dagre_edge_key(
      src_dagre_id,
      dst_dagre_id,
      Some(edge_name),
    )] = { edge_index: edge.index, src_id: edge.src_id, dst_id: edge.dst_id }
  }

  (dagre_graph, edge_layout_by_key, node_size_by_id, dagre_node_id_by_object_id)
}

///|
fn make_dagre_graph_attrs(
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> @moon_dagre.Attrs {
  let attrs = @moon_dagre.empty_attrs()
  let (nodesep, ranksep) = spacing_for_direction(config, direction)
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
  direction : @engine_api.Direction,
) -> (Double, Double) {
  let nodesep = d2_nodesep(config.horizontal_spacing)
  let ranksep = d2_ranksep(config.vertical_spacing)
  match direction {
    Down | Up => (nodesep, ranksep)
    Right | Left => (ranksep, nodesep)
  }
}

///|
fn d2_nodesep(value : Double) -> Double {
  let base = clamp_positive(value, 50.0)
  if base < 50.0 {
    50.0
  } else {
    base
  }
}

///|
fn d2_ranksep(value : Double) -> Double {
  let base = clamp_positive(value, 100.0)
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
  let src = resolve_container_endpoint(
    graph,
    edge.src_id,
    true,
    object_by_id,
    parent_id_by_child_id,
  )
  let dst = resolve_container_endpoint(
    graph,
    edge.dst_id,
    false,
    object_by_id,
    parent_id_by_child_id,
  )
  if edge.src_arrow && !edge.dst_arrow {
    (dst, src)
  } else {
    (src, dst)
  }
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
) -> (Double, Double) {
  match obj.box {
    Some(box) =>
      (
        clamp_positive(box.width, config.default_width),
        clamp_positive(box.height, config.default_height),
      )
    None => estimate_object_size(obj, config)
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

  let mut width = label_dims.width
  let mut height = label_dims.height

  match obj.shape_type {
    @graph.Text | @graph.Code => {
      width = width + 2.0
      height = height + 2.0
    }
    @graph.Diamond => {
      width = width + 40.0
      height = height + 30.0
    }
    @graph.Circle | @graph.Square | @graph.Oval => {
      width = width + 36.0
      height = height + 30.0
      let side = if width > height { width } else { height }
      width = side
      height = side
    }
    @graph.C4Person => {
      width = width + 48.0
      height = height + 64.0
    }
    _ => {
      width = width + 50.0
      height = height + 45.0
    }
  }

  if !obj.child_ids.is_empty() {
    width = width + 16.0
    height = height + font_size.to_double() + 12.0
  }

  let min_width = clamp_positive(config.default_width * 0.5, 50.0)
  let min_height = clamp_positive(config.default_height * 0.6, 40.0)
  let width = if width < min_width { min_width } else { width }
  let height = if height < min_height { min_height } else { height }
  (width, height)
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
fn make_dagre_edge_attrs(edge : @graph.EdgeInput) -> @moon_dagre.Attrs {
  let attrs = @moon_dagre.empty_attrs()
  attrs.set_float(
    "weight",
    clamp_positive(edge.reference_count.to_double(), 1.0),
  )
  match edge_label_size(edge) {
    Some((width, height)) => {
      attrs.set_float("width", width)
      attrs.set_float("height", height)
      attrs.set_string("labelpos", "c")
    }
    None => ()
  }
  attrs
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
  let width = clamp_positive(
    attrs.get_float_or("width", fallback_width),
    fallback_width,
  )
  let height = clamp_positive(
    attrs.get_float_or("height", fallback_height),
    fallback_height,
  )
  Some(@graph.Box::new(x - width / 2.0, y - height / 2.0, width, height))
}

///|
fn dagre_node_id(order : Int, obj_id : String) -> String {
  zero_padded_int(order, 8) + "\u0002" + obj_id
}

///|
fn zero_padded_int(value : Int, width : Int) -> String {
  let s = value.to_string()
  if s.length() >= width {
    return s
  }
  let pad = StringBuilder::new()
  let pad_count = width - s.length()
  for _ in 0..<pad_count {
    pad.write_char('0')
  }
  pad.write_string(s)
  pad.to_string()
}

///|
fn fill_patch_edges(
  patch : @graph.LayoutPatch,
  dagre_graph : @moon_dagre.Graph,
  edge_layout_by_key : Map[String, EdgeLayoutInfo],
) -> Unit {
  for edge_obj in dagre_graph.edges() {
    let key = dagre_edge_key(edge_obj.v, edge_obj.w, edge_obj.name)
    match edge_layout_by_key.get(key) {
      Some(info) => {
        let edge_attrs = @moon_dagre.value_as_attrs(
          dagre_graph.edge_obj(edge_obj),
        )
        match edge_attrs {
          Some(attrs) => {
            match attrs.get_points("points") {
              Some(points) => {
                let route = points_to_route(points)
                patch.edges[info.edge_index] = chop_route_to_endpoint_boxes(
                  route,
                  patch.nodes,
                  info.src_id,
                  info.dst_id,
                )
              }
              None => ()
            }
            match label_box_from_dagre_edge(attrs) {
              Some(box) => patch.edge_labels[info.edge_index] = box
              None => ()
            }
          }
          None => ()
        }
      }
      None => ()
    }
  }
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
  let candidates : Array[(Double, @graph.Point)] = []
  let x0 = box.x
  let x1 = box.x + box.width
  let y0 = box.y
  let y1 = box.y + box.height

  match segment_intersection_at_x(p0, p1, x0, y0, y1) {
    Some(hit) => candidates.push(hit)
    None => ()
  }
  match segment_intersection_at_x(p0, p1, x1, y0, y1) {
    Some(hit) => candidates.push(hit)
    None => ()
  }
  match segment_intersection_at_y(p0, p1, y0, x0, x1) {
    Some(hit) => candidates.push(hit)
    None => ()
  }
  match segment_intersection_at_y(p0, p1, y1, x0, x1) {
    Some(hit) => candidates.push(hit)
    None => ()
  }
  if candidates.is_empty() {
    return None
  }
  let mut best_t = 2.0
  let mut best_point = @graph.Point::new(0.0, 0.0)
  for hit in candidates {
    let t = hit.0
    let point = hit.1
    if t < best_t {
      best_t = t
      best_point = point
    }
  }
  if best_t <= 1.0 {
    Some(best_point)
  } else {
    None
  }
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
  Some((t, @graph.Point::new(x, y)))
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
  Some((t, @graph.Point::new(x, y)))
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
fn label_box_from_dagre_edge(attrs : @moon_dagre.Attrs) -> @graph.Box? {
  guard attrs.get_float("x") is Some(x) && attrs.get_float("y") is Some(y) else {
    return None
  }
  let width = attrs.get_float_or("width", 0.0)
  let height = attrs.get_float_or("height", 0.0)
  if width <= 0.0 || height <= 0.0 {
    return None
  }
  Some(@graph.Box::new(x - width / 2.0, y - height / 2.0, width, height))
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
