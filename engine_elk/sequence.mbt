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
/// Sequence Diagram Layout
///
/// Implements layout for sequence diagrams with actors, messages, and lifelines.
///
/// Features:
/// - Actors arranged horizontally at the top
/// - Messages routed vertically in temporal order
/// - Lifelines extend from actors
/// - Self-referential messages loop back
/// - Activation boxes (spans) show active periods
/// - Notes attached to actors

// Layout constants
let min_actor_width : Double = 100.0

///|
let min_actor_distance : Double = 150.0

///|
let min_message_distance : Double = 40.0

///|
let lifeline_start_offset : Double = 10.0

///|
let self_message_width : Double = 50.0

///|
let activation_box_width : Double = 16.0

///|
let note_width : Double = 120.0

///|
let note_height : Double = 40.0

///|
let note_padding : Double = 10.0

///|
/// Activation box representing an active period on a lifeline
pub(all) struct ActivationBox {
  /// Actor ID this activation box belongs to
  actor_id : String
  /// X position (center of lifeline)
  x : Double
  /// Start Y position
  start_y : Double
  /// End Y position
  mut end_y : Double
}

///|
pub fn ActivationBox::new(
  actor_id : String,
  x : Double,
  start_y : Double,
) -> ActivationBox {
  { actor_id, x, start_y, end_y: start_y }
}

///|
pub fn ActivationBox::get_box(self : ActivationBox) -> @graph.Box {
  let height = self.end_y - self.start_y
  let min_height = 10.0
  let actual_height = if height < min_height { min_height } else { height }
  @graph.Box::new(
    self.x - activation_box_width / 2.0,
    self.start_y,
    activation_box_width,
    actual_height,
  )
}

///|
/// Layout a sequence diagram container
pub fn layout_sequence(container : Object, config : LayoutConfig) -> Unit {
  let children = container.get_children()
  if children.length() == 0 {
    return
  }
  // Collect actors (direct children of sequence diagram)
  let actors : Array[Object] = []
  for child in children {
    actors.push(child)
  }
  if actors.length() == 0 {
    return
  }
  // Build actor rank map (horizontal position index)
  let actor_rank : Map[String, Int] = {}
  for i, actor in actors {
    actor_rank[actor.get_id()] = i
  }
  // Place actors horizontally
  let max_actor_height = place_sequence_actors(actors, config)
  // Calculate total dimensions
  let mut total_width = 0.0
  for actor in actors {
    if actor.get_box() is Some(b) {
      let right = b.get_x() + b.get_width()
      if right > total_width {
        total_width = right
      }
    }
  }
  total_width = total_width + config.container_padding * 2.0
  // Use default height based on container padding and actor height
  let total_height = max_actor_height +
    lifeline_start_offset +
    min_message_distance * 5.0 + // Default space for messages
    config.container_padding * 2.0
  container.set_box(@graph.Box::new(0.0, 0.0, total_width, total_height))
}

///|
/// A note attached to an actor in a sequence diagram
pub(all) struct SequenceNote {
  /// Actor ID this note is attached to
  actor_id : String
  /// Note text content
  text : String
  /// Bounding box for the note
  bbox : @graph.Box
}

///|
pub fn SequenceNote::new(
  actor_id : String,
  text : String,
  bbox : @graph.Box,
) -> SequenceNote {
  { actor_id, text, bbox }
}

///|
/// Result of sequence diagram layout including activation boxes and notes
pub(all) struct SequenceLayoutResult {
  /// Activation boxes computed from message flow
  activation_boxes : Array[ActivationBox]
  /// Notes attached to actors
  notes : Array[SequenceNote]
  /// Final Y position after all messages
  end_y : Double
}

///|
/// Layout a sequence diagram container with message routing
pub fn layout_sequence_with_messages(
  container : Object,
  graph : Graph,
  config : LayoutConfig,
) -> Unit {
  let _ = layout_sequence_with_activations(container, graph, config)

}

