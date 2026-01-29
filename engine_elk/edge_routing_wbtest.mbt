// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Regression tests for edge routing perpendicularity

///|
fn style_to_input_for_routing(style : Style) -> @graph.StyleInput {
  @graph.StyleInput::from_parts(
    style.opacity,
    style.stroke,
    style.fill,
    style.stroke_width,
    style.stroke_dash,
    style.border_radius,
    style.shadow,
    style.three_d,
    style.multiple,
    style.font,
    style.font_size,
    style.font_color,
    style.bold,
    style.italic,
    style.underline,
    style.animated,
    style.filled,
    style.double_border,
    style.text_transform,
    style.font_family,
    style.fill_pattern,
    style.sketch,
    style.curved,
  )
}

///|
fn object_to_input_for_routing(obj : Object) -> @graph.ObjectInput {
  let child_ids : Array[String] = []
  for child in obj.children {
    child_ids.push(child.id)
  }
  let classes : Array[String] = []
  for c in obj.classes {
    classes.push(c)
  }
  @graph.ObjectInput::from_parts(
    obj.id,
    obj.label,
    obj.shape_type,
    style_to_input_for_routing(obj.style),
    obj.box,
    obj.label_box,
    child_ids,
    obj.z_index,
    obj.icon,
    obj.tooltip,
    obj.link,
    classes,
    obj.grid_rows,
    obj.grid_columns,
    obj.grid_gap,
    obj.horizontal_gap,
    obj.vertical_gap,
    obj.grid_column_span,
    obj.grid_row_span,
    obj.near,
  )
}

///|
fn edge_to_input_for_routing(edge : Edge) -> @graph.EdgeInput {
  @graph.EdgeInput::from_parts(
    edge.index,
    edge.src_id,
    edge.dst_id,
    edge.src_arrow,
    edge.dst_arrow,
    edge.src_arrowhead,
    edge.dst_arrowhead,
    edge.src_anchor,
    edge.dst_anchor,
    edge.label,
    style_to_input_for_routing(edge.style),
    [],
    edge.bend_points,
    edge.is_curve,
    edge.z_index,
    edge.reference_count,
    edge.label_box,
    edge.src_column_index,
    edge.dst_column_index,
  )
}

///|
fn fragment_to_input_for_routing(
  fragment : SequenceFragment,
) -> @graph.SequenceFragmentInput {
  let operands : Array[@graph.FragmentOperandInput] = []
  for op in fragment.operands {
    operands.push(@graph.FragmentOperandInput::new(op.condition))
  }
  @graph.SequenceFragmentInput::new(
    fragment.fragment_type,
    fragment.condition,
    fragment.start_index,
    fragment.end_index,
    operands,
  )
}

///|
fn graph_to_input_for_routing(graph : Graph) -> @graph.GraphInput {
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    objects.push(object_to_input_for_routing(obj))
  }
  let edges : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    edges.push(edge_to_input_for_routing(edge))
  }
  let fragments : Array[@graph.SequenceFragmentInput] = []
  for fragment in graph.sequence_fragments {
    fragments.push(fragment_to_input_for_routing(fragment))
  }
  @graph.GraphInput::from_parts(
    graph.name,
    object_to_input_for_routing(graph.root),
    objects,
    edges,
    fragments,
    [],
    [],
    [],
    [],
    [],
    [],
    graph.legend,
  )
}

///|
fn new_graph_for_routing(name : String) -> Graph {
  Graph::from_input(@graph.GraphInput::new(name))
}

///|
fn object_with_label_for_routing(id : String, label : String) -> Object {
  let obj = Object::new(id)
  obj.label = label
  obj
}

///|
fn layout_to_graph_for_routing(
  graph : Graph,
  config : LayoutConfig,
  direction : Direction,
) -> Graph raise LayoutError {
  let input = graph_to_input_for_routing(graph)
  let patch = ElkEngine::new().layout(input, config, direction)
  let laid_out_input = @graph.apply_layout(input, patch)
  Graph::from_input(laid_out_input)
}

