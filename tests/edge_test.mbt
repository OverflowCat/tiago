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
/// Edge and arrowhead tests

///|
test "simple edge" {
  let svg = compile("a -> b").unwrap()
  assert_true(svg.contains("marker-end"))
  assert_true(svg.contains(">a<"))
  assert_true(svg.contains(">b<"))
}

///|
test "edge with label" {
  let svg = compile("a -> b: connects").unwrap()
  assert_true(svg.contains("connects"))
}

///|
test "bidirectional edge" {
  let svg = compile("a <-> b").unwrap()
  assert_true(svg.contains("marker-end"))
  assert_true(svg.contains("marker-start"))
}

///|
test "reverse edge" {
  let svg = compile("a <- b").unwrap()
  assert_true(svg.contains("marker-start"))
}

///|
test "line without arrows" {
  let svg = compile("a -- b").unwrap()
  assert_true(svg.contains(">a<"))
  assert_true(svg.contains(">b<"))
}

///|
test "edge chain" {
  let svg = compile("a -> b -> c").unwrap()
  assert_true(svg.contains(">a<"))
  assert_true(svg.contains(">b<"))
  assert_true(svg.contains(">c<"))
}

///|
test "edge glob endpoint expands to matched nodes" {
  let source =
    #|x
    #|y
    #|z
    #|
    #|*.style.fill: yellow
    #|x -> *
  let svg = compile(source).unwrap()
  assert_true(svg.contains(">x<"))
  assert_true(svg.contains(">y<"))
  assert_true(svg.contains(">z<"))
  assert_false(svg.contains(">*<"))
}

// =============================================================================
// Arrowhead tests
// =============================================================================

///|
test "triangle arrowhead marker exists" {
  let svg = compile("a -> b").unwrap()
  assert_true(svg.contains("arrow-triangle"))
  assert_true(svg.contains("marker-end"))
}

///|
test "diamond arrowhead" {
  let source =
    #|a -> b {
    #|  target-arrowhead.shape: diamond
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-diamond"))
}

///|
test "circle arrowhead" {
  let source =
    #|a -> b {
    #|  target-arrowhead.shape: circle
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-circle"))
}

///|
test "cf-one arrowhead (crow's foot)" {
  let source =
    #|user -> order {
    #|  source-arrowhead.shape: cf-one
    #|  target-arrowhead.shape: cf-many
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-cf-one"))
  assert_true(svg.contains("arrow-cf-many"))
}

///|
test "cf-many arrowhead (crow's foot)" {
  let source =
    #|a -> b {
    #|  target-arrowhead.shape: cf-many
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-cf-many"))
}

///|
test "bidirectional with different arrowheads" {
  let source =
    #|a <-> b {
    #|  source-arrowhead.shape: circle
    #|  target-arrowhead.shape: diamond
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-circle-reverse"))
  assert_true(svg.contains("arrow-diamond"))
}

///|
test "no arrowhead when none specified" {
  let source =
    #|a -> b {
    #|  target-arrowhead.shape: none
    #|}
  let svg = compile(source).unwrap()
  assert_true(
    svg.contains("marker-end=\"\"") || !svg.contains("arrow-triangle\">"),
  )
}

///|
test "all arrowhead markers are defined in defs" {
  let svg = compile("a -> b").unwrap()
  assert_true(svg.contains("id=\"arrow-triangle\""))
  assert_true(svg.contains("id=\"arrow-diamond\""))
  assert_true(svg.contains("id=\"arrow-circle\""))
  assert_true(svg.contains("id=\"arrow-cf-one\""))
  assert_true(svg.contains("id=\"arrow-cf-many\""))
  assert_true(svg.contains("id=\"arrow-cf-one-required\""))
  assert_true(svg.contains("id=\"arrow-cf-many-required\""))
  assert_true(svg.contains("id=\"arrow-cf-one-optional\""))
  assert_true(svg.contains("id=\"arrow-cf-many-optional\""))
  assert_true(svg.contains("id=\"arrow-line\""))
  assert_true(svg.contains("id=\"arrow-open\""))
}

///|
test "cf-one-required arrowhead" {
  let source =
    #|a -> b {
    #|  target-arrowhead.shape: cf-one-required
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-cf-one-required"))
}

///|
test "cf-many-required arrowhead" {
  let source =
    #|a -> b {
    #|  target-arrowhead.shape: cf-many-required
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-cf-many-required"))
}

///|
test "cf-one-optional arrowhead" {
  let source =
    #|a -> b {
    #|  target-arrowhead.shape: cf-one-optional
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-cf-one-optional"))
}

///|
test "cf-many-optional arrowhead" {
  let source =
    #|a -> b {
    #|  target-arrowhead.shape: cf-many-optional
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-cf-many-optional"))
}

///|
test "line arrowhead" {
  let source =
    #|a -> b {
    #|  target-arrowhead.shape: line
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-line"))
}

///|
test "open arrowhead" {
  let source =
    #|a -> b {
    #|  target-arrowhead.shape: open
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("arrow-open"))
}

// =============================================================================
// Edge style tests
// =============================================================================

///|
test "curved edge" {
  let source =
    #|a -> b {
    #|  style.curved: true
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains(" C"))
}

///|
test "curved edge default" {
  let source = "a -> b"
  let svg = compile(source).unwrap()
  assert_true(svg.contains(" C"))
}

///|
test "straight edge when curved=false" {
  let source =
    #|a -> b {
    #|  style.curved: false
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains(" L"))
}

// =============================================================================
// Connection anchor tests
// =============================================================================

///|
test "source anchor top" {
  let source =
    #|a -> b {
    #|  source-anchor: top
    #|}
  let result = compile(source)
  assert_true(result is Ok(_))
}

///|
test "target anchor bottom" {
  let source =
    #|a -> b {
    #|  target-anchor: bottom
    #|}
  let result = compile(source)
  assert_true(result is Ok(_))
}

///|
test "both anchors" {
  let source =
    #|a -> b {
    #|  source-anchor: right
    #|  target-anchor: left
    #|}
  let result = compile(source)
  assert_true(result is Ok(_))
}

///|
test "corner anchors" {
  let source =
    #|a -> b {
    #|  source-anchor: top-right
    #|  target-anchor: bottom-left
    #|}
  let result = compile(source)
  assert_true(result is Ok(_))
}

// =============================================================================
// Automatic label positioning tests
// =============================================================================

///|
test "edge label has computed position" {
  let source =
    #|a -> b: test label
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  // The edge should have a label_box set by automatic positioning
  let edges = graph.get_edges()
  assert_eq(edges.length(), 1)
  let edge = edges[0]
  assert_true(edge.label_box is Some(_))
}

///|
test "multiple edge labels are positioned" {
  let source =
    #|a -> b: first
    #|b -> c: second
    #|c -> d: third
  let graph = compile_to_graph(source, @engine_api.Direction::Down).unwrap()
  // All edges with labels should have label_box set
  for edge in graph.get_edges() {
    if edge.label != "" {
      assert_true(edge.label_box is Some(_))
    }
  }
}

///|
test "label positioning renders in svg" {
  let source =
    #|a -> b: my label
  let svg = compile(source).unwrap()
  // The label should be rendered
  assert_true(svg.contains("my label"))
  // And should have a background rect
  assert_true(svg.contains("fill=\"white\""))
}
