///|
pub fn order_build_layer_graph(
  g : Graph,
  rank : Int,
  relationship : String,
  nodes_with_rank? : Array[String]? = None,
) -> Graph {
  let selected_nodes = if nodes_with_rank is Some(nodes_with_rank) {
    nodes_with_rank
  } else {
    g.nodes()
  }
  let root = order_create_root_node(g)
  let result = Graph::new(compound=true)
  let graph_label = empty_attrs()
  graph_label.set_string("root", root)
  result.set_graph(graph_label)
  for v in selected_nodes {
    let node = g.node(v)
    let node_rank = node.get_int("rank")
    let min_rank = node.get_int("minRank")
    let max_rank = node.get_int("maxRank")
    let in_layer = if node_rank is Some(node_rank) {
      node_rank == rank
    } else if min_rank is Some(min_rank) && max_rank is Some(max_rank) {
      min_rank <= rank && rank <= max_rank
    } else {
      false
    }
    if in_layer {
      result.set_node(v, label=node)
      let parent = if g.parent(v) is Some(parent) { parent } else { root }
      result.set_parent(v, parent~)
      let incident = order_incident_edges(g, relationship, v)
      for e in incident {
        let u = if e.v == v { e.w } else { e.v }
        if !result.has_node(u) {
          if g.node_opt(u) is Some(u_node) {
            result.set_node(u, label=u_node)
          } else {
            result.set_node(u)
          }
        }
        let existing = order_edge_weight(result.edge(u, v))
        let w = existing + order_edge_weight(g.edge_obj(e))
        let edge = empty_attrs()
        edge.set_float("weight", w)
        result.set_edge(u, v, label=attrs_value(edge))
      }
      if node.get_int("minRank") is Some(_) {
        let cluster_label = empty_attrs()
        if node.get_strings("borderLeft") is Some(border_lefts) {
          if rank >= 0 && rank < border_lefts.length() {
            cluster_label.set_string("borderLeft", border_lefts[rank])
          }
        }
        if node.get_strings("borderRight") is Some(border_rights) {
          if rank >= 0 && rank < border_rights.length() {
            cluster_label.set_string("borderRight", border_rights[rank])
          }
        }
        result.set_node(v, label=cluster_label)
      }
    }
  }
  result
}

///|
fn order_create_root_node(g : Graph) -> String {
  let mut v = unique_id("_root")
  while g.has_node(v) {
    v = unique_id("_root")
  }
  v
}

///|
fn order_incident_edges(
  g : Graph,
  relationship : String,
  v : String,
) -> Array[EdgeObj] {
  if relationship == "inEdges" || relationship == "in_edges" {
    g.in_edges(v)
  } else {
    g.out_edges(v)
  }
}

///|
fn order_edge_weight(label : Value?) -> Double {
  if value_as_attrs(label) is Some(attrs) {
    attrs.get_float_or("weight", 0.0)
  } else if value_as_int(label) is Some(v) {
    v.to_double()
  } else if value_as_float(label) is Some(v) {
    v
  } else {
    0.0
  }
}
