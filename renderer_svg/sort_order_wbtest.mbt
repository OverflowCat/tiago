///|
fn test_object(id : String, z_index : Int) -> @graph.ObjectInput {
  test_object_with_children(id, z_index, [])
}

///|
fn test_object_with_children(
  id : String,
  z_index : Int,
  child_ids : Array[String],
) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    id,
    id,
    @graph.Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    child_ids,
    z_index,
    None,
    None,
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
  )
}

///|
fn test_shapes(objects : Array[@graph.ObjectInput]) -> Array[Shape] {
  let graph = @graph.GraphInput::from_parts(
    "sort-order-test",
    @graph.ObjectInput::new("root"),
    objects,
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    None,
  )
  let diagram = @diagram.from_graph(graph, None)
  let shapes : Array[Shape] = []
  for shape in diagram.shapes {
    if shape.id != "root" {
      shapes.push(shape)
    }
  }
  shapes
}

///|
test "sort objects by z-index depth and stable order" {
  let input = test_shapes([
    test_object("app.service", 0),
    test_object("app", 0),
    test_object("other.root", 1),
    test_object("app.db", 0),
    test_object("api", -1),
  ])
  let sorted = sort_objects_by_depth(input)
  inspect(
    sorted.map(fn(shape) { shape.id }),
    content="[\"api\", \"app\", \"app.service\", \"app.db\", \"other.root\"]",
  )
}

///|
test "sort objects preserves export order for equal z-index and depth" {
  let input = test_shapes([
    test_object("alpha.one", 3),
    test_object("beta.one", 3),
    test_object("gamma.one", 3),
  ])
  let sorted = sort_objects_by_depth(input)
  inspect(
    sorted.map(fn(shape) { shape.id }),
    content="[\"alpha.one\", \"beta.one\", \"gamma.one\"]",
  )
}

///|
test "sort objects prefers container before non-container on tie" {
  let input = test_shapes([
    test_object_with_children("group", 0, ["group.child"]),
    test_object("leaf", 0),
    test_object("group.child", 0),
  ])
  let sorted = sort_objects_by_depth(input)
  inspect(
    sorted.map(fn(shape) { shape.id }),
    content="[\"group\", \"leaf\", \"group.child\"]",
  )
}

///|
test "sort objects keeps containers before leaves even when deeper" {
  let input = test_shapes([
    test_object("aws.s3", 0),
    test_object_with_children("aws.vpc.subnet", 0, ["aws.vpc.subnet.ec2"]),
    test_object("aws.vpc.subnet.ec2", 0),
  ])
  let sorted = sort_objects_by_depth(input)
  inspect(
    sorted.map(fn(shape) { shape.id }),
    content="[\"aws.vpc.subnet\", \"aws.s3\", \"aws.vpc.subnet.ec2\"]",
  )
}
