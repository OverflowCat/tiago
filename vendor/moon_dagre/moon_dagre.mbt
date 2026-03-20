///|
pub fn new_graph(
  directed? : Bool = true,
  multigraph? : Bool = false,
  compound? : Bool = false,
) -> Graph {
  Graph::new(directed~, multigraph~, compound~)
}

///|
pub fn layout(g : Graph, debug_timing? : Bool = false) -> Graph {
  layout_run(g, debug_timing~)
}

///|
pub fn layout_with_constraints(
  g : Graph,
  constraints : Array[OrderConstraint],
  debug_timing? : Bool = false,
) -> Graph {
  layout_run_with_constraints(g, constraints, debug_timing~)
}
