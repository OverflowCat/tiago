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
test "tokenize empty string" {
  let (tokens, errors) = tokenize("")
  assert_eq(tokens.length(), 1) // Just EOF
  assert_eq(errors.length(), 0)
  assert_true(tokens[0].kind == Eof)
}

///|
test "tokenize simple identifier" {
  let (tokens, _) = tokenize("server")
  assert_eq(tokens.length(), 2) // Ident + EOF
  assert_eq(tokens[0].kind, Ident("server"))
  assert_eq(tokens[0].raw, "server")
}

///|
test "tokenize arrow" {
  let (tokens, _) = tokenize("a -> b")
  assert_eq(tokens.length(), 4) // a, ->, b, EOF
  assert_eq(tokens[0].kind, Ident("a"))
  assert_eq(tokens[1].kind, Arrow)
  assert_eq(tokens[2].kind, Ident("b"))
  assert_eq(tokens[3].kind, Eof)
}

///|
test "tokenize reverse arrow" {
  let (tokens, _) = tokenize("a <- b")
  assert_eq(tokens.length(), 4)
  assert_eq(tokens[1].kind, ReverseArrow)
}

///|
test "tokenize bidirectional arrow" {
  let (tokens, _) = tokenize("a <-> b")
  assert_eq(tokens.length(), 4)
  assert_eq(tokens[1].kind, BidirectionalArrow)
}

///|
test "tokenize double dash" {
  let (tokens, _) = tokenize("a -- b")
  assert_eq(tokens.length(), 4)
  assert_eq(tokens[1].kind, DoubleDash)
}

///|
test "tokenize colon and value" {
  let (tokens, _) = tokenize("server: Web Server")
  assert_eq(tokens.length(), 5) // server, :, Web, Server, EOF
  assert_eq(tokens[0].kind, Ident("server"))
  assert_eq(tokens[1].kind, Colon)
  assert_eq(tokens[2].kind, Ident("Web"))
  assert_eq(tokens[3].kind, Ident("Server"))
}

///|
test "tokenize braces" {
  let (tokens, _) = tokenize("aws { server }")
  assert_eq(tokens.length(), 5) // aws, {, server, }, EOF
  assert_eq(tokens[0].kind, Ident("aws"))
  assert_eq(tokens[1].kind, LeftBrace)
  assert_eq(tokens[2].kind, Ident("server"))
  assert_eq(tokens[3].kind, RightBrace)
}

///|
test "tokenize brackets" {
  let (tokens, _) = tokenize("[a, b]")
  assert_eq(tokens.length(), 6) // [, a, ,, b, ], EOF
  assert_eq(tokens[0].kind, LeftBracket)
  assert_eq(tokens[1].kind, Ident("a"))
  assert_eq(tokens[2].kind, Comma)
  assert_eq(tokens[3].kind, Ident("b"))
  assert_eq(tokens[4].kind, RightBracket)
}

///|
test "tokenize dot path" {
  let (tokens, _) = tokenize("container.child.label")
  assert_eq(tokens.length(), 6) // container, ., child, ., label, EOF
  assert_eq(tokens[0].kind, Ident("container"))
  assert_eq(tokens[1].kind, Dot)
  assert_eq(tokens[2].kind, Ident("child"))
  assert_eq(tokens[3].kind, Dot)
  assert_eq(tokens[4].kind, Ident("label"))
}

///|
test "tokenize line comment" {
  let (tokens, _) = tokenize("server # this is a comment")
  assert_eq(tokens.length(), 3) // server, comment, EOF
  assert_eq(tokens[0].kind, Ident("server"))
  assert_eq(tokens[1].kind, Comment(" this is a comment"))
}

///|
test "tokenize block comment" {
  let (tokens, _) = tokenize("/* block comment */ server")
  assert_eq(tokens.length(), 3) // comment, server, EOF
  assert_eq(tokens[0].kind, BlockComment(" block comment "))
  assert_eq(tokens[1].kind, Ident("server"))
}

