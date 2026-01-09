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
/// diago Source Code Formatter
///
/// Pretty-prints the AST back to formatted diago source code.

///|
/// Format configuration
pub struct FormatConfig {
  /// Indentation string (default: 2 spaces)
  indent : String
  /// Maximum line width for wrapping (default: 80)
  max_width : Int
}

///|
pub fn FormatConfig::new() -> FormatConfig {
  { indent: "  ", max_width: 80 }
}

///|
/// Format an AST Map to formatted diago source
pub fn format(ast : @ast.Map, config : FormatConfig) -> String {
  let buf = StringBuilder::new()
  format_map_nodes(buf, ast.nodes, 0, config)
  buf.to_string()
}

///|
fn format_map_nodes(
  buf : StringBuilder,
  nodes : Array[@ast.MapNode],
  depth : Int,
  config : FormatConfig,
) -> Unit {
  let mut prev_was_key = false
  for i, node in nodes {
    match node {
      @ast.MapNode::Comment(_, text) => {
        // Add blank line before comment if previous was a key
        if prev_was_key && i > 0 {
          buf.write_char('\n')
        }
        write_indent(buf, depth, config)
        buf.write_string("#")
        buf.write_string(text)
        buf.write_char('\n')
        prev_was_key = false
      }
      @ast.MapNode::BlockComment(_, text) => {
        if prev_was_key && i > 0 {
          buf.write_char('\n')
        }
        write_indent(buf, depth, config)
        buf.write_string("/*")
        buf.write_string(text)
        buf.write_string("*/")
        buf.write_char('\n')
        prev_was_key = false
      }
      @ast.MapNode::Substitution(sub) => {
        write_indent(buf, depth, config)
        format_substitution(buf, sub)
        buf.write_char('\n')
        prev_was_key = false
      }
      @ast.MapNode::Import(imp) => {
        write_indent(buf, depth, config)
        format_import(buf, imp)
        buf.write_char('\n')
        prev_was_key = false
      }
      @ast.MapNode::Key(key) => {
        // Add blank line between different top-level elements
        if i > 0 && depth == 0 && is_significant_key(key) {
          buf.write_char('\n')
        }
        write_indent(buf, depth, config)
        format_key(buf, key, depth, config)
        buf.write_char('\n')
        prev_was_key = true
      }
    }
  }
}

///|
fn write_indent(
  buf : StringBuilder,
  depth : Int,
  config : FormatConfig,
) -> Unit {
  for _ in 0..<depth {
    buf.write_string(config.indent)
  }
}

///|
/// Check if a key is significant (container, edge, or has special attributes)
fn is_significant_key(key : @ast.Key) -> Bool {
  key.edges.length() > 0 ||
  key.value is Some(@ast.Value::Map(_)) ||
  key.value is Some(@ast.Value::BlockScalar(_, _))
}

///|
fn format_key(
  buf : StringBuilder,
  key : @ast.Key,
  depth : Int,
  config : FormatConfig,
) -> Unit {
  // Format ampersand
  if key.ampersand {
    buf.write_char('&')
  }
  if key.not_ampersand {
    buf.write_string("!&")
  }
  // Format key path
  match key.key {
    Some(path) => format_key_path(buf, path)
    None => ()
  }
  // Format edges
  for edge in key.edges {
    format_edge(buf, edge)
  }
  // Format edge index
  match key.edge_index {
    Some(idx) => format_edge_index(buf, idx)
    None => ()
  }
  // Format edge key
  match key.edge_key {
    Some(path) => {
      buf.write_char('.')
      format_key_path(buf, path)
    }
    None => ()
  }
  // Format primary (label after first colon)
  match key.primary {
    Some(scalar) => {
      buf.write_string(": ")
      format_scalar(buf, scalar)
    }
    None => ()
  }
  // Format value
  match key.value {
    Some(value) => {
      if key.primary is None && key.edges.length() == 0 {
        buf.write_string(": ")
      } else if key.primary is Some(_) {
        buf.write_char(' ')
      } else if key.edges.length() > 0 && !(value is @ast.Value::Map(_)) {
        buf.write_string(": ")
      }
      format_value(buf, value, depth, config)
    }
    None => ()
  }
}

///|
fn format_key_path(buf : StringBuilder, path : @ast.KeyPath) -> Unit {
  for i, s in path.path {
    if i > 0 {
      buf.write_char('.')
    }
    format_string_value(buf, s)
  }
}

///|
fn format_edge(buf : StringBuilder, edge : @ast.Edge) -> Unit {
  // Format source
  format_key_path(buf, edge.src)
  // Format arrow
  buf.write_char(' ')
  if edge.src_arrow == "<" {
    buf.write_char('<')
  }
  buf.write_char('-')
  if edge.dst_arrow == ">" {
    buf.write_char('>')
  }
  buf.write_char(' ')
  // Format destination
  format_key_path(buf, edge.dst)
}

///|
fn format_edge_index(buf : StringBuilder, idx : @ast.EdgeIndex) -> Unit {
  buf.write_char('[')
  match idx.index {
    Some(i) => buf.write_string(i.to_string())
    None => if idx.glob { buf.write_char('*') }
  }
  buf.write_char(']')
}

