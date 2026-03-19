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
/// Layout engine capability flags aligned with D2's layout feature model.
pub(all) enum LayoutFeature {
  NearObject
  ContainerDimensions
  TopLeft
  DescendantEdges
} derive(Eq, Show)

///|
/// Layout error
pub(all) suberror LayoutError {
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
    vertical_spacing: 100.0,
    container_padding: 50.0,
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
  engine_name(Self) -> String
  features(Self) -> Array[LayoutFeature]
}

///|
fn direction_from_keyword(raw : String) -> Direction? {
  match raw.to_lower() {
    "down" => Some(Direction::Down)
    "up" => Some(Direction::Up)
    "left" => Some(Direction::Left)
    "right" => Some(Direction::Right)
    _ => None
  }
}

///|
fn graph_layout_direction(
  graph : @graph.GraphInput,
  fallback : Direction,
) -> Direction {
  match graph.root.direction {
    Some(raw) =>
      match direction_from_keyword(raw) {
        Some(direction) => direction
        None => fallback
      }
    None => fallback
  }
}

///|
fn has_layout_feature(
  features : Array[LayoutFeature],
  feature : LayoutFeature,
) -> Bool {
  for current in features {
    if current == feature {
      return true
    }
  }
  false
}

///|
fn build_object_by_abs_id_syntax(
  graph : @graph.GraphInput,
) -> Map[String, @graph.ObjectInput] {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.abs_id_syntax] = graph.root
  for obj in graph.objects {
    object_by_id[obj.abs_id_syntax] = obj
  }
  object_by_id
}

///|
fn build_parent_id_by_child_abs_id_syntax(
  graph : @graph.GraphInput,
) -> Map[String, String] {
  let parent_id_by_child_id : Map[String, String] = {}
  for child_id in graph.root.child_ids {
    parent_id_by_child_id[child_id] = graph.root.abs_id_syntax
  }
  for obj in graph.objects {
    for child_id in obj.child_ids {
      parent_id_by_child_id[child_id] = obj.abs_id_syntax
    }
  }
  parent_id_by_child_id
}

///|
fn is_grid_diagram_object(obj : @graph.ObjectInput) -> Bool {
  obj.grid_rows is Some(_) || obj.grid_columns is Some(_)
}

///|
fn is_container_object(obj : @graph.ObjectInput) -> Bool {
  !obj.child_ids.is_empty()
}

///|
fn has_explicit_dimensions(obj : @graph.ObjectInput) -> Bool {
  match obj.box {
    Some(box) => box.width > 0.0 || box.height > 0.0
    None => false
  }
}

///|
fn is_descendant_of_id(
  obj_id : String,
  ancestor_id : String,
  parent_id_by_child_id : Map[String, String],
) -> Bool {
  let mut current = obj_id
  while true {
    if current == ancestor_id {
      return true
    }
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => current = parent_id
      None => break
    }
  }
  false
}

///|
fn is_inside_sequence_diagram(
  graph : @graph.GraphInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  id : String,
) -> Bool {
  if graph.root.shape_type == @graph.SequenceDiagram {
    return true
  }
  let mut current = id
  while true {
    match object_by_id.get(current) {
      Some(obj) => if obj.shape_type == @graph.SequenceDiagram { return true }
      None => ()
    }
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => current = parent_id
      None => break
    }
  }
  false
}

///|
fn edge_display_id(edge : @graph.EdgeInput) -> String {
  let operator = match (edge.src_arrow, edge.dst_arrow) {
    (false, false) => "--"
    (false, true) => "->"
    (true, false) => "<-"
    (true, true) => "<->"
  }
  "(\{edge.src_id_syntax} \{operator} \{edge.dst_id_syntax})[\{edge.index}]"
}

///|
fn check_feature_support(
  engine_name : String,
  features : Array[LayoutFeature],
  graph : @graph.GraphInput,
) -> Unit raise LayoutError {
  let object_by_id = build_object_by_abs_id_syntax(graph)
  let parent_id_by_child_id = build_parent_id_by_child_abs_id_syntax(graph)

  for obj in graph.objects {
    if (obj.top is Some(_) || obj.left is Some(_)) &&
      !has_layout_feature(features, LayoutFeature::TopLeft) {
      raise unsupported(
        "Object \"\{obj.abs_id_syntax}\" has attribute \"top\" and/or \"left\" set, but layout engine \"\{engine_name}\" does not support locked positions. See https://d2lang.com/tour/layouts/#layout-specific-functionality for more.",
      )
    }
    if has_explicit_dimensions(obj) &&
      is_container_object(obj) &&
      !is_grid_diagram_object(obj) &&
      !has_layout_feature(features, LayoutFeature::ContainerDimensions) {
      raise unsupported(
        "Object \"\{obj.abs_id_syntax}\" has attribute \"width\" and/or \"height\" set, but layout engine \"\{engine_name}\" does not support dimensions set on containers. See https://d2lang.com/tour/layouts/#layout-specific-functionality for more.",
      )
    }
    match obj.near {
      Some(near_key) =>
        if graph.find_object(near_key) is Some(_) &&
          !has_layout_feature(features, LayoutFeature::NearObject) {
          raise unsupported(
            "Object \"\{obj.abs_id_syntax}\" has \"near\" set to another object, but layout engine \"\{engine_name}\" only supports constant values for \"near\". See https://d2lang.com/tour/layouts/#layout-specific-functionality for more.",
          )
        }
      None => ()
    }
  }

  if has_layout_feature(features, LayoutFeature::DescendantEdges) {
    return
  }

  for edge in graph.edges {
    if is_inside_sequence_diagram(
        graph,
        object_by_id,
        parent_id_by_child_id,
        edge.src_id_syntax,
      ) ||
      is_inside_sequence_diagram(
        graph,
        object_by_id,
        parent_id_by_child_id,
        edge.dst_id_syntax,
      ) {
      continue
    }
    let src = match object_by_id.get(edge.src_id_syntax) {
      Some(obj) => obj
      None => continue
    }
    let dst = match object_by_id.get(edge.dst_id_syntax) {
      Some(obj) => obj
      None => continue
    }
    if !is_container_object(src) && !is_container_object(dst) {
      continue
    }
    if edge.src_id_syntax == edge.dst_id_syntax {
      raise unsupported(
        "Connection \"\{edge_display_id(edge)}\" is a self loop on a container, but layout engine \"\{engine_name}\" does not support this. See https://d2lang.com/tour/layouts/#layout-specific-functionality for more.",
      )
    }
    if is_descendant_of_id(
        edge.src_id_syntax,
        edge.dst_id_syntax,
        parent_id_by_child_id,
      ) ||
      is_descendant_of_id(
        edge.dst_id_syntax,
        edge.src_id_syntax,
        parent_id_by_child_id,
      ) {
      raise unsupported(
        "Connection \"\{edge_display_id(edge)}\" goes from a container to a descendant, but layout engine \"\{engine_name}\" does not support this. See https://d2lang.com/tour/layouts/#layout-specific-functionality for more.",
      )
    }
  }
}

///|
fn clone_graph_with_parts(
  graph : @graph.GraphInput,
  root : @graph.ObjectInput,
  objects : Array[@graph.ObjectInput],
  edges : Array[@graph.EdgeInput],
  layers : Array[@graph.LayerInput],
  scenarios : Array[@graph.ScenarioInput],
  steps : Array[@graph.StepInput],
) -> @graph.GraphInput {
  @graph.GraphInput::from_parts(
    graph.name,
    root,
    objects,
    edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    layers,
    scenarios,
    steps,
    graph.legend,
    is_folder_only=graph.is_folder_only,
    data=graph.data,
    extracted_include_self=graph.extracted_include_self,
  )
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
    if not(child_ids.contains(obj.abs_id_syntax)) {
      root_child_ids.push(obj.abs_id_syntax)
    }
  }
  let root = clone_object_with_parts(graph.root, graph.root.box, root_child_ids)
  clone_graph_with_parts(
    graph,
    root,
    graph.objects,
    graph.edges,
    graph.layers,
    graph.scenarios,
    graph.steps,
  )
}

