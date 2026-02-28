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
  mut depth : Int
  mut in_edge_group : Bool
  mut in_array : Bool
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
  {
    source,
    tokens,
    pos: 0,
    depth: 0,
    in_edge_group: false,
    in_array: false,
    errors: ParseErrors::new(),
  }
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
  if not(is_file_map) {
    self.depth += 1
  }
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
  let map = @ast.Map::new(@lexer.Range::new(start, end), nodes)
  if not(is_file_map) {
    self.depth -= 1
  }
  map
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

fn is_unquoted_string_value(s : @ast.StringValue) -> Bool {
  match s {
    @ast.StringValue::Unquoted(_) => true
    _ => false
  }
}

///|
fn Parser::parse_key(self : Parser) -> @ast.Key? {
  let start = self.current().range.start

  // Collect all the values we need for Key::new
  let mut ampersand = false
  let mut not_ampersand = false
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
    @lexer.Ident(text) =>
      if text == "!" && self.pos + 1 < self.tokens.length() {
        match self.tokens[self.pos + 1].kind {
          @lexer.Ampersand => {
            let _ = self.advance() // consume !
            let _ = self.advance() // consume &
            not_ampersand = true
          }
          _ => ()
        }
      } else {
        ()
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
          None => break
        }
      }
      _ => break
    }
  }
  let end = self.current().range.end
  for part in path {
    if part.content().length() > 518 {
      self.error(
        "key length \{part.content().length()} exceeds maximum allowed length of 518",
      )
      break
    }
  }
  Some(@ast.KeyPath::new(@lexer.Range::new(start, end), path))
}

