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
/// PropTest - Extensions for MoonBit QuickCheck
/// Provides additional generators, combinators, and testing utilities

// ============================================================================
// Implication (Conditional Properties)
// ============================================================================

///|
/// Implication for conditional properties.
/// If the condition is false, the test is discarded (not counted as pass/fail).
/// Usage: `implies(precondition, property)`
pub fn[P : @qc.Testable] implies(condition : Bool, prop : P) -> @qc.Property {
  @qc.filter(prop, condition)
}

///|
/// Infix-style implication using a tuple.
/// Usage: `(precondition, property) |> imply`
pub fn[P : @qc.Testable] imply(pair : (Bool, P)) -> @qc.Property {
  let (cond, prop) = pair
  implies(cond, prop)
}

// ============================================================================
// Property Combinators
// ============================================================================

///|
/// Combine two properties with logical AND.
/// Both properties must hold for the test to pass.
pub fn prop_and(p1 : Bool, p2 : Bool) -> Bool {
  p1 && p2
}

///|
/// Combine two properties with logical OR.
/// At least one property must hold for the test to pass.
pub fn prop_or(p1 : Bool, p2 : Bool) -> Bool {
  p1 || p2
}

///|
/// Property that always passes (useful as identity for combining)
pub fn trivial() -> Bool {
  true
}

///|
/// Property that always fails (useful for testing test infrastructure)
pub fn absurd() -> Bool {
  false
}

// ============================================================================
// Numeric Generators
// ============================================================================

///|
/// Generate a positive integer (>= 1)
pub fn positive_int() -> @qc.Gen[Int] {
  @qc.int_range(1, 2147483647)
}

///|
/// Generate an integer within a percentage of a base value
pub fn int_near(base : Int, percentage : Int) -> @qc.Gen[Int] {
  let delta = base.abs() * percentage / 100
  let low = base - delta
  let high = base + delta
  @qc.int_range(low, high)
}

///|
/// Generate a double in the range [0.0, 1.0)
pub fn unit_double() -> @qc.Gen[Double] {
  @qc.Gen::new(fn(size, state) {
    let n = @qc.int_range(0, size * 1000).run(size, state)
    n.to_double() / (size * 1000).to_double()
  })
}

///|
/// Generate a double in the given range [low, high)
pub fn double_range(low : Double, high : Double) -> @qc.Gen[Double] {
  @qc.Gen::new(fn(size, state) {
    let unit = unit_double().run(size, state)
    low + unit * (high - low)
  })
}

// ============================================================================
// String Generators
// ============================================================================

///|
/// Generate an ASCII printable string (chars 32-126)
pub fn ascii_string() -> @qc.Gen[String] {
  @qc.sized(fn(size) {
    let char_gen = @qc.char_range(' ', '~')
    char_gen
    .array_with_size(size)
    .fmap(fn(chars) {
      let buf = StringBuilder::new()
      for c in chars {
        buf.write_char(c)
      }
      buf.to_string()
    })
  })
}

///|
/// Generate an alphabetic string (a-z, A-Z)
pub fn alpha_string() -> @qc.Gen[String] {
  @qc.sized(fn(size) {
    let char_gen = @qc.one_of([
      @qc.char_range('a', 'z'),
      @qc.char_range('A', 'Z'),
    ])
    char_gen
    .array_with_size(size)
    .fmap(fn(chars) {
      let buf = StringBuilder::new()
      for c in chars {
        buf.write_char(c)
      }
      buf.to_string()
    })
  })
}

///|
/// Generate an alphanumeric string (a-z, A-Z, 0-9)
pub fn alphanumeric_string() -> @qc.Gen[String] {
  @qc.sized(fn(size) {
    let char_gen = @qc.one_of([
      @qc.char_range('a', 'z'),
      @qc.char_range('A', 'Z'),
      @qc.char_range('0', '9'),
    ])
    char_gen
    .array_with_size(size)
    .fmap(fn(chars) {
      let buf = StringBuilder::new()
      for c in chars {
        buf.write_char(c)
      }
      buf.to_string()
    })
  })
}

