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
test "options: to_properties/from_properties roundtrip (subset)" {
  let options = LayoutOptions::layered()
    .with_direction(Left)
    .with_node_spacing(33.0)
    .with_layer_spacing(44.0)
    .with_edge_spacing(5.0)
    .with_padding(ElkPadding::uniform(7.0))
    .with_cycle_breaking(DepthFirst)
    .with_layering(LongestPath)
    .with_crossing_min(None)
    .with_node_placement(Simple)
  let props = options.to_properties()
  let parsed = LayoutOptions::from_properties(props)
  assert_eq(parsed.algorithm, Some(Layered))
  assert_eq(parsed.direction, Some(Left))
  assert_eq(parsed.edge_routing, Some(Orthogonal))
  assert_eq(parsed.node_node_spacing, Some(33.0))
  assert_eq(parsed.node_node_between_layers_spacing, Some(44.0))
  assert_eq(parsed.edge_edge_spacing, Some(5.0))
  assert_eq(parsed.padding, Some(ElkPadding::uniform(7.0)))
  assert_eq(parsed.cycle_breaking_strategy, Some(DepthFirst))
  assert_eq(parsed.layering_strategy, Some(LongestPath))
  assert_eq(parsed.crossing_min_strategy, Some(None))
  assert_eq(parsed.node_placement_strategy, Some(Simple))
}
