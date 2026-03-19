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
fn test_object_input(
  box : @graph.Box,
  label? : String = "",
  label_position? : String? = None,
  icon? : String? = None,
  icon_position? : String? = None,
  tooltip? : String? = None,
  tooltip_position? : String? = None,
) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    "node",
    label,
    @graph.Rectangle,
    @graph.StyleInput::new(),
    Some(box),
    None,
    [],
    0,
    icon,
    tooltip,
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
    icon_position~,
    tooltip_position~,
    label_position~,
  )
}

///|
fn test_diagram_with_object(obj : @graph.ObjectInput) -> @diagram.Diagram {
  let graph = @graph.GraphInput::from_parts(
    "svg-render-test",
    @graph.ObjectInput::new("root"),
    [obj],
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
  @diagram.from_graph(graph, None)
}

///|
test "plain object label layout uses explicit label position" {
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(100.0, 80.0, 80.0, 40.0),
      label="Node",
      label_position=Some("OUTSIDE_TOP_LEFT"),
    ),
  )
  guard diagram.find_object("node") is Some(shape) else {
    fail("expected node shape")
  }
  guard shape.box is Some(box) else { fail("expected shape box") }
  let (x, y, width) = plain_object_label_layout(shape, box, 20.0, 10.0)
  assert_eq(x, 105.0)
  assert_eq(y, 65.0)
  assert_eq(width, 20.0)
}

///|
test "positioned tooltips render without fallback appendix icon title" {
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(100.0, 80.0, 80.0, 40.0),
      tooltip=Some("hover text"),
      tooltip_position=Some("bottom-right"),
    ),
  )
  guard diagram.find_object("node") is Some(shape) else {
    fail("expected node shape")
  }
  guard shape.box is Some(box) else { fail("expected shape box") }
  let rendered = render_object_appendix_icons(
    "hash",
    shape,
    box,
    SvgConfig::new(),
    @themes.get_theme(0),
  ).join("\n")
  assert_true(rendered.contains("positioned-tooltip"))
  assert_false(rendered.contains("<title>hover text</title>"))
}

///|
test "compute graph bounds includes outside icon and positioned tooltip extents" {
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(100.0, 80.0, 80.0, 40.0),
      icon=Some("https://example.com/icon.svg"),
      icon_position=Some("OUTSIDE_RIGHT_MIDDLE"),
      tooltip=Some("hover text"),
      tooltip_position=Some("bottom-right"),
    ),
  )
  let bounds = compute_graph_bounds(
    diagram,
    SvgConfig::new(),
    @themes.get_theme(0),
  )
  assert_true(bounds.0 < 100.0)
  assert_eq(bounds.1, 79.0)
  assert_true(bounds.2 >= 217.0)
  assert_true(bounds.3 > 121.0)
}
