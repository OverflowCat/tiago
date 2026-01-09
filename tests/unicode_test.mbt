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
/// Unicode renderer regression tests

///|
test "unicode renderer uses box drawing characters" {
  let graph = compile_to_graph("server\nclient", @engine_api.Direction::Down).unwrap()
  let unicode = @d2renderer_unicode.render_graph(graph)
  assert_true(unicode.contains("┌") || unicode.contains("┏"))
  assert_true(unicode.contains("─") || unicode.contains("━"))
  assert_true(unicode.contains("│") || unicode.contains("┃"))
}

///|
test "unicode diagram entrypoint matches render_graph" {
  let diagram = compile_to_diagram("a -> b", @engine_api.Direction::Down).unwrap()
  let graph = diagram.materialize()
  assert_eq(
    @d2renderer_unicode.render(diagram),
    @d2renderer_unicode.render_graph(graph),
  )
}
