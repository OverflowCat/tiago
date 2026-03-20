///|
priv struct SketchSession {
  interp : @interpreter.Interpreter
}

///|
fn SketchSession::new() -> SketchSession raise @render_api.RenderError {
  let interp = @interpreter.Interpreter::new()
  ignore(sketch_run_source(interp, sketch_runtime_source))
  ignore(sketch_run_source(interp, sketch_setup_source))
  { interp, }
}

///|
fn sketch_run_source(
  interp : @interpreter.Interpreter,
  source : String,
) -> @interpreter.Value raise @render_api.RenderError {
  let program = @parser.parse(source) catch {
    e => raise RenderFailed("Sketch runtime parse failed: \{e}")
  }
  let result = interp.run(program.stmts) catch {
    e => raise RenderFailed("Sketch runtime execution failed: \{e}")
  }
  interp.run_microtasks() catch {
    e => raise RenderFailed("Sketch runtime microtask failed: \{e}")
  }
  interp.run_timers() catch {
    e => raise RenderFailed("Sketch runtime timer failed: \{e}")
  }
  result
}

///|
fn sketch_js_string(value : String) -> String {
  Json::string(value).stringify(escape_slash=false)
}

///|
fn sketch_js_number(value : Double) -> String {
  if value.round() == value {
    value.to_int().to_string()
  } else {
    d2_fixed6(value)
  }
}

///|
fn sketch_js_points(points : Array[(Double, Double)]) -> String {
  let out = StringBuilder::new()
  out.write_char('[')
  for i = 0; i < points.length(); i = i + 1 {
    if i > 0 {
      out.write_char(',')
    }
    let (x, y) = points[i]
    out.write_string("[\{sketch_js_number(x)},\{sketch_js_number(y)}]")
  }
  out.write_char(']')
  out.to_string()
}

///|
fn sketch_base_shape_props(stroke_width : Double) -> String {
  "fill: \"#000\", stroke: \"#000\", strokeWidth: \{sketch_js_number(stroke_width)}, fillWeight: 2.0, hachureGap: 16, fillStyle: \"solid\", bowing: 2, seed: 1"
}

///|
fn SketchSession::eval_nodes(
  self : SketchSession,
  command : String,
) -> Array[Map[String, String]] raise @render_api.RenderError {
  let extractor =
    #|
    #|(function() {
    #|  var out = [];
    #|  var children = node.children || [];
    #|  for (var i = 0; i < children.length; i++) {
    #|    var child = children[i];
    #|    var d = "";
    #|    if (child.attrs && child.attrs.d) {
    #|      d = child.attrs.d.replace(/(\d+)\.(\d+)/g, function(_, intPart, fracPart) {
    #|        return intPart + "." + fracPart.slice(0, 6);
    #|      });
    #|    }
    #|    out.push({
    #|      d: d,
    #|      fill: child.style && child.style.fill ? child.style.fill : "",
    #|      stroke: child.style && child.style.stroke ? child.style.stroke : "",
    #|      stroke_width: child.style && child.style.strokeWidth ? child.style.strokeWidth : ""
    #|    });
    #|  }
    #|  return JSON.stringify(out);
    #|})()
  let source = command + extractor
  let result = sketch_run_source(self.interp, source)
  let json = @json.parse(result.to_string()[:]) catch {
    e => raise RenderFailed("Sketch runtime JSON parse failed: \{e}")
  }
  @json.from_json(json) catch {
    e => raise RenderFailed("Sketch runtime JSON decode failed: \{e}")
  }
}

///|
fn SketchSession::rectangle(
  self : SketchSession,
  width : Double,
  height : Double,
  stroke_width : Double,
) -> Array[Map[String, String]] raise @render_api.RenderError {
  self.eval_nodes(
    "node = rc.rectangle(0, 0, \{sketch_js_number(width)}, \{sketch_js_number(height)}, { \{sketch_base_shape_props(stroke_width)} });",
  )
}

