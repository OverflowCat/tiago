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
/// Nested diagram orchestration for non-root nested diagram containers.
///
/// Upstream reference:
/// - `LayoutNested`
/// - the nested diagram types fixture
///
/// The core layout engines in diago only special-case a subset of root-level
/// diagram kinds. This helper mirrors the upstream nested-layout flow by
/// extracting nested diagram subgraphs, recursively laying them out, using the
/// laid out bounds as outer placeholders, and then restoring descendants and
/// extracted edges in original source order.

///|
priv struct NestedSequenceContext {
  container_order : Array[String]
  graphs_by_container_id : Map[String, @graph.GraphInput]
  constant_near_order : Array[String]
  constant_near_graphs_by_container_id : Map[String, @graph.GraphInput]
  descendant_container_by_id : Map[String, String]
  internal_edge_container_by_index : Map[Int, String]
  external_edge_indices : Map[Int, Bool]
}

///|
fn empty_nested_sequence_context() -> NestedSequenceContext {
  {
    container_order: [],
    graphs_by_container_id: {},
    constant_near_order: [],
    constant_near_graphs_by_container_id: {},
    descendant_container_by_id: {},
    internal_edge_container_by_index: {},
    external_edge_indices: {},
  }
}

///|
fn[Engine : LayoutEngine] prepare_nested_sequence_layouts(
  engine : Engine,
  graph : @graph.GraphInput,
  config : LayoutConfig,
  direction : Direction,
) -> (@graph.GraphInput, NestedSequenceContext) raise LayoutError {
  let candidate_ids = collect_nested_sequence_candidate_ids(graph)
  if candidate_ids.is_empty() {
    return (graph, empty_nested_sequence_context())
  }

  let context = empty_nested_sequence_context()
  let mut prepared_graph = graph
  for container_id in candidate_ids {
    let prepared_object_by_id = build_object_by_abs_id_syntax(prepared_graph)
    let container = match prepared_object_by_id.get(container_id) {
      Some(obj) => obj
      None => continue
    }
    let is_constant_near = is_constant_near_candidate_like_d2(
      prepared_graph, container,
    )
    let is_root_grid_cell_container = is_root_grid_cell_container_like_d2(
        prepared_graph, container,
      ) &&
      !is_constant_near
    if is_constant_near {
      let original_near = container.near
      let (prepared_without_nested, constant_near_graph, external_edge_indices) = extract_constant_near_graph_like_d2(
        prepared_graph, container_id,
      )
      let laid_out_constant_near = layout_with_engine(
        engine,
        clear_constant_near_for_nested_layout_like_d2(
          constant_near_graph, container_id,
        ),
        config,
        direction,
      )
      let laid_out_constant_near = restore_constant_near_after_layout_like_d2(
        laid_out_constant_near, container_id, original_near,
      )
      prepared_graph = prepared_without_nested
      context.constant_near_order.push(container_id)
      context.constant_near_graphs_by_container_id[container_id] = laid_out_constant_near
      for edge_index, _ in external_edge_indices {
        context.external_edge_indices[edge_index] = true
      }
      continue
    }
    let (
      prepared_without_nested,
      descendant_graph,
      descendant_ids,
      internal_edge_indices,
      external_edge_indices,
    ) = extract_nested_sequence_graph(prepared_graph, container_id)
    if is_root_grid_cell_container {
      let include_self_graph = extract_nested_include_self_graph_like_d2(
        prepared_graph, container_id,
      )
      let laid_out_include_self = layout_with_engine(
        engine, include_self_graph, config, direction,
      )
      let (placeholder_root, finalized_nested) = finalize_grid_cell_container_like_d2(
        prepared_graph, laid_out_include_self, descendant_graph, container_id, internal_edge_indices,
      )
      prepared_graph = install_nested_sequence_placeholder_object(
        prepared_without_nested, placeholder_root,
      )
      context.container_order.push(container_id)
      context.graphs_by_container_id[container_id] = finalized_nested
      for descendant_id, _ in descendant_ids {
        context.descendant_container_by_id[descendant_id] = container_id
      }
      for edge_index, _ in internal_edge_indices {
        context.internal_edge_container_by_index[edge_index] = container_id
      }
      for edge_index, _ in external_edge_indices {
        context.external_edge_indices[edge_index] = true
      }
      continue
    }
    let nested_graph = descendant_graph
    let laid_out_nested = layout_with_engine(
      engine, nested_graph, config, direction,
    )
    let finalized_nested = finalize_nested_sequence_graph(laid_out_nested)
    let placeholder_box = match finalized_nested.root.box {
      Some(box) => box
      None => @graph.Box::zero()
    }
    prepared_graph = install_nested_sequence_placeholder(
      prepared_without_nested, container_id, placeholder_box,
    )
    context.container_order.push(container_id)
    context.graphs_by_container_id[container_id] = finalized_nested
    for descendant_id, _ in descendant_ids {
      context.descendant_container_by_id[descendant_id] = container_id
    }
    for edge_index, _ in internal_edge_indices {
      context.internal_edge_container_by_index[edge_index] = container_id
    }
    for edge_index, _ in external_edge_indices {
      context.external_edge_indices[edge_index] = true
    }
  }
  (prepared_graph, context)
}

