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
/// E2E regression tests for the example `.d2` inputs.
///
/// These tests compile the example sources using the in-repo ELK engine and
/// compare the rendered output against checked-in golden SVGs.
///
/// We use Milky2018/xml as the XML parser.

///|
struct Box {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Show)

///|
struct Route {
  points : Array[(Double, Double)]
  has_marker_start : Bool
  has_marker_end : Bool
} derive(Eq, Show)

///|
fn quantize_coord(x : Double, scale : Double) -> Int {
  // Stable rounding for route-point comparisons across renderers.
  if x >= 0.0 {
    (x * scale + 0.5).to_int()
  } else {
    (x * scale - 0.5).to_int()
  }
}

///|
fn read_file(path : String) -> Result[String, String] {
  let content = Some(@fs.read_file_to_string(path)) catch { _ => None }
  match content {
    Some(s) => Ok(s)
    None => Err("failed to read file '" + path + "'")
  }
}

///|
fn write_file(path : String, content : String) -> Unit {
  @fs.write_string_to_file(path, content) catch {
    _ => ()
  }
}

///|
fn normalize_newlines(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    if c != '\r' {
      sb.write_char(c)
    }
  }
  let out = sb.to_string()
  if out.has_suffix("\n") {
    out
  } else {
    out + "\n"
  }
}

///|
fn abs(x : Double) -> Double {
  if x < 0.0 {
    -x
  } else {
    x
  }
}

///|
fn approx_eq(a : Double, b : Double, eps : Double) -> Bool {
  abs(a - b) <= eps
}

///|
fn contains_substring(haystack : String, needle : String) -> Bool {
  has_substring(haystack, needle)
}

///|
fn has_substring(haystack : String, needle : String) -> Bool {
  let n = needle.length()
  if n == 0 {
    return true
  }
  let m = haystack.length()
  if m < n {
    return false
  }
  let last = m - n
  for i = 0; i <= last; i = i + 1 {
    let mut ok = true
    for j = 0; j < n; j = j + 1 {
      if haystack[i + j] != needle[j] {
        ok = false
        break
      }
    }
    if ok {
      return true
    }
  }
  false
}

///|
fn parse_double(s : String) -> Double? {
  Some(@strconv.parse_double(s)) catch {
    _ => None
  }
}

///|
fn is_cmd(c : Char) -> Bool {
  let n = c.to_int()
  (n >= 'A'.to_int() && n <= 'Z'.to_int()) ||
  (n >= 'a'.to_int() && n <= 'z'.to_int())
}

///|
fn is_num_char(c : Char) -> Bool {
  let i = c.to_int()
  (i >= '0'.to_int() && i <= '9'.to_int()) || c == '.' || c == '-' || c == '+'
}

///|
fn skip_sep(s : String, i0 : Int) -> Int {
  let mut i = i0
  while i < s.length() {
    let c = s.code_unit_at(i).to_int().unsafe_to_char()
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' || c == ',' {
      i = i + 1
    } else {
      break
    }
  }
  i
}

///|
fn read_number(s : String, i0 : Int) -> (Double?, Int) {
  let mut i = skip_sep(s, i0)
  if i >= s.length() {
    return (None, i)
  }
  let c0 = s.code_unit_at(i).to_int().unsafe_to_char()
  if !is_num_char(c0) {
    return (None, i)
  }
  let start = i
  i = i + 1
  while i < s.length() {
    let c = s.code_unit_at(i).to_int().unsafe_to_char()
    if is_num_char(c) || c == 'e' || c == 'E' {
      i = i + 1
    } else {
      break
    }
  }
  let sb = StringBuilder::new()
  for k in start..<i {
    sb.write_char(s.code_unit_at(k).to_int().unsafe_to_char())
  }
  (parse_double(sb.to_string()), i)
}

///|
fn get_attr(el : @xml.XmlElement, key : String) -> String? {
  el.get(key)
}

///|
fn get_attr_double(el : @xml.XmlElement, key : String) -> Double? {
  match get_attr(el, key) {
    Some(v) => parse_double(v)
    None => None
  }
}

///|
fn collect_elements_by_name(
  svg : String,
  name : String,
) -> Result[Array[@xml.XmlElement], String] {
  let reader = @xml.Reader::from_string(svg)
  let out : Array[@xml.XmlElement] = []
  let restrict = has_substring(svg, "<g id=\"base-layer\"")
  let mut in_base = false
  let mut base_depth = 0
  while true {
    let ev = Some(reader.read_event()) catch { e => return Err(e.to_string()) }
    match ev.unwrap() {
      Start(el) => {
        if restrict &&
          !in_base &&
          el.name == "g" &&
          get_attr(el, "id") == Some("base-layer") {
          in_base = true
          base_depth = 1
        } else if restrict && in_base {
          base_depth = base_depth + 1
        }
        if (!restrict || in_base) && el.name == name {
          out.push(el)
        }
      }
      Empty(el) => if (!restrict || in_base) && el.name == name { out.push(el) }
      End(_) =>
        if restrict && in_base {
          base_depth = base_depth - 1
          if base_depth <= 0 {
            in_base = false
            base_depth = 0
          }
        }
      Eof => break
      _ => ()
    }
  }
  Ok(out)
}

