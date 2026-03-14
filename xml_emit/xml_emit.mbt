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
/// XML Emitter Library
///
/// Provides utilities for building well-formed XML documents with proper escaping.

///|
/// Escape special XML characters in text content
pub fn escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    match c {
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '&' => sb.write_string("&amp;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&#39;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Escape attribute value (same as escape but for attribute context)
pub fn escape_attr(s : String) -> String {
  escape(s)
}

///|
fn d2_number(value : Double) -> String {
  if value.round() == value {
    value.to_int().to_string()
  } else {
    value.to_string()
  }
}

///|
/// Wrap a string in a CDATA section.
///
/// Note: the sequence `]]>` is not allowed inside CDATA. We split it safely by
/// closing and re-opening CDATA sections.
pub fn cdata(content : String) -> String {
  let sb = StringBuilder::new()
  sb.write_string("<![CDATA[")
  let mut i = 0
  while i < content.length() {
    if i + 2 < content.length() &&
      content.code_unit_at(i).to_int().unsafe_to_char() == ']' &&
      content.code_unit_at(i + 1).to_int().unsafe_to_char() == ']' &&
      content.code_unit_at(i + 2).to_int().unsafe_to_char() == '>' {
      sb.write_string("]]]]><![CDATA[>")
      i = i + 3
    } else {
      sb.write_char(content.code_unit_at(i).to_int().unsafe_to_char())
      i = i + 1
    }
  }
  sb.write_string("]]>")
  sb.to_string()
}

///|
/// XML Element builder for constructing elements with attributes and content
pub struct Element {
  tag : String
  attrs : Array[(String, String)]
  content : String
  children : Array[String]
  self_closing : Bool
}

///|
/// Create a new element builder
pub fn Element::new(tag : String) -> Element {
  { tag, attrs: [], content: "", children: [], self_closing: false }
}

///|
/// Add an attribute to the element
pub fn Element::attr(self : Element, name : String, value : String) -> Element {
  self.attrs.push((name, value))
  self
}

///|
/// Add an attribute only if the value is not empty
pub fn Element::attr_if(
  self : Element,
  name : String,
  value : String,
) -> Element {
  if value != "" {
    self.attrs.push((name, value))
  }
  self
}

///|
/// Add a numeric attribute
pub fn Element::attr_num(
  self : Element,
  name : String,
  value : Double,
) -> Element {
  self.attrs.push((name, d2_number(value)))
  self
}

///|
/// Add an integer attribute
pub fn Element::attr_int(self : Element, name : String, value : Int) -> Element {
  self.attrs.push((name, value.to_string()))
  self
}

///|
/// Add a numeric attribute only if condition is true
pub fn Element::attr_num_if(
  self : Element,
  name : String,
  value : Double,
  cond : Bool,
) -> Element {
  if cond {
    self.attrs.push((name, d2_number(value)))
  }
  self
}

///|
/// Set text content (will be escaped)
pub fn Element::text(self : Element, content : String) -> Element {
  { ..self, content: escape(content) }
}

///|
/// Set raw content (will NOT be escaped - use for nested elements)
pub fn Element::raw(self : Element, content : String) -> Element {
  { ..self, content, }
}

///|
/// Set CDATA content (will NOT be escaped).
pub fn Element::cdata(self : Element, content : String) -> Element {
  self.raw(cdata(content))
}

///|
/// Add a child element (as string)
pub fn Element::child(self : Element, child : String) -> Element {
  self.children.push(child)
  self
}

///|
/// Add multiple child elements (as strings)
pub fn Element::children(self : Element, children : Array[String]) -> Element {
  for child in children {
    self.children.push(child)
  }
  self
}

///|
/// Mark as self-closing element (e.g., <br/>)
pub fn Element::self_close(self : Element) -> Element {
  { ..self, self_closing: true }
}

///|
/// Build the element to a string
pub fn Element::build(self : Element) -> String {
  let sb = StringBuilder::new()
  sb.write_char('<')
  sb.write_string(self.tag)
  for attr in self.attrs {
    sb.write_char(' ')
    sb.write_string(attr.0)
    sb.write_string("=\"")
    sb.write_string(escape_attr(attr.1))
    sb.write_char('"')
  }
  if self.self_closing && self.content == "" && self.children.length() == 0 {
    sb.write_string(" />")
  } else {
    sb.write_char('>')
    sb.write_string(self.content)
    for child in self.children {
      sb.write_string(child)
    }
    sb.write_string("</")
    sb.write_string(self.tag)
    sb.write_char('>')
  }
  sb.to_string()
}

///|
/// Build just the opening tag (for streaming/incremental building)
pub fn Element::open_tag(self : Element) -> String {
  let sb = StringBuilder::new()
  sb.write_char('<')
  sb.write_string(self.tag)
  for attr in self.attrs {
    sb.write_char(' ')
    sb.write_string(attr.0)
    sb.write_string("=\"")
    sb.write_string(escape_attr(attr.1))
    sb.write_char('"')
  }
  sb.write_char('>')
  sb.to_string()
}

///|
/// Build just the closing tag
pub fn Element::close_tag(self : Element) -> String {
  "</\{self.tag}>"
}

///|
pub impl Show for Element with output(self, logger) {
  logger.write_string(self.build())
}

// =============================================================================
// Convenience functions for common elements
// =============================================================================

///|
/// Create a self-closing element with attributes
pub fn empty_element(tag : String, attrs : Array[(String, String)]) -> String {
  let elem = Element::new(tag)
  for attr in attrs {
    elem.attrs.push(attr)
  }
  elem.self_close().build()
}

///|
/// Create an element with text content
pub fn text_element(
  tag : String,
  content : String,
  attrs : Array[(String, String)],
) -> String {
  let elem = Element::new(tag)
  for attr in attrs {
    elem.attrs.push(attr)
  }
  elem.text(content).build()
}

///|
/// Create an element with raw content (nested elements)
pub fn container_element(
  tag : String,
  content : String,
  attrs : Array[(String, String)],
) -> String {
  let elem = Element::new(tag)
  for attr in attrs {
    elem.attrs.push(attr)
  }
  elem.raw(content).build()
}

// =============================================================================
// XML Document builder
// =============================================================================

///|
/// XML Document builder
pub struct Document {
  version : String
  encoding : String
  root : String
  elements : Array[String]
}

///|
/// Create a new XML document
pub fn Document::new() -> Document {
  { version: "1.0", encoding: "UTF-8", root: "", elements: [] }
}

///|
/// Set the XML version
pub fn Document::version(self : Document, version : String) -> Document {
  { ..self, version, }
}

///|
/// Set the encoding
pub fn Document::encoding(self : Document, encoding : String) -> Document {
  { ..self, encoding, }
}

///|
/// Add an element to the document
pub fn Document::add(self : Document, element : String) -> Unit {
  self.elements.push(element)
}

///|
/// Build the XML declaration
pub fn Document::declaration(self : Document) -> String {
  "<?xml version=\"\{self.version}\" encoding=\"\{self.encoding}\"?>"
}

///|
/// Build the complete document
pub fn Document::build(self : Document) -> String {
  let sb = StringBuilder::new()
  sb.write_string(self.declaration())
  sb.write_char('\n')
  for elem in self.elements {
    sb.write_string(elem)
    sb.write_char('\n')
  }
  sb.to_string()
}
