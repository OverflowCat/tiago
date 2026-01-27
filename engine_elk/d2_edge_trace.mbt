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
/// D2 post-processing for ELK routes.
///
/// Ported from:
/// - ../d2/d2graph/layout.go (Edge.TraceToShape, findOuterIntersection)
/// - ../d2/d2layouts/d2elklayout/layout.go (deleteBends + collision heuristics)
/// - ../d2/lib/{geo,svg,shape} (TraceToShapeBorder + minimal geometry support)
///
/// This is intentionally "copy, don't invent": when something looks odd
/// (e.g. loop bounds), it's likely reflecting upstream quirks.

///|
const D2_LABEL_PADDING : Double = 5.0

///|
const D2_MIN_SEGMENT_LEN : Double = 10.0

///|
const D2_BEZIER_PRECISION : Double = 0.0001

///|
const D2_EDGE_NODE_SPACING : Double = 40.0

///|
fn d2_truncate_float32(v : Double) -> Double {
  // Match `float64(float32(v))` from Go.
  let f : Float = Float::from_double(v)
  f.to_double()
}

///|
fn d2_chop_precision(v : Double) -> Double {
  // Ported from d2/lib/svg/path.go:chopPrecision.
  // Note: yes, this rounds to an integer after float32 precision reduction.
  let reduced = d2_truncate_float32(v * 10000.0)
  let result = (reduced / 10000.0).round()
  if result == 0.0 { 0.0 } else { result }
}

///|
fn d2_euclidean_distance(x1 : Double, y1 : Double, x2 : Double, y2 : Double) -> Double {
  // Ported from d2/lib/geo/math.go:EuclideanDistance.
  if x1 == x2 {
    (y1 - y2).abs()
  } else if y1 == y2 {
    (x1 - x2).abs()
  } else {
    ((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)).sqrt()
  }
}

///|
fn d2_precision_compare(a : Double, b : Double, e : Double) -> Int {
  // Ported from d2/lib/geo/math.go:PrecisionCompare.
  if (a - b).abs() < e {
    0
  } else if a < b {
    -1
  } else {
    1
  }
}

///|
fn d2_min_double(a : Double, b : Double) -> Double {
  if a < b { a } else { b }
}

///|
fn d2_intersection_point(u0 : Point, u1 : Point, v0 : Point, v1 : Point) -> Point? {
  // Ported from d2/lib/geo/point.go:IntersectionPoint.
  let udx = u1.x - u0.x
  let vdx = v1.x - v0.x
  let uvdx = v0.x - u0.x
  let udy = u1.y - u0.y
  let vdy = v1.y - v0.y
  let uvdy = v0.y - u0.y
  let denom = (udy * vdx - udx * vdy)
  if denom == 0.0 {
    return None
  }
  let s = (vdx * uvdy - vdy * uvdx) / denom
  let t = (udx * uvdy - udy * uvdx) / denom
  if s < 0.0 || s > 1.0 || t < 0.0 || t > 1.0 {
    return None
  }
  let ix = u0.x + (s * udx).round()
  let iy = u0.y + (s * udy).round()
  Some(Point::new(ix, iy))
}

///|
priv struct D2Segment {
  start : Point
  end : Point
}

///|
fn D2Segment::new(start : Point, end : Point) -> D2Segment {
  { start, end }
}

///|
fn D2Segment::length(self : D2Segment) -> Double {
  d2_euclidean_distance(self.start.x, self.start.y, self.end.x, self.end.y)
}

///|
fn d2_segment_intersections(a : D2Segment, b : D2Segment) -> Array[Point] {
  match d2_intersection_point(a.start, a.end, b.start, b.end) {
    Some(p) => [p]
    None => []
  }
}

///|
fn d2_segment_overlaps(
  seg : D2Segment,
  other : D2Segment,
  is_horizontal : Bool,
  buffer : Double,
) -> Bool {
  // Ported from d2/lib/geo/segment.go:Segment.Overlaps.
  if is_horizontal {
    if d2_min_double(seg.start.y, seg.end.y) - max_double(other.start.y, other.end.y) >= buffer {
      return false
    }
    if d2_min_double(other.start.y, other.end.y) - max_double(seg.start.y, seg.end.y) >= buffer {
      return false
    }
    true
  } else {
    if d2_min_double(seg.start.x, seg.end.x) - max_double(other.start.x, other.end.x) >= buffer {
      return false
    }
    if d2_min_double(other.start.x, other.end.x) - max_double(seg.start.x, seg.end.x) >= buffer {
      return false
    }
    true
  }
}

///|
fn d2_box_contains(box : Box, p : Point) -> Bool {
  // Ported from d2/lib/geo/box.go:Box.Contains.
  not(
    p.x < box.x || box.x + box.width < p.x || p.y < box.y || box.y + box.height < p.y,
  )
}

///|
fn d2_box_intersections(box : Box, seg : D2Segment) -> Array[Point] {
  // Ported from d2/lib/geo/box.go:Box.Intersections.
  let tl = Point::new(box.x, box.y)
  let tr = Point::new(box.x + box.width, box.y)
  let br = Point::new(box.x + box.width, box.y + box.height)
  let bl = Point::new(box.x, box.y + box.height)
  let out : Array[Point] = []
  match d2_intersection_point(seg.start, seg.end, tl, tr) {
    Some(p) => out.push(p)
    None => ()
  }
  match d2_intersection_point(seg.start, seg.end, tr, br) {
    Some(p) => out.push(p)
    None => ()
  }
  match d2_intersection_point(seg.start, seg.end, br, bl) {
    Some(p) => out.push(p)
    None => ()
  }
  match d2_intersection_point(seg.start, seg.end, bl, tl) {
    Some(p) => out.push(p)
    None => ()
  }
  out
}

///|
fn d2_box_intersects_with_buffer(box : Box, seg : D2Segment, buffer : Double) -> Bool {
  // Ported from d2/lib/geo/box.go:Box.Intersects.
  let tl = Point::new(box.x - buffer, box.y - buffer)
  let tr = Point::new(box.x + box.width + buffer, box.y - buffer)
  let br = Point::new(box.x + box.width + buffer, box.y + box.height + buffer)
  let bl = Point::new(box.x - buffer, box.y + box.height + buffer)
  d2_intersection_point(seg.start, seg.end, tl, tr) is Some(_) ||
  d2_intersection_point(seg.start, seg.end, tr, br) is Some(_) ||
  d2_intersection_point(seg.start, seg.end, br, bl) is Some(_) ||
  d2_intersection_point(seg.start, seg.end, bl, tl) is Some(_)
}