///|
fn extract_text_positions(
  svg : String,
) -> Result[Array[(String, (Double, Double))], String] {
  // D2 renders edge labels as `<text>` over a `mask` rectangle; diago renders
  // them as `<text>` over a small background `<rect stroke="none">`. We filter
  // these out so the "semantic" matching stays focused on node geometry.
  let edge_label_masks = match collect_elements_by_name(svg, "rect") {
    Ok(rects) => {
      let out : Array[Box] = []
      for r in rects {
        let no_stroke = match get_attr(r, "stroke") {
          Some(stroke) => stroke == "none"
          None => true
        }
        if !no_stroke {
          continue
        }
        match
          (
            get_attr_double(r, "x"),
            get_attr_double(r, "y"),
            get_attr_double(r, "width"),
            get_attr_double(r, "height"),
          ) {
          (Some(x), Some(y), Some(w), Some(h)) =>
            // Heuristic: edge-label mask/background rects are small; this
            // excludes the full-canvas background rect.
            if w <= 240.0 && h <= 90.0 {
              out.push({ x, y, width: w, height: h })
            }
          _ => ()
        }
      }
      out
    }
    Err(_) => []
  }
  let reader = @xml.Reader::from_string(svg)
  let mut in_text = false
  let mut current_text_el : @xml.XmlElement? = None
  let mut buffer = ""
  let out : Array[(String, (Double, Double))] = []
  let restrict = has_substring(svg, "<g id=\"base-layer\"")
  let mut in_base = false
  let mut base_depth = 0
  while true {
    let ev = Some(reader.read_event()) catch { e => return Err(e.to_string()) }
    match ev.unwrap() {
      Start(el) => {
        if restrict &&
          !in_base &&
          el.name == "g" &&
          get_attr(el, "id") == Some("base-layer") {
          in_base = true
          base_depth = 1
        } else if restrict && in_base {
          base_depth = base_depth + 1
        }
        if (!restrict || in_base) && el.name == "text" {
          in_text = true
          current_text_el = Some(el)
          buffer = ""
        }
      }
      Empty(_) => ()
      Text(t) | CData(t) => if in_text { buffer = buffer + t }
      End(name) =>
        if name == "text" && in_text {
          in_text = false
          match current_text_el {
            Some(el) => {
              let label = buffer.trim().to_string()
              if label != "" {
                match (get_attr_double(el, "x"), get_attr_double(el, "y")) {
                  (Some(x), Some(y)) =>
                    if !edge_label_masks.any(fn(b) { point_in_box(x, y, b) }) {
                      out.push((label, (x, y)))
                    }
                  _ => ()
                }
              }
            }
            None => ()
          }
          current_text_el = None
        } else if restrict && in_base {
          base_depth = base_depth - 1
          if base_depth <= 0 {
            in_base = false
            base_depth = 0
          }
        }
      Eof => break
      _ => ()
    }
  }
  Ok(out)
}

