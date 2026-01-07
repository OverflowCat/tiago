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
/// Unified Edge Router - Single Source of Truth
///
/// This module provides a unified edge routing system that:
/// - Routes all edges in a single pass
/// - Enforces orthogonality by construction (impossible to create diagonals)
/// - Handles obstacle avoidance during initial routing
/// - Handles parallel edge separation during routing
/// - Guarantees perpendicularity at endpoints via port constraints

// ============================================================================
// Orthogonal Route Builder - Enforces orthogonality by construction
// ============================================================================

///|
/// Direction of the last segment in a route being built
priv enum RouteDirection {
  None // Starting point
  Horizontal // Last segment was horizontal
  Vertical // Last segment was vertical
} derive(Eq)

///|
/// Builder that constructs orthogonal routes.
/// By only providing extend_horizontal and extend_vertical methods,
/// diagonal segments become impossible by construction.
priv struct OrthogonalRouteBuilder {
  points : Array[@graph.Point]
  mut last_direction : RouteDirection
}

///|
fn OrthogonalRouteBuilder::new(start : @graph.Point) -> OrthogonalRouteBuilder {
  { points: [start], last_direction: None }
}

///|
/// Extend route horizontally to the given x coordinate.
/// The y coordinate stays the same as the last point.
fn OrthogonalRouteBuilder::extend_horizontal(
  self : OrthogonalRouteBuilder,
  x : Double,
) -> Unit {
  let last = self.points[self.points.length() - 1]
  // Skip if x is same as current x (no movement)
  if (x - last.x).abs() < 0.001 {
    return
  }
  // If last direction was also horizontal, update the last point instead of adding new one
  if self.last_direction == Horizontal && self.points.length() > 1 {
    let idx = self.points.length() - 1
    self.points[idx] = @graph.Point::new(x, last.y)
  } else {
    self.points.push(@graph.Point::new(x, last.y))
  }
  self.last_direction = Horizontal
}

///|
/// Extend route vertically to the given y coordinate.
/// The x coordinate stays the same as the last point.
fn OrthogonalRouteBuilder::extend_vertical(
  self : OrthogonalRouteBuilder,
  y : Double,
) -> Unit {
  let last = self.points[self.points.length() - 1]
  // Skip if y is same as current y (no movement)
  if (y - last.y).abs() < 0.001 {
    return
  }
  // If last direction was also vertical, update the last point instead of adding new one
  if self.last_direction == Vertical && self.points.length() > 1 {
    let idx = self.points.length() - 1
    self.points[idx] = @graph.Point::new(last.x, y)
  } else {
    self.points.push(@graph.Point::new(last.x, y))
  }
  self.last_direction = Vertical
}

///|
/// Finish the route by adding the final destination point.
/// Ensures the final segment is perpendicular based on the destination side.
fn OrthogonalRouteBuilder::finish(
  self : OrthogonalRouteBuilder,
  end : @graph.Point,
  end_side : @graph.PortSide,
) -> Array[@graph.Point] {
  let last = self.points[self.points.length() - 1]
  // If already at destination, just return
  if (last.x - end.x).abs() < 0.001 && (last.y - end.y).abs() < 0.001 {
    return self.points
  }
  // Ensure final segment is perpendicular to the destination side
  match end_side {
    @graph.Top | @graph.Bottom => {
      // Need vertical approach - first go horizontal to align x, then vertical
      if (last.x - end.x).abs() > 0.001 {
        self.extend_horizontal(end.x)
      }
      self.extend_vertical(end.y)
    }
    @graph.Left | @graph.Right => {
      // Need horizontal approach - first go vertical to align y, then horizontal
      if (last.y - end.y).abs() > 0.001 {
        self.extend_vertical(end.y)
      }
      self.extend_horizontal(end.x)
    }
  }
  self.points
}

///|
/// Get the current endpoint of the route being built
fn OrthogonalRouteBuilder::current_point(
  self : OrthogonalRouteBuilder,
) -> @graph.Point {
  self.points[self.points.length() - 1]
}

// ============================================================================
// Helper Functions
// ============================================================================

///|
fn double_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn double_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

// ============================================================================
// Simple Routing (L-shape and Z-shape)
// ============================================================================

///|
/// Create a simple orthogonal route between two ports.
/// Uses L-shape or Z-shape depending on port sides.
/// No obstacle avoidance - assumes direct path is clear.
fn route_simple(
  src : @graph.Point,
  dst : @graph.Point,
  src_side : @graph.PortSide,
  dst_side : @graph.PortSide,
  offset : Double,
) -> Array[@graph.Point] {
  let builder = OrthogonalRouteBuilder::new(src)
  match (src_side, dst_side) {
    // Both vertical sides (Top/Bottom) - Z-shape with horizontal middle
    (@graph.Top, @graph.Top) | (@graph.Bottom, @graph.Bottom) => {
      let mid_y = (src.y + dst.y) / 2.0 + offset
      builder.extend_vertical(mid_y)
      builder.extend_horizontal(dst.x)
    }
    (@graph.Bottom, @graph.Top) =>
      // Normal downward flow
      if src.y < dst.y {
        // Direct Z-shape
        let mid_y = (src.y + dst.y) / 2.0 + offset
        builder.extend_vertical(mid_y)
        builder.extend_horizontal(dst.x)
      } else {
        // Need to go around (reversed flow)
        let detour_y = double_max(src.y, dst.y) + 30.0 + offset.abs()
        builder.extend_vertical(detour_y)
        builder.extend_horizontal(dst.x)
      }
    (@graph.Top, @graph.Bottom) =>
      // Upward flow
      if src.y > dst.y {
        // Direct Z-shape
        let mid_y = (src.y + dst.y) / 2.0 + offset
        builder.extend_vertical(mid_y)
        builder.extend_horizontal(dst.x)
      } else {
        // Need to go around (reversed flow)
        let detour_y = double_min(src.y, dst.y) - 30.0 - offset.abs()
        builder.extend_vertical(detour_y)
        builder.extend_horizontal(dst.x)
      }
    // Both horizontal sides (Left/Right) - Z-shape with vertical middle
    (@graph.Left, @graph.Left) | (@graph.Right, @graph.Right) => {
      let mid_x = (src.x + dst.x) / 2.0 + offset
      builder.extend_horizontal(mid_x)
      builder.extend_vertical(dst.y)
    }
    (@graph.Right, @graph.Left) =>
      // Normal rightward flow
      if src.x < dst.x {
        let mid_x = (src.x + dst.x) / 2.0 + offset
        builder.extend_horizontal(mid_x)
        builder.extend_vertical(dst.y)
      } else {
        // Need to go around
        let detour_x = double_max(src.x, dst.x) + 30.0 + offset.abs()
        builder.extend_horizontal(detour_x)
        builder.extend_vertical(dst.y)
      }
    (@graph.Left, @graph.Right) =>
      // Leftward flow
      if src.x > dst.x {
        let mid_x = (src.x + dst.x) / 2.0 + offset
        builder.extend_horizontal(mid_x)
        builder.extend_vertical(dst.y)
      } else {
        // Need to go around
        let detour_x = double_min(src.x, dst.x) - 30.0 - offset.abs()
        builder.extend_horizontal(detour_x)
        builder.extend_vertical(dst.y)
      }
    // Mixed sides - L-shape
    (@graph.Bottom, @graph.Left) | (@graph.Bottom, @graph.Right) =>
      // Exit bottom, enter horizontal - go vertical first, then horizontal
      builder.extend_vertical(dst.y + offset)
    (@graph.Top, @graph.Left) | (@graph.Top, @graph.Right) =>
      // Exit top, enter horizontal - go vertical first, then horizontal
      builder.extend_vertical(dst.y + offset)
    (@graph.Left, @graph.Top) | (@graph.Left, @graph.Bottom) =>
      // Exit left, enter vertical - go horizontal first, then vertical
      builder.extend_horizontal(dst.x + offset)
    (@graph.Right, @graph.Top) | (@graph.Right, @graph.Bottom) =>
      // Exit right, enter vertical - go horizontal first, then vertical
      builder.extend_horizontal(dst.x + offset)
  }
  builder.finish(dst, dst_side)
}

// ============================================================================
// Parallel Edge Handling
// ============================================================================

///|
/// Group edges by their source-destination pair for parallel edge handling.
/// Uses normalized key (sorted src/dst) so both A->B and B->A go in same group.
fn group_parallel_edges(
  graph : @graph.Graph,
) -> Map[String, Array[@graph.Edge]] {
  let groups : Map[String, Array[@graph.Edge]] = {}
  for edge in graph.edges {
    // Normalize key so A->B and B->A have same key
    let key = if edge.src_id <= edge.dst_id {
      edge.src_id + "||" + edge.dst_id
    } else {
      edge.dst_id + "||" + edge.src_id
    }
    match groups.get(key) {
      Some(arr) => arr.push(edge)
      None => groups[key] = [edge]
    }
  }
  groups
}

///|
/// Calculate parallel edge offset for a given index in a group.
/// Uses alternating pattern: 0, +spacing/2, -spacing/2, +spacing, -spacing, ...
fn calculate_parallel_offset(index : Int, group_size : Int) -> Double {
  if group_size <= 1 || index == 0 {
    return 0.0
  }
  let spacing = 15.0 // Minimum separation between parallel edges
  let sign = if index % 2 == 1 { 1.0 } else { -1.0 }
  let slot = ((index + 1) / 2).to_double()
  sign * slot * spacing
}

