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
/// ELK Layered Algorithm - Internal Types
/// These types represent the internal graph structure used during layered layout

// ============================================================================
// Node Types
// ============================================================================

///|
/// Type of node in the layered graph
#warnings("-unused_constructor")
enum LNodeType {
  Normal // Regular node from the original graph
  LongEdgeDummy // Virtual node for long edges spanning multiple layers
  NorthSouthPort // Virtual node for north/south ports
  ExternalPort // Virtual node for external ports
  LabelDummy // Virtual node for edge labels
  BreakPoint // Virtual node for edge breaks
} derive(Show, Eq)

///|
/// A node in the layered graph
struct LNode {
  id : String
  mut original_id : String? // ID of original ElkNode (None for dummies)
  node_type : LNodeType
  mut layer : Int // Layer index (-1 if not assigned)
  mut position : Int // Position within layer (-1 if not assigned)
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  incoming_edges : Array[LEdge]
  outgoing_edges : Array[LEdge]
  ports : Array[LPort]
  labels : Array[LLabel]
  // For dummy nodes: the edge they belong to
  mut origin_edge : String?
  // Nested graph for compound nodes
  mut nested_graph : LGraph?
  properties : ElkProperties
} derive(Show)

///|
fn LNode::new(id : String, node_type : LNodeType) -> LNode {
  {
    id,
    original_id: None,
    node_type,
    layer: -1,
    position: -1,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    incoming_edges: [],
    outgoing_edges: [],
    ports: [],
    labels: [],
    origin_edge: None,
    nested_graph: None,
    properties: ElkProperties::new(),
  }
}

///|
fn LNode::from_elk_node(elk_node : ElkNode) -> LNode {
  let node = LNode::new(elk_node.id, Normal)
  node.original_id = Some(elk_node.id)
  node.x = elk_node.x
  node.y = elk_node.y
  node.width = elk_node.width
  node.height = elk_node.height
  node.properties.copy_from(elk_node.properties)
  // Convert labels
  for label in elk_node.labels {
    node.labels.push(LLabel::from_elk_label(label))
  }
  // Convert ports (preserve input order for model order processing)
  for i, port in elk_node.ports {
    let lport = LPort::from_elk_port(port)
    lport.properties.set("diago.layered.modelOrder", Int(i))
    node.ports.push(lport)
  }
  node
}

///|
/// Check if this is a dummy node
fn LNode::is_dummy(self : LNode) -> Bool {
  match self.node_type {
    Normal => false
    _ => true
  }
}

///|
/// Get the degree of this node (incoming + outgoing edges)
#warnings("-unused_value")
fn LNode::degree(self : LNode) -> Int {
  self.incoming_edges.length() + self.outgoing_edges.length()
}

///|
/// Get in-degree
fn LNode::in_degree(self : LNode) -> Int {
  self.incoming_edges.length()
}

///|
/// Get out-degree
#warnings("-unused_value")
fn LNode::out_degree(self : LNode) -> Int {
  self.outgoing_edges.length()
}

// ============================================================================
// Port Types
// ============================================================================

///|
/// A port in the layered graph
struct LPort {
  id : String
  mut original_id : String?
  mut side : ElkPortSide
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  labels : Array[LLabel]
  properties : ElkProperties
} derive(Show)

///|
fn LPort::new(id : String) -> LPort {
  {
    id,
    original_id: None,
    side: Undefined,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    labels: [],
    properties: ElkProperties::new(),
  }
}

///|
fn LPort::from_elk_port(elk_port : ElkPort) -> LPort {
  let port = LPort::new(elk_port.id)
  port.original_id = Some(elk_port.id)
  port.side = elk_port.side
  port.x = elk_port.x
  port.y = elk_port.y
  port.width = elk_port.width
  port.height = elk_port.height
  port.properties.copy_from(elk_port.properties)
  for label in elk_port.labels {
    port.labels.push(LLabel::from_elk_label(label))
  }
  port
}

// ============================================================================
// Label Types
// ============================================================================

///|
/// A label in the layered graph
struct LLabel {
  id : String
  text : String
  mut x : Double
  mut y : Double
  width : Double
  height : Double
  properties : ElkProperties
} derive(Show)

///|
#warnings("-unused_value")
fn LLabel::new(id : String, text : String) -> LLabel {
  {
    id,
    text,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    properties: ElkProperties::new(),
  }
}

