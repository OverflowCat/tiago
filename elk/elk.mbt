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
/// ELK.js Port for MoonBit - Main Entry Point
/// Eclipse Layout Kernel algorithm registry and dispatch

// ============================================================================
// Layout Error Types
// ============================================================================

///|
/// Errors that can occur during layout
pub suberror LayoutError {
  InvalidGraph(String)
}

///|
pub fn LayoutError::to_string(self : LayoutError) -> String {
  match self {
    InvalidGraph(msg) => "Invalid graph: " + msg
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn abs_double(a : Double) -> Double {
  if a < 0.0 {
    -a
  } else {
    a
  }
}

///|
fn sqrt_double(x : Double) -> Double {
  if x <= 0.0 {
    return 0.0
  }
  // Newton-Raphson method
  let mut guess = x / 2.0
  for iter = 0; iter < 20; iter = iter + 1 {
    guess = (guess + x / guess) / 2.0
  }
  guess
}

// ============================================================================
// Main Layout Function
// ============================================================================

///|
/// Layout an ELK graph using the specified options
pub fn layout(
  graph : ElkNode,
  options : LayoutOptions,
) -> Unit raise LayoutError {
  let algorithm = match options.algorithm {
    Some(alg) => alg
    None => Layered
  }
  match algorithm {
    Layered => layout_layered(graph, options)
    Force => layout_force(graph, options)
    Stress => layout_stress(graph, options)
    Radial => layout_radial(graph, options)
    MrTree => layout_tree(graph, options)
    Box => layout_box(graph, options)
    RectPacking => layout_rectpacking(graph, options)
    TopDownPacking => layout_topdown(graph, options)
    DisCo => layout_disco(graph, options)
    Fixed => layout_fixed(graph, options)
    Random => layout_random(graph, options)
    SporeCompaction => layout_spore_compaction(graph, options)
    SporeOverlap => layout_spore_overlap(graph, options)
  }
}

// ============================================================================
// Layered (Sugiyama) Algorithm
// ============================================================================

///|
/// Layered (Sugiyama) layout algorithm - simplified inline version
fn layout_layered(graph : ElkNode, options : LayoutOptions) -> Unit {
  if graph.children.is_empty() {
    return
  }
  let direction = options.direction.unwrap_or(Down)
  let node_spacing = options.node_node_spacing.unwrap_or(20.0)
  let layer_spacing = options.node_node_between_layers_spacing.unwrap_or(40.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))

  // Build adjacency for layer assignment
  let node_map : Map[String, ElkNode] = {}
  let in_degree : Map[String, Int] = {}
  let out_edges : Map[String, Array[String]] = {}
  for node in graph.children {
    node_map[node.id] = node
    in_degree[node.id] = 0
    out_edges[node.id] = []
  }

  // Build edge relationships
  for edge in graph.edges {
    if edge.sources.length() > 0 && edge.targets.length() > 0 {
      let src = edge.sources[0]
      let tgt = edge.targets[0]
      if node_map.contains(src) && node_map.contains(tgt) {
        match out_edges.get(src) {
          Some(arr) => arr.push(tgt)
          None => ()
        }
        in_degree[tgt] = in_degree.get(tgt).unwrap_or(0) + 1
      }
    }
  }

  // Check if we have any edges at all
  let has_edges = graph.edges.length() > 0

  // Topological sort for layer assignment (Kahn's algorithm)
  let layers : Array[Array[ElkNode]] = []
  let layer_map : Map[String, Int] = {}
  if has_edges {
    let queue : Array[String] = []

    // Find sources
    for node in graph.children {
      if in_degree.get(node.id).unwrap_or(0) == 0 {
        queue.push(node.id)
        layer_map[node.id] = 0
      }
    }

    // Process nodes
    while queue.length() > 0 {
      let node_id = queue.remove(0)
      let node_layer = layer_map.get(node_id).unwrap_or(0)

      // Ensure layer exists
      while layers.length() <= node_layer {
        layers.push([])
      }
      match node_map.get(node_id) {
        Some(node) => layers[node_layer].push(node)
        None => ()
      }

      // Process outgoing edges
      for target_id in out_edges.get(node_id).unwrap_or([]) {
        let new_degree = in_degree.get(target_id).unwrap_or(1) - 1
        in_degree[target_id] = new_degree
        let target_layer = max_double(
          layer_map.get(target_id).unwrap_or(0).to_double(),
          (node_layer + 1).to_double(),
        ).to_int()
        layer_map[target_id] = target_layer
        if new_degree == 0 {
          queue.push(target_id)
        }
      }
    }

    // Handle nodes not reached (disconnected or cycles)
    for node in graph.children {
      if !layer_map.contains(node.id) {
        // Put disconnected nodes in their own layers based on definition order
        let new_layer = layers.length()
        layers.push([node])
        layer_map[node.id] = new_layer
      }
    }
  } else {
    // No edges: put each node in its own layer to respect definition order
    for node in graph.children {
      layers.push([node])
      layer_map[node.id] = layers.length() - 1
    }
  }

  // Handle any remaining nodes not assigned (shouldn't happen but just in case)
  for node in graph.children {
    if !layer_map.contains(node.id) {
      if layers.is_empty() {
        layers.push([])
      }
      layers[0].push(node)
      layer_map[node.id] = 0
    }
  }

  // First, recursively layout compound nodes to determine their final sizes
  for node in graph.children {
    if node.children.length() > 0 {
      layout_layered(node, options)
      // Update node size to contain its children
      let (child_w, child_h) = node.calculate_bounds()
      node.width = child_w + padding.left + padding.right
      node.height = child_h + padding.top + padding.bottom
    }
    // Ensure minimum size for all nodes
    if node.width < 1.0 {
      node.width = 60.0
    }
    if node.height < 1.0 {
      node.height = 40.0
    }
  }

  // Position nodes using their final sizes
  let is_horizontal = direction.is_horizontal()
  let mut layer_offset = if is_horizontal { padding.left } else { padding.top }
  for layer in layers {
    let mut max_size = 0.0
    let mut node_offset = if is_horizontal { padding.top } else { padding.left }
    for node in layer {
      if is_horizontal {
        node.x = layer_offset
        node.y = node_offset
        node_offset = node_offset + node.height + node_spacing
        max_size = max_double(max_size, node.width)
      } else {
        node.x = node_offset
        node.y = layer_offset
        node_offset = node_offset + node.width + node_spacing
        max_size = max_double(max_size, node.height)
      }
    }
    layer_offset = layer_offset + max_size + layer_spacing
  }

  // Resolve any remaining overlaps
  resolve_overlaps(graph.children, node_spacing, is_horizontal)

  // Route edges with orthogonal bends
  route_edges_orthogonal(graph, direction)

  // Update graph bounds
  update_graph_bounds(graph, padding)
}

///|
/// Resolve any overlapping nodes by shifting them apart
fn resolve_overlaps(
  nodes : Array[ElkNode],
  spacing : Double,
  is_horizontal : Bool,
) -> Unit {
  // Simple O(n^2) overlap resolution
  let mut changed = true
  let mut iterations = 0
  let max_iterations = 100
  while changed && iterations < max_iterations {
    changed = false
    iterations = iterations + 1
    for i in 0..<nodes.length() {
      for j in (i + 1)..<nodes.length() {
        let a = nodes[i]
        let b = nodes[j]

        // Check for overlap
        let overlap_x = a.x < b.x + b.width && a.x + a.width > b.x
        let overlap_y = a.y < b.y + b.height && a.y + a.height > b.y
        if overlap_x && overlap_y {
          // Nodes overlap - separate them
          changed = true
          if is_horizontal {
            // Separate horizontally first
            if a.x <= b.x {
              b.x = a.x + a.width + spacing
            } else {
              a.x = b.x + b.width + spacing
            }
            // Separate vertically first
          } else if a.y <= b.y {
            b.y = a.y + a.height + spacing
          } else {
            a.y = b.y + b.height + spacing
          }
        }
      }
    }
  }
}

///|
/// Route edges with orthogonal (90-degree) bends
fn route_edges_orthogonal(graph : ElkNode, direction : LayoutDirection) -> Unit {
  let is_vertical = direction.is_vertical()
  let node_map : Map[String, ElkNode] = {}
  for node in graph.children {
    node_map[node.id] = node
  }
  for edge in graph.edges {
    if edge.sources.length() == 0 || edge.targets.length() == 0 {
      continue
    }
    let src_id = edge.sources[0]
    let tgt_id = edge.targets[0]
    match (node_map.get(src_id), node_map.get(tgt_id)) {
      (Some(source), Some(target)) => {
        let section = ElkEdgeSection::new(edge.id + "_s0")
        if is_vertical {
          // Determine if this is a forward or backward edge
          let src_center_y = source.y + source.height / 2.0
          let tgt_center_y = target.y + target.height / 2.0
          let is_forward = tgt_center_y > src_center_y
          let src_x = source.x + source.width / 2.0
          let tgt_x = target.x + target.width / 2.0
          let (src_y, tgt_y) = if is_forward {
            (source.y + source.height, target.y)
          } else {
            (source.y, target.y + target.height)
          }
          section.start_point = ElkPoint::new(src_x, src_y)
          section.end_point = ElkPoint::new(tgt_x, tgt_y)

          // Add bend if not aligned
          if abs_double(src_x - tgt_x) > 1.0 {
            let mid_y = (src_y + tgt_y) / 2.0
            section.bend_points.push(ElkPoint::new(src_x, mid_y))
            section.bend_points.push(ElkPoint::new(tgt_x, mid_y))
          }
        } else {
          // Horizontal layout
          let src_center_x = source.x + source.width / 2.0
          let tgt_center_x = target.x + target.width / 2.0
          let is_forward = tgt_center_x > src_center_x
          let src_y = source.y + source.height / 2.0
          let tgt_y = target.y + target.height / 2.0
          let (src_x, tgt_x) = if is_forward {
            (source.x + source.width, target.x)
          } else {
            (source.x, target.x + target.width)
          }
          section.start_point = ElkPoint::new(src_x, src_y)
          section.end_point = ElkPoint::new(tgt_x, tgt_y)
          if abs_double(src_y - tgt_y) > 1.0 {
            let mid_x = (src_x + tgt_x) / 2.0
            section.bend_points.push(ElkPoint::new(mid_x, src_y))
            section.bend_points.push(ElkPoint::new(mid_x, tgt_y))
          }
        }
        edge.sections.clear()
        edge.sections.push(section)
      }
      _ => ()
    }
  }
}

// ============================================================================
// Force-Directed Algorithm (Fruchterman-Reingold)
// ============================================================================

///|
/// Force-directed layout using Fruchterman-Reingold algorithm
fn layout_force(graph : ElkNode, options : LayoutOptions) -> Unit {
  if graph.children.is_empty() {
    return
  }
  let iterations = options.force_iterations.unwrap_or(300)
  let repulsion = options.force_repulsion.unwrap_or(5.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let n = graph.children.length()
  let area = 500.0 * 500.0
  let k = sqrt_double(area / n.to_double()) * repulsion

  // Initialize positions randomly
  let mut x_pos = padding.left + 50.0
  let mut y_pos = padding.top + 50.0
  for node in graph.children {
    node.x = x_pos
    node.y = y_pos
    x_pos = x_pos + 80.0
    if x_pos > 400.0 {
      x_pos = padding.left + 50.0
      y_pos = y_pos + 80.0
    }
  }

  // Build edge map
  let edges : Array[(Int, Int)] = []
  let node_indices : Map[String, Int] = {}
  for i, node in graph.children {
    node_indices[node.id] = i
  }
  for edge in graph.edges {
    if edge.sources.length() > 0 && edge.targets.length() > 0 {
      match
        (node_indices.get(edge.sources[0]), node_indices.get(edge.targets[0])) {
        (Some(i), Some(j)) => edges.push((i, j))
        _ => ()
      }
    }
  }

  // Force-directed iterations
  let disp_x : Array[Double] = Array::make(n, 0.0)
  let disp_y : Array[Double] = Array::make(n, 0.0)
  let mut temperature = 100.0
  for iter = 0; iter < iterations; iter = iter + 1 {
    // Reset displacements
    for i = 0; i < n; i = i + 1 {
      disp_x[i] = 0.0
      disp_y[i] = 0.0
    }

    // Repulsive forces between all pairs
    for i = 0; i < n; i = i + 1 {
      for j = i + 1; j < n; j = j + 1 {
        let dx = graph.children[i].x - graph.children[j].x
        let dy = graph.children[i].y - graph.children[j].y
        let dist = max_double(sqrt_double(dx * dx + dy * dy), 0.01)
        let force = k * k / dist
        let fx = dx / dist * force
        let fy = dy / dist * force
        disp_x[i] = disp_x[i] + fx
        disp_y[i] = disp_y[i] + fy
        disp_x[j] = disp_x[j] - fx
        disp_y[j] = disp_y[j] - fy
      }
    }

    // Attractive forces for edges
    for edge in edges {
      let (i, j) = edge
      let dx = graph.children[i].x - graph.children[j].x
      let dy = graph.children[i].y - graph.children[j].y
      let dist = max_double(sqrt_double(dx * dx + dy * dy), 0.01)
      let force = dist * dist / k
      let fx = dx / dist * force
      let fy = dy / dist * force
      disp_x[i] = disp_x[i] - fx
      disp_y[i] = disp_y[i] - fy
      disp_x[j] = disp_x[j] + fx
      disp_y[j] = disp_y[j] + fy
    }

    // Apply displacements with temperature limiting
    for i = 0; i < n; i = i + 1 {
      let disp = sqrt_double(disp_x[i] * disp_x[i] + disp_y[i] * disp_y[i])
      if disp > 0.01 {
        let scale = min_double(disp, temperature) / disp
        graph.children[i].x = graph.children[i].x + disp_x[i] * scale
        graph.children[i].y = graph.children[i].y + disp_y[i] * scale
      }
    }

    // Cool down
    temperature = temperature * 0.95
  }

  // Normalize positions
  let mut min_x = graph.children[0].x
  let mut min_y = graph.children[0].y
  for node in graph.children {
    min_x = min_double(min_x, node.x)
    min_y = min_double(min_y, node.y)
  }
  for node in graph.children {
    node.x = node.x - min_x + padding.left
    node.y = node.y - min_y + padding.top
  }
  update_graph_bounds(graph, padding)
}

// ============================================================================
// Stress Majorization Algorithm
// ============================================================================

///|
/// Stress majorization layout
fn layout_stress(graph : ElkNode, options : LayoutOptions) -> Unit {
  if graph.children.is_empty() {
    return
  }
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let desired_distance = options.node_node_spacing.unwrap_or(100.0)
  let iterations = 50
  let n = graph.children.length()

  // Build distance matrix (graph-theoretic distances)
  let dist : Array[Array[Double]] = []
  for row = 0; row < n; row = row + 1 {
    dist.push(Array::make(n, 1000.0))
  }
  for i = 0; i < n; i = i + 1 {
    dist[i][i] = 0.0
  }

  // Build edge connectivity
  let node_indices : Map[String, Int] = {}
  for i, node in graph.children {
    node_indices[node.id] = i
  }
  for edge in graph.edges {
    if edge.sources.length() > 0 && edge.targets.length() > 0 {
      match
        (node_indices.get(edge.sources[0]), node_indices.get(edge.targets[0])) {
        (Some(i), Some(j)) => {
          dist[i][j] = 1.0
          dist[j][i] = 1.0
        }
        _ => ()
      }
    }
  }

  // Floyd-Warshall for all-pairs shortest paths
  for k = 0; k < n; k = k + 1 {
    for i = 0; i < n; i = i + 1 {
      for j = 0; j < n; j = j + 1 {
        if dist[i][k] + dist[k][j] < dist[i][j] {
          dist[i][j] = dist[i][k] + dist[k][j]
        }
      }
    }
  }

  // Scale distances
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      dist[i][j] = dist[i][j] * desired_distance
    }
  }

  // Initialize positions
  let mut x_pos = padding.left + 50.0
  let mut y_pos = padding.top + 50.0
  for node in graph.children {
    node.x = x_pos
    node.y = y_pos
    x_pos = x_pos + 100.0
    if x_pos > 500.0 {
      x_pos = padding.left + 50.0
      y_pos = y_pos + 100.0
    }
  }

  // Stress majorization iterations
  for iter = 0; iter < iterations; iter = iter + 1 {
    for i = 0; i < n; i = i + 1 {
      let mut new_x = 0.0
      let mut new_y = 0.0
      let mut weight_sum = 0.0
      for j = 0; j < n; j = j + 1 {
        if i != j && dist[i][j] < 500.0 {
          let dx = graph.children[i].x - graph.children[j].x
          let dy = graph.children[i].y - graph.children[j].y
          let current_dist = max_double(sqrt_double(dx * dx + dy * dy), 0.01)
          let weight = 1.0 / (dist[i][j] * dist[i][j])
          new_x = new_x +
            weight * (graph.children[j].x + dist[i][j] * dx / current_dist)
          new_y = new_y +
            weight * (graph.children[j].y + dist[i][j] * dy / current_dist)
          weight_sum = weight_sum + weight
        }
      }
      if weight_sum > 0.0 {
        graph.children[i].x = new_x / weight_sum
        graph.children[i].y = new_y / weight_sum
      }
    }
  }

  // Normalize positions
  let mut min_x = graph.children[0].x
  let mut min_y = graph.children[0].y
  for node in graph.children {
    min_x = min_double(min_x, node.x)
    min_y = min_double(min_y, node.y)
  }
  for node in graph.children {
    node.x = node.x - min_x + padding.left
    node.y = node.y - min_y + padding.top
  }
  update_graph_bounds(graph, padding)
}

