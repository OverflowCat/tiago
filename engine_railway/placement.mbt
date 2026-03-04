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
fn place_nodes(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
  object_by_id : Map[String, @graph.ObjectInput],
) -> RailwayNodeLayout raise @engine_api.LayoutError {
  place_nodes_dagre(graph, config, direction, object_by_id)
}

///|
fn place_nodes_dagre(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
  object_by_id : Map[String, @graph.ObjectInput],
) -> RailwayNodeLayout raise @engine_api.LayoutError {
  let dagre_graph = @moon_dagre.new_graph(multigraph=true, compound=true)
  dagre_graph.set_graph(
    make_railway_dagre_graph_attrs(config, graph, direction),
  )

  let dagre_node_id_by_object_id : Map[String, String] = {}
  let node_size_by_id : Map[String, (Double, Double)] = {}
  for i, obj in graph.objects {
    let dagre_id = railway_dagre_node_id(i)
    dagre_node_id_by_object_id[obj.id] = dagre_id
    let (width, height) = object_size_with_objects(obj, config, object_by_id)
    node_size_by_id[obj.id] = (width, height)
    let node_attrs = @moon_dagre.empty_attrs()
    node_attrs.set_float("width", width)
    node_attrs.set_float("height", height)
    dagre_graph.set_node(dagre_id, label=node_attrs)
  }

  for parent in graph.objects {
    let parent_dagre_id = match dagre_node_id_by_object_id.get(parent.id) {
      Some(id) => id
      None => continue
    }
    for child_id in parent.child_ids {
      if child_id == parent.id {
        continue
      }
      match dagre_node_id_by_object_id.get(child_id) {
        Some(child_dagre_id) =>
          dagre_graph.set_parent(child_dagre_id, parent=parent_dagre_id)
        None => ()
      }
    }
  }

  for edge in graph.edges {
    let src_dagre_id = match dagre_node_id_by_object_id.get(edge.src_id) {
      Some(id) => id
      None => continue
    }
    let dst_dagre_id = match dagre_node_id_by_object_id.get(edge.dst_id) {
      Some(id) => id
      None => continue
    }
    let (layout_src, layout_dst) = if edge.src_arrow && !edge.dst_arrow {
      (dst_dagre_id, src_dagre_id)
    } else {
      (src_dagre_id, dst_dagre_id)
    }
    let edge_attrs = make_railway_dagre_edge_attrs(edge)
    dagre_graph.set_edge(
      layout_src,
      layout_dst,
      label=@moon_dagre.attrs_value(edge_attrs),
      name=edge.index.to_string(),
    )
  }

  let laid_out = @moon_dagre.layout(dagre_graph)
  let boxes : Map[String, @graph.Box] = {}
  for obj in graph.objects {
    let dagre_id = match dagre_node_id_by_object_id.get(obj.id) {
      Some(id) => id
      None => raise Unsupported("missing dagre node id for node: \{obj.id}")
    }
    let attrs = match laid_out.node_opt(dagre_id) {
      Some(node_attrs) => node_attrs
      None => raise Unsupported("missing dagre attrs for node: \{obj.id}")
    }
    let (fallback_width, fallback_height) = node_size_by_id.get_or_default(
      obj.id,
      (
        railway_clamp_positive(config.default_width, 100.0),
        railway_clamp_positive(config.default_height, 60.0),
      ),
    )
    match railway_box_from_dagre_node(attrs, fallback_width, fallback_height) {
      Some(box) => boxes[obj.id] = box
      None => raise Unsupported("missing dagre position for node: \{obj.id}")
    }
  }
  let rank_by_id = rank_by_layout_constraints(
    graph, boxes, direction, config, dagre_node_id_by_object_id, laid_out,
  )
  let levels = levels_from_rank_and_order(
    graph, rank_by_id, dagre_node_id_by_object_id, laid_out,
  )
  repack_levels_left_to_right(
    graph, boxes, levels, object_by_id, direction, config,
  )
  let (level_main_mins, level_main_maxs, level_cross_mins, level_cross_maxs) = level_bounds_from_boxes(
    graph, boxes, levels, direction, config,
  )
  let level_heights = build_level_heights_from_bounds(
    level_main_mins, level_main_maxs, direction, config,
  )
  place_virtual_nodes_for_levels(
    boxes, levels, level_main_mins, level_main_maxs, level_cross_mins, level_cross_maxs,
    direction, config,
  )
  { boxes, level_heights, rank_by_id }
}

