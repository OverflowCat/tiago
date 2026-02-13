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
/// Character Set abstraction for ASCII/Unicode rendering modes

///|
/// Character set for box drawing
pub struct CharSet {
  // Box corners
  top_left : Char
  top_right : Char
  bottom_left : Char
  bottom_right : Char
  // Lines
  horizontal : Char
  vertical : Char
  left_vertical : Char
  right_vertical : Char
  // Rounded corners (arcs)
  top_left_arc : Char
  top_right_arc : Char
  bottom_left_arc : Char
  bottom_right_arc : Char
  // Arrows
  arrow_down : Char
  arrow_up : Char
  arrow_right : Char
  arrow_left : Char
  // T-junctions
  t_down : Char
  t_up : Char
  t_right : Char
  t_left : Char
  // Cross
  cross : Char
  // Diagonals
  diagonal_down : Char
  diagonal_up : Char
  // Cylinder/special characters
  dot : Char
  hyphen : Char
  tilde : Char
  overline : Char
  underscore : Char
  // Shape symbols
  cloud : Char
  circle : Char
  oval : Char
  star : Char
} derive(Show)

///|
/// ASCII character set - uses only 7-bit ASCII characters
pub fn CharSet::ascii() -> CharSet {
  {
    // Box corners
    top_left: '+',
    top_right: '+',
    bottom_left: '+',
    bottom_right: '+',
    // Lines
    horizontal: '-',
    vertical: '|',
    left_vertical: '|',
    right_vertical: '|',
    // Rounded corners (ASCII approximation)
    top_left_arc: '.',
    top_right_arc: '.',
    bottom_left_arc: '\'',
    bottom_right_arc: '\'',
    // Arrows
    arrow_down: 'v',
    arrow_up: '^',
    arrow_right: '>',
    arrow_left: '<',
    // T-junctions
    t_down: '+',
    t_up: '+',
    t_right: '+',
    t_left: '+',
    // Cross
    cross: 'X',
    // Diagonals
    diagonal_down: '\\',
    diagonal_up: '/',
    // Cylinder/special
    dot: '.',
    hyphen: '-',
    tilde: '~',
    overline: '-',
    underscore: '_',
    // Shape symbols
    cloud: '@',
    circle: 'o',
    oval: 'O',
    star: '*',
  }
}

///|
/// Unicode character set - uses box-drawing characters
pub fn CharSet::unicode() -> CharSet {
  {
    // Box corners
    top_left: '┌',
    top_right: '┐',
    bottom_left: '└',
    bottom_right: '┘',
    // Lines
    horizontal: '─',
    vertical: '│',
    left_vertical: '▏',
    right_vertical: '▕',
    // Rounded corners
    top_left_arc: '╭',
    top_right_arc: '╮',
    bottom_left_arc: '╰',
    bottom_right_arc: '╯',
    // Arrows
    arrow_down: '▼',
    arrow_up: '▲',
    arrow_right: '▶',
    arrow_left: '◀',
    // T-junctions
    t_down: '┬',
    t_up: '┴',
    t_right: '├',
    t_left: '┤',
    // Cross
    cross: '╳',
    // Diagonals
    diagonal_down: '╲',
    diagonal_up: '╱',
    // Cylinder/special
    dot: '.',
    hyphen: '-',
    tilde: '`',
    overline: '‾',
    underscore: '_',
    // Shape symbols
    cloud: '☁',
    circle: '●',
    oval: '⬭',
    star: '*',
  }
}

///|
/// Accessors for box corners
pub fn CharSet::top_left(self : CharSet) -> Char {
  self.top_left
}

///|
pub fn CharSet::top_right(self : CharSet) -> Char {
  self.top_right
}

///|
pub fn CharSet::bottom_left(self : CharSet) -> Char {
  self.bottom_left
}

///|
pub fn CharSet::bottom_right(self : CharSet) -> Char {
  self.bottom_right
}

///|
/// Accessors for lines
pub fn CharSet::horizontal(self : CharSet) -> Char {
  self.horizontal
}

///|
pub fn CharSet::vertical(self : CharSet) -> Char {
  self.vertical
}

///|
pub fn CharSet::left_vertical(self : CharSet) -> Char {
  self.left_vertical
}

///|
pub fn CharSet::right_vertical(self : CharSet) -> Char {
  self.right_vertical
}

///|
/// Accessors for rounded corners
pub fn CharSet::top_left_arc(self : CharSet) -> Char {
  self.top_left_arc
}

///|
pub fn CharSet::top_right_arc(self : CharSet) -> Char {
  self.top_right_arc
}

///|
pub fn CharSet::bottom_left_arc(self : CharSet) -> Char {
  self.bottom_left_arc
}

///|
pub fn CharSet::bottom_right_arc(self : CharSet) -> Char {
  self.bottom_right_arc
}

///|
/// Accessors for arrows
pub fn CharSet::arrow_down(self : CharSet) -> Char {
  self.arrow_down
}

///|
pub fn CharSet::arrow_up(self : CharSet) -> Char {
  self.arrow_up
}

///|
pub fn CharSet::arrow_right(self : CharSet) -> Char {
  self.arrow_right
}

///|
pub fn CharSet::arrow_left(self : CharSet) -> Char {
  self.arrow_left
}

///|
/// Accessors for T-junctions
pub fn CharSet::t_down(self : CharSet) -> Char {
  self.t_down
}

///|
pub fn CharSet::t_up(self : CharSet) -> Char {
  self.t_up
}

///|
pub fn CharSet::t_right(self : CharSet) -> Char {
  self.t_right
}

///|
pub fn CharSet::t_left(self : CharSet) -> Char {
  self.t_left
}

///|
/// Accessor for cross
pub fn CharSet::cross(self : CharSet) -> Char {
  self.cross
}

///|
/// Accessors for diagonals
pub fn CharSet::diagonal_down(self : CharSet) -> Char {
  self.diagonal_down
}

///|
pub fn CharSet::diagonal_up(self : CharSet) -> Char {
  self.diagonal_up
}

///|
pub fn CharSet::backslash(self : CharSet) -> Char {
  self.diagonal_down
}

///|
pub fn CharSet::forwardslash(self : CharSet) -> Char {
  self.diagonal_up
}

///|
/// Accessors for cylinder/special characters
pub fn CharSet::dot(self : CharSet) -> Char {
  self.dot
}

///|
pub fn CharSet::hyphen(self : CharSet) -> Char {
  self.hyphen
}

///|
pub fn CharSet::tilde(self : CharSet) -> Char {
  self.tilde
}

///|
pub fn CharSet::overline(self : CharSet) -> Char {
  self.overline
}

///|
pub fn CharSet::underscore(self : CharSet) -> Char {
  self.underscore
}

///|
pub fn CharSet::cloud(self : CharSet) -> Char {
  self.cloud
}

///|
pub fn CharSet::circle(self : CharSet) -> Char {
  self.circle
}

///|
pub fn CharSet::oval(self : CharSet) -> Char {
  self.oval
}

///|
pub fn CharSet::star(self : CharSet) -> Char {
  self.star
}
