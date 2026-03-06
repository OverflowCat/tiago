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
priv struct PortItem {
  edge_index : Int
  desired_axis : Double
}

///|
priv struct ReciprocalPortEntry {
  edge_index : Int
  sign : Int
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

  fn choose_single_port_axis(
    box : @graph.Box,
    flow : @engine_api.Direction,
  ) -> Double {
    let m = port_margin(box, flow, config)
    let (lo0, hi0) = axis_min_max(box, flow)
    let lo = lo0 + m
    let hi = hi0 - m
    if hi <= lo + 1.0e-6 {
      return (lo + hi) / 2.0
    }
    let center = (lo + hi) / 2.0
    let span = hi - lo
    let base_abs_offset = @cmp.maximum(8.0, config.edge_padding * 0.7)
    let offset = @cmp.minimum(
      base_abs_offset,
      @cmp.maximum(0.0, span / 2.0 - 1.0),
    )
    if offset <= 1.0e-6 {
      return center
    }
    // Use a stable left/top-biased port for single-edge sides.
    let axis = lo + offset
    @cmp.maximum(lo, @cmp.minimum(axis, hi))
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
      let axis = choose_single_port_axis(box, flow)
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
    let sep = @cmp.minimum(max_sep, @cmp.maximum(base_sep, ideal_sep))
    let base_abs_offset = @cmp.maximum(8.0, config.edge_padding * 0.7)
    let max_start = hi - sep * (k - 1).to_double()
    let start = @cmp.maximum(lo, @cmp.minimum(lo + base_abs_offset, max_start))
    let pos : Array[Double] = Array::make(k, 0.0)
    for i in 0..<k {
      let axis = start + i.to_double() * sep
      pos[i] = @cmp.maximum(lo, @cmp.minimum(axis, hi))
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

  // If both endpoints own only one port on this flow side, align them on a
  // shared axis so short edges stay visually straight.
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
    let src_key = "s:\{e.src_id}:\{flow}"
    let dst_key = "t:\{e.dst_id}:\{flow}"
    let src_count = match src_groups.get(src_key) {
      Some(items) => items.length()
      None => 0
    }
    let dst_count = match dst_groups.get(dst_key) {
      Some(items) => items.length()
      None => 0
    }
    if src_count != 1 || dst_count != 1 {
      continue
    }
    let src_box = match boxes.get(e.src_id) {
      Some(b) => b
      None => raise Unsupported("missing box for node: \{e.src_id}")
    }
    let dst_box = match boxes.get(e.dst_id) {
      Some(b) => b
      None => raise Unsupported("missing box for node: \{e.dst_id}")
    }
    let src_port = match src_ports.get(e.index) {
      Some(p) => p
      None => continue
    }
    let dst_port = match dst_ports.get(e.index) {
      Some(p) => p
      None => continue
    }
    let src_margin = port_margin(src_box, flow, config)
    let dst_margin = port_margin(dst_box, flow, config)
    let (src_lo0, src_hi0) = axis_min_max(src_box, flow)
    let (dst_lo0, dst_hi0) = axis_min_max(dst_box, flow)
    let lo = @cmp.maximum(src_lo0 + src_margin, dst_lo0 + dst_margin)
    let hi = @cmp.minimum(src_hi0 - src_margin, dst_hi0 - dst_margin)
    if hi <= lo + 1.0e-6 {
      continue
    }
    let shared0 = @cmp.minimum(
      port_axis(src_port, flow),
      port_axis(dst_port, flow),
    )
    let shared = @cmp.maximum(lo, @cmp.minimum(shared0, hi))
    src_ports[e.index] = port_point_on_axis(src_box, flow, true, shared)
    dst_ports[e.index] = port_point_on_axis(dst_box, flow, false, shared)
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
      let other_box = match boxes.get(e.dst_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{e.dst_id}")
      }
      ignore(other_box)
      let axis = choose_single_port_axis(b, flow)
      src_ports[e.index] = port_point_on_axis(b, flow, true, axis)
    }
    if !dst_ports.contains(e.index) {
      let b = match boxes.get(e.dst_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{e.dst_id}")
      }
      let other_box = match boxes.get(e.src_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{e.src_id}")
      }
      ignore(other_box)
      let axis = choose_single_port_axis(b, flow)
      dst_ports[e.index] = port_point_on_axis(b, flow, false, axis)
    }
  }

  apply_reciprocal_port_offsets(
    graph, id_to_idx, depths, self_loop, direction, config, boxes, src_ports, dst_ports,
  )

  (src_ports, dst_ports)
}

///|
fn unordered_pair_key(a : String, b : String) -> String {
  if a < b {
    "\{a}|\{b}"
  } else {
    "\{b}|\{a}"
  }
}

