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
// Part 1: Import functions from the protocol and create wrappers.
// Don't edit this part unless you know what you are doing.

///|
fn __send_result_to_host(ptr : Int, len : Int) = "typst_env" "wasm_minimal_protocol_send_result_to_host"

///|
fn __write_args_to_buffer(ptr : Int) = "typst_env" "wasm_minimal_protocol_write_args_to_buffer"

///|
/// Returns a raw pointer to the first data byte of `bytes`.
#borrow(bytes)
extern "wasm" fn _as_ptr(bytes : Bytes) -> Int =
  #|(func (param i32) (result i32)
  #|  (i32.add (local.get 0) (i32.const 8)))
// `Bytes` have 8-byte headers, so this is not `%identity`.
// Note that the ABI for `Bytes` is unstable. Refer to README for further explanation.

///|
/// Reinterpret the byte sequence as Bytes.
///
/// Notice that this will make the `Bytes` object to be a view of the original
/// byte sequence, so any modification to the original byte sequence will be
/// reflected in the `Bytes` object.
///
/// This is a copy of `FixedArray::unsafe_reinterpret_as_bytes`.
/// https://github.com/moonbitlang/core/blob/a2cc59d/builtin/bytes.mbt#L15-L25
fn as_bytes(arr : FixedArray[Byte]) -> Bytes = "%identity"

///|
fn send_result(bytes : Bytes) -> Unit {
  __send_result_to_host(_as_ptr(bytes), bytes.length())
}

///|
fn write_args(arr : FixedArray[Byte]) -> Unit {
  let bytes = as_bytes(arr)
  __write_args_to_buffer(_as_ptr(bytes))
}

// ===
// Part 2: Diago Typst plugin.

///|
/// Render Diago source (D2 language) to SVG using the default (Dagre) layout engine.
/// Typst usage: #str(diago.render_svg(bytes(source)))
pub fn render_svg(source_len : Int) -> Int {
  let args = FixedArray::make(source_len, b'\x00')
  write_args(args)
  let source = fixed_array_to_string(args)
  match compile_diago_svg(source, None, 0) {
    Ok(svg) => {
      send_result(@utf8.encode(svg[:]))
      0
    }
    Err(e) => {
      send_result(@utf8.encode("Error: \{e}"[:]))
      1
    }
  }
}

///|
/// Render Diago source to SVG with a specified layout engine.
/// Pass the engine name as a second bytes argument: "dagre", "elk", or "railway".
/// Typst usage: #str(diago.render_svg_with_engine(bytes(source), bytes("elk")))
pub fn render_svg_with_engine(source_len : Int, engine_len : Int) -> Int {
  let args = FixedArray::make(source_len + engine_len, b'\x00')
  write_args(args)
  let source = slice_fixed_array_to_string(args, 0, source_len)
  let engine_str = slice_fixed_array_to_string(args, source_len, engine_len)
  let engine = engine_from_string(engine_str)
  match compile_diago_svg(source, None, engine) {
    Ok(svg) => {
      send_result(@utf8.encode(svg[:]))
      0
    }
    Err(e) => {
      send_result(@utf8.encode("Error: \{e}"[:]))
      1
    }
  }
}

///|
/// Render Diago source to ASCII art using the default (Dagre) layout engine.
/// Typst usage: #str(diago.render_ascii(bytes(source)))
pub fn render_ascii(source_len : Int) -> Int {
  let args = FixedArray::make(source_len, b'\x00')
  write_args(args)
  let source = fixed_array_to_string(args)
  match compile_diago_ascii(source, 0) {
    Ok(text) => {
      send_result(@utf8.encode(text[:]))
      0
    }
    Err(e) => {
      send_result(@utf8.encode("Error: \{e}"[:]))
      1
    }
  }
}

///|
/// Render Diago source to ASCII art with a specified layout engine.
/// Pass the engine name as a second bytes argument: "dagre", "elk", or "railway".
pub fn render_ascii_with_engine(source_len : Int, engine_len : Int) -> Int {
  let args = FixedArray::make(source_len + engine_len, b'\x00')
  write_args(args)
  let source = slice_fixed_array_to_string(args, 0, source_len)
  let engine_str = slice_fixed_array_to_string(args, source_len, engine_len)
  let engine = engine_from_string(engine_str)
  match compile_diago_ascii(source, engine) {
    Ok(text) => {
      send_result(@utf8.encode(text[:]))
      0
    }
    Err(e) => {
      send_result(@utf8.encode("Error: \{e}"[:]))
      1
    }
  }
}

