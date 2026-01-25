///|
/// Rectpacking (ELK reference) compaction logic.
///
/// This file ports the core of elk-reference rectpacking phase 2 (initial
/// placement + compaction) used by `CompactionTest.java`.

///|
priv struct RpBlockRow {
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  node_node_spacing : Double
  rects : Array[ElkNode]
}

///|
fn RpBlockRow::new(
  x : Double,
  y : Double,
  node_node_spacing : Double,
) -> RpBlockRow {
  { x, y, width: 0.0, height: 0.0, node_node_spacing, rects: [] }
}

///|
fn RpBlockRow::add_rectangle(self : RpBlockRow, rect : ElkNode) -> Bool {
  rect.x = self.x +
    self.width +
    (if self.rects.is_empty() { 0.0 } else { self.node_node_spacing })
  rect.y = self.y
  self.height = max_double(self.height, rect.height)
  self.width = self.width +
    rect.width +
    (if self.rects.is_empty() { 0.0 } else { self.node_node_spacing })
  self.rects.push(rect)
  true
}

///|
fn RpBlockRow::remove_rectangle(
  self : RpBlockRow,
  rect : ElkNode,
  update : Bool,
) -> Unit {
  for i, r in self.rects {
    if r.id == rect.id {
      self.rects.remove(i) |> ignore
      break
    }
  }
  if update {
    self.update_row()
  }
}

///|
fn RpBlockRow::update_row(self : RpBlockRow) -> Unit {
  let mut width = 0.0
  let mut height = 0.0
  for rect in self.rects {
    rect.x = self.x + width
    rect.y = self.y
    width = width + rect.width + self.node_node_spacing
    height = max_double(height, rect.height + self.node_node_spacing)
  }
  self.width = if self.rects.is_empty() {
    0.0
  } else {
    width - self.node_node_spacing
  }
  self.height = if self.rects.is_empty() {
    0.0
  } else {
    height - self.node_node_spacing
  }
}

///|
priv struct RpBlock {
  mut smallest_rect_width : Double
  mut min_width : Double
  mut width : Double
  mut min_height : Double
  mut smallest_rect_height : Double
  mut average_height : Double
  mut max_height : Double
  mut height : Double
  children : Array[ElkNode]
  rows : Array[RpBlockRow]
  mut x : Double
  mut y : Double
  mut parent_row_id : Int
  mut stack_id : Int?
  node_node_spacing : Double
  mut fixed : Bool
  mut position_fixed : Bool
}

///|
fn RpBlock::new(
  x : Double,
  y : Double,
  parent_row_id : Int,
  node_node_spacing : Double,
) -> RpBlock {
  {
    smallest_rect_width: @double.infinity,
    min_width: 0.0,
    width: 0.0,
    min_height: 0.0,
    smallest_rect_height: @double.infinity,
    average_height: 0.0,
    max_height: 0.0,
    height: 0.0,
    children: [],
    rows: [],
    x,
    y,
    parent_row_id,
    stack_id: None,
    node_node_spacing,
    fixed: false,
    position_fixed: false,
  }
}

///|
fn RpBlock::add_child(
  self : RpBlock,
  state : RpState,
  rows : Array[RpRectRow],
  rect : ElkNode,
) -> Unit {
  if self.rows.is_empty() {
    self.rows.push(RpBlockRow::new(self.x, self.y, self.node_node_spacing))
  }
  self.children.push(rect)
  self.rows[self.rows.length() - 1].add_rectangle(rect) |> ignore
  self.adjust_size_add(state, rows, rect)
}

///|
fn RpBlock::add_child_in_new_row(
  self : RpBlock,
  state : RpState,
  rows : Array[RpRectRow],
  rect : ElkNode,
) -> Unit {
  self.children.push(rect)
  let last_row = self.get_last_row()
  self.rows.push(
    RpBlockRow::new(
      self.x,
      last_row.y + last_row.height + self.node_node_spacing,
      self.node_node_spacing,
    ),
  )
  self.rows[self.rows.length() - 1].add_rectangle(rect) |> ignore
  self.adjust_size_add(state, rows, rect)
}

///|
fn RpBlock::remove_child(
  self : RpBlock,
  state : RpState,
  rows : Array[RpRectRow],
  rect : ElkNode,
) -> Unit {
  // Remove from children list.
  for i, r in self.children {
    if r.id == rect.id {
      self.children.remove(i) |> ignore
      break
    }
  }
  // Remove from block rows.
  let mut row_to_delete : Int? = None
  for i, row in self.rows {
    let mut found = false
    for r in row.rects {
      if r.id == rect.id {
        found = true
        break
      }
    }
    if found {
      row.remove_rectangle(rect, true)
      if row.rects.is_empty() {
        row_to_delete = Some(i)
      }
      break
    }
  }
  match row_to_delete {
    Some(i) => self.rows.remove(i) |> ignore
    None => ()
  }
  self.adjust_size_after_remove(state, rows)
}

