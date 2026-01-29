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
/// Brandes-Koepf Node Placement Algorithm
///
/// This algorithm assigns y-coordinates to nodes to minimize edge bends
/// while respecting layer structure. It uses a four-direction approach:
/// (UP/DOWN) x (LEFT/RIGHT), then selects the best result.
///
/// Based on "Fast and Simple Horizontal Coordinate Assignment" (2002)
/// with ELK's extensions (ports, block shifts, compaction classes).

// ============================================================================
// Block and Root Structures
// ============================================================================

///|
/// Direction for vertical alignment
enum VDirection {
  Up
  Down
} derive(Show, Eq)

///|
/// Direction for horizontal alignment
enum HDirection {
  Left
  Right
} derive(Show, Eq)

///|
priv struct NeighborRef {
  node_id : String
  edge_id : String
}

///|
priv struct NeighborInfo {
  node_index : Map[String, Int]
  left_neighbors : Map[String, Array[NeighborRef]]
  right_neighbors : Map[String, Array[NeighborRef]]
}

///|
priv struct ClassEdge {
  target_id : String
  separation : Double
}

///|
#warnings("-unused_field")
priv struct ClassNode {
  node_id : String
  mut class_shift : Double?
  mut indegree : Int
  outgoing : Array[ClassEdge]
}

///|
priv struct BKLayout {
  vdir : VDirection
  hdir : HDirection
  root : Map[String, String]
  align : Map[String, String]
  align_edge : Map[String, String]
  inner_shift : Map[String, Double]
  block_size : Map[String, Double]
  sink : Map[String, String]
  shift : Map[String, Double]
  y : Map[String, Double?]
  od : Map[String, Bool]
  su : Map[String, Bool]
}

///|
fn node_size_cross(node : LNode, is_horizontal : Bool) -> Double {
  if is_horizontal {
    node.height
  } else {
    node.width
  }
}

///|
fn resolve_spacings(options : LayoutOptions) -> SpacingOptions {
  let defaults = SpacingOptions::default()
  {
    ..defaults,
    node_node: options.node_node_spacing.unwrap_or(defaults.node_node),
    node_node_between_layers: options.node_node_between_layers_spacing.unwrap_or(
      defaults.node_node_between_layers,
    ),
    edge_node: options.edge_node_spacing.unwrap_or(defaults.edge_node),
    edge_node_between_layers: options.edge_node_between_layers_spacing.unwrap_or(
      defaults.edge_node_between_layers,
    ),
    edge_edge: options.edge_edge_spacing.unwrap_or(defaults.edge_edge),
    edge_edge_between_layers: options.edge_edge_between_layers_spacing.unwrap_or(
      defaults.edge_edge_between_layers,
    ),
    edge_label: options.edge_label_spacing.unwrap_or(defaults.edge_label),
    label_node: options.label_node_spacing.unwrap_or(defaults.label_node),
    label_port_horizontal: options.label_port_horizontal_spacing.unwrap_or(
      defaults.label_port_horizontal,
    ),
    label_port_vertical: options.label_port_vertical_spacing.unwrap_or(
      defaults.label_port_vertical,
    ),
    label_label: options.label_label_spacing.unwrap_or(defaults.label_label),
    port_port: options.port_port_spacing.unwrap_or(defaults.port_port),
    component_component: options.component_component_spacing.unwrap_or(
      defaults.component_component,
    ),
  }
}

///|
fn spacing_for_types(
  spacings : SpacingOptions,
  a : LNodeType,
  b : LNodeType,
) -> Double {
  match (a, b) {
    (Normal, Normal) => spacings.node_node
    (Normal, LongEdgeDummy) | (LongEdgeDummy, Normal) => spacings.edge_node
    (Normal, NorthSouthPort) | (NorthSouthPort, Normal) => spacings.edge_node
    (Normal, ExternalPort) | (ExternalPort, Normal) => spacings.edge_node
    (Normal, LabelDummy) | (LabelDummy, Normal) => spacings.node_node
    (LongEdgeDummy, LongEdgeDummy) => spacings.edge_edge
    (LongEdgeDummy, NorthSouthPort) | (NorthSouthPort, LongEdgeDummy) =>
      spacings.edge_edge
    (LongEdgeDummy, ExternalPort) | (ExternalPort, LongEdgeDummy) =>
      spacings.edge_edge
    (LongEdgeDummy, LabelDummy) | (LabelDummy, LongEdgeDummy) =>
      spacings.edge_node
    (NorthSouthPort, NorthSouthPort) => spacings.edge_edge
    (NorthSouthPort, ExternalPort) | (ExternalPort, NorthSouthPort) =>
      spacings.edge_edge
    (NorthSouthPort, LabelDummy) | (LabelDummy, NorthSouthPort) =>
      spacings.label_node
    (ExternalPort, ExternalPort) => spacings.port_port
    (ExternalPort, LabelDummy) | (LabelDummy, ExternalPort) =>
      spacings.label_port_vertical
    (LabelDummy, LabelDummy) => spacings.edge_edge
    (BreakPoint, BreakPoint) => spacings.edge_edge
    (BreakPoint, Normal) | (Normal, BreakPoint) => spacings.edge_node
    (BreakPoint, LabelDummy) | (LabelDummy, BreakPoint) => spacings.edge_node
    (BreakPoint, LongEdgeDummy) | (LongEdgeDummy, BreakPoint) =>
      spacings.edge_node
    _ => spacings.node_node
  }
}

///|
fn vertical_spacing(spacings : SpacingOptions, a : LNode, b : LNode) -> Double {
  spacing_for_types(spacings, a.node_type, b.node_type)
}

///|
fn port_cross(node : LNode, port_id : String?, is_horizontal : Bool) -> Double {
  match port_id {
    Some(pid) => {
      for port in node.ports {
        if port.id == pid {
          let has_size = port.width > 0.0 || port.height > 0.0
          if has_size {
            return if is_horizontal {
              port.y + port.height / 2.0
            } else {
              port.x + port.width / 2.0
            }
          }
          // Infer missing coordinates from port side. This matches ELK behavior
          // for FIXED_POS ports where the DSL often sets only one component
          // (e.g. SQL table ports specify only `y`).
          if is_horizontal {
            // LEFT/RIGHT layout: cross axis is Y.
            if port.y != 0.0 {
              return port.y
            }
            return match port.side {
              North => 0.0
              South => node.height
              _ => node.height / 2.0
            }
          }
          // UP/DOWN layout: cross axis is X.
          return match port.side {
            West => 0.0
            East => node.width
            _ => if port.x != 0.0 { port.x } else { node.width / 2.0 }
          }
        }
      }
      if is_horizontal {
        node.height / 2.0
      } else {
        node.width / 2.0
      }
    }
    None => if is_horizontal { node.height / 2.0 } else { node.width / 2.0 }
  }
}

///|
fn edge_priority(edge : LEdge) -> Int {
  edge.priority
}

///|
fn is_in_layer_edge(graph : LGraph, edge : LEdge) -> Bool {
  let source = graph.get_node(edge.source_id)
  let target = graph.get_node(edge.target_id)
  match (source, target) {
    (Some(src), Some(tgt)) => src.layer == tgt.layer
    _ => false
  }
}

