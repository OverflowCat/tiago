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
  // Compute ASCII layout for all objects
  let boxes = compute_ascii_layout(graph, config)
  // Calculate canvas dimensions
  let (canvas_width, canvas_height) = compute_canvas_size(boxes, config)
  let grid = @ascii.Grid::new(canvas_width, canvas_height)
  // Render edge lines first (behind objects)
  for edge in graph.edges {
    for ref_idx = 0; ref_idx < edge.reference_count; ref_idx = ref_idx + 1 {
      render_ascii_edge_new(grid, graph, edge, ref_idx, boxes, config)
    }
  }
  // Render objects
  for box in boxes {
    render_ascii_box(grid, box, config)
  }
  // Re-render container borders on top of edges
  for box in boxes {
    if box.is_container {
      render_container_border(grid, box)
    }
  }
  // Render edge labels (only for first reference which has the label)
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
/// Compute ASCII layout positions for all objects
fn compute_ascii_layout(graph : Graph, config : AsciiConfig) -> Array[AsciiBox] {
  let boxes : Array[AsciiBox] = []
  // Find root objects and their edge targets for layout
  let roots = find_ascii_roots(graph)
  // Build adjacency list for topological ordering
  let adj : Map[String, Array[String]] = {}
  for edge in graph.edges {
    let src = edge.get_src_id()
    let dst = edge.get_dst_id()
    match adj.get(src) {
      Some(arr) => arr.push(dst)
      None => adj[src] = [dst]
    }
  }
  // Track which object IDs are children (nested inside containers)
  let child_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    for child in obj.children {
      child_ids[child.id] = true
    }
  }
  // Layout objects level by level (BFS)
  let placed : Map[String, AsciiBox] = {}
  let mut current_y = 1
  // First pass: place roots - containers get their own rows, non-containers grouped
  let mut current_x = 1
  let mut max_row_height = config.box_height
  for obj in roots {
    // Containers go on their own row for cleaner layout
    if obj.is_container() {
      // If we have pending non-containers, finish that row first
      if current_x > 1 {
        current_y = current_y + max_row_height + config.v_spacing
        current_x = 1
        max_row_height = config.box_height
      }
      let box = create_container_box(obj, current_x, current_y, config)
      boxes.push(box)
      placed[obj.id] = box
      register_children(box, placed)
      current_y = current_y + box.height + config.v_spacing
    } else {
      let box = create_ascii_box(obj, current_x, current_y, config)
      boxes.push(box)
      placed[obj.id] = box
      current_x = current_x + box.width + config.h_spacing
      max_row_height = max_i(max_row_height, box.height)
    }
  }
  // Finish any pending row
  if current_x > 1 {
    current_y = current_y + max_row_height + config.v_spacing
  }
  // BFS for remaining levels
  let mut frontier : Array[String] = []
  for obj in roots {
    frontier.push(obj.id)
  }
  let visited : Map[String, Bool] = {}
  for obj in roots {
    visited[obj.id] = true
  }
  while frontier.length() > 0 {
    let next_frontier : Array[String] = []
    let level_objs : Array[Object] = []
    for src_id in frontier {
      match adj.get(src_id) {
        Some(targets) =>
          for dst_id in targets {
            if not(visited.contains(dst_id)) {
              visited[dst_id] = true
              match graph.find_object(dst_id) {
                Some(obj) => {
                  // Skip if this is a child of a container (already placed)
                  if not(child_ids.contains(obj.id)) {
                    level_objs.push(obj)
                  }
                  next_frontier.push(dst_id)
                }
                None => ()
              }
            }
          }
        None => ()
      }
    }
    // Place objects in this level
    if level_objs.length() > 0 {
      // Center this level under its parents
      let level_width = compute_level_width_with_containers(level_objs, config)
      let parent_center = compute_parent_center(frontier, placed)
      let start_x = max_i(1, parent_center - level_width / 2)
      let mut x = start_x
      for obj in level_objs {
        let box = if obj.is_container() {
          create_container_box(obj, x, current_y, config)
        } else {
          create_ascii_box(obj, x, current_y, config)
        }
        boxes.push(box)
        placed[obj.id] = box
        // Register children
        register_children(box, placed)
        x = x + box.width + config.h_spacing
      }
      // Update y based on max height of this level
      let max_height = level_objs.fold(init=config.box_height, fn(acc, obj) {
        if obj.is_container() {
          max_i(acc, compute_container_height(obj, config))
        } else {
          acc
        }
      })
      current_y = current_y + max_height + config.v_spacing
    }
    frontier = next_frontier
  }
  // Add any unplaced objects (disconnected, non-children)
  for obj in graph.objects {
    if not(placed.contains(obj.id)) && not(child_ids.contains(obj.id)) {
      let box = if obj.is_container() {
        create_container_box(obj, 1, current_y, config)
      } else {
        create_ascii_box(obj, 1, current_y, config)
      }
      boxes.push(box)
      placed[obj.id] = box
      register_children(box, placed)
      current_y = current_y + box.height + config.v_spacing
    }
  }
  // Flatten all boxes including children for rendering
  flatten_boxes(boxes)
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
  result.push(box)
  for child in box.children {
    flatten_children(child, result)
  }
}