///|
fn restore_nested_sequence_layouts(
  original_graph : @graph.GraphInput,
  laid_out_graph : @graph.GraphInput,
  context : NestedSequenceContext,
) -> @graph.GraphInput {
  if context.container_order.is_empty() &&
    context.constant_near_order.is_empty() {
    return laid_out_graph
  }

  let laid_out_graph = apply_constant_near_graphs_like_d2(
    laid_out_graph, context,
  )

  let container_ids : Map[String, Bool] = {}
  let shifted_nested_object_by_id : Map[String, @graph.ObjectInput] = {}
  let shifted_nested_edge_by_index : Map[Int, @graph.EdgeInput] = {}
  let shifted_activation_boxes : Array[(String, @graph.Box)] = []
  let shifted_sequence_notes : Array[(String, String, @graph.Box)] = []
  let shifted_sequence_fragments : Array[@graph.SequenceFragmentLayout] = []
  let laid_out_object_by_id = build_object_by_abs_id_syntax(laid_out_graph)
  for container_id in context.container_order {
    container_ids[container_id] = true
    let nested_graph = match context.graphs_by_container_id.get(container_id) {
      Some(graph) => graph
      None => continue
    }
    let container = match laid_out_object_by_id.get(container_id) {
      Some(obj) => obj
      None => continue
    }
    let (dx, dy) = match container.box {
      Some(box) => (box.x, box.y)
      None => (0.0, 0.0)
    }
    let shifted_graph = shift_nested_sequence_graph(nested_graph, dx, dy)
    for obj in shifted_graph.objects {
      shifted_nested_object_by_id[obj.abs_id_syntax] = obj
    }
    for edge in shifted_graph.edges {
      shifted_nested_edge_by_index[edge.index] = edge
    }
    for activation in shifted_graph.activation_boxes {
      shifted_activation_boxes.push(activation)
    }
    for note in shifted_graph.sequence_notes {
      shifted_sequence_notes.push(note)
    }
    for fragment in shifted_graph.sequence_fragments_layout {
      shifted_sequence_fragments.push(fragment)
    }
  }

  let objects : Array[@graph.ObjectInput] = []
  let final_object_by_id : Map[String, @graph.ObjectInput] = {}
  final_object_by_id[original_graph.root.abs_id_syntax] = clone_object_with_parts(
    laid_out_graph.root,
    laid_out_graph.root.box,
    original_graph.root.child_ids,
  )
  for original_obj in original_graph.objects {
    let final_obj = match
      context.descendant_container_by_id.get(original_obj.abs_id_syntax) {
      Some(_) =>
        match shifted_nested_object_by_id.get(original_obj.abs_id_syntax) {
          Some(obj) => obj
          None => original_obj
        }
      None =>
        match laid_out_object_by_id.get(original_obj.abs_id_syntax) {
          Some(laid_out_obj) =>
            if container_ids.contains(original_obj.abs_id_syntax) {
              clone_object_with_parts_and_label(
                laid_out_obj,
                laid_out_obj.box,
                None,
                original_obj.child_ids,
              )
            } else {
              laid_out_obj
            }
          None => original_obj
        }
    }
    final_object_by_id[final_obj.abs_id_syntax] = final_obj
    objects.push(final_obj)
  }

  let laid_out_edge_by_index : Map[Int, @graph.EdgeInput] = {}
  for edge in laid_out_graph.edges {
    laid_out_edge_by_index[edge.index] = edge
  }
  let edges : Array[@graph.EdgeInput] = []
  for original_edge in original_graph.edges {
    let edge = if context.external_edge_indices.contains(original_edge.index) {
      route_nested_external_edge(original_edge, final_object_by_id)
    } else {
      match context.internal_edge_container_by_index.get(original_edge.index) {
        Some(_) =>
          match shifted_nested_edge_by_index.get(original_edge.index) {
            Some(edge) => edge
            None => original_edge
          }
        None =>
          match laid_out_edge_by_index.get(original_edge.index) {
            Some(edge) => edge
            None => original_edge
          }
      }
    }
    edges.push(edge)
  }

  let activation_boxes : Array[(String, @graph.Box)] = []
  for activation in laid_out_graph.activation_boxes {
    activation_boxes.push(activation)
  }
  for activation in shifted_activation_boxes {
    activation_boxes.push(activation)
  }

  let sequence_notes : Array[(String, String, @graph.Box)] = []
  for note in laid_out_graph.sequence_notes {
    sequence_notes.push(note)
  }
  for note in shifted_sequence_notes {
    sequence_notes.push(note)
  }

  let sequence_fragments_layout : Array[@graph.SequenceFragmentLayout] = []
  for fragment in laid_out_graph.sequence_fragments_layout {
    sequence_fragments_layout.push(fragment)
  }
  for fragment in shifted_sequence_fragments {
    sequence_fragments_layout.push(fragment)
  }

  let root = final_object_by_id.get_or_default(
    original_graph.root.abs_id_syntax,
    laid_out_graph.root,
  )
  clone_graph_with_sequence_parts(
    laid_out_graph, root, objects, edges, activation_boxes, sequence_notes, sequence_fragments_layout,
  )
}

///|
fn collect_nested_sequence_candidate_ids(
  graph : @graph.GraphInput,
) -> Array[String] {
  let object_by_id = build_object_by_abs_id_syntax(graph)
  let queue : Array[String] = []
  for child_id in graph.root.child_ids {
    if object_by_id.contains(child_id) {
      queue.push(child_id)
    }
  }
  let candidate_ids : Array[String] = []
  let mut index = 0
  while index < queue.length() {
    let current_id = queue[index]
    index += 1
    match object_by_id.get(current_id) {
      Some(current) => {
        let is_constant_near = is_constant_near_candidate_like_d2(
          graph, current,
        )
        let is_root_grid_cell_container = is_root_grid_cell_container_like_d2(
            graph, current,
          ) &&
          !is_constant_near
        if is_root_grid_cell_container || is_constant_near {
          candidate_ids.push(current.abs_id_syntax)
        } else if is_nested_diagram_candidate_like_d2(current) &&
          !current.child_ids.is_empty() {
          candidate_ids.push(current.abs_id_syntax)
        } else {
          for child_id in current.child_ids {
            if object_by_id.contains(child_id) {
              queue.push(child_id)
            }
          }
        }
      }
      None => ()
    }
  }
  candidate_ids
}

///|
fn is_root_grid_cell_container_like_d2(
  graph : @graph.GraphInput,
  obj : @graph.ObjectInput,
) -> Bool {
  (graph.root.grid_rows is Some(_) || graph.root.grid_columns is Some(_)) &&
  graph.root.child_ids.contains(obj.abs_id_syntax) &&
  !obj.child_ids.is_empty() &&
  !is_nested_diagram_candidate_like_d2(obj)
}

///|
fn graph_root_level_like_d2(graph : @graph.GraphInput) -> Int {
  if graph.root.child_ids.is_empty() {
    return 0
  }
  let mut min_depth = 1000000000
  for child_id in graph.root.child_ids {
    let depth = @graph.syntax_path_depth(child_id)
    if depth < min_depth {
      min_depth = depth
    }
  }
  if min_depth <= 0 {
    0
  } else {
    min_depth - 1
  }
}

///|
fn is_constant_near_candidate_like_d2(
  graph : @graph.GraphInput,
  obj : @graph.ObjectInput,
) -> Bool {
  if graph_root_level_like_d2(graph) != 0 {
    return false
  }
  match obj.near {
    Some(raw) => is_constant_near_key_like_d2(raw.to_lower())
    None => false
  }
}

///|
fn is_nested_diagram_candidate_like_d2(obj : @graph.ObjectInput) -> Bool {
  obj.shape_type == @graph.SequenceDiagram ||
  obj.grid_rows is Some(_) ||
  obj.grid_columns is Some(_)
}

