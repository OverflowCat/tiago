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
/// Whitebox tests for coordinate assignment (can access private functions)

///|
test "median4" {
  // Test the median4 helper function
  let m1 = median4(1.0, 2.0, 3.0, 4.0)
  // Average of middle two (2.0 + 3.0) / 2 = 2.5
  inspect(m1, content="2.5")
  let m2 = median4(10.0, 20.0, 30.0, 40.0)
  inspect(m2, content="25")
  // Test with unordered input
  let m3 = median4(4.0, 1.0, 3.0, 2.0)
  inspect(m3, content="2.5")
}

///|
test "range helpers" {
  let r1 = range(0, 3)
  inspect(r1.length(), content="3")
  inspect(r1[0], content="0")
  inspect(r1[2], content="2")
  let r2 = range_rev(0, 3)
  inspect(r2.length(), content="3")
  inspect(r2[0], content="2")
  inspect(r2[2], content="0")
}

///|
test "sort_by_pos" {
  let pos : Map[String, Int] = {}
  pos["a"] = 2
  pos["b"] = 0
  pos["c"] = 1
  let nodes = ["a", "b", "c"]
  let sorted = sort_by_pos(nodes, pos)
  inspect(sorted[0], content="b")
  inspect(sorted[1], content="c")
  inspect(sorted[2], content="a")
}

///|
test "find_layer" {
  let layers : Array[Array[String]] = [["a", "b"], ["c", "d"], ["e"]]
  inspect(find_layer("a", layers), content="0")
  inspect(find_layer("c", layers), content="1")
  inspect(find_layer("e", layers), content="2")
  inspect(find_layer("x", layers), content="-1")
}
