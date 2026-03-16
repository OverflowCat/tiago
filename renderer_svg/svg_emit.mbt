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
let d2_base_stylesheet : String =
  #|.shape {
  #|  shape-rendering: geometricPrecision;
  #|  stroke-linejoin: round;
  #|}
  #|.connection {
  #|  stroke-linecap: round;
  #|  stroke-linejoin: round;
  #|}
  #|.blend {
  #|  mix-blend-mode: multiply;
  #|  opacity: 0.5;
  #|}
  #|

///|
priv struct SvgEmitAssets {
  diagram_hash : String
  light_theme : @themes.Theme
  dark_theme : @themes.Theme?
  has_markdown_shape : Bool
  style_blocks : Array[String]
  defs : Array[String]
  tail_elements : Array[String]
}

///|
fn SvgEmitAssets::new(
  diagram_hash : String,
  light_theme : @themes.Theme,
  dark_theme : @themes.Theme?,
  has_markdown_shape : Bool,
) -> SvgEmitAssets {
  {
    diagram_hash,
    light_theme,
    dark_theme,
    has_markdown_shape,
    style_blocks: [],
    defs: [],
    tail_elements: [],
  }
}

///|
fn SvgEmitAssets::mask_id(self : SvgEmitAssets) -> String {
  self.diagram_hash
}

///|
fn SvgEmitAssets::add_style(self : SvgEmitAssets, css : String) -> Unit {
  self.style_blocks.push(
    @xml_emit.Element::new("style").attr("type", "text/css").cdata(css).build(),
  )
}

///|
fn SvgEmitAssets::add_def(self : SvgEmitAssets, def : String) -> Unit {
  self.defs.push(def)
}

///|
fn SvgEmitAssets::add_tail(self : SvgEmitAssets, element : String) -> Unit {
  self.tail_elements.push(element)
}

///|
fn d2_fixed6(value : Double) -> String {
  let sign = if value < 0.0 { "-" } else { "" }
  let abs_value = if value < 0.0 { -value } else { value }
  let mut int_part = @math.floor(abs_value).to_int()
  let mut frac_part = ((abs_value - int_part.to_double()) * 1000000.0)
    .round()
    .to_int()
  if frac_part >= 1000000 {
    int_part = int_part + 1
    frac_part = frac_part - 1000000
  }
  let frac_raw = frac_part.to_string()
  let pad = 6 - frac_raw.length()
  let frac = StringBuilder::new()
  if pad > 0 {
    for _ in 0..<pad {
      frac.write_char('0')
    }
  }
  frac.write_string(frac_raw)
  "\{sign}\{int_part}.\{frac.to_string()}"
}

///|
fn d2_normalized_color(value : String) -> String {
  value.trim().to_lower().to_string()
}

///|
fn d2_theme_color_pairs(theme : @themes.Theme) -> Array[(String, String)] {
  [
    ("N1", theme.colors.n1),
    ("N2", theme.colors.n2),
    ("N3", theme.colors.n3),
    ("N4", theme.colors.n4),
    ("N5", theme.colors.n5),
    ("N6", theme.colors.n6),
    ("N7", theme.colors.n7),
    ("B1", theme.colors.b1),
    ("B2", theme.colors.b2),
    ("B3", theme.colors.b3),
    ("B4", theme.colors.b4),
    ("B5", theme.colors.b5),
    ("B6", theme.colors.b6),
    ("AA2", theme.colors.aa2),
    ("AA4", theme.colors.aa4),
    ("AA5", theme.colors.aa5),
    ("AB4", theme.colors.ab4),
    ("AB5", theme.colors.ab5),
  ]
}

///|
fn d2_sketch_color_pairs(theme : @themes.Theme) -> Array[(String, String)] {
  [
    ("B1", theme.colors.b1),
    ("B2", theme.colors.b2),
    ("B3", theme.colors.b3),
    ("B4", theme.colors.b4),
    ("B5", theme.colors.b5),
    ("B6", theme.colors.b6),
    ("AA2", theme.colors.aa2),
    ("AA4", theme.colors.aa4),
    ("AA5", theme.colors.aa5),
    ("AB4", theme.colors.ab4),
    ("AB5", theme.colors.ab5),
    ("N1", theme.colors.n1),
    ("N2", theme.colors.n2),
    ("N3", theme.colors.n3),
    ("N4", theme.colors.n4),
    ("N5", theme.colors.n5),
    ("N6", theme.colors.n6),
    ("N7", theme.colors.n7),
  ]
}

///|
fn d2_theme_token(value : String, theme : @themes.Theme) -> String? {
  let token_candidate = value.trim().to_upper().to_string()
  let normalized = d2_normalized_color(value)
  for entry in d2_theme_color_pairs(theme) {
    if token_candidate == entry.0 {
      return Some(entry.0)
    }
    if normalized == d2_normalized_color(entry.1) {
      return Some(entry.0)
    }
  }
  None
}

///|
fn d2_theme_scope_rules(
  diagram_hash : String,
  theme : @themes.Theme,
  property : String,
) -> String {
  let sb = StringBuilder::new()
  for entry in d2_theme_color_pairs(theme) {
    sb.write_string(
      "\n\t\t.\{diagram_hash} .\{property}-\{entry.0}{\{property}:\{entry.1};}",
    )
  }
  sb.to_string()
}

///|
fn d2_markdown_theme_vars(theme : @themes.Theme) -> String {
  ".md{--color-fg-default:\{theme.colors.n1};--color-fg-muted:\{theme.colors.n2};--color-fg-subtle:\{theme.colors.n3};--color-canvas-default:\{theme.colors.n7};--color-canvas-subtle:\{theme.colors.n6};--color-border-default:\{theme.colors.b1};--color-border-muted:\{theme.colors.b2};--color-neutral-muted:\{theme.colors.n6};--color-accent-fg:\{theme.colors.b2};--color-accent-emphasis:\{theme.colors.b2};--color-attention-subtle:\{theme.colors.n2};--color-danger-fg:red;}"
}

///|
fn d2_sketch_rules(diagram_hash : String, theme : @themes.Theme) -> String {
  let sb = StringBuilder::new()
  for entry in d2_sketch_color_pairs(theme) {
    let mode = match color_luminance_category(entry.1) {
      "bright" => "darken"
      "normal" => "color-burn"
      "dark" => "overlay"
      _ => "lighten"
    }
    sb.write_string(
      ".sketch-overlay-\{entry.0}{fill:url(#streaks-\{color_luminance_category(entry.1)}-\{diagram_hash});mix-blend-mode:\{mode}}",
    )
  }
  sb.to_string()
}

///|
fn color_luminance_category(color : String) -> String {
  match parse_hex_color(color) {
    Some((r, g, b)) => {
      let luminance = (
          0.2126 * r.to_double() +
          0.7152 * g.to_double() +
          0.0722 * b.to_double()
        ) /
        255.0
      if luminance > 0.85 {
        "bright"
      } else if luminance > 0.55 {
        "normal"
      } else if luminance > 0.25 {
        "dark"
      } else {
        "darker"
      }
    }
    None => "normal"
  }
}

///|
fn d2_theme_stylesheet(
  diagram_hash : String,
  light_theme : @themes.Theme,
  dark_theme : @themes.Theme?,
) -> String {
  let base = StringBuilder::new()
  for property in ["fill", "stroke", "background-color", "color"] {
    base.write_string(d2_theme_scope_rules(diagram_hash, light_theme, property))
  }
  base.write_string(".appendix text.text{fill:\{light_theme.colors.n1}}")
  base.write_string(d2_markdown_theme_vars(light_theme))
  base.write_string(d2_sketch_rules(diagram_hash, light_theme))
  base.write_string(".light-code{display: block}.dark-code{display: none}")
  match dark_theme {
    Some(theme) => {
      let dark = StringBuilder::new()
      for property in ["fill", "stroke", "background-color", "color"] {
        dark.write_string(d2_theme_scope_rules(diagram_hash, theme, property))
      }
      dark.write_string(".appendix text.text{fill:\{theme.colors.n1}}")
      dark.write_string(d2_markdown_theme_vars(theme))
      dark.write_string(d2_sketch_rules(diagram_hash, theme))
      dark.write_string(".light-code{display: none}.dark-code{display: block}")
      base.write_string(
        "@media screen and (prefers-color-scheme:dark){\{dark.to_string()}}",
      )
    }
    None => ()
  }
  d2_base_stylesheet + base.to_string()
}

///|
fn append_on_trigger(
  out : StringBuilder,
  source : String,
  triggers : Array[String],
  content : String,
) -> Unit {
  if !d2_has_any_trigger(source, triggers) {
    return
  }
  out.write_string(content)
}

///|
fn d2_has_any_trigger(source : String, triggers : Array[String]) -> Bool {
  for trigger in triggers {
    if source.contains(trigger) {
      return true
    }
  }
  false
}