///|
fn extract_constant_near_graph_like_d2(
  graph : @graph.GraphInput,
  container_id : String,
) -> (@graph.GraphInput, @graph.GraphInput, Map[Int, Bool]) raise LayoutError {
  let object_by_id = build_object_by_abs_id_syntax(graph)
  guard object_by_id.get(container_id) is Some(_) else {
    raise invalid_graph("constant near container not found: \{container_id}")
  }
  let subtree_ids = collect_descendant_ids(object_by_id, [container_id])
  let parent_id_by_child_id = build_parent_id_by_child_abs_id_syntax(graph)
  let parent_id = parent_id_by_child_id.get(container_id)
  let subtree_semantic_ids : Map[String, Bool] = {}
  let nested_objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if subtree_ids.contains(obj.abs_id_syntax) {
      subtree_semantic_ids[obj.id] = true
      nested_objects.push(obj)
    }
  }
  let nested_edges : Array[@graph.EdgeInput] = []
  let outer_edges : Array[@graph.EdgeInput] = []
  let external_edge_indices : Map[Int, Bool] = {}
  for edge in graph.edges {
    let src_nested = subtree_ids.contains(edge.src_id_syntax)
    let dst_nested = subtree_ids.contains(edge.dst_id_syntax)
    if src_nested && dst_nested {
      nested_edges.push(edge)
    } else if src_nested || dst_nested {
      external_edge_indices[edge.index] = true
    } else {
      outer_edges.push(edge)
    }
  }
  let outer_root_child_ids = match parent_id {
    Some(parent) if parent == graph.root.abs_id_syntax =>
      remove_child_id_like_d2(graph.root.child_ids, container_id)
    _ => graph.root.child_ids
  }
  let outer_root = clone_object_with_parts(
    graph.root,
    graph.root.box,
    outer_root_child_ids,
  )
  let outer_objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if subtree_ids.contains(obj.abs_id_syntax) {
      continue
    }
    let child_ids = match parent_id {
      Some(parent) if parent == obj.abs_id_syntax =>
        remove_child_id_like_d2(obj.child_ids, container_id)
      _ => obj.child_ids
    }
    if child_ids == obj.child_ids {
      outer_objects.push(obj)
    } else {
      outer_objects.push(clone_object_with_parts(obj, obj.box, child_ids))
    }
  }
  let nested_activation_boxes : Array[(String, @graph.Box)] = []
  let outer_activation_boxes : Array[(String, @graph.Box)] = []
  for activation in graph.activation_boxes {
    let (id, box) = activation
    if subtree_semantic_ids.contains(id) {
      nested_activation_boxes.push((id, box))
    } else {
      outer_activation_boxes.push((id, box))
    }
  }
  let nested_sequence_notes : Array[(String, String, @graph.Box)] = []
  let outer_sequence_notes : Array[(String, String, @graph.Box)] = []
  for note_entry in graph.sequence_notes {
    let (id, note, box) = note_entry
    if subtree_semantic_ids.contains(id) {
      nested_sequence_notes.push((id, note, box))
    } else {
      outer_sequence_notes.push((id, note, box))
    }
  }
  let outer_graph = @graph.GraphInput::from_parts(
    graph.name,
    outer_root,
    outer_objects,
    outer_edges,
    graph.sequence_fragments,
    outer_activation_boxes,
    outer_sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
    is_folder_only=graph.is_folder_only,
    data=graph.data,
  )
  let nested_graph = extract_nested_include_self_graph_like_d2(
    graph, container_id,
  )
  let nested_graph = clone_graph_with_sequence_parts(
    nested_graph,
    nested_graph.root,
    nested_graph.objects,
    nested_edges,
    nested_activation_boxes,
    nested_sequence_notes,
    [],
  )
  (outer_graph, nested_graph, external_edge_indices)
}

///|
fn remove_child_id_like_d2(
  child_ids : Array[String],
  child_id : String,
) -> Array[String] {
  let filtered : Array[String] = []
  for current in child_ids {
    if current != child_id {
      filtered.push(current)
    }
  }
  filtered
}

///|
fn clear_constant_near_for_nested_layout_like_d2(
  graph : @graph.GraphInput,
  container_id : String,
) -> @graph.GraphInput {
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if obj.abs_id_syntax == container_id {
      objects.push(clone_object_with_near_like_d2(obj, None))
    } else {
      objects.push(obj)
    }
  }
  clone_graph_with_sequence_parts(
    graph,
    graph.root,
    objects,
    graph.edges,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
  )
}

///|
fn clone_object_with_near_like_d2(
  obj : @graph.ObjectInput,
  near : String?,
) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    obj.id,
    obj.label,
    obj.shape_type,
    obj.style,
    obj.box,
    obj.label_box,
    obj.child_ids,
    obj.z_index,
    obj.icon,
    obj.tooltip,
    obj.link,
    obj.classes,
    obj.grid_rows,
    obj.grid_columns,
    obj.grid_gap,
    obj.horizontal_gap,
    obj.vertical_gap,
    obj.grid_column_span,
    obj.grid_row_span,
    near,
    obj.top,
    obj.left,
    direction=obj.direction,
    language=obj.language,
    sql_constraints=obj.sql_constraints,
    id_val=obj.id_val,
    id_syntax=obj.id_syntax,
    abs_id_syntax=obj.abs_id_syntax,
    references=obj.references,
    icon_position=obj.icon_position,
    tooltip_position=obj.tooltip_position,
    label_position=obj.label_position,
  )
}

///|
fn restore_constant_near_after_layout_like_d2(
  graph : @graph.GraphInput,
  container_id : String,
  near : String?,
) -> @graph.GraphInput {
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if obj.abs_id_syntax == container_id {
      let effective_label_position = match obj.label_position {
        Some(current) => Some(current)
        None =>
          if obj.child_ids.is_empty() {
            None
          } else {
            inferred_label_position_from_layout_like_d2(obj)
          }
      }
      objects.push(
        clone_object_with_parts_and_effective_positions(
          clone_object_with_near_like_d2(obj, near),
          obj.box,
          obj.label_box,
          obj.child_ids,
          effective_label_position,
          obj.icon_position,
        ),
      )
    } else {
      objects.push(obj)
    }
  }
  clone_graph_with_sequence_parts(
    graph,
    graph.root,
    objects,
    graph.edges,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
  )
}

