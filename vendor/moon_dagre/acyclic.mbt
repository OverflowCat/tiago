///|
pub fn acyclic_run(g : Graph) -> Unit {
  let acyclicer = g.graph().get_string_or("acyclicer", "")
  let fas = if acyclicer == "greedy" {
    greedy_fas(g, weight_fn=weight_fn(g))
  } else {
    dfs_fas(g)
  }
  for e in fas {
    if g.edge_obj(e) is Some(label) {
      g.remove_edge_obj(e)
      let reversed = as_attrs_label(label)
      reversed.set_bool("reversed", true)
      if e.name is Some(name) {
        reversed.set_string("forwardName", name)
      }
      g.set_edge(e.w, e.v, label=Value::VAttrs(reversed), name=unique_id("rev"))
    }
  }
}

///|
fn weight_fn(g : Graph) -> (EdgeObj) -> Double {
  (e : EdgeObj) => {
    match g.edge_obj(e) {
      Some(Value::VAttrs(attrs)) => attrs.get_float_or("weight", 1.0)
      Some(Value::VInt(v)) => v.to_double()
      Some(Value::VFloat(v)) => v
      _ => 1.0
    }
  }
}

///|
fn dfs_fas(g : Graph) -> Array[EdgeObj] {
  let fas = []
  let stack = Set::new()
  let visited = Set::new()
  fn dfs(
    g : Graph,
    v : String,
    stack : Set[String],
    visited : Set[String],
    fas : Array[EdgeObj],
  ) -> Unit {
    if visited.contains(v) {
      return
    }
    visited.add(v)
    stack.add(v)
    for e in g.out_edges(v) {
      if stack.contains(e.w) {
        fas.push(e)
      } else {
        dfs(g, e.w, stack, visited, fas)
      }
    }
    stack.remove(v)
  }

  for v in g.nodes() {
    dfs(g, v, stack, visited, fas)
  }
  fas
}

///|
pub fn acyclic_undo(g : Graph) -> Unit {
  let edges = g.edges()
  for e in edges {
    if g.edge_obj(e) is Some(Value::VAttrs(label)) {
      if label.get_bool_or("reversed", false) {
        g.remove_edge_obj(e)
        let forward_name = label.get_string("forwardName")
        label.remove("reversed")
        label.remove("forwardName")
        let name = forward_name
        g.set_edge(e.w, e.v, label=Value::VAttrs(label), name?)
      }
    }
  }
}

///|
fn as_attrs_label(value : Value) -> Attrs {
  match value {
    Value::VAttrs(attrs) => clone_attrs(attrs)
    Value::VInt(v) => {
      let attrs = empty_attrs()
      attrs.set_float("weight", v.to_double())
      attrs
    }
    Value::VFloat(v) => {
      let attrs = empty_attrs()
      attrs.set_float("weight", v)
      attrs
    }
    Value::VBool(v) => {
      let attrs = empty_attrs()
      attrs.set_bool("value", v)
      attrs
    }
    Value::VString(v) => {
      let attrs = empty_attrs()
      attrs.set_string("value", v)
      attrs
    }
    Value::VNull => empty_attrs()
  }
}
