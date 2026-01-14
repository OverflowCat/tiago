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

///|
/// Bridge between Graph and ELK types
/// Converts diago Graph to ELK format, runs layout, and converts back

///|
/// Clamp a value to a range [min_val, max_val]
fn clamp(value : Double, min_val : Double, max_val : Double) -> Double {
  if value < min_val {
    min_val
  } else if value > max_val {
    max_val
  } else {
    value
  }
}

///|
/// Get parent ID from a dotted object ID (e.g., "users.id" -> "users")
fn get_parent_id_from_dotted_id(id : String) -> String? {
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
    match id[i].to_char() {
      Some(c) => buf.write_char(c)
      None => ()
    }
  }
  Some(buf.to_string())
}

///|
/// Check if an object is a child of an sql_table (should not participate in ELK layout)
fn is_sql_table_child(obj : Object, graph : Graph) -> Bool {
  match get_parent_id_from_dotted_id(obj.id) {
    Some(parent_id) =>
      match graph.find_object(parent_id) {
        Some(parent) => parent.shape_type == @graph.SqlTable
        None => false
      }
    None => false
  }
}

///|
/// Convert a diago Graph to an ELK ElkNode for layout
fn graph_to_elk(graph : Graph, config : LayoutConfig) -> ElkNode {
  let root = ElkNode::new("root")

  // Convert all objects to ELK nodes
  for obj in graph.objects {
    // sql_table fields are rendered inline; exclude them from ELK layout
    if is_sql_table_child(obj, graph) {
      continue
    }
    let elk_node = object_to_elk_node(obj, config)
    root.add_child(elk_node)
  }

  // Convert all edges
  for i, edge in graph.edges {
    // For sql_table field-level connections, ELK should connect the parent tables
    let src_id = if edge.src_column_index is Some(_) {
      match get_parent_id_from_dotted_id(edge.src_id) {
        Some(p) => p
        None => edge.src_id
      }
    } else {
      edge.src_id
    }
    let dst_id = if edge.dst_column_index is Some(_) {
      match get_parent_id_from_dotted_id(edge.dst_id) {
        Some(p) => p
        None => edge.dst_id
      }
    } else {
      edge.dst_id
    }
    let elk_edge = ElkEdge::new("e" + i.to_string(), src_id, dst_id)
    // Add label if present
    if edge.label.length() > 0 {
      match edge.label_box {
        Some(b) => {
          let label = ElkLabel::new("e" + i.to_string() + "_label", edge.label)
          label.width = b.width
          label.height = b.height
          elk_edge.labels.push(label)
        }
        None =>
          abort(
            "Edge '\{edge.src_id} -> \{edge.dst_id}' has no label_box; sizes must be precomputed",
          )
      }
    }
    root.add_edge(elk_edge)
  }
  root
}

///|
/// Convert a diago Object to an ELK node
fn object_to_elk_node(obj : Object, config : LayoutConfig) -> ElkNode {
  let elk_node = ElkNode::new(obj.id)

  // Set size from existing box
  match obj.box {
    Some(b) => {
      elk_node.width = if b.width > 0.0 {
        b.width
      } else {
        config.default_width
      }
      elk_node.height = if b.height > 0.0 {
        b.height
      } else {
        config.default_height
      }
    }
    None => abort("Object '\{obj.id}' has no box; sizes must be precomputed")
  }

  // Add label
  if obj.label.length() > 0 {
    match obj.label_box {
      Some(b) => {
        let label = ElkLabel::new(obj.id + "_label", obj.label)
        label.width = b.width
        label.height = b.height
        elk_node.add_label(label)
      }
      None =>
        abort("Object '\{obj.id}' has no label_box; sizes must be precomputed")
    }
  }

  // Handle children for containers
  // sql_table renders children as rows, not nested boxes - keep it as a leaf in ELK.
  if obj.shape_type != @graph.SqlTable {
    for child in obj.children {
      let elk_child = object_to_elk_node(child, config)
      elk_node.add_child(elk_child)
    }
  }
  elk_node
}

///|
/// Apply ELK layout results back to a diago Graph
fn elk_to_graph(
  elk_root : ElkNode,
  graph : Graph,
  _config : LayoutConfig,
  direction : Direction,
) -> Unit {
  // Create map of ELK nodes by ID
  let elk_map : Map[String, ElkNode] = {}
  collect_elk_nodes(elk_root, elk_map)

  // Apply positions to graph objects
  for obj in graph.objects {
    match elk_map.get(obj.id) {
      Some(elk_node) => {
        obj.box = Some(
          @graph.Box::new(
            elk_node.x,
            elk_node.y,
            elk_node.width,
            elk_node.height,
          ),
        )
        // Apply to children recursively
        apply_children_positions(obj, elk_node)
      }
      None => ()
    }
  }

  // Apply edge routes
  apply_edge_routes(elk_root, graph, elk_map, direction)
}

