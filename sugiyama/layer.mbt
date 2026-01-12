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
/// Layer Assignment using Network Simplex
///
/// Implements the second phase of the Sugiyama framework.
/// Assigns each node to a discrete layer such that:
/// 1. For each edge (u,v): layer(v) > layer(u)
/// 2. Total edge span is minimized

///|
/// Result of layer assignment
pub(all) struct LayerAssignment {
  /// Map from node ID to layer number (0-indexed)
  layers : Map[String, Int]
  /// Number of layers
  layer_count : Int
  /// Nodes grouped by layer
  nodes_by_layer : Array[Array[String]]
}

///|
/// Assign layers to nodes in the graph
/// Uses longest path for initial assignment, then network simplex to optimize
pub fn assign_layers(
  graph : @graph.GraphInput,
  cycle_result : CycleBreakResult,
) -> LayerAssignment {
  // Build adjacency using effective edge directions (after cycle breaking)
  let adj : Map[String, Array[String]] = {}
  let pred : Map[String, Array[String]] = {}
  let all_nodes : Array[String] = []
  // Collect all nodes
  for obj in graph.objects {
    collect_all_nodes(graph, obj, all_nodes)
  }
  // Initialize adjacency lists
  for node in all_nodes {
    adj[node] = []
    pred[node] = []
  }
  // Build adjacency from edges
  for edge in graph.edges {
    let src = get_effective_src(edge, cycle_result)
    let dst = get_effective_dst(edge, cycle_result)
    match adj.get(src) {
      Some(neighbors) => neighbors.push(dst)
      None => ()
    }
    match pred.get(dst) {
      Some(predecessors) => predecessors.push(src)
      None => ()
    }
  }
  // Initial layer assignment using longest path algorithm
  let initial_layers = longest_path_layering(all_nodes, adj, pred)
  // Optimize with network simplex (minimize total edge span)
  let layers = network_simplex(all_nodes, adj, pred, initial_layers)
  build_layer_result(all_nodes, layers)
}

///|
/// Collect all node IDs from object tree
fn collect_all_nodes(
  graph : @graph.GraphInput,
  obj : @graph.ObjectInput,
  nodes : Array[String],
) -> Unit {
  nodes.push(obj.id)
  for child in graph.children_of(obj) {
    collect_all_nodes(graph, child, nodes)
  }
}

