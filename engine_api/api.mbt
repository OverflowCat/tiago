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
/// Engine API: layout contract shared between layout engines and exporters.
///
/// The layout pipeline is intentionally functional:
/// - engines take an immutable graph
/// - engines return a `@graph.LayoutPatch`
/// - callers apply the patch to obtain a new graph

///|
/// Layout configuration
pub struct LayoutConfig {
  /// Horizontal spacing between objects
  horizontal_spacing : Double
  /// Vertical spacing between objects
  vertical_spacing : Double
  /// Padding inside containers
  container_padding : Double
  /// Default object width
  default_width : Double
  /// Default object height
  default_height : Double
  /// Edge padding from objects
  edge_padding : Double
} derive(Show)

///|
/// Layout direction
pub(all) enum Direction {
  Down
  Right
  Up
  Left
} derive(Eq, Show)

///|
/// Layout error
pub suberror LayoutError {
  InvalidGraph(String)
  CycleDetected(String)
  Unsupported(String)
} derive(Eq, Show)

///|
/// Construct an `engine_api.LayoutError` from outside this package.
pub fn invalid_graph(message : String) -> LayoutError {
  LayoutError::InvalidGraph(message)
}

///|
pub fn cycle_detected(message : String) -> LayoutError {
  LayoutError::CycleDetected(message)
}

///|
pub fn unsupported(message : String) -> LayoutError {
  LayoutError::Unsupported(message)
}

///|
pub fn LayoutConfig::new() -> LayoutConfig {
  {
    horizontal_spacing: 60.0,
    vertical_spacing: 60.0,
    container_padding: 20.0,
    default_width: 100.0,
    default_height: 60.0,
    edge_padding: 20.0,
  }
}

///|
pub fn LayoutConfig::with_spacing(
  horizontal : Double,
  vertical : Double,
) -> LayoutConfig {
  let config = LayoutConfig::new()
  { ..config, horizontal_spacing: horizontal, vertical_spacing: vertical }
}

///|
/// Layout engine interface.
///
/// Engines must not mutate their input graph. They return a patch that can be
/// applied by the caller.
pub(open) trait LayoutEngine {
  layout(Self, @graph.GraphInput, LayoutConfig, Direction) -> @graph.LayoutPatch raise LayoutError
}

///|
fn get_short_id(id : String) -> String {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot >= 0 && last_dot < id.length() - 1 {
    let buf = StringBuilder::new()
    for i = last_dot + 1; i < id.length(); i = i + 1 {
      match id[i].to_char() {
        Some(c) => buf.write_char(c)
        None => ()
      }
    }
    buf.to_string()
  } else {
    id
  }
}

///|
fn get_parent_id(id : String) -> String? {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot <= 0 {
    return None
  }
  let buf = StringBuilder::new()
  for i = 0; i < last_dot; i = i + 1 {
    match id[i].to_char() {
      Some(c) => buf.write_char(c)
      None => ()
    }
  }
  Some(buf.to_string())
}

///|
fn normalize_sequence_root(graph : @graph.GraphInput) -> @graph.GraphInput {
  if graph.root.shape_type != @graph.SequenceDiagram {
    return graph
  }
  let child_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    for child_id in obj.child_ids {
      child_ids[child_id] = true
    }
  }
  let root_child_ids : Array[String] = []
  for obj in graph.objects {
    if not(child_ids.contains(obj.id)) {
      root_child_ids.push(obj.id)
    }
  }
  let r = graph.root
  let root = @graph.ObjectInput::from_parts(
    r.id,
    r.label,
    r.shape_type,
    r.style,
    r.box,
    r.label_box,
    root_child_ids,
    r.z_index,
    r.icon,
    r.tooltip,
    r.link,
    r.classes,
    r.grid_rows,
    r.grid_columns,
    r.grid_gap,
    r.horizontal_gap,
    r.vertical_gap,
    r.grid_column_span,
    r.grid_row_span,
    r.near,
  )
  @graph.GraphInput::from_parts(
    graph.name,
    root,
    graph.objects,
    graph.edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
  )
}

