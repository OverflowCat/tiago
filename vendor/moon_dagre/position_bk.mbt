///|
pub struct PositionBkAlignment {
  root : Map[String, String]
  align : Map[String, String]
}

///|
pub fn position_bk_x(g : Graph) -> Map[String, Double] {
  let layering = build_layer_matrix(g)
  let conflicts = position_bk_find_type1_conflicts(g, layering)
  let type2 = position_bk_find_type2_conflicts(g, layering)
  // dagre JS uses `Object.assign(type1, type2)` (shallow overwrite), not a deep union.
  // This matters because each conflict map is keyed by the first endpoint.
  position_bk_assign_conflicts(conflicts, type2)
  let xss : Map[String, Map[String, Double]] = Map::new()
  for vert in ["u", "d"] {
    let base_layering = if vert == "u" {
      position_bk_copy_layering(layering)
    } else {
      position_bk_reverse_layering(layering)
    }
    for horiz in ["l", "r"] {
      let adjusted_layering = if horiz == "r" {
        position_bk_reverse_each_layer(base_layering)
      } else {
        position_bk_copy_layering(base_layering)
      }
      let neighbor_fn : (String) -> Array[String] = if vert == "u" {
        (v : String) => g.predecessors(v)
      } else {
        (v : String) => g.successors(v)
      }
      let alignment = position_bk_vertical_alignment(
        g, adjusted_layering, conflicts, neighbor_fn,
      )
      let mut xs = position_bk_horizontal_compaction(
        g,
        adjusted_layering,
        alignment.root,
        alignment.align,
        reverse_sep=horiz == "r",
      )
      if horiz == "r" {
        let mirrored : Map[String, Double] = Map::new()
        xs.each((v, x) => mirrored.set(v, -x))
        xs = mirrored
      }
      xss.set(vert + horiz, xs)
    }
  }
  let smallest = position_bk_find_smallest_width_alignment(g, xss)
  position_bk_align_coordinates(xss, smallest)
  if g.graph().get_string("align") is Some(align) {
    position_bk_balance(xss, align~)
  } else {
    position_bk_balance(xss)
  }
}

///|
pub fn position_bk_find_type1_conflicts(
  g : Graph,
  layering : Array[Array[String]],
) -> Map[String, Set[String]] {
  let conflicts : Map[String, Set[String]] = Map::new()
  if layering.length() <= 1 {
    return conflicts
  }
  let mut prev_layer = layering[0]
  for layer_idx = 1; layer_idx < layering.length(); layer_idx = layer_idx + 1 {
    let layer = layering[layer_idx]
    let mut k0 = 0
    let mut scan_pos = 0
    let prev_layer_length = prev_layer.length()
    let last_node = if layer.is_empty() {
      ""
    } else {
      layer[layer.length() - 1]
    }
    for i = 0; i < layer.length(); i = i + 1 {
      let v = layer[i]
      if position_bk_is_layer_hole(v) {
        continue
      }
      let w = position_bk_find_other_inner_segment_node(g, v)
      let k1 = if w is Some(w) {
        g.node(w).get_int_or("order", 0)
      } else {
        prev_layer_length
      }
      let mut is_boundary = false
      if w is Some(_) {
        is_boundary = true
      }
      if !is_boundary && v == last_node {
        is_boundary = true
      }
      if is_boundary {
        for j = scan_pos; j <= i; j = j + 1 {
          let scan_node = layer[j]
          if position_bk_is_layer_hole(scan_node) {
            continue
          }
          for u in g.predecessors(scan_node) {
            let u_label = g.node(u)
            let scan_label = g.node(scan_node)
            let u_pos = u_label.get_int_or("order", 0)
            let crosses = u_pos < k0 || k1 < u_pos
            let both_dummy = position_bk_is_dummy(u_label) &&
              position_bk_is_dummy(scan_label)
            if crosses && !both_dummy {
              position_bk_add_conflict(conflicts, u, scan_node)
            }
          }
        }
        scan_pos = i + 1
        k0 = k1
      }
    }
    prev_layer = layer
  }
  conflicts
}

