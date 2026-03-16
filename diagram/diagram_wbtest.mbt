///|
fn test_object(
  id : String,
  label : String,
  shape_type : @graph.ShapeType,
  child_ids? : Array[String] = [],
  tooltip? : String? = None,
  link? : String? = None,
  language? : String? = None,
  sql_constraints? : Array[String] = [],
) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    id,
    label,
    shape_type,
    @graph.StyleInput::new(),
    None,
    None,
    child_ids,
    0,
    None,
    tooltip,
    link,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    direction=None,
    language~,
    sql_constraints~,
  )
}

///|
fn test_edge(
  index : Int,
  src_id : String,
  dst_id : String,
  label : String,
  src_label? : String? = None,
  dst_label? : String? = None,
) -> @graph.EdgeInput {
  @graph.EdgeInput::from_parts(
    index,
    src_id,
    dst_id,
    false,
    true,
    @graph.ArrowheadType::None,
    @graph.ArrowheadType::Triangle,
    src_label,
    dst_label,
    None,
    None,
    None,
    None,
    label,
    @graph.StyleInput::new(),
    [],
    None,
    false,
    0,
    1,
    None,
    None,
    None,
  )
}

///|
fn test_graph_input(
  name : String,
  objects? : Array[@graph.ObjectInput] = [],
  edges? : Array[@graph.EdgeInput] = [],
  layers? : Array[@graph.LayerInput] = [],
  scenarios? : Array[@graph.ScenarioInput] = [],
  steps? : Array[@graph.StepInput] = [],
  legend? : @graph.LegendInput? = None,
) -> @graph.GraphInput {
  @graph.GraphInput::from_parts(
    name,
    @graph.ObjectInput::new("root"),
    objects,
    edges,
    [],
    [],
    [],
    [],
    layers,
    scenarios,
    steps,
    legend,
  )
}

///|
fn test_diagram(
  name : String,
  objects? : Array[@graph.ObjectInput] = [],
  edges? : Array[@graph.EdgeInput] = [],
  layers? : Array[@graph.LayerInput] = [],
  scenarios? : Array[@graph.ScenarioInput] = [],
  steps? : Array[@graph.StepInput] = [],
  legend? : @graph.LegendInput? = None,
  config? : Config? = None,
) -> Diagram {
  from_graph(
    test_graph_input(
      name,
      objects~,
      edges~,
      layers~,
      scenarios~,
      steps~,
      legend~,
    ),
    config,
  )
}

///|
fn test_config(theme_id : Int) -> Config {
  Config::from_parts(
    None,
    Some(theme_id),
    None,
    {},
    {},
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    {},
  )
}

///|
test "get_board supports explicit and shorthand nested paths" {
  let scenario_graph = test_graph_input("scenario-one", objects=[
    test_object("nested.service", "Service", @graph.ShapeType::Rectangle),
  ])
  let layer_graph = test_graph_input("layer-one", scenarios=[
    @graph.ScenarioInput::new("scenario-one", scenario_graph),
  ])
  let diagram = test_diagram("root", layers=[
    @graph.LayerInput::new("layer-one", layer_graph),
  ])

  assert_eq(
    diagram
    .get_board(["layers", "layer-one", "scenarios", "scenario-one"])
    .unwrap().name,
    "scenario-one",
  )
  assert_eq(
    diagram.get_board(["layer-one", "scenario-one"]).unwrap().name,
    "scenario-one",
  )
  assert_eq(diagram.get_board(["root"]).unwrap().name, "root")
}

///|
test "has_shape recurses across nested boards" {
  let scenario_graph = test_graph_input("scenario-one", objects=[
    test_object("nested.service", "Service", @graph.ShapeType::Rectangle),
  ])
  let layer_graph = test_graph_input("layer-one", scenarios=[
    @graph.ScenarioInput::new("scenario-one", scenario_graph),
  ])
  let diagram = test_diagram("root", layers=[
    @graph.LayerInput::new("layer-one", layer_graph),
  ])

  assert_eq(diagram.has_shape(fn(shape) { shape.id == "nested.service" }), true)
  assert_eq(diagram.has_shape(fn(shape) { shape.id == "missing" }), false)
}

