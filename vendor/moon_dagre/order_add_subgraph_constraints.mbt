///|
pub fn order_add_subgraph_constraints(
  g : Graph,
  cg : Graph,
  vs : Array[String],
) -> Unit {
  let prev : Map[String, String] = Map::new()
  let mut root_prev : String? = None
  for v in vs {
    let mut child = g.parent(v)
    while child is Some(child_v) {
      let parent = g.parent(child_v)
      let prev_child = if parent is Some(parent_v) {
        let value = prev.get(parent_v)
        prev.set(parent_v, child_v)
        value
      } else {
        let value = root_prev
        root_prev = Some(child_v)
        value
      }
      if prev_child is Some(prev_v) {
        if prev_v != child_v {
          cg.set_edge(prev_v, child_v)
          break
        }
      }
      child = parent
    }
  }
}
