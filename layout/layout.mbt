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
/// Layout engine for D2 diagrams
///
/// Computes positions for objects and routes for edges.

///|
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Layout configuration
pub struct LayoutConfig {
  /// Horizontal spacing between objects
  horizontal_spacing : Double
  /// Vertical spacing between objects
  vertical_spacing : Double
  /// Padding inside containers
  container_padding : Double
  /// Default object width
  default_width : Double
  /// Default object height
  default_height : Double
  /// Edge padding from objects
  edge_padding : Double
} derive(Show)

///|
/// Layout direction
pub(all) enum Direction {
  Down
  Right
  Up
  Left
} derive(Eq, Show)

///|
/// Layout error
pub(all) suberror LayoutError {
  InvalidGraph(String)
  CycleDetected(String)
} derive(Eq, Show)

///|
pub fn LayoutConfig::new() -> LayoutConfig {
  {
    horizontal_spacing: 60.0,
    vertical_spacing: 60.0,
    container_padding: 20.0,
    default_width: 100.0,
    default_height: 60.0,
    edge_padding: 20.0,
  }
}

///|
pub fn LayoutConfig::with_spacing(
  horizontal : Double,
  vertical : Double,
) -> LayoutConfig {
  let config = LayoutConfig::new()
  { ..config, horizontal_spacing: horizontal, vertical_spacing: vertical }
}

///|
/// Perform layout on a graph using ELK algorithms
pub fn layout(
  graph : @graph.Graph,
  config : LayoutConfig,
  direction : Direction,
) -> Unit {
  // Check if root-level is a sequence diagram
  if is_sequence_diagram(graph.root) && graph.root.is_container() {
    // Use sequence layout for the entire graph
    let result = layout_sequence_with_activations(graph.root, graph, config)
    // Store activation boxes in the graph for rendering
    for box in result.activation_boxes {
      graph.activation_boxes.push((box.actor_id, box.get_box()))
    }
    // Store notes in the graph for rendering
    for note in result.notes {
      graph.sequence_notes.push((note.actor_id, note.text, note.bbox))
    }
    // Layout layers, scenarios, and steps recursively
    for layer in graph.layers {
      layout(layer.graph, config, direction)
    }
    for scenario in graph.scenarios {
      layout(scenario.graph, config, direction)
    }
    for step in graph.steps {
      layout(step.graph, config, direction)
    }
    return
  }

  // Phase 1: Compute sizes for all objects first
  compute_sizes(graph, config)

  // Phase 2: Handle special containers (sequence diagrams, grids)
  for obj in graph.objects {
    if is_sequence_diagram(obj) && obj.is_container() {
      let result = layout_sequence_with_activations(obj, graph, config)
      for box in result.activation_boxes {
        graph.activation_boxes.push((box.actor_id, box.get_box()))
      }
      for note in result.notes {
        graph.sequence_notes.push((note.actor_id, note.text, note.bbox))
      }
    } else if obj.is_grid_diagram() && obj.is_container() {
      layout_grid(obj, config)
    }
  }

  // Phase 3: Run ELK layout (handles node positioning and edge routing)
  run_elk_layout(graph, config, direction)

  // Phase 3.5: Fix any overlapping nodes that ELK may have left
  fix_node_overlaps(graph, config)

  // Phase 4: Apply near positioning
  apply_near_positioning(graph, config)

  // Phase 5: Post-processing for edge routes
  // Re-route edges that cross through unrelated nodes
  reroute_crossing_edges(graph)
  // Normalize coordinates to non-negative
  normalize_coordinates(graph)
  // Optimize edge routes by removing unnecessary bends (before perpendicularity fixes)
  eliminate_unnecessary_bends(graph)
  // Perpendicularity fix
  fix_perpendicularity(graph)
  // Clean up any S-shapes or redundant points created by perpendicularity fix
  eliminate_unnecessary_bends(graph)
  // Separate parallel edges (bidirectional duplicates)
  separate_parallel_edges(graph)
  // Fix perpendicularity again after separation
  fix_perpendicularity(graph)
  // Final cleanup
  eliminate_unnecessary_bends(graph)

  // Phase 6: Position edge labels to avoid overlaps
  position_edge_labels(graph, config)

  // Phase 7: Layout layers, scenarios, and steps recursively
  for layer in graph.layers {
    layout(layer.graph, config, direction)
  }
  for scenario in graph.scenarios {
    layout(scenario.graph, config, direction)
  }
  for step in graph.steps {
    layout(step.graph, config, direction)
  }
}

///|
/// Compute sizes for all objects
fn compute_sizes(graph : @graph.Graph, config : LayoutConfig) -> Unit {
  for obj in graph.objects {
    compute_object_size(obj, config)
  }
}