///|
fn SketchSession::ellipse(
  self : SketchSession,
  width : Double,
  height : Double,
  stroke_width : Double,
) -> Array[Map[String, String]] raise @render_api.RenderError {
  self.eval_nodes(
    "node = rc.ellipse(\{sketch_js_number(width / 2.0)}, \{sketch_js_number(height / 2.0)}, \{sketch_js_number(width)}, \{sketch_js_number(height)}, { \{sketch_base_shape_props(stroke_width)} });",
  )
}

///|
fn SketchSession::polygon(
  self : SketchSession,
  points : Array[(Double, Double)],
  stroke_width : Double,
) -> Array[Map[String, String]] raise @render_api.RenderError {
  self.eval_nodes(
    "node = rc.polygon(\{sketch_js_points(points)}, { \{sketch_base_shape_props(stroke_width)} });",
  )
}

///|
fn SketchSession::path_shape(
  self : SketchSession,
  path_d : String,
  stroke_width : Double,
) -> Array[Map[String, String]] raise @render_api.RenderError {
  self.eval_nodes(
    "node = rc.path(\{sketch_js_string(path_d)}, { \{sketch_base_shape_props(stroke_width)} });",
  )
}

///|
fn SketchSession::connection(
  self : SketchSession,
  path_d : String,
) -> Array[Map[String, String]] raise @render_api.RenderError {
  self.eval_nodes(
    "node = rc.path(\{sketch_js_string(path_d)}, { roughness: 0.5, seed: 1 });",
  )
}

///|
fn sketch_arrowhead_command(
  arrowhead : ArrowheadType,
  stroke : String,
  stroke_width : Double,
  background_fill : String,
) -> (String, String?) {
  let stroke_js = sketch_js_string(stroke)
  let background_fill_js = sketch_js_string(background_fill)
  let width_js = sketch_js_number(stroke_width)
  match arrowhead {
    @graph.None => ("", None)
    @graph.Line =>
      (
        "node = rc.linearPath([[-10, -4], [0, 0], [-10, 4]], { strokeWidth: \{width_js}, stroke: \{stroke_js}, seed: 3 });",
        None,
      )
    @graph.Triangle =>
      (
        "node = rc.polygon([[-10, -4], [0, 0], [-10, 4]], { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{stroke_js}, fillStyle: \"solid\", seed: 2 });",
        None,
      )
    @graph.Open =>
      (
        "node = rc.polygon([[-10, -4], [0, 0], [-10, 4]], { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{background_fill_js}, fillStyle: \"solid\", seed: 2 });",
        None,
      )
    @graph.Diamond =>
      (
        "node = rc.polygon([[-20, 0], [-10, 5], [0, 0], [-10, -5], [-20, 0]], { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{background_fill_js}, fillStyle: \"solid\", seed: 1 });",
        None,
      )
    @graph.Circle =>
      (
        "node = rc.circle(-2, -1, 8, { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{background_fill_js}, fillStyle: \"solid\", fillWeight: 1, seed: 5 });",
        None,
      )
    @graph.CfMany =>
      (
        "node = rc.path(\"M0,10 -15,0 M0,-10 -15,0\", { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{stroke_js}, fillStyle: \"solid\", fillWeight: 4, seed: 8 });",
        None,
      )
    @graph.CfManyOptional =>
      (
        "node = rc.path(\"M0,10 -15,0 M0,-10 -15,0\", { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{stroke_js}, fillStyle: \"solid\", fillWeight: 4, seed: 8 });",
        Some(
          "node = rc.circle(-20, 0, 8, { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{background_fill_js}, fillStyle: \"solid\", fillWeight: 1, seed: 4 });",
        ),
      )
    @graph.CfManyRequired =>
      (
        "node = rc.path(\"M-15,-10 -15,10 M0,10 -15,0 M0,-10 -15,0\", { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{stroke_js}, fillStyle: \"solid\", fillWeight: 4, seed: 2 });",
        None,
      )
    @graph.CfOne =>
      (
        "node = rc.path(\"M-10,-10 -10,10\", { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{stroke_js}, fillStyle: \"solid\", fillWeight: 4, seed: 3 });",
        None,
      )
    @graph.CfOneOptional =>
      (
        "node = rc.path(\"M-10,-10 -10,10\", { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{stroke_js}, fillStyle: \"solid\", fillWeight: 4, seed: 3 });",
        Some(
          "node = rc.circle(-20, 0, 8, { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{background_fill_js}, fillStyle: \"solid\", fillWeight: 1, seed: 5 });",
        ),
      )
    @graph.CfOneRequired =>
      (
        "node = rc.path(\"M-15,-10 -15,10 M-10,-10 -10,10\", { strokeWidth: \{width_js}, stroke: \{stroke_js}, fill: \{stroke_js}, fillStyle: \"solid\", fillWeight: 4, seed: 2 });",
        None,
      )
  }
}

