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
priv enum CliCommand {
  Render
  Fmt
  Validate
  Layout
  Themes
  Version
  InternalDumpInput
}

///|
priv struct RenderRequest {
  input_path : String?
  output_path : String?
  from_stdin : Bool
  output_mode : OutputMode
  ascii_mode : AsciiMode
  layout_engine : LayoutEngineChoice
  layout_explicit : Bool
  target_spec : String?
  theme_name : String?
  dark_theme_id : Int?
  pad : Double?
  center : Bool?
  theme_overrides : @diagram.ThemeOverrides?
  dark_theme_overrides : @diagram.ThemeOverrides?
  scale : Double?
  bundle : Bool
  no_xml_tag : Bool?
  salt : String?
  omit_version : Bool?
  watch : Bool
  watch_interval_ms : Int
  preview_enabled : Bool
  preview_host : String
  preview_port : Int
  preview_open_browser : Bool
}

///|
priv struct FmtRequest {
  check : Bool
  files : Array[String]
}

///|
priv struct ValidateRequest {
  input_path : String?
  from_stdin : Bool
}

///|
priv struct LayoutRequest {
  engine_name : String?
}

///|
priv struct DumpInputRequest {
  engine : DumpInputEngine
  out_dir : String
  input_paths : Array[String]
}

///|
priv struct CliRequest {
  command : CliCommand
  render : RenderRequest?
  fmt : FmtRequest?
  validate : ValidateRequest?
  layout : LayoutRequest?
  dump_input : DumpInputRequest?
}

///|
fn CliRequest::themes() -> CliRequest {
  {
    command: CliCommand::Themes,
    render: None,
    fmt: None,
    validate: None,
    layout: None,
    dump_input: None,
  }
}

///|
fn CliRequest::version() -> CliRequest {
  {
    command: CliCommand::Version,
    render: None,
    fmt: None,
    validate: None,
    layout: None,
    dump_input: None,
  }
}

///|
fn CliRequest::render(req : RenderRequest) -> CliRequest {
  {
    command: CliCommand::Render,
    render: Some(req),
    fmt: None,
    validate: None,
    layout: None,
    dump_input: None,
  }
}

///|
fn CliRequest::fmt(req : FmtRequest) -> CliRequest {
  {
    command: CliCommand::Fmt,
    render: None,
    fmt: Some(req),
    validate: None,
    layout: None,
    dump_input: None,
  }
}

///|
fn CliRequest::validate(req : ValidateRequest) -> CliRequest {
  {
    command: CliCommand::Validate,
    render: None,
    fmt: None,
    validate: Some(req),
    layout: None,
    dump_input: None,
  }
}

///|
fn CliRequest::layout(req : LayoutRequest) -> CliRequest {
  {
    command: CliCommand::Layout,
    render: None,
    fmt: None,
    validate: None,
    layout: Some(req),
    dump_input: None,
  }
}

///|
fn CliRequest::dump_input(req : DumpInputRequest) -> CliRequest {
  {
    command: CliCommand::InternalDumpInput,
    render: None,
    fmt: None,
    validate: None,
    layout: None,
    dump_input: Some(req),
  }
}
