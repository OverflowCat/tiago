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
/// Improved Orthogonal Edge Routing
///
/// This module implements orthogonal edge routing.
///
/// We are incrementally porting ELK's
/// `p5edges/orthogonal/OrthogonalRoutingGenerator`.
///
/// Current parity focus:
/// - For a given layer-pair, group edges into hyperedge-segment like trunks.
/// - Assign a routing slot per segment.
/// - Compute bend points using the ELK direction strategies.

// ============================================================================
// OrthogonalRoutingGenerator (partial port)
// ============================================================================

///|
const TOLERANCE : Double = 1.0e-3

///|
priv struct LaneInfo {
  lane : Double
  split_lane : Double?
  split_coord : Double?
}

///|
priv struct RoutingLaneAssignment {
  lane_by_edge : Map[String, LaneInfo]
  slots_by_pair : Map[String, Int]
}

///|
fn default_lane_info(lane : Double) -> LaneInfo {
  { lane, split_lane: None, split_coord: None }
}

///|
fn port_key_for_edge(
  node_id : String,
  port_id : String?,
  is_source : Bool,
  collapse_implicit_ports : Bool,
) -> String {
  match port_id {
    Some(pid) =>
      // Treat implicit per-edge ports as a single hypernode endpoint for the
      // purposes of slot assignment; this matches ELK's hyperedge behavior and
      // keeps slot counts stable for spacing.
      if collapse_implicit_ports && (pid.contains("|auto|") || pid.contains("|hier|")) {
        if is_source {
          "n:" + node_id + ":out"
        } else {
          "n:" + node_id + ":in"
        }
      } else {
        "p:" + node_id + ":" + pid
      }
    None =>
      if is_source {
        "n:" + node_id + ":out"
      } else {
        "n:" + node_id + ":in"
      }
  }
}

///|
const CONFLICT_THRESHOLD_FACTOR : Double = 0.5

///|
const CRITICAL_CONFLICT_THRESHOLD_FACTOR : Double = 0.2

///|
const CONFLICT_PENALTY : Int = 1

///|
const CROSSING_PENALTY : Int = 16

///|
const CRITICAL_CONFLICTS_DETECTED : Int = -1

///|
priv enum HyperDependencyType {
  Regular
  Critical
}

///|
priv struct HyperEdgeDependency {
  dep_type : HyperDependencyType
  mut source : Int
  mut target : Int
  weight : Int
}

///|
priv struct HyperEdgeSegment {
  mut incoming_coords : Array[Double]
  mut outgoing_coords : Array[Double]
  mut start_pos : Double
  mut end_pos : Double
  mut routing_slot : Int
  mut outgoing_deps : Array[Int]
  mut incoming_deps : Array[Int]

  // Values used by cycle breaking / numbering.
  mut in_weight : Int
  mut out_weight : Int
  mut critical_in_weight : Int
  mut critical_out_weight : Int
  mut mark : Int
  mut split_partner : Int?
  mut split_by : Int?
}

///|
fn HyperEdgeSegment::new() -> HyperEdgeSegment {
  {
    incoming_coords: [],
    outgoing_coords: [],
    start_pos: 0.0,
    end_pos: 0.0,
    routing_slot: 0,
    outgoing_deps: [],
    incoming_deps: [],
    in_weight: 0,
    out_weight: 0,
    critical_in_weight: 0,
    critical_out_weight: 0,
    mark: 0,
    split_partner: None,
    split_by: None,
  }
}

///|
priv struct PRNG {
  mut state : Int
}

///|
fn PRNG::new(seed : Int) -> PRNG {
  { state: (seed & 0x7fffffff) + 1 }
}

///|
fn PRNG::next_int(self : PRNG, bound : Int) -> Int {
  if bound <= 0 {
    return 0
  }
  self.state = (self.state * 1103515245 + 12345) & 0x7fffffff
  self.state % bound
}

///|
priv struct FreeArea {
  start_pos : Double
  end_pos : Double
  size : Double
}

///|
priv struct AreaRating {
  mut dependencies : Int
  mut crossings : Int
}

///|
fn segment_length(seg : HyperEdgeSegment) -> Double {
  seg.end_pos - seg.start_pos
}

///|
fn segment_represents_hyperedge(seg : HyperEdgeSegment) -> Bool {
  seg.incoming_coords.length() + seg.outgoing_coords.length() > 2
}

///|
#warnings("-unused_value")
fn segment_is_dummy(seg : HyperEdgeSegment) -> Bool {
  seg.split_partner is Some(_) && seg.split_by is None
}

///|
fn segment_simulate_split(
  seg : HyperEdgeSegment,
) -> (HyperEdgeSegment, HyperEdgeSegment) {
  let a = HyperEdgeSegment::new()
  let b = HyperEdgeSegment::new()
  for v in seg.incoming_coords {
    a.incoming_coords.push(v)
  }
  for v in seg.outgoing_coords {
    b.outgoing_coords.push(v)
  }
  a.split_by = seg.split_by
  a.split_partner = Some(0)
  b.split_partner = Some(0)

  // extents will be recomputed by the caller
  (a, b)
}

///|
fn segment_split_at(
  seg_idx : Int,
  split_pos : Double,
  segments : Array[HyperEdgeSegment],
  deps : Array[HyperEdgeDependency],
) -> Int {
  // Equivalent to ELK HyperEdgeSegment.splitAt.
  // Returns the new split partner index.

  let new_seg = HyperEdgeSegment::new()
  let new_idx = segments.length()
  segments.push(new_seg)

  // Move all outgoing coordinates over.
  for v in segments[seg_idx].outgoing_coords {
    segments[new_idx].outgoing_coords.push(v)
  }
  segments[seg_idx].outgoing_coords.clear()

  // Link the two.
  segments[seg_idx].outgoing_coords.push(split_pos)
  segments[new_idx].incoming_coords.push(split_pos)
  segments[seg_idx].split_partner = Some(new_idx)
  segments[new_idx].split_partner = Some(seg_idx)
  // Dummy segment has no split_by.
  segments[new_idx].split_by = None

  // Recompute extents.
  fn sorted_unique(values : Array[Double]) -> Array[Double] {
    values.sort()
    let out : Array[Double] = []
    for v in values {
      if out.is_empty() || out[out.length() - 1] != v {
        out.push(v)
      }
    }
    out
  }

  fn recompute(seg : HyperEdgeSegment) -> Unit {
    seg.incoming_coords = sorted_unique(seg.incoming_coords)
    seg.outgoing_coords = sorted_unique(seg.outgoing_coords)
    let mut start : Double? = None
    let mut end : Double? = None
    if !seg.incoming_coords.is_empty() {
      let s = seg.incoming_coords[0]
      let e = seg.incoming_coords[seg.incoming_coords.length() - 1]
      start = Some(
        match start {
          Some(v) => min_double(v, s)
          None => s
        },
      )
      end = Some(
        match end {
          Some(v) => max_double(v, e)
          None => e
        },
      )
    }
    if !seg.outgoing_coords.is_empty() {
      let s = seg.outgoing_coords[0]
      let e = seg.outgoing_coords[seg.outgoing_coords.length() - 1]
      start = Some(
        match start {
          Some(v) => min_double(v, s)
          None => s
        },
      )
      end = Some(
        match end {
          Some(v) => max_double(v, e)
          None => e
        },
      )
    }
    seg.start_pos = start.unwrap_or(0.0)
    seg.end_pos = end.unwrap_or(0.0)
  }

  recompute(segments[seg_idx])
  recompute(segments[new_idx])

  // Clear dependencies on the original segment (removes from both ends).
  while !segments[seg_idx].incoming_deps.is_empty() {
    let dep_id = segments[seg_idx].incoming_deps[0]
    let dep = deps[dep_id]
    if dep.source >= 0 {
      segments[dep.source].outgoing_deps = segments[dep.source].outgoing_deps.filter(fn(
          i,
        ) {
          i != dep_id
        },
      )
    }
    segments[seg_idx].incoming_deps.remove(0) |> ignore
    dep.source = -1
    dep.target = -1
  }
  while !segments[seg_idx].outgoing_deps.is_empty() {
    let dep_id = segments[seg_idx].outgoing_deps[0]
    let dep = deps[dep_id]
    if dep.target >= 0 {
      segments[dep.target].incoming_deps = segments[dep.target].incoming_deps.filter(fn(
          i,
        ) {
          i != dep_id
        },
      )
    }
    segments[seg_idx].outgoing_deps.remove(0) |> ignore
    dep.source = -1
    dep.target = -1
  }
  new_idx
}