///|
pub fn position_bk_find_type2_conflicts(
  g : Graph,
  layering : Array[Array[String]],
) -> Map[String, Set[String]] {
  let conflicts : Map[String, Set[String]] = Map::new()
  if layering.length() <= 1 {
    return conflicts
  }
  for i = 1; i < layering.length(); i = i + 1 {
    let north = layering[i - 1]
    let south = layering[i]
    let mut prev_north_pos = -1
    let mut next_north_pos : Int? = None
    let mut south_pos = 0
    for south_lookahead = 0
        south_lookahead < south.length()
        south_lookahead = south_lookahead + 1 {
      let v = south[south_lookahead]
      if position_bk_is_layer_hole(v) {
        continue
      }
      if g.node(v).get_string("dummy") is Some(dummy) {
        if dummy == "border" {
          let predecessors = g.predecessors(v)
          if !predecessors.is_empty() {
            next_north_pos = Some(
              g.node(predecessors[0]).get_int_or("order", 0),
            )
            position_bk_scan_type2_conflicts(
              g,
              conflicts,
              south,
              south_pos,
              south_lookahead,
              Some(prev_north_pos),
              next_north_pos,
            )
            south_pos = south_lookahead
            if next_north_pos is Some(next_pos) {
              prev_north_pos = next_pos
            }
          }
        }
      }
      position_bk_scan_type2_conflicts(
        g,
        conflicts,
        south,
        south_pos,
        south.length(),
        next_north_pos,
        Some(north.length()),
      )
    }
  }
  conflicts
}

///|
fn position_bk_scan_type2_conflicts(
  g : Graph,
  conflicts : Map[String, Set[String]],
  south : Array[String],
  south_pos : Int,
  south_end : Int,
  prev_north_border : Int?,
  next_north_border : Int?,
) -> Unit {
  for i = south_pos; i < south_end; i = i + 1 {
    let v = south[i]
    if position_bk_is_layer_hole(v) {
      continue
    }
    let v_node = g.node(v)
    if position_bk_is_dummy(v_node) {
      for u in g.predecessors(v) {
        let u_node = g.node(u)
        if position_bk_is_dummy(u_node) {
          let u_order = u_node.get_int_or("order", 0)
          let crosses_left = if prev_north_border is Some(prev) {
            u_order < prev
          } else {
            false
          }
          let crosses_right = if next_north_border is Some(next) {
            u_order > next
          } else {
            false
          }
          if crosses_left || crosses_right {
            position_bk_add_conflict(conflicts, u, v)
          }
        }
      }
    }
  }
}

///|
fn position_bk_find_other_inner_segment_node(g : Graph, v : String) -> String? {
  let node = g.node(v)
  if position_bk_is_dummy(node) {
    for u in g.predecessors(v) {
      if position_bk_is_dummy(g.node(u)) {
        return Some(u)
      }
    }
  }
  None
}

///|
pub fn position_bk_add_conflict(
  conflicts : Map[String, Set[String]],
  v : String,
  w : String,
) -> Unit {
  let mut lhs = v
  let mut rhs = w
  // JS compares strings lexicographically by UTF-16 code units. MoonBit's default
  // `Compare` for String is shortlex, so use `lexical_compare` to match JS behavior.
  if lhs.lexical_compare(rhs) > 0 {
    let tmp = lhs
    lhs = rhs
    rhs = tmp
  }
  if conflicts.get(lhs) is Some(conflicts_v) {
    conflicts_v.add(rhs)
  } else {
    let conflicts_v = Set::new()
    conflicts_v.add(rhs)
    conflicts.set(lhs, conflicts_v)
  }
}

///|
pub fn position_bk_has_conflict(
  conflicts : Map[String, Set[String]],
  v : String,
  w : String,
) -> Bool {
  let mut lhs = v
  let mut rhs = w
  if lhs.lexical_compare(rhs) > 0 {
    let tmp = lhs
    lhs = rhs
    rhs = tmp
  }
  if conflicts.get(lhs) is Some(conflicts_v) {
    conflicts_v.contains(rhs)
  } else {
    false
  }
}

