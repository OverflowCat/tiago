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
fn read_source_file(file_path : String) -> String raise DiagoError {
  @fs.read_file_to_string(file_path) catch {
    e => raise IOError("Error reading file '\{file_path}': \{e}")
  }
}

///|
fn get_dir_path(file_path : String) -> String? {
  let path = @path.Path(file_path)
  let dir = path.dirname()
  let dir_str = dir.to_string()
  if dir_str.length() > 0 {
    Some(dir_str)
  } else {
    None
  }
}

///|
fn default_import_resolver(base_path : String?) -> @ir.ImportResolver {
  @ir.ImportResolver::new(fn(import_path) {
    let full_path = match base_path {
      Some(base) => @path.Path(base).join(@path.Path(import_path)).to_string()
      None => import_path
    }
    let path_with_ext = if full_path.has_suffix(".d2") {
      full_path
    } else {
      full_path + ".d2"
    }
    Some(@fs.read_file_to_string(path_with_ext)) catch {
      _ => None
    }
  })
}

///|
fn resolve_parse_options(options : ParseOptions) -> ParseOptions {
  match options.import_resolver {
    Some(_) => options
    None =>
      {
        ..options,
        import_resolver: Some(default_import_resolver(options.base_path)),
      }
  }
}

///|
fn resolve_parse_options_for_file(
  file_path : String,
  options : ParseOptions,
) -> ParseOptions {
  let resolved_base_path = match options.base_path {
    Some(base_path) => Some(base_path)
    None => get_dir_path(file_path)
  }
  resolve_parse_options({ ..options, base_path: resolved_base_path })
}
