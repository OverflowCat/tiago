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
/// diago Source Code Formatter (ported from upstream reference d2format)

///|
pub struct FormatConfig {
  indent : String
  max_width : Int
}

///|
pub fn FormatConfig::new() -> FormatConfig {
  { indent: "  ", max_width: 80 }
}

///|
priv struct Printer {
  sb : StringBuilder
  config : FormatConfig
  mut indent_level : Int
  mut in_key : Bool
}

///|
pub fn format(ast : @ast.Map, config : FormatConfig) -> String {
  let p = { sb: StringBuilder::new(), config, indent_level: 0, in_key: false }
  p.format_map(ast, true)
  p.sb.to_string()
}

///|
fn Printer::write_indent(self : Printer) -> Unit {
  for _ in 0..<self.indent_level {
    self.sb.write_string(self.config.indent)
  }
}

///|
fn Printer::newline(self : Printer) -> Unit {
  self.sb.write_char('\n')
  self.write_indent()
}

///|
fn range_is_one_line(r : @lexer.Range) -> Bool {
  r.start.line == r.end.line
}

///|
fn is_board_node(n : @ast.MapNode) -> Bool {
  match n {
    @ast.MapNode::Key(k) =>
      match (k.key, k.value) {
        (Some(kp), Some(@ast.Value::Map(m))) =>
          if kp.path.length() == 0 || m.nodes.length() == 0 {
            false
          } else {
            let board_type = kp.path[0].content()
            board_type == "layers" ||
            board_type == "scenarios" ||
            board_type == "steps"
          }
        _ => false
      }
    _ => false
  }
}

///|
fn is_comment_map_node(n : @ast.MapNode) -> Bool {
  match n {
    @ast.MapNode::Comment(_, _) | @ast.MapNode::BlockComment(_, _) => true
    _ => false
  }
}

///|
fn is_comment_array_node(n : @ast.ArrayNode) -> Bool {
  match n {
    @ast.ArrayNode::Comment(_, _) | @ast.ArrayNode::BlockComment(_, _) => true
    _ => false
  }
}

///|
fn Printer::format_map(
  self : Printer,
  m : @ast.Map,
  is_file_map : Bool,
) -> Unit {
  let multiline = !range_is_one_line(m.range)
  if !is_file_map {
    self.sb.write_char('{')
    if multiline {
      self.indent_level = self.indent_level + 1
    }
  }

  let board_nodes : Array[@ast.MapNode] = []
  let mut prev_range : @lexer.Range? = None
  for i, nb in m.nodes {
    if is_board_node(nb) {
      board_nodes.push(nb)
      prev_range = Some(nb.range())
      continue
    }

    let nr = nb.range()
    let inline_comment = i > 0 &&
      is_comment_map_node(nb) &&
      range_is_one_line(nr) &&
      (match prev_range {
        Some(pr) => nr.start.line == pr.end.line
        None => false
      })
    if inline_comment {
      self.sb.write_char(' ')
      self.format_map_node(nb)
      prev_range = Some(nr)
      continue
    }

    if multiline {
      match prev_range {
        Some(pr) =>
          if nr.start.line - pr.end.line > 1 {
            self.sb.write_char('\n')
          } else {
            ()
          }
        None => ()
      }
      if !is_file_map || i > 0 {
        self.newline()
      }
    } else if i > 0 {
      self.sb.write_string("; ")
    }

    self.format_map_node(nb)
    prev_range = Some(nr)
  }

  for i, bn in board_nodes {
    let br = bn.range()
    if br.start.line != 0 {
      self.sb.write_char('\n')
    }
    if i != 0 || m.nodes.length() > board_nodes.length() {
      self.sb.write_char('\n')
    }
    self.write_indent()
    self.format_map_node(bn)
  }

  if !is_file_map {
    if multiline {
      self.indent_level = self.indent_level - 1
      self.newline()
    }
    self.sb.write_char('}')
  } else if m.nodes.length() > 0 {
    self.sb.write_char('\n')
  }
}

///|
fn Printer::format_map_node(self : Printer, n : @ast.MapNode) -> Unit {
  match n {
    @ast.MapNode::Comment(_, text) => self.format_comment(text)
    @ast.MapNode::BlockComment(r, text) => self.format_block_comment(r, text)
    @ast.MapNode::Substitution(sub) => self.format_substitution(sub)
    @ast.MapNode::Import(imp) => self.format_import(imp)
    @ast.MapNode::Key(key) => self.format_key(key)
  }
}