///|
fn d2_distance_to_line(p : Point, p1 : Point, p2 : Point) -> Double {
  // Ported from d2/lib/geo/point.go:Point.DistanceToLine.
  let a = p.x - p1.x
  let b = p.y - p1.y
  let c = p2.x - p1.x
  let d = p2.y - p1.y
  let dot = (a * c) + (b * d)
  let len_sq = (c * c) + (d * d)
  let mut param = -1.0
  if len_sq != 0.0 {
    param = dot / len_sq
  }
  let (xx, yy) = if param < 0.0 {
    (p1.x, p1.y)
  } else if param > 1.0 {
    (p2.x, p2.y)
  } else {
    (p1.x + (param * c), p1.y + (param * d))
  }
  let dx = p.x - xx
  let dy = p.y - yy
  (dx * dx + dy * dy).sqrt()
}

///|
priv struct D2Ellipse {
  center : Point
  rx : Double
  ry : Double
}

///|
fn d2_ellipse_intersections(e : D2Ellipse, seg : D2Segment) -> Array[Point] {
  // Ported from d2/lib/geo/ellipse.go:Ellipse.Intersections.
  let a = e.rx
  let b = e.ry
  let a2 = a * a
  let b2 = b * b
  if a <= 0.0 || b <= 0.0 {
    return []
  }
  let x1 = seg.start.x - e.center.x
  let y1 = seg.start.y - e.center.y
  let x2 = seg.end.x - e.center.x
  let y2 = seg.end.y - e.center.y
  let out : Array[Point] = []
  if x1 == x2 {
    // Vertical line special-case.
    let root = (a2 - x1 * x1).sqrt()
    let iy1 = b * root / a
    let iy2 = -iy1
    fn is_point_on_line(py : Double, y1 : Double, y2 : Double) -> Bool {
      let lo = min_double(y1, y2)
      let hi = max_double(y1, y2)
      py >= lo && py <= hi
    }
    if is_point_on_line(iy1, y1, y2) {
      out.push(Point::new(x1 + e.center.x, iy1 + e.center.y))
    }
    if iy2 != 0.0 && is_point_on_line(iy2, y1, y2) {
      out.push(Point::new(x1 + e.center.x, iy2 + e.center.y))
    }
    return out
  }
  let m = (y2 - y1) / (x2 - x1)
  let c = y1 - m * x1
  fn is_point_on_line(p : Point, p1 : Point, p2 : Point) -> Bool {
    d2_precision_compare(d2_distance_to_line(p, p1, p2), 0.0, D2_BEZIER_PRECISION) == 0
  }
  let denom = a2 * m * m + b2
  let root = (a2 * b2 * (denom - c * c)).sqrt()
  let ix1 = (-m * c * a2 + root) / denom
  let iy1 = (c * b2 + m * root) / denom
  let ix2 = (-m * c * a2 - root) / denom
  let iy2 = (c * b2 - m * root) / denom
  let p1 = Point::new(ix1, iy1)
  let p2 = Point::new(ix2, iy2)
  if is_point_on_line(p1, Point::new(x1, y1), Point::new(x2, y2)) {
    out.push(Point::new(p1.x + e.center.x, p1.y + e.center.y))
  }
  if !(p1 == p2) && is_point_on_line(p2, Point::new(x1, y1), Point::new(x2, y2)) {
    out.push(Point::new(p2.x + e.center.x, p2.y + e.center.y))
  }
  out
}

///|
fn d2_sgn(x : Double) -> Double {
  if x < 0.0 { -1.0 } else { 1.0 }
}

///|
fn d2_bezier_coeffs(p0 : Double, p1 : Double, p2 : Double, p3 : Double) -> Array[Double] {
  // Ported from d2/lib/geo/bezier.go:bezierCoeffs.
  [
    -p0 + 3.0 * p1 + -3.0 * p2 + p3,
    3.0 * p0 - 6.0 * p1 + 3.0 * p2,
    -3.0 * p0 + 3.0 * p1,
    p0,
  ]
}

///|
fn d2_sort_special(vals : Array[Double]) -> Array[Double] {
  // Ported from d2/lib/geo/bezier.go:sortSpecial.
  let a = vals.copy()
  let mut flip = true
  while flip {
    flip = false
    for i = 0; i < a.length() - 1; i = i + 1 {
      let ai1_gte0 = d2_precision_compare(a[i + 1], 0.0, D2_BEZIER_PRECISION) >= 0
      let ai_gt_ai1 = d2_precision_compare(a[i], a[i + 1], D2_BEZIER_PRECISION) > 0
      let ai_lt0 = d2_precision_compare(a[i], 0.0, D2_BEZIER_PRECISION) < 0
      if (ai1_gte0 && ai_gt_ai1) || (ai_lt0 && ai1_gte0) {
        flip = true
        let tmp = a[i]
        a[i] = a[i + 1]
        a[i + 1] = tmp
      }
    }
  }
  a
}

