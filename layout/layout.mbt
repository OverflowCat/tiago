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
/// Legacy `layout/` compatibility façade.
///
/// New code should use `engine_api` + `engine_elk` directly.

///|
pub type LayoutConfig = @engine_api.LayoutConfig

///|
pub type Direction = @engine_api.Direction

///|
pub type LayoutError = @engine_api.LayoutError

///|
pub type LayoutResult = @engine_api.LayoutResult

///|
pub fn layout(
  graph : @graph.Graph,
  config : LayoutConfig,
  direction : Direction,
) -> LayoutResult raise LayoutError {
  @engine_elk.layout(graph, config, direction)
}
