///|
pub fn order_barycenter(
  g : Graph,
  movable? : Array[String] = [],
) -> Array[OrderBarycenterEntry] {
  let out = []
  for v in movable {
    let in_v = g.in_edges(v)
    if in_v.is_empty() {
      out.push({ v, barycenter: None, weight: None })
    } else {
      let mut sum = 0.0
      let mut weight = 0.0
      for e in in_v {
        let edge_weight = order_barycenter_edge_weight(g.edge_obj(e))
        let node_u = g.node(e.v)
        let u_order = node_u.get_int_or("order", 0).to_double()
        sum = sum + edge_weight * u_order
        weight = weight + edge_weight
      }
      out.push({ v, barycenter: Some(sum / weight), weight: Some(weight) })
    }
  }
  out
}

///|
fn order_barycenter_edge_weight(label : Value?) -> Double {
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