///|
test "tokenize nested block comment" {
  let (tokens, _) = tokenize("/* outer /* inner */ outer */ x")
  assert_eq(tokens.length(), 3)
  assert_eq(tokens[0].kind, BlockComment(" outer /* inner */ outer "))
  assert_eq(tokens[1].kind, Ident("x"))
}

///|
test "tokenize single quoted string" {
  let (tokens, _) = tokenize("'hello world'")
  assert_eq(tokens.length(), 2) // string, EOF
  assert_eq(tokens[0].kind, StringLit(SingleQuoted, "hello world"))
  assert_eq(tokens[0].raw, "'hello world'")
}

///|
test "tokenize double quoted string" {
  let (tokens, _) = tokenize("\"hello world\"")
  assert_eq(tokens.length(), 2)
  assert_eq(tokens[0].kind, StringLit(DoubleQuoted, "hello world"))
}

///|
test "tokenize double quoted string with escape" {
  let (tokens, _) = tokenize("\"hello \\\"world\\\"\"")
  assert_eq(tokens.length(), 2)
  assert_eq(tokens[0].kind, StringLit(DoubleQuoted, "hello \\\"world\\\""))
}

///|
test "tokenize number" {
  let (tokens, _) = tokenize("42")
  assert_eq(tokens.length(), 2)
  assert_eq(tokens[0].kind, Number("42"))
}

///|
test "tokenize decimal number" {
  let (tokens, _) = tokenize("3.14")
  assert_eq(tokens.length(), 2)
  assert_eq(tokens[0].kind, Number("3.14"))
}

///|
test "tokenize scientific number" {
  let (tokens, _) = tokenize("1.5e10")
  assert_eq(tokens.length(), 2)
  assert_eq(tokens[0].kind, Number("1.5e10"))
}

///|
test "tokenize dollar substitution" {
  let (tokens, _) = tokenize("$var")
  assert_eq(tokens.length(), 3) // $, var, EOF
  assert_eq(tokens[0].kind, Dollar)
  assert_eq(tokens[1].kind, Ident("var"))
}

///|
test "tokenize dollar brace substitution" {
  let (tokens, _) = tokenize("${var}")
  assert_eq(tokens.length(), 4) // ${, var, }, EOF
  assert_eq(tokens[0].kind, DollarBrace)
  assert_eq(tokens[1].kind, Ident("var"))
  assert_eq(tokens[2].kind, RightBrace)
}

///|
test "tokenize at for import" {
  let (tokens, _) = tokenize("@path/to/file")
  assert_eq(tokens.length(), 5)
  assert_eq(tokens[0].kind, At)
}

///|
test "tokenize glob patterns" {
  let (tokens, _) = tokenize("* ** ***")
  assert_eq(tokens.length(), 4) // *, **, ***, EOF
  assert_eq(tokens[0].kind, Star)
  assert_eq(tokens[1].kind, DoubleStar)
  assert_eq(tokens[2].kind, TripleStar)
}

///|
test "tokenize pipe and ampersand" {
  let (tokens, _) = tokenize("| &")
  assert_eq(tokens.length(), 3)
  assert_eq(tokens[0].kind, Pipe)
  assert_eq(tokens[1].kind, Ampersand)
}

///|
test "tokenize newlines" {
  let (tokens, _) = tokenize("a\nb")
  assert_eq(tokens.length(), 4) // a, newline, b, EOF
  assert_eq(tokens[0].kind, Ident("a"))
  assert_eq(tokens[1].kind, Newline)
  assert_eq(tokens[2].kind, Ident("b"))
}

///|
test "tokenize position tracking" {
  let (tokens, _) = tokenize("a\nb")
  // 'a' at line 1, col 1
  assert_eq(tokens[0].range.start.line, 1)
  assert_eq(tokens[0].range.start.column, 1)
  assert_eq(tokens[0].range.start.offset, 0)
  // newline at line 1, col 2
  assert_eq(tokens[1].range.start.line, 1)
  assert_eq(tokens[1].range.start.column, 2)
  // 'b' at line 2, col 1
  assert_eq(tokens[2].range.start.line, 2)
  assert_eq(tokens[2].range.start.column, 1)
}

