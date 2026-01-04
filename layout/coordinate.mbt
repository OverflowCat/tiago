///|
/// Coordinate Assignment using Brandes-Köpf Algorithm
///
/// Implements the fourth phase of the Sugiyama framework.
/// Assigns x-coordinates to nodes to minimize edge lengths while
/// maintaining minimum separation between nodes.
///
/// The algorithm:
/// 1. Performs vertical alignment in 4 directions (up-left, up-right, down-left, down-right)
/// 2. Compacts horizontally to assign coordinates
/// 3. Takes the average of the 4 alignments for balanced positioning

///|
/// Result of coordinate assignment
pub(all) struct CoordinateResult {
  /// X-coordinate for each node
  x_coords : Map[String, Double]
  /// Y-coordinate for each node (layer position)
  y_coords : Map[String, Double]
}

///|
/// Assign coordinates to nodes using Brandes-Köpf algorithm
pub fn assign_coordinates(
  graph : @graph.Graph,
  crossing_result : CrossingResult,
  cycle_result : CycleBreakResult,
  node_widths : Map[String, Double],
  node_heights : Map[String, Double],
  horizontal_sep : Double,
  vertical_sep : Double,
) -> CoordinateResult {
  let layers = crossing_result.ordered_layers
  if layers.length() == 0 {
    return { x_coords: {}, y_coords: {} }
  }
  // Build position index for each node within its layer
  let pos : Map[String, Int] = {}
  for layer in layers {
    for i, node in layer {
      pos[node] = i
    }
  }
  // Build adjacency (upper and lower neighbors)
  let (upper_neighbors, lower_neighbors) = build_neighbors(
    graph, layers, cycle_result,
  )
  // Run 4 alignment strategies and take average
  let x1 = align_and_compact(
    layers, pos, upper_neighbors, node_widths, horizontal_sep, true, true,
  )
  let x2 = align_and_compact(
    layers, pos, upper_neighbors, node_widths, horizontal_sep, true, false,
  )
  let x3 = align_and_compact(
    layers, pos, lower_neighbors, node_widths, horizontal_sep, false, true,
  )
  let x4 = align_and_compact(
    layers, pos, lower_neighbors, node_widths, horizontal_sep, false, false,
  )
  // Average the 4 alignments
  let x_coords : Map[String, Double] = {}
  for layer in layers {
    for node in layer {
      let v1 = x1.get(node).unwrap_or(0.0)
      let v2 = x2.get(node).unwrap_or(0.0)
      let v3 = x3.get(node).unwrap_or(0.0)
      let v4 = x4.get(node).unwrap_or(0.0)
      // Use median of 4 values for robustness
      x_coords[node] = median4(v1, v2, v3, v4)
    }
  }
  // Compute dynamic rank spacing based on edge labels
  let rank_spacing = compute_dynamic_rank_spacing(
    graph, layers, vertical_sep, cycle_result,
  )
  // Assign y coordinates based on layer with dynamic spacing
  let y_coords : Map[String, Double] = {}
  let mut y = 0.0
  for i, layer in layers {
    // Find max height in this layer
    let mut max_height = 0.0
    for node in layer {
      let h = node_heights.get(node).unwrap_or(60.0)
      if h > max_height {
        max_height = h
      }
    }
    // Assign y to all nodes in layer (center of layer)
    for node in layer {
      y_coords[node] = y
    }
    // Move to next layer using dynamic spacing
    let spacing = if i < rank_spacing.length() {
      rank_spacing[i]
    } else {
      vertical_sep
    }
    y = y + max_height + spacing
  }
  { x_coords, y_coords }
}

///|
/// Compute dynamic rank spacing based on edge label heights
/// Returns an array of spacing values, one for each layer gap (layers.length()-1 values)
fn compute_dynamic_rank_spacing(
  graph : @graph.Graph,
  layers : Array[Array[String]],
  base_spacing : Double,
  cycle_result : CycleBreakResult,
) -> Array[Double] {
  if layers.length() <= 1 {
    return []
  }
  // Build layer index for each node
  let layer_idx : Map[String, Int] = {}
  for i, layer in layers {
    for node in layer {
      layer_idx[node] = i
    }
  }
  // Initialize spacing for each layer gap
  let spacing : Array[Double] = []
  for _ in 0..<(layers.length() - 1) {
    spacing.push(base_spacing)
  }
  // Check each edge and increase spacing if label is tall
  let label_padding = 10.0 // Extra padding around labels
  let char_height = 14.0 // Approximate character height (font_size)
  for edge in graph.edges {
    if edge.label == "" {
      continue
    }
    // Get source and destination layers (handle reversed edges)
    let src = get_effective_src(edge, cycle_result)
    let dst = get_effective_dst(edge, cycle_result)
    let src_layer = layer_idx.get(src).unwrap_or(-1)
    let dst_layer = layer_idx.get(dst).unwrap_or(-1)
    if src_layer < 0 || dst_layer < 0 {
      continue
    }
    // Calculate label height (simple estimate)
    let label_height = char_height + label_padding * 2.0
    // Apply to all layer gaps this edge spans
    let min_layer = if src_layer < dst_layer { src_layer } else { dst_layer }
    let max_layer = if src_layer > dst_layer { src_layer } else { dst_layer }
    for gap_idx in min_layer..<max_layer {
      if gap_idx < spacing.length() {
        // Increase spacing if label needs more room
        let required = label_height + label_padding
        if required > spacing[gap_idx] {
          spacing[gap_idx] = required
        }
      }
    }
  }
  spacing
}

