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
/// compatibility typed theme override set.
///
/// This mirrors upstream `d2target.ThemeOverrides`, including fixed field
/// coverage and stable declaration order.
pub struct ThemeOverrides {
  n1 : String?
  n2 : String?
  n3 : String?
  n4 : String?
  n5 : String?
  n6 : String?
  n7 : String?
  b1 : String?
  b2 : String?
  b3 : String?
  b4 : String?
  b5 : String?
  b6 : String?
  aa2 : String?
  aa4 : String?
  aa5 : String?
  ab4 : String?
  ab5 : String?
} derive(Eq, Show)

///|
pub fn ThemeOverrides::new() -> ThemeOverrides {
  {
    n1: None,
    n2: None,
    n3: None,
    n4: None,
    n5: None,
    n6: None,
    n7: None,
    b1: None,
    b2: None,
    b3: None,
    b4: None,
    b5: None,
    b6: None,
    aa2: None,
    aa4: None,
    aa5: None,
    ab4: None,
    ab5: None,
  }
}

///|
pub fn ThemeOverrides::is_empty(self : ThemeOverrides) -> Bool {
  self.n1 is None &&
  self.n2 is None &&
  self.n3 is None &&
  self.n4 is None &&
  self.n5 is None &&
  self.n6 is None &&
  self.n7 is None &&
  self.b1 is None &&
  self.b2 is None &&
  self.b3 is None &&
  self.b4 is None &&
  self.b5 is None &&
  self.b6 is None &&
  self.aa2 is None &&
  self.aa4 is None &&
  self.aa5 is None &&
  self.ab4 is None &&
  self.ab5 is None
}

///|
pub fn ThemeOverrides::get(self : ThemeOverrides, code : String) -> String? {
  match code.to_upper() {
    "N1" => self.n1
    "N2" => self.n2
    "N3" => self.n3
    "N4" => self.n4
    "N5" => self.n5
    "N6" => self.n6
    "N7" => self.n7
    "B1" => self.b1
    "B2" => self.b2
    "B3" => self.b3
    "B4" => self.b4
    "B5" => self.b5
    "B6" => self.b6
    "AA2" => self.aa2
    "AA4" => self.aa4
    "AA5" => self.aa5
    "AB4" => self.ab4
    "AB5" => self.ab5
    _ => None
  }
}

///|
pub fn ThemeOverrides::with_code(
  self : ThemeOverrides,
  code : String,
  value : String,
) -> ThemeOverrides {
  match code.to_upper() {
    "N1" => { ..self, n1: Some(value) }
    "N2" => { ..self, n2: Some(value) }
    "N3" => { ..self, n3: Some(value) }
    "N4" => { ..self, n4: Some(value) }
    "N5" => { ..self, n5: Some(value) }
    "N6" => { ..self, n6: Some(value) }
    "N7" => { ..self, n7: Some(value) }
    "B1" => { ..self, b1: Some(value) }
    "B2" => { ..self, b2: Some(value) }
    "B3" => { ..self, b3: Some(value) }
    "B4" => { ..self, b4: Some(value) }
    "B5" => { ..self, b5: Some(value) }
    "B6" => { ..self, b6: Some(value) }
    "AA2" => { ..self, aa2: Some(value) }
    "AA4" => { ..self, aa4: Some(value) }
    "AA5" => { ..self, aa5: Some(value) }
    "AB4" => { ..self, ab4: Some(value) }
    "AB5" => { ..self, ab5: Some(value) }
    _ => self
  }
}

///|
pub fn ThemeOverrides::merge(
  self : ThemeOverrides,
  other : ThemeOverrides,
) -> ThemeOverrides {
  {
    n1: theme_override_value(self.n1, other.n1),
    n2: theme_override_value(self.n2, other.n2),
    n3: theme_override_value(self.n3, other.n3),
    n4: theme_override_value(self.n4, other.n4),
    n5: theme_override_value(self.n5, other.n5),
    n6: theme_override_value(self.n6, other.n6),
    n7: theme_override_value(self.n7, other.n7),
    b1: theme_override_value(self.b1, other.b1),
    b2: theme_override_value(self.b2, other.b2),
    b3: theme_override_value(self.b3, other.b3),
    b4: theme_override_value(self.b4, other.b4),
    b5: theme_override_value(self.b5, other.b5),
    b6: theme_override_value(self.b6, other.b6),
    aa2: theme_override_value(self.aa2, other.aa2),
    aa4: theme_override_value(self.aa4, other.aa4),
    aa5: theme_override_value(self.aa5, other.aa5),
    ab4: theme_override_value(self.ab4, other.ab4),
    ab5: theme_override_value(self.ab5, other.ab5),
  }
}

///|
pub fn ThemeOverrides::entries(
  self : ThemeOverrides,
) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  theme_override_push(out, "N1", self.n1)
  theme_override_push(out, "N2", self.n2)
  theme_override_push(out, "N3", self.n3)
  theme_override_push(out, "N4", self.n4)
  theme_override_push(out, "N5", self.n5)
  theme_override_push(out, "N6", self.n6)
  theme_override_push(out, "N7", self.n7)
  theme_override_push(out, "B1", self.b1)
  theme_override_push(out, "B2", self.b2)
  theme_override_push(out, "B3", self.b3)
  theme_override_push(out, "B4", self.b4)
  theme_override_push(out, "B5", self.b5)
  theme_override_push(out, "B6", self.b6)
  theme_override_push(out, "AA2", self.aa2)
  theme_override_push(out, "AA4", self.aa4)
  theme_override_push(out, "AA5", self.aa5)
  theme_override_push(out, "AB4", self.ab4)
  theme_override_push(out, "AB5", self.ab5)
  out
}

///|
pub fn merge_theme_overrides(
  base : ThemeOverrides?,
  overlay : ThemeOverrides?,
) -> ThemeOverrides? {
  match (base, overlay) {
    (None, None) => None
    (Some(current), None) =>
      if current.is_empty() {
        None
      } else {
        Some(current)
      }
    (None, Some(next)) => if next.is_empty() { None } else { Some(next) }
    (Some(current), Some(next)) => {
      let merged = current.merge(next)
      if merged.is_empty() {
        None
      } else {
        Some(merged)
      }
    }
  }
}

///|
fn theme_override_value(base : String?, overlay : String?) -> String? {
  match overlay {
    Some(value) => Some(value)
    None => base
  }
}

///|
fn theme_override_push(
  out : Array[(String, String)],
  code : String,
  value : String?,
) -> Unit {
  match value {
    Some(resolved) => out.push((code, resolved))
    None => ()
  }
}
