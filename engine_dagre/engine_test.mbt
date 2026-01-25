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
test "dagre engine can layout simple graph" {
  let (ast, errors) = @parser.parse("a -> b")
  if not(errors.is_empty()) {
    fail("parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => fail("ir error: \{e}") }
  let graph_input = @exporter.compile("test", ir) catch {
    e => fail("graph error: \{e}")
  }
  let laid_out = @engine_api.layout_with_engine(
    DagreEngine::new(),
    graph_input,
    @engine_api.LayoutConfig::new(),
    @engine_api.Direction::Down,
  ) catch {
    e => fail("layout error: \{e}")
  }
  assert_true(laid_out.find_object("a").unwrap().box is Some(_))
  assert_true(laid_out.find_object("b").unwrap().box is Some(_))
  assert_true(laid_out.edges.length() == 1)
  assert_true(laid_out.edges[0].route.length() >= 2)
}