// ============================================================================
// Obstacle Avoidance
// ============================================================================

///|
/// Collect obstacles for routing an edge (all nodes except source and destination)
fn collect_obstacles(
  graph : @graph.Graph,
  src_id : String,
  dst_id : String,
) -> Array[@graph.Box] {
  let obstacles : Array[@graph.Box] = []
  for obj in graph.objects {
    // Skip source and destination nodes
    if obj.id == src_id || obj.id == dst_id {
      continue
    }
    // Skip children of source/destination (for SQL table fields)
    if is_field_of_table(obj.id, src_id) || is_field_of_table(obj.id, dst_id) {
      continue
    }
    if obj.box is Some(box) {
      obstacles.push(box)
    }
  }
  obstacles
}

///|
/// Check if obj_id is a field of table_id (e.g., "users.id" is field of "users")
fn is_field_of_table(obj_id : String, table_id : String) -> Bool {
  obj_id.has_prefix(table_id + ".")
}

///|
/// Check if an object ID refers to a field rendered inline inside an sql_table.
fn is_sql_table_child_id(graph : @graph.Graph, obj_id : String) -> Bool {
  match get_parent_id_from_field(obj_id) {
    Some(parent_id) =>
      match graph.find_object(parent_id) {
        Some(parent) => parent.shape_type == @graph.SqlTable
        None => false
      }
    None => false
  }
}

///|
/// True if this object should be treated as a leaf obstacle during edge routing.
/// Containers are allowed to be crossed; leaf nodes must be avoided.
fn is_leaf_obstacle_node(obj : @graph.Object) -> Bool {
  // sql_table renders children as rows, but the table itself behaves like a leaf node visually.
  if obj.shape_type == @graph.SqlTable {
    return true
  }
  not(obj.is_container())
}

///|
/// Check if a route intersects any obstacle
fn route_intersects_obstacles(
  route : Array[@graph.Point],
  obstacles : Array[@graph.Box],
  clearance : Double,
) -> Bool {
  if route.length() < 2 {
    return false
  }
  for i in 0..<(route.length() - 1) {
    let p0 = route[i]
    let p1 = route[i + 1]
    for obs in obstacles {
      let expanded = expand_box_by(obs, clearance)
      if line_segment_strictly_intersects_box(p0, p1, expanded) {
        return true
      }
    }
  }
  false
}

///|
/// Expand a box by a margin on all sides
fn expand_box_by(box : @graph.Box, margin : Double) -> @graph.Box {
  @graph.Box::new(
    box.x - margin,
    box.y - margin,
    box.width + margin * 2.0,
    box.height + margin * 2.0,
  )
}

///|
fn shrink_box_by(box : @graph.Box, margin : Double) -> @graph.Box {
  let width = box.width - margin * 2.0
  let height = box.height - margin * 2.0
  if width <= 0.0 || height <= 0.0 {
    return box
  }
  @graph.Box::new(box.x + margin, box.y + margin, width, height)
}

///|
/// Check if a line segment strictly intersects the interior of a box.
/// Touching the boundary is allowed.
fn line_segment_strictly_intersects_box(
  p0 : @graph.Point,
  p1 : @graph.Point,
  box : @graph.Box,
) -> Bool {
  // Quick bounding box check
  let min_x = double_min(p0.x, p1.x)
  let max_x = double_max(p0.x, p1.x)
  let min_y = double_min(p0.y, p1.y)
  let max_y = double_max(p0.y, p1.y)
  let box_max_x = box.x + box.width
  let box_max_y = box.y + box.height
  // No overlap at all
  if max_x < box.x || min_x > box_max_x || max_y < box.y || min_y > box_max_y {
    return false
  }
  // Check if segment passes through interior
  // Use parametric line clipping (Cohen-Sutherland style)
  let dx = p1.x - p0.x
  let dy = p1.y - p0.y
  let margin = 1.0 // Allow boundary touch
  let inner_box = @graph.Box::new(
    box.x + margin,
    box.y + margin,
    double_max(box.width - margin * 2.0, 0.0),
    double_max(box.height - margin * 2.0, 0.0),
  )
  // Check if the line actually passes through the inner box
  // Simple approach: check multiple sample points along the segment
  for i in 1..<10 {
    let t = i.to_double() / 10.0
    let px = p0.x + dx * t
    let py = p0.y + dy * t
    if px > inner_box.x &&
      px < inner_box.x + inner_box.width &&
      py > inner_box.y &&
      py < inner_box.y + inner_box.height {
      return true
    }
  }
  false
}

// ============================================================================
// A* Maze Routing (moved from routing.mbt, integrated here)
// ============================================================================

///|
/// A* search entry for priority queue
priv struct AStarState {
  f : Double
  g : Double
  state : Int
} derive(Eq, Show)

///|
impl Compare for AStarState with compare(a, b) {
  let c1 = a.f.compare(b.f)
  if c1 != 0 {
    c1
  } else {
    a.g.compare(b.g)
  }
}

///|
/// Get required initial direction based on source port side
/// Direction encoding: 0=start, 1=right, 2=left, 3=down, 4=up
fn get_required_start_directions(src_side : @graph.PortSide) -> Array[Int] {
  match src_side {
    @graph.Top => [4] // Must start by going up (leaving from top)
    @graph.Bottom => [3] // Must start by going down (leaving from bottom)
    @graph.Left => [2] // Must start by going left (leaving from left)
    @graph.Right => [1] // Must start by going right (leaving from right)
  }
}

///|
/// Check if a direction is allowed for the first move based on source port side
fn is_valid_start_direction(dir : Int, src_side : @graph.PortSide) -> Bool {
  get_required_start_directions(src_side).contains(dir)
}

///|
/// Route using A* maze routing with obstacle avoidance
/// Direction encoding: 0=start, 1=right, 2=left, 3=down, 4=up
fn route_with_astar(
  src : @graph.Point,
  dst : @graph.Point,
  src_side : @graph.PortSide,
  dst_side : @graph.PortSide,
  obstacles : Array[@graph.Box],
  clearance : Double,
) -> Array[@graph.Point]? {
  // Build Hanan grid from obstacles and endpoints
  let xs : Array[Double] = [src.x, dst.x]
  let ys : Array[Double] = [src.y, dst.y]
  // Add obstacle boundaries with clearance offsets
  for obs in obstacles {
    let expanded = expand_box_by(obs, clearance)
    xs.push(expanded.x)
    xs.push(expanded.x + expanded.width)
    xs.push(obs.x - clearance * 2.0)
    xs.push(obs.x + obs.width + clearance * 2.0)
    ys.push(expanded.y)
    ys.push(expanded.y + expanded.height)
    ys.push(obs.y - clearance * 2.0)
    ys.push(obs.y + obs.height + clearance * 2.0)
  }
  // Add outer margin
  let outer_margin = 100.0
  let (min_x, max_x, min_y, max_y) = compute_bounds(xs, ys)
  xs.push(min_x - outer_margin)
  xs.push(max_x + outer_margin)
  ys.push(min_y - outer_margin)
  ys.push(max_y + outer_margin)
  // Sort and deduplicate
  let x_coords = unique_sorted_coords(xs)
  let y_coords = unique_sorted_coords(ys)
  if x_coords.length() < 2 || y_coords.length() < 2 {
    return None
  }
  // Find start and goal indices
  let start_ix = find_nearest_coord_index(x_coords, src.x)
  let start_iy = find_nearest_coord_index(y_coords, src.y)
  let goal_ix = find_nearest_coord_index(x_coords, dst.x)
  let goal_iy = find_nearest_coord_index(y_coords, dst.y)
  let x_len = x_coords.length()
  let y_len = y_coords.length()
  let cell_count = x_len * y_len
  // Build blocked grid
  let blocked : Array[Bool] = Array::make(cell_count, false)
  let expanded_obstacles : Array[@graph.Box] = []
  for obs in obstacles {
    expanded_obstacles.push(expand_box_by(obs, clearance))
  }
  for iy in 0..<y_len {
    for ix in 0..<x_len {
      let p = @graph.Point::new(x_coords[ix], y_coords[iy])
      if point_inside_any_obstacle(p, expanded_obstacles) {
        blocked[iy * x_len + ix] = true
      }
    }
  }
  // Ensure start and goal are not blocked
  blocked[start_iy * x_len + start_ix] = false
  blocked[goal_iy * x_len + goal_ix] = false
  // A* search with 5 direction states: 0=start, 1=right, 2=left, 3=down, 4=up
  let total_states = cell_count * 5
  let inf = 1.0e18
  let g_score : Array[Double] = Array::make(total_states, inf)
  let came_from : Array[Int] = Array::make(total_states, -1)
  let closed : Array[Bool] = Array::make(total_states, false)
  let start_state = astar_encode_state_5dir(start_ix, start_iy, 0, x_len)
  g_score[start_state] = 0.0
  let open : @priority_queue.PriorityQueue[@cmp.Reverse[AStarState]] = @priority_queue.new()
  let initial_h = astar_heuristic(
    start_ix, start_iy, goal_ix, goal_iy, x_coords, y_coords,
  )
  open.push(@cmp.Reverse({ f: initial_h, g: 0.0, state: start_state }))
  let turn_penalty = 10.0
  let mut goal_state : Int? = None
  // Movement steps: (dx, dy, direction) where direction = 1=right, 2=left, 3=down, 4=up
  let steps = [(1, 0, 1), (-1, 0, 2), (0, 1, 3), (0, -1, 4)]
  while open.pop() is Some(@cmp.Reverse(entry)) {
    let state = entry.state
    if closed[state] {
      continue
    }
    closed[state] = true
    let (ix, iy, dir) = astar_decode_state_5dir(state, x_len, y_len)
    if ix == goal_ix && iy == goal_iy {
      if can_approach_goal_5dir(dir, dst_side) {
        goal_state = Some(state)
        break
      }
      // Continue searching for valid approach direction
    }
    // Explore neighbors
    for step in steps {
      let nix = ix + step.0
      let niy = iy + step.1
      let ndir = step.2
      if nix < 0 || niy < 0 || nix >= x_len || niy >= y_len {
        continue
      }
      if blocked[niy * x_len + nix] {
        continue
      }
      // Enforce perpendicularity: first move must match port side
      if dir == 0 && !is_valid_start_direction(ndir, src_side) {
        continue // Skip moves that don't match required initial direction
      }
      // Check segment doesn't hit obstacles
      let p0 = @graph.Point::new(x_coords[ix], y_coords[iy])
      let p1 = @graph.Point::new(x_coords[nix], y_coords[niy])
      if segment_hits_obstacles(p0, p1, expanded_obstacles) {
        continue
      }
      let move_cost = (p1.x - p0.x).abs() + (p1.y - p0.y).abs()
      // Turn cost: changing between horizontal (1,2) and vertical (3,4) directions
      let is_turn = dir != 0 && !same_axis(dir, ndir)
      let turn_cost = if is_turn { turn_penalty } else { 0.0 }
      let tentative = g_score[state] + move_cost + turn_cost
      let nstate = astar_encode_state_5dir(nix, niy, ndir, x_len)
      if tentative + 1.0e-9 < g_score[nstate] {
        g_score[nstate] = tentative
        came_from[nstate] = state
        let h = astar_heuristic(nix, niy, goal_ix, goal_iy, x_coords, y_coords)
        open.push(
          @cmp.Reverse({ f: tentative + h, g: tentative, state: nstate }),
        )
      }
    }
  }
  guard goal_state is Some(gs) else { return None }
  // Reconstruct path
  let raw_path = astar_reconstruct_path_5dir(
    gs, came_from, x_len, y_len, x_coords, y_coords,
  )
  // Compress to remove collinear points
  let compressed = compress_collinear_points(raw_path)
  // Ensure route starts at exact src and ends at exact dst
  if compressed.length() >= 2 {
    compressed[0] = src
    compressed[compressed.length() - 1] = dst
    // Fix final approach direction if snapping changed it
    fix_endpoint_approach(compressed, dst_side, is_start=false)
    fix_endpoint_approach(compressed, src_side, is_start=true)
  }
  Some(compressed)
}

