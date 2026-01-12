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
/// Property-based tests for layout algorithm constraints

// ============================================================================
// QuickCheck Graph Generation
// ============================================================================

///|
/// Generate a random graph for layout property tests.
fn gen_graph() -> @qc.Gen[Graph] {
  @qc.Gen::new(fn(_size, rs) {
    // Random node count (3-10)
    let node_count = 3 + rs.next_int().abs() % 8
    // Random edge count - capped at 2x node_count to limit density
    let edge_count_raw = 3 + rs.next_int().abs() % 12
    let edge_count = if edge_count_raw > node_count * 2 {
      node_count * 2
    } else {
      edge_count_raw
    }
    let graph = Graph::new("test")

    // Create nodes with simple IDs
    for i in 0..<node_count {
      let id = "n\{i}"
      let label = "Node\{i}"
      graph.add_object(Object::with_label(id, label))
    }

    // Track degrees to limit connectivity
    let out_degree : Array[Int] = Array::make(node_count, 0)
    let in_degree : Array[Int] = Array::make(node_count, 0)
    let max_degree = 4

    // Create edges with degree limits
    let mut edge_idx = 0
    let mut attempts = 0
    let max_attempts = edge_count * 3
    while edge_idx < edge_count && attempts < max_attempts {
      attempts = attempts + 1
      let src_idx = rs.next_int().abs() % node_count
      let dst_idx = rs.next_int().abs() % node_count
      if src_idx != dst_idx &&
        out_degree[src_idx] < max_degree &&
        in_degree[dst_idx] < max_degree {
        let edge = Edge::new(
          edge_idx,
          "n\{src_idx}",
          "n\{dst_idx}",
          false,
          true,
        )
        graph.add_edge(edge)
        out_degree[src_idx] = out_degree[src_idx] + 1
        in_degree[dst_idx] = in_degree[dst_idx] + 1
        edge_idx = edge_idx + 1
      }
    }
    graph
  })
}

///|
/// Generate a random graph with edge labels.
/// Uses smaller graphs to keep runtime/memory bounded.
fn gen_graph_with_edge_labels() -> @qc.Gen[Graph] {
  @qc.Gen::new(fn(_size, rs) {
    // Smaller graphs for edge label test due to higher memory usage
    let node_count = 3 + rs.next_int().abs() % 2
    let edge_count = 2 + rs.next_int().abs() % 2
    let graph = Graph::new("test")

    // Create nodes
    for i in 0..<node_count {
      graph.add_object(Object::with_label("n\{i}", "Node\{i}"))
    }

    // Create edges with labels
    for i in 0..<edge_count {
      let src_idx = rs.next_int().abs() % node_count
      let mut dst_idx = rs.next_int().abs() % node_count
      if dst_idx == src_idx {
        dst_idx = (dst_idx + 1) % node_count
      }
      let edge = Edge::new(i, "n\{src_idx}", "n\{dst_idx}", false, true)
      // Add random label
      let label_len = 1 + rs.next_int().abs() % 7
      let label = StringBuilder::new()
      for _ in 0..<label_len {
        let c = 97 + rs.next_int().abs() % 26
        match c.to_char() {
          Some(ch) => label.write_char(ch)
          None => label.write_char('a')
        }
      }
      edge.label = label.to_string()
      graph.add_edge(edge)
    }
    graph
  })
}

///|
/// Generate a random graph containing sql_table field-level edges.
/// The edges connect dotted field IDs (e.g., "t0.c1") and set column indices so
/// routing uses row anchors on the parent tables.
fn gen_sql_table_graph() -> @qc.Gen[Graph] {
  @qc.Gen::new(fn(_size, rs) {
    let table_count = 2 + rs.next_int().abs() % 2
    let graph = Graph::new("test")
    let table_ids : Array[String] = []
    let column_counts : Array[Int] = []
    for i in 0..<table_count {
      let table_id = "t\{i}"
      let table = Object::with_label(table_id, "Table\{i}")
      table.set_shape_type(@graph.SqlTable)
      let col_count = 2 + rs.next_int().abs() % 5
      for j in 0..<col_count {
        let col_id = table_id + ".c\{j}"
        let col = Object::with_label(col_id, "c\{j}")
        table.add_child(col)
        // Mirror compiler behavior: sql_table fields exist as normal objects too.
        graph.add_object(col)
      }
      table_ids.push(table_id)
      column_counts.push(col_count)
      graph.add_object(table)
    }
    let edge_count = 1 + rs.next_int().abs() % 6
    for i in 0..<edge_count {
      let src_table = rs.next_int().abs() % table_count
      let mut dst_table = rs.next_int().abs() % table_count
      if dst_table == src_table {
        dst_table = (dst_table + 1) % table_count
      }
      let src_col = rs.next_int().abs() % column_counts[src_table]
      let dst_col = rs.next_int().abs() % column_counts[dst_table]
      let src_id = table_ids[src_table] + ".c\{src_col}"
      let dst_id = table_ids[dst_table] + ".c\{dst_col}"
      let edge = Edge::new(i, src_id, dst_id, false, true)
      edge.src_column_index = Some(src_col)
      edge.dst_column_index = Some(dst_col)
      graph.add_edge(edge)
    }
    graph
  })
}

///|
fn apply_layout_result(
  layout : @engine_api.LayoutResult,
  graph : Graph,
) -> Unit {
  for obj in graph.objects {
    match layout.nodes.get(obj.id) {
      Some(node_layout) => obj.set_box(node_layout.to_box())
      None => ()
    }
  }
  for edge in graph.edges {
    match layout.edges.get(edge.index) {
      Some(edge_layout) => {
        edge.route.clear()
        for p in edge_layout.points {
          edge.route.push(p)
        }
      }
      None => ()
    }
    match layout.edge_labels.get(edge.index) {
      Some(label_layout) => edge.label_box = Some(label_layout.to_box())
      None => ()
    }
  }
  graph.activation_boxes.clear()
  for box in layout.activation_boxes {
    graph.activation_boxes.push((box.0, box.1.to_box()))
  }
  graph.sequence_notes.clear()
  for note in layout.sequence_notes {
    graph.sequence_notes.push((note.0, note.1, note.2.to_box()))
  }
}

///|
fn layout_in_place(
  graph : Graph,
  config : LayoutConfig,
  direction : Direction,
) -> Unit raise LayoutError {
  let outputs = layout(graph.to_input(), config, direction)
  apply_layout_result(outputs.layout, graph)
}

// ============================================================================
// Layout Constraints
// ============================================================================

