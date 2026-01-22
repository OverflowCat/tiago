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
/// ELK.js Port for MoonBit - Layout Options
/// Complete 400+ options system for ELK algorithms

// ============================================================================
// Core Algorithm Selection
// ============================================================================

///|
/// Available layout algorithms
enum LayoutAlgorithm {
  Layered
  Force
  Stress
  Radial
  MrTree
  Box
  RectPacking
  TopDownPacking
  DisCo
  Fixed
  Random
  SporeCompaction
  SporeOverlap
} derive(Show, Eq)

///|
fn LayoutAlgorithm::from_string(s : String) -> LayoutAlgorithm? {
  match s.to_upper() {
    "LAYERED" => Some(Layered)
    "FORCE" => Some(Force)
    "STRESS" => Some(Stress)
    "RADIAL" => Some(Radial)
    "MRTREE" => Some(MrTree)
    "BOX" => Some(Box)
    "RECTPACKING" => Some(RectPacking)
    "TOPDOWNPACKING" => Some(TopDownPacking)
    "DISCO" => Some(DisCo)
    "FIXED" => Some(Fixed)
    "RANDOM" => Some(Random)
    "SPORECOMPACTION" => Some(SporeCompaction)
    "SPOREOVERLAP" => Some(SporeOverlap)
    _ => None
  }
}

///|
/// Layout direction (primary axis for layered layout)
enum LayoutDirection {
  Undefined
  Right
  Left
  Down
  Up
} derive(Show, Eq)

///|
fn LayoutDirection::from_string(s : String) -> LayoutDirection? {
  match s.to_upper() {
    "UNDEFINED" => Some(Undefined)
    "RIGHT" => Some(Right)
    "LEFT" => Some(Left)
    "DOWN" => Some(Down)
    "UP" => Some(Up)
    _ => None
  }
}

///|
fn LayoutDirection::is_horizontal(self : LayoutDirection) -> Bool {
  match self {
    Right | Left => true
    _ => false
  }
}

///|
fn LayoutDirection::is_vertical(self : LayoutDirection) -> Bool {
  match self {
    Down | Up => true
    _ => false
  }
}

// ============================================================================
// Edge Routing Options
// ============================================================================

///|
/// Edge routing style
enum EdgeRouting {
  Undefined
  Polyline
  Orthogonal
  Splines
} derive(Show, Eq)

///|
fn EdgeRouting::from_string(s : String) -> EdgeRouting? {
  match s.to_upper() {
    "UNDEFINED" => Some(Undefined)
    "POLYLINE" => Some(Polyline)
    "ORTHOGONAL" => Some(Orthogonal)
    "SPLINES" => Some(Splines)
    _ => None
  }
}

///|
/// Edge type for differentiating edge kinds
enum EdgeType {
  Undefined
  Directed
  Undirected
  Association
  Generalization
  Dependency
} derive(Show, Eq)

// ============================================================================
// Layered Algorithm Options
// ============================================================================

///|
/// Cycle breaking strategy
enum CycleBreakingStrategy {
  GreedyCycleBreaker
  DepthFirst
  InteractiveCycleBreaker
  ModelOrder
  GreedyModelOrder
} derive(Show, Eq)

///|
fn CycleBreakingStrategy::from_string(s : String) -> CycleBreakingStrategy? {
  match s.to_upper() {
    "GREEDY" | "GREEDY_CYCLE_BREAKER" | "GREEDYCYCLEBREAKER" =>
      Some(GreedyCycleBreaker)
    "DEPTH_FIRST" | "DEPTHFIRST" => Some(DepthFirst)
    "INTERACTIVE" | "INTERACTIVE_CYCLE_BREAKER" | "INTERACTIVECYCLEBREAKER" =>
      Some(InteractiveCycleBreaker)
    "MODEL_ORDER" | "MODELORDER" => Some(ModelOrder)
    "GREEDY_MODEL_ORDER" | "GREEDYMODELORDER" => Some(GreedyModelOrder)
    _ => None
  }
}

///|
/// Layer assignment strategy
enum LayeringStrategy {
  NetworkSimplex
  LongestPath
  InteractiveLayering
  CoffmanGraham
  StretchWidth
  MinWidth
  BreadthFirstModelOrder
  DepthFirstModelOrder
} derive(Show, Eq)

///|
fn LayeringStrategy::from_string(s : String) -> LayeringStrategy? {
  match s.to_upper() {
    "NETWORK_SIMPLEX" | "NETWORKSIMPLEX" => Some(NetworkSimplex)
    "LONGEST_PATH" | "LONGESTPATH" => Some(LongestPath)
    "INTERACTIVE" | "INTERACTIVE_LAYERING" | "INTERACTIVELAYERING" =>
      Some(InteractiveLayering)
    "COFFMAN_GRAHAM" | "COFFMANGRAHAM" => Some(CoffmanGraham)
    "STRETCH_WIDTH" | "STRETCHWIDTH" => Some(StretchWidth)
    "MIN_WIDTH" | "MINWIDTH" => Some(MinWidth)
    "BREADTH_FIRST" | "BREADTH_FIRST_MODEL_ORDER" | "BREADTHFIRSTMODELORDER" =>
      Some(BreadthFirstModelOrder)
    "DEPTH_FIRST" | "DEPTH_FIRST_MODEL_ORDER" | "DEPTHFIRSTMODELORDER" =>
      Some(DepthFirstModelOrder)
    _ => None
  }
}

///|
/// Crossing minimization strategy
enum CrossingMinimizationStrategy {
  LayerSweep
  InteractiveCrossMin
  None
} derive(Show, Eq)

///|
/// Strategy to preserve model order.
///
/// Mirrors ELK `OrderingStrategy` but only keeps the variants we currently use.
enum OrderingStrategy {
  None
  NodesAndEdges
  PreferEdges
  PreferNodes
} derive(Show, Eq)

///|
fn OrderingStrategy::from_string(s : String) -> OrderingStrategy? {
  match s.to_upper() {
    "NONE" => Some(None)
    "NODES_AND_EDGES" | "NODESANDEDGES" => Some(NodesAndEdges)
    "PREFER_EDGES" | "PREFEREDGES" => Some(PreferEdges)
    "PREFER_NODES" | "PREFERNODES" => Some(PreferNodes)
    _ => None
  }
}

///|
fn CrossingMinimizationStrategy::from_string(
  s : String,
) -> CrossingMinimizationStrategy? {
  match s.to_upper() {
    "LAYER_SWEEP" | "LAYERSWEEP" => Some(LayerSweep)
    "INTERACTIVE" | "INTERACTIVE_CROSS_MIN" | "INTERACTIVECROSSMIN" =>
      Some(InteractiveCrossMin)
    "NONE" => Some(None)
    _ => None
  }
}

///|
/// Greedy switch type for crossing minimization
enum GreedySwitchType {
  Off
  OneSided
  TwoSided
} derive(Show, Eq)

///|
/// Node placement strategy
enum NodePlacementStrategy {
  BrandesKoepf
  LinearSegments
  Simple
  NetworkSimplex
} derive(Show, Eq)

