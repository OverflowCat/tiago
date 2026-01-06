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
/// Blackbox tests for the proptest package

// ============================================================================
// Implication Tests
// ============================================================================

test "implies - true condition runs property" {
  // When condition is true, property is checked
  let result = @proptest.check_property(@proptest.implies(true, true))
  inspect(result, content="true")
}

///|
test "implies - false condition discards test" {
  // When condition is false, property is discarded (not checked)
  // We test by using implies with a condition that's sometimes true
  // When true, property should hold; when false, test is discarded
  let result = @proptest.check_property(
    @qc.forall(@qc.int_range(0, 10), fn(n : Int) {
      // Only check property when n > 5 (about half the time)
      // When n <= 5, the test is discarded
      @proptest.implies(n > 5, n > 5) // trivially true when checked
    }),
  )
  inspect(result, content="true")
}

///|
test "imply - tuple style works" {
  let result = @proptest.check_property((true, true) |> @proptest.imply)
  inspect(result, content="true")
}

// ============================================================================
// Property Combinator Tests
// ============================================================================

///|
test "prop_and - both true" {
  inspect(@proptest.prop_and(true, true), content="true")
}

///|
test "prop_and - one false" {
  inspect(@proptest.prop_and(true, false), content="false")
  inspect(@proptest.prop_and(false, true), content="false")
}

///|
test "prop_and - both false" {
  inspect(@proptest.prop_and(false, false), content="false")
}

///|
test "prop_or - both true" {
  inspect(@proptest.prop_or(true, true), content="true")
}

///|
test "prop_or - one true" {
  inspect(@proptest.prop_or(true, false), content="true")
  inspect(@proptest.prop_or(false, true), content="true")
}

///|
test "prop_or - both false" {
  inspect(@proptest.prop_or(false, false), content="false")
}

///|
test "trivial always passes" {
  inspect(@proptest.trivial(), content="true")
}

///|
test "absurd always fails" {
  inspect(@proptest.absurd(), content="false")
}

// ============================================================================
// Numeric Generator Tests
// ============================================================================

///|
test "positive_int generates positive integers" {
  let gen = @proptest.positive_int()
  let samples = gen.samples(size=10)
  for n in samples {
    assert_true(n >= 1)
  }
}

///|
test "int_near generates integers within range" {
  let gen = @proptest.int_near(100, 10) // 100 +/- 10%
  let samples = gen.samples(size=10)
  for n in samples {
    assert_true(n >= 90 && n <= 110)
  }
}

///|
test "unit_double generates values in [0, 1)" {
  let gen = @proptest.unit_double()
  let samples = gen.samples(size=20)
  for d in samples {
    assert_true(d >= 0.0 && d < 1.0)
  }
}

///|
test "double_range generates values in range" {
  let gen = @proptest.double_range(10.0, 20.0)
  let samples = gen.samples(size=20)
  for d in samples {
    assert_true(d >= 10.0 && d < 20.0)
  }
}

// ============================================================================
// String Generator Tests
// ============================================================================

///|
test "ascii_string generates printable characters" {
  let gen = @proptest.ascii_string()
  let samples = gen.samples(size=10)
  for s in samples {
    for c in s {
      let code = c.to_int()
      assert_true(code >= 32 && code <= 126)
    }
  }
}

///|
test "alpha_string generates only letters" {
  let gen = @proptest.alpha_string()
  let samples = gen.samples(size=10)
  for s in samples {
    for c in s {
      let is_lower = c >= 'a' && c <= 'z'
      let is_upper = c >= 'A' && c <= 'Z'
      assert_true(is_lower || is_upper)
    }
  }
}

///|
test "alphanumeric_string generates letters and digits" {
  let gen = @proptest.alphanumeric_string()
  let samples = gen.samples(size=10)
  for s in samples {
    for c in s {
      let is_lower = c >= 'a' && c <= 'z'
      let is_upper = c >= 'A' && c <= 'Z'
      let is_digit = c >= '0' && c <= '9'
      assert_true(is_lower || is_upper || is_digit)
    }
  }
}

///|
test "string_of_length generates exact length" {
  let gen = @proptest.string_of_length(5)
  let samples = gen.samples(size=10)
  for s in samples {
    inspect(s.length(), content="5")
  }
}

// ============================================================================
// Collection Generator Tests
// ============================================================================

///|
test "non_empty_array generates non-empty arrays" {
  let gen : @qc.Gen[Array[Int]] = @proptest.non_empty_array()
  let samples = gen.samples(size=10)
  for arr in samples {
    assert_true(arr.length() > 0)
  }
}

///|
test "array_with_bounds respects size bounds" {
  let gen : @qc.Gen[Array[Int]] = @proptest.array_with_bounds(3, 7)
  let samples = gen.samples(size=20)
  for arr in samples {
    assert_true(arr.length() >= 3 && arr.length() <= 7)
  }
}

///|
test "unique_array has no duplicates" {
  let gen : @qc.Gen[Array[Int]] = @proptest.unique_array()
  let samples = gen.samples(size=5)
  for arr in samples {
    assert_true(@proptest.all_unique(arr))
  }
}

///|
test "sorted_array is sorted" {
  let gen : @qc.Gen[Array[Int]] = @proptest.sorted_array()
  let samples = gen.samples(size=10)
  for arr in samples {
    assert_true(@proptest.is_sorted(arr))
  }
}

