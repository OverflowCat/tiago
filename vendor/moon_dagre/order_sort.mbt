///|
pub fn order_sort(
  entries : Array[OrderEntry],
  bias_right? : Bool = false,
) -> OrderResult {
  let parts = partition(entries, entry => entry.barycenter is Some(_))
  let sortable = parts.lhs
  let unsortable = parts.rhs
  unsortable.sort_by((a, b) => b.i - a.i)
  sortable.sort_by(order_compare_with_bias(bias_right))
  let vs : Array[String] = []
  let mut sum = 0.0
  let mut weight = 0.0
  let mut vs_index = 0
  vs_index = order_consume_unsortable(vs, unsortable, vs_index)
  for entry in sortable {
    vs_index = vs_index + entry.vs.length()
    for v in entry.vs {
      vs.push(v)
    }
    if entry.barycenter is Some(entry_bary) &&
      entry.weight is Some(entry_weight) {
      sum = sum + entry_bary * entry_weight
      weight = weight + entry_weight
    }
    vs_index = order_consume_unsortable(vs, unsortable, vs_index)
  }
  if weight > 0.0 {
    { vs, barycenter: Some(sum / weight), weight: Some(weight) }
  } else {
    { vs, barycenter: None, weight: None }
  }
}

///|
fn order_consume_unsortable(
  vs : Array[String],
  unsortable : Array[OrderEntry],
  index : Int,
) -> Int {
  let mut out_index = index
  while !unsortable.is_empty() {
    let last = unsortable[unsortable.length() - 1]
    if last.i <= out_index {
      ignore(unsortable.pop())
      for v in last.vs {
        vs.push(v)
      }
      out_index = out_index + 1
    } else {
      break
    }
  }
  out_index
}

///|
fn order_compare_with_bias(bias : Bool) -> (OrderEntry, OrderEntry) -> Int {
  (entry_v : OrderEntry, entry_w : OrderEntry) => {
    match (entry_v.barycenter, entry_w.barycenter) {
      (Some(v), Some(w)) =>
        if v < w {
          -1
        } else if v > w {
          1
        } else if !bias {
          entry_v.i - entry_w.i
        } else {
          entry_w.i - entry_v.i
        }
      _ => 0
    }
  }
}