///|
/// Render Diago source to Unicode box-drawing characters using the default layout engine.
/// Typst usage: #str(diago.render_unicode(bytes(source)))
pub fn render_unicode(source_len : Int) -> Int {
  let args = FixedArray::make(source_len, b'\x00')
  write_args(args)
  let source = fixed_array_to_string(args)
  match compile_diago_unicode(source, 0) {
    Ok(text) => {
      send_result(@utf8.encode(text[:]))
      0
    }
    Err(e) => {
      send_result(@utf8.encode("Error: \{e}"[:]))
      1
    }
  }
}

///|
/// Render Diago source to Unicode box-drawing characters with a specified layout engine.
/// Pass the engine name as a second bytes argument: "dagre", "elk", or "railway".
pub fn render_unicode_with_engine(source_len : Int, engine_len : Int) -> Int {
  let args = FixedArray::make(source_len + engine_len, b'\x00')
  write_args(args)
  let source = slice_fixed_array_to_string(args, 0, source_len)
  let engine_str = slice_fixed_array_to_string(args, source_len, engine_len)
  let engine = engine_from_string(engine_str)
  match compile_diago_unicode(source, engine) {
    Ok(text) => {
      send_result(@utf8.encode(text[:]))
      0
    }
    Err(e) => {
      send_result(@utf8.encode("Error: \{e}"[:]))
      1
    }
  }
}

// === Internal helpers ===

///|
fn fixed_array_to_string(arr : FixedArray[Byte]) -> String {
  @utf8.decode_lossy(as_bytes(arr).view())
}

///|
fn slice_fixed_array_to_string(
  arr : FixedArray[Byte],
  offset : Int,
  len : Int,
) -> String {
  let slice = FixedArray::make(len, b'\x00')
  arr.blit_to(slice, len~, src_offset=offset)
  @utf8.decode_lossy(as_bytes(slice).view())
}

///|
fn engine_from_string(s : String) -> Int {
  if s == "elk" {
    1
  } else if s == "railway" {
    2
  } else {
    0
  }
}

///|
fn compile_diago_svg(
  source : String,
  theme_name : String?,
  engine : Int,
) -> Result[String, String] {
  let diagram = match compile_to_diagram(source, engine) {
    Ok(diagram) => diagram
    Err(err) => return Err(err)
  }
  let render_options = @lib.RenderOptions::new()
    .with_output_mode(@lib.Svg)
    .with_theme_name(theme_name)
  match @lib.render(diagram, options=render_options) {
    Ok(svg) => Ok(svg)
    Err(err) => Err(lib_error_message(err))
  }
}

///|
fn compile_diago_ascii(source : String, engine : Int) -> Result[String, String] {
  match compile_to_diagram(source, engine) {
    Ok(diagram) =>
      match
        @lib.render(
          diagram,
          options=@lib.RenderOptions::new().with_output_mode(@lib.Ascii),
        ) {
        Ok(text) => Ok(text)
        Err(err) => Err(lib_error_message(err))
      }
    Err(err) => Err(err)
  }
}

///|
fn compile_diago_unicode(
  source : String,
  engine : Int,
) -> Result[String, String] {
  match compile_to_diagram(source, engine) {
    Ok(diagram) => Ok(@renderer_unicode.render(diagram))
    Err(err) => Err(err)
  }
}

///|
/// Compile diago source to a render-ready diagram
fn compile_to_diagram(
  source : String,
  engine : Int,
) -> Result[@diagram.Diagram, String] {
  let compiled = match @compiler.compile_graph("diagram", source) {
    Ok(compiled) => compiled
    Err(err) => return Err(compiler_error_message(err))
  }
  let diagram_options = @lib.DiagramOptions::new()
    .with_layout_engine(resolve_layout_engine(engine))
    .with_direction(@engine_api.Down)
  match
    @lib.compile_diagram(
      compiled.graph_input(),
      compiled.source_config(),
      options=diagram_options,
    ) {
    Ok(diagram) => Ok(diagram)
    Err(err) => Err(lib_error_message(err))
  }
}

///|
fn resolve_layout_engine(engine : Int) -> @lib.LayoutEngine {
  if engine == 1 {
    @lib.Elk
  } else if engine == 2 {
    @lib.Railway
  } else {
    @lib.Dagre
  }
}

///|
fn compiler_error_message(err : @compiler.CompileError) -> String {
  match err {
    @compiler.ParseError(message) => message
    @compiler.IOError(message) => message
    @compiler.IrError(message) => message
    @compiler.GraphError(message) => message
    @compiler.ConfigError(message) => message
  }
}

///|
fn lib_error_message(err : @lib.LibError) -> String {
  match err {
    @lib.LayoutError(message) => message
    @lib.RenderError(message) => message
    @lib.ConfigError(message) => message
    @lib.TargetError(message) => message
  }
}
