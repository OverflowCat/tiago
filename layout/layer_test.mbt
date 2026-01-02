///|
/// Tests for layer assignment algorithm

///|
test "assign_layers simple chain" {
  // a -> b -> c should be layers 0, 1, 2
  let source = "a -> b\nb -> c"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph = @graph.compile("test", ir)
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
  let graph = @graph.compile("test", ir)
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
  let graph = @graph.compile("test", ir)
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
  let graph = @graph.compile("test", ir)
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
  let graph = @graph.compile("test", ir)
  let cycle_result = break_cycles(graph)
  let result = assign_layers(graph, cycle_result)
  // Check nodes_by_layer
  inspect(result.nodes_by_layer.length(), content="3")
  // Layer 0 should have "a"
  inspect(result.nodes_by_layer[0].contains("a"), content="true")
  // Layer 2 should have "d"
  inspect(result.nodes_by_layer[2].contains("d"), content="true")
}