///|
fn segment_lane_for_layer_pair(
  edges : Array[LEdge],
  graph : LGraph,
  direction : LayoutDirection,
  edge_edge_spacing : Double,
  edge_node_spacing : Double,
  random_seed : Int,
  collapse_implicit_ports : Bool,
) -> RoutingLaneAssignment {
  // Partial ELK port: build hyperedge segments per layer boundary, create
  // dependencies, break non-critical cycles, then assign routing slots by
  // topological numbering.

  // Group edges by layer pair.
  // Keep a sorted key list for determinism.
  let buckets : Map[String, Array[LEdge]] = {}
  let bucket_keys : Array[String] = []
  for e in edges {
    // Long-edge split dummies should not influence routing slot allocation.
    // ELK's orthogonal router operates on the original edges; including these
    // dummies inflates between-layer spacing (notably for sql_table long edges).
    if e.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    match (graph.get_node(e.source_id), graph.get_node(e.target_id)) {
      (Some(src), Some(tgt)) => {
        if src.node_type is LongEdgeDummy || tgt.node_type is LongEdgeDummy {
          continue
        }
        if src.layer == tgt.layer {
          continue
        }
        let lo = @cmp.minimum(src.layer, tgt.layer)
        let hi = @cmp.maximum(src.layer, tgt.layer)
        let key = lo.to_string() + "-" + hi.to_string()
        if !buckets.contains(key) {
          buckets[key] = []
          bucket_keys.push(key)
        }
        buckets[key].push(e)
      }
      _ => ()
    }
  }

  // Helper: union-find for port keys.
  fn uf_find(parent : Map[String, String], x : String) -> String {
    let p = parent.get(x).unwrap_or(x)
    if p == x {
      x
    } else {
      let root = uf_find(parent, p)
      parent[x] = root
      root
    }
  }

  fn uf_union(parent : Map[String, String], a : String, b : String) -> Unit {
    let ra = uf_find(parent, a)
    let rb = uf_find(parent, b)
    if ra != rb {
      parent[ra] = rb
    }
  }

  fn routing_source_side(direction : LayoutDirection) -> ElkPortSide {
    match direction {
      Right => East
      Left => West
      Down => South
      Up => North
      Undefined => East
    }
  }

  fn routing_target_side(direction : LayoutDirection) -> ElkPortSide {
    match direction {
      Right => West
      Left => East
      Down => North
      Up => South
      Undefined => West
    }
  }

  fn default_anchor(
    node : LNode,
    direction : LayoutDirection,
    is_source : Bool,
  ) -> (Double, Double) {
    let cx = node.x + node.width / 2.0
    let cy = node.y + node.height / 2.0
    match direction {
      Down => if is_source { (cx, node.y + node.height) } else { (cx, node.y) }
      Up => if is_source { (cx, node.y) } else { (cx, node.y + node.height) }
      Right => if is_source { (node.x + node.width, cy) } else { (node.x, cy) }
      Left => if is_source { (node.x, cy) } else { (node.x + node.width, cy) }
      Undefined =>
        if is_source {
          (node.x + node.width, cy)
        } else {
          (node.x, cy)
        }
    }
  }

  fn anchor_with_port_and_side(
    node : LNode,
    port_id : String?,
    direction : LayoutDirection,
    is_source : Bool,
    fallback_side : ElkPortSide,
  ) -> (Double, Double, ElkPortSide) {
    let default_side = if fallback_side is Undefined {
      if is_source {
        routing_source_side(direction)
      } else {
        routing_target_side(direction)
      }
    } else {
      fallback_side
    }
    fn anchor_for_side(
      node : LNode,
      side : ElkPortSide,
      direction : LayoutDirection,
      is_source : Bool,
    ) -> (Double, Double) {
      let cx = node.x + node.width / 2.0
      let cy = node.y + node.height / 2.0
      match side {
        North => (cx, node.y)
        South => (cx, node.y + node.height)
        West => (node.x, cy)
        East => (node.x + node.width, cy)
        Undefined => default_anchor(node, direction, is_source)
      }
    }

    match port_id {
      Some(pid) => {
        for port in node.ports {
          if port.id == pid {
            let side = if port.side is Undefined {
              default_side
            } else {
              port.side
            }
            let has_size = port.width > 0.0 || port.height > 0.0
            if has_size {
              return (
                node.x + port.x + port.width / 2.0,
                node.y + port.y + port.height / 2.0,
                side,
              )
            }
            let has_pos = port.x != 0.0 || port.y != 0.0
            let border = port.properties.get_double_or(
              "diago.layered.portBorderOffset", 0.0,
            )
            let (ax, ay) = match side {
              North =>
                if has_pos {
                  (node.x + port.x, node.y + border)
                } else {
                  (node.x + node.width / 2.0, node.y + border)
                }
              South =>
                if has_pos {
                  (node.x + port.x, node.y + node.height - border)
                } else {
                  (node.x + node.width / 2.0, node.y + node.height - border)
                }
              West =>
                if has_pos {
                  (node.x + border, node.y + port.y)
                } else {
                  (node.x + border, node.y + node.height / 2.0)
                }
              East =>
                if has_pos {
                  (node.x + node.width - border, node.y + port.y)
                } else {
                  (node.x + node.width - border, node.y + node.height / 2.0)
                }
              Undefined =>
                anchor_for_side(node, default_side, direction, is_source)
            }
            return (ax, ay, side)
          }
        }
        let (ax, ay) = anchor_for_side(node, default_side, direction, is_source)
        (ax, ay, default_side)
      }
      None => {
        let (ax, ay) = anchor_for_side(node, default_side, direction, is_source)
        (ax, ay, default_side)
      }
    }
  }

  fn nested_anchor_for_edge(
    edge : LEdge,
    node : LNode,
    is_source : Bool,
    fallback_side : ElkPortSide,
  ) -> (Double, Double)? {
    if !edge.properties.get_bool_or("diago.layered.crossHierarchy", false) {
      return None
    }
    let key = if is_source {
      "diago.layered.originalSourceId"
    } else {
      "diago.layered.originalTargetId"
    }
    let orig_id = edge.properties.get_string(key)
    guard orig_id is Some(child_id) else { return None }
    if child_id == node.id {
      return None
    }
    match node.nested_graph {
      Some(nested) =>
        match nested.get_node(child_id) {
          Some(child) => {
            let cx = child.x + child.width / 2.0
            let cy = child.y + child.height / 2.0
            let anchor = match fallback_side {
              North => (node.x + cx, node.y)
              South => (node.x + cx, node.y + node.height)
              West => (node.x, node.y + cy)
              East => (node.x + node.width, node.y + cy)
              Undefined =>
                (node.x + node.width / 2.0, node.y + node.height / 2.0)
            }
            Some(anchor)
          }
          None => None
        }
      None => None
    }
  }

  fn sorted_unique(values : Array[Double]) -> Array[Double] {
    values.sort()
    let out : Array[Double] = []
    for v in values {
      if out.is_empty() || out[out.length() - 1] != v {
        out.push(v)
      }
    }
    out
  }

  fn segment_recompute_extent(seg : HyperEdgeSegment) -> Unit {
    seg.incoming_coords = sorted_unique(seg.incoming_coords)
    seg.outgoing_coords = sorted_unique(seg.outgoing_coords)
    let mut start : Double? = None
    let mut end : Double? = None
    if !seg.incoming_coords.is_empty() {
      let s = seg.incoming_coords[0]
      let e = seg.incoming_coords[seg.incoming_coords.length() - 1]
      start = Some(
        match start {
          Some(v) => min_double(v, s)
          None => s
        },
      )
      end = Some(
        match end {
          Some(v) => max_double(v, e)
          None => e
        },
      )
    }
    if !seg.outgoing_coords.is_empty() {
      let s = seg.outgoing_coords[0]
      let e = seg.outgoing_coords[seg.outgoing_coords.length() - 1]
      start = Some(
        match start {
          Some(v) => min_double(v, s)
          None => s
        },
      )
      end = Some(
        match end {
          Some(v) => max_double(v, e)
          None => e
        },
      )
    }
    seg.start_pos = start.unwrap_or(0.0)
    seg.end_pos = end.unwrap_or(0.0)
  }

  fn segment_is_straight(seg : HyperEdgeSegment) -> Bool {
    (seg.start_pos - seg.end_pos).abs() < TOLERANCE
  }

  fn minimum_difference(values : Array[Double]) -> Double {
    let nums = sorted_unique(values)
    if nums.length() < 2 {
      return 1.0e18
    }
    let mut min_diff = 1.0e18
    for i = 1; i < nums.length(); i = i + 1 {
      min_diff = min_double(min_diff, nums[i] - nums[i - 1])
    }
    min_diff
  }

  fn minimum_horizontal_segment_distance(
    segments : Array[HyperEdgeSegment],
  ) -> Double {
    let incoming : Array[Double] = []
    let outgoing : Array[Double] = []
    for seg in segments {
      for v in seg.incoming_coords {
        incoming.push(v)
      }
      for v in seg.outgoing_coords {
        outgoing.push(v)
      }
    }
    min_double(minimum_difference(incoming), minimum_difference(outgoing))
  }

  // Counts conflicts, returning CRITICAL_CONFLICTS_DETECTED for overlaps.
  fn count_conflicts(
    posis1 : Array[Double],
    posis2 : Array[Double],
    conflict_threshold : Double,
    critical_conflict_threshold : Double,
  ) -> Int {
    let a = sorted_unique(posis1)
    let b = sorted_unique(posis2)
    if a.is_empty() || b.is_empty() {
      return 0
    }
    let mut conflicts = 0
    let mut i = 0
    let mut j = 0
    while i < a.length() && j < b.length() {
      let pos1 = a[i]
      let pos2 = b[j]
      if pos1 > pos2 - critical_conflict_threshold &&
        pos1 < pos2 + critical_conflict_threshold {
        return CRITICAL_CONFLICTS_DETECTED
      } else if pos1 > pos2 - conflict_threshold &&
        pos1 < pos2 + conflict_threshold {
        conflicts = conflicts + 1
      }
      if pos1 <= pos2 {
        i = i + 1
      } else {
        j = j + 1
      }
    }
    conflicts
  }

  fn count_crossings(
    posis : Array[Double],
    start : Double,
    end : Double,
  ) -> Int {
    let nums = sorted_unique(posis)
    let mut crossings = 0
    for pos in nums {
      if pos > end {
        break
      } else if pos >= start {
        crossings = crossings + 1
      }
    }
    crossings
  }

  let lane_by_edge : Map[String, LaneInfo] = {}
  let slots_by_pair : Map[String, Int] = {}
  let is_vertical = direction.is_vertical()
  bucket_keys.sort()
  let mut bucket_index = 0
  for layer_key in bucket_keys {
    let layer_edges = buckets[layer_key]
    let local_seed = random_seed + bucket_index * 10007
    bucket_index = bucket_index + 1
    // Compute startPos base lane for this boundary.
    let mut base_lane = 0.0
    if !layer_edges.is_empty() {
      let first = layer_edges[0]
      match (graph.get_node(first.source_id), graph.get_node(first.target_id)) {
        (Some(a), Some(b)) => {
          let lo = @cmp.minimum(a.layer, b.layer)
          let hi = @cmp.maximum(a.layer, b.layer)
          let scan_layer = match direction {
            Up | Left => hi
            _ => lo
          }
          let mut boundary = if is_vertical {
            if direction is Down {
              -1.0e18
            } else {
              1.0e18
            }
          } else if direction is Right {
            -1.0e18
          } else {
            1.0e18
          }
          if scan_layer >= 0 && scan_layer < graph.layers.length() {
            for node in graph.layers[scan_layer].nodes {
              if is_vertical {
                if direction is Down {
                  boundary = max_double(boundary, node.y + node.height)
                } else {
                  boundary = min_double(boundary, node.y)
                }
              } else if direction is Right {
                boundary = max_double(boundary, node.x + node.width)
              } else {
                boundary = min_double(boundary, node.x)
              }
            }
          }
          base_lane = match direction {
            Up | Left => boundary - edge_node_spacing
            _ => boundary + edge_node_spacing
          }
        }
        _ => ()
      }
    }

    // Union-find and port data for this layer boundary.
    let parent : Map[String, String] = {}
    let port_pos_sum : Map[String, Double] = {}
    let port_pos_count : Map[String, Int] = {}
    let port_is_incoming : Map[String, Bool] = {}
    let edge_src_key : Map[String, String] = {}
    let all_ports : Array[String] = []
    let source_side = routing_source_side(direction)
    fn infer_for_edge(
      src : LNode,
      tgt : LNode,
      direction : LayoutDirection,
    ) -> (ElkPortSide, ElkPortSide) {
      if src.layer < tgt.layer {
        if direction.is_vertical() {
          (South, North)
        } else {
          (East, West)
        }
      } else if src.layer > tgt.layer {
        if direction.is_vertical() {
          (North, South)
        } else {
          (West, East)
        }
      } else if direction.is_vertical() {
        if src.position < tgt.position {
          (East, West)
        } else {
          (West, East)
        }
      } else if src.position < tgt.position {
        (South, North)
      } else {
        (North, South)
      }
    }

    for e in layer_edges {
      let src_node = graph.get_node(e.source_id)
      let tgt_node = graph.get_node(e.target_id)
      guard src_node is Some(src) && tgt_node is Some(tgt) else { continue }
      let (fallback_src_side, fallback_tgt_side) = infer_for_edge(
        src, tgt, direction,
      )
      // Slot assignment should not depend on implicit per-edge port positions;
      // Slot assignment should not depend on implicit per-edge port positions;
      // use node-side endpoints for auto/hier ports to avoid inflating slot
      // counts and shifting layers.
      let slot_src_port : String? = match e.source_port_id {
        Some(pid) =>
          if collapse_implicit_ports && (pid.contains("|auto|") || pid.contains("|hier|")) {
            (None : String?)
          } else {
            Some(pid)
          }
        None => None
      }
      let slot_tgt_port : String? = match e.target_port_id {
        Some(pid) =>
          if collapse_implicit_ports && (pid.contains("|auto|") || pid.contains("|hier|")) {
            (None : String?)
          } else {
            Some(pid)
          }
        None => None
      }
      let (sx0, sy0, s_side) = anchor_with_port_and_side(
        src,
        slot_src_port,
        direction,
        true,
        fallback_src_side,
      )
      let mut sx = sx0
      let mut sy = sy0
      match nested_anchor_for_edge(e, src, true, fallback_src_side) {
        Some((nx, ny)) => {
          sx = nx
          sy = ny
        }
        None => ()
      }
      let (tx0, ty0, t_side) = anchor_with_port_and_side(
        tgt,
        slot_tgt_port,
        direction,
        false,
        fallback_tgt_side,
      )
      let mut tx = tx0
      let mut ty = ty0
      match nested_anchor_for_edge(e, tgt, false, fallback_tgt_side) {
        Some((nx, ny)) => {
          tx = nx
          ty = ny
        }
        None => ()
      }
      let mut sk = port_key_for_edge(
        e.source_id,
        e.source_port_id,
        true,
        collapse_implicit_ports,
      )
      let mut tk = port_key_for_edge(
        e.target_id,
        e.target_port_id,
        false,
        collapse_implicit_ports,
      )
      if e.properties.get_bool_or("diago.layered.crossHierarchy", false) {
        let orig_src = e.properties.get_string("diago.layered.originalSourceId")
        let orig_tgt = e.properties.get_string("diago.layered.originalTargetId")
        if e.source_port_id is None {
          match orig_src {
            Some(orig) if orig != e.source_id => sk = "h:" + orig + ":out"
            _ => ()
          }
        }
        if e.target_port_id is None {
          match (orig_src, orig_tgt) {
            (Some(os), Some(ot)) if ot == e.target_id && os != e.source_id =>
              tk = "h:" + os + ":in:" + e.target_id
            _ => ()
          }
        }
      }
      parent[sk] = sk
      parent[tk] = tk
      uf_union(parent, sk, tk)

      // Hypernode axis coordinate.
      let sk_coord = if is_vertical { sx } else { sy }
      let tk_coord = if is_vertical { tx } else { ty }
      port_pos_sum[sk] = port_pos_sum.get(sk).unwrap_or(0.0) + sk_coord
      port_pos_count[sk] = port_pos_count.get(sk).unwrap_or(0) + 1
      port_pos_sum[tk] = port_pos_sum.get(tk).unwrap_or(0.0) + tk_coord
      port_pos_count[tk] = port_pos_count.get(tk).unwrap_or(0) + 1
      port_is_incoming[sk] = s_side == source_side
      port_is_incoming[tk] = t_side == source_side
      edge_src_key[e.id] = sk
      all_ports.push(sk)
      all_ports.push(tk)
    }

    // Build segments.
    all_ports.sort()
    let unique_ports : Array[String] = []
    for p in all_ports {
      if unique_ports.is_empty() || unique_ports[unique_ports.length() - 1] != p {
        unique_ports.push(p)
      }
    }
    let segments : Array[HyperEdgeSegment] = []
    let root_to_seg : Map[String, Int] = {}
    let port_to_seg : Map[String, Int] = {}
    for p in unique_ports {
      let root = uf_find(parent, p)
      let seg_idx = match root_to_seg.get(root) {
        Some(i) => i
        None => {
          let i = segments.length()
          segments.push(HyperEdgeSegment::new())
          root_to_seg[root] = i
          i
        }
      }
      port_to_seg[p] = seg_idx
      let sum = port_pos_sum.get(p).unwrap_or(0.0)
      let cnt = port_pos_count.get(p).unwrap_or(1).to_double()
      let coord = sum / cnt
      if port_is_incoming.get(p).unwrap_or(false) {
        segments[seg_idx].incoming_coords.push(coord)
      } else {
        segments[seg_idx].outgoing_coords.push(coord)
      }
    }
    for seg in segments {
      segment_recompute_extent(seg)
      seg.routing_slot = 0
    }

    // Create dependencies.
    let deps : Array[HyperEdgeDependency] = []
    fn dep_add(
      segments : Array[HyperEdgeSegment],
      deps : Array[HyperEdgeDependency],
      dep_type : HyperDependencyType,
      source : Int,
      target : Int,
      weight : Int,
    ) -> Int {
      deps.push({ dep_type, source, target, weight })
      let id = deps.length() - 1
      segments[source].outgoing_deps.push(id)
      segments[target].incoming_deps.push(id)
      id
    }

    fn dep_remove(
      segments : Array[HyperEdgeSegment],
      deps : Array[HyperEdgeDependency],
      dep_id : Int,
    ) -> Unit {
      let dep = deps[dep_id]
      if dep.source >= 0 {
        segments[dep.source].outgoing_deps = segments[dep.source].outgoing_deps.filter(fn(
            i,
          ) {
            i != dep_id
          },
        )
      }
      if dep.target >= 0 {
        segments[dep.target].incoming_deps = segments[dep.target].incoming_deps.filter(fn(
            i,
          ) {
            i != dep_id
          },
        )
      }
      dep.source = -1
      dep.target = -1
    }

    fn dep_reverse(
      segments : Array[HyperEdgeSegment],
      deps : Array[HyperEdgeDependency],
      dep_id : Int,
    ) -> Unit {
      let dep = deps[dep_id]
      let old_source = dep.source
      let old_target = dep.target
      if old_source < 0 || old_target < 0 {
        return
      }
      segments[old_source].outgoing_deps = segments[old_source].outgoing_deps.filter(fn(
          i,
        ) {
          i != dep_id
        },
      )
      segments[old_target].incoming_deps = segments[old_target].incoming_deps.filter(fn(
          i,
        ) {
          i != dep_id
        },
      )
      dep.source = old_target
      dep.target = old_source
      segments[dep.source].outgoing_deps.push(dep_id)
      segments[dep.target].incoming_deps.push(dep_id)
    }

    fn create_dependency_if_necessary(
      segments : Array[HyperEdgeSegment],
      deps : Array[HyperEdgeDependency],
      he1 : Int,
      he2 : Int,
      conflict_threshold : Double,
      critical_conflict_threshold : Double,
    ) -> Int {
      let s1 = segments[he1]
      let s2 = segments[he2]
      if segment_is_straight(s1) || segment_is_straight(s2) {
        return 0
      }
      let conflicts1 = count_conflicts(
        s1.outgoing_coords,
        s2.incoming_coords,
        conflict_threshold,
        critical_conflict_threshold,
      )
      let conflicts2 = count_conflicts(
        s2.outgoing_coords,
        s1.incoming_coords,
        conflict_threshold,
        critical_conflict_threshold,
      )
      let critical_conflicts = conflicts1 == CRITICAL_CONFLICTS_DETECTED ||
        conflicts2 == CRITICAL_CONFLICTS_DETECTED
      let mut critical_dep_count = 0
      if critical_conflicts {
        if conflicts1 == CRITICAL_CONFLICTS_DETECTED {
          ignore(dep_add(segments, deps, Critical, he2, he1, 1))
          critical_dep_count = critical_dep_count + 1
        }
        if conflicts2 == CRITICAL_CONFLICTS_DETECTED {
          ignore(dep_add(segments, deps, Critical, he1, he2, 1))
          critical_dep_count = critical_dep_count + 1
        }
      } else {
        let mut crossings1 = 0
        crossings1 = crossings1 +
          count_crossings(s1.outgoing_coords, s2.start_pos, s2.end_pos)
        crossings1 = crossings1 +
          count_crossings(s2.incoming_coords, s1.start_pos, s1.end_pos)
        let mut crossings2 = 0
        crossings2 = crossings2 +
          count_crossings(s2.outgoing_coords, s1.start_pos, s1.end_pos)
        crossings2 = crossings2 +
          count_crossings(s1.incoming_coords, s2.start_pos, s2.end_pos)
        let dep_value1 = CONFLICT_PENALTY * conflicts1 +
          CROSSING_PENALTY * crossings1
        let dep_value2 = CONFLICT_PENALTY * conflicts2 +
          CROSSING_PENALTY * crossings2
        if dep_value1 < dep_value2 {
          ignore(
            dep_add(segments, deps, Regular, he1, he2, dep_value2 - dep_value1),
          )
        } else if dep_value1 > dep_value2 {
          ignore(
            dep_add(segments, deps, Regular, he2, he1, dep_value1 - dep_value2),
          )
        } else if dep_value1 > 0 && dep_value2 > 0 {
          ignore(dep_add(segments, deps, Regular, he1, he2, 0))
          ignore(dep_add(segments, deps, Regular, he2, he1, 0))
        }
      }
      critical_dep_count
    }

    // Compute thresholds.
    let critical_conflict_threshold = CRITICAL_CONFLICT_THRESHOLD_FACTOR *
      minimum_horizontal_segment_distance(segments)
    let conflict_threshold = CONFLICT_THRESHOLD_FACTOR * edge_edge_spacing
    let mut critical_dep_count = 0
    for i = 0; i < segments.length() - 1; i = i + 1 {
      for j = i + 1; j < segments.length(); j = j + 1 {
        critical_dep_count = critical_dep_count +
          create_dependency_if_necessary(
            segments, deps, i, j, conflict_threshold, critical_conflict_threshold,
          )
      }
    }

    // Break non-critical cycles (critical cycles not yet split).
    fn detect_cycles(
      segments : Array[HyperEdgeSegment],
      deps : Array[HyperEdgeDependency],
      critical_only : Bool,
      prng : PRNG,
    ) -> Array[Int] {
      let sources : Array[Int] = []
      let sinks : Array[Int] = []

      // Initialize.
      let mut next_mark = -1
      for i = 0; i < segments.length(); i = i + 1 {
        let seg = segments[i]
        seg.mark = next_mark
        next_mark = next_mark - 1
        let mut critical_in = 0
        let mut critical_out = 0
        for dep_id in seg.incoming_deps {
          let dep = deps[dep_id]
          if dep.dep_type is Critical {
            critical_in = critical_in + dep.weight
          }
        }
        for dep_id in seg.outgoing_deps {
          let dep = deps[dep_id]
          if dep.dep_type is Critical {
            critical_out = critical_out + dep.weight
          }
        }
        let in_w = if critical_only {
          critical_in
        } else {
          seg.incoming_deps.fold(init=0, fn(acc, dep_id) {
            acc + deps[dep_id].weight
          })
        }
        let out_w = if critical_only {
          critical_out
        } else {
          seg.outgoing_deps.fold(init=0, fn(acc, dep_id) {
            acc + deps[dep_id].weight
          })
        }
        seg.in_weight = in_w
        seg.out_weight = out_w
        seg.critical_in_weight = critical_in
        seg.critical_out_weight = critical_out
        if out_w == 0 {
          sinks.push(i)
        } else if in_w == 0 {
          sources.push(i)
        }
      }

      // Compute linear ordering marks.
      let unprocessed : Array[Int] = []
      for i = 0; i < segments.length(); i = i + 1 {
        unprocessed.push(i)
      }
      fn remove_from(arr : Array[Int], value : Int) -> Unit {
        for i = 0; i < arr.length(); i = i + 1 {
          if arr[i] == value {
            arr.remove(i) |> ignore
            break
          }
        }
      }

      fn update_neighbors(
        idx : Int,
        segments : Array[HyperEdgeSegment],
        deps : Array[HyperEdgeDependency],
        sources : Array[Int],
        sinks : Array[Int],
        critical_only : Bool,
      ) -> Unit {
        // following nodes
        for dep_id in segments[idx].outgoing_deps {
          let dep = deps[dep_id]
          if critical_only && dep.dep_type is Regular {
            continue
          }
          let target = dep.target
          if target >= 0 && segments[target].mark < 0 && dep.weight > 0 {
            segments[target].in_weight = segments[target].in_weight - dep.weight
            if dep.dep_type is Critical {
              segments[target].critical_in_weight = segments[target].critical_in_weight -
                dep.weight
            }
            if segments[target].in_weight <= 0 &&
              segments[target].out_weight > 0 {
              sources.push(target)
            }
          }
        }

        // preceding nodes
        for dep_id in segments[idx].incoming_deps {
          let dep = deps[dep_id]
          if critical_only && dep.dep_type is Regular {
            continue
          }
          let source = dep.source
          if source >= 0 && segments[source].mark < 0 && dep.weight > 0 {
            segments[source].out_weight = segments[source].out_weight -
              dep.weight
            if dep.dep_type is Critical {
              segments[source].critical_out_weight = segments[source].critical_out_weight -
                dep.weight
            }
            if segments[source].out_weight <= 0 &&
              segments[source].in_weight > 0 {
              sinks.push(source)
            }
          }
        }
      }

      let mark_base = segments.length()
      let mut next_sink_mark = mark_base - 1
      let mut next_source_mark = mark_base + 1
      while !unprocessed.is_empty() {
        while !sinks.is_empty() {
          let sink = sinks.remove(0)
          remove_from(unprocessed, sink)
          segments[sink].mark = next_sink_mark
          next_sink_mark = next_sink_mark - 1
          update_neighbors(sink, segments, deps, sources, sinks, critical_only)
        }
        while !sources.is_empty() {
          let source = sources.remove(0)
          remove_from(unprocessed, source)
          segments[source].mark = next_source_mark
          next_source_mark = next_source_mark + 1
          update_neighbors(
            source, segments, deps, sources, sinks, critical_only,
          )
        }
        if unprocessed.is_empty() {
          break
        }

        // Find segments with maximal outflow.
        let max_segments : Array[Int] = []
        let mut max_outflow = -0x7fffffff
        for idx in unprocessed {
          let seg = segments[idx]
          if !critical_only &&
            seg.critical_out_weight > 0 &&
            seg.critical_in_weight <= 0 {
            max_segments.clear()
            max_segments.push(idx)
            break
          }
          let outflow = seg.out_weight - seg.in_weight
          if outflow >= max_outflow {
            if outflow > max_outflow {
              max_segments.clear()
              max_outflow = outflow
            }
            max_segments.push(idx)
          }
        }
        if !max_segments.is_empty() {
          let choice = max_segments[prng.next_int(max_segments.length())]
          remove_from(unprocessed, choice)
          segments[choice].mark = next_source_mark
          next_source_mark = next_source_mark + 1
          update_neighbors(
            choice, segments, deps, sources, sinks, critical_only,
          )
        }
      }

      // shift sink marks
      let shift_base = segments.length() + 1
      for seg in segments {
        if seg.mark < mark_base {
          seg.mark = seg.mark + shift_base
        }
      }

      // collect left-pointing dependencies
      let result : Array[Int] = []
      for i = 0; i < segments.length(); i = i + 1 {
        for dep_id in segments[i].outgoing_deps {
          let dep = deps[dep_id]
          if critical_only && dep.dep_type is Regular {
            continue
          }
          if dep.target >= 0 && segments[i].mark > segments[dep.target].mark {
            result.push(dep_id)
          }
        }
      }
      result
    }

    fn center2(p1 : Double, p2 : Double) -> Double {
      (p1 + p2) / 2.0
    }

    fn center_segment(seg : HyperEdgeSegment) -> Double {
      center2(seg.start_pos, seg.end_pos)
    }

    fn center_area(area : FreeArea) -> Double {
      center2(area.start_pos, area.end_pos)
    }

    fn find_free_areas(
      segments : Array[HyperEdgeSegment],
      critical_conflict_threshold : Double,
    ) -> Array[FreeArea] {
      let coords : Array[Double] = []
      for seg in segments {
        for v in seg.incoming_coords {
          coords.push(v)
        }
        for v in seg.outgoing_coords {
          coords.push(v)
        }
      }
      coords.sort()
      let uniq : Array[Double] = []
      for v in coords {
        if uniq.is_empty() || uniq[uniq.length() - 1] != v {
          uniq.push(v)
        }
      }
      let free_areas : Array[FreeArea] = []
      for i = 1; i < uniq.length(); i = i + 1 {
        if uniq[i] - uniq[i - 1] >= 2.0 * critical_conflict_threshold {
          let start_pos = uniq[i - 1] + critical_conflict_threshold
          let end_pos = uniq[i] - critical_conflict_threshold
          free_areas.push({ start_pos, end_pos, size: end_pos - start_pos })
        }
      }
      free_areas
    }

    fn count_crossings_for_single_ordering(
      left : HyperEdgeSegment,
      right : HyperEdgeSegment,
    ) -> Int {
      count_crossings(left.outgoing_coords, right.start_pos, right.end_pos) +
      count_crossings(right.incoming_coords, left.start_pos, left.end_pos)
    }

    fn update_considering_both_orderings(
      rating : AreaRating,
      s1 : HyperEdgeSegment,
      s2 : HyperEdgeSegment,
    ) -> Unit {
      let crossings_s1_left = count_crossings_for_single_ordering(s1, s2)
      let crossings_s2_left = count_crossings_for_single_ordering(s2, s1)
      if crossings_s1_left == crossings_s2_left {
        if crossings_s1_left > 0 {
          rating.dependencies = rating.dependencies + 2
          rating.crossings = rating.crossings + crossings_s1_left
        }
      } else {
        rating.dependencies = rating.dependencies + 1
        rating.crossings = rating.crossings +
          @cmp.minimum(crossings_s1_left, crossings_s2_left)
      }
    }

    fn rate_area(
      segment_idx : Int,
      split_segment : HyperEdgeSegment,
      split_partner : HyperEdgeSegment,
      area : FreeArea,
      segments : Array[HyperEdgeSegment],
      deps : Array[HyperEdgeDependency],
    ) -> AreaRating {
      let rating : AreaRating = { dependencies: 0, crossings: 0 }
      let area_center = center_area(area)
      split_segment.outgoing_coords.clear()
      split_segment.outgoing_coords.push(area_center)
      segment_recompute_extent(split_segment)
      split_partner.incoming_coords.clear()
      split_partner.incoming_coords.push(area_center)
      segment_recompute_extent(split_partner)

      // Consider dependencies to other segments.
      for dep_id in segments[segment_idx].incoming_deps {
        let other = deps[dep_id].source
        if other >= 0 {
          update_considering_both_orderings(
            rating,
            split_segment,
            segments[other],
          )
          update_considering_both_orderings(
            rating,
            split_partner,
            segments[other],
          )
        }
      }
      for dep_id in segments[segment_idx].outgoing_deps {
        let other = deps[dep_id].target
        if other >= 0 {
          update_considering_both_orderings(
            rating,
            split_segment,
            segments[other],
          )
          update_considering_both_orderings(
            rating,
            split_partner,
            segments[other],
          )
        }
      }

      // Fixed order: splitSegment -> splitBy -> splitPartner
      rating.dependencies = rating.dependencies + 2
      match segments[segment_idx].split_by {
        Some(split_by) => {
          rating.crossings = rating.crossings +
            count_crossings_for_single_ordering(
              split_segment,
              segments[split_by],
            )
          rating.crossings = rating.crossings +
            count_crossings_for_single_ordering(
              segments[split_by],
              split_partner,
            )
        }
        None => ()
      }
      rating
    }

    fn is_better(
      curr_area : FreeArea,
      curr_rating : AreaRating,
      best_area : FreeArea,
      best_rating : AreaRating,
    ) -> Bool {
      if curr_rating.crossings < best_rating.crossings {
        true
      } else if curr_rating.crossings == best_rating.crossings {
        if curr_rating.dependencies < best_rating.dependencies {
          true
        } else if curr_rating.dependencies == best_rating.dependencies {
          curr_area.size > best_area.size
        } else {
          false
        }
      } else {
        false
      }
    }

    fn use_area(
      free_areas : Array[FreeArea],
      used_idx : Int,
      critical_conflict_threshold : Double,
    ) -> Unit {
      let old = free_areas[used_idx]
      free_areas.remove(used_idx) |> ignore
      if old.size / 2.0 >= critical_conflict_threshold {
        let insert_idx = used_idx
        let center = center_area(old)
        let new_end1 = center - critical_conflict_threshold
        if old.start_pos <= new_end1 {
          let a1 = {
            start_pos: old.start_pos,
            end_pos: new_end1,
            size: new_end1 - old.start_pos,
          }
          free_areas.insert(insert_idx, a1)
        }
        let new_start2 = center + critical_conflict_threshold
        if new_start2 <= old.end_pos {
          let a2 = {
            start_pos: new_start2,
            end_pos: old.end_pos,
            size: old.end_pos - new_start2,
          }
          // Insert after potential first insertion.
          let idx2 = if old.start_pos <= new_end1 {
            insert_idx + 1
          } else {
            insert_idx
          }
          free_areas.insert(idx2, a2)
        }
      }
    }

    fn choose_best_area_index(
      segment_idx : Int,
      free_areas : Array[FreeArea],
      from_idx : Int,
      to_idx : Int,
      segments : Array[HyperEdgeSegment],
      deps : Array[HyperEdgeDependency],
    ) -> Int {
      let mut best_idx = from_idx
      if from_idx < to_idx {
        let (split_seg, split_partner) = segment_simulate_split(
          segments[segment_idx],
        )
        // These are simulation segments, not part of segments array.
        segment_recompute_extent(split_seg)
        segment_recompute_extent(split_partner)
        let mut best_area = free_areas[best_idx]
        let mut best_rating = rate_area(
          segment_idx, split_seg, split_partner, best_area, segments, deps,
        )
        for i = from_idx + 1; i <= to_idx; i = i + 1 {
          let curr_area = free_areas[i]
          let curr_rating = rate_area(
            segment_idx, split_seg, split_partner, curr_area, segments, deps,
          )
          if is_better(curr_area, curr_rating, best_area, best_rating) {
            best_area = curr_area
            best_rating = curr_rating
            best_idx = i
          }
        }
      }
      best_idx
    }

    fn compute_split_position_and_update_free_areas(
      segment_idx : Int,
      free_areas : Array[FreeArea],
      critical_conflict_threshold : Double,
      segments : Array[HyperEdgeSegment],
      deps : Array[HyperEdgeDependency],
    ) -> Double {
      let seg = segments[segment_idx]
      let mut first_idx = -1
      let mut last_idx = -1
      for i = 0; i < free_areas.length(); i = i + 1 {
        let area = free_areas[i]
        if area.start_pos > seg.end_pos {
          break
        } else if area.end_pos >= seg.start_pos {
          if first_idx < 0 {
            first_idx = i
          }
          last_idx = i
        }
      }
      let mut split_pos = center_segment(seg)
      if first_idx >= 0 {
        let best_idx = choose_best_area_index(
          segment_idx, free_areas, first_idx, last_idx, segments, deps,
        )
        split_pos = center_area(free_areas[best_idx])
        use_area(free_areas, best_idx, critical_conflict_threshold)
      }
      split_pos
    }

    fn split_and_update_dependencies(
      segment_idx : Int,
      segments : Array[HyperEdgeSegment],
      deps : Array[HyperEdgeDependency],
      conflict_threshold : Double,
      critical_conflict_threshold : Double,
      free_areas : Array[FreeArea],
    ) -> Unit {
      // Split the segment and add the new segment.
      let split_pos = compute_split_position_and_update_free_areas(
        segment_idx, free_areas, critical_conflict_threshold, segments, deps,
      )

      // Perform split.
      let partner_idx = segment_split_at(segment_idx, split_pos, segments, deps)

      // Add critical ordering deps: segment -> split_by -> partner
      match segments[segment_idx].split_by {
        Some(split_by) => {
          ignore(dep_add(segments, deps, Critical, segment_idx, split_by, 1))
          ignore(dep_add(segments, deps, Critical, split_by, partner_idx, 1))
        }
        None => ()
      }

      // Re-introduce dependencies to other segments.
      for other = 0; other < segments.length(); other = other + 1 {
        if other == segment_idx || other == partner_idx {
          continue
        }
        match segments[segment_idx].split_by {
          Some(split_by) if other == split_by => continue
          _ => ()
        }
        ignore(
          create_dependency_if_necessary(
            segments, deps, other, segment_idx, conflict_threshold, critical_conflict_threshold,
          ),
        )
        ignore(
          create_dependency_if_necessary(
            segments, deps, other, partner_idx, conflict_threshold, critical_conflict_threshold,
          ),
        )
      }
    }

    fn split_segments_for_critical_cycles(
      deps_to_resolve : Array[Int],
      segments : Array[HyperEdgeSegment],
      deps : Array[HyperEdgeDependency],
      conflict_threshold : Double,
      critical_conflict_threshold : Double,
    ) -> Unit {
      if deps_to_resolve.is_empty() {
        return
      }

      // Find free areas between existing horizontal segments.
      let free_areas = find_free_areas(segments, critical_conflict_threshold)

      // Decide which segments to split.
      let to_split : Array[Int] = []
      let selected : Map[Int, Bool] = {}
      for dep_id in deps_to_resolve {
        let dep = deps[dep_id]
        let source_seg = dep.source
        let target_seg = dep.target
        if source_seg < 0 || target_seg < 0 {
          continue
        }
        if selected.contains(source_seg) || selected.contains(target_seg) {
          continue
        }
        let mut seg_to_split = source_seg
        let mut seg_causing = target_seg
        if segment_represents_hyperedge(segments[source_seg]) &&
          !segment_represents_hyperedge(segments[target_seg]) {
          seg_to_split = target_seg
          seg_causing = source_seg
        }
        selected[seg_to_split] = true
        to_split.push(seg_to_split)
        segments[seg_to_split].split_by = Some(seg_causing)
      }

      // Split smallest segments first.
      to_split.sort_by(fn(a, b) {
        let la = segment_length(segments[a])
        let lb = segment_length(segments[b])
        if la < lb {
          -1
        } else if la > lb {
          1
        } else {
          a - b
        }
      })
      for seg_idx in to_split {
        split_and_update_dependencies(
          seg_idx, segments, deps, conflict_threshold, critical_conflict_threshold,
          free_areas,
        )
      }
    }

    // Break critical cycles by splitting segments (ELK HyperEdgeSegmentSplitter).
    if critical_dep_count >= 2 {
      let critical_cycle_deps = detect_cycles(
        segments,
        deps,
        true,
        PRNG::new(local_seed),
      )
      if !critical_cycle_deps.is_empty() {
        split_segments_for_critical_cycles(
          critical_cycle_deps, segments, deps, conflict_threshold, critical_conflict_threshold,
        )
      }
    }

    // Break non-critical cycles.
    let cycle_deps = detect_cycles(
      segments,
      deps,
      false,
      PRNG::new(local_seed + 1),
    )
    for dep_id in cycle_deps {
      // Never remove/reverse critical dependencies.
      if deps[dep_id].dep_type is Critical {
        continue
      }
      if deps[dep_id].weight == 0 {
        dep_remove(segments, deps, dep_id)
      } else {
        dep_reverse(segments, deps, dep_id)
      }
    }

    // Topological numbering.
    let sources : Array[Int] = []
    let rightward_targets : Array[Int] = []
    for i = 0; i < segments.length(); i = i + 1 {
      let seg = segments[i]
      seg.in_weight = seg.incoming_deps.length()
      seg.out_weight = seg.outgoing_deps.length()
      if seg.in_weight == 0 {
        sources.push(i)
      }
      if seg.out_weight == 0 && seg.incoming_coords.is_empty() {
        rightward_targets.push(i)
      }
    }
    let mut max_rank = -1
    while !sources.is_empty() {
      let node = sources.remove(0)
      for dep_id in segments[node].outgoing_deps {
        let dep = deps[dep_id]
        let target = dep.target
        if target < 0 {
          continue
        }
        let candidate = segments[node].routing_slot + 1
        if candidate > segments[target].routing_slot {
          segments[target].routing_slot = candidate
        }
        max_rank = @cmp.maximum(max_rank, segments[target].routing_slot)
        segments[target].in_weight = segments[target].in_weight - 1
        if segments[target].in_weight == 0 {
          sources.push(target)
        }
      }
    }
    if max_rank > -1 {
      for t in rightward_targets {
        segments[t].routing_slot = max_rank
      }
      while !rightward_targets.is_empty() {
        let node = rightward_targets.remove(0)
        for dep_id in segments[node].incoming_deps {
          let dep = deps[dep_id]
          let source = dep.source
          if source < 0 {
            continue
          }
          if !segments[source].incoming_coords.is_empty() {
            continue
          }
          let candidate = segments[node].routing_slot - 1
          if candidate < segments[source].routing_slot {
            segments[source].routing_slot = candidate
          }
          segments[source].out_weight = segments[source].out_weight - 1
          if segments[source].out_weight == 0 {
            rightward_targets.push(source)
          }
        }
      }
    }
    let mut max_slot = -1
    for seg in segments {
      if segment_is_straight(seg) {
        continue
      }
      if seg.routing_slot > max_slot {
        max_slot = seg.routing_slot
      }
    }
    if max_slot >= 0 {
      slots_by_pair[layer_key] = max_slot + 1
    } else {
      slots_by_pair[layer_key] = 0
    }

    // Cross-hierarchy edges: ensure enough slots to separate distinct child-to-top edges.
    let mut min_slots = 0
    let seen : Map[String, Bool] = {}
    for e in layer_edges {
      if !e.properties.get_bool_or("diago.layered.crossHierarchy", false) {
        continue
      }
      let orig_src = e.properties.get_string("diago.layered.originalSourceId")
      let orig_tgt = e.properties.get_string("diago.layered.originalTargetId")
      match (orig_src, orig_tgt) {
        (Some(os), Some(ot)) if ot == e.target_id && os != e.source_id => {
          let key = os + "->" + ot
          if !seen.contains(key) {
            seen[key] = true
            min_slots = min_slots + 1
          }
        }
        _ => ()
      }
    }
    let current_slots = slots_by_pair.get(layer_key).unwrap_or(0)
    if min_slots > current_slots {
      slots_by_pair[layer_key] = min_slots
    }

    // Emit lane per edge.
    let reverse_slots = direction is Up || direction is Left
    for e in layer_edges {
      let sk = edge_src_key.get(e.id)
      guard sk is Some(src_key) else { continue }
      let seg_idx = port_to_seg.get(src_key).unwrap_or(0)
      let slot = segments[seg_idx].routing_slot.to_double()
      let lane = if reverse_slots {
        base_lane - slot * edge_edge_spacing
      } else {
        base_lane + slot * edge_edge_spacing
      }
      let info = match segments[seg_idx].split_partner {
        Some(partner_idx) => {
          let partner_slot = segments[partner_idx].routing_slot.to_double()
          let split_lane = if reverse_slots {
            base_lane - partner_slot * edge_edge_spacing
          } else {
            base_lane + partner_slot * edge_edge_spacing
          }

          // The connecting coordinate is stored on the split partner.
          let split_coord = if segments[partner_idx].incoming_coords.is_empty() {
            0.0
          } else {
            segments[partner_idx].incoming_coords[0]
          }
          { lane, split_lane: Some(split_lane), split_coord: Some(split_coord) }
        }
        None => default_lane_info(lane)
      }
      lane_by_edge[e.id] = info
    }
    ignore(critical_dep_count)
  }
  { lane_by_edge, slots_by_pair }
}