///|
/// Layout a sequence diagram container with message routing and return activation boxes
pub fn layout_sequence_with_activations(
  container : Object,
  graph : Graph,
  config : LayoutConfig,
) -> SequenceLayoutResult {
  let children = container.get_children()
  if children.length() == 0 {
    return { activation_boxes: [], notes: [], end_y: 0.0 }
  }
  // Collect actors (direct children of sequence diagram that have edge refs)
  // and groups (containers with fragment-like labels that are not actors)
  let actors : Array[Object] = []
  let groups : Array[Object] = []
  let container_id = container.get_id()
  for child in children {
    // Check if this child is involved in any edges - if so, it's an actor
    if is_actor_in_sequence(child, graph, container_id) {
      actors.push(child)
    } else if is_sequence_group(child) {
      // Container with fragment-like label is a group
      groups.push(child)
    }
  }
  if actors.length() == 0 {
    // If no actors found, treat all non-group children as actors
    for child in children {
      if not(is_sequence_group(child)) {
        actors.push(child)
      }
    }
  }
  if actors.length() == 0 {
    return { activation_boxes: [], notes: [], end_y: 0.0 }
  }
  // Build actor rank map (horizontal position index)
  let actor_rank : Map[String, Int] = {}
  for i, actor in actors {
    actor_rank[actor.get_id()] = i
  }
  // Place actors horizontally
  let max_actor_height = place_sequence_actors(actors, config)
  // Route messages and compute activation boxes
  let messages = collect_sequence_messages_from_graph(graph, container_id)
  let start_y = max_actor_height +
    lifeline_start_offset +
    config.container_padding
  let (message_end_y, activation_boxes, message_positions) = route_messages_with_positions(
    messages, actors, start_y,
  )
  // Create fragments for groups
  create_sequence_fragments(graph, groups, messages, message_positions, actors)
  // Collect and position notes
  let notes = collect_and_position_notes(
    actors, graph, container_id, message_end_y,
  )
  // Calculate final Y position after notes
  let mut final_y = message_end_y
  for note in notes {
    let note_bottom = note.bbox.get_y() + note.bbox.get_height()
    if note_bottom > final_y {
      final_y = note_bottom
    }
  }
  // Calculate total dimensions
  let mut total_width = 0.0
  for actor in actors {
    if actor.get_box() is Some(b) {
      let right = b.get_x() + b.get_width()
      if right > total_width {
        total_width = right
      }
    }
  }
  // Account for note width extending beyond actors
  for note in notes {
    let right = note.bbox.get_x() + note.bbox.get_width()
    if right > total_width {
      total_width = right
    }
  }
  total_width = total_width + config.container_padding * 2.0
  let total_height = final_y + config.container_padding
  container.set_box(@graph.Box::new(0.0, 0.0, total_width, total_height))
  // Add lifelines as dashed edges (from actor bottom to diagram end)
  add_lifeline_edges(graph, actors, max_actor_height, final_y, config)
  // Add activation boxes as objects
  add_activation_box_objects(graph, activation_boxes)
  // Store notes in graph for backward compatibility
  for note in notes {
    graph.sequence_notes.push((note.actor_id, note.text, note.bbox))
  }
  { activation_boxes, notes, end_y: final_y }
}

///|
/// Place actors horizontally at the top
fn place_sequence_actors(
  actors : Array[Object],
  config : LayoutConfig,
) -> Double {
  let mut max_height = 0.0
  let mut x = config.container_padding
  for actor in actors {
    // Use actor's existing width or default minimum
    let mut width = config.default_width
    if width < min_actor_width {
      width = min_actor_width
    }
    let height = config.default_height
    if height > max_height {
      max_height = height
    }
    // Set actor position
    actor.set_box(@graph.Box::new(x, config.container_padding, width, height))
    x = x + width + min_actor_distance
  }
  max_height
}

///|
/// Collect all edges that represent messages in the sequence diagram
fn collect_sequence_messages_from_graph(
  graph : Graph,
  container_id : String,
) -> Array[Edge] {
  let messages : Array[Edge] = []
  // Find edges whose source and destination are children of this container
  for edge in graph.get_edges() {
    let src_id = edge.get_src_id()
    let dst_id = edge.get_dst_id()
    // Check if both endpoints are within this sequence diagram
    if is_child_of_container(src_id, container_id) &&
      is_child_of_container(dst_id, container_id) {
      messages.push(edge)
    }
  }
  messages
}

///|
/// Check if a node ID is a direct or nested child of a container
fn is_child_of_container(node_id : String, container_id : String) -> Bool {
  // Special case: root container's children don't have "root." prefix
  // They are top-level objects like "alice", not "root.alice"
  if container_id == "root" {
    // For root container, any node without dots is a direct child
    // Nodes with dots are nested within other containers, not direct children of root
    return not(node_id.contains("."))
  }
  // Direct child: parent.child
  if node_id.has_prefix(container_id + ".") {
    return true
  }
  // Handle nested paths
  let prefix = container_id + "."
  node_id.has_prefix(prefix)
}

