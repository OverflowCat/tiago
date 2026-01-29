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
// Port-Based Routing (Phase 7 with pre-assigned ports)
// ============================================================================

///|
/// Convert PortSide to string for compatibility with legacy routing code
fn port_side_to_side_string(side : PortSide) -> String {
  match side {
    Top => "top"
    Bottom => "bottom"
    Left => "left"
    Right => "right"
  }
}

///|
/// Route edges using pre-assigned ports
/// This guarantees perpendicular connections since ports are on node sides
#warnings("-unused_value")
fn route_edges_with_ports(
  graph : Graph,
  _config : LayoutConfig,
  virtual_result : VirtualNodeResult,
) -> Unit {
  // Track parallel edge counts for offset calculation
  let edge_counts : Map[String, Int] = {}
  for edge in graph.edges {
    // Clear existing route
    edge.route.clear()
    // Handle self-loops specially
    if edge.src_id == edge.dst_id {
      let src_obj = graph.find_object(edge.src_id)
      guard src_obj is Some(src) else { continue }
      guard src.box is Some(box) else { continue }
      route_self_loop(edge, box)
      continue
    }
    // Calculate parallel edge offset
    let edge_key = if edge.src_id < edge.dst_id {
      edge.src_id + "->" + edge.dst_id
    } else {
      edge.dst_id + "->" + edge.src_id
    }
    let edge_index = edge_counts.get(edge_key).unwrap_or(0)
    edge_counts[edge_key] = edge_index + 1
    // Check if this edge has pre-assigned ports with computed points
    let use_port_routing = match (edge.src_port, edge.dst_port) {
      (Some(src_port), Some(dst_port)) =>
        match (src_port.point, dst_port.point) {
          (Some(_), Some(_)) => {
            // Use port-based routing (guarantees perpendicular connections)
            route_edge_with_ports(edge, src_port, dst_port, graph, edge_index)
            true
          }
          _ => false // Fall through to legacy routing
        }
      _ => false
    }
    if use_port_routing {
      continue
    }
    // Fallback to legacy routing for edges without ports
    let (src_box, src_num_cols, dst_box, dst_num_cols) = match
      get_sql_table_boxes(graph, edge) {
      Some(boxes) => boxes
      None => {
        let src_obj = graph.find_object(edge.src_id)
        let dst_obj = graph.find_object(edge.dst_id)
        if src_obj is None || dst_obj is None {
          continue
        }
        let src = src_obj.unwrap()
        let dst = dst_obj.unwrap()
        if src.box is None || dst.box is None {
          continue
        }
        (src.box.unwrap(), 0, dst.box.unwrap(), 0)
      }
    }
    // Check if this edge has virtual nodes
    if virtual_result.edge_virtual_nodes.get(edge.index) is Some(virtual_ids) &&
      virtual_ids.length() > 0 {
      route_edge_through_virtual_sql(
        edge, src_box, dst_box, virtual_ids, virtual_result, src_num_cols, dst_num_cols,
        edge_index,
      )
    } else {
      route_direct_edge_sql_parallel(
        edge, src_box, dst_box, src_num_cols, dst_num_cols, edge_index,
      )
    }
  }
}

///|
/// Route an edge using pre-assigned ports
/// Creates an orthogonal route that respects port sides
fn route_edge_with_ports(
  edge : Edge,
  src_port : Port,
  dst_port : Port,
  _graph : Graph,
  parallel_index : Int,
) -> Unit {
  // Get port points
  let src_point = match src_port.point {
    Some(p) => p
    None => return // Port not computed yet
  }
  let dst_point = match dst_port.point {
    Some(p) => p
    None => return // Port not computed yet
  }
  // Calculate parallel offset for multiple edges
  let offset_amount = 15.0
  let offset = if parallel_index == 0 {
    0.0
  } else {
    let sign = if parallel_index % 2 == 1 { 1.0 } else { -1.0 }
    sign * ((parallel_index + 1) / 2).to_double() * offset_amount
  }
  // Create orthogonal route based on port sides
  let route = create_orthogonal_route_from_ports(
    src_point,
    dst_point,
    src_port.side,
    dst_port.side,
    offset,
  )
  // Apply route to edge
  for pt in route {
    edge.route.push(pt)
  }
}