///|
fn path_bbox_approx(d : String) -> Box? {
  // Minimal parser: follow M/m L/l H/h V/v, treat C/Q end points.
  // Good enough for bbox candidates.
  let mut i = 0
  let mut cur_x = 0.0
  let mut cur_y = 0.0
  let mut min_x = 1.0e18
  let mut min_y = 1.0e18
  let mut max_x = -1.0e18
  let mut max_y = -1.0e18
  fn update(
    min_x : Double,
    min_y : Double,
    max_x : Double,
    max_y : Double,
    x : Double,
    y : Double,
  ) -> (Double, Double, Double, Double) {
    let mut min_x = min_x
    let mut min_y = min_y
    let mut max_x = max_x
    let mut max_y = max_y
    if x < min_x {
      min_x = x
    }
    if y < min_y {
      min_y = y
    }
    if x > max_x {
      max_x = x
    }
    if y > max_y {
      max_y = y
    }
    (min_x, min_y, max_x, max_y)
  }

  let mut cmd : Char? = None
  while i < d.length() {
    i = skip_sep(d, i)
    if i >= d.length() {
      break
    }
    let c = d.code_unit_at(i).to_int().unsafe_to_char()
    if is_cmd(c) {
      cmd = Some(c)
      i = i + 1
    } else if cmd is None {
      return None
    }
    match cmd.unwrap() {
      'M' | 'm' | 'L' | 'l' => {
        let (x_opt, i2) = read_number(d, i)
        let (y_opt, i3) = read_number(d, i2)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 'm' || cmd.unwrap() == 'l'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            let (mnx, mny, mxx, mxy) = update(
              min_x, min_y, max_x, max_y, cur_x, cur_y,
            )
            min_x = mnx
            min_y = mny
            max_x = mxx
            max_y = mxy
            i = i3
            if cmd.unwrap() == 'm' {
              cmd = Some('l')
            }
            if cmd.unwrap() == 'M' {
              cmd = Some('L')
            }
          }
          _ => return None
        }
      }
      'H' | 'h' => {
        let (x_opt, i2) = read_number(d, i)
        match x_opt {
          Some(x) => {
            if cmd.unwrap() == 'h' {
              cur_x = cur_x + x
            } else {
              cur_x = x
            }
            let (mnx, mny, mxx, mxy) = update(
              min_x, min_y, max_x, max_y, cur_x, cur_y,
            )
            min_x = mnx
            min_y = mny
            max_x = mxx
            max_y = mxy
            i = i2
          }
          None => return None
        }
      }
      'V' | 'v' => {
        let (y_opt, i2) = read_number(d, i)
        match y_opt {
          Some(y) => {
            if cmd.unwrap() == 'v' {
              cur_y = cur_y + y
            } else {
              cur_y = y
            }
            let (mnx, mny, mxx, mxy) = update(
              min_x, min_y, max_x, max_y, cur_x, cur_y,
            )
            min_x = mnx
            min_y = mny
            max_x = mxx
            max_y = mxy
            i = i2
          }
          None => return None
        }
      }
      'C' | 'c' => {
        // skip 4 nums (controls), then endpoint
        let (_, i2) = read_number(d, i)
        let (_, i3) = read_number(d, i2)
        let (_, i4) = read_number(d, i3)
        let (_, i5) = read_number(d, i4)
        let (x_opt, i6) = read_number(d, i5)
        let (y_opt, i7) = read_number(d, i6)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 'c'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            let (mnx, mny, mxx, mxy) = update(
              min_x, min_y, max_x, max_y, cur_x, cur_y,
            )
            min_x = mnx
            min_y = mny
            max_x = mxx
            max_y = mxy
            i = i7
          }
          _ => return None
        }
      }
      'S' | 's' => {
        // smooth cubic: skip 2 nums (control), then endpoint
        let (_, i2) = read_number(d, i)
        let (_, i3) = read_number(d, i2)
        let (x_opt, i4) = read_number(d, i3)
        let (y_opt, i5) = read_number(d, i4)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 's'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            let (mnx, mny, mxx, mxy) = update(
              min_x, min_y, max_x, max_y, cur_x, cur_y,
            )
            min_x = mnx
            min_y = mny
            max_x = mxx
            max_y = mxy
            i = i5
          }
          _ => return None
        }
      }
      'Q' | 'q' => {
        let (_, i2) = read_number(d, i)
        let (_, i3) = read_number(d, i2)
        let (x_opt, i4) = read_number(d, i3)
        let (y_opt, i5) = read_number(d, i4)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 'q'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            let (mnx, mny, mxx, mxy) = update(
              min_x, min_y, max_x, max_y, cur_x, cur_y,
            )
            min_x = mnx
            min_y = mny
            max_x = mxx
            max_y = mxy
            i = i5
          }
          _ => return None
        }
      }
      'T' | 't' => {
        // smooth quadratic: endpoint
        let (x_opt, i2) = read_number(d, i)
        let (y_opt, i3) = read_number(d, i2)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 't'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            let (mnx, mny, mxx, mxy) = update(
              min_x, min_y, max_x, max_y, cur_x, cur_y,
            )
            min_x = mnx
            min_y = mny
            max_x = mxx
            max_y = mxy
            i = i3
          }
          _ => return None
        }
      }
      'A' | 'a' => {
        // elliptical arc: skip rx ry rot laf sf, then endpoint x y
        let (_, i2) = read_number(d, i)
        let (_, i3) = read_number(d, i2)
        let (_, i4) = read_number(d, i3)
        let (_, i5) = read_number(d, i4)
        let (_, i6) = read_number(d, i5)
        let (x_opt, i7) = read_number(d, i6)
        let (y_opt, i8) = read_number(d, i7)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 'a'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            let (mnx, mny, mxx, mxy) = update(
              min_x, min_y, max_x, max_y, cur_x, cur_y,
            )
            min_x = mnx
            min_y = mny
            max_x = mxx
            max_y = mxy
            i = i8
          }
          _ => return None
        }
      }
      'Z' | 'z' => ()
      _ => return None
    }
  }
  if max_x < min_x || max_y < min_y {
    None
  } else {
    Some({ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y })
  }
}

///|
fn extract_shape_boxes(svg : String) -> Result[Array[Box], String] {
  let rects = match collect_elements_by_name(svg, "rect") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let polygons = match collect_elements_by_name(svg, "polygon") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let ellipses = match collect_elements_by_name(svg, "ellipse") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let circles = match collect_elements_by_name(svg, "circle") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let paths = match collect_elements_by_name(svg, "path") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out : Array[Box] = []
  for r in rects {
    // Ignore background / mask rects (D2 emits full-canvas rects without stroke).
    match get_attr(r, "stroke") {
      Some(stroke) => if stroke == "none" { continue }
      None => continue
    }
    match
      (
        get_attr_double(r, "x"),
        get_attr_double(r, "y"),
        get_attr_double(r, "width"),
        get_attr_double(r, "height"),
      ) {
      (Some(x), Some(y), Some(w), Some(h)) =>
        match (get_attr(r, "width"), get_attr(r, "height")) {
          (Some("100%"), Some("100%")) => ()
          _ => out.push({ x, y, width: w, height: h })
        }
      _ => ()
    }
  }
  for p in polygons {
    // D2 emits arrowhead marker polygons in `<defs>` with `class="connection"`.
    // These should not count as node "shape boxes".
    let class = get_attr(p, "class").unwrap_or("")
    if contains_substring(class, "connection") {
      continue
    }
    match get_attr(p, "points") {
      Some(points_raw) => {
        let sb = StringBuilder::new()
        for c in points_raw {
          if c == '\n' || c == '\r' || c == '\t' {
            sb.write_char(' ')
          } else {
            sb.write_char(c)
          }
        }
        let points = sb.to_string()
        let mut min_x = 1.0e18
        let mut min_y = 1.0e18
        let mut max_x = -1.0e18
        let mut max_y = -1.0e18
        for token in points.split(" ") {
          let part = token.trim()
          if part.length() == 0 {
            continue
          }
          let coords_iter = part.split(",")
          let coords : Array[String] = []
          for v in coords_iter {
            coords.push(v.to_string())
          }
          if coords.length() != 2 {
            continue
          }
          match (parse_double(coords[0]), parse_double(coords[1])) {
            (Some(x), Some(y)) => {
              if x < min_x {
                min_x = x
              }
              if y < min_y {
                min_y = y
              }
              if x > max_x {
                max_x = x
              }
              if y > max_y {
                max_y = y
              }
            }
            _ => ()
          }
        }
        if max_x >= min_x && max_y >= min_y {
          out.push({
            x: min_x,
            y: min_y,
            width: max_x - min_x,
            height: max_y - min_y,
          })
        }
      }
      None => ()
    }
  }
  for e in ellipses {
    // Some renderers emit invisible helper ellipses (e.g. for cylinder tops)
    // with both fill and stroke set to "none". These should not participate in
    // semantic "shape box" matching.
    let mut visible = false
    match get_attr(e, "fill") {
      Some(fill) => if fill != "none" { visible = true }
      None => ()
    }
    match get_attr(e, "stroke") {
      Some(stroke) => if stroke != "none" { visible = true }
      None => ()
    }
    if !visible {
      continue
    }
    match
      (
        get_attr_double(e, "cx"),
        get_attr_double(e, "cy"),
        get_attr_double(e, "rx"),
        get_attr_double(e, "ry"),
      ) {
      (Some(cx), Some(cy), Some(rx), Some(ry)) =>
        out.push({ x: cx - rx, y: cy - ry, width: 2.0 * rx, height: 2.0 * ry })
      _ => ()
    }
  }
  for c in circles {
    let mut visible = false
    match get_attr(c, "fill") {
      Some(fill) => if fill != "none" { visible = true }
      None => ()
    }
    match get_attr(c, "stroke") {
      Some(stroke) => if stroke != "none" { visible = true }
      None => ()
    }
    if !visible {
      continue
    }
    match
      (
        get_attr_double(c, "cx"),
        get_attr_double(c, "cy"),
        get_attr_double(c, "r"),
      ) {
      (Some(cx), Some(cy), Some(r)) =>
        out.push({ x: cx - r, y: cy - r, width: 2.0 * r, height: 2.0 * r })
      _ => ()
    }
  }
  for p in paths {
    match get_attr(p, "fill") {
      Some(fill) =>
        if fill != "none" {
          match get_attr(p, "d") {
            Some(d) =>
              match path_bbox_approx(d) {
                Some(b) => out.push(b)
                None => ()
              }
            None => ()
          }
        }
      None => ()
    }
  }
  Ok(out)
}