///|
/// Compute container height
fn compute_container_height(obj : Object, config : AsciiConfig) -> Int {
  if obj.children.length() == 0 {
    return config.box_height
  }
  let title_height = 2 // Title row + 1 row gap
  let padding = 2
  let max_child_height = obj.children.fold(init=config.box_height, fn(
    acc,
    child,
  ) {
    if child.is_container() {
      max_i(acc, compute_container_height(child, config))
    } else {
      acc
    }
  })
  title_height + max_child_height + padding
}

///|
/// Compute level width accounting for containers
fn compute_level_width_with_containers(
  objs : Array[Object],
  config : AsciiConfig,
) -> Int {
  let mut width = 0
  for obj in objs {
    let box_width = if obj.is_container() {
      compute_container_width(obj, config)
    } else {
      max_i(config.min_box_width, obj.label.length() + config.h_padding * 2 + 2)
    }
    width = width + box_width + config.h_spacing
  }
  if width > 0 {
    width - config.h_spacing
  } else {
    0
  }
}

///|
/// Compute container width
fn compute_container_width(obj : Object, config : AsciiConfig) -> Int {
  if obj.children.length() == 0 {
    return max_i(
      config.min_box_width,
      obj.label.length() + config.h_padding * 2 + 2,
    )
  }
  let padding = 2
  let mut children_width = padding
  for child in obj.children {
    let child_width = if child.is_container() {
      compute_container_width(child, config)
    } else {
      max_i(
        config.min_box_width,
        child.label.length() + config.h_padding * 2 + 2,
      )
    }
    children_width = children_width + child_width + config.h_spacing
  }
  if obj.children.length() > 0 {
    children_width = children_width - config.h_spacing + padding
  }
  max_i(children_width, obj.label.length() + config.h_padding * 2 + 2)
}

///|
fn find_ascii_roots(graph : Graph) -> Array[Object] {
  // Track which objects are children of containers
  let child_ids : Map[String, Bool] = {}
  for obj in graph.objects {
    for child in obj.children {
      child_ids[child.id] = true
    }
  }
  // Objects that are not targets of any edge and not children
  let targets : Map[String, Bool] = {}
  for edge in graph.edges {
    targets[edge.get_dst_id()] = true
  }
  let roots : Array[Object] = []
  for obj in graph.objects {
    // Include object if it's not a target and not a child of a container
    if not(targets.contains(obj.id)) && not(child_ids.contains(obj.id)) {
      roots.push(obj)
    }
  }
  // If no roots found, use first non-child object
  if roots.length() == 0 {
    for obj in graph.objects {
      if not(child_ids.contains(obj.id)) {
        roots.push(obj)
        break
      }
    }
  }
  roots
}

///|
fn create_ascii_box(
  obj : Object,
  x : Int,
  y : Int,
  config : AsciiConfig,
) -> AsciiBox {
  let is_container = obj.is_container()
  let width = max_i(
    config.min_box_width,
    obj.label.length() + config.h_padding * 2 + 2,
  )
  {
    id: obj.id,
    x,
    y,
    width,
    height: config.box_height,
    label: obj.label,
    shape: obj.shape,
    is_container,
    children: [],
  }
}

///|
/// Create a container box with its children laid out inside
fn create_container_box(
  obj : Object,
  x : Int,
  y : Int,
  config : AsciiConfig,
) -> AsciiBox {
  // Layout children horizontally inside the container
  let children : Array[AsciiBox] = []
  let padding = 2 // Padding inside container
  let title_height = 2 // Title row + 1 row gap
  let mut child_x = x + padding
  let child_y = y + title_height
  for child in obj.children {
    let child_box = if child.is_container() {
      create_container_box(child, child_x, child_y, config)
    } else {
      create_ascii_box(child, child_x, child_y, config)
    }
    child_x = child_x + child_box.width + config.h_spacing
    children.push(child_box)
  }
  // Calculate container width to fit all children
  let children_width = if children.length() > 0 {
    let last = children[children.length() - 1]
    last.x + last.width - x + padding
  } else {
    config.min_box_width
  }
  // Calculate container height
  let children_height = if children.length() > 0 {
    let max_child_height = children.fold(init=0, fn(acc, c) {
      max_i(acc, c.height)
    })
    max_child_height
  } else {
    config.box_height
  }
  let container_width = max_i(
    children_width,
    obj.label.length() + config.h_padding * 2 + 2,
  )
  let container_height = title_height + children_height + padding
  {
    id: obj.id,
    x,
    y,
    width: container_width,
    height: container_height,
    label: obj.label,
    shape: "container",
    is_container: true,
    children,
  }
}

