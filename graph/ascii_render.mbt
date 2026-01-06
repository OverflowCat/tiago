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
/// ASCII Renderer for Graph
///
/// Renders a laid-out Graph to ASCII art using the pure ascii library.

///|
/// ASCII rendering configuration
pub struct AsciiConfig {
  /// Minimum box width in characters
  min_box_width : Int
  /// Box height in lines
  box_height : Int
  /// Horizontal padding inside box
  h_padding : Int
  /// Vertical spacing between boxes
  v_spacing : Int
  /// Horizontal spacing between boxes
  h_spacing : Int
  /// Minimum canvas width
  min_width : Int
  /// Minimum canvas height
  min_height : Int
  /// Character set for rendering
  charset : @ascii.CharSet
} derive(Show)

///|
pub fn AsciiConfig::new() -> AsciiConfig {
  {
    min_box_width: 6,
    box_height: 4,
    h_padding: 1,
    v_spacing: 4,
    h_spacing: 2,
    min_width: 40,
    min_height: 10,
    charset: @ascii.CharSet::ascii(),
  }
}

///|
/// Create config with Unicode charset
pub fn AsciiConfig::unicode() -> AsciiConfig {
  {
    min_box_width: 6,
    box_height: 4,
    h_padding: 1,
    v_spacing: 4,
    h_spacing: 2,
    min_width: 40,
    min_height: 10,
    charset: @ascii.CharSet::unicode(),
  }
}

///|
/// Get the short name from a dotted ID (e.g., "users.id" -> "id")
fn get_short_id(id : String) -> String {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot >= 0 && last_dot < id.length() - 1 {
    // Build substring manually to avoid deprecated method
    let buf = StringBuilder::new()
    for i = last_dot + 1; i < id.length(); i = i + 1 {
      buf.write_char(id[i].to_int().unsafe_to_char())
    }
    buf.to_string()
  } else {
    id
  }
}

///|
/// ASCII box position and size in character coordinates
struct AsciiBox {
  id : String
  x : Int
  y : Int
  width : Int
  height : Int
  label : String
  shape : String
  /// Whether this is a container with children
  is_container : Bool
  /// Child boxes (if container)
  children : Array[AsciiBox]
} derive(Show)

///|
/// Render a graph to ASCII string
pub fn render_ascii(graph : Graph, config : AsciiConfig) -> String {
  // Check if this is a sequence diagram - use special renderer
  if graph.root.get_shape() == "sequence_diagram" {
    return render_ascii_sequence(graph, config)
  }
  // Compute ASCII layout for all objects
  let boxes = compute_ascii_layout(graph, config)
  // Calculate canvas dimensions
  let (canvas_width, canvas_height) = compute_canvas_size(boxes, config)
  let grid = @ascii.Grid::new(canvas_width, canvas_height)
  // Render objects first (containers and boxes)
  for box in boxes {
    render_ascii_box(grid, box, config)
  }
  // Render edge lines (will overwrite container borders where they pass through)
  for edge in graph.edges {
    for ref_idx = 0; ref_idx < edge.reference_count; ref_idx = ref_idx + 1 {
      render_ascii_edge_new(grid, graph, edge, ref_idx, boxes, config)
    }
  }
  // Re-render box labels on top of edges
  for box in boxes {
    let label_x = box.x + (box.width - box.label.length()) / 2
    let label_y = box.y + 1
    grid.text(label_x, label_y, box.label)
  }
  // Render edge labels
  for edge in graph.edges {
    render_ascii_label_new(grid, graph, edge, 0, boxes, config)
  }
  // Render edge arrows LAST (on top of everything)
  for edge in graph.edges {
    for ref_idx = 0; ref_idx < edge.reference_count; ref_idx = ref_idx + 1 {
      render_ascii_arrows_new(grid, graph, edge, ref_idx, boxes, config)
    }
  }
  grid.to_string()
}

