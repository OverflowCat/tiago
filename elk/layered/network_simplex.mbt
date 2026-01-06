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
/// Network Simplex Algorithm for Layer Assignment
/// Based on "A technique for drawing directed graphs" (Gansner et al., 1993)
///
/// The algorithm finds an optimal layer assignment that minimizes the total
/// edge length (sum of edge spans across layers).

// ============================================================================
// Network Simplex Data Structures
// ============================================================================

///|
/// A node in the network simplex graph
struct NSNode {
  id : String
  mut layer : Int // Layer assignment
  mut low : Int // Lowest postorder number in subtree
  mut lim : Int // Postorder number (limit)
  mut parent : NSNode? // Parent in spanning tree
  mut parent_edge : NSEdge? // Edge connecting to parent
} derive(Show)

///|
/// An edge in the network simplex graph
struct NSEdge {
  id : String
  source : NSNode
  target : NSNode
  weight : Int // Edge weight (typically 1)
  min_length : Int // Minimum length (typically 1)
  mut is_tree_edge : Bool // Part of spanning tree?
  mut cut_value : Int // Cut value for tree edges
} derive(Show)

///|
/// Network Simplex solver
struct NetworkSimplex {
  nodes : Array[NSNode]
  edges : Array[NSEdge]
  tree_edges : Array[NSEdge]
  mut postorder_count : Int
}

// ============================================================================
// Network Simplex Implementation
// ============================================================================

///|
fn NetworkSimplex::new() -> NetworkSimplex {
  { nodes: [], edges: [], tree_edges: [], postorder_count: 0 }
}

///|
/// Create network simplex problem from LGraph
fn NetworkSimplex::from_lgraph(graph : LGraph) -> NetworkSimplex {
  let ns = NetworkSimplex::new()
  let node_map : Map[String, NSNode] = {}

  // Create NS nodes
  for lnode in graph.nodes {
    let nsnode : NSNode = {
      id: lnode.id,
      layer: 0,
      low: 0,
      lim: 0,
      parent: None,
      parent_edge: None,
    }
    ns.nodes.push(nsnode)
    node_map[lnode.id] = nsnode
  }

  // Create NS edges
  for ledge in graph.edges {
    match (node_map.get(ledge.source.id), node_map.get(ledge.target.id)) {
      (Some(src), Some(tgt)) => {
        // Skip self-loops
        if src.id != tgt.id {
          let nsedge : NSEdge = {
            id: ledge.id,
            source: src,
            target: tgt,
            weight: 1,
            min_length: 1,
            is_tree_edge: false,
            cut_value: 0,
          }
          ns.edges.push(nsedge)
        }
      }
      _ => ()
    }
  }

  ns
}

///|
/// Execute the network simplex algorithm
fn NetworkSimplex::execute(self : NetworkSimplex) -> Unit {
  if self.nodes.length() == 0 {
    return
  }

  // Step 1: Find initial feasible tree
  self.feasible_tree()

  // Step 2: Iterate until optimal
  let max_iterations = self.nodes.length() * self.nodes.length()
  for iter = 0; iter < max_iterations; iter = iter + 1 {
    // Find a leaving edge (tree edge with negative cut value)
    let leave = self.leave_edge()
    match leave {
      None => break // Optimal solution found
      Some(leave_edge) => {
        // Find entering edge
        match self.enter_edge(leave_edge) {
          Some(enter_edge) => self.exchange(leave_edge, enter_edge)
          None => break // No improvement possible
        }
      }
    }
  }

  // Normalize layers to start at 0
  self.normalize()
}