///|
fn d2_subset_font_data_url(
  ttf_bytes : Bytes,
  corpus : String,
  fallback_data_url : String,
) -> String {
  let unique_corpus = d2_unique_chars(corpus)
  match @font_subset.utf8_cut_font(ttf_bytes, unique_corpus) {
    Some(subset_sfnt) =>
      if subset_sfnt.length() == 0 {
        fallback_data_url
      } else {
        match @font_subset.sfnt_to_woff(subset_sfnt) {
          Some(subset_woff) =>
            if subset_woff.length() == 0 {
              fallback_data_url
            } else {
              "data:application/font-woff;base64,\{@base64.encode(subset_woff)}"
            }
          None => fallback_data_url
        }
      }
    None => fallback_data_url
  }
}

///|
fn d2_unique_chars(text : String) -> String {
  let seen : Map[Char, Bool] = {}
  let out = StringBuilder::new()
  for ch in text.to_array() {
    if !seen.contains(ch) {
      seen[ch] = true
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn d2_embed_fonts_styles(
  diagram_hash : String,
  source : String,
  corpus : String,
) -> String {
  let out = StringBuilder::new()
  let regular_text_triggers = [
    "class=\"text\"", "class=\"text ", "class=\"md\"", "class=\"md ",
  ]
  let markdown_triggers = ["class=\"md\"", "class=\"md "]
  let bold_triggers = ["class=\"text-bold", "<b>", "<strong>"]
  let italic_triggers = ["class=\"text-italic", "<em>", "<dfn>"]
  let mono_triggers = [
    "class=\"text-mono", "<pre>", "<code>", "<kbd>", "<samp>",
  ]
  let mono_bold_triggers = ["class=\"text-mono-bold"]
  let mono_italic_triggers = ["class=\"text-mono-italic"]
  let regular_data = if d2_has_any_trigger(source, regular_text_triggers) {
    d2_subset_font_data_url(
      source_sans_pro_regular_ttf_bytes, corpus, source_sans_pro_regular_data,
    )
  } else {
    source_sans_pro_regular_data
  }
  let semibold_data = if d2_has_any_trigger(source, markdown_triggers) {
    d2_subset_font_data_url(
      source_sans_pro_semibold_ttf_bytes, corpus, source_sans_pro_semibold_data,
    )
  } else {
    source_sans_pro_semibold_data
  }
  let bold_data = if d2_has_any_trigger(source, bold_triggers) {
    d2_subset_font_data_url(
      source_sans_pro_bold_ttf_bytes, corpus, source_sans_pro_bold_data,
    )
  } else {
    source_sans_pro_bold_data
  }
  let italic_data = if d2_has_any_trigger(source, italic_triggers) {
    d2_subset_font_data_url(
      source_sans_pro_italic_ttf_bytes, corpus, source_sans_pro_italic_data,
    )
  } else {
    source_sans_pro_italic_data
  }
  let mono_regular_data = if d2_has_any_trigger(source, mono_triggers) {
    d2_subset_font_data_url(
      source_code_pro_regular_ttf_bytes, corpus, source_code_pro_regular_data,
    )
  } else {
    source_code_pro_regular_data
  }
  let mono_bold_data = if d2_has_any_trigger(source, mono_bold_triggers) {
    d2_subset_font_data_url(
      source_code_pro_bold_ttf_bytes, corpus, source_code_pro_bold_data,
    )
  } else {
    source_code_pro_bold_data
  }
  let mono_italic_data = if d2_has_any_trigger(source, mono_italic_triggers) {
    d2_subset_font_data_url(
      source_code_pro_italic_ttf_bytes, corpus, source_code_pro_italic_data,
    )
  } else {
    source_code_pro_italic_data
  }
  append_on_trigger(
    out,
    source,
    regular_text_triggers,
    "\n.\{diagram_hash} .text {\n\tfont-family: \"\{diagram_hash}-font-regular\";\n}\n@font-face {\n\tfont-family: \{diagram_hash}-font-regular;\n\tsrc: url(\"\{regular_data}\");\n}",
  )
  append_on_trigger(
    out,
    source,
    markdown_triggers,
    "\n@font-face {\n\tfont-family: \{diagram_hash}-font-semibold;\n\tsrc: url(\"\{semibold_data}\");\n}",
  )
  append_on_trigger(
    out,
    source,
    ["text-underline"],
    "\n.text-underline {\n\ttext-decoration: underline;\n}",
  )
  append_on_trigger(
    out,
    source,
    ["text-link"],
    "\n.text-link {\n\tfill: blue;\n}\n\n.text-link:visited {\n\tfill: purple;\n}",
  )
  append_on_trigger(
    out,
    source,
    ["animated-connection"],
    "\n@keyframes dashdraw {\n\tfrom {\n\t\tstroke-dashoffset: 0;\n\t}\n}\n",
  )
  append_on_trigger(
    out,
    source,
    ["animated-shape"],
    "\n@keyframes shapeappear {\n    0%, 100% { transform: translateY(0); filter: drop-shadow(0px 0px 0px rgba(0,0,0,0)); }\n    50% { transform: translateY(-4px); filter: drop-shadow(0px 12.6px 25.2px rgba(50,50,93,0.25)) drop-shadow(0px 7.56px 15.12px rgba(0,0,0,0.1)); }\n}\n.animated-shape {\n\tanimation: shapeappear 1s linear infinite;\n}\n",
  )
  append_on_trigger(
    out,
    source,
    ["appendix-icon"],
    "\n.appendix-icon {\n\tfilter: drop-shadow(0px 0px 32px rgba(31, 36, 58, 0.1));\n}",
  )
  append_on_trigger(
    out,
    source,
    bold_triggers,
    "\n.\{diagram_hash} .text-bold {\n\tfont-family: \"\{diagram_hash}-font-bold\";\n}\n@font-face {\n\tfont-family: \{diagram_hash}-font-bold;\n\tsrc: url(\"\{bold_data}\");\n}",
  )
  append_on_trigger(
    out,
    source,
    italic_triggers,
    "\n.\{diagram_hash} .text-italic {\n\tfont-family: \"\{diagram_hash}-font-italic\";\n}\n@font-face {\n\tfont-family: \{diagram_hash}-font-italic;\n\tsrc: url(\"\{italic_data}\");\n}",
  )
  append_on_trigger(
    out,
    source,
    mono_triggers,
    "\n.\{diagram_hash} .text-mono {\n\tfont-family: \"\{diagram_hash}-font-mono\";\n}\n@font-face {\n\tfont-family: \{diagram_hash}-font-mono;\n\tsrc: url(\"\{mono_regular_data}\");\n}",
  )
  append_on_trigger(
    out,
    source,
    mono_bold_triggers,
    "\n.\{diagram_hash} .text-mono-bold {\n\tfont-family: \"\{diagram_hash}-font-mono-bold\";\n}\n@font-face {\n\tfont-family: \{diagram_hash}-font-mono-bold;\n\tsrc: url(\"\{mono_bold_data}\");\n}",
  )
  append_on_trigger(
    out,
    source,
    mono_italic_triggers,
    "\n.\{diagram_hash} .text-mono-italic {\n\tfont-family: \"\{diagram_hash}-font-mono-italic\";\n}\n@font-face {\n\tfont-family: \{diagram_hash}-font-mono-italic;\n\tsrc: url(\"\{mono_italic_data}\");\n}",
  )
  @xml_emit.Element::new("style")
  .attr("type", "text/css")
  .cdata(out.to_string())
  .build()
}

///|
fn d2_legend_corpus(legend : @graph.LegendInput) -> String {
  let sb = StringBuilder::new()
  match legend.title {
    Some(title) =>
      if title == "" {
        sb.write_string("Legend")
      } else {
        sb.write_string(title)
      }
    None => sb.write_string("Legend")
  }
  for entry in legend.entries {
    match entry {
      @graph.ShapeEntry(label~, ..) => sb.write_string(label)
      @graph.ConnectionEntry(label~, ..) => sb.write_string(label)
      // D2 GetCorpus includes legend shape/connection labels only.
      @graph.CustomEntry(..) => ()
      @graph.Separator => ()
    }
  }
  sb.to_string()
}

///|
fn d2_shape_structured_corpus(
  shape : Shape,
  all_shapes : Array[Shape],
) -> String {
  let sb = StringBuilder::new()
  match shape.shape_type {
    Class =>
      for child in object_children(shape, all_shapes) {
        let class_member = class_member_from_shape(child)
        sb.write_string(class_member.name)
        sb.write_string(class_member.type_name)
        sb.write_string(class_member.visibility)
      }
    SqlTable =>
      for child in object_children(shape, all_shapes) {
        sb.write_string(get_short_name(child.id))
        sb.write_string(child.label)
        sb.write_string(sql_table_constraint_abbr(child))
      }
    _ => ()
  }
  sb.to_string()
}

///|
fn d2_append_graph_corpus(sb : StringBuilder, graph : Diagram) -> Unit {
  let mut appendix_count = 0
  for shape in graph.shapes {
    sb.write_string(shape.label)
    match shape.tooltip {
      Some(tooltip) =>
        if tooltip != "" {
          sb.write_string(tooltip)
          appendix_count = appendix_count + 1
          sb.write_string(appendix_count.to_string())
        }
      None => ()
    }
    match shape.link {
      Some(link) =>
        if link != "" {
          sb.write_string(link)
          appendix_count = appendix_count + 1
          sb.write_string(appendix_count.to_string())
        }
      None => ()
    }
    sb.write_string(d2_shape_structured_corpus(shape, graph.shapes))
  }
  for edge in graph.connections {
    sb.write_string(edge.label)
    match edge.src_arrowhead_label {
      Some(label) => sb.write_string(label)
      None => ()
    }
    match edge.dst_arrowhead_label {
      Some(label) => sb.write_string(label)
      None => ()
    }
  }
  match graph.legend {
    Some(legend) =>
      if !legend.is_empty() {
        sb.write_string(d2_legend_corpus(legend))
      }
    None => ()
  }
  for child in graph.layers {
    d2_append_graph_corpus(sb, child)
  }
  for child in graph.scenarios {
    d2_append_graph_corpus(sb, child)
  }
  for child in graph.steps {
    d2_append_graph_corpus(sb, child)
  }
}

///|

///|
#warnings("-unused_value")
fn d2_diagram_corpus(graph : Diagram) -> String {
  let sb = StringBuilder::new()
  d2_append_graph_corpus(sb, graph)
  sb.to_string()
}

///|
fn replace_all(text : String, old : String, new : String) -> String {
  if old == "" {
    return text
  }
  text.split(old).collect().join(new)
}

///|
fn d2_markdown_styles(diagram_hash : String) -> String {
  let mut css = markdown_css_template
  css = replace_all(css, ".md", ".\{diagram_hash} .md")
  css = replace_all(css, "font-italic", "\{diagram_hash}-font-italic")
  css = replace_all(css, "font-bold", "\{diagram_hash}-font-bold")
  css = replace_all(css, "font-mono", "\{diagram_hash}-font-mono")
  css = replace_all(css, "font-regular", "\{diagram_hash}-font-regular")
  css = replace_all(css, "font-semibold", "\{diagram_hash}-font-semibold")
  if !css.has_suffix("\n") {
    css = css + "\n"
  }
  // Keep CSS bytes unescaped to match d2's markdown style emission.
  @xml_emit.Element::new("style").attr("type", "text/css").raw(css).build()
}

///|
fn d2_fnv32a(text : String) -> Int {
  let mut h : Int = -2128831035
  let bytes = @utf8.encode(text[:])
  for b in bytes {
    h = (h ^ b.to_int()) & 0xffffffff
    h = (h * 16777619) & 0xffffffff
  }
  h
}

///|
fn d2_u32_decimal(v : Int) -> String {
  if v < 0 {
    Json::number(v.to_double() + 4294967296.0).stringify(escape_slash=false)
  } else {
    v.to_string()
  }
}

///|
fn d2_secret_hash(text : String) -> String {
  d2_u32_decimal(d2_fnv32a(text + "lalalas"))
}

///|
priv struct D2JsonField {
  key : String
  value : String
}

///|
fn d2_json_field(key : String, value : String) -> D2JsonField {
  { key, value }
}

///|
fn d2_json_string(value : String) -> String {
  Json::string(value).stringify(escape_slash=false)
}

///|
fn d2_json_number(value : Double) -> String {
  Json::number(value).stringify(escape_slash=false)
}

///|
fn d2_json_int(value : Int) -> String {
  value.to_string()
}

///|
fn d2_json_bool(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn d2_json_array(values : Array[String]) -> String {
  let sb = StringBuilder::new()
  sb.write_char('[')
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_string(values[i])
  }
  sb.write_char(']')
  sb.to_string()
}

///|
fn d2_json_string_array(values : Array[String]) -> String {
  let quoted : Array[String] = []
  for value in values {
    quoted.push(d2_json_string(value))
  }
  d2_json_array(quoted)
}

///|
fn d2_json_object(fields : Array[D2JsonField]) -> String {
  let sb = StringBuilder::new()
  sb.write_char('{')
  for i = 0; i < fields.length(); i = i + 1 {
    if i > 0 {
      sb.write_char(',')
    }
    let field = fields[i]
    sb.write_char('"')
    sb.write_string(field.key)
    sb.write_string("\":")
    sb.write_string(field.value)
  }
  sb.write_char('}')
  sb.to_string()
}

///|
fn d2_json_text(
  label : String,
  font_size : Int,
  font_family : String,
  language : String,
  color : String,
  italic : Bool,
  bold : Bool,
  underline : Bool,
  label_width : Int,
  label_height : Int,
) -> String {
  d2_json_object([
    d2_json_field("label", d2_json_string(label)),
    d2_json_field("fontSize", d2_json_int(font_size)),
    d2_json_field("fontFamily", d2_json_string(font_family)),
    d2_json_field("language", d2_json_string(language)),
    d2_json_field("color", d2_json_string(color)),
    d2_json_field("italic", d2_json_bool(italic)),
    d2_json_field("bold", d2_json_bool(bold)),
    d2_json_field("underline", d2_json_bool(underline)),
    d2_json_field("labelWidth", d2_json_int(label_width)),
    d2_json_field("labelHeight", d2_json_int(label_height)),
  ])
}

///|
fn d2_hash_shape_type(shape_type : ShapeType) -> String {
  match shape_type {
    Circle => "oval"
    Square => "rectangle"
    C4Person => "c4-person"
    C4Container => "rectangle"
    _ => shape_type_name(shape_type)
  }
}

///|
fn d2_hash_arrowhead_value(arrowhead : ArrowheadType) -> String {
  match arrowhead {
    @graph.None => "none"
    Triangle => "triangle"
    Diamond => "diamond"
    Circle => "circle"
    Open => "unfilled-triangle"
    Line => "line"
    CfOne => "cf-one"
    CfMany => "cf-many"
    CfOneRequired => "cf-one-required"
    CfManyRequired => "cf-many-required"
    CfOneOptional => "cf-one"
    CfManyOptional => "cf-many"
  }
}

///|
fn d2_hash_class_visibility(token : String) -> String {
  match token {
    "#" => "protected"
    "-" => "private"
    _ => "public"
  }
}

///|
fn d2_hash_shape_language(shape : Shape) -> String {
  match object_language(shape) {
    Some(tag) => if tag == "go" { "golang" } else { tag }
    None => ""
  }
}

///|
fn d2_config_uses_mono(config : SvgConfig) -> Bool {
  config.font_family.to_lower().contains("mono")
}

///|
fn d2_hash_shape_font_family(shape : Shape, config : SvgConfig) -> String {
  if d2_config_uses_mono(config) || style_is_mono(shape.style.font_family) {
    "mono"
  } else {
    style_string(shape.style.font_family, "DEFAULT")
  }
}

///|
fn d2_hash_edge_font_family(edge : Connection, config : SvgConfig) -> String {
  if d2_config_uses_mono(config) || style_is_mono(edge.style.font_family) {
    "mono"
  } else {
    style_string(edge.style.font_family, "DEFAULT")
  }
}

///|
fn d2_hash_shape_label_dims(shape : Shape, config : SvgConfig) -> (Int, Int) {
  if shape.label == "" {
    return (0, 0)
  }
  match (shape.label_width, shape.label_height) {
    (Some(width), Some(height)) =>
      if width > 0.0 && height > 0.0 {
        return (width.to_int(), height.to_int())
      }
    _ => ()
  }
  match shape.label_box {
    Some(label_box) =>
      if label_box.width > 0.0 && label_box.height > 0.0 {
        return (label_box.width.to_int(), label_box.height.to_int())
      }
    None => ()
  }
  let default_font_size = default_object_font_size(shape, config)
  let font_size = style_int(shape.style.font_size, default_font_size)
  let is_mono = shape.shape_type == Code ||
    d2_config_uses_mono(config) ||
    style_is_mono(shape.style.font_family)
  let is_bold = style_bool(shape.style.bold, default_object_bold(shape))
  let is_italic = style_bool(shape.style.italic, false)
  let dims = @text_metrics.measure_label(
    shape.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  (dims.width.to_int(), dims.height.to_int())
}

///|
fn d2_hash_edge_label_dims(edge : Connection, config : SvgConfig) -> (Int, Int) {
  if edge.label == "" {
    return (0, 0)
  }
  match edge.label_box {
    Some(label_box) =>
      if label_box.width > 0.0 && label_box.height > 0.0 {
        return (label_box.width.to_int(), label_box.height.to_int())
      }
    None => ()
  }
  let font_size = style_int(edge.style.font_size, config.font_size)
  let dims = @text_metrics.measure_edge_label(edge.label, font_size)
  (dims.width.to_int(), dims.height.to_int())
}

///|
fn d2_hash_shape_label_position(shape : Shape, config : SvgConfig) -> String? {
  let _ = config
  if shape.label == "" {
    return None
  }
  match shape.label_position {
    Some(position) => return Some(position)
    None => ()
  }
  match shape.shape_type {
    Class | SqlTable | Code => return None
    _ => ()
  }
  let is_grid_container = is_container(shape) &&
    (shape.grid_rows is Some(_) || shape.grid_columns is Some(_))
  if is_container(shape) && !is_grid_container {
    return Some("INSIDE_TOP_CENTER")
  }
  if is_grid_container {
    return Some("INSIDE_TOP_CENTER")
  }
  if has_outside_bottom_label(shape) {
    return Some("OUTSIDE_BOTTOM_CENTER")
  }
  Some("INSIDE_MIDDLE_CENTER")
}

///|
fn d2_hash_sql_constraints(child : Shape) -> String {
  let constraints = shape_sql_constraints(child)
  if constraints.is_empty() {
    "null"
  } else {
    d2_json_string_array(constraints)
  }
}

///|
fn d2_hash_sql_column_text(label : String) -> String {
  let dims = @text_metrics.measure_label(label, 20, false, false, false)
  d2_json_text(
    label,
    0,
    "",
    "",
    "",
    false,
    false,
    false,
    dims.width.to_int(),
    dims.height.to_int(),
  )
}

///|
fn d2_hash_shape_json(
  shape : Shape,
  all_shapes : Array[Shape],
  config : SvgConfig,
) -> String {
  let fields : Array[D2JsonField] = []
  let (x, y, width, height) = match shape.box {
    Some(box) =>
      (box.x.to_int(), box.y.to_int(), box.width.to_int(), box.height.to_int())
    None => (0, 0, 0, 0)
  }
  let default_fill = match shape.shape_type {
    Class | SqlTable => "N1"
    _ => "N7"
  }
  let default_stroke = match shape.shape_type {
    Class | SqlTable => "N7"
    _ => "N1"
  }
  let font_size = style_int(
    shape.style.font_size,
    default_object_font_size(shape, config),
  )
  let font_family = d2_hash_shape_font_family(shape, config)
  let language = d2_hash_shape_language(shape)
  let color = style_string(shape.style.font_color, "N1")
  let is_italic = style_bool(shape.style.italic, false)
  let is_bold = style_bool(shape.style.bold, default_object_bold(shape))
  let is_underline = style_bool(shape.style.underline, false)
  let (label_width, label_height) = d2_hash_shape_label_dims(shape, config)

  fields.push(d2_json_field("id", d2_json_string(d2_output_abs_id(shape.id))))
  fields.push(
    d2_json_field("type", d2_json_string(d2_hash_shape_type(shape.shape_type))),
  )
  if !shape.classes.is_empty() {
    fields.push(d2_json_field("classes", d2_json_string_array(shape.classes)))
  }
  fields.push(
    d2_json_field(
      "pos",
      d2_json_object([
        d2_json_field("x", d2_json_int(x)),
        d2_json_field("y", d2_json_int(y)),
      ]),
    ),
  )
  fields.push(d2_json_field("width", d2_json_int(width)))
  fields.push(d2_json_field("height", d2_json_int(height)))
  fields.push(
    d2_json_field(
      "opacity",
      d2_json_number(style_double(shape.style.opacity, 1.0)),
    ),
  )
  fields.push(
    d2_json_field(
      "strokeDash",
      d2_json_number(style_double(shape.style.stroke_dash, 0.0)),
    ),
  )
  fields.push(
    d2_json_field(
      "strokeWidth",
      d2_json_int(
        style_double(shape.style.stroke_width, config.default_stroke_width).to_int(),
      ),
    ),
  )
  fields.push(
    d2_json_field(
      "borderRadius",
      d2_json_int(style_double(shape.style.border_radius, 0.0).to_int()),
    ),
  )
  fields.push(
    d2_json_field(
      "fill",
      d2_json_string(style_string(shape.style.fill, default_fill)),
    ),
  )
  match style_string_opt(shape.style.fill_pattern) {
    Some(fill_pattern) =>
      if fill_pattern != "" {
        fields.push(d2_json_field("fillPattern", d2_json_string(fill_pattern)))
      }
    None => ()
  }
  fields.push(
    d2_json_field(
      "stroke",
      d2_json_string(style_string(shape.style.stroke, default_stroke)),
    ),
  )
  fields.push(
    d2_json_field(
      "animated",
      d2_json_bool(style_bool(shape.style.animated, false)),
    ),
  )
  fields.push(
    d2_json_field("shadow", d2_json_bool(style_bool(shape.style.shadow, false))),
  )
  fields.push(
    d2_json_field("3d", d2_json_bool(style_bool(shape.style.three_d, false))),
  )
  fields.push(
    d2_json_field(
      "multiple",
      d2_json_bool(style_bool(shape.style.multiple, false)),
    ),
  )
  fields.push(
    d2_json_field(
      "double-border",
      d2_json_bool(style_bool(shape.style.double_border, false)),
    ),
  )
  fields.push(
    d2_json_field("tooltip", d2_json_string(shape.tooltip.unwrap_or(""))),
  )
  fields.push(
    d2_json_field(
      "tooltipPosition",
      d2_json_string(shape.tooltip_position.unwrap_or("")),
    ),
  )
  fields.push(d2_json_field("link", d2_json_string(shape.link.unwrap_or(""))))
  fields.push(
    d2_json_field(
      "icon",
      match shape.icon {
        Some(icon) => d2_json_string(icon)
        None => "null"
      },
    ),
  )
  fields.push(
    d2_json_field(
      "iconPosition",
      d2_json_string(shape.icon_position.unwrap_or("")),
    ),
  )
  fields.push(d2_json_field("blend", d2_json_bool(false)))

  match shape.shape_type {
    Class => {
      let class_fields : Array[String] = []
      let class_methods : Array[String] = []
      for child in object_children(shape, all_shapes) {
        let class_member = class_member_from_shape(child)
        let visibility = d2_hash_class_visibility(class_member.visibility)
        if class_member.is_method {
          class_methods.push(
            d2_json_object([
              d2_json_field("name", d2_json_string(class_member.name)),
              d2_json_field("return", d2_json_string(class_member.type_name)),
              d2_json_field("visibility", d2_json_string(visibility)),
              d2_json_field("underline", d2_json_bool(class_member.underline)),
            ]),
          )
        } else {
          class_fields.push(
            d2_json_object([
              d2_json_field("name", d2_json_string(class_member.name)),
              d2_json_field("type", d2_json_string(class_member.type_name)),
              d2_json_field("visibility", d2_json_string(visibility)),
              d2_json_field("underline", d2_json_bool(class_member.underline)),
            ]),
          )
        }
      }
      fields.push(d2_json_field("fields", d2_json_array(class_fields)))
      fields.push(d2_json_field("methods", d2_json_array(class_methods)))
      fields.push(d2_json_field("columns", "null"))
    }
    SqlTable => {
      let columns : Array[String] = []
      for child in object_children(shape, all_shapes) {
        columns.push(
          d2_json_object([
            d2_json_field(
              "name",
              d2_hash_sql_column_text(get_short_name(child.id)),
            ),
            d2_json_field("type", d2_hash_sql_column_text(child.label)),
            d2_json_field("constraint", d2_hash_sql_constraints(child)),
            d2_json_field("reference", d2_json_string("")),
          ]),
        )
      }
      fields.push(d2_json_field("fields", "null"))
      fields.push(d2_json_field("methods", "null"))
      fields.push(d2_json_field("columns", d2_json_array(columns)))
    }
    _ => {
      fields.push(d2_json_field("fields", "null"))
      fields.push(d2_json_field("methods", "null"))
      fields.push(d2_json_field("columns", "null"))
    }
  }

  fields.push(d2_json_field("label", d2_json_string(shape.label)))
  fields.push(d2_json_field("fontSize", d2_json_int(font_size)))
  fields.push(d2_json_field("fontFamily", d2_json_string(font_family)))
  fields.push(d2_json_field("language", d2_json_string(language)))
  fields.push(d2_json_field("color", d2_json_string(color)))
  fields.push(d2_json_field("italic", d2_json_bool(is_italic)))
  fields.push(d2_json_field("bold", d2_json_bool(is_bold)))
  fields.push(d2_json_field("underline", d2_json_bool(is_underline)))
  fields.push(d2_json_field("labelWidth", d2_json_int(label_width)))
  fields.push(d2_json_field("labelHeight", d2_json_int(label_height)))
  match d2_hash_shape_label_position(shape, config) {
    Some(position) =>
      fields.push(d2_json_field("labelPosition", d2_json_string(position)))
    None => ()
  }
  fields.push(d2_json_field("zIndex", d2_json_int(shape.z_index)))
  fields.push(d2_json_field("level", d2_json_int(get_object_depth(shape.id))))

  match shape.shape_type {
    Class | SqlTable => {
      fields.push(d2_json_field("primaryAccentColor", d2_json_string("B2")))
      fields.push(d2_json_field("secondaryAccentColor", d2_json_string("AA2")))
      fields.push(d2_json_field("neutralAccentColor", d2_json_string("N2")))
    }
    _ => ()
  }

  d2_json_object(fields)
}

///|
fn d2_hash_connection_json_with_repeat_index(
  edge : Connection,
  config : SvgConfig,
  repeat_index : Int,
) -> String {
  let fields : Array[D2JsonField] = []
  let stroke_default = d2_default_edge_stroke_token(edge)
  let font_size = style_int(edge.style.font_size, config.font_size)
  let font_family = d2_hash_edge_font_family(edge, config)
  let color = style_string(edge.style.font_color, "N2")
  let (label_width, label_height) = d2_hash_edge_label_dims(edge, config)
  let route_json : Array[String] = []
  for point in edge.route {
    route_json.push(
      d2_json_object([
        d2_json_field("x", d2_json_number(point.x)),
        d2_json_field("y", d2_json_number(point.y)),
      ]),
    )
  }

  fields.push(
    d2_json_field(
      "id",
      d2_json_string(d2_connection_abs_id(edge, repeat_index)),
    ),
  )
  fields.push(
    d2_json_field("src", d2_json_string(d2_output_abs_id(edge.src_id))),
  )
  fields.push(
    d2_json_field(
      "srcArrow",
      d2_json_string(d2_hash_arrowhead_value(edge.src_arrowhead)),
    ),
  )
  fields.push(
    d2_json_field("dst", d2_json_string(d2_output_abs_id(edge.dst_id))),
  )
  fields.push(
    d2_json_field(
      "dstArrow",
      d2_json_string(d2_hash_arrowhead_value(edge.dst_arrowhead)),
    ),
  )
  fields.push(
    d2_json_field(
      "opacity",
      d2_json_number(style_double(edge.style.opacity, 1.0)),
    ),
  )
  fields.push(
    d2_json_field(
      "strokeDash",
      d2_json_number(style_double(edge.style.stroke_dash, 0.0)),
    ),
  )
  fields.push(
    d2_json_field(
      "strokeWidth",
      d2_json_int(
        style_double(edge.style.stroke_width, config.default_stroke_width).to_int(),
      ),
    ),
  )
  fields.push(
    d2_json_field(
      "stroke",
      d2_json_string(style_string(edge.style.stroke, stroke_default)),
    ),
  )
  match style_string_opt(edge.style.fill) {
    Some(fill) =>
      if fill != "" {
        fields.push(d2_json_field("fill", d2_json_string(fill)))
      }
    None => ()
  }
  fields.push(
    d2_json_field(
      "borderRadius",
      d2_json_number(style_double(edge.style.border_radius, 10.0)),
    ),
  )
  fields.push(d2_json_field("label", d2_json_string(edge.label)))
  fields.push(d2_json_field("fontSize", d2_json_int(font_size)))
  fields.push(d2_json_field("fontFamily", d2_json_string(font_family)))
  fields.push(d2_json_field("language", d2_json_string("")))
  fields.push(d2_json_field("color", d2_json_string(color)))
  fields.push(
    d2_json_field("italic", d2_json_bool(style_bool(edge.style.italic, true))),
  )
  fields.push(
    d2_json_field("bold", d2_json_bool(style_bool(edge.style.bold, false))),
  )
  fields.push(
    d2_json_field(
      "underline",
      d2_json_bool(style_bool(edge.style.underline, false)),
    ),
  )
  fields.push(d2_json_field("labelWidth", d2_json_int(label_width)))
  fields.push(d2_json_field("labelHeight", d2_json_int(label_height)))
  fields.push(
    d2_json_field(
      "labelPosition",
      if edge.label == "" {
        d2_json_string("")
      } else {
        d2_json_string("INSIDE_MIDDLE_CENTER")
      },
    ),
  )
  fields.push(d2_json_field("labelPercentage", d2_json_number(0.0)))
  fields.push(d2_json_field("link", d2_json_string("")))
  fields.push(d2_json_field("route", d2_json_array(route_json)))
  if edge.is_curve {
    fields.push(d2_json_field("isCurve", d2_json_bool(true)))
  }
  fields.push(
    d2_json_field(
      "animated",
      d2_json_bool(style_bool(edge.style.animated, false)),
    ),
  )
  fields.push(d2_json_field("tooltip", d2_json_string("")))
  fields.push(d2_json_field("icon", "null"))
  fields.push(d2_json_field("zIndex", d2_json_int(edge.z_index)))
  d2_json_object(fields)
}

///|
fn d2_default_edge_stroke_token(edge : Connection) -> String {
  if style_double(edge.style.stroke_dash, 0.0) != 0.0 {
    "B2"
  } else {
    "B1"
  }
}

///|
fn d2_hash_root_json(graph : Diagram) -> String {
  let fill = match graph.config {
    Some(_) => style_string(graph.root.style.fill, "N7")
    None => "N7"
  }
  d2_json_object([
    d2_json_field("id", d2_json_string("")),
    d2_json_field("type", d2_json_string("")),
    d2_json_field(
      "pos",
      d2_json_object([
        d2_json_field("x", d2_json_int(0)),
        d2_json_field("y", d2_json_int(0)),
      ]),
    ),
    d2_json_field("width", d2_json_int(0)),
    d2_json_field("height", d2_json_int(0)),
    d2_json_field("opacity", d2_json_number(0.0)),
    d2_json_field("strokeDash", d2_json_number(0.0)),
    d2_json_field("strokeWidth", d2_json_int(0)),
    d2_json_field("borderRadius", d2_json_int(0)),
    d2_json_field("fill", d2_json_string(fill)),
    d2_json_field("stroke", d2_json_string("")),
    d2_json_field("animated", d2_json_bool(false)),
    d2_json_field("shadow", d2_json_bool(false)),
    d2_json_field("3d", d2_json_bool(false)),
    d2_json_field("multiple", d2_json_bool(false)),
    d2_json_field("double-border", d2_json_bool(false)),
    d2_json_field("tooltip", d2_json_string("")),
    d2_json_field("link", d2_json_string("")),
    d2_json_field("icon", "null"),
    d2_json_field("iconPosition", d2_json_string("")),
    d2_json_field("blend", d2_json_bool(false)),
    d2_json_field("fields", "null"),
    d2_json_field("methods", "null"),
    d2_json_field("columns", "null"),
    d2_json_field("label", d2_json_string("")),
    d2_json_field("fontSize", d2_json_int(0)),
    d2_json_field("fontFamily", d2_json_string("")),
    d2_json_field("language", d2_json_string("")),
    d2_json_field("color", d2_json_string("")),
    d2_json_field("italic", d2_json_bool(false)),
    d2_json_field("bold", d2_json_bool(false)),
    d2_json_field("underline", d2_json_bool(false)),
    d2_json_field("labelWidth", d2_json_int(0)),
    d2_json_field("labelHeight", d2_json_int(0)),
    d2_json_field("zIndex", d2_json_int(0)),
    d2_json_field("level", d2_json_int(0)),
  ])
}

///|
fn d2_hash_string_map(m : Map[String, String]) -> String {
  let keys : Array[String] = []
  for key, _ in m {
    keys.push(key)
  }
  keys.sort_by(fn(a, b) { a.compare(b) })
  let fields : Array[D2JsonField] = []
  for key in keys {
    fields.push(d2_json_field(key, d2_json_string(m[key])))
  }
  d2_json_object(fields)
}

///|
fn d2_hash_config_data_map(m : Map[String, @diagram.ConfigDataValue]) -> String {
  let keys : Array[String] = []
  for key, _ in m {
    keys.push(key)
  }
  keys.sort_by(fn(a, b) { a.compare(b) })
  let fields : Array[D2JsonField] = []
  for key in keys {
    let value = match m[key] {
      @diagram.ConfigDataValue::Text(text) => d2_json_string(text)
      @diagram.ConfigDataValue::StringArray(items) =>
        d2_json_string_array(items)
    }
    fields.push(d2_json_field(key, value))
  }
  d2_json_object(fields)
}

///|
fn d2_hash_config_json(graph : Diagram) -> String? {
  match graph.config {
    Some(cfg) => {
      let fields : Array[D2JsonField] = []
      fields.push(
        d2_json_field("sketch", d2_json_bool(cfg.sketch.unwrap_or(false))),
      )
      fields.push(
        d2_json_field("themeID", d2_json_int(cfg.theme_id.unwrap_or(0))),
      )
      fields.push(
        d2_json_field(
          "darkThemeID",
          match cfg.dark_theme_id {
            Some(v) => d2_json_int(v)
            None => "null"
          },
        ),
      )
      fields.push(
        d2_json_field(
          "pad",
          match cfg.pad {
            Some(v) => d2_json_int(v.to_int())
            None => "null"
          },
        ),
      )
      fields.push(
        d2_json_field(
          "center",
          match cfg.center {
            Some(v) => d2_json_bool(v)
            None => "null"
          },
        ),
      )
      fields.push(
        d2_json_field(
          "layoutEngine",
          match cfg.layout_engine {
            Some(v) => d2_json_string(v)
            None => "null"
          },
        ),
      )
      if !cfg.theme_overrides.is_empty() {
        fields.push(
          d2_json_field(
            "themeOverrides",
            d2_hash_string_map(cfg.theme_overrides),
          ),
        )
      }
      if !cfg.dark_theme_overrides.is_empty() {
        fields.push(
          d2_json_field(
            "darkThemeOverrides",
            d2_hash_string_map(cfg.dark_theme_overrides),
          ),
        )
      }
      if !cfg.data.is_empty() {
        fields.push(d2_json_field("data", d2_hash_config_data_map(cfg.data)))
      }
      Some(d2_json_object(fields))
    }
    None => None
  }
}

///|

///|
#warnings("-unused_value")
fn d2_hash_diagram_bytes(graph : Diagram, config : SvgConfig) -> String {
  let out = StringBuilder::new()
  let shapes_json : Array[String] = []
  for shape in graph.shapes {
    shapes_json.push(d2_hash_shape_json(shape, graph.shapes, config))
  }
  out.write_string(d2_json_array(shapes_json))
  let connections_json : Array[String] = []
  let repeat_indices = d2_connection_repeat_indices(graph.connections)
  for i, edge in graph.connections {
    connections_json.push(
      d2_hash_connection_json_with_repeat_index(edge, config, repeat_indices[i]),
    )
  }
  out.write_string(d2_json_array(connections_json))
  out.write_string(d2_hash_root_json(graph))
  match d2_hash_config_json(graph) {
    Some(config_json) => out.write_string(config_json)
    None => ()
  }
  for child in graph.layers {
    out.write_string(d2_hash_diagram_bytes(child, config))
  }
  for child in graph.scenarios {
    out.write_string(d2_hash_diagram_bytes(child, config))
  }
  for child in graph.steps {
    out.write_string(d2_hash_diagram_bytes(child, config))
  }
  out.to_string()
}

///|
fn diagram_scope_class(graph : Diagram, config : SvgConfig) -> String {
  graph.hash_id(config.salt)
}

///|
fn d2_wrapper_class(id : String) -> String {
  d2_shape_wrapper_class(id)
}

///|
fn d2_shape_wrapper_class(id : String) -> String {
  let normalized_id = d2_output_abs_id(id)
  d2_wrapper_class_base64(normalized_id)
}

///|
fn d2_connection_wrapper_class(id : String) -> String {
  d2_wrapper_class_base64(id)
}

///|
fn d2_wrapper_class_base64(id : String) -> String {
  let escaped = replace_all(@svg.escape_xml(id), "&quot;", "&#34;")
  @base64.encode(@utf8.encode(escaped[:]), url_safe=true)
}

///|
fn d2_arrow_string(edge : Connection) -> String {
  if edge.src_arrow && edge.dst_arrow {
    "<->"
  } else if edge.src_arrow {
    "<-"
  } else if edge.dst_arrow {
    "->"
  } else {
    "--"
  }
}

///|
fn d2_split_abs_id(id : String) -> Array[String] {
  let parts : Array[String] = []
  if id != "" {
    for part in id.split(".") {
      parts.push(part.to_string())
    }
  }
  parts
}

///|
fn d2_output_abs_id_parts(id : String) -> Array[String] {
  let parts : Array[String] = []
  for raw_part in d2_split_abs_id(id) {
    parts.push(d2_format_key_segment(raw_part))
  }
  parts
}

///|
fn d2_output_abs_id(id : String) -> String {
  d2_output_abs_id_parts(id).join(".")
}

///|
fn d2_has_surrounding_whitespace(s : String) -> Bool {
  if s.length() == 0 {
    false
  } else {
    s.trim().length() != s.length()
  }
}

///|
fn d2_contains_char(s : String, target : Char) -> Bool {
  for c in s {
    if c == target {
      return true
    }
  }
  false
}

///|
fn d2_escape_single_quoted_value(s : String) -> String {
  let b = StringBuilder::new()
  for r in s {
    match r {
      '\'' => b.write_char('\'')
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
        continue
      }
      _ => ()
    }
    b.write_char(r)
  }
  b.to_string()
}

///|
fn d2_escape_double_quoted_value(s : String) -> String {
  let b = StringBuilder::new()
  for r in s {
    match r {
      '"' | '\\' => b.write_char('\\')
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
        continue
      }
      _ => ()
    }
    b.write_char(r)
  }
  b.to_string()
}

///|
fn d2_escape_unquoted_key_value(s : String) -> String {
  if s.length() == 0 {
    return "\"\""
  }
  if s.to_lower() == "null" {
    return "'null'"
  }
  let key_specials = "#;\n\\{}[]'\"|:.-<>*&()@&"
  let chars = s.to_array()
  let b = StringBuilder::new()
  for i, r in chars {
    match r {
      '\'' | '"' | '|' => if i == 0 { b.write_char('\\') } else { () }
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
        continue
      }
      _ =>
        if r == '-' {
          if i + 1 < chars.length() && chars[i + 1] == '-' {
            b.write_char('\\')
          }
        } else if r == '&' {
          if i == 0 {
            b.write_char('\\')
          }
        } else if d2_contains_char(key_specials, r) {
          b.write_char('\\')
        }
    }
    b.write_char(r)
  }
  b.to_string()
}

///|
fn d2_is_reserved_for_unquoted_key(s : String) -> Bool {
  let lower = s.to_lower()
  lower == "null" ||
  lower == "suspend" ||
  lower == "unsuspend" ||
  lower == "style" ||
  lower == "shape" ||
  lower == "icon" ||
  lower == "tooltip" ||
  lower == "link" ||
  lower == "near" ||
  lower == "width" ||
  lower == "height" ||
  lower == "top" ||
  lower == "left" ||
  lower == "direction" ||
  lower == "constraint" ||
  lower == "class" ||
  lower == "classes" ||
  lower == "vars" ||
  lower == "grid-rows" ||
  lower == "grid-columns" ||
  lower == "grid-gap" ||
  lower == "horizontal-gap" ||
  lower == "vertical-gap" ||
  lower == "grid-column-span" ||
  lower == "grid-row-span" ||
  lower == "layers" ||
  lower == "scenarios" ||
  lower == "steps"
}

///|
fn d2_format_key_segment(s : String) -> String {
  if s.length() == 0 {
    return "\"\""
  }
  let key_specials = "#;\n\\{}[]'\"|:.-<>*&()@&"
  let chars = s.to_array()
  for i, r in chars {
    if r == '-' {
      if i + 1 < chars.length() && chars[i + 1] != '-' {
        continue
      }
    }
    if d2_contains_char(key_specials, r) {
      if !d2_contains_char(s, '"') {
        return "\"\{d2_escape_double_quoted_value(s)}\""
      }
      if d2_contains_char(s, '\n') {
        return "\"\{d2_escape_double_quoted_value(s)}\""
      }
      return "'\{d2_escape_single_quoted_value(s)}'"
    }
  }
  if d2_has_surrounding_whitespace(s) {
    return "\"\{d2_escape_double_quoted_value(s)}\""
  }
  let mut out = d2_escape_unquoted_key_value(s)
  if d2_is_reserved_for_unquoted_key(out) {
    out = out.to_lower()
  }
  out
}

///|
fn d2_edge_repeat_key(edge : Connection) -> String {
  "\{edge.src_id}\u0000\{edge.src_arrow.to_string()}\u0000\{edge.dst_id}\u0000\{edge.dst_arrow.to_string()}"
}

///|
fn d2_connection_repeat_indices(connections : Array[Connection]) -> Array[Int] {
  let key_counts : Map[String, Int] = {}
  let indices : Array[Int] = []
  for edge in connections {
    let key = d2_edge_repeat_key(edge)
    let index = key_counts.get(key).unwrap_or(0)
    indices.push(index)
    key_counts[key] = index + 1
  }
  indices
}

///|
fn d2_connection_abs_id(edge : Connection, repeat_index : Int) -> String {
  let src_parts = d2_output_abs_id_parts(edge.src_id)
  let dst_parts = d2_output_abs_id_parts(edge.dst_id)
  let common : Array[String] = []
  let mut src_start = 0
  let mut dst_start = 0
  while src_parts.length() - src_start > 1 && dst_parts.length() - dst_start > 1 {
    if src_parts[src_start].to_lower() != dst_parts[dst_start].to_lower() {
      break
    }
    common.push(src_parts[src_start])
    src_start = src_start + 1
    dst_start = dst_start + 1
  }
  let common_key = if common.is_empty() { "" } else { common.join(".") + "." }
  let src_tail : Array[String] = []
  let dst_tail : Array[String] = []
  for i in src_start..<src_parts.length() {
    src_tail.push(src_parts[i])
  }
  for i in dst_start..<dst_parts.length() {
    dst_tail.push(dst_parts[i])
  }
  let src_join = src_tail.join(".")
  let dst_join = dst_tail.join(".")
  "\{common_key}(\{src_join} \{d2_arrow_string(edge)} \{dst_join})[\{repeat_index}]"
}

///|
fn marker_resource_id(
  diagram_hash : String,
  arrowhead : ArrowheadType,
  is_target : Bool,
  stroke : String,
  stroke_width : Double,
) -> String {
  let signature = "\{d2_hash_arrowhead_value(arrowhead)},\{is_target.to_string()},\{stroke_width.to_int().to_string()},\{stroke}"
  "mk-\{diagram_hash}-\{d2_secret_hash(signature)}"
}

///|
fn d2_alignment(config : SvgConfig) -> String {
  if config.center {
    "xMidYMid"
  } else {
    "xMinYMin"
  }
}

///|
fn emit_defs_block(defs : Array[String]) -> String {
  if defs.is_empty() {
    return ""
  }
  let sb = StringBuilder::new()
  sb.write_string("<defs>")
  for def in defs {
    sb.write_string(def)
  }
  sb.write_string("</defs>")
  sb.to_string()
}

///|
fn d2_render_text_spans(text : String, x : Double, height : Double) -> String {
  if !text.contains("\n") {
    return @svg.escape_xml(text)
  }
  let lines = text.split("\n").collect()
  let rendered : Array[String] = []
  for i, line in lines {
    let mut dy = height / lines.length().to_double()
    if i == 0 {
      dy = 0.0
    }
    let line_string = line.to_string()
    let escaped = if line_string == "" {
      " "
    } else {
      @svg.escape_xml(line_string)
    }
    rendered.push(
      "<tspan x=\"\{d2_fixed6(x)}\" dy=\"\{d2_fixed6(dy)}\">\{escaped}</tspan>",
    )
  }
  rendered.join("")
}

///|
fn d2_text_element(
  x : Double,
  y : Double,
  text : String,
  line_height : Double,
  fill : String,
  font_class : String,
  font_size : Int,
  theme : @themes.Theme,
  inline_theme : Bool,
  text_anchor? : String = "middle",
  fill_class_token? : String? = None,
) -> String {
  let classes : Array[String] = [font_class]
  match fill_class_token {
    Some(token) => if token != "" { classes.push("fill-\{token}") }
    None =>
      match d2_theme_token(fill, theme) {
        Some(token) => classes.push("fill-\{token}")
        None => ()
      }
  }
  let class_attr = @svg.escape_xml(classes.join(" "))
  let sb = StringBuilder::new()
  sb.write_string("<text")
  sb.write_string(" x=\"\{d2_fixed6(x)}\"")
  sb.write_string(" y=\"\{d2_fixed6(y)}\"")
  if inline_theme {
    sb.write_string(" fill=\"\{@svg.escape_xml(fill)}\"")
  }
  sb.write_string(" class=\"\{class_attr}\"")
  sb.write_string(
    " style=\"text-anchor:\{text_anchor};font-size:\{font_size}px\"",
  )
  if text == "" {
    sb.write_string(" />")
  } else {
    sb.write_string(">")
    sb.write_string(d2_render_text_spans(text, x, line_height))
    sb.write_string("</text>")
  }
  sb.to_string()
}

///|
fn d2_group_open(
  class_name : String,
  style? : String = "",
  filter? : String = "",
  trailing_space_before_gt? : Bool = false,
) -> String {
  let sb = StringBuilder::new()
  sb.write_string("<g")
  if class_name != "" {
    sb.write_string(" class=\"\{@svg.escape_xml(class_name)}\"")
  }
  if style != "" {
    sb.write_string(" style='\{@svg.escape_xml(style)}'")
  }
  if filter != "" {
    sb.write_string(" filter=\"\{@svg.escape_xml(filter)}\"")
  }
  if trailing_space_before_gt {
    sb.write_string(" ")
  }
  sb.write_string(">")
  sb.to_string()
}

///|
fn d2_font_class_name(
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
  underline : Bool,
) -> String {
  let font_class = if is_mono { "text-mono" } else { "text" }
  let sb = StringBuilder::new()
  sb.write_string(font_class)
  if is_bold {
    sb.write_string("-bold")
  } else if is_italic {
    sb.write_string("-italic")
  }
  if underline {
    sb.write_string(" text-underline")
  }
  sb.to_string()
}

///|
fn d2_stroke_dash_attributes(
  stroke_width : Double,
  dash_gap_size : Double,
) -> (Double, Double) {
  let scale = @math.log10(-0.6 * stroke_width + 10.6) * 0.5 + 0.5
  let scaled_dash_size = stroke_width * dash_gap_size
  let scaled_gap_size = scale * scaled_dash_size
  (scaled_dash_size, scaled_gap_size)
}

///|
fn d2_connection_path_element(
  d : String,
  stroke : String,
  stroke_signature : String,
  stroke_width : Double,
  stroke_dash : Double,
  marker_start : String,
  marker_end : String,
  mask : String,
  animated : Bool,
  theme : @themes.Theme,
  inline_theme : Bool,
  animation_direction? : String = "",
) -> String {
  let classes : Array[String] = ["connection"]
  if animated {
    classes.push("animated-connection")
  }
  let stroke_class_token = match theme_token(stroke_signature) {
    Some(token) => Some(token)
    None => d2_theme_token(stroke, theme)
  }
  match stroke_class_token {
    Some(token) => classes.push("stroke-\{token}")
    None => ()
  }
  let stroke_width_css = if stroke_width.round() == stroke_width {
    stroke_width.to_int().to_string()
  } else {
    d2_fixed6(stroke_width)
  }
  let styles : Array[String] = ["stroke-width:\{stroke_width_css}"]
  let effective_stroke_dash = if stroke_dash == 0.0 && animated {
    5.0
  } else {
    stroke_dash
  }
  if effective_stroke_dash > 0.0 {
    let (dash_size, gap_size) = d2_stroke_dash_attributes(
      stroke_width, effective_stroke_dash,
    )
    styles.push(
      "stroke-dasharray:\{d2_fixed6(dash_size)},\{d2_fixed6(gap_size)}",
    )
    if animated {
      let dash_offset = if marker_start != "" && marker_end == "" {
        10.0
      } else {
        -10.0
      }
      styles.push(
        "stroke-dashoffset:\{d2_fixed6(dash_offset * (dash_size + gap_size))}",
      )
      styles.push(
        "animation: dashdraw \{d2_fixed6(gap_size * 0.5)}s linear infinite",
      )
    }
  }
  if animation_direction != "" {
    styles.push("animation-direction: \{animation_direction}")
  }
  let class_attr = @svg.escape_xml(classes.join(" "))
  let style_attr = @svg.escape_xml(styles.join(";") + ";")
  let sb = StringBuilder::new()
  sb.write_string("<path")
  sb.write_string(" d=\"\{@svg.escape_xml(d)}\"")
  if inline_theme || stroke_class_token is None {
    sb.write_string(" stroke=\"\{@svg.escape_xml(stroke)}\"")
  }
  sb.write_string(" fill=\"none\"")
  sb.write_string(" class=\"\{class_attr}\"")
  sb.write_string(" style=\"\{style_attr}\"")
  if marker_start != "" {
    sb.write_string(" marker-start=\"\{@svg.escape_xml(marker_start)}\"")
  }
  if marker_end != "" {
    sb.write_string(" marker-end=\"\{@svg.escape_xml(marker_end)}\"")
  }
  if mask != "" {
    sb.write_string(" mask=\"\{@svg.escape_xml(mask)}\"")
  }
  sb.write_string(" />")
  sb.to_string()
}

///|
fn d2_root_background_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  fill : String,
  stroke : String,
  stroke_width : Double,
  border_radius : Double,
  class_name : String?,
  theme : @themes.Theme,
  inline_theme : Bool,
) -> String {
  let classes = StringBuilder::new()
  match class_name {
    Some(class_raw) => classes.write_string(class_raw)
    None => ()
  }
  match d2_theme_token(fill, theme) {
    Some(token) => classes.write_string(" fill-\{token}")
    None => ()
  }
  let class_value = classes.to_string()
  let sb = StringBuilder::new()
  sb.write_string("<rect")
  sb.write_string(" x=\"\{d2_fixed6(x)}\"")
  sb.write_string(" y=\"\{d2_fixed6(y)}\"")
  sb.write_string(" width=\"\{d2_fixed6(width)}\"")
  sb.write_string(" height=\"\{d2_fixed6(height)}\"")
  sb.write_string(" rx=\"\{d2_fixed6(border_radius)}\"")
  if stroke != "" && stroke != "none" {
    sb.write_string(" stroke=\"\{@svg.escape_xml(stroke)}\"")
  }
  if inline_theme || d2_theme_token(fill, theme) is None {
    sb.write_string(" fill=\"\{@svg.escape_xml(fill)}\"")
  } else {
    sb.write_string(" fill=\"\{@svg.escape_xml(fill)}\"")
  }
  if class_value != "" {
    sb.write_string(" class=\"\{@svg.escape_xml(class_value)}\"")
  }
  if stroke_width.round() == stroke_width {
    sb.write_string(" stroke-width=\"\{stroke_width.to_int().to_string()}\"")
  } else {
    sb.write_string(" stroke-width=\"\{d2_fixed6(stroke_width)}\"")
  }
  sb.write_string(" />")
  sb.to_string()
}

