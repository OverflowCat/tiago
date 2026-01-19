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
/// Tests ported from elk-reference `BinaryIndexedTreeTest`.

///|
test "elk-reference: BinaryIndexedTree rank" {
  let ft = BinaryIndexedTree::new(5)
  ft.add(1)
  ft.add(2)
  ft.add(1)
  assert_eq(ft.rank(1), 0)
  assert_eq(ft.rank(2), 2)
}

///|
test "elk-reference: BinaryIndexedTree size" {
  let ft = BinaryIndexedTree::new(5)
  ft.add(2)
  ft.add(1)
  ft.add(1)
  assert_eq(ft.size(), 3)
}

///|
test "elk-reference: BinaryIndexedTree removeAll" {
  let ft = BinaryIndexedTree::new(5)
  ft.add(0)
  ft.add(2)
  ft.add(1)
  ft.add(1)
  ft.removeAll(1)
  assert_eq(ft.size(), 2)
  assert_eq(ft.rank(2), 1)
  ft.removeAll(1)
  assert_eq(ft.size(), 2)
  assert_eq(ft.rank(2), 1)
}
