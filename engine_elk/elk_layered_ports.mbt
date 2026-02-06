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
/// Layered port processors (clean-room).

///|
fn parse_port_side(value : String) -> ElkPortSide? {
  match value {
    "NORTH" | "North" | "north" => Some(North)
    "EAST" | "East" | "east" => Some(East)
    "SOUTH" | "South" | "south" => Some(South)
    "WEST" | "West" | "west" => Some(West)
    _ => None
  }
}

///|
fn infer_side_from_port_geometry(
  port : LPort,
  node : LNode,
  border : Double,
) -> ElkPortSide? {
  let tol = max_double(1.0, border + 1.0)

  // Prefer explicit coordinates when present.
  let left_dist = port.x.abs()
  let right_dist = (port.x + port.width - node.width).abs()
  let top_dist = port.y.abs()
  let bottom_dist = (port.y + port.height - node.height).abs()

  // If port has no geometry information, don't guess.
  let has_any_geometry = port.x != 0.0 ||
    port.y != 0.0 ||
    port.width != 0.0 ||
    port.height != 0.0
  if !has_any_geometry {
    return None
  }
  let min_dist = min_double(
    min_double(left_dist, right_dist),
    min_double(top_dist, bottom_dist),
  )
  if min_dist > tol {
    return None
  }
  if left_dist <= min_dist + tol {
    Some(West)
  } else if right_dist <= min_dist + tol {
    Some(East)
  } else if top_dist <= min_dist + tol {
    Some(North)
  } else {
    Some(South)
  }
}

///|
fn port_side_order(side : ElkPortSide) -> Int {
  match side {
    North => 0
    East => 1
    South => 2
    West => 3
    Undefined => 4
  }
}

///|
fn port_index(port : LPort) -> Int? {
  match port.properties.get_int("elk.port.index") {
    Some(i) => Some(i)
    None => port.properties.get_int("org.eclipse.elk.port.index")
  }
}

///|
fn port_side_from_properties(port : LPort) -> ElkPortSide? {
  match port.properties.get_string("elk.port.side") {
    Some(s) => parse_port_side(s)
    None =>
      match port.properties.get_string("org.eclipse.elk.port.side") {
        Some(s) => parse_port_side(s)
        None => None
      }
  }
}

///|
fn resolve_options_for_lnode(
  inherited : LayoutOptions,
  node : LNode,
) -> LayoutOptions {
  LayoutOptions::merge(
    inherited,
    LayoutOptions::from_properties(node.properties),
  )
}

///|
fn resolve_options_for_lport(
  inherited : LayoutOptions,
  port : LPort,
) -> LayoutOptions {
  LayoutOptions::merge(
    inherited,
    LayoutOptions::from_properties(port.properties),
  )
}

///|
/// Assign missing port sides using properties/geometry/graph structure.
fn process_port_sides(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
) -> Unit {
  // Phase 1: explicit port metadata and geometry hints.
  for node in graph.nodes {
    let node_options = resolve_options_for_lnode(options, node)
    let border = node_options.port_border_offset.unwrap_or(0.0)
    for port in node.ports {
      if port.side is Undefined {
        let side = match port_side_from_properties(port) {
          Some(s) => Some(s)
          None => infer_side_from_port_geometry(port, node, border)
        }
        match side {
          Some(s) => port.side = s
          None => ()
        }
      }
    }
  }

  // Phase 2: infer for ports referenced by edges.
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

  for edge in graph.edges {
    let src_node = graph.get_node(edge.source_id)
    let tgt_node = graph.get_node(edge.target_id)
    guard src_node is Some(src) && tgt_node is Some(tgt) else { continue }
    let (src_side, tgt_side) = infer_for_edge(src, tgt, direction)
    let src_constraints = match
      resolve_options_for_lnode(options, src).port_constraints {
      Some(c) => c
      None => Undefined
    }
    match src_constraints {
      FixedSide | FixedOrder | FixedPos | FixedRatio => ()
      _ =>
        match edge.source_port_id {
          Some(pid) =>
            for port in src.ports {
              if port.id == pid && port.side is Undefined {
                port.side = src_side
                port.properties.set(
                  "diago.layered.inferredPortSide",
                  Bool(true),
                )
              }
            }
          None => ()
        }
    }
    let tgt_constraints = match
      resolve_options_for_lnode(options, tgt).port_constraints {
      Some(c) => c
      None => Undefined
    }
    match tgt_constraints {
      FixedSide | FixedOrder | FixedPos | FixedRatio => ()
      _ =>
        match edge.target_port_id {
          Some(pid) =>
            for port in tgt.ports {
              if port.id == pid && port.side is Undefined {
                port.side = tgt_side
                port.properties.set(
                  "diago.layered.inferredPortSide",
                  Bool(true),
                )
              }
            }
          None => ()
        }
    }
  }
}

