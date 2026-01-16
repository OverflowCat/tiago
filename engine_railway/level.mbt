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
fn dag_edge_index_sets(
  plan : DagPlan,
) -> (@hashset.HashSet[Int], @hashset.HashSet[Int]) {
  let self_loop : @hashset.HashSet[Int] = @hashset.HashSet::new(
    capacity=plan.self_loop_edge_indices.length() * 2 + 1,
  )
  for ei in plan.self_loop_edge_indices {
    self_loop.add(ei)
  }
  let reversed : @hashset.HashSet[Int] = @hashset.HashSet::new(
    capacity=plan.reverse_edge_indices.length() * 2 + 1,
  )
  for ei in plan.reverse_edge_indices {
    reversed.add(ei)
  }
  (self_loop, reversed)
}

///|
fn compute_depths(
  n : Int,
  graph : @graph.GraphInput,
  id_to_idx : Map[String, Int],
  plan : DagPlan,
  self_loop : @hashset.HashSet[Int],
  reversed : @hashset.HashSet[Int],
) -> Array[Int] {
  let out_adj : Array[Array[Int]] = Array::makei(n, _ => ([] : Array[Int]))
  for e in graph.edges {
    if self_loop.contains(e.index) {
      continue
    }
    let u = require_index(id_to_idx, e.src_id)
    let v = require_index(id_to_idx, e.dst_id)
    if u == v {
      abort("self-loop: unreachable")
    }
    if reversed.contains(e.index) {
      out_adj[v].push(u)
    } else {
      out_adj[u].push(v)
    }
  }
  let order_vertices = plan.order_ids.map(id => require_index(id_to_idx, id))
  let depth = Array::make(n, 0)
  for u in order_vertices {
    let du = depth[u]
    for v in out_adj[u] {
      let cand = du + 1
      if cand > depth[v] {
        depth[v] = cand
      }
    }
  }
  depth
}

///|
fn level_node_id(n : LevelNode) -> String {
  match n {
    Physics(id) => id
    Virtual(id) => id
  }
}

///|
fn map_array_push(
  m : Map[String, Array[String]],
  key : String,
  value : String,
) -> Unit {
  match m.get(key) {
    Some(arr) => arr.push(value)
    None => m[key] = [value]
  }
}

///|
fn order_layer_by_barycenter(
  layer : Array[LevelNode],
  fixed_layer : Array[LevelNode],
  neighbors : Map[String, Array[String]],
) -> Unit {
  if layer.length() <= 1 || fixed_layer.length() == 0 {
    return
  }
  let fixed_pos : Map[String, Int] = {}
  for i, node in fixed_layer {
    fixed_pos[level_node_id(node)] = i
  }
  let original_pos : Map[String, Int] = {}
  for i, node in layer {
    original_pos[level_node_id(node)] = i
  }
  let barycenters : Map[String, Double] = {}
  for node in layer {
    let id = level_node_id(node)
    let connected_positions : Array[Int] = []
    match neighbors.get(id) {
      Some(ns) =>
        for nid in ns {
          match fixed_pos.get(nid) {
            Some(p) => connected_positions.push(p)
            None => ()
          }
        }
      None => ()
    }
    if connected_positions.length() > 0 {
      let sum = connected_positions.fold(init=0, fn(acc, p) { acc + p })
      barycenters[id] = sum.to_double() /
        connected_positions.length().to_double()
    } else {
      barycenters[id] = original_pos.get(id).unwrap_or(0).to_double()
    }
  }
  layer.sort_by(fn(a, b) {
    let ida = level_node_id(a)
    let idb = level_node_id(b)
    let bc_a = barycenters.get(ida).unwrap_or(0.0)
    let bc_b = barycenters.get(idb).unwrap_or(0.0)
    if bc_a < bc_b {
      -1
    } else if bc_a > bc_b {
      1
    } else {
      let pa = original_pos.get(ida).unwrap_or(0)
      let pb = original_pos.get(idb).unwrap_or(0)
      if pa != pb {
        pa - pb
      } else {
        ida.compare(idb)
      }
    }
  })
}

///|
priv struct Level(Array[LevelNode])

///|
priv enum LevelNode {
  Physics(String)
  Virtual(String)
}

///|
fn make_levels(graph : @graph.GraphInput) -> Array[Level] {
  let n = graph.objects.length()
  if n == 0 {
    return []
  }
  let ids : Array[String] = graph.objects.map(o => o.id)
  let id_to_idx : Map[String, Int] = Map::new(capacity=n * 2)
  for i in 0..<n {
    id_to_idx.set(ids[i], i)
  }
  let plan = els_tarjan_plan(graph)
  let (self_loop, reversed) = dag_edge_index_sets(plan)
  let depths = compute_depths(n, graph, id_to_idx, plan, self_loop, reversed)
  let mut max_depth = 0
  for d in depths {
    if d > max_depth {
      max_depth = d
    }
  }
  let nodes_by_level : Array[Array[LevelNode]] = Array::makei(max_depth + 1, _ => (
    [] : Array[LevelNode]))
  for i in 0..<n {
    nodes_by_level[depths[i]].push(Physics(ids[i]))
  }
  let incoming : Map[String, Array[String]] = {}
  let outgoing : Map[String, Array[String]] = {}
  for e in graph.edges {
    if self_loop.contains(e.index) {
      continue
    }
    let mut u = require_index(id_to_idx, e.src_id)
    let mut v = require_index(id_to_idx, e.dst_id)
    if reversed.contains(e.index) {
      let tmp = u
      u = v
      v = tmp
    }
    let du = depths[u]
    let dv = depths[v]
    if dv <= du {
      abort("unexpected non-forward edge when building levels")
    }
    let span = dv - du
    let mut prev_id = ids[u]
    if span > 1 {
      for step in 1..<span {
        let level = du + step
        let virt_id = "virtual:\{e.index}:\{level}"
        nodes_by_level[level].push(Virtual(virt_id))
        map_array_push(outgoing, prev_id, virt_id)
        map_array_push(incoming, virt_id, prev_id)
        prev_id = virt_id
      }
    }
    let dst_id = ids[v]
    map_array_push(outgoing, prev_id, dst_id)
    map_array_push(incoming, dst_id, prev_id)
  }
  let thoroughness = 4
  if nodes_by_level.length() > 1 {
    for _sweep in 0..<thoroughness {
      for i in 1..<nodes_by_level.length() {
        order_layer_by_barycenter(
          nodes_by_level[i],
          nodes_by_level[i - 1],
          incoming,
        )
      }
      for i = nodes_by_level.length() - 2; i >= 0; i = i - 1 {
        order_layer_by_barycenter(
          nodes_by_level[i],
          nodes_by_level[i + 1],
          outgoing,
        )
      }
    }
  }
  nodes_by_level.map(nodes => Level(nodes))
}
