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
  // More compact scaling to match d2's output
  { x_scale: 10.0, y_scale: 20.0, min_width: 40, min_height: 10 }
}

///|
/// Render a graph to ASCII string
pub fn render_ascii(graph : Graph, config : AsciiConfig) -> String {
  // Calculate grid dimensions
  let (max_x, max_y) = compute_graph_bounds(graph)
  let width = max_int((max_x + 40.0) / config.x_scale, config.min_width)
  let height = max_int((max_y + 20.0) / config.y_scale, config.min_height)
  let grid = @ascii.Grid::new(width, height)
  // Render edge lines first (behind objects)
  for edge in graph.edges {
    render_ascii_edge_lines(grid, edge, config)
  }
  // Render objects
  for obj in graph.objects {
    render_ascii_object(grid, obj, config)
  }
  // Render edge arrows last (on top of objects)
  for edge in graph.edges {
    render_ascii_edge_arrows(grid, edge, config)
  }
  // Render edge labels
  for edge in graph.edges {
    render_ascii_edge_label(grid, edge, config)
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
    "circle" => draw_unicode_circle(grid, x1, y1, x2, y2)
    "oval" => draw_unicode_oval(grid, x1, y1, x2, y2)
    "diamond" => draw_unicode_diamond(grid, x1, y1, x2, y2)
    "cylinder" => draw_unicode_cylinder(grid, x1, y1, x2, y2)
    "hexagon" => draw_unicode_hexagon(grid, x1, y1, x2, y2)
    "parallelogram" => draw_unicode_parallelogram(grid, x1, y1, x2, y2)
    "queue" => draw_unicode_queue(grid, x1, y1, x2, y2)
    "document" => draw_unicode_document(grid, x1, y1, x2, y2)
    "stored_data" => draw_unicode_stored_data(grid, x1, y1, x2, y2)
    "page" => draw_unicode_page(grid, x1, y1, x2, y2)
    "package" => draw_unicode_package(grid, x1, y1, x2, y2)
    "step" => draw_unicode_step(grid, x1, y1, x2, y2)
    "callout" => draw_unicode_callout(grid, x1, y1, x2, y2)
    "cloud" => draw_unicode_cloud(grid, x1, y1, x2, y2)
    "person" => draw_unicode_person(grid, x1, y1, x2, y2)
    _ => grid.unicode_rect(x1, y1, x2, y2)
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
/// Draw circle with Unicode (uses ┌⬭ marker at top-left)
fn draw_unicode_circle(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Draw oval with circle marker
  grid.set(x1, y1, '┌')
  grid.set(x1 + 1, y1, '⬭')
  grid.hline(x1 + 2, x2 - 1, y1, '─')
  grid.set(x2, y1, '┐')
  grid.set(x1, y2, '└')
  grid.hline(x1 + 1, x2 - 1, y2, '─')
  grid.set(x2, y2, '┘')
  grid.vline(x1, y1 + 1, y2 - 1, '│')
  grid.vline(x2, y1 + 1, y2 - 1, '│')
}

///|
/// Draw oval with Unicode (uses ┌⬭ marker at top-left)
fn draw_unicode_oval(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Similar to circle but for oval
  grid.set(x1, y1, '┌')
  grid.set(x1 + 1, y1, '⬭')
  grid.hline(x1 + 2, x2 - 1, y1, '─')
  grid.set(x2, y1, '┐')
  grid.set(x1, y2, '└')
  grid.hline(x1 + 1, x2 - 1, y2, '─')
  grid.set(x2, y2, '┘')
  grid.vline(x1, y1 + 1, y2 - 1, '│')
  grid.vline(x2, y1 + 1, y2 - 1, '│')
}

///|
/// Draw diamond shape with Unicode
fn draw_unicode_diamond(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  let cx = (x1 + x2) / 2
  let half_w = (x2 - x1) / 2
  let half_h = (y2 - y1) / 2
  // Draw asterisks for diamond shape
  grid.set(cx, y1, '*')
  grid.set(cx, y2, '*')
  for i in 0..=half_h {
    let dx = i * half_w / max(half_h, 1)
    for j in -dx..=dx {
      if i == 0 || i == half_h || j == -dx || j == dx {
        grid.set(cx + j, y1 + i, '*')
        grid.set(cx + j, y2 - i, '*')
      }
    }
  }
}

///|
/// Draw cylinder shape with Unicode (database-like)
fn draw_unicode_cylinder(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Top ellipse: .-‾‾‾-.
  grid.set(x1, y1, '.')
  grid.set(x1 + 1, y1, '-')
  grid.hline(x1 + 2, x2 - 2, y1, '‾')
  grid.set(x2 - 1, y1, '-')
  grid.set(x2, y1, '.')
  // Second line with top curve: │╲-____-╱│
  if y2 - y1 > 2 {
    grid.set(x1, y1 + 1, '│')
    grid.set(x1 + 1, y1 + 1, '╲')
    grid.set(x1 + 2, y1 + 1, '-')
    grid.hline(x1 + 3, x2 - 3, y1 + 1, '_')
    grid.set(x2 - 2, y1 + 1, '-')
    grid.set(x2 - 1, y1 + 1, '╱')
    grid.set(x2, y1 + 1, '│')
  }
  // Sides
  grid.vline(x1, y1 + 2, y2 - 1, '│')
  grid.vline(x2, y1 + 2, y2 - 1, '│')
  // Bottom ellipse: ╲-____-╱
  grid.set(x1, y2, ' ')
  grid.set(x1 + 1, y2, '╲')
  grid.set(x1 + 2, y2, '-')
  grid.hline(x1 + 3, x2 - 3, y2, '_')
  grid.set(x2 - 2, y2, '-')
  grid.set(x2 - 1, y2, '╱')
}

///|
/// Draw hexagon shape with Unicode
fn draw_unicode_hexagon(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  let w = x2 - x1
  let indent = max(w / 4, 1)
  // Top edge
  grid.set(x1 + indent, y1, '╱')
  grid.hline(x1 + indent + 1, x2 - indent - 1, y1, '‾')
  grid.set(x2 - indent, y1, '╲')
  // Top slants
  grid.set(x1, y1 + 1, '╱')
  grid.set(x2, y1 + 1, '╲')
  // Sides
  let mid_start = y1 + 2
  let mid_end = y2 - 2
  if mid_end >= mid_start {
    grid.hline(x1, x1, mid_start, ' ')
    grid.hline(x2, x2, mid_end, ' ')
  }
  // Bottom slants
  grid.set(x1, y2 - 1, '╲')
  grid.set(x2, y2 - 1, '╱')
  // Bottom edge
  grid.set(x1 + indent, y2, '╲')
  grid.hline(x1 + indent + 1, x2 - indent - 1, y2, '_')
  grid.set(x2 - indent, y2, '╱')
}

///|
/// Draw parallelogram shape with Unicode
fn draw_unicode_parallelogram(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  let indent = max((x2 - x1) / 4, 1)
  // Top edge: ╱‾‾‾‾╱
  grid.set(x1 + indent, y1, '╱')
  grid.hline(x1 + indent + 1, x2, y1, '‾')
  grid.set(x2 + 1, y1, '╱')
  // Sides
  grid.set(x1 + indent, y2, '╱')
  // Bottom edge
  grid.hline(x1, x2 - indent, y2, '_')
  grid.set(x2 - indent + 1, y2, '╱')
}

///|
/// Draw queue shape with Unicode (cylinder-like)
fn draw_unicode_queue(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Top: ╱‾‾‾‾‾╱╲
  grid.set(x1, y1, '╱')
  grid.hline(x1 + 1, x2 - 2, y1, '‾')
  grid.set(x2 - 1, y1, '╱')
  grid.set(x2, y1, '╲')
  // Sides
  grid.vline(x1, y1 + 1, y2 - 1, '│')
  grid.vline(x2 - 1, y1 + 1, y2 - 1, '│')
  grid.vline(x2, y1 + 1, y2 - 1, ' ')
  // Bottom: ╲________╲╱
  grid.set(x1, y2, ' ')
  grid.set(x1 + 1, y2, '╲')
  grid.hline(x1 + 2, x2 - 2, y2, '_')
  grid.set(x2 - 1, y2, '╲')
  grid.set(x2, y2, '╱')
}

///|
/// Draw document shape with Unicode
fn draw_unicode_document(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Standard rectangle top and sides
  grid.unicode_rect(x1, y1, x2, y2)
  // Wavy bottom: `-.-`
  grid.set(x1, y2, ' ')
  grid.set(x1 + 1, y2, '`')
  grid.set(x1 + 2, y2, '-')
  grid.set(x1 + 3, y2, '.')
  grid.set(x1 + 4, y2, '-')
  grid.set(x1 + 5, y2, '`')
}

///|
/// Draw stored_data shape with Unicode (slanted cylinder)
fn draw_unicode_stored_data(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Top: ╱‾‾‾‾‾‾‾╱
  grid.set(x1, y1, '╱')
  grid.hline(x1 + 1, x2, y1, '‾')
  grid.set(x2 + 1, y1, '╱')
  // Sides
  grid.vline(x1, y1 + 1, y2 - 1, '│')
  // Bottom: ╲___________╲
  grid.set(x1, y2, ' ')
  grid.set(x1 + 1, y2, '╲')
  grid.hline(x1 + 2, x2, y2, '_')
  grid.set(x2 + 1, y2, '╲')
}

///|
/// Draw page shape with Unicode (folded corner)
fn draw_unicode_page(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Top with fold
  grid.set(x1, y1, '┌')
  grid.hline(x1 + 1, x2 - 2, y1, '─')
  grid.set(x2 - 1, y1, '╲')
  grid.set(x2, y1, '┐')
  // Fold indicator
  grid.set(x2, y1 + 1, '│')
  // Sides
  grid.vline(x1, y1 + 1, y2 - 1, '│')
  grid.vline(x2, y1 + 2, y2 - 1, '│')
  // Bottom
  grid.set(x1, y2, '└')
  grid.hline(x1 + 1, x2 - 1, y2, '─')
  grid.set(x2, y2, '┘')
}

///|
/// Draw package shape with Unicode
fn draw_unicode_package(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Top with tab
  grid.set(x1, y1, '┌')
  grid.hline(x1 + 1, x1 + 3, y1, '─')
  grid.set(x1 + 4, y1, '┐')
  // Tab extension
  grid.set(x1, y1 + 1, '│')
  grid.set(x1 + 4, y1 + 1, '└')
  grid.hline(x1 + 5, x2 - 1, y1 + 1, '─')
  grid.set(x2, y1 + 1, '┐')
  // Sides
  grid.vline(x1, y1 + 2, y2 - 1, '│')
  grid.vline(x2, y1 + 2, y2 - 1, '│')
  // Bottom
  grid.set(x1, y2, '└')
  grid.hline(x1 + 1, x2 - 1, y2, '─')
  grid.set(x2, y2, '┘')
}

///|
/// Draw step shape with Unicode (ribbon-like)
fn draw_unicode_step(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Top: ╲‾‾‾‾‾╲
  grid.set(x1, y1, '╲')
  grid.hline(x1 + 1, x2, y1, '‾')
  grid.set(x2 + 1, y1, '╲')
  // Sides
  grid.set(x1, y1 + 1, ' ')
  grid.set(x1 + 1, y1 + 1, '╲')
  grid.vline(x2 + 1, y1 + 1, y2 - 1, '╲')
  // Bottom: ╱_______╱
  grid.set(x1 + 1, y2, '╱')
  grid.hline(x1 + 2, x2, y2, '_')
  grid.set(x2 + 1, y2, '╱')
}

///|
/// Draw callout shape with Unicode (box with tail)
fn draw_unicode_callout(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Standard box
  grid.unicode_rect(x1, y1, x2, y2)
  // Tail pointing down-left
  grid.set(x1 + 2, y2 + 1, '│')
  grid.set(x1 + 1, y2 + 2, '╱')
}

///|
/// Draw cloud shape with Unicode
fn draw_unicode_cloud(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  // Cloud marker at top-left
  grid.set(x1, y1, '┌')
  grid.set(x1 + 1, y1, '☁')
  grid.hline(x1 + 2, x2 - 1, y1, '─')
  grid.set(x2, y1, '┐')
  // Sides
  grid.vline(x1, y1 + 1, y2 - 1, '│')
  grid.vline(x2, y1 + 1, y2 - 1, '│')
  // Bottom
  grid.set(x1, y2, '└')
  grid.hline(x1 + 1, x2 - 1, y2, '─')
  grid.set(x2, y2, '┘')
}

///|
/// Draw person shape with Unicode (stick figure)
fn draw_unicode_person(
  grid : @ascii.Grid,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  let cx = (x1 + x2) / 2
  // Head: ╱‾‾╲
  grid.set(cx - 1, y1, '╱')
  grid.set(cx, y1, '‾')
  grid.set(cx + 1, y1, '‾')
  grid.set(cx + 2, y1, '╲')
  // Neck: ╲__╱
  grid.set(cx - 1, y1 + 1, '╲')
  grid.set(cx, y1 + 1, '_')
  grid.set(cx + 1, y1 + 1, '_')
  grid.set(cx + 2, y1 + 1, '╱')
  // Body: ╱‾‾‾‾╲
  if y2 - y1 > 3 {
    grid.set(cx - 1, y1 + 2, '╱')
    grid.set(cx, y1 + 2, '‾')
    grid.set(cx + 1, y1 + 2, '‾')
    grid.set(cx + 2, y1 + 2, '╲')
    // Bottom: ‾‾‾‾‾‾
    grid.hline(cx - 1, cx + 2, y1 + 3, '‾')
  }
}

///|
/// Draw edge lines (without arrows)
fn render_ascii_edge_lines(
  grid : @ascii.Grid,
  edge : Edge,
  config : AsciiConfig,
) -> Unit {
  let route = edge.route
  if route.length() < 2 {
    return
  }
  // Draw line segments using Unicode: ─ │
  for i in 0..<(route.length() - 1) {
    let p1 = route[i]
    let p2 = route[i + 1]
    let x1 = (p1.x / config.x_scale).to_int()
    let y1 = (p1.y / config.y_scale).to_int()
    let x2 = (p2.x / config.x_scale).to_int()
    let y2 = (p2.y / config.y_scale).to_int()
    grid.line(x1, y1, x2, y2, '─', '│', '\\', '/')
  }
}

///|
/// Draw edge arrows (called after objects are rendered)
fn render_ascii_edge_arrows(
  grid : @ascii.Grid,
  edge : Edge,
  config : AsciiConfig,
) -> Unit {
  let route = edge.route
  if route.length() < 2 {
    return
  }
  // Draw arrow at end using Unicode arrows: ▼ ▲ ◀ ▶
  if edge.dst_arrow {
    let last = route[route.length() - 1]
    let prev = route[route.length() - 2]
    let lx = (last.x / config.x_scale).to_int()
    let ly = (last.y / config.y_scale).to_int()
    let px = (prev.x / config.x_scale).to_int()
    let py = (prev.y / config.y_scale).to_int()
    let arrow = if lx > px {
      '▶'
    } else if lx < px {
      '◀'
    } else if ly > py {
      '▼'
    } else {
      '▲'
    }
    grid.set(lx, ly, arrow)
  }
  // Draw arrow at start for bidirectional edges
  if edge.src_arrow {
    let first = route[0]
    let second = route[1]
    let fx = (first.x / config.x_scale).to_int()
    let fy = (first.y / config.y_scale).to_int()
    let sx = (second.x / config.x_scale).to_int()
    let sy = (second.y / config.y_scale).to_int()
    let arrow = if fx > sx {
      '▶'
    } else if fx < sx {
      '◀'
    } else if fy > sy {
      '▼'
    } else {
      '▲'
    }
    grid.set(fx, fy, arrow)
  }
}

///|
/// Draw edge labels
fn render_ascii_edge_label(
  grid : @ascii.Grid,
  edge : Edge,
  config : AsciiConfig,
) -> Unit {
  if edge.label.length() > 0 {
    match edge.midpoint() {
      Some(mid) => {
        let mx = (mid.x / config.x_scale).to_int()
        let my = (mid.y / config.y_scale).to_int()
        let label = edge.label.replace(old=" ", new="─")
        grid.text(mx - label.length() / 2, my, label)
      }
      None => ()
    }
  }
}
