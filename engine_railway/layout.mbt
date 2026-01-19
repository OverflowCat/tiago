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
  let (boxes, level_heights) = place_nodes(graph, config, direction, levels)
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
      level_heights,
    )
  }
  patch
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
  boxes : Map[String, @graph.Box],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  level_heights : Array[Double],
) -> Array[@graph.Point] raise @engine_api.LayoutError {
  ignore(edge_index)
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
  let src_box = match boxes.get(src_id) {
    Some(b) => b
    None => raise Unsupported("missing box for node: \{src_id}")
  }
  let dst_box = match boxes.get(dst_id) {
    Some(b) => b
    None => raise Unsupported("missing box for node: \{dst_id}")
  }
  let start = exit_of_box(src_box, flow)
  let end = entry_of_box(dst_box, flow)
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
        config.edge_padding
      let start_on_rail = @graph.Point::new(rail_x, start.y)
      // Leave the rail just below the destination, then enter vertically so the
      // arrowhead direction is correct.
      let last_rail = rails[rails.length() - 1]
      push_if_new(waypoints, start_on_rail)
      push_if_new(waypoints, @graph.Point::new(rail_x, last_rail))
      push_if_new(waypoints, point_on_rail(end, last_rail, flow))
      push_if_new(waypoints, end)
      return waypoints
    }
    (Up, Down) => {
      let rail_x = global_backward_rail_anchor(boxes, level_heights.length()) +
        config.edge_padding
      let start_on_rail = @graph.Point::new(rail_x, start.y)
      let last_rail = rails[rails.length() - 1]
      push_if_new(waypoints, start_on_rail)
      push_if_new(waypoints, @graph.Point::new(rail_x, last_rail))
      push_if_new(waypoints, point_on_rail(end, last_rail, flow))
      push_if_new(waypoints, end)
      return waypoints
    }
    _ => ()
  }
  if span == 1 {
    let rail = rails[0]
    let points = waypoints_between(start, end, rail, flow)
    waypoints.append(points)
    push_if_new(waypoints, end)
    return waypoints
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
  waypoints
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
  ignore(direction) // TODO: take direction into consideration
  let boxes = Map::new()
  let level_heights = []
  let object_by_id : Map[String, @graph.ObjectInput] = Map::new(
    capacity=graph.objects.length() * 2,
  )
  for obj in graph.objects {
    object_by_id[obj.id] = obj
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
    let label = forward_virtual_node_label(i)
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
    let label = backward_virtual_node_label(i)
    boxes[label] = box
    level_heights.push(level_height)
    layer_offset += level_height
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
    None => (config.default_width, config.default_height)
  }
}
