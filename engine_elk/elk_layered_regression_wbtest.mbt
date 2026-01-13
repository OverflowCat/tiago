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
/// M0.3: Minimal fixture set for layered layout regression

///|
fn collect_nodes(
  node : ElkNode,
  prefix : String,
) -> Array[(String, Double, Double, Double, Double)] {
  let result : Array[(String, Double, Double, Double, Double)] = []
  for child in node.children {
    let path = if prefix.length() == 0 {
      child.id
    } else {
      prefix + "/" + child.id
    }
    result.push((path, child.x, child.y, child.width, child.height))
    result.append(collect_nodes(child, path))
  }
  result
}

///|
fn edge_points(edge : ElkEdge) -> Array[ElkPoint] {
  if edge.sections.length() == 0 {
    []
  } else {
    let sec = edge.sections[0]
    let points : Array[ElkPoint] = []
    points.push(sec.start_point)
    points.append(sec.bend_points)
    points.push(sec.end_point)
    points
  }
}

///|
fn collect_edges(
  node : ElkNode,
  prefix : String,
) -> Array[(String, String, String, String, Array[ElkPoint])] {
  let result : Array[(String, String, String, String, Array[ElkPoint])] = []
  for edge in node.edges {
    let src = edge.source().unwrap_or("")
    let tgt = edge.target().unwrap_or("")
    result.push((prefix, edge.id, src, tgt, edge_points(edge)))
  }
  for child in node.children {
    let child_prefix = if prefix.length() == 0 {
      child.id
    } else {
      prefix + "/" + child.id
    }
    result.append(collect_edges(child, child_prefix))
  }
  result
}

///|
fn snapshot_layered(root : ElkNode) -> String {
  let (bx, by) = root.calculate_bounds()
  let nodes = collect_nodes(root, "")
  nodes.sort_by(fn(a, b) {
    if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else {
      0
    }
  })
  let edges = collect_edges(root, "")
  edges.sort_by(fn(a, b) {
    // (container_path, edge_id, ...)
    if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else if a.1 < b.1 {
      -1
    } else if a.1 > b.1 {
      1
    } else {
      0
    }
  })
  let buf = StringBuilder::new()
  buf.write_string(
    "root size=(\{root.width}, \{root.height}) bounds=(\{bx}, \{by})\n",
  )
  buf.write_string("nodes:\n")
  for node in nodes {
    let (path, x, y, w, h) = node
    buf.write_string("  - \{path}: (\{x}, \{y}) (\{w}, \{h})\n")
  }
  buf.write_string("edges:\n")
  for edge in edges {
    let (container, id, src, tgt, points) = edge
    let container_label = if container.length() == 0 {
      "root"
    } else {
      container
    }
    buf.write_string("  - [\{container_label}] \{id} \{src}->\{tgt}:")
    for p in points {
      buf.write_string(" (\{p.x}, \{p.y})")
    }
    buf.write_string("\n")
  }
  buf.to_string()
}

///|
fn fixture_chain() -> ElkNode {
  let root = ElkNode::new("root")
  root.add_child(ElkNode::with_size("a", 60.0, 40.0))
  root.add_child(ElkNode::with_size("b", 60.0, 40.0))
  root.add_child(ElkNode::with_size("c", 60.0, 40.0))
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  root.add_edge(ElkEdge::new("e2", "b", "c"))
  root
}

///|
fn fixture_diamond() -> ElkNode {
  let root = ElkNode::new("root")
  root.add_child(ElkNode::with_size("a", 60.0, 40.0))
  root.add_child(ElkNode::with_size("b", 60.0, 40.0))
  root.add_child(ElkNode::with_size("c", 60.0, 40.0))
  root.add_child(ElkNode::with_size("d", 60.0, 40.0))
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  root.add_edge(ElkEdge::new("e2", "a", "c"))
  root.add_edge(ElkEdge::new("e3", "b", "d"))
  root.add_edge(ElkEdge::new("e4", "c", "d"))
  root
}

///|
fn fixture_parallel_edges() -> ElkNode {
  let root = ElkNode::new("root")
  root.add_child(ElkNode::with_size("a", 60.0, 40.0))
  root.add_child(ElkNode::with_size("b", 60.0, 40.0))
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  root.add_edge(ElkEdge::new("e2", "a", "b"))
  root
}

///|
fn fixture_long_edge() -> ElkNode {
  // Long edge A -> D spans multiple layers due to A->B->C->D chain
  let root = ElkNode::new("root")
  root.add_child(ElkNode::with_size("a", 60.0, 40.0))
  root.add_child(ElkNode::with_size("b", 60.0, 40.0))
  root.add_child(ElkNode::with_size("c", 60.0, 40.0))
  root.add_child(ElkNode::with_size("d", 60.0, 40.0))
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  root.add_edge(ElkEdge::new("e2", "b", "c"))
  root.add_edge(ElkEdge::new("e3", "c", "d"))
  root.add_edge(ElkEdge::new("e4", "a", "d"))
  root
}

///|
fn fixture_cycle() -> ElkNode {
  let root = ElkNode::new("root")
  root.add_child(ElkNode::with_size("a", 60.0, 40.0))
  root.add_child(ElkNode::with_size("b", 60.0, 40.0))
  root.add_child(ElkNode::with_size("c", 60.0, 40.0))
  root.add_edge(ElkEdge::new("e1", "a", "b"))
  root.add_edge(ElkEdge::new("e2", "b", "c"))
  root.add_edge(ElkEdge::new("e3", "c", "a"))
  root
}

