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
/// Stub Dagre engine implementation.

///|
pub struct DagreEngine {
  _marker : Unit
} derive(Show)

///|
pub fn DagreEngine::new() -> DagreEngine {
  { _marker: () }
}

///|
pub impl @engine_api.LayoutEngine for DagreEngine with layout(
  _self,
  graph,
  config,
  direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  // d2 parity note: D2's dagre layout is backed by the dagre JS library.
  // diago's ELK implementation is already portable across all targets, so we
  // use it as a functional fallback until a full dagre port lands.
  @engine_elk.ElkEngine::new().layout(graph, config, direction)
}
