///|
test "rectpacking: issue583 decreases approximated width with compaction" {
  // Ported from elk-reference:
  // elk-reference/test/org.eclipse.elk.alg.rectpacking.test/.../Issue583Test.java
  //
  // The greedy width approximation yields a larger width than needed; the
  // compaction packing strategy is expected to reduce the final width.

  fn mk_graph() -> (ElkNode, ElkNode, ElkNode, ElkNode, ElkNode) {
    let root = ElkNode::new("root")
    let n1 = ElkNode::with_size("n1", 30.0, 30.0)
    let n2 = ElkNode::with_size("n2", 10.0, 10.0)
    let n3 = ElkNode::with_size("n3", 30.0, 30.0)
    // Added to disable last row optimization in elk-reference.
    let n4 = ElkNode::with_size("n4", 40.0, 10.0)
    root.add_child(n1)
    root.add_child(n2)
    root.add_child(n3)
    root.add_child(n4)
    (root, n1, n2, n3, n4)
  }

  let base_options : LayoutOptions = {
    ..LayoutOptions::new(),
    aspect_ratio: Some(1.3),
    node_node_spacing: Some(0.0),
    padding: Some(ElkPadding::uniform(0.0)),
  }

  // Width approximation only (no placement), expected width: 60.
  {
    let (root, _, _, _, _) = mk_graph()
    let options : LayoutOptions = {
      ..base_options,
      custom: Some({
        "org.eclipse.elk.rectpacking.packing.strategy": PropertyValue::Enum(
          "NONE",
        ),
      }),
    }
    elk_rect_packing_layout(root, options)
    assert_true((root.width - 60.0).abs() < 0.0001)
  }

  // Full algorithm (compaction), expected width: 40.
  let (root, _, _, _, _) = mk_graph()
  let options : LayoutOptions = {
    ..base_options,
    custom: Some({
      "org.eclipse.elk.rectpacking.packing.strategy": PropertyValue::Enum(
        "COMPACTION",
      ),
    }),
  }
  elk_rect_packing_layout(root, options)
  assert_true((root.width - 40.0).abs() < 0.0001)
}