///|
fn SketchSession::arrowhead(
  self : SketchSession,
  arrowhead : ArrowheadType,
  stroke : String,
  stroke_width : Double,
  background_fill : String,
) -> Array[Map[String, String]] raise @render_api.RenderError {
  let (command, extra_command) = sketch_arrowhead_command(
    arrowhead, stroke, stroke_width, background_fill,
  )
  if command == "" {
    []
  } else {
    let nodes = self.eval_nodes(command)
    match extra_command {
      Some(extra) => {
        let extra_nodes = self.eval_nodes(extra)
        let out : Array[Map[String, String]] = []
        for node in nodes {
          out.push(node)
        }
        for node in extra_nodes {
          out.push(node)
        }
        out
      }
      None => nodes
    }
  }
}

///|
fn sketch_needed(graph : Diagram, config : SvgConfig) -> Bool {
  if config.sketch {
    return true
  }
  for obj in graph.shapes {
    if sketch_enabled(obj.style.sketch, config) {
      return true
    }
  }
  for edge in graph.connections {
    if sketch_enabled(edge.style.sketch, config) {
      return true
    }
  }
  false
}

///|
fn sketch_shape_overlay_class(fill : String, theme : @themes.Theme) -> String {
  match d2_theme_token(fill, theme) {
    Some(token) => "sketch-overlay-\{token}"
    None => "sketch-overlay-\{color_luminance_category(fill)}"
  }
}

///|
fn sketch_transform(x : Double, y : Double) -> String? {
  if x == 0.0 && y == 0.0 {
    None
  } else {
    Some("translate(\{d2_fixed6(x)} \{d2_fixed6(y)})")
  }
}

///|
fn sketch_mask(diagram_hash : String, obj : Shape) -> String? {
  if obj.label != "" &&
    (
      d2_label_position_is_outside(obj.label_position.unwrap_or("")) ||
      d2_label_position_is_border(obj.label_position.unwrap_or(""))
    ) {
    Some("url(#\{diagram_hash})")
  } else {
    None
  }
}

///|
fn sketch_fill_value(node_fill : String, fill : String) -> String {
  match node_fill {
    "#000" => fill
    "" | "none" => "none"
    _ => node_fill
  }
}

///|
fn sketch_stroke_value(node_stroke : String, stroke : String) -> String {
  match node_stroke {
    "#000" => stroke
    "" | "none" => "none"
    _ => node_stroke
  }
}

