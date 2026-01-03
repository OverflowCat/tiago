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
  // Add arrow markers for all arrowhead types
  add_arrowhead_markers(svg, config)
  // Add fill patterns
  add_fill_patterns(svg, graph, config)
  // Add sketch filter if needed
  add_sketch_filter(svg, graph)
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
/// Add all arrowhead marker definitions to the SVG
fn add_arrowhead_markers(svg : @svg.Svg, config : SvgConfig) -> Unit {
  let size = config.arrow_size
  let stroke = config.default_stroke
  // Triangle (default arrow)
  svg.add_def(@svg.arrow_marker("arrow-triangle", size, stroke))
  svg.add_def(
    @svg.arrow_marker("arrow-triangle-reverse", size, stroke, reverse=true),
  )
  // Diamond
  svg.add_def(@svg.diamond_marker("arrow-diamond", size, stroke))
  svg.add_def(
    @svg.diamond_marker("arrow-diamond-reverse", size, stroke, reverse=true),
  )
  // Circle
  svg.add_def(@svg.circle_marker("arrow-circle", size, stroke))
  svg.add_def(
    @svg.circle_marker("arrow-circle-reverse", size, stroke, reverse=true),
  )
  // Crow's foot: one
  svg.add_def(@svg.cf_one_marker("arrow-cf-one", size, stroke))
  svg.add_def(
    @svg.cf_one_marker("arrow-cf-one-reverse", size, stroke, reverse=true),
  )
  // Crow's foot: many
  svg.add_def(@svg.cf_many_marker("arrow-cf-many", size, stroke))
  svg.add_def(
    @svg.cf_many_marker("arrow-cf-many-reverse", size, stroke, reverse=true),
  )
  // Crow's foot: one-required
  svg.add_def(
    @svg.cf_one_required_marker("arrow-cf-one-required", size, stroke),
  )
  svg.add_def(
    @svg.cf_one_required_marker(
      "arrow-cf-one-required-reverse",
      size,
      stroke,
      reverse=true,
    ),
  )
  // Crow's foot: many-required
  svg.add_def(
    @svg.cf_many_required_marker("arrow-cf-many-required", size, stroke),
  )
  svg.add_def(
    @svg.cf_many_required_marker(
      "arrow-cf-many-required-reverse",
      size,
      stroke,
      reverse=true,
    ),
  )
  // Crow's foot: one-optional
  svg.add_def(
    @svg.cf_one_optional_marker("arrow-cf-one-optional", size, stroke),
  )
  svg.add_def(
    @svg.cf_one_optional_marker(
      "arrow-cf-one-optional-reverse",
      size,
      stroke,
      reverse=true,
    ),
  )
  // Crow's foot: many-optional
  svg.add_def(
    @svg.cf_many_optional_marker("arrow-cf-many-optional", size, stroke),
  )
  svg.add_def(
    @svg.cf_many_optional_marker(
      "arrow-cf-many-optional-reverse",
      size,
      stroke,
      reverse=true,
    ),
  )
  // Line terminator
  svg.add_def(@svg.line_marker("arrow-line", size, stroke))
  svg.add_def(
    @svg.line_marker("arrow-line-reverse", size, stroke, reverse=true),
  )
  // Open triangle
  svg.add_def(@svg.open_marker("arrow-open", size, stroke))
  svg.add_def(
    @svg.open_marker("arrow-open-reverse", size, stroke, reverse=true),
  )
  // Aliases for backward compatibility
  svg.add_def(@svg.arrow_marker("arrow", size, stroke))
  svg.add_def(@svg.arrow_marker("arrow-reverse", size, stroke, reverse=true))
}

///|
/// Add fill pattern definitions based on patterns used in the graph
fn add_fill_patterns(svg : @svg.Svg, graph : Graph, config : SvgConfig) -> Unit {
  // Collect unique patterns used
  let patterns_used : @hashset.HashSet[String] = @hashset.new()
  for obj in graph.objects {
    if obj.style.fill_pattern is Some(p) {
      patterns_used.add(p)
    }
  }
  // Add pattern definitions for each used pattern
  let stroke_color = config.default_stroke
  let bg_color = config.default_fill
  for pattern in patterns_used {
    match pattern.to_lower() {
      "dots" =>
        svg.add_def(@svg.dots_pattern("pattern-dots", stroke_color, bg_color))
      "lines" =>
        svg.add_def(@svg.lines_pattern("pattern-lines", stroke_color, bg_color))
      "cross-hatch" | "crosshatch" =>
        svg.add_def(
          @svg.crosshatch_pattern("pattern-crosshatch", stroke_color, bg_color),
        )
      "grain" =>
        svg.add_def(@svg.grain_pattern("pattern-grain", stroke_color, bg_color))
      _ => ()
    }
  }
}

