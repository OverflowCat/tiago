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
/// Pure ASCII Grid Library
///
/// A 2D character canvas for building ASCII art diagrams.

///|
/// 2D character grid for ASCII rendering
pub struct Grid {
  width : Int
  height : Int
  cells : Array[Array[Char]]
}

///|
/// Create a new grid filled with spaces
pub fn Grid::new(width : Int, height : Int) -> Grid {
  let cells : Array[Array[Char]] = []
  for _ in 0..<height {
    let row : Array[Char] = []
    for _ in 0..<width {
      row.push(' ')
    }
    cells.push(row)
  }
  { width, height, cells }
}

///|
/// Get grid width
pub fn Grid::get_width(self : Grid) -> Int {
  self.width
}

///|
/// Get grid height
pub fn Grid::get_height(self : Grid) -> Int {
  self.height
}

///|
/// Set a character at position (x, y)
pub fn Grid::set(self : Grid, x : Int, y : Int, ch : Char) -> Unit {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.cells[y][x] = ch
  }
}

///|
/// Get character at position (x, y)
pub fn Grid::get(self : Grid, x : Int, y : Int) -> Char {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.cells[y][x]
  } else {
    ' '
  }
}

///|
/// Write text starting at position (x, y)
pub fn Grid::text(self : Grid, x : Int, y : Int, text : String) -> Unit {
  let mut col = x
  for ch in text {
    self.set(col, y, ch)
    col = col + 1
  }
}

///|
/// Draw a horizontal line from (x1, y) to (x2, y)
pub fn Grid::hline(self : Grid, x1 : Int, x2 : Int, y : Int, ch : Char) -> Unit {
  let start = if x1 < x2 { x1 } else { x2 }
  let end = if x1 < x2 { x2 } else { x1 }
  for x in start..=end {
    self.set(x, y, ch)
  }
}

///|
/// Draw a vertical line from (x, y1) to (x, y2)
pub fn Grid::vline(self : Grid, x : Int, y1 : Int, y2 : Int, ch : Char) -> Unit {
  let start = if y1 < y2 { y1 } else { y2 }
  let end = if y1 < y2 { y2 } else { y1 }
  for y in start..=end {
    self.set(x, y, ch)
  }
}

///|
/// Draw a rectangle outline
pub fn Grid::rect(
  self : Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  corner : Char,
  horiz : Char,
  vert : Char,
) -> Unit {
  // Corners
  self.set(x1, y1, corner)
  self.set(x2, y1, corner)
  self.set(x1, y2, corner)
  self.set(x2, y2, corner)
  // Edges
  self.hline(x1 + 1, x2 - 1, y1, horiz)
  self.hline(x1 + 1, x2 - 1, y2, horiz)
  self.vline(x1, y1 + 1, y2 - 1, vert)
  self.vline(x2, y1 + 1, y2 - 1, vert)
}

///|
/// Draw a rectangle with ASCII box-drawing characters
/// Uses: + - |
pub fn Grid::ascii_rect(
  self : Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  self.box_rect(x1, y1, x2, y2, CharSet::ascii())
}

///|
/// Draw a rectangle using a CharSet
pub fn Grid::box_rect(
  self : Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  cs : CharSet,
) -> Unit {
  // Corners
  self.set(x1, y1, cs.top_left())
  self.set(x2, y1, cs.top_right())
  self.set(x1, y2, cs.bottom_left())
  self.set(x2, y2, cs.bottom_right())
  // Edges
  self.hline(x1 + 1, x2 - 1, y1, cs.horizontal())
  self.hline(x1 + 1, x2 - 1, y2, cs.horizontal())
  self.vline(x1, y1 + 1, y2 - 1, cs.vertical())
  self.vline(x2, y1 + 1, y2 - 1, cs.vertical())
}

///|
/// Draw a rounded rectangle using a CharSet
pub fn Grid::rounded_rect(
  self : Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  cs : CharSet,
) -> Unit {
  // Rounded corners
  self.set(x1, y1, cs.top_left_arc())
  self.set(x2, y1, cs.top_right_arc())
  self.set(x1, y2, cs.bottom_left_arc())
  self.set(x2, y2, cs.bottom_right_arc())
  // Edges
  self.hline(x1 + 1, x2 - 1, y1, cs.horizontal())
  self.hline(x1 + 1, x2 - 1, y2, cs.horizontal())
  self.vline(x1, y1 + 1, y2 - 1, cs.vertical())
  self.vline(x2, y1 + 1, y2 - 1, cs.vertical())
}

///|
/// Draw a line between two points (handles vertical, horizontal, diagonal)
pub fn Grid::line(
  self : Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  horiz : Char,
  vert : Char,
  diag_down : Char,
  diag_up : Char,
) -> Unit {
  if x1 == x2 {
    self.vline(x1, y1, y2, vert)
  } else if y1 == y2 {
    self.hline(x1, x2, y1, horiz)
  } else {
    // Diagonal using simple step
    let dx = if x2 > x1 { 1 } else { -1 }
    let dy = if y2 > y1 { 1 } else { -1 }
    let ch = if (dx > 0) == (dy > 0) { diag_down } else { diag_up }
    let mut x = x1
    let mut y = y1
    while x != x2 || y != y2 {
      self.set(x, y, ch)
      if x != x2 {
        x = x + dx
      }
      if y != y2 {
        y = y + dy
      }
    }
    self.set(x2, y2, ch)
  }
}

///|
/// Fill a rectangular area with a character
pub fn Grid::fill(
  self : Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  ch : Char,
) -> Unit {
  let start_x = if x1 < x2 { x1 } else { x2 }
  let end_x = if x1 < x2 { x2 } else { x1 }
  let start_y = if y1 < y2 { y1 } else { y2 }
  let end_y = if y1 < y2 { y2 } else { y1 }
  for y in start_y..=end_y {
    for x in start_x..=end_x {
      self.set(x, y, ch)
    }
  }
}

///|
/// Convert grid to string
pub fn Grid::to_string(self : Grid) -> String {
  let sb = StringBuilder::new()
  for row in self.cells {
    // Find last non-space character to trim trailing spaces
    let mut last_non_space = -1
    for i, ch in row {
      if ch != ' ' {
        last_non_space = i
      }
    }
    // Write up to last non-space character
    for i = 0; i <= last_non_space; i = i + 1 {
      sb.write_char(row[i])
    }
    sb.write_char('\n')
  }
  sb.to_string()
}

///|
pub impl Show for Grid with output(self, logger) {
  logger.write_string(self.to_string())
}
