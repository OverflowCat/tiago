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
  // Each edge may have multiple references, render each as a separate line
  for edge in graph.edges {
    for ref_idx = 0; ref_idx < edge.reference_count; ref_idx = ref_idx + 1 {
      render_ascii_edge_new(grid, graph, edge, ref_idx, boxes, config)
    }
  }
  // Render objects
  for box in boxes {
    render_ascii_box(grid, box, config)
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
/// Compute horizontal offset for parallel edges between same node pair
/// ref_idx: which reference of this edge (0..reference_count-1)
fn compute_edge_offset(
  graph : Graph,
  edge : Edge,
  ref_idx : Int,
  _boxes : Array[AsciiBox],
) -> Int {
  let src_id = edge.get_src_id()
  let dst_id = edge.get_dst_id()
  // Count total parallel lines: sum of reference_count for all edges between same nodes
  let mut total_lines = 0
  let mut line_index = 0
  for e in graph.edges {
    let e_src = e.get_src_id()
    let e_dst = e.get_dst_id()
    // Check if same node pair (considering both directions)
    if (e_src == src_id && e_dst == dst_id) ||
      (e_src == dst_id && e_dst == src_id) {
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
  // Calculate offset: spread lines around center
  let spacing = 2 // chars between parallel lines
  let total_width = (total_lines - 1) * spacing
  let start_offset = -(total_width / 2)
  start_offset + line_index * spacing
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
/// Render edge lines - straight vertical lines only
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
    (Some(src), Some(dst)) => {
      if dst.y > src.y + src.height {
        // Vertical edge going down - use destination center + offset
        let line_x = dst.x + dst.width / 2 + offset
        let src_bottom = src.y + src.height
        let dst_top = dst.y - 1
        grid.vline(line_x, src_bottom, dst_top, '│')
      } else if dst.x != src.x {
        // Side by side - horizontal connection
        let cy = src.y + src.height / 2
        if src.x < dst.x {
          grid.hline(src.x + src.width, dst.x - 1, cy, '─')
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
    (Some(src), Some(dst)) => {
      if dst.y > src.y + src.height {
        // Vertical edge - line is at destination center + offset
        let line_x = dst.x + dst.width / 2 + offset
        let src_bottom = src.y + src.height
        let dst_top = dst.y - 1
        if edge.dst_arrow {
          grid.set(line_x, dst_top, '▼')
        }
        // Only draw src_arrow on first reference to avoid duplicates
        if edge.src_arrow && ref_idx == 0 {
          grid.set(line_x, src_bottom, '▲')
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
    (Some(src), Some(dst)) => {
      if dst.y > src.y + src.height {
        // Vertical edge - place label in the MIDDLE of the edge
        let line_x = dst.x + dst.width / 2 + offset
        let src_bottom = src.y + src.height
        let dst_top = dst.y - 1
        let mid_y = (src_bottom + dst_top) / 2
        grid.text(line_x - edge.label.length() / 2, mid_y, edge.label)
      } else {
        // Horizontal edge
        let cy = src.y + src.height / 2
        let cx = (src.x + src.width + dst.x) / 2
        grid.text(cx - edge.label.length() / 2, cy, edge.label)
      }
    }
    _ => ()
  }
}