// ============================================================================
// Improved Orthogonal Routing
// ============================================================================

///|
/// Route edges orthogonally with proper slot assignment
fn route_edges_orthogonal(
  graph : LGraph,
  direction : LayoutDirection,
  node_node_spacing : Double,
  edge_edge_spacing : Double,
  edge_node_spacing : Double,
  padding : ElkPadding,
  random_seed : Int,
) -> Unit {
  let is_vertical = direction.is_vertical()
  let slot_info = segment_lane_for_layer_pair(
    graph.edges,
    graph,
    direction,
    edge_edge_spacing,
    edge_node_spacing,
    random_seed,
    true,
  )
  if is_vertical {
    apply_routing_spacing_vertical(
      graph,
      direction,
      padding,
      node_node_spacing,
      edge_edge_spacing,
      edge_node_spacing,
      slot_info.slots_by_pair,
    )
  } else {
    apply_routing_spacing_horizontal(
      graph,
      direction,
      padding,
      node_node_spacing,
      edge_edge_spacing,
      edge_node_spacing,
      slot_info.slots_by_pair,
    )
  }
  let lane_info = segment_lane_for_layer_pair(
    graph.edges,
    graph,
    direction,
    edge_edge_spacing,
    edge_node_spacing,
    random_seed,
    true,
  )

  // Process edges layer by layer
  if is_vertical {
    route_vertical_layout(
      graph,
      direction,
      edge_edge_spacing,
      edge_node_spacing,
      lane_info.lane_by_edge,
    )
  } else {
    route_horizontal_layout(
      graph,
      direction,
      edge_edge_spacing,
      edge_node_spacing,
      lane_info.lane_by_edge,
    )
  }

  // ------------------------------------------------------------------------
  // Hierarchical port routing (north/south external ports)
  // ------------------------------------------------------------------------
  //
  // ELK routes edges incident to hierarchical external ports in a dedicated
  // post-processing step. We approximate that behavior here by:
  // - positioning north/south ExternalPort dummy nodes outside the graph padding
  // - setting their x coordinate to the average x of connected port anchors
  // - re-running bendpoint routing without modifying node/layer spacing again
  if is_vertical {
    fn parse_side(raw : String) -> ElkPortSide? {
      match raw {
        "North" | "NORTH" => Some(North)
        "South" | "SOUTH" => Some(South)
        "East" | "EAST" => Some(East)
        "West" | "WEST" => Some(West)
        _ => None
      }
    }

    fn anchor_for_port(node : LNode, port_id : String?) -> (Double, Double)? {
      match port_id {
        None => None
        Some(pid) => {
          for port in node.ports {
            if port.id != pid {
              continue
            }
            let has_size = port.width > 0.0 || port.height > 0.0
            if has_size {
              return Some(
                (
                  node.x + port.x + port.width / 2.0,
                  node.y + port.y + port.height / 2.0,
                ),
              )
            }
            let has_pos = port.x != 0.0 || port.y != 0.0
            let border = port.properties.get_double_or(
              "diago.layered.portBorderOffset",
              0.0,
            )
            let pt = match port.side {
              North =>
                if has_pos { (node.x + port.x, node.y + border) } else {
                  (node.x + node.width / 2.0, node.y + border)
                }
              South =>
                if has_pos { (node.x + port.x, node.y + node.height - border) } else {
                  (node.x + node.width / 2.0, node.y + node.height - border)
                }
              West =>
                if has_pos { (node.x + border, node.y + port.y) } else {
                  (node.x + border, node.y + node.height / 2.0)
                }
              East =>
                if has_pos { (node.x + node.width - border, node.y + port.y) } else {
                  (node.x + node.width - border, node.y + node.height / 2.0)
                }
              Undefined =>
                (node.x + node.width / 2.0, node.y + node.height / 2.0)
            }
            return Some(pt)
          }
          None
        }
      }
    }

    let north_y = 0.0 - padding.top
    let south_y = graph.height
    let mut touched = false

    for dummy in graph.nodes {
      if dummy.node_type != ExternalPort {
        continue
      }
      let side_raw = dummy.properties.get_string("diago.layered.extPortSide")
      guard side_raw is Some(sr) else { continue }
      let side = parse_side(sr)
      guard side is Some(s) else { continue }
      if s != North && s != South {
        continue
      }

      let mut pos_sum = 0.0
      let mut degree = 0
      for e in graph.edges {
        if e.source_id == dummy.id {
          match graph.get_node(e.target_id) {
            Some(other) =>
              match anchor_for_port(other, e.target_port_id) {
                Some((ax, _)) => {
                  pos_sum = pos_sum + ax
                  degree = degree + 1
                }
                None => ()
              }
            None => ()
          }
        } else if e.target_id == dummy.id {
          match graph.get_node(e.source_id) {
            Some(other) =>
              match anchor_for_port(other, e.source_port_id) {
                Some((ax, _)) => {
                  pos_sum = pos_sum + ax
                  degree = degree + 1
                }
                None => ()
              }
            None => ()
          }
        }
      }
      if degree == 0 {
        dummy.x = 0.0
      } else {
        dummy.x = pos_sum / degree.to_double()
      }
      dummy.y = if s == North { north_y } else { south_y }
      touched = true
    }

    if touched {
      // Re-route bends only.
      let lane_info = segment_lane_for_layer_pair(
        graph.edges,
        graph,
        direction,
        edge_edge_spacing,
        edge_node_spacing,
        random_seed,
        true,
      )
      route_vertical_layout(
        graph,
        direction,
        edge_edge_spacing,
        edge_node_spacing,
        lane_info.lane_by_edge,
      )
    }
  }
}

