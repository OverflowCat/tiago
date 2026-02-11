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
pub impl @engine_api.LayoutEngine for DagreEngine with layout(
  _self,
  graph,
  config,
  direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  let (dagre_graph, edge_index_by_key, node_size_by_id) = build_dagre_graph(
    graph, config, direction,
  )
  ignore(@moon_dagre.layout(dagre_graph))
  let patch = @graph.LayoutPatch::new()
  copy_passthrough_layout_data(patch, graph)
  fill_patch_nodes(patch, dagre_graph, graph, node_size_by_id, config)
  fill_patch_edges(patch, dagre_graph, edge_index_by_key)
  patch
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
) -> (@moon_dagre.Graph, Map[String, Int], Map[String, (Double, Double)]) raise @engine_api.LayoutError {
  let dagre_graph = @moon_dagre.new_graph(multigraph=true, compound=true)
  dagre_graph.set_graph(make_dagre_graph_attrs(config, direction))

  let node_ids : Map[String, Bool] = {}
  let node_size_by_id : Map[String, (Double, Double)] = {}
  for obj in graph.objects {
    node_ids[obj.id] = true
    let node_attrs = @moon_dagre.empty_attrs()
    let (width, height) = object_size(obj, config)
    node_size_by_id[obj.id] = (width, height)
    node_attrs.set_float("width", width)
    node_attrs.set_float("height", height)
    dagre_graph.set_node(obj.id, label=node_attrs)
  }

  let risky_parent_ids = find_risky_compound_parent_ids(graph)
  for parent in graph.objects {
    if risky_parent_ids.contains(parent.id) {
      continue
    }
    for child_id in parent.child_ids {
      if child_id == parent.id || !node_ids.contains(child_id) {
        continue
      }
      dagre_graph.set_parent(child_id, parent=parent.id)
    }
  }

  let edge_index_by_key : Map[String, Int] = {}
  for edge in graph.edges {
    if !node_ids.contains(edge.src_id) || !node_ids.contains(edge.dst_id) {
      raise @engine_api.invalid_graph(
        "dagre edge endpoint not found: \{edge.src_id} -> \{edge.dst_id}",
      )
    }
    let edge_name = "e\{edge.index}"
    let edge_attrs = make_dagre_edge_attrs(edge)
    dagre_graph.set_edge(
      edge.src_id,
      edge.dst_id,
      label=@moon_dagre.attrs_value(edge_attrs),
      name=edge_name,
    )
    edge_index_by_key[dagre_edge_key(edge.src_id, edge.dst_id, Some(edge_name))] = edge.index
  }

  (dagre_graph, edge_index_by_key, node_size_by_id)
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
  attrs.set_float("marginx", clamp_positive(config.container_padding, 0.0))
  attrs.set_float("marginy", clamp_positive(config.container_padding, 0.0))
  attrs
}

///|
fn spacing_for_direction(
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> (Double, Double) {
  match direction {
    Down | Up =>
      (
        clamp_positive(config.horizontal_spacing, 50.0),
        clamp_positive(config.vertical_spacing, 50.0),
      )
    Right | Left =>
      (
        clamp_positive(config.vertical_spacing, 50.0),
        clamp_positive(config.horizontal_spacing, 50.0),
      )
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
    None =>
      (
        clamp_positive(config.default_width, 100.0),
        clamp_positive(config.default_height, 60.0),
      )
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
        None
      }
    }
    None =>
      if edge.label.is_empty() {
        None
      } else {
        let width = edge.label.length().to_double() * 7.0 + 12.0
        Some((width, 16.0))
      }
  }
}

///|
fn find_risky_compound_parent_ids(
  graph : @graph.GraphInput,
) -> Map[String, Bool] {
  let has_children : Map[String, Bool] = {}
  for obj in graph.objects {
    if !obj.child_ids.is_empty() {
      has_children[obj.id] = true
    }
  }

  let has_outer_incident_edge : Map[String, Bool] = {}
  let has_inner_edge : Map[String, Bool] = {}
  for edge in graph.edges {
    if has_children.contains(edge.src_id) {
      has_outer_incident_edge[edge.src_id] = true
    }
    if has_children.contains(edge.dst_id) {
      has_outer_incident_edge[edge.dst_id] = true
    }

    for parent_id, _ in has_children {
      if is_descendant_id(edge.src_id, parent_id) &&
        is_descendant_id(edge.dst_id, parent_id) {
        has_inner_edge[parent_id] = true
      }
    }
  }

  let risky : Map[String, Bool] = {}
  for parent_id, _ in has_children {
    if has_outer_incident_edge.contains(parent_id) &&
      has_inner_edge.contains(parent_id) {
      risky[parent_id] = true
    }
  }
  risky
}

///|
fn is_descendant_id(id : String, parent_id : String) -> Bool {
  id.has_prefix(parent_id + ".")
}

///|
fn fill_patch_nodes(
  patch : @graph.LayoutPatch,
  dagre_graph : @moon_dagre.Graph,
  graph : @graph.GraphInput,
  node_size_by_id : Map[String, (Double, Double)],
  config : @engine_api.LayoutConfig,
) -> Unit {
  for obj in graph.objects {
    match dagre_graph.node_opt(obj.id) {
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
fn fill_patch_edges(
  patch : @graph.LayoutPatch,
  dagre_graph : @moon_dagre.Graph,
  edge_index_by_key : Map[String, Int],
) -> Unit {
  for edge_obj in dagre_graph.edges() {
    let key = dagre_edge_key(edge_obj.v, edge_obj.w, edge_obj.name)
    match edge_index_by_key.get(key) {
      Some(edge_index) => {
        let edge_attrs = @moon_dagre.value_as_attrs(
          dagre_graph.edge_obj(edge_obj),
        )
        match edge_attrs {
          Some(attrs) => {
            match attrs.get_points("points") {
              Some(points) => patch.edges[edge_index] = points_to_route(points)
              None => ()
            }
            match label_box_from_dagre_edge(attrs) {
              Some(box) => patch.edge_labels[edge_index] = box
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
