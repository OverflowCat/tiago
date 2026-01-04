///|
/// SVG Renderer for Graph
///
/// Renders a laid-out Graph to SVG using the pure svg library.

///|
/// Render pass for two-layer rendering
/// Background: shapes, fills, borders (rendered first, behind edges)
/// Foreground: text, labels, content (rendered last, on top of edges)
pub enum RenderPass {
  Background
  Foreground
}

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
  // Check if we have layers, scenarios, or steps
  let has_layers = graph.has_layers()
  let has_scenarios = graph.has_scenarios()
  let has_steps = graph.has_steps()
  // Calculate control bar height
  let control_height = if has_layers || has_scenarios || has_steps {
    40.0
  } else {
    0.0
  }
  // Calculate bounds (include all layers/scenarios/steps for max size)
  let (base_min_x, base_min_y, base_max_x, base_max_y) = compute_graph_bounds(
    graph,
  )
  let mut min_x = base_min_x
  let mut min_y = base_min_y
  let mut max_x = base_max_x
  let mut max_y = base_max_y
  for layer in graph.layers {
    let (lmin_x, lmin_y, lmax_x, lmax_y) = compute_graph_bounds(layer.graph)
    if lmin_x < min_x {
      min_x = lmin_x
    }
    if lmin_y < min_y {
      min_y = lmin_y
    }
    if lmax_x > max_x {
      max_x = lmax_x
    }
    if lmax_y > max_y {
      max_y = lmax_y
    }
  }
  for scenario in graph.scenarios {
    let (smin_x, smin_y, smax_x, smax_y) = compute_graph_bounds(scenario.graph)
    if smin_x < min_x {
      min_x = smin_x
    }
    if smin_y < min_y {
      min_y = smin_y
    }
    if smax_x > max_x {
      max_x = smax_x
    }
    if smax_y > max_y {
      max_y = smax_y
    }
  }
  for step in graph.steps {
    let (smin_x, smin_y, smax_x, smax_y) = compute_graph_bounds(step.graph)
    if smin_x < min_x {
      min_x = smin_x
    }
    if smin_y < min_y {
      min_y = smin_y
    }
    if smax_x > max_x {
      max_x = smax_x
    }
    if smax_y > max_y {
      max_y = smax_y
    }
  }
  // Calculate dimensions accounting for negative coordinates
  let content_width = max_x - min_x
  let content_height = max_y - min_y
  let width = content_width + config.padding * 2.0
  let height = content_height + config.padding * 2.0 + control_height
  // Calculate offset to shift content into positive coordinate space
  let offset_x = config.padding - min_x
  let offset_y = config.padding + control_height - min_y
  // Create SVG document
  let svg = @svg.Svg::new(width, height)
  // Get theme for special rules
  let theme = @themes.get_theme(config.theme_id)
  // Add arrow markers for all arrowhead types
  add_arrowhead_markers(svg, config)
  // Add fill patterns
  add_fill_patterns(svg, graph, config)
  // Add sketch filter if needed
  add_sketch_filter(svg, graph)
  // Background
  svg.add(@svg.background(config.background))
  // Render control bar based on what's present
  if has_layers {
    render_layer_tabs(svg, graph, config)
  } else if has_scenarios {
    render_scenario_selector(svg, graph, config)
  } else if has_steps {
    render_step_controls(svg, graph, config)
  }
  // Main content group with offset to shift content into positive coordinate space
  svg.open_group_with_id("base-layer", "translate(\{offset_x},\{offset_y})")
  // Three-pass rendering for all diagrams (sequence diagrams are now format-agnostic)
  // Lifelines are rendered as dashed edges, activation boxes as regular objects
  let sorted_objects = sort_objects_by_depth(graph.objects)
  // Pass 1: Render object backgrounds (shapes, fills, borders)
  for obj in sorted_objects {
    render_svg_object(svg, obj, graph.objects, config, theme, pass=Background)
  }
  // Pass 2: Render edges (on top of backgrounds, behind text)
  for edge in graph.edges {
    render_svg_edge(svg, edge, config, theme)
  }
  // Pass 3: Render object foregrounds (text, labels, content)
  for obj in sorted_objects {
    render_svg_object(svg, obj, graph.objects, config, theme, pass=Foreground)
  }
  // Render sequence diagram notes (using page shape)
  for note in graph.sequence_notes {
    let text = note.1
    let box = note.2
    render_svg_sequence_note(svg, box, text, config)
  }
  // Render sequence diagram fragments (combined fragments like alt, opt, loop)
  render_svg_sequence_fragments(svg, graph, config)
  svg.close_group()
  // Render each layer as a hidden group
  for i, layer in graph.layers {
    let layer_id = "layer-\{i}"
    // Hidden by default (display: none)
    svg.open_group_with_id_style(
      layer_id,
      "translate(\{offset_x},\{offset_y})",
      "display: none",
    )
    // Render layer edges
    for edge in layer.graph.edges {
      render_svg_edge(svg, edge, config, theme)
    }
    // Render layer objects sorted by depth
    let sorted_layer_objects = sort_objects_by_depth(layer.graph.objects)
    for obj in sorted_layer_objects {
      render_svg_object(svg, obj, layer.graph.objects, config, theme)
    }
    svg.close_group()
  }
  // Render each scenario as a hidden group
  for i, scenario in graph.scenarios {
    let scenario_id = "scenario-\{i}"
    svg.open_group_with_id_style(
      scenario_id,
      "translate(\{offset_x},\{offset_y})",
      "display: none",
    )
    for edge in scenario.graph.edges {
      render_svg_edge(svg, edge, config, theme)
    }
    // Render scenario objects sorted by depth
    let sorted_scenario_objects = sort_objects_by_depth(scenario.graph.objects)
    for obj in sorted_scenario_objects {
      render_svg_object(svg, obj, scenario.graph.objects, config, theme)
    }
    svg.close_group()
  }
  // Render each step as a hidden group
  for i, step in graph.steps {
    let step_id = "step-\{i}"
    svg.open_group_with_id_style(
      step_id,
      "translate(\{offset_x},\{offset_y})",
      "display: none",
    )
    for edge in step.graph.edges {
      render_svg_edge(svg, edge, config, theme)
    }
    // Render step objects sorted by depth
    let sorted_step_objects = sort_objects_by_depth(step.graph.objects)
    for obj in sorted_step_objects {
      render_svg_object(svg, obj, step.graph.objects, config, theme)
    }
    svg.close_group()
  }
  // Add JavaScript for controls
  if has_layers {
    add_layer_switch_script(svg, graph.layers.length())
  } else if has_scenarios {
    add_scenario_switch_script(svg, graph.scenarios.length())
  } else if has_steps {
    add_step_control_script(svg, graph.steps.length())
  }
  svg.to_string()
}

