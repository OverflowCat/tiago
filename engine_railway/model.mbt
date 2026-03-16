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
fn build_railway_layout_input(
  graph : @graph.GraphInput,
) -> (@graph.GraphInput, Map[String, @graph.ObjectInput], Map[String, String]) {
  let (object_by_id, parent_id_by_child_id) = build_object_maps_railway(graph)
  let layout_node_ids : Map[String, Bool] = {}
  let layout_objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if is_inner_member_of_sql_or_class(
        obj.lookup_id(),
        object_by_id,
        parent_id_by_child_id,
      ) {
      continue
    }
    layout_node_ids[obj.lookup_id()] = true
    layout_objects.push(canonicalize_layout_object(obj))
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
          layout_objects.push(canonicalize_layout_object(obj))
        }
        None => ()
      }
    }
    if !layout_node_ids.contains(dst_id) {
      match object_by_id.get(dst_id) {
        Some(obj) => {
          layout_node_ids[dst_id] = true
          layout_objects.push(canonicalize_layout_object(obj))
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
    canonicalize_layout_object(graph.root),
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
    is_folder_only=graph.is_folder_only,
    data=graph.data,
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
  object_by_id[graph.root.lookup_id()] = graph.root
  for obj in graph.objects {
    object_by_id[obj.lookup_id()] = obj
  }
  let parent_id_by_child_id : Map[String, String] = {}
  for child_id in graph.root.child_ids {
    parent_id_by_child_id[child_id] = graph.root.lookup_id()
  }
  for obj in graph.objects {
    for child_id in obj.child_ids {
      parent_id_by_child_id[child_id] = obj.lookup_id()
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
fn resolve_edge_layout_endpoints_railway(
  graph : @graph.GraphInput,
  edge : @graph.EdgeInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> (String, String) {
  let src_id = collapse_sql_or_class_endpoint_id(
    edge.lookup_src_id(),
    object_by_id,
    parent_id_by_child_id,
  )
  let dst_id = collapse_sql_or_class_endpoint_id(
    edge.lookup_dst_id(),
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
const RAILWAY_CONTAINER_LABEL_PADDING : Double = 5.0

///|
fn is_grid_container_candidate(obj : @graph.ObjectInput) -> Bool {
  obj.grid_rows is Some(_) || obj.grid_columns is Some(_)
}

///|
fn container_label_size_railway(level : Int) -> Int {
  if level <= 1 {
    28
  } else if level == 2 {
    24
  } else if level == 3 {
    20
  } else {
    16
  }
}

///|
fn object_depth_from_dotted_id(id : String) -> Int {
  let mut depth = 1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      depth = depth + 1
    }
  }
  depth
}

///|
fn style_bool_for_container_padding(
  value : @graph.StyleValue?,
  default : Bool,
) -> Bool {
  match value {
    Some(v) => v.as_bool().unwrap_or(default)
    None => default
  }
}

///|
fn style_is_mono_for_container_padding(value : @graph.StyleValue?) -> Bool {
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
fn container_top_padding_railway(
  obj : @graph.ObjectInput,
  base_padding : Double,
) -> Double {
  if obj.label == "" || is_grid_container_candidate(obj) {
    return base_padding
  }
  let (_, label_height) = match container_label_dimensions_railway(obj) {
    Some(v) => v
    None => (0.0, 0.0)
  }
  base_padding + label_height + RAILWAY_CONTAINER_LABEL_PADDING * 2.0
}

///|
fn container_label_dimensions_railway(
  obj : @graph.ObjectInput,
) -> (Double, Double)? {
  if obj.label == "" {
    return None
  }
  let default_font_size = container_label_size_railway(
    object_depth_from_dotted_id(obj.id),
  )
  let font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(default_font_size)
    None => default_font_size
  }
  let is_bold = style_bool_for_container_padding(obj.style.bold, false)
  let is_italic = style_bool_for_container_padding(obj.style.italic, false)
  let is_mono = style_is_mono_for_container_padding(obj.style.font_family)
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
    font_size.to_double()
  }
  Some((width, height))
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
    let top_padding = container_top_padding_railway(container, padding)
    let side_padding = padding
    let bottom_padding = padding
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
    let mut x = min_x - side_padding
    let mut width = max_x - min_x + side_padding * 2.0
    if !is_grid_container_candidate(container) {
      match container_label_dimensions_railway(container) {
        Some((label_width, _)) => {
          let min_width = label_width + side_padding * 10.0
          if width < min_width {
            let grow = min_width - width
            width = min_width
            x = x - grow / 2.0
          }
        }
        None => ()
      }
    }
    let height = max_y - min_y + top_padding + bottom_padding
    node_boxes[container_id] = @graph.Box::new(
      x,
      min_y - top_padding,
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
  fn merge_scalar_intervals(
    intervals : Array[(Double, Double)],
  ) -> Array[(Double, Double)] {
    if intervals.length() <= 1 {
      return intervals
    }
    intervals.sort_by(fn(a, b) {
      if a.0 < b.0 {
        -1
      } else if a.0 > b.0 {
        1
      } else if a.1 < b.1 {
        -1
      } else if a.1 > b.1 {
        1
      } else {
        0
      }
    })
    let merged : Array[(Double, Double)] = []
    let mut cur_lo = intervals[0].0
    let mut cur_hi = intervals[0].1
    for i in 1..<intervals.length() {
      let it = intervals[i]
      if it.0 <= cur_hi + 1.0e-6 {
        cur_hi = @cmp.maximum(cur_hi, it.1)
      } else {
        merged.push((cur_lo, cur_hi))
        cur_lo = it.0
        cur_hi = it.1
      }
    }
    merged.push((cur_lo, cur_hi))
    merged
  }

  fn nearest_value_outside_intervals(
    value : Double,
    lo_bound : Double,
    hi_bound : Double,
    intervals : Array[(Double, Double)],
  ) -> Double {
    if hi_bound <= lo_bound + 1.0e-6 {
      return value
    }
    let merged = merge_scalar_intervals(intervals)
    if merged.is_empty() {
      return @cmp.maximum(lo_bound, @cmp.minimum(value, hi_bound))
    }
    let clamped = @cmp.maximum(lo_bound, @cmp.minimum(value, hi_bound))
    let eps = 1.0
    let candidates : Array[Double] = [clamped]
    for interval in merged {
      let left = @cmp.maximum(
        lo_bound,
        @cmp.minimum(hi_bound, interval.0 - eps),
      )
      let right = @cmp.maximum(
        lo_bound,
        @cmp.minimum(hi_bound, interval.1 + eps),
      )
      candidates.push(left)
      candidates.push(right)
    }
    let mut best = clamped
    let mut best_cost = 0.0
    let mut found = false
    for cand in candidates {
      let mut blocked = false
      for interval in merged {
        if cand >= interval.0 - 1.0e-6 && cand <= interval.1 + 1.0e-6 {
          blocked = true
          break
        }
      }
      if blocked {
        continue
      }
      let cost = (cand - value).abs()
      if !found || cost < best_cost {
        found = true
        best = cand
        best_cost = cost
      }
    }
    if found {
      best
    } else {
      clamped
    }
  }

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
      let mut next_x = box.x
      let mut next_y = box.y
      match direction {
        Down | Up => {
          let lo_bound = -1000000000000.0
          let hi_bound = 1000000000000.0
          let forbidden : Array[(Double, Double)] = []
          for container_id in container_ids {
            if is_descendant_of_id(obj.id, container_id, parent_id_by_child_id) ||
              is_descendant_of_id(container_id, obj.id, parent_id_by_child_id) {
              continue
            }
            let c_box = match node_boxes.get(container_id) {
              Some(v) => v
              None => continue
            }
            let y_overlap = !(box.y + box.height <= c_box.y ||
              c_box.y + c_box.height <= box.y)
            if !y_overlap {
              continue
            }
            forbidden.push(
              (c_box.x - box.width - gap, c_box.x + c_box.width + gap),
            )
          }
          if !forbidden.is_empty() {
            next_x = nearest_value_outside_intervals(
              box.x,
              lo_bound,
              hi_bound,
              forbidden,
            )
          }
        }
        Right | Left => {
          let lo_bound = -1000000000000.0
          let hi_bound = 1000000000000.0
          let forbidden : Array[(Double, Double)] = []
          for container_id in container_ids {
            if is_descendant_of_id(obj.id, container_id, parent_id_by_child_id) ||
              is_descendant_of_id(container_id, obj.id, parent_id_by_child_id) {
              continue
            }
            let c_box = match node_boxes.get(container_id) {
              Some(v) => v
              None => continue
            }
            let x_overlap = !(box.x + box.width <= c_box.x ||
              c_box.x + c_box.width <= box.x)
            if !x_overlap {
              continue
            }
            forbidden.push(
              (c_box.y - box.height - gap, c_box.y + c_box.height + gap),
            )
          }
          if !forbidden.is_empty() {
            next_y = nearest_value_outside_intervals(
              box.y,
              lo_bound,
              hi_bound,
              forbidden,
            )
          }
        }
      }
      if (next_x - box.x).abs() > 1.0e-6 || (next_y - box.y).abs() > 1.0e-6 {
        node_boxes[obj.id] = @graph.Box::new(
          next_x,
          next_y,
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
priv struct RailwaySubtreeEnvelope {
  id : String
  cross_start : Double
  cross_end : Double
  main_start : Double
  main_end : Double
}

///|
fn subtree_union_box_railway(
  root_id : String,
  node_boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
) -> @graph.Box? {
  let stack : Array[String] = [root_id]
  let mut min_x = 1000000000000.0
  let mut max_x = -1000000000000.0
  let mut min_y = 1000000000000.0
  let mut max_y = -1000000000000.0
  let mut seen = false
  while !stack.is_empty() {
    let id = stack.pop().unwrap()
    match node_boxes.get(id) {
      Some(b) => {
        seen = true
        if b.x < min_x {
          min_x = b.x
        }
        if b.y < min_y {
          min_y = b.y
        }
        if b.x + b.width > max_x {
          max_x = b.x + b.width
        }
        if b.y + b.height > max_y {
          max_y = b.y + b.height
        }
      }
      None => ()
    }
    match object_by_id.get(id) {
      Some(obj) =>
        for child_id in obj.child_ids {
          stack.push(child_id)
        }
      None => ()
    }
  }
  if !seen {
    None
  } else {
    Some(@graph.Box::new(min_x, min_y, max_x - min_x, max_y - min_y))
  }
}

///|
fn shift_subtree_railway(
  root_id : String,
  dx : Double,
  dy : Double,
  node_boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
) -> Unit {
  if dx.abs() <= 1.0e-6 && dy.abs() <= 1.0e-6 {
    return
  }
  let stack : Array[String] = [root_id]
  while !stack.is_empty() {
    let id = stack.pop().unwrap()
    match node_boxes.get(id) {
      Some(b) =>
        node_boxes[id] = @graph.Box::new(b.x + dx, b.y + dy, b.width, b.height)
      None => ()
    }
    match object_by_id.get(id) {
      Some(obj) =>
        for child_id in obj.child_ids {
          stack.push(child_id)
        }
      None => ()
    }
  }
}

///|
fn railway_box_cross_start(
  box : @graph.Box,
  direction : @engine_api.Direction,
) -> Double {
  match direction {
    Down | Up => box.x
    Right | Left => box.y
  }
}

///|
fn railway_box_cross_end(
  box : @graph.Box,
  direction : @engine_api.Direction,
) -> Double {
  match direction {
    Down | Up => box.x + box.width
    Right | Left => box.y + box.height
  }
}

///|
fn railway_box_main_start(
  box : @graph.Box,
  direction : @engine_api.Direction,
) -> Double {
  match direction {
    Down | Up => box.y
    Right | Left => box.x
  }
}

///|
fn railway_box_main_end(
  box : @graph.Box,
  direction : @engine_api.Direction,
) -> Double {
  match direction {
    Down | Up => box.y + box.height
    Right | Left => box.x + box.width
  }
}

///|
fn railway_subtree_envelope(
  root_id : String,
  node_boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  direction : @engine_api.Direction,
) -> RailwaySubtreeEnvelope? {
  match subtree_union_box_railway(root_id, node_boxes, object_by_id) {
    Some(box) =>
      Some({
        id: root_id,
        cross_start: railway_box_cross_start(box, direction),
        cross_end: railway_box_cross_end(box, direction),
        main_start: railway_box_main_start(box, direction),
        main_end: railway_box_main_end(box, direction),
      })
    None => None
  }
}

///|
fn railway_subtree_envelopes_overlap_on_main(
  a : RailwaySubtreeEnvelope,
  b : RailwaySubtreeEnvelope,
) -> Bool {
  !(a.main_end <= b.main_start || b.main_end <= a.main_start)
}

///|
fn spread_sibling_subtrees_once_railway(
  sibling_ids : Array[String],
  node_boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  direction : @engine_api.Direction,
  gap : Double,
) -> Bool {
  let envelopes : Array[RailwaySubtreeEnvelope] = []
  for sibling_id in sibling_ids {
    match
      railway_subtree_envelope(sibling_id, node_boxes, object_by_id, direction) {
      Some(envelope) => envelopes.push(envelope)
      None => ()
    }
  }
  if envelopes.length() <= 1 {
    return false
  }
  envelopes.sort_by(fn(a, b) {
    if a.cross_start < b.cross_start {
      -1
    } else if a.cross_start > b.cross_start {
      1
    } else {
      a.id.compare(b.id)
    }
  })
  let mut changed = false
  for i in 1..<envelopes.length() {
    let current = envelopes[i]
    let mut target_cross_start = current.cross_start
    for j in 0..<i {
      let previous = envelopes[j]
      if !railway_subtree_envelopes_overlap_on_main(current, previous) {
        continue
      }
      let candidate = previous.cross_end + gap
      if candidate > target_cross_start {
        target_cross_start = candidate
      }
    }
    if current.cross_start >= target_cross_start {
      continue
    }
    let delta = target_cross_start - current.cross_start
    match direction {
      Down | Up =>
        shift_subtree_railway(current.id, delta, 0.0, node_boxes, object_by_id)
      Right | Left =>
        shift_subtree_railway(current.id, 0.0, delta, node_boxes, object_by_id)
    }
    envelopes[i] = {
      ..current,
      cross_start: target_cross_start,
      cross_end: current.cross_end + delta,
    }
    changed = true
  }
  changed
}

///|
fn spread_sibling_boxes_railway(
  node_boxes : Map[String, @graph.Box],
  graph : @graph.GraphInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Unit {
  let root_key = "__railway_root__"
  let children_by_parent : Map[String, Array[String]] = {}
  for obj in graph.objects {
    let parent_id = parent_id_by_child_id.get_or_default(obj.id, root_key)
    match children_by_parent.get(parent_id) {
      Some(arr) => arr.push(obj.id)
      None => children_by_parent[parent_id] = [obj.id]
    }
  }
  for entry in parent_id_by_child_id {
    let child_id = entry.0
    let parent_id = entry.1
    match children_by_parent.get(parent_id) {
      Some(arr) => if !arr.contains(child_id) { arr.push(child_id) }
      None => ()
    }
  }
  let gap = @cmp.maximum(12.0, config.edge_padding)
  let parent_ids : Array[String] = []
  for entry in children_by_parent {
    parent_ids.push(entry.0)
  }
  parent_ids.sort_by(fn(a, b) {
    if a == root_key && b != root_key {
      -1
    } else if a != root_key && b == root_key {
      1
    } else {
      a.compare(b)
    }
  })
  for _ in 0..<8 {
    let mut changed = false
    for parent_id in parent_ids {
      let parent_children = match children_by_parent.get(parent_id) {
        Some(v) => v
        None => continue
      }
      let root_only_containers = parent_id == root_key
      let sibling_ids : Array[String] = []
      for child_id in parent_children {
        if !node_boxes.contains(child_id) {
          continue
        }
        match object_by_id.get(child_id) {
          Some(obj) =>
            if obj.shape_type != @graph.Class &&
              obj.shape_type != @graph.SqlTable &&
              (!root_only_containers || is_layout_container_candidate(obj)) {
              sibling_ids.push(child_id)
            }
          None => if !root_only_containers { sibling_ids.push(child_id) }
        }
      }
      if sibling_ids.length() <= 1 {
        continue
      }
      let parent_is_container = if parent_id == root_key {
        false
      } else {
        match object_by_id.get(parent_id) {
          Some(parent_obj) => is_layout_container_candidate(parent_obj)
          None => false
        }
      }
      let mut has_container_sibling = false
      for sibling_id in sibling_ids {
        match object_by_id.get(sibling_id) {
          Some(sibling_obj) =>
            if is_layout_container_candidate(sibling_obj) {
              has_container_sibling = true
              break
            }
          None => ()
        }
      }
      if !parent_is_container && !has_container_sibling {
        continue
      }
      if spread_sibling_subtrees_once_railway(
          sibling_ids, node_boxes, object_by_id, direction, gap,
        ) {
        changed = true
      }
    }
    if !changed {
      break
    }
  }
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
