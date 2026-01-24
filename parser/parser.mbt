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
/// Token-based recursive descent parser for diago

///|
struct Parser {
  source : String
  tokens : Array[@lexer.Token]
  mut pos : Int
  errors : ParseErrors
} derive(Show)

///|
/// Parse a diago source string into an AST
pub fn parse(source : String) -> (@ast.Map, ParseErrors) {
  parse_with_path("", source)
}

///|
pub fn parse_with_path(
  path : String,
  source : String,
) -> (@ast.Map, ParseErrors) {
  let (tokens, lex_errors) = @lexer.tokenize_with_path(path, source)
  let parser = Parser::new(source, tokens)

  // Add lexer errors to parse errors
  for err in lex_errors {
    parser.errors.add(err.range, err.message)
  }
  let ast = parser.parse_map(true)
  (ast, parser.errors)
}

///|
pub fn Parser::new(source : String, tokens : Array[@lexer.Token]) -> Parser {
  { source, tokens, pos: 0, errors: ParseErrors::new() }
}

///|
/// Extract substring from source using positions
fn Parser::extract_source(
  self : Parser,
  start : @lexer.Position,
  end : @lexer.Position,
) -> String {
  let chars = self.source.to_array()
  let buf = StringBuilder::new()
  for i = start.offset; i < end.offset && i < chars.length(); i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn Parser::is_at_end(self : Parser) -> Bool {
  self.pos >= self.tokens.length() || self.peek_is_eof()
}

///|
fn Parser::peek_is_eof(self : Parser) -> Bool {
  match self.peek() {
    @lexer.Eof => true
    _ => false
  }
}

///|
fn Parser::current(self : Parser) -> @lexer.Token {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos]
  } else {
    self.tokens[self.tokens.length() - 1]
  }
}

///|
fn Parser::peek(self : Parser) -> @lexer.TokenKind {
  self.current().kind
}

///|
fn Parser::advance(self : Parser) -> @lexer.Token {
  let token = self.current()
  if not(self.is_at_end()) {
    self.pos += 1
  }
  token
}

///|
fn Parser::skip_trivia(self : Parser) -> Unit {
  while not(self.is_at_end()) {
    match self.peek() {
      @lexer.Newline | @lexer.Comment(_) | @lexer.BlockComment(_) => {
        let _ = self.advance()

      }
      _ => break
    }
  }
}

///|
fn Parser::skip_whitespace_not_newline(self : Parser) -> Unit {
  while not(self.is_at_end()) {
    match self.peek() {
      @lexer.Comment(_) | @lexer.BlockComment(_) => {
        let _ = self.advance()

      }
      _ => break
    }
  }
}

///|
fn Parser::error(self : Parser, message : String) -> Unit {
  self.errors.add(self.current().range, message)
}

///|
fn Parser::parse_map(self : Parser, is_file_map : Bool) -> @ast.Map {
  let start = self.current().range.start
  let nodes : Array[@ast.MapNode] = []
  while not(self.is_at_end()) {
    self.skip_trivia()
    if self.is_at_end() {
      break
    }
    match self.peek() {
      @lexer.Semicolon => {
        let _ = self.advance()
        continue
      }
      @lexer.RightBrace =>
        if is_file_map {
          self.error("unexpected } in file map")
          let _ = self.advance()
          continue
        } else {
          break
        }
      _ => ()
    }
    match self.parse_map_node() {
      Some(node) => nodes.push(node)
      None =>
        // Error recovery: skip to next line
        while not(self.is_at_end()) {
          match self.peek() {
            @lexer.Newline | @lexer.Semicolon | @lexer.RightBrace => break
            _ => {
              let _ = self.advance()

            }
          }
        }
    }
  }
  let end = self.current().range.end
  @ast.Map::new(@lexer.Range::new(start, end), nodes)
}