///|
/// Estimate text width based on font size and character count
fn estimate_text_width(text : String, font_size : Int) -> Double {
  // Average character width is approximately 0.6 * font_size for proportional fonts
  text.length().to_double() * font_size.to_double() * 0.6
}

///|
/// Render layer tabs at the top of the SVG
fn render_layer_tabs(svg : @svg.Svg, graph : Graph, config : SvgConfig) -> Unit {
  let tab_height = 30.0
  let tab_y = 5.0
  let mut tab_x = config.padding
  let tab_padding = 10.0
  // Base layer tab (selected by default)
  let base_width = estimate_text_width("Base", config.font_size) +
    tab_padding * 2.0
  svg.add(
    @svg.rect(
      tab_x,
      tab_y,
      base_width,
      tab_height,
      fill=config.default_fill,
      stroke=config.default_stroke,
      stroke_width=1.0,
      rx=Some(4.0),
      id=Some("tab-base"),
      class=Some("layer-tab selected"),
      onclick=Some("switchLayer('base-layer', this)"),
    ),
  )
  svg.add(
    @svg.text(
      tab_x + tab_padding,
      tab_y + tab_height / 2.0 + 5.0,
      "Base",
      font_size=config.font_size,
      font_family=config.font_family,
    ),
  )
  tab_x = tab_x + base_width + 5.0
  // Layer tabs
  for i, layer in graph.layers {
    let layer_width = estimate_text_width(layer.name, config.font_size) +
      tab_padding * 2.0
    svg.add(
      @svg.rect(
        tab_x,
        tab_y,
        layer_width,
        tab_height,
        fill="#f0f0f0",
        stroke=config.default_stroke,
        stroke_width=1.0,
        rx=Some(4.0),
        id=Some("tab-layer-\{i}"),
        class=Some("layer-tab"),
        onclick=Some("switchLayer('layer-\{i}', this)"),
      ),
    )
    svg.add(
      @svg.text(
        tab_x + tab_padding,
        tab_y + tab_height / 2.0 + 5.0,
        layer.name,
        font_size=config.font_size,
        font_family=config.font_family,
      ),
    )
    tab_x = tab_x + layer_width + 5.0
  }
}

///|
/// Add JavaScript for layer switching
fn add_layer_switch_script(svg : @svg.Svg, layer_count : Int) -> Unit {
  let mut layer_ids = "['base-layer'"
  for i = 0; i < layer_count; i = i + 1 {
    layer_ids = layer_ids + ", 'layer-\{i}'"
  }
  layer_ids = layer_ids + "]"
  let script = "function switchLayer(layerId, tabEl) {\n" +
    "  var layers = " +
    layer_ids +
    ";\n" +
    "  layers.forEach(function(id) {\n" +
    "    var el = document.getElementById(id);\n" +
    "    if (el) el.style.display = (id === layerId) ? 'block' : 'none';\n" +
    "  });\n" +
    "  var tabs = document.querySelectorAll('.layer-tab');\n" +
    "  tabs.forEach(function(t) {\n" +
    "    t.classList.remove('selected');\n" +
    "    t.style.fill = '#f0f0f0';\n" +
    "  });\n" +
    "  if (tabEl) {\n" +
    "    tabEl.classList.add('selected');\n" +
    "    tabEl.style.fill = '#ffffff';\n" +
    "  }\n" +
    "}"
  svg.add_script(script)
}

///|
/// Render scenario dropdown selector at the top of the SVG
fn render_scenario_selector(
  svg : @svg.Svg,
  graph : Graph,
  config : SvgConfig,
) -> Unit {
  let selector_height = 30.0
  let selector_y = 5.0
  let selector_x = config.padding
  let label_width = estimate_text_width("Scenario:", config.font_size) + 10.0
  // Label
  svg.add(
    @svg.text(
      selector_x + label_width / 2.0,
      selector_y + selector_height / 2.0 + 5.0,
      "Scenario:",
      font_size=config.font_size,
      font_family=config.font_family,
    ),
  )
  // Build option list for dropdown appearance
  let mut options_x = selector_x + label_width + 5.0
  // Base option (selected by default)
  let base_width = estimate_text_width("Base", config.font_size) + 20.0
  svg.add(
    @svg.rect(
      options_x,
      selector_y,
      base_width,
      selector_height,
      fill=config.default_fill,
      stroke=config.default_stroke,
      stroke_width=1.0,
      rx=Some(4.0),
      id=Some("scenario-base"),
      class=Some("scenario-btn selected"),
      onclick=Some("switchScenario('base-layer', this)"),
    ),
  )
  svg.add(
    @svg.text(
      options_x + base_width / 2.0,
      selector_y + selector_height / 2.0 + 5.0,
      "Base",
      font_size=config.font_size - 1,
      font_family=config.font_family,
    ),
  )
  options_x = options_x + base_width + 5.0
  // Scenario options
  for i, scenario in graph.scenarios {
    let btn_width = estimate_text_width(scenario.name, config.font_size) + 20.0
    svg.add(
      @svg.rect(
        options_x,
        selector_y,
        btn_width,
        selector_height,
        fill="#f0f0f0",
        stroke=config.default_stroke,
        stroke_width=1.0,
        rx=Some(4.0),
        id=Some("scenario-btn-\{i}"),
        class=Some("scenario-btn"),
        onclick=Some("switchScenario('scenario-\{i}', this)"),
      ),
    )
    svg.add(
      @svg.text(
        options_x + btn_width / 2.0,
        selector_y + selector_height / 2.0 + 5.0,
        scenario.name,
        font_size=config.font_size - 1,
        font_family=config.font_family,
      ),
    )
    options_x = options_x + btn_width + 5.0
  }
}