///|
/// Create an orthogonal route between two ports
/// The first segment is perpendicular to src_side
/// The last segment is perpendicular to dst_side
/// IMPORTANT: Endpoints are kept exactly on port points to ensure perpendicularity.
/// Offset is applied to middle segments only for parallel edge separation.
fn create_orthogonal_route_from_ports(
  src : @graph.Point,
  dst : @graph.Point,
  src_side : PortSide,
  dst_side : PortSide,
  offset : Double,
) -> Array[@graph.Point] {
  let route : Array[@graph.Point] = []
  // Keep source exactly on the port point (on node boundary)
  route.push(src)
  // Determine routing based on port sides
  // For orthogonal routes, offset is applied to the middle segment coordinate
  match (src_side, dst_side) {
    (Top, Top) | (Bottom, Bottom) => {
      // Both vertical sides - need horizontal middle segment
      // Offset applied to mid_y for parallel edge separation
      let mid_y = (src.y + dst.y) / 2.0 + offset
      route.push(@graph.Point::new(src.x, mid_y))
      route.push(@graph.Point::new(dst.x, mid_y))
    }
    (Top, Bottom) =>
      // Source exits top, destination enters from bottom
      if src.y > dst.y {
        // src is below dst - need horizontal detour
        let mid_x = (src.x + dst.x) / 2.0 + offset
        route.push(@graph.Point::new(src.x, src.y - 30.0))
        route.push(@graph.Point::new(mid_x, src.y - 30.0))
        route.push(@graph.Point::new(mid_x, dst.y + 30.0))
        route.push(@graph.Point::new(dst.x, dst.y + 30.0))
      } else {
        // Direct vertical connection possible
        let mid_y = (src.y + dst.y) / 2.0 + offset
        route.push(@graph.Point::new(src.x, mid_y))
        route.push(@graph.Point::new(dst.x, mid_y))
      }
    (Bottom, Top) =>
      // Source exits bottom, destination enters from top
      // This is the typical case in Sugiyama layout (downward flow)
      if src.y < dst.y {
        // Direct vertical connection possible
        let mid_y = (src.y + dst.y) / 2.0 + offset
        route.push(@graph.Point::new(src.x, mid_y))
        route.push(@graph.Point::new(dst.x, mid_y))
      } else {
        // src is below dst - need horizontal detour
        let mid_x = (src.x + dst.x) / 2.0 + offset
        route.push(@graph.Point::new(src.x, src.y + 30.0))
        route.push(@graph.Point::new(mid_x, src.y + 30.0))
        route.push(@graph.Point::new(mid_x, dst.y - 30.0))
        route.push(@graph.Point::new(dst.x, dst.y - 30.0))
      }
    (Left, Left) | (Right, Right) => {
      // Both horizontal sides - need vertical middle segment
      // Offset applied to mid_x for parallel edge separation
      let mid_x = (src.x + dst.x) / 2.0 + offset
      route.push(@graph.Point::new(mid_x, src.y))
      route.push(@graph.Point::new(mid_x, dst.y))
    }
    (Left, Right) =>
      // Source exits left, destination enters from right
      if src.x > dst.x {
        // Direct horizontal connection possible
        let mid_x = (src.x + dst.x) / 2.0 + offset
        route.push(@graph.Point::new(mid_x, src.y))
        route.push(@graph.Point::new(mid_x, dst.y))
      } else {
        // src is to the left of dst - need vertical detour
        let mid_y = (src.y + dst.y) / 2.0 + offset
        route.push(@graph.Point::new(src.x - 30.0, src.y))
        route.push(@graph.Point::new(src.x - 30.0, mid_y))
        route.push(@graph.Point::new(dst.x + 30.0, mid_y))
        route.push(@graph.Point::new(dst.x + 30.0, dst.y))
      }
    (Right, Left) =>
      // Source exits right, destination enters from left
      if src.x < dst.x {
        // Direct horizontal connection possible
        let mid_x = (src.x + dst.x) / 2.0 + offset
        route.push(@graph.Point::new(mid_x, src.y))
        route.push(@graph.Point::new(mid_x, dst.y))
      } else {
        // src is to the right of dst - need vertical detour
        let mid_y = (src.y + dst.y) / 2.0 + offset
        route.push(@graph.Point::new(src.x + 30.0, src.y))
        route.push(@graph.Point::new(src.x + 30.0, mid_y))
        route.push(@graph.Point::new(dst.x - 30.0, mid_y))
        route.push(@graph.Point::new(dst.x - 30.0, dst.y))
      }
    (Top, Left) | (Top, Right) =>
      // L-shape: vertical then horizontal
      route.push(@graph.Point::new(src.x, dst.y))
    (Bottom, Left) | (Bottom, Right) =>
      // L-shape: vertical then horizontal
      route.push(@graph.Point::new(src.x, dst.y))
    (Left, Top) | (Left, Bottom) =>
      // L-shape: horizontal then vertical
      route.push(@graph.Point::new(dst.x, src.y))
    (Right, Top) | (Right, Bottom) =>
      // L-shape: horizontal then vertical
      route.push(@graph.Point::new(dst.x, src.y))
  }
  // Keep destination exactly on the port point (on node boundary)
  route.push(dst)
  route
}