///|
fn clamp_port_axis_by_direction(
  p : @graph.Point,
  box : @graph.Box,
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> @graph.Point {
  let m = match direction {
    Down | Up => port_margin(box, Down, config)
    Right | Left => port_margin(box, Right, config)
  }
  match direction {
    Down | Up => {
      let lo = box.x + m
      let hi = box.x + box.width - m
      let x = @cmp.maximum(lo, @cmp.minimum(p.x, hi))
      @graph.Point::new(x, p.y)
    }
    Right | Left => {
      let lo = box.y + m
      let hi = box.y + box.height - m
      let y = @cmp.maximum(lo, @cmp.minimum(p.y, hi))
      @graph.Point::new(p.x, y)
    }
  }
}

///|
fn apply_reciprocal_port_offsets(
  graph : @graph.GraphInput,
  id_to_idx : Map[String, Int],
  depths : Array[Int],
  self_loop : @hashset.HashSet[Int],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  boxes : Map[String, @graph.Box],
  src_ports : Map[Int, @graph.Point],
  dst_ports : Map[Int, @graph.Point],
) -> Unit raise @engine_api.LayoutError {
  let entries_by_pair : Map[String, Array[ReciprocalPortEntry]] = {}
  let edge_by_index : Map[Int, @graph.EdgeInput] = {}
  for edge in graph.edges {
    edge_by_index[edge.index] = edge
    if self_loop.contains(edge.index) || edge.src_id == edge.dst_id {
      continue
    }
    let su = require_index(id_to_idx, edge.src_id)
    let sv = require_index(id_to_idx, edge.dst_id)
    let src_level = depths[su]
    let dst_level = depths[sv]
    let span = Int::abs(dst_level - src_level)
    if span != 1 {
      continue
    }
    let flow = edge_flow_direction(direction, src_level, dst_level)
    let sign = if flow == direction { -1 } else { 1 }
    let key = unordered_pair_key(edge.src_id, edge.dst_id)
    let entry = { edge_index: edge.index, sign }
    match entries_by_pair.get(key) {
      Some(arr) => arr.push(entry)
      None => entries_by_pair[key] = [entry]
    }
  }

  let base_offset = @cmp.maximum(12.0, config.edge_padding / 2.0)
  for pair_entry in entries_by_pair {
    let entries = pair_entry.1
    if entries.length() <= 1 {
      continue
    }
    let neg : Array[ReciprocalPortEntry] = []
    let pos : Array[ReciprocalPortEntry] = []
    for entry in entries {
      if entry.sign < 0 {
        neg.push(entry)
      } else {
        pos.push(entry)
      }
    }
    if neg.is_empty() || pos.is_empty() {
      continue
    }
    neg.sort_by(fn(a, b) { a.edge_index - b.edge_index })
    pos.sort_by(fn(a, b) { a.edge_index - b.edge_index })
    fn apply_group(
      group : Array[ReciprocalPortEntry],
      sign : Int,
    ) -> Unit raise @engine_api.LayoutError {
      let local_center = (group.length() - 1).to_double() / 2.0
      for i, entry in group {
        let lane_offset = (i.to_double() - local_center) * (base_offset / 2.0)
        let delta = sign.to_double() * (base_offset + lane_offset)
        match edge_by_index.get(entry.edge_index) {
          Some(edge) => {
            let src_box = match boxes.get(edge.src_id) {
              Some(v) => v
              None => raise Unsupported("missing box for node: \{edge.src_id}")
            }
            let dst_box = match boxes.get(edge.dst_id) {
              Some(v) => v
              None => raise Unsupported("missing box for node: \{edge.dst_id}")
            }
            let src_shifted = match src_ports.get(edge.index) {
              Some(p) =>
                match direction {
                  Down | Up =>
                    clamp_port_axis_by_direction(
                      @graph.Point::new(p.x + delta, p.y),
                      src_box,
                      direction,
                      config,
                    )
                  Right | Left =>
                    clamp_port_axis_by_direction(
                      @graph.Point::new(p.x, p.y + delta),
                      src_box,
                      direction,
                      config,
                    )
                }
              None => continue
            }
            let dst_shifted = match dst_ports.get(edge.index) {
              Some(p) =>
                match direction {
                  Down | Up =>
                    clamp_port_axis_by_direction(
                      @graph.Point::new(p.x + delta, p.y),
                      dst_box,
                      direction,
                      config,
                    )
                  Right | Left =>
                    clamp_port_axis_by_direction(
                      @graph.Point::new(p.x, p.y + delta),
                      dst_box,
                      direction,
                      config,
                    )
                }
              None => continue
            }
            src_ports[edge.index] = src_shifted
            dst_ports[edge.index] = dst_shifted
          }
          None => ()
        }
      }
    }
    apply_group(neg, -1)
    apply_group(pos, 1)
  }
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
fn major_axis_spacing(
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Double {
  match direction {
    Down | Up => config.vertical_spacing
    Right | Left => config.horizontal_spacing
  }
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
  label_major_span : Double
}

///|
pub struct RailwayLanePlan {
  lane_by_edge : Map[Int, Int]
  shift_by_edge : Map[Int, Double]
}

///|
priv struct GapLaneEdge {
  edge_index : Int
  src_axis : Double
  dst_axis : Double
  span_start : Double
  span_end : Double
  label_major_span : Double
  flow : @engine_api.Direction
}

///|
priv struct LaneOrderScore {
  crossings : Int
  displacement : Int
}

///|
priv struct SyntheticSegment {
  a : @graph.Point
  b : @graph.Point
  vertical : Bool
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
fn edge_label_major_span(
  edge : @graph.EdgeInput,
  direction : @engine_api.Direction,
) -> Double {
  match edge_label_size(edge) {
    Some((width, height)) =>
      match direction {
        Down | Up => height
        Right | Left => width
      }
    None => 0.0
  }
}

///|
fn lane_order_score_less(a : LaneOrderScore, b : LaneOrderScore) -> Bool {
  if a.crossings != b.crossings {
    a.crossings < b.crossings
  } else {
    a.displacement < b.displacement
  }
}

///|
fn identity_lane_order(lane_count : Int) -> Array[Int] {
  let order : Array[Int] = []
  for lane in 0..<lane_count {
    order.push(lane)
  }
  order
}

///|
fn lane_rank_by_lane(order : Array[Int], lane_count : Int) -> Array[Int] {
  let rank_by_lane = Array::make(lane_count, 0)
  for rank, lane in order {
    if lane >= 0 && lane < lane_count {
      rank_by_lane[lane] = rank
    }
  }
  rank_by_lane
}

///|
fn synthetic_endpoints_for_lane_edge(
  edge : GapLaneEdge,
) -> (@graph.Point, @graph.Point) {
  match edge.flow {
    Down =>
      (
        @graph.Point::new(edge.src_axis, 0.0),
        @graph.Point::new(edge.dst_axis, 2.0),
      )
    Up =>
      (
        @graph.Point::new(edge.src_axis, 2.0),
        @graph.Point::new(edge.dst_axis, 0.0),
      )
    Right =>
      (
        @graph.Point::new(0.0, edge.src_axis),
        @graph.Point::new(2.0, edge.dst_axis),
      )
    Left =>
      (
        @graph.Point::new(2.0, edge.src_axis),
        @graph.Point::new(0.0, edge.dst_axis),
      )
  }
}

///|
fn synthetic_route_for_lane_edge(
  edge : GapLaneEdge,
  lane_rank : Int,
  lane_count : Int,
) -> Array[@graph.Point] {
  let (start, end) = synthetic_endpoints_for_lane_edge(edge)
  let center = (lane_count - 1).to_double() / 2.0
  let lane_step = 0.8 / (lane_count.to_double() + 1.0)
  let rail = 1.0 + (lane_rank.to_double() - center) * lane_step
  let route : Array[@graph.Point] = [start]
  let middle = waypoints_between(start, end, rail, edge.flow)
  route.append(middle)
  push_if_new(route, end)
  route
}

///|
fn synthetic_segments(route : Array[@graph.Point]) -> Array[SyntheticSegment] {
  let segs : Array[SyntheticSegment] = []
  if route.length() < 2 {
    return segs
  }
  for i in 0..<(route.length() - 1) {
    let a = route[i]
    let b = route[i + 1]
    let dx = b.x - a.x
    let dy = b.y - a.y
    if dx.abs() <= 1.0e-6 && dy.abs() <= 1.0e-6 {
      continue
    }
    if dx.abs() <= 1.0e-6 {
      segs.push({ a, b, vertical: true })
    } else if dy.abs() <= 1.0e-6 {
      segs.push({ a, b, vertical: false })
    }
  }
  segs
}

///|
fn between_open(v : Double, a : Double, b : Double) -> Bool {
  let lo = @cmp.minimum(a, b)
  let hi = @cmp.maximum(a, b)
  v > lo + 1.0e-6 && v < hi - 1.0e-6
}

///|
fn segment_crosses(sa : SyntheticSegment, sb : SyntheticSegment) -> Bool {
  if sa.vertical == sb.vertical {
    return false
  }
  let vertical = if sa.vertical { sa } else { sb }
  let horizontal = if sa.vertical { sb } else { sa }
  let x = vertical.a.x
  let y = horizontal.a.y
  between_open(x, horizontal.a.x, horizontal.b.x) &&
  between_open(y, vertical.a.y, vertical.b.y)
}

///|
fn synthetic_route_crossings(
  a : Array[@graph.Point],
  b : Array[@graph.Point],
) -> Int {
  let segs_a = synthetic_segments(a)
  let segs_b = synthetic_segments(b)
  let mut crossings = 0
  for sa in segs_a {
    for sb in segs_b {
      if segment_crosses(sa, sb) {
        crossings = crossings + 1
      }
    }
  }
  crossings
}

///|
fn evaluate_lane_order(
  edges : Array[GapLaneEdge],
  base_lane_by_edge : Map[Int, Int],
  lane_count : Int,
  order : Array[Int],
) -> LaneOrderScore {
  let rank_by_lane = lane_rank_by_lane(order, lane_count)
  let route_by_edge : Map[Int, Array[@graph.Point]] = {}
  let mut displacement = 0
  for edge in edges {
    let base_lane = base_lane_by_edge.get(edge.edge_index).unwrap_or(0)
    let rank = rank_by_lane[base_lane]
    displacement = displacement + (rank - base_lane).abs()
    route_by_edge[edge.edge_index] = synthetic_route_for_lane_edge(
      edge, rank, lane_count,
    )
  }
  let mut crossings = 0
  for i in 0..<edges.length() {
    for j in (i + 1)..<edges.length() {
      let ri = route_by_edge.get(edges[i].edge_index).unwrap_or([])
      let rj = route_by_edge.get(edges[j].edge_index).unwrap_or([])
      crossings = crossings + synthetic_route_crossings(ri, rj)
    }
  }
  { crossings, displacement }
}

///|
fn optimize_lane_order_exhaustive(
  edges : Array[GapLaneEdge],
  base_lane_by_edge : Map[Int, Int],
  lane_count : Int,
) -> Array[Int] {
  let used = Array::make(lane_count, false)
  let current = Array::make(lane_count, 0)
  let best_order = identity_lane_order(lane_count)
  let best_score = evaluate_lane_order(
    edges, base_lane_by_edge, lane_count, best_order,
  )
  let has_best = false

  fn dfs(
    pos : Int,
    used : Array[Bool],
    current : Array[Int],
    lane_count : Int,
    edges : Array[GapLaneEdge],
    base_lane_by_edge : Map[Int, Int],
    best_order_ref : Ref[Array[Int]],
    best_score_ref : Ref[LaneOrderScore],
    has_best_ref : Ref[Bool],
  ) -> Unit {
    if pos == lane_count {
      let order = current.copy()
      let score = evaluate_lane_order(
        edges, base_lane_by_edge, lane_count, order,
      )
      if !has_best_ref.val || lane_order_score_less(score, best_score_ref.val) {
        best_order_ref.val = order
        best_score_ref.val = score
        has_best_ref.val = true
      }
      return
    }
    for lane in 0..<lane_count {
      if used[lane] {
        continue
      }
      used[lane] = true
      current[pos] = lane
      dfs(
        pos + 1,
        used,
        current,
        lane_count,
        edges,
        base_lane_by_edge,
        best_order_ref,
        best_score_ref,
        has_best_ref,
      )
      used[lane] = false
    }
  }

  let best_order_ref = Ref::new(best_order)
  let best_score_ref = Ref::new(best_score)
  let has_best_ref = Ref::new(has_best)
  dfs(
    0, used, current, lane_count, edges, base_lane_by_edge, best_order_ref, best_score_ref,
    has_best_ref,
  )
  best_order_ref.val
}

///|
fn optimize_lane_order_local_search(
  edges : Array[GapLaneEdge],
  base_lane_by_edge : Map[Int, Int],
  lane_count : Int,
) -> Array[Int] {
  let order = identity_lane_order(lane_count)
  let mut best_score = evaluate_lane_order(
    edges, base_lane_by_edge, lane_count, order,
  )
  let mut improved = true
  while improved {
    improved = false
    let mut best_swap = -1
    let mut swap_score = best_score
    for i in 0..<(lane_count - 1) {
      let candidate = order.copy()
      let t = candidate[i]
      candidate[i] = candidate[i + 1]
      candidate[i + 1] = t
      let score = evaluate_lane_order(
        edges, base_lane_by_edge, lane_count, candidate,
      )
      if lane_order_score_less(score, swap_score) {
        swap_score = score
        best_swap = i
      }
    }
    if best_swap >= 0 {
      let t = order[best_swap]
      order[best_swap] = order[best_swap + 1]
      order[best_swap + 1] = t
      best_score = swap_score
      improved = true
    }
  }
  order
}

///|
fn optimize_lane_order(
  edges : Array[GapLaneEdge],
  base_lane_by_edge : Map[Int, Int],
  lane_count : Int,
) -> Array[Int] {
  if lane_count <= 1 {
    return identity_lane_order(lane_count)
  }
  if lane_count <= 7 {
    optimize_lane_order_exhaustive(edges, base_lane_by_edge, lane_count)
  } else {
    optimize_lane_order_local_search(edges, base_lane_by_edge, lane_count)
  }
}

///|
fn plan_gap_lanes(
  graph : @graph.GraphInput,
  id_to_idx : Map[String, Int],
  depths : Array[Int],
  self_loop : @hashset.HashSet[Int],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  src_ports : Map[Int, @graph.Point],
  dst_ports : Map[Int, @graph.Point],
) -> RailwayLanePlan raise @engine_api.LayoutError {
  let bundles_by_gap : Map[Int, Array[GapLaneEdge]] = {}
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
    let start = match src_ports.get(e.index) {
      Some(p) => p
      None => raise Unsupported("missing src port for edge: \{e.index}")
    }
    let end = match dst_ports.get(e.index) {
      Some(p) => p
      None => raise Unsupported("missing dst port for edge: \{e.index}")
    }
    let (a0, a1, needs_rail) = match direction {
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
    let item : GapLaneEdge = {
      edge_index: e.index,
      src_axis: port_axis(start, flow),
      dst_axis: port_axis(end, flow),
      span_start: a0,
      span_end: a1,
      label_major_span: edge_label_major_span(e, direction),
      flow,
    }
    match bundles_by_gap.get(gap) {
      Some(arr) => arr.push(item)
      None => bundles_by_gap[gap] = [item]
    }
  }

  let lane_by_edge : Map[Int, Int] = {}
  let shift_by_edge : Map[Int, Double] = {}

  for entry in bundles_by_gap {
    let edges = entry.1
    let spans : Array[EdgeSpan] = []
    for edge in edges {
      spans.push({
        start: edge.span_start,
        end: edge.span_end,
        edge_index: edge.edge_index,
        label_major_span: edge.label_major_span,
      })
    }
    let (base_lane_by_edge, lane_count) = allocate_span_lanes(spans)
    if lane_count <= 1 {
      for edge in edges {
        lane_by_edge[edge.edge_index] = 0
      }
      continue
    }
    let order = optimize_lane_order(edges, base_lane_by_edge, lane_count)
    let rank_by_lane = lane_rank_by_lane(order, lane_count)
    let center = (lane_count - 1).to_double() / 2.0
    // Keep rails away from node boundaries so rounded corners don't start
    // immediately at the box exit/entry.
    let min_clear = @cmp.maximum(12.0, config.edge_padding / 2.0)
    let main_spacing = major_axis_spacing(direction, config)
    let max_offset = @cmp.maximum(0.0, main_spacing / 2.0 - min_clear)
    let mut max_label_span = 0.0
    for span in spans {
      if span.label_major_span > max_label_span {
        max_label_span = span.label_major_span
      }
    }
    // Keep adjacent label boxes from overlapping when edges run in parallel
    // through the same inter-level gap.
    let min_lane_spacing = @cmp.maximum(
      track_spacing(config),
      max_label_span + 4.0,
    )
    let mut spacing = min_lane_spacing
    if center > 0.0 && spacing * center > max_offset {
      spacing = max_offset / center
    }
    for edge in edges {
      let base_lane = base_lane_by_edge.get(edge.edge_index).unwrap_or(0)
      let lane = rank_by_lane[base_lane]
      let offset = (lane.to_double() - center) * spacing
      lane_by_edge[edge.edge_index] = lane
      shift_by_edge[edge.edge_index] = offset
    }
  }
  { lane_by_edge, shift_by_edge }
}

///|
fn assign_rail_tracks(
  graph : @graph.GraphInput,
  id_to_idx : Map[String, Int],
  depths : Array[Int],
  self_loop : @hashset.HashSet[Int],
  direction : @engine_api.Direction,
  src_ports : Map[Int, @graph.Point],
  dst_ports : Map[Int, @graph.Point],
) -> Map[Int, Int] raise @engine_api.LayoutError {
  let forward_long_left : Array[EdgeInterval] = []
  let forward_long_center : Array[EdgeInterval] = []
  let forward_long_right : Array[EdgeInterval] = []
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
      let src = match src_ports.get(e.index) {
        Some(v) => v
        None => raise Unsupported("missing src port for edge: \{e.index}")
      }
      let dst = match dst_ports.get(e.index) {
        Some(v) => v
        None => raise Unsupported("missing dst port for edge: \{e.index}")
      }
      let side = long_edge_lateral_side(direction, src, dst)
      match side {
        -1 => forward_long_left.push({ start, end, edge_index: e.index })
        1 => forward_long_right.push({ start, end, edge_index: e.index })
        _ => forward_long_center.push({ start, end, edge_index: e.index })
      }
    }
  }
  let tracks : Map[Int, Int] = {}
  for entry in allocate_interval_tracks(back_edges) {
    tracks[entry.0] = entry.1
  }
  for entry in allocate_interval_tracks(forward_long_center) {
    tracks[entry.0] = entry.1
  }
  for entry in allocate_interval_tracks(forward_long_left) {
    tracks[entry.0] = entry.1
  }
  for entry in allocate_interval_tracks(forward_long_right) {
    tracks[entry.0] = entry.1
  }
  tracks
}

///|
fn long_edge_lateral_side(
  direction : @engine_api.Direction,
  start : @graph.Point,
  end : @graph.Point,
) -> Int {
  let tol = 1.0e-6
  let delta = match direction {
    Down | Up => end.x - start.x
    Right | Left => end.y - start.y
  }
  if delta > tol {
    1
  } else if delta < -tol {
    -1
  } else {
    0
  }
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
fn edge_flow_direction_with_geometry(
  layout_direction : @engine_api.Direction,
  src_level : Int,
  dst_level : Int,
  start : @graph.Point,
  end : @graph.Point,
) -> @engine_api.Direction {
  let tol = 1.0e-6
  match layout_direction {
    Down => {
      let dy = end.y - start.y
      if dy.abs() <= tol {
        edge_flow_direction(layout_direction, src_level, dst_level)
      } else if dy > 0.0 {
        Down
      } else {
        Up
      }
    }
    Up => {
      let dy = start.y - end.y
      if dy.abs() <= tol {
        edge_flow_direction(layout_direction, src_level, dst_level)
      } else if dy > 0.0 {
        Up
      } else {
        Down
      }
    }
    Right => {
      let dx = end.x - start.x
      if dx.abs() <= tol {
        edge_flow_direction(layout_direction, src_level, dst_level)
      } else if dx > 0.0 {
        Right
      } else {
        Left
      }
    }
    Left => {
      let dx = start.x - end.x
      if dx.abs() <= tol {
        edge_flow_direction(layout_direction, src_level, dst_level)
      } else if dx > 0.0 {
        Left
      } else {
        Right
      }
    }
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
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  level_heights : Array[Double],
  reserved_label_boxes : Array[@graph.Box],
  gap_rail_reservations : Ref[Map[Int, Array[GapRailReservation]]],
) -> Array[@graph.Point] raise @engine_api.LayoutError {
  if dst_level == src_level {
    raise Unsupported(
      "route_edge: dst_level is \{dst_level}, src_level is \{src_level}",
    )
  }
  let flow = edge_flow_direction(direction, src_level, dst_level)
  let tangent_flow = edge_flow_direction_with_geometry(
    direction, src_level, dst_level, start, end,
  )
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
      calculate_rail(
        level_heights,
        rail_level,
        major_axis_spacing(direction, config),
      ),
    )
    continue next_level
  }
  let waypoints : Array[@graph.Point] = []
  let first_gap = if step == 1 { src_level } else { src_level - 1 }
  let last_gap = if step == 1 { dst_level - 1 } else { dst_level }
  let start_axis = port_axis(start, flow)
  let end_axis = port_axis(end, flow)
  fn finalize_route(points : Array[@graph.Point]) -> Array[@graph.Point] {
    enforce_flow_tangent(points, tangent_flow)
  }
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
      let gap_shift = multi_edge_gap_shift(
        flow, direction, start, end, rail_track, config,
      )
      let spacing = track_spacing(config)
      let preferred_rail_x = @cmp.maximum(start.x, end.x) +
        config.edge_padding * 2.0 +
        spacing * rail_track.to_double()
      let blocked = blocked_axis_intervals_for_edge(
        start,
        end,
        flow,
        boxes,
        object_by_id,
        src_id,
        dst_id,
        reserved_label_boxes,
        config.edge_padding,
      )
      let side_clearance = @cmp.maximum(
        config.edge_padding * 2.0,
        spacing * 2.0,
      )
      let mut lo = @cmp.minimum(start.x, end.x) - side_clearance - spacing * 2.0
      let mut hi = @cmp.maximum(start.x, end.x) + side_clearance + spacing * 4.0
      for interval in blocked {
        lo = @cmp.minimum(lo, interval.lo - side_clearance)
        hi = @cmp.maximum(hi, interval.hi + side_clearance)
      }
      let rail_x = nearest_unblocked_axis(preferred_rail_x, lo, hi, blocked)
      // Leave source along edge flow first, then shift laterally on rail.
      let preferred_last_rail = rails[rails.length() - 1] +
        rail_shift +
        gap_shift
      let last_rail = choose_span_one_reserved_rail(
        start,
        end,
        preferred_last_rail,
        flow,
        boxes,
        object_by_id,
        parent_id_by_child_id,
        src_id,
        dst_id,
        reserved_label_boxes,
        config.edge_padding,
        config,
        gap_rail_reservations,
        last_gap,
        @cmp.minimum(@cmp.minimum(start_axis, end_axis), rail_x),
        @cmp.maximum(@cmp.maximum(start_axis, end_axis), rail_x),
      )
      push_if_new(waypoints, point_on_rail(start, last_rail, flow))
      push_if_new(waypoints, anchor_on_rail(rail_x, last_rail, flow))
      push_if_new(waypoints, point_on_rail(end, last_rail, flow))
      push_if_new(waypoints, end)
      return finalize_route(waypoints)
    }
    (Up, Down) => {
      let gap_shift = multi_edge_gap_shift(
        flow, direction, start, end, rail_track, config,
      )
      let spacing = track_spacing(config)
      let preferred_rail_x = @cmp.maximum(start.x, end.x) +
        config.edge_padding * 2.0 +
        spacing * rail_track.to_double()
      let blocked = blocked_axis_intervals_for_edge(
        start,
        end,
        flow,
        boxes,
        object_by_id,
        src_id,
        dst_id,
        reserved_label_boxes,
        config.edge_padding,
      )
      let side_clearance = @cmp.maximum(
        config.edge_padding * 2.0,
        spacing * 2.0,
      )
      let mut lo = @cmp.minimum(start.x, end.x) - side_clearance - spacing * 2.0
      let mut hi = @cmp.maximum(start.x, end.x) + side_clearance + spacing * 4.0
      for interval in blocked {
        lo = @cmp.minimum(lo, interval.lo - side_clearance)
        hi = @cmp.maximum(hi, interval.hi + side_clearance)
      }
      let rail_x = nearest_unblocked_axis(preferred_rail_x, lo, hi, blocked)
      let preferred_last_rail = rails[rails.length() - 1] +
        rail_shift +
        gap_shift
      let last_rail = choose_span_one_reserved_rail(
        start,
        end,
        preferred_last_rail,
        flow,
        boxes,
        object_by_id,
        parent_id_by_child_id,
        src_id,
        dst_id,
        reserved_label_boxes,
        config.edge_padding,
        config,
        gap_rail_reservations,
        last_gap,
        @cmp.minimum(@cmp.minimum(start_axis, end_axis), rail_x),
        @cmp.maximum(@cmp.maximum(start_axis, end_axis), rail_x),
      )
      push_if_new(waypoints, point_on_rail(start, last_rail, flow))
      push_if_new(waypoints, anchor_on_rail(rail_x, last_rail, flow))
      push_if_new(waypoints, point_on_rail(end, last_rail, flow))
      push_if_new(waypoints, end)
      return finalize_route(waypoints)
    }
    _ => ()
  }
  if span == 1 {
    let blocked_axes = if (start_axis - end_axis).abs() <= 1.0e-6 {
      blocked_axis_intervals_for_edge(
        start,
        end,
        flow,
        boxes,
        object_by_id,
        src_id,
        dst_id,
        reserved_label_boxes,
        config.edge_padding,
      )
    } else {
      []
    }
    let preferred_rail = rails[0] +
      rail_shift +
      span_one_edge_seed_shift(edge_index, config)
    let rail = choose_span_one_reserved_rail(
      start,
      end,
      preferred_rail,
      flow,
      boxes,
      object_by_id,
      parent_id_by_child_id,
      src_id,
      dst_id,
      reserved_label_boxes,
      config.edge_padding,
      config,
      gap_rail_reservations,
      first_gap,
      @cmp.minimum(start_axis, end_axis),
      @cmp.maximum(start_axis, end_axis),
    )
    let direct_axis_blocked = (start_axis - end_axis).abs() <= 1.0e-6 &&
      axis_blocked_by_intervals(start_axis, blocked_axes)
    if direct_axis_blocked {
      let blocked_rails = blocked_span_one_rail_intervals(
        start,
        end,
        flow,
        boxes,
        object_by_id,
        parent_id_by_child_id,
        src_id,
        dst_id,
        reserved_label_boxes,
        config.edge_padding,
      )
      let anchor = span_one_local_channel_anchor(
        start_axis,
        rail_track,
        config,
        blocked_axes,
      )
      let shoulder_major = span_one_detour_shoulder_major(
        start,
        flow,
        blocked_rails,
        config.edge_padding,
      )
      let points = waypoints_between_via_anchor(
        end, rail, anchor, flow, shoulder_major,
      )
      waypoints.append(points)
    } else {
      let points = waypoints_between(start, end, rail, flow)
      waypoints.append(points)
    }
    push_if_new(waypoints, end)
    return finalize_route(waypoints)
  }
  // Long edge: route through an edge-local channel anchor instead of a global
  // virtual-node anchor. This keeps long edges compact and avoids sweeping
  // detours that hurt readability on deep graphs.
  let anchor = long_edge_channel_anchor(
    start, end, flow, direction, rail_track, config, boxes, object_by_id, src_id,
    dst_id, reserved_label_boxes,
  )

  let gap_shift = 0.0
  let adjusted_rails = rails.copy()
  if adjusted_rails.length() > 0 {
    for i in 0..<adjusted_rails.length() {
      adjusted_rails[i] = adjusted_rails[i] + rail_shift + gap_shift
    }
    adjusted_rails[0] = choose_gap_rail_for_edge(
      start,
      end,
      adjusted_rails[0],
      flow,
      boxes,
      object_by_id,
      parent_id_by_child_id,
      src_id,
      dst_id,
      reserved_label_boxes,
      config.edge_padding,
      major_axis_spacing(direction, config),
      config,
      gap_rail_reservations,
      first_gap,
      @cmp.minimum(start_axis, anchor),
      @cmp.maximum(start_axis, anchor),
    )
    let last = adjusted_rails.length() - 1
    adjusted_rails[last] = choose_gap_rail_for_edge(
      start,
      end,
      adjusted_rails[last],
      flow,
      boxes,
      object_by_id,
      parent_id_by_child_id,
      src_id,
      dst_id,
      reserved_label_boxes,
      config.edge_padding,
      major_axis_spacing(direction, config),
      config,
      gap_rail_reservations,
      last_gap,
      @cmp.minimum(end_axis, anchor),
      @cmp.maximum(end_axis, anchor),
    )
  }

  // Go from src exit to the first rail.
  let first_rail = adjusted_rails[0]
  push_if_new(waypoints, point_on_rail(start, first_rail, flow))
  // Move onto the chosen rail anchor.
  push_if_new(waypoints, anchor_on_rail(anchor, first_rail, flow))
  // Traverse intermediate rails while staying on the same anchor.
  for i in 1..<adjusted_rails.length() {
    push_if_new(waypoints, anchor_on_rail(anchor, adjusted_rails[i], flow))
  }
  // Leave the anchor on the last rail and enter the destination.
  let last_rail = adjusted_rails[adjusted_rails.length() - 1]
  push_if_new(waypoints, point_on_rail(end, last_rail, flow))
  push_if_new(waypoints, end)
  finalize_route(waypoints)
}