///|
fn extract_nested_sequence_graph(
  graph : @graph.GraphInput,
  container_id : String,
) -> (
  @graph.GraphInput,
  @graph.GraphInput,
  Map[String, Bool],
  Map[Int, Bool],
  Map[Int, Bool],
) raise LayoutError {
  let object_by_id = build_object_by_abs_id_syntax(graph)
  let container = match object_by_id.get(container_id) {
    Some(obj) => obj
    None =>
      raise invalid_graph(
        "nested sequence container not found: \{container_id}",
      )
  }
  let descendant_ids = collect_descendant_ids(object_by_id, container.child_ids)
  let descendant_semantic_ids : Map[String, Bool] = {}
  let nested_root = clone_nested_sequence_root(container)
  let nested_objects : Array[@graph.ObjectInput] = []
  let outer_objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if descendant_ids.contains(obj.abs_id_syntax) {
      descendant_semantic_ids[obj.id] = true
      nested_objects.push(obj)
    } else if obj.abs_id_syntax == container_id {
      outer_objects.push(clone_object_with_parts(obj, obj.box, []))
    } else {
      outer_objects.push(obj)
    }
  }

  let nested_edges : Array[@graph.EdgeInput] = []
  let outer_edges : Array[@graph.EdgeInput] = []
  let internal_edge_indices : Map[Int, Bool] = {}
  let external_edge_indices : Map[Int, Bool] = {}
  for edge in graph.edges {
    let src_nested = descendant_ids.contains(edge.src_id_syntax)
    let dst_nested = descendant_ids.contains(edge.dst_id_syntax)
    if src_nested && dst_nested {
      internal_edge_indices[edge.index] = true
      nested_edges.push(edge)
    } else if src_nested || dst_nested {
      external_edge_indices[edge.index] = true
    } else {
      outer_edges.push(edge)
    }
  }

  let nested_activation_boxes : Array[(String, @graph.Box)] = []
  let outer_activation_boxes : Array[(String, @graph.Box)] = []
  for activation in graph.activation_boxes {
    let (id, box) = activation
    if descendant_semantic_ids.contains(id) {
      nested_activation_boxes.push((id, box))
    } else {
      outer_activation_boxes.push((id, box))
    }
  }

  let nested_sequence_notes : Array[(String, String, @graph.Box)] = []
  let outer_sequence_notes : Array[(String, String, @graph.Box)] = []
  for note_entry in graph.sequence_notes {
    let (id, note, box) = note_entry
    if descendant_semantic_ids.contains(id) {
      nested_sequence_notes.push((id, note, box))
    } else {
      outer_sequence_notes.push((id, note, box))
    }
  }

  let outer_graph = @graph.GraphInput::from_parts(
    graph.name,
    graph.root,
    outer_objects,
    outer_edges,
    graph.sequence_fragments,
    outer_activation_boxes,
    outer_sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
    is_folder_only=graph.is_folder_only,
    data=graph.data,
  )
  let nested_graph = @graph.GraphInput::from_parts(
    graph.name,
    nested_root,
    nested_objects,
    nested_edges,
    [],
    nested_activation_boxes,
    nested_sequence_notes,
    [],
    [],
    [],
    [],
    None,
    is_folder_only=false,
    data={},
  )
  (
    outer_graph, nested_graph, descendant_ids, internal_edge_indices, external_edge_indices,
  )
}

///|
fn collect_descendant_ids(
  object_by_id : Map[String, @graph.ObjectInput],
  child_ids : Array[String],
) -> Map[String, Bool] {
  let descendant_ids : Map[String, Bool] = {}
  let queue : Array[String] = []
  for child_id in child_ids {
    if object_by_id.contains(child_id) {
      queue.push(child_id)
    }
  }
  let mut index = 0
  while index < queue.length() {
    let current_id = queue[index]
    index += 1
    if descendant_ids.contains(current_id) {
      continue
    }
    descendant_ids[current_id] = true
    match object_by_id.get(current_id) {
      Some(obj) =>
        for child_id in obj.child_ids {
          if object_by_id.contains(child_id) {
            queue.push(child_id)
          }
        }
      None => ()
    }
  }
  descendant_ids
}

///|
fn extract_nested_include_self_graph_like_d2(
  graph : @graph.GraphInput,
  container_id : String,
) -> @graph.GraphInput raise LayoutError {
  let object_by_id = build_object_by_abs_id_syntax(graph)
  let container = match object_by_id.get(container_id) {
    Some(obj) => obj
    None =>
      raise invalid_graph(
        "nested include-self container not found: \{container_id}",
      )
  }
  let subtree_ids = collect_descendant_ids(object_by_id, [container_id])
  let subtree_semantic_ids : Map[String, Bool] = {}
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if subtree_ids.contains(obj.abs_id_syntax) {
      subtree_semantic_ids[obj.id] = true
      objects.push(obj)
    }
  }
  let edges : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    if subtree_ids.contains(edge.src_id_syntax) &&
      subtree_ids.contains(edge.dst_id_syntax) {
      edges.push(edge)
    }
  }
  let activation_boxes : Array[(String, @graph.Box)] = []
  for activation in graph.activation_boxes {
    let (id, box) = activation
    if subtree_semantic_ids.contains(id) {
      activation_boxes.push((id, box))
    }
  }
  let sequence_notes : Array[(String, String, @graph.Box)] = []
  for note_entry in graph.sequence_notes {
    let (id, note, box) = note_entry
    if subtree_semantic_ids.contains(id) {
      sequence_notes.push((id, note, box))
    }
  }
  let root = @graph.ObjectInput::from_parts(
    "root",
    "",
    @graph.Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    [container.abs_id_syntax],
    0,
    None,
    None,
    None,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    direction=graph.root.direction,
  )
  @graph.GraphInput::from_parts(
    graph.name,
    root,
    objects,
    edges,
    [],
    activation_boxes,
    sequence_notes,
    [],
    [],
    [],
    [],
    None,
    is_folder_only=false,
    data={},
  )
}