///|
fn LLabel::from_elk_label(elk_label : ElkLabel) -> LLabel {
  let props = ElkProperties::new()
  props.copy_from(elk_label.properties)
  {
    id: elk_label.id,
    text: elk_label.text,
    x: elk_label.x,
    y: elk_label.y,
    width: elk_label.width,
    height: elk_label.height,
    properties: props,
  }
}

// ============================================================================
// Edge Types
// ============================================================================

///|
/// An edge in the layered graph
/// Uses node IDs instead of direct references to avoid circular references
struct LEdge {
  id : String
  mut original_id : String?
  mut source_id : String
  mut target_id : String
  // Port IDs for edge routing (optional)
  mut source_port_id : String?
  mut target_port_id : String?
  labels : Array[LLabel]
  // Edge routing
  bend_points : Array[ElkPoint]
  // For reversed edges during cycle breaking
  mut reversed : Bool
  // Priority for crossing minimization
  mut priority : Int
  // Offset for parallel edge routing (to distinguish parallel edges)
  mut parallel_offset : Double
  properties : ElkProperties
} derive(Show)

///|
fn LEdge::new(id : String, source_id : String, target_id : String) -> LEdge {
  {
    id,
    original_id: None,
    source_id,
    target_id,
    source_port_id: None,
    target_port_id: None,
    labels: [],
    bend_points: [],
    reversed: false,
    priority: 0,
    parallel_offset: 0.0,
    properties: ElkProperties::new(),
  }
}

///|
/// Reverse this edge (swap source and target)
fn LEdge::reverse(self : LEdge) -> Unit {
  let temp = self.source_id
  self.source_id = self.target_id
  self.target_id = temp
  let temp_port = self.source_port_id
  self.source_port_id = self.target_port_id
  self.target_port_id = temp_port

  // Keep bend point traversal consistent with direction.
  let n = self.bend_points.length()
  for i = 0; i < n / 2; i = i + 1 {
    let j = n - 1 - i
    let tmp = self.bend_points[i]
    self.bend_points[i] = self.bend_points[j]
    self.bend_points[j] = tmp
  }
  self.reversed = !self.reversed
}

///|
/// Check if this edge is a self-loop
fn LEdge::is_self_loop(self : LEdge) -> Bool {
  self.source_id == self.target_id
}

///|
/// Get the source node from a graph
#warnings("-unused_value")
fn LEdge::get_source(self : LEdge, graph : LGraph) -> LNode? {
  graph.node_map.get(self.source_id)
}

///|
/// Get the target node from a graph
#warnings("-unused_value")
fn LEdge::get_target(self : LEdge, graph : LGraph) -> LNode? {
  graph.node_map.get(self.target_id)
}

// ============================================================================
// Layer Types
// ============================================================================

///|
/// A layer in the layered graph
struct LLayer {
  index : Int
  nodes : Array[LNode]
} derive(Show)

///|
fn LLayer::new(index : Int) -> LLayer {
  { index, nodes: [] }
}

///|
#warnings("-unused_value")
fn LLayer::add_node(self : LLayer, node : LNode) -> Unit {
  node.layer = self.index
  node.position = self.nodes.length()
  self.nodes.push(node)
}

// ============================================================================
// Graph Types
// ============================================================================

///|
/// The layered graph - internal representation for the layered algorithm
struct LGraph {
  id : String
  nodes : Array[LNode]
  edges : Array[LEdge]
  self_loop_edges : Array[LEdge]
  layers : Array[LLayer]
  // Node lookup map for O(1) access by ID
  node_map : Map[String, LNode]
  // Graph properties
  mut width : Double
  mut height : Double
  properties : ElkProperties
} derive(Show)

///|
fn LGraph::new(id : String) -> LGraph {
  {
    id,
    nodes: [],
    edges: [],
    self_loop_edges: [],
    layers: [],
    node_map: {},
    width: 0.0,
    height: 0.0,
    properties: ElkProperties::new(),
  }
}

///|
/// Get a node by ID
fn LGraph::get_node(self : LGraph, id : String) -> LNode? {
  self.node_map.get(id)
}

///|
/// Add a node and update the lookup map
fn LGraph::add_node(self : LGraph, node : LNode) -> Unit {
  self.nodes.push(node)
  self.node_map[node.id] = node
}