///|
fn RpBlock::set_location(self : RpBlock, x : Double, y : Double) -> Unit {
  let x_change = x - self.x
  let y_change = y - self.y
  // Shift children.
  for rect in self.children {
    rect.x = rect.x + x_change
    rect.y = rect.y + y_change
  }
  // Shift row origins.
  for row in self.rows {
    row.x = row.x + x_change
    row.y = row.y + y_change
  }
  self.x = x
  self.y = y
}

///|
fn RpBlock::get_last_row(self : RpBlock) -> RpBlockRow {
  self.rows[self.rows.length() - 1]
}

///|
fn RpBlock::adjust_size_add(
  self : RpBlock,
  state : RpState,
  rows : Array[RpRectRow],
  rect : ElkNode,
) -> Unit {
  let width_of_last_row = self.get_last_row().width
  self.smallest_rect_width = min_double(self.smallest_rect_width, rect.width)
  self.width = max_double(self.width, width_of_last_row)
  self.min_width = max_double(
    self.min_width,
    rect.width +
    (if self.children.length() == 1 { 0.0 } else { self.node_node_spacing }),
  )
  self.smallest_rect_height = min_double(self.smallest_rect_height, rect.height)
  self.max_height = self.max_height +
    rect.height +
    (if self.children.length() == 1 { 0.0 } else { self.node_node_spacing })
  self.min_height = max_double(self.min_height, rect.height)
  let mut total_height = if self.rows.length() > 0 {
    (self.rows.length() - 1).to_double() * self.node_node_spacing
  } else {
    0.0
  }
  for row in self.rows {
    total_height = total_height + row.height
  }
  self.height = total_height
  self.average_height = self.max_height / self.children.length().to_double() -
    self.node_node_spacing *
    (
      (self.children.length() - 1).to_double() /
      self.children.length().to_double()
    )
  rows[self.parent_row_id].notify_about_node_change(state)
}

///|
priv struct RpBounds {
  width : Double
  height : Double
}

///|
fn RpBlock::place_rects_in(
  self : RpBlock,
  state : RpState,
  rows : Array[RpRectRow],
  width : Double,
  place_rects : Bool,
) -> RpBounds {
  let mut current_x = 0.0
  let mut current_y = self.y
  let mut current_width = 0.0
  let mut current_height = 0.0
  let mut max_height_in_row = 0.0
  let mut width_in_row = 0.0
  let mut row_idx = 0
  if place_rects {
    self.rows.clear()
    self.rows.push(RpBlockRow::new(self.x, self.y, self.node_node_spacing))
  }
  let mut index_in_row = 0
  for rect in self.children {
    if current_x +
      rect.width +
      (if index_in_row > 0 { self.node_node_spacing } else { 0.0 }) >
      width &&
      max_height_in_row > 0.0 {
      // New row.
      current_x = 0.0
      current_y = current_y + max_height_in_row + self.node_node_spacing
      current_width = max_double(current_width, width_in_row)
      current_height = current_height +
        max_height_in_row +
        self.node_node_spacing
      max_height_in_row = 0.0
      width_in_row = 0.0
      if place_rects {
        row_idx = row_idx + 1
        self.rows.push(
          RpBlockRow::new(self.x, current_y, self.node_node_spacing),
        )
      }
      index_in_row = 0
    }
    width_in_row = width_in_row +
      rect.width +
      (if index_in_row > 0 { self.node_node_spacing } else { 0.0 })
    max_height_in_row = max_double(max_height_in_row, rect.height)
    if place_rects {
      self.rows[row_idx].add_rectangle(rect) |> ignore
    }
    current_x = current_x +
      rect.width +
      (if index_in_row > 0 { self.node_node_spacing } else { 0.0 })
    index_in_row = index_in_row + 1
  }
  current_width = max_double(current_width, width_in_row)
  current_height = current_height + max_height_in_row
  if place_rects {
    self.width = current_width
    self.height = current_height
    rows[self.parent_row_id].notify_about_node_change(state)
  }
  { width: current_width, height: current_height }
}

///|
fn RpBlock::place_rects_in_width(
  self : RpBlock,
  state : RpState,
  rows : Array[RpRectRow],
  width : Double,
) -> Bool {
  let old_width = self.width
  let old_height = self.height
  let bounds = self.place_rects_in(state, rows, width, true)
  bounds.width != old_width || bounds.height != old_height
}

///|
fn RpBlock::place_rects_in_width_height(
  self : RpBlock,
  state : RpState,
  rows : Array[RpRectRow],
  width : Double,
  height : Double,
  place_rects : Bool,
) -> Bool {
  let bounds = self.place_rects_in(state, rows, width, place_rects)
  bounds.width <= width && bounds.height <= height
}

