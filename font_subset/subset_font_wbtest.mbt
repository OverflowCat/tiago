///|
test "utf8_cut_font returns none on empty input" {
  let empty = Bytes::from_array([])
  assert_eq(utf8_cut_font(empty, "abc"), None)
}

///|
test "utf8_cut_font returns none on malformed bytes" {
  let malformed = Bytes::from_array([
    b'\xDE', b'\xAD', b'\xBE', b'\xEF', b'\x00', b'\x01', b'\x02',
  ])
  assert_eq(utf8_cut_font(malformed, "abc"), None)
}

///|
test "utf8_cut_font does not panic on minimal sfnt shell" {
  let minimal_sfnt = Bytes::from_array([
    b'\x00', b'\x01', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00',
  ])
  assert_eq(utf8_cut_font(minimal_sfnt, "A"), None)
}

///|
test "sfnt_to_woff returns none on malformed bytes" {
  let malformed = Bytes::from_array([
    b'\xDE', b'\xAD', b'\xBE', b'\xEF', b'\x00', b'\x01', b'\x02',
  ])
  assert_eq(sfnt_to_woff(malformed), None)
}