///|
/// Convert an ElkNode (root graph) to an LGraph
fn LGraph::from_elk_node(elk_node : ElkNode) -> LGraph {
  let graph = LGraph::new(elk_node.id)
  graph.width = elk_node.width
  graph.height = elk_node.height
  graph.properties.copy_from(elk_node.properties)

  // Preserve the root node's label extents so node placement can enforce a
  // minimum container size that fits the title (D2 behavior).
  if !elk_node.labels.is_empty() {
    let mut max_w = 0.0
    let mut max_h = 0.0
    for label in elk_node.labels {
      let w = if label.width > 0.0 {
        label.width
      } else {
        // Fallback should match `ensure_label_size`'s rough heuristic.
        label.text.length().to_double() * 8.0
      }
      let h = if label.height > 0.0 { label.height } else { 14.0 }
      if w > max_w {
        max_w = w
      }
      if h > max_h {
        max_h = h
      }
    }
    graph.properties.set("diago.layered.rootLabelWidth", Double(max_w))
    graph.properties.set("diago.layered.rootLabelHeight", Double(max_h))
  }

  // Convert all children to LNodes (preserve input order for model order)
  for i, child in elk_node.children {
    let lnode = LNode::from_elk_node(child)
    lnode.properties.set("diago.layered.modelOrder", Int(i))
    graph.add_node(lnode)

    // Handle nested graphs recursively
    if child.children.length() > 0 {
      lnode.nested_graph = Some(LGraph::from_elk_node(child))
    }
  }
  fn find_top_level_container_id(root : ElkNode, id : String) -> String? {
    for child in root.children {
      if child.id == id {
        return Some(child.id)
      }
      match child.find_node(id) {
        Some(_) => return Some(child.id)
        None => ()
      }
    }
    None
  }
  // Try to infer the direction from graph properties (present when coming from
  // the diago->ELK bridge). Default to DOWN for whitebox fixtures.
  let dir = graph.properties.get_enum("elk.direction").unwrap_or("DOWN")
  fn port_side(dir : String, suffix : String) -> ElkPortSide {
    match dir {
      "UP" =>
        if suffix == "src" { ElkPortSide::North } else { ElkPortSide::South }
      "LEFT" =>
        if suffix == "src" { ElkPortSide::West } else { ElkPortSide::East }
      "RIGHT" =>
        if suffix == "src" { ElkPortSide::East } else { ElkPortSide::West }
      _ => if suffix == "src" { ElkPortSide::South } else { ElkPortSide::North }
    }
  }
  fn add_hierarchical_port(
    graph : LGraph,
    container_id : String,
    child_id : String,
    suffix : String,
  ) -> String? {
    match graph.node_map.get(container_id) {
      Some(container) =>
        match container.nested_graph {
          Some(nested) =>
            match nested.get_node(child_id) {
              Some(child) => {
                // Hierarchical ports need stable positions derived from the
                // already-laid-out nested graph (ELK's hierarchical port
                // processors). We approximate this by fixing the port geometry
                // and snapping it to the requested side during `position_ports`.
                if container.properties.get_string("elk.portConstraints") is None {
                  container.properties.set(
                    "elk.portConstraints",
                    Enum("FIXED_POS"),
                  )
                }
                let port_id = container_id +
                  "|hier|" +
                  child_id +
                  "|" +
                  suffix
                for p in container.ports {
                  if p.id == port_id {
                    return Some(port_id)
                  }
                }
                let port = LPort::new(port_id)
                port.side = port_side(dir, suffix)
                // Use the nested child's center as the port position hint; the
                // port side determines which border the anchor snaps to.
                port.x = child.x + child.width / 2.0
                port.y = child.y + child.height / 2.0
                container.ports.push(port)
                Some(port_id)
              }
              None => None
            }
          None => None
        }
      None => None
    }
  }

  fn add_edge_port(
    graph : LGraph,
    node_id : String,
    edge_id : String,
    suffix : String,
    ratio : Double?,
  ) -> String? {
    match graph.node_map.get(node_id) {
      Some(node) => {
        let port_id = node_id + "|edge|" + edge_id + "|" + suffix
        for p in node.ports {
          if p.id == port_id {
            return Some(port_id)
          }
        }
        let port = LPort::new(port_id)
        port.side = port_side(dir, suffix)
        match ratio {
          Some(r) => {
            let rr = if r < 0.0 { 0.0 } else if r > 1.0 { 1.0 } else { r }
            if dir == "LEFT" || dir == "RIGHT" {
              port.y = rr * node.height
              if port.y == 0.0 {
                port.y = 0.001
              }
            } else {
              port.x = rr * node.width
              if port.x == 0.0 {
                port.x = 0.001
              }
            }
          }
          None => ()
        }
        node.ports.push(port)
        Some(port_id)
      }
      None => None
    }
  }

  fn port_ratio(node : LNode, port_id : String) -> Double? {
    for p in node.ports {
      if p.id == port_id {
        if dir == "LEFT" || dir == "RIGHT" {
          if node.height <= 0.0 {
            return None
          }
          return Some(p.y / node.height)
        }
        if node.width <= 0.0 {
          return None
        }
        return Some(p.x / node.width)
      }
    }
    None
  }

  // Convert all edges - now using IDs instead of node references
  for i, elk_edge in elk_node.edges {
    // Handle hyperedges - for now, assume simple edges
    if elk_edge.sources.length() > 0 && elk_edge.targets.length() > 0 {
      let original_source_id = elk_edge.sources[0]
      let original_target_id = elk_edge.targets[0]
      // Cross-hierarchy edges: map endpoints to their top-level container
      let source_id = if graph.node_map.contains(original_source_id) {
        original_source_id
      } else {
        find_top_level_container_id(elk_node, original_source_id).unwrap_or(
          original_source_id,
        )
      }
      let target_id = if graph.node_map.contains(original_target_id) {
        original_target_id
      } else {
        find_top_level_container_id(elk_node, original_target_id).unwrap_or(
          original_target_id,
        )
      }
      let mut source_port_id = elk_edge.source_port_id()
      let mut target_port_id = elk_edge.target_port_id()
      if source_id != original_source_id {
        match
          add_hierarchical_port(graph, source_id, original_source_id, "src") {
          Some(pid) => source_port_id = Some(pid)
          None => ()
        }
      }
      if target_id != original_target_id {
        match
          add_hierarchical_port(graph, target_id, original_target_id, "dst") {
          Some(pid) => target_port_id = Some(pid)
          None => ()
        }
      }
      // If one endpoint uses a port (hierarchical or explicit), give the other
      // endpoint a per-edge port too. We rely on port positioning processors to
      // turn the per-edge port order into stable geometry for placement/routing.
      if source_port_id is None && target_port_id is Some(tpid) {
        let ratio = match graph.node_map.get(target_id) {
          Some(tgt) => port_ratio(tgt, tpid).unwrap_or(0.5)
          None => 0.5
        }
        match add_edge_port(graph, source_id, elk_edge.id, "src", Some(ratio)) {
          Some(pid) => source_port_id = Some(pid)
          None => ()
        }
      }
      if target_port_id is None && source_port_id is Some(spid) {
        let ratio = match graph.node_map.get(source_id) {
          Some(src) => port_ratio(src, spid).unwrap_or(0.5)
          None => 0.5
        }
        match add_edge_port(graph, target_id, elk_edge.id, "dst", Some(ratio)) {
          Some(pid) => target_port_id = Some(pid)
          None => ()
        }
      }
      // Only create edge if both nodes exist
      if graph.node_map.contains(source_id) &&
        graph.node_map.contains(target_id) {
        let ledge = LEdge::new(elk_edge.id, source_id, target_id)
        ledge.original_id = Some(elk_edge.id)
        ledge.source_port_id = source_port_id
        ledge.target_port_id = target_port_id
        ledge.properties.copy_from(elk_edge.properties)
        ledge.properties.set("diago.layered.modelOrder", Int(i))
        ledge.properties.set(
          "diago.layered.originalSourceId",
          String(original_source_id),
        )
        ledge.properties.set(
          "diago.layered.originalTargetId",
          String(original_target_id),
        )
        ledge.properties.set(
          "diago.layered.crossHierarchy",
          Bool(
            source_id != original_source_id || target_id != original_target_id,
          ),
        )
        ledge.priority = elk_edge.properties
          .get_int("elk.priority")
          .unwrap_or(
            elk_edge.properties.get_int_or("org.eclipse.elk.priority", 0),
          )
        // Convert labels
        for label in elk_edge.labels {
          ledge.labels.push(LLabel::from_elk_label(label))
        }
        // Link edge to nodes (nodes still reference edges for algorithm efficiency)
        match graph.node_map.get(source_id) {
          Some(source) => source.outgoing_edges.push(ledge)
          None => ()
        }
        match graph.node_map.get(target_id) {
          Some(target) => target.incoming_edges.push(ledge)
          None => ()
        }
        graph.edges.push(ledge)
      }
    }
  }
  graph
}

