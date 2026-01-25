///|
test "rectpacking: padding affects aspect ratio (top padding)" {
  let root = ElkNode::new("root")
  let n1 = ElkNode::with_size("n1", 30.0, 30.0)
  let n2 = ElkNode::with_size("n2", 30.0, 30.0)
  let n3 = ElkNode::with_size("n3", 30.0, 30.0)
  let n4 = ElkNode::with_size("n4", 30.0, 30.0)
  root.add_child(n1)
  root.add_child(n2)
  root.add_child(n3)
  root.add_child(n4)
  let options : LayoutOptions = {
    ..LayoutOptions::new(),
    aspect_ratio: Some(1.3),
    node_node_spacing: Some(10.0),
    padding: Some(ElkPadding::new(1000.0, 0.0, 0.0, 0.0)),
  }
  elk_rect_packing_layout(root, options)
  assert_true((root.width - 150.0).abs() < 0.0001)
  assert_true((root.height - 1030.0).abs() < 0.0001)
  assert_true((n1.x - 0.0).abs() < 0.0001)
  assert_true((n1.y - 1000.0).abs() < 0.0001)
  assert_true((n2.x - 40.0).abs() < 0.0001)
  assert_true((n2.y - 1000.0).abs() < 0.0001)
  assert_true((n3.x - 80.0).abs() < 0.0001)
  assert_true((n3.y - 1000.0).abs() < 0.0001)
  assert_true((n4.x - 120.0).abs() < 0.0001)
  assert_true((n4.y - 1000.0).abs() < 0.0001)
}

///|
test "rectpacking: padding affects aspect ratio (left padding)" {
  let root = ElkNode::new("root")
  let n1 = ElkNode::with_size("n1", 30.0, 30.0)
  let n2 = ElkNode::with_size("n2", 30.0, 30.0)
  let n3 = ElkNode::with_size("n3", 30.0, 30.0)
  let n4 = ElkNode::with_size("n4", 30.0, 30.0)
  root.add_child(n1)
  root.add_child(n2)
  root.add_child(n3)
  root.add_child(n4)
  let options : LayoutOptions = {
    ..LayoutOptions::new(),
    aspect_ratio: Some(1.3),
    node_node_spacing: Some(10.0),
    padding: Some(ElkPadding::new(0.0, 0.0, 0.0, 1000.0)),
  }
  elk_rect_packing_layout(root, options)
  assert_true((root.width - 1030.0).abs() < 0.0001)
  assert_true((root.height - 150.0).abs() < 0.0001)
  assert_true((n1.x - 1000.0).abs() < 0.0001)
  assert_true((n1.y - 0.0).abs() < 0.0001)
  assert_true((n2.x - 1000.0).abs() < 0.0001)
  assert_true((n2.y - 40.0).abs() < 0.0001)
  assert_true((n3.x - 1000.0).abs() < 0.0001)
  assert_true((n3.y - 80.0).abs() < 0.0001)
  assert_true((n4.x - 1000.0).abs() < 0.0001)
  assert_true((n4.y - 120.0).abs() < 0.0001)
}

///|
test "rectpacking: padding affects aspect ratio (bottom padding)" {
  let root = ElkNode::new("root")
  let n1 = ElkNode::with_size("n1", 30.0, 30.0)
  let n2 = ElkNode::with_size("n2", 30.0, 30.0)
  let n3 = ElkNode::with_size("n3", 30.0, 30.0)
  let n4 = ElkNode::with_size("n4", 30.0, 30.0)
  root.add_child(n1)
  root.add_child(n2)
  root.add_child(n3)
  root.add_child(n4)
  let options : LayoutOptions = {
    ..LayoutOptions::new(),
    aspect_ratio: Some(1.3),
    node_node_spacing: Some(10.0),
    padding: Some(ElkPadding::new(0.0, 0.0, 1000.0, 0.0)),
  }
  elk_rect_packing_layout(root, options)
  assert_true((root.width - 150.0).abs() < 0.0001)
  assert_true((root.height - 1030.0).abs() < 0.0001)
  assert_true((n1.x - 0.0).abs() < 0.0001)
  assert_true((n1.y - 0.0).abs() < 0.0001)
  assert_true((n2.x - 40.0).abs() < 0.0001)
  assert_true((n2.y - 0.0).abs() < 0.0001)
  assert_true((n3.x - 80.0).abs() < 0.0001)
  assert_true((n3.y - 0.0).abs() < 0.0001)
  assert_true((n4.x - 120.0).abs() < 0.0001)
  assert_true((n4.y - 0.0).abs() < 0.0001)
}

///|
test "rectpacking: padding affects aspect ratio (right padding)" {
  let root = ElkNode::new("root")
  let n1 = ElkNode::with_size("n1", 30.0, 30.0)
  let n2 = ElkNode::with_size("n2", 30.0, 30.0)
  let n3 = ElkNode::with_size("n3", 30.0, 30.0)
  let n4 = ElkNode::with_size("n4", 30.0, 30.0)
  root.add_child(n1)
  root.add_child(n2)
  root.add_child(n3)
  root.add_child(n4)
  let options : LayoutOptions = {
    ..LayoutOptions::new(),
    aspect_ratio: Some(1.3),
    node_node_spacing: Some(10.0),
    padding: Some(ElkPadding::new(0.0, 1000.0, 0.0, 0.0)),
  }
  elk_rect_packing_layout(root, options)
  assert_true((root.width - 1030.0).abs() < 0.0001)
  assert_true((root.height - 150.0).abs() < 0.0001)
  assert_true((n1.x - 0.0).abs() < 0.0001)
  assert_true((n1.y - 0.0).abs() < 0.0001)
  assert_true((n2.x - 0.0).abs() < 0.0001)
  assert_true((n2.y - 40.0).abs() < 0.0001)
  assert_true((n3.x - 0.0).abs() < 0.0001)
  assert_true((n3.y - 80.0).abs() < 0.0001)
  assert_true((n4.x - 0.0).abs() < 0.0001)
  assert_true((n4.y - 120.0).abs() < 0.0001)
}
