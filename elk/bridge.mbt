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
/// ELK.js Port for MoonBit - Bridge Functions
/// Convert between existing @graph types and ELK types

// ============================================================================
// Convert Graph -> ElkNode
// ============================================================================

///|
/// Convert a diago Graph to an ELK graph structure
pub fn from_graph(graph : @graph.Graph) -> ElkNode {
  // Create root ELK node
  let root = ElkNode::new(graph.root.id)

  // Set root properties
  match graph.root.box {
    Some(b) => {
      root.x = b.x
      root.y = b.y
      root.width = b.width
      root.height = b.height
    }
    None => ()
  }

  // Add label if present
  if graph.root.label.length() > 0 {
    root.add_label(ElkLabel::new(graph.root.id + "_label", graph.root.label))
  }

  // Convert all objects to children
  for obj in graph.objects {
    root.add_child(convert_object(obj))
  }

  // Convert all edges
  for edge in graph.edges {
    root.add_edge(convert_edge(edge))
  }

  // Handle nested children from root
  for child in graph.root.children {
    root.add_child(convert_object(child))
  }
  root
}

///|
/// Convert a diago Object to an ElkNode
fn convert_object(obj : @graph.Object) -> ElkNode {
  let node = ElkNode::new(obj.id)

  // Use pre-computed dimensions from graph compilation (D2's approach)
  match obj.box {
    Some(b) => {
      node.x = b.x
      node.y = b.y
      node.width = b.width
      node.height = b.height
    }
    None =>
      // No box - this should not happen since set_text_dimensions sets it
      abort(
        "Object '\{obj.id}' has no computed dimensions. Text dimensions should have been set during graph compilation.",
      )
  }

  // Add label with pre-computed dimensions
  if obj.label.length() > 0 {
    match obj.label_box {
      Some(label_box) => {
        let label = ElkLabel::new(obj.id + "_label", obj.label)
        label.width = label_box.width
        label.height = label_box.height
        node.add_label(label)
      }
      None =>
        abort(
          "Object '\{obj.id}' has label but no computed label dimensions. Text dimensions should have been set during graph compilation.",
        )
    }
  }

  // Convert children recursively
  for child in obj.children {
    node.add_child(convert_object(child))
  }
  node
}

///|
/// Convert a diago Edge to an ElkEdge
fn convert_edge(edge : @graph.Edge) -> ElkEdge {
  let elk_edge = ElkEdge::new(
    "e" + edge.index.to_string(),
    edge.src_id,
    edge.dst_id,
  )

  // Use pre-computed label dimensions (D2's approach)
  if edge.label.length() > 0 {
    match edge.label_box {
      Some(label_box) => {
        let label = ElkLabel::new(
          "e" + edge.index.to_string() + "_label",
          edge.label,
        )
        label.width = label_box.width
        label.height = label_box.height
        elk_edge.labels.push(label)
      }
      None =>
        abort(
          "Edge \{edge.index} (\{edge.src_id} -> \{edge.dst_id}) has label but no computed label dimensions. Text dimensions should have been set during graph compilation.",
        )
    }
  }

  // Convert route to sections if present
  if edge.route.length() >= 2 {
    let section = ElkEdgeSection::new("s" + edge.index.to_string())
    section.start_point = ElkPoint::new(edge.route[0].x, edge.route[0].y)
    let last_idx = edge.route.length() - 1
    section.end_point = ElkPoint::new(
      edge.route[last_idx].x,
      edge.route[last_idx].y,
    )

    // Add intermediate points as bends
    for i = 1; i < edge.route.length() - 1; i = i + 1 {
      section.bend_points.push(ElkPoint::new(edge.route[i].x, edge.route[i].y))
    }
    elk_edge.sections.push(section)
  }
  elk_edge
}

// ============================================================================
// Convert ElkNode -> Graph (apply layout results)
// ============================================================================

///|
/// Apply ELK layout results back to a diago Graph
pub fn to_graph(elk_node : ElkNode, graph : @graph.Graph) -> Unit {
  // Apply root size
  graph.root.box = Some(
    @graph.Box::new(elk_node.x, elk_node.y, elk_node.width, elk_node.height),
  )

  // Apply positions to all objects
  for obj in graph.objects {
    apply_node_position(elk_node, obj)
  }

  // Apply positions to root's children
  for child in graph.root.children {
    apply_node_position(elk_node, child)
  }

  // Apply routes to all edges
  for edge in graph.edges {
    apply_edge_route(elk_node, edge)
  }
}

///|
/// Find and apply position from ELK node to diago object
fn apply_node_position(elk_node : ElkNode, obj : @graph.Object) -> Unit {
  // Try to find matching ELK node
  match elk_node.find_node(obj.id) {
    Some(elk) => {
      obj.box = Some(@graph.Box::new(elk.x, elk.y, elk.width, elk.height))

      // Recursively apply to children
      for child in obj.children {
        apply_node_position(elk_node, child)
      }
    }
    None => ()
  }
}

///|
/// Find and apply route from ELK edge to diago edge
fn apply_edge_route(elk_node : ElkNode, edge : @graph.Edge) -> Unit {
  let edge_id = "e" + edge.index.to_string()

  // Search all edges in the ELK graph
  for elk_edge in elk_node.all_edges() {
    if elk_edge.id == edge_id {
      // Clear existing route
      edge.route.clear()

      // Apply sections as route points
      for section in elk_edge.sections {
        // Add start point
        edge.route.push(
          @graph.Point::new(section.start_point.x, section.start_point.y),
        )

        // Add bend points
        for bend in section.bend_points {
          edge.route.push(@graph.Point::new(bend.x, bend.y))
        }

        // Add end point
        edge.route.push(
          @graph.Point::new(section.end_point.x, section.end_point.y),
        )
      }

      // Apply label position if present
      if elk_edge.labels.length() > 0 {
        let label = elk_edge.labels[0]
        edge.label_box = Some(
          @graph.Box::new(label.x, label.y, label.width, label.height),
        )
      }
      return
    }
  }
}

// ============================================================================
// Port Conversion
// ============================================================================

///|
/// Convert ELK PortSide to diago PortSide
pub fn elk_port_side_to_graph(side : PortSide) -> @graph.PortSide {
  match side {
    North => @graph.Top
    South => @graph.Bottom
    East => @graph.Right
    West => @graph.Left
    Undefined => @graph.Top
  } // Default
}

///|
/// Convert diago PortSide to ELK PortSide
pub fn graph_port_side_to_elk(side : @graph.PortSide) -> PortSide {
  match side {
    @graph.Top => North
    @graph.Bottom => South
    @graph.Left => West
    @graph.Right => East
  }
}

// ============================================================================
// High-Level Layout Function
// ============================================================================

///|
/// Layout a diago graph using ELK algorithms
pub fn layout_diago_graph(
  graph : @graph.Graph,
  options : LayoutOptions,
) -> Unit raise LayoutError {
  // Convert to ELK format
  let elk_graph = from_graph(graph)

  // Run ELK layout
  layout(elk_graph, options)

  // Apply results back
  to_graph(elk_graph, graph)
}
