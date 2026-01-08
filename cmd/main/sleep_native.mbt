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
fn sleep_supported_internal() -> Bool {
  true
}

///|
fn sleep_ms_internal(ms : Int) -> Unit {
  let mut usec = ms * 1000
  if usec < 0 {
    usec = 0
  }
  let _ = usleep_ffi(usec)

}

///|
extern "C" fn usleep_ffi(usec : Int) -> Int = "usleep"
