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
/// Theme System for diago Diagrams
///
/// Provides color palettes and special rendering rules.

///|
/// Color palette for a theme
pub struct ColorPalette {
  /// Neutral colors (N1-N7, dark to light)
  n1 : String
  n2 : String
  n3 : String
  n4 : String
  n5 : String
  n6 : String
  n7 : String
  /// Base colors (B1-B6, for containers)
  b1 : String
  b2 : String
  b3 : String
  b4 : String
  b5 : String
  b6 : String
  /// Alternative colors A (AA2, AA4, AA5)
  aa2 : String
  aa4 : String
  aa5 : String
  /// Alternative colors B (AB4, AB5)
  ab4 : String
  ab5 : String
} derive(Show)

///|
/// Special rendering rules
pub struct SpecialRules {
  /// Use monospace font
  mono : Bool
  /// Disable rounded corners
  no_corner_radius : Bool
  /// Double border on outer containers
  outer_container_double_border : Bool
  /// Render dots at container corners
  container_dots : Bool
  /// Force uppercase text
  caps_lock : Bool
  /// All backgrounds white
  all_paper : Bool
} derive(Show)

///|
pub fn SpecialRules::default() -> SpecialRules {
  {
    mono: false,
    no_corner_radius: false,
    outer_container_double_border: false,
    container_dots: false,
    caps_lock: false,
    all_paper: false,
  }
}

///|
/// A complete theme definition
pub struct Theme {
  id : Int
  name : String
  colors : ColorPalette
  rules : SpecialRules
  is_dark : Bool
} derive(Show)

///|
pub fn Theme::get_id(self : Theme) -> Int {
  self.id
}

///|
pub fn Theme::get_name(self : Theme) -> String {
  self.name
}

///|
pub fn Theme::is_dark(self : Theme) -> Bool {
  self.is_dark
}

///|
/// Resolve a theme color code to hex value
pub fn Theme::resolve(self : Theme, code : String) -> String {
  match code {
    "N1" => self.colors.n1
    "N2" => self.colors.n2
    "N3" => self.colors.n3
    "N4" => self.colors.n4
    "N5" => self.colors.n5
    "N6" => self.colors.n6
    "N7" => self.colors.n7
    "B1" => self.colors.b1
    "B2" => self.colors.b2
    "B3" => self.colors.b3
    "B4" => self.colors.b4
    "B5" => self.colors.b5
    "B6" => self.colors.b6
    "AA2" => self.colors.aa2
    "AA4" => self.colors.aa4
    "AA5" => self.colors.aa5
    "AB4" => self.colors.ab4
    "AB5" => self.colors.ab5
    _ => code // Return as-is if not a theme code
  }
}

///|
/// Get primary text color
pub fn Theme::text_color(self : Theme) -> String {
  self.colors.n1
}

///|
/// Get primary stroke color
pub fn Theme::stroke_color(self : Theme) -> String {
  self.colors.n1
}

///|
/// Get primary fill color
pub fn Theme::fill_color(self : Theme) -> String {
  self.colors.n7
}

///|
/// Get container fill for nesting level (0 = outermost)
pub fn Theme::container_fill(self : Theme, level : Int) -> String {
  match level {
    0 => self.colors.b6
    1 => self.colors.b5
    2 => self.colors.b4
    3 => self.colors.b3
    _ => self.colors.b3
  }
}

///|
/// Get container stroke
pub fn Theme::container_stroke(self : Theme) -> String {
  self.colors.b2
}

///|
/// Get accent color
pub fn Theme::accent_color(self : Theme) -> String {
  self.colors.aa2
}

///|
/// Get background color
pub fn Theme::background_color(self : Theme) -> String {
  self.colors.n7
}

///|
/// Return a copy of this theme with color overrides applied.
pub fn Theme::with_overrides(
  self : Theme,
  overrides : @diagram.ThemeOverrides?,
) -> Theme {
  let mut theme = self
  match overrides {
    None => return self
    Some(override_set) =>
      if override_set.is_empty() {
        return self
      } else {
        match override_set.b1 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, b1: value } }
          None => ()
        }
        match override_set.b2 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, b2: value } }
          None => ()
        }
        match override_set.b3 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, b3: value } }
          None => ()
        }
        match override_set.b4 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, b4: value } }
          None => ()
        }
        match override_set.b5 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, b5: value } }
          None => ()
        }
        match override_set.b6 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, b6: value } }
          None => ()
        }
        match override_set.aa2 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, aa2: value } }
          None => ()
        }
        match override_set.aa4 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, aa4: value } }
          None => ()
        }
        match override_set.aa5 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, aa5: value } }
          None => ()
        }
        match override_set.ab4 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, ab4: value } }
          None => ()
        }
        match override_set.ab5 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, ab5: value } }
          None => ()
        }
        match override_set.n1 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, n1: value } }
          None => ()
        }
        match override_set.n2 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, n2: value } }
          None => ()
        }
        match override_set.n3 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, n3: value } }
          None => ()
        }
        match override_set.n4 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, n4: value } }
          None => ()
        }
        match override_set.n5 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, n5: value } }
          None => ()
        }
        match override_set.n6 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, n6: value } }
          None => ()
        }
        match override_set.n7 {
          Some(value) =>
            theme = { ..theme, colors: { ..theme.colors, n7: value } }
          None => ()
        }
      }
  }
  theme
}
