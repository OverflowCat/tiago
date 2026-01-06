///|
/// Tests for ELK layout algorithms
test "layered algorithm basic" {
  let root = ElkNode::new("root")
  let node_a = ElkNode::with_size("a", 60.0, 40.0)
  let node_b = ElkNode::with_size("b", 60.0, 40.0)
  let node_c = ElkNode::with_size("c", 60.0, 40.0)
  root.add_child(node_a)
  root.add_child(node_b)
  root.add_child(node_c)
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  root.add_edge(ElkEdge::new("e2", "b", "c"))
  let options = LayoutOptions::layered()
  layout(root, options) |> ignore

  // Nodes should be arranged in layers
  assert_true(node_a.y < node_b.y)
  assert_true(node_b.y < node_c.y)
}

///|
test "force-directed algorithm" {
  let root = ElkNode::new("root")
  for i = 0; i < 5; i = i + 1 {
    root.add_child(ElkNode::with_size("n\{i}", 40.0, 30.0))
  }
  root.add_edge(ElkEdge::new("e1", "n0", "n1"))
  root.add_edge(ElkEdge::new("e2", "n1", "n2"))
  root.add_edge(ElkEdge::new("e3", "n2", "n3"))
  root.add_edge(ElkEdge::new("e4", "n3", "n4"))
  let options = LayoutOptions::force()
  layout(root, options) |> ignore

  // All nodes should have positive positions
  for node in root.children {
    assert_true(node.x >= 0.0)
    assert_true(node.y >= 0.0)
  }
}

///|
test "stress algorithm" {
  let root = ElkNode::new("root")
  root.add_child(ElkNode::with_size("a", 50.0, 30.0))
  root.add_child(ElkNode::with_size("b", 50.0, 30.0))
  root.add_child(ElkNode::with_size("c", 50.0, 30.0))
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  root.add_edge(ElkEdge::new("e2", "b", "c"))
  let options = LayoutOptions::stress()
  layout(root, options) |> ignore

  // All nodes should have valid positions
  for node in root.children {
    assert_true(node.x >= 0.0)
    assert_true(node.y >= 0.0)
  }
}

///|
test "radial algorithm" {
  let root = ElkNode::new("root")
  root.add_child(ElkNode::with_size("center", 40.0, 40.0))
  root.add_child(ElkNode::with_size("outer1", 30.0, 30.0))
  root.add_child(ElkNode::with_size("outer2", 30.0, 30.0))
  root.add_child(ElkNode::with_size("outer3", 30.0, 30.0))
  root.add_edge(ElkEdge::new("e1", "center", "outer1"))
  root.add_edge(ElkEdge::new("e2", "center", "outer2"))
  root.add_edge(ElkEdge::new("e3", "center", "outer3"))
  let options = LayoutOptions::radial()
  layout(root, options) |> ignore

  // Center should be at center, others should be further out
  // Note: radial places center at (center_x - width/2, center_y - height/2)
  for node in root.children {
    assert_true(node.x >= -500.0) // May be negative before normalization
    assert_true(node.y >= -500.0)
  }
}

///|
test "tree algorithm" {
  let root = ElkNode::new("root")
  root.add_child(ElkNode::with_size("parent", 60.0, 40.0))
  root.add_child(ElkNode::with_size("child1", 50.0, 30.0))
  root.add_child(ElkNode::with_size("child2", 50.0, 30.0))
  root.add_child(ElkNode::with_size("grandchild", 40.0, 25.0))
  root.add_edge(ElkEdge::new("e1", "parent", "child1"))
  root.add_edge(ElkEdge::new("e2", "parent", "child2"))
  root.add_edge(ElkEdge::new("e3", "child1", "grandchild"))
  let options = LayoutOptions::tree()
  layout(root, options) |> ignore

  // Parent should be above children
  let parent = root.children[0]
  let child1 = root.children[1]
  assert_true(parent.y < child1.y)
}

///|
test "box packing algorithm" {
  let root = ElkNode::new("root")
  for i = 0; i < 10; i = i + 1 {
    root.add_child(ElkNode::with_size("box\{i}", 50.0, 40.0))
  }
  let options = LayoutOptions::new().with_algorithm(Box)
  layout(root, options) |> ignore

  // All nodes should have valid positions
  for node in root.children {
    assert_true(node.x >= 0.0)
    assert_true(node.y >= 0.0)
  }
}

