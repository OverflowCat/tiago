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
// Edge Label Positioning
// ============================================================================

///|
/// Position edge labels to avoid overlaps with nodes and other labels
fn position_edge_labels(graph : Graph, config : LayoutConfig) -> Unit {
  // Collect all node bounding boxes for overlap detection
  let node_boxes : Array[@graph.Box] = []
  for obj in graph.objects {
    match obj.box {
      Some(b) => node_boxes.push(b)
      None => ()
    }
  }
  // Collect already-placed label boxes for inter-label collision detection
  let label_boxes : Array[@graph.Box] = []
  // Process each edge with a label
  for edge in graph.edges {
    if edge.label == "" {
      continue
    }
    match edge.midpoint() {
      Some(mid) => {
        let (label_width, label_height) = match edge.label_box {
          Some(b) => (b.width, b.height)
          None =>
            abort(
              "Edge '\{edge.src_id} -> \{edge.dst_id}' has no label_box; sizes must be precomputed",
            )
        }
        // Initial label box centered at midpoint
        let mut label_x = mid.x - label_width / 2.0
        let mut label_y = mid.y - label_height / 2.0
        let mut label_box = @graph.Box::new(
          label_x, label_y, label_width, label_height,
        )
        // Calculate perpendicular direction to the edge
        let (perp_x, perp_y) = compute_perpendicular_direction(edge)
        // Also get the edge direction for along-edge offsets
        let route = edge.route
        let (edge_dx, edge_dy) = if route.length() >= 2 {
          let p1 = route[0]
          let p2 = route[route.length() - 1]
          let dx = p2.x - p1.x
          let dy = p2.y - p1.y
          let len = (dx * dx + dy * dy).sqrt()
          if len > 0.001 {
            (dx / len, dy / len)
          } else {
            (1.0, 0.0)
          }
        } else {
          (1.0, 0.0)
        }
        // Try to find a non-overlapping position using grid search
        let mut found = false
        // Increase step size based on number of existing labels to spread them out
        let base_step = config.edge_padding
        let label_count = label_boxes.length()
        // Try positions in expanding circles around midpoint
        for radius in [0, 1, 2, 3, 4, 5] {
          if found {
            break
          }
          // Also try vertical stacking based on label index
          let stack_offset = label_count.to_double() * (label_height + 5.0)
          for perp_mult in [-radius, 0, radius] {
            if found {
              break
            }
            for along_mult in [-radius, 0, radius] {
              if radius == 0 && (perp_mult != 0 || along_mult != 0) {
                continue
              }
              // Try without stack offset first, then with
              for stack in [0.0, stack_offset, -stack_offset] {
                label_x = mid.x -
                  label_width / 2.0 +
                  perp_x * (perp_mult.to_double() * base_step) +
                  edge_dx * (along_mult.to_double() * base_step)
                label_y = mid.y -
                  label_height / 2.0 +
                  perp_y * (perp_mult.to_double() * base_step) +
                  edge_dy * (along_mult.to_double() * base_step) +
                  stack
                label_box = @graph.Box::new(
                  label_x, label_y, label_width, label_height,
                )
                // Check for overlaps with nodes
                let mut overlaps = false
                for node_box in node_boxes {
                  if boxes_overlap(label_box, node_box) {
                    overlaps = true
                    break
                  }
                }
                // Check for overlaps with other labels
                if !overlaps {
                  for other_box in label_boxes {
                    if boxes_overlap(label_box, other_box) {
                      overlaps = true
                      break
                    }
                  }
                }
                if !overlaps {
                  found = true
                  break
                }
              }
              if found {
                break
              }
            }
          }
        }
        // Store the computed label box
        edge.label_box = Some(label_box)
        label_boxes.push(label_box)
      }
      None => ()
    }
  }
}

///|
/// Compute the perpendicular direction to an edge for label offset
fn compute_perpendicular_direction(edge : Edge) -> (Double, Double) {
  let route = edge.route
  if route.length() < 2 {
    return (0.0, 1.0) // Default to vertical offset
  }
  // Get direction at midpoint
  let mid_idx = route.length() / 2
  let p1 = if mid_idx > 0 { route[mid_idx - 1] } else { route[0] }
  let p2 = if mid_idx < route.length() {
    route[mid_idx]
  } else {
    route[mid_idx - 1]
  }
  // Direction vector
  let dx = p2.x - p1.x
  let dy = p2.y - p1.y
  let len = (dx * dx + dy * dy).sqrt()
  if len < 0.001 {
    return (0.0, 1.0) // Fallback
  }
  // Perpendicular direction (rotated 90 degrees)
  let perp_x = -dy / len
  let perp_y = dx / len
  (perp_x, perp_y)
}

///|
/// Check if two boxes overlap (with small margin)
fn boxes_overlap(a : @graph.Box, b : @graph.Box) -> Bool {
  let margin = 2.0
  not(
    a.x + a.width + margin < b.x ||
    b.x + b.width + margin < a.x ||
    a.y + a.height + margin < b.y ||
    b.y + b.height + margin < a.y,
  )
}
