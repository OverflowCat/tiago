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
/// ASCII renderer.
///
/// All layout decisions (box placement, edge routing, legend placement) are
/// computed by `layout_ascii`. This module only draws the plan.

///|
/// ASCII rendering configuration
pub struct AsciiConfig {
  /// Minimum box width in characters
  min_box_width : Int
  /// Box height in lines
  box_height : Int
  /// Horizontal padding inside box
  h_padding : Int
  /// Vertical spacing between boxes
  v_spacing : Int
  /// Horizontal spacing between boxes
  h_spacing : Int
  /// Minimum canvas width
  min_width : Int
  /// Minimum canvas height
  min_height : Int
  /// Character set for rendering
  charset : @ascii.CharSet
} derive(Show)

///|
pub fn AsciiConfig::new() -> AsciiConfig {
  {
    min_box_width: 6,
    box_height: 4,
    h_padding: 1,
    v_spacing: 4,
    h_spacing: 2,
    min_width: 40,
    min_height: 10,
    charset: @ascii.CharSet::ascii(),
  }
}

///|
/// Create config with Unicode charset
pub fn AsciiConfig::unicode() -> AsciiConfig {
  {
    min_box_width: 6,
    box_height: 4,
    h_padding: 1,
    v_spacing: 4,
    h_spacing: 2,
    min_width: 40,
    min_height: 10,
    charset: @ascii.CharSet::unicode(),
  }
}

///|
fn to_layout_config(config : AsciiConfig) -> @layout_ascii.AsciiLayoutConfig {
  @layout_ascii.AsciiLayoutConfig::from_parts(
    config.min_box_width,
    config.box_height,
    config.h_padding,
    config.v_spacing,
    config.h_spacing,
    config.min_width,
    config.min_height,
  )
}

///|
/// Render a diagram to ASCII string
pub fn render_ascii(graph : @diagram.Diagram, config : AsciiConfig) -> String {
  let plan = @layout_ascii.plan(graph, to_layout_config(config))
  let grid = @ascii.Grid::new(plan.canvas_width, plan.canvas_height)

  // Boxes
  for box in plan.boxes {
    render_ascii_box(grid, box, config.charset)
  }

  // Edges
  for e in plan.edges {
    draw_edge(grid, e, config.charset)
  }

  // Edge labels
  for e in plan.edges {
    match e.label_pos {
      Some(p) => if e.label != "" { grid.text(p.x, p.y, e.label) }
      None => ()
    }
  }

  // Legend
  match plan.legend {
    Some((_legend, legend_plan)) =>
      draw_legend(grid, legend_plan, config.charset)
    None => ()
  }
  grid.to_string()
}

///|
fn draw_edge(
  grid : @ascii.Grid,
  edge : @layout_ascii.EdgePlan,
  cs : @ascii.CharSet,
) -> Unit {
  if edge.points.length() < 2 {
    return
  }

  // Draw polyline segments.
  for i = 0; i < edge.points.length() - 1; i = i + 1 {
    let p0 = edge.points[i]
    let p1 = edge.points[i + 1]
    if p0.x == p1.x {
      let y0 = if p0.y < p1.y { p0.y } else { p1.y }
      let y1 = if p0.y < p1.y { p1.y } else { p0.y }
      grid.vline(p0.x, y0, y1, cs.vertical())
    } else if p0.y == p1.y {
      let x0 = if p0.x < p1.x { p0.x } else { p1.x }
      let x1 = if p0.x < p1.x { p1.x } else { p0.x }
      grid.hline(x0, x1, p0.y, cs.horizontal())
    } else {
      // Fallback: draw a simple cornered L
      grid.set(p0.x, p0.y, cs.bottom_left())
      grid.hline(p0.x, p1.x, p0.y, cs.horizontal())
      grid.vline(p1.x, p0.y, p1.y, cs.vertical())
    }
  }

  // Arrowhead
  match edge.arrow {
    Some((p, dir)) =>
      match dir {
        @layout_ascii.ArrowDir::Down => grid.set(p.x, p.y, cs.arrow_down())
        @layout_ascii.ArrowDir::Up => grid.set(p.x, p.y, cs.arrow_up())
        @layout_ascii.ArrowDir::Left => grid.set(p.x, p.y, cs.arrow_left())
        @layout_ascii.ArrowDir::Right => grid.set(p.x, p.y, cs.arrow_right())
      }
    None => ()
  }
}

///|
fn draw_legend(
  grid : @ascii.Grid,
  plan : @layout_ascii.LegendPlan,
  cs : @ascii.CharSet,
) -> Unit {
  grid.box_rect(plan.x, plan.y, plan.x + plan.width, plan.y + plan.height, cs)
  for row in plan.rows {
    let (x, y, text) = row
    grid.text(x, y, text)
  }
  for sep in plan.separators {
    let (x1, x2, y) = sep
    grid.hline(x1, x2, y, cs.horizontal())
  }
}

///|
fn render_ascii_box(
  grid : @ascii.Grid,
  box : @layout_ascii.AsciiBox,
  cs : @ascii.CharSet,
) -> Unit {
  let x1 = box.x
  let y1 = box.y
  let x2 = box.x + box.width - 1
  let y2 = box.y + box.height - 1
  match box.shape {
    "text" => {
      grid.text(x1, y1, box.label)
      return
    }
    "code" => {
      grid.box_rect(x1, y1, x2, y2, cs)
      grid.text(x1 + 1, y1 + 1, "`")
      return
    }
    "sql_table" => {
      grid.box_rect(x1, y1, x2, y2, cs)
      // Separator after title
      if y1 + 2 < y2 {
        grid.hline(x1 + 1, x2 - 1, y1 + 2, cs.horizontal())
      }
      // Column labels
      let mut row_y = y1 + 3
      for col in box.children {
        if row_y < y2 {
          grid.text(x1 + 1, row_y, col.label)
          row_y = row_y + 1
        }
      }
    }
    _ => grid.box_rect(x1, y1, x2, y2, cs)
  }

  // Label (top row inside)
  if box.label != "" && box.shape != "sql_column" {
    let label_x = x1 + (box.width - box.label.length()) / 2
    let label_y = y1 + 1
    grid.text(label_x, label_y, box.label)
  }
}