///|
priv struct AxisInterval {
  lo : Double
  hi : Double
}

///|
priv struct GapRailReservation {
  span_lo : Double
  span_hi : Double
  rail : Double
}

///|
fn long_edge_channel_anchor(
  start : @graph.Point,
  end : @graph.Point,
  flow : @engine_api.Direction,
  direction : @engine_api.Direction,
  rail_track : Int,
  config : @engine_api.LayoutConfig,
  boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  src_id : String,
  dst_id : String,
  reserved_label_boxes : Array[@graph.Box],
) -> Double {
  let (src_axis, dst_axis) = match flow {
    Down | Up => (start.x, end.x)
    Right | Left => (start.y, end.y)
  }
  let spacing = track_spacing(config)
  let center_axis = (src_axis + dst_axis) / 2.0
  let lateral = dst_axis - src_axis
  let side_tol = spacing * 0.35
  let side_clearance = @cmp.maximum(config.edge_padding * 1.8, spacing * 2.0)
  let preferred = if lateral.abs() <= side_tol {
    center_axis + zigzag_track_offset(rail_track, spacing)
  } else if lateral > 0.0 {
    @cmp.maximum(src_axis, dst_axis) +
    side_clearance +
    rail_track.to_double() * spacing
  } else {
    @cmp.minimum(src_axis, dst_axis) -
    side_clearance -
    rail_track.to_double() * spacing
  }
  let side_left = @cmp.minimum(src_axis, dst_axis) -
    side_clearance -
    rail_track.to_double() * spacing
  let side_right = @cmp.maximum(src_axis, dst_axis) +
    side_clearance +
    rail_track.to_double() * spacing
  let center_zigzag = center_axis + zigzag_track_offset(rail_track, spacing)
  let blocked = blocked_axis_intervals_for_edge(
    start,
    end,
    flow,
    boxes,
    object_by_id,
    src_id,
    dst_id,
    reserved_label_boxes,
    config.edge_padding,
  )
  let margin = major_axis_spacing(direction, config) * 1.6 + spacing * 4.0
  let mut lo = @cmp.minimum(src_axis, dst_axis) - margin
  let mut hi = @cmp.maximum(src_axis, dst_axis) + margin
  for interval in blocked {
    lo = @cmp.minimum(lo, interval.lo - side_clearance)
    hi = @cmp.maximum(hi, interval.hi + side_clearance)
  }
  let candidates = [
    preferred, center_axis, center_zigzag, side_left, side_right,
  ]
  let mut best_axis = nearest_unblocked_axis(candidates[0], lo, hi, blocked)
  let mut best_cost = 0.0
  let mut has_best = false
  let band_lo = @cmp.minimum(src_axis, dst_axis) - spacing * 0.75
  let band_hi = @cmp.maximum(src_axis, dst_axis) + spacing * 0.75
  for candidate in candidates {
    let axis = nearest_unblocked_axis(candidate, lo, hi, blocked)
    let mut cost = 0.0
    cost = cost + (axis - center_axis).abs() * 0.9
    cost = cost + (axis - preferred).abs() * 0.45
    cost = cost + (axis - src_axis).abs() * 0.15
    cost = cost + (axis - dst_axis).abs() * 0.15
    if axis < band_lo || axis > band_hi {
      cost = cost + spacing * 2.0
    }
    if !has_best || cost < best_cost {
      has_best = true
      best_axis = axis
      best_cost = cost
    }
  }
  best_axis
}