// ============================================================================
// Radial Layout Algorithm
// ============================================================================

///|
/// Radial layout - nodes arranged in concentric circles
fn layout_radial(graph : ElkNode, options : LayoutOptions) -> Unit {
  if graph.children.is_empty() {
    return
  }
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let layer_spacing = options.node_node_between_layers_spacing.unwrap_or(80.0)

  // Build adjacency
  let node_map : Map[String, ElkNode] = {}
  let neighbors : Map[String, Array[String]] = {}
  for node in graph.children {
    node_map[node.id] = node
    neighbors[node.id] = []
  }
  for edge in graph.edges {
    if edge.sources.length() > 0 && edge.targets.length() > 0 {
      let src = edge.sources[0]
      let tgt = edge.targets[0]
      if node_map.contains(src) && node_map.contains(tgt) {
        match neighbors.get(src) {
          Some(arr) => arr.push(tgt)
          None => ()
        }
        match neighbors.get(tgt) {
          Some(arr) => arr.push(src)
          None => ()
        }
      }
    }
  }

  // BFS to assign levels
  let level : Map[String, Int] = {}
  let queue : Array[String] = []
  let root_id = graph.children[0].id
  level[root_id] = 0
  queue.push(root_id)
  while queue.length() > 0 {
    let node_id = queue.remove(0)
    let node_level = level.get(node_id).unwrap_or(0)
    for neighbor_id in neighbors.get(node_id).unwrap_or([]) {
      if !level.contains(neighbor_id) {
        level[neighbor_id] = node_level + 1
        queue.push(neighbor_id)
      }
    }
  }

  // Handle disconnected nodes
  for node in graph.children {
    if !level.contains(node.id) {
      level[node.id] = 0
    }
  }

  // Group by level
  let levels : Map[Int, Array[ElkNode]] = {}
  let mut max_level = 0
  for node in graph.children {
    let l = level.get(node.id).unwrap_or(0)
    if !levels.contains(l) {
      levels[l] = []
    }
    match levels.get(l) {
      Some(arr) => arr.push(node)
      None => ()
    }
    if l > max_level {
      max_level = l
    }
  }

  // Calculate center
  let center_x = 250.0 + padding.left
  let center_y = 250.0 + padding.top

  // Position nodes in circles
  for l = 0; l <= max_level; l = l + 1 {
    let nodes = levels.get(l).unwrap_or([])
    let radius = l.to_double() * layer_spacing
    let count = nodes.length()
    for i, node in nodes {
      if radius < 1.0 {
        // Center node
        node.x = center_x - node.width / 2.0
        node.y = center_y - node.height / 2.0
      } else {
        let angle = 2.0 * 3.14159265359 * i.to_double() / count.to_double()
        // Approximate cos/sin using Taylor series
        let cos_a = 1.0 -
          angle * angle / 2.0 +
          angle * angle * angle * angle / 24.0
        let sin_a = angle - angle * angle * angle / 6.0
        node.x = center_x + radius * cos_a - node.width / 2.0
        node.y = center_y + radius * sin_a - node.height / 2.0
      }
    }
  }
  update_graph_bounds(graph, padding)
}

