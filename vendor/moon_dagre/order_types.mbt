///|
pub struct OrderBarycenterEntry {
  v : String
  mut barycenter : Double?
  mut weight : Double?
}

///|
pub struct OrderEntry {
  mut vs : Array[String]
  i : Int
  barycenter : Double?
  weight : Double?
}

///|
pub struct OrderResult {
  mut vs : Array[String]
  mut barycenter : Double?
  mut weight : Double?
}

///|
pub struct OrderConstraint {
  left : String
  right : String
}

///|
pub fn order_bary_entry(
  v : String,
  barycenter? : Double? = None,
  weight? : Double? = None,
) -> OrderBarycenterEntry {
  { v, barycenter, weight }
}

///|
pub fn order_entry(
  vs : Array[String],
  i : Int,
  barycenter? : Double? = None,
  weight? : Double? = None,
) -> OrderEntry {
  { vs, i, barycenter, weight }
}

///|
pub fn order_result(
  vs : Array[String],
  barycenter? : Double? = None,
  weight? : Double? = None,
) -> OrderResult {
  { vs, barycenter, weight }
}

///|
pub fn order_constraint(left : String, right : String) -> OrderConstraint {
  { left, right }
}
