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
// Route Optimization
// ============================================================================

///|
/// Re-route edges that cross through unrelated nodes using A* maze routing.
#warnings("-unused_value")
fn reroute_crossing_edges(graph : Graph) -> Unit {
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
fn edge_crosses_unrelated_nodes(edge : Edge, graph : Graph) -> Bool {
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
  edge : Edge,
  graph : Graph,
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
