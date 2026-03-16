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
test "compile empty map" {
  let zero = @lexer.Position::zero()
  let ast = @ast.Map::new(@lexer.Range::new(zero, zero), [])
  let ir = compile(ast)
  assert_eq(ir.fields.length(), 0)
  assert_eq(ir.edges.length(), 0)
}

///|
test "compile simple key" {
  let (ast, _) = @parser.parse("x")
  let ir = compile(ast)
  assert_eq(ir.fields.length(), 1)
  assert_eq(ir.fields[0].name, "x")
}

///|
test "compile key with value" {
  let (ast, _) = @parser.parse("x: hello")
  let ir = compile(ast)
  assert_eq(ir.fields.length(), 1)
  assert_eq(ir.fields[0].name, "x")
  guard ir.fields[0].primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "hello")
}

///|
test "compile nested keys" {
  let (ast, _) = @parser.parse("a.b.c: value")
  let ir = compile(ast)
  assert_eq(ir.fields.length(), 1)
  assert_eq(ir.fields[0].name, "a")
  guard ir.fields[0].composite is Some(Composite::Map(m1)) else {
    fail("expected map")
  }
  assert_eq(m1.fields.length(), 1)
  assert_eq(m1.fields[0].name, "b")
  guard m1.fields[0].composite is Some(Composite::Map(m2)) else {
    fail("expected map")
  }
  assert_eq(m2.fields.length(), 1)
  assert_eq(m2.fields[0].name, "c")
  guard m2.fields[0].primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "value")
}

///|
test "field references retain AST context" {
  let (ast, _) = @parser.parse("a.b.c: value")
  let expected_key = match ast.nodes[0] {
    @ast.MapNode::Key(key) => key
    _ => fail("expected key node")
  }
  let ir = compile(ast)
  guard ir.get_field("a") is Some(a_field) else { fail("expected field a") }
  guard a_field.map() is Some(a_map) else { fail("expected map a") }
  guard a_map.get_field("b") is Some(b_field) else { fail("expected field b") }
  guard b_field.map() is Some(b_map) else { fail("expected map b") }
  guard b_map.get_field("c") is Some(c_field) else { fail("expected field c") }
  guard c_field.last_ref() is Some(Reference::FieldRef(last_ref)) else {
    fail("expected last field reference")
  }
  assert_eq(last_ref.string, "c")
  assert_true(last_ref.primary)
  guard last_ref.context() is Some(context) else {
    fail("expected reference context")
  }
  assert_eq(context.source_path, None)
  assert_eq(context.key, Some(expected_key))
  guard c_field.last_primary_key() is Some(primary_key) else {
    fail("expected primary key")
  }
  assert_eq(primary_key, expected_key)
  guard c_field.ast() is Some(@ast.Node::StringValue(syntax)) else {
    fail("expected string AST node")
  }
  assert_eq(syntax.content(), "c")
}

///|
test "compile edge" {
  let (ast, _) = @parser.parse("a -> b")
  let ir = compile(ast)
  assert_eq(ir.edges.length(), 1)
  assert_eq(ir.edges[0].id.src_path, ["a"])
  assert_eq(ir.edges[0].id.dst_path, ["b"])
  assert_false(ir.edges[0].id.src_arrow)
  assert_true(ir.edges[0].id.dst_arrow)
  // Source and destination fields should exist
  assert_true(ir.has_field("a"))
  assert_true(ir.has_field("b"))
}

///|
test "edge references retain context for glob expansions" {
  let source =
    #|a
    #|c
    #|* -> c
  let (ast, _) = @parser.parse(source)
  let expected_key = match ast.nodes[2] {
    @ast.MapNode::Key(key) => key
    _ => fail("expected edge key")
  }
  let ir = compile(ast)
  assert_eq(ir.edges.length(), 1)
  let edge = ir.edges[0]
  guard edge.last_ref() is Some(Reference::EdgeRef(reference)) else {
    fail("expected edge reference")
  }
  assert_true(reference.due_to_glob)
  guard reference.context() is Some(context) else {
    fail("expected edge context")
  }
  assert_eq(context.key, Some(expected_key))
  guard context.edge is Some(edge_ast) else { fail("expected edge ast") }
  assert_true(edge_ast.src.has_glob())
  guard edge.ast() is Some(@ast.Node::Edge(ast_edge)) else {
    fail("expected edge AST node")
  }
  assert_eq(ast_edge, edge_ast)
}

