///|
pub fn rank_longest_path(g : Graph) -> Unit {
  let visited = Set::new()
  fn dfs(g : Graph, v : String, visited : Set[String]) -> Int {
    let label = g.node(v)
    if visited.contains(v) {
      label.get_int_or("rank", 0)
    } else {
      visited.add(v)
      let mut rank = 0
      let out_edges = g.out_edges(v)
      if !out_edges.is_empty() {
        rank = @int.max_value
        for e in out_edges {
          let w_rank = dfs(g, e.w, visited)
          let candidate = w_rank - edge_minlen(g.edge_obj(e))
          if candidate < rank {
            rank = candidate
          }
        }
      }
      label.set_int("rank", rank)
      rank
    }
  }

  for v in g.sources() {
    ignore(dfs(g, v, visited))
  }
}

///|
pub fn rank_slack(g : Graph, e : EdgeObj) -> Int {
  let wrank = g.node(e.w).get_int_or("rank", 0)
  let vrank = g.node(e.v).get_int_or("rank", 0)
  wrank - vrank - edge_minlen(g.edge_obj(e))
}

///|
fn edge_minlen(label : Value?) -> Int {
  if value_as_attrs(label) is Some(attrs) {
    attrs.get_int_or("minlen", 1)
  } else {
    1
  }
}
