// ============================================================================
// Virtual Node Positioning and Routing
// ============================================================================

///|
/// Position objects with virtual node support
/// Virtual nodes are positioned but not rendered - their positions are used for edge routing
fn position_objects_layered_with_virtual(
  graph : @graph.Graph,
  config : LayoutConfig,
  direction : Direction,
  virtual_result : VirtualNodeResult,
  crossing_result : CrossingResult,
  cycle_result : CycleBreakResult,
) -> Unit {
  let layer_result = virtual_result.layer_assignment
  // If only one layer, fall back to sequential layout
  if layer_result.layer_count <= 1 {
    position_objects_sequential(graph, config, direction)
    return
  }
  // Collect node dimensions (virtual nodes get minimal size)
  let node_widths : Map[String, Double] = {}
  let node_heights : Map[String, Double] = {}
  for layer in crossing_result.ordered_layers {
    for node_id in layer {
      if is_virtual_node(node_id) {
        // Virtual nodes have minimal size (just for routing)
        node_widths[node_id] = 1.0
        node_heights[node_id] = 1.0
      } else if graph.find_object(node_id) is Some(obj) {
        if obj.box is Some(b) {
          node_widths[node_id] = b.width
          node_heights[node_id] = b.height
        } else {
          node_widths[node_id] = config.default_width
          node_heights[node_id] = config.default_height
        }
      }
    }
  }
  // Assign coordinates using Brandes-Köpf algorithm
  let coords = assign_coordinates(
    graph,
    crossing_result,
    cycle_result,
    node_widths,
    node_heights,
    config.horizontal_spacing,
    config.vertical_spacing,
  )
  // Store virtual node positions in a map for edge routing
  // (Stored in the graph's edge metadata later)

  // Apply coordinates to real objects only
  for layer in crossing_result.ordered_layers {
    for node_id in layer {
      if is_virtual_node(node_id) {
        continue // Skip virtual nodes - they're just for routing
      }
      if graph.find_object(node_id) is Some(obj) && obj.box is Some(b) {
        let x = coords.x_coords.get(node_id).unwrap_or(0.0) +
          config.container_padding
        let y = coords.y_coords.get(node_id).unwrap_or(0.0) +
          config.container_padding
        match direction {
          Down | Up => obj.set_box(@graph.Box::new(x, y, b.width, b.height))
          Right | Left => obj.set_box(@graph.Box::new(y, x, b.width, b.height))
        }
      }
    }
  }
  // Note: Virtual node coordinates are calculated during edge routing
  // based on layer positions, so we don't need to store them here
  // Position children within containers
  for obj in graph.objects {
    if obj.is_container() {
      position_container_children(obj, config, direction)
    }
  }
}

// ============================================================================
// Port-Based Routing (Phase 7 with pre-assigned ports)
// ============================================================================

///|
/// Convert PortSide to string for compatibility with legacy routing code
fn port_side_to_side_string(side : @graph.PortSide) -> String {
  match side {
    @graph.Top => "top"
    @graph.Bottom => "bottom"
    @graph.Left => "left"
    @graph.Right => "right"
  }
}

///|
/// Check if a route respects the assigned port side at the destination
/// The final segment must approach from the correct direction
fn route_respects_dst_port(
  route : Array[@graph.Point],
  dst_side : @graph.PortSide,
) -> Bool {
  if route.length() < 2 {
    return true
  }
  let last_idx = route.length() - 1
  let p0 = route[last_idx - 1]
  let p1 = route[last_idx]
  let dx = (p1.x - p0.x).abs()
  let dy = (p1.y - p0.y).abs()
  let tolerance = 0.01
  match dst_side {
    @graph.Top | @graph.Bottom =>
      // Must approach vertically (dx ≈ 0)
      dx < tolerance || dx < dy * 0.01
    @graph.Left | @graph.Right =>
      // Must approach horizontally (dy ≈ 0)
      dy < tolerance || dy < dx * 0.01
  }
}

///|
/// Check if a route respects the assigned port side at the source
/// The first segment must depart in the correct direction
fn route_respects_src_port(
  route : Array[@graph.Point],
  src_side : @graph.PortSide,
) -> Bool {
  if route.length() < 2 {
    return true
  }
  let p0 = route[0]
  let p1 = route[1]
  let dx = (p1.x - p0.x).abs()
  let dy = (p1.y - p0.y).abs()
  let tolerance = 0.01
  match src_side {
    @graph.Top | @graph.Bottom =>
      // Must depart vertically (dx ≈ 0)
      dx < tolerance || dx < dy * 0.01
    @graph.Left | @graph.Right =>
      // Must depart horizontally (dy ≈ 0)
      dy < tolerance || dy < dx * 0.01
  }
}

///|
/// Route edges using pre-assigned ports
/// This guarantees perpendicular connections since ports are on node sides
pub fn route_edges_with_ports(
  graph : @graph.Graph,
  _config : LayoutConfig,
  virtual_result : VirtualNodeResult,
) -> Unit {
  // Track parallel edge counts for offset calculation
  let edge_counts : Map[String, Int] = {}
  for edge in graph.edges {
    // Clear existing route
    edge.route.clear()
    // Handle self-loops specially
    if edge.src_id == edge.dst_id {
      let src_obj = graph.find_object(edge.src_id)
      guard src_obj is Some(src) else { continue }
      guard src.box is Some(box) else { continue }
      route_self_loop(edge, box)
      continue
    }
    // Calculate parallel edge offset
    let edge_key = if edge.src_id < edge.dst_id {
      edge.src_id + "->" + edge.dst_id
    } else {
      edge.dst_id + "->" + edge.src_id
    }
    let edge_index = edge_counts.get(edge_key).unwrap_or(0)
    edge_counts[edge_key] = edge_index + 1
    // Check if this edge has pre-assigned ports with computed points
    let use_port_routing = match (edge.src_port, edge.dst_port) {
      (Some(src_port), Some(dst_port)) =>
        match (src_port.point, dst_port.point) {
          (Some(_), Some(_)) => {
            // Use port-based routing (guarantees perpendicular connections)
            route_edge_with_ports(edge, src_port, dst_port, graph, edge_index)
            true
          }
          _ => false // Fall through to legacy routing
        }
      _ => false
    }
    if use_port_routing {
      continue
    }
    // Fallback to legacy routing for edges without ports
    let (src_box, src_num_cols, dst_box, dst_num_cols) = match
      get_sql_table_boxes(graph, edge) {
      Some(boxes) => boxes
      None => {
        let src_obj = graph.find_object(edge.src_id)
        let dst_obj = graph.find_object(edge.dst_id)
        if src_obj is None || dst_obj is None {
          continue
        }
        let src = src_obj.unwrap()
        let dst = dst_obj.unwrap()
        if src.box is None || dst.box is None {
          continue
        }
        (src.box.unwrap(), 0, dst.box.unwrap(), 0)
      }
    }
    // Check if this edge has virtual nodes
    if virtual_result.edge_virtual_nodes.get(edge.index) is Some(virtual_ids) &&
      virtual_ids.length() > 0 {
      route_edge_through_virtual_sql(
        edge, src_box, dst_box, virtual_ids, virtual_result, src_num_cols, dst_num_cols,
        edge_index,
      )
    } else {
      route_direct_edge_sql_parallel(
        edge, src_box, dst_box, src_num_cols, dst_num_cols, edge_index,
      )
    }
  }
}