///|
fn RpBlock::get_height_for_target_width(
  self : RpBlock,
  state : RpState,
  rows : Array[RpRectRow],
  width : Double,
) -> Double {
  self.place_rects_in(state, rows, width, false).height
}

///|
fn RpBlock::get_width_for_target_height(
  self : RpBlock,
  state : RpState,
  rows : Array[RpRectRow],
  height : Double,
) -> Double {
  if self.max_height <= height {
    return self.min_width
  }
  if self.place_rects_in_width_height(
      state,
      rows,
      self.min_width,
      height,
      false,
    ) {
    return self.min_width
  }
  let mut upper_bound = self.width
  let mut lower_bound = self.min_width
  let mut viable_width = self.width
  let mut new_width = (upper_bound - lower_bound) / 2.0 + lower_bound
  while lower_bound + 1.0 < upper_bound {
    if self.place_rects_in_width_height(state, rows, new_width, height, false) {
      viable_width = new_width
      upper_bound = new_width
    } else {
      lower_bound = new_width
    }
    new_width = (upper_bound - lower_bound) / 2.0 + lower_bound
  }
  viable_width
}

///|
fn RpBlock::adjust_size_after_remove(
  self : RpBlock,
  state : RpState,
  rows : Array[RpRectRow],
) -> Unit {
  let mut new_width = 0.0
  let mut new_height = 0.0
  let rows_to_delete : Array[Int] = []
  for i, row in self.rows {
    if row.rects.is_empty() {
      rows_to_delete.push(i)
    } else {
      new_width = max_double(new_width, row.width)
      new_height = new_height +
        row.height +
        (if i > 0 { self.node_node_spacing } else { 0.0 })
    }
  }
  // Remove empty rows from back to front.
  if !rows_to_delete.is_empty() {
    rows_to_delete.sort_by(fn(a, b) { b.compare(a) })
    for idx in rows_to_delete {
      self.rows.remove(idx) |> ignore
    }
  }
  self.height = new_height
  self.width = new_width

  // Recalculate smallest/biggest rectangle, min/max widths and heights.
  self.min_width = 0.0
  self.min_height = 0.0
  self.max_height = 0.0
  self.smallest_rect_height = @double.infinity
  self.smallest_rect_width = @double.infinity
  for rect in self.children {
    self.smallest_rect_width = min_double(self.smallest_rect_width, rect.width)
    self.min_width = max_double(self.min_width, rect.width)
    self.min_height = max_double(self.min_height, rect.height)
    self.smallest_rect_height = min_double(
      self.smallest_rect_height,
      rect.height,
    )
    self.max_height = self.max_height + rect.height + self.node_node_spacing
  }
  if self.children.is_empty() {
    self.average_height = 0.0
  } else {
    self.average_height = self.max_height / self.children.length().to_double() -
      self.node_node_spacing *
      (
        (self.children.length() - 1).to_double() /
        self.children.length().to_double()
      )
  }
  rows[self.parent_row_id].notify_about_node_change(state)
}

///|
fn RpBlockStack::get_width_for_fixed_height(
  self : RpBlockStack,
  state : RpState,
  rows : Array[RpRectRow],
  height : Double,
) -> Double {
  if self.block_ids.length() == 1 {
    let b = state.blocks[self.block_ids[0]]
    return b.get_width_for_target_height(state, rows, height)
  }
  let mut min_width = 0.0
  for bid in self.block_ids {
    min_width = max_double(min_width, state.blocks[bid].min_width)
  }
  let mut upper_bound = self.width
  let mut lower_bound = min_width
  let mut viable_width = self.width
  let mut new_width = (upper_bound - lower_bound) / 2.0 + lower_bound
  while lower_bound + 1.0 < upper_bound {
    let mut total_height = 0.0
    for bid in self.block_ids {
      total_height = total_height +
        state.blocks[bid].get_height_for_target_width(state, rows, new_width)
    }
    if total_height < height {
      viable_width = new_width
      upper_bound = new_width
    } else {
      lower_bound = new_width
    }
    new_width = (upper_bound - lower_bound) / 2.0 + lower_bound
  }
  viable_width
}

///|
fn RpBlockStack::place_rects_in(
  self : RpBlockStack,
  state : RpState,
  rows : Array[RpRectRow],
  target_width : Double,
) -> Unit {
  let mut current_y = self.y
  let mut current_height = 0.0
  let mut current_width = 0.0
  for bid in self.block_ids {
    let b = state.blocks[bid]
    b.set_location(self.x, current_y)
    b.place_rects_in_width(state, rows, target_width) |> ignore
    current_width = max_double(current_width, b.width)
    current_y = current_y + b.height + self.node_node_spacing
    current_height = current_y
  }
  self.width = current_width
  self.height = current_height
}