///|
/// Apply layout results back to an ElkNode
fn LGraph::to_elk_node(
  self : LGraph,
  elk_node : ElkNode,
  direction : LayoutDirection,
  options : LayoutOptions,
) -> Unit {
  elk_node.width = self.width
  elk_node.height = self.height

  // Create a map of LNodes by original_id
  let lnode_map : Map[String, LNode] = {}
  for lnode in self.nodes {
    match lnode.original_id {
      Some(id) => lnode_map[id] = lnode
      None => ()
    }
  }
  fn stack_total(labels : Array[LLabel], gap : Double) -> Double {
    if labels.is_empty() {
      0.0
    } else {
      let mut sum = 0.0
      for l in labels {
        sum = sum + l.height
      }
      sum + (labels.length() - 1).to_double() * gap
    }
  }

  fn place_node_labels(lnode : LNode, node_options : LayoutOptions) -> Unit {
    if lnode.labels.is_empty() {
      return
    }
    let placements = node_options.node_label_placement.unwrap_or([])
    let outside = placements.contains(Outside)
    let inside = placements.contains(Inside) || !outside
    let top = placements.contains(Top)
    let bottom = placements.contains(Bottom)
    let left = placements.contains(Left)
    let right = placements.contains(Right)
    let spacing = node_options.label_node_spacing.unwrap_or(5.0)
    let gap = node_options.label_label_spacing.unwrap_or(0.0)
    let total_h = stack_total(lnode.labels, gap)
    let start_y = if outside {
      if top {
        lnode.y - spacing - total_h
      } else if bottom {
        lnode.y + lnode.height + spacing
      } else {
        lnode.y - spacing - total_h
      }
    } else if inside {
      if top {
        lnode.y + spacing
      } else if bottom {
        lnode.y + lnode.height - spacing - total_h
      } else {
        lnode.y + (lnode.height - total_h) / 2.0
      }
    } else {
      lnode.y + (lnode.height - total_h) / 2.0
    }
    let mut cursor = 0.0
    for label in lnode.labels {
      let x = if left {
        lnode.x + spacing
      } else if right {
        lnode.x + lnode.width - spacing - label.width
      } else {
        lnode.x + (lnode.width - label.width) / 2.0
      }
      label.x = x
      label.y = start_y + cursor
      cursor = cursor + label.height + gap
    }
  }

  fn place_port_labels(lnode : LNode, node_options : LayoutOptions) -> Unit {
    let placements = node_options.port_label_placement.unwrap_or([])
    let outside = placements.contains(Outside) ||
      placements.contains(NextToPortIfPossible)
    let inside = placements.contains(Inside) || !outside
    let spacing = node_options.label_node_spacing.unwrap_or(5.0)
    let gap = node_options.label_label_spacing.unwrap_or(0.0)
    for port in lnode.ports {
      if port.labels.is_empty() {
        continue
      }
      let border = port.properties.get_double_or(
        "diago.layered.portBorderOffset",
        node_options.port_border_offset.unwrap_or(0.0),
      )
      let (ax, ay) = if port.width > 0.0 || port.height > 0.0 {
        (
          lnode.x + port.x + port.width / 2.0,
          lnode.y + port.y + port.height / 2.0,
        )
      } else {
        match port.side {
          North => (lnode.x + port.x, lnode.y + border)
          South => (lnode.x + port.x, lnode.y + lnode.height - border)
          West => (lnode.x + border, lnode.y + port.y)
          East => (lnode.x + lnode.width - border, lnode.y + port.y)
          Undefined =>
            (lnode.x + lnode.width / 2.0, lnode.y + lnode.height / 2.0)
        }
      }
      let total_h = stack_total(port.labels, gap)
      let start_y = match port.side {
        North =>
          if outside {
            lnode.y - spacing - total_h
          } else {
            lnode.y + spacing
          }
        South =>
          if outside {
            lnode.y + lnode.height + spacing
          } else {
            lnode.y + lnode.height - spacing - total_h
          }
        _ => ay - total_h / 2.0
      }
      let mut cursor = 0.0
      for label in port.labels {
        let x = match port.side {
          West =>
            if outside {
              lnode.x - spacing - label.width
            } else if inside {
              lnode.x + spacing
            } else {
              ax - label.width / 2.0
            }
          East =>
            if outside {
              lnode.x + lnode.width + spacing
            } else if inside {
              lnode.x + lnode.width - spacing - label.width
            } else {
              ax - label.width / 2.0
            }
          _ => ax - label.width / 2.0
        }
        label.x = x
        label.y = start_y + cursor
        cursor = cursor + label.height + gap
      }
    }
  }

  // Apply positions to children
  for child in elk_node.children {
    match lnode_map.get(child.id) {
      Some(lnode) => {
        child.x = lnode.x
        child.y = lnode.y
        child.width = lnode.width
        child.height = lnode.height

        // Apply nested graph if present
        let child_options = resolve_options_for_node(options, child)
        match lnode.nested_graph {
          Some(nested) => nested.to_elk_node(child, direction, child_options)
          None => ()
        }
        place_node_labels(lnode, child_options)
        place_port_labels(lnode, child_options)
        if !child.labels.is_empty() && !lnode.labels.is_empty() {
          let label_map : Map[String, LLabel] = {}
          for llabel in lnode.labels {
            label_map[llabel.id] = llabel
          }
          for label in child.labels {
            match label_map.get(label.id) {
              Some(llabel) => {
                label.x = llabel.x
                label.y = llabel.y
                label.width = llabel.width
                label.height = llabel.height
              }
              None => ()
            }
          }
        }
        if !child.ports.is_empty() && !lnode.ports.is_empty() {
          let port_map : Map[String, LPort] = {}
          for lport in lnode.ports {
            port_map[lport.id] = lport
          }
          for port in child.ports {
            match port_map.get(port.id) {
              Some(lport) =>
                if !port.labels.is_empty() && !lport.labels.is_empty() {
                  let plabel_map : Map[String, LLabel] = {}
                  for llabel in lport.labels {
                    plabel_map[llabel.id] = llabel
                  }
                  for label in port.labels {
                    match plabel_map.get(label.id) {
                      Some(llabel) => {
                        label.x = llabel.x
                        label.y = llabel.y
                        label.width = llabel.width
                        label.height = llabel.height
                      }
                      None => ()
                    }
                  }
                }
              None => ()
            }
          }
        }
      }
      None => ()
    }
  }

  // Apply edge routes
  // Only map the first edge with each original_id (the original edge, not dummy edges)
  let ledge_map : Map[String, LEdge] = {}
  for ledge in self.edges {
    match ledge.original_id {
      Some(id) => if !ledge_map.contains(id) { ledge_map[id] = ledge }
      None => ()
    }
  }
  fn find_elk_node_abs(
    node : ElkNode,
    id : String,
    ox : Double,
    oy : Double,
  ) -> (ElkNode?, Double, Double) {
    let nx = ox + node.x
    let ny = oy + node.y
    if node.id == id {
      return (Some(node), nx, ny)
    }
    for child in node.children {
      let (found, fx, fy) = find_elk_node_abs(child, id, nx, ny)
      match found {
        Some(_) => return (found, fx, fy)
        None => ()
      }
    }
    (None, 0.0, 0.0)
  }

  fn anchor_on_node(
    node : ElkNode,
    abs_x : Double,
    abs_y : Double,
    direction : LayoutDirection,
    is_source : Bool,
  ) -> (Double, Double) {
    let cx = abs_x + node.width / 2.0
    let cy = abs_y + node.height / 2.0
    match direction {
      Down => if is_source { (cx, abs_y + node.height) } else { (cx, abs_y) }
      Up => if is_source { (cx, abs_y) } else { (cx, abs_y + node.height) }
      Right => if is_source { (abs_x + node.width, cy) } else { (abs_x, cy) }
      Left => if is_source { (abs_x, cy) } else { (abs_x + node.width, cy) }
      Undefined =>
        if is_source {
          (cx, abs_y + node.height)
        } else {
          (cx, abs_y)
        }
    }
  }

  for elk_edge in elk_node.edges {
    match ledge_map.get(elk_edge.id) {
      Some(ledge) => {
        let section = ElkEdgeSection::new(elk_edge.id + "_s0")
        let cross = ledge.properties.get_bool_or(
          "diago.layered.crossHierarchy", false,
        )
        if cross {
          let original_source_id = ledge.properties
            .get_string("diago.layered.originalSourceId")
            .unwrap_or(ledge.source_id)
          let original_target_id = ledge.properties
            .get_string("diago.layered.originalTargetId")
            .unwrap_or(ledge.target_id)
          let (src_found, src_abs_x, src_abs_y) = find_elk_node_abs(
            elk_node, original_source_id, 0.0, 0.0,
          )
          let (tgt_found, tgt_abs_x, tgt_abs_y) = find_elk_node_abs(
            elk_node, original_target_id, 0.0, 0.0,
          )
          match (src_found, tgt_found) {
            (Some(src_node), Some(tgt_node)) => {
              let (start_x, start_y) = anchor_on_node(
                src_node, src_abs_x, src_abs_y, direction, true,
              )
              let (end_x, end_y) = anchor_on_node(
                tgt_node, tgt_abs_x, tgt_abs_y, direction, false,
              )
              section.start_point = ElkPoint::new(start_x, start_y)
              section.end_point = ElkPoint::new(end_x, end_y)
              section.bend_points.clear()
              if direction.is_vertical() {
                if (start_x - end_x).abs() >= 1.0 {
                  let mid_y = (start_y + end_y) / 2.0
                  section.bend_points.push(ElkPoint::new(start_x, mid_y))
                  section.bend_points.push(ElkPoint::new(end_x, mid_y))
                }
              } else if direction.is_horizontal() {
                if (start_y - end_y).abs() >= 1.0 {
                  let mid_x = (start_x + end_x) / 2.0
                  section.bend_points.push(ElkPoint::new(mid_x, start_y))
                  section.bend_points.push(ElkPoint::new(mid_x, end_y))
                }
              }
              elk_edge.sections.clear()
              elk_edge.sections.push(section)
            }
            _ => ()
          }
          continue
        }

        // Look up source and target nodes by ID
        let source_node = self.node_map.get(ledge.source_id)
        let target_node = self.node_map.get(ledge.target_id)
        fn default_anchor(
          node : LNode,
          direction : LayoutDirection,
          is_source : Bool,
        ) -> (Double, Double) {
          let cx = node.x + node.width / 2.0
          let cy = node.y + node.height / 2.0
          match direction {
            Down =>
              if is_source {
                (cx, node.y + node.height)
              } else {
                (cx, node.y)
              }
            Up =>
              if is_source {
                (cx, node.y)
              } else {
                (cx, node.y + node.height)
              }
            Right =>
              if is_source {
                (node.x + node.width, cy)
              } else {
                (node.x, cy)
              }
            Left =>
              if is_source {
                (node.x, cy)
              } else {
                (node.x + node.width, cy)
              }
            Undefined =>
              if is_source {
                (cx, node.y + node.height)
              } else {
                (cx, node.y)
              }
          }
        }

        fn anchor_with_port(
          node : LNode,
          port_id : String?,
          direction : LayoutDirection,
          is_source : Bool,
        ) -> (Double, Double) {
          match port_id {
            Some(pid) => {
              for port in node.ports {
                if port.id == pid {
                  let has_size = port.width > 0.0 || port.height > 0.0
                  if has_size {
                    return (
                      node.x + port.x + port.width / 2.0,
                      node.y + port.y + port.height / 2.0,
                    )
                  }
                  // Side-only ports: if no explicit position, fall back to side center
                  let has_pos = port.x != 0.0 || port.y != 0.0
                  let border = port.properties.get_double_or(
                    "diago.layered.portBorderOffset", 0.0,
                  )
                  let anchor = match port.side {
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
                        (
                          node.x + node.width / 2.0,
                          node.y + node.height - border,
                        )
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
                        (
                          node.x + node.width - border,
                          node.y + node.height / 2.0,
                        )
                      }
                    _ => (node.x + port.x, node.y + port.y)
                  }
                  return anchor
                }
              }
              default_anchor(node, direction, is_source)
            }
            None => default_anchor(node, direction, is_source)
          }
        }

        // In ELK, start/end points come from port anchors; fall back to node boundary.
        // Apply parallel_offset to keep parallel edges distinct.
        let offset = ledge.parallel_offset
        let (raw_start_x, raw_start_y) = match source_node {
          Some(src) =>
            anchor_with_port(src, ledge.source_port_id, direction, true)
          _ => (0.0, 0.0)
        }
        let (raw_end_x, raw_end_y) = match target_node {
          Some(tgt) =>
            anchor_with_port(tgt, ledge.target_port_id, direction, false)
          _ => (0.0, 0.0)
        }
        let (start_x, start_y, end_x, end_y) = if direction.is_vertical() {
          (raw_start_x + offset, raw_start_y, raw_end_x + offset, raw_end_y)
        } else if direction.is_horizontal() {
          (raw_start_x, raw_start_y + offset, raw_end_x, raw_end_y + offset)
        } else {
          (raw_start_x + offset, raw_start_y, raw_end_x + offset, raw_end_y)
        }
        section.start_point = ElkPoint::new(start_x, start_y)
        section.end_point = ElkPoint::new(end_x, end_y)

        // Copy bend points
        for bp in ledge.bend_points {
          section.bend_points.push(bp)
        }
        elk_edge.sections.clear()
        elk_edge.sections.push(section)

        // Apply edge label positions (absolute coords).
        if !elk_edge.labels.is_empty() && !ledge.labels.is_empty() {
          let label_map : Map[String, LLabel] = {}
          for llabel in ledge.labels {
            label_map[llabel.id] = llabel
          }
          for label in elk_edge.labels {
            match label_map.get(label.id) {
              Some(llabel) => {
                label.x = llabel.x
                label.y = llabel.y
                label.width = llabel.width
                label.height = llabel.height
              }
              None => ()
            }
          }
        }
      }
      None => ()
    }
  }
}

