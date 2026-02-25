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
    let label_major_span = edge_label_major_span(e, direction)
    match spans_by_gap.get(gap) {
      Some(arr) =>
        arr.push({ start: a0, end: a1, edge_index: e.index, label_major_span })
      None =>
        spans_by_gap[gap] = [
          { start: a0, end: a1, edge_index: e.index, label_major_span },
        ]
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
      let rail_x = @cmp.maximum(start.x, end.x) +
        config.edge_padding * 2.0 +
        track_spacing(config) * rail_track.to_double()
      let start_on_rail = @graph.Point::new(rail_x, start.y)
      // Leave the rail just below the destination, then enter vertically so the
      // arrowhead direction is correct.
      let last_rail = rails[rails.length() - 1]
      push_if_new(waypoints, start_on_rail)
      push_if_new(waypoints, @graph.Point::new(rail_x, last_rail))
      push_if_new(waypoints, point_on_rail(end, last_rail, flow))
      push_if_new(waypoints, end)
      return enforce_flow_tangent(waypoints, tangent_flow)
    }
    (Up, Down) => {
      let rail_x = @cmp.maximum(start.x, end.x) +
        config.edge_padding * 2.0 +
        track_spacing(config) * rail_track.to_double()
      let start_on_rail = @graph.Point::new(rail_x, start.y)
      let last_rail = rails[rails.length() - 1]
      push_if_new(waypoints, start_on_rail)
      push_if_new(waypoints, @graph.Point::new(rail_x, last_rail))
      push_if_new(waypoints, point_on_rail(end, last_rail, flow))
      push_if_new(waypoints, end)
      return enforce_flow_tangent(waypoints, tangent_flow)
    }
    _ => ()
  }
  if span == 1 {
    let rail = rails[0] + rail_shift
    let points = waypoints_between(start, end, rail, flow)
    waypoints.append(points)
    push_if_new(waypoints, end)
    return enforce_flow_tangent(waypoints, tangent_flow)
  }
  // Long edge: route through an edge-local channel anchor instead of a global
  // virtual-node anchor. This keeps long edges compact and avoids sweeping
  // detours that hurt readability on deep graphs.
  let anchor = long_edge_channel_anchor(
    start, end, flow, direction, rail_track, config, boxes, src_id, dst_id,
  )

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
  enforce_flow_tangent(waypoints, tangent_flow)
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
  src_id : String,
  dst_id : String,
) -> Double {
  let (src_axis, dst_axis) = match flow {
    Down | Up => (start.x, end.x)
    Right | Left => (start.y, end.y)
  }
  let spacing = track_spacing(config)
  let center_axis = (src_axis + dst_axis) / 2.0
  let lateral = dst_axis - src_axis
  let side_tol = spacing * 0.75
  let side_clearance = @cmp.maximum(config.edge_padding * 1.8, spacing * 2.0)
  let blocked_center = long_edge_center_axis_blocked(
    center_axis,
    start,
    end,
    flow,
    boxes,
    src_id,
    dst_id,
    config.edge_padding,
  )
  let preferred = if lateral.abs() <= side_tol {
    if blocked_center {
      let (block_min, block_max) = long_edge_blocking_axis_bounds(
        start, end, flow, boxes, src_id, dst_id,
      )
      match (block_min, block_max) {
        (Some(lo), Some(hi)) => {
          let left_anchor = lo -
            side_clearance -
            rail_track.to_double() * spacing
          let right_anchor = hi +
            side_clearance +
            rail_track.to_double() * spacing
          let left_cost = (center_axis - left_anchor).abs()
          let right_cost = (right_anchor - center_axis).abs()
          if right_cost <= left_cost {
            right_anchor
          } else {
            left_anchor
          }
        }
        _ => center_axis + side_clearance + rail_track.to_double() * spacing
      }
    } else {
      center_axis + zigzag_track_offset(rail_track, spacing)
    }
  } else if lateral > 0.0 {
    @cmp.maximum(src_axis, dst_axis) +
    side_clearance +
    rail_track.to_double() * spacing
  } else {
    @cmp.minimum(src_axis, dst_axis) -
    side_clearance -
    rail_track.to_double() * spacing
  }
  let margin = major_axis_spacing(direction, config) * 1.2 + spacing * 4.0
  let lo = @cmp.minimum(src_axis, dst_axis) - margin
  let hi = @cmp.maximum(src_axis, dst_axis) + margin
  let unclamped = preferred
  @cmp.maximum(lo, @cmp.minimum(unclamped, hi))
}

///|
fn long_edge_center_axis_blocked(
  axis : Double,
  start : @graph.Point,
  end : @graph.Point,
  flow : @engine_api.Direction,
  boxes : Map[String, @graph.Box],
  src_id : String,
  dst_id : String,
  padding : Double,
) -> Bool {
  let (major_lo, major_hi) = match flow {
    Down | Up => (@cmp.minimum(start.y, end.y), @cmp.maximum(start.y, end.y))
    Right | Left => (@cmp.minimum(start.x, end.x), @cmp.maximum(start.x, end.x))
  }
  let inner_lo = major_lo + padding
  let inner_hi = major_hi - padding
  for entry in boxes {
    let id = entry.0
    if id == src_id || id == dst_id {
      continue
    }
    let b = entry.1
    let intersects_major = match flow {
      Down | Up => !(b.y + b.height <= inner_lo || inner_hi <= b.y)
      Right | Left => !(b.x + b.width <= inner_lo || inner_hi <= b.x)
    }
    if !intersects_major {
      continue
    }
    let contains_axis = match flow {
      Down | Up => b.x <= axis && axis <= b.x + b.width
      Right | Left => b.y <= axis && axis <= b.y + b.height
    }
    if contains_axis {
      return true
    }
  }
  false
}

///|
fn long_edge_blocking_axis_bounds(
  start : @graph.Point,
  end : @graph.Point,
  flow : @engine_api.Direction,
  boxes : Map[String, @graph.Box],
  src_id : String,
  dst_id : String,
) -> (Double?, Double?) {
  let (major_lo, major_hi) = match flow {
    Down | Up => (@cmp.minimum(start.y, end.y), @cmp.maximum(start.y, end.y))
    Right | Left => (@cmp.minimum(start.x, end.x), @cmp.maximum(start.x, end.x))
  }
  let mut min_axis : Double? = None
  let mut max_axis : Double? = None
  for entry in boxes {
    let id = entry.0
    if id == src_id || id == dst_id {
      continue
    }
    let b = entry.1
    let intersects_major = match flow {
      Down | Up => !(b.y + b.height <= major_lo || major_hi <= b.y)
      Right | Left => !(b.x + b.width <= major_lo || major_hi <= b.x)
    }
    if !intersects_major {
      continue
    }
    let (axis_lo, axis_hi) = match flow {
      Down | Up => (b.x, b.x + b.width)
      Right | Left => (b.y, b.y + b.height)
    }
    min_axis = Some(
      match min_axis {
        Some(v) => @cmp.minimum(v, axis_lo)
        None => axis_lo
      },
    )
    max_axis = Some(
      match max_axis {
        Some(v) => @cmp.maximum(v, axis_hi)
        None => axis_hi
      },
    )
  }
  (min_axis, max_axis)
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
