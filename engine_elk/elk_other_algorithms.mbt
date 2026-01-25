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
/// Minimal, deterministic implementations for non-layered ELK algorithms.
///
/// These are intentionally simple placeholders so `elk.algorithm` dispatch is
/// functional and testable. They aim for determinism and reasonable spacing,
/// not full behavioral parity with upstream ELK (yet).

///|
fn stable_sort_children_by_id(node : ElkNode) -> Unit {
  node.children.sort_by(fn(a, b) { a.id.compare(b.id) })
}

///|
fn stable_sort_edges_by_id(node : ElkNode) -> Unit {
  node.edges.sort_by(fn(a, b) { a.id.compare(b.id) })
}

///|
fn route_edges_straight(root : ElkNode) -> Unit {
  stable_sort_edges_by_id(root)
  for edge in root.edges {
    guard edge.is_simple() else { continue }
    let src_id = edge.source().unwrap_or("")
    let tgt_id = edge.target().unwrap_or("")
    let src = root.find_node(src_id)
    let tgt = root.find_node(tgt_id)
    guard src is Some(s) && tgt is Some(t) else { continue }
    let sx = s.x + s.width / 2.0
    let sy = s.y + s.height / 2.0
    let tx = t.x + t.width / 2.0
    let ty = t.y + t.height / 2.0
    let section = ElkEdgeSection::new(edge.id + "_s0")
    section.start_point = ElkPoint::new(sx, sy)
    section.end_point = ElkPoint::new(tx, ty)
    edge.sections.clear()
    edge.sections.push(section)
  }
}

///|
fn layout_children_grid(
  root : ElkNode,
  options : LayoutOptions,
  columns : Int,
) -> Unit {
  stable_sort_children_by_id(root)
  let n = root.children.length()
  if n == 0 {
    root.width = 0.0
    root.height = 0.0
    return
  }
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let spacing_x = options.node_node_spacing.unwrap_or(20.0)
  let spacing_y = options.node_node_between_layers_spacing.unwrap_or(20.0)
  let cols = if columns <= 0 {
    // ceil(sqrt(n)) without needing `sqrt`.
    let mut c = 1
    while c * c < n {
      c = c + 1
    }
    c
  } else {
    columns
  }
  let mut max_x = 0.0
  let mut max_y = 0.0
  for i, child in root.children {
    let row = i / cols
    let col = i % cols
    child.x = padding.left + col.to_double() * (child.width + spacing_x)
    child.y = padding.top + row.to_double() * (child.height + spacing_y)
    let right = child.x + child.width
    let bottom = child.y + child.height
    if right > max_x {
      max_x = right
    }
    if bottom > max_y {
      max_y = bottom
    }
  }
  root.width = max_x + padding.right
  root.height = max_y + padding.bottom
}

///|
fn layout_children_circle(root : ElkNode, options : LayoutOptions) -> Unit {
  stable_sort_children_by_id(root)
  let n = root.children.length()
  if n == 0 {
    root.width = 0.0
    root.height = 0.0
    return
  }
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let spacing = options.node_node_spacing.unwrap_or(20.0)
  let mut max_dim = 0.0
  for child in root.children {
    max_dim = max_double(max_dim, max_double(child.width, child.height))
  }

  // Avoid trig dependencies: approximate a circle using a square perimeter.
  let radius = (max_dim + spacing) * n.to_double() / 4.0
  let cx = padding.left + radius + max_dim / 2.0
  let cy = padding.top + radius + max_dim / 2.0
  for i, child in root.children {
    let u = i.to_double() / n.to_double() * 4.0
    let seg = u.to_int()
    let f = u - seg.to_double()
    let (dx, dy) = match seg {
      0 => (1.0, f)
      1 => (1.0 - f, 1.0)
      2 => (0.0, 1.0 - f)
      _ => (f, 0.0)
    }
    child.x = cx + (dx - 0.5) * 2.0 * radius - child.width / 2.0
    child.y = cy + (dy - 0.5) * 2.0 * radius - child.height / 2.0
  }
  root.width = cx + radius + padding.right + max_dim / 2.0
  root.height = cy + radius + padding.bottom + max_dim / 2.0
}