///|
/// Route a self-loop edge (where source and destination are the same node)
fn route_self_loop(edge : Edge, box : @graph.Box) -> Unit {
  // Create a loop that goes out from the right side, curves up/right, and comes back
  let loop_size = 30.0
  let right = box.x + box.width
  let top = box.y
  let center_y = box.y + box.height / 2.0
  // Start from right side, slightly above center
  let start_x = right
  let start_y = center_y - 10.0
  // End at right side, slightly below center
  let end_x = right
  let end_y = center_y + 10.0
  // Control points for the loop
  let ctrl1_x = right + loop_size
  let ctrl1_y = start_y - loop_size
  let ctrl2_x = right + loop_size * 1.5
  let ctrl2_y = top - loop_size
  let ctrl3_x = right + loop_size
  let ctrl3_y = end_y + loop_size
  // Add route points
  edge.add_route_point(@graph.Point::new(start_x, start_y))
  edge.add_route_point(@graph.Point::new(ctrl1_x, ctrl1_y))
  edge.add_route_point(@graph.Point::new(ctrl2_x, ctrl2_y))
  edge.add_route_point(@graph.Point::new(ctrl3_x, ctrl3_y))
  edge.add_route_point(@graph.Point::new(end_x, end_y))
}

///|
/// Get SQL table boxes for an edge with column indices
/// Returns (src_box, src_num_cols, dst_box, dst_num_cols) if applicable
fn get_sql_table_boxes(
  graph : Graph,
  edge : Edge,
) -> (@graph.Box, Int, @graph.Box, Int)? {
  // Get source box (either from parent table or direct object)
  let (src_box, src_num_cols) = if edge.src_column_index is Some(_) {
    // Find parent SQL table
    let parent_id = match get_parent_id_from_field(edge.src_id) {
      Some(p) => p
      None => return None
    }
    let parent = match graph.find_object(parent_id) {
      Some(p) => p
      None => return None
    }
    if parent.box is None {
      return None
    }
    (parent.box.unwrap(), parent.children.length())
  } else {
    let obj = match graph.find_object(edge.src_id) {
      Some(o) => o
      None => return None
    }
    if obj.box is None {
      return None
    }
    (obj.box.unwrap(), 0)
  }
  // Get destination box (either from parent table or direct object)
  let (dst_box, dst_num_cols) = if edge.dst_column_index is Some(_) {
    // Find parent SQL table
    let parent_id = match get_parent_id_from_field(edge.dst_id) {
      Some(p) => p
      None => return None
    }
    let parent = match graph.find_object(parent_id) {
      Some(p) => p
      None => return None
    }
    if parent.box is None {
      return None
    }
    (parent.box.unwrap(), parent.children.length())
  } else {
    let obj = match graph.find_object(edge.dst_id) {
      Some(o) => o
      None => return None
    }
    if obj.box is None {
      return None
    }
    (obj.box.unwrap(), 0)
  }
  Some((src_box, src_num_cols, dst_box, dst_num_cols))
}

