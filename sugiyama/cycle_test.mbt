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
/// Tests for cycle breaking algorithm

///|
test "break_cycles detects simple cycle" {
  // Create a graph with cycle: a -> b -> c -> a
  let source = "a -> b\nb -> c\nc -> a"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let result = break_cycles(graph)
  // Should have found one back-edge to break
  inspect(result.had_cycles, content="true")
  inspect(result.reversed_edges.length() > 0, content="true")
}

///|
test "break_cycles handles DAG" {
  // Create a DAG (no cycles): a -> b -> c
  let source = "a -> b\nb -> c"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let result = break_cycles(graph)
  // No cycles to break
  inspect(result.had_cycles, content="false")
  inspect(result.reversed_edges.length(), content="0")
}

///|
test "break_cycles handles self-loop" {
  // Self-loop: a -> a
  let source = "a -> a"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let result = break_cycles(graph)
  // Self-loop is a cycle
  inspect(result.had_cycles, content="true")
}

///|
test "break_cycles handles diamond" {
  // Diamond: a -> b, a -> c, b -> d, c -> d (no cycle)
  let source = "a -> b\na -> c\nb -> d\nc -> d"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let result = break_cycles(graph)
  inspect(result.had_cycles, content="false")
}

///|
test "break_cycles handles multiple cycles" {
  // Two cycles: a -> b -> a, c -> d -> c
  let source = "a -> b\nb -> a\nc -> d\nd -> c"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let result = break_cycles(graph)
  inspect(result.had_cycles, content="true")
  // Should break at least 2 edges (one per cycle)
  inspect(result.reversed_edges.length() >= 2, content="true")
}

///|
test "get_effective_src/dst respects reversal" {
  let source = "a -> b\nb -> a"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let result = break_cycles(graph)
  // At least one edge should be reversed
  let mut found_reversed = false
  for edge in graph.edges {
    if is_edge_reversed(result, edge.index) {
      // Reversed edge should swap src/dst
      let eff_src = get_effective_src(edge, result)
      let eff_dst = get_effective_dst(edge, result)
      inspect(eff_src == edge.get_dst_id(), content="true")
      inspect(eff_dst == edge.get_src_id(), content="true")
      found_reversed = true
      break
    }
  }
  inspect(found_reversed, content="true")
}