// ============================================================================
// Tree (MrTree) Layout Algorithm
// ============================================================================

///|
/// Tree layout - hierarchical tree structure
fn layout_tree(graph : ElkNode, options : LayoutOptions) -> Unit {
  if graph.children.is_empty() {
    return
  }
  let direction = options.direction.unwrap_or(Down)
  let node_spacing = options.node_node_spacing.unwrap_or(20.0)
  let layer_spacing = options.node_node_between_layers_spacing.unwrap_or(40.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))

  // Build parent-child relationships
  let children_map : Map[String, Array[String]] = {}
  let has_parent : Map[String, Bool] = {}
  for node in graph.children {
    children_map[node.id] = []
    has_parent[node.id] = false
  }
  for edge in graph.edges {
    if edge.sources.length() > 0 && edge.targets.length() > 0 {
      let src = edge.sources[0]
      let tgt = edge.targets[0]
      if children_map.contains(src) && children_map.contains(tgt) {
        match children_map.get(src) {
          Some(arr) => arr.push(tgt)
          None => ()
        }
        has_parent[tgt] = true
      }
    }
  }

  // Find roots
  let roots : Array[String] = []
  for node in graph.children {
    if !has_parent.get(node.id).unwrap_or(false) {
      roots.push(node.id)
    }
  }

  // If no roots, use first node
  if roots.is_empty() && graph.children.length() > 0 {
    roots.push(graph.children[0].id)
  }
  let node_map : Map[String, ElkNode] = {}
  for node in graph.children {
    node_map[node.id] = node
  }

  // Calculate subtree widths
  let subtree_width : Map[String, Double] = {}
  fn calc_width(node_id : String) -> Double {
    match subtree_width.get(node_id) {
      Some(w) => w
      None => {
        let node = node_map.get(node_id)
        let node_w = match node {
          Some(n) => n.width
          None => 60.0
        }
        let kids = children_map.get(node_id).unwrap_or([])
        if kids.is_empty() {
          subtree_width[node_id] = node_w
          node_w
        } else {
          let mut total = 0.0
          for child_id in kids {
            total = total + calc_width(child_id) + node_spacing
          }
          let width = max_double(node_w, total - node_spacing)
          subtree_width[node_id] = width
          width
        }
      }
    }
  }

  for root_id in roots {
    calc_width(root_id) |> ignore
  }

  // Position nodes
  let is_horizontal = direction.is_horizontal()
  let mut root_offset = if is_horizontal { padding.top } else { padding.left }
  fn position_subtree(
    node_id : String,
    depth : Int,
    offset : Double,
  ) -> Double {
    let layer_pos = if is_horizontal {
      padding.left + depth.to_double() * layer_spacing
    } else {
      padding.top + depth.to_double() * layer_spacing
    }
    let width = subtree_width.get(node_id).unwrap_or(60.0)
    let kids = children_map.get(node_id).unwrap_or([])
    match node_map.get(node_id) {
      Some(node) =>
        if is_horizontal {
          node.x = layer_pos
          if kids.is_empty() {
            node.y = offset + (width - node.height) / 2.0
          } else {
            let mut child_offset = offset
            for child_id in kids {
              child_offset = position_subtree(child_id, depth + 1, child_offset)
            }
            // Center parent over children
            let first_kid = node_map.get(kids[0])
            let last_kid = node_map.get(kids[kids.length() - 1])
            match (first_kid, last_kid) {
              (Some(f), Some(l)) =>
                node.y = (f.y + l.y + l.height - node.height) / 2.0
              _ => node.y = offset + width / 2.0 - node.height / 2.0
            }
          }
        } else {
          node.y = layer_pos
          if kids.is_empty() {
            node.x = offset + (width - node.width) / 2.0
          } else {
            let mut child_offset = offset
            for child_id in kids {
              child_offset = position_subtree(child_id, depth + 1, child_offset)
            }
            let first_kid = node_map.get(kids[0])
            let last_kid = node_map.get(kids[kids.length() - 1])
            match (first_kid, last_kid) {
              (Some(f), Some(l)) =>
                node.x = (f.x + l.x + l.width - node.width) / 2.0
              _ => node.x = offset + width / 2.0 - node.width / 2.0
            }
          }
        }
      None => ()
    }
    offset + width + node_spacing
  }

  for root_id in roots {
    root_offset = position_subtree(root_id, 0, root_offset)
  }
  update_graph_bounds(graph, padding)
}