///|
fn layer_is_external(layer : LLayer) -> Bool {
  if layer.nodes.is_empty() {
    return true
  }
  for node in layer.nodes {
    if node.node_type != ExternalPort {
      return false
    }
  }
  true
}

///|
fn layer_pair_key(a : Int, b : Int) -> String {
  let lo = @cmp.minimum(a, b)
  let hi = @cmp.maximum(a, b)
  lo.to_string() + "-" + hi.to_string()
}

///|
fn apply_routing_spacing_vertical(
  graph : LGraph,
  direction : LayoutDirection,
  padding : ElkPadding,
  node_node_spacing : Double,
  edge_edge_spacing : Double,
  edge_node_spacing : Double,
  slots_by_pair : Map[String, Int],
) -> Unit {
  let reverse_layers = direction == Up
  let indices : Array[Int] = []
  if reverse_layers {
    for i = 0; i < graph.layers.length(); i = i + 1 {
      indices.push(graph.layers.length() - 1 - i)
    }
  } else {
    for i = 0; i < graph.layers.length(); i = i + 1 {
      indices.push(i)
    }
  }
  let mut offset = padding.top
  for i = 0; i < indices.length(); i = i + 1 {
    let layer_idx = indices[i]
    let layer = graph.layers[layer_idx]
    // Preserve intra-layer offsets (e.g. bottom-aligned mixed-size nodes) by
    // translating the whole layer, instead of overwriting each node position.
    let mut layer_top = @double.infinity
    let mut layer_bottom = -@double.infinity
    for node in layer.nodes {
      if node.y < layer_top {
        layer_top = node.y
      }
      let b = node.y + node.height
      if b > layer_bottom {
        layer_bottom = b
      }
    }
    let delta = if layer_top == @double.infinity {
      0.0
    } else {
      offset - layer_top
    }
    for node in layer.nodes {
      node.y = node.y + delta
    }
    let layer_size = if layer_top == @double.infinity {
      0.0
    } else {
      layer_bottom - layer_top
    }
    offset = offset + layer_size
    if i + 1 < indices.length() {
      let next_idx = indices[i + 1]
      let next_layer = graph.layers[next_idx]
      let key = layer_pair_key(layer.index, next_layer.index)
      let slots = slots_by_pair.get(key).unwrap_or(0)
      let left_external = layer_is_external(layer)
      let right_external = layer_is_external(next_layer)
      let mut spacing = 0.0
      if left_external || right_external {
        // External-port border layers are positioned outside the compound node
        // padding (handled in hierarchical port routing). They must not consume
        // regular inter-layer spacing or push internal layers around.
        spacing = 0.0
      } else if slots > 0 {
        spacing = (slots - 1).to_double() * edge_edge_spacing
        if !layer.nodes.is_empty() {
          spacing = spacing + edge_node_spacing
        }
        if !next_layer.nodes.is_empty() {
          spacing = spacing + edge_node_spacing
        }
        if spacing < node_node_spacing {
          spacing = node_node_spacing
        }
      } else {
        spacing = node_node_spacing
      }
      offset = offset + spacing
    }
  }
  let mut max_y = 0.0
  let mut max_x = 0.0
  for node in graph.nodes {
    if node.node_type == ExternalPort {
      continue
    }
    if node.y + node.height > max_y {
      max_y = node.y + node.height
    }
    if node.x + node.width > max_x {
      max_x = node.x + node.width
    }
  }
  graph.height = max_y + padding.bottom
  graph.width = max_x + padding.right
}