///|
fn finalize_grid_cell_container_like_d2(
  original_graph : @graph.GraphInput,
  laid_out_graph : @graph.GraphInput,
  descendant_graph : @graph.GraphInput,
  container_id : String,
  internal_edge_indices : Map[Int, Bool],
) -> (@graph.ObjectInput, @graph.GraphInput) raise LayoutError {
  let object_by_id = build_object_by_abs_id_syntax(laid_out_graph)
  let container = match object_by_id.get(container_id) {
    Some(obj) => obj
    None =>
      raise invalid_graph(
        "laid out grid cell container not found: \{container_id}",
      )
  }
  let container_box = match container.box {
    Some(box) => box
    None => @graph.Box::zero()
  }
  let dx = -container_box.x
  let dy = -container_box.y
  let placeholder_box = @graph.Box::new(
    0.0,
    0.0,
    container_box.width,
    container_box.height,
  )
  let placeholder_label_box = shift_box_opt(container.label_box, dx, dy)
  let (default_label_position, default_icon_position) = grid_child_effective_positions_like_d2(
    container,
  )
  let effective_label_position = match container.label_position {
    Some(position) => Some(position)
    None => default_label_position
  }
  let effective_icon_position = match container.icon_position {
    Some(position) => Some(position)
    None => default_icon_position
  }
  let placeholder_root = clone_object_with_parts_and_effective_positions(
    container,
    Some(placeholder_box),
    placeholder_label_box,
    [],
    effective_label_position,
    effective_icon_position,
  )
  let nested_objects : Array[@graph.ObjectInput] = []
  for obj in laid_out_graph.objects {
    if obj.abs_id_syntax == container_id {
      continue
    }
    nested_objects.push(
      clone_object_with_parts_and_label(
        obj,
        shift_box_opt(obj.box, dx, dy),
        shift_box_opt(obj.label_box, dx, dy),
        obj.child_ids,
      ),
    )
  }
  let nested_edges : Array[@graph.EdgeInput] = []
  for edge in laid_out_graph.edges {
    if !internal_edge_indices.contains(edge.index) {
      continue
    }
    nested_edges.push(
      clone_edge_with_layout(
        edge,
        shift_route(edge.route, dx, dy),
        shift_points_opt(edge.bend_points, dx, dy),
        shift_box_opt(edge.label_box, dx, dy),
      ),
    )
  }
  let subtree_object_by_id = build_object_by_abs_id_syntax(original_graph)
  let descendant_ids = collect_descendant_ids(
    subtree_object_by_id,
    container.child_ids,
  )
  let descendant_semantic_ids : Map[String, Bool] = {}
  for descendant_id, _ in descendant_ids {
    match subtree_object_by_id.get(descendant_id) {
      Some(obj) => descendant_semantic_ids[obj.id] = true
      None => ()
    }
  }
  let activation_boxes : Array[(String, @graph.Box)] = []
  for activation in laid_out_graph.activation_boxes {
    let (id, box) = activation
    if descendant_semantic_ids.contains(id) {
      activation_boxes.push((id, shift_box(box, dx, dy)))
    }
  }
  let sequence_notes : Array[(String, String, @graph.Box)] = []
  for note_entry in laid_out_graph.sequence_notes {
    let (id, note, box) = note_entry
    if descendant_semantic_ids.contains(id) {
      sequence_notes.push((id, note, shift_box(box, dx, dy)))
    }
  }
  let sequence_fragments_layout : Array[@graph.SequenceFragmentLayout] = []
  for fragment in laid_out_graph.sequence_fragments_layout {
    sequence_fragments_layout.push(shift_fragment_layout(fragment, dx, dy))
  }
  let nested_root = clone_object_with_parts_and_effective_positions(
    placeholder_root,
    Some(placeholder_box),
    placeholder_label_box,
    descendant_graph.root.child_ids,
    effective_label_position,
    effective_icon_position,
  )
  let nested_graph = clone_graph_with_sequence_parts(
    descendant_graph, nested_root, nested_objects, nested_edges, activation_boxes,
    sequence_notes, sequence_fragments_layout,
  )
  (placeholder_root, nested_graph)
}

///|
fn clone_object_with_parts_and_effective_positions(
  obj : @graph.ObjectInput,
  box : @graph.Box?,
  label_box : @graph.Box?,
  child_ids : Array[String],
  label_position : String?,
  icon_position : String?,
) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    obj.id,
    obj.label,
    obj.shape_type,
    obj.style,
    box,
    label_box,
    child_ids,
    obj.z_index,
    obj.icon,
    obj.tooltip,
    obj.link,
    obj.classes,
    obj.grid_rows,
    obj.grid_columns,
    obj.grid_gap,
    obj.horizontal_gap,
    obj.vertical_gap,
    obj.grid_column_span,
    obj.grid_row_span,
    obj.near,
    obj.top,
    obj.left,
    direction=obj.direction,
    language=obj.language,
    sql_constraints=obj.sql_constraints,
    id_val=obj.id_val,
    id_syntax=obj.id_syntax,
    abs_id_syntax=obj.abs_id_syntax,
    references=obj.references,
    icon_position~,
    tooltip_position=obj.tooltip_position,
    label_position~,
  )
}

///|
fn finalize_nested_sequence_graph(
  graph : @graph.GraphInput,
) -> @graph.GraphInput {
  let (min_x, min_y, max_x, max_y, saw_content) = nested_sequence_content_bounds(
    graph,
  )
  let dx = if min_x < 0.0 { -min_x } else { 0.0 }
  let dy = if min_y < 0.0 { -min_y } else { 0.0 }
  let shifted = if dx == 0.0 && dy == 0.0 {
    graph
  } else {
    shift_nested_sequence_graph(graph, dx, dy)
  }
  let placeholder_box = match shifted.root.box {
    Some(box) =>
      if box.width > 0.0 && box.height > 0.0 {
        @graph.Box::new(0.0, 0.0, box.width, box.height)
      } else {
        nested_sequence_placeholder_box(saw_content, max_x + dx, max_y + dy)
      }
    None => nested_sequence_placeholder_box(saw_content, max_x + dx, max_y + dy)
  }
  let root = clone_object_with_parts(
    shifted.root,
    Some(placeholder_box),
    shifted.root.child_ids,
  )
  clone_graph_with_sequence_parts(
    shifted,
    root,
    shifted.objects,
    shifted.edges,
    shifted.activation_boxes,
    shifted.sequence_notes,
    shifted.sequence_fragments_layout,
  )
}

///|
fn nested_sequence_placeholder_box(
  saw_content : Bool,
  max_x : Double,
  max_y : Double,
) -> @graph.Box {
  let width = if saw_content { max_x } else { 0.0 }
  let height = if saw_content { max_y } else { 0.0 }
  @graph.Box::new(0.0, 0.0, width, height)
}

///|
fn nested_sequence_content_bounds(
  graph : @graph.GraphInput,
) -> (Double, Double, Double, Double, Bool) {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut saw_content = false

  let update_point = fn(point : @graph.Point) -> Unit {
    saw_content = true
    if point.x < min_x {
      min_x = point.x
    }
    if point.y < min_y {
      min_y = point.y
    }
    if point.x > max_x {
      max_x = point.x
    }
    if point.y > max_y {
      max_y = point.y
    }
  }
  let update_box = fn(box : @graph.Box) -> Unit {
    saw_content = true
    if box.x < min_x {
      min_x = box.x
    }
    if box.y < min_y {
      min_y = box.y
    }
    if box.x + box.width > max_x {
      max_x = box.x + box.width
    }
    if box.y + box.height > max_y {
      max_y = box.y + box.height
    }
  }

  for obj in graph.objects {
    match obj.box {
      Some(box) => update_box(box)
      None => ()
    }
    match obj.label_box {
      Some(box) => update_box(box)
      None => ()
    }
  }
  for edge in graph.edges {
    for point in edge.route {
      update_point(point)
    }
    match edge.bend_points {
      Some(points) =>
        for point in points {
          update_point(point)
        }
      None => ()
    }
    match edge.label_box {
      Some(box) => update_box(box)
      None => ()
    }
  }
  for activation in graph.activation_boxes {
    let (_, box) = activation
    update_box(box)
  }
  for note_entry in graph.sequence_notes {
    let (_, _, box) = note_entry
    update_box(box)
  }
  for fragment in graph.sequence_fragments_layout {
    match fragment.bbox {
      Some(box) => update_box(box)
      None => ()
    }
    for operand in fragment.operands {
      update_point(@graph.Point::new(0.0, operand.separator_y))
    }
  }

  (min_x, min_y, max_x, max_y, saw_content)
}

