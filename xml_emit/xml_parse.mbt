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
/// Minimal XML parser.
///
/// Intended for internal tooling/tests (e.g. SVG comparisons). This parser is
/// not a fully compliant XML implementation, but supports:
/// - XML declaration and processing instructions
/// - Elements with attributes (quoted or unquoted)
/// - Text nodes (with basic entity decoding)
/// - Comments and CDATA sections

///|
pub enum XmlNode {
  NodeElement(XmlElement)
  NodeText(String)
} derive(Eq, Show)

///|
pub struct XmlElement {
  name : String
  attrs : Map[String, String]
  children : Array[XmlNode]
} derive(Eq, Show)

///|
priv struct Parser {
  s : String
  mut pos : Int
}

///|
fn Parser::new(s : String) -> Parser {
  { s, pos: 0 }
}

///|
fn Parser::eof(self : Parser) -> Bool {
  self.pos >= self.s.length()
}

///|
fn Parser::peek_u16(self : Parser) -> UInt16? {
  if self.eof() {
    None
  } else {
    Some(self.s.code_unit_at(self.pos))
  }
}

///|
fn Parser::peek_char(self : Parser) -> Char? {
  match self.peek_u16() {
    Some(u) => Some(u.to_int().unsafe_to_char())
    None => None
  }
}

///|
fn Parser::eat_char(self : Parser) -> Char? {
  let c = self.peek_char()
  if c is Some(_) {
    self.pos = self.pos + 1
  }
  c
}

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn is_name_char(c : Char) -> Bool {
  let i = c.to_int()
  (i >= 'a'.to_int() && i <= 'z'.to_int()) ||
  (i >= 'A'.to_int() && i <= 'Z'.to_int()) ||
  (i >= '0'.to_int() && i <= '9'.to_int()) ||
  c == '_' ||
  c == '-' ||
  c == ':' ||
  c == '.'
}