///|
/// Route messages with positions tracking
/// Returns (final_y, activation_boxes, message_positions)
fn route_messages_with_positions(
  messages : Array[Edge],
  actors : Array[Object],
  start_y : Double,
) -> (Double, Array[ActivationBox], Map[Int, Double]) {
  let mut current_y = start_y
  let activation_boxes : Array[ActivationBox] = []
  let message_positions : Map[Int, Double] = {}
  // Track active activation boxes per actor (stack for nested activations)
  let active_stacks : Map[String, Array[ActivationBox]] = {}
  // Initialize empty stacks for all actors
  for actor in actors {
    active_stacks[actor.get_id()] = []
  }
  // Process messages in definition order
  for i, edge in messages {
    let src_id = edge.get_src_id()
    let dst_id = edge.get_dst_id()
    let src_actor_id = extract_actor_id(src_id)
    let dst_actor_id = extract_actor_id(dst_id)
    let src_actor = find_actor_by_suffix(actors, src_actor_id)
    let dst_actor = find_actor_by_suffix(actors, dst_actor_id)
    if src_actor is Some(src) && dst_actor is Some(dst) {
      // Track position for this message (using array index)
      message_positions[i] = current_y
      // Route the message
      route_message(edge, src, dst, current_y)
      // Handle activation boxes
      if src.get_id() == dst.get_id() {
        // Self-message: create a short activation box
        if src.get_box() is Some(src_box) {
          let center_x = src_box.get_x() + src_box.get_width() / 2.0
          let self_box = ActivationBox::new(src.get_id(), center_x, current_y)
          self_box.end_y = current_y + min_message_distance / 2.0
          activation_boxes.push(self_box)
        }
      } else {
        // Normal message: destination becomes active
        if dst.get_box() is Some(dst_box) {
          let center_x = dst_box.get_x() + dst_box.get_width() / 2.0
          // Check if there's already an active box for the destination
          let dst_stack = active_stacks.get(dst.get_id())
          if dst_stack is Some(stack) {
            if stack.length() == 0 {
              // Start a new activation
              let new_box = ActivationBox::new(
                dst.get_id(),
                center_x,
                current_y,
              )
              stack.push(new_box)
            }
          }
        }
        // If source has an active box, extend it to this point
        let src_stack = active_stacks.get(src.get_id())
        if src_stack is Some(stack) && stack.length() > 0 {
          let active_box = stack[stack.length() - 1]
          active_box.end_y = current_y
        }
      }
      current_y = current_y + min_message_distance
    }
  }
  // Close all remaining activation boxes
  for actor in actors {
    if active_stacks.get(actor.get_id()) is Some(stack) {
      for box in stack {
        box.end_y = current_y
        activation_boxes.push(box)
      }
    }
  }
  (current_y, activation_boxes, message_positions)
}

///|
/// Create sequence fragments from groups
fn create_sequence_fragments(
  graph : Graph,
  groups : Array[Object],
  messages : Array[Edge],
  message_positions : Map[Int, Double],
  actors : Array[Object],
) -> Unit {
  let fragment_padding = 10.0
  for group in groups {
    let group_id = group.get_id()
    let group_label = group.get_label()
    // Determine fragment type from label (alt, opt, loop, par, break, critical)
    let fragment_type = parse_fragment_type(group_label)
    // Find messages that belong to this group (edge IDs contain group prefix)
    let mut min_y = 1000000.0 // Large value as infinity placeholder
    let mut max_y = -1000000.0 // Large negative value
    let mut start_idx = -1
    let mut end_idx = -1
    for i, edge in messages {
      let src_id = edge.get_src_id()
      let dst_id = edge.get_dst_id()
      // Check if this edge belongs to this group
      if edge_belongs_to_group(src_id, dst_id, group_id) {
        if message_positions.get(i) is Some(y) {
          if y < min_y {
            min_y = y
            start_idx = i
          }
          if y > max_y {
            max_y = y
            end_idx = i
          }
        }
      }
    }
    // If we found messages for this group, create a fragment
    if start_idx >= 0 && end_idx >= 0 {
      // Calculate bounding box - span from leftmost to rightmost actor
      let (left_x, right_x) = compute_actor_span(actors)
      let bbox = @graph.Box::new(
        left_x - fragment_padding,
        min_y - fragment_padding,
        right_x - left_x + fragment_padding * 2.0,
        max_y - min_y + min_message_distance + fragment_padding * 2.0,
      )
      // Create the fragment
      let fragment = SequenceFragment::new(fragment_type, start_idx, end_idx)
      fragment.bbox = Some(bbox)
      // Parse condition from label if present (e.g., "alt [x > 0]")
      fragment.condition = parse_fragment_condition(group_label)
      graph.add_fragment(fragment)
    }
  }
}

