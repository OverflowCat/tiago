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
/// Deep cloning helpers for Graph/Object/Edge.
///
/// Layout engines should treat `graph.Graph` as read-only input. A deep clone
/// enables engines to reuse existing in-place layout logic internally while
/// still honoring the “no in-place mutation of the input graph” contract.

///|
fn clone_box(b : Box) -> Box {
  Box::new(b.x, b.y, b.width, b.height)
}

///|
fn clone_point(p : Point) -> Point {
  Point::new(p.x, p.y)
}

///|
fn clone_port(p : Port) -> Port {
  {
    side: p.side,
    position: p.position,
    point: match p.point {
      Some(pt) => Some(clone_point(pt))
      None => None
    },
  }
}

///|
fn clone_style(s : Style) -> Style {
  {
    opacity: s.opacity,
    stroke: s.stroke,
    fill: s.fill,
    stroke_width: s.stroke_width,
    stroke_dash: s.stroke_dash,
    border_radius: s.border_radius,
    shadow: s.shadow,
    three_d: s.three_d,
    multiple: s.multiple,
    font: s.font,
    font_size: s.font_size,
    font_color: s.font_color,
    bold: s.bold,
    italic: s.italic,
    underline: s.underline,
    animated: s.animated,
    filled: s.filled,
    double_border: s.double_border,
    text_transform: s.text_transform,
    font_family: s.font_family,
    fill_pattern: s.fill_pattern,
    sketch: s.sketch,
    curved: s.curved,
  }
}

///|
fn clone_object_shallow(obj : Object) -> Object {
  {
    id: obj.id,
    label: obj.label,
    shape_type: obj.shape_type,
    style: clone_style(obj.style),
    box: match obj.box {
      Some(b) => Some(clone_box(b))
      None => None
    },
    label_box: match obj.label_box {
      Some(b) => Some(clone_box(b))
      None => None
    },
    children: [],
    z_index: obj.z_index,
    icon: obj.icon,
    tooltip: obj.tooltip,
    link: obj.link,
    classes: obj.classes.copy(),
    grid_rows: obj.grid_rows,
    grid_columns: obj.grid_columns,
    grid_gap: obj.grid_gap,
    horizontal_gap: obj.horizontal_gap,
    vertical_gap: obj.vertical_gap,
    grid_column_span: obj.grid_column_span,
    grid_row_span: obj.grid_row_span,
    near: obj.near,
  }
}

///|
fn clone_edge(edge : Edge) -> Edge {
  let route : Array[Point] = []
  for p in edge.route {
    route.push(clone_point(p))
  }
  let bend_points = match edge.bend_points {
    Some(ps) => {
      let cps : Array[Point] = []
      for p in ps {
        cps.push(clone_point(p))
      }
      Some(cps)
    }
    None => None
  }
  {
    index: edge.index,
    src_id: edge.src_id,
    dst_id: edge.dst_id,
    src_arrow: edge.src_arrow,
    dst_arrow: edge.dst_arrow,
    src_arrowhead: edge.src_arrowhead,
    dst_arrowhead: edge.dst_arrowhead,
    src_anchor: edge.src_anchor,
    dst_anchor: edge.dst_anchor,
    label: edge.label,
    style: clone_style(edge.style),
    route,
    bend_points,
    is_curve: edge.is_curve,
    z_index: edge.z_index,
    reference_count: edge.reference_count,
    label_box: match edge.label_box {
      Some(b) => Some(clone_box(b))
      None => None
    },
    src_column_index: edge.src_column_index,
    dst_column_index: edge.dst_column_index,
    src_port: match edge.src_port {
      Some(p) => Some(clone_port(p))
      None => None
    },
    dst_port: match edge.dst_port {
      Some(p) => Some(clone_port(p))
      None => None
    },
  }
}

///|
fn clone_fragment_operand(op : FragmentOperand) -> FragmentOperand {
  { condition: op.condition, separator_y: op.separator_y }
}

