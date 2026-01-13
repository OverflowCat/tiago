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
/// Railway engine implementation for diagram layout.
/// This engine uses a railway-inspired layout algorithm.

///|
pub struct RailwayEngine {
  _marker : Unit
} derive(Show)

///|
pub fn RailwayEngine::new() -> RailwayEngine {
  { _marker: () }
}

///|
pub impl @engine_api.LayoutEngine for RailwayEngine with layout(
  _self,
  graph,
  _config,
  _direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  let patch = @graph.LayoutPatch::new()
  for i, node in graph.objects {
    patch.nodes[node.id] = @graph.Box::new(i.to_double() * 50, 50, 50, 50)
  }
  patch
}