///|
/// Route an edge through virtual nodes with SQL table support
fn route_edge_through_virtual_sql(
  edge : Edge,
  src_box : @graph.Box,
  dst_box : @graph.Box,
  _virtual_ids : Array[String],
  _virtual_result : VirtualNodeResult,
  src_num_cols : Int,
  dst_num_cols : Int,
  parallel_index : Int,
) -> Unit {
  // Calculate parallel offset (alternate left/right)
  let offset_amount = 15.0 // Pixels between parallel edges
  let offset = if parallel_index == 0 {
    0.0
  } else {
    let sign = if parallel_index % 2 == 1 { 1.0 } else { -1.0 }
    sign * ((parallel_index + 1) / 2).to_double() * offset_amount
  }

  // Check if this is an SQL table edge
  let is_sql_src = edge.src_column_index is Some(_) && src_num_cols > 0
  let is_sql_dst = edge.dst_column_index is Some(_) && dst_num_cols > 0
  let is_sql_edge = is_sql_src || is_sql_dst

  // Port constraint approach for SQL tables:
  // - Source column connections use RIGHT side (srcSide = East)
  // - Destination column connections use LEFT side (dstSide = West)
  // Calculate best anchors based on relative positions if not specified
  let (default_src_anchor, default_dst_anchor) = calculate_best_anchors(
    src_box, dst_box,
  )
  let src_point = if edge.src_column_index is Some(col_idx) && src_num_cols > 0 {
    get_sql_row_anchor_point(src_box, col_idx, src_num_cols, false)
  } else {
    let src_anchor = edge.src_anchor.unwrap_or(default_src_anchor)
    get_anchor_point(src_box, src_anchor, offset)
  }
  let dst_point = if edge.dst_column_index is Some(col_idx) && dst_num_cols > 0 {
    get_sql_row_anchor_point(dst_box, col_idx, dst_num_cols, true)
  } else {
    let dst_anchor = edge.dst_anchor.unwrap_or(default_dst_anchor)
    get_anchor_point(dst_box, dst_anchor, offset)
  }
  if is_sql_edge {
    // SQL table edge: simple 4-point zig-zag
    let mid_x = (src_point.x + dst_point.x) / 2.0 + offset
    edge.route.push(src_point)
    edge.route.push(@graph.Point::new(mid_x, src_point.y))
    edge.route.push(@graph.Point::new(mid_x, dst_point.y))
    edge.route.push(dst_point)
  } else {
    // Regular edge: use orthogonal routing that respects anchor direction
    // The final segment must approach from the correct direction for the anchor
    let dst_anchor = edge.dst_anchor.unwrap_or(default_dst_anchor)
    let is_vertical_anchor = dst_anchor == "top" || dst_anchor == "bottom"
    edge.route.push(src_point)
    if is_vertical_anchor {
      // Vertical approach: route horizontally first, then vertically to dst
      let mid_y = (src_point.y + dst_point.y) / 2.0
      if (src_point.x - dst_point.x).abs() > 1.0 {
        edge.route.push(@graph.Point::new(src_point.x, mid_y))
        edge.route.push(@graph.Point::new(dst_point.x, mid_y))
      }
    } else {
      // Horizontal approach: route vertically first, then horizontally to dst
      let mid_x = (src_point.x + dst_point.x) / 2.0
      if (src_point.y - dst_point.y).abs() > 1.0 {
        edge.route.push(@graph.Point::new(mid_x, src_point.y))
        edge.route.push(@graph.Point::new(mid_x, dst_point.y))
      }
    }
    edge.route.push(dst_point)
  }
}

