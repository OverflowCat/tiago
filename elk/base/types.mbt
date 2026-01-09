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
/// ELK.js Port for MoonBit - Core Types
/// Port of Eclipse Layout Kernel data model

// ============================================================================
// Core Geometric Types
// ============================================================================

///|
/// A point in 2D space
pub(all) struct ElkPoint {
  x : Double
  y : Double
} derive(Show, Eq)

///|
pub fn ElkPoint::new(x : Double, y : Double) -> ElkPoint {
  { x, y }
}

///|
pub fn ElkPoint::zero() -> ElkPoint {
  { x: 0.0, y: 0.0 }
}

///|
/// A padding/margin specification
pub(all) struct ElkPadding {
  top : Double
  right : Double
  bottom : Double
  left : Double
} derive(Show, Eq)

///|
pub fn ElkPadding::new(
  top : Double,
  right : Double,
  bottom : Double,
  left : Double,
) -> ElkPadding {
  { top, right, bottom, left }
}

///|
pub fn ElkPadding::uniform(value : Double) -> ElkPadding {
  { top: value, right: value, bottom: value, left: value }
}

///|
pub fn ElkPadding::zero() -> ElkPadding {
  { top: 0.0, right: 0.0, bottom: 0.0, left: 0.0 }
}

// ============================================================================
// Port Side Enumeration
// ============================================================================

///|
/// The side of a node where a port is located
pub(all) enum PortSide {
  Undefined
  North
  East
  South
  West
} derive(Show, Eq)

///|
pub fn PortSide::opposite(self : PortSide) -> PortSide {
  match self {
    Undefined => Undefined
    North => South
    South => North
    East => West
    West => East
  }
}

///|
pub fn PortSide::is_vertical(self : PortSide) -> Bool {
  match self {
    North | South => true
    _ => false
  }
}

///|
pub fn PortSide::is_horizontal(self : PortSide) -> Bool {
  match self {
    East | West => true
    _ => false
  }
}

// ============================================================================
// Property System
// ============================================================================

///|
/// Type-safe property values for ELK configuration
pub(all) enum PropertyValue {
  Bool(Bool)
  Int(Int)
  Double(Double)
  String(String)
  Enum(String)
  Point(ElkPoint)
  Padding(ElkPadding)
  Array(Array[PropertyValue])
  Map(Map[String, PropertyValue])
} derive(Show, Eq)

///|
/// Container for layout properties
pub(all) struct ElkProperties {
  values : Map[String, PropertyValue]
} derive(Show, Eq)

///|
pub fn ElkProperties::new() -> ElkProperties {
  { values: {} }
}

///|
pub fn ElkProperties::set(
  self : ElkProperties,
  key : String,
  value : PropertyValue,
) -> Unit {
  self.values[key] = value
}

///|
pub fn ElkProperties::get(self : ElkProperties, key : String) -> PropertyValue? {
  self.values.get(key)
}

///|
pub fn ElkProperties::get_bool(self : ElkProperties, key : String) -> Bool? {
  match self.values.get(key) {
    Some(Bool(v)) => Some(v)
    _ => None
  }
}

///|
pub fn ElkProperties::get_int(self : ElkProperties, key : String) -> Int? {
  match self.values.get(key) {
    Some(Int(v)) => Some(v)
    _ => None
  }
}

///|
pub fn ElkProperties::get_double(self : ElkProperties, key : String) -> Double? {
  match self.values.get(key) {
    Some(Double(v)) => Some(v)
    _ => None
  }
}

///|
pub fn ElkProperties::get_string(self : ElkProperties, key : String) -> String? {
  match self.values.get(key) {
    Some(String(v)) => Some(v)
    Some(Enum(v)) => Some(v)
    _ => None
  }
}

///|
pub fn ElkProperties::get_enum(self : ElkProperties, key : String) -> String? {
  match self.values.get(key) {
    Some(Enum(v)) => Some(v)
    _ => None
  }
}

///|
pub fn ElkProperties::get_point(
  self : ElkProperties,
  key : String,
) -> ElkPoint? {
  match self.values.get(key) {
    Some(Point(v)) => Some(v)
    _ => None
  }
}

///|
pub fn ElkProperties::get_padding(
  self : ElkProperties,
  key : String,
) -> ElkPadding? {
  match self.values.get(key) {
    Some(Padding(v)) => Some(v)
    _ => None
  }
}

///|
pub fn ElkProperties::get_array(
  self : ElkProperties,
  key : String,
) -> Array[PropertyValue]? {
  match self.values.get(key) {
    Some(Array(v)) => Some(v)
    _ => None
  }
}

///|
pub fn ElkProperties::get_map(
  self : ElkProperties,
  key : String,
) -> Map[String, PropertyValue]? {
  match self.values.get(key) {
    Some(Map(v)) => Some(v)
    _ => None
  }
}

