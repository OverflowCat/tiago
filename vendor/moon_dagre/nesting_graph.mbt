///|
pub fn nesting_graph_run(g : Graph) -> Unit {
  let root = add_dummy_node(g, "root", empty_attrs(), "_root")
  let depths = nesting_tree_depths(g)
  let depth_values = nesting_depth_values(depths)
  let height = if depth_values.is_empty() {
    0
  } else {
    apply_with_chunking_max(depth_values) - 1
  }
  let node_sep = 2 * height + 1
  g.graph().set_string("nestingRoot", root)
  for e in g.edges() {
    let label = nesting_edge_attrs(g.edge_obj(e))
    label.set_int("minlen", label.get_int_or("minlen", 1) * node_sep)
    g.set_edge_obj(e, label=attrs_value(label))
  }
  let weight = nesting_sum_weights(g) + 1.0
  for child in g.children() {
    nesting_dfs(g, root, node_sep, weight, height, depths, child)
  }
  g.graph().set_int("nodeRankFactor", node_sep)
}

///|
fn nesting_dfs(
  g : Graph,
  root : String,
  node_sep : Int,
  weight : Double,
  height : Int,
  depths : Map[String, Int],
  v : String,
) -> Unit {
  let children = g.children(v~)
  if children.is_empty() {
    if v != root {
      g.set_edge(root, v, label=nesting_weight_minlen(0.0, node_sep))
    }
    return
  }
  let top = add_border_node(g, "_bt")
  let bottom = add_border_node(g, "_bb")
  let label = g.node(v)
  g.set_parent(top, parent=v)
  label.set_string("borderTop", top)
  g.set_parent(bottom, parent=v)
  label.set_string("borderBottom", bottom)
  for child in children {
    nesting_dfs(g, root, node_sep, weight, height, depths, child)
    let child_node = g.node(child)
    let child_top = child_node.get_string_or("borderTop", child)
    let child_bottom = child_node.get_string_or("borderBottom", child)
    let this_weight = if child_node.get_string("borderTop") is Some(_) {
      weight
    } else {
      2.0 * weight
    }
    let minlen = if child_top != child_bottom {
      1
    } else {
      height - depths.get_or_default(v, 1) + 1
    }
    g.set_edge(
      top,
      child_top,
      label=nesting_weight_minlen(this_weight, minlen, nesting_edge=true),
    )
    g.set_edge(
      child_bottom,
      bottom,
      label=nesting_weight_minlen(this_weight, minlen, nesting_edge=true),
    )
  }
  if g.parent(v) is None {
    g.set_edge(
      root,
      top,
      label=nesting_weight_minlen(0.0, height + depths.get_or_default(v, 1)),
    )
  }
}

///|
fn nesting_tree_depths(g : Graph) -> Map[String, Int] {
  let depths : Map[String, Int] = Map::new()
  fn dfs(
    g : Graph,
    depths : Map[String, Int],
    v : String,
    depth : Int,
  ) -> Unit {
    let children = g.children(v~)
    if !children.is_empty() {
      for child in children {
        dfs(g, depths, child, depth + 1)
      }
    }
    depths.set(v, depth)
  }

  for v in g.children() {
    dfs(g, depths, v, 1)
  }
  depths
}

///|
fn nesting_sum_weights(g : Graph) -> Double {
  let mut weight = 0.0
  for e in g.edges() {
    weight = weight +
      nesting_edge_attrs(g.edge_obj(e)).get_float_or("weight", 0.0)
  }
  weight
}

///|
fn nesting_depth_values(depths : Map[String, Int]) -> Array[Int] {
  let values = []
  depths.each((_, depth) => values.push(depth))
  values
}

///|
pub fn nesting_graph_cleanup(g : Graph) -> Unit {
  let graph_label = g.graph()
  if graph_label.get_string("nestingRoot") is Some(root) {
    g.remove_node(root)
  }
  graph_label.remove("nestingRoot")
  let edges = g.edges()
  for e in edges {
    let edge = nesting_edge_attrs(g.edge_obj(e))
    if edge.get_bool_or("nestingEdge", false) {
      g.remove_edge_obj(e)
    }
  }
}

///|
fn nesting_edge_attrs(label : Value?) -> Attrs {
  if value_as_attrs(label) is Some(attrs) {
    attrs
  } else if value_as_int(label) is Some(v) {
    let attrs = empty_attrs()
    attrs.set_int("weight", v)
    attrs
  } else if value_as_float(label) is Some(v) {
    let attrs = empty_attrs()
    attrs.set_float("weight", v)
    attrs
  } else {
    empty_attrs()
  }
}

///|
fn nesting_weight_minlen(
  weight : Double,
  minlen : Int,
  nesting_edge? : Bool = false,
) -> Value {
  let attrs = empty_attrs()
  attrs.set_float("weight", weight)
  attrs.set_int("minlen", minlen)
  if nesting_edge {
    attrs.set_bool("nestingEdge", true)
  }
  attrs_value(attrs)
}
