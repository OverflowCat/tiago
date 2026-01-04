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
  let cx = box.center().get_x() + offset
  let cy = box.center().get_y()
  match anchor.to_lower() {
    "top" => @graph.Point::new(cx, box.y)
    "bottom" => @graph.Point::new(cx, box.y + box.height)
    "left" => @graph.Point::new(box.x, cy)
    "right" => @graph.Point::new(box.x + box.width, cy)
    "center" => @graph.Point::new(cx, cy)
    "top-left" => @graph.Point::new(box.x, box.y)
    "top-right" => @graph.Point::new(box.x + box.width, box.y)
    "bottom-left" => @graph.Point::new(box.x, box.y + box.height)
    "bottom-right" => @graph.Point::new(box.x + box.width, box.y + box.height)
    _ => @graph.Point::new(cx, cy) // Default to center
  }
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
        // Try to find a non-overlapping position
        // Check up to 5 positions: center, then alternating offsets
        let offsets = [
          0.0,
          config.edge_padding,
          -config.edge_padding,
          config.edge_padding * 2.0,
          -config.edge_padding * 2.0,
        ]
        for offset in offsets {
          label_x = mid.x - label_width / 2.0 + perp_x * offset
          label_y = mid.y - label_height / 2.0 + perp_y * offset
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
          if not(overlaps) {
            for other_box in label_boxes {
              if boxes_overlap(label_box, other_box) {
                overlaps = true
                break
              }
            }
          }
          if not(overlaps) {
            break // Found a good position
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
  for edge in graph.edges {
    // Clear existing route
    edge.route.clear()
    // Find source and destination objects
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
    let src_box = src.box.unwrap()
    let dst_box = dst.box.unwrap()
    // Check if this edge has virtual nodes
    if virtual_result.edge_virtual_nodes.get(edge.index) is Some(virtual_ids) &&
      virtual_ids.length() > 0 {
      // Route through virtual nodes
      route_edge_through_virtual(
        edge, src_box, dst_box, virtual_ids, virtual_result,
      )
    } else {
      // Direct edge routing
      route_direct_edge(edge, src_box, dst_box)
    }
  }
}

///|
/// Route an edge through virtual nodes
fn route_edge_through_virtual(
  edge : @graph.Edge,
  src_box : @graph.Box,
  dst_box : @graph.Box,
  virtual_ids : Array[String],
  virtual_result : VirtualNodeResult,
) -> Unit {
  // Get connection points on source
  let src_anchor = edge.src_anchor.unwrap_or("bottom")
  let src_point = get_anchor_point(src_box, src_anchor, 0.0)
  edge.route.push(src_point)
  // Add waypoints at virtual node positions
  // Virtual nodes should be positioned between source and destination
  let layer_assignment = virtual_result.layer_assignment
  let src_layer = layer_assignment.layers.get(edge.src_id).unwrap_or(0)
  let dst_layer = layer_assignment.layers.get(edge.dst_id).unwrap_or(0)
  let layer_span = dst_layer - src_layer
  if layer_span > 1 {
    // Calculate intermediate Y positions based on layer
    let total_height = dst_box.y - (src_box.y + src_box.height)
    let layer_height = total_height / layer_span.to_double()
    // Interpolate X position between source and destination centers
    let src_center_x = src_box.x + src_box.width / 2.0
    let dst_center_x = dst_box.x + dst_box.width / 2.0
    for i, _ in virtual_ids {
      let t = (i + 1).to_double() / layer_span.to_double()
      let waypoint_x = src_center_x + (dst_center_x - src_center_x) * t
      let waypoint_y = src_box.y +
        src_box.height +
        layer_height * (i + 1).to_double()
      edge.route.push(@graph.Point::new(waypoint_x, waypoint_y))
    }
  }
  // Get connection point on destination
  let dst_anchor = edge.dst_anchor.unwrap_or("top")
  let dst_point = get_anchor_point(dst_box, dst_anchor, 0.0)
  edge.route.push(dst_point)
}

///|
/// Route a direct edge (no virtual nodes)
fn route_direct_edge(
  edge : @graph.Edge,
  src_box : @graph.Box,
  dst_box : @graph.Box,
) -> Unit {
  let src_anchor = edge.src_anchor.unwrap_or("bottom")
  let dst_anchor = edge.dst_anchor.unwrap_or("top")
  let src_point = get_anchor_point(src_box, src_anchor, 0.0)
  let dst_point = get_anchor_point(dst_box, dst_anchor, 0.0)
  edge.route.push(src_point)
  edge.route.push(dst_point)
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
