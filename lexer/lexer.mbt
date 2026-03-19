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
/// Lexer for the diago diagram language
struct Lexer {
  path : String
  chars : Array[Char] // pre-converted characters for easy indexing
  mut pos : Int // current character position
  mut line : Int // current line (0-based)
  mut column : Int // current column (0-based)
  tokens : Array[Token]
  errors : Array[LexError]
}

///|
/// Lexer error
pub struct LexError {
  message : String
  range : Range
} derive(Eq, Show)

///|
/// Create a new lexer for the given source (in-memory, no path)
pub fn Lexer::new(source : String) -> Lexer {
  Lexer::with_path("", source)
}

///|
pub fn Lexer::with_path(path : String, source : String) -> Lexer {
  let chars = source.to_array()
  { path, chars, pos: 0, line: 0, column: 0, tokens: [], errors: [] }
}

///|
/// Tokenize the entire source and return tokens
pub fn Lexer::tokenize(self : Lexer) -> (Array[Token], Array[LexError]) {
  while not(self.is_at_end()) {
    self.scan_token()
  }
  // Add EOF token
  let eof_pos = self.current_position()
  self.tokens.push(
    Token::new(Eof, Range::with_path(self.path, eof_pos, eof_pos), ""),
  )
  (self.tokens, self.errors)
}

///|
fn Lexer::is_at_end(self : Lexer) -> Bool {
  self.pos >= self.chars.length()
}

///|
fn Lexer::current_position(self : Lexer) -> Position {
  Position::new(self.line, self.column, self.pos)
}

///|
fn Lexer::peek(self : Lexer) -> Char {
  if self.is_at_end() {
    '\u{0}'
  } else {
    self.chars[self.pos]
  }
}

///|
fn Lexer::peek_next(self : Lexer) -> Char {
  if self.pos + 1 >= self.chars.length() {
    '\u{0}'
  } else {
    self.chars[self.pos + 1]
  }
}

///|
fn Lexer::peek_offset(self : Lexer, n : Int) -> Char {
  if self.pos + n >= self.chars.length() {
    '\u{0}'
  } else {
    self.chars[self.pos + n]
  }
}

///|
fn Lexer::advance(self : Lexer) -> Char {
  let c = self.peek()
  self.pos += 1
  if c == '\n' {
    self.line += 1
    self.column = 0
  } else {
    self.column += 1
  }
  c
}

///|
fn Lexer::slice_source(self : Lexer, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    if i < self.chars.length() {
      buf.write_char(self.chars[i])
    }
  }
  buf.to_string()
}

///|
fn Lexer::add_token(self : Lexer, kind : TokenKind, start : Position) -> Unit {
  let end = self.current_position()
  let raw = self.slice_source(start.offset, end.offset)
  self.tokens.push(
    Token::new(kind, Range::with_path(self.path, start, end), raw),
  )
}

///|
fn Lexer::add_error(self : Lexer, message : String, start : Position) -> Unit {
  let end = self.current_position()
  self.errors.push({ message, range: Range::with_path(self.path, start, end) })
}