///|
test "compile edge with label" {
  let (ast, _) = @parser.parse("a -> b: connection")
  let ir = compile(ast)
  assert_eq(ir.edges.length(), 1)
  guard ir.edges[0].primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "connection")
}

///|
test "compile reverse edge" {
  let (ast, _) = @parser.parse("a <- b")
  let ir = compile(ast)
  assert_eq(ir.edges.length(), 1)
  assert_true(ir.edges[0].id.src_arrow)
  assert_false(ir.edges[0].id.dst_arrow)
}

///|
test "compile bidirectional edge" {
  let (ast, _) = @parser.parse("a <-> b")
  let ir = compile(ast)
  assert_eq(ir.edges.length(), 1)
  assert_true(ir.edges[0].id.src_arrow)
  assert_true(ir.edges[0].id.dst_arrow)
}

///|
test "compile block" {
  let source =
    #|container {
    #|  child
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  assert_eq(ir.fields.length(), 1)
  assert_eq(ir.fields[0].name, "container")
  guard ir.fields[0].composite is Some(Composite::Map(m)) else {
    fail("expected map")
  }
  assert_eq(m.fields.length(), 1)
  assert_eq(m.fields[0].name, "child")
}

///|
test "compile array" {
  let (ast, _) = @parser.parse("x: [1, 2, 3]")
  let ir = compile(ast)
  assert_eq(ir.fields.length(), 1)
  guard ir.fields[0].composite is Some(Composite::Array(arr)) else {
    fail("expected array")
  }
  assert_eq(arr.values.length(), 3)
}

///|
test "compile boolean values" {
  let (ast, _) = @parser.parse("x: true")
  let ir = compile(ast)
  guard ir.fields[0].primary is Some(p) else { fail("expected primary") }
  assert_true(p.is_bool())
  assert_eq(p.as_bool(), Some(true))
}

///|
test "compile null value" {
  let (ast, _) = @parser.parse("x: null")
  let ir = compile(ast)
  guard ir.fields[0].primary is Some(p) else { fail("expected primary") }
  assert_true(p.is_null())
}

///|
test "compile number value" {
  let (ast, _) = @parser.parse("x: 42")
  let ir = compile(ast)
  guard ir.fields[0].primary is Some(p) else { fail("expected primary") }
  assert_true(p.is_number())
  assert_eq(p.to_string(), "42")
}

///|
test "map operations" {
  let m = Map::new()
  m.add_field(Field::simple("a"))
  m.add_field(Field::simple("b"))
  assert_eq(m.fields.length(), 2)
  assert_true(m.has_field("a"))
  assert_true(m.has_field("A")) // case-insensitive
  assert_false(m.has_field("c"))
  // Get field
  guard m.get_field("a") is Some(f) else { fail("expected field") }
  assert_eq(f.name, "a")
  // Ensure field (existing)
  let f2 = m.ensure_field("a")
  assert_eq(f2.name, "a")
  assert_eq(m.fields.length(), 2) // No new field
  // Ensure field (new)
  let f3 = m.ensure_field("c")
  assert_eq(f3.name, "c")
  assert_eq(m.fields.length(), 3) // New field added
  // Delete field
  let deleted = m.delete_field("b")
  assert_true(deleted is Some(_))
  assert_eq(m.fields.length(), 2)
  assert_false(m.has_field("b"))
}

///|
test "edge id matching" {
  let id1 = EdgeID::new(["a"], ["b"], false, true)
  let id2 = EdgeID::new(["a"], ["b"], false, true)
  let id3 = EdgeID::new(["a"], ["c"], false, true)
  let id4 = EdgeID::new(["A"], ["B"], false, true) // case-insensitive
  assert_true(id1.matches(id2))
  assert_false(id1.matches(id3))
  assert_true(id1.matches(id4))
}

///|
test "edge id with index" {
  let id1 = EdgeID::with_index(["a"], ["b"], false, true, 0)
  let id2 = EdgeID::with_index(["a"], ["b"], false, true, 0)
  let id3 = EdgeID::with_index(["a"], ["b"], false, true, 1)
  assert_true(id1.matches(id2))
  assert_false(id1.matches(id3))
}

