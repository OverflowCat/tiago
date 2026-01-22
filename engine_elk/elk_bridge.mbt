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
fn endpoint_matches(obj_id : String, node_id : String) -> Bool {
  node_id == obj_id || node_id.has_prefix(obj_id + ".")
}

///|
const PORT_SPACING : Double = 40.0

///|
fn sql_src_port_id(table_id : String, column : String) -> String {
  table_id + "." + column + ".src"
}

///|
fn sql_dst_port_id(table_id : String, column : String) -> String {
  table_id + "." + column + ".dst"
}

///|
fn sql_port_sides(direction : Direction) -> (ElkPortSide, ElkPortSide) {
  match direction {
    Left => (West, East)
    _ => (East, West)
  }
}

///|
fn apply_port_spacing(graph : Graph, direction : Direction) -> Unit {
  let incoming : Map[String, Int] = {}
  let outgoing : Map[String, Int] = {}
  for edge in graph.edges {
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
    outgoing[src_id] = outgoing.get(src_id).unwrap_or(0) + 1
    incoming[dst_id] = incoming.get(dst_id).unwrap_or(0) + 1
  }
  for obj in graph.objects {
    let inc = incoming.get(obj.id).unwrap_or(0)
    let out = outgoing.get(obj.id).unwrap_or(0)
    let max_ports = if inc > out { inc } else { out }
    if max_ports < 2 {
      continue
    }
    guard obj.box is Some(b) else { continue }
    let min_span = max_ports.to_double() * PORT_SPACING
    let (new_w, new_h) = if direction is Left || direction is Right {
      (b.width, if b.height < min_span { min_span } else { b.height })
    } else {
      (if b.width < min_span { min_span } else { b.width }, b.height)
    }
    if new_w != b.width || new_h != b.height {
      obj.box = Some(@graph.Box::new(b.x, b.y, new_w, new_h))
    }
  }
}

///|
fn port_group_key(node_id : String, side : ElkPortSide) -> String {
  node_id + "|" + side.to_string()
}

///|
fn push_port_group(
  groups : Map[String, Array[String]],
  node_id : String,
  side : ElkPortSide,
  port_id : String,
) -> Unit {
  let key = port_group_key(node_id, side)
  let ports = groups.get(key).unwrap_or([])
  ports.push(port_id)
  groups[key] = ports
}

///|
fn add_port_to_tree(node : ElkNode, target_id : String, port : ElkPort) -> Bool {
  if node.id == target_id {
    node.add_port(port)
    return true
  }
  for i = 0; i < node.children.length(); i = i + 1 {
    if add_port_to_tree(node.children[i], target_id, port) {
      return true
    }
  }
  false
}

///|
fn set_port_x_positions(node : ElkNode, port_ids : Array[String]) -> Unit {
  if port_ids.is_empty() {
    return
  }
  let spacing = node.width / (port_ids.length() + 1).to_double()
  for i, port_id in port_ids {
    let x = spacing * (i.to_double() + 1.0)
    for j = 0; j < node.ports.length(); j = j + 1 {
      if node.ports[j].id == port_id {
        node.ports[j] = { ..node.ports[j], x, }
        break
      }
    }
  }
}

///|
fn apply_port_group_positions(
  node : ElkNode,
  groups : Map[String, Array[String]],
) -> Unit {
  for side in [ElkPortSide::North, ElkPortSide::South] {
    let key = port_group_key(node.id, side)
    match groups.get(key) {
      Some(port_ids) => set_port_x_positions(node, port_ids)
      None => ()
    }
  }
  for i = 0; i < node.children.length(); i = i + 1 {
    apply_port_group_positions(node.children[i], groups)
  }
}