///|
fn apply_routing_spacing_horizontal(
  graph : LGraph,
  direction : LayoutDirection,
  padding : ElkPadding,
  node_node_spacing : Double,
  edge_edge_spacing : Double,
  edge_node_spacing : Double,
  slots_by_pair : Map[String, Int],
) -> Unit {
  let reverse_layers = direction == Left
  let indices : Array[Int] = []
  if reverse_layers {
    for i = 0; i < graph.layers.length(); i = i + 1 {
      indices.push(graph.layers.length() - 1 - i)
    }
  } else {
    for i = 0; i < graph.layers.length(); i = i + 1 {
      indices.push(i)
    }
  }
  let mut offset = padding.left
  for i = 0; i < indices.length(); i = i + 1 {
    let layer_idx = indices[i]
    let layer = graph.layers[layer_idx]
    let mut layer_left = @double.infinity
    let mut layer_right = -@double.infinity
    for node in layer.nodes {
      if node.x < layer_left {
        layer_left = node.x
      }
      let r = node.x + node.width
      if r > layer_right {
        layer_right = r
      }
    }
    let delta = if layer_left == @double.infinity {
      0.0
    } else {
      offset - layer_left
    }
    for node in layer.nodes {
      node.x = node.x + delta
    }
    let layer_size = if layer_left == @double.infinity {
      0.0
    } else {
      layer_right - layer_left
    }
    offset = offset + layer_size
    if i + 1 < indices.length() {
      let next_idx = indices[i + 1]
      let next_layer = graph.layers[next_idx]
      let key = layer_pair_key(layer.index, next_layer.index)
      let slots = slots_by_pair.get(key).unwrap_or(0)
      let left_external = layer_is_external(layer)
      let right_external = layer_is_external(next_layer)
      let mut spacing = 0.0
      if left_external || right_external {
        spacing = 0.0
      } else if slots > 0 {
        spacing = (slots - 1).to_double() * edge_edge_spacing
        if !layer.nodes.is_empty() {
          spacing = spacing + edge_node_spacing
        }
        if !next_layer.nodes.is_empty() {
          spacing = spacing + edge_node_spacing
        }
        if spacing < node_node_spacing {
          spacing = node_node_spacing
        }
      } else {
        spacing = node_node_spacing
      }
      offset = offset + spacing
    }
  }
  let mut max_y = 0.0
  let mut max_x = 0.0
  for node in graph.nodes {
    if node.node_type == ExternalPort {
      continue
    }
    if node.y + node.height > max_y {
      max_y = node.y + node.height
    }
    if node.x + node.width > max_x {
      max_x = node.x + node.width
    }
  }
  graph.height = max_y + padding.bottom
  graph.width = max_x + padding.right
}