///|
fn Parser::parse_map_node(self : Parser) -> @ast.MapNode? {
  match self.peek() {
    @lexer.Comment(content) => {
      let token = self.advance()
      Some(@ast.MapNode::Comment(token.range, content))
    }
    @lexer.BlockComment(content) => {
      let token = self.advance()
      Some(@ast.MapNode::BlockComment(token.range, content))
    }
    @lexer.Dollar | @lexer.DollarBrace =>
      match self.parse_substitution() {
        Some(sub) => Some(@ast.MapNode::Substitution(sub))
        None => None
      }
    @lexer.At =>
      // Import statement: @path
      match self.parse_import(false) {
        Some(imp) => Some(@ast.MapNode::Import(imp))
        None => None
      }
    @lexer.DotDotDot => {
      // Spread import or spread substitution: ...@path or ...$var
      let dots = self.advance() // consume ...
      match self.peek() {
        @lexer.At =>
          match self.parse_import(true) {
            Some(imp) => Some(@ast.MapNode::Import(imp))
            None => None
          }
        @lexer.Dollar | @lexer.DollarBrace =>
          match self.parse_substitution() {
            Some(sub) =>
              Some(
                @ast.MapNode::Substitution(
                  @ast.Substitution::new(
                    @lexer.Range::between(dots.range, sub.range),
                    true,
                    sub.path,
                  ),
                ),
              )
            None => None
          }
        _ => {
          self.error("expected @ or $ after ...")
          None
        }
      }
    }
    _ =>
      match self.parse_key() {
        Some(key) => Some(@ast.MapNode::Key(key))
        None => None
      }
  }
}

///|
fn Parser::parse_key(self : Parser) -> @ast.Key? {
  let start = self.current().range.start

  // Collect all the values we need for Key::new
  let mut ampersand = false
  let not_ampersand = false
  let mut key_path : @ast.KeyPath? = None
  let edges : Array[@ast.Edge] = []
  let mut edge_index : @ast.EdgeIndex? = None
  let mut edge_key : @ast.KeyPath? = None
  let primary : @ast.Scalar? = None
  let mut value : @ast.Value? = None

  // Check for ampersand/not-ampersand filters
  match self.peek() {
    @lexer.Ampersand => {
      let _ = self.advance()
      ampersand = true
    }
    _ => ()
  }

  // Check for edge group (x -> y)
  match self.peek() {
    @lexer.LeftParen => {
      let _ = self.advance()
      let (kp, eds, eidx, ekey, val) = self.parse_edge_group()
      key_path = kp
      for e in eds {
        edges.push(e)
      }
      edge_index = eidx
      edge_key = ekey
      value = val
      let end = self.current().range.end
      let range = @lexer.Range::new(start, end)
      return Some(
        @ast.Key::new(
          range, ampersand, not_ampersand, key_path, edges, edge_index, edge_key,
          primary, value,
        ),
      )
    }
    _ => ()
  }

  // Parse key path
  match self.parse_key_path() {
    Some(kp) => key_path = Some(kp)
    None => ()
  }

  // Parse edges (-> <- <->)
  self.skip_whitespace_not_newline()
  while not(self.is_at_end()) && self.current().is_edge_op() {
    match self.parse_edge(key_path) {
      Some(edge) => {
        let dst = edge.dst
        edges.push(edge)
        key_path = Some(dst) // Keep dst as potential source for next edge in chain
      }
      None => break
    }
    self.skip_whitespace_not_newline()
  }
  // After parsing edges, clear key_path since it was consumed by the edge chain
  if edges.length() > 0 {
    key_path = None
  }

  // Parse edge index [n] or [*]
  match self.peek() {
    @lexer.LeftBracket =>
      match self.parse_edge_index() {
        Some(idx) => edge_index = Some(idx)
        None => ()
      }
    _ => ()
  }

  // Parse edge key (.property after edges)
  if edges.length() > 0 {
    match self.peek() {
      @lexer.Dot => {
        let _ = self.advance()
        match self.parse_key_path() {
          Some(kp) => edge_key = Some(kp)
          None => self.error("expected key path after .")
        }
      }
      _ => ()
    }
  }

  // Parse colon and value
  self.skip_whitespace_not_newline()
  match self.peek() {
    @lexer.Colon => {
      let _ = self.advance()
      self.skip_whitespace_not_newline()
      match self.parse_value() {
        Some(val) => value = Some(val)
        None => ()
      }
      // diago allows "name: label { block }" - check for block after scalar
      self.skip_whitespace_not_newline()
      match (value, self.peek()) {
        (Some(@ast.Value::Scalar(_)), @lexer.LeftBrace) =>
          match self.parse_block() {
            Some(block) =>
              // Merge: keep scalar as label, wrap in BlockScalar
              value = Some(@ast.Value::BlockScalar(value.unwrap(), block))
            None => ()
          }
        _ => ()
      }
    }
    @lexer.LeftBrace =>
      match self.parse_block() {
        Some(map) => value = Some(@ast.Value::Map(map))
        None => ()
      }
    _ => ()
  }
  let end = self.current().range.end
  let range = @lexer.Range::new(start, end)
  if key_path is None && edges.length() == 0 {
    None
  } else {
    Some(
      @ast.Key::new(
        range, ampersand, not_ampersand, key_path, edges, edge_index, edge_key, primary,
        value,
      ),
    )
  }
}

