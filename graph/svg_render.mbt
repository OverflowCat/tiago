///|
/// SVG Renderer for Graph
///
/// Renders a laid-out Graph to SVG using the pure svg library.

///|
/// SVG rendering configuration
pub struct SvgConfig {
  /// Padding around the entire diagram
  padding : Double
  /// Default font family
  font_family : String
  /// Default font size
  font_size : Int
  /// Background color
  background : String
  /// Default stroke color
  default_stroke : String
  /// Default fill color
  default_fill : String
  /// Default stroke width
  default_stroke_width : Double
  /// Arrow size
  arrow_size : Double
  /// Theme ID (0 = default)
  theme_id : Int
} derive(Show)

///|
pub fn SvgConfig::new() -> SvgConfig {
  let theme = @themes.get_theme(0)
  {
    padding: 20.0,
    font_family: "Arial, sans-serif",
    font_size: 14,
    background: theme.background_color(),
    default_stroke: theme.stroke_color(),
    default_fill: theme.fill_color(),
    default_stroke_width: 2.0,
    arrow_size: 10.0,
    theme_id: 0,
  }
}

///|
/// Create config with a specific theme
pub fn SvgConfig::with_theme(theme_id : Int) -> SvgConfig {
  let theme = @themes.get_theme(theme_id)
  let font = if theme.rules.mono { "monospace" } else { "Arial, sans-serif" }
  {
    padding: 20.0,
    font_family: font,
    font_size: 14,
    background: theme.background_color(),
    default_stroke: theme.stroke_color(),
    default_fill: theme.fill_color(),
    default_stroke_width: 2.0,
    arrow_size: 10.0,
    theme_id,
  }
}

///|
/// Create config with theme by name
pub fn SvgConfig::with_theme_name(name : String) -> SvgConfig {
  let theme = @themes.get_theme_by_name(name)
  SvgConfig::with_theme(theme.get_id())
}

///|
/// List all available theme names
pub fn list_themes() -> Array[String] {
  @themes.list_themes()
}

///|
/// Render a graph to SVG string
pub fn render_svg(graph : Graph, config : SvgConfig) -> String {
  // Calculate bounds
  let (max_x, max_y) = compute_graph_bounds(graph)
  let width = max_x + config.padding * 2.0
  let height = max_y + config.padding * 2.0
  // Create SVG document
  let svg = @svg.Svg::new(width, height)
  // Add arrow markers
  svg.add_def(
    @svg.arrow_marker("arrow", config.arrow_size, config.default_stroke),
  )
  svg.add_def(
    @svg.arrow_marker(
      "arrow-reverse",
      config.arrow_size,
      config.default_stroke,
      reverse=true,
    ),
  )
  // Background
  svg.add(@svg.background(config.background))
  // Main content group with padding offset
  svg.open_group("translate(\{config.padding},\{config.padding})")
  // Render edges first (behind objects)
  for edge in graph.edges {
    render_svg_edge(svg, edge, config)
  }
  // Render objects
  for obj in graph.objects {
    render_svg_object(svg, obj, config)
  }
  svg.close_group()
  svg.to_string()
}

///|
fn compute_graph_bounds(graph : Graph) -> (Double, Double) {
  let mut max_x = 0.0
  let mut max_y = 0.0
  for obj in graph.objects {
    match obj.box {
      Some(b) => {
        let right = b.x + b.width
        let bottom = b.y + b.height
        if right > max_x {
          max_x = right
        }
        if bottom > max_y {
          max_y = bottom
        }
      }
      None => ()
    }
  }
  (max_x, max_y)
}