///|
fn span_one_local_channel_anchor(
  direct_axis : Double,
  rail_track : Int,
  config : @engine_api.LayoutConfig,
  blocked : Array[AxisInterval],
) -> Double {
  let spacing = track_spacing(config)
  let preferred = direct_axis + zigzag_track_offset(rail_track, spacing)
  let margin = @cmp.maximum(config.edge_padding * 1.5, spacing * 4.0)
  let mut lo = preferred - margin
  let mut hi = preferred + margin
  for interval in blocked {
    if preferred >= interval.lo - 1.0e-6 && preferred <= interval.hi + 1.0e-6 {
      lo = @cmp.minimum(lo, interval.lo - margin)
      hi = @cmp.maximum(hi, interval.hi + margin)
    }
  }
  nearest_unblocked_axis(preferred, lo, hi, blocked)
}

///|
fn blocked_axis_intervals_for_edge(
  start : @graph.Point,
  end : @graph.Point,
  flow : @engine_api.Direction,
  boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  src_id : String,
  dst_id : String,
  reserved_label_boxes : Array[@graph.Box],
  padding : Double,
) -> Array[AxisInterval] {
  let blocked = long_edge_obstacle_intervals(
    start, end, flow, boxes, object_by_id, src_id, dst_id, padding,
  )
  let reserved = reserved_label_obstacle_intervals(
    start, end, flow, reserved_label_boxes, padding,
  )
  for interval in reserved {
    blocked.push(interval)
  }
  merge_axis_intervals(blocked)
}

