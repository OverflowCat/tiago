///|
fn subset_ok(bytes : Bytes) -> Bool {
  match @font_subset.utf8_cut_font(bytes, "abcABC123") {
    Some(subset) => subset.length() > 0
    None => false
  }
}

///|
fn read_u16_be(data : Array[Byte], at : Int) -> Int {
  (data[at].to_int() << 8) + data[at + 1].to_int()
}

///|
fn read_u32_be(data : Array[Byte], at : Int) -> Int {
  (data[at].to_int() << 24) +
  (data[at + 1].to_int() << 16) +
  (data[at + 2].to_int() << 8) +
  data[at + 3].to_int()
}

///|
fn align4(n : Int) -> Int {
  (n + 3) / 4 * 4
}

///|
fn tag_string(data : Array[Byte], at : Int) -> String {
  let sb = StringBuilder::new()
  for i in 0..<4 {
    sb.write_char(data[at + i].to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
fn woff_structure_ok(woff : Bytes) -> Bool {
  if woff.length() < 44 {
    return false
  }
  let b = woff.to_array()
  if !(b[0] == b'w' && b[1] == b'O' && b[2] == b'F' && b[3] == b'F') {
    return false
  }
  if read_u32_be(b, 8) != b.length() {
    return false
  }
  let num_tables = read_u16_be(b, 12)
  if num_tables <= 0 {
    return false
  }
  let dir_end = 44 + num_tables * 20
  if dir_end > b.length() {
    return false
  }

  let mut prev_tag = ""
  for i in 0..<num_tables {
    let rec = 44 + i * 20
    let tag = tag_string(b, rec)
    let offset = read_u32_be(b, rec + 4)
    let comp_len = read_u32_be(b, rec + 8)
    let orig_len = read_u32_be(b, rec + 12)
    if tag < prev_tag {
      return false
    }
    prev_tag = tag
    if comp_len <= 0 || orig_len <= 0 || comp_len > orig_len {
      return false
    }
    if offset < dir_end || offset % 4 != 0 {
      return false
    }
    if offset > b.length() || align4(comp_len) > b.length() - offset {
      return false
    }
  }
  true
}

///|
fn subset_woff_ok(bytes : Bytes) -> Bool {
  match @font_subset.utf8_cut_font(bytes, "abcABC123") {
    Some(subset) =>
      match @font_subset.sfnt_to_woff(subset) {
        Some(woff) => woff_structure_ok(woff)
        None => false
      }
    None => false
  }
}

///|
test "font subset source sans regular smoke" {
  inspect(subset_ok(source_sans_pro_regular_ttf_bytes), content="true")
}

///|
test "font subset source sans bold smoke" {
  inspect(subset_ok(source_sans_pro_bold_ttf_bytes), content="true")
}

///|
test "font subset source sans semibold smoke" {
  inspect(subset_ok(source_sans_pro_semibold_ttf_bytes), content="true")
}

///|
test "font subset source sans italic smoke" {
  inspect(subset_ok(source_sans_pro_italic_ttf_bytes), content="true")
}

///|
test "font subset source code regular smoke" {
  inspect(subset_ok(source_code_pro_regular_ttf_bytes), content="true")
}

///|
test "font subset source code bold smoke" {
  inspect(subset_ok(source_code_pro_bold_ttf_bytes), content="true")
}

///|
test "font subset source code italic smoke" {
  inspect(subset_ok(source_code_pro_italic_ttf_bytes), content="true")
}

///|
test "font subset->woff source sans regular smoke" {
  inspect(subset_woff_ok(source_sans_pro_regular_ttf_bytes), content="true")
}

///|
test "font subset->woff source code regular smoke" {
  inspect(subset_woff_ok(source_code_pro_regular_ttf_bytes), content="true")
}
