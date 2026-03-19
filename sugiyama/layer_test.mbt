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
/// Tests for layer assignment algorithm

///|
test "layer assignment classes example - alice and bob at top" {
  // alice -> web1, bob -> web2, web1 -> db1, web2 -> db1, db1 -> db2
  // Expected layers: [alice, bob] -> [web1, web2] -> [db1] -> [db2]
  let source =
    #|alice: Alice
    #|bob: Bob
    #|web1: Web Server 1
    #|web2: Web Server 2
    #|db1: Primary DB
    #|db2: Replica DB
    #|alice -> web1
    #|bob -> web2
    #|web1 -> db1
    #|web2 -> db1
    #|db1 -> db2
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)

  // Should have no reversed edges (no cycles)
  inspect(cycle_result.reversed_edges.length(), content="0")
  let layer_result = assign_layers(graph, cycle_result)

  // alice and bob should be at layer 0 (sources)
  inspect(layer_result.layers.get("alice"), content="Some(0)")
  inspect(layer_result.layers.get("bob"), content="Some(0)")

  // web1 and web2 should be at layer 1
  inspect(layer_result.layers.get("web1"), content="Some(1)")
  inspect(layer_result.layers.get("web2"), content="Some(1)")

  // db1 should be at layer 2
  inspect(layer_result.layers.get("db1"), content="Some(2)")

  // db2 should be at layer 3
  inspect(layer_result.layers.get("db2"), content="Some(3)")
}

///|
test "assign_layers simple chain" {
  // a -> b -> c should be layers 0, 1, 2
  let source = "a -> b\nb -> c"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)
  let result = assign_layers(graph, cycle_result)
  // Should have 3 layers
  inspect(result.layer_count, content="3")
  // Check layer assignments
  let layer_a = result.layers.get("a")
  let layer_b = result.layers.get("b")
  let layer_c = result.layers.get("c")
  inspect(layer_a, content="Some(0)")
  inspect(layer_b, content="Some(1)")
  inspect(layer_c, content="Some(2)")
}

///|
test "assign_layers diamond" {
  // Diamond: a -> b, a -> c, b -> d, c -> d
  // a should be layer 0, b/c layer 1, d layer 2
  let source = "a -> b\na -> c\nb -> d\nc -> d"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)
  let result = assign_layers(graph, cycle_result)
  // Should have 3 layers
  inspect(result.layer_count, content="3")
  // Check key relationships
  let layer_a = match result.layers.get("a") {
    Some(l) => l
    None => -1
  }
  let layer_b = match result.layers.get("b") {
    Some(l) => l
    None => -1
  }
  let layer_c = match result.layers.get("c") {
    Some(l) => l
    None => -1
  }
  let layer_d = match result.layers.get("d") {
    Some(l) => l
    None => -1
  }
  // a < b, a < c, b < d, c < d
  inspect(layer_a < layer_b, content="true")
  inspect(layer_a < layer_c, content="true")
  inspect(layer_b < layer_d, content="true")
  inspect(layer_c < layer_d, content="true")
}

///|
test "assign_layers independent nodes" {
  // No edges: all nodes in layer 0
  let source = "a\nb\nc"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)
  let result = assign_layers(graph, cycle_result)
  // All nodes should be in layer 0
  inspect(result.layer_count, content="1")
  inspect(result.layers.get("a"), content="Some(0)")
  inspect(result.layers.get("b"), content="Some(0)")
  inspect(result.layers.get("c"), content="Some(0)")
}

///|
test "assign_layers with cycle" {
  // a -> b -> c -> a (cycle)
  // After cycle breaking, should still get valid layering
  let source = "a -> b\nb -> c\nc -> a"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)
  let result = assign_layers(graph, cycle_result)
  // Should have valid layers (at least 1)
  inspect(result.layer_count >= 1, content="true")
  // All nodes should have layers
  inspect(result.layers.get("a") is Some(_), content="true")
  inspect(result.layers.get("b") is Some(_), content="true")
  inspect(result.layers.get("c") is Some(_), content="true")
}

///|
test "nodes_by_layer grouping" {
  let source = "a -> b\na -> c\nb -> d\nc -> d"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = graph_input
  let cycle_result = break_cycles(graph)
  let result = assign_layers(graph, cycle_result)
  // Check nodes_by_layer
  inspect(result.nodes_by_layer.length(), content="3")
  // Layer 0 should have "a"
  inspect(result.nodes_by_layer[0].contains("a"), content="true")
  // Layer 2 should have "d"
  inspect(result.nodes_by_layer[2].contains("d"), content="true")
}