///|
fn Printer::format_array_node(self : Printer, n : @ast.ArrayNode) -> Unit {
  match n {
    @ast.ArrayNode::Comment(_, text) => self.format_comment(text)
    @ast.ArrayNode::BlockComment(r, text) => self.format_block_comment(r, text)
    @ast.ArrayNode::Substitution(sub) => self.format_substitution(sub)
    @ast.ArrayNode::Import(imp) => self.format_import(imp)
    @ast.ArrayNode::Value(v) => self.format_value(v)
  }
}

///|
fn Printer::format_comment(self : Printer, text : String) -> Unit {
  let lines = split_by_newline(text)
  for i, line in lines {
    self.sb.write_char('#')
    if line != "" {
      self.sb.write_char(' ')
    }
    self.sb.write_string(line)
    if i < lines.length() - 1 {
      self.newline()
    }
  }
}

///|
fn Printer::format_block_comment(
  self : Printer,
  r : @lexer.Range,
  text : String,
) -> Unit {
  self.sb.write_string("\"\"\"")
  if range_is_one_line(r) {
    self.sb.write_char(' ')
  }
  let lines = split_by_newline(text)
  for line in lines {
    if !range_is_one_line(r) {
      if line == "" {
        self.sb.write_char('\n')
      } else {
        self.newline()
      }
    }
    self.sb.write_string(line)
  }
  if !range_is_one_line(r) {
    self.newline()
  } else {
    self.sb.write_char(' ')
  }
  self.sb.write_string("\"\"\"")
}

///|
fn Printer::format_key(self : Printer, k : @ast.Key) -> Unit {
  if k.ampersand {
    self.sb.write_char('&')
  } else if k.not_ampersand {
    self.sb.write_char('!')
    self.sb.write_char('&')
  }

  match k.key {
    Some(kp) => self.format_key_path(kp)
    None => ()
  }

  if k.edges.length() > 0 {
    if k.key is Some(_) {
      self.sb.write_char('.')
    }
    if k.key is Some(_) || k.edge_index is Some(_) || k.edge_key is Some(_) {
      self.sb.write_char('(')
    }

    if k.edges[0].src.path.length() > 0 {
      self.format_key_path(k.edges[0].src)
      self.sb.write_char(' ')
    }
    for i, e in k.edges {
      self.format_edge_arrow_and_dst(e)
      if i < k.edges.length() - 1 {
        self.sb.write_char(' ')
      }
    }

    if k.key is Some(_) || k.edge_index is Some(_) || k.edge_key is Some(_) {
      self.sb.write_char(')')
    }

    match k.edge_index {
      Some(idx) => self.format_edge_index(idx)
      None => ()
    }
    match k.edge_key {
      Some(ek) => {
        self.sb.write_char('.')
        self.format_key_path(ek)
      }
      None => ()
    }
  }

  match k.primary {
    Some(primary) => {
      self.sb.write_string(": ")
      self.format_scalar(primary)
    }
    None => ()
  }

  if k.value is Some(@ast.Value::Map(m)) && m.nodes.length() == 0 {
    return
  }
  match k.value {
    Some(v) => {
      if k.primary is None {
        self.sb.write_string(": ")
      } else {
        self.sb.write_char(' ')
      }
      self.format_value(v)
    }
    None => ()
  }
}

///|
fn Printer::format_value(self : Printer, v : @ast.Value) -> Unit {
  match v {
    @ast.Value::Scalar(s) => self.format_scalar(s)
    @ast.Value::Array(a) => self.format_array(a)
    @ast.Value::Map(m) => self.format_map(m, false)
    @ast.Value::Import(i) => self.format_import(i)
    @ast.Value::BlockScalar(label, m) => {
      self.format_value(label)
      self.sb.write_char(' ')
      self.format_map(m, false)
    }
  }
}