///|
fn build_neighbor_info(graph : LGraph) -> NeighborInfo {
  let node_index : Map[String, Int] = {}
  for layer in graph.layers {
    for i, node in layer.nodes {
      node_index[node.id] = i
    }
  }
  // ELK's neighborhood sorting is stable. MoonBit's `sort_by` is not
  // guaranteed to be stable, so we add an explicit tie-breaker by model order
  // to keep parallel edges deterministic and D2-aligned.
  let edge_order : Map[String, Int] = {}
  for edge in graph.edges {
    edge_order[edge.id] = edge.properties
      .get_int("diago.layered.modelOrder")
      .unwrap_or(0)
  }
  let left_neighbors : Map[String, Array[NeighborRef]] = {}
  let right_neighbors : Map[String, Array[NeighborRef]] = {}
  for layer in graph.layers {
    for node in layer.nodes {
      // Left neighbors (incoming)
      let mut max_prio = -0x7fffffff
      let incoming : Array[NeighborRef] = []
      for edge in node.incoming_edges {
        if edge.is_self_loop() || is_in_layer_edge(graph, edge) {
          continue
        }
        let prio = edge_priority(edge)
        if prio > max_prio {
          max_prio = prio
          incoming.clear()
        }
        if prio == max_prio {
          incoming.push({ node_id: edge.source_id, edge_id: edge.id })
        }
      }
      incoming.sort_by(fn(a, b) {
        let ai = node_index.get(a.node_id).unwrap_or(0)
        let bi = node_index.get(b.node_id).unwrap_or(0)
        if ai != bi {
          ai - bi
        } else {
          edge_order.get(a.edge_id).unwrap_or(0) -
          edge_order.get(b.edge_id).unwrap_or(0)
        }
      })
      left_neighbors[node.id] = incoming

      // Right neighbors (outgoing)
      max_prio = -0x7fffffff
      let outgoing : Array[NeighborRef] = []
      for edge in node.outgoing_edges {
        if edge.is_self_loop() || is_in_layer_edge(graph, edge) {
          continue
        }
        let prio = edge_priority(edge)
        if prio > max_prio {
          max_prio = prio
          outgoing.clear()
        }
        if prio == max_prio {
          outgoing.push({ node_id: edge.target_id, edge_id: edge.id })
        }
      }
      outgoing.sort_by(fn(a, b) {
        let ai = node_index.get(a.node_id).unwrap_or(0)
        let bi = node_index.get(b.node_id).unwrap_or(0)
        if ai != bi {
          ai - bi
        } else {
          edge_order.get(a.edge_id).unwrap_or(0) -
          edge_order.get(b.edge_id).unwrap_or(0)
        }
      })
      right_neighbors[node.id] = outgoing
    }
  }
  { node_index, left_neighbors, right_neighbors }
}

///|
fn incident_to_inner_segment(
  graph : LGraph,
  node : LNode,
  layer1 : Int,
  layer2 : Int,
) -> Bool {
  if node.node_type != LongEdgeDummy {
    return false
  }
  for edge in node.incoming_edges {
    let source = graph.get_node(edge.source_id)
    match source {
      Some(src) =>
        if src.node_type == LongEdgeDummy &&
          src.layer == layer2 &&
          node.layer == layer1 {
          return true
        }
      None => ()
    }
  }
  false
}

///|
fn mark_conflicts(graph : LGraph, ni : NeighborInfo) -> Map[String, Bool] {
  let marked : Map[String, Bool] = {}
  let number_of_layers = graph.layers.length()
  if number_of_layers < 3 {
    return marked
  }
  let layer_sizes : Array[Int] = []
  for layer in graph.layers {
    layer_sizes.push(layer.nodes.length())
  }
  for i = 1; i < number_of_layers - 1; i = i + 1 {
    let current_layer = graph.layers[i + 1]
    let mut k_0 = 0
    let mut l = 0
    for l_1 = 0; l_1 < layer_sizes[i + 1]; l_1 = l_1 + 1 {
      let v_l_i = current_layer.nodes[l_1]
      if l_1 == layer_sizes[i + 1] - 1 ||
        incident_to_inner_segment(graph, v_l_i, i + 1, i) {
        let mut k_1 = layer_sizes[i] - 1
        if incident_to_inner_segment(graph, v_l_i, i + 1, i) {
          match ni.left_neighbors.get(v_l_i.id) {
            Some(neighbors) =>
              if neighbors.length() > 0 {
                let first = neighbors[0]
                k_1 = ni.node_index.get(first.node_id).unwrap_or(k_1)
              }
            None => ()
          }
        }
        while l <= l_1 {
          let v_l = current_layer.nodes[l]
          if !incident_to_inner_segment(graph, v_l, i + 1, i) {
            match ni.left_neighbors.get(v_l.id) {
              Some(neighbors) =>
                for upper in neighbors {
                  let k = ni.node_index.get(upper.node_id).unwrap_or(0)
                  if k < k_0 || k > k_1 {
                    marked[upper.edge_id] = true
                  }
                }
              None => ()
            }
          }
          l = l + 1
        }
        k_0 = k_1
      }
    }
  }
  marked
}

///|
fn init_layout(
  graph : LGraph,
  vdir : VDirection,
  hdir : HDirection,
) -> BKLayout {
  let root : Map[String, String] = {}
  let align : Map[String, String] = {}
  let align_edge : Map[String, String] = {}
  let inner_shift : Map[String, Double] = {}
  let block_size : Map[String, Double] = {}
  let sink : Map[String, String] = {}
  let shift : Map[String, Double] = {}
  let y : Map[String, Double?] = {}
  let od : Map[String, Bool] = {}
  let su : Map[String, Bool] = {}
  for node in graph.nodes {
    root[node.id] = node.id
    align[node.id] = node.id
    inner_shift[node.id] = 0.0
    sink[node.id] = node.id
    shift[node.id] = if vdir == Up {
      @double.neg_infinity
    } else {
      @double.infinity
    }
    y[node.id] = None
    od[node.id] = true
    su[node.id] = false
  }
  {
    vdir,
    hdir,
    root,
    align,
    align_edge,
    inner_shift,
    block_size,
    sink,
    shift,
    y,
    od,
    su,
  }
}

///|
fn vertical_alignment(
  graph : LGraph,
  ni : NeighborInfo,
  marked : Map[String, Bool],
  layout : BKLayout,
) -> Unit {
  let layers : Array[LLayer] = []
  if layout.hdir == Left {
    for i = 0; i < graph.layers.length(); i = i + 1 {
      let idx = graph.layers.length() - 1 - i
      layers.push(graph.layers[idx])
    }
  } else {
    layers.append(graph.layers)
  }
  for layer in layers {
    let mut r = -1
    let nodes : Array[LNode] = []
    if layout.vdir == Up {
      r = 0x7fffffff
      for i = 0; i < layer.nodes.length(); i = i + 1 {
        let idx = layer.nodes.length() - 1 - i
        nodes.push(layer.nodes[idx])
      }
    } else {
      nodes.append(layer.nodes)
    }
    for node in nodes {
      let neighbors = if layout.hdir == Left {
        ni.right_neighbors.get(node.id).unwrap_or([])
      } else {
        ni.left_neighbors.get(node.id).unwrap_or([])
      }
      if neighbors.length() == 0 {
        continue
      }
      let d = neighbors.length()
      let low = (d + 1) / 2 - 1
      let high = (d + 2) / 2 - 1
      let indices : Array[Int] = []
      if layout.vdir == Up {
        for m = high; m >= low; m = m - 1 {
          indices.push(m)
        }
      } else {
        for m = low; m <= high; m = m + 1 {
          indices.push(m)
        }
      }
      for m in indices {
        let median = neighbors[m]
        if layout.align.get(node.id).unwrap_or(node.id) != node.id {
          break
        }
        let median_index = ni.node_index.get(median.node_id).unwrap_or(0)
        let allow = if layout.vdir == Up {
          r > median_index
        } else {
          r < median_index || r < 0
        }
        if !allow {
          continue
        }
        if marked.get(median.edge_id).unwrap_or(false) {
          continue
        }
        let median_root = layout.root
          .get(median.node_id)
          .unwrap_or(median.node_id)
        layout.align[median.node_id] = node.id
        layout.align_edge[median.node_id] = median.edge_id
        layout.root[node.id] = median_root
        layout.align[node.id] = median_root
        let is_dummy = node.node_type == LongEdgeDummy
        let od_root = layout.od.get(median_root).unwrap_or(true)
        layout.od[median_root] = od_root && is_dummy
        r = median_index
      }
    }
  }
}

