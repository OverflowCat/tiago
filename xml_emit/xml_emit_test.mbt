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
/// Tests for XML emitter

///|
test "escape basic characters" {
  assert_eq(escape("<"), "&lt;")
  assert_eq(escape(">"), "&gt;")
  assert_eq(escape("&"), "&amp;")
  assert_eq(escape("\""), "&quot;")
  assert_eq(escape("'"), "&#39;")
}

///|
test "escape mixed content" {
  assert_eq(
    escape("<div>Hello & World</div>"),
    "&lt;div&gt;Hello &amp; World&lt;/div&gt;",
  )
}

///|
test "escape preserves normal text" {
  assert_eq(escape("Hello World"), "Hello World")
  assert_eq(escape("abc123"), "abc123")
}

///|
test "element with attributes" {
  let elem = Element::new("rect")
    .attr("x", "10")
    .attr("y", "20")
    .attr("width", "100")
    .self_close()
  assert_eq(elem.build(), "<rect x=\"10\" y=\"20\" width=\"100\"/>")
}

///|
test "element with numeric attributes" {
  let elem = Element::new("circle")
    .attr_num("cx", 50.0)
    .attr_num("cy", 50.0)
    .attr_num("r", 25.5)
    .self_close()
  assert_eq(elem.build(), "<circle cx=\"50\" cy=\"50\" r=\"25.5\"/>")
}

///|
test "element with text content" {
  let elem = Element::new("text").attr("x", "0").text("Hello <World>")
  assert_eq(elem.build(), "<text x=\"0\">Hello &lt;World&gt;</text>")
}

///|
test "element with raw content" {
  let inner = Element::new("span").text("inner").build()
  let outer = Element::new("div").raw(inner)
  assert_eq(outer.build(), "<div><span>inner</span></div>")
}

///|
test "element with multiple children" {
  let span1 = Element::new("span").text("a").build()
  let span2 = Element::new("span").text("b").build()
  let div = Element::new("div").children([span1, span2])
  assert_eq(div.build(), "<div><span>a</span><span>b</span></div>")
}

///|
test "attr_if only adds non-empty" {
  let elem = Element::new("div")
    .attr_if("class", "active")
    .attr_if("id", "")
    .self_close()
  assert_eq(elem.build(), "<div class=\"active\"/>")
}

///|
test "empty_element convenience function" {
  let result = empty_element("br", [])
  assert_eq(result, "<br/>")
}

///|
test "text_element convenience function" {
  let result = text_element("p", "Hello", [("class", "intro")])
  assert_eq(result, "<p class=\"intro\">Hello</p>")
}

///|
test "document declaration" {
  let doc = Document::new()
  assert_eq(doc.declaration(), "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
}