///|
fn find_sql_column_index(
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  field_id : String,
) -> Int? {
  let field = match object_by_id.get(field_id) {
    Some(f) => f
    None => return None
  }
  let parent_id = match parent_id_by_child_id.get(field.abs_id_syntax) {
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
  let mut i = 0
  for child_id in parent.child_ids {
    if child_id == field.abs_id_syntax {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn assign_sql_column_indices(graph : @graph.GraphInput) -> @graph.GraphInput {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.abs_id_syntax] = graph.root
  for obj in graph.objects {
    object_by_id[obj.abs_id_syntax] = obj
  }
  let parent_id_by_child_id : Map[String, String] = {}
  for child_id in graph.root.child_ids {
    parent_id_by_child_id[child_id] = graph.root.abs_id_syntax
  }
  for obj in graph.objects {
    for child_id in obj.child_ids {
      parent_id_by_child_id[child_id] = obj.abs_id_syntax
    }
  }
  let edges : Array[@graph.EdgeInput] = []
  for e in graph.edges {
    let src_column_index = match e.src_column_index {
      Some(i) => Some(i)
      None =>
        find_sql_column_index(
          object_by_id,
          parent_id_by_child_id,
          e.src_id_syntax,
        )
    }
    let dst_column_index = match e.dst_column_index {
      Some(i) => Some(i)
      None =>
        find_sql_column_index(
          object_by_id,
          parent_id_by_child_id,
          e.dst_id_syntax,
        )
    }
    edges.push(
      @graph.EdgeInput::from_parts(
        e.index,
        e.src_id,
        e.dst_id,
        e.src_arrow,
        e.dst_arrow,
        e.src_arrowhead,
        e.dst_arrowhead,
        e.src_arrowhead_label,
        e.dst_arrowhead_label,
        e.src_arrowhead_label_color,
        e.dst_arrowhead_label_color,
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
        src_id_syntax=e.src_id_syntax,
        dst_id_syntax=e.dst_id_syntax,
        references=e.references,
      ),
    )
  }
  clone_graph_with_parts(
    graph,
    graph.root,
    graph.objects,
    edges,
    graph.layers,
    graph.scenarios,
    graph.steps,
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
    let route = if edge_prefers_curved(e) {
      e.route
    } else {
      ensure_orthogonal_route(e.route)
    }
    edges.push(
      @graph.EdgeInput::from_parts(
        e.index,
        e.src_id,
        e.dst_id,
        e.src_arrow,
        e.dst_arrow,
        e.src_arrowhead,
        e.dst_arrowhead,
        e.src_arrowhead_label,
        e.dst_arrowhead_label,
        e.src_arrowhead_label_color,
        e.dst_arrowhead_label_color,
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
        src_id_syntax=e.src_id_syntax,
        dst_id_syntax=e.dst_id_syntax,
        references=e.references,
      ),
    )
  }
  clone_graph_with_parts(
    graph,
    graph.root,
    graph.objects,
    edges,
    graph.layers,
    graph.scenarios,
    graph.steps,
  )
}

///|
fn edge_prefers_curved(edge : @graph.EdgeInput) -> Bool {
  match edge.style.curved {
    Some(v) => v.as_bool().unwrap_or(true)
    None => true
  }
}

///|
priv struct GridChildLayoutMetrics {
  layout_width : Double
  layout_height : Double
  label_position : String?
  icon_position : String?
  initial_margin : GridMargin
}

///|
priv struct GridMargin {
  left : Double
  top : Double
  right : Double
  bottom : Double
}

///|
const D2_GRID_STARTING_THRESHOLD : Double = 1.2

///|
const D2_GRID_THRESHOLD_STEP_SIZE : Double = 0.25

///|
const D2_GRID_MIN_THRESHOLD_ATTEMPTS : Int = 1

///|
const D2_GRID_MAX_THRESHOLD_ATTEMPTS : Int = 3

///|
const D2_GRID_ATTEMPT_LIMIT : Int = 100000

///|
const D2_GRID_SKIP_LIMIT : Int = 10000000

///|
priv struct GridSemanticContext {
  groups : Map[String, Array[String]]
  child_ids : Map[String, Bool]
}

///|
priv struct GridContainerLayout {
  width : Double
  height : Double
  child_boxes : Map[String, @graph.Box]
}

///|
fn prepare_layout_semantics(
  graph : @graph.GraphInput,
  config : LayoutConfig,
) -> (@graph.GraphInput, GridSemanticContext) {
  let groups = collect_grid_semantic_groups(graph)
  if groups.is_empty() {
    return (graph, { groups, child_ids: {} })
  }
  let pre_sized = apply_grid_semantic_parent_boxes(graph, groups, config)
  let child_ids : Map[String, Bool] = {}
  for _, ids in groups {
    for id in ids {
      child_ids[id] = true
    }
  }
  (detach_grid_children(pre_sized, groups), { groups, child_ids })
}

///|
fn restore_layout_semantics(
  original_graph : @graph.GraphInput,
  laid_out_graph : @graph.GraphInput,
  context : GridSemanticContext,
  config : LayoutConfig,
) -> @graph.GraphInput {
  if context.groups.is_empty() {
    laid_out_graph
  } else {
    restore_grid_semantics(original_graph, laid_out_graph, context, config)
  }
}

///|
fn collect_grid_semantic_groups(
  graph : @graph.GraphInput,
) -> Map[String, Array[String]] {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.abs_id_syntax] = graph.root
  for obj in graph.objects {
    object_by_id[obj.abs_id_syntax] = obj
  }
  let incident_ids : Map[String, Bool] = {}
  for edge in graph.edges {
    incident_ids[edge.src_id_syntax] = true
    incident_ids[edge.dst_id_syntax] = true
  }
  let groups : Map[String, Array[String]] = {}
  let parents : Array[@graph.ObjectInput] = [graph.root]
  for obj in graph.objects {
    parents.push(obj)
  }
  for parent in parents {
    if parent.grid_rows is None && parent.grid_columns is None {
      continue
    }
    let child_ids : Array[String] = []
    let mut blocked = false
    for child_id in parent.child_ids {
      guard object_by_id.contains(child_id) else { continue }
      if incident_ids.contains(child_id) {
        blocked = true
        break
      }
      child_ids.push(child_id)
    }
    if blocked || child_ids.is_empty() {
      continue
    }
    groups[parent.abs_id_syntax] = child_ids
  }
  groups
}

///|
fn apply_grid_semantic_parent_boxes(
  graph : @graph.GraphInput,
  groups : Map[String, Array[String]],
  config : LayoutConfig,
) -> @graph.GraphInput {
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  object_by_id[graph.root.abs_id_syntax] = graph.root
  for obj in graph.objects {
    object_by_id[obj.abs_id_syntax] = obj
  }
  let parent_id_by_child_id = build_parent_id_by_child_abs_id_syntax(graph)

  let parent_box_by_id : Map[String, @graph.Box] = {}
  for parent_id, child_ids in groups {
    if parent_id == graph.root.abs_id_syntax {
      continue
    }
    let parent = match object_by_id.get(parent_id) {
      Some(v) => v
      None => continue
    }
    let child_size_by_id : Map[String, (Double, Double)] = {}
    for child_id in child_ids {
      match object_by_id.get(child_id) {
        Some(child) => {
          let inside_sequence = is_inside_sequence_diagram(
            graph, object_by_id, parent_id_by_child_id, child_id,
          )
          child_size_by_id[child_id] = semantic_object_size(
            child,
            config,
            inside_sequence~,
          )
        }
        None => ()
      }
    }
    match
      estimate_grid_container_layout_like_d2(
        parent, child_ids, child_size_by_id,
      ) {
      Some(layout) => {
        let (x, y) = match parent.box {
          Some(box) => (box.x, box.y)
          None => (0.0, 0.0)
        }
        parent_box_by_id[parent_id] = @graph.Box::new(
          x,
          y,
          layout.width,
          layout.height,
        )
      }
      None => ()
    }
  }

  if parent_box_by_id.is_empty() {
    return graph
  }

  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    let box = match parent_box_by_id.get(obj.abs_id_syntax) {
      Some(v) => Some(v)
      None => obj.box
    }
    objects.push(clone_object_with_parts(obj, box, obj.child_ids))
  }

  clone_graph_with_parts(
    graph,
    graph.root,
    objects,
    graph.edges,
    graph.layers,
    graph.scenarios,
    graph.steps,
  )
}

///|
fn detach_grid_children(
  graph : @graph.GraphInput,
  groups : Map[String, Array[String]],
) -> @graph.GraphInput {
  let group_child_ids : Map[String, Bool] = {}
  for _, child_ids in groups {
    for child_id in child_ids {
      group_child_ids[child_id] = true
    }
  }
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    if group_child_ids.contains(obj.abs_id_syntax) {
      continue
    }
    let child_ids = match groups.get(obj.abs_id_syntax) {
      Some(filtered) => {
        let removed : Map[String, Bool] = {}
        for id in filtered {
          removed[id] = true
        }
        let kept : Array[String] = []
        for id in obj.child_ids {
          if !removed.contains(id) {
            kept.push(id)
          }
        }
        kept
      }
      None => obj.child_ids
    }
    objects.push(clone_object_with_parts(obj, obj.box, child_ids))
  }
  let root_child_ids = match groups.get(graph.root.abs_id_syntax) {
    Some(filtered) => {
      let removed : Map[String, Bool] = {}
      for id in filtered {
        removed[id] = true
      }
      let kept : Array[String] = []
      for id in graph.root.child_ids {
        if !removed.contains(id) {
          kept.push(id)
        }
      }
      kept
    }
    None => graph.root.child_ids
  }
  let root = clone_object_with_parts(graph.root, graph.root.box, root_child_ids)
  clone_graph_with_parts(
    graph,
    root,
    objects,
    graph.edges,
    graph.layers,
    graph.scenarios,
    graph.steps,
  )
}

///|
fn estimate_grid_container_layout_like_d2(
  parent : @graph.ObjectInput,
  child_ids : Array[String],
  child_size_by_id : Map[String, (Double, Double)],
) -> GridContainerLayout? {
  match estimate_root_grid_child_boxes(parent, child_ids, child_size_by_id) {
    Some(content_child_boxes) => {
      let mut content_width = 0.0
      let mut content_height = 0.0
      for _, box in content_child_boxes {
        let right = box.x + box.width
        let bottom = box.y + box.height
        if right > content_width {
          content_width = right
        }
        if bottom > content_height {
          content_height = bottom
        }
      }
      let (hgap, vgap) = grid_semantic_gaps(parent)
      let padding = grid_semantic_padding_like_d2(
        parent, content_width, content_height, hgap, vgap,
      )
      let child_boxes : Map[String, @graph.Box] = {}
      for child_id, box in content_child_boxes {
        child_boxes[child_id] = @graph.Box::new(
          box.x + padding.left,
          box.y + padding.top,
          box.width,
          box.height,
        )
      }
      Some({
        width: content_width + padding.left + padding.right,
        height: content_height + padding.top + padding.bottom,
        child_boxes,
      })
    }
    None => None
  }
}

///|
fn grid_child_layout_metrics_like_d2(
  obj : @graph.ObjectInput,
  config : LayoutConfig,
) -> GridChildLayoutMetrics {
  let (base_width, base_height) = grid_child_base_dimensions_like_d2(
    obj, config,
  )
  let (label_position, icon_position) = grid_child_effective_positions_like_d2(
    obj,
  )
  let initial_margin = grid_child_margin_like_d2(
    obj, base_width, base_height, label_position, icon_position,
  )
  {
    layout_width: base_width + initial_margin.left + initial_margin.right,
    layout_height: base_height + initial_margin.top + initial_margin.bottom,
    label_position,
    icon_position,
    initial_margin,
  }
}

///|
fn grid_child_base_dimensions_like_d2(
  obj : @graph.ObjectInput,
  config : LayoutConfig,
) -> (Double, Double) {
  match obj.box {
    Some(box) =>
      if box.width > 0.0 && box.height > 0.0 {
        (box.width, box.height)
      } else {
        semantic_object_size(obj, config)
      }
    None => semantic_object_size(obj, config)
  }
}