///|
fn point_in_box(x : Double, y : Double, b : Box) -> Bool {
  x >= b.x && x <= b.x + b.width && y >= b.y && y <= b.y + b.height
}

///|
fn point_box_distance_sq(x : Double, y : Double, b : Box) -> Double {
  let left = b.x
  let right = b.x + b.width
  let top = b.y
  let bottom = b.y + b.height
  let dx = if x < left { left - x } else if x > right { x - right } else { 0.0 }
  let dy = if y < top { top - y } else if y > bottom { y - bottom } else { 0.0 }
  dx * dx + dy * dy
}

///|
fn map_labels_to_boxes(svg : String) -> Result[Map[String, Box], String] {
  let positions = match extract_text_positions(svg) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let boxes = match extract_shape_boxes(svg) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  // Sort label positions top-to-bottom then left-to-right so duplicate labels
  // get stable suffixes across renderers.
  let positions = positions
  for i = 1; i < positions.length(); i = i + 1 {
    let mut j = i
    while j > 0 {
      let (la, (xa, ya)) = positions[j - 1]
      let (lb, (xb, yb)) = positions[j]
      let swap = if ya < yb {
        false
      } else if ya > yb {
        true
      } else if xa < xb {
        false
      } else if xa > xb {
        true
      } else {
        la > lb
      }
      if !swap {
        break
      }
      let tmp = positions[j - 1]
      positions[j - 1] = positions[j]
      positions[j] = tmp
      j = j - 1
    }
  }
  let total_counts : Map[String, Int] = {}
  for pair in positions.iter() {
    let (label, _) = pair
    total_counts[label] = total_counts.get(label).unwrap_or(0) + 1
  }
  let seen : Map[String, Int] = {}
  let out : Map[String, Box] = {}
  for pair in positions.iter() {
    let (label, (tx, ty)) = pair
    let key = if total_counts.get(label).unwrap_or(0) > 1 {
      let idx = seen.get(label).unwrap_or(0)
      seen[label] = idx + 1
      label + "#" + idx.to_string()
    } else {
      label
    }
    let mut best : Box? = None
    let mut best_area = 1.0e30
    let mut found_inside = false
    for b in boxes {
      if point_in_box(tx, ty, b) {
        let area = b.width * b.height
        if area < best_area {
          best = Some(b)
          best_area = area
        }
        found_inside = true
      }
    }
    if !found_inside {
      let mut best_dist = 1.0e30
      let mut best_area = 1.0e30
      for b in boxes {
        let dist = point_box_distance_sq(tx, ty, b)
        let area = b.width * b.height
        if dist < best_dist || (dist == best_dist && area < best_area) {
          best = Some(b)
          best_dist = dist
          best_area = area
        }
      }
    }
    match best {
      Some(b) => out[key] = b
      None => ()
    }
  }
  Ok(out)
}