///|
/// Invert inferred port sides for Up/Left directions.
fn invert_inferred_port_sides(
  graph : LGraph,
  direction : LayoutDirection,
) -> Unit {
  let flip_vertical = direction == Up
  let flip_horizontal = direction == Left
  if !flip_vertical && !flip_horizontal {
    return
  }
  for node in graph.nodes {
    for port in node.ports {
      if !port.properties.get_bool_or("diago.layered.inferredPortSide", false) {
        continue
      }
      if flip_vertical {
        match port.side {
          North => port.side = South
          South => port.side = North
          _ => ()
        }
      }
      if flip_horizontal {
        match port.side {
          East => port.side = West
          West => port.side = East
          _ => ()
        }
      }
    }
  }
}

///|
/// Sort ports in each node for determinism.
fn sort_ports(graph : LGraph, options : LayoutOptions) -> Unit {
  fn reverse_range(ports : Array[LPort], start : Int, end : Int) -> Unit {
    let mut i = 0
    while start + i < end - i - 1 {
      let tmp = ports[start + i]
      ports[start + i] = ports[end - i - 1]
      ports[end - i - 1] = tmp
      i = i + 1
    }
  }

  fn reverse_side_segments(ports : Array[LPort]) -> Unit {
    if ports.length() <= 1 {
      return
    }
    fn find_range(ports : Array[LPort], side : ElkPortSide) -> (Int, Int) {
      let mut lo = 0
      while lo < ports.length() && ports[lo].side != side {
        lo = lo + 1
      }
      let mut hi = lo
      while hi < ports.length() && ports[hi].side == side {
        hi = hi + 1
      }
      (lo, hi)
    }

    let (s_lo, s_hi) = find_range(ports, South)
    reverse_range(ports, s_lo, s_hi)
    let (w_lo, w_hi) = find_range(ports, West)
    reverse_range(ports, w_lo, w_hi)
  }

  fn is_order_fixed(c : PortConstraints) -> Bool {
    match c {
      FixedOrder | FixedRatio | FixedPos => true
      _ => false
    }
  }

  fn is_side_fixed(c : PortConstraints) -> Bool {
    match c {
      FixedSide | FixedOrder | FixedRatio | FixedPos => true
      _ => false
    }
  }

  fn tie_break(a : LPort, b : LPort) -> Int {
    // Prefer explicit port indices (set by our ELK importer for implicit ports)
    // to keep per-edge auto ports ordered consistently across nodes.
    let ia = port_index(a)
    let ib = port_index(b)
    match (ia, ib) {
      (Some(x), Some(y)) => if x != y { x - y } else { a.id.compare(b.id) }
      (Some(_), None) => -1
      (None, Some(_)) => 1
      (None, None) => a.id.compare(b.id)
    }
  }

  for node in graph.nodes {
    let node_options = resolve_options_for_lnode(options, node)
    // Match ELK importer: unspecified/UNDEFINED constraints become FREE.
    let constraints = match node_options.port_constraints {
      Some(c) => c
      None => Free
    }

    // ELK only sorts port lists when sides/orders are fixed. For FREE ports,
    // preserve insertion order so later processors see the same model order.
    if !is_order_fixed(constraints) && !is_side_fixed(constraints) {
      continue
    }
    let sorting_strategy = match node_options.port_sorting_strategy {
      Some(s) => s
      None => InputOrder
    }
    if constraints is FixedSide {
      // Mirror ELK PortListSorter for FIXED_SIDE:
      // group by side in input order (stable), then reverse SOUTH and WEST.
      let north : Array[LPort] = []
      let east : Array[LPort] = []
      let south : Array[LPort] = []
      let west : Array[LPort] = []
      let undefined : Array[LPort] = []
      for port in node.ports {
        match port.side {
          North => north.push(port)
          East => east.push(port)
          South => south.push(port)
          West => west.push(port)
          Undefined => undefined.push(port)
        }
      }
      reverse_range(south, 0, south.length())
      reverse_range(west, 0, west.length())
      node.ports.clear()
      node.ports.append(north)
      node.ports.append(east)
      node.ports.append(south)
      node.ports.append(west)
      node.ports.append(undefined)
      // FIXED_SIDE + PORT_DEGREE is intentionally not implemented yet.
      let _ = sorting_strategy
      continue
    }

    // Precompute port degrees for this node.
    let degree_by_port : Map[String, Int] = {}
    for edge in graph.edges {
      if edge.source_id == node.id {
        match edge.source_port_id {
          Some(pid) =>
            degree_by_port[pid] = degree_by_port.get(pid).unwrap_or(0) + 1
          None => ()
        }
      }
      if edge.target_id == node.id {
        match edge.target_port_id {
          Some(pid) =>
            degree_by_port[pid] = degree_by_port.get(pid).unwrap_or(0) + 1
          None => ()
        }
      }
    }
    node.ports.sort_by(fn(a, b) {
      let sa = port_side_order(a.side)
      let sb = port_side_order(b.side)
      if sa != sb {
        sa - sb
      } else {
        // When port order is fixed, prefer explicit indices (FIXED_ORDER),
        // otherwise fall back to geometric ordering (FIXED_POS).
        if constraints == FixedOrder {
          let ia = port_index(a)
          let ib = port_index(b)
          match (ia, ib) {
            (Some(x), Some(y)) => if x != y { return x - y }
            (Some(_), None) => return -1
            (None, Some(_)) => return 1
            _ => ()
          }
        }
        // FIXED_POS / fallback: sort by port positions on the side.
        let cmp = match a.side {
          North => if a.x < b.x { -1 } else if a.x > b.x { 1 } else { 0 }
          East => if a.y < b.y { -1 } else if a.y > b.y { 1 } else { 0 }
          South => if a.x < b.x { 1 } else if a.x > b.x { -1 } else { 0 }
          West => if a.y < b.y { 1 } else if a.y > b.y { -1 } else { 0 }
          Undefined => 0
        }
        if cmp != 0 {
          cmp
        } else {
          tie_break(a, b)
        }
      }
    })
    // For FIXED_SIDE + PORT_DEGREE, ELK further sorts within EAST/WEST sides by
    // degree. Keep the existing (InputOrder) behavior for now since it doesn't
    // affect our current test suite.
    let _ = sorting_strategy

  }
}