///|
fn Parser::parse_key_path(self : Parser) -> @ast.KeyPath? {
  let start = self.current().range.start
  let path : Array[@ast.StringValue] = []
  match self.parse_string_for_key() {
    Some(s) => path.push(s)
    None => return None
  }
  while not(self.is_at_end()) {
    match self.peek() {
      @lexer.Dot => {
        let _ = self.advance()
        match self.parse_string_for_key() {
          Some(s) => path.push(s)
          None => {
            self.error("expected identifier after .")
            break
          }
        }
      }
      _ => break
    }
  }
  let end = self.current().range.end
  Some(@ast.KeyPath::new(@lexer.Range::new(start, end), path))
}

///|
fn Parser::parse_string_for_key(self : Parser) -> @ast.StringValue? {
  match self.peek() {
    @lexer.Ident(name) => {
      let token = self.advance()
      Some(
        @ast.StringValue::Unquoted(
          @ast.UnquotedString::new(
            token.range,
            [@ast.Interpolation::Text(name)],
            [],
          ),
        ),
      )
    }
    @lexer.StringLit(style, content) => {
      let token = self.advance()
      match style {
        @lexer.SingleQuoted =>
          Some(@ast.StringValue::SingleQuoted(token.range, content))
        @lexer.DoubleQuoted =>
          Some(
            @ast.StringValue::DoubleQuoted(
              @ast.DoubleQuotedString::new(token.range, [
                @ast.Interpolation::Text(content),
              ]),
            ),
          )
      }
    }
    @lexer.Number(n) => {
      let token = self.advance()
      Some(
        @ast.StringValue::Unquoted(
          @ast.UnquotedString::new(token.range, [@ast.Interpolation::Text(n)], []),
        ),
      )
    }
    @lexer.Star => {
      let token = self.advance()
      Some(
        @ast.StringValue::Unquoted(
          @ast.UnquotedString::new(
            token.range,
            [@ast.Interpolation::Text("*")],
            ["*"],
          ),
        ),
      )
    }
    @lexer.DoubleStar => {
      let token = self.advance()
      Some(
        @ast.StringValue::Unquoted(
          @ast.UnquotedString::new(
            token.range,
            [@ast.Interpolation::Text("**")],
            ["*", "", "*"],
          ),
        ),
      )
    }
    @lexer.TripleStar => {
      let token = self.advance()
      Some(
        @ast.StringValue::Unquoted(
          @ast.UnquotedString::new(
            token.range,
            [@ast.Interpolation::Text("***")],
            ["*", "", "*", "", "*"],
          ),
        ),
      )
    }
    _ => None
  }
}