///|
/// Route edges for vertical (top-to-bottom) layouts
fn route_vertical_layout(
  graph : LGraph,
  direction : LayoutDirection,
  edge_edge_spacing : Double,
  edge_node_spacing : Double,
  lane_by_edge : Map[String, LaneInfo],
) -> Unit {
  // ELK's layered implementation (with orthogonal routing and FIXED_POS ports)
  // ensures enough horizontal clearance for EAST->WEST edges by shifting lower
  // layers in the cross direction. This is especially important for sql_table
  // column ports, which are fixed on EAST/WEST even in vertical layouts.
  fn enforce_side_port_layer_separation(
    graph : LGraph,
    direction : LayoutDirection,
    edge_node_spacing : Double,
  ) -> Unit {
    if !direction.is_vertical() {
      return
    }
    let layer_count = graph.layers.length()
    if layer_count <= 1 {
      return
    }
    let gap = 2.0 * edge_node_spacing
    fn port_side(node : LNode, port_id : String?) -> ElkPortSide? {
      match port_id {
        Some(pid) => {
          for port in node.ports {
            if port.id == pid {
              return Some(port.side)
            }
          }
          None
        }
        None => None
      }
    }

    fn is_sql_table(node : LNode) -> Bool {
      node.properties.get_bool_or("diago.sqlTable", false)
    }

    let shifts : Array[Double] = []
    for _ in 0..<layer_count {
      shifts.push(0.0)
    }
    // Relax constraints layer-by-layer; for a vertical layout, edges point
    // forward in layer index for Down and reverse for Up.
    for _pass in 0..<layer_count {
      let mut changed = false
      for edge in graph.edges {
        let source = graph.get_node(edge.source_id)
        let target = graph.get_node(edge.target_id)
        guard source is Some(src) && target is Some(tgt) else { continue }
        if src.layer == tgt.layer {
          continue
        }
        // Only apply to sql_table nodes; other FIXED_POS uses (e.g. hierarchy
        // ports) should keep the generic placement behavior.
        if !is_sql_table(src) && !is_sql_table(tgt) {
          continue
        }
        let forward = match direction {
          Down => src.layer < tgt.layer
          Up => src.layer > tgt.layer
          _ => false
        }
        if !forward {
          continue
        }
        let src_side = port_side(src, edge.source_port_id)
        let tgt_side = port_side(tgt, edge.target_port_id)
        // EAST -> WEST edges need clearance to route between layers.
        if src_side != Some(East) || tgt_side != Some(West) {
          continue
        }
        let src_layer = src.layer
        let tgt_layer = tgt.layer
        if src_layer < 0 ||
          src_layer >= layer_count ||
          tgt_layer < 0 ||
          tgt_layer >= layer_count {
          continue
        }
        let src_right = src.x + shifts[src_layer] + src.width
        let need = src_right + gap
        let tgt_left = tgt.x + shifts[tgt_layer]
        if tgt_left + 1.0e-6 < need {
          shifts[tgt_layer] = shifts[tgt_layer] + (need - tgt_left)
          changed = true
        }
      }
      if !changed {
        break
      }
    }
    for layer in graph.layers {
      let idx = layer.index
      if idx < 0 || idx >= shifts.length() {
        continue
      }
      let dx = shifts[idx]
      if dx == 0.0 {
        continue
      }
      for node in layer.nodes {
        node.x = node.x + dx
      }
    }
  }

  enforce_side_port_layer_separation(graph, direction, edge_node_spacing)
  fn fallback_lane(
    graph : LGraph,
    src : LNode,
    tgt : LNode,
    direction : LayoutDirection,
    edge_node_spacing : Double,
  ) -> Double {
    let lo = @cmp.minimum(src.layer, tgt.layer)
    let hi = @cmp.maximum(src.layer, tgt.layer)
    let scan_layer = match direction {
      Up | Left => hi
      _ => lo
    }
    let is_vertical = direction.is_vertical()
    let mut boundary = if is_vertical {
      if direction is Down {
        -1.0e18
      } else {
        1.0e18
      }
    } else if direction is Right {
      -1.0e18
    } else {
      1.0e18
    }
    if scan_layer >= 0 && scan_layer < graph.layers.length() {
      for node in graph.layers[scan_layer].nodes {
        if is_vertical {
          if direction is Down {
            boundary = max_double(boundary, node.y + node.height)
          } else {
            boundary = min_double(boundary, node.y)
          }
        } else if direction is Right {
          boundary = max_double(boundary, node.x + node.width)
        } else {
          boundary = min_double(boundary, node.x)
        }
      }
    }
    match direction {
      Up | Left => boundary - edge_node_spacing
      _ => boundary + edge_node_spacing
    }
  }

  fn default_anchor(
    node : LNode,
    direction : LayoutDirection,
    is_source : Bool,
  ) -> (Double, Double) {
    let cx = node.x + node.width / 2.0
    let cy = node.y + node.height / 2.0
    match direction {
      Down => if is_source { (cx, node.y + node.height) } else { (cx, node.y) }
      Up => if is_source { (cx, node.y) } else { (cx, node.y + node.height) }
      Right => if is_source { (node.x + node.width, cy) } else { (node.x, cy) }
      Left => if is_source { (node.x, cy) } else { (node.x + node.width, cy) }
      Undefined =>
        if is_source {
          (cx, node.y + node.height)
        } else {
          (cx, node.y)
        }
    }
  }

  fn anchor_with_port(
    node : LNode,
    port_id : String?,
    direction : LayoutDirection,
    is_source : Bool,
    fallback_side : ElkPortSide,
  ) -> (Double, Double) {
    fn anchor_for_side(
      node : LNode,
      side : ElkPortSide,
      direction : LayoutDirection,
      is_source : Bool,
    ) -> (Double, Double) {
      let cx = node.x + node.width / 2.0
      let cy = node.y + node.height / 2.0
      match side {
        North => (cx, node.y)
        South => (cx, node.y + node.height)
        West => (node.x, cy)
        East => (node.x + node.width, cy)
        Undefined => default_anchor(node, direction, is_source)
      }
    }

    let default_side = if fallback_side is Undefined {
      if is_source {
        South
      } else {
        North
      }
    } else {
      fallback_side
    }
    match port_id {
      Some(pid) => {
        for port in node.ports {
          if port.id == pid {
            let side = if port.side is Undefined {
              default_side
            } else {
              port.side
            }
            let has_size = port.width > 0.0 || port.height > 0.0
            if has_size {
              return (
                node.x + port.x + port.width / 2.0,
                node.y + port.y + port.height / 2.0,
              )
            }
            let has_pos = port.x != 0.0 || port.y != 0.0
            let border = port.properties.get_double_or(
              "diago.layered.portBorderOffset", 0.0,
            )
            let anchor = match side {
              North =>
                if has_pos {
                  (node.x + port.x, node.y + border)
                } else {
                  (node.x + node.width / 2.0, node.y + border)
                }
              South =>
                if has_pos {
                  (node.x + port.x, node.y + node.height - border)
                } else {
                  (node.x + node.width / 2.0, node.y + node.height - border)
                }
              West =>
                if has_pos {
                  (node.x + border, node.y + port.y)
                } else {
                  (node.x + border, node.y + node.height / 2.0)
                }
              East =>
                if has_pos {
                  (node.x + node.width - border, node.y + port.y)
                } else {
                  (node.x + node.width - border, node.y + node.height / 2.0)
                }
              Undefined =>
                anchor_for_side(node, default_side, direction, is_source)
            }
            return anchor
          }
        }
        anchor_for_side(node, default_side, direction, is_source)
      }
      None => anchor_for_side(node, default_side, direction, is_source)
    }
  }

  fn infer_for_edge(
    src : LNode,
    tgt : LNode,
    direction : LayoutDirection,
  ) -> (ElkPortSide, ElkPortSide) {
    if src.layer < tgt.layer {
      if direction.is_vertical() {
        (South, North)
      } else {
        (East, West)
      }
    } else if src.layer > tgt.layer {
      if direction.is_vertical() {
        (North, South)
      } else {
        (West, East)
      }
    } else if direction.is_vertical() {
      if src.position < tgt.position {
        (East, West)
      } else {
        (West, East)
      }
    } else if src.position < tgt.position {
      (South, North)
    } else {
      (North, South)
    }
  }

  // First, group parallel edges deterministically.
  // Use normalized keys so (A->B) and (B->A) are counted together.
  let edge_groups : Map[String, Array[LEdge]] = {}
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source = graph.get_node(edge.source_id)
    let target = graph.get_node(edge.target_id)
    guard source is Some(src) && target is Some(tgt) else { continue }
    if src.layer == tgt.layer {
      continue
    }
    let key = if edge.source_id < edge.target_id {
      edge.source_id +
      ":" +
      edge.source_port_id.unwrap_or("") +
      "->" +
      edge.target_id +
      ":" +
      edge.target_port_id.unwrap_or("")
    } else {
      edge.target_id +
      ":" +
      edge.target_port_id.unwrap_or("") +
      "->" +
      edge.source_id +
      ":" +
      edge.source_port_id.unwrap_or("")
    }
    if !edge_groups.contains(key) {
      edge_groups[key] = []
    }
    match edge_groups.get(key) {
      Some(arr) => arr.push(edge)
      None => ()
    }
  }
  let parallel_count_by_key : Map[String, Int] = {}
  let parallel_index_by_edge : Map[String, Int] = {}
  for key, edges in edge_groups {
    edges.sort_by(fn(a, b) { a.id.compare(b.id) })
    parallel_count_by_key[key] = edges.length()
    for i, e in edges {
      parallel_index_by_edge[e.id] = i
    }
  }
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source = graph.get_node(edge.source_id)
    let target = graph.get_node(edge.target_id)
    guard source is Some(src) && target is Some(tgt) else { continue }

    // Skip edges within the same layer
    if src.layer == tgt.layer {
      continue
    }

    // Clear existing bend points
    edge.bend_points.clear()

    // Calculate source and target connection points (from ports if present)
    let (fallback_src_side, fallback_tgt_side) = infer_for_edge(
      src, tgt, direction,
    )
    let (src_x, src_y) = anchor_with_port(
      src,
      edge.source_port_id,
      direction,
      true,
      fallback_src_side,
    )
    let (tgt_x, tgt_y) = anchor_with_port(
      tgt,
      edge.target_port_id,
      direction,
      false,
      fallback_tgt_side,
    )

    // Deterministic parallel edge index using normalized key.
    let key = if edge.source_id < edge.target_id {
      edge.source_id +
      ":" +
      edge.source_port_id.unwrap_or("") +
      "->" +
      edge.target_id +
      ":" +
      edge.target_port_id.unwrap_or("")
    } else {
      edge.target_id +
      ":" +
      edge.target_port_id.unwrap_or("") +
      "->" +
      edge.source_id +
      ":" +
      edge.source_port_id.unwrap_or("")
    }
    let parallel_count = parallel_count_by_key.get(key).unwrap_or(1)
    let parallel_index = parallel_index_by_edge.get(edge.id).unwrap_or(0)

    // Calculate offset for parallel edges - ALWAYS non-zero for parallel edges
    // This ensures all parallel edges have distinct routes from start to end
    let parallel_offset = if parallel_count > 1 {
      // Use alternating offsets that are always non-zero
      // Sequence: -0.5*spacing, +0.5*spacing, -1.5*spacing, +1.5*spacing, ...
      let half_spacing = edge_edge_spacing / 2.0
      let slot = (parallel_index / 2).to_double() + 0.5
      if parallel_index % 2 == 0 {
        -slot * half_spacing
      } else {
        slot * half_spacing
      }
    } else {
      0.0
    }

    // Store the parallel offset so apply_to_elk_graph can use it for start/end points
    edge.parallel_offset = parallel_offset

    // Calculate routing
    if (src_x - tgt_x).abs() < 1.0 && parallel_count == 1 {
      // Nodes are aligned and single edge - straight edge, no bend points needed
      // Bend points will be empty, edge goes straight
    } else {
      let lane_base = fallback_lane(
        graph, src, tgt, direction, edge_node_spacing,
      )
      let lane_info = lane_by_edge
        .get(edge.id)
        .unwrap_or(default_lane_info(lane_base))
      let lane = lane_info.lane
      if (src_x - tgt_x).abs() < 1.0 {
        edge.bend_points.push(ElkPoint::new(src_x + parallel_offset, src_y))
        edge.bend_points.push(ElkPoint::new(src_x + parallel_offset, tgt_y))
      } else {
        match (lane_info.split_lane, lane_info.split_coord) {
          (Some(split_lane), Some(split_coord)) => {
            edge.bend_points.push(ElkPoint::new(src_x + parallel_offset, lane))
            edge.bend_points.push(
              ElkPoint::new(split_coord + parallel_offset, lane),
            )
            edge.bend_points.push(
              ElkPoint::new(split_coord + parallel_offset, split_lane),
            )
            edge.bend_points.push(
              ElkPoint::new(tgt_x + parallel_offset, split_lane),
            )
          }
          _ => {
            edge.bend_points.push(ElkPoint::new(src_x + parallel_offset, lane))
            edge.bend_points.push(ElkPoint::new(tgt_x + parallel_offset, lane))
          }
        }
      }
    }
  }
}

