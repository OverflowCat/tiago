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
    render_ascii_edge_new(grid, edge, boxes, config)
  }
  // Render objects
  for box in boxes {
    render_ascii_box(grid, box, config)
  }
  // Render edge labels
  for edge in graph.edges {
    render_ascii_label_new(grid, edge, boxes, config)
  }
  // Render edge arrows LAST (on top of everything)
  for edge in graph.edges {
    render_ascii_arrows_new(grid, edge, boxes, config)
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
  // Layout objects level by level (BFS)
  let placed : Map[String, AsciiBox] = {}
  let mut current_y = 1
  // First pass: place roots
  let mut current_x = 1
  for obj in roots {
    let box = create_ascii_box(obj, current_x, current_y, config)
    boxes.push(box)
    placed[obj.id] = box
    current_x = current_x + box.width + config.h_spacing
  }
  current_y = current_y + config.box_height + config.v_spacing
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
                  level_objs.push(obj)
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
      let level_width = compute_level_width(level_objs, config)
      let parent_center = compute_parent_center(frontier, placed)
      let start_x = max_i(1, parent_center - level_width / 2)
      let mut x = start_x
      for obj in level_objs {
        let box = create_ascii_box(obj, x, current_y, config)
        boxes.push(box)
        placed[obj.id] = box
        x = x + box.width + config.h_spacing
      }
      current_y = current_y + config.box_height + config.v_spacing
    }
    frontier = next_frontier
  }
  // Add any unplaced objects (disconnected)
  for obj in graph.objects {
    if not(placed.contains(obj.id)) {
      let box = create_ascii_box(obj, 1, current_y, config)
      boxes.push(box)
      placed[obj.id] = box
      current_y = current_y + config.box_height + config.v_spacing
    }
  }
  boxes
}

///|
fn find_ascii_roots(graph : Graph) -> Array[Object] {
  // Objects that are not targets of any edge
  let targets : Map[String, Bool] = {}
  for edge in graph.edges {
    targets[edge.get_dst_id()] = true
  }
  let roots : Array[Object] = []
  for obj in graph.objects {
    if not(targets.contains(obj.id)) && not(obj.is_container()) {
      roots.push(obj)
    }
  }
  // If no roots found, use first object
  if roots.length() == 0 && graph.objects.length() > 0 {
    roots.push(graph.objects[0])
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
  }
}

///|
fn compute_level_width(objs : Array[Object], config : AsciiConfig) -> Int {
  let mut width = 0
  for obj in objs {
    let box_width = max_i(
      config.min_box_width,
      obj.label.length() + config.h_padding * 2 + 2,
    )
    width = width + box_width + config.h_spacing
  }
  if width > 0 {
    width - config.h_spacing
  } else {
    0
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
    _ => grid.unicode_rect(x1, y1, x2, y2)
  }
  // Draw label centered (on first content line, which is y1 + 1)
  let label_x = x1 + (box.width - box.label.length()) / 2
  let label_y = y1 + 1
  grid.text(label_x, label_y, box.label)
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
/// Render edge lines with orthogonal routing
fn render_ascii_edge_new(
  grid : @ascii.Grid,
  edge : Edge,
  boxes : Array[AsciiBox],
  _config : AsciiConfig,
) -> Unit {
  // Find source and destination boxes by ID
  let src_id = edge.get_src_id()
  let dst_id = edge.get_dst_id()
  let src_box = find_ascii_box(boxes, src_id)
  let dst_box = find_ascii_box(boxes, dst_id)
  match (src_box, dst_box) {
    (Some(src), Some(dst)) => {
      // Calculate connection points
      let src_cx = src.x + src.width / 2
      let src_bottom = src.y + src.height
      let dst_cx = dst.x + dst.width / 2
      let dst_top = dst.y - 1
      // Draw vertical line from source bottom
      if dst.y > src.y + src.height {
        // Going down
        if src_cx == dst_cx {
          // Straight down
          grid.vline(src_cx, src_bottom, dst_top, '│')
        } else {
          // Need orthogonal routing
          let mid_y = (src_bottom + dst_top) / 2
          // Down from source
          grid.vline(src_cx, src_bottom, mid_y, '│')
          // Horizontal
          if src_cx < dst_cx {
            grid.set(src_cx, mid_y, '└')
            grid.hline(src_cx + 1, dst_cx - 1, mid_y, '─')
            grid.set(dst_cx, mid_y, '┐')
          } else {
            grid.set(src_cx, mid_y, '┘')
            grid.hline(dst_cx + 1, src_cx - 1, mid_y, '─')
            grid.set(dst_cx, mid_y, '┌')
          }
          // Down to dest
          grid.vline(dst_cx, mid_y + 1, dst_top, '│')
        }
      } else if dst.x != src.x {
        // Side by side - horizontal connection
        let src_right = src.x + src.width
        let dst_left = dst.x - 1
        let cy = src.y + src.height / 2
        if src.x < dst.x {
          grid.hline(src_right, dst_left, cy, '─')
        } else {
          grid.hline(dst.x + dst.width, src.x - 1, cy, '─')
        }
      }
    }
    _ => ()
  }
}

///|
/// Render edge arrows
fn render_ascii_arrows_new(
  grid : @ascii.Grid,
  edge : Edge,
  boxes : Array[AsciiBox],
  _config : AsciiConfig,
) -> Unit {
  let src_id = edge.get_src_id()
  let dst_id = edge.get_dst_id()
  let src_box = find_ascii_box(boxes, src_id)
  let dst_box = find_ascii_box(boxes, dst_id)
  match (src_box, dst_box) {
    (Some(src), Some(dst)) => {
      if edge.dst_arrow {
        let dst_cx = dst.x + dst.width / 2
        let dst_top = dst.y - 1
        if dst.y > src.y + src.height {
          // Arrow pointing down
          grid.set(dst_cx, dst_top, '▼')
        } else if dst.x > src.x {
          // Arrow pointing right
          grid.set(dst.x - 1, dst.y + dst.height / 2, '▶')
        } else {
          // Arrow pointing left
          grid.set(dst.x + dst.width, dst.y + dst.height / 2, '◀')
        }
      }
      if edge.src_arrow {
        let src_cx = src.x + src.width / 2
        let src_bottom = src.y + src.height
        if dst.y > src.y + src.height {
          // Arrow pointing up from source
          grid.set(src_cx, src_bottom, '▲')
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
  edge : Edge,
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
  match (src_box, dst_box) {
    (Some(src), Some(dst)) => {
      let label = edge.label.replace(old=" ", new="─")
      if dst.y > src.y + src.height {
        // Vertical edge - place label above the arrow (not at arrow position)
        let cx = (src.x + src.width / 2 + dst.x + dst.width / 2) / 2
        // Put label on the line after the source box, not at the midpoint
        let cy = src.y + src.height + 1
        grid.text(cx - label.length() / 2, cy, label)
      } else {
        // Horizontal edge
        let cy = src.y + src.height / 2
        let cx = (src.x + src.width + dst.x) / 2
        grid.text(cx - label.length() / 2, cy, label)
      }
    }
    _ => ()
  }
}
