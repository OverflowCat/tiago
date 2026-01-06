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
/// Improved Orthogonal Edge Routing
///
/// This module implements orthogonal edge routing with:
/// - Routing slots between layers to avoid edge crossings
/// - Proper bend point calculation
/// - Support for edges spanning multiple layers (via dummy nodes)
///
/// Based on ELK's OrthogonalRoutingGenerator concepts

// ============================================================================
// Edge Segment Types
// ============================================================================

///|
/// Represents a vertical segment of an edge between layers
struct EdgeSegment {
  edge_id : String
  source_y : Double // Y coordinate of source connection
  target_y : Double // Y coordinate of target connection
  slot : Int // Routing slot (horizontal position between layers)
} derive(Show)

// Note: EdgeSegment is currently unused but kept for future hyperedge support

// ============================================================================
// Improved Orthogonal Routing
// ============================================================================

///|
/// Route edges orthogonally with proper slot assignment
pub fn route_edges_orthogonal(
  graph : LGraph,
  direction : @elk.LayoutDirection,
  edge_spacing : Double,
) -> Unit {
  let is_vertical = direction.is_vertical()

  // Process edges layer by layer
  if is_vertical {
    route_vertical_layout(graph, edge_spacing)
  } else {
    route_horizontal_layout(graph, edge_spacing)
  }
}

///|
/// Route edges for vertical (top-to-bottom) layouts
fn route_vertical_layout(graph : LGraph, edge_spacing : Double) -> Unit {
  for edge in graph.edges {
    let source = edge.source
    let target = edge.target

    // Skip edges within the same layer
    if source.layer == target.layer {
      continue
    }

    // Clear existing bend points
    edge.bend_points.clear()

    // Calculate source and target connection points
    let src_x = source.x + source.width / 2.0
    let src_y = source.y + source.height // Bottom of source
    let tgt_x = target.x + target.width / 2.0
    let tgt_y = target.y // Top of target

    // Calculate routing
    if (src_x - tgt_x).abs() < 1.0 {
      // Nodes are aligned - straight edge, no bend points needed
      // Bend points will be empty, edge goes straight
    } else {
      // Need orthogonal routing with bends
      // Find midpoint Y between layers
      let mid_y = (src_y + tgt_y) / 2.0

      // For edges spanning multiple layers, we might need intermediate bends
      let layer_diff = (target.layer - source.layer).abs()

      if layer_diff == 1 {
        // Adjacent layers - simple L-shape or Z-shape routing
        edge.bend_points.push(@elk.ElkPoint::new(src_x, mid_y))
        edge.bend_points.push(@elk.ElkPoint::new(tgt_x, mid_y))
      } else {
        // Multi-layer edge - route through intermediate space
        // Use existing dummy node positions if available
        if edge.bend_points.length() == 0 {
          // Fallback: create simple Z-shape
          edge.bend_points.push(@elk.ElkPoint::new(src_x, mid_y))
          edge.bend_points.push(@elk.ElkPoint::new(tgt_x, mid_y))
        }
      }
    }
  }

  // Assign routing slots to avoid overlaps
  assign_routing_slots(graph, edge_spacing, true)
}

///|
/// Route edges for horizontal (left-to-right) layouts
fn route_horizontal_layout(graph : LGraph, edge_spacing : Double) -> Unit {
  for edge in graph.edges {
    let source = edge.source
    let target = edge.target

    // Skip edges within the same layer
    if source.layer == target.layer {
      continue
    }

    // Clear existing bend points
    edge.bend_points.clear()

    // Calculate source and target connection points
    let src_x = source.x + source.width // Right of source
    let src_y = source.y + source.height / 2.0
    let tgt_x = target.x // Left of target
    let tgt_y = target.y + target.height / 2.0

    // Calculate routing
    if (src_y - tgt_y).abs() < 1.0 {
      // Nodes are aligned - straight edge
    } else {
      // Need orthogonal routing
      let mid_x = (src_x + tgt_x) / 2.0
      edge.bend_points.push(@elk.ElkPoint::new(mid_x, src_y))
      edge.bend_points.push(@elk.ElkPoint::new(mid_x, tgt_y))
    }
  }

  assign_routing_slots(graph, edge_spacing, false)
}

