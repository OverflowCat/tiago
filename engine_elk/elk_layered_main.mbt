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
#warnings("-unused_value")
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
fn elk_layered_layout_impl(graph : ElkNode, options : LayoutOptions) -> Unit {
  fn collect_all_edges(node : ElkNode, out : Array[ElkEdge]) -> Unit {
    for edge in node.edges {
      out.push(edge)
    }
    for child in node.children {
      collect_all_edges(child, out)
    }
  }

  let all_edges : Array[ElkEdge] = []
  collect_all_edges(graph, all_edges)
  fn layout_rec(
    node : ElkNode,
    inherited : LayoutOptions,
    all_edges : Array[ElkEdge],
  ) -> Unit {
    let resolved_options = resolve_options_for_graph(inherited, node)
    ensure_sizes(node, resolved_options)

    // First, recursively layout compound nodes.
    for child in node.children {
      if child.children.length() > 0 {
        layout_rec(child, resolved_options, all_edges)
      }
    }

    // Convert ElkNode to internal LGraph representation.
    let direction = resolved_options.direction.unwrap_or(Down)
    let lgraph = LGraph::from_elk_node(node, direction)

    // ELK INCLUDE_CHILDREN: internal layout of a compound node needs to "feel"
    // outgoing hierarchy edges (to outside nodes) so port distribution and
    // spacing match D2/ELK. We approximate this by injecting ExternalPort
    // dummies for edges that cross this node's subtree boundary (both incoming
    // and outgoing).
    fn collect_subtree_ids(node : ElkNode, set : Map[String, Bool]) -> Unit {
      set[node.id] = true
      for child in node.children {
        collect_subtree_ids(child, set)
      }
    }

    let subtree_ids : Map[String, Bool] = {}
    collect_subtree_ids(node, subtree_ids)

    // Merge hierarchy edges per endpoint (ELK: MERGE_HIERARCHY_EDGES default).
    let dummy_by_src : Map[String, String] = {}
    let dummy_by_tgt : Map[String, String] = {}
    fn port_side(direction : LayoutDirection, suffix : String) -> ElkPortSide {
      match direction {
        Up =>
          if suffix == "src" {
            ElkPortSide::North
          } else {
            ElkPortSide::South
          }
        Left =>
          if suffix == "src" {
            ElkPortSide::West
          } else {
            ElkPortSide::East
          }
        Right =>
          if suffix == "src" {
            ElkPortSide::East
          } else {
            ElkPortSide::West
          }
        _ => if suffix == "src" { ElkPortSide::South } else { ElkPortSide::North }
      }
    }
    fn opposite_side(side : ElkPortSide) -> ElkPortSide {
      match side {
        North => South
        South => North
        East => West
        West => East
        Undefined => Undefined
      }
    }

    fn ensure_auto_port(
      node : LNode,
      edge_id : String,
      suffix : String,
      direction : LayoutDirection,
      port_index : Int,
    ) -> String {
      let port_id = node.id + "|auto|" + edge_id + "|" + suffix
      for p in node.ports {
        if p.id == port_id {
          return port_id
        }
      }
      let p = LPort::new(port_id)
      p.side = port_side(direction, suffix)
      p.properties.set("elk.port.index", Int(port_index))
      p.properties.set("diago.layered.autoPort", Bool(true))
      node.ports.push(p)
      port_id
    }

    fn ensure_dummy_port(
      dummy : LNode,
      edge_id : String,
      dummy_suffix : String,
      direction : LayoutDirection,
    ) -> String {
      // One shared port per dummy (multiple hierarchy edges may be merged).
      let port_id = dummy.id + "|p0"
      for p in dummy.ports {
        if p.id == port_id {
          return port_id
        }
      }
      let ext_side = port_side(direction, dummy_suffix)
      let p = LPort::new(port_id)
      p.side = opposite_side(ext_side)
      dummy.ports.push(p)
      // External port dummies behave like fixed-position ports in ELK.
      if dummy.properties.get_string("elk.portConstraints") is None {
        dummy.properties.set("elk.portConstraints", Enum("FIXED_POS"))
      }
      // Keep enough info around for hierarchical port capture.
      dummy.properties.set("diago.layered.extPortSide", Enum(ext_side.to_string()))
      dummy.properties.set("diago.layered.extPortEdgeId", String(edge_id))
      port_id
    }
    for i, edge in all_edges {
      if edge.sources.is_empty() || edge.targets.is_empty() {
        continue
      }
      let orig_src = edge.sources[0]
      let orig_tgt = edge.targets[0]

      // Outgoing boundary edges: internal source is inside, target is outside.
      if subtree_ids.contains(orig_src) && !subtree_ids.contains(orig_tgt) {
        // Only consider outgoing edges from nodes that are direct children of
        // this graph. Deeper descendants are handled when their parent graphs
        // are laid out.
        if !lgraph.node_map.contains(orig_src) {
          continue
        }
        let src_id = orig_src
        let should_merge = edge.labels.is_empty()
        let dummy_id = if should_merge {
          match dummy_by_src.get(src_id) {
            Some(id) => id
            None => {
              let id = lgraph.alloc_dummy_id()
              let dummy = LNode::new(id, ExternalPort)
              // ELK external port dummies are size-less (#766); any required
              // spacing is handled by routing/spacing processors.
              dummy.width = 0.0
              dummy.height = 0.0
              dummy.properties.set("diago.layered.hierEdgeId", String(edge.id))
              dummy.properties.set("diago.layered.hierEdgeSuffix", String("src"))
              lgraph.add_node(dummy)
              dummy_by_src[src_id] = id
              id
            }
          }
        } else {
          let id = lgraph.alloc_dummy_id()
          let dummy = LNode::new(id, ExternalPort)
          dummy.width = 0.0
          dummy.height = 0.0
          dummy.properties.set("diago.layered.hierEdgeId", String(edge.id))
          dummy.properties.set("diago.layered.hierEdgeSuffix", String("src"))
          lgraph.add_node(dummy)
          id
        }
        let ledge = LEdge::new(
          "h_" + edge.id + "_" + dummy_id,
          src_id,
          dummy_id,
        )
        ledge.original_id = Some(edge.id)
        ledge.properties.set("diago.layered.hierEdgeId", String(edge.id))
        ledge.properties.set("diago.layered.hierEdgeSuffix", String("src"))
        match (lgraph.get_node(src_id), lgraph.get_node(dummy_id)) {
          (Some(src), Some(dummy)) => {
            ledge.source_port_id = Some(
              ensure_auto_port(src, edge.id, "src", direction, i),
            )
            ledge.target_port_id = Some(
              ensure_dummy_port(dummy, edge.id, "src", direction),
            )
          }
          _ => ()
        }
        match lgraph.get_node(src_id) {
          Some(src) => src.outgoing_edges.push(ledge)
          None => ()
        }
        match lgraph.get_node(dummy_id) {
          Some(tgt) => tgt.incoming_edges.push(ledge)
          None => ()
        }
        lgraph.edges.push(ledge)
        continue
      }

      // Incoming boundary edges: external source is outside, internal target is inside.
      if !subtree_ids.contains(orig_src) && subtree_ids.contains(orig_tgt) {
        // Only consider incoming edges to nodes that are direct children of
        // this graph. Deeper descendants are handled when their parent graphs
        // are laid out.
        if !lgraph.node_map.contains(orig_tgt) {
          continue
        }
        let tgt_id = orig_tgt
        let should_merge = edge.labels.is_empty()
        let dummy_id = if should_merge {
          match dummy_by_tgt.get(tgt_id) {
            Some(id) => id
            None => {
              let id = lgraph.alloc_dummy_id()
              let dummy = LNode::new(id, ExternalPort)
              dummy.width = 0.0
              dummy.height = 0.0
              dummy.properties.set("diago.layered.hierEdgeId", String(edge.id))
              dummy.properties.set("diago.layered.hierEdgeSuffix", String("dst"))
              lgraph.add_node(dummy)
              dummy_by_tgt[tgt_id] = id
              id
            }
          }
        } else {
          let id = lgraph.alloc_dummy_id()
          let dummy = LNode::new(id, ExternalPort)
          dummy.width = 0.0
          dummy.height = 0.0
          dummy.properties.set("diago.layered.hierEdgeId", String(edge.id))
          dummy.properties.set("diago.layered.hierEdgeSuffix", String("dst"))
          lgraph.add_node(dummy)
          id
        }
        let ledge = LEdge::new(
          "h_" + edge.id + "_" + dummy_id,
          dummy_id,
          tgt_id,
        )
        ledge.original_id = Some(edge.id)
        ledge.properties.set("diago.layered.hierEdgeId", String(edge.id))
        ledge.properties.set("diago.layered.hierEdgeSuffix", String("dst"))
        match (lgraph.get_node(dummy_id), lgraph.get_node(tgt_id)) {
          (Some(dummy), Some(tgt)) => {
            ledge.source_port_id = Some(
              ensure_dummy_port(dummy, edge.id, "dst", direction),
            )
            ledge.target_port_id = Some(
              ensure_auto_port(tgt, edge.id, "dst", direction, i),
            )
          }
          _ => ()
        }
        match lgraph.get_node(dummy_id) {
          Some(src) => src.outgoing_edges.push(ledge)
          None => ()
        }
        match lgraph.get_node(tgt_id) {
          Some(tgt) => tgt.incoming_edges.push(ledge)
          None => ()
        }
        lgraph.edges.push(ledge)
        continue
      }
    }

    // Get options with defaults.
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

    // Persist inner edge segment routes for INCLUDE_CHILDREN hierarchy edges.
    // (Later used by the cross-hierarchy stitcher in `to_elk_node`.)
    fn anchor_for_port(node : LNode, port_id : String?) -> (Double, Double)? {
      match port_id {
        None => None
        Some(pid) => {
          for port in node.ports {
            if port.id != pid {
              continue
            }
            let has_size = port.width > 0.0 || port.height > 0.0
            if has_size {
              return Some(
                (
                  node.x + port.x + port.width / 2.0,
                  node.y + port.y + port.height / 2.0,
                ),
              )
            }
            let has_pos = port.x != 0.0 || port.y != 0.0
            let border = port.properties.get_double_or(
              "diago.layered.portBorderOffset", 0.0,
            )
            let pt = match port.side {
              North =>
                if has_pos {
                  (node.x + port.x, node.y + border)
                } else {
                  (node.x + node.width / 2.0, node.y + border)
                }
              South =>
                if has_pos {
                  (node.x + port.x, node.y + node.height - border)
                } else {
                  (node.x + node.width / 2.0, node.y + node.height - border)
                }
              West =>
                if has_pos {
                  (node.x + border, node.y + port.y)
                } else {
                  (node.x + border, node.y + node.height / 2.0)
                }
              East =>
                if has_pos {
                  (node.x + node.width - border, node.y + port.y)
                } else {
                  (node.x + node.width - border, node.y + node.height / 2.0)
                }
              Undefined =>
                (node.x + node.width / 2.0, node.y + node.height / 2.0)
            }
            return Some(pt)
          }
          None
        }
      }
    }

    fn edge_polyline_points(
      graph : LGraph,
      edge : LEdge,
      direction : LayoutDirection,
    ) -> Array[ElkPoint] {
      let out : Array[ElkPoint] = []
      match (graph.get_node(edge.source_id), graph.get_node(edge.target_id)) {
        (Some(src), Some(tgt)) => {
          let (sx, sy) = anchor_for_port(src, edge.source_port_id).unwrap_or(
            (src.x + src.width / 2.0, src.y + src.height / 2.0),
          )
          let (tx, ty) = anchor_for_port(tgt, edge.target_port_id).unwrap_or(
            (tgt.x + tgt.width / 2.0, tgt.y + tgt.height / 2.0),
          )
          // Keep the edge's parallel offset semantics aligned with `to_elk_node`.
          let offset = edge.parallel_offset
          let (sx, sy, tx, ty) = if direction.is_vertical() {
            (sx + offset, sy, tx + offset, ty)
          } else if direction.is_horizontal() {
            (sx, sy + offset, tx, ty + offset)
          } else {
            (sx + offset, sy, tx + offset, ty)
          }
          out.push(ElkPoint::new(sx, sy))
          for bp in edge.bend_points {
            out.push(bp)
          }
          out.push(ElkPoint::new(tx, ty))
        }
        _ => ()
      }
      out
    }

    for e in lgraph.edges {
      // Only capture our injected hierarchy edge segments.
      let eid = e.properties.get_string("diago.layered.hierEdgeId")
      let suffix = e.properties.get_string("diago.layered.hierEdgeSuffix")
      guard eid is Some(edge_id) && suffix is Some(sfx) else { continue }
      let points = edge_polyline_points(lgraph, e, direction)
      if points.length() < 2 {
        continue
      }
      let key = "diago.layered.hierSeg." + edge_id + "." + sfx
      let arr : Array[PropertyValue] = []
      for p in points {
        arr.push(Point(p))
      }
      node.properties.set(key, Array(arr))
    }

    // Capture ExternalPort dummy coordinates for hierarchical port positioning
    // in the parent graph. This mirrors ELK's hierarchical port processors
    // which derive hierarchical port coordinates from their dummy nodes.
    for n in lgraph.nodes {
      if n.node_type != ExternalPort {
        continue
      }
      let edge_id = n.properties.get_string("diago.layered.hierEdgeId")
      let suffix = n.properties.get_string("diago.layered.hierEdgeSuffix")
      match (edge_id, suffix) {
        (Some(eid), Some(sfx)) => {
          let cx = n.x + n.width / 2.0
          let cy = n.y + n.height / 2.0
          node.properties.set(
            "diago.layered.hierPort." + eid + "." + sfx + ".x",
            Double(cx),
          )
          node.properties.set(
            "diago.layered.hierPort." + eid + "." + sfx + ".y",
            Double(cy),
          )
        }
        _ => ()
      }
    }

    // Apply results back to ElkNode.
    lgraph.to_elk_node(node, direction, resolved_options)
  }

  layout_rec(graph, options, all_edges)
}