///|
/// Generate a string with exactly the given length
pub fn string_of_length(len : Int) -> @qc.Gen[String] {
  @qc.Gen::new(fn(size, state) {
    let char_gen = @qc.char_range(' ', '~')
    let buf = StringBuilder::new()
    for _ in 0..<len {
      let c = char_gen.run(size, state)
      buf.write_char(c)
    }
    buf.to_string()
  })
}

// ============================================================================
// Collection Generators
// ============================================================================

///|
/// Generate a non-empty array
pub fn[T : @quickcheck.Arbitrary] non_empty_array() -> @qc.Gen[Array[T]] {
  @qc.sized(fn(size) {
    let actual_size = if size < 1 { 1 } else { size }
    let elem_gen : @qc.Gen[T] = @qc.Gen::spawn()
    elem_gen
    .array_with_size(actual_size)
    .such_that(fn(arr) { arr.length() > 0 })
  })
}

///|
/// Generate an array with size in [min_size, max_size]
pub fn[T : @quickcheck.Arbitrary] array_with_bounds(
  min_size : Int,
  max_size : Int,
) -> @qc.Gen[Array[T]] {
  @qc.Gen::new(fn(size, state) {
    let actual_size = @qc.int_range(min_size, max_size).run(size, state)
    let elem_gen : @qc.Gen[T] = @qc.Gen::spawn()
    let result : Array[T] = []
    for _ in 0..<actual_size {
      result.push(elem_gen.run(size, state))
    }
    result
  })
}

///|
/// Generate an array with unique elements (no duplicates)
pub fn[T : @quickcheck.Arbitrary + Eq] unique_array() -> @qc.Gen[Array[T]] {
  @qc.sized(fn(size) {
    let elem_gen : @qc.Gen[T] = @qc.Gen::spawn()
    elem_gen
    .array_with_size(size * 2)
    .fmap(fn(arr) {
      let result : Array[T] = []
      for elem in arr {
        if !result.contains(elem) {
          result.push(elem)
        }
      }
      result
    })
  })
}

///|
/// Generate a sorted array
pub fn[T : @quickcheck.Arbitrary + Compare] sorted_array() -> @qc.Gen[Array[T]] {
  @qc.sized(fn(size) {
    let elem_gen : @qc.Gen[T] = @qc.Gen::spawn()
    elem_gen
    .array_with_size(size)
    .fmap(fn(arr) {
      arr.sort()
      arr
    })
  })
}

///|
/// Generate a permutation of the given array
pub fn[T] permutation(arr : Array[T]) -> @qc.Gen[Array[T]] {
  @qc.Gen::new(fn(size, state) {
    let result = arr.copy()
    // Fisher-Yates shuffle
    for i = result.length() - 1; i > 0; i = i - 1 {
      let j = @qc.int_range(0, i).run(size, state)
      let tmp = result[i]
      result[i] = result[j]
      result[j] = tmp
    }
    result
  })
}

// ============================================================================
// Comparison Utilities
// ============================================================================

///|
/// Check if two doubles are equal within a delta tolerance
pub fn within_delta(a : Double, b : Double, delta : Double) -> Bool {
  (a - b).abs() < delta
}

///|
/// Check if two doubles are approximately equal (1e-9 tolerance)
pub fn approx_eq(a : Double, b : Double) -> Bool {
  within_delta(a, b, 1.0e-9)
}

///|
/// Check if an array is sorted in ascending order
pub fn[T : Compare] is_sorted(arr : Array[T]) -> Bool {
  for i = 0; i < arr.length() - 1; i = i + 1 {
    if arr[i] > arr[i + 1] {
      return false
    }
  }
  true
}

///|
/// Check if an array is sorted in descending order
pub fn[T : Compare] is_sorted_desc(arr : Array[T]) -> Bool {
  for i = 0; i < arr.length() - 1; i = i + 1 {
    if arr[i] < arr[i + 1] {
      return false
    }
  }
  true
}

///|
/// Check if an array contains no duplicates
pub fn[T : Eq] all_unique(arr : Array[T]) -> Bool {
  for i = 0; i < arr.length(); i = i + 1 {
    for j = i + 1; j < arr.length(); j = j + 1 {
      if arr[i] == arr[j] {
        return false
      }
    }
  }
  true
}

