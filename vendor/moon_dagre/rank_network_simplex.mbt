///|
pub fn rank_network_simplex(g : Graph) -> Unit {
  let simplified = simplify(g)
  rank_longest_path(simplified)
  let tree = rank_feasible_tree(simplified)
  rank_network_simplex_init_low_lim_values(tree)
  rank_network_simplex_init_cut_values(tree, simplified)
  while true {
    if rank_network_simplex_leave_edge(tree) is Some(leaving_edge) {
      let entering_edge = rank_network_simplex_enter_edge(
        tree, simplified, leaving_edge,
      )
      rank_network_simplex_exchange_edges(
        tree, simplified, leaving_edge, entering_edge,
      )
    } else {
      break
    }
  }
  rank_network_simplex_copy_ranks(simplified, g)
}

///|
pub fn rank_network_simplex_init_cut_values(t : Graph, g : Graph) -> Unit {
  let vs = postorder(t, t.nodes())
  if !vs.is_empty() {
    ignore(vs.pop())
  }
  for v in vs {
    rank_network_simplex_assign_cut_value(t, g, v)
  }
}

///|
fn rank_network_simplex_assign_cut_value(
  t : Graph,
  g : Graph,
  child : String,
) -> Unit {
  let child_label = t.node(child)
  if child_label.get_string("parent") is Some(parent) {
    let edge_label = rank_network_simplex_tree_edge_attrs(t.edge(child, parent))
    edge_label.set_int(
      "cutvalue",
      rank_network_simplex_calc_cut_value(t, g, child),
    )
    t.set_edge(child, parent, label=attrs_value(edge_label))
  }
}

///|
pub fn rank_network_simplex_calc_cut_value(
  t : Graph,
  g : Graph,
  child : String,
) -> Int {
  let child_label = t.node(child)
  if child_label.get_string("parent") is Some(parent) {
    let mut child_is_tail = true
    let mut graph_edge = g.edge(child, parent)
    if graph_edge is None {
      child_is_tail = false
      graph_edge = g.edge(parent, child)
    }
    let mut cut_value = rank_network_simplex_edge_weight(graph_edge)
    for e in g.node_edges(child) {
      let is_out_edge = e.v == child
      let other = if is_out_edge { e.w } else { e.v }
      if other != parent {
        let points_to_head = is_out_edge == child_is_tail
        let other_weight = rank_network_simplex_edge_weight(g.edge_obj(e))
        let weight_delta = if points_to_head {
          other_weight
        } else {
          -other_weight
        }
        cut_value = cut_value + weight_delta
        if rank_network_simplex_is_tree_edge(t, child, other) {
          let other_cutvalue = rank_network_simplex_tree_edge_cutvalue(
            t.edge(child, other),
          )
          let cutvalue_delta = if points_to_head {
            -other_cutvalue
          } else {
            other_cutvalue
          }
          cut_value = cut_value + cutvalue_delta
        }
      }
    }
    cut_value
  } else {
    0
  }
}

///|
pub fn rank_network_simplex_init_low_lim_values(
  tree : Graph,
  root? : String,
) -> Unit {
  if tree.nodes().is_empty() {
    return
  }
  let start = if root is Some(root) { root } else { tree.nodes()[0] }
  ignore(rank_network_simplex_dfs_assign_low_lim(tree, Set::new(), 1, start))
}

///|
fn rank_network_simplex_dfs_assign_low_lim(
  tree : Graph,
  visited : Set[String],
  next_lim : Int,
  v : String,
  parent? : String,
) -> Int {
  let low = next_lim
  let label = tree.node(v)
  visited.add(v)
  let mut cursor = next_lim
  for w in tree.neighbors(v) {
    if !visited.contains(w) {
      cursor = rank_network_simplex_dfs_assign_low_lim(
        tree,
        visited,
        cursor,
        w,
        parent=v,
      )
    }
  }
  label.set_int("low", low)
  label.set_int("lim", cursor)
  cursor = cursor + 1
  if parent is Some(parent) {
    label.set_string("parent", parent)
  } else {
    label.remove("parent")
  }
  cursor
}

///|
pub fn rank_network_simplex_leave_edge(tree : Graph) -> EdgeObj? {
  for e in tree.edges() {
    if rank_network_simplex_tree_edge_cutvalue(tree.edge_obj(e)) < 0 {
      return Some(e)
    }
  }
  None
}

