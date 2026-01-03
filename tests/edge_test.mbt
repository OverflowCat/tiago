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
  // Curved edges use bezier curves (Q for quadratic or C for cubic)
  // Simple 2-point edges use Q (quadratic bezier) for a subtle curve
  assert_true(svg.contains(" Q") || svg.contains(" C"))
}

///|
test "straight edge default" {
  let source = "a -> b"
  let svg = compile(source).unwrap()
  // Straight edges use line commands (L in path), not cubic beziers
  // The path should contain L command for straight lines
  assert_true(svg.contains(" L"))
}