///|
pub fn position_bk_vertical_alignment(
  g : Graph,
  layering : Array[Array[String]],
  conflicts : Map[String, Set[String]],
  neighbor_fn : (String) -> Array[String],
) -> PositionBkAlignment {
  ignore(g)
  let root : Map[String, String] = Map::new()
  let align : Map[String, String] = Map::new()
  let pos : Map[String, Int] = Map::new()
  for layer in layering {
    for order = 0; order < layer.length(); order = order + 1 {
      let v = layer[order]
      if position_bk_is_layer_hole(v) {
        continue
      }
      root.set(v, v)
      align.set(v, v)
      pos.set(v, order)
    }
  }
  for layer in layering {
    let mut prev_idx = -1
    for v in layer {
      if position_bk_is_layer_hole(v) {
        continue
      }
      let ws = neighbor_fn(v).copy()
      if !ws.is_empty() {
        ws.sort_by((a, b) => pos.get_or_default(a, 0) - pos.get_or_default(b, 0))
        let mp = (ws.length() - 1).to_double() / 2.0
        let mut i = mp.floor().to_int()
        let il = mp.ceil().to_int()
        while i <= il {
          let w = ws[i]
          if align.get_or_default(v, v) == v &&
            prev_idx < pos.get_or_default(w, 0) &&
            !position_bk_has_conflict(conflicts, v, w) {
            align.set(w, v)
            let new_root = root.get_or_default(w, w)
            align.set(v, new_root)
            root.set(v, new_root)
            prev_idx = pos.get_or_default(w, 0)
          }
          i = i + 1
        }
      }
    }
  }
  { root, align }
}

///|
pub fn position_bk_horizontal_compaction(
  g : Graph,
  layering : Array[Array[String]],
  root : Map[String, String],
  align : Map[String, String],
  reverse_sep? : Bool = false,
) -> Map[String, Double] {
  let xs : Map[String, Double] = Map::new()
  let block_g = position_bk_build_block_graph(g, layering, root, reverse_sep)
  let border_type = if reverse_sep { "borderLeft" } else { "borderRight" }
  position_bk_iterate(
    block_g,
    elem => {
      let mut max_x = 0.0
      for e in block_g.in_edges(elem) {
        let candidate = xs.get_or_default(e.v, 0.0) +
          position_bk_numeric(block_g.edge_obj(e))
        if candidate > max_x {
          max_x = candidate
        }
      }
      xs.set(elem, max_x)
    },
    elem => block_g.predecessors(elem),
  )
  position_bk_iterate(
    block_g,
    elem => {
      let mut min_x = 9_999_999_999.0
      for e in block_g.out_edges(elem) {
        let candidate = xs.get_or_default(e.w, 0.0) -
          position_bk_numeric(block_g.edge_obj(e))
        if candidate < min_x {
          min_x = candidate
        }
      }
      let node = g.node(elem)
      if min_x != 9_999_999_999.0 &&
        node.get_string_or("borderType", "") != border_type {
        xs.set(elem, position_bk_max(xs.get_or_default(elem, 0.0), min_x))
      }
    },
    elem => block_g.successors(elem),
  )
  align.each((v, _) => {
    let r = root.get_or_default(v, v)
    xs.set(v, xs.get_or_default(r, 0.0))
  })
  xs
}

///|
fn position_bk_iterate(
  block_g : Graph,
  set_xs_func : (String) -> Unit,
  next_nodes_func : (String) -> Array[String],
) -> Unit {
  let stack = block_g.nodes().copy()
  let visited : Map[String, Bool] = Map::new()
  while true {
    if stack.pop() is Some(elem) {
      if visited.get_or_default(elem, false) {
        set_xs_func(elem)
      } else {
        visited.set(elem, true)
        stack.push(elem)
        for next_elem in next_nodes_func(elem) {
          stack.push(next_elem)
        }
      }
    } else {
      break
    }
  }
}

