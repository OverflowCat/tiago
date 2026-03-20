///|
pub fn normalize_run(g : Graph) -> Unit {
  let dummy_chains : Array[String] = []
  g.graph().set_strings("dummyChains", dummy_chains)
  let edges = g.edges()
  for edge in edges {
    normalize_long_edge(g, edge, dummy_chains)
  }
}

///|
fn normalize_long_edge(
  g : Graph,
  e : EdgeObj,
  dummy_chains : Array[String],
) -> Unit {
  let mut v = e.v
  let mut v_rank = g.node(v).get_int_or("rank", 0)
  let w = e.w
  let w_rank = g.node(w).get_int_or("rank", 0)
  let name = e.name
  let edge_label = edge_label_attrs(g.edge_obj(e))
  let label_rank = edge_label.get_int("labelRank")
  if w_rank == v_rank + 1 {
    return
  }
  g.remove_edge_obj(e)
  let mut i = 0
  v_rank = v_rank + 1
  while v_rank < w_rank {
    edge_label.set_points("points", [])
    let attrs = empty_attrs()
    attrs.set_float("width", 0.0)
    attrs.set_float("height", 0.0)
    attrs.set_value("edgeLabel", attrs_value(edge_label))
    attrs.set_edge("edgeObj", e)
    attrs.set_int("rank", v_rank)
    let dummy = add_dummy_node(g, "edge", attrs, "_d")
    if label_rank is Some(rank) {
      if v_rank == rank {
        attrs.set_float("width", edge_label.get_float_or("width", 0.0))
        attrs.set_float("height", edge_label.get_float_or("height", 0.0))
        attrs.set_string("dummy", "edge-label")
        attrs.set_string("labelpos", edge_label.get_string_or("labelpos", "r"))
        g.set_node(dummy, label=attrs)
      }
    }
    let weighted = empty_attrs()
    weighted.set_float("weight", edge_label.get_float_or("weight", 1.0))
    g.set_edge(v, dummy, label=attrs_value(weighted), name?)
    if i == 0 {
      dummy_chains.push(dummy)
    }
    v = dummy
    i = i + 1
    v_rank = v_rank + 1
  }
  let weighted = empty_attrs()
  weighted.set_float("weight", edge_label.get_float_or("weight", 1.0))
  g.set_edge(v, w, label=attrs_value(weighted), name?)
}

///|
pub fn normalize_undo(g : Graph) -> Unit {
  let chains = if g.graph().get_strings("dummyChains") is Some(chains) {
    chains.copy()
  } else {
    []
  }
  for start in chains {
    let mut v = start
    let mut node = g.node(v)
    let orig_label = if node.get_value("edgeLabel") is Some(label) {
      label
    } else {
      attrs_value(empty_attrs())
    }
    if node.get_edge("edgeObj") is Some(edge_obj) {
      g.set_edge_obj(edge_obj, label=orig_label)
      let orig_attrs = edge_label_attrs(Some(orig_label))
      while node.get_string("dummy") is Some(dummy_type) {
        let successors = g.successors(v)
        if successors.is_empty() {
          break
        }
        let w = successors[0]
        let x = node.get_float_or("x", 0.0)
        let y = node.get_float_or("y", 0.0)
        let width = node.get_float_or("width", 0.0)
        let height = node.get_float_or("height", 0.0)
        g.remove_node(v)
        let points = if orig_attrs.get_points("points") is Some(points) {
          points
        } else {
          []
        }
        points.push(point(x, y))
        orig_attrs.set_points("points", points)
        if dummy_type == "edge-label" {
          orig_attrs.set_float("x", x)
          orig_attrs.set_float("y", y)
          orig_attrs.set_float("width", width)
          orig_attrs.set_float("height", height)
        }
        v = w
        node = g.node(v)
      }
      g.set_edge_obj(edge_obj, label=attrs_value(orig_attrs))
    }
  }
}

///|
fn edge_label_attrs(label : Value?) -> Attrs {
  if value_as_attrs(label) is Some(attrs) {
    attrs
  } else if value_as_float(label) is Some(weight) {
    let attrs = empty_attrs()
    attrs.set_float("weight", weight)
    attrs
  } else if value_as_int(label) is Some(weight) {
    let attrs = empty_attrs()
    attrs.set_int("weight", weight)
    attrs
  } else {
    empty_attrs()
  }
}