///|
fn substring_range(s : String, start : Int, end_ : Int) -> String {
  if start >= end_ {
    return ""
  }
  let buf = StringBuilder::new()
  for i in start..<end_ {
    buf.write_char(s.code_unit_at(i).to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
fn Parser::starts_with(self : Parser, pat : String) -> Bool {
  if self.pos + pat.length() > self.s.length() {
    return false
  }
  let mut i = 0
  while i < pat.length() {
    if self.s.code_unit_at(self.pos + i) != pat.code_unit_at(i) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn Parser::consume(self : Parser, pat : String) -> Bool {
  if self.starts_with(pat) {
    self.pos = self.pos + pat.length()
    true
  } else {
    false
  }
}

///|
fn Parser::skip_ws(self : Parser) -> Unit {
  while true {
    match self.peek_char() {
      Some(c) if is_space(c) => {
        self.pos = self.pos + 1
        continue
      }
      _ => break
    }
  }
}

///|
fn Parser::read_name(self : Parser) -> String? {
  self.skip_ws()
  let start = self.pos
  while true {
    match self.peek_char() {
      Some(c) if is_name_char(c) => {
        self.pos = self.pos + 1
        continue
      }
      _ => break
    }
  }
  if self.pos == start {
    None
  } else {
    Some(substring_range(self.s, start, self.pos))
  }
}

///|
fn Parser::read_until(self : Parser, pat : String) -> String? {
  // Returns text up to (but not including) pat, consuming through pat.
  let start = self.pos
  while self.pos + pat.length() <= self.s.length() {
    if self.starts_with(pat) {
      let out = substring_range(self.s, start, self.pos)
      self.pos = self.pos + pat.length()
      return Some(out)
    }
    self.pos = self.pos + 1
  }
  None
}

///|
fn decode_entities(s : String) -> String {
  // Minimal entity decoding used for text nodes.
  s
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&amp;", new="&")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&#39;", new="'")
}

///|
fn Parser::read_quoted_or_unquoted_value(self : Parser) -> String? {
  self.skip_ws()
  match self.peek_char() {
    Some('"') => {
      self.pos = self.pos + 1
      match self.read_until("\"") {
        Some(v) => Some(v)
        None => None
      }
    }
    Some('\'') => {
      self.pos = self.pos + 1
      match self.read_until("\'") {
        Some(v) => Some(v)
        None => None
      }
    }
    Some(_) => {
      let start = self.pos
      while true {
        match self.peek_char() {
          Some(c) if !(is_space(c) || c == '>' || c == '/') => {
            self.pos = self.pos + 1
            continue
          }
          _ => break
        }
      }
      if self.pos == start {
        None
      } else {
        Some(substring_range(self.s, start, self.pos))
      }
    }
    None => None
  }
}

///|
fn Parser::skip_comment_or_decl(self : Parser) -> Bool {
  if self.consume("<!--") {
    self.read_until("-->") |> ignore
    true
  } else if self.consume("<!DOCTYPE") {
    self.read_until(">") |> ignore
    true
  } else {
    false
  }
}

///|
fn Parser::parse_text(self : Parser) -> String {
  let start = self.pos
  while true {
    match self.peek_char() {
      Some('<') | None => break
      _ => {
        self.pos = self.pos + 1
        continue
      }
    }
  }
  decode_entities(substring_range(self.s, start, self.pos))
}

///|
fn Parser::parse_node(self : Parser) -> XmlNode? {
  self.skip_ws()
  match self.peek_char() {
    None => None
    Some('<') => {
      if self.starts_with("<![CDATA[") {
        self.consume("<![CDATA[") |> ignore
        let content = self.read_until("]]>").unwrap_or("")
        return Some(XmlNode::NodeText(content))
      }
      if self.starts_with("<!--") || self.starts_with("<!DOCTYPE") {
        self.eat_char() |> ignore // '<'
        self.skip_comment_or_decl() |> ignore
        return self.parse_node()
      }
      if self.starts_with("<?") {
        self.consume("<?") |> ignore
        self.read_until("?>") |> ignore
        return self.parse_node()
      }
      // element
      match self.parse_element() {
        Some(el) => Some(XmlNode::NodeElement(el))
        None => None
      }
    }
    Some(_) => {
      let t = self.parse_text()
      if t == "" {
        None
      } else {
        Some(XmlNode::NodeText(t))
      }
    }
  }
}

///|
fn Parser::parse_element(self : Parser) -> XmlElement? {
  if !self.consume("<") {
    return None
  }
  if self.consume("/") {
    // Closing tag should be handled by parent.
    return None
  }
  let name = match self.read_name() {
    Some(n) => n
    None => return None
  }
  let attrs : Map[String, String] = {}
  let children : Array[XmlNode] = []

  // Attributes
  while true {
    self.skip_ws()
    match self.peek_char() {
      Some('/') | Some('>') | None => break
      _ => ()
    }
    let k = match self.read_name() {
      Some(v) => v
      None => break
    }
    self.skip_ws()
    if !self.consume("=") {
      // Boolean attribute
      attrs[k] = ""
      continue
    }
    let v = match self.read_quoted_or_unquoted_value() {
      Some(v) => v
      None => return None
    }
    attrs[k] = v
  }
  self.skip_ws()
  if self.consume("/>") {
    return Some({ name, attrs, children })
  }
  if !self.consume(">") {
    return None
  }

  // Children
  while true {
    self.skip_ws()
    if self.starts_with("</") {
      self.consume("</") |> ignore
      self.read_name() |> ignore
      self.skip_ws()
      self.consume(">") |> ignore
      break
    }
    match self.parse_node() {
      Some(n) => children.push(n)
      None => break
    }
  }
  Some({ name, attrs, children })
}

///|
/// Parse XML and return the first element node.
///
/// This is intentionally forgiving and will skip leading XML declarations,
/// comments, and whitespace.
pub fn parse(xml : String) -> Result[XmlElement, String] {
  let p = Parser::new(xml)

  // Skip XML declaration if present
  p.skip_ws()
  if p.starts_with("<?xml") {
    p.consume("<?") |> ignore
    p.read_until("?>") |> ignore
  }
  while true {
    match p.parse_node() {
      Some(XmlNode::NodeElement(el)) => return Ok(el)
      Some(_) => continue
      None => break
    }
  }
  Err("no root element")
}
