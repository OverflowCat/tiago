///|
priv struct LayoutSelfEdge {
  e : EdgeObj
  label : Value
}

///|
pub fn layout_run(g : Graph, debug_timing? : Bool = false) -> Graph {
  layout_run_with_constraints(g, [], debug_timing~)
}

///|
pub fn layout_run_with_constraints(
  g : Graph,
  constraints : Array[OrderConstraint],
  debug_timing? : Bool = false,
) -> Graph {
  if debug_timing {
    time("layout", () => {
      let layout_graph = time("  buildLayoutGraph", () => {
        layout_build_layout_graph(g)
      })
      ignore(
        time("  runLayout", () => layout_run_pipeline(layout_graph, constraints)),
      )
      ignore(
        time("  updateInputGraph", () => {
          layout_update_input_graph(g, layout_graph)
        }),
      )
      layout_graph
    })
  } else {
    notime("layout", () => {
      let layout_graph = notime("  buildLayoutGraph", () => {
        layout_build_layout_graph(g)
      })
      ignore(
        notime(
          "  runLayout",
          () => layout_run_pipeline(layout_graph, constraints),
        ),
      )
      ignore(
        notime("  updateInputGraph", () => {
          layout_update_input_graph(g, layout_graph)
        }),
      )
      layout_graph
    })
  }
}

///|
fn layout_run_pipeline(g : Graph, constraints : Array[OrderConstraint]) -> Unit {
  layout_make_space_for_edge_labels(g)
  let self_edges = layout_remove_self_edges(g)
  acyclic_run(g)
  nesting_graph_run(g)
  layout_rank_non_compound(g)
  layout_inject_edge_label_proxies(g)
  remove_empty_ranks(g)
  nesting_graph_cleanup(g)
  normalize_ranks(g)
  layout_assign_rank_min_max(g)
  layout_remove_edge_label_proxies(g)
  normalize_run(g)
  parent_dummy_chains(g)
  add_border_segments(g)
  order_run(g, constraints=constraints)
  layout_insert_self_edges(g, self_edges)
  coordinate_adjust(g)
  position(g)
  layout_position_self_edges(g)
  layout_remove_border_nodes(g)
  normalize_undo(g)
  layout_fixup_edge_label_coords(g)
  coordinate_undo(g)
  layout_translate_graph(g)
  layout_assign_node_intersects(g)
  layout_reverse_points_for_reversed_edges(g)
  acyclic_undo(g)
}

///|
// Debug helper for parity investigations. Returns the layout graph, optionally
// stopping before removing border nodes (so border dummy nodes remain).
pub fn layout_layout_graph_debug(
  input_graph : Graph,
  stop_before_remove_border_nodes? : Bool = false,
  stop_after_rank? : Bool = false,
  stop_after_order? : Bool = false,
  stop_after_normalize_undo? : Bool = false,
  stop_after_coordinate_undo? : Bool = false,
  stop_after_translate_graph? : Bool = false,
) -> Graph {
  let g = layout_build_layout_graph(input_graph)
  layout_make_space_for_edge_labels(g)
  let self_edges = layout_remove_self_edges(g)
  acyclic_run(g)
  nesting_graph_run(g)
  layout_rank_non_compound(g)
  layout_inject_edge_label_proxies(g)
  remove_empty_ranks(g)
  nesting_graph_cleanup(g)
  normalize_ranks(g)
  layout_assign_rank_min_max(g)
  layout_remove_edge_label_proxies(g)
  if stop_after_rank {
    return g
  }
  normalize_run(g)
  parent_dummy_chains(g)
  add_border_segments(g)
  order_run(g)
  layout_insert_self_edges(g, self_edges)
  if stop_after_order {
    return g
  }
  coordinate_adjust(g)
  position(g)
  layout_position_self_edges(g)
  if stop_before_remove_border_nodes {
    return g
  }
  layout_remove_border_nodes(g)
  normalize_undo(g)
  if stop_after_normalize_undo {
    return g
  }
  layout_fixup_edge_label_coords(g)
  coordinate_undo(g)
  if stop_after_coordinate_undo {
    return g
  }
  layout_translate_graph(g)
  if stop_after_translate_graph {
    return g
  }
  layout_assign_node_intersects(g)
  layout_reverse_points_for_reversed_edges(g)
  acyclic_undo(g)
  g
}