///|
/// Route edges for horizontal (left-to-right) layouts
fn route_horizontal_layout(
  graph : LGraph,
  direction : LayoutDirection,
  edge_edge_spacing : Double,
  edge_node_spacing : Double,
  lane_by_edge : Map[String, LaneInfo],
) -> Unit {
  let _ = edge_node_spacing
  fn default_anchor(
    node : LNode,
    direction : LayoutDirection,
    is_source : Bool,
  ) -> (Double, Double) {
    let cx = node.x + node.width / 2.0
    let cy = node.y + node.height / 2.0
    match direction {
      Down => if is_source { (cx, node.y + node.height) } else { (cx, node.y) }
      Up => if is_source { (cx, node.y) } else { (cx, node.y + node.height) }
      Right => if is_source { (node.x + node.width, cy) } else { (node.x, cy) }
      Left => if is_source { (node.x, cy) } else { (node.x + node.width, cy) }
      Undefined =>
        if is_source {
          (node.x + node.width, cy)
        } else {
          (node.x, cy)
        }
    }
  }

  fn anchor_with_port(
    node : LNode,
    port_id : String?,
    direction : LayoutDirection,
    is_source : Bool,
    fallback_side : ElkPortSide,
  ) -> (Double, Double) {
    fn anchor_for_side(
      node : LNode,
      side : ElkPortSide,
      direction : LayoutDirection,
      is_source : Bool,
    ) -> (Double, Double) {
      let cx = node.x + node.width / 2.0
      let cy = node.y + node.height / 2.0
      match side {
        North => (cx, node.y)
        South => (cx, node.y + node.height)
        West => (node.x, cy)
        East => (node.x + node.width, cy)
        Undefined => default_anchor(node, direction, is_source)
      }
    }

    let default_side = if fallback_side is Undefined {
      if is_source {
        East
      } else {
        West
      }
    } else {
      fallback_side
    }
    match port_id {
      Some(pid) => {
        for port in node.ports {
          if port.id == pid {
            let side = if port.side is Undefined {
              default_side
            } else {
              port.side
            }
            let has_size = port.width > 0.0 || port.height > 0.0
            if has_size {
              return (
                node.x + port.x + port.width / 2.0,
                node.y + port.y + port.height / 2.0,
              )
            }
            let has_pos = port.x != 0.0 || port.y != 0.0
            let border = port.properties.get_double_or(
              "diago.layered.portBorderOffset", 0.0,
            )
            let anchor = match side {
              North =>
                if has_pos {
                  (node.x + port.x, node.y + border)
                } else {
                  (node.x + node.width / 2.0, node.y + border)
                }
              South =>
                if has_pos {
                  (node.x + port.x, node.y + node.height - border)
                } else {
                  (node.x + node.width / 2.0, node.y + node.height - border)
                }
              West =>
                if has_pos {
                  (node.x + border, node.y + port.y)
                } else {
                  (node.x + border, node.y + node.height / 2.0)
                }
              East =>
                if has_pos {
                  (node.x + node.width - border, node.y + port.y)
                } else {
                  (node.x + node.width - border, node.y + node.height / 2.0)
                }
              Undefined =>
                anchor_for_side(node, default_side, direction, is_source)
            }
            return anchor
          }
        }
        anchor_for_side(node, default_side, direction, is_source)
      }
      None => anchor_for_side(node, default_side, direction, is_source)
    }
  }

  fn infer_for_edge(
    src : LNode,
    tgt : LNode,
    direction : LayoutDirection,
  ) -> (ElkPortSide, ElkPortSide) {
    if src.layer < tgt.layer {
      if direction.is_vertical() {
        (South, North)
      } else {
        (East, West)
      }
    } else if src.layer > tgt.layer {
      if direction.is_vertical() {
        (North, South)
      } else {
        (West, East)
      }
    } else if direction.is_vertical() {
      if src.position < tgt.position {
        (East, West)
      } else {
        (West, East)
      }
    } else if src.position < tgt.position {
      (South, North)
    } else {
      (North, South)
    }
  }

  // Deterministic parallel edge grouping.
  // Use normalized keys so (A->B) and (B->A) are counted together.
  let edge_groups : Map[String, Array[LEdge]] = {}
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source = graph.get_node(edge.source_id)
    let target = graph.get_node(edge.target_id)
    guard source is Some(src) && target is Some(tgt) else { continue }
    if src.layer == tgt.layer {
      continue
    }
    let key = if edge.source_id < edge.target_id {
      edge.source_id +
      ":" +
      edge.source_port_id.unwrap_or("") +
      "->" +
      edge.target_id +
      ":" +
      edge.target_port_id.unwrap_or("")
    } else {
      edge.target_id +
      ":" +
      edge.target_port_id.unwrap_or("") +
      "->" +
      edge.source_id +
      ":" +
      edge.source_port_id.unwrap_or("")
    }
    if !edge_groups.contains(key) {
      edge_groups[key] = []
    }
    match edge_groups.get(key) {
      Some(arr) => arr.push(edge)
      None => ()
    }
  }
  let parallel_count_by_key : Map[String, Int] = {}
  let parallel_index_by_edge : Map[String, Int] = {}
  for key, edges in edge_groups {
    edges.sort_by(fn(a, b) { a.id.compare(b.id) })
    parallel_count_by_key[key] = edges.length()
    for i, e in edges {
      parallel_index_by_edge[e.id] = i
    }
  }
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source = graph.get_node(edge.source_id)
    let target = graph.get_node(edge.target_id)
    guard source is Some(src) && target is Some(tgt) else { continue }

    // Skip edges within the same layer
    if src.layer == tgt.layer {
      continue
    }

    // Clear existing bend points
    edge.bend_points.clear()

    // Calculate source and target connection points (from ports if present)
    let (fallback_src_side, fallback_tgt_side) = infer_for_edge(
      src, tgt, direction,
    )
    let (src_x, src_y) = anchor_with_port(
      src,
      edge.source_port_id,
      direction,
      true,
      fallback_src_side,
    )
    let (tgt_x, tgt_y) = anchor_with_port(
      tgt,
      edge.target_port_id,
      direction,
      false,
      fallback_tgt_side,
    )
    let key = if edge.source_id < edge.target_id {
      edge.source_id +
      ":" +
      edge.source_port_id.unwrap_or("") +
      "->" +
      edge.target_id +
      ":" +
      edge.target_port_id.unwrap_or("")
    } else {
      edge.target_id +
      ":" +
      edge.target_port_id.unwrap_or("") +
      "->" +
      edge.source_id +
      ":" +
      edge.source_port_id.unwrap_or("")
    }
    let parallel_count = parallel_count_by_key.get(key).unwrap_or(1)
    let parallel_index = parallel_index_by_edge.get(edge.id).unwrap_or(0)
    let parallel_offset = if parallel_count > 1 {
      let half_spacing = edge_edge_spacing / 2.0
      let slot = (parallel_index / 2).to_double() + 0.5
      if parallel_index % 2 == 0 {
        -slot * half_spacing
      } else {
        slot * half_spacing
      }
    } else {
      0.0
    }
    edge.parallel_offset = parallel_offset

    // Calculate routing
    if (src_y - tgt_y).abs() < 1.0 && parallel_count == 1 {
      // Nodes are aligned and single edge - straight edge.
    } else if (src_y - tgt_y).abs() < 1.0 {
      // Aligned nodes with parallel edges: detour with Y offset.
      edge.bend_points.push(ElkPoint::new(src_x, src_y + parallel_offset))
      edge.bend_points.push(ElkPoint::new(tgt_x, tgt_y + parallel_offset))
    } else {
      let lane_info = lane_by_edge
        .get(edge.id)
        .unwrap_or(default_lane_info((src_x + tgt_x) / 2.0))
      let lane = lane_info.lane
      match (lane_info.split_lane, lane_info.split_coord) {
        (Some(split_lane), Some(split_coord)) => {
          edge.bend_points.push(ElkPoint::new(lane, src_y + parallel_offset))
          edge.bend_points.push(
            ElkPoint::new(lane, split_coord + parallel_offset),
          )
          edge.bend_points.push(
            ElkPoint::new(split_lane, split_coord + parallel_offset),
          )
          edge.bend_points.push(
            ElkPoint::new(split_lane, tgt_y + parallel_offset),
          )
        }
        _ => {
          edge.bend_points.push(ElkPoint::new(lane, src_y + parallel_offset))
          edge.bend_points.push(ElkPoint::new(lane, tgt_y + parallel_offset))
        }
      }
    }
  }
}

