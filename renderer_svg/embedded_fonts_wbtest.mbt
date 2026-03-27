///|
let font_data_url_prefix = "data:application/font-woff;base64,"

///|
fn is_embedded_font_woff(data_url : String) -> Bool {
  if !data_url.has_prefix(font_data_url_prefix) {
    return false
  }
  let payload = data_url[font_data_url_prefix.length():]
  let decoded = try @base64.decode(payload[:]) catch {
    _ => return false
  } noraise {
    bytes => bytes
  }
  decoded.length() >= 4 &&
  decoded[0] == b'w' &&
  decoded[1] == b'O' &&
  decoded[2] == b'F' &&
  decoded[3] == b'F'
}

///|
// test "embedded font payloads are WOFF" {
  // assert_true(is_embedded_font_woff(source_sans_pro_regular_data))
  // assert_true(is_embedded_font_woff(source_sans_pro_bold_data))
  // assert_true(is_embedded_font_woff(source_sans_pro_semibold_data))
  // assert_true(is_embedded_font_woff(source_sans_pro_italic_data))
  // assert_true(is_embedded_font_woff(source_code_pro_regular_data))
  // assert_true(is_embedded_font_woff(source_code_pro_bold_data))
  // assert_true(is_embedded_font_woff(source_code_pro_italic_data))
// }