///|
fn layout_update_input_graph(input_graph : Graph, layout_graph : Graph) -> Unit {
  for v in input_graph.nodes() {
    let input_label = input_graph.node(v)
    if layout_graph.node_opt(v) is Some(layout_label) {
      if layout_label.get_float("x") is Some(x) {
        input_label.set_float("x", x)
      }
      if layout_label.get_float("y") is Some(y) {
        input_label.set_float("y", y)
      }
      if layout_label.get_int("order") is Some(order) {
        input_label.set_int("order", order)
      }
      if layout_label.get_int("rank") is Some(rank) {
        input_label.set_int("rank", rank)
      }
      if !layout_graph.children(v~).is_empty() {
        if layout_label.get_float("width") is Some(width) {
          input_label.set_float("width", width)
        }
        if layout_label.get_float("height") is Some(height) {
          input_label.set_float("height", height)
        }
      }
    }
  }
  for e in input_graph.edges() {
    let input_label = layout_edge_attrs(input_graph.edge_obj(e))
    let layout_label = layout_edge_attrs(layout_graph.edge_obj(e))
    if layout_label.get_points("points") is Some(points) {
      input_label.set_points("points", points)
    }
    if layout_label.get_float("x") is Some(x) {
      input_label.set_float("x", x)
      input_label.set_float("y", layout_label.get_float_or("y", 0.0))
    }
    input_graph.set_edge_obj(e, label=attrs_value(input_label))
  }
  input_graph
  .graph()
  .set_float("width", layout_graph.graph().get_float_or("width", 0.0))
  input_graph
  .graph()
  .set_float("height", layout_graph.graph().get_float_or("height", 0.0))
}

///|
fn layout_build_layout_graph(input_graph : Graph) -> Graph {
  let g = Graph::new(multigraph=true, compound=true)
  let graph = layout_canonicalize(input_graph.graph())
  let graph_label = layout_graph_defaults()
  layout_merge_attrs(
    graph_label,
    layout_select_number_attrs(graph, layout_graph_num_attrs()),
  )
  layout_merge_attrs(graph_label, pick(graph, layout_graph_attrs()))
  g.set_graph(graph_label)
  for v in input_graph.nodes() {
    let node = layout_canonicalize(input_graph.node(v))
    let new_node = layout_select_number_attrs(node, layout_node_num_attrs())
    let node_defaults = layout_node_defaults()
    node_defaults
    .keys()
    .each(key => {
      if !new_node.contains(key) {
        if node_defaults.get(key) is Some(value) {
          new_node.set(key, value)
        }
      }
    })
    g.set_node(v, label=new_node)
    if input_graph.parent(v) is Some(parent) {
      g.set_parent(v, parent~)
    }
  }
  for e in input_graph.edges() {
    let edge = layout_canonicalize(layout_edge_attrs(input_graph.edge_obj(e)))
    let new_edge = layout_edge_defaults()
    layout_merge_attrs(
      new_edge,
      layout_select_number_attrs(edge, layout_edge_num_attrs()),
    )
    layout_merge_attrs(new_edge, pick(edge, layout_edge_attrs_keys()))
    g.set_edge_obj(e, label=attrs_value(new_edge))
  }
  g
}

///|
fn layout_make_space_for_edge_labels(g : Graph) -> Unit {
  let graph = g.graph()
  graph.set_float("ranksep", graph.get_float_or("ranksep", 50.0) / 2.0)
  let rank_dir = graph.get_string_or("rankdir", "tb").to_upper()
  for e in g.edges() {
    let edge = layout_edge_attrs(g.edge_obj(e))
    edge.set_int("minlen", edge.get_int_or("minlen", 1) * 2)
    if edge.get_string_or("labelpos", "r").to_lower() != "c" {
      if rank_dir == "TB" || rank_dir == "BT" {
        edge.set_float(
          "width",
          edge.get_float_or("width", 0.0) +
          edge.get_float_or("labeloffset", 10.0),
        )
      } else {
        edge.set_float(
          "height",
          edge.get_float_or("height", 0.0) +
          edge.get_float_or("labeloffset", 10.0),
        )
      }
    }
    g.set_edge_obj(e, label=attrs_value(edge))
  }
}

///|
fn layout_remove_self_edges(g : Graph) -> Map[String, Array[LayoutSelfEdge]] {
  let out : Map[String, Array[LayoutSelfEdge]] = Map::new()
  let edges = g.edges()
  for e in edges {
    if e.v == e.w {
      let self_edges = out.get_or_default(e.v, [])
      let label = if g.edge_obj(e) is Some(label) {
        clone_value(label)
      } else {
        attrs_value(empty_attrs())
      }
      self_edges.push({ e, label })
      out.set(e.v, self_edges)
      g.remove_edge_obj(e)
    }
  }
  out
}

