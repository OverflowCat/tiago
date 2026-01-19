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
/// Crossing counter helpers.
///
/// This is a small, deterministic subset of ELK's layered crossing counting.
/// It is primarily used to support tests ported from elk-reference.

///|
pub struct CrossingsCounter {
  mut left : Array[LNode]
  mut right : Array[LNode]
} derive(Show)

///|
pub fn CrossingsCounter::new() -> CrossingsCounter {
  { left: [], right: [] }
}

///|
/// Initialize the node arrays used for counting.
///
/// Nodes are treated in the order given by the arrays.
pub fn CrossingsCounter::init_for_counting_between(
  self : CrossingsCounter,
  left : Array[LNode],
  right : Array[LNode],
) -> Unit {
  self.left = left
  self.right = right
}

///|
fn port_rank(node : LNode, port_id : String?) -> Int {
  match port_id {
    Some(pid) => {
      for i, p in node.ports {
        if p.id == pid {
          return i
        }
      }
      0
    }
    None => 0
  }
}

///|
fn count_inversions(pairs : Array[(Int, Int)]) -> Int {
  pairs.sort_by(fn(a, b) {
    let (au, al) = a
    let (bu, bl) = b
    if au != bu {
      au - bu
    } else {
      al - bl
    }
  })
  let mut inv = 0
  for i = 0; i < pairs.length(); i = i + 1 {
    for j = i + 1; j < pairs.length(); j = j + 1 {
      let (_, li) = pairs[i]
      let (_, lj) = pairs[j]
      if li > lj {
        inv = inv + 1
      }
    }
  }
  inv
}

///|
fn count_crossings_between_node_arrays(
  upper : Array[LNode],
  lower : Array[LNode],
) -> Int {
  let upper_pos : Map[String, Int] = {}
  let lower_pos : Map[String, Int] = {}
  for i, n in upper {
    upper_pos[n.id] = i
  }
  for i, n in lower {
    lower_pos[n.id] = i
  }
  let edges : Array[(Int, Int)] = []
  let scale = 10_000
  for u_idx, node in upper {
    for e in node.outgoing_edges {
      match lower_pos.get(e.target_id) {
        Some(l_idx) => {
          let ur = u_idx * scale + port_rank(node, e.source_port_id)
          let target = lower[l_idx]
          let lr = l_idx * scale + port_rank(target, e.target_port_id)
          edges.push((ur, lr))
        }
        None => ()
      }
    }
  }
  count_inversions(edges)
}

///|
/// Count crossings between the currently configured left and right node arrays.
pub fn CrossingsCounter::count_crossings_between_layers(
  self : CrossingsCounter,
) -> Int {
  count_crossings_between_node_arrays(self.left, self.right)
}

///|
enum PortTag {
  A
  B
  Other
} derive(Eq, Show)

///|
fn find_port_location(
  left : Array[LNode],
  right : Array[LNode],
  pid : String,
) -> (Bool, LNode) {
  for node in left {
    for p in node.ports {
      if p.id == pid {
        return (true, node)
      }
    }
  }
  for node in right {
    for p in node.ports {
      if p.id == pid {
        return (false, node)
      }
    }
  }
  abort("port not found in configured layers")
}

///|
fn find_port_index(node : LNode, pid : String) -> Int {
  for i, p in node.ports {
    if p.id == pid {
      return i
    }
  }
  -1
}

///|
fn adjusted_port_rank_for_pair(
  node : LNode,
  pid : String?,
  a : String,
  b : String,
  a_before_b : Bool,
) -> Int {
  match pid {
    None => 0
    Some(id) => {
      let ia = find_port_index(node, a)
      let ib = find_port_index(node, b)
      if ia < 0 || ib < 0 {
        return port_rank(node, Some(id))
      }
      let mut idx = port_rank(node, Some(id))
      // Only swap the indices of A and B.
      let swap = if a_before_b { ia > ib } else { ib > ia }
      if !swap {
        return idx
      }
      if id == a {
        idx = ib
      } else if id == b {
        idx = ia
      }
      idx
    }
  }
}

