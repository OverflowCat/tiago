///|
test "fixed_array_to_string decodes utf8" {
  let encoded = @utf8.encode("你好 -> y"[:])
  let arr = FixedArray::make(encoded.length(), b'\x00')
  for i in 0..<encoded.length() {
    arr[i] = encoded[i]
  }
  assert_eq(fixed_array_to_string(arr), "你好 -> y")
}

///|
test "slice_fixed_array_to_string extracts slices" {
  let src = @utf8.encode("hello"[:])
  let eng = @utf8.encode("elk"[:])
  let arr = FixedArray::make(src.length() + eng.length(), b'\x00')
  for i in 0..<src.length() {
    arr[i] = src[i]
  }
  for i in 0..<eng.length() {
    arr[src.length() + i] = eng[i]
  }
  assert_eq(slice_fixed_array_to_string(arr, 0, src.length()), "hello")
  assert_eq(slice_fixed_array_to_string(arr, src.length(), eng.length()), "elk")
}