// ============================================================================
// Box Packing Algorithm
// ============================================================================

///|
/// Box packing - simple row-based packing
fn layout_box(graph : ElkNode, options : LayoutOptions) -> Unit {
  if graph.children.is_empty() {
    return
  }
  let spacing = options.node_node_spacing.unwrap_or(20.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let max_width = options.aspect_ratio.unwrap_or(2.0) * 300.0
  let mut x = padding.left
  let mut y = padding.top
  let mut row_height = 0.0
  for node in graph.children {
    if x + node.width > max_width && x > padding.left {
      // New row
      x = padding.left
      y = y + row_height + spacing
      row_height = 0.0
    }
    node.x = x
    node.y = y
    x = x + node.width + spacing
    row_height = max_double(row_height, node.height)
  }
  update_graph_bounds(graph, padding)
}

// ============================================================================
// Rectangle Packing Algorithm
// ============================================================================

///|
/// Rectangle packing - more sophisticated bin packing
fn layout_rectpacking(graph : ElkNode, options : LayoutOptions) -> Unit {
  if graph.children.is_empty() {
    return
  }
  let spacing = options.node_node_spacing.unwrap_or(10.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))

  // Sort by height (tallest first)
  let sorted = graph.children.copy()
  sorted.sort_by(fn(a, b) {
    if a.height > b.height {
      -1
    } else if a.height < b.height {
      1
    } else {
      0
    }
  })

  // Shelf-based packing
  let shelves : Array[(Double, Double, Double)] = [] // (y, height, next_x)
  for node in sorted {
    // Find best shelf
    let mut best_shelf = -1
    let mut best_waste = 1000000.0
    for i, shelf in shelves {
      let (_, shelf_height, _) = shelf
      if node.height <= shelf_height {
        let waste = shelf_height - node.height
        if waste < best_waste {
          best_waste = waste
          best_shelf = i
        }
      }
    }
    if best_shelf >= 0 {
      // Use existing shelf
      let (y, h, next_x) = shelves[best_shelf]
      node.x = next_x
      node.y = y
      shelves[best_shelf] = (y, h, next_x + node.width + spacing)
    } else {
      // Create new shelf
      let new_y = if shelves.is_empty() {
        padding.top
      } else {
        let (y, h, _) = shelves[shelves.length() - 1]
        y + h + spacing
      }
      node.x = padding.left
      node.y = new_y
      shelves.push((new_y, node.height, padding.left + node.width + spacing))
    }
  }
  update_graph_bounds(graph, padding)
}