///|
fn d2_shape_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  fill : String,
  stroke : String,
  stroke_width : Double,
  border_radius : Double,
  theme : @themes.Theme,
  inline_theme : Bool,
  fill_class_token? : String? = None,
  stroke_class_token? : String? = None,
) -> String {
  let classes = StringBuilder::new()
  let stroke_token = match stroke_class_token {
    Some(v) => Some(v)
    None => d2_theme_token(stroke, theme)
  }
  let fill_token = match fill_class_token {
    Some(v) => Some(v)
    None => d2_theme_token(fill, theme)
  }
  match stroke_token {
    Some(token) => classes.write_string(" stroke-\{token}")
    None => ()
  }
  match fill_token {
    Some(token) => classes.write_string(" fill-\{token}")
    None => ()
  }
  let stroke_width_css = if stroke_width.round() == stroke_width {
    stroke_width.to_int().to_string()
  } else {
    d2_fixed6(stroke_width)
  }
  let sb = StringBuilder::new()
  sb.write_string("<rect")
  sb.write_string(" x=\"\{d2_fixed6(x)}\"")
  sb.write_string(" y=\"\{d2_fixed6(y)}\"")
  sb.write_string(" width=\"\{d2_fixed6(width)}\"")
  sb.write_string(" height=\"\{d2_fixed6(height)}\"")
  if border_radius > 0.0 {
    sb.write_string(" rx=\"\{d2_fixed6(border_radius)}\"")
  }
  if inline_theme || stroke_token is None {
    sb.write_string(" stroke=\"\{@svg.escape_xml(stroke)}\"")
  }
  if inline_theme || fill_token is None {
    sb.write_string(" fill=\"\{@svg.escape_xml(fill)}\"")
  }
  let class_value = classes.to_string()
  if class_value != "" {
    sb.write_string(" class=\"\{@svg.escape_xml(class_value)}\"")
  }
  sb.write_string(
    " style=\"stroke-width:\{@svg.escape_xml(stroke_width_css)};\"",
  )
  sb.write_string(" />")
  sb.to_string()
}