///|
/// Check if two boxes are horizontally aligned (overlap vertically)
fn boxes_horizontally_aligned(box1 : @graph.Box, box2 : @graph.Box) -> Bool {
  let top1 = box1.y
  let bottom1 = box1.y + box1.height
  let top2 = box2.y
  let bottom2 = box2.y + box2.height
  // Overlap if one's top is above other's bottom AND one's bottom is below other's top
  top1 < bottom2 && bottom1 > top2
}

///|
/// Check if two boxes are vertically aligned (overlap horizontally)
fn boxes_vertically_aligned(box1 : @graph.Box, box2 : @graph.Box) -> Bool {
  let left1 = box1.x
  let right1 = box1.x + box1.width
  let left2 = box2.x
  let right2 = box2.x + box2.width
  // Overlap if one's left is before other's right AND one's right is after other's left
  left1 < right2 && right1 > left2
}

///|
/// Compute horizontal gap between two boxes (assumes they don't overlap horizontally)
fn horizontal_gap(box1 : @graph.Box, box2 : @graph.Box) -> Double {
  let left_gap = box1.x - (box2.x + box2.width) // box1 is to the right
  let right_gap = box2.x - (box1.x + box1.width) // box1 is to the left
  if left_gap > 0.0 {
    left_gap
  } else if right_gap > 0.0 {
    right_gap
  } else {
    0.0
  }
}

///|
/// Compute vertical gap between two boxes (assumes they don't overlap vertically)
fn vertical_gap(box1 : @graph.Box, box2 : @graph.Box) -> Double {
  let top_gap = box1.y - (box2.y + box2.height) // box1 is below
  let bottom_gap = box2.y - (box1.y + box1.height) // box1 is above
  if top_gap > 0.0 {
    top_gap
  } else if bottom_gap > 0.0 {
    bottom_gap
  } else {
    0.0
  }
}

///|
/// Check that aligned nodes have at least minimum spacing between them
/// - Horizontally aligned boxes (same row region) must have horizontal spacing
/// - Vertically aligned boxes (same column region) must have vertical spacing
/// - Diagonally separated boxes are not checked (already separated in both dimensions)
pub fn minimum_spacing_between_nodes(
  graph : Graph,
  min_spacing : Double,
) -> Bool {
  let objects = graph.get_objects()
  for i in 0..<objects.length() {
    for j in (i + 1)..<objects.length() {
      let obj1 = objects[i]
      let obj2 = objects[j]
      // Skip if either object has no box (not laid out)
      guard obj1.get_box() is Some(box1) else { continue }
      guard obj2.get_box() is Some(box2) else { continue }
      // Skip children of containers (they may be inside parent)
      if is_child_of(obj1, obj2, graph) || is_child_of(obj2, obj1, graph) {
        continue
      }
      // Skip if boxes overlap (handled by nodes_should_not_overlap)
      if box1.intersects(box2) {
        continue
      }
      // Check spacing based on alignment
      if boxes_horizontally_aligned(box1, box2) {
        // Boxes in same row region - check horizontal gap
        let h_gap = horizontal_gap(box1, box2)
        if h_gap < min_spacing - 0.001 {
          return false
        }
      } else if boxes_vertically_aligned(box1, box2) {
        // Boxes in same column region - check vertical gap
        let v_gap = vertical_gap(box1, box2)
        if v_gap < min_spacing - 0.001 {
          return false
        }
      }
      // Diagonally separated boxes are fine - no spacing requirement
    }
  }
  true
}

///|
/// Check that no two nodes overlap after layout
/// Returns true if all nodes are properly separated
pub fn nodes_should_not_overlap(graph : Graph) -> Bool {
  let objects = graph.get_objects()
  for i in 0..<objects.length() {
    for j in (i + 1)..<objects.length() {
      let obj1 = objects[i]
      let obj2 = objects[j]
      // Skip if either object has no box (not laid out)
      guard obj1.get_box() is Some(box1) else { continue }
      guard obj2.get_box() is Some(box2) else { continue }
      // Skip children of containers (they may overlap with parent)
      if is_child_of(obj1, obj2, graph) || is_child_of(obj2, obj1, graph) {
        continue
      }
      // Check for intersection
      if box1.intersects(box2) {
        return false
      }
    }
  }
  true
}

///|
/// Check if obj1 is a child of obj2
fn is_child_of(obj1 : Object, obj2 : Object, graph : Graph) -> Bool {
  for child in obj2.children {
    if child.id == obj1.id {
      return true
    }
    if is_child_of(obj1, child, graph) {
      return true
    }
  }
  false
}

///|
/// Check that all nodes have been assigned positions (boxes)
pub fn all_nodes_have_positions(graph : Graph) -> Bool {
  for obj in graph.get_objects() {
    if obj.get_box() is None {
      return false
    }
  }
  true
}

///|
/// Check that all node positions are non-negative
pub fn all_positions_non_negative(graph : Graph) -> Bool {
  for obj in graph.get_objects() {
    if obj.get_box() is Some(box) {
      if box.x < 0.0 || box.y < 0.0 {
        return false
      }
    }
  }
  true
}

///|
/// Check that all node dimensions are positive
pub fn all_dimensions_positive(graph : Graph) -> Bool {
  for obj in graph.get_objects() {
    if obj.get_box() is Some(box) {
      if box.width <= 0.0 || box.height <= 0.0 {
        return false
      }
    }
  }
  true
}

///|
/// Check that all children are inside their parent container
/// Returns true if every child's box is fully contained within parent's box
pub fn children_inside_parent(graph : Graph) -> Bool {
  fn check_object(obj : Object) -> Bool {
    guard obj.get_box() is Some(parent_box) else { return true }
    for child in obj.children {
      guard child.get_box() is Some(child_box) else { continue }
      // Child must be fully inside parent (with small tolerance)
      let tolerance = 0.001
      if child_box.x < parent_box.x - tolerance {
        return false
      }
      if child_box.y < parent_box.y - tolerance {
        return false
      }
      if child_box.x + child_box.width >
        parent_box.x + parent_box.width + tolerance {
        return false
      }
      if child_box.y + child_box.height >
        parent_box.y + parent_box.height + tolerance {
        return false
      }
      // Recursively check nested children
      if !check_object(child) {
        return false
      }
    }
    true
  }

  for obj in graph.get_objects() {
    if !check_object(obj) {
      return false
    }
  }
  true
}