///|
/// Add JavaScript for scenario switching
fn add_scenario_switch_script(svg : @svg.Svg, scenario_count : Int) -> Unit {
  let mut scenario_ids = "['base-layer'"
  for i = 0; i < scenario_count; i = i + 1 {
    scenario_ids = scenario_ids + ", 'scenario-\{i}'"
  }
  scenario_ids = scenario_ids + "]"
  let script = "function switchScenario(scenarioId, btnEl) {\n" +
    "  var scenarios = " +
    scenario_ids +
    ";\n" +
    "  scenarios.forEach(function(id) {\n" +
    "    var el = document.getElementById(id);\n" +
    "    if (el) el.style.display = (id === scenarioId) ? 'block' : 'none';\n" +
    "  });\n" +
    "  var btns = document.querySelectorAll('.scenario-btn');\n" +
    "  btns.forEach(function(b) {\n" +
    "    b.classList.remove('selected');\n" +
    "    b.style.fill = '#f0f0f0';\n" +
    "  });\n" +
    "  if (btnEl) {\n" +
    "    btnEl.classList.add('selected');\n" +
    "    btnEl.style.fill = '#ffffff';\n" +
    "  }\n" +
    "}"
  svg.add_script(script)
}

///|
/// Render step timeline controls at the top of the SVG
fn render_step_controls(
  svg : @svg.Svg,
  graph : Graph,
  config : SvgConfig,
) -> Unit {
  let control_height = 30.0
  let control_y = 5.0
  let control_x = config.padding
  let btn_size = 28.0
  // Previous button
  svg.add(
    @svg.rect(
      control_x,
      control_y,
      btn_size,
      control_height,
      fill="#f0f0f0",
      stroke=config.default_stroke,
      stroke_width=1.0,
      rx=Some(4.0),
      id=Some("step-prev"),
      onclick=Some("stepPrev()"),
    ),
  )
  svg.add(
    @svg.text(
      control_x + btn_size / 2.0,
      control_y + control_height / 2.0 + 5.0,
      "<",
      font_size=config.font_size,
      font_family=config.font_family,
    ),
  )
  // Play/Pause button
  svg.add(
    @svg.rect(
      control_x + btn_size + 5.0,
      control_y,
      btn_size,
      control_height,
      fill="#f0f0f0",
      stroke=config.default_stroke,
      stroke_width=1.0,
      rx=Some(4.0),
      id=Some("step-play"),
      onclick=Some("stepTogglePlay()"),
    ),
  )
  svg.add(
    @svg.text(
      control_x + btn_size + 5.0 + btn_size / 2.0,
      control_y + control_height / 2.0 + 5.0,
      ">",
      font_size=config.font_size,
      font_family=config.font_family,
    ),
  )
  // Next button
  svg.add(
    @svg.rect(
      control_x + (btn_size + 5.0) * 2.0,
      control_y,
      btn_size,
      control_height,
      fill="#f0f0f0",
      stroke=config.default_stroke,
      stroke_width=1.0,
      rx=Some(4.0),
      id=Some("step-next"),
      onclick=Some("stepNext()"),
    ),
  )
  svg.add(
    @svg.text(
      control_x + (btn_size + 5.0) * 2.0 + btn_size / 2.0,
      control_y + control_height / 2.0 + 5.0,
      ">",
      font_size=config.font_size,
      font_family=config.font_family,
    ),
  )
  // Step indicator (shows current step)
  let indicator_x = control_x + (btn_size + 5.0) * 3.0 + 10.0
  svg.add(
    @svg.text(
      indicator_x,
      control_y + control_height / 2.0 + 5.0,
      "Step: ",
      font_size=config.font_size,
      font_family=config.font_family,
      text_anchor="start",
    ),
  )
  // Step name indicators
  let step_x = indicator_x + estimate_text_width("Step: ", config.font_size)
  for i, step in graph.steps {
    let step_width = estimate_text_width(step.name, config.font_size) + 16.0
    let style = if i == 0 { "display: block" } else { "display: none" }
    svg.add(
      "<text id=\"step-name-\{i}\" x=\"\{step_x}\" y=\"\{control_y + control_height / 2.0 + 5.0}\" font-family=\"\{config.font_family}\" font-size=\"\{config.font_size}\" text-anchor=\"start\" style=\"\{style}\">\{@svg.escape_xml(step.name)}</text>",
    )
    ignore(step_width)
  }
}

///|
/// Add JavaScript for step animation controls
fn add_step_control_script(svg : @svg.Svg, step_count : Int) -> Unit {
  let script = "var currentStep = 0;\n" +
    "var stepCount = \{step_count};\n" +
    "var isPlaying = false;\n" +
    "var playInterval = null;\n" +
    "function showStep(index) {\n" +
    "  for (var i = 0; i < stepCount; i++) {\n" +
    "    var el = document.getElementById('step-' + i);\n" +
    "    var name = document.getElementById('step-name-' + i);\n" +
    "    if (el) el.style.display = (i === index) ? 'block' : 'none';\n" +
    "    if (name) name.style.display = (i === index) ? 'block' : 'none';\n" +
    "  }\n" +
    "  var base = document.getElementById('base-layer');\n" +
    "  if (base) base.style.display = (index < 0) ? 'block' : 'none';\n" +
    "  currentStep = index;\n" +
    "}\n" +
    "function stepNext() {\n" +
    "  if (currentStep < stepCount - 1) showStep(currentStep + 1);\n" +
    "}\n" +
    "function stepPrev() {\n" +
    "  if (currentStep > 0) showStep(currentStep - 1);\n" +
    "  else showStep(-1);\n" +
    "}\n" +
    "function stepTogglePlay() {\n" +
    "  if (isPlaying) {\n" +
    "    clearInterval(playInterval);\n" +
    "    isPlaying = false;\n" +
    "  } else {\n" +
    "    isPlaying = true;\n" +
    "    playInterval = setInterval(function() {\n" +
    "      if (currentStep < stepCount - 1) stepNext();\n" +
    "      else { showStep(-1); }\n" +
    "    }, 1500);\n" +
    "  }\n" +
    "}\n" +
    "showStep(-1);"
  svg.add_script(script)
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
fn get_marker_url(arrowhead : ArrowheadType, reverse : Bool) -> String {
  arrowhead.marker_url(reverse)
}

///|
fn compute_graph_bounds(graph : Graph) -> (Double, Double, Double, Double) {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  for obj in graph.objects {
    match obj.box {
      Some(b) => {
        let left = b.x
        let top = b.y
        let right = b.x + b.width
        let bottom = b.y + b.height
        if first {
          min_x = left
          min_y = top
          max_x = right
          max_y = bottom
          first = false
        } else {
          if left < min_x {
            min_x = left
          }
          if top < min_y {
            min_y = top
          }
          if right > max_x {
            max_x = right
          }
          if bottom > max_y {
            max_y = bottom
          }
        }
      }
      None => ()
    }
  }
  // Include activation boxes (for sequence diagrams)
  for ab in graph.activation_boxes {
    let b = ab.1
    let left = b.x
    let top = b.y
    let right = b.x + b.width
    let bottom = b.y + b.height
    if first {
      min_x = left
      min_y = top
      max_x = right
      max_y = bottom
      first = false
    } else {
      if left < min_x {
        min_x = left
      }
      if top < min_y {
        min_y = top
      }
      if right > max_x {
        max_x = right
      }
      if bottom > max_y {
        max_y = bottom
      }
    }
  }
  // Include edge routes
  for edge in graph.edges {
    for point in edge.route {
      if first {
        min_x = point.x
        min_y = point.y
        max_x = point.x
        max_y = point.y
        first = false
      } else {
        if point.x < min_x {
          min_x = point.x
        }
        if point.y < min_y {
          min_y = point.y
        }
        if point.x > max_x {
          max_x = point.x
        }
        if point.y > max_y {
          max_y = point.y
        }
      }
    }
  }
  (min_x, min_y, max_x, max_y)
}

///|
/// Get the depth of an object ID (number of dots + 1)
/// e.g., "aws" = 1, "aws.vpc" = 2, "aws.vpc.subnet" = 3
fn get_object_depth(id : String) -> Int {
  let mut depth = 1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      depth = depth + 1
    }
  }
  depth
}