///|
fn inferred_label_position_from_layout_like_d2(
  obj : @graph.ObjectInput,
) -> String? {
  match (obj.box, obj.label_box) {
    (Some(box), Some(label_box)) => {
      let label_bottom = label_box.y + label_box.height
      let box_bottom = box.y + box.height
      let label_center_x = label_box.x + label_box.width / 2.0
      let box_center_x = box.x + box.width / 2.0
      let centered_x = (label_center_x - box_center_x).abs() <= 1.0
      if label_bottom <= box.y {
        if centered_x {
          Some("OUTSIDE_TOP_CENTER")
        } else {
          Some("OUTSIDE_TOP_LEFT")
        }
      } else if label_box.y >= box_bottom {
        if centered_x {
          Some("OUTSIDE_BOTTOM_CENTER")
        } else {
          Some("OUTSIDE_BOTTOM_LEFT")
        }
      } else if label_box.y >= box.y && label_bottom <= box_bottom {
        if label_box.y <= box.y + label_box.height + D2_LABEL_PADDING {
          if centered_x {
            Some("INSIDE_TOP_CENTER")
          } else {
            Some("INSIDE_TOP_LEFT")
          }
        } else if centered_x {
          Some("INSIDE_MIDDLE_CENTER")
        } else {
          Some("INSIDE_MIDDLE_LEFT")
        }
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn grid_child_effective_positions_like_d2(
  obj : @graph.ObjectInput,
) -> (String?, String?) {
  let mut label_position = match obj.label_position {
    Some(position) => Some(position)
    None => inferred_label_position_from_layout_like_d2(obj)
  }
  let mut icon_position = obj.icon_position
  let mut positioned_label = false
  if obj.icon is Some(_) && icon_position is None {
    if !obj.child_ids.is_empty() {
      icon_position = Some("OUTSIDE_TOP_LEFT")
      if label_position is None {
        label_position = Some("OUTSIDE_TOP_RIGHT")
        positioned_label = true
      }
    } else {
      icon_position = Some("INSIDE_MIDDLE_CENTER")
    }
  }
  if !positioned_label &&
    grid_child_has_label_like_d2(obj) &&
    label_position is None {
    if !obj.child_ids.is_empty() {
      label_position = Some("OUTSIDE_TOP_CENTER")
    } else if grid_child_has_outside_bottom_label_like_d2(obj) {
      label_position = Some("OUTSIDE_BOTTOM_CENTER")
    } else if obj.icon is Some(_) {
      label_position = Some("INSIDE_TOP_CENTER")
    } else {
      label_position = Some("INSIDE_MIDDLE_CENTER")
    }
  }
  (label_position, icon_position)
}

///|
fn grid_child_has_label_like_d2(obj : @graph.ObjectInput) -> Bool {
  match obj.shape_type {
    @graph.Text => false
    @graph.Class => false
    @graph.SqlTable => false
    @graph.Code => false
    _ => obj.label != ""
  }
}

///|
fn grid_child_has_outside_bottom_label_like_d2(
  obj : @graph.ObjectInput,
) -> Bool {
  match obj.shape_type {
    @graph.Image => true
    @graph.Person => true
    _ => false
  }
}

///|
fn grid_child_margin_like_d2(
  obj : @graph.ObjectInput,
  width : Double,
  height : Double,
  label_position : String?,
  icon_position : String?,
) -> GridMargin {
  let mut left = 0.0
  let mut top = 0.0
  let mut right = 0.0
  let mut bottom = 0.0

  if grid_child_has_label_like_d2(obj) {
    match label_position {
      Some(position) => {
        let dims = grid_child_label_dimensions_like_d2(obj)
        let label_width = dims.0
        let label_height = dims.1
        let upper = position.to_upper()
        if upper.contains("OUTSIDE_TOP_") {
          top = label_height
        } else if upper.contains("OUTSIDE_BOTTOM_") {
          bottom = label_height
        } else if upper.contains("OUTSIDE_LEFT_") {
          left = label_width
        } else if upper.contains("OUTSIDE_RIGHT_") {
          right = label_width
        }
        if label_width > width {
          let dx = label_width - width
          if upper == "OUTSIDE_TOP_LEFT" || upper == "OUTSIDE_BOTTOM_LEFT" {
            right = dx
          } else if upper == "OUTSIDE_TOP_CENTER" ||
            upper == "OUTSIDE_BOTTOM_CENTER" {
            let half = (dx / 2.0).ceil()
            left = half
            right = half
          } else if upper == "OUTSIDE_TOP_RIGHT" ||
            upper == "OUTSIDE_BOTTOM_RIGHT" {
            left = dx
          }
        }
        if label_height > height {
          let dy = label_height - height
          if upper == "OUTSIDE_LEFT_TOP" || upper == "OUTSIDE_RIGHT_TOP" {
            bottom = dy
          } else if upper == "OUTSIDE_LEFT_MIDDLE" ||
            upper == "OUTSIDE_RIGHT_MIDDLE" {
            let half = (dy / 2.0).ceil()
            top = half
            bottom = half
          } else if upper == "OUTSIDE_LEFT_BOTTOM" ||
            upper == "OUTSIDE_RIGHT_BOTTOM" {
            top = dy
          }
        }
      }
      None => ()
    }
  }

  if obj.icon is Some(_) {
    match icon_position {
      Some(position) => {
        let upper = position.to_upper()
        let icon_size = D2_MAX_ICON_SIZE + D2_LABEL_PADDING
        if upper.contains("OUTSIDE_TOP_") {
          top = if top > icon_size { top } else { icon_size }
        } else if upper.contains("OUTSIDE_BOTTOM_") {
          bottom = if bottom > icon_size { bottom } else { icon_size }
        } else if upper.contains("OUTSIDE_LEFT_") {
          left = if left > icon_size { left } else { icon_size }
        } else if upper.contains("OUTSIDE_RIGHT_") {
          right = if right > icon_size { right } else { icon_size }
        }
      }
      None => ()
    }
  }

  { left, top, right, bottom }
}

///|
fn grid_child_label_dimensions_like_d2(
  obj : @graph.ObjectInput,
) -> (Double, Double) {
  let font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(obj.style.bold, false)
  let is_italic = style_bool(obj.style.italic, false)
  let is_mono = obj.shape_type == @graph.Code ||
    style_is_mono(obj.style.font_family)
  let dims = if obj.shape_type == @graph.Code {
    @text_metrics.measure_label_code(obj.label, font_size, is_bold, is_italic)
  } else {
    @text_metrics.measure_label(
      obj.label,
      font_size,
      is_mono,
      is_bold,
      is_italic,
    )
  }
  (dims.width + D2_LABEL_PADDING, dims.height + D2_LABEL_PADDING)
}

///|
fn grid_child_restored_box_like_d2(
  obj : @graph.ObjectInput,
  metrics : GridChildLayoutMetrics,
  x : Double,
  y : Double,
  cell_w : Double,
  cell_h : Double,
) -> @graph.Box {
  let initial_dx = metrics.initial_margin.left + metrics.initial_margin.right
  let initial_dy = metrics.initial_margin.top + metrics.initial_margin.bottom
  let mut width = cell_w - initial_dx
  let mut height = cell_h - initial_dy
  if width < 0.0 {
    width = 0.0
  }
  if height < 0.0 {
    height = 0.0
  }
  let new_margin = grid_child_margin_like_d2(
    obj,
    width,
    height,
    metrics.label_position,
    metrics.icon_position,
  )
  let new_dx = new_margin.left + new_margin.right
  let new_dy = new_margin.top + new_margin.bottom
  if new_dx < initial_dx {
    width += initial_dx - new_dx
  }
  if new_dy < initial_dy {
    height += initial_dy - new_dy
  }
  @graph.Box::new(x + new_margin.left, y + new_margin.top, width, height)
}

///|
fn grid_semantic_gaps(parent : @graph.ObjectInput) -> (Double, Double) {
  let mut hgap = 40.0
  let mut vgap = 40.0
  match parent.grid_gap {
    Some(v) => {
      hgap = v
      vgap = v
    }
    None => ()
  }
  match parent.horizontal_gap {
    Some(v) => hgap = v
    None => ()
  }
  match parent.vertical_gap {
    Some(v) => vgap = v
    None => ()
  }
  (hgap, vgap)
}

///|
fn grid_semantic_padding_like_d2(
  parent : @graph.ObjectInput,
  content_width : Double,
  content_height : Double,
  hgap : Double,
  vgap : Double,
) -> GridMargin {
  let (label_position, icon_position) = grid_container_effective_positions_like_d2(
    parent,
  )
  let spacing_padding = grid_container_spacing_padding_like_d2(
    parent, label_position, icon_position,
  )
  let mut left = spacing_padding.left
  let mut top = spacing_padding.top
  let mut right = spacing_padding.right
  let mut bottom = spacing_padding.bottom
  let (label_width, label_height) = if grid_child_has_label_like_d2(parent) {
    object_label_dimensions_like_d2(parent, 2.0 * D2_LABEL_PADDING)
  } else {
    (0.0, 0.0)
  }

  match label_position {
    Some(position) => {
      let upper = position.to_upper()
      if label_width > 0.0 &&
        (
          upper.contains("OUTSIDE_TOP_") ||
          upper.contains("INSIDE_TOP_") ||
          upper.contains("INSIDE_BOTTOM_") ||
          upper.contains("OUTSIDE_BOTTOM_")
        ) {
        let overflow = label_width - content_width
        if overflow > 0.0 {
          let half = overflow / 2.0
          left = left + half
          right = right + half
        }
      }
      if label_height > 0.0 &&
        (
          upper.contains("OUTSIDE_LEFT_") ||
          upper.contains("INSIDE_MIDDLE_") ||
          upper.contains("OUTSIDE_RIGHT_")
        ) {
        let overflow = label_height - content_height
        if overflow > 0.0 {
          let half = overflow / 2.0
          top = top + half
          bottom = bottom + half
        }
      }
    }
    None => ()
  }

  if icon_position == Some("INSIDE_TOP_LEFT") &&
    label_position == Some("INSIDE_TOP_CENTER") {
    let icon_size = D2_MAX_ICON_SIZE + 2.0 * D2_LABEL_PADDING
    if left < icon_size {
      left = icon_size
    }
    if right < icon_size {
      right = icon_size
    }
    let min_width = 2.0 * icon_size + label_width
    let overflow = min_width - content_width
    if overflow > 0.0 {
      let half = overflow / 2.0
      if left < half {
        left = half
      }
      if right < half {
        right = half
      }
    }
  }

  let horizontal_padding = if parent.grid_gap is Some(_) ||
    parent.horizontal_gap is Some(_) {
    hgap
  } else {
    60.0
  }
  let vertical_padding = if parent.grid_gap is Some(_) ||
    parent.vertical_gap is Some(_) {
    vgap
  } else {
    60.0
  }
  if top < vertical_padding {
    top = vertical_padding
  }
  if bottom < vertical_padding {
    bottom = vertical_padding
  }
  if left < horizontal_padding {
    left = horizontal_padding
  }
  if right < horizontal_padding {
    right = horizontal_padding
  }
  { left, top, right, bottom }
}

///|
fn grid_container_effective_positions_like_d2(
  obj : @graph.ObjectInput,
) -> (String?, String?) {
  let label_position = if obj.label_position is Some(_) {
    obj.label_position
  } else if grid_child_has_label_like_d2(obj) {
    Some("INSIDE_TOP_CENTER")
  } else {
    None
  }
  let icon_position = if obj.icon_position is Some(_) {
    obj.icon_position
  } else if obj.icon is Some(_) {
    Some("INSIDE_TOP_LEFT")
  } else {
    None
  }
  (label_position, icon_position)
}

///|
fn grid_container_spacing_padding_like_d2(
  obj : @graph.ObjectInput,
  label_position : String?,
  icon_position : String?,
) -> GridMargin {
  let mut left = 0.0
  let mut top = 0.0
  let mut right = 0.0
  let mut bottom = 0.0

  if grid_child_has_label_like_d2(obj) {
    let (label_width, label_height) = object_label_dimensions_like_d2(
      obj,
      2.0 * D2_LABEL_PADDING,
    )
    match label_position {
      Some(position) => {
        let upper = position.to_upper()
        if upper.contains("INSIDE_TOP_") {
          top = label_height
        } else if upper.contains("INSIDE_BOTTOM_") {
          bottom = label_height
        } else if upper == "INSIDE_MIDDLE_LEFT" {
          left = label_width
        } else if upper == "INSIDE_MIDDLE_RIGHT" {
          right = label_width
        }
      }
      None => ()
    }
  }

  if obj.icon is Some(_) {
    let icon_size = D2_MAX_ICON_SIZE + 2.0 * D2_LABEL_PADDING
    match icon_position {
      Some(position) => {
        let upper = position.to_upper()
        if upper.contains("INSIDE_TOP_") {
          if top < icon_size {
            top = icon_size
          }
        } else if upper.contains("INSIDE_BOTTOM_") {
          if bottom < icon_size {
            bottom = icon_size
          }
        } else if upper == "INSIDE_MIDDLE_LEFT" {
          if left < icon_size {
            left = icon_size
          }
        } else if upper == "INSIDE_MIDDLE_RIGHT" {
          if right < icon_size {
            right = icon_size
          }
        }
      }
      None => ()
    }
  }

  { left, top, right, bottom }
}

///|
fn object_label_dimensions_like_d2(
  obj : @graph.ObjectInput,
  padding : Double,
) -> (Double, Double) {
  let font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(obj.style.bold, false)
  let is_italic = style_bool(obj.style.italic, false)
  let is_mono = obj.shape_type == @graph.Code ||
    style_is_mono(obj.style.font_family)
  let dims = if obj.shape_type == @graph.Code {
    @text_metrics.measure_label_code(obj.label, font_size, is_bold, is_italic)
  } else {
    @text_metrics.measure_label(
      obj.label,
      font_size,
      is_mono,
      is_bold,
      is_italic,
    )
  }
  (dims.width + padding, dims.height + padding)
}

///|
fn root_grid_gaps(parent : @graph.ObjectInput) -> (Double, Double) {
  let default_gap = if parent.grid_rows is Some(_) ||
    parent.grid_columns is Some(_) {
    40.0
  } else {
    20.0
  }
  let mut vertical_gap = default_gap
  let mut horizontal_gap = default_gap
  match parent.grid_gap {
    Some(v) => {
      vertical_gap = v
      horizontal_gap = v
    }
    None => ()
  }
  match parent.vertical_gap {
    Some(v) => vertical_gap = v
    None => ()
  }
  match parent.horizontal_gap {
    Some(v) => horizontal_gap = v
    None => ()
  }
  (horizontal_gap, vertical_gap)
}

///|
fn root_grid_segment_size(
  segment : Array[Int],
  sizes : Array[Double],
  gap : Double,
) -> Double {
  let mut out = 0.0
  for i in segment {
    out = out + sizes[i]
  }
  if segment.length() > 1 {
    out = out + gap * (segment.length() - 1).to_double()
  }
  out
}

///|
fn root_grid_layout_distance(
  layout : Array[Array[Int]],
  target_size : Double,
  sizes : Array[Double],
  gap : Double,
) -> Double {
  let mut total = 0.0
  for segment in layout {
    let segment_size = root_grid_segment_size(segment, sizes, gap)
    total = total + (segment_size - target_size).abs()
  }
  total
}

///|
fn root_grid_gen_layout(
  count : Int,
  cut_indices : Array[Int],
) -> Array[Array[Int]] {
  let layout : Array[Array[Int]] = []
  let mut obj_index = 0
  let mut i = 0
  while i <= cut_indices.length() {
    let stop = if i < cut_indices.length() { cut_indices[i] } else { count - 1 }
    let row : Array[Int] = []
    while obj_index <= stop && obj_index < count {
      row.push(obj_index)
      obj_index = obj_index + 1
    }
    layout.push(row)
    i = i + 1
  }
  layout
}

///|
fn root_grid_cut_combinations(end : Int, cuts_left : Int) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = []
  if end < 2 || cuts_left <= 0 {
    return out
  }
  let mut index = end - 1
  while index >= cuts_left {
    if cuts_left > 1 {
      let inner = root_grid_cut_combinations(index, cuts_left - 1)
      for cut_list in inner {
        let combined = cut_list.copy()
        combined.push(index - 1)
        out.push(combined)
      }
    } else {
      out.push([index - 1])
    }
    index = index - 1
  }
  out
}

///|
fn root_grid_fast_layout(
  sizes : Array[Double],
  target_size : Double,
  n_cuts : Int,
  gap : Double,
) -> Array[Array[Int]]? {
  if n_cuts <= 0 {
    return Some(root_grid_gen_layout(sizes.length(), []))
  }
  let mut debt = 0.0
  let division : Array[Int] = []
  let mut row_size = 0.0
  for i, size in sizes {
    if row_size == 0.0 {
      if size > target_size - debt {
        division.push(i)
        debt = debt + (size - target_size)
      } else {
        row_size = row_size + size
      }
      continue
    }
    if row_size + gap + size / 2.0 > target_size - debt {
      division.push(i - 1)
      debt = debt + (row_size - target_size)
      row_size = size
    } else {
      row_size = row_size + gap + size
    }
  }
  if division.length() == n_cuts {
    return Some(root_grid_gen_layout(sizes.length(), division))
  }
  None
}

///|
fn root_grid_sum(values : Array[Double]) -> Double {
  let mut s = 0.0
  for v in values {
    s = s + v
  }
  s
}

///|
fn root_grid_avg(values : Array[Double]) -> Double {
  if values.is_empty() {
    return 0.0
  }
  root_grid_sum(values) / values.length().to_double()
}

///|
fn root_grid_variance(values : Array[Double]) -> Double {
  if values.is_empty() {
    return 0.0
  }
  let mean = root_grid_avg(values)
  let mut total = 0.0
  for value in values {
    let dev = mean - value
    total = total + dev * dev
  }
  total / values.length().to_double()
}

///|
fn root_grid_stddev(values : Array[Double]) -> Double {
  root_grid_variance(values).sqrt()
}

///|
fn root_grid_best_layout(
  sizes : Array[Double],
  target_size : Double,
  n_cuts : Int,
  gap : Double,
) -> Array[Array[Int]] {
  if n_cuts <= 0 {
    return root_grid_gen_layout(sizes.length(), [])
  }
  let mut best_layout : Array[Array[Int]] = []
  let mut best_dist = 1000000000000.0
  let mut has_best = false
  let mut fast_is_best = false

  match root_grid_fast_layout(sizes, target_size, n_cuts, gap) {
    Some(fast_layout) => {
      let dist = root_grid_layout_distance(fast_layout, target_size, sizes, gap)
      if dist == 0.0 {
        return fast_layout
      }
      best_layout = fast_layout
      best_dist = dist
      has_best = true
      fast_is_best = true
    }
    None => ()
  }

  let sd = root_grid_stddev(sizes)
  let mut threshold_attempts = sd.ceil().to_int()
  if threshold_attempts < D2_GRID_MIN_THRESHOLD_ATTEMPTS {
    threshold_attempts = D2_GRID_MIN_THRESHOLD_ATTEMPTS
  } else if threshold_attempts > D2_GRID_MAX_THRESHOLD_ATTEMPTS {
    threshold_attempts = D2_GRID_MAX_THRESHOLD_ATTEMPTS
  }

  let combinations = root_grid_cut_combinations(sizes.length(), n_cuts)
  let mut ok_threshold = D2_GRID_STARTING_THRESHOLD
  let mut attempt = 0
  while attempt < threshold_attempts || !has_best {
    let starting_cache : Map[Int, Bool] = {}
    let mut count = 0
    let mut skip_count = 0
    for division in combinations {
      if count >= D2_GRID_ATTEMPT_LIMIT || skip_count >= D2_GRID_SKIP_LIMIT {
        break
      }
      let layout = root_grid_gen_layout(sizes.length(), division)
      let mut valid = true
      for i, segment in layout {
        let starting = i == 0
        if starting {
          let cached = starting_cache.get(segment.length())
          match cached {
            Some(ok) =>
              if !ok {
                valid = false
                break
              }
            None => {
              let segment_size = root_grid_segment_size(segment, sizes, gap)
              let mut ok = true
              if segment.length() > 1 &&
                segment_size > ok_threshold * target_size {
                skip_count = skip_count + 1
                ok = skip_count >= D2_GRID_SKIP_LIMIT
              }
              if ok && segment_size < target_size / ok_threshold {
                skip_count = skip_count + 1
                ok = skip_count >= D2_GRID_SKIP_LIMIT
              }
              starting_cache[segment.length()] = ok
              if !ok {
                valid = false
                break
              }
            }
          }
        } else {
          let segment_size = root_grid_segment_size(segment, sizes, gap)
          if segment.length() > 1 && segment_size > ok_threshold * target_size {
            skip_count = skip_count + 1
            if skip_count < D2_GRID_SKIP_LIMIT {
              valid = false
              break
            }
          }
          if segment_size < target_size / ok_threshold {
            skip_count = skip_count + 1
            if skip_count < D2_GRID_SKIP_LIMIT {
              valid = false
              break
            }
          }
        }
      }
      if !valid {
        continue
      }
      let dist = root_grid_layout_distance(layout, target_size, sizes, gap)
      if dist < best_dist {
        best_layout = layout
        best_dist = dist
        has_best = true
        fast_is_best = false
      } else if fast_is_best && dist == best_dist {
        best_layout = layout
        fast_is_best = false
      }
      count = count + 1
    }
    ok_threshold = ok_threshold + D2_GRID_THRESHOLD_STEP_SIZE
    if skip_count == 0 {
      break
    }
    if count == 0 && threshold_attempts < D2_GRID_MAX_THRESHOLD_ATTEMPTS {
      threshold_attempts = threshold_attempts + 1
    }
    attempt = attempt + 1
  }

  if has_best {
    best_layout
  } else {
    root_grid_gen_layout(sizes.length(), [])
  }
}

///|
pub fn estimate_root_grid_child_boxes(
  parent : @graph.ObjectInput,
  child_ids : Array[String],
  child_size_by_id : Map[String, (Double, Double)],
) -> Map[String, @graph.Box]? {
  if child_ids.is_empty() {
    return None
  }
  let n = child_ids.length()
  let mut rows = match parent.grid_rows {
    Some(v) => if v > 0 { v } else { 0 }
    None => 0
  }
  let mut columns = match parent.grid_columns {
    Some(v) => if v > 0 { v } else { 0 }
    None => 0
  }
  if rows == 0 && columns == 0 {
    return None
  }

  let mut row_directed = false
  if rows != 0 && columns != 0 {
    row_directed = true
    let mut capacity = rows * columns
    while capacity < n {
      if row_directed {
        rows = rows + 1
        capacity = capacity + columns
      } else {
        columns = columns + 1
        capacity = capacity + rows
      }
    }
  } else if columns == 0 {
    row_directed = true
    if n < rows {
      rows = n
    }
  } else if n < columns {
    columns = n
  }

  let (horizontal_gap, vertical_gap) = root_grid_gaps(parent)
  let widths : Array[Double] = []
  let heights : Array[Double] = []
  for id in child_ids {
    match child_size_by_id.get(id) {
      Some((w, h)) => {
        widths.push(w)
        heights.push(h)
      }
      None => {
        widths.push(0.0)
        heights.push(0.0)
      }
    }
  }

  let final_widths = widths.copy()
  let final_heights = heights.copy()
  let final_x : Array[Double] = []
  let final_y : Array[Double] = []
  for _ in 0..<n {
    final_x.push(0.0)
    final_y.push(0.0)
  }

  let mut total_width = 0.0
  let mut total_height = 0.0

  if rows != 0 && columns != 0 {
    let row_heights : Array[Double] = []
    let col_widths : Array[Double] = []
    for _ in 0..<rows {
      row_heights.push(0.0)
    }
    for _ in 0..<columns {
      col_widths.push(0.0)
    }

    let get_index = (row_index : Int, column_index : Int) => {
      if row_directed {
        let index = row_index * columns + column_index
        if index < n {
          Some(index)
        } else {
          None
        }
      } else {
        let index = column_index * rows + row_index
        if index < n {
          Some(index)
        } else {
          None
        }
      }
    }

    for i in 0..<rows {
      let mut row_height = 0.0
      for j in 0..<columns {
        match get_index(i, j) {
          Some(index) =>
            if final_heights[index] > row_height {
              row_height = final_heights[index]
            }
          None => break
        }
      }
      row_heights[i] = row_height
    }
    for j in 0..<columns {
      let mut column_width = 0.0
      for i in 0..<rows {
        match get_index(i, j) {
          Some(index) =>
            if final_widths[index] > column_width {
              column_width = final_widths[index]
            }
          None => break
        }
      }
      col_widths[j] = column_width
    }

    if row_directed {
      let mut cursor_y = 0.0
      for i in 0..<rows {
        let mut cursor_x = 0.0
        for j in 0..<columns {
          match get_index(i, j) {
            Some(index) => {
              final_widths[index] = col_widths[j]
              final_heights[index] = row_heights[i]
              final_x[index] = cursor_x
              final_y[index] = cursor_y
              cursor_x = cursor_x + col_widths[j] + horizontal_gap
            }
            None => break
          }
        }
        cursor_y = cursor_y + row_heights[i] + vertical_gap
      }
    } else {
      let mut cursor_x = 0.0
      for j in 0..<columns {
        let mut cursor_y = 0.0
        for i in 0..<rows {
          match get_index(i, j) {
            Some(index) => {
              final_widths[index] = col_widths[j]
              final_heights[index] = row_heights[i]
              final_x[index] = cursor_x
              final_y[index] = cursor_y
              cursor_y = cursor_y + row_heights[i] + vertical_gap
            }
            None => break
          }
        }
        cursor_x = cursor_x + col_widths[j] + horizontal_gap
      }
    }

    for w in col_widths {
      total_width = total_width + w + horizontal_gap
    }
    for h in row_heights {
      total_height = total_height + h + vertical_gap
    }
    total_width = total_width - horizontal_gap
    total_height = total_height - vertical_gap
  } else if row_directed {
    let mut sum_width = 0.0
    for w in final_widths {
      sum_width = sum_width + w
    }
    let target_width = (sum_width + horizontal_gap * (n - rows).to_double()) /
      rows.to_double()
    let layout = root_grid_best_layout(
      final_widths,
      target_width,
      rows - 1,
      horizontal_gap,
    )

    let row_widths : Array[Double] = []
    let mut max_x = 0.0
    for row in layout {
      let row_width = root_grid_segment_size(row, final_widths, horizontal_gap)
      row_widths.push(row_width)
      if row_width > max_x {
        max_x = row_width
      }
    }

    for i, row in layout {
      let row_width = row_widths[i]
      if row_width == max_x {
        continue
      }
      let delta = max_x - row_width
      let mut widest = 0.0
      for index in row {
        if final_widths[index] > widest {
          widest = final_widths[index]
        }
      }
      let diffs : Array[Double] = []
      let mut total_diff = 0.0
      for index in row {
        let diff = widest - final_widths[index]
        diffs.push(diff)
        total_diff = total_diff + diff
      }
      if total_diff > 0.0 {
        let growth = if delta < total_diff { delta } else { total_diff }
        for j, index in row {
          final_widths[index] = final_widths[index] +
            diffs[j] / total_diff * growth
        }
      }
      if delta > total_diff {
        let growth = (delta - total_diff) / row.length().to_double()
        for index in row {
          final_widths[index] = final_widths[index] + growth
        }
      }
    }

    let mut cursor_y = 0.0
    for row in layout {
      let mut row_height = 0.0
      let mut cursor_x = 0.0
      for index in row {
        final_x[index] = cursor_x
        final_y[index] = cursor_y
        cursor_x = cursor_x + final_widths[index] + horizontal_gap
        if final_heights[index] > row_height {
          row_height = final_heights[index]
        }
      }
      for index in row {
        final_heights[index] = row_height
      }
      cursor_y = cursor_y + row_height + vertical_gap
    }
    total_width = max_x
    total_height = cursor_y - vertical_gap
  } else {
    let mut sum_height = 0.0
    for h in final_heights {
      sum_height = sum_height + h
    }
    let target_height = (sum_height + vertical_gap * (n - columns).to_double()) /
      columns.to_double()
    let layout = root_grid_best_layout(
      final_heights,
      target_height,
      columns - 1,
      vertical_gap,
    )

    let column_heights : Array[Double] = []
    let mut max_y = 0.0
    for column in layout {
      let column_height = root_grid_segment_size(
        column, final_heights, vertical_gap,
      )
      column_heights.push(column_height)
      if column_height > max_y {
        max_y = column_height
      }
    }

    for i, column in layout {
      let column_height = column_heights[i]
      if column_height == max_y {
        continue
      }
      let delta = max_y - column_height
      let mut tallest = 0.0
      for index in column {
        if final_heights[index] > tallest {
          tallest = final_heights[index]
        }
      }
      let diffs : Array[Double] = []
      let mut total_diff = 0.0
      for index in column {
        let diff = tallest - final_heights[index]
        diffs.push(diff)
        total_diff = total_diff + diff
      }
      if total_diff > 0.0 {
        let growth = if delta < total_diff { delta } else { total_diff }
        for j, index in column {
          final_heights[index] = final_heights[index] +
            diffs[j] / total_diff * growth
        }
      }
      if delta > total_diff {
        let growth = (delta - total_diff) / column.length().to_double()
        for index in column {
          final_heights[index] = final_heights[index] + growth
        }
      }
    }

    let mut cursor_x = 0.0
    for column in layout {
      let mut column_width = 0.0
      let mut cursor_y = 0.0
      for index in column {
        final_x[index] = cursor_x
        final_y[index] = cursor_y
        cursor_y = cursor_y + final_heights[index] + vertical_gap
        if final_widths[index] > column_width {
          column_width = final_widths[index]
        }
      }
      for index in column {
        final_widths[index] = column_width
      }
      cursor_x = cursor_x + column_width + horizontal_gap
    }
    total_width = cursor_x - horizontal_gap
    total_height = max_y
  }

  let child_boxes : Map[String, @graph.Box] = {}
  for i, id in child_ids {
    child_boxes[id] = @graph.Box::new(
      final_x[i],
      final_y[i],
      final_widths[i],
      final_heights[i],
    )
  }
  ignore(total_width)
  ignore(total_height)
  Some(child_boxes)
}

///|
fn restore_grid_semantics(
  original_graph : @graph.GraphInput,
  laid_out_graph : @graph.GraphInput,
  context : GridSemanticContext,
  config : LayoutConfig,
) -> @graph.GraphInput {
  let original_by_id : Map[String, @graph.ObjectInput] = {}
  original_by_id[original_graph.root.abs_id_syntax] = original_graph.root
  for obj in original_graph.objects {
    original_by_id[obj.abs_id_syntax] = obj
  }
  let laid_out_by_id : Map[String, @graph.ObjectInput] = {}
  laid_out_by_id[laid_out_graph.root.abs_id_syntax] = laid_out_graph.root
  for obj in laid_out_graph.objects {
    laid_out_by_id[obj.abs_id_syntax] = obj
  }

  let override_boxes : Map[String, @graph.Box] = {}
  for parent_id, child_ids in context.groups {
    if parent_id == original_graph.root.abs_id_syntax {
      let parent = original_graph.root
      let child_metrics_by_id : Map[String, GridChildLayoutMetrics] = {}
      let child_size_by_id : Map[String, (Double, Double)] = {}
      for child_id in child_ids {
        let child = match laid_out_by_id.get(child_id) {
          Some(v) => v
          None =>
            match original_by_id.get(child_id) {
              Some(v) => v
              None => continue
            }
        }
        let metrics = grid_child_layout_metrics_like_d2(child, config)
        child_metrics_by_id[child_id] = metrics
        child_size_by_id[child_id] = (
          metrics.layout_width,
          metrics.layout_height,
        )
      }
      if root_uses_container_grid_semantics(parent) {
        match
          estimate_grid_container_layout_like_d2(
            parent, child_ids, child_size_by_id,
          ) {
          Some(layout) => {
            override_boxes[parent.abs_id_syntax] = @graph.Box::new(
              0.0,
              0.0,
              layout.width,
              layout.height,
            )
            for child_id in child_ids {
              let content_box = match layout.child_boxes.get(child_id) {
                Some(value) => value
                None => continue
              }
              let child = match original_by_id.get(child_id) {
                Some(value) =>
                  match laid_out_by_id.get(child_id) {
                    Some(laid_out_value) => laid_out_value
                    None => value
                  }
                None => {
                  override_boxes[child_id] = content_box
                  continue
                }
              }
              let metrics = match child_metrics_by_id.get(child_id) {
                Some(value) => value
                None =>
                  {
                    layout_width: content_box.width,
                    layout_height: content_box.height,
                    label_position: None,
                    icon_position: None,
                    initial_margin: {
                      left: 0.0,
                      top: 0.0,
                      right: 0.0,
                      bottom: 0.0,
                    },
                  }
              }
              override_boxes[child_id] = grid_child_restored_box_like_d2(
                child,
                metrics,
                content_box.x,
                content_box.y,
                content_box.width,
                content_box.height,
              )
            }
          }
          None => ()
        }
      } else {
        match
          estimate_root_grid_child_boxes(parent, child_ids, child_size_by_id) {
          Some(child_boxes) =>
            for child_id, box in child_boxes {
              override_boxes[child_id] = box
            }
          None => ()
        }
      }
      continue
    }
    let parent = match laid_out_by_id.get(parent_id) {
      Some(v) => v
      None => continue
    }
    let parent_box = match parent.box {
      Some(v) => v
      None => continue
    }
    let child_metrics_by_id : Map[String, GridChildLayoutMetrics] = {}
    let child_size_by_id : Map[String, (Double, Double)] = {}
    for child_id in child_ids {
      let child = match laid_out_by_id.get(child_id) {
        Some(v) => v
        None =>
          match original_by_id.get(child_id) {
            Some(v) => v
            None => continue
          }
      }
      let metrics = grid_child_layout_metrics_like_d2(child, config)
      child_metrics_by_id[child_id] = metrics
      child_size_by_id[child_id] = (metrics.layout_width, metrics.layout_height)
    }
    let layout = match
      estimate_grid_container_layout_like_d2(
        parent, child_ids, child_size_by_id,
      ) {
      Some(v) => v
      None => continue
    }

    let parent_new = parent_box
    override_boxes[parent_id] = parent_new

    for child_id in child_ids {
      let content_box = match layout.child_boxes.get(child_id) {
        Some(value) => value
        None => continue
      }
      let metrics = match child_metrics_by_id.get(child_id) {
        Some(value) => value
        None =>
          {
            layout_width: content_box.width,
            layout_height: content_box.height,
            label_position: None,
            icon_position: None,
            initial_margin: { left: 0.0, top: 0.0, right: 0.0, bottom: 0.0 },
          }
      }
      let child = match laid_out_by_id.get(child_id) {
        Some(value) => value
        None =>
          match original_by_id.get(child_id) {
            Some(value) => value
            None => {
              override_boxes[child_id] = @graph.Box::new(
                parent_new.x + content_box.x,
                parent_new.y + content_box.y,
                content_box.width,
                content_box.height,
              )
              continue
            }
          }
      }
      override_boxes[child_id] = grid_child_restored_box_like_d2(
        child,
        metrics,
        parent_new.x + content_box.x,
        parent_new.y + content_box.y,
        content_box.width,
        content_box.height,
      )
    }
  }
  normalize_override_boxes_origin(override_boxes)

  let objects : Array[@graph.ObjectInput] = []
  for obj in original_graph.objects {
    if context.child_ids.contains(obj.abs_id_syntax) {
      let laid_out_obj = match laid_out_by_id.get(obj.abs_id_syntax) {
        Some(v) => v
        None => obj
      }
      let override_box = override_boxes.get(obj.abs_id_syntax)
      let box = match override_box {
        Some(v) => Some(v)
        None => obj.box
      }
      let label_box = match override_box {
        Some(_) => laid_out_obj.label_box
        None => obj.label_box
      }
      objects.push(
        clone_object_with_parts_and_label(
          laid_out_obj,
          box,
          label_box,
          obj.child_ids,
        ),
      )
      continue
    }
    let laid_out_obj = match laid_out_by_id.get(obj.abs_id_syntax) {
      Some(v) => v
      None => obj
    }
    let override_box = override_boxes.get(obj.abs_id_syntax)
    let box = match override_box {
      Some(v) => Some(v)
      None => laid_out_obj.box
    }
    let label_box = match override_box {
      Some(_) =>
        if context.groups.contains(obj.abs_id_syntax) {
          None
        } else {
          laid_out_obj.label_box
        }
      None => laid_out_obj.label_box
    }
    let child_ids = if context.groups.contains(obj.abs_id_syntax) {
      obj.child_ids
    } else {
      laid_out_obj.child_ids
    }
    objects.push(
      clone_object_with_parts_and_label(laid_out_obj, box, label_box, child_ids),
    )
  }

  let root_has_group = context.groups.contains(
    original_graph.root.abs_id_syntax,
  )
  let root_child_ids = if root_has_group {
    original_graph.root.child_ids
  } else {
    laid_out_graph.root.child_ids
  }
  let root_box = match override_boxes.get(original_graph.root.abs_id_syntax) {
    Some(box) => Some(box)
    None => laid_out_graph.root.box
  }
  let root_label_box = match
    override_boxes.get(original_graph.root.abs_id_syntax) {
    Some(_) => if root_has_group { None } else { laid_out_graph.root.label_box }
    None => laid_out_graph.root.label_box
  }
  let root = clone_object_with_parts_and_label(
    laid_out_graph.root,
    root_box,
    root_label_box,
    root_child_ids,
  )

  clone_graph_with_parts(
    laid_out_graph,
    root,
    objects,
    laid_out_graph.edges,
    laid_out_graph.layers,
    laid_out_graph.scenarios,
    laid_out_graph.steps,
  )
}

///|
fn root_uses_container_grid_semantics(parent : @graph.ObjectInput) -> Bool {
  !(parent.id == "root" &&
  parent.abs_id_syntax == "root" &&
  parent.references.is_empty())
}

///|
fn normalize_override_boxes_origin(
  override_boxes : Map[String, @graph.Box],
) -> Unit {
  if override_boxes.is_empty() {
    return
  }
  let mut min_x = 1000000000.0
  let mut min_y = 1000000000.0
  for _, box in override_boxes {
    if box.x < min_x {
      min_x = box.x
    }
    if box.y < min_y {
      min_y = box.y
    }
  }
  let shift_x = if min_x < 0.0 { -min_x } else { 0.0 }
  let shift_y = if min_y < 0.0 { -min_y } else { 0.0 }
  if shift_x == 0.0 && shift_y == 0.0 {
    return
  }
  let ids : Array[String] = []
  for id, _ in override_boxes {
    ids.push(id)
  }
  for id in ids {
    if override_boxes.get(id) is Some(box) {
      override_boxes[id] = @graph.Box::new(
        box.x + shift_x,
        box.y + shift_y,
        box.width,
        box.height,
      )
    }
  }
}

///|
fn clone_object_with_parts(
  obj : @graph.ObjectInput,
  box : @graph.Box?,
  child_ids : Array[String],
) -> @graph.ObjectInput {
  clone_object_with_parts_and_label(obj, box, obj.label_box, child_ids)
}

///|
fn clone_object_with_parts_and_label(
  obj : @graph.ObjectInput,
  box : @graph.Box?,
  label_box : @graph.Box?,
  child_ids : Array[String],
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
    icon_position=obj.icon_position,
    tooltip_position=obj.tooltip_position,
    label_position=obj.label_position,
  )
}

///|
fn semantic_object_size(
  obj : @graph.ObjectInput,
  config : LayoutConfig,
  inside_sequence? : Bool = false,
) -> (Double, Double) {
  match obj.box {
    Some(box) => {
      let (auto_width, auto_height) = estimate_semantic_object_size(
        obj,
        config,
        inside_sequence~,
      )
      let width = if box.width > 0.0 { box.width } else { auto_width }
      let height = if box.height > 0.0 { box.height } else { auto_height }
      (
        positive_or(width, config.default_width),
        positive_or(height, config.default_height),
      )
    }
    None => estimate_semantic_object_size(obj, config, inside_sequence~)
  }
}

///|
fn estimate_semantic_object_size(
  obj : @graph.ObjectInput,
  config : LayoutConfig,
  inside_sequence? : Bool = false,
) -> (Double, Double) {
  let has_explicit_width = match obj.box {
    Some(box) => box.width > 0.0
    None => false
  }
  let has_explicit_height = match obj.box {
    Some(box) => box.height > 0.0
    None => false
  }
  let with_inner_label_padding = !(has_explicit_width || has_explicit_height)
  let font_size = object_label_font_size_like_d2(obj, inside_sequence)
  let is_bold = object_label_bold_like_d2(obj, inside_sequence)
  let is_italic = style_bool(obj.style.italic, false)
  let is_mono = obj.shape_type == @graph.Code ||
    style_is_mono(obj.style.font_family)
  let label_dims = if obj.shape_type == @graph.Code {
    @text_metrics.measure_label_code(obj.label, font_size, is_bold, is_italic)
  } else {
    @text_metrics.measure_label(
      obj.label,
      font_size,
      is_mono,
      is_bold,
      is_italic,
    )
  }
  let mut content_width = label_dims.width
  let mut content_height = label_dims.height

  if obj.shape_type == @graph.Code {
    content_width = content_width + font_size.to_double()
    content_height = content_height + font_size.to_double()
    // D2 parity: code shape size is measured text + 0.5em padding each side only.
    return (content_width, content_height)
  } else if with_inner_label_padding &&
    obj.label != "" &&
    obj.shape_type != @graph.Text {
    content_width = content_width + D2_INNER_LABEL_PADDING
    content_height = content_height + D2_INNER_LABEL_PADDING
  }

  if obj.shape_type == @graph.Text {
    if content_width < D2_MIN_SHAPE_SIZE {
      content_width = D2_MIN_SHAPE_SIZE
    }
    if content_height < D2_MIN_SHAPE_SIZE {
      content_height = D2_MIN_SHAPE_SIZE
    }
    return (content_width, content_height)
  }

  if obj.shape_type == @graph.Image {
    return (128.0, 128.0)
  }

  let base_padding = semantic_shape_default_padding(obj.shape_type)
  let mut padding_x = base_padding.0
  let mut padding_y = base_padding.1
  if has_explicit_width {
    padding_x = 0.0
  }
  if has_explicit_height {
    padding_y = 0.0
  }
  if obj.icon is Some(_) &&
    obj.shape_type != @graph.SqlTable &&
    obj.shape_type != @graph.Class &&
    obj.shape_type != @graph.Code &&
    obj.shape_type != @graph.Text {
    let label_height = label_dims.height + D2_INNER_LABEL_PADDING
    if !has_explicit_width {
      padding_x = padding_x + label_height
    }
    if !has_explicit_height {
      padding_y = padding_y + label_height
    }
  }

  let fitted = semantic_shape_dimensions_to_fit(
    obj.shape_type,
    content_width,
    content_height,
    padding_x,
    padding_y,
  )
  let mut width = fitted.0
  let mut height = fitted.1

  if obj.shape_type == @graph.Circle || obj.shape_type == @graph.Square {
    let side = if width > height { width } else { height }
    width = side
    height = side
  } else if obj.shape_type == @graph.Person {
    let fit = limit_ar(width, height, D2_PERSON_AR_LIMIT)
    width = fit.0
    height = fit.1
  } else if obj.shape_type == @graph.Oval {
    let fit = limit_ar(width, height, D2_OVAL_AR_LIMIT)
    width = fit.0
    height = fit.1
  } else if obj.shape_type == @graph.C4Person {
    let fit = limit_ar(width, height, D2_C4_PERSON_AR_LIMIT)
    width = fit.0
    height = fit.1
  }

  (
    if width > 0.0 {
      width
    } else {
      positive_or(config.default_width, 1.0)
    },
    if height > 0.0 {
      height
    } else {
      positive_or(config.default_height, 1.0)
    },
  )
}

///|
const D2_FONT_SIZE_M : Int = 16

///|
const D2_FONT_SIZE_L : Int = 20

///|
const D2_FONT_SIZE_XL : Int = 24

///|
const D2_FONT_SIZE_XXL : Int = 28

///|
fn container_level_label_size_like_d2(level : Int) -> Int {
  if level <= 1 {
    D2_FONT_SIZE_XXL
  } else if level == 2 {
    D2_FONT_SIZE_XL
  } else if level == 3 {
    D2_FONT_SIZE_L
  } else {
    D2_FONT_SIZE_M
  }
}

///|
fn object_container_level_like_d2(obj : @graph.ObjectInput) -> Int {
  let depth = @graph.syntax_path_depth(obj.abs_id_syntax)
  if depth <= 0 {
    1
  } else {
    depth
  }
}

///|
fn object_label_font_size_like_d2(
  obj : @graph.ObjectInput,
  inside_sequence : Bool,
) -> Int {
  let mut font_size = D2_FONT_SIZE_M
  if obj.shape_type == @graph.Class || obj.shape_type == @graph.SqlTable {
    font_size = D2_FONT_SIZE_L
  }
  if !inside_sequence &&
    (
      !obj.child_ids.is_empty() ||
      obj.grid_rows is Some(_) ||
      obj.grid_columns is Some(_)
    ) &&
    obj.shape_type != @graph.Text {
    font_size = container_level_label_size_like_d2(
      object_container_level_like_d2(obj),
    )
  }
  match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(font_size)
    None => font_size
  }
}

///|
fn object_label_bold_like_d2(
  obj : @graph.ObjectInput,
  inside_sequence : Bool,
) -> Bool {
  let default_bold = !inside_sequence &&
    obj.child_ids.is_empty() &&
    obj.shape_type != @graph.Text
  style_bool(obj.style.bold, default_bold)
}

///|
const D2_DEFAULT_PADDING : Double = 40.0

///|
const D2_DEFAULT_ARC_DEPTH : Double = 24.0

///|
const D2_PARALLELOGRAM_WEDGE_WIDTH : Double = 26.0

///|
const D2_STORED_DATA_WEDGE_WIDTH : Double = 15.0

///|
const D2_STEP_WEDGE_WIDTH : Double = 35.0

///|
const D2_PACKAGE_TOP_MAX_HEIGHT : Double = 55.0

///|
const D2_PACKAGE_VERTICAL_SCALAR : Double = 0.2

///|
const D2_CALLOUT_DEFAULT_TIP_HEIGHT : Double = 45.0

///|
const D2_PAGE_CORNER_WIDTH : Double = 20.8164

///|
const D2_PAGE_CORNER_HEIGHT : Double = 20.348

///|
const D2_DOC_PATH_HEIGHT : Double = 18.925

///|
const D2_DOC_PATH_INNER_BOTTOM : Double = 14.0

///|
const D2_LABEL_PADDING : Double = 5.0

///|
const D2_INNER_LABEL_PADDING : Double = 5.0

///|
const D2_MIN_SHAPE_SIZE : Double = 5.0

///|
const D2_MAX_ICON_SIZE : Double = 64.0

///|
const D2_PERSON_AR_LIMIT : Double = 1.5

///|
const D2_OVAL_AR_LIMIT : Double = 3.0

///|
const D2_C4_PERSON_AR_LIMIT : Double = 1.5

///|
const D2_C4_HEAD_RADIUS_FACTOR : Double = 0.22

///|
const D2_C4_BODY_TOP_FACTOR : Double = 0.8

///|
const CLOUD_WIDE_INNER_WIDTH : Double = 0.819

///|
const CLOUD_WIDE_INNER_HEIGHT : Double = 0.548

///|
const CLOUD_WIDE_ASPECT_BOUNDARY : Double = (1.0 + D2_DEFAULT_PADDING) /
  D2_DEFAULT_PADDING

///|
const CLOUD_TALL_INNER_WIDTH : Double = 0.549

///|
const CLOUD_TALL_INNER_HEIGHT : Double = 0.820

///|
const CLOUD_TALL_ASPECT_BOUNDARY : Double = D2_DEFAULT_PADDING /
  (1.0 + D2_DEFAULT_PADDING)

///|
const CLOUD_SQUARE_INNER_WIDTH : Double = 0.663

///|
const CLOUD_SQUARE_INNER_HEIGHT : Double = 0.663

///|
fn semantic_shape_default_padding(
  shape_type : @graph.ShapeType,
) -> (Double, Double) {
  match shape_type {
    @graph.Circle => {
      let p = D2_DEFAULT_PADDING / 2.0.sqrt()
      (p, p)
    }
    @graph.Diamond => (D2_DEFAULT_PADDING / 4.0, D2_DEFAULT_PADDING / 2.0)
    @graph.Hexagon => (D2_DEFAULT_PADDING / 2.0, D2_DEFAULT_PADDING / 2.0)
    @graph.Cylinder => (D2_DEFAULT_PADDING, D2_DEFAULT_PADDING / 2.0)
    @graph.Queue => (D2_DEFAULT_PADDING / 2.0, D2_DEFAULT_PADDING)
    @graph.StoredData => (D2_DEFAULT_PADDING - 10.0, D2_DEFAULT_PADDING)
    @graph.Person => (10.0, D2_DEFAULT_PADDING)
    @graph.C4Person => (10.0, D2_DEFAULT_PADDING)
    @graph.Page =>
      (D2_DEFAULT_PADDING, D2_PAGE_CORNER_HEIGHT + D2_DEFAULT_PADDING)
    @graph.Document =>
      (
        D2_DEFAULT_PADDING,
        D2_DEFAULT_PADDING * D2_DOC_PATH_INNER_BOTTOM / D2_DOC_PATH_HEIGHT,
      )
    @graph.Package => (D2_DEFAULT_PADDING, 0.8 * D2_DEFAULT_PADDING)
    @graph.Step =>
      (D2_DEFAULT_PADDING / 4.0, D2_DEFAULT_PADDING + D2_STEP_WEDGE_WIDTH)
    @graph.Callout => (D2_DEFAULT_PADDING, D2_DEFAULT_PADDING / 2.0)
    @graph.Cloud => (D2_DEFAULT_PADDING, D2_DEFAULT_PADDING / 2.0)
    _ => (D2_DEFAULT_PADDING, D2_DEFAULT_PADDING)
  }
}

///|
fn semantic_shape_dimensions_to_fit(
  shape_type : @graph.ShapeType,
  width : Double,
  height : Double,
  padding_x : Double,
  padding_y : Double,
) -> (Double, Double) {
  match shape_type {
    @graph.Circle => {
      let length = if width + padding_x > height + padding_y {
        width + padding_x
      } else {
        height + padding_y
      }
      let diameter = (2.0.sqrt() * length).ceil()
      (diameter, diameter)
    }
    @graph.Oval => {
      let theta = @math.atan2(height, width)
      let padded_width = width + padding_x * @math.cos(theta)
      let padded_height = height + padding_y * @math.sin(theta)
      let mut total_width = (2.0.sqrt() * padded_width).ceil()
      let mut total_height = (2.0.sqrt() * padded_height).ceil()
      let fit = limit_ar(total_width, total_height, D2_OVAL_AR_LIMIT)
      total_width = fit.0
      total_height = fit.1
      (total_width, total_height)
    }
    @graph.Diamond =>
      ((2.0 * (width + padding_x)).ceil(), (2.0 * (height + padding_y)).ceil())
    @graph.Hexagon =>
      ((1.5 * (width + padding_x)).ceil(), (1.5 * (height + padding_y)).ceil())
    @graph.Parallelogram =>
      (
        (width + padding_x + D2_PARALLELOGRAM_WEDGE_WIDTH * 2.0).ceil(),
        (height + padding_y).ceil(),
      )
    @graph.Cylinder =>
      (
        (width + padding_x).ceil(),
        (height + padding_y + 3.0 * D2_DEFAULT_ARC_DEPTH).ceil(),
      )
    @graph.Queue =>
      (
        (width + padding_x + 3.0 * D2_DEFAULT_ARC_DEPTH).ceil(),
        (height + padding_y).ceil(),
      )
    @graph.StoredData =>
      (
        (width + padding_x + 2.0 * D2_STORED_DATA_WEDGE_WIDTH).ceil(),
        (height + padding_y).ceil(),
      )
    @graph.Person => {
      let mut total_width = width + padding_x
      let mut total_height = height + padding_y
      let fit = limit_ar(total_width, total_height, D2_PERSON_AR_LIMIT)
      total_width = fit.0
      total_height = fit.1
      (total_width.ceil(), total_height.ceil())
    }
    @graph.C4Person => {
      let content_width = width + padding_x
      let content_height = height + padding_y
      let mut total_width = content_width / 0.9
      let head_radius = total_width * D2_C4_HEAD_RADIUS_FACTOR
      let body_top = head_radius + head_radius * D2_C4_BODY_TOP_FACTOR
      let vertical_padding = total_width * 0.06
      let mut total_height = content_height + body_top + vertical_padding
      let min_height = total_width * 0.95
      if total_height < min_height {
        total_height = min_height
      }
      let fit = limit_ar(total_width, total_height, D2_C4_PERSON_AR_LIMIT)
      total_width = fit.0
      total_height = fit.1
      (total_width.ceil(), total_height.ceil())
    }
    @graph.Cloud => {
      let total_width = width + padding_x
      let total_height = height + padding_y
      let aspect_ratio = total_width / total_height
      if aspect_ratio > CLOUD_WIDE_ASPECT_BOUNDARY {
        (
          (total_width / CLOUD_WIDE_INNER_WIDTH).ceil(),
          (total_height / CLOUD_WIDE_INNER_HEIGHT).ceil(),
        )
      } else if aspect_ratio < CLOUD_TALL_ASPECT_BOUNDARY {
        (
          (total_width / CLOUD_TALL_INNER_WIDTH).ceil(),
          (total_height / CLOUD_TALL_INNER_HEIGHT).ceil(),
        )
      } else {
        (
          (total_width / CLOUD_SQUARE_INNER_WIDTH).ceil(),
          (total_height / CLOUD_SQUARE_INNER_HEIGHT).ceil(),
        )
      }
    }
    @graph.Page => {
      let mut total_width = width + padding_x
      let mut total_height = height + padding_y
      if total_height < 3.0 * D2_PAGE_CORNER_HEIGHT {
        total_width = total_width + D2_PAGE_CORNER_WIDTH
      }
      if total_width < 2.0 * D2_PAGE_CORNER_WIDTH {
        total_width = 2.0 * D2_PAGE_CORNER_WIDTH
      }
      if total_height < D2_PAGE_CORNER_HEIGHT {
        total_height = D2_PAGE_CORNER_HEIGHT
      }
      (total_width.ceil(), total_height.ceil())
    }
    @graph.Document =>
      (
        (width + padding_x).ceil(),
        ((height + padding_y) * D2_DOC_PATH_HEIGHT / D2_DOC_PATH_INNER_BOTTOM).ceil(),
      )
    @graph.Package => {
      let inner_height = height + padding_y
      let top_height = inner_height *
        D2_PACKAGE_VERTICAL_SCALAR /
        (1.0 - D2_PACKAGE_VERTICAL_SCALAR)
      let total_height = inner_height +
        (if top_height < D2_PACKAGE_TOP_MAX_HEIGHT {
          top_height
        } else {
          D2_PACKAGE_TOP_MAX_HEIGHT
        })
      ((width + padding_x).ceil(), total_height.ceil())
    }
    @graph.Step =>
      (
        (width + padding_x + 2.0 * D2_STEP_WEDGE_WIDTH).ceil(),
        (height + padding_y).ceil(),
      )
    @graph.Callout => {
      let mut total_height = height + padding_y
      if total_height < D2_CALLOUT_DEFAULT_TIP_HEIGHT {
        total_height = total_height * 2.0
      } else {
        total_height = total_height + D2_CALLOUT_DEFAULT_TIP_HEIGHT
      }
      ((width + padding_x).ceil(), total_height.ceil())
    }
    _ => ((width + padding_x).ceil(), (height + padding_y).ceil())
  }
}

///|
fn limit_ar(
  width : Double,
  height : Double,
  aspect_ratio : Double,
) -> (Double, Double) {
  let mut w = width
  let mut h = height
  if w <= 0.0 && h <= 0.0 {
    return (1.0, 1.0)
  }
  if w <= 0.0 {
    w = h / aspect_ratio
  }
  if h <= 0.0 {
    h = w / aspect_ratio
  }
  if h > 0.0 && w / h > aspect_ratio {
    h = w / aspect_ratio
  } else if w > 0.0 && h / w > aspect_ratio {
    w = h / aspect_ratio
  }
  (w, h)
}

///|
fn style_bool(value : @graph.StyleValue?, default : Bool) -> Bool {
  match value {
    Some(v) => v.as_bool().unwrap_or(default)
    None => default
  }
}

///|
fn style_is_mono(value : @graph.StyleValue?) -> Bool {
  match value {
    Some(v) =>
      match v.get_value().to_lower() {
        "mono" | "monospace" | "code" => true
        _ => false
      }
    None => false
  }
}

///|
fn positive_or(value : Double, fallback : Double) -> Double {
  if value > 0.0 {
    value
  } else {
    fallback
  }
}

///|
priv struct GraphOrderContext {
  object_order : Map[String, Int]
  edge_order : Map[Int, Int]
  child_order_by_parent : Map[String, Map[String, Int]]
}

///|
fn save_graph_order_like_d2(graph : @graph.GraphInput) -> GraphOrderContext {
  let object_order : Map[String, Int] = {}
  for i, obj in graph.objects {
    object_order[obj.abs_id_syntax] = i
  }

  let edge_order : Map[Int, Int] = {}
  for i, edge in graph.edges {
    edge_order[edge.index] = i
  }

  let child_order_by_parent : Map[String, Map[String, Int]] = {}
  let root_child_order : Map[String, Int] = {}
  for i, child_id in graph.root.child_ids {
    root_child_order[child_id] = i
  }
  child_order_by_parent[graph.root.abs_id_syntax] = root_child_order
  for obj in graph.objects {
    let child_order : Map[String, Int] = {}
    for i, child_id in obj.child_ids {
      child_order[child_id] = i
    }
    child_order_by_parent[obj.abs_id_syntax] = child_order
  }

  { object_order, edge_order, child_order_by_parent }
}

///|
fn restore_child_order_like_d2(
  parent_id : String,
  child_ids : Array[String],
  context : GraphOrderContext,
) -> Array[String] {
  match context.child_order_by_parent.get(parent_id) {
    Some(order) => {
      let out = child_ids.copy()
      let current_order : Map[String, Int] = {}
      for i, child_id in out {
        current_order[child_id] = i
      }
      out.sort_by(fn(a, b) {
        let a_has = order.contains(a)
        let b_has = order.contains(b)
        if a_has && b_has {
          let cmp = order.get_or_default(a, 0) - order.get_or_default(b, 0)
          if cmp != 0 {
            return cmp
          }
        } else if a_has != b_has {
          return if a_has { -1 } else { 1 }
        }
        current_order.get_or_default(a, 0) - current_order.get_or_default(b, 0)
      })
      out
    }
    None => child_ids
  }
}

///|
fn restore_graph_order_like_d2(
  graph : @graph.GraphInput,
  laid_out_graph : @graph.GraphInput,
) -> @graph.GraphInput {
  let context = save_graph_order_like_d2(graph)

  let objects = laid_out_graph.objects.copy()
  let current_object_order : Map[String, Int] = {}
  for i, obj in objects {
    current_object_order[obj.abs_id_syntax] = i
  }
  objects.sort_by(fn(a, b) {
    let a_has = context.object_order.contains(a.abs_id_syntax)
    let b_has = context.object_order.contains(b.abs_id_syntax)
    if a_has && b_has {
      let cmp = context.object_order.get_or_default(a.abs_id_syntax, 0) -
        context.object_order.get_or_default(b.abs_id_syntax, 0)
      if cmp != 0 {
        return cmp
      }
    } else if a_has != b_has {
      return if a_has { -1 } else { 1 }
    }
    current_object_order.get_or_default(a.abs_id_syntax, 0) -
    current_object_order.get_or_default(b.abs_id_syntax, 0)
  })

  let restored_objects : Array[@graph.ObjectInput] = []
  for obj in objects {
    restored_objects.push(
      clone_object_with_parts_and_label(
        obj,
        obj.box,
        obj.label_box,
        restore_child_order_like_d2(obj.abs_id_syntax, obj.child_ids, context),
      ),
    )
  }

  let edges = laid_out_graph.edges.copy()
  let current_edge_order : Map[Int, Int] = {}
  for i, edge in edges {
    current_edge_order[edge.index] = i
  }
  edges.sort_by(fn(a, b) {
    let a_has = context.edge_order.contains(a.index)
    let b_has = context.edge_order.contains(b.index)
    if a_has && b_has {
      let cmp = context.edge_order.get_or_default(a.index, 0) -
        context.edge_order.get_or_default(b.index, 0)
      if cmp != 0 {
        return cmp
      }
    } else if a_has != b_has {
      return if a_has { -1 } else { 1 }
    }
    current_edge_order.get_or_default(a.index, 0) -
    current_edge_order.get_or_default(b.index, 0)
  })

  let root = clone_object_with_parts_and_label(
    laid_out_graph.root,
    laid_out_graph.root.box,
    laid_out_graph.root.label_box,
    restore_child_order_like_d2(
      graph.root.abs_id_syntax,
      laid_out_graph.root.child_ids,
      context,
    ),
  )

  clone_graph_with_parts(
    laid_out_graph,
    root,
    restored_objects,
    edges,
    laid_out_graph.layers,
    laid_out_graph.scenarios,
    laid_out_graph.steps,
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
  check_feature_support(engine.engine_name(), engine.features(), graph)
  let effective_direction = graph_layout_direction(graph, direction)
  let prepared = prepare_graph_for_layout(graph)
  let (nested_prepared, nested_sequence_ctx) = prepare_nested_sequence_layouts(
    engine, prepared, config, effective_direction,
  )
  let (engine_graph, semantic_ctx) = prepare_layout_semantics(
    nested_prepared, config,
  )
  let laid_out_core = if engine_graph.objects.is_empty() {
    engine_graph
  } else {
    let patch = engine.layout(engine_graph, config, effective_direction)
    @graph.apply_layout(engine_graph, patch)
  }
  let semantic_restored = restore_layout_semantics(
    nested_prepared, laid_out_core, semantic_ctx, config,
  )
  let laid_out = restore_nested_sequence_layouts(
    prepared, semantic_restored, nested_sequence_ctx,
  )
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
  restore_graph_order_like_d2(
    graph,
    normalize_routes(
      clone_graph_with_parts(
        laid_out,
        laid_out.root,
        laid_out.objects,
        laid_out.edges,
        layers,
        scenarios,
        steps,
      ),
    ),
  )
}
