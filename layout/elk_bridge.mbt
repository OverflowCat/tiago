///|
/// Bridge between Graph and ELK types
/// Converts D2 Graph to ELK format, runs layout, and converts back

///|
/// Convert a D2 Graph to an ELK ElkNode for layout
fn graph_to_elk(graph : @graph.Graph, config : LayoutConfig) -> @elk.ElkNode {
  let root = @elk.ElkNode::new("root")

  // Create a map for object ID to ELK node
  let node_map : Map[String, @elk.ElkNode] = {}

  // Convert all objects to ELK nodes
  for obj in graph.objects {
    let elk_node = object_to_elk_node(obj, config)
    root.add_child(elk_node)
    node_map[obj.id] = elk_node
  }

  // Convert all edges
  for i, edge in graph.edges {
    let elk_edge = @elk.ElkEdge::new(
      "e" + i.to_string(),
      edge.src_id,
      edge.dst_id,
    )
    // Add label if present
    if edge.label.length() > 0 {
      let label = @elk.ElkLabel::new("e" + i.to_string() + "_label", edge.label)
      // Estimate label size
      label.width = edge.label.length().to_double() * 8.0 + 20.0
      label.height = 20.0
      elk_edge.labels.push(label)
    }
    root.add_edge(elk_edge)
  }
  root
}

///|
/// Convert a D2 Object to an ELK node
fn object_to_elk_node(
  obj : @graph.Object,
  config : LayoutConfig,
) -> @elk.ElkNode {
  let elk_node = @elk.ElkNode::new(obj.id)

  // Set size from existing box or compute from label
  match obj.box {
    Some(b) => {
      // Use computed size, ensuring minimum dimensions
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
    None => {
      // Estimate size from label with minimum size
      let char_width = 8.0
      let padding = 20.0
      let label_width = obj.label.length().to_double() * char_width + padding
      elk_node.width = if label_width > config.default_width {
        label_width
      } else {
        config.default_width
      }
      elk_node.height = config.default_height
    }
  }

  // Add label
  if obj.label.length() > 0 {
    let label = @elk.ElkLabel::new(obj.id + "_label", obj.label)
    label.width = obj.label.length().to_double() * 8.0
    label.height = 14.0
    elk_node.add_label(label)
  }

  // Handle children for containers
  for child in obj.children {
    let elk_child = object_to_elk_node(child, config)
    elk_node.add_child(elk_child)
  }
  elk_node
}

///|
/// Apply ELK layout results back to a D2 Graph
fn elk_to_graph(
  elk_root : @elk.ElkNode,
  graph : @graph.Graph,
  _config : LayoutConfig,
) -> Unit {
  // Create map of ELK nodes by ID
  let elk_map : Map[String, @elk.ElkNode] = {}
  collect_elk_nodes(elk_root, elk_map)

  // Apply positions to graph objects
  for obj in graph.objects {
    match elk_map.get(obj.id) {
      Some(elk_node) => {
        obj.set_box(
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
  apply_edge_routes(elk_root, graph)
}

///|
/// Collect all ELK nodes into a map
fn collect_elk_nodes(
  node : @elk.ElkNode,
  map : Map[String, @elk.ElkNode],
) -> Unit {
  map[node.id] = node
  for child in node.children {
    collect_elk_nodes(child, map)
  }
}

///|
/// Apply positions from ELK children to Graph object children
fn apply_children_positions(
  obj : @graph.Object,
  elk_node : @elk.ElkNode,
) -> Unit {
  for child in obj.children {
    for elk_child in elk_node.children {
      if elk_child.id == child.id {
        // Child positions are relative to parent in ELK
        let parent_box = obj.box.unwrap_or(@graph.Box::zero())
        child.set_box(
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
/// Apply edge routes from ELK to Graph
fn apply_edge_routes(elk_root : @elk.ElkNode, graph : @graph.Graph) -> Unit {
  // Match ELK edges to graph edges by index (order is preserved)
  for i, elk_edge in elk_root.edges {
    if i < graph.edges.length() {
      let edge = graph.edges[i]
      // Clear existing route
      edge.route.clear()
      // Apply route from ELK edge sections
      for section in elk_edge.sections {
        // Start point
        edge.route.push(
          @graph.Point::new(section.start_point.x, section.start_point.y),
        )
        // Bend points
        for bp in section.bend_points {
          edge.route.push(@graph.Point::new(bp.x, bp.y))
        }
        // End point
        edge.route.push(
          @graph.Point::new(section.end_point.x, section.end_point.y),
        )
      }
    }
  }
}

///|
/// Run ELK layout on a graph
pub fn run_elk_layout(
  graph : @graph.Graph,
  config : LayoutConfig,
  direction : Direction,
) -> Unit {
  // Convert to ELK format
  let elk_root = graph_to_elk(graph, config)

  // Create layout options using builder pattern
  let elk_direction = match direction {
    Down => @elk.Down
    Up => @elk.Up
    Right => @elk.Right
    Left => @elk.Left
  }
  let options = @elk.LayoutOptions::layered()
    .with_direction(elk_direction)
    .with_node_spacing(config.horizontal_spacing)
    .with_layer_spacing(config.vertical_spacing)
    .with_padding(
      @elk.ElkPadding::new(
        config.container_padding,
        config.container_padding,
        config.container_padding,
        config.container_padding,
      ),
    )
    .with_edge_routing(@elk.Orthogonal)

  // Run ELK layout
  @elk.layout(elk_root, options) catch {
    _ => () // Layout errors are handled gracefully
  }

  // Convert back to Graph format
  elk_to_graph(elk_root, graph, config)
}
