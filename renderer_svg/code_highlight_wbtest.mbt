///|
test "code language aliases normalize" {
  assert_true(code_language_from_tag(Some("go")) == Go)
  assert_true(code_language_from_tag(Some("golang")) == Go)
  assert_true(code_language_from_tag(Some("js")) == JavaScript)
  assert_true(code_language_from_tag(Some("ts")) == TypeScript)
  assert_true(code_language_from_tag(Some("py")) == Python)
  assert_true(code_language_from_tag(Some("md")) == Markdown)
}

///|
test "javascript line highlights keyword function number and comment" {
  let raw = code_line_svg_raw(
    "const x = foo(1) // comment",
    Some("javascript"),
    false,
  )
  assert_true(
    raw.contains("fill=\"#000000\" class=\"text-mono-bold\">const</tspan>"),
  )
  assert_true(
    raw.contains("fill=\"#990000\" class=\"text-mono-bold\">foo</tspan>"),
  )
  assert_true(raw.contains("fill=\"#009999\">1</tspan>"))
  assert_true(
    raw.contains(
      "fill=\"#999988\" class=\"text-mono-italic\">//&#160;comment</tspan>",
    ),
  )
}

///|
test "markup line highlights tag and attribute" {
  let raw = code_line_svg_raw("<div class=\"x\">ok</div>", Some("html"), false)
  assert_true(raw.contains("fill=\"#000080\">div</tspan>"))
  assert_true(raw.contains("fill=\"#008080\">class</tspan>"))
}

///|
test "unknown language uses dark text fallback style" {
  let raw = code_line_svg_raw("hello world", Some("unknown"), true)
  assert_true(raw.contains("fill=\"#cdd6f4\">hello</tspan>"))
  assert_true(raw.contains("fill=\"#cdd6f4\">world</tspan>"))
}
