///|
/// Unified variant system for D2 diagram layers, scenarios, and steps
///
/// This module provides a unified abstraction for the different ways
/// D2 diagrams can have multiple variants:
/// - Layers: Named diagram variants that can be toggled
/// - Scenarios: Delta-based variations on a base diagram
/// - Steps: Animation frames for step-by-step presentation

///|
/// Type of graph variant
pub enum VariantType {
  /// A layer - independent diagram variant
  Layer
  /// A scenario - delta-based variation
  Scenario
  /// A step - animation frame
  Step
} derive(Eq, Show)

///|
/// A unified variant identifier
pub enum GraphVariant {
  /// A named layer variant
  LayerVariant(name~ : String)
  /// A named scenario variant
  ScenarioVariant(name~ : String)
  /// A numbered step variant (1-indexed)
  StepVariant(index~ : Int, name~ : String)
} derive(Show)

///|
/// Get the variant type
pub fn GraphVariant::variant_type(self : GraphVariant) -> VariantType {
  match self {
    LayerVariant(..) => Layer
    ScenarioVariant(..) => Scenario
    StepVariant(..) => Step
  }
}

///|
/// Get the variant name
pub fn GraphVariant::name(self : GraphVariant) -> String {
  match self {
    LayerVariant(name~) => name
    ScenarioVariant(name~) => name
    StepVariant(name~, ..) => name
  }
}

///|
/// Get step index (returns None for non-step variants)
pub fn GraphVariant::step_index(self : GraphVariant) -> Int? {
  match self {
    StepVariant(index~, ..) => Some(index)
    _ => None
  }
}

///|
/// Create a layer variant
pub fn GraphVariant::layer(name : String) -> GraphVariant {
  LayerVariant(name~)
}

///|
/// Create a scenario variant
pub fn GraphVariant::scenario(name : String) -> GraphVariant {
  ScenarioVariant(name~)
}

///|
/// Create a step variant
pub fn GraphVariant::step(index : Int, name : String) -> GraphVariant {
  StepVariant(index~, name~)
}

///|
/// A variant graph - combines the variant type with its graph
pub struct VariantGraph {
  variant : GraphVariant
  graph : Graph
} derive(Show)

///|
/// Create a new variant graph
pub fn VariantGraph::new(variant : GraphVariant, graph : Graph) -> VariantGraph {
  { variant, graph }
}

///|
/// Get the variant type
pub fn VariantGraph::variant_type(self : VariantGraph) -> VariantType {
  self.variant.variant_type()
}

///|
/// Get the variant name
pub fn VariantGraph::name(self : VariantGraph) -> String {
  self.variant.name()
}
