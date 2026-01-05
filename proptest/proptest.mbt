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
