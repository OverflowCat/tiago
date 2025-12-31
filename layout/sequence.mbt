///|
/// Sequence Diagram Layout
///
/// Implements layout for sequence diagrams with actors, messages, and lifelines.

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
  // Separate actors from other elements
  let actors : Array[@graph.Object] = []
  for child in children {
    actors.push(child)
  }
  if actors.length() == 0 {
    return
  }
  // Place actors horizontally
  let max_actor_height = place_sequence_actors(actors, config)
  // Calculate total width
  let mut total_width = 0.0
  for actor in actors {
    match actor.get_box() {
      Some(b) => {
        let right = b.get_x() + b.get_width()
        if right > total_width {
          total_width = right
        }
      }
      None => ()
    }
  }
  total_width = total_width + config.container_padding * 2.0
  // Calculate total height based on message count (simplified)
  let message_count = 5 // Placeholder for actual message routing
  let msg_distance = 40.0 // MIN_MESSAGE_DISTANCE
  let total_height = max_actor_height +
    message_count.to_double() * msg_distance +
    config.container_padding * 2.0
  container.set_box(@graph.Box::new(0.0, 0.0, total_width, total_height))
}

///|
/// Place actors horizontally at the top
fn place_sequence_actors(
  actors : Array[@graph.Object],
  config : LayoutConfig,
) -> Double {
  let min_width = 100.0 // MIN_ACTOR_WIDTH
  let actor_distance = 150.0 // MIN_ACTOR_DISTANCE
  let mut max_height = 0.0
  let mut x = config.container_padding
  for actor in actors {
    // Ensure minimum width
    let mut width = config.default_width
    if width < min_width {
      width = min_width
    }
    let height = config.default_height
    if height > max_height {
      max_height = height
    }
    // Set actor position
    actor.set_box(@graph.Box::new(x, config.container_padding, width, height))
    x = x + width + actor_distance
  }
  max_height
}

///|
/// Check if object is a sequence diagram
pub fn is_sequence_diagram(obj : @graph.Object) -> Bool {
  obj.get_shape() == "sequence_diagram"
}
