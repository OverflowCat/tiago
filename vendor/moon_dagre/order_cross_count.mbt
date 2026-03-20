///|
pub fn order_cross_count(g : Graph, layering : Array[Array[String]]) -> Double {
  let mut cc = 0.0
  for i = 1; i < layering.length(); i = i + 1 {
    cc = cc + order_two_layer_cross_count(g, layering[i - 1], layering[i])
  }
  cc
}

///|
fn order_two_layer_cross_count(
  g : Graph,
  north_layer : Array[String],
  south_layer : Array[String],
) -> Double {
  let south_pos : Map[String, Int] = Map::new()
  for i = 0; i < south_layer.length(); i = i + 1 {
    let v = south_layer[i]
    if !order_cross_is_layer_hole(v) {
      south_pos.set(v, i)
    }
  }
  let south_entries : Array[(Int, Double)] = []
  for v in north_layer {
    if order_cross_is_layer_hole(v) {
      continue
    }
    let entries : Array[(Int, Double)] = []
    for e in g.out_edges(v) {
      if south_pos.get(e.w) is Some(pos) {
        entries.push((pos, order_cross_weight(g.edge_obj(e))))
      }
    }
    entries.sort_by((a, b) => a.0 - b.0)
    for entry in entries {
      south_entries.push(entry)
    }
  }
  let mut first_index = 1
  while first_index < south_layer.length() {
    first_index = first_index << 1
  }
  let tree_size = 2 * first_index - 1
  first_index = first_index - 1
  let tree : Array[Double] = []
  for _ in 0..<tree_size {
    tree.push(0.0)
  }
  let mut cc = 0.0
  for entry in south_entries {
    let mut index = entry.0 + first_index
    tree[index] = tree[index] + entry.1
    let mut weight_sum = 0.0
    while index > 0 {
      if index % 2 == 1 {
        weight_sum = weight_sum + tree[index + 1]
      }
      index = (index - 1) >> 1
      tree[index] = tree[index] + entry.1
    }
    cc = cc + entry.1 * weight_sum
  }
  cc
}

///|
fn order_cross_weight(label : Value?) -> Double {
  if value_as_attrs(label) is Some(attrs) {
    attrs.get_float_or("weight", 1.0)
  } else if value_as_int(label) is Some(v) {
    v.to_double()
  } else if value_as_float(label) is Some(v) {
    v
  } else {
    1.0
  }
}

///|
fn order_cross_is_layer_hole(v : String) -> Bool {
  v == ""
}
