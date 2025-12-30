///|
/// Layout engine for D2 diagrams
///
/// Computes positions for objects and routes for edges.

///|
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Layout configuration
pub struct LayoutConfig {
  /// Horizontal spacing between objects
  horizontal_spacing : Double
  /// Vertical spacing between objects
  vertical_spacing : Double
  /// Padding inside containers
  container_padding : Double
  /// Default object width
  default_width : Double
  /// Default object height
  default_height : Double
  /// Edge padding from objects
  edge_padding : Double
} derive(Show)

///|
/// Layout direction
pub(all) enum Direction {
  Down
  Right
  Up
  Left
} derive(Eq, Show)

///|
/// Layout error
pub(all) suberror LayoutError {
  InvalidGraph(String)
  CycleDetected(String)
} derive(Eq, Show)

///|
pub fn LayoutConfig::new() -> LayoutConfig {
  {
    horizontal_spacing: 60.0,
    vertical_spacing: 40.0,
    container_padding: 20.0,
    default_width: 100.0,
    default_height: 60.0,
    edge_padding: 10.0,
  }
}

///|
pub fn LayoutConfig::with_spacing(
  horizontal : Double,
  vertical : Double,
) -> LayoutConfig {
  let config = LayoutConfig::new()
  { ..config, horizontal_spacing: horizontal, vertical_spacing: vertical }
}

///|
/// Perform layout on a graph
pub fn layout(
  graph : @graph.Graph,
  config : LayoutConfig,
  direction : Direction,
) -> Unit {
  // Phase 1: Compute sizes for all objects
  compute_sizes(graph, config)
  // Phase 2: Position objects based on hierarchy
  position_objects(graph, config, direction)
  // Phase 3: Route edges
  route_edges(graph, config)
}

///|
/// Compute sizes for all objects
fn compute_sizes(graph : @graph.Graph, config : LayoutConfig) -> Unit {
  for obj in graph.objects {
    compute_object_size(obj, config)
  }
}

///|
/// Compute size for a single object
fn compute_object_size(obj : @graph.Object, config : LayoutConfig) -> Unit {
  if obj.is_container() {
    // Container: compute based on children
    let mut max_width = 0.0
    let mut total_height = 0.0
    for child in obj.children {
      compute_object_size(child, config)
      match child.box {
        Some(b) => {
          if b.width > max_width {
            max_width = b.width
          }
          total_height = total_height + b.height + config.vertical_spacing
        }
        None => ()
      }
    }
    // Remove last spacing
    if total_height > 0.0 {
      total_height = total_height - config.vertical_spacing
    }
    // Add padding
    let width = max_width + config.container_padding * 2.0
    let height = total_height + config.container_padding * 2.0
    obj.set_box(
      @graph.Box::new(
        0.0,
        0.0,
        max(width, config.default_width),
        max(height, config.default_height),
      ),
    )
  } else {
    // Leaf node: use default size or compute from label
    let width = estimate_label_width(obj.label, config)
    let height = config.default_height
    obj.set_box(@graph.Box::new(0.0, 0.0, width, height))
  }
}

///|
/// Estimate width needed for a label
fn estimate_label_width(label : String, config : LayoutConfig) -> Double {
  // Simple estimation: 8 pixels per character + padding
  let char_width = 8.0
  let padding = 20.0
  let width = label.length().to_double() * char_width + padding
  max(width, config.default_width)
}

///|
/// Position objects in the graph
fn position_objects(
  graph : @graph.Graph,
  config : LayoutConfig,
  direction : Direction,
) -> Unit {
  // Find root objects (objects without parents)
  let roots = find_root_objects(graph)
  // Position each root and its subtree
  let mut x = config.container_padding
  let mut y = config.container_padding
  for root in roots {
    position_subtree(root, x, y, config, direction)
    match (root.box, direction) {
      // Down/Up: stack vertically (same x, different y)
      (Some(b), Down | Up) => y = y + b.height + config.vertical_spacing
      // Right/Left: stack horizontally (different x, same y)
      (Some(b), Right | Left) => x = x + b.width + config.horizontal_spacing
      (None, _) => ()
    }
  }
}

