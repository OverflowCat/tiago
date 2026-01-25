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
  let source =
    #|vars: { color: red }
    #|server: { fill: ${color} }
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("server") is Some(s) else { fail("expected server") }
  guard s.composite is Some(Composite::Map(sm)) else { fail("expected map") }
  guard sm.get_field("fill") is Some(f) else { fail("expected fill") }
  guard f.primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "red")
}

///|
test "resolve nested variable" {
  let source =
    #|vars: { colors: { primary: blue } }
    #|box: { fill: ${colors.primary} }
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("box") is Some(b) else { fail("expected box") }
  guard b.composite is Some(Composite::Map(bm)) else { fail("expected map") }
  guard bm.get_field("fill") is Some(f) else { fail("expected fill") }
  guard f.primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "blue")
}

///|
test "resolve simple dollar variable" {
  let source =
    #|vars: { name: Server }
    #|node: $name
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("node") is Some(n) else { fail("expected node") }
  guard n.primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "Server")
}

///|
test "unresolved variable errors" {
  let (ast, _) = @parser.parse("node: ${unknown}")
  let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

///|
test "deeply nested variable substitution (3+ levels)" {
  let source =
    #|vars: { a: { b: { c: deep } } }
    #|x: ${a.b.c}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "deep")
}

///|
test "variable shadowing in nested scopes" {
  let source =
    #|vars: { x: outer }
    #|container: {
    #|  vars: { x: inner }
    #|  label: ${x}
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("container") is Some(c) else { fail("expected container") }
  guard c.composite is Some(Composite::Map(cm)) else { fail("expected map") }
  guard cm.get_field("label") is Some(lbl) else { fail("expected label") }
  guard lbl.primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "inner")
}

///|
test "outer variable accessible when not shadowed" {
  let source =
    #|vars: { y: outer }
    #|container: {
    #|  vars: { x: inner }
    #|  label: ${y}
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("container") is Some(c) else { fail("expected container") }
  guard c.composite is Some(Composite::Map(cm)) else { fail("expected map") }
  guard cm.get_field("label") is Some(lbl) else { fail("expected label") }
  guard lbl.primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "outer")
}

///|
test "edge label substitution" {
  let source =
    #|vars: { msg: hello }
    #|a -> b: ${msg}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  assert_eq(ir.edges.length(), 1)
  guard ir.edges[0].primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "hello")
}

///|
test "unquoted interpolation - embedded ${} substitution" {
  let source =
    #|vars: { x: hi }
    #|label: pre-${x}-post
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("label") is Some(lbl) else { fail("expected label") }
  guard lbl.primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "pre-hi-post")
}

///|
test "unquoted interpolation - embedded $var substitution" {
  let source =
    #|vars: { x: hi }
    #|label: pre-$x post
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("label") is Some(lbl) else { fail("expected label") }
  guard lbl.primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "pre-hi post")
}

///|
test "double quoted substitution" {
  let source =
    #|vars: { x: hi }
    #|label: "${x}"
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("label") is Some(lbl) else { fail("expected label") }
  guard lbl.primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "hi")
}

///|
test "double quoted substitution - composite errors" {
  let source =
    #|vars: { m: { a } }
    #|label: "${m}"
  let (ast, _) = @parser.parse(source)
  let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidSubstitution(msg)) =>
      assert_eq(msg, "cannot substitute map variable \"m\" in quotes")
    _ => fail("expected InvalidSubstitution")
  }
}

///|
test "double quoted substitution in edge label" {
  let source =
    #|vars: { x: hi }
    #|a -> b: "${x}"
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  assert_eq(ir.edges.length(), 1)
  guard ir.edges[0].primary is Some(p) else { fail("expected primary") }
  assert_eq(p.to_string(), "hi")
}

///|
test "double quoted substitution in edge label - composite errors" {
  let source =
    #|vars: { m: { a } }
    #|a -> b: "${m}"
  let (ast, _) = @parser.parse(source)
  let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidSubstitution(msg)) =>
      assert_eq(msg, "cannot substitute map variable \"m\" in quotes")
    _ => fail("expected InvalidSubstitution")
  }
}

///|
test "double quoted substitution in array element" {
  let source =
    #|vars: { x: hi }
    #|arr: ["${x}"]
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("arr") is Some(arr) else { fail("expected arr") }
  guard arr.array() is Some(a) else { fail("expected array") }
  assert_eq(a.values.length(), 1)
  guard a.values[0] is Value::Scalar(s) else { fail("expected scalar") }
  assert_eq(s.to_string(), "hi")
}