///|
/// Render a sequence diagram to ASCII string
/// This uses a format-agnostic approach: all elements come from the graph structure
/// - Actors are objects with labels
/// - Lifelines are edges with vertical routes (dashed style)
/// - Messages are edges with horizontal routes
/// - Activation boxes are objects (rectangles with no labels)
fn render_ascii_sequence(graph : Graph, config : AsciiConfig) -> String {
  let cs = config.charset
  // Separate actors from activation boxes
  // Actors have labels, activation boxes don't
  let actors : Array[Object] = []
  for obj in graph.objects {
    // Skip activation box objects (no label, internal ID pattern)
    if obj.label.length() > 0 && not(obj.id.contains("__activation_")) {
      actors.push(obj)
    }
  }
  if actors.length() == 0 {
    return ""
  }
  // Sort actors by x-coordinate
  let sorted_actors : Array[Object] = []
  for actor in actors {
    sorted_actors.push(actor)
  }
  sort_objects_by_x(sorted_actors)
  // Separate edges into lifelines and messages
  // Lifelines have dashed stroke, messages don't
  let messages : Array[Edge] = []
  for edge in graph.edges {
    // Skip lifeline edges (dashed stroke)
    if edge.style.stroke_dash is None || edge.style.stroke_dash == Some(0.0) {
      messages.push(edge)
    }
    // Lifelines will be rendered automatically via the edge routes
  }
  // Build actor position info - map actor ID to (ascii_x, center_x, width)
  let actor_positions : Map[String, (Int, Int, Int)] = {}
  let mut current_x = 1
  let mut max_label_len = 0
  for actor in sorted_actors {
    let label = actor.label
    if label.length() > max_label_len {
      max_label_len = label.length()
    }
  }
  // Find max message label length to determine spacing
  let mut max_msg_len = 0
  for edge in messages {
    if edge.label.length() > max_msg_len {
      max_msg_len = edge.label.length()
    }
  }
  // Calculate box width (at least label + padding + borders)
  let box_width = max_i(config.min_box_width, max_label_len + 4)
  // Calculate spacing based on longest message label (need space for label + arrows)
  let min_spacing = max_i(config.h_spacing, max_msg_len + 6)
  for actor in sorted_actors {
    let center_x = current_x + box_width / 2
    actor_positions[actor.id] = (current_x, center_x, box_width)
    current_x = current_x + box_width + min_spacing
  }
  // Calculate message y-positions based on route points
  // Each message gets a unique y-level
  let message_start_y = config.box_height + 1
  let mut max_message_y = message_start_y
  let message_y_positions : Array[(Int, Edge)] = [] // (y, edge)
  for edge in messages {
    // Get y from route points if available, otherwise use sequential
    let y = if edge.route.length() >= 2 {
      // Scale from layout coordinates to ASCII coordinates
      let route_y = edge.route[0].y
      // Approximate scaling: assume layout y starts around 100, each message adds ~40
      let scaled_y = message_start_y + ((route_y - 100.0) / 40.0 * 2.0).to_int()
      if scaled_y > message_start_y {
        scaled_y
      } else {
        message_start_y
      }
    } else {
      message_start_y + message_y_positions.length() * 2
    }
    message_y_positions.push((y, edge))
    if y > max_message_y {
      max_message_y = y
    }
  }
  // Calculate canvas size
  let canvas_width = current_x + 2
  let lifeline_end_y = max_message_y + 3
  let canvas_height = lifeline_end_y + 2
  let grid = @ascii.Grid::new(canvas_width, canvas_height)
  // Render actor boxes at top
  for actor in sorted_actors {
    match actor_positions.get(actor.id) {
      Some((x, _, width)) => {
        let y1 = 1
        let y2 = config.box_height
        let x2 = x + width - 1
        grid.box_rect(x, y1, x2, y2, cs)
        // Center label in box
        let label_x = x + (width - actor.label.length()) / 2
        let label_y = y1 + 1
        grid.text(label_x, label_y, actor.label)
      }
      None => ()
    }
  }
  // Render lifelines (from edges with dashed stroke)
  for edge in graph.edges {
    // Lifelines have dashed stroke
    if edge.style.stroke_dash is Some(d) && d > 0.0 && edge.route.length() >= 2 {
      // This is a lifeline edge - render as vertical line
      // Get x from the route (lifelines are vertical)
      let route_x = edge.route[0].x
      // Find which actor this lifeline belongs to
      for actor in sorted_actors {
        match (actor.box, actor_positions.get(actor.id)) {
          (Some(actor_box), Some((_, center_x, _))) => {
            let actor_center = actor_box.x + actor_box.width / 2.0
            // Check if this lifeline belongs to this actor (within tolerance)
            if (route_x - actor_center).abs() < 10.0 {
              let lifeline_start = config.box_height + 1
              grid.vline(
                center_x,
                lifeline_start,
                lifeline_end_y,
                cs.vertical(),
              )
              break
            }
          }
          _ => ()
        }
      }
    }
  }
  // Render messages in three passes: lines, labels, arrows
  // Pass 1: Draw horizontal lines
  for pair in message_y_positions {
    let (msg_y, edge) = pair
    let src_id = edge.get_src_id()
    let dst_id = edge.get_dst_id()
    let src_pos = find_actor_position(actor_positions, src_id)
    let dst_pos = find_actor_position(actor_positions, dst_id)
    match (src_pos, dst_pos) {
      (Some((_, src_center, _)), Some((_, dst_center, _))) =>
        if src_center == dst_center {
          // Self-message: draw a loop
          let loop_right = src_center + 4
          grid.hline(src_center, loop_right, msg_y, cs.horizontal())
          grid.set(loop_right, msg_y, cs.top_right())
          grid.vline(loop_right, msg_y + 1, msg_y + 1, cs.vertical())
          grid.set(loop_right, msg_y + 2, cs.bottom_right())
          grid.hline(src_center + 1, loop_right - 1, msg_y + 2, cs.horizontal())
        } else if dst_center > src_center {
          // Left to right line
          grid.hline(src_center + 1, dst_center - 1, msg_y, cs.horizontal())
        } else {
          // Right to left line
          grid.hline(dst_center + 1, src_center - 1, msg_y, cs.horizontal())
        }
      _ => ()
    }
  }
  // Pass 2: Draw labels (will overwrite line segments, but not arrow positions)
  for pair in message_y_positions {
    let (msg_y, edge) = pair
    if edge.label.length() == 0 {
      continue
    }
    let src_id = edge.get_src_id()
    let dst_id = edge.get_dst_id()
    let src_pos = find_actor_position(actor_positions, src_id)
    let dst_pos = find_actor_position(actor_positions, dst_id)
    match (src_pos, dst_pos) {
      (Some((_, src_center, _)), Some((_, dst_center, _))) => {
        // Calculate safe label bounds (leave space for arrows)
        let (left, right) = if src_center < dst_center {
          (src_center + 2, dst_center - 2)
        } else {
          (dst_center + 2, src_center - 2)
        }
        let available_width = right - left
        let label = edge.label
        let label_len = label.length()
        // Center the label within the safe bounds
        if label_len <= available_width {
          let label_start = left + (available_width - label_len) / 2
          grid.text(label_start, msg_y, label)
        } else {
          // Label is too long, truncate it
          let truncated = truncate_string(label, available_width)
          let label_start = left
          grid.text(label_start, msg_y, truncated)
        }
      }
      _ => ()
    }
  }
  // Pass 3: Draw arrows (on top of labels)
  for pair in message_y_positions {
    let (msg_y, edge) = pair
    let src_id = edge.get_src_id()
    let dst_id = edge.get_dst_id()
    let src_pos = find_actor_position(actor_positions, src_id)
    let dst_pos = find_actor_position(actor_positions, dst_id)
    match (src_pos, dst_pos) {
      (Some((_, src_center, _)), Some((_, dst_center, _))) =>
        if src_center == dst_center {
          // Self-message arrow
          if edge.dst_arrow {
            grid.set(src_center, msg_y + 2, cs.arrow_left())
          }
        } else if dst_center > src_center {
          // Left to right arrows
          if edge.dst_arrow {
            grid.set(dst_center, msg_y, cs.arrow_right())
          }
          if edge.src_arrow {
            grid.set(src_center, msg_y, cs.arrow_left())
          }
        } else {
          // Right to left arrows
          if edge.dst_arrow {
            grid.set(dst_center, msg_y, cs.arrow_left())
          }
          if edge.src_arrow {
            grid.set(src_center, msg_y, cs.arrow_right())
          }
        }
      _ => ()
    }
  }
  grid.to_string()
}

