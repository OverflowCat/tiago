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
fn object_size(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
) -> (Double, Double) {
  match obj.box {
    Some(b) => (b.width, b.height)
    None => {
      let font_size = match obj.style.font_size {
        Some(v) => v.as_int().unwrap_or(16)
        None => 16
      }
      let is_bold = style_bool(obj.style.bold, false)
      let is_italic = style_bool(obj.style.italic, true)
      let is_mono = style_is_mono(obj.style.font_family)
      let dims = @text_metrics.measure_label(
        obj.label,
        font_size,
        is_mono,
        is_bold,
        is_italic,
      )
      let label_width = if dims.width > 0.0 {
        dims.width + 24.0
      } else {
        config.default_width
      }
      let label_height = if dims.height > 0.0 {
        dims.height + 16.0
      } else {
        config.default_height
      }
      (
        @cmp.maximum(config.default_width, label_width),
        @cmp.maximum(config.default_height, label_height),
      )
    }
  }
}

///|
fn recompute_edge_label_boxes(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  for edge in graph.edges {
    let route = match patch.edges.get(edge.index) {
      Some(v) => v
      None => continue
    }
    if route.is_empty() {
      continue
    }
    let (width, height) = match edge_label_size(edge) {
      Some(v) => v
      None => continue
    }
    let center = route_point_at_percent(route, 0.5)
    patch.edge_labels[edge.index] = @graph.Box::new(
      center.x - width / 2.0,
      center.y - height / 2.0,
      width,
      height,
    )
  }
}

///|
fn edge_label_size(edge : @graph.EdgeInput) -> (Double, Double)? {
  match edge.label_box {
    Some(box) => {
      let width = if box.width > 0.0 { box.width } else { 0.0 }
      let height = if box.height > 0.0 { box.height } else { 0.0 }
      if width > 0.0 && height > 0.0 {
        Some((width, height))
      } else {
        fallback_edge_label_size(edge)
      }
    }
    None => fallback_edge_label_size(edge)
  }
}

///|
fn fallback_edge_label_size(edge : @graph.EdgeInput) -> (Double, Double)? {
  if edge.label.is_empty() {
    return None
  }
  let font_size = match edge.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(edge.style.bold, false)
  let is_italic = style_bool(edge.style.italic, true)
  let is_mono = style_is_mono(edge.style.font_family)
  let dims = @text_metrics.measure_label(
    edge.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  let width = if dims.width > 0.0 {
    dims.width
  } else {
    edge.label.length().to_double() * 7.0
  }
  let height = if dims.height > 0.0 {
    dims.height
  } else {
    font_size.to_double() + 5.0
  }
  Some((width, height))
}

///|
fn style_bool(value : @graph.StyleValue?, default : Bool) -> Bool {
  match value {
    Some(v) => v.as_bool().unwrap_or(default)
    None => default
  }
}

///|
fn style_is_mono(value : @graph.StyleValue?) -> Bool {
  match value {
    Some(v) =>
      match v.get_value().to_lower() {
        "mono" | "monospace" | "code" => true
        _ => false
      }
    None => false
  }
}
