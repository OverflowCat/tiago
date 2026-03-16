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
  compile_objects(graph, ir, "", "", classes)
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

///|
fn test_range(offset : Int) -> @lexer.Range {
  let start = @lexer.Position::new(0, offset, offset)
  let end = @lexer.Position::new(0, offset + 1, offset + 1)
  @lexer.Range::new(start, end)
}

///|
test "sort_graph_by_references reorders objects edges and children by source ranges" {
  let graph = Graph::new("root")

  let parent = Object::new("parent")
  let child_late = Object::new(
    "parent.late",
    id_val="late",
    id_syntax="late",
    abs_id_syntax="parent.late",
  )
  child_late.references = [
    @graph.ObjectReference::new(
      test_range(40),
      0,
      false,
      Some("parent"),
      None,
      true,
      false,
      false,
    ),
  ]
  let child_early = Object::new(
    "parent.early",
    id_val="early",
    id_syntax="early",
    abs_id_syntax="parent.early",
  )
  child_early.references = [
    @graph.ObjectReference::new(
      test_range(10),
      0,
      false,
      Some("parent"),
      None,
      true,
      false,
      false,
    ),
  ]
  parent.add_child(child_late)
  parent.add_child(child_early)

  let object_late = Object::new("late")
  object_late.references = [
    @graph.ObjectReference::new(
      test_range(30),
      0,
      false,
      Some("root"),
      None,
      true,
      false,
      false,
    ),
  ]
  let object_early = Object::new("early")
  object_early.references = [
    @graph.ObjectReference::new(
      test_range(5),
      0,
      false,
      Some("root"),
      None,
      true,
      false,
      false,
    ),
  ]

  let edge_late = Edge::new(2, "late", "early", false, true)
  edge_late.references = [
    @graph.EdgeReference::new(
      test_range(50),
      2,
      Some("root"),
      None,
      true,
      false,
      false,
    ),
  ]
  let edge_early = Edge::new(1, "early", "late", false, true)
  edge_early.references = [
    @graph.EdgeReference::new(
      test_range(15),
      1,
      Some("root"),
      None,
      true,
      false,
      false,
    ),
  ]

  graph.add_object(object_late)
  graph.add_object(object_early)
  graph.add_object(parent)
  graph.add_edge(edge_late)
  graph.add_edge(edge_early)

  sort_graph_by_references(graph)

  assert_eq(graph.objects.map(fn(obj) { obj.id }), ["early", "late", "parent"])
  assert_eq(graph.edges.map(fn(edge) { edge.index }), [1, 2])
  assert_eq(parent.children.map(fn(child) { child.id }), [
    "parent.early", "parent.late",
  ])
}