///|
fn choose_span_one_reserved_rail(
  start : @graph.Point,
  end : @graph.Point,
  preferred_rail : Double,
  flow : @engine_api.Direction,
  boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  src_id : String,
  dst_id : String,
  reserved_label_boxes : Array[@graph.Box],
  padding : Double,
  config : @engine_api.LayoutConfig,
  gap_rail_reservations : Ref[Map[Int, Array[GapRailReservation]]],
  gap_index : Int,
  span_lo : Double,
  span_hi : Double,
) -> Double {
  let blocked = blocked_span_one_rail_intervals(
    start, end, flow, boxes, object_by_id, parent_id_by_child_id, src_id, dst_id,
    reserved_label_boxes, padding,
  )
  let gap = @cmp.maximum(4.0, padding * 0.25)
  let (major_lo, major_hi) = match flow {
    Down | Up => (@cmp.minimum(start.y, end.y), @cmp.maximum(start.y, end.y))
    Right | Left => (@cmp.minimum(start.x, end.x), @cmp.maximum(start.x, end.x))
  }
  let lo = major_lo + gap
  let hi = major_hi - gap
  if hi <= lo {
    return preferred_rail
  }
  reserve_gap_rail(
    preferred_rail, lo, hi, blocked, gap_rail_reservations, gap_index, span_lo, span_hi,
    flow, config,
  )
}

///|
fn choose_gap_rail_for_edge(
  start : @graph.Point,
  end : @graph.Point,
  preferred_rail : Double,
  flow : @engine_api.Direction,
  boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  src_id : String,
  dst_id : String,
  reserved_label_boxes : Array[@graph.Box],
  padding : Double,
  gap_span : Double,
  config : @engine_api.LayoutConfig,
  gap_rail_reservations : Ref[Map[Int, Array[GapRailReservation]]],
  gap_index : Int,
  span_lo : Double,
  span_hi : Double,
) -> Double {
  let blocked = blocked_span_one_rail_intervals(
    start, end, flow, boxes, object_by_id, parent_id_by_child_id, src_id, dst_id,
    reserved_label_boxes, padding,
  )
  let gap = @cmp.maximum(4.0, padding * 0.25)
  let lo = preferred_rail - gap_span / 2.0 + gap
  let hi = preferred_rail + gap_span / 2.0 - gap
  if hi <= lo {
    return preferred_rail
  }
  reserve_gap_rail(
    preferred_rail, lo, hi, blocked, gap_rail_reservations, gap_index, span_lo, span_hi,
    flow, config,
  )
}

///|
fn blocked_span_one_rail_intervals(
  start : @graph.Point,
  end : @graph.Point,
  flow : @engine_api.Direction,
  boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  src_id : String,
  dst_id : String,
  reserved_label_boxes : Array[@graph.Box],
  padding : Double,
) -> Array[AxisInterval] {
  let blocked = span_one_reserved_rail_intervals(
    start, end, flow, reserved_label_boxes, padding,
  )
  let crossed_container_interiors = span_one_crossed_container_interior_intervals(
    start, end, flow, boxes, object_by_id, parent_id_by_child_id, src_id, dst_id,
    padding,
  )
  for interval in crossed_container_interiors {
    blocked.push(interval)
  }
  let border_intervals = span_one_container_border_proximity_intervals(
    start, end, flow, boxes, object_by_id, padding,
  )
  for interval in border_intervals {
    blocked.push(interval)
  }
  merge_axis_intervals(blocked)
}