///|
fn find_edge_between(graph : LGraph, a : String, b : String) -> LEdge? {
  // Mirror ELK's `BKNodePlacer.getEdge`: iterate a node's connected edges in
  // port order and return the first edge connecting to the target node.
  //
  // In ELK, `node.getConnectedEdges()` concatenates `port.getConnectedEdges()`
  // for each port, and `port.getConnectedEdges()` iterates incoming edges first
  // and outgoing edges second (both in insertion order).
  let source = graph.get_node(a)
  guard source is Some(source) else { return None }
  fn edge_order(e : LEdge) -> Int {
    e.properties.get_int("diago.layered.modelOrder").unwrap_or(0)
  }

  fn edges_for_port(
    graph : LGraph,
    node_id : String,
    port_id : String,
    incoming : Bool,
  ) -> Array[LEdge] {
    let edges : Array[LEdge] = []
    for e in graph.edges {
      if incoming {
        if e.target_id == node_id && e.target_port_id == Some(port_id) {
          edges.push(e)
        }
      } else if e.source_id == node_id && e.source_port_id == Some(port_id) {
        edges.push(e)
      }
    }
    edges.sort_by(fn(x, y) {
      let dx = edge_order(x) - edge_order(y)
      if dx != 0 {
        dx
      } else {
        x.id.compare(y.id)
      }
    })
    edges
  }

  for p in source.ports {
    // Incoming edges first
    for e in edges_for_port(graph, a, p.id, true) {
      if e.source_id == b || e.target_id == b {
        return Some(e)
      }
    }
    // Then outgoing edges
    for e in edges_for_port(graph, a, p.id, false) {
      if e.source_id == b || e.target_id == b {
        return Some(e)
      }
    }
  }

  // Fallback: scan in global edge order (should be rare; mainly for nodes
  // without ports or dummies).
  for e in graph.edges {
    if (e.source_id == a && e.target_id == b) ||
      (e.source_id == b && e.target_id == a) {
      return Some(e)
    }
  }
  None
}

///|
fn inside_block_shift(
  graph : LGraph,
  layout : BKLayout,
  is_horizontal : Bool,
) -> Unit {
  let blocks : Map[String, Array[String]] = {}
  for layer in graph.layers {
    for node in layer.nodes {
      let rid = layout.root.get(node.id).unwrap_or(node.id)
      let nodes = blocks.get(rid).unwrap_or([])
      nodes.push(node.id)
      blocks[rid] = nodes
    }
  }
  for pair in blocks.iter() {
    let (root_id, _) = pair
    let root_node = graph.get_node(root_id)
    guard root_node is Some(root_node) else { continue }
    let mut space_above = 0.0
    let mut space_below = node_size_cross(root_node, is_horizontal)
    layout.inner_shift[root_id] = 0.0
    let mut current_id = root_id
    while true {
      let next_id = layout.align.get(current_id).unwrap_or(root_id)
      if next_id == root_id {
        break
      }
      let edge = match layout.align_edge.get(current_id) {
        Some(eid) => get_edge_by_id(graph, eid)
        None => find_edge_between(graph, current_id, next_id)
      }
      match edge {
        Some(edge) => {
          let source = graph.get_node(edge.source_id)
          let target = graph.get_node(edge.target_id)
          guard source is Some(src) && target is Some(tgt) else { () }
          let src_cross = port_cross(src, edge.source_port_id, is_horizontal)
          let tgt_cross = port_cross(tgt, edge.target_port_id, is_horizontal)
          let port_diff = if layout.hdir == Left {
            tgt_cross - src_cross
          } else {
            src_cross - tgt_cross
          }
          let current_shift = layout.inner_shift.get(current_id).unwrap_or(0.0)
          let next_shift = current_shift + port_diff
          layout.inner_shift[next_id] = next_shift
          let next_node = graph.get_node(next_id)
          match next_node {
            Some(nn) => {
              let size = node_size_cross(nn, is_horizontal)
              if -next_shift > space_above {
                space_above = -next_shift
              }
              if next_shift + size > space_below {
                space_below = next_shift + size
              }
            }
            None => ()
          }
        }
        None => ()
      }
      current_id = next_id
    }
    let mut current = root_id
    while true {
      let shift = layout.inner_shift.get(current).unwrap_or(0.0)
      layout.inner_shift[current] = shift + space_above
      let next = layout.align.get(current).unwrap_or(root_id)
      current = next
      if current == root_id {
        break
      }
    }
    layout.block_size[root_id] = space_above + space_below
  }
}

///|
fn get_or_create_class_node(
  class_nodes : Map[String, ClassNode],
  node_id : String,
) -> ClassNode {
  match class_nodes.get(node_id) {
    Some(n) => n
    None => {
      let n = { node_id, class_shift: None, indegree: 0, outgoing: [] }
      class_nodes[node_id] = n
      n
    }
  }
}

///|
fn add_class_edge(
  class_nodes : Map[String, ClassNode],
  from_id : String,
  to_id : String,
  separation : Double,
) -> Unit {
  let from = get_or_create_class_node(class_nodes, from_id)
  let to = get_or_create_class_node(class_nodes, to_id)
  from.outgoing.push({ target_id: to_id, separation })
  to.indegree = to.indegree + 1
  class_nodes[from_id] = from
  class_nodes[to_id] = to
}

///|
fn place_classes(
  class_nodes : Map[String, ClassNode],
  layout : BKLayout,
) -> Unit {
  let queue : Array[String] = []
  for pair in class_nodes.iter() {
    let (id, node) = pair
    if node.indegree == 0 {
      queue.push(id.to_string())
    }
  }
  let mut idx = 0
  while idx < queue.length() {
    let id = queue[idx]
    idx = idx + 1
    let node = class_nodes.get(id).unwrap()
    if node.class_shift is None {
      node.class_shift = Some(0.0)
    }
    let base = node.class_shift.unwrap_or(0.0)
    for edge in node.outgoing {
      let target = class_nodes.get(edge.target_id).unwrap()
      match target.class_shift {
        Some(v) =>
          if layout.vdir == Down {
            if base + edge.separation < v {
              target.class_shift = Some(base + edge.separation)
            }
          } else if base + edge.separation > v {
            target.class_shift = Some(base + edge.separation)
          }
        None => target.class_shift = Some(base + edge.separation)
      }
      target.indegree = target.indegree - 1
      class_nodes[edge.target_id] = target
      if target.indegree == 0 {
        queue.push(edge.target_id)
      }
    }
    class_nodes[id] = node
  }
  for pair in class_nodes.iter() {
    let (id, node) = pair
    match node.class_shift {
      Some(v) => layout.shift[id.to_string()] = v
      None => ()
    }
  }
}

///|
fn get_other_node(edge : LEdge, node_id : String) -> String? {
  if edge.source_id == node_id {
    Some(edge.target_id)
  } else if edge.target_id == node_id {
    Some(edge.source_id)
  } else {
    None
  }
}

///|
fn calculate_delta(
  graph : LGraph,
  layout : BKLayout,
  fix_node_id : String,
  fix_port_id : String?,
  block_node_id : String,
  block_port_id : String?,
  is_horizontal : Bool,
) -> Double {
  let fix_node = graph.get_node(fix_node_id)
  let block_node = graph.get_node(block_node_id)
  guard fix_node is Some(fix_node) && block_node is Some(block_node) else {
    return 0.0
  }
  let fix_y = layout.y.get(fix_node_id).unwrap_or(None).unwrap_or(0.0)
  let block_y = layout.y.get(block_node_id).unwrap_or(None).unwrap_or(0.0)
  let fix_shift = layout.inner_shift.get(fix_node_id).unwrap_or(0.0)
  let block_shift = layout.inner_shift.get(block_node_id).unwrap_or(0.0)
  let fix_pos = fix_y +
    fix_shift +
    port_cross(fix_node, fix_port_id, is_horizontal)
  let block_pos = block_y +
    block_shift +
    port_cross(block_node, block_port_id, is_horizontal)
  block_pos - fix_pos
}

///|
fn shift_block(layout : BKLayout, start_id : String, delta : Double) -> Unit {
  let mut current = start_id
  while true {
    let y = layout.y.get(current).unwrap_or(Some(0.0)).unwrap_or(0.0)
    layout.y[current] = Some(y + delta)
    let next = layout.align.get(current).unwrap_or(start_id)
    current = next
    if current == start_id {
      break
    }
  }
}

///|
fn get_min_pos(graph : LGraph, layout : BKLayout, node_id : String) -> Double {
  match graph.get_node(node_id) {
    Some(_) => ()
    None => return 0.0
  }
  let y = layout.y.get(node_id).unwrap_or(None).unwrap_or(0.0)
  let shift = layout.inner_shift.get(node_id).unwrap_or(0.0)
  y + shift
}