///|
/// Fix the endpoint approach direction to match the required side.
/// Also ensures the final segment is long enough for perpendicularity tests.
/// The test uses tolerance=2.0 and requires dx/dy > tolerance, so segment needs > 2px.
fn fix_endpoint_approach(
  route : Array[@graph.Point],
  side : @graph.PortSide,
  is_start~ : Bool,
) -> Unit {
  if route.length() < 2 {
    return
  }
  // Ensure final segment is at least this long for perpendicularity test
  // The test uses tolerance=2.0 and requires dx/dy > tolerance, so we need > 2
  let min_segment_length = 5.0 // Must be > 2.0 (test tolerance)
  if is_start {
    // Fix the first segment: route[0] → route[1]
    let p0 = route[0]
    let p1 = route[1]
    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    // Check if current direction is wrong
    let needs_fix = match side {
      @graph.Top => dy >= 0.0 || dx.abs() > dy.abs() // Should go up
      @graph.Bottom => dy <= 0.0 || dx.abs() > dy.abs() // Should go down
      @graph.Left => dx >= 0.0 || dy.abs() > dx.abs() // Should go left
      @graph.Right => dx <= 0.0 || dy.abs() > dx.abs() // Should go right
    }
    // Also check if segment is too short (even if direction is correct)
    let segment_too_short = match side {
      @graph.Top | @graph.Bottom => dy.abs() <= min_segment_length
      @graph.Left | @graph.Right => dx.abs() <= min_segment_length
    }
    if needs_fix || segment_too_short {
      // Determine if direction is correct but just too short
      let direction_correct = match side {
        @graph.Top => dy < 0.0 && dx.abs() <= dy.abs() // Moving up (leaving from top)
        @graph.Bottom => dy > 0.0 && dx.abs() <= dy.abs() // Moving down (leaving from bottom)
        @graph.Left => dx < 0.0 && dy.abs() <= dx.abs() // Moving left (leaving from left)
        @graph.Right => dx > 0.0 && dy.abs() <= dx.abs() // Moving right (leaving from right)
      }
      if direction_correct && segment_too_short {
        // Direction is correct, just extend the existing second point
        let new_p1 = match side {
          @graph.Top => @graph.Point::new(p1.x, p0.y - min_segment_length)
          @graph.Bottom => @graph.Point::new(p1.x, p0.y + min_segment_length)
          @graph.Left => @graph.Point::new(p0.x - min_segment_length, p1.y)
          @graph.Right => @graph.Point::new(p0.x + min_segment_length, p1.y)
        }
        route[1] = new_p1
      } else {
        // Direction is wrong, insert a new correction point
        let new_p1 = match side {
          @graph.Top => @graph.Point::new(p0.x, p0.y - min_segment_length)
          @graph.Bottom => @graph.Point::new(p0.x, p0.y + min_segment_length)
          @graph.Left => @graph.Point::new(p0.x - min_segment_length, p0.y)
          @graph.Right => @graph.Point::new(p0.x + min_segment_length, p0.y)
        }
        let new_route : Array[@graph.Point] = [p0, new_p1]
        for i in 1..<route.length() {
          new_route.push(route[i])
        }
        route.clear()
        for p in new_route {
          route.push(p)
        }
      }
    }
    // If we adjusted/inserted the departure segment, ensure we didn't create a
    // diagonal with the next segment.
    if route.length() >= 3 {
      let p1 = route[1]
      let p2 = route[2]
      let dx12 = (p2.x - p1.x).abs()
      let dy12 = (p2.y - p1.y).abs()
      if dx12 > 1.0 && dy12 > 1.0 {
        let corner = match side {
          @graph.Left | @graph.Right => @graph.Point::new(p1.x, p2.y)
          @graph.Top | @graph.Bottom => @graph.Point::new(p2.x, p1.y)
        }
        let new_route : Array[@graph.Point] = [route[0], p1, corner]
        for i in 2..<route.length() {
          new_route.push(route[i])
        }
        route.clear()
        for p in new_route {
          route.push(p)
        }
      }
    }
  } else {
    // Fix the last segment: route[n-2] → route[n-1]
    let last_idx = route.length() - 1
    let pn = route[last_idx]
    let pn_1 = route[last_idx - 1]
    let dx = pn.x - pn_1.x
    let dy = pn.y - pn_1.y
    // Check if current direction is wrong
    let needs_fix = match side {
      @graph.Top => dy <= 0.0 || dx.abs() > dy.abs() // Should arrive going down
      @graph.Bottom => dy >= 0.0 || dx.abs() > dy.abs() // Should arrive going up
      @graph.Left => dx <= 0.0 || dy.abs() > dx.abs() // Should arrive going right
      @graph.Right => dx >= 0.0 || dy.abs() > dx.abs() // Should arrive going left
    }
    // Also check if segment is too short (even if direction is correct)
    let segment_too_short = match side {
      @graph.Top | @graph.Bottom => dy.abs() <= min_segment_length
      @graph.Left | @graph.Right => dx.abs() <= min_segment_length
    }
    if needs_fix || segment_too_short {
      // Determine if direction is correct but just too short
      let direction_correct = match side {
        @graph.Top => dy > 0.0 && dx.abs() <= dy.abs() // Moving down toward top
        @graph.Bottom => dy < 0.0 && dx.abs() <= dy.abs() // Moving up toward bottom
        @graph.Left => dx > 0.0 && dy.abs() <= dx.abs() // Moving right toward left
        @graph.Right => dx < 0.0 && dy.abs() <= dx.abs() // Moving left toward right
      }
      if direction_correct && segment_too_short {
        // Direction is correct, just extend the existing penultimate point
        // Also adjust the point before if needed to maintain orthogonality
        let new_pn_1 = match side {
          @graph.Top => @graph.Point::new(pn_1.x, pn.y - min_segment_length)
          @graph.Bottom => @graph.Point::new(pn_1.x, pn.y + min_segment_length)
          @graph.Left => @graph.Point::new(pn.x - min_segment_length, pn_1.y)
          @graph.Right => @graph.Point::new(pn.x + min_segment_length, pn_1.y)
        }
        // Check if we need to adjust the point before the penultimate
        // to maintain orthogonality
        if last_idx >= 2 {
          let pn_2 = route[last_idx - 2]
          // Check if adjusting pn_1 would create a diagonal with pn_2
          let would_be_diagonal = (new_pn_1.x - pn_2.x).abs() > 1.0 &&
            (new_pn_1.y - pn_2.y).abs() > 1.0
          if would_be_diagonal {
            // Adjust pn_2 to maintain orthogonality
            // If pn_2 and pn_1 were on same x (vertical segment), keep y same, change x
            // If pn_2 and pn_1 were on same y (horizontal segment), keep x same, change y
            if (pn_2.x - pn_1.x).abs() < 1.0 {
              // Was vertical segment, keep pn_2.y, change pn_2.x
              route[last_idx - 2] = @graph.Point::new(new_pn_1.x, pn_2.y)
            } else if (pn_2.y - pn_1.y).abs() < 1.0 {
              // Was horizontal segment, keep pn_2.x, change pn_2.y
              route[last_idx - 2] = @graph.Point::new(pn_2.x, new_pn_1.y)
            }
          }
        }
        route[last_idx - 1] = new_pn_1
      } else {
        // Direction is wrong, insert a new correction point
        let new_pn_1 = match side {
          @graph.Top => @graph.Point::new(pn.x, pn.y - min_segment_length)
          @graph.Bottom => @graph.Point::new(pn.x, pn.y + min_segment_length)
          @graph.Left => @graph.Point::new(pn.x - min_segment_length, pn.y)
          @graph.Right => @graph.Point::new(pn.x + min_segment_length, pn.y)
        }
        let new_route : Array[@graph.Point] = []
        for i in 0..<last_idx {
          new_route.push(route[i])
        }
        new_route.push(new_pn_1)
        new_route.push(pn)
        route.clear()
        for p in new_route {
          route.push(p)
        }
      }
    }
  }
}