///|
fn hash_u32(s : String) -> Int {
  // Deterministic string hash (stays within signed Int range).
  let mut h : Int = 216613626
  for i in 0..<s.length() {
    let b = s.code_unit_at(i).to_int()
    h = h ^ b
    h = (h * 16777619) & 0x7fffffff
  }
  h
}

///|
fn layout_children_deterministic_random(
  root : ElkNode,
  options : LayoutOptions,
) -> Unit {
  stable_sort_children_by_id(root)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let spacing = options.node_node_spacing.unwrap_or(20.0)
  let mut max_x = 0.0
  let mut max_y = 0.0
  for child in root.children {
    let hx = hash_u32(child.id + ":x").to_double() / 2147483647.0
    let hy = hash_u32(child.id + ":y").to_double() / 2147483647.0
    child.x = padding.left + hx * 200.0
    child.y = padding.top + hy * 200.0
    let right = child.x + child.width
    let bottom = child.y + child.height
    if right > max_x {
      max_x = right
    }
    if bottom > max_y {
      max_y = bottom
    }
  }
  root.width = max_x + padding.right + spacing
  root.height = max_y + padding.bottom + spacing
}

///|
fn elk_fixed_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  route_edges_straight(graph)
}

///|
fn elk_random_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_deterministic_random(graph, options)
  route_edges_straight(graph)
}

///|
fn elk_box_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_grid(graph, options, 3)
  route_edges_straight(graph)
}