///|
fn compute_parent_center(
  parent_ids : Array[String],
  placed : Map[String, AsciiBox],
) -> Int {
  let mut sum_x = 0
  let mut count = 0
  for id in parent_ids {
    match placed.get(id) {
      Some(box) => {
        sum_x = sum_x + box.x + box.width / 2
        count = count + 1
      }
      None => ()
    }
  }
  if count > 0 {
    sum_x / count
  } else {
    20
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
/// Render a single ASCII box
fn render_ascii_box(
  grid : @ascii.Grid,
  box : AsciiBox,
  _config : AsciiConfig,
) -> Unit {
  let x1 = box.x
  let y1 = box.y
  let x2 = box.x + box.width - 1
  let y2 = box.y + box.height - 1
  // Draw box shape
  match box.shape {
    "circle" | "oval" => {
      grid.set(x1, y1, '┌')
      grid.set(x1 + 1, y1, '⬭')
      grid.hline(x1 + 2, x2 - 1, y1, '─')
      grid.set(x2, y1, '┐')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '└')
      grid.hline(x1 + 1, x2 - 1, y2, '─')
      grid.set(x2, y2, '┘')
    }
    "cylinder" => {
      // Top: .-‾‾-.
      grid.set(x1, y1, '.')
      grid.set(x1 + 1, y1, '-')
      grid.hline(x1 + 2, x2 - 2, y1, '‾')
      grid.set(x2 - 1, y1, '-')
      grid.set(x2, y1, '.')
      // Sides
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      // Bottom: ╲-__-╱
      grid.set(x1, y2, ' ')
      grid.set(x1 + 1, y2, '╲')
      grid.set(x1 + 2, y2, '-')
      grid.hline(x1 + 3, x2 - 3, y2, '_')
      grid.set(x2 - 2, y2, '-')
      grid.set(x2 - 1, y2, '╱')
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
      grid.set(x1, y1, '┌')
      grid.set(x1 + 1, y1, '☁')
      grid.hline(x1 + 2, x2 - 1, y1, '─')
      grid.set(x2, y1, '┐')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '└')
      grid.hline(x1 + 1, x2 - 1, y2, '─')
      grid.set(x2, y2, '┘')
    }
    "person" => {
      // Stick figure:  ╱‾‾╲
      //                ╲__╱
      //               ╱‾‾‾‾╲
      //               ‾‾‾‾‾‾
      let cx = (x1 + x2) / 2
      // Head (top)
      grid.set(cx - 1, y1, '╱')
      grid.set(cx, y1, '‾')
      grid.set(cx + 1, y1, '╲')
      grid.set(cx - 1, y1 + 1, '╲')
      grid.set(cx, y1 + 1, '_')
      grid.set(cx + 1, y1 + 1, '╱')
      // Body (bottom)
      if y2 > y1 + 2 {
        grid.set(cx - 2, y1 + 2, '╱')
        grid.hline(cx - 1, cx + 1, y1 + 2, '‾')
        grid.set(cx + 2, y1 + 2, '╲')
        grid.hline(cx - 2, cx + 2, y2, '‾')
      }
    }
    "hexagon" => {
      // Hexagon:  ╱‾‾‾‾‾╲
      //          ╲_____╱
      grid.set(x1, y1, '╱')
      grid.hline(x1 + 1, x2 - 1, y1, '‾')
      grid.set(x2, y1, '╲')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '╲')
      grid.hline(x1 + 1, x2 - 1, y2, '_')
      grid.set(x2, y2, '╱')
    }
    "parallelogram" => {
      // Parallelogram: ╱‾‾‾‾‾╱
      //               ╱_____╱
      grid.set(x1, y1, '╱')
      grid.hline(x1 + 1, x2 - 1, y1, '‾')
      grid.set(x2, y1, '╱')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '╱')
      grid.hline(x1 + 1, x2 - 1, y2, '_')
      grid.set(x2, y2, '╱')
    }
    "document" => {
      // Document: box with wavy bottom
      grid.set(x1, y1, '┌')
      grid.hline(x1 + 1, x2 - 1, y1, '─')
      grid.set(x2, y1, '┐')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      // Wavy bottom: `-.-`
      grid.set(x1, y2, '`')
      grid.set(x1 + 1, y2, '-')
      grid.set(x1 + 2, y2, '.')
      grid.set(x1 + 3, y2, '-')
      grid.set(x1 + 4, y2, '`')
    }
    "page" => {
      // Page: box with folded corner
      grid.set(x1, y1, '┌')
      grid.hline(x1 + 1, x2 - 2, y1, '─')
      grid.set(x2 - 1, y1, '╲')
      grid.set(x2, y1, '┐')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '└')
      grid.hline(x1 + 1, x2 - 1, y2, '─')
      grid.set(x2, y2, '┘')
    }
    "package" => {
      // Package: box with top fold
      grid.set(x1, y1, '┌')
      grid.hline(x1 + 1, x2 - 2, y1, '─')
      grid.set(x2 - 1, y1, '└')
      grid.set(x2, y1, '─')
      grid.set(x2 + 1, y1, '┐')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '└')
      grid.hline(x1 + 1, x2 - 1, y2, '─')
      grid.set(x2, y2, '┘')
    }
    "queue" => {
      // Queue: box with right side extending
      grid.set(x1, y1, '╱')
      grid.hline(x1 + 1, x2 - 1, y1, '‾')
      grid.set(x2, y1, '╱')
      grid.set(x2 + 1, y1, '╲')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '╲')
      grid.hline(x1 + 1, x2 - 1, y2, '_')
      grid.set(x2, y2, '╲')
      grid.set(x2 + 1, y2, '╱')
    }
    "step" => {
      // Step: parallelogram pointing right
      grid.set(x1, y1, '╲')
      grid.hline(x1 + 1, x2 - 1, y1, '‾')
      grid.set(x2, y1, '╲')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '╱')
      grid.hline(x1 + 1, x2 - 1, y2, '_')
      grid.set(x2, y2, '╱')
    }
    "stored_data" => {
      // Stored data: parallelogram-like cylinder
      grid.set(x1, y1, '╱')
      grid.hline(x1 + 1, x2 - 1, y1, '‾')
      grid.set(x2, y1, '╱')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '╲')
      grid.hline(x1 + 1, x2 - 1, y2, '_')
      grid.set(x2, y2, '╲')
    }
    "callout" => {
      // Callout: box with arrow pointing down
      grid.set(x1, y1, '┌')
      grid.hline(x1 + 1, x2 - 1, y1, '─')
      grid.set(x2, y1, '┐')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '└')
      grid.hline(x1 + 1, x2 - 1, y2, '─')
      grid.set(x2, y2, '┘')
      // Arrow pointing down
      let cx = (x1 + x2) / 2
      grid.set(cx, y2 + 1, '│')
      grid.set(cx, y2 + 2, '╱')
    }
    "container" => {
      // Container: box with title at top, children inside
      // Draw the border
      grid.set(x1, y1, '┌')
      grid.hline(x1 + 1, x2 - 1, y1, '─')
      grid.set(x2, y1, '┐')
      grid.vline(x1, y1 + 1, y2 - 1, '│')
      grid.vline(x2, y1 + 1, y2 - 1, '│')
      grid.set(x1, y2, '└')
      grid.hline(x1 + 1, x2 - 1, y2, '─')
      grid.set(x2, y2, '┘')
      // Draw title centered at top
      let label_x = x1 + (box.width - box.label.length()) / 2
      grid.text(label_x, y1 + 1, box.label)
      // Note: children are rendered separately since they're in the flattened boxes list
      return
    }
    _ => grid.unicode_rect(x1, y1, x2, y2)
  }
  // Draw label centered (on first content line, which is y1 + 1)
  let label_x = x1 + (box.width - box.label.length()) / 2
  let label_y = y1 + 1
  grid.text(label_x, label_y, box.label)
}