///|
/// Route an edge using pre-assigned ports
/// Creates an orthogonal route that respects port sides
fn route_edge_with_ports(
  edge : @graph.Edge,
  src_port : @graph.Port,
  dst_port : @graph.Port,
  _graph : @graph.Graph,
  parallel_index : Int,
) -> Unit {
  // Get port points
  let src_point = match src_port.point {
    Some(p) => p
    None => return // Port not computed yet
  }
  let dst_point = match dst_port.point {
    Some(p) => p
    None => return // Port not computed yet
  }
  // Calculate parallel offset for multiple edges
  let offset_amount = 15.0
  let offset = if parallel_index == 0 {
    0.0
  } else {
    let sign = if parallel_index % 2 == 1 { 1.0 } else { -1.0 }
    sign * ((parallel_index + 1) / 2).to_double() * offset_amount
  }
  // Create orthogonal route based on port sides
  let route = create_orthogonal_route_from_ports(
    src_point,
    dst_point,
    src_port.side,
    dst_port.side,
    offset,
  )
  // Apply route to edge
  for pt in route {
    edge.route.push(pt)
  }
}

///|
/// Create an orthogonal route between two ports
/// The first segment is perpendicular to src_side
/// The last segment is perpendicular to dst_side
/// IMPORTANT: Endpoints are kept exactly on port points to ensure perpendicularity.
/// Offset is applied to middle segments only for parallel edge separation.
fn create_orthogonal_route_from_ports(
  src : @graph.Point,
  dst : @graph.Point,
  src_side : @graph.PortSide,
  dst_side : @graph.PortSide,
  offset : Double,
) -> Array[@graph.Point] {
  let route : Array[@graph.Point] = []
  // Keep source exactly on the port point (on node boundary)
  route.push(src)
  // Determine routing based on port sides
  // For orthogonal routes, offset is applied to the middle segment coordinate
  match (src_side, dst_side) {
    (@graph.Top, @graph.Top) | (@graph.Bottom, @graph.Bottom) => {
      // Both vertical sides - need horizontal middle segment
      // Offset applied to mid_y for parallel edge separation
      let mid_y = (src.y + dst.y) / 2.0 + offset
      route.push(@graph.Point::new(src.x, mid_y))
      route.push(@graph.Point::new(dst.x, mid_y))
    }
    (@graph.Top, @graph.Bottom) =>
      // Source exits top, destination enters from bottom
      if src.y > dst.y {
        // src is below dst - need horizontal detour
        let mid_x = (src.x + dst.x) / 2.0 + offset
        route.push(@graph.Point::new(src.x, src.y - 30.0))
        route.push(@graph.Point::new(mid_x, src.y - 30.0))
        route.push(@graph.Point::new(mid_x, dst.y + 30.0))
        route.push(@graph.Point::new(dst.x, dst.y + 30.0))
      } else {
        // Direct vertical connection possible
        let mid_y = (src.y + dst.y) / 2.0 + offset
        route.push(@graph.Point::new(src.x, mid_y))
        route.push(@graph.Point::new(dst.x, mid_y))
      }
    (@graph.Bottom, @graph.Top) =>
      // Source exits bottom, destination enters from top
      // This is the typical case in Sugiyama layout (downward flow)
      if src.y < dst.y {
        // Direct vertical connection possible
        let mid_y = (src.y + dst.y) / 2.0 + offset
        route.push(@graph.Point::new(src.x, mid_y))
        route.push(@graph.Point::new(dst.x, mid_y))
      } else {
        // src is below dst - need horizontal detour
        let mid_x = (src.x + dst.x) / 2.0 + offset
        route.push(@graph.Point::new(src.x, src.y + 30.0))
        route.push(@graph.Point::new(mid_x, src.y + 30.0))
        route.push(@graph.Point::new(mid_x, dst.y - 30.0))
        route.push(@graph.Point::new(dst.x, dst.y - 30.0))
      }
    (@graph.Left, @graph.Left) | (@graph.Right, @graph.Right) => {
      // Both horizontal sides - need vertical middle segment
      // Offset applied to mid_x for parallel edge separation
      let mid_x = (src.x + dst.x) / 2.0 + offset
      route.push(@graph.Point::new(mid_x, src.y))
      route.push(@graph.Point::new(mid_x, dst.y))
    }
    (@graph.Left, @graph.Right) =>
      // Source exits left, destination enters from right
      if src.x > dst.x {
        // Direct horizontal connection possible
        let mid_x = (src.x + dst.x) / 2.0 + offset
        route.push(@graph.Point::new(mid_x, src.y))
        route.push(@graph.Point::new(mid_x, dst.y))
      } else {
        // src is to the left of dst - need vertical detour
        let mid_y = (src.y + dst.y) / 2.0 + offset
        route.push(@graph.Point::new(src.x - 30.0, src.y))
        route.push(@graph.Point::new(src.x - 30.0, mid_y))
        route.push(@graph.Point::new(dst.x + 30.0, mid_y))
        route.push(@graph.Point::new(dst.x + 30.0, dst.y))
      }
    (@graph.Right, @graph.Left) =>
      // Source exits right, destination enters from left
      if src.x < dst.x {
        // Direct horizontal connection possible
        let mid_x = (src.x + dst.x) / 2.0 + offset
        route.push(@graph.Point::new(mid_x, src.y))
        route.push(@graph.Point::new(mid_x, dst.y))
      } else {
        // src is to the right of dst - need vertical detour
        let mid_y = (src.y + dst.y) / 2.0 + offset
        route.push(@graph.Point::new(src.x + 30.0, src.y))
        route.push(@graph.Point::new(src.x + 30.0, mid_y))
        route.push(@graph.Point::new(dst.x - 30.0, mid_y))
        route.push(@graph.Point::new(dst.x - 30.0, dst.y))
      }
    (@graph.Top, @graph.Left) | (@graph.Top, @graph.Right) =>
      // L-shape: vertical then horizontal
      route.push(@graph.Point::new(src.x, dst.y))
    (@graph.Bottom, @graph.Left) | (@graph.Bottom, @graph.Right) =>
      // L-shape: vertical then horizontal
      route.push(@graph.Point::new(src.x, dst.y))
    (@graph.Left, @graph.Top) | (@graph.Left, @graph.Bottom) =>
      // L-shape: horizontal then vertical
      route.push(@graph.Point::new(dst.x, src.y))
    (@graph.Right, @graph.Top) | (@graph.Right, @graph.Bottom) =>
      // L-shape: horizontal then vertical
      route.push(@graph.Point::new(dst.x, src.y))
  }
  // Keep destination exactly on the port point (on node boundary)
  route.push(dst)
  route
}

///|
/// Route a self-loop edge (where source and destination are the same node)
fn route_self_loop(edge : @graph.Edge, box : @graph.Box) -> Unit {
  // Create a loop that goes out from the right side, curves up/right, and comes back
  let loop_size = 30.0
  let right = box.x + box.width
  let top = box.y
  let center_y = box.y + box.height / 2.0
  // Start from right side, slightly above center
  let start_x = right
  let start_y = center_y - 10.0
  // End at right side, slightly below center
  let end_x = right
  let end_y = center_y + 10.0
  // Control points for the loop
  let ctrl1_x = right + loop_size
  let ctrl1_y = start_y - loop_size
  let ctrl2_x = right + loop_size * 1.5
  let ctrl2_y = top - loop_size
  let ctrl3_x = right + loop_size
  let ctrl3_y = end_y + loop_size
  // Add route points
  edge.add_route_point(@graph.Point::new(start_x, start_y))
  edge.add_route_point(@graph.Point::new(ctrl1_x, ctrl1_y))
  edge.add_route_point(@graph.Point::new(ctrl2_x, ctrl2_y))
  edge.add_route_point(@graph.Point::new(ctrl3_x, ctrl3_y))
  edge.add_route_point(@graph.Point::new(end_x, end_y))
}