///|
/// Check if an object is a sequence group/fragment (container with fragment-like label)
fn is_sequence_group(obj : Object) -> Bool {
  if not(obj.is_container()) {
    return false
  }
  // Check if label starts with a known fragment type
  let label = obj.get_label().to_lower()
  let known_types = [
    "alt", "opt", "loop", "par", "break", "critical", "neg", "ref",
  ]
  for t in known_types {
    if label.has_prefix(t) {
      return true
    }
  }
  false
}

///|
/// Parse fragment type from label (returns lowercase type like "alt", "opt", "loop")
fn parse_fragment_type(label : String) -> String {
  let lower = label.to_lower()
  let known_types = [
    "alt", "opt", "loop", "par", "break", "critical", "neg", "ref",
  ]
  for t in known_types {
    if lower.has_prefix(t) {
      return t
    }
  }
  // Default to the label itself for custom types
  label
}

///|
/// Parse condition from fragment label (e.g., "alt [x > 0]" -> "[x > 0]")
fn parse_fragment_condition(label : String) -> String? {
  // Find [ and ] in the label
  let mut start = -1
  let mut end = -1
  for i in 0..<label.length() {
    let cu = label.code_unit_at(i)
    if cu == '['.to_int().to_uint16() && start < 0 {
      start = i
    }
    if cu == ']'.to_int().to_uint16() {
      end = i
    }
  }
  if start >= 0 && end > start {
    Some(substring(label, start, end + 1))
  } else {
    None
  }
}

///|
/// Check if an edge belongs to a group based on its src/dst IDs
fn edge_belongs_to_group(
  src_id : String,
  dst_id : String,
  group_id : String,
) -> Bool {
  let group_prefix = group_id + "."
  // Edge belongs to group if either endpoint has the group prefix
  src_id.has_prefix(group_prefix) || dst_id.has_prefix(group_prefix)
}

///|
/// Compute the horizontal span of all actors (leftmost x to rightmost x + width)
fn compute_actor_span(actors : Array[Object]) -> (Double, Double) {
  let mut left = 1000000.0 // Large value as infinity placeholder
  let mut right = -1000000.0 // Large negative value
  for actor in actors {
    if actor.get_box() is Some(box) {
      let x = box.get_x()
      let w = box.get_width()
      if x < left {
        left = x
      }
      if x + w > right {
        right = x + w
      }
    }
  }
  (left, right)
}

///|
/// Extract the actor ID from a full path (e.g., "seq.alice" -> "alice")
fn extract_actor_id(full_id : String) -> String {
  // Find last dot
  let mut last_dot = -1
  for i in 0..<full_id.length() {
    if full_id.code_unit_at(i) == '.'.to_int().to_uint16() {
      last_dot = i
    }
  }
  if last_dot >= 0 {
    substring(full_id, last_dot + 1, full_id.length())
  } else {
    full_id
  }
}

///|
/// Extract a substring
fn substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i in start..<end {
    match s.code_unit_at(i).to_char() {
      Some(c) => buf.write_char(c)
      None => ()
    }
  }
  buf.to_string()
}

///|
/// Find an actor whose ID ends with the given suffix
fn find_actor_by_suffix(actors : Array[Object], suffix : String) -> Object? {
  for actor in actors {
    let id = actor.get_id()
    if id.has_suffix("." + suffix) || id == suffix {
      return Some(actor)
    }
  }
  None
}

///|
/// Route a single message between two actors
fn route_message(edge : Edge, src : Object, dst : Object, y : Double) -> Unit {
  // Clear existing route points
  edge.route.clear()
  if src.get_box() is Some(src_box) && dst.get_box() is Some(dst_box) {
    // Calculate lifeline center positions
    let src_center_x = src_box.get_x() + src_box.get_width() / 2.0
    let dst_center_x = dst_box.get_x() + dst_box.get_width() / 2.0
    // Check if this is a self-referential message
    if src.get_id() == dst.get_id() {
      // Self-message: create a loop
      let loop_right = src_center_x + self_message_width
      edge.add_route_point(@graph.Point::new(src_center_x, y))
      edge.add_route_point(@graph.Point::new(loop_right, y))
      edge.add_route_point(
        @graph.Point::new(loop_right, y + min_message_distance / 2.0),
      )
      edge.add_route_point(
        @graph.Point::new(src_center_x, y + min_message_distance / 2.0),
      )
    } else {
      // Normal message: straight line between lifelines
      edge.add_route_point(@graph.Point::new(src_center_x, y))
      edge.add_route_point(@graph.Point::new(dst_center_x, y))
    }
  }
}