///|
/// Assign routing slots to edges to minimize crossings
fn assign_routing_slots(
  graph : LGraph,
  edge_spacing : Double,
  is_vertical : Bool,
) -> Unit {
  // Group edges by the layer pair they cross
  let layer_edges : Map[String, Array[LEdge]] = {}

  for edge in graph.edges {
    let src_layer = edge.source.layer
    let tgt_layer = edge.target.layer

    if src_layer != tgt_layer {
      let key = src_layer.to_string() + "_" + tgt_layer.to_string()
      if !layer_edges.contains(key) {
        layer_edges[key] = []
      }
      match layer_edges.get(key) {
        Some(arr) => arr.push(edge)
        None => ()
      }
    }
  }

  // For each layer pair, assign slots to avoid crossings
  for pair in layer_edges.iter() {
    let (_, edges) = pair
    if edges.length() <= 1 {
      continue
    }

    // Sort edges by their source position to minimize crossings
    if is_vertical {
      edges.sort_by(fn(a, b) {
        let a_x = a.source.x + a.source.width / 2.0
        let b_x = b.source.x + b.source.width / 2.0
        if a_x < b_x {
          -1
        } else if a_x > b_x {
          1
        } else {
          0
        }
      })
    } else {
      edges.sort_by(fn(a, b) {
        let a_y = a.source.y + a.source.height / 2.0
        let b_y = b.source.y + b.source.height / 2.0
        if a_y < b_y {
          -1
        } else if a_y > b_y {
          1
        } else {
          0
        }
      })
    }

    // Adjust bend points to use different routing slots
    for i, edge in edges {
      if edge.bend_points.length() >= 2 {
        let offset = i.to_double() * edge_spacing * 0.5
        // Create new bend points with adjusted coordinates
        let new_bends : Array[@elk.ElkPoint] = []
        for bp in edge.bend_points {
          if is_vertical {
            // Shift horizontal segment vertically
            new_bends.push(@elk.ElkPoint::new(bp.x, bp.y + offset))
          } else {
            // Shift vertical segment horizontally
            new_bends.push(@elk.ElkPoint::new(bp.x + offset, bp.y))
          }
        }
        // Replace bend points
        edge.bend_points.clear()
        for bp in new_bends {
          edge.bend_points.push(bp)
        }
      }
    }
  }
}

// ============================================================================
// Self-Loop Routing
// ============================================================================

///|
/// Route self-loop edges
pub fn route_self_loops(graph : LGraph, _direction : @elk.LayoutDirection) -> Unit {
  for edge in graph.edges {
    if edge.source.id == edge.target.id {
      // This is a self-loop
      let node = edge.source
      edge.bend_points.clear()

      // Route around the right side of the node
      let right_x = node.x + node.width + 20.0
      let top_y = node.y
      let bottom_y = node.y + node.height

      // Create loop path: bottom-right, top-right, back to top
      edge.bend_points.push(@elk.ElkPoint::new(node.x + node.width, bottom_y))
      edge.bend_points.push(@elk.ElkPoint::new(right_x, bottom_y))
      edge.bend_points.push(@elk.ElkPoint::new(right_x, top_y))
      edge.bend_points.push(@elk.ElkPoint::new(node.x + node.width, top_y))
    }
  }
}

// ============================================================================
// Edge Straightening
// ============================================================================

///|
/// Straighten edges by removing unnecessary bend points
pub fn straighten_edges(graph : LGraph) -> Unit {
  for edge in graph.edges {
    if edge.bend_points.length() < 2 {
      continue
    }

    // Remove collinear bend points
    let new_bends : Array[@elk.ElkPoint] = []
    let mut prev : @elk.ElkPoint? = None

    for bp in edge.bend_points {
      match prev {
        Some(p) => {
          // Check if this point is collinear with the previous segment
          if new_bends.length() > 0 {
            let last = new_bends[new_bends.length() - 1]
            // Check if all three points are collinear
            if !is_collinear(last, p, bp) {
              new_bends.push(p)
            }
          } else {
            new_bends.push(p)
          }
        }
        None => ()
      }
      prev = Some(bp)
    }

    // Add the last point if needed
    match prev {
      Some(p) => new_bends.push(p)
      None => ()
    }

    // Update bend points
    edge.bend_points.clear()
    for bp in new_bends {
      edge.bend_points.push(bp)
    }
  }
}

///|
/// Check if three points are collinear
fn is_collinear(p1 : @elk.ElkPoint, p2 : @elk.ElkPoint, p3 : @elk.ElkPoint) -> Bool {
  let dx1 = p2.x - p1.x
  let dy1 = p2.y - p1.y
  let dx2 = p3.x - p2.x
  let dy2 = p3.y - p2.y

  // Check if the cross product is approximately zero
  let cross = dx1 * dy2 - dy1 * dx2
  cross.abs() < 0.001
}