///|
fn get_max_pos(
  graph : LGraph,
  layout : BKLayout,
  node_id : String,
  is_horizontal : Bool,
) -> Double {
  let node = graph.get_node(node_id)
  guard node is Some(node) else { return 0.0 }
  let y = layout.y.get(node_id).unwrap_or(None).unwrap_or(0.0)
  let shift = layout.inner_shift.get(node_id).unwrap_or(0.0)
  let size = node_size_cross(node, is_horizontal)
  y + shift + size
}

///|
fn node_layer_nodes(graph : LGraph, node : LNode) -> Array[LNode] {
  if node.layer >= 0 && node.layer < graph.layers.length() {
    graph.layers[node.layer].nodes
  } else {
    []
  }
}

///|
fn get_upper_neighbor(
  graph : LGraph,
  ni : NeighborInfo,
  node : LNode,
) -> LNode? {
  let idx = ni.node_index.get(node.id).unwrap_or(0)
  let layer = node_layer_nodes(graph, node)
  if idx > 0 && idx - 1 < layer.length() {
    Some(layer[idx - 1])
  } else {
    None
  }
}

///|
fn get_lower_neighbor(
  graph : LGraph,
  ni : NeighborInfo,
  node : LNode,
) -> LNode? {
  let idx = ni.node_index.get(node.id).unwrap_or(0)
  let layer = node_layer_nodes(graph, node)
  if idx < layer.length() - 1 {
    Some(layer[idx + 1])
  } else {
    None
  }
}

///|
fn get_edge_by_id(graph : LGraph, edge_id : String) -> LEdge? {
  for edge in graph.edges {
    if edge.id == edge_id {
      return Some(edge)
    }
  }
  None
}

///|
fn check_space_above(
  graph : LGraph,
  layout : BKLayout,
  ni : NeighborInfo,
  spacings : SpacingOptions,
  start_id : String,
  delta : Double,
  is_horizontal : Bool,
) -> Double {
  let mut available = delta
  let root_id = start_id
  let mut current = root_id
  while true {
    let next = layout.align.get(current).unwrap_or(root_id)
    current = next
    let min_y = get_min_pos(graph, layout, current)
    let node = graph.get_node(current)
    match node {
      Some(n) =>
        match get_upper_neighbor(graph, ni, n) {
          Some(neighbor) => {
            let max_y = get_max_pos(graph, layout, neighbor.id, is_horizontal)
            let spacing = vertical_spacing(spacings, n, neighbor)
            let space = min_y - (max_y + spacing)
            if space < available {
              available = space
            }
          }
          None => ()
        }
      None => ()
    }
    if current == root_id {
      break
    }
  }
  available
}

///|
fn check_space_below(
  graph : LGraph,
  layout : BKLayout,
  ni : NeighborInfo,
  spacings : SpacingOptions,
  start_id : String,
  delta : Double,
  is_horizontal : Bool,
) -> Double {
  let mut available = delta
  let root_id = start_id
  let mut current = root_id
  while true {
    let next = layout.align.get(current).unwrap_or(root_id)
    current = next
    let max_y = get_max_pos(graph, layout, current, is_horizontal)
    let node = graph.get_node(current)
    match node {
      Some(n) =>
        match get_lower_neighbor(graph, ni, n) {
          Some(neighbor) => {
            let min_y = get_min_pos(graph, layout, neighbor.id)
            let spacing = vertical_spacing(spacings, n, neighbor)
            let space = min_y - (max_y + spacing)
            if space < available {
              available = space
            }
          }
          None => ()
        }
      None => ()
    }
    if current == root_id {
      break
    }
  }
  available
}

///|
priv struct Postprocessable {
  free_id : String
  is_root : Bool
  has_edges : Bool
  edge_id : String?
}

///|
fn pick_edge(
  graph : LGraph,
  layout : BKLayout,
  block_finished : Map[String, Bool],
  pp : Postprocessable,
) -> Postprocessable {
  let edges : Array[LEdge] = []
  let node = graph.get_node(pp.free_id)
  guard node is Some(node) else { return pp }
  if pp.is_root {
    if layout.hdir == Right {
      edges.append(node.incoming_edges)
    } else {
      edges.append(node.outgoing_edges)
    }
  } else if layout.hdir == Left {
    edges.append(node.incoming_edges)
  } else {
    edges.append(node.outgoing_edges)
  }
  let mut has_edges = false
  for edge in edges {
    let root_id = layout.root.get(pp.free_id).unwrap_or(pp.free_id)
    let only_dummies = layout.od.get(root_id).unwrap_or(false)
    if !only_dummies && is_in_layer_edge(graph, edge) {
      continue
    }
    let other_id = get_other_node(edge, pp.free_id)
    match other_id {
      Some(oid) => {
        let other_root = layout.root.get(oid).unwrap_or(oid)
        if layout.su.get(root_id).unwrap_or(false) {
          continue
        }
        has_edges = true
        if block_finished.get(other_root).unwrap_or(false) {
          let out = { ..pp, has_edges: true, edge_id: Some(edge.id) }
          return out
        }
      }
      None => ()
    }
  }
  { ..pp, has_edges, edge_id: None }
}

///|
fn get_threshold_bound(
  graph : LGraph,
  layout : BKLayout,
  block_finished : Map[String, Bool],
  pp : Postprocessable,
  queue : Array[Postprocessable],
  is_horizontal : Bool,
) -> (Double, Array[Postprocessable]) {
  let invalid = if layout.vdir == Up {
    @double.infinity
  } else {
    @double.neg_infinity
  }
  let pick = pick_edge(graph, layout, block_finished, pp)
  if pick.edge_id is None && pick.has_edges {
    queue.push(pick)
    return (invalid, queue)
  } else if pick.edge_id is Some(edge_id) {
    let edge = get_edge_by_id(graph, edge_id)
    guard edge is Some(edge) else { return (invalid, queue) }
    let left_id = edge.source_id
    let right_id = edge.target_id
    let left_port = edge.source_port_id
    let right_port = edge.target_port_id
    let mut threshold = invalid
    if pick.is_root {
      let (root_id, root_port, other_id, other_port) = if layout.hdir == Right {
        (right_id, right_port, left_id, left_port)
      } else {
        (left_id, left_port, right_id, right_port)
      }
      let other_root = layout.root.get(other_id).unwrap_or(other_id)
      let other_y = layout.y.get(other_root).unwrap_or(Some(0.0)).unwrap_or(0.0)
      match (graph.get_node(other_id), graph.get_node(root_id)) {
        (Some(other_node), Some(root_node)) =>
          threshold = other_y +
            layout.inner_shift.get(other_id).unwrap_or(0.0) +
            port_cross(other_node, other_port, is_horizontal) -
            layout.inner_shift.get(root_id).unwrap_or(0.0) -
            port_cross(root_node, root_port, is_horizontal)
        _ => threshold = invalid
      }
    } else {
      let (root_id, root_port, other_id, other_port) = if layout.hdir == Left {
        (right_id, right_port, left_id, left_port)
      } else {
        (left_id, left_port, right_id, right_port)
      }
      let other_root = layout.root.get(other_id).unwrap_or(other_id)
      let other_y = layout.y.get(other_root).unwrap_or(Some(0.0)).unwrap_or(0.0)
      match (graph.get_node(other_id), graph.get_node(root_id)) {
        (Some(other_node), Some(root_node)) =>
          threshold = other_y +
            layout.inner_shift.get(other_id).unwrap_or(0.0) +
            port_cross(other_node, other_port, is_horizontal) -
            layout.inner_shift.get(root_id).unwrap_or(0.0) -
            port_cross(root_node, root_port, is_horizontal)
        _ => threshold = invalid
      }
    }
    let left_root = layout.root.get(left_id).unwrap_or(left_id)
    let right_root = layout.root.get(right_id).unwrap_or(right_id)
    layout.su[left_root] = true
    layout.su[right_root] = true
    (threshold, queue)
  } else {
    (invalid, queue)
  }
}