///|
/// Check if object is a sequence diagram
pub fn is_sequence_diagram(obj : Object) -> Bool {
  obj.get_shape() == "sequence_diagram"
}

///|
/// Check if an object is an actor in a sequence diagram (involved in edges)
fn is_actor_in_sequence(
  obj : Object,
  graph : Graph,
  container_id : String,
) -> Bool {
  let obj_id = obj.get_id()
  // Check if this object is the source or destination of any edge within the sequence diagram
  for edge in graph.get_edges() {
    let src_id = edge.get_src_id()
    let dst_id = edge.get_dst_id()
    // Check if both endpoints are in this container and this object is one of them
    if is_child_of_container(src_id, container_id) &&
      is_child_of_container(dst_id, container_id) {
      // Check if obj_id matches src or dst (with possible prefix)
      if src_id == obj_id ||
        dst_id == obj_id ||
        src_id.has_suffix("." + extract_actor_id(obj_id)) ||
        dst_id.has_suffix("." + extract_actor_id(obj_id)) {
        return true
      }
    }
  }
  false
}

///|
/// Check if an object is a note (child of an actor with no edge references)
fn is_sequence_note(obj : Object, graph : Graph, container_id : String) -> Bool {
  // Notes are objects that are NOT involved in any edges
  // and have no children
  if obj.get_children().length() > 0 {
    return false
  }
  // Check if this object is referenced by any edge
  not(is_actor_in_sequence(obj, graph, container_id))
}

///|
/// Collect notes from actors and position them below their parent actor
fn collect_and_position_notes(
  actors : Array[Object],
  graph : Graph,
  container_id : String,
  start_y : Double,
) -> Array[SequenceNote] {
  let notes : Array[SequenceNote] = []
  // For each actor, look for children that are notes
  for actor in actors {
    let actor_children = actor.get_children()
    let mut note_y = start_y + note_padding
    for child in actor_children {
      if is_sequence_note(child, graph, container_id) {
        // Position the note centered below the actor's lifeline
        if actor.get_box() is Some(actor_box) {
          let actor_center_x = actor_box.get_x() + actor_box.get_width() / 2.0
          let note_x = actor_center_x - note_width / 2.0
          let note_text = child.get_label()
          let note_bbox = @graph.Box::new(
            note_x, note_y, note_width, note_height,
          )
          // Also set the child's box so it can be rendered
          child.set_box(note_bbox)
          notes.push(SequenceNote::new(actor.get_id(), note_text, note_bbox))
          note_y = note_y + note_height + note_padding
        }
      }
    }
  }
  notes
}

///|
/// Add lifeline edges for each actor (dashed vertical lines from actor bottom to diagram end)
fn add_lifeline_edges(
  graph : Graph,
  actors : Array[Object],
  actor_bottom_y : Double,
  end_y : Double,
  config : LayoutConfig,
) -> Unit {
  let lifeline_start_y = actor_bottom_y + config.container_padding
  for actor in actors {
    if actor.get_box() is Some(actor_box) {
      let center_x = actor_box.get_x() + actor_box.get_width() / 2.0
      // Create a lifeline edge with no arrows and dashed stroke
      let edge_index = graph.get_edges().length()
      let lifeline_id = actor.get_id() + "__lifeline"
      let edge = Edge::new(
        edge_index, lifeline_id, // Use a pseudo ID for the lifeline source
         lifeline_id, // Same for destination (self-edge)
         false, // No source arrow
         false, // No destination arrow
      )
      // Set dashed stroke style
      edge.style.stroke_dash = Some(6.0)
      // Add route points (vertical line from actor bottom to diagram end)
      edge.add_route_point(@graph.Point::new(center_x, lifeline_start_y))
      edge.add_route_point(@graph.Point::new(center_x, end_y))
      graph.add_edge(edge)
    }
  }
}

///|
/// Add activation boxes as objects
fn add_activation_box_objects(
  graph : Graph,
  activation_boxes : Array[ActivationBox],
) -> Unit {
  for i, ab in activation_boxes {
    let box = ab.get_box()
    let obj_id = ab.actor_id + "__activation_" + i.to_string()
    let obj = Object::new(obj_id)
    obj.set_label("") // No label for activation boxes
    obj.set_box(box)
    // Store in graph's activation_boxes for backward compatibility
    graph.activation_boxes.push((ab.actor_id, box))
    // Also add as a regular object for format-agnostic rendering
    graph.add_object(obj)
  }
}