///|
fn rp_get_next_block_id(
  rows : Array[RpRectRow],
  row_id : Int,
  block_idx : Int,
  next_row_index : Int,
) -> Int? {
  if block_idx < rows[row_id].get_number_of_assigned_blocks() - 1 {
    Some(rows[row_id].block_ids[block_idx + 1])
  } else if next_row_index < rows.length() &&
    !rows[next_row_index].block_ids.is_empty() {
    Some(rows[next_row_index].block_ids[0])
  } else {
    None
  }
}

///|
fn rp_use_row_width(
  state : RpState,
  rows : Array[RpRectRow],
  block_id : Int,
  bounding_width : Double,
) -> Unit {
  let b = state.blocks[block_id]
  b.place_rects_in_width(state, rows, bounding_width - b.x) |> ignore
  match b.stack_id {
    Some(sid) => state.stacks[sid].update_dimension(state)
    None => ()
  }
}

///|
fn rp_use_row_height(
  state : RpState,
  rows : Array[RpRectRow],
  row_id : Int,
  block_id : Int,
) -> Bool {
  let b = state.blocks[block_id]
  let row = rows[row_id]
  let sid = b.stack_id.unwrap()
  let stack = state.stacks[sid]
  let previous_width = stack.width
  let mut something_was_changed = false
  if b.height < row.height {
    let target_width = stack.get_width_for_fixed_height(state, rows, row.height)
    if stack.width > target_width {
      stack.place_rects_in(state, rows, target_width)
      something_was_changed = previous_width != stack.width
    }
  }
  something_was_changed
}

///|
fn rp_absorb_blocks(
  state : RpState,
  rows : Array[RpRectRow],
  row_id : Int,
  block_id : Int,
  next_block_id : Int,
  bounding_width : Double,
  node_node_spacing : Double,
) -> Bool {
  let mut something_was_changed = false
  let next_block = state.blocks[next_block_id]
  while !next_block.children.is_empty() {
    let rect = next_block.children[0]
    if rp_place_rect_in_block(
        state, rows, row_id, block_id, rect, bounding_width, node_node_spacing,
      ) {
      something_was_changed = true
      next_block.remove_child(state, rows, rect)
    } else {
      break
    }
  }

  // Cleanup.
  if next_block.children.is_empty() {
    let parent_row_id = next_block.parent_row_id
    rows[parent_row_id].remove_block(state, next_block_id)
  }
  if something_was_changed {
    let b = state.blocks[block_id]
    match b.stack_id {
      Some(sid) => state.stacks[sid].update_dimension(state)
      None => ()
    }
  }
  something_was_changed
}

///|
fn rp_place_below(
  state : RpState,
  rows : Array[RpRectRow],
  row_id : Int,
  block_id : Int,
  next_block_id : Int,
  was_from_next_row : Bool,
  bounding_width : Double,
  next_row_index : Int,
  node_node_spacing : Double,
) -> Bool {
  let row = rows[row_id]
  let block = state.blocks[block_id]
  let next_block = state.blocks[next_block_id]
  let remaining_width = bounding_width - block.x
  let current_block_min_height = block.y -
    row.y +
    block.get_height_for_target_width(state, rows, remaining_width)
  if next_block.min_width + node_node_spacing > remaining_width {
    return false
  }
  let next_block_min_height = next_block.get_height_for_target_width(
    state, rows, remaining_width,
  )
  if current_block_min_height + node_node_spacing + next_block_min_height <=
    row.height {
    block.place_rects_in_width(state, rows, bounding_width - block.x) |> ignore
    block.fixed = true
    next_block.place_rects_in_width(state, rows, bounding_width - block.x)
    |> ignore
    next_block.set_location(block.x, block.y + block.height + node_node_spacing)
    next_block.position_fixed = true
    let sid = block.stack_id.unwrap()
    state.stacks[sid].add_block(state, sid, next_block_id)
    if was_from_next_row {
      rows[row_id].add_block(state, row_id, next_block_id)
      // Remove from next row if present.
      if next_row_index < rows.length() {
        rows[next_row_index].remove_block(state, next_block_id)
        if rows[next_row_index].block_ids.is_empty() {
          rows.remove(next_row_index) |> ignore
          rp_fix_block_parent_row_ids_from(state, rows, next_row_index)
        }
      }
    }
    return true
  }
  false
}