///|
test "scalar operations" {
  let s1 = Scalar::null()
  assert_true(s1.is_null())
  assert_false(s1.is_bool())
  assert_eq(s1.to_string(), "null")
  let s2 = Scalar::bool(true)
  assert_true(s2.is_bool())
  assert_eq(s2.as_bool(), Some(true))
  assert_eq(s2.to_string(), "true")
  let s3 = Scalar::number("3.14")
  assert_true(s3.is_number())
  assert_eq(s3.to_string(), "3.14")
  let s4 = Scalar::string("hello")
  assert_true(s4.is_string())
  assert_eq(s4.to_string(), "hello")
}

///|
test "field operations" {
  let f = Field::simple("test")
  assert_eq(f.name, "test")
  assert_false(f.has_primary())
  assert_false(f.has_composite())
  assert_true(f.map() is None)
  assert_true(f.array() is None)
}

///|
test "value operations" {
  let v1 : Value = Value::Scalar(Scalar::string("test"))
  assert_true(v1.as_scalar() is Some(_))
  assert_true(v1.as_map() is None)
  assert_true(v1.as_array() is None)
  let v2 : Value = Value::Map(Map::new())
  assert_true(v2.as_map() is Some(_))
  let v3 : Value = Value::Array(IRArray::new([]))
  assert_true(v3.as_array() is Some(_))
}

///|
test "glob style.fill applies to all fields" {
  let source =
    #|a
    #|b
    #|*.style.fill: red
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  // Both a and b should have style.fill: red
  for field_name in ["a", "b"] {
    guard ir.get_field(field_name) is Some(field) else {
      fail("no field \{field_name}")
    }
    guard field.composite is Some(Composite::Map(m)) else {
      fail("field \{field_name} has no map")
    }
    guard m.get_field("style") is Some(style_field) else {
      fail("field \{field_name} has no style")
    }
    guard style_field.composite is Some(Composite::Map(style_map)) else {
      fail("field \{field_name} style has no map")
    }
    guard style_map.get_field("fill") is Some(fill_field) else {
      fail("field \{field_name} style has no fill")
    }
    guard fill_field.primary is Some(p) else {
      fail("field \{field_name} fill has no value")
    }
    assert_eq(p.to_string(), "red")
  }
}

///|
test "glob-created properties keep due_to_glob references" {
  let source =
    #|a
    #|*.style.fill: red
  let (ast, _) = @parser.parse(source)
  let expected_key = match ast.nodes[1] {
    @ast.MapNode::Key(key) => key
    _ => fail("expected glob key")
  }
  let ir = compile(ast)
  guard ir.get_field("a") is Some(a_field) else { fail("expected field a") }
  guard a_field.map() is Some(a_map) else { fail("expected field map") }
  guard a_map.get_field("style") is Some(style_field) else {
    fail("expected style field")
  }
  guard style_field.map() is Some(style_map) else { fail("expected style map") }
  guard style_map.get_field("fill") is Some(fill_field) else {
    fail("expected fill field")
  }
  guard fill_field.last_ref() is Some(Reference::FieldRef(reference)) else {
    fail("expected fill reference")
  }
  assert_true(reference.due_to_glob)
  assert_eq(reference.string, "fill")
  guard reference.context() is Some(context) else {
    fail("expected glob context")
  }
  assert_eq(context.key, Some(expected_key))
}

///|
test "double glob applies to nested fields" {
  let source =
    #|container {
    #|  child1
    #|  child2
    #|}
    #|**.style.opacity: 0.5
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  // container, child1, and child2 should all have style.opacity: 0.5
  guard ir.get_field("container") is Some(container) else {
    fail("no container")
  }
  guard container.composite is Some(Composite::Map(container_map)) else {
    fail("container has no map")
  }
  // Check child1 has opacity
  guard container_map.get_field("child1") is Some(child1) else {
    fail("no child1")
  }
  guard child1.composite is Some(Composite::Map(child1_map)) else {
    fail("child1 has no map")
  }
  guard child1_map.get_field("style") is Some(style) else {
    fail("child1 has no style")
  }
  guard style.composite is Some(Composite::Map(style_map)) else {
    fail("child1 style has no map")
  }
  guard style_map.get_field("opacity") is Some(opacity) else {
    fail("child1 has no opacity")
  }
  guard opacity.primary is Some(p) else { fail("opacity has no value") }
  assert_eq(p.to_string(), "0.5")
}

