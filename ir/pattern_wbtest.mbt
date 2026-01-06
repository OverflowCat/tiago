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
test "is_reserved_keyword" {
  assert_true(is_reserved_keyword("label"))
  assert_true(is_reserved_keyword("LABEL"))
  assert_true(is_reserved_keyword("shape"))
  assert_true(is_reserved_keyword("style"))
  assert_true(is_reserved_keyword("layers"))
  assert_true(!is_reserved_keyword("mynode"))
  assert_true(!is_reserved_keyword("server"))
}

///|
test "is_board_keyword" {
  assert_true(is_board_keyword("layers"))
  assert_true(is_board_keyword("scenarios"))
  assert_true(is_board_keyword("steps"))
  assert_true(!is_board_keyword("label"))
  assert_true(!is_board_keyword("shape"))
}

///|
test "is_double_glob" {
  assert_true(is_double_glob(["**"]))
  assert_true(!is_double_glob(["*"]))
  assert_true(!is_double_glob(["***"]))
  assert_true(!is_double_glob(["**", "extra"]))
  assert_true(!is_double_glob([]))
}

///|
test "is_triple_glob" {
  assert_true(is_triple_glob(["***"]))
  assert_true(!is_triple_glob(["*"]))
  assert_true(!is_triple_glob(["**"]))
  assert_true(!is_triple_glob([]))
}

///|
test "match_pattern simple" {
  // Empty pattern matches everything (except reserved)
  assert_true(match_pattern("server", []))
  assert_true(!match_pattern("label", [])) // reserved keyword
  // Literal match
  assert_true(match_pattern("server", ["server"]))
  assert_true(match_pattern("Server", ["server"])) // case insensitive
  assert_true(!match_pattern("client", ["server"]))
}

///|
test "match_pattern with wildcard" {
  // Prefix wildcard: *end
  assert_true(match_pattern("backend", ["*", "end"]))
  assert_true(match_pattern("frontend", ["*", "end"]))
  assert_true(!match_pattern("server", ["*", "end"]))
  // Suffix wildcard: prefix*
  assert_true(match_pattern("server1", ["server", "*"]))
  assert_true(match_pattern("server2", ["server", "*"]))
  assert_true(!match_pattern("client1", ["server", "*"]))
  // Middle wildcard: pre*suf
  assert_true(match_pattern("pre_abc_suf", ["pre", "*", "suf"]))
  assert_true(match_pattern("pre123suf", ["pre", "*", "suf"]))
  assert_true(match_pattern("prefix_suf", ["pre", "*", "suf"])) // matches pre...suf
  assert_true(!match_pattern("prefiend", ["pre", "*", "suf"])) // no suf at end
}

///|
test "double_glob" {
  // Create a map with nested fields
  let m = Map::new()
  let server = Field::simple("server")
  let server_map = Map::new()
  server_map.add_field(Field::simple("db"))
  server_map.add_field(Field::simple("cache"))
  server.composite = Some(Composite::Map(server_map))
  m.add_field(server)
  m.add_field(Field::simple("client"))
  // Double glob should return all fields recursively
  let fields = m.double_glob()
  assert_eq(fields.length(), 4) // server, db, cache, client
}

///|
test "double_glob skips board keywords" {
  let m = Map::new()
  m.add_field(Field::simple("server"))
  // Add layers with children
  let layers = Field::simple("layers")
  let layers_map = Map::new()
  layers_map.add_field(Field::simple("layer1"))
  layers.composite = Some(Composite::Map(layers_map))
  m.add_field(layers)
  // Double glob should not include layers or its children
  let fields = m.double_glob()
  assert_eq(fields.length(), 1) // only server
}

///|
test "triple_glob includes all" {
  let m = Map::new()
  m.add_field(Field::simple("server"))
  // Add layers with children
  let layers = Field::simple("layers")
  let layers_map = Map::new()
  layers_map.add_field(Field::simple("layer1"))
  layers.composite = Some(Composite::Map(layers_map))
  m.add_field(layers)
  // Triple glob should include fields inside layers
  let fields = m.triple_glob()
  assert_eq(fields.length(), 2) // server and layer1 (not layers itself)
}

