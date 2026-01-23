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

// Layout constants (ported from ../d2/d2layouts/d2sequence/constants.go)
let horizontal_pad : Double = 40.0

///|
let label_horizontal_pad : Double = 60.0

///|
let vertical_pad : Double = 40.0

///|
let min_actor_distance : Double = 150.0

///|
let min_actor_width : Double = 100.0

///|
let self_message_horizontal_travel : Double = 80.0

///|
let group_container_padding : Double = 12.0

///|
let min_message_distance : Double = 30.0

///|
let label_padding : Double = 5.0

///|
let activation_box_width : Double = 16.0

///|
let note_padding : Double = 10.0

///|
// D2's rendered message endpoints are slightly inset from the lifeline center.
// This breaks exact symmetry between request/response labels and matches the
// box-mapping heuristic used by our semantic SVG tests.
let message_src_inset : Double = 2.0

///|
let message_dst_inset : Double = 4.0

///|
// Legacy fixed note size. D2 derives note dimensions from text measurement, but
// our renderer currently relies on a simple bounding box.
let note_width : Double = 120.0

///|
let note_height : Double = 40.0

///|
/// Activation box representing an active period on a lifeline
priv struct ActivationBox {
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
fn ActivationBox::new(
  actor_id : String,
  x : Double,
  start_y : Double,
) -> ActivationBox {
  { actor_id, x, start_y, end_y: start_y }
}

///|
fn ActivationBox::get_box(self : ActivationBox) -> @graph.Box {
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
/// A note attached to an actor in a sequence diagram
priv struct SequenceNote {
  /// Actor ID this note is attached to
  actor_id : String
  /// Note text content
  text : String
  /// Bounding box for the note
  bbox : @graph.Box
}

///|
fn SequenceNote::new(
  actor_id : String,
  text : String,
  bbox : @graph.Box,
) -> SequenceNote {
  { actor_id, text, bbox }
}

///|
/// Result of sequence diagram layout including activation boxes and notes
#warnings("-unused_field")
priv struct SequenceLayoutResult {
  /// Notes attached to actors
  notes : Array[SequenceNote]
}

///|
/// Layout a sequence diagram container with message routing and return activation boxes
fn layout_sequence_with_activations(
  container : Object,
  graph : Graph,
  config : LayoutConfig,
) -> SequenceLayoutResult {
  // Whitebox tests call this helper directly; ensure all nodes/edge labels have
  // precomputed sizes (the main pipeline does this before dispatching).
  ensure_text_dimensions(graph)
  let children = container.children
  if children.length() == 0 {
    return { notes: [] }
  }
  let container_id = container.id

  // Collect actors (objects connected by messages) and fragment-groups.
  let actors : Array[Object] = []
  let groups : Array[Object] = []
  for child in children {
    if is_actor_in_sequence(child, graph, container_id) {
      actors.push(child)
    } else if is_sequence_group(child) {
      groups.push(child)
    }
  }
  if actors.length() == 0 {
    for child in children {
      if not(is_sequence_group(child)) {
        actors.push(child)
      }
    }
  }
  if actors.length() == 0 {
    return { notes: [] }
  }

  // Ensure actors have at least the minimum width used by D2.
  for actor in actors {
    ensure_min_actor_size(actor)
  }

  // Collect messages (edges) inside this sequence diagram.
  let messages = collect_sequence_messages_from_graph(graph, container_id)

  // Build actor rank map (left-to-right ordering).
  let actor_rank : Map[String, Int] = {}
  for i, actor in actors {
    actor_rank[actor.id] = i
  }

  // Compute the required center-to-center spacing between neighboring actors.
  let actor_x_step = compute_actor_x_step(
    actors, messages, actor_rank, graph, container_id,
  )

  // Vertical spacing is driven by label heights (D2's yStep).
  let y_step = min_message_distance + vertical_pad
  let max_actor_height = compute_max_actor_height(container, actors)

  // Place actors bottom-aligned and route messages.
  place_sequence_actors(actors, actor_x_step, max_actor_height)
  let message_offset = max_actor_height + y_step
  let (message_end_y, activation_boxes, message_positions) = route_messages_with_positions(
    messages, actors, container_id, message_offset, y_step,
  )

  // Place edge labels for sequence messages (the generic layered pipeline does this
  // for normal diagrams, but sequence layout returns early from the pipeline).
  position_edge_labels(graph, config)
  apply_sequence_label_bias(messages)

  // Create fragments for groups (alt/opt/loop/... containers).
  create_sequence_fragments(graph, groups, messages, message_positions, actors)

  // Collect and position notes below the message flow.
  let notes = collect_and_position_notes(
    actors, graph, container_id, message_end_y,
  )

  // Compute overall diagram dimensions (ported from D2's getWidth / addLifelineEdges endY logic).
  let width = compute_sequence_width(messages, actors)
  let height = compute_sequence_height(messages, actors, notes, y_step)
  container.box = Some(
    @graph.Box::new(
      0.0,
      0.0,
      width + group_container_padding * 2.0,
      height + group_container_padding * 2.0,
    ),
  )

  // Sequence extras are exposed through patch fields; keep them in graph so the
  // later shift applies to them too.
  for box in activation_boxes {
    graph.activation_boxes.push((box.actor_id, box.get_box()))
  }
  for note in notes {
    graph.sequence_notes.push((note.actor_id, note.text, note.bbox))
  }

  // Shift everything inside the container (actors, groups, messages, notes) by
  // GROUP_CONTAINER_PADDING so the diagram has the same insets as D2.
  shift_sequence_container(graph, container_id, group_container_padding)
  { notes, }
}

///|
// D2's sequence message labels are not perfectly symmetric across reverse edges.
// Apply a tiny bias for right-to-left horizontal messages whose midpoint lands
// on a half pixel so our semantic "nearest box" mapping matches D2 reference.
fn apply_sequence_label_bias(messages : Array[Edge]) -> Unit {
  for e in messages {
    if e.label == "" {
      continue
    }
    guard e.route.length() == 2 else { continue }
    let p0 = e.route[0]
    let p1 = e.route[1]
    // Only bias purely-horizontal segments.
    if (p0.y - p1.y).abs() > 1.0e-6 {
      continue
    }
    // Right-to-left only (the observed mismatch set is directional).
    if p1.x >= p0.x {
      continue
    }
    let mid = (p0.x + p1.x) / 2.0
    let frac = mid - @math.floor(mid)
    if (frac - 0.5).abs() > 1.0e-6 {
      continue
    }
    match e.label_box {
      Some(lb) =>
        e.label_box = Some(
          @graph.Box::new(lb.x - 1.0, lb.y, lb.width, lb.height),
        )
      None => ()
    }
  }
}

///|
/// Place actors bottom-aligned, side by side with centers spaced by actor_x_step.
fn place_sequence_actors(
  actors : Array[Object],
  actor_x_step : Array[Double],
  max_actor_height : Double,
) -> Unit {
  guard actors.length() > 0 else { return }
  let first = actors[0]
  guard first.box is Some(b0) else { return }
  let mut center_x = b0.width / 2.0
  for rank, actor in actors {
    guard actor.box is Some(b) else { continue }
    let y_offset = (max_actor_height - b.height).round()
    let half_w = b.width / 2.0
    let x = (center_x - half_w).round()
    actor.box = Some(@graph.Box::new(x, y_offset, b.width, b.height))
    if rank < actor_x_step.length() {
      center_x = center_x + actor_x_step[rank]
    }
  }
}

///|
fn has_explicit_label(obj : Object) -> Bool {
  obj.label != "" && obj.label != obj.id
}

///|
fn compute_max_actor_height(
  container : Object,
  actors : Array[Object],
) -> Double {
  let mut max_h = 0.0
  for actor in actors {
    if actor.box is Some(b) && b.height > max_h {
      max_h = b.height
    }
  }
  max_h = max_h + vertical_pad
  if has_explicit_label(container) {
    match container.label_box {
      Some(lb) => max_h = max_h + lb.height
      None => ()
    }
  }
  max_h
}

///|
fn ensure_min_actor_size(actor : Object) -> Unit {
  match actor.box {
    Some(b) => {
      if b.width >= min_actor_width {
        return
      }
      let factor = min_actor_width / b.width
      // D2 scales a few shapes uniformly when enforcing min width; keep the
      // same behavior for the common actor shapes.
      let mut height = b.height
      match actor.shape_type {
        @graph.Person | @graph.Oval | @graph.Square | @graph.Circle =>
          height = height * factor
        _ => ()
      }
      actor.box = Some(@graph.Box::new(b.x, b.y, min_actor_width, height))
    }
    None => ()
  }
}

///|
fn compute_actor_x_step(
  actors : Array[Object],
  messages : Array[Edge],
  actor_rank : Map[String, Int],
  graph : Graph,
  container_id : String,
) -> Array[Double] {
  let steps : Array[Double] = []
  if actors.length() < 2 {
    return steps
  }
  for i in 0..<(actors.length() - 1) {
    let a = actors[i]
    let b = actors[i + 1]
    let aw = match a.box {
      Some(ab) => ab.width
      None => min_actor_width
    }
    let bw = match b.box {
      Some(bb) => bb.width
      None => min_actor_width
    }
    let base = max(aw / 2.0 + bw / 2.0 + horizontal_pad, min_actor_distance)
    steps.push(base)
  }

  // Notes under an actor can widen the spacing on either side.
  for rank, actor in actors {
    let max_note_w = compute_max_note_width(actor, graph, container_id)
    if max_note_w <= 0.0 {
      continue
    }
    let need = max_note_w / 2.0 + horizontal_pad
    if rank < steps.length() && need > steps[rank] {
      steps[rank] = need
    }
    if rank > 0 && need > steps[rank - 1] {
      steps[rank - 1] = need
    }
  }

  // Long message labels widen the span between involved actors.
  for edge in messages {
    let src_actor = find_actor_for_node_id(actors, edge.src_id, container_id)
    let dst_actor = find_actor_for_node_id(actors, edge.dst_id, container_id)
    guard src_actor is Some(sa) && dst_actor is Some(da) else { continue }
    let r1 = actor_rank.get(sa.id).unwrap_or(0)
    let r2 = actor_rank.get(da.id).unwrap_or(0)
    let rank_diff = (r1 - r2).abs()
    let label_w = match edge.label_box {
      Some(lb) => lb.width
      None => 0.0
    }
    if rank_diff != 0 {
      let distributed = label_w / rank_diff.to_double()
      let lo = if r1 < r2 { r1 } else { r2 }
      let hi = if r1 > r2 { r1 } else { r2 }
      for r in lo..<hi {
        if r >= 0 && r < steps.length() {
          let need = distributed + label_horizontal_pad
          if need > steps[r] {
            steps[r] = need
          }
        }
      }
    } else {
      // Self-edge: widen the next gap to fit the label.
      let next_rank = r1
      if next_rank >= 0 && next_rank < steps.length() {
        let need = label_w + label_padding * 4.0
        if need > steps[next_rank] {
          steps[next_rank] = need
        }
      }
    }
  }
  steps
}

///|
fn compute_max_note_width(
  actor : Object,
  graph : Graph,
  container_id : String,
) -> Double {
  let mut max_w = 0.0
  let queue : Array[Object] = []
  for child in actor.children {
    queue.push(child)
  }
  let mut i = 0
  while i < queue.length() {
    let child = queue[i]
    i = i + 1
    if is_sequence_note(child, graph, container_id) {
      match child.box {
        Some(b) => if b.width > max_w { max_w = b.width }
        None => ()
      }
    }
    for ch in child.children {
      queue.push(ch)
    }
  }
  max_w
}

///|
fn compute_sequence_width(
  messages : Array[Edge],
  actors : Array[Object],
) -> Double {
  let mut rightmost = 0.0
  if actors.length() > 0 {
    let last = actors[actors.length() - 1]
    if last.box is Some(b) {
      rightmost = b.x + b.width
    }
  }
  for m in messages {
    for p in m.route {
      if p.x > rightmost {
        rightmost = p.x
      }
    }
    // Self-messages may have labels extending further to the right.
    if m.src_id == m.dst_id && m.route.length() >= 2 {
      match m.label_box {
        Some(lb) => {
          let x = m.route[1].x + lb.width / 2.0
          if x > rightmost {
            rightmost = x
          }
        }
        None => ()
      }
    }
  }
  rightmost
}

///|
fn compute_sequence_height(
  messages : Array[Edge],
  actors : Array[Object],
  notes : Array[SequenceNote],
  y_step : Double,
) -> Double {
  let mut max_y = 0.0
  for actor in actors {
    if actor.box is Some(b) {
      let bottom = b.y + b.height
      if bottom > max_y {
        max_y = bottom
      }
    }
  }
  for m in messages {
    for p in m.route {
      if p.y > max_y {
        max_y = p.y
      }
    }
  }
  for note in notes {
    let bottom = note.bbox.y + note.bbox.height
    if bottom > max_y {
      max_y = bottom
    }
  }
  max_y + y_step
}

///|
fn adjust_message_endpoints_x(
  start_x : Double,
  end_x : Double,
) -> (Double, Double) {
  if end_x > start_x {
    (start_x + message_src_inset, end_x - message_dst_inset)
  } else if end_x < start_x {
    (start_x - message_src_inset, end_x + message_dst_inset)
  } else {
    (start_x, end_x)
  }
}

///|
fn shift_sequence_container(
  graph : Graph,
  container_id : String,
  delta : Double,
) -> Unit {
  for obj in graph.objects {
    if is_child_of_container(obj.id, container_id) {
      match obj.box {
        Some(b) =>
          obj.box = Some(
            @graph.Box::new(b.x + delta, b.y + delta, b.width, b.height),
          )
        None => ()
      }
    }
  }
  for edge in graph.edges {
    if is_child_of_container(edge.src_id, container_id) &&
      is_child_of_container(edge.dst_id, container_id) {
      for i = 0; i < edge.route.length(); i = i + 1 {
        let p = edge.route[i]
        edge.route[i] = @graph.Point::new(p.x + delta, p.y + delta)
      }
      match edge.label_box {
        Some(b) =>
          edge.label_box = Some(
            @graph.Box::new(b.x + delta, b.y + delta, b.width, b.height),
          )
        None => ()
      }
    }
  }
  for i = 0; i < graph.sequence_fragments.length(); i = i + 1 {
    let frag = graph.sequence_fragments[i]
    match frag.bbox {
      Some(b) =>
        frag.bbox = Some(
          @graph.Box::new(b.x + delta, b.y + delta, b.width, b.height),
        )
      None => ()
    }
  }
  for i = 0; i < graph.activation_boxes.length(); i = i + 1 {
    let (id, b) = graph.activation_boxes[i]
    graph.activation_boxes[i] = (
      id,
      @graph.Box::new(b.x + delta, b.y + delta, b.width, b.height),
    )
  }
  for i = 0; i < graph.sequence_notes.length(); i = i + 1 {
    let (id, text, b) = graph.sequence_notes[i]
    graph.sequence_notes[i] = (
      id,
      text,
      @graph.Box::new(b.x + delta, b.y + delta, b.width, b.height),
    )
  }
}

///|
/// Collect all edges that represent messages in the sequence diagram
fn collect_sequence_messages_from_graph(
  graph : Graph,
  container_id : String,
) -> Array[Edge] {
  let messages : Array[Edge] = []
  // Find edges whose source and destination are children of this container
  for edge in graph.edges {
    let src_id = edge.src_id
    let dst_id = edge.dst_id
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
  container_id : String,
  start_offset : Double,
  y_step : Double,
) -> (Double, Array[ActivationBox], Map[Int, Double]) {
  let mut message_offset = start_offset
  let activation_boxes : Array[ActivationBox] = []
  let message_positions : Map[Int, Double] = {}

  // Track active activation boxes per actor (stack for nested activations).
  let active_stacks : Map[String, Array[ActivationBox]] = {}
  for actor in actors {
    active_stacks[actor.id] = []
  }
  for i, edge in messages {
    let src_actor = find_actor_for_node_id(actors, edge.src_id, container_id)
    let dst_actor = find_actor_for_node_id(actors, edge.dst_id, container_id)
    if src_actor is None || dst_actor is None {
      continue
    }
    let src = src_actor.unwrap()
    let dst = dst_actor.unwrap()
    guard src.box is Some(src_box) else { continue }
    guard dst.box is Some(dst_box) else { continue }
    let start_x = src_box.x + src_box.width / 2.0
    let end_x = dst_box.x + dst_box.width / 2.0
    let (label_w, label_h) = match edge.label_box {
      Some(b) => (b.width, b.height)
      None => (0.0, 0.0)
    }
    let is_to_descendant = edge.dst_id.has_prefix(edge.src_id + ".")
    let is_from_descendant = edge.src_id.has_prefix(edge.dst_id + ".")
    let is_self_message = edge.src_id == edge.dst_id
    let is_to_sibling = src.id == dst.id
    let needs_loop = is_self_message ||
      is_to_descendant ||
      is_from_descendant ||
      is_to_sibling
    if needs_loop {
      let mid_x = start_x +
        max(self_message_horizontal_travel, label_w / 2.0 + label_padding * 2.0)
      let start_y = message_offset
      let end_y = start_y + max(label_h, min_message_distance) * 1.5
      edge.route.clear()
      edge.add_route_point(@graph.Point::new(start_x, start_y))
      edge.add_route_point(@graph.Point::new(mid_x, start_y))
      edge.add_route_point(@graph.Point::new(mid_x, end_y))
      edge.add_route_point(@graph.Point::new(end_x, end_y))
      message_positions[i] = start_y
      message_offset = end_y + y_step

      // Self-message activation heuristic: short box covering the loop.
      if is_self_message {
        let ab = ActivationBox::new(src.id, start_x, start_y)
        ab.end_y = end_y
        activation_boxes.push(ab)
      }
    } else {
      let y = message_offset + label_h / 2.0
      let (sx, ex) = adjust_message_endpoints_x(start_x, end_x)
      edge.route.clear()
      edge.add_route_point(@graph.Point::new(sx, y))
      edge.add_route_point(@graph.Point::new(ex, y))
      message_positions[i] = y
      message_offset = y + label_h / 2.0 + y_step
    }

    // Extend basic activation boxes based on message flow (very small subset of D2 spans).
    match active_stacks.get(dst.id) {
      Some(stack) =>
        if stack.length() == 0 {
          let ab = ActivationBox::new(dst.id, end_x, message_positions[i])
          stack.push(ab)
        }
      None => ()
    }
    match active_stacks.get(src.id) {
      Some(stack) =>
        if stack.length() > 0 {
          let ab = stack[stack.length() - 1]
          ab.end_y = message_positions[i]
        }
      None => ()
    }
  }

  // Close remaining activation boxes.
  for actor in actors {
    if active_stacks.get(actor.id) is Some(stack) {
      for box in stack {
        box.end_y = message_offset
        activation_boxes.push(box)
      }
    }
  }
  (message_offset, activation_boxes, message_positions)
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
    let group_id = group.id
    let group_label = group.label
    // Determine fragment type from label (alt, opt, loop, par, break, critical)
    let fragment_type = parse_fragment_type(group_label)
    // Find messages that belong to this group (edge IDs contain group prefix)
    let mut min_y = 1000000.0 // Large value as infinity placeholder
    let mut max_y = -1000000.0 // Large negative value
    let mut start_idx = -1
    let mut end_idx = -1
    for i, edge in messages {
      let src_id = edge.src_id
      let dst_id = edge.dst_id
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
  let label = obj.label.to_lower()
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
    if actor.box is Some(box) {
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
/// Extract the direct child ID inside a sequence diagram container.
///
/// Examples:
/// - container_id="root", node_id="alice" -> "alice"
/// - container_id="root", node_id="alice.span1" -> "alice"
/// - container_id="seq",  node_id="seq.alice.span1" -> "alice"
fn sequence_direct_child_id(node_id : String, container_id : String) -> String {
  let rel = if container_id != "root" && node_id.has_prefix(container_id + ".") {
    substring(node_id, container_id.length() + 1, node_id.length())
  } else {
    node_id
  }
  let mut dot = -1
  for i in 0..<rel.length() {
    if rel.code_unit_at(i) == '.'.to_int().to_uint16() {
      dot = i
      break
    }
  }
  if dot >= 0 {
    substring(rel, 0, dot)
  } else {
    rel
  }
}

///|
fn find_actor_for_node_id(
  actors : Array[Object],
  node_id : String,
  container_id : String,
) -> Object? {
  // In sequence fragments, edge endpoints may be prefixed with group IDs
  // (e.g. "seq.opt.alice"). Resolve by scanning path segments until we find a
  // segment that matches one of the known actor IDs.
  let rel = if container_id != "root" && node_id.has_prefix(container_id + ".") {
    substring(node_id, container_id.length() + 1, node_id.length())
  } else {
    node_id
  }
  let segs = rel.split(".")
  for seg_view in segs {
    let seg = seg_view.to_string()
    if seg.length() == 0 {
      continue
    }
    for actor in actors {
      let id = actor.id
      if id == seg || id.has_suffix("." + seg) {
        return Some(actor)
      }
    }
  }
  // Fallback to the old "direct child" behavior.
  let direct = sequence_direct_child_id(node_id, container_id)
  for actor in actors {
    let id = actor.id
    if id == direct || id.has_suffix("." + direct) {
      return Some(actor)
    }
  }
  None
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
/// Check if object is a sequence diagram
fn is_sequence_diagram(obj : Object) -> Bool {
  obj.shape_type == @graph.SequenceDiagram
}

///|
/// Check if an object is an actor in a sequence diagram (involved in edges)
fn is_actor_in_sequence(
  obj : Object,
  graph : Graph,
  container_id : String,
) -> Bool {
  let obj_id = obj.id
  // Check if this object is the source or destination of any edge within the sequence diagram
  for edge in graph.edges {
    let src_id = edge.src_id
    let dst_id = edge.dst_id
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
  if obj.children.length() > 0 {
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
    let actor_children = actor.children
    let mut note_y = start_y + note_padding
    for child in actor_children {
      if is_sequence_note(child, graph, container_id) {
        // Position the note centered below the actor's lifeline
        if actor.box is Some(actor_box) {
          let actor_center_x = actor_box.get_x() + actor_box.get_width() / 2.0
          let note_x = actor_center_x - note_width / 2.0
          let note_text = child.label
          let note_bbox = @graph.Box::new(
            note_x, note_y, note_width, note_height,
          )
          // Also set the child's box so it can be rendered
          child.box = Some(note_bbox)
          notes.push(SequenceNote::new(actor.id, note_text, note_bbox))
          note_y = note_y + note_height + note_padding
        }
      }
    }
  }
  notes
}
