///|
priv struct Counter {
  mut value : Int
}

///|
let id_counter : Counter = { value: 0 }

///|
let graph_id_counter_key = "__moon_dagre_uid"

///|
// Internal helper: generate deterministic ids per graph instance so repeated
// layouts in the same process don't depend on global counter state.
pub fn unique_id_for_graph(g : Graph, prefix : String) -> String {
  let graph = g.graph()
  let next = graph.get_int_or(graph_id_counter_key, 0) + 1
  graph.set_int(graph_id_counter_key, next)
  prefix + "\{next}"
}

///|
pub struct Partition[T] {
  lhs : Array[T]
  rhs : Array[T]
}

///|
pub struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub fn rect(x : Double, y : Double, width : Double, height : Double) -> Rect {
  { x, y, width, height }
}

///|
pub fn add_dummy_node(
  g : Graph,
  typ : String,
  attrs : Attrs,
  name : String,
) -> String {
  let mut v = name
  while g.has_node(v) {
    v = unique_id(name)
  }
  attrs.set_string("dummy", typ)
  g.set_node(v, label=attrs)
  v
}

///|
pub fn simplify(g : Graph) -> Graph {
  let simplified = Graph::new()
  simplified.set_graph(clone_attrs(g.graph()))
  for v in g.nodes() {
    simplified.set_node(v, label=clone_attrs(g.node(v)))
  }
  for e in g.edges() {
    let simple_label = attrs_from_edge_label(simplified.edge(e.v, e.w))
    let label = attrs_from_edge_label(g.edge_obj(e))
    let merged = empty_attrs()
    merged.set_float(
      "weight",
      simple_label.get_float_or("weight", 0.0) +
      label.get_float_or("weight", 0.0),
    )
    merged.set_int(
      "minlen",
      int_max(
        simple_label.get_int_or("minlen", 1),
        label.get_int_or("minlen", 1),
      ),
    )
    simplified.set_edge(e.v, e.w, label=attrs_value(merged))
  }
  simplified
}

///|
pub fn as_non_compound_graph(g : Graph) -> Graph {
  let simplified = Graph::new(multigraph=g.is_multigraph())
  simplified.set_graph(clone_attrs(g.graph()))
  for v in g.nodes() {
    if g.children(v~).is_empty() {
      simplified.set_node(v, label=clone_attrs(g.node(v)))
    }
  }
  for e in g.edges() {
    if g.edge_obj(e) is Some(label) {
      simplified.set_edge_obj(e, label=clone_value(label))
    }
  }
  simplified
}

///|
pub fn successor_weights(g : Graph) -> Map[String, Map[String, Double]] {
  let out = Map::new()
  for v in g.nodes() {
    let sucs = Map::new()
    for e in g.out_edges(v) {
      let weight = edge_weight(g.edge_obj(e))
      sucs.set(e.w, sucs.get_or_default(e.w, 0.0) + weight)
    }
    out.set(v, sucs)
  }
  out
}

///|
pub fn predecessor_weights(g : Graph) -> Map[String, Map[String, Double]] {
  let out = Map::new()
  for v in g.nodes() {
    let preds = Map::new()
    for e in g.in_edges(v) {
      let weight = edge_weight(g.edge_obj(e))
      preds.set(e.v, preds.get_or_default(e.v, 0.0) + weight)
    }
    out.set(v, preds)
  }
  out
}

///|
pub fn intersect_rect(rect : Rect, pt : Point) -> Point {
  let x = rect.x
  let y = rect.y
  let dx = pt.x - x
  let dy = pt.y - y
  let mut w = rect.width / 2.0
  let mut h = rect.height / 2.0
  if dx == 0.0 && dy == 0.0 {
    abort("Not possible to find intersection inside of the rectangle")
  }
  let mut sx = 0.0
  let mut sy = 0.0
  if dy.abs() * w > dx.abs() * h {
    if dy < 0.0 {
      h = -h
    }
    sx = h * dx / dy
    sy = h
  } else {
    if dx < 0.0 {
      w = -w
    }
    sx = w
    sy = w * dy / dx
  }
  point(x + sx, y + sy)
}

///|
pub fn build_layer_matrix(g : Graph) -> Array[Array[String]] {
  let layering = range(max_rank(g) + 1).map(_ => [])
  for v in g.nodes() {
    let node = g.node(v)
    if node.get_int("rank") is Some(rank) {
      let order = node.get_int_or("order", 0)
      ensure_index(layering[rank], order)
      layering[rank][order] = v
    }
  }
  layering
}

///|
fn ensure_index(arr : Array[String], idx : Int) -> Unit {
  if arr.length() <= idx {
    let mut i = arr.length()
    while i <= idx {
      // Keep placeholder holes so indexes stay aligned with JS sparse arrays.
      arr.push("")
      i = i + 1
    }
  }
}

///|
pub fn normalize_ranks(g : Graph) -> Unit {
  let ranks = g.nodes().map(v => g.node(v).get_int_or("rank", @int.max_value))
  let min_rank = apply_with_chunking_min(ranks)
  for v in g.nodes() {
    let node = g.node(v)
    if node.get_int("rank") is Some(rank) {
      node.set_int("rank", rank - min_rank)
    }
  }
}