///|
/// Initial layer assignment using longest path algorithm
/// Assigns each node to layer = max(predecessor layers) + 1
fn longest_path_layering(
  nodes : Array[String],
  adj : Map[String, Array[String]],
  pred : Map[String, Array[String]],
) -> Map[String, Int] {
  let layers : Map[String, Int] = {}
  let in_degree : Map[String, Int] = {}
  // Compute in-degrees
  for node in nodes {
    let preds = match pred.get(node) {
      Some(p) => p.length()
      None => 0
    }
    in_degree[node] = preds
  }
  // Process nodes in topological order
  let queue : Array[String] = []
  for node in nodes {
    match in_degree.get(node) {
      Some(0) => {
        queue.push(node)
        layers[node] = 0
      }
      _ => ()
    }
  }
  while queue.length() > 0 {
    let node = queue.remove(0)
    let node_layer = match layers.get(node) {
      Some(l) => l
      None => 0
    }
    // Update successors
    match adj.get(node) {
      Some(successors) =>
        for succ in successors {
          // Successor layer = max(current, node_layer + 1)
          let new_layer = node_layer + 1
          match layers.get(succ) {
            Some(curr) => if new_layer > curr { layers[succ] = new_layer }
            None => layers[succ] = new_layer
          }
          // Decrease in-degree
          match in_degree.get(succ) {
            Some(d) => {
              let new_deg = d - 1
              in_degree[succ] = new_deg
              if new_deg == 0 {
                queue.push(succ)
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }
  // Handle any unassigned nodes (disconnected)
  for node in nodes {
    match layers.get(node) {
      None => layers[node] = 0
      Some(_) => ()
    }
  }
  layers
}

///|
/// Network Simplex optimization for layer assignment
/// Minimizes total edge span while maintaining valid layering
fn network_simplex(
  nodes : Array[String],
  adj : Map[String, Array[String]],
  pred : Map[String, Array[String]],
  initial_layers : Map[String, Int],
) -> Map[String, Int] {
  // For network simplex, we need to:
  // 1. Build a feasible spanning tree
  // 2. Compute potentials (node layers)
  // 3. Find leaving edge (negative cut value)
  // 4. Find entering edge
  // 5. Pivot until optimal

  // Copy initial layers
  let layers : Map[String, Int] = {}
  for node in nodes {
    match initial_layers.get(node) {
      Some(l) => layers[node] = l
      None => layers[node] = 0
    }
  }
  // Build initial spanning tree
  let tree_edges = build_spanning_tree(nodes, adj, pred)
  // Iterate until no improvement
  let max_iterations = nodes.length() * nodes.length()
  for i = 0; i < max_iterations; i = i + 1 {
    // Compute cut values for tree edges
    let cut_values = compute_cut_values(nodes, adj, tree_edges)
    // Find leaving edge (negative cut value)
    let leaving = find_leaving_edge(cut_values)
    match leaving {
      None => break // Optimal
      Some(leave_idx) => {
        // Find entering edge
        let entering = find_entering_edge(
          nodes, adj, tree_edges, leave_idx, layers,
        )
        match entering {
          Some((src, dst)) =>
            // Pivot: remove leaving edge, add entering edge
            pivot(tree_edges, leave_idx, src, dst, layers)
          None => break
        }
      }
    }
  }
  // Normalize layers to start from 0
  normalize_layers(nodes, layers)
  layers
}

///|
/// Build initial feasible spanning tree
/// Uses DFS to build a spanning tree from the graph edges
fn build_spanning_tree(
  nodes : Array[String],
  adj : Map[String, Array[String]],
  pred : Map[String, Array[String]],
) -> Array[(String, String)] {
  let tree : Array[(String, String)] = []
  let in_tree : Map[String, Bool] = {}
  if nodes.length() == 0 {
    return tree
  }
  // Start with first node
  in_tree[nodes[0]] = true
  // Use DFS to add edges greedily
  let stack : Array[String] = [nodes[0]]
  while stack.length() > 0 {
    let node = stack.pop().unwrap()
    // Check outgoing edges
    match adj.get(node) {
      Some(successors) =>
        for succ in successors {
          match in_tree.get(succ) {
            Some(true) => ()
            _ => {
              tree.push((node, succ))
              in_tree[succ] = true
              stack.push(succ)
            }
          }
        }
      None => ()
    }
    // Check incoming edges
    match pred.get(node) {
      Some(predecessors) =>
        for p in predecessors {
          match in_tree.get(p) {
            Some(true) => ()
            _ => {
              tree.push((p, node))
              in_tree[p] = true
              stack.push(p)
            }
          }
        }
      None => ()
    }
  }
  // Handle disconnected components - just mark them as in tree
  // (no edges to add for truly disconnected nodes)
  for node in nodes {
    match in_tree.get(node) {
      Some(true) => ()
      _ => in_tree[node] = true
    }
  }
  tree
}

///|
/// Compute slack for an edge: layer(dst) - layer(src) - minlen
/// minlen is typically 1 for hierarchical layouts
fn compute_slack(src : String, dst : String, layers : Map[String, Int]) -> Int {
  let src_layer = match layers.get(src) {
    Some(l) => l
    None => 0
  }
  let dst_layer = match layers.get(dst) {
    Some(l) => l
    None => 0
  }
  dst_layer - src_layer - 1
}

///|
/// Tree structure for low/lim optimization
/// Enables O(1) subtree membership testing
priv struct TreeInfo {
  low : Map[String, Int] // Lowest DFS number in subtree
  lim : Map[String, Int] // Highest DFS number in subtree (DFS order of node)
}

///|
/// Initialize low/lim values for the spanning tree
/// This enables O(1) subtree membership testing
fn init_low_lim_values(
  nodes : Array[String],
  tree_edges : Array[(String, String)],
) -> TreeInfo {
  // Build parent-child relationships from tree edges
  let children : Map[String, Array[String]] = {}
  let low : Map[String, Int] = {}
  let lim : Map[String, Int] = {}
  // Initialize children arrays
  for node in nodes {
    children[node] = []
  }
  // Find root (nodes without a parent in the tree)
  let has_parent : Map[String, Bool] = {}
  for edge in tree_edges {
    let (src, dst) = edge
    // In a directed spanning tree, src is parent of dst
    has_parent[dst] = true
    match children.get(src) {
      Some(c) => c.push(dst)
      None => children[src] = [dst]
    }
  }
  // Find root node
  let mut root = ""
  for node in nodes {
    match has_parent.get(node) {
      Some(true) => ()
      _ => {
        root = node
        break
      }
    }
  }
  if root == "" && nodes.length() > 0 {
    root = nodes[0]
  }
  // DFS to compute low/lim values
  fn dfs(
    node : String,
    children : Map[String, Array[String]],
    low : Map[String, Int],
    lim : Map[String, Int],
    dfs_num : Ref[Int],
  ) {
    let my_low = dfs_num.val
    let mut max_lim = dfs_num.val
    dfs_num.val = dfs_num.val + 1
    match children.get(node) {
      Some(childs) =>
        for child in childs {
          dfs(child, children, low, lim, dfs_num)
          match lim.get(child) {
            Some(child_lim) => if child_lim > max_lim { max_lim = child_lim }
            None => ()
          }
        }
      None => ()
    }
    low[node] = my_low
    lim[node] = max_lim
  }

  let dfs_num_ref : Ref[Int] = { val: 0 }
  if root != "" {
    dfs(root, children, low, lim, dfs_num_ref)
  }
  // Handle disconnected nodes
  for node in nodes {
    match lim.get(node) {
      Some(_) => ()
      None => {
        low[node] = dfs_num_ref.val
        lim[node] = dfs_num_ref.val
        dfs_num_ref.val = dfs_num_ref.val + 1
      }
    }
  }
  { low, lim }
}

///|
/// Check if node is in the subtree rooted at subtree_root
/// Uses low/lim for O(1) check: low(root) <= lim(node) <= lim(root)
fn is_in_subtree(
  node : String,
  subtree_root : String,
  tree_info : TreeInfo,
) -> Bool {
  let node_lim = match tree_info.lim.get(node) {
    Some(l) => l
    None => return false
  }
  let root_low = match tree_info.low.get(subtree_root) {
    Some(l) => l
    None => return false
  }
  let root_lim = match tree_info.lim.get(subtree_root) {
    Some(l) => l
    None => return false
  }
  root_low <= node_lim && node_lim <= root_lim
}

///|
/// Compute cut values for tree edges using low/lim optimization
/// Cut value = number of edges going down - edges going up across the cut
/// A negative cut value indicates the edge should be removed from the tree
fn compute_cut_values(
  nodes : Array[String],
  adj : Map[String, Array[String]],
  tree_edges : Array[(String, String)],
) -> Array[Int] {
  // Initialize low/lim values for O(1) subtree membership
  let tree_info = init_low_lim_values(nodes, tree_edges)
  let cut_values : Array[Int] = []
  for edge in tree_edges {
    let (_src, dst) = edge
    // For tree edge (src, dst), we consider dst as the subtree root
    // Tail side = subtree rooted at dst
    // Head side = everything else
    // Count edges crossing the cut
    let mut cut_value = 0
    // Edge from tail to head counts as +1, head to tail as -1
    for node in nodes {
      let in_tail = is_in_subtree(node, dst, tree_info)
      match adj.get(node) {
        Some(successors) =>
          for succ in successors {
            let succ_in_tail = is_in_subtree(succ, dst, tree_info)
            if in_tail && not(succ_in_tail) {
              // Edge from tail to head side
              cut_value = cut_value + 1
            } else if not(in_tail) && succ_in_tail {
              // Edge from head to tail side
              cut_value = cut_value - 1
            }
          }
        None => ()
      }
    }
    cut_values.push(cut_value)
  }
  cut_values
}

///|
/// Compute the tail component when an edge is removed from tree
fn compute_tail_component(
  src : String,
  dst : String,
  tree_edges : Array[(String, String)],
) -> Array[String] {
  // BFS from src without using the (src, dst) edge
  let component : Array[String] = []
  let visited : Map[String, Bool] = {}
  let queue : Array[String] = [src]
  visited[src] = true
  while queue.length() > 0 {
    let node = queue.remove(0)
    component.push(node)
    // Find tree neighbors
    for edge in tree_edges {
      let (e_src, e_dst) = edge
      // Skip the removed edge
      if e_src == src && e_dst == dst {
        continue
      }
      if e_src == dst && e_dst == src {
        continue
      }
      // Check if this edge connects to current node
      if e_src == node {
        match visited.get(e_dst) {
          Some(true) => ()
          _ => {
            visited[e_dst] = true
            queue.push(e_dst)
          }
        }
      } else if e_dst == node {
        match visited.get(e_src) {
          Some(true) => ()
          _ => {
            visited[e_src] = true
            queue.push(e_src)
          }
        }
      }
    }
  }
  component
}

///|
/// Find edge with negative cut value (leaving edge)
fn find_leaving_edge(cut_values : Array[Int]) -> Int? {
  for i, cv in cut_values {
    if cv < 0 {
      return Some(i)
    }
  }
  None
}

///|
/// Find edge to enter the tree
/// Looks for a non-tree edge crossing the cut with minimum slack
fn find_entering_edge(
  nodes : Array[String],
  adj : Map[String, Array[String]],
  tree_edges : Array[(String, String)],
  leave_idx : Int,
  layers : Map[String, Int],
) -> (String, String)? {
  let (leave_src, leave_dst) = tree_edges[leave_idx]
  let tail_side = compute_tail_component(leave_src, leave_dst, tree_edges)
  // Find non-tree edge crossing the cut with minimum slack
  let mut best_edge : (String, String)? = None
  let mut best_slack = 1000000
  for node in nodes {
    let in_tail = tail_side.contains(node)
    match adj.get(node) {
      Some(successors) =>
        for succ in successors {
          let succ_in_tail = tail_side.contains(succ)
          // Edge crossing from head to tail (opposite direction of leaving)
          if not(in_tail) && succ_in_tail {
            // Check if it's a non-tree edge
            let is_tree_edge = is_in_tree(node, succ, tree_edges)
            if not(is_tree_edge) {
              let slack = compute_slack(node, succ, layers)
              if slack < best_slack {
                best_slack = slack
                best_edge = Some((node, succ))
              }
            }
          }
        }
      None => ()
    }
  }
  best_edge
}

///|
/// Check if edge is in the tree
fn is_in_tree(
  src : String,
  dst : String,
  tree_edges : Array[(String, String)],
) -> Bool {
  for edge in tree_edges {
    let (e_src, e_dst) = edge
    if (e_src == src && e_dst == dst) || (e_src == dst && e_dst == src) {
      return true
    }
  }
  false
}

///|
/// Pivot: exchange leaving and entering edges, update layers
/// This is the core operation of network simplex - swaps edges and adjusts ranks
fn pivot(
  tree_edges : Array[(String, String)],
  leave_idx : Int,
  enter_src : String,
  enter_dst : String,
  layers : Map[String, Int],
) -> Unit {
  let (leave_src, leave_dst) = tree_edges[leave_idx]
  // Compute component to adjust (the tail side when leaving edge is removed)
  let tail_side = compute_tail_component(leave_src, leave_dst, tree_edges)
  // Compute slack of entering edge
  let slack = compute_slack(enter_src, enter_dst, layers)
  // Adjust layers in tail component to make entering edge tight
  if slack != 0 {
    for node in tail_side {
      match layers.get(node) {
        Some(l) => layers[node] = l - slack
        None => ()
      }
    }
  }
  // Update tree: remove leaving edge, add entering edge
  tree_edges[leave_idx] = (enter_src, enter_dst)
}

///|
/// Normalize layers to start from 0
fn normalize_layers(nodes : Array[String], layers : Map[String, Int]) -> Unit {
  let mut min_layer = 1000000
  for node in nodes {
    match layers.get(node) {
      Some(l) => if l < min_layer { min_layer = l }
      None => ()
    }
  }
  if min_layer != 0 && min_layer != 1000000 {
    for node in nodes {
      match layers.get(node) {
        Some(l) => layers[node] = l - min_layer
        None => ()
      }
    }
  }
}

///|
/// Build the final layer result
fn build_layer_result(
  nodes : Array[String],
  layers : Map[String, Int],
) -> LayerAssignment {
  // Find max layer
  let mut max_layer = 0
  for node in nodes {
    match layers.get(node) {
      Some(l) => if l > max_layer { max_layer = l }
      None => ()
    }
  }
  // Group nodes by layer
  let layer_count = max_layer + 1
  let nodes_by_layer : Array[Array[String]] = []
  for _ in 0..<layer_count {
    nodes_by_layer.push([])
  }
  for node in nodes {
    match layers.get(node) {
      Some(l) => if l >= 0 && l < layer_count { nodes_by_layer[l].push(node) }
      None => ()
    }
  }
  { layers, layer_count, nodes_by_layer }
}