// ============================================================================
// Shrink Extensions
// ============================================================================

///|
/// Shrink towards a target value
pub fn shrink_towards(current : Int, target : Int) -> Iter[Int] {
  if current == target {
    Iter::empty()
  } else if current > target {
    let values : Array[Int] = []
    let mut c = current
    while c > target {
      c = target + (c - target) / 2
      values.push(c)
    }
    values.iter()
  } else {
    let values : Array[Int] = []
    let mut c = current
    while c < target {
      c = target - (target - c) / 2
      values.push(c)
    }
    values.iter()
  }
}

// ============================================================================
// Constrained Generators (for invariant relationships)
// ============================================================================

///|
/// Generate values that satisfy a constraint, with retry limit.
/// Unlike `such_that`, this keeps trying with new random seeds up to max_attempts.
pub fn[T] constrained(
  gen : @qc.Gen[T],
  predicate : (T) -> Bool,
  max_attempts? : Int = 100,
) -> @qc.Gen[T] {
  @qc.Gen::new(fn(size, state) {
    for i = 0; i < max_attempts; i = i + 1 {
      let value = gen.run(size + i, state) // Vary size to get different values
      if predicate(value) {
        return value
      }
    }
    // Fallback: return last attempt (test will fail if constraint violated)
    gen.run(size, state)
  })
}

///|
/// Generate a value dependent on a previously generated value.
/// Useful for generating values that reference other generated values.
pub fn[A, B] dependent(
  first : @qc.Gen[A],
  second : (A) -> @qc.Gen[B],
) -> @qc.Gen[(A, B)] {
  @qc.Gen::new(fn(size, state) {
    let a = first.run(size, state)
    let b = second(a).run(size, state)
    (a, b)
  })
}

///|
/// Generate a value, then generate an array of dependent values.
/// Useful for generating edges that reference valid node IDs.
pub fn[A, B] one_to_many(
  one : @qc.Gen[A],
  make_many : (A) -> @qc.Gen[B],
  count : Int,
) -> @qc.Gen[(A, Array[B])] {
  @qc.Gen::new(fn(size, state) {
    let a = one.run(size, state)
    let gen_b = make_many(a)
    let bs : Array[B] = []
    for _ in 0..<count {
      bs.push(gen_b.run(size, state))
    }
    (a, bs)
  })
}

///|
/// Generate an array of unique IDs, then generate edges that only reference those IDs.
/// This ensures edge invariants (src_id and dst_id reference valid objects).
pub fn[ID : Eq, Node, Edge] gen_with_valid_references(
  id_count : Int,
  gen_id : @qc.Gen[ID],
  make_node : (ID) -> Node,
  edge_count : Int,
  make_edge : (ID, ID) -> Edge,
) -> @qc.Gen[(Array[Node], Array[Edge])] {
  @qc.Gen::new(fn(size, state) {
    // Generate unique IDs first
    let ids : Array[ID] = []
    let max_attempts = id_count * 2
    for i = 0; i < max_attempts; i = i + 1 {
      // Generate extra to ensure uniqueness
      let id = gen_id.run(size, state)
      if not(ids.contains(id)) && ids.length() < id_count {
        ids.push(id)
      }
    }
    // Create nodes from IDs
    let nodes = ids.map(make_node)
    // Generate edges that only reference valid IDs
    let edges : Array[Edge] = []
    if ids.length() >= 2 {
      for i = 0; i < edge_count; i = i + 1 {
        let src_idx = @qc.int_range(0, ids.length()).run(size, state)
        let dst_idx = @qc.int_range(0, ids.length()).run(size, state)
        if src_idx != dst_idx {
          edges.push(make_edge(ids[src_idx], ids[dst_idx]))
        }
      }
    }
    (nodes, edges)
  })
}

///|
/// Pick a random element from an array.
/// Useful for generating references to existing elements.
pub fn[T] element_of(arr : Array[T]) -> @qc.Gen[T] {
  @qc.Gen::new(fn(size, state) {
    if arr.is_empty() {
      abort("element_of: empty array")
    }
    let idx = @qc.int_range(0, arr.length()).run(size, state)
    arr[idx]
  })
}

