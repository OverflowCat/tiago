///|
test "rectpacking: inNewRow forces a new row (simple packing)" {
  let root = ElkNode::new("root")
  let n1 = ElkNode::with_size("n1", 30.0, 10.0)
  let n2 = ElkNode::with_size("n2", 30.0, 10.0)
  let n3 = ElkNode::with_size("n3", 30.0, 10.0)
  n2.properties.set(
    "org.eclipse.elk.rectpacking.inNewRow",
    PropertyValue::Bool(true),
  )
  root.add_child(n1)
  root.add_child(n2)
  root.add_child(n3)
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
    }),
  }
  elk_rect_packing_layout(root, options)
  assert_true((n1.x - 0.0).abs() < 0.0001)
  assert_true((n1.y - 0.0).abs() < 0.0001)
  assert_true((n2.x - 0.0).abs() < 0.0001)
  assert_true((n2.y - 20.0).abs() < 0.0001)
  assert_true((n3.x - 40.0).abs() < 0.0001)
  assert_true((n3.y - 20.0).abs() < 0.0001)
}

///|
test "rectpacking: orderBySize sorts children by height before phase1" {
  let root = ElkNode::new("root")
  let n1 = ElkNode::with_size("n1", 10.0, 10.0)
  let n2 = ElkNode::with_size("n2", 10.0, 30.0)
  let n3 = ElkNode::with_size("n3", 10.0, 20.0)
  root.add_child(n1)
  root.add_child(n2)
  root.add_child(n3)
  let options : LayoutOptions = {
    ..LayoutOptions::new(),
    node_node_spacing: Some(0.0),
    padding: Some(ElkPadding::zero()),
    custom: Some({
      "org.eclipse.elk.rectpacking.orderBySize": PropertyValue::Bool(true),
      "org.eclipse.elk.rectpacking.packing.strategy": PropertyValue::Enum(
        "NONE",
      ),
    }),
  }
  elk_rect_packing_layout(root, options)
  assert_eq(root.children[0].id, "n2")
  assert_eq(root.children[1].id, "n3")
  assert_eq(root.children[2].id, "n1")
}

///|
test "rectpacking: interactive reorderer respects desiredPosition and sets currentPosition" {
  let root = ElkNode::new("root")
  let n1 = ElkNode::with_size("n1", 10.0, 10.0)
  let n2 = ElkNode::with_size("n2", 10.0, 10.0)
  let n3 = ElkNode::with_size("n3", 10.0, 10.0)
  n3.properties.set(
    "org.eclipse.elk.rectpacking.desiredPosition",
    PropertyValue::Int(0),
  )
  root.add_child(n1)
  root.add_child(n2)
  root.add_child(n3)
  let options : LayoutOptions = {
    ..LayoutOptions::new(),
    interactive: Some(true),
    node_node_spacing: Some(0.0),
    padding: Some(ElkPadding::zero()),
    custom: Some({
      "org.eclipse.elk.rectpacking.packing.strategy": PropertyValue::Enum(
        "NONE",
      ),
    }),
  }
  elk_rect_packing_layout(root, options)
  assert_eq(root.children[0].id, "n3")
  assert_eq(root.children[1].id, "n1")
  assert_eq(root.children[2].id, "n2")
  assert_eq(
    n3.properties.get_int("org.eclipse.elk.rectpacking.currentPosition"),
    Some(0),
  )
  assert_eq(
    n1.properties.get_int("org.eclipse.elk.rectpacking.currentPosition"),
    Some(1),
  )
  assert_eq(
    n2.properties.get_int("org.eclipse.elk.rectpacking.currentPosition"),
    Some(2),
  )
}