///|
fn d2_ceil_to_int(x : Double) -> Int {
  let i = x.to_int()
  if i.to_double() == x {
    i
  } else if x > 0.0 {
    i + 1
  } else {
    i
  }
}

///|
fn d2_shape_ellipse(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  fill : String,
  stroke : String,
  stroke_width : Double,
  theme : @themes.Theme,
  inline_theme : Bool,
  fill_class_token? : String? = None,
  stroke_class_token? : String? = None,
) -> String {
  let classes = StringBuilder::new()
  classes.write_string("shape")
  let stroke_token = match stroke_class_token {
    Some(v) => Some(v)
    None => d2_theme_token(stroke, theme)
  }
  let fill_token = match fill_class_token {
    Some(v) => Some(v)
    None => d2_theme_token(fill, theme)
  }
  match stroke_token {
    Some(token) => classes.write_string(" stroke-\{token}")
    None => ()
  }
  match fill_token {
    Some(token) => classes.write_string(" fill-\{token}")
    None => ()
  }
  let stroke_width_css = if stroke_width.round() == stroke_width {
    stroke_width.to_int().to_string()
  } else {
    d2_fixed6(stroke_width)
  }
  let sb = StringBuilder::new()
  sb.write_string("<ellipse")
  sb.write_string(" rx=\"\{d2_fixed6(rx)}\"")
  sb.write_string(" ry=\"\{d2_fixed6(ry)}\"")
  sb.write_string(" cx=\"\{d2_fixed6(cx)}\"")
  sb.write_string(" cy=\"\{d2_fixed6(cy)}\"")
  if inline_theme || stroke_token is None {
    sb.write_string(" stroke=\"\{@svg.escape_xml(stroke)}\"")
  }
  if inline_theme || fill_token is None {
    sb.write_string(" fill=\"\{@svg.escape_xml(fill)}\"")
  }
  let class_value = classes.to_string()
  if class_value != "" {
    sb.write_string(" class=\"\{@svg.escape_xml(class_value)}\"")
  }
  sb.write_string(
    " style=\"stroke-width:\{@svg.escape_xml(stroke_width_css)};\"",
  )
  sb.write_string(" />")
  sb.to_string()
}

