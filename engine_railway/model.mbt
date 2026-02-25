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
fn build_railway_layout_input(
  graph : @graph.GraphInput,
) -> (@graph.GraphInput, Map[String, @graph.ObjectInput], Map[String, String]) {
  let (object_by_id, parent_id_by_child_id) = build_object_maps_railway(graph)
  let layout_node_ids : Map[String, Bool] = {}
  let layout_objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if is_inner_member_of_sql_or_class(
        obj.id,
        object_by_id,
        parent_id_by_child_id,
      ) {
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
fn is_inner_member_of_sql_or_class(
  id : String,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> Bool {
  let mut current = id
  while true {
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => {
        match object_by_id.get(parent_id) {
          Some(parent) =>
            if parent.shape_type == @graph.SqlTable ||
              parent.shape_type == @graph.Class {
              return true
            }
          None => ()
        }
        current = parent_id
      }
      None => break
    }
  }
  false
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
  let gap = @cmp.maximum(24.0, config.edge_padding * 2.0)
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
fn spread_sibling_boxes_railway(
  node_boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Unit {
  let children_by_parent : Map[String, Array[String]] = {}
  for entry in parent_id_by_child_id {
    let child_id = entry.0
    let parent_id = entry.1
    match children_by_parent.get(parent_id) {
      Some(arr) => arr.push(child_id)
      None => children_by_parent[parent_id] = [child_id]
    }
  }
  let gap = @cmp.maximum(12.0, config.edge_padding)
  for parent_entry in children_by_parent {
    let sibling_ids : Array[String] = []
    for child_id in parent_entry.1 {
      if !node_boxes.contains(child_id) {
        continue
      }
      match object_by_id.get(child_id) {
        Some(obj) =>
          if obj.shape_type != @graph.Class && obj.shape_type != @graph.SqlTable {
            sibling_ids.push(child_id)
          }
        None => sibling_ids.push(child_id)
      }
    }
    if sibling_ids.length() <= 1 {
      continue
    }
    sibling_ids.sort_by(fn(a, b) {
      let pa = node_boxes.get(a).unwrap()
      let pb = node_boxes.get(b).unwrap()
      let aa = match direction {
        Down | Up => pa.x
        Right | Left => pa.y
      }
      let bb = match direction {
        Down | Up => pb.x
        Right | Left => pb.y
      }
      if aa < bb {
        -1
      } else if aa > bb {
        1
      } else {
        a.compare(b)
      }
    })
    for i in 1..<sibling_ids.length() {
      let prev_id = sibling_ids[i - 1]
      let curr_id = sibling_ids[i]
      let prev_box = node_boxes.get(prev_id).unwrap()
      let curr_box = node_boxes.get(curr_id).unwrap()
      match direction {
        Down | Up => {
          let required_left = prev_box.x + prev_box.width + gap
          if curr_box.x < required_left {
            node_boxes[curr_id] = @graph.Box::new(
              required_left,
              curr_box.y,
              curr_box.width,
              curr_box.height,
            )
          }
        }
        Right | Left => {
          let required_top = prev_box.y + prev_box.height + gap
          if curr_box.y < required_top {
            node_boxes[curr_id] = @graph.Box::new(
              curr_box.x,
              required_top,
              curr_box.width,
              curr_box.height,
            )
          }
        }
      }
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
