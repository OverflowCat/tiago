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
/// ELK Layered Algorithm - Main Coordinator
/// Implements the Sugiyama-style layered layout algorithm with 5 phases:
/// 1. Cycle Breaking
/// 2. Layer Assignment
/// 3. Crossing Minimization
/// 4. Node Placement
/// 5. Edge Routing

// ============================================================================
// Helper Functions
// ============================================================================

///|
fn find_node_index(nodes : Array[LNode], id : String) -> Int {
  for i, n in nodes {
    if n.id == id {
      return i
    }
  }
  -1
}

///|
fn find_edge_index(edges : Array[LEdge], id : String) -> Int {
  for i, e in edges {
    if e.id == id {
      return i
    }
  }
  -1
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

// ============================================================================
// Main Entry Point
// ============================================================================

///|
/// Execute the layered layout algorithm
pub fn layout(
  graph : @elk.ElkNode,
  options : @elk.LayoutOptions,
) -> Unit raise @elk.LayoutError {
  // First, recursively layout compound nodes (children with their own children)
  for child in graph.children {
    if child.children.length() > 0 {
      layout(child, options) catch {
        _ => () // Ignore layout errors in nested graphs
      }
      // Update child size to contain its children
      let (child_w, child_h) = child.calculate_bounds()
      let padding = options.padding.unwrap_or(@elk.ElkPadding::uniform(12.0))
      child.width = child_w + padding.left + padding.right
      child.height = child_h + padding.top + padding.bottom
    }
  }

  // Convert ElkNode to internal LGraph representation
  let lgraph = LGraph::from_elk_node(graph)

  // Get options with defaults
  let direction = match options.direction {
    Some(d) => d
    None => @elk.Down
  }
  let thoroughness = match options.thoroughness {
    Some(t) => t
    None => 7
  }

  // Phase 1: Cycle Breaking
  let cycle_strategy = match options.cycle_breaking_strategy {
    Some(s) => s
    None => @elk.GreedyModelOrder
  }
  break_cycles(lgraph, cycle_strategy)

  // Phase 2: Layer Assignment
  let layer_strategy = match options.layering_strategy {
    Some(s) => s
    None => @elk.LongestPath
  }
  assign_layers(lgraph, layer_strategy)

  // Initialize layer structure
  lgraph.initialize_layers()

  // Insert dummy nodes for long edges
  insert_dummy_nodes(lgraph)

  // Phase 3: Crossing Minimization
  let crossing_strategy = match options.crossing_min_strategy {
    Some(s) => s
    None => @elk.LayerSweep
  }
  minimize_crossings(lgraph, crossing_strategy, thoroughness)

  // Phase 4: Node Placement
  let placement_strategy = match options.node_placement_strategy {
    Some(s) => s
    None => @elk.BrandesKoepf
  } // Default to Brandes-Koepf like ELK
  place_nodes(lgraph, options, placement_strategy, direction)

  // Phase 5: Edge Routing
  let routing = match options.edge_routing {
    Some(r) => r
    None => @elk.Orthogonal
  }
  route_edges(lgraph, routing, direction)

  // Restore reversed edges
  restore_reversed_edges(lgraph)

  // Remove dummy nodes and create final edge routes
  remove_dummy_nodes(lgraph)

  // Apply results back to ElkNode
  lgraph.to_elk_node(graph)
}

// ============================================================================
// Phase 1: Cycle Breaking
// ============================================================================

///|
/// Break cycles in the graph by reversing certain edges
fn break_cycles(graph : LGraph, strategy : @elk.CycleBreakingStrategy) -> Unit {
  match strategy {
    @elk.GreedyCycleBreaker | @elk.GreedyModelOrder =>
      greedy_cycle_breaker(graph)
    @elk.DepthFirst => dfs_cycle_breaker(graph)
    @elk.InteractiveCycleBreaker | @elk.ModelOrder =>
      greedy_cycle_breaker(graph)
  }
}

///|
/// Greedy cycle breaker - based on ELK's GreedyCycleBreaker
/// Uses out-degree vs in-degree heuristic to select edges to reverse
fn greedy_cycle_breaker(graph : LGraph) -> Unit {
  // Create working copies of degree counts
  let in_degree : Map[String, Int] = {}
  let out_degree : Map[String, Int] = {}
  let remaining_nodes : Array[LNode] = []
  for node in graph.nodes {
    in_degree[node.id] = node.in_degree()
    out_degree[node.id] = node.out_degree()
    remaining_nodes.push(node)
  }

  // Track node order (for determining edge direction)
  let node_order : Map[String, Int] = {}
  let mut order_index = 0

  // Process nodes until all are ordered
  while remaining_nodes.length() > 0 {
    // Find sinks (nodes with out_degree == 0 in remaining graph)
    let sinks = remaining_nodes.filter(fn(n) {
      out_degree.get(n.id).unwrap_or(0) == 0
    })

    // Find sources (nodes with in_degree == 0 in remaining graph)
    let sources = remaining_nodes.filter(fn(n) {
      in_degree.get(n.id).unwrap_or(0) == 0
    })

    // Prefer sources, then sinks, then highest out-in difference
    let node = if sources.length() > 0 {
      sources[0]
    } else if sinks.length() > 0 {
      sinks[0]
    } else {
      // Find node with maximum out_degree - in_degree
      let mut best_node : LNode? = None
      let mut best_diff = @int.min_value
      for n in remaining_nodes {
        let diff = out_degree.get(n.id).unwrap_or(0) -
          in_degree.get(n.id).unwrap_or(0)
        if diff > best_diff {
          best_diff = diff
          best_node = Some(n)
        }
      }
      match best_node {
        Some(n) => n
        None => remaining_nodes[0]
      }
    }

    // Assign order to this node
    node_order[node.id] = order_index
    order_index += 1

    // Remove node from remaining and update degrees
    let idx = find_node_index(remaining_nodes, node.id)
    if idx >= 0 {
      remaining_nodes.remove(idx) |> ignore
    }

    // Update degrees of neighbors
    for edge in node.outgoing_edges {
      in_degree[edge.target_id] = in_degree.get(edge.target_id).unwrap_or(1) - 1
    }
    for edge in node.incoming_edges {
      out_degree[edge.source_id] = out_degree.get(edge.source_id).unwrap_or(1) -
        1
    }
  }

  // Reverse edges that go against the order (back edges)
  for edge in graph.edges {
    let source_order = node_order.get(edge.source_id).unwrap_or(0)
    let target_order = node_order.get(edge.target_id).unwrap_or(0)
    if source_order > target_order {
      edge.reverse()
    }
  }
}

///|
/// DFS-based cycle breaker
fn dfs_cycle_breaker(graph : LGraph) -> Unit {
  let visited : Map[String, Bool] = {}
  let in_stack : Map[String, Bool] = {}
  fn dfs(node : LNode, graph : LGraph) -> Unit {
    visited[node.id] = true
    in_stack[node.id] = true
    for edge in node.outgoing_edges {
      let target_id = edge.target_id
      if in_stack.get(target_id).unwrap_or(false) {
        // Back edge found - reverse it
        edge.reverse()
      } else if !visited.get(target_id).unwrap_or(false) {
        match graph.get_node(target_id) {
          Some(target) => dfs(target, graph)
          None => ()
        }
      }
    }
    in_stack[node.id] = false
  }

  // Start DFS from each unvisited node
  for node in graph.nodes {
    if !visited.get(node.id).unwrap_or(false) {
      dfs(node, graph)
    }
  }
}

// ============================================================================
// Phase 2: Layer Assignment
// ============================================================================

///|
/// Assign nodes to layers
fn assign_layers(graph : LGraph, strategy : @elk.LayeringStrategy) -> Unit {
  match strategy {
    @elk.LongestPath => longest_path_layering(graph)
    @elk.NetworkSimplex => network_simplex_layering(graph)
    _ => longest_path_layering(graph) // Default
  }
}

///|
/// Longest path layering - simple and effective
fn longest_path_layering(graph : LGraph) -> Unit {
  // Check if we have any edges
  let has_edges = graph.edges.length() > 0

  // If no edges, put each node in its own layer to respect definition order
  if !has_edges {
    for i, node in graph.nodes {
      node.layer = i
    }
    return
  }

  // First pass: assign layers based on longest path from sources
  let layer : Map[String, Int] = {}

  // Find sources (nodes with no incoming edges)
  let sources : Array[LNode] = []
  for node in graph.nodes {
    if node.in_degree() == 0 {
      sources.push(node)
      layer[node.id] = 0
    }
  }

  // If no sources, pick the first node as starting point
  // This handles cyclic graphs or graphs where cycle breaking didn't create sources
  let queue : Array[LNode] = []
  if sources.is_empty() {
    if graph.nodes.length() > 0 {
      let start_node = graph.nodes[0]
      layer[start_node.id] = 0
      queue.push(start_node)
    }
  } else {
    for src in sources {
      queue.push(src)
    }
  }

  // BFS to assign layers
  let visited : Map[String, Bool] = {}
  while queue.length() > 0 {
    let node = queue.remove(0)
    if visited.get(node.id).unwrap_or(false) {
      continue
    }
    visited[node.id] = true
    let node_layer = layer.get(node.id).unwrap_or(0)
    for edge in node.outgoing_edges {
      let target_id = edge.target_id
      let target_layer = layer.get(target_id).unwrap_or(-1)
      let new_layer = node_layer + 1
      if new_layer > target_layer {
        layer[target_id] = new_layer
        // Add to queue if not already visited
        if !visited.get(target_id).unwrap_or(false) {
          match graph.get_node(target_id) {
            Some(target) => queue.push(target)
            None => ()
          }
        }
      }
    }
  }

  // Handle any nodes not reached by BFS (disconnected components or cycles)
  // For unreached nodes, assign them based on their incoming edges
  let mut changed = true
  while changed {
    changed = false
    for node in graph.nodes {
      if !layer.contains(node.id) {
        // Look at incoming edges to determine layer
        let mut max_incoming = -1
        for edge in node.incoming_edges {
          let src_layer = layer.get(edge.source_id).unwrap_or(-1)
          if src_layer > max_incoming {
            max_incoming = src_layer
          }
        }
        if max_incoming >= 0 {
          layer[node.id] = max_incoming + 1
          changed = true
        }
      }
    }
  }

  // Any still unreached nodes get layer 0
  for node in graph.nodes {
    if !layer.contains(node.id) {
      layer[node.id] = 0
    }
  }

  // Apply layer assignments
  for node in graph.nodes {
    node.layer = layer.get(node.id).unwrap_or(0)
  }
}

///|
/// Network simplex layering - optimal layer assignment
fn network_simplex_layering(graph : LGraph) -> Unit {
  // Use the full network simplex implementation
  network_simplex_layer_assignment(graph)
}

// ============================================================================
// Dummy Node Handling
// ============================================================================

///|
/// Insert dummy nodes for edges spanning multiple layers
fn insert_dummy_nodes(graph : LGraph) -> Unit {
  // Collect long edges
  let long_edges = graph.get_long_edges()
  let mut dummy_count = 0
  for edge in long_edges {
    let source_node = graph.get_node(edge.source_id)
    let target_node = graph.get_node(edge.target_id)
    guard source_node is Some(src) && target_node is Some(tgt) else { continue }
    let source_layer = src.layer
    let target_layer = tgt.layer

    // Skip if not spanning multiple layers
    if (target_layer - source_layer).abs() <= 1 {
      continue
    }

    // Create dummy nodes for each intermediate layer
    let mut prev_node_id = edge.source_id
    let direction = if target_layer > source_layer { 1 } else { -1 }
    let mut layer_idx = source_layer + direction
    while layer_idx != target_layer {
      // Create dummy node
      let dummy_id = "dummy_" + dummy_count.to_string()
      dummy_count += 1
      let dummy = LNode::new(dummy_id, LongEdgeDummy)
      dummy.layer = layer_idx
      dummy.origin_edge = Some(edge.id)
      dummy.width = 1.0 // Minimal width for dummy
      dummy.height = 1.0

      // Add to graph
      graph.add_node(dummy)

      // Create edge from prev_node to dummy
      let edge_to_dummy = LEdge::new(
        "e_" + prev_node_id + "_" + dummy_id,
        prev_node_id,
        dummy_id,
      )
      edge_to_dummy.original_id = edge.original_id
      // Link edge to nodes
      match graph.get_node(prev_node_id) {
        Some(prev) => prev.outgoing_edges.push(edge_to_dummy)
        None => ()
      }
      dummy.incoming_edges.push(edge_to_dummy)
      graph.edges.push(edge_to_dummy)
      prev_node_id = dummy_id
      layer_idx = layer_idx + direction
    }

    // Create final edge from last dummy to target
    let final_edge = LEdge::new(
      "e_" + prev_node_id + "_" + edge.target_id,
      prev_node_id,
      edge.target_id,
    )
    final_edge.original_id = edge.original_id
    match graph.get_node(prev_node_id) {
      Some(prev) => prev.outgoing_edges.push(final_edge)
      None => ()
    }
    tgt.incoming_edges.push(final_edge)
    graph.edges.push(final_edge)

    // Remove original edge from source's outgoing
    let src_idx = find_edge_index(src.outgoing_edges, edge.id)
    if src_idx >= 0 {
      src.outgoing_edges.remove(src_idx) |> ignore
    }

    // Remove original edge from target's incoming
    let tgt_idx = find_edge_index(tgt.incoming_edges, edge.id)
    if tgt_idx >= 0 {
      tgt.incoming_edges.remove(tgt_idx) |> ignore
    }
  }

  // Reinitialize layers with dummy nodes
  graph.initialize_layers()
}

///|
/// Remove dummy nodes and reconstruct edge routes
fn remove_dummy_nodes(graph : LGraph) -> Unit {
  // Group dummy nodes by their origin edge
  let dummy_chains : Map[String, Array[LNode]] = {}
  let dummy_node_ids : Array[String] = []
  for node in graph.nodes {
    if node.node_type is LongEdgeDummy {
      dummy_node_ids.push(node.id)
      match node.origin_edge {
        Some(edge_id) => {
          if !dummy_chains.contains(edge_id) {
            dummy_chains[edge_id] = []
          }
          match dummy_chains.get(edge_id) {
            Some(arr) => arr.push(node)
            None => ()
          }
        }
        None => ()
      }
    }
  }

  // Sort dummy nodes in each chain by layer and create bend points
  // Only add bend points to original edges (not dummy edges)
  for edge in graph.edges {
    match edge.original_id {
      Some(orig_id) =>
        // Only process edges that start from a real (non-dummy) source
        if !edge.source_id.has_prefix("dummy_") {
          match dummy_chains.get(orig_id) {
            Some(dummies) => {
              // Sort by layer
              dummies.sort_by(fn(a, b) { a.layer - b.layer })
              // Add bend points from dummy positions
              for dummy in dummies {
                let bend_x = dummy.x + dummy.width / 2.0
                let bend_y = dummy.y + dummy.height / 2.0
                edge.bend_points.push(@elk.ElkPoint::new(bend_x, bend_y))
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }

  // Remove dummy nodes from graph.nodes and graph.node_map
  let non_dummy_nodes : Array[LNode] = []
  for node in graph.nodes {
    if !node.is_dummy() {
      non_dummy_nodes.push(node)
    }
  }
  graph.nodes.clear()
  for node in non_dummy_nodes {
    graph.nodes.push(node)
  }

  // Remove dummy nodes from node_map
  for dummy_id in dummy_node_ids {
    graph.node_map.remove(dummy_id) |> ignore
  }

  // Remove dummy edges from graph.edges
  let non_dummy_edges : Array[LEdge] = []
  for edge in graph.edges {
    // Keep edges that don't involve dummy nodes
    let source_is_dummy = edge.source_id.has_prefix("dummy_")
    let target_is_dummy = edge.target_id.has_prefix("dummy_")
    if !source_is_dummy && !target_is_dummy {
      non_dummy_edges.push(edge)
    }
  }
  graph.edges.clear()
  for edge in non_dummy_edges {
    graph.edges.push(edge)
  }

  // Clear and rebuild layers without dummy nodes
  graph.layers.clear()

  // Clear incoming/outgoing edge references to dummy edges from real nodes
  for node in graph.nodes {
    // Filter out edges that reference dummy nodes
    let real_incoming : Array[LEdge] = []
    for e in node.incoming_edges {
      if !e.source_id.has_prefix("dummy_") && !e.target_id.has_prefix("dummy_") {
        real_incoming.push(e)
      }
    }
    node.incoming_edges.clear()
    for e in real_incoming {
      node.incoming_edges.push(e)
    }
    let real_outgoing : Array[LEdge] = []
    for e in node.outgoing_edges {
      if !e.source_id.has_prefix("dummy_") && !e.target_id.has_prefix("dummy_") {
        real_outgoing.push(e)
      }
    }
    node.outgoing_edges.clear()
    for e in real_outgoing {
      node.outgoing_edges.push(e)
    }
  }
}

// ============================================================================
// Phase 3: Crossing Minimization
// ============================================================================

///|
/// Minimize edge crossings between layers
fn minimize_crossings(
  graph : LGraph,
  strategy : @elk.CrossingMinimizationStrategy,
  thoroughness : Int,
) -> Unit {
  match strategy {
    @elk.LayerSweep => layer_sweep_crossing_min(graph, thoroughness)
    @elk.InteractiveCrossMin | @elk.None => () // No minimization
  }
}

///|
/// Layer sweep crossing minimization with barycenter heuristic and greedy switch
fn layer_sweep_crossing_min(graph : LGraph, thoroughness : Int) -> Unit {
  if graph.layers.length() <= 1 {
    return
  }

  // Phase 1: Barycenter ordering
  for sweep = 0; sweep < thoroughness; sweep = sweep + 1 {
    // Forward sweep (top to bottom for Down direction)
    for i = 1; i < graph.layers.length(); i = i + 1 {
      order_layer_by_barycenter(
        graph,
        graph.layers[i],
        graph.layers[i - 1],
        true,
      )
    }

    // Backward sweep (bottom to top)
    for i = graph.layers.length() - 2; i >= 0; i = i - 1 {
      order_layer_by_barycenter(
        graph,
        graph.layers[i],
        graph.layers[i + 1],
        false,
      )
    }
  }

  // Update node positions after barycenter ordering
  for layer in graph.layers {
    for i, node in layer.nodes {
      node.position = i
    }
  }

  // Phase 2: Greedy switch for further optimization
  greedy_switch_two_sided(graph, thoroughness)
}

///|
/// Order nodes in a layer using barycenter heuristic
fn order_layer_by_barycenter(
  graph : LGraph,
  layer : LLayer,
  fixed_layer : LLayer,
  forward : Bool,
) -> Unit {
  // Calculate barycenter for each node
  let barycenters : Map[String, Double] = {}
  for node in layer.nodes {
    let connected_positions : Array[Int] = []
    if forward {
      // Use incoming edges (connect to fixed layer above)
      for edge in node.incoming_edges {
        match graph.get_node(edge.source_id) {
          Some(source) =>
            if source.layer == fixed_layer.index {
              connected_positions.push(source.position)
            }
          None => ()
        }
      }
    } else {
      // Use outgoing edges (connect to fixed layer below)
      for edge in node.outgoing_edges {
        match graph.get_node(edge.target_id) {
          Some(target) =>
            if target.layer == fixed_layer.index {
              connected_positions.push(target.position)
            }
          None => ()
        }
      }
    }

    // Calculate barycenter
    if connected_positions.length() > 0 {
      let sum = connected_positions.fold(init=0, fn(acc, p) { acc + p })
      barycenters[node.id] = sum.to_double() /
        connected_positions.length().to_double()
    } else {
      // Keep original position for disconnected nodes
      barycenters[node.id] = node.position.to_double()
    }
  }

  // Sort layer nodes by barycenter
  layer.nodes.sort_by(fn(a, b) {
    let bc_a = barycenters.get(a.id).unwrap_or(0.0)
    let bc_b = barycenters.get(b.id).unwrap_or(0.0)
    if bc_a < bc_b {
      -1
    } else if bc_a > bc_b {
      1
    } else {
      0
    }
  })
}

// ============================================================================
// Phase 4: Node Placement
// ============================================================================

///|
/// Place nodes with final x,y coordinates
fn place_nodes(
  graph : LGraph,
  options : @elk.LayoutOptions,
  strategy : @elk.NodePlacementStrategy,
  direction : @elk.LayoutDirection,
) -> Unit {
  match strategy {
    @elk.Simple => simple_node_placement(graph, options, direction)
    @elk.BrandesKoepf => brandes_koepf_placement(graph, options, direction)
    _ => simple_node_placement(graph, options, direction)
  }
}

///|
/// Simple node placement - evenly distributed within layers
fn simple_node_placement(
  graph : LGraph,
  options : @elk.LayoutOptions,
  direction : @elk.LayoutDirection,
) -> Unit {
  let node_spacing = options.node_node_spacing.unwrap_or(20.0)
  let layer_spacing = options.node_node_between_layers_spacing.unwrap_or(40.0)
  let padding = options.padding.unwrap_or(@elk.ElkPadding::uniform(12.0))

  // Determine if horizontal or vertical layout
  let is_horizontal = direction.is_horizontal()

  // Calculate layer positions
  let mut layer_offset = if is_horizontal { padding.left } else { padding.top }
  for layer in graph.layers {
    // Calculate layer size
    let mut layer_size = 0.0
    for node in layer.nodes {
      layer_size = if is_horizontal {
        max_double(layer_size, node.height)
      } else {
        max_double(layer_size, node.width)
      }
    }

    // Position nodes within layer
    let mut node_offset = if is_horizontal { padding.top } else { padding.left }
    for node in layer.nodes {
      if is_horizontal {
        node.x = layer_offset
        node.y = node_offset
        node_offset = node_offset + node.height + node_spacing
      } else {
        node.x = node_offset
        node.y = layer_offset
        node_offset = node_offset + node.width + node_spacing
      }
    }
    layer_offset = layer_offset + layer_size + layer_spacing
  }

  // Update graph size
  let mut max_x = 0.0
  let mut max_y = 0.0
  for node in graph.nodes {
    max_x = max_double(max_x, node.x + node.width)
    max_y = max_double(max_y, node.y + node.height)
  }
  graph.width = max_x + padding.right
  graph.height = max_y + padding.bottom
}

///|
/// Brandes-Koepf placement - uses the full implementation
fn brandes_koepf_placement(
  graph : LGraph,
  options : @elk.LayoutOptions,
  direction : @elk.LayoutDirection,
) -> Unit {
  // Use the full Brandes-Koepf implementation
  run_brandes_koepf(graph, options, direction)
}

// ============================================================================
// Phase 5: Edge Routing
// ============================================================================

///|
/// Route edges between nodes
fn route_edges(
  graph : LGraph,
  routing : @elk.EdgeRouting,
  direction : @elk.LayoutDirection,
) -> Unit {
  match routing {
    @elk.Orthogonal => orthogonal_routing(graph, direction)
    @elk.Polyline => polyline_routing(graph, direction)
    @elk.Splines => spline_routing(graph, direction)
    @elk.Undefined => orthogonal_routing(graph, direction)
  }
}

///|
/// Orthogonal edge routing - strict 90-degree turns with slot assignment
fn orthogonal_routing(graph : LGraph, direction : @elk.LayoutDirection) -> Unit {
  let edge_spacing = 10.0 // Default edge spacing

  // Use improved routing with slot assignment
  route_edges_orthogonal(graph, direction, edge_spacing)

  // Route any self-loops
  route_self_loops(graph, direction)

  // Clean up unnecessary bend points
  straighten_edges(graph)
}

///|
/// Polyline edge routing - direct connections with bend points
fn polyline_routing(graph : LGraph, direction : @elk.LayoutDirection) -> Unit {
  // For polyline, edges go directly through dummy node positions
  // Bend points are already set from dummy nodes
  let _ = graph
  let _ = direction

}

///|
/// Spline edge routing (placeholder)
fn spline_routing(graph : LGraph, direction : @elk.LayoutDirection) -> Unit {
  // For now, fall back to polyline
  polyline_routing(graph, direction)
}

// ============================================================================
// Edge Restoration
// ============================================================================

///|
/// Restore reversed edges to their original direction
fn restore_reversed_edges(graph : LGraph) -> Unit {
  for edge in graph.edges {
    if edge.reversed {
      edge.reverse()
    }
  }
}