///|
#warnings("-unused_value")
fn apply_layout_result_for_routing(
  _patch : @graph.LayoutPatch,
  _graph : Graph,
) -> Unit {
  ()
}

///|
/// Helper to check if a segment is horizontal (dy < tolerance)
fn is_horizontal(
  p0 : @graph.Point,
  p1 : @graph.Point,
  tolerance : Double,
) -> Bool {
  let dy = (p1.y - p0.y).abs()
  let dx = (p1.x - p0.x).abs()
  dy < tolerance && dx > tolerance
}

///|
/// Helper to check if a segment is vertical (dx < tolerance)
fn is_vertical(
  p0 : @graph.Point,
  p1 : @graph.Point,
  tolerance : Double,
) -> Bool {
  let dx = (p1.x - p0.x).abs()
  let dy = (p1.y - p0.y).abs()
  dx < tolerance && dy > tolerance
}

///|
/// Helper to check if point is on node boundary
fn point_on_boundary(
  p : @graph.Point,
  box : @graph.Box,
  tolerance : Double,
) -> (Bool, Bool, Bool, Bool) {
  let on_left = (p.x - box.x).abs() < tolerance
  let on_right = (p.x - (box.x + box.width)).abs() < tolerance
  let on_top = (p.y - box.y).abs() < tolerance
  let on_bottom = (p.y - (box.y + box.height)).abs() < tolerance
  (on_left, on_right, on_top, on_bottom)
}