///|
/// Route a direct edge with SQL table support and parallel edge offset
fn route_direct_edge_sql_parallel(
  edge : Edge,
  src_box : @graph.Box,
  dst_box : @graph.Box,
  src_num_cols : Int,
  dst_num_cols : Int,
  parallel_index : Int,
) -> Unit {
  // Check if this is an SQL table edge
  let is_sql_src = edge.src_column_index is Some(_) && src_num_cols > 0
  let is_sql_dst = edge.dst_column_index is Some(_) && dst_num_cols > 0
  let is_sql_edge = is_sql_src || is_sql_dst
  // Calculate parallel offset (alternate left/right)
  let offset_amount = 15.0 // Pixels between parallel edges
  let offset = if parallel_index == 0 {
    0.0
  } else {
    let sign = if parallel_index % 2 == 1 { 1.0 } else { -1.0 }
    sign * ((parallel_index + 1) / 2).to_double() * offset_amount
  }
  // Port constraint approach for SQL tables:
  // - Source column connections use RIGHT side (srcSide = East)
  // - Destination column connections use LEFT side (dstSide = West)
  // Calculate best anchors based on relative positions if not specified
  let (default_src_anchor, default_dst_anchor) = calculate_best_anchors(
    src_box, dst_box,
  )
  let src_point = if edge.src_column_index is Some(col_idx) && src_num_cols > 0 {
    get_sql_row_anchor_point(src_box, col_idx, src_num_cols, false)
  } else {
    let src_anchor = edge.src_anchor.unwrap_or(default_src_anchor)
    get_anchor_point(src_box, src_anchor, offset)
  }
  let dst_point = if edge.dst_column_index is Some(col_idx) && dst_num_cols > 0 {
    get_sql_row_anchor_point(dst_box, col_idx, dst_num_cols, true)
  } else {
    let dst_anchor = edge.dst_anchor.unwrap_or(default_dst_anchor)
    get_anchor_point(dst_box, dst_anchor, offset)
  }
  if is_sql_edge {
    // SQL table edge: simple 4-point zig-zag
    // The railroad path builder will add rounded corners at the 2 turns
    let mid_x = (src_point.x + dst_point.x) / 2.0 + offset
    edge.route.push(src_point)
    edge.route.push(@graph.Point::new(mid_x, src_point.y))
    edge.route.push(@graph.Point::new(mid_x, dst_point.y))
    edge.route.push(dst_point)
  } else if parallel_index > 0 {
    // Parallel edge: use orthogonal L-shape routing (offset is in anchor points)
    // The approach direction must match the anchor side
    let is_vertical_anchor = default_dst_anchor == "top" ||
      default_dst_anchor == "bottom"
    edge.route.push(src_point)
    if is_vertical_anchor {
      // Vertical approach: L-shape with horizontal first, then vertical to dst
      if (src_point.x - dst_point.x).abs() > 1.0 {
        edge.route.push(@graph.Point::new(dst_point.x, src_point.y))
      }
      // Horizontal approach: L-shape with vertical first, then horizontal to dst
    } else if (src_point.y - dst_point.y).abs() > 1.0 {
      edge.route.push(@graph.Point::new(src_point.x, dst_point.y))
    }
    edge.route.push(dst_point)
  } else {
    // Regular edge: use orthogonal routing to ensure correct approach direction
    // The final segment must approach from the direction matching the anchor side
    let is_vertical_anchor = default_dst_anchor == "top" ||
      default_dst_anchor == "bottom"
    edge.route.push(src_point)
    if is_vertical_anchor {
      // Vertical approach needed: route to dst's x first, then vertically to dst
      if (src_point.x - dst_point.x).abs() > 1.0 {
        edge.route.push(@graph.Point::new(dst_point.x, src_point.y))
      }
      // Horizontal approach needed: route to dst's y first, then horizontally to dst
    } else if (src_point.y - dst_point.y).abs() > 1.0 {
      edge.route.push(@graph.Point::new(src_point.x, dst_point.y))
    }
    edge.route.push(dst_point)
  }
}

// ============================================================================
// Obstacle Avoidance Routing
// ============================================================================

///|
/// Compute bounding box of all objects in the graph.
/// Returns (min_x, min_y, max_x, max_y).
fn compute_all_bounds(graph : Graph) -> (Double, Double, Double, Double) {
  let mut min_x = 1.0e10
  let mut min_y = 1.0e10
  let mut max_x = -1.0e10
  let mut max_y = -1.0e10
  for obj in graph.objects {
    guard obj.box is Some(box) else { continue }
    if box.x < min_x {
      min_x = box.x
    }
    if box.y < min_y {
      min_y = box.y
    }
    if box.x + box.width > max_x {
      max_x = box.x + box.width
    }
    if box.y + box.height > max_y {
      max_y = box.y + box.height
    }
  }
  (min_x, min_y, max_x, max_y)
}

///|
struct AStarEntry {
  f : Double
  g : Double
  state : Int
} derive(Eq, Show)

///|
impl Compare for AStarEntry with compare(a, b) {
  let c1 = a.f.compare(b.f)
  if c1 != 0 {
    c1
  } else {
    let c2 = a.g.compare(b.g)
    if c2 != 0 {
      c2
    } else {
      a.state.compare(b.state)
    }
  }
}