///|
/// Convert a diago Graph to an ELK ElkNode for layout
fn graph_to_elk(
  graph : Graph,
  config : LayoutConfig,
  direction : Direction,
) -> ElkNode {
  apply_port_spacing(graph, direction)
  let root = ElkNode::new("root")

  // Convert only top-level objects to ELK nodes (children are added recursively).
  //
  // Prefer `graph.root.children` if it's populated (GraphInput-derived graphs).
  // Fall back to `graph.objects` + child filtering for legacy whitebox tests.
  let top_level : Array[Object] = if graph.root.children.is_empty() {
    let is_child : Map[String, Bool] = {}
    for obj in graph.objects {
      for child in obj.children {
        is_child[child.id] = true
      }
    }
    let out : Array[Object] = []
    for obj in graph.objects {
      if is_child.contains(obj.id) {
        continue
      }
      out.push(obj)
    }
    out
  } else {
    graph.root.children
  }
  for obj in top_level {
    if is_sql_table_child(obj, graph) {
      continue
    }
    let elk_node = object_to_elk_node(obj, config, direction)
    root.add_child(elk_node)
  }
  let port_groups : Map[String, Array[String]] = {}
  let (table_src_side, table_dst_side) = match direction {
    Up => (ElkPortSide::North, ElkPortSide::South)
    _ => (ElkPortSide::South, ElkPortSide::North)
  }

  // Convert all edges
  for i, edge in graph.edges {
    // For sql_table field-level connections, ELK should connect the parent tables
    let mut src_id = edge.src_id
    let mut src_port : String? = None
    if edge.src_column_index is Some(_) {
      match get_parent_id_from_dotted_id(edge.src_id) {
        Some(p) => {
          src_id = p
          src_port = Some(
            sql_src_port_id(p, get_short_name_from_id(edge.src_id)),
          )
        }
        None => ()
      }
    } else if {
        let is_sql_table = match graph.find_object(edge.src_id) {
          Some(obj) => obj.shape_type == @graph.SqlTable
          None => false
        }
        is_sql_table
      } {
      let port_id = sql_src_port_id(edge.src_id, "__root__") +
        "." +
        i.to_string()
      let port = ElkPort::with_side(port_id, table_src_side)
      add_port_to_tree(root, edge.src_id, port) |> ignore
      push_port_group(port_groups, edge.src_id, table_src_side, port_id)
      src_port = Some(port_id)
    }
    let mut dst_id = edge.dst_id
    let mut dst_port : String? = None
    if edge.dst_column_index is Some(_) {
      match get_parent_id_from_dotted_id(edge.dst_id) {
        Some(p) => {
          dst_id = p
          dst_port = Some(
            sql_dst_port_id(p, get_short_name_from_id(edge.dst_id)),
          )
        }
        None => ()
      }
    } else if {
        let is_sql_table = match graph.find_object(edge.dst_id) {
          Some(obj) => obj.shape_type == @graph.SqlTable
          None => false
        }
        is_sql_table
      } {
      let port_id = sql_dst_port_id(edge.dst_id, "__root__") +
        "." +
        i.to_string()
      let port = ElkPort::with_side(port_id, table_dst_side)
      add_port_to_tree(root, edge.dst_id, port) |> ignore
      push_port_group(port_groups, edge.dst_id, table_dst_side, port_id)
      dst_port = Some(port_id)
    }
    let elk_edge = {
      ..ElkEdge::new("e" + i.to_string(), src_id, dst_id),
      source_port: src_port,
      target_port: dst_port,
    }
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
  apply_port_group_positions(root, port_groups)
  root
}

///|
/// Convert a diago Object to an ELK node
fn object_to_elk_node(
  obj : Object,
  config : LayoutConfig,
  direction : Direction,
) -> ElkNode {
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

  // SQL table ports: fixed column anchors for row-level edges.
  if obj.shape_type == @graph.SqlTable {
    elk_node.properties.set("elk.portConstraints", Enum("FIXED_POS"))
    let (src_side, dst_side) = sql_port_sides(direction)
    let row_count = obj.children.length() + 1
    if row_count > 0 {
      let row_height = elk_node.height / row_count.to_double()
      for i, child in obj.children {
        let col_name = get_short_name_from_id(child.id)
        let y = row_height * (i.to_double() + 1.0) + row_height / 2.0
        let src_port = {
          ..ElkPort::with_side(sql_src_port_id(obj.id, col_name), src_side),
          y,
        }
        elk_node.add_port(src_port)
        let dst_port = {
          ..ElkPort::with_side(sql_dst_port_id(obj.id, col_name), dst_side),
          y,
        }
        elk_node.add_port(dst_port)
      }
    }
  }
  let is_container = obj.children.length() > 0 &&
    obj.shape_type != @graph.SqlTable
  if is_container {
    let base_padding = ElkPadding::uniform(config.container_padding)
    let padding = if obj.label.length() > 0 {
      match obj.label_box {
        Some(b) => {
          let label_padding = 5.0
          let extra_top = b.height + label_padding * 2.0
          let top = if extra_top > base_padding.top {
            extra_top
          } else {
            base_padding.top
          }
          ElkPadding::new(
            top,
            base_padding.right,
            base_padding.bottom,
            base_padding.left,
          )
        }
        None => base_padding
      }
    } else {
      base_padding
    }
    let (min_w, min_h) = match direction {
      Down | Up => (elk_node.height.ceil(), elk_node.width.ceil())
      Right | Left => (elk_node.width.ceil(), elk_node.height.ceil())
    }
    let container_options = {
      ..LayoutOptions::new(),
      crossing_min_force_node_model_order: Some(true),
      thoroughness: Some(8),
      edge_edge_between_layers_spacing: Some(50.0),
      hierarchy_handling: Some(Include),
      bk_fixed_alignment: Some(Average),
      edge_node_spacing: Some(40.0),
      consider_model_order_strategy: Some(NodesAndEdges),
      cycle_breaking_strategy: Some(GreedyModelOrder),
      node_size_constraints: Some([MinimumSize]),
      content_alignment: Some(HorizontalVertical),
      node_node_between_layers_spacing: Some(config.vertical_spacing),
      edge_node_between_layers_spacing: Some(config.edge_padding),
      padding: Some(padding),
      node_size_minimum: Some((min_w, min_h)),
    }
    elk_node.properties.copy_from(container_options.to_properties())
  }

  // Handle children for containers
  // sql_table renders children as rows, not nested boxes - keep it as a leaf in ELK.
  if obj.shape_type != @graph.SqlTable {
    for child in obj.children {
      let elk_child = object_to_elk_node(child, config, direction)
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
  config : LayoutConfig,
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
          let start_point = if elk_edge.source_port_id() is Some(_) {
            @graph.Point::new(section.start_point.x, section.start_point.y)
          } else {
            match src_box {
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
          }
          let end_point = if elk_edge.target_port_id() is Some(_) {
            @graph.Point::new(section.end_point.x, section.end_point.y)
          } else {
            match tgt_box {
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
              None =>
                @graph.Point::new(section.end_point.x, section.end_point.y)
            }
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
    // Vertical layout with diagonal segment.
    // For ELK parity we must not "decide" left/right based on dx/dy, since
    // that can flip a vertical-flow edge into a side-exiting edge for far targets.
    // Always respect the layout direction (Down/Up) for entry/exit side.
    let start_y = match direction {
      Down => src.y + src.height
      Up => src.y
      _ => if next_y > src_cy { src.y + src.height } else { src.y }
    }
    let start_x = clamp(next_x, src.x, src.x + src.width)
    @graph.Point::new(start_x, start_y)
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
    // Vertical layout with diagonal segment.
    // Same parity rationale as start-point adjustment: keep vertical-flow edges
    // entering on top/bottom rather than picking left/right for far targets.
    let end_y = match direction {
      Down => tgt.y
      Up => tgt.y + tgt.height
      _ => if prev_y < tgt_cy { tgt.y } else { tgt.y + tgt.height }
    }
    let end_x = clamp(prev_x, tgt.x, tgt.x + tgt.width)
    @graph.Point::new(end_x, end_y)
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
  let elk_root = graph_to_elk(graph, config, direction)

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
  // D2 uses these defaults for ELK layered layout.
  let options = {
    ..options,
    consider_model_order_strategy: Some(NodesAndEdges),
    separate_connected_components: Some(false),
    // Match D2 default: `fixedAlignment = BALANCED` for BK placement.
    bk_fixed_alignment: Some(Average),
    thoroughness: Some(8),
    edge_edge_between_layers_spacing: Some(50.0),
    edge_node_spacing: Some(40.0),
    edge_node_between_layers_spacing: Some(config.edge_padding),
    hierarchy_handling: Some(Include),
    content_alignment: Some(HorizontalVertical),
    node_size_constraints: Some([MinimumSize]),
    cycle_breaking_strategy: Some(GreedyModelOrder),
  }
  // Keep options also attached as ELK properties for future property-driven resolution.
  elk_root.properties.copy_from(options.to_properties())
  let algorithm = match options.algorithm {
    Some(a) => a
    None => Layered
  }

  // Dispatch to the selected algorithm implementation.
  match algorithm {
    Layered => elk_layered_layout_with_components(elk_root, options)
    MrTree => elk_mrtree_layout(elk_root, options)
    Force => elk_force_layout(elk_root, options)
    Stress => elk_stress_layout(elk_root, options)
    Radial => elk_radial_layout(elk_root, options)
    Box => elk_box_layout(elk_root, options)
    RectPacking => elk_rect_packing_layout(elk_root, options)
    TopDownPacking => elk_top_down_packing_layout(elk_root, options)
    DisCo => elk_disco_layout(elk_root, options)
    Fixed => elk_fixed_layout(elk_root, options)
    Random => elk_random_layout(elk_root, options)
    SporeCompaction => elk_spore_compaction_layout(elk_root, options)
    SporeOverlap => elk_spore_overlap_layout(elk_root, options)
  }

  // Convert back to Graph format
  elk_to_graph(elk_root, graph, config, direction)
}