///|
fn shift_nested_sequence_graph(
  graph : @graph.GraphInput,
  dx : Double,
  dy : Double,
) -> @graph.GraphInput {
  if dx == 0.0 && dy == 0.0 {
    return graph
  }
  let root = clone_object_with_parts_and_label(
    graph.root,
    shift_box_opt(graph.root.box, dx, dy),
    shift_box_opt(graph.root.label_box, dx, dy),
    graph.root.child_ids,
  )
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    objects.push(
      clone_object_with_parts_and_label(
        obj,
        shift_box_opt(obj.box, dx, dy),
        shift_box_opt(obj.label_box, dx, dy),
        obj.child_ids,
      ),
    )
  }
  let edges : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    edges.push(
      clone_edge_with_layout(
        edge,
        shift_route(edge.route, dx, dy),
        shift_points_opt(edge.bend_points, dx, dy),
        shift_box_opt(edge.label_box, dx, dy),
      ),
    )
  }
  let activation_boxes : Array[(String, @graph.Box)] = []
  for activation in graph.activation_boxes {
    let (id, box) = activation
    activation_boxes.push((id, shift_box(box, dx, dy)))
  }
  let sequence_notes : Array[(String, String, @graph.Box)] = []
  for note_entry in graph.sequence_notes {
    let (id, note, box) = note_entry
    sequence_notes.push((id, note, shift_box(box, dx, dy)))
  }
  let sequence_fragments_layout : Array[@graph.SequenceFragmentLayout] = []
  for fragment in graph.sequence_fragments_layout {
    sequence_fragments_layout.push(shift_fragment_layout(fragment, dx, dy))
  }
  clone_graph_with_sequence_parts(
    graph, root, objects, edges, activation_boxes, sequence_notes, sequence_fragments_layout,
  )
}

///|
fn install_nested_sequence_placeholder(
  graph : @graph.GraphInput,
  container_id : String,
  placeholder_box : @graph.Box,
) -> @graph.GraphInput {
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if obj.abs_id_syntax == container_id {
      objects.push(clone_object_with_parts(obj, Some(placeholder_box), []))
    } else {
      objects.push(obj)
    }
  }
  clone_graph_with_sequence_parts(
    graph,
    graph.root,
    objects,
    graph.edges,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
  )
}

///|
fn install_nested_sequence_placeholder_object(
  graph : @graph.GraphInput,
  placeholder : @graph.ObjectInput,
) -> @graph.GraphInput {
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if obj.abs_id_syntax == placeholder.abs_id_syntax {
      objects.push(placeholder)
    } else {
      objects.push(obj)
    }
  }
  clone_graph_with_sequence_parts(
    graph,
    graph.root,
    objects,
    graph.edges,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
  )
}

///|
fn clone_graph_with_sequence_parts(
  graph : @graph.GraphInput,
  root : @graph.ObjectInput,
  objects : Array[@graph.ObjectInput],
  edges : Array[@graph.EdgeInput],
  activation_boxes : Array[(String, @graph.Box)],
  sequence_notes : Array[(String, String, @graph.Box)],
  sequence_fragments_layout : Array[@graph.SequenceFragmentLayout],
) -> @graph.GraphInput {
  @graph.GraphInput::from_parts(
    graph.name,
    root,
    objects,
    edges,
    graph.sequence_fragments,
    activation_boxes,
    sequence_notes,
    sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
    is_folder_only=graph.is_folder_only,
    data=graph.data,
  )
}

///|
const D2_NEAR_PAD_LIKE_D2 : Double = 20.0

///|
fn apply_constant_near_graphs_like_d2(
  graph : @graph.GraphInput,
  context : NestedSequenceContext,
) -> @graph.GraphInput {
  if context.constant_near_order.is_empty() {
    return graph
  }

  let mut placed_graph = graph
  let placed_near_ids : Map[String, Bool] = {}
  for key_set in [0, 1, 2] {
    let current_set_ids : Array[String] = []
    for container_id in context.constant_near_order {
      let nested_graph = match
        context.constant_near_graphs_by_container_id.get(container_id) {
        Some(current) => current
        None => continue
      }
      let obj = match constant_near_root_object_like_d2(nested_graph) {
        Some(current) => current
        None => continue
      }
      let near_key = match obj.near {
        Some(raw) => raw.to_lower()
        None => continue
      }
      if !near_key_matches_set_like_d2(near_key, key_set) {
        continue
      }
      let box = match obj.box {
        Some(current) => current
        None => continue
      }
      let (min_x, min_y, max_x, max_y) = constant_near_bounding_box_like_d2(
        placed_graph, placed_near_ids,
      )
      let (x, y) = place_constant_near_box_like_d2(
        obj,
        near_key,
        min_x,
        min_y,
        max_x - min_x,
        max_y - min_y,
        box.width,
        box.height,
      )
      let shifted = shift_nested_sequence_graph(
        nested_graph,
        x - box.x,
        y - box.y,
      )
      placed_graph = inject_constant_near_graph_like_d2(placed_graph, shifted)
      current_set_ids.push(container_id)
    }
    for container_id in current_set_ids {
      placed_near_ids[container_id] = true
    }
  }
  placed_graph
}

///|
fn constant_near_root_object_like_d2(
  graph : @graph.GraphInput,
) -> @graph.ObjectInput? {
  if graph.root.child_ids.is_empty() {
    return None
  }
  build_object_by_abs_id_syntax(graph).get(graph.root.child_ids[0])
}