///|
/// Pick a random subset of elements from an array.
pub fn[T] subset_of(
  arr : Array[T],
  min_size : Int,
  max_size : Int,
) -> @qc.Gen[Array[T]] {
  @qc.Gen::new(fn(size, state) {
    let count = @qc.int_range(min_size, max_size + 1).run(size, state)
    let count = if count > arr.length() { arr.length() } else { count }
    let indices : Array[Int] = []
    while indices.length() < count {
      let idx = @qc.int_range(0, arr.length()).run(size, state)
      if not(indices.contains(idx)) {
        indices.push(idx)
      }
    }
    indices.map(fn(i) { arr[i] })
  })
}

///|
/// Generate a pair where second element references valid first element.
/// Ensures referential integrity in generated data.
pub fn[A, B] with_valid_ref(
  gen_target : @qc.Gen[Array[A]],
  get_id : (A) -> String,
  make_ref : (String) -> B,
) -> @qc.Gen[(Array[A], Array[B])] {
  @qc.Gen::new(fn(size, state) {
    let targets = gen_target.run(size, state)
    if targets.is_empty() {
      return (targets, [])
    }
    let ids = targets.map(get_id)
    let ref_count = @qc.int_range(0, targets.length() * 2).run(size, state)
    let refs : Array[B] = []
    for _ in 0..<ref_count {
      let id = element_of(ids).run(size, state)
      refs.push(make_ref(id))
    }
    (targets, refs)
  })
}

// ============================================================================
// Test Runner Extensions
// ============================================================================

///|
/// Run a property test and return whether it passed (for use in assertions)
pub fn[P : @qc.Testable] check_property(prop : P) -> Bool {
  try {
    @qc.quick_check(prop, max_success=100)
    true
  } catch {
    _ => false
  }
}

///|
/// Run a property test with a specific number of test cases
pub fn[P : @qc.Testable] check_property_n(prop : P, n : Int) -> Bool {
  try {
    @qc.quick_check(prop, max_success=n)
    true
  } catch {
    _ => false
  }
}

// ============================================================================
// Memory-Efficient Property Testing (No Shrinking)
// ============================================================================

///|
/// Error type for property test failures
suberror PropTestFailure {
  PropFailed(String)
  GaveUp(String)
} derive(Show)

///|
/// A simple, memory-efficient property test runner.
///
/// Unlike `quick_check`, this runner:
/// - Does NOT build shrink trees (saves memory)
/// - Generates and tests values one at a time
/// - Immediately discards passed test cases
/// - Only keeps the failing case (if any)
///
/// Use this for high-iteration tests where memory is a concern.
/// Trade-off: No automatic shrinking of failing cases.
pub fn[T : Show] check_forall(
  gen : @qc.Gen[T],
  prop : (T) -> Bool,
  iterations? : Int = 100,
) -> Unit raise PropTestFailure {
  let state = @quickcheck/splitmix.new(seed=42UL)
  for i in 0..<iterations {
    let size = i % 100 + 1 // Vary size like QuickCheck does
    let value = gen.run(size, state)
    if not(prop(value)) {
      let msg = "Failed after \{i + 1} tests.\nFailing case: \{value}"
      raise PropFailed(msg)
    }
  }
  println("+++ [\{iterations}/0/\{iterations}] Ok, passed!")
}

///|
/// Memory-efficient property test with two generators.
pub fn[A : Show, B : Show] check_forall2(
  gen_a : @qc.Gen[A],
  gen_b : @qc.Gen[B],
  prop : (A, B) -> Bool,
  iterations? : Int = 100,
) -> Unit raise PropTestFailure {
  let state = @quickcheck/splitmix.new(seed=42UL)
  for i in 0..<iterations {
    let size = i % 100 + 1
    let a = gen_a.run(size, state)
    let b = gen_b.run(size, state)
    if not(prop(a, b)) {
      let msg = "Failed after \{i + 1} tests.\nFailing case: (\{a}, \{b})"
      raise PropFailed(msg)
    }
  }
  println("+++ [\{iterations}/0/\{iterations}] Ok, passed!")
}

