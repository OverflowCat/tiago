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
/// Tests for coordinate assignment algorithm

///|
test "assign_coordinates simple chain" {
  // a -> b -> c should have increasing y coordinates
  let source = "a -> b\nb -> c"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = @graph.Graph::from_input(graph_input)
  let cycle_result = break_cycles(graph)
  let layer_result = assign_layers(graph, cycle_result)
  let crossing_result = minimize_crossings(graph, layer_result, cycle_result)
  // Collect node dimensions
  let widths : Map[String, Double] = {}
  let heights : Map[String, Double] = {}
  widths["a"] = 100.0
  widths["b"] = 100.0
  widths["c"] = 100.0
  heights["a"] = 60.0
  heights["b"] = 60.0
  heights["c"] = 60.0
  let coords = assign_coordinates(
    graph, crossing_result, cycle_result, widths, heights, 60.0, 40.0,
  )
  // All nodes should have coordinates
  inspect(coords.x_coords.get("a") is Some(_), content="true")
  inspect(coords.x_coords.get("b") is Some(_), content="true")
  inspect(coords.x_coords.get("c") is Some(_), content="true")
  // Y coordinates should increase (a < b < c)
  let ya = coords.y_coords.get("a").unwrap_or(0.0)
  let yb = coords.y_coords.get("b").unwrap_or(0.0)
  let yc = coords.y_coords.get("c").unwrap_or(0.0)
  inspect(ya < yb, content="true")
  inspect(yb < yc, content="true")
}

///|
test "assign_coordinates diamond" {
  // Diamond: a -> b, a -> c, b -> d, c -> d
  // b and c should be in same layer with different x
  let source = "a -> b\na -> c\nb -> d\nc -> d"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = @graph.Graph::from_input(graph_input)
  let cycle_result = break_cycles(graph)
  let layer_result = assign_layers(graph, cycle_result)
  let crossing_result = minimize_crossings(graph, layer_result, cycle_result)
  let widths : Map[String, Double] = {}
  let heights : Map[String, Double] = {}
  for node in ["a", "b", "c", "d"] {
    widths[node] = 100.0
    heights[node] = 60.0
  }
  let coords = assign_coordinates(
    graph, crossing_result, cycle_result, widths, heights, 60.0, 40.0,
  )
  // b and c should have same y (same layer)
  let yb = coords.y_coords.get("b").unwrap_or(0.0)
  let yc = coords.y_coords.get("c").unwrap_or(0.0)
  inspect(yb == yc, content="true")
  // b and c should have different x
  let xb = coords.x_coords.get("b").unwrap_or(0.0)
  let xc = coords.x_coords.get("c").unwrap_or(0.0)
  inspect(xb != xc, content="true")
}

///|
test "assign_coordinates_simple" {
  let source = "a -> b\na -> c"
  let (ast, _) = @parser.parse(source)
  let ir = @ir.compile(ast)
  let graph_input = @exporter.compile("test", ir)
  let graph = @graph.Graph::from_input(graph_input)
  let cycle_result = break_cycles(graph)
  let layer_result = assign_layers(graph, cycle_result)
  let crossing_result = minimize_crossings(graph, layer_result, cycle_result)
  let widths : Map[String, Double] = {}
  let heights : Map[String, Double] = {}
  widths["a"] = 100.0
  widths["b"] = 100.0
  widths["c"] = 100.0
  heights["a"] = 60.0
  heights["b"] = 60.0
  heights["c"] = 60.0
  let coords = assign_coordinates_simple(
    crossing_result, widths, heights, 60.0, 40.0, 20.0,
  )
  // All nodes should have coordinates starting from padding
  let xa = coords.x_coords.get("a").unwrap_or(0.0)
  inspect(xa >= 20.0, content="true")
  let ya = coords.y_coords.get("a").unwrap_or(0.0)
  inspect(ya >= 20.0, content="true")
}