///|
fn calculate_threshold(
  graph : LGraph,
  layout : BKLayout,
  block_finished : Map[String, Bool],
  old_thresh : Double,
  block_root_id : String,
  current_id : String,
  queue : Array[Postprocessable],
  is_horizontal : Bool,
  use_threshold : Bool,
) -> (Double, Array[Postprocessable]) {
  if !use_threshold {
    let val = if layout.vdir == Up {
      @double.infinity
    } else {
      @double.neg_infinity
    }
    return (val, queue)
  }
  let mut out_queue = queue
  let is_root = block_root_id == current_id
  let is_last = layout.align.get(current_id).unwrap_or(block_root_id) ==
    block_root_id
  if !(is_root || is_last) {
    return (old_thresh, out_queue)
  }
  let mut t = old_thresh
  if layout.hdir == Right {
    if is_root {
      let (bound, q) = get_threshold_bound(
        graph,
        layout,
        block_finished,
        {
          free_id: block_root_id,
          is_root: true,
          has_edges: false,
          edge_id: None,
        },
        out_queue,
        is_horizontal,
      )
      t = bound
      out_queue = q
    }
    if (t == @double.infinity || t == @double.neg_infinity) && is_last {
      let (bound, q) = get_threshold_bound(
        graph,
        layout,
        block_finished,
        { free_id: current_id, is_root: false, has_edges: false, edge_id: None },
        out_queue,
        is_horizontal,
      )
      t = bound
      out_queue = q
    }
  } else {
    if is_root {
      let (bound, q) = get_threshold_bound(
        graph,
        layout,
        block_finished,
        {
          free_id: block_root_id,
          is_root: true,
          has_edges: false,
          edge_id: None,
        },
        out_queue,
        is_horizontal,
      )
      t = bound
      out_queue = q
    }
    if (t == @double.infinity || t == @double.neg_infinity) && is_last {
      let (bound, q) = get_threshold_bound(
        graph,
        layout,
        block_finished,
        { free_id: current_id, is_root: false, has_edges: false, edge_id: None },
        out_queue,
        is_horizontal,
      )
      t = bound
      out_queue = q
    }
  }
  (t, out_queue)
}

///|
fn process_postprocessable(
  graph : LGraph,
  layout : BKLayout,
  ni : NeighborInfo,
  spacings : SpacingOptions,
  pp : Postprocessable,
  is_horizontal : Bool,
) -> Bool {
  guard pp.edge_id is Some(edge_id) else { return false }
  let edge = get_edge_by_id(graph, edge_id)
  guard edge is Some(edge) else { return false }
  let (fix_id, fix_port, block_id, block_port) = if edge.source_id == pp.free_id {
    (edge.target_id, edge.target_port_id, edge.source_id, edge.source_port_id)
  } else {
    (edge.source_id, edge.source_port_id, edge.target_id, edge.target_port_id)
  }
  let delta = calculate_delta(
    graph, layout, fix_id, fix_port, block_id, block_port, is_horizontal,
  )
  let threshold = @double.infinity
  if delta > 0.0 && delta < threshold {
    let available = check_space_above(
      graph, layout, ni, spacings, block_id, delta, is_horizontal,
    )
    shift_block(layout, block_id, -available)
    return available > 0.0
  } else if delta < 0.0 && -delta < threshold {
    let available = check_space_below(
      graph,
      layout,
      ni,
      spacings,
      block_id,
      -delta,
      is_horizontal,
    )
    shift_block(layout, block_id, available)
    return available > 0.0
  }
  false
}

///|
fn post_process_thresholds(
  graph : LGraph,
  layout : BKLayout,
  ni : NeighborInfo,
  block_finished : Map[String, Bool],
  queue : Array[Postprocessable],
  spacings : SpacingOptions,
  is_horizontal : Bool,
) -> Unit {
  let stack : Array[Postprocessable] = []
  let mut idx = 0
  while idx < queue.length() {
    let pp = queue[idx]
    idx = idx + 1
    let pick = pick_edge(graph, layout, block_finished, pp)
    if pick.edge_id is None {
      continue
    }
    let edge = get_edge_by_id(graph, pick.edge_id.unwrap())
    guard edge is Some(edge) else { continue }
    let root_id = layout.root.get(pp.free_id).unwrap_or(pp.free_id)
    let only_dummies = layout.od.get(root_id).unwrap_or(false)
    if !only_dummies && is_in_layer_edge(graph, edge) {
      continue
    }
    let moved = process_postprocessable(
      graph, layout, ni, spacings, pick, is_horizontal,
    )
    if !moved {
      stack.push(pick)
    }
  }
  for i = stack.length() - 1; i >= 0; i = i - 1 {
    process_postprocessable(
      graph,
      layout,
      ni,
      spacings,
      stack[i],
      is_horizontal,
    )
    |> ignore
  }
}