///|
/// Get SQL table boxes for an edge with column indices
/// Returns (src_box, src_num_cols, dst_box, dst_num_cols) if applicable
fn get_sql_table_boxes(
  graph : @graph.Graph,
  edge : @graph.Edge,
) -> (@graph.Box, Int, @graph.Box, Int)? {
  // Get source box (either from parent table or direct object)
  let (src_box, src_num_cols) = if edge.src_column_index is Some(_) {
    // Find parent SQL table
    let parent_id = match get_parent_id_from_field(edge.src_id) {
      Some(p) => p
      None => return None
    }
    let parent = match graph.find_object(parent_id) {
      Some(p) => p
      None => return None
    }
    if parent.box is None {
      return None
    }
    (parent.box.unwrap(), parent.children.length())
  } else {
    let obj = match graph.find_object(edge.src_id) {
      Some(o) => o
      None => return None
    }
    if obj.box is None {
      return None
    }
    (obj.box.unwrap(), 0)
  }
  // Get destination box (either from parent table or direct object)
  let (dst_box, dst_num_cols) = if edge.dst_column_index is Some(_) {
    // Find parent SQL table
    let parent_id = match get_parent_id_from_field(edge.dst_id) {
      Some(p) => p
      None => return None
    }
    let parent = match graph.find_object(parent_id) {
      Some(p) => p
      None => return None
    }
    if parent.box is None {
      return None
    }
    (parent.box.unwrap(), parent.children.length())
  } else {
    let obj = match graph.find_object(edge.dst_id) {
      Some(o) => o
      None => return None
    }
    if obj.box is None {
      return None
    }
    (obj.box.unwrap(), 0)
  }
  Some((src_box, src_num_cols, dst_box, dst_num_cols))
}

///|
/// Route an edge through virtual nodes with SQL table support
fn route_edge_through_virtual_sql(
  edge : @graph.Edge,
  src_box : @graph.Box,
  dst_box : @graph.Box,
  _virtual_ids : Array[String],
  _virtual_result : VirtualNodeResult,
  src_num_cols : Int,
  dst_num_cols : Int,
  parallel_index : Int,
) -> Unit {
  // Calculate parallel offset (alternate left/right)
  let offset_amount = 15.0 // Pixels between parallel edges
  let offset = if parallel_index == 0 {
    0.0
  } else {
    let sign = if parallel_index % 2 == 1 { 1.0 } else { -1.0 }
    sign * ((parallel_index + 1) / 2).to_double() * offset_amount
  }

  // Check if this is an SQL table edge
  let is_sql_src = edge.src_column_index is Some(_) && src_num_cols > 0
  let is_sql_dst = edge.dst_column_index is Some(_) && dst_num_cols > 0
  let is_sql_edge = is_sql_src || is_sql_dst

  // Port constraint approach for SQL tables:
  // - Source column connections use RIGHT side (srcSide = East)
  // - Destination column connections use LEFT side (dstSide = West)
  // Calculate best anchors based on relative positions if not specified
  let (default_src_anchor, default_dst_anchor) = calculate_best_anchors(
    src_box, dst_box,
  )
  let src_point = if edge.src_column_index is Some(col_idx) && src_num_cols > 0 {
    get_sql_row_anchor_point(src_box, col_idx, src_num_cols, false)
  } else {
    let src_anchor = edge.src_anchor.unwrap_or(default_src_anchor)
    get_anchor_point(src_box, src_anchor, offset)
  }
  let dst_point = if edge.dst_column_index is Some(col_idx) && dst_num_cols > 0 {
    get_sql_row_anchor_point(dst_box, col_idx, dst_num_cols, true)
  } else {
    let dst_anchor = edge.dst_anchor.unwrap_or(default_dst_anchor)
    get_anchor_point(dst_box, dst_anchor, offset)
  }
  if is_sql_edge {
    // SQL table edge: simple 4-point zig-zag
    let mid_x = (src_point.x + dst_point.x) / 2.0 + offset
    edge.route.push(src_point)
    edge.route.push(@graph.Point::new(mid_x, src_point.y))
    edge.route.push(@graph.Point::new(mid_x, dst_point.y))
    edge.route.push(dst_point)
  } else {
    // Regular edge: use orthogonal routing that respects anchor direction
    // The final segment must approach from the correct direction for the anchor
    let dst_anchor = edge.dst_anchor.unwrap_or(default_dst_anchor)
    let is_vertical_anchor = dst_anchor == "top" || dst_anchor == "bottom"
    edge.route.push(src_point)
    if is_vertical_anchor {
      // Vertical approach: route horizontally first, then vertically to dst
      let mid_y = (src_point.y + dst_point.y) / 2.0
      if (src_point.x - dst_point.x).abs() > 1.0 {
        edge.route.push(@graph.Point::new(src_point.x, mid_y))
        edge.route.push(@graph.Point::new(dst_point.x, mid_y))
      }
    } else {
      // Horizontal approach: route vertically first, then horizontally to dst
      let mid_x = (src_point.x + dst_point.x) / 2.0
      if (src_point.y - dst_point.y).abs() > 1.0 {
        edge.route.push(@graph.Point::new(mid_x, src_point.y))
        edge.route.push(@graph.Point::new(mid_x, dst_point.y))
      }
    }
    edge.route.push(dst_point)
  }
}

///|
/// Route a direct edge with SQL table support and parallel edge offset
fn route_direct_edge_sql_parallel(
  edge : @graph.Edge,
  src_box : @graph.Box,
  dst_box : @graph.Box,
  src_num_cols : Int,
  dst_num_cols : Int,
  parallel_index : Int,
) -> Unit {
  // Check if this is an SQL table edge
  let is_sql_src = edge.src_column_index is Some(_) && src_num_cols > 0
  let is_sql_dst = edge.dst_column_index is Some(_) && dst_num_cols > 0
  let is_sql_edge = is_sql_src || is_sql_dst
  // Calculate parallel offset (alternate left/right)
  let offset_amount = 15.0 // Pixels between parallel edges
  let offset = if parallel_index == 0 {
    0.0
  } else {
    let sign = if parallel_index % 2 == 1 { 1.0 } else { -1.0 }
    sign * ((parallel_index + 1) / 2).to_double() * offset_amount
  }
  // Port constraint approach for SQL tables:
  // - Source column connections use RIGHT side (srcSide = East)
  // - Destination column connections use LEFT side (dstSide = West)
  // Calculate best anchors based on relative positions if not specified
  let (default_src_anchor, default_dst_anchor) = calculate_best_anchors(
    src_box, dst_box,
  )
  let src_point = if edge.src_column_index is Some(col_idx) && src_num_cols > 0 {
    get_sql_row_anchor_point(src_box, col_idx, src_num_cols, false)
  } else {
    let src_anchor = edge.src_anchor.unwrap_or(default_src_anchor)
    get_anchor_point(src_box, src_anchor, offset)
  }
  let dst_point = if edge.dst_column_index is Some(col_idx) && dst_num_cols > 0 {
    get_sql_row_anchor_point(dst_box, col_idx, dst_num_cols, true)
  } else {
    let dst_anchor = edge.dst_anchor.unwrap_or(default_dst_anchor)
    get_anchor_point(dst_box, dst_anchor, offset)
  }
  if is_sql_edge {
    // SQL table edge: simple 4-point zig-zag
    // The railroad path builder will add rounded corners at the 2 turns
    let mid_x = (src_point.x + dst_point.x) / 2.0 + offset
    edge.route.push(src_point)
    edge.route.push(@graph.Point::new(mid_x, src_point.y))
    edge.route.push(@graph.Point::new(mid_x, dst_point.y))
    edge.route.push(dst_point)
  } else if parallel_index > 0 {
    // Parallel edge: use orthogonal L-shape routing (offset is in anchor points)
    // The approach direction must match the anchor side
    let is_vertical_anchor = default_dst_anchor == "top" ||
      default_dst_anchor == "bottom"
    edge.route.push(src_point)
    if is_vertical_anchor {
      // Vertical approach: L-shape with horizontal first, then vertical to dst
      if (src_point.x - dst_point.x).abs() > 1.0 {
        edge.route.push(@graph.Point::new(dst_point.x, src_point.y))
      }
      // Horizontal approach: L-shape with vertical first, then horizontal to dst
    } else if (src_point.y - dst_point.y).abs() > 1.0 {
      edge.route.push(@graph.Point::new(src_point.x, dst_point.y))
    }
    edge.route.push(dst_point)
  } else {
    // Regular edge: use orthogonal routing to ensure correct approach direction
    // The final segment must approach from the direction matching the anchor side
    let is_vertical_anchor = default_dst_anchor == "top" ||
      default_dst_anchor == "bottom"
    edge.route.push(src_point)
    if is_vertical_anchor {
      // Vertical approach needed: route to dst's x first, then vertically to dst
      if (src_point.x - dst_point.x).abs() > 1.0 {
        edge.route.push(@graph.Point::new(dst_point.x, src_point.y))
      }
      // Horizontal approach needed: route to dst's y first, then horizontally to dst
    } else if (src_point.y - dst_point.y).abs() > 1.0 {
      edge.route.push(@graph.Point::new(src_point.x, dst_point.y))
    }
    edge.route.push(dst_point)
  }
}