///|
test "tokenize parentheses" {
  let (tokens, _) = tokenize("(a -> b)[0]")
  assert_eq(tokens.length(), 9) // (, a, ->, b, ), [, 0, ], EOF
  assert_eq(tokens[0].kind, LeftParen)
  assert_eq(tokens[1].kind, Ident("a"))
  assert_eq(tokens[2].kind, Arrow)
  assert_eq(tokens[3].kind, Ident("b"))
  assert_eq(tokens[4].kind, RightParen)
  assert_eq(tokens[5].kind, LeftBracket)
  assert_eq(tokens[6].kind, Number("0"))
  assert_eq(tokens[7].kind, RightBracket)
}

///|
test "tokenize identifier with hyphen" {
  let (tokens, _) = tokenize("my-node")
  assert_eq(tokens.length(), 2)
  assert_eq(tokens[0].kind, Ident("my-node"))
}

///|
test "tokenize identifier with underscore" {
  let (tokens, _) = tokenize("my_node")
  assert_eq(tokens.length(), 2)
  assert_eq(tokens[0].kind, Ident("my_node"))
}

///|
test "tokenize semicolon" {
  let (tokens, _) = tokenize("a; b")
  assert_eq(tokens.length(), 4) // a, ;, b, EOF
  assert_eq(tokens[0].kind, Ident("a"))
  assert_eq(tokens[1].kind, Semicolon)
  assert_eq(tokens[2].kind, Ident("b"))
}

///|
test "tokenize d2 example" {
  let source = "server -> database: queries"
  let (tokens, errors) = tokenize(source)
  assert_eq(errors.length(), 0)
  assert_eq(tokens.length(), 6) // server, ->, database, :, queries, EOF
  assert_eq(tokens[0].kind, Ident("server"))
  assert_eq(tokens[1].kind, Arrow)
  assert_eq(tokens[2].kind, Ident("database"))
  assert_eq(tokens[3].kind, Colon)
  assert_eq(tokens[4].kind, Ident("queries"))
  assert_eq(tokens[5].kind, Eof)
}

///|
test "unterminated string error" {
  let (_, errors) = tokenize("\"unterminated")
  assert_true(errors.length() > 0)
  assert_true(errors[0].message.contains("Unterminated"))
}

///|
test "unterminated block comment error" {
  let (_, errors) = tokenize("/* unterminated")
  assert_true(errors.length() > 0)
  assert_true(errors[0].message.contains("Unterminated"))
}

///|
test "token is_arrow helper" {
  let (tokens, _) = tokenize("->")
  assert_true(tokens[0].is_arrow())
  let (tokens2, _) = tokenize("server")
  assert_false(tokens2[0].is_arrow())
}

///|
test "token is_edge_op helper" {
  let (tokens, _) = tokenize("-> <- <-> --")
  assert_true(tokens[0].is_edge_op())
  assert_true(tokens[1].is_edge_op())
  assert_true(tokens[2].is_edge_op())
  assert_true(tokens[3].is_edge_op())
}

///|
test "token is_trivia helper" {
  let (tokens, _) = tokenize("# comment\n")
  assert_true(tokens[0].is_trivia()) // comment
  assert_true(tokens[1].is_trivia()) // newline
}

///|
test "Position::zero" {
  let pos = Position::zero()
  assert_eq(pos.line, 1)
  assert_eq(pos.column, 1)
  assert_eq(pos.offset, 0)
}

///|
test "complex d2 example" {
  let source =
    #|aws: AWS {
    #|  server: EC2
    #|  database: RDS
    #|}
    #|server -> database
  let (tokens, errors) = tokenize(source)
  assert_eq(errors.length(), 0)
  // Verify key tokens are present
  let mut found_aws = false
  let mut found_arrow = false
  let mut found_brace = false
  for token in tokens {
    match token.kind {
      Ident("aws") => found_aws = true
      Arrow => found_arrow = true
      LeftBrace => found_brace = true
      _ => ()
    }
  }
  assert_true(found_aws)
  assert_true(found_arrow)
  assert_true(found_brace)
}