///|
/// Add sketch filter if any object uses sketch mode
fn add_sketch_filter(svg : @svg.Svg, graph : Graph) -> Unit {
  // Check if any object uses sketch mode
  let mut needs_sketch = false
  for obj in graph.objects {
    if obj.style.sketch is Some(true) {
      needs_sketch = true
      break
    }
  }
  // Also check edges
  if not(needs_sketch) {
    for edge in graph.edges {
      if edge.style.sketch is Some(true) {
        needs_sketch = true
        break
      }
    }
  }
  if needs_sketch {
    svg.add_def(@svg.sketch_filter("sketch-filter"))
  }
}

///|
/// Get the marker URL for an arrowhead type
fn get_marker_url(arrowhead : String, reverse : Bool) -> String {
  let base = match arrowhead.to_lower() {
    "triangle" | "arrow" => "arrow-triangle"
    "diamond" => "arrow-diamond"
    "circle" => "arrow-circle"
    "cf-one" => "arrow-cf-one"
    "cf-many" => "arrow-cf-many"
    "cf-one-required" => "arrow-cf-one-required"
    "cf-many-required" => "arrow-cf-many-required"
    "cf-one-optional" => "arrow-cf-one-optional"
    "cf-many-optional" => "arrow-cf-many-optional"
    "line" => "arrow-line"
    "open" => "arrow-open"
    "none" => return ""
    _ => "arrow-triangle" // default
  }
  let id = if reverse { "\{base}-reverse" } else { base }
  "url(#\{id})"
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
  // Apply sketch filter if enabled
  let use_sketch = obj.style.sketch is Some(true)
  if use_sketch {
    svg.open_group_with_filter("sketch-filter")
  }
  // Get style values
  let base_fill = match obj.style.fill {
    Some(f) => f
    None => config.default_fill
  }
  // Apply fill pattern if specified
  let fill = match obj.style.fill_pattern {
    Some(p) =>
      match p.to_lower() {
        "dots" => "url(#pattern-dots)"
        "lines" => "url(#pattern-lines)"
        "cross-hatch" | "crosshatch" => "url(#pattern-crosshatch)"
        "grain" => "url(#pattern-grain)"
        _ => base_fill
      }
    None => base_fill
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
    "text" =>
      // Text shape - no border, just the label
      ()
    "image" => {
      // Image shape - render external image
      if obj.icon is Some(url) {
        svg.add(
          "<image href=\"\{@svg.escape_xml(url)}\" x=\"\{box.x}\" y=\"\{box.y}\" width=\"\{box.width}\" height=\"\{box.height}\" preserveAspectRatio=\"xMidYMid meet\"/>",
        )
      }
      return // Don't render the default label for image shape
    }
    "code" => {
      // Code shape - monospace text with dark background
      render_svg_code(svg, box, obj.label, fill, stroke, stroke_width, config)
      return // Don't render the default label
    }
    "class" => {
      // UML class shape with sections for name, fields, methods
      render_svg_class(svg, box, obj.label, fill, stroke, stroke_width, config)
      return // Don't render the default label
    }
    "sql_table" => {
      // SQL table shape with header and columns
      render_svg_sql_table(
        svg,
        box,
        obj.label,
        fill,
        stroke,
        stroke_width,
        config,
      )
      return // Don't render the default label
    }
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
    "c4_person" =>
      render_svg_c4_person(
        svg,
        box,
        obj.label,
        fill,
        stroke,
        stroke_width,
        config,
      )
    "c4_container" =>
      render_svg_c4_container(
        svg,
        box,
        obj.label,
        fill,
        stroke,
        stroke_width,
        config,
      )
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
  // Add double border if specified
  if obj.style.double_border is Some(true) {
    let inset = 4.0 // Gap between inner and outer border
    svg.add(
      @svg.rect(
        box.x + inset,
        box.y + inset,
        box.width - inset * 2.0,
        box.height - inset * 2.0,
        fill="none",
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
    // Use custom font-family if specified in style, otherwise use config
    let font_family = match obj.style.font_family {
      Some(f) => f
      None => config.font_family
    }
    // Get text-transform if specified
    let text_transform = match obj.style.text_transform {
      Some(t) => t
      None => ""
    }
    svg.add(
      @svg.styled_text(
        cx,
        cy,
        obj.label,
        font_family~,
        font_size=config.font_size,
        text_transform~,
      ),
    )
  }
  // Close sketch filter group if opened
  if use_sketch {
    svg.close_group()
  }
}

///|
fn render_svg_sql_table(
  svg : @svg.Svg,
  box : Box,
  label : String,
  fill : String,
  stroke : String,
  stroke_width : Double,
  config : SvgConfig,
) -> Unit {
  let line_height = config.font_size.to_double() + 4.0
  let padding = 8.0
  let header_bg = "#4a5568" // Darker header
  let header_fg = "#ffffff"
  // Parse label into table name and columns
  let lines = split_lines(label)
  let table_name = if lines.length() > 0 { lines[0] } else { "" }
  // Draw main rectangle
  svg.add(
    @svg.rect(
      box.x,
      box.y,
      box.width,
      box.height,
      fill~,
      stroke~,
      stroke_width~,
    ),
  )
  // Draw header background
  let header_height = line_height + padding
  svg.add(
    @svg.rect(
      box.x,
      box.y,
      box.width,
      header_height,
      fill=header_bg,
      stroke~,
      stroke_width~,
    ),
  )
  // Draw table name (bold, centered, white)
  let name_y = box.y + header_height / 2.0
  svg.add(
    "<text x=\"\{box.x + box.width / 2.0}\" y=\"\{name_y}\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\{config.font_family}\" font-size=\"\{config.font_size}\" font-weight=\"bold\" fill=\"\{header_fg}\">\{@svg.escape_xml(table_name)}</text>",
  )
  // Draw columns
  let mut current_y = box.y + header_height + line_height * 0.7
  for i = 1; i < lines.length(); i = i + 1 {
    let col = lines[i]
    if col.length() > 0 && current_y < box.y + box.height - padding {
      // Check for PK/FK markers
      let is_pk = col.contains("PK") || col.contains("pk")
      let font_weight = if is_pk { "font-weight=\"bold\"" } else { "" }
      svg.add(
        "<text x=\"\{box.x + padding}\" y=\"\{current_y}\" text-anchor=\"start\" dominant-baseline=\"middle\" font-family=\"\{config.font_family}\" font-size=\"\{config.font_size - 1}\" \{font_weight}>\{@svg.escape_xml(col)}</text>",
      )
      current_y = current_y + line_height
    }
  }
}

///|
fn render_svg_class(
  svg : @svg.Svg,
  box : Box,
  label : String,
  fill : String,
  stroke : String,
  stroke_width : Double,
  config : SvgConfig,
) -> Unit {
  let line_height = config.font_size.to_double() + 4.0
  let padding = 8.0
  // Parse label into sections: name, fields, methods
  let lines = split_lines(label)
  let class_name = if lines.length() > 0 { lines[0] } else { "" }
  // Draw main rectangle
  svg.add(
    @svg.rect(
      box.x,
      box.y,
      box.width,
      box.height,
      fill~,
      stroke~,
      stroke_width~,
    ),
  )
  // Draw class name (bold, centered)
  let name_y = box.y + padding + line_height * 0.5
  svg.add(
    "<text x=\"\{box.x + box.width / 2.0}\" y=\"\{name_y}\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\{config.font_family}\" font-size=\"\{config.font_size}\" font-weight=\"bold\">\{@svg.escape_xml(class_name)}</text>",
  )
  // Draw separator line after class name
  let sep1_y = box.y + padding + line_height
  svg.add(
    @svg.line(box.x, sep1_y, box.x + box.width, sep1_y, stroke~, stroke_width~),
  )
  // Collect fields (start with +, -, #) and methods (contain parentheses)
  let fields : Array[String] = []
  let methods : Array[String] = []
  for i = 1; i < lines.length(); i = i + 1 {
    let line = lines[i]
    if line.contains("(") {
      methods.push(line)
    } else if line.length() > 0 {
      fields.push(line)
    }
  }
  // Draw fields
  let mut current_y = sep1_y + line_height * 0.7
  for field in fields {
    if current_y < box.y + box.height - padding {
      svg.add(
        "<text x=\"\{box.x + padding}\" y=\"\{current_y}\" text-anchor=\"start\" dominant-baseline=\"middle\" font-family=\"\{config.font_family}\" font-size=\"\{config.font_size - 1}\">\{@svg.escape_xml(field)}</text>",
      )
      current_y = current_y + line_height
    }
  }
  // Draw separator before methods if there are both fields and methods
  if fields.length() > 0 && methods.length() > 0 {
    let sep2_y = sep1_y + (fields.length().to_double() + 0.5) * line_height
    if sep2_y < box.y + box.height - padding {
      svg.add(
        @svg.line(
          box.x,
          sep2_y,
          box.x + box.width,
          sep2_y,
          stroke~,
          stroke_width~,
        ),
      )
      current_y = sep2_y + line_height * 0.7
    }
  }
  // Draw methods
  for m in methods {
    if current_y < box.y + box.height - padding {
      svg.add(
        "<text x=\"\{box.x + padding}\" y=\"\{current_y}\" text-anchor=\"start\" dominant-baseline=\"middle\" font-family=\"\{config.font_family}\" font-size=\"\{config.font_size - 1}\">\{@svg.escape_xml(m)}</text>",
      )
      current_y = current_y + line_height
    }
  }
}

///|
fn render_svg_code(
  svg : @svg.Svg,
  box : Box,
  label : String,
  _fill : String,
  stroke : String,
  stroke_width : Double,
  config : SvgConfig,
) -> Unit {
  // Dark background for code block
  let code_bg = "#1e1e1e"
  let code_fg = "#d4d4d4"
  let padding = 8.0
  let line_height = 16.0
  // Draw background rectangle with rounded corners
  svg.add(
    @svg.rect(
      box.x,
      box.y,
      box.width,
      box.height,
      fill=code_bg,
      stroke~,
      stroke_width~,
      rx=4.0,
      ry=4.0,
    ),
  )
  // Split label into lines and render each
  let lines = split_lines(label)
  let start_y = box.y + padding + line_height * 0.8
  for i, line in lines {
    let y = start_y + i.to_double() * line_height
    if y < box.y + box.height - padding {
      svg.add(
        "<text x=\"\{box.x + padding}\" y=\"\{y}\" fill=\"\{code_fg}\" font-family=\"'SF Mono', 'Fira Code', 'Consolas', monospace\" font-size=\"\{config.font_size - 2}\" text-anchor=\"start\" dominant-baseline=\"middle\">\{@svg.escape_xml(line)}</text>",
      )
    }
  }
}

///|
fn split_lines(s : String) -> Array[String] {
  let lines : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == '\n' {
      lines.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  let last = current.to_string()
  if last.length() > 0 || lines.length() == 0 {
    lines.push(last)
  }
  lines
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
  // Apply sketch filter if enabled
  let use_sketch = edge.style.sketch is Some(true)
  if use_sketch {
    svg.open_group_with_filter("sketch-filter")
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
  // Determine markers based on arrowhead types
  let marker_end = get_marker_url(edge.dst_arrowhead, false)
  let marker_start = get_marker_url(edge.src_arrowhead, true)
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
  // Close sketch filter group if opened
  if use_sketch {
    svg.close_group()
  }
}

///|
/// Render C4 Person shape - person icon with label below
fn render_svg_c4_person(
  svg : @svg.Svg,
  box : Box,
  label : String,
  fill : String,
  stroke : String,
  stroke_width : Double,
  config : SvgConfig,
) -> Unit {
  let cx = box.x + box.width / 2.0
  // Person icon takes top 60%, label takes bottom 40%
  let icon_height = box.height * 0.6
  let label_height = box.height * 0.4
  // Head
  let head_r = icon_height * 0.25
  let head_cy = box.y + head_r + 5.0
  svg.add(@svg.circle(cx, head_cy, head_r, fill~, stroke~, stroke_width~))
  // Body (rounded rectangle representing torso)
  let body_width = box.width * 0.5
  let body_height = icon_height * 0.45
  let body_top = head_cy + head_r + 5.0
  svg.add(
    @svg.rect(
      cx - body_width / 2.0,
      body_top,
      body_width,
      body_height,
      fill~,
      stroke~,
      stroke_width~,
      rx=8.0,
      ry=8.0,
    ),
  )
  // Label below the icon
  let label_y = box.y + icon_height + label_height / 2.0
  svg.add(
    @svg.text(
      cx,
      label_y,
      label,
      font_family=config.font_family,
      font_size=config.font_size,
    ),
  )
}

///|
/// Render C4 Container shape - rounded rect with technology label
fn render_svg_c4_container(
  svg : @svg.Svg,
  box : Box,
  label : String,
  fill : String,
  stroke : String,
  stroke_width : Double,
  config : SvgConfig,
) -> Unit {
  // Main container rectangle with rounded corners
  let corner_radius = 10.0
  svg.add(
    @svg.rect(
      box.x,
      box.y,
      box.width,
      box.height,
      fill~,
      stroke~,
      stroke_width~,
      rx=corner_radius,
      ry=corner_radius,
    ),
  )
  // Parse label for name and technology
  let lines = split_lines(label)
  let name = if lines.length() > 0 { lines[0] } else { label }
  let tech = if lines.length() > 1 { lines[1] } else { "" }
  // Container name (centered)
  let name_y = box.y + box.height / 2.0
  svg.add(
    @svg.text(
      box.x + box.width / 2.0,
      name_y,
      name,
      font_family=config.font_family,
      font_size=config.font_size,
    ),
  )
  // Technology label below name (smaller, in brackets)
  if tech != "" {
    svg.add(
      @svg.styled_text(
        box.x + box.width / 2.0,
        name_y + config.font_size.to_double() + 5.0,
        "[\{tech}]",
        font_family=config.font_family,
        font_size=config.font_size - 2,
        extra_style="fill: #666666",
      ),
    )
  }
}