// ============================================================================
// Obstacle Avoidance Routing
// ============================================================================

///|
/// Compute bounding box of all objects in the graph
/// Returns (min_x, min_y, max_x, max_y)
fn compute_all_bounds(graph : @graph.Graph) -> (Double, Double, Double, Double) {
  let mut min_x = 1.0e10
  let mut min_y = 1.0e10
  let mut max_x = -1.0e10
  let mut max_y = -1.0e10
  for obj in graph.objects {
    guard obj.box is Some(box) else { continue }
    if box.x < min_x {
      min_x = box.x
    }
    if box.y < min_y {
      min_y = box.y
    }
    if box.x + box.width > max_x {
      max_x = box.x + box.width
    }
    if box.y + box.height > max_y {
      max_y = box.y + box.height
    }
  }
  (min_x, min_y, max_x, max_y)
}

///|
/// Normalize coordinates to ensure all elements have non-negative positions
/// This shifts the entire graph if any element has negative coordinates
fn normalize_coordinates(graph : @graph.Graph) -> Unit {
  // Find minimum x and y across all elements (nodes and edge routes)
  let mut min_x = 0.0
  let mut min_y = 0.0
  // Check object boxes
  for obj in graph.objects {
    if obj.box is Some(box) {
      if box.x < min_x {
        min_x = box.x
      }
      if box.y < min_y {
        min_y = box.y
      }
    }
  }
  // Check edge route points
  for edge in graph.edges {
    for pt in edge.route {
      if pt.x < min_x {
        min_x = pt.x
      }
      if pt.y < min_y {
        min_y = pt.y
      }
    }
    // Check edge label positions
    if edge.label_box is Some(lb) {
      if lb.x < min_x {
        min_x = lb.x
      }
      if lb.y < min_y {
        min_y = lb.y
      }
    }
  }
  // If everything is already non-negative, nothing to do
  if min_x >= 0.0 && min_y >= 0.0 {
    return
  }
  // Calculate shift amounts
  let shift_x = if min_x < 0.0 { -min_x } else { 0.0 }
  let shift_y = if min_y < 0.0 { -min_y } else { 0.0 }
  // Shift all object boxes
  for obj in graph.objects {
    if obj.box is Some(box) {
      obj.box = Some(
        @graph.Box::new(box.x + shift_x, box.y + shift_y, box.width, box.height),
      )
    }
  }
  // Shift all edge route points
  for edge in graph.edges {
    for i = 0; i < edge.route.length(); i = i + 1 {
      let pt = edge.route[i]
      edge.route[i] = @graph.Point::new(pt.x + shift_x, pt.y + shift_y)
    }
    // Shift edge label positions
    if edge.label_box is Some(lb) {
      edge.label_box = Some(
        @graph.Box::new(lb.x + shift_x, lb.y + shift_y, lb.width, lb.height),
      )
    }
  }
}

///|
/// Route edges around obstacles (objects that would be intersected)
fn route_around_obstacles(graph : @graph.Graph) -> Unit {
  // Compute canvas bounds once for fallback routing
  let canvas_bounds = compute_all_bounds(graph)
  for edge in graph.edges {
    route_edge_around_obstacles(edge, graph, canvas_bounds)
  }
}

///|
/// Route a single edge around any obstacles it would intersect
/// Uses quality-first approach with canvas-edge fallback
fn route_edge_around_obstacles(
  edge : @graph.Edge,
  graph : @graph.Graph,
  canvas_bounds : (Double, Double, Double, Double),
) -> Unit {
  // Skip SQL table field-to-field edges - they use a zig-zag route that
  // naturally avoids obstacles (the vertical segment is between tables)
  if edge.src_column_index is Some(_) || edge.dst_column_index is Some(_) {
    return
  }
  // Skip edges without routes
  if edge.route.length() < 2 {
    return
  }
  // Quality-first: iterate until no more intersections (max 50 iterations)
  let max_iterations = 50
  let mut iteration = 0
  while iteration < max_iterations {
    let obstacle = find_intersecting_obstacle(edge, graph)
    if obstacle is None {
      return // Success - no more obstacles
    }
    let obs_box = obstacle.unwrap()
    // Try to reroute around the obstacle
    let success = reroute_around_obstacle_with_fallback(
      edge, obs_box, graph, canvas_bounds,
    )
    if !success {
      // Local bypass failed - use canvas edge fallback
      route_via_canvas_edge(edge, graph, canvas_bounds)
      return
    }
    iteration = iteration + 1
  }
  // Max iterations reached - use canvas edge fallback
  route_via_canvas_edge(edge, graph, canvas_bounds)
}