///|
fn horizontal_compaction(
  graph : LGraph,
  layout : BKLayout,
  ni : NeighborInfo,
  spacings : SpacingOptions,
  is_horizontal : Bool,
  use_threshold : Bool,
) -> Unit {
  let class_nodes : Map[String, ClassNode] = {}
  let block_finished : Map[String, Bool] = {}
  let mut queue : Array[Postprocessable] = []
  let layers : Array[LLayer] = []
  if layout.hdir == Left {
    for i = 0; i < graph.layers.length(); i = i + 1 {
      let idx = graph.layers.length() - 1 - i
      layers.push(graph.layers[idx])
    }
  } else {
    layers.append(graph.layers)
  }
  fn place_block(
    graph : LGraph,
    layout : BKLayout,
    ni : NeighborInfo,
    spacings : SpacingOptions,
    is_horizontal : Bool,
    use_threshold : Bool,
    class_nodes : Map[String, ClassNode],
    block_finished : Map[String, Bool],
    queue : Array[Postprocessable],
    root_id : String,
  ) -> Array[Postprocessable] {
    let mut queue = queue
    let placed = match layout.y.get(root_id) {
      Some(Some(_)) => true
      _ => false
    }
    if placed {
      return queue
    }
    layout.y[root_id] = Some(0.0)
    let mut is_initial = true
    let mut current_id = root_id
    let mut thresh = if layout.vdir == Down {
      @double.neg_infinity
    } else {
      @double.infinity
    }
    while true {
      let current_opt = graph.get_node(current_id)
      if current_opt is None {
        break
      }
      let current = current_opt.unwrap()
      let current_index = ni.node_index.get(current_id).unwrap_or(0)
      let layer_nodes = node_layer_nodes(graph, current)
      if (layout.vdir == Down && current_index > 0) ||
        (layout.vdir == Up && current_index < layer_nodes.length() - 1) {
        let neighbor = if layout.vdir == Up {
          layer_nodes[current_index + 1]
        } else {
          layer_nodes[current_index - 1]
        }
        let neighbor_root = layout.root.get(neighbor.id).unwrap_or(neighbor.id)
        queue = place_block(
          graph, layout, ni, spacings, is_horizontal, use_threshold, class_nodes,
          block_finished, queue, neighbor_root,
        )
        let (new_thresh, q2) = calculate_threshold(
          graph, layout, block_finished, thresh, root_id, current_id, queue, is_horizontal,
          use_threshold,
        )
        thresh = new_thresh
        queue = q2
        if layout.sink.get(root_id).unwrap_or(root_id) == root_id {
          let neigh_sink = layout.sink
            .get(neighbor_root)
            .unwrap_or(neighbor_root)
          layout.sink[root_id] = neigh_sink
        }
        let root_sink = layout.sink.get(root_id).unwrap_or(root_id)
        let neighbor_sink = layout.sink
          .get(neighbor_root)
          .unwrap_or(neighbor_root)
        if root_sink == neighbor_sink {
          let spacing = vertical_spacing(spacings, current, neighbor)
          if layout.vdir == Up {
            let new_pos = layout.y
              .get(neighbor_root)
              .unwrap_or(Some(0.0))
              .unwrap_or(0.0) +
              layout.inner_shift.get(neighbor.id).unwrap_or(0.0) -
              spacing -
              node_size_cross(current, is_horizontal) -
              layout.inner_shift.get(current_id).unwrap_or(0.0)
            let cur = layout.y.get(root_id).unwrap_or(Some(0.0)).unwrap_or(0.0)
            let next = if is_initial { new_pos } else { bk_min(cur, new_pos) }
            layout.y[root_id] = Some(bk_min(next, thresh))
            is_initial = false
          } else {
            let new_pos = layout.y
              .get(neighbor_root)
              .unwrap_or(Some(0.0))
              .unwrap_or(0.0) +
              layout.inner_shift.get(neighbor.id).unwrap_or(0.0) +
              node_size_cross(neighbor, is_horizontal) +
              spacing -
              layout.inner_shift.get(current_id).unwrap_or(0.0)
            let cur = layout.y.get(root_id).unwrap_or(Some(0.0)).unwrap_or(0.0)
            let next = if is_initial { new_pos } else { bk_max(cur, new_pos) }
            layout.y[root_id] = Some(bk_max(next, thresh))
            is_initial = false
          }
        } else {
          // ELK's BKCompactor uses plain node-node spacing for class graph
          // separations (as opposed to type-dependent spacings).
          let spacing = spacings.node_node
          if layout.vdir == Up {
            let required = layout.y
              .get(root_id)
              .unwrap_or(Some(0.0))
              .unwrap_or(0.0) +
              layout.inner_shift.get(current_id).unwrap_or(0.0) +
              node_size_cross(current, is_horizontal) +
              spacing -
              (
                layout.y.get(neighbor_root).unwrap_or(Some(0.0)).unwrap_or(0.0) +
                layout.inner_shift.get(neighbor.id).unwrap_or(0.0)
              )
            add_class_edge(class_nodes, root_sink, neighbor_sink, required)
          } else {
            let required = layout.y
              .get(root_id)
              .unwrap_or(Some(0.0))
              .unwrap_or(0.0) +
              layout.inner_shift.get(current_id).unwrap_or(0.0) -
              layout.y.get(neighbor_root).unwrap_or(Some(0.0)).unwrap_or(0.0) -
              layout.inner_shift.get(neighbor.id).unwrap_or(0.0) -
              node_size_cross(neighbor, is_horizontal) -
              spacing
            add_class_edge(class_nodes, root_sink, neighbor_sink, required)
          }
        }
      } else {
        let (new_thresh, q2) = calculate_threshold(
          graph, layout, block_finished, thresh, root_id, current_id, queue, is_horizontal,
          use_threshold,
        )
        thresh = new_thresh
        queue = q2
      }
      current_id = layout.align.get(current_id).unwrap_or(root_id)
      if current_id == root_id {
        break
      }
    }
    block_finished[root_id] = true
    queue
  }

  for layer in layers {
    let nodes : Array[LNode] = []
    if layout.vdir == Up {
      for i = 0; i < layer.nodes.length(); i = i + 1 {
        let idx = layer.nodes.length() - 1 - i
        nodes.push(layer.nodes[idx])
      }
    } else {
      nodes.append(layer.nodes)
    }
    for node in nodes {
      let rid = layout.root.get(node.id).unwrap_or(node.id)
      if rid == node.id {
        queue = place_block(
          graph,
          layout,
          ni,
          spacings,
          is_horizontal,
          use_threshold,
          class_nodes,
          block_finished,
          queue,
          node.id,
        )
      }
    }
  }
  place_classes(class_nodes, layout)
  for layer in layers {
    for node in layer.nodes {
      let root_id = layout.root.get(node.id).unwrap_or(node.id)
      let mut y = layout.y.get(root_id).unwrap_or(Some(0.0)).unwrap_or(0.0)
      if node.id == root_id {
        let sink_id = layout.sink.get(root_id).unwrap_or(root_id)
        let sink_shift = layout.shift
          .get(sink_id)
          .unwrap_or(
            if layout.vdir == Up {
              @double.neg_infinity
            } else {
              @double.infinity
            },
          )
        if (layout.vdir == Up && sink_shift > @double.neg_infinity) ||
          (layout.vdir == Down && sink_shift < @double.infinity) {
          y = y + sink_shift
          layout.y[root_id] = Some(y)
        }
      }
      layout.y[node.id] = Some(y)
    }
  }
  if use_threshold {
    post_process_thresholds(
      graph, layout, ni, block_finished, queue, spacings, is_horizontal,
    )
  }
}

///|
fn layout_positions(graph : LGraph, layout : BKLayout) -> Map[String, Double] {
  let positions : Map[String, Double] = {}
  for node in graph.nodes {
    let base = layout.y.get(node.id).unwrap_or(None).unwrap_or(0.0)
    let shift = layout.inner_shift.get(node.id).unwrap_or(0.0)
    positions[node.id] = base + shift
  }
  positions
}

///|
fn layout_size(
  graph : LGraph,
  layout : BKLayout,
  is_horizontal : Bool,
) -> Double {
  let mut min_pos = @double.infinity
  let mut max_pos = @double.neg_infinity
  for node in graph.nodes {
    let root_id = layout.root.get(node.id).unwrap_or(node.id)
    let base = layout.y.get(node.id).unwrap_or(None).unwrap_or(0.0)
    let size = layout.block_size
      .get(root_id)
      .unwrap_or(node_size_cross(node, is_horizontal))
    if base < min_pos {
      min_pos = base
    }
    if base + size > max_pos {
      max_pos = base + size
    }
  }
  if min_pos == @double.infinity {
    0.0
  } else {
    max_pos - min_pos
  }
}

///|
fn check_order_constraint(
  graph : LGraph,
  positions : Map[String, Double],
  is_horizontal : Bool,
) -> Bool {
  fn margin_leading(n : LNode) -> Double {
    if is_horizontal {
      n.properties.get_double_or("diago.layered.marginTop", 0.0)
    } else {
      n.properties.get_double_or("diago.layered.marginLeft", 0.0)
    }
  }

  fn margin_trailing(n : LNode) -> Double {
    if is_horizontal {
      n.properties.get_double_or("diago.layered.marginBottom", 0.0)
    } else {
      n.properties.get_double_or("diago.layered.marginRight", 0.0)
    }
  }

  let mut feasible = true
  for layer in graph.layers {
    let mut pos = @double.neg_infinity
    for node in layer.nodes {
      // Mirror ELK: include node margins when checking overlaps.
      let base = positions.get(node.id).unwrap_or(0.0)
      let top = base - margin_leading(node)
      let bottom = base +
        node_size_cross(node, is_horizontal) +
        margin_trailing(node)
      if top > pos && bottom > pos {
        pos = bottom
      } else {
        feasible = false
        break
      }
    }
    if !feasible {
      break
    }
  }
  feasible
}

///|
fn enforce_layer_spacing(
  graph : LGraph,
  positions : Map[String, Double],
  spacings : SpacingOptions,
  is_horizontal : Bool,
) -> Map[String, Double] {
  fn margin_leading(n : LNode) -> Double {
    if is_horizontal {
      n.properties.get_double_or("diago.layered.marginTop", 0.0)
    } else {
      n.properties.get_double_or("diago.layered.marginLeft", 0.0)
    }
  }

  fn margin_trailing(n : LNode) -> Double {
    if is_horizontal {
      n.properties.get_double_or("diago.layered.marginBottom", 0.0)
    } else {
      n.properties.get_double_or("diago.layered.marginRight", 0.0)
    }
  }

  let out : Map[String, Double] = {}
  for node in graph.nodes {
    out[node.id] = positions.get(node.id).unwrap_or(0.0)
  }
  for layer in graph.layers {
    let mut prev_node : LNode? = None
    let mut prev_pos = 0.0
    for node in layer.nodes {
      let mut pos = out.get(node.id).unwrap_or(0.0)
      match prev_node {
        Some(prev) => {
          let spacing = vertical_spacing(spacings, prev, node)
          let min_pos = prev_pos +
            node_size_cross(prev, is_horizontal) +
            margin_trailing(prev) +
            spacing +
            margin_leading(node)
          if pos < min_pos {
            pos = min_pos
            out[node.id] = pos
          }
          prev_pos = pos
        }
        None => prev_pos = pos
      }
      prev_node = Some(node)
    }
  }
  out
}

