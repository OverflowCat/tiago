///|
/// Minimal port of elk-reference `org.eclipse.elk.core.util.BoxLayoutProvider`
/// (simple packing mode only).
///
/// This is used by rectpacking's `trybox` fallback.

///|
fn elk_box_layout_provider_simple(
  graph : ElkNode,
  options : LayoutOptions,
) -> Unit {
  // Defaults from elk-reference BoxLayoutProvider.
  let obj_spacing = options.node_node_spacing.unwrap_or(0.0)
  let padding = options.padding.unwrap_or(ElkPadding::zero())
  let interactive = options.interactive.unwrap_or(false)
  let mut expand_nodes = false
  match options.custom {
    Some(custom) =>
      match custom.get("org.eclipse.elk.box.expandNodes") {
        Some(PropertyValue::Bool(v)) => expand_nodes = v
        _ => ()
      }
    None => ()
  }
  let mut aspect_ratio = options.aspect_ratio.unwrap_or(1.3)
  if aspect_ratio <= 0.0 {
    aspect_ratio = 1.3
  }
  ensure_sizes(graph, options)

  // Sort nodes (priority desc; then position if interactive; else area asc).
  let sorted : Array[ElkNode] = []
  for n in graph.children {
    sorted.push(n)
  }
  sorted.sort_by(fn(a, b) {
    let prio_a = a.properties.get_int("org.eclipse.elk.priority").unwrap_or(0)
    let prio_b = b.properties.get_int("org.eclipse.elk.priority").unwrap_or(0)
    if prio_a > prio_b {
      -1
    } else if prio_a < prio_b {
      1
    } else if interactive {
      if a.y < b.y {
        -1
      } else if a.y > b.y {
        1
      } else if a.x < b.x {
        -1
      } else if a.x > b.x {
        1
      } else {
        0
      }
    } else {
      let size_a = a.width * a.height
      let size_b = b.width * b.height
      if size_a < size_b {
        -1
      } else if size_a > size_b {
        1
      } else {
        0
      }
    }
  })
  let (parent_w, parent_h) = box_place_boxes(
    sorted, obj_spacing, padding, 0.0, 0.0, expand_nodes, aspect_ratio,
  )
  graph.width = parent_w
  graph.height = parent_h
}

///|
fn box_place_boxes(
  sorted_boxes : Array[ElkNode],
  min_spacing : Double,
  padding : ElkPadding,
  min_total_width : Double,
  min_total_height : Double,
  expand_nodes : Bool,
  aspect_ratio : Double,
) -> (Double, Double) {
  // Determine the maximal row width by the maximal box width and the total area.
  let mut max_row_width = 0.0
  let mut total_area = 0.0
  for box in sorted_boxes {
    max_row_width = max_double(max_row_width, box.width)
    total_area = total_area + box.width * box.height
  }

  // Std deviation influence (elk-reference: add n * 1 * stddev to area).
  let mean = if sorted_boxes.is_empty() {
    0.0
  } else {
    total_area / sorted_boxes.length().to_double()
  }
  let stddev = box_area_stddev(sorted_boxes, mean)
  total_area = total_area + sorted_boxes.length().to_double() * stddev

  // Add padding influence to total area (ported as-is).
  if total_area > 0.0 {
    let s = total_area.sqrt()
    total_area = total_area + s * (padding.bottom + padding.top)
    total_area = total_area + s * padding.right
  }

  // Calculate required row width to achieve the desired aspect ratio.
  max_row_width = max_double(max_row_width, (total_area * aspect_ratio).sqrt()) +
    padding.left

  // Place nodes iteratively into rows.
  let mut xpos = padding.left
  let mut ypos = padding.top
  let mut highest_box = 0.0
  let mut broadest_row = padding.left + padding.right
  let row_starts : Array[Int] = [0]
  let row_heights : Array[Double] = []
  for i, box in sorted_boxes {
    let w = box.width
    let h = box.height
    if xpos + w > max_row_width {
      if expand_nodes {
        row_heights.push(highest_box)
        row_starts.push(i)
      }
      xpos = padding.left
      ypos = ypos + highest_box + min_spacing
      highest_box = 0.0
      broadest_row = max_double(broadest_row, padding.left + padding.right + w)
    }
    box.x = xpos
    box.y = ypos
    broadest_row = max_double(broadest_row, xpos + w + padding.right)
    highest_box = max_double(highest_box, h)
    xpos = xpos + w + min_spacing
  }
  broadest_row = max_double(broadest_row, min_total_width)
  let mut total_height = ypos + highest_box + padding.bottom
  if total_height < min_total_height {
    highest_box = highest_box + (min_total_height - total_height)
    total_height = min_total_height
  }

  // Expand nodes if required (not used by rectpacking's trybox path).
  if expand_nodes {
    row_starts.push(sorted_boxes.length())
    row_heights.push(highest_box)
    let mut row_idx = 0
    while row_idx + 1 < row_starts.length() {
      let start = row_starts[row_idx]
      let end = row_starts[row_idx + 1]
      let row_height = row_heights[row_idx]
      let mut i = start
      while i < end {
        let box = sorted_boxes[i]
        let old_h = box.height
        box.height = row_height
        let new_h = row_height
        if i == end - 1 {
          let new_w = broadest_row - box.x - padding.right
          let old_w = box.width
          box.width = new_w
          rp_translate_node_contents(box, new_w, new_h, old_w, old_h)
        }
        i = i + 1
      }
      row_idx = row_idx + 1
    }
  }
  (broadest_row, total_height)
}

///|
fn box_area_stddev(boxes : Array[ElkNode], mean : Double) -> Double {
  // elk-reference BoxLayoutProvider.areaStdDev
  if boxes.length() <= 1 {
    return 0.0
  }
  let mut variance = 0.0
  for box in boxes {
    let area = box.width * box.height
    let diff = area - mean
    variance = variance + diff * diff
  }
  (variance / (boxes.length() - 1).to_double()).sqrt()
}
