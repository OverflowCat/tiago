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
/// Greedy DFS Cycle Breaking
///
/// Implements the first phase of the Sugiyama framework for layered graph layout.
/// Uses depth-first search to find back-edges that create cycles, then marks
/// them for reversal to create a directed acyclic graph (DAG).

///|
/// DFS node state for cycle detection
priv enum NodeState {
  /// Not yet visited
  White
  /// Currently on the DFS stack (being explored)
  Gray
  /// Finished exploration
  Black
}

///|
/// Result of cycle breaking algorithm
pub(all) struct CycleBreakResult {
  /// Indices of edges that should be reversed to break cycles
  reversed_edges : Array[Int]
  /// Whether the original graph had cycles
  had_cycles : Bool
}

///|
/// Find edges that need to be reversed to break all cycles (Feedback Arc Set)
/// Uses greedy DFS traversal - edges pointing to nodes on the current DFS stack
/// are back-edges that create cycles.
pub fn break_cycles(graph : @graph.Graph) -> CycleBreakResult {
  // Build adjacency list: node_id -> [(edge_index, target_id)]
  let adj : Map[String, Array[(Int, String)]] = {}
  for edge in graph.edges {
    let src = edge.get_src_id()
    let dst = edge.get_dst_id()
    match adj.get(src) {
      Some(neighbors) => neighbors.push((edge.index, dst))
      None => adj[src] = [(edge.index, dst)]
    }
  }
  // Collect all node IDs
  let nodes : Array[String] = []
  for obj in graph.objects {
    collect_node_ids(obj, nodes)
  }
  // DFS state
  let state : Map[String, NodeState] = {}
  for node in nodes {
    state[node] = White
  }
  // Reversed edges (feedback arc set)
  let reversed : Array[Int] = []
  // Run DFS from each unvisited node
  for node in nodes {
    match state.get(node) {
      Some(White) => dfs_visit(node, adj, state, reversed)
      _ => ()
    }
  }
  { reversed_edges: reversed, had_cycles: reversed.length() > 0 }
}

///|
/// Collect all node IDs from object tree
fn collect_node_ids(obj : @graph.Object, nodes : Array[String]) -> Unit {
  nodes.push(obj.id)
  for child in obj.children {
    collect_node_ids(child, nodes)
  }
}

///|
/// DFS visit for cycle detection
fn dfs_visit(
  node : String,
  adj : Map[String, Array[(Int, String)]],
  state : Map[String, NodeState],
  reversed : Array[Int],
) -> Unit {
  // Mark as being explored (on DFS stack)
  state[node] = Gray
  // Visit all outgoing edges
  match adj.get(node) {
    Some(neighbors) =>
      for neighbor in neighbors {
        let (edge_idx, target) = neighbor
        match state.get(target) {
          Some(White) =>
            // Unvisited - continue DFS
            dfs_visit(target, adj, state, reversed)
          Some(Gray) =>
            // Back-edge! Target is on current DFS stack, creating a cycle
            // Mark this edge for reversal
            reversed.push(edge_idx)
          Some(Black) =>
            // Cross-edge or forward-edge - no cycle
            ()
          None =>
            // Node not in graph (edge to non-existent node)
            ()
        }
      }
    None =>
      // No outgoing edges
      ()
  }
  // Mark as finished
  state[node] = Black
}

///|
/// Check if an edge should be treated as reversed during layout
pub fn is_edge_reversed(result : CycleBreakResult, edge_index : Int) -> Bool {
  result.reversed_edges.contains(edge_index)
}

///|
/// Get the effective source of an edge (accounting for reversal)
pub fn get_effective_src(
  edge : @graph.Edge,
  result : CycleBreakResult,
) -> String {
  if is_edge_reversed(result, edge.index) {
    edge.get_dst_id()
  } else {
    edge.get_src_id()
  }
}

///|
/// Get the effective destination of an edge (accounting for reversal)
pub fn get_effective_dst(
  edge : @graph.Edge,
  result : CycleBreakResult,
) -> String {
  if is_edge_reversed(result, edge.index) {
    edge.get_src_id()
  } else {
    edge.get_dst_id()
  }
}