///|
/// Collect all ELK nodes into a map
fn collect_elk_nodes(node : ElkNode, map : Map[String, ElkNode]) -> Unit {
  map[node.id] = node
  for child in node.children {
    collect_elk_nodes(child, map)
  }
}

///|
/// Apply positions from ELK children to Graph object children
fn apply_children_positions(obj : Object, elk_node : ElkNode) -> Unit {
  for child in obj.children {
    for elk_child in elk_node.children {
      if elk_child.id == child.id {
        // Child positions are relative to parent in ELK
        let parent_box = obj.box.unwrap_or(@graph.Box::zero())
        child.box = Some(
          @graph.Box::new(
            parent_box.x + elk_child.x,
            parent_box.y + elk_child.y,
            elk_child.width,
            elk_child.height,
          ),
        )
        apply_children_positions(child, elk_child)
        break
      }
    }
  }
}

///|
/// Apply edge routes from ELK to Graph with perpendicularity adjustment
fn apply_edge_routes(
  elk_root : ElkNode,
  graph : Graph,
  elk_map : Map[String, ElkNode],
  direction : Direction,
) -> Unit {
  // Match ELK edges to graph edges by index (order is preserved)
  for i, elk_edge in elk_root.edges {
    if i < graph.edges.length() {
      let edge = graph.edges[i]
      // Clear existing route
      edge.route.clear()
      // Apply route from ELK edge sections
      if elk_edge.sections.length() > 0 {
        for section in elk_edge.sections {
          // Get source and target boxes for perpendicularity adjustment
          let src_box = elk_map.get(elk_edge.sources[0])
          let tgt_box = elk_map.get(elk_edge.targets[0])

          // Adjust start point for perpendicularity
          let start_point = match src_box {
            Some(src) =>
              adjust_start_point_perpendicular(
                section.start_point.x,
                section.start_point.y,
                src,
                section.bend_points,
                section.end_point.x,
                section.end_point.y,
                direction,
              )
            None =>
              @graph.Point::new(section.start_point.x, section.start_point.y)
          }

          // Adjust end point for perpendicularity
          let end_point = match tgt_box {
            Some(tgt) =>
              adjust_end_point_perpendicular(
                section.end_point.x,
                section.end_point.y,
                tgt,
                section.bend_points,
                section.start_point.x,
                section.start_point.y,
                direction,
              )
            None => @graph.Point::new(section.end_point.x, section.end_point.y)
          }
          edge.route.push(start_point)
          // Bend points
          for bp in section.bend_points {
            edge.route.push(@graph.Point::new(bp.x, bp.y))
          }
          edge.route.push(end_point)
        }
        // Fallback: create direct route from source to target
        // Determine direction based on node positions
      } else if elk_edge.sources.length() > 0 && elk_edge.targets.length() > 0 {
        match
          (elk_map.get(elk_edge.sources[0]), elk_map.get(elk_edge.targets[0])) {
          (Some(src), Some(tgt)) => {
            let src_cx = src.x + src.width / 2.0
            let src_cy = src.y + src.height / 2.0
            let tgt_cx = tgt.x + tgt.width / 2.0
            let tgt_cy = tgt.y + tgt.height / 2.0

            // Determine if connection is more horizontal or vertical
            let dx = (tgt_cx - src_cx).abs()
            let dy = (tgt_cy - src_cy).abs()
            if dy > dx {
              // More vertical - connect from top/bottom
              let (start_y, end_y) = if tgt_cy > src_cy {
                (src.y + src.height, tgt.y) // Bottom to top
              } else {
                (src.y, tgt.y + tgt.height) // Top to bottom
              }
              edge.route.push(@graph.Point::new(src_cx, start_y))
              edge.route.push(@graph.Point::new(tgt_cx, end_y))
            } else {
              // More horizontal - connect from left/right
              let (start_x, end_x) = if tgt_cx > src_cx {
                (src.x + src.width, tgt.x) // Right to left
              } else {
                (src.x, tgt.x + tgt.width) // Left to right
              }
              edge.route.push(@graph.Point::new(start_x, src_cy))
              edge.route.push(@graph.Point::new(end_x, tgt_cy))
            }
          }
          _ => ()
        }
      }
    }
  }
}