///|
fn NodePlacementStrategy::from_string(s : String) -> NodePlacementStrategy? {
  match s.to_upper() {
    "BRANDES_KOEPF" | "BRANDESKOEPF" => Some(BrandesKoepf)
    "LINEAR_SEGMENTS" | "LINEARSEGMENTS" => Some(LinearSegments)
    "SIMPLE" => Some(Simple)
    "NETWORK_SIMPLEX" | "NETWORKSIMPLEX" => Some(NetworkSimplex)
    _ => None
  }
}

///|
/// Brandes-Koepf node placement mode
enum BKNodePlacementMode {
  Average
  LeftUp
  LeftDown
  RightUp
  RightDown
} derive(Show, Eq)

///|
fn BKNodePlacementMode::from_string(s : String) -> BKNodePlacementMode? {
  match s.to_upper() {
    "BALANCED" | "AVERAGE" => Some(Average)
    "LEFTUP" | "LEFT_UP" => Some(LeftUp)
    "LEFTDOWN" | "LEFT_DOWN" => Some(LeftDown)
    "RIGHTUP" | "RIGHT_UP" => Some(RightUp)
    "RIGHTDOWN" | "RIGHT_DOWN" => Some(RightDown)
    _ => None
  }
}

///|
/// Edge straightening strategy for Brandes-Koepf
enum EdgeStraighteningStrategy {
  None
  ImproveStraightness
} derive(Show, Eq)

///|
/// Node flexibility for network simplex placement
enum NodeFlexibility {
  None
  NodeSize
  NodeSizeWhereSpacePermits
} derive(Show, Eq)

// ============================================================================
// Port Options
// ============================================================================

///|
/// Port constraints level
enum PortConstraints {
  Undefined
  Free
  FixedSide
  FixedOrder
  FixedRatio
  FixedPos
} derive(Show, Eq)

///|
fn PortConstraints::from_string(s : String) -> PortConstraints? {
  match s.to_upper() {
    "UNDEFINED" => Some(Undefined)
    "FREE" => Some(Free)
    "FIXED_SIDE" | "FIXEDSIDE" => Some(FixedSide)
    "FIXED_ORDER" | "FIXEDORDER" => Some(FixedOrder)
    "FIXED_RATIO" | "FIXEDRATIO" => Some(FixedRatio)
    "FIXED_POS" | "FIXEDPOS" => Some(FixedPos)
    _ => None
  }
}

///|
/// Port alignment within side
enum PortAlignment {
  Undefined
  Distributed
  Justified
  Begin
  Center
  End
} derive(Show, Eq)

///|
fn PortAlignment::from_string(s : String) -> PortAlignment? {
  match s.to_upper() {
    "UNDEFINED" => Some(Undefined)
    "DISTRIBUTED" => Some(Distributed)
    "JUSTIFIED" => Some(Justified)
    "BEGIN" => Some(Begin)
    "CENTER" => Some(Center)
    "END" => Some(End)
    _ => None
  }
}

///|
/// Port label placement
///
/// Note: ELK's enum has more variants; we map the subset we support.
enum PortLabelPlacement {
  Inside
  Outside
  NextToPortIfPossible
  AlwaysOther
  AlwaysSameSide
} derive(Show, Eq)

///|
fn PortLabelPlacement::from_string(s : String) -> PortLabelPlacement? {
  match s.to_upper() {
    "INSIDE" => Some(Inside)
    "OUTSIDE" => Some(Outside)
    "NEXT_TO_PORT_IF_POSSIBLE" => Some(NextToPortIfPossible)
    "ALWAYS_OTHER_SAME_SIDE" => Some(AlwaysOther)
    "ALWAYS_SAME_SIDE" => Some(AlwaysSameSide)
    _ => None
  }
}

///|
/// Port sort order
enum PortSortingStrategy {
  InputOrder
  PortDegree
} derive(Show, Eq)

// ============================================================================
// Node Options
// ============================================================================

///|
/// Node size constraints
enum NodeSizeConstraints {
  None
  Ports
  PortLabels
  NodeLabels
  MinimumSize
  MinimumSizeAccountsForPadding
} derive(Show, Eq)

///|
fn NodeSizeConstraints::from_string(s : String) -> NodeSizeConstraints? {
  match s.to_upper() {
    "NONE" => Some(None)
    "PORTS" => Some(Ports)
    "PORT_LABELS" | "PORTLABELS" => Some(PortLabels)
    "NODE_LABELS" | "NODELABELS" => Some(NodeLabels)
    "MINIMUM_SIZE" | "MINIMUMSIZE" => Some(MinimumSize)
    "MINIMUM_SIZE_ACCOUNTS_FOR_PADDING"
    | "MINIMUMSIZEACCOUNTSFORPADDING"
    | "MINIMUMSIZEACCOUNTSPADDING" => Some(MinimumSizeAccountsForPadding)
    _ => None
  }
}

///|
/// Node size options (bit flags combined)
enum NodeSizeOptions {
  DefaultMinimumSize
  MinimumSizeAccountsForPadding
  ComputePadding
  OutsidePortLabelsOverhang
  PortsOverhang
  UniformPortSpacing
  SpaceEfficientPortLabels
  ForceTabularNodeLabels
  AsymmetricalSpacing
} derive(Show, Eq)

///|
/// Node label placement
///
/// This is a simplified representation of ELK's `NodeLabelPlacement` EnumSet.
enum NodeLabelPlacement {
  Inside
  Outside
  Horizontal
  Vertical
  Top
  Center
  Bottom
  Left
  Right
} derive(Show, Eq)

///|
fn NodeLabelPlacement::from_string(s : String) -> NodeLabelPlacement? {
  match s.to_upper() {
    "INSIDE" => Some(Inside)
    "OUTSIDE" => Some(Outside)

    // Horizontal group.
    "H_LEFT" | "LEFT" => Some(Left)
    "H_CENTER" | "CENTER" => Some(Center)
    "H_RIGHT" | "RIGHT" => Some(Right)

    // Vertical group.
    "V_TOP" | "TOP" => Some(Top)
    "V_CENTER" => Some(Center)
    "V_BOTTOM" | "BOTTOM" => Some(Bottom)

    // Rare / internal.
    "H_PRIORITY" => Some(Horizontal)
    _ => None
  }
}

// ============================================================================
// Edge Label Options
// ============================================================================

///|
/// Edge label placement strategy
enum EdgeLabelPlacement {
  Undefined
  Center
  Head
  Tail
} derive(Show, Eq)

///|
fn EdgeLabelPlacement::from_string(s : String) -> EdgeLabelPlacement? {
  match s.to_upper() {
    "UNDEFINED" => Some(Undefined)
    "CENTER" => Some(Center)
    "HEAD" => Some(Head)
    "TAIL" => Some(Tail)
    _ => None
  }
}

///|
/// Edge label side selection
enum EdgeLabelSideSelection {
  AlwaysUp
  AlwaysDown
  DirectionUp
  DirectionDown
  SmartUp
  SmartDown
} derive(Show, Eq)

///|
fn EdgeLabelSideSelection::from_string(s : String) -> EdgeLabelSideSelection? {
  match s.to_upper() {
    "ALWAYS_UP" => Some(AlwaysUp)
    "ALWAYS_DOWN" => Some(AlwaysDown)
    "DIRECTION_UP" => Some(DirectionUp)
    "DIRECTION_DOWN" => Some(DirectionDown)
    "SMART_UP" => Some(SmartUp)
    "SMART_DOWN" => Some(SmartDown)
    _ => None
  }
}