///|
/// Compute size for a single object
fn compute_object_size(obj : @graph.Object, config : LayoutConfig) -> Unit {
  // SQL tables use compact row-based sizing (not container spacing)
  if obj.shape_type == @graph.SqlTable {
    let line_height = 18.0 // font_size (14) + 4
    let padding = 8.0
    let header_height = line_height + padding // 26
    let columns_height = obj.children.length().to_double() * line_height +
      padding
    let total_height = header_height + columns_height
    // Width: max of label and column labels
    let mut max_width = estimate_label_width(obj.label, config)
    for child in obj.children {
      let col_width = estimate_label_width(child.label, config)
      if col_width > max_width {
        max_width = col_width
      }
    }
    obj.set_box(@graph.Box::new(0.0, 0.0, max_width, total_height))
  } else if obj.is_container() {
    // Container: compute based on children
    let mut max_width = 0.0
    let mut total_height = 0.0
    for child in obj.children {
      compute_object_size(child, config)
      match child.box {
        Some(b) => {
          if b.width > max_width {
            max_width = b.width
          }
          total_height = total_height + b.height + config.vertical_spacing
        }
        None => ()
      }
    }
    // Remove last spacing
    if total_height > 0.0 {
      total_height = total_height - config.vertical_spacing
    }
    // Add padding
    let width = max_width + config.container_padding * 2.0
    let height = total_height + config.container_padding * 2.0
    obj.set_box(
      @graph.Box::new(
        0.0,
        0.0,
        max(width, config.default_width),
        max(height, config.default_height),
      ),
    )
  } else {
    // Leaf node: use default size or compute from label
    let width = estimate_label_width(obj.label, config)
    let height = config.default_height
    obj.set_box(@graph.Box::new(0.0, 0.0, width, height))
  }
}

///|
/// Estimate width needed for a label
fn estimate_label_width(label : String, config : LayoutConfig) -> Double {
  // Simple estimation: 8 pixels per character + padding
  let char_width = 8.0
  let padding = 20.0
  let width = label.length().to_double() * char_width + padding
  max(width, config.default_width)
}

///|
/// Find objects that are not children of any other object
fn find_root_objects(graph : @graph.Graph) -> Array[@graph.Object] {
  let child_ids : Array[String] = []
  for obj in graph.objects {
    for child in obj.children {
      child_ids.push(child.id)
    }
  }
  let roots : Array[@graph.Object] = []
  for obj in graph.objects {
    if not(child_ids.contains(obj.id)) {
      roots.push(obj)
    }
  }
  roots
}

///|
/// Get the connection point for a specific anchor position on a box
fn get_anchor_point(
  box : @graph.Box,
  anchor : String,
  offset : Double,
) -> @graph.Point {
  let cx = box.center().get_x()
  let cy = box.center().get_y()
  match anchor.to_lower() {
    "top" => @graph.Point::new(cx + offset, box.y)
    "bottom" => @graph.Point::new(cx + offset, box.y + box.height)
    "left" => @graph.Point::new(box.x, cy + offset)
    "right" => @graph.Point::new(box.x + box.width, cy + offset)
    "center" => @graph.Point::new(cx + offset, cy)
    "top-left" => @graph.Point::new(box.x, box.y)
    "top-right" => @graph.Point::new(box.x + box.width, box.y)
    "bottom-left" => @graph.Point::new(box.x, box.y + box.height)
    "bottom-right" => @graph.Point::new(box.x + box.width, box.y + box.height)
    _ => @graph.Point::new(cx + offset, cy) // Default to center
  }
}

///|
/// Get parent ID from a dotted field ID (e.g., "users.id" -> "users")
fn get_parent_id_from_field(id : String) -> String? {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot <= 0 {
    return None
  }
  let buf = StringBuilder::new()
  for i = 0; i < last_dot; i = i + 1 {
    buf.write_char(id[i].to_int().unsafe_to_char())
  }
  Some(buf.to_string())
}

///|
/// Get the anchor point for a SQL table row connection
/// column_index is 0-based, the y-position matches SVG renderer's calculation
fn get_sql_row_anchor_point(
  table_box : @graph.Box,
  column_index : Int,
  _num_columns : Int,
  is_left_side : Bool,
) -> @graph.Point {
  // Match the SVG renderer's calculation in svg_render.mbt:
  // - line_height = font_size + 4.0 (default font_size = 14, so line_height = 18)
  // - header_height = line_height + padding = 18 + 8 = 26
  // - row text y = box.y + header_height + line_height * 0.7 + line_height * i
  // For edge connection, use the same y as the row text (which is centered)
  let line_height = 18.0 // font_size (14) + 4
  let header_height = 26.0 // line_height + padding (8)
  let row_center_y = table_box.y +
    header_height +
    line_height * (column_index.to_double() + 0.7)
  // Return exact edge position - extend_edge_endpoints will add outward extension
  let x = if is_left_side { table_box.x } else { table_box.x + table_box.width }
  @graph.Point::new(x, row_center_y)
}

