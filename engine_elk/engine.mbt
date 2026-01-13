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
/// ELK-backed layout engine.

///|
pub struct ElkEngine {
  _marker : Unit
} derive(Show)

///|
pub fn ElkEngine::new() -> ElkEngine {
  { _marker: () }
}

///|
pub impl @engine_api.LayoutEngine for ElkEngine with layout(
  _self,
  graph,
  config,
  direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  // Layout engines must treat the input graph as read-only.
  let materialized = Graph::from_input(graph)
  layout_graph(materialized, config, direction)
  layout_patch_from_graph(materialized)
}

///|
fn layout_patch_from_graph(graph : Graph) -> @graph.LayoutPatch {
  let patch = @graph.LayoutPatch::new()
  for obj in graph.objects {
    match obj.box {
      Some(b) => patch.nodes[obj.id] = b
      None => ()
    }
  }
  for edge in graph.edges {
    let points : Array[@graph.Point] = []
    for p in edge.route {
      points.push(@graph.Point::new(p.x, p.y))
    }
    patch.edges[edge.index] = points
    match edge.label_box {
      Some(b) => patch.edge_labels[edge.index] = b
      None => ()
    }
  }
  for ab in graph.activation_boxes {
    patch.activation_boxes.push(ab)
  }
  for note in graph.sequence_notes {
    patch.sequence_notes.push(note)
  }
  for fragment in graph.sequence_fragments {
    patch.sequence_fragments.push(fragment_layout_from_fragment(fragment))
  }
  patch
}

///|
fn fragment_layout_from_fragment(
  fragment : SequenceFragment,
) -> @graph.SequenceFragmentLayout {
  let operands : Array[@graph.FragmentOperandLayout] = []
  for op in fragment.operands {
    operands.push(
      @graph.FragmentOperandLayout::new(op.condition, op.separator_y),
    )
  }
  @graph.SequenceFragmentLayout::new(
    fragment.fragment_type,
    fragment.condition,
    fragment.bbox,
    fragment.start_index,
    fragment.end_index,
    operands,
  )
}