///|
fn repack_levels_left_to_right(
  graph : @graph.GraphInput,
  boxes : Map[String, @graph.Box],
  levels : Array[Level],
  object_by_id : Map[String, @graph.ObjectInput],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Unit {
  if direction != @engine_api.Down {
    return
  }
  let anchor_candidates : Array[Double] = []
  for level in levels {
    match min_physical_cross_in_level(level, boxes, object_by_id, direction) {
      Some(cross) => anchor_candidates.push(cross)
      None => ()
    }
  }
  if anchor_candidates.is_empty() {
    return
  }
  let mut anchor = anchor_candidates[0]
  for cross in anchor_candidates {
    anchor = @cmp.minimum(anchor, cross)
  }

  let degree_by_id : Map[String, Int] = {}
  for edge in graph.edges {
    degree_by_id[edge.src_id] = degree_by_id.get_or_default(edge.src_id, 0) + 1
    degree_by_id[edge.dst_id] = degree_by_id.get_or_default(edge.dst_id, 0) + 1
  }

  for level in levels {
    let physical_ids : Array[String] = []
    for id in level {
      match object_by_id.get(id) {
        Some(obj) =>
          if !is_layout_container_candidate(obj) {
            physical_ids.push(id)
          }
        None => if boxes.contains(id) { physical_ids.push(id) }
      }
    }
    if physical_ids.is_empty() {
      continue
    }
    let mut cursor = anchor
    for id in physical_ids {
      match boxes.get(id) {
        Some(box) => {
          boxes[id] = @graph.Box::new(cursor, box.y, box.width, box.height)
          let degree = degree_by_id.get_or_default(id, 0)
          let congestion_bonus = @cmp.minimum(48.0, degree.to_double() * 6.0)
          cursor += box.width + config.horizontal_spacing + congestion_bonus
        }
        None => ()
      }
    }
  }
}

///|
fn min_physical_cross_in_level(
  level : Level,
  boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  direction : @engine_api.Direction,
) -> Double? {
  let mut found = false
  let mut cross_min = 0.0
  for id in level {
    match object_by_id.get(id) {
      Some(obj) => if is_layout_container_candidate(obj) { continue }
      None => ()
    }
    match boxes.get(id) {
      Some(box) => {
        let cross = match direction {
          Down | Up => box.x
          Right | Left => box.y
        }
        if !found {
          cross_min = cross
          found = true
        } else {
          cross_min = @cmp.minimum(cross_min, cross)
        }
      }
      None => ()
    }
  }
  if found {
    Some(cross_min)
  } else {
    None
  }
}

///|
priv struct AxisSample {
  id : String
  key : Double
}

///|
priv struct OrderCandidate {
  id : String
  barycenter : Double
  parent_id : String
  original_pos : Int
}

///|
fn rank_by_layout_constraints(
  graph : @graph.GraphInput,
  boxes : Map[String, @graph.Box],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  dagre_node_id_by_object_id : Map[String, String],
  laid_out : @moon_dagre.Graph,
) -> Map[String, Int] {
  let rank_by_id : Map[String, Int] = {}
  let physical_axis : Array[AxisSample] = []
  let raw_rank_by_id : Map[String, Int] = {}
  for obj in graph.objects {
    if is_layout_container_candidate(obj) {
      continue
    }
    let box = match boxes.get(obj.id) {
      Some(b) => b
      None => continue
    }
    physical_axis.push({ id: obj.id, key: major_axis_key(box, direction) })
  }
  let rank_cluster_threshold = @cmp.maximum(
    12.0,
    major_axis_spacing(direction, config) * 0.45,
  )
  let fallback_rank_by_id = rank_by_axis_clustering(
    physical_axis, rank_cluster_threshold,
  )

  for obj in graph.objects {
    if is_layout_container_candidate(obj) {
      continue
    }
    let dagre_rank = match dagre_node_id_by_object_id.get(obj.id) {
      Some(dagre_id) =>
        match laid_out.node_opt(dagre_id) {
          Some(attrs) => attrs.get_int("rank")
          None => None
        }
      None => None
    }
    match dagre_rank {
      Some(r) => raw_rank_by_id[obj.id] = r
      None =>
        raw_rank_by_id[obj.id] = fallback_rank_by_id.get_or_default(obj.id, 0)
    }
  }

  let dense_rank_by_id = densify_rank_map(raw_rank_by_id)
  for entry in dense_rank_by_id {
    rank_by_id[entry.0] = entry.1
  }

  let ranked_axis : Array[(Double, Int)] = []
  for sample in physical_axis {
    ranked_axis.push((sample.key, rank_by_id.get_or_default(sample.id, 0)))
  }

  for obj in graph.objects {
    if !is_layout_container_candidate(obj) {
      continue
    }
    let child_ranks : Array[Int] = []
    for child_id in obj.child_ids {
      if rank_by_id.contains(child_id) {
        child_ranks.push(rank_by_id.get_or_default(child_id, 0))
      }
    }
    if !child_ranks.is_empty() {
      let mut min_rank = child_ranks[0]
      for r in child_ranks {
        if r < min_rank {
          min_rank = r
        }
      }
      rank_by_id[obj.id] = min_rank
    } else {
      let key = match boxes.get(obj.id) {
        Some(b) => major_axis_key(b, direction)
        None => 0.0
      }
      rank_by_id[obj.id] = nearest_rank_by_axis(key, ranked_axis)
    }
  }
  rank_by_id
}

///|
fn rank_by_axis_clustering(
  samples : Array[AxisSample],
  threshold : Double,
) -> Map[String, Int] {
  let rank_by_id : Map[String, Int] = {}
  if samples.is_empty() {
    return rank_by_id
  }
  let sorted = samples.copy()
  sorted.sort_by(fn(a, b) {
    if a.key < b.key {
      -1
    } else if a.key > b.key {
      1
    } else {
      a.id.compare(b.id)
    }
  })
  let mut cluster_idx = 0
  let mut cluster_center = sorted[0].key
  let mut cluster_size = 0.0
  for sample in sorted {
    if cluster_size > 0.0 && (sample.key - cluster_center).abs() > threshold {
      cluster_idx = cluster_idx + 1
      cluster_center = sample.key
      cluster_size = 0.0
    }
    rank_by_id[sample.id] = cluster_idx
    cluster_size = cluster_size + 1.0
    cluster_center = cluster_center +
      (sample.key - cluster_center) / cluster_size
  }
  rank_by_id
}

///|
fn densify_rank_map(rank_by_id : Map[String, Int]) -> Map[String, Int] {
  let dense : Map[String, Int] = {}
  if rank_by_id.is_empty() {
    return dense
  }
  let unique_ranks : Array[Int] = []
  for entry in rank_by_id {
    let r = entry.1
    let mut found = false
    for v in unique_ranks {
      if v == r {
        found = true
        break
      }
    }
    if !found {
      unique_ranks.push(r)
    }
  }
  unique_ranks.sort()
  let dense_by_raw : Map[Int, Int] = {}
  for i, raw in unique_ranks {
    dense_by_raw[raw] = i
  }
  for entry in rank_by_id {
    dense[entry.0] = dense_by_raw.get_or_default(entry.1, 0)
  }
  dense
}

///|
fn nearest_rank_by_axis(
  key : Double,
  ranked_axis : Array[(Double, Int)],
) -> Int {
  if ranked_axis.is_empty() {
    return 0
  }
  let mut best_rank = ranked_axis[0].1
  let mut best_dist = (key - ranked_axis[0].0).abs()
  for i in 1..<ranked_axis.length() {
    let d = (key - ranked_axis[i].0).abs()
    if d < best_dist {
      best_dist = d
      best_rank = ranked_axis[i].1
    }
  }
  best_rank
}

///|
fn build_parent_id_by_child_id(
  graph : @graph.GraphInput,
) -> Map[String, String] {
  let parent_id_by_child_id : Map[String, String] = {}
  for child_id in graph.root.child_ids {
    parent_id_by_child_id[child_id] = graph.root.id
  }
  for obj in graph.objects {
    for child_id in obj.child_ids {
      parent_id_by_child_id[child_id] = obj.id
    }
  }
  parent_id_by_child_id
}

///|
fn barycenter_toward_adjacent_rank(
  graph : @graph.GraphInput,
  node_id : String,
  adjacent_rank : Int,
  rank_by_id : Map[String, Int],
  position_by_id : Map[String, Int],
) -> Double? {
  let neighbors : Array[Int] = []
  for edge in graph.edges {
    if edge.src_id == node_id {
      if rank_by_id.get_or_default(edge.dst_id, -1000000) == adjacent_rank {
        neighbors.push(position_by_id.get_or_default(edge.dst_id, 0))
      }
    } else if edge.dst_id == node_id {
      if rank_by_id.get_or_default(edge.src_id, -1000000) == adjacent_rank {
        neighbors.push(position_by_id.get_or_default(edge.src_id, 0))
      }
    }
  }
  if neighbors.is_empty() {
    None
  } else {
    let mut s = 0.0
    for p in neighbors {
      s = s + p.to_double()
    }
    Some(s / neighbors.length().to_double())
  }
}

///|
fn optimize_levels_by_barycenter(
  graph : @graph.GraphInput,
  rank_by_id : Map[String, Int],
  levels : Array[Level],
  order_by_id : Map[String, Int],
) -> Unit {
  let parent_id_by_child_id = build_parent_id_by_child_id(graph)
  if levels.length() <= 2 {
    return
  }
  fn rebuild_positions(levels : Array[Level]) -> Map[String, Int] {
    let pos : Map[String, Int] = {}
    for level in levels {
      for i, id in level {
        pos[id] = i
      }
    }
    pos
  }

  let sweep_iters = 6
  for _ in 0..<sweep_iters {
    let pos_down = rebuild_positions(levels)
    for rank in 1..<levels.length() {
      let level = levels[rank]
      let candidates : Array[OrderCandidate] = []
      for i, id in level {
        let bary = match
          barycenter_toward_adjacent_rank(
            graph,
            id,
            rank - 1,
            rank_by_id,
            pos_down,
          ) {
          Some(v) => v
          None =>
            i.to_double() +
            order_by_id.get_or_default(id, 0).to_double() * 0.001
        }
        let parent_id = parent_id_by_child_id.get_or_default(id, id)
        candidates.push({ id, barycenter: bary, parent_id, original_pos: i })
      }
      candidates.sort_by(fn(a, b) {
        if a.barycenter < b.barycenter {
          -1
        } else if a.barycenter > b.barycenter {
          1
        } else if a.parent_id != b.parent_id {
          a.parent_id.compare(b.parent_id)
        } else if a.original_pos != b.original_pos {
          a.original_pos - b.original_pos
        } else {
          a.id.compare(b.id)
        }
      })
      let sorted : Array[String] = []
      for c in candidates {
        sorted.push(c.id)
      }
      levels[rank] = sorted
    }

    let pos_up = rebuild_positions(levels)
    for rank = levels.length() - 2; rank >= 0; rank = rank - 1 {
      let level = levels[rank]
      let candidates : Array[OrderCandidate] = []
      for i, id in level {
        let bary = match
          barycenter_toward_adjacent_rank(
            graph,
            id,
            rank + 1,
            rank_by_id,
            pos_up,
          ) {
          Some(v) => v
          None =>
            i.to_double() +
            order_by_id.get_or_default(id, 0).to_double() * 0.001
        }
        let parent_id = parent_id_by_child_id.get_or_default(id, id)
        candidates.push({ id, barycenter: bary, parent_id, original_pos: i })
      }
      candidates.sort_by(fn(a, b) {
        if a.barycenter < b.barycenter {
          -1
        } else if a.barycenter > b.barycenter {
          1
        } else if a.parent_id != b.parent_id {
          a.parent_id.compare(b.parent_id)
        } else if a.original_pos != b.original_pos {
          a.original_pos - b.original_pos
        } else {
          a.id.compare(b.id)
        }
      })
      let sorted : Array[String] = []
      for c in candidates {
        sorted.push(c.id)
      }
      levels[rank] = sorted
    }
  }
}

///|
fn major_axis_key(
  box : @graph.Box,
  direction : @engine_api.Direction,
) -> Double {
  match direction {
    Down => box.y + box.height / 2.0
    Up => -(box.y + box.height / 2.0)
    Right => box.x + box.width / 2.0
    Left => -(box.x + box.width / 2.0)
  }
}

///|
fn levels_from_rank_and_order(
  graph : @graph.GraphInput,
  rank_by_id : Map[String, Int],
  dagre_node_id_by_object_id : Map[String, String],
  laid_out : @moon_dagre.Graph,
) -> Array[Level] {
  let mut max_rank = 0
  for entry in rank_by_id {
    if entry.1 > max_rank {
      max_rank = entry.1
    }
  }
  let levels : Array[Level] = Array::makei(max_rank + 1, _ => ([] : Level))
  let order_by_id : Map[String, Int] = {}
  for obj in graph.objects {
    let dagre_id = dagre_node_id_by_object_id.get_or_default(obj.id, "")
    let order = if dagre_id == "" {
      0
    } else {
      match laid_out.node_opt(dagre_id) {
        Some(attrs) => attrs.get_int_or("order", 0)
        None => 0
      }
    }
    order_by_id[obj.id] = order
    levels[rank_by_id.get_or_default(obj.id, 0)].push(obj.id)
  }
  for level in levels {
    level.sort_by(fn(a, b) {
      let oa = order_by_id.get_or_default(a, 0)
      let ob = order_by_id.get_or_default(b, 0)
      if oa < ob {
        -1
      } else if oa > ob {
        1
      } else {
        a.compare(b)
      }
    })
  }
  optimize_levels_by_barycenter(graph, rank_by_id, levels, order_by_id)
  levels
}

///|
fn place_virtual_nodes_for_levels(
  boxes : Map[String, @graph.Box],
  levels : Array[Level],
  level_main_mins : Array[Double],
  level_main_maxs : Array[Double],
  level_cross_mins : Array[Double],
  level_cross_maxs : Array[Double],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Unit {
  let cross_padding = match direction {
    Down | Up => @cmp.maximum(20.0, config.horizontal_spacing / 2.0)
    Right | Left => @cmp.maximum(20.0, config.vertical_spacing / 2.0)
  }
  for i in 0..<levels.length() {
    let main_center = (level_main_mins[i] + level_main_maxs[i]) / 2.0
    let forward_cross = level_cross_mins[i] - cross_padding
    let backward_cross = level_cross_maxs[i] + cross_padding
    match direction {
      Down | Up => {
        boxes[forward_virtual_node_label(i)] = @graph.Box::new(
          forward_cross, main_center, 0.0, 0.0,
        )
        boxes[backward_virtual_node_label(i)] = @graph.Box::new(
          backward_cross, main_center, 0.0, 0.0,
        )
      }
      Right | Left => {
        boxes[forward_virtual_node_label(i)] = @graph.Box::new(
          main_center, forward_cross, 0.0, 0.0,
        )
        boxes[backward_virtual_node_label(i)] = @graph.Box::new(
          main_center, backward_cross, 0.0, 0.0,
        )
      }
    }
  }
}

///|
fn level_bounds_from_boxes(
  graph : @graph.GraphInput,
  boxes : Map[String, @graph.Box],
  levels : Array[Level],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> (Array[Double], Array[Double], Array[Double], Array[Double]) {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  let level_main_mins : Array[Double] = []
  let level_main_maxs : Array[Double] = []
  let level_cross_mins : Array[Double] = []
  let level_cross_maxs : Array[Double] = []
  let mut fallback_main_min = 0.0
  for level in levels {
    // Container boxes are fitted after node layout and can be much larger than
    // physical nodes in the same rank. Rails should be derived from physical
    // node bands, otherwise adjacent-level edges can bend below destinations.
    let physical_ids : Array[String] = []
    for id in level {
      match object_by_id.get(id) {
        Some(obj) =>
          if !is_layout_container_candidate(obj) {
            physical_ids.push(id)
          }
        None => physical_ids.push(id)
      }
    }
    let ids_for_bounds : Array[String] = []
    if physical_ids.is_empty() {
      ids_for_bounds.append(level)
    } else {
      ids_for_bounds.append(physical_ids)
    }
    let mut has = false
    let mut main_min = 0.0
    let mut main_max = 0.0
    let mut cross_min = 0.0
    let mut cross_max = 0.0
    for id in ids_for_bounds {
      match boxes.get(id) {
        Some(box) => {
          let (curr_main_min, curr_main_max, curr_cross_min, curr_cross_max) = match
            direction {
            Down | Up => (box.y, box.y + box.height, box.x, box.x + box.width)
            Right | Left =>
              (box.x, box.x + box.width, box.y, box.y + box.height)
          }
          if !has {
            main_min = curr_main_min
            main_max = curr_main_max
            cross_min = curr_cross_min
            cross_max = curr_cross_max
            has = true
          } else {
            main_min = @cmp.minimum(main_min, curr_main_min)
            main_max = @cmp.maximum(main_max, curr_main_max)
            cross_min = @cmp.minimum(cross_min, curr_cross_min)
            cross_max = @cmp.maximum(cross_max, curr_cross_max)
          }
        }
        None => ()
      }
    }
    if !has {
      let fallback_main_size = match direction {
        Down | Up => railway_clamp_positive(config.default_height, 60.0)
        Right | Left => railway_clamp_positive(config.default_width, 100.0)
      }
      let fallback_cross_size = match direction {
        Down | Up => railway_clamp_positive(config.default_width, 100.0)
        Right | Left => railway_clamp_positive(config.default_height, 60.0)
      }
      main_min = fallback_main_min
      main_max = fallback_main_min + fallback_main_size
      cross_min = 0.0
      cross_max = fallback_cross_size
    }
    level_main_mins.push(main_min)
    level_main_maxs.push(main_max)
    level_cross_mins.push(cross_min)
    level_cross_maxs.push(cross_max)
    fallback_main_min = main_max + major_axis_spacing(direction, config)
  }
  (level_main_mins, level_main_maxs, level_cross_mins, level_cross_maxs)
}

///|
fn build_level_heights_from_bounds(
  level_main_mins : Array[Double],
  level_main_maxs : Array[Double],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Array[Double] {
  let level_heights : Array[Double] = []
  let main_spacing = major_axis_spacing(direction, config)
  let level_count = level_main_mins.length()
  if level_count == 0 {
    return level_heights
  }
  if level_count == 1 {
    let only_height = level_main_maxs[0] - level_main_mins[0] + main_spacing
    level_heights.push(@cmp.maximum(1.0, only_height))
    return level_heights
  }
  let mut prefix = 0.0
  for i in 0..<(level_count - 1) {
    let rail = (level_main_maxs[i] + level_main_mins[i + 1]) / 2.0
    let thickness = rail + main_spacing / 2.0 - prefix
    let clamped = @cmp.maximum(1.0, thickness)
    level_heights.push(clamped)
    prefix = prefix + clamped
  }
  let last_span = level_main_maxs[level_count - 1] -
    level_main_mins[level_count - 1]
  level_heights.push(@cmp.maximum(1.0, last_span + main_spacing))
  level_heights
}

///|
fn make_railway_dagre_graph_attrs(
  config : @engine_api.LayoutConfig,
  graph : @graph.GraphInput,
  direction : @engine_api.Direction,
) -> @moon_dagre.Attrs {
  let attrs = @moon_dagre.empty_attrs()
  attrs.set_string("rankdir", railway_rankdir_from_direction(direction))
  attrs.set_float("nodesep", railway_nodesep(config.horizontal_spacing))
  attrs.set_float("ranksep", railway_ranksep(graph, direction))
  attrs.set_float("edgesep", railway_clamp_positive(config.edge_padding, 20.0))
  attrs.set_float("marginx", 0.0)
  attrs.set_float("marginy", 0.0)
  attrs
}

///|
fn make_railway_dagre_edge_attrs(edge : @graph.EdgeInput) -> @moon_dagre.Attrs {
  let attrs = @moon_dagre.empty_attrs()
  attrs.set_string("labelpos", "c")
  attrs.set_float(
    "weight",
    railway_clamp_positive(edge.reference_count.to_double(), 1.0),
  )
  match edge_label_size(edge) {
    Some((width, height)) => {
      attrs.set_float("width", width)
      attrs.set_float("height", height)
    }
    None => ()
  }
  attrs
}

///|
fn railway_rankdir_from_direction(direction : @engine_api.Direction) -> String {
  match direction {
    Down => "tb"
    Right => "lr"
    Up => "bt"
    Left => "rl"
  }
}

///|
fn railway_nodesep(value : Double) -> Double {
  let base = railway_clamp_positive(value, 60.0)
  if base < 60.0 {
    60.0
  } else {
    base
  }
}

///|
fn railway_ranksep(
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
  if base < 80.0 {
    80.0
  } else {
    base
  }
}

///|
fn railway_box_from_dagre_node(
  attrs : @moon_dagre.Attrs,
  fallback_width : Double,
  fallback_height : Double,
) -> @graph.Box? {
  guard attrs.get_float("x") is Some(x) && attrs.get_float("y") is Some(y) else {
    return None
  }
  let raw_width = railway_clamp_positive(
    attrs.get_float_or("width", fallback_width),
    fallback_width,
  )
  let raw_height = railway_clamp_positive(
    attrs.get_float_or("height", fallback_height),
    fallback_height,
  )
  let width = raw_width.ceil()
  let height = raw_height.ceil()
  let left = railway_round_double(x - raw_width / 2.0)
  let top = railway_round_double(y - raw_height / 2.0)
  Some(@graph.Box::new(left, top, width, height))
}

///|
fn railway_round_double(v : Double) -> Double {
  if v >= 0.0 {
    (v + 0.5).to_int().to_double()
  } else {
    (v - 0.5).to_int().to_double()
  }
}

///|
fn railway_dagre_node_id(order : Int) -> String {
  order.to_string()
}

///|
fn railway_clamp_positive(value : Double, fallback : Double) -> Double {
  if value <= 0.0 {
    fallback
  } else {
    value
  }
}

///|
fn place_nodes_grid(
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
        let (w, h) = object_size_with_objects(obj, config, object_by_id)
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
      let (w, h) = object_size_with_objects(obj, config, object_by_id)
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