///|
/// Adjust start point to be perpendicular to first segment
fn adjust_start_point_perpendicular(
  elk_start_x : Double,
  elk_start_y : Double,
  src : ElkNode,
  bend_points : Array[ElkPoint],
  end_x : Double,
  end_y : Double,
  direction : Direction,
) -> @graph.Point {
  let src_cx = src.x + src.width / 2.0
  let src_cy = src.y + src.height / 2.0

  // Get the next point (first bend or end point)
  let (next_x, next_y) = if bend_points.length() > 0 {
    (bend_points[0].x, bend_points[0].y)
  } else {
    (end_x, end_y)
  }

  // Determine segment direction from ELK's suggested start to next point
  // This tells us what direction ELK intended for the first segment
  let elk_dx = (next_x - elk_start_x).abs()
  let elk_dy = (next_y - elk_start_y).abs()

  // If ELK's segment is horizontal (same y), connect from left/right
  // If ELK's segment is vertical (same x), connect from top/bottom
  let tolerance = 1.0
  let elk_is_horizontal = elk_dy < tolerance && elk_dx > tolerance
  let elk_is_vertical = elk_dx < tolerance && elk_dy > tolerance

  // For horizontal layouts (Right/Left), edges should exit from left/right sides
  // For vertical layouts (Down/Up), edges should exit from top/bottom sides
  let is_horizontal_layout = direction is Right || direction is Left
  if elk_is_horizontal {
    // ELK intended horizontal segment - connect from left or right side
    let start_x = if next_x > src_cx {
      src.x + src.width // Right side
    } else {
      src.x // Left side
    }
    // Clamp y to node bounds
    let start_y = clamp(next_y, src.y, src.y + src.height)
    @graph.Point::new(start_x, start_y)
  } else if elk_is_vertical {
    // ELK intended vertical segment - connect from top or bottom side
    // For vertical layouts, use layout direction to determine exit side
    // This prevents routing slot Y-shifts from causing wrong side connections
    let start_y = match direction {
      Down => src.y + src.height // Always exit from bottom when layout flows down
      Up => src.y // Always exit from top when layout flows up
      // For horizontal layouts with vertical segments, use next_y comparison
      _ =>
        if next_y > src_cy {
          src.y + src.height // Bottom side
        } else {
          src.y // Top side
        }
    }
    // Clamp x to node bounds
    let start_x = clamp(next_x, src.x, src.x + src.width)
    @graph.Point::new(start_x, start_y)
  } else if is_horizontal_layout {
    // Horizontal layout with diagonal segment - prefer left/right exit
    // This is the key fix: for Right/Left direction, edges should exit horizontally
    let start_x = match direction {
      Right => src.x + src.width // Exit from right side
      Left => src.x // Exit from left side
      _ => if next_x > src_cx { src.x + src.width } else { src.x }
    }
    // For horizontal exit, use the node center y, clamped to bounds
    let start_y = clamp(next_y, src.y, src.y + src.height)
    @graph.Point::new(start_x, start_y)
  } else {
    // Vertical layout with diagonal segment - prefer top/bottom exit
    let dx = (next_x - src_cx).abs()
    let dy = (next_y - src_cy).abs()
    if dx > dy {
      // More horizontal - connect from left/right
      let start_x = if next_x > src_cx { src.x + src.width } else { src.x }
      let start_y = clamp(next_y, src.y, src.y + src.height)
      @graph.Point::new(start_x, start_y)
    } else {
      // More vertical - connect from top/bottom
      let start_y = if next_y > src_cy { src.y + src.height } else { src.y }
      let start_x = clamp(next_x, src.x, src.x + src.width)
      @graph.Point::new(start_x, start_y)
    }
  }
}

