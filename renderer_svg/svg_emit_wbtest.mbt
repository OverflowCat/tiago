///|
test "d2 legend corpus ignores custom entries" {
  let legend = @graph.LegendInput::from_parts(
    Some("Legendary"),
    @graph.LegendPosition::TopRight,
    [
      @graph.LegendEntryInput::shape(@graph.ShapeType::Rectangle, "Node", None),
      @graph.LegendEntryInput::connection(
        @graph.ArrowheadType::None,
        @graph.ArrowheadType::Triangle,
        "Edge",
        None,
      ),
      @graph.LegendEntryInput::custom("https://example.com/icon.svg", "Custom"),
    ],
    None,
    None,
    0.0,
    0.0,
    0.0,
  )
  assert_eq(d2_legend_corpus(legend), "LegendaryNodeEdge")
}

///|
test "d2 legend corpus uses fallback title when empty" {
  let legend = @graph.LegendInput::from_parts(
    Some(""),
    @graph.LegendPosition::TopRight,
    [@graph.LegendEntryInput::shape(@graph.ShapeType::Rectangle, "Node", None)],
    None,
    None,
    0.0,
    0.0,
    0.0,
  )
  assert_eq(d2_legend_corpus(legend), "LegendNode")
}

///|
fn test_diagram_for_scope_hash() -> @diagram.Diagram {
  let graph = @graph.GraphInput::from_parts(
    "hash-test",
    @graph.ObjectInput::new("root"),
    [
      @graph.ObjectInput::from_parts(
        "node",
        "Node",
        @graph.ShapeType::Rectangle,
        @graph.StyleInput::new(),
        None,
        None,
        [],
        0,
        None,
        None,
        None,
        [],
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
      ),
    ],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    None,
  )
  @diagram.from_graph(graph, None)
}

///|
test "diagram scope class follows diagram hash id instead of svg config font settings" {
  let diagram = test_diagram_for_scope_hash()
  let base = SvgConfig::new()
  let font_variant = {
    ..SvgConfig::new(),
    font_family: "monospace",
    font_size: 24,
  }
  let salted = { ..font_variant, salt: Some("salt") }

  assert_eq(diagram_scope_class(diagram, base), diagram.hash_id(None))
  assert_eq(diagram_scope_class(diagram, font_variant), diagram.hash_id(None))
  assert_eq(
    diagram_scope_class(diagram, base),
    diagram_scope_class(diagram, font_variant),
  )
  assert_eq(diagram_scope_class(diagram, salted), diagram.hash_id(Some("salt")))
}
