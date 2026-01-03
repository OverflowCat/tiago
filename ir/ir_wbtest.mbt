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
  let source = "@common"
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
  let source = "@nonexistent"
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
