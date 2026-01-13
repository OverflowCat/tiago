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
/// Deprecated render-graph view model.
///
/// Renderers and tests historically consumed `RenderGraph`.
/// The new pipeline exports directly to `Diagram`, but we keep a small
/// compatibility layer so older code continues to work.

///|
using @graph {type Box, type Point}

///|
pub type RenderGraph = Diagram

///|
pub type RenderObject = Shape

///|
pub type RenderEdge = Connection

///|
/// Materialize a diagram into a render graph.
///
/// In the new pipeline the diagram is already render-ready.
pub fn materialize(diagram : Diagram) -> RenderGraph {
  diagram
}

///|
pub fn RenderGraph::get_objects(self : RenderGraph) -> Array[RenderObject] {
  self.shapes
}

///|
pub fn RenderGraph::get_edges(self : RenderGraph) -> Array[RenderEdge] {
  self.connections
}

///|
pub fn RenderGraph::has_legend(self : RenderGraph) -> Bool {
  self.legend is Some(_)
}

///|
pub fn RenderGraph::find_object(
  self : RenderGraph,
  id : String,
) -> RenderObject? {
  if self.root.id == id {
    return Some(self.root)
  }
  for obj in self.shapes {
    if obj.id == id {
      return Some(obj)
    }
  }
  None
}

///|
pub fn RenderObject::get_id(self : RenderObject) -> String {
  self.id
}

///|
pub fn RenderObject::get_box(self : RenderObject) -> Box? {
  self.box
}

///|
pub fn RenderObject::center(self : RenderObject) -> Point? {
  match self.box {
    Some(b) => Some(b.center())
    None => None
  }
}
