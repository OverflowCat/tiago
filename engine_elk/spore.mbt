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
/// ELK SPOrE port (sporeOverlap / sporeCompaction).
///
/// This file is a direct, small-scope port of the corresponding ELK Java
/// reference implementation under `elk-reference/plugins/.../alg/spore` and
/// `elk-reference/plugins/.../alg/common/spore`.
///
/// We keep the behavior deterministic and match d2's embedded `elk.js`.

///|
let spore_fuzziness : Double = 0.0001

///|
fn fuzzy_compare(a : Double, b : Double, eps : Double) -> Int {
  if a < b - eps {
    -1
  } else if a > b + eps {
    1
  } else {
    0
  }
}

///|
priv struct SporeVec {
  x : Double
  y : Double
}

///|
fn SporeVec::new(x : Double, y : Double) -> SporeVec {
  { x, y }
}

///|
fn SporeVec::add(self : SporeVec, other : SporeVec) -> SporeVec {
  { x: self.x + other.x, y: self.y + other.y }
}

///|
fn SporeVec::sub(self : SporeVec, other : SporeVec) -> SporeVec {
  { x: self.x - other.x, y: self.y - other.y }
}

///|
fn SporeVec::scale(self : SporeVec, s : Double) -> SporeVec {
  { x: self.x * s, y: self.y * s }
}

///|
fn SporeVec::negate(self : SporeVec) -> SporeVec {
  { x: -self.x, y: -self.y }
}

///|
fn SporeVec::length(self : SporeVec) -> Double {
  (self.x * self.x + self.y * self.y).sqrt()
}

///|
fn SporeVec::distance(self : SporeVec, other : SporeVec) -> Double {
  self.sub(other).length()
}

///|
fn SporeVec::equals_fuzzily(
  self : SporeVec,
  other : SporeVec,
  eps : Double,
) -> Bool {
  (self.x - other.x).abs() <= eps && (self.y - other.y).abs() <= eps
}

///|
fn SporeVec::scale_to_length(self : SporeVec, len : Double) -> SporeVec {
  let l = self.length()
  if l == 0.0 {
    self
  } else {
    self.scale(len / l)
  }
}

///|
fn cross(a : SporeVec, b : SporeVec) -> Double {
  a.x * b.y - a.y * b.x
}