///|
fn rp_place_beside(
  state : RpState,
  rows : Array[RpRectRow],
  row_id : Int,
  block_id : Int,
  next_block_id : Int,
  bounding_width : Double,
  next_row_index : Int,
  node_node_spacing : Double,
  row_height_reevaluation : Bool,
) -> Bool {
  let row = rows[row_id]
  let block = state.blocks[block_id]
  let next_block = state.blocks[next_block_id]
  let stack_id = block.stack_id.unwrap()
  let stack = state.stacks[stack_id]
  let available_height = row.y + row.height - stack.y
  let current_block_min_width = stack.get_width_for_fixed_height(
    state, rows, available_height,
  )
  let should_row_height_be_reevaluated = next_block.min_height > row.height &&
    row_height_reevaluation
  let mut target_width_of_next_block = bounding_width -
    (stack.x + current_block_min_width - node_node_spacing)
  let next_block_height = next_block.get_height_for_target_width(
    state, rows, target_width_of_next_block,
  )
  if should_row_height_be_reevaluated &&
    next_block_height > next_block.min_height {
    return false
  }
  if should_row_height_be_reevaluated {
    let mut potential_width = 0.0
    for sid in row.stack_ids {
      potential_width = potential_width +
        state.stacks[sid].get_width_for_fixed_height(
          state,
          rows,
          next_block.min_height,
        ) +
        node_node_spacing
    }
    target_width_of_next_block = bounding_width - potential_width
  }
  if target_width_of_next_block < next_block.min_width {
    return false
  }
  let last_row_optimization = next_row_index == rows.length() - 1 &&
    target_width_of_next_block >= rows[next_row_index].width
  if !should_row_height_be_reevaluated &&
    next_block_height > row.height &&
    !last_row_optimization {
    return false
  }
  if last_row_optimization ||
    should_row_height_be_reevaluated ||
    next_block_height <= row.height {
    if last_row_optimization && next_block_height > row.height {
      block.height = next_block_height
      let w = block.get_width_for_target_height(state, rows, next_block_height)
      block.place_rects_in_width(state, rows, w) |> ignore
    } else {
      stack.place_rects_in(state, rows, current_block_min_width)
      block.fixed = true
    }
    next_block.place_rects_in_width(
      state,
      rows,
      bounding_width - (block.x + block.width),
    )
    |> ignore
    next_block.set_location(stack.x + stack.width, row.y)
    rows[row_id].add_block(state, row_id, next_block_id)
    if next_row_index < rows.length() {
      rows[next_row_index].remove_block(state, next_block_id)
      if rows[next_row_index].block_ids.is_empty() {
        rows.remove(next_row_index) |> ignore
        rp_fix_block_parent_row_ids_from(state, rows, next_row_index)
      }
    }
    return true
  }
  false
}