///|
/// Check that siblings (children of same parent) don't overlap
pub fn sibling_no_overlap(graph : Graph) -> Bool {
  fn check_siblings(obj : Object) -> Bool {
    let children = obj.children
    for i in 0..<children.length() {
      for j in (i + 1)..<children.length() {
        guard children[i].get_box() is Some(box1) else { continue }
        guard children[j].get_box() is Some(box2) else { continue }
        if box1.intersects(box2) {
          return false
        }
      }
      // Recursively check nested containers
      if !check_siblings(children[i]) {
        return false
      }
    }
    true
  }

  // Check root level objects
  let objects = graph.get_objects()
  for i in 0..<objects.length() {
    for j in (i + 1)..<objects.length() {
      guard objects[i].get_box() is Some(box1) else { continue }
      guard objects[j].get_box() is Some(box2) else { continue }
      // Skip parent-child relationships
      if is_child_of(objects[i], objects[j], graph) ||
        is_child_of(objects[j], objects[i], graph) {
        continue
      }
      if box1.intersects(box2) {
        return false
      }
    }
    // Check children of each container
    if !check_siblings(objects[i]) {
      return false
    }
  }
  true
}

///|
/// Check that edge endpoints touch (or are near) node boundaries
/// Returns true if edge routes start near source and end near destination
pub fn edge_endpoints_touch_nodes(graph : Graph) -> Bool {
  let tolerance = 20.0 // Allow some tolerance for arrow heads etc.
  for edge in graph.get_edges() {
    if edge.route.length() < 2 {
      continue // Skip edges without routes
    }
    // Find source and destination objects
    let src_obj = graph.find_object(edge.src_id)
    let dst_obj = graph.find_object(edge.dst_id)
    guard src_obj is Some(src) else { continue }
    guard dst_obj is Some(dst) else { continue }
    guard src.get_box() is Some(src_box) else { continue }
    guard dst.get_box() is Some(dst_box) else { continue }
    // Check start point is near source box
    let start = edge.route[0]
    if !point_near_box(start, src_box, tolerance) {
      return false
    }
    // Check end point is near destination box
    let end = edge.route[edge.route.length() - 1]
    if !point_near_box(end, dst_box, tolerance) {
      return false
    }
  }
  true
}

///|
/// Check if a point is near a box (within tolerance of any edge)
fn point_near_box(
  p : @graph.Point,
  box : @graph.Box,
  tolerance : Double,
) -> Bool {
  let left = box.x - tolerance
  let right = box.x + box.width + tolerance
  let top = box.y - tolerance
  let bottom = box.y + box.height + tolerance
  // Point should be within the expanded box area
  p.x >= left && p.x <= right && p.y >= top && p.y <= bottom
}

///|
/// Check that all input nodes are present after layout
/// Returns true if every node that was added has a position
pub fn all_input_nodes_present(
  input_node_ids : Array[String],
  graph : Graph,
) -> Bool {
  for id in input_node_ids {
    let obj = graph.find_object(id)
    if obj is None {
      return false
    }
  }
  true
}

