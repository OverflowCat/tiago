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
/// Shared sizing utilities across ELK algorithm ports.

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn ensure_label_size(label : ElkLabel) -> Unit {
  if label.width <= 0.0 {
    label.width = label.text.length().to_double() * 8.0
  }
  if label.height <= 0.0 {
    label.height = 14.0
  }
}

///|
fn ensure_sizes(node : ElkNode, options : LayoutOptions) -> Unit {
  let node_options = resolve_options_for_node(options, node)
  for label in node.labels {
    ensure_label_size(label)
  }
  for port in node.ports {
    for label in port.labels {
      ensure_label_size(label)
    }
  }
  for edge in node.edges {
    for label in edge.labels {
      ensure_label_size(label)
    }
  }
  for child in node.children {
    ensure_sizes(child, node_options)
  }

  // Auto-size nodes when missing width/height.
  if node.width <= 0.0 || node.height <= 0.0 {
    let (min_w, min_h) = match node_options.node_size_minimum {
      Some((w, h)) => (w, h)
      None => (60.0, 40.0)
    }
    let mut label_w = 0.0
    let mut label_h = 0.0
    for label in node.labels {
      if label.width > label_w {
        label_w = label.width
      }
      label_h = label_h + label.height
    }
    let padding = 20.0
    if node.width <= 0.0 {
      node.width = max_double(min_w, label_w + padding)
    }
    if node.height <= 0.0 {
      node.height = max_double(min_h, label_h + padding)
    }
  }
}