///|
fn normalize_positions(
  graph : LGraph,
  positions : Map[String, Double],
) -> Map[String, Double] {
  let mut min_pos = @double.infinity
  for node in graph.nodes {
    // External port dummy nodes represent hierarchical ports on the compound
    // border. They may be placed outside the content area and must not shift
    // the actual node coordinates when normalizing the layout.
    if node.node_type == ExternalPort {
      continue
    }
    let pos = positions.get(node.id).unwrap_or(0.0)
    if pos < min_pos {
      min_pos = pos
    }
  }
  if min_pos == @double.infinity || min_pos == 0.0 {
    return positions
  }
  let out : Map[String, Double] = {}
  for node in graph.nodes {
    out[node.id] = positions.get(node.id).unwrap_or(0.0) - min_pos
  }
  out
}

///|
fn create_balanced_layout(
  graph : LGraph,
  layouts : Array[BKLayout],
  is_horizontal : Bool,
) -> Map[String, Double] {
  if layouts.length() == 0 {
    return {}
  }
  let no_layouts = layouts.length()
  let min_vals : Array[Double] = []
  let max_vals : Array[Double] = []
  let widths : Array[Double] = []
  for _ in 0..<no_layouts {
    min_vals.push(@double.infinity)
    max_vals.push(@double.neg_infinity)
    widths.push(0.0)
  }
  let mut min_idx = 0
  for i = 0; i < no_layouts; i = i + 1 {
    let layout = layouts[i]
    widths[i] = layout_size(graph, layout, is_horizontal)
    if widths[i] < widths[min_idx] {
      min_idx = i
    }
    for node in graph.nodes {
      let base = layout.y.get(node.id).unwrap_or(Some(0.0)).unwrap_or(0.0)
      let shift = layout.inner_shift.get(node.id).unwrap_or(0.0)
      let pos = base + shift
      let size = node_size_cross(node, is_horizontal)
      if pos < min_vals[i] {
        min_vals[i] = pos
      }
      if pos + size > max_vals[i] {
        max_vals[i] = pos + size
      }
    }
  }
  let shifts : Array[Double] = []
  for i = 0; i < no_layouts; i = i + 1 {
    let layout = layouts[i]
    if layout.vdir == Down {
      shifts.push(min_vals[min_idx] - min_vals[i])
    } else {
      shifts.push(max_vals[min_idx] - max_vals[i])
    }
  }
  let balanced : Map[String, Double] = {}
  for node in graph.nodes {
    let values : Array[Double] = []
    for i = 0; i < no_layouts; i = i + 1 {
      let layout = layouts[i]
      let base = layout.y.get(node.id).unwrap_or(Some(0.0)).unwrap_or(0.0)
      let shift = layout.inner_shift.get(node.id).unwrap_or(0.0)
      values.push(base + shift + shifts[i])
    }
    values.sort_by(fn(a, b) { if a < b { -1 } else if a > b { 1 } else { 0 } })
    if values.length() >= 4 {
      balanced[node.id] = (values[1] + values[2]) / 2.0
    } else if values.length() > 0 {
      balanced[node.id] = values[values.length() / 2]
    } else {
      balanced[node.id] = 0.0
    }
  }
  balanced
}

///|
fn straight_edge_score(
  positions : Map[String, Double],
  graph : LGraph,
  is_horizontal : Bool,
) -> Int {
  let eps = 0.5
  let mut score = 0
  for edge in graph.edges {
    if edge.properties.get_bool_or("diago.layered.longEdgeSplit", false) {
      continue
    }
    let source = graph.get_node(edge.source_id)
    let target = graph.get_node(edge.target_id)
    guard source is Some(src) && target is Some(tgt) else { continue }
    if src.is_dummy() || tgt.is_dummy() {
      continue
    }
    if src.layer == tgt.layer {
      continue
    }
    let src_pos = positions.get(src.id).unwrap_or(0.0)
    let tgt_pos = positions.get(tgt.id).unwrap_or(0.0)
    let src_anchor = port_cross(src, edge.source_port_id, is_horizontal)
    let tgt_anchor = port_cross(tgt, edge.target_port_id, is_horizontal)
    let src_center = src_pos + src_anchor
    let tgt_center = tgt_pos + tgt_anchor
    if (src_center - tgt_center).abs() <= eps {
      score = score + 1
    }
  }
  score
}

///|
#warnings("-unused_value")
fn select_smallest_layout(
  graph : LGraph,
  layouts : Array[BKLayout],
  is_horizontal : Bool,
) -> BKLayout {
  let mut best = layouts[0]
  let mut best_span = layout_size(graph, best, is_horizontal)
  for i = 1; i < layouts.length(); i = i + 1 {
    let span = layout_size(graph, layouts[i], is_horizontal)
    if span < best_span {
      best = layouts[i]
      best_span = span
    }
  }
  best
}

///|
#warnings("-unused_value")
fn select_favor_straight_layout(
  graph : LGraph,
  layouts : Array[BKLayout],
  is_horizontal : Bool,
) -> BKLayout {
  let mut best = layouts[0]
  let best_positions = layout_positions(graph, best)
  let mut best_score = straight_edge_score(best_positions, graph, is_horizontal)
  let mut best_span = layout_size(graph, best, is_horizontal)
  for i = 1; i < layouts.length(); i = i + 1 {
    let positions = layout_positions(graph, layouts[i])
    let score = straight_edge_score(positions, graph, is_horizontal)
    let span = layout_size(graph, layouts[i], is_horizontal)
    if score > best_score || (score == best_score && span < best_span) {
      best = layouts[i]
      best_score = score
      best_span = span
    }
  }
  best
}