///|
fn rp_compact(
  state : RpState,
  rows : Array[RpRectRow],
  row_id : Int,
  bounding_width : Double,
  node_node_spacing : Double,
  row_height_reevaluation : Bool,
) -> (Bool, Bool) {
  let mut something_was_changed = false
  let mut compact_row_again = false
  let next_row_index = row_id + 1
  let mut current_stack_id : Int? = None

  // Ensure stacks list starts clean for this run.
  rows[row_id].stack_ids.clear()
  let mut block_idx = 0
  while block_idx < rows[row_id].get_number_of_assigned_blocks() {
    let block_id = rows[row_id].block_ids[block_idx]
    let block = state.blocks[block_id]
    if block.fixed {
      block_idx = block_idx + 1
      continue
    }
    if block.children.is_empty() {
      rows[row_id].remove_block(state, block_id)
      block_idx = if block_idx > 0 { block_idx - 1 } else { 0 }
      something_was_changed = true
      continue
    }
    if !block.position_fixed {
      match current_stack_id {
        Some(sid) => state.stacks[sid].update_dimension(state)
        None => ()
      }
      let x = match current_stack_id {
        None => 0.0
        Some(sid) =>
          state.stacks[sid].x + state.stacks[sid].width + node_node_spacing
      }
      let sid = state.new_stack(x, rows[row_id].y, node_node_spacing)
      current_stack_id = Some(sid)
      block.set_location(
        state.stacks[sid].x + state.stacks[sid].width,
        rows[row_id].y,
      )
      rows[row_id].stack_ids.push(sid)
      state.stacks[sid].add_block(state, sid, block_id)
      block.position_fixed = true
    }
    let mut next_block_id_opt = rp_get_next_block_id(
      rows, row_id, block_idx, next_row_index,
    )
    let mut was_from_next_row = false
    match next_block_id_opt {
      Some(nbid) =>
        was_from_next_row = state.blocks[nbid].parent_row_id != row_id
      None => ()
    }
    if next_block_id_opt is Some(next_block_id) {
      let next_block = state.blocks[next_block_id]
      if !next_block.children.is_empty() {
        rp_use_row_width(state, rows, block_id, bounding_width)
        let absorbed = rp_absorb_blocks(
          state, rows, row_id, block_id, next_block_id, bounding_width, node_node_spacing,
        )
        something_was_changed = something_was_changed || absorbed
      } else {
        rows[state.blocks[next_block_id].parent_row_id].remove_block(
          state, next_block_id,
        )
        break
      }

      // Delete empty blocks and rows after absorption.
      if state.blocks[next_block_id].children.is_empty() {
        if rows.length() > next_row_index {
          rows[next_row_index].remove_block(state, next_block_id)
        }
        next_block_id_opt = None
        while rows.length() > next_row_index &&
              rows[next_row_index].block_ids.is_empty() {
          rows.remove(next_row_index) |> ignore
          rp_fix_block_parent_row_ids_from(state, rows, next_row_index)
        }
      }
      if next_block_id_opt is None {
        if block_idx > 0 {
          block_idx = block_idx - 1
        }
        continue
      }
      let next_block_id2 = next_block_id_opt.unwrap()
      if rp_place_below(
          state, rows, row_id, block_id, next_block_id2, was_from_next_row, bounding_width,
          next_row_index, node_node_spacing,
        ) {
        something_was_changed = true
        block_idx = block_idx + 1
        continue
      }
      if was_from_next_row {
        let old_row_height = rows[row_id].height
        let next_block_min_height = state.blocks[next_block_id2].min_height
        if rp_place_beside(
            state, rows, row_id, block_id, next_block_id2, bounding_width, next_row_index,
            node_node_spacing, row_height_reevaluation,
          ) {
          something_was_changed = true
          if old_row_height < next_block_min_height {
            compact_row_again = true
            state.blocks[next_block_id2].parent_row_id = row_id
            break
          }
          block_idx = block_idx + 1
          continue
        } else if rp_use_row_height(state, rows, row_id, block_id) {
          block.fixed = true
          something_was_changed = true
          block_idx = block_idx + 1
          continue
        }
      } else if rp_use_row_height(state, rows, row_id, block_id) {
        block.fixed = true
        something_was_changed = true
        block_idx = block_idx + 1
        continue
      }
      if something_was_changed {
        block_idx = block_idx + 1
        continue
      }
    }
    if rp_use_row_height(state, rows, row_id, block_id) {
      block.fixed = true
      something_was_changed = true
      match next_block_id_opt {
        Some(nbid) => state.blocks[nbid].position_fixed = false
        None => ()
      }
      block_idx = block_idx + 1
      continue
    } else {
      let sid = block.stack_id.unwrap()
      state.stacks[sid].update_dimension(state)
    }
    block_idx = block_idx + 1
  }
  (something_was_changed, compact_row_again)
}

///|
fn rp_adjust_row_width_and_height(
  state : RpState,
  rows : Array[RpRectRow],
  row_id : Int,
) -> Unit {
  let row = rows[row_id]
  let mut max_height = 0.0
  let mut max_width = 0.0
  for i, sid in row.stack_ids {
    let stack = state.stacks[sid]
    stack.update_dimension(state)
    max_height = max_double(max_height, stack.height)
    max_width = max_width +
      stack.width +
      (if i > 0 { row.node_node_spacing } else { 0.0 })
  }
  row.height = max_height
  row.width = max_width
}

///|
fn rp_calculate_dimensions(
  rows : Array[RpRectRow],
  node_node_spacing : Double,
) -> (Double, Double) {
  let mut max_width = 0.0
  let mut total_height = 0.0
  for i, row in rows {
    max_width = max_double(max_width, row.width)
    total_height = total_height +
      row.height +
      (if i > 0 { node_node_spacing } else { 0.0 })
  }
  (max_width, total_height)
}

///|
fn rp_compact_layout(
  rectangles : Array[ElkNode],
  target_width : Double,
  node_node_spacing : Double,
) -> (Double, Double) {
  let state = RpState::new()
  rp_reset_coordinates(rectangles)
  let rows = rp_initial_place(
    state, rectangles, target_width, node_node_spacing, false,
  )
  let mut row_idx = 0
  while row_idx < rows.length() {
    if row_idx != 0 {
      let prev = rows[row_idx - 1]
      rows[row_idx].set_y(state, prev.y + prev.height + node_node_spacing)
    }
    let (_changed, compact_again) = rp_compact(
      state, rows, row_idx, target_width, node_node_spacing, false,
    )
    if compact_again {
      // Reset the row such that stacks are removed, blocks are not fixed.
      for bid in rows[row_idx].block_ids {
        let b = state.blocks[bid]
        b.fixed = false
        b.position_fixed = false
        b.stack_id = None
        b.adjust_size_after_remove(state, rows)
      }
      rows[row_idx].reset_stacks()
      rows[row_idx].width = target_width
      if row_idx > 0 {
        row_idx = row_idx - 1
      }
      continue
    } else {
      rp_adjust_row_width_and_height(state, rows, row_idx)
    }
    row_idx = row_idx + 1
  }
  rp_calculate_dimensions(rows, node_node_spacing)
}