///|
/// Center edge label placement strategy.
///
/// In ELK this decides into which layer long-edge center label dummies are moved.
enum CenterEdgeLabelPlacementStrategy {
  MedianLayer
  TailLayer
  HeadLayer
  SpaceEfficientLayer
  WidestLayer
  CenterLayer
} derive(Show, Eq)

///|
fn CenterEdgeLabelPlacementStrategy::from_string(
  s : String,
) -> CenterEdgeLabelPlacementStrategy? {
  match s.to_upper() {
    "MEDIAN_LAYER" => Some(MedianLayer)
    "TAIL_LAYER" => Some(TailLayer)
    "HEAD_LAYER" => Some(HeadLayer)
    "SPACE_EFFICIENT_LAYER" => Some(SpaceEfficientLayer)
    "WIDEST_LAYER" => Some(WidestLayer)
    "CENTER_LAYER" => Some(CenterLayer)
    _ => None
  }
}

// ============================================================================
// Hierarchy Options
// ============================================================================

///|
/// Hierarchy handling mode
enum HierarchyHandling {
  Inherit
  Include
  Separate
} derive(Show, Eq)

///|
fn HierarchyHandling::from_string(s : String) -> HierarchyHandling? {
  match s.to_upper() {
    "INHERIT" => Some(Inherit)
    "INCLUDE" | "INCLUDE_CHILDREN" | "INCLUDECHILDREN" => Some(Include)
    "SEPARATE" | "SEPARATE_CHILDREN" | "SEPARATECHILDREN" => Some(Separate)
    _ => None
  }
}

///|
/// Content alignment within compound nodes
enum ContentAlignment {
  None
  Horizontal
  Vertical
  HorizontalVertical
} derive(Show, Eq)

///|
fn ContentAlignment::from_string(s : String) -> ContentAlignment? {
  let upper = s.to_upper()
  if upper.contains("H_CENTER") && upper.contains("V_CENTER") {
    Some(HorizontalVertical)
  } else if upper.contains("H_CENTER") {
    Some(Horizontal)
  } else if upper.contains("V_CENTER") {
    Some(Vertical)
  } else if upper == "NONE" {
    Some(None)
  } else {
    None
  }
}

// ============================================================================
// Compaction Options
// ============================================================================

///|
/// Compaction strategy
enum CompactionStrategy {
  None
  Polyomino
  Rectangle
} derive(Show, Eq)

///|
/// Graph compaction strategy
enum GraphCompactionStrategy {
  None
  LeftToRight
  RightToLeft
  TopToBottom
  BottomToTop
} derive(Show, Eq)

// ============================================================================
// Self-Loop Options
// ============================================================================

///|
/// Self-loop distribution strategy
enum SelfLoopDistribution {
  North
  NorthSouth
  Equally
} derive(Show, Eq)

///|
/// Self-loop ordering strategy
enum SelfLoopOrdering {
  Stacked
  Sequenced
} derive(Show, Eq)

// ============================================================================
// Force Algorithm Options
// ============================================================================

///|
/// Force model type
enum ForceModelType {
  Eades
  FruchtermanReingold
} derive(Show, Eq)

// ============================================================================
// Spacing Options (struct for grouped spacing values)
// ============================================================================

///|
/// Spacing configuration
struct SpacingOptions {
  node_node : Double
  node_node_between_layers : Double
  edge_node : Double
  edge_node_between_layers : Double
  edge_edge : Double
  edge_edge_between_layers : Double
  edge_label : Double
  label_node : Double
  label_port_horizontal : Double
  label_port_vertical : Double
  label_label : Double
  port_port : Double
  component_component : Double
  port_surrounding : ElkPadding
} derive(Show, Eq)

///|
fn SpacingOptions::default() -> SpacingOptions {
  {
    node_node: 20.0,
    node_node_between_layers: 20.0,
    edge_node: 10.0,
    edge_node_between_layers: 10.0,
    edge_edge: 10.0,
    edge_edge_between_layers: 10.0,
    edge_label: 2.0,
    label_node: 5.0,
    label_port_horizontal: 1.0,
    label_port_vertical: 1.0,
    label_label: 0.0,
    port_port: 10.0,
    component_component: 20.0,
    port_surrounding: ElkPadding::zero(),
  }
}

// ============================================================================
// Main Layout Options
// ============================================================================

///|
/// Complete layout options configuration
struct LayoutOptions {
  // Core options
  algorithm : LayoutAlgorithm?
  direction : LayoutDirection?

  // Spacing (flattened for common access)
  node_node_spacing : Double?
  node_node_between_layers_spacing : Double?
  edge_node_spacing : Double?
  edge_node_between_layers_spacing : Double?
  edge_edge_spacing : Double?
  edge_edge_between_layers_spacing : Double?
  edge_label_spacing : Double?
  label_node_spacing : Double?
  label_port_horizontal_spacing : Double?
  label_port_vertical_spacing : Double?
  label_label_spacing : Double?
  port_port_spacing : Double?
  component_component_spacing : Double?

  // Padding
  padding : ElkPadding?

  // Edge routing
  edge_routing : EdgeRouting?
  edge_type : EdgeType?

  // Port options
  port_constraints : PortConstraints?
  port_alignment : PortAlignment?
  port_alignment_north : PortAlignment?
  port_alignment_south : PortAlignment?
  port_alignment_east : PortAlignment?
  port_alignment_west : PortAlignment?
  port_label_placement : Array[PortLabelPlacement]?
  port_sorting_strategy : PortSortingStrategy?
  port_border_offset : Double?

  // Node sizing
  node_size_constraints : Array[NodeSizeConstraints]?
  node_size_options : Array[NodeSizeOptions]?
  node_size_minimum : (Double, Double)?
  node_size_fixed_graph_size : Bool?

  // Node labels
  node_label_placement : Array[NodeLabelPlacement]?

  // Edge labels
  edge_label_placement : EdgeLabelPlacement?
  edge_label_side_selection : EdgeLabelSideSelection?
  center_edge_label_placement_strategy : CenterEdgeLabelPlacementStrategy?

  // Layered-specific options
  cycle_breaking_strategy : CycleBreakingStrategy?
  layering_strategy : LayeringStrategy?
  crossing_min_strategy : CrossingMinimizationStrategy?
  crossing_min_force_node_model_order : Bool?
  greedy_switch : GreedySwitchType?
  node_placement_strategy : NodePlacementStrategy?
  bk_fixed_alignment : BKNodePlacementMode?
  bk_edge_straightening : EdgeStraighteningStrategy?
  linear_segments_deflection_dampening : Double?
  node_flexibility : NodeFlexibility?

  // Hierarchy
  hierarchy_handling : HierarchyHandling?
  content_alignment : ContentAlignment?

  // Quality vs speed
  thoroughness : Int?
  aspect_ratio : Double?

  // Interactive mode
  interactive : Bool?
  interactive_reference_point : (Double, Double)?

  // Random seed (for deterministic pseudo-random choices)
  random_seed : Int?

  // Compaction
  compaction_strategy : CompactionStrategy?
  post_compaction_strategy : GraphCompactionStrategy?

