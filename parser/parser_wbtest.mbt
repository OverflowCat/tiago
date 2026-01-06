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
test "parse empty string" {
  let (ast, errors) = parse("")
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 0)
}

///|
test "parse simple key" {
  let (ast, errors) = parse("x")
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 1)
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.key is Some(kp) else { fail("expected key path") }
  assert_eq(kp.to_strings(), ["x"])
}

///|
test "parse key with value" {
  let (ast, errors) = parse("x: hello")
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 1)
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.key is Some(kp) else { fail("expected key path") }
  assert_eq(kp.to_strings(), ["x"])
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected string value")
  }
  assert_eq(sv.content(), "hello")
}

///|
test "parse nested key path" {
  let (ast, errors) = parse("container.child.item")
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 1)
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.key is Some(kp) else { fail("expected key path") }
  assert_eq(kp.to_strings(), ["container", "child", "item"])
}

///|
test "parse simple edge" {
  let (ast, errors) = parse("a -> b")
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 1)
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  assert_eq(key.edges.length(), 1)
  let edge = key.edges[0]
  assert_eq(edge.src.to_strings(), ["a"])
  assert_eq(edge.dst.to_strings(), ["b"])
  assert_eq(edge.src_arrow, "")
  assert_eq(edge.dst_arrow, ">")
}

///|
test "parse reverse edge" {
  let (ast, errors) = parse("a <- b")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  assert_eq(key.edges.length(), 1)
  let edge = key.edges[0]
  assert_eq(edge.src_arrow, "<")
  assert_eq(edge.dst_arrow, "")
}

///|
test "parse bidirectional edge" {
  let (ast, errors) = parse("a <-> b")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  assert_eq(key.edges.length(), 1)
  let edge = key.edges[0]
  assert_eq(edge.src_arrow, "<")
  assert_eq(edge.dst_arrow, ">")
}

///|
test "parse edge chain" {
  let (ast, errors) = parse("a -> b -> c")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  assert_eq(key.edges.length(), 2)
  assert_eq(key.edges[0].src.to_strings(), ["a"])
  assert_eq(key.edges[0].dst.to_strings(), ["b"])
  assert_eq(key.edges[1].src.to_strings(), ["b"])
  assert_eq(key.edges[1].dst.to_strings(), ["c"])
}

///|
test "parse edge with label" {
  let (ast, errors) = parse("a -> b: connection")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  assert_eq(key.edges.length(), 1)
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected string value")
  }
  assert_eq(sv.content(), "connection")
}

///|
test "parse block" {
  let (ast, errors) = parse("container { child }")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::Map(inner)) else {
    fail("expected Map value")
  }
  assert_eq(inner.nodes.length(), 1)
}

///|
test "parse number value" {
  let (ast, errors) = parse("x: 42")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::Number(_, n))) else {
    fail("expected number value")
  }
  assert_eq(n, "42")
}

///|
test "parse boolean true" {
  let (ast, errors) = parse("x: true")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::Boolean(_, b))) else {
    fail("expected boolean value")
  }
  assert_true(b)
}

///|
test "parse boolean false" {
  let (ast, errors) = parse("x: false")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::Boolean(_, b))) else {
    fail("expected boolean value")
  }
  assert_false(b)
}

///|
test "parse null value" {
  let (ast, errors) = parse("x: null")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::Null(_))) else {
    fail("expected null value")
  }
}

///|
test "parse single quoted string" {
  let (ast, errors) = parse("x: 'hello world'")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected string value")
  }
  assert_eq(sv.content(), "hello world")
}

///|
test "parse double quoted string" {
  let (ast, errors) = parse("x: \"hello world\"")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected string value")
  }
  assert_eq(sv.content(), "hello world")
}

///|
test "parse array" {
  let (ast, errors) = parse("x: [1, 2, 3]")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::Array(arr)) else {
    fail("expected array value")
  }
  assert_eq(arr.nodes.length(), 3)
}

///|
test "parse multiple keys" {
  let source =
    #|x: 1
    #|y: 2
    #|z: 3
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 3)
}

///|
test "parse comment" {
  let (ast, errors) = parse("# this is a comment")
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 0) // comments are skipped as trivia
}

///|
test "parse edge index" {
  let (ast, errors) = parse("(a -> b)[0]")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.edge_index is Some(idx) else { fail("expected edge index") }
  assert_eq(idx.index, Some(0))
  assert_false(idx.glob)
}

///|
test "parse edge index glob" {
  let (ast, errors) = parse("(a -> b)[*]")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.edge_index is Some(idx) else { fail("expected edge index") }
  assert_true(idx.glob)
}

///|
test "parse edge with property" {
  let (ast, errors) = parse("(a -> b).style.stroke: red")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.edge_key is Some(ek) else { fail("expected edge key") }
  assert_eq(ek.to_strings(), ["style", "stroke"])
}

///|
test "parse ampersand filter" {
  let (ast, errors) = parse("&x")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  assert_true(key.ampersand)
}