///|
fn format_value(
  buf : StringBuilder,
  value : @ast.Value,
  depth : Int,
  config : FormatConfig,
) -> Unit {
  match value {
    @ast.Value::Scalar(s) => format_scalar(buf, s)
    @ast.Value::Array(a) => format_array(buf, a, depth, config)
    @ast.Value::Map(m) => format_map(buf, m, depth, config)
    @ast.Value::Import(i) => format_import(buf, i)
    @ast.Value::BlockScalar(label, m) => {
      format_value(buf, label, depth, config)
      buf.write_char(' ')
      format_map(buf, m, depth, config)
    }
  }
}

///|
fn format_scalar(buf : StringBuilder, scalar : @ast.Scalar) -> Unit {
  match scalar {
    @ast.Scalar::Null(_) => buf.write_string("null")
    @ast.Scalar::Boolean(_, true) => buf.write_string("true")
    @ast.Scalar::Boolean(_, false) => buf.write_string("false")
    @ast.Scalar::Number(_, n) => buf.write_string(n)
    @ast.Scalar::String(s) => format_string_value(buf, s)
  }
}

///|
fn format_string_value(buf : StringBuilder, s : @ast.StringValue) -> Unit {
  match s {
    @ast.StringValue::Unquoted(us) =>
      for seg in us.value {
        match seg {
          @ast.Interpolation::Text(t) => buf.write_string(t)
          @ast.Interpolation::Sub(sub) => format_substitution(buf, sub)
        }
      }
    @ast.StringValue::SingleQuoted(_, v) => {
      buf.write_char('\'')
      buf.write_string(v)
      buf.write_char('\'')
    }
    @ast.StringValue::DoubleQuoted(dqs) => {
      buf.write_char('"')
      for seg in dqs.value {
        match seg {
          @ast.Interpolation::Text(t) => buf.write_string(escape_string(t))
          @ast.Interpolation::Sub(sub) => format_substitution(buf, sub)
        }
      }
      buf.write_char('"')
    }
    @ast.StringValue::Block(bs) => {
      buf.write_string(bs.quote)
      buf.write_string(bs.tag)
      buf.write_char('\n')
      buf.write_string(bs.value)
      buf.write_string(bs.quote)
    }
  }
}

///|
fn escape_string(s : String) -> String {
  let out = StringBuilder::new()
  for c in s {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\t' => out.write_string("\\t")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn format_substitution(buf : StringBuilder, sub : @ast.Substitution) -> Unit {
  buf.write_char('$')
  if sub.spread {
    buf.write_string("...")
  }
  buf.write_char('{')
  for i, s in sub.path {
    if i > 0 {
      buf.write_char('.')
    }
    format_string_value(buf, s)
  }
  buf.write_char('}')
}

///|
fn format_import(buf : StringBuilder, imp : @ast.Import) -> Unit {
  buf.write_char('@')
  if imp.spread {
    buf.write_string("...")
  }
  buf.write_string(imp.pre)
  for i, s in imp.path {
    if i > 0 {
      buf.write_char('/')
    }
    format_string_value(buf, s)
  }
}

///|
fn format_array(
  buf : StringBuilder,
  arr : @ast.ArrayValue,
  depth : Int,
  config : FormatConfig,
) -> Unit {
  buf.write_char('[')
  let inline = should_inline_array(arr)
  if !inline {
    buf.write_char('\n')
  }
  for i, node in arr.nodes {
    match node {
      @ast.ArrayNode::Comment(_, text) => {
        if !inline {
          write_indent(buf, depth + 1, config)
        }
        buf.write_string("#")
        buf.write_string(text)
        if !inline {
          buf.write_char('\n')
        }
      }
      @ast.ArrayNode::BlockComment(_, text) => {
        if !inline {
          write_indent(buf, depth + 1, config)
        }
        buf.write_string("/*")
        buf.write_string(text)
        buf.write_string("*/")
        if !inline {
          buf.write_char('\n')
        }
      }
      @ast.ArrayNode::Substitution(sub) => {
        if !inline {
          write_indent(buf, depth + 1, config)
        }
        format_substitution(buf, sub)
        if inline && i < arr.nodes.length() - 1 {
          buf.write_string("; ")
        }
        if !inline {
          buf.write_char('\n')
        }
      }
      @ast.ArrayNode::Import(imp) => {
        if !inline {
          write_indent(buf, depth + 1, config)
        }
        format_import(buf, imp)
        if inline && i < arr.nodes.length() - 1 {
          buf.write_string("; ")
        }
        if !inline {
          buf.write_char('\n')
        }
      }
      @ast.ArrayNode::Value(v) => {
        if !inline {
          write_indent(buf, depth + 1, config)
        }
        format_value(buf, v, depth + 1, config)
        if inline && i < arr.nodes.length() - 1 {
          buf.write_string("; ")
        }
        if !inline {
          buf.write_char('\n')
        }
      }
    }
  }
  if !inline {
    write_indent(buf, depth, config)
  }
  buf.write_char(']')
}

///|
fn should_inline_array(arr : @ast.ArrayValue) -> Bool {
  // Inline if all values are simple scalars and there are few items
  if arr.nodes.length() > 5 {
    return false
  }
  for node in arr.nodes {
    match node {
      @ast.ArrayNode::Value(@ast.Value::Scalar(_)) => continue
      _ => return false
    }
  }
  true
}

///|
fn format_map(
  buf : StringBuilder,
  m : @ast.Map,
  depth : Int,
  config : FormatConfig,
) -> Unit {
  buf.write_char('{')
  if m.nodes.length() > 0 {
    buf.write_char('\n')
    format_map_nodes(buf, m.nodes, depth + 1, config)
    write_indent(buf, depth, config)
  }
  buf.write_char('}')
}