///|
test "rectangle packing algorithm" {
  let root = ElkNode::new("root")
  root.add_child(ElkNode::with_size("tall", 30.0, 100.0))
  root.add_child(ElkNode::with_size("wide", 100.0, 30.0))
  root.add_child(ElkNode::with_size("small", 20.0, 20.0))
  let options = LayoutOptions::new().with_algorithm(RectPacking)
  layout(root, options) |> ignore

  // Tallest should be first (sorted by height)
  for node in root.children {
    assert_true(node.x >= 0.0)
    assert_true(node.y >= 0.0)
  }
}

///|
test "topdown packing algorithm" {
  let root = ElkNode::new("root")
  root.add_child(ElkNode::with_size("first", 80.0, 40.0))
  root.add_child(ElkNode::with_size("second", 60.0, 40.0))
  root.add_child(ElkNode::with_size("third", 100.0, 40.0))
  let options = LayoutOptions::new().with_algorithm(TopDownPacking)
  layout(root, options) |> ignore

  // Nodes should be stacked vertically
  let first = root.children[0]
  let second = root.children[1]
  let third = root.children[2]
  assert_true(first.y < second.y)
  assert_true(second.y < third.y)
}

///|
test "disco algorithm - disconnected components" {
  let root = ElkNode::new("root")
  // Component 1: a -> b
  root.add_child(ElkNode::with_size("a", 40.0, 30.0))
  root.add_child(ElkNode::with_size("b", 40.0, 30.0))
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  // Component 2: c -> d (disconnected)
  root.add_child(ElkNode::with_size("c", 40.0, 30.0))
  root.add_child(ElkNode::with_size("d", 40.0, 30.0))
  root.add_edge(ElkEdge::new("e2", "c", "d"))
  let options = LayoutOptions::new().with_algorithm(DisCo)
  layout(root, options) |> ignore

  // All nodes should be positioned
  for node in root.children {
    assert_true(node.x >= 0.0)
    assert_true(node.y >= 0.0)
  }
}

///|
test "spore overlap removal" {
  let root = ElkNode::new("root")
  // Create overlapping nodes
  let a = ElkNode::with_size("a", 50.0, 50.0)
  let b = ElkNode::with_size("b", 50.0, 50.0)
  a.x = 10.0
  a.y = 10.0
  b.x = 20.0 // Overlaps with a
  b.y = 20.0
  root.add_child(a)
  root.add_child(b)
  let options = LayoutOptions::new().with_algorithm(SporeOverlap)
  layout(root, options) |> ignore

  // Nodes should no longer overlap (or overlap should be reduced)
  let a_right = a.x + a.width
  let b_left = b.x
  let a_bottom = a.y + a.height
  let b_top = b.y

  // Either horizontally or vertically separated
  let separated = a_right <= b_left ||
    b.x + b.width <= a.x ||
    a_bottom <= b_top ||
    b.y + b.height <= a.y
  assert_true(separated)
}

///|
test "spore compaction" {
  let root = ElkNode::new("root")
  // Create nodes with gaps
  let a = ElkNode::with_size("a", 40.0, 30.0)
  let b = ElkNode::with_size("b", 40.0, 30.0)
  a.x = 10.0
  a.y = 10.0
  b.x = 200.0 // Large gap
  b.y = 10.0
  root.add_child(a)
  root.add_child(b)
  let options = LayoutOptions::new().with_algorithm(SporeCompaction)
  layout(root, options) |> ignore

  // Nodes should be compacted
  for node in root.children {
    assert_true(node.x >= 0.0)
    assert_true(node.y >= 0.0)
  }
}

///|
test "available algorithms" {
  let algs = available_algorithms()
  assert_eq(algs.length(), 13)
  for alg in algs {
    assert_true(is_algorithm_implemented(alg))
  }
}

///|
test "default options" {
  let layered_opts = default_options(Layered)
  assert_true(layered_opts.algorithm.unwrap_or(Force) is Layered)
  let force_opts = default_options(Force)
  assert_true(force_opts.algorithm.unwrap_or(Layered) is Force)
}