///|
fn fixture_compound() -> ElkNode {
  let root = ElkNode::new("root")
  let group = ElkNode::with_size("group", 0.0, 0.0)
  group.add_child(ElkNode::with_size("g1", 60.0, 40.0))
  group.add_child(ElkNode::with_size("g2", 60.0, 40.0))
  group.add_edge(ElkEdge::new("ge1", "g1", "g2"))
  let outside = ElkNode::with_size("outside", 60.0, 40.0)
  root.add_child(group)
  root.add_child(outside)
  root.add_edge(ElkEdge::new("e1", "group", "outside"))
  root
}

///|
fn fixture_cross_hierarchy_edge() -> ElkNode {
  let root = ElkNode::new("root")
  let group = ElkNode::with_size("group", 0.0, 0.0)
  group.add_child(ElkNode::with_size("g1", 60.0, 40.0))
  root.add_child(group)
  let outside = ElkNode::with_size("outside", 60.0, 40.0)
  root.add_child(outside)

  // Cross-hierarchy edge: root-level edge to a nested node
  root.add_edge(ElkEdge::new("e1", "g1", "outside"))
  root
}

///|
test "layered regression: chain" {
  let root = fixture_chain()
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)
  inspect(
    snapshot_layered(root),
    content=(
      #|root size=(84, 224) bounds=(84, 224)
      #|nodes:
      #|  - a: (12, 12) (60, 40)
      #|  - b: (12, 92) (60, 40)
      #|  - c: (12, 172) (60, 40)
      #|edges:
      #|  - [root] e1 a->b: (42, 52) (42, 92)
      #|  - [root] e2 b->c: (42, 132) (42, 172)
      #|
    ),
  )
}

///|
test "layered regression: diamond" {
  let root = fixture_diamond()
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)
  inspect(
    snapshot_layered(root),
    content=(
      #|root size=(164, 224) bounds=(164, 224)
      #|nodes:
      #|  - a: (12, 12) (60, 40)
      #|  - b: (12, 92) (60, 40)
      #|  - c: (92, 92) (60, 40)
      #|  - d: (12, 172) (60, 40)
      #|edges:
      #|  - [root] e1 a->b: (42, 52) (42, 92)
      #|  - [root] e2 a->c: (42, 52) (42, 77) (122, 77) (122, 92)
      #|  - [root] e3 b->d: (42, 132) (42, 172)
      #|  - [root] e4 c->d: (122, 132) (122, 157) (42, 157) (42, 172)
      #|
    ),
  )
}

///|
test "layered regression: parallel edges" {
  let root = fixture_parallel_edges()
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)
  inspect(
    snapshot_layered(root),
    content=(
      #|root size=(84, 144) bounds=(84, 144)
      #|nodes:
      #|  - a: (12, 12) (60, 40)
      #|  - b: (12, 92) (60, 40)
      #|edges:
      #|  - [root] e1 a->b: (39.5, 52) (39.5, 52) (39.5, 92) (39.5, 92)
      #|  - [root] e2 a->b: (44.5, 52) (44.5, 57) (44.5, 97) (44.5, 92)
      #|
    ),
  )
}

///|
test "layered regression: long edge" {
  let root = fixture_long_edge()
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)
  inspect(
    snapshot_layered(root),
    content=(
      #|root size=(164, 224) bounds=(164, 224)
      #|nodes:
      #|  - a: (12, 92) (60, 40)
      #|  - b: (12, 12) (60, 40)
      #|  - c: (92, 92) (60, 40)
      #|  - d: (12, 172) (60, 40)
      #|edges:
      #|  - [root] e1 a->b: (42, 132) (42, 12)
      #|  - [root] e2 b->c: (42, 52) (42, 72) (122, 72) (122, 92)
      #|  - [root] e3 c->d: (122, 132) (122, 157) (42, 157) (42, 172)
      #|  - [root] e4 a->d: (42, 132) (42, 172)
      #|
    ),
  )
}

///|
test "layered regression: cycle breaking" {
  let root = fixture_cycle()
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)
  inspect(
    snapshot_layered(root),
    content=(
      #|root size=(164, 144) bounds=(164, 144)
      #|nodes:
      #|  - a: (12, 12) (60, 40)
      #|  - b: (92, 12) (60, 40)
      #|  - c: (12, 92) (60, 40)
      #|edges:
      #|  - [root] e1 a->b: (42, 52) (122, 12)
      #|  - [root] e2 b->c: (122, 52) (122, 77) (42, 77) (42, 92)
      #|  - [root] e3 c->a: (42, 132) (42, 12)
      #|
    ),
  )
}

///|
test "layered regression: compound" {
  let root = fixture_compound()
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)
  inspect(
    snapshot_layered(root),
    content=(
      #|root size=(132, 192) bounds=(132, 192)
      #|nodes:
      #|  - group: (12, 12) (108, 168)
      #|  - outside: (12, 140) (60, 40)
      #|  - group/g1: (12, 12) (60, 40)
      #|  - group/g2: (12, 92) (60, 40)
      #|edges:
      #|  - [root] e1 group->outside: (66, 180) (66, 160) (42, 160) (42, 140)
      #|  - [group] ge1 g1->g2: (42, 52) (42, 92)
      #|
    ),
  )
}

///|
test "layered regression: cross-hierarchy edge mapping" {
  let root = fixture_cross_hierarchy_edge()
  let options = LayoutOptions::layered()
  elk_layered_layout(root, options)
  inspect(
    snapshot_layered(root),
    content=(
      #|root size=(132, 192) bounds=(132, 192)
      #|nodes:
      #|  - group: (12, 12) (108, 88)
      #|  - outside: (12, 140) (60, 40)
      #|  - group/g1: (12, 12) (60, 40)
      #|edges:
      #|  - [root] e1 g1->outside: (66, 100) (66, 120) (42, 120) (42, 140)
      #|
    ),
  )
}