///|
test "permutation preserves elements" {
  let original = [1, 2, 3, 4, 5]
  let gen = @proptest.permutation(original)
  let samples = gen.samples(size=10)
  for perm in samples {
    // Same length
    inspect(perm.length(), content="5")
    // Contains all elements
    for elem in original {
      assert_true(perm.contains(elem))
    }
  }
}

// ============================================================================
// Comparison Utility Tests
// ============================================================================

///|
test "within_delta - values within tolerance" {
  assert_true(@proptest.within_delta(1.0, 1.0001, 0.001))
  assert_true(@proptest.within_delta(1.0, 0.9999, 0.001))
}

///|
test "within_delta - values outside tolerance" {
  assert_false(@proptest.within_delta(1.0, 1.01, 0.001))
  assert_false(@proptest.within_delta(1.0, 0.99, 0.001))
}

///|
test "approx_eq - nearly equal values" {
  assert_true(@proptest.approx_eq(1.0, 1.0))
  assert_true(@proptest.approx_eq(1.0, 1.0 + 1.0e-10))
}

///|
test "approx_eq - different values" {
  assert_false(@proptest.approx_eq(1.0, 1.1))
}

///|
test "is_sorted - sorted array" {
  assert_true(@proptest.is_sorted([1, 2, 3, 4, 5]))
  assert_true(@proptest.is_sorted([1]))
  assert_true(@proptest.is_sorted(([] : Array[Int])))
}

///|
test "is_sorted - unsorted array" {
  assert_false(@proptest.is_sorted([1, 3, 2]))
  assert_false(@proptest.is_sorted([5, 4, 3, 2, 1]))
}

///|
test "is_sorted_desc - descending array" {
  assert_true(@proptest.is_sorted_desc([5, 4, 3, 2, 1]))
  assert_true(@proptest.is_sorted_desc([1]))
  assert_true(@proptest.is_sorted_desc(([] : Array[Int])))
}

///|
test "is_sorted_desc - not descending" {
  assert_false(@proptest.is_sorted_desc([1, 2, 3]))
}

///|
test "all_unique - unique elements" {
  assert_true(@proptest.all_unique([1, 2, 3, 4, 5]))
  assert_true(@proptest.all_unique([1]))
  assert_true(@proptest.all_unique(([] : Array[Int])))
}

///|
test "all_unique - duplicates present" {
  assert_false(@proptest.all_unique([1, 2, 2, 3]))
  assert_false(@proptest.all_unique([1, 1]))
}

// ============================================================================
// Shrink Extension Tests
// ============================================================================

///|
test "shrink_towards - shrink down" {
  let shrinks = @proptest.shrink_towards(10, 0).collect()
  // Should shrink 10 -> 5 -> 2 -> 1 -> 0
  assert_true(shrinks.length() > 0)
  // All values should be between target and current
  for v in shrinks {
    assert_true(v >= 0 && v <= 10)
  }
}

///|
test "shrink_towards - already at target" {
  let shrinks = @proptest.shrink_towards(5, 5).collect()
  inspect(shrinks.length(), content="0")
}

///|
test "shrink_towards - shrink up" {
  let shrinks = @proptest.shrink_towards(0, 10).collect()
  assert_true(shrinks.length() > 0)
  for v in shrinks {
    assert_true(v >= 0 && v <= 10)
  }
}

// ============================================================================
// Test Runner Extension Tests
// ============================================================================

///|
test "check_property - passing property" {
  let result = @proptest.check_property(true)
  inspect(result, content="true")
}

///|
test "check_property - failing property" {
  let result = @proptest.check_property(false)
  inspect(result, content="false")
}

///|
test "check_property_n - custom test count" {
  let result = @proptest.check_property_n(true, 10)
  inspect(result, content="true")
}

// ============================================================================
// Integration Tests with QuickCheck
// ============================================================================

///|
test "property: reverse twice is identity" {
  @qc.quick_check_fn(fn(arr : Array[Int]) {
    let reversed_twice = arr.copy()
    reversed_twice.rev_in_place()
    reversed_twice.rev_in_place()
    reversed_twice == arr
  })
}

///|
test "property: sorted array is sorted" {
  @qc.quick_check_fn(fn(arr : Array[Int]) {
    let sorted = arr.copy()
    sorted.sort()
    @proptest.is_sorted(sorted)
  })
}

///|
test "property: permutation has same length" {
  @qc.quick_check_fn(fn(arr : Array[Int]) {
    let perm = @proptest.permutation(arr).sample(size=10)
    perm.length() == arr.length()
  })
}

///|
test "property: within_delta is symmetric" {
  @qc.quick_check_fn(fn(pair : (Double, Double)) {
    let (a, b) = pair
    let delta = 0.1
    @proptest.within_delta(a, b, delta) == @proptest.within_delta(b, a, delta)
  })
}

///|
test "property: all_unique on unique_array" {
  @qc.quick_check(
    @qc.forall(@proptest.unique_array(), fn(arr : Array[Int]) {
      @proptest.all_unique(arr)
    }),
  )
}

///|
test "property: is_sorted on sorted_array" {
  @qc.quick_check(
    @qc.forall(@proptest.sorted_array(), fn(arr : Array[Int]) {
      @proptest.is_sorted(arr)
    }),
  )
}
