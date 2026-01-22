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
/// ELK MrTree algorithm (tree layout) - clean-room MoonBit implementation.
///
/// This is an incremental port: it focuses on placing nodes in a tree/forest and
/// generating simple orthogonal edge routes.

///|
fn is_vertical_direction(direction : LayoutDirection) -> Bool {
  direction == Down || direction == Up
}

///|
fn elk_mrtree_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  let resolved_options = resolve_options_for_graph(options, graph)
  ensure_sizes(graph, resolved_options)

  // Recursively layout compound nodes.
  for child in graph.children {
    if child.children.length() > 0 {
      elk_mrtree_layout(child, resolved_options)
    }
  }
  let direction = match resolved_options.direction {
    Some(d) => d
    None => Down
  }
  let padding = resolved_options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let sibling_spacing = match resolved_options.node_node_spacing {
    Some(v) => v
    None => 30.0
  }
  let level_spacing = match resolved_options.node_node_between_layers_spacing {
    Some(v) => v
    None => 50.0
  }
  let is_vertical = is_vertical_direction(direction)
  let node_by_id : Map[String, ElkNode] = {}
  for child in graph.children {
    node_by_id[child.id] = child
  }
  if node_by_id.is_empty() {
    return
  }

  // Pick a single parent for each node based on simple edges.
  let parent_by_id : Map[String, String] = {}
  for edge in graph.edges {
    match (edge.source(), edge.target()) {
      (Some(src), Some(tgt)) => {
        if src == tgt {
          continue
        }
        if node_by_id.contains(src) && node_by_id.contains(tgt) {
          if not(parent_by_id.contains(tgt)) {
            parent_by_id[tgt] = src
          }
        }
      }
      _ => ()
    }
  }
  let children_by_id : Map[String, Array[String]] = {}
  for id, _ in node_by_id {
    children_by_id[id] = []
  }
  for child_id, parent_id in parent_by_id {
    match children_by_id.get(parent_id) {
      Some(children) => children.push(child_id)
      None => ()
    }
  }
  let roots : Array[String] = []
  for id, _ in node_by_id {
    if not(parent_by_id.contains(id)) {
      roots.push(id)
    }
  }

  // If there is no root (cycle), fall back to a single-layer layout.
  if roots.is_empty() {
    let mut cursor = 0.0
    for child in graph.children {
      if is_vertical {
        child.x = padding.left + cursor
        child.y = padding.top
        cursor = cursor + child.width + sibling_spacing
      } else {
        child.x = padding.left
        child.y = padding.top + cursor
        cursor = cursor + child.height + sibling_spacing
      }
    }
    route_tree_edges(graph, node_by_id, direction)
    return
  }

  // Depth computation.
  let depth_by_id : Map[String, Int] = {}
  fn set_depth(
    id : String,
    depth : Int,
    depth_by_id : Map[String, Int],
    children_by_id : Map[String, Array[String]],
  ) -> Unit {
    match depth_by_id.get(id) {
      Some(prev) => if prev <= depth { return }
      None => ()
    }
    depth_by_id[id] = depth
    match children_by_id.get(id) {
      Some(children) =>
        for child_id in children {
          set_depth(child_id, depth + 1, depth_by_id, children_by_id)
        }
      None => ()
    }
  }

  for root_id in roots {
    set_depth(root_id, 0, depth_by_id, children_by_id)
  }

  // Per-depth maximum size along the layout direction.
  let max_dir_size : Array[Double] = []
  for id, node in node_by_id {
    let depth = match depth_by_id.get(id) {
      Some(d) => d
      None => 0
    }
    while max_dir_size.length() <= depth {
      max_dir_size.push(0.0)
    }
    let size = if is_vertical { node.height } else { node.width }
    if size > max_dir_size[depth] {
      max_dir_size[depth] = size
    }
  }
  let depth_offset : Array[Double] = []
  let mut cursor = 0.0
  for i = 0; i < max_dir_size.length(); i = i + 1 {
    depth_offset.push(cursor)
    cursor = cursor + max_dir_size[i] + level_spacing
  }

  // Subtree breadth computation.
  let subtree_breadth_by_id : Map[String, Double] = {}
  fn compute_subtree_breadth(
    id : String,
    node_by_id : Map[String, ElkNode],
    children_by_id : Map[String, Array[String]],
    subtree_breadth_by_id : Map[String, Double],
    is_vertical : Bool,
    sibling_spacing : Double,
  ) -> Double {
    match subtree_breadth_by_id.get(id) {
      Some(v) => v
      None => {
        let node = node_by_id[id]
        let node_breadth = if is_vertical { node.width } else { node.height }
        let children = children_by_id[id]
        if children.is_empty() {
          subtree_breadth_by_id[id] = node_breadth
          node_breadth
        } else {
          let mut sum = 0.0
          let mut first = true
          for child_id in children {
            let child_breadth = compute_subtree_breadth(
              child_id, node_by_id, children_by_id, subtree_breadth_by_id, is_vertical,
              sibling_spacing,
            )
            if first {
              first = false
              sum = child_breadth
            } else {
              sum = sum + sibling_spacing + child_breadth
            }
          }
          let subtree = max_double(node_breadth, sum)
          subtree_breadth_by_id[id] = subtree
          subtree
        }
      }
    }
  }

  for root_id in roots {
    let _ = compute_subtree_breadth(
      root_id, node_by_id, children_by_id, subtree_breadth_by_id, is_vertical, sibling_spacing,
    )

  }

  // Assign breadth positions within each subtree.
  let breadth_pos_by_id : Map[String, Double] = {}
  fn assign_breadth_positions(
    id : String,
    start : Double,
    node_by_id : Map[String, ElkNode],
    children_by_id : Map[String, Array[String]],
    subtree_breadth_by_id : Map[String, Double],
    breadth_pos_by_id : Map[String, Double],
    is_vertical : Bool,
    sibling_spacing : Double,
  ) -> Unit {
    let node = node_by_id[id]
    let node_breadth = if is_vertical { node.width } else { node.height }
    let subtree = subtree_breadth_by_id[id]
    breadth_pos_by_id[id] = start + (subtree - node_breadth) / 2.0
    let mut cursor = start
    for child_id in children_by_id[id] {
      assign_breadth_positions(
        child_id, cursor, node_by_id, children_by_id, subtree_breadth_by_id, breadth_pos_by_id,
        is_vertical, sibling_spacing,
      )
      cursor = cursor + subtree_breadth_by_id[child_id] + sibling_spacing
    }
  }

  let mut forest_cursor = 0.0
  for root_id in roots {
    assign_breadth_positions(
      root_id, forest_cursor, node_by_id, children_by_id, subtree_breadth_by_id,
      breadth_pos_by_id, is_vertical, sibling_spacing,
    )
    forest_cursor = forest_cursor +
      subtree_breadth_by_id[root_id] +
      sibling_spacing * 2.0
  }

  // Compute total extents.
  let mut total_breadth = 0.0
  let mut total_dir = 0.0
  for id, node in node_by_id {
    let breadth_pos = match breadth_pos_by_id.get(id) {
      Some(v) => v
      None => 0.0
    }
    let depth = match depth_by_id.get(id) {
      Some(d) => d
      None => 0
    }
    let dir_pos = if depth < depth_offset.length() {
      depth_offset[depth]
    } else {
      0.0
    }
    let breadth_size = if is_vertical { node.width } else { node.height }
    let dir_size = if is_vertical { node.height } else { node.width }
    total_breadth = max_double(total_breadth, breadth_pos + breadth_size)
    total_dir = max_double(total_dir, dir_pos + dir_size)
  }

  // Place nodes.
  for id, node in node_by_id {
    let breadth_pos = match breadth_pos_by_id.get(id) {
      Some(v) => v
      None => 0.0
    }
    let depth = match depth_by_id.get(id) {
      Some(d) => d
      None => 0
    }
    let dir_pos = if depth < depth_offset.length() {
      depth_offset[depth]
    } else {
      0.0
    }
    if is_vertical {
      node.x = padding.left + breadth_pos
      let y0 = padding.top + dir_pos
      node.y = if direction == Down {
        y0
      } else {
        padding.top + (total_dir - dir_pos - node.height)
      }
    } else {
      node.y = padding.top + breadth_pos
      let x0 = padding.left + dir_pos
      node.x = if direction == Right {
        x0
      } else {
        padding.left + (total_dir - dir_pos - node.width)
      }
    }
  }

  // Update graph bounds.
  let mut max_x = 0.0
  let mut max_y = 0.0
  for child in graph.children {
    max_x = max_double(max_x, child.x + child.width)
    max_y = max_double(max_y, child.y + child.height)
  }
  graph.width = max_x + padding.right
  graph.height = max_y + padding.bottom
  route_tree_edges(graph, node_by_id, direction)
}