// ============================================================================
// Top-Down Packing Algorithm
// ============================================================================

///|
/// Top-down packing - vertical stack layout
fn layout_topdown(graph : ElkNode, options : LayoutOptions) -> Unit {
  if graph.children.is_empty() {
    return
  }
  let spacing = options.node_node_spacing.unwrap_or(20.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let mut y = padding.top
  let mut max_width = 0.0
  for node in graph.children {
    node.x = padding.left
    node.y = y
    y = y + node.height + spacing
    max_width = max_double(max_width, node.width)
  }

  // Center nodes horizontally
  for node in graph.children {
    node.x = padding.left + (max_width - node.width) / 2.0
  }
  update_graph_bounds(graph, padding)
}

// ============================================================================
// DisCo (Disconnected Components) Algorithm
// ============================================================================

///|
/// DisCo - handle disconnected components
fn layout_disco(graph : ElkNode, options : LayoutOptions) -> Unit {
  if graph.children.is_empty() {
    return
  }
  let spacing = options.component_component_spacing.unwrap_or(30.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))

  // Find connected components using union-find
  let parent : Map[String, String] = {}
  for node in graph.children {
    parent[node.id] = node.id
  }
  fn find(id : String) -> String {
    let p = parent.get(id).unwrap_or(id)
    if p == id {
      id
    } else {
      let root = find(p)
      parent[id] = root
      root
    }
  }

  fn union(a : String, b : String) -> Unit {
    let ra = find(a)
    let rb = find(b)
    if ra != rb {
      parent[ra] = rb
    }
  }

  // Union nodes connected by edges
  for edge in graph.edges {
    if edge.sources.length() > 0 && edge.targets.length() > 0 {
      union(edge.sources[0], edge.targets[0])
    }
  }

  // Group by component
  let components : Map[String, Array[ElkNode]] = {}
  for node in graph.children {
    let root = find(node.id)
    if !components.contains(root) {
      components[root] = []
    }
    match components.get(root) {
      Some(arr) => arr.push(node)
      None => ()
    }
  }

  // Layout each component and arrange them
  let mut x_offset = padding.left
  for _, comp_nodes in components {
    // Simple box layout for each component
    let mut y = padding.top
    let mut max_width = 0.0
    for node in comp_nodes {
      node.x = x_offset
      node.y = y
      y = y + node.height + 10.0
      max_width = max_double(max_width, node.width)
    }
    x_offset = x_offset + max_width + spacing
  }
  update_graph_bounds(graph, padding)
}