///|
fn normalize_boxes(
  raw : Map[String, Box],
) -> (Map[String, Box], Double, Double) {
  let anchor = "Web Application Architecture"
  let mut dx = 0.0
  let mut dy = 0.0
  match raw.get(anchor) {
    Some(b) => {
      dx = -b.x
      dy = -b.y
    }
    None => {
      let mut min_x = 0.0
      let mut min_y = 0.0
      let mut first = true
      for pair in raw.iter() {
        let (_, b) = pair
        if first {
          min_x = b.x
          min_y = b.y
          first = false
        } else {
          min_x = @cmp.minimum(min_x, b.x)
          min_y = @cmp.minimum(min_y, b.y)
        }
      }
      dx = -min_x
      dy = -min_y
    }
  }
  let out : Map[String, Box] = {}
  for pair in raw.iter() {
    let (k, b) = pair
    out[k.to_string()] = {
      x: b.x + dx,
      y: b.y + dy,
      width: b.width,
      height: b.height,
    }
  }
  (out, dx, dy)
}

///|
fn simplify_route_points(
  points : Array[(Double, Double)],
) -> Array[(Double, Double)] {
  let eps = 1.0e-6
  if points.length() <= 2 {
    return points
  }
  let dedup : Array[(Double, Double)] = []
  for p in points {
    if dedup.is_empty() {
      dedup.push(p)
    } else {
      let last = dedup[dedup.length() - 1]
      if !(approx_eq(last.0, p.0, eps) && approx_eq(last.1, p.1, eps)) {
        dedup.push(p)
      }
    }
  }
  if dedup.length() <= 2 {
    return dedup
  }
  // Remove collinear middle points (mostly orthogonal routing).
  let out : Array[(Double, Double)] = []
  out.push(dedup[0])
  for i = 1; i + 1 < dedup.length(); i = i + 1 {
    let (x0, y0) = out[out.length() - 1]
    let (x1, y1) = dedup[i]
    let (x2, y2) = dedup[i + 1]
    let collinear_x = approx_eq(x0, x1, eps) && approx_eq(x1, x2, eps)
    let collinear_y = approx_eq(y0, y1, eps) && approx_eq(y1, y2, eps)
    if collinear_x || collinear_y {
      continue
    }
    out.push((x1, y1))
  }
  out.push(dedup[dedup.length() - 1])
  out
}

///|
fn path_points(d : String) -> Array[(Double, Double)]? {
  // Extract a polyline-like representation from an SVG path. We record segment
  // endpoints for all commands.
  let mut i = 0
  let mut cur_x = 0.0
  let mut cur_y = 0.0
  let mut cmd : Char? = None
  let points : Array[(Double, Double)] = []
  while i < d.length() {
    i = skip_sep(d, i)
    if i >= d.length() {
      break
    }
    let c = d.code_unit_at(i).to_int().unsafe_to_char()
    if is_cmd(c) {
      cmd = Some(c)
      i = i + 1
    } else if cmd is None {
      return None
    }
    match cmd.unwrap() {
      'M' | 'm' | 'L' | 'l' => {
        let (x_opt, i2) = read_number(d, i)
        let (y_opt, i3) = read_number(d, i2)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 'm' || cmd.unwrap() == 'l'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            points.push((cur_x, cur_y))
            i = i3
            if cmd.unwrap() == 'm' {
              cmd = Some('l')
            }
            if cmd.unwrap() == 'M' {
              cmd = Some('L')
            }
          }
          _ => return None
        }
      }
      'H' | 'h' => {
        let (x_opt, i2) = read_number(d, i)
        match x_opt {
          Some(x) => {
            if cmd.unwrap() == 'h' {
              cur_x = cur_x + x
            } else {
              cur_x = x
            }
            points.push((cur_x, cur_y))
            i = i2
          }
          None => return None
        }
      }
      'V' | 'v' => {
        let (y_opt, i2) = read_number(d, i)
        match y_opt {
          Some(y) => {
            if cmd.unwrap() == 'v' {
              cur_y = cur_y + y
            } else {
              cur_y = y
            }
            points.push((cur_x, cur_y))
            i = i2
          }
          None => return None
        }
      }
      'C' | 'c' => {
        // skip 4 nums (controls), then endpoint
        let (_, i2) = read_number(d, i)
        let (_, i3) = read_number(d, i2)
        let (_, i4) = read_number(d, i3)
        let (_, i5) = read_number(d, i4)
        let (x_opt, i6) = read_number(d, i5)
        let (y_opt, i7) = read_number(d, i6)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 'c'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            points.push((cur_x, cur_y))
            i = i7
          }
          _ => return None
        }
      }
      'S' | 's' => {
        let (_, i2) = read_number(d, i)
        let (_, i3) = read_number(d, i2)
        let (x_opt, i4) = read_number(d, i3)
        let (y_opt, i5) = read_number(d, i4)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 's'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            points.push((cur_x, cur_y))
            i = i5
          }
          _ => return None
        }
      }
      'Q' | 'q' => {
        let (_, i2) = read_number(d, i)
        let (_, i3) = read_number(d, i2)
        let (x_opt, i4) = read_number(d, i3)
        let (y_opt, i5) = read_number(d, i4)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 'q'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            points.push((cur_x, cur_y))
            i = i5
          }
          _ => return None
        }
      }
      'T' | 't' => {
        let (x_opt, i2) = read_number(d, i)
        let (y_opt, i3) = read_number(d, i2)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 't'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            points.push((cur_x, cur_y))
            i = i3
          }
          _ => return None
        }
      }
      'A' | 'a' => {
        // elliptical arc: skip rx ry rot laf sf, then endpoint x y
        let (_, i2) = read_number(d, i)
        let (_, i3) = read_number(d, i2)
        let (_, i4) = read_number(d, i3)
        let (_, i5) = read_number(d, i4)
        let (_, i6) = read_number(d, i5)
        let (x_opt, i7) = read_number(d, i6)
        let (y_opt, i8) = read_number(d, i7)
        match (x_opt, y_opt) {
          (Some(x), Some(y)) => {
            let rel = cmd.unwrap() == 'a'
            if rel {
              cur_x = cur_x + x
              cur_y = cur_y + y
            } else {
              cur_x = x
              cur_y = y
            }
            points.push((cur_x, cur_y))
            i = i8
          }
          _ => return None
        }
      }
      'Z' | 'z' => ()
      _ => return None
    }
  }
  Some(points)
}