///|
test "compile with imports - basic" {
  let source = "common: @common"
  let (ast, _) = @parser.parse(source)
  // Create a resolver that returns content for "common.d2"
  let resolver = ImportResolver::new(fn(path) {
    if path == "common" || path == "common.d2" {
      Some("server\ndatabase")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  // Should have a "common" field with "server" and "database" inside
  guard ir.get_field("common") is Some(common) else { fail("no common field") }
  guard common.composite is Some(Composite::Map(common_map)) else {
    fail("common has no map")
  }
  assert_true(common_map.has_field("server"))
  assert_true(common_map.has_field("database"))
}

///|
test "compile with imports tracks source path in references" {
  let resolver = ImportResolver::new(fn(path) {
    match path {
      "inner.d2" => Some("service.api: ok")
      _ => None
    }
  })
  let (ast, _) = @parser.parse("common: @inner")
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("common") is Some(inner_field) else {
    fail("expected imported field")
  }
  guard inner_field.map() is Some(inner_map) else {
    fail("expected imported map")
  }
  guard inner_map.get_field("service") is Some(service_field) else {
    fail("expected service field")
  }
  guard service_field.map() is Some(service_map) else {
    fail("expected service map")
  }
  guard service_map.get_field("api") is Some(api_field) else {
    fail("expected api field")
  }
  guard api_field.last_ref() is Some(Reference::FieldRef(reference)) else {
    fail("expected imported reference")
  }
  guard reference.context() is Some(context) else {
    fail("expected imported context")
  }
  assert_eq(context.source_path, Some("inner.d2"))
}

///|
test "compile with imports - spread" {
  let source = "...@common"
  let (ast, _) = @parser.parse(source)
  // Create a resolver that returns content for "common.d2"
  let resolver = ImportResolver::new(fn(path) {
    if path == "common" || path == "common.d2" {
      Some("server\ndatabase")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  // Should have "server" and "database" directly at the root level
  assert_true(ir.has_field("server"))
  assert_true(ir.has_field("database"))
}

///|
test "compile with imports - missing import" {
  let source = "missing: @nonexistent"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(_) { None })
  // Should raise an error
  let result : Result[Map, CompileError] = Ok(
    compile_with_imports(ast, resolver),
  ) catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

///|
test "compile with imports - selection (nested scalar)" {
  let source = "x: @a.y"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "a" || path == "a.d2" {
      Some("y: meow")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "meow")
}

///|
test "compile with imports - selection (nested array)" {
  let source = "x: @a.y"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "a" || path == "a.d2" {
      Some("y: [1, 2]")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.composite is Some(Composite::Array(arr)) else {
    fail("expected array")
  }
  assert_eq(arr.values.length(), 2)
  guard arr.values[0] is Value::Scalar(s0) else { fail("expected scalar") }
  guard arr.values[1] is Value::Scalar(s1) else { fail("expected scalar") }
  assert_eq(s0.to_string(), "1")
  assert_eq(s1.to_string(), "2")
}

///|
test "compile with imports - spread selection non-map errors" {
  let source = "...@a.y"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "a" || path == "a.d2" {
      Some("y: meow")
    } else {
      None
    }
  })
  let result : Result[Map, CompileError] = Ok(
    compile_with_imports(ast, resolver),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(ImportError(msg)) =>
      assert_eq(msg, "cannot spread import non map into map")
    _ => fail("expected ImportError")
  }
}

///|
test "compile with imports - spread array into array" {
  let source = "x: [...@a.y, 3]"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "a" || path == "a.d2" {
      Some("y: [1, 2]")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.composite is Some(Composite::Array(arr)) else {
    fail("expected array")
  }
  assert_eq(arr.values.length(), 3)
  guard arr.values[0] is Value::Scalar(s0) else { fail("expected scalar") }
  guard arr.values[1] is Value::Scalar(s1) else { fail("expected scalar") }
  guard arr.values[2] is Value::Scalar(s2) else { fail("expected scalar") }
  assert_eq(s0.to_string(), "1")
  assert_eq(s1.to_string(), "2")
  assert_eq(s2.to_string(), "3")
}

///|
test "compile with imports - cyclic import errors" {
  let source = "...@a"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "a" || path == "a.d2" {
      Some("...@b")
    } else if path == "b" || path == "b.d2" {
      Some("...@a")
    } else {
      None
    }
  })
  let result : Result[Map, CompileError] = Ok(
    compile_with_imports(ast, resolver),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(ImportError(_)) => ()
    _ => fail("expected ImportError")
  }
}

///|
test "compile with imports - pre path normalization" {
  let source = "...@./../.././common"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "../../common" || path == "../../common.d2" {
      Some("server")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  assert_true(ir.has_field("server"))
}

///|
test "compile - imports require resolver" {
  let cases = ["common: @common", "...@common", "x: @common", "x: [@common]"]
  for src in cases {
    let (ast, _) = @parser.parse(src)
    let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
      e => Err(e)
    }
    match result {
      Err(ImportError(_)) => ()
      _ => fail("expected ImportError for: \{src}")
    }
  }
}

///|
test "compile vars - spread-in-place (d2 parity)" {
  let source =
    #|vars: {
    #|  person-shape: {
    #|    grid-columns: 1
    #|    grid-rows: 2
    #|    grid-gap: 0
    #|    head
    #|    body
    #|  }
    #|}
    #|
    #|dora: {
    #|  ...${person-shape}
    #|  body
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("dora") is Some(dora) else { fail("expected dora") }
  guard dora.composite is Some(Composite::Map(dm)) else {
    fail("expected dora map")
  }
  guard dm.fields.length() > 0 else { fail("expected fields") }
  assert_eq(dm.fields[0].name, "grid-columns")
}

///|
test "compile vars - spread array (d2 parity)" {
  let source =
    #|vars: {
    #|  xs: [1, 2]
    #|}
    #|
    #|a: [...${xs}, 3]
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("a") is Some(a) else { fail("expected a") }
  guard a.composite is Some(Composite::Array(arr)) else {
    fail("expected array")
  }
  assert_eq(arr.values.length(), 3)
  guard arr.values[0] is Value::Scalar(s0) else { fail("expected scalar") }
  guard arr.values[1] is Value::Scalar(s1) else { fail("expected scalar") }
  guard arr.values[2] is Value::Scalar(s2) else { fail("expected scalar") }
  assert_eq(s0.to_string(), "1")
  assert_eq(s1.to_string(), "2")
  assert_eq(s2.to_string(), "3")
}

///|
test "compile vars - unresolved substitution errors (d2 parity)" {
  let source = "x: ${missing}"
  let (ast, _) = @parser.parse(source)
  let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidSubstitution(msg)) =>
      assert_eq(msg, "could not resolve variable \"missing\"")
    _ => fail("expected InvalidSubstitution")
  }
}

///|
test "compile vars - self scope vars doesn't resolve to itself (d2 parity)" {
  let source =
    #|vars: {
    #|  x: a
    #|}
    #|hi: {
    #|  vars: {
    #|    x: ${x}-b
    #|  }
    #|  yo: ${x}
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("hi") is Some(hi) else { fail("expected hi") }
  guard hi.composite is Some(Composite::Map(hm)) else {
    fail("expected hi map")
  }
  guard hm.get_field("vars") is Some(vars) else { fail("expected vars") }
  guard vars.composite is Some(Composite::Map(vm)) else {
    fail("expected vars map")
  }
  guard vm.get_field("x") is Some(x) else { fail("expected x") }
  guard x.primary is Some(px) else { fail("expected x primary") }
  assert_eq(px.to_string(), "a-b")
  guard hm.get_field("yo") is Some(yo) else { fail("expected yo") }
  guard yo.primary is Some(pyo) else { fail("expected yo primary") }
  assert_eq(pyo.to_string(), "a-b")
}

///|
test "compile vars - spread non-composite errors (d2 parity)" {
  let source =
    #|vars: { x: 1 }
    #|a: { ...${x} }
  let (ast, _) = @parser.parse(source)
  let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidSubstitution(msg)) =>
      assert_eq(msg, "cannot spread non-composite")
    _ => fail("expected InvalidSubstitution")
  }
}

///|
test "compile vars - spread non-array into array errors (d2 parity)" {
  let source =
    #|vars: { x: { a } }
    #|a: [...${x}]
  let (ast, _) = @parser.parse(source)
  let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidSubstitution(msg)) =>
      assert_eq(msg, "cannot spread non-array into array")
    _ => fail("expected InvalidSubstitution")
  }
}
