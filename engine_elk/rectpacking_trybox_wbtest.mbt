///|
test "rectpacking: trybox falls back to box layout provider when not stackable" {
  fn mk_graph(n : Int) -> ElkNode {
    let root = ElkNode::new("root")
    for i in 0..<n {
      root.add_child(ElkNode::with_size("n" + i.to_string(), 30.0, 10.0))
    }
    root
  }

  let n = 20
  let options_common : LayoutOptions = {
    ..LayoutOptions::new(),
    aspect_ratio: Some(1.3),
    node_node_spacing: Some(10.0),
    padding: Some(ElkPadding::zero()),
  }

  // trybox-enabled rectpacking result.
  let root_trybox = mk_graph(n)
  let options_trybox : LayoutOptions = {
    ..options_common,
    custom: Some({
      "org.eclipse.elk.rectpacking.trybox": PropertyValue::Bool(true),
      "org.eclipse.elk.rectpacking.packing.strategy": PropertyValue::Enum(
        "COMPACTION",
      ),
    }),
  }
  elk_rect_packing_layout(root_trybox, options_trybox)

  // Direct box layout provider result (what trybox should delegate to).
  let root_box = mk_graph(n)
  // Match the priorities set by the trybox fallback.
  let mut prio = root_box.children.length()
  for child in root_box.children {
    child.properties.set("org.eclipse.elk.priority", PropertyValue::Int(prio))
    prio = prio - 1
  }
  elk_box_layout_provider_simple(root_box, options_common)
  assert_true((root_trybox.width - root_box.width).abs() < 0.0001)
  assert_true((root_trybox.height - root_box.height).abs() < 0.0001)
  for i in 0..<n {
    let a = root_trybox.children[i]
    let b = root_box.children[i]
    assert_true((a.x - b.x).abs() < 0.0001)
    assert_true((a.y - b.y).abs() < 0.0001)
  }

  // Without trybox, rectpacking's greedy width approximation prefers a narrow
  // column; the resulting width should differ from box layout.
  let root_rectpacking = mk_graph(n)
  let options_rectpacking : LayoutOptions = {
    ..options_common,
    custom: Some({
      "org.eclipse.elk.rectpacking.packing.strategy": PropertyValue::Enum(
        "COMPACTION",
      ),
    }),
  }
  elk_rect_packing_layout(root_rectpacking, options_rectpacking)
  assert_true((root_trybox.width - root_rectpacking.width).abs() > 0.0001)
}