///|
fn Parser::parse_edge(self : Parser, src_key : @ast.KeyPath?) -> @ast.Edge? {
  let src = match src_key {
    Some(k) => k
    None => {
      self.error("edge requires a source")
      return None
    }
  }
  let start = self.current().range.start
  let (src_arrow, dst_arrow) = match self.peek() {
    @lexer.Arrow => {
      let _ = self.advance()
      ("", ">")
    }
    @lexer.ReverseArrow => {
      let _ = self.advance()
      ("<", "")
    }
    @lexer.BidirectionalArrow => {
      let _ = self.advance()
      ("<", ">")
    }
    @lexer.DoubleDash => {
      let _ = self.advance()
      ("", "")
    }
    _ => return None
  }
  self.skip_whitespace_not_newline()
  let dst = match self.parse_key_path() {
    Some(kp) => kp
    None => {
      self.error("edge requires a destination")
      return None
    }
  }
  let end = self.current().range.end
  Some(
    @ast.Edge::new(
      @lexer.Range::new(start, end),
      src,
      dst,
      src_arrow,
      dst_arrow,
    ),
  )
}

///|
/// Parse edge group contents and return all the parsed values
/// Returns: (key_path, edges, edge_index, edge_key, value)
fn Parser::parse_edge_group(
  self : Parser,
) -> (
  @ast.KeyPath?,
  Array[@ast.Edge],
  @ast.EdgeIndex?,
  @ast.KeyPath?,
  @ast.Value?,
) {
  let mut key_path : @ast.KeyPath? = None
  let edges : Array[@ast.Edge] = []
  let mut edge_index : @ast.EdgeIndex? = None
  let mut edge_key : @ast.KeyPath? = None
  let mut value : @ast.Value? = None
  self.skip_trivia()
  match self.parse_key_path() {
    Some(kp) => key_path = Some(kp)
    None => {
      self.error("expected key in edge group")
      return (None, edges, None, None, None)
    }
  }
  self.skip_whitespace_not_newline()
  while not(self.is_at_end()) && self.current().is_edge_op() {
    match self.parse_edge(key_path) {
      Some(edge) => {
        let dst = edge.dst
        edges.push(edge)
        key_path = Some(dst) // Keep dst as potential source for next edge in chain
      }
      None => break
    }
    self.skip_whitespace_not_newline()
  }
  // After parsing edges, clear key_path since it was consumed by the edge chain
  if edges.length() > 0 {
    key_path = None
  }
  self.skip_trivia()
  match self.peek() {
    @lexer.RightParen => {
      let _ = self.advance()

    }
    _ => self.error("expected ) to close edge group")
  }
  match self.peek() {
    @lexer.LeftBracket =>
      match self.parse_edge_index() {
        Some(idx) => edge_index = Some(idx)
        None => ()
      }
    _ => ()
  }
  match self.peek() {
    @lexer.Dot => {
      let _ = self.advance()
      match self.parse_key_path() {
        Some(kp) => edge_key = Some(kp)
        None => self.error("expected key path after .")
      }
    }
    _ => ()
  }
  self.skip_whitespace_not_newline()
  match self.peek() {
    @lexer.Colon => {
      let _ = self.advance()
      self.skip_whitespace_not_newline()
      match self.parse_value() {
        Some(val) => value = Some(val)
        None => ()
      }
    }
    @lexer.LeftBrace =>
      match self.parse_block() {
        Some(map) => value = Some(@ast.Value::Map(map))
        None => ()
      }
    _ => ()
  }
  (key_path, edges, edge_index, edge_key, value)
}