///|
test "single_glob" {
  let m = Map::new()
  m.add_field(Field::simple("server1"))
  m.add_field(Field::simple("server2"))
  m.add_field(Field::simple("client"))
  // Pattern: server*
  let fields = m.single_glob(["server", "*"])
  assert_eq(fields.length(), 2)
}

///|
test "evaluate_filter shape" {
  let field = Field::simple("mybox")
  let field_map = Map::new()
  let shape_field = Field::simple("shape")
  shape_field.primary = Some(Scalar::string("rectangle"))
  field_map.add_field(shape_field)
  field.composite = Some(Composite::Map(field_map))
  let parent = Map::new()
  parent.add_field(field)
  let ctx = FilterContext::new(field, parent)
  // Should match rectangle
  assert_true(evaluate_filter(ctx, "shape", "rectangle"))
  assert_true(!evaluate_filter(ctx, "shape", "circle"))
}

///|
test "evaluate_filter with default" {
  // Field without explicit shape should default to rectangle
  let field = Field::simple("mybox")
  let parent = Map::new()
  parent.add_field(field)
  let ctx = FilterContext::new(field, parent)
  assert_true(evaluate_filter(ctx, "shape", "rectangle"))
  assert_true(!evaluate_filter(ctx, "shape", "circle"))
}

///|
test "apply_glob_properties" {
  let m = Map::new()
  m.add_field(Field::simple("server1"))
  m.add_field(Field::simple("server2"))
  m.add_field(Field::simple("client"))
  // Create properties map
  let props = Map::new()
  let fill_field = Field::simple("fill")
  fill_field.primary = Some(Scalar::string("red"))
  props.add_field(fill_field)
  // Apply to all matching server*
  m.apply_glob_properties(["server", "*"], props, [])
  // server1 and server2 should have fill property
  guard m.get_field("server1") is Some(s1) else { fail("expected server1") }
  guard s1.composite is Some(Composite::Map(s1m)) else {
    fail("expected server1 map")
  }
  guard s1m.get_field("fill") is Some(fill) else { fail("expected fill") }
  assert_eq(fill.primary, Some(Scalar::string("red")))
}

///|
test "apply_glob_properties with filter" {
  let m = Map::new()
  // Create server1 with shape: rectangle
  let server1 = Field::simple("server1")
  let s1map = Map::new()
  let shape1 = Field::simple("shape")
  shape1.primary = Some(Scalar::string("rectangle"))
  s1map.add_field(shape1)
  server1.composite = Some(Composite::Map(s1map))
  m.add_field(server1)
  // Create server2 with shape: circle
  let server2 = Field::simple("server2")
  let s2map = Map::new()
  let shape2 = Field::simple("shape")
  shape2.primary = Some(Scalar::string("circle"))
  s2map.add_field(shape2)
  server2.composite = Some(Composite::Map(s2map))
  m.add_field(server2)
  // Create properties
  let props = Map::new()
  let fill = Field::simple("fill")
  fill.primary = Some(Scalar::string("blue"))
  props.add_field(fill)
  // Apply with filter: only rectangles
  let filters : Array[(Bool, String, String)] = [(false, "shape", "rectangle")]
  m.apply_glob_properties(["**"], props, filters)
  // Only server1 should have fill=blue
  guard m.get_field("server1") is Some(s1) else { fail("expected server1") }
  guard s1.composite is Some(Composite::Map(s1m)) else {
    fail("expected server1 map")
  }
  guard s1m.get_field("fill") is Some(fill1) else {
    fail("expected fill in server1")
  }
  assert_eq(fill1.primary, Some(Scalar::string("blue")))
  // server2 should not have fill=blue (still has circle shape only)
  guard m.get_field("server2") is Some(s2) else { fail("expected server2") }
  guard s2.composite is Some(Composite::Map(s2m)) else {
    fail("expected server2 map")
  }
  // server2 should not have fill field
  assert_true(s2m.get_field("fill") is None)
}