///|
fn extract_routes(svg : String) -> Result[Array[Route], String] {
  let paths = match collect_elements_by_name(svg, "path") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let lines = match collect_elements_by_name(svg, "line") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out : Array[Route] = []
  for p in paths {
    let class = get_attr(p, "class").unwrap_or("")
    let marker_start = get_attr(p, "marker-start").unwrap_or("")
    let marker_end = get_attr(p, "marker-end").unwrap_or("")
    let is_conn = contains_substring(class, "connection") ||
      marker_start != "" ||
      marker_end != ""
    if !is_conn {
      continue
    }
    match get_attr(p, "fill") {
      Some(fill) => if fill != "none" { continue }
      None => ()
    }
    let d = match get_attr(p, "d") {
      Some(v) => v
      None => continue
    }
    match path_points(d) {
      Some(raw_points) => {
        let pts = simplify_route_points(raw_points)
        if pts.length() >= 2 {
          out.push({
            points: pts,
            has_marker_start: marker_start != "",
            has_marker_end: marker_end != "",
          })
        }
      }
      None => ()
    }
  }
  for l in lines {
    let class = get_attr(l, "class").unwrap_or("")
    let marker_start = get_attr(l, "marker-start").unwrap_or("")
    let marker_end = get_attr(l, "marker-end").unwrap_or("")
    let is_conn = contains_substring(class, "connection") ||
      marker_start != "" ||
      marker_end != ""
    if !is_conn {
      continue
    }
    match
      (
        get_attr_double(l, "x1"),
        get_attr_double(l, "y1"),
        get_attr_double(l, "x2"),
        get_attr_double(l, "y2"),
      ) {
      (Some(x1), Some(y1), Some(x2), Some(y2)) =>
        out.push({
          points: simplify_route_points([(x1, y1), (x2, y2)]),
          has_marker_start: marker_start != "",
          has_marker_end: marker_end != "",
        })
      _ => ()
    }
  }
  Ok(out)
}

///|
fn label_for_point(
  label_boxes : Map[String, Box],
  x : Double,
  y : Double,
) -> String? {
  // Some renderers clip / mask connections at container boundaries, so route
  // endpoints may fall on a parent box border instead of inside the actual
  // source/target node. Use a distance-to-box metric with a small area penalty
  // to prefer more specific (smaller) boxes when reasonably close.
  let area_weight = 1.0e-4
  let mut best_k : String? = None
  let mut best_score = 1.0e30
  for pair in label_boxes.iter() {
    let (k_view, b) = pair
    let dist = point_box_distance_sq(x, y, b)
    let area = b.width * b.height
    let score = dist + area * area_weight
    if score < best_score {
      best_k = Some(k_view.to_string())
      best_score = score
    }
  }
  best_k
}

///|
fn route_direction_signature(points : Array[(Double, Double)]) -> String {
  // Extract a direction-only signature (H/V) for the routed polyline,
  // ignoring tiny offsets and rounded-corner diagonal segments.
  let sb = StringBuilder::new()
  let mut last : Char? = None
  for i = 0; i + 1 < points.length(); i = i + 1 {
    let dx = points[i + 1].0 - points[i].0
    let dy = points[i + 1].1 - points[i].1
    let adx = abs(dx)
    let ady = abs(dy)
    // Treat slightly slanted segments as axis-aligned if one axis dominates.
    let dir : Char? = if adx <= 1.0 && ady > 1.0 {
      Some('V')
    } else if ady <= 1.0 && adx > 1.0 {
      Some('H')
    } else if ady > adx * 5.0 {
      Some('V')
    } else if adx > ady * 5.0 {
      Some('H')
    } else {
      None
    }
    match dir {
      Some(d) =>
        match last {
          Some(prev) => if prev != d { sb.write_char(d) }
          None => sb.write_char(d)
        }
      None => ()
    }
    match dir {
      Some(_) => last = dir
      None => ()
    }
  }
  sb.to_string()
}

///|
fn nudge_towards(
  from : (Double, Double),
  to : (Double, Double),
  step : Double,
) -> (Double, Double) {
  let dx = to.0 - from.0
  let dy = to.1 - from.1
  // Routes are mostly orthogonal; move along the dominant axis.
  if abs(dx) >= abs(dy) {
    let s = if dx < 0.0 { -1.0 } else if dx > 0.0 { 1.0 } else { 0.0 }
    (from.0 + s * step, from.1)
  } else {
    let s = if dy < 0.0 { -1.0 } else if dy > 0.0 { 1.0 } else { 0.0 }
    (from.0, from.1 + s * step)
  }
}

///|
fn route_endpoint_sample(
  points : Array[(Double, Double)],
  at_start : Bool,
) -> (Double, Double) {
  let step = 6.0
  if points.length() < 2 {
    return points[0]
  }
  if at_start {
    nudge_towards(points[0], points[1], step)
  } else {
    let n = points.length()
    nudge_towards(points[n - 1], points[n - 2], step)
  }
}

