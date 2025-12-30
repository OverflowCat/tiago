///|
/// Lexer for the D2 diagram language
pub struct Lexer {
  source : String
  chars : Array[Char] // pre-converted characters for easy indexing
  mut pos : Int // current character position
  mut line : Int // current line (1-indexed)
  mut column : Int // current column (1-indexed)
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
/// Create a new lexer for the given source
pub fn Lexer::new(source : String) -> Lexer {
  let chars = source.to_array()
  { source, chars, pos: 0, line: 1, column: 1, tokens: [], errors: [] }
}

///|
/// Tokenize the entire source and return tokens
pub fn Lexer::tokenize(self : Lexer) -> (Array[Token], Array[LexError]) {
  while not(self.is_at_end()) {
    self.scan_token()
  }
  // Add EOF token
  let eof_pos = self.current_position()
  self.tokens.push(Token::new(Eof, Range::new(eof_pos, eof_pos), ""))
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
fn Lexer::advance(self : Lexer) -> Char {
  let c = self.peek()
  self.pos += 1
  if c == '\n' {
    self.line += 1
    self.column = 1
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
  self.tokens.push(Token::new(kind, Range::new(start, end), raw))
}

///|
fn Lexer::add_error(self : Lexer, message : String, start : Position) -> Unit {
  let end = self.current_position()
  self.errors.push({ message, range: Range::new(start, end) })
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
    '.' => self.add_token(Dot, start)
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
    '"' => self.scan_double_quoted_string(start)
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
        self.add_error("Unexpected character: " + c.to_string(), start)
        self.add_token(Error("Unexpected character"), start)
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
  let content = self.slice_source(content_start, self.pos)
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
  is_alpha(c) || is_digit(c) || c == '_' || c == '-'
}

///|
/// Convenience function to tokenize a string
pub fn tokenize(source : String) -> (Array[Token], Array[LexError]) {
  let lexer = Lexer::new(source)
  lexer.tokenize()
}