///|
pub fn ElkProperties::get_bool_or(
  self : ElkProperties,
  key : String,
  default : Bool,
) -> Bool {
  self.get_bool(key).unwrap_or(default)
}

///|
pub fn ElkProperties::get_int_or(
  self : ElkProperties,
  key : String,
  default : Int,
) -> Int {
  self.get_int(key).unwrap_or(default)
}

///|
pub fn ElkProperties::get_double_or(
  self : ElkProperties,
  key : String,
  default : Double,
) -> Double {
  self.get_double(key).unwrap_or(default)
}

///|
pub fn ElkProperties::get_string_or(
  self : ElkProperties,
  key : String,
  default : String,
) -> String {
  self.get_string(key).unwrap_or(default)
}

///|
pub fn ElkProperties::copy_from(
  self : ElkProperties,
  other : ElkProperties,
) -> Unit {
  for key, value in other.values {
    self.values[key] = value
  }
}

// ============================================================================
// Label
// ============================================================================

///|
/// A text label that can be attached to nodes, edges, or ports
pub(all) struct ElkLabel {
  id : String
  text : String
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  properties : ElkProperties
} derive(Show, Eq)

///|
pub fn ElkLabel::new(id : String, text : String) -> ElkLabel {
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

// ============================================================================
// Port
// ============================================================================

///|
/// A connection point on a node
pub(all) struct ElkPort {
  id : String
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  side : PortSide
  labels : Array[ElkLabel]
  properties : ElkProperties
} derive(Show, Eq)

///|
pub fn ElkPort::new(id : String) -> ElkPort {
  {
    id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side: Undefined,
    labels: [],
    properties: ElkProperties::new(),
  }
}

///|
pub fn ElkPort::with_side(id : String, side : PortSide) -> ElkPort {
  {
    id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    side,
    labels: [],
    properties: ElkProperties::new(),
  }
}

// ============================================================================
// Edge Section (for complex routing)
// ============================================================================

///|
/// A section of an edge route (used for hierarchical edges)
pub(all) struct ElkEdgeSection {
  id : String
  mut start_point : ElkPoint
  mut end_point : ElkPoint
  bend_points : Array[ElkPoint]
  incoming_shape : String?
  outgoing_shape : String?
  incoming_sections : Array[String]
  outgoing_sections : Array[String]
  properties : ElkProperties
} derive(Show, Eq)

///|
pub fn ElkEdgeSection::new(id : String) -> ElkEdgeSection {
  {
    id,
    start_point: ElkPoint::zero(),
    end_point: ElkPoint::zero(),
    bend_points: [],
    incoming_shape: None,
    outgoing_shape: None,
    incoming_sections: [],
    outgoing_sections: [],
    properties: ElkProperties::new(),
  }
}

// ============================================================================
// Edge
// ============================================================================

///|
/// An edge connecting nodes (supports hyperedges with multiple sources/targets)
pub(all) struct ElkEdge {
  id : String
  sources : Array[String]
  targets : Array[String]
  // Optional port IDs for simple edges (one source, one target)
  mut source_port : String?
  mut target_port : String?
  labels : Array[ElkLabel]
  sections : Array[ElkEdgeSection]
  container_id : String?
  properties : ElkProperties
} derive(Show, Eq)

///|
pub fn ElkEdge::new(id : String, source : String, target : String) -> ElkEdge {
  {
    id,
    sources: [source],
    targets: [target],
    source_port: None,
    target_port: None,
    labels: [],
    sections: [],
    container_id: None,
    properties: ElkProperties::new(),
  }
}

///|
pub fn ElkEdge::hyperedge(
  id : String,
  sources : Array[String],
  targets : Array[String],
) -> ElkEdge {
  {
    id,
    sources,
    targets,
    source_port: None,
    target_port: None,
    labels: [],
    sections: [],
    container_id: None,
    properties: ElkProperties::new(),
  }
}

///|
/// Check if this is a simple edge (one source, one target)
pub fn ElkEdge::is_simple(self : ElkEdge) -> Bool {
  self.sources.length() == 1 && self.targets.length() == 1
}

///|
/// Get single source (for simple edges)
pub fn ElkEdge::source(self : ElkEdge) -> String? {
  if self.sources.length() == 1 {
    Some(self.sources[0])
  } else {
    None
  }
}

///|
/// Get single target (for simple edges)
pub fn ElkEdge::target(self : ElkEdge) -> String? {
  if self.targets.length() == 1 {
    Some(self.targets[0])
  } else {
    None
  }
}

///|
/// Get single source port ID (for simple edges)
pub fn ElkEdge::source_port_id(self : ElkEdge) -> String? {
  match self.source_port {
    Some(id) => Some(id)
    None => self.properties.get_string("elk.sourcePort")
  }
}

///|
/// Get single target port ID (for simple edges)
pub fn ElkEdge::target_port_id(self : ElkEdge) -> String? {
  match self.target_port {
    Some(id) => Some(id)
    None => self.properties.get_string("elk.targetPort")
  }
}

// ============================================================================
// Node (the core element, can contain children for hierarchy)
// ============================================================================

///|
/// A node in the ELK graph (can be hierarchical with children)
pub(all) struct ElkNode {
  id : String
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  labels : Array[ElkLabel]
  ports : Array[ElkPort]
  children : Array[ElkNode]
  edges : Array[ElkEdge]
  properties : ElkProperties
} derive(Show, Eq)

///|
pub fn ElkNode::new(id : String) -> ElkNode {
  {
    id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    labels: [],
    ports: [],
    children: [],
    edges: [],
    properties: ElkProperties::new(),
  }
}

///|
pub fn ElkNode::with_size(
  id : String,
  width : Double,
  height : Double,
) -> ElkNode {
  {
    id,
    x: 0.0,
    y: 0.0,
    width,
    height,
    labels: [],
    ports: [],
    children: [],
    edges: [],
    properties: ElkProperties::new(),
  }
}

///|
/// Check if this node is a leaf (no children)
pub fn ElkNode::is_leaf(self : ElkNode) -> Bool {
  self.children.is_empty()
}

///|
/// Check if this node is a compound node (has children)
pub fn ElkNode::is_compound(self : ElkNode) -> Bool {
  !self.children.is_empty()
}

///|
/// Add a child node
pub fn ElkNode::add_child(self : ElkNode, child : ElkNode) -> Unit {
  self.children.push(child)
}

///|
/// Add an edge contained in this node
pub fn ElkNode::add_edge(self : ElkNode, edge : ElkEdge) -> Unit {
  self.edges.push(edge)
}

///|
/// Add a port to this node
pub fn ElkNode::add_port(self : ElkNode, port : ElkPort) -> Unit {
  self.ports.push(port)
}

///|
/// Add a label to this node
pub fn ElkNode::add_label(self : ElkNode, label : ElkLabel) -> Unit {
  self.labels.push(label)
}

///|
/// Find a child node by ID (non-recursive)
pub fn ElkNode::find_child(self : ElkNode, id : String) -> ElkNode? {
  for child in self.children {
    if child.id == id {
      return Some(child)
    }
  }
  None
}

///|
/// Find a node by ID (recursive search through hierarchy)
pub fn ElkNode::find_node(self : ElkNode, id : String) -> ElkNode? {
  if self.id == id {
    return Some(self)
  }
  for child in self.children {
    match child.find_node(id) {
      Some(n) => return Some(n)
      None => continue
    }
  }
  None
}

///|
/// Find a port by ID (recursive search)
pub fn ElkNode::find_port(self : ElkNode, id : String) -> ElkPort? {
  for port in self.ports {
    if port.id == id {
      return Some(port)
    }
  }
  for child in self.children {
    match child.find_port(id) {
      Some(p) => return Some(p)
      None => continue
    }
  }
  None
}

///|
/// Get all nodes in the graph (flattened)
pub fn ElkNode::all_nodes(self : ElkNode) -> Array[ElkNode] {
  let result : Array[ElkNode] = [self]
  for child in self.children {
    result.append(child.all_nodes())
  }
  result
}

///|
/// Get all edges in the graph (recursive)
pub fn ElkNode::all_edges(self : ElkNode) -> Array[ElkEdge] {
  let result : Array[ElkEdge] = []
  result.append(self.edges)
  for child in self.children {
    result.append(child.all_edges())
  }
  result
}

///|
/// Calculate bounding box considering all children
pub fn ElkNode::calculate_bounds(self : ElkNode) -> (Double, Double) {
  let mut max_x = self.width
  let mut max_y = self.height
  for child in self.children {
    let child_right = child.x + child.width
    let child_bottom = child.y + child.height
    if child_right > max_x {
      max_x = child_right
    }
    if child_bottom > max_y {
      max_y = child_bottom
    }
  }
  (max_x, max_y)
}

// ============================================================================
// Graph Utilities
// ============================================================================

///|
/// Create a root node (representing the entire graph)
pub fn create_graph(id : String) -> ElkNode {
  ElkNode::new(id)
}

///|
/// Create a simple edge between two nodes
pub fn create_edge(id : String, source : String, target : String) -> ElkEdge {
  ElkEdge::new(id, source, target)
}

///|
/// Create a node with a label
pub fn create_labeled_node(id : String, label : String) -> ElkNode {
  let node = ElkNode::new(id)
  node.add_label(ElkLabel::new(id + "_label", label))
  node
}
