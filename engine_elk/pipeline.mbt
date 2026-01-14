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
fn reset_graph_layout_state(graph : Graph) -> Unit {
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
fn default_layered_pipeline() -> LayeredPipeline {
  let builder = LayeredPipelineBuilder::new()
  builder.add("elk.layered.layout", BeforePhase5, fn(graph, ctx) {
    run_elk_layout(graph, ctx.config, ctx.direction)
  })
  builder.add("elk.layered.position_sql_table_children", AfterPhase5, fn(
    graph,
    _ctx,
  ) {
    position_sql_table_children(graph)
  })
  builder.add("elk.layered.route_edges", AfterPhase5, fn(graph, ctx) {
    route_all_edges(graph, ctx.config, ctx.direction)
  })
  builder.add("elk.layered.normalize_coordinates", AfterPhase5, fn(
    graph,
    _ctx,
  ) {
    normalize_coordinates(graph)
  })
  builder.add("elk.layered.position_edge_labels", AfterPhase5, fn(graph, ctx) {
    position_edge_labels(graph, ctx.config)
  })
  builder.build()
}

///|
fn layout_graph(
  graph : Graph,
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
  let pipeline = default_layered_pipeline()
  pipeline.run(graph, { config, direction })
}

///|
/// Convenience wrapper: layout a graph and return a new graph.
pub fn layout(
  graph : GraphInput,
  config : LayoutConfig,
  direction : Direction,
) -> GraphInput raise LayoutError {
  @engine_api.layout_with_engine(ElkEngine::new(), graph, config, direction)
}