///|
fn astar_route_orthogonal(
  start : @graph.Point,
  goal : @graph.Point,
  _start_side : String,
  goal_side : String,
  src_box : @graph.Box,
  dst_box : @graph.Box,
  obstacles : Array[@graph.Box],
  canvas_bounds : (Double, Double, Double, Double),
  clearance : Double,
) -> Array[@graph.Point]? {
  // Expand obstacles by clearance (boundary-touch still allowed).
  let expanded : Array[@graph.Box] = []
  for b in obstacles {
    expanded.push(expand_box(b, clearance))
  }
  let (min_x, min_y, max_x, max_y) = canvas_bounds
  let outer_margin = 250.0
  let left_bound = min_x - outer_margin
  let right_bound = max_x + outer_margin
  let top_bound = min_y - outer_margin
  let bottom_bound = max_y + outer_margin

  // Sparse coordinate grid (Hanan-style): obstacle boundaries + endpoints + canvas bounds.
  let xs : Array[Double] = [
    start.x,
    goal.x,
    left_bound,
    right_bound,
    src_box.x,
    src_box.x + src_box.width,
    dst_box.x,
    dst_box.x + dst_box.width,
  ]
  let ys : Array[Double] = [
    start.y,
    goal.y,
    top_bound,
    bottom_bound,
    src_box.y,
    src_box.y + src_box.height,
    dst_box.y,
    dst_box.y + dst_box.height,
  ]
  for b in expanded {
    xs.push(b.x)
    xs.push(b.x + b.width)
    ys.push(b.y)
    ys.push(b.y + b.height)
  }
  let x_coords = unique_sorted(xs, 0.001)
  let y_coords = unique_sorted(ys, 0.001)
  if x_coords.length() < 2 || y_coords.length() < 2 {
    return None
  }
  let start_ix_opt = find_coord_index(x_coords, start.x, 0.01)
  let start_iy_opt = find_coord_index(y_coords, start.y, 0.01)
  let goal_ix_opt = find_coord_index(x_coords, goal.x, 0.01)
  let goal_iy_opt = find_coord_index(y_coords, goal.y, 0.01)
  guard start_ix_opt is Some(start_ix) else { return None }
  guard start_iy_opt is Some(start_iy) else { return None }
  guard goal_ix_opt is Some(goal_ix) else { return None }
  guard goal_iy_opt is Some(goal_iy) else { return None }
  let x_len = x_coords.length()
  let y_len = y_coords.length()
  let cell_count = x_len * y_len

  // Blocked grid nodes (inside obstacle interior).
  let blocked : Array[Bool] = Array::new(capacity=cell_count)
  for _ in 0..<cell_count {
    blocked.push(false)
  }
  for iy = 0; iy < y_len; iy = iy + 1 {
    for ix = 0; ix < x_len; ix = ix + 1 {
      let idx = iy * x_len + ix
      let p = @graph.Point::new(x_coords[ix], y_coords[iy])
      if point_inside_any_box(p, expanded) {
        blocked[idx] = true
      }
    }
  }
  // Ensure endpoints stay reachable even if numerically on a boundary.
  blocked[start_iy * x_len + start_ix] = false
  blocked[goal_iy * x_len + goal_ix] = false
  let total_states = cell_count * 3
  let inf = 1.0e18
  let g_score : Array[Double] = Array::new(capacity=total_states)
  let came_from : Array[Int] = Array::new(capacity=total_states)
  let closed : Array[Bool] = Array::new(capacity=total_states)
  for _ in 0..<total_states {
    g_score.push(inf)
    came_from.push(-1)
    closed.push(false)
  }
  let start_state = encode_state(start_ix, start_iy, 0, x_len, y_len)
  g_score[start_state] = 0.0
  let open : @priority_queue.PriorityQueue[@cmp.Reverse[AStarEntry]] = @priority_queue.new()
  open.push(
    @cmp.Reverse({
      f: heuristic(start_ix, start_iy, goal_ix, goal_iy, x_coords, y_coords),
      g: 0.0,
      state: start_state,
    }),
  )
  let mut goal_state : Int? = None
  let turn_penalty = 10.0
  while open.pop() is Some(@cmp.Reverse(entry)) {
    let state = entry.state
    if closed[state] {
      continue
    }
    closed[state] = true
    let (ix, iy, dir) = decode_state(state, x_len, y_len)
    if ix == goal_ix && iy == goal_iy {
      goal_state = Some(state)
      break
    }

    // Neighbor order chosen for determinism.
    for step in [(1, 0, 1), (-1, 0, 1), (0, 1, 2), (0, -1, 2)] {
      let dx = step.0
      let dy = step.1
      let ndir = step.2
      let nix = ix + dx
      let niy = iy + dy
      if nix < 0 || niy < 0 || nix >= x_len || niy >= y_len {
        continue
      }
      let ncell = niy * x_len + nix
      if blocked[ncell] {
        continue
      }

      // Enforce goal approach side/direction for arrow correctness.
      if nix == goal_ix &&
        niy == goal_iy &&
        !can_enter_goal(
          ix, iy, nix, niy, goal_ix, goal_iy, goal_side, x_coords, y_coords,
        ) {
        continue
      }
      let p0 = @graph.Point::new(x_coords[ix], y_coords[iy])
      let p1 = @graph.Point::new(x_coords[nix], y_coords[niy])
      if segment_hits_any_box(p0, p1, expanded) {
        continue
      }
      let move_cost = (p1.x - p0.x).abs() + (p1.y - p0.y).abs()
      let turn_cost = if dir != 0 && dir != ndir { turn_penalty } else { 0.0 }
      let tentative = g_score[state] + move_cost + turn_cost
      let nstate = encode_state(nix, niy, ndir, x_len, y_len)
      if tentative + 1.0e-9 < g_score[nstate] {
        g_score[nstate] = tentative
        came_from[nstate] = state
        let f = tentative +
          heuristic(nix, niy, goal_ix, goal_iy, x_coords, y_coords)
        open.push(@cmp.Reverse({ f, g: tentative, state: nstate }))
      }
    }
  }
  guard goal_state is Some(gs) else { return None }
  let raw = reconstruct_points(gs, came_from, x_len, y_len, x_coords, y_coords)
  let route = compress_route(raw, start, goal)

  // Final sanity: avoid returning a route that still hits an obstacle due to numerical drift.
  if route.length() < 2 {
    None
  } else if route_hits_any_box(route, expanded) {
    None
  } else {
    Some(route)
  }
}