///|
/// Find actor position by ID, handling nested IDs (e.g., "seq.alice" -> "alice")
fn find_actor_position(
  positions : Map[String, (Int, Int, Int)],
  id : String,
) -> (Int, Int, Int)? {
  // Direct match
  match positions.get(id) {
    Some(pos) => return Some(pos)
    None => ()
  }
  // Try suffix match (for nested IDs)
  let suffix = get_short_id(id)
  positions.get(suffix)
}

///|
/// Compute ASCII layout positions for all objects
/// Uses the y-coordinates from the layout phase for ordering
fn compute_ascii_layout(graph : Graph, config : AsciiConfig) -> Array[AsciiBox] {
  // Track which object IDs are children (nested inside containers)
  let child_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    for child in obj.children {
      child_ids[child.id] = true
    }
  }
  // Find root objects (not children of any container)
  let roots : Array[Object] = []
  for obj in graph.objects {
    if not(child_ids.contains(obj.id)) {
      roots.push(obj)
    }
  }
  // Sort roots by their y-coordinate from the layout phase (top to bottom)
  // This respects the order computed by the Sugiyama algorithm
  sort_objects_by_y(roots)
  // First pass: compute sizes for all objects (bottom-up)
  let sizes : Map[String, (Int, Int)] = {} // id -> (width, height)
  for obj in graph.objects {
    compute_object_size(obj, config, sizes) |> ignore
  }
  // Group objects by layer (same y-coordinate = same layer)
  let layers = group_by_layer(roots)
  // Compute total width needed for each layer (sum of widths + spacing)
  let mut max_layer_width = config.min_width
  for layer in layers {
    let mut layer_width = 0
    for obj in layer {
      match sizes.get(obj.id) {
        Some((w, _)) => layer_width = layer_width + w + config.h_spacing
        None => ()
      }
    }
    if layer_width > 0 {
      layer_width = layer_width - config.h_spacing // Remove last spacing
    }
    max_layer_width = max_i(max_layer_width, layer_width)
  }
  // Second pass: position objects by layer
  let boxes : Array[AsciiBox] = []
  let placed : Map[String, AsciiBox] = {}
  let mut current_y = 1
  for layer in layers {
    // Sort objects within layer by x-coordinate
    sort_objects_by_x(layer)
    // Compute layer width and height
    let mut layer_width = 0
    let mut max_height = 0
    for obj in layer {
      match sizes.get(obj.id) {
        Some((w, h)) => {
          layer_width = layer_width + w + config.h_spacing
          max_height = max_i(max_height, h)
        }
        None => ()
      }
    }
    if layer_width > 0 {
      layer_width = layer_width - config.h_spacing
    }
    // Center the layer horizontally
    let start_x = (max_layer_width - layer_width) / 2
    let mut x = start_x
    for obj in layer {
      match sizes.get(obj.id) {
        Some((w, h)) => {
          let box = create_positioned_box(
            obj, x, current_y, w, h, config, sizes,
          )
          boxes.push(box)
          placed[obj.id] = box
          register_children(box, placed)
          x = x + w + config.h_spacing
        }
        None => ()
      }
    }
    current_y = current_y + max_height + config.v_spacing
  }
  // Flatten all boxes including children for rendering
  flatten_boxes(boxes)
}

///|
/// Compute the size of an object (recursively for containers)
fn compute_object_size(
  obj : Object,
  config : AsciiConfig,
  sizes : Map[String, (Int, Int)],
) -> (Int, Int) {
  // Check if already computed
  match sizes.get(obj.id) {
    Some(size) => return size
    None => ()
  }
  // Special handling for sql_table: size based on header + column rows
  if obj.shape_type == SqlTable {
    let header_height = 3 // top border + label + separator
    let num_columns = obj.children.length()
    let footer_height = 1 // bottom border
    let total_height = header_height + num_columns + footer_height
    // Width = max of label width and column widths
    let mut max_width = obj.label.length() + config.h_padding * 2 + 2
    for child in obj.children {
      // Column format: "name: type"
      let col_name = get_short_id(child.id)
      let col_label = if child.label.length() > 0 {
        col_name + ": " + child.label
      } else {
        col_name
      }
      let col_width = col_label.length() + config.h_padding * 2 + 2
      max_width = max_i(max_width, col_width)
    }
    max_width = max_i(max_width, config.min_box_width)
    sizes[obj.id] = (max_width, total_height)
    return (max_width, total_height)
  }
  if obj.is_container() {
    // Container: stack children vertically
    let title_height = 2 // Title row + gap
    let padding = 2
    let mut children_height = 0
    let mut max_child_width = 0
    for child in obj.children {
      let (cw, ch) = compute_object_size(child, config, sizes)
      max_child_width = max_i(max_child_width, cw)
      children_height = children_height + ch + 1 // +1 for spacing between children
    }
    if obj.children.length() > 0 {
      children_height = children_height - 1 // Remove last spacing
    }
    let content_width = max_i(
      max_child_width + padding * 2,
      obj.label.length() + config.h_padding * 2 + 2,
    )
    let content_height = title_height + children_height + padding
    sizes[obj.id] = (content_width, content_height)
    (content_width, content_height)
  } else {
    // Regular object
    let width = max_i(
      config.min_box_width,
      obj.label.length() + config.h_padding * 2 + 2,
    )
    let height = config.box_height
    sizes[obj.id] = (width, height)
    (width, height)
  }
}