///|
fn d2_cubic_roots(p_in : Array[Double]) -> Array[Double] {
  // Ported from d2/lib/geo/bezier.go:cubicRoots.
  let t = [-1.0, -1.0, -1.0]
  if d2_precision_compare(p_in[0], 0.0, D2_BEZIER_PRECISION) == 0 {
    if d2_precision_compare(p_in[1], 0.0, D2_BEZIER_PRECISION) == 0 {
      t[0] = -1.0 * (p_in[3] / p_in[2])
      for i = 0; i < 1; i = i + 1 {
        if d2_precision_compare(t[i], 0.0, D2_BEZIER_PRECISION) < 0 ||
          d2_precision_compare(t[i], 1.0, D2_BEZIER_PRECISION) > 0 {
          t[i] = -1.0
        }
      }
      return d2_sort_special(t)
    }
    let mut dq = p_in[2] * p_in[2] - 4.0 * p_in[1] * p_in[3]
    if d2_precision_compare(dq, 0.0, D2_BEZIER_PRECISION) >= 0 {
      dq = dq.sqrt()
      t[0] = -1.0 * ((dq + p_in[2]) / (2.0 * p_in[1]))
      t[1] = (dq - p_in[2]) / (2.0 * p_in[1])
      for i = 0; i < 2; i = i + 1 {
        if d2_precision_compare(t[i], 0.0, D2_BEZIER_PRECISION) < 0 ||
          d2_precision_compare(t[i], 1.0, D2_BEZIER_PRECISION) > 0 {
          t[i] = -1.0
        }
      }
      return d2_sort_special(t)
    }
  }
  let a0 = p_in[0]
  let b0 = p_in[1]
  let c0 = p_in[2]
  let d0 = p_in[3]
  let aa = b0 / a0
  let bb = c0 / a0
  let cc = d0 / a0
  let q = (3.0 * bb - aa * aa) / 9.0
  let r = (9.0 * aa * bb - 27.0 * cc - 2.0 * aa * aa * aa) / 54.0
  let d = q * q * q + r * r
  if d2_precision_compare(d, 0.0, D2_BEZIER_PRECISION) >= 0 {
    let s = d2_sgn(r + d.sqrt()) * @math.cbrt((r + d.sqrt()).abs())
    let tt = d2_sgn(r - d.sqrt()) * @math.cbrt((r - d.sqrt()).abs())
    t[0] = -aa / 3.0 + (s + tt)
    t[1] = -aa / 3.0 - (s + tt) / 2.0
    t[2] = t[1]
    let im = (3.0.sqrt() * (s - tt) / 2.0).abs()
    if d2_precision_compare(im, 0.0, D2_BEZIER_PRECISION) != 0 {
      t[1] = -1.0
      t[2] = -1.0
    }
  } else {
    let th = @math.acos(r / (-q * q * q).sqrt())
    t[0] = 2.0 * (-q).sqrt() * @math.cos(th / 3.0) - aa / 3.0
    t[1] = 2.0 * (-q).sqrt() * @math.cos((th + 2.0 * @math.PI) / 3.0) - aa / 3.0
    t[2] = 2.0 * (-q).sqrt() * @math.cos((th + 4.0 * @math.PI) / 3.0) - aa / 3.0
  }
  for i = 0; i < 3; i = i + 1 {
    if d2_precision_compare(t[i], 0.0, D2_BEZIER_PRECISION) < 0 ||
      d2_precision_compare(t[i], 1.0, D2_BEZIER_PRECISION) > 0 {
      t[i] = -1.0
    }
  }
  d2_sort_special(t)
}

///|
fn[T] array_slice(arr : Array[T], start : Int, end_exclusive : Int) -> Array[T] {
  let mut s = start
  let mut e = end_exclusive
  if s < 0 {
    s = 0
  }
  if e > arr.length() {
    e = arr.length()
  }
  if e < s {
    e = s
  }
  let out : Array[T] = []
  for i = s; i < e; i = i + 1 {
    out.push(arr[i])
  }
  out
}

///|
fn d2_bezier_line_intersections(
  p0 : Point,
  p1 : Point,
  p2 : Point,
  p3 : Point,
  seg : D2Segment,
) -> Array[Point] {
  // Ported from d2/lib/geo/bezier.go:BezierCurve.Intersections + ComputeIntersections.
  let a = seg.end.y - seg.start.y
  let b = seg.start.x - seg.end.x
  let c = seg.start.x * (seg.start.y - seg.end.y) +
    seg.start.y * (seg.end.x - seg.start.x)
  let bx = d2_bezier_coeffs(p0.x, p1.x, p2.x, p3.x)
  let by = d2_bezier_coeffs(p0.y, p1.y, p2.y, p3.y)
  let p = [0.0, 0.0, 0.0, 0.0]
  p[0] = a * bx[0] + b * by[0]
  p[1] = a * bx[1] + b * by[1]
  p[2] = a * bx[2] + b * by[2]
  p[3] = a * bx[3] + b * by[3] + c
  let r = d2_cubic_roots(p)
  let out : Array[Point] = []
  for i = 0; i < 3; i = i + 1 {
    let t = r[i]
    let px = bx[0] * t * t * t + bx[1] * t * t + bx[2] * t + bx[3]
    let py = by[0] * t * t * t + by[1] * t * t + by[2] * t + by[3]
    let mut s = 0.0
    if (seg.end.x - seg.start.x) != 0.0 {
      s = (px - seg.start.x) / (seg.end.x - seg.start.x)
    } else {
      s = (py - seg.start.y) / (seg.end.y - seg.start.y)
    }
    let t_lt0 = d2_precision_compare(t, 0.0, D2_BEZIER_PRECISION) < 0
    let t_gt1 = d2_precision_compare(t, 1.0, D2_BEZIER_PRECISION) > 0
    let s_lt0 = d2_precision_compare(s, 0.0, D2_BEZIER_PRECISION) < 0
    let s_gt1 = d2_precision_compare(s, 1.0, D2_BEZIER_PRECISION) > 0
    if !(t_lt0 || t_gt1 || s_lt0 || s_gt1) {
      out.push(Point::new(px, py))
    }
  }
  out
}

///|
priv enum D2Intersectable {
  Seg(D2Segment)
  Bezier(Point, Point, Point, Point)
  Ellipse(D2Ellipse)
}

///|
fn d2_intersections(shape : D2Intersectable, seg : D2Segment) -> Array[Point] {
  match shape {
    Seg(s) => d2_segment_intersections(s, seg)
    Bezier(p0, p1, p2, p3) => d2_bezier_line_intersections(p0, p1, p2, p3, seg)
    Ellipse(e) => d2_ellipse_intersections(e, seg)
  }
}

///|
priv struct SvgPathContext {
  top_left : Point
  scale_x : Double
  scale_y : Double
  mut start : Point?
  mut current : Point?
  path : Array[D2Intersectable]
}

///|
fn SvgPathContext::new(tl : Point, sx : Double, sy : Double) -> SvgPathContext {
  { top_left: Point::new(tl.x, tl.y), scale_x: sx, scale_y: sy, start: None, current: None, path: [] }
}

///|
fn SvgPathContext::relative(self : SvgPathContext, base : Point, dx : Double, dy : Double) -> Point {
  Point::new(
    d2_chop_precision(base.x + self.scale_x * dx),
    d2_chop_precision(base.y + self.scale_y * dy),
  )
}

///|
fn SvgPathContext::absolute(self : SvgPathContext, x : Double, y : Double) -> Point {
  self.relative(self.top_left, x, y)
}

///|
fn SvgPathContext::start_at(self : SvgPathContext, p : Point) -> Unit {
  self.start = Some(p)
  self.current = Some(p)
}

