///|
test "syntax_path_last_display preserves quoted dots and escapes" {
  assert_eq(syntax_path_last_display("alpha.\"beta.gamma\""), "beta.gamma")
  assert_eq(syntax_path_last_display("alpha.'beta.gamma'"), "beta.gamma")
  assert_eq(syntax_path_last_display("alpha.\"+peek\\\"()\""), "+peek\"()")
  assert_eq(syntax_path_last_display("alpha.rewind()"), "rewind()")
}
