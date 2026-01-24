///|
test "other algorithms: Force produces deterministic positions" {
  let mk = fn() -> (ElkNode, ElkNode, ElkNode) {
    let root = ElkNode::new("root")
    let a = ElkNode::with_size("a", 60.0, 40.0)
    let b = ElkNode::with_size("b", 60.0, 40.0)
    let c = ElkNode::with_size("c", 60.0, 40.0)
    root.add_child(a)
    root.add_child(b)
    root.add_child(c)
    (root, a, b)
  }
  let (r1, a1, b1) = mk()
  elk_force_layout(r1, LayoutOptions::force())
  let (r2, a2, b2) = mk()
  elk_force_layout(r2, LayoutOptions::force())
  assert_true(r1.width > 0.0 && r1.height > 0.0)
  assert_true((a1.x - a2.x).abs() < 0.0001)
  assert_true((a1.y - a2.y).abs() < 0.0001)
  assert_true((b1.x - b2.x).abs() < 0.0001)
  assert_true((b1.y - b2.y).abs() < 0.0001)
}

///|
test "other algorithms: Random is deterministic" {
  let mk = fn() -> (ElkNode, ElkNode) {
    let root = ElkNode::new("root")
    let a = ElkNode::with_size("a", 60.0, 40.0)
    let b = ElkNode::with_size("b", 60.0, 40.0)
    root.add_child(a)
    root.add_child(b)
    (root, a)
  }
  let (r1, a1) = mk()
  elk_random_layout(r1, LayoutOptions::new())
  let (r2, a2) = mk()
  elk_random_layout(r2, LayoutOptions::new())
  assert_true((a1.x - a2.x).abs() < 0.0001)
  assert_true((a1.y - a2.y).abs() < 0.0001)
}

///|
test "other algorithms: Fixed keeps node positions" {
  let root = ElkNode::new("root")
  let a = ElkNode::with_size("a", 60.0, 40.0)
  let b = ElkNode::with_size("b", 60.0, 40.0)
  a.x = 10.0
  a.y = 20.0
  b.x = 30.0
  b.y = 40.0
  root.add_child(a)
  root.add_child(b)
  elk_fixed_layout(root, LayoutOptions::new())
  assert_true((a.x - 10.0).abs() < 0.0001)
  assert_true((a.y - 20.0).abs() < 0.0001)
  assert_true((b.x - 30.0).abs() < 0.0001)
  assert_true((b.y - 40.0).abs() < 0.0001)
}

///|
test "other algorithms: SporeOverlap matches d2/elk.js (overlap removal)" {
  // Reference output generated via ../d2/d2layouts/d2elklayout/elk.js (ELK SPOrE Overlap Removal)
  // with options: elk.algorithm=sporeOverlap, elk.spacing.nodeNode=8, elk.padding=[top=8,left=8,bottom=8,right=8]
  let root = ElkNode::new("root")
  let a = ElkNode::with_size("a", 50.0, 50.0)
  let b = ElkNode::with_size("b", 50.0, 50.0)
  let c = ElkNode::with_size("c", 50.0, 50.0)
  a.x = 0.0
  a.y = 0.0
  b.x = 20.0
  b.y = 20.0
  c.x = 120.0
  c.y = 0.0
  root.add_child(a)
  root.add_child(b)
  root.add_child(c)
  elk_spore_overlap_layout(root, LayoutOptions::new())
  assert_true((a.x - 8.0).abs() < 0.0001)
  assert_true((a.y - 8.0).abs() < 0.0001)
  assert_true((b.x - 66.0).abs() < 0.0001)
  assert_true((b.y - 66.0).abs() < 0.0001)
  assert_true((c.x - 166.0).abs() < 0.0001)
  assert_true((c.y - 46.0).abs() < 0.0001)
  assert_true((root.width - 224.0).abs() < 0.0001)
  assert_true((root.height - 124.0).abs() < 0.0001)
}

///|
test "other algorithms: SporeCompaction matches d2/elk.js (compaction)" {
  // Reference output generated via ../d2/d2layouts/d2elklayout/elk.js (ELK SPOrE Compaction)
  // with options: elk.algorithm=sporeCompaction, elk.spacing.nodeNode=8, elk.padding=[top=8,left=8,bottom=8,right=8]
  let root = ElkNode::new("root")
  let a = ElkNode::with_size("a", 50.0, 50.0)
  let b = ElkNode::with_size("b", 50.0, 50.0)
  let c = ElkNode::with_size("c", 50.0, 50.0)
  a.x = 0.0
  a.y = 0.0
  b.x = 70.0
  b.y = 70.0
  c.x = 140.0
  c.y = 0.0
  root.add_child(a)
  root.add_child(b)
  root.add_child(c)
  elk_spore_compaction_layout(root, LayoutOptions::new())
  assert_true((a.x - 8.0).abs() < 0.0001)
  assert_true((a.y - 8.0).abs() < 0.0001)
  assert_true((b.x - 66.0).abs() < 0.0001)
  assert_true((b.y - 66.0).abs() < 0.0001)
  assert_true((c.x - 124.0).abs() < 0.0001)
  assert_true((c.y - 8.0).abs() < 0.0001)
  assert_true((root.width - 182.0).abs() < 0.0001)
  assert_true((root.height - 124.0).abs() < 0.0001)
}
