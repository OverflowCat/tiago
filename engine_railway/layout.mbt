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
fn layout_graph(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  let patch = @graph.LayoutPatch::new()
  copy_passthrough_layout_data(patch, graph)
  let (layout_input, object_by_id, parent_id_by_child_id) = build_railway_layout_input(
    graph,
  )
  let plan = els_tarjan_plan(layout_input)
  let (self_loop, reversed_set) = dag_edge_index_sets(plan)
  let n = layout_input.objects.length()
  let id_to_idx : Map[String, Int] = Map::new(capacity=n * 2)
  for i in 0..<n {
    id_to_idx.set(layout_input.objects[i].id, i)
  }
  let depths = compute_depths(
    n, layout_input, id_to_idx, plan, self_loop, reversed_set,
  )
  let levels = make_levels(layout_input, depths)
  let (boxes, level_heights) = place_nodes(
    layout_input, config, direction, levels,
  )
  let container_padding = @cmp.maximum(
    RAILWAY_CONTAINER_PADDING,
    config.edge_padding,
  )
  fit_container_boxes_in_map_railway(
    boxes, graph, object_by_id, parent_id_by_child_id, container_padding,
  )
  relax_layout_nodes_against_containers(
    boxes, graph, parent_id_by_child_id, direction, config,
  )
  fit_container_boxes_in_map_railway(
    boxes, graph, object_by_id, parent_id_by_child_id, container_padding,
  )
  let (src_ports, dst_ports) = assign_ports(
    layout_input, id_to_idx, depths, self_loop, direction, config, boxes,
  )
  let rail_tracks = assign_rail_tracks(
    layout_input, id_to_idx, depths, self_loop, direction,
  )
  let rail_shifts = assign_gap_lane_offsets(
    layout_input, id_to_idx, depths, self_loop, direction, config, src_ports, dst_ports,
  )
  for obj in layout_input.objects {
    match boxes.get(obj.id) {
      Some(b) => patch.nodes[obj.id] = b
      None => ()
    }
  }
  for edge in layout_input.edges {
    if self_loop.contains(edge.index) {
      let b = match boxes.get(edge.src_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{edge.src_id}")
      }
      patch.edges[edge.index] = self_loop_route(
        b,
        direction,
        config.edge_padding,
      )
      continue
    }
    let su = require_index(id_to_idx, edge.src_id)
    let sv = require_index(id_to_idx, edge.dst_id)
    let du = depths[su]
    let dv = depths[sv]
    let start = match src_ports.get(edge.index) {
      Some(p) => p
      None => raise Unsupported("missing src port for edge: \{edge.index}")
    }
    let end = match dst_ports.get(edge.index) {
      Some(p) => p
      None => raise Unsupported("missing dst port for edge: \{edge.index}")
    }
    patch.edges[edge.index] = route_edge(
      edge.index,
      edge.src_id,
      edge.dst_id,
      du,
      dv,
      rail_tracks.get(edge.index).unwrap_or(0),
      rail_shifts.get(edge.index).unwrap_or(0.0),
      start,
      end,
      boxes,
      direction,
      config,
      level_heights,
    )
  }
  recompute_edge_label_boxes(patch, graph)
  fit_container_boxes_railway(
    patch, graph, object_by_id, parent_id_by_child_id, config,
  )
  patch
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
const RAILWAY_CONTAINER_PADDING : Double = 30.0

///|
fn build_railway_layout_input(
  graph : @graph.GraphInput,
) -> (@graph.GraphInput, Map[String, @graph.ObjectInput], Map[String, String]) {
  let (object_by_id, parent_id_by_child_id) = build_object_maps_railway(graph)
  let layout_node_ids : Map[String, Bool] = {}
  let layout_objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if is_layout_container_candidate(obj) {
      continue
    }
    layout_node_ids[obj.id] = true
    layout_objects.push(obj)
  }
  let layout_edges : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    let (src_id, dst_id) = resolve_edge_layout_endpoints_railway(
      graph, edge, object_by_id, parent_id_by_child_id,
    )
    if !layout_node_ids.contains(src_id) {
      match object_by_id.get(src_id) {
        Some(obj) => {
          layout_node_ids[src_id] = true
          layout_objects.push(obj)
        }
        None => ()
      }
    }
    if !layout_node_ids.contains(dst_id) {
      match object_by_id.get(dst_id) {
        Some(obj) => {
          layout_node_ids[dst_id] = true
          layout_objects.push(obj)
        }
        None => ()
      }
    }
    if !layout_node_ids.contains(src_id) || !layout_node_ids.contains(dst_id) {
      continue
    }
    layout_edges.push(edge_with_layout_endpoints(edge, src_id, dst_id))
  }
  let layout_input = @graph.GraphInput::from_parts(
    graph.name,
    graph.root,
    layout_objects,
    layout_edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
  )
  (layout_input, object_by_id, parent_id_by_child_id)
}

