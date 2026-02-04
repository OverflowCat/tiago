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
    // Mirror ELK's port indexing: keep a stable input order unless explicitly
    // overridden by the input graph.
    if lport.properties.get_int("elk.port.index") is None &&
      lport.properties.get_int("org.eclipse.elk.port.index") is None {
      lport.properties.set("elk.port.index", Int(i))
    }
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
fn LGraph::from_elk_node(
  elk_node : ElkNode,
  direction : LayoutDirection,
) -> LGraph {
  let graph = LGraph::new(elk_node.id)
  graph.width = elk_node.width
  graph.height = elk_node.height
  graph.properties.copy_from(elk_node.properties)

  // Convert all children to LNodes (preserve input order for model order)
  for i, child in elk_node.children {
    let lnode = LNode::from_elk_node(child)
    lnode.properties.set("diago.layered.modelOrder", Int(i))
    graph.add_node(lnode)

    // Handle nested graphs recursively
    if child.children.length() > 0 {
      lnode.nested_graph = Some(LGraph::from_elk_node(child, direction))
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

  // NOTE: ELK's hierarchical port processors compute external-port coordinates
  // from the connected inner nodes. For now we approximate that directly when
  // creating the hierarchical port by using the inner node's center.

  fn add_hierarchical_port(
    graph : LGraph,
    container_id : String,
    child_id : String,
    edge_id : String,
    suffix : String,
    port_index : Int,
  ) -> String? {
    // Match ELK layered default behavior:
    // for non-hyperedges, create one hierarchical port per hierarchy-crossing
    // edge at each crossing point.
    match graph.node_map.get(container_id) {
      Some(container) =>
        match container.nested_graph {
          Some(nested) =>
            match nested.get_node(child_id) {
              Some(child) => {
                let port_id = container_id + "|hier|" + edge_id + "|" + suffix
                for p in container.ports {
                  if p.id == port_id {
                    return Some(port_id)
                  }
                }
                let port = LPort::new(port_id)
                port.side = port_side(direction, suffix)
                // Mirror ELK's implicit-port indexing behavior so port ordering
                // processors have a stable input order.
                port.properties.set("elk.port.index", Int(port_index))
                port.properties.set(
                  "diago.layered.hierChildId",
                  String(child_id),
                )
                // Approximate the hierarchical port coordinate by using the
                // nested endpoint center. ELK layered will still reposition
                // FREE ports later during port processing.
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

  fn add_auto_port(
    graph : LGraph,
    node_id : String,
    edge_id : String,
    suffix : String,
    port_index : Int,
  ) -> String? {
    match graph.node_map.get(node_id) {
      Some(node) => {
        let port_id = node_id + "|auto|" + edge_id + "|" + suffix
        for p in node.ports {
          if p.id == port_id {
            return Some(port_id)
          }
        }
        let port = LPort::new(port_id)
        // Match ELK's `LGraphUtil.createPort`: implicit ports default to the
        // direction-dependent output/input sides, not inferred later.
        port.side = port_side(direction, suffix)
        port.properties.set("elk.port.index", Int(port_index))
        port.properties.set("diago.layered.autoPort", Bool(true))
        node.ports.push(port)
        Some(port_id)
      }
      None => None
    }
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
          add_hierarchical_port(
            graph,
            source_id,
            original_source_id,
            elk_edge.id,
            "src",
            i,
          ) {
          Some(pid) => source_port_id = Some(pid)
          None => ()
        }
      }
      if target_id != original_target_id {
        match
          add_hierarchical_port(
            graph,
            target_id,
            original_target_id,
            elk_edge.id,
            "dst",
            i,
          ) {
          Some(pid) => target_port_id = Some(pid)
          None => ()
        }
      }

      // If one endpoint uses a port (hierarchical or explicit), ELK still
      // creates an implicit per-edge port for the other endpoint during import.
      // (Don't try to mirror a ratio/position across endpoints.)
      if source_port_id is None && target_port_id is Some(_) {
        match add_auto_port(graph, source_id, elk_edge.id, "src", i) {
          Some(pid) => source_port_id = Some(pid)
          None => ()
        }
      }
      if target_port_id is None && source_port_id is Some(_) {
        match add_auto_port(graph, target_id, elk_edge.id, "dst", i) {
          Some(pid) => target_port_id = Some(pid)
          None => ()
        }
      }

      // If neither endpoint uses a port, ELK creates implicit per-edge ports for
      // both ends during graph import. These ports participate in port ordering
      // (crossing minimization) and are positioned before edge routing.
      if source_port_id is None && target_port_id is None {
        match add_auto_port(graph, source_id, elk_edge.id, "src", i) {
          Some(pid) => source_port_id = Some(pid)
          None => ()
        }
        match add_auto_port(graph, target_id, elk_edge.id, "dst", i) {
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

  for elk_edge in elk_node.edges {
    match ledge_map.get(elk_edge.id) {
      Some(ledge) => {
        let section = ElkEdgeSection::new(elk_edge.id + "_s0")
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

        let cross = ledge.properties.get_bool_or(
          "diago.layered.crossHierarchy", false,
        )
        if cross {
          // Stitch edge segments across hierarchy boundaries.
          //
          // `elk_layered_main` captures per-container edge segment polylines under:
          //   diago.layered.hierSeg.<edgeId>.src / .dst
          // and stores them on the container ElkNode. We assemble:
          //   [source-inner segment?] + [this-graph segment] + [target-inner segment?]
          // into a single ElkEdge section.
          fn read_seg_points(
            container : ElkNode,
            key : String,
          ) -> Array[ElkPoint]? {
            match container.properties.get_array(key) {
              None => None
              Some(arr) => {
                let pts : Array[ElkPoint] = []
                for v in arr {
                  match v {
                    Point(p) => pts.push(p)
                    _ => ()
                  }
                }
                if pts.length() >= 2 {
                  Some(pts)
                } else {
                  None
                }
              }
            }
          }

          fn offset_points(
            points : Array[ElkPoint],
            dx : Double,
            dy : Double,
          ) -> Array[ElkPoint] {
            let out : Array[ElkPoint] = []
            for p in points {
              out.push(ElkPoint::new(p.x + dx, p.y + dy))
            }
            out
          }

          fn compute_edge_points(
            ledge : LEdge,
            source_node : LNode,
            target_node : LNode,
            direction : LayoutDirection,
          ) -> Array[ElkPoint] {
            let offset = ledge.parallel_offset
            let (raw_start_x, raw_start_y) = anchor_with_port(
              source_node,
              ledge.source_port_id,
              direction,
              true,
            )
            let (raw_end_x, raw_end_y) = anchor_with_port(
              target_node,
              ledge.target_port_id,
              direction,
              false,
            )
            let (start_x, start_y, end_x, end_y) = if direction.is_vertical() {
              (raw_start_x + offset, raw_start_y, raw_end_x + offset, raw_end_y)
            } else if direction.is_horizontal() {
              (raw_start_x, raw_start_y + offset, raw_end_x, raw_end_y + offset)
            } else {
              (raw_start_x + offset, raw_start_y, raw_end_x + offset, raw_end_y)
            }
            let out : Array[ElkPoint] = []
            out.push(ElkPoint::new(start_x, start_y))
            for bp in ledge.bend_points {
              out.push(bp)
            }
            out.push(ElkPoint::new(end_x, end_y))
            out
          }

          let original_source_id = ledge.properties
            .get_string("diago.layered.originalSourceId")
            .unwrap_or(ledge.source_id)
          let original_target_id = ledge.properties
            .get_string("diago.layered.originalTargetId")
            .unwrap_or(ledge.target_id)
          let edge_id = ledge.original_id.unwrap_or(ledge.id)
          let segments : Array[Array[ElkPoint]] = []

          // Optional source-side inner segment (inside source container at this level).
          if original_source_id != ledge.source_id {
            let key = "diago.layered.hierSeg." + edge_id + ".src"
            let (src_container, dx, dy) = find_elk_node_abs(
              elk_node,
              ledge.source_id,
              0.0,
              0.0,
            )
            match src_container {
              Some(c) =>
                match read_seg_points(c, key) {
                  Some(pts) => segments.push(offset_points(pts, dx, dy))
                  None => ()
                }
              None => ()
            }
          }

          // Middle segment routed in this graph (typically between boundary ports).
          match
            (
              self.node_map.get(ledge.source_id),
              self.node_map.get(ledge.target_id),
            ) {
            (Some(src), Some(tgt)) =>
              segments.push(compute_edge_points(ledge, src, tgt, direction))
            _ => ()
          }

          // Optional target-side inner segment (inside target container at this level).
          if original_target_id != ledge.target_id {
            let key = "diago.layered.hierSeg." + edge_id + ".dst"
            let (tgt_container, dx, dy) = find_elk_node_abs(
              elk_node,
              ledge.target_id,
              0.0,
              0.0,
            )
            match tgt_container {
              Some(c) =>
                match read_seg_points(c, key) {
                  Some(pts) => segments.push(offset_points(pts, dx, dy))
                  None => ()
                }
              None => ()
            }
          }
          if segments.length() > 0 {
            // Ported from ELK's CompoundGraphPostprocessor: join bend points, and add a boundary
            // connector bendpoint when segment endpoints don't line up.
            let bends : Array[ElkPoint] = []
            let mut last_point : ElkPoint? = None
            for seg in segments {
              if seg.length() < 2 {
                continue
              }
              let source_point = seg[0]
              let target_point = seg[seg.length() - 1]
              let seg_bends : Array[ElkPoint] = []
              for i = 1; i + 1 < seg.length(); i = i + 1 {
                seg_bends.push(seg[i])
              }
              let next_point = if seg_bends.is_empty() {
                target_point
              } else {
                seg_bends[0]
              }
              match last_point {
                Some(lp) => {
                  let x_diff = Double::abs(lp.x - next_point.x) > TOLERANCE
                  let y_diff = Double::abs(lp.y - next_point.y) > TOLERANCE
                  if x_diff && y_diff {
                    bends.push(source_point)
                  }
                }
                None => ()
              }
              for bp in seg_bends {
                bends.push(bp)
              }
              last_point = Some(
                if seg_bends.is_empty() {
                  source_point
                } else {
                  seg_bends[seg_bends.length() - 1]
                },
              )
            }

            // Flatten to a single section.
            let start = segments[0][0]
            let last_seg = segments[segments.length() - 1]
            let end = last_seg[last_seg.length() - 1]
            section.start_point = start
            section.end_point = end
            section.bend_points.clear()
            for bp in bends {
              section.bend_points.push(bp)
            }
            elk_edge.sections.clear()
            elk_edge.sections.push(section)
            continue
          }
        }

        // Look up source and target nodes by ID
        let source_node = self.node_map.get(ledge.source_id)
        let target_node = self.node_map.get(ledge.target_id)

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
  // ELK's layer list contains no gaps. Normalize the assigned layer indices to
  // a dense 0..N-1 range to avoid empty layers affecting placement.
  let seen : Map[Int, Bool] = {}
  let used : Array[Int] = []
  for node in self.nodes {
    if node.layer < 0 {
      continue
    }
    if !seen.contains(node.layer) {
      seen[node.layer] = true
      used.push(node.layer)
    }
  }
  used.sort_by(fn(a, b) { a - b })
  let remap : Map[Int, Int] = {}
  for i, layer_id in used {
    remap[layer_id] = i
  }
  for node in self.nodes {
    if node.layer < 0 {
      continue
    }
    node.layer = remap.get(node.layer).unwrap_or(node.layer)
  }

  // Create layers
  self.layers.clear()
  for i = 0; i < used.length(); i = i + 1 {
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
