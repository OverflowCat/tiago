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
  let (src_ports, dst_ports) = assign_ports(
    graph, id_to_idx, depths, self_loop, direction, config, boxes,
  )
  let rail_tracks = assign_rail_tracks(
    graph, id_to_idx, depths, self_loop, direction,
  )
  let rail_shifts = assign_gap_lane_offsets(
    graph, id_to_idx, depths, self_loop, direction, config, boxes, src_ports, dst_ports,
  )
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
  patch
}

///|
priv struct PortItem {
  edge_index : Int
  other_axis : Double
} derive(Eq, Show)

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
    let other_for_src = entry_of_box(dst_box, flow)
    let other_for_dst = exit_of_box(src_box, flow)
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
      other_axis: port_axis(other_for_src, flow),
    }
    let dst_item = {
      edge_index: e.index,
      other_axis: port_axis(other_for_dst, flow),
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
  fn assign_group(
    items : Array[PortItem],
    is_source : Bool,
    node_id : String,
    flow : @engine_api.Direction,
  ) -> Unit raise @engine_api.LayoutError {
    let ordered = items.copy()
    ordered.sort_by(fn(a, b) {
      if a.other_axis < b.other_axis {
        -1
      } else if a.other_axis > b.other_axis {
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
    for i in 0..<k {
      let t = (i + 1).to_double() / (k + 1).to_double()
      let ei = ordered[i].edge_index
      let p = if is_source {
        exit_of_box_at(box, flow, t, config)
      } else {
        entry_of_box_at(box, flow, t, config)
      }
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
} derive(Eq, Show)

///|
priv struct TrackUsage {
  end : Int
  track : Int
} derive(Eq, Show)

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
} derive(Eq, Show)

///|
priv struct LaneUsage {
  end : Double
  lane : Int
} derive(Eq, Show)

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
  boxes : Map[String, @graph.Box],
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
      return waypoints
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
      return waypoints
    }
    _ => ()
  }
  if span == 1 {
    let rail = rails[0] + rail_shift
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
