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

///|
test "board graphs carry folder-only metadata" {
  let layer_body = @ir.Map::new()
  layer_body.add_field(
    @ir.Field::new("service", None, Some(@ir.Composite::Map(@ir.Map::new())), []),
  )
  let layers_map = @ir.Map::new()
  layers_map.add_field(
    @ir.Field::new("one", None, Some(@ir.Composite::Map(layer_body)), []),
  )
  let ir = @ir.Map::new()
  ir.add_field(
    @ir.Field::new("layers", None, Some(@ir.Composite::Map(layers_map)), []),
  )

  let graph = compile("root", ir) catch { e => fail(e.to_string()) }
  assert_true(graph.is_folder_only)
  assert_eq(graph.layers.length(), 1)
  assert_false(graph.layers[0].graph.is_folder_only)
  assert_true(graph.layers[0].graph.find_object("service") is Some(_))
}

///|
test "graph objects preserve explicit language and sql constraints" {
  let code_body = @ir.Map::new()
  code_body.add_field(
    @ir.Field::new("shape", Some(@ir.Scalar::string("code")), None, []),
  )
  let column_body = @ir.Map::new()
  column_body.add_field(
    @ir.Field::new(
      "constraint",
      None,
      Some(
        @ir.Composite::Array(
          @ir.IRArray::new([
            @ir.Value::Scalar(@ir.Scalar::string("primary_key")),
            @ir.Value::Scalar(@ir.Scalar::string("unique")),
          ]),
        ),
      ),
      [],
    ),
  )
  let table_body = @ir.Map::new()
  table_body.add_field(
    @ir.Field::new("shape", Some(@ir.Scalar::string("sql_table")), None, []),
  )
  table_body.add_field(
    @ir.Field::new("id", None, Some(@ir.Composite::Map(column_body)), []),
  )
  let ir = @ir.Map::new()
  ir.add_field(
    @ir.Field::new(
      "snippet",
      Some(@ir.Scalar::string("select 1")),
      Some(@ir.Composite::Map(code_body)),
      [],
    ),
  )
  ir.add_field(
    @ir.Field::new("orders", None, Some(@ir.Composite::Map(table_body)), []),
  )

  let graph = compile("root", ir) catch { e => fail(e.to_string()) }
  guard graph.find_object("snippet") is Some(snippet) else {
    fail("expected code object")
  }
  guard graph.find_object("orders.id") is Some(column) else {
    fail("expected sql column object")
  }
  assert_eq(snippet.language, Some("text"))
  assert_eq(column.sql_constraints, ["primary_key", "unique"])
}
