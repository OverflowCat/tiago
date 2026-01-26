///|
test "rectpacking: whitespace elimination expands narrow rows to drawing width" {
  let root = ElkNode::new("root")
  let n1 = ElkNode::with_size("n1", 100.0, 10.0)
  let n2 = ElkNode::with_size("n2", 50.0, 10.0)
  n2.properties.set(
    "org.eclipse.elk.rectpacking.inNewRow",
    PropertyValue::Bool(true),
  )
  root.add_child(n1)
  root.add_child(n2)
  let options : LayoutOptions = {
    ..LayoutOptions::new(),
    node_node_spacing: Some(10.0),
    padding: Some(ElkPadding::zero()),
    custom: Some({
      "org.eclipse.elk.rectpacking.widthApproximation.targetWidth": PropertyValue::Double(
        200.0,
      ),
      "org.eclipse.elk.rectpacking.packing.strategy": PropertyValue::Enum(
        "SIMPLE",
      ),
      "org.eclipse.elk.rectpacking.whiteSpaceElimination.strategy": PropertyValue::Enum(
        "EQUAL_BETWEEN_STRUCTURES",
      ),
    }),
  }
  elk_rect_packing_layout(root, options)
  assert_true((n1.width - 100.0).abs() < 0.0001)
  assert_true((n2.width - 100.0).abs() < 0.0001)
}

///|
test "rectpacking: whitespace elimination TO_ASPECT_RATIO increases height and distributes it" {
  let root = ElkNode::new("root")
  let n1 = ElkNode::with_size("n1", 100.0, 10.0)
  let n2 = ElkNode::with_size("n2", 50.0, 10.0)
  n2.properties.set(
    "org.eclipse.elk.rectpacking.inNewRow",
    PropertyValue::Bool(true),
  )
  root.add_child(n1)
  root.add_child(n2)
  let options : LayoutOptions = {
    ..LayoutOptions::new(),
    aspect_ratio: Some(2.0),
    node_node_spacing: Some(10.0),
    padding: Some(ElkPadding::zero()),
    custom: Some({
      "org.eclipse.elk.rectpacking.widthApproximation.targetWidth": PropertyValue::Double(
        200.0,
      ),
      "org.eclipse.elk.rectpacking.packing.strategy": PropertyValue::Enum(
        "SIMPLE",
      ),
      "org.eclipse.elk.rectpacking.whiteSpaceElimination.strategy": PropertyValue::Enum(
        "TO_ASPECT_RATIO",
      ),
    }),
  }
  elk_rect_packing_layout(root, options)
  assert_true((root.width - 100.0).abs() < 0.0001)
  assert_true((root.height - 50.0).abs() < 0.0001)
  assert_true((n1.height - 20.0).abs() < 0.0001)
  assert_true((n2.height - 20.0).abs() < 0.0001)
  assert_true((n2.y - 30.0).abs() < 0.0001)
}