///|
fn sketch_path_element(
  d : String,
  fill : String,
  stroke : String,
  stroke_width : String,
  class_name : String?,
  transform : String?,
  mask : String?,
  theme : @themes.Theme,
  inline_theme : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> String {
  let classes = StringBuilder::new()
  match class_name {
    Some(name) => if name != "" { classes.write_string(name) }
    None => ()
  }
  let fill_token = match fill_class_token {
    Some(token) => Some(token)
    None => d2_theme_token(fill, theme)
  }
  let stroke_token = match stroke_class_token {
    Some(token) => Some(token)
    None => d2_theme_token(stroke, theme)
  }
  match stroke_token {
    Some(token) =>
      if classes.to_string() == "" {
        classes.write_string("stroke-\{token}")
      } else {
        classes.write_string(" stroke-\{token}")
      }
    None => ()
  }
  match fill_token {
    Some(token) =>
      if classes.to_string() == "" {
        classes.write_string("fill-\{token}")
      } else {
        classes.write_string(" fill-\{token}")
      }
    None => ()
  }
  let element = @xml_emit.Element::new("path")
    .attr("d", d)
    .attr_if("transform", transform.unwrap_or(""))
    .attr_if("mask", mask.unwrap_or(""))
    .attr_if("class", classes.to_string())
    .attr("style", "stroke-width:\{stroke_width};")
  let element = if inline_theme || fill_token is None {
    element.attr("fill", fill)
  } else {
    element
  }
  let element = if inline_theme || stroke_token is None {
    element.attr("stroke", stroke)
  } else {
    element
  }
  element.self_close().build()
}

///|
fn sketch_overlay_path_element(
  d : String,
  overlay_class : String,
  transform : String?,
  mask : String?,
) -> String {
  @xml_emit.Element::new("path")
  .attr("d", d)
  .attr("class", overlay_class)
  .attr_if("transform", transform.unwrap_or(""))
  .attr_if("mask", mask.unwrap_or(""))
  .self_close()
  .build()
}

///|
fn sketch_overlay_rect_element(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  class_name : String,
  border_radius : Double,
  mask : String?,
) -> String {
  let element = @xml_emit.Element::new("rect")
    .attr("x", d2_fixed6(x))
    .attr("y", d2_fixed6(y))
    .attr("width", d2_fixed6(width))
    .attr("height", d2_fixed6(height))
    .attr("class", class_name)
    .attr_if("mask", mask.unwrap_or(""))
  let element = if border_radius > 0.0 {
    element
    .attr("rx", d2_fixed6(border_radius))
    .attr("ry", d2_fixed6(border_radius))
  } else {
    element
  }
  element.self_close().build()
}

///|
fn sketch_overlay_ellipse_element(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  class_name : String,
  mask : String?,
) -> String {
  @xml_emit.Element::new("ellipse")
  .attr("cx", d2_fixed6(cx))
  .attr("cy", d2_fixed6(cy))
  .attr("rx", d2_fixed6(rx))
  .attr("ry", d2_fixed6(ry))
  .attr("class", class_name)
  .attr_if("mask", mask.unwrap_or(""))
  .self_close()
  .build()
}

///|
fn add_sketch_path_nodes(
  svg : @svg.Svg,
  nodes : Array[Map[String, String]],
  translate_x : Double,
  translate_y : Double,
  fill : String,
  overlay_fill : String,
  stroke : String,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
  overlay_geometry : String,
  mask : String?,
) -> Unit {
  let transform = sketch_transform(translate_x, translate_y)
  let overlay_class = sketch_shape_overlay_class(overlay_fill, theme)
  for node in nodes {
    let d = node.get("d").unwrap_or("")
    if d == "" {
      continue
    }
    let mapped_fill = sketch_fill_value(node.get("fill").unwrap_or(""), fill)
    let mapped_stroke = sketch_stroke_value(
      node.get("stroke").unwrap_or(""),
      stroke,
    )
    let stroke_width = node.get("stroke_width").unwrap_or("1")
    let shape_fill_class_token = if mapped_fill == fill {
      fill_class_token
    } else {
      None
    }
    let shape_stroke_class_token = if mapped_stroke == stroke {
      stroke_class_token
    } else {
      None
    }
    svg.add(
      sketch_path_element(
        d,
        mapped_fill,
        mapped_stroke,
        stroke_width,
        None,
        transform,
        mask,
        theme,
        !use_css_theme_vars,
        shape_fill_class_token,
        shape_stroke_class_token,
      ),
    )
    if overlay_geometry == "path" && mapped_fill != "none" {
      svg.add(sketch_overlay_path_element(d, overlay_class, transform, mask))
    }
  }
}

///|
fn sketch_local_box(box : Box) -> Box {
  @graph.Box::new(0.0, 0.0, box.width, box.height)
}

///|
fn sketch_extract_path_attr(element : String) -> String? {
  let needle = " d=\""
  let start = match code_find_substring_from(element, needle, 0) {
    Some(v) => v
    None => return None
  }
  let value_start = start + needle.length()
  let value_end = match code_find_substring_from(element, "\"", value_start) {
    Some(v) => v
    None => return None
  }
  Some(code_slice(element, value_start, value_end))
}

///|
fn sketch_extract_paths(svg : @svg.Svg) -> Array[String] {
  let out : Array[String] = []
  for element in svg.elements() {
    if element.contains("<path") {
      match sketch_extract_path_attr(element) {
        Some(d) => out.push(d)
        None => ()
      }
    }
  }
  out
}

///|
fn sketch_rounded_rect_path(box : Box, radius : Double) -> String {
  let rx = if radius * 2.0 > box.width { box.width / 2.0 } else { radius }
  let ry = if radius * 2.0 > box.height { box.height / 2.0 } else { radius }
  @svg.PathBuilder::new()
  .move_to(box.x + rx, box.y)
  .line_to(box.x + box.width - rx, box.y)
  .arc_to(rx, ry, box.x + box.width, box.y + ry)
  .line_to(box.x + box.width, box.y + box.height - ry)
  .arc_to(rx, ry, box.x + box.width - rx, box.y + box.height)
  .line_to(box.x + rx, box.y + box.height)
  .arc_to(rx, ry, box.x, box.y + box.height - ry)
  .line_to(box.x, box.y + ry)
  .arc_to(rx, ry, box.x + rx, box.y)
  .close()
  .build()
}

///|
fn sketch_path_shape_data(
  shape_name : String,
  box : Box,
  theme : @themes.Theme,
) -> Array[String] {
  let svg = @svg.Svg::new(box.width, box.height)
  let local_box = sketch_local_box(box)
  match shape_name {
    "cylinder" =>
      render_svg_cylinder(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "diamond" =>
      render_svg_diamond(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "hexagon" =>
      render_svg_hexagon(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "parallelogram" =>
      render_svg_parallelogram(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "person" =>
      render_svg_person(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "cloud" =>
      render_svg_cloud(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "document" =>
      render_svg_document(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "queue" =>
      render_svg_queue(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "stored_data" =>
      render_svg_stored_data(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "page" =>
      render_svg_page(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "package" =>
      render_svg_package(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "step" =>
      render_svg_step(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    "callout" =>
      render_svg_callout(
        svg,
        local_box,
        "#000",
        "#000",
        2.0,
        theme,
        false,
        None,
        None,
      )
    _ => ()
  }
  sketch_extract_paths(svg)
}

///|
fn render_sketch_box_shape(
  svg : @svg.Svg,
  session : SketchSession,
  shape_name : String,
  diagram_hash : String,
  obj : Shape,
  box : Box,
  fill : String,
  overlay_fill : String,
  stroke : String,
  stroke_width : Double,
  border_radius : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
  fill_class_token : String?,
  stroke_class_token : String?,
) -> Bool raise @render_api.RenderError {
  let mask = sketch_mask(diagram_hash, obj)
  match shape_name {
    "circle" | "oval" => {
      let nodes = session.ellipse(box.width, box.height, stroke_width)
      add_sketch_path_nodes(
        svg,
        nodes,
        box.x,
        box.y,
        fill,
        overlay_fill,
        stroke,
        theme,
        use_css_theme_vars,
        fill_class_token,
        stroke_class_token,
        "ellipse",
        mask,
      )
      svg.add(
        sketch_overlay_ellipse_element(
          box.x + box.width / 2.0,
          box.y + box.height / 2.0,
          box.width / 2.0,
          box.height / 2.0,
          sketch_shape_overlay_class(overlay_fill, theme),
          mask,
        ),
      )
      true
    }
    "octagon" => {
      let inset = box.width * 0.29
      let inset_y = box.height * 0.29
      let nodes = session.polygon(
        [
          (inset, 0.0),
          (box.width - inset, 0.0),
          (box.width, inset_y),
          (box.width, box.height - inset_y),
          (box.width - inset, box.height),
          (inset, box.height),
          (0.0, box.height - inset_y),
          (0.0, inset_y),
        ],
        stroke_width,
      )
      add_sketch_path_nodes(
        svg,
        nodes,
        box.x,
        box.y,
        fill,
        overlay_fill,
        stroke,
        theme,
        use_css_theme_vars,
        fill_class_token,
        stroke_class_token,
        "path",
        mask,
      )
      true
    }
    "cylinder"
    | "diamond"
    | "hexagon"
    | "parallelogram"
    | "person"
    | "cloud"
    | "document"
    | "queue"
    | "stored_data"
    | "page"
    | "package"
    | "step"
    | "callout" => {
      let local_paths = sketch_path_shape_data(shape_name, box, theme)
      for path_d in local_paths {
        let nodes = session.path_shape(path_d, stroke_width)
        add_sketch_path_nodes(
          svg,
          nodes,
          box.x,
          box.y,
          fill,
          overlay_fill,
          stroke,
          theme,
          use_css_theme_vars,
          fill_class_token,
          stroke_class_token,
          "path",
          mask,
        )
      }
      true
    }
    "rectangle" | "square" => {
      if border_radius > 0.0 {
        let nodes = session.path_shape(
          sketch_rounded_rect_path(sketch_local_box(box), border_radius),
          stroke_width,
        )
        add_sketch_path_nodes(
          svg,
          nodes,
          box.x,
          box.y,
          fill,
          overlay_fill,
          stroke,
          theme,
          use_css_theme_vars,
          fill_class_token,
          stroke_class_token,
          "path",
          mask,
        )
      } else {
        let nodes = session.rectangle(box.width, box.height, stroke_width)
        add_sketch_path_nodes(
          svg,
          nodes,
          box.x,
          box.y,
          fill,
          overlay_fill,
          stroke,
          theme,
          use_css_theme_vars,
          fill_class_token,
          stroke_class_token,
          "rect",
          mask,
        )
        svg.add(
          sketch_overlay_rect_element(
            box.x,
            box.y,
            box.width,
            box.height,
            sketch_shape_overlay_class(overlay_fill, theme),
            0.0,
            mask,
          ),
        )
      }
      true
    }
    _ => false
  }
}

///|
fn sketch_angle(x1 : Double, y1 : Double, x2 : Double, y2 : Double) -> Double {
  @math.atan2(y2 - y1, x2 - x1) * 180.0 / @math.PI
}

///|
fn render_sketch_arrowhead(
  svg : @svg.Svg,
  session : SketchSession,
  arrowhead : ArrowheadType,
  anchor : Point,
  adj : (Double, Double),
  angle : Double,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> Unit raise @render_api.RenderError {
  if arrowhead == @graph.None {
    return
  }
  let nodes = session.arrowhead(
    arrowhead,
    stroke,
    stroke_width,
    theme.colors.n7,
  )
  let transform = "translate(\{d2_fixed6(anchor.x + adj.0)} \{d2_fixed6(anchor.y + adj.1)}) rotate(\{d2_fixed6(angle)})"
  for node in nodes {
    let d = node.get("d").unwrap_or("")
    if d == "" {
      continue
    }
    svg.add(
      sketch_path_element(
        d,
        node.get("fill").unwrap_or("none"),
        node.get("stroke").unwrap_or(stroke),
        node.get("stroke_width").unwrap_or(sketch_js_number(stroke_width)),
        Some("connection"),
        Some(transform),
        None,
        theme,
        !use_css_theme_vars,
        None,
        None,
      ),
    )
  }
}

///|
fn render_sketch_edge(
  svg : @svg.Svg,
  session : SketchSession,
  edge : Connection,
  shapes : Array[Shape],
  edge_label_mask_url : String,
  config : SvgConfig,
  theme : @themes.Theme,
  use_css_theme_vars : Bool,
) -> Unit raise @render_api.RenderError {
  let stroke_default = default_edge_stroke_token(edge)
  let stroke_signature = style_string(edge.style.stroke, stroke_default)
  let stroke = style_color(
    edge.style.stroke,
    stroke_default,
    theme,
    use_css_theme_vars,
  )
  let stroke_width = style_double(
    edge.style.stroke_width,
    config.default_stroke_width,
  )
  let connection_border_radius = style_double(edge.style.border_radius, 10.0)
  let stroke_dash = style_double(edge.style.stroke_dash, 0.0)
  let (src_adj, dst_adj) = get_arrowhead_adjustments(
    edge,
    shapes,
    stroke_width,
    config.default_stroke_width,
  )
  let path_data = d2_path_data(edge, src_adj, dst_adj, connection_border_radius)
  if style_bool(edge.style.animated, false) {
    svg.add(
      d2_connection_path_element(
        path_data,
        stroke,
        stroke_signature,
        stroke_width,
        stroke_dash,
        "",
        "",
        edge_label_mask_url,
        true,
        theme,
        !use_css_theme_vars,
      ),
    )
  } else {
    let nodes = session.connection(path_data)
    for node in nodes {
      let d = node.get("d").unwrap_or("")
      if d == "" {
        continue
      }
      svg.add(
        d2_connection_path_element(
          d,
          stroke,
          stroke_signature,
          stroke_width,
          stroke_dash,
          "",
          "",
          edge_label_mask_url,
          false,
          theme,
          !use_css_theme_vars,
        ),
      )
    }
  }
  let first = edge.route[0]
  let second = edge.route[1]
  let src_angle = sketch_angle(second.x, second.y, first.x, first.y)
  render_sketch_arrowhead(
    svg,
    session,
    edge.src_arrowhead,
    first,
    src_adj,
    src_angle,
    stroke,
    stroke_width,
    theme,
    use_css_theme_vars,
  )
  let route_len = edge.route.length()
  let prev = edge.route[route_len - 2]
  let last = edge.route[route_len - 1]
  let dst_angle = sketch_angle(prev.x, prev.y, last.x, last.y)
  render_sketch_arrowhead(
    svg,
    session,
    edge.dst_arrowhead,
    last,
    dst_adj,
    dst_angle,
    stroke,
    stroke_width,
    theme,
    use_css_theme_vars,
  )
}

///|
fn format_sketch_pattern_template(
  luminance_category : String,
  diagram_hash : String,
  fill : String,
) -> String {
  let values = [luminance_category, diagram_hash, fill]
  let out = StringBuilder::new()
  let mut value_index = 0
  let chars = sketch_streaks_pattern_template.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '%' &&
      i + 1 < chars.length() &&
      chars[i + 1] == 's' &&
      value_index < values.length() {
      out.write_string(values[value_index])
      value_index += 1
      i += 2
    } else {
      out.write_char(chars[i])
      i += 1
    }
  }
  out.to_string()
}

///|
fn add_sketch_assets(
  assets : SvgEmitAssets,
  graph : Diagram,
  config : SvgConfig,
) -> Unit {
  if !sketch_needed(graph, config) {
    return
  }
  assets.add_def(
    format_sketch_pattern_template(
      "bright",
      assets.diagram_hash,
      "rgba(0, 0, 0, 0.1)",
    ),
  )
  assets.add_def(
    format_sketch_pattern_template(
      "normal",
      assets.diagram_hash,
      "rgba(0, 0, 0, 0.16)",
    ),
  )
  assets.add_def(
    format_sketch_pattern_template(
      "dark",
      assets.diagram_hash,
      "rgba(0, 0, 0, 0.32)",
    ),
  )
  assets.add_def(
    format_sketch_pattern_template(
      "darker",
      assets.diagram_hash,
      "rgba(255, 255, 255, 0.24)",
    ),
  )
}