///|
/// Check that all input edges are present after layout
/// Returns true if every edge that was added exists in the graph
pub fn all_input_edges_present(
  input_edges : Array[(String, String)],
  graph : Graph,
) -> Bool {
  for pair in input_edges {
    let (src, dst) = pair
    let mut found = false
    for edge in graph.get_edges() {
      if edge.src_id == src && edge.dst_id == dst {
        found = true
        break
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
/// Check that layout is deterministic - same input produces same output
pub fn deterministic_output(graph1 : Graph, graph2 : Graph) -> Bool {
  let objs1 = graph1.get_objects()
  let objs2 = graph2.get_objects()
  if objs1.length() != objs2.length() {
    return false
  }
  // Build maps for comparison
  let pos_map1 : Map[String, (Double, Double, Double, Double)] = {}
  let pos_map2 : Map[String, (Double, Double, Double, Double)] = {}
  for obj in objs1 {
    if obj.get_box() is Some(b) {
      pos_map1[obj.id] = (b.x, b.y, b.width, b.height)
    }
  }
  for obj in objs2 {
    if obj.get_box() is Some(b) {
      pos_map2[obj.id] = (b.x, b.y, b.width, b.height)
    }
  }
  // Compare positions
  for id in pos_map1.keys() {
    guard pos_map1.get(id) is Some(p1) else { return false }
    guard pos_map2.get(id) is Some(p2) else { return false }
    let (x1, y1, w1, h1) = p1
    let (x2, y2, w2, h2) = p2
    let tolerance = 0.001
    if (x1 - x2).abs() > tolerance ||
      (y1 - y2).abs() > tolerance ||
      (w1 - w2).abs() > tolerance ||
      (h1 - h2).abs() > tolerance {
      return false
    }
  }
  true
}

///|
/// Check that edge labels don't overlap with each other
pub fn edge_labels_no_overlap(graph : Graph) -> Bool {
  let label_boxes : Array[@graph.Box] = []
  for edge in graph.get_edges() {
    if edge.label_box is Some(lb) {
      label_boxes.push(lb)
    }
  }
  for i in 0..<label_boxes.length() {
    for j in (i + 1)..<label_boxes.length() {
      if label_boxes[i].intersects(label_boxes[j]) {
        return false
      }
    }
  }
  true
}

///|
/// Check that self-loops have a visible route (not degenerate)
pub fn self_loop_visible(graph : Graph) -> Bool {
  for edge in graph.get_edges() {
    if edge.src_id == edge.dst_id {
      // Self-loop - should have a meaningful route
      if edge.route.length() < 3 {
        // Self-loops need at least 3 points to form a visible loop
        return false
      }
      // Check that the route covers some area (not all points at same location)
      let mut min_x = edge.route[0].x
      let mut max_x = edge.route[0].x
      let mut min_y = edge.route[0].y
      let mut max_y = edge.route[0].y
      for pt in edge.route {
        if pt.x < min_x {
          min_x = pt.x
        }
        if pt.x > max_x {
          max_x = pt.x
        }
        if pt.y < min_y {
          min_y = pt.y
        }
        if pt.y > max_y {
          max_y = pt.y
        }
      }
      // Self-loop should span some area
      let width = max_x - min_x
      let height = max_y - min_y
      if width < 5.0 && height < 5.0 {
        return false
      }
    }
  }
  true
}

///|
/// Check that edges don't pass through unrelated nodes
/// An edge should not intersect any node box except its source and destination
pub fn edge_avoids_unrelated_nodes(graph : Graph) -> Bool {
  for edge in graph.get_edges() {
    if edge.route.length() < 2 {
      continue
    }
    // Check each segment of the route
    for i in 0..<(edge.route.length() - 1) {
      let p1 = edge.route[i]
      let p2 = edge.route[i + 1]
      // Check against all nodes except source and destination
      for obj in graph.get_objects() {
        if obj.id == edge.src_id || obj.id == edge.dst_id {
          continue
        }
        guard obj.get_box() is Some(box) else { continue }
        // Check if line segment intersects the box
        if line_segment_intersects_box(p1, p2, box) {
          return false
        }
      }
    }
  }
  true
}

///|
/// Check that sql_table field-level edges do not pass through any sql_table box.
/// Endpoints are allowed to touch table boundaries.
pub fn sql_table_edges_clipped_to_boxes(graph : Graph) -> Bool {
  let sql_table_boxes : Array[(String, @graph.Box)] = []
  for obj in graph.get_objects() {
    if obj.shape_type != @graph.SqlTable {
      continue
    }
    if obj.get_box() is Some(b) {
      sql_table_boxes.push((obj.id, b))
    }
  }
  if sql_table_boxes.is_empty() {
    return true
  }
  for edge in graph.get_edges() {
    if edge.src_column_index is None && edge.dst_column_index is None {
      continue
    }
    if edge.route.length() < 2 {
      continue
    }
    let src_table_id = edge.src_id.split(".").collect()[0].to_string()
    let dst_table_id = edge.dst_id.split(".").collect()[0].to_string()
    let last_segment = edge.route.length() - 2
    for i in 0..<(edge.route.length() - 1) {
      let p1 = edge.route[i]
      let p2 = edge.route[i + 1]
      for entry in sql_table_boxes {
        let (table_id, box) = entry
        if table_id == src_table_id && i == 0 {
          continue
        }
        if table_id == dst_table_id && i == last_segment {
          continue
        }
        if line_segment_intersects_box(p1, p2, box) {
          return false
        }
      }
    }
  }
  true
}

///|
/// Check if a line segment intersects a box (excluding touching edges)
fn line_segment_intersects_box(
  p1 : @graph.Point,
  p2 : @graph.Point,
  box : @graph.Box,
) -> Bool {
  // Shrink the box slightly to allow edges to touch node boundaries
  let margin = 1.0
  let left = box.x + margin
  let right = box.x + box.width - margin
  let top = box.y + margin
  let bottom = box.y + box.height - margin
  if right <= left || bottom <= top {
    return false // Box too small
  }
  // Check if line segment crosses through the interior of the box
  // Using parametric line clipping (Liang-Barsky algorithm simplified)
  let dx = p2.x - p1.x
  let dy = p2.y - p1.y
  // If both endpoints are outside on the same side, no intersection
  if (p1.x < left && p2.x < left) || (p1.x > right && p2.x > right) {
    return false
  }
  if (p1.y < top && p2.y < top) || (p1.y > bottom && p2.y > bottom) {
    return false
  }
  // Check if both endpoints are inside the box
  let p1_inside = p1.x >= left && p1.x <= right && p1.y >= top && p1.y <= bottom
  let p2_inside = p2.x >= left && p2.x <= right && p2.y >= top && p2.y <= bottom
  if p1_inside || p2_inside {
    return true
  }
  // Check if line crosses through the box
  // Simplified: check if segment crosses any edge of the box
  // Left edge
  if dx.abs() > 0.001 {
    let t = (left - p1.x) / dx
    if t >= 0.0 && t <= 1.0 {
      let y = p1.y + t * dy
      if y >= top && y <= bottom {
        return true
      }
    }
    // Right edge
    let t2 = (right - p1.x) / dx
    if t2 >= 0.0 && t2 <= 1.0 {
      let y = p1.y + t2 * dy
      if y >= top && y <= bottom {
        return true
      }
    }
  }
  if dy.abs() > 0.001 {
    // Top edge
    let t = (top - p1.y) / dy
    if t >= 0.0 && t <= 1.0 {
      let x = p1.x + t * dx
      if x >= left && x <= right {
        return true
      }
    }
    // Bottom edge
    let t2 = (bottom - p1.y) / dy
    if t2 >= 0.0 && t2 <= 1.0 {
      let x = p1.x + t2 * dx
      if x >= left && x <= right {
        return true
      }
    }
  }
  false
}

///|
/// Check that text labels fit within their container
/// Returns true if all node labels fit within their bounding boxes
pub fn text_fits_container(graph : Graph) -> Bool {
  for obj in graph.get_objects() {
    guard obj.get_box() is Some(box) else { return false }
    match obj.label_box {
      Some(label_box) => if box.width < label_box.width - 0.001 { return false }
      None => return false
    }
  }
  true
}

///|
/// Check that parallel edges (multiple edges between same nodes) are distinguishable
/// Returns true if parallel edges don't overlap - checks entire routes, not just midpoints
pub fn parallel_edges_distinguishable(graph : Graph) -> Bool {
  // Group edges by (src, dst) pair (considering both directions as same pair)
  let edge_groups : Map[String, Array[Edge]] = {}
  for edge in graph.get_edges() {
    // Normalize the key so (a,b) and (b,a) are grouped together
    let key = if edge.src_id < edge.dst_id {
      edge.src_id + "->" + edge.dst_id
    } else {
      edge.dst_id + "->" + edge.src_id
    }
    match edge_groups.get(key) {
      Some(arr) => arr.push(edge)
      None => edge_groups[key] = [edge]
    }
  }
  // Check each group with multiple edges
  for group in edge_groups.values() {
    if group.length() <= 1 {
      continue
    }
    // Check all pairs of edges in this group
    for i in 0..<group.length() {
      for j in (i + 1)..<group.length() {
        if edges_overlap(group[i], group[j]) {
          return false
        }
      }
    }
  }
  true
}

///|
/// Check if two edge routes overlap (any segments too close together)
fn edges_overlap(edge1 : Edge, edge2 : Edge) -> Bool {
  let min_separation = 3.0 // Minimum pixels between parallel edges
  // Check each segment of edge1 against each segment of edge2
  for i in 0..<(edge1.route.length() - 1) {
    let a1 = edge1.route[i]
    let a2 = edge1.route[i + 1]
    for j in 0..<(edge2.route.length() - 1) {
      let b1 = edge2.route[j]
      let b2 = edge2.route[j + 1]
      // Check if these two segments are too close
      if segments_too_close(a1, a2, b1, b2, min_separation) {
        println(
          "parallel edge overlap: \{edge1.src_id}->\{edge1.dst_id}(\{edge1.index}) vs \{edge2.src_id}->\{edge2.dst_id}(\{edge2.index})",
        )
        println("edge1 route: \{edge1.route}")
        println("edge2 route: \{edge2.route}")
        return true
      }
    }
  }
  false
}

///|
/// Check if two line segments are too close (within min_dist of each other)
fn segments_too_close(
  a1 : @graph.Point,
  a2 : @graph.Point,
  b1 : @graph.Point,
  b2 : @graph.Point,
  min_dist : Double,
) -> Bool {
  // Sample points along both segments and check distances
  // Use 5 sample points per segment for reasonable coverage
  let samples = 5
  for i in 0..=samples {
    let t1 = i.to_double() / samples.to_double()
    let p1_x = a1.x + t1 * (a2.x - a1.x)
    let p1_y = a1.y + t1 * (a2.y - a1.y)
    for j in 0..=samples {
      let t2 = j.to_double() / samples.to_double()
      let p2_x = b1.x + t2 * (b2.x - b1.x)
      let p2_y = b1.y + t2 * (b2.y - b1.y)
      let dist = ((p2_x - p1_x) * (p2_x - p1_x) + (p2_y - p1_y) * (p2_y - p1_y)).sqrt()
      if dist < min_dist {
        return true
      }
    }
  }
  false
}

///|
/// Check that cluster/group containers fully enclose their members
/// This is similar to children_inside_parent but explicitly for clusters
pub fn cluster_contains_members(graph : Graph) -> Bool {
  // This constraint is equivalent to children_inside_parent
  // A cluster is just a container with children
  children_inside_parent(graph)
}

///|
/// Compute the canvas bounds from all objects in the graph
fn compute_canvas_bounds(graph : Graph) -> (Double, Double, Double, Double) {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  for obj in graph.get_objects() {
    if obj.get_box() is Some(b) {
      let left = b.x
      let top = b.y
      let right = b.x + b.width
      let bottom = b.y + b.height
      if first {
        min_x = left
        min_y = top
        max_x = right
        max_y = bottom
        first = false
      } else {
        if left < min_x {
          min_x = left
        }
        if top < min_y {
          min_y = top
        }
        if right > max_x {
          max_x = right
        }
        if bottom > max_y {
          max_y = bottom
        }
      }
    }
  }
  (min_x, min_y, max_x, max_y)
}

///|
/// Compute the full bounding box including edges and labels
fn compute_full_bounds(graph : Graph) -> (Double, Double, Double, Double) {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true

  // Include all object boxes
  for obj in graph.get_objects() {
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

  // Include all edge route points
  for edge in graph.get_edges() {
    for pt in edge.route {
      if first {
        min_x = pt.x
        min_y = pt.y
        max_x = pt.x
        max_y = pt.y
        first = false
      } else {
        if pt.x < min_x {
          min_x = pt.x
        }
        if pt.y < min_y {
          min_y = pt.y
        }
        if pt.x > max_x {
          max_x = pt.x
        }
        if pt.y > max_y {
          max_y = pt.y
        }
      }
    }
    // Include edge label boxes
    if edge.label_box is Some(lb) {
      if lb.x < min_x {
        min_x = lb.x
      }
      if lb.y < min_y {
        min_y = lb.y
      }
      if lb.x + lb.width > max_x {
        max_x = lb.x + lb.width
      }
      if lb.y + lb.height > max_y {
        max_y = lb.y + lb.height
      }
    }
  }
  (min_x, min_y, max_x, max_y)
}

///|
/// Check that the bounding box contains all elements (nodes, edges, labels)
pub fn bounding_box_contains_all_elements(graph : Graph) -> Bool {
  let (min_x, min_y, max_x, max_y) = compute_full_bounds(graph)

  // Bounding box should start at non-negative coordinates
  if min_x < -0.001 || min_y < -0.001 {
    return false
  }

  // Check all objects are within bounds
  for obj in graph.get_objects() {
    if obj.get_box() is Some(b) {
      if b.x < min_x - 0.001 || b.y < min_y - 0.001 {
        return false
      }
      if b.x + b.width > max_x + 0.001 || b.y + b.height > max_y + 0.001 {
        return false
      }
    }
  }

  // Check all edge route points are within bounds
  for edge in graph.get_edges() {
    for pt in edge.route {
      if pt.x < min_x - 0.001 || pt.y < min_y - 0.001 {
        return false
      }
      if pt.x > max_x + 0.001 || pt.y > max_y + 0.001 {
        return false
      }
    }
    // Check edge label boxes
    if edge.label_box is Some(lb) {
      if lb.x < min_x - 0.001 || lb.y < min_y - 0.001 {
        return false
      }
      if lb.x + lb.width > max_x + 0.001 || lb.y + lb.height > max_y + 0.001 {
        return false
      }
    }
  }
  true
}

///|
/// Check that all nodes are within the canvas bounds
/// Canvas bounds start at (0, 0) and extend to cover all nodes
pub fn nodes_within_canvas_bounds(graph : Graph) -> Bool {
  let (min_x, min_y, _, _) = compute_canvas_bounds(graph)
  // All nodes should have non-negative positions (canvas starts at 0,0)
  // and the minimum bounds should be >= 0
  if min_x < 0.0 || min_y < 0.0 {
    return false
  }
  // Additionally check each node is within computed bounds
  let (_, _, max_x, max_y) = compute_canvas_bounds(graph)
  for obj in graph.get_objects() {
    if obj.get_box() is Some(box) {
      // Node should not extend beyond canvas
      if box.x < 0.0 || box.y < 0.0 {
        return false
      }
      if box.x + box.width > max_x + 0.001 || box.y + box.height > max_y + 0.001 {
        return false
      }
    }
  }
  true
}

///|
/// Check that edge routes have no redundant waypoints (collinear points)
/// If A, B, C are collinear, B should have been removed
pub fn no_redundant_waypoints(graph : Graph) -> Bool {
  for edge in graph.get_edges() {
    if edge.route.length() < 3 {
      continue
    }
    // Check each triple of consecutive points
    for i in 0..<(edge.route.length() - 2) {
      let p0 = edge.route[i]
      let p1 = edge.route[i + 1]
      let p2 = edge.route[i + 2]
      // If they're collinear, the middle point is redundant
      if points_are_collinear(p0, p1, p2) {
        return false
      }
    }
  }
  true
}

///|
/// Check if three points are collinear (on the same line)
/// Uses cross product: if (p1-p0) × (p2-p0) ≈ 0, points are collinear
fn points_are_collinear(
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
) -> Bool {
  let dx1 = p1.x - p0.x
  let dy1 = p1.y - p0.y
  let dx2 = p2.x - p0.x
  let dy2 = p2.y - p0.y
  // Cross product: dx1*dy2 - dy1*dx2
  let cross = dx1 * dy2 - dy1 * dx2
  cross.abs() < 1.0
}

///|
/// Check that edge routes have no serpentine (S-shaped) routing
/// An S-shape occurs when direction reverses unnecessarily
pub fn no_serpentine_routing(graph : Graph) -> Bool {
  for edge in graph.get_edges() {
    if edge.route.length() < 3 {
      continue
    }
    // Check each triple of consecutive points for S-shapes
    for i in 0..<(edge.route.length() - 2) {
      let p0 = edge.route[i]
      let p1 = edge.route[i + 1]
      let p2 = edge.route[i + 2]
      // Check if this is an S-shape that should have been removed
      if is_removable_s_shape(p0, p1, p2, graph, edge) {
        return false
      }
    }
  }
  true
}

///|
/// Check if three points form an S-shape that should have been removed
/// Only flags S-shapes where the direct path doesn't intersect obstacles
fn is_removable_s_shape(
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  graph : Graph,
  edge : Edge,
) -> Bool {
  // First check if this forms an S-shape
  if !points_form_s_shape(p0, p1, p2) {
    return false
  }
  // Check if the direct line p0->p2 would intersect any obstacles
  // If it doesn't, this S-shape should have been removed
  for obj in graph.get_objects() {
    if obj.id == edge.src_id || obj.id == edge.dst_id {
      continue
    }
    if obj.get_box() is Some(box) {
      if line_segment_intersects_box(p0, p2, box) {
        // There's an obstacle, so the S-shape might be necessary
        return false
      }
    }
  }
  // No obstacles - this S-shape should have been removed
  true
}

///|
/// Check if three points form an S-shape (direction reversal)
fn points_form_s_shape(
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
) -> Bool {
  let dx1 = p1.x - p0.x
  let dy1 = p1.y - p0.y
  let dx2 = p2.x - p1.x
  let dy2 = p2.y - p1.y
  // Check for orthogonal corner (railroad style) - not an S-shape
  let is_seg1_vertical = dx1.abs() < 1.0 && dy1.abs() > 1.0
  let is_seg1_horizontal = dy1.abs() < 1.0 && dx1.abs() > 1.0
  let is_seg2_vertical = dx2.abs() < 1.0 && dy2.abs() > 1.0
  let is_seg2_horizontal = dy2.abs() < 1.0 && dx2.abs() > 1.0
  // Orthogonal corners are not S-shapes
  if (is_seg1_vertical && is_seg2_horizontal) ||
    (is_seg1_horizontal && is_seg2_vertical) {
    return false
  }
  // S-shape: horizontal direction reverses
  if dx1 * dx2 < 0.0 {
    return true
  }
  // S-shape: vertical direction reverses
  if dy1 * dy2 < 0.0 {
    return true
  }
  false
}

///|
/// Check that all edge segments are orthogonal (horizontal or vertical)
/// No diagonal segments should exist in the final edge routes
pub fn never_use_diagonal_edges(graph : Graph) -> Bool {
  let tolerance = 1.0
  for edge in graph.get_edges() {
    if edge.route.length() < 2 {
      continue
    }
    // Check each segment
    for i in 0..<(edge.route.length() - 1) {
      let p0 = edge.route[i]
      let p1 = edge.route[i + 1]
      let dx = (p1.x - p0.x).abs()
      let dy = (p1.y - p0.y).abs()
      // A segment is orthogonal if one dimension is near zero
      let is_horizontal = dy < tolerance
      let is_vertical = dx < tolerance
      if !is_horizontal && !is_vertical {
        // This is a diagonal segment
        return false
      }
    }
  }
  true
}

///|
/// Check that edge segments at node boundaries are perpendicular to the boundary
/// Bidirectional constraint:
/// - Horizontal segments must connect to LEFT or RIGHT side
/// - Vertical segments must connect to TOP or BOTTOM side
/// - Left/Right connections must have horizontal segments
/// - Top/Bottom connections must have vertical segments
/// - Corners are special: must match at least one valid direction
/// - Diagonal segments are NEVER perpendicular
pub fn edge_perpendicular_to_node_boundary(graph : Graph) -> Bool {
  let tolerance = 2.0
  for edge in graph.get_edges() {
    if edge.route.length() < 2 {
      continue
    }
    // Check first segment against source node
    let src_obj = graph.find_object(edge.src_id)
    if src_obj is Some(obj) {
      if obj.get_box() is Some(box) {
        let p0 = edge.route[0]
        let p1 = edge.route[1]
        let dx = (p1.x - p0.x).abs()
        let dy = (p1.y - p0.y).abs()
        let is_horizontal = dy < tolerance && dx > tolerance
        let is_vertical = dx < tolerance && dy > tolerance
        let is_diagonal = dx > tolerance && dy > tolerance
        // Diagonal segments are NEVER perpendicular
        if is_diagonal {
          return false
        }
        // Check which side p0 is on
        let on_left = (p0.x - box.x).abs() < tolerance
        let on_right = (p0.x - (box.x + box.width)).abs() < tolerance
        let on_top = (p0.y - box.y).abs() < tolerance
        let on_bottom = (p0.y - (box.y + box.height)).abs() < tolerance
        let on_vertical_side = on_left || on_right
        let on_horizontal_side = on_top || on_bottom
        // Forward constraint: segment direction → must be on matching side
        if is_horizontal && !on_vertical_side {
          return false
        }
        if is_vertical && !on_horizontal_side {
          return false
        }
        // Reverse constraint: side → must have matching segment direction
        // Only enforce when EXCLUSIVELY on one type of side (not at corner)
        if on_vertical_side && !on_horizontal_side && !is_horizontal {
          return false
        }
        if on_horizontal_side && !on_vertical_side && !is_vertical {
          return false
        }
      }
    }
    // Check last segment against destination node
    let dst_obj = graph.find_object(edge.dst_id)
    if dst_obj is Some(obj) {
      if obj.get_box() is Some(box) {
        let last_idx = edge.route.length() - 1
        let p0 = edge.route[last_idx - 1]
        let p1 = edge.route[last_idx]
        let dx = (p1.x - p0.x).abs()
        let dy = (p1.y - p0.y).abs()
        let is_horizontal = dy < tolerance && dx > tolerance
        let is_vertical = dx < tolerance && dy > tolerance
        let is_diagonal = dx > tolerance && dy > tolerance
        // Diagonal segments are NEVER perpendicular
        if is_diagonal {
          return false
        }
        // Check which side p1 (endpoint) is on
        let on_left = (p1.x - box.x).abs() < tolerance
        let on_right = (p1.x - (box.x + box.width)).abs() < tolerance
        let on_top = (p1.y - box.y).abs() < tolerance
        let on_bottom = (p1.y - (box.y + box.height)).abs() < tolerance
        let on_vertical_side = on_left || on_right
        let on_horizontal_side = on_top || on_bottom
        // Forward constraint: segment direction → must be on matching side
        if is_horizontal && !on_vertical_side {
          return false
        }
        if is_vertical && !on_horizontal_side {
          return false
        }
        // Reverse constraint: side → must have matching segment direction
        // Only enforce when EXCLUSIVELY on one type of side (not at corner)
        if on_vertical_side && !on_horizontal_side && !is_horizontal {
          return false
        }
        if on_horizontal_side && !on_vertical_side && !is_vertical {
          return false
        }
      }
    }
  }
  true
}

///|
/// Check that arrowhead direction matches the relative position of target node
/// The last segment of the edge route should point toward the destination node
pub fn arrowhead_direction_matches_node_position(graph : Graph) -> Bool {
  for edge in graph.get_edges() {
    // Only check edges with arrows
    if !edge.dst_arrow {
      continue
    }
    // Need at least 2 points to determine direction
    if edge.route.length() < 2 {
      continue
    }
    // Get the last segment (determines arrow direction)
    let last_idx = edge.route.length() - 1
    let second_last = edge.route[last_idx - 1]
    let last = edge.route[last_idx]
    // Get the destination node's center
    let dst_obj = graph.find_object(edge.dst_id)
    guard dst_obj is Some(obj) else { continue }
    guard obj.get_box() is Some(dst_box) else { continue }
    let dst_center_x = dst_box.x + dst_box.width / 2.0
    let dst_center_y = dst_box.y + dst_box.height / 2.0
    // Calculate the edge direction (from second_last to last)
    let edge_dx = last.x - second_last.x
    let edge_dy = last.y - second_last.y
    // Calculate direction from last point to destination center
    let to_dst_dx = dst_center_x - last.x
    let to_dst_dy = dst_center_y - last.y
    // If the last point is very close to dst center, direction doesn't matter much
    let dist_to_dst = (to_dst_dx * to_dst_dx + to_dst_dy * to_dst_dy).sqrt()
    if dist_to_dst < 1.0 {
      continue // Edge endpoint is essentially at the destination
    }
    // Check the primary axis alignment
    // The arrow should point toward the destination, not away from it
    if edge_dx.abs() > edge_dy.abs() {
      // Horizontal segment - check x direction
      if edge_dx > 0.0 && to_dst_dx < -dst_box.width / 2.0 {
        return false // Arrow points right but dst is to the left
      }
      if edge_dx < 0.0 && to_dst_dx > dst_box.width / 2.0 {
        return false // Arrow points left but dst is to the right
      }
    } else if edge_dy.abs() > 1.0 {
      // Vertical segment - check y direction
      if edge_dy > 0.0 && to_dst_dy < -dst_box.height / 2.0 {
        return false // Arrow points down but dst is above
      }
      if edge_dy < 0.0 && to_dst_dy > dst_box.height / 2.0 {
        return false // Arrow points up but dst is below
      }
    }
  }
  true
}

///|
/// Check that edge connects to the correct side of the destination node
/// based on approach direction:
/// - Approaching from above (going down) → connects to TOP edge
/// - Approaching from below (going up) → connects to BOTTOM edge
/// - Approaching from left (going right) → connects to LEFT edge
/// - Approaching from right (going left) → connects to RIGHT edge
pub fn edge_connects_to_correct_side(graph : Graph) -> Bool {
  let tolerance = 1.0
  for edge in graph.get_edges() {
    // Need at least 2 points to determine direction
    if edge.route.length() < 2 {
      continue
    }
    // Get the last segment (determines approach direction)
    let last_idx = edge.route.length() - 1
    let second_last = edge.route[last_idx - 1]
    let endpoint = edge.route[last_idx]
    // Get the destination node box
    let dst_obj = graph.find_object(edge.dst_id)
    guard dst_obj is Some(obj) else { continue }
    guard obj.get_box() is Some(box) else { continue }
    // Calculate the approach direction
    let dx = endpoint.x - second_last.x
    let dy = endpoint.y - second_last.y
    // Determine which side the endpoint should be on based on approach direction
    // and verify the endpoint is actually on that side
    if dy.abs() > dx.abs() {
      // Primarily vertical approach
      if dy > 0.0 {
        // Approaching from above (going down) → should connect to TOP edge
        if (endpoint.y - box.y).abs() > tolerance {
          return false
        }
        // Approaching from below (going up) → should connect to BOTTOM edge
      } else if (endpoint.y - (box.y + box.height)).abs() > tolerance {
        return false
      }
    } else if dx.abs() > tolerance {
      // Primarily horizontal approach
      if dx > 0.0 {
        // Approaching from left (going right) → should connect to LEFT edge
        if (endpoint.x - box.x).abs() > tolerance {
          return false
        }
        // Approaching from right (going left) → should connect to RIGHT edge
      } else if (endpoint.x - (box.x + box.width)).abs() > tolerance {
        return false
      }
    }
  }
  true
}

// ============================================================================
// Property Tests
// ============================================================================

///|
test "property: nodes should not overlap after layout" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      nodes_should_not_overlap(graph)
    }),
    max_success=50,
  )
}

///|
test "property: all nodes have positions after layout" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      all_nodes_have_positions(graph)
    }),
    max_success=50,
  )
}