///|
fn position_bk_build_block_graph(
  g : Graph,
  layering : Array[Array[String]],
  root : Map[String, String],
  reverse_sep : Bool,
) -> Graph {
  let block_graph = Graph::new()
  let graph_label = g.graph()
  let sep_fn = position_bk_sep(
    graph_label.get_float_or("nodesep", 50.0),
    graph_label.get_float_or("edgesep", 20.0),
    reverse_sep,
  )
  for layer in layering {
    let mut u : String? = None
    for v in layer {
      if position_bk_is_layer_hole(v) {
        continue
      }
      let v_root = root.get_or_default(v, v)
      block_graph.set_node(v_root)
      if u is Some(u) {
        let u_root = root.get_or_default(u, u)
        let prev_max = position_bk_numeric(block_graph.edge(u_root, v_root))
        let next_sep = sep_fn(g, v, u)
        block_graph.set_edge(
          u_root,
          v_root,
          label=value_float(position_bk_max(next_sep, prev_max)),
        )
      }
      u = Some(v)
    }
  }
  block_graph
}

///|
pub fn position_bk_find_smallest_width_alignment(
  g : Graph,
  xss : Map[String, Map[String, Double]],
) -> Map[String, Double] {
  let mut best_width = 9_999_999_999.0
  let mut best : Map[String, Double] = Map::new()
  // Match JS iteration order (`Object.values(xss)` on insertion order):
  // ul -> ur -> dl -> dr. This also guarantees deterministic tie-breaking.
  for key in ["ul", "ur", "dl", "dr"] {
    if xss.get(key) is Some(xs) {
      let mut max = -9_999_999_999.0
      let mut min = 9_999_999_999.0
      xs.each((v, x) => {
        let half_width = position_bk_width(g, v) / 2.0
        max = position_bk_max(max, x + half_width)
        min = position_bk_min(min, x - half_width)
      })
      let width = max - min
      if width < best_width {
        best_width = width
        best = xs
      }
    }
  }
  best
}

///|
pub fn position_bk_align_coordinates(
  xss : Map[String, Map[String, Double]],
  align_to : Map[String, Double],
) -> Unit {
  let align_to_min = position_bk_map_min(align_to)
  let align_to_max = position_bk_map_max(align_to)
  for vert in ["u", "d"] {
    for horiz in ["l", "r"] {
      let alignment = vert + horiz
      if xss.get(alignment) is Some(xs) {
        let mut delta = align_to_min - position_bk_map_min(xs)
        if horiz != "l" {
          delta = align_to_max - position_bk_map_max(xs)
        }
        if delta != 0.0 {
          let shifted : Map[String, Double] = Map::new()
          xs.each((v, x) => shifted.set(v, x + delta))
          xss.set(alignment, shifted)
        }
      }
    }
  }
}

///|
pub fn position_bk_balance(
  xss : Map[String, Map[String, Double]],
  align? : String,
) -> Map[String, Double] {
  let out : Map[String, Double] = Map::new()
  let ul = xss.get_or_default("ul", Map::new())
  ul.each((v, _) => {
    if align is Some(align) {
      let key = align.to_lower()
      if xss.get(key) is Some(xs) {
        out.set(v, xs.get_or_default(v, 0.0))
      } else {
        out.set(v, ul.get_or_default(v, 0.0))
      }
    } else {
      let values = [
        xss.get_or_default("ul", Map::new()).get_or_default(v, 0.0),
        xss.get_or_default("ur", Map::new()).get_or_default(v, 0.0),
        xss.get_or_default("dl", Map::new()).get_or_default(v, 0.0),
        xss.get_or_default("dr", Map::new()).get_or_default(v, 0.0),
      ]
      values.sort_by(position_bk_compare_double)
      out.set(v, (values[1] + values[2]) / 2.0)
    }
  })
  out
}