///|
/// Adjust end point to be perpendicular to last segment
fn adjust_end_point_perpendicular(
  elk_end_x : Double,
  elk_end_y : Double,
  tgt : ElkNode,
  bend_points : Array[ElkPoint],
  start_x : Double,
  start_y : Double,
  direction : Direction,
) -> @graph.Point {
  let tgt_cx = tgt.x + tgt.width / 2.0
  let tgt_cy = tgt.y + tgt.height / 2.0

  // Get the previous point (last bend or start point)
  let (prev_x, prev_y) = if bend_points.length() > 0 {
    let last = bend_points[bend_points.length() - 1]
    (last.x, last.y)
  } else {
    (start_x, start_y)
  }

  // Determine segment direction from previous point to ELK's suggested end
  // This tells us what direction ELK intended for the last segment
  let elk_dx = (elk_end_x - prev_x).abs()
  let elk_dy = (elk_end_y - prev_y).abs()

  // If ELK's segment is horizontal (same y), connect to left/right
  // If ELK's segment is vertical (same x), connect to top/bottom
  let tolerance = 1.0
  let elk_is_horizontal = elk_dy < tolerance && elk_dx > tolerance
  let elk_is_vertical = elk_dx < tolerance && elk_dy > tolerance

  // For horizontal layouts (Right/Left), edges should enter from left/right sides
  // For vertical layouts (Down/Up), edges should enter from top/bottom sides
  let is_horizontal_layout = direction is Right || direction is Left
  if elk_is_horizontal {
    // ELK intended horizontal segment - connect to left or right side
    let end_x = if prev_x < tgt_cx {
      tgt.x // Left side
    } else {
      tgt.x + tgt.width // Right side
    }
    // Clamp y to node bounds
    let end_y = clamp(prev_y, tgt.y, tgt.y + tgt.height)
    @graph.Point::new(end_x, end_y)
  } else if elk_is_vertical {
    // ELK intended vertical segment - connect to top or bottom side
    // For vertical layouts, use layout direction to determine entry side
    // This prevents routing slot Y-shifts from causing wrong side connections
    let end_y = match direction {
      Down => tgt.y // Always enter from top when layout flows down
      Up => tgt.y + tgt.height // Always enter from bottom when layout flows up
      // For horizontal layouts with vertical segments, use prev_y comparison
      _ =>
        if prev_y < tgt_cy {
          tgt.y // Top side
        } else {
          tgt.y + tgt.height // Bottom side
        }
    }
    // Clamp x to node bounds
    let end_x = clamp(prev_x, tgt.x, tgt.x + tgt.width)
    @graph.Point::new(end_x, end_y)
  } else if is_horizontal_layout {
    // Horizontal layout with diagonal segment - prefer left/right entry
    let end_x = match direction {
      Right => tgt.x // Enter from left side
      Left => tgt.x + tgt.width // Enter from right side
      _ => if prev_x < tgt_cx { tgt.x } else { tgt.x + tgt.width }
    }
    // For horizontal entry, use the previous y, clamped to bounds
    let end_y = clamp(prev_y, tgt.y, tgt.y + tgt.height)
    @graph.Point::new(end_x, end_y)
  } else {
    // Vertical layout with diagonal segment - prefer top/bottom entry
    let dx = (prev_x - tgt_cx).abs()
    let dy = (prev_y - tgt_cy).abs()
    if dx > dy {
      // More horizontal - connect to left/right
      let end_x = if prev_x < tgt_cx { tgt.x } else { tgt.x + tgt.width }
      let end_y = clamp(prev_y, tgt.y, tgt.y + tgt.height)
      @graph.Point::new(end_x, end_y)
    } else {
      // More vertical - connect to top/bottom
      let end_y = if prev_y < tgt_cy { tgt.y } else { tgt.y + tgt.height }
      let end_x = clamp(prev_x, tgt.x, tgt.x + tgt.width)
      @graph.Point::new(end_x, end_y)
    }
  }
}

///|
/// Run ELK layout on a graph
fn run_elk_layout(
  graph : Graph,
  config : LayoutConfig,
  direction : Direction,
) -> Unit {
  // Convert to ELK format
  let elk_root = graph_to_elk(graph, config)

  // Create layout options using builder pattern
  let elk_direction = match direction {
    Down => LayoutDirection::Down
    Up => LayoutDirection::Up
    Right => LayoutDirection::Right
    Left => LayoutDirection::Left
  }
  let options = LayoutOptions::layered()
    .with_direction(elk_direction)
    .with_node_spacing(config.horizontal_spacing)
    .with_layer_spacing(config.vertical_spacing)
    .with_padding(
      ElkPadding::new(
        config.container_padding,
        config.container_padding,
        config.container_padding,
        config.container_padding,
      ),
    )
    .with_edge_routing(EdgeRouting::Orthogonal)
  // Keep options also attached as ELK properties for future property-driven resolution.
  elk_root.properties.copy_from(options.to_properties())
  let algorithm = match options.algorithm {
    Some(a) => a
    None => Layered
  }

  // Dispatch to the selected algorithm implementation.
  match algorithm {
    Layered => elk_layered_layout(elk_root, options)
    MrTree => elk_mrtree_layout(elk_root, options)
    // TODO: implement and wire the remaining ELK algorithms.
    _ => elk_layered_layout(elk_root, options)
  }

  // Convert back to Graph format
  elk_to_graph(elk_root, graph, config, direction)
}