///|
fn elk_rect_packing_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  // Defaults from elk-reference `RectPacking.melk`.
  //
  // Notes on parity:
  // - ELK's width approximation considers padding when evaluating aspect ratio:
  //   (drawingW + paddingH) / (drawingH + paddingV) ~= aspectRatio
  // - The packing itself operates in drawing coordinates (no padding), and
  //   padding is applied afterwards by translating children by (left, top).
  let spacing = options.node_node_spacing.unwrap_or(15.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(15.0))
  let aspect_ratio = options.aspect_ratio.unwrap_or(1.3)
  ensure_sizes(graph, options)

  // Preserve input order; rectpacking keeps order stable.
  let n = graph.children.length()
  if n == 0 {
    graph.width = padding.left + padding.right
    graph.height = padding.top + padding.bottom
    route_edges_straight(graph)
    return
  }

  // If a target width is explicitly provided (elk-reference WidthApproximationStrategy.TARGET_WIDTH),
  // If the caller provides ELK rectpacking options via `options.custom`, switch
  // to an elk-reference-compatible code path (phased width approximation +
  // packing strategy selection). Otherwise, keep the existing simple placeholder
  // behavior for stability.
  let mut custom_target_width : Double? = None
  let mut custom_packing_strategy : String? = None
  let mut custom_optimization_goal : String? = None
  let mut custom_last_place_shift : Bool? = None
  match options.custom {
    Some(custom) => {
      match
        custom.get("org.eclipse.elk.rectpacking.widthApproximation.targetWidth") {
        Some(PropertyValue::Double(v)) if v > 0.0 =>
          custom_target_width = Some(v)
        _ => ()
      }
      match custom.get("org.eclipse.elk.rectpacking.packing.strategy") {
        Some(PropertyValue::Enum(v)) => custom_packing_strategy = Some(v)
        Some(PropertyValue::String(v)) => custom_packing_strategy = Some(v)
        _ => ()
      }
      match
        custom.get(
          "org.eclipse.elk.rectpacking.widthApproximation.optimizationGoal",
        ) {
        Some(PropertyValue::Enum(v)) => custom_optimization_goal = Some(v)
        Some(PropertyValue::String(v)) => custom_optimization_goal = Some(v)
        _ => ()
      }
      match
        custom.get(
          "org.eclipse.elk.rectpacking.widthApproximation.lastPlaceShift",
        ) {
        Some(PropertyValue::Bool(v)) => custom_last_place_shift = Some(v)
        _ => ()
      }
    }
    None => ()
  }
  if custom_target_width is Some(_) || custom_packing_strategy is Some(_) {
    let pad_h = padding.left + padding.right
    let pad_v = padding.top + padding.bottom

    // Phase 1: compute a target width.
    let target_width = match custom_target_width {
      Some(tw) => tw
      None => {
        let goal = rp_parse_optimization_goal(custom_optimization_goal)
        let lp_shift = custom_last_place_shift.unwrap_or(true)
        let (w, _h) = rp_greedy_width_approximation(
          graph.children,
          aspect_ratio,
          goal,
          lp_shift,
          spacing,
          padding,
        )
        w
      }
    }

    // Phase 2: packing strategy.
    let packing_strategy = custom_packing_strategy.unwrap_or("COMPACTION")
    let (drawing_w, drawing_h) = match packing_strategy {
      "NONE" => {
        // Keep coordinates from width approximation (if any), or user-provided coordinates.
        let (w, h) = rp_calculate_rectangles_dimensions(graph.children)
        (max_double(w, target_width), h)
      }
      "SIMPLE" => {
        rp_reset_coordinates(graph.children)
        let (w, h) = rp_simple_place_rows(graph.children, target_width, spacing)
        (w, h)
      }
      _ =>
        // Default: COMPACTION
        rp_compact_layout(graph.children, target_width, spacing)
    }

    // Apply padding (ELK's `applyPadding`).
    for child in graph.children {
      child.x = child.x + padding.left
      child.y = child.y + padding.top
    }
    graph.width = drawing_w + pad_h
    graph.height = drawing_h + pad_v
    route_edges_straight(graph)
    return
  }

  // Approximate a target drawing width (excluding padding). We solve the
  // area/aspect ratio equation using a continuous approximation and then clamp
  // to feasible bounds.
  let mut total_area = 0.0
  let mut max_width = 0.0
  let mut max_single_row_width = 0.0
  for i, child in graph.children {
    total_area = total_area + child.width * child.height
    max_width = max_double(max_width, child.width)
    max_single_row_width = max_single_row_width + child.width
    if i > 0 {
      max_single_row_width = max_single_row_width + spacing
    }
  }
  let pad_h = padding.left + padding.right
  let pad_v = padding.top + padding.bottom
  let b = pad_h - aspect_ratio * pad_v
  let disc = b * b + 4.0 * aspect_ratio * total_area
  let mut target_width = (-b + disc.sqrt()) / 2.0
  // Clamp to feasible range: at least the widest child; at most all in one row.
  target_width = clamp_double(target_width, max_width, max_single_row_width)

  // Place rectangles in rows using the chosen target width (drawing coords).
  let mut x = 0.0
  let mut y = 0.0
  let mut row_height = 0.0
  let mut drawing_w = 0.0
  for child in graph.children {
    if x > 0.0 && x + child.width > target_width {
      x = 0.0
      y = y + row_height + spacing
      row_height = 0.0
    }
    child.x = x
    child.y = y
    x = x + child.width + spacing
    row_height = max_double(row_height, child.height)
    drawing_w = max_double(drawing_w, child.x + child.width)
  }
  let drawing_h = y + row_height

  // Apply padding by translating rectangles (ELK's `applyPadding`).
  for child in graph.children {
    child.x = child.x + padding.left
    child.y = child.y + padding.top
  }
  graph.width = drawing_w + pad_h
  graph.height = drawing_h + pad_v
  route_edges_straight(graph)
}

///|
fn rp_calculate_rectangles_dimensions(
  rectangles : Array[ElkNode],
) -> (Double, Double) {
  // elk-reference DrawingUtil.calculateDimensions(rectangles)
  let mut max_width = 0.0
  let mut max_height = 0.0
  for node in rectangles {
    max_width = max_double(max_width, node.width + node.x)
    max_height = max_double(max_height, node.height + node.y)
  }
  (max_width, max_height)
}

///|
fn rp_simple_place_rows(
  rectangles : Array[ElkNode],
  target_width : Double,
  node_node_spacing : Double,
) -> (Double, Double) {
  // Minimal port of elk-reference p2packing.SimplePlacement's row placement
  // (without block/stack bookkeeping).
  let mut x = 0.0
  let mut y = 0.0
  let mut row_height = 0.0
  let mut drawing_w = 0.0
  for rect in rectangles {
    if x > 0.0 && x + rect.width > target_width {
      x = 0.0
      y = y + row_height + node_node_spacing
      row_height = 0.0
    }
    rect.x = x
    rect.y = y
    x = x + rect.width + node_node_spacing
    row_height = max_double(row_height, rect.height)
    drawing_w = max_double(drawing_w, rect.x + rect.width)
  }
  let drawing_h = y + row_height
  (drawing_w, drawing_h)
}