///|
fn Parser::parse_edge_index(self : Parser) -> @ast.EdgeIndex? {
  let start = self.current().range.start
  let _ = self.advance() // consume [
  self.skip_trivia()
  let (index, glob) = match self.peek() {
    @lexer.Star => {
      let _ = self.advance()
      (None, true)
    }
    @lexer.Number(num_str) => {
      let _ = self.advance()
      try @strconv.parse_int(num_str) catch {
        _ => {
          self.error("invalid edge index")
          (None, false)
        }
      } noraise {
        i => (Some(i), false)
      }
    }
    _ => {
      self.error("expected number or * in edge index")
      (None, false)
    }
  }
  self.skip_trivia()
  match self.peek() {
    @lexer.RightBracket => {
      let _ = self.advance()

    }
    _ => self.error("expected ] to close edge index")
  }
  let end = self.current().range.end
  Some(@ast.EdgeIndex::new(@lexer.Range::new(start, end), index, glob))
}

///|
fn Parser::parse_value(self : Parser) -> @ast.Value? {
  match self.peek() {
    @lexer.LeftBrace =>
      match self.parse_block() {
        Some(map) => Some(@ast.Value::Map(map))
        None => None
      }
    @lexer.LeftBracket =>
      match self.parse_array() {
        Some(arr) => Some(@ast.Value::Array(arr))
        None => None
      }
    @lexer.At =>
      match self.parse_import(false) {
        Some(imp) => Some(@ast.Value::Import(imp))
        None => None
      }
    @lexer.DotDotDot => {
      // Spread import: ...@path
      let _ = self.advance() // consume ...
      match self.peek() {
        @lexer.At =>
          match self.parse_import(true) {
            Some(imp) => Some(@ast.Value::Import(imp))
            None => None
          }
        _ => {
          self.error("expected @ after ...")
          None
        }
      }
    }
    _ =>
      match self.parse_scalar() {
        Some(s) => Some(@ast.Value::Scalar(s))
        None => None
      }
  }
}

///|
fn Parser::parse_block(self : Parser) -> @ast.Map? {
  let _ = self.advance() // consume {
  let map = self.parse_map(false)
  match self.peek() {
    @lexer.RightBrace => {
      let _ = self.advance()

    }
    _ => self.error("expected } to close block")
  }
  Some(map)
}

///|
fn Parser::parse_array(self : Parser) -> @ast.ArrayValue? {
  let start = self.current().range.start
  let _ = self.advance() // consume [
  let nodes : Array[@ast.ArrayNode] = []
  self.skip_trivia()
  while not(self.is_at_end()) {
    match self.peek() {
      @lexer.RightBracket => break
      @lexer.Comma => {
        let _ = self.advance()
        self.skip_trivia()
        continue
      }
      @lexer.Comment(content) => {
        let token = self.advance()
        nodes.push(@ast.ArrayNode::Comment(token.range, content))
      }
      @lexer.BlockComment(content) => {
        let token = self.advance()
        nodes.push(@ast.ArrayNode::BlockComment(token.range, content))
      }
      @lexer.At =>
        match self.parse_import(false) {
          Some(imp) => nodes.push(@ast.ArrayNode::Import(imp))
          None => break
        }
      @lexer.Dollar | @lexer.DollarBrace =>
        match self.parse_substitution() {
          Some(sub) => nodes.push(@ast.ArrayNode::Substitution(sub))
          None => break
        }
      @lexer.DotDotDot => {
        let dots = self.advance()
        match self.peek() {
          @lexer.At =>
            match self.parse_import(true) {
              Some(imp) => nodes.push(@ast.ArrayNode::Import(imp))
              None => break
            }
          @lexer.Dollar | @lexer.DollarBrace =>
            match self.parse_substitution() {
              Some(sub) =>
                nodes.push(
                  @ast.ArrayNode::Substitution(
                    @ast.Substitution::new(
                      @lexer.Range::between(dots.range, sub.range),
                      true,
                      sub.path,
                    ),
                  ),
                )
              None => break
            }
          _ => {
            self.error("expected @ or $ after ...")
            break
          }
        }
      }
      _ =>
        match self.parse_value() {
          Some(v) => nodes.push(@ast.ArrayNode::Value(v))
          None => {
            self.error("expected value in array")
            break
          }
        }
    }
    self.skip_trivia()
  }
  match self.peek() {
    @lexer.RightBracket => {
      let _ = self.advance()

    }
    _ => self.error("expected ] to close array")
  }
  let end = self.current().range.end
  Some(@ast.ArrayValue::new(@lexer.Range::new(start, end), nodes))
}