///|
/// Check if two directions are on the same axis
fn same_axis(dir1 : Int, dir2 : Int) -> Bool {
  let horiz1 = dir1 == 1 || dir1 == 2
  let horiz2 = dir2 == 1 || dir2 == 2
  horiz1 == horiz2
}

///|
fn astar_encode_state_5dir(ix : Int, iy : Int, dir : Int, x_len : Int) -> Int {
  let cell = iy * x_len + ix
  cell * 5 + dir
}

///|
fn astar_decode_state_5dir(
  state : Int,
  x_len : Int,
  _y_len : Int,
) -> (Int, Int, Int) {
  let dir = state % 5
  let cell = state / 5
  let iy = cell / x_len
  let ix = cell % x_len
  (ix, iy, dir)
}

///|
/// Check if approach direction is valid for goal side (5-direction version)
/// - For Top side: must arrive by going down (dir=3)
/// - For Bottom side: must arrive by going up (dir=4)
/// - For Left side: must arrive by going right (dir=1)
/// - For Right side: must arrive by going left (dir=2)
fn can_approach_goal_5dir(dir : Int, goal_side : @graph.PortSide) -> Bool {
  match (dir, goal_side) {
    (3, @graph.Top) => true // Going down to reach top
    (4, @graph.Bottom) => true // Going up to reach bottom
    (1, @graph.Left) => true // Going right to reach left
    (2, @graph.Right) => true // Going left to reach right
    (0, _) => true // Starting state (for very short routes)
    _ => false
  }
}

///|
fn astar_reconstruct_path_5dir(
  goal_state : Int,
  came_from : Array[Int],
  x_len : Int,
  y_len : Int,
  x_coords : Array[Double],
  y_coords : Array[Double],
) -> Array[@graph.Point] {
  let path : Array[@graph.Point] = []
  let mut state = goal_state
  while state >= 0 {
    let (ix, iy, _) = astar_decode_state_5dir(state, x_len, y_len)
    path.push(@graph.Point::new(x_coords[ix], y_coords[iy]))
    state = came_from[state]
  }
  // Reverse path in place
  let n = path.length()
  for i in 0..<(n / 2) {
    let tmp = path[i]
    path[i] = path[n - 1 - i]
    path[n - 1 - i] = tmp
  }
  path
}

///|
fn astar_heuristic(
  ix : Int,
  iy : Int,
  goal_ix : Int,
  goal_iy : Int,
  x_coords : Array[Double],
  y_coords : Array[Double],
) -> Double {
  let dx = (x_coords[ix] - x_coords[goal_ix]).abs()
  let dy = (y_coords[iy] - y_coords[goal_iy]).abs()
  dx + dy
}

///|
fn point_inside_any_obstacle(
  p : @graph.Point,
  obstacles : Array[@graph.Box],
) -> Bool {
  for obs in obstacles {
    if p.x > obs.x &&
      p.x < obs.x + obs.width &&
      p.y > obs.y &&
      p.y < obs.y + obs.height {
      return true
    }
  }
  false
}

///|
fn segment_hits_obstacles(
  p0 : @graph.Point,
  p1 : @graph.Point,
  obstacles : Array[@graph.Box],
) -> Bool {
  for obs in obstacles {
    if line_segment_strictly_intersects_box(p0, p1, obs) {
      return true
    }
  }
  false
}

///|
fn compute_bounds(
  xs : Array[Double],
  ys : Array[Double],
) -> (Double, Double, Double, Double) {
  let mut min_x = xs[0]
  let mut max_x = xs[0]
  let mut min_y = ys[0]
  let mut max_y = ys[0]
  for x in xs {
    if x < min_x {
      min_x = x
    }
    if x > max_x {
      max_x = x
    }
  }
  for y in ys {
    if y < min_y {
      min_y = y
    }
    if y > max_y {
      max_y = y
    }
  }
  (min_x, max_x, min_y, max_y)
}

///|
fn unique_sorted_coords(values : Array[Double]) -> Array[Double] {
  values.sort()
  let result : Array[Double] = []
  for v in values {
    if result.is_empty() || (v - result[result.length() - 1]).abs() > 0.01 {
      result.push(v)
    }
  }
  result
}

///|
fn find_nearest_coord_index(coords : Array[Double], target : Double) -> Int {
  let mut best_idx = 0
  let mut best_dist = (coords[0] - target).abs()
  for i in 1..<coords.length() {
    let dist = (coords[i] - target).abs()
    if dist < best_dist {
      best_dist = dist
      best_idx = i
    }
  }
  best_idx
}

///|
fn compress_collinear_points(
  points : Array[@graph.Point],
) -> Array[@graph.Point] {
  if points.length() <= 2 {
    return points
  }
  let result : Array[@graph.Point] = [points[0]]
  for i in 1..<(points.length() - 1) {
    let prev = result[result.length() - 1]
    let curr = points[i]
    let next = points[i + 1]
    // Check if curr is collinear with prev and next
    let dx1 = curr.x - prev.x
    let dy1 = curr.y - prev.y
    let dx2 = next.x - curr.x
    let dy2 = next.y - curr.y
    let cross = dx1 * dy2 - dy1 * dx2
    if cross.abs() > 0.1 {
      // Not collinear, keep this point
      result.push(curr)
    }
  }
  result.push(points[points.length() - 1])
  result
}

// ============================================================================
// Port Distribution for Shared Nodes
// ============================================================================

///|
/// Port usage info for distribution
priv struct PortUsage {
  edge : @graph.Edge
  is_source : Bool // true if this is the source port, false if destination
}

