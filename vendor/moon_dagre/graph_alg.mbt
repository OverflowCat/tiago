///|
priv struct TarjanIndex {
  mut value : Int
}

///|
pub fn components(g : Graph) -> Array[Array[String]] {
  let visited = Set::new()
  let result = []
  for v in g.nodes() {
    if !visited.contains(v) {
      let component = []
      dfs_component(g, v, visited, component)
      result.push(component)
    }
  }
  result
}

///|
fn dfs_component(
  g : Graph,
  v : String,
  visited : Set[String],
  component : Array[String],
) -> Unit {
  if visited.contains(v) {
    return
  }
  visited.add(v)
  component.push(v)
  for w in g.neighbors(v) {
    dfs_component(g, w, visited, component)
  }
}

///|
pub fn find_cycles(g : Graph) -> Array[Array[String]] {
  if !g.is_directed() {
    []
  } else {
    tarjan_scc(g).filter(component => is_cycle_component(g, component))
  }
}

///|
fn is_cycle_component(g : Graph, component : Array[String]) -> Bool {
  if component.length() > 1 {
    true
  } else if component.length() == 1 {
    let v = component[0]
    g.has_edge(v, v)
  } else {
    false
  }
}

///|
fn tarjan_scc(g : Graph) -> Array[Array[String]] {
  let index : TarjanIndex = { value: 0 }
  let stack = []
  let on_stack = Set::new()
  let indices = Map::new()
  let lowlinks = Map::new()
  let result = []
  for v in g.nodes() {
    if !indices.contains(v) {
      strongconnect(g, v, index, stack, on_stack, indices, lowlinks, result)
    }
  }
  result
}

///|
fn strongconnect(
  g : Graph,
  v : String,
  index : TarjanIndex,
  stack : Array[String],
  on_stack : Set[String],
  indices : Map[String, Int],
  lowlinks : Map[String, Int],
  result : Array[Array[String]],
) -> Unit {
  indices.set(v, index.value)
  lowlinks.set(v, index.value)
  index.value = index.value + 1
  stack.push(v)
  on_stack.add(v)
  for w in g.successors(v) {
    if !indices.contains(w) {
      strongconnect(g, w, index, stack, on_stack, indices, lowlinks, result)
      lowlinks.set(v, min_int(lowlinks.at(v), lowlinks.at(w)))
    } else if on_stack.contains(w) {
      lowlinks.set(v, min_int(lowlinks.at(v), indices.at(w)))
    }
  }
  if lowlinks.at(v) == indices.at(v) {
    let component = []
    pop_component(stack, on_stack, component, v)
    result.push(component)
  }
}

///|
fn pop_component(
  stack : Array[String],
  on_stack : Set[String],
  component : Array[String],
  stop : String,
) -> Unit {
  if stack.pop() is Some(w) {
    on_stack.remove(w)
    component.push(w)
    if w != stop {
      pop_component(stack, on_stack, component, stop)
    }
  }
}

///|
pub fn preorder(g : Graph, roots : Array[String]) -> Array[String] {
  let visited = Set::new()
  let order = []
  for root in roots {
    preorder_dfs(g, root, visited, order)
  }
  order
}

///|
fn preorder_dfs(
  g : Graph,
  v : String,
  visited : Set[String],
  order : Array[String],
) -> Unit {
  if visited.contains(v) {
    return
  }
  visited.add(v)
  order.push(v)
  let neighbors = if g.is_directed() { g.successors(v) } else { g.neighbors(v) }
  for w in neighbors {
    preorder_dfs(g, w, visited, order)
  }
}

///|
pub fn postorder(g : Graph, roots : Array[String]) -> Array[String] {
  let visited = Set::new()
  let order = []
  for root in roots {
    postorder_dfs(g, root, visited, order)
  }
  order
}

///|
fn postorder_dfs(
  g : Graph,
  v : String,
  visited : Set[String],
  order : Array[String],
) -> Unit {
  if visited.contains(v) {
    return
  }
  visited.add(v)
  let neighbors = if g.is_directed() { g.successors(v) } else { g.neighbors(v) }
  for w in neighbors {
    postorder_dfs(g, w, visited, order)
  }
  order.push(v)
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}