///|
fn Lexer::scan_token(self : Lexer) -> Unit {
  let start = self.current_position()
  let c = self.advance()
  match c {
    // Whitespace (except newlines which are significant)
    ' ' | '\t' | '\r' => self.skip_whitespace()
    // Newlines
    '\n' => self.add_token(Newline, start)
    // Single character tokens
    ':' => self.add_token(Colon, start)
    ';' => self.add_token(Semicolon, start)
    '.' => self.scan_dots(start)
    ',' => self.add_token(Comma, start)
    '{' => self.add_token(LeftBrace, start)
    '}' => self.add_token(RightBrace, start)
    '[' => self.add_token(LeftBracket, start)
    ']' => self.add_token(RightBracket, start)
    '(' => self.add_token(LeftParen, start)
    ')' => self.add_token(RightParen, start)
    '|' => self.add_token(Pipe, start)
    '&' => self.add_token(Ampersand, start)
    '@' => self.add_token(At, start)
    // Stars (glob patterns)
    '*' => self.scan_stars(start)
    // Arrows and dashes
    '-' => self.scan_dash(start)
    '<' => self.scan_left_angle(start)
    // Comments
    '#' => self.scan_line_comment(start)
    '/' =>
      if self.peek() == '*' {
        let _ = self.advance()
        self.scan_block_comment(start)
      } else {
        // Treat as identifier start or error
        self.scan_identifier(start, c)
      }
    // Strings
    '\'' => self.scan_single_quoted_string(start)
    '"' =>
      if self.peek() == '"' && self.peek_next() == '"' {
        let _ = self.advance()
        let _ = self.advance()
        self.scan_triple_quoted_block_comment(start)
      } else {
        self.scan_double_quoted_string(start)
      }
    // Dollar for substitutions
    '$' =>
      if self.peek() == '{' {
        let _ = self.advance()
        self.add_token(DollarBrace, start)
      } else {
        self.add_token(Dollar, start)
      }
    // Numbers
    _ =>
      if is_digit(c) {
        self.scan_number(start, c)
      } else if is_ident_start(c) {
        self.scan_identifier(start, c)
      } else {
        // reference behavior: most non-delimiter characters are part of unquoted text.
        // Keep them as identifier-like tokens so parser-level delimiters decide.
        self.scan_identifier(start, c)
      }
  }
}

///|
fn Lexer::skip_whitespace(self : Lexer) -> Unit {
  while not(self.is_at_end()) {
    match self.peek() {
      ' ' | '\t' | '\r' => {
        let _ = self.advance()
      }
      _ => break
    }
  }
}

///|
fn Lexer::scan_stars(self : Lexer, start : Position) -> Unit {
  // Could be *, **, or ***
  if self.peek() == '*' {
    let _ = self.advance()
    if self.peek() == '*' {
      let _ = self.advance()
      self.add_token(TripleStar, start)
    } else {
      self.add_token(DoubleStar, start)
    }
  } else {
    self.add_token(Star, start)
  }
}

///|
fn Lexer::scan_dots(self : Lexer, start : Position) -> Unit {
  // Could be . or ...
  if self.peek() == '.' && self.peek_next() == '.' {
    let _ = self.advance()
    let _ = self.advance()
    self.add_token(DotDotDot, start)
  } else {
    self.add_token(Dot, start)
  }
}

///|
fn Lexer::scan_dash(self : Lexer, start : Position) -> Unit {
  // Could be -, --, or ->
  if self.peek() == '>' {
    let _ = self.advance()
    self.add_token(Arrow, start)
  } else if self.peek() == '-' {
    let _ = self.advance()
    self.add_token(DoubleDash, start)
  } else {
    // Just a minus, treat as part of number or identifier
    self.scan_identifier(start, '-')
  }
}

///|
fn Lexer::scan_left_angle(self : Lexer, start : Position) -> Unit {
  // Could be <-, <->, or just <
  if self.peek() == '-' {
    let _ = self.advance()
    if self.peek() == '>' {
      let _ = self.advance()
      self.add_token(BidirectionalArrow, start)
    } else {
      self.add_token(ReverseArrow, start)
    }
  } else {
    // Treat < as identifier character
    self.scan_identifier(start, '<')
  }
}

///|
fn Lexer::scan_line_comment(self : Lexer, start : Position) -> Unit {
  let content_start = self.pos
  while not(self.is_at_end()) && self.peek() != '\n' {
    let _ = self.advance()
  }
  let raw = self.slice_source(content_start, self.pos)
  let chars = raw.to_array()
  let content = if chars.length() > 0 && chars[0] == ' ' {
    substring_comment_by_offsets(raw, 1, chars.length())
  } else {
    raw
  }
  self.add_token(Comment(content), start)
}