///|
fn Parser::parse_scalar(self : Parser) -> @ast.Scalar? {
  match self.peek() {
    @lexer.Ident(name) => {
      let start_token = self.advance()
      if name == "null" {
        Some(@ast.Scalar::Null(start_token.range))
      } else if name == "true" {
        Some(@ast.Scalar::Boolean(start_token.range, true))
      } else if name == "false" {
        Some(@ast.Scalar::Boolean(start_token.range, false))
      } else {
        // Unquoted value may include substitutions, e.g. `pre-${x}-post`.
        // Build interpolation segments using source extraction to preserve spacing.
        let start_pos = start_token.range.start
        let mut end_pos = start_token.range.end
        let mut seg_start = start_pos
        let segs : Array[@ast.Interpolation] = []
        while not(self.is_at_end()) {
          match self.peek() {
            @lexer.Dollar | @lexer.DollarBrace =>
              match self.parse_substitution() {
                Some(sub) => {
                  let pre = self.extract_source(seg_start, sub.range.start)
                  if pre.length() > 0 {
                    segs.push(@ast.Interpolation::Text(pre))
                  }
                  segs.push(@ast.Interpolation::Sub(sub))
                  seg_start = sub.range.end
                  end_pos = sub.range.end
                }
                None => break
              }
            @lexer.Newline
            | @lexer.Comma
            | @lexer.Semicolon
            | @lexer.LeftBrace
            | @lexer.RightBrace
            | @lexer.LeftBracket
            | @lexer.RightBracket => break
            _ => {
              let token = self.advance()
              end_pos = token.range.end
            }
          }
        }
        let post = self.extract_source(seg_start, end_pos)
        if post.length() > 0 {
          segs.push(@ast.Interpolation::Text(post))
        }
        let range = @lexer.Range::new(start_pos, end_pos)
        Some(
          @ast.Scalar::String(
            @ast.StringValue::Unquoted(
              @ast.UnquotedString::new(range, segs, []),
            ),
          ),
        )
      }
    }
    @lexer.Number(n) => {
      let start_token = self.advance()
      // Check if there are more words after the number (e.g., "3D Box")
      // If so, treat as multi-word string, otherwise as number
      match self.peek() {
        @lexer.Ident(_) => {
          // Multi-word value starting with number like "3D Box" (may include substitutions).
          let start_pos = start_token.range.start
          let mut end_pos = start_token.range.end
          let mut seg_start = start_pos
          let segs : Array[@ast.Interpolation] = []
          while not(self.is_at_end()) {
            match self.peek() {
              @lexer.Dollar | @lexer.DollarBrace =>
                match self.parse_substitution() {
                  Some(sub) => {
                    let pre = self.extract_source(seg_start, sub.range.start)
                    if pre.length() > 0 {
                      segs.push(@ast.Interpolation::Text(pre))
                    }
                    segs.push(@ast.Interpolation::Sub(sub))
                    seg_start = sub.range.end
                    end_pos = sub.range.end
                  }
                  None => break
                }
              @lexer.Newline
              | @lexer.Comma
              | @lexer.Semicolon
              | @lexer.LeftBrace
              | @lexer.RightBrace
              | @lexer.LeftBracket
              | @lexer.RightBracket => break
              _ => {
                let token = self.advance()
                end_pos = token.range.end
              }
            }
          }
          let post = self.extract_source(seg_start, end_pos)
          if post.length() > 0 {
            segs.push(@ast.Interpolation::Text(post))
          }
          let range = @lexer.Range::new(start_pos, end_pos)
          Some(
            @ast.Scalar::String(
              @ast.StringValue::Unquoted(
                @ast.UnquotedString::new(range, segs, []),
              ),
            ),
          )
        }
        _ => Some(@ast.Scalar::Number(start_token.range, n))
      }
    }
    @lexer.StringLit(style, content) => {
      let token = self.advance()
      match style {
        @lexer.SingleQuoted =>
          Some(
            @ast.Scalar::String(
              @ast.StringValue::SingleQuoted(token.range, content),
            ),
          )
        @lexer.DoubleQuoted =>
          Some(
            @ast.Scalar::String(
              @ast.StringValue::DoubleQuoted(
                @ast.DoubleQuotedString::new(
                  token.range,
                  parse_double_quoted_interpolations(token.range, content),
                ),
              ),
            ),
          )
      }
    }
    @lexer.Dollar | @lexer.DollarBrace => {
      // An unquoted scalar can start with a substitution and continue with text,
      // e.g. `${x}-b`. Parse the whole token run into interpolation segments.
      let start_pos = self.current().range.start
      let mut end_pos = self.current().range.end
      let mut seg_start = start_pos
      let segs : Array[@ast.Interpolation] = []
      while not(self.is_at_end()) {
        match self.peek() {
          @lexer.Dollar | @lexer.DollarBrace =>
            match self.parse_substitution() {
              Some(sub) => {
                let pre = self.extract_source(seg_start, sub.range.start)
                if pre.length() > 0 {
                  segs.push(@ast.Interpolation::Text(pre))
                }
                segs.push(@ast.Interpolation::Sub(sub))
                seg_start = sub.range.end
                end_pos = sub.range.end
              }
              None => break
            }
          // Stop at any delimiter.
          @lexer.Newline
          | @lexer.Comma
          | @lexer.Semicolon
          | @lexer.LeftBrace
          | @lexer.RightBrace
          | @lexer.LeftBracket
          | @lexer.RightBracket => break
          _ => {
            let token = self.advance()
            end_pos = token.range.end
          }
        }
      }
      let post = self.extract_source(seg_start, end_pos)
      if post.length() > 0 {
        segs.push(@ast.Interpolation::Text(post))
      }
      let range = @lexer.Range::new(start_pos, end_pos)
      Some(
        @ast.Scalar::String(
          @ast.StringValue::Unquoted(@ast.UnquotedString::new(range, segs, [])),
        ),
      )
    }
    _ => None
  }
}

