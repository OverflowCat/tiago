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