///|
fn render_svg_object(svg : @svg.Svg, obj : Object, config : SvgConfig) -> Unit {
  guard obj.box is Some(box) else { return }
  // Get style values
  let fill = match obj.style.fill {
    Some(f) => f
    None => config.default_fill
  }
  let stroke = match obj.style.stroke {
    Some(s) => s
    None => config.default_stroke
  }
  let stroke_width = match obj.style.stroke_width {
    Some(w) => w
    None => config.default_stroke_width
  }
  let border_radius = match obj.style.border_radius {
    Some(r) => r
    None => 0.0
  }
  // Render shape based on type
  match obj.shape {
    "circle" | "oval" => {
      let cx = box.x + box.width / 2.0
      let cy = box.y + box.height / 2.0
      svg.add(
        @svg.ellipse(
          cx,
          cy,
          box.width / 2.0,
          box.height / 2.0,
          fill~,
          stroke~,
          stroke_width~,
        ),
      )
    }
    "cylinder" => render_svg_cylinder(svg, box, fill, stroke, stroke_width)
    "diamond" => {
      let cx = box.x + box.width / 2.0
      let cy = box.y + box.height / 2.0
      svg.add(
        @svg.polygon(
          [
            (cx, box.y),
            (box.x + box.width, cy),
            (cx, box.y + box.height),
            (box.x, cy),
          ],
          fill~,
          stroke~,
          stroke_width~,
        ),
      )
    }
    "hexagon" => {
      let inset = box.width * 0.25
      svg.add(
        @svg.polygon(
          [
            (box.x + inset, box.y),
            (box.x + box.width - inset, box.y),
            (box.x + box.width, box.y + box.height / 2.0),
            (box.x + box.width - inset, box.y + box.height),
            (box.x + inset, box.y + box.height),
            (box.x, box.y + box.height / 2.0),
          ],
          fill~,
          stroke~,
          stroke_width~,
        ),
      )
    }
    "octagon" => render_svg_octagon(svg, box, fill, stroke, stroke_width)
    "parallelogram" =>
      render_svg_parallelogram(svg, box, fill, stroke, stroke_width)
    "person" => render_svg_person(svg, box, fill, stroke, stroke_width)
    "cloud" => render_svg_cloud(svg, box, fill, stroke, stroke_width)
    "document" => render_svg_document(svg, box, fill, stroke, stroke_width)
    "queue" => render_svg_queue(svg, box, fill, stroke, stroke_width)
    "stored_data" =>
      render_svg_stored_data(svg, box, fill, stroke, stroke_width)
    "page" => render_svg_page(svg, box, fill, stroke, stroke_width)
    "package" => render_svg_package(svg, box, fill, stroke, stroke_width)
    "step" => render_svg_step(svg, box, fill, stroke, stroke_width)
    "callout" => render_svg_callout(svg, box, fill, stroke, stroke_width)
    _ =>
      svg.add(
        @svg.rect(
          box.x,
          box.y,
          box.width,
          box.height,
          fill~,
          stroke~,
          stroke_width~,
          rx=border_radius,
          ry=border_radius,
        ),
      )
  }
  // Render label
  if obj.label != "" {
    let cx = box.x + box.width / 2.0
    let cy = box.y + box.height / 2.0
    svg.add(
      @svg.text(
        cx,
        cy,
        obj.label,
        font_family=config.font_family,
        font_size=config.font_size,
      ),
    )
  }
}

///|
fn render_svg_cylinder(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let cap_height = box.height * 0.15
  // Body path using PathBuilder
  let body = @svg.PathBuilder::new()
    .move_to(box.x, box.y + cap_height)
    .arc_to(box.width / 2.0, cap_height, box.x + box.width, box.y + cap_height)
    .line_to(box.x + box.width, box.y + box.height - cap_height)
    .arc_to(box.width / 2.0, cap_height, box.x, box.y + box.height - cap_height)
    .close()
    .build()
  svg.add(@svg.path(body, fill~, stroke~, stroke_width~))
  // Top cap
  svg.add(
    @svg.ellipse(
      box.x + box.width / 2.0,
      box.y + cap_height,
      box.width / 2.0,
      cap_height,
      fill~,
      stroke~,
      stroke_width~,
    ),
  )
}

