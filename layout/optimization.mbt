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
// Parallel Edge Separation
// ============================================================================
// NOTE: Uses port_side_to_side_string from routing.mbt (same package)

///|
/// Ensure parallel edges (including bidirectional pairs) don't overlap.
/// This runs after obstacle routing and bend elimination, so it must not rely on
/// later cleanup passes.
fn separate_parallel_edges(graph : @graph.Graph) -> Unit {
  let edge_groups : Map[String, Array[@graph.Edge]] = {}
  for edge in graph.edges {
    if edge.route.length() < 2 {
      continue
    }
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
  let min_separation = 8.0 // Minimum separation between parallel edges
  for group in edge_groups.values() {
    if group.length() <= 1 {
      continue
    }

    // Strategy: Assign unique horizontal offsets to each edge in the group.
    // For bidirectional edges (A→B and B→A), offset them in opposite directions.
    // For same-direction duplicates, offset them incrementally.
    //
    // Group edges by direction to handle same-direction duplicates
    let forward_edges : Array[@graph.Edge] = []
    let backward_edges : Array[@graph.Edge] = []

    // Determine which direction is "forward" (smaller src_id first)
    let first_edge = group[0]
    let is_forward = first_edge.src_id < first_edge.dst_id
    for edge in group {
      let edge_is_forward = edge.src_id < edge.dst_id
      if edge_is_forward == is_forward {
        forward_edges.push(edge)
      } else {
        backward_edges.push(edge)
      }
    }

    // If we have both forward and backward edges, offset them to opposite sides
    // Forward edges go positive, backward edges go negative
    if forward_edges.length() > 0 && backward_edges.length() > 0 {
      // Offset all forward edges to positive side
      for i, edge in forward_edges {
        let offset = (i.to_double() + 0.5) * min_separation
        offset_edge_route(edge, offset)
      }
      // Offset all backward edges to negative side
      for i, edge in backward_edges {
        let offset = (i.to_double() + 0.5) * min_separation
        offset_edge_route(edge, -offset)
      }
    } else if forward_edges.length() > 1 {
      // Only same-direction edges - offset incrementally
      for i, edge in forward_edges {
        if i > 0 {
          let offset = i.to_double() * min_separation
          offset_edge_route(edge, offset)
        }
      }
    } else if backward_edges.length() > 1 {
      // Only same-direction edges - offset incrementally
      for i, edge in backward_edges {
        if i > 0 {
          let offset = i.to_double() * min_separation
          offset_edge_route(edge, -offset)
        }
      }
    }
  }
}

///|
/// Check if two routes are nearly identical (within tolerance)
fn routes_nearly_identical(
  r1 : Array[@graph.Point],
  r2 : Array[@graph.Point],
) -> Bool {
  if r1.length() != r2.length() {
    return false
  }
  let tolerance = 1.0
  for i in 0..<r1.length() {
    let dx = (r1[i].x - r2[i].x).abs()
    let dy = (r1[i].y - r2[i].y).abs()
    if dx > tolerance || dy > tolerance {
      return false
    }
  }
  true
}

///|
/// Offset an edge route to separate it from overlapping parallel edges.
/// For 2-point routes, adds intermediate waypoints to create a separated path.
/// For 3+ point routes, offsets the intermediate points.
fn offset_edge_route(edge : @graph.Edge, offset : Double) -> Unit {
  // Only offset routes with 3+ points (intermediate waypoints)
  // 2-point routes can't be offset without breaking perpendicularity
  if edge.route.length() < 3 {
    return
  }
  // Skip zero offset
  if offset.abs() < 0.1 {
    return
  }
  let p0 = edge.route[0]
  let p1 = edge.route[edge.route.length() - 1]
  let is_vertical = (p1.x - p0.x).abs() < (p1.y - p0.y).abs()
  // 3+ point route: offset intermediate points only
  let new_route : Array[@graph.Point] = []
  for i, p in edge.route {
    if i == 0 || i == edge.route.length() - 1 {
      // Keep endpoints as-is to maintain perpendicularity
      new_route.push(p)
    } else if is_vertical {
      // Vertical edge - offset intermediate points horizontally
      new_route.push(@graph.Point::new(p.x + offset, p.y))
    } else {
      // Horizontal edge - offset intermediate points vertically
      new_route.push(@graph.Point::new(p.x, p.y + offset))
    }
  }
  edge.route.clear()
  for p in new_route {
    edge.route.push(p)
  }
}

///|
/// Re-route edges that cross through unrelated nodes using A* maze routing
pub fn reroute_crossing_edges(graph : @graph.Graph) -> Unit {
  let canvas_bounds = compute_all_bounds(graph)
  for edge in graph.edges {
    if edge.route.length() < 2 {
      continue
    }
    // Check if this edge crosses any unrelated nodes
    if edge_crosses_unrelated_nodes(edge, graph) {
      // Try to re-route using maze routing
      route_fixed_ports_maze_with_extra_obstacles(edge, graph, canvas_bounds, [])
      |> ignore
    }
  }
}

///|
/// Check if an edge route crosses through any unrelated nodes
fn edge_crosses_unrelated_nodes(
  edge : @graph.Edge,
  graph : @graph.Graph,
) -> Bool {
  for i in 0..<(edge.route.length() - 1) {
    let p1 = edge.route[i]
    let p2 = edge.route[i + 1]
    for obj in graph.objects {
      if obj.id == edge.src_id || obj.id == edge.dst_id {
        continue
      }
      guard obj.box is Some(box) else { continue }
      if line_segment_crosses_box_interior(p1, p2, box) {
        return true
      }
    }
  }
  false
}

///|
/// Check if a line segment crosses through the interior of a box (not just touches edges)
fn line_segment_crosses_box_interior(
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
  // If both endpoints are outside on the same side, no intersection
  if (p1.x < left && p2.x < left) || (p1.x > right && p2.x > right) {
    return false
  }
  if (p1.y < top && p2.y < top) || (p1.y > bottom && p2.y > bottom) {
    return false
  }
  // Check if either endpoint is inside the box
  let p1_inside = p1.x > left && p1.x < right && p1.y > top && p1.y < bottom
  let p2_inside = p2.x > left && p2.x < right && p2.y > top && p2.y < bottom
  if p1_inside || p2_inside {
    return true
  }
  // Check line-box intersection using parametric clipping
  let dx = p2.x - p1.x
  let dy = p2.y - p1.y
  let mut t_min = 0.0
  let mut t_max = 1.0
  // Check x bounds
  if dx != 0.0 {
    let t1 = (left - p1.x) / dx
    let t2 = (right - p1.x) / dx
    let (tx_min, tx_max) = if t1 < t2 { (t1, t2) } else { (t2, t1) }
    t_min = if tx_min > t_min { tx_min } else { t_min }
    t_max = if tx_max < t_max { tx_max } else { t_max }
  } else if p1.x < left || p1.x > right {
    return false
  }
  // Check y bounds
  if dy != 0.0 {
    let t1 = (top - p1.y) / dy
    let t2 = (bottom - p1.y) / dy
    let (ty_min, ty_max) = if t1 < t2 { (t1, t2) } else { (t2, t1) }
    t_min = if ty_min > t_min { ty_min } else { t_min }
    t_max = if ty_max < t_max { ty_max } else { t_max }
  } else if p1.y < top || p1.y > bottom {
    return false
  }
  // If t_min <= t_max, segment crosses through interior
  t_min < t_max
}

///|
fn edges_overlap_min_sep(
  edge1 : @graph.Edge,
  edge2 : @graph.Edge,
  min_dist : Double,
) -> Bool {
  if edge1.route.length() < 2 || edge2.route.length() < 2 {
    return false
  }
  for i in 0..<(edge1.route.length() - 1) {
    let a1 = edge1.route[i]
    let a2 = edge1.route[i + 1]
    for j in 0..<(edge2.route.length() - 1) {
      let b1 = edge2.route[j]
      let b2 = edge2.route[j + 1]
      if parallel_segments_too_close(a1, a2, b1, b2, min_dist) {
        return true
      }
    }
  }
  false
}

///|
fn parallel_segments_too_close(
  a1 : @graph.Point,
  a2 : @graph.Point,
  b1 : @graph.Point,
  b2 : @graph.Point,
  min_dist : Double,
) -> Bool {
  let samples = 5
  for i in 0..=samples {
    let t1 = i.to_double() / samples.to_double()
    let p1_x = a1.x + t1 * (a2.x - a1.x)
    let p1_y = a1.y + t1 * (a2.y - a1.y)
    for j in 0..=samples {
      let t2 = j.to_double() / samples.to_double()
      let p2_x = b1.x + t2 * (b2.x - b1.x)
      let p2_y = b1.y + t2 * (b2.y - b1.y)
      let dx = p2_x - p1_x
      let dy = p2_y - p1_y
      let dist = (dx * dx + dy * dy).sqrt()
      if dist < min_dist {
        return true
      }
    }
  }
  false
}

///|
fn build_edge_corridor_obstacles(
  route : Array[@graph.Point],
  width : Double,
) -> Array[@graph.Box] {
  let boxes : Array[@graph.Box] = []
  if route.length() < 2 {
    return boxes
  }
  let half = width / 2.0
  let trim = 0.0
  for i = 0; i < route.length() - 1; i = i + 1 {
    let p0 = route[i]
    let p1 = route[i + 1]
    if (p0.x - p1.x).abs() < 0.001 {
      // Vertical segment
      let x = p0.x - half
      let y0 = if p0.y < p1.y { p0.y } else { p1.y }
      let y1 = if p0.y > p1.y { p0.y } else { p1.y }
      let y_start = y0 + trim
      let y_end = y1 - trim
      if y_end - y_start > 0.1 {
        boxes.push(@graph.Box::new(x, y_start, width, y_end - y_start))
      }
    } else if (p0.y - p1.y).abs() < 0.001 {
      // Horizontal segment
      let y = p0.y - half
      let x0 = if p0.x < p1.x { p0.x } else { p1.x }
      let x1 = if p0.x > p1.x { p0.x } else { p1.x }
      let x_start = x0 + trim
      let x_end = x1 - trim
      if x_end - x_start > 0.1 {
        boxes.push(@graph.Box::new(x_start, y, x_end - x_start, width))
      }
    }
  }
  // Block corners too (exclude endpoints).
  if route.length() >= 3 {
    for i = 1; i < route.length() - 1; i = i + 1 {
      let p = route[i]
      boxes.push(@graph.Box::new(p.x - half, p.y - half, width, width))
    }
  }
  boxes
}

///|
fn clip_obstacle_away_from_box(
  obstacle : @graph.Box,
  blocker : @graph.Box,
  margin : Double,
) -> Array[@graph.Box] {
  let expanded = expand_box(blocker, margin)
  let ox0 = obstacle.x
  let oy0 = obstacle.y
  let ox1 = obstacle.x + obstacle.width
  let oy1 = obstacle.y + obstacle.height
  let bx0 = expanded.x
  let by0 = expanded.y
  let bx1 = expanded.x + expanded.width
  let by1 = expanded.y + expanded.height
  let ix0 = if ox0 > bx0 { ox0 } else { bx0 }
  let ix1 = if ox1 < bx1 { ox1 } else { bx1 }
  let iy0 = if oy0 > by0 { oy0 } else { by0 }
  let iy1 = if oy1 < by1 { oy1 } else { by1 }
  if ix0 >= ix1 || iy0 >= iy1 {
    return [obstacle]
  }
  let out : Array[@graph.Box] = []
  // Cut along the long axis (corridor obstacles are thin rectangles).
  if obstacle.height >= obstacle.width {
    // Keep portion above intersection.
    let top_h = iy0 - oy0
    if top_h > 0.1 {
      out.push(@graph.Box::new(obstacle.x, oy0, obstacle.width, top_h))
    }
    // Keep portion below intersection.
    let bottom_h = oy1 - iy1
    if bottom_h > 0.1 {
      out.push(@graph.Box::new(obstacle.x, iy1, obstacle.width, bottom_h))
    }
  } else {
    // Keep portion left of intersection.
    let left_w = ix0 - ox0
    if left_w > 0.1 {
      out.push(@graph.Box::new(ox0, obstacle.y, left_w, obstacle.height))
    }
    // Keep portion right of intersection.
    let right_w = ox1 - ix1
    if right_w > 0.1 {
      out.push(@graph.Box::new(ix1, obstacle.y, right_w, obstacle.height))
    }
  }
  out
}

///|
/// Route edge with fixed ports using maze router, with extra obstacles
/// IMPORTANT: Uses assigned port sides from Phase 6.5 to guarantee perpendicularity
fn route_fixed_ports_maze_with_extra_obstacles(
  edge : @graph.Edge,
  graph : @graph.Graph,
  canvas_bounds : (Double, Double, Double, Double),
  extra_obstacles : Array[@graph.Box],
) -> Bool {
  if edge.route.length() < 2 {
    return false
  }
  let src_obj = graph.find_object(edge.src_id)
  let dst_obj = graph.find_object(edge.dst_id)
  guard src_obj is Some(so) else { return false }
  guard dst_obj is Some(dst_obj1) else { return false }
  guard so.box is Some(src_box) else { return false }
  guard dst_obj1.box is Some(dst_box) else { return false }
  let start = edge.route[0]
  let goal = edge.route[edge.route.length() - 1]

  // Use assigned port sides from Phase 6.5 if available
  let start_side = match edge.src_port {
    Some(port) => port_side_to_side_string(port.side)
    None => get_endpoint_side(start, src_box, 2.0)
  }
  let goal_side = match edge.dst_port {
    Some(port) => port_side_to_side_string(port.side)
    None => get_endpoint_side(goal, dst_box, 2.0)
  }

  // Base obstacles: all node boxes except endpoints (+ SQL parent skip).
  let src_parent = get_parent_id_from_field(edge.src_id)
  let dst_parent = get_parent_id_from_field(edge.dst_id)
  let node_obstacles : Array[@graph.Box] = []
  for obj in graph.objects {
    if obj.id == edge.src_id || obj.id == edge.dst_id {
      continue
    }
    if src_parent is Some(p) && obj.id == p {
      continue
    }
    if dst_parent is Some(p) && obj.id == p {
      continue
    }
    guard obj.box is Some(box) else { continue }
    node_obstacles.push(box)
  }

  // Clip extra obstacles so they don't block leaving/entering the endpoints.
  // This keeps the "corridor" effective while allowing attachment near nodes.
  let filtered_extra : Array[@graph.Box] = []
  for b in extra_obstacles {
    let parts1 = clip_obstacle_away_from_box(b, src_box, 2.0)
    for p1 in parts1 {
      let parts2 = clip_obstacle_away_from_box(p1, dst_box, 2.0)
      for p2 in parts2 {
        filtered_extra.push(p2)
      }
    }
  }

  // Expand node obstacles by a clearance; keep edge-corridor obstacles as-is.
  for node_clearance in [2.0, 1.0, 0.0] {
    let obstacles : Array[@graph.Box] = []
    for b in node_obstacles {
      obstacles.push(expand_box(b, node_clearance))
    }
    for b in filtered_extra {
      obstacles.push(b)
    }
    let path_opt = astar_route_orthogonal(
      start, goal, start_side, goal_side, src_box, dst_box, obstacles, canvas_bounds,
      0.0,
    )
    match path_opt {
      None => ()
      Some(path) => {
        edge.route.clear()
        for pt in path {
          edge.route.push(pt)
        }
        return true
      }
    }
  }
  false
}

///|
/// Route edge with port offset using maze router, with extra obstacles
/// IMPORTANT: Uses assigned port sides from Phase 6.5 to guarantee perpendicularity
fn route_maze_with_port_offset_and_extra_obstacles(
  edge : @graph.Edge,
  graph : @graph.Graph,
  canvas_bounds : (Double, Double, Double, Double),
  extra_obstacles : Array[@graph.Box],
  port_offset : Double,
) -> Bool {
  if edge.route.length() < 2 {
    return false
  }
  let src_obj = graph.find_object(edge.src_id)
  let dst_obj = graph.find_object(edge.dst_id)
  guard src_obj is Some(so) else { return false }
  guard dst_obj is Some(dst_obj1) else { return false }
  guard so.box is Some(src_box) else { return false }
  guard dst_obj1.box is Some(dst_box) else { return false }

  // Use assigned port sides from Phase 6.5 if available (keep same side, shift position)
  let current_start = edge.route[0]
  let current_goal = edge.route[edge.route.length() - 1]
  let (default_src_anchor, default_dst_anchor) = calculate_best_anchors(
    src_box, dst_box,
  )

  // Get start side from assigned port or detect geometrically
  let start_side = match edge.src_port {
    Some(port) => port_side_to_side_string(port.side)
    None => {
      let start_side0 = get_endpoint_side(current_start, src_box, 2.0)
      match start_side0 {
        "top" | "bottom" | "left" | "right" => start_side0
        _ => edge.src_anchor.unwrap_or(default_src_anchor)
      }
    }
  }

  // Get goal side from assigned port or detect geometrically
  let goal_side = match edge.dst_port {
    Some(port) => port_side_to_side_string(port.side)
    None => {
      let goal_side0 = get_endpoint_side(current_goal, dst_box, 2.0)
      match goal_side0 {
        "top" | "bottom" | "left" | "right" => goal_side0
        _ => edge.dst_anchor.unwrap_or(default_dst_anchor)
      }
    }
  }
  let start = get_anchor_point(src_box, start_side, port_offset)
  let goal = get_anchor_point(dst_box, goal_side, port_offset)

  // Base obstacles: all node boxes except endpoints (+ SQL parent skip).
  let src_parent = get_parent_id_from_field(edge.src_id)
  let dst_parent = get_parent_id_from_field(edge.dst_id)
  let node_obstacles : Array[@graph.Box] = []
  for obj in graph.objects {
    if obj.id == edge.src_id || obj.id == edge.dst_id {
      continue
    }
    if src_parent is Some(p) && obj.id == p {
      continue
    }
    if dst_parent is Some(p) && obj.id == p {
      continue
    }
    guard obj.box is Some(box) else { continue }
    node_obstacles.push(box)
  }

  // Clip extra obstacles so they don't block leaving/entering the endpoints.
  let filtered_extra : Array[@graph.Box] = []
  for b in extra_obstacles {
    let parts1 = clip_obstacle_away_from_box(b, src_box, 2.0)
    for p1 in parts1 {
      let parts2 = clip_obstacle_away_from_box(p1, dst_box, 2.0)
      for p2 in parts2 {
        filtered_extra.push(p2)
      }
    }
  }

  // Expand node obstacles by a clearance; keep edge-corridor obstacles as-is.
  for node_clearance in [2.0, 1.0, 0.0] {
    let obstacles : Array[@graph.Box] = []
    for b in node_obstacles {
      obstacles.push(expand_box(b, node_clearance))
    }
    for b in filtered_extra {
      obstacles.push(b)
    }
    let path_opt = astar_route_orthogonal(
      start, goal, start_side, goal_side, src_box, dst_box, obstacles, canvas_bounds,
      0.0,
    )
    match path_opt {
      None => ()
      Some(path) => {
        edge.route.clear()
        for pt in path {
          edge.route.push(pt)
        }
        return true
      }
    }
  }
  false
}

///|
/// Attempt to reroute around obstacle, return false if no valid bypass found
fn reroute_around_obstacle_with_fallback(
  edge : @graph.Edge,
  obstacle : @graph.Box,
  graph : @graph.Graph,
  _canvas_bounds : (Double, Double, Double, Double),
) -> Bool {
  if edge.route.length() < 2 {
    return false
  }
  // Find the segment that intersects the obstacle
  for i = 0; i < edge.route.length() - 1; i = i + 1 {
    let p0 = edge.route[i]
    let p1 = edge.route[i + 1]
    if line_intersects_box(p0, p1, obstacle) {
      // Calculate bypass routes and pick the best one
      let bypass_opt = calculate_best_bypass_opt(p0, p1, obstacle, edge, graph)
      match bypass_opt {
        Some(bypass) => {
          // Replace segment with bypass route
          let new_route : Array[@graph.Point] = []
          for j = 0; j <= i; j = j + 1 {
            new_route.push(edge.route[j])
          }
          for pt in bypass {
            new_route.push(pt)
          }
          for j = i + 1; j < edge.route.length(); j = j + 1 {
            new_route.push(edge.route[j])
          }
          edge.route.clear()
          for pt in new_route {
            edge.route.push(pt)
          }
          return true // Successfully rerouted
        }
        None => return false // No valid bypass found
      }
    }
  }
  true // No intersection found (shouldn't happen, but safe default)
}

///|
/// Determine which side of a box a point is on (for endpoint approach direction)
/// Returns: "top", "bottom", "left", "right", or "none" if not on any edge
fn get_endpoint_side(
  point : @graph.Point,
  box : @graph.Box,
  tolerance : Double,
) -> String {
  let on_top = (point.y - box.y).abs() < tolerance
  let on_bottom = (point.y - (box.y + box.height)).abs() < tolerance
  let on_left = (point.x - box.x).abs() < tolerance
  let on_right = (point.x - (box.x + box.width)).abs() < tolerance
  // Prefer vertical sides (top/bottom) when point is on a corner
  if on_top {
    "top"
  } else if on_bottom {
    "bottom"
  } else if on_left {
    "left"
  } else if on_right {
    "right"
  } else {
    "none"
  }
}

///|
/// Calculate the best bypass route around an obstacle, returning None if no valid bypass
/// Respects endpoint side: only allows bypass routes that approach from the correct direction
/// IMPORTANT: Uses assigned port sides from Phase 6.5 to guarantee perpendicularity
fn calculate_best_bypass_opt(
  p0 : @graph.Point,
  p1 : @graph.Point,
  obstacle : @graph.Box,
  edge : @graph.Edge,
  graph : @graph.Graph,
) -> Array[@graph.Point]? {
  // Determine which side the endpoint (p1) is on, if this is the last segment
  // This ensures the bypass approach direction matches the endpoint's side
  let last_point = edge.route[edge.route.length() - 1]
  let first_point = edge.route[0]
  let is_last_segment = (p1.x - last_point.x).abs() < 1.0 &&
    (p1.y - last_point.y).abs() < 1.0
  let is_first_segment = (p0.x - first_point.x).abs() < 1.0 &&
    (p0.y - first_point.y).abs() < 1.0

  // IMPORTANT: Use assigned port sides from Phase 6.5 if available
  // This ensures perpendicularity is maintained even after bypass routing
  let endpoint_side = if is_last_segment {
    // Check for assigned destination port first
    match edge.dst_port {
      Some(port) => port_side_to_side_string(port.side)
      None => {
        // Fallback to geometric detection
        let dst_obj = graph.find_object(edge.dst_id)
        match dst_obj {
          Some(obj) =>
            match obj.box {
              Some(box) => get_endpoint_side(p1, box, 2.0)
              None => "none"
            }
          None => "none"
        }
      }
    }
  } else {
    "none" // Not the last segment, no constraint
  }

  // Also check source side constraint for first segment
  let source_side = if is_first_segment {
    match edge.src_port {
      Some(port) => port_side_to_side_string(port.side)
      None => {
        let src_obj = graph.find_object(edge.src_id)
        match src_obj {
          Some(obj) =>
            match obj.box {
              Some(box) => get_endpoint_side(p0, box, 2.0)
              None => "none"
            }
          None => "none"
        }
      }
    }
  } else {
    "none" // Not the first segment, no constraint
  }

  // Helper to check if bypass first segment respects source side
  fn bypass_respects_source_side(
    p0 : @graph.Point,
    bypass : Array[@graph.Point],
    source_side : String,
  ) -> Bool {
    if source_side == "none" || bypass.is_empty() {
      return true
    }
    let first_pt = bypass[0]
    let dx = first_pt.x - p0.x
    let dy = first_pt.y - p0.y
    let tolerance = 0.01
    // Check that exit direction matches source side
    // bottom: must exit downward (dy > 0)
    // top: must exit upward (dy < 0)
    // left: must exit leftward (dx < 0)
    // right: must exit rightward (dx > 0)
    match source_side {
      "bottom" => dy.abs() > tolerance && (dx.abs() < tolerance || dy > 0.0)
      "top" => dy.abs() > tolerance && (dx.abs() < tolerance || dy < 0.0)
      "left" => dx.abs() > tolerance && (dy.abs() < tolerance || dx < 0.0)
      "right" => dx.abs() > tolerance && (dy.abs() < tolerance || dx > 0.0)
      _ => true
    }
  }

  // Try multiple margin sizes for more options
  for margin in [10.0, 20.0, 40.0] {
    let obs_left = obstacle.x - margin
    let obs_right = obstacle.x + obstacle.width + margin
    let obs_top = obstacle.y - margin
    let obs_bottom = obstacle.y + obstacle.height + margin
    // Try bypass routes based on endpoint side constraint
    let routes : Array[Array[@graph.Point]] = []
    // Route 1: Go above obstacle → approaches from above (dy > 0) → for TOP edge
    // Only add if endpoint is on TOP or no constraint
    if (endpoint_side == "top" || endpoint_side == "none") &&
      (p0.x - p1.x).abs() > 1.0 {
      routes.push([
        @graph.Point::new(p0.x, obs_top),
        @graph.Point::new(p1.x, obs_top),
      ])
    }
    // Route 2: Go below obstacle → approaches from below (dy < 0) → for BOTTOM edge
    if (endpoint_side == "bottom" || endpoint_side == "none") &&
      (p0.x - p1.x).abs() > 1.0 {
      routes.push([
        @graph.Point::new(p0.x, obs_bottom),
        @graph.Point::new(p1.x, obs_bottom),
      ])
    }
    // Route 3: Go left of obstacle → approaches from left (dx > 0) → for LEFT edge
    if (endpoint_side == "left" || endpoint_side == "none") &&
      (p0.y - p1.y).abs() > 1.0 {
      routes.push([
        @graph.Point::new(obs_left, p0.y),
        @graph.Point::new(obs_left, p1.y),
      ])
    }
    // Route 4: Go right of obstacle → approaches from right (dx < 0) → for RIGHT edge
    if (endpoint_side == "right" || endpoint_side == "none") &&
      (p0.y - p1.y).abs() > 1.0 {
      routes.push([
        @graph.Point::new(obs_right, p0.y),
        @graph.Point::new(obs_right, p1.y),
      ])
    }
    // Additional corner routes for complex obstacle configurations
    if endpoint_side == "none" || endpoint_side == "top" {
      // Route via top-left corner
      routes.push([
        @graph.Point::new(obs_left, p0.y),
        @graph.Point::new(obs_left, obs_top),
        @graph.Point::new(p1.x, obs_top),
      ])
      // Route via top-right corner
      routes.push([
        @graph.Point::new(obs_right, p0.y),
        @graph.Point::new(obs_right, obs_top),
        @graph.Point::new(p1.x, obs_top),
      ])
    }
    if endpoint_side == "none" || endpoint_side == "bottom" {
      // Route via bottom-left corner
      routes.push([
        @graph.Point::new(obs_left, p0.y),
        @graph.Point::new(obs_left, obs_bottom),
        @graph.Point::new(p1.x, obs_bottom),
      ])
      // Route via bottom-right corner
      routes.push([
        @graph.Point::new(obs_right, p0.y),
        @graph.Point::new(obs_right, obs_bottom),
        @graph.Point::new(p1.x, obs_bottom),
      ])
    }
    if endpoint_side == "none" || endpoint_side == "left" {
      // Route via left-top corner
      routes.push([
        @graph.Point::new(p0.x, obs_top),
        @graph.Point::new(obs_left, obs_top),
        @graph.Point::new(obs_left, p1.y),
      ])
      // Route via left-bottom corner
      routes.push([
        @graph.Point::new(p0.x, obs_bottom),
        @graph.Point::new(obs_left, obs_bottom),
        @graph.Point::new(obs_left, p1.y),
      ])
    }
    if endpoint_side == "none" || endpoint_side == "right" {
      // Route via right-top corner
      routes.push([
        @graph.Point::new(p0.x, obs_top),
        @graph.Point::new(obs_right, obs_top),
        @graph.Point::new(obs_right, p1.y),
      ])
      // Route via right-bottom corner
      routes.push([
        @graph.Point::new(p0.x, obs_bottom),
        @graph.Point::new(obs_right, obs_bottom),
        @graph.Point::new(obs_right, p1.y),
      ])
    }
    // Fallback for degenerate segments - create routes matching endpoint side
    if routes.is_empty() {
      // For degenerate segments, we need a 3-point bypass to change approach direction
      // This handles vertical segments to top/bottom and horizontal segments to left/right
      if endpoint_side == "top" {
        // Vertical segment to TOP: go left/right, then up, then to endpoint
        routes.push([
          @graph.Point::new(obs_left, p0.y),
          @graph.Point::new(obs_left, obs_top),
          @graph.Point::new(p1.x, obs_top),
        ])
      } else if endpoint_side == "bottom" {
        // Vertical segment to BOTTOM: go left/right, then down, then to endpoint
        routes.push([
          @graph.Point::new(obs_left, p0.y),
          @graph.Point::new(obs_left, obs_bottom),
          @graph.Point::new(p1.x, obs_bottom),
        ])
      } else if endpoint_side == "left" {
        // Horizontal segment to LEFT: go up/down, then left, then to endpoint
        routes.push([
          @graph.Point::new(p0.x, obs_top),
          @graph.Point::new(obs_left, obs_top),
          @graph.Point::new(obs_left, p1.y),
        ])
      } else if endpoint_side == "right" {
        // Horizontal segment to RIGHT: go up/down, then right, then to endpoint
        routes.push([
          @graph.Point::new(p0.x, obs_top),
          @graph.Point::new(obs_right, obs_top),
          @graph.Point::new(obs_right, p1.y),
        ])
      } else {
        // No constraint - use simple bypass
        routes.push([
          @graph.Point::new(p0.x, obs_top),
          @graph.Point::new(p1.x, obs_top),
        ])
      }
    }
    // Find the shortest valid route that respects BOTH source and destination constraints
    let mut best_route : Array[@graph.Point]? = None
    let mut best_length = 1.0e10
    for route in routes {
      // Check that route respects source side constraint (for first segment)
      if !bypass_respects_source_side(p0, route, source_side) {
        continue
      }
      if is_bypass_valid(p0, route, p1, edge, graph) {
        let length = bypass_length(p0, route, p1)
        if length < best_length {
          best_length = length
          best_route = Some(route)
        }
      }
    }
    if best_route is Some(_) {
      return best_route
    }
  }
  None // No valid bypass found at any margin
}

///|
/// Find the first obstacle (object box) that the edge route intersects
fn find_intersecting_obstacle(
  edge : @graph.Edge,
  graph : @graph.Graph,
) -> @graph.Box? {
  if edge.route.length() < 2 {
    return None
  }
  // For SQL table field connections (e.g., users.id), also skip the parent table
  let src_parent = get_parent_id_from_field(edge.src_id)
  let dst_parent = get_parent_id_from_field(edge.dst_id)
  for i = 0; i < edge.route.length() - 1; i = i + 1 {
    let p0 = edge.route[i]
    let p1 = edge.route[i + 1]
    for obj in graph.objects {
      // Skip source and destination objects (and their parent tables)
      if obj.id == edge.src_id || obj.id == edge.dst_id {
        continue
      }
      if src_parent is Some(p) && obj.id == p {
        continue
      }
      if dst_parent is Some(p) && obj.id == p {
        continue
      }
      // Skip objects without boxes
      guard obj.box is Some(box) else { continue }
      if line_intersects_box(p0, p1, box) {
        return Some(box)
      }
    }
  }
  None
}

///|
/// Check if a bypass route is valid (doesn't intersect other obstacles)
fn is_bypass_valid(
  start : @graph.Point,
  bypass : Array[@graph.Point],
  end : @graph.Point,
  edge : @graph.Edge,
  graph : @graph.Graph,
) -> Bool {
  // For SQL table field connections, get parent IDs to skip
  let src_parent = get_parent_id_from_field(edge.src_id)
  let dst_parent = get_parent_id_from_field(edge.dst_id)
  // Check segment from start to first bypass point
  if bypass.length() > 0 {
    if line_intersects_objects_with_skip(
        start,
        bypass[0],
        graph,
        edge,
        src_parent,
        dst_parent,
      ) {
      return false
    }
    // Check segments between bypass points
    for i = 0; i < bypass.length() - 1; i = i + 1 {
      if line_intersects_objects_with_skip(
          bypass[i],
          bypass[i + 1],
          graph,
          edge,
          src_parent,
          dst_parent,
        ) {
        return false
      }
    }
    // Check segment from last bypass point to end
    if line_intersects_objects_with_skip(
        bypass[bypass.length() - 1],
        end,
        graph,
        edge,
        src_parent,
        dst_parent,
      ) {
      return false
    }
  }
  true
}

///|
/// Calculate total length of a bypass route
fn bypass_length(
  start : @graph.Point,
  bypass : Array[@graph.Point],
  end : @graph.Point,
) -> Double {
  let mut total = 0.0
  let mut prev = start
  for pt in bypass {
    let dx = pt.x - prev.x
    let dy = pt.y - prev.y
    total = total + (dx * dx + dy * dy).sqrt()
    prev = pt
  }
  let dx = end.x - prev.x
  let dy = end.y - prev.y
  total = total + (dx * dx + dy * dy).sqrt()
  total
}