///|
/// Calculate the best anchor points for an edge based on relative box positions.
/// Returns (src_anchor, dst_anchor) strings.
///
/// IMPORTANT: The dst_anchor is chosen based on the direction from src_point to
/// dst_center (not center-to-center). This ensures the approach direction matches
/// the anchor side (required by edge_connects_to_correct_side constraint).
fn calculate_best_anchors(
  src_box : @graph.Box,
  dst_box : @graph.Box,
) -> (String, String) {
  let src_cx = src_box.center().get_x()
  let src_cy = src_box.center().get_y()
  let dst_cx = dst_box.center().get_x()
  let dst_cy = dst_box.center().get_y()
  let dx_center = dst_cx - src_cx
  let dy_center = dst_cy - src_cy
  // Step 1: Pick src_anchor based on center-to-center direction
  let src_anchor = if dy_center.abs() >= dx_center.abs() {
    if dy_center > 0.0 {
      "bottom"
    } else {
      "top"
    }
  } else if dx_center > 0.0 {
    "right"
  } else {
    "left"
  }
  // Step 2: Calculate src_point
  let src_point = get_anchor_point(src_box, src_anchor, 0.0)
  // Step 3: Pick dst_anchor based on direction from src_point to dst_center
  // This ensures the final segment approaches from the correct direction
  let dx_to_dst = dst_cx - src_point.x
  let dy_to_dst = dst_cy - src_point.y
  let dst_anchor = if dy_to_dst.abs() >= dx_to_dst.abs() {
    // Approach is more vertical
    if dy_to_dst > 0.0 {
      "top" // Approaching from above (going down) → connect to top
    } else {
      "bottom" // Approaching from below (going up) → connect to bottom
    }
    // Approach is more horizontal
  } else if dx_to_dst > 0.0 {
    "left" // Approaching from left (going right) → connect to left
  } else {
    "right" // Approaching from right (going left) → connect to right
  }
  (src_anchor, dst_anchor)
}

///|
/// Find where a line from center to target intersects the box edge
pub fn find_edge_intersection(
  box : @graph.Box,
  center : @graph.Point,
  target : @graph.Point,
) -> @graph.Point {
  let dx = target.x - center.x
  let dy = target.y - center.y
  if dx == 0.0 && dy == 0.0 {
    return center
  }
  // Calculate intersection with each edge
  let half_width = box.width / 2.0
  let half_height = box.height / 2.0
  // Scale factors for intersection with each edge
  let mut t = 1.0
  if dx != 0.0 {
    let tx = if dx > 0.0 { half_width / dx } else { -half_width / dx }
    if tx < t {
      t = tx
    }
  }
  if dy != 0.0 {
    let ty = if dy > 0.0 { half_height / dy } else { -half_height / dy }
    if ty < t {
      t = ty
    }
  }
  @graph.Point::new(center.x + dx * t, center.y + dy * t)
}

///|
/// Fix any overlapping nodes left by the ELK layout algorithm
fn fix_node_overlaps(graph : @graph.Graph, config : LayoutConfig) -> Unit {
  let objects = graph.get_objects()
  let min_spacing = config.horizontal_spacing

  // Keep fixing until no overlaps remain (may need multiple passes)
  let mut changed = true
  let mut iterations = 0
  let max_iterations = objects.length() * 2 // Safety limit
  while changed && iterations < max_iterations {
    changed = false
    iterations += 1

    // Check all pairs for overlaps
    for i in 0..<objects.length() {
      for j in (i + 1)..<objects.length() {
        let obj1 = objects[i]
        let obj2 = objects[j]

        // Skip if either object has no box
        guard obj1.box is Some(box1) else { continue }
        guard obj2.box is Some(box2) else { continue }

        // Skip children of containers
        if is_child_of_obj(obj1, obj2) || is_child_of_obj(obj2, obj1) {
          continue
        }

        // Check if boxes overlap
        if box1.intersects(box2) {
          // Determine which direction to separate
          // Push the object with larger x/y value further away
          let dx = box2.x - box1.x
          let dy = box2.y - box1.y
          if dy.abs() > dx.abs() {
            // Overlapping more horizontally - separate vertically
            if dy >= 0.0 {
              // obj2 is below obj1 - push obj2 down
              let new_y = box1.y + box1.height + min_spacing
              obj2.set_box(
                @graph.Box::new(box2.x, new_y, box2.width, box2.height),
              )
            } else {
              // obj2 is above obj1 - push obj1 down
              let new_y = box2.y + box2.height + min_spacing
              obj1.set_box(
                @graph.Box::new(box1.x, new_y, box1.width, box1.height),
              )
            }
            // Overlapping more vertically - separate horizontally
          } else if dx >= 0.0 {
            // obj2 is to the right of obj1 - push obj2 right
            let new_x = box1.x + box1.width + min_spacing
            obj2.set_box(
              @graph.Box::new(new_x, box2.y, box2.width, box2.height),
            )
          } else {
            // obj2 is to the left of obj1 - push obj1 right
            let new_x = box2.x + box2.width + min_spacing
            obj1.set_box(
              @graph.Box::new(new_x, box1.y, box1.width, box1.height),
            )
          }
          changed = true
        }
      }
    }
  }
}

///|
/// Check if obj1 is a child of obj2 (helper for overlap fix)
fn is_child_of_obj(obj1 : @graph.Object, obj2 : @graph.Object) -> Bool {
  for child in obj2.children {
    if child.id == obj1.id {
      return true
    }
    if is_child_of_obj(obj1, child) {
      return true
    }
  }
  false
}
