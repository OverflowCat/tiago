///|
pub fn rank_feasible_tree(g : Graph) -> Graph {
  let t = Graph::new(directed=false)
  let nodes = g.nodes()
  if nodes.is_empty() {
    return t
  }
  let start = nodes[0]
  let size = g.node_count()
  t.set_node(start, label=empty_attrs())
  while tight_tree(t, g) < size {
    if find_min_slack_edge(t, g) is Some(edge) {
      let delta = if t.has_node(edge.v) {
        rank_slack(g, edge)
      } else {
        -rank_slack(g, edge)
      }
      shift_ranks(t, g, delta)
    } else {
      break
    }
  }
  t
}

///|
fn tight_tree(t : Graph, g : Graph) -> Int {
  fn dfs(v : String, t : Graph, g : Graph) -> Unit {
    for e in g.node_edges(v) {
      let w = if v == e.v { e.w } else { e.v }
      if !t.has_node(w) && rank_slack(g, e) == 0 {
        t.set_node(w, label=empty_attrs())
        t.set_edge(v, w, label=attrs_value(empty_attrs()))
        dfs(w, t, g)
      }
    }
  }

  for v in t.nodes() {
    dfs(v, t, g)
  }
  t.node_count()
}

///|
fn find_min_slack_edge(t : Graph, g : Graph) -> EdgeObj? {
  let mut best_edge : EdgeObj? = None
  let mut best_slack = @int.max_value
  for edge in g.edges() {
    if t.has_node(edge.v) != t.has_node(edge.w) {
      let s = rank_slack(g, edge)
      if s < best_slack {
        best_slack = s
        best_edge = Some(edge)
      }
    }
  }
  best_edge
}

///|
fn shift_ranks(t : Graph, g : Graph, delta : Int) -> Unit {
  for v in t.nodes() {
    let node = g.node(v)
    node.set_int("rank", node.get_int_or("rank", 0) + delta)
  }
}
