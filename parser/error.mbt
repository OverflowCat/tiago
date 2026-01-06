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
/// Parse error with location
pub struct ParseError {
  range : @lexer.Range
  message : String
} derive(Eq, Show)

///|
/// Collection of parse errors
pub struct ParseErrors {
  errors : Array[ParseError]
} derive(Eq, Show)

///|
pub fn ParseErrors::new() -> ParseErrors {
  { errors: [] }
}

///|
pub fn ParseErrors::add(
  self : ParseErrors,
  range : @lexer.Range,
  message : String,
) -> Unit {
  self.errors.push({ range, message })
}

///|
pub fn ParseErrors::is_empty(self : ParseErrors) -> Bool {
  self.errors.length() == 0
}

///|
pub fn ParseErrors::to_string(self : ParseErrors) -> String {
  let buf = StringBuilder::new()
  for i, err in self.errors {
    if i > 0 {
      buf.write_char('\n')
    }
    buf.write_string(err.range.start.line.to_string())
    buf.write_char(':')
    buf.write_string(err.range.start.column.to_string())
    buf.write_string(": ")
    buf.write_string(err.message)
  }
  buf.to_string()
}