///|
/// Distribute port positions for edges sharing a node.
/// This ensures edges from different sources to the same destination,
/// or from the same source to different destinations, get different port positions.
/// Also handles bidirectional edges (A->B and B->A) that touch the same node-side.
fn distribute_shared_ports(graph : @graph.Graph) -> Unit {
  // Group ALL port usages by (node_id, side) - combining both source and destination
  let port_groups : Map[String, Array[PortUsage]] = {}

  // First pass: assign port sides based on node positions
  for edge in graph.edges {
    if edge.src_id == edge.dst_id {
      continue // Skip self-loops
    }
    // Resolve endpoint boxes.
    // For sql_table field-level edges, connect at the parent table row position.
    let src_sql = edge.src_column_index is Some(_)
    let dst_sql = edge.dst_column_index is Some(_)
    let is_sql_edge = src_sql || dst_sql
    let (src_box_for_sides, src_sql_info) = if edge.src_column_index
      is Some(col_idx) {
      let parent_id = match get_parent_id_from_field(edge.src_id) {
        Some(p) => p
        None => continue
      }
      let parent = match graph.find_object(parent_id) {
        Some(p) => p
        None => continue
      }
      guard parent.box is Some(table_box) else { continue }
      (table_box, Some((table_box, col_idx, parent.children.length())))
    } else {
      let src_obj = graph.find_object(edge.src_id)
      guard src_obj is Some(src) else { continue }
      guard src.box is Some(src_box) else { continue }
      (src_box, None)
    }
    let (dst_box_for_sides, dst_sql_info) = if edge.dst_column_index
      is Some(col_idx) {
      let parent_id = match get_parent_id_from_field(edge.dst_id) {
        Some(p) => p
        None => continue
      }
      let parent = match graph.find_object(parent_id) {
        Some(p) => p
        None => continue
      }
      guard parent.box is Some(table_box) else { continue }
      (table_box, Some((table_box, col_idx, parent.children.length())))
    } else {
      let dst_obj = graph.find_object(edge.dst_id)
      guard dst_obj is Some(dst) else { continue }
      guard dst.box is Some(dst_box) else { continue }
      (dst_box, None)
    }

    // Determine port sides based on relative positions
    let src_center = src_box_for_sides.center()
    let dst_center = dst_box_for_sides.center()
    let dx = dst_center.get_x() - src_center.get_x()
    let dy = dst_center.get_y() - src_center.get_y()
    let (src_side, dst_side) : (@graph.PortSide, @graph.PortSide) = if is_sql_edge {
      // Keep sql_table row connections on left/right sides so they align with rows.
      if dx >= 0.0 {
        (@graph.Right, @graph.Left)
      } else {
        (@graph.Left, @graph.Right)
      }
    } else if dy.abs() > dx.abs() {
      if dy > 0.0 {
        (@graph.Bottom, @graph.Top)
      } else {
        (@graph.Top, @graph.Bottom)
      }
    } else if dx > 0.0 {
      (@graph.Right, @graph.Left)
    } else {
      (@graph.Left, @graph.Right)
    }

    // Store port sides (with default position 0.5)
    edge.src_port = Some(@graph.Port::new(src_side, 0.5))
    edge.dst_port = Some(@graph.Port::new(dst_side, 0.5))

    // For sql_table row connections, set fixed port points immediately.
    match src_sql_info {
      Some((table_box, col_idx, num_cols)) => {
        let is_left_side = src_side == @graph.Left
        let pt = get_sql_row_anchor_point(
          table_box, col_idx, num_cols, is_left_side,
        )
        if edge.src_port is Some(port) {
          port.point = Some(pt)
        }
      }
      None => ()
    }
    match dst_sql_info {
      Some((table_box, col_idx, num_cols)) => {
        let is_left_side = dst_side == @graph.Left
        let pt = get_sql_row_anchor_point(
          table_box, col_idx, num_cols, is_left_side,
        )
        if edge.dst_port is Some(port) {
          port.point = Some(pt)
        }
      }
      None => ()
    }

    // Group non-sql endpoints by node+side for distribution.
    if !src_sql {
      let src_key = edge.src_id + "_" + port_side_string(src_side)
      let src_usage = { edge, is_source: true }
      match port_groups.get(src_key) {
        Some(arr) => arr.push(src_usage)
        None => port_groups[src_key] = [src_usage]
      }
    }
    if !dst_sql {
      let dst_key = edge.dst_id + "_" + port_side_string(dst_side)
      let dst_usage = { edge, is_source: false }
      match port_groups.get(dst_key) {
        Some(arr) => arr.push(dst_usage)
        None => port_groups[dst_key] = [dst_usage]
      }
    }
  }

  // Distribute port positions for all ports sharing a node-side
  for entry in port_groups {
    let usages = entry.1
    if usages.length() <= 1 {
      continue
    }

    // Sort by the "other" node's x-position for consistent ordering
    // For source ports, sort by destination x; for destination ports, sort by source x
    usages.sort_by(fn(a, b) {
      let ax = if a.is_source {
        get_object_center_x(graph, a.edge.dst_id)
      } else {
        get_object_center_x(graph, a.edge.src_id)
      }
      let bx = if b.is_source {
        get_object_center_x(graph, b.edge.dst_id)
      } else {
        get_object_center_x(graph, b.edge.src_id)
      }
      ax.compare(bx)
    })

    // Distribute positions from 0.15 to 0.85 (wider range for more separation)
    let count = usages.length()
    for i, usage in usages {
      let position = if count == 1 {
        0.5
      } else {
        0.15 + 0.7 * i.to_double() / (count - 1).to_double()
      }
      if usage.is_source {
        if usage.edge.src_port is Some(port) {
          usage.edge.src_port = Some(@graph.Port::new(port.side, position))
        }
      } else if usage.edge.dst_port is Some(port) {
        usage.edge.dst_port = Some(@graph.Port::new(port.side, position))
      }
    }
  }

  // Compute absolute port coordinates
  for edge in graph.edges {
    if edge.src_port is Some(src_port) {
      if src_port.point is None {
        if graph.find_object(edge.src_id) is Some(obj) {
          if obj.box is Some(box) {
            src_port.point = Some(
              get_port_point_on_side(box, src_port.side, src_port.position),
            )
          }
        }
      }
    }
    if edge.dst_port is Some(dst_port) {
      if dst_port.point is None {
        if graph.find_object(edge.dst_id) is Some(obj) {
          if obj.box is Some(box) {
            dst_port.point = Some(
              get_port_point_on_side(box, dst_port.side, dst_port.position),
            )
          }
        }
      }
    }
  }
}

///|
fn port_side_string(side : @graph.PortSide) -> String {
  match side {
    @graph.Top => "top"
    @graph.Bottom => "bottom"
    @graph.Left => "left"
    @graph.Right => "right"
  }
}

///|
fn get_object_center_x(graph : @graph.Graph, id : String) -> Double {
  match graph.find_object(id) {
    Some(obj) =>
      match obj.box {
        Some(b) => b.x + b.width / 2.0
        None => 0.0
      }
    None => 0.0
  }
}

// ============================================================================
// Main Entry Point - Route All Edges
// ============================================================================

///|
/// Route all edges in the graph using unified routing.
/// This is the single source of truth for edge routing.
pub fn route_all_edges(
  graph : @graph.Graph,
  _config : LayoutConfig,
  _direction : Direction,
) -> Unit {
  // Step 1: Distribute port positions for edges sharing nodes
  distribute_shared_ports(graph)

  // Step 2: Group edges by source-destination pair for parallel edge handling
  let parallel_groups = group_parallel_edges(graph)
  let clearance = 2.0
  // Route each group
  for entry in parallel_groups {
    let edges = entry.1
    let group_size = edges.length()

    // Collect base obstacles (nodes not involved in any edge of this group)
    let base_obstacles = collect_obstacles_for_group(graph, edges, clearance)

    // Track previously routed edges as additional soft obstacles
    let route_obstacles : Array[@graph.Box] = []

    // Route each edge in the group with appropriate offset
    for i, edge in edges {
      // Clear existing route
      edge.route.clear()
      // Handle self-loops specially
      if edge.src_id == edge.dst_id {
        route_self_loop_unified(edge, graph)
        continue
      }
      // Get port information
      let (src_point, src_side, dst_point, dst_side) = match
        get_port_info(edge, graph) {
        Some(info) => info
        None => continue // Skip edges without valid ports
      }
      // Calculate parallel offset
      let offset = calculate_parallel_offset(i, group_size)

      // Combine base obstacles with previously routed edges
      let all_obstacles : Array[@graph.Box] = []
      for obs in base_obstacles {
        all_obstacles.push(obs)
      }
      for obs in route_obstacles {
        all_obstacles.push(obs)
      }

      // Try simple routing first
      let simple_route = route_simple(
        src_point, dst_point, src_side, dst_side, offset,
      )
      // Check if simple route intersects any obstacles
      if route_intersects_obstacles(simple_route, all_obstacles, clearance) {
        // Use A* maze routing
        // Note: A* doesn't use the parallel offset directly - it relies on
        // different port positions (from distribute_shared_ports) to find different paths.
        // Applying offset to A* routes would break orthogonality.
        let maze_route = route_with_astar(
          src_point, dst_point, src_side, dst_side, all_obstacles, clearance,
        )
        let retry_without_soft_obstacles = edge.src_column_index is Some(_) ||
          edge.dst_column_index is Some(_)
        let maze_route = if maze_route is Some(_) ||
          !retry_without_soft_obstacles {
          maze_route
        } else {
          route_with_astar(
            src_point, dst_point, src_side, dst_side, base_obstacles, clearance,
          )
        }
        match maze_route {
          Some(route) => {
            for pt in route {
              edge.route.push(pt)
            }
            // Add this route as a soft obstacle for subsequent parallel edges
            add_route_as_obstacles(route, route_obstacles, 5.0)
          }
          None => {
            // Fallback to simple route even if it intersects
            // (better than no route at all)
            for pt in simple_route {
              edge.route.push(pt)
            }
            add_route_as_obstacles(simple_route, route_obstacles, 5.0)
          }
        }
      } else {
        // Simple route is clear, use it
        for pt in simple_route {
          edge.route.push(pt)
        }
        // Add this route as a soft obstacle for subsequent parallel edges
        add_route_as_obstacles(simple_route, route_obstacles, 5.0)
      }

      // Fix endpoint approach direction for this edge's route
      if edge.route.length() >= 2 {
        fix_endpoint_approach(edge.route, dst_side, is_start=false)
        fix_endpoint_approach(edge.route, src_side, is_start=true)
      }
    }
  }

  // Step 3: Update port sides to match actual route approach directions
  // This is critical because A* routing can find paths that approach from
  // different directions than originally planned based on node positions
  update_port_sides_from_routes(graph)
}

///|
/// Collect obstacles for a group of parallel edges (excludes all source and destination nodes)
fn collect_obstacles_for_group(
  graph : @graph.Graph,
  edges : Array[@graph.Edge],
  clearance : Double,
) -> Array[@graph.Box] {
  let obstacles : Array[@graph.Box] = []
  let excluded_ids : Array[String] = []
  let sql_parent_ids : Array[String] = []
  for edge in edges {
    if !excluded_ids.contains(edge.src_id) {
      excluded_ids.push(edge.src_id)
    }
    if !excluded_ids.contains(edge.dst_id) {
      excluded_ids.push(edge.dst_id)
    }
    // Track parent sql_table boxes for field-level connections.
    if edge.src_column_index is Some(_) {
      match get_parent_id_from_field(edge.src_id) {
        Some(parent_id) =>
          if !sql_parent_ids.contains(parent_id) {
            sql_parent_ids.push(parent_id)
          }
        None => ()
      }
    }
    if edge.dst_column_index is Some(_) {
      match get_parent_id_from_field(edge.dst_id) {
        Some(parent_id) =>
          if !sql_parent_ids.contains(parent_id) {
            sql_parent_ids.push(parent_id)
          }
        None => ()
      }
    }
  }
  for obj in graph.objects {
    if excluded_ids.contains(obj.id) {
      continue
    }
    // sql_table fields are not rendered as separate boxes; don't treat them as obstacles.
    if is_sql_table_child_id(graph, obj.id) {
      continue
    }
    // Edges avoid leaf nodes; containers are allowed to be crossed.
    if !is_leaf_obstacle_node(obj) {
      continue
    }
    if obj.box is Some(b) {
      if sql_parent_ids.contains(obj.id) {
        obstacles.push(shrink_box_by(b, clearance))
      } else {
        obstacles.push(b)
      }
    }
  }
  obstacles
}