///|
/// Find an initial feasible spanning tree using topological ordering
fn NetworkSimplex::feasible_tree(self : NetworkSimplex) -> Unit {
  // Initialize all nodes to layer 0
  for node in self.nodes {
    node.layer = 0
    node.parent = None
    node.parent_edge = None
  }

  self.tree_edges.clear()

  // Assign layers using longest path from sources
  let in_degree : Map[String, Int] = {}
  let out_edges : Map[String, Array[NSEdge]] = {}

  for node in self.nodes {
    in_degree[node.id] = 0
    out_edges[node.id] = []
  }

  for edge in self.edges {
    in_degree[edge.target.id] = in_degree.get(edge.target.id).unwrap_or(0) + 1
    match out_edges.get(edge.source.id) {
      Some(arr) => arr.push(edge)
      None => ()
    }
  }

  // Find sources and process in topological order
  let queue : Array[NSNode] = []
  for node in self.nodes {
    if in_degree.get(node.id).unwrap_or(0) == 0 {
      queue.push(node)
    }
  }

  while queue.length() > 0 {
    let node = queue.remove(0)
    for edge in out_edges.get(node.id).unwrap_or([]) {
      let target = edge.target
      // Layer must be at least source layer + min_length
      let required_layer = node.layer + edge.min_length
      if target.layer < required_layer {
        target.layer = required_layer
      }
      // Decrease in-degree and add to queue when ready
      let new_degree = in_degree.get(target.id).unwrap_or(1) - 1
      in_degree[target.id] = new_degree
      if new_degree == 0 {
        queue.push(target)
      }
    }
  }

  // Build spanning tree from tight edges (edges where length == min_length)
  let in_tree : Map[String, Bool] = {}
  in_tree[self.nodes[0].id] = true

  let mut tree_size = 1
  let target_size = self.nodes.length()

  // Keep adding tight edges until we have a spanning tree
  while tree_size < target_size {
    let mut added = false
    for edge in self.edges {
      let slack = self.slack(edge)
      if slack == 0 {
        // Tight edge
        let src_in = in_tree.get(edge.source.id).unwrap_or(false)
        let tgt_in = in_tree.get(edge.target.id).unwrap_or(false)
        if src_in && !tgt_in {
          // Add target to tree
          in_tree[edge.target.id] = true
          edge.is_tree_edge = true
          edge.target.parent = Some(edge.source)
          edge.target.parent_edge = Some(edge)
          self.tree_edges.push(edge)
          tree_size = tree_size + 1
          added = true
        } else if !src_in && tgt_in {
          // Add source to tree
          in_tree[edge.source.id] = true
          edge.is_tree_edge = true
          edge.source.parent = Some(edge.target)
          edge.source.parent_edge = Some(edge)
          self.tree_edges.push(edge)
          tree_size = tree_size + 1
          added = true
        }
      }
    }

    // If no tight edge found, tighten an edge
    if !added && tree_size < target_size {
      let mut min_slack = @int.max_value
      let mut best_edge : NSEdge? = None

      for edge in self.edges {
        let src_in = in_tree.get(edge.source.id).unwrap_or(false)
        let tgt_in = in_tree.get(edge.target.id).unwrap_or(false)
        if src_in != tgt_in {
          let slack = self.slack(edge)
          if slack > 0 && slack < min_slack {
            min_slack = slack
            best_edge = Some(edge)
          }
        }
      }

      // Adjust layers to make this edge tight
      match best_edge {
        Some(edge) => {
          let src_in = in_tree.get(edge.source.id).unwrap_or(false)
          if src_in {
            // Target not in tree, increase its layer
            for node in self.nodes {
              if !in_tree.get(node.id).unwrap_or(false) {
                node.layer = node.layer + min_slack
              }
            }
          } else {
            // Source not in tree, decrease its layer
            for node in self.nodes {
              if !in_tree.get(node.id).unwrap_or(false) {
                node.layer = node.layer - min_slack
              }
            }
          }
        }
        None => break // No edges to add
      }
    }
  }

  // Compute postorder and cut values
  self.postorder()
  self.compute_cut_values()
}

///|
/// Calculate slack of an edge (current length - minimum length)
fn NetworkSimplex::slack(self : NetworkSimplex, edge : NSEdge) -> Int {
  let _ = self
  edge.target.layer - edge.source.layer - edge.min_length
}

///|
/// Compute postorder traversal of spanning tree
fn NetworkSimplex::postorder(self : NetworkSimplex) -> Unit {
  self.postorder_count = 0

  // Find root (node with no parent)
  for node in self.nodes {
    if node.parent is None {
      self.postorder_dfs(node)
      break
    }
  }
}

///|
fn NetworkSimplex::postorder_dfs(self : NetworkSimplex, node : NSNode) -> Unit {
  node.low = self.postorder_count

  // Visit children
  for edge in self.tree_edges {
    if edge.source.id == node.id && edge.target.parent is Some(p) && p.id == node.id {
      self.postorder_dfs(edge.target)
    }
    if edge.target.id == node.id && edge.source.parent is Some(p) && p.id == node.id {
      self.postorder_dfs(edge.source)
    }
  }

  node.lim = self.postorder_count
  self.postorder_count = self.postorder_count + 1
}