///|
/// Create a positioned box with pre-computed size
fn create_positioned_box(
  obj : Object,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  config : AsciiConfig,
  sizes : Map[String, (Int, Int)],
) -> AsciiBox {
  // Special handling for sql_table: store column info but not as nested boxes
  if obj.shape_type == SqlTable {
    let columns : Array[AsciiBox] = []
    for child in obj.children {
      // Column format: "name: type"
      let col_name = get_short_id(child.id)
      let col_label = if child.label.length() > 0 {
        col_name + ": " + child.label
      } else {
        col_name
      }
      // Store column as a pseudo-box (just for label storage)
      columns.push({
        id: child.id,
        x: 0,
        y: 0,
        width: 0,
        height: 0,
        label: col_label,
        shape: "sql_column",
        is_container: false,
        children: [],
      })
    }
    return {
      id: obj.id,
      x,
      y,
      width,
      height,
      label: obj.label,
      shape: "sql_table",
      is_container: false, // Don't treat as container for rendering
      children: columns,
    }
  }
  if obj.is_container() {
    // Container with vertically stacked, centered children
    let children : Array[AsciiBox] = []
    let title_height = 2
    let mut child_y = y + title_height
    for child in obj.children {
      match sizes.get(child.id) {
        Some((cw, ch)) => {
          // Center child horizontally within container
          let child_x = x + (width - cw) / 2
          let child_box = create_positioned_box(
            child, child_x, child_y, cw, ch, config, sizes,
          )
          children.push(child_box)
          child_y = child_y + ch + 1
        }
        None => ()
      }
    }
    {
      id: obj.id,
      x,
      y,
      width,
      height,
      label: obj.label,
      shape: "container",
      is_container: true,
      children,
    }
  } else {
    {
      id: obj.id,
      x,
      y,
      width,
      height,
      label: obj.label,
      shape: obj.get_shape(),
      is_container: false,
      children: [],
    }
  }
}

///|
/// Register container children in the placed map
fn register_children(box : AsciiBox, placed : Map[String, AsciiBox]) -> Unit {
  for child in box.children {
    placed[child.id] = child
    register_children(child, placed)
  }
}

///|
/// Flatten nested boxes into a single array for rendering
fn flatten_boxes(boxes : Array[AsciiBox]) -> Array[AsciiBox] {
  let result : Array[AsciiBox] = []
  for box in boxes {
    result.push(box)
    for child in box.children {
      flatten_children(child, result)
    }
  }
  result
}

///|
fn flatten_children(box : AsciiBox, result : Array[AsciiBox]) -> Unit {
  // Skip sql_column boxes - they're rendered inline within sql_table
  if box.shape == "sql_column" {
    return
  }
  result.push(box)
  for child in box.children {
    flatten_children(child, result)
  }
}

///|
fn compute_canvas_size(
  boxes : Array[AsciiBox],
  config : AsciiConfig,
) -> (Int, Int) {
  let mut max_x = config.min_width
  let mut max_y = config.min_height
  for box in boxes {
    let right = box.x + box.width + 2
    let bottom = box.y + box.height + 2
    if right > max_x {
      max_x = right
    }
    if bottom > max_y {
      max_y = bottom
    }
  }
  (max_x, max_y)
}