///|
fn elk_top_down_packing_layout(
  graph : ElkNode,
  options : LayoutOptions,
) -> Unit {
  ensure_sizes(graph, options)
  layout_children_grid(graph, options, 1)
  route_edges_straight(graph)
}

///|
fn clamp_double(v : Double, lo : Double, hi : Double) -> Double {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn java_random_init(seed : Int) -> Ref[UInt64] {
  let multiplier : UInt64 = 25214903917UL
  let mask : UInt64 = 281474976710655UL
  { val: (seed.to_uint64() ^ multiplier) & mask }
}

///|
fn java_random_next_bits(state : Ref[UInt64], bits : Int) -> UInt64 {
  let multiplier : UInt64 = 25214903917UL
  let addend : UInt64 = 11UL
  let mask : UInt64 = 281474976710655UL
  state.val = (state.val * multiplier + addend) & mask
  state.val >> (48 - bits)
}

///|
fn java_random_next_double(state : Ref[UInt64]) -> Double {
  let hi = java_random_next_bits(state, 26)
  let lo = java_random_next_bits(state, 27)
  let val = (hi << 27) + lo
  val.to_double() / 9007199254740992.0
}

///|
priv struct ForceComponent {
  indices : Array[Int]
  priority : Int
  minx : Double
  miny : Double
  width : Double
  height : Double
}

///|
fn force_collect_edges(graph : ElkNode) -> Array[(Int, Int)] {
  let id_to_index : Map[String, Int] = {}
  stable_sort_children_by_id(graph)
  for i, node in graph.children {
    id_to_index[node.id] = i
  }
  let edges : Array[(Int, Int)] = []
  stable_sort_edges_by_id(graph)
  for edge in graph.edges {
    guard edge.is_simple() else { continue }
    let src_id = edge.source().unwrap_or("")
    let tgt_id = edge.target().unwrap_or("")
    match (id_to_index.get(src_id), id_to_index.get(tgt_id)) {
      (Some(src), Some(tgt)) => edges.push((src, tgt))
      _ => ()
    }
  }
  edges
}

///|
fn force_connected_components(
  node_count : Int,
  edges : Array[(Int, Int)],
) -> Array[Array[Int]] {
  if node_count == 0 {
    return []
  }
  let adjacency : Array[Array[Int]] = []
  for _ in 0..<node_count {
    adjacency.push([])
  }
  for e in edges {
    let (a, b) = e
    adjacency[a].push(b)
    adjacency[b].push(a)
  }
  let visited : Array[Bool] = []
  for _ in 0..<node_count {
    visited.push(false)
  }
  let components : Array[Array[Int]] = []
  for start in 0..<node_count {
    if visited[start] {
      continue
    }
    let stack : Array[Int] = [start]
    visited[start] = true
    let comp : Array[Int] = []
    while stack.pop() is Some(cur) {
      comp.push(cur)
      for next in adjacency[cur] {
        if !visited[next] {
          visited[next] = true
          stack.push(next)
        }
      }
    }
    comp.sort_by(fn(a, b) { a - b })
    components.push(comp)
  }
  components
}

///|
fn force_component_bounds(
  indices : Array[Int],
  centers_x : Array[Double],
  centers_y : Array[Double],
  widths : Array[Double],
  heights : Array[Double],
) -> (Double, Double, Double, Double) {
  let mut minx = 0.0
  let mut miny = 0.0
  let mut maxx = 0.0
  let mut maxy = 0.0
  let mut first = true
  for idx in indices {
    let cx = centers_x[idx]
    let cy = centers_y[idx]
    let w = widths[idx]
    let h = heights[idx]
    let left = cx - w / 2.0
    let top = cy - h / 2.0
    let right = cx + w / 2.0
    let bottom = cy + h / 2.0
    if first {
      minx = left
      miny = top
      maxx = right
      maxy = bottom
      first = false
    } else {
      if left < minx {
        minx = left
      }
      if top < miny {
        miny = top
      }
      if right > maxx {
        maxx = right
      }
      if bottom > maxy {
        maxy = bottom
      }
    }
  }
  (minx, miny, maxx, maxy)
}

///|
fn force_layout_fruchterman_reingold_component(
  indices : Array[Int],
  edges : Array[(Int, Int)],
  centers_x : Array[Double],
  centers_y : Array[Double],
  widths : Array[Double],
  heights : Array[Double],
  radii : Array[Double],
  node_spacing : Double,
  iterations : Int,
  initial_temperature : Double,
  interactive : Bool,
  rng_state : Ref[UInt64],
) -> Unit {
  let n = indices.length()
  if n <= 0 {
    return
  }
  let local_index : Map[Int, Int] = {}
  for i, idx in indices {
    local_index[idx] = i
  }
  let adjacency : Array[Array[Int]] = []
  for _ in 0..<n {
    let row : Array[Int] = []
    for _ in 0..<n {
      row.push(0)
    }
    adjacency.push(row)
  }
  let mut edge_count = 0
  for e in edges {
    let (src, tgt) = e
    match (local_index.get(src), local_index.get(tgt)) {
      (Some(ls), Some(lt)) => {
        adjacency[ls][lt] = adjacency[ls][lt] + 1
        edge_count = edge_count + 1
      }
      _ => ()
    }
  }
  if !interactive {
    let pos_scale = n.to_double()
    for idx in indices {
      centers_x[idx] = java_random_next_double(rng_state) * pos_scale
      centers_y[idx] = java_random_next_double(rng_state) * pos_scale
    }
  }
  let mut total_width = 0.0
  let mut total_height = 0.0
  for idx in indices {
    total_width = total_width + widths[idx]
    total_height = total_height + heights[idx]
  }
  let area = total_width * total_height
  let k = if n > 0 {
    (area / (2.0 * n.to_double())).sqrt() * (node_spacing * 0.01)
  } else {
    0.0
  }
  let disp_bound = max_double(
    n.to_double() * 16.0 + edge_count.to_double(),
    256.0,
  )
  let threshold = if iterations <= 0 {
    initial_temperature
  } else {
    initial_temperature / iterations.to_double()
  }
  let mut temperature = initial_temperature
  for _ in 0..<iterations {
    temperature = temperature - threshold
    if temperature <= 0.0 {
      break
    }
    let disp_x : Array[Double] = []
    let disp_y : Array[Double] = []
    for _ in 0..<n {
      disp_x.push(0.0)
      disp_y.push(0.0)
    }
    for a in 0..<n {
      let ia = indices[a]
      let ax = centers_x[ia]
      let ay = centers_y[ia]
      let ar = radii[ia]
      for b in 0..<n {
        if a == b {
          continue
        }
        let ib = indices[b]
        let mut dx = centers_x[ib] - ax
        let mut dy = centers_y[ib] - ay
        let mut length = (dx * dx + dy * dy).sqrt()
        if length == 0.0 {
          dx = (java_random_next_double(rng_state) - 0.5) * 2.0
          dy = (java_random_next_double(rng_state) - 0.5) * 2.0
          length = (dx * dx + dy * dy).sqrt()
          if length == 0.0 {
            continue
          }
        }
        let br = radii[ib]
        let d = max_double(0.0, length - ar - br)
        let repulsive = if d > 0.0 { k * k / d } else { k * k * 100.0 }
        let mut force = repulsive
        let connection = adjacency[a][b] + adjacency[b][a]
        if connection > 0 {
          let attractive = d * d / k
          force = force - attractive * connection.to_double()
        }
        let scale = force * temperature / length
        disp_x[b] = disp_x[b] + dx * scale
        disp_y[b] = disp_y[b] + dy * scale
      }
    }
    for i in 0..<n {
      let idx = indices[i]
      let bounded_x = clamp_double(disp_x[i], -disp_bound, disp_bound)
      let bounded_y = clamp_double(disp_y[i], -disp_bound, disp_bound)
      centers_x[idx] = centers_x[idx] + bounded_x
      centers_y[idx] = centers_y[idx] + bounded_y
    }
  }
}

///|
fn elk_force_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  let resolved = resolve_options_for_graph(options, graph)
  ensure_sizes(graph, resolved)
  stable_sort_children_by_id(graph)
  let n = graph.children.length()
  if n == 0 {
    graph.width = 0.0
    graph.height = 0.0
    route_edges_straight(graph)
    return
  }
  let node_spacing = resolved.node_node_spacing.unwrap_or(80.0)
  let iterations = resolved.force_iterations.unwrap_or(300)
  let initial_temperature = resolved.force_temperature.unwrap_or(0.001)
  let aspect_ratio = resolved.aspect_ratio.unwrap_or(1.6)
  let separate = resolved.separate_connected_components.unwrap_or(true)
  let interactive = resolved.interactive.unwrap_or(false)
  let padding = resolved.padding.unwrap_or(ElkPadding::uniform(50.0))
  let centers_x : Array[Double] = []
  let centers_y : Array[Double] = []
  let widths : Array[Double] = []
  let heights : Array[Double] = []
  let radii : Array[Double] = []
  for node in graph.children {
    widths.push(node.width)
    heights.push(node.height)
    radii.push(
      (node.width * node.width + node.height * node.height).sqrt() / 2.0,
    )
    centers_x.push(node.x + node.width / 2.0)
    centers_y.push(node.y + node.height / 2.0)
  }
  let edges = force_collect_edges(graph)
  let rng_state = java_random_init(1)
  let components = if separate {
    force_connected_components(n, edges)
  } else {
    let all : Array[Int] = []
    for i in 0..<n {
      all.push(i)
    }
    [all]
  }
  let component_layouts : Array[ForceComponent] = []
  for indices in components {
    force_layout_fruchterman_reingold_component(
      indices, edges, centers_x, centers_y, widths, heights, radii, node_spacing,
      iterations, initial_temperature, interactive, rng_state,
    )
    let (minx, miny, maxx, maxy) = force_component_bounds(
      indices, centers_x, centers_y, widths, heights,
    )
    component_layouts.push({
      indices,
      priority: indices.length(),
      minx,
      miny,
      width: maxx - minx,
      height: maxy - miny,
    })
  }
  component_layouts.sort_by(fn(a, b) {
    let prio = b.priority - a.priority
    if prio != 0 {
      prio
    } else {
      let area_a = a.width * a.height
      let area_b = b.width * b.height
      if area_a < area_b {
        -1
      } else if area_a > area_b {
        1
      } else {
        0
      }
    }
  })
  let mut max_row_width = 0.0
  let mut total_area = 0.0
  for comp in component_layouts {
    max_row_width = max_double(max_row_width, comp.width)
    total_area = total_area + comp.width * comp.height
  }
  max_row_width = max_double(max_row_width, total_area.sqrt() * aspect_ratio)
  let mut xpos = 0.0
  let mut ypos = 0.0
  let mut highest_box = 0.0
  for comp in component_layouts {
    if xpos > 0.0 && xpos + comp.width > max_row_width {
      xpos = 0.0
      ypos = ypos + highest_box + node_spacing
      highest_box = 0.0
    }
    let dx = xpos - comp.minx
    let dy = ypos - comp.miny
    for idx in comp.indices {
      centers_x[idx] = centers_x[idx] + dx
      centers_y[idx] = centers_y[idx] + dy
    }
    highest_box = max_double(highest_box, comp.height)
    xpos = xpos + comp.width + node_spacing
  }
  let all_indices : Array[Int] = []
  for i in 0..<n {
    all_indices.push(i)
  }
  let (minx, miny, maxx, maxy) = force_component_bounds(
    all_indices, centers_x, centers_y, widths, heights,
  )
  let shift_x = padding.left - minx
  let shift_y = padding.top - miny
  for i, node in graph.children {
    let cx = centers_x[i] + shift_x
    let cy = centers_y[i] + shift_y
    node.x = cx - node.width / 2.0
    node.y = cy - node.height / 2.0
  }
  graph.width = maxx - minx + padding.left + padding.right
  graph.height = maxy - miny + padding.top + padding.bottom
  route_edges_straight(graph)
}

