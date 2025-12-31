///|
test "resolve simple variable" {
  let ir = Map::new()
  // Create vars map
  let vars = Field::simple("vars")
  let vars_map = Map::new()
  let color = Field::simple("color")
  color.primary = Some(Scalar::string("red"))
  vars_map.add_field(color)
  vars.composite = Some(Composite::Map(vars_map))
  ir.add_field(vars)
  // Create field with substitution
  let server = Field::simple("server")
  let server_map = Map::new()
  let fill = Field::simple("fill")
  fill.primary = Some(Scalar::string("${color}"))
  server_map.add_field(fill)
  server.composite = Some(Composite::Map(server_map))
  ir.add_field(server)
  // Resolve substitutions
  ir.resolve_substitutions()
  // Check that substitution was resolved
  guard ir.get_field("server") is Some(s) else { fail("expected server") }
  guard s.composite is Some(Composite::Map(sm)) else {
    fail("expected server map")
  }
  guard sm.get_field("fill") is Some(f) else { fail("expected fill") }
  assert_eq(f.primary, Some(Scalar::string("red")))
}

///|
test "resolve nested variable" {
  let ir = Map::new()
  // Create vars map with nested structure
  let vars = Field::simple("vars")
  let vars_map = Map::new()
  let colors = Field::simple("colors")
  let colors_map = Map::new()
  let primary = Field::simple("primary")
  primary.primary = Some(Scalar::string("blue"))
  colors_map.add_field(primary)
  colors.composite = Some(Composite::Map(colors_map))
  vars_map.add_field(colors)
  vars.composite = Some(Composite::Map(vars_map))
  ir.add_field(vars)
  // Create field with nested substitution
  let box = Field::simple("box")
  let box_map = Map::new()
  let fill = Field::simple("fill")
  fill.primary = Some(Scalar::string("${colors.primary}"))
  box_map.add_field(fill)
  box.composite = Some(Composite::Map(box_map))
  ir.add_field(box)
  // Resolve substitutions
  ir.resolve_substitutions()
  // Check that substitution was resolved
  guard ir.get_field("box") is Some(b) else { fail("expected box") }
  guard b.composite is Some(Composite::Map(bm)) else {
    fail("expected box map")
  }
  guard bm.get_field("fill") is Some(f) else { fail("expected fill") }
  assert_eq(f.primary, Some(Scalar::string("blue")))
}

///|
test "resolve simple dollar variable" {
  let ir = Map::new()
  // Create vars map
  let vars = Field::simple("vars")
  let vars_map = Map::new()
  let name = Field::simple("name")
  name.primary = Some(Scalar::string("Server"))
  vars_map.add_field(name)
  vars.composite = Some(Composite::Map(vars_map))
  ir.add_field(vars)
  // Create field with $name substitution
  let node = Field::simple("node")
  node.primary = Some(Scalar::string("$name"))
  ir.add_field(node)
  // Resolve substitutions
  ir.resolve_substitutions()
  // Check that substitution was resolved
  guard ir.get_field("node") is Some(n) else { fail("expected node") }
  assert_eq(n.primary, Some(Scalar::string("Server")))
}

///|
test "unresolved variable stays unchanged" {
  let ir = Map::new()
  // Create field with unknown variable
  let node = Field::simple("node")
  node.primary = Some(Scalar::string("${unknown}"))
  ir.add_field(node)
  // Resolve substitutions
  ir.resolve_substitutions()
  // Check that value stayed unchanged
  guard ir.get_field("node") is Some(n) else { fail("expected node") }
  assert_eq(n.primary, Some(Scalar::string("${unknown}")))
}

///|
test "split_dot_path" {
  let path = split_dot_path("a.b.c")
  assert_eq(path.length(), 3)
  assert_eq(path[0], "a")
  assert_eq(path[1], "b")
  assert_eq(path[2], "c")
  let single = split_dot_path("single")
  assert_eq(single.length(), 1)
  assert_eq(single[0], "single")
}

///|
test "join_strings" {
  let arr = ["a", "b", "c"]
  assert_eq(join_strings(arr, "."), "a.b.c")
  assert_eq(join_strings(arr, ", "), "a, b, c")
  let empty : Array[String] = []
  assert_eq(join_strings(empty, "."), "")
  let single = ["one"]
  assert_eq(join_strings(single, "."), "one")
}