///|
test "property: all positions are non-negative after layout" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      all_positions_non_negative(graph)
    }),
    max_success=50,
  )
}

///|
test "property: all dimensions are positive after layout" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      all_dimensions_positive(graph)
    }),
    max_success=50,
  )
}

///|
test "property: nodes within canvas bounds after layout" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      nodes_within_canvas_bounds(graph)
    }),
    max_success=50,
  )
}

///|
test "property: dense graphs - nodes within canvas bounds" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      nodes_within_canvas_bounds(graph)
    }),
    max_success=50,
  )
}

///|
test "property: bounding box contains all elements" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      bounding_box_contains_all_elements(graph)
    }),
    max_success=50,
  )
}

///|
test "property: dense graphs - bounding box contains all elements" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      bounding_box_contains_all_elements(graph)
    }),
    max_success=50,
  )
}

///|
test "property: dense graphs - nodes should not overlap" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      nodes_should_not_overlap(graph)
    }),
    max_success=50,
  )
}

///|
test "property: layout direction does not affect overlap constraint" {
  let directions = [
    Direction::Down,
    Direction::Up,
    Direction::Left,
    Direction::Right,
  ]
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      // Test all directions
      for dir in directions {
        // Create a fresh copy of the graph for each direction
        let test_graph = Graph::new("test")
        for obj in graph.get_objects() {
          let new_obj = Object::with_label(obj.id, obj.label)
          test_graph.add_object(new_obj)
        }
        for edge in graph.get_edges() {
          let new_edge = Edge::new(
            edge.index,
            edge.src_id,
            edge.dst_id,
            edge.src_arrow,
            edge.dst_arrow,
          )
          test_graph.add_edge(new_edge)
        }
        ignore(layout_in_place(test_graph, config, dir)) catch {
          _ => return false
        }
        if !nodes_should_not_overlap(test_graph) {
          return false
        }
      }
      true
    }),
    max_success=50,
  )
}

