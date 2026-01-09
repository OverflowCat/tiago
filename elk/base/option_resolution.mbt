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
/// Option resolution helpers.
///
/// ELK treats options as properties that can be set at different scopes.
/// For the current port, we expose a minimal, explicit resolution API:
///
/// - Graph → Node/Edge → child graph (compound node)
///
/// Each `resolve_*` merges the inherited `LayoutOptions` with the element's
/// own `properties` (if any). Element-local properties override inherited ones.

///|
pub fn resolve_options_for_graph(
  inherited : LayoutOptions,
  graph : ElkNode,
) -> LayoutOptions {
  LayoutOptions::merge(
    inherited,
    LayoutOptions::from_properties(graph.properties),
  )
}

///|
pub fn resolve_options_for_node(
  inherited : LayoutOptions,
  node : ElkNode,
) -> LayoutOptions {
  resolve_options_for_graph(inherited, node)
}

///|
pub fn resolve_options_for_edge(
  inherited : LayoutOptions,
  edge : ElkEdge,
) -> LayoutOptions {
  LayoutOptions::merge(
    inherited,
    LayoutOptions::from_properties(edge.properties),
  )
}

///|
pub fn resolve_options_for_port(
  inherited : LayoutOptions,
  port : ElkPort,
) -> LayoutOptions {
  LayoutOptions::merge(
    inherited,
    LayoutOptions::from_properties(port.properties),
  )
}

///|
pub fn resolve_options_for_label(
  inherited : LayoutOptions,
  label : ElkLabel,
) -> LayoutOptions {
  LayoutOptions::merge(
    inherited,
    LayoutOptions::from_properties(label.properties),
  )
}