///|
fn parse_double_quoted_interpolations(
  range : @lexer.Range,
  content : String,
) -> Array[@ast.Interpolation] {
  let segs : Array[@ast.Interpolation] = []
  let chars = content.to_array()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '$' {
      // Try ${path} form first.
      if i + 1 < chars.length() && chars[i + 1] == '{' {
        let mut j = i + 2
        let parts : Array[String] = []
        let part_buf = StringBuilder::new()
        let mut ok = false
        while j < chars.length() {
          let cj = chars[j]
          if cj == '}' {
            if part_buf.to_string().length() > 0 {
              parts.push(part_buf.to_string())
            }
            ok = parts.length() > 0
            break
          } else if cj == '.' {
            if part_buf.to_string().length() == 0 {
              ok = false
              break
            }
            parts.push(part_buf.to_string())
            part_buf.reset()
          } else {
            part_buf.write_char(cj)
          }
          j = j + 1
        }
        if ok {
          if buf.to_string().length() > 0 {
            segs.push(@ast.Interpolation::Text(buf.to_string()))
            buf.reset()
          }
          let path : Array[@ast.StringValue] = []
          for p in parts {
            path.push(
              @ast.StringValue::Unquoted(
                @ast.UnquotedString::new(range, [@ast.Interpolation::Text(p)], []),
              ),
            )
          }
          segs.push(
            @ast.Interpolation::Sub(@ast.Substitution::new(range, false, path)),
          )
          // Skip past the closing brace.
          i = j + 1
          continue
        }
      } else if i + 1 < chars.length() && is_ident_start_char(chars[i + 1]) {
        // $var form
        let mut j = i + 1
        let name_buf = StringBuilder::new()
        while j < chars.length() && is_ident_continue_char(chars[j]) {
          name_buf.write_char(chars[j])
          j = j + 1
        }
        if name_buf.to_string().length() > 0 {
          if buf.to_string().length() > 0 {
            segs.push(@ast.Interpolation::Text(buf.to_string()))
            buf.reset()
          }
          let path : Array[@ast.StringValue] = [
            @ast.StringValue::Unquoted(
              @ast.UnquotedString::new(
                range,
                [@ast.Interpolation::Text(name_buf.to_string())],
                [],
              ),
            ),
          ]
          segs.push(
            @ast.Interpolation::Sub(@ast.Substitution::new(range, false, path)),
          )
          i = j
          continue
        }
      }
    }
    buf.write_char(c)
    i = i + 1
  }
  if buf.to_string().length() > 0 || segs.length() == 0 {
    segs.push(@ast.Interpolation::Text(buf.to_string()))
  }
  segs
}