///|
fn emit_svg_document(
  graph : Diagram,
  svg : @svg.Svg,
  config : SvgConfig,
  assets : SvgEmitAssets,
) -> String {
  let outer_width = d2_ceil_to_int(svg.width())
  let outer_height = d2_ceil_to_int(svg.height())
  let inner_width = outer_width
  let inner_height = outer_height
  let outer_viewbox = "0 0 \{outer_width} \{outer_height}"
  let inner_viewbox = "\{svg.viewbox_x().to_int()} \{svg.viewbox_y().to_int()} \{inner_width} \{inner_height}"
  let body_elements = svg.elements()
  let body_source = body_elements.join("") + assets.tail_elements.join("")
  let corpus = graph.get_corpus()
  let upper_blocks : Array[String] = []
  upper_blocks.push(
    d2_embed_fonts_styles(assets.diagram_hash, body_source, corpus),
  )
  upper_blocks.push(
    @xml_emit.Element::new("style")
    .attr("type", "text/css")
    .cdata(
      d2_theme_stylesheet(
        assets.diagram_hash,
        assets.light_theme,
        assets.dark_theme,
      ),
    )
    .build(),
  )
  if assets.has_markdown_shape {
    upper_blocks.push(d2_markdown_styles(assets.diagram_hash))
  }
  for style in assets.style_blocks {
    upper_blocks.push(style)
  }
  let outer = @xml_emit.Element::new("svg")
    .attr("xmlns", "http://www.w3.org/2000/svg")
    .attr("xmlns:xlink", "http://www.w3.org/1999/xlink")
    .attr_if(
      "data-d2-version",
      if config.omit_version {
        ""
      } else {
        DIAGO_VERSION
      },
    )
    .attr("preserveAspectRatio", "\{d2_alignment(config)} meet")
    .attr("viewBox", outer_viewbox)
    .attr_num_if("width", svg.width(), config.scale is Some(_))
    .attr_num_if("height", svg.height(), config.scale is Some(_))
  let inner = @xml_emit.Element::new("svg")
    .attr("class", "\{assets.diagram_hash} d2-svg")
    .attr_int("width", inner_width)
    .attr_int("height", inner_height)
    .attr("viewBox", inner_viewbox)
  let sb = StringBuilder::new()
  if svg.include_xml_declaration() {
    sb.write_string("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
  }
  sb.write_string(outer.open_tag())
  sb.write_string(inner.open_tag())
  let mut body_index = 0
  while body_index < body_elements.length() &&
        body_elements[body_index].has_prefix("<rect") {
    sb.write_string(body_elements[body_index])
    body_index = body_index + 1
  }
  for block in upper_blocks {
    sb.write_string(block)
  }
  let combined_defs : Array[String] = []
  for def in assets.defs {
    combined_defs.push(def)
  }
  for def in svg.defs() {
    combined_defs.push(def)
  }
  let defs_block = emit_defs_block(combined_defs)
  if defs_block != "" {
    sb.write_string(defs_block)
  }
  let mut index = body_index
  while index < body_elements.length() {
    sb.write_string(body_elements[index])
    index = index + 1
  }
  for tail in assets.tail_elements {
    sb.write_string(tail)
  }
  for script in svg.scripts() {
    sb.write_string(
      @xml_emit.Element::new("script")
      .attr("type", "text/javascript")
      .cdata(script)
      .build(),
    )
  }
  sb.write_string(inner.close_tag())
  sb.write_string(outer.close_tag())
  sb.write_string("\n")
  sb.to_string()
}