///|
/// Build upper and lower neighbor maps
fn build_neighbors(
  graph : @graph.Graph,
  layers : Array[Array[String]],
  cycle_result : CycleBreakResult,
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let upper : Map[String, Array[String]] = {}
  let lower : Map[String, Array[String]] = {}
  // Build layer index for each node
  let layer_idx : Map[String, Int] = {}
  for i, layer in layers {
    for node in layer {
      layer_idx[node] = i
      upper[node] = []
      lower[node] = []
    }
  }
  // Add edges
  for edge in graph.edges {
    let src = get_effective_src(edge, cycle_result)
    let dst = get_effective_dst(edge, cycle_result)
    let src_layer = layer_idx.get(src).unwrap_or(-1)
    let dst_layer = layer_idx.get(dst).unwrap_or(-1)
    if src_layer >= 0 && dst_layer >= 0 && src_layer < dst_layer {
      // src is upper neighbor of dst
      match upper.get(dst) {
        Some(arr) => arr.push(src)
        None => ()
      }
      // dst is lower neighbor of src
      match lower.get(src) {
        Some(arr) => arr.push(dst)
        None => ()
      }
    }
  }
  (upper, lower)
}

///|
/// Perform vertical alignment and horizontal compaction
fn align_and_compact(
  layers : Array[Array[String]],
  pos : Map[String, Int],
  neighbors : Map[String, Array[String]],
  node_widths : Map[String, Double],
  sep : Double,
  top_down : Bool,
  left_to_right : Bool,
) -> Map[String, Double] {
  // Step 1: Vertical alignment - find root and align for each node
  let root : Map[String, String] = {}
  let align : Map[String, String] = {}
  // Initialize: each node is its own root and aligned to itself
  for layer in layers {
    for node in layer {
      root[node] = node
      align[node] = node
    }
  }
  // Process layers in order
  let layer_order = if top_down {
    range(0, layers.length())
  } else {
    range_rev(0, layers.length())
  }
  for layer_i in layer_order {
    let layer = layers[layer_i]
    let mut r = if left_to_right { -1 } else { layer.length() }
    // Process nodes in order within layer
    let node_order = if left_to_right {
      range(0, layer.length())
    } else {
      range_rev(0, layer.length())
    }
    for node_i in node_order {
      let v = layer[node_i]
      let v_neighbors = neighbors.get(v).unwrap_or([])
      if v_neighbors.length() > 0 {
        // Find median neighbor(s)
        let sorted_neighbors = sort_by_pos(v_neighbors, pos)
        let mid = (sorted_neighbors.length() - 1) / 2
        let medians = if sorted_neighbors.length() % 2 == 1 {
          [sorted_neighbors[mid]]
        } else {
          [sorted_neighbors[mid], sorted_neighbors[mid + 1]]
        }
        // Try to align with median neighbor
        for m in medians {
          if align.get(v).unwrap_or("") == v {
            let m_pos = pos.get(m).unwrap_or(0)
            // Check if we can align (no conflict)
            let can_align = if left_to_right { r < m_pos } else { r > m_pos }
            if can_align {
              align[m] = v
              root[v] = root.get(m).unwrap_or(m)
              align[v] = root.get(v).unwrap_or(v)
              r = m_pos
            }
          }
        }
      }
    }
  }
  // Step 2: Horizontal compaction
  let x : Map[String, Double] = {}
  let sink : Map[String, String] = {}
  let shift : Map[String, Double] = {}
  // Initialize
  for layer in layers {
    for node in layer {
      sink[node] = node
      shift[node] = 1.0e10 // infinity
    }
  }
  // Place blocks
  for layer in layers {
    let node_order = if left_to_right {
      range(0, layer.length())
    } else {
      range_rev(0, layer.length())
    }
    for node_i in node_order {
      let v = layer[node_i]
      let v_root = root.get(v).unwrap_or(v)
      if v_root == v {
        place_block(
          v, x, sink, shift, root, align, pos, node_widths, sep, layers, left_to_right,
        )
      }
    }
  }
  // Apply shifts
  for layer in layers {
    for v in layer {
      let v_root = root.get(v).unwrap_or(v)
      x[v] = x.get(v_root).unwrap_or(0.0)
      let v_sink = sink.get(v_root).unwrap_or(v_root)
      let s = shift.get(v_sink).unwrap_or(1.0e10)
      if s < 1.0e10 && v_sink != v_root {
        x[v] = x.get(v).unwrap_or(0.0) + s
      }
    }
  }
  x
}