///|
fn Lexer::scan_block_comment(self : Lexer, start : Position) -> Unit {
  let content_start = self.pos
  let mut depth = 1
  while not(self.is_at_end()) && depth > 0 {
    if self.peek() == '/' && self.peek_next() == '*' {
      let _ = self.advance()
      let _ = self.advance()
      depth += 1
    } else if self.peek() == '*' && self.peek_next() == '/' {
      let _ = self.advance()
      let _ = self.advance()
      depth -= 1
    } else {
      let _ = self.advance()
    }
  }
  if depth > 0 {
    self.add_error("Unterminated block comment", start)
  }
  // Content excludes the closing */
  let content_end = if depth == 0 { self.pos - 2 } else { self.pos }
  let content = self.slice_source(content_start, content_end)
  self.add_token(BlockComment(content), start)
}

///|
fn Lexer::scan_single_quoted_string(self : Lexer, start : Position) -> Unit {
  let content_start = self.pos
  while not(self.is_at_end()) && self.peek() != '\'' {
    if self.peek() == '\\' && self.peek_next() == '\'' {
      let _ = self.advance() // skip backslash
      let _ = self.advance()
      // skip escaped quote
    } else if self.peek() == '\n' {
      // Single-quoted strings cannot span lines
      self.add_error("Unterminated string", start)
      break
    } else {
      let _ = self.advance()
    }
  }
  let content = self.slice_source(content_start, self.pos)
  if not(self.is_at_end()) && self.peek() == '\'' {
    let _ = self.advance()
    // consume closing quote
  } else {
    self.add_error("Unterminated string", start)
  }
  self.add_token(StringLit(SingleQuoted, content), start)
}

///|
fn Lexer::scan_double_quoted_string(self : Lexer, start : Position) -> Unit {
  let content_start = self.pos
  while not(self.is_at_end()) && self.peek() != '"' {
    if self.peek() == '\\' {
      let _ = self.advance() // skip backslash
      if not(self.is_at_end()) {
        let _ = self.advance()
        // skip escaped char
      }
    } else if self.peek() == '\n' {
      // Double-quoted strings cannot span lines
      self.add_error("Unterminated string", start)
      break
    } else {
      let _ = self.advance()
    }
  }
  let content = self.slice_source(content_start, self.pos)
  if not(self.is_at_end()) && self.peek() == '"' {
    let _ = self.advance()
    // consume closing quote
  } else {
    self.add_error("Unterminated string", start)
  }
  self.add_token(StringLit(DoubleQuoted, content), start)
}

///|
fn Lexer::scan_triple_quoted_block_comment(
  self : Lexer,
  start : Position,
) -> Unit {
  let content_start = self.pos
  while not(self.is_at_end()) {
    if self.peek() == '"' &&
      self.peek_next() == '"' &&
      self.peek_offset(2) == '"' {
      let content = trim_block_comment_content(
        self.slice_source(content_start, self.pos),
      )
      let _ = self.advance()
      let _ = self.advance()
      let _ = self.advance()
      self.add_token(BlockComment(content), start)
      return
    }
    let _ = self.advance()
  }
  self.add_error("Unterminated block comment", start)
  self.add_token(
    BlockComment(
      trim_block_comment_content(self.slice_source(content_start, self.pos)),
    ),
    start,
  )
}

///|
fn Lexer::scan_number(self : Lexer, start : Position, first : Char) -> Unit {
  let buf = StringBuilder::new()
  buf.write_char(first)
  // Integer part
  while not(self.is_at_end()) && is_digit(self.peek()) {
    buf.write_char(self.advance())
  }
  // Decimal part
  if self.peek() == '.' && is_digit(self.peek_next()) {
    buf.write_char(self.advance()) // consume '.'
    while not(self.is_at_end()) && is_digit(self.peek()) {
      buf.write_char(self.advance())
    }
  }
  // Exponent part
  if self.peek() == 'e' || self.peek() == 'E' {
    buf.write_char(self.advance())
    if self.peek() == '+' || self.peek() == '-' {
      buf.write_char(self.advance())
    }
    while not(self.is_at_end()) && is_digit(self.peek()) {
      buf.write_char(self.advance())
    }
  }
  self.add_token(Number(buf.to_string()), start)
}

