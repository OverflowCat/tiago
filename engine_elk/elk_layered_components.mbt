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
/// Connected-components processing for the layered algorithm.
///
/// This follows ELK Layered's `ComponentsProcessor` + `SimpleRowGraphPlacer`:
/// - split the input into connected components
/// - layout each component
/// - pack components in rows (small components first by default)
///
/// Source of truth:
/// - elk-reference/.../components/ComponentsProcessor.java
/// - elk-reference/.../components/SimpleRowGraphPlacer.java

///|
priv struct ComponentLayout {
  root : ElkNode
  width : Double
  height : Double
  priority : Int
  order_index : Int
} derive(Show, Eq)

///|
priv struct ComponentPart {
  root : ElkNode
  order_index : Int
} derive(Show, Eq)

///|
priv struct Bounds {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
} derive(Show, Eq)

///|
fn bounds_empty() -> Bounds {
  { min_x: 1.0e30, min_y: 1.0e30, max_x: -1.0e30, max_y: -1.0e30 }
}

///|
fn bounds_is_empty(b : Bounds) -> Bool {
  b.max_x < b.min_x || b.max_y < b.min_y
}

///|
fn cc_min_d(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn cc_max_d(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn bounds_add_point(b : Bounds, x : Double, y : Double) -> Bounds {
  {
    min_x: cc_min_d(b.min_x, x),
    min_y: cc_min_d(b.min_y, y),
    max_x: cc_max_d(b.max_x, x),
    max_y: cc_max_d(b.max_y, y),
  }
}

///|
fn bounds_add_rect(
  b : Bounds,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Bounds {
  let b = bounds_add_point(b, x, y)
  bounds_add_point(b, x + w, y + h)
}

///|
fn collect_top_level_map(root : ElkNode) -> Map[String, String] {
  let map : Map[String, String] = {}
  for child in root.children {
    collect_top_level_map_rec(child, child.id, map)
  }
  map
}

///|
fn collect_top_level_map_rec(
  node : ElkNode,
  top_id : String,
  map : Map[String, String],
) -> Unit {
  map[node.id] = top_id
  for child in node.children {
    collect_top_level_map_rec(child, top_id, map)
  }
}

///|
priv struct Dsu {
  parent : Map[String, String]
  rank : Map[String, Int]
}

///|
fn Dsu::new(keys : Array[String]) -> Dsu {
  let parent : Map[String, String] = {}
  let rank : Map[String, Int] = {}
  for k in keys {
    parent[k] = k
    rank[k] = 0
  }
  { parent, rank }
}

///|
fn Dsu::find(self : Dsu, key : String) -> String {
  match self.parent.get(key) {
    Some(p) =>
      if p == key {
        key
      } else {
        let root = self.find(p)
        self.parent[key] = root
        root
      }
    None => key
  }
}

///|
fn Dsu::union(self : Dsu, a : String, b : String) -> Unit {
  let ra = self.find(a)
  let rb = self.find(b)
  if ra == rb {
    return
  }
  let rra = self.rank.get(ra).unwrap_or(0)
  let rrb = self.rank.get(rb).unwrap_or(0)
  if rra < rrb {
    self.parent[ra] = rb
  } else if rra > rrb {
    self.parent[rb] = ra
  } else {
    self.parent[rb] = ra
    self.rank[ra] = rra + 1
  }
}

///|
fn component_priority(root : ElkNode) -> Int {
  let mut sum = 0
  for child in root.children {
    sum = sum + node_priority_rec(child)
  }
  sum
}

///|
fn node_priority_rec(node : ElkNode) -> Int {
  let mut sum = node.properties.get_int_or("elk.priority", 0)
  for child in node.children {
    sum = sum + node_priority_rec(child)
  }
  sum
}

///|
fn component_bounds(root : ElkNode) -> Bounds {
  let mut b = bounds_empty()
  for child in root.children {
    b = bounds_add_rect(b, child.x, child.y, child.width, child.height)
  }
  b
}

///|
fn component_bounds_edge(edge : ElkEdge, b : Bounds) -> Bounds {
  let mut b = b
  for section in edge.sections {
    b = bounds_add_point(b, section.start_point.x, section.start_point.y)
    b = bounds_add_point(b, section.end_point.x, section.end_point.y)
    for p in section.bend_points {
      b = bounds_add_point(b, p.x, p.y)
    }
  }
  b
}

///|
fn offset_component(root : ElkNode, dx : Double, dy : Double) -> Unit {
  for child in root.children {
    offset_node_shallow(child, dx, dy)
  }
  for edge in root.edges {
    offset_edge(edge, dx, dy)
  }
}

///|
fn offset_node_shallow(node : ElkNode, dx : Double, dy : Double) -> Unit {
  node.x = node.x + dx
  node.y = node.y + dy
  for label in node.labels {
    label.x = label.x + dx
    label.y = label.y + dy
  }
}

///|
fn offset_edge(edge : ElkEdge, dx : Double, dy : Double) -> Unit {
  for label in edge.labels {
    label.x = label.x + dx
    label.y = label.y + dy
  }
  for section in edge.sections {
    section.start_point = {
      x: section.start_point.x + dx,
      y: section.start_point.y + dy,
    }
    section.end_point = {
      x: section.end_point.x + dx,
      y: section.end_point.y + dy,
    }
    for i = 0; i < section.bend_points.length(); i = i + 1 {
      let p = section.bend_points[i]
      section.bend_points[i] = { x: p.x + dx, y: p.y + dy }
    }
  }
}

///|
fn component_size_without_padding(root : ElkNode) -> (Double, Double) {
  let b = component_bounds(root)
  if bounds_is_empty(b) {
    return (0.0, 0.0)
  }
  // Normalize the component such that its content bounds start at (0, 0).
  let shift_x = -b.min_x
  let shift_y = -b.min_y
  if shift_x != 0.0 || shift_y != 0.0 {
    offset_component(root, shift_x, shift_y)
  }
  let max_x = b.max_x + shift_x
  let max_y = b.max_y + shift_y
  (max_x, max_y)
}

///|
fn apply_graph_padding(root : ElkNode, options : LayoutOptions) -> Unit {
  let padding = options.padding.unwrap_or(ElkPadding::zero())
  if padding.left == 0.0 && padding.top == 0.0 {
    return
  }
  let dx = padding.left
  let dy = padding.top
  for child in root.children {
    offset_node_shallow(child, dx, dy)
  }
  for edge in root.edges {
    offset_edge(edge, dx, dy)
  }
}

///|
fn split_connected_components(root : ElkNode) -> Array[ElkNode] {
  if root.children.length() <= 1 {
    return [root]
  }
  let top_ids : Array[String] = []
  for child in root.children {
    top_ids.push(child.id)
  }
  let top_map = collect_top_level_map(root)
  let dsu = Dsu::new(top_ids)

  // Connect components by (undirected) edges.
  for edge in root.edges {
    for src in edge.sources {
      for dst in edge.targets {
        let src_top = match top_map.get(src) {
          Some(v) => v
          None => continue
        }
        let dst_top = match top_map.get(dst) {
          Some(v) => v
          None => continue
        }
        dsu.union(src_top, dst_top)
      }
    }
  }
  let comp_by_rep : Map[String, Int] = {}
  let components : Array[ComponentPart] = []
  for i, child in root.children {
    let rep = dsu.find(child.id)
    let idx = match comp_by_rep.get(rep) {
      Some(v) => v
      None => {
        let part_root = ElkNode::new("root")
        part_root.properties.copy_from(root.properties)
        let idx = components.length()
        components.push({ root: part_root, order_index: i })
        comp_by_rep[rep] = idx
        idx
      }
    }
    components[idx].root.children.push(child)
  }
  for edge in root.edges {
    let mut key : String? = None
    for src in edge.sources {
      match top_map.get(src) {
        Some(v) => {
          key = Some(dsu.find(v))
          break
        }
        None => ()
      }
    }
    if key is None {
      for dst in edge.targets {
        match top_map.get(dst) {
          Some(v) => {
            key = Some(dsu.find(v))
            break
          }
          None => ()
        }
      }
    }
    match key {
      Some(k) =>
        match comp_by_rep.get(k) {
          Some(idx) => components[idx].root.edges.push(edge)
          None => ()
        }
      None => ()
    }
  }

  // Return in stable model order (order of first encountered node).
  components.map(fn(p) { p.root })
}

///|
fn sort_components(components : Array[ComponentLayout]) -> Unit {
  components.sort_by(fn(a, b) {
    if a.priority != b.priority {
      // Higher priority first (ELK sorts by graph2.id - graph1.id)
      b.priority - a.priority
    } else {
      let area_a = a.width * a.height
      let area_b = b.width * b.height
      if area_a < area_b {
        -1
      } else if area_a > area_b {
        1
      } else {
        a.order_index - b.order_index
      }
    }
  })
}

///|
fn pack_components(
  components : Array[ComponentLayout],
  max_row_width : Double,
  component_spacing : Double,
) -> (Double, Double) {
  let mut xpos = 0.0
  let mut ypos = 0.0
  let mut highest_box = 0.0
  let mut broadest_row = component_spacing
  for comp in components {
    if xpos + comp.width > max_row_width {
      xpos = 0.0
      ypos = ypos + highest_box + component_spacing
      highest_box = 0.0
    }
    offset_component(comp.root, xpos, ypos)
    broadest_row = cc_max_d(broadest_row, xpos + comp.width)
    highest_box = cc_max_d(highest_box, comp.height)
    xpos = xpos + comp.width + component_spacing
  }
  (broadest_row, ypos + highest_box)
}

///|
fn combine_components(
  target : ElkNode,
  components : Array[ComponentLayout],
  width : Double,
  height : Double,
) -> Unit {
  target.children.clear()
  target.edges.clear()
  for comp in components {
    for child in comp.root.children {
      target.children.push(child)
    }
    for edge in comp.root.edges {
      target.edges.push(edge)
    }
  }
  target.width = width
  target.height = height
}

///|
fn elk_layered_layout_with_components(
  root : ElkNode,
  options : LayoutOptions,
) -> Unit {
  let separate = options.separate_connected_components.unwrap_or(true)
  if !separate || root.children.length() <= 1 {
    elk_layered_layout_impl(root, options)
    return
  }
  let parts = split_connected_components(root)
  if parts.length() <= 1 {
    elk_layered_layout_impl(root, options)
    return
  }
  let layouts : Array[ComponentLayout] = []
  for i, part in parts {
    elk_layered_layout_impl(part, options)
    let (w, h) = component_size_without_padding(part)
    layouts.push({
      root: part,
      width: w,
      height: h,
      priority: component_priority(part),
      order_index: i,
    })
  }
  sort_components(layouts)
  let aspect_ratio = options.aspect_ratio.unwrap_or(1.6)
  let component_spacing = options.component_component_spacing.unwrap_or(20.0)
  let mut max_width = 0.0
  let mut total_area = 0.0
  for comp in layouts {
    max_width = cc_max_d(max_width, comp.width)
    total_area = total_area + comp.width * comp.height
  }
  let target_width = cc_max_d(max_width, total_area.sqrt() * aspect_ratio)
  let (w, h) = pack_components(layouts, target_width, component_spacing)
  combine_components(root, layouts, w, h)
  apply_graph_padding(root, options)
}
