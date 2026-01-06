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
/// Route types for edge path rendering
///
/// This module defines routing styles and waypoint management for edges.

///|
/// Route style for edge paths
pub enum RouteStyle {
  /// Direct straight line between endpoints
  Straight
  /// Smooth bezier curve
  Curved
  /// Right-angle turns (Manhattan routing)
  Elbow
  /// Optimal axis-aligned routing that avoids obstacles
  Orthogonal
} derive(Eq, Show)

///|
/// Parse route style from string
pub fn RouteStyle::from_string(s : String) -> RouteStyle {
  match s.to_lower() {
    "straight" | "line" | "direct" => Straight
    "curved" | "curve" | "bezier" => Curved
    "elbow" | "manhattan" => Elbow
    "orthogonal" | "ortho" => Orthogonal
    _ => Straight // Default
  }
}

///|
/// Convert route style to canonical string
pub fn RouteStyle::to_route_string(self : RouteStyle) -> String {
  match self {
    Straight => "straight"
    Curved => "curved"
    Elbow => "elbow"
    Orthogonal => "orthogonal"
  }
}

///|
/// Check if this style uses curves
pub fn RouteStyle::is_curved(self : RouteStyle) -> Bool {
  match self {
    Curved => true
    _ => false
  }
}

///|
/// Check if this style uses right angles
pub fn RouteStyle::is_orthogonal(self : RouteStyle) -> Bool {
  match self {
    Elbow | Orthogonal => true
    _ => false
  }
}

///|
/// A waypoint along an edge route
pub struct Waypoint {
  /// X coordinate
  x : Double
  /// Y coordinate
  y : Double
  /// Optional control point for curves (for bezier curves)
  control : (Double, Double)?
} derive(Show)

///|
/// Create a simple waypoint
pub fn Waypoint::new(x : Double, y : Double) -> Waypoint {
  { x, y, control: None }
}

///|
/// Create a waypoint with a bezier control point
pub fn Waypoint::with_control(
  x : Double,
  y : Double,
  cx : Double,
  cy : Double,
) -> Waypoint {
  { x, y, control: Some((cx, cy)) }
}

///|
/// Convert waypoint to Point
pub fn Waypoint::to_point(self : Waypoint) -> Point {
  Point::new(self.x, self.y)
}

///|
/// Route configuration for an edge
pub struct Route {
  /// The routing style
  style : RouteStyle
  /// Waypoints along the route (including start and end)
  waypoints : Array[Waypoint]
  /// Source arrowhead type
  src_arrowhead : ArrowheadType
  /// Destination arrowhead type
  dst_arrowhead : ArrowheadType
} derive(Show)

///|
/// Create a new empty route with default style
pub fn Route::new() -> Route {
  {
    style: Straight,
    waypoints: [],
    src_arrowhead: None,
    dst_arrowhead: Triangle,
  }
}

///|
/// Create a route with specified style
pub fn Route::with_style(style : RouteStyle) -> Route {
  { style, waypoints: [], src_arrowhead: None, dst_arrowhead: Triangle }
}

///|
/// Add a waypoint to the route
pub fn Route::add_waypoint(self : Route, wp : Waypoint) -> Unit {
  self.waypoints.push(wp)
}

///|
/// Add a simple point to the route
pub fn Route::add_point(self : Route, x : Double, y : Double) -> Unit {
  self.waypoints.push(Waypoint::new(x, y))
}

///|
/// Get all points as a simple array (for backward compatibility)
pub fn Route::to_points(self : Route) -> Array[Point] {
  let points : Array[Point] = []
  for wp in self.waypoints {
    points.push(wp.to_point())
  }
  points
}

///|
/// Check if route has any waypoints
pub fn Route::is_empty(self : Route) -> Bool {
  self.waypoints.is_empty()
}

///|
/// Get the number of waypoints
pub fn Route::length(self : Route) -> Int {
  self.waypoints.length()
}

///|
/// Get the starting point of the route
pub fn Route::start(self : Route) -> Waypoint? {
  if self.waypoints.is_empty() {
    None
  } else {
    Some(self.waypoints[0])
  }
}

///|
/// Get the ending point of the route
pub fn Route::end(self : Route) -> Waypoint? {
  if self.waypoints.is_empty() {
    None
  } else {
    Some(self.waypoints[self.waypoints.length() - 1])
  }
}

///|
/// Convert from Edge's simple route (Array[Point]) to Route
pub fn Route::from_points(
  points : Array[Point],
  style : RouteStyle,
  src : ArrowheadType,
  dst : ArrowheadType,
) -> Route {
  let waypoints : Array[Waypoint] = []
  for p in points {
    waypoints.push(Waypoint::new(p.x, p.y))
  }
  { style, waypoints, src_arrowhead: src, dst_arrowhead: dst }
}