///|
fn render_svg_octagon(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let inset = box.width * 0.29
  let inset_y = box.height * 0.29
  svg.add(
    @svg.polygon(
      [
        (box.x + inset, box.y),
        (box.x + box.width - inset, box.y),
        (box.x + box.width, box.y + inset_y),
        (box.x + box.width, box.y + box.height - inset_y),
        (box.x + box.width - inset, box.y + box.height),
        (box.x + inset, box.y + box.height),
        (box.x, box.y + box.height - inset_y),
        (box.x, box.y + inset_y),
      ],
      fill~,
      stroke~,
      stroke_width~,
    ),
  )
}

///|
fn render_svg_parallelogram(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let wedge = if box.width < 52.0 { box.width / 2.0 } else { 26.0 }
  svg.add(
    @svg.polygon(
      [
        (box.x + wedge, box.y),
        (box.x + box.width, box.y),
        (box.x + box.width - wedge, box.y + box.height),
        (box.x, box.y + box.height),
      ],
      fill~,
      stroke~,
      stroke_width~,
    ),
  )
}

///|
fn render_svg_person(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Simple stick figure person
  let cx = box.x + box.width / 2.0
  let head_r = box.width * 0.2
  let head_cy = box.y + head_r + 5.0
  let body_top = head_cy + head_r
  let body_bottom = box.y + box.height * 0.6
  let arm_y = body_top + (body_bottom - body_top) * 0.3
  let leg_bottom = box.y + box.height
  // Head
  svg.add(@svg.circle(cx, head_cy, head_r, fill~, stroke~, stroke_width~))
  // Body
  svg.add(@svg.line(cx, body_top, cx, body_bottom, stroke~, stroke_width~))
  // Arms
  svg.add(
    @svg.line(
      box.x + box.width * 0.1,
      arm_y,
      box.x + box.width * 0.9,
      arm_y,
      stroke~,
      stroke_width~,
    ),
  )
  // Legs
  svg.add(
    @svg.line(
      cx,
      body_bottom,
      box.x + box.width * 0.2,
      leg_bottom,
      stroke~,
      stroke_width~,
    ),
  )
  svg.add(
    @svg.line(
      cx,
      body_bottom,
      box.x + box.width * 0.8,
      leg_bottom,
      stroke~,
      stroke_width~,
    ),
  )
}