// ============================================================================
// Fixed Layout
// ============================================================================

///|
/// Fixed layout (preserves existing positions)
fn layout_fixed(
  graph : ElkNode,
  options : LayoutOptions,
) -> Unit raise LayoutError {
  let _ = options
  // Validate all nodes have positions
  for node in graph.all_nodes() {
    if node.width <= 0.0 || node.height <= 0.0 {
      raise InvalidGraph(
        "Node " + node.id + " has invalid size for fixed layout",
      )
    }
  }
}

// ============================================================================
// Random Layout
// ============================================================================

///|
/// Random layout algorithm
fn layout_random(graph : ElkNode, options : LayoutOptions) -> Unit {
  let spacing = options.node_node_spacing.unwrap_or(20.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let mut x = padding.left
  let mut y = padding.top
  let mut row_height = 0.0
  for node in graph.children {
    node.x = x
    node.y = y
    x = x + node.width + spacing
    if node.height > row_height {
      row_height = node.height
    }
    if x > 500.0 {
      x = padding.left
      y = y + row_height + spacing
      row_height = 0.0
    }
  }
  update_graph_bounds(graph, padding)
}

// ============================================================================
// SPOrE Algorithms
// ============================================================================

///|
/// SPOrE compaction algorithm
fn layout_spore_compaction(graph : ElkNode, options : LayoutOptions) -> Unit {
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))

  // Simple compaction: remove gaps
  if graph.children.is_empty() {
    return
  }

  // Sort by current position
  let sorted = graph.children.copy()
  sorted.sort_by(fn(a, b) {
    if a.y < b.y {
      -1
    } else if a.y > b.y {
      1
    } else if a.x < b.x {
      -1
    } else if a.x > b.x {
      1
    } else {
      0
    }
  })

  // Compact positions
  let spacing = options.node_node_spacing.unwrap_or(10.0)
  let mut y = padding.top
  let mut x = padding.left
  let mut row_height = 0.0
  let mut prev_y = sorted[0].y
  for node in sorted {
    if abs_double(node.y - prev_y) > 50.0 {
      // New row
      x = padding.left
      y = y + row_height + spacing
      row_height = 0.0
      prev_y = node.y
    }
    node.x = x
    node.y = y
    x = x + node.width + spacing
    row_height = max_double(row_height, node.height)
  }
  update_graph_bounds(graph, padding)
}