///|
test "get_corpus matches d2-style appendices legend and structured members" {
  let legend = @graph.LegendInput::from_parts(
    Some("Legend"),
    @graph.LegendPosition::TopRight,
    [
      @graph.LegendEntryInput::shape(
        @graph.ShapeType::Rectangle,
        "Service",
        None,
      ),
      @graph.LegendEntryInput::connection(
        @graph.ArrowheadType::None,
        @graph.ArrowheadType::Triangle,
        "Uses",
        None,
      ),
    ],
    None,
    None,
    0.0,
    0.0,
    0.0,
  )
  let diagram = test_diagram(
    "root",
    objects=[
      test_object(
        "user",
        "User",
        @graph.ShapeType::Rectangle,
        tooltip=Some("tip"),
        link=Some("https://example.com"),
      ),
      test_object("Account", "Account", @graph.ShapeType::Class, child_ids=[
        "Account.+name", "Account.+save()",
      ]),
      test_object("Account.+name", "string", @graph.ShapeType::Text),
      test_object("Account.+save()", "", @graph.ShapeType::Text),
      test_object("users", "users", @graph.ShapeType::SqlTable, child_ids=[
        "users.id", "users.email",
      ]),
      test_object("users.id", "int", @graph.ShapeType::Text, sql_constraints=[
        "primary_key",
      ]),
      test_object("users.email", "text", @graph.ShapeType::Text, sql_constraints=[
        "unique",
      ]),
    ],
    edges=[
      test_edge(
        0,
        "user",
        "users",
        "owns",
        src_label=Some("1"),
        dst_label=Some("N"),
      ),
    ],
    legend=Some(legend),
  )

  inspect(
    diagram.get_corpus(),
    content="Usertip1https://example.com2Accountnamestring+save()void+usersidintPKemailtextUNQowns1NLegendServiceUses",
  )
}

///|
test "get_nested_corpus includes nested boards" {
  let layer_graph = test_graph_input("layer-one", objects=[
    test_object("child", "Child", @graph.ShapeType::Rectangle),
  ])
  let diagram = test_diagram(
    "root",
    objects=[test_object("root-node", "Root", @graph.ShapeType::Rectangle)],
    layers=[@graph.LayerInput::new("layer-one", layer_graph)],
  )

  inspect(diagram.get_corpus(), content="Root")
  inspect(diagram.get_nested_corpus(), content="RootChild")
}

///|
test "hash_id follows d2 target config bytes and salt" {
  let a = test_diagram(
    "root",
    objects=[test_object("node", "Node", @graph.ShapeType::Rectangle)],
    config=Some(test_config(3)),
  )
  let b = test_diagram(
    "root",
    objects=[test_object("node", "Node", @graph.ShapeType::Rectangle)],
    config=Some(test_config(4)),
  )

  assert_eq(a.hash_id(None) == b.hash_id(None), false)
  assert_eq(a.hash_id(None) == a.hash_id(Some("salt")), false)
}

///|
test "hash_id includes target position metadata" {
  let base = from_graph(
    @graph.GraphInput::from_parts(
      "hash-pos-base",
      @graph.ObjectInput::new("root"),
      [
        @graph.ObjectInput::from_parts(
          "node",
          "Node",
          @graph.ShapeType::Rectangle,
          @graph.StyleInput::new(),
          Some(@graph.Box::new(0.0, 0.0, 120.0, 60.0)),
          None,
          [],
          0,
          Some("https://example.com/icon.svg"),
          Some("hover text"),
          None,
          [],
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          None,
        ),
      ],
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      None,
    ),
    None,
  )
  let positioned = from_graph(
    @graph.GraphInput::from_parts(
      "hash-pos-positioned",
      @graph.ObjectInput::new("root"),
      [
        @graph.ObjectInput::from_parts(
          "node",
          "Node",
          @graph.ShapeType::Rectangle,
          @graph.StyleInput::new(),
          Some(@graph.Box::new(0.0, 0.0, 120.0, 60.0)),
          None,
          [],
          0,
          Some("https://example.com/icon.svg"),
          Some("hover text"),
          None,
          [],
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          icon_position=Some("OUTSIDE_RIGHT_MIDDLE"),
          tooltip_position=Some("bottom-right"),
          label_position=Some("OUTSIDE_TOP_LEFT"),
        ),
      ],
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      None,
    ),
    None,
  )

  assert_true(base.hash_id(None) != positioned.hash_id(None))
}
