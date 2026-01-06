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
// S-Shape and Ladder Elimination
// ============================================================================

///|
/// Optimize edge routes by removing unnecessary bends (S-shapes and ladders)
/// This post-processing step improves visual quality by straightening edges
/// where possible without increasing edge crossings.
fn eliminate_unnecessary_bends(graph : @graph.Graph) -> Unit {
  for edge in graph.edges {
    if edge.route.length() < 3 {
      continue
    }
    // Make multiple passes until no more improvements
    let mut improved = true
    while improved {
      improved = false
      let mut i = 0
      while i < edge.route.length() - 2 {
        let p0 = edge.route[i]
        let p1 = edge.route[i + 1]
        let p2 = edge.route[i + 2]
        // Check if removing p1 would create a valid straight-ish line
        if can_remove_waypoint(p0, p1, p2, graph, edge) {
          // Remove the middle point
          let new_route : Array[@graph.Point] = []
          for j, pt in edge.route {
            if j != i + 1 {
              new_route.push(pt)
            }
          }
          edge.route.clear()
          for pt in new_route {
            edge.route.push(pt)
          }
          improved = true
          // Don't increment i, check the new triple at this position
        } else {
          i = i + 1
        }
      }
    }
  }
}

///|
/// Check if removing the middle waypoint would improve the edge route
fn can_remove_waypoint(
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  graph : @graph.Graph,
  edge : @graph.Edge,
) -> Bool {
  // Remove if points are collinear (on same line) - middle point is redundant
  // Also remove if this forms an S-shape (direction reversal)
  if not(are_collinear(p0, p1, p2)) && not(is_s_shape(p0, p1, p2)) {
    return false
  }
  // Check if the direct line would intersect any objects
  if line_intersects_objects(p0, p2, graph, edge) {
    return false
  }
  true
}

///|
/// Check if three points are collinear (on the same line)
/// Uses cross product: if (p1-p0) × (p2-p0) ≈ 0, points are collinear
fn are_collinear(
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
) -> Bool {
  let dx1 = p1.x - p0.x
  let dy1 = p1.y - p0.y
  let dx2 = p2.x - p0.x
  let dy2 = p2.y - p0.y
  // Cross product: dx1*dy2 - dy1*dx2
  // If close to zero, points are collinear
  let cross = dx1 * dy2 - dy1 * dx2
  cross.abs() < 1.0
}

///|
/// Check if three points form an S-shape (horizontal or vertical direction reversal)
/// Only removes waypoints that form S-shapes, NOT orthogonal corners
fn is_s_shape(p0 : @graph.Point, p1 : @graph.Point, p2 : @graph.Point) -> Bool {
  let dx1 = p1.x - p0.x
  let dy1 = p1.y - p0.y
  let dx2 = p2.x - p1.x
  let dy2 = p2.y - p1.y
  // Check if this is an orthogonal corner (railroad style) - don't remove these!
  // Orthogonal: one segment is vertical (dx≈0) and other is horizontal (dy≈0)
  let is_seg1_vertical = dx1.abs() < 1.0 && dy1.abs() > 1.0
  let is_seg1_horizontal = dy1.abs() < 1.0 && dx1.abs() > 1.0
  let is_seg2_vertical = dx2.abs() < 1.0 && dy2.abs() > 1.0
  let is_seg2_horizontal = dy2.abs() < 1.0 && dx2.abs() > 1.0
  // If this forms an orthogonal corner, preserve it
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
/// Check if a line segment intersects any object boxes (excluding edge endpoints)
fn line_intersects_objects(
  p0 : @graph.Point,
  p1 : @graph.Point,
  graph : @graph.Graph,
  edge : @graph.Edge,
) -> Bool {
  for obj in graph.objects {
    // Skip source and destination objects
    if obj.id == edge.src_id || obj.id == edge.dst_id {
      continue
    }
    match obj.box {
      Some(b) => if line_intersects_box(p0, p1, b) { return true }
      None => ()
    }
  }
  false
}

///|
/// Check if a line segment intersects any object boxes (with parent skip for SQL tables)
fn line_intersects_objects_with_skip(
  p0 : @graph.Point,
  p1 : @graph.Point,
  graph : @graph.Graph,
  edge : @graph.Edge,
  src_parent : String?,
  dst_parent : String?,
) -> Bool {
  for obj in graph.objects {
    // Skip source and destination objects
    if obj.id == edge.src_id || obj.id == edge.dst_id {
      continue
    }
    // Skip parent tables for SQL field connections
    if src_parent is Some(p) && obj.id == p {
      continue
    }
    if dst_parent is Some(p) && obj.id == p {
      continue
    }
    match obj.box {
      Some(b) => if line_intersects_box(p0, p1, b) { return true }
      None => ()
    }
  }
  false
}

///|
/// Check if a line segment intersects a box
fn line_intersects_box(
  p0 : @graph.Point,
  p1 : @graph.Point,
  box : @graph.Box,
) -> Bool {
  // Add a small margin to avoid edge cases
  let margin = 2.0
  let left = box.x - margin
  let right = box.x + box.width + margin
  let top = box.y - margin
  let bottom = box.y + box.height + margin
  // Check if line segment intersects any of the 4 box edges
  // Left edge
  if line_segments_intersect(p0.x, p0.y, p1.x, p1.y, left, top, left, bottom) {
    return true
  }
  // Right edge
  if line_segments_intersect(p0.x, p0.y, p1.x, p1.y, right, top, right, bottom) {
    return true
  }
  // Top edge
  if line_segments_intersect(p0.x, p0.y, p1.x, p1.y, left, top, right, top) {
    return true
  }
  // Bottom edge
  if line_segments_intersect(
      p0.x,
      p0.y,
      p1.x,
      p1.y,
      left,
      bottom,
      right,
      bottom,
    ) {
    return true
  }
  // Check if line is entirely inside the box
  if p0.x > left && p0.x < right && p0.y > top && p0.y < bottom {
    return true
  }
  if p1.x > left && p1.x < right && p1.y > top && p1.y < bottom {
    return true
  }
  false
}

///|
/// Check if two line segments intersect
fn line_segments_intersect(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
  x4 : Double,
  y4 : Double,
) -> Bool {
  let d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
  if d.abs() < 0.0001 {
    return false // Parallel lines
  }
  let t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / d
  let u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / d
  t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0
}