///|
fn inject_constant_near_graph_like_d2(
  graph : @graph.GraphInput,
  nested_graph : @graph.GraphInput,
) -> @graph.GraphInput {
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    objects.push(obj)
  }
  for obj in nested_graph.objects {
    objects.push(obj)
  }
  let edges : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    edges.push(edge)
  }
  for edge in nested_graph.edges {
    edges.push(edge)
  }
  let activation_boxes : Array[(String, @graph.Box)] = []
  for activation in graph.activation_boxes {
    activation_boxes.push(activation)
  }
  for activation in nested_graph.activation_boxes {
    activation_boxes.push(activation)
  }
  let sequence_notes : Array[(String, String, @graph.Box)] = []
  for note in graph.sequence_notes {
    sequence_notes.push(note)
  }
  for note in nested_graph.sequence_notes {
    sequence_notes.push(note)
  }
  let sequence_fragments_layout : Array[@graph.SequenceFragmentLayout] = []
  for fragment in graph.sequence_fragments_layout {
    sequence_fragments_layout.push(fragment)
  }
  for fragment in nested_graph.sequence_fragments_layout {
    sequence_fragments_layout.push(fragment)
  }
  clone_graph_with_sequence_parts(
    graph,
    graph.root,
    objects,
    edges,
    activation_boxes,
    sequence_notes,
    sequence_fragments_layout,
  )
}

///|
fn is_constant_near_key_like_d2(key : String) -> Bool {
  match key {
    "top-left"
    | "top-center"
    | "top-right"
    | "center-left"
    | "center-right"
    | "bottom-left"
    | "bottom-center"
    | "bottom-right" => true
    _ => false
  }
}

///|
fn near_key_matches_set_like_d2(key : String, key_set : Int) -> Bool {
  match key_set {
    0 => key == "top-center" || key == "bottom-center"
    1 => key == "center-left" || key == "center-right"
    _ =>
      key == "top-left" ||
      key == "top-right" ||
      key == "bottom-left" ||
      key == "bottom-right"
  }
}

///|
fn constant_near_bounding_box_like_d2(
  graph : @graph.GraphInput,
  placed_near_ids : Map[String, Bool],
) -> (Double, Double, Double, Double) {
  let mut min_x = 1000000000000.0
  let mut min_y = 1000000000000.0
  let mut max_x = -1000000000000.0
  let mut max_y = -1000000000000.0
  let mut has_bounds = false
  let update_box = fn(box : @graph.Box) -> Unit {
    if box.x < min_x {
      min_x = box.x
    }
    if box.y < min_y {
      min_y = box.y
    }
    if box.x + box.width > max_x {
      max_x = box.x + box.width
    }
    if box.y + box.height > max_y {
      max_y = box.y + box.height
    }
    has_bounds = true
  }
  for obj in graph.objects {
    let box = match obj.box {
      Some(current) => current
      None => continue
    }
    if placed_near_ids.contains(obj.abs_id_syntax) {
      let near_key = match obj.near {
        Some(raw) => raw.to_lower()
        None => continue
      }
      match near_key {
        "top-center" | "bottom-center" => {
          if box.x < min_x {
            min_x = box.x
          }
          if box.x + box.width > max_x {
            max_x = box.x + box.width
          }
          has_bounds = true
        }
        "center-left" | "center-right" => {
          if box.y < min_y {
            min_y = box.y
          }
          if box.y + box.height > max_y {
            max_y = box.y + box.height
          }
          has_bounds = true
        }
        _ => ()
      }
      continue
    }
    if has_outer_near_container_like_d2(obj.abs_id_syntax, placed_near_ids) {
      continue
    }
    update_box(box)
    match obj.label_box {
      Some(label_box) => {
        let label_position = match obj.label_position {
          Some(current) => current
          None => ""
        }
        if !label_position.contains("INSIDE") {
          update_box(label_box)
        }
      }
      None => ()
    }
  }
  for edge in graph.edges {
    if has_outer_near_container_like_d2(edge.src_id_syntax, placed_near_ids) ||
      has_outer_near_container_like_d2(edge.dst_id_syntax, placed_near_ids) {
      continue
    }
    for point in edge.route {
      if point.x < min_x {
        min_x = point.x
      }
      if point.y < min_y {
        min_y = point.y
      }
      if point.x > max_x {
        max_x = point.x
      }
      if point.y > max_y {
        max_y = point.y
      }
      has_bounds = true
    }
  }
  if !has_bounds {
    return (0.0, 0.0, 0.0, 0.0)
  }
  if min_x > max_x {
    min_x = 0.0
    max_x = 0.0
  }
  if min_y > max_y {
    min_y = 0.0
    max_y = 0.0
  }
  (min_x, min_y, max_x, max_y)
}

///|
fn has_outer_near_container_like_d2(
  obj_id : String,
  placed_near_ids : Map[String, Bool],
) -> Bool {
  for near_id, _ in placed_near_ids {
    if obj_id != near_id && obj_id.has_prefix(near_id + ".") {
      return true
    }
  }
  false
}

///|
fn place_constant_near_box_like_d2(
  obj : @graph.ObjectInput,
  near_key : String,
  min_x : Double,
  min_y : Double,
  width : Double,
  height : Double,
  box_width : Double,
  box_height : Double,
) -> (Double, Double) {
  let (x, y) = match near_key {
    "top-left" =>
      (
        min_x - box_width - D2_NEAR_PAD_LIKE_D2,
        min_y - box_height - D2_NEAR_PAD_LIKE_D2,
      )
    "top-center" =>
      (
        min_x + width / 2.0 - box_width / 2.0,
        min_y - box_height - D2_NEAR_PAD_LIKE_D2,
      )
    "top-right" =>
      (
        min_x + width + D2_NEAR_PAD_LIKE_D2,
        min_y - box_height - D2_NEAR_PAD_LIKE_D2,
      )
    "center-left" =>
      (
        min_x - box_width - D2_NEAR_PAD_LIKE_D2,
        min_y + height / 2.0 - box_height / 2.0,
      )
    "center-right" =>
      (
        min_x + width + D2_NEAR_PAD_LIKE_D2,
        min_y + height / 2.0 - box_height / 2.0,
      )
    "bottom-left" =>
      (
        min_x - box_width - D2_NEAR_PAD_LIKE_D2,
        min_y + height + D2_NEAR_PAD_LIKE_D2,
      )
    "bottom-center" =>
      (
        min_x + width / 2.0 - box_width / 2.0,
        min_y + height + D2_NEAR_PAD_LIKE_D2,
      )
    "bottom-right" =>
      (
        min_x + width + D2_NEAR_PAD_LIKE_D2,
        min_y + height + D2_NEAR_PAD_LIKE_D2,
      )
    _ => (min_x, min_y)
  }
  adjust_constant_near_for_label_like_d2(obj, near_key, x, y)
}