///|
/// Add a route's segments as small obstacle boxes to push subsequent routes away
fn add_route_as_obstacles(
  route : Array[@graph.Point],
  obstacles : Array[@graph.Box],
  thickness : Double,
) -> Unit {
  // Avoid blocking future edges from leaving/entering the same endpoints by
  // skipping the first and last segments.
  let n = route.length()
  if n < 4 {
    return
  }
  for i in 1..<(n - 2) {
    let p1 = route[i]
    let p2 = route[i + 1]
    // Create a small box around this segment
    let min_x = double_min(p1.x, p2.x) - thickness / 2.0
    let max_x = double_max(p1.x, p2.x) + thickness / 2.0
    let min_y = double_min(p1.y, p2.y) - thickness / 2.0
    let max_y = double_max(p1.y, p2.y) + thickness / 2.0
    obstacles.push(@graph.Box::new(min_x, min_y, max_x - min_x, max_y - min_y))
  }
}

///|
/// Compute port info for sql_table field-level connections.
fn get_sql_edge_port_info(
  edge : @graph.Edge,
  graph : @graph.Graph,
) -> (@graph.Point, @graph.PortSide, @graph.Point, @graph.PortSide)? {
  // Resolve endpoint boxes used for side decisions.
  let (src_box_for_sides, src_sql_info) = if edge.src_column_index
    is Some(col_idx) {
    let parent_id = match get_parent_id_from_field(edge.src_id) {
      Some(p) => p
      None => return None
    }
    let parent = match graph.find_object(parent_id) {
      Some(p) => p
      None => return None
    }
    guard parent.box is Some(table_box) else { return None }
    (table_box, Some((table_box, col_idx, parent.children.length())))
  } else {
    let src_obj = graph.find_object(edge.src_id)
    guard src_obj is Some(src) else { return None }
    guard src.box is Some(src_box) else { return None }
    (src_box, None)
  }
  let (dst_box_for_sides, dst_sql_info) = if edge.dst_column_index
    is Some(col_idx) {
    let parent_id = match get_parent_id_from_field(edge.dst_id) {
      Some(p) => p
      None => return None
    }
    let parent = match graph.find_object(parent_id) {
      Some(p) => p
      None => return None
    }
    guard parent.box is Some(table_box) else { return None }
    (table_box, Some((table_box, col_idx, parent.children.length())))
  } else {
    let dst_obj = graph.find_object(edge.dst_id)
    guard dst_obj is Some(dst) else { return None }
    guard dst.box is Some(dst_box) else { return None }
    (dst_box, None)
  }
  let src_center = src_box_for_sides.center()
  let dst_center = dst_box_for_sides.center()
  let dx = dst_center.get_x() - src_center.get_x()

  // Keep sql_table row connections on left/right sides so they align with rows.
  let (src_side, dst_side) = if dx >= 0.0 {
    (@graph.Right, @graph.Left)
  } else {
    (@graph.Left, @graph.Right)
  }
  let src_pt = match src_sql_info {
    Some((table_box, col_idx, num_cols)) => {
      let is_left_side = src_side == @graph.Left
      get_sql_row_anchor_point(table_box, col_idx, num_cols, is_left_side)
    }
    None => get_port_point_on_side(src_box_for_sides, src_side, 0.5)
  }
  let dst_pt = match dst_sql_info {
    Some((table_box, col_idx, num_cols)) => {
      let is_left_side = dst_side == @graph.Left
      get_sql_row_anchor_point(table_box, col_idx, num_cols, is_left_side)
    }
    None => get_port_point_on_side(dst_box_for_sides, dst_side, 0.5)
  }
  Some((src_pt, src_side, dst_pt, dst_side))
}

///|
/// Get port information for an edge
fn get_port_info(
  edge : @graph.Edge,
  graph : @graph.Graph,
) -> (@graph.Point, @graph.PortSide, @graph.Point, @graph.PortSide)? {
  // Try to get from pre-assigned ports
  match (edge.src_port, edge.dst_port) {
    (Some(src_port), Some(dst_port)) =>
      match (src_port.point, dst_port.point) {
        (Some(src_pt), Some(dst_pt)) =>
          return Some((src_pt, src_port.side, dst_pt, dst_port.side))
        _ => ()
      }
    _ => ()
  }
  // SQL table field-level edges: compute row-anchored ports.
  if edge.src_column_index is Some(_) || edge.dst_column_index is Some(_) {
    match get_sql_edge_port_info(edge, graph) {
      Some(info) => return Some(info)
      None => ()
    }
  }
  // Fall back to computing from node boxes
  let src_obj = graph.find_object(edge.src_id)
  let dst_obj = graph.find_object(edge.dst_id)
  guard src_obj is Some(src) else { return None }
  guard dst_obj is Some(dst) else { return None }
  guard src.box is Some(src_box) else { return None }
  guard dst.box is Some(dst_box) else { return None }
  // Determine best sides based on relative positions
  let src_center = src_box.center()
  let dst_center = dst_box.center()
  let dx = dst_center.get_x() - src_center.get_x()
  let dy = dst_center.get_y() - src_center.get_y()
  let (src_side, dst_side) = if dy.abs() > dx.abs() {
    if dy > 0.0 {
      (@graph.Bottom, @graph.Top)
    } else {
      (@graph.Top, @graph.Bottom)
    }
  } else if dx > 0.0 {
    (@graph.Right, @graph.Left)
  } else {
    (@graph.Left, @graph.Right)
  }
  // Compute port points
  let src_pt = get_port_point_on_side(src_box, src_side, 0.5)
  let dst_pt = get_port_point_on_side(dst_box, dst_side, 0.5)
  Some((src_pt, src_side, dst_pt, dst_side))
}

///|
/// Get a point on a specific side of a box.
/// Position is 0.0-1.0 along the side.
fn get_port_point_on_side(
  box : @graph.Box,
  side : @graph.PortSide,
  position : Double,
) -> @graph.Point {
  match side {
    @graph.Top => {
      let x = box.x + box.width * position
      @graph.Point::new(x, box.y)
    }
    @graph.Bottom => {
      let x = box.x + box.width * position
      @graph.Point::new(x, box.y + box.height)
    }
    @graph.Left => {
      let y = box.y + box.height * position
      @graph.Point::new(box.x, y)
    }
    @graph.Right => {
      let y = box.y + box.height * position
      @graph.Point::new(box.x + box.width, y)
    }
  }
}

///|
/// Route a self-loop edge
fn route_self_loop_unified(edge : @graph.Edge, graph : @graph.Graph) -> Unit {
  let obj = graph.find_object(edge.src_id)
  guard obj is Some(o) else { return }
  guard o.box is Some(box) else { return }
  // Create a self-loop on the right side
  let loop_offset = 30.0
  let start_y = box.y + box.height * 0.3
  let end_y = box.y + box.height * 0.7
  let right_x = box.x + box.width
  edge.route.push(@graph.Point::new(right_x, start_y))
  edge.route.push(@graph.Point::new(right_x + loop_offset, start_y))
  edge.route.push(@graph.Point::new(right_x + loop_offset, end_y))
  edge.route.push(@graph.Point::new(right_x, end_y))
}

// ============================================================================
// Post-Routing Port Side Correction
// ============================================================================

///|
/// Update port sides to match actual route approach directions.
/// This is needed because A* routing can find paths that approach from
/// different directions than originally planned based on node positions.
fn update_port_sides_from_routes(graph : @graph.Graph) -> Unit {
  for edge in graph.edges {
    if edge.route.length() < 2 {
      continue
    }

    // Update source port side based on first segment direction
    let p0 = edge.route[0]
    let p1 = edge.route[1]
    let src_side = infer_port_side_from_segment(p0, p1, is_departure=true)
    if edge.src_port is Some(port) {
      edge.src_port = Some({
        side: src_side,
        position: port.position,
        point: port.point,
      })
    }

    // Update destination port side based on last segment direction
    let pn = edge.route[edge.route.length() - 1]
    let pn_1 = edge.route[edge.route.length() - 2]
    let dst_side = infer_port_side_from_segment(pn_1, pn, is_departure=false)
    if edge.dst_port is Some(port) {
      edge.dst_port = Some({
        side: dst_side,
        position: port.position,
        point: port.point,
      })
    }
  }
}

