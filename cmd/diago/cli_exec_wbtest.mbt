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
test "render output plan writes svg before surfacing bundling warning" {
  let compiled : CompiledSourceResult = {
    output: "<svg/>",
    warning: Some("bundle warning"),
  }
  match render_output_write_plan(OutputMode::Svg, compiled) {
    RenderOutputWritePlan::WriteThenWarn(warning) =>
      assert_eq(warning, "bundle warning")
    _ => fail("expected svg warning plan to write before returning warning")
  }
}

///|
test "render output plan keeps warnings write-free for non-svg outputs" {
  let compiled : CompiledSourceResult = {
    output: "<svg/>",
    warning: Some("bundle warning"),
  }
  match render_output_write_plan(OutputMode::Unicode, compiled) {
    RenderOutputWritePlan::WarnOnly(warning) =>
      assert_eq(warning, "bundle warning")
    _ => fail("expected non-svg warning plan to skip writing output")
  }
}

///|
test "render output plan writes normally when no warning exists" {
  let compiled : CompiledSourceResult = { output: "<svg/>", warning: None }
  match render_output_write_plan(OutputMode::Svg, compiled) {
    RenderOutputWritePlan::WriteOnly => ()
    _ => fail("expected svg output without warning to write normally")
  }
  match render_output_write_plan(OutputMode::Unicode, compiled) {
    RenderOutputWritePlan::WriteOnly => ()
    _ => fail("expected non-svg output without warning to write normally")
  }
}
