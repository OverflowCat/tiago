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

// ============================================================================
// Main Entry Point
// ============================================================================

///|
/// Execute the layered layout algorithm
fn elk_layered_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  let resolved_options = resolve_options_for_graph(options, graph)
  ensure_sizes(graph, resolved_options)
  // First, recursively layout compound nodes (children with their own children)
  for child in graph.children {
    if child.children.length() > 0 {
      elk_layered_layout(child, resolved_options)
      // Update child size to contain its children
      let (child_w, child_h) = child.calculate_bounds()
      let child_options = resolve_options_for_node(resolved_options, child)
      let padding = child_options.padding.unwrap_or(ElkPadding::uniform(12.0))
      child.width = child_w + padding.left + padding.right
      child.height = child_h + padding.top + padding.bottom
    }
  }

  // Convert ElkNode to internal LGraph representation
  let lgraph = LGraph::from_elk_node(graph)

  // Get options with defaults
  let direction = match resolved_options.direction {
    Some(d) => d
    None => Down
  }
  let thoroughness = match resolved_options.thoroughness {
    Some(t) => t
    None => 7
  }
  run_layered_internal_pipeline(
    lgraph, resolved_options, direction, thoroughness,
  )

  // Apply results back to ElkNode
  lgraph.to_elk_node(graph, direction)
}

// ============================================================================
// Phase 1: Cycle Breaking
// ============================================================================

