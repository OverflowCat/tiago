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
pub(all) enum LNodeType {
  Normal // Regular node from the original graph
  LongEdgeDummy // Virtual node for long edges spanning multiple layers
  NorthSouthPort // Virtual node for north/south ports
  ExternalPort // Virtual node for external ports
  LabelDummy // Virtual node for edge labels
  BreakPoint // Virtual node for edge breaks
} derive(Show, Eq)

///|
/// A node in the layered graph
pub(all) struct LNode {
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
  properties : @elk.ElkProperties
} derive(Show)

///|
pub fn LNode::new(id : String, node_type : LNodeType) -> LNode {
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
    properties: @elk.ElkProperties::new(),
  }
}

///|
pub fn LNode::from_elk_node(elk_node : @elk.ElkNode) -> LNode {
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
  // Convert ports
  for port in elk_node.ports {
    node.ports.push(LPort::from_elk_port(port))
  }
  node
}

///|
/// Check if this is a dummy node
pub fn LNode::is_dummy(self : LNode) -> Bool {
  match self.node_type {
    Normal => false
    _ => true
  }
}

///|
/// Get the degree of this node (incoming + outgoing edges)
pub fn LNode::degree(self : LNode) -> Int {
  self.incoming_edges.length() + self.outgoing_edges.length()
}

///|
/// Get in-degree
pub fn LNode::in_degree(self : LNode) -> Int {
  self.incoming_edges.length()
}

///|
/// Get out-degree
pub fn LNode::out_degree(self : LNode) -> Int {
  self.outgoing_edges.length()
}

// ============================================================================
// Port Types
// ============================================================================

///|
/// A port in the layered graph
pub(all) struct LPort {
  id : String
  mut original_id : String?
  mut side : @elk.PortSide
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  incoming_edges : Array[LEdge]
  outgoing_edges : Array[LEdge]
  labels : Array[LLabel]
  properties : @elk.ElkProperties
} derive(Show)

///|
pub fn LPort::new(id : String) -> LPort {
  {
    id,
    original_id: None,
    side: @elk.Undefined,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    incoming_edges: [],
    outgoing_edges: [],
    labels: [],
    properties: @elk.ElkProperties::new(),
  }
}