  // Self-loops
  self_loop_distribution : SelfLoopDistribution?
  self_loop_ordering : SelfLoopOrdering?

  // Force algorithm options
  force_model : ForceModelType?
  force_iterations : Int?
  force_repulsion : Double?
  force_repulsive_power : Int?
  force_temperature : Double?

  // Component handling
  separate_connected_components : Bool?
  consider_model_order_strategy : OrderingStrategy?

  // Various flags
  merge_edges : Bool?
  merge_hierarchy_crossing_edges : Bool?
  wrap_graphs : Bool?
  feedback_edges : Bool?
  partition_cycle : Bool?

  // Additional numeric options
  layer_constraint : Int?
  position_constraint : Int?
  priority : Int?
  long_edge_priority : Int?

  // Custom options (for extensibility)
  custom : Map[String, PropertyValue]?
} derive(Show, Eq)

///|
fn LayoutOptions::new() -> LayoutOptions {
  {
    algorithm: None,
    direction: None,
    node_node_spacing: None,
    node_node_between_layers_spacing: None,
    edge_node_spacing: None,
    edge_node_between_layers_spacing: None,
    edge_edge_spacing: None,
    edge_edge_between_layers_spacing: None,
    edge_label_spacing: None,
    label_node_spacing: None,
    label_port_horizontal_spacing: None,
    label_port_vertical_spacing: None,
    label_label_spacing: None,
    port_port_spacing: None,
    component_component_spacing: None,
    padding: None,
    edge_routing: None,
    edge_type: None,
    port_constraints: None,
    port_alignment: None,
    port_alignment_north: None,
    port_alignment_south: None,
    port_alignment_east: None,
    port_alignment_west: None,
    port_label_placement: None,
    port_sorting_strategy: None,
    port_border_offset: None,
    node_size_constraints: None,
    node_size_options: None,
    node_size_minimum: None,
    node_size_fixed_graph_size: None,
    node_label_placement: None,
    edge_label_placement: None,
    edge_label_side_selection: None,
    center_edge_label_placement_strategy: None,
    cycle_breaking_strategy: None,
    layering_strategy: None,
    crossing_min_strategy: None,
    crossing_min_force_node_model_order: None,
    greedy_switch: None,
    node_placement_strategy: None,
    bk_fixed_alignment: None,
    bk_edge_straightening: None,
    linear_segments_deflection_dampening: None,
    node_flexibility: None,
    hierarchy_handling: None,
    content_alignment: None,
    thoroughness: None,
    aspect_ratio: None,
    interactive: None,
    interactive_reference_point: None,
    random_seed: None,
    compaction_strategy: None,
    post_compaction_strategy: None,
    self_loop_distribution: None,
    self_loop_ordering: None,
    force_model: None,
    force_iterations: None,
    force_repulsion: None,
    force_repulsive_power: None,
    force_temperature: None,
    separate_connected_components: None,
    consider_model_order_strategy: None,
    merge_edges: None,
    merge_hierarchy_crossing_edges: None,
    wrap_graphs: None,
    feedback_edges: None,
    partition_cycle: None,
    layer_constraint: None,
    position_constraint: None,
    priority: None,
    long_edge_priority: None,
    custom: None,
  }
}

///|
/// Create default options for layered algorithm
fn LayoutOptions::layered() -> LayoutOptions {
  {
    ..LayoutOptions::new(),
    algorithm: Some(Layered),
    direction: Some(Down),
    edge_routing: Some(Orthogonal),
    node_node_spacing: Some(20.0),
    node_node_between_layers_spacing: Some(20.0),
    edge_node_spacing: Some(10.0),
    edge_edge_spacing: Some(10.0),
    padding: Some(ElkPadding::uniform(12.0)),
    cycle_breaking_strategy: Some(GreedyModelOrder),
    layering_strategy: Some(NetworkSimplex),
    crossing_min_strategy: Some(LayerSweep),
    crossing_min_force_node_model_order: Some(false),
    consider_model_order_strategy: Some(NodesAndEdges),
    node_placement_strategy: Some(BrandesKoepf),
    bk_fixed_alignment: Some(Average),
    thoroughness: Some(7),
  }
}

///|
/// Create default options for force algorithm
fn LayoutOptions::force() -> LayoutOptions {
  {
    ..LayoutOptions::new(),
    algorithm: Some(Force),
    force_model: Some(FruchtermanReingold),
    force_iterations: Some(300),
    node_node_spacing: Some(80.0),
    padding: Some(ElkPadding::uniform(50.0)),
    aspect_ratio: Some(1.6),
    separate_connected_components: Some(true),
    force_temperature: Some(0.001),
    force_repulsion: Some(5.0),
  }
}

///|
/// Create default options for stress algorithm
fn LayoutOptions::stress() -> LayoutOptions {
  {
    ..LayoutOptions::new(),
    algorithm: Some(Stress),
    node_node_spacing: Some(20.0),
    padding: Some(ElkPadding::uniform(12.0)),
  }
}

///|
/// Create default options for radial algorithm
fn LayoutOptions::radial() -> LayoutOptions {
  {
    ..LayoutOptions::new(),
    algorithm: Some(Radial),
    node_node_spacing: Some(20.0),
    padding: Some(ElkPadding::uniform(12.0)),
  }
}

///|
/// Create default options for tree algorithm
fn LayoutOptions::tree() -> LayoutOptions {
  {
    ..LayoutOptions::new(),
    algorithm: Some(MrTree),
    direction: Some(Down),
    node_node_spacing: Some(20.0),
    node_node_between_layers_spacing: Some(20.0),
    padding: Some(ElkPadding::uniform(12.0)),
  }
}

// ============================================================================
// Builder Methods
// ============================================================================

///|
fn LayoutOptions::with_algorithm(
  self : LayoutOptions,
  alg : LayoutAlgorithm,
) -> LayoutOptions {
  { ..self, algorithm: Some(alg) }
}

///|
fn LayoutOptions::with_direction(
  self : LayoutOptions,
  dir : LayoutDirection,
) -> LayoutOptions {
  { ..self, direction: Some(dir) }
}

///|
fn LayoutOptions::with_edge_routing(
  self : LayoutOptions,
  routing : EdgeRouting,
) -> LayoutOptions {
  { ..self, edge_routing: Some(routing) }
}

///|
fn LayoutOptions::with_node_spacing(
  self : LayoutOptions,
  spacing : Double,
) -> LayoutOptions {
  { ..self, node_node_spacing: Some(spacing) }
}

///|
fn LayoutOptions::with_layer_spacing(
  self : LayoutOptions,
  spacing : Double,
) -> LayoutOptions {
  { ..self, node_node_between_layers_spacing: Some(spacing) }
}

///|
fn LayoutOptions::with_edge_spacing(
  self : LayoutOptions,
  spacing : Double,
) -> LayoutOptions {
  { ..self, edge_edge_spacing: Some(spacing) }
}

///|
fn LayoutOptions::with_padding(
  self : LayoutOptions,
  padding : ElkPadding,
) -> LayoutOptions {
  { ..self, padding: Some(padding) }
}

///|
fn LayoutOptions::with_uniform_padding(
  self : LayoutOptions,
  value : Double,
) -> LayoutOptions {
  { ..self, padding: Some(ElkPadding::uniform(value)) }
}