///|
fn layout_rank_non_compound(g : Graph) -> Unit {
  let non_compound = as_non_compound_graph(g)
  rank(non_compound)
  for v in non_compound.nodes() {
    if g.node_opt(v) is Some(node) {
      if non_compound.node(v).get_int("rank") is Some(rank) {
        node.set_int("rank", rank)
      }
    }
  }
}

///|
fn layout_inject_edge_label_proxies(g : Graph) -> Unit {
  for e in g.edges() {
    let edge = layout_edge_attrs(g.edge_obj(e))
    if edge.get_float_or("width", 0.0) != 0.0 &&
      edge.get_float_or("height", 0.0) != 0.0 {
      let v = g.node(e.v)
      let w = g.node(e.w)
      let rank = (w.get_int_or("rank", 0) - v.get_int_or("rank", 0)) / 2 +
        v.get_int_or("rank", 0)
      let label = empty_attrs()
      label.set_int("rank", rank)
      label.set_edge("e", e)
      ignore(add_dummy_node(g, "edge-proxy", label, "_ep"))
    }
  }
}

///|
fn layout_assign_rank_min_max(g : Graph) -> Unit {
  let mut max_rank = 0
  for v in g.nodes() {
    let node = g.node(v)
    if node.get_string("borderTop") is Some(border_top) {
      if node.get_string("borderBottom") is Some(border_bottom) {
        node.set_int("minRank", g.node(border_top).get_int_or("rank", 0))
        let node_max = g.node(border_bottom).get_int_or("rank", 0)
        node.set_int("maxRank", node_max)
        if node_max > max_rank {
          max_rank = node_max
        }
      }
    }
  }
  g.graph().set_int("maxRank", max_rank)
}

///|
fn layout_remove_edge_label_proxies(g : Graph) -> Unit {
  let nodes = g.nodes()
  for v in nodes {
    let node = g.node(v)
    if node.get_string_or("dummy", "") == "edge-proxy" {
      if node.get_edge("e") is Some(e) {
        let edge = layout_edge_attrs(g.edge_obj(e))
        edge.set_int("labelRank", node.get_int_or("rank", 0))
        g.set_edge_obj(e, label=attrs_value(edge))
      }
      g.remove_node(v)
    }
  }
}

///|
fn layout_insert_self_edges(
  g : Graph,
  self_edges : Map[String, Array[LayoutSelfEdge]],
) -> Unit {
  let layers = build_layer_matrix(g)
  for layer in layers {
    let mut order_shift = 0
    for i = 0; i < layer.length(); i = i + 1 {
      let v = layer[i]
      if v == "" {
        continue
      }
      let node = g.node(v)
      node.set_int("order", i + order_shift)
      for self_edge in self_edges.get_or_default(v, []) {
        order_shift = order_shift + 1
        let edge_label = layout_edge_attrs(Some(clone_value(self_edge.label)))
        let label = empty_attrs()
        label.set_float("width", edge_label.get_float_or("width", 0.0))
        label.set_float("height", edge_label.get_float_or("height", 0.0))
        label.set_int("rank", node.get_int_or("rank", 0))
        label.set_int("order", i + order_shift)
        label.set_edge("e", self_edge.e)
        label.set_value("label", clone_value(self_edge.label))
        ignore(add_dummy_node(g, "selfedge", label, "_se"))
      }
    }
  }
}

///|
fn layout_position_self_edges(g : Graph) -> Unit {
  let nodes = g.nodes()
  for v in nodes {
    let node = g.node(v)
    if node.get_string_or("dummy", "") == "selfedge" {
      if node.get_edge("e") is Some(e) {
        let self_node = g.node(e.v)
        let x = self_node.get_float_or("x", 0.0) +
          self_node.get_float_or("width", 0.0) / 2.0
        let y = self_node.get_float_or("y", 0.0)
        let dx = node.get_float_or("x", 0.0) - x
        let dy = self_node.get_float_or("height", 0.0) / 2.0
        let label_value = if node.get_value("label") is Some(label) {
          label
        } else {
          attrs_value(empty_attrs())
        }
        g.set_edge_obj(e, label=clone_value(label_value))
        g.remove_node(v)
        let label = layout_edge_attrs(Some(label_value))
        label.set_points("points", [
          point(x + 2.0 * dx / 3.0, y - dy),
          point(x + 5.0 * dx / 6.0, y - dy),
          point(x + dx, y),
          point(x + 5.0 * dx / 6.0, y + dy),
          point(x + 2.0 * dx / 3.0, y + dy),
        ])
        label.set_float("x", node.get_float_or("x", 0.0))
        label.set_float("y", node.get_float_or("y", 0.0))
        g.set_edge_obj(e, label=attrs_value(label))
      }
    }
  }
}