///|
/// Place a block of aligned nodes
fn place_block(
  v : String,
  x : Map[String, Double],
  sink : Map[String, String],
  shift : Map[String, Double],
  root : Map[String, String],
  align : Map[String, String],
  pos : Map[String, Int],
  node_widths : Map[String, Double],
  sep : Double,
  layers : Array[Array[String]],
  left_to_right : Bool,
) -> Unit {
  // Skip if already placed
  if x.get(v) is Some(_) {
    return
  }
  x[v] = 0.0
  let mut w = v
  let mut done = false
  while not(done) {
    let w_pos = pos.get(w).unwrap_or(0)
    // Find predecessor in same layer
    let pred_pos = if left_to_right { w_pos - 1 } else { w_pos + 1 }
    let w_layer = find_layer(w, layers)
    if w_layer >= 0 && pred_pos >= 0 && pred_pos < layers[w_layer].length() {
      let u = layers[w_layer][pred_pos]
      let u_root = root.get(u).unwrap_or(u)
      place_block(
        u_root, x, sink, shift, root, align, pos, node_widths, sep, layers, left_to_right,
      )
      if sink.get(v).unwrap_or(v) == v {
        sink[v] = sink.get(u_root).unwrap_or(u_root)
      }
      let u_width = node_widths.get(u).unwrap_or(100.0)
      let delta = u_width + sep
      if sink.get(v).unwrap_or(v) != sink.get(u_root).unwrap_or(u_root) {
        let u_root_x = x.get(u_root).unwrap_or(0.0)
        let v_x = x.get(v).unwrap_or(0.0)
        let diff = if left_to_right {
          v_x - u_root_x - delta
        } else {
          u_root_x - v_x - delta
        }
        let u_root_sink = sink.get(u_root).unwrap_or(u_root)
        let old_shift = shift.get(u_root_sink).unwrap_or(1.0e10)
        if diff < old_shift {
          shift[u_root_sink] = diff
        }
      } else {
        let u_root_x = x.get(u_root).unwrap_or(0.0)
        let new_x = if left_to_right {
          u_root_x + delta
        } else {
          u_root_x - delta
        }
        if left_to_right {
          if new_x > x.get(v).unwrap_or(0.0) {
            x[v] = new_x
          }
        } else if new_x < x.get(v).unwrap_or(0.0) {
          x[v] = new_x
        }
      }
    }
    // Move to next node in alignment
    w = align.get(w).unwrap_or(w)
    if w == v {
      done = true
    }
  }
}

///|
/// Find layer index for a node
fn find_layer(node : String, layers : Array[Array[String]]) -> Int {
  for i, layer in layers {
    if layer.contains(node) {
      return i
    }
  }
  -1
}

///|
/// Sort nodes by their position
fn sort_by_pos(nodes : Array[String], pos : Map[String, Int]) -> Array[String] {
  let result = nodes.copy()
  // Insertion sort
  for i = 1; i < result.length(); i = i + 1 {
    let key = result[i]
    let key_pos = pos.get(key).unwrap_or(0)
    let mut j = i - 1
    while j >= 0 {
      let j_pos = pos.get(result[j]).unwrap_or(0)
      if j_pos > key_pos {
        result[j + 1] = result[j]
        j = j - 1
      } else {
        break
      }
    }
    result[j + 1] = key
  }
  result
}

///|
/// Generate range [start, end)
fn range(start : Int, end : Int) -> Array[Int] {
  let result : Array[Int] = []
  for i = start; i < end; i = i + 1 {
    result.push(i)
  }
  result
}

///|
/// Generate reversed range [start, end) -> [end-1, ..., start]
fn range_rev(start : Int, end : Int) -> Array[Int] {
  let result : Array[Int] = []
  for i = end - 1; i >= start; i = i - 1 {
    result.push(i)
  }
  result
}

///|
/// Compute median of 4 values
fn median4(a : Double, b : Double, c : Double, d : Double) -> Double {
  // Sort the 4 values and take average of middle 2
  let arr = [a, b, c, d]
  // Simple bubble sort for 4 elements
  for i = 0; i < 4; i = i + 1 {
    for j = 0; j < 3 - i; j = j + 1 {
      if arr[j] > arr[j + 1] {
        let tmp = arr[j]
        arr[j] = arr[j + 1]
        arr[j + 1] = tmp
      }
    }
  }
  // Return average of middle two
  (arr[1] + arr[2]) / 2.0
}

///|
/// Simple coordinate assignment (fallback)
/// Places nodes sequentially within each layer
pub fn assign_coordinates_simple(
  crossing_result : CrossingResult,
  node_widths : Map[String, Double],
  node_heights : Map[String, Double],
  horizontal_sep : Double,
  vertical_sep : Double,
  padding : Double,
) -> CoordinateResult {
  let x_coords : Map[String, Double] = {}
  let y_coords : Map[String, Double] = {}
  let mut y = padding
  for layer in crossing_result.ordered_layers {
    let mut x = padding
    let mut max_height = 0.0
    for node in layer {
      x_coords[node] = x
      y_coords[node] = y
      let w = node_widths.get(node).unwrap_or(100.0)
      let h = node_heights.get(node).unwrap_or(60.0)
      x = x + w + horizontal_sep
      if h > max_height {
        max_height = h
      }
    }
    y = y + max_height + vertical_sep
  }
  { x_coords, y_coords }
}