///|
priv struct SporeRect {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
fn SporeRect::new(x : Double, y : Double, w : Double, h : Double) -> SporeRect {
  { x, y, width: w, height: h }
}

///|
fn SporeRect::center(self : SporeRect) -> SporeVec {
  SporeVec::new(self.x + self.width / 2.0, self.y + self.height / 2.0)
}

///|
fn SporeRect::position(self : SporeRect) -> SporeVec {
  SporeVec::new(self.x, self.y)
}

///|
fn SporeRect::translate(self : SporeRect, v : SporeVec) -> SporeRect {
  { x: self.x + v.x, y: self.y + v.y, width: self.width, height: self.height }
}

///|
fn shortest_distance(r1 : SporeRect, r2 : SporeRect) -> Double {
  // Ported from elk-reference ElkMath.shortestDistance(ElkRectangle,ElkRectangle).
  let right_dist = r2.x - (r1.x + r1.width)
  let left_dist = r1.x - (r2.x + r2.width)
  let top_dist = r1.y - (r2.y + r2.height)
  let bottom_dist = r2.y - (r1.y + r1.height)
  let horz_dist = max_double(left_dist, right_dist)
  let vert_dist = max_double(top_dist, bottom_dist)
  let horz_nonneg = fuzzy_compare(horz_dist, 0.0, 1.0e-6) >= 0
  let vert_nonneg = fuzzy_compare(vert_dist, 0.0, 1.0e-6) >= 0
  // XOR: one axis is separated, the other overlaps.
  if horz_nonneg != vert_nonneg {
    max_double(vert_dist, horz_dist)
  } else if fuzzy_compare(horz_dist, 0.0, 1.0e-6) > 0 {
    (vert_dist * vert_dist + horz_dist * horz_dist).sqrt()
  } else {
    -(vert_dist * vert_dist + horz_dist * horz_dist).sqrt()
  }
}

///|
fn spore_overlap(r1 : SporeRect, r2 : SporeRect) -> Double {
  // Ported from elk-reference Utils.overlap(ElkRectangle,ElkRectangle).
  let horizontal_overlap = min_double(
    (r1.x - (r2.x + r2.width)).abs(),
    (r1.x + r1.width - r2.x).abs(),
  )
  let vertical_overlap = min_double(
    (r1.y - (r2.y + r2.height)).abs(),
    (r1.y + r1.height - r2.y).abs(),
  )
  let horizontal_center_distance = (r1.x +
  r1.width / 2.0 -
  (r2.x + r2.width / 2.0)).abs()
  if horizontal_center_distance > r1.width / 2.0 + r2.width / 2.0 {
    return 1.0
  }
  let vertical_center_distance = (r1.y +
  r1.height / 2.0 -
  (r2.y + r2.height / 2.0)).abs()
  if vertical_center_distance > r1.height / 2.0 + r2.height / 2.0 {
    return 1.0
  }
  if horizontal_center_distance == 0.0 && vertical_center_distance == 0.0 {
    return 0.0
  }
  if horizontal_center_distance == 0.0 {
    return vertical_overlap / vertical_center_distance + 1.0
  }
  if vertical_center_distance == 0.0 {
    return horizontal_overlap / horizontal_center_distance + 1.0
  }
  min_double(
    horizontal_overlap / horizontal_center_distance,
    vertical_overlap / vertical_center_distance,
  ) +
  1.0
}

///|
priv struct SporeNode {
  mut original_vertex : SporeVec
  mut vertex : SporeVec
  mut rect : SporeRect
}

///|
fn SporeNode::new(v : SporeVec, r : SporeRect) -> SporeNode {
  { original_vertex: v, vertex: v, rect: r }
}

///|
fn SporeNode::translate(self : SporeNode, v : SporeVec) -> Unit {
  self.vertex = self.vertex.add(v)
  self.rect = self.rect.translate(v)
}

///|
fn SporeNode::set_center_position(self : SporeNode, p : SporeVec) -> Unit {
  self.translate(p.sub(self.vertex))
}

///|
fn SporeNode::underlap(self : SporeNode, other : SporeNode) -> Double {
  // Ported from elk-reference Node.underlap(Node).
  let horizontal_center_distance = (self.rect.center().x - other.rect.center().x).abs()
  let vertical_center_distance = (self.rect.center().y - other.rect.center().y).abs()
  let mut h_scale = 1.0
  let mut v_scale = 1.0
  if horizontal_center_distance > self.rect.width / 2.0 + other.rect.width / 2.0 {
    let horizontal_underlap = min_double(
      (self.rect.x - (other.rect.x + other.rect.width)).abs(),
      (self.rect.x + self.rect.width - other.rect.x).abs(),
    )
    h_scale = 1.0 - horizontal_underlap / horizontal_center_distance
  }
  if vertical_center_distance > self.rect.height / 2.0 + other.rect.height / 2.0 {
    let vertical_underlap = min_double(
      (self.rect.y - (other.rect.y + other.rect.height)).abs(),
      (self.rect.y + self.rect.height - other.rect.y).abs(),
    )
    v_scale = 1.0 - vertical_underlap / vertical_center_distance
  }
  let scale = min_double(h_scale, v_scale)
  (1.0 - scale) *
  (horizontal_center_distance * horizontal_center_distance +
  vertical_center_distance * vertical_center_distance).sqrt()
}

///|
fn intersects2(
  p : SporeVec,
  r : SporeVec,
  q : SporeVec,
  s : SporeVec,
) -> SporeVec? {
  // Ported from elk-reference ElkMath.intersects2.
  let pq = q.sub(p)
  let pq_x_r = cross(pq, r)
  let r_x_s = cross(r, s)
  if r_x_s == 0.0 {
    if pq_x_r == 0.0 {
      // Collinear: return point closest to center of `s`.
      let center = q.add(s.scale(0.5))
      let d1 = p.distance(center)
      let d2 = p.add(r).distance(center)
      let l = s.length() * 0.5
      if d1 < d2 && d1 <= l {
        return Some(p)
      }
      if d2 <= l {
        return Some(p.add(r))
      }
      None
    } else {
      None
    }
  } else {
    let t = cross(pq, s) / r_x_s
    let u = pq_x_r / r_x_s
    if t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0 {
      Some(p.add(r.scale(t)))
    } else {
      None
    }
  }
}

///|
fn trace_rays(
  a1 : SporeVec,
  a2 : SporeVec,
  b1 : SporeVec,
  b2 : SporeVec,
  v : SporeVec,
) -> Double {
  // Ported from elk-reference ElkMath.traceRays.
  let mut result = @double.infinity
  let mut endpoint_hit = false
  let intersection0 = intersects2(a1, a2.sub(a1), b1.add(v), b2.sub(b1))
  let edge_case = match intersection0 {
    Some(i) =>
      !(i.equals_fuzzily(a1, spore_fuzziness) ||
      i.equals_fuzzily(a2, spore_fuzziness))
    None => false
  }
  let intersection1 = intersects2(a1, a2.sub(a1), b1, v)
  match intersection1 {
    Some(i) => {
      let eq_a1 = i.equals_fuzzily(a1, spore_fuzziness)
      let eq_a2 = i.equals_fuzzily(a2, spore_fuzziness)
      if eq_a1 == eq_a2 || edge_case {
        result = min_double(result, i.sub(b1).length())
      } else {
        endpoint_hit = true
      }
    }
    None => ()
  }
  let intersection2 = intersects2(a1, a2.sub(a1), b2, v)
  match intersection2 {
    Some(i) => {
      let eq_a1 = i.equals_fuzzily(a1, spore_fuzziness)
      let eq_a2 = i.equals_fuzzily(a2, spore_fuzziness)
      if endpoint_hit || eq_a1 == eq_a2 || edge_case {
        result = min_double(result, i.sub(b2).length())
      }
    }
    None => ()
  }
  result
}

///|
fn segment_distance(
  a1 : SporeVec,
  a2 : SporeVec,
  b1 : SporeVec,
  b2 : SporeVec,
  v : SporeVec,
) -> Double {
  // Ported from elk-reference ElkMath.distance(a1,a2,b1,b2,v).
  min_double(
    trace_rays(a1, a2, b1, b2, v),
    trace_rays(b1, b2, a1, a2, v.negate()),
  )
}

///|
fn rect_edges(r : SporeRect) -> Array[(SporeVec, SporeVec)] {
  // Ported from elk-reference Utils.getRectEdges.
  let tl = SporeVec::new(r.x, r.y)
  let tr = SporeVec::new(r.x + r.width, r.y)
  let bl = SporeVec::new(r.x, r.y + r.height)
  let br = SporeVec::new(r.x + r.width, r.y + r.height)
  [(tl, tr), (tl, bl), (br, tr), (br, bl)]
}

///|
fn SporeNode::distance(
  self : SporeNode,
  other : SporeNode,
  v : SporeVec,
) -> Double {
  // Ported from elk-reference Node.distance(Node,KVector).
  let mut result = @double.infinity
  for ae in rect_edges(self.rect) {
    let (a1, a2) = ae
    for be in rect_edges(other.rect) {
      let (b1, b2) = be
      result = min_double(result, segment_distance(a1, a2, b1, b2, v))
    }
  }
  result
}

///|
fn SporeNode::touches(self : SporeNode, other : SporeNode) -> Bool {
  // Ported from elk-reference Node.touches(Node).
  fuzzy_compare(self.rect.x, other.rect.x + other.rect.width, spore_fuzziness) <=
  0 &&
  fuzzy_compare(other.rect.x, self.rect.x + self.rect.width, spore_fuzziness) <=
  0 &&
  fuzzy_compare(self.rect.y, other.rect.y + other.rect.height, spore_fuzziness) <=
  0 &&
  fuzzy_compare(other.rect.y, self.rect.y + self.rect.height, spore_fuzziness) <=
  0
}

///|
priv struct SporeEdge {
  u : Int
  v : Int
}

///|
fn spore_edge_key(u : Int, v : Int) -> String {
  if u < v {
    "\{u}|\{v}"
  } else {
    "\{v}|\{u}"
  }
}

///|
priv struct SporeEdgeSet {
  keys : Map[String, Bool]
  edges : Array[SporeEdge]
}

///|
fn SporeEdgeSet::new() -> SporeEdgeSet {
  { keys: {}, edges: [] }
}

///|
fn SporeEdgeSet::add(self : SporeEdgeSet, u : Int, v : Int) -> Unit {
  if u == v {
    return
  }
  let key = spore_edge_key(u, v)
  if self.keys.contains(key) {
    return
  }
  self.keys[key] = true
  self.edges.push({ u, v })
}

///|
priv struct SporeTriangle {
  a : Int
  b : Int
  c : Int
  circumcenter : SporeVec
}

///|
fn triangle_key(a : Int, b : Int, c : Int) -> String {
  let arr = [a, b, c]
  arr.sort_by(fn(x, y) { x - y })
  "\{arr[0]}|\{arr[1]}|\{arr[2]}"
}

///|
fn SporeTriangle::new(
  a : Int,
  b : Int,
  c : Int,
  vs : Array[SporeVec],
) -> SporeTriangle {
  // Ported from elk-reference TTriangle.calculateCircumcenter().
  let va = vs[a]
  let vb = vs[b]
  let vc = vs[c]
  let ab = vb.sub(va)
  let ac = vc.sub(va)
  let bc = vc.sub(vb)
  let e = ab.x * (va.x + vb.x) + ab.y * (va.y + vb.y)
  let f = ac.x * (va.x + vc.x) + ac.y * (va.y + vc.y)
  let g = 2.0 * (ab.x * bc.y - ab.y * bc.x)
  let px = (ac.y * e - ab.y * f) / g
  let py = (ab.x * f - ac.x * e) / g
  { a, b, c, circumcenter: SporeVec::new(px, py) }
}

///|
fn SporeTriangle::edges(self : SporeTriangle) -> Array[SporeEdge] {
  [{ u: self.a, v: self.b }, { u: self.b, v: self.c }, { u: self.c, v: self.a }]
}

///|
fn SporeTriangle::contains_edge(self : SporeTriangle, e : SporeEdge) -> Bool {
  let key = spore_edge_key(e.u, e.v)
  for te in self.edges() {
    if spore_edge_key(te.u, te.v) == key {
      return true
    }
  }
  false
}

///|
fn SporeTriangle::in_circumcircle(
  self : SporeTriangle,
  v : SporeVec,
  vs : Array[SporeVec],
) -> Bool {
  // Ported from elk-reference TTriangle.inCircumcircle(KVector).
  let da = self.circumcenter.distance(vs[self.a])
  let dv = self.circumcenter.distance(v)
  fuzzy_compare(dv, da, spore_fuzziness) < 0
}

///|
fn bowyer_watson_triangulate(vertices : Array[SporeVec]) -> Array[SporeEdge] {
  // Ported from elk-reference BowyerWatsonTriangulation.triangulate(List<KVector>).
  if vertices.length() == 0 {
    return []
  }

  // Determine bounding box.
  let mut topleft = SporeVec::new(@double.infinity, @double.infinity)
  let mut bottomright = SporeVec::new(
    @double.neg_infinity, @double.neg_infinity,
  )
  for v in vertices {
    topleft = SporeVec::new(
      min_double(topleft.x, v.x),
      min_double(topleft.y, v.y),
    )
    bottomright = SporeVec::new(
      max_double(bottomright.x, v.x),
      max_double(bottomright.y, v.y),
    )
  }
  let size = bottomright.sub(topleft)

  // Super-triangle.
  let wiggleroom = 50.0
  let sa = SporeVec::new(
    topleft.x - wiggleroom,
    topleft.y - size.x - wiggleroom,
  )
  let sb = SporeVec::new(
    topleft.x - wiggleroom,
    bottomright.y + size.x + wiggleroom,
  )
  let sc = SporeVec::new(
    bottomright.x + size.y / 2.0 + wiggleroom,
    topleft.y + size.y / 2.0,
  )

  // Work on an extended vertex array to keep indices stable.
  let vs = vertices.copy()
  let super_a = vs.length()
  vs.push(sa)
  let super_b = vs.length()
  vs.push(sb)
  let super_c = vs.length()
  vs.push(sc)
  let triangulation : Map[String, SporeTriangle] = {}
  let super_triangle = SporeTriangle::new(super_a, super_b, super_c, vs)
  triangulation[triangle_key(super_a, super_b, super_c)] = super_triangle
  for vi in 0..<vertices.length() {
    let vertex = vs[vi]

    // Gather invalid triangles.
    let invalid_keys : Array[String] = []
    for k, t in triangulation {
      if t.in_circumcircle(vertex, vs) {
        invalid_keys.push(k)
      }
    }

    // Calculate boundary of invalid triangles.
    let boundary = SporeEdgeSet::new()
    for k in invalid_keys {
      let tri = triangulation[k]
      for e in tri.edges() {
        let mut on_boundary = true
        for ok in invalid_keys {
          if ok == k {
            continue
          }
          let other = triangulation[ok]
          if other.contains_edge(e) {
            on_boundary = false
            break
          }
        }
        if on_boundary {
          boundary.add(e.u, e.v)
        }
      }
    }

    // Remove invalid triangles.
    for k in invalid_keys {
      triangulation.remove(k)
    }

    // Triangulate boundary.
    for e in boundary.edges {
      let tri = SporeTriangle::new(vi, e.u, e.v, vs)
      triangulation[triangle_key(tri.a, tri.b, tri.c)] = tri
    }
  }

  // Convert triangulation to set of edges.
  let edges = SporeEdgeSet::new()
  for _, tri in triangulation {
    for e in tri.edges() {
      edges.add(e.u, e.v)
    }
  }

  // Remove edges connected to super triangle.
  let result : Array[SporeEdge] = []
  for e in edges.edges {
    if e.u == super_a ||
      e.u == super_b ||
      e.u == super_c ||
      e.v == super_a ||
      e.v == super_b ||
      e.v == super_c {
      continue
    }
    result.push(e)
  }
  result
}

///|
priv struct SporeTree {
  node : Int
  children : Array[SporeTree]
}

///|
fn SporeTree::new(n : Int) -> SporeTree {
  { node: n, children: [] }
}

///|
fn spore_cost(
  nodes : Array[SporeNode],
  preferred_root : Int?,
  e : SporeEdge,
  mode : Int,
) -> Double {
  // mode matches SpanningTreeCostFunction enum order in elk-reference.
  let u = e.u
  let v = e.v
  let nu = nodes[u]
  let nv = nodes[v]
  match mode {
    0 => nu.original_vertex.distance(nv.original_vertex) // CENTER_DISTANCE
    1 => // CIRCLE_UNDERLAP
      nu.original_vertex.distance(nv.original_vertex) -
      nu.original_vertex.distance(nu.rect.position()) -
      nv.original_vertex.distance(nv.rect.position())
    2 => nu.underlap(nv) // RECTANGLE_UNDERLAP
    3 => { // INVERTED_OVERLAP
      let dist = shortest_distance(nu.rect, nv.rect)
      if dist >= 0.0 {
        dist
      } else {
        let s = nv.rect.center().sub(nu.rect.center()).length()
        -((spore_overlap(nu.rect, nv.rect) - 1.0) * s)
      }
    }
    4 => // MINIMUM_ROOT_DISTANCE
      match preferred_root {
        Some(r) => {
          let rv = nodes[r].vertex
          min_double(
            nu.original_vertex.distance(rv),
            nv.original_vertex.distance(rv),
          )
        }
        None => @double.infinity
      }
    _ => nu.original_vertex.distance(nv.original_vertex)
  }
}

///|
fn naive_min_st(
  node_count : Int,
  edges : Array[SporeEdge],
  root : Int,
  nodes : Array[SporeNode],
  preferred_root : Int?,
  cost_mode : Int,
) -> SporeTree {
  // Ported from elk-reference NaiveMinST.createSpanningTree.
  if node_count == 0 {
    return SporeTree::new(root)
  }
  let weights : Array[Double] = []
  for e in edges {
    weights.push(spore_cost(nodes, preferred_root, e, cost_mode))
  }
  // Keep a stable index list and sort by weight.
  let order : Array[Int] = []
  for i in 0..<edges.length() {
    order.push(i)
  }
  order.sort_by(fn(i, j) -> Int {
    let wi = weights[i]
    let wj = weights[j]
    if wi < wj {
      -1
    } else if wi > wj {
      1
    } else {
      // Tie-break deterministically to emulate LinkedHashSet order on sorted list.
      let ei = edges[i]
      let ej = edges[j]
      if ei.u != ej.u {
        ei.u - ej.u
      } else {
        ei.v - ej.v
      }
    }
  })
  let in_tree : Array[Bool] = []
  let parent : Array[Int?] = []
  for _ in 0..<node_count {
    in_tree.push(false)
    parent.push(None)
  }
  in_tree[root] = true
  let available : Array[Bool] = []
  for _ in 0..<edges.length() {
    available.push(true)
  }
  while true {
    let mut next_edge_index : Int? = None
    let mut next_node : Int = 0
    let mut node_in_tree : Int = 0
    for idx in order {
      if !available[idx] {
        continue
      }
      let e = edges[idx]
      if in_tree[e.u] && !in_tree[e.v] {
        next_edge_index = Some(idx)
        next_node = e.v
        node_in_tree = e.u
        break
      }
      if in_tree[e.v] && !in_tree[e.u] {
        next_edge_index = Some(idx)
        next_node = e.u
        node_in_tree = e.v
        break
      }
    }
    match next_edge_index {
      None => break
      Some(ei) => {
        parent[next_node] = Some(node_in_tree)
        in_tree[next_node] = true
        available[ei] = false
      }
    }
  }

  // Build children adjacency from parent[].
  let children : Array[Array[Int]] = []
  for _ in 0..<node_count {
    children.push([])
  }
  for i in 0..<node_count {
    match parent[i] {
      Some(p) => children[p].push(i)
      None => ()
    }
  }
  for i in 0..<node_count {
    children[i].sort_by(fn(a, b) { a - b })
  }
  fn build(n : Int, children : Array[Array[Int]]) -> SporeTree {
    let t = SporeTree::new(n)
    for c in children[n] {
      t.children.push(build(c, children))
    }
    t
  }

  build(root, children)
}

///|
priv struct SporeTimestamp {
  node : Int
  low : Bool
}

///|
fn scanline_overlap_edges(nodes : Array[SporeNode]) -> Array[SporeEdge] {
  // Ported from elk-reference ScanlineOverlapCheck.sweep.
  let points : Array[SporeTimestamp] = []
  for i, _ in nodes {
    points.push({ node: i, low: true })
    points.push({ node: i, low: false })
  }
  points.sort_by(fn(a, b) -> Int {
    let na = nodes[a.node]
    let nb = nodes[b.node]
    let mut y1 = na.rect.y
    if !a.low {
      y1 = y1 + na.rect.height
    }
    let mut y2 = nb.rect.y
    if !b.low {
      y2 = y2 + nb.rect.height
    }
    let cmp = y1.compare(y2)
    if cmp != 0 {
      cmp
    } else if !a.low && b.low {
      -1
    } else if !b.low && a.low {
      1
    } else {
      0
    }
  })
  let overlaps = SporeEdgeSet::new()
  let intervals : Array[Int] = []
  fn interval_key(
    nodes : Array[SporeNode],
    idx : Int,
  ) -> (Double, Double, Double) {
    let n = nodes[idx]
    (n.rect.x, n.original_vertex.x, n.original_vertex.y)
  }

  fn interval_sort(nodes : Array[SporeNode], a : Int, b : Int) -> Int {
    let (ax, acx, acy) = interval_key(nodes, a)
    let (bx, bcx, bcy) = interval_key(nodes, b)
    if ax < bx {
      -1
    } else if ax > bx {
      1
    } else if acx < bcx {
      -1
    } else if acx > bcx {
      1
    } else if acy < bcy {
      -1
    } else if acy > bcy {
      1
    } else {
      0
    }
  }

  fn overlap_x(nodes : Array[SporeNode], a : Int, b : Int) -> Bool {
    let n1 = nodes[a]
    let n2 = nodes[b]
    fuzzy_compare(n1.rect.x, n2.rect.x + n2.rect.width, spore_fuzziness) < 0 &&
    fuzzy_compare(n2.rect.x, n1.rect.x + n1.rect.width, spore_fuzziness) < 0
  }

  fn insert_sorted(
    nodes : Array[SporeNode],
    arr : Array[Int],
    v : Int,
  ) -> Unit {
    arr.push(v)
    arr.sort_by(fn(a, b) { interval_sort(nodes, a, b) })
  }

  fn delete_value(arr : Array[Int], v : Int) -> Unit {
    let mut k = 0
    for i in 0..<arr.length() {
      if arr[i] != v {
        arr[k] = arr[i]
        k = k + 1
      }
    }
    arr.truncate(k)
  }

  for p in points {
    if p.low {
      insert_sorted(nodes, intervals, p.node)
      let mut overlaps_found = false
      for other in intervals {
        if other == p.node {
          continue
        }
        if overlap_x(nodes, p.node, other) {
          overlaps.add(p.node, other)
          overlaps_found = true
        } else if overlaps_found {
          break
        }
      }
    } else {
      delete_value(intervals, p.node)
    }
  }
  overlaps.edges
}

///|
fn choose_center_root(
  nodes : Array[SporeNode],
  root_x : Double,
  root_y : Double,
  root_w : Double,
  root_h : Double,
) -> Int? {
  if nodes.is_empty() {
    return None
  }
  let center = SporeVec::new(root_x + root_w * 0.5, root_y + root_h * 0.5)
  let mut closest = @double.infinity
  let mut best : Int = 0
  for i, n in nodes {
    let d = n.original_vertex.distance(center)
    if d < closest {
      closest = d
      best = i
    }
  }
  Some(best)
}

///|
fn update_graph_nodes_for_next_iteration(nodes : Array[SporeNode]) -> Unit {
  for n in nodes {
    let c = n.rect.center()
    n.original_vertex = c
    n.vertex = c
  }
}

///|
fn apply_positions_and_padding(
  root : ElkNode,
  nodes : Array[SporeNode],
  padding : ElkPadding,
) -> Unit {
  let mut min_x = @double.infinity
  let mut min_y = @double.infinity
  let mut max_x = @double.neg_infinity
  let mut max_y = @double.neg_infinity
  for i in 0..<nodes.length() {
    let n = nodes[i]
    let child = root.children[i]
    child.x = n.rect.x
    child.y = n.rect.y
    min_x = min_double(min_x, child.x)
    min_y = min_double(min_y, child.y)
    max_x = max_double(max_x, child.x + child.width)
    max_y = max_double(max_y, child.y + child.height)
  }
  if min_x == @double.infinity {
    root.width = 0.0
    root.height = 0.0
    return
  }
  root.width = max_x - min_x + padding.left + padding.right
  root.height = max_y - min_y + padding.top + padding.bottom
  let dx = -min_x + padding.left
  let dy = -min_y + padding.top
  for child in root.children {
    child.x = child.x + dx
    child.y = child.y + dy
  }
  // Keep edge routing consistent with elk-reference: straight sections after translation.
  route_edges_straight(root)
}

///|
fn grow_tree(nodes : Array[SporeNode], tree : SporeTree) -> Bool {
  // Ported from elk-reference GrowTreePhase.growAt.
  let mut overlaps_existed = false
  fn rec(
    nodes : Array[SporeNode],
    t : SporeTree,
    overlaps_existed : Ref[Bool],
  ) -> Unit {
    let r = nodes[t.node]
    for ctree in t.children {
      let c = nodes[ctree.node]
      // Update child by parent's translation.
      c.translate(r.vertex.sub(r.original_vertex))
      let t_factor = spore_overlap(r.rect, c.rect)
      if t_factor > 1.0 {
        overlaps_existed.val = true
      }
      c.set_center_position(
        r.vertex.add(c.original_vertex.sub(r.original_vertex).scale(t_factor)),
      )
      rec(nodes, ctree, overlaps_existed)
    }
  }

  let flag : Ref[Bool] = { val: false }
  rec(nodes, tree, flag)
  overlaps_existed = flag.val
  overlaps_existed
}

///|
fn depth_first_compact(
  tree : SporeTree,
  nodes : Array[SporeNode],
  orthogonal : Bool,
) -> Unit {
  // Ported from elk-reference DepthFirstCompaction.compactTree.
  fn translate_subtree(
    t : SporeTree,
    nodes : Array[SporeNode],
    v : SporeVec,
  ) -> Unit {
    nodes[t.node].translate(v)
    for c in t.children {
      translate_subtree(c, nodes, v)
    }
  }

  fn min_underlap_with_subtree(
    r_idx : Int,
    t : SporeTree,
    nodes : Array[SporeNode],
    current : Double,
    compaction_vector : SporeVec,
  ) -> Double {
    let r = nodes[r_idx]
    let mut min_underlap = current
    for child in t.children {
      let c = nodes[child.node]
      if r.touches(c) {
        if (
            fuzzy_compare(c.rect.x, r.rect.x + r.rect.width, spore_fuzziness) ==
            0 &&
            compaction_vector.x < 0.0
          ) ||
          (
            fuzzy_compare(c.rect.x + c.rect.width, r.rect.x, spore_fuzziness) ==
            0 &&
            compaction_vector.x > 0.0
          ) ||
          (
            fuzzy_compare(c.rect.y, r.rect.y + r.rect.height, spore_fuzziness) ==
            0 &&
            compaction_vector.y < 0.0
          ) ||
          (
            fuzzy_compare(c.rect.y + c.rect.height, r.rect.y, spore_fuzziness) ==
            0 &&
            compaction_vector.y > 0.0
          ) {
          min_underlap = 0.0
          break
        }
      } else {
        min_underlap = min_double(
          min_underlap,
          r.distance(c, compaction_vector),
        )
      }
      min_underlap = min_double(
        min_underlap,
        min_underlap_with_subtree(
          r_idx, child, nodes, min_underlap, compaction_vector,
        ),
      )
    }
    min_underlap
  }

  fn get_min_underlap(
    t : SporeTree,
    child : SporeTree,
    nodes : Array[SporeNode],
    current : Double,
    compaction_vector : SporeVec,
  ) -> Double {
    let mut min_u = min_double(
      current,
      min_underlap_with_subtree(
        t.node,
        child,
        nodes,
        current,
        compaction_vector,
      ),
    )
    for c in t.children {
      if c.node != child.node {
        min_u = min_double(
          min_u,
          get_min_underlap(c, child, nodes, min_u, compaction_vector),
        )
      }
    }
    min_u
  }

  fn rec(
    t : SporeTree,
    root : SporeTree,
    nodes : Array[SporeNode],
    orthogonal : Bool,
  ) -> Unit {
    for c in t.children {
      rec(c, root, nodes, orthogonal)
    }
    for child in t.children {
      let r = nodes[t.node]
      let c = nodes[child.node]
      let mut compaction_vector = r.vertex.sub(c.vertex)
      if orthogonal {
        let rt = r.rect
        let rc = c.rect
        if compaction_vector.x.abs() >= compaction_vector.y.abs() {
          compaction_vector = SporeVec::new(compaction_vector.x, 0.0)
          if rc.y + rc.height > rt.y && rc.y < rt.y + rt.height {
            let dist = max_double(
              rt.x - (rc.x + rc.width),
              rc.x - (rt.x + rt.width),
            )
            compaction_vector = compaction_vector.scale_to_length(dist)
          }
        } else {
          compaction_vector = SporeVec::new(0.0, compaction_vector.y)
          if rc.x + rc.width > rt.x && rc.x < rt.x + rt.width {
            let dist = max_double(
              rt.y - (rc.y + rc.height),
              rc.y - (rt.y + rt.height),
            )
            compaction_vector = compaction_vector.scale_to_length(dist)
          }
        }
      } else {
        compaction_vector = compaction_vector.scale_to_length(r.underlap(c))
      }
      let mut min_underlap = compaction_vector.length()
      min_underlap = get_min_underlap(
        root, child, nodes, min_underlap, compaction_vector,
      )
      compaction_vector = compaction_vector.scale_to_length(min_underlap)
      translate_subtree(child, nodes, compaction_vector)
    }
  }

  rec(tree, tree, nodes, orthogonal)
}

///|
fn build_spore_nodes(
  root : ElkNode,
  options : LayoutOptions,
) -> (Array[SporeNode], ElkPadding, Double) {
  // Ported from elk-reference ElkGraphImporter.importGraph (simplified: margins assumed 0).
  let padding = options.padding.unwrap_or(ElkPadding::uniform(8.0))
  let spacing = options.node_node_spacing.unwrap_or(8.0)
  let nodes : Array[SporeNode] = []
  // Deterministic disambiguation for identical vertices.
  let used : Map[String, Int] = {}
  for child in root.children {
    let half_w = child.width / 2.0
    let half_h = child.height / 2.0
    let mut vx = child.x + half_w
    let mut vy = child.y + half_h
    let key = "\{vx}|\{vy}"
    match used.get(key) {
      Some(k) => {
        // Mimic elk-reference's "tiny random shift", but deterministically.
        let delta = (k + 1).to_double() * 0.0005
        vx = vx + delta
        vy = vy - delta
        used[key] = k + 1
      }
      None => used[key] = 0
    }
    let v = SporeVec::new(vx, vy)
    let r = SporeRect::new(
      vx - half_w - spacing / 2.0,
      vy - half_h - spacing / 2.0,
      child.width + spacing,
      child.height + spacing,
    )
    nodes.push(SporeNode::new(v, r))
  }
  (nodes, padding, spacing)
}

///|
fn spore_overlap_layout_impl_with_scanline(
  graph : ElkNode,
  options : LayoutOptions,
  run_scanline : Bool,
) -> Unit {
  ensure_sizes(graph, options)
  let (nodes, padding, _) = build_spore_nodes(graph, options)
  if nodes.length() <= 1 {
    apply_positions_and_padding(graph, nodes, padding)
    return
  }
  let max_iterations = 64
  let preferred_root = choose_center_root(
    nodes,
    graph.x,
    graph.y,
    graph.width,
    graph.height,
  )
  let mut overlaps_existed = true
  let mut iteration = 0
  while iteration < max_iterations && overlaps_existed {
    let mut base_edges : Array[SporeEdge] = []
    if run_scanline {
      base_edges = scanline_overlap_edges(nodes)
      if base_edges.is_empty() {
        break
      }
    }
    let triangulation_edges = bowyer_watson_triangulate(
      nodes.map(fn(n) { n.original_vertex }),
    )
    // union edges
    let all_edges = SporeEdgeSet::new()
    for e in base_edges {
      all_edges.add(e.u, e.v)
    }
    for e in triangulation_edges {
      all_edges.add(e.u, e.v)
    }
    let root_idx = match preferred_root {
      Some(r) => r
      None => 0
    }
    let tree = naive_min_st(
      nodes.length(),
      all_edges.edges,
      root_idx,
      nodes,
      preferred_root,
      3,
    )
    overlaps_existed = grow_tree(nodes, tree)
    update_graph_nodes_for_next_iteration(nodes)
    iteration = iteration + 1
  }
  apply_positions_and_padding(graph, nodes, padding)
}

///|
fn spore_overlap_layout_impl(graph : ElkNode, options : LayoutOptions) -> Unit {
  // ELK default: overlapRemoval.runScanline = true
  spore_overlap_layout_impl_with_scanline(graph, options, true)
}

///|
fn spore_compaction_layout_impl(
  graph : ElkNode,
  options : LayoutOptions,
) -> Unit {
  ensure_sizes(graph, options)
  let (nodes, padding, _) = build_spore_nodes(graph, options)
  if nodes.length() <= 1 {
    apply_positions_and_padding(graph, nodes, padding)
    return
  }
  let preferred_root = choose_center_root(
    nodes,
    graph.x,
    graph.y,
    graph.width,
    graph.height,
  )
  let triangulation_edges = bowyer_watson_triangulate(
    nodes.map(fn(n) { n.original_vertex }),
  )
  let root_idx = match preferred_root {
    Some(r) => r
    None => 0
  }
  let tree = naive_min_st(
    nodes.length(),
    triangulation_edges,
    root_idx,
    nodes,
    preferred_root,
    1,
  )
  depth_first_compact(tree, nodes, false)
  apply_positions_and_padding(graph, nodes, padding)
}