///|
fn is_ident_start_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn is_ident_continue_char(c : Char) -> Bool {
  is_ident_start_char(c) || (c >= '0' && c <= '9') || c == '-'
}

///|
fn Parser::parse_substitution(self : Parser) -> @ast.Substitution? {
  let start = self.current().range.start
  let mut end = self.current().range.end
  let is_brace = match self.peek() {
    @lexer.DollarBrace => {
      let token = self.advance()
      end = token.range.end
      true
    }
    @lexer.Dollar => {
      let token = self.advance()
      end = token.range.end
      false
    }
    _ => return None
  }
  let path : Array[@ast.StringValue] = []
  match self.parse_string_for_key() {
    Some(s) => {
      end = s.range().end
      path.push(s)
    }
    None => {
      self.error("expected variable name after $")
      return None
    }
  }
  if is_brace {
    while not(self.is_at_end()) {
      match self.peek() {
        @lexer.Dot => {
          let dot = self.advance()
          end = dot.range.end
          match self.parse_string_for_key() {
            Some(s) => {
              end = s.range().end
              path.push(s)
            }
            None => {
              self.error("expected identifier after .")
              break
            }
          }
        }
        _ => break
      }
    }
    match self.peek() {
      @lexer.RightBrace => {
        let close = self.advance()
        end = close.range.end
      }
      _ => self.error("expected } to close substitution")
    }
  }
  Some(@ast.Substitution::new(@lexer.Range::new(start, end), false, path))
}

///|
fn Parser::parse_import(self : Parser, spread : Bool) -> @ast.Import? {
  let start = self.current().range.start
  let at = self.advance() // consume @
  let mut end = at.range.end
  let path : Array[@ast.StringValue] = []
  match self.parse_string_for_key() {
    Some(s) => {
      end = s.range().end
      path.push(s)
    }
    None => {
      self.error("expected path after @")
      return None
    }
  }
  while not(self.is_at_end()) {
    match self.peek() {
      @lexer.Dot => {
        let dot = self.advance()
        end = dot.range.end
        match self.parse_string_for_key() {
          Some(s) => {
            end = s.range().end
            path.push(s)
          }
          None => {
            self.error("expected identifier after .")
            break
          }
        }
      }
      _ => break
    }
  }
  Some(@ast.Import::new(@lexer.Range::new(start, end), spread, "", path))
}
