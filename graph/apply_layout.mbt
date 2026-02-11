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
/// Apply a layout patch to an immutable `GraphInput`.

///|
fn apply_box_to_object(
  obj : ObjectInput,
  nodes : Map[String, Box],
) -> ObjectInput {
  let layout_box = match nodes.get(obj.id) {
    Some(b) => Some(b)
    None => obj.box
  }
  { ..obj, box: apply_locked_position(obj, layout_box) }
}

///|
fn apply_locked_position(obj : ObjectInput, box : Box?) -> Box? {
  match box {
    Some(b) => {
      let x = match obj.left {
        Some(v) => v.to_double()
        None => b.x
      }
      let y = match obj.top {
        Some(v) => v.to_double()
        None => b.y
      }
      Some(Box::new(x, y, b.width, b.height))
    }
    None => None
  }
}

///|
fn apply_route_to_edge(
  edge : EdgeInput,
  routes : Map[Int, Array[Point]],
  edge_curves : Map[Int, Bool],
  edge_labels : Map[Int, Box],
) -> EdgeInput {
  let route = match routes.get(edge.index) {
    Some(ps) => ps
    None => edge.route
  }
  let is_curve = edge_curves.get_or_default(edge.index, edge.is_curve)
  let label_box = match edge_labels.get(edge.index) {
    Some(b) => Some(b)
    None => edge.label_box
  }
  { ..edge, route, is_curve, label_box }
}

///|
pub fn apply_layout(graph : GraphInput, patch : LayoutPatch) -> GraphInput {
  let root = apply_box_to_object(graph.root, patch.nodes)
  let objects : Array[ObjectInput] = []
  for obj in graph.objects {
    objects.push(apply_box_to_object(obj, patch.nodes))
  }
  let edges : Array[EdgeInput] = []
  for e in graph.edges {
    edges.push(
      apply_route_to_edge(e, patch.edges, patch.edge_curves, patch.edge_labels),
    )
  }
  {
    ..graph,
    root,
    objects,
    edges,
    activation_boxes: patch.activation_boxes,
    sequence_notes: patch.sequence_notes,
    sequence_fragments_layout: patch.sequence_fragments,
  }
}
