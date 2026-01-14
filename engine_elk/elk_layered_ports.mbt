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
/// Assign missing port sides using properties/geometry/graph structure.
fn process_port_sides(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
) -> Unit {
  let border = options.port_border_offset.unwrap_or(0.0)

  // Phase 1: explicit port metadata.
  for node in graph.nodes {
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
  let constraints = match options.port_constraints {
    Some(c) => c
    None => Undefined
  }
  // Fixed constraints: do not infer sides from graph structure.
  match constraints {
    FixedSide | FixedOrder | FixedPos | FixedRatio => return
    _ => ()
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
    match edge.source_port_id {
      Some(pid) =>
        for port in src.ports {
          if port.id == pid && port.side is Undefined {
            port.side = src_side
            port.properties.set("diago.layered.inferredPortSide", Bool(true))
          }
        }
      None => ()
    }
    match edge.target_port_id {
      Some(pid) =>
        for port in tgt.ports {
          if port.id == pid && port.side is Undefined {
            port.side = tgt_side
            port.properties.set("diago.layered.inferredPortSide", Bool(true))
          }
        }
      None => ()
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
  // For fixed port order, preserve model order.
  match options.port_constraints {
    Some(FixedOrder) => return
    _ => ()
  }
  let sorting_strategy = match options.port_sorting_strategy {
    Some(s) => s
    None => InputOrder
  }
  for node in graph.nodes {
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
        match sorting_strategy {
          PortDegree => {
            let da = degree_by_port.get(a.id).unwrap_or(0)
            let db = degree_by_port.get(b.id).unwrap_or(0)
            if da != db {
              db - da
            } else {
              let ia = port_index(a)
              let ib = port_index(b)
              match (ia, ib) {
                (Some(x), Some(y)) => x - y
                (Some(_), None) => -1
                (None, Some(_)) => 1
                (None, None) => a.id.compare(b.id)
              }
            }
          }
          InputOrder => {
            let ia = port_index(a)
            let ib = port_index(b)
            match (ia, ib) {
              (Some(x), Some(y)) => x - y
              (Some(_), None) => -1
              (None, Some(_)) => 1
              (None, None) => a.id.compare(b.id)
            }
          }
        }
      }
    })
  }
}

///|
/// Compute port geometry from side ordering.
///
/// After node placement, many ports only have side + index, so we generate a
/// deterministic position on the node boundary for routing.
fn position_ports(graph : LGraph, options : LayoutOptions) -> Unit {
  let border = options.port_border_offset.unwrap_or(0.0)
  let spacing = options.port_port_spacing.unwrap_or(10.0)
  let constraints = match options.port_constraints {
    Some(c) => c
    None => Undefined
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
              None => Distributed
            }
        }
      South =>
        match options.port_alignment_south {
          Some(a) => a
          None =>
            match options.port_alignment {
              Some(a) => a
              None => Distributed
            }
        }
      East =>
        match options.port_alignment_east {
          Some(a) => a
          None =>
            match options.port_alignment {
              Some(a) => a
              None => Distributed
            }
        }
      West =>
        match options.port_alignment_west {
          Some(a) => a
          None =>
            match options.port_alignment {
              Some(a) => a
              None => Distributed
            }
        }
      Undefined =>
        match options.port_alignment {
          Some(a) => a
          None => Distributed
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
    let mut step = spacing
    if step <= 0.0 {
      step = length / (ports.length() - 1).to_double()
    }
    let max_step = length / (ports.length() - 1).to_double()
    if step > max_step {
      step = max_step
    }
    let span = (ports.length() - 1).to_double() * step
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
          let t = i.to_double() / (ports.length() - 1).to_double()
          make(t * length, port)
        }
      _ =>
        for i, port in ports {
          make(start + i.to_double() * step, port)
        }
    }
  }

  for node in graph.nodes {
    // If port positions are fixed, don't synthesize positions.
    if constraints is FixedPos {
      continue
    }
    let effective_border = min_double(
      border,
      min_double(node.width, node.height) / 2.0,
    )
    for port in node.ports {
      port.properties.set(
        "diago.layered.portBorderOffset",
        Double(effective_border),
      )
    }

    // Group by side; optionally skip ports that already have explicit geometry.
    let north : Array[LPort] = []
    let east : Array[LPort] = []
    let south : Array[LPort] = []
    let west : Array[LPort] = []
    for port in node.ports {
      let has_geometry = port.x != 0.0 ||
        port.y != 0.0 ||
        port.width != 0.0 ||
        port.height != 0.0

      // When constraints ask for fixed ratios, respect explicit coordinates.
      if constraints is FixedRatio && has_geometry {
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

    // Normalize usable lengths.
    let usable_w = max_double(0.0, node.width - 2.0 * effective_border)
    let usable_h = max_double(0.0, node.height - 2.0 * effective_border)
    place_along(north, usable_w, alignment_for_side(options, North), spacing, fn(
      pos,
      port,
    ) {
      port.x = effective_border + pos
      port.y = 0.0
      port.width = 0.0
      port.height = 0.0
    })
    place_along(south, usable_w, alignment_for_side(options, South), spacing, fn(
      pos,
      port,
    ) {
      port.x = effective_border + pos
      port.y = node.height
      port.width = 0.0
      port.height = 0.0
    })
    place_along(west, usable_h, alignment_for_side(options, West), spacing, fn(
      pos,
      port,
    ) {
      port.x = 0.0
      port.y = effective_border + pos
      port.width = 0.0
      port.height = 0.0
    })
    place_along(east, usable_h, alignment_for_side(options, East), spacing, fn(
      pos,
      port,
    ) {
      port.x = node.width
      port.y = effective_border + pos
      port.width = 0.0
      port.height = 0.0
    })
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
