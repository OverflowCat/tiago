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
/// Regression tests for deterministic edge ordering across compilation stages.

///|
test "edge order: architecture load_balancer fanout" {
  let source = @fs.read_file_to_string("examples/architecture.d2")
  let (ast, errors) = @parser.parse(source)
  if !errors.is_empty() {
    fail("parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => fail("IR error: \{e}") }
  let graph_input = @exporter.compile("test", ir) catch {
    e => fail("Graph error: \{e}")
  }
  let outs : Array[String] = []
  for e in graph_input.edges {
    if e.src_id == "load_balancer" && e.dst_id.has_prefix("web_tier.") {
      outs.push(e.dst_id)
    }
  }
  assert_eq(outs, ["web_tier.web1", "web_tier.web2", "web_tier.web3"])
}