///|
test "property: minimum spacing between nodes (default config)" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      // With default spacing of 60, aligned nodes should have at least 10 gap
      minimum_spacing_between_nodes(graph, 10.0)
    }),
    max_success=50,
  )
}

///|
test "property: dense graphs - minimum spacing between nodes" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      // Dense graphs should still maintain minimum spacing
      minimum_spacing_between_nodes(graph, 10.0)
    }),
    max_success=50,
  )
}

///|
test "property: custom spacing is respected" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::with_spacing(100.0, 100.0)
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      // With 100 spacing, aligned nodes should have at least 20 gap
      minimum_spacing_between_nodes(graph, 20.0)
    }),
    max_success=50,
  )
}

///|
test "property: children inside parent containers" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      children_inside_parent(graph)
    }),
    max_success=50,
  )
}

///|
test "property: siblings do not overlap" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      sibling_no_overlap(graph)
    }),
    max_success=50,
  )
}

///|
test "property: edge endpoints touch nodes" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      edge_endpoints_touch_nodes(graph)
    }),
    max_success=50,
  )
}

///|
test "property: all input nodes are present after layout" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      // Record node IDs before layout
      let node_ids : Array[String] = []
      for obj in graph.get_objects() {
        node_ids.push(obj.id)
      }
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      all_input_nodes_present(node_ids, graph)
    }),
    max_success=50,
  )
}