///|
fn Printer::format_array(self : Printer, a : @ast.ArrayValue) -> Unit {
  let multiline = !range_is_one_line(a.range)
  self.sb.write_char('[')
  if multiline {
    self.indent_level = self.indent_level + 1
  }

  let mut prev_range : @lexer.Range? = None
  for i, nb in a.nodes {
    let nr = nb.range()
    let inline_comment = i > 0 &&
      is_comment_array_node(nb) &&
      range_is_one_line(nr) &&
      (match prev_range {
        Some(pr) => nr.start.line == pr.end.line
        None => false
      })
    if inline_comment {
      self.sb.write_char(' ')
      self.format_array_node(nb)
      prev_range = Some(nr)
      continue
    }

    if multiline {
      match prev_range {
        Some(pr) =>
          if nr.start.line - pr.end.line > 1 {
            self.sb.write_char('\n')
          } else {
            ()
          }
        None => ()
      }
      self.newline()
    } else if i > 0 {
      self.sb.write_string("; ")
    }

    self.format_array_node(nb)
    prev_range = Some(nr)
  }

  if multiline {
    self.indent_level = self.indent_level - 1
    self.newline()
  }
  self.sb.write_char(']')
}

///|
fn Printer::format_scalar(self : Printer, scalar : @ast.Scalar) -> Unit {
  match scalar {
    @ast.Scalar::Null(_) => self.sb.write_string("null")
    @ast.Scalar::Boolean(_, b) =>
      self.sb.write_string(if b { "true" } else { "false" })
    @ast.Scalar::Number(_, raw) => self.sb.write_string(raw)
    @ast.Scalar::String(s) => self.format_string_value(s)
  }
}

///|
fn Printer::format_string_value(self : Printer, s : @ast.StringValue) -> Unit {
  match s {
    @ast.StringValue::Unquoted(u) => self.format_interpolations(u.value, false)
    @ast.StringValue::DoubleQuoted(dq) => {
      self.sb.write_char('"')
      self.format_interpolations(dq.value, true)
      self.sb.write_char('"')
    }
    @ast.StringValue::SingleQuoted(_, v) => {
      self.sb.write_char('\'')
      self.sb.write_string(escape_single_quoted_value(v))
      self.sb.write_char('\'')
    }
    @ast.StringValue::Block(bs) => self.format_block_string(bs)
  }
}

///|
fn Printer::format_interpolations(
  self : Printer,
  boxes : Array[@ast.Interpolation],
  is_double_string : Bool,
) -> Unit {
  for box in boxes {
    match box {
      @ast.Interpolation::Sub(sub) => self.format_substitution(sub)
      @ast.Interpolation::Text(text) => {
        let mut raw = if is_double_string {
          escape_double_quoted_value(text, self.in_key)
        } else {
          escape_unquoted_value(text, self.in_key)
        }
        if !is_double_string && is_reserved_for_unquoted(raw) {
          raw = raw.to_lower()
        }
        self.sb.write_string(raw)
      }
    }
  }
}

///|
fn Printer::format_block_string(self : Printer, bs : @ast.BlockString) -> Unit {
  let mut quote = bs.quote
  while bs.value.contains("|" + quote) {
    if quote == "" {
      quote = quote + "|"
    } else {
      let chars = quote.to_array()
      quote = quote + chars[chars.length() - 1].to_string()
    }
  }
  while bs.value.contains(quote + "|") {
    let chars = quote.to_array()
    quote = quote + chars[chars.length() - 1].to_string()
  }

  self.sb.write_string("|")
  self.sb.write_string(quote)
  self.sb.write_string(bs.tag)
  if !range_is_one_line(bs.range) {
    self.indent_level = self.indent_level + 1
  } else {
    self.sb.write_char(' ')
  }

  let lines = split_by_newline(bs.value)
  for line in lines {
    if !range_is_one_line(bs.range) {
      if line == "" {
        self.sb.write_char('\n')
      } else {
        self.newline()
      }
    }
    self.sb.write_string(line)
  }

  if !range_is_one_line(bs.range) {
    self.indent_level = self.indent_level - 1
    self.newline()
  } else if bs.value != "" {
    self.sb.write_char(' ')
  }
  self.sb.write_string(quote)
  self.sb.write_char('|')
}

///|
fn Printer::format_key_path(self : Printer, kp : @ast.KeyPath) -> Unit {
  self.in_key = true
  for i, p in kp.path {
    self.format_string_value(p)
    if i < kp.path.length() - 1 {
      self.sb.write_char('.')
    }
  }
  self.in_key = false
}

