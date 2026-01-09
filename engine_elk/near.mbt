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

// ============================================================================
// Near Positioning
// ============================================================================

///|
/// Near constant positions
let near_constants : Array[String] = [
  "top-left", "top-center", "top-right", "center-left", "center-right", "bottom-left",
  "bottom-center", "bottom-right",
]

///|
/// Check if a near value is a constant position
fn is_near_constant(near : String) -> Bool {
  for c in near_constants {
    if c == near.to_lower() {
      return true
    }
  }
  false
}

///|
/// Apply near positioning to all objects that have it set
fn apply_near_positioning(graph : @graph.Graph, config : LayoutConfig) -> Unit {
  // Get root bounding box (for constant positions relative to root)
  let root_box = compute_root_bounding_box(graph)
  // Apply near positioning to each object
  for obj in graph.objects {
    if obj.get_near() is Some(near) {
      if is_near_constant(near) {
        apply_constant_near(obj, near, root_box, config)
      } else {
        apply_object_near(graph, obj, near, config)
      }
    }
  }
}

///|
/// Compute bounding box containing all root objects
fn compute_root_bounding_box(graph : @graph.Graph) -> @graph.Box {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  let roots = find_root_objects(graph)
  for obj in roots {
    if obj.get_box() is Some(b) {
      if first {
        min_x = b.x
        min_y = b.y
        max_x = b.x + b.width
        max_y = b.y + b.height
        first = false
      } else {
        if b.x < min_x {
          min_x = b.x
        }
        if b.y < min_y {
          min_y = b.y
        }
        if b.x + b.width > max_x {
          max_x = b.x + b.width
        }
        if b.y + b.height > max_y {
          max_y = b.y + b.height
        }
      }
    }
  }
  @graph.Box::new(min_x, min_y, max_x - min_x, max_y - min_y)
}

///|
/// Apply constant near position (top-left, center, etc.)
fn apply_constant_near(
  obj : @graph.Object,
  near : String,
  parent_box : @graph.Box,
  config : LayoutConfig,
) -> Unit {
  if obj.get_box() is Some(b) {
    let margin = config.container_padding
    let (x, y) = match near.to_lower() {
      "top-left" => (parent_box.x + margin, parent_box.y + margin)
      "top-center" =>
        (
          parent_box.x + parent_box.width / 2.0 - b.width / 2.0,
          parent_box.y + margin,
        )
      "top-right" =>
        (
          parent_box.x + parent_box.width - b.width - margin,
          parent_box.y + margin,
        )
      "center-left" =>
        (
          parent_box.x + margin,
          parent_box.y + parent_box.height / 2.0 - b.height / 2.0,
        )
      "center-right" =>
        (
          parent_box.x + parent_box.width - b.width - margin,
          parent_box.y + parent_box.height / 2.0 - b.height / 2.0,
        )
      "bottom-left" =>
        (
          parent_box.x + margin,
          parent_box.y + parent_box.height - b.height - margin,
        )
      "bottom-center" =>
        (
          parent_box.x + parent_box.width / 2.0 - b.width / 2.0,
          parent_box.y + parent_box.height - b.height - margin,
        )
      "bottom-right" =>
        (
          parent_box.x + parent_box.width - b.width - margin,
          parent_box.y + parent_box.height - b.height - margin,
        )
      _ => (b.x, b.y) // Keep current position if unknown
    }
    obj.set_box(@graph.Box::new(x, y, b.width, b.height))
  }
}

///|
/// Apply near positioning relative to another object
fn apply_object_near(
  graph : @graph.Graph,
  obj : @graph.Object,
  target_id : String,
  config : LayoutConfig,
) -> Unit {
  // Find the target object
  if obj.get_box() is Some(obj_box) &&
    graph.find_object(target_id) is Some(target_obj) &&
    target_obj.get_box() is Some(target_box) {
    // Position the object near the target (to the right and slightly below)
    let margin = config.horizontal_spacing / 2.0
    let x = target_box.x + target_box.width + margin
    let y = target_box.y
    obj.set_box(@graph.Box::new(x, y, obj_box.width, obj_box.height))
  }
}