///|
fn layout_remove_border_nodes(g : Graph) -> Unit {
  for v in g.nodes() {
    if !g.children(v~).is_empty() {
      let node = g.node(v)
      let border_left = node.get_strings("borderLeft")
      let border_right = node.get_strings("borderRight")
      if node.get_string("borderTop") is Some(border_top) &&
        node.get_string("borderBottom") is Some(border_bottom) &&
        border_left is Some(border_left) &&
        border_right is Some(border_right) &&
        !border_left.is_empty() &&
        !border_right.is_empty() {
        let t = g.node(border_top)
        let b = g.node(border_bottom)
        let l = g.node(border_left[border_left.length() - 1])
        let r = g.node(border_right[border_right.length() - 1])
        let width = (r.get_float_or("x", 0.0) - l.get_float_or("x", 0.0)).abs()
        let height = (b.get_float_or("y", 0.0) - t.get_float_or("y", 0.0)).abs()
        node.set_float("width", width)
        node.set_float("height", height)
        node.set_float("x", l.get_float_or("x", 0.0) + width / 2.0)
        node.set_float("y", t.get_float_or("y", 0.0) + height / 2.0)
      }
    }
  }
  let nodes = g.nodes()
  for v in nodes {
    if g.node(v).get_string_or("dummy", "") == "border" {
      g.remove_node(v)
    }
  }
}

///|
fn layout_fixup_edge_label_coords(g : Graph) -> Unit {
  for e in g.edges() {
    let edge = layout_edge_attrs(g.edge_obj(e))
    if edge.get_float("x") is Some(x) {
      let label_pos = edge.get_string_or("labelpos", "r")
      if label_pos == "l" || label_pos == "r" {
        edge.set_float(
          "width",
          edge.get_float_or("width", 0.0) -
          edge.get_float_or("labeloffset", 10.0),
        )
      }
      if label_pos == "l" {
        edge.set_float(
          "x",
          x -
          edge.get_float_or("width", 0.0) / 2.0 -
          edge.get_float_or("labeloffset", 10.0),
        )
      } else if label_pos == "r" {
        edge.set_float(
          "x",
          x +
          edge.get_float_or("width", 0.0) / 2.0 +
          edge.get_float_or("labeloffset", 10.0),
        )
      }
      g.set_edge_obj(e, label=attrs_value(edge))
    }
  }
}

///|
fn layout_reverse_points_for_reversed_edges(g : Graph) -> Unit {
  for e in g.edges() {
    let edge = layout_edge_attrs(g.edge_obj(e))
    if edge.get_bool_or("reversed", false) {
      if edge.get_points("points") is Some(points) {
        edge.set_points("points", layout_reverse_points(points))
        g.set_edge_obj(e, label=attrs_value(edge))
      }
    }
  }
}

///|
fn layout_translate_graph(g : Graph) -> Unit {
  if g.nodes().is_empty() {
    g.graph().set_float("width", 0.0)
    g.graph().set_float("height", 0.0)
    return
  }
  let mut min_x = 9_999_999_999.0
  let mut max_x = 0.0
  let mut min_y = 9_999_999_999.0
  let mut max_y = 0.0
  let graph_label = g.graph()
  let margin_x = graph_label.get_float_or("marginx", 0.0)
  let margin_y = graph_label.get_float_or("marginy", 0.0)
  for v in g.nodes() {
    let node = g.node(v)
    let x = node.get_float_or("x", 0.0)
    let y = node.get_float_or("y", 0.0)
    let w = node.get_float_or("width", 0.0)
    let h = node.get_float_or("height", 0.0)
    min_x = layout_min(min_x, x - w / 2.0)
    max_x = layout_max(max_x, x + w / 2.0)
    min_y = layout_min(min_y, y - h / 2.0)
    max_y = layout_max(max_y, y + h / 2.0)
  }
  for e in g.edges() {
    let edge = layout_edge_attrs(g.edge_obj(e))
    if edge.get_float("x") is Some(x) {
      let y = edge.get_float_or("y", 0.0)
      let w = edge.get_float_or("width", 0.0)
      let h = edge.get_float_or("height", 0.0)
      min_x = layout_min(min_x, x - w / 2.0)
      max_x = layout_max(max_x, x + w / 2.0)
      min_y = layout_min(min_y, y - h / 2.0)
      max_y = layout_max(max_y, y + h / 2.0)
    }
  }
  min_x = min_x - margin_x
  min_y = min_y - margin_y
  for v in g.nodes() {
    let node = g.node(v)
    node.set_float("x", node.get_float_or("x", 0.0) - min_x)
    node.set_float("y", node.get_float_or("y", 0.0) - min_y)
  }
  for e in g.edges() {
    let edge = layout_edge_attrs(g.edge_obj(e))
    if edge.get_points("points") is Some(points) {
      for p in points {
        p.x = p.x - min_x
        p.y = p.y - min_y
      }
      edge.set_points("points", points)
    }
    if edge.get_float("x") is Some(x) {
      edge.set_float("x", x - min_x)
    }
    if edge.get_float("y") is Some(y) {
      edge.set_float("y", y - min_y)
    }
    g.set_edge_obj(e, label=attrs_value(edge))
  }
  graph_label.set_float("width", max_x - min_x + margin_x)
  graph_label.set_float("height", max_y - min_y + margin_y)
}

