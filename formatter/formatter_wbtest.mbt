///|
fn r(line : Int) -> @lexer.Range {
  let p = @lexer.Position::new(line, 0, line)
  @lexer.Range::new(p, p)
}

///|
fn r2(start_line : Int, end_line : Int) -> @lexer.Range {
  let start = @lexer.Position::new(start_line, 0, start_line)
  let end = @lexer.Position::new(end_line, 0, end_line)
  @lexer.Range::new(start, end)
}

///|
fn uq(text : String, line : Int) -> @ast.StringValue {
  let range = r(line)
  @ast.StringValue::Unquoted(
    @ast.UnquotedString::new(range, [@ast.Interpolation::Text(text)], []),
  )
}

///|
fn kp(text : String, line : Int) -> @ast.KeyPath {
  @ast.KeyPath::new(r(line), [uq(text, line)])
}

///|
fn key_with_value(name : String, value : @ast.Value, line : Int) -> @ast.Key {
  @ast.Key::new(
    r(line),
    false,
    false,
    Some(kp(name, line)),
    [],
    None,
    None,
    None,
    Some(value),
  )
}

///|
test "format file map has trailing newline" {
  let map = @ast.Map::new(r(0), [
    @ast.MapNode::Key(
      key_with_value("x", @ast.Value::Scalar(@ast.Scalar::Number(r(0), "1")), 0),
    ),
  ])
  let out = format(map, FormatConfig::new())
  assert_eq(out, "x: 1\n")
}

///|
test "format block comment uses triple quotes" {
  let map = @ast.Map::new(r2(0, 1), [
    @ast.MapNode::BlockComment(r(0), "hi"),
    @ast.MapNode::Key(
      @ast.Key::new(
        r(1),
        false,
        false,
        Some(kp("x", 1)),
        [],
        None,
        None,
        None,
        None,
      ),
    ),
  ])
  let out = format(map, FormatConfig::new())
  assert_eq(out, "\"\"\" hi \"\"\"\nx\n")
}

///|
test "format edge key follows d2 parenthesized style" {
  let edge = @ast.Edge::new(r(0), kp("a", 0), kp("b", 0), "", ">")
  let edge_index = @ast.EdgeIndex::new(r(0), Some(0), false)
  let edge_key = @ast.KeyPath::new(r(0), [uq("style", 0), uq("stroke", 0)])
  let key = @ast.Key::new(
    r(0),
    false,
    false,
    None,
    [edge],
    Some(edge_index),
    Some(edge_key),
    None,
    Some(
      @ast.Value::Scalar(
        @ast.Scalar::String(
          @ast.StringValue::Unquoted(
            @ast.UnquotedString::new(r(0), [@ast.Interpolation::Text("red")], []),
          ),
        ),
      ),
    ),
  )
  let map = @ast.Map::new(r(0), [@ast.MapNode::Key(key)])
  let out = format(map, FormatConfig::new())
  assert_eq(out, "(a -> b)[0].style.stroke: red\n")
}

///|
test "format unquoted null is escaped like d2" {
  let key = key_with_value(
    "x",
    @ast.Value::Scalar(
      @ast.Scalar::String(
        @ast.StringValue::Unquoted(
          @ast.UnquotedString::new(r(0), [@ast.Interpolation::Text("null")], []),
        ),
      ),
    ),
    0,
  )
  let map = @ast.Map::new(r(0), [@ast.MapNode::Key(key)])
  let out = format(map, FormatConfig::new())
  assert_eq(out, "x: 'null'\n")
}