///|
/// Test: Simple two-node vertical arrangement (A above B)
test "edge routing: two nodes vertical - A above B" {
  let graph = new_graph_for_routing("test")
  let a = object_with_label_for_routing("A", "Node A")
  let b = object_with_label_for_routing("B", "Node B")
  graph.add_object(a)
  graph.add_object(b)
  graph.add_edge(Edge::new(0, "A", "B", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  // Get the edge route
  let edge = laid_out.edges[0]
  inspect(edge.route.length() >= 2, content="true")

  // Get node boxes
  let a_box = laid_out.find_object("A").unwrap().box.unwrap()

  // Check first segment
  let p0 = edge.route[0]
  let p1 = edge.route[1]
  let first_horiz = is_horizontal(p0, p1, 2.0)
  let first_vert = is_vertical(p0, p1, 2.0)

  // Check start point is on correct side
  let (on_left, on_right, on_top, on_bottom) = point_on_boundary(p0, a_box, 2.0)

  // For vertical first segment, start should be on top or bottom
  // For horizontal first segment, start should be on left or right
  if first_vert {
    inspect(on_top || on_bottom, content="true")
  }
  if first_horiz {
    inspect(on_left || on_right, content="true")
  }
}

///|
/// Test: Two nodes horizontal arrangement (A left of B)
test "edge routing: two nodes horizontal - A left of B" {
  let graph = new_graph_for_routing("test")
  let a = object_with_label_for_routing("A", "Node A")
  let b = object_with_label_for_routing("B", "Node B")
  graph.add_object(a)
  graph.add_object(b)
  graph.add_edge(Edge::new(0, "A", "B", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Right) catch {
    e => fail("layout failed: \{e}")
  }
  let edge = laid_out.edges[0]
  inspect(edge.route.length() >= 2, content="true")
  let a_box = laid_out.find_object("A").unwrap().box.unwrap()
  let p0 = edge.route[0]
  let p1 = edge.route[1]
  let first_horiz = is_horizontal(p0, p1, 2.0)
  let first_vert = is_vertical(p0, p1, 2.0)
  let (on_left, on_right, on_top, on_bottom) = point_on_boundary(p0, a_box, 2.0)
  if first_vert {
    inspect(on_top || on_bottom, content="true")
  }
  if first_horiz {
    inspect(on_left || on_right, content="true")
  }
}

///|
/// Test: Three nodes in chain (A -> B -> C)
test "edge routing: chain A -> B -> C" {
  let graph = new_graph_for_routing("test")
  graph.add_object(object_with_label_for_routing("A", "A"))
  graph.add_object(object_with_label_for_routing("B", "B"))
  graph.add_object(object_with_label_for_routing("C", "C"))
  graph.add_edge(Edge::new(0, "A", "B", false, true))
  graph.add_edge(Edge::new(1, "B", "C", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  // Verify all edges have routes
  inspect(laid_out.edges[0].route.length() >= 2, content="true")
  inspect(laid_out.edges[1].route.length() >= 2, content="true")
}

///|
/// Regression: fanout edges must enter targets vertically in Down layout
/// (matches layered orthogonal routing behavior; unified router violates this).
test "edge routing: fanout enters from top" {
  let graph = new_graph_for_routing("test")
  graph.add_object(object_with_label_for_routing("a", "a"))
  graph.add_object(object_with_label_for_routing("b", "b"))
  graph.add_object(object_with_label_for_routing("c", "c"))
  graph.add_object(object_with_label_for_routing("d", "d"))
  graph.add_object(object_with_label_for_routing("e", "e"))
  graph.add_edge(Edge::new(0, "a", "b", false, true))
  graph.add_edge(Edge::new(1, "a", "c", false, true))
  graph.add_edge(Edge::new(2, "a", "d", false, true))
  graph.add_edge(Edge::new(3, "a", "e", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  for edge in laid_out.edges {
    // End point must lie on top boundary of target.
    let tgt_box = laid_out.find_object(edge.dst_id).unwrap().box.unwrap()
    let p_last = edge.route[edge.route.length() - 1]
    let (_on_left, _on_right, on_top, _on_bottom) = point_on_boundary(
      p_last, tgt_box, 2.0,
    )
    inspect(on_top, content="true")
  }
}

///|
/// Test: Cycle (A -> B, B -> A) - tests reversed edges
test "edge routing: cycle A <-> B" {
  let graph = new_graph_for_routing("test")
  graph.add_object(object_with_label_for_routing("A", "A"))
  graph.add_object(object_with_label_for_routing("B", "B"))
  graph.add_edge(Edge::new(0, "A", "B", false, true))
  graph.add_edge(Edge::new(1, "B", "A", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  let mut errors = 0
  for edge in laid_out.edges {
    if edge.route.length() >= 2 {
      let src_obj = laid_out.find_object(edge.src_id).unwrap()
      let src_box = src_obj.box.unwrap()
      let p0 = edge.route[0]
      let p1 = edge.route[1]
      let first_horiz = is_horizontal(p0, p1, 2.0)
      let first_vert = is_vertical(p0, p1, 2.0)
      let (on_left, on_right, on_top, on_bottom) = point_on_boundary(
        p0, src_box, 2.0,
      )

      // Check perpendicularity
      if first_vert && !(on_top || on_bottom) {
        errors = errors + 1
      }
      if first_horiz && !(on_left || on_right) {
        errors = errors + 1
      }
    }
  }
  inspect(errors, content="0")
}

///|
/// Test: Same layer nodes - this might cause horizontal segments from top/bottom
test "edge routing: same layer - multiple sources to one target" {
  // Create a graph where multiple nodes connect to the same target
  // This can cause nodes to be placed in the same layer
  let graph = new_graph_for_routing("test")
  graph.add_object(object_with_label_for_routing("A", "A"))
  graph.add_object(object_with_label_for_routing("B", "B"))
  graph.add_object(object_with_label_for_routing("C", "C"))
  // A and B both point to C
  graph.add_edge(Edge::new(0, "A", "C", false, true))
  graph.add_edge(Edge::new(1, "B", "C", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  let mut errors = 0
  for edge in laid_out.edges {
    if edge.route.length() >= 2 {
      let src_obj = laid_out.find_object(edge.src_id).unwrap()
      let src_box = src_obj.box.unwrap()
      let p0 = edge.route[0]
      let p1 = edge.route[1]
      let first_horiz = is_horizontal(p0, p1, 2.0)
      let first_vert = is_vertical(p0, p1, 2.0)
      let (on_left, on_right, on_top, on_bottom) = point_on_boundary(
        p0, src_box, 2.0,
      )
      if first_vert && !(on_top || on_bottom) {
        errors = errors + 1
      }
      if first_horiz && !(on_left || on_right) {
        errors = errors + 1
      }
    }
  }
  inspect(errors, content="0")
}

///|
/// Test: Complex graph with cycle - similar to failing property test
test "edge routing: complex with cycle" {
  let graph = new_graph_for_routing("test")
  // Create nodes similar to the failing test case
  graph.add_object(object_with_label_for_routing("N1", "N1"))
  graph.add_object(object_with_label_for_routing("N2", "N2"))
  graph.add_object(object_with_label_for_routing("N3", "N3"))
  // Create a cycle
  graph.add_edge(Edge::new(0, "N1", "N2", false, true))
  graph.add_edge(Edge::new(1, "N2", "N3", false, true))
  graph.add_edge(Edge::new(2, "N3", "N1", false, true)) // Back edge
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  fn strictly_inside(p : @graph.Point, box : @graph.Box, tol : Double) -> Bool {
    p.x > box.x + tol &&
    p.x < box.x + box.width - tol &&
    p.y > box.y + tol &&
    p.y < box.y + box.height - tol
  }

  let boxes : Array[@graph.Box] = [
    laid_out.find_object("N1").unwrap().box.unwrap(),
    laid_out.find_object("N2").unwrap().box.unwrap(),
    laid_out.find_object("N3").unwrap().box.unwrap(),
  ]
  let mut errors = 0
  for edge in laid_out.edges {
    if edge.route.length() < 2 {
      errors = errors + 1
      continue
    }
    let src_box = laid_out.find_object(edge.src_id).unwrap().box.unwrap()
    let dst_box = laid_out.find_object(edge.dst_id).unwrap().box.unwrap()
    let p0 = edge.route[0]
    let p1 = edge.route[1]
    let p_last = edge.route[edge.route.length() - 1]

    // Start point must lie on the source boundary.
    let (on_left, on_right, on_top, on_bottom) = point_on_boundary(
      p0, src_box, 2.0,
    )

    // End point must lie on the target boundary.
    let (end_left, end_right, end_top, end_bottom) = point_on_boundary(
      p_last, dst_box, 2.0,
    )
    if !(end_left || end_right || end_top || end_bottom) {
      errors = errors + 1
    }

    // First segment direction must match the boundary side.
    let first_horiz = is_horizontal(p0, p1, 2.0)
    let first_vert = is_vertical(p0, p1, 2.0)
    if first_vert && !(on_top || on_bottom) {
      errors = errors + 1
    }
    if first_horiz && !(on_left || on_right) {
      errors = errors + 1
    }

    // No intermediate point should pass through a node.
    for i = 1; i + 1 < edge.route.length(); i = i + 1 {
      let p = edge.route[i]
      for b in boxes {
        if strictly_inside(p, b, 0.5) {
          errors = errors + 1
        }
      }
    }
  }
  inspect(errors, content="0")
}

///|
/// Test: Parallel edges (A -> B and A -> B again)
test "edge routing: parallel edges" {
  let graph = new_graph_for_routing("test")
  graph.add_object(object_with_label_for_routing("A", "A"))
  graph.add_object(object_with_label_for_routing("B", "B"))
  graph.add_edge(Edge::new(0, "A", "B", false, true))
  graph.add_edge(Edge::new(1, "A", "B", false, true)) // Duplicate
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  // Check that boxes are assigned
  inspect(laid_out.find_object("A").unwrap().box is Some(_), content="true")
  inspect(laid_out.find_object("B").unwrap().box is Some(_), content="true")
  // Check that routes are assigned
  inspect(laid_out.edges[0].route.length() >= 2, content="true")
  inspect(laid_out.edges[1].route.length() >= 2, content="true")
}

///|
test "edge routing: multi outgoing edges distribute source anchors" {
  let graph = new_graph_for_routing("test")
  graph.add_object(object_with_label_for_routing("A", "A"))
  graph.add_object(object_with_label_for_routing("B", "B"))
  graph.add_object(object_with_label_for_routing("C", "C"))
  graph.add_edge(Edge::new(0, "A", "B", false, true))
  graph.add_edge(Edge::new(1, "A", "C", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  let a_box = laid_out.find_object("A").unwrap().box.unwrap()
  let b_box = laid_out.find_object("B").unwrap().box.unwrap()
  let c_box = laid_out.find_object("C").unwrap().box.unwrap()
  let b_cx = b_box.x + b_box.width / 2.0
  let c_cx = c_box.x + c_box.width / 2.0

  let mut ab : Edge? = None
  let mut ac : Edge? = None
  for edge in laid_out.edges {
    if edge.src_id == "A" && edge.dst_id == "B" {
      ab = Some(edge)
    }
    if edge.src_id == "A" && edge.dst_id == "C" {
      ac = Some(edge)
    }
  }
  guard ab is Some(eab) && ac is Some(eac) else { fail("missing A edges") }
  guard eab.route.length() >= 2 && eac.route.length() >= 2 else {
    fail("missing routes")
  }
  let ab_x = eab.route[0].x
  let ac_x = eac.route[0].x

  // With multiple outgoing edges, ELK assigns distinct anchors on the source
  // boundary (matching D2/elkjs behavior).
  inspect((ab_x - ac_x).abs() > 0.5, content="true")

  // The ordering of anchors follows the ordering of target x positions.
  if b_cx < c_cx {
    inspect(ab_x <= ac_x + 0.5, content="true")
  } else if c_cx < b_cx {
    inspect(ac_x <= ab_x + 0.5, content="true")
  }

  // Sanity: anchors lie on A's border (top or bottom in Down direction).
  let (on_left, on_right, on_top, on_bottom) = point_on_boundary(
    eab.route[0],
    a_box,
    2.0,
  )
  let _ = (on_left, on_right)
  inspect(on_top || on_bottom, content="true")
}

///|
/// Test: Bidirectional edges (A -> B and B -> A)
test "edge routing: bidirectional edges" {
  let graph = new_graph_for_routing("test")
  graph.add_object(object_with_label_for_routing("A", "A"))
  graph.add_object(object_with_label_for_routing("B", "B"))
  graph.add_edge(Edge::new(0, "A", "B", false, true))
  graph.add_edge(Edge::new(1, "B", "A", false, true))
  graph.add_edge(Edge::new(2, "A", "B", false, true)) // Duplicate
  graph.add_edge(Edge::new(3, "B", "A", false, true)) // Duplicate
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }

  // Check that boxes are assigned
  inspect(laid_out.find_object("A").unwrap().box is Some(_), content="true")
  inspect(laid_out.find_object("B").unwrap().box is Some(_), content="true")
}

///|
/// Test: Diamond pattern (A -> B, A -> C, B -> D, C -> D)
test "edge routing: diamond pattern" {
  let graph = new_graph_for_routing("test")
  graph.add_object(object_with_label_for_routing("A", "A"))
  graph.add_object(object_with_label_for_routing("B", "B"))
  graph.add_object(object_with_label_for_routing("C", "C"))
  graph.add_object(object_with_label_for_routing("D", "D"))
  graph.add_edge(Edge::new(0, "A", "B", false, true))
  graph.add_edge(Edge::new(1, "A", "C", false, true))
  graph.add_edge(Edge::new(2, "B", "D", false, true))
  graph.add_edge(Edge::new(3, "C", "D", false, true))
  let config = LayoutConfig::new()
  let laid_out = layout_to_graph_for_routing(graph, config, Direction::Down) catch {
    e => fail("layout failed: \{e}")
  }
  let mut errors = 0
  for edge in laid_out.edges {
    if edge.route.length() >= 2 {
      let src_obj = laid_out.find_object(edge.src_id).unwrap()
      let src_box = src_obj.box.unwrap()
      let p0 = edge.route[0]
      let p1 = edge.route[1]
      let first_horiz = is_horizontal(p0, p1, 2.0)
      let first_vert = is_vertical(p0, p1, 2.0)
      let (on_left, on_right, on_top, on_bottom) = point_on_boundary(
        p0, src_box, 2.0,
      )
      if first_vert && !(on_top || on_bottom) {
        errors = errors + 1
      }
      if first_horiz && !(on_left || on_right) {
        errors = errors + 1
      }
    }
  }
  inspect(errors, content="0")
}
