///|
fn subset_ok(bytes : Bytes) -> Bool {
  match @font_subset.utf8_cut_font(bytes, "abcABC123") {
    Some(subset) => subset.length() > 0
    None => false
  }
}

///|
fn subset_woff_magic_ok(bytes : Bytes) -> Bool {
  match @font_subset.utf8_cut_font(bytes, "abcABC123") {
    Some(subset) =>
      match @font_subset.sfnt_to_woff(subset) {
        Some(woff) =>
          if woff.length() < 4 {
            false
          } else {
            let b = woff.to_array()
            b[0] == b'w' && b[1] == b'O' && b[2] == b'F' && b[3] == b'F'
          }
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
  inspect(
    subset_woff_magic_ok(source_sans_pro_regular_ttf_bytes),
    content="true",
  )
}

///|
test "font subset->woff source code regular smoke" {
  inspect(
    subset_woff_magic_ok(source_code_pro_regular_ttf_bytes),
    content="true",
  )
}
