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
/// Layout a sequence diagram container
pub fn layout_sequence(
  container : @graph.Object,
  config : LayoutConfig,
) -> Unit {
  let children = container.get_children()
  if children.length() == 0 {
    return
  }
  // Collect actors (direct children of sequence diagram)
  let actors : Array[@graph.Object] = []
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
/// Layout a sequence diagram container with message routing
pub fn layout_sequence_with_messages(
  container : @graph.Object,
  graph : @graph.Graph,
  config : LayoutConfig,
) -> Unit {
  let children = container.get_children()
  if children.length() == 0 {
    return
  }
  // Collect actors (direct children of sequence diagram)
  let actors : Array[@graph.Object] = []
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
  // Route messages and calculate their vertical positions
  let container_id = container.get_id()
  let messages = collect_sequence_messages_from_graph(graph, container_id)
  let message_end_y = route_sequence_messages(
    messages,
    actors,
    actor_rank,
    max_actor_height + lifeline_start_offset + config.container_padding,
  )
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
  let total_height = message_end_y + config.container_padding
  container.set_box(@graph.Box::new(0.0, 0.0, total_width, total_height))
}

///|
/// Place actors horizontally at the top
fn place_sequence_actors(
  actors : Array[@graph.Object],
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
  graph : @graph.Graph,
  container_id : String,
) -> Array[@graph.Edge] {
  let messages : Array[@graph.Edge] = []
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
  // Direct child: parent.child
  if node_id.has_prefix(container_id + ".") {
    return true
  }
  // Handle nested paths
  let prefix = container_id + "."
  node_id.has_prefix(prefix)
}

///|
/// Route sequence messages and return the final Y position
fn route_sequence_messages(
  messages : Array[@graph.Edge],
  actors : Array[@graph.Object],
  _actor_rank : Map[String, Int],
  start_y : Double,
) -> Double {
  let mut current_y = start_y
  // Messages are processed in definition order (temporal sequence)
  for edge in messages {
    let src_id = edge.get_src_id()
    let dst_id = edge.get_dst_id()
    // Extract actor IDs (last component of path)
    let src_actor_id = extract_actor_id(src_id)
    let dst_actor_id = extract_actor_id(dst_id)
    // Find source and destination actors
    let src_actor = find_actor_by_suffix(actors, src_actor_id)
    let dst_actor = find_actor_by_suffix(actors, dst_actor_id)
    if src_actor is Some(src) && dst_actor is Some(dst) {
      // Route the message
      route_message(edge, src, dst, current_y)
      // Move to next message position
      current_y = current_y + min_message_distance
    }
  }
  current_y
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
    buf.write_char(s.code_unit_at(i).to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Find an actor whose ID ends with the given suffix
fn find_actor_by_suffix(
  actors : Array[@graph.Object],
  suffix : String,
) -> @graph.Object? {
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
fn route_message(
  edge : @graph.Edge,
  src : @graph.Object,
  dst : @graph.Object,
  y : Double,
) -> Unit {
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
pub fn is_sequence_diagram(obj : @graph.Object) -> Bool {
  obj.get_shape() == "sequence_diagram"
}
