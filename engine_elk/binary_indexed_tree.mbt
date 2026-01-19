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
/// A simple Binary Indexed Tree (Fenwick tree) implementation.
///
/// Ported to support elk-reference layered crossing-counting tests.

///|
pub struct BinaryIndexedTree {
  n : Int
  mut size_ : Int
  tree : Array[Int]
  counts : Array[Int]
} derive(Show)

///|
pub fn BinaryIndexedTree::new(n : Int) -> BinaryIndexedTree {
  if n <= 0 {
    { n: 0, size_: 0, tree: [0], counts: [] }
  } else {
    { n, size_: 0, tree: Array::make(n + 1, 0), counts: Array::make(n, 0) }
  }
}

///|
fn BinaryIndexedTree::fenwick_add(
  self : BinaryIndexedTree,
  idx0 : Int,
  delta : Int,
) -> Unit {
  // idx0 is 0-based value; fenwick uses 1-based index.
  if self.n <= 0 {
    return
  }
  let mut i = idx0 + 1
  while i <= self.n {
    self.tree[i] = self.tree[i] + delta
    i = i + (i & -i)
  }
}

///|
fn BinaryIndexedTree::fenwick_sum(
  self : BinaryIndexedTree,
  idx0_exclusive : Int,
) -> Int {
  // Sum of values in [0, idx0_exclusive).
  if self.n <= 0 {
    return 0
  }
  let mut res = 0
  let mut i = idx0_exclusive
  while i > 0 {
    res = res + self.tree[i]
    i = i - (i & -i)
  }
  res
}

///|
/// Add one element with value `v`.
///
/// `v` must satisfy `0 <= v < n`.
pub fn BinaryIndexedTree::add(self : BinaryIndexedTree, v : Int) -> Unit {
  if v < 0 || v >= self.n {
    return
  }
  self.size_ = self.size_ + 1
  self.counts[v] = self.counts[v] + 1
  self.fenwick_add(v, 1)
}

///|
/// Return number of elements whose value is strictly less than `v`.
///
/// `v` may be `0..=n`.
pub fn BinaryIndexedTree::rank(self : BinaryIndexedTree, v : Int) -> Int {
  let vv = if v < 0 { 0 } else if v > self.n { self.n } else { v }
  self.fenwick_sum(vv)
}

///|
/// Remove all elements equal to `v`.
pub fn BinaryIndexedTree::removeAll(self : BinaryIndexedTree, v : Int) -> Unit {
  if v < 0 || v >= self.n {
    return
  }
  let cnt = self.counts[v]
  if cnt <= 0 {
    return
  }
  self.counts[v] = 0
  self.size_ = self.size_ - cnt
  self.fenwick_add(v, -cnt)
}

///|
pub fn BinaryIndexedTree::size(self : BinaryIndexedTree) -> Int {
  self.size_
}
