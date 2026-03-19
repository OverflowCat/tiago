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
