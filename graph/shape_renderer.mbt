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
/// Shape rendering abstraction for modular shape support
///
/// This module defines the interface for rendering different shapes
/// in SVG format. Each shape type has its own render function that
/// can be called via the dispatch function.

///|
/// Context for SVG shape rendering
pub struct SvgShapeContext {
  svg : @svg.Svg
  box_ : Box
  fill : String
  stroke : String
  stroke_width : Double
  label : String
  config : SvgConfig
}

///|
/// Create a new SVG shape context
pub fn SvgShapeContext::new(
  svg : @svg.Svg,
  box_ : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  label : String,
  config : SvgConfig,
) -> SvgShapeContext {
  { svg, box_, fill, stroke, stroke_width, label, config }
}

///|
/// Render a shape to SVG based on its type
///
/// This function dispatches to the appropriate shape-specific renderer.
/// Special shapes like Text, Code, Class, SqlTable, and Image are handled
/// separately in render_svg_object because they need additional context.
pub fn render_shape_svg(shape : ShapeType, ctx : SvgShapeContext) -> Unit {
  match shape {
    Rectangle | Square => render_rectangle_svg(ctx)
    Circle | Oval => render_ellipse_svg(ctx)
    Diamond => render_diamond_svg(ctx)
    Hexagon => render_hexagon_svg(ctx)
    Octagon => render_octagon_svg(ctx)
    Parallelogram => render_parallelogram_svg(ctx)
    Cylinder => render_cylinder_svg(ctx)
    Person => render_person_svg(ctx)
    Cloud => render_cloud_svg(ctx)
    Document => render_document_svg(ctx)
    Queue => render_queue_svg(ctx)
    StoredData => render_stored_data_svg(ctx)
    Page => render_page_svg(ctx)
    Package => render_package_svg(ctx)
    Step => render_step_svg(ctx)
    Callout => render_callout_svg(ctx)
    C4Person => render_c4_person_svg(ctx)
    C4Container => render_c4_container_svg(ctx)
    // Text, Code, Class, SqlTable, Image, SequenceDiagram handled specially
    _ => render_rectangle_svg(ctx)
  }
}

// ============================================================================
// SVG Shape Renderers
// ============================================================================

///|
fn render_rectangle_svg(ctx : SvgShapeContext) -> Unit {
  ctx.svg.add(
    @svg.rect(
      ctx.box_.x,
      ctx.box_.y,
      ctx.box_.width,
      ctx.box_.height,
      fill=ctx.fill,
      stroke=ctx.stroke,
      stroke_width=ctx.stroke_width,
    ),
  )
}

///|
fn render_ellipse_svg(ctx : SvgShapeContext) -> Unit {
  let cx = ctx.box_.x + ctx.box_.width / 2.0
  let cy = ctx.box_.y + ctx.box_.height / 2.0
  ctx.svg.add(
    @svg.ellipse(
      cx,
      cy,
      ctx.box_.width / 2.0,
      ctx.box_.height / 2.0,
      fill=ctx.fill,
      stroke=ctx.stroke,
      stroke_width=ctx.stroke_width,
    ),
  )
}

///|
fn render_diamond_svg(ctx : SvgShapeContext) -> Unit {
  let cx = ctx.box_.x + ctx.box_.width / 2.0
  let cy = ctx.box_.y + ctx.box_.height / 2.0
  ctx.svg.add(
    @svg.polygon(
      [
        (cx, ctx.box_.y),
        (ctx.box_.x + ctx.box_.width, cy),
        (cx, ctx.box_.y + ctx.box_.height),
        (ctx.box_.x, cy),
      ],
      fill=ctx.fill,
      stroke=ctx.stroke,
      stroke_width=ctx.stroke_width,
    ),
  )
}

///|
fn render_hexagon_svg(ctx : SvgShapeContext) -> Unit {
  let inset = ctx.box_.width * 0.25
  ctx.svg.add(
    @svg.polygon(
      [
        (ctx.box_.x + inset, ctx.box_.y),
        (ctx.box_.x + ctx.box_.width - inset, ctx.box_.y),
        (ctx.box_.x + ctx.box_.width, ctx.box_.y + ctx.box_.height / 2.0),
        (ctx.box_.x + ctx.box_.width - inset, ctx.box_.y + ctx.box_.height),
        (ctx.box_.x + inset, ctx.box_.y + ctx.box_.height),
        (ctx.box_.x, ctx.box_.y + ctx.box_.height / 2.0),
      ],
      fill=ctx.fill,
      stroke=ctx.stroke,
      stroke_width=ctx.stroke_width,
    ),
  )
}

///|
fn render_octagon_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_octagon(ctx.svg, ctx.box_, ctx.fill, ctx.stroke, ctx.stroke_width)
}

///|
fn render_parallelogram_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_parallelogram(
    ctx.svg,
    ctx.box_,
    ctx.fill,
    ctx.stroke,
    ctx.stroke_width,
  )
}

///|
fn render_cylinder_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_cylinder(ctx.svg, ctx.box_, ctx.fill, ctx.stroke, ctx.stroke_width)
}

///|
fn render_person_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_person(ctx.svg, ctx.box_, ctx.fill, ctx.stroke, ctx.stroke_width)
}

///|
fn render_cloud_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_cloud(ctx.svg, ctx.box_, ctx.fill, ctx.stroke, ctx.stroke_width)
}

///|
fn render_document_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_document(ctx.svg, ctx.box_, ctx.fill, ctx.stroke, ctx.stroke_width)
}

///|
fn render_queue_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_queue(ctx.svg, ctx.box_, ctx.fill, ctx.stroke, ctx.stroke_width)
}

///|
fn render_stored_data_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_stored_data(
    ctx.svg,
    ctx.box_,
    ctx.fill,
    ctx.stroke,
    ctx.stroke_width,
  )
}

///|
fn render_page_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_page(ctx.svg, ctx.box_, ctx.fill, ctx.stroke, ctx.stroke_width)
}

///|
fn render_package_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_package(ctx.svg, ctx.box_, ctx.fill, ctx.stroke, ctx.stroke_width)
}

///|
fn render_step_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_step(ctx.svg, ctx.box_, ctx.fill, ctx.stroke, ctx.stroke_width)
}

///|
fn render_callout_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_callout(ctx.svg, ctx.box_, ctx.fill, ctx.stroke, ctx.stroke_width)
}

///|
fn render_c4_person_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_c4_person(
    ctx.svg,
    ctx.box_,
    ctx.label,
    ctx.fill,
    ctx.stroke,
    ctx.stroke_width,
    ctx.config,
  )
}

///|
fn render_c4_container_svg(ctx : SvgShapeContext) -> Unit {
  render_svg_c4_container(
    ctx.svg,
    ctx.box_,
    ctx.label,
    ctx.fill,
    ctx.stroke,
    ctx.stroke_width,
    ctx.config,
  )
}