///|
/// Route edge around the canvas perimeter when local bypasses fail
/// Uses complete U-shaped routes that respect endpoint approach direction
/// Tries multiple margin sizes until a valid route is found
/// IMPORTANT: Uses assigned port sides from Phase 6.5 to guarantee perpendicularity
fn route_via_canvas_edge(
  edge : @graph.Edge,
  graph : @graph.Graph,
  canvas_bounds : (Double, Double, Double, Double),
) -> Unit {
  let (min_x, min_y, max_x, max_y) = canvas_bounds
  // Get source and destination points
  if edge.route.length() < 2 {
    return
  }
  let src = edge.route[0]
  let dst = edge.route[edge.route.length() - 1]

  // Use assigned port sides from Phase 6.5 (port assignment)
  // This ensures perpendicularity is maintained even after obstacle avoidance
  let src_side_opt : @graph.PortSide? = match edge.src_port {
    Some(p) => Some(p.side)
    None => None
  }
  let dst_side_opt : @graph.PortSide? = match edge.dst_port {
    Some(p) => Some(p.side)
    None => None
  }

  // Determine endpoint sides - prefer assigned ports, fallback to geometric detection
  let dst_obj = graph.find_object(edge.dst_id)
  let endpoint_side = match dst_side_opt {
    Some(side) => port_side_to_side_string(side)
    None =>
      match dst_obj {
        Some(obj) =>
          match obj.box {
            Some(box) => get_endpoint_side(dst, box, 2.0)
            None => "none"
          }
        None => "none"
      }
  }
  let src_obj = graph.find_object(edge.src_id)
  let src_side_str = match src_side_opt {
    Some(side) => port_side_to_side_string(side)
    None =>
      match src_obj {
        Some(obj) =>
          match obj.box {
            Some(box) => get_endpoint_side(src, box, 2.0)
            None => "none"
          }
        None => "none"
      }
  }

  // Try multiple margins until we find a valid route
  let margins = [30.0, 60.0, 100.0, 150.0, 200.0]
  for margin in margins {
    let left = min_x - margin
    let right = max_x + margin
    let top = min_y - margin
    let bottom = max_y + margin
    // First, try port-aware routes that respect both source and destination sides
    let port_aware_routes = create_canvas_edge_routes_port_aware(
      src, dst, src_side_str, endpoint_side, left, right, top, bottom,
    )
    for route in port_aware_routes {
      if is_bypass_valid(src, route, dst, edge, graph) {
        let full_route : Array[@graph.Point] = [src]
        for pt in route {
          full_route.push(pt)
        }
        full_route.push(dst)
        // Check perpendicularity only if we have assigned ports
        let src_ok = match src_side_opt {
          Some(side) => route_respects_src_port(full_route, side)
          None => true
        }
        let dst_ok = match dst_side_opt {
          Some(side) => route_respects_dst_port(full_route, side)
          None => true
        }
        if src_ok && dst_ok {
          edge.route.clear()
          for pt in full_route {
            edge.route.push(pt)
          }
          return
        }
      }
    }
    // Fall back to legacy routes (endpoint_side only) if port-aware routes fail
    let legacy_routes = create_canvas_edge_routes(
      src, dst, endpoint_side, left, right, top, bottom,
    )
    for route in legacy_routes {
      if is_bypass_valid(src, route, dst, edge, graph) {
        edge.route.clear()
        edge.route.push(src)
        for pt in route {
          edge.route.push(pt)
        }
        edge.route.push(dst)
        return
      }
    }
  }
  // If no valid route found at any margin, try a complete maze-router fallback.
  // This is slower but avoids leaving an intersecting route behind.
  let _ = route_via_maze_router(edge, graph, canvas_bounds)

}

///|
/// Create canvas edge routes that respect BOTH source and destination port sides
/// This ensures perpendicularity is maintained at both endpoints
fn create_canvas_edge_routes_port_aware(
  src : @graph.Point,
  dst : @graph.Point,
  src_side : String,
  dst_side : String,
  left : Double,
  right : Double,
  top : Double,
  bottom : Double,
) -> Array[Array[@graph.Point]] {
  let routes : Array[Array[@graph.Point]] = []

  // Generate routes based on the combination of source and destination sides
  // The key insight: we need to create routes where:
  // - First segment from src is perpendicular to src_side
  // - Last segment to dst is perpendicular to dst_side

  match (src_side, dst_side) {
    ("bottom", "top") => {
      // Normal downward flow: src exits bottom, dst enters from top
      // Route goes down from src, then up to dst via canvas edge
      routes.push([
        @graph.Point::new(src.x, bottom),
        @graph.Point::new(left, bottom),
        @graph.Point::new(left, top),
        @graph.Point::new(dst.x, top),
      ])
      routes.push([
        @graph.Point::new(src.x, bottom),
        @graph.Point::new(right, bottom),
        @graph.Point::new(right, top),
        @graph.Point::new(dst.x, top),
      ])
    }
    ("top", "bottom") => {
      // Upward flow: src exits top, dst enters from bottom
      routes.push([
        @graph.Point::new(src.x, top),
        @graph.Point::new(left, top),
        @graph.Point::new(left, bottom),
        @graph.Point::new(dst.x, bottom),
      ])
      routes.push([
        @graph.Point::new(src.x, top),
        @graph.Point::new(right, top),
        @graph.Point::new(right, bottom),
        @graph.Point::new(dst.x, bottom),
      ])
    }
    ("right", "left") => {
      // Horizontal flow: src exits right, dst enters from left
      routes.push([
        @graph.Point::new(right, src.y),
        @graph.Point::new(right, top),
        @graph.Point::new(left, top),
        @graph.Point::new(left, dst.y),
      ])
      routes.push([
        @graph.Point::new(right, src.y),
        @graph.Point::new(right, bottom),
        @graph.Point::new(left, bottom),
        @graph.Point::new(left, dst.y),
      ])
    }
    ("left", "right") => {
      // Reverse horizontal: src exits left, dst enters from right
      routes.push([
        @graph.Point::new(left, src.y),
        @graph.Point::new(left, top),
        @graph.Point::new(right, top),
        @graph.Point::new(right, dst.y),
      ])
      routes.push([
        @graph.Point::new(left, src.y),
        @graph.Point::new(left, bottom),
        @graph.Point::new(right, bottom),
        @graph.Point::new(right, dst.y),
      ])
    }
    ("bottom", "bottom") => {
      // Both exit/enter from bottom
      routes.push([
        @graph.Point::new(src.x, bottom),
        @graph.Point::new(dst.x, bottom),
      ])
      routes.push([
        @graph.Point::new(src.x, bottom),
        @graph.Point::new(left, bottom),
        @graph.Point::new(left, bottom - 30.0),
        @graph.Point::new(dst.x, bottom - 30.0),
        @graph.Point::new(dst.x, bottom),
      ])
    }
    ("top", "top") => {
      // Both exit/enter from top
      routes.push([@graph.Point::new(src.x, top), @graph.Point::new(dst.x, top)])
      routes.push([
        @graph.Point::new(src.x, top),
        @graph.Point::new(left, top),
        @graph.Point::new(left, top + 30.0),
        @graph.Point::new(dst.x, top + 30.0),
        @graph.Point::new(dst.x, top),
      ])
    }
    ("left", "left") =>
      // Both exit/enter from left
      routes.push([
        @graph.Point::new(left, src.y),
        @graph.Point::new(left, dst.y),
      ])
    ("right", "right") =>
      // Both exit/enter from right
      routes.push([
        @graph.Point::new(right, src.y),
        @graph.Point::new(right, dst.y),
      ])
    // Mixed vertical/horizontal cases
    ("bottom", "left") =>
      routes.push([
        @graph.Point::new(src.x, bottom),
        @graph.Point::new(left, bottom),
        @graph.Point::new(left, dst.y),
      ])
    ("bottom", "right") =>
      routes.push([
        @graph.Point::new(src.x, bottom),
        @graph.Point::new(right, bottom),
        @graph.Point::new(right, dst.y),
      ])
    ("top", "left") =>
      routes.push([
        @graph.Point::new(src.x, top),
        @graph.Point::new(left, top),
        @graph.Point::new(left, dst.y),
      ])
    ("top", "right") =>
      routes.push([
        @graph.Point::new(src.x, top),
        @graph.Point::new(right, top),
        @graph.Point::new(right, dst.y),
      ])
    ("left", "top") =>
      routes.push([
        @graph.Point::new(left, src.y),
        @graph.Point::new(left, top),
        @graph.Point::new(dst.x, top),
      ])
    ("left", "bottom") =>
      routes.push([
        @graph.Point::new(left, src.y),
        @graph.Point::new(left, bottom),
        @graph.Point::new(dst.x, bottom),
      ])
    ("right", "top") =>
      routes.push([
        @graph.Point::new(right, src.y),
        @graph.Point::new(right, top),
        @graph.Point::new(dst.x, top),
      ])
    ("right", "bottom") =>
      routes.push([
        @graph.Point::new(right, src.y),
        @graph.Point::new(right, bottom),
        @graph.Point::new(dst.x, bottom),
      ])
    _ =>
      // Fallback: use legacy route generation
      return create_canvas_edge_routes(
        src, dst, dst_side, left, right, top, bottom,
      )
  }
  routes
}

