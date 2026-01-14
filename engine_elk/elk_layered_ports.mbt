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
fn infer_side_from_port_geometry(port : LPort, node : LNode) -> ElkPortSide? {
  let tol = 1.0

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
fn process_port_sides(graph : LGraph, direction : LayoutDirection) -> Unit {
  // Phase 1: explicit port metadata.
  for node in graph.nodes {
    for port in node.ports {
      if port.side is Undefined {
        let side = match port_side_from_properties(port) {
          Some(s) => Some(s)
          None => infer_side_from_port_geometry(port, node)
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
    match edge.source_port_id {
      Some(pid) =>
        for port in src.ports {
          if port.id == pid && port.side is Undefined {
            port.side = src_side
          }
        }
      None => ()
    }
    match edge.target_port_id {
      Some(pid) =>
        for port in tgt.ports {
          if port.id == pid && port.side is Undefined {
            port.side = tgt_side
          }
        }
      None => ()
    }
  }
}

///|
/// Sort ports in each node for determinism.
fn sort_ports(graph : LGraph, options : LayoutOptions) -> Unit {
  let sorting_strategy = match options.port_constraints {
    Some(FixedOrder) => InputOrder
    _ =>
      match options.port_sorting_strategy {
        Some(s) => s
        None => InputOrder
      }
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
  for node in graph.nodes {
    // Group by side.
    let north : Array[LPort] = []
    let east : Array[LPort] = []
    let south : Array[LPort] = []
    let west : Array[LPort] = []
    for port in node.ports {
      match port.side {
        North => north.push(port)
        East => east.push(port)
        South => south.push(port)
        West => west.push(port)
        Undefined => ()
      }
    }
    fn place_along(
      ports : Array[LPort],
      length : Double,
      make : (Double, LPort) -> Unit,
    ) -> Unit {
      if ports.is_empty() {
        return
      }
      if ports.length() == 1 {
        make(length / 2.0, ports[0])
        return
      }
      // Spread evenly along the side.
      for i, port in ports {
        let t = i.to_double() / (ports.length() - 1).to_double()
        make(t * length, port)
      }
    }

    // Normalize usable lengths.
    let usable_w = max_double(0.0, node.width - 2.0 * border)
    let usable_h = max_double(0.0, node.height - 2.0 * border)
    place_along(north, usable_w, fn(pos, port) {
      port.x = border + pos
      port.y = 0.0
      port.width = 0.0
      port.height = 0.0
    })
    place_along(south, usable_w, fn(pos, port) {
      port.x = border + pos
      port.y = node.height
      port.width = 0.0
      port.height = 0.0
    })
    place_along(west, usable_h, fn(pos, port) {
      port.x = 0.0
      port.y = border + pos
      port.width = 0.0
      port.height = 0.0
    })
    place_along(east, usable_h, fn(pos, port) {
      port.x = node.width
      port.y = border + pos
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
