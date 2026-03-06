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
  keep_legacy_railway_symbols_alive()
  if graph.root.shape_type == @graph.SequenceDiagram {
    return layout_sequence_diagram_railway(graph, config)
  }
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
  ignore(reversed_set)
  let node_layout = place_nodes(layout_input, config, direction, object_by_id)
  let boxes = node_layout.boxes
  let level_heights = node_layout.level_heights
  let depths = rank_array_for_layout(
    layout_input,
    id_to_idx,
    node_layout.rank_by_id,
  )
  let container_padding = @cmp.maximum(
    RAILWAY_CONTAINER_PADDING,
    config.edge_padding,
  )
  let mut has_layout_container = false
  for obj in graph.objects {
    if is_layout_container_candidate(obj) {
      has_layout_container = true
      break
    }
  }
  stabilize_container_layout_railway(
    boxes,
    graph,
    object_by_id,
    parent_id_by_child_id,
    node_layout.rank_by_id,
    direction,
    config,
    container_padding,
    has_layout_container,
  )
  let (src_ports, dst_ports) = assign_ports(
    layout_input, id_to_idx, depths, self_loop, direction, config, boxes,
  )
  let rail_tracks = assign_rail_tracks(
    layout_input, id_to_idx, depths, self_loop, direction, src_ports, dst_ports,
  )
  let lane_plan = plan_gap_lanes(
    layout_input, id_to_idx, depths, self_loop, direction, config, src_ports, dst_ports,
  )
  for obj in layout_input.objects {
    match boxes.get(obj.id) {
      Some(b) => patch.nodes[obj.id] = b
      None => ()
    }
  }
  fit_container_boxes_railway(
    patch, graph, object_by_id, parent_id_by_child_id, config,
  )
  sync_boxes_from_patch_railway(boxes, patch)
  route_edges_railway(
    patch,
    layout_input,
    self_loop,
    id_to_idx,
    depths,
    rail_tracks,
    lane_plan.shift_by_edge,
    src_ports,
    dst_ports,
    boxes,
    object_by_id,
    parent_id_by_child_id,
    direction,
    config,
    level_heights,
    [],
  )
  recompute_container_label_boxes_railway(patch, graph)
  let reserved_label_boxes = collect_reserved_container_label_boxes_railway(
    patch, graph,
  )
  route_edges_railway(
    patch,
    layout_input,
    self_loop,
    id_to_idx,
    depths,
    rail_tracks,
    lane_plan.shift_by_edge,
    src_ports,
    dst_ports,
    boxes,
    object_by_id,
    parent_id_by_child_id,
    direction,
    config,
    level_heights,
    reserved_label_boxes,
  )
  recompute_container_label_boxes_railway(patch, graph)
  let final_reserved_label_boxes = collect_reserved_container_label_boxes_railway(
    patch, graph,
  )
  route_edges_railway(
    patch,
    layout_input,
    self_loop,
    id_to_idx,
    depths,
    rail_tracks,
    lane_plan.shift_by_edge,
    src_ports,
    dst_ports,
    boxes,
    object_by_id,
    parent_id_by_child_id,
    direction,
    config,
    level_heights,
    final_reserved_label_boxes,
  )
  recompute_edge_label_boxes(
    patch,
    graph,
    direction,
    config,
    lane_plan.lane_by_edge,
  )
  patch
}

///|
fn clone_boxes_railway(
  boxes : Map[String, @graph.Box],
) -> Map[String, @graph.Box] {
  let cloned : Map[String, @graph.Box] = {}
  for entry in boxes {
    cloned[entry.0] = entry.1
  }
  cloned
}

///|
fn box_changed_railway(a : @graph.Box, b : @graph.Box) -> Bool {
  let tol = 1.0e-6
  (a.x - b.x).abs() > tol ||
  (a.y - b.y).abs() > tol ||
  (a.width - b.width).abs() > tol ||
  (a.height - b.height).abs() > tol
}

///|
fn boxes_changed_railway(
  before : Map[String, @graph.Box],
  after : Map[String, @graph.Box],
) -> Bool {
  if before.length() != after.length() {
    return true
  }
  for entry in before {
    match after.get(entry.0) {
      Some(other) => if box_changed_railway(entry.1, other) { return true }
      None => return true
    }
  }
  false
}

///|
fn stabilize_container_layout_railway(
  boxes : Map[String, @graph.Box],
  graph : @graph.GraphInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  rank_by_id : Map[String, Int],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  container_padding : Double,
  has_layout_container : Bool,
) -> Unit {
  let levels = if has_layout_container {
    levels_from_rank_only_railway(graph, rank_by_id)
  } else {
    []
  }
  for _ in 0..<6 {
    let before = clone_boxes_railway(boxes)
    fit_container_boxes_in_map_railway(
      boxes, graph, object_by_id, parent_id_by_child_id, container_padding,
    )
    // NOTE: container relaxation can over-shift sibling nodes in nested
    // container graphs and produce very wide layouts. Keep it disabled until
    // constraints are made hierarchy-aware.
    // relax_layout_nodes_against_containers(
    //   boxes, graph, parent_id_by_child_id, direction, config,
    // )
    if has_layout_container {
      spread_sibling_boxes_railway(
        boxes, graph, object_by_id, parent_id_by_child_id, direction, config,
      )
      repack_levels_left_to_right(
        graph, boxes, levels, object_by_id, direction, config,
      )
    }
    fit_container_boxes_in_map_railway(
      boxes, graph, object_by_id, parent_id_by_child_id, container_padding,
    )
    if has_layout_container {
      spread_sibling_boxes_railway(
        boxes, graph, object_by_id, parent_id_by_child_id, direction, config,
      )
      fit_container_boxes_in_map_railway(
        boxes, graph, object_by_id, parent_id_by_child_id, container_padding,
      )
    }
    if !boxes_changed_railway(before, boxes) {
      break
    }
  }
}