///|
fn count_crossings_involving_ports(
  left : Array[LNode],
  right : Array[LNode],
  port_a : String,
  port_b : String,
  a_before_b : Bool,
) -> Int {
  // Determine port locations.
  let (a_is_left, a_node) = find_port_location(left, right, port_a)
  let (b_is_left, b_node) = find_port_location(left, right, port_b)

  // Only if both ports belong to the same node on the same side can their order change.
  let can_reorder = a_is_left == b_is_left && a_node.id == b_node.id
  let lower_pos : Map[String, Int] = {}
  for i, n in right {
    lower_pos[n.id] = i
  }
  let edges : Array[(Int, Int, PortTag)] = []
  let scale = 10_000
  for u_idx, src in left {
    for e in src.outgoing_edges {
      match lower_pos.get(e.target_id) {
        Some(l_idx) => {
          let tgt = right[l_idx]
          let src_rank = if can_reorder && a_is_left && src.id == a_node.id {
            adjusted_port_rank_for_pair(
              src,
              e.source_port_id,
              port_a,
              port_b,
              a_before_b,
            )
          } else {
            port_rank(src, e.source_port_id)
          }
          let tgt_rank = if can_reorder && !a_is_left && tgt.id == a_node.id {
            adjusted_port_rank_for_pair(
              tgt,
              e.target_port_id,
              port_a,
              port_b,
              a_before_b,
            )
          } else {
            port_rank(tgt, e.target_port_id)
          }
          let ur = u_idx * scale + src_rank
          let lr = l_idx * scale + tgt_rank
          let mut tag = Other
          match e.source_port_id {
            Some(pid) =>
              if pid == port_a {
                tag = A
              } else if pid == port_b {
                tag = B
              }
            None => ()
          }
          match e.target_port_id {
            Some(pid) =>
              if pid == port_a {
                tag = A
              } else if pid == port_b {
                tag = B
              }
            None => ()
          }
          edges.push((ur, lr, tag))
        }
        None => ()
      }
    }
  }

  // Sort by upper rank, then lower.
  edges.sort_by(fn(a, b) {
    let (au, al, _) = a
    let (bu, bl, _) = b
    if au != bu {
      au - bu
    } else {
      al - bl
    }
  })
  let mut crossings = 0
  for i = 0; i < edges.length(); i = i + 1 {
    for j = i + 1; j < edges.length(); j = j + 1 {
      let (_, li, ti) = edges[i]
      let (_, lj, tj) = edges[j]
      if li > lj && ((ti == A && tj == B) || (ti == B && tj == A)) {
        crossings = crossings + 1
      }
    }
  }
  crossings
}

///|
/// Count crossings for two alternative orders of two ports.
///
/// Returns `(a_before_b, b_before_a)`.
pub fn CrossingsCounter::count_crossings_between_ports_in_both_orders(
  self : CrossingsCounter,
  port_a : LPort,
  port_b : LPort,
) -> (Int, Int) {
  let a = port_a.id
  let b = port_b.id

  // If ports are on different nodes/sides, both orders are identical.
  let (a_is_left, a_node) = find_port_location(self.left, self.right, a)
  let (b_is_left, b_node) = find_port_location(self.left, self.right, b)
  if a_is_left != b_is_left || a_node.id != b_node.id {
    let c = count_crossings_involving_ports(self.left, self.right, a, b, true)
    return (c, c)
  }
  let ab = count_crossings_involving_ports(self.left, self.right, a, b, true)
  let ba = count_crossings_involving_ports(self.left, self.right, a, b, false)
  (ab, ba)
}

///|
/// Update internal state after ports are swapped.
///
/// This implementation is stateless, so this is a no-op.
pub fn CrossingsCounter::switch_ports(
  _self : CrossingsCounter,
  _a : LPort,
  _b : LPort,
) -> Unit {
  ()
}

///|
/// Count crossings among in-layer edges on a given side.
///
/// This is a simplified, deterministic variant used for test parity.
pub fn count_in_layer_crossings_on_side(
  layer : Array[LNode],
  side : ElkPortSide,
) -> Int {
  let pos : Map[String, Int] = {}
  for i, n in layer {
    pos[n.id] = i
  }
  fn port_side(node : LNode, port_id : String?) -> ElkPortSide? {
    match port_id {
      Some(pid) => {
        for p in node.ports {
          if p.id == pid {
            return Some(p.side)
          }
        }
        None
      }
      None => None
    }
  }

  // Collect in-layer edges as intervals.
  let intervals : Array[(Int, Int)] = []
  for node in layer {
    for e in node.outgoing_edges {
      match (pos.get(e.source_id), pos.get(e.target_id)) {
        (Some(a), Some(b)) => {
          match port_side(node, e.source_port_id) {
            Some(s) => if s != side { continue }
            None => continue
          }
          if a == b {
            continue
          }
          let lo = if a < b { a } else { b }
          let hi = if a < b { b } else { a }
          intervals.push((lo, hi))
        }
        _ => ()
      }
    }
  }
  let mut crossings = 0
  for i = 0; i < intervals.length(); i = i + 1 {
    for j = i + 1; j < intervals.length(); j = j + 1 {
      let (a0, a1) = intervals[i]
      let (b0, b1) = intervals[j]
      if (a0 < b0 && b0 < a1 && a1 < b1) || (b0 < a0 && a0 < b1 && b1 < a1) {
        crossings = crossings + 1
      }
    }
  }
  crossings
}
