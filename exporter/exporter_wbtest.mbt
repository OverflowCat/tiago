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
test "classes block is treated as reserved during object compilation" {
  let class_def = @ir.Map::new()
  class_def.add_field(
    @ir.Field::new("shape", Some(@ir.Scalar::string("person")), None, []),
  )
  let classes_map = @ir.Map::new()
  classes_map.add_field(
    @ir.Field::new("user", None, Some(@ir.Composite::Map(class_def)), []),
  )
  let alice_map = @ir.Map::new()
  let ir = @ir.Map::new()
  ir.add_field(
    @ir.Field::new("classes", None, Some(@ir.Composite::Map(classes_map)), []),
  )
  ir.add_field(
    @ir.Field::new(
      "alice",
      Some(@ir.Scalar::string("Alice")),
      Some(@ir.Composite::Map(alice_map)),
      [],
    ),
  )
  guard ir.get_field("classes") is Some(classes_field) else {
    fail("expected classes field")
  }
  assert_true(classes_field.is_reserved_keyword_name())
  let classes = extract_classes(ir)
  let graph = Graph::new("root")
  compile_objects(graph, ir, "", classes)
  assert_eq(graph.objects.length(), 1)
  assert_eq(graph.objects[0].id, "alice")
}