///|
fn SvgPathContext::z(self : SvgPathContext) -> Unit {
  guard self.current is Some(cur) else { return }
  guard self.start is Some(st) else { return }
  self.path.push(Seg(D2Segment::new(cur, st)))
  self.current = Some(st)
}

///|
fn SvgPathContext::l(self : SvgPathContext, is_lower : Bool, x : Double, y : Double) -> Unit {
  guard self.current is Some(cur) else { return }
  let end = if is_lower { self.relative(cur, x, y) } else { self.absolute(x, y) }
  self.path.push(Seg(D2Segment::new(cur, end)))
  self.current = Some(end)
}

///|
fn SvgPathContext::c(
  self : SvgPathContext,
  is_lower : Bool,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> Unit {
  guard self.current is Some(cur) else { return }
  fn p(self : SvgPathContext, is_lower : Bool, cur : Point, x : Double, y : Double) -> Point {
    if is_lower { self.relative(cur, x, y) } else { self.absolute(x, y) }
  }
  let cp1 = p(self, is_lower, cur, x1, y1)
  let cp2 = p(self, is_lower, cur, x2, y2)
  let end = p(self, is_lower, cur, x3, y3)
  self.path.push(Bezier(cur, cp1, cp2, end))
  self.current = Some(end)
}

///|
fn SvgPathContext::h(self : SvgPathContext, is_lower : Bool, x : Double) -> Unit {
  guard self.current is Some(cur) else { return }
  let end = if is_lower {
    self.relative(cur, x, 0.0)
  } else {
    let mut p = self.absolute(x, 0.0)
    p = Point::new(p.x, cur.y)
    p
  }
  self.path.push(Seg(D2Segment::new(cur, end)))
  self.current = Some(end)
}

///|
fn SvgPathContext::v(self : SvgPathContext, is_lower : Bool, y : Double) -> Unit {
  guard self.current is Some(cur) else { return }
  let end = if is_lower {
    self.relative(cur, 0.0, y)
  } else {
    let mut p = self.absolute(0.0, y)
    p = Point::new(cur.x, p.y)
    p
  }
  self.path.push(Seg(D2Segment::new(cur, end)))
  self.current = Some(end)
}

///|
fn d2_is_rectangular_shape(shape : ShapeType) -> Bool {
  match shape {
    Rectangle | Square | Text | Code | Image | Class | SqlTable | SequenceDiagram |
      C4Container => true
    _ => false
  }
}

///|
fn d2_hexagon_perimeter(box : Box) -> Array[D2Intersectable] {
  // Ported from d2/lib/shape/shape_hexagon.go:hexagonPath.
  let half_y_factor = 43.6 / 87.3
  let pc = SvgPathContext::new(Point::new(box.x, box.y), box.width, box.height)
  pc.start_at(pc.absolute(0.25, 0.0))
  pc.l(false, 0.0, half_y_factor)
  pc.l(false, 0.25, 1.0)
  pc.l(false, 0.75, 1.0)
  pc.l(false, 1.0, half_y_factor)
  pc.l(false, 0.75, 0.0)
  pc.z()
  pc.path
}

///|
fn d2_person_perimeter(box : Box) -> Array[D2Intersectable] {
  // Ported from d2/lib/shape/shape_person.go:personPath.
  let pc = SvgPathContext::new(
    Point::new(box.x, box.y),
    box.width / 68.3,
    box.height / 77.4,
  )
  pc.start_at(pc.absolute(68.3, 77.4))
  pc.h(false, 0.0)
  pc.v(true, -1.1)
  pc.c(true, 0.0, -13.2, 7.5, -25.1, 19.3, -30.8)
  pc.c(false, 12.8, 40.9, 8.9, 33.4, 8.9, 25.2)
  pc.c(false, 8.9, 11.3, 20.2, 0.0, 34.1, 0.0)
  pc.c(true, 13.9, 0.0, 25.2, 11.3, 25.2, 25.2)
  pc.c(true, 0.0, 8.2, -3.8, 15.6, -10.4, 20.4)
  pc.c(true, 11.8, 5.7, 19.3, 17.6, 19.3, 30.8)
  pc.v(true, 1.0)
  pc.h(false, 68.3)
  pc.z()
  pc.path
}

///|
fn d2_cloud_perimeter(box : Box) -> Array[D2Intersectable] {
  // Ported from d2/lib/shape/shape_cloud.go:cloudPath.
  let pc = SvgPathContext::new(
    Point::new(box.x, box.y),
    box.width / 834.0,
    box.height / 523.0,
  )
  pc.start_at(pc.absolute(137.833, 182.833))
  pc.c(true, 0.0, 5.556, -5.556, 11.111, -11.111, 11.111)
  pc.c(true, -70.833, 6.944, -126.389, 77.778, -126.389, 163.889)
  pc.c(true, 0.0, 91.667, 62.5, 165.278, 141.667, 165.278)
  pc.h(true, 537.5)
  pc.c(true, 84.723, 0.0, 154.167, -79.167, 154.167, -175.0)
  pc.c(true, 0.0, -91.667, -63.89, -168.056, -144.444, -173.611)
  pc.c(true, -5.556, 0.0, -11.111, -4.167, -12.5, -11.111)
  pc.c(true, -18.056, -93.055, -101.39, -162.5, -198.611, -162.5)
  pc.c(true, -63.889, 0.0, -120.834, 29.167, -156.944, 75.0)
  pc.c(true, -4.167, 5.556, -11.111, 6.945, -15.278, 5.556)
  pc.c(true, -13.889, -5.556, -29.166, -8.333, -45.833, -8.333)
  pc.c(false, 196.167, 71.722, 143.389, 120.333, 137.833, 182.833)
  pc.z()
  pc.path
}

///|
fn d2_arc_height(box : Box) -> Double {
  // Ported from d2/lib/shape/shape_cylinder.go:getArcHeight.
  let default_arc_depth = 24.0
  let mut arc_h = default_arc_depth
  if box.height < arc_h * 2.0 {
    arc_h = box.height / 2.0
  }
  arc_h
}

///|
fn d2_cylinder_perimeter(box : Box) -> Array[D2Intersectable] {
  // Ported from d2/lib/shape/shape_cylinder.go:cylinderOuterPath.
  let arc_h = d2_arc_height(box)
  let multiplier = 0.45
  let pc = SvgPathContext::new(Point::new(box.x, box.y), 1.0, 1.0)
  pc.start_at(pc.absolute(0.0, arc_h))
  pc.c(false, 0.0, 0.0, box.width * multiplier, 0.0, box.width / 2.0, 0.0)
  pc.c(false, box.width - box.width * multiplier, 0.0, box.width, 0.0, box.width, arc_h)
  pc.v(true, box.height - arc_h * 2.0)
  pc.c(false, box.width, box.height, box.width - box.width * multiplier, box.height, box.width / 2.0, box.height)
  pc.c(false, box.width * multiplier, box.height, 0.0, box.height, 0.0, box.height - arc_h)
  pc.v(true, -(box.height - arc_h * 2.0))
  pc.z()
  pc.path
}

///|
fn d2_arc_width(box : Box) -> Double {
  // Ported from d2/lib/shape/shape_queue.go:getArcWidth.
  let default_arc_depth = 24.0
  let mut arc_w = default_arc_depth
  if box.width < arc_w * 2.0 {
    arc_w = box.width / 2.0
  }
  arc_w
}

///|
fn d2_queue_perimeter(box : Box) -> Array[D2Intersectable] {
  // Ported from d2/lib/shape/shape_queue.go:queueOuterPath.
  let arc_w = d2_arc_width(box)
  let multiplier = 0.45
  let pc = SvgPathContext::new(Point::new(box.x, box.y), 1.0, 1.0)
  pc.start_at(pc.absolute(arc_w, 0.0))
  pc.h(true, box.width - 2.0 * arc_w)
  pc.c(false, box.width, 0.0, box.width, box.height * multiplier, box.width, box.height / 2.0)
  pc.c(false, box.width, box.height - box.height * multiplier, box.width, box.height, box.width - arc_w, box.height)
  pc.h(true, -1.0 * (box.width - 2.0 * arc_w))
  pc.c(false, 0.0, box.height, 0.0, box.height - box.height * multiplier, 0.0, box.height / 2.0)
  pc.c(false, 0.0, box.height * multiplier, 0.0, 0.0, arc_w, 0.0)
  pc.z()
  pc.path
}

///|
fn d2_stored_data_perimeter(box : Box) -> Array[D2Intersectable] {
  // Ported from d2/lib/shape/shape_stored_data.go:storedDataPath.
  let stored_data_wedge_width = 15.0
  let mut wedge = stored_data_wedge_width
  let multiplier = 0.27
  if box.width < wedge * 2.0 {
    wedge = box.width / 2.0
  }
  let pc = SvgPathContext::new(Point::new(box.x, box.y), 1.0, 1.0)
  pc.start_at(pc.absolute(wedge, 0.0))
  pc.h(true, box.width - wedge)
  pc.c(false, box.width - wedge * multiplier, 0.0, box.width - wedge, box.height * multiplier, box.width - wedge, box.height / 2.0)
  pc.c(false, box.width - wedge, box.height - box.height * multiplier, box.width - wedge * multiplier, box.height, box.width, box.height)
  pc.h(true, -(box.width - wedge))
  pc.c(false, wedge - wedge * multiplier, box.height, 0.0, box.height - box.height * multiplier, 0.0, box.height / 2.0)
  pc.c(false, 0.0, box.height * multiplier, wedge - wedge * multiplier, 0.0, wedge, 0.0)
  pc.z()
  pc.path
}

///|
fn d2_perimeter(shape : ShapeType, box : Box) -> Array[D2Intersectable] {
  match shape {
    Hexagon => d2_hexagon_perimeter(box)
    Person => d2_person_perimeter(box)
    Cloud => d2_cloud_perimeter(box)
    Cylinder => d2_cylinder_perimeter(box)
    Queue => d2_queue_perimeter(box)
    StoredData => d2_stored_data_perimeter(box)
    Circle => [Ellipse({ center: box.center(), rx: box.width / 2.0, ry: box.height / 2.0 })]
    Oval => [Ellipse({ center: box.center(), rx: box.width / 2.0, ry: box.height / 2.0 })]
    _ => []
  }
}

///|
fn d2_trace_to_shape_border(
  shape : ShapeType,
  box : Box,
  rect_border_point : Point,
  prev_point : Point,
) -> Point {
  // Ported from d2/lib/shape/shape.go:TraceToShapeBorder.
  if d2_is_rectangular_shape(shape) {
    return rect_border_point
  }
  let perim = d2_perimeter(shape, box)
  if perim.is_empty() {
    return rect_border_point
  }
  let mut scale_size = box.width
  if prev_point.x == rect_border_point.x {
    scale_size = box.height
  }
  let dx = rect_border_point.x - prev_point.x
  let dy = rect_border_point.y - prev_point.y
  let len = (dx * dx + dy * dy).sqrt()
  if len == 0.0 {
    return rect_border_point
  }
  let ux = dx / len
  let uy = dy / len
  let ext_end = Point::new(prev_point.x + ux * (len + scale_size), prev_point.y + uy * (len + scale_size))
  let ext_seg = D2Segment::new(prev_point, ext_end)
  let mut closest_d = 1.0 / 0.0 // +Inf
  let mut closest = rect_border_point
  for it in perim {
    for ip in d2_intersections(it, ext_seg) {
      let d = d2_euclidean_distance(rect_border_point.x, rect_border_point.y, ip.x, ip.y)
      if d < closest_d {
        closest_d = d
        closest = ip
      }
    }
  }
  let tx = d2_truncate_float32(closest.x)
  let ty = d2_truncate_float32(closest.y)
  Point::new(tx.round(), ty.round())
}

///|
fn d2_get_point_on_box(
  pos : D2LabelPosition,
  box : Box,
  padding : Double,
  width : Double,
  height : Double,
) -> Point {
  // Ported from d2/lib/label/label.go:Position.GetPointOnBox (subset).
  let mut x = box.x
  let mut y = box.y
  let cx = box.x + box.width / 2.0
  let cy = box.y + box.height / 2.0
  match pos {
    OutsideTopLeft => {
      x = x - padding
      y = y - padding - height
    }
    OutsideTopCenter => {
      x = cx - width / 2.0
      y = y - padding - height
    }
    OutsideBottomCenter => {
      x = cx - width / 2.0
      y = y + box.height + padding
    }
    OutsideLeftMiddle => {
      x = x - padding - width
      y = cy - height / 2.0
    }
    OutsideRightMiddle => {
      x = x + box.width + padding
      y = cy - height / 2.0
    }
    InsideTopLeft => {
      x = x + padding
      y = y + padding
    }
    InsideTopCenter => {
      x = cx - width / 2.0
      y = y + padding
    }
    InsideMiddleCenter => {
      x = cx - width / 2.0
      y = cy - height / 2.0
    }
    _ => ()
  }
  Point::new(x, y)
}

///|
fn d2_find_outer_intersection(
  pos : D2LabelPosition,
  intersections : Array[Point],
) -> Point {
  // Ported from d2graph/layout.go:findOuterIntersection.
  let sorted = intersections.copy()
  sorted.sort_by(fn(a, b) {
    match pos {
      OutsideTopLeft | OutsideTopCenter => a.y.compare(b.y)
      OutsideBottomCenter => b.y.compare(a.y)
      OutsideLeftMiddle => a.x.compare(b.x)
      OutsideRightMiddle => b.x.compare(a.x)
      _ => 0
    }
  })
  sorted[0]
}

///|
fn d2_trace_edge_to_shapes(graph : Graph) -> Unit {
  // Ported from d2layouts/d2elklayout/layout.go edge post-processing loop.
  for edge in graph.edges {
    let points = edge.route
    if points.length() < 2 {
      continue
    }
    let mut start_index = 0
    let mut end_index = points.length() - 1
    let start = points[start_index]
    let end = points[end_index]
    let src_opt = graph.find_object(edge.src_id)
    let dst_opt = graph.find_object(edge.dst_id)
    guard src_opt is Some(src) else { continue }
    guard dst_opt is Some(dst) else { continue }
    let mut orig_src_box : Box? = None
    let mut orig_dst_box : Box? = None

    // If the edge passes through 3d/multiple, use the offset box for tracing.
    match src.box {
      Some(b) => {
        let (dx, dy) = d2_modifier_adjustments(src)
        if (dx != 0.0 || dy != 0.0) &&
          start.x > b.x + dx &&
          start.y < b.y + b.height - dy {
          orig_src_box = Some(b)
          src.box = Some(Box::new(b.x + dx, b.y - dy, b.width, b.height))
        }
      }
      None => ()
    }
    match dst.box {
      Some(b) => {
        let (dx, dy) = d2_modifier_adjustments(dst)
        if (dx != 0.0 || dy != 0.0) &&
          end.x > b.x + dx &&
          end.y < b.y + b.height - dy {
          orig_dst_box = Some(b)
          dst.box = Some(Box::new(b.x + dx, b.y - dy, b.width, b.height))
        }
      }
      None => ()
    }

    // Trace endpoints.
    let (new_start, new_end) = d2_trace_to_shape(graph, edge, src, dst, points, start_index, end_index)
    start_index = new_start
    end_index = new_end
    let new_points = array_slice(points, start_index, end_index + 1)
    edge.route.clear()
    for p in new_points {
      edge.route.push(p)
    }

    // Undo 3d/multiple offset.
    match orig_src_box {
      Some(b) => src.box = Some(b)
      None => ()
    }
    match orig_dst_box {
      Some(b) => dst.box = Some(b)
      None => ()
    }
  }
}

///|
fn d2_trace_to_shape(
  _graph : Graph,
  _edge : Edge,
  src : Object,
  dst : Object,
  points : Array[Point],
  start_index : Int,
  end_index : Int,
) -> (Int, Int) {
  // Ported from d2graph/layout.go:Edge.TraceToShape.
  let mut si = start_index
  let mut ei = end_index
  guard si + 1 <= ei else { return (si, ei) }
  guard src.box is Some(src_box) else { return (si, ei) }
  guard dst.box is Some(dst_box) else { return (si, ei) }

  let mut starting = D2Segment::new(points[si + 1], points[si])
  let mut overlaps_label = false
  let mut overlaps_icon = false

  if d2_has_label(src) {
    let label_pos = d2_default_label_position(src)
    if d2_is_outside(label_pos) {
      match src.label_box {
        Some(lb) => {
          let label_tl = d2_get_point_on_box(label_pos, src_box, D2_LABEL_PADDING, lb.width, lb.height)
          // Add left/right padding to box.
          let label_box = Box::new(label_tl.x - D2_LABEL_PADDING, label_tl.y, lb.width + 2.0 * D2_LABEL_PADDING, lb.height)
          // Note: copied verbatim from D2 (the loop bound looks inverted).
          while d2_box_contains(label_box, starting.end) && si + 1 > ei {
            starting = D2Segment::new(starting.end, points[si + 2])
            si = si + 1
          }
          let intersections = d2_box_intersections(label_box, starting)
          if !intersections.is_empty() {
            overlaps_label = true
            let mut p = intersections[0]
            if intersections.length() > 1 {
              p = d2_find_outer_intersection(label_pos, intersections)
            }
            points[si] = p
            starting = D2Segment::new(starting.start, p)
            if si + 1 < ei && starting.length() < D2_MIN_SEGMENT_LEN {
              points[si + 1] = points[si]
              si = si + 1
            }
          }
        }
        None => ()
      }
    }
  }

  if !overlaps_label && d2_has_icon(src) {
    let icon_pos_opt = d2_default_icon_position(src)
    match icon_pos_opt {
      Some(icon_pos) =>
        if d2_is_outside(icon_pos) {
          match src.box {
            Some(b) => {
              let icon_size = d2_icon_size(b, icon_pos)
              let icon_tl = d2_get_point_on_box(icon_pos, b, D2_LABEL_PADDING, icon_size, icon_size)
              let icon_box = Box::new(icon_tl.x, icon_tl.y, icon_size, icon_size)
              // Note: copied verbatim from D2 (the loop bound looks inverted).
              while d2_box_contains(icon_box, starting.end) && si + 1 > ei {
                starting = D2Segment::new(starting.end, points[si + 2])
                si = si + 1
              }
              let intersections = d2_box_intersections(icon_box, starting)
              if !intersections.is_empty() {
                overlaps_icon = true
                let mut p = intersections[0]
                if intersections.length() > 1 {
                  p = d2_find_outer_intersection(icon_pos, intersections)
                }
                points[si] = p
                starting = D2Segment::new(starting.start, p)
                if si + 1 < ei && starting.length() < D2_MIN_SEGMENT_LEN {
                  points[si + 1] = points[si]
                  si = si + 1
                }
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }

  if !overlaps_label && !overlaps_icon {
    let intersections = d2_box_intersections(src_box, starting)
    if !intersections.is_empty() {
      points[si] = intersections[0]
      starting = D2Segment::new(starting.start, intersections[0])
      if si + 1 < ei && starting.length() < D2_MIN_SEGMENT_LEN {
        points[si + 1] = points[si]
        si = si + 1
      }
    }
    points[si] = d2_trace_to_shape_border(src.shape_type, src_box, points[si], points[si + 1])
  }

  let mut ending = D2Segment::new(points[ei - 1], points[ei])
  overlaps_label = false
  overlaps_icon = false

  if d2_has_label(dst) {
    let label_pos = d2_default_label_position(dst)
    if d2_is_outside(label_pos) {
      match dst.label_box {
        Some(lb) => {
          let label_tl = d2_get_point_on_box(label_pos, dst_box, D2_LABEL_PADDING, lb.width, lb.height)
          let label_box = Box::new(label_tl.x - D2_LABEL_PADDING, label_tl.y, lb.width + 2.0 * D2_LABEL_PADDING, lb.height)
          while d2_box_contains(label_box, ending.start) && ei - 1 > si {
            ending = D2Segment::new(points[ei - 2], ending.start)
            ei = ei - 1
          }
          let intersections = d2_box_intersections(label_box, ending)
          if !intersections.is_empty() {
            overlaps_label = true
            let mut p = intersections[0]
            if intersections.length() > 1 {
              p = d2_find_outer_intersection(label_pos, intersections)
            }
            points[ei] = p
            ending = D2Segment::new(ending.start, p)
            if ei - 1 > si && ending.length() < D2_MIN_SEGMENT_LEN {
              points[ei - 1] = points[ei]
              ei = ei - 1
            }
          }
        }
        None => ()
      }
    }
  }

  if !overlaps_label && d2_has_icon(dst) {
    let icon_pos_opt = d2_default_icon_position(dst)
    match icon_pos_opt {
      Some(icon_pos) =>
        if d2_is_outside(icon_pos) {
          match dst.box {
            Some(b) => {
              let icon_size = d2_icon_size(b, icon_pos)
              let icon_tl = d2_get_point_on_box(icon_pos, b, D2_LABEL_PADDING, icon_size, icon_size)
              let icon_box = Box::new(icon_tl.x, icon_tl.y, icon_size, icon_size)
              while d2_box_contains(icon_box, ending.start) && ei - 1 > si {
                ending = D2Segment::new(points[ei - 2], ending.start)
                ei = ei - 1
              }
              let intersections = d2_box_intersections(icon_box, ending)
              if !intersections.is_empty() {
                overlaps_icon = true
                let mut p = intersections[0]
                if intersections.length() > 1 {
                  p = d2_find_outer_intersection(icon_pos, intersections)
                }
                points[ei] = p
                ending = D2Segment::new(ending.start, p)
                if ei - 1 > si && ending.length() < D2_MIN_SEGMENT_LEN {
                  points[ei - 1] = points[ei]
                  ei = ei - 1
                }
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }

  if !overlaps_label && !overlaps_icon {
    let intersections = d2_box_intersections(dst_box, ending)
    if !intersections.is_empty() {
      points[ei] = intersections[0]
      ending = D2Segment::new(ending.start, intersections[0])
      if ei - 1 > si && ending.length() < D2_MIN_SEGMENT_LEN {
        points[ei - 1] = points[ei]
        ei = ei - 1
      }
    }
    points[ei] = d2_trace_to_shape_border(dst.shape_type, dst_box, points[ei], points[ei - 1])
  }

  (si, ei)
}

///|
fn d2_count_object_intersects(graph : Graph, src : Object, dst : Object, seg : D2Segment) -> Int {
  // Ported from d2elklayout/layout.go:countObjectIntersects.
  let mut count = 0
  for obj in graph.objects {
    if obj.id == src.id || obj.id == dst.id {
      continue
    }
    match obj.box {
      Some(b) =>
        if d2_box_intersects_with_buffer(b, seg, D2_EDGE_NODE_SPACING - 1.0) {
          count = count + 1
        }
      None => ()
    }
  }
  count
}

///|
fn d2_count_edge_intersects(
  graph : Graph,
  skip_edge_index : Int,
  seg : D2Segment,
) -> (Int, Int, Int, Int) {
  // Ported from d2elklayout/layout.go:countEdgeIntersects.
  let is_horizontal = seg.start.y.ceil() == seg.end.y.ceil()
  let mut crossings = 0
  let mut overlaps = 0
  let mut close_overlaps = 0
  let mut touching = 0
  for e in graph.edges {
    if e.index == skip_edge_index {
      continue
    }
    for i = 0; i < e.route.length() - 1; i = i + 1 {
      let other = D2Segment::new(e.route[i], e.route[i + 1])
      let other_is_horizontal = other.start.y.ceil() == other.end.y.ceil()
      if is_horizontal == other_is_horizontal {
        if d2_segment_overlaps(seg, other, !is_horizontal, 0.0) {
          if is_horizontal {
            let dy = (seg.start.y - other.start.y).abs()
            if dy < D2_EDGE_NODE_SPACING / 2.0 {
              overlaps = overlaps + 1
              if dy < D2_EDGE_NODE_SPACING / 4.0 {
                close_overlaps = close_overlaps + 1
                if dy < 1.0 {
                  touching = touching + 1
                }
              }
            }
          } else {
            let dx = (seg.start.x - other.start.x).abs()
            if dx < D2_EDGE_NODE_SPACING / 2.0 {
              overlaps = overlaps + 1
              if dx < D2_EDGE_NODE_SPACING / 4.0 {
                close_overlaps = close_overlaps + 1
                if (seg.start.y - other.start.y).abs() < 1.0 {
                  touching = touching + 1
                }
              }
            }
          }
        }
      } else {
        if !d2_segment_intersections(seg, other).is_empty() {
          crossings = crossings + 1
        }
      }
    }
  }
  (crossings, overlaps, close_overlaps, touching)
}

///|
fn d2_delete_bends(graph : Graph) -> Unit {
  // Ported from d2elklayout/layout.go:deleteBends.

  // Remove S-shapes at the source and the target.
  for is_source in [true, false] {
    for ei = 0; ei < graph.edges.length(); ei = ei + 1 {
      let e = graph.edges[ei]
      if e.route.length() < 4 {
        continue
      }
      if e.src_id == e.dst_id {
        continue
      }
      let src_opt = graph.find_object(e.src_id)
      let dst_opt = graph.find_object(e.dst_id)
      guard src_opt is Some(src) else { continue }
      guard dst_opt is Some(dst) else { continue }

      let (endpoint, start, corner, end, column_index) = if is_source {
        (src, e.route[0], e.route[1], e.route[2], e.src_column_index)
      } else {
        let n = e.route.length()
        (dst, e.route[n - 1], e.route[n - 2], e.route[n - 3], e.dst_column_index)
      }

      let is_horizontal = start.y.ceil() == corner.y.ceil()
      guard endpoint.box is Some(ep_box) else { continue }
      let (dx, dy) = d2_modifier_adjustments(endpoint)

      // Make sure it's still attached.
      match column_index {
        Some(col_idx) => {
          let row_height = ep_box.height / (endpoint.children.length() + 1).to_double()
          let row_center = ep_box.y + row_height * (col_idx + 1).to_double() + row_height / 2.0
          if (end.y - row_center).abs() > row_height / 3.0 {
            continue
          }
        }
        None =>
          if is_horizontal {
            if end.y <= ep_box.y + 10.0 - dy {
              continue
            }
            if end.y >= ep_box.y + ep_box.height - 10.0 {
              continue
            }
          } else {
            if end.x <= ep_box.x + 10.0 {
              continue
            }
            if end.x >= ep_box.x + ep_box.width - 10.0 + dx {
              continue
            }
          }
      }

      let mut new_start = if is_horizontal {
        Point::new(start.x, end.y)
      } else {
        Point::new(end.x, start.y)
      }
      new_start = d2_trace_to_shape_border(endpoint.shape_type, ep_box, new_start, end)

      let old_seg = D2Segment::new(start, corner)
      let new_seg = D2Segment::new(new_start, end)

      let old_obj = d2_count_object_intersects(graph, src, dst, old_seg)
      let new_obj = d2_count_object_intersects(graph, src, dst, new_seg)
      if new_obj > old_obj {
        continue
      }

      let (old_cross, old_ov, old_close, old_touch) = d2_count_edge_intersects(graph, e.index, old_seg)
      let (new_cross, new_ov, new_close, new_touch) = d2_count_edge_intersects(graph, e.index, new_seg)
      if new_cross > old_cross || new_ov > old_ov || new_close > old_close || new_touch > old_touch {
        continue
      }

      // Commit.
      if is_source {
        let kept = array_slice(e.route, 3, e.route.length())
        e.route.clear()
        e.route.push(new_start)
        for p in kept {
          e.route.push(p)
        }
      } else {
        let kept = array_slice(e.route, 0, e.route.length() - 3)
        e.route.clear()
        for p in kept {
          e.route.push(p)
        }
        e.route.push(new_start)
      }
    }
  }

  // Remove ladders.
  let point_counts : Map[String, Int] = {}
  fn key(p : Point) -> String {
    p.x.to_string() + "," + p.y.to_string()
  }
  for e in graph.edges {
    for p in e.route {
      let k = key(p)
      point_counts[k] = point_counts.get(k).unwrap_or(0) + 1
    }
  }

  for ei = 0; ei < graph.edges.length(); ei = ei + 1 {
    let e = graph.edges[ei]
    if e.route.length() < 6 {
      continue
    }
    if e.src_id == e.dst_id {
      continue
    }
    for i = 1; i < e.route.length() - 3; i = i + 1 {
      let before = e.route[i - 1]
      let start = e.route[i]
      let corner = e.route[i + 1]
      let end = e.route[i + 2]
      let after = e.route[i + 3]
      if point_counts.get(key(corner)).unwrap_or(0) > 1 {
        continue
      }
      let mut new_corner = Point::zero()
      if start.x.ceil() == corner.x.ceil() {
        new_corner = Point::new(end.x, start.y)
        if (end.x > start.x) != (start.x > before.x) {
          continue
        }
        if (end.y > start.y) != (after.y > end.y) {
          continue
        }
      } else {
        new_corner = Point::new(start.x, end.y)
        if (end.y > start.y) != (start.y > before.y) {
          continue
        }
        if (end.x > start.x) != (after.x > end.x) {
          continue
        }
      }

      let old_s1 = D2Segment::new(start, corner)
      let old_s2 = D2Segment::new(corner, end)
      let new_s1 = D2Segment::new(start, new_corner)
      let new_s2 = D2Segment::new(new_corner, end)

      let src_opt = graph.find_object(e.src_id)
      let dst_opt = graph.find_object(e.dst_id)
      guard src_opt is Some(src) else { continue }
      guard dst_opt is Some(dst) else { continue }
      let old_obj = d2_count_object_intersects(graph, src, dst, old_s1) +
        d2_count_object_intersects(graph, src, dst, old_s2)
      let new_obj = d2_count_object_intersects(graph, src, dst, new_s1) +
        d2_count_object_intersects(graph, src, dst, new_s2)
      if new_obj > old_obj {
        continue
      }

      let (oc1, oo1, oco1, ot1) = d2_count_edge_intersects(graph, e.index, old_s1)
      let (oc2, oo2, oco2, ot2) = d2_count_edge_intersects(graph, e.index, old_s2)
      let old_cross = oc1 + oc2
      let old_ov = oo1 + oo2
      let old_close = oco1 + oco2
      let old_touch = ot1 + ot2
      let (nc1, no1, nco1, nt1) = d2_count_edge_intersects(graph, e.index, new_s1)
      let (nc2, no2, nco2, nt2) = d2_count_edge_intersects(graph, e.index, new_s2)
      let new_cross = nc1 + nc2
      let new_ov = no1 + no2
      let new_close = nco1 + nco2
      let new_touch = nt1 + nt2
      if new_cross > old_cross || new_ov > old_ov || new_close > old_close || new_touch > old_touch {
        continue
      }

      // Commit.
      let prefix = array_slice(e.route, 0, i)
      let suffix = array_slice(e.route, i + 3, e.route.length())
      e.route.clear()
      for p in prefix {
        e.route.push(p)
      }
      e.route.push(new_corner)
      for p in suffix {
        e.route.push(p)
      }
      break
    }
  }
}

///|
fn d2_post_process_routes(graph : Graph) -> Unit {
  d2_trace_edge_to_shapes(graph)
  d2_delete_bends(graph)
}
