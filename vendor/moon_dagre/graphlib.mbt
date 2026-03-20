///|
let root_node = "\u0000"

///|
let edge_sep = "\u0001"

///|
struct EdgeRecord {
  obj : EdgeObj
  label : Value
}

///|
pub struct Graph {
  directed : Bool
  multigraph : Bool
  compound : Bool
  mut graph_label : Attrs
  nodes : Map[String, Attrs]
  node_order : Array[String]
  node_index : Map[String, Int]
  node_seen : Set[String]
  edges : Map[String, EdgeRecord]
  edge_order : Array[String]
  edge_seen : Set[String]
  parent_by_node : Map[String, String]
  children_by_node : Map[String, Set[String]]
  // Tracks child insertion time (via set_node/set_parent) so Graph::children can
  // preserve upstream graphlib's child enumeration order.
  mut child_seq : Int
  child_add_index : Map[String, Int]
  mut default_edge_label_fn : () -> Value

  fn new(directed? : Bool, multigraph? : Bool, compound? : Bool) -> Graph
}

///|
pub fn Graph::new(
  directed? : Bool = true,
  multigraph? : Bool = false,
  compound? : Bool = false,
) -> Graph {
  let children = Map::new()
  children.set(root_node, Set::new())
  let node_index : Map[String, Int] = Map::new()
  let node_seen : Set[String] = Set::new()
  let edge_seen : Set[String] = Set::new()
  let child_add_index : Map[String, Int] = Map::new()
  {
    directed,
    multigraph,
    compound,
    graph_label: empty_attrs(),
    nodes: Map::new(),
    node_order: [],
    node_index,
    node_seen,
    edges: Map::new(),
    edge_order: [],
    edge_seen,
    parent_by_node: Map::new(),
    children_by_node: children,
    child_seq: 0,
    child_add_index,
    default_edge_label_fn: () => Value::VNull,
  }
}

///|
pub fn Graph::is_directed(self : Graph) -> Bool {
  self.directed
}

///|
pub fn Graph::is_multigraph(self : Graph) -> Bool {
  self.multigraph
}

///|
pub fn Graph::is_compound(self : Graph) -> Bool {
  self.compound
}

///|
pub fn Graph::set_graph(self : Graph, label : Attrs) -> Unit {
  self.graph_label = label
}

///|
pub fn Graph::graph(self : Graph) -> Attrs {
  self.graph_label
}

///|
pub fn Graph::set_default_edge_label(self : Graph, f : () -> Value) -> Unit {
  self.default_edge_label_fn = f
}

///|
pub fn Graph::set_node(self : Graph, v : String, label? : Attrs) -> Unit {
  let node_label = if label is Some(label) { label } else { empty_attrs() }
  if !self.nodes.contains(v) {
    self.nodes.set(v, node_label)
    if !self.node_seen.contains(v) {
      self.node_seen.add(v)
      self.node_index.set(v, self.node_order.length())
      self.node_order.push(v)
    }
    if self.compound {
      add_child(self, root_node, v)
    }
  } else {
    self.nodes.set(v, node_label)
  }
}

///|
pub fn Graph::set_nodes(
  self : Graph,
  vs : Array[String],
  label? : Attrs,
) -> Unit {
  for v in vs {
    if label is Some(label) {
      self.set_node(v, label=clone_attrs(label))
    } else {
      self.set_node(v)
    }
  }
}

///|
pub fn Graph::has_node(self : Graph, v : String) -> Bool {
  self.nodes.contains(v)
}

///|
pub fn Graph::node(self : Graph, v : String) -> Attrs {
  match self.nodes.get(v) {
    Some(label) => label
    None => abort("Unknown node: \{v}")
  }
}

///|
pub fn Graph::node_opt(self : Graph, v : String) -> Attrs? {
  self.nodes.get(v)
}

///|
pub fn Graph::nodes(self : Graph) -> Array[String] {
  let out = []
  for v in self.node_order {
    if self.nodes.contains(v) {
      out.push(v)
    }
  }
  out
}

///|
pub fn Graph::node_count(self : Graph) -> Int {
  self.nodes.length()
}

///|
pub fn Graph::set_parent(self : Graph, v : String, parent? : String) -> Unit {
  if !self.compound {
    abort("Cannot set parent in a non-compound graph")
  }
  if !self.has_node(v) {
    self.set_node(v)
  }
  let target_parent = if parent is Some(p) {
    if !self.has_node(p) {
      self.set_node(p)
    }
    p
  } else {
    root_node
  }
  if self.parent_by_node.get(v) is Some(current_parent) {
    remove_child(self, current_parent, v)
  } else {
    remove_child(self, root_node, v)
  }
  if target_parent == root_node {
    self.parent_by_node.remove(v)
    add_child(self, root_node, v)
  } else {
    self.parent_by_node.set(v, target_parent)
    add_child(self, target_parent, v)
  }
}