///|
priv struct RpBlockStack {
  block_ids : Array[Int]
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  node_node_spacing : Double
}

///|
fn RpBlockStack::new(
  x : Double,
  y : Double,
  node_node_spacing : Double,
) -> RpBlockStack {
  { block_ids: [], x, y, width: 0.0, height: 0.0, node_node_spacing }
}

///|
fn RpBlockStack::add_block(
  self : RpBlockStack,
  state : RpState,
  stack_id : Int,
  block_id : Int,
) -> Unit {
  state.blocks[block_id].stack_id = Some(stack_id)
  self.width = max_double(self.width, state.blocks[block_id].width)
  self.height = self.height +
    state.blocks[block_id].height +
    (if self.block_ids.is_empty() { 0.0 } else { self.node_node_spacing })
  self.block_ids.push(block_id)
}

///|
fn RpBlockStack::update_dimension(self : RpBlockStack, state : RpState) -> Unit {
  let mut height = 0.0
  let mut width = 0.0
  for i, bid in self.block_ids {
    let b = state.blocks[bid]
    width = max_double(width, b.width)
    height = height +
      b.height +
      (if i > 0 { self.node_node_spacing } else { 0.0 })
  }
  self.height = height
  self.width = width
}

///|
fn RpBlockStack::set_location(
  self : RpBlockStack,
  state : RpState,
  x : Double,
  y : Double,
) -> Unit {
  let x_diff = x - self.x
  let y_diff = y - self.y
  for bid in self.block_ids {
    let b = state.blocks[bid]
    b.set_location(b.x + x_diff, b.y + y_diff)
  }
  self.x = x
  self.y = y
}

///|
priv struct RpRectRow {
  mut height : Double
  mut width : Double
  mut y : Double
  node_node_spacing : Double
  block_ids : Array[Int]
  stack_ids : Array[Int]
}

///|
fn RpRectRow::new(y : Double, node_node_spacing : Double) -> RpRectRow {
  {
    height: 0.0,
    width: 0.0,
    y,
    node_node_spacing,
    block_ids: [],
    stack_ids: [],
  }
}

///|
priv struct RpState {
  blocks : Array[RpBlock]
  stacks : Array[RpBlockStack]
}

///|
fn RpState::new() -> RpState {
  { blocks: [], stacks: [] }
}

///|
fn RpState::new_block(
  self : RpState,
  x : Double,
  y : Double,
  parent_row_id : Int,
  node_node_spacing : Double,
) -> Int {
  let id = self.blocks.length()
  self.blocks.push(RpBlock::new(x, y, parent_row_id, node_node_spacing))
  id
}

///|
fn RpState::new_stack(
  self : RpState,
  x : Double,
  y : Double,
  node_node_spacing : Double,
) -> Int {
  let id = self.stacks.length()
  self.stacks.push(RpBlockStack::new(x, y, node_node_spacing))
  id
}

///|
fn rp_fix_block_parent_row_ids_from(
  state : RpState,
  rows : Array[RpRectRow],
  start_row_idx : Int,
) -> Unit {
  for ridx in start_row_idx..<rows.length() {
    for bid in rows[ridx].block_ids {
      state.blocks[bid].parent_row_id = ridx
    }
  }
}

///|
fn RpRectRow::notify_about_node_change(
  self : RpRectRow,
  state : RpState,
) -> Unit {
  let mut total_width = 0.0
  let mut new_max_height = -@double.infinity
  for i, bid in self.block_ids {
    let b = state.blocks[bid]
    total_width = total_width +
      b.width +
      (if i > 0 { self.node_node_spacing } else { 0.0 })
    new_max_height = max_double(new_max_height, b.height)
  }
  self.width = total_width
  self.height = if new_max_height == -@double.infinity {
    0.0
  } else {
    new_max_height
  }
}

///|
fn RpRectRow::add_block(
  self : RpRectRow,
  state : RpState,
  row_id : Int,
  block_id : Int,
) -> Unit {
  let b = state.blocks[block_id]
  self.height = max_double(self.height, b.height)
  self.width = self.width +
    b.width +
    (if self.block_ids.is_empty() { 0.0 } else { self.node_node_spacing })
  self.block_ids.push(block_id)
  state.blocks[block_id].parent_row_id = row_id
}

///|
fn RpRectRow::remove_block(
  self : RpRectRow,
  state : RpState,
  block_id : Int,
) -> Unit {
  let mut removed = false
  for i, bid in self.block_ids {
    if bid == block_id {
      self.block_ids.remove(i) |> ignore
      removed = true
      break
    }
  }
  if !removed {
    return
  }
  let b = state.blocks[block_id]
  self.width = self.width -
    b.width -
    (if self.block_ids.is_empty() { 0.0 } else { self.node_node_spacing })
  if self.block_ids.is_empty() {
    self.height = 0.0
  } else {
    let mut new_max_height = 0.0
    for bid in self.block_ids {
      new_max_height = max_double(new_max_height, state.blocks[bid].height)
    }
    self.height = new_max_height
  }
}

