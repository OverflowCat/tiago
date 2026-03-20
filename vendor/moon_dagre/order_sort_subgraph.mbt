///|
pub fn order_sort_subgraph(
  g : Graph,
  v : String,
  cg : Graph,
  bias_right? : Bool = false,
) -> OrderResult {
  let mut movable = g.children(v~)
  let node = if g.node_opt(v) is Some(node) { node } else { empty_attrs() }
  let bl = node.get_string("borderLeft")
  let br = node.get_string("borderRight")
  if bl is Some(bl) && br is Some(br) {
    movable = movable.filter(w => w != bl && w != br)
  }
  let barycenters = order_barycenter(g, movable~)
  let subgraphs : Map[String, OrderResult] = Map::new()
  for entry in barycenters {
    if !g.children(v=entry.v).is_empty() {
      let subgraph_result = order_sort_subgraph(g, entry.v, cg, bias_right~)
      subgraphs.set(entry.v, subgraph_result)
      if subgraph_result.barycenter is Some(other_bary) &&
        subgraph_result.weight is Some(other_weight) {
        if entry.barycenter is Some(target_bary) &&
          entry.weight is Some(target_weight) {
          entry.barycenter = Some(
            (target_bary * target_weight + other_bary * other_weight) /
            (target_weight + other_weight),
          )
          entry.weight = Some(target_weight + other_weight)
        } else {
          entry.barycenter = Some(other_bary)
          entry.weight = Some(other_weight)
        }
      }
    }
  }
  let entries = order_resolve_conflicts(barycenters, cg)
  order_expand_subgraphs(entries, subgraphs)
  let result = order_sort(entries, bias_right~)
  if bl is Some(bl) && br is Some(br) {
    result.vs = [bl] + result.vs + [br]
    let bl_preds = g.predecessors(bl)
    let br_preds = g.predecessors(br)
    if !bl_preds.is_empty() && !br_preds.is_empty() {
      let bl_pred = g.node(bl_preds[0])
      let br_pred = g.node(br_preds[0])
      let mut bary = 0.0
      let mut weight = 0.0
      if result.barycenter is Some(result_bary) &&
        result.weight is Some(result_weight) {
        bary = result_bary
        weight = result_weight
      }
      result.barycenter = Some(
        (
          bary * weight +
          bl_pred.get_int_or("order", 0).to_double() +
          br_pred.get_int_or("order", 0).to_double()
        ) /
        (weight + 2.0),
      )
      result.weight = Some(weight + 2.0)
    }
  }
  result
}

///|
fn order_expand_subgraphs(
  entries : Array[OrderEntry],
  subgraphs : Map[String, OrderResult],
) -> Unit {
  for entry in entries {
    let expanded : Array[String] = []
    for v in entry.vs {
      if subgraphs.get(v) is Some(subgraph) {
        for sub_v in subgraph.vs {
          expanded.push(sub_v)
        }
      } else {
        expanded.push(v)
      }
    }
    entry.vs = expanded
  }
}
