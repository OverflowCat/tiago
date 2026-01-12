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
/// Bounding box for positioning
pub struct Box {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Show)

///|
/// A 2D point
pub struct Point {
  x : Double
  y : Double
} derive(Eq, Show)

///|
pub fn Box::new(x : Double, y : Double, width : Double, height : Double) -> Box {
  { x, y, width, height }
}

///|
pub fn Box::zero() -> Box {
  { x: 0.0, y: 0.0, width: 0.0, height: 0.0 }
}

///|
pub fn Point::new(x : Double, y : Double) -> Point {
  { x, y }
}

///|
pub fn Point::zero() -> Point {
  { x: 0.0, y: 0.0 }
}

///|
/// Get the center point of the box
pub fn Box::center(self : Box) -> Point {
  Point::new(self.x + self.width / 2.0, self.y + self.height / 2.0)
}

///|
/// Get the top-left corner
pub fn Box::top_left(self : Box) -> Point {
  Point::new(self.x, self.y)
}

///|
/// Get the top-right corner
pub fn Box::top_right(self : Box) -> Point {
  Point::new(self.x + self.width, self.y)
}

///|
/// Get the bottom-left corner
pub fn Box::bottom_left(self : Box) -> Point {
  Point::new(self.x, self.y + self.height)
}

///|
/// Get the bottom-right corner
pub fn Box::bottom_right(self : Box) -> Point {
  Point::new(self.x + self.width, self.y + self.height)
}

///|
/// Check if a point is inside the box
pub fn Box::contains(self : Box, p : Point) -> Bool {
  p.x >= self.x &&
  p.x <= self.x + self.width &&
  p.y >= self.y &&
  p.y <= self.y + self.height
}

///|
/// Check if this box intersects another
pub fn Box::intersects(self : Box, other : Box) -> Bool {
  not(
    self.x + self.width < other.x ||
    other.x + other.width < self.x ||
    self.y + self.height < other.y ||
    other.y + other.height < self.y,
  )
}

///|
/// Get x coordinate
pub fn Box::get_x(self : Box) -> Double {
  self.x
}

///|
/// Get y coordinate
pub fn Box::get_y(self : Box) -> Double {
  self.y
}

///|
/// Get width
pub fn Box::get_width(self : Box) -> Double {
  self.width
}

///|
/// Get height
pub fn Box::get_height(self : Box) -> Double {
  self.height
}

///|
/// Get x coordinate
pub fn Point::get_x(self : Point) -> Double {
  self.x
}

///|
/// Get y coordinate
pub fn Point::get_y(self : Point) -> Double {
  self.y
}

///|
/// Calculate distance to another point
pub fn Point::distance(self : Point, other : Point) -> Double {
  let dx = self.x - other.x
  let dy = self.y - other.y
  (dx * dx + dy * dy).sqrt()
}

///|
/// Add two points
pub fn Point::add(self : Point, other : Point) -> Point {
  Point::new(self.x + other.x, self.y + other.y)
}

///|
/// Subtract another point
pub fn Point::sub(self : Point, other : Point) -> Point {
  Point::new(self.x - other.x, self.y - other.y)
}

///|
/// Scale by a factor
pub fn Point::scale(self : Point, factor : Double) -> Point {
  Point::new(self.x * factor, self.y * factor)
}