///|
fn apply_layout(
  graph : LGraph,
  positions : Map[String, Double],
  layer_spacing : Double,
  padding : ElkPadding,
  is_horizontal : Bool,
  direction : LayoutDirection,
  content_alignment : ContentAlignment,
) -> Unit {
  fn node_margin_left(n : LNode) -> Double {
    n.properties.get_double_or("diago.layered.marginLeft", 0.0)
  }

  fn node_margin_top(n : LNode) -> Double {
    n.properties.get_double_or("diago.layered.marginTop", 0.0)
  }

  fn node_margin_right(n : LNode) -> Double {
    n.properties.get_double_or("diago.layered.marginRight", 0.0)
  }

  fn node_margin_bottom(n : LNode) -> Double {
    n.properties.get_double_or("diago.layered.marginBottom", 0.0)
  }

  fn max_double(a : Double, b : Double) -> Double {
    if a > b {
      a
    } else {
      b
    }
  }

  fn min_double(a : Double, b : Double) -> Double {
    if a < b {
      a
    } else {
      b
    }
  }

  // Port-balance alignment used by ELK (see `LGraphUtil.placeNodesHorizontally`):
  // sources align to the outgoing side, sinks to the incoming side, isolated
  // nodes are centered, and mixed nodes interpolate by out/(in+out), where
  // `in`/`out` count ports (not edges).
  fn bk_port_balance_ratio(node : LNode) -> Double {
    if node.ports.is_empty() {
      let inports = if node.incoming_edges.is_empty() { 0 } else { 1 }
      let outports = if node.outgoing_edges.is_empty() { 0 } else { 1 }
      let total = inports + outports
      return if total == 0 {
        0.5
      } else {
        outports.to_double() / total.to_double()
      }
    }
    let has_in : Map[String, Bool] = {}
    let has_out : Map[String, Bool] = {}
    let mut in_without_port = false
    let mut out_without_port = false
    for e in node.incoming_edges {
      match e.target_port_id {
        Some(pid) => has_in[pid] = true
        None => in_without_port = true
      }
    }
    for e in node.outgoing_edges {
      match e.source_port_id {
        Some(pid) => has_out[pid] = true
        None => out_without_port = true
      }
    }
    let mut inports = 0
    let mut outports = 0
    for p in node.ports {
      if has_in.get(p.id).unwrap_or(false) {
        inports = inports + 1
      }
      if has_out.get(p.id).unwrap_or(false) {
        outports = outports + 1
      }
    }
    if in_without_port {
      inports = inports + 1
    }
    if out_without_port {
      outports = outports + 1
    }
    let total = inports + outports
    if total == 0 {
      0.5
    } else {
      outports.to_double() / total.to_double()
    }
  }

  fn alignment_ratio(node : LNode) -> Double {
    let raw = node.properties
      .get_string("elk.layered.alignment")
      .unwrap_or(
        node.properties.get_string_or("org.eclipse.elk.layered.alignment", ""),
      )
    match raw.to_upper() {
      "LEFT" => 0.0
      "RIGHT" => 1.0
      "CENTER" => 0.5
      _ => bk_port_balance_ratio(node)
    }
  }
  // NOTE: Minimum-size handling and content alignment are applied after edge
  // routing to match ELK's `HierarchicalNodeResizingProcessor`. At this stage
  // we only place nodes and compute the natural content size.
  let _ = content_alignment
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
  fn layer_is_external(layer : LLayer) -> Bool {
    if layer.nodes.is_empty() {
      return false
    }
    for n in layer.nodes {
      if n.node_type != ExternalPort {
        return false
      }
    }
    true
  }

  for layer in layers {
    let is_external_layer = layer_is_external(layer)
    let mut layer_size = 0.0
    let mut max_leading_margin = 0.0
    let mut max_trailing_margin = 0.0
    for node in layer.nodes {
      if is_horizontal {
        let lm = node_margin_left(node)
        let rm = node_margin_right(node)
        max_leading_margin = max_double(max_leading_margin, lm)
        max_trailing_margin = max_double(max_trailing_margin, rm)
        layer_size = max_double(layer_size, node.width + lm + rm)
      } else {
        let tm = node_margin_top(node)
        let bm = node_margin_bottom(node)
        max_leading_margin = max_double(max_leading_margin, tm)
        max_trailing_margin = max_double(max_trailing_margin, bm)
        layer_size = max_double(layer_size, node.height + tm + bm)
      }
    }
    for node in layer.nodes {
      let cross_pos = positions.get(node.id).unwrap_or(0.0)
      let ratio = alignment_ratio(node)
      if is_horizontal {
        let mut xpos = (layer_size - node.width) * ratio
        if ratio > 0.5 {
          xpos = xpos - max_trailing_margin * 2.0 * (ratio - 0.5)
        } else if ratio < 0.5 {
          xpos = xpos + max_leading_margin * 2.0 * (0.5 - ratio)
        }
        let left_margin = node_margin_left(node)
        if xpos < left_margin {
          xpos = left_margin
        }
        let right_margin = node_margin_right(node)
        xpos = min_double(xpos, layer_size - right_margin - node.width)
        node.x = layer_offset + xpos
        node.y = cross_pos + padding.top
      } else {
        node.x = cross_pos + padding.left
        let mut ypos = (layer_size - node.height) * ratio
        if ratio > 0.5 {
          ypos = ypos - max_trailing_margin * 2.0 * (ratio - 0.5)
        } else if ratio < 0.5 {
          ypos = ypos + max_leading_margin * 2.0 * (0.5 - ratio)
        }
        let top_margin = node_margin_top(node)
        if ypos < top_margin {
          ypos = top_margin
        }
        let bottom_margin = node_margin_bottom(node)
        ypos = min_double(ypos, layer_size - bottom_margin - node.height)
        node.y = layer_offset + ypos
      }
    }
    // External-port layers represent hierarchical ports on the compound node
    // border and must not consume regular layer spacing (ELK behavior).
    if !is_external_layer {
      layer_offset = layer_offset + layer_size + layer_spacing
    }
  }
  let mut max_x = 0.0
  let mut max_y = 0.0
  for node in graph.nodes {
    // External port dummies represent hierarchical ports and are positioned
    // on or outside the graph boundary. They must not contribute to the
    // compound node's computed size (ELK behavior).
    if node.node_type == ExternalPort {
      continue
    }
    max_x = max_double(max_x, node.x + node.width + node_margin_right(node))
    max_y = max_double(max_y, node.y + node.height + node_margin_bottom(node))
  }
  graph.width = max_x + padding.right
  graph.height = max_y + padding.bottom
}

// ============================================================================
// Brandes-Koepf Algorithm Implementation
// ============================================================================

///|
/// Run Brandes-Koepf node placement
fn run_brandes_koepf(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
) -> Unit {
  if graph.nodes.length() == 0 {
    return
  }
  let spacings = resolve_spacings(options)
  let layer_spacing = options.node_node_between_layers_spacing.unwrap_or(40.0)
  let padding = effective_graph_padding(graph, options)
  let is_horizontal = direction.is_horizontal()
  let edge_routing = options.edge_routing.unwrap_or(Orthogonal)
  let favor_straight_edges = edge_routing == Orthogonal
  let requested = options.bk_fixed_alignment
  let produce_balanced = match requested {
    Some(Average) => true
    Some(_) => false
    None => !favor_straight_edges
  }
  let use_threshold = match options.bk_edge_straightening {
    Some(ImproveStraightness) | None => true
    _ => false
  }
  let content_alignment = options.content_alignment.unwrap_or(None)
  let ni = build_neighbor_info(graph)
  let marked = mark_conflicts(graph, ni)
  let layouts : Array[BKLayout] = []
  match requested {
    Some(LeftDown) => {
      let layout = init_layout(graph, Down, Left)
      vertical_alignment(graph, ni, marked, layout)
      inside_block_shift(graph, layout, is_horizontal)
      horizontal_compaction(
        graph, layout, ni, spacings, is_horizontal, use_threshold,
      )
      layouts.push(layout)
    }
    Some(LeftUp) => {
      let layout = init_layout(graph, Up, Left)
      vertical_alignment(graph, ni, marked, layout)
      inside_block_shift(graph, layout, is_horizontal)
      horizontal_compaction(
        graph, layout, ni, spacings, is_horizontal, use_threshold,
      )
      layouts.push(layout)
    }
    Some(RightDown) => {
      let layout = init_layout(graph, Down, Right)
      vertical_alignment(graph, ni, marked, layout)
      inside_block_shift(graph, layout, is_horizontal)
      horizontal_compaction(
        graph, layout, ni, spacings, is_horizontal, use_threshold,
      )
      layouts.push(layout)
    }
    Some(RightUp) => {
      let layout = init_layout(graph, Up, Right)
      vertical_alignment(graph, ni, marked, layout)
      inside_block_shift(graph, layout, is_horizontal)
      horizontal_compaction(
        graph, layout, ni, spacings, is_horizontal, use_threshold,
      )
      layouts.push(layout)
    }
    Some(Average) | None => {
      let combos : Array[(VDirection, HDirection)] = [
        (Down, Right),
        (Up, Right),
        (Down, Left),
        (Up, Left),
      ]
      for pair in combos {
        let (vdir, hdir) = pair
        let layout = init_layout(graph, vdir, hdir)
        vertical_alignment(graph, ni, marked, layout)
        inside_block_shift(graph, layout, is_horizontal)
        horizontal_compaction(
          graph, layout, ni, spacings, is_horizontal, use_threshold,
        )
        layouts.push(layout)
      }
    }
  }
  let mut positions : Map[String, Double]? = None
  if produce_balanced {
    let balanced = create_balanced_layout(graph, layouts, is_horizontal)
    if check_order_constraint(graph, balanced, is_horizontal) {
      positions = Some(balanced)
    }
  }
  if positions is None {
    let mut best_span = @double.infinity
    for layout in layouts {
      let candidate = layout_positions(graph, layout)
      if check_order_constraint(graph, candidate, is_horizontal) {
        let span = layout_size(graph, layout, is_horizontal)
        if span < best_span {
          best_span = span
          positions = Some(candidate)
        }
      }
    }
  }
  if positions is None {
    positions = Some(layout_positions(graph, layouts[0]))
  }
  let mut positions = positions.unwrap_or({})
  if !check_order_constraint(graph, positions, is_horizontal) {
    positions = enforce_layer_spacing(graph, positions, spacings, is_horizontal)
  }
  positions = normalize_positions(graph, positions)
  apply_layout(
    graph, positions, layer_spacing, padding, is_horizontal, direction, content_alignment,
  )
}

///|
fn bk_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn bk_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
