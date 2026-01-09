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
/// Public API facade for `Milky2018/diago/elk`.
///
/// - Data model & option types live in `Milky2018/diago/elk/base`.
/// - Algorithms live in subpackages (e.g. `Milky2018/diago/elk/layered`).
///
/// We keep these as type aliases to avoid cyclic dependencies and keep existing
/// call sites (`@elk.ElkNode`, `@elk.LayoutOptions`, …) stable.
pub type ElkPoint = @base.ElkPoint

///|
pub type ElkPadding = @base.ElkPadding

///|
pub type PortSide = @base.PortSide

///|
pub type PropertyValue = @base.PropertyValue

///|
pub type ElkProperties = @base.ElkProperties

///|
pub type ElkLabel = @base.ElkLabel

///|
pub type ElkPort = @base.ElkPort

///|
pub type ElkEdgeSection = @base.ElkEdgeSection

///|
pub type ElkEdge = @base.ElkEdge

///|
pub type ElkNode = @base.ElkNode

///|
pub type LayoutAlgorithm = @base.LayoutAlgorithm

///|
pub type LayoutDirection = @base.LayoutDirection

///|
pub type EdgeRouting = @base.EdgeRouting

///|
pub type EdgeType = @base.EdgeType

///|
pub type CycleBreakingStrategy = @base.CycleBreakingStrategy

///|
pub type LayeringStrategy = @base.LayeringStrategy

///|
pub type CrossingMinimizationStrategy = @base.CrossingMinimizationStrategy

///|
pub type GreedySwitchType = @base.GreedySwitchType

///|
pub type NodePlacementStrategy = @base.NodePlacementStrategy

///|
pub type BKNodePlacementMode = @base.BKNodePlacementMode

///|
pub type EdgeStraighteningStrategy = @base.EdgeStraighteningStrategy

///|
pub type NodeFlexibility = @base.NodeFlexibility

///|
pub type PortConstraints = @base.PortConstraints

///|
pub type PortAlignment = @base.PortAlignment

///|
pub type PortLabelPlacement = @base.PortLabelPlacement

///|
pub type PortSortingStrategy = @base.PortSortingStrategy

///|
pub type NodeSizeConstraints = @base.NodeSizeConstraints

///|
pub type NodeSizeOptions = @base.NodeSizeOptions

///|
pub type NodeLabelPlacement = @base.NodeLabelPlacement

///|
pub type EdgeLabelPlacement = @base.EdgeLabelPlacement

///|
pub type EdgeLabelSideSelection = @base.EdgeLabelSideSelection

///|
pub type HierarchyHandling = @base.HierarchyHandling

///|
pub type ContentAlignment = @base.ContentAlignment

///|
pub type CompactionStrategy = @base.CompactionStrategy

///|
pub type GraphCompactionStrategy = @base.GraphCompactionStrategy

///|
pub type SelfLoopDistribution = @base.SelfLoopDistribution

///|
pub type SelfLoopOrdering = @base.SelfLoopOrdering

///|
pub type ForceModelType = @base.ForceModelType

///|
pub type SpacingOptions = @base.SpacingOptions

///|
pub type LayoutOptions = @base.LayoutOptions

///|
pub fn create_graph(id : String) -> ElkNode {
  @base.create_graph(id)
}

///|
pub fn create_edge(id : String, source : String, target : String) -> ElkEdge {
  @base.create_edge(id, source, target)
}

///|
pub fn create_labeled_node(id : String, label : String) -> ElkNode {
  @base.create_labeled_node(id, label)
}