///|
fn span_one_reserved_rail_intervals(
  start : @graph.Point,
  end : @graph.Point,
  flow : @engine_api.Direction,
  reserved_label_boxes : Array[@graph.Box],
  padding : Double,
) -> Array[AxisInterval] {
  let intervals : Array[AxisInterval] = []
  let lateral_clearance = @cmp.maximum(4.0, padding * 0.4)
  let rail_clearance = @cmp.maximum(6.0, padding * 0.7)
  let (span_lo, span_hi) = match flow {
    Down | Up =>
      (
        @cmp.minimum(start.x, end.x) - lateral_clearance,
        @cmp.maximum(start.x, end.x) + lateral_clearance,
      )
    Right | Left =>
      (
        @cmp.minimum(start.y, end.y) - lateral_clearance,
        @cmp.maximum(start.y, end.y) + lateral_clearance,
      )
  }
  for box in reserved_label_boxes {
    let intersects_lateral = match flow {
      Down | Up => !(box.x + box.width <= span_lo || span_hi <= box.x)
      Right | Left => !(box.y + box.height <= span_lo || span_hi <= box.y)
    }
    if !intersects_lateral {
      continue
    }
    let (axis_lo0, axis_hi0) = match flow {
      Down | Up => (box.y, box.y + box.height)
      Right | Left => (box.x, box.x + box.width)
    }
    let axis_lo = axis_lo0 - rail_clearance
    let axis_hi = axis_hi0 + rail_clearance
    if axis_hi > axis_lo {
      intervals.push({ lo: axis_lo, hi: axis_hi })
    }
  }
  merge_axis_intervals(intervals)
}

///|
fn span_one_crossed_container_interior_intervals(
  start : @graph.Point,
  end : @graph.Point,
  flow : @engine_api.Direction,
  boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  src_id : String,
  dst_id : String,
  padding : Double,
) -> Array[AxisInterval] {
  let intervals : Array[AxisInterval] = []
  let lateral_clearance = @cmp.maximum(4.0, padding * 0.4)
  // Keep enough distance from crossed container interiors so rounded SVG
  // corner smoothing (radius ~10) still stays outside the container border.
  let rail_clearance = @cmp.maximum(14.0, padding * 0.8)
  let (span_lo, span_hi) = match flow {
    Down | Up =>
      (
        @cmp.minimum(start.x, end.x) - lateral_clearance,
        @cmp.maximum(start.x, end.x) + lateral_clearance,
      )
    Right | Left =>
      (
        @cmp.minimum(start.y, end.y) - lateral_clearance,
        @cmp.maximum(start.y, end.y) + lateral_clearance,
      )
  }
  for entry in boxes {
    let id = entry.0
    if id == src_id || id == dst_id {
      continue
    }
    let object = match object_by_id.get(id) {
      Some(v) => v
      None => continue
    }
    if !is_layout_container_candidate(object) {
      continue
    }
    let src_in = is_descendant_of_id(src_id, id, parent_id_by_child_id)
    let dst_in = is_descendant_of_id(dst_id, id, parent_id_by_child_id)
    if src_in && dst_in {
      continue
    }
    let box = entry.1
    let intersects_lateral = match flow {
      Down | Up => !(box.x + box.width <= span_lo || span_hi <= box.x)
      Right | Left => !(box.y + box.height <= span_lo || span_hi <= box.y)
    }
    if !intersects_lateral {
      continue
    }
    let (major_lo0, major_hi0) = match flow {
      Down | Up => (box.y, box.y + box.height)
      Right | Left => (box.x, box.x + box.width)
    }
    let major_lo = major_lo0 - rail_clearance
    let major_hi = major_hi0 + rail_clearance
    if major_hi > major_lo {
      intervals.push({ lo: major_lo, hi: major_hi })
    }
  }
  merge_axis_intervals(intervals)
}

///|
fn span_one_container_border_proximity_intervals(
  start : @graph.Point,
  end : @graph.Point,
  flow : @engine_api.Direction,
  boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  padding : Double,
) -> Array[AxisInterval] {
  let intervals : Array[AxisInterval] = []
  let lateral_clearance = @cmp.maximum(4.0, padding * 0.4)
  let rail_clearance = @cmp.maximum(16.0, padding)
  let (span_lo, span_hi) = match flow {
    Down | Up =>
      (
        @cmp.minimum(start.x, end.x) - lateral_clearance,
        @cmp.maximum(start.x, end.x) + lateral_clearance,
      )
    Right | Left =>
      (
        @cmp.minimum(start.y, end.y) - lateral_clearance,
        @cmp.maximum(start.y, end.y) + lateral_clearance,
      )
  }
  let (edge_major_lo, edge_major_hi) = match flow {
    Down | Up => (@cmp.minimum(start.y, end.y), @cmp.maximum(start.y, end.y))
    Right | Left => (@cmp.minimum(start.x, end.x), @cmp.maximum(start.x, end.x))
  }
  for entry in boxes {
    let id = entry.0
    let object = match object_by_id.get(id) {
      Some(v) => v
      None => continue
    }
    if !is_layout_container_candidate(object) {
      continue
    }
    let box = entry.1
    let intersects_lateral = match flow {
      Down | Up => !(box.x + box.width <= span_lo || span_hi <= box.x)
      Right | Left => !(box.y + box.height <= span_lo || span_hi <= box.y)
    }
    if !intersects_lateral {
      continue
    }
    let (major_lo0, major_hi0) = match flow {
      Down | Up => (box.y, box.y + box.height)
      Right | Left => (box.x, box.x + box.width)
    }
    if major_hi0 + rail_clearance < edge_major_lo ||
      edge_major_hi < major_lo0 - rail_clearance {
      continue
    }
    let top_lo = major_lo0 - rail_clearance
    let top_hi = major_lo0 + rail_clearance
    if top_hi > top_lo {
      intervals.push({ lo: top_lo, hi: top_hi })
    }
    let bottom_lo = major_hi0 - rail_clearance
    let bottom_hi = major_hi0 + rail_clearance
    if bottom_hi > bottom_lo {
      intervals.push({ lo: bottom_lo, hi: bottom_hi })
    }
  }
  merge_axis_intervals(intervals)
}

///|
fn reserved_label_obstacle_intervals(
  start : @graph.Point,
  end : @graph.Point,
  flow : @engine_api.Direction,
  reserved_label_boxes : Array[@graph.Box],
  padding : Double,
) -> Array[AxisInterval] {
  if reserved_label_boxes.is_empty() {
    return []
  }
  let intervals : Array[AxisInterval] = []
  let (major_lo, major_hi) = match flow {
    Down | Up => (@cmp.minimum(start.y, end.y), @cmp.maximum(start.y, end.y))
    Right | Left => (@cmp.minimum(start.x, end.x), @cmp.maximum(start.x, end.x))
  }
  let major_margin = @cmp.maximum(1.0, padding * 0.25)
  let axis_clearance = @cmp.maximum(6.0, padding * 0.6)
  for box in reserved_label_boxes {
    let intersects_major = match flow {
      Down | Up =>
        !(box.y + box.height <= major_lo + major_margin ||
        major_hi - major_margin <= box.y)
      Right | Left =>
        !(box.x + box.width <= major_lo + major_margin ||
        major_hi - major_margin <= box.x)
    }
    if !intersects_major {
      continue
    }
    let (axis_lo0, axis_hi0) = match flow {
      Down | Up => (box.x, box.x + box.width)
      Right | Left => (box.y, box.y + box.height)
    }
    let axis_lo = axis_lo0 - axis_clearance
    let axis_hi = axis_hi0 + axis_clearance
    if axis_hi > axis_lo {
      intervals.push({ lo: axis_lo, hi: axis_hi })
    }
  }
  merge_axis_intervals(intervals)
}