///|
fn find_sql_column_index(
  object_by_id : Map[String, @graph.ObjectInput],
  field_id : String,
) -> Int? {
  let parent_id = match get_parent_id(field_id) {
    Some(p) => p
    None => return None
  }
  let parent = match object_by_id.get(parent_id) {
    Some(p) => p
    None => return None
  }
  if parent.shape_type != @graph.SqlTable {
    return None
  }
  let field_name = get_short_id(field_id)
  let mut i = 0
  for child_id in parent.child_ids {
    if get_short_id(child_id) == field_name {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn assign_sql_column_indices(graph : @graph.GraphInput) -> @graph.GraphInput {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.id] = graph.root
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  let edges : Array[@graph.EdgeInput] = []
  for e in graph.edges {
    let src_column_index = find_sql_column_index(object_by_id, e.src_id)
    let dst_column_index = find_sql_column_index(object_by_id, e.dst_id)
    edges.push(
      @graph.EdgeInput::from_parts(
        e.index,
        e.src_id,
        e.dst_id,
        e.src_arrow,
        e.dst_arrow,
        e.src_arrowhead,
        e.dst_arrowhead,
        e.src_anchor,
        e.dst_anchor,
        e.label,
        e.style,
        e.route,
        e.bend_points,
        e.is_curve,
        e.z_index,
        e.reference_count,
        e.label_box,
        src_column_index,
        dst_column_index,
      ),
    )
  }
  @graph.GraphInput::from_parts(
    graph.name,
    graph.root,
    graph.objects,
    edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
  )
}

///|
fn prepare_graph_for_layout(graph : @graph.GraphInput) -> @graph.GraphInput {
  let graph = normalize_sequence_root(graph)
  assign_sql_column_indices(graph)
}

///|
fn ensure_orthogonal_route(route : Array[@graph.Point]) -> Array[@graph.Point] {
  if route.length() != 2 {
    return route
  }
  let p0 = route[0]
  let p1 = route[1]
  let dx = (p1.x - p0.x).abs()
  let dy = (p1.y - p0.y).abs()
  if dx < 1.0 || dy < 1.0 {
    return route
  }
  [p0, @graph.Point::new(p0.x, p1.y), p1]
}

///|
fn normalize_routes(graph : @graph.GraphInput) -> @graph.GraphInput {
  let edges : Array[@graph.EdgeInput] = []
  for e in graph.edges {
    let route = ensure_orthogonal_route(e.route)
    edges.push(
      @graph.EdgeInput::from_parts(
        e.index,
        e.src_id,
        e.dst_id,
        e.src_arrow,
        e.dst_arrow,
        e.src_arrowhead,
        e.dst_arrowhead,
        e.src_anchor,
        e.dst_anchor,
        e.label,
        e.style,
        route,
        e.bend_points,
        e.is_curve,
        e.z_index,
        e.reference_count,
        e.label_box,
        e.src_column_index,
        e.dst_column_index,
      ),
    )
  }
  @graph.GraphInput::from_parts(
    graph.name,
    graph.root,
    graph.objects,
    edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
  )
}

///|
/// Perform layout on a graph (including variants) with a specific engine.
///
/// Returns a new graph with layout applied.
pub fn[Engine : LayoutEngine] layout_with_engine(
  engine : Engine,
  graph : @graph.GraphInput,
  config : LayoutConfig,
  direction : Direction,
) -> @graph.GraphInput raise LayoutError {
  let prepared = prepare_graph_for_layout(graph)
  let patch = engine.layout(prepared, config, direction)
  let laid_out = @graph.apply_layout(prepared, patch)
  let layers : Array[@graph.LayerInput] = []
  for layer in laid_out.layers {
    layers.push(
      @graph.LayerInput::new(
        layer.name,
        layout_with_engine(engine, layer.graph, config, direction),
      ),
    )
  }
  let scenarios : Array[@graph.ScenarioInput] = []
  for scenario in laid_out.scenarios {
    scenarios.push(
      @graph.ScenarioInput::new(
        scenario.name,
        layout_with_engine(engine, scenario.graph, config, direction),
      ),
    )
  }
  let steps : Array[@graph.StepInput] = []
  for step in laid_out.steps {
    steps.push(
      @graph.StepInput::new(
        step.name,
        layout_with_engine(engine, step.graph, config, direction),
      ),
    )
  }
  normalize_routes(
    @graph.GraphInput::from_parts(
      laid_out.name,
      laid_out.root,
      laid_out.objects,
      laid_out.edges,
      laid_out.sequence_fragments,
      laid_out.activation_boxes,
      laid_out.sequence_notes,
      laid_out.sequence_fragments_layout,
      layers,
      scenarios,
      steps,
      laid_out.legend,
    ),
  )
}