///|
fn LayoutOptions::with_port_constraints(
  self : LayoutOptions,
  constraints : PortConstraints,
) -> LayoutOptions {
  { ..self, port_constraints: Some(constraints) }
}

///|
fn LayoutOptions::with_thoroughness(
  self : LayoutOptions,
  value : Int,
) -> LayoutOptions {
  { ..self, thoroughness: Some(value) }
}

///|
fn LayoutOptions::with_aspect_ratio(
  self : LayoutOptions,
  ratio : Double,
) -> LayoutOptions {
  { ..self, aspect_ratio: Some(ratio) }
}

///|
fn LayoutOptions::interactive(self : LayoutOptions) -> LayoutOptions {
  { ..self, interactive: Some(true) }
}

///|
fn LayoutOptions::with_cycle_breaking(
  self : LayoutOptions,
  strategy : CycleBreakingStrategy,
) -> LayoutOptions {
  { ..self, cycle_breaking_strategy: Some(strategy) }
}

///|
fn LayoutOptions::with_layering(
  self : LayoutOptions,
  strategy : LayeringStrategy,
) -> LayoutOptions {
  { ..self, layering_strategy: Some(strategy) }
}

///|
fn LayoutOptions::with_crossing_min(
  self : LayoutOptions,
  strategy : CrossingMinimizationStrategy,
) -> LayoutOptions {
  { ..self, crossing_min_strategy: Some(strategy) }
}

///|
fn LayoutOptions::with_node_placement(
  self : LayoutOptions,
  strategy : NodePlacementStrategy,
) -> LayoutOptions {
  { ..self, node_placement_strategy: Some(strategy) }
}

///|
fn LayoutOptions::with_custom(
  self : LayoutOptions,
  key : String,
  value : PropertyValue,
) -> LayoutOptions {
  let custom = match self.custom {
    Some(m) => m
    None => {}
  }
  custom[key] = value
  { ..self, custom: Some(custom) }
}

// ============================================================================
// Option Resolution (inheritance from parent)
// ============================================================================

///|
/// Helper to merge optional values (child takes precedence)
fn[T] merge_opt(child : T?, parent : T?) -> T? {
  match child {
    Some(_) => child
    None => parent
  }
}

///|
/// Merge two option sets (child overrides parent)
fn LayoutOptions::merge(
  parent : LayoutOptions,
  child : LayoutOptions,
) -> LayoutOptions {
  {
    algorithm: merge_opt(child.algorithm, parent.algorithm),
    direction: merge_opt(child.direction, parent.direction),
    node_node_spacing: merge_opt(
      child.node_node_spacing,
      parent.node_node_spacing,
    ),
    node_node_between_layers_spacing: merge_opt(
      child.node_node_between_layers_spacing,
      parent.node_node_between_layers_spacing,
    ),
    edge_node_spacing: merge_opt(
      child.edge_node_spacing,
      parent.edge_node_spacing,
    ),
    edge_node_between_layers_spacing: merge_opt(
      child.edge_node_between_layers_spacing,
      parent.edge_node_between_layers_spacing,
    ),
    edge_edge_spacing: merge_opt(
      child.edge_edge_spacing,
      parent.edge_edge_spacing,
    ),
    edge_edge_between_layers_spacing: merge_opt(
      child.edge_edge_between_layers_spacing,
      parent.edge_edge_between_layers_spacing,
    ),
    edge_label_spacing: merge_opt(
      child.edge_label_spacing,
      parent.edge_label_spacing,
    ),
    label_node_spacing: merge_opt(
      child.label_node_spacing,
      parent.label_node_spacing,
    ),
    label_port_horizontal_spacing: merge_opt(
      child.label_port_horizontal_spacing,
      parent.label_port_horizontal_spacing,
    ),
    label_port_vertical_spacing: merge_opt(
      child.label_port_vertical_spacing,
      parent.label_port_vertical_spacing,
    ),
    label_label_spacing: merge_opt(
      child.label_label_spacing,
      parent.label_label_spacing,
    ),
    port_port_spacing: merge_opt(
      child.port_port_spacing,
      parent.port_port_spacing,
    ),
    component_component_spacing: merge_opt(
      child.component_component_spacing,
      parent.component_component_spacing,
    ),
    padding: merge_opt(child.padding, parent.padding),
    edge_routing: merge_opt(child.edge_routing, parent.edge_routing),
    edge_type: merge_opt(child.edge_type, parent.edge_type),
    port_constraints: merge_opt(child.port_constraints, parent.port_constraints),
    port_alignment: merge_opt(child.port_alignment, parent.port_alignment),
    port_alignment_north: merge_opt(
      child.port_alignment_north,
      parent.port_alignment_north,
    ),
    port_alignment_south: merge_opt(
      child.port_alignment_south,
      parent.port_alignment_south,
    ),
    port_alignment_east: merge_opt(
      child.port_alignment_east,
      parent.port_alignment_east,
    ),
    port_alignment_west: merge_opt(
      child.port_alignment_west,
      parent.port_alignment_west,
    ),
    port_label_placement: merge_opt(
      child.port_label_placement,
      parent.port_label_placement,
    ),
    port_sorting_strategy: merge_opt(
      child.port_sorting_strategy,
      parent.port_sorting_strategy,
    ),
    port_border_offset: merge_opt(
      child.port_border_offset,
      parent.port_border_offset,
    ),
    node_size_constraints: merge_opt(
      child.node_size_constraints,
      parent.node_size_constraints,
    ),
    node_size_options: merge_opt(
      child.node_size_options,
      parent.node_size_options,
    ),
    node_size_minimum: merge_opt(
      child.node_size_minimum,
      parent.node_size_minimum,
    ),
    node_size_fixed_graph_size: merge_opt(
      child.node_size_fixed_graph_size,
      parent.node_size_fixed_graph_size,
    ),
    node_label_placement: merge_opt(
      child.node_label_placement,
      parent.node_label_placement,
    ),
    edge_label_placement: merge_opt(
      child.edge_label_placement,
      parent.edge_label_placement,
    ),
    edge_label_side_selection: merge_opt(
      child.edge_label_side_selection,
      parent.edge_label_side_selection,
    ),
    center_edge_label_placement_strategy: merge_opt(
      child.center_edge_label_placement_strategy,
      parent.center_edge_label_placement_strategy,
    ),
    cycle_breaking_strategy: merge_opt(
      child.cycle_breaking_strategy,
      parent.cycle_breaking_strategy,
    ),
    layering_strategy: merge_opt(
      child.layering_strategy,
      parent.layering_strategy,
    ),
    crossing_min_strategy: merge_opt(
      child.crossing_min_strategy,
      parent.crossing_min_strategy,
    ),
    crossing_min_force_node_model_order: merge_opt(
      child.crossing_min_force_node_model_order,
      parent.crossing_min_force_node_model_order,
    ),
    greedy_switch: merge_opt(child.greedy_switch, parent.greedy_switch),
    node_placement_strategy: merge_opt(
      child.node_placement_strategy,
      parent.node_placement_strategy,
    ),
    bk_fixed_alignment: merge_opt(
      child.bk_fixed_alignment,
      parent.bk_fixed_alignment,
    ),
    bk_edge_straightening: merge_opt(
      child.bk_edge_straightening,
      parent.bk_edge_straightening,
    ),
    linear_segments_deflection_dampening: merge_opt(
      child.linear_segments_deflection_dampening,
      parent.linear_segments_deflection_dampening,
    ),
    node_flexibility: merge_opt(child.node_flexibility, parent.node_flexibility),
    hierarchy_handling: merge_opt(
      child.hierarchy_handling,
      parent.hierarchy_handling,
    ),
    content_alignment: merge_opt(
      child.content_alignment,
      parent.content_alignment,
    ),
    thoroughness: merge_opt(child.thoroughness, parent.thoroughness),
    aspect_ratio: merge_opt(child.aspect_ratio, parent.aspect_ratio),
    interactive: merge_opt(child.interactive, parent.interactive),
    interactive_reference_point: merge_opt(
      child.interactive_reference_point,
      parent.interactive_reference_point,
    ),
    random_seed: merge_opt(child.random_seed, parent.random_seed),

    // Compaction
    compaction_strategy: merge_opt(
      child.compaction_strategy,
      parent.compaction_strategy,
    ),
    post_compaction_strategy: merge_opt(
      child.post_compaction_strategy,
      parent.post_compaction_strategy,
    ),
    self_loop_distribution: merge_opt(
      child.self_loop_distribution,
      parent.self_loop_distribution,
    ),
    self_loop_ordering: merge_opt(
      child.self_loop_ordering,
      parent.self_loop_ordering,
    ),
    force_model: merge_opt(child.force_model, parent.force_model),
    force_iterations: merge_opt(child.force_iterations, parent.force_iterations),
    force_repulsion: merge_opt(child.force_repulsion, parent.force_repulsion),
    force_repulsive_power: merge_opt(
      child.force_repulsive_power,
      parent.force_repulsive_power,
    ),
    force_temperature: merge_opt(
      child.force_temperature,
      parent.force_temperature,
    ),
    separate_connected_components: merge_opt(
      child.separate_connected_components,
      parent.separate_connected_components,
    ),
    consider_model_order_strategy: merge_opt(
      child.consider_model_order_strategy,
      parent.consider_model_order_strategy,
    ),
    merge_edges: merge_opt(child.merge_edges, parent.merge_edges),
    merge_hierarchy_crossing_edges: merge_opt(
      child.merge_hierarchy_crossing_edges,
      parent.merge_hierarchy_crossing_edges,
    ),
    wrap_graphs: merge_opt(child.wrap_graphs, parent.wrap_graphs),
    feedback_edges: merge_opt(child.feedback_edges, parent.feedback_edges),
    partition_cycle: merge_opt(child.partition_cycle, parent.partition_cycle),
    layer_constraint: merge_opt(child.layer_constraint, parent.layer_constraint),
    position_constraint: merge_opt(
      child.position_constraint,
      parent.position_constraint,
    ),
    priority: merge_opt(child.priority, parent.priority),
    long_edge_priority: merge_opt(
      child.long_edge_priority,
      parent.long_edge_priority,
    ),
    custom: match (parent.custom, child.custom) {
      (None, None) => None
      (Some(p), None) => Some(p)
      (None, Some(c)) => Some(c)
      (Some(p), Some(c)) => {
        let merged : Map[String, PropertyValue] = {}
        for k, v in p {
          merged[k] = v
        }
        for k, v in c {
          merged[k] = v
        }
        Some(merged)
      }
    },
  }
}