///|
/// Infer the port side based on a segment's direction.
/// - For departure (source): the side the edge leaves from
/// - For arrival (destination): the side the edge arrives at
fn infer_port_side_from_segment(
  p1 : @graph.Point,
  p2 : @graph.Point,
  is_departure~ : Bool,
) -> @graph.PortSide {
  let dx = p2.x - p1.x
  let dy = p2.y - p1.y

  // Check if segment is more horizontal or vertical
  if dx.abs() > dy.abs() {
    // Horizontal segment
    if is_departure {
      // Departing: going right means leaving from right side, going left means left side
      if dx > 0.0 {
        @graph.Right
      } else {
        @graph.Left
      }
      // Arriving: going right means entering from left side, going left means right side
    } else if dx > 0.0 {
      @graph.Left
    } else {
      @graph.Right
    }
    // Vertical segment
  } else if is_departure {
    // Departing: going down means leaving from bottom, going up means top
    if dy > 0.0 {
      @graph.Bottom
    } else {
      @graph.Top
    }
    // Arriving: going down means entering from top, going up means bottom
  } else if dy > 0.0 {
    @graph.Top
  } else {
    @graph.Bottom
  }
}

// ============================================================================
// Route Compression (Post-processing cleanup)
// ============================================================================

///|
/// Compress all routes in the graph to remove redundant waypoints.
pub fn compress_all_routes(graph : @graph.Graph) -> Unit {
  for edge in graph.edges {
    if edge.route.length() > 2 {
      let points : Array[@graph.Point] = []
      for pt in edge.route {
        points.push(pt)
      }
      let compressed = compress_collinear_points(points)
      edge.route.clear()
      for pt in compressed {
        edge.route.push(pt)
      }
    }
  }
}

///|
/// Fix endpoint approach directions for all edges.
/// Instead of inserting correction points, we adjust the endpoint to
/// the side that matches the actual approach direction.
pub fn fix_all_endpoint_approaches(graph : @graph.Graph) -> Unit {
  for edge in graph.edges {
    if edge.route.length() < 2 {
      continue
    }
    // sql_table field-level edges use explicit row anchors; don't snap endpoints.
    if edge.src_column_index is Some(_) || edge.dst_column_index is Some(_) {
      continue
    }
    // Fix destination endpoint based on actual approach
    let dst_box = if edge.dst_column_index is Some(_) {
      match get_parent_id_from_field(edge.dst_id) {
        Some(parent_id) =>
          match graph.find_object(parent_id) {
            Some(obj) => obj.box
            None => None
          }
        None => None
      }
    } else {
      match graph.find_object(edge.dst_id) {
        Some(obj) => obj.box
        None => None
      }
    }
    if dst_box is Some(box) {
      fix_endpoint_to_match_approach(edge.route, box, is_start=false)
    }
    // Fix source endpoint based on actual departure
    let src_box = if edge.src_column_index is Some(_) {
      match get_parent_id_from_field(edge.src_id) {
        Some(parent_id) =>
          match graph.find_object(parent_id) {
            Some(obj) => obj.box
            None => None
          }
        None => None
      }
    } else {
      match graph.find_object(edge.src_id) {
        Some(obj) => obj.box
        None => None
      }
    }
    if src_box is Some(box) {
      fix_endpoint_to_match_approach(edge.route, box, is_start=true)
    }
    // Update port sides to match the new endpoints
    update_edge_port_sides(edge, graph)
  }
}

///|
/// Check if a point is strictly inside a box (not on boundary)
fn point_strictly_inside_box(p : @graph.Point, box : @graph.Box) -> Bool {
  p.x > box.x + 2.0 &&
  p.x < box.x + box.width - 2.0 &&
  p.y > box.y + 2.0 &&
  p.y < box.y + box.height - 2.0
}

///|
/// Fix endpoint approach ONLY when there are points strictly inside the box.
/// This avoids modifying routes that are already correct.
fn fix_endpoint_to_match_approach(
  route : Array[@graph.Point],
  box : @graph.Box,
  is_start~ : Bool,
) -> Unit {
  if route.length() < 2 || is_start {
    return
  }
  // Check if any points (except endpoint) are strictly inside the box
  let mut has_internal_points = false
  for i in 0..<(route.length() - 1) {
    if point_strictly_inside_box(route[i], box) {
      has_internal_points = true
      break
    }
  }
  if !has_internal_points {
    // Route doesn't pass through box interior, nothing to fix
    return
  }
  // Find the last point OUTSIDE the box (strictly)
  let mut outside_idx = route.length() - 2
  while outside_idx >= 0 &&
        (
          point_strictly_inside_box(route[outside_idx], box) ||
          (
            route[outside_idx].x >= box.x &&
            route[outside_idx].x <= box.x + box.width &&
            route[outside_idx].y >= box.y &&
            route[outside_idx].y <= box.y + box.height
          )
        ) {
    outside_idx = outside_idx - 1
  }
  if outside_idx < 0 {
    return
  }
  let outside_pt = route[outside_idx]
  // Determine approach direction
  let endpoint = route[route.length() - 1]
  let dx = endpoint.x - outside_pt.x
  let dy = endpoint.y - outside_pt.y
  // Build new endpoint segment without clearance (direct approach)
  let new_endpoint = if dy.abs() > dx.abs() {
    // Vertical approach
    if dy > 0.0 {
      // Coming from above, connect to top
      @graph.Point::new(clamp(outside_pt.x, box.x, box.x + box.width), box.y)
    } else {
      // Coming from below, connect to bottom
      @graph.Point::new(
        clamp(outside_pt.x, box.x, box.x + box.width),
        box.y + box.height,
      )
    }
    // Horizontal approach
  } else if dx > 0.0 {
    // Coming from left, connect to left side
    @graph.Point::new(box.x, clamp(outside_pt.y, box.y, box.y + box.height))
  } else {
    // Coming from right, connect to right side
    @graph.Point::new(
      box.x + box.width,
      clamp(outside_pt.y, box.y, box.y + box.height),
    )
  }
  // Build new route: keep points up to outside_idx, add direct connection to endpoint
  let new_route : Array[@graph.Point] = []
  for i in 0..=outside_idx {
    new_route.push(route[i])
  }
  // Add orthogonal connection if needed
  if (outside_pt.x - new_endpoint.x).abs() > 1.0 &&
    (outside_pt.y - new_endpoint.y).abs() > 1.0 {
    // Need L-shape connection
    if dy.abs() > dx.abs() {
      // Vertical dominant - go vertical first, then horizontal
      new_route.push(@graph.Point::new(outside_pt.x, new_endpoint.y))
    } else {
      // Horizontal dominant - go horizontal first, then vertical
      new_route.push(@graph.Point::new(new_endpoint.x, outside_pt.y))
    }
  }
  new_route.push(new_endpoint)
  // Replace route contents
  route.clear()
  for pt in new_route {
    route.push(pt)
  }
}

///|
/// Fix approach direction when endpoint is near boundary but approach is wrong.
/// This handles the case where the route approaches from the wrong direction.
pub fn fix_wrong_approach_direction(graph : @graph.Graph) -> Unit {
  let tolerance = 5.0
  for edge in graph.edges {
    if edge.route.length() < 2 {
      continue
    }
    // Fix destination
    let dst_obj = graph.find_object(edge.dst_id)
    if dst_obj is Some(obj) && obj.box is Some(box) {
      fix_wrong_approach_for_endpoint(edge.route, box, is_start=false)
    }
    // Fix source
    let src_obj = graph.find_object(edge.src_id)
    if src_obj is Some(obj) && obj.box is Some(box) {
      fix_wrong_approach_for_endpoint(edge.route, box, is_start=true)
    }
  }
  let _ = tolerance
  // Don't compress here - it would remove the correction points we just added
}