///|
fn route_signature(route : Route, label_boxes : Map[String, Box]) -> String {
  // Endpoints may lie on a clipped/masked border; sample slightly inward.
  let start = route_endpoint_sample(route.points, true)
  let end = route_endpoint_sample(route.points, false)
  let src = label_for_point(label_boxes, start.0, start.1).unwrap_or(
    "(unknown)",
  )
  let dst = label_for_point(label_boxes, end.0, end.1).unwrap_or("(unknown)")
  let dir = route_direction_signature(route.points)
  let ms = if route.has_marker_start { "1" } else { "0" }
  let me = if route.has_marker_end { "1" } else { "0" }
  src + "->" + dst + "|" + dir + "|" + ms + "|" + me
}

///|
fn route_points_key(points : Array[(Double, Double)]) -> String {
  // Compare point-by-point (after normalization) rather than only direction
  // changes. This makes ELK parity diffs actionable.
  let scale = 1000.0
  let sb = StringBuilder::new()
  for i = 0; i < points.length(); i = i + 1 {
    if i > 0 {
      sb.write_char(';')
    }
    let x = quantize_coord(points[i].0, scale).to_string()
    let y = quantize_coord(points[i].1, scale).to_string()
    sb.write_string(x)
    sb.write_char(',')
    sb.write_string(y)
  }
  sb.to_string()
}

///|
fn compare_routes(
  name : String,
  got_svg : String,
  expected_svg : String,
) -> Result[Unit, String] {
  let got_routes = match extract_routes(got_svg) {
    Ok(v) => v
    Err(e) => return Err(name + ": got svg: " + e)
  }
  let exp_routes = match extract_routes(expected_svg) {
    Ok(v) => v
    Err(e) => return Err(name + ": expected svg: " + e)
  }

  // Normalize coordinates by the same anchor/min-box logic as `compare_boxes`,
  // then compare full routed point sequences.
  let got_raw_labels = match map_labels_to_boxes(got_svg) {
    Ok(v) => v
    Err(_) => {}
  }
  let exp_raw_labels = match map_labels_to_boxes(expected_svg) {
    Ok(v) => v
    Err(_) => {}
  }
  let (got_labels, got_dx, got_dy) = normalize_boxes(got_raw_labels)
  let (exp_labels, exp_dx, exp_dy) = normalize_boxes(exp_raw_labels)
  let got_counts : Map[String, Int] = {}
  for r in got_routes {
    let shifted : Array[(Double, Double)] = []
    for p in r.points {
      shifted.push((p.0 + got_dx, p.1 + got_dy))
    }
    let rr = {
      points: shifted,
      has_marker_start: r.has_marker_start,
      has_marker_end: r.has_marker_end,
    }
    let sig = route_signature(rr, got_labels)
    let key = sig + "|" + route_points_key(rr.points)
    got_counts[key] = got_counts.get(key).unwrap_or(0) + 1
  }
  let exp_counts : Map[String, Int] = {}
  for r in exp_routes {
    let shifted : Array[(Double, Double)] = []
    for p in r.points {
      shifted.push((p.0 + exp_dx, p.1 + exp_dy))
    }
    let rr = {
      points: shifted,
      has_marker_start: r.has_marker_start,
      has_marker_end: r.has_marker_end,
    }
    let sig = route_signature(rr, exp_labels)
    let key = sig + "|" + route_points_key(rr.points)
    exp_counts[key] = exp_counts.get(key).unwrap_or(0) + 1
  }
  let mismatches : Array[String] = []
  for pair in exp_counts.iter() {
    let (k_view, exp_n) = pair
    let k = k_view.to_string()
    let got_n = got_counts.get(k).unwrap_or(0)
    if got_n != exp_n {
      mismatches.push(
        "count '" +
        k +
        "' got=" +
        got_n.to_string() +
        " expected=" +
        exp_n.to_string(),
      )
    }
  }
  for pair in got_counts.iter() {
    let (k_view, got_n) = pair
    let k = k_view.to_string()
    if exp_counts.get(k) is None {
      mismatches.push(
        "extra '" + k + "' got=" + got_n.to_string() + " expected=0",
      )
    }
  }
  if !mismatches.is_empty() {
    mismatches.sort()
    let limit = mismatches.length()
    let buf = StringBuilder::new()
    buf.write_string(
      name +
      ": connection route mismatches (" +
      mismatches.length().to_string() +
      ")\n",
    )
    buf.write_string(
      "debug normalize: got_dx=" +
      got_dx.to_string() +
      " got_dy=" +
      got_dy.to_string() +
      " exp_dx=" +
      exp_dx.to_string() +
      " exp_dy=" +
      exp_dy.to_string() +
      "\n",
    )
    for i = 0; i < limit; i = i + 1 {
      buf.write_string(mismatches[i] + "\n")
    }
    return Err(buf.to_string())
  }
  Ok(())
}