///|
/// Create canvas edge routes for a given endpoint side
/// Routes go via corners to avoid intersecting objects on connecting segments
fn create_canvas_edge_routes(
  src : @graph.Point,
  dst : @graph.Point,
  endpoint_side : String,
  left : Double,
  right : Double,
  top : Double,
  bottom : Double,
) -> Array[Array[@graph.Point]] {
  let routes : Array[Array[@graph.Point]] = []
  if endpoint_side == "top" {
    // Must approach from ABOVE (dy > 0) - route via top of canvas
    // Via top-left corner (safest - goes to corner first)
    routes.push([
      @graph.Point::new(left, src.y),
      @graph.Point::new(left, top),
      @graph.Point::new(dst.x, top),
    ])
    // Via top-right corner
    routes.push([
      @graph.Point::new(right, src.y),
      @graph.Point::new(right, top),
      @graph.Point::new(dst.x, top),
    ])
    // Direct via top (may intersect if objects above src)
    routes.push([@graph.Point::new(src.x, top), @graph.Point::new(dst.x, top)])
  } else if endpoint_side == "bottom" {
    // Must approach from BELOW (dy < 0) - route via bottom of canvas
    // Via bottom-left corner
    routes.push([
      @graph.Point::new(left, src.y),
      @graph.Point::new(left, bottom),
      @graph.Point::new(dst.x, bottom),
    ])
    // Via bottom-right corner
    routes.push([
      @graph.Point::new(right, src.y),
      @graph.Point::new(right, bottom),
      @graph.Point::new(dst.x, bottom),
    ])
    // Direct via bottom
    routes.push([
      @graph.Point::new(src.x, bottom),
      @graph.Point::new(dst.x, bottom),
    ])
  } else if endpoint_side == "left" {
    // Must approach from LEFT (dx > 0) - route via left of canvas
    // Via top-left corner
    routes.push([
      @graph.Point::new(src.x, top),
      @graph.Point::new(left, top),
      @graph.Point::new(left, dst.y),
    ])
    // Via bottom-left corner
    routes.push([
      @graph.Point::new(src.x, bottom),
      @graph.Point::new(left, bottom),
      @graph.Point::new(left, dst.y),
    ])
    // Direct via left
    routes.push([@graph.Point::new(left, src.y), @graph.Point::new(left, dst.y)])
  } else if endpoint_side == "right" {
    // Must approach from RIGHT (dx < 0) - route via right of canvas
    // Via top-right corner
    routes.push([
      @graph.Point::new(src.x, top),
      @graph.Point::new(right, top),
      @graph.Point::new(right, dst.y),
    ])
    // Via bottom-right corner
    routes.push([
      @graph.Point::new(src.x, bottom),
      @graph.Point::new(right, bottom),
      @graph.Point::new(right, dst.y),
    ])
    // Direct via right
    routes.push([
      @graph.Point::new(right, src.y),
      @graph.Point::new(right, dst.y),
    ])
  } else {
    // No constraint - try all corner routes
    // Via top-left
    routes.push([
      @graph.Point::new(left, src.y),
      @graph.Point::new(left, top),
      @graph.Point::new(dst.x, top),
    ])
    // Via top-right
    routes.push([
      @graph.Point::new(right, src.y),
      @graph.Point::new(right, top),
      @graph.Point::new(dst.x, top),
    ])
    // Via bottom-left
    routes.push([
      @graph.Point::new(left, src.y),
      @graph.Point::new(left, bottom),
      @graph.Point::new(dst.x, bottom),
    ])
    // Via bottom-right
    routes.push([
      @graph.Point::new(right, src.y),
      @graph.Point::new(right, bottom),
      @graph.Point::new(dst.x, bottom),
    ])
  }
  routes
}

///|
struct AStarEntry {
  f : Double
  g : Double
  state : Int
} derive(Eq, Show)

///|
impl Compare for AStarEntry with compare(a, b) {
  let c1 = a.f.compare(b.f)
  if c1 != 0 {
    c1
  } else {
    let c2 = a.g.compare(b.g)
    if c2 != 0 {
      c2
    } else {
      a.state.compare(b.state)
    }
  }
}

///|
/// Maze-router fallback: sparse grid A* in free space.
/// Returns true if it rewrote `edge.route`.
/// IMPORTANT: Uses assigned port sides from Phase 6.5 to guarantee perpendicularity
fn route_via_maze_router(
  edge : @graph.Edge,
  graph : @graph.Graph,
  canvas_bounds : (Double, Double, Double, Double),
) -> Bool {
  if edge.route.length() < 2 {
    return false
  }
  let src_obj = graph.find_object(edge.src_id)
  let dst_obj = graph.find_object(edge.dst_id)
  guard src_obj is Some(so) else { return false }
  guard dst_obj is Some(dst_obj1) else { return false }
  guard so.box is Some(src_box) else { return false }
  guard dst_obj1.box is Some(dst_box) else { return false }
  let src = edge.route[0]
  let dst = edge.route[edge.route.length() - 1]

  // Use assigned port sides from Phase 6.5 as PRIMARY candidates
  // Fall back to other ports if no valid route found with assigned ports
  let src_ports : Array[(String, @graph.Point)] = []
  let dst_ports : Array[(String, @graph.Point)] = []

  // Add assigned port first if available (primary candidate)
  match edge.src_port {
    Some(port) => {
      let side = port_side_to_side_string(port.side)
      let pt = match port.point {
        Some(p) => p
        None => src
      }
      src_ports.push((side, pt))
    }
    None => ()
  }
  // Add current endpoint and all other sides as fallbacks
  let src_side = get_endpoint_side(src, src_box, 2.0)
  let src_assigned_side = match edge.src_port {
    Some(p) => port_side_to_side_string(p.side)
    None => ""
  }
  if src_ports.length() == 0 || src_side != src_assigned_side {
    src_ports.push((src_side, src))
  }
  for side in ["top", "bottom", "left", "right"] {
    let already_added = src_ports.iter().any(fn(p) { p.0 == side })
    if !already_added {
      src_ports.push((side, get_anchor_point(src_box, side, 0.0)))
    }
  }

  // Add assigned port first if available (primary candidate)
  match edge.dst_port {
    Some(port) => {
      let side = port_side_to_side_string(port.side)
      let pt = match port.point {
        Some(p) => p
        None => dst
      }
      dst_ports.push((side, pt))
    }
    None => ()
  }
  // Add current endpoint and all other sides as fallbacks
  let dst_side = get_endpoint_side(dst, dst_box, 2.0)
  let dst_assigned_side = match edge.dst_port {
    Some(p) => port_side_to_side_string(p.side)
    None => ""
  }
  if dst_ports.length() == 0 || dst_side != dst_assigned_side {
    dst_ports.push((dst_side, dst))
  }
  for side in ["top", "bottom", "left", "right"] {
    let already_added = dst_ports.iter().any(fn(p) { p.0 == side })
    if !already_added {
      dst_ports.push((side, get_anchor_point(dst_box, side, 0.0)))
    }
  }

  // Build obstacle list (exclude endpoints; also skip SQL parent tables if present).
  let src_parent = get_parent_id_from_field(edge.src_id)
  let dst_parent = get_parent_id_from_field(edge.dst_id)
  let obstacles : Array[@graph.Box] = []
  for obj in graph.objects {
    if obj.id == edge.src_id || obj.id == edge.dst_id {
      continue
    }
    if src_parent is Some(p) && obj.id == p {
      continue
    }
    if dst_parent is Some(p) && obj.id == p {
      continue
    }
    guard obj.box is Some(box) else { continue }
    obstacles.push(box)
  }

  // Prefer larger clearance; fall back to tighter routing only if needed.
  let clearances = [2.0, 1.0, 0.0]
  let mut best_route : Array[@graph.Point]? = None
  let mut best_clearance_idx = 1000000
  let mut best_cost = 1.0e18
  for s_port in src_ports {
    let s_side = s_port.0
    let s_pt = s_port.1
    for d_port in dst_ports {
      let d_side = d_port.0
      let d_pt = d_port.1
      for ci, clearance in clearances {
        let path_opt = astar_route_orthogonal(
          s_pt, d_pt, s_side, d_side, src_box, dst_box, obstacles, canvas_bounds,
          clearance,
        )
        match path_opt {
          None => ()
          Some(path) => {
            // Validate that the route respects port constraints
            let src_ok = match edge.src_port {
              Some(port) => route_respects_src_port(path, port.side)
              None => true
            }
            let dst_ok = match edge.dst_port {
              Some(port) => route_respects_dst_port(path, port.side)
              None => true
            }
            if src_ok && dst_ok {
              let cost = path_cost(path)
              if ci < best_clearance_idx ||
                (ci == best_clearance_idx && cost < best_cost) {
                best_clearance_idx = ci
                best_cost = cost
                best_route = Some(path)
              }
              // If we found a valid path at this clearance for this pair, don't try tighter.
              break
            }
          }
        }
      }
    }
  }
  match best_route {
    None => false
    Some(route) => {
      edge.route.clear()
      for pt in route {
        edge.route.push(pt)
      }
      true
    }
  }
}

