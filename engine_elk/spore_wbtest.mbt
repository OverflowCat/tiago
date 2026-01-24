///|
fn assert_no_overlaps(children : Array[ElkNode]) -> Unit raise {
  for i in 0..<children.length() {
    for j in 0..<children.length() {
      if i == j {
        continue
      }
      let a = children[i]
      let b = children[j]
      let r1 = SporeRect::new(a.x, a.y, a.width, a.height)
      let r2 = SporeRect::new(b.x, b.y, b.width, b.height)
      assert_true(
        fuzzy_compare(shortest_distance(r1, r2), 0.0, spore_fuzziness) >= 0,
      )
    }
  }
}

///|
test "spore utils: overlap factor removes overlap when applied" {
  let r1 = SporeRect::new(0.0, 0.0, 40.0, 80.0)
  let rs = [
    SporeRect::new(0.0, 0.0, 70.0, 20.0),
    SporeRect::new(10.0, 50.0, 70.0, 20.0),
    SporeRect::new(-40.0, 30.0, 70.0, 20.0),
    SporeRect::new(-60.0, 70.0, 70.0, 20.0),
    SporeRect::new(-10.0, 70.0, 70.0, 20.0),
    SporeRect::new(-20.0, -10.0, 70.0, 20.0),
    SporeRect::new(10.0, 20.0, 20.0, 20.0),
    SporeRect::new(-20.0, -20.0, 100.0, 120.0),
    SporeRect::new(0.0, -0.001, 40.0, 80.0),
  ]
  for r2 in rs {
    let o = spore_overlap(r1, r2)
    let c1 = r1.center()
    let c2 = r2.center()
    let d = c2.sub(c1)
    let c3 = c1.add(d.scale(o))
    let r3 = r2.translate(c3.sub(c2))
    assert_true(
      fuzzy_compare(shortest_distance(r1, r3), 0.0, spore_fuzziness) >= 0,
    )
  }
}

///|
test "spore utils: underlap equals distance along center direction" {
  let r1 = SporeRect::new(0.0, 0.0, 20.0, 60.0)
  let rectangles = [
    SporeRect::new(40.0, 20.0, 20.0, 20.0),
    SporeRect::new(40.0, 40.0, 20.0, 20.0),
    SporeRect::new(30.0, 70.0, 20.0, 20.0),
    SporeRect::new(20.0, 80.0, 20.0, 20.0),
    SporeRect::new(10.0, 80.0, 20.0, 20.0),
    SporeRect::new(0.0, 80.0, 20.0, 20.0),
    SporeRect::new(-30.0, 70.0, 20.0, 20.0),
    SporeRect::new(-40.0, 40.0, 20.0, 20.0),
    SporeRect::new(-40.0, 20.0, 20.0, 20.0),
    SporeRect::new(-30.0, -20.0, 20.0, 20.0),
    SporeRect::new(-20.0, -40.0, 20.0, 20.0),
    SporeRect::new(0.0, -30.0, 20.0, 20.0),
    SporeRect::new(30.0, -30.0, 20.0, 20.0),
    SporeRect::new(20.0, 0.0, 20.0, 20.0),
    SporeRect::new(0.0, 60.0, 20.0, 20.0),
  ]
  let n1 = SporeNode::new(r1.center(), r1)
  for r in rectangles {
    let n2 = SporeNode::new(r.center(), r)
    let underlap = n1.underlap(n2)
    let dir = n1.vertex.sub(n2.vertex)
    let dist = n1.distance(n2, dir)
    assert_true((underlap - dist).abs() <= spore_fuzziness)
    n2.translate(dir.scale_to_length(underlap))
    assert_true(shortest_distance(n1.rect, n2.rect).abs() <= spore_fuzziness)
  }
}

///|
test "spore utils: distance returns infinity when direction cannot reach" {
  let r1 = SporeRect::new(0.0, 0.0, 20.0, 60.0)
  let target = SporeRect::new(30.0, -30.0, 20.0, 20.0)
  let n1 = SporeNode::new(r1.center(), r1)
  let vectors : Array[(SporeVec, Bool)] = [
    (SporeVec::new(-20.0, 20.0), true),
    (SporeVec::new(-80.0, 0.0), false),
    (SporeVec::new(-20.0, 9.0), false),
    (SporeVec::new(0.0, 50.0), false),
    (SporeVec::new(-9.99, 50.0), false),
    (SporeVec::new(60.0, 60.0), false),
    (SporeVec::new(-30.0, 50.0), true),
    (SporeVec::new(-20.0, 130.0), true),
    (SporeVec::new(-20.0, -21.0), false),
  ]
  for pair in vectors {
    let (v, should_collide) = pair
    let n2 = SporeNode::new(target.center(), target)
    let distance = n1.distance(n2, v)
    if should_collide {
      n2.translate(v.scale_to_length(distance))
      assert_true(shortest_distance(n1.rect, n2.rect).abs() <= spore_fuzziness)
    } else {
      assert_true(distance == @double.infinity)
    }
  }
}

///|
test "spore overlap removal: scanline toggle affects completeness (elk-reference regression)" {
  let mk = fn() -> ElkNode {
    let graph = ElkNode::new("root")
    let n0 = ElkNode::with_size("n0", 160.0, 20.0)
    let n1 = ElkNode::with_size("n1", 160.0, 20.0)
    let n2 = ElkNode::with_size("n2", 20.0, 20.0)
    let n3 = ElkNode::with_size("n3", 20.0, 20.0)
    n0.x = 0.0
    n0.y = 30.0
    n1.x = 150.0
    n1.y = 40.0
    n2.x = 150.0
    n2.y = 0.0
    n3.x = 150.0
    n3.y = 70.0
    graph.add_child(n0)
    graph.add_child(n1)
    graph.add_child(n2)
    graph.add_child(n3)
    graph
  }
  let g1 = mk()
  spore_overlap_layout_impl_with_scanline(g1, LayoutOptions::new(), true)
  assert_no_overlaps(g1.children)
  let g2 = mk()
  spore_overlap_layout_impl_with_scanline(g2, LayoutOptions::new(), false)
  // When scanline is disabled, the MST-based overlap removal may miss some overlaps.
  let mut has_overlaps = false
  for i in 0..<g2.children.length() {
    for j in 0..<g2.children.length() {
      if i == j {
        continue
      }
      let a = g2.children[i]
      let b = g2.children[j]
      let r1 = SporeRect::new(a.x, a.y, a.width, a.height)
      let r2 = SporeRect::new(b.x, b.y, b.width, b.height)
      if fuzzy_compare(shortest_distance(r1, r2), 0.0, spore_fuzziness) < 0 {
        has_overlaps = true
      }
    }
  }
  assert_true(has_overlaps)
}