///|
pub fn Graph::parent(self : Graph, v : String) -> String? {
  if !self.compound {
    None
  } else {
    self.parent_by_node.get(v)
  }
}

///|
pub fn Graph::children(self : Graph, v? : String) -> Array[String] {
  if !self.compound {
    if v is Some(_) {
      []
    } else {
      self.nodes()
    }
  } else {
    let parent = if v is Some(parent) { parent } else { root_node }
    match self.children_by_node.get(parent) {
      Some(children) => {
        let out = children.to_array()
        // Preserve child insertion order to match upstream graphlib behavior.
        // Upstream stores children in object insertion order, which follows
        // set_node/set_parent calls, not node creation order.
        out.sort_by((a, b) => {
          self.child_add_index.get_or_default(a, 0) -
          self.child_add_index.get_or_default(b, 0)
        })
        out
      }
      None => []
    }
  }
}

///|
pub fn Graph::set_edge(
  self : Graph,
  v : String,
  w : String,
  label? : Value,
  name? : String,
) -> Unit {
  if !self.has_node(v) {
    self.set_node(v)
  }
  if !self.has_node(w) {
    self.set_node(w)
  }
  let normalized = normalize_edge(self, v, w, name)
  let edge_label = if label is Some(label) {
    label
  } else {
    (self.default_edge_label_fn)()
  }
  let record : EdgeRecord = { obj: normalized, label: clone_value(edge_label) }
  let key = edge_key(normalized.v, normalized.w, normalized.name)
  if !self.edge_seen.contains(key) {
    self.edge_seen.add(key)
    self.edge_order.push(key)
  }
  self.edges.set(key, record)
}

///|
pub fn Graph::set_edge_obj(self : Graph, e : EdgeObj, label? : Value) -> Unit {
  let name = e.name
  if label is Some(label) {
    self.set_edge(e.v, e.w, label~, name?)
  } else {
    self.set_edge(e.v, e.w, name?)
  }
}

///|
pub fn Graph::edge(
  self : Graph,
  v : String,
  w : String,
  name? : String,
) -> Value? {
  let normalized = normalize_edge(self, v, w, name)
  match self.edges.get(edge_key(normalized.v, normalized.w, normalized.name)) {
    Some(rec) => Some(rec.label)
    None => None
  }
}

///|
pub fn Graph::edge_obj(self : Graph, e : EdgeObj) -> Value? {
  let name = e.name
  self.edge(e.v, e.w, name?)
}

///|
pub fn Graph::has_edge(
  self : Graph,
  v : String,
  w : String,
  name? : String,
) -> Bool {
  let normalized = normalize_edge(self, v, w, name)
  self.edges.contains(edge_key(normalized.v, normalized.w, normalized.name))
}

///|
pub fn Graph::remove_edge(
  self : Graph,
  v : String,
  w : String,
  name? : String,
) -> Unit {
  let normalized = normalize_edge(self, v, w, name)
  self.edges.remove(edge_key(normalized.v, normalized.w, normalized.name))
}

///|
pub fn Graph::remove_edge_obj(self : Graph, e : EdgeObj) -> Unit {
  let name = e.name
  self.remove_edge(e.v, e.w, name?)
}

///|
pub fn Graph::edges(self : Graph) -> Array[EdgeObj] {
  let result = []
  for key in self.edge_order {
    if self.edges.get(key) is Some(rec) {
      result.push(rec.obj)
    }
  }
  result
}

///|
pub fn Graph::edge_count(self : Graph) -> Int {
  self.edges.length()
}

///|
pub fn Graph::out_edges(
  self : Graph,
  v : String,
  w? : String,
) -> Array[EdgeObj] {
  let result = []
  for key in self.edge_order {
    if self.edges.get(key) is Some(rec) {
      let e = rec.obj
      if self.directed {
        if e.v == v {
          if w is Some(w) {
            if e.w == w {
              result.push(e)
            }
          } else {
            result.push(e)
          }
        }
      } else if touches_undirected(e, v, w) {
        result.push(e)
      }
    }
  }
  result
}

///|
pub fn Graph::in_edges(self : Graph, v : String, u? : String) -> Array[EdgeObj] {
  let result = []
  for key in self.edge_order {
    if self.edges.get(key) is Some(rec) {
      let e = rec.obj
      if self.directed {
        if e.w == v {
          if u is Some(u) {
            if e.v == u {
              result.push(e)
            }
          } else {
            result.push(e)
          }
        }
      } else if touches_undirected(e, v, u) {
        result.push(e)
      }
    }
  }
  result
}