///|
/// SPOrE overlap removal algorithm
fn layout_spore_overlap(graph : ElkNode, options : LayoutOptions) -> Unit {
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  let spacing = options.node_node_spacing.unwrap_or(10.0)

  // Iteratively remove overlaps
  for iter = 0; iter < 50; iter = iter + 1 {
    let mut had_overlap = false
    for i, node_a in graph.children {
      for j = i + 1; j < graph.children.length(); j = j + 1 {
        let node_b = graph.children[j]

        // Check overlap
        let overlap_x = min_double(
            node_a.x + node_a.width,
            node_b.x + node_b.width,
          ) -
          max_double(node_a.x, node_b.x)
        let overlap_y = min_double(
            node_a.y + node_a.height,
            node_b.y + node_b.height,
          ) -
          max_double(node_a.y, node_b.y)
        if overlap_x > 0.0 && overlap_y > 0.0 {
          had_overlap = true
          // Push apart
          let push_x = (overlap_x + spacing) / 2.0
          let push_y = (overlap_y + spacing) / 2.0
          if overlap_x < overlap_y {
            // Push horizontally
            if node_a.x < node_b.x {
              node_a.x = node_a.x - push_x
              node_b.x = node_b.x + push_x
            } else {
              node_a.x = node_a.x + push_x
              node_b.x = node_b.x - push_x
            }
            // Push vertically
          } else if node_a.y < node_b.y {
            node_a.y = node_a.y - push_y
            node_b.y = node_b.y + push_y
          } else {
            node_a.y = node_a.y + push_y
            node_b.y = node_b.y - push_y
          }
        }
      }
    }
    if !had_overlap {
      break
    }
  }

  // Normalize to positive coordinates
  if graph.children.length() > 0 {
    let mut min_x = graph.children[0].x
    let mut min_y = graph.children[0].y
    for node in graph.children {
      min_x = min_double(min_x, node.x)
      min_y = min_double(min_y, node.y)
    }
    for node in graph.children {
      node.x = node.x - min_x + padding.left
      node.y = node.y - min_y + padding.top
    }
  }
  update_graph_bounds(graph, padding)
}