///|
fn layout_assign_node_intersects(g : Graph) -> Unit {
  for e in g.edges() {
    let edge = layout_edge_attrs(g.edge_obj(e))
    let node_v = g.node(e.v)
    let node_w = g.node(e.w)
    let mut points = if edge.get_points("points") is Some(points) {
      points
    } else {
      []
    }
    let p1 = if points.is_empty() {
      point(node_w.get_float_or("x", 0.0), node_w.get_float_or("y", 0.0))
    } else {
      points[0]
    }
    let p2 = if points.is_empty() {
      point(node_v.get_float_or("x", 0.0), node_v.get_float_or("y", 0.0))
    } else {
      points[points.length() - 1]
    }
    let head = intersect_rect(layout_rect_from_node(node_v), p1)
    let tail = intersect_rect(layout_rect_from_node(node_w), p2)
    points = [head] + points + [tail]
    edge.set_points("points", points)
    g.set_edge_obj(e, label=attrs_value(edge))
  }
}

///|
fn layout_rect_from_node(node : Attrs) -> Rect {
  rect(
    node.get_float_or("x", 0.0),
    node.get_float_or("y", 0.0),
    node.get_float_or("width", 0.0),
    node.get_float_or("height", 0.0),
  )
}

///|
fn layout_graph_num_attrs() -> Array[String] {
  ["nodesep", "edgesep", "ranksep", "marginx", "marginy"]
}

///|
fn layout_graph_attrs() -> Array[String] {
  ["acyclicer", "ranker", "rankdir", "align"]
}

///|
fn layout_node_num_attrs() -> Array[String] {
  ["width", "height", "rank"]
}

///|
fn layout_edge_num_attrs() -> Array[String] {
  ["minlen", "weight", "width", "height", "labeloffset"]
}

///|
fn layout_edge_attrs_keys() -> Array[String] {
  ["labelpos"]
}

///|
fn layout_graph_defaults() -> Attrs {
  let out = empty_attrs()
  out.set_float("ranksep", 50.0)
  out.set_float("edgesep", 20.0)
  out.set_float("nodesep", 50.0)
  out.set_string("rankdir", "tb")
  out
}

///|
fn layout_node_defaults() -> Attrs {
  let out = empty_attrs()
  out.set_float("width", 0.0)
  out.set_float("height", 0.0)
  out
}

///|
fn layout_edge_defaults() -> Attrs {
  let out = empty_attrs()
  out.set_int("minlen", 1)
  out.set_float("weight", 1.0)
  out.set_float("width", 0.0)
  out.set_float("height", 0.0)
  out.set_float("labeloffset", 10.0)
  out.set_string("labelpos", "r")
  out
}

///|
fn layout_canonicalize(attrs : Attrs) -> Attrs {
  let out = empty_attrs()
  attrs
  .keys()
  .each(key => {
    if attrs.get(key) is Some(value) {
      out.set(key.to_lower(), value)
    }
  })
  out
}

///|
fn layout_select_number_attrs(source : Attrs, keys : Array[String]) -> Attrs {
  let out = empty_attrs()
  for key in keys {
    if source.get_float(key) is Some(value) {
      out.set_float(key, value)
    }
  }
  out
}

///|
fn layout_merge_attrs(dst : Attrs, src : Attrs) -> Unit {
  src.keys().each(key => if src.get(key) is Some(value) { dst.set(key, value) })
}

///|
fn layout_reverse_points(points : Array[Point]) -> Array[Point] {
  let out = []
  for i = points.length() - 1; i >= 0; i = i - 1 {
    out.push(points[i])
  }
  out
}

///|
fn layout_edge_attrs(label : Value?) -> Attrs {
  if value_as_attrs(label) is Some(attrs) {
    attrs
  } else {
    empty_attrs()
  }
}

///|
fn layout_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn layout_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