///|
pub fn Graph::node_edges(
  self : Graph,
  v : String,
  w? : String,
) -> Array[EdgeObj] {
  if self.directed {
    let ins = if w is Some(w) {
      self.in_edges(v, u=w)
    } else {
      self.in_edges(v)
    }
    let outs = if w is Some(w) {
      self.out_edges(v, w~)
    } else {
      self.out_edges(v)
    }
    let result = []
    for e in ins {
      result.push(e)
    }
    for e in outs {
      result.push(e)
    }
    return result
  }

  let result = []
  for key in self.edge_order {
    if self.edges.get(key) is Some(rec) {
      let e = rec.obj
      if w is Some(w) {
        if (e.v == v && e.w == w) || (e.v == w && e.w == v) {
          result.push(e)
        }
      } else if e.v == v || e.w == v {
        result.push(e)
      }
    }
  }
  result
}

///|
pub fn Graph::predecessors(self : Graph, v : String) -> Array[String] {
  if self.directed {
    unique_nodes(self.in_edges(v).map(e => e.v))
  } else {
    self.neighbors(v)
  }
}

///|
pub fn Graph::successors(self : Graph, v : String) -> Array[String] {
  if self.directed {
    unique_nodes(self.out_edges(v).map(e => e.w))
  } else {
    self.neighbors(v)
  }
}

///|
pub fn Graph::neighbors(self : Graph, v : String) -> Array[String] {
  let seen = Set::new()
  let out = []
  for e in self.node_edges(v) {
    let other = if e.v == v { e.w } else { e.v }
    if !seen.contains(other) {
      seen.add(other)
      out.push(other)
    }
  }
  out
}

///|
pub fn Graph::sources(self : Graph) -> Array[String] {
  if self.directed {
    self.nodes().filter(v => self.in_edges(v).length() == 0)
  } else {
    self.nodes().filter(v => self.node_edges(v).length() == 0)
  }
}

///|
pub fn Graph::sinks(self : Graph) -> Array[String] {
  if self.directed {
    self.nodes().filter(v => self.out_edges(v).length() == 0)
  } else {
    self.nodes().filter(v => self.node_edges(v).length() == 0)
  }
}

///|
pub fn Graph::set_path(
  self : Graph,
  vs : Array[String],
  label? : Value,
) -> Unit {
  for i = 1; i < vs.length(); i = i + 1 {
    let v = vs[i - 1]
    let w = vs[i]
    if label is Some(label) {
      self.set_edge(v, w, label=clone_value(label))
    } else {
      self.set_edge(v, w)
    }
  }
}

///|
pub fn Graph::remove_node(self : Graph, v : String) -> Unit {
  if !self.nodes.contains(v) {
    return
  }
  self.node_edges(v).each(e => self.remove_edge_obj(e))
  self.nodes.remove(v)
  if self.compound {
    if self.parent_by_node.get(v) is Some(parent) {
      remove_child(self, parent, v)
    } else {
      remove_child(self, root_node, v)
    }
    if self.children_by_node.get(v) is Some(children) {
      let child_list = children.to_array()
      for child in child_list {
        self.set_parent(child)
      }
    }
    self.children_by_node.remove(v)
    self.parent_by_node.remove(v)
  }
}

///|
fn add_child(graph : Graph, parent : String, child : String) -> Unit {
  if graph.children_by_node.get(parent) is Some(children) {
    if !children.contains(child) {
      children.add(child)
      graph.child_seq = graph.child_seq + 1
      graph.child_add_index.set(child, graph.child_seq)
    }
  } else {
    let children = Set::new()
    children.add(child)
    graph.children_by_node.set(parent, children)
    graph.child_seq = graph.child_seq + 1
    graph.child_add_index.set(child, graph.child_seq)
  }
}

///|
fn remove_child(graph : Graph, parent : String, child : String) -> Unit {
  if graph.children_by_node.get(parent) is Some(children) {
    children.remove(child)
  }
}

///|
fn edge_key(v : String, w : String, name : String?) -> String {
  let part = if name is Some(name) { name } else { "" }
  v + edge_sep + w + edge_sep + part
}

///|
fn normalize_edge(
  graph : Graph,
  v : String,
  w : String,
  name : String?,
) -> EdgeObj {
  let normalized_name = if graph.multigraph { name } else { None }
  if graph.directed || v.lexical_compare(w) <= 0 {
    let name = normalized_name
    edge_obj(v, w, name?)
  } else {
    let name = normalized_name
    edge_obj(w, v, name?)
  }
}

///|
fn touches_undirected(e : EdgeObj, v : String, other : String?) -> Bool {
  if other is Some(other) {
    (e.v == v && e.w == other) || (e.v == other && e.w == v)
  } else {
    e.v == v || e.w == v
  }
}

///|
fn unique_nodes(nodes : Array[String]) -> Array[String] {
  let seen = Set::new()
  let out = []
  for v in nodes {
    if !seen.contains(v) {
      seen.add(v)
      out.push(v)
    }
  }
  out
}