///|
fn elk_stress_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_circle(graph, options)
  route_edges_straight(graph)
}

///|
#warnings("-unused_value")
fn elk_nodes_overlap(a : ElkNode, b : ElkNode) -> Bool {
  let ax2 = a.x + a.width
  let ay2 = a.y + a.height
  let bx2 = b.x + b.width
  let by2 = b.y + b.height
  !(ax2 <= b.x || bx2 <= a.x || ay2 <= b.y || by2 <= a.y)
}

///|
fn update_root_bounds_from_children(
  graph : ElkNode,
  padding : ElkPadding,
) -> Unit {
  let mut max_x = padding.left
  let mut max_y = padding.top
  for child in graph.children {
    max_x = max_double(max_x, child.x + child.width)
    max_y = max_double(max_y, child.y + child.height)
  }
  graph.width = max_x + padding.right
  graph.height = max_y + padding.bottom
}

///|
fn elk_radial_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  // Minimal radial tree layout: place nodes by BFS depth on concentric circles.
  // (Real ELK radial has many more options; this is a parity-oriented baseline.)
  ensure_sizes(graph, options)
  let spacing = options.node_node_spacing.unwrap_or(20.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let n = graph.children.length()
  if n == 0 {
    graph.width = 0.0
    graph.height = 0.0
    route_edges_straight(graph)
    return
  }

  // Build adjacency over the children indices.
  let id_to_index : Map[String, Int] = {}
  for i, node in graph.children {
    id_to_index[node.id] = i
  }
  let adjacency : Array[Array[Int]] = []
  for _ in 0..<n {
    adjacency.push([])
  }
  for edge in graph.edges {
    guard edge.is_simple() else { continue }
    let src_id = edge.source().unwrap_or("")
    let tgt_id = edge.target().unwrap_or("")
    match (id_to_index.get(src_id), id_to_index.get(tgt_id)) {
      (Some(s), Some(t)) => {
        adjacency[s].push(t)
        adjacency[t].push(s)
      }
      _ => ()
    }
  }

  // Choose root as first child (deterministic).
  let root_idx = 0
  let depth : Array[Int] = []
  for _ in 0..<n {
    depth.push(-1)
  }
  let queue : Array[Int] = [root_idx]
  depth[root_idx] = 0
  let mut q = 0
  while q < queue.length() {
    let cur = queue[q]
    q = q + 1
    for nxt in adjacency[cur] {
      if depth[nxt] < 0 {
        depth[nxt] = depth[cur] + 1
        queue.push(nxt)
      }
    }
  }

  // Group nodes by depth.
  let mut max_depth = 0
  for d in depth {
    if d > max_depth {
      max_depth = d
    }
  }
  let levels : Array[Array[Int]] = []
  for _ in 0..<(max_depth + 1) {
    levels.push([])
  }
  for i in 0..<n {
    let d = if depth[i] < 0 { max_depth + 1 } else { depth[i] }
    if d >= levels.length() {
      levels.push([])
      max_depth = d
    }
    levels[d].push(i)
  }

  // Radius step based on spacing and max node dimension.
  let mut max_dim = 0.0
  for node in graph.children {
    max_dim = max_double(max_dim, max_double(node.width, node.height))
  }
  let radius_step = max_dim + spacing
  let cx = padding.left + (max_depth.to_double() + 1.0) * radius_step
  let cy = padding.top + (max_depth.to_double() + 1.0) * radius_step
  for level, indices in levels {
    let radius = level.to_double() * radius_step
    let m = indices.length()
    if m == 0 {
      continue
    }
    for k, idx in indices {
      // Avoid trig deps; approximate circle with square perimeter.
      let u = k.to_double() / m.to_double() * 4.0
      let seg = u.to_int()
      let f = u - seg.to_double()
      let (dx, dy) = match seg {
        0 => (1.0, f)
        1 => (1.0 - f, 1.0)
        2 => (0.0, 1.0 - f)
        _ => (f, 0.0)
      }
      let node = graph.children[idx]
      let px = cx + (dx - 0.5) * 2.0 * radius - node.width / 2.0
      let py = cy + (dy - 0.5) * 2.0 * radius - node.height / 2.0
      node.x = px
      node.y = py
    }
  }
  update_root_bounds_from_children(graph, padding)
  route_edges_straight(graph)
}