///|
fn path_cost(route : Array[@graph.Point]) -> Double {
  if route.length() < 2 {
    return 0.0
  }
  let turn_penalty = 10.0
  let mut total = 0.0
  let mut prev_dir = 0 // 0 none, 1 horizontal, 2 vertical
  for i = 0; i < route.length() - 1; i = i + 1 {
    let a = route[i]
    let b = route[i + 1]
    let dx = (b.x - a.x).abs()
    let dy = (b.y - a.y).abs()
    let dir = if dx > dy { 1 } else { 2 }
    total = total + dx + dy
    if prev_dir != 0 && prev_dir != dir {
      total = total + turn_penalty
    }
    prev_dir = dir
  }
  total
}

///|
fn astar_route_orthogonal(
  start : @graph.Point,
  goal : @graph.Point,
  _start_side : String,
  goal_side : String,
  src_box : @graph.Box,
  dst_box : @graph.Box,
  obstacles : Array[@graph.Box],
  canvas_bounds : (Double, Double, Double, Double),
  clearance : Double,
) -> Array[@graph.Point]? {
  // Expand obstacles by clearance (boundary-touch still allowed).
  let expanded : Array[@graph.Box] = []
  for b in obstacles {
    expanded.push(expand_box(b, clearance))
  }
  let (min_x, min_y, max_x, max_y) = canvas_bounds
  let outer_margin = 250.0
  let left_bound = min_x - outer_margin
  let right_bound = max_x + outer_margin
  let top_bound = min_y - outer_margin
  let bottom_bound = max_y + outer_margin

  // Sparse coordinate grid (Hanan-style): obstacle boundaries + endpoints + canvas bounds.
  let xs : Array[Double] = [
    start.x,
    goal.x,
    left_bound,
    right_bound,
    src_box.x,
    src_box.x + src_box.width,
    dst_box.x,
    dst_box.x + dst_box.width,
  ]
  let ys : Array[Double] = [
    start.y,
    goal.y,
    top_bound,
    bottom_bound,
    src_box.y,
    src_box.y + src_box.height,
    dst_box.y,
    dst_box.y + dst_box.height,
  ]
  for b in expanded {
    xs.push(b.x)
    xs.push(b.x + b.width)
    ys.push(b.y)
    ys.push(b.y + b.height)
  }
  let x_coords = unique_sorted(xs, 0.001)
  let y_coords = unique_sorted(ys, 0.001)
  if x_coords.length() < 2 || y_coords.length() < 2 {
    return None
  }
  let start_ix_opt = find_coord_index(x_coords, start.x, 0.01)
  let start_iy_opt = find_coord_index(y_coords, start.y, 0.01)
  let goal_ix_opt = find_coord_index(x_coords, goal.x, 0.01)
  let goal_iy_opt = find_coord_index(y_coords, goal.y, 0.01)
  guard start_ix_opt is Some(start_ix) else { return None }
  guard start_iy_opt is Some(start_iy) else { return None }
  guard goal_ix_opt is Some(goal_ix) else { return None }
  guard goal_iy_opt is Some(goal_iy) else { return None }
  let x_len = x_coords.length()
  let y_len = y_coords.length()
  let cell_count = x_len * y_len

  // Blocked grid nodes (inside obstacle interior).
  let blocked : Array[Bool] = Array::new(capacity=cell_count)
  for _ in 0..<cell_count {
    blocked.push(false)
  }
  for iy = 0; iy < y_len; iy = iy + 1 {
    for ix = 0; ix < x_len; ix = ix + 1 {
      let idx = iy * x_len + ix
      let p = @graph.Point::new(x_coords[ix], y_coords[iy])
      if point_inside_any_box(p, expanded) {
        blocked[idx] = true
      }
    }
  }
  // Ensure endpoints stay reachable even if numerically on a boundary.
  blocked[start_iy * x_len + start_ix] = false
  blocked[goal_iy * x_len + goal_ix] = false
  let total_states = cell_count * 3
  let inf = 1.0e18
  let g_score : Array[Double] = Array::new(capacity=total_states)
  let came_from : Array[Int] = Array::new(capacity=total_states)
  let closed : Array[Bool] = Array::new(capacity=total_states)
  for _ in 0..<total_states {
    g_score.push(inf)
    came_from.push(-1)
    closed.push(false)
  }
  let start_state = encode_state(start_ix, start_iy, 0, x_len, y_len)
  g_score[start_state] = 0.0
  let open : @priority_queue.PriorityQueue[@cmp.Reverse[AStarEntry]] = @priority_queue.new()
  open.push(
    @cmp.Reverse({
      f: heuristic(start_ix, start_iy, goal_ix, goal_iy, x_coords, y_coords),
      g: 0.0,
      state: start_state,
    }),
  )
  let mut goal_state : Int? = None
  let turn_penalty = 10.0
  while open.pop() is Some(@cmp.Reverse(entry)) {
    let state = entry.state
    if closed[state] {
      continue
    }
    closed[state] = true
    let (ix, iy, dir) = decode_state(state, x_len, y_len)
    if ix == goal_ix && iy == goal_iy {
      goal_state = Some(state)
      break
    }

    // Neighbor order chosen for determinism.
    for step in [(1, 0, 1), (-1, 0, 1), (0, 1, 2), (0, -1, 2)] {
      let dx = step.0
      let dy = step.1
      let ndir = step.2
      let nix = ix + dx
      let niy = iy + dy
      if nix < 0 || niy < 0 || nix >= x_len || niy >= y_len {
        continue
      }
      let ncell = niy * x_len + nix
      if blocked[ncell] {
        continue
      }

      // Enforce goal approach side/direction for arrow correctness.
      if nix == goal_ix &&
        niy == goal_iy &&
        !can_enter_goal(
          ix, iy, nix, niy, goal_ix, goal_iy, goal_side, x_coords, y_coords,
        ) {
        continue
      }
      let p0 = @graph.Point::new(x_coords[ix], y_coords[iy])
      let p1 = @graph.Point::new(x_coords[nix], y_coords[niy])
      if segment_hits_any_box(p0, p1, expanded) {
        continue
      }
      let move_cost = (p1.x - p0.x).abs() + (p1.y - p0.y).abs()
      let turn_cost = if dir != 0 && dir != ndir { turn_penalty } else { 0.0 }
      let tentative = g_score[state] + move_cost + turn_cost
      let nstate = encode_state(nix, niy, ndir, x_len, y_len)
      if tentative + 1.0e-9 < g_score[nstate] {
        g_score[nstate] = tentative
        came_from[nstate] = state
        let f = tentative +
          heuristic(nix, niy, goal_ix, goal_iy, x_coords, y_coords)
        open.push(@cmp.Reverse({ f, g: tentative, state: nstate }))
      }
    }
  }
  guard goal_state is Some(gs) else { return None }
  let raw = reconstruct_points(gs, came_from, x_len, y_len, x_coords, y_coords)
  let route = compress_route(raw, start, goal)

  // Final sanity: avoid returning a route that still hits an obstacle due to numerical drift.
  if route.length() < 2 {
    None
  } else if route_hits_any_box(route, expanded) {
    None
  } else {
    Some(route)
  }
}