///|
fn max_i(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Sort objects by their y-coordinate (layout position)
fn sort_objects_by_y(objects : Array[Object]) -> Unit {
  // Insertion sort by y-coordinate
  let n = objects.length()
  for i = 1; i < n; i = i + 1 {
    let key = objects[i]
    let key_y = match key.box {
      Some(b) => b.y
      None => 0.0
    }
    let mut j = i - 1
    while j >= 0 {
      let j_y = match objects[j].box {
        Some(b) => b.y
        None => 0.0
      }
      if j_y > key_y {
        objects[j + 1] = objects[j]
        j = j - 1
      } else {
        break
      }
    }
    objects[j + 1] = key
  }
}

///|
/// Sort objects by their x-coordinate (layout position)
fn sort_objects_by_x(objects : Array[Object]) -> Unit {
  let n = objects.length()
  for i = 1; i < n; i = i + 1 {
    let key = objects[i]
    let key_x = match key.box {
      Some(b) => b.x
      None => 0.0
    }
    let mut j = i - 1
    while j >= 0 {
      let j_x = match objects[j].box {
        Some(b) => b.x
        None => 0.0
      }
      if j_x > key_x {
        objects[j + 1] = objects[j]
        j = j - 1
      } else {
        break
      }
    }
    objects[j + 1] = key
  }
}

///|
/// Group objects by their y-coordinate (layer)
/// Objects are already sorted by y, so consecutive objects with same y are in same layer
fn group_by_layer(objects : Array[Object]) -> Array[Array[Object]] {
  let layers : Array[Array[Object]] = []
  if objects.length() == 0 {
    return layers
  }
  let mut current_layer : Array[Object] = []
  let mut current_y = match objects[0].box {
    Some(b) => b.y
    None => 0.0
  }
  for obj in objects {
    let obj_y = match obj.box {
      Some(b) => b.y
      None => 0.0
    }
    // Use a small epsilon for floating point comparison
    if (obj_y - current_y).abs() < 1.0 {
      current_layer.push(obj)
    } else {
      if current_layer.length() > 0 {
        layers.push(current_layer)
      }
      current_layer = [obj]
      current_y = obj_y
    }
  }
  if current_layer.length() > 0 {
    layers.push(current_layer)
  }
  layers
}

///|
/// Render a single ASCII box
fn render_ascii_box(
  grid : @ascii.Grid,
  box : AsciiBox,
  config : AsciiConfig,
) -> Unit {
  let x1 = box.x
  let y1 = box.y
  let x2 = box.x + box.width - 1
  let y2 = box.y + box.height - 1
  let cs = config.charset
  // Draw box shape
  match box.shape {
    "text" => {
      // Text shape - just the label, no border
      let label_x = x1 + (box.width - box.label.length()) / 2
      let label_y = y1 + box.height / 2
      grid.text(label_x, label_y, box.label)
      return
    }
    "image" => {
      // Image shape - show [IMG] placeholder
      grid.box_rect(x1, y1, x2, y2, cs)
      let img_text = "[IMG]"
      let label_x = x1 + (box.width - img_text.length()) / 2
      let label_y = y1 + box.height / 2
      grid.text(label_x, label_y, img_text)
      return
    }
    "code" => {
      // Code shape - box with ``` markers
      grid.set(x1, y1, cs.top_left())
      grid.set(x1 + 1, y1, '`')
      grid.set(x1 + 2, y1, '`')
      grid.set(x1 + 3, y1, '`')
      grid.hline(x1 + 4, x2 - 1, y1, cs.horizontal())
      grid.set(x2, y1, cs.top_right())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      grid.set(x1, y2, cs.bottom_left())
      grid.hline(x1 + 1, x2 - 4, y2, cs.horizontal())
      grid.set(x2 - 3, y2, '`')
      grid.set(x2 - 2, y2, '`')
      grid.set(x2 - 1, y2, '`')
      grid.set(x2, y2, cs.bottom_right())
    }
    "sql_table" => {
      // SQL table: header + separator + column rows
      // Top border
      grid.set(x1, y1, cs.top_left())
      grid.hline(x1 + 1, x2 - 1, y1, cs.horizontal())
      grid.set(x2, y1, cs.top_right())
      // Sides
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      // Header row (label is drawn below by common code, but we draw separator)
      // Separator line after table name (at y1 + 2)
      if y1 + 2 < y2 {
        grid.set(x1, y1 + 2, cs.t_right())
        grid.hline(x1 + 1, x2 - 1, y1 + 2, cs.horizontal())
        grid.set(x2, y1 + 2, cs.t_left())
      }
      // Column rows: starting at y1 + 3
      let mut row_y = y1 + 3
      for col in box.children {
        if row_y < y2 {
          // Draw column label left-aligned with padding
          let col_x = x1 + 1
          grid.text(col_x, row_y, col.label)
          row_y = row_y + 1
        }
      }
      // Bottom border
      grid.set(x1, y2, cs.bottom_left())
      grid.hline(x1 + 1, x2 - 1, y2, cs.horizontal())
      grid.set(x2, y2, cs.bottom_right())
    }
    "sql_column" =>
      // sql_column is rendered inline within sql_table, skip standalone rendering
      return
    "class" => {
      // UML class shape - box with separator line
      grid.set(x1, y1, cs.top_left())
      grid.hline(x1 + 1, x2 - 1, y1, cs.horizontal())
      grid.set(x2, y1, cs.top_right())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      // Separator line after class name
      if y1 + 2 < y2 {
        grid.set(x1, y1 + 2, cs.t_right())
        grid.hline(x1 + 1, x2 - 1, y1 + 2, cs.horizontal())
        grid.set(x2, y1 + 2, cs.t_left())
      }
      grid.set(x1, y2, cs.bottom_left())
      grid.hline(x1 + 1, x2 - 1, y2, cs.horizontal())
      grid.set(x2, y2, cs.bottom_right())
    }
    "circle" | "oval" => grid.rounded_rect(x1, y1, x2, y2, cs)
    "cylinder" => {
      // Draw cylinder according to D2 implementation
      // Top row: .--‾‾--.
      grid.set(x1 + 1, y1, cs.dot())
      grid.set(x2 - 1, y1, cs.dot())
      grid.set(x1 + 2, y1, cs.hyphen())
      grid.set(x2 - 2, y1, cs.hyphen())
      for ix = x1 + 3; ix < x2 - 2; ix = ix + 1 {
        grid.set(ix, y1, cs.overline())
      }
      // Second row (y1+1) and bottom row (y2): \--__--/
      for iy in [y1 + 1, y2] {
        grid.set(x1 + 1, iy, cs.diagonal_down())
        grid.set(x2 - 1, iy, cs.diagonal_up())
        grid.set(x1 + 2, iy, cs.hyphen())
        grid.set(x2 - 2, iy, cs.hyphen())
        for ix = x1 + 3; ix < x2 - 2; ix = ix + 1 {
          grid.set(ix, iy, cs.underscore())
        }
      }
      // Sides: vertical lines
      for iy = y1 + 1; iy < y2; iy = iy + 1 {
        grid.set(x1, iy, cs.vertical())
        grid.set(x2, iy, cs.vertical())
      }
    }
    "diamond" => {
      let cx = (x1 + x2) / 2
      for x in x1..=x2 {
        for y in y1..=y2 {
          grid.set(x, y, '*')
        }
      }
      grid.set(cx, y1, '*')
      grid.set(cx, y2, '*')
    }
    "cloud" => {
      grid.set(x1, y1, cs.top_left())
      grid.set(x1 + 1, y1, '~')
      grid.hline(x1 + 2, x2 - 1, y1, cs.horizontal())
      grid.set(x2, y1, cs.top_right())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      grid.set(x1, y2, cs.bottom_left())
      grid.hline(x1 + 1, x2 - 1, y2, cs.horizontal())
      grid.set(x2, y2, cs.bottom_right())
    }
    "person" => {
      // Stick figure
      let cx = (x1 + x2) / 2
      // Head (top)
      grid.set(cx - 1, y1, cs.diagonal_up())
      grid.set(cx, y1, cs.horizontal())
      grid.set(cx + 1, y1, cs.diagonal_down())
      grid.set(cx - 1, y1 + 1, cs.diagonal_down())
      grid.set(cx, y1 + 1, '_')
      grid.set(cx + 1, y1 + 1, cs.diagonal_up())
      // Body (bottom)
      if y2 > y1 + 2 {
        grid.set(cx - 2, y1 + 2, cs.diagonal_up())
        grid.hline(cx - 1, cx + 1, y1 + 2, cs.horizontal())
        grid.set(cx + 2, y1 + 2, cs.diagonal_down())
        grid.hline(cx - 2, cx + 2, y2, cs.horizontal())
      }
    }
    "c4_person" => {
      // C4 person: simplified person icon with label
      let cx = (x1 + x2) / 2
      // Head
      grid.set(cx - 1, y1, cs.diagonal_up())
      grid.set(cx, y1, cs.horizontal())
      grid.set(cx + 1, y1, cs.diagonal_down())
      grid.set(cx - 1, y1 + 1, cs.diagonal_down())
      grid.set(cx, y1 + 1, '_')
      grid.set(cx + 1, y1 + 1, cs.diagonal_up())
      // Body (rounded box)
      if y2 > y1 + 3 {
        grid.set(x1 + 1, y1 + 2, cs.top_left())
        grid.hline(x1 + 2, x2 - 2, y1 + 2, cs.horizontal())
        grid.set(x2 - 1, y1 + 2, cs.top_right())
        grid.vline(x1 + 1, y1 + 3, y2 - 1, cs.vertical())
        grid.vline(x2 - 1, y1 + 3, y2 - 1, cs.vertical())
        grid.set(x1 + 1, y2, cs.bottom_left())
        grid.hline(x1 + 2, x2 - 2, y2, cs.horizontal())
        grid.set(x2 - 1, y2, cs.bottom_right())
      }
    }
    "c4_container" => grid.rounded_rect(x1, y1, x2, y2, cs)
    "hexagon" => {
      // Hexagon:  /-----\
      //          \_____/
      grid.set(x1, y1, cs.diagonal_up())
      grid.hline(x1 + 1, x2 - 1, y1, cs.horizontal())
      grid.set(x2, y1, cs.diagonal_down())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      grid.set(x1, y2, cs.diagonal_down())
      grid.hline(x1 + 1, x2 - 1, y2, '_')
      grid.set(x2, y2, cs.diagonal_up())
    }
    "parallelogram" => {
      // Parallelogram: /-----/
      grid.set(x1, y1, cs.diagonal_up())
      grid.hline(x1 + 1, x2 - 1, y1, cs.horizontal())
      grid.set(x2, y1, cs.diagonal_up())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      grid.set(x1, y2, cs.diagonal_up())
      grid.hline(x1 + 1, x2 - 1, y2, '_')
      grid.set(x2, y2, cs.diagonal_up())
    }
    "document" => {
      // Document: box with wavy bottom
      grid.set(x1, y1, cs.top_left())
      grid.hline(x1 + 1, x2 - 1, y1, cs.horizontal())
      grid.set(x2, y1, cs.top_right())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      // Wavy bottom
      grid.set(x1, y2, '`')
      grid.set(x1 + 1, y2, cs.horizontal())
      grid.set(x1 + 2, y2, '.')
      grid.set(x1 + 3, y2, cs.horizontal())
      grid.set(x1 + 4, y2, '`')
    }
    "page" => {
      // Page: box with folded corner
      grid.set(x1, y1, cs.top_left())
      grid.hline(x1 + 1, x2 - 2, y1, cs.horizontal())
      grid.set(x2 - 1, y1, cs.diagonal_down())
      grid.set(x2, y1, cs.top_right())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      grid.set(x1, y2, cs.bottom_left())
      grid.hline(x1 + 1, x2 - 1, y2, cs.horizontal())
      grid.set(x2, y2, cs.bottom_right())
    }
    "package" => {
      // Package: box with top fold
      grid.set(x1, y1, cs.top_left())
      grid.hline(x1 + 1, x2 - 2, y1, cs.horizontal())
      grid.set(x2 - 1, y1, cs.top_right())
      grid.set(x2, y1, cs.horizontal())
      grid.set(x2 + 1, y1, cs.top_right())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      grid.set(x1, y2, cs.bottom_left())
      grid.hline(x1 + 1, x2 - 1, y2, cs.horizontal())
      grid.set(x2, y2, cs.bottom_right())
    }
    "queue" => {
      // Queue: box with right side extending
      grid.set(x1, y1, cs.diagonal_up())
      grid.hline(x1 + 1, x2 - 1, y1, cs.horizontal())
      grid.set(x2, y1, cs.diagonal_up())
      grid.set(x2 + 1, y1, cs.diagonal_down())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      grid.set(x1, y2, cs.diagonal_down())
      grid.hline(x1 + 1, x2 - 1, y2, '_')
      grid.set(x2, y2, cs.diagonal_down())
      grid.set(x2 + 1, y2, cs.diagonal_up())
    }
    "step" => {
      // Step: parallelogram pointing right
      grid.set(x1, y1, cs.diagonal_down())
      grid.hline(x1 + 1, x2 - 1, y1, cs.horizontal())
      grid.set(x2, y1, cs.diagonal_down())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      grid.set(x1, y2, cs.diagonal_up())
      grid.hline(x1 + 1, x2 - 1, y2, '_')
      grid.set(x2, y2, cs.diagonal_up())
    }
    "stored_data" => {
      // Stored data: parallelogram-like cylinder
      grid.set(x1, y1, cs.diagonal_up())
      grid.hline(x1 + 1, x2 - 1, y1, cs.horizontal())
      grid.set(x2, y1, cs.diagonal_up())
      grid.vline(x1, y1 + 1, y2 - 1, cs.vertical())
      grid.vline(x2, y1 + 1, y2 - 1, cs.vertical())
      grid.set(x1, y2, cs.diagonal_down())
      grid.hline(x1 + 1, x2 - 1, y2, '_')
      grid.set(x2, y2, cs.diagonal_down())
    }
    "callout" => {
      // Callout: box with arrow pointing down
      grid.box_rect(x1, y1, x2, y2, cs)
      // Arrow pointing down
      let cx = (x1 + x2) / 2
      grid.set(cx, y2 + 1, cs.vertical())
      grid.set(cx, y2 + 2, cs.arrow_down())
    }
    "container" => {
      // Container: box with title at top, children inside
      grid.box_rect(x1, y1, x2, y2, cs)
      // Draw title centered at top
      let label_x = x1 + (box.width - box.label.length()) / 2
      grid.text(label_x, y1 + 1, box.label)
      // Note: children are rendered separately since they're in the flattened boxes list
      return
    }
    _ => grid.box_rect(x1, y1, x2, y2, cs)
  }
  // Draw label centered (on first content line, which is y1 + 1)
  let label_x = x1 + (box.width - box.label.length()) / 2
  let label_y = y1 + 1
  grid.text(label_x, label_y, box.label)
}

///|
/// Compute horizontal offset for parallel edges between same node pair
/// ref_idx: which reference of this edge (0..reference_count-1)
fn compute_edge_offset(
  graph : Graph,
  edge : Edge,
  ref_idx : Int,
  boxes : Array[AsciiBox],
) -> Int {
  let src_id = edge.get_src_id()
  let dst_id = edge.get_dst_id()
  // Count total parallel lines and find max label length
  let mut total_lines = 0
  let mut line_index = 0
  let mut max_label_len = 0
  for e in graph.edges {
    let e_src = e.get_src_id()
    let e_dst = e.get_dst_id()
    // Check if same node pair (considering both directions)
    if (e_src == src_id && e_dst == dst_id) ||
      (e_src == dst_id && e_dst == src_id) {
      // Track max label length for spacing
      if e.label.length() > max_label_len {
        max_label_len = e.label.length()
      }
      // Is this the current edge?
      if e_src == edge.get_src_id() &&
        e_dst == edge.get_dst_id() &&
        e.label == edge.label &&
        e.src_arrow == edge.src_arrow &&
        e.dst_arrow == edge.dst_arrow {
        line_index = total_lines + ref_idx
      }
      total_lines = total_lines + e.reference_count
    }
  }
  if total_lines <= 1 {
    return 0
  }
  // Calculate spacing: at least 2 chars, or label width + 2 for gaps
  let mut spacing = max_i(2, max_label_len + 2)
  // Constrain spacing to fit within the narrower box
  let src_box = find_ascii_box(boxes, src_id)
  let dst_box = find_ascii_box(boxes, dst_id)
  match (src_box, dst_box) {
    (Some(src), Some(dst)) => {
      let min_width = if src.width < dst.width { src.width } else { dst.width }
      // Max total spread should fit within box (with 2 char margin on each side)
      let max_spread = min_width - 4
      let needed_spread = (total_lines - 1) * spacing
      if needed_spread > max_spread && total_lines > 1 {
        spacing = max_spread / (total_lines - 1)
        if spacing < 1 {
          spacing = 1
        }
      }
    }
    _ => ()
  }
  let total_width = (total_lines - 1) * spacing
  let start_offset = -(total_width / 2)
  start_offset + line_index * spacing
}

///|
/// Compute horizontal offset for edges from different sources to same destination
/// This ensures multiple incoming edges don't overlap at the destination
fn compute_destination_offset(
  graph : Graph,
  edge : Edge,
  boxes : Array[AsciiBox],
) -> Int {
  let dst_id = edge.get_dst_id()
  // Count edges going to the same destination from different sources
  let mut total_incoming = 0
  let mut edge_index = 0
  for e in graph.edges {
    if e.get_dst_id() == dst_id {
      if e.get_src_id() == edge.get_src_id() &&
        e.get_dst_id() == edge.get_dst_id() {
        edge_index = total_incoming
      }
      total_incoming = total_incoming + 1
    }
  }
  if total_incoming <= 1 {
    return 0
  }
  // Use spacing of 4 characters between incoming edges
  let spacing = 4
  let dst_box = find_ascii_box(boxes, dst_id)
  match dst_box {
    Some(dst) => {
      // Constrain to destination box width
      let max_spread = dst.width - 4
      let needed_spread = (total_incoming - 1) * spacing
      let actual_spacing = if needed_spread > max_spread && total_incoming > 1 {
        max_i(1, max_spread / (total_incoming - 1))
      } else {
        spacing
      }
      let total_width = (total_incoming - 1) * actual_spacing
      let start_offset = -(total_width / 2)
      start_offset + edge_index * actual_spacing
    }
    None => 0
  }
}

///|
/// Find ASCII box by object ID
fn find_ascii_box(boxes : Array[AsciiBox], id : String) -> AsciiBox? {
  for box in boxes {
    // Match by ID (handles nested IDs like "container.child")
    if box.id == id || box.id.has_suffix("." + id) {
      return Some(box)
    }
  }
  // Fallback: try matching by label
  for box in boxes {
    if box.label == id {
      return Some(box)
    }
  }
  None
}

///|
/// Render edge lines with L-shaped routing when needed
fn render_ascii_edge_new(
  grid : @ascii.Grid,
  graph : Graph,
  edge : Edge,
  ref_idx : Int,
  boxes : Array[AsciiBox],
  config : AsciiConfig,
) -> Unit {
  let src_id = edge.get_src_id()
  let dst_id = edge.get_dst_id()
  let src_box = find_ascii_box(boxes, src_id)
  let dst_box = find_ascii_box(boxes, dst_id)
  let offset = compute_edge_offset(graph, edge, ref_idx, boxes)
  let cs = config.charset
  match (src_box, dst_box) {
    (Some(src), Some(dst)) =>
      if dst.y > src.y + src.height {
        // Destination is below source - draw downward
        let src_center_x = src.x + src.width / 2
        let dst_center_x = dst.x + dst.width / 2
        let src_bottom = src.y + src.height
        let dst_top = dst.y - 1
        // Check if source and destination are roughly aligned (within box overlap)
        let src_left = src.x
        let src_right = src.x + src.width
        let dst_left = dst.x
        let dst_right = dst.x + dst.width
        let overlaps = src_right > dst_left && dst_right > src_left
        if overlaps {
          // Boxes overlap horizontally - use straight vertical line
          // Apply destination offset for multiple incoming edges
          let dst_offset = compute_destination_offset(graph, edge, boxes)
          let line_x = dst_center_x + offset + dst_offset
          grid.vline(line_x, src_bottom, dst_top, cs.vertical())
        } else {
          // L-shaped routing needed
          let line_x = src_center_x + offset
          // Draw vertical line from source
          let mid_y = (src_bottom + dst_top) / 2
          grid.vline(line_x, src_bottom, mid_y, cs.vertical())
          // Draw corner
          if dst_center_x > line_x {
            grid.set(line_x, mid_y, cs.bottom_left())
            // Draw horizontal line
            grid.hline(line_x + 1, dst_center_x - 1, mid_y, cs.horizontal())
            grid.set(dst_center_x, mid_y, cs.top_right())
          } else {
            grid.set(line_x, mid_y, cs.bottom_right())
            // Draw horizontal line
            grid.hline(dst_center_x + 1, line_x - 1, mid_y, cs.horizontal())
            grid.set(dst_center_x, mid_y, cs.top_left())
          }
          // Draw vertical line to destination
          grid.vline(dst_center_x, mid_y + 1, dst_top, cs.vertical())
        }
      } else if src.y > dst.y + dst.height {
        // Destination is above source - draw upward
        let src_center_x = src.x + src.width / 2
        let dst_center_x = dst.x + dst.width / 2
        let src_top = src.y - 1
        let dst_bottom = dst.y + dst.height
        // Check horizontal overlap
        let src_left = src.x
        let src_right = src.x + src.width
        let dst_left = dst.x
        let dst_right = dst.x + dst.width
        let overlaps = src_right > dst_left && dst_right > src_left
        if overlaps {
          // Straight vertical line upward
          let line_x = dst_center_x + offset
          grid.vline(line_x, dst_bottom, src_top, cs.vertical())
        } else {
          // L-shaped routing upward
          let line_x = src_center_x + offset
          let mid_y = (dst_bottom + src_top) / 2
          grid.vline(line_x, mid_y, src_top, cs.vertical())
          if dst_center_x > line_x {
            grid.set(line_x, mid_y, cs.top_left())
            grid.hline(line_x + 1, dst_center_x - 1, mid_y, cs.horizontal())
            grid.set(dst_center_x, mid_y, cs.bottom_right())
          } else {
            grid.set(line_x, mid_y, cs.top_right())
            grid.hline(dst_center_x + 1, line_x - 1, mid_y, cs.horizontal())
            grid.set(dst_center_x, mid_y, cs.bottom_left())
          }
          grid.vline(dst_center_x, dst_bottom, mid_y - 1, cs.vertical())
        }
      } else if dst.x != src.x {
        // Side by side - horizontal connection
        let cy = src.y + src.height / 2
        if src.x < dst.x {
          grid.hline(src.x + src.width, dst.x - 1, cy, cs.horizontal())
        } else {
          grid.hline(dst.x + dst.width, src.x - 1, cy, cs.horizontal())
        }
      }
    _ => ()
  }
}

///|
/// Render edge arrows
fn render_ascii_arrows_new(
  grid : @ascii.Grid,
  graph : Graph,
  edge : Edge,
  ref_idx : Int,
  boxes : Array[AsciiBox],
  config : AsciiConfig,
) -> Unit {
  let src_id = edge.get_src_id()
  let dst_id = edge.get_dst_id()
  let src_box = find_ascii_box(boxes, src_id)
  let dst_box = find_ascii_box(boxes, dst_id)
  let offset = compute_edge_offset(graph, edge, ref_idx, boxes)
  let cs = config.charset
  match (src_box, dst_box) {
    (Some(src), Some(dst)) =>
      if dst.y > src.y + src.height {
        // Destination is below source
        let src_center_x = src.x + src.width / 2
        let dst_center_x = dst.x + dst.width / 2
        let src_bottom = src.y + src.height
        let dst_top = dst.y - 1
        // Check if boxes overlap horizontally
        let src_right = src.x + src.width
        let dst_left = dst.x
        let dst_right = dst.x + dst.width
        let overlaps = src_right > dst_left && dst_right > src.x
        if overlaps {
          // Straight vertical line with destination offset
          let dst_offset = compute_destination_offset(graph, edge, boxes)
          let line_x = dst_center_x + offset + dst_offset
          if edge.dst_arrow {
            grid.set(line_x, dst_top, cs.arrow_down())
          }
          if edge.src_arrow && ref_idx == 0 {
            grid.set(line_x, src_bottom, cs.arrow_up())
          }
        } else {
          // L-shaped routing - arrow at destination center
          if edge.dst_arrow {
            grid.set(dst_center_x, dst_top, cs.arrow_down())
          }
          if edge.src_arrow && ref_idx == 0 {
            let line_x = src_center_x + offset
            grid.set(line_x, src_bottom, cs.arrow_up())
          }
        }
      } else if src.y > dst.y + dst.height {
        // Destination is above source - upward edge
        let src_center_x = src.x + src.width / 2
        let dst_center_x = dst.x + dst.width / 2
        let src_top = src.y - 1
        let dst_bottom = dst.y + dst.height
        let src_right = src.x + src.width
        let dst_left = dst.x
        let dst_right = dst.x + dst.width
        let overlaps = src_right > dst_left && dst_right > src.x
        if overlaps {
          let line_x = dst_center_x + offset
          if edge.dst_arrow {
            // Arrow pointing up at destination (from below)
            grid.set(line_x, dst_bottom, cs.arrow_up())
          }
          if edge.src_arrow && ref_idx == 0 {
            // Arrow pointing down at source (from above)
            grid.set(line_x, src_top, cs.arrow_down())
          }
        } else {
          if edge.dst_arrow {
            // Arrow pointing up at destination
            grid.set(dst_center_x, dst_bottom, cs.arrow_up())
          }
          if edge.src_arrow && ref_idx == 0 {
            // Arrow pointing down at source
            let line_x = src_center_x + offset
            grid.set(line_x, src_top, cs.arrow_down())
          }
        }
      } else if dst.x != src.x {
        // Horizontal edge
        if edge.dst_arrow {
          if dst.x > src.x {
            grid.set(dst.x - 1, dst.y + dst.height / 2, cs.arrow_right())
          } else {
            grid.set(dst.x + dst.width, dst.y + dst.height / 2, cs.arrow_left())
          }
        }
        if edge.src_arrow && ref_idx == 0 {
          if dst.x > src.x {
            grid.set(src.x + src.width, src.y + src.height / 2, cs.arrow_left())
          } else {
            grid.set(src.x - 1, src.y + src.height / 2, cs.arrow_right())
          }
        }
      }
    _ => ()
  }
}

///|
/// Render edge labels
fn render_ascii_label_new(
  grid : @ascii.Grid,
  graph : Graph,
  edge : Edge,
  ref_idx : Int,
  boxes : Array[AsciiBox],
  _config : AsciiConfig,
) -> Unit {
  if edge.label.length() == 0 {
    return
  }
  let src_id = edge.get_src_id()
  let dst_id = edge.get_dst_id()
  let src_box = find_ascii_box(boxes, src_id)
  let dst_box = find_ascii_box(boxes, dst_id)
  let offset = compute_edge_offset(graph, edge, ref_idx, boxes)
  match (src_box, dst_box) {
    (Some(src), Some(dst)) =>
      if dst.y > src.y + src.height {
        // Vertical edge
        let dst_center_x = dst.x + dst.width / 2
        let src_bottom = src.y + src.height
        let dst_top = dst.y - 1
        // Check if boxes overlap horizontally
        let src_right = src.x + src.width
        let dst_left = dst.x
        let dst_right = dst.x + dst.width
        let overlaps = src_right > dst_left && dst_right > src.x
        let line_x = if overlaps {
          // Use destination center with offset
          let dst_offset = compute_destination_offset(graph, edge, boxes)
          dst_center_x + offset + dst_offset
        } else {
          // L-shaped: use source center
          src.x + src.width / 2 + offset
        }
        let mid_y = (src_bottom + dst_top) / 2
        // Position label centered on the line position
        let label_start_x = line_x - edge.label.length() / 2
        grid.text(label_start_x, mid_y, edge.label)
      } else {
        // Horizontal edge
        let cy = src.y + src.height / 2
        let cx = (src.x + src.width + dst.x) / 2
        grid.text(cx - edge.label.length() / 2, cy, edge.label)
      }
    _ => ()
  }
}