///|
fn build_object_maps_railway(
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
fn edge_with_layout_endpoints(
  edge : @graph.EdgeInput,
  src_id : String,
  dst_id : String,
) -> @graph.EdgeInput {
  @graph.EdgeInput::from_parts(
    edge.index,
    src_id,
    dst_id,
    edge.src_arrow,
    edge.dst_arrow,
    edge.src_arrowhead,
    edge.dst_arrowhead,
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
  )
}

///|
fn resolve_edge_layout_endpoints_railway(
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
  let src = resolve_container_endpoint_railway(
    graph, src_id, true, object_by_id, parent_id_by_child_id,
  )
  let dst = resolve_container_endpoint_railway(
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
fn resolve_container_endpoint_railway(
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
fn fit_container_boxes_railway(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  config : @engine_api.LayoutConfig,
) -> Unit {
  let padding = @cmp.maximum(RAILWAY_CONTAINER_PADDING, config.edge_padding)
  fit_container_boxes_in_map_railway(
    patch.nodes,
    graph,
    object_by_id,
    parent_id_by_child_id,
    padding,
  )
}

///|
fn object_depth_in_hierarchy(
  id : String,
  parent_id_by_child_id : Map[String, String],
) -> Int {
  let mut depth = 0
  let mut current = id
  while true {
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => {
        depth = depth + 1
        current = parent_id
      }
      None => break
    }
  }
  depth
}

///|
fn fit_container_boxes_in_map_railway(
  node_boxes : Map[String, @graph.Box],
  graph : @graph.GraphInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  padding : Double,
) -> Unit {
  let container_ids : Array[String] = []
  for obj in graph.objects {
    if is_layout_container_candidate(obj) {
      container_ids.push(obj.id)
    }
  }
  container_ids.sort_by(fn(a, b) {
    let da = object_depth_in_hierarchy(a, parent_id_by_child_id)
    let db = object_depth_in_hierarchy(b, parent_id_by_child_id)
    if da > db {
      -1
    } else if da < db {
      1
    } else {
      a.compare(b)
    }
  })
  for container_id in container_ids {
    let container = match object_by_id.get(container_id) {
      Some(v) => v
      None => continue
    }
    let mut min_x = 1000000000000.0
    let mut max_x = -1000000000000.0
    let mut min_y = 1000000000000.0
    let mut max_y = -1000000000000.0
    let mut seen = false
    for child_id in container.child_ids {
      match node_boxes.get(child_id) {
        Some(box) => {
          seen = true
          if box.x < min_x {
            min_x = box.x
          }
          if box.y < min_y {
            min_y = box.y
          }
          if box.x + box.width > max_x {
            max_x = box.x + box.width
          }
          if box.y + box.height > max_y {
            max_y = box.y + box.height
          }
        }
        None => ()
      }
    }
    if !seen {
      continue
    }
    let width = max_x - min_x + 2.0 * padding
    let height = max_y - min_y + 2.0 * padding
    node_boxes[container_id] = @graph.Box::new(
      min_x - padding,
      min_y - padding,
      width,
      height,
    )
  }
}

///|
fn relax_layout_nodes_against_containers(
  node_boxes : Map[String, @graph.Box],
  graph : @graph.GraphInput,
  parent_id_by_child_id : Map[String, String],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Unit {
  let container_ids : Array[String] = []
  for obj in graph.objects {
    if is_layout_container_candidate(obj) {
      container_ids.push(obj.id)
    }
  }
  let gap = @cmp.maximum(12.0, config.edge_padding)
  for _ in 0..<8 {
    let mut changed = false
    for obj in graph.objects {
      if is_layout_container_candidate(obj) {
        continue
      }
      let box = match node_boxes.get(obj.id) {
        Some(v) => v
        None => continue
      }
      let mut dx = 0.0
      let mut dy = 0.0
      for container_id in container_ids {
        if is_descendant_of_id(obj.id, container_id, parent_id_by_child_id) ||
          is_descendant_of_id(container_id, obj.id, parent_id_by_child_id) {
          continue
        }
        let c_box = match node_boxes.get(container_id) {
          Some(v) => v
          None => continue
        }
        if !boxes_overlap_with_gap(box, c_box, gap) {
          continue
        }
        match direction {
          Down | Up => {
            let target_x = c_box.x + c_box.width + gap
            let delta_x = target_x - box.x
            if delta_x > dx {
              dx = delta_x
            }
          }
          Right | Left => {
            let target_y = c_box.y + c_box.height + gap
            let delta_y = target_y - box.y
            if delta_y > dy {
              dy = delta_y
            }
          }
        }
      }
      if dx > 0.0 || dy > 0.0 {
        node_boxes[obj.id] = @graph.Box::new(
          box.x + dx,
          box.y + dy,
          box.width,
          box.height,
        )
        changed = true
      }
    }
    if !changed {
      break
    }
  }
}

///|
fn boxes_overlap_with_gap(a : @graph.Box, b : @graph.Box, gap : Double) -> Bool {
  !(a.x + a.width + gap <= b.x ||
  b.x + b.width + gap <= a.x ||
  a.y + a.height + gap <= b.y ||
  b.y + b.height + gap <= a.y)
}

///|
fn is_descendant_of_id(
  node_id : String,
  ancestor_id : String,
  parent_id_by_child_id : Map[String, String],
) -> Bool {
  if node_id == ancestor_id {
    return true
  }
  let mut curr = node_id
  while true {
    match parent_id_by_child_id.get(curr) {
      Some(parent_id) => {
        if parent_id == ancestor_id {
          return true
        }
        curr = parent_id
      }
      None => return false
    }
  }
  false
}

///|
priv struct PortItem {
  edge_index : Int
  desired_axis : Double
}

///|
fn port_axis(p : @graph.Point, flow : @engine_api.Direction) -> Double {
  match flow {
    Down | Up => p.x
    Right | Left => p.y
  }
}

///|
fn port_margin(
  box : @graph.Box,
  flow : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Double {
  let base = @cmp.maximum(6.0, config.edge_padding / 2.0)
  match flow {
    Down | Up => @cmp.maximum(0.0, @cmp.minimum(base, box.width / 2.0 - 1.0))
    Right | Left =>
      @cmp.maximum(0.0, @cmp.minimum(base, box.height / 2.0 - 1.0))
  }
}

///|
fn exit_of_box_at(
  box : @graph.Box,
  flow : @engine_api.Direction,
  t : Double,
  config : @engine_api.LayoutConfig,
) -> @graph.Point {
  let m = port_margin(box, flow, config)
  match flow {
    Down => {
      let x = box.x + m + (box.width - 2.0 * m) * t
      @graph.Point::new(x, box.y + box.height)
    }
    Up => {
      let x = box.x + m + (box.width - 2.0 * m) * t
      @graph.Point::new(x, box.y)
    }
    Right => {
      let y = box.y + m + (box.height - 2.0 * m) * t
      @graph.Point::new(box.x + box.width, y)
    }
    Left => {
      let y = box.y + m + (box.height - 2.0 * m) * t
      @graph.Point::new(box.x, y)
    }
  }
}

///|
fn entry_of_box_at(
  box : @graph.Box,
  flow : @engine_api.Direction,
  t : Double,
  config : @engine_api.LayoutConfig,
) -> @graph.Point {
  let m = port_margin(box, flow, config)
  match flow {
    Down => {
      let x = box.x + m + (box.width - 2.0 * m) * t
      @graph.Point::new(x, box.y)
    }
    Up => {
      let x = box.x + m + (box.width - 2.0 * m) * t
      @graph.Point::new(x, box.y + box.height)
    }
    Right => {
      let y = box.y + m + (box.height - 2.0 * m) * t
      @graph.Point::new(box.x, y)
    }
    Left => {
      let y = box.y + m + (box.height - 2.0 * m) * t
      @graph.Point::new(box.x + box.width, y)
    }
  }
}

///|
fn assign_ports(
  graph : @graph.GraphInput,
  id_to_idx : Map[String, Int],
  depths : Array[Int],
  self_loop : @hashset.HashSet[Int],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  boxes : Map[String, @graph.Box],
) -> (Map[Int, @graph.Point], Map[Int, @graph.Point]) raise @engine_api.LayoutError {
  let src_groups : Map[String, Array[PortItem]] = {}
  let src_meta : Map[String, (String, @engine_api.Direction)] = {}
  let dst_groups : Map[String, Array[PortItem]] = {}
  let dst_meta : Map[String, (String, @engine_api.Direction)] = {}
  for e in graph.edges {
    if self_loop.contains(e.index) {
      continue
    }
    let su = require_index(id_to_idx, e.src_id)
    let sv = require_index(id_to_idx, e.dst_id)
    let src_level = depths[su]
    let dst_level = depths[sv]
    if src_level == dst_level {
      continue
    }
    let flow = edge_flow_direction(direction, src_level, dst_level)
    let src_box = match boxes.get(e.src_id) {
      Some(b) => b
      None => raise Unsupported("missing box for node: \{e.src_id}")
    }
    let dst_box = match boxes.get(e.dst_id) {
      Some(b) => b
      None => raise Unsupported("missing box for node: \{e.dst_id}")
    }
    let desired_for_src = dst_box.center()
    let desired_for_dst = src_box.center()
    let src_key = "s:\{e.src_id}:\{flow}"
    let dst_key = "t:\{e.dst_id}:\{flow}"
    if !src_meta.contains(src_key) {
      src_meta[src_key] = (e.src_id, flow)
    }
    if !dst_meta.contains(dst_key) {
      dst_meta[dst_key] = (e.dst_id, flow)
    }
    let src_item = {
      edge_index: e.index,
      desired_axis: port_axis(desired_for_src, flow),
    }
    let dst_item = {
      edge_index: e.index,
      desired_axis: port_axis(desired_for_dst, flow),
    }
    match src_groups.get(src_key) {
      Some(arr) => arr.push(src_item)
      None => src_groups[src_key] = [src_item]
    }
    match dst_groups.get(dst_key) {
      Some(arr) => arr.push(dst_item)
      None => dst_groups[dst_key] = [dst_item]
    }
  }
  let src_ports : Map[Int, @graph.Point] = {}
  let dst_ports : Map[Int, @graph.Point] = {}
  fn axis_min_max(
    box : @graph.Box,
    flow : @engine_api.Direction,
  ) -> (Double, Double) {
    match flow {
      Down | Up => (box.x, box.x + box.width)
      Right | Left => (box.y, box.y + box.height)
    }
  }

  fn port_point_on_axis(
    box : @graph.Box,
    flow : @engine_api.Direction,
    is_source : Bool,
    axis : Double,
  ) -> @graph.Point {
    match (flow, is_source) {
      (Down, true) => @graph.Point::new(axis, box.y + box.height)
      (Down, false) => @graph.Point::new(axis, box.y)
      (Up, true) => @graph.Point::new(axis, box.y)
      (Up, false) => @graph.Point::new(axis, box.y + box.height)
      (Right, true) => @graph.Point::new(box.x + box.width, axis)
      (Right, false) => @graph.Point::new(box.x, axis)
      (Left, true) => @graph.Point::new(box.x, axis)
      (Left, false) => @graph.Point::new(box.x + box.width, axis)
    }
  }

  fn assign_group(
    items : Array[PortItem],
    is_source : Bool,
    node_id : String,
    flow : @engine_api.Direction,
  ) -> Unit raise @engine_api.LayoutError {
    let ordered = items.copy()
    ordered.sort_by(fn(a, b) {
      if a.desired_axis < b.desired_axis {
        -1
      } else if a.desired_axis > b.desired_axis {
        1
      } else {
        a.edge_index - b.edge_index
      }
    })
    let k = ordered.length()
    let box = match boxes.get(node_id) {
      Some(b) => b
      None => raise Unsupported("missing box for node: \{node_id}")
    }
    let m = port_margin(box, flow, config)
    let (lo0, hi0) = axis_min_max(box, flow)
    let lo = lo0 + m
    let hi = hi0 - m
    if k == 1 || hi <= lo + 1.0e-6 {
      let ei = ordered[0].edge_index
      let axis = (lo + hi) / 2.0
      let p = port_point_on_axis(box, flow, is_source, axis)
      if is_source {
        src_ports[ei] = p
      } else {
        dst_ports[ei] = p
      }
      return
    }
    let span = hi - lo
    let max_sep = span / (k - 1).to_double()
    let ideal_sep = span / (k + 1).to_double()
    let base_sep = track_spacing(config) * 1.2
    let min_sep = @cmp.minimum(max_sep, @cmp.maximum(base_sep, ideal_sep))
    let pos : Array[Double] = Array::make(k, 0.0)
    let mut desired_sum = 0.0
    for i in 0..<k {
      let v0 = ordered[i].desired_axis
      let v1 = @cmp.maximum(lo, @cmp.minimum(v0, hi))
      pos[i] = v1
      desired_sum = desired_sum + v1
    }
    for i in 1..<k {
      pos[i] = @cmp.maximum(pos[i], pos[i - 1] + min_sep)
    }
    pos[k - 1] = @cmp.minimum(pos[k - 1], hi)
    for i = k - 2; i >= 0; i = i - 1 {
      pos[i] = @cmp.minimum(pos[i], pos[i + 1] - min_sep)
    }
    pos[0] = @cmp.maximum(pos[0], lo)
    let pos_min = pos[0]
    let pos_max = pos[k - 1]
    let desired_center = desired_sum / k.to_double()
    let pos_center = (pos_min + pos_max) / 2.0
    let delta0 = desired_center - pos_center
    let delta = @cmp.maximum(lo - pos_min, @cmp.minimum(delta0, hi - pos_max))
    for i in 0..<k {
      pos[i] = pos[i] + delta
    }
    for i in 0..<k {
      let ei = ordered[i].edge_index
      let p = port_point_on_axis(box, flow, is_source, pos[i])
      if is_source {
        src_ports[ei] = p
      } else {
        dst_ports[ei] = p
      }
    }
  }

  for entry in src_groups {
    let key = entry.0
    let items = entry.1
    let (node_id, flow) = match src_meta.get(key) {
      Some(v) => v
      None => raise Unsupported("missing src port meta for key: \{key}")
    }
    assign_group(items, true, node_id, flow)
  }
  for entry in dst_groups {
    let key = entry.0
    let items = entry.1
    let (node_id, flow) = match dst_meta.get(key) {
      Some(v) => v
      None => raise Unsupported("missing dst port meta for key: \{key}")
    }
    assign_group(items, false, node_id, flow)
  }

  // Ensure every routed edge has a port, even if it didn't appear in groups.
  for e in graph.edges {
    if self_loop.contains(e.index) {
      continue
    }
    let su = require_index(id_to_idx, e.src_id)
    let sv = require_index(id_to_idx, e.dst_id)
    let src_level = depths[su]
    let dst_level = depths[sv]
    if src_level == dst_level {
      continue
    }
    let flow = edge_flow_direction(direction, src_level, dst_level)
    if !src_ports.contains(e.index) {
      let b = match boxes.get(e.src_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{e.src_id}")
      }
      src_ports[e.index] = exit_of_box_at(b, flow, 0.5, config)
    }
    if !dst_ports.contains(e.index) {
      let b = match boxes.get(e.dst_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{e.dst_id}")
      }
      dst_ports[e.index] = entry_of_box_at(b, flow, 0.5, config)
    }
  }

  (src_ports, dst_ports)
}

///|
priv struct EdgeInterval {
  start : Int
  end : Int
  edge_index : Int
}

///|
priv struct TrackUsage {
  end : Int
  track : Int
} derive(Eq)

///|
impl Compare for TrackUsage with compare(a, b) {
  let c = a.end.compare(b.end)
  if c != 0 {
    c
  } else {
    a.track.compare(b.track)
  }
}

///|
fn track_spacing(config : @engine_api.LayoutConfig) -> Double {
  @cmp.maximum(6.0, config.edge_padding / 2.0)
}

///|
fn allocate_interval_tracks(intervals : Array[EdgeInterval]) -> Map[Int, Int] {
  let track_by_edge : Map[Int, Int] = {}
  if intervals.length() == 0 {
    return track_by_edge
  }
  let ordered = intervals.copy()
  ordered.sort_by(fn(a, b) {
    let c = a.start.compare(b.start)
    if c != 0 {
      c
    } else {
      a.end.compare(b.end)
    }
  })
  let active : @priority_queue.PriorityQueue[@cmp.Reverse[TrackUsage]] = @priority_queue.new()
  let free : @priority_queue.PriorityQueue[@cmp.Reverse[Int]] = @priority_queue.new()
  let mut next_track = 0
  for it in ordered {
    // Release tracks whose interval ended before this one begins.
    while active.peek() is Some(@cmp.Reverse(u)) && u.end <= it.start {
      ignore(active.pop())
      free.push(@cmp.Reverse(u.track))
    }
    let track = match free.pop() {
      Some(@cmp.Reverse(t)) => t
      None => {
        let t = next_track
        next_track = next_track + 1
        t
      }
    }
    track_by_edge[it.edge_index] = track
    active.push(@cmp.Reverse({ end: it.end, track }))
  }
  track_by_edge
}

///|
priv struct EdgeSpan {
  start : Double
  end : Double
  edge_index : Int
}

///|
priv struct LaneUsage {
  end : Double
  lane : Int
} derive(Eq)

///|
impl Compare for LaneUsage with compare(a, b) {
  let c = a.end.compare(b.end)
  if c != 0 {
    c
  } else {
    a.lane.compare(b.lane)
  }
}

///|
fn allocate_span_lanes(spans : Array[EdgeSpan]) -> (Map[Int, Int], Int) {
  let lane_by_edge : Map[Int, Int] = {}
  if spans.length() == 0 {
    return (lane_by_edge, 0)
  }
  let ordered = spans.copy()
  ordered.sort_by(fn(a, b) {
    let c = a.start.compare(b.start)
    if c != 0 {
      c
    } else {
      a.end.compare(b.end)
    }
  })
  let active : @priority_queue.PriorityQueue[@cmp.Reverse[LaneUsage]] = @priority_queue.new()
  let free : @priority_queue.PriorityQueue[@cmp.Reverse[Int]] = @priority_queue.new()
  let mut next_lane = 0
  for it in ordered {
    while active.peek() is Some(@cmp.Reverse(u)) && u.end <= it.start {
      ignore(active.pop())
      free.push(@cmp.Reverse(u.lane))
    }
    let lane = match free.pop() {
      Some(@cmp.Reverse(t)) => t
      None => {
        let t = next_lane
        next_lane = next_lane + 1
        t
      }
    }
    lane_by_edge[it.edge_index] = lane
    active.push(@cmp.Reverse({ end: it.end, lane }))
  }
  (lane_by_edge, next_lane)
}

///|
fn assign_gap_lane_offsets(
  graph : @graph.GraphInput,
  id_to_idx : Map[String, Int],
  depths : Array[Int],
  self_loop : @hashset.HashSet[Int],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  src_ports : Map[Int, @graph.Point],
  dst_ports : Map[Int, @graph.Point],
) -> Map[Int, Double] raise @engine_api.LayoutError {
  let spans_by_gap : Map[Int, Array[EdgeSpan]] = {}
  for e in graph.edges {
    if self_loop.contains(e.index) {
      continue
    }
    let su = require_index(id_to_idx, e.src_id)
    let sv = require_index(id_to_idx, e.dst_id)
    let src_level = depths[su]
    let dst_level = depths[sv]
    let span = Int::abs(dst_level - src_level)
    if span != 1 {
      continue
    }
    let flow = edge_flow_direction(direction, src_level, dst_level)
    if flow != direction {
      // Back edges already get distinct rails by `rail_track`.
      continue
    }
    let start = match src_ports.get(e.index) {
      Some(p) => p
      None => raise Unsupported("missing src port for edge: \{e.index}")
    }
    let end = match dst_ports.get(e.index) {
      Some(p) => p
      None => raise Unsupported("missing dst port for edge: \{e.index}")
    }
    let (a0, a1, needs_rail) = match flow {
      Down | Up =>
        (
          @cmp.minimum(start.x, end.x),
          @cmp.maximum(start.x, end.x),
          start.x != end.x,
        )
      Right | Left =>
        (
          @cmp.minimum(start.y, end.y),
          @cmp.maximum(start.y, end.y),
          start.y != end.y,
        )
    }
    if !needs_rail {
      continue
    }
    let gap = @cmp.minimum(src_level, dst_level)
    match spans_by_gap.get(gap) {
      Some(arr) => arr.push({ start: a0, end: a1, edge_index: e.index })
      None => spans_by_gap[gap] = [{ start: a0, end: a1, edge_index: e.index }]
    }
  }
  let shift_by_edge : Map[Int, Double] = {}
  for entry in spans_by_gap {
    let spans = entry.1
    let (lane_by_edge, lane_count) = allocate_span_lanes(spans)
    if lane_count <= 1 {
      continue
    }
    let center = (lane_count - 1).to_double() / 2.0
    // Keep rails away from node boundaries so rounded corners don't start
    // immediately at the box exit/entry.
    let min_clear = @cmp.maximum(12.0, config.edge_padding / 2.0)
    let max_offset = @cmp.maximum(
      0.0,
      config.vertical_spacing / 2.0 - min_clear,
    )
    let mut spacing = track_spacing(config)
    if center > 0.0 && spacing * center > max_offset {
      spacing = max_offset / center
    }
    for lane_entry in lane_by_edge {
      let lane = lane_entry.1
      let offset = (lane.to_double() - center) * spacing
      shift_by_edge[lane_entry.0] = offset
    }
  }
  shift_by_edge
}

///|
fn assign_rail_tracks(
  graph : @graph.GraphInput,
  id_to_idx : Map[String, Int],
  depths : Array[Int],
  self_loop : @hashset.HashSet[Int],
  direction : @engine_api.Direction,
) -> Map[Int, Int] raise @engine_api.LayoutError {
  let forward_long : Array[EdgeInterval] = []
  let back_edges : Array[EdgeInterval] = []
  for e in graph.edges {
    if self_loop.contains(e.index) {
      continue
    }
    let su = require_index(id_to_idx, e.src_id)
    let sv = require_index(id_to_idx, e.dst_id)
    let src_level = depths[su]
    let dst_level = depths[sv]
    if src_level == dst_level {
      continue
    }
    let start = @cmp.minimum(src_level, dst_level)
    let end = @cmp.maximum(src_level, dst_level)
    let flow = edge_flow_direction(direction, src_level, dst_level)
    let span = end - start
    if flow != direction {
      back_edges.push({ start, end, edge_index: e.index })
    } else if span > 1 {
      forward_long.push({ start, end, edge_index: e.index })
    }
  }
  let tracks : Map[Int, Int] = {}
  for entry in allocate_interval_tracks(back_edges) {
    tracks[entry.0] = entry.1
  }
  for entry in allocate_interval_tracks(forward_long) {
    tracks[entry.0] = entry.1
  }
  tracks
}

///|
fn opposite_direction(d : @engine_api.Direction) -> @engine_api.Direction {
  match d {
    Down => Up
    Up => Down
    Right => Left
    Left => Right
  }
}

///|
fn edge_flow_direction(
  layout_direction : @engine_api.Direction,
  src_level : Int,
  dst_level : Int,
) -> @engine_api.Direction {
  if dst_level >= src_level {
    layout_direction
  } else {
    opposite_direction(layout_direction)
  }
}

///|
fn route_edge(
  edge_index : Int,
  src_id : String,
  dst_id : String,
  src_level : Int,
  dst_level : Int,
  rail_track : Int,
  rail_shift : Double,
  start : @graph.Point,
  end : @graph.Point,
  boxes : Map[String, @graph.Box],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  level_heights : Array[Double],
) -> Array[@graph.Point] raise @engine_api.LayoutError {
  ignore(edge_index)
  ignore(src_id)
  ignore(dst_id)
  if dst_level == src_level {
    raise Unsupported(
      "route_edge: dst_level is \{dst_level}, src_level is \{src_level}",
    )
  }
  let flow = edge_flow_direction(direction, src_level, dst_level)
  let step = if dst_level > src_level { 1 } else { -1 }
  let span = if dst_level > src_level {
    dst_level - src_level
  } else {
    src_level - dst_level
  }
  let rails : Array[Double] = []
  for level = src_level {
    if level == dst_level {
      break
    }
    let next_level = level + step
    let rail_level = if step == 1 { level } else { next_level }
    rails.push(
      calculate_rail(level_heights, rail_level, config.vertical_spacing),
    )
    continue next_level
  }
  let waypoints : Array[@graph.Point] = []
  waypoints.push(start)
  if rails.length() == 0 {
    // Defensive: should be unreachable when `src_level != dst_level`.
    waypoints.push(end)
    return waypoints
  }
  // Back-edge routing (opposite to layout direction): use a single outer rail,
  // and avoid adding per-level intermediate waypoints.
  match (direction, flow) {
    (Down, Up) => {
      let rail_x = global_backward_rail_anchor(boxes, level_heights.length()) +
        config.edge_padding +
        track_spacing(config) * rail_track.to_double()
      let start_on_rail = @graph.Point::new(rail_x, start.y)
      // Leave the rail just below the destination, then enter vertically so the
      // arrowhead direction is correct.
      let last_rail = rails[rails.length() - 1]
      push_if_new(waypoints, start_on_rail)
      push_if_new(waypoints, @graph.Point::new(rail_x, last_rail))
      push_if_new(waypoints, point_on_rail(end, last_rail, flow))
      push_if_new(waypoints, end)
      return enforce_flow_tangent(waypoints, flow)
    }
    (Up, Down) => {
      let rail_x = global_backward_rail_anchor(boxes, level_heights.length()) +
        config.edge_padding +
        track_spacing(config) * rail_track.to_double()
      let start_on_rail = @graph.Point::new(rail_x, start.y)
      let last_rail = rails[rails.length() - 1]
      push_if_new(waypoints, start_on_rail)
      push_if_new(waypoints, @graph.Point::new(rail_x, last_rail))
      push_if_new(waypoints, point_on_rail(end, last_rail, flow))
      push_if_new(waypoints, end)
      return enforce_flow_tangent(waypoints, flow)
    }
    _ => ()
  }
  if span == 1 {
    let rail = rails[0] + rail_shift
    let points = waypoints_between(start, end, rail, flow)
    waypoints.append(points)
    push_if_new(waypoints, end)
    return enforce_flow_tangent(waypoints, flow)
  }
  // Long edge: use ONE virtual rail anchor for the whole edge.
  // Virtual nodes are NOT waypoints; only rail points are.
  let anchor_level = src_level + step
  let anchor_id = if step == 1 {
    forward_virtual_node_label(anchor_level)
  } else {
    backward_virtual_node_label(anchor_level)
  }
  let anchor_box = match boxes.get(anchor_id) {
    Some(b) => b
    None => raise Unsupported("missing box for node: \{anchor_id}")
  }
  let anchor = match flow {
    Down | Up => anchor_box.x + anchor_box.width / 2.0
    Right | Left => anchor_box.y + anchor_box.height / 2.0
  }
  let anchor = match direction {
    Down | Up => anchor - track_spacing(config) * rail_track.to_double()
    Right | Left => anchor - track_spacing(config) * rail_track.to_double()
  }

  // Go from src exit to the first rail.
  let first_rail = rails[0]
  push_if_new(waypoints, point_on_rail(start, first_rail, flow))
  // Move onto the chosen rail anchor.
  push_if_new(waypoints, anchor_on_rail(anchor, first_rail, flow))
  // Traverse intermediate rails while staying on the same anchor.
  for i in 1..<rails.length() {
    push_if_new(waypoints, anchor_on_rail(anchor, rails[i], flow))
  }
  // Leave the anchor on the last rail and enter the destination.
  let last_rail = rails[rails.length() - 1]
  push_if_new(waypoints, point_on_rail(end, last_rail, flow))
  push_if_new(waypoints, end)
  enforce_flow_tangent(waypoints, flow)
}

///|
fn enforce_flow_tangent(
  route : Array[@graph.Point],
  flow : @engine_api.Direction,
) -> Array[@graph.Point] {
  if route.length() < 2 {
    return route
  }
  fn approx_eq(a : Double, b : Double) -> Bool {
    (a - b).abs() <= 1.0e-6
  }
  let with_start : Array[@graph.Point] = []
  let p0 = route[0]
  let p1 = route[1]
  with_start.push(p0)
  match flow {
    Down | Up =>
      if !approx_eq(p0.x, p1.x) {
        with_start.push(@graph.Point::new(p0.x, p1.y))
      }
    Right | Left =>
      if !approx_eq(p0.y, p1.y) {
        with_start.push(@graph.Point::new(p1.x, p0.y))
      }
  }
  for i in 1..<route.length() {
    with_start.push(route[i])
  }

  if with_start.length() < 2 {
    return with_start
  }
  let n = with_start.length()
  let end = with_start[n - 1]
  let prev = with_start[n - 2]
  let with_end : Array[@graph.Point] = []
  for i in 0..<(n - 1) {
    with_end.push(with_start[i])
  }
  match flow {
    Down | Up =>
      if !approx_eq(prev.x, end.x) {
        with_end.push(@graph.Point::new(end.x, prev.y))
      }
    Right | Left =>
      if !approx_eq(prev.y, end.y) {
        with_end.push(@graph.Point::new(prev.x, end.y))
      }
  }
  with_end.push(end)

  let cleaned : Array[@graph.Point] = []
  for p in with_end {
    push_if_new(cleaned, p)
  }
  cleaned
}

///|
fn global_backward_rail_anchor(
  boxes : Map[String, @graph.Box],
  level_count : Int,
) -> Double raise @engine_api.LayoutError {
  let mut best = 0.0
  let mut has_any = false
  for level in 0..<level_count {
    let id = backward_virtual_node_label(level)
    match boxes.get(id) {
      Some(b) => {
        let x = b.x + b.width / 2.0
        if !has_any || x > best {
          best = x
          has_any = true
        }
      }
      None => ()
    }
  }
  if !has_any {
    raise Unsupported("missing backward virtual rail anchors")
  }
  best
}

///|
fn point_on_rail(
  p : @graph.Point,
  rail : Double,
  direction : @engine_api.Direction,
) -> @graph.Point {
  match direction {
    Down | Up => @graph.Point::new(p.x, rail)
    Right | Left => @graph.Point::new(rail, p.y)
  }
}

///|
fn anchor_on_rail(
  anchor : Double,
  rail : Double,
  direction : @engine_api.Direction,
) -> @graph.Point {
  match direction {
    Down | Up => @graph.Point::new(anchor, rail)
    Right | Left => @graph.Point::new(rail, anchor)
  }
}

///|
fn push_if_new(points : Array[@graph.Point], p : @graph.Point) -> Unit {
  if points.length() == 0 || points[points.length() - 1] != p {
    points.push(p)
  }
}

///|
fn calculate_rail(
  level_heights : Array[Double],
  level : Int,
  v_space : Double,
) -> Double {
  // Rail sits in the middle of the spacing gap between `level` and `level + 1`.
  // `level_heights[i]` already includes `v_space`.
  let mut rail = 0.0
  for i in 0..<(level + 1) {
    rail += level_heights[i]
  }
  rail - v_space / 2.0
}

///|
fn waypoints_between(
  src : @graph.Point,
  dst : @graph.Point,
  rail : Double,
  direction : @engine_api.Direction,
) -> Array[@graph.Point] {
  match direction {
    Down | Up =>
      if src.x == dst.x {
        []
      } else {
        [@graph.Point::new(src.x, rail), @graph.Point::new(dst.x, rail)]
      }
    Right | Left =>
      if src.y == dst.y {
        []
      } else {
        [@graph.Point::new(rail, src.y), @graph.Point::new(rail, dst.y)]
      }
  }
}

///|
fn entry_of_box(
  box : @graph.Box,
  direction : @engine_api.Direction,
) -> @graph.Point {
  match direction {
    Down => @graph.Point::new(box.x + box.width / 2, box.y)
    Up => @graph.Point::new(box.x + box.width / 2, box.y + box.height)
    Right => @graph.Point::new(box.x, box.y + box.height / 2)
    Left => @graph.Point::new(box.x + box.width, box.y + box.height / 2)
  }
}

///|
fn exit_of_box(
  box : @graph.Box,
  direction : @engine_api.Direction,
) -> @graph.Point {
  match direction {
    Down => @graph.Point::new(box.x + box.width / 2, box.y + box.height)
    Up => @graph.Point::new(box.x + box.width / 2, box.y)
    Right => @graph.Point::new(box.x + box.width, box.y + box.height / 2)
    Left => @graph.Point::new(box.x, box.y + box.height / 2)
  }
}

///|
fn place_nodes(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
  levels : Array[Level],
) -> (Map[String, @graph.Box], Array[Double]) {
  let boxes = Map::new()
  let level_heights = []
  let level_spans : Array[Double] = []
  let level_max_heights : Array[Double] = []
  let level_max_widths : Array[Double] = []
  let mut global_span = 0.0
  let object_by_id : Map[String, @graph.ObjectInput] = Map::new(
    capacity=graph.objects.length() * 2,
  )
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  for level in levels {
    let level_objects : Array[@graph.ObjectInput] = []
    for id in level {
      match object_by_id.get(id) {
        Some(obj) => level_objects.push(obj)
        None => ()
      }
    }
    let level_length = level_objects.length() + 2
    let (max_object_width, max_object_height) = {
      let mut mw = 0.0
      let mut mh = 0.0
      for obj in level_objects {
        let (w, h) = object_size(obj, config)
        mw = @cmp.maximum(w, mw)
        mh = @cmp.maximum(h, mh)
      }
      (mw, mh)
    }
    let span = match direction {
      Down | Up => {
        let cell = max_object_width + config.horizontal_spacing
        (level_length - 1).to_double() * cell + max_object_width
      }
      Right | Left => {
        let cell = max_object_height + config.vertical_spacing
        (level_length - 1).to_double() * cell + max_object_height
      }
    }
    level_spans.push(span)
    level_max_heights.push(max_object_height)
    level_max_widths.push(max_object_width)
    global_span = @cmp.maximum(global_span, span)
  }
  let mut layer_offset = 0.0
  for i, level in levels {
    let level_objects : Array[@graph.ObjectInput] = []
    for id in level {
      match object_by_id.get(id) {
        Some(obj) => level_objects.push(obj)
        None => ()
      }
    }
    let max_object_width = level_max_widths[i]
    let max_object_height = level_max_heights[i]
    let (level_thickness, node_offset0) = match direction {
      Down | Up =>
        (
          max_object_height + config.vertical_spacing,
          (global_span - level_spans[i]) / 2.0,
        )
      Right | Left =>
        (
          max_object_width + config.horizontal_spacing,
          (global_span - level_spans[i]) / 2.0,
        )
    }
    let mut node_offset = node_offset0

    // put the downward virtual node 
    let box = match direction {
      Down | Up =>
        @graph.Box::new(
          node_offset + max_object_width / 2,
          layer_offset + max_object_height / 2,
          0,
          0,
        )
      Right | Left =>
        @graph.Box::new(
          layer_offset + max_object_width / 2,
          node_offset + max_object_height / 2,
          0,
          0,
        )
    }
    let label = forward_virtual_node_label(i)
    boxes[label] = box
    node_offset += match direction {
      Down | Up => max_object_width + config.horizontal_spacing
      Right | Left => max_object_height + config.vertical_spacing
    }

    // put physical nodes
    for obj in level_objects {
      let (w, h) = object_size(obj, config)
      let box = match direction {
        Down | Up =>
          @graph.Box::new(
            node_offset + max_object_width / 2 - w / 2,
            layer_offset + max_object_height / 2 - h / 2,
            w,
            h,
          )
        Right | Left =>
          @graph.Box::new(
            layer_offset + max_object_width / 2 - w / 2,
            node_offset + max_object_height / 2 - h / 2,
            w,
            h,
          )
      }
      let label = obj.id
      boxes[label] = box
      node_offset += match direction {
        Down | Up => max_object_width + config.horizontal_spacing
        Right | Left => max_object_height + config.vertical_spacing
      }
    }

    // put the upward virtual node
    let box = match direction {
      Down | Up =>
        @graph.Box::new(
          node_offset + max_object_width / 2,
          layer_offset + max_object_height / 2,
          0,
          0,
        )
      Right | Left =>
        @graph.Box::new(
          layer_offset + max_object_width / 2,
          node_offset + max_object_height / 2,
          0,
          0,
        )
    }
    let label = backward_virtual_node_label(i)
    boxes[label] = box
    level_heights.push(level_thickness)
    layer_offset += level_thickness
  }
  // Mirror coordinates for reverse flow directions so depth increases "against" the axis.
  match direction {
    Up => {
      let mut max_y = 0.0
      for entry in boxes {
        let b = entry.1
        max_y = @cmp.maximum(max_y, b.y + b.height)
      }
      for entry in boxes {
        let id = entry.0
        let b = entry.1
        boxes[id] = @graph.Box::new(
          b.x,
          max_y - (b.y + b.height),
          b.width,
          b.height,
        )
      }
    }
    Left => {
      let mut max_x = 0.0
      for entry in boxes {
        let b = entry.1
        max_x = @cmp.maximum(max_x, b.x + b.width)
      }
      for entry in boxes {
        let id = entry.0
        let b = entry.1
        boxes[id] = @graph.Box::new(
          max_x - (b.x + b.width),
          b.y,
          b.width,
          b.height,
        )
      }
    }
    _ => ()
  }
  (boxes, level_heights)
}

///|
fn forward_virtual_node_label(level : Int) -> String {
  "level-\{level}-forward-virtual"
}

///|
fn backward_virtual_node_label(level : Int) -> String {
  "level-\{level}-backward-virtual"
}

///|
fn self_loop_route(
  b : @graph.Box,
  direction : @engine_api.Direction,
  edge_padding : Double,
) -> Array[@graph.Point] {
  let start = exit_of_box(b, direction)
  let end = entry_of_box(b, direction)
  match direction {
    Down =>
      [
        start,
        @graph.Point::new(start.x, start.y + edge_padding),
        @graph.Point::new(b.x + b.width + edge_padding, start.y + edge_padding),
        @graph.Point::new(b.x + b.width + edge_padding, b.y - edge_padding),
        end,
      ]
    Up =>
      [
        start,
        @graph.Point::new(start.x, start.y - edge_padding),
        @graph.Point::new(b.x + b.width + edge_padding, start.y - edge_padding),
        @graph.Point::new(
          b.x + b.width + edge_padding,
          b.y + b.height + edge_padding,
        ),
        end,
      ]
    Right =>
      [
        start,
        @graph.Point::new(start.x + edge_padding, start.y),
        @graph.Point::new(start.x + edge_padding, b.y + b.height + edge_padding),
        @graph.Point::new(b.x - edge_padding, b.y + b.height + edge_padding),
        end,
      ]
    Left =>
      [
        start,
        @graph.Point::new(start.x - edge_padding, start.y),
        @graph.Point::new(start.x - edge_padding, b.y + b.height + edge_padding),
        @graph.Point::new(
          b.x + b.width + edge_padding,
          b.y + b.height + edge_padding,
        ),
        end,
      ]
  }
}

///|
fn object_size(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
) -> (Double, Double) {
  match obj.box {
    Some(b) => (b.width, b.height)
    None => {
      let font_size = match obj.style.font_size {
        Some(v) => v.as_int().unwrap_or(16)
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
      let label_width = if dims.width > 0.0 {
        dims.width + 24.0
      } else {
        config.default_width
      }
      let label_height = if dims.height > 0.0 {
        dims.height + 16.0
      } else {
        config.default_height
      }
      (
        @cmp.maximum(config.default_width, label_width),
        @cmp.maximum(config.default_height, label_height),
      )
    }
  }
}

///|
fn recompute_edge_label_boxes(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  for edge in graph.edges {
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
    patch.edge_labels[edge.index] = @graph.Box::new(
      center.x - width / 2.0,
      center.y - height / 2.0,
      width,
      height,
    )
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
