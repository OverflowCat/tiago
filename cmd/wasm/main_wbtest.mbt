///|
test "bytes_to_string decodes utf8 input" {
  let bytes = @utf8.encode("你好 -> y"[:]).to_array()
  assert_eq(bytes_to_string(bytes), "你好 -> y")
}

///|
test "string_to_bytes encodes utf8 output" {
  let out : Array[Byte] = []
  string_to_bytes("你好 -> y", out)
  assert_eq(@utf8.decode_lossy(Bytes::from_array(out[:]).view()), "你好 -> y")
}