///|
fn expand_box(box : @graph.Box, margin : Double) -> @graph.Box {
  @graph.Box::new(
    box.x - margin,
    box.y - margin,
    box.width + margin * 2.0,
    box.height + margin * 2.0,
  )
}

///|
fn unique_sorted(values : Array[Double], eps : Double) -> Array[Double] {
  values.sort()
  let out : Array[Double] = []
  for v in values {
    if out.is_empty() {
      out.push(v)
    } else {
      let last = out[out.length() - 1]
      if (v - last).abs() > eps {
        out.push(v)
      }
    }
  }
  out
}

///|
fn find_coord_index(
  values : Array[Double],
  target : Double,
  eps : Double,
) -> Int? {
  for i, v in values {
    if (v - target).abs() <= eps {
      return Some(i)
    }
  }
  None
}

///|
fn encode_state(ix : Int, iy : Int, dir : Int, x_len : Int, y_len : Int) -> Int {
  let cell = iy * x_len + ix
  let base = x_len * y_len
  dir * base + cell
}

///|
fn decode_state(state : Int, x_len : Int, y_len : Int) -> (Int, Int, Int) {
  let base = x_len * y_len
  let dir = state / base
  let cell = state % base
  let ix = cell % x_len
  let iy = cell / x_len
  (ix, iy, dir)
}

///|
fn heuristic(
  ix : Int,
  iy : Int,
  goal_ix : Int,
  goal_iy : Int,
  xs : Array[Double],
  ys : Array[Double],
) -> Double {
  (xs[ix] - xs[goal_ix]).abs() + (ys[iy] - ys[goal_iy]).abs()
}

///|
fn point_inside_any_box(p : @graph.Point, boxes : Array[@graph.Box]) -> Bool {
  for b in boxes {
    let left = b.x
    let right = b.x + b.width
    let top = b.y
    let bottom = b.y + b.height
    if p.x > left && p.x < right && p.y > top && p.y < bottom {
      return true
    }
  }
  false
}

