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
test "compile_graph attaches vars config data to graph input" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    data: {
    #|      cat: hat
    #|      later: [1, 5, 2]
    #|    }
    #|  }
    #|}
    #|a -> b
  let result = compile_graph("diagram", source).unwrap()
  let graph = result.graph_input()
  assert_eq(graph.data["cat"], @graph.GraphDataValue::Text("hat"))
  assert_eq(
    graph.data["later"],
    @graph.GraphDataValue::StringArray(["1", "5", "2"]),
  )
}

///|
test "compile_graph preserves sequence edge reference ordering without imports" {
  let source =
    #|shape: sequence_diagram
    #|alice -> bob: What does it mean
    #|to be well-adjusted?
    #|bob -> alice: The ability to play bridge or
    #|golf as if they were games.
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let direct_graph = @exporter.compile("diagram", @ir.compile(ast))
  let compiled_graph = compile_graph("diagram", source).unwrap().graph_input()

  let direct_object_ids : Array[String] = []
  for obj in direct_graph.objects {
    direct_object_ids.push(obj.lookup_id())
  }
  let compiled_object_ids : Array[String] = []
  for obj in compiled_graph.objects {
    compiled_object_ids.push(obj.lookup_id())
  }
  assert_eq(compiled_object_ids, direct_object_ids)

  let direct_edge_ids : Array[String] = []
  for edge in direct_graph.edges {
    direct_edge_ids.push("\{edge.lookup_src_id()}->\{edge.lookup_dst_id()}")
  }
  let compiled_edge_ids : Array[String] = []
  for edge in compiled_graph.edges {
    compiled_edge_ids.push("\{edge.lookup_src_id()}->\{edge.lookup_dst_id()}")
  }
  assert_eq(compiled_edge_ids, direct_edge_ids)
}