///|
fn RpRectRow::get_last_block_id(self : RpRectRow) -> Int {
  self.block_ids[self.block_ids.length() - 1]
}

///|
fn RpRectRow::get_number_of_assigned_blocks(self : RpRectRow) -> Int {
  self.block_ids.length()
}

///|
fn RpRectRow::reset_stacks(self : RpRectRow) -> Unit {
  self.stack_ids.clear()
}

///|
fn RpRectRow::set_y(self : RpRectRow, state : RpState, y : Double) -> Unit {
  let y_change = y - self.y
  for sid in self.stack_ids {
    let s = state.stacks[sid]
    s.set_location(state, s.x, s.y + y_change)
  }
  self.y = y
}

///|
fn RpBlock::get_last_row_new_x(self : RpBlock) -> Double {
  let last_row = self.get_last_row()
  last_row.x + last_row.width
}

///|
fn RpBlock::get_last_row_y(self : RpBlock) -> Double {
  self.get_last_row().y
}

///|
fn rp_is_similar_height(block : RpBlock, rect : ElkNode) -> Bool {
  if rect.height >= block.smallest_rect_height &&
    rect.height <= block.min_height {
    true
  } else {
    block.average_height * 0.5 <= rect.height &&
    block.average_height * 1.5 >= rect.height
  }
}

///|
fn rp_place_rect_in_block(
  state : RpState,
  rows : Array[RpRectRow],
  row_id : Int,
  block_id : Int,
  rect : ElkNode,
  bounding_width : Double,
  node_node_spacing : Double,
) -> Bool {
  let block = state.blocks[block_id]
  if rp_is_similar_height(block, rect) {
    if block.get_last_row_new_x() + rect.width + node_node_spacing <=
      bounding_width &&
      (
        block.get_last_row_y() - rows[row_id].y + rect.height <=
        rows[row_id].height ||
        rows[row_id].block_ids.length() == 1
      ) {
      block.add_child(state, rows, rect)
      return true
    } else if block.x + rect.width <= bounding_width &&
      block.y + block.height + rect.height + node_node_spacing <=
      rows[row_id].y + rows[row_id].height {
      block.add_child_in_new_row(state, rows, rect)
      return true
    }
  }
  false
}

///|
fn rp_reset_coordinates(rectangles : Array[ElkNode]) -> Unit {
  for node in rectangles {
    node.x = 0.0
    node.y = 0.0
  }
}

///|
fn rp_initial_place(
  state : RpState,
  rectangles : Array[ElkNode],
  bounding_width : Double,
  node_node_spacing : Double,
  row_height_reevaluation : Bool,
) -> Array[RpRectRow] {
  let rows : Array[RpRectRow] = [RpRectRow::new(0.0, node_node_spacing)]
  let mut drawing_height = 0.0
  let mut row_id = 0
  let first_block_id = state.new_block(0.0, 0.0, row_id, node_node_spacing)
  rows[row_id].add_block(state, row_id, first_block_id)
  let mut current_width = 0.0
  for rect in rectangles {
    // Check whether current rectangle can be added to the last block.
    let first_block = state.blocks[rows[row_id].block_ids[0]]
    let potential_row_width = current_width +
      rect.width +
      (if first_block.children.is_empty() { 0.0 } else { node_node_spacing })
    if potential_row_width > bounding_width {
      // Add rect in new block in new row.
      current_width = 0.0
      drawing_height = drawing_height + rows[row_id].height + node_node_spacing
      row_id = rows.length()
      rows.push(RpRectRow::new(drawing_height, node_node_spacing))
      let new_block_id = state.new_block(
        0.0,
        rows[row_id].y,
        row_id,
        node_node_spacing,
      )
      rows[row_id].add_block(state, row_id, new_block_id)
    }
    let current_block_id = rows[row_id].get_last_block_id()
    let current_block = state.blocks[current_block_id]
    if current_block.children.is_empty() ||
      (!row_height_reevaluation && rp_is_similar_height(current_block, rect)) {
      current_block.add_child(state, rows, rect)
    } else {
      // Add new block to the right of it.
      let new_x = current_block.x + current_block.width + node_node_spacing
      let new_block_id = state.new_block(
        new_x,
        rows[row_id].y,
        row_id,
        node_node_spacing,
      )
      rows[row_id].add_block(state, row_id, new_block_id)
      state.blocks[new_block_id].add_child(state, rows, rect)
    }
    current_width = rect.x + rect.width
  }
  rows
}