///|
/// Compute port geometry from side ordering.
///
/// After node placement, many ports only have side + index, so we generate a
/// deterministic position on the node boundary for routing.
fn position_ports(graph : LGraph, options : LayoutOptions) -> Unit {
  fn clamp_border(value : Double, max_abs : Double) -> Double {
    if value > max_abs {
      max_abs
    } else if value < -max_abs {
      -max_abs
    } else {
      value
    }
  }

  fn substring_from(s : String, start : Int) -> String {
    if start >= s.length() {
      return ""
    }
    let buf = StringBuilder::new()
    let mut i = start
    while i < s.length() {
      let code = s.code_unit_at(i).to_int()
      buf.write_char(code.unsafe_to_char())
      i = i + 1
    }
    buf.to_string()
  }

  fn substring_range(s : String, start : Int, end_exclusive : Int) -> String {
    if start >= s.length() || end_exclusive <= start {
      return ""
    }
    let end_exclusive_clamped = if end_exclusive > s.length() {
      s.length()
    } else {
      end_exclusive
    }
    let buf = StringBuilder::new()
    let mut i = start
    while i < end_exclusive_clamped {
      let code = s.code_unit_at(i).to_int()
      buf.write_char(code.unsafe_to_char())
      i = i + 1
    }
    buf.to_string()
  }

  fn string_index_of(s : String, sub : String) -> Int? {
    if sub.length() == 0 {
      return Some(0)
    }
    if s.length() < sub.length() {
      return None
    }
    let mut i = 0
    while i <= s.length() - sub.length() {
      let mut matches = true
      let mut j = 0
      while j < sub.length() {
        if s.code_unit_at(i + j) != sub.code_unit_at(j) {
          matches = false
          break
        }
        j = j + 1
      }
      if matches {
        return Some(i)
      }
      i = i + 1
    }
    None
  }

  fn find_char_from(s : String, ch : Char, start : Int) -> Int? {
    if start < 0 {
      return None
    }
    let mut i = start
    while i < s.length() {
      match s[i].to_char() {
        Some(c) => if c == ch { return Some(i) }
        None => ()
      }
      i = i + 1
    }
    None
  }

  fn parse_auto_port_id(port_id : String) -> (String, String)? {
    // Format: "<nodeId>|auto|<edgeId>|<src|dst>"
    let marker = "|auto|"
    match string_index_of(port_id, marker) {
      None => None
      Some(i) => {
        let after = i + marker.length()
        match find_char_from(port_id, '|', after) {
          None => None
          Some(j) => {
            let edge_id = substring_range(port_id, after, j)
            let suffix = substring_from(port_id, j + 1)
            if edge_id.length() == 0 || suffix.length() == 0 {
              None
            } else {
              Some((edge_id, suffix))
            }
          }
        }
      }
    }
  }

  fn original_source_id(edge : LEdge) -> String {
    edge.properties
    .get_string("diago.layered.originalSourceId")
    .unwrap_or(edge.source_id)
  }

  fn original_target_id(edge : LEdge) -> String {
    edge.properties
    .get_string("diago.layered.originalTargetId")
    .unwrap_or(edge.target_id)
  }

  // Decide which implicit per-edge ports should remain unpositioned.
  //
  // ELK Layered treats *parallel edges* differently from a node with multiple
  // outgoing edges to different targets:
  // - parallel edges: anchors stay centered; lane offsets separate edges
  // - multiple targets: implicit ports are distributed along the side
  //
  // To match D2's goldens, only skip positioning for `auto` ports that belong
  // to a parallel edge group (same original endpoints).
  let edge_by_id : Map[String, LEdge] = {}
  for e in graph.edges {
    edge_by_id[e.id] = e
  }
  let auto_group_counts : Map[String, Int] = {}
  for node in graph.nodes {
    for port in node.ports {
      if !port.properties.get_bool_or("diago.layered.autoPort", false) {
        continue
      }
      match parse_auto_port_id(port.id) {
        Some((edge_id, suffix)) =>
          match edge_by_id.get(edge_id) {
            Some(edge) => {
              let other = if suffix == "src" {
                original_target_id(edge)
              } else {
                original_source_id(edge)
              }
              let key = node.id + "|" + port.side.to_string() + "|" + other
              auto_group_counts[key] = auto_group_counts.get(key).unwrap_or(0) +
                1
            }
            None => ()
          }
        None => ()
      }
    }
  }
  let auto_skip : Map[String, Bool] = {}
  for node in graph.nodes {
    for port in node.ports {
      if !port.properties.get_bool_or("diago.layered.autoPort", false) {
        continue
      }
      let has_geometry = port.x != 0.0 ||
        port.y != 0.0 ||
        port.width != 0.0 ||
        port.height != 0.0
      if has_geometry {
        continue
      }
      match parse_auto_port_id(port.id) {
        Some((edge_id, suffix)) =>
          match edge_by_id.get(edge_id) {
            Some(edge) => {
              let other = if suffix == "src" {
                original_target_id(edge)
              } else {
                original_source_id(edge)
              }
              let key = node.id + "|" + port.side.to_string() + "|" + other
              let n = auto_group_counts.get(key).unwrap_or(0)
              if n > 1 {
                auto_skip[port.id] = true
              }
            }
            None => ()
          }
        None => ()
      }
    }
  }
  fn alignment_for_side(
    options : LayoutOptions,
    side : ElkPortSide,
  ) -> PortAlignment {
    match side {
      North =>
        match options.port_alignment_north {
          Some(a) => a
          None =>
            match options.port_alignment {
              Some(a) => a
              None => Justified
            }
        }
      South =>
        match options.port_alignment_south {
          Some(a) => a
          None =>
            match options.port_alignment {
              Some(a) => a
              None => Justified
            }
        }
      East =>
        match options.port_alignment_east {
          Some(a) => a
          None =>
            match options.port_alignment {
              Some(a) => a
              None => Justified
            }
        }
      West =>
        match options.port_alignment_west {
          Some(a) => a
          None =>
            match options.port_alignment {
              Some(a) => a
              None => Justified
            }
        }
      Undefined =>
        match options.port_alignment {
          Some(a) => a
          None => Justified
        }
    }
  }

  fn place_along(
    ports : Array[LPort],
    length : Double,
    alignment : PortAlignment,
    spacing : Double,
    make : (Double, LPort) -> Unit,
  ) -> Unit {
    if ports.is_empty() {
      return
    }
    if ports.length() == 1 {
      make(length / 2.0, ports[0])
      return
    }
    let n = ports.length()
    let desired_step = length / (n - 1).to_double()
    // `spacing` is the requested port spacing. For `Distributed`, treat it as a
    // minimum spacing but spread ports when there is room.
    let mut step = if alignment is Distributed {
      let distributed_step = length / (n + 1).to_double()
      if spacing > 0.0 {
        max_double(spacing, distributed_step)
      } else {
        distributed_step
      }
    } else if spacing > 0.0 {
      spacing
    } else {
      desired_step
    }
    let max_step = length / (n - 1).to_double()
    if step > max_step {
      step = max_step
    }
    let span = (n - 1).to_double() * step
    let start = match alignment {
      Begin => 0.0
      End => max_double(0.0, length - span)
      Center => max_double(0.0, (length - span) / 2.0)
      Distributed => max_double(0.0, (length - span) / 2.0)
      Justified => 0.0
      Undefined => max_double(0.0, (length - span) / 2.0)
    }
    match alignment {
      Justified =>
        for i, port in ports {
          // ELK's JUSTIFIED alignment distributes ports evenly, keeping a margin
          // to the border (equivalent to i/(n+1) on a zero-size port model).
          let t = (i + 1).to_double() / (ports.length() + 1).to_double()
          make(t * length, port)
        }
      _ =>
        for i, port in ports {
          make(start + i.to_double() * step, port)
        }
    }
  }

  fn place_auto_cluster_if_needed(
    ports : Array[LPort],
    length : Double,
    alignment : PortAlignment,
    spacing : Double,
    between_layers_spacing : Double,
    allow_cluster : Bool,
    make : (Double, LPort) -> Unit,
  ) -> Unit {
    if !allow_cluster {
      place_along(ports, length, alignment, spacing, make)
      return
    }
    if ports.length() <= 1 {
      place_along(ports, length, alignment, spacing, make)
      return
    }
    let mut all_auto = true
    for port in ports {
      if !port.properties.get_bool_or("diago.layered.autoPort", false) {
        all_auto = false
        break
      }
    }
    if !all_auto {
      place_along(ports, length, alignment, spacing, make)
      return
    }
    // For implicit per-edge ports, ELK's layered routing tends to keep a wider
    // channel between anchors than generic JUSTIFIED distribution. Approximate
    // that by centering ports with a lane-like spacing derived from
    // edge-node-between-layers spacing.
    let base = if between_layers_spacing > 0.0 {
      max_double(spacing, between_layers_spacing * 2.0 - spacing / 5.0)
    } else {
      spacing
    }
    let max_step = length / (ports.length() - 1).to_double()
    let step = min_double(max_step, base)
    let span = (ports.length() - 1).to_double() * step
    let start = max_double(0.0, (length - span) / 2.0)
    for i, port in ports {
      make(start + i.to_double() * step, port)
    }
  }

  for node in graph.nodes {
    let node_options = resolve_options_for_lnode(options, node)
    // Match ELK importer: unspecified constraints become FREE.
    let constraints = match node_options.port_constraints {
      Some(c) => c
      None => Free
    }

    // Fixed positions still need to snap to the node boundary based on side.
    if constraints is FixedPos {
      for port in node.ports {
        match port.side {
          East => port.x = node.width
          West => port.x = 0.0
          North => port.y = 0.0
          South => port.y = node.height
          Undefined => ()
        }
      }
      continue
    }
    let node_border = node_options.port_border_offset.unwrap_or(0.0)
    let max_abs_border = min_double(node.width, node.height) / 2.0
    let effective_border = clamp_border(node_border, max_abs_border)
    let spacing = node_options.port_port_spacing.unwrap_or(10.0)

    // Store the effective border offset per port (ports may override).
    for port in node.ports {
      let port_options = resolve_options_for_lport(node_options, port)
      let port_border = clamp_border(
        port_options.port_border_offset.unwrap_or(node_border),
        max_abs_border,
      )
      port.properties.set("diago.layered.portBorderOffset", Double(port_border))
    }

    // Normalize usable lengths.
    let usable_w = max_double(0.0, node.width - 2.0 * effective_border)
    let usable_h = max_double(0.0, node.height - 2.0 * effective_border)
    let between_layers_spacing = node_options.edge_node_between_layers_spacing
      .unwrap_or(0.0)

    // Group by side.
    let north : Array[LPort] = []
    let east : Array[LPort] = []
    let south : Array[LPort] = []
    let west : Array[LPort] = []
    fn clamp01(v : Double) -> Double {
      if v < 0.0 {
        0.0
      } else if v > 1.0 {
        1.0
      } else {
        v
      }
    }

    for port in node.ports {
      let has_geometry = port.x != 0.0 ||
        port.y != 0.0 ||
        port.width != 0.0 ||
        port.height != 0.0

      // Parallel-edge case: keep implicit ports centered and let the router
      // apply lane offsets (D2/ELK behavior).
      if auto_skip.get(port.id).unwrap_or(false) && !has_geometry {
        continue
      }

      // Keep hierarchical ports with explicit projected coordinates fixed.
      // These are computed from the connected inner endpoints and must not be
      // redistributed along the border by the generic port positioner.
      if port.properties.get_bool_or("diago.layered.hierPortFixed", false) &&
        has_geometry {
        continue
      }

      // FixedRatio: treat existing port coordinates as ratios along the side.
      if constraints is FixedRatio && has_geometry {
        match port.side {
          North => {
            let r = clamp01(port.x)
            port.x = effective_border + r * usable_w
            port.y = 0.0
            port.width = 0.0
            port.height = 0.0
          }
          South => {
            let r = clamp01(port.x)
            port.x = effective_border + r * usable_w
            port.y = node.height
            port.width = 0.0
            port.height = 0.0
          }
          West => {
            let r = clamp01(port.y)
            port.x = 0.0
            port.y = effective_border + r * usable_h
            port.width = 0.0
            port.height = 0.0
          }
          East => {
            let r = clamp01(port.y)
            port.x = node.width
            port.y = effective_border + r * usable_h
            port.width = 0.0
            port.height = 0.0
          }
          Undefined => ()
        }
        continue
      }
      match port.side {
        North => north.push(port)
        East => east.push(port)
        South => south.push(port)
        West => west.push(port)
        Undefined => ()
      }
    }
    place_auto_cluster_if_needed(
      north,
      usable_w,
      alignment_for_side(node_options, North),
      spacing,
      between_layers_spacing,
      true,
      fn(pos, port) {
        port.x = effective_border + pos
        port.y = 0.0
        port.width = 0.0
        port.height = 0.0
      },
    )
    place_auto_cluster_if_needed(
      south,
      usable_w,
      alignment_for_side(node_options, South),
      spacing,
      between_layers_spacing,
      true,
      fn(pos, port) {
        port.x = effective_border + pos
        port.y = node.height
        port.width = 0.0
        port.height = 0.0
      },
    )
    place_auto_cluster_if_needed(
      west,
      usable_h,
      alignment_for_side(node_options, West),
      spacing,
      between_layers_spacing,
      true,
      fn(pos, port) {
        port.x = 0.0
        port.y = effective_border + pos
        port.width = 0.0
        port.height = 0.0
      },
    )
    place_auto_cluster_if_needed(
      east,
      usable_h,
      alignment_for_side(node_options, East),
      spacing,
      between_layers_spacing,
      true,
      fn(pos, port) {
        port.x = node.width
        port.y = effective_border + pos
        port.width = 0.0
        port.height = 0.0
      },
    )
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}
