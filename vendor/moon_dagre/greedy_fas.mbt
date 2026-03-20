///|
priv struct GreedyEntry {
  v : String
  mut in_w : Double
  mut out_w : Double
}

///|
priv struct GreedyState {
  graph : Graph
  entries : Map[String, GreedyEntry]
  buckets : Array[Array[String]]
  bucket_of : Map[String, Int]
  zero_idx : Int
}

///|
pub fn greedy_fas(
  g : Graph,
  weight_fn? : (EdgeObj) -> Double,
) -> Array[EdgeObj] {
  if g.node_count() <= 1 {
    return []
  }
  let weight_fn = if weight_fn is Some(weight_fn) {
    weight_fn
  } else {
    (_ : EdgeObj) => 1.0
  }
  let state = build_state(g, weight_fn)
  let fas = do_greedy_fas(state)
  let result : Array[EdgeObj] = []
  for e in fas {
    for multi in g.out_edges(e.v, w=e.w) {
      result.push(multi)
    }
  }
  result
}

///|
fn do_greedy_fas(state : GreedyState) -> Array[EdgeObj] {
  let result : Array[EdgeObj] = []
  let sinks_idx = 0
  let sources_idx = state.buckets.length() - 1
  while state.graph.node_count() > 0 {
    while bucket_dequeue(state, sinks_idx) is Some(v) {
      ignore(remove_node(state, v, false))
    }
    while bucket_dequeue(state, sources_idx) is Some(v) {
      ignore(remove_node(state, v, false))
    }
    if state.graph.node_count() > 0 {
      let mut i = state.buckets.length() - 2
      let mut picked = false
      while i > 0 && !picked {
        if bucket_dequeue(state, i) is Some(v) {
          let removed = remove_node(state, v, true)
          for e in removed {
            result.push(e)
          }
          picked = true
        }
        i = i - 1
      }
    }
  }
  result
}

///|
fn remove_node(
  state : GreedyState,
  v : String,
  collect_predecessors : Bool,
) -> Array[EdgeObj] {
  let result : Array[EdgeObj] = []
  if !state.graph.has_node(v) {
    return result
  }
  for edge in state.graph.in_edges(v) {
    let weight = edge_label_weight(state.graph.edge_obj(edge))
    if collect_predecessors {
      let name = edge.name
      result.push(edge_obj(edge.v, edge.w, name?))
    }
    if state.entries.get(edge.v) is Some(u_entry) {
      u_entry.out_w = u_entry.out_w - weight
      assign_bucket(state, u_entry.v)
    }
  }
  for edge in state.graph.out_edges(v) {
    let weight = edge_label_weight(state.graph.edge_obj(edge))
    if state.entries.get(edge.w) is Some(w_entry) {
      w_entry.in_w = w_entry.in_w - weight
      assign_bucket(state, w_entry.v)
    }
  }
  state.graph.remove_node(v)
  state.bucket_of.remove(v)
  result
}

///|
fn build_state(g : Graph, weight_fn : (EdgeObj) -> Double) -> GreedyState {
  let fas_graph = Graph::new()
  let entries : Map[String, GreedyEntry] = Map::new()
  for v in g.nodes() {
    fas_graph.set_node(v)
    entries.set(v, { v, in_w: 0.0, out_w: 0.0 })
  }
  let mut max_in = 0.0
  let mut max_out = 0.0
  for e in g.edges() {
    let prev = edge_label_weight(fas_graph.edge(e.v, e.w))
    let w = weight_fn(e)
    let edge_weight = prev + w
    fas_graph.set_edge(e.v, e.w, label=Value::VFloat(edge_weight))
    if entries.get(e.v) is Some(v_entry) {
      v_entry.out_w = v_entry.out_w + w
      if v_entry.out_w > max_out {
        max_out = v_entry.out_w
      }
    }
    if entries.get(e.w) is Some(w_entry) {
      w_entry.in_w = w_entry.in_w + w
      if w_entry.in_w > max_in {
        max_in = w_entry.in_w
      }
    }
  }
  let bucket_len = max_out.to_int() + max_in.to_int() + 3
  let buckets = range(bucket_len).map(_ => [])
  let bucket_of : Map[String, Int] = Map::new()
  let state : GreedyState = {
    graph: fas_graph,
    entries,
    buckets,
    bucket_of,
    zero_idx: max_in.to_int() + 1,
  }
  for v in fas_graph.nodes() {
    assign_bucket(state, v)
  }
  state
}

///|
fn assign_bucket(state : GreedyState, v : String) -> Unit {
  if !state.graph.has_node(v) {
    return
  }
  if state.entries.get(v) is Some(entry) {
    let idx = if entry.out_w == 0.0 {
      0
    } else if entry.in_w == 0.0 {
      state.buckets.length() - 1
    } else {
      (entry.out_w - entry.in_w).to_int() + state.zero_idx
    }
    if state.bucket_of.get(v) is Some(prev_idx) {
      bucket_remove(state.buckets[prev_idx], v)
    }
    state.buckets[idx].insert(0, v)
    state.bucket_of.set(v, idx)
  }
}

///|
fn bucket_dequeue(state : GreedyState, idx : Int) -> String? {
  if state.buckets[idx].pop() is Some(v) {
    state.bucket_of.remove(v)
    Some(v)
  } else {
    None
  }
}

///|
fn bucket_remove(bucket : Array[String], v : String) -> Unit {
  if bucket.search_by(item => item == v) is Some(i) {
    ignore(bucket.remove(i))
  }
}

///|
fn edge_label_weight(label : Value?) -> Double {
  match label {
    Some(Value::VInt(v)) => v.to_double()
    Some(Value::VFloat(v)) => v
    Some(Value::VAttrs(attrs)) => attrs.get_float_or("weight", 1.0)
    _ => 0.0
  }
}