///|
fn position_bk_sep(
  node_sep : Double,
  edge_sep : Double,
  reverse_sep : Bool,
) -> (Graph, String, String) -> Double {
  (g : Graph, v : String, w : String) => {
    let v_label = g.node(v)
    let w_label = g.node(w)
    let mut sum = 0.0
    let mut delta = 0.0
    sum = sum + v_label.get_float_or("width", 0.0) / 2.0
    if v_label.get_string("labelpos") is Some(labelpos) {
      let lower = labelpos.to_lower()
      if lower == "l" {
        delta = -v_label.get_float_or("width", 0.0) / 2.0
      } else if lower == "r" {
        delta = v_label.get_float_or("width", 0.0) / 2.0
      }
    }
    if delta != 0.0 {
      let delta_contrib = if reverse_sep { delta } else { -delta }
      sum = sum + delta_contrib
    }
    delta = 0.0
    let v_sep = if position_bk_is_dummy(v_label) {
      edge_sep / 2.0
    } else {
      node_sep / 2.0
    }
    let w_sep = if position_bk_is_dummy(w_label) {
      edge_sep / 2.0
    } else {
      node_sep / 2.0
    }
    sum = sum + v_sep
    sum = sum + w_sep
    sum = sum + w_label.get_float_or("width", 0.0) / 2.0
    if w_label.get_string("labelpos") is Some(labelpos) {
      let lower = labelpos.to_lower()
      if lower == "l" {
        delta = w_label.get_float_or("width", 0.0) / 2.0
      } else if lower == "r" {
        delta = -w_label.get_float_or("width", 0.0) / 2.0
      }
    }
    if delta != 0.0 {
      let delta_contrib = if reverse_sep { delta } else { -delta }
      sum = sum + delta_contrib
    }
    sum
  }
}

///|
fn position_bk_width(g : Graph, v : String) -> Double {
  g.node(v).get_float_or("width", 0.0)
}

///|
fn position_bk_assign_conflicts(
  target : Map[String, Set[String]],
  source : Map[String, Set[String]],
) -> Unit {
  source.each((v, ws) => target.set(v, ws))
}

///|
fn position_bk_is_dummy(node : Attrs) -> Bool {
  node.contains("dummy")
}

///|
fn position_bk_is_layer_hole(v : String) -> Bool {
  v == ""
}

///|
fn position_bk_numeric(value : Value?) -> Double {
  if value_as_float(value) is Some(v) {
    v
  } else if value_as_int(value) is Some(v) {
    v.to_double()
  } else if value_as_attrs(value) is Some(attrs) {
    attrs.get_float_or("weight", 0.0)
  } else {
    0.0
  }
}

///|
fn position_bk_copy_layering(
  layering : Array[Array[String]],
) -> Array[Array[String]] {
  layering.map(layer => layer.copy())
}

///|
fn position_bk_reverse_layering(
  layering : Array[Array[String]],
) -> Array[Array[String]] {
  let out = []
  for i = layering.length() - 1; i >= 0; i = i - 1 {
    out.push(layering[i].copy())
  }
  out
}

///|
fn position_bk_reverse_each_layer(
  layering : Array[Array[String]],
) -> Array[Array[String]] {
  let out = []
  for layer in layering {
    let reversed = []
    for i = layer.length() - 1; i >= 0; i = i - 1 {
      let v = layer[i]
      if !position_bk_is_layer_hole(v) {
        reversed.push(v)
      }
    }
    out.push(reversed)
  }
  out
}

///|
fn position_bk_compare_double(a : Double, b : Double) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn position_bk_map_min(xs : Map[String, Double]) -> Double {
  let mut min = 9_999_999_999.0
  xs.each((_, x) => if x < min { min = x })
  min
}

///|
fn position_bk_map_max(xs : Map[String, Double]) -> Double {
  let mut max = -9_999_999_999.0
  xs.each((_, x) => if x > max { max = x })
  max
}

///|
fn position_bk_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn position_bk_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
