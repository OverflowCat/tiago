///|
pub fn add_border_segments(g : Graph) -> Unit {
  if !g.is_compound() {
    return
  }
  for v in g.children() {
    add_bs_dfs(g, v)
  }
}

///|
fn add_bs_dfs(g : Graph, v : String) -> Unit {
  let children = g.children(v~)
  let node = g.node(v)
  if !children.is_empty() {
    for child in children {
      add_bs_dfs(g, child)
    }
  }
  if node.get_int("minRank") is Some(min_rank) {
    let max_rank = node.get_int_or("maxRank", min_rank)
    node.set_strings("borderLeft", [])
    node.set_strings("borderRight", [])
    let mut rank = min_rank
    while rank <= max_rank {
      add_bs_border_node(g, "borderLeft", "_bl", v, node, rank)
      add_bs_border_node(g, "borderRight", "_br", v, node, rank)
      rank = rank + 1
    }
  }
}

///|
fn add_bs_border_node(
  g : Graph,
  prop : String,
  prefix : String,
  sg : String,
  sg_node : Attrs,
  rank : Int,
) -> Unit {
  let label = empty_attrs()
  label.set_float("width", 0.0)
  label.set_float("height", 0.0)
  label.set_int("rank", rank)
  label.set_string("borderType", prop)
  let prev = add_bs_border_at(sg_node, prop, rank - 1)
  let curr = add_dummy_node(g, "border", label, prefix)
  add_bs_set_border_at(sg_node, prop, rank, curr)
  g.set_parent(curr, parent=sg)
  if prev is Some(prev) {
    let edge = empty_attrs()
    edge.set_int("weight", 1)
    g.set_edge(prev, curr, label=attrs_value(edge))
  }
}

///|
fn add_bs_border_at(node : Attrs, prop : String, rank : Int) -> String? {
  if node.get_strings(prop) is Some(border_nodes) {
    if rank >= 0 && rank < border_nodes.length() {
      let value = border_nodes[rank]
      if value == "" {
        None
      } else {
        Some(value)
      }
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn add_bs_set_border_at(
  node : Attrs,
  prop : String,
  rank : Int,
  value : String,
) -> Unit {
  let border_nodes = if node.get_strings(prop) is Some(border_nodes) {
    border_nodes
  } else {
    []
  }
  add_bs_ensure_index(border_nodes, rank)
  border_nodes[rank] = value
  node.set_strings(prop, border_nodes)
}

///|
fn add_bs_ensure_index(values : Array[String], idx : Int) -> Unit {
  while values.length() <= idx {
    values.push("")
  }
}
