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
/// compare the rendered output against checked-in D2 CLI golden SVGs.
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
fn read_file(path : String) -> Result[String, String] {
  let content = Some(@fs.read_file_to_string(path)) catch { _ => None }
  match content {
    Some(s) => Ok(s)
    None => Err("failed to read file '" + path + "'")
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
fn parse_double(s : String) -> Double? {
  Some(@strconv.parse_double(s)) catch {
    _ => None
  }
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
  while true {
    let ev = Some(reader.read_event()) catch { e => return Err(e.to_string()) }
    match ev.unwrap() {
      Start(el) | Empty(el) => if el.name == name { out.push(el) }
      Eof => break
      _ => ()
    }
  }
  Ok(out)
}

///|
fn extract_text_positions(
  svg : String,
) -> Result[Map[String, (Double, Double)], String] {
  let reader = @xml.Reader::from_string(svg)
  let mut in_text = false
  let mut current_text_el : @xml.XmlElement? = None
  let mut buffer = ""
  let out : Map[String, (Double, Double)] = {}
  while true {
    let ev = Some(reader.read_event()) catch { e => return Err(e.to_string()) }
    match ev.unwrap() {
      Start(el) =>
        if el.name == "text" {
          in_text = true
          current_text_el = Some(el)
          buffer = ""
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
                  (Some(x), Some(y)) => out[label] = (x, y)
                  _ => ()
                }
              }
            }
            None => ()
          }
          current_text_el = None
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

  fn is_cmd(c : Char) -> Bool {
    let n = c.to_int()
    (n >= 'A'.to_int() && n <= 'Z'.to_int()) ||
    (n >= 'a'.to_int() && n <= 'z'.to_int())
  }

  fn is_num_char(c : Char) -> Bool {
    let i = c.to_int()
    (i >= '0'.to_int() && i <= '9'.to_int()) || c == '.' || c == '-' || c == '+'
  }

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
  let out : Map[String, Box] = {}
  for pair in positions.iter() {
    let (label_view, (tx, ty)) = pair
    let label = label_view.to_string()
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
      Some(b) => out[label] = b
      None => ()
    }
  }
  Ok(out)
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
    None => ()
  }
  let mut exp_dx = 0.0
  let mut exp_dy = 0.0
  match exp_raw.get(anchor) {
    Some(b) => {
      exp_dx = -b.x
      exp_dy = -b.y
    }
    None => ()
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
  let tol_pos = 50.0
  let tol_size = 20.0
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
          return Err(
            name +
            ": box mismatch for '" +
            label +
            "' got=" +
            gb.to_string() +
            " expected=" +
            eb.to_string(),
          )
        }
      }
      None => ()
    }
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
    let expected_svg = normalize_newlines(read_file(expected_path).unwrap())
    match compare_boxes(name, got_svg, expected_svg) {
      Ok(_) => ()
      Err(msg) => fail(msg)
    }
  }
}