///|
pub fn LPort::from_elk_port(elk_port : @elk.ElkPort) -> LPort {
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
pub(all) struct LLabel {
  id : String
  text : String
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  properties : @elk.ElkProperties
} derive(Show)

///|
pub fn LLabel::new(id : String, text : String) -> LLabel {
  {
    id,
    text,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    properties: @elk.ElkProperties::new(),
  }
}

///|
pub fn LLabel::from_elk_label(elk_label : @elk.ElkLabel) -> LLabel {
  {
    id: elk_label.id,
    text: elk_label.text,
    x: elk_label.x,
    y: elk_label.y,
    width: elk_label.width,
    height: elk_label.height,
    properties: @elk.ElkProperties::new(),
  }
}

// ============================================================================
// Edge Types
// ============================================================================

///|
/// An edge in the layered graph
pub(all) struct LEdge {
  id : String
  mut original_id : String?
  mut source : LNode
  mut target : LNode
  source_port : LPort?
  target_port : LPort?
  labels : Array[LLabel]
  // Edge routing
  bend_points : Array[@elk.ElkPoint]
  // For reversed edges during cycle breaking
  mut reversed : Bool
  // Priority for crossing minimization
  mut priority : Int
  properties : @elk.ElkProperties
} derive(Show)

///|
pub fn LEdge::new(id : String, source : LNode, target : LNode) -> LEdge {
  {
    id,
    original_id: None,
    source,
    target,
    source_port: None,
    target_port: None,
    labels: [],
    bend_points: [],
    reversed: false,
    priority: 0,
    properties: @elk.ElkProperties::new(),
  }
}

///|
/// Reverse this edge (swap source and target)
pub fn LEdge::reverse(self : LEdge) -> Unit {
  let temp = self.source
  self.source = self.target
  self.target = temp
  self.reversed = !self.reversed
}

///|
/// Check if this edge is a self-loop
pub fn LEdge::is_self_loop(self : LEdge) -> Bool {
  self.source.id == self.target.id
}

// ============================================================================
// Layer Types
// ============================================================================

///|
/// A layer in the layered graph
pub(all) struct LLayer {
  index : Int
  nodes : Array[LNode]
} derive(Show)

///|
pub fn LLayer::new(index : Int) -> LLayer {
  { index, nodes: [] }
}

///|
pub fn LLayer::add_node(self : LLayer, node : LNode) -> Unit {
  node.layer = self.index
  node.position = self.nodes.length()
  self.nodes.push(node)
}

// ============================================================================
// Graph Types
// ============================================================================

///|
/// The layered graph - internal representation for the layered algorithm
pub(all) struct LGraph {
  id : String
  nodes : Array[LNode]
  edges : Array[LEdge]
  layers : Array[LLayer]
  // Parent node if this is a nested graph
  parent_node : LNode?
  // Graph properties
  mut width : Double
  mut height : Double
  properties : @elk.ElkProperties
} derive(Show)

///|
pub fn LGraph::new(id : String) -> LGraph {
  {
    id,
    nodes: [],
    edges: [],
    layers: [],
    parent_node: None,
    width: 0.0,
    height: 0.0,
    properties: @elk.ElkProperties::new(),
  }
}

///|
/// Convert an ElkNode (root graph) to an LGraph
pub fn LGraph::from_elk_node(elk_node : @elk.ElkNode) -> LGraph {
  let graph = LGraph::new(elk_node.id)
  graph.width = elk_node.width
  graph.height = elk_node.height
  graph.properties.copy_from(elk_node.properties)

  // Create a map for quick node lookup
  let node_map : Map[String, LNode] = {}

  // Convert all children to LNodes
  for child in elk_node.children {
    let lnode = LNode::from_elk_node(child)
    graph.nodes.push(lnode)
    node_map[child.id] = lnode

    // Handle nested graphs recursively
    if child.children.length() > 0 {
      lnode.nested_graph = Some(LGraph::from_elk_node(child))
    }
  }

  // Convert all edges
  for elk_edge in elk_node.edges {
    // Handle hyperedges - for now, assume simple edges
    if elk_edge.sources.length() > 0 && elk_edge.targets.length() > 0 {
      let source_id = elk_edge.sources[0]
      let target_id = elk_edge.targets[0]
      match (node_map.get(source_id), node_map.get(target_id)) {
        (Some(source), Some(target)) => {
          let ledge = LEdge::new(elk_edge.id, source, target)
          ledge.original_id = Some(elk_edge.id)
          ledge.properties.copy_from(elk_edge.properties)
          // Convert labels
          for label in elk_edge.labels {
            ledge.labels.push(LLabel::from_elk_label(label))
          }
          // Link edge to nodes
          source.outgoing_edges.push(ledge)
          target.incoming_edges.push(ledge)
          graph.edges.push(ledge)
        }
        _ => () // Skip edges with missing endpoints
      }
    }
  }
  graph
}

///|
/// Apply layout results back to an ElkNode
pub fn LGraph::to_elk_node(self : LGraph, elk_node : @elk.ElkNode) -> Unit {
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

  // Apply positions to children
  for child in elk_node.children {
    match lnode_map.get(child.id) {
      Some(lnode) => {
        child.x = lnode.x
        child.y = lnode.y
        child.width = lnode.width
        child.height = lnode.height

        // Apply nested graph if present
        match lnode.nested_graph {
          Some(nested) => nested.to_elk_node(child)
          None => ()
        }
      }
      None => ()
    }
  }

  // Apply edge routes
  let ledge_map : Map[String, LEdge] = {}
  for ledge in self.edges {
    match ledge.original_id {
      Some(id) => ledge_map[id] = ledge
      None => ()
    }
  }
  for elk_edge in elk_node.edges {
    match ledge_map.get(elk_edge.id) {
      Some(ledge) =>
        // Create edge section from bend points
        if ledge.bend_points.length() > 0 || true {
          let section = @elk.ElkEdgeSection::new(elk_edge.id + "_s0")
          // Start point (from source node)
          section.start_point = @elk.ElkPoint::new(
            ledge.source.x + ledge.source.width / 2.0,
            ledge.source.y + ledge.source.height,
          )
          // End point (to target node)
          section.end_point = @elk.ElkPoint::new(
            ledge.target.x + ledge.target.width / 2.0,
            ledge.target.y,
          )
          // Copy bend points
          for bp in ledge.bend_points {
            section.bend_points.push(bp)
          }
          elk_edge.sections.clear()
          elk_edge.sections.push(section)
        }
      None => ()
    }
  }
}

///|
/// Get all edges that span multiple layers (long edges)
pub fn LGraph::get_long_edges(self : LGraph) -> Array[LEdge] {
  let result : Array[LEdge] = []
  for edge in self.edges {
    if edge.source.layer >= 0 &&
      edge.target.layer >= 0 &&
      (edge.target.layer - edge.source.layer).abs() > 1 {
      result.push(edge)
    }
  }
  result
}

///|
/// Get all nodes in a specific layer
pub fn LGraph::get_layer_nodes(
  self : LGraph,
  layer_index : Int,
) -> Array[LNode] {
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
pub fn LGraph::initialize_layers(self : LGraph) -> Unit {
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

  // Update position indices
  for layer in self.layers {
    for i, node in layer.nodes {
      node.position = i
    }
  }
}
