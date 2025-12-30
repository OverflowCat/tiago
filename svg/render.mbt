///|
/// SVG Renderer for D2 diagrams
///
/// Converts a laid-out Graph to SVG markup.

///|
/// SVG rendering configuration
pub struct RenderConfig {
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
pub fn RenderConfig::new() -> RenderConfig {
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
pub fn render(graph : @graph.Graph, config : RenderConfig) -> String {
  let sb = StringBuilder::new()
  // Calculate viewbox
  let bounds = compute_bounds(graph, config)
  // SVG header
  sb.write_string("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_string("<svg xmlns=\"http://www.w3.org/2000/svg\" ")
  sb.write_string("width=\"")
  sb.write_string(bounds.width.to_string())
  sb.write_string("\" height=\"")
  sb.write_string(bounds.height.to_string())
  sb.write_string("\" viewBox=\"0 0 ")
  sb.write_string(bounds.width.to_string())
  sb.write_string(" ")
  sb.write_string(bounds.height.to_string())
  sb.write_string("\">\n")
  // Definitions (markers for arrows)
  render_defs(sb, config)
  // Background
  sb.write_string("<rect width=\"100%\" height=\"100%\" fill=\"")
  sb.write_string(config.background)
  sb.write_string("\"/>\n")
  // Main content group
  sb.write_string("<g transform=\"translate(")
  sb.write_string(config.padding.to_string())
  sb.write_string(",")
  sb.write_string(config.padding.to_string())
  sb.write_string(")\">\n")
  // Render edges first (so they appear behind objects)
  for edge in graph.edges {
    render_edge(sb, edge, config)
  }
  // Render objects
  for obj in graph.objects {
    render_object(sb, obj, config)
  }
  sb.write_string("</g>\n")
  sb.write_string("</svg>")
  sb.to_string()
}

///|
/// Compute the bounding box of the entire graph
fn compute_bounds(graph : @graph.Graph, config : RenderConfig) -> @graph.Box {
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
  let width = max_x + config.padding * 2.0
  let height = max_y + config.padding * 2.0
  @graph.Box::new(0.0, 0.0, width, height)
}

///|
/// Render SVG definitions (markers)
fn render_defs(sb : StringBuilder, config : RenderConfig) -> Unit {
  sb.write_string("<defs>\n")
  // Arrow marker for edges
  sb.write_string("<marker id=\"arrow\" markerWidth=\"")
  sb.write_string(config.arrow_size.to_string())
  sb.write_string("\" markerHeight=\"")
  sb.write_string(config.arrow_size.to_string())
  sb.write_string("\" refX=\"")
  sb.write_string(config.arrow_size.to_string())
  sb.write_string("\" refY=\"")
  sb.write_string((config.arrow_size / 2.0).to_string())
  sb.write_string("\" orient=\"auto\" markerUnits=\"strokeWidth\">\n")
  sb.write_string("<path d=\"M0,0 L")
  sb.write_string(config.arrow_size.to_string())
  sb.write_string(",")
  sb.write_string((config.arrow_size / 2.0).to_string())
  sb.write_string(" L0,")
  sb.write_string(config.arrow_size.to_string())
  sb.write_string(" Z\" fill=\"")
  sb.write_string(config.default_stroke)
  sb.write_string("\"/>\n")
  sb.write_string("</marker>\n")
  // Reverse arrow marker
  sb.write_string("<marker id=\"arrow-reverse\" markerWidth=\"")
  sb.write_string(config.arrow_size.to_string())
  sb.write_string("\" markerHeight=\"")
  sb.write_string(config.arrow_size.to_string())
  sb.write_string("\" refX=\"0\" refY=\"")
  sb.write_string((config.arrow_size / 2.0).to_string())
  sb.write_string("\" orient=\"auto\" markerUnits=\"strokeWidth\">\n")
  sb.write_string("<path d=\"M")
  sb.write_string(config.arrow_size.to_string())
  sb.write_string(",0 L0,")
  sb.write_string((config.arrow_size / 2.0).to_string())
  sb.write_string(" L")
  sb.write_string(config.arrow_size.to_string())
  sb.write_string(",")
  sb.write_string(config.arrow_size.to_string())
  sb.write_string(" Z\" fill=\"")
  sb.write_string(config.default_stroke)
  sb.write_string("\"/>\n")
  sb.write_string("</marker>\n")
  sb.write_string("</defs>\n")
}

///|
/// Render a single object
fn render_object(
  sb : StringBuilder,
  obj : @graph.Object,
  config : RenderConfig,
) -> Unit {
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
  // Render shape based on type
  match obj.shape {
    "circle" | "oval" => render_circle(sb, box, fill, stroke, stroke_width)
    "cylinder" => render_cylinder(sb, box, fill, stroke, stroke_width)
    "diamond" => render_diamond(sb, box, fill, stroke, stroke_width)
    "hexagon" => render_hexagon(sb, box, fill, stroke, stroke_width)
    _ => render_rectangle(sb, box, fill, stroke, stroke_width, obj.style)
  }
  // Render label
  render_label(sb, obj.label, box, config)
}

///|
/// Render a rectangle shape
fn render_rectangle(
  sb : StringBuilder,
  box : @graph.Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
  style : @graph.Style,
) -> Unit {
  sb.write_string("<rect x=\"")
  sb.write_string(box.x.to_string())
  sb.write_string("\" y=\"")
  sb.write_string(box.y.to_string())
  sb.write_string("\" width=\"")
  sb.write_string(box.width.to_string())
  sb.write_string("\" height=\"")
  sb.write_string(box.height.to_string())
  sb.write_string("\"")
  // Border radius
  match style.border_radius {
    Some(r) => {
      sb.write_string(" rx=\"")
      sb.write_string(r.to_string())
      sb.write_string("\" ry=\"")
      sb.write_string(r.to_string())
      sb.write_string("\"")
    }
    None => ()
  }
  sb.write_string(" fill=\"")
  sb.write_string(fill)
  sb.write_string("\" stroke=\"")
  sb.write_string(stroke)
  sb.write_string("\" stroke-width=\"")
  sb.write_string(stroke_width.to_string())
  sb.write_string("\"/>\n")
}

///|
/// Render a circle/oval shape
fn render_circle(
  sb : StringBuilder,
  box : @graph.Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let cx = box.x + box.width / 2.0
  let cy = box.y + box.height / 2.0
  let rx = box.width / 2.0
  let ry = box.height / 2.0
  sb.write_string("<ellipse cx=\"")
  sb.write_string(cx.to_string())
  sb.write_string("\" cy=\"")
  sb.write_string(cy.to_string())
  sb.write_string("\" rx=\"")
  sb.write_string(rx.to_string())
  sb.write_string("\" ry=\"")
  sb.write_string(ry.to_string())
  sb.write_string("\" fill=\"")
  sb.write_string(fill)
  sb.write_string("\" stroke=\"")
  sb.write_string(stroke)
  sb.write_string("\" stroke-width=\"")
  sb.write_string(stroke_width.to_string())
  sb.write_string("\"/>\n")
}

///|
/// Render a cylinder shape (for databases)
fn render_cylinder(
  sb : StringBuilder,
  box : @graph.Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let cap_height = box.height * 0.15
  // Body path
  sb.write_string("<path d=\"")
  // Start at top-left
  sb.write_string("M ")
  sb.write_string(box.x.to_string())
  sb.write_string(" ")
  sb.write_string((box.y + cap_height).to_string())
  // Top ellipse arc
  sb.write_string(" A ")
  sb.write_string((box.width / 2.0).to_string())
  sb.write_string(" ")
  sb.write_string(cap_height.to_string())
  sb.write_string(" 0 1 1 ")
  sb.write_string((box.x + box.width).to_string())
  sb.write_string(" ")
  sb.write_string((box.y + cap_height).to_string())
  // Right side down
  sb.write_string(" L ")
  sb.write_string((box.x + box.width).to_string())
  sb.write_string(" ")
  sb.write_string((box.y + box.height - cap_height).to_string())
  // Bottom ellipse arc
  sb.write_string(" A ")
  sb.write_string((box.width / 2.0).to_string())
  sb.write_string(" ")
  sb.write_string(cap_height.to_string())
  sb.write_string(" 0 1 1 ")
  sb.write_string(box.x.to_string())
  sb.write_string(" ")
  sb.write_string((box.y + box.height - cap_height).to_string())
  // Close path
  sb.write_string(" Z\" fill=\"")
  sb.write_string(fill)
  sb.write_string("\" stroke=\"")
  sb.write_string(stroke)
  sb.write_string("\" stroke-width=\"")
  sb.write_string(stroke_width.to_string())
  sb.write_string("\"/>\n")
  // Top cap ellipse
  sb.write_string("<ellipse cx=\"")
  sb.write_string((box.x + box.width / 2.0).to_string())
  sb.write_string("\" cy=\"")
  sb.write_string((box.y + cap_height).to_string())
  sb.write_string("\" rx=\"")
  sb.write_string((box.width / 2.0).to_string())
  sb.write_string("\" ry=\"")
  sb.write_string(cap_height.to_string())
  sb.write_string("\" fill=\"")
  sb.write_string(fill)
  sb.write_string("\" stroke=\"")
  sb.write_string(stroke)
  sb.write_string("\" stroke-width=\"")
  sb.write_string(stroke_width.to_string())
  sb.write_string("\"/>\n")
}

///|
/// Render a diamond shape
fn render_diamond(
  sb : StringBuilder,
  box : @graph.Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let cx = box.x + box.width / 2.0
  let cy = box.y + box.height / 2.0
  sb.write_string("<polygon points=\"")
  sb.write_string(cx.to_string())
  sb.write_string(",")
  sb.write_string(box.y.to_string())
  sb.write_string(" ")
  sb.write_string((box.x + box.width).to_string())
  sb.write_string(",")
  sb.write_string(cy.to_string())
  sb.write_string(" ")
  sb.write_string(cx.to_string())
  sb.write_string(",")
  sb.write_string((box.y + box.height).to_string())
  sb.write_string(" ")
  sb.write_string(box.x.to_string())
  sb.write_string(",")
  sb.write_string(cy.to_string())
  sb.write_string("\" fill=\"")
  sb.write_string(fill)
  sb.write_string("\" stroke=\"")
  sb.write_string(stroke)
  sb.write_string("\" stroke-width=\"")
  sb.write_string(stroke_width.to_string())
  sb.write_string("\"/>\n")
}

///|
/// Render a hexagon shape
fn render_hexagon(
  sb : StringBuilder,
  box : @graph.Box,
  fill : String,
  stroke : String,
  stroke_width : Double,
) -> Unit {
  let inset = box.width * 0.25
  sb.write_string("<polygon points=\"")
  // Top edge
  sb.write_string((box.x + inset).to_string())
  sb.write_string(",")
  sb.write_string(box.y.to_string())
  sb.write_string(" ")
  sb.write_string((box.x + box.width - inset).to_string())
  sb.write_string(",")
  sb.write_string(box.y.to_string())
  sb.write_string(" ")
  // Right side
  sb.write_string((box.x + box.width).to_string())
  sb.write_string(",")
  sb.write_string((box.y + box.height / 2.0).to_string())
  sb.write_string(" ")
  // Bottom edge
  sb.write_string((box.x + box.width - inset).to_string())
  sb.write_string(",")
  sb.write_string((box.y + box.height).to_string())
  sb.write_string(" ")
  sb.write_string((box.x + inset).to_string())
  sb.write_string(",")
  sb.write_string((box.y + box.height).to_string())
  sb.write_string(" ")
  // Left side
  sb.write_string(box.x.to_string())
  sb.write_string(",")
  sb.write_string((box.y + box.height / 2.0).to_string())
  sb.write_string("\" fill=\"")
  sb.write_string(fill)
  sb.write_string("\" stroke=\"")
  sb.write_string(stroke)
  sb.write_string("\" stroke-width=\"")
  sb.write_string(stroke_width.to_string())
  sb.write_string("\"/>\n")
}

///|
/// Render a text label centered in a box
fn render_label(
  sb : StringBuilder,
  label : String,
  box : @graph.Box,
  config : RenderConfig,
) -> Unit {
  if label == "" {
    return
  }
  let cx = box.x + box.width / 2.0
  let cy = box.y + box.height / 2.0
  sb.write_string("<text x=\"")
  sb.write_string(cx.to_string())
  sb.write_string("\" y=\"")
  sb.write_string(cy.to_string())
  sb.write_string(
    "\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"",
  )
  sb.write_string(config.font_family)
  sb.write_string("\" font-size=\"")
  sb.write_string(config.font_size.to_string())
  sb.write_string("\">")
  sb.write_string(escape_xml(label))
  sb.write_string("</text>\n")
}

///|
/// Render an edge
fn render_edge(
  sb : StringBuilder,
  edge : @graph.Edge,
  config : RenderConfig,
) -> Unit {
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
  sb.write_string("<path d=\"M ")
  for i, point in edge.route {
    if i > 0 {
      sb.write_string(" L ")
    }
    sb.write_string(point.x.to_string())
    sb.write_string(" ")
    sb.write_string(point.y.to_string())
  }
  sb.write_string("\" fill=\"none\" stroke=\"")
  sb.write_string(stroke)
  sb.write_string("\" stroke-width=\"")
  sb.write_string(stroke_width.to_string())
  sb.write_string("\"")
  // Add arrow markers
  if edge.dst_arrow {
    sb.write_string(" marker-end=\"url(#arrow)\"")
  }
  if edge.src_arrow {
    sb.write_string(" marker-start=\"url(#arrow-reverse)\"")
  }
  // Animated dash
  match edge.style.animated {
    Some(true) => {
      sb.write_string(" stroke-dasharray=\"5,5\"")
      sb.write_string(" class=\"animated-edge\"")
    }
    _ => ()
  }
  sb.write_string("/>\n")
  // Render edge label
  if edge.label != "" {
    match edge.midpoint() {
      Some(mid) => render_edge_label(sb, edge.label, mid, config)
      None => ()
    }
  }
}

///|
/// Render an edge label at a given position
fn render_edge_label(
  sb : StringBuilder,
  label : String,
  pos : @graph.Point,
  config : RenderConfig,
) -> Unit {
  // Background for label
  let padding = 4.0
  let label_width = label.length().to_double() * 7.0 + padding * 2.0
  let label_height = config.font_size.to_double() + padding * 2.0
  sb.write_string("<rect x=\"")
  sb.write_string((pos.x - label_width / 2.0).to_string())
  sb.write_string("\" y=\"")
  sb.write_string((pos.y - label_height / 2.0).to_string())
  sb.write_string("\" width=\"")
  sb.write_string(label_width.to_string())
  sb.write_string("\" height=\"")
  sb.write_string(label_height.to_string())
  sb.write_string("\" fill=\"white\" rx=\"3\" ry=\"3\"/>\n")
  // Label text
  sb.write_string("<text x=\"")
  sb.write_string(pos.x.to_string())
  sb.write_string("\" y=\"")
  sb.write_string(pos.y.to_string())
  sb.write_string(
    "\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"",
  )
  sb.write_string(config.font_family)
  sb.write_string("\" font-size=\"")
  sb.write_string((config.font_size - 2).to_string())
  sb.write_string("\">")
  sb.write_string(escape_xml(label))
  sb.write_string("</text>\n")
}

///|
/// Escape special XML characters
fn escape_xml(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    match c {
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '&' => sb.write_string("&amp;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&#39;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}