// ============================================================================
// Utility Functions
// ============================================================================

///|
fn update_graph_bounds(graph : ElkNode, padding : ElkPadding) -> Unit {
  let mut max_x = 0.0
  let mut max_y = 0.0
  for node in graph.children {
    max_x = max_double(max_x, node.x + node.width)
    max_y = max_double(max_y, node.y + node.height)
  }
  graph.width = max_x + padding.right
  graph.height = max_y + padding.bottom
}

///|
/// Get list of available algorithms
pub fn available_algorithms() -> Array[LayoutAlgorithm] {
  [
    Layered,
    Force,
    Stress,
    Radial,
    MrTree,
    Box,
    RectPacking,
    TopDownPacking,
    DisCo,
    Fixed,
    Random,
    SporeCompaction,
    SporeOverlap,
  ]
}

///|
/// Check if an algorithm is implemented
pub fn is_algorithm_implemented(alg : LayoutAlgorithm) -> Bool {
  // All algorithms are now implemented
  let _ = alg
  true
}

///|
/// Get default options for an algorithm
pub fn default_options(alg : LayoutAlgorithm) -> LayoutOptions {
  match alg {
    Layered => LayoutOptions::layered()
    Force => LayoutOptions::force()
    Stress => LayoutOptions::stress()
    Radial => LayoutOptions::radial()
    MrTree => LayoutOptions::tree()
    _ => LayoutOptions::new().with_algorithm(alg)
  }
}
