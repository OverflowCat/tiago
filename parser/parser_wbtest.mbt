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
test "parse block string |md" {
  let source =
    #|x: |md
    #|  hello
    #||
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else { fail("expected Key") }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected string scalar")
  }
  guard sv is @ast.StringValue::Block(bs) else { fail("expected block") }
  assert_eq(bs.quote, "")
  assert_eq(bs.tag, "md")
  assert_eq(bs.value, "hello")
}

///|
test "parse block string defaults tag to md" {
  let source =
    #|x: |
    #|  hello
    #||
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else { fail("expected Key") }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected string scalar")
  }
  guard sv is @ast.StringValue::Block(bs) else { fail("expected block") }
  assert_eq(bs.quote, "")
  assert_eq(bs.tag, "md")
  assert_eq(bs.value, "hello")
}

///|
test "parse block string with quote (||md ... ||)" {
  let source =
    #|x: ||md
    #|  a | b
    #|||
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else { fail("expected Key") }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected string scalar")
  }
  guard sv is @ast.StringValue::Block(bs) else { fail("expected block") }
  assert_eq(bs.quote, "|")
  assert_eq(bs.tag, "md")
  assert_eq(bs.value, "a | b")
}

///|
test "parse triple-quote block comment" {
  let source =
    #|""" hi """
    #|x
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 2)
  guard ast.nodes[0] is @ast.MapNode::BlockComment(_, text) else {
    fail("expected block comment node")
  }
  assert_eq(text, "hi")
  guard ast.nodes[1] is @ast.MapNode::Key(key) else {
    fail("expected key node")
  }
  guard key.key is Some(kp) else { fail("expected key path") }
  assert_eq(kp.to_strings(), ["x"])
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
  assert_eq(ast.nodes.length(), 1)
  guard ast.nodes[0] is @ast.MapNode::Comment(_, text) else {
    fail("expected comment node")
  }
  assert_eq(text, "this is a comment")
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
test "parse spread import with pre path" {
  let (ast, errors) = parse("...@../file")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Import(imp) else {
    fail("expected import node")
  }
  assert_true(imp.spread)
  assert_eq(imp.pre, "../")
  assert_eq(imp.path.length(), 1)
  assert_eq(imp.path[0].content(), "file")
}

///|
test "parse import strips d2 extension for unquoted path" {
  let (ast, errors) = parse("x: @file.d2")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else { fail("expected key") }
  guard key.value is Some(@ast.Value::Import(imp)) else {
    fail("expected import value")
  }
  assert_eq(imp.pre, "")
  assert_eq(imp.path.length(), 1)
  assert_eq(imp.path[0].content(), "file")
}

///|
test "parse import keeps quoted d2 segment" {
  let (ast, errors) = parse("...@\"file\".d2")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Import(imp) else {
    fail("expected import")
  }
  assert_eq(imp.path.length(), 2)
  assert_eq(imp.path[0].content(), "file")
  assert_eq(imp.path[1].content(), "d2")
}

///|
test "parse edge line continuation with escaped newline" {
  let source =
    #|super long shape id here --\
    #|  -> super long shape id even longer here
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  assert_eq(key.edges.length(), 1)
  let edge = key.edges[0]
  assert_eq(edge.src.to_strings(), ["super long shape id here"])
  assert_eq(edge.dst.to_strings(), ["super long shape id even longer here"])
  assert_eq(edge.src_arrow, "")
  assert_eq(edge.dst_arrow, ">")
}

///|
test "parse less-than-edge compatibility (#955)" {
  let (ast, errors) = parse("x <= y")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected key node")
  }
  assert_eq(key.edges.length(), 1)
  let edge = key.edges[0]
  assert_eq(edge.src.to_strings(), ["x"])
  assert_eq(edge.src_arrow, "<")
  assert_eq(edge.dst_arrow, "")
  assert_eq(edge.dst.to_strings(), ["= y"])
}

///|
test "parse unquoted value rejects ...@ prefix" {
  let (_, errors) = parse("meow: ...@file")
  assert_true(!errors.is_empty())
  assert_true(
    errors
    .to_string()
    .contains(
      "unquoted strings cannot begin with ...@ as that's import spread syntax",
    ),
  )
}

///|
test "parse key length limit" {
  let long_key = "a".repeat(519)
  let (_, errors) = parse(long_key + ": 1")
  assert_true(!errors.is_empty())
  assert_true(
    errors.to_string().contains("exceeds maximum allowed length of 518"),
  )
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

///|
test "parse not ampersand filter" {
  let (ast, errors) = parse("!&x")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  assert_true(key.not_ampersand)
}

///|
test "parse key with spaces and apostrophe" {
  let (ast, errors) = parse("i'm a shape")
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 1)
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.key is Some(kp) else { fail("expected key path") }
  assert_eq(kp.to_strings(), ["i'm a shape"])
}