///|
/// Assign routing slots to edges to minimize crossings
#warnings("-unused_value")
fn assign_routing_slots(
  graph : LGraph,
  edge_spacing : Double,
  is_vertical : Bool,
) -> Unit {
  // Pre-compute source positions for sorting
  let edge_sort_keys : Map[String, Double] = {}
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    match graph.get_node(edge.source_id) {
      Some(src) =>
        if is_vertical {
          edge_sort_keys[edge.id] = src.x + src.width / 2.0
        } else {
          edge_sort_keys[edge.id] = src.y + src.height / 2.0
        }
      None => ()
    }
  }

  // Group edges by the layer pair they cross
  let layer_edges : Map[String, Array[LEdge]] = {}
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let src_node = graph.get_node(edge.source_id)
    let tgt_node = graph.get_node(edge.target_id)
    guard src_node is Some(src) && tgt_node is Some(tgt) else { continue }
    if src.layer != tgt.layer {
      let key = src.layer.to_string() + "_" + tgt.layer.to_string()
      if !layer_edges.contains(key) {
        layer_edges[key] = []
      }
      match layer_edges.get(key) {
        Some(arr) => arr.push(edge)
        None => ()
      }
    }
  }

  // For each layer pair, assign slots to avoid crossings
  for pair in layer_edges.iter() {
    let (_, edges) = pair
    if edges.length() <= 1 {
      continue
    }

    // Sort edges by their source position to minimize crossings
    edges.sort_by(fn(a, b) {
      let a_key = edge_sort_keys.get(a.id).unwrap_or(0.0)
      let b_key = edge_sort_keys.get(b.id).unwrap_or(0.0)
      if a_key < b_key {
        -1
      } else if a_key > b_key {
        1
      } else {
        a.id.compare(b.id)
      }
    })

    // Adjust bend points to use different routing slots
    // Use alternating offsets (0, -0.5, +0.5, -1.0, +1.0, ...) * edge_spacing.
    for i, edge in edges {
      if edge.bend_points.length() >= 2 {
        let offset = if i == 0 {
          0.0
        } else {
          let slot = ((i + 1) / 2).to_double() * edge_spacing * 0.5
          let sign = if i % 2 == 1 { -1.0 } else { 1.0 }
          sign * slot
        }
        // Create new bend points with adjusted coordinates
        let new_bends : Array[ElkPoint] = []
        for bp in edge.bend_points {
          if is_vertical {
            // Shift horizontal segment vertically
            new_bends.push(ElkPoint::new(bp.x, bp.y + offset))
          } else {
            // Shift vertical segment horizontally
            new_bends.push(ElkPoint::new(bp.x + offset, bp.y))
          }
        }
        // Replace bend points
        edge.bend_points.clear()
        for bp in new_bends {
          edge.bend_points.push(bp)
        }
      }
    }
  }
}

// ============================================================================
// Self-Loop Routing
// ============================================================================

///|
/// Route self-loop edges on the given edge list.
fn route_self_loop_edges(
  graph : LGraph,
  edges : Array[LEdge],
  _direction : LayoutDirection,
) -> Unit {
  for edge in edges {
    if edge.source_id != edge.target_id {
      continue
    }
    match graph.get_node(edge.source_id) {
      Some(node) => {
        edge.bend_points.clear()

        // Route around the right side of the node.
        // Use parallel_offset (assigned by SELF_LOOP_ROUTER) to avoid overlap.
        let right_x = node.x + node.width + 20.0 + edge.parallel_offset
        let top_y = node.y
        let bottom_y = node.y + node.height

        // Create loop path: bottom-right, bottom-out, top-out, top-right.
        edge.bend_points.push(ElkPoint::new(node.x + node.width, bottom_y))
        edge.bend_points.push(ElkPoint::new(right_x, bottom_y))
        edge.bend_points.push(ElkPoint::new(right_x, top_y))
        edge.bend_points.push(ElkPoint::new(node.x + node.width, top_y))
      }
      None => ()
    }
  }
}

///|
/// Route self-loop edges present in the graph.
#warnings("-unused_value")
fn route_self_loops(graph : LGraph, direction : LayoutDirection) -> Unit {
  route_self_loop_edges(graph, graph.edges, direction)
}

// ============================================================================
// Edge Straightening
// ============================================================================

///|
/// Straighten edges by removing unnecessary bend points
fn straighten_edges(graph : LGraph) -> Unit {
  for edge in graph.edges {
    if edge.bend_points.length() < 2 {
      continue
    }

    // Remove collinear bend points
    let new_bends : Array[ElkPoint] = []
    let mut prev : ElkPoint? = None
    for bp in edge.bend_points {
      match prev {
        Some(p) =>
          // Check if this point is collinear with the previous segment
          if new_bends.length() > 0 {
            let last = new_bends[new_bends.length() - 1]
            // Check if all three points are collinear
            if !is_collinear(last, p, bp) {
              new_bends.push(p)
            }
          } else {
            new_bends.push(p)
          }
        None => ()
      }
      prev = Some(bp)
    }

    // Add the last point if needed
    match prev {
      Some(p) => new_bends.push(p)
      None => ()
    }

    // Update bend points
    edge.bend_points.clear()
    for bp in new_bends {
      edge.bend_points.push(bp)
    }
  }
}

///|
/// Check if three points are collinear
fn is_collinear(p1 : ElkPoint, p2 : ElkPoint, p3 : ElkPoint) -> Bool {
  let dx1 = p2.x - p1.x
  let dy1 = p2.y - p1.y
  let dx2 = p3.x - p2.x
  let dy2 = p3.y - p2.y

  // Check if the cross product is approximately zero
  let cross = dx1 * dy2 - dy1 * dx2
  cross.abs() < 0.001
}
