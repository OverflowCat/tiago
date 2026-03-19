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
fn constant_near_label_test_object(
  label_position : String?,
) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    "cluster",
    "Near label",
    @graph.Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    [],
    0,
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
    label_position~,
  )
}

///|
test "constant near place shifts left for outside-right labels like d2" {
  let plain = constant_near_label_test_object(None)
  let outside_right = constant_near_label_test_object(
    Some("OUTSIDE_RIGHT_MIDDLE"),
  )
  let plain_pos = place_constant_near_box(
    plain, "top-left", 0.0, 0.0, 100.0, 80.0, 60.0, 40.0,
  )
  let adjusted_pos = place_constant_near_box(
    outside_right, "top-left", 0.0, 0.0, 100.0, 80.0, 60.0, 40.0,
  )
  let (label_width, _) = object_label_dimensions(outside_right).unwrap()
  assert_eq(adjusted_pos.0, plain_pos.0 - label_width)
  assert_eq(adjusted_pos.1, plain_pos.1)
}

///|
test "constant near place shifts down for outside-top labels like d2" {
  let plain = constant_near_label_test_object(None)
  let outside_top = constant_near_label_test_object(Some("OUTSIDE_TOP_CENTER"))
  let plain_pos = place_constant_near_box(
    plain, "bottom-right", 0.0, 0.0, 100.0, 80.0, 60.0, 40.0,
  )
  let adjusted_pos = place_constant_near_box(
    outside_top, "bottom-right", 0.0, 0.0, 100.0, 80.0, 60.0, 40.0,
  )
  let (_, label_height) = object_label_dimensions(outside_top).unwrap()
  assert_eq(adjusted_pos.0, plain_pos.0)
  assert_eq(adjusted_pos.1, plain_pos.1 + label_height)
}

///|
fn include_self_compat_test_graph() -> (
  @graph.GraphInput,
  @graph.ObjectInput,
  @graph.ObjectInput,
) {
  let nested = @graph.ObjectInput::new(
    "nested",
    abs_id_syntax="container.nested",
  )
  let container = @graph.ObjectInput::from_parts(
    "container",
    "container",
    @graph.Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["container.nested"],
    0,
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
    abs_id_syntax="container",
  )
  let root = @graph.ObjectInput::from_parts(
    "root",
    "",
    @graph.Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["container"],
    0,
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
  let graph = @graph.GraphInput::from_parts(
    "diagram",
    root,
    [container, nested],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    None,
    extracted_include_self=true,
  )
  (graph, container, nested)
}

///|
test "moon_elk include-self compatibility only strips the extracted root container options" {
  let root = make_root_layout_options(
    @engine_api.LayoutConfig::new(),
    @engine_api.Direction::Down,
    50,
  )
  let container = make_container_layout_options(
    @engine_api.LayoutConfig::new(),
    @engine_api.Direction::Down,
    104.0,
    81.0,
    50,
  )
  let nested_container = make_container_layout_options(
    @engine_api.LayoutConfig::new(),
    @engine_api.Direction::Down,
    104.0,
    81.0,
    50,
  )
  let (graph, extracted_root_child, nested_child) = include_self_compat_test_graph()

  apply_include_self_container_model_order_compat_like_d2(
    graph, extracted_root_child, container,
  )
  apply_include_self_container_model_order_compat_like_d2(
    graph, nested_child, nested_container,
  )

  assert_true(root.get("elk.layered.considerModelOrder.strategy") is Some(_))
  assert_true(
    root.get("elk.layered.crossingMinimization.forceNodeModelOrder") is None,
  )
  assert_true(container.get("elk.layered.considerModelOrder.strategy") is None)
  assert_true(
    container.get("elk.layered.crossingMinimization.forceNodeModelOrder")
    is None,
  )
  assert_true(
    nested_container.get("elk.layered.considerModelOrder.strategy") is Some(_),
  )
  assert_true(
    nested_container.get("elk.layered.crossingMinimization.forceNodeModelOrder")
    is Some(_),
  )
}