///|
fn expand_box(box : @graph.Box, margin : Double) -> @graph.Box {
  @graph.Box::new(
    box.x - margin,
    box.y - margin,
    box.width + margin * 2.0,
    box.height + margin * 2.0,
  )
}

///|
fn unique_sorted(values : Array[Double], eps : Double) -> Array[Double] {
  values.sort()
  let out : Array[Double] = []
  for v in values {
    if out.is_empty() {
      out.push(v)
    } else {
      let last = out[out.length() - 1]
      if (v - last).abs() > eps {
        out.push(v)
      }
    }
  }
  out
}

///|
fn find_coord_index(
  values : Array[Double],
  target : Double,
  eps : Double,
) -> Int? {
  for i, v in values {
    if (v - target).abs() <= eps {
      return Some(i)
    }
  }
  None
}

///|
fn encode_state(ix : Int, iy : Int, dir : Int, x_len : Int, y_len : Int) -> Int {
  let cell = iy * x_len + ix
  let base = x_len * y_len
  dir * base + cell
}

///|
fn decode_state(state : Int, x_len : Int, y_len : Int) -> (Int, Int, Int) {
  let base = x_len * y_len
  let dir = state / base
  let cell = state % base
  let ix = cell % x_len
  let iy = cell / x_len
  (ix, iy, dir)
}

///|
fn heuristic(
  ix : Int,
  iy : Int,
  goal_ix : Int,
  goal_iy : Int,
  xs : Array[Double],
  ys : Array[Double],
) -> Double {
  (xs[ix] - xs[goal_ix]).abs() + (ys[iy] - ys[goal_iy]).abs()
}

///|
fn point_inside_any_box(p : @graph.Point, boxes : Array[@graph.Box]) -> Bool {
  for b in boxes {
    let left = b.x
    let right = b.x + b.width
    let top = b.y
    let bottom = b.y + b.height
    if p.x > left && p.x < right && p.y > top && p.y < bottom {
      return true
    }
  }
  false
}

///|
fn segment_hits_any_box(
  p0 : @graph.Point,
  p1 : @graph.Point,
  boxes : Array[@graph.Box],
) -> Bool {
  for b in boxes {
    if segment_hits_box(p0, p1, b) {
      return true
    }
  }
  false
}

///|
fn segment_hits_box(
  p0 : @graph.Point,
  p1 : @graph.Point,
  b : @graph.Box,
) -> Bool {
  let left = b.x
  let right = b.x + b.width
  let top = b.y
  let bottom = b.y + b.height
  let dx = (p1.x - p0.x).abs()
  let dy = (p1.y - p0.y).abs()
  // Only used for orthogonal routing; treat near-zero as axis-aligned.
  if dx >= dy {
    // Horizontal
    let y = p0.y
    if !(y > top && y < bottom) {
      return false
    }
    let x0 = if p0.x < p1.x { p0.x } else { p1.x }
    let x1 = if p0.x > p1.x { p0.x } else { p1.x }
    x1 > left && x0 < right
  } else {
    // Vertical
    let x = p0.x
    if !(x > left && x < right) {
      return false
    }
    let y0 = if p0.y < p1.y { p0.y } else { p1.y }
    let y1 = if p0.y > p1.y { p0.y } else { p1.y }
    y1 > top && y0 < bottom
  }
}

///|
fn can_enter_goal(
  from_ix : Int,
  from_iy : Int,
  to_ix : Int,
  to_iy : Int,
  goal_ix : Int,
  goal_iy : Int,
  goal_side : String,
  xs : Array[Double],
  ys : Array[Double],
) -> Bool {
  if to_ix != goal_ix || to_iy != goal_iy {
    return true
  }
  match goal_side {
    "top" => from_ix == to_ix && ys[from_iy] < ys[to_iy]
    "bottom" => from_ix == to_ix && ys[from_iy] > ys[to_iy]
    "left" => from_iy == to_iy && xs[from_ix] < xs[to_ix]
    "right" => from_iy == to_iy && xs[from_ix] > xs[to_ix]
    _ => true
  }
}

///|
fn reconstruct_points(
  goal_state : Int,
  came_from : Array[Int],
  x_len : Int,
  y_len : Int,
  xs : Array[Double],
  ys : Array[Double],
) -> Array[@graph.Point] {
  let mut cur = goal_state
  let states : Array[Int] = []
  while cur >= 0 {
    states.push(cur)
    cur = came_from[cur]
  }
  states.rev_in_place()
  let pts : Array[@graph.Point] = []
  for s in states {
    let (ix, iy, _dir) = decode_state(s, x_len, y_len)
    pts.push(@graph.Point::new(xs[ix], ys[iy]))
  }
  pts
}

///|
fn compress_route(
  points : Array[@graph.Point],
  start : @graph.Point,
  goal : @graph.Point,
) -> Array[@graph.Point] {
  if points.length() == 0 {
    return []
  }
  if points.length() == 1 {
    return [start, goal]
  }
  let cleaned : Array[@graph.Point] = []
  cleaned.push(start)
  for i = 1; i < points.length() - 1; i = i + 1 {
    let prev = cleaned[cleaned.length() - 1]
    let cur = points[i]
    let next = points[i + 1]
    // Drop duplicates.
    if (cur.x - prev.x).abs() < 0.001 && (cur.y - prev.y).abs() < 0.001 {
      continue
    }
    // Drop collinear points.
    if (prev.x - cur.x).abs() < 0.001 && (cur.x - next.x).abs() < 0.001 {
      continue
    }
    if (prev.y - cur.y).abs() < 0.001 && (cur.y - next.y).abs() < 0.001 {
      continue
    }
    cleaned.push(cur)
  }
  cleaned.push(goal)
  cleaned
}

///|
fn route_hits_any_box(
  route : Array[@graph.Point],
  boxes : Array[@graph.Box],
) -> Bool {
  if route.length() < 2 {
    return false
  }
  for i = 0; i < route.length() - 1; i = i + 1 {
    if segment_hits_any_box(route[i], route[i + 1], boxes) {
      return true
    }
  }
  false
}
