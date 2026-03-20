///|
priv struct ResolveEntry {
  mut indegree : Int
  in_entries : Array[Int]
  out_entries : Array[Int]
  mut vs : Array[String]
  mut i : Int
  mut barycenter : Double?
  mut weight : Double?
  mut merged : Bool
}

///|
pub fn order_resolve_conflicts(
  entries : Array[OrderBarycenterEntry],
  cg : Graph,
) -> Array[OrderEntry] {
  let mapped : Map[String, Int] = Map::new()
  let nodes : Array[ResolveEntry] = []
  for i = 0; i < entries.length(); i = i + 1 {
    let entry = entries[i]
    mapped.set(entry.v, i)
    nodes.push({
      indegree: 0,
      in_entries: [],
      out_entries: [],
      vs: [entry.v],
      i,
      barycenter: entry.barycenter,
      weight: entry.weight,
      merged: false,
    })
  }
  for e in cg.edges() {
    if mapped.get(e.v) is Some(v_idx) && mapped.get(e.w) is Some(w_idx) {
      nodes[w_idx].indegree = nodes[w_idx].indegree + 1
      nodes[v_idx].out_entries.push(w_idx)
    }
  }
  let source_set : Array[Int] = []
  for i = 0; i < nodes.length(); i = i + 1 {
    if nodes[i].indegree == 0 {
      source_set.push(i)
    }
  }
  let visited_order : Array[Int] = []
  while !source_set.is_empty() {
    let v_idx = source_set.pop().unwrap()
    visited_order.push(v_idx)
    let in_list = nodes[v_idx].in_entries
    if !in_list.is_empty() {
      let mut i = in_list.length() - 1
      while true {
        let u_idx = in_list[i]
        if !nodes[u_idx].merged {
          if order_should_merge(nodes[u_idx], nodes[v_idx]) {
            order_merge_entries(nodes, v_idx, u_idx)
          }
        }
        if i == 0 {
          break
        }
        i = i - 1
      }
    }
    let out_list = nodes[v_idx].out_entries
    for w_idx in out_list {
      nodes[w_idx].in_entries.push(v_idx)
      nodes[w_idx].indegree = nodes[w_idx].indegree - 1
      if nodes[w_idx].indegree == 0 {
        source_set.push(w_idx)
      }
    }
  }
  let out : Array[OrderEntry] = []
  for idx in visited_order {
    let entry = nodes[idx]
    if !entry.merged {
      out.push({
        vs: entry.vs,
        i: entry.i,
        barycenter: entry.barycenter,
        weight: entry.weight,
      })
    }
  }
  out
}

///|
fn order_should_merge(u_entry : ResolveEntry, v_entry : ResolveEntry) -> Bool {
  if u_entry.barycenter is None || v_entry.barycenter is None {
    true
  } else if u_entry.barycenter is Some(u_bary) &&
    v_entry.barycenter is Some(v_bary) {
    u_bary >= v_bary
  } else {
    false
  }
}

///|
fn order_merge_entries(
  nodes : Array[ResolveEntry],
  target_idx : Int,
  source_idx : Int,
) -> Unit {
  let target = nodes[target_idx]
  let source = nodes[source_idx]
  let mut sum = 0.0
  let mut weight = 0.0
  if target.barycenter is Some(target_bary) &&
    target.weight is Some(target_weight) {
    sum = sum + target_bary * target_weight
    weight = weight + target_weight
  }
  if source.barycenter is Some(source_bary) &&
    source.weight is Some(source_weight) {
    sum = sum + source_bary * source_weight
    weight = weight + source_weight
  }
  target.vs = source.vs + target.vs
  if weight > 0.0 {
    target.barycenter = Some(sum / weight)
    target.weight = Some(weight)
  } else {
    target.barycenter = None
    target.weight = None
  }
  if source.i < target.i {
    target.i = source.i
  }
  source.merged = true
}