///|
fn route_tree_edges(
  graph : ElkNode,
  node_by_id : Map[String, ElkNode],
  direction : LayoutDirection,
) -> Unit {
  let is_vertical = is_vertical_direction(direction)
  for edge in graph.edges {
    match (edge.source(), edge.target()) {
      (Some(src_id), Some(tgt_id)) => {
        if not(node_by_id.contains(src_id)) || not(node_by_id.contains(tgt_id)) {
          continue
        }
        let src = node_by_id[src_id]
        let tgt = node_by_id[tgt_id]
        let section = ElkEdgeSection::new(edge.id + ".s0")
        let (start, end, bends) = if is_vertical {
          let start_y = if direction == Down {
            src.y + src.height
          } else {
            src.y
          }
          let end_y = if direction == Down { tgt.y } else { tgt.y + tgt.height }
          let start = ElkPoint::new(src.x + src.width / 2.0, start_y)
          let end = ElkPoint::new(tgt.x + tgt.width / 2.0, end_y)
          let mid_y = (start.y + end.y) / 2.0
          let bends = [
            ElkPoint::new(start.x, mid_y),
            ElkPoint::new(end.x, mid_y),
          ]
          (start, end, bends)
        } else {
          let start_x = if direction == Right {
            src.x + src.width
          } else {
            src.x
          }
          let end_x = if direction == Right { tgt.x } else { tgt.x + tgt.width }
          let start = ElkPoint::new(start_x, src.y + src.height / 2.0)
          let end = ElkPoint::new(end_x, tgt.y + tgt.height / 2.0)
          let mid_x = (start.x + end.x) / 2.0
          let bends = [
            ElkPoint::new(mid_x, start.y),
            ElkPoint::new(mid_x, end.y),
          ]
          (start, end, bends)
        }
        section.start_point = start
        section.end_point = end
        section.bend_points.clear()
        for p in bends {
          section.bend_points.push(p)
        }
        edge.sections.clear()
        edge.sections.push(section)
      }
      _ => ()
    }
  }
}