///|
/// Memory-efficient property test with three generators.
pub fn[A : Show, B : Show, C : Show] check_forall3(
  gen_a : @qc.Gen[A],
  gen_b : @qc.Gen[B],
  gen_c : @qc.Gen[C],
  prop : (A, B, C) -> Bool,
  iterations? : Int = 100,
) -> Unit raise PropTestFailure {
  let state = @quickcheck/splitmix.new(seed=42UL)
  for i in 0..<iterations {
    let size = i % 100 + 1
    let a = gen_a.run(size, state)
    let b = gen_b.run(size, state)
    let c = gen_c.run(size, state)
    if not(prop(a, b, c)) {
      let msg = "Failed after \{i + 1} tests.\nFailing case: (\{a}, \{b}, \{c})"
      raise PropFailed(msg)
    }
  }
  println("+++ [\{iterations}/0/\{iterations}] Ok, passed!")
}

///|
/// Memory-efficient property test that allows discarding test cases.
/// Return `None` to discard, `Some(true)` for pass, `Some(false)` for fail.
pub fn[T : Show] check_forall_filter(
  gen : @qc.Gen[T],
  prop : (T) -> Bool?,
  iterations? : Int = 100,
  max_discards? : Int = 1000,
) -> Unit raise PropTestFailure {
  let state = @quickcheck/splitmix.new(seed=42UL)
  let mut passed = 0
  let mut discarded = 0
  let mut attempts = 0
  while passed < iterations && discarded < max_discards {
    attempts += 1
    let size = attempts % 100 + 1
    let value = gen.run(size, state)
    match prop(value) {
      Some(true) => passed += 1
      Some(false) => {
        let msg = "Failed after \{passed + 1} tests (\{discarded} discarded).\nFailing case: \{value}"
        raise PropFailed(msg)
      }
      None => discarded += 1
    }
  }
  if passed < iterations {
    let msg = "Gave up after \{discarded} discards. Only passed \{passed}/\{iterations} tests."
    raise GaveUp(msg)
  }
  println("+++ [\{passed}/\{discarded}/\{iterations}] Ok, passed!")
}

// ============================================================================
// Lightweight RNG (QuickCheck-free)
// ============================================================================

///|
/// Simple Linear Congruential Generator for lightweight randomness.
/// Uses same parameters as glibc for good statistical properties.
/// This is QuickCheck-free and has minimal memory overhead.
pub(all) struct Rng {
  mut state : UInt64
}

///|
pub fn Rng::new(seed : UInt64) -> Rng {
  { state: seed }
}

///|
pub fn Rng::next(self : Rng) -> UInt64 {
  // LCG parameters (same as glibc)
  self.state = self.state * 1103515245UL + 12345UL
  self.state
}

///|
pub fn Rng::next_int(self : Rng, max : Int) -> Int {
  if max <= 0 {
    return 0
  }
  (self.next() % max.reinterpret_as_uint().to_uint64()).to_int()
}

///|
pub fn Rng::next_int_range(self : Rng, min : Int, max : Int) -> Int {
  if max <= min {
    return min
  }
  min + self.next_int(max - min)
}

///|
pub fn Rng::next_bool(self : Rng) -> Bool {
  self.next() % 2UL == 0UL
}

// ============================================================================
// QuickCheck-free Property Testing
// ============================================================================

///|
/// Ultra-lightweight property test runner that uses no QuickCheck at all.
/// Takes a generator function that receives an Rng and iteration index.
/// This avoids all QuickCheck memory overhead.
pub fn[T : Show] run_property_test(
  gen : (Rng, Int) -> T,
  prop : (T) -> Bool,
  iterations? : Int = 100,
  seed? : UInt64 = 42UL,
) -> Unit raise PropTestFailure {
  let rng = Rng::new(seed)
  for i in 0..<iterations {
    let value = gen(rng, i)
    if not(prop(value)) {
      let msg = "Failed after \{i + 1} tests.\nFailing case: \{value}"
      raise PropFailed(msg)
    }
  }
  println("+++ [\{iterations}/0/\{iterations}] Ok, passed!")
}
