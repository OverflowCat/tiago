///|
pub fn order_init_order(g : Graph) -> Array[Array[String]] {
  let visited : Set[String] = Set::new()
  let simple_nodes = g.nodes().filter(v => g.children(v~).is_empty())
  if simple_nodes.is_empty() {
    return []
  }
  let simple_ranks = simple_nodes.map(v => g.node(v).get_int_or("rank", 0))
  let max_rank = apply_with_chunking_max(simple_ranks)
  let layers = range(max_rank + 1).map(_ => [])
  fn dfs(
    g : Graph,
    v : String,
    visited : Set[String],
    layers : Array[Array[String]],
  ) -> Unit {
    if visited.contains(v) {
      return
    }
    visited.add(v)
    let node = g.node(v)
    let rank = node.get_int_or("rank", 0)
    layers[rank].push(v)
    for w in g.successors(v) {
      dfs(g, w, visited, layers)
    }
  }

  // JS uses a stable sort when ordering by rank only. Preserve the original
  // `simple_nodes` order as a tiebreaker to match upstream behavior.
  let index_by_node : Map[String, Int] = Map::new()
  for i = 0; i < simple_nodes.length(); i = i + 1 {
    index_by_node.set(simple_nodes[i], i)
  }

  let ordered_vs = simple_nodes.copy()
  ordered_vs.sort_by((a, b) => {
    let ra = g.node(a).get_int_or("rank", 0)
    let rb = g.node(b).get_int_or("rank", 0)
    let d = ra - rb
    if d != 0 {
      d
    } else {
      index_by_node.get_or_default(a, 0) - index_by_node.get_or_default(b, 0)
    }
  })
  for v in ordered_vs {
    dfs(g, v, visited, layers)
  }
  layers
}