///|
pub fn rank_network_simplex_enter_edge(
  t : Graph,
  g : Graph,
  edge : EdgeObj,
) -> EdgeObj {
  let mut v = edge.v
  let mut w = edge.w
  if !g.has_edge(v, w) {
    v = edge.w
    w = edge.v
  }
  let v_label = t.node(v)
  let w_label = t.node(w)
  let mut tail_label = v_label
  let mut flip = false
  if v_label.get_int_or("lim", 0) > w_label.get_int_or("lim", 0) {
    tail_label = w_label
    flip = true
  }
  let candidates = []
  for e in g.edges() {
    if flip == rank_network_simplex_is_descendant(t, t.node(e.v), tail_label) &&
      flip != rank_network_simplex_is_descendant(t, t.node(e.w), tail_label) {
      candidates.push(e)
    }
  }
  if candidates.is_empty() {
    edge
  } else {
    let mut best = candidates[0]
    let mut best_slack = rank_slack(g, best)
    for i = 1; i < candidates.length(); i = i + 1 {
      let candidate = candidates[i]
      let candidate_slack = rank_slack(g, candidate)
      if candidate_slack < best_slack {
        best = candidate
        best_slack = candidate_slack
      }
    }
    best
  }
}

///|
pub fn rank_network_simplex_exchange_edges(
  t : Graph,
  g : Graph,
  leaving_edge : EdgeObj,
  entering_edge : EdgeObj,
) -> Unit {
  let name = leaving_edge.name
  t.remove_edge(leaving_edge.v, leaving_edge.w, name?)
  t.set_edge(entering_edge.v, entering_edge.w, label=attrs_value(empty_attrs()))
  rank_network_simplex_init_low_lim_values(t)
  rank_network_simplex_init_cut_values(t, g)
  rank_network_simplex_update_ranks(t, g)
}

///|
fn rank_network_simplex_update_ranks(t : Graph, g : Graph) -> Unit {
  let nodes = t.nodes()
  if nodes.is_empty() {
    return
  }
  let mut root = nodes[0]
  for v in nodes {
    if g.parent(v) is None {
      root = v
      break
    }
  }
  let vs = preorder(t, [root])
  for i = 1; i < vs.length(); i = i + 1 {
    let v = vs[i]
    let v_label = t.node(v)
    if v_label.get_string("parent") is Some(parent) {
      let mut edge = g.edge(v, parent)
      let mut flipped = false
      if edge is None {
        edge = g.edge(parent, v)
        flipped = true
      }
      let minlen = rank_network_simplex_edge_minlen(edge)
      let parent_rank = g.node(parent).get_int_or("rank", 0)
      let rank_delta = if flipped { minlen } else { -minlen }
      g.node(v).set_int("rank", parent_rank + rank_delta)
    }
  }
}

///|
fn rank_network_simplex_is_tree_edge(
  tree : Graph,
  u : String,
  v : String,
) -> Bool {
  tree.has_edge(u, v)
}

///|
fn rank_network_simplex_is_descendant(
  tree : Graph,
  v_label : Attrs,
  root_label : Attrs,
) -> Bool {
  ignore(tree)
  let root_low = root_label.get_int_or("low", 0)
  let root_lim = root_label.get_int_or("lim", 0)
  let v_lim = v_label.get_int_or("lim", 0)
  root_low <= v_lim && v_lim <= root_lim
}

///|
fn rank_network_simplex_tree_edge_attrs(label : Value?) -> Attrs {
  if value_as_attrs(label) is Some(attrs) {
    attrs
  } else {
    empty_attrs()
  }
}

///|
fn rank_network_simplex_tree_edge_cutvalue(label : Value?) -> Int {
  if value_as_attrs(label) is Some(attrs) {
    if attrs.get_int("cutvalue") is Some(cutvalue) {
      cutvalue
    } else if attrs.get_float("cutvalue") is Some(cutvalue) {
      cutvalue.to_int()
    } else {
      0
    }
  } else if value_as_int(label) is Some(cutvalue) {
    cutvalue
  } else if value_as_float(label) is Some(cutvalue) {
    cutvalue.to_int()
  } else {
    0
  }
}

///|
fn rank_network_simplex_edge_minlen(label : Value?) -> Int {
  if value_as_attrs(label) is Some(attrs) {
    if attrs.get_int("minlen") is Some(minlen) {
      minlen
    } else if attrs.get_float("minlen") is Some(minlen) {
      minlen.to_int()
    } else {
      1
    }
  } else {
    1
  }
}

///|
fn rank_network_simplex_edge_weight(label : Value?) -> Int {
  if value_as_attrs(label) is Some(attrs) {
    if attrs.get_int("weight") is Some(weight) {
      weight
    } else if attrs.get_float("weight") is Some(weight) {
      weight.to_int()
    } else {
      1
    }
  } else if value_as_int(label) is Some(weight) {
    weight
  } else if value_as_float(label) is Some(weight) {
    weight.to_int()
  } else {
    1
  }
}

///|
fn rank_network_simplex_copy_ranks(src : Graph, dst : Graph) -> Unit {
  for v in src.nodes() {
    if dst.node_opt(v) is Some(node) {
      if src.node(v).get_int("rank") is Some(rank) {
        node.set_int("rank", rank)
      }
    }
  }
}
