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
fn compile_source_graph(source : String) -> Result[@graph.GraphInput, String] {
  let (ast, errors) = @parser.parse(source)
  if !errors.is_empty() {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  let result = try? compile("root", ir)
  match result {
    Ok(graph) => Ok(graph)
    Err(err) => Err(err.to_string())
  }
}

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
test "scenarios and steps inherit base board objects while layers stay isolated" {
  let source =
    #|x: {
    #|  style.opacity: 0.5
    #|}
    #|scenarios: {
    #|  scene: {}
    #|}
    #|steps: {
    #|  1: {}
    #|}
    #|layers: {
    #|  alt: {
    #|    x
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.scenarios[0].graph.find_object("x") is Some(scenario_x) else {
    fail("expected inherited scenario object")
  }
  guard graph.steps[0].graph.find_object("x") is Some(step_x) else {
    fail("expected inherited step object")
  }
  guard graph.layers[0].graph.find_object("x") is Some(layer_x) else {
    fail("expected layer object")
  }
  assert_false(graph.scenarios[0].graph.is_folder_only)
  assert_false(graph.steps[0].graph.is_folder_only)
  assert_eq(
    scenario_x.style.opacity,
    Some(@graph.StyleValue::from_string("0.5")),
  )
  assert_eq(step_x.style.opacity, Some(@graph.StyleValue::from_string("0.5")))
  assert_eq(layer_x.style.opacity, None)
}

///|
test "scenario overlays preserve base objects and apply overrides" {
  let source =
    #|a
    #|x
    #|a -> x
    #|scenarios: {
    #|  focus: {
    #|    x.style.opacity: 0.1
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  let scenario = graph.scenarios[0].graph
  assert_eq(scenario.objects.length(), 2)
  assert_eq(scenario.edges.length(), 1)
  guard scenario.find_object("x") is Some(x) else {
    fail("expected overlaid object")
  }
  assert_eq(x.style.opacity, Some(@graph.StyleValue::from_string("0.1")))
}

///|
test "board primary labels override explicit labels and base labels are not inherited" {
  let source =
    #|label: hi
    #|layers: {
    #|  1: one {
    #|    RJ
    #|  }
    #|  2: {
    #|    label: two
    #|    RJ
    #|  }
    #|}
    #|scenarios: {
    #|  x: b {
    #|    k
    #|  }
    #|}
    #|steps: {
    #|  s1: {
    #|    RJ
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  assert_eq(graph.layers[0].graph.root.label, "one")
  assert_eq(graph.layers[1].graph.root.label, "two")
  assert_eq(graph.scenarios[0].graph.root.label, "b")
  assert_eq(graph.steps[0].graph.root.label, "root")
}

///|
test "duplicate board names across kinds raise semantic error" {
  let source =
    #|layers: {
    #|  one: {
    #|    santa
    #|  }
    #|}
    #|steps: {
    #|  one: {
    #|    clause
    #|  }
    #|}
  match compile_source_graph(source) {
    Err(err) =>
      assert_true(err.contains("board name one already used by another board"))
    Ok(_) => fail("expected duplicate board name error")
  }
}

///|
test "board keywords must be declared at a board root scope" {
  let source =
    #|x: {
    #|  steps: {
    #|    1: {
    #|      a
    #|    }
    #|  }
    #|}
  match compile_source_graph(source) {
    Err(err) =>
      assert_true(err.contains("steps must be declared at a board root scope"))
    Ok(_) => fail("expected board root scope error")
  }
}

///|
test "board links canonicalize quoted board targets" {
  let source =
    #|x.link: layers."cat.go"
    #|layers: {
    #|  "cat.go": {
    #|    y
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.find_object("x") is Some(x) else {
    fail("expected linked object")
  }
  assert_eq(x.link, Some("root.layers.\"cat.go\""))
}

///|
test "board links resolve relative underscores and discard invalid links" {
  let source =
    #|question.link: layers.cat
    #|plain.link: two
    #|layers: {
    #|  cat: {
    #|    meow
    #|    layers: {
    #|      kitten: {
    #|        up.link: _
    #|        self.link: _.layers.kitten
    #|        missing.link: _._._
    #|        remote.link: https://example.com/docs
    #|      }
    #|    }
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.find_object("question") is Some(question) else {
    fail("expected question object")
  }
  guard graph.find_object("plain") is Some(plain) else {
    fail("expected plain object")
  }
  let kitten_board = graph.layers[0].graph.layers[0].graph
  guard kitten_board.find_object("up") is Some(up) else {
    fail("expected relative-link object")
  }
  guard kitten_board.find_object("self") is Some(self) else {
    fail("expected self-link object")
  }
  guard kitten_board.find_object("missing") is Some(missing) else {
    fail("expected missing-link object")
  }
  guard kitten_board.find_object("remote") is Some(remote) else {
    fail("expected remote-link object")
  }
  assert_eq(question.link, Some("root.layers.cat"))
  assert_eq(plain.link, None)
  assert_eq(up.link, Some("root.layers.cat"))
  assert_eq(self.link, None)
  assert_eq(missing.link, None)
  assert_eq(remote.link, Some("https://example.com/docs"))
}

///|
test "near keys cannot target descendants of grid diagrams" {
  let source =
    #|x.near: z.x
    #|z: {
    #|  grid-rows: 1
    #|  x
    #|}
  match compile_source_graph(source) {
    Err(err) =>
      assert_true(
        err.contains(
          "near keys cannot be set to descendants of special objects, like grid cells",
        ),
      )
    Ok(_) => fail("expected near_special error")
  }
}

///|
test "near keys cannot target objects within sequence diagrams" {
  let source =
    #|x: {
    #|  shape: sequence_diagram
    #|  a
    #|}
    #|b.near: x.a
  match compile_source_graph(source) {
    Err(err) =>
      assert_true(
        err.contains(
          "near keys cannot be set to an object within sequence diagrams",
        ),
      )
    Ok(_) => fail("expected near_sequence error")
  }
}

///|
test "near keys cannot target objects with constant near keys" {
  let source =
    #|title: Title {
    #|  near: top-center
    #|}
    #|
    #|obj {
    #|  near: title
    #|}
  match compile_source_graph(source) {
    Err(err) =>
      assert_true(
        err.contains(
          "near keys cannot be set to an object with a constant near key",
        ),
      )
    Ok(_) => fail("expected near_near_const error")
  }
}

///|
test "edges from constant near containers cannot enter themselves" {
  let source =
    #|tl: {
    #|  near: top-left
    #|  a
    #|}
    #|tl -> tl.a
  match compile_source_graph(source) {
    Err(err) => assert_true(err.contains("edge from constant near"))
    Ok(_) => fail("expected constant near edge error")
  }
}

///|
test "edges from grid diagrams and cells cannot enter themselves" {
  let grid_source =
    #|grid: {
    #|  grid-rows: 1
    #|  cell
    #|}
    #|grid -> grid.cell
  match compile_source_graph(grid_source) {
    Err(err) => assert_true(err.contains("edge from grid diagram"))
    Ok(_) => fail("expected grid diagram edge error")
  }

  let cell_source =
    #|grid: {
    #|  grid-rows: 1
    #|  cell: {
    #|    c
    #|  }
    #|}
    #|grid.cell -> grid.cell.c
  match compile_source_graph(cell_source) {
    Err(err) => assert_true(err.contains("edge from grid cell"))
    Ok(_) => fail("expected grid cell edge error")
  }
}

///|
test "edges from sequence diagrams cannot enter themselves" {
  let source =
    #|seq: {
    #|  shape: sequence_diagram
    #|  e
    #|}
    #|seq -> seq.e
  match compile_source_graph(source) {
    Err(err) => assert_true(err.contains("edge from sequence diagram"))
    Ok(_) => fail("expected sequence diagram edge error")
  }
}

///|
test "label icon and tooltip near fields follow d2 position semantics" {
  let source =
    #|hey: {
    #|  label: sushi {
    #|    near: outside-top-left
    #|  }
    #|  icon: https://asdf.com {
    #|    near: border-right-center
    #|  }
    #|  tooltip: hover text {
    #|    near: center-left
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.find_object("hey") is Some(hey) else { fail("expected object") }
  assert_eq(hey.label, "sushi")
  assert_eq(hey.icon, Some("https://asdf.com"))
  assert_eq(hey.tooltip, Some("hover text"))
  assert_eq(hey.label_position, Some("OUTSIDE_TOP_LEFT"))
  assert_eq(hey.icon_position, Some("BORDER_RIGHT_MIDDLE"))
  assert_eq(hey.tooltip_position, Some("center-left"))
}

///|
test "separate near fields and null position resets follow d2 semantics" {
  let source =
    #|hey: sushi {
    #|  label.near: outside-top-left
    #|  tooltip: hover text {
    #|    near: null
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.find_object("hey") is Some(hey) else { fail("expected object") }
  assert_eq(hey.label, "sushi")
  assert_eq(hey.label_position, Some("OUTSIDE_TOP_LEFT"))
  assert_eq(hey.tooltip_position, None)
}

///|
test "tooltip near rejects label-only positions like d2" {
  let source =
    #|hey: {
    #|  tooltip: hover text {
    #|    near: outside-top-left
    #|  }
    #|}
  match compile_source_graph(source) {
    Err(_) => ()
    Ok(_) => fail("expected invalid near error")
  }
}

///|
test "d2-legend follows D2 compile semantics and defaults" {
  let source =
    #|vars: {
    #|  d2-legend: "凡例" {
    #|    User: "A person who interacts with the system" {
    #|      shape: person
    #|      style: {
    #|        fill: "#f5f5f5"
    #|      }
    #|    }
    #|
    #|    Database: "Stores application data" {
    #|      shape: cylinder
    #|      style.fill: "#b5d3ff"
    #|    }
    #|
    #|    HiddenShape: "This should not appear in the legend" {
    #|      style.opacity: 0
    #|    }
    #|
    #|    User -> Database: "Reads data" {
    #|      style.stroke: blue
    #|    }
    #|
    #|    Database -> User: "Returns results" {
    #|      style.stroke-dash: 5
    #|    }
    #|  }
    #|}
    #|
    #|user: User
    #|db: Database
    #|user -> db: Uses
  let graph = compile_source_graph(source).unwrap()
  guard graph.legend is Some(legend) else {
    fail("expected legend to be compiled")
  }

  assert_eq(legend.title, Some("凡例"))
  assert_eq(legend.position, @graph.LegendPosition::BottomRight)
  assert_eq(legend.fill, Some("#ffffff"))
  assert_eq(legend.stroke, Some("#DEE1EB"))
  assert_eq(legend.padding, 20.0)
  assert_eq(legend.entry_gap, 15.0)
  assert_eq(legend.icon_size, 24.0)
  assert_eq(legend.entry_count(), 4)
  assert_eq(legend.entries.length(), 5)

  match legend.entries[0] {
    @graph.ShapeEntry(shape~, label~, style~) => {
      assert_eq(shape, @graph.ShapeType::Person)
      assert_eq(label, "A person who interacts with the system")
      guard style is Some(style_input) else {
        fail("expected user legend style")
      }
      assert_eq(style_input.fill.unwrap().get_value(), "#f5f5f5")
    }
    _ => fail("expected first legend entry to be user shape")
  }

  match legend.entries[1] {
    @graph.ShapeEntry(shape~, label~, style~) => {
      assert_eq(shape, @graph.ShapeType::Cylinder)
      assert_eq(label, "Stores application data")
      guard style is Some(style_input) else {
        fail("expected database legend style")
      }
      assert_eq(style_input.fill.unwrap().get_value(), "#b5d3ff")
    }
    _ => fail("expected second legend entry to be database shape")
  }

  assert_true(legend.entries[2] is @graph.Separator)

  match legend.entries[3] {
    @graph.ConnectionEntry(src_arrow~, dst_arrow~, label~, style~) => {
      assert_eq(src_arrow, @graph.ArrowheadType::None)
      assert_eq(dst_arrow, @graph.ArrowheadType::Triangle)
      assert_eq(label, "Reads data")
      guard style is Some(style_input) else {
        fail("expected reads-data legend style")
      }
      assert_eq(style_input.stroke.unwrap().get_value(), "blue")
    }
    _ => fail("expected fourth legend entry to be reads-data connection")
  }

  match legend.entries[4] {
    @graph.ConnectionEntry(src_arrow~, dst_arrow~, label~, style~) => {
      assert_eq(src_arrow, @graph.ArrowheadType::None)
      assert_eq(dst_arrow, @graph.ArrowheadType::Triangle)
      assert_eq(label, "Returns results")
      guard style is Some(style_input) else {
        fail("expected returns-results legend style")
      }
      assert_eq(style_input.stroke_dash.unwrap().get_value(), "5")
    }
    _ => fail("expected fifth legend entry to be returns-results connection")
  }

  assert_true(graph.find_object("user") is Some(_))
  assert_true(graph.find_object("db") is Some(_))
}

///|
test "d2-legend keeps zero-opacity edges like D2 compiler" {
  let source =
    #|vars: {
    #|  d2-legend: {
    #|    A
    #|    B
    #|    A -> B: Hidden {
    #|      style.opacity: 0
    #|    }
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.legend is Some(legend) else {
    fail("expected legend to be compiled")
  }
  assert_eq(legend.entry_count(), 3)
  guard legend.entries.last() is Some(last_entry) else {
    fail("expected trailing legend connection entry")
  }
  match last_entry {
    @graph.ConnectionEntry(label~, style~, ..) => {
      assert_eq(label, "Hidden")
      guard style is Some(style_input) else {
        fail("expected style on hidden legend edge")
      }
      assert_eq(style_input.opacity.unwrap().get_value(), "0")
    }
    _ => fail("expected trailing legend entry to be connection")
  }
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
