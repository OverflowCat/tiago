///|
pub fn rank(g : Graph) -> Unit {
  let ranker = g.graph().get_string_or("ranker", "network-simplex")
  match ranker {
    "longest-path" => rank_longest_path(g)
    "tight-tree" => tight_tree_ranker(g)
    "network-simplex" => rank_network_simplex(g)
    "none" => ()
    _ => rank_network_simplex(g)
  }
}

///|
fn tight_tree_ranker(g : Graph) -> Unit {
  rank_longest_path(g)
  ignore(rank_feasible_tree(g))
}