// ============================================================================
// Conversion to Properties
// ============================================================================

///|
/// Convert LayoutOptions to ElkProperties for attachment to nodes
fn LayoutOptions::to_properties(self : LayoutOptions) -> ElkProperties {
  let props = ElkProperties::new()
  match self.algorithm {
    Some(alg) => props.set("elk.algorithm", Enum(alg.to_string()))
    None => ()
  }
  match self.direction {
    Some(dir) => props.set("elk.direction", Enum(dir.to_string()))
    None => ()
  }
  match self.edge_routing {
    Some(routing) => props.set("elk.edgeRouting", Enum(routing.to_string()))
    None => ()
  }
  match self.priority {
    Some(v) => props.set("elk.priority", Int(v))
    None => ()
  }
  match self.node_node_spacing {
    Some(v) => props.set("elk.spacing.nodeNode", Double(v))
    None => ()
  }
  match self.node_node_between_layers_spacing {
    Some(v) => props.set("elk.spacing.nodeNodeBetweenLayers", Double(v))
    None => ()
  }
  match self.edge_node_spacing {
    Some(v) => props.set("elk.spacing.edgeNode", Double(v))
    None => ()
  }
  match self.edge_node_between_layers_spacing {
    Some(v) => props.set("elk.spacing.edgeNodeBetweenLayers", Double(v))
    None => ()
  }
  match self.edge_edge_spacing {
    Some(v) => props.set("elk.spacing.edgeEdge", Double(v))
    None => ()
  }
  match self.edge_edge_between_layers_spacing {
    Some(v) => {
      props.set("elk.spacing.edgeEdgeBetweenLayers", Double(v))
      props.set("elk.layered.spacing.edgeEdgeBetweenLayers", Double(v))
    }
    None => ()
  }
  match self.component_component_spacing {
    Some(v) => props.set("elk.spacing.componentComponent", Double(v))
    None => ()
  }
  match self.padding {
    Some(p) =>
      props.set(
        "elk.padding",
        Padding({ top: p.top, right: p.right, bottom: p.bottom, left: p.left }),
      )
    None => ()
  }
  match self.thoroughness {
    Some(v) => props.set("elk.layered.thoroughness", Int(v))
    None => ()
  }
  match self.cycle_breaking_strategy {
    Some(v) =>
      props.set("elk.layered.cycleBreaking.strategy", Enum(v.to_string()))
    None => ()
  }
  match self.layering_strategy {
    Some(v) => props.set("elk.layered.layering.strategy", Enum(v.to_string()))
    None => ()
  }
  match self.crossing_min_strategy {
    Some(v) =>
      props.set(
        "elk.layered.crossingMinimization.strategy",
        Enum(v.to_string()),
      )
    None => ()
  }
  match self.crossing_min_force_node_model_order {
    Some(v) =>
      props.set("elk.layered.crossingMinimization.forceNodeModelOrder", Bool(v))
    None => ()
  }
  match self.node_placement_strategy {
    Some(v) =>
      props.set("elk.layered.nodePlacement.strategy", Enum(v.to_string()))
    None => ()
  }
  match self.bk_fixed_alignment {
    Some(v) => {
      let value = match v {
        Average => "BALANCED"
        LeftUp => "LEFT_UP"
        LeftDown => "LEFT_DOWN"
        RightUp => "RIGHT_UP"
        RightDown => "RIGHT_DOWN"
      }
      props.set("elk.layered.nodePlacement.bk.fixedAlignment", Enum(value))
    }
    None => ()
  }
  match self.consider_model_order_strategy {
    Some(v) =>
      props.set("elk.layered.considerModelOrder.strategy", Enum(v.to_string()))
    None => ()
  }
  match self.hierarchy_handling {
    Some(v) => {
      let value = match v {
        Inherit => "INHERIT"
        Include => "INCLUDE_CHILDREN"
        Separate => "SEPARATE_CHILDREN"
      }
      props.set("elk.hierarchyHandling", Enum(value))
    }
    None => ()
  }
  match self.content_alignment {
    Some(v) => {
      let value = match v {
        None => "NONE"
        Horizontal => "H_CENTER"
        Vertical => "V_CENTER"
        HorizontalVertical => "H_CENTER V_CENTER"
      }
      props.set("elk.contentAlignment", Enum(value))
    }
    None => ()
  }
  match self.node_size_constraints {
    Some(values) => {
      let raw : Array[PropertyValue] = []
      for v in values {
        let value = match v {
          None => "NONE"
          Ports => "PORTS"
          PortLabels => "PORT_LABELS"
          NodeLabels => "NODE_LABELS"
          MinimumSize => "MINIMUM_SIZE"
          MinimumSizeAccountsForPadding => "MINIMUM_SIZE_ACCOUNTS_FOR_PADDING"
        }
        raw.push(Enum(value))
      }
      props.set("elk.nodeSize.constraints", Array(raw))
    }
    None => ()
  }
  match self.node_size_minimum {
    Some((w, h)) =>
      props.set("elk.nodeSize.minimum", Point(ElkPoint::new(w, h)))
    None => ()
  }
  props
}

