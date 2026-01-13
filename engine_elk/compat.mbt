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
/// Internal compat aliases so the legacy layout implementation can live under
/// `engine_elk/` while using the shared `engine_api` contract.

///|
pub type LayoutConfig = @engine_api.LayoutConfig

///|
pub type Direction = @engine_api.Direction

///|
pub type LayoutError = @engine_api.LayoutError

///|
pub type LayoutPatch = @graph.LayoutPatch