///|
fn segment_hits_any_box(
  p0 : @graph.Point,
  p1 : @graph.Point,
  boxes : Array[@graph.Box],
) -> Bool {
  for b in boxes {
    if segment_hits_box(p0, p1, b) {
      return true
    }
  }
  false
}

///|
fn segment_hits_box(
  p0 : @graph.Point,
  p1 : @graph.Point,
  b : @graph.Box,
) -> Bool {
  let left = b.x
  let right = b.x + b.width
  let top = b.y
  let bottom = b.y + b.height
  let dx = (p1.x - p0.x).abs()
  let dy = (p1.y - p0.y).abs()
  // Only used for orthogonal routing; treat near-zero as axis-aligned.
  if dx >= dy {
    // Horizontal
    let y = p0.y
    if !(y > top && y < bottom) {
      return false
    }
    let x0 = if p0.x < p1.x { p0.x } else { p1.x }
    let x1 = if p0.x > p1.x { p0.x } else { p1.x }
    x1 > left && x0 < right
  } else {
    // Vertical
    let x = p0.x
    if !(x > left && x < right) {
      return false
    }
    let y0 = if p0.y < p1.y { p0.y } else { p1.y }
    let y1 = if p0.y > p1.y { p0.y } else { p1.y }
    y1 > top && y0 < bottom
  }
}

///|
fn can_enter_goal(
  from_ix : Int,
  from_iy : Int,
  to_ix : Int,
  to_iy : Int,
  goal_ix : Int,
  goal_iy : Int,
  goal_side : String,
  xs : Array[Double],
  ys : Array[Double],
) -> Bool {
  if to_ix != goal_ix || to_iy != goal_iy {
    return true
  }
  match goal_side {
    "top" => from_ix == to_ix && ys[from_iy] < ys[to_iy]
    "bottom" => from_ix == to_ix && ys[from_iy] > ys[to_iy]
    "left" => from_iy == to_iy && xs[from_ix] < xs[to_ix]
    "right" => from_iy == to_iy && xs[from_ix] > xs[to_ix]
    _ => true
  }
}

///|
fn reconstruct_points(
  goal_state : Int,
  came_from : Array[Int],
  x_len : Int,
  y_len : Int,
  xs : Array[Double],
  ys : Array[Double],
) -> Array[@graph.Point] {
  let mut cur = goal_state
  let states : Array[Int] = []
  while cur >= 0 {
    states.push(cur)
    cur = came_from[cur]
  }
  states.rev_in_place()
  let pts : Array[@graph.Point] = []
  for s in states {
    let (ix, iy, _dir) = decode_state(s, x_len, y_len)
    pts.push(@graph.Point::new(xs[ix], ys[iy]))
  }
  pts
}

///|
fn compress_route(
  points : Array[@graph.Point],
  start : @graph.Point,
  goal : @graph.Point,
) -> Array[@graph.Point] {
  if points.length() == 0 {
    return []
  }
  if points.length() == 1 {
    return [start, goal]
  }
  let cleaned : Array[@graph.Point] = []
  cleaned.push(start)
  for i = 1; i < points.length() - 1; i = i + 1 {
    let prev = cleaned[cleaned.length() - 1]
    let cur = points[i]
    let next = points[i + 1]
    // Drop duplicates.
    if (cur.x - prev.x).abs() < 0.001 && (cur.y - prev.y).abs() < 0.001 {
      continue
    }
    // Drop collinear points.
    if (prev.x - cur.x).abs() < 0.001 && (cur.x - next.x).abs() < 0.001 {
      continue
    }
    if (prev.y - cur.y).abs() < 0.001 && (cur.y - next.y).abs() < 0.001 {
      continue
    }
    cleaned.push(cur)
  }
  cleaned.push(goal)
  cleaned
}

///|
fn route_hits_any_box(
  route : Array[@graph.Point],
  boxes : Array[@graph.Box],
) -> Bool {
  if route.length() < 2 {
    return false
  }
  for i = 0; i < route.length() - 1; i = i + 1 {
    if segment_hits_any_box(route[i], route[i + 1], boxes) {
      return true
    }
  }
  false
}
