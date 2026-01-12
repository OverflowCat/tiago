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
/// Render diago source to SVG
pub fn render_svg() -> Int {
  render_svg_with_engine(0)
}

///|
pub fn render_svg_with_engine(engine : Int) -> Int {
  let source = bytes_to_string(input_buffer)
  let result = compile_diago_svg(source, None, engine)
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
/// Render diago source to ASCII
pub fn render_ascii() -> Int {
  render_ascii_with_engine(0)
}

///|
pub fn render_ascii_with_engine(engine : Int) -> Int {
  let source = bytes_to_string(input_buffer)
  let result = compile_diago_text(
    source,
    @renderer_ascii.AsciiConfig::new(),
    engine,
  )
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
/// Render diago source to Unicode box-drawing characters
pub fn render_unicode() -> Int {
  render_unicode_with_engine(0)
}

///|
pub fn render_unicode_with_engine(engine : Int) -> Int {
  let source = bytes_to_string(input_buffer)
  let result = match compile_to_diagram(source, engine) {
    Ok(diagram) => Ok(@renderer_unicode.render(diagram))
    Err(e) => Err(e)
  }
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
/// Compile diago source to SVG
fn compile_diago_svg(
  source : String,
  theme_name : String?,
  engine : Int,
) -> Result[String, String] {
  match compile_to_diagram(source, engine) {
    Ok(diagram) => {
      let render_config = match theme_name {
        Some(name) => @renderer_svg.SvgConfig::with_theme_name(name)
        None => @renderer_svg.SvgConfig::new()
      }
      Ok(@renderer_svg.render(diagram, render_config))
    }
    Err(e) => Err(e)
  }
}

///|
/// Compile diago source to text art (ASCII or Unicode)
fn compile_diago_text(
  source : String,
  config : @renderer_ascii.AsciiConfig,
  engine : Int,
) -> Result[String, String] {
  match compile_to_diagram(source, engine) {
    Ok(diagram) => Ok(@renderer_ascii.render(diagram, config))
    Err(e) => Err(e)
  }
}

///|
/// Compile diago source to a render-ready diagram
fn compile_to_diagram(
  source : String,
  engine : Int,
) -> Result[@diagram.Diagram, String] {
  let (ast, errors) = @compiler.parse(source)
  if not(errors.is_empty()) {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let graph_input = @exporter.to_graph("diagram", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let config = @engine_api.LayoutConfig::new()
  let diagram = if engine == 1 {
    @diagram.layout_with_engine(
      @engine_dagre.DagreEngine::new(),
      graph_input,
      config,
      @engine_api.Down,
    ) catch {
      e => return Err("Layout error: \{e}")
    }
  } else if engine == 2 {
    @diagram.layout_with_engine(
      @engine_railway.RailwayEngine::new(),
      graph_input,
      config,
      @engine_api.Down,
    ) catch {
      e => return Err("Layout error: \{e}")
    }
  } else {
    @diagram.layout_with_engine(
      @engine_elk.ElkEngine::new(),
      graph_input,
      config,
      @engine_api.Down,
    ) catch {
      e => return Err("Layout error: \{e}")
    }
  }
  Ok(diagram)
}