///|
/// Execute the layered layout algorithm
#warnings("-unused_value")
fn elk_layered_layout(graph : ElkNode, options : LayoutOptions) -> Unit {
  elk_layered_layout_with_components(graph, options)
}

// ============================================================================
// Phase 1: Cycle Breaking
// ============================================================================

///|
/// Break cycles in the graph by reversing certain edges
fn break_cycles(graph : LGraph, strategy : CycleBreakingStrategy) -> Unit {
  match strategy {
    GreedyCycleBreaker => greedy_cycle_breaker(graph, false)
    GreedyModelOrder => greedy_cycle_breaker(graph, true)
    DepthFirst => dfs_cycle_breaker(graph)
    InteractiveCycleBreaker => greedy_cycle_breaker(graph, false)
    ModelOrder => greedy_cycle_breaker(graph, true)
  }
}

///|
/// Greedy cycle breaker - based on ELK's GreedyCycleBreaker
/// Uses out-degree vs in-degree heuristic to select edges to reverse
fn greedy_cycle_breaker(graph : LGraph, use_model_order : Bool) -> Unit {
  let nodes = graph.nodes
  if nodes.is_empty() {
    return
  }
  let node_order : Map[String, Int] = {}
  for i, node in nodes {
    node_order[node.id] = i
  }
  let indeg : Map[String, Int] = {}
  let outdeg : Map[String, Int] = {}
  let mark : Map[String, Int] = {}
  for node in nodes {
    indeg[node.id] = 0
    outdeg[node.id] = 0
    mark[node.id] = 0
  }
  for edge in graph.edges {
    if edge.source_id == edge.target_id {
      continue
    }
    let mut prio = edge.priority
    if prio < 0 {
      prio = 0
    }
    let w = prio + 1
    outdeg[edge.source_id] = outdeg.get(edge.source_id).unwrap_or(0) + w
    indeg[edge.target_id] = indeg.get(edge.target_id).unwrap_or(0) + w
  }
  let sources : Array[LNode] = []
  let sinks : Array[LNode] = []
  for node in nodes {
    let outd = outdeg.get(node.id).unwrap_or(0)
    let ind = indeg.get(node.id).unwrap_or(0)
    if outd == 0 {
      sinks.push(node)
    } else if ind == 0 {
      sources.push(node)
    }
  }
  let mut next_right = -1
  let mut next_left = 1
  let mut remaining = nodes.length()
  fn reverse_edge_in_graph(graph : LGraph, edge : LEdge) -> Unit {
    let old_src = edge.source_id
    let old_tgt = edge.target_id
    match graph.get_node(old_src) {
      Some(node) => {
        let idx = find_edge_index(node.outgoing_edges, edge.id)
        if idx >= 0 {
          node.outgoing_edges.remove(idx) |> ignore
        }
      }
      None => ()
    }
    match graph.get_node(old_tgt) {
      Some(node) => {
        let idx = find_edge_index(node.incoming_edges, edge.id)
        if idx >= 0 {
          node.incoming_edges.remove(idx) |> ignore
        }
      }
      None => ()
    }
    edge.reverse()
    match graph.get_node(edge.source_id) {
      Some(node) => node.outgoing_edges.push(edge)
      None => ()
    }
    match graph.get_node(edge.target_id) {
      Some(node) => node.incoming_edges.push(edge)
      None => ()
    }
  }

  fn update_neighbors(
    graph : LGraph,
    indeg : Map[String, Int],
    outdeg : Map[String, Int],
    mark : Map[String, Int],
    sources : Array[LNode],
    sinks : Array[LNode],
    node : LNode,
  ) -> Unit {
    for edge in node.outgoing_edges {
      if edge.source_id == edge.target_id {
        continue
      }
      let other_id = edge.target_id
      if mark.get(other_id).unwrap_or(0) != 0 {
        continue
      }
      let mut prio = edge.priority
      if prio < 0 {
        prio = 0
      }
      let w = prio + 1
      indeg[other_id] = indeg.get(other_id).unwrap_or(0) - w
      if indeg.get(other_id).unwrap_or(0) <= 0 &&
        outdeg.get(other_id).unwrap_or(0) > 0 {
        match graph.get_node(other_id) {
          Some(n) => sources.push(n)
          None => ()
        }
      }
    }
    for edge in node.incoming_edges {
      if edge.source_id == edge.target_id {
        continue
      }
      let other_id = edge.source_id
      if mark.get(other_id).unwrap_or(0) != 0 {
        continue
      }
      let mut prio = edge.priority
      if prio < 0 {
        prio = 0
      }
      let w = prio + 1
      outdeg[other_id] = outdeg.get(other_id).unwrap_or(0) - w
      if outdeg.get(other_id).unwrap_or(0) <= 0 &&
        indeg.get(other_id).unwrap_or(0) > 0 {
        match graph.get_node(other_id) {
          Some(n) => sinks.push(n)
          None => ()
        }
      }
    }
  }

  while remaining > 0 {
    while !sinks.is_empty() {
      let sink = sinks[0]
      sinks.remove(0) |> ignore
      if mark.get(sink.id).unwrap_or(0) != 0 {
        continue
      }
      mark[sink.id] = next_right
      next_right = next_right - 1
      update_neighbors(graph, indeg, outdeg, mark, sources, sinks, sink)
      remaining = remaining - 1
    }
    while !sources.is_empty() {
      let source = sources[0]
      sources.remove(0) |> ignore
      if mark.get(source.id).unwrap_or(0) != 0 {
        continue
      }
      mark[source.id] = next_left
      next_left = next_left + 1
      update_neighbors(graph, indeg, outdeg, mark, sources, sinks, source)
      remaining = remaining - 1
    }
    if remaining > 0 {
      let mut max_outflow = @int.min_value
      let candidates : Array[LNode] = []
      for node in nodes {
        if mark.get(node.id).unwrap_or(0) != 0 {
          continue
        }
        let outflow = outdeg.get(node.id).unwrap_or(0) -
          indeg.get(node.id).unwrap_or(0)
        if outflow > max_outflow {
          max_outflow = outflow
          candidates.clear()
          candidates.push(node)
        } else if outflow == max_outflow {
          candidates.push(node)
        }
      }
      let mut chosen = candidates[0]
      if use_model_order {
        let mut best = @int.max_value
        for node in candidates {
          let ord = node_order.get(node.id).unwrap_or(@int.max_value)
          if ord < best {
            best = ord
            chosen = node
          }
        }
      }
      mark[chosen.id] = next_left
      next_left = next_left + 1
      update_neighbors(graph, indeg, outdeg, mark, sources, sinks, chosen)
      remaining = remaining - 1
    }
  }
  let shift_base = nodes.length() + 1
  for node in nodes {
    let v = mark.get(node.id).unwrap_or(0)
    if v < 0 {
      mark[node.id] = v + shift_base
    }
  }
  for edge in graph.edges {
    let source_mark = mark.get(edge.source_id).unwrap_or(0)
    let target_mark = mark.get(edge.target_id).unwrap_or(0)
    if source_mark > target_mark {
      reverse_edge_in_graph(graph, edge)
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
  // Our internal label-dummy insertion runs before layering and relies on the
  // invariant that dummy edges span at least one layer. Some layerers can
  // still produce invalid assignments involving label dummies; repair those
  // locally to avoid global drift.
  let max_iters = graph.nodes.length() + 1
  for _iter = 0; _iter < max_iters; _iter = _iter + 1 {
    let mut changed = false
    for edge in graph.edges {
      if edge.source_id == edge.target_id {
        continue
      }
      match (graph.get_node(edge.source_id), graph.get_node(edge.target_id)) {
        (Some(src), Some(tgt)) =>
          if src.node_type is LabelDummy || tgt.node_type is LabelDummy {
            if tgt.layer < src.layer + 1 {
              tgt.layer = src.layer + 1
              changed = true
            }
          }
        _ => ()
      }
    }
    if !changed {
      break
    }
  }
}

///|
/// Longest path layering - simple and effective
fn longest_path_layering(graph : LGraph) -> Unit {
  // Check if we have any edges
  let has_edges = graph.edges.length() > 0

  // If no edges, either keep a single layer or stack by model order.
  if !has_edges {
    let keep_single = graph.properties.get_bool_or(
      "diago.layered.keepSingleLayerNoEdges", false,
    )
    if keep_single {
      for node in graph.nodes {
        node.layer = 0
      }
    } else {
      for i, node in graph.nodes {
        node.layer = i
      }
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
  let label_label_spacing = options.label_label_spacing.unwrap_or(0.0)
  let edge_label_spacing = options.edge_label_spacing.unwrap_or(2.0)
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
    // Follow ELK's LabelDummyInserter sizing:
    // - Vertical layout stacks labels horizontally (width sums; height is max).
    // - Horizontal layout stacks labels vertically (width is max; height sums).
    // Always reserve edge-label spacing and edge thickness in the dummy size.
    fn edge_thickness(edge : LEdge) -> Double {
      let mut thickness = match
        edge.properties.get_double("elk.edge.thickness") {
        Some(v) => v
        None =>
          match edge.properties.get_double("org.eclipse.elk.edge.thickness") {
            Some(v) => v
            None => 1.0
          }
      }
      if thickness < 0.0 {
        thickness = 0.0
        edge.properties.set("elk.edge.thickness", Double(thickness))
      }
      thickness
    }

    let thickness = edge_thickness(edge)
    let n = center_labels.length()
    let gaps = (n - 1).to_double()
    let mut max_w = 0.0
    let mut max_h = 0.0
    let mut sum_w = 0.0
    let mut sum_h = 0.0
    for label in center_labels {
      if label.width > max_w {
        max_w = label.width
      }
      if label.height > max_h {
        max_h = label.height
      }
      sum_w = sum_w + label.width
      sum_h = sum_h + label.height
    }
    let dir = options.direction.unwrap_or(Down)
    if dir.is_vertical() {
      // ELK LabelDummyInserter:
      // - stack labels horizontally (sum widths + gaps)
      // - height is max label height
      // - add edge-label spacing and edge thickness to height
      dummy.width = sum_w + gaps * label_label_spacing
      dummy.height = max_h + edge_label_spacing + thickness
    } else {
      // ELK LabelDummyInserter:
      // - stack labels vertically (sum heights + gaps)
      // - width is max label width
      // - add edge-label spacing and edge thickness to height
      dummy.width = max_w
      dummy.height = sum_h +
        gaps * label_label_spacing +
        edge_label_spacing +
        thickness
    }
    dummy.properties.set(
      "diago.layered.labelLabelSpacing",
      Double(label_label_spacing),
    )
    graph.add_node(dummy)

    // Create edge from source to label dummy.
    let edge_to_dummy = LEdge::new(
      "e_" + edge.source_id + "_" + dummy_id,
      edge.source_id,
      dummy_id,
    )
    edge_to_dummy.original_id = Some(origin)
    edge_to_dummy.properties.copy_from(edge.properties)
    // The original (carrier) edge is marked as split; the replacement edges must
    // still participate in later phases (layering/placement/routing).
    edge_to_dummy.properties.set("diago.layered.longEdgeSplit", Bool(false))
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
    edge_from_dummy.properties.copy_from(edge.properties)
    edge_from_dummy.properties.set("diago.layered.longEdgeSplit", Bool(false))
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
  fn edge_thickness(edge : LEdge) -> Double {
    let mut thickness = match edge.properties.get_double("elk.edge.thickness") {
      Some(v) => v
      None =>
        match edge.properties.get_double("org.eclipse.elk.edge.thickness") {
          Some(v) => v
          None => 1.0
        }
    }
    if thickness < 0.0 {
      thickness = 0.0
      edge.properties.set("elk.edge.thickness", Double(thickness))
    }
    thickness
  }

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
    let mut prev_port_id = edge.source_port_id
    let direction = if target_layer > source_layer { 1 } else { -1 }
    let mut layer_idx = source_layer + direction
    while layer_idx != target_layer {
      let dummy_id = graph.alloc_dummy_id()
      let dummy = LNode::new(dummy_id, LongEdgeDummy)
      dummy.layer = layer_idx
      dummy.origin_edge = Some(origin)
      let thickness = edge_thickness(edge)
      dummy.width = 0.0
      dummy.height = thickness
      dummy.properties.set("elk.portConstraints", Enum("FIXED_POS"))
      let port_pos = @math.floor(thickness / 2.0)
      let input_port_id = dummy_id + "_in"
      let output_port_id = dummy_id + "_out"
      let input_port = { ..LPort::new(input_port_id), side: West, y: port_pos }
      let output_port = {
        ..LPort::new(output_port_id),
        side: East,
        y: port_pos,
      }
      dummy.ports.push(input_port)
      dummy.ports.push(output_port)
      graph.add_node(dummy)
      let edge_to_dummy = LEdge::new(
        "e_" + prev_node_id + "_" + dummy_id,
        prev_node_id,
        dummy_id,
      )
      edge_to_dummy.original_id = Some(origin)
      edge_to_dummy.properties.copy_from(edge.properties)
      edge_to_dummy.properties.set("diago.layered.longEdgeSplit", Bool(false))
      edge_to_dummy.priority = edge.priority
      edge_to_dummy.source_port_id = prev_port_id
      edge_to_dummy.target_port_id = Some(input_port_id)
      match graph.get_node(prev_node_id) {
        Some(prev) => prev.outgoing_edges.push(edge_to_dummy)
        None => ()
      }
      dummy.incoming_edges.push(edge_to_dummy)
      graph.edges.push(edge_to_dummy)
      prev_node_id = dummy_id
      prev_port_id = Some(output_port_id)
      layer_idx = layer_idx + direction
    }
    let final_edge = LEdge::new(
      "e_" + prev_node_id + "_" + edge.target_id,
      prev_node_id,
      edge.target_id,
    )
    final_edge.original_id = Some(origin)
    final_edge.properties.copy_from(edge.properties)
    final_edge.properties.set("diago.layered.longEdgeSplit", Bool(false))
    final_edge.priority = edge.priority
    final_edge.source_port_id = prev_port_id
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
                  let label_label_spacing = dummy.properties.get_double_or(
                    "diago.layered.labelLabelSpacing",
                    options.label_label_spacing.unwrap_or(0.0),
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
                  let edge_label_spacing = options.edge_label_spacing.unwrap_or(
                    2.0,
                  )
                  let label_port_horizontal_spacing = options.label_port_horizontal_spacing.unwrap_or(
                    1.0,
                  )
                  let label_port_vertical_spacing = options.label_port_vertical_spacing.unwrap_or(
                    1.0,
                  )
                  let perp_x = edge_label_spacing +
                    label_port_horizontal_spacing
                  let perp_y = edge_label_spacing + label_port_vertical_spacing
                  let base_x = if direction.is_vertical() {
                    dummy.x + side_sign * perp_x
                  } else {
                    dummy.x
                  }
                  let mut y = if direction.is_horizontal() {
                    dummy.y + side_sign * perp_y
                  } else {
                    dummy.y
                  }
                  for i, label in center_labels {
                    label.x = base_x + (dummy.width - label.width) / 2.0
                    label.y = y
                    y = y + label.height
                    if i + 1 < center_labels.length() {
                      y = y + label_label_spacing
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
#warnings("-unused_value")
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
priv struct SliContext {
  graph : LGraph
  strategy : OrderingStrategy
  incoming_by_port : Map[String, Array[LEdge]]
  outgoing_by_port : Map[String, Array[LEdge]]
}

///|
fn SliContext::new(
  graph : LGraph,
  strategy : OrderingStrategy,
  incoming_by_port : Map[String, Array[LEdge]],
  outgoing_by_port : Map[String, Array[LEdge]],
) -> SliContext {
  { graph, strategy, incoming_by_port, outgoing_by_port }
}

///|
priv struct SliNodeOrderState {
  node_bigger_than : Map[String, Map[String, Bool]]
  node_smaller_than : Map[String, Map[String, Bool]]
}

///|
fn SliNodeOrderState::new() -> SliNodeOrderState {
  { node_bigger_than: {}, node_smaller_than: {} }
}

///|
priv struct SliPortOrderState {
  port_bigger_than : Map[String, Map[String, Bool]]
  port_smaller_than : Map[String, Map[String, Bool]]
}

///|
fn SliPortOrderState::new() -> SliPortOrderState {
  { port_bigger_than: {}, port_smaller_than: {} }
}

///|
fn sli_port_model_order_enabled(graph : LGraph) -> Bool {
  graph.properties.get_bool_or(
    "elk.layered.considerModelOrder.portModelOrder", false,
  ) ||
  graph.properties.get_bool_or(
    "org.eclipse.elk.alg.layered.considerModelOrder.portModelOrder", false,
  )
}

///|
fn sli_node_model_order(node : LNode) -> Int? {
  if node.node_type is Normal {
    node.properties.get_int("diago.layered.modelOrder")
  } else {
    None
  }
}

///|
fn sli_edge_model_order(edge : LEdge) -> Int {
  edge.properties.get_int("diago.layered.modelOrder").unwrap_or(0)
}

///|
fn sli_port_model_order(port : LPort) -> Int? {
  port.properties.get_int("diago.layered.modelOrder")
}

///|
fn sli_port_side_order(side : ElkPortSide) -> Int {
  match side {
    North => 0
    East => 1
    South => 2
    West => 3
    Undefined => 4
  }
}

///|
fn sli_incoming_edges_for_port(
  incoming_by_port : Map[String, Array[LEdge]],
  port_id : String,
) -> Array[LEdge] {
  incoming_by_port.get(port_id).unwrap_or([])
}

///|
fn sli_outgoing_edges_for_port(
  outgoing_by_port : Map[String, Array[LEdge]],
  port_id : String,
) -> Array[LEdge] {
  outgoing_by_port.get(port_id).unwrap_or([])
}

///|
fn sli_first_incoming_edge(
  node : LNode,
  incoming_by_port : Map[String, Array[LEdge]],
) -> LEdge? {
  if node.ports.is_empty() {
    if !node.incoming_edges.is_empty() {
      return Some(node.incoming_edges[0])
    }
    return None
  }
  for port in node.ports {
    let incoming = sli_incoming_edges_for_port(incoming_by_port, port.id)
    if !incoming.is_empty() {
      return Some(incoming[0])
    }
  }
  None
}

///|
fn sli_first_outgoing_edge(
  node : LNode,
  outgoing_by_port : Map[String, Array[LEdge]],
) -> LEdge? {
  if node.ports.is_empty() {
    if !node.outgoing_edges.is_empty() {
      return Some(node.outgoing_edges[0])
    }
    return None
  }
  for port in node.ports {
    let outgoing = sli_outgoing_edges_for_port(outgoing_by_port, port.id)
    if !outgoing.is_empty() {
      return Some(outgoing[0])
    }
  }
  None
}

///|
fn sli_get_long_edge_target_node(
  graph : LGraph,
  edge : LEdge,
  outgoing_by_port : Map[String, Array[LEdge]],
) -> LNode? {
  let mut current = edge
  while true {
    match graph.get_node(current.target_id) {
      Some(node) =>
        if node.node_type is Normal {
          return Some(node)
        } else {
          match sli_first_outgoing_edge(node, outgoing_by_port) {
            Some(next) => current = next
            None => return None
          }
        }
      None => return None
    }
  }
  None
}

///|
fn sli_long_edge_target_node_preprocessing(
  graph : LGraph,
  node : LNode,
  outgoing_by_port : Map[String, Array[LEdge]],
) -> Map[String, Int] {
  let target_node_model_order : Map[String, Int] = {}
  for port in node.ports {
    let outgoing = sli_outgoing_edges_for_port(outgoing_by_port, port.id)
    if outgoing.is_empty() {
      continue
    }
    let edge = outgoing[0]
    match sli_get_long_edge_target_node(graph, edge, outgoing_by_port) {
      Some(target_node) => {
        port.properties.set(
          "diago.layered.longEdgeTargetNodeId",
          String(target_node.id),
        )
        if !edge.reversed {
          let previous = target_node_model_order
            .get(target_node.id)
            .unwrap_or(@int.max_value)
          let order = sli_edge_model_order(edge)
          if order < previous {
            target_node_model_order[target_node.id] = order
          }
        }
      }
      None => ()
    }
  }
  target_node_model_order
}

///|
fn sli_node_set_has(
  sets : Map[String, Map[String, Bool]],
  key : String,
  value : String,
) -> Bool {
  match sets.get(key) {
    Some(set) => set.get(value).unwrap_or(false)
    None => false
  }
}

///|
fn sli_node_set_add(
  sets : Map[String, Map[String, Bool]],
  key : String,
  value : String,
) -> Unit {
  let set = sets.get(key).unwrap_or({})
  set[value] = true
  sets[key] = set
}

///|
fn sli_node_set_add_all(
  sets : Map[String, Map[String, Bool]],
  key : String,
  other : Map[String, Bool],
) -> Unit {
  let set = sets.get(key).unwrap_or({})
  for k, v in other {
    if v {
      set[k] = true
    }
  }
  sets[key] = set
}

///|
fn sli_update_node_order(
  state : SliNodeOrderState,
  bigger : LNode,
  smaller : LNode,
) -> Unit {
  sli_node_set_add(state.node_bigger_than, bigger.id, smaller.id)
  sli_node_set_add(state.node_smaller_than, smaller.id, bigger.id)
  let smaller_bigger = state.node_bigger_than.get(smaller.id).unwrap_or({})
  let bigger_smaller = state.node_smaller_than.get(bigger.id).unwrap_or({})
  for very_small, flag in smaller_bigger {
    if flag {
      sli_node_set_add(state.node_bigger_than, bigger.id, very_small)
      sli_node_set_add(state.node_smaller_than, very_small, bigger.id)
      sli_node_set_add_all(state.node_smaller_than, very_small, bigger_smaller)
    }
  }
  for very_big, flag in bigger_smaller {
    if flag {
      sli_node_set_add(state.node_smaller_than, smaller.id, very_big)
      sli_node_set_add(state.node_bigger_than, very_big, smaller.id)
      sli_node_set_add_all(state.node_bigger_than, very_big, smaller_bigger)
    }
  }
}

///|
fn sli_model_order_from_connected_edges(
  node : LNode,
  incoming_by_port : Map[String, Array[LEdge]],
) -> Int {
  match sli_first_incoming_edge(node, incoming_by_port) {
    Some(edge) => sli_edge_model_order(edge)
    None => 0
  }
}

///|
fn sli_first_incoming_from_prev(
  graph : LGraph,
  node : LNode,
  prev_layer : Int,
  incoming_by_port : Map[String, Array[LEdge]],
) -> (LNode?, LPort?, LEdge?) {
  if node.ports.is_empty() {
    for edge in node.incoming_edges {
      match graph.get_node(edge.source_id) {
        Some(src) =>
          if src.layer == prev_layer {
            return (Some(src), None, Some(edge))
          }
        None => ()
      }
    }
    return (None, None, None)
  }
  for port in node.ports {
    let incoming = sli_incoming_edges_for_port(incoming_by_port, port.id)
    if incoming.is_empty() {
      continue
    }
    let edge = incoming[0]
    match graph.get_node(edge.source_id) {
      Some(src) =>
        if src.layer == prev_layer {
          let src_port = match edge.source_port_id {
            Some(pid) => find_port_for_id(src, pid)
            None => None
          }
          return (Some(src), src_port, Some(edge))
        }
      None => ()
    }
  }
  (None, None, None)
}

///|
fn sli_first_incoming_source_port(
  graph : LGraph,
  node : LNode,
  incoming_by_port : Map[String, Array[LEdge]],
) -> LPort? {
  match sli_first_incoming_edge(node, incoming_by_port) {
    Some(edge) =>
      match graph.get_node(edge.source_id) {
        Some(src) =>
          match edge.source_port_id {
            Some(pid) => find_port_for_id(src, pid)
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn sli_first_incoming_source_node(
  graph : LGraph,
  node : LNode,
  incoming_by_port : Map[String, Array[LEdge]],
) -> LNode? {
  match sli_first_incoming_edge(node, incoming_by_port) {
    Some(edge) => graph.get_node(edge.source_id)
    None => None
  }
}

///|
fn sli_first_outgoing_target_node(
  graph : LGraph,
  node : LNode,
  outgoing_by_port : Map[String, Array[LEdge]],
) -> LNode? {
  match sli_first_outgoing_edge(node, outgoing_by_port) {
    Some(edge) => graph.get_node(edge.target_id)
    None => None
  }
}

///|
fn sli_port_set_has(
  sets : Map[String, Map[String, Bool]],
  key : String,
  value : String,
) -> Bool {
  match sets.get(key) {
    Some(set) => set.get(value).unwrap_or(false)
    None => false
  }
}

///|
fn sli_port_set_add(
  sets : Map[String, Map[String, Bool]],
  key : String,
  value : String,
) -> Unit {
  let set = sets.get(key).unwrap_or({})
  set[value] = true
  sets[key] = set
}

///|
fn sli_port_set_add_all(
  sets : Map[String, Map[String, Bool]],
  key : String,
  other : Map[String, Bool],
) -> Unit {
  let set = sets.get(key).unwrap_or({})
  for k, v in other {
    if v {
      set[k] = true
    }
  }
  sets[key] = set
}

///|
fn sli_update_port_order(
  state : SliPortOrderState,
  bigger_ori : LPort,
  smaller_ori : LPort,
  reverse_order : Int,
) -> Unit {
  let bigger = if reverse_order < 0 { smaller_ori } else { bigger_ori }
  let smaller = if reverse_order < 0 { bigger_ori } else { smaller_ori }
  sli_port_set_add(state.port_bigger_than, bigger.id, smaller.id)
  sli_port_set_add(state.port_smaller_than, smaller.id, bigger.id)
  let smaller_bigger = state.port_bigger_than.get(smaller.id).unwrap_or({})
  let bigger_smaller = state.port_smaller_than.get(bigger.id).unwrap_or({})
  for very_small, flag in smaller_bigger {
    if flag {
      sli_port_set_add(state.port_bigger_than, bigger.id, very_small)
      sli_port_set_add(state.port_smaller_than, very_small, bigger.id)
      sli_port_set_add_all(state.port_smaller_than, very_small, bigger_smaller)
    }
  }
  for very_big, flag in bigger_smaller {
    if flag {
      sli_port_set_add(state.port_smaller_than, smaller.id, very_big)
      sli_port_set_add(state.port_bigger_than, very_big, smaller.id)
      sli_port_set_add_all(state.port_bigger_than, very_big, smaller_bigger)
    }
  }
}

///|
fn sli_check_reference_layer(
  layer_nodes : Array[LNode],
  n1 : LNode,
  n2 : LNode,
) -> Int {
  for node in layer_nodes {
    if node.id == n1.id {
      return -1
    } else if node.id == n2.id {
      return 1
    }
  }
  0
}

///|
fn sli_check_port_model_order(p1 : LPort, p2 : LPort) -> Int {
  match (sli_port_model_order(p1), sli_port_model_order(p2)) {
    (Some(a), Some(b)) => a.compare(b)
    _ => 0
  }
}

///|
fn sli_port_compare(
  ctx : SliContext,
  state : SliPortOrderState,
  owner : LNode,
  original_p1 : LPort,
  original_p2 : LPort,
  previous_layer : Array[LNode],
  target_node_model_order : Map[String, Int]?,
  port_model_order_enabled : Bool,
) -> Int {
  let graph = ctx.graph
  let strategy = ctx.strategy
  let incoming_by_port = ctx.incoming_by_port
  let outgoing_by_port = ctx.outgoing_by_port
  let port_bigger_than = state.port_bigger_than
  let port_smaller_than = state.port_smaller_than
  let p1 = original_p1
  let p2 = original_p2
  if sli_port_set_has(port_bigger_than, p1.id, p2.id) {
    return 1
  }
  if sli_port_set_has(port_bigger_than, p2.id, p1.id) {
    return -1
  }
  if sli_port_set_has(port_smaller_than, p1.id, p2.id) {
    return -1
  }
  if sli_port_set_has(port_smaller_than, p2.id, p1.id) {
    return 1
  }
  if p1.side != p2.side {
    let result = sli_port_side_order(p1.side) - sli_port_side_order(p2.side)
    if result > 0 {
      sli_update_port_order(state, p1, p2, 1)
    } else {
      sli_update_port_order(state, p2, p1, 1)
    }
    return result
  }
  let mut reverse_order = 1
  let in1 = sli_incoming_edges_for_port(incoming_by_port, p1.id)
  let in2 = sli_incoming_edges_for_port(incoming_by_port, p2.id)
  let out1 = sli_outgoing_edges_for_port(outgoing_by_port, p1.id)
  let out2 = sli_outgoing_edges_for_port(outgoing_by_port, p2.id)
  if !in1.is_empty() && !in2.is_empty() {
    if p1.side == West || p1.side == North || p1.side == South {
      reverse_order = -reverse_order
    }
    let e1 = in1[0]
    let e2 = in2[0]
    match (graph.get_node(e1.source_id), graph.get_node(e2.source_id)) {
      (Some(n1), Some(n2)) =>
        if n1.id == n2.id {
          for port in n1.ports {
            if port.id == e1.source_port_id.unwrap_or("") {
              sli_update_port_order(state, p2, p1, reverse_order)
              return -reverse_order
            } else if port.id == e2.source_port_id.unwrap_or("") {
              sli_update_port_order(state, p1, p2, reverse_order)
              return reverse_order
            }
          }
          let order1 = sli_edge_model_order(e1)
          let order2 = sli_edge_model_order(e2)
          if order1 > order2 {
            sli_update_port_order(state, p1, p2, reverse_order)
            return reverse_order
          } else {
            sli_update_port_order(state, p2, p1, reverse_order)
            return -reverse_order
          }
        }
      _ => ()
    }
    match (graph.get_node(e1.source_id), graph.get_node(e2.source_id)) {
      (Some(n1), Some(n2)) =>
        if n1.node_type is LongEdgeDummy &&
          n2.node_type is LongEdgeDummy &&
          n1.layer == n2.layer &&
          n1.layer == owner.layer {
          let layer_nodes = graph.layers[n1.layer].nodes
          if p1.side == East && p2.side == East {
            reverse_order = -reverse_order
          }
          let in_prev = sli_check_reference_layer(layer_nodes, n1, n2)
          if in_prev != 0 {
            if in_prev > 0 {
              sli_update_port_order(state, p1, p2, reverse_order)
              return reverse_order
            } else {
              sli_update_port_order(state, p2, p1, reverse_order)
              return -reverse_order
            }
          }
        }
      _ => ()
    }
    match (graph.get_node(e1.source_id), graph.get_node(e2.source_id)) {
      (Some(n1), Some(n2)) => {
        let in_prev = sli_check_reference_layer(previous_layer, n1, n2)
        if in_prev != 0 {
          if in_prev > 0 {
            sli_update_port_order(state, p1, p2, reverse_order)
            return reverse_order
          } else {
            sli_update_port_order(state, p2, p1, reverse_order)
            return -reverse_order
          }
        }
      }
      _ => ()
    }
    if port_model_order_enabled {
      let result = sli_check_port_model_order(p1, p2)
      if result != 0 {
        if result > 0 {
          sli_update_port_order(state, p1, p2, reverse_order)
          return reverse_order
        } else {
          sli_update_port_order(state, p2, p1, reverse_order)
          return -reverse_order
        }
      }
    }
  }
  if !out1.is_empty() && !out2.is_empty() {
    if p1.side == West || p1.side == South {
      reverse_order = -reverse_order
    }
    let e1 = out1[0]
    let e2 = out2[0]
    let target1 = match
      p1.properties.get_string("diago.layered.longEdgeTargetNodeId") {
      Some(id) => graph.get_node(id)
      None => sli_get_long_edge_target_node(graph, e1, outgoing_by_port)
    }
    let target2 = match
      p2.properties.get_string("diago.layered.longEdgeTargetNodeId") {
      Some(id) => graph.get_node(id)
      None => sli_get_long_edge_target_node(graph, e2, outgoing_by_port)
    }
    if strategy == PreferNodes {
      match (target1, target2) {
        (Some(t1), Some(t2)) =>
          match (sli_node_model_order(t1), sli_node_model_order(t2)) {
            (Some(m1), Some(m2)) =>
              if m1 != m2 {
                if m1 > m2 {
                  sli_update_port_order(state, p1, p2, reverse_order)
                  return reverse_order
                } else {
                  sli_update_port_order(state, p2, p1, reverse_order)
                  return -reverse_order
                }
              }
            _ => ()
          }
        _ => ()
      }
    }
    if port_model_order_enabled {
      let result = sli_check_port_model_order(p1, p2)
      if result != 0 {
        if result > 0 {
          sli_update_port_order(state, p1, p2, reverse_order)
          return reverse_order
        } else {
          sli_update_port_order(state, p2, p1, reverse_order)
          return -reverse_order
        }
      }
    }
    let mut order1 = sli_edge_model_order(e1)
    let mut order2 = sli_edge_model_order(e2)
    match (target1, target2) {
      (Some(t1), Some(t2)) =>
        if t1.id == t2.id {
          if order1 > order2 {
            sli_update_port_order(state, p1, p2, reverse_order)
            return reverse_order
          } else {
            sli_update_port_order(state, p2, p1, reverse_order)
            return -reverse_order
          }
        }
      _ => ()
    }
    match target_node_model_order {
      Some(target_order) => {
        match target1 {
          Some(t1) =>
            if target_order.contains(t1.id) {
              order1 = target_order.get(t1.id).unwrap_or(order1)
            }
          None => ()
        }
        match target2 {
          Some(t2) =>
            if target_order.contains(t2.id) {
              order2 = target_order.get(t2.id).unwrap_or(order2)
            }
          None => ()
        }
      }
      None => ()
    }
    if order1 > order2 {
      sli_update_port_order(state, p1, p2, reverse_order)
      return reverse_order
    } else {
      sli_update_port_order(state, p2, p1, reverse_order)
      return -reverse_order
    }
  }
  if !in1.is_empty() && !out2.is_empty() {
    sli_update_port_order(state, p1, p2, reverse_order)
    return 1
  }
  if !out1.is_empty() && !in2.is_empty() {
    sli_update_port_order(state, p2, p1, reverse_order)
    return -1
  }
  match (sli_port_model_order(p1), sli_port_model_order(p2)) {
    (Some(m1), Some(m2)) => {
      if p1.side == West || p1.side == South {
        reverse_order = -reverse_order
      }
      if m1 > m2 {
        sli_update_port_order(state, p1, p2, reverse_order)
        return reverse_order
      } else {
        sli_update_port_order(state, p2, p1, reverse_order)
        return -reverse_order
      }
    }
    _ => ()
  }
  sli_update_port_order(state, p2, p1, reverse_order)
  -1
}

///|
fn sli_compare_ports(
  ctx : SliContext,
  state : SliPortOrderState,
  owner : LNode,
  p1 : LPort,
  p2 : LPort,
  previous_layer : Array[LNode],
  target_node_model_order : Map[String, Int]?,
  port_model_order_enabled : Bool,
) -> Int {
  sli_port_compare(
    ctx, state, owner, p1, p2, previous_layer, target_node_model_order, port_model_order_enabled,
  )
}

///|
fn sli_handle_helper_dummy_nodes(
  ctx : SliContext,
  state : SliNodeOrderState,
  n1 : LNode,
  n2 : LNode,
  previous_layer : Array[LNode],
  before_ports : Bool,
) -> Int {
  let graph = ctx.graph
  let incoming_by_port = ctx.incoming_by_port
  let outgoing_by_port = ctx.outgoing_by_port
  if n1.node_type is LongEdgeDummy && n2.node_type is Normal {
    let dummy_source_node = sli_first_incoming_source_node(
      graph, n1, incoming_by_port,
    )
    let dummy_target_node = sli_first_outgoing_target_node(
      graph, n1, outgoing_by_port,
    )
    let dummy_layer = n1.layer
    match (dummy_source_node, dummy_target_node) {
      (Some(src_node), Some(tgt_node)) => {
        if src_node.layer != dummy_layer && tgt_node.layer != dummy_layer {
          return 0
        }
        if src_node.id == n2.id {
          sli_update_node_order(state, n1, n2)
          return 1
        } else if tgt_node.id == n2.id {
          sli_update_node_order(state, n1, n2)
          return 1
        } else {
          return sli_compare_nodes(
            ctx, state, src_node, n2, previous_layer, before_ports,
          )
        }
      }
      _ => return 0
    }
  } else if n1.node_type is Normal && n2.node_type is LongEdgeDummy {
    let dummy_source_node = sli_first_incoming_source_node(
      graph, n2, incoming_by_port,
    )
    let dummy_target_node = sli_first_outgoing_target_node(
      graph, n2, outgoing_by_port,
    )
    let dummy_layer = n1.layer
    match (dummy_source_node, dummy_target_node) {
      (Some(src_node), Some(tgt_node)) => {
        if src_node.layer != dummy_layer && tgt_node.layer != dummy_layer {
          return 0
        }
        if src_node.id == n1.id {
          sli_update_node_order(state, n2, n1)
          return -1
        } else if tgt_node.id == n1.id {
          sli_update_node_order(state, n2, n1)
          return -1
        } else {
          return sli_compare_nodes(
            ctx, state, n1, src_node, previous_layer, before_ports,
          )
        }
      }
      _ => return 0
    }
  } else if n1.node_type is LongEdgeDummy && n2.node_type is LongEdgeDummy {
    let n1_source_port = sli_first_incoming_source_port(
      graph, n1, incoming_by_port,
    )
    let n1_source_node = sli_first_incoming_source_node(
      graph, n1, incoming_by_port,
    )
    let n1_target_node = sli_first_outgoing_target_node(
      graph, n1, outgoing_by_port,
    )
    let n2_source_port = sli_first_incoming_source_port(
      graph, n2, incoming_by_port,
    )
    let n2_source_node = sli_first_incoming_source_node(
      graph, n2, incoming_by_port,
    )
    let n2_target_node = sli_first_outgoing_target_node(
      graph, n2, outgoing_by_port,
    )
    let n1_layer = n1.layer
    let n2_layer = n2.layer
    let mut n1_source_feedback = false
    let mut n1_target_feedback = false
    let mut n2_source_feedback = false
    let mut n2_target_feedback = false
    let mut n1_ref = n1
    let mut n2_ref = n2
    match (n1_source_node, n1_target_node) {
      (Some(src), Some(tgt)) =>
        if src.layer == n1_layer {
          n1_source_feedback = true
          n1_ref = src
        } else if tgt.layer == n1_layer {
          n1_target_feedback = true
          n1_ref = tgt
        }
      _ => ()
    }
    match (n2_source_node, n2_target_node) {
      (Some(src), Some(tgt)) =>
        if src.layer == n2_layer {
          n2_source_feedback = true
          n2_ref = src
        } else if tgt.layer == n2_layer {
          n2_target_feedback = true
          n2_ref = tgt
        }
      _ => ()
    }
    if n1_ref.id == n2_ref.id {
      if before_ports {
        if n1_source_feedback && n2_source_feedback {
          match (n1_source_port, n2_source_port) {
            (Some(p1), Some(p2)) => {
              let port_state = SliPortOrderState::new()
              let result = sli_compare_ports(
                ctx,
                port_state,
                n1_ref,
                p1,
                p2,
                previous_layer,
                None,
                n2_target_feedback,
              )
              if result > 0 {
                sli_update_node_order(state, n2, n1)
                return 1
              } else {
                sli_update_node_order(state, n1, n2)
                return -1
              }
            }
            _ => ()
          }
        } else if n1_source_feedback && n2_target_feedback {
          sli_update_node_order(state, n2, n1)
          return 1
        } else if n1_target_feedback && n2_source_feedback {
          sli_update_node_order(state, n1, n2)
          return -1
        } else if n1_target_feedback && n2_target_feedback {
          return 0
        }
      } else {
        match (n1_source_port, n2_source_port) {
          (Some(p1), Some(p2)) =>
            for port in n1_ref.ports {
              if port.id == p1.id {
                sli_update_node_order(state, n2, n1)
                return -1
              } else if port.id == p2.id {
                sli_update_node_order(state, n1, n2)
                return 1
              }
            }
          _ => ()
        }
      }
    }
    return sli_compare_nodes(
      ctx, state, n1_ref, n2_ref, previous_layer, before_ports,
    )
  }
  0
}

///|
fn sli_compare_nodes(
  ctx : SliContext,
  state : SliNodeOrderState,
  n1 : LNode,
  n2 : LNode,
  previous_layer : Array[LNode],
  before_ports : Bool,
) -> Int {
  let graph = ctx.graph
  let strategy = ctx.strategy
  let incoming_by_port = ctx.incoming_by_port
  let node_bigger_than = state.node_bigger_than
  let node_smaller_than = state.node_smaller_than
  if sli_node_set_has(node_bigger_than, n1.id, n2.id) {
    return 1
  }
  if sli_node_set_has(node_bigger_than, n2.id, n1.id) {
    return -1
  }
  if sli_node_set_has(node_smaller_than, n1.id, n2.id) {
    return -1
  }
  if sli_node_set_has(node_smaller_than, n2.id, n1.id) {
    return 1
  }
  let use_edge_order = strategy == PreferEdges ||
    sli_node_model_order(n1) is None ||
    sli_node_model_order(n2) is None
  if use_edge_order {
    let prev_layer = if n1.layer > 0 { n1.layer - 1 } else { 0 }
    let (src1, src_port1, _) = sli_first_incoming_from_prev(
      graph, n1, prev_layer, incoming_by_port,
    )
    let (src2, src_port2, _) = sli_first_incoming_from_prev(
      graph, n2, prev_layer, incoming_by_port,
    )
    if src1 is Some(_) && src2 is Some(_) {
      let s1 = src1.unwrap()
      let s2 = src2.unwrap()
      if s1.id == s2.id {
        if src_port1 is Some(_) && src_port2 is Some(_) {
          let p1 = src_port1.unwrap()
          let p2 = src_port2.unwrap()
          for port in s1.ports {
            if port.id == p1.id {
              sli_update_node_order(state, n2, n1)
              return -1
            } else if port.id == p2.id {
              sli_update_node_order(state, n1, n2)
              return 1
            }
          }
        }
        let order1 = sli_model_order_from_connected_edges(n1, incoming_by_port)
        let order2 = sli_model_order_from_connected_edges(n2, incoming_by_port)
        if order1 > order2 {
          sli_update_node_order(state, n1, n2)
          return 1
        } else {
          sli_update_node_order(state, n2, n1)
          return -1
        }
      }
      for prev in previous_layer {
        if prev.id == s1.id {
          sli_update_node_order(state, n2, n1)
          return -1
        } else if prev.id == s2.id {
          sli_update_node_order(state, n1, n2)
          return 1
        }
      }
    }
    if (src_port1 is Some(_) && src_port2 is None) ||
      (src_port1 is None && src_port2 is Some(_)) {
      let cmp = sli_handle_helper_dummy_nodes(
        ctx, state, n1, n2, previous_layer, before_ports,
      )
      if cmp != 0 {
        if cmp > 0 {
          sli_update_node_order(state, n1, n2)
        } else {
          sli_update_node_order(state, n2, n1)
        }
        return cmp
      }
      if sli_node_model_order(n1) is None || sli_node_model_order(n2) is None {
        let order1 = sli_model_order_from_connected_edges(n1, incoming_by_port)
        let order2 = sli_model_order_from_connected_edges(n2, incoming_by_port)
        if order1 > order2 {
          sli_update_node_order(state, n1, n2)
          return 1
        } else {
          sli_update_node_order(state, n2, n1)
          return -1
        }
      }
    }
    if src_port1 is None && src_port2 is None {
      let cmp = sli_handle_helper_dummy_nodes(
        ctx, state, n1, n2, previous_layer, before_ports,
      )
      if cmp != 0 {
        if cmp > 0 {
          sli_update_node_order(state, n1, n2)
        } else {
          sli_update_node_order(state, n2, n1)
        }
        return cmp
      }
    }
  }
  match (sli_node_model_order(n1), sli_node_model_order(n2)) {
    (Some(m1), Some(m2)) =>
      if m1 > m2 {
        sli_update_node_order(state, n1, n2)
        1
      } else {
        sli_update_node_order(state, n2, n1)
        -1
      }
    _ => {
      sli_update_node_order(state, n2, n1)
      -1
    }
  }
}

///|
fn sli_insertion_sort_nodes(
  ctx : SliContext,
  nodes : Array[LNode],
  previous_layer : Array[LNode],
  before_ports : Bool,
) -> Unit {
  let state = SliNodeOrderState::new()
  for i = 1; i < nodes.length(); i = i + 1 {
    let temp = nodes[i]
    let mut j = i
    while j > 0 &&
          sli_compare_nodes(
            ctx,
            state,
            nodes[j - 1],
            temp,
            previous_layer,
            before_ports,
          ) >
          0 {
      nodes[j] = nodes[j - 1]
      j = j - 1
    }
    nodes[j] = temp
  }
}

///|
fn sli_insertion_sort_ports(
  ctx : SliContext,
  ports : Array[LPort],
  owner : LNode,
  previous_layer : Array[LNode],
  target_node_model_order : Map[String, Int],
  port_model_order_enabled : Bool,
) -> Unit {
  let state = SliPortOrderState::new()
  for i = 1; i < ports.length(); i = i + 1 {
    let temp = ports[i]
    let mut j = i
    while j > 0 &&
          sli_compare_ports(
            ctx,
            state,
            owner,
            ports[j - 1],
            temp,
            previous_layer,
            Some(target_node_model_order),
            port_model_order_enabled,
          ) >
          0 {
      ports[j] = ports[j - 1]
      j = j - 1
    }
    ports[j] = temp
  }
}

///|
fn sort_layers_by_input_order(
  graph : LGraph,
  options : LayoutOptions,
  _direction : LayoutDirection,
) -> Unit {
  let strategy = options.consider_model_order_strategy.unwrap_or(None)
  if strategy is None {
    return
  }
  let port_model_order_enabled = sli_port_model_order_enabled(graph)
  let incoming_by_port : Map[String, Array[LEdge]] = {}
  let outgoing_by_port : Map[String, Array[LEdge]] = {}
  for edge in graph.edges {
    match edge.source_port_id {
      Some(pid) => {
        let arr = outgoing_by_port.get(pid).unwrap_or([])
        arr.push(edge)
        outgoing_by_port[pid] = arr
      }
      None => ()
    }
    match edge.target_port_id {
      Some(pid) => {
        let arr = incoming_by_port.get(pid).unwrap_or([])
        arr.push(edge)
        incoming_by_port[pid] = arr
      }
      None => ()
    }
  }
  let ctx = SliContext::new(graph, strategy, incoming_by_port, outgoing_by_port)
  for li = 0; li < graph.layers.length(); li = li + 1 {
    let layer = graph.layers[li]
    let previous_layer = if li == 0 {
      graph.layers[0].nodes
    } else {
      graph.layers[li - 1].nodes
    }
    sli_insertion_sort_nodes(ctx, layer.nodes, previous_layer, true)
    for i, node in layer.nodes {
      node.position = i
    }
    for node in layer.nodes {
      if node.ports.is_empty() {
        continue
      }
      let node_options = resolve_options_for_lnode(options, node)
      match node_options.port_constraints {
        Some(FixedOrder) | Some(FixedPos) => ()
        _ => {
          let target_node_model_order = sli_long_edge_target_node_preprocessing(
            graph, node, outgoing_by_port,
          )
          sli_insertion_sort_ports(
            ctx,
            node.ports,
            node,
            previous_layer,
            target_node_model_order,
            port_model_order_enabled,
          )
        }
      }
      for i, port in node.ports {
        port.properties.set("diago.layered.portIndex", Int(i))
      }
    }
    sli_insertion_sort_nodes(ctx, layer.nodes, previous_layer, false)
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
  // ELK uses `edgeLabels.placement` (plural) on labels; keep the older
  // `edgeLabel.placement` (singular) for compatibility with existing tests.
  match label.properties.get_string("elk.edgeLabels.placement") {
    Some(s) => parse_edge_label_placement(s)
    None =>
      match
        label.properties.get_string("org.eclipse.elk.edgeLabels.placement") {
        Some(s) => parse_edge_label_placement(s)
        None =>
          match label.properties.get_string("elk.edgeLabel.placement") {
            Some(s) => parse_edge_label_placement(s)
            None =>
              match
                label.properties.get_string(
                  "org.eclipse.elk.edgeLabel.placement",
                ) {
                Some(s) => parse_edge_label_placement(s)
                None =>
                  match
                    label.properties.get_string(
                      "diago.layered.edgeLabelPlacement",
                    ) {
                    Some(s) => parse_edge_label_placement(s)
                    None => None
                  }
              }
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
              let border = port.properties.get_double_or(
                "diago.layered.portBorderOffset", 0.0,
              )
              match port.side {
                North =>
                  if has_pos {
                    ElkPoint::new(node.x + port.x, node.y + border)
                  } else {
                    ElkPoint::new(node.x + node.width / 2.0, node.y + border)
                  }
                South =>
                  if has_pos {
                    ElkPoint::new(
                      node.x + port.x,
                      node.y + node.height - border,
                    )
                  } else {
                    ElkPoint::new(
                      node.x + node.width / 2.0,
                      node.y + node.height - border,
                    )
                  }
                West =>
                  if has_pos {
                    ElkPoint::new(node.x + border, node.y + port.y)
                  } else {
                    ElkPoint::new(node.x + border, node.y + node.height / 2.0)
                  }
                East =>
                  if has_pos {
                    ElkPoint::new(node.x + node.width - border, node.y + port.y)
                  } else {
                    ElkPoint::new(
                      node.x + node.width - border,
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
  let edge_label_spacing = options.edge_label_spacing.unwrap_or(2.0)
  let label_label_spacing = options.label_label_spacing.unwrap_or(0.0)
  let label_node_spacing = options.label_node_spacing.unwrap_or(5.0)
  let label_port_horizontal_spacing = options.label_port_horizontal_spacing.unwrap_or(
    1.0,
  )
  let label_port_vertical_spacing = options.label_port_vertical_spacing.unwrap_or(
    1.0,
  )
  let perp_x = edge_label_spacing + label_port_horizontal_spacing
  let perp_y = edge_label_spacing + label_port_vertical_spacing
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
      let total_h = stack_total(head_labels, label_label_spacing)
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
          lx = lx + side_sign * perp_x
          ly = ly + along * label_node_spacing + cursor
        } else {
          lx = lx + along * label_node_spacing + cursor
          ly = ly + side_sign * perp_y
        }
        label.x = lx - label.width / 2.0
        label.y = ly
        cursor = cursor + label.height + label_label_spacing
      }
    }
    if !tail_labels.is_empty() {
      let anchor = edge_anchor_point(graph, edge, direction, false)
      let total_h = stack_total(tail_labels, label_label_spacing)
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
          lx = lx + side_sign * perp_x
          ly = ly - along * label_node_spacing + cursor
        } else {
          lx = lx - along * label_node_spacing + cursor
          ly = ly + side_sign * perp_y
        }
        label.x = lx - label.width / 2.0
        label.y = ly
        cursor = cursor + label.height + label_label_spacing
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
  options : LayoutOptions,
  strategy : CrossingMinimizationStrategy,
  thoroughness : Int,
) -> Unit {
  match strategy {
    LayerSweep => layer_sweep_crossing_min(graph, options, thoroughness)
    InteractiveCrossMin | None => () // No minimization
  }
}

///|
/// Sweep port distributors (partial ELK port)
///
/// ELK adjusts port order during layer sweep to reduce crossings.
fn distribute_ports_node_relative(
  graph : LGraph,
  layer : LLayer,
  fixed_layer : LLayer,
  forward : Bool,
  options : LayoutOptions,
) -> Unit {
  fn resolve_options_for_lnode(
    inherited : LayoutOptions,
    node : LNode,
  ) -> LayoutOptions {
    LayoutOptions::merge(
      inherited,
      LayoutOptions::from_properties(node.properties),
    )
  }

  fn allow_reorder(node_options : LayoutOptions) -> Bool {
    match node_options.port_constraints {
      Some(FixedOrder) | Some(FixedPos) => false
      _ => true
    }
  }

  fn port_side_order(side : ElkPortSide) -> Int {
    match side {
      North => 0
      East => 1
      South => 2
      West => 3
      Undefined => 4
    }
  }

  for node in layer.nodes {
    let node_options = resolve_options_for_lnode(options, node)
    if !allow_reorder(node_options) {
      continue
    }

    // Compute barycenters per port based on adjacent-layer node positions.
    let sum_by_port : Map[String, Int] = {}
    let cnt_by_port : Map[String, Int] = {}
    if forward {
      for edge in node.incoming_edges {
        match graph.get_node(edge.source_id) {
          Some(src) =>
            if src.layer == fixed_layer.index {
              match edge.target_port_id {
                Some(pid) => {
                  sum_by_port[pid] = sum_by_port.get(pid).unwrap_or(0) +
                    src.position
                  cnt_by_port[pid] = cnt_by_port.get(pid).unwrap_or(0) + 1
                }
                None => ()
              }
            }
          None => ()
        }
      }
    } else {
      for edge in node.outgoing_edges {
        match graph.get_node(edge.target_id) {
          Some(tgt) =>
            if tgt.layer == fixed_layer.index {
              match edge.source_port_id {
                Some(pid) => {
                  sum_by_port[pid] = sum_by_port.get(pid).unwrap_or(0) +
                    tgt.position
                  cnt_by_port[pid] = cnt_by_port.get(pid).unwrap_or(0) + 1
                }
                None => ()
              }
            }
          None => ()
        }
      }
    }
    if sum_by_port.is_empty() {
      continue
    }
    let orig_index : Map[String, Int] = {}
    for i, p in node.ports {
      orig_index[p.id] = i
    }
    let port_ids : Array[String] = []
    for pid, _ in sum_by_port {
      port_ids.push(pid)
    }
    port_ids.sort_by(fn(a, b) {
      let sa = sum_by_port.get(a).unwrap_or(0).to_double() /
        cnt_by_port.get(a).unwrap_or(1).to_double()
      let sb = sum_by_port.get(b).unwrap_or(0).to_double() /
        cnt_by_port.get(b).unwrap_or(1).to_double()
      if sa < sb {
        -1
      } else if sa > sb {
        1
      } else {
        orig_index.get(a).unwrap_or(0) - orig_index.get(b).unwrap_or(0)
      }
    })
    let rank_by_port : Map[String, Int] = {}
    for i, pid in port_ids {
      rank_by_port[pid] = i
    }

    // Sort ports by side, then by port rank if affected.
    node.ports.sort_by(fn(a, b) {
      let sa = port_side_order(a.side)
      let sb = port_side_order(b.side)
      if sa != sb {
        return sa - sb
      }
      let oa = orig_index.get(a.id).unwrap_or(0)
      let ob = orig_index.get(b.id).unwrap_or(0)
      let ka = match rank_by_port.get(a.id) {
        Some(r) => r
        None => 10_000 + oa
      }
      let kb = match rank_by_port.get(b.id) {
        Some(r) => r
        None => 10_000 + ob
      }
      if ka != kb {
        ka - kb
      } else {
        oa - ob
      }
    })
  }
}

///|
/// Layer sweep barycenter ordering
///
/// Runs multiple sweeps and keeps the best (lowest crossings) intermediate
/// ordering. Greedy switching is intentionally not run here.
fn layer_sweep_barycenter_best(
  graph : LGraph,
  options : LayoutOptions,
  thoroughness : Int,
) -> Unit {
  if graph.layers.length() <= 1 || thoroughness <= 0 {
    return
  }
  fn total_crossings() -> Int {
    let mut total = 0
    for i = 0; i < graph.layers.length() - 1; i = i + 1 {
      total = total +
        count_crossings_between_layers(graph.layers[i], graph.layers[i + 1])
    }
    total
  }

  fn snapshot_positions() -> (
    Array[Map[String, Int]],
    Map[String, Array[String]],
  ) {
    let layer_snapshot : Array[Map[String, Int]] = []
    for layer in graph.layers {
      let m : Map[String, Int] = {}
      for i, node in layer.nodes {
        m[node.id] = i
      }
      layer_snapshot.push(m)
    }
    let port_snapshot : Map[String, Array[String]] = {}
    for node in graph.nodes {
      let ids : Array[String] = []
      for p in node.ports {
        ids.push(p.id)
      }
      port_snapshot[node.id] = ids
    }
    (layer_snapshot, port_snapshot)
  }

  fn restore_positions(
    snapshot : (Array[Map[String, Int]], Map[String, Array[String]]),
  ) -> Unit {
    let (layer_snapshot, port_snapshot) = snapshot
    for li = 0; li < graph.layers.length(); li = li + 1 {
      let layer = graph.layers[li]
      let m = layer_snapshot[li]
      for node in layer.nodes {
        match m.get(node.id) {
          Some(pos) => node.position = pos
          None => ()
        }
      }
      layer.nodes.sort_by(fn(a, b) {
        if a.position != b.position {
          a.position - b.position
        } else {
          a.id.compare(b.id)
        }
      })
      for i, node in layer.nodes {
        node.position = i
      }
    }
    for node in graph.nodes {
      match port_snapshot.get(node.id) {
        Some(ids) => {
          let rank : Map[String, Int] = {}
          for i, pid in ids {
            rank[pid] = i
          }
          node.ports.sort_by(fn(a, b) {
            let ra = rank.get(a.id).unwrap_or(1_000_000)
            let rb = rank.get(b.id).unwrap_or(1_000_000)
            if ra != rb {
              ra - rb
            } else {
              a.id.compare(b.id)
            }
          })
        }
        None => ()
      }
    }
  }

  let seed = options.random_seed.unwrap_or(1)
  let use_perturb = options.random_seed is Some(_)
  let is_horizontal = options.direction.unwrap_or(Down).is_horizontal()
  let consider_order = options.consider_model_order_strategy.unwrap_or(None)
  let mut best_crossings = total_crossings()
  let mut best_snapshot = snapshot_positions()
  for sweep = 0; sweep < thoroughness; sweep = sweep + 1 {
    // Forward sweep (top to bottom for Down direction)
    for i = 1; i < graph.layers.length(); i = i + 1 {
      order_layer_by_barycenter(
        graph,
        graph.layers[i],
        graph.layers[i - 1],
        true,
        sweep,
        seed,
        use_perturb,
        options.crossing_min_force_node_model_order.unwrap_or(false),
        consider_order,
        is_horizontal,
      )
      distribute_ports_node_relative(
        graph,
        graph.layers[i],
        graph.layers[i - 1],
        true,
        options,
      )
      let crossings = total_crossings()
      if crossings < best_crossings {
        best_crossings = crossings
        best_snapshot = snapshot_positions()
      }
    }

    // Backward sweep (bottom to top)
    for i = graph.layers.length() - 2; i >= 0; i = i - 1 {
      order_layer_by_barycenter(
        graph,
        graph.layers[i],
        graph.layers[i + 1],
        false,
        sweep,
        seed,
        use_perturb,
        options.crossing_min_force_node_model_order.unwrap_or(false),
        consider_order,
        is_horizontal,
      )
      distribute_ports_node_relative(
        graph,
        graph.layers[i],
        graph.layers[i + 1],
        false,
        options,
      )
      let crossings = total_crossings()
      if crossings < best_crossings {
        best_crossings = crossings
        best_snapshot = snapshot_positions()
      }
    }
  }
  restore_positions(best_snapshot)

  // Update node positions after barycenter ordering
  for layer in graph.layers {
    for i, node in layer.nodes {
      node.position = i
    }
  }
}

///|
/// Layer sweep crossing minimization (barycenter ordering only)
fn layer_sweep_crossing_min(
  graph : LGraph,
  options : LayoutOptions,
  thoroughness : Int,
) -> Unit {
  if graph.layers.length() <= 1 {
    return
  }
  layer_sweep_barycenter_best(graph, options, thoroughness)
}

///|
/// Order nodes in a layer using barycenter heuristic
fn order_layer_by_barycenter(
  graph : LGraph,
  layer : LLayer,
  fixed_layer : LLayer,
  forward : Bool,
  sweep : Int,
  seed : Int,
  use_perturb : Bool,
  force_model_order : Bool,
  consider_model_order : OrderingStrategy,
  is_horizontal : Bool,
) -> Unit {
  // ELK parity notes:
  // - Nodes with no connections get an "unknown" barycenter, then filled in by
  //   taking the midpoint between previous and next defined barycenter.
  // - A small random perturbation is added to increase solution diversity.
  //   We keep determinism by deriving it from `(seed, sweep, node.id)`.

  fn hash_u32(s : String) -> Int {
    let mut h : Int = 216613626
    for i in 0..<s.length() {
      let b = s.code_unit_at(i).to_int()
      h = h ^ b
      h = (h * 16777619) & 0x7fffffff
    }
    h
  }

  fn perturb(
    node_id : String,
    sweep : Int,
    forward : Bool,
    seed : Int,
  ) -> Double {
    // ELK uses RANDOM_AMOUNT=0.07.
    let amount = if use_perturb { 0.07 } else { 0.0 }
    let tag = if forward { "f" } else { "b" }
    let r = hash_u32(
        node_id + ":" + sweep.to_string() + ":" + tag + ":" + seed.to_string(),
      ).to_double() /
      2147483647.0
    (r - 0.5) * amount
  }

  // Compute barycenters.
  let barycenters : Map[String, Double?] = {}
  fn neighbor_position(node : LNode, edge : LEdge, is_source : Bool) -> Double {
    let base = node.position.to_double()
    if !edge.properties.get_bool_or("diago.layered.crossHierarchy", false) {
      return base
    }
    let key = if is_source {
      "diago.layered.originalSourceId"
    } else {
      "diago.layered.originalTargetId"
    }
    let orig_id = edge.properties.get_string(key)
    guard orig_id is Some(child_id) else { return base }
    if child_id == node.id {
      return base
    }
    match node.nested_graph {
      Some(nested) =>
        match nested.get_node(child_id) {
          Some(child) => {
            let centers : Array[(String, Double)] = []
            for other in nested.nodes {
              let c = if is_horizontal {
                other.y + other.height / 2.0
              } else {
                other.x + other.width / 2.0
              }
              centers.push((other.id, c))
            }
            centers.sort_by(fn(a, b) {
              let (_, ca) = a
              let (_, cb) = b
              if ca < cb {
                -1
              } else if ca > cb {
                1
              } else {
                0
              }
            })
            let count = centers.length()
            if count == 0 {
              return base
            }
            let mut idx = 0
            for i = 0; i < count; i = i + 1 {
              let (id, _) = centers[i]
              if id == child.id {
                idx = i
                break
              }
            }
            // Approximate ELK's port-based crossing minimization by using a small
            // fractional offset derived from the child order inside the compound node.
            // This keeps the adjustment within (-0.5, 0.5) so it doesn't dominate
            // node ordering in the outer graph.
            let t = (idx.to_double() + 1.0) / (count.to_double() + 1.0)
            base + (t - 0.5)
          }
          None => base
        }
      None => base
    }
  }

  for node in layer.nodes {
    let connected_positions : Array[Double] = []
    if forward {
      for edge in node.incoming_edges {
        match graph.get_node(edge.source_id) {
          Some(source) =>
            if source.layer == fixed_layer.index {
              connected_positions.push(neighbor_position(source, edge, true))
            }
          None => ()
        }
      }
    } else {
      for edge in node.outgoing_edges {
        match graph.get_node(edge.target_id) {
          Some(target) =>
            if target.layer == fixed_layer.index {
              connected_positions.push(neighbor_position(target, edge, false))
            }
          None => ()
        }
      }
    }
    if connected_positions.length() > 0 {
      let sum = connected_positions.fold(init=0.0, fn(acc, p) { acc + p })
      let base = sum / connected_positions.length().to_double()
      barycenters[node.id] = Some(base + perturb(node.id, sweep, forward, seed))
    } else {
      barycenters[node.id] = None
    }
  }

  // Fill unknown barycenters (ELK: preOrdered=true behavior).
  let mut last_value = -1.0
  for i = 0; i < layer.nodes.length(); i = i + 1 {
    let node = layer.nodes[i]
    match barycenters.get(node.id).unwrap_or(None) {
      Some(v) => last_value = v
      None => {
        let mut next_value = last_value + 1.0
        for j = i + 1; j < layer.nodes.length(); j = j + 1 {
          let nxt = layer.nodes[j]
          match barycenters.get(nxt.id).unwrap_or(None) {
            Some(v) => {
              next_value = v
              break
            }
            None => ()
          }
        }
        let v = (last_value + next_value) / 2.0
        barycenters[node.id] = Some(v)
        last_value = v
      }
    }
  }
  fn model_order(node : LNode) -> Int? {
    if node.node_type is Normal {
      match node.properties.get_int("diago.layered.modelOrder") {
        Some(v) => Some(v)
        None => None
      }
    } else {
      None
    }
  }

  let preserve_model_order = match consider_model_order {
    None => false
    _ => true
  }
  if preserve_model_order {
    let bigger_than : Map[String, Map[String, Bool]] = {}
    let smaller_than : Map[String, Map[String, Bool]] = {}
    fn set_has(
      sets : Map[String, Map[String, Bool]],
      key : String,
      value : String,
    ) -> Bool {
      match sets.get(key) {
        Some(set) => set.get(value).unwrap_or(false)
        None => false
      }
    }

    fn set_add(
      sets : Map[String, Map[String, Bool]],
      key : String,
      value : String,
    ) -> Unit {
      let set = sets.get(key).unwrap_or({})
      set[value] = true
      sets[key] = set
    }

    fn set_add_all(
      sets : Map[String, Map[String, Bool]],
      key : String,
      other : Map[String, Bool],
    ) -> Unit {
      let set = sets.get(key).unwrap_or({})
      for k, v in other {
        if v {
          set[k] = true
        }
      }
      sets[key] = set
    }

    fn update_transitive(bigger : LNode, smaller : LNode) -> Unit {
      set_add(bigger_than, bigger.id, smaller.id)
      set_add(smaller_than, smaller.id, bigger.id)
      let smaller_bigger = bigger_than.get(smaller.id).unwrap_or({})
      let bigger_smaller = smaller_than.get(bigger.id).unwrap_or({})
      for very_small, flag in smaller_bigger {
        if flag {
          set_add(bigger_than, bigger.id, very_small)
          set_add(smaller_than, very_small, bigger.id)
          set_add_all(smaller_than, very_small, bigger_smaller)
        }
      }
      for very_big, flag in bigger_smaller {
        if flag {
          set_add(smaller_than, smaller.id, very_big)
          set_add(bigger_than, very_big, smaller.id)
          set_add_all(bigger_than, very_big, smaller_bigger)
        }
      }
    }

    fn compare_transitive(n1 : LNode, n2 : LNode) -> Int {
      if set_has(bigger_than, n1.id, n2.id) {
        return 1
      }
      if set_has(bigger_than, n2.id, n1.id) {
        return -1
      }
      if set_has(smaller_than, n1.id, n2.id) {
        return -1
      }
      if set_has(smaller_than, n2.id, n1.id) {
        return 1
      }
      0
    }

    fn barycenter_value(
      barycenters : Map[String, Double?],
      node : LNode,
    ) -> Double? {
      barycenters.get(node.id).unwrap_or(None)
    }

    fn compare_barycenter(
      barycenters : Map[String, Double?],
      n1 : LNode,
      n2 : LNode,
    ) -> Int {
      let b1 = barycenter_value(barycenters, n1)
      let b2 = barycenter_value(barycenters, n2)
      match (b1, b2) {
        (Some(v1), Some(v2)) =>
          if v1 < v2 {
            update_transitive(n1, n2)
            -1
          } else if v1 > v2 {
            update_transitive(n2, n1)
            1
          } else {
            0
          }
        (Some(_), None) => {
          update_transitive(n1, n2)
          -1
        }
        (None, Some(_)) => {
          update_transitive(n2, n1)
          1
        }
        (None, None) => 0
      }
    }

    fn compare_nodes_with_model_order(
      barycenters : Map[String, Double?],
      n1 : LNode,
      n2 : LNode,
    ) -> Int {
      let transitive = compare_transitive(n1, n2)
      if transitive != 0 {
        return transitive
      }
      match (model_order(n1), model_order(n2)) {
        (Some(m1), Some(m2)) =>
          if m1 < m2 {
            update_transitive(n1, n2)
            -1
          } else if m1 > m2 {
            update_transitive(n2, n1)
            1
          } else {
            0
          }
        _ => compare_barycenter(barycenters, n1, n2)
      }
    }

    for i = 1; i < layer.nodes.length(); i = i + 1 {
      let temp = layer.nodes[i]
      let mut j = i
      while j > 0 &&
            compare_nodes_with_model_order(
              barycenters,
              layer.nodes[j - 1],
              temp,
            ) >
            0 {
        layer.nodes[j] = layer.nodes[j - 1]
        j = j - 1
      }
      layer.nodes[j] = temp
    }
  } else {
    // Sort by barycenter; optionally prevent normal nodes from reordering.
    layer.nodes.sort_by(fn(a, b) {
      if force_model_order {
        match (a.node_type, b.node_type) {
          (Normal, Normal) =>
            match (model_order(a), model_order(b)) {
              (Some(ma), Some(mb)) => if ma != mb { return ma - mb }
              _ => ()
            }
          _ => ()
        }
      }
      let bc_a = barycenters.get(a.id).unwrap_or(Some(0.0)).unwrap_or(0.0)
      let bc_b = barycenters.get(b.id).unwrap_or(Some(0.0)).unwrap_or(0.0)
      if bc_a < bc_b {
        -1
      } else if bc_a > bc_b {
        1
      } else {
        // Barycenter tie-break: if requested, use initial model order.
        match consider_model_order {
          NodesAndEdges | PreferEdges | PreferNodes =>
            match (a.node_type, b.node_type) {
              (Normal, Normal) =>
                match (model_order(a), model_order(b)) {
                  (Some(ma), Some(mb)) => if ma != mb { return ma - mb }
                  _ => ()
                }
              _ => ()
            }
          None => ()
        }
        if a.position != b.position {
          a.position - b.position
        } else {
          a.id.compare(b.id)
        }
      }
    })
  }
  for i, node in layer.nodes {
    node.position = i
  }
}

// ============================================================================
// Phase 4: Node Placement
// ============================================================================

///|
fn effective_graph_padding(
  _graph : LGraph,
  options : LayoutOptions,
) -> ElkPadding {
  let padding = options.padding.unwrap_or(ElkPadding::uniform(12.0))
  padding
}

///|
/// Place nodes with final x,y coordinates
fn place_nodes(
  graph : LGraph,
  options : LayoutOptions,
  strategy : NodePlacementStrategy,
  direction : LayoutDirection,
) -> Unit {
  if graph.edges.is_empty() {
    simple_node_placement(graph, options, direction)
    return
  }
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
  let padding = effective_graph_padding(graph, options)

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
  options : LayoutOptions,
  routing : EdgeRouting,
  direction : LayoutDirection,
) -> Unit {
  match routing {
    Orthogonal => orthogonal_routing(graph, options, direction)
    Polyline => polyline_routing(graph, direction)
    Splines => spline_routing(graph, direction)
    Undefined => orthogonal_routing(graph, options, direction)
  }
}

///|
/// Orthogonal edge routing - strict 90-degree turns with slot assignment
fn orthogonal_routing(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
) -> Unit {
  // For vertical layouts, this controls the minimum spacing between *layers*.
  // (The within-layer spacing is handled by the node placement phase.)
  let node_node_spacing = options.node_node_between_layers_spacing.unwrap_or(
    20.0,
  )
  let edge_edge_spacing = options.edge_edge_between_layers_spacing.unwrap_or(
    10.0,
  )
  let edge_node_spacing = options.edge_node_between_layers_spacing.unwrap_or(
    10.0,
  )
  let padding = effective_graph_padding(graph, options)

  // Use improved routing with slot assignment
  let random_seed = options.random_seed.unwrap_or(1)
  route_edges_orthogonal(
    graph, direction, node_node_spacing, edge_edge_spacing, edge_node_spacing, padding,
    random_seed,
  )

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
