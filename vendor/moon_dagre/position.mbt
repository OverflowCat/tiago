///|
pub fn position(g : Graph) -> Unit {
  let simple = as_non_compound_graph(g)
  position_y(simple)
  let xs = position_bk_x(simple)
  for v in simple.nodes() {
    if g.node_opt(v) is Some(node) {
      node.set_float("x", xs.get_or_default(v, 0.0))
      node.set_float("y", simple.node(v).get_float_or("y", 0.0))
    }
  }
}

///|
pub fn position_y(g : Graph) -> Unit {
  let layering = build_layer_matrix(g)
  let rank_sep = g.graph().get_float_or("ranksep", 50.0)
  let rank_align = g.graph().get_string_or("rankalign", "center")
  let mut prev_y = 0.0
  for layer in layering {
    let mut max_height = 0.0
    for v in layer {
      if position_is_layer_hole(v) {
        continue
      }
      let h = g.node(v).get_float_or("height", 0.0)
      if h > max_height {
        max_height = h
      }
    }
    for v in layer {
      if position_is_layer_hole(v) {
        continue
      }
      let node = g.node(v)
      if rank_align == "top" {
        node.set_float("y", prev_y + node.get_float_or("height", 0.0) / 2.0)
      } else if rank_align == "bottom" {
        node.set_float(
          "y",
          prev_y + max_height - node.get_float_or("height", 0.0) / 2.0,
        )
      } else {
        node.set_float("y", prev_y + max_height / 2.0)
      }
    }
    prev_y = prev_y + max_height + rank_sep
  }
}

///|
pub fn position_x(g : Graph) -> Map[String, Double] {
  position_bk_x(g)
}

///|
fn position_is_layer_hole(v : String) -> Bool {
  v == ""
}