///|
/// Render only the container border (called after edges to ensure clean borders)
fn render_container_border(grid : @ascii.Grid, box : AsciiBox) -> Unit {
  let x1 = box.x
  let y1 = box.y
  let x2 = box.x + box.width - 1
  let y2 = box.y + box.height - 1
  // Draw corners
  grid.set(x1, y1, '┌')
  grid.set(x2, y1, '┐')
  grid.set(x1, y2, '└')
  grid.set(x2, y2, '┘')
  // Draw top and bottom edges
  grid.hline(x1 + 1, x2 - 1, y1, '─')
  grid.hline(x1 + 1, x2 - 1, y2, '─')
  // Draw left and right edges
  grid.vline(x1, y1 + 1, y2 - 1, '│')
  grid.vline(x2, y1 + 1, y2 - 1, '│')
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
  _config : AsciiConfig,
) -> Unit {
  let src_id = edge.get_src_id()
  let dst_id = edge.get_dst_id()
  let src_box = find_ascii_box(boxes, src_id)
  let dst_box = find_ascii_box(boxes, dst_id)
  let offset = compute_edge_offset(graph, edge, ref_idx, boxes)
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
          grid.vline(line_x, src_bottom, dst_top, '│')
        } else {
          // L-shaped routing needed
          let line_x = src_center_x + offset
          // Draw vertical line from source
          let mid_y = (src_bottom + dst_top) / 2
          grid.vline(line_x, src_bottom, mid_y, '│')
          // Draw corner
          if dst_center_x > line_x {
            grid.set(line_x, mid_y, '└')
            // Draw horizontal line
            grid.hline(line_x + 1, dst_center_x - 1, mid_y, '─')
            grid.set(dst_center_x, mid_y, '┐')
          } else {
            grid.set(line_x, mid_y, '┘')
            // Draw horizontal line
            grid.hline(dst_center_x + 1, line_x - 1, mid_y, '─')
            grid.set(dst_center_x, mid_y, '┌')
          }
          // Draw vertical line to destination
          grid.vline(dst_center_x, mid_y + 1, dst_top, '│')
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
          grid.vline(line_x, dst_bottom, src_top, '│')
        } else {
          // L-shaped routing upward
          let line_x = src_center_x + offset
          let mid_y = (dst_bottom + src_top) / 2
          grid.vline(line_x, mid_y, src_top, '│')
          if dst_center_x > line_x {
            grid.set(line_x, mid_y, '┌')
            grid.hline(line_x + 1, dst_center_x - 1, mid_y, '─')
            grid.set(dst_center_x, mid_y, '┘')
          } else {
            grid.set(line_x, mid_y, '┐')
            grid.hline(dst_center_x + 1, line_x - 1, mid_y, '─')
            grid.set(dst_center_x, mid_y, '└')
          }
          grid.vline(dst_center_x, dst_bottom, mid_y - 1, '│')
        }
      } else if dst.x != src.x {
        // Side by side - horizontal connection
        let cy = src.y + src.height / 2
        if src.x < dst.x {
          grid.hline(src.x + src.width, dst.x - 1, cy, '─')
        } else {
          grid.hline(dst.x + dst.width, src.x - 1, cy, '─')
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
  _config : AsciiConfig,
) -> Unit {
  let src_id = edge.get_src_id()
  let dst_id = edge.get_dst_id()
  let src_box = find_ascii_box(boxes, src_id)
  let dst_box = find_ascii_box(boxes, dst_id)
  let offset = compute_edge_offset(graph, edge, ref_idx, boxes)
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
            grid.set(line_x, dst_top, '▼')
          }
          if edge.src_arrow && ref_idx == 0 {
            grid.set(line_x, src_bottom, '▲')
          }
        } else {
          // L-shaped routing - arrow at destination center
          if edge.dst_arrow {
            grid.set(dst_center_x, dst_top, '▼')
          }
          if edge.src_arrow && ref_idx == 0 {
            let line_x = src_center_x + offset
            grid.set(line_x, src_bottom, '▲')
          }
        }
      } else if src.y > dst.y + dst.height {
        // Destination is above source - upward arrows
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
            grid.set(line_x, dst_bottom, '▼')
          }
          if edge.src_arrow && ref_idx == 0 {
            grid.set(line_x, src_top, '▲')
          }
        } else {
          if edge.dst_arrow {
            grid.set(dst_center_x, dst_bottom, '▼')
          }
          if edge.src_arrow && ref_idx == 0 {
            let line_x = src_center_x + offset
            grid.set(line_x, src_top, '▲')
          }
        }
      } else if dst.x != src.x {
        // Horizontal edge
        if edge.dst_arrow {
          if dst.x > src.x {
            grid.set(dst.x - 1, dst.y + dst.height / 2, '▶')
          } else {
            grid.set(dst.x + dst.width, dst.y + dst.height / 2, '◀')
          }
        }
        if edge.src_arrow && ref_idx == 0 {
          if dst.x > src.x {
            grid.set(src.x + src.width, src.y + src.height / 2, '◀')
          } else {
            grid.set(src.x - 1, src.y + src.height / 2, '▶')
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
