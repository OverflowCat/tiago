///|
/// Rectpacking (ELK reference) whitespace elimination (phase 3).
///
/// Ported from elk-reference:
/// - p3whitespaceelimination/RectangleExpansion.java
/// - util/RectRow.expand, BlockStack.expand, Block.expand, BlockRow.expand
/// - core/util/ElkUtil.translate (content-alignment based translation)

///|
fn rp_whitespace_eliminate(
  state : RpState,
  rows : Array[RpRectRow],
  drawing_width : Double,
  drawing_height : Double,
  desired_aspect_ratio : Double,
  strategy : String,
) -> (Double, Double) {
  match strategy {
    "EQUAL_BETWEEN_STRUCTURES" => {
      rp_expand_rows(state, rows, drawing_width, 0.0)
      (drawing_width, drawing_height)
    }
    "TO_ASPECT_RATIO" => {
      let mut width = drawing_width
      let mut height = drawing_height
      let mut additional_height = 0.0
      let aspect_ratio = width / height
      if aspect_ratio < desired_aspect_ratio {
        width = height * desired_aspect_ratio
      } else {
        additional_height = additional_height +
          width / desired_aspect_ratio -
          height
        height = height + additional_height
      }
      rp_expand_rows(state, rows, width, additional_height)
      (width, height)
    }
    _ => (drawing_width, drawing_height)
  }
}

///|
fn rp_expand_rows(
  state : RpState,
  rows : Array[RpRectRow],
  drawing_width : Double,
  additional_height : Double,
) -> Unit {
  if rows.is_empty() {
    return
  }
  let height_per_row = additional_height / rows.length().to_double()
  for idx, row in rows {
    row.set_y(state, row.y + height_per_row * idx.to_double())
    row.expand(state, drawing_width, height_per_row)
  }
}

///|
fn rp_simple_ensure_stacks(
  state : RpState,
  rows : Array[RpRectRow],
  node_node_spacing : Double,
) -> Unit {
  // elk-reference SimplePlacement: put every block into its own stack.
  for row in rows {
    row.stack_ids.clear()
    for bid in row.block_ids {
      let b = state.blocks[bid]
      let sid = state.new_stack(b.x, row.y, node_node_spacing)
      row.stack_ids.push(sid)
      state.stacks[sid].add_block(state, sid, bid)
    }
  }
}

///|
fn RpRectRow::expand(
  self : RpRectRow,
  state : RpState,
  width : Double,
  additional_height : Double,
) -> Unit {
  if self.stack_ids.is_empty() {
    return
  }
  let additional_width = width - self.width
  let additional_width_per_stack = additional_width /
    self.stack_ids.length().to_double()
  for idx, sid in self.stack_ids {
    let stack = state.stacks[sid]
    let additional_height_for_stack = self.height -
      stack.height +
      additional_height
    stack.set_location(
      state,
      stack.x + idx.to_double() * additional_width_per_stack,
      stack.y,
    )
    stack.expand(state, additional_width_per_stack, additional_height_for_stack)
  }
}

///|
fn RpBlockStack::expand(
  self : RpBlockStack,
  state : RpState,
  additional_width : Double,
  additional_height : Double,
) -> Unit {
  if self.block_ids.is_empty() {
    return
  }
  let additional_height_per_block = additional_height /
    self.block_ids.length().to_double()
  for idx, bid in self.block_ids {
    let b = state.blocks[bid]
    b.set_location(b.x, b.y + idx.to_double() * additional_height_per_block)
    b.expand(
      self.width - b.width + additional_width,
      additional_height_per_block,
    )
  }
}

///|
fn RpBlock::expand(
  self : RpBlock,
  additional_width : Double,
  additional_height : Double,
) -> Unit {
  if self.rows.is_empty() {
    return
  }
  let width_for_row = self.width + additional_width
  self.width = self.width + additional_width
  self.height = self.height + additional_height
  let additional_height_for_row = additional_height /
    self.rows.length().to_double()
  for idx, row in self.rows {
    row.expand(width_for_row, additional_height_for_row, idx)
  }
}

///|
fn RpBlockRow::expand(
  self : RpBlockRow,
  width_for_row : Double,
  additional_height_for_row : Double,
  index : Int,
) -> Unit {
  if self.rects.is_empty() {
    self.width = width_for_row
    self.height = self.height + additional_height_for_row
    return
  }
  let additional_width_for_rect = (width_for_row - self.width) /
    self.rects.length().to_double()
  self.height = self.height + additional_height_for_row
  self.width = width_for_row
  let mut i = 0
  for rect in self.rects {
    let old_w = rect.width
    let old_h = rect.height
    rect.x = rect.x + i.to_double() * additional_width_for_rect
    rect.y = rect.y + index.to_double() * additional_height_for_row
    rect.width = rect.width + additional_width_for_rect
    rect.height = self.height
    rp_translate_node_contents(rect, rect.width, rect.height, old_w, old_h)
    // Keep block row bookkeeping in sync for any subsequent operations.
    i = i + 1
  }
}

///|
fn rp_translate_node_contents(
  node : ElkNode,
  new_w : Double,
  new_h : Double,
  old_w : Double,
  old_h : Double,
) -> Unit {
  // Minimal port of ElkUtil.translate(node, newSize, oldSize).
  //
  // For leaf rectangles this is a no-op, but it keeps nested content aligned if
  // present.
  let alignment = match
    node.properties.get_enum("org.eclipse.elk.contentAlignment") {
    Some(s) =>
      ContentAlignment::from_string(s).unwrap_or(ContentAlignment::None)
    None => ContentAlignment::None
  }
  let mut x_translate = 0.0
  let mut y_translate = 0.0
  if new_w > old_w {
    match alignment {
      Horizontal | HorizontalVertical => x_translate = (new_w - old_w) / 2.0
      _ => ()
    }
  }
  if new_h > old_h {
    match alignment {
      Vertical | HorizontalVertical => y_translate = (new_h - old_h) / 2.0
      _ => ()
    }
  }
  if x_translate == 0.0 && y_translate == 0.0 {
    return
  }
  rp_translate_node(node, x_translate, y_translate)
}

///|
fn rp_translate_node(node : ElkNode, xoff : Double, yoff : Double) -> Unit {
  for child in node.children {
    child.x = child.x + xoff
    child.y = child.y + yoff
  }
  for edge in node.edges {
    for section in edge.sections {
      section.start_point = ElkPoint::new(
        section.start_point.x + xoff,
        section.start_point.y + yoff,
      )
      section.end_point = ElkPoint::new(
        section.end_point.x + xoff,
        section.end_point.y + yoff,
      )
      for i, p in section.bend_points {
        section.bend_points[i] = ElkPoint::new(p.x + xoff, p.y + yoff)
      }
    }
    for label in edge.labels {
      label.x = label.x + xoff
      label.y = label.y + yoff
    }
  }
}