///|
fn fix_wrong_approach_for_endpoint(
  route : Array[@graph.Point],
  box : @graph.Box,
  is_start~ : Bool,
) -> Unit {
  if route.length() < 2 {
    return
  }
  let tolerance = 5.0
  let endpoint_idx = if is_start { 0 } else { route.length() - 1 }
  let second_idx = if is_start { 1 } else { route.length() - 2 }
  let endpoint = route[endpoint_idx]
  let second = route[second_idx]
  // Compute approach direction
  let dx = if is_start { second.x - endpoint.x } else { endpoint.x - second.x }
  let dy = if is_start { second.y - endpoint.y } else { endpoint.y - second.y }
  // Determine which side endpoint is closest to
  let dist_left = (endpoint.x - box.x).abs()
  let dist_right = (endpoint.x - (box.x + box.width)).abs()
  let dist_top = (endpoint.y - box.y).abs()
  let dist_bottom = (endpoint.y - (box.y + box.height)).abs()
  let min_dist = min_double(
    min_double(dist_left, dist_right),
    min_double(dist_top, dist_bottom),
  )
  // If endpoint is not close to any boundary, skip
  if min_dist > tolerance {
    return
  }
  // Determine expected approach direction based on closest side
  let is_left_side = dist_left <= min_dist + tolerance
  let is_right_side = dist_right <= min_dist + tolerance
  let is_top_side = dist_top <= min_dist + tolerance
  let is_bottom_side = dist_bottom <= min_dist + tolerance
  // Check if approach direction matches the side
  // Test logic: approach direction should point TOWARD the side
  // - LEFT side: dx > 0 (approaching from left, going right toward box.x)
  // - RIGHT side: dx < 0 (approaching from right, going left toward box.x+width)
  // - TOP side: dy > 0 (approaching from top, going down toward box.y)
  // - BOTTOM side: dy < 0 (approaching from bottom, going up toward box.y+height)
  let is_horizontal_approach = dx.abs() > dy.abs()
  let needs_fix = if is_left_side {
    // Left side needs horizontal approach going right (dx > 0)
    !is_horizontal_approach || dx < -tolerance
  } else if is_right_side {
    // Right side needs horizontal approach going left (dx < 0)
    !is_horizontal_approach || dx > tolerance
  } else if is_top_side {
    // Top side needs vertical approach going down (dy > 0)
    is_horizontal_approach || dy < -tolerance
  } else if is_bottom_side {
    // Bottom side needs vertical approach going up (dy < 0)
    is_horizontal_approach || dy > tolerance
  } else {
    false
  }
  if !needs_fix {
    return
  }
  // Calculate the correct endpoint on the boundary
  let new_endpoint = if is_left_side {
    @graph.Point::new(box.x, clamp(endpoint.y, box.y, box.y + box.height))
  } else if is_right_side {
    @graph.Point::new(
      box.x + box.width,
      clamp(endpoint.y, box.y, box.y + box.height),
    )
  } else if is_top_side {
    @graph.Point::new(clamp(endpoint.x, box.x, box.x + box.width), box.y)
  } else {
    @graph.Point::new(
      clamp(endpoint.x, box.x, box.x + box.width),
      box.y + box.height,
    )
  }
  // Insert correction point to make approach from correct direction
  let clearance = 20.0
  let correction = if is_left_side {
    // Left side: approach from left (dx > 0), so correction is to the LEFT of endpoint
    @graph.Point::new(new_endpoint.x - clearance, new_endpoint.y)
  } else if is_right_side {
    // Right side: approach from right (dx < 0), so correction is to the RIGHT of endpoint
    @graph.Point::new(new_endpoint.x + clearance, new_endpoint.y)
  } else if is_top_side {
    // Top side: approach from top (dy > 0), so correction is ABOVE endpoint
    @graph.Point::new(new_endpoint.x, new_endpoint.y - clearance)
  } else {
    // Bottom side: approach from bottom (dy < 0), so correction is BELOW endpoint
    @graph.Point::new(new_endpoint.x, new_endpoint.y + clearance)
  }
  // Update route
  if is_start {
    // Insert correction after endpoint
    route[0] = new_endpoint
    // Check if correction is different from endpoint and second point
    if (correction.x - new_endpoint.x).abs() > 1.0 ||
      (correction.y - new_endpoint.y).abs() > 1.0 {
      let new_route : Array[@graph.Point] = [new_endpoint, correction]
      for i in 1..<route.length() {
        new_route.push(route[i])
      }
      route.clear()
      for pt in new_route {
        route.push(pt)
      }
    }
  } else {
    // Insert correction before endpoint
    let n = route.length()
    route[n - 1] = new_endpoint
    // Check if correction is different
    if (correction.x - new_endpoint.x).abs() > 1.0 ||
      (correction.y - new_endpoint.y).abs() > 1.0 {
      let new_route : Array[@graph.Point] = []
      for i in 0..<(n - 1) {
        new_route.push(route[i])
      }
      new_route.push(correction)
      new_route.push(new_endpoint)
      route.clear()
      for pt in new_route {
        route.push(pt)
      }
    }
  }
}

///|
/// Remove tiny segments at route endpoints (less than min_length pixels).
/// These can cause perpendicularity test failures.
pub fn cleanup_tiny_endpoint_segments(graph : @graph.Graph) -> Unit {
  let min_length = 5.0
  for edge in graph.edges {
    if edge.route.length() < 3 {
      continue
    }
    // Check first segment
    let mut p0 = edge.route[0]
    let mut p1 = edge.route[1]
    let mut dx = (p1.x - p0.x).abs()
    let mut dy = (p1.y - p0.y).abs()
    let seg_length = dx + dy // Manhattan distance for orthogonal
    if seg_length < min_length && edge.route.length() >= 3 {
      // Remove p0 if it creates a tiny segment, adjust p1 to be on boundary
      // Actually, snap p1 onto the line from p0 toward p2
      let p2 = edge.route[2]
      let dx2 = p2.x - p1.x
      let dy2 = p2.y - p1.y
      // If p1-p2 is vertical, move p0.x to match p2.x
      // If p1-p2 is horizontal, move p0.y to match p2.y
      if dx2.abs() < 1.0 {
        // p1-p2 is vertical, snap p0.x to p2.x
        edge.route[0] = @graph.Point::new(p2.x, p0.y)
      } else if dy2.abs() < 1.0 {
        // p1-p2 is horizontal, snap p0.y to p2.y
        edge.route[0] = @graph.Point::new(p0.x, p2.y)
      }
      // Then remove p1 if it's now redundant (collinear)
    }
    // Check last segment
    if edge.route.length() < 3 {
      continue
    }
    let last_idx = edge.route.length() - 1
    p0 = edge.route[last_idx - 1]
    p1 = edge.route[last_idx]
    dx = (p1.x - p0.x).abs()
    dy = (p1.y - p0.y).abs()
    let seg_length_end = dx + dy
    if seg_length_end < min_length && edge.route.length() >= 3 {
      let p_prev = edge.route[last_idx - 2]
      let dx_prev = p0.x - p_prev.x
      let dy_prev = p0.y - p_prev.y
      // If prev-p0 is vertical, snap p1.x to match prev.x
      // If prev-p0 is horizontal, snap p1.y to match prev.y
      if dx_prev.abs() < 1.0 {
        // prev-p0 is vertical, snap p1.x
        edge.route[last_idx] = @graph.Point::new(p_prev.x, p1.y)
      } else if dy_prev.abs() < 1.0 {
        // prev-p0 is horizontal, snap p1.y
        edge.route[last_idx] = @graph.Point::new(p1.x, p_prev.y)
      }
    }
  }
  // Now compress again to remove any redundant points created
  compress_all_routes(graph)
}

///|
/// Update port sides for an edge to match its actual route endpoints.
fn update_edge_port_sides(edge : @graph.Edge, graph : @graph.Graph) -> Unit {
  if edge.route.length() < 2 {
    return
  }
  // Update source port
  let src_box = if edge.src_column_index is Some(_) {
    match get_parent_id_from_field(edge.src_id) {
      Some(parent_id) =>
        match graph.find_object(parent_id) {
          Some(obj) => obj.box
          None => None
        }
      None => None
    }
  } else {
    match graph.find_object(edge.src_id) {
      Some(obj) => obj.box
      None => None
    }
  }
  if src_box is Some(box) {
    let p0 = edge.route[0]
    let p1 = edge.route[1]
    let side = infer_side_from_endpoint_position(p0, p1, box, is_start=true)
    let position = compute_position_on_side(p0, box, side)
    edge.src_port = Some(@graph.Port::new(side, position))
    if edge.src_port is Some(port) {
      port.point = Some(p0)
    }
  }
  // Update destination port
  let dst_box = if edge.dst_column_index is Some(_) {
    match get_parent_id_from_field(edge.dst_id) {
      Some(parent_id) =>
        match graph.find_object(parent_id) {
          Some(obj) => obj.box
          None => None
        }
      None => None
    }
  } else {
    match graph.find_object(edge.dst_id) {
      Some(obj) => obj.box
      None => None
    }
  }
  if dst_box is Some(box) {
    let pn = edge.route[edge.route.length() - 1]
    let pn_1 = edge.route[edge.route.length() - 2]
    let side = infer_side_from_endpoint_position(pn, pn_1, box, is_start=false)
    let position = compute_position_on_side(pn, box, side)
    edge.dst_port = Some(@graph.Port::new(side, position))
    if edge.dst_port is Some(port) {
      port.point = Some(pn)
    }
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Infer port side from actual endpoint position on the box boundary.
fn infer_side_from_endpoint_position(
  endpoint : @graph.Point,
  _other : @graph.Point,
  box : @graph.Box,
  is_start~ : Bool,
) -> @graph.PortSide {
  // Ignore is_start - we just check where the endpoint actually is
  let _ = is_start
  let tolerance = 5.0
  let dist_left = (endpoint.x - box.x).abs()
  let dist_right = (endpoint.x - (box.x + box.width)).abs()
  let dist_top = (endpoint.y - box.y).abs()
  let dist_bottom = (endpoint.y - (box.y + box.height)).abs()
  // Find the closest boundary
  let min_dist = min_double(
    min_double(dist_left, dist_right),
    min_double(dist_top, dist_bottom),
  )
  if min_dist > tolerance * 10.0 {
    // Endpoint is not close to any boundary - fallback to direction-based
    let dx = _other.x - endpoint.x
    let dy = _other.y - endpoint.y
    let is_horizontal = dx.abs() > dy.abs()
    if is_horizontal {
      if dx > 0.0 {
        @graph.Right
      } else {
        @graph.Left
      }
    } else if dy > 0.0 {
      @graph.Bottom
    } else {
      @graph.Top
    }
  } else if dist_left <= min_dist + tolerance {
    @graph.Left
  } else if dist_right <= min_dist + tolerance {
    @graph.Right
  } else if dist_top <= min_dist + tolerance {
    @graph.Top
  } else {
    @graph.Bottom
  }
}

///|
fn compute_position_on_side(
  point : @graph.Point,
  box : @graph.Box,
  side : @graph.PortSide,
) -> Double {
  match side {
    @graph.Top | @graph.Bottom => {
      let t = (point.x - box.x) / box.width
      clamp(t, 0.0, 1.0)
    }
    @graph.Left | @graph.Right => {
      let t = (point.y - box.y) / box.height
      clamp(t, 0.0, 1.0)
    }
  }
}