///|
test "parse scalar with comma punctuation" {
  let (ast, errors) = parse("x: To err is human, to moo bovine!")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected string value")
  }
  assert_eq(sv.content(), "To err is human, to moo bovine!")
}

///|
test "parse star block scalar value" {
  let source =
    #|x: * {
    #|  shape: diamond
    #|}
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::BlockScalar(label, props)) else {
    fail("expected block scalar")
  }
  guard label is @ast.Value::Scalar(@ast.Scalar::String(sv)) else {
    fail("expected scalar label")
  }
  assert_eq(sv.content(), "*")
  assert_eq(props.nodes.length(), 1)
}

///|
test "parse scalar starting with left parenthesis" {
  let (ast, errors) = parse("x: (s string, eof bool)")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected string value")
  }
  assert_eq(sv.content(), "(s string, eof bool)")
}

///|
test "parse key with trailing dot without error" {
  let (ast, errors) = parse("golf as if they were games.")
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected Key node")
  }
  guard key.key is Some(kp) else { fail("expected key path") }
  assert_eq(kp.to_strings(), ["golf as if they were games"])
}

///|
test "parse edge line continuation compact arrow form" {
  let source =
    #|super long shape id here --\
    #|> super long shape id even longer here
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected key node")
  }
  assert_eq(key.edges.length(), 1)
  let edge = key.edges[0]
  assert_eq(edge.src.to_strings(), ["super long shape id here"])
  assert_eq(edge.dst.to_strings(), ["super long shape id even longer here"])
  assert_eq(edge.src_arrow, "")
  assert_eq(edge.dst_arrow, ">")
}

///|
test "parse field line continuation with escaped newline" {
  let source =
    #|meow \
    #|  ok \
    #|    super: yes \
    #|    wow so cool
    #|  \
    #|xd \
    #|\
    #|  ok does it work: hopefully
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 2)
  guard ast.nodes[0] is @ast.MapNode::Key(first) else {
    fail("expected first key node")
  }
  guard first.key is Some(first_key) else { fail("expected first key path") }
  assert_eq(first_key.to_strings(), ["meow ok super"])
  guard first.value
    is Some(@ast.Value::Scalar(@ast.Scalar::String(first_value))) else {
    fail("expected first scalar value")
  }
  assert_eq(first_value.content(), "yes wow so cool")
  guard ast.nodes[1] is @ast.MapNode::Key(second) else {
    fail("expected second key node")
  }
  guard second.key is Some(second_key) else { fail("expected second key path") }
  assert_eq(second_key.to_strings(), ["xd ok does it work"])
  guard second.value
    is Some(@ast.Value::Scalar(@ast.Scalar::String(second_value))) else {
    fail("expected second scalar value")
  }
  assert_eq(second_value.content(), "hopefully")
}

///|
test "parse one-line block string" {
  let source =
    #|a: |   hello  |
    #|"""   hello  """
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 2)
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected key node")
  }
  guard key.key is Some(kp) else { fail("expected key path") }
  assert_eq(kp.to_strings(), ["a"])
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected block string scalar")
  }
  guard sv is @ast.StringValue::Block(bs) else { fail("expected block string") }
  assert_eq(bs.quote, "")
  assert_eq(bs.tag, "md")
  assert_eq(bs.value, "hello")
  guard ast.nodes[1] is @ast.MapNode::BlockComment(_, text) else {
    fail("expected trailing block comment")
  }
  assert_eq(text, "hello")
}

///|
test "parse block string with embedded delimiters" {
  let source =
    #|a: ||
    #|  |pipe|
    #|||
    #|
    #|"""
    #|b: ""
    #|"""
  let (ast, errors) = parse(source)
  assert_true(errors.is_empty())
  assert_eq(ast.nodes.length(), 2)
  guard ast.nodes[0] is @ast.MapNode::Key(key) else {
    fail("expected key node")
  }
  guard key.value is Some(@ast.Value::Scalar(@ast.Scalar::String(sv))) else {
    fail("expected scalar value")
  }
  guard sv is @ast.StringValue::Block(bs) else { fail("expected block string") }
  assert_eq(bs.quote, "|")
  assert_eq(bs.value, "|pipe|")
  guard ast.nodes[1] is @ast.MapNode::BlockComment(_, text) else {
    fail("expected trailing block comment")
  }
  assert_eq(text, "\nb: \"\"")
}

///|
test "parse missing map value after colon" {
  let (_, errors) = parse("x:")
  assert_true(!errors.is_empty())
  assert_true(errors.to_string().contains("missing value after colon"))
}

///|
test "parse plain @ import form reports suggestion error" {
  let (_, errors) = parse("@file")
  assert_true(!errors.is_empty())
  assert_true(
    errors
    .to_string()
    .contains("@file is not a valid import, did you mean ...@file?"),
  )
}
