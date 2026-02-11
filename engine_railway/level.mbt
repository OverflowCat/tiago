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
) -> Array[Int] raise @engine_api.LayoutError {
  let out_adj : Array[Array[Int]] = Array::makei(n, _ => ([] : Array[Int]))
  for e in graph.edges {
    if self_loop.contains(e.index) {
      continue
    }
    let u = require_index(id_to_idx, e.src_id)
    let v = require_index(id_to_idx, e.dst_id)
    if u == v {
      raise Unsupported("unreachable: self-loop in compute_depths")
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
fn order_layer_by_barycenter(
  layer : Array[String],
  fixed_layer : Array[String],
  neighbors : Map[String, Array[String]],
) -> Unit {
  if layer.length() <= 1 || fixed_layer.length() == 0 {
    return
  }
  let fixed_pos : Map[String, Int] = {}
  for i, node in fixed_layer {
    fixed_pos[node] = i
  }
  let original_pos : Map[String, Int] = {}
  for i, node in layer {
    original_pos[node] = i
  }
  let barycenters : Map[String, Double] = {}
  for node in layer {
    let connected_positions : Array[Int] = []
    match neighbors.get(node) {
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
      barycenters[node] = sum.to_double() /
        connected_positions.length().to_double()
    } else {
      barycenters[node] = original_pos.get(node).unwrap_or(0).to_double()
    }
  }
  layer.sort_by(fn(a, b) {
    let bc_a = barycenters.get(a).unwrap_or(0.0)
    let bc_b = barycenters.get(b).unwrap_or(0.0)
    if bc_a < bc_b {
      -1
    } else if bc_a > bc_b {
      1
    } else {
      let pa = original_pos.get(a).unwrap_or(0)
      let pb = original_pos.get(b).unwrap_or(0)
      if pa != pb {
        pa - pb
      } else {
        a.compare(b)
      }
    }
  })
}

///|
type Level = Array[String]

///|
fn make_levels(
  graph : @graph.GraphInput,
  depths : Array[Int],
) -> Array[Level] raise @engine_api.LayoutError {
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
  let mut max_depth = 0
  for d in depths {
    if d > max_depth {
      max_depth = d
    }
  }
  let nodes_by_level : Array[Array[String]] = Array::makei(max_depth + 1, _ => {
    []
  })
  for i in 0..<n {
    nodes_by_level[depths[i]].push(ids[i])
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
    if du >= dv {
      raise Unsupported("make_levels: \{du} >= \{dv}")
    }
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
  nodes_by_level
}