///|
fn levels_from_rank_only_railway(
  graph : @graph.GraphInput,
  rank_by_id : Map[String, Int],
) -> Array[Level] {
  let mut max_rank = 0
  for entry in rank_by_id {
    if entry.1 > max_rank {
      max_rank = entry.1
    }
  }
  let levels : Array[Level] = Array::makei(max_rank + 1, _ => ([] : Level))
  for obj in graph.objects {
    levels[rank_by_id.get_or_default(obj.id, 0)].push(obj.id)
  }
  levels
}

///|
fn route_edges_railway(
  patch : @graph.LayoutPatch,
  layout_input : @graph.GraphInput,
  self_loop : @hashset.HashSet[Int],
  id_to_idx : Map[String, Int],
  depths : Array[Int],
  rail_tracks : Map[Int, Int],
  shift_by_edge : Map[Int, Double],
  src_ports : Map[Int, @graph.Point],
  dst_ports : Map[Int, @graph.Point],
  boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  level_heights : Array[Double],
  reserved_label_boxes : Array[@graph.Box],
) -> Unit raise @engine_api.LayoutError {
  let gap_rail_reservations = Ref::new({})
  let ordered_edges = layout_input.edges.copy()
  ordered_edges.sort_by(fn(a, b) {
    let a_self = self_loop.contains(a.index)
    let b_self = self_loop.contains(b.index)
    let a_priority = if a_self {
      3
    } else {
      let su = id_to_idx.get_or_default(a.src_id, -1)
      let sv = id_to_idx.get_or_default(a.dst_id, -1)
      if su < 0 || sv < 0 {
        3
      } else {
        let span = Int::abs(depths[sv] - depths[su])
        if span > 1 {
          0
        } else if span == 1 {
          1
        } else {
          2
        }
      }
    }
    let b_priority = if b_self {
      3
    } else {
      let su = id_to_idx.get_or_default(b.src_id, -1)
      let sv = id_to_idx.get_or_default(b.dst_id, -1)
      if su < 0 || sv < 0 {
        3
      } else {
        let span = Int::abs(depths[sv] - depths[su])
        if span > 1 {
          0
        } else if span == 1 {
          1
        } else {
          2
        }
      }
    }
    if a_priority != b_priority {
      a_priority - b_priority
    } else {
      let a_span = if a_self {
        0
      } else {
        let su = id_to_idx.get_or_default(a.src_id, -1)
        let sv = id_to_idx.get_or_default(a.dst_id, -1)
        if su < 0 || sv < 0 {
          0
        } else {
          Int::abs(depths[sv] - depths[su])
        }
      }
      let b_span = if b_self {
        0
      } else {
        let su = id_to_idx.get_or_default(b.src_id, -1)
        let sv = id_to_idx.get_or_default(b.dst_id, -1)
        if su < 0 || sv < 0 {
          0
        } else {
          Int::abs(depths[sv] - depths[su])
        }
      }
      if a_span != b_span {
        b_span - a_span
      } else {
        a.index - b.index
      }
    }
  })
  for edge in ordered_edges {
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
    if du == dv {
      let src_box = match boxes.get(edge.src_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{edge.src_id}")
      }
      let dst_box = match boxes.get(edge.dst_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{edge.dst_id}")
      }
      patch.edges[edge.index] = same_rank_route(
        src_box, dst_box, direction, config,
      )
      continue
    }
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
      shift_by_edge.get(edge.index).unwrap_or(0.0),
      start,
      end,
      boxes,
      object_by_id,
      parent_id_by_child_id,
      direction,
      config,
      level_heights,
      reserved_label_boxes,
      gap_rail_reservations,
    )
  }
}

///|
fn collect_reserved_container_label_boxes_railway(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Array[@graph.Box] {
  let reserved : Array[@graph.Box] = []
  for obj in graph.objects {
    if !is_layout_container_candidate(obj) {
      continue
    }
    match patch.node_labels.get(obj.id) {
      Some(label_box) => reserved.push(label_box)
      None => ()
    }
  }
  reserved
}

///|
fn sync_boxes_from_patch_railway(
  boxes : Map[String, @graph.Box],
  patch : @graph.LayoutPatch,
) -> Unit {
  for entry in patch.nodes {
    boxes[entry.0] = entry.1
  }
}

///|
fn keep_legacy_railway_symbols_alive() -> Unit {
  ignore(object_size)
  ignore(relax_layout_nodes_against_containers)
  ignore(spread_sibling_boxes_railway)
  ignore(place_nodes_grid)
  ignore(global_backward_rail_anchor)
  ignore(railway_readability_metrics)
  ignore(compute_depths)
  ignore(make_levels)
}