///|
/// Find objects that are not children of any other object
fn find_root_objects(graph : @graph.Graph) -> Array[@graph.Object] {
  let child_ids : Array[String] = []
  for obj in graph.objects {
    for child in obj.children {
      child_ids.push(child.id)
    }
  }
  let roots : Array[@graph.Object] = []
  for obj in graph.objects {
    if not(child_ids.contains(obj.id)) {
      roots.push(obj)
    }
  }
  roots
}

///|
/// Position an object and its children
fn position_subtree(
  obj : @graph.Object,
  x : Double,
  y : Double,
  config : LayoutConfig,
  direction : Direction,
) -> Unit {
  // Update object position
  match obj.box {
    Some(b) => obj.set_box(@graph.Box::new(x, y, b.width, b.height))
    None => ()
  }
  // Position children if this is a container
  if obj.is_container() {
    let child_x = x + config.container_padding
    let mut child_y = y + config.container_padding
    for child in obj.children {
      position_subtree(child, child_x, child_y, config, direction)
      match child.box {
        Some(b) => child_y = child_y + b.height + config.vertical_spacing
        None => ()
      }
    }
  }
}

///|
/// Route edges between objects
fn route_edges(graph : @graph.Graph, config : LayoutConfig) -> Unit {
  // Group edges by source to compute offsets
  let edges_by_src : Map[String, Array[@graph.Edge]] = {}
  for edge in graph.edges {
    let src_id = edge.get_src_id()
    match edges_by_src.get(src_id) {
      Some(arr) => arr.push(edge)
      None => edges_by_src[src_id] = [edge]
    }
  }
  // Route each edge with offset based on its position in source group
  for _, edges in edges_by_src {
    let count = edges.length()
    for i, edge in edges {
      route_edge(graph, edge, config, i, count)
    }
  }
}

///|
/// Route a single edge with offset for multiple edges from same source
fn route_edge(
  graph : @graph.Graph,
  edge : @graph.Edge,
  config : LayoutConfig,
  edge_index : Int,
  total_edges : Int,
) -> Unit {
  // Find source and destination objects
  let src = graph.find_object(edge.get_src_id())
  let dst = graph.find_object(edge.get_dst_id())
  match (src, dst) {
    (Some(src_obj), Some(dst_obj)) =>
      match (src_obj.get_box(), dst_obj.get_box()) {
        (Some(src_box), Some(dst_box)) => {
          // Calculate horizontal offset for multiple edges from same source
          let offset = if total_edges > 1 {
            let spacing = 15.0
            let total_width = (total_edges - 1).to_double() * spacing
            edge_index.to_double() * spacing - total_width / 2.0
          } else {
            0.0
          }
          let points = compute_connection_points(
            src_box, dst_box, config, offset,
          )
          for point in points {
            edge.add_route_point(point)
          }
        }
        _ => ()
      }
    _ => ()
  }
}

///|
/// Compute connection points between two boxes with optional horizontal offset
fn compute_connection_points(
  src : @graph.Box,
  dst : @graph.Box,
  _config : LayoutConfig,
  offset : Double,
) -> Array[@graph.Point] {
  // Apply horizontal offset to centers for edge routing
  let src_center = @graph.Point::new(
    src.center().get_x() + offset,
    src.center().get_y(),
  )
  let dst_center = @graph.Point::new(
    dst.center().get_x() + offset,
    dst.center().get_y(),
  )
  // Find edge intersection points
  let src_point = find_edge_intersection(src, src_center, dst_center)
  let dst_point = find_edge_intersection(dst, dst_center, src_center)
  [src_point, dst_point]
}

///|
/// Find where a line from center to target intersects the box edge
fn find_edge_intersection(
  box : @graph.Box,
  center : @graph.Point,
  target : @graph.Point,
) -> @graph.Point {
  let dx = target.x - center.x
  let dy = target.y - center.y
  if dx == 0.0 && dy == 0.0 {
    return center
  }
  // Calculate intersection with each edge
  let half_width = box.width / 2.0
  let half_height = box.height / 2.0
  // Scale factors for intersection with each edge
  let mut t = 1.0
  if dx != 0.0 {
    let tx = if dx > 0.0 { half_width / dx } else { -half_width / dx }
    if tx < t {
      t = tx
    }
  }
  if dy != 0.0 {
    let ty = if dy > 0.0 { half_height / dy } else { -half_height / dy }
    if ty < t {
      t = ty
    }
  }
  @graph.Point::new(center.x + dx * t, center.y + dy * t)
}