///|
fn clone_sequence_fragment(f : SequenceFragment) -> SequenceFragment {
  let ops : Array[FragmentOperand] = []
  for op in f.operands {
    ops.push(clone_fragment_operand(op))
  }
  {
    fragment_type: f.fragment_type,
    condition: f.condition,
    bbox: match f.bbox {
      Some(b) => Some(clone_box(b))
      None => None
    },
    start_index: f.start_index,
    end_index: f.end_index,
    operands: ops,
  }
}

///|
fn clone_legend_entry(e : LegendEntry) -> LegendEntry {
  match e {
    ShapeEntry(shape~, label~, style~) =>
      LegendEntry::shape(
        shape,
        label,
        match style {
          Some(s) => Some(clone_style(s))
          None => None
        },
      )
    ConnectionEntry(src_arrow~, dst_arrow~, label~, style~) =>
      LegendEntry::connection(
        src_arrow,
        dst_arrow,
        label,
        match style {
          Some(s) => Some(clone_style(s))
          None => None
        },
      )
    CustomEntry(icon~, label~) => LegendEntry::custom(icon, label)
    Separator => LegendEntry::separator()
  }
}

///|
fn clone_legend(legend : Legend) -> Legend {
  let entries : Array[LegendEntry] = []
  for e in legend.entries {
    entries.push(clone_legend_entry(e))
  }
  {
    title: legend.title,
    position: legend.position,
    entries,
    fill: legend.fill,
    stroke: legend.stroke,
    padding: legend.padding,
    entry_gap: legend.entry_gap,
    icon_size: legend.icon_size,
  }
}

///|
pub fn Graph::clone_deep(self : Graph) -> Graph {
  let root = clone_object_shallow(self.root)
  let obj_map : Map[String, Object] = {}
  for obj in self.objects {
    obj_map[obj.id] = clone_object_shallow(obj)
  }

  // Reconnect children using the id->object map to preserve identity between
  // `graph.objects` and nested `children` arrays.
  for obj in self.objects {
    let cloned = obj_map[obj.id]
    for child in obj.children {
      match obj_map.get(child.id) {
        Some(c) => cloned.children.push(c)
        None => cloned.children.push(clone_object_shallow(child))
      }
    }
  }
  for child in self.root.children {
    match obj_map.get(child.id) {
      Some(c) => root.children.push(c)
      None => root.children.push(clone_object_shallow(child))
    }
  }
  let objects : Array[Object] = []
  for obj in self.objects {
    objects.push(obj_map[obj.id])
  }
  let edges : Array[Edge] = []
  for edge in self.edges {
    edges.push(clone_edge(edge))
  }
  let activation_boxes : Array[(String, Box)] = []
  for entry in self.activation_boxes {
    activation_boxes.push((entry.0, clone_box(entry.1)))
  }
  let sequence_notes : Array[(String, String, Box)] = []
  for entry in self.sequence_notes {
    sequence_notes.push((entry.0, entry.1, clone_box(entry.2)))
  }
  let sequence_fragments : Array[SequenceFragment] = []
  for f in self.sequence_fragments {
    sequence_fragments.push(clone_sequence_fragment(f))
  }
  let layers : Array[Layer] = []
  for layer in self.layers {
    layers.push({ name: layer.name, graph: layer.graph.clone_deep() })
  }
  let scenarios : Array[Scenario] = []
  for s in self.scenarios {
    scenarios.push({ name: s.name, graph: s.graph.clone_deep() })
  }
  let steps : Array[Step] = []
  for s in self.steps {
    steps.push({ name: s.name, graph: s.graph.clone_deep() })
  }
  {
    name: self.name,
    root,
    objects,
    edges,
    activation_boxes,
    sequence_notes,
    sequence_fragments,
    layers,
    scenarios,
    steps,
    legend: match self.legend {
      Some(l) => Some(clone_legend(l))
      None => None
    },
  }
}