///|
pub fn remove_empty_ranks(g : Graph) -> Unit {
  let ranks = g.nodes().filter_map(v => g.node(v).get_int("rank"))
  if ranks.is_empty() {
    return
  }
  let offset = apply_with_chunking_min(ranks)
  let layers = []
  for v in g.nodes() {
    let node = g.node(v)
    if node.get_int("rank") is Some(rank0) {
      let rank = rank0 - offset
      while layers.length() <= rank {
        layers.push([])
      }
      layers[rank].push(v)
    }
  }
  let mut delta = 0
  let node_rank_factor = g.graph().get_int_or("nodeRankFactor", 0)
  for i = 0; i < layers.length(); i = i + 1 {
    let vs = layers[i]
    if vs.is_empty() && (node_rank_factor == 0 || i % node_rank_factor != 0) {
      delta = delta - 1
    } else if !vs.is_empty() && delta != 0 {
      for v in vs {
        let node = g.node(v)
        if node.get_int("rank") is Some(rank) {
          node.set_int("rank", rank + delta)
        }
      }
    }
  }
}

///|
pub fn add_border_node(
  g : Graph,
  prefix : String,
  rank? : Int,
  order? : Int,
) -> String {
  let node = empty_attrs()
  node.set_float("width", 0.0)
  node.set_float("height", 0.0)
  if rank is Some(rank) && order is Some(order) {
    node.set_int("rank", rank)
    node.set_int("order", order)
  }
  add_dummy_node(g, "border", node, prefix)
}

///|
pub fn apply_with_chunking_min(values : Array[Int]) -> Int {
  if values.is_empty() {
    @int.max_value
  } else {
    let mut out = values[0]
    for i = 1; i < values.length(); i = i + 1 {
      if values[i] < out {
        out = values[i]
      }
    }
    out
  }
}

///|
pub fn apply_with_chunking_max(values : Array[Int]) -> Int {
  if values.is_empty() {
    @int.min_value
  } else {
    let mut out = values[0]
    for i = 1; i < values.length(); i = i + 1 {
      if values[i] > out {
        out = values[i]
      }
    }
    out
  }
}

///|
pub fn max_rank(g : Graph) -> Int {
  let ranks = g.nodes().map(v => g.node(v).get_int_or("rank", @int.min_value))
  apply_with_chunking_max(ranks)
}

///|
pub fn[T] partition(
  collection : Array[T],
  predicate : (T) -> Bool,
) -> Partition[T] {
  let lhs : Array[T] = []
  let rhs : Array[T] = []
  for value in collection {
    if predicate(value) {
      lhs.push(value)
    } else {
      rhs.push(value)
    }
  }
  { lhs, rhs }
}

///|
pub fn[T] time(name : String, thunk : () -> T) -> T {
  ignore(name)
  thunk()
}

///|
pub fn[T] notime(name : String, thunk : () -> T) -> T {
  ignore(name)
  thunk()
}

///|
pub fn unique_id(prefix : String) -> String {
  id_counter.value = id_counter.value + 1
  prefix + "\{id_counter.value}"
}

///|
pub fn range(start : Int, limit? : Int, step? : Int) -> Array[Int] {
  let mut s = start
  let mut l = limit
  let step = if step is Some(step) { step } else { 1 }
  if l is None {
    l = Some(start)
    s = 0
  }
  let out : Array[Int] = []
  if l is Some(limit) {
    if step > 0 {
      for i = s; i < limit; i = i + step {
        out.push(i)
      }
    } else {
      for i = s; i > limit; i = i + step {
        out.push(i)
      }
    }
  }
  out
}

///|
pub fn pick(source : Attrs, keys : Array[String]) -> Attrs {
  let dest = empty_attrs()
  for key in keys {
    if source.get(key) is Some(value) {
      dest.set(key, value)
    }
  }
  dest
}

///|
pub fn[V, U] map_values(
  obj : Map[String, V],
  f : (V, String) -> U,
) -> Map[String, U] {
  let out : Map[String, U] = Map::new()
  obj.each((k, v) => out.set(k, f(v, k)))
  out
}

///|
pub fn map_values_prop(
  obj : Map[String, Attrs],
  prop : String,
) -> Map[String, Attr] {
  let out : Map[String, Attr] = Map::new()
  obj.each((k, v) => if v.get(prop) is Some(value) { out.set(k, value) })
  out
}

///|
pub fn[T] zip_object(
  props : Array[String],
  values : Array[T],
) -> Map[String, T] {
  let out : Map[String, T] = Map::new()
  for i = 0; i < props.length() && i < values.length(); i = i + 1 {
    out.set(props[i], values[i])
  }
  out
}

///|
fn edge_weight(label : Value?) -> Double {
  match label {
    Some(Value::VInt(v)) => v.to_double()
    Some(Value::VFloat(v)) => v
    Some(Value::VAttrs(attrs)) => attrs.get_float_or("weight", 1.0)
    _ => 1.0
  }
}

///|
fn attrs_from_edge_label(label : Value?) -> Attrs {
  match label {
    Some(Value::VAttrs(attrs)) => clone_attrs(attrs)
    Some(Value::VInt(v)) => {
      let attrs = empty_attrs()
      attrs.set_float("weight", v.to_double())
      attrs
    }
    Some(Value::VFloat(v)) => {
      let attrs = empty_attrs()
      attrs.set_float("weight", v)
      attrs
    }
    _ => empty_attrs()
  }
}

///|
fn int_max(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