///|
fn compare_boxes(
  name : String,
  got_svg : String,
  expected_svg : String,
) -> Result[Unit, String] {
  let got_raw = match map_labels_to_boxes(got_svg) {
    Ok(v) => v
    Err(e) => return Err(name + ": got svg: " + e)
  }
  let exp_raw = match map_labels_to_boxes(expected_svg) {
    Ok(v) => v
    Err(e) => return Err(name + ": expected svg: " + e)
  }
  let anchor = "Web Application Architecture"
  let mut got_dx = 0.0
  let mut got_dy = 0.0
  match got_raw.get(anchor) {
    Some(b) => {
      got_dx = -b.x
      got_dy = -b.y
    }
    None => {
      // Fall back to normalizing by the overall bounding box when the anchor
      // label is not present in this example.
      let mut min_x = 0.0
      let mut min_y = 0.0
      let mut first = true
      for pair in got_raw.iter() {
        let (_, b) = pair
        if first {
          min_x = b.x
          min_y = b.y
          first = false
        } else {
          min_x = @cmp.minimum(min_x, b.x)
          min_y = @cmp.minimum(min_y, b.y)
        }
      }
      got_dx = -min_x
      got_dy = -min_y
    }
  }
  let mut exp_dx = 0.0
  let mut exp_dy = 0.0
  match exp_raw.get(anchor) {
    Some(b) => {
      exp_dx = -b.x
      exp_dy = -b.y
    }
    None => {
      let mut min_x = 0.0
      let mut min_y = 0.0
      let mut first = true
      for pair in exp_raw.iter() {
        let (_, b) = pair
        if first {
          min_x = b.x
          min_y = b.y
          first = false
        } else {
          min_x = @cmp.minimum(min_x, b.x)
          min_y = @cmp.minimum(min_y, b.y)
        }
      }
      exp_dx = -min_x
      exp_dy = -min_y
    }
  }
  let got : Map[String, Box] = {}
  for pair in got_raw.iter() {
    let (k, b) = pair
    got[k.to_string()] = {
      x: b.x + got_dx,
      y: b.y + got_dy,
      width: b.width,
      height: b.height,
    }
  }
  let exp : Map[String, Box] = {}
  for pair in exp_raw.iter() {
    let (k, b) = pair
    exp[k.to_string()] = {
      x: b.x + exp_dx,
      y: b.y + exp_dy,
      width: b.width,
      height: b.height,
    }
  }
  // D2 parity goal: treat any geometry drift as a failure. Keep a tiny epsilon
  // to tolerate float rounding artifacts.
  let tol_pos = 0.51
  let tol_size = 0.51
  let mismatches : Array[String] = []
  for pair in exp.iter() {
    let (label_view, eb) = pair
    let label = label_view.to_string()
    match got.get(label) {
      Some(gb) => {
        let dx = abs(gb.x - eb.x)
        let dy = abs(gb.y - eb.y)
        let dw = abs(gb.width - eb.width)
        let dh = abs(gb.height - eb.height)
        if dx > tol_pos || dy > tol_pos || dw > tol_size || dh > tol_size {
          mismatches.push(
            "'" +
            label +
            "' got=" +
            gb.to_string() +
            " expected=" +
            eb.to_string() +
            " (dx=" +
            dx.to_string() +
            ", dy=" +
            dy.to_string() +
            ", dw=" +
            dw.to_string() +
            ", dh=" +
            dh.to_string() +
            ")",
          )
        }
      }
      None => ()
    }
  }
  if !mismatches.is_empty() {
    // Debug helper: dump SVGs for the first failing case to inspect layout drift.
    // Keep this lightweight and only trigger on failures.
    @fs.write_string_to_file("/tmp/diago-e2e-" + name + "-got.svg", got_svg) catch {
      _ => ()
    }
    @fs.write_string_to_file(
      "/tmp/diago-e2e-" + name + "-expected.svg",
      expected_svg,
    ) catch {
      _ => ()
    }
    mismatches.sort()
    let limit = mismatches.length()
    let buf = StringBuilder::new()
    buf.write_string(
      name + ": box mismatches (" + mismatches.length().to_string() + ")\n",
    )
    if name == "basic" || name == "arrowheads" || name == "architecture" {
      let keys = if name == "architecture" {
        [
          "Web Application Architecture", "Users", "CDN", "Load Balancer", "Web Tier",
          "Application Tier", "Redis Cache", "Message Queue", "Background Workers",
          "Database Cluster", "Object Storage",
        ]
      } else {
        [
          "Web Server", "PostgreSQL", "queries", "HTTP", "a", "b", "c", "d", "user",
          "orders",
        ]
      }
      for key in keys {
        match (got.get(key), exp.get(key)) {
          (Some(gb), Some(eb)) =>
            buf.write_string(
              "debug '" +
              key +
              "': got=" +
              gb.to_string() +
              " expected=" +
              eb.to_string() +
              "\n",
            )
          _ => ()
        }
      }
    }
    for i = 0; i < limit; i = i + 1 {
      buf.write_string(mismatches[i] + "\n")
    }
    return Err(buf.to_string())
  }
  Ok(())
}

///|
test "examples: svg matches D2 reference (semantic)" {
  let names : Array[String] = [
    "architecture", "arrowheads", "basic", "c4", "classes", "containers", "directions",
    "grid", "hello", "layers", "legend_auto", "legend_custom", "sequence", "shapes",
    "sql_tables", "styles", "variables",
  ]
  for name in names {
    let input_path = "examples/" + name + ".d2"
    let expected_path = "examples/reference/" + name + ".svg"
    let source = read_file(input_path).unwrap()
    let got_svg = normalize_newlines(compile(source).unwrap())
    // Persist the generated SVGs for manual inspection and diffing.
    write_file("examples/diago-output/" + name + ".svg", got_svg)
    let expected_svg = normalize_newlines(read_file(expected_path).unwrap())
    match compare_boxes(name, got_svg, expected_svg) {
      Ok(_) => ()
      Err(msg) => {
        write_file("examples/diago-output/" + name + ".boxes.diff", msg)
        fail(msg)
      }
    }
    match compare_routes(name, got_svg, expected_svg) {
      Ok(_) => ()
      Err(msg) => {
        write_file("examples/diago-output/" + name + ".routes.diff", msg)
        fail(msg)
      }
    }
  }
}
