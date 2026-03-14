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
