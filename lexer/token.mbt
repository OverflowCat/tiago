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
/// Position in source code with line, column, and byte offset
pub struct Position {
  line : Int // 1-indexed line number
  column : Int // 1-indexed column number (in characters)
  offset : Int // 0-indexed byte offset
} derive(Eq, Show)

///|
/// A range in source code from start to end position
pub struct Range {
  start : Position
  end : Position
} derive(Eq, Show)

///|
/// Token types for the D2 language
pub enum TokenKind {
  // Literals
  Ident(String) // identifiers and unquoted strings
  StringLit(StringType, String) // string literals with type
  Number(String) // numeric literals (kept as string for precision)

  // Keywords / special identifiers handled at parse level

  // Operators and punctuation
  Colon // :
  Semicolon // ;
  Dot // .
  Comma // ,
  LeftBrace // {
  RightBrace // }
  LeftBracket // [
  RightBracket // ]
  LeftParen // (
  RightParen // )
  Pipe // |
  Ampersand // &

  // Arrows
  Arrow // ->
  ReverseArrow // <-
  BidirectionalArrow // <->
  DoubleDash // --

  // Comments
  Comment(String) // # single line comment
  BlockComment(String) // /* block comment */

  // Special
  At // @ for imports
  DotDotDot // ... for spread imports
  Dollar // $ for substitutions
  DollarBrace // ${ for substitutions
  Star // * for glob patterns
  DoubleStar // ** for glob patterns
  TripleStar // *** for glob patterns

  // Whitespace and structure
  Newline // significant newlines

  // End of file
  Eof

  // Error token for error recovery
  Error(String)
} derive(Eq, Show)

///|
/// String literal types
pub enum StringType {
  SingleQuoted
  DoubleQuoted
} derive(Eq, Show)

///|
/// A token with its kind, range, and raw text
pub struct Token {
  kind : TokenKind
  range : Range
  raw : String // original source text
} derive(Eq, Show)

///|
pub fn Position::new(line : Int, column : Int, offset : Int) -> Position {
  { line, column, offset }
}

///|
pub fn Range::new(start : Position, end : Position) -> Range {
  { start, end }
}

///|
pub fn Token::new(kind : TokenKind, range : Range, raw : String) -> Token {
  { kind, range, raw }
}

///|
/// Create a simple position at the origin
pub fn Position::zero() -> Position {
  { line: 1, column: 1, offset: 0 }
}

///|
/// Check if a token is a trivia token (whitespace, comments)
pub fn Token::is_trivia(self : Token) -> Bool {
  match self.kind {
    Comment(_) | BlockComment(_) | Newline => true
    _ => false
  }
}

///|
/// Check if a token is an arrow
pub fn Token::is_arrow(self : Token) -> Bool {
  match self.kind {
    Arrow | ReverseArrow | BidirectionalArrow => true
    _ => false
  }
}

///|
/// Check if a token can start an edge
pub fn Token::is_edge_op(self : Token) -> Bool {
  match self.kind {
    Arrow | ReverseArrow | BidirectionalArrow | DoubleDash => true
    _ => false
  }
}