///|
fn Printer::format_edge_arrow_and_dst(self : Printer, e : @ast.Edge) -> Unit {
  if e.src_arrow == "" {
    self.sb.write_char('-')
  } else {
    self.sb.write_string(e.src_arrow)
  }
  if e.dst_arrow == "" {
    self.sb.write_char('-')
  } else {
    if e.src_arrow != "" {
      self.sb.write_char('-')
    }
    self.sb.write_string(e.dst_arrow)
  }
  if e.dst.path.length() > 0 {
    self.sb.write_char(' ')
    self.format_key_path(e.dst)
  }
}

///|
fn Printer::format_edge_index(self : Printer, idx : @ast.EdgeIndex) -> Unit {
  self.sb.write_char('[')
  if idx.glob {
    self.sb.write_char('*')
  } else {
    match idx.index {
      Some(i) => self.sb.write_string(i.to_string())
      None => ()
    }
  }
  self.sb.write_char(']')
}

///|
fn Printer::format_substitution(
  self : Printer,
  sub : @ast.Substitution,
) -> Unit {
  if sub.spread {
    self.sb.write_string("...")
  }
  self.sb.write_string("${")
  for i, p in sub.path {
    self.format_string_value(p)
    if i < sub.path.length() - 1 {
      self.sb.write_char('.')
    }
  }
  self.sb.write_char('}')
}

///|
fn Printer::format_import(self : Printer, imp : @ast.Import) -> Unit {
  if imp.spread {
    self.sb.write_string("...")
  }
  self.sb.write_char('@')
  if imp.pre != "" {
    self.sb.write_string(imp.pre)
  }
  if imp.path.length() > 0 && imp.pre != "" && !imp.pre.has_suffix("/") {
    self.sb.write_char('/')
  }
  for i, p in imp.path {
    self.format_string_value(p)
    if i < imp.path.length() - 1 {
      self.sb.write_char('/')
    }
  }
}

///|
fn escape_single_quoted_value(s : String) -> String {
  let b = StringBuilder::new()
  for r in s {
    match r {
      '\'' => b.write_char('\'')
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
        continue
      }
      _ => ()
    }
    b.write_char(r)
  }
  b.to_string()
}

///|
fn escape_double_quoted_value(s : String, in_key : Bool) -> String {
  let b = StringBuilder::new()
  for r in s {
    match r {
      '"' | '\\' => b.write_char('\\')
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
        continue
      }
      _ => ()
    }
    if !in_key && r == '$' {
      b.write_char('\\')
    }
    b.write_char(r)
  }
  b.to_string()
}

///|
fn escape_unquoted_value(s : String, in_key : Bool) -> String {
  if s.length() == 0 {
    return "\"\""
  }
  if s.to_lower() == "null" {
    return "'null'"
  }
  let key_specials = "#;\n\\{}[]'\"|:.-<>*&()@&"
  let value_specials = "#;\n\\{}[]'\"|$@"
  let chars = s.to_array()
  let b = StringBuilder::new()
  for i, r in chars {
    match r {
      '\'' | '"' | '|' => if i == 0 { b.write_char('\\') } else { () }
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
        continue
      }
      _ =>
        if in_key {
          if r == '-' {
            if i + 1 < chars.length() && chars[i + 1] == '-' {
              b.write_char('\\')
            }
          } else if r == '&' {
            if i == 0 {
              b.write_char('\\')
            }
          } else if string_contains_char(key_specials, r) {
            b.write_char('\\')
          }
        } else if string_contains_char(value_specials, r) {
          b.write_char('\\')
        }
    }
    b.write_char(r)
  }
  b.to_string()
}

///|
fn string_contains_char(s : String, target : Char) -> Bool {
  for c in s {
    if c == target {
      return true
    }
  }
  false
}

///|
fn is_reserved_for_unquoted(s : String) -> Bool {
  let lower = s.to_lower()
  lower == "null" ||
  lower == "suspend" ||
  lower == "unsuspend" ||
  @ast.is_reserved_keyword(lower)
}

///|
fn split_by_newline(s : String) -> Array[String] {
  let lines : Array[String] = []
  let cur = StringBuilder::new()
  for c in s {
    if c == '\n' {
      lines.push(cur.to_string())
      cur.reset()
    } else {
      cur.write_char(c)
    }
  }
  lines.push(cur.to_string())
  lines
}
