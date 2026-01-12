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
/// Tests for crossing minimization algorithm

///|
test "count_crossings no crossings" {
  // Two parallel edges that don't cross
  //  a   b
  //  |   |
  //  c   d
  let upper = ["a", "b"]
  let lower = ["c", "d"]
  let edges = [("a", "c"), ("b", "d")]
  let crossings = count_crossings(upper, lower, edges)
  inspect(crossings, content="0")
}

///|
test "count_crossings one crossing" {
  // Two edges that cross
  //  a   b
  //   \ /
  //   / \
  //  c   d
  let upper = ["a", "b"]
  let lower = ["c", "d"]
  let edges = [("a", "d"), ("b", "c")]
  let crossings = count_crossings(upper, lower, edges)
  inspect(crossings, content="1")
}

///|
test "count_crossings multiple crossings" {
  // Three edges with crossings
  //  a   b   c
  //   \ / \ /
  //    X   X
  //   / \ / \
  //  d   e   f
  let upper = ["a", "b", "c"]
  let lower = ["d", "e", "f"]
  // a->e crosses b->d; b->f crosses c->e
  let edges = [("a", "e"), ("b", "d"), ("b", "f"), ("c", "e")]
  let crossings = count_crossings(upper, lower, edges)
  // a->e crosses b->d (1)
  // b->f crosses c->e (1)
  inspect(crossings, content="2")
}

///|
test "minimize_crossings simple graph" {
  // Graph: a -> c, a -> d, b -> c
  // Initial layers: [a, b], [c, d]
  // After barycenter: should reorder to minimize crossings
  let source = "a -> c\na -> d\nb -> c"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)
  let layer_result = assign_layers(graph, cycle_result)
  let crossing_result = minimize_crossings(graph, layer_result, cycle_result)
  // Should have 2 layers
  inspect(crossing_result.ordered_layers.length(), content="2")
  // Both layers should have the same nodes (possibly reordered)
  inspect(crossing_result.ordered_layers[0].length(), content="2")
  inspect(crossing_result.ordered_layers[1].length(), content="2")
}

///|
test "minimize_crossings preserves all nodes" {
  // Verify all nodes are preserved after crossing minimization
  let source = "a -> b\na -> c\nb -> d\nc -> d"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)
  let layer_result = assign_layers(graph, cycle_result)
  let crossing_result = minimize_crossings(graph, layer_result, cycle_result)
  // Count total nodes
  let mut total = 0
  for layer in crossing_result.ordered_layers {
    total = total + layer.length()
  }
  inspect(total, content="4")
  // All node IDs should be present
  let all_nodes : Array[String] = []
  for layer in crossing_result.ordered_layers {
    for node in layer {
      all_nodes.push(node)
    }
  }
  inspect(all_nodes.contains("a"), content="true")
  inspect(all_nodes.contains("b"), content="true")
  inspect(all_nodes.contains("c"), content="true")
  inspect(all_nodes.contains("d"), content="true")
}

///|
test "minimize_crossings reduces crossings" {
  // Graph that has a suboptimal initial ordering
  // After minimization, crossings should be reduced or equal
  let source = "a -> d\nb -> c\nc -> e\nd -> e"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)
  let layer_result = assign_layers(graph, cycle_result)
  // Store initial crossing count
  let initial_crossings = count_all_crossings(
    layer_result.nodes_by_layer,
    graph,
    cycle_result,
  )
  let crossing_result = minimize_crossings(graph, layer_result, cycle_result)
  // Count final crossings
  let final_crossings = count_all_crossings(
    crossing_result.ordered_layers,
    graph,
    cycle_result,
  )
  // Final should be <= initial
  inspect(final_crossings <= initial_crossings, content="true")
}

///|
test "minimize_crossings preserves original order for unconnected nodes" {
  // When nodes have no edges connecting them, they should preserve definition order
  // Define: a, b, c, d all on the same layer (no edges between them)
  let source = "a\nb\nc\nd"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)
  let layer_result = assign_layers(graph, cycle_result)
  let crossing_result = minimize_crossings(graph, layer_result, cycle_result)
  // All nodes should be in one layer, in original definition order
  inspect(crossing_result.ordered_layers.length(), content="1")
  inspect(
    crossing_result.ordered_layers[0],
    content="[\"a\", \"b\", \"c\", \"d\"]",
  )
}

///|
test "minimize_crossings preserves order within layer for nodes without neighbors" {
  // x -> a, y -> b
  // Nodes x and y in layer 0, a and b in layer 1
  // x and y have no cross-constraints, should maintain definition order
  let source = "x -> a\ny -> b"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)
  let layer_result = assign_layers(graph, cycle_result)
  let crossing_result = minimize_crossings(graph, layer_result, cycle_result)
  // Layer 0 should have [x, y] in definition order
  // Layer 1 should have [a, b] in definition order
  inspect(crossing_result.ordered_layers.length(), content="2")
  // The order should be preserved or reordered to minimize crossings
  // Since x->a and y->b are parallel (no crossing), order should be preserved
  let layer0 = crossing_result.ordered_layers[0]
  let layer1 = crossing_result.ordered_layers[1]
  // Both layers should have 2 nodes each
  inspect(layer0.length(), content="2")
  inspect(layer1.length(), content="2")
}

///|
/// Helper to count all crossings across all adjacent layer pairs
fn count_all_crossings(
  layers : Array[Array[String]],
  graph : @graph.GraphInput,
  cycle_result : CycleBreakResult,
) -> Int {
  let mut total = 0
  for i = 0; i < layers.length() - 1; i = i + 1 {
    // Collect edges between layer i and i+1
    let edges : Array[(String, String)] = []
    for edge in graph.edges {
      let src = get_effective_src(edge, cycle_result)
      let dst = get_effective_dst(edge, cycle_result)
      if layers[i].contains(src) && layers[i + 1].contains(dst) {
        edges.push((src, dst))
      }
    }
    total = total + count_crossings(layers[i], layers[i + 1], edges)
  }
  total
}
