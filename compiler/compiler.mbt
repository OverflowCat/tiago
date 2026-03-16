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
/// Compiler-layer API for source parsing and graph compilation.

///|
pub struct ParseOptions {
  import_resolver : @ir.ImportResolver?
}

///|
pub fn ParseOptions::new() -> ParseOptions {
  { import_resolver: None }
}

///|
pub fn ParseOptions::with_import_resolver(
  self : ParseOptions,
  import_resolver : @ir.ImportResolver?,
) -> ParseOptions {
  ignore(self)
  { import_resolver, }
}

///|
pub(all) enum CompileError {
  ParseError(String)
  IOError(String)
  IrError(String)
  GraphError(String)
  ConfigError(String)
} derive(Eq, Show)

///|
pub struct CompileResult {
  ir_map : @ir.Map
  graph_input : @graph.GraphInput
  source_config : @diagram.Config?
}

///|
pub fn CompileResult::ir_map(self : CompileResult) -> @ir.Map {
  self.ir_map
}

///|
pub fn CompileResult::graph_input(self : CompileResult) -> @graph.GraphInput {
  self.graph_input
}

///|
pub fn CompileResult::source_config(self : CompileResult) -> @diagram.Config? {
  self.source_config
}

///|
pub fn parse(source : String) -> (@ast.Map, @parser.ParseErrors) {
  @parser.parse(source)
}

///|
pub fn compile_ir(
  source : String,
  options? : ParseOptions = ParseOptions::new(),
) -> Result[@ir.Map, CompileError] {
  let (ast, errors) = parse(source)
  if !errors.is_empty() {
    return Err(ParseError("Parse errors: \{errors}"))
  }
  let resolver = options.import_resolver.unwrap_or(
    @ir.ImportResolver::new(fn(_) { None }),
  )
  Ok(@ir.compile_with_imports(ast, resolver)) catch {
    e => Err(IrError(e.to_string()))
  }
}

///|
pub fn compile_graph(
  name : String,
  source : String,
  options? : ParseOptions = ParseOptions::new(),
) -> Result[CompileResult, CompileError] {
  let ir_map = match compile_ir(source, options~) {
    Ok(ir_map) => ir_map
    Err(err) => return Err(err)
  }
  let source_config = match extract_source_config(ir_map) {
    Ok(config) => config
    Err(err) => return Err(err)
  }
  let base_graph_input = @exporter.to_graph(name, ir_map) catch {
    e => return Err(GraphError(e.to_string()))
  }
  let graph_input = @graph.GraphInput::from_parts(
    base_graph_input.name,
    base_graph_input.root,
    base_graph_input.objects,
    base_graph_input.edges,
    base_graph_input.sequence_fragments,
    base_graph_input.activation_boxes,
    base_graph_input.sequence_notes,
    base_graph_input.sequence_fragments_layout,
    base_graph_input.layers,
    base_graph_input.scenarios,
    base_graph_input.steps,
    base_graph_input.legend,
    is_folder_only=base_graph_input.is_folder_only,
    data=graph_data_from_source_config(source_config),
  )
  Ok({ ir_map, graph_input, source_config })
}
