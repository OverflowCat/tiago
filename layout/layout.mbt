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
    vertical_spacing: 60.0,
    container_padding: 20.0,
    default_width: 100.0,
    default_height: 60.0,
    edge_padding: 20.0,
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
  // Check if root-level is a sequence diagram
  if is_sequence_diagram(graph.root) && graph.root.is_container() {
    // Use sequence layout for the entire graph
    let result = layout_sequence_with_activations(graph.root, graph, config)
    // Store activation boxes in the graph for rendering
    for box in result.activation_boxes {
      graph.activation_boxes.push((box.actor_id, box.get_box()))
    }
    // Store notes in the graph for rendering
    for note in result.notes {
      graph.sequence_notes.push((note.actor_id, note.text, note.bbox))
    }
    // Layout layers, scenarios, and steps recursively
    for layer in graph.layers {
      layout(layer.graph, config, direction)
    }
    for scenario in graph.scenarios {
      layout(scenario.graph, config, direction)
    }
    for step in graph.steps {
      layout(step.graph, config, direction)
    }
    return
  }
  // Phase 0: Break cycles using greedy DFS (Feedback Arc Set)
  let cycle_result = break_cycles(graph)
  // Phase 1: Assign layers using network simplex
  let layer_result = assign_layers(graph, cycle_result)
  // Phase 1.5: Insert virtual nodes for long edges
  let virtual_result = insert_virtual_nodes(graph, layer_result, cycle_result)
  // Phase 2: Minimize edge crossings using Barycenter heuristic
  let crossing_result = minimize_crossings_with_virtual(
    graph,
    virtual_result.layer_assignment,
    cycle_result,
    virtual_result.virtual_nodes,
  )
  // Phase 3: Compute sizes for all objects
  compute_sizes(graph, config)
  // Phase 4: Position objects - check for special containers
  for obj in graph.objects {
    if is_sequence_diagram(obj) && obj.is_container() {
      // Use full sequence layout with message routing, activation boxes, and notes
      let result = layout_sequence_with_activations(obj, graph, config)
      // Store activation boxes in the graph for rendering
      for box in result.activation_boxes {
        graph.activation_boxes.push((box.actor_id, box.get_box()))
      }
      // Store notes in the graph for rendering
      for note in result.notes {
        graph.sequence_notes.push((note.actor_id, note.text, note.bbox))
      }
    } else if obj.is_grid_diagram() && obj.is_container() {
      layout_grid(obj, config)
    }
  }
  // Phase 5: Position remaining objects based on layers with optimized ordering
  position_objects_layered_with_virtual(
    graph, config, direction, virtual_result, crossing_result, cycle_result,
  )
  // Phase 6: Apply near positioning
  apply_near_positioning(graph, config)
  // Phase 7: Route edges using virtual node positions
  route_edges_with_virtual(graph, config, virtual_result)
  // Phase 7.1: Route around obstacles
  route_around_obstacles(graph)
  // Phase 7.2: Normalize coordinates to non-negative
  normalize_coordinates(graph)
  // Phase 7.5: Optimize edge routes by removing unnecessary bends
  eliminate_unnecessary_bends(graph)
  // Phase 7.6: Separate parallel edges (bidirectional duplicates)
  separate_parallel_edges(graph)
  // Note: approach direction correction removed - handled upstream in routing functions
  // Phase 8: Position edge labels to avoid overlaps
  position_edge_labels(graph, config)
  // Phase 9: Layout layers, scenarios, and steps recursively
  for layer in graph.layers {
    layout(layer.graph, config, direction)
  }
  for scenario in graph.scenarios {
    layout(scenario.graph, config, direction)
  }
  for step in graph.steps {
    layout(step.graph, config, direction)
  }
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
  // SQL tables use compact row-based sizing (not container spacing)
  if obj.shape_type == @graph.SqlTable {
    let line_height = 18.0 // font_size (14) + 4
    let padding = 8.0
    let header_height = line_height + padding // 26
    let columns_height = obj.children.length().to_double() * line_height +
      padding
    let total_height = header_height + columns_height
    // Width: max of label and column labels
    let mut max_width = estimate_label_width(obj.label, config)
    for child in obj.children {
      let col_width = estimate_label_width(child.label, config)
      if col_width > max_width {
        max_width = col_width
      }
    }
    obj.set_box(@graph.Box::new(0.0, 0.0, max_width, total_height))
  } else if obj.is_container() {
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
/// Position objects sequentially (for graphs without dependencies)
fn position_objects_sequential(
  graph : @graph.Graph,
  config : LayoutConfig,
  direction : Direction,
) -> Unit {
  let roots = find_root_objects(graph)
  let mut x = config.container_padding
  let mut y = config.container_padding
  for root in roots {
    position_subtree(root, x, y, config, direction)
    match (root.box, direction) {
      (Some(b), Down | Up) => y = y + b.height + config.vertical_spacing
      (Some(b), Right | Left) => x = x + b.width + config.horizontal_spacing
      (None, _) => ()
    }
  }
}

///|
/// Position children within a container
fn position_container_children(
  container : @graph.Object,
  config : LayoutConfig,
  direction : Direction,
) -> Unit {
  match container.box {
    Some(parent_box) => {
      let mut child_x = parent_box.x + config.container_padding
      let mut child_y = parent_box.y + config.container_padding
      for child in container.children {
        match child.box {
          Some(b) => {
            child.set_box(@graph.Box::new(child_x, child_y, b.width, b.height))
            match direction {
              Down | Up =>
                child_y = child_y + b.height + config.vertical_spacing
              Right | Left =>
                child_x = child_x + b.width + config.horizontal_spacing
            }
            // Recursively position nested children
            if child.is_container() {
              position_container_children(child, config, direction)
            }
          }
          None => ()
        }
      }
    }
    None => ()
  }
}

///|
/// Get the connection point for a specific anchor position on a box
fn get_anchor_point(
  box : @graph.Box,
  anchor : String,
  offset : Double,
) -> @graph.Point {
  let cx = box.center().get_x()
  let cy = box.center().get_y()
  match anchor.to_lower() {
    "top" => @graph.Point::new(cx + offset, box.y)
    "bottom" => @graph.Point::new(cx + offset, box.y + box.height)
    "left" => @graph.Point::new(box.x, cy + offset)
    "right" => @graph.Point::new(box.x + box.width, cy + offset)
    "center" => @graph.Point::new(cx + offset, cy)
    "top-left" => @graph.Point::new(box.x, box.y)
    "top-right" => @graph.Point::new(box.x + box.width, box.y)
    "bottom-left" => @graph.Point::new(box.x, box.y + box.height)
    "bottom-right" => @graph.Point::new(box.x + box.width, box.y + box.height)
    _ => @graph.Point::new(cx + offset, cy) // Default to center
  }
}

///|
/// Get parent ID from a dotted field ID (e.g., "users.id" -> "users")
fn get_parent_id_from_field(id : String) -> String? {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot <= 0 {
    return None
  }
  let buf = StringBuilder::new()
  for i = 0; i < last_dot; i = i + 1 {
    buf.write_char(id[i].to_int().unsafe_to_char())
  }
  Some(buf.to_string())
}

///|
/// Get the anchor point for a SQL table row connection
/// column_index is 0-based, the y-position matches SVG renderer's calculation
fn get_sql_row_anchor_point(
  table_box : @graph.Box,
  column_index : Int,
  _num_columns : Int,
  is_left_side : Bool,
) -> @graph.Point {
  // Match the SVG renderer's calculation in svg_render.mbt:
  // - line_height = font_size + 4.0 (default font_size = 14, so line_height = 18)
  // - header_height = line_height + padding = 18 + 8 = 26
  // - row text y = box.y + header_height + line_height * 0.7 + line_height * i
  // For edge connection, use the same y as the row text (which is centered)
  let line_height = 18.0 // font_size (14) + 4
  let header_height = 26.0 // line_height + padding (8)
  let row_center_y = table_box.y +
    header_height +
    line_height * (column_index.to_double() + 0.7)
  // Return exact edge position - extend_edge_endpoints will add outward extension
  let x = if is_left_side { table_box.x } else { table_box.x + table_box.width }
  @graph.Point::new(x, row_center_y)
}

///|
/// Calculate the best anchor points for an edge based on relative box positions.
/// Returns (src_anchor, dst_anchor) strings.
///
/// IMPORTANT: The dst_anchor is chosen based on the direction from src_point to
/// dst_center (not center-to-center). This ensures the approach direction matches
/// the anchor side (required by edge_connects_to_correct_side constraint).
fn calculate_best_anchors(
  src_box : @graph.Box,
  dst_box : @graph.Box,
) -> (String, String) {
  let src_cx = src_box.center().get_x()
  let src_cy = src_box.center().get_y()
  let dst_cx = dst_box.center().get_x()
  let dst_cy = dst_box.center().get_y()
  let dx_center = dst_cx - src_cx
  let dy_center = dst_cy - src_cy
  // Step 1: Pick src_anchor based on center-to-center direction
  let src_anchor = if dy_center.abs() >= dx_center.abs() {
    if dy_center > 0.0 {
      "bottom"
    } else {
      "top"
    }
  } else if dx_center > 0.0 {
    "right"
  } else {
    "left"
  }
  // Step 2: Calculate src_point
  let src_point = get_anchor_point(src_box, src_anchor, 0.0)
  // Step 3: Pick dst_anchor based on direction from src_point to dst_center
  // This ensures the final segment approaches from the correct direction
  let dx_to_dst = dst_cx - src_point.x
  let dy_to_dst = dst_cy - src_point.y
  let dst_anchor = if dy_to_dst.abs() >= dx_to_dst.abs() {
    // Approach is more vertical
    if dy_to_dst > 0.0 {
      "top" // Approaching from above (going down) → connect to top
    } else {
      "bottom" // Approaching from below (going up) → connect to bottom
    }
    // Approach is more horizontal
  } else if dx_to_dst > 0.0 {
    "left" // Approaching from left (going right) → connect to left
  } else {
    "right" // Approaching from right (going left) → connect to right
  }
  (src_anchor, dst_anchor)
}

///|
/// Find where a line from center to target intersects the box edge
pub fn find_edge_intersection(
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

// ============================================================================
// Grid Layout
// ============================================================================

///|
/// Layout children of a container in a grid pattern (with spanning support)
fn layout_grid(container : @graph.Object, config : LayoutConfig) -> Unit {
  let children = container.get_children()
  if children.length() == 0 {
    return
  }
  let h_gap = container.get_horizontal_gap()
  let v_gap = container.get_vertical_gap()
  // Determine rows and columns
  let (rows, columns, row_directed) = compute_grid_dimensions(
    container,
    children.length(),
  )
  // Allocate cells and compute positions for each child (with spanning)
  let cell_positions = allocate_grid_cells(
    children, rows, columns, row_directed,
  )
  // Compute column widths and row heights (considering spans)
  let col_widths = compute_column_widths_with_spans(
    children, columns, cell_positions, config,
  )
  let row_heights = compute_row_heights_with_spans(
    children, rows, cell_positions, config,
  )
  // Position children in the grid (with spanning)
  position_grid_children_with_spans(
    children, cell_positions, col_widths, row_heights, h_gap, v_gap, config,
  )
  // Update container size
  let total_width = sum_with_gap(col_widths, h_gap) +
    config.container_padding * 2.0
  let total_height = sum_with_gap(row_heights, v_gap) +
    config.container_padding * 2.0
  container.set_box(
    @graph.Box::new(0.0, 0.0, max(total_width, 100.0), max(total_height, 60.0)),
  )
}

///|
/// Compute grid dimensions (rows, columns, row_directed)
fn compute_grid_dimensions(
  container : @graph.Object,
  child_count : Int,
) -> (Int, Int, Bool) {
  match (container.get_grid_rows(), container.get_grid_columns()) {
    (Some(r), Some(c)) => (r, c, true)
    (Some(r), None) => {
      let columns = (child_count + r - 1) / r
      (r, columns, true)
    }
    (None, Some(c)) => {
      let rows = (child_count + c - 1) / c
      (rows, c, false)
    }
    (None, None) =>
      // Should not happen for grid diagrams, but default to single column
      (child_count, 1, true)
  }
}

///|
/// Sum array values with gap between them
fn sum_with_gap(values : Array[Double], gap : Double) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  for v in values {
    total = total + v + gap
  }
  total - gap
}

// ============================================================================
// Grid Cell Spanning Support
// ============================================================================

///|
/// Cell position with spanning information
priv struct CellPosition {
  row : Int
  col : Int
  row_span : Int
  col_span : Int
}

///|
/// Allocate cells for children considering spans
/// Returns array of CellPosition for each child
fn allocate_grid_cells(
  children : Array[@graph.Object],
  rows : Int,
  columns : Int,
  row_directed : Bool,
) -> Array[CellPosition] {
  // Create occupancy grid: occupied[row * columns + col] = true if cell is occupied
  let total_cells = rows * columns
  let occupied : Array[Bool] = []
  for _ in 0..<total_cells {
    occupied.push(false)
  }
  let positions : Array[CellPosition] = []
  for child in children {
    let col_span = min(child.get_grid_column_span(), columns)
    let row_span = min(child.get_grid_row_span(), rows)
    // Find next available cell that can fit this span
    match
      find_available_cell(
        occupied, rows, columns, row_span, col_span, row_directed,
      ) {
      Some((row, col)) => {
        // Mark cells as occupied
        for r in row..<min(row + row_span, rows) {
          for c in col..<min(col + col_span, columns) {
            occupied[r * columns + c] = true
          }
        }
        positions.push({ row, col, row_span, col_span })
      }
      None =>
        // No space available - place at 0,0 with 1x1 span (fallback)
        positions.push({ row: 0, col: 0, row_span: 1, col_span: 1 })
    }
  }
  positions
}

///|
/// Find the next available cell that can fit the given span
fn find_available_cell(
  occupied : Array[Bool],
  rows : Int,
  columns : Int,
  row_span : Int,
  col_span : Int,
  row_directed : Bool,
) -> (Int, Int)? {
  if row_directed {
    // Scan row by row, left to right
    for r in 0..<rows {
      for c in 0..<columns {
        if can_place_span(occupied, rows, columns, r, c, row_span, col_span) {
          return Some((r, c))
        }
      }
    }
  } else {
    // Scan column by column, top to bottom
    for c in 0..<columns {
      for r in 0..<rows {
        if can_place_span(occupied, rows, columns, r, c, row_span, col_span) {
          return Some((r, c))
        }
      }
    }
  }
  None
}

///|
/// Check if a span can be placed at the given position
fn can_place_span(
  occupied : Array[Bool],
  rows : Int,
  columns : Int,
  start_row : Int,
  start_col : Int,
  row_span : Int,
  col_span : Int,
) -> Bool {
  // Check bounds
  if start_row + row_span > rows || start_col + col_span > columns {
    return false
  }
  // Check if all cells are available
  for r in start_row..<(start_row + row_span) {
    for c in start_col..<(start_col + col_span) {
      if occupied[r * columns + c] {
        return false
      }
    }
  }
  true
}

///|
/// Compute column widths considering spans
fn compute_column_widths_with_spans(
  children : Array[@graph.Object],
  columns : Int,
  positions : Array[CellPosition],
  config : LayoutConfig,
) -> Array[Double] {
  let widths : Array[Double] = []
  for _ in 0..<columns {
    widths.push(config.default_width)
  }
  // First pass: handle non-spanning cells
  for i, child in children {
    if i >= positions.length() {
      continue
    }
    let pos = positions[i]
    if pos.col_span == 1 {
      let child_width = match child.get_box() {
        Some(b) => b.get_width()
        None => config.default_width
      }
      if child_width > widths[pos.col] {
        widths[pos.col] = child_width
      }
    }
  }
  // Second pass: distribute spanning cell widths if needed
  for i, child in children {
    if i >= positions.length() {
      continue
    }
    let pos = positions[i]
    if pos.col_span > 1 {
      let child_width = match child.get_box() {
        Some(b) => b.get_width()
        None => config.default_width * pos.col_span.to_double()
      }
      // Sum current widths for spanned columns
      let mut current_total = 0.0
      for c in pos.col..<min(pos.col + pos.col_span, columns) {
        current_total = current_total + widths[c]
      }
      // If child needs more space, distribute evenly
      if child_width > current_total {
        let extra_per_col = (child_width - current_total) /
          pos.col_span.to_double()
        for c in pos.col..<min(pos.col + pos.col_span, columns) {
          widths[c] = widths[c] + extra_per_col
        }
      }
    }
  }
  widths
}

///|
/// Compute row heights considering spans
fn compute_row_heights_with_spans(
  children : Array[@graph.Object],
  rows : Int,
  positions : Array[CellPosition],
  config : LayoutConfig,
) -> Array[Double] {
  let heights : Array[Double] = []
  for _ in 0..<rows {
    heights.push(config.default_height)
  }
  // First pass: handle non-spanning cells
  for i, child in children {
    if i >= positions.length() {
      continue
    }
    let pos = positions[i]
    if pos.row_span == 1 {
      let child_height = match child.get_box() {
        Some(b) => b.get_height()
        None => config.default_height
      }
      if child_height > heights[pos.row] {
        heights[pos.row] = child_height
      }
    }
  }
  // Second pass: distribute spanning cell heights if needed
  for i, child in children {
    if i >= positions.length() {
      continue
    }
    let pos = positions[i]
    if pos.row_span > 1 {
      let child_height = match child.get_box() {
        Some(b) => b.get_height()
        None => config.default_height * pos.row_span.to_double()
      }
      // Sum current heights for spanned rows
      let mut current_total = 0.0
      for r in pos.row..<min(pos.row + pos.row_span, rows) {
        current_total = current_total + heights[r]
      }
      // If child needs more space, distribute evenly
      if child_height > current_total {
        let extra_per_row = (child_height - current_total) /
          pos.row_span.to_double()
        for r in pos.row..<min(pos.row + pos.row_span, rows) {
          heights[r] = heights[r] + extra_per_row
        }
      }
    }
  }
  heights
}

///|
/// Position children in grid cells with spanning support
fn position_grid_children_with_spans(
  children : Array[@graph.Object],
  positions : Array[CellPosition],
  col_widths : Array[Double],
  row_heights : Array[Double],
  h_gap : Double,
  v_gap : Double,
  config : LayoutConfig,
) -> Unit {
  let columns = col_widths.length()
  let rows = row_heights.length()
  for i, child in children {
    if i >= positions.length() {
      continue
    }
    let pos = positions[i]
    if pos.row >= rows || pos.col >= columns {
      continue
    }
    // Calculate x position
    let mut x = config.container_padding
    for j in 0..<pos.col {
      x = x + col_widths[j] + h_gap
    }
    // Calculate y position
    let mut y = config.container_padding
    for j in 0..<pos.row {
      y = y + row_heights[j] + v_gap
    }
    // Calculate width (sum of spanned columns + gaps)
    let mut width = 0.0
    let end_col = min(pos.col + pos.col_span, columns)
    for j in pos.col..<end_col {
      width = width + col_widths[j]
      if j < end_col - 1 {
        width = width + h_gap
      }
    }
    // Calculate height (sum of spanned rows + gaps)
    let mut height = 0.0
    let end_row = min(pos.row + pos.row_span, rows)
    for j in pos.row..<end_row {
      height = height + row_heights[j]
      if j < end_row - 1 {
        height = height + v_gap
      }
    }
    child.set_box(@graph.Box::new(x, y, width, height))
  }
}

///|
fn min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

// ============================================================================
// Edge Label Positioning
// ============================================================================

///|
/// Position edge labels to avoid overlaps with nodes and other labels
fn position_edge_labels(graph : @graph.Graph, config : LayoutConfig) -> Unit {
  // Collect all node bounding boxes for overlap detection
  let node_boxes : Array[@graph.Box] = []
  for obj in graph.objects {
    match obj.get_box() {
      Some(b) => node_boxes.push(b)
      None => ()
    }
  }
  // Collect already-placed label boxes for inter-label collision detection
  let label_boxes : Array[@graph.Box] = []
  // Process each edge with a label
  for edge in graph.edges {
    if edge.label == "" {
      continue
    }
    match edge.midpoint() {
      Some(mid) => {
        // Estimate label dimensions (similar to SVG render)
        let padding = 4.0
        let char_width = 7.0
        let font_size = 12.0
        let label_width = edge.label.length().to_double() * char_width +
          padding * 2.0
        let label_height = font_size + padding * 2.0
        // Initial label box centered at midpoint
        let mut label_x = mid.x - label_width / 2.0
        let mut label_y = mid.y - label_height / 2.0
        let mut label_box = @graph.Box::new(
          label_x, label_y, label_width, label_height,
        )
        // Calculate perpendicular direction to the edge
        let (perp_x, perp_y) = compute_perpendicular_direction(edge)
        // Also get the edge direction for along-edge offsets
        let route = edge.get_route()
        let (edge_dx, edge_dy) = if route.length() >= 2 {
          let p1 = route[0]
          let p2 = route[route.length() - 1]
          let dx = p2.x - p1.x
          let dy = p2.y - p1.y
          let len = (dx * dx + dy * dy).sqrt()
          if len > 0.001 {
            (dx / len, dy / len)
          } else {
            (1.0, 0.0)
          }
        } else {
          (1.0, 0.0)
        }
        // Try to find a non-overlapping position using grid search
        let mut found = false
        // Increase step size based on number of existing labels to spread them out
        let base_step = config.edge_padding
        let label_count = label_boxes.length()
        // Try positions in expanding circles around midpoint
        for radius in [0, 1, 2, 3, 4, 5] {
          if found {
            break
          }
          // Also try vertical stacking based on label index
          let stack_offset = label_count.to_double() * (label_height + 5.0)
          for perp_mult in [-radius, 0, radius] {
            if found {
              break
            }
            for along_mult in [-radius, 0, radius] {
              if radius == 0 && (perp_mult != 0 || along_mult != 0) {
                continue
              }
              // Try without stack offset first, then with
              for stack in [0.0, stack_offset, -stack_offset] {
                label_x = mid.x -
                  label_width / 2.0 +
                  perp_x * (perp_mult.to_double() * base_step) +
                  edge_dx * (along_mult.to_double() * base_step)
                label_y = mid.y -
                  label_height / 2.0 +
                  perp_y * (perp_mult.to_double() * base_step) +
                  edge_dy * (along_mult.to_double() * base_step) +
                  stack
                label_box = @graph.Box::new(
                  label_x, label_y, label_width, label_height,
                )
                // Check for overlaps with nodes
                let mut overlaps = false
                for node_box in node_boxes {
                  if boxes_overlap(label_box, node_box) {
                    overlaps = true
                    break
                  }
                }
                // Check for overlaps with other labels
                if !overlaps {
                  for other_box in label_boxes {
                    if boxes_overlap(label_box, other_box) {
                      overlaps = true
                      break
                    }
                  }
                }
                if !overlaps {
                  found = true
                  break
                }
              }
              if found {
                break
              }
            }
          }
        }
        // Store the computed label box
        edge.set_label_box(label_box)
        label_boxes.push(label_box)
      }
      None => ()
    }
  }
}

///|
/// Compute the perpendicular direction to an edge for label offset
fn compute_perpendicular_direction(edge : @graph.Edge) -> (Double, Double) {
  let route = edge.get_route()
  if route.length() < 2 {
    return (0.0, 1.0) // Default to vertical offset
  }
  // Get direction at midpoint
  let mid_idx = route.length() / 2
  let p1 = if mid_idx > 0 { route[mid_idx - 1] } else { route[0] }
  let p2 = if mid_idx < route.length() {
    route[mid_idx]
  } else {
    route[mid_idx - 1]
  }
  // Direction vector
  let dx = p2.x - p1.x
  let dy = p2.y - p1.y
  let len = (dx * dx + dy * dy).sqrt()
  if len < 0.001 {
    return (0.0, 1.0) // Fallback
  }
  // Perpendicular direction (rotated 90 degrees)
  let perp_x = -dy / len
  let perp_y = dx / len
  (perp_x, perp_y)
}

///|
/// Check if two boxes overlap (with small margin)
fn boxes_overlap(a : @graph.Box, b : @graph.Box) -> Bool {
  let margin = 2.0
  not(
    a.x + a.width + margin < b.x ||
    b.x + b.width + margin < a.x ||
    a.y + a.height + margin < b.y ||
    b.y + b.height + margin < a.y,
  )
}

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

///|
/// Route edges using virtual node positions for smoother paths
fn route_edges_with_virtual(
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
    // Handle SQL table field connections specially
    let (src_box, src_num_cols, dst_box, dst_num_cols) = match
      get_sql_table_boxes(graph, edge) {
      Some(boxes) => boxes
      None => {
        // Regular edge routing - find source and destination objects
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
    // Calculate parallel edge offset
    let edge_key = if edge.src_id < edge.dst_id {
      edge.src_id + "->" + edge.dst_id
    } else {
      edge.dst_id + "->" + edge.src_id
    }
    let edge_index = edge_counts.get(edge_key).unwrap_or(0)
    edge_counts[edge_key] = edge_index + 1
    // Check if this edge has virtual nodes
    if virtual_result.edge_virtual_nodes.get(edge.index) is Some(virtual_ids) &&
      virtual_ids.length() > 0 {
      // Route through virtual nodes
      route_edge_through_virtual_sql(
        edge, src_box, dst_box, virtual_ids, virtual_result, src_num_cols, dst_num_cols,
        edge_index,
      )
    } else {
      // Direct edge routing with parallel offset
      route_direct_edge_sql_parallel(
        edge, src_box, dst_box, src_num_cols, dst_num_cols, edge_index,
      )
    }
  }
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
  // Determine which side the destination endpoint is on
  let dst_obj = graph.find_object(edge.dst_id)
  let endpoint_side = match dst_obj {
    Some(obj) =>
      match obj.box {
        Some(box) => get_endpoint_side(dst, box, 2.0)
        None => "none"
      }
    None => "none"
  }
  // Try multiple margins until we find a valid route
  let margins = [30.0, 60.0, 100.0, 150.0, 200.0]
  for margin in margins {
    let left = min_x - margin
    let right = max_x + margin
    let top = min_y - margin
    let bottom = max_y + margin
    // Create routes based on specific endpoint side
    let routes = create_canvas_edge_routes(
      src, dst, endpoint_side, left, right, top, bottom,
    )
    // Find the shortest valid route
    for route in routes {
      if is_bypass_valid(src, route, dst, edge, graph) {
        // Found a valid route - apply it and return
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
  let src_side = get_endpoint_side(src, src_box, 2.0)
  let dst_side = get_endpoint_side(dst, dst_box, 2.0)

  // Candidate ports: keep current endpoints first, then try all sides.
  let src_ports : Array[(String, @graph.Point)] = [(src_side, src)]
  let dst_ports : Array[(String, @graph.Point)] = [(dst_side, dst)]
  for side in ["top", "bottom", "left", "right"] {
    src_ports.push((side, get_anchor_point(src_box, side, 0.0)))
    dst_ports.push((side, get_anchor_point(dst_box, side, 0.0)))
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
            let cost = path_cost(path)
            if ci < best_clearance_idx ||
              (ci == best_clearance_idx && cost < best_cost) {
              best_clearance_idx = ci
              best_cost = cost
              best_route = Some(path)
            }
            // If we found a path at this clearance for this pair, don't try tighter.
            break
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

// ============================================================================
// Parallel Edge Separation
// ============================================================================

///|
/// Ensure parallel edges (including bidirectional pairs) don't overlap.
/// This runs after obstacle routing and bend elimination, so it must not rely on
/// later cleanup passes.
fn separate_parallel_edges(graph : @graph.Graph) -> Unit {
  let canvas_bounds = compute_all_bounds(graph)
  let edge_groups : Map[String, Array[@graph.Edge]] = {}
  for edge in graph.edges {
    if edge.route.length() < 2 {
      continue
    }
    let key = if edge.src_id < edge.dst_id {
      edge.src_id + "->" + edge.dst_id
    } else {
      edge.dst_id + "->" + edge.src_id
    }
    match edge_groups.get(key) {
      Some(arr) => arr.push(edge)
      None => edge_groups[key] = [edge]
    }
  }
  let min_separation = 3.0
  let corridor_widths = [8.0, 6.0]
  for group in edge_groups.values() {
    if group.length() <= 1 {
      continue
    }
    for i in 0..<group.length() {
      for j in (i + 1)..<group.length() {
        let e1 = group[i]
        let e2 = group[j]
        if !edges_overlap_min_sep(e1, e2, min_separation) {
          continue
        }
        let mut fixed = false
        for w in corridor_widths {
          let corridor = build_edge_corridor_obstacles(e1.route, w)
          if route_fixed_ports_maze_with_extra_obstacles(
              e2, graph, canvas_bounds, corridor,
            ) &&
            !edges_overlap_min_sep(e1, e2, min_separation) {
            fixed = true
            break
          }
        }
        if !fixed {
          // If the overlap is caused by shared endpoints (common for bidirectional edges),
          // reroute again with shifted ports on both nodes.
          for port_offset in [15.0, -15.0, 30.0, -30.0] {
            for w in corridor_widths {
              let corridor = build_edge_corridor_obstacles(e1.route, w)
              if route_maze_with_port_offset_and_extra_obstacles(
                  e2, graph, canvas_bounds, corridor, port_offset,
                ) &&
                !edges_overlap_min_sep(e1, e2, min_separation) {
                fixed = true
                break
              }
            }
            if fixed {
              break
            }
          }
        }
        if fixed {
          continue
        }
        // Try the opposite direction (reroute e1) if rerouting e2 couldn't separate.
        for w in corridor_widths {
          let corridor = build_edge_corridor_obstacles(e2.route, w)
          if route_fixed_ports_maze_with_extra_obstacles(
              e1, graph, canvas_bounds, corridor,
            ) &&
            !edges_overlap_min_sep(e1, e2, min_separation) {
            break
          }
        }
      }
    }
  }
}

///|
fn edges_overlap_min_sep(
  edge1 : @graph.Edge,
  edge2 : @graph.Edge,
  min_dist : Double,
) -> Bool {
  if edge1.route.length() < 2 || edge2.route.length() < 2 {
    return false
  }
  for i in 0..<(edge1.route.length() - 1) {
    let a1 = edge1.route[i]
    let a2 = edge1.route[i + 1]
    for j in 0..<(edge2.route.length() - 1) {
      let b1 = edge2.route[j]
      let b2 = edge2.route[j + 1]
      if parallel_segments_too_close(a1, a2, b1, b2, min_dist) {
        return true
      }
    }
  }
  false
}

///|
fn parallel_segments_too_close(
  a1 : @graph.Point,
  a2 : @graph.Point,
  b1 : @graph.Point,
  b2 : @graph.Point,
  min_dist : Double,
) -> Bool {
  let samples = 5
  for i in 0..=samples {
    let t1 = i.to_double() / samples.to_double()
    let p1_x = a1.x + t1 * (a2.x - a1.x)
    let p1_y = a1.y + t1 * (a2.y - a1.y)
    for j in 0..=samples {
      let t2 = j.to_double() / samples.to_double()
      let p2_x = b1.x + t2 * (b2.x - b1.x)
      let p2_y = b1.y + t2 * (b2.y - b1.y)
      let dx = p2_x - p1_x
      let dy = p2_y - p1_y
      let dist = (dx * dx + dy * dy).sqrt()
      if dist < min_dist {
        return true
      }
    }
  }
  false
}

///|
fn build_edge_corridor_obstacles(
  route : Array[@graph.Point],
  width : Double,
) -> Array[@graph.Box] {
  let boxes : Array[@graph.Box] = []
  if route.length() < 2 {
    return boxes
  }
  let half = width / 2.0
  let trim = 0.0
  for i = 0; i < route.length() - 1; i = i + 1 {
    let p0 = route[i]
    let p1 = route[i + 1]
    if (p0.x - p1.x).abs() < 0.001 {
      // Vertical segment
      let x = p0.x - half
      let y0 = if p0.y < p1.y { p0.y } else { p1.y }
      let y1 = if p0.y > p1.y { p0.y } else { p1.y }
      let y_start = y0 + trim
      let y_end = y1 - trim
      if y_end - y_start > 0.1 {
        boxes.push(@graph.Box::new(x, y_start, width, y_end - y_start))
      }
    } else if (p0.y - p1.y).abs() < 0.001 {
      // Horizontal segment
      let y = p0.y - half
      let x0 = if p0.x < p1.x { p0.x } else { p1.x }
      let x1 = if p0.x > p1.x { p0.x } else { p1.x }
      let x_start = x0 + trim
      let x_end = x1 - trim
      if x_end - x_start > 0.1 {
        boxes.push(@graph.Box::new(x_start, y, x_end - x_start, width))
      }
    }
  }
  // Block corners too (exclude endpoints).
  if route.length() >= 3 {
    for i = 1; i < route.length() - 1; i = i + 1 {
      let p = route[i]
      boxes.push(@graph.Box::new(p.x - half, p.y - half, width, width))
    }
  }
  boxes
}

///|
fn clip_obstacle_away_from_box(
  obstacle : @graph.Box,
  blocker : @graph.Box,
  margin : Double,
) -> Array[@graph.Box] {
  let expanded = expand_box(blocker, margin)
  let ox0 = obstacle.x
  let oy0 = obstacle.y
  let ox1 = obstacle.x + obstacle.width
  let oy1 = obstacle.y + obstacle.height
  let bx0 = expanded.x
  let by0 = expanded.y
  let bx1 = expanded.x + expanded.width
  let by1 = expanded.y + expanded.height
  let ix0 = if ox0 > bx0 { ox0 } else { bx0 }
  let ix1 = if ox1 < bx1 { ox1 } else { bx1 }
  let iy0 = if oy0 > by0 { oy0 } else { by0 }
  let iy1 = if oy1 < by1 { oy1 } else { by1 }
  if ix0 >= ix1 || iy0 >= iy1 {
    return [obstacle]
  }
  let out : Array[@graph.Box] = []
  // Cut along the long axis (corridor obstacles are thin rectangles).
  if obstacle.height >= obstacle.width {
    // Keep portion above intersection.
    let top_h = iy0 - oy0
    if top_h > 0.1 {
      out.push(@graph.Box::new(obstacle.x, oy0, obstacle.width, top_h))
    }
    // Keep portion below intersection.
    let bottom_h = oy1 - iy1
    if bottom_h > 0.1 {
      out.push(@graph.Box::new(obstacle.x, iy1, obstacle.width, bottom_h))
    }
  } else {
    // Keep portion left of intersection.
    let left_w = ix0 - ox0
    if left_w > 0.1 {
      out.push(@graph.Box::new(ox0, obstacle.y, left_w, obstacle.height))
    }
    // Keep portion right of intersection.
    let right_w = ox1 - ix1
    if right_w > 0.1 {
      out.push(@graph.Box::new(ix1, obstacle.y, right_w, obstacle.height))
    }
  }
  out
}

///|
fn route_fixed_ports_maze_with_extra_obstacles(
  edge : @graph.Edge,
  graph : @graph.Graph,
  canvas_bounds : (Double, Double, Double, Double),
  extra_obstacles : Array[@graph.Box],
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
  let start = edge.route[0]
  let goal = edge.route[edge.route.length() - 1]
  let start_side = get_endpoint_side(start, src_box, 2.0)
  let goal_side = get_endpoint_side(goal, dst_box, 2.0)

  // Base obstacles: all node boxes except endpoints (+ SQL parent skip).
  let src_parent = get_parent_id_from_field(edge.src_id)
  let dst_parent = get_parent_id_from_field(edge.dst_id)
  let node_obstacles : Array[@graph.Box] = []
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
    node_obstacles.push(box)
  }

  // Clip extra obstacles so they don't block leaving/entering the endpoints.
  // This keeps the "corridor" effective while allowing attachment near nodes.
  let filtered_extra : Array[@graph.Box] = []
  for b in extra_obstacles {
    let parts1 = clip_obstacle_away_from_box(b, src_box, 2.0)
    for p1 in parts1 {
      let parts2 = clip_obstacle_away_from_box(p1, dst_box, 2.0)
      for p2 in parts2 {
        filtered_extra.push(p2)
      }
    }
  }

  // Expand node obstacles by a clearance; keep edge-corridor obstacles as-is.
  for node_clearance in [2.0, 1.0, 0.0] {
    let obstacles : Array[@graph.Box] = []
    for b in node_obstacles {
      obstacles.push(expand_box(b, node_clearance))
    }
    for b in filtered_extra {
      obstacles.push(b)
    }
    let path_opt = astar_route_orthogonal(
      start, goal, start_side, goal_side, src_box, dst_box, obstacles, canvas_bounds,
      0.0,
    )
    match path_opt {
      None => ()
      Some(path) => {
        edge.route.clear()
        for pt in path {
          edge.route.push(pt)
        }
        return true
      }
    }
  }
  false
}

///|
fn route_maze_with_port_offset_and_extra_obstacles(
  edge : @graph.Edge,
  graph : @graph.Graph,
  canvas_bounds : (Double, Double, Double, Double),
  extra_obstacles : Array[@graph.Box],
  port_offset : Double,
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

  // Keep the same attachment side, but shift along that side.
  let current_start = edge.route[0]
  let current_goal = edge.route[edge.route.length() - 1]
  let start_side0 = get_endpoint_side(current_start, src_box, 2.0)
  let goal_side0 = get_endpoint_side(current_goal, dst_box, 2.0)
  let (default_src_anchor, default_dst_anchor) = calculate_best_anchors(
    src_box, dst_box,
  )
  let start_side = match start_side0 {
    "top" | "bottom" | "left" | "right" => start_side0
    _ => edge.src_anchor.unwrap_or(default_src_anchor)
  }
  let goal_side = match goal_side0 {
    "top" | "bottom" | "left" | "right" => goal_side0
    _ => edge.dst_anchor.unwrap_or(default_dst_anchor)
  }
  let start = get_anchor_point(src_box, start_side, port_offset)
  let goal = get_anchor_point(dst_box, goal_side, port_offset)

  // Base obstacles: all node boxes except endpoints (+ SQL parent skip).
  let src_parent = get_parent_id_from_field(edge.src_id)
  let dst_parent = get_parent_id_from_field(edge.dst_id)
  let node_obstacles : Array[@graph.Box] = []
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
    node_obstacles.push(box)
  }

  // Clip extra obstacles so they don't block leaving/entering the endpoints.
  let filtered_extra : Array[@graph.Box] = []
  for b in extra_obstacles {
    let parts1 = clip_obstacle_away_from_box(b, src_box, 2.0)
    for p1 in parts1 {
      let parts2 = clip_obstacle_away_from_box(p1, dst_box, 2.0)
      for p2 in parts2 {
        filtered_extra.push(p2)
      }
    }
  }

  // Expand node obstacles by a clearance; keep edge-corridor obstacles as-is.
  for node_clearance in [2.0, 1.0, 0.0] {
    let obstacles : Array[@graph.Box] = []
    for b in node_obstacles {
      obstacles.push(expand_box(b, node_clearance))
    }
    for b in filtered_extra {
      obstacles.push(b)
    }
    let path_opt = astar_route_orthogonal(
      start, goal, start_side, goal_side, src_box, dst_box, obstacles, canvas_bounds,
      0.0,
    )
    match path_opt {
      None => ()
      Some(path) => {
        edge.route.clear()
        for pt in path {
          edge.route.push(pt)
        }
        return true
      }
    }
  }
  false
}

///|
/// Attempt to reroute around obstacle, return false if no valid bypass found
fn reroute_around_obstacle_with_fallback(
  edge : @graph.Edge,
  obstacle : @graph.Box,
  graph : @graph.Graph,
  _canvas_bounds : (Double, Double, Double, Double),
) -> Bool {
  if edge.route.length() < 2 {
    return false
  }
  // Find the segment that intersects the obstacle
  for i = 0; i < edge.route.length() - 1; i = i + 1 {
    let p0 = edge.route[i]
    let p1 = edge.route[i + 1]
    if line_intersects_box(p0, p1, obstacle) {
      // Calculate bypass routes and pick the best one
      let bypass_opt = calculate_best_bypass_opt(p0, p1, obstacle, edge, graph)
      match bypass_opt {
        Some(bypass) => {
          // Replace segment with bypass route
          let new_route : Array[@graph.Point] = []
          for j = 0; j <= i; j = j + 1 {
            new_route.push(edge.route[j])
          }
          for pt in bypass {
            new_route.push(pt)
          }
          for j = i + 1; j < edge.route.length(); j = j + 1 {
            new_route.push(edge.route[j])
          }
          edge.route.clear()
          for pt in new_route {
            edge.route.push(pt)
          }
          return true // Successfully rerouted
        }
        None => return false // No valid bypass found
      }
    }
  }
  true // No intersection found (shouldn't happen, but safe default)
}

///|
/// Determine which side of a box a point is on (for endpoint approach direction)
/// Returns: "top", "bottom", "left", "right", or "none" if not on any edge
fn get_endpoint_side(
  point : @graph.Point,
  box : @graph.Box,
  tolerance : Double,
) -> String {
  let on_top = (point.y - box.y).abs() < tolerance
  let on_bottom = (point.y - (box.y + box.height)).abs() < tolerance
  let on_left = (point.x - box.x).abs() < tolerance
  let on_right = (point.x - (box.x + box.width)).abs() < tolerance
  // Prefer vertical sides (top/bottom) when point is on a corner
  if on_top {
    "top"
  } else if on_bottom {
    "bottom"
  } else if on_left {
    "left"
  } else if on_right {
    "right"
  } else {
    "none"
  }
}

///|
/// Calculate the best bypass route around an obstacle, returning None if no valid bypass
/// Respects endpoint side: only allows bypass routes that approach from the correct direction
fn calculate_best_bypass_opt(
  p0 : @graph.Point,
  p1 : @graph.Point,
  obstacle : @graph.Box,
  edge : @graph.Edge,
  graph : @graph.Graph,
) -> Array[@graph.Point]? {
  // Determine which side the endpoint (p1) is on, if this is the last segment
  // This ensures the bypass approach direction matches the endpoint's side
  let last_point = edge.route[edge.route.length() - 1]
  let is_last_segment = (p1.x - last_point.x).abs() < 1.0 &&
    (p1.y - last_point.y).abs() < 1.0
  // Get destination box to determine endpoint side
  let endpoint_side = if is_last_segment {
    let dst_obj = graph.find_object(edge.dst_id)
    match dst_obj {
      Some(obj) =>
        match obj.box {
          Some(box) => get_endpoint_side(p1, box, 2.0)
          None => "none"
        }
      None => "none"
    }
  } else {
    "none" // Not the last segment, no constraint
  }
  // Try multiple margin sizes for more options
  for margin in [10.0, 20.0, 40.0] {
    let obs_left = obstacle.x - margin
    let obs_right = obstacle.x + obstacle.width + margin
    let obs_top = obstacle.y - margin
    let obs_bottom = obstacle.y + obstacle.height + margin
    // Try bypass routes based on endpoint side constraint
    let routes : Array[Array[@graph.Point]] = []
    // Route 1: Go above obstacle → approaches from above (dy > 0) → for TOP edge
    // Only add if endpoint is on TOP or no constraint
    if (endpoint_side == "top" || endpoint_side == "none") &&
      (p0.x - p1.x).abs() > 1.0 {
      routes.push([
        @graph.Point::new(p0.x, obs_top),
        @graph.Point::new(p1.x, obs_top),
      ])
    }
    // Route 2: Go below obstacle → approaches from below (dy < 0) → for BOTTOM edge
    if (endpoint_side == "bottom" || endpoint_side == "none") &&
      (p0.x - p1.x).abs() > 1.0 {
      routes.push([
        @graph.Point::new(p0.x, obs_bottom),
        @graph.Point::new(p1.x, obs_bottom),
      ])
    }
    // Route 3: Go left of obstacle → approaches from left (dx > 0) → for LEFT edge
    if (endpoint_side == "left" || endpoint_side == "none") &&
      (p0.y - p1.y).abs() > 1.0 {
      routes.push([
        @graph.Point::new(obs_left, p0.y),
        @graph.Point::new(obs_left, p1.y),
      ])
    }
    // Route 4: Go right of obstacle → approaches from right (dx < 0) → for RIGHT edge
    if (endpoint_side == "right" || endpoint_side == "none") &&
      (p0.y - p1.y).abs() > 1.0 {
      routes.push([
        @graph.Point::new(obs_right, p0.y),
        @graph.Point::new(obs_right, p1.y),
      ])
    }
    // Additional corner routes for complex obstacle configurations
    if endpoint_side == "none" || endpoint_side == "top" {
      // Route via top-left corner
      routes.push([
        @graph.Point::new(obs_left, p0.y),
        @graph.Point::new(obs_left, obs_top),
        @graph.Point::new(p1.x, obs_top),
      ])
      // Route via top-right corner
      routes.push([
        @graph.Point::new(obs_right, p0.y),
        @graph.Point::new(obs_right, obs_top),
        @graph.Point::new(p1.x, obs_top),
      ])
    }
    if endpoint_side == "none" || endpoint_side == "bottom" {
      // Route via bottom-left corner
      routes.push([
        @graph.Point::new(obs_left, p0.y),
        @graph.Point::new(obs_left, obs_bottom),
        @graph.Point::new(p1.x, obs_bottom),
      ])
      // Route via bottom-right corner
      routes.push([
        @graph.Point::new(obs_right, p0.y),
        @graph.Point::new(obs_right, obs_bottom),
        @graph.Point::new(p1.x, obs_bottom),
      ])
    }
    if endpoint_side == "none" || endpoint_side == "left" {
      // Route via left-top corner
      routes.push([
        @graph.Point::new(p0.x, obs_top),
        @graph.Point::new(obs_left, obs_top),
        @graph.Point::new(obs_left, p1.y),
      ])
      // Route via left-bottom corner
      routes.push([
        @graph.Point::new(p0.x, obs_bottom),
        @graph.Point::new(obs_left, obs_bottom),
        @graph.Point::new(obs_left, p1.y),
      ])
    }
    if endpoint_side == "none" || endpoint_side == "right" {
      // Route via right-top corner
      routes.push([
        @graph.Point::new(p0.x, obs_top),
        @graph.Point::new(obs_right, obs_top),
        @graph.Point::new(obs_right, p1.y),
      ])
      // Route via right-bottom corner
      routes.push([
        @graph.Point::new(p0.x, obs_bottom),
        @graph.Point::new(obs_right, obs_bottom),
        @graph.Point::new(obs_right, p1.y),
      ])
    }
    // Fallback for degenerate segments - create routes matching endpoint side
    if routes.is_empty() {
      // For degenerate segments, we need a 3-point bypass to change approach direction
      // This handles vertical segments to top/bottom and horizontal segments to left/right
      if endpoint_side == "top" {
        // Vertical segment to TOP: go left/right, then up, then to endpoint
        routes.push([
          @graph.Point::new(obs_left, p0.y),
          @graph.Point::new(obs_left, obs_top),
          @graph.Point::new(p1.x, obs_top),
        ])
      } else if endpoint_side == "bottom" {
        // Vertical segment to BOTTOM: go left/right, then down, then to endpoint
        routes.push([
          @graph.Point::new(obs_left, p0.y),
          @graph.Point::new(obs_left, obs_bottom),
          @graph.Point::new(p1.x, obs_bottom),
        ])
      } else if endpoint_side == "left" {
        // Horizontal segment to LEFT: go up/down, then left, then to endpoint
        routes.push([
          @graph.Point::new(p0.x, obs_top),
          @graph.Point::new(obs_left, obs_top),
          @graph.Point::new(obs_left, p1.y),
        ])
      } else if endpoint_side == "right" {
        // Horizontal segment to RIGHT: go up/down, then right, then to endpoint
        routes.push([
          @graph.Point::new(p0.x, obs_top),
          @graph.Point::new(obs_right, obs_top),
          @graph.Point::new(obs_right, p1.y),
        ])
      } else {
        // No constraint - use simple bypass
        routes.push([
          @graph.Point::new(p0.x, obs_top),
          @graph.Point::new(p1.x, obs_top),
        ])
      }
    }
    // Find the shortest valid route
    let mut best_route : Array[@graph.Point]? = None
    let mut best_length = 1.0e10
    for route in routes {
      if is_bypass_valid(p0, route, p1, edge, graph) {
        let length = bypass_length(p0, route, p1)
        if length < best_length {
          best_length = length
          best_route = Some(route)
        }
      }
    }
    if best_route is Some(_) {
      return best_route
    }
  }
  None // No valid bypass found at any margin
}

///|
/// Find the first obstacle (object box) that the edge route intersects
fn find_intersecting_obstacle(
  edge : @graph.Edge,
  graph : @graph.Graph,
) -> @graph.Box? {
  if edge.route.length() < 2 {
    return None
  }
  // For SQL table field connections (e.g., users.id), also skip the parent table
  let src_parent = get_parent_id_from_field(edge.src_id)
  let dst_parent = get_parent_id_from_field(edge.dst_id)
  for i = 0; i < edge.route.length() - 1; i = i + 1 {
    let p0 = edge.route[i]
    let p1 = edge.route[i + 1]
    for obj in graph.objects {
      // Skip source and destination objects (and their parent tables)
      if obj.id == edge.src_id || obj.id == edge.dst_id {
        continue
      }
      if src_parent is Some(p) && obj.id == p {
        continue
      }
      if dst_parent is Some(p) && obj.id == p {
        continue
      }
      // Skip objects without boxes
      guard obj.box is Some(box) else { continue }
      if line_intersects_box(p0, p1, box) {
        return Some(box)
      }
    }
  }
  None
}

///|
/// Check if a bypass route is valid (doesn't intersect other obstacles)
fn is_bypass_valid(
  start : @graph.Point,
  bypass : Array[@graph.Point],
  end : @graph.Point,
  edge : @graph.Edge,
  graph : @graph.Graph,
) -> Bool {
  // For SQL table field connections, get parent IDs to skip
  let src_parent = get_parent_id_from_field(edge.src_id)
  let dst_parent = get_parent_id_from_field(edge.dst_id)
  // Check segment from start to first bypass point
  if bypass.length() > 0 {
    if line_intersects_objects_with_skip(
        start,
        bypass[0],
        graph,
        edge,
        src_parent,
        dst_parent,
      ) {
      return false
    }
    // Check segments between bypass points
    for i = 0; i < bypass.length() - 1; i = i + 1 {
      if line_intersects_objects_with_skip(
          bypass[i],
          bypass[i + 1],
          graph,
          edge,
          src_parent,
          dst_parent,
        ) {
        return false
      }
    }
    // Check segment from last bypass point to end
    if line_intersects_objects_with_skip(
        bypass[bypass.length() - 1],
        end,
        graph,
        edge,
        src_parent,
        dst_parent,
      ) {
      return false
    }
  }
  true
}

///|
/// Calculate total length of a bypass route
fn bypass_length(
  start : @graph.Point,
  bypass : Array[@graph.Point],
  end : @graph.Point,
) -> Double {
  let mut total = 0.0
  let mut prev = start
  for pt in bypass {
    let dx = pt.x - prev.x
    let dy = pt.y - prev.y
    total = total + (dx * dx + dy * dy).sqrt()
    prev = pt
  }
  let dx = end.x - prev.x
  let dy = end.y - prev.y
  total = total + (dx * dx + dy * dy).sqrt()
  total
}

// ============================================================================
// S-Shape and Ladder Elimination
// ============================================================================

///|
/// Optimize edge routes by removing unnecessary bends (S-shapes and ladders)
/// This post-processing step improves visual quality by straightening edges
/// where possible without increasing edge crossings.
fn eliminate_unnecessary_bends(graph : @graph.Graph) -> Unit {
  for edge in graph.edges {
    if edge.route.length() < 3 {
      continue
    }
    // Make multiple passes until no more improvements
    let mut improved = true
    while improved {
      improved = false
      let mut i = 0
      while i < edge.route.length() - 2 {
        let p0 = edge.route[i]
        let p1 = edge.route[i + 1]
        let p2 = edge.route[i + 2]
        // Check if removing p1 would create a valid straight-ish line
        if can_remove_waypoint(p0, p1, p2, graph, edge) {
          // Remove the middle point
          let new_route : Array[@graph.Point] = []
          for j, pt in edge.route {
            if j != i + 1 {
              new_route.push(pt)
            }
          }
          edge.route.clear()
          for pt in new_route {
            edge.route.push(pt)
          }
          improved = true
          // Don't increment i, check the new triple at this position
        } else {
          i = i + 1
        }
      }
    }
  }
}

///|
/// Check if removing the middle waypoint would improve the edge route
fn can_remove_waypoint(
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
  graph : @graph.Graph,
  edge : @graph.Edge,
) -> Bool {
  // Remove if points are collinear (on same line) - middle point is redundant
  // Also remove if this forms an S-shape (direction reversal)
  if not(are_collinear(p0, p1, p2)) && not(is_s_shape(p0, p1, p2)) {
    return false
  }
  // Check if the direct line would intersect any objects
  if line_intersects_objects(p0, p2, graph, edge) {
    return false
  }
  true
}

///|
/// Check if three points are collinear (on the same line)
/// Uses cross product: if (p1-p0) × (p2-p0) ≈ 0, points are collinear
fn are_collinear(
  p0 : @graph.Point,
  p1 : @graph.Point,
  p2 : @graph.Point,
) -> Bool {
  let dx1 = p1.x - p0.x
  let dy1 = p1.y - p0.y
  let dx2 = p2.x - p0.x
  let dy2 = p2.y - p0.y
  // Cross product: dx1*dy2 - dy1*dx2
  // If close to zero, points are collinear
  let cross = dx1 * dy2 - dy1 * dx2
  cross.abs() < 1.0
}

///|
/// Check if three points form an S-shape (horizontal or vertical direction reversal)
/// Only removes waypoints that form S-shapes, NOT orthogonal corners
fn is_s_shape(p0 : @graph.Point, p1 : @graph.Point, p2 : @graph.Point) -> Bool {
  let dx1 = p1.x - p0.x
  let dy1 = p1.y - p0.y
  let dx2 = p2.x - p1.x
  let dy2 = p2.y - p1.y
  // Check if this is an orthogonal corner (railroad style) - don't remove these!
  // Orthogonal: one segment is vertical (dx≈0) and other is horizontal (dy≈0)
  let is_seg1_vertical = dx1.abs() < 1.0 && dy1.abs() > 1.0
  let is_seg1_horizontal = dy1.abs() < 1.0 && dx1.abs() > 1.0
  let is_seg2_vertical = dx2.abs() < 1.0 && dy2.abs() > 1.0
  let is_seg2_horizontal = dy2.abs() < 1.0 && dx2.abs() > 1.0
  // If this forms an orthogonal corner, preserve it
  if (is_seg1_vertical && is_seg2_horizontal) ||
    (is_seg1_horizontal && is_seg2_vertical) {
    return false
  }
  // S-shape: horizontal direction reverses
  if dx1 * dx2 < 0.0 {
    return true
  }
  // S-shape: vertical direction reverses
  if dy1 * dy2 < 0.0 {
    return true
  }
  false
}

///|
/// Check if a line segment intersects any object boxes (excluding edge endpoints)
fn line_intersects_objects(
  p0 : @graph.Point,
  p1 : @graph.Point,
  graph : @graph.Graph,
  edge : @graph.Edge,
) -> Bool {
  for obj in graph.objects {
    // Skip source and destination objects
    if obj.id == edge.src_id || obj.id == edge.dst_id {
      continue
    }
    match obj.box {
      Some(b) => if line_intersects_box(p0, p1, b) { return true }
      None => ()
    }
  }
  false
}

///|
/// Check if a line segment intersects any object boxes (with parent skip for SQL tables)
fn line_intersects_objects_with_skip(
  p0 : @graph.Point,
  p1 : @graph.Point,
  graph : @graph.Graph,
  edge : @graph.Edge,
  src_parent : String?,
  dst_parent : String?,
) -> Bool {
  for obj in graph.objects {
    // Skip source and destination objects
    if obj.id == edge.src_id || obj.id == edge.dst_id {
      continue
    }
    // Skip parent tables for SQL field connections
    if src_parent is Some(p) && obj.id == p {
      continue
    }
    if dst_parent is Some(p) && obj.id == p {
      continue
    }
    match obj.box {
      Some(b) => if line_intersects_box(p0, p1, b) { return true }
      None => ()
    }
  }
  false
}

///|
/// Check if a line segment intersects a box
fn line_intersects_box(
  p0 : @graph.Point,
  p1 : @graph.Point,
  box : @graph.Box,
) -> Bool {
  // Add a small margin to avoid edge cases
  let margin = 2.0
  let left = box.x - margin
  let right = box.x + box.width + margin
  let top = box.y - margin
  let bottom = box.y + box.height + margin
  // Check if line segment intersects any of the 4 box edges
  // Left edge
  if line_segments_intersect(p0.x, p0.y, p1.x, p1.y, left, top, left, bottom) {
    return true
  }
  // Right edge
  if line_segments_intersect(p0.x, p0.y, p1.x, p1.y, right, top, right, bottom) {
    return true
  }
  // Top edge
  if line_segments_intersect(p0.x, p0.y, p1.x, p1.y, left, top, right, top) {
    return true
  }
  // Bottom edge
  if line_segments_intersect(
      p0.x,
      p0.y,
      p1.x,
      p1.y,
      left,
      bottom,
      right,
      bottom,
    ) {
    return true
  }
  // Check if line is entirely inside the box
  if p0.x > left && p0.x < right && p0.y > top && p0.y < bottom {
    return true
  }
  if p1.x > left && p1.x < right && p1.y > top && p1.y < bottom {
    return true
  }
  false
}

///|
/// Check if two line segments intersect
fn line_segments_intersect(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
  x4 : Double,
  y4 : Double,
) -> Bool {
  let d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
  if d.abs() < 0.0001 {
    return false // Parallel lines
  }
  let t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / d
  let u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / d
  t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0
}

// ============================================================================
// Near Positioning
// ============================================================================

///|
/// Near constant positions
let near_constants : Array[String] = [
  "top-left", "top-center", "top-right", "center-left", "center-right", "bottom-left",
  "bottom-center", "bottom-right",
]

///|
/// Check if a near value is a constant position
fn is_near_constant(near : String) -> Bool {
  for c in near_constants {
    if c == near.to_lower() {
      return true
    }
  }
  false
}

///|
/// Apply near positioning to all objects that have it set
fn apply_near_positioning(graph : @graph.Graph, config : LayoutConfig) -> Unit {
  // Get root bounding box (for constant positions relative to root)
  let root_box = compute_root_bounding_box(graph)
  // Apply near positioning to each object
  for obj in graph.objects {
    if obj.get_near() is Some(near) {
      if is_near_constant(near) {
        apply_constant_near(obj, near, root_box, config)
      } else {
        apply_object_near(graph, obj, near, config)
      }
    }
  }
}

///|
/// Compute bounding box containing all root objects
fn compute_root_bounding_box(graph : @graph.Graph) -> @graph.Box {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  let roots = find_root_objects(graph)
  for obj in roots {
    if obj.box is Some(b) {
      if first {
        min_x = b.x
        min_y = b.y
        max_x = b.x + b.width
        max_y = b.y + b.height
        first = false
      } else {
        if b.x < min_x {
          min_x = b.x
        }
        if b.y < min_y {
          min_y = b.y
        }
        if b.x + b.width > max_x {
          max_x = b.x + b.width
        }
        if b.y + b.height > max_y {
          max_y = b.y + b.height
        }
      }
    }
  }
  @graph.Box::new(min_x, min_y, max_x - min_x, max_y - min_y)
}

///|
/// Apply constant near position (top-left, center, etc.)
fn apply_constant_near(
  obj : @graph.Object,
  near : String,
  parent_box : @graph.Box,
  config : LayoutConfig,
) -> Unit {
  if obj.box is Some(b) {
    let margin = config.container_padding
    let (x, y) = match near.to_lower() {
      "top-left" => (parent_box.x + margin, parent_box.y + margin)
      "top-center" =>
        (
          parent_box.x + parent_box.width / 2.0 - b.width / 2.0,
          parent_box.y + margin,
        )
      "top-right" =>
        (
          parent_box.x + parent_box.width - b.width - margin,
          parent_box.y + margin,
        )
      "center-left" =>
        (
          parent_box.x + margin,
          parent_box.y + parent_box.height / 2.0 - b.height / 2.0,
        )
      "center-right" =>
        (
          parent_box.x + parent_box.width - b.width - margin,
          parent_box.y + parent_box.height / 2.0 - b.height / 2.0,
        )
      "bottom-left" =>
        (
          parent_box.x + margin,
          parent_box.y + parent_box.height - b.height - margin,
        )
      "bottom-center" =>
        (
          parent_box.x + parent_box.width / 2.0 - b.width / 2.0,
          parent_box.y + parent_box.height - b.height - margin,
        )
      "bottom-right" =>
        (
          parent_box.x + parent_box.width - b.width - margin,
          parent_box.y + parent_box.height - b.height - margin,
        )
      _ => (b.x, b.y) // Keep current position if unknown
    }
    obj.set_box(@graph.Box::new(x, y, b.width, b.height))
  }
}

///|
/// Apply near positioning relative to another object
fn apply_object_near(
  graph : @graph.Graph,
  obj : @graph.Object,
  target_id : String,
  config : LayoutConfig,
) -> Unit {
  // Find the target object
  if obj.box is Some(obj_box) &&
    graph.find_object(target_id) is Some(target_obj) &&
    target_obj.box is Some(target_box) {
    // Position the object near the target (to the right and slightly below)
    let margin = config.horizontal_spacing / 2.0
    let x = target_box.x + target_box.width + margin
    let y = target_box.y
    obj.set_box(@graph.Box::new(x, y, obj_box.width, obj_box.height))
  }
}