///|
/// Sort objects by depth (parents before children) for proper SVG layering
fn sort_objects_by_depth(objects : Array[Object]) -> Array[Object] {
  let sorted = objects.copy()
  // Simple bubble sort by depth (shallow objects first)
  for i = 0; i < sorted.length(); i = i + 1 {
    for j = i + 1; j < sorted.length(); j = j + 1 {
      let depth_i = get_object_depth(sorted[i].id)
      let depth_j = get_object_depth(sorted[j].id)
      if depth_i > depth_j {
        let temp = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = temp
      }
    }
  }
  sorted
}

///|
/// Check if an object is a child of an sql_table (should not be rendered separately)
fn is_sql_table_child(obj : Object, all_objects : Array[Object]) -> Bool {
  // Check if object has a parent that is an sql_table
  // Parent ID is everything before the last dot
  let id = obj.id
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot <= 0 {
    return false // No parent
  }
  // Get parent ID
  let parent_id_buf = StringBuilder::new()
  for i = 0; i < last_dot; i = i + 1 {
    parent_id_buf.write_char(id[i].to_int().unsafe_to_char())
  }
  let parent_id = parent_id_buf.to_string()
  // Find parent object and check if it's an sql_table
  for parent in all_objects {
    if parent.id == parent_id && parent.shape_type == SqlTable {
      return true
    }
  }
  false
}

