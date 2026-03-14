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
test "svg new creates document" {
  let svg = Svg::new(800.0, 600.0)
  let s = svg.to_string()
  assert_true(s.contains("width=\"800\""))
  assert_true(s.contains("height=\"600\""))
  assert_true(s.contains("viewBox=\"0 0 800 600\""))
}

///|
test "svg add element" {
  let svg = Svg::new(100.0, 100.0)
  svg.add(
    @xml_emit.Element::new("rect")
    .attr_int("x", 0)
    .attr_int("y", 0)
    .attr_int("width", 50)
    .attr_int("height", 50)
    .self_close()
    .build(),
  )
  let s = svg.to_string()
  assert_true(s.contains("<rect x=\"0\" y=\"0\""))
}

///|
test "svg add def" {
  let svg = Svg::new(100.0, 100.0)
  svg.add_def(
    @xml_emit.Element::new("marker").attr("id", "test").self_close().build(),
  )
  let s = svg.to_string()
  assert_true(s.contains("<defs>"))
  assert_true(s.contains("<marker id=\"test\" />"))
}

///|
test "svg group" {
  let svg = Svg::new(100.0, 100.0)
  svg.open_group("translate(10,10)")
  svg.add(@xml_emit.Element::new("rect").self_close().build())
  svg.close_group()
  let s = svg.to_string()
  assert_true(s.contains("<g transform=\"translate(10,10)\">"))
  assert_true(s.contains("</g>"))
}

///|
test "rect builder" {
  let r = rect(10.0, 20.0, 100.0, 50.0, fill="red", stroke="blue")
  assert_true(r.contains("x=\"10\""))
  assert_true(r.contains("y=\"20\""))
  assert_true(r.contains("width=\"100\""))
  assert_true(r.contains("height=\"50\""))
  assert_true(r.contains("fill=\"red\""))
  assert_true(r.contains("stroke=\"blue\""))
}

///|
test "rect with rounded corners" {
  let r = rect(0.0, 0.0, 100.0, 50.0, rx=Some(5.0), ry=Some(5.0))
  assert_true(r.contains("rx=\"5\""))
  assert_true(r.contains("ry=\"5\""))
}

///|
test "ellipse builder" {
  let e = ellipse(50.0, 50.0, 40.0, 30.0, fill="green")
  assert_true(e.contains("cx=\"50\""))
  assert_true(e.contains("cy=\"50\""))
  assert_true(e.contains("rx=\"40\""))
  assert_true(e.contains("ry=\"30\""))
  assert_true(e.contains("fill=\"green\""))
}

///|
test "circle builder" {
  let c = circle(100.0, 100.0, 50.0, fill="yellow")
  assert_true(c.contains("cx=\"100\""))
  assert_true(c.contains("cy=\"100\""))
  assert_true(c.contains("r=\"50\""))
}

///|
test "line builder" {
  let l = line(0.0, 0.0, 100.0, 100.0, stroke="red", stroke_width=2.0)
  assert_true(l.contains("x1=\"0\""))
  assert_true(l.contains("y1=\"0\""))
  assert_true(l.contains("x2=\"100\""))
  assert_true(l.contains("y2=\"100\""))
  assert_true(l.contains("stroke=\"red\""))
}

///|
test "polyline builder" {
  let p = polyline([(0.0, 0.0), (50.0, 50.0), (100.0, 0.0)])
  assert_true(p.contains("points=\"0,0 50,50 100,0\""))
}

///|
test "polygon builder" {
  let p = polygon([(0.0, 0.0), (100.0, 0.0), (50.0, 100.0)], fill="blue")
  assert_true(p.contains("points=\"0,0 100,0 50,100\""))
  assert_true(p.contains("fill=\"blue\""))
}

///|
test "path builder" {
  let p = path("M 0 0 L 100 100", stroke="black")
  assert_true(p.contains("d=\"M 0 0 L 100 100\""))
}

///|
test "path with markers" {
  let p = path(
    "M 0 0 L 100 100",
    marker_start="url(#start)",
    marker_end="url(#end)",
  )
  assert_true(p.contains("marker-start=\"url(#start)\""))
  assert_true(p.contains("marker-end=\"url(#end)\""))
}

///|
test "text builder" {
  let t = text(50.0, 50.0, "Hello", font_size=16)
  assert_true(t.contains("x=\"50\""))
  assert_true(t.contains("y=\"50\""))
  assert_true(t.contains(">Hello</text>"))
  assert_true(t.contains("font-size=\"16\""))
}

///|
test "text escapes special characters" {
  let t = text(0.0, 0.0, "<script>alert('xss')</script>")
  assert_true(t.contains("&lt;script&gt;"))
  assert_true(t.contains("&#39;"))
}

///|
test "arrow marker" {
  let m = arrow_marker("arrow", 10.0, "#333")
  assert_true(m.contains("id=\"arrow\""))
  assert_true(m.contains("markerWidth=\"10\""))
  assert_true(m.contains("fill=\"#333\""))
}

///|
test "reverse arrow marker" {
  let m = arrow_marker("arrow-rev", 10.0, "#333", reverse=true)
  assert_true(m.contains("id=\"arrow-rev\""))
  assert_true(m.contains("refX=\"0\""))
}

///|
test "background" {
  let bg = background("#ffffff")
  assert_true(bg.contains("width=\"100%\""))
  assert_true(bg.contains("height=\"100%\""))
  assert_true(bg.contains("fill=\"#ffffff\""))
}

///|
test "path builder fluent api" {
  let d = PathBuilder::new()
    .move_to(0.0, 0.0)
    .line_to(100.0, 0.0)
    .line_to(100.0, 100.0)
    .close()
    .build()
  assert_true(d.contains("M 0.000000 0.000000"))
  assert_true(d.contains("L 100.000000 0.000000"))
  assert_true(d.contains("L 100.000000 100.000000"))
  assert_true(d.contains("Z"))
}

///|
test "path builder arc" {
  let d = PathBuilder::new()
    .move_to(0.0, 50.0)
    .arc_to(50.0, 50.0, 100.0, 50.0)
    .build()
  assert_true(d.contains("A 50.000000 50.000000 0 0 1 100.000000 50.000000"))
}

///|
test "escape_xml" {
  assert_eq(escape_xml("<>&\"'"), "&lt;&gt;&amp;&quot;&#39;")
  assert_eq(escape_xml("normal text"), "normal text")
}
