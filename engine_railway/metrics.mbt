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
fn route_point_at_percent(
  route : Array[@graph.Point],
  percent : Double,
) -> @graph.Point {
  if route.is_empty() {
    return @graph.Point::new(0.0, 0.0)
  }
  if route.length() == 1 {
    return route[0]
  }
  let clamped = if percent < 0.0 {
    0.0
  } else if percent > 1.0 {
    1.0
  } else {
    percent
  }
  let total = route_total_length(route)
  if total <= 0.000001 {
    return route[0]
  }
  let target = total * clamped
  let mut walked = 0.0
  for i in 1..<route.length() {
    let p0 = route[i - 1]
    let p1 = route[i]
    let segment_len = point_distance(p0, p1)
    if segment_len <= 0.000001 {
      continue
    }
    if walked + segment_len >= target {
      let t = (target - walked) / segment_len
      let x = p0.x + (p1.x - p0.x) * t
      let y = p0.y + (p1.y - p0.y) * t
      return @graph.Point::new(x, y)
    }
    walked = walked + segment_len
  }
  route[route.length() - 1]
}

///|
fn route_total_length(route : Array[@graph.Point]) -> Double {
  if route.length() < 2 {
    return 0.0
  }
  let mut total = 0.0
  for i in 1..<route.length() {
    total = total + point_distance(route[i - 1], route[i])
  }
  total
}

///|
fn point_distance(a : @graph.Point, b : @graph.Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  (dx * dx + dy * dy).sqrt()
}

///|
priv struct OrthSegment {
  edge_index : Int
  x1 : Double
  y1 : Double
  x2 : Double
  y2 : Double
  vertical : Bool
}

///|
fn railway_readability_metrics(
  graph : @graph.GraphInput,
  patch : @graph.LayoutPatch,
) -> (Int, Int, Int, Int, Double) {
  let crossing_count = route_crossing_count(patch)
  let label_overlap_count = edge_label_overlap_count(patch)
  let node_overlap_count = node_overlap_count_excluding_hierarchy(graph, patch)
  let (long_detour_count, edge_total_length) = route_detour_metrics(
    graph, patch,
  )
  (
    crossing_count, label_overlap_count, node_overlap_count, long_detour_count, edge_total_length,
  )
}

///|
fn route_crossing_count(patch : @graph.LayoutPatch) -> Int {
  let segments : Array[OrthSegment] = []
  for edge_entry in patch.edges {
    let edge_index = edge_entry.0
    let route = edge_entry.1
    for i in 1..<route.length() {
      let p0 = route[i - 1]
      let p1 = route[i]
      if p0 == p1 {
        continue
      }
      if (p0.x - p1.x).abs() <= 1.0e-6 {
        segments.push({
          edge_index,
          x1: p0.x,
          y1: p0.y,
          x2: p1.x,
          y2: p1.y,
          vertical: true,
        })
      } else if (p0.y - p1.y).abs() <= 1.0e-6 {
        segments.push({
          edge_index,
          x1: p0.x,
          y1: p0.y,
          x2: p1.x,
          y2: p1.y,
          vertical: false,
        })
      }
    }
  }
  let mut crossings = 0
  for i in 0..<segments.length() {
    let a = segments[i]
    let mut j = i + 1
    while j < segments.length() {
      let b = segments[j]
      if a.edge_index == b.edge_index || a.vertical == b.vertical {
        j = j + 1
        continue
      }
      let (v, h) = if a.vertical { (a, b) } else { (b, a) }
      if orth_segments_cross(v, h) {
        crossings = crossings + 1
      }
      j = j + 1
    }
  }
  crossings
}

///|
fn orth_segments_cross(v : OrthSegment, h : OrthSegment) -> Bool {
  let vx = v.x1
  let hy = h.y1
  let vmin = @cmp.minimum(v.y1, v.y2)
  let vmax = @cmp.maximum(v.y1, v.y2)
  let hmin = @cmp.minimum(h.x1, h.x2)
  let hmax = @cmp.maximum(h.x1, h.x2)
  vx > hmin + 1.0e-6 &&
  vx < hmax - 1.0e-6 &&
  hy > vmin + 1.0e-6 &&
  hy < vmax - 1.0e-6
}

///|
fn edge_label_overlap_count(patch : @graph.LayoutPatch) -> Int {
  let labels : Array[(Int, @graph.Box)] = []
  for entry in patch.edge_labels {
    labels.push((entry.0, entry.1))
  }
  let mut overlaps = 0
  for i in 0..<labels.length() {
    let (_, a) = labels[i]
    let mut j = i + 1
    while j < labels.length() {
      let (_, b) = labels[j]
      if boxes_overlap_strict(a, b) {
        overlaps = overlaps + 1
      }
      j = j + 1
    }
  }
  overlaps
}

///|
fn node_overlap_count_excluding_hierarchy(
  graph : @graph.GraphInput,
  patch : @graph.LayoutPatch,
) -> Int {
  let parent_id_by_child_id = build_parent_id_by_child_id(graph)
  let nodes : Array[(String, @graph.Box)] = []
  for entry in patch.nodes {
    nodes.push((entry.0, entry.1))
  }
  let mut overlaps = 0
  for i in 0..<nodes.length() {
    let (a_id, a_box) = nodes[i]
    let mut j = i + 1
    while j < nodes.length() {
      let (b_id, b_box) = nodes[j]
      if is_ancestor_of(a_id, b_id, parent_id_by_child_id) ||
        is_ancestor_of(b_id, a_id, parent_id_by_child_id) {
        j = j + 1
        continue
      }
      if boxes_overlap_strict(a_box, b_box) {
        overlaps = overlaps + 1
      }
      j = j + 1
    }
  }
  overlaps
}

///|
fn is_ancestor_of(
  ancestor_id : String,
  node_id : String,
  parent_id_by_child_id : Map[String, String],
) -> Bool {
  let mut current = node_id
  while true {
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => {
        if parent_id == ancestor_id {
          return true
        }
        current = parent_id
      }
      None => break
    }
  }
  false
}

///|
fn boxes_overlap_strict(a : @graph.Box, b : @graph.Box) -> Bool {
  let x_overlap = @cmp.minimum(a.x + a.width, b.x + b.width) -
    @cmp.maximum(a.x, b.x)
  let y_overlap = @cmp.minimum(a.y + a.height, b.y + b.height) -
    @cmp.maximum(a.y, b.y)
  x_overlap > 1.0e-6 && y_overlap > 1.0e-6
}

///|
fn route_detour_metrics(
  graph : @graph.GraphInput,
  patch : @graph.LayoutPatch,
) -> (Int, Double) {
  let mut long_detour_count = 0
  let mut edge_total_length = 0.0
  for edge in graph.edges {
    let route = patch.edges.get_or_default(edge.index, [])
    if route.length() < 2 {
      continue
    }
    let length = route_total_length(route)
    edge_total_length = edge_total_length + length
    let start = route[0]
    let end = route[route.length() - 1]
    let direct = (start.x - end.x).abs() + (start.y - end.y).abs()
    let threshold = direct * 2.4 + 120.0
    if length > threshold {
      long_detour_count = long_detour_count + 1
    }
  }
  (long_detour_count, edge_total_length)
}
