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
fn layout_sequence_diagram_railway(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
) -> @graph.LayoutPatch {
  let patch = @graph.LayoutPatch::new()
  copy_passthrough_layout_data(patch, graph)

  let participant_ids = sequence_participant_ids_railway(graph)
  if participant_ids.is_empty() {
    return patch
  }

  let object_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }

  let widths : Array[Double] = []
  let heights : Array[Double] = []
  for id in participant_ids {
    match object_by_id.get(id) {
      Some(obj) => {
        let (w0, h0) = object_size_with_objects(obj, config, object_by_id)
        let width = if w0 < 100.0 { 100.0 } else { w0 }
        let height = if h0 < 66.0 { 66.0 } else { h0 }
        widths.push(width)
        heights.push(height)
      }
      None => {
        widths.push(100.0)
        heights.push(66.0)
      }
    }
  }

  let centers : Array[Double] = []
  if !widths.is_empty() {
    centers.push(12.0 + widths[0] / 2.0)
    for i = 1; i < widths.length(); i = i + 1 {
      let base_gap = widths[i - 1] / 2.0 + widths[i] / 2.0 + 50.0
      centers.push(centers[i - 1] + base_gap)
    }
  }

  let participant_index_by_id : Map[String, Int] = {}
  for i, id in participant_ids {
    participant_index_by_id[id] = i
  }

  for edge in graph.edges {
    let src_index = match participant_index_by_id.get(edge.src_id) {
      Some(v) => v
      None => continue
    }
    let dst_index = match participant_index_by_id.get(edge.dst_id) {
      Some(v) => v
      None => continue
    }
    if src_index == dst_index {
      continue
    }
    let left = if src_index < dst_index { src_index } else { dst_index }
    let right = if src_index < dst_index { dst_index } else { src_index }
    let (label_width, _) = sequence_edge_label_size_railway(edge)
    let required_span = if label_width > 0.0 { label_width + 56.0 } else { 0.0 }
    let current_span = centers[right] - centers[left]
    if required_span > current_span {
      let delta = required_span - current_span
      for i = right; i < centers.length(); i = i + 1 {
        centers[i] = centers[i] + delta
      }
    }
  }

  let participant_top = 52.0
  for i, id in participant_ids {
    let width = widths[i]
    let height = heights[i]
    patch.nodes[id] = @graph.Box::new(
      centers[i] - width / 2.0,
      participant_top,
      width,
      height,
    )
  }

  let max_participant_height = array_max_railway(heights, 66.0)
  let lifeline_start_y = participant_top + max_participant_height + 2.0
  let max_label_height = sequence_max_label_height_railway(graph.edges)
  let first_message_y = lifeline_start_y + 78.0
  let message_gap = @cmp.maximum(90.0, max_label_height + 30.0)

  for i, edge in graph.edges {
    let src_index = match participant_index_by_id.get(edge.src_id) {
      Some(v) => v
      None => continue
    }
    let dst_index = match participant_index_by_id.get(edge.dst_id) {
      Some(v) => v
      None => continue
    }
    let src_x = centers[src_index]
    let dst_x = centers[dst_index]
    let y = first_message_y + i.to_double() * message_gap
    if src_index == dst_index {
      // Self message: keep a compact loop on the right side of lifeline.
      let loop_dx = 40.0
      let loop_dy = 28.0
      patch.edges[edge.index] = [
        @graph.Point::new(src_x, y),
        @graph.Point::new(src_x + loop_dx, y),
        @graph.Point::new(src_x + loop_dx, y + loop_dy),
        @graph.Point::new(src_x, y + loop_dy),
      ]
    } else {
      patch.edges[edge.index] = [
        @graph.Point::new(src_x, y),
        @graph.Point::new(dst_x, y),
      ]
    }
    if edge.label != "" {
      let (label_width, label_height) = sequence_edge_label_size_railway(edge)
      let center_x = if src_index == dst_index {
        src_x + 20.0
      } else {
        (src_x + dst_x) / 2.0
      }
      let label_y = y - label_height - 8.0
      patch.edge_labels[edge.index] = @graph.Box::new(
        center_x - label_width / 2.0,
        label_y,
        label_width,
        label_height,
      )
    }
  }

  patch
}

///|
fn sequence_participant_ids_railway(graph : @graph.GraphInput) -> Array[String] {
  if !graph.root.child_ids.is_empty() {
    let ids : Array[String] = []
    let exists : Map[String, Bool] = {}
    for obj in graph.objects {
      exists[obj.id] = true
    }
    for id in graph.root.child_ids {
      if exists.contains(id) {
        ids.push(id)
      }
    }
    if !ids.is_empty() {
      return ids
    }
  }
  let child_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    for child_id in obj.child_ids {
      child_ids[child_id] = true
    }
  }
  let ids : Array[String] = []
  for obj in graph.objects {
    if !child_ids.contains(obj.id) {
      ids.push(obj.id)
    }
  }
  ids
}

///|
fn sequence_edge_label_size_railway(
  edge : @graph.EdgeInput,
) -> (Double, Double) {
  match edge_label_size(edge) {
    Some((width, height)) => {
      let adjusted_width = if width > 0.0 { width + 4.0 } else { 0.0 }
      let font_size = match edge.style.font_size {
        Some(v) => v.as_int().unwrap_or(16)
        None => 16
      }
      let min_height = font_size.to_double() + 5.0
      let adjusted_height = if height < min_height {
        min_height
      } else {
        height
      }
      (adjusted_width, adjusted_height)
    }
    None => (0.0, 0.0)
  }
}

///|
fn array_max_railway(values : Array[Double], fallback : Double) -> Double {
  if values.is_empty() {
    return fallback
  }
  let mut out = values[0]
  for v in values {
    if v > out {
      out = v
    }
  }
  out
}

///|
fn sequence_max_label_height_railway(edges : Array[@graph.EdgeInput]) -> Double {
  let mut max_height = 0.0
  for edge in edges {
    let (_, label_height) = sequence_edge_label_size_railway(edge)
    if label_height > max_height {
      max_height = label_height
    }
  }
  max_height
}
