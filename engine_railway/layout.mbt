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
  let plan = els_tarjan_plan(graph)
  let (self_loop, reversed_set) = dag_edge_index_sets(plan)
  let n = graph.objects.length()
  let id_to_idx : Map[String, Int] = Map::new(capacity=n * 2)
  for i in 0..<n {
    id_to_idx.set(graph.objects[i].id, i)
  }
  let depths = compute_depths(
    n, graph, id_to_idx, plan, self_loop, reversed_set,
  )
  let levels = make_levels(graph, depths)
  let boxes = place_nodes(graph, config, direction, levels)
  for obj in graph.objects {
    match boxes.get(obj.id) {
      Some(b) => patch.nodes[obj.id] = b
      None => ()
    }
  }
  for edge in graph.edges {
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
    patch.edges[edge.index] = route_edge(
      edge.index,
      edge.src_id,
      edge.dst_id,
      du,
      dv,
      boxes,
      direction,
      config,
    )
  }
  patch
}

///|
fn route_edge(
  edge_index : Int,
  src_id : String,
  dst_id : String,
  src_level : Int,
  dst_level : Int,
  boxes : Map[String, @graph.Box],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Array[@graph.Point] raise @engine_api.LayoutError {
  if dst_level - src_level < 1 {
    raise Unsupported(
      "route_edge: dst_level is \{dst_level}, src_level is \{src_level}",
    )
  }
  let waypoints = []
  let src_box = boxes[src_id]
  let dst_box = boxes[dst_id]
  let exit_of_src = exit_of_box(src_box, direction)
  let entry_of_dst = entry_of_box(dst_box, direction)
  waypoints.push(exit_of_src)

  // temp
  let mid = @graph.Point::new(
    (exit_of_src.x + entry_of_dst.x) / 2,
    (exit_of_src.y + entry_of_dst.y) / 2,
  )
  waypoints.push(mid)
  // virtual nodes as waypoints

  waypoints.push(entry_of_dst)
  waypoints
}

///|
fn waypoints_between(
  src : @graph.Point,
  dst : @graph.Point,
  rail : Double,
  direction : @engine_api.Direction,
) -> Array[@graph.Point] {
  ignore(direction) // TODO: 
  [@graph.Point::new(src.x, rail), @graph.Point::new(dst.x, rail)]
}

///|
fn entry_of_box(
  box : @graph.Box,
  direction : @engine_api.Direction,
) -> @graph.Point {
  ignore(direction) // TODO: 
  @graph.Point::new(box.x + box.width / 2, box.y)
}

///|
fn exit_of_box(
  box : @graph.Box,
  direction : @engine_api.Direction,
) -> @graph.Point {
  ignore(direction) // TODO: 
  @graph.Point::new(box.x + box.width / 2, box.y + box.height)
}

///|
fn place_nodes(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
  levels : Array[Level],
) -> Map[String, @graph.Box] {
  ignore(direction) // TODO: take direction into consideration
  let boxes = Map::new()
  let objects = graph.objects
  let mut layer_offset = 0.0
  for i, level in levels {
    let level_objects = objects.filter(obj => level.contains(obj.id))
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
    let level_height = max_object_height + config.vertical_spacing
    let level_width = level_length.to_double() *
      (max_object_width + config.horizontal_spacing)
    let mut node_offset = 0.0

    // put the downward virtual node 
    let box = @graph.Box::new(
      node_offset + max_object_width / 2,
      layer_offset + max_object_height / 2,
      0,
      0,
    )
    let label = "level-\{i}-forward-virtual"
    boxes[label] = box
    node_offset += max_object_width + config.horizontal_spacing

    // put physical nodes
    for obj in level_objects {
      let (w, h) = object_size(obj, config)
      let box = @graph.Box::new(
        node_offset + max_object_width / 2 - w / 2,
        layer_offset + max_object_height / 2 - h / 2,
        w,
        h,
      )
      let label = obj.id
      boxes[label] = box
      node_offset += max_object_width + config.horizontal_spacing
    }

    // put the upward virtual node
    let box = @graph.Box::new(
      node_offset + max_object_width / 2,
      layer_offset + max_object_height / 2,
      0,
      0,
    )
    let label = "level-\{i}-backward-virtual"
    boxes[label] = box
    layer_offset += level_height
  }
  boxes
}

///|
fn self_loop_route(
  b : @graph.Box,
  direction : @engine_api.Direction,
  edge_padding : Double,
) -> Array[@graph.Point] {
  ignore(direction) // TODO: 
  [] // TODO: 
}

///|
fn object_size(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
) -> (Double, Double) {
  match obj.box {
    Some(b) => (b.width, b.height)
    None => (config.default_width, config.default_height)
  }
}