///|
fn Lexer::scan_identifier(self : Lexer, start : Position, first : Char) -> Unit {
  let buf = StringBuilder::new()
  buf.write_char(first)
  while not(self.is_at_end()) && is_ident_continue(self.peek()) {
    if self.peek() == '-' {
      let next = self.peek_next()
      if next == '>' || next == '-' {
        break
      }
    }
    buf.write_char(self.advance())
  }
  self.add_token(Ident(buf.to_string()), start)
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn is_ident_start(c : Char) -> Bool {
  is_alpha(c) || c == '_'
}

///|
fn is_ident_continue(c : Char) -> Bool {
  is_alpha(c) ||
  is_digit(c) ||
  c == '_' ||
  c == '-' ||
  c == '\'' ||
  c == '+' ||
  c == '!' ||
  c == '?' ||
  c == '=' ||
  c == '/' ||
  c == '\\'
}

///|
fn trim_block_comment_content(s : String) -> String {
  trim_comment_common_indent(trim_comment_space_after_last_newline(s))
}

///|
fn trim_comment_space_after_last_newline(s : String) -> String {
  let chars = s.to_array()
  let mut last_nl = -1
  for i, c in chars {
    if c == '\n' {
      last_nl = i
    }
  }
  if last_nl < 0 {
    return trim_comment_right_ws(s)
  }
  let last_line = substring_comment_by_offsets(s, last_nl + 1, chars.length())
  let trimmed_last_line = trim_comment_right_ws(last_line)
  if trimmed_last_line.length() == 0 {
    return substring_comment_by_offsets(s, 0, last_nl)
  }
  substring_comment_by_offsets(s, 0, last_nl + 1) + trimmed_last_line
}

///|
fn trim_comment_right_ws(s : String) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 {
    let c = chars[end - 1]
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      end = end - 1
    } else {
      break
    }
  }
  substring_comment_by_offsets(s, 0, end)
}

///|
fn trim_comment_common_indent(s : String) -> String {
  let lines = s.split("\n").collect()
  let mut min_spaces = -1
  for line in lines {
    let text = line.to_string()
    if text.length() == 0 {
      continue
    }
    let chars = text.to_array()
    let mut spaces = 0
    let mut has_non_space = false
    for c in chars {
      if c == ' ' {
        spaces = spaces + 1
      } else if c == '\t' {
        spaces = spaces + 2
      } else {
        has_non_space = true
        break
      }
    }
    if has_non_space {
      if min_spaces < 0 || spaces < min_spaces {
        min_spaces = spaces
      }
    }
  }
  if min_spaces <= 0 {
    return s
  }
  let out : Array[String] = []
  for line in lines {
    let text = line.to_string()
    if text.length() == 0 {
      out.push(text)
      continue
    }
    let chars = text.to_array()
    let mut to_drop = min_spaces
    let mut idx = 0
    while idx < chars.length() && to_drop > 0 {
      if chars[idx] == ' ' {
        to_drop = to_drop - 1
        idx = idx + 1
      } else if chars[idx] == '\t' {
        to_drop = to_drop - 2
        idx = idx + 1
      } else {
        break
      }
    }
    out.push(substring_comment_by_offsets(text, idx, chars.length()))
  }
  out.join("\n")
}

///|
fn substring_comment_by_offsets(s : String, start : Int, end : Int) -> String {
  let chars = s.to_array()
  let buf = StringBuilder::new()
  let mut i = start
  while i < end && i < chars.length() {
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.to_string()
}

///|
/// Convenience function to tokenize a string
pub fn tokenize(source : String) -> (Array[Token], Array[LexError]) {
  let lexer = Lexer::new(source)
  lexer.tokenize()
}

///|
pub fn tokenize_with_path(
  path : String,
  source : String,
) -> (Array[Token], Array[LexError]) {
  let lexer = Lexer::with_path(path, source)
  lexer.tokenize()
}
