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
) -> @engine_api.LayoutResult raise @engine_api.LayoutError {
  // Layout engines must treat the input graph as read-only.
  let materialized = Graph::from_input(graph)
  layout_graph(materialized, config, direction)
  layout_result_from_graph(materialized)
}

///|
fn layout_result_from_graph(graph : Graph) -> @engine_api.LayoutResult {
  let result = @engine_api.LayoutResult::new()
  for obj in graph.objects {
    match obj.box {
      Some(b) => result.nodes[obj.id] = @engine_api.NodeLayout::from_box(b)
      None => ()
    }
  }
  for edge in graph.edges {
    let points : Array[@graph.Point] = []
    for p in edge.route {
      points.push(@graph.Point::new(p.x, p.y))
    }
    result.edges[edge.index] = @engine_api.EdgeLayout::new(points)
    match edge.label_box {
      Some(b) =>
        result.edge_labels[edge.index] = @engine_api.NodeLayout::from_box(b)
      None => ()
    }
  }
  for ab in graph.activation_boxes {
    result.activation_boxes.push((ab.0, @engine_api.NodeLayout::from_box(ab.1)))
  }
  for note in graph.sequence_notes {
    result.sequence_notes.push(
      (note.0, note.1, @engine_api.NodeLayout::from_box(note.2)),
    )
  }
  for fragment in graph.sequence_fragments {
    result.sequence_fragments.push(fragment_layout_from_fragment(fragment))
  }
  result
}

///|
fn fragment_layout_from_fragment(
  fragment : SequenceFragment,
) -> @engine_api.SequenceFragmentLayout {
  let operands : Array[@engine_api.FragmentOperandLayout] = []
  for op in fragment.operands {
    operands.push(
      @engine_api.FragmentOperandLayout::new(op.condition, op.separator_y),
    )
  }
  @engine_api.SequenceFragmentLayout::new(
    fragment.fragment_type,
    fragment.condition,
    fragment.bbox,
    fragment.start_index,
    fragment.end_index,
    operands,
  )
}
