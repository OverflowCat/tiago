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
/// WASM entry point for Diago
///
/// Exports render functions for browser usage.

///|
/// Shared buffer for input/output string passing
let input_buffer : Array[Byte] = []

///|
let output_buffer : Array[Byte] = []

///|
/// Set input string (called from JS before render)
pub fn set_input(len : Int) -> Int {
  input_buffer.resize(len, b'\x00')
  0 // Return pointer offset (always 0 for our simple buffer)
}

///|
/// Get pointer to input buffer
pub fn get_input_ptr() -> Int {
  0 // Using index-based access
}

///|
/// Write a byte to input buffer
pub fn write_input_byte(index : Int, byte : Int) -> Unit {
  if index < input_buffer.length() {
    input_buffer[index] = byte.to_byte()
  }
}

///|
/// Get output length after render
pub fn get_output_len() -> Int {
  output_buffer.length()
}

///|
/// Read a byte from output buffer
pub fn read_output_byte(index : Int) -> Int {
  if index < output_buffer.length() {
    output_buffer[index].to_int()
  } else {
    0
  }
}

///|
/// Render D2 source to SVG
pub fn render_svg() -> Int {
  let source = bytes_to_string(input_buffer)
  let result = compile_d2_svg(source, None)
  match result {
    Ok(svg) => {
      string_to_bytes(svg, output_buffer)
      0 // Success
    }
    Err(e) => {
      string_to_bytes("Error: \{e}", output_buffer)
      1 // Error
    }
  }
}

///|
/// Render D2 source to ASCII
pub fn render_ascii() -> Int {
  let source = bytes_to_string(input_buffer)
  let result = compile_d2_text(source, @graph.AsciiConfig::new())
  match result {
    Ok(ascii) => {
      string_to_bytes(ascii, output_buffer)
      0 // Success
    }
    Err(e) => {
      string_to_bytes("Error: \{e}", output_buffer)
      1 // Error
    }
  }
}

///|
/// Render D2 source to Unicode box-drawing characters
pub fn render_unicode() -> Int {
  let source = bytes_to_string(input_buffer)
  let result = compile_d2_text(source, @graph.AsciiConfig::unicode())
  match result {
    Ok(text) => {
      string_to_bytes(text, output_buffer)
      0 // Success
    }
    Err(e) => {
      string_to_bytes("Error: \{e}", output_buffer)
      1 // Error
    }
  }
}

///|
fn bytes_to_string(bytes : Array[Byte]) -> String {
  let sb = StringBuilder::new()
  for b in bytes {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
/// Encode string to UTF-8 bytes
fn string_to_bytes(s : String, out : Array[Byte]) -> Unit {
  out.clear()
  let bytes = @encoding/utf8.encode(s[:])
  for i in 0..<bytes.length() {
    out.push(bytes[i])
  }
}

///|
/// Compile D2 source to SVG
fn compile_d2_svg(
  source : String,
  theme_name : String?,
) -> Result[String, String] {
  match compile_to_graph(source) {
    Ok(graph) => {
      let render_config = match theme_name {
        Some(name) => @graph.SvgConfig::with_theme_name(name)
        None => @graph.SvgConfig::new()
      }
      Ok(@graph.render_svg(graph, render_config))
    }
    Err(e) => Err(e)
  }
}

///|
/// Compile D2 source to text art (ASCII or Unicode)
fn compile_d2_text(
  source : String,
  config : @graph.AsciiConfig,
) -> Result[String, String] {
  match compile_to_graph(source) {
    Ok(graph) => Ok(@graph.render_ascii(graph, config))
    Err(e) => Err(e)
  }
}

///|
/// Compile D2 source to laid-out graph
fn compile_to_graph(source : String) -> Result[@graph.Graph, String] {
  let (ast, errors) = @parser.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph = @graph.compile("diagram", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @layout.LayoutConfig::new()
  @layout.layout(graph, config, @layout.Direction::Down)
  Ok(graph)
}

///|
fn main {
  // Empty main - all functionality via exported functions
}