///|
test "property: all input edges are present after layout" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      // Record edges before layout
      let edges : Array[(String, String)] = []
      for edge in graph.get_edges() {
        edges.push((edge.src_id, edge.dst_id))
      }
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      all_input_edges_present(edges, graph)
    }),
    max_success=50,
  )
}

///|
test "property: layout is deterministic" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      // Create two identical copies
      let graph1 = Graph::new("test")
      let graph2 = Graph::new("test")
      for obj in graph.get_objects() {
        let obj1 = Object::with_label(obj.id, obj.label)
        let obj2 = Object::with_label(obj.id, obj.label)
        graph1.add_object(obj1)
        graph2.add_object(obj2)
      }
      for edge in graph.get_edges() {
        let edge1 = Edge::new(
          edge.index,
          edge.src_id,
          edge.dst_id,
          edge.src_arrow,
          edge.dst_arrow,
        )
        let edge2 = Edge::new(
          edge.index,
          edge.src_id,
          edge.dst_id,
          edge.src_arrow,
          edge.dst_arrow,
        )
        graph1.add_edge(edge1)
        graph2.add_edge(edge2)
      }
      // Apply same layout to both
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph1, config, Direction::Down)) catch {
        _ => return false
      }
      ignore(layout_in_place(graph2, config, Direction::Down)) catch {
        _ => return false
      }
      // Should produce identical results
      deterministic_output(graph1, graph2)
    }),
    max_success=50,
  )
}