///|
fn Parser::parse_string_for_key(self : Parser) -> @ast.StringValue? {
  match self.peek() {
    @lexer.StringLit(style, content) => {
      let token = self.advance()
      return match style {
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
    _ => ()
  }

  if self.is_key_segment_delimiter() {
    return None
  }

  let start = self.current().range.start
  let mut end = start
  let mut consumed = false
  while not(self.is_at_end()) && not(self.is_key_segment_delimiter()) {
    let token = self.advance()
    consumed = true
    end = token.range.end
  }
  if not(consumed) {
    return None
  }

  let text = trim_right_ws(self.extract_source(start, end))
  if text.length() == 0 {
    return None
  }

  let range = @lexer.Range::new(start, end)
  Some(
    @ast.StringValue::Unquoted(
      @ast.UnquotedString::new(
        range,
        [@ast.Interpolation::Text(text)],
        key_glob_pattern_from_text(text),
      ),
    ),
  )
}

///|
fn Parser::is_key_segment_delimiter(self : Parser) -> Bool {
  match self.peek() {
    @lexer.Newline
    | @lexer.Semicolon
    | @lexer.Comma
    | @lexer.Colon
    | @lexer.Dot
    | @lexer.LeftBrace
    | @lexer.RightBrace
    | @lexer.LeftBracket
    | @lexer.RightBracket
    | @lexer.Arrow
    | @lexer.ReverseArrow
    | @lexer.BidirectionalArrow
    | @lexer.DoubleDash
    | @lexer.Ampersand
    | @lexer.Comment(_)
    | @lexer.BlockComment(_)
    | @lexer.Eof => true
    @lexer.RightParen => self.in_edge_group
    _ => false
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
  let mut src_arrow = ""
  let mut dst_arrow = ""
  match self.peek() {
    @lexer.Arrow => {
      let _ = self.advance()
      dst_arrow = ">"
    }
    @lexer.ReverseArrow => {
      let _ = self.advance()
      src_arrow = "<"
    }
    @lexer.BidirectionalArrow => {
      let _ = self.advance()
      src_arrow = "<"
      dst_arrow = ">"
    }
    @lexer.DoubleDash => {
      let _ = self.advance()
    }
    _ => return None
  }
  self.skip_whitespace_not_newline()
  // Support d2-style edge operator line continuation:
  // src --\
  //   -> dst
  while not(self.is_at_end()) {
    match self.peek() {
      @lexer.Ident(text) =>
        if text == "\\" && self.pos + 1 < self.tokens.length() {
          match self.tokens[self.pos + 1].kind {
            @lexer.Newline => {
              let _ = self.advance() // consume "\"
              let _ = self.advance() // consume newline
              self.skip_trivia()
              if self.is_at_end() {
                break
              }
              if self.current().is_edge_op() {
                match self.peek() {
                  @lexer.Arrow => dst_arrow = ">"
                  @lexer.ReverseArrow => src_arrow = "<"
                  @lexer.BidirectionalArrow => {
                    src_arrow = "<"
                    dst_arrow = ">"
                  }
                  @lexer.DoubleDash => ()
                  _ => ()
                }
                let _ = self.advance()
                self.skip_whitespace_not_newline()
                continue
              } else {
                self.skip_whitespace_not_newline()
                continue
              }
            }
            _ => break
          }
        } else {
          break
        }
      _ => break
    }
  }
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
  let prev_in_edge_group = self.in_edge_group
  self.in_edge_group = true
  self.skip_trivia()
  match self.parse_key_path() {
    Some(kp) => key_path = Some(kp)
    None => {
      self.error("expected key in edge group")
      self.in_edge_group = prev_in_edge_group
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
  self.in_edge_group = prev_in_edge_group
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
  let prev_in_array = self.in_array
  self.in_array = true
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
  self.in_array = prev_in_array
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
            @lexer.Comma =>
              if self.in_array {
                break
              } else {
                let token = self.advance()
                end_pos = token.range.end
              }
            @lexer.Newline
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
              @lexer.Comma =>
                if self.in_array {
                  break
                } else {
                  let token = self.advance()
                  end_pos = token.range.end
                }
              @lexer.Newline
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
    @lexer.Star => {
      let token = self.advance()
      Some(
        @ast.Scalar::String(
          @ast.StringValue::Unquoted(
            @ast.UnquotedString::new(
              token.range,
              [@ast.Interpolation::Text("*")],
              ["*"],
            ),
          ),
        ),
      )
    }
    @lexer.DoubleStar => {
      let token = self.advance()
      Some(
        @ast.Scalar::String(
          @ast.StringValue::Unquoted(
            @ast.UnquotedString::new(
              token.range,
              [@ast.Interpolation::Text("**")],
              ["*", "", "*"],
            ),
          ),
        ),
      )
    }
    @lexer.TripleStar => {
      let token = self.advance()
      Some(
        @ast.Scalar::String(
          @ast.StringValue::Unquoted(
            @ast.UnquotedString::new(
              token.range,
              [@ast.Interpolation::Text("***")],
              ["*", "", "*", "", "*"],
            ),
          ),
        ),
      )
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
          @lexer.Comma =>
            if self.in_array {
              break
            } else {
              let token = self.advance()
              end_pos = token.range.end
            }
          // Stop at any delimiter.
          @lexer.Newline
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
    @lexer.Pipe =>
      match self.parse_block_string() {
        Some(bs) => Some(@ast.Scalar::String(@ast.StringValue::Block(bs)))
        None => None
      }
    _ => self.parse_unquoted_scalar_run()
  }
}

///|
fn Parser::parse_unquoted_scalar_run(self : Parser) -> @ast.Scalar? {
  match self.peek() {
    @lexer.DotDotDot =>
      if self.pos + 1 < self.tokens.length() {
        match self.tokens[self.pos + 1].kind {
          @lexer.At =>
            self.error(
              "unquoted strings cannot begin with ...@ as that's import spread syntax",
            )
          _ => ()
        }
      } else {
        ()
      }
    _ => ()
  }
  let start_pos = self.current().range.start
  let mut end_pos = start_pos
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
      @lexer.Comma =>
        if self.in_array {
          break
        } else {
          let token = self.advance()
          end_pos = token.range.end
        }
      @lexer.Newline
      | @lexer.Semicolon
      | @lexer.LeftBrace
      | @lexer.RightBrace
      | @lexer.LeftBracket
      | @lexer.RightBracket
      | @lexer.Comment(_)
      | @lexer.BlockComment(_) => break
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
  if segs.length() == 0 {
    return None
  }

  let range = @lexer.Range::new(start_pos, end_pos)
  Some(
    @ast.Scalar::String(
      @ast.StringValue::Unquoted(@ast.UnquotedString::new(range, segs, [])),
    ),
  )
}

///|
fn Parser::parse_block_string(self : Parser) -> @ast.BlockString? {
  // Ported from ../d2/d2parser/parse.go:parseBlockString (adapted to token-based parsing).
  let pipe = self.advance() // consume '|'
  let start = pipe.range.start
  let path = pipe.range.path
  self.depth += 1
  let chars = self.source.to_array()
  let mut i = start.offset + 1

  // Parse quote symbols (non-whitespace, non-[a-zA-Z0-9_]).
  let quote_buf = StringBuilder::new()
  while i < chars.length() {
    let c = chars[i]
    if is_block_string_tag_char(c) || is_block_string_space(c) {
      break
    }
    quote_buf.write_char(c)
    i = i + 1
  }
  let quote = quote_buf.to_string()

  // Parse tag (until whitespace).
  let tag_buf = StringBuilder::new()
  while i < chars.length() {
    let c = chars[i]
    if is_block_string_space(c) {
      break
    }
    tag_buf.write_char(c)
    i = i + 1
  }
  let mut tag = tag_buf.to_string()
  if tag.length() == 0 {
    tag = "md"
  }

  // Skip whitespace until newline. If we see non-whitespace before newline, it has an implicit indent.
  let mut implicit_indent = ""
  while i < chars.length() {
    let c = chars[i]
    if not(is_block_string_space(c)) {
      implicit_indent = self.get_indent()
      break
    }
    i = i + 1
    if c == '\n' {
      break
    }
  }
  let content_start = i

  // Find terminator: quote + "|"
  let end_marker = quote + "|"
  let marker_chars = end_marker.to_array()
  let mut close_start = -1
  let mut j = content_start
  while j + marker_chars.length() <= chars.length() {
    if starts_with_chars(chars, j, marker_chars) {
      close_start = j
      break
    }
    j = j + 1
  }
  if close_start < 0 {
    self.errors.add(
      pipe.range,
      "block string must be terminated with \{quote}|",
    )
    self.depth -= 1
    return None
  }
  let close_end = close_start + marker_chars.length()

  // Advance token cursor through the terminator (but not beyond it).
  let mut end_pos = pipe.range.end
  while not(self.is_at_end()) && self.current().range.end.offset <= close_end {
    let t = self.advance()
    end_pos = t.range.end
  }

  // Extract raw content and apply d2 trimming rules.
  let mut value = substring_by_offsets(self.source, content_start, close_start)
  if implicit_indent.length() > 0 {
    value = implicit_indent + value
  }
  value = trim_common_indent(trim_space_after_last_newline(value))
  self.depth -= 1
  Some(
    @ast.BlockString::new(
      @lexer.Range::with_path(path, start, end_pos),
      quote,
      tag,
      value,
    ),
  )
}

///|
fn Parser::get_indent(self : Parser) -> String {
  let buf = StringBuilder::new()
  let n = self.depth * 2
  let mut i = 0
  while i < n {
    buf.write_char(' ')
    i = i + 1
  }
  buf.to_string()
}

///|
fn is_block_string_tag_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}

///|
fn is_block_string_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn starts_with_chars(hay : Array[Char], at : Int, needle : Array[Char]) -> Bool {
  let mut i = 0
  while i < needle.length() {
    if at + i >= hay.length() || hay[at + i] != needle[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn substring_by_offsets(s : String, start : Int, end : Int) -> String {
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
fn trim_space_after_last_newline(s : String) -> String {
  let chars = s.to_array()
  let mut last_nl = -1
  for i, c in chars {
    if c == '\n' {
      last_nl = i
    }
  }
  if last_nl < 0 {
    return trim_right_ws(s)
  }
  let last_line = substring_by_offsets(s, last_nl + 1, chars.length())
  let trimmed_last_line = trim_right_ws(last_line)
  if trimmed_last_line.length() == 0 {
    return substring_by_offsets(s, 0, last_nl)
  }
  substring_by_offsets(s, 0, last_nl + 1) + trimmed_last_line
}

///|
fn trim_right_ws(s : String) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 {
    let c = chars[end - 1]
    if is_block_string_space(c) {
      end = end - 1
      continue
    }
    break
  }
  substring_by_offsets(s, 0, end)
}

///|
fn key_glob_pattern_from_text(s : String) -> Array[String] {
  if s == "*" {
    return ["*"]
  }
  if s == "**" {
    return ["*", "", "*"]
  }
  if s == "***" {
    return ["*", "", "*", "", "*"]
  }

  let chars = s.to_array()
  let mut has_star = false
  let pattern : Array[String] = []
  let part = StringBuilder::new()
  for c in chars {
    if c == '*' {
      has_star = true
      let p = part.to_string()
      if p.length() > 0 {
        pattern.push(p)
        part.reset()
      }
      pattern.push("*")
    } else {
      part.write_char(c)
    }
  }
  let tail = part.to_string()
  if tail.length() > 0 {
    pattern.push(tail)
  }
  if has_star {
    pattern
  } else {
    []
  }
}

///|
fn trim_common_indent(s : String) -> String {
  let lines = split_lines(s)
  let mut common = ""
  for l in lines {
    if l.length() == 0 {
      continue
    }
    let (indent, rest) = split_leading_indent(l, -1)
    if indent.length() == 0 {
      return s
    }
    if rest.length() == 0 {
      continue
    }
    if common.length() == 0 || indent.length() < common.length() {
      common = indent
    }
  }
  if common.length() == 0 {
    return s
  }
  trim_indent(s, common)
}

///|
fn trim_indent(s : String, indent : String) -> String {
  let lines = split_lines(s)
  let out : Array[String] = []
  for l in lines {
    if l.length() == 0 {
      out.push(l)
      continue
    }
    let (_, rest) = split_leading_indent(l, indent.length())
    out.push(rest)
  }
  join_lines(out)
}

///|
fn split_lines(s : String) -> Array[String] {
  let chars = s.to_array()
  let out : Array[String] = []
  let mut start = 0
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\n' {
      out.push(substring_by_offsets(s, start, i))
      start = i + 1
    }
    i = i + 1
  }
  out.push(substring_by_offsets(s, start, chars.length()))
  out
}

///|
fn join_lines(lines : Array[String]) -> String {
  let buf = StringBuilder::new()
  for i, l in lines {
    if i > 0 {
      buf.write_char('\n')
    }
    buf.write_string(l)
  }
  buf.to_string()
}

///|
fn split_leading_indent(s : String, max_spaces : Int) -> (String, String) {
  let chars = s.to_array()
  let indent_buf = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if not(is_block_string_space(c)) {
      break
    }
    i = i + 1
    if c != '\t' {
      indent_buf.write_char(c)
    } else {
      indent_buf.write_char(' ')
      indent_buf.write_char(' ')
    }
    if max_spaces > -1 && indent_buf.to_string().length() == max_spaces {
      break
    }
  }
  (indent_buf.to_string(), substring_by_offsets(s, i, chars.length()))
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
  let first_segment = if is_brace {
    self.parse_string_for_key()
  } else {
    self.parse_substitution_segment()
  }
  match first_segment {
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
fn Parser::parse_substitution_segment(self : Parser) -> @ast.StringValue? {
  match self.peek() {
    @lexer.StringLit(style, content) => {
      let token = self.advance()
      return match style {
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
    _ => ()
  }

  if self.is_key_segment_delimiter() {
    return None
  }
  let token = self.advance()
  let text = trim_right_ws(
    self.extract_source(token.range.start, token.range.end),
  )
  if text.length() == 0 {
    return None
  }
  Some(
    @ast.StringValue::Unquoted(
      @ast.UnquotedString::new(
        token.range,
        [@ast.Interpolation::Text(text)],
        key_glob_pattern_from_text(text),
      ),
    ),
  )
}

///|
fn Parser::parse_import(self : Parser, spread : Bool) -> @ast.Import? {
  let start = self.current().range.start
  let at = self.advance() // consume @
  let mut end = at.range.end
  let (pre, first_segment_trim) = self.parse_import_pre()
  let path : Array[@ast.StringValue] = []
  match self.parse_string_for_key() {
    Some(raw_first) => {
      let first = if first_segment_trim > 0 {
        trim_import_first_segment(raw_first, first_segment_trim)
      } else {
        raw_first
      }
      end = first.range().end
      path.push(first)
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
  if path.length() > 1 &&
    is_unquoted_string_value(path[0]) &&
    is_unquoted_string_value(path[1]) &&
    path[1].content() == "d2" {
    let compact : Array[@ast.StringValue] = [path[0]]
    for i = 2; i < path.length(); i = i + 1 {
      compact.push(path[i])
    }
    return Some(
      @ast.Import::new(@lexer.Range::new(start, end), spread, pre, compact),
    )
  }
  Some(@ast.Import::new(@lexer.Range::new(start, end), spread, pre, path))
}

///|
fn Parser::parse_import_pre(self : Parser) -> (String, Int) {
  if self.is_at_end() {
    return ("", 0)
  }
  let token = self.current()
  let start_offset = token.range.start.offset
  let chars = self.source.to_array()
  let mut offset = start_offset
  while offset < chars.length() {
    let c = chars[offset]
    if c == '.' || c == '/' {
      offset = offset + 1
    } else {
      break
    }
  }
  if offset == start_offset {
    return ("", 0)
  }
  while !self.is_at_end() && self.current().range.end.offset <= offset {
    let _ = self.advance()
  }
  let first_trim = if !self.is_at_end() &&
    self.current().range.start.offset < offset {
    offset - self.current().range.start.offset
  } else {
    0
  }
  (substring_by_offsets(self.source, start_offset, offset), first_trim)
}

///|
fn trim_import_first_segment(
  value : @ast.StringValue,
  trim_chars : Int,
) -> @ast.StringValue {
  if trim_chars <= 0 {
    return value
  }
  match value {
    @ast.StringValue::Unquoted(s) => {
      let raw = s.to_string()
      let chars = raw.to_array()
      if trim_chars >= chars.length() {
        return value
      }
      let trimmed = substring_by_offsets(raw, trim_chars, chars.length())
      @ast.StringValue::Unquoted(
        @ast.UnquotedString::new(
          s.range,
          [@ast.Interpolation::Text(trimmed)],
          key_glob_pattern_from_text(trimmed),
        ),
      )
    }
    _ => value
  }
}
