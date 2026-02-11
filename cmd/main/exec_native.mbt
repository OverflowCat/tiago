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
fn command_exec_supported_internal() -> Bool {
  true
}

///|
fn command_exec_internal(command : String) -> Int {
  let command_bytes = to_c_ascii_bytes(command)
  system_ffi(command_bytes)
}

///|
#borrow(command)
extern "C" fn system_ffi(command : Bytes) -> Int = "system"

///|
fn to_c_ascii_bytes(s : String) -> Bytes {
  Bytes::makei(s.length() + 1, fn(i) {
    if i == s.length() {
      b'\x00'
    } else {
      s.code_unit_at(i).to_int().to_byte()
    }
  })
}