///|
fn adjust_constant_near_for_label_like_d2(
  obj : @graph.ObjectInput,
  near_key : String,
  x : Double,
  y : Double,
) -> (Double, Double) {
  let label_position = match obj.label_position {
    Some(current) => current
    None =>
      match inferred_label_position_from_layout_like_d2(obj) {
        Some(current) => current
        None => return (x, y)
      }
  }
  if label_position.contains("INSIDE") {
    return (x, y)
  }
  let (label_width, label_height) = match obj.label_box {
    Some(box) => (box.width, box.height)
    None => object_label_dimensions_like_d2(obj, 0.0)
  }
  if label_width <= 0.0 || label_height <= 0.0 {
    return (x, y)
  }
  if label_position.contains("_TOP_") {
    if near_key.contains("bottom") {
      (x, y + label_height)
    } else {
      (x, y)
    }
  } else if label_position.contains("_LEFT_") {
    if near_key.contains("right") {
      (x + label_width, y)
    } else {
      (x, y)
    }
  } else if label_position.contains("_RIGHT_") {
    if near_key.contains("left") {
      (x - label_width, y)
    } else {
      (x, y)
    }
  } else if label_position.contains("_BOTTOM_") {
    if near_key.contains("top") {
      (x, y - label_height)
    } else {
      (x, y)
    }
  } else {
    (x, y)
  }
}

///|
fn route_nested_external_edge(
  edge : @graph.EdgeInput,
  object_by_id : Map[String, @graph.ObjectInput],
) -> @graph.EdgeInput {
  let route = match
    (object_by_id.get(edge.src_id_syntax), object_by_id.get(edge.dst_id_syntax)) {
    (Some(src), Some(dst)) =>
      match (src.box, dst.box) {
        (Some(src_box), Some(dst_box)) =>
          clip_default_route_like_d2(
            [src_box.center(), dst_box.center()],
            src_box,
            dst_box,
          )
        _ => edge.route
      }
    _ => edge.route
  }
  clone_edge_with_layout(edge, route, None, None)
}

///|
fn clip_default_route_like_d2(
  route : Array[@graph.Point],
  src_box : @graph.Box,
  dst_box : @graph.Box,
) -> Array[@graph.Point] {
  if route.length() < 2 {
    return route
  }
  let clipped : Array[@graph.Point] = []
  for point in route {
    clipped.push(point)
  }
  clipped[0] = box_border_point_towards_like_d2(src_box, clipped[1])
  let last_index = clipped.length() - 1
  clipped[last_index] = box_border_point_towards_like_d2(
    dst_box,
    clipped[last_index - 1],
  )
  clipped
}

///|
fn box_border_point_towards_like_d2(
  box : @graph.Box,
  target : @graph.Point,
) -> @graph.Point {
  let center = box.center()
  let dx = target.x - center.x
  let dy = target.y - center.y
  if dx.abs() <= 1.0e-9 && dy.abs() <= 1.0e-9 {
    return center
  }

  let large = 1.0e18
  let tx = if dx.abs() > 1.0e-9 {
    if dx > 0.0 {
      (box.x + box.width - center.x) / dx
    } else {
      (box.x - center.x) / dx
    }
  } else {
    large
  }
  let ty = if dy.abs() > 1.0e-9 {
    if dy > 0.0 {
      (box.y + box.height - center.y) / dy
    } else {
      (box.y - center.y) / dy
    }
  } else {
    large
  }
  let t = if ty < tx { ty } else { tx }
  let t = if t < 0.0 { 0.0 } else { t }
  @graph.Point::new(center.x + dx * t, center.y + dy * t)
}

///|
fn shift_fragment_layout(
  fragment : @graph.SequenceFragmentLayout,
  dx : Double,
  dy : Double,
) -> @graph.SequenceFragmentLayout {
  let operands : Array[@graph.FragmentOperandLayout] = []
  for operand in fragment.operands {
    operands.push(
      @graph.FragmentOperandLayout::new(
        operand.condition,
        operand.separator_y + dy,
      ),
    )
  }
  @graph.SequenceFragmentLayout::new(
    fragment.fragment_type,
    fragment.condition,
    shift_box_opt(fragment.bbox, dx, dy),
    fragment.start_index,
    fragment.end_index,
    operands,
  )
}

///|
fn clone_nested_sequence_root(obj : @graph.ObjectInput) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    obj.id,
    obj.label,
    obj.shape_type,
    obj.style,
    None,
    None,
    obj.child_ids,
    obj.z_index,
    obj.icon,
    obj.tooltip,
    obj.link,
    obj.classes,
    obj.grid_rows,
    obj.grid_columns,
    obj.grid_gap,
    obj.horizontal_gap,
    obj.vertical_gap,
    obj.grid_column_span,
    obj.grid_row_span,
    None,
    None,
    None,
    direction=obj.direction,
    language=obj.language,
    sql_constraints=obj.sql_constraints,
    id_val=obj.id_val,
    id_syntax=obj.id_syntax,
    abs_id_syntax=obj.abs_id_syntax,
    references=obj.references,
    icon_position=obj.icon_position,
    tooltip_position=obj.tooltip_position,
    label_position=obj.label_position,
  )
}

///|
fn clone_edge_with_layout(
  edge : @graph.EdgeInput,
  route : Array[@graph.Point],
  bend_points : Array[@graph.Point]?,
  label_box : @graph.Box?,
) -> @graph.EdgeInput {
  @graph.EdgeInput::from_parts(
    edge.index,
    edge.src_id,
    edge.dst_id,
    edge.src_arrow,
    edge.dst_arrow,
    edge.src_arrowhead,
    edge.dst_arrowhead,
    edge.src_arrowhead_label,
    edge.dst_arrowhead_label,
    edge.src_arrowhead_label_color,
    edge.dst_arrowhead_label_color,
    edge.src_anchor,
    edge.dst_anchor,
    edge.label,
    edge.style,
    route,
    bend_points,
    edge.is_curve,
    edge.z_index,
    edge.reference_count,
    label_box,
    edge.src_column_index,
    edge.dst_column_index,
    src_id_syntax=edge.src_id_syntax,
    dst_id_syntax=edge.dst_id_syntax,
    references=edge.references,
  )
}

///|
fn shift_points_opt(
  points : Array[@graph.Point]?,
  dx : Double,
  dy : Double,
) -> Array[@graph.Point]? {
  match points {
    Some(values) => Some(shift_route(values, dx, dy))
    None => None
  }
}

///|
fn shift_route(
  route : Array[@graph.Point],
  dx : Double,
  dy : Double,
) -> Array[@graph.Point] {
  let shifted : Array[@graph.Point] = []
  for point in route {
    shifted.push(@graph.Point::new(point.x + dx, point.y + dy))
  }
  shifted
}

///|
fn shift_box_opt(box : @graph.Box?, dx : Double, dy : Double) -> @graph.Box? {
  match box {
    Some(value) => Some(shift_box(value, dx, dy))
    None => None
  }
}

///|
fn shift_box(box : @graph.Box, dx : Double, dy : Double) -> @graph.Box {
  @graph.Box::new(box.x + dx, box.y + dy, box.width, box.height)
}