///|
fn elk_disco_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  // DisCo packs connected components; component internals unchanged by default.
  ensure_sizes(graph, options)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(0.0))
  let spacing = options.component_component_spacing.unwrap_or(20.0)
  let aspect_ratio = options.aspect_ratio.unwrap_or(1.6)
  let n = graph.children.length()
  if n == 0 {
    graph.width = 0.0
    graph.height = 0.0
    route_edges_straight(graph)
    return
  }

  // Build edges between child indices (preserve current order).
  let id_to_index : Map[String, Int] = {}
  for i, node in graph.children {
    id_to_index[node.id] = i
  }
  let edges : Array[(Int, Int)] = []
  for edge in graph.edges {
    guard edge.is_simple() else { continue }
    match
      (
        id_to_index.get(edge.source().unwrap_or("")),
        id_to_index.get(edge.target().unwrap_or("")),
      ) {
      (Some(s), Some(t)) => edges.push((s, t))
      _ => ()
    }
  }
  let components = force_connected_components(n, edges)

  // Compute bounds per component.
  let comps : Array[ForceComponent] = []
  for indices in components {
    let mut minx = 0.0
    let mut miny = 0.0
    let mut maxx = 0.0
    let mut maxy = 0.0
    let mut first = true
    for idx in indices {
      let node = graph.children[idx]
      let left = node.x
      let top = node.y
      let right = node.x + node.width
      let bottom = node.y + node.height
      if first {
        minx = left
        miny = top
        maxx = right
        maxy = bottom
        first = false
      } else {
        if left < minx {
          minx = left
        }
        if top < miny {
          miny = top
        }
        if right > maxx {
          maxx = right
        }
        if bottom > maxy {
          maxy = bottom
        }
      }
    }
    comps.push({
      indices,
      priority: indices.length(),
      minx,
      miny,
      width: maxx - minx,
      height: maxy - miny,
    })
  }

  // Pack components in rows similar to ELK force ComponentsProcessor.
  let mut max_row_width = 0.0
  let mut total_area = 0.0
  for comp in comps {
    max_row_width = max_double(max_row_width, comp.width)
    total_area = total_area + comp.width * comp.height
  }
  max_row_width = max_double(max_row_width, total_area.sqrt() * aspect_ratio)
  let mut xpos = 0.0
  let mut ypos = 0.0
  let mut highest = 0.0
  for comp in comps {
    if xpos > 0.0 && xpos + comp.width > max_row_width {
      xpos = 0.0
      ypos = ypos + highest + spacing
      highest = 0.0
    }
    let dx = xpos - comp.minx
    let dy = ypos - comp.miny
    for idx in comp.indices {
      let node = graph.children[idx]
      node.x = node.x + dx
      node.y = node.y + dy
    }
    highest = max_double(highest, comp.height)
    xpos = xpos + comp.width + spacing
  }

  // Shift into padded coordinates.
  let mut minx = 0.0
  let mut miny = 0.0
  let mut maxx = 0.0
  let mut maxy = 0.0
  let mut first = true
  for node in graph.children {
    let left = node.x
    let top = node.y
    let right = node.x + node.width
    let bottom = node.y + node.height
    if first {
      minx = left
      miny = top
      maxx = right
      maxy = bottom
      first = false
    } else {
      if left < minx {
        minx = left
      }
      if top < miny {
        miny = top
      }
      if right > maxx {
        maxx = right
      }
      if bottom > maxy {
        maxy = bottom
      }
    }
  }
  let shift_x = padding.left - minx
  let shift_y = padding.top - miny
  for node in graph.children {
    node.x = node.x + shift_x
    node.y = node.y + shift_y
  }
  graph.width = maxx - minx + padding.left + padding.right
  graph.height = maxy - miny + padding.top + padding.bottom
  route_edges_straight(graph)
}

///|
fn elk_spore_compaction_layout(
  graph : ElkNode,
  options : LayoutOptions,
) -> Unit {
  spore_compaction_layout_impl(graph, options)
}

///|
fn elk_spore_overlap_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  spore_overlap_layout_impl(graph, options)
}
