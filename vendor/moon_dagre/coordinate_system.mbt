///|
pub fn coordinate_adjust(g : Graph) -> Unit {
  let rank_dir = g.graph().get_string_or("rankdir", "tb").to_lower()
  if rank_dir == "lr" || rank_dir == "rl" {
    swap_width_height(g)
  }
}

///|
pub fn coordinate_undo(g : Graph) -> Unit {
  let rank_dir = g.graph().get_string_or("rankdir", "tb").to_lower()
  if rank_dir == "bt" || rank_dir == "rl" {
    reverse_y(g)
  }
  if rank_dir == "lr" || rank_dir == "rl" {
    swap_xy(g)
    swap_width_height(g)
  }
}

///|
fn swap_width_height(g : Graph) -> Unit {
  for v in g.nodes() {
    swap_width_height_one(g.node(v))
  }
  for e in g.edges() {
    if value_as_attrs(g.edge_obj(e)) is Some(edge) {
      swap_width_height_one(edge)
    }
  }
}

///|
fn swap_width_height_one(attrs : Attrs) -> Unit {
  let w = attrs.get_float_or("width", 0.0)
  let h = attrs.get_float_or("height", 0.0)
  attrs.set_float("width", h)
  attrs.set_float("height", w)
}

///|
fn reverse_y(g : Graph) -> Unit {
  for v in g.nodes() {
    reverse_y_one(g.node(v))
  }
  for e in g.edges() {
    if value_as_attrs(g.edge_obj(e)) is Some(edge) {
      if edge.get_points("points") is Some(points) {
        for p in points {
          p.y = -p.y
        }
      }
      if edge.contains("y") {
        reverse_y_one(edge)
      }
    }
  }
}

///|
fn reverse_y_one(attrs : Attrs) -> Unit {
  if attrs.get_float("y") is Some(y) {
    attrs.set_float("y", -y)
  }
}

///|
fn swap_xy(g : Graph) -> Unit {
  for v in g.nodes() {
    swap_xy_one(g.node(v))
  }
  for e in g.edges() {
    if value_as_attrs(g.edge_obj(e)) is Some(edge) {
      if edge.get_points("points") is Some(points) {
        for p in points {
          let x = p.x
          p.x = p.y
          p.y = x
        }
      }
      if edge.contains("x") {
        swap_xy_one(edge)
      }
    }
  }
}

///|
fn swap_xy_one(attrs : Attrs) -> Unit {
  let x = attrs.get_float_or("x", 0.0)
  let y = attrs.get_float_or("y", 0.0)
  attrs.set_float("x", y)
  attrs.set_float("y", x)
}
