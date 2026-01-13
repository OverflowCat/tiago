// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
test "resolve simple variable" {
  let ir = Map::new()
  // Create vars map
  let vars_map = Map::new()
  let color = Field::new("color", Some(Scalar::string("red")), None, [])
  vars_map.add_field(color)
  let vars = Field::new("vars", None, Some(Composite::Map(vars_map)), [])
  ir.add_field(vars)
  // Create field with substitution
  let server_map = Map::new()
  let fill = Field::new("fill", Some(Scalar::string("${color}")), None, [])
  server_map.add_field(fill)
  let server = Field::new("server", None, Some(Composite::Map(server_map)), [])
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
  let vars_map = Map::new()
  let colors_map = Map::new()
  let primary = Field::new("primary", Some(Scalar::string("blue")), None, [])
  colors_map.add_field(primary)
  let colors = Field::new("colors", None, Some(Composite::Map(colors_map)), [])
  vars_map.add_field(colors)
  let vars = Field::new("vars", None, Some(Composite::Map(vars_map)), [])
  ir.add_field(vars)
  // Create field with nested substitution
  let box_map = Map::new()
  let fill = Field::new(
    "fill",
    Some(Scalar::string("${colors.primary}")),
    None,
    [],
  )
  box_map.add_field(fill)
  let box = Field::new("box", None, Some(Composite::Map(box_map)), [])
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
  let vars_map = Map::new()
  let name = Field::new("name", Some(Scalar::string("Server")), None, [])
  vars_map.add_field(name)
  let vars = Field::new("vars", None, Some(Composite::Map(vars_map)), [])
  ir.add_field(vars)
  // Create field with $name substitution
  let node = Field::new("node", Some(Scalar::string("$name")), None, [])
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
  let node = Field::new("node", Some(Scalar::string("${unknown}")), None, [])
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

///|
test "deeply nested variable substitution (3+ levels)" {
  // Test: vars: { a: { b: { c: "deep" } } }, x: ${a.b.c}
  let ir = Map::new()
  // Build deeply nested vars structure
  let vars_map = Map::new()
  let a_map = Map::new()
  let b_map = Map::new()
  let c = Field::new("c", Some(Scalar::string("deep")), None, [])
  b_map.add_field(c)
  let b = Field::new("b", None, Some(Composite::Map(b_map)), [])
  a_map.add_field(b)
  let a = Field::new("a", None, Some(Composite::Map(a_map)), [])
  vars_map.add_field(a)
  let vars = Field::new("vars", None, Some(Composite::Map(vars_map)), [])
  ir.add_field(vars)
  // Create field using deeply nested path
  let x = Field::new("x", Some(Scalar::string("${a.b.c}")), None, [])
  ir.add_field(x)
  // Resolve substitutions
  ir.resolve_substitutions()
  // Check that deeply nested variable was resolved
  guard ir.get_field("x") is Some(xf) else { fail("expected x field") }
  assert_eq(xf.primary, Some(Scalar::string("deep")))
}

///|
test "variable shadowing in nested scopes" {
  // Test: vars: { x: "outer" }, container: { vars: { x: "inner" }, label: ${x} }
  // The inner ${x} should resolve to "inner" (local scope first)
  let ir = Map::new()
  // Create outer vars
  let outer_vars_map = Map::new()
  let outer_x = Field::new("x", Some(Scalar::string("outer")), None, [])
  outer_vars_map.add_field(outer_x)
  let outer_vars = Field::new(
    "vars",
    None,
    Some(Composite::Map(outer_vars_map)),
    [],
  )
  ir.add_field(outer_vars)
  // Create container with inner vars
  let container_map = Map::new()
  let inner_vars_map = Map::new()
  let inner_x = Field::new("x", Some(Scalar::string("inner")), None, [])
  inner_vars_map.add_field(inner_x)
  let inner_vars = Field::new(
    "vars",
    None,
    Some(Composite::Map(inner_vars_map)),
    [],
  )
  container_map.add_field(inner_vars)
  // Add field that uses ${x}
  let label = Field::new("label", Some(Scalar::string("${x}")), None, [])
  container_map.add_field(label)
  let container = Field::new(
    "container",
    None,
    Some(Composite::Map(container_map)),
    [],
  )
  ir.add_field(container)
  // Resolve substitutions
  ir.resolve_substitutions()
  // Check that inner scope's x was used
  guard ir.get_field("container") is Some(c) else { fail("expected container") }
  guard c.composite is Some(Composite::Map(cm)) else {
    fail("expected container map")
  }
  guard cm.get_field("label") is Some(lbl) else { fail("expected label") }
  assert_eq(lbl.primary, Some(Scalar::string("inner")))
}

///|
test "outer variable accessible when not shadowed" {
  // Test: vars: { y: "outer" }, container: { vars: { x: "inner" }, label: ${y} }
  // ${y} should resolve to "outer" from outer scope
  let ir = Map::new()
  // Create outer vars with y
  let outer_vars_map = Map::new()
  let outer_y = Field::new("y", Some(Scalar::string("outer")), None, [])
  outer_vars_map.add_field(outer_y)
  let outer_vars = Field::new(
    "vars",
    None,
    Some(Composite::Map(outer_vars_map)),
    [],
  )
  ir.add_field(outer_vars)
  // Create container with inner vars (different variable)
  let container_map = Map::new()
  let inner_vars_map = Map::new()
  let inner_x = Field::new("x", Some(Scalar::string("inner")), None, [])
  inner_vars_map.add_field(inner_x)
  let inner_vars = Field::new(
    "vars",
    None,
    Some(Composite::Map(inner_vars_map)),
    [],
  )
  container_map.add_field(inner_vars)
  // Add field that uses ${y} from outer scope
  let label = Field::new("label", Some(Scalar::string("${y}")), None, [])
  container_map.add_field(label)
  let container = Field::new(
    "container",
    None,
    Some(Composite::Map(container_map)),
    [],
  )
  ir.add_field(container)
  // Resolve substitutions
  ir.resolve_substitutions()
  // Check that outer scope's y was used
  guard ir.get_field("container") is Some(c) else { fail("expected container") }
  guard c.composite is Some(Composite::Map(cm)) else {
    fail("expected container map")
  }
  guard cm.get_field("label") is Some(lbl) else { fail("expected label") }
  assert_eq(lbl.primary, Some(Scalar::string("outer")))
}

///|
test "edge label substitution" {
  // Test: vars: { msg: "hello" }, a -> b: ${msg}
  let ir = Map::new()
  // Create vars
  let vars_map = Map::new()
  vars_map.add_field(Field::new("msg", Some(Scalar::string("hello")), None, []))
  ir.add_field(Field::new("vars", None, Some(Composite::Map(vars_map)), []))
  // Create source and destination nodes
  let a = Field::simple("a")
  ir.add_field(a)
  let b = Field::simple("b")
  ir.add_field(b)
  // Create edge with variable in label
  let edge = Edge::new(
    EdgeID::new(["a"], ["b"], false, true),
    Some(Scalar::string("${msg}")),
    None,
    [],
  )
  ir.add_edge(edge)
  // Resolve substitutions
  ir.resolve_substitutions()
  // Check that edge label was resolved
  assert_eq(ir.edges.length(), 1)
  assert_eq(ir.edges[0].primary, Some(Scalar::string("hello")))
}
