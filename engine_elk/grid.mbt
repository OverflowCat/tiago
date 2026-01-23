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

// ============================================================================
// Grid Layout
// ============================================================================

///|
fn horizontal_gap(container : Object) -> Double {
  match container.horizontal_gap {
    Some(v) => v
    None =>
      match container.grid_gap {
        Some(v) => v
        None => 40.0
      }
  }
}

///|
fn vertical_gap(container : Object) -> Double {
  match container.vertical_gap {
    Some(v) => v
    None =>
      match container.grid_gap {
        Some(v) => v
        None => 40.0
      }
  }
}

///|
fn grid_span(value : Int?) -> Int {
  match value {
    Some(v) => if v >= 1 { v } else { 1 }
    None => 1
  }
}

///|
/// Layout children of a container in a grid pattern (with spanning support)
fn layout_grid(container : Object, config : LayoutConfig) -> Unit {
  let children = container.children
  if children.length() == 0 {
    return
  }
  let h_gap = horizontal_gap(container)
  let v_gap = vertical_gap(container)
  // D2 grid diagrams use a larger default container padding (60), but if the
  // user specifies gaps we use those as the padding too.
  let h_pad = if container.grid_gap is Some(_) || container.horizontal_gap is Some(_) {
    h_gap
  } else {
    60.0
  }
  let v_pad_base = if container.grid_gap is Some(_) || container.vertical_gap is Some(_) {
    v_gap
  } else {
    60.0
  }
  // Grid containers can have a title; ensure there's enough *top* padding to fit it
  // (D2 accounts for label height even when gap-based padding is used).
  let v_pad_top = match container.label_box {
    Some(b) => {
      let want = b.height + 10.0
      if want > v_pad_base { want } else { v_pad_base }
    }
    None => v_pad_base
  }
  let v_pad_bottom = v_pad_base
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
    children,
    cell_positions,
    col_widths,
    row_heights,
    h_gap,
    v_gap,
    h_pad,
    v_pad_top,
    config,
  )
  // Update container size
  let total_width = sum_with_gap(col_widths, h_gap) + h_pad * 2.0
  let total_height = sum_with_gap(row_heights, v_gap) + v_pad_top + v_pad_bottom
  container.box = Some(
    @graph.Box::new(0.0, 0.0, max(total_width, 100.0), max(total_height, 60.0)),
  )
}

///|
/// Compute grid dimensions (rows, columns, row_directed)
fn compute_grid_dimensions(
  container : Object,
  child_count : Int,
) -> (Int, Int, Bool) {
  match (container.grid_rows, container.grid_columns) {
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
  children : Array[Object],
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
    let col_span = min(grid_span(child.grid_column_span), columns)
    let row_span = min(grid_span(child.grid_row_span), rows)
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
  children : Array[Object],
  columns : Int,
  positions : Array[CellPosition],
  config : LayoutConfig,
) -> Array[Double] {
  let widths : Array[Double] = []
  for _ in 0..<columns {
    widths.push(0.0)
  }
  // First pass: handle non-spanning cells
  for i, child in children {
    if i >= positions.length() {
      continue
    }
    let pos = positions[i]
    if pos.col_span == 1 {
      let child_width = match child.box {
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
      let child_width = match child.box {
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
  // D2 grid layout doesn't enforce a fixed minimum column width; if a column is
  // empty (e.g. underspecified rows/cols), fall back to the engine default.
  for i = 0; i < widths.length(); i = i + 1 {
    if widths[i] <= 0.0 {
      widths[i] = config.default_width
    }
  }
  widths
}

///|
/// Compute row heights considering spans
fn compute_row_heights_with_spans(
  children : Array[Object],
  rows : Int,
  positions : Array[CellPosition],
  config : LayoutConfig,
) -> Array[Double] {
  let heights : Array[Double] = []
  for _ in 0..<rows {
    heights.push(0.0)
  }
  // First pass: handle non-spanning cells
  for i, child in children {
    if i >= positions.length() {
      continue
    }
    let pos = positions[i]
    if pos.row_span == 1 {
      let child_height = match child.box {
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
      let child_height = match child.box {
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
  for i = 0; i < heights.length(); i = i + 1 {
    if heights[i] <= 0.0 {
      heights[i] = config.default_height
    }
  }
  heights
}

///|
/// Position children in grid cells with spanning support
fn position_grid_children_with_spans(
  children : Array[Object],
  positions : Array[CellPosition],
  col_widths : Array[Double],
  row_heights : Array[Double],
  h_gap : Double,
  v_gap : Double,
  h_pad : Double,
  v_pad : Double,
  _config : LayoutConfig,
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
    let mut x = h_pad
    for j in 0..<pos.col {
      x = x + col_widths[j] + h_gap
    }
    // Calculate y position
    let mut y = v_pad
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
    child.box = Some(@graph.Box::new(x, y, width, height))
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