///|
/// Compute cut values for all tree edges
fn NetworkSimplex::compute_cut_values(self : NetworkSimplex) -> Unit {
  for tree_edge in self.tree_edges {
    let mut cut_value = 0

    // For each edge, check if it contributes to cut value
    for edge in self.edges {
      let src_in_tail = self.in_head_component(tree_edge, edge.source)
      let tgt_in_tail = self.in_head_component(tree_edge, edge.target)

      if src_in_tail && !tgt_in_tail {
        // Edge from tail to head component
        cut_value = cut_value + edge.weight
      } else if !src_in_tail && tgt_in_tail {
        // Edge from head to tail component
        cut_value = cut_value - edge.weight
      }
    }

    tree_edge.cut_value = cut_value
  }
}

///|
/// Check if node is in the head component of the tree edge
fn NetworkSimplex::in_head_component(
  self : NetworkSimplex,
  tree_edge : NSEdge,
  node : NSNode,
) -> Bool {
  let _ = self
  // Node is in head component if it's in the subtree rooted at tree_edge.target
  let head = tree_edge.target
  node.lim >= head.low && node.lim <= head.lim
}

///|
/// Find a tree edge with negative cut value (leaving edge)
fn NetworkSimplex::leave_edge(self : NetworkSimplex) -> NSEdge? {
  for edge in self.tree_edges {
    if edge.cut_value < 0 {
      return Some(edge)
    }
  }
  None
}

///|
/// Find a non-tree edge to enter the tree
fn NetworkSimplex::enter_edge(
  self : NetworkSimplex,
  leave_edge : NSEdge,
) -> NSEdge? {
  let mut best_edge : NSEdge? = None
  let mut min_slack = @int.max_value

  for edge in self.edges {
    if edge.is_tree_edge {
      continue
    }

    // Check if edge crosses the cut in the right direction
    let src_in_head = self.in_head_component(leave_edge, edge.source)
    let tgt_in_head = self.in_head_component(leave_edge, edge.target)

    if src_in_head != tgt_in_head {
      let slack = self.slack(edge)
      if slack >= 0 && slack < min_slack {
        min_slack = slack
        best_edge = Some(edge)
      }
    }
  }

  best_edge
}

///|
/// Exchange leave edge with enter edge in the spanning tree
fn NetworkSimplex::exchange(
  self : NetworkSimplex,
  leave_edge : NSEdge,
  enter_edge : NSEdge,
) -> Unit {
  // Calculate the amount to shift layers
  let delta = self.slack(enter_edge)

  // Shift layers of nodes in the head component of leave_edge
  for node in self.nodes {
    if self.in_head_component(leave_edge, node) {
      node.layer = node.layer - delta
    }
  }

  // Update tree structure
  leave_edge.is_tree_edge = false
  enter_edge.is_tree_edge = true

  // Remove leave edge from tree_edges
  for i = 0; i < self.tree_edges.length(); i = i + 1 {
    if self.tree_edges[i].id == leave_edge.id {
      self.tree_edges.remove(i) |> ignore
      break
    }
  }

  // Add enter edge to tree_edges
  self.tree_edges.push(enter_edge)

  // Recompute postorder and cut values
  self.postorder()
  self.compute_cut_values()
}

///|
/// Normalize layers to start at 0
fn NetworkSimplex::normalize(self : NetworkSimplex) -> Unit {
  if self.nodes.length() == 0 {
    return
  }

  let mut min_layer = self.nodes[0].layer
  for node in self.nodes {
    if node.layer < min_layer {
      min_layer = node.layer
    }
  }

  for node in self.nodes {
    node.layer = node.layer - min_layer
  }
}

///|
/// Apply network simplex results back to LGraph
fn NetworkSimplex::apply_to_lgraph(
  self : NetworkSimplex,
  graph : LGraph,
) -> Unit {
  let layer_map : Map[String, Int] = {}
  for node in self.nodes {
    layer_map[node.id] = node.layer
  }

  for lnode in graph.nodes {
    lnode.layer = layer_map.get(lnode.id).unwrap_or(0)
  }
}

// ============================================================================
// Public API
// ============================================================================

///|
/// Run network simplex layer assignment on an LGraph
pub fn network_simplex_layer_assignment(graph : LGraph) -> Unit {
  if graph.nodes.length() == 0 {
    return
  }

  // Handle graphs with no edges - assign layers by definition order
  if graph.edges.length() == 0 {
    for i, node in graph.nodes {
      node.layer = i
    }
    return
  }

  let ns = NetworkSimplex::from_lgraph(graph)
  ns.execute()
  ns.apply_to_lgraph(graph)
}