///|
/// Get all edges that span multiple layers (long edges)
fn LGraph::get_long_edges(self : LGraph) -> Array[LEdge] {
  let result : Array[LEdge] = []
  for edge in self.edges {
    let source_layer = match self.node_map.get(edge.source_id) {
      Some(n) => n.layer
      None => -1
    }
    let target_layer = match self.node_map.get(edge.target_id) {
      Some(n) => n.layer
      None => -1
    }
    if source_layer >= 0 &&
      target_layer >= 0 &&
      (target_layer - source_layer).abs() > 1 {
      result.push(edge)
    }
  }
  result
}

///|
/// Get all nodes in a specific layer
#warnings("-unused_value")
fn LGraph::get_layer_nodes(self : LGraph, layer_index : Int) -> Array[LNode] {
  let result : Array[LNode] = []
  for node in self.nodes {
    if node.layer == layer_index {
      result.push(node)
    }
  }
  result
}

///|
/// Initialize layers array based on node layer assignments
fn LGraph::initialize_layers(self : LGraph) -> Unit {
  // Find max layer
  let mut max_layer = -1
  for node in self.nodes {
    if node.layer > max_layer {
      max_layer = node.layer
    }
  }

  // Create layers
  self.layers.clear()
  for i = 0; i <= max_layer; i = i + 1 {
    self.layers.push(LLayer::new(i))
  }

  // Assign nodes to layers
  for node in self.nodes {
    if node.layer >= 0 && node.layer < self.layers.length() {
      self.layers[node.layer].nodes.push(node)
    }
  }

  // Update position indices and store initial model order.
  // Only set model order if requested by options.
  let mut enable_model_order = false
  fn get_string_any(props : ElkProperties, keys : Array[String]) -> String? {
    for key in keys {
      match props.get_string(key) {
        Some(v) => return Some(v)
        None => ()
      }
      match props.get_enum(key) {
        Some(v) => return Some(v)
        None => ()
      }
    }
    None
  }

  match
    get_string_any(self.properties, [
      "org.eclipse.elk.alg.layered.considerModelOrder.strategy", "elk.layered.considerModelOrder.strategy",
    ]) {
    Some(s) => if s.to_upper() != "NONE" { enable_model_order = true }
    None => ()
  }
  if self.properties.get_bool_or(
      "org.eclipse.elk.alg.layered.crossingMinimization.forceNodeModelOrder", false,
    ) {
    enable_model_order = true
  }
  for layer in self.layers {
    for i, node in layer.nodes {
      node.position = i
      if enable_model_order &&
        node.node_type is Normal &&
        !node.properties.get_bool_or(
          "org.eclipse.elk.alg.layered.considerModelOrder.noModelOrder", false,
        ) &&
        node.properties.get_int("diago.layered.modelOrder") is None {
        node.properties.set("diago.layered.modelOrder", Int(i))
      }
    }
  }
}

///|
/// Allocate a unique dummy node ID within this graph.
fn LGraph::alloc_dummy_id(self : LGraph) -> String {
  let key = "diago.layered.nextDummyId"
  let next = self.properties.get_int_or(key, 0)
  self.properties.set(key, Int(next + 1))
  "dummy_" + next.to_string()
}
