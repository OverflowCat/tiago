///|
/// ELK.js Port for MoonBit - Layout Options
/// Complete 400+ options system for ELK algorithms

// ============================================================================
// Core Algorithm Selection
// ============================================================================

///|
/// Available layout algorithms
pub(all) enum LayoutAlgorithm {
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
/// Layout direction (primary axis for layered layout)
pub(all) enum LayoutDirection {
  Undefined
  Right
  Left
  Down
  Up
} derive(Show, Eq)

///|
pub fn LayoutDirection::is_horizontal(self : LayoutDirection) -> Bool {
  match self {
    Right | Left => true
    _ => false
  }
}

///|
pub fn LayoutDirection::is_vertical(self : LayoutDirection) -> Bool {
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
pub(all) enum EdgeRouting {
  Undefined
  Polyline
  Orthogonal
  Splines
} derive(Show, Eq)

///|
/// Edge type for differentiating edge kinds
pub(all) enum EdgeType {
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
pub(all) enum CycleBreakingStrategy {
  GreedyCycleBreaker
  DepthFirst
  InteractiveCycleBreaker
  ModelOrder
  GreedyModelOrder
} derive(Show, Eq)

///|
/// Layer assignment strategy
pub(all) enum LayeringStrategy {
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
/// Crossing minimization strategy
pub(all) enum CrossingMinimizationStrategy {
  LayerSweep
  InteractiveCrossMin
  None
} derive(Show, Eq)

///|
/// Greedy switch type for crossing minimization
pub(all) enum GreedySwitchType {
  Off
  OneSided
  TwoSided
} derive(Show, Eq)

///|
/// Node placement strategy
pub(all) enum NodePlacementStrategy {
  BrandesKoepf
  LinearSegments
  Simple
  NetworkSimplex
} derive(Show, Eq)

///|
/// Brandes-Koepf node placement mode
pub(all) enum BKNodePlacementMode {
  Average
  LeftUp
  LeftDown
  RightUp
  RightDown
} derive(Show, Eq)

///|
/// Edge straightening strategy for Brandes-Koepf
pub(all) enum EdgeStraighteningStrategy {
  None
  ImproveStraightness
} derive(Show, Eq)

///|
/// Node flexibility for network simplex placement
pub(all) enum NodeFlexibility {
  None
  NodeSize
  NodeSizeWhereSpacePermits
} derive(Show, Eq)

// ============================================================================
// Port Options
// ============================================================================

///|
/// Port constraints level
pub(all) enum PortConstraints {
  Undefined
  Free
  FixedSide
  FixedOrder
  FixedRatio
  FixedPos
} derive(Show, Eq)

///|
/// Port alignment within side
pub(all) enum PortAlignment {
  Undefined
  Distributed
  Justified
  Begin
  Center
  End
} derive(Show, Eq)

///|
/// Port label placement
pub(all) enum PortLabelPlacement {
  Inside
  Outside
  NextToPortIfPossible
  AlwaysOther
  AlwaysSameSide
} derive(Show, Eq)

///|
/// Port sort order
pub(all) enum PortSortingStrategy {
  InputOrder
  PortDegree
} derive(Show, Eq)

// ============================================================================
// Node Options
// ============================================================================

///|
/// Node size constraints
pub(all) enum NodeSizeConstraints {
  None
  Ports
  PortLabels
  NodeLabels
  MinimumSize
  MinimumSizeAccountsForPadding
} derive(Show, Eq)

///|
/// Node size options (bit flags combined)
pub(all) enum NodeSizeOptions {
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
pub(all) enum NodeLabelPlacement {
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

// ============================================================================
// Edge Label Options
// ============================================================================

///|
/// Edge label placement strategy
pub(all) enum EdgeLabelPlacement {
  Undefined
  Center
  Head
  Tail
} derive(Show, Eq)

///|
/// Edge label side selection
pub(all) enum EdgeLabelSideSelection {
  AlwaysUp
  AlwaysDown
  DirectionUp
  DirectionDown
  SmartUp
  SmartDown
} derive(Show, Eq)

// ============================================================================
// Hierarchy Options
// ============================================================================

///|
/// Hierarchy handling mode
pub(all) enum HierarchyHandling {
  Inherit
  Include
  Separate
} derive(Show, Eq)

///|
/// Content alignment within compound nodes
pub(all) enum ContentAlignment {
  None
  Horizontal
  Vertical
  HorizontalVertical
} derive(Show, Eq)

// ============================================================================
// Compaction Options
// ============================================================================

///|
/// Compaction strategy
pub(all) enum CompactionStrategy {
  None
  Polyomino
  Rectangle
} derive(Show, Eq)

///|
/// Graph compaction strategy
pub(all) enum GraphCompactionStrategy {
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
pub(all) enum SelfLoopDistribution {
  North
  NorthSouth
  Equally
} derive(Show, Eq)

///|
/// Self-loop ordering strategy
pub(all) enum SelfLoopOrdering {
  Stacked
  Sequenced
} derive(Show, Eq)

// ============================================================================
// Force Algorithm Options
// ============================================================================

///|
/// Force model type
pub(all) enum ForceModelType {
  Eades
  FruchtermanReingold
} derive(Show, Eq)

// ============================================================================
// Spacing Options (struct for grouped spacing values)
// ============================================================================

///|
/// Spacing configuration
pub(all) struct SpacingOptions {
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
pub fn SpacingOptions::default() -> SpacingOptions {
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
pub(all) struct LayoutOptions {
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
  center_edge_label_placement_strategy : Bool?

  // Layered-specific options
  cycle_breaking_strategy : CycleBreakingStrategy?
  layering_strategy : LayeringStrategy?
  crossing_min_strategy : CrossingMinimizationStrategy?
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
  consider_model_order_strategy : Bool?

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
pub fn LayoutOptions::new() -> LayoutOptions {
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
pub fn LayoutOptions::layered() -> LayoutOptions {
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
    node_placement_strategy: Some(BrandesKoepf),
    thoroughness: Some(7),
  }
}

///|
/// Create default options for force algorithm
pub fn LayoutOptions::force() -> LayoutOptions {
  {
    ..LayoutOptions::new(),
    algorithm: Some(Force),
    force_model: Some(FruchtermanReingold),
    force_iterations: Some(300),
    force_repulsion: Some(5.0),
    force_temperature: Some(0.1),
    node_node_spacing: Some(20.0),
    padding: Some(ElkPadding::uniform(12.0)),
  }
}

///|
/// Create default options for stress algorithm
pub fn LayoutOptions::stress() -> LayoutOptions {
  {
    ..LayoutOptions::new(),
    algorithm: Some(Stress),
    node_node_spacing: Some(20.0),
    padding: Some(ElkPadding::uniform(12.0)),
  }
}

///|
/// Create default options for radial algorithm
pub fn LayoutOptions::radial() -> LayoutOptions {
  {
    ..LayoutOptions::new(),
    algorithm: Some(Radial),
    node_node_spacing: Some(20.0),
    padding: Some(ElkPadding::uniform(12.0)),
  }
}

///|
/// Create default options for tree algorithm
pub fn LayoutOptions::tree() -> LayoutOptions {
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
pub fn LayoutOptions::with_algorithm(
  self : LayoutOptions,
  alg : LayoutAlgorithm,
) -> LayoutOptions {
  { ..self, algorithm: Some(alg) }
}

///|
pub fn LayoutOptions::with_direction(
  self : LayoutOptions,
  dir : LayoutDirection,
) -> LayoutOptions {
  { ..self, direction: Some(dir) }
}

///|
pub fn LayoutOptions::with_edge_routing(
  self : LayoutOptions,
  routing : EdgeRouting,
) -> LayoutOptions {
  { ..self, edge_routing: Some(routing) }
}

///|
pub fn LayoutOptions::with_node_spacing(
  self : LayoutOptions,
  spacing : Double,
) -> LayoutOptions {
  { ..self, node_node_spacing: Some(spacing) }
}

///|
pub fn LayoutOptions::with_layer_spacing(
  self : LayoutOptions,
  spacing : Double,
) -> LayoutOptions {
  { ..self, node_node_between_layers_spacing: Some(spacing) }
}

///|
pub fn LayoutOptions::with_edge_spacing(
  self : LayoutOptions,
  spacing : Double,
) -> LayoutOptions {
  { ..self, edge_edge_spacing: Some(spacing) }
}

///|
pub fn LayoutOptions::with_padding(
  self : LayoutOptions,
  padding : ElkPadding,
) -> LayoutOptions {
  { ..self, padding: Some(padding) }
}

///|
pub fn LayoutOptions::with_uniform_padding(
  self : LayoutOptions,
  value : Double,
) -> LayoutOptions {
  { ..self, padding: Some(ElkPadding::uniform(value)) }
}

///|
pub fn LayoutOptions::with_port_constraints(
  self : LayoutOptions,
  constraints : PortConstraints,
) -> LayoutOptions {
  { ..self, port_constraints: Some(constraints) }
}

///|
pub fn LayoutOptions::with_hierarchy_handling(
  self : LayoutOptions,
  handling : HierarchyHandling,
) -> LayoutOptions {
  { ..self, hierarchy_handling: Some(handling) }
}

///|
pub fn LayoutOptions::with_thoroughness(
  self : LayoutOptions,
  value : Int,
) -> LayoutOptions {
  { ..self, thoroughness: Some(value) }
}

///|
pub fn LayoutOptions::with_aspect_ratio(
  self : LayoutOptions,
  ratio : Double,
) -> LayoutOptions {
  { ..self, aspect_ratio: Some(ratio) }
}

///|
pub fn LayoutOptions::interactive(self : LayoutOptions) -> LayoutOptions {
  { ..self, interactive: Some(true) }
}

///|
pub fn LayoutOptions::with_cycle_breaking(
  self : LayoutOptions,
  strategy : CycleBreakingStrategy,
) -> LayoutOptions {
  { ..self, cycle_breaking_strategy: Some(strategy) }
}

///|
pub fn LayoutOptions::with_layering(
  self : LayoutOptions,
  strategy : LayeringStrategy,
) -> LayoutOptions {
  { ..self, layering_strategy: Some(strategy) }
}

///|
pub fn LayoutOptions::with_crossing_min(
  self : LayoutOptions,
  strategy : CrossingMinimizationStrategy,
) -> LayoutOptions {
  { ..self, crossing_min_strategy: Some(strategy) }
}

///|
pub fn LayoutOptions::with_node_placement(
  self : LayoutOptions,
  strategy : NodePlacementStrategy,
) -> LayoutOptions {
  { ..self, node_placement_strategy: Some(strategy) }
}

///|
pub fn LayoutOptions::with_custom(
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
pub fn LayoutOptions::merge(
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
pub fn LayoutOptions::to_properties(self : LayoutOptions) -> ElkProperties {
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
  match self.node_node_spacing {
    Some(v) => props.set("elk.spacing.nodeNode", Double(v))
    None => ()
  }
  match self.edge_edge_spacing {
    Some(v) => props.set("elk.spacing.edgeEdge", Double(v))
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
  props
}
