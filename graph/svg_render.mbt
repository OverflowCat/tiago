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
} derive(Show)

///|
pub fn SvgConfig::new() -> SvgConfig {
  {
    padding: 20.0,
    font_family: "Arial, sans-serif",
    font_size: 14,
    background: "#ffffff",
    default_stroke: "#333333",
    default_fill: "#ffffff",
    default_stroke_width: 2.0,
    arrow_size: 10.0,
  }
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
