///|
/// ASCII Renderer for Graph
///
/// Renders a laid-out Graph to ASCII art using the pure ascii library.

///|
/// ASCII rendering configuration
pub struct AsciiConfig {
  /// Pixels per character (horizontal)
  x_scale : Double
  /// Pixels per character (vertical)
  y_scale : Double
  /// Minimum width in characters
  min_width : Int
  /// Minimum height in characters
  min_height : Int
} derive(Show)

///|
pub fn AsciiConfig::new() -> AsciiConfig {
  { x_scale: 8.0, y_scale: 16.0, min_width: 40, min_height: 10 }
}

///|
/// Render a graph to ASCII string
pub fn render_ascii(graph : Graph, config : AsciiConfig) -> String {
  // Calculate grid dimensions
  let (max_x, max_y) = compute_graph_bounds(graph)
  let width = max_int((max_x + 40.0) / config.x_scale, config.min_width)
  let height = max_int((max_y + 20.0) / config.y_scale, config.min_height)
  let grid = @ascii.Grid::new(width, height)
  // Render edges first (behind objects)
  for edge in graph.edges {
    render_ascii_edge(grid, edge, config)
  }
  // Render objects
  for obj in graph.objects {
    render_ascii_object(grid, obj, config)
  }
  grid.to_string()
}

///|
fn max_int(a : Double, b : Int) -> Int {
  let ai = a.to_int()
  if ai > b {
    ai
  } else {
    b
  }
}

///|
fn render_ascii_object(
  grid : @ascii.Grid,
  obj : Object,
  config : AsciiConfig,
) -> Unit {
  guard obj.box is Some(box) else { return }
  // Convert to grid coordinates
  let x1 = (box.x / config.x_scale).to_int()
  let y1 = (box.y / config.y_scale).to_int()
  let x2 = ((box.x + box.width) / config.x_scale).to_int()
  let y2 = ((box.y + box.height) / config.y_scale).to_int()
  // Draw shape
  match obj.shape {
    "circle" | "oval" => draw_ascii_oval(grid, x1, y1, x2, y2)
    "diamond" => draw_ascii_diamond(grid, x1, y1, x2, y2)
    "cylinder" => draw_ascii_cylinder(grid, x1, y1, x2, y2)
    _ => grid.rect(x1, y1, x2, y2, '+', '-', '|')
  }
  // Draw label centered
  let label = truncate_label(obj.label, x2 - x1 - 2)
  let label_x = x1 + (x2 - x1 - label.length()) / 2
  let label_y = y1 + (y2 - y1) / 2
  grid.text(max(label_x, x1 + 1), label_y, label)
}

///|
fn max(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn truncate_label(s : String, max_len : Int) -> String {
  if max_len <= 0 {
    ""
  } else if s.length() <= max_len {
    s
  } else if max_len <= 3 {
    (try! s[:max_len]).to_string()
  } else {
    (try! s[:max_len - 2]).to_string() + ".."
  }
}

///|
fn draw_ascii_oval(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Top edge
  grid.set(x1, y1, '/')
  grid.hline(x1 + 1, x2 - 1, y1, '-')
  grid.set(x2, y1, '\\')
  // Bottom edge
  grid.set(x1, y2, '\\')
  grid.hline(x1 + 1, x2 - 1, y2, '-')
  grid.set(x2, y2, '/')
  // Sides
  grid.vline(x1, y1 + 1, y2 - 1, '|')
  grid.vline(x2, y1 + 1, y2 - 1, '|')
}

///|
fn draw_ascii_diamond(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  let cx = (x1 + x2) / 2
  let cy = (y1 + y2) / 2
  let half_w = (x2 - x1) / 2
  let half_h = (y2 - y1) / 2
  // Top and bottom points
  grid.set(cx, y1, '^')
  grid.set(cx, y2, 'v')
  // Left and right points
  grid.set(x1, cy, '<')
  grid.set(x2, cy, '>')
  // Diagonal edges
  for i in 1..<half_h {
    let dx = i * half_w / half_h
    if dx > 0 {
      grid.set(cx - dx, y1 + i, '/')
      grid.set(cx + dx, y1 + i, '\\')
      grid.set(cx - dx, y2 - i, '\\')
      grid.set(cx + dx, y2 - i, '/')
    }
  }
}

///|
fn draw_ascii_cylinder(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Top ellipse
  grid.set(x1, y1, '/')
  grid.hline(x1 + 1, x2 - 1, y1, '-')
  grid.set(x2, y1, '\\')
  // Second line
  if y2 - y1 > 2 {
    grid.set(x1, y1 + 1, '\\')
    grid.hline(x1 + 1, x2 - 1, y1 + 1, '_')
    grid.set(x2, y1 + 1, '/')
  }
  // Sides
  grid.vline(x1, y1 + 2, y2 - 1, '|')
  grid.vline(x2, y1 + 2, y2 - 1, '|')
  // Bottom
  grid.set(x1, y2, '\\')
  grid.hline(x1 + 1, x2 - 1, y2, '_')
  grid.set(x2, y2, '/')
}

///|
fn render_ascii_edge(
  grid : @ascii.Grid,
  edge : Edge,
  config : AsciiConfig,
) -> Unit {
  let route = edge.route
  if route.length() < 2 {
    return
  }
  // Draw line segments
  for i in 0..<(route.length() - 1) {
    let p1 = route[i]
    let p2 = route[i + 1]
    let x1 = (p1.x / config.x_scale).to_int()
    let y1 = (p1.y / config.y_scale).to_int()
    let x2 = (p2.x / config.x_scale).to_int()
    let y2 = (p2.y / config.y_scale).to_int()
    grid.line(x1, y1, x2, y2, '-', '|', '\\', '/')
  }
  // Draw arrow at end
  if edge.dst_arrow {
    let last = route[route.length() - 1]
    let prev = route[route.length() - 2]
    let lx = (last.x / config.x_scale).to_int()
    let ly = (last.y / config.y_scale).to_int()
    let px = (prev.x / config.x_scale).to_int()
    let py = (prev.y / config.y_scale).to_int()
    let arrow = if lx > px {
      '>'
    } else if lx < px {
      '<'
    } else if ly > py {
      'v'
    } else {
      '^'
    }
    grid.set(lx, ly, arrow)
  }
  // Draw label at midpoint
  if edge.label.length() > 0 {
    match edge.midpoint() {
      Some(mid) => {
        let mx = (mid.x / config.x_scale).to_int()
        let my = (mid.y / config.y_scale).to_int()
        let label = truncate_label(edge.label, 10)
        grid.text(mx - label.length() / 2, my, label)
      }
      None => ()
    }
  }
}