///|
fn render_svg_cloud(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Cloud shape using bezier curves
  let sx = box.width / 100.0
  let sy = box.height / 60.0
  let pb = @svg.PathBuilder::new()
    .move_to(box.x + 20.0 * sx, box.y + 40.0 * sy)
    .cubic_to(
      box.x + 20.0 * sx,
      box.y + 55.0 * sy,
      box.x + 35.0 * sx,
      box.y + 60.0 * sy,
      box.x + 50.0 * sx,
      box.y + 55.0 * sy,
    )
    .cubic_to(
      box.x + 65.0 * sx,
      box.y + 60.0 * sy,
      box.x + 80.0 * sx,
      box.y + 55.0 * sy,
      box.x + 85.0 * sx,
      box.y + 40.0 * sy,
    )
    .cubic_to(
      box.x + 100.0 * sx,
      box.y + 35.0 * sy,
      box.x + 100.0 * sx,
      box.y + 20.0 * sy,
      box.x + 85.0 * sx,
      box.y + 15.0 * sy,
    )
    .cubic_to(
      box.x + 85.0 * sx,
      box.y + 5.0 * sy,
      box.x + 70.0 * sx,
      box.y,
      box.x + 55.0 * sx,
      box.y + 10.0 * sy,
    )
    .cubic_to(
      box.x + 45.0 * sx,
      box.y,
      box.x + 30.0 * sx,
      box.y + 5.0 * sy,
      box.x + 25.0 * sx,
      box.y + 20.0 * sy,
    )
    .cubic_to(
      box.x + 10.0 * sx,
      box.y + 20.0 * sy,
      box.x + 5.0 * sx,
      box.y + 30.0 * sy,
      box.x + 20.0 * sx,
      box.y + 40.0 * sy,
    )
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_document(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Document with wavy bottom
  let wave_h = box.height * 0.15
  let pb = @svg.PathBuilder::new()
    .move_to(box.x, box.y)
    .line_to(box.x + box.width, box.y)
    .line_to(box.x + box.width, box.y + box.height - wave_h)
    .cubic_to(
      box.x + box.width * 0.75,
      box.y + box.height - wave_h * 2.0,
      box.x + box.width * 0.5,
      box.y + box.height,
      box.x + box.width * 0.25,
      box.y + box.height - wave_h,
    )
    .cubic_to(
      box.x + box.width * 0.1,
      box.y + box.height - wave_h * 1.5,
      box.x,
      box.y + box.height - wave_h,
      box.x,
      box.y + box.height - wave_h,
    )
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_queue(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Queue/3D box shape
  let arc_w = if box.width < 30.0 { box.width / 2.0 } else { 15.0 }
  let m = 0.45 // bezier multiplier
  let pb = @svg.PathBuilder::new()
    .move_to(box.x + arc_w, box.y)
    .line_to(box.x + box.width - arc_w, box.y)
    .cubic_to(
      box.x + box.width - arc_w * m,
      box.y,
      box.x + box.width,
      box.y + box.height * 0.25,
      box.x + box.width,
      box.y + box.height * 0.5,
    )
    .cubic_to(
      box.x + box.width,
      box.y + box.height * 0.75,
      box.x + box.width - arc_w * m,
      box.y + box.height,
      box.x + box.width - arc_w,
      box.y + box.height,
    )
    .line_to(box.x + arc_w, box.y + box.height)
    .cubic_to(
      box.x + arc_w * m,
      box.y + box.height,
      box.x,
      box.y + box.height * 0.75,
      box.x,
      box.y + box.height * 0.5,
    )
    .cubic_to(
      box.x,
      box.y + box.height * 0.25,
      box.x + arc_w * m,
      box.y,
      box.x + arc_w,
      box.y,
    )
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_stored_data(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Stored data (curved sides)
  let wedge = if box.width < 30.0 { box.width / 2.0 } else { 15.0 }
  let m = 0.27
  let pb = @svg.PathBuilder::new()
    .move_to(box.x + wedge, box.y)
    .line_to(box.x + box.width - wedge, box.y)
    .cubic_to(
      box.x + box.width - wedge * m,
      box.y,
      box.x + box.width,
      box.y + box.height * 0.25,
      box.x + box.width,
      box.y + box.height * 0.5,
    )
    .cubic_to(
      box.x + box.width,
      box.y + box.height * 0.75,
      box.x + box.width - wedge * m,
      box.y + box.height,
      box.x + box.width - wedge,
      box.y + box.height,
    )
    .line_to(box.x + wedge, box.y + box.height)
    .cubic_to(
      box.x + wedge * m,
      box.y + box.height,
      box.x,
      box.y + box.height * 0.75,
      box.x,
      box.y + box.height * 0.5,
    )
    .cubic_to(
      box.x,
      box.y + box.height * 0.25,
      box.x + wedge * m,
      box.y,
      box.x + wedge,
      box.y,
    )
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_page(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Page with folded corner
  let fold = if box.width < 40.0 { box.width * 0.25 } else { 20.0 }
  let pb = @svg.PathBuilder::new()
    .move_to(box.x, box.y)
    .line_to(box.x + box.width - fold, box.y)
    .line_to(box.x + box.width, box.y + fold)
    .line_to(box.x + box.width, box.y + box.height)
    .line_to(box.x, box.y + box.height)
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
  // Fold line
  let fold_pb = @svg.PathBuilder::new()
    .move_to(box.x + box.width - fold, box.y)
    .line_to(box.x + box.width - fold, box.y + fold)
    .line_to(box.x + box.width, box.y + fold)
  svg.add(@svg.path(fold_pb.build(), fill="none", stroke~, stroke_width~))
}

///|
fn render_svg_package(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // UML package with top flap
  let w40 = box.width * 0.4
  let tab_w = if 150.0 < (if 50.0 > w40 { 50.0 } else { w40 }) {
    150.0
  } else if 50.0 > w40 {
    50.0
  } else {
    w40
  }
  let h20 = box.height * 0.2
  let tab_h = if 25.0 < h20 { 25.0 } else { h20 }
  let pb = @svg.PathBuilder::new()
    .move_to(box.x, box.y)
    .line_to(box.x + tab_w, box.y)
    .line_to(box.x + tab_w, box.y + tab_h)
    .line_to(box.x + box.width, box.y + tab_h)
    .line_to(box.x + box.width, box.y + box.height)
    .line_to(box.x, box.y + box.height)
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_step(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Chevron/arrow pointing right
  let wedge = if box.width < 70.0 { box.width / 2.0 } else { 35.0 }
  svg.add(
    @svg.polygon(
      [
        (box.x, box.y),
        (box.x + box.width - wedge, box.y),
        (box.x + box.width, box.y + box.height / 2.0),
        (box.x + box.width - wedge, box.y + box.height),
        (box.x, box.y + box.height),
        (box.x + wedge, box.y + box.height / 2.0),
      ],
      fill~,
      stroke~,
      stroke_width~,
    ),
  )
}

///|
fn render_svg_callout(
  svg : @svg.Svg,
  box : Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  // Speech bubble with pointer
  let tip_w = if box.width < 60.0 { box.width / 2.0 } else { 30.0 }
  let tip_h = if box.height < 90.0 { box.height / 2.0 } else { 45.0 }
  let main_h = box.height - tip_h
  let pb = @svg.PathBuilder::new()
    .move_to(box.x, box.y)
    .line_to(box.x + box.width, box.y)
    .line_to(box.x + box.width, box.y + main_h)
    .line_to(box.x + box.width / 2.0 + tip_w, box.y + main_h)
    .line_to(box.x + box.width / 2.0, box.y + box.height)
    .line_to(box.x + box.width / 2.0 - tip_w, box.y + main_h)
    .line_to(box.x, box.y + main_h)
    .close()
  svg.add(@svg.path(pb.build(), fill~, stroke~, stroke_width~))
}

///|
fn render_svg_edge(svg : @svg.Svg, edge : Edge, config : SvgConfig) -> Unit {
  if edge.route.length() < 2 {
    return
  }
  // Get style values
  let stroke = match edge.style.stroke {
    Some(s) => s
    None => config.default_stroke
  }
  let stroke_width = match edge.style.stroke_width {
    Some(w) => w
    None => config.default_stroke_width
  }
  // Build path
  let pb = @svg.PathBuilder::new()
  for i, point in edge.route {
    if i == 0 {
      let _ = pb.move_to(point.x, point.y)

    } else {
      let _ = pb.line_to(point.x, point.y)

    }
  }
  // Determine markers
  let marker_end = if edge.dst_arrow { "url(#arrow)" } else { "" }
  let marker_start = if edge.src_arrow { "url(#arrow-reverse)" } else { "" }
  svg.add(
    @svg.path(pb.build(), stroke~, stroke_width~, marker_start~, marker_end~),
  )
  // Render edge label
  if edge.label != "" {
    match edge.midpoint() {
      Some(mid) => {
        // Background for label
        let padding = 4.0
        let label_width = edge.label.length().to_double() * 7.0 + padding * 2.0
        let label_height = config.font_size.to_double() + padding * 2.0
        svg.add(
          @svg.rect(
            mid.x - label_width / 2.0,
            mid.y - label_height / 2.0,
            label_width,
            label_height,
            fill="white",
            stroke="none",
            rx=3.0,
            ry=3.0,
          ),
        )
        svg.add(
          @svg.text(
            mid.x,
            mid.y,
            edge.label,
            font_family=config.font_family,
            font_size=config.font_size - 2,
          ),
        )
      }
      None => ()
    }
  }
}
