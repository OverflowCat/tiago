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
  let node_layout = place_nodes(layout_input, config, direction)
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
  fit_container_boxes_in_map_railway(
    boxes, graph, object_by_id, parent_id_by_child_id, container_padding,
  )
  let (src_ports, dst_ports) = assign_ports(
    layout_input, id_to_idx, depths, self_loop, direction, config, boxes,
  )
  let rail_tracks = assign_rail_tracks(
    layout_input, id_to_idx, depths, self_loop, direction, src_ports, dst_ports,
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
fn keep_legacy_railway_symbols_alive() -> Unit {
  ignore(relax_layout_nodes_against_containers)
  ignore(spread_sibling_boxes_railway)
  ignore(place_nodes_grid)
  ignore(global_backward_rail_anchor)
  ignore(railway_readability_metrics)
  ignore(compute_depths)
  ignore(make_levels)
}