///|
fn render_svg_object(
  svg : @svg.Svg,
  obj : Object,
  all_objects : Array[Object],
  config : SvgConfig,
  theme : @themes.Theme,
  pass? : RenderPass = Foreground,
) -> Unit {
  guard obj.box is Some(box) else { return }
  // Skip children of sql_table - they are rendered inline within the table
  if is_sql_table_child(obj, all_objects) {
    return
  }
  // For background pass, only open groups in foreground pass
  let is_foreground = match pass {
    Foreground => true
    Background => false
  }
  // Apply tooltip if present (only in foreground pass to avoid double-wrapping)
  let has_tooltip = obj.tooltip is Some(_) && is_foreground
  if has_tooltip {
    svg.open_group_with_tooltip(obj.tooltip.unwrap())
  }
  // Apply sketch filter if enabled (only in foreground pass)
  let use_sketch = obj.style.sketch is Some(true) && is_foreground
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
  // Apply no_corner_radius special rule
  let border_radius = if theme.rules.no_corner_radius {
    0.0
  } else {
    match obj.style.border_radius {
      Some(r) => r
      None => 0.0
    }
  }
  // Render shape based on type
  match obj.get_shape() {
    "text" =>
      // Text shape - no border, just the label (foreground only)
      ()
    "image" => {
      // Image shape - render external image (foreground only)
      if is_foreground && obj.icon is Some(url) {
        svg.add(
          "<image href=\"\{@svg.escape_xml(url)}\" x=\"\{box.x}\" y=\"\{box.y}\" width=\"\{box.width}\" height=\"\{box.height}\" preserveAspectRatio=\"xMidYMid meet\"/>",
        )
      }
      if is_foreground {
        if use_sketch {
          svg.close_group()
        }
        if has_tooltip {
          svg.close_group()
        }
      }
      return // Don't render the default label for image shape
    }
    "code" => {
      // Code shape - render in appropriate pass
      render_svg_code(
        svg,
        box,
        obj.label,
        fill,
        stroke,
        stroke_width,
        config,
        pass~,
      )
      if is_foreground {
        if use_sketch {
          svg.close_group()
        }
        if has_tooltip {
          svg.close_group()
        }
      }
      return // Don't render the default label
    }
    "class" => {
      // UML class shape - render in appropriate pass
      render_svg_class(
        svg,
        box,
        obj.label,
        fill,
        stroke,
        stroke_width,
        config,
        pass~,
      )
      if is_foreground {
        if use_sketch {
          svg.close_group()
        }
        if has_tooltip {
          svg.close_group()
        }
      }
      return // Don't render the default label
    }
    "sql_table" => {
      // SQL table shape with header and columns - render in appropriate pass
      render_svg_sql_table(
        svg,
        box,
        obj.label,
        obj.children,
        fill,
        stroke,
        stroke_width,
        pass~,
        config,
      )
      if is_foreground {
        if use_sketch {
          svg.close_group()
        }
        if has_tooltip {
          svg.close_group()
        }
      }
      return // Don't render the default label
    }
    "circle" | "oval" =>
      if not(is_foreground) {
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
    "cylinder" =>
      if not(is_foreground) {
        render_svg_cylinder(svg, box, fill, stroke, stroke_width)
      }
    "diamond" =>
      if not(is_foreground) {
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
    "hexagon" =>
      if not(is_foreground) {
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
    "octagon" =>
      if not(is_foreground) {
        render_svg_octagon(svg, box, fill, stroke, stroke_width)
      }
    "parallelogram" =>
      if not(is_foreground) {
        render_svg_parallelogram(svg, box, fill, stroke, stroke_width)
      }
    "person" =>
      if not(is_foreground) {
        render_svg_person(svg, box, fill, stroke, stroke_width)
      }
    "c4_person" =>
      if not(is_foreground) {
        render_svg_c4_person(
          svg,
          box,
          obj.label,
          fill,
          stroke,
          stroke_width,
          config,
        )
      }
    "c4_container" =>
      if not(is_foreground) {
        render_svg_c4_container(
          svg,
          box,
          obj.label,
          fill,
          stroke,
          stroke_width,
          config,
        )
      }
    "cloud" =>
      if not(is_foreground) {
        render_svg_cloud(svg, box, fill, stroke, stroke_width)
      }
    "document" =>
      if not(is_foreground) {
        render_svg_document(svg, box, fill, stroke, stroke_width)
      }
    "queue" =>
      if not(is_foreground) {
        render_svg_queue(svg, box, fill, stroke, stroke_width)
      }
    "stored_data" =>
      if not(is_foreground) {
        render_svg_stored_data(svg, box, fill, stroke, stroke_width)
      }
    "page" =>
      if not(is_foreground) {
        render_svg_page(svg, box, fill, stroke, stroke_width)
      }
    "package" =>
      if not(is_foreground) {
        render_svg_package(svg, box, fill, stroke, stroke_width)
      }
    "step" =>
      if not(is_foreground) {
        render_svg_step(svg, box, fill, stroke, stroke_width)
      }
    "callout" =>
      if not(is_foreground) {
        render_svg_callout(svg, box, fill, stroke, stroke_width)
      }
    _ =>
      if not(is_foreground) {
        svg.add(
          @svg.rect(
            box.x,
            box.y,
            box.width,
            box.height,
            fill~,
            stroke~,
            stroke_width~,
            rx=Some(border_radius),
            ry=Some(border_radius),
          ),
        )
      }
  }
  // Background pass: render decorations (double border, dots)
  if not(is_foreground) {
    // Add double border if specified by style or theme rule for outer containers
    let is_outer_container = obj.is_container() && not(obj.id.contains("."))
    let needs_double_border = obj.style.double_border is Some(true) ||
      (theme.rules.outer_container_double_border && is_outer_container)
    if needs_double_border {
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
          rx=Some(border_radius),
          ry=Some(border_radius),
        ),
      )
    }
    // Add container dots if theme rule is enabled
    if theme.rules.container_dots && obj.is_container() {
      let dot_r = 2.5
      let dot_offset = 8.0
      // Dots at each corner
      svg.add(
        @svg.circle(
          box.x + dot_offset,
          box.y + dot_offset,
          dot_r,
          fill=stroke,
          stroke="none",
        ),
      )
      svg.add(
        @svg.circle(
          box.x + box.width - dot_offset,
          box.y + dot_offset,
          dot_r,
          fill=stroke,
          stroke="none",
        ),
      )
      svg.add(
        @svg.circle(
          box.x + dot_offset,
          box.y + box.height - dot_offset,
          dot_r,
          fill=stroke,
          stroke="none",
        ),
      )
      svg.add(
        @svg.circle(
          box.x + box.width - dot_offset,
          box.y + box.height - dot_offset,
          dot_r,
          fill=stroke,
          stroke="none",
        ),
      )
    }
  }
  // Foreground pass: render icon and label
  if is_foreground {
    let cx = box.x + box.width / 2.0
    let cy = box.y + box.height / 2.0
    // Check if icon is present (non-image shapes)
    let has_icon = obj.icon is Some(_) && obj.shape_type != Image
    if has_icon {
      // Render icon above label
      let icon_size = 24.0
      let icon_y = cy - config.font_size.to_double() / 2.0 - icon_size / 2.0
      let icon_url = obj.icon.unwrap()
      let icon_x = cx - icon_size / 2.0
      let icon_top = icon_y - icon_size / 2.0
      svg.add(
        "<image href=\"\{@svg.escape_xml(icon_url)}\" x=\"\{icon_x}\" y=\"\{icon_top}\" width=\"\{icon_size}\" height=\"\{icon_size}\" preserveAspectRatio=\"xMidYMid meet\"/>",
      )
    }
    // Render label
    if obj.label != "" {
      // Use custom font-family if specified in style, otherwise use config
      let font_family = match obj.style.font_family {
        Some(f) => f
        None => config.font_family
      }
      // Get text-transform if specified, or apply caps_lock rule
      let text_transform = if theme.rules.caps_lock {
        "uppercase"
      } else {
        match obj.style.text_transform {
          Some(t) => t
          None => ""
        }
      }
      // Adjust label position if icon is present
      let label_y = if has_icon {
        cy + 12.0 // Move label down when icon is present
      } else {
        cy
      }
      svg.add(
        @svg.styled_text(
          cx,
          label_y,
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
    // Close tooltip group if opened
    if has_tooltip {
      svg.close_group()
    }
  }
}

///|
fn render_svg_sql_table(
  svg : @svg.Svg,
  box : Box,
  label : String,
  children : Array[Object],
  fill : String,
  stroke : String,
  stroke_width : Double,
  pass? : RenderPass = Foreground,
  config : SvgConfig,
) -> Unit {
  let line_height = config.font_size.to_double() + 4.0
  let padding = 8.0
  let header_bg = "#4a5568" // Darker header
  let header_fg = "#ffffff"
  let table_name = label
  // Calculate height: header + column rows
  let header_height = line_height + padding
  let columns_height = children.length().to_double() * line_height + padding
  let total_height = header_height + columns_height
  // Use calculated height if larger than box
  let actual_height = if total_height > box.height {
    total_height
  } else {
    box.height
  }
  match pass {
    Background => {
      // Background pass: render shapes (rectangles, lines)
      // Draw main rectangle
      svg.add(
        @svg.rect(
          box.x,
          box.y,
          box.width,
          actual_height,
          fill~,
          stroke~,
          stroke_width~,
        ),
      )
      // Draw header background
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
      // Draw separator line
      let sep_y = box.y + header_height
      svg.add(
        @svg.line(
          box.x,
          sep_y,
          box.x + box.width,
          sep_y,
          stroke~,
          stroke_width~,
        ),
      )
    }
    Foreground => {
      // Foreground pass: render text (table name, column names)
      // Draw table name (bold, centered, white)
      let name_y = box.y + header_height / 2.0
      svg.add(
        "<text x=\"\{box.x + box.width / 2.0}\" y=\"\{name_y}\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\{config.font_family}\" font-size=\"\{config.font_size}\" font-weight=\"bold\" fill=\"\{header_fg}\">\{@svg.escape_xml(table_name)}</text>",
      )
      // Draw columns from children
      let mut current_y = box.y + header_height + line_height * 0.7
      for child in children {
        // Get short name from child ID (e.g., "users.id" -> "id")
        let col_name = get_short_name(child.id)
        // Format: "name: type" where type is the child's label
        let col_text = if child.label.length() > 0 {
          col_name + ": " + child.label
        } else {
          col_name
        }
        // Check for PK/FK markers in label
        let is_pk = child.label.contains("PK") || child.label.contains("pk")
        let font_weight = if is_pk { "font-weight=\"bold\"" } else { "" }
        svg.add(
          "<text x=\"\{box.x + padding}\" y=\"\{current_y}\" text-anchor=\"start\" dominant-baseline=\"middle\" font-family=\"\{config.font_family}\" font-size=\"\{config.font_size - 1}\" \{font_weight}>\{@svg.escape_xml(col_text)}</text>",
        )
        current_y = current_y + line_height
      }
    }
  }
}

///|
/// Get the short name from a dotted ID (e.g., "users.id" -> "id")
fn get_short_name(id : String) -> String {
  let mut last_dot = -1
  for i = 0; i < id.length(); i = i + 1 {
    if id[i] == '.' {
      last_dot = i
    }
  }
  if last_dot >= 0 && last_dot < id.length() - 1 {
    let buf = StringBuilder::new()
    for i = last_dot + 1; i < id.length(); i = i + 1 {
      buf.write_char(id[i].to_int().unsafe_to_char())
    }
    buf.to_string()
  } else {
    id
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
  pass? : RenderPass = Foreground,
) -> Unit {
  let line_height = config.font_size.to_double() + 4.0
  let padding = 8.0
  // Parse label into sections: name, fields, methods
  let lines = split_lines(label)
  let class_name = if lines.length() > 0 { lines[0] } else { "" }
  match pass {
    Background =>
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
    Foreground => {
      // Draw class name (bold, centered)
      let name_y = box.y + padding + line_height * 0.5
      svg.add(
        "<text x=\"\{box.x + box.width / 2.0}\" y=\"\{name_y}\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\{config.font_family}\" font-size=\"\{config.font_size}\" font-weight=\"bold\">\{@svg.escape_xml(class_name)}</text>",
      )
      // Draw separator line after class name
      let sep1_y = box.y + padding + line_height
      svg.add(
        @svg.line(
          box.x,
          sep1_y,
          box.x + box.width,
          sep1_y,
          stroke~,
          stroke_width~,
        ),
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
  pass? : RenderPass = Foreground,
) -> Unit {
  // Dark background for code block
  let code_bg = "#1e1e1e"
  let code_fg = "#d4d4d4"
  let padding = 8.0
  let line_height = 16.0
  match pass {
    Background =>
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
          rx=Some(4.0),
          ry=Some(4.0),
        ),
      )
    Foreground => {
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
  // D2-style person shape based on 68.3 x 77.4 coordinate system
  let sx = box.width / 68.3
  let sy = box.height / 77.4
  let x = box.x
  let y = box.y
  // Build path using PathBuilder
  // The path draws: bottom line, left leg, left shoulder, head circle, right shoulder, right leg
  let path_data = @svg.PathBuilder::new()
    // Start at bottom right
    .move_to(x + 68.3 * sx, y + 77.4 * sy)
    // Bottom line
    .h_to(x)
    // Left leg
    .v_rel(-1.1 * sy)
    .cubic_rel(0.0, -13.2 * sy, 7.5 * sx, -25.1 * sy, 19.3 * sx, -30.8 * sy)
    // Left shoulder curve
    .cubic_to(
      x + 12.8 * sx,
      y + 40.9 * sy,
      x + 8.9 * sx,
      y + 33.4 * sy,
      x + 8.9 * sx,
      y + 25.2 * sy,
    )
    // Head left half
    .cubic_to(
      x + 8.9 * sx,
      y + 11.3 * sy,
      x + 20.2 * sx,
      y + 0.0 * sy,
      x + 34.1 * sx,
      y + 0.0 * sy,
    )
    // Head right half
    .cubic_rel(13.9 * sx, 0.0, 25.2 * sx, 11.3 * sy, 25.2 * sx, 25.2 * sy)
    // Right shoulder
    .cubic_rel(0.0, 8.2 * sy, -3.8 * sx, 15.6 * sy, -10.4 * sx, 20.4 * sy)
    // Right leg
    .cubic_rel(11.8 * sx, 5.7 * sy, 19.3 * sx, 17.6 * sy, 19.3 * sx, 30.8 * sy)
    .v_rel(1.0 * sy)
    .close()
    .build()
  svg.add(@svg.path(path_data, fill~, stroke~, stroke_width~))
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
/// Build a smooth curved path through waypoints using Catmull-Rom to Bezier conversion
fn build_curved_path(pb : @svg.PathBuilder, points : Array[Point]) -> Unit {
  if points.length() < 2 {
    return
  }
  // Move to first point
  let _ = pb.move_to(points[0].x, points[0].y)
  if points.length() == 2 {
    // Only two points - create a subtle curve using quadratic bezier
    let p0 = points[0]
    let p1 = points[1]
    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    let mx = (p0.x + p1.x) / 2.0
    let my = (p0.y + p1.y) / 2.0
    let len = (dx * dx + dy * dy).sqrt()
    if len > 0.0 {
      let offset = len * 0.1
      let cx = mx - dy / len * offset
      let cy = my + dx / len * offset
      let _ = pb.quad_to(cx, cy, p1.x, p1.y)

    } else {
      let _ = pb.line_to(p1.x, p1.y)

    }
    return
  }
  // Tension factor for Catmull-Rom (0.5 is typical)
  let tension = 0.5
  // For each segment, calculate cubic bezier control points
  for i = 0; i < points.length() - 1; i = i + 1 {
    // Get the four points for Catmull-Rom (p0, p1, p2, p3)
    // Clamp to valid indices
    let p0 = if i == 0 { points[0] } else { points[i - 1] }
    let p1 = points[i]
    let p2 = points[i + 1]
    let p3 = if i + 2 >= points.length() {
      points[i + 1]
    } else {
      points[i + 2]
    }
    // Convert Catmull-Rom to Bezier control points
    // The formulas for control points:
    // cp1 = p1 + (p2 - p0) / 6 * tension
    // cp2 = p2 - (p3 - p1) / 6 * tension
    let cp1_x = p1.x + (p2.x - p0.x) * tension / 3.0
    let cp1_y = p1.y + (p2.y - p0.y) * tension / 3.0
    let cp2_x = p2.x - (p3.x - p1.x) * tension / 3.0
    let cp2_y = p2.y - (p3.y - p1.y) * tension / 3.0
    // Draw cubic bezier
    let _ = pb.cubic_to(cp1_x, cp1_y, cp2_x, cp2_y, p2.x, p2.y)

  }
}

///|
/// Build a railroad-style path with orthogonal lines and rounded corners
fn build_railroad_path(pb : @svg.PathBuilder, points : Array[Point]) -> Unit {
  if points.length() < 2 {
    return
  }
  // Radius for rounded corners
  let radius = 8.0
  // Move to first point
  let _ = pb.move_to(points[0].x, points[0].y)
  if points.length() == 2 {
    // Two points - create orthogonal path with a bend
    let p0 = points[0]
    let p1 = points[1]
    let dx = (p1.x - p0.x).abs()
    let dy = (p1.y - p0.y).abs()
    // If already aligned, just draw straight
    if dx < 1.0 || dy < 1.0 {
      let _ = pb.line_to(p1.x, p1.y)
      return
    }
    // Create orthogonal path: go vertical first, then horizontal (or vice versa)
    // Choose based on which dimension is larger
    let mid_y = (p0.y + p1.y) / 2.0
    let r = @cmp.minimum(radius, @cmp.minimum(dx, dy) / 2.0)
    if r < 1.0 {
      // Too small for arcs, just use straight lines
      let _ = pb.line_to(p0.x, mid_y)
      let _ = pb.line_to(p1.x, mid_y)
      let _ = pb.line_to(p1.x, p1.y)
      return
    }
    // First vertical segment (stop before corner)
    let stop1_y = if mid_y > p0.y { mid_y - r } else { mid_y + r }
    let _ = pb.line_to(p0.x, stop1_y)
    // First arc
    let sweep1 = (p1.x > p0.x) != (mid_y > p0.y)
    let resume1_x = if p1.x > p0.x { p0.x + r } else { p0.x - r }
    let _ = pb.arc_to(r, r, resume1_x, mid_y, large_arc=false, sweep=sweep1)
    // Horizontal segment (stop before second corner)
    let stop2_x = if p1.x > p0.x { p1.x - r } else { p1.x + r }
    let _ = pb.line_to(stop2_x, mid_y)
    // Second arc
    let sweep2 = (p1.x > p0.x) == (p1.y > mid_y)
    let resume2_y = if p1.y > mid_y { mid_y + r } else { mid_y - r }
    let _ = pb.arc_to(r, r, p1.x, resume2_y, large_arc=false, sweep=sweep2)
    // Final vertical segment
    let _ = pb.line_to(p1.x, p1.y)
    return
  }
  // For each intermediate point, draw line segments with rounded corners
  for i = 0; i < points.length() - 1; i = i + 1 {
    let curr = points[i]
    let next = points[i + 1]
    if i == points.length() - 2 {
      // Last segment - just draw to end
      let _ = pb.line_to(next.x, next.y)

    } else {
      // There's a corner at 'next', so we need to draw a rounded corner
      let after = points[i + 2]
      // Calculate the direction vectors
      let dx1 = next.x - curr.x
      let dy1 = next.y - curr.y
      let dx2 = after.x - next.x
      let dy2 = after.y - next.y
      // Normalize directions
      let len1 = (dx1 * dx1 + dy1 * dy1).sqrt()
      let len2 = (dx2 * dx2 + dy2 * dy2).sqrt()
      if len1 < 0.001 || len2 < 0.001 {
        // Degenerate case - just line to next
        let _ = pb.line_to(next.x, next.y)
        continue
      }
      // Limit radius to half the shorter segment length
      let max_radius = @cmp.minimum(len1, len2) / 2.0
      let r = @cmp.minimum(radius, max_radius)
      if r < 1.0 {
        // Radius too small - just use straight lines
        let _ = pb.line_to(next.x, next.y)
        continue
      }
      // Calculate the point where we stop before the corner
      let stop_x = next.x - dx1 / len1 * r
      let stop_y = next.y - dy1 / len1 * r
      // Calculate the point where we resume after the corner
      let resume_x = next.x + dx2 / len2 * r
      let resume_y = next.y + dy2 / len2 * r
      // Draw line to the stop point
      let _ = pb.line_to(stop_x, stop_y)
      // Determine arc direction (sweep flag)
      // Cross product of directions determines if we turn left or right
      // In SVG coords (y down), positive cross means counter-clockwise turn
      // For right→down or left→up turns, we need sweep=true (clockwise)
      // For down→right or up→left turns, we need sweep=false (counter-clockwise)
      let cross = dx1 * dy2 - dy1 * dx2
      let sweep_flag = cross > 0.0
      // Draw arc to resume point: rx, ry, end-x, end-y, large_arc?, sweep?
      let _ = pb.arc_to(
        r,
        r,
        resume_x,
        resume_y,
        large_arc=false,
        sweep=sweep_flag,
      )

    }
  }
}

///|
fn render_svg_edge(
  svg : @svg.Svg,
  edge : Edge,
  config : SvgConfig,
  theme : @themes.Theme,
) -> Unit {
  // Suppress unused variable warning
  let _ = theme
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
  let stroke_dash = match edge.style.stroke_dash {
    Some(d) => d
    None => 0.0
  }
  // Build path - use railroad style (orthogonal with rounded corners) by default
  // Curved style overrides to smooth bezier curves when explicitly requested
  let use_curved = edge.style.curved is Some(true)
  let pb = @svg.PathBuilder::new()
  if use_curved && edge.route.length() >= 2 {
    // Use smooth bezier curves (Catmull-Rom to Bezier conversion)
    build_curved_path(pb, edge.route)
  } else {
    // Use railroad style: orthogonal lines with rounded corners at bends
    build_railroad_path(pb, edge.route)
  }
  // Determine markers based on arrowhead types
  // For marker-start: reverse direction (arrow points toward destination/into line)
  // For marker-end: normal direction (arrow points toward destination/away from line)
  let marker_start = get_marker_url(edge.src_arrowhead, true)
  let marker_end = get_marker_url(edge.dst_arrowhead, false)
  // Use animated path if animated style is enabled
  if edge.style.animated is Some(true) {
    svg.add(
      @svg.animated_path(
        pb.build(),
        stroke~,
        stroke_width~,
        marker_start~,
        marker_end~,
      ),
    )
  } else {
    svg.add(
      @svg.path(
        pb.build(),
        stroke~,
        stroke_width~,
        stroke_dash~,
        marker_start~,
        marker_end~,
      ),
    )
  }
  // Render edge label
  if edge.label != "" {
    // Use computed label_box if available (from automatic positioning)
    // Otherwise fall back to midpoint
    match edge.get_label_box() {
      Some(label_box) => {
        // Use pre-computed label position
        let cx = label_box.x + label_box.width / 2.0
        let cy = label_box.y + label_box.height / 2.0
        svg.add(
          @svg.rect(
            label_box.x,
            label_box.y,
            label_box.width,
            label_box.height,
            fill="white",
            stroke="none",
            rx=Some(3.0),
            ry=Some(3.0),
          ),
        )
        svg.add(
          @svg.text(
            cx,
            cy,
            edge.label,
            font_family=config.font_family,
            font_size=config.font_size - 2,
          ),
        )
      }
      None =>
        // Fallback to midpoint positioning
        match edge.midpoint() {
          Some(mid) => {
            let padding = 4.0
            let label_width = edge.label.length().to_double() * 7.0 +
              padding * 2.0
            let label_height = config.font_size.to_double() + padding * 2.0
            svg.add(
              @svg.rect(
                mid.x - label_width / 2.0,
                mid.y - label_height / 2.0,
                label_width,
                label_height,
                fill="white",
                stroke="none",
                rx=Some(3.0),
                ry=Some(3.0),
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
      rx=Some(8.0),
      ry=Some(8.0),
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
      rx=Some(corner_radius),
      ry=Some(corner_radius),
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

///|
/// Render a sequence diagram note (uses page shape with folded corner)
fn render_svg_sequence_note(
  svg : @svg.Svg,
  box : Box,
  text : String,
  config : SvgConfig,
) -> Unit {
  let fill = "#ffffc0" // Light yellow for notes
  let stroke = config.default_stroke
  let stroke_width = config.default_stroke_width
  // Use page shape for notes (with folded corner)
  render_svg_page(svg, box, fill, stroke, stroke_width)
  // Render note text centered
  let cx = box.x + box.width / 2.0
  let cy = box.y + box.height / 2.0
  svg.add(
    @svg.text(
      cx,
      cy,
      text,
      font_family=config.font_family,
      font_size=config.font_size - 2,
    ),
  )
}

///|
/// Render sequence diagram fragments (combined fragments like alt, opt, loop)
fn render_svg_sequence_fragments(
  svg : @svg.Svg,
  graph : Graph,
  config : SvgConfig,
) -> Unit {
  for fragment in graph.sequence_fragments {
    if fragment.bbox is Some(bbox) {
      render_svg_fragment(svg, fragment, bbox, config)
    }
  }
}

///|
/// Render a single sequence diagram fragment
fn render_svg_fragment(
  svg : @svg.Svg,
  fragment : SequenceFragment,
  bbox : Box,
  config : SvgConfig,
) -> Unit {
  let stroke = config.default_stroke
  let stroke_width = config.default_stroke_width
  let fill = "none"
  let label_height = 20.0
  let label_padding = 8.0
  // Draw the main fragment frame
  svg.add(
    @svg.rect(
      bbox.x,
      bbox.y,
      bbox.width,
      bbox.height,
      fill~,
      stroke~,
      stroke_width~,
    ),
  )
  // Draw the label box in the top-left corner
  let label_text = fragment.fragment_type.to_upper()
  let label_width = estimate_text_width(label_text, config.font_size) +
    label_padding * 2.0
  // Pentagon-like shape for the label
  let pb = @svg.PathBuilder::new()
    .move_to(bbox.x, bbox.y)
    .line_to(bbox.x + label_width, bbox.y)
    .line_to(bbox.x + label_width, bbox.y + label_height - 5.0)
    .line_to(bbox.x + label_width - 5.0, bbox.y + label_height)
    .line_to(bbox.x, bbox.y + label_height)
    .close()
  svg.add(@svg.path(pb.build(), fill="#f0f0f0", stroke~, stroke_width~))
  // Fragment type label
  svg.add(
    @svg.text(
      bbox.x + label_padding,
      bbox.y + label_height / 2.0 + 3.0,
      label_text,
      font_size=config.font_size - 1,
      font_family=config.font_family,
      text_anchor="start",
    ),
  )
  // Draw condition if present
  if fragment.condition is Some(cond) {
    svg.add(
      @svg.text(
        bbox.x + label_width + 10.0,
        bbox.y + label_height / 2.0 + 3.0,
        cond,
        font_size=config.font_size - 2,
        font_family=config.font_family,
        text_anchor="start",
      ),
    )
  }
  // Draw operand separators for multi-branch fragments (e.g., alt)
  for operand in fragment.operands {
    // Dashed horizontal line
    svg.add(
      "<line x1=\"\{bbox.x}\" y1=\"\{operand.separator_y}\" x2=\"\{bbox.x + bbox.width}\" y2=\"\{operand.separator_y}\" stroke=\"\{stroke}\" stroke-width=\"\{stroke_width}\" stroke-dasharray=\"5,5\"/>",
    )
    // Operand condition label
    if operand.condition is Some(cond) {
      svg.add(
        @svg.text(
          bbox.x + label_padding,
          operand.separator_y + 15.0,
          cond,
          font_size=config.font_size - 2,
          font_family=config.font_family,
          text_anchor="start",
        ),
      )
    }
  }
}