///|
fn long_edge_obstacle_intervals(
  start : @graph.Point,
  end : @graph.Point,
  flow : @engine_api.Direction,
  boxes : Map[String, @graph.Box],
  object_by_id : Map[String, @graph.ObjectInput],
  src_id : String,
  dst_id : String,
  padding : Double,
) -> Array[AxisInterval] {
  let intervals : Array[AxisInterval] = []
  let (major_lo, major_hi) = match flow {
    Down | Up => (@cmp.minimum(start.y, end.y), @cmp.maximum(start.y, end.y))
    Right | Left => (@cmp.minimum(start.x, end.x), @cmp.maximum(start.x, end.x))
  }
  let inner_lo = major_lo + @cmp.maximum(1.0, padding * 0.4)
  let inner_hi = major_hi - @cmp.maximum(1.0, padding * 0.4)
  let axis_clearance = @cmp.maximum(8.0, padding * 0.8)
  for entry in boxes {
    let id = entry.0
    if id == src_id || id == dst_id {
      continue
    }
    let node_box = entry.1
    let obstacle_box = match object_by_id.get(id) {
      Some(obj) =>
        if is_layout_container_candidate(obj) {
          match container_label_dimensions_railway(obj) {
            Some((_, label_height)) => {
              let reserved_height = label_height +
                RAILWAY_CONTAINER_LABEL_PADDING * 2.0 +
                6.0
              let height = @cmp.minimum(node_box.height, reserved_height)
              @graph.Box::new(node_box.x, node_box.y, node_box.width, height)
            }
            None => continue
          }
        } else {
          node_box
        }
      None => node_box
    }
    let intersects_major = match flow {
      Down | Up =>
        !(obstacle_box.y + obstacle_box.height <= inner_lo ||
        inner_hi <= obstacle_box.y)
      Right | Left =>
        !(obstacle_box.x + obstacle_box.width <= inner_lo ||
        inner_hi <= obstacle_box.x)
    }
    if !intersects_major {
      continue
    }
    let (axis_lo0, axis_hi0) = match flow {
      Down | Up => (obstacle_box.x, obstacle_box.x + obstacle_box.width)
      Right | Left => (obstacle_box.y, obstacle_box.y + obstacle_box.height)
    }
    let axis_lo = axis_lo0 - axis_clearance
    let axis_hi = axis_hi0 + axis_clearance
    if axis_hi > axis_lo {
      intervals.push({ lo: axis_lo, hi: axis_hi })
    }
  }
  merge_axis_intervals(intervals)
}

///|
fn merge_axis_intervals(intervals : Array[AxisInterval]) -> Array[AxisInterval] {
  if intervals.length() <= 1 {
    return intervals
  }
  intervals.sort_by(fn(a, b) {
    if a.lo < b.lo {
      -1
    } else if a.lo > b.lo {
      1
    } else if a.hi < b.hi {
      -1
    } else if a.hi > b.hi {
      1
    } else {
      0
    }
  })
  let merged : Array[AxisInterval] = []
  let mut cur_lo = intervals[0].lo
  let mut cur_hi = intervals[0].hi
  for i in 1..<intervals.length() {
    let interval = intervals[i]
    if interval.lo <= cur_hi + 1.0e-6 {
      cur_hi = @cmp.maximum(cur_hi, interval.hi)
    } else {
      merged.push({ lo: cur_lo, hi: cur_hi })
      cur_lo = interval.lo
      cur_hi = interval.hi
    }
  }
  merged.push({ lo: cur_lo, hi: cur_hi })
  merged
}

///|
fn axis_blocked_by_intervals(
  axis : Double,
  intervals : Array[AxisInterval],
) -> Bool {
  let tol = 1.0e-6
  for interval in intervals {
    if axis >= interval.lo - tol && axis <= interval.hi + tol {
      return true
    }
  }
  false
}

///|
fn nearest_unblocked_axis_bounded(
  preferred : Double,
  lo : Double,
  hi : Double,
  blocked : Array[AxisInterval],
) -> Double {
  let p = @cmp.maximum(lo, @cmp.minimum(preferred, hi))
  if !axis_blocked_by_intervals(p, blocked) {
    return p
  }
  let eps = 1.0
  let candidates : Array[Double] = [lo, hi]
  for interval in blocked {
    let left = @cmp.maximum(lo, @cmp.minimum(hi, interval.lo - eps))
    let right = @cmp.maximum(lo, @cmp.minimum(hi, interval.hi + eps))
    candidates.push(left)
    candidates.push(right)
    if p >= interval.lo - 1.0e-6 && p <= interval.hi + 1.0e-6 {
      let d_left = @cmp.maximum(0.0, p - interval.lo)
      let d_right = @cmp.maximum(0.0, interval.hi - p)
      let mirror_left = @cmp.maximum(
        lo,
        @cmp.minimum(hi, interval.lo - eps - d_left),
      )
      let mirror_right = @cmp.maximum(
        lo,
        @cmp.minimum(hi, interval.hi + eps + d_right),
      )
      candidates.push(mirror_left)
      candidates.push(mirror_right)
    }
  }
  let mut found = false
  let mut best = p
  let mut best_cost = 0.0
  for c in candidates {
    if axis_blocked_by_intervals(c, blocked) {
      continue
    }
    let cost = (c - p).abs()
    if !found || cost < best_cost {
      found = true
      best = c
      best_cost = cost
    }
  }
  if found {
    best
  } else {
    p
  }
}

///|
fn nearest_unblocked_axis(
  preferred : Double,
  lo : Double,
  hi : Double,
  blocked : Array[AxisInterval],
) -> Double {
  let p = @cmp.maximum(lo, @cmp.minimum(preferred, hi))
  if !axis_blocked_by_intervals(p, blocked) {
    return p
  }
  let eps = 1.0
  let candidates : Array[Double] = [lo, hi]
  for interval in blocked {
    candidates.push(@cmp.maximum(lo, @cmp.minimum(hi, interval.lo - eps)))
    candidates.push(@cmp.maximum(lo, @cmp.minimum(hi, interval.hi + eps)))
  }
  let mut found = false
  let mut best = p
  let mut best_cost = 0.0
  for c in candidates {
    if axis_blocked_by_intervals(c, blocked) {
      continue
    }
    let cost = (c - p).abs()
    if !found || cost < best_cost {
      found = true
      best = c
      best_cost = cost
    }
  }
  if found {
    best
  } else {
    if blocked.is_empty() {
      return p
    }
    let eps = 1.0
    let left = blocked[0].lo - eps
    let right = blocked[blocked.length() - 1].hi + eps
    if (p - left).abs() <= (right - p).abs() {
      left
    } else {
      right
    }
  }
}

///|
fn multi_edge_gap_shift(
  flow : @engine_api.Direction,
  direction : @engine_api.Direction,
  start : @graph.Point,
  end : @graph.Point,
  rail_track : Int,
  config : @engine_api.LayoutConfig,
) -> Double {
  let group = if flow != direction {
    3
  } else {
    match long_edge_lateral_side(direction, start, end) {
      -1 => 1
      1 => 2
      _ => 0
    }
  }
  let idx = rail_track * 4 + group
  let spacing = track_spacing(config)
  let raw = zigzag_track_offset(idx, spacing)
  let min_clear = @cmp.maximum(10.0, config.edge_padding / 2.0)
  let max_offset = @cmp.maximum(
    0.0,
    major_axis_spacing(direction, config) / 2.0 - min_clear,
  )
  @cmp.maximum(-max_offset, @cmp.minimum(raw, max_offset))
}

