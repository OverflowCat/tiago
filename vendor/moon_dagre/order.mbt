///|
pub fn order_run(
  g : Graph,
  disable_optimal_order_heuristic? : Bool = false,
  constraints? : Array[OrderConstraint] = [],
) -> Unit {
  let max_rank_value = max_rank(g)
  let down_layer_graphs = order_build_layer_graphs(
    g,
    range(1, limit=max_rank_value + 1),
    "in_edges",
  )
  let up_layer_graphs = order_build_layer_graphs(
    g,
    range(max_rank_value - 1, limit=-1, step=-1),
    "out_edges",
  )
  let mut layering = order_init_order(g)
  order_assign_order(g, layering)
  if disable_optimal_order_heuristic {
    return
  }
  let mut best_cc = 999_999_999_999_999_999.0
  let mut best = order_copy_layering(layering)
  let initial_layering = order_copy_layering(layering)
  let mut best_order_distance = order_layering_distance(
    best,
    initial_layering,
  )
  let mut i = 0
  let mut last_best = 0
  while last_best < 4 {
    let layer_graphs = if i % 2 == 1 {
      down_layer_graphs
    } else {
      up_layer_graphs
    }
    order_sweep_layer_graphs(layer_graphs, i % 4 >= 2, constraints)
    layering = build_layer_matrix(g)
    let cc = order_cross_count(g, layering)
    if cc < best_cc {
      last_best = 0
      best = order_copy_layering(layering)
      best_cc = cc
    } else if cc == best_cc {
      let order_distance = order_layering_distance(layering, initial_layering)
      if order_distance < best_order_distance {
        best = order_copy_layering(layering)
        best_order_distance = order_distance
      }
    }
    i = i + 1
    last_best = last_best + 1
  }
  order_assign_order(g, best)
  order_fix_border_node_order(g)
}

///|
// Ensure border dummy nodes for each cluster are ordered left-to-right.
// This matches the expected compound layout behavior and prevents cases where
// borderLeft and borderRight swap orders at boundary ranks.
fn order_fix_border_node_order(g : Graph) -> Unit {
  if !g.is_compound() {
    return
  }
  for v in g.nodes() {
    let node = g.node(v)
    if node.get_int("minRank") is Some(min_rank) &&
      node.get_int("maxRank") is Some(max_rank) &&
      node.get_strings("borderLeft") is Some(border_lefts) &&
      node.get_strings("borderRight") is Some(border_rights) {
      let mut r = min_rank
      while r <= max_rank {
        if r >= 0 && r < border_lefts.length() && r < border_rights.length() {
          let bl = border_lefts[r]
          let br = border_rights[r]
          if bl != "" && br != "" && g.has_node(bl) && g.has_node(br) {
            let bl_order = g.node(bl).get_int_or("order", 0)
            let br_order = g.node(br).get_int_or("order", 0)
            if bl_order > br_order {
              g.node(bl).set_int("order", br_order)
              g.node(br).set_int("order", bl_order)
            }
          }
        }
        r = r + 1
      }
    }
  }
}

///|
fn order_build_layer_graphs(
  g : Graph,
  ranks : Array[Int],
  relationship : String,
) -> Array[Graph] {
  let nodes_by_rank : Map[Int, Array[String]] = Map::new()
  fn add_node_to_rank(
    nodes_by_rank : Map[Int, Array[String]],
    rank : Int,
    node : String,
  ) -> Unit {
    let nodes = nodes_by_rank.get_or_default(rank, [])
    nodes.push(node)
    nodes_by_rank.set(rank, nodes)
  }

  for v in g.nodes() {
    let node = g.node(v)
    if node.get_int("rank") is Some(rank) {
      add_node_to_rank(nodes_by_rank, rank, v)
    }
    if node.get_int("minRank") is Some(min_rank) &&
      node.get_int("maxRank") is Some(max_rank) {
      let node_rank = node.get_int("rank")
      let mut r = min_rank
      while r <= max_rank {
        if !(node_rank is Some(rank) && r == rank) {
          add_node_to_rank(nodes_by_rank, r, v)
        }
        r = r + 1
      }
    }
  }
  let out : Array[Graph] = []
  for rank in ranks {
    let nodes = nodes_by_rank.get_or_default(rank, [])
    out.push(
      order_build_layer_graph(
        g,
        rank,
        relationship,
        nodes_with_rank=Some(nodes),
      ),
    )
  }
  out
}

///|
fn order_sweep_layer_graphs(
  layer_graphs : Array[Graph],
  bias_right : Bool,
  constraints : Array[OrderConstraint],
) -> Unit {
  let cg = Graph::new()
  for lg in layer_graphs {
    for con in constraints {
      cg.set_edge(con.left, con.right)
    }
    let root = lg.graph().get_string_or("root", "")
    let sorted = order_sort_subgraph(lg, root, cg, bias_right~)
    for i = 0; i < sorted.vs.length(); i = i + 1 {
      lg.node(sorted.vs[i]).set_int("order", i)
    }
    order_add_subgraph_constraints(lg, cg, sorted.vs)
  }
}

///|
fn order_assign_order(g : Graph, layering : Array[Array[String]]) -> Unit {
  for layer in layering {
    for i = 0; i < layer.length(); i = i + 1 {
      let v = layer[i]
      if v == "" {
        continue
      }
      g.node(v).set_int("order", i)
    }
  }
}

///|
fn order_copy_layering(layering : Array[Array[String]]) -> Array[Array[String]] {
  layering.map(layer => layer.copy())
}

///|
fn order_layering_distance(
  layering : Array[Array[String]],
  baseline : Array[Array[String]],
) -> Int {
  let baseline_index_by_node : Map[String, Int] = Map::new()
  for layer in baseline {
    for i = 0; i < layer.length(); i = i + 1 {
      let v = layer[i]
      if v != "" {
        baseline_index_by_node.set(v, i)
      }
    }
  }
  let mut distance = 0
  for layer in layering {
    for i = 0; i < layer.length(); i = i + 1 {
      let v = layer[i]
      if v == "" {
        continue
      }
      match baseline_index_by_node.get(v) {
        Some(baseline_index) =>
          distance = distance + (i - baseline_index).abs()
        None => ()
      }
    }
  }
  distance
}
