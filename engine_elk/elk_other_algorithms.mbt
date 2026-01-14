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
/// Minimal, deterministic implementations for non-layered ELK algorithms.
///
/// These are intentionally simple placeholders so `elk.algorithm` dispatch is
/// functional and testable. They aim for determinism and reasonable spacing,
/// not full behavioral parity with upstream ELK (yet).

///|
fn stable_sort_children_by_id(node : ElkNode) -> Unit {
  node.children.sort_by(fn(a, b) { a.id.compare(b.id) })
}

///|
fn stable_sort_edges_by_id(node : ElkNode) -> Unit {
  node.edges.sort_by(fn(a, b) { a.id.compare(b.id) })
}

///|
fn route_edges_straight(root : ElkNode) -> Unit {
  stable_sort_edges_by_id(root)
  for edge in root.edges {
    guard edge.is_simple() else { continue }
    let src_id = edge.source().unwrap_or("")
    let tgt_id = edge.target().unwrap_or("")
    let src = root.find_node(src_id)
    let tgt = root.find_node(tgt_id)
    guard src is Some(s) && tgt is Some(t) else { continue }
    let sx = s.x + s.width / 2.0
    let sy = s.y + s.height / 2.0
    let tx = t.x + t.width / 2.0
    let ty = t.y + t.height / 2.0
    let section = ElkEdgeSection::new(edge.id + "_s0")
    section.start_point = ElkPoint::new(sx, sy)
    section.end_point = ElkPoint::new(tx, ty)
    edge.sections.clear()
    edge.sections.push(section)
  }
}

///|
fn layout_children_grid(
  root : ElkNode,
  options : LayoutOptions,
  columns : Int,
) -> Unit {
  stable_sort_children_by_id(root)
  let n = root.children.length()
  if n == 0 {
    root.width = 0.0
    root.height = 0.0
    return
  }
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let spacing_x = options.node_node_spacing.unwrap_or(20.0)
  let spacing_y = options.node_node_between_layers_spacing.unwrap_or(20.0)
  let cols = if columns <= 0 {
    // ceil(sqrt(n)) without needing `sqrt`.
    let mut c = 1
    while c * c < n {
      c = c + 1
    }
    c
  } else {
    columns
  }
  let mut max_x = 0.0
  let mut max_y = 0.0
  for i, child in root.children {
    let row = i / cols
    let col = i % cols
    child.x = padding.left + col.to_double() * (child.width + spacing_x)
    child.y = padding.top + row.to_double() * (child.height + spacing_y)
    let right = child.x + child.width
    let bottom = child.y + child.height
    if right > max_x {
      max_x = right
    }
    if bottom > max_y {
      max_y = bottom
    }
  }
  root.width = max_x + padding.right
  root.height = max_y + padding.bottom
}

///|
fn layout_children_circle(root : ElkNode, options : LayoutOptions) -> Unit {
  stable_sort_children_by_id(root)
  let n = root.children.length()
  if n == 0 {
    root.width = 0.0
    root.height = 0.0
    return
  }
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let spacing = options.node_node_spacing.unwrap_or(20.0)
  let mut max_dim = 0.0
  for child in root.children {
    max_dim = max_double(max_dim, max_double(child.width, child.height))
  }

  // Avoid trig dependencies: approximate a circle using a square perimeter.
  let radius = (max_dim + spacing) * n.to_double() / 4.0
  let cx = padding.left + radius + max_dim / 2.0
  let cy = padding.top + radius + max_dim / 2.0
  for i, child in root.children {
    let u = i.to_double() / n.to_double() * 4.0
    let seg = u.to_int()
    let f = u - seg.to_double()
    let (dx, dy) = match seg {
      0 => (1.0, f)
      1 => (1.0 - f, 1.0)
      2 => (0.0, 1.0 - f)
      _ => (f, 0.0)
    }
    child.x = cx + (dx - 0.5) * 2.0 * radius - child.width / 2.0
    child.y = cy + (dy - 0.5) * 2.0 * radius - child.height / 2.0
  }
  root.width = cx + radius + padding.right + max_dim / 2.0
  root.height = cy + radius + padding.bottom + max_dim / 2.0
}

///|
fn hash_u32(s : String) -> Int {
  // Deterministic string hash (stays within signed Int range).
  let mut h : Int = 216613626
  for i in 0..<s.length() {
    let b = s.code_unit_at(i).to_int()
    h = h ^ b
    h = (h * 16777619) & 0x7fffffff
  }
  h
}

///|
fn layout_children_deterministic_random(
  root : ElkNode,
  options : LayoutOptions,
) -> Unit {
  stable_sort_children_by_id(root)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let spacing = options.node_node_spacing.unwrap_or(20.0)
  let mut max_x = 0.0
  let mut max_y = 0.0
  for child in root.children {
    let hx = hash_u32(child.id + ":x").to_double() / 2147483647.0
    let hy = hash_u32(child.id + ":y").to_double() / 2147483647.0
    child.x = padding.left + hx * 200.0
    child.y = padding.top + hy * 200.0
    let right = child.x + child.width
    let bottom = child.y + child.height
    if right > max_x {
      max_x = right
    }
    if bottom > max_y {
      max_y = bottom
    }
  }
  root.width = max_x + padding.right + spacing
  root.height = max_y + padding.bottom + spacing
}

///|
fn elk_fixed_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  route_edges_straight(graph)
}

///|
fn elk_random_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_deterministic_random(graph, options)
  route_edges_straight(graph)
}

///|
fn elk_box_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_grid(graph, options, 3)
  route_edges_straight(graph)
}

///|
fn elk_rect_packing_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_grid(graph, options, 0)
  route_edges_straight(graph)
}

///|
fn elk_top_down_packing_layout(
  graph : ElkNode,
  options : LayoutOptions,
) -> Unit {
  ensure_sizes(graph, options)
  layout_children_grid(graph, options, 1)
  route_edges_straight(graph)
}

///|
fn elk_force_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_circle(graph, options)
  route_edges_straight(graph)
}

///|
fn elk_stress_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_circle(graph, options)
  route_edges_straight(graph)
}

///|
fn elk_radial_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_circle(graph, options)
  route_edges_straight(graph)
}

///|
fn elk_disco_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_grid(graph, options, 4)
  route_edges_straight(graph)
}

///|
fn elk_spore_compaction_layout(
  graph : ElkNode,
  options : LayoutOptions,
) -> Unit {
  ensure_sizes(graph, options)
  layout_children_grid(graph, options, 4)
  route_edges_straight(graph)
}

///|
fn elk_spore_overlap_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  ensure_sizes(graph, options)
  layout_children_grid(graph, options, 4)
  route_edges_straight(graph)
}
