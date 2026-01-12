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
fn reset_graph_layout_state(graph : @graph.Graph) -> Unit {
  for obj in graph.objects {
    match obj.box {
      Some(b) => obj.box = Some(@graph.Box::new(0.0, 0.0, b.width, b.height))
      None => ()
    }
    match obj.label_box {
      Some(b) =>
        obj.label_box = Some(@graph.Box::new(0.0, 0.0, b.width, b.height))
      None => ()
    }
  }
  for edge in graph.edges {
    edge.route.clear()
    match edge.label_box {
      Some(b) =>
        edge.label_box = Some(@graph.Box::new(0.0, 0.0, b.width, b.height))
      None => ()
    }
    edge.src_port = None
    edge.dst_port = None
  }
  graph.activation_boxes.clear()
  graph.sequence_notes.clear()
  graph.sequence_fragments.clear()
}

///|
fn layout_graph(
  graph : @graph.Graph,
  config : LayoutConfig,
  direction : Direction,
) -> Unit {
  ensure_text_dimensions(graph)
  reset_graph_layout_state(graph)
  if is_sequence_diagram(graph.root) && graph.root.is_container() {
    let result = layout_sequence_with_activations(graph.root, graph, config)
    for box in result.activation_boxes {
      graph.activation_boxes.push((box.actor_id, box.get_box()))
    }
    for note in result.notes {
      graph.sequence_notes.push((note.actor_id, note.text, note.bbox))
    }
    return
  }
  compute_sizes(graph, config)
  for obj in graph.objects {
    if is_sequence_diagram(obj) && obj.is_container() {
      let result = layout_sequence_with_activations(obj, graph, config)
      for box in result.activation_boxes {
        graph.activation_boxes.push((box.actor_id, box.get_box()))
      }
      for note in result.notes {
        graph.sequence_notes.push((note.actor_id, note.text, note.bbox))
      }
    } else if obj.is_grid_diagram() && obj.is_container() {
      layout_grid(obj, config)
    }
  }
  run_elk_layout(graph, config, direction)
  position_sql_table_children(graph)
  fix_node_overlaps(graph, config)
  apply_near_positioning(graph, config)
  route_all_edges(graph, config, direction)
  normalize_coordinates(graph)
  compress_all_routes(graph)
  fix_all_endpoint_approaches(graph)
  position_edge_labels(graph, config)
}

///|
/// Convenience wrapper matching the legacy `layout.layout` API.
pub fn layout(
  graph : @graph.GraphInput,
  config : LayoutConfig,
  direction : Direction,
) -> @engine_api.LayoutOutputs raise LayoutError {
  @engine_api.layout_with_engine(ElkEngine::new(), graph, config, direction)
}