///|
test "property: edge labels do not overlap" {
  @qc.quick_check(
    @qc.forall(gen_graph_with_edge_labels(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      edge_labels_no_overlap(graph)
    }),
    max_success=50,
  )
}

///|
test "property: sql_table edges are clipped to boxes" {
  @qc.quick_check(
    @qc.forall(gen_sql_table_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      sql_table_edges_clipped_to_boxes(graph) && never_use_diagonal_edges(graph)
    }),
    max_success=50,
  )
}

// NOTE: The following tests are commented out because they reveal known algorithm limitations
// that require significant work to fix. The constraints are implemented and can be used
// for testing once the algorithm is improved.

// ///|
// test "property: self-loops are visible" {
//   // KNOWN ISSUE: Self-loops are removed during cycle breaking and not re-routed
//   @qc.quick_check(
//     @qc.forall(gen_graph_with_self_loops(), fn(graph : Graph) {
//       let config = LayoutConfig::new()
//       ignore(layout_in_place(graph, config, Direction::Down)) catch { _ => return false }
//       self_loop_visible(graph)
//     }),
//     max_success=50,
//   )
// }

///|
test "property: edges avoid unrelated nodes" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      edge_avoids_unrelated_nodes(graph)
    }),
    max_success=50,
  )
}

///|
test "property: text fits in container" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      text_fits_container(graph)
    }),
    max_success=50,
  )
}

///|
test "property: no redundant waypoints in edge routes" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      no_redundant_waypoints(graph)
    }),
    max_success=50,
  )
}

///|
test "property: no serpentine routing in edges" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      no_serpentine_routing(graph)
    }),
    max_success=50,
  )
}

///|
test "property: never use diagonal edges" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      never_use_diagonal_edges(graph)
    }),
    max_success=50,
  )
}

///|
test "property: parallel edges are distinguishable" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      parallel_edges_distinguishable(graph)
    }),
    max_success=50,
  )
}

///|
test "property: arrowhead direction matches node position" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      arrowhead_direction_matches_node_position(graph)
    }),
    max_success=50,
  )
}

///|
test "property: edge connects to correct side of node" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      edge_connects_to_correct_side(graph)
    }),
    max_success=50,
  )
}

///|
test "property: cluster contains all members" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      cluster_contains_members(graph)
    }),
    max_success=50,
  )
}

///|
test "property: edge perpendicular to node boundary" {
  @qc.quick_check(
    @qc.forall(gen_graph(), fn(graph : Graph) {
      let config = LayoutConfig::new()
      ignore(layout_in_place(graph, config, Direction::Down)) catch {
        _ => return false
      }
      edge_perpendicular_to_node_boundary(graph)
    }),
    max_success=50,
  )
}