///|
/// Break cycles in the graph by reversing certain edges
fn break_cycles(graph : LGraph, strategy : CycleBreakingStrategy) -> Unit {
  match strategy {
    GreedyCycleBreaker | GreedyModelOrder => greedy_cycle_breaker(graph)
    DepthFirst => dfs_cycle_breaker(graph)
    InteractiveCycleBreaker | ModelOrder => greedy_cycle_breaker(graph)
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
fn assign_layers(graph : LGraph, strategy : LayeringStrategy) -> Unit {
  match strategy {
    LongestPath => longest_path_layering(graph)
    NetworkSimplex => network_simplex_layering(graph)
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
/// Insert label dummy nodes for edges with labels.
///
/// This follows the ELK layered approach of turning edge labels into nodes so
/// later phases can account for label sizes.
fn insert_label_dummy_nodes(graph : LGraph, options : LayoutOptions) -> Unit {
  let label_spacing = options.edge_label_spacing.unwrap_or(2.0)
  let original_edge_count = graph.edges.length()
  for i = 0; i < original_edge_count; i = i + 1 {
    let edge = graph.edges[i]

    // Skip already-split carrier edges.
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }

    // Ignore edges without any center labels.
    if edge.labels.is_empty() {
      continue
    }
    let center_labels : Array[LLabel] = []
    for label in edge.labels {
      if effective_edge_label_placement(options, label) is Center {
        center_labels.push(label)
      }
    }
    if center_labels.is_empty() {
      continue
    }

    // Self-loops are handled by dedicated processors.
    if edge.source_id == edge.target_id {
      continue
    }
    let source_node = graph.get_node(edge.source_id)
    let target_node = graph.get_node(edge.target_id)
    guard source_node is Some(src) && target_node is Some(tgt) else { continue }

    // Mark the original edge so later phases (routing) skip it.
    edge.properties.set("diago.layered.longEdgeSplit", Bool(true))
    let origin = match edge.original_id {
      Some(id) => id
      None => edge.id
    }

    // Create the label dummy node.
    let dummy_id = graph.alloc_dummy_id()
    let dummy = LNode::new(dummy_id, LabelDummy)
    dummy.origin_edge = Some(origin)
    let mut max_w = 1.0
    let mut sum_h = 0.0
    for label in center_labels {
      if label.width > max_w {
        max_w = label.width
      }
      sum_h = sum_h + label.height
    }
    let gaps = (center_labels.length() - 1).to_double()
    dummy.width = max_w
    dummy.height = sum_h + gaps * label_spacing
    dummy.properties.set(
      "diago.layered.edgeLabelSpacing",
      Double(label_spacing),
    )
    graph.add_node(dummy)

    // Create edge from source to label dummy.
    let edge_to_dummy = LEdge::new(
      "e_" + edge.source_id + "_" + dummy_id,
      edge.source_id,
      dummy_id,
    )
    edge_to_dummy.original_id = Some(origin)
    edge_to_dummy.priority = edge.priority
    edge_to_dummy.source_port_id = edge.source_port_id
    match graph.get_node(edge.source_id) {
      Some(source) => source.outgoing_edges.push(edge_to_dummy)
      None => ()
    }
    dummy.incoming_edges.push(edge_to_dummy)
    graph.edges.push(edge_to_dummy)

    // Create edge from label dummy to target.
    let edge_from_dummy = LEdge::new(
      "e_" + dummy_id + "_" + edge.target_id,
      dummy_id,
      edge.target_id,
    )
    edge_from_dummy.original_id = Some(origin)
    edge_from_dummy.priority = edge.priority
    edge_from_dummy.target_port_id = edge.target_port_id
    dummy.outgoing_edges.push(edge_from_dummy)
    tgt.incoming_edges.push(edge_from_dummy)
    graph.edges.push(edge_from_dummy)

    // Remove the original edge from adjacency lists (carrier edge only).
    let src_idx = find_edge_index(src.outgoing_edges, edge.id)
    if src_idx >= 0 {
      src.outgoing_edges.remove(src_idx) |> ignore
    }
    let tgt_idx = find_edge_index(tgt.incoming_edges, edge.id)
    if tgt_idx >= 0 {
      tgt.incoming_edges.remove(tgt_idx) |> ignore
    }
  }
}

///|
/// Insert dummy nodes for edges spanning multiple layers.
fn insert_dummy_nodes(graph : LGraph, _options : LayoutOptions) -> Unit {
  // Collect long edges
  let long_edges = graph.get_long_edges()
  for edge in long_edges {
    // Skip already-split carrier edges.
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source_node = graph.get_node(edge.source_id)
    let target_node = graph.get_node(edge.target_id)
    guard source_node is Some(src) && target_node is Some(tgt) else { continue }
    let source_layer = src.layer
    let target_layer = tgt.layer

    // Skip if not spanning multiple layers
    if (target_layer - source_layer).abs() <= 1 {
      continue
    }

    // Mark the edge so later phases can skip routing it directly.
    edge.properties.set("diago.layered.longEdgeSplit", Bool(true))
    let origin = match edge.original_id {
      Some(id) => id
      None => edge.id
    }
    let mut prev_node_id = edge.source_id
    let direction = if target_layer > source_layer { 1 } else { -1 }
    let mut layer_idx = source_layer + direction
    while layer_idx != target_layer {
      let dummy_id = graph.alloc_dummy_id()
      let dummy = LNode::new(dummy_id, LongEdgeDummy)
      dummy.layer = layer_idx
      dummy.origin_edge = Some(origin)
      dummy.width = 1.0
      dummy.height = 1.0
      graph.add_node(dummy)
      let edge_to_dummy = LEdge::new(
        "e_" + prev_node_id + "_" + dummy_id,
        prev_node_id,
        dummy_id,
      )
      edge_to_dummy.original_id = Some(origin)
      edge_to_dummy.priority = edge.priority
      if prev_node_id == edge.source_id {
        edge_to_dummy.source_port_id = edge.source_port_id
      }
      match graph.get_node(prev_node_id) {
        Some(prev) => prev.outgoing_edges.push(edge_to_dummy)
        None => ()
      }
      dummy.incoming_edges.push(edge_to_dummy)
      graph.edges.push(edge_to_dummy)
      prev_node_id = dummy_id
      layer_idx = layer_idx + direction
    }
    let final_edge = LEdge::new(
      "e_" + prev_node_id + "_" + edge.target_id,
      prev_node_id,
      edge.target_id,
    )
    final_edge.original_id = Some(origin)
    final_edge.priority = edge.priority
    final_edge.target_port_id = edge.target_port_id
    match graph.get_node(prev_node_id) {
      Some(prev) => prev.outgoing_edges.push(final_edge)
      None => ()
    }
    tgt.incoming_edges.push(final_edge)
    graph.edges.push(final_edge)
    let src_idx = find_edge_index(src.outgoing_edges, edge.id)
    if src_idx >= 0 {
      src.outgoing_edges.remove(src_idx) |> ignore
    }
    let tgt_idx = find_edge_index(tgt.incoming_edges, edge.id)
    if tgt_idx >= 0 {
      tgt.incoming_edges.remove(tgt_idx) |> ignore
    }
  }

  // Reinitialize layers with dummy nodes.
  graph.initialize_layers()
}

///|
/// Extract self-loop edges so they don't affect layering/crossing/placement.
fn extract_self_loop_edges(graph : LGraph) -> Unit {
  graph.self_loop_edges.clear()
  fn remove_edge_by_id(edges : Array[LEdge], id : String) -> Unit {
    while true {
      let idx = find_edge_index(edges, id)
      if idx < 0 {
        break
      }
      edges.remove(idx) |> ignore
    }
  }

  let edges : Array[LEdge] = []
  for edge in graph.edges {
    if edge.source_id == edge.target_id {
      graph.self_loop_edges.push(edge)
      match graph.get_node(edge.source_id) {
        Some(node) => {
          remove_edge_by_id(node.incoming_edges, edge.id)
          remove_edge_by_id(node.outgoing_edges, edge.id)
        }
        None => ()
      }
    } else {
      edges.push(edge)
    }
  }
  graph.edges.clear()
  graph.edges.append(edges)
}

///|
/// Assign per-edge offsets for self-loop routing.
fn assign_self_loop_offsets(graph : LGraph) -> Unit {
  let mut i = 0
  for edge in graph.self_loop_edges {
    edge.parallel_offset = (i.to_double() + 1.0) * 10.0
    i = i + 1
  }
}

///|
/// Ensure self-loop edges have usable port IDs when possible.
fn assign_self_loop_ports(graph : LGraph, _direction : LayoutDirection) -> Unit {
  for edge in graph.self_loop_edges {
    if edge.source_port_id is Some(_) && edge.target_port_id is Some(_) {
      continue
    }
    match graph.get_node(edge.source_id) {
      Some(node) => {
        // Prefer an east-side port to match our routing around the right edge.
        let mut selected : String? = None
        for port in node.ports {
          if port.side is East {
            selected = match port.original_id {
              Some(id) => Some(id)
              None => Some(port.id)
            }
            break
          }
        }
        if selected is None && node.ports.length() > 0 {
          let p = node.ports[0]
          selected = match p.original_id {
            Some(id) => Some(id)
            None => Some(p.id)
          }
        }
        match selected {
          Some(pid) => {
            if edge.source_port_id is None {
              edge.source_port_id = Some(pid)
            }
            if edge.target_port_id is None {
              edge.target_port_id = Some(pid)
            }
          }
          None => ()
        }
      }
      None => ()
    }
  }
}

///|
/// Route extracted self-loops, then restore them into the graph.
fn route_and_restore_self_loops(
  graph : LGraph,
  direction : LayoutDirection,
) -> Unit {
  if graph.self_loop_edges.is_empty() {
    return
  }

  // Route self-loop edges using final node positions.
  route_self_loop_edges(graph, graph.self_loop_edges, direction)

  // Restore into graph and node adjacency lists.
  let loops : Array[LEdge] = []
  loops.append(graph.self_loop_edges)
  graph.self_loop_edges.clear()
  for edge in loops {
    graph.edges.push(edge)
    match graph.get_node(edge.source_id) {
      Some(node) => {
        node.incoming_edges.push(edge)
        node.outgoing_edges.push(edge)
      }
      None => ()
    }
  }
}

///|
/// Remove long-edge dummy nodes and reconstruct bend points.
fn remove_long_edge_dummy_nodes(graph : LGraph) -> Unit {
  let dummy_chains : Map[String, Array[LNode]] = {}
  let dummy_ids : Map[String, Bool] = {}
  for node in graph.nodes {
    if node.is_dummy() && node.node_type is LongEdgeDummy {
      dummy_ids[node.id] = true
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

  // Only add bend points to original edges.
  for edge in graph.edges {
    match edge.original_id {
      Some(orig_id) =>
        if edge.id == orig_id {
          match dummy_chains.get(orig_id) {
            Some(dummies) => {
              let source_layer = match graph.get_node(edge.source_id) {
                Some(n) => n.layer
                None => 0
              }
              let target_layer = match graph.get_node(edge.target_id) {
                Some(n) => n.layer
                None => 0
              }
              if source_layer <= target_layer {
                dummies.sort_by(fn(a, b) { a.layer - b.layer })
              } else {
                dummies.sort_by(fn(a, b) { b.layer - a.layer })
              }
              edge.bend_points.clear()
              for dummy in dummies {
                let bend_x = dummy.x + dummy.width / 2.0
                let bend_y = dummy.y + dummy.height / 2.0
                edge.bend_points.push(ElkPoint::new(bend_x, bend_y))
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }
  if dummy_ids.is_empty() {
    return
  }

  // Remove long-edge dummies from nodes.
  let nodes : Array[LNode] = []
  for node in graph.nodes {
    if !dummy_ids.contains(node.id) {
      nodes.push(node)
    }
  }
  graph.nodes.clear()
  graph.nodes.append(nodes)

  // Remove from node_map.
  for id, _ in dummy_ids {
    graph.node_map.remove(id) |> ignore
  }

  // Remove edges incident to long-edge dummies.
  let edges : Array[LEdge] = []
  for edge in graph.edges {
    if !dummy_ids.contains(edge.source_id) &&
      !dummy_ids.contains(edge.target_id) {
      edges.push(edge)
    }
  }
  graph.edges.clear()
  graph.edges.append(edges)

  // Clean incoming/outgoing references.
  for node in graph.nodes {
    let incoming : Array[LEdge] = []
    for e in node.incoming_edges {
      if !dummy_ids.contains(e.source_id) && !dummy_ids.contains(e.target_id) {
        incoming.push(e)
      }
    }
    node.incoming_edges.clear()
    node.incoming_edges.append(incoming)
    let outgoing : Array[LEdge] = []
    for e in node.outgoing_edges {
      if !dummy_ids.contains(e.source_id) && !dummy_ids.contains(e.target_id) {
        outgoing.push(e)
      }
    }
    node.outgoing_edges.clear()
    node.outgoing_edges.append(outgoing)
  }
  graph.layers.clear()
}

///|
/// Remove label dummy nodes and write back label positions.
fn remove_label_dummy_nodes(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
) -> Unit {
  let dummy_chains : Map[String, Array[LNode]] = {}
  let dummy_ids : Map[String, Bool] = {}
  for node in graph.nodes {
    if node.is_dummy() && node.node_type is LabelDummy {
      dummy_ids[node.id] = true
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
  for edge in graph.edges {
    match edge.original_id {
      Some(orig_id) =>
        if edge.id == orig_id {
          match dummy_chains.get(orig_id) {
            Some(dummies) => {
              let source_layer = match graph.get_node(edge.source_id) {
                Some(n) => n.layer
                None => 0
              }
              let target_layer = match graph.get_node(edge.target_id) {
                Some(n) => n.layer
                None => 0
              }
              if source_layer <= target_layer {
                dummies.sort_by(fn(a, b) { a.layer - b.layer })
              } else {
                dummies.sort_by(fn(a, b) { b.layer - a.layer })
              }
              // Keep any bend points generated earlier (e.g. long-edge joiner) and append.
              for dummy in dummies {
                let bend_x = dummy.x + dummy.width / 2.0
                let bend_y = dummy.y + dummy.height / 2.0
                edge.bend_points.push(ElkPoint::new(bend_x, bend_y))
                if !edge.labels.is_empty() {
                  let center_labels : Array[LLabel] = []
                  for label in edge.labels {
                    if effective_edge_label_placement(options, label) is Center {
                      center_labels.push(label)
                    }
                  }
                  if center_labels.is_empty() {
                    continue
                  }
                  let spacing = dummy.properties.get_double_or(
                    "diago.layered.edgeLabelSpacing", 2.0,
                  )
                  let default_selection = match
                    options.edge_label_side_selection {
                    Some(s) => s
                    None => DirectionDown
                  }
                  let mut side_sign = side_selection_sign(
                    default_selection, direction,
                  )
                  match
                    center_labels[0].properties.get_int(
                      "diago.layered.labelSideSign",
                    ) {
                    Some(v) => side_sign = v
                    None => ()
                  }
                  let side_sign = side_sign.to_double()
                  let offset = options.label_node_spacing.unwrap_or(5.0)
                  let base_x = if direction.is_vertical() {
                    dummy.x + side_sign * offset
                  } else {
                    dummy.x
                  }
                  let mut y = if direction.is_horizontal() {
                    dummy.y + side_sign * offset
                  } else {
                    dummy.y
                  }
                  for i, label in center_labels {
                    label.x = base_x + (dummy.width - label.width) / 2.0
                    label.y = y
                    y = y + label.height
                    if i + 1 < center_labels.length() {
                      y = y + spacing
                    }
                  }
                }
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }
  if dummy_ids.is_empty() {
    return
  }
  let nodes : Array[LNode] = []
  for node in graph.nodes {
    if !dummy_ids.contains(node.id) {
      nodes.push(node)
    }
  }
  graph.nodes.clear()
  graph.nodes.append(nodes)
  for id, _ in dummy_ids {
    graph.node_map.remove(id) |> ignore
  }
  let edges : Array[LEdge] = []
  for edge in graph.edges {
    if !dummy_ids.contains(edge.source_id) &&
      !dummy_ids.contains(edge.target_id) {
      edges.push(edge)
    }
  }
  graph.edges.clear()
  graph.edges.append(edges)
  for node in graph.nodes {
    let incoming : Array[LEdge] = []
    for e in node.incoming_edges {
      if !dummy_ids.contains(e.source_id) && !dummy_ids.contains(e.target_id) {
        incoming.push(e)
      }
    }
    node.incoming_edges.clear()
    node.incoming_edges.append(incoming)
    let outgoing : Array[LEdge] = []
    for e in node.outgoing_edges {
      if !dummy_ids.contains(e.source_id) && !dummy_ids.contains(e.target_id) {
        outgoing.push(e)
      }
    }
    node.outgoing_edges.clear()
    node.outgoing_edges.append(outgoing)
  }
  graph.layers.clear()
}

///|
/// Backwards-compatible helper: remove all dummies.
fn remove_dummy_nodes(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
) -> Unit {
  remove_long_edge_dummy_nodes(graph)
  remove_label_dummy_nodes(graph, options, direction)
}

// ============================================================================
// Model Order Processors
// ============================================================================

///|
fn sort_layers_by_input_order(graph : LGraph) -> Unit {
  let order : Map[String, Int] = {}
  for i, node in graph.nodes {
    order[node.id] = i
  }
  for layer in graph.layers {
    layer.nodes.sort_by(fn(a, b) {
      let ia = order.get(a.id).unwrap_or(0)
      let ib = order.get(b.id).unwrap_or(0)
      ia - ib
    })
    for i, node in layer.nodes {
      node.position = i
    }
  }
}

// ============================================================================
// End Label Processors
// ============================================================================

///|
fn parse_edge_label_placement(value : String) -> EdgeLabelPlacement? {
  match value {
    "CENTER" | "Center" | "center" => Some(Center)
    "HEAD" | "Head" | "head" => Some(Head)
    "TAIL" | "Tail" | "tail" => Some(Tail)
    _ => None
  }
}

///|
fn label_placement_from_properties(label : LLabel) -> EdgeLabelPlacement? {
  match label.properties.get_string("elk.edgeLabel.placement") {
    Some(s) => parse_edge_label_placement(s)
    None =>
      match label.properties.get_string("org.eclipse.elk.edgeLabel.placement") {
        Some(s) => parse_edge_label_placement(s)
        None =>
          match
            label.properties.get_string("diago.layered.edgeLabelPlacement") {
            Some(s) => parse_edge_label_placement(s)
            None => None
          }
      }
  }
}

///|
fn effective_edge_label_placement(
  options : LayoutOptions,
  label : LLabel,
) -> EdgeLabelPlacement {
  match label_placement_from_properties(label) {
    Some(p) => p
    None =>
      match options.edge_label_placement {
        Some(p) => p
        None => Center
      }
  }
}

///|
fn set_default_label_placement(graph : LGraph, options : LayoutOptions) -> Unit {
  let placement = match options.edge_label_placement {
    Some(p) => p
    None => Center
  }
  let placement_str = match placement {
    Head => "Head"
    Tail => "Tail"
    _ => "Center"
  }
  for edge in graph.edges {
    for label in edge.labels {
      if label_placement_from_properties(label) is None {
        label.properties.set(
          "diago.layered.edgeLabelPlacement",
          String(placement_str),
        )
      }
    }
  }
}

///|
fn preprocess_end_labels(graph : LGraph, options : LayoutOptions) -> Unit {
  // Keep compatibility: this stage historically stamped default placement.
  set_default_label_placement(graph, options)
}

///|
fn sort_end_labels(graph : LGraph, options : LayoutOptions) -> Unit {
  fn rank(p : EdgeLabelPlacement) -> Int {
    match p {
      Head => 0
      Center => 1
      Tail => 2
      Undefined => 1
    }
  }

  for edge in graph.edges {
    if edge.labels.length() <= 1 {
      continue
    }
    edge.labels.sort_by(fn(a, b) {
      let ra = rank(effective_edge_label_placement(options, a))
      let rb = rank(effective_edge_label_placement(options, b))
      if ra != rb {
        ra - rb
      } else {
        a.id.compare(b.id)
      }
    })
  }
}

///|
fn apply_label_side_selection(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
) -> Unit {
  let selection = match options.edge_label_side_selection {
    Some(s) => s
    None => DirectionDown
  }
  let sign = side_selection_sign(selection, direction)
  for edge in graph.edges {
    for label in edge.labels {
      label.properties.set("diago.layered.labelSideSign", Int(sign))
    }
  }
}

///|
fn side_selection_sign(
  selection : EdgeLabelSideSelection,
  direction : LayoutDirection,
) -> Int {
  fn flip_for_direction(direction : LayoutDirection) -> Bool {
    direction == Up || direction == Left
  }

  let sign = match selection {
    AlwaysUp => -1
    AlwaysDown => 1
    DirectionUp => if flip_for_direction(direction) { 1 } else { -1 }
    DirectionDown => if flip_for_direction(direction) { -1 } else { 1 }
    SmartUp => if flip_for_direction(direction) { 1 } else { -1 }
    SmartDown => if flip_for_direction(direction) { -1 } else { 1 }
  }
  sign
}

///|
fn along_sign(direction : LayoutDirection) -> Int {
  if direction == Down || direction == Right {
    1
  } else {
    -1
  }
}

///|
fn find_port_for_id(node : LNode, port_id : String) -> LPort? {
  for port in node.ports {
    if port.id == port_id {
      return Some(port)
    }
    match port.original_id {
      Some(id) => if id == port_id { return Some(port) }
      None => ()
    }
  }
  None
}

///|
fn default_edge_anchor(
  node : LNode,
  direction : LayoutDirection,
  is_source : Bool,
) -> ElkPoint {
  if direction.is_vertical() {
    if is_source {
      ElkPoint::new(node.x + node.width / 2.0, node.y + node.height)
    } else {
      ElkPoint::new(node.x + node.width / 2.0, node.y)
    }
  } else if direction.is_horizontal() {
    if is_source {
      ElkPoint::new(node.x + node.width, node.y + node.height / 2.0)
    } else {
      ElkPoint::new(node.x, node.y + node.height / 2.0)
    }
  } else {
    ElkPoint::new(node.x + node.width / 2.0, node.y + node.height / 2.0)
  }
}

///|
fn edge_anchor_point(
  graph : LGraph,
  edge : LEdge,
  direction : LayoutDirection,
  is_source : Bool,
) -> ElkPoint {
  let node_id = if is_source { edge.source_id } else { edge.target_id }
  let port_id = if is_source {
    edge.source_port_id
  } else {
    edge.target_port_id
  }
  match graph.get_node(node_id) {
    Some(node) =>
      match port_id {
        Some(pid) =>
          match find_port_for_id(node, pid) {
            Some(port) => {
              let has_pos = port.x != 0.0 || port.y != 0.0
              match port.side {
                North =>
                  if has_pos {
                    ElkPoint::new(node.x + port.x, node.y)
                  } else {
                    ElkPoint::new(node.x + node.width / 2.0, node.y)
                  }
                South =>
                  if has_pos {
                    ElkPoint::new(node.x + port.x, node.y + node.height)
                  } else {
                    ElkPoint::new(
                      node.x + node.width / 2.0,
                      node.y + node.height,
                    )
                  }
                West =>
                  if has_pos {
                    ElkPoint::new(node.x, node.y + port.y)
                  } else {
                    ElkPoint::new(node.x, node.y + node.height / 2.0)
                  }
                East =>
                  if has_pos {
                    ElkPoint::new(node.x + node.width, node.y + port.y)
                  } else {
                    ElkPoint::new(
                      node.x + node.width,
                      node.y + node.height / 2.0,
                    )
                  }
                _ => default_edge_anchor(node, direction, is_source)
              }
            }
            None => default_edge_anchor(node, direction, is_source)
          }
        None => default_edge_anchor(node, direction, is_source)
      }
    None => ElkPoint::new(0.0, 0.0)
  }
}

///|
fn place_end_labels(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
) -> Unit {
  let default_selection = match options.edge_label_side_selection {
    Some(s) => s
    None => DirectionDown
  }
  let default_side_sign = side_selection_sign(default_selection, direction).to_double()
  let along = along_sign(direction).to_double()
  let label_spacing = options.edge_label_spacing.unwrap_or(2.0)
  let label_label_spacing = options.label_label_spacing.unwrap_or(0.0)
  let label_offset = options.label_node_spacing.unwrap_or(5.0)
  let edge_offset = options.edge_label_spacing.unwrap_or(2.0)
  for edge in graph.edges {
    if edge.labels.is_empty() {
      continue
    }
    let head_labels : Array[LLabel] = []
    let tail_labels : Array[LLabel] = []
    for label in edge.labels {
      match effective_edge_label_placement(options, label) {
        Head => head_labels.push(label)
        Tail => tail_labels.push(label)
        _ => ()
      }
    }
    fn stack_total(labels : Array[LLabel], spacing : Double) -> Double {
      let mut total = 0.0
      for i, label in labels {
        total = total + label.height
        if i + 1 < labels.length() {
          total = total + spacing
        }
      }
      total
    }

    if !head_labels.is_empty() {
      let anchor = edge_anchor_point(graph, edge, direction, true)
      let total_h = stack_total(head_labels, label_spacing)
      let mut cursor = -total_h / 2.0
      for label in head_labels {
        let side_sign = match
          label.properties.get_int("diago.layered.labelSideSign") {
          Some(v) => v.to_double()
          None => default_side_sign
        }
        let mut lx = anchor.x
        let mut ly = anchor.y
        if direction.is_vertical() {
          lx = lx + side_sign * (edge_offset + label_offset)
          ly = ly + along * label_offset + cursor
        } else {
          lx = lx + along * label_offset + cursor
          ly = ly + side_sign * (edge_offset + label_offset)
        }
        label.x = lx - label.width / 2.0
        label.y = ly
        cursor = cursor + label.height + label_spacing + label_label_spacing
      }
    }
    if !tail_labels.is_empty() {
      let anchor = edge_anchor_point(graph, edge, direction, false)
      let total_h = stack_total(tail_labels, label_spacing)
      let mut cursor = -total_h / 2.0
      for label in tail_labels {
        let side_sign = match
          label.properties.get_int("diago.layered.labelSideSign") {
          Some(v) => v.to_double()
          None => default_side_sign
        }
        let mut lx = anchor.x
        let mut ly = anchor.y
        if direction.is_vertical() {
          lx = lx + side_sign * (edge_offset + label_offset)
          ly = ly - along * label_offset + cursor
        } else {
          lx = lx - along * label_offset + cursor
          ly = ly + side_sign * (edge_offset + label_offset)
        }
        label.x = lx - label.width / 2.0
        label.y = ly
        cursor = cursor + label.height + label_spacing + label_label_spacing
      }
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
  strategy : CrossingMinimizationStrategy,
  thoroughness : Int,
) -> Unit {
  match strategy {
    LayerSweep => layer_sweep_crossing_min(graph, thoroughness)
    InteractiveCrossMin | None => () // No minimization
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
      // Deterministic tie-break.
    } else if a.position != b.position {
      a.position - b.position
    } else {
      a.id.compare(b.id)
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
  options : LayoutOptions,
  strategy : NodePlacementStrategy,
  direction : LayoutDirection,
) -> Unit {
  match strategy {
    Simple => simple_node_placement(graph, options, direction)
    BrandesKoepf => brandes_koepf_placement(graph, options, direction)
    _ => simple_node_placement(graph, options, direction)
  }
}

///|
/// Simple node placement - evenly distributed within layers
fn simple_node_placement(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
) -> Unit {
  let node_spacing = options.node_node_spacing.unwrap_or(20.0)
  let layer_spacing = options.node_node_between_layers_spacing.unwrap_or(40.0)
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))

  // Determine if horizontal or vertical layout
  let is_horizontal = direction.is_horizontal()

  // Calculate layer positions
  let mut layer_offset = if is_horizontal { padding.left } else { padding.top }
  let reverse_layers = match direction {
    Up => !is_horizontal
    Left => is_horizontal
    _ => false
  }
  let layers : Array[LLayer] = []
  if reverse_layers {
    for i = 0; i < graph.layers.length(); i = i + 1 {
      let idx = graph.layers.length() - 1 - i
      layers.push(graph.layers[idx])
    }
  } else {
    layers.append(graph.layers)
  }
  for layer in layers {
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
  options : LayoutOptions,
  direction : LayoutDirection,
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
  routing : EdgeRouting,
  direction : LayoutDirection,
) -> Unit {
  match routing {
    Orthogonal => orthogonal_routing(graph, direction)
    Polyline => polyline_routing(graph, direction)
    Splines => spline_routing(graph, direction)
    Undefined => orthogonal_routing(graph, direction)
  }
}

///|
/// Orthogonal edge routing - strict 90-degree turns with slot assignment
fn orthogonal_routing(graph : LGraph, direction : LayoutDirection) -> Unit {
  let edge_spacing = 10.0 // Default edge spacing

  // Use improved routing with slot assignment
  route_edges_orthogonal(graph, direction, edge_spacing)

  // Clean up unnecessary bend points
  straighten_edges(graph)
}

///|
/// Polyline edge routing - direct connections with bend points
fn polyline_routing(graph : LGraph, direction : LayoutDirection) -> Unit {
  // For polyline, edges go directly through dummy node positions
  // Bend points are already set from dummy nodes
  let _ = graph
  let _ = direction

}

///|
/// Spline edge routing (placeholder)
fn spline_routing(graph : LGraph, direction : LayoutDirection) -> Unit {
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