///|
fn reserve_gap_rail(
  preferred : Double,
  lo : Double,
  hi : Double,
  blocked : Array[AxisInterval],
  gap_rail_reservations : Ref[Map[Int, Array[GapRailReservation]]],
  gap_index : Int,
  span_lo : Double,
  span_hi : Double,
  flow : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Double {
  ignore(flow)
  let lo_norm = @cmp.minimum(lo, hi)
  let hi_norm = @cmp.maximum(lo, hi)
  if hi_norm <= lo_norm {
    return preferred
  }
  let span_lo_norm = @cmp.minimum(span_lo, span_hi)
  let span_hi_norm = @cmp.maximum(span_lo, span_hi)
  let preferred_clamped = @cmp.maximum(
    lo_norm,
    @cmp.minimum(preferred, hi_norm),
  )
  let base = nearest_unblocked_axis_bounded(
    preferred_clamped, lo_norm, hi_norm, blocked,
  )
  let min_sep = @cmp.maximum(track_spacing(config), 10.0)
  let tol = 1.0e-6

  fn overlaps_on_lateral_axis(
    a_lo : Double,
    a_hi : Double,
    b_lo : Double,
    b_hi : Double,
  ) -> Bool {
    !(a_hi <= b_lo + tol || b_hi <= a_lo + tol)
  }

  fn conflicts_with_gap(
    rail : Double,
    span_lo : Double,
    span_hi : Double,
    reservations : Array[GapRailReservation],
    min_sep : Double,
  ) -> Bool {
    for reservation in reservations {
      if !overlaps_on_lateral_axis(
          span_lo,
          span_hi,
          reservation.span_lo,
          reservation.span_hi,
        ) {
        continue
      }
      if (rail - reservation.rail).abs() < min_sep {
        return true
      }
    }
    false
  }

  fn append_reservation(
    gap_rail_reservations : Ref[Map[Int, Array[GapRailReservation]]],
    gap_index : Int,
    span_lo : Double,
    span_hi : Double,
    rail : Double,
  ) -> Unit {
    let item : GapRailReservation = { span_lo, span_hi, rail }
    match gap_rail_reservations.val.get(gap_index) {
      Some(arr) => arr.push(item)
      None => gap_rail_reservations.val[gap_index] = [item]
    }
  }

  fn acceptable(
    rail : Double,
    blocked : Array[AxisInterval],
    gap_rail_reservations : Ref[Map[Int, Array[GapRailReservation]]],
    gap_index : Int,
    span_lo : Double,
    span_hi : Double,
    min_sep : Double,
  ) -> Bool {
    if axis_blocked_by_intervals(rail, blocked) {
      return false
    }
    match gap_rail_reservations.val.get(gap_index) {
      Some(arr) => !conflicts_with_gap(rail, span_lo, span_hi, arr, min_sep)
      None => true
    }
  }

  if acceptable(
      base, blocked, gap_rail_reservations, gap_index, span_lo_norm, span_hi_norm,
      min_sep,
    ) {
    append_reservation(
      gap_rail_reservations, gap_index, span_lo_norm, span_hi_norm, base,
    )
    return base
  }

  for k in 1..<96 {
    let delta = k.to_double() * min_sep
    let up = base + delta
    if up <= hi_norm + tol &&
      acceptable(
        up, blocked, gap_rail_reservations, gap_index, span_lo_norm, span_hi_norm,
        min_sep,
      ) {
      append_reservation(
        gap_rail_reservations, gap_index, span_lo_norm, span_hi_norm, up,
      )
      return up
    }
    let down = base - delta
    if down >= lo_norm - tol &&
      acceptable(
        down, blocked, gap_rail_reservations, gap_index, span_lo_norm, span_hi_norm,
        min_sep,
      ) {
      append_reservation(
        gap_rail_reservations, gap_index, span_lo_norm, span_hi_norm, down,
      )
      return down
    }
    if up > hi_norm + tol && down < lo_norm - tol {
      break
    }
  }

  let fallback = nearest_unblocked_axis_bounded(
    preferred_clamped, lo_norm, hi_norm, blocked,
  )
  append_reservation(
    gap_rail_reservations, gap_index, span_lo_norm, span_hi_norm, fallback,
  )
  fallback
}

///|
fn span_one_edge_seed_shift(
  edge_index : Int,
  config : @engine_api.LayoutConfig,
) -> Double {
  ignore(edge_index)
  ignore(config)
  // Keep span-1 rails deterministic and driven by channel reservation only.
  0.0
}

///|
fn zigzag_track_offset(track : Int, spacing : Double) -> Double {
  if track <= 0 {
    return 0.0
  }
  let tier = (track + 1) / 2
  let sign = if track % 2 == 1 { 1.0 } else { -1.0 }
  tier.to_double() * spacing * sign
}

///|
fn same_rank_route(
  src_box : @graph.Box,
  dst_box : @graph.Box,
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
) -> Array[@graph.Point] {
  let start = exit_of_box(src_box, direction)
  let end = entry_of_box(dst_box, direction)
  let clearance = config.edge_padding + track_spacing(config)
  match direction {
    Down => {
      let rail = @cmp.maximum(
          src_box.y + src_box.height,
          dst_box.y + dst_box.height,
        ) +
        clearance
      enforce_flow_tangent(
        [
          start,
          @graph.Point::new(start.x, rail),
          @graph.Point::new(end.x, rail),
          end,
        ],
        Down,
      )
    }
    Up => {
      let rail = @cmp.minimum(src_box.y, dst_box.y) - clearance
      enforce_flow_tangent(
        [
          start,
          @graph.Point::new(start.x, rail),
          @graph.Point::new(end.x, rail),
          end,
        ],
        Up,
      )
    }
    Right => {
      let rail = @cmp.maximum(
          src_box.x + src_box.width,
          dst_box.x + dst_box.width,
        ) +
        clearance
      enforce_flow_tangent(
        [
          start,
          @graph.Point::new(rail, start.y),
          @graph.Point::new(rail, end.y),
          end,
        ],
        Right,
      )
    }
    Left => {
      let rail = @cmp.minimum(src_box.x, dst_box.x) - clearance
      enforce_flow_tangent(
        [
          start,
          @graph.Point::new(rail, start.y),
          @graph.Point::new(rail, end.y),
          end,
        ],
        Left,
      )
    }
  }
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
    Down =>
      if !approx_eq(p0.x, p1.x) {
        let y = if approx_eq(p0.y, p1.y) { p0.y + 1.0 } else { p1.y }
        with_start.push(@graph.Point::new(p0.x, y))
      }
    Up =>
      if !approx_eq(p0.x, p1.x) {
        let y = if approx_eq(p0.y, p1.y) { p0.y - 1.0 } else { p1.y }
        with_start.push(@graph.Point::new(p0.x, y))
      }
    Right =>
      if !approx_eq(p0.y, p1.y) {
        let x = if approx_eq(p0.x, p1.x) { p0.x + 1.0 } else { p1.x }
        with_start.push(@graph.Point::new(x, p0.y))
      }
    Left =>
      if !approx_eq(p0.y, p1.y) {
        let x = if approx_eq(p0.x, p1.x) { p0.x - 1.0 } else { p1.x }
        with_start.push(@graph.Point::new(x, p0.y))
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
    Down =>
      if !approx_eq(prev.x, end.x) {
        let y = if approx_eq(prev.y, end.y) { end.y - 1.0 } else { prev.y }
        with_end.push(@graph.Point::new(end.x, y))
      }
    Up =>
      if !approx_eq(prev.x, end.x) {
        let y = if approx_eq(prev.y, end.y) { end.y + 1.0 } else { prev.y }
        with_end.push(@graph.Point::new(end.x, y))
      }
    Right =>
      if !approx_eq(prev.y, end.y) {
        let x = if approx_eq(prev.x, end.x) { end.x - 1.0 } else { prev.x }
        with_end.push(@graph.Point::new(x, end.y))
      }
    Left =>
      if !approx_eq(prev.y, end.y) {
        let x = if approx_eq(prev.x, end.x) { end.x + 1.0 } else { prev.x }
        with_end.push(@graph.Point::new(x, end.y))
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
fn major_coordinate_for_flow(
  p : @graph.Point,
  flow : @engine_api.Direction,
) -> Double {
  match flow {
    Down | Up => p.y
    Right | Left => p.x
  }
}

///|
fn span_one_detour_shoulder_major(
  start : @graph.Point,
  flow : @engine_api.Direction,
  blocked : Array[AxisInterval],
  padding : Double,
) -> Double {
  let start_major = major_coordinate_for_flow(start, flow)
  let min_step = 1.0
  let preferred_step = @cmp.maximum(6.0, padding * 0.4)
  match flow {
    Down | Right => {
      let min_major = start_major + min_step
      let max_major = start_major + preferred_step
      for interval in blocked {
        if interval.hi <= start_major + 1.0e-6 {
          continue
        }
        let safe_hi = interval.lo - 1.0
        if safe_hi >= min_major {
          return @cmp.minimum(max_major, safe_hi)
        } else {
          return min_major
        }
      }
      max_major
    }
    Up | Left => {
      let max_major = start_major - min_step
      let min_major = start_major - preferred_step
      let mut nearest_hi = None
      for interval in blocked {
        if interval.lo >= start_major - 1.0e-6 {
          break
        }
        nearest_hi = Some(interval.hi)
      }
      match nearest_hi {
        Some(v) => {
          let safe_lo = v + 1.0
          if safe_lo <= max_major {
            @cmp.maximum(min_major, safe_lo)
          } else {
            max_major
          }
        }
        None => min_major
      }
    }
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
fn waypoints_between_via_anchor(
  dst : @graph.Point,
  rail : Double,
  anchor : Double,
  direction : @engine_api.Direction,
  shoulder_major : Double,
) -> Array[@graph.Point] {
  let points : Array[@graph.Point] = []
  push_if_new(points, anchor_on_rail(anchor, shoulder_major, direction))
  push_if_new(points, anchor_on_rail(anchor, rail, direction))
  push_if_new(points, point_on_rail(dst, rail, direction))
  points
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