// ============================================================================
// Conversion from Properties
// ============================================================================

///|
/// Parse a subset of ELK properties into LayoutOptions (unknown keys ignored).
fn LayoutOptions::from_properties(props : ElkProperties) -> LayoutOptions {
  let mut options = LayoutOptions::new()
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

  fn get_double_any(props : ElkProperties, keys : Array[String]) -> Double? {
    for key in keys {
      match props.get_double(key) {
        Some(v) => return Some(v)
        None => ()
      }
    }
    None
  }

  fn get_int_any(props : ElkProperties, keys : Array[String]) -> Int? {
    for key in keys {
      match props.get_int(key) {
        Some(v) => return Some(v)
        None => ()
      }
    }
    None
  }

  fn get_bool_any(props : ElkProperties, keys : Array[String]) -> Bool? {
    for key in keys {
      match props.get_bool(key) {
        Some(v) => return Some(v)
        None => ()
      }
    }
    None
  }

  fn get_padding_any(
    props : ElkProperties,
    keys : Array[String],
  ) -> ElkPadding? {
    for key in keys {
      match props.get_padding(key) {
        Some(v) => return Some(v)
        None => ()
      }
    }
    None
  }

  fn get_point_any(props : ElkProperties, keys : Array[String]) -> ElkPoint? {
    for key in keys {
      match props.get_point(key) {
        Some(v) => return Some(v)
        None => ()
      }
    }
    None
  }

  fn get_array_any(
    props : ElkProperties,
    keys : Array[String],
  ) -> Array[PropertyValue]? {
    for key in keys {
      match props.get_array(key) {
        Some(v) => return Some(v)
        None => ()
      }
    }
    None
  }

  match get_string_any(props, ["elk.algorithm", "org.eclipse.elk.algorithm"]) {
    Some(s) =>
      match LayoutAlgorithm::from_string(s) {
        Some(v) => options = options.with_algorithm(v)
        None => ()
      }
    None => ()
  }
  match get_string_any(props, ["elk.direction", "org.eclipse.elk.direction"]) {
    Some(s) =>
      match LayoutDirection::from_string(s) {
        Some(v) => options = options.with_direction(v)
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, ["elk.edgeRouting", "org.eclipse.elk.edgeRouting"]) {
    Some(s) =>
      match EdgeRouting::from_string(s) {
        Some(v) => options = options.with_edge_routing(v)
        None => ()
      }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.nodeNode", "org.eclipse.elk.spacing.nodeNode",
    ]) {
    Some(v) => options = options.with_node_spacing(v)
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.nodeNodeBetweenLayers", "org.eclipse.elk.spacing.nodeNodeBetweenLayers",
    ]) {
    Some(v) => options = options.with_layer_spacing(v)
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.edgeEdge", "org.eclipse.elk.spacing.edgeEdge",
    ]) {
    Some(v) => options = options.with_edge_spacing(v)
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.edgeEdgeBetweenLayers", "org.eclipse.elk.spacing.edgeEdgeBetweenLayers",
      "elk.layered.spacing.edgeEdgeBetweenLayers", "org.eclipse.elk.layered.spacing.edgeEdgeBetweenLayers",
    ]) {
    Some(v) =>
      options = { ..options, edge_edge_between_layers_spacing: Some(v) }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.edgeNode", "org.eclipse.elk.spacing.edgeNode",
    ]) {
    Some(v) => options = { ..options, edge_node_spacing: Some(v) }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.edgeNodeBetweenLayers", "org.eclipse.elk.spacing.edgeNodeBetweenLayers",
      "elk.layered.spacing.edgeNodeBetweenLayers", "org.eclipse.elk.layered.spacing.edgeNodeBetweenLayers",
    ]) {
    Some(v) =>
      options = { ..options, edge_node_between_layers_spacing: Some(v) }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.edgeLabel", "org.eclipse.elk.spacing.edgeLabel",
    ]) {
    Some(v) => options = { ..options, edge_label_spacing: Some(v) }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.labelLabel", "org.eclipse.elk.spacing.labelLabel",
    ]) {
    Some(v) => options = { ..options, label_label_spacing: Some(v) }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.labelNode", "org.eclipse.elk.spacing.labelNode",
    ]) {
    Some(v) => options = { ..options, label_node_spacing: Some(v) }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.labelPortHorizontal", "org.eclipse.elk.spacing.labelPortHorizontal",
    ]) {
    Some(v) => options = { ..options, label_port_horizontal_spacing: Some(v) }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.labelPortVertical", "org.eclipse.elk.spacing.labelPortVertical",
    ]) {
    Some(v) => options = { ..options, label_port_vertical_spacing: Some(v) }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.portPort", "org.eclipse.elk.spacing.portPort",
    ]) {
    Some(v) => options = { ..options, port_port_spacing: Some(v) }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.spacing.componentComponent", "org.eclipse.elk.spacing.componentComponent",
    ]) {
    Some(v) => options = { ..options, component_component_spacing: Some(v) }
    None => ()
  }
  match get_padding_any(props, ["elk.padding", "org.eclipse.elk.padding"]) {
    Some(p) => options = options.with_padding(p)
    None => ()
  }
  match
    get_string_any(props, [
      "elk.portConstraints", "org.eclipse.elk.portConstraints",
    ]) {
    Some(s) =>
      match PortConstraints::from_string(s) {
        Some(v) => options = { ..options, port_constraints: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.portAlignment", "org.eclipse.elk.portAlignment", "elk.portAlignment.default",
      "org.eclipse.elk.portAlignment.default",
    ]) {
    Some(s) =>
      match PortAlignment::from_string(s) {
        Some(v) => options = { ..options, port_alignment: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.portAlignment.north", "org.eclipse.elk.portAlignment.north",
    ]) {
    Some(s) =>
      match PortAlignment::from_string(s) {
        Some(v) => options = { ..options, port_alignment_north: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.portAlignment.south", "org.eclipse.elk.portAlignment.south",
    ]) {
    Some(s) =>
      match PortAlignment::from_string(s) {
        Some(v) => options = { ..options, port_alignment_south: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.portAlignment.east", "org.eclipse.elk.portAlignment.east",
    ]) {
    Some(s) =>
      match PortAlignment::from_string(s) {
        Some(v) => options = { ..options, port_alignment_east: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.portAlignment.west", "org.eclipse.elk.portAlignment.west",
    ]) {
    Some(s) =>
      match PortAlignment::from_string(s) {
        Some(v) => options = { ..options, port_alignment_west: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_double_any(props, [
      "elk.port.borderOffset", "org.eclipse.elk.port.borderOffset",
    ]) {
    Some(v) => options = { ..options, port_border_offset: Some(v) }
    None => ()
  }
  fn parse_node_size_constraints(
    raw : Array[PropertyValue],
  ) -> Array[NodeSizeConstraints] {
    let out : Array[NodeSizeConstraints] = []
    for v in raw {
      match v {
        String(s) | Enum(s) =>
          match NodeSizeConstraints::from_string(s) {
            Some(e) => out.push(e)
            None => ()
          }
        _ => ()
      }
    }
    out
  }

  match
    get_array_any(props, [
      "elk.nodeSize.constraints", "org.eclipse.elk.nodeSize.constraints",
    ]) {
    Some(raw) =>
      options = {
        ..options,
        node_size_constraints: Some(parse_node_size_constraints(raw)),
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.nodeSize.constraints", "org.eclipse.elk.nodeSize.constraints",
    ]) {
    Some(s) =>
      match NodeSizeConstraints::from_string(s) {
        Some(v) => options = { ..options, node_size_constraints: Some([v]) }
        None => ()
      }
    None => ()
  }
  match
    get_point_any(props, [
      "elk.nodeSize.minimum", "org.eclipse.elk.nodeSize.minimum",
    ]) {
    Some(p) => options = { ..options, node_size_minimum: Some((p.x, p.y)) }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.hierarchyHandling", "org.eclipse.elk.hierarchyHandling",
    ]) {
    Some(s) =>
      match HierarchyHandling::from_string(s) {
        Some(v) => options = { ..options, hierarchy_handling: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.contentAlignment", "org.eclipse.elk.contentAlignment",
    ]) {
    Some(s) =>
      match ContentAlignment::from_string(s) {
        Some(v) => options = { ..options, content_alignment: Some(v) }
        None => ()
      }
    None => ()
  }
  fn parse_node_label_placements(
    raw : Array[PropertyValue],
  ) -> Array[NodeLabelPlacement] {
    let out : Array[NodeLabelPlacement] = []
    for v in raw {
      match v {
        String(s) | Enum(s) =>
          match NodeLabelPlacement::from_string(s) {
            Some(e) => out.push(e)
            None => ()
          }
        _ => ()
      }
    }
    out
  }

  fn parse_port_label_placements(
    raw : Array[PropertyValue],
  ) -> Array[PortLabelPlacement] {
    let out : Array[PortLabelPlacement] = []
    for v in raw {
      match v {
        String(s) | Enum(s) =>
          match PortLabelPlacement::from_string(s) {
            Some(e) => out.push(e)
            None => ()
          }
        _ => ()
      }
    }
    out
  }

  match
    get_array_any(props, [
      "elk.nodeLabels.placement", "org.eclipse.elk.nodeLabels.placement",
    ]) {
    Some(raw) =>
      options = {
        ..options,
        node_label_placement: Some(parse_node_label_placements(raw)),
      }
    None => ()
  }
  match
    get_array_any(props, [
      "elk.portLabels.placement", "org.eclipse.elk.portLabels.placement",
    ]) {
    Some(raw) =>
      options = {
        ..options,
        port_label_placement: Some(parse_port_label_placements(raw)),
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.edgeLabels.placement", "org.eclipse.elk.edgeLabels.placement",
    ]) {
    Some(s) =>
      match EdgeLabelPlacement::from_string(s) {
        Some(v) => options = { ..options, edge_label_placement: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.layered.edgeLabels.sideSelection", "org.eclipse.elk.alg.layered.edgeLabels.sideSelection",
    ]) {
    Some(s) =>
      match EdgeLabelSideSelection::from_string(s) {
        Some(v) => options = { ..options, edge_label_side_selection: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.layered.edgeLabels.centerLabelPlacementStrategy", "org.eclipse.elk.alg.layered.edgeLabels.centerLabelPlacementStrategy",
    ]) {
    Some(s) =>
      match CenterEdgeLabelPlacementStrategy::from_string(s) {
        Some(v) =>
          options = { ..options, center_edge_label_placement_strategy: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_bool_any(props, [
      "elk.layered.crossingMinimization.forceNodeModelOrder", "org.eclipse.elk.alg.layered.crossingMinimization.forceNodeModelOrder",
    ]) {
    Some(v) =>
      options = { ..options, crossing_min_force_node_model_order: Some(v) }
    None => ()
  }
  match get_int_any(props, ["elk.priority", "org.eclipse.elk.priority"]) {
    Some(v) => options = { ..options, priority: Some(v) }
    None => ()
  }
  match get_int_any(props, ["elk.randomSeed", "org.eclipse.elk.randomSeed"]) {
    Some(v) => options = { ..options, random_seed: Some(v) }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.layered.considerModelOrder.strategy", "org.eclipse.elk.alg.layered.considerModelOrder.strategy",
    ]) {
    Some(s) =>
      match OrderingStrategy::from_string(s) {
        Some(v) =>
          options = { ..options, consider_model_order_strategy: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_int_any(props, [
      "elk.layered.thoroughness", "org.eclipse.elk.alg.layered.thoroughness",
    ]) {
    Some(v) => options = { ..options, thoroughness: Some(v) }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.layered.cycleBreaking.strategy", "org.eclipse.elk.alg.layered.cycleBreaking.strategy",
    ]) {
    Some(s) =>
      match CycleBreakingStrategy::from_string(s) {
        Some(v) => options = { ..options, cycle_breaking_strategy: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.layered.layering.strategy", "org.eclipse.elk.alg.layered.layering.strategy",
    ]) {
    Some(s) =>
      match LayeringStrategy::from_string(s) {
        Some(v) => options = { ..options, layering_strategy: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.layered.crossingMinimization.strategy", "org.eclipse.elk.alg.layered.crossingMinimization.strategy",
    ]) {
    Some(s) =>
      match CrossingMinimizationStrategy::from_string(s) {
        Some(v) => options = { ..options, crossing_min_strategy: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.layered.nodePlacement.strategy", "org.eclipse.elk.alg.layered.nodePlacement.strategy",
    ]) {
    Some(s) =>
      match NodePlacementStrategy::from_string(s) {
        Some(v) => options = { ..options, node_placement_strategy: Some(v) }
        None => ()
      }
    None => ()
  }
  match
    get_string_any(props, [
      "elk.layered.nodePlacement.bk.fixedAlignment", "org.eclipse.elk.layered.nodePlacement.bk.fixedAlignment",
    ]) {
    Some(s) =>
      match BKNodePlacementMode::from_string(s) {
        Some(v) => options = { ..options, bk_fixed_alignment: Some(v) }
        None => ()
      }
    None => ()
  }
  options
}
