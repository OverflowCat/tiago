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
/// LSP-facing helper APIs for editor integrations.

///|
pub(all) enum CompletionKind {
  Keyword
  Style
  Shape
  Value
} derive(Eq, Show)

///|
pub struct CompletionItem {
  label : String
  kind : CompletionKind
  detail : String
  insert_text : String
} derive(Eq, Show)

///|
priv enum RefSelector {
  Field(Array[String])
  Edge(@ir.EdgeID)
}

///|
priv enum CompletionContext {
  StyleProperties
  ShapeValues
  BooleanValues
  FillPatternValues
  TextTransformValues
  NearValues
  TooltipTemplate
  IconTemplate
  DirectionValues
  ArrowheadProperties
  ArrowheadShapes
  LabelProperties
  ValueHint(String)
}

///|
pub fn get_ref_ranges(
  source : String,
  key : String,
  board_path? : Array[String] = [],
  options? : ParseOptions = ParseOptions::new(),
) -> Array[@lexer.Range] raise DiagoError {
  let ir_map = parse(source, options~)
  let board_root = match find_map_by_path(ir_map, board_path) {
    Some(m) => m
    None => raise TargetError("Target board not found: \{board_path}")
  }
  let selector = parse_ref_selector(key)
  let ranges : Array[@lexer.Range] = []
  match selector {
    Field(path) =>
      match find_field_by_path(board_root, path) {
        Some(field) =>
          for reference in field.references {
            ranges.push(reference.range)
          }
        None => ()
      }
    Edge(edge_id) =>
      for edge in board_root.find_edges(edge_id) {
        for reference in edge.references {
          ranges.push(reference.range)
        }
      }
  }
  ranges
}

///|
pub fn get_board_path_at_position(
  source : String,
  line : Int,
  column : Int,
) -> Array[String] {
  let (ast_map, _errors) = @compiler.parse(source)
  match board_path_at_map(ast_map, [], line, column) {
    Some(path) => path
    None => []
  }
}

///|
pub fn get_completion_items(
  source : String,
  line : Int,
  column : Int,
) -> Array[CompletionItem] {
  let prefix = line_prefix_at(source, line, column)
  match detect_completion_context(prefix) {
    Some(StyleProperties) => style_completion_items()
    Some(ShapeValues) => shape_completion_items()
    Some(BooleanValues) => boolean_completion_items()
    Some(FillPatternValues) => fill_pattern_completion_items()
    Some(TextTransformValues) => text_transform_completion_items()
    Some(NearValues) => near_completion_items()
    Some(TooltipTemplate) => tooltip_completion_items()
    Some(IconTemplate) => icon_completion_items()
    Some(DirectionValues) => direction_completion_items()
    Some(ArrowheadProperties) => arrowhead_property_completion_items()
    Some(ArrowheadShapes) => arrowhead_shape_completion_items()
    Some(LabelProperties) => label_completion_items()
    Some(ValueHint(property)) => [value_hint_completion_item(property)]
    None => []
  }
}

///|
fn parse_ref_selector(key : String) -> RefSelector raise DiagoError {
  let selector_source = key + ": null"
  let (selector_ast, selector_errors) = @compiler.parse(selector_source)
  if !selector_errors.is_empty() {
    raise ConfigError("invalid reference selector: \{key}")
  }
  if selector_ast.nodes.length() == 0 {
    raise ConfigError("invalid reference selector: \{key}")
  }
  let map_key = match selector_ast.nodes[0] {
    @ast.MapNode::Key(k) => k
    _ => raise ConfigError("invalid reference selector: \{key}")
  }
  if !map_key.edges.is_empty() {
    let edge = map_key.edges[0]
    let base = @ir.EdgeID::new(
      edge.src.to_strings(),
      edge.dst.to_strings(),
      edge.src_arrow == "<",
      edge.dst_arrow == ">",
    )
    let query_edge = match map_key.edge_index {
      Some(edge_index) =>
        if edge_index.glob {
          @ir.EdgeID::with_glob(
            base.src_path,
            base.dst_path,
            base.src_arrow,
            base.dst_arrow,
          )
        } else {
          @ir.EdgeID::with_index(
            base.src_path,
            base.dst_path,
            base.src_arrow,
            base.dst_arrow,
            edge_index.index.unwrap_or(0),
          )
        }
      None => base
    }
    Edge(query_edge)
  } else {
    match map_key.key {
      Some(key_path) => {
        if key_path.path.length() == 0 {
          raise ConfigError("invalid reference selector: \{key}")
        }
        let path : Array[String] = []
        for segment in key_path.path {
          path.push(segment.content())
        }
        Field(path)
      }
      None => raise ConfigError("invalid reference selector: \{key}")
    }
  }
}

///|
fn find_map_by_path(root : @ir.Map, path : Array[String]) -> @ir.Map? {
  if path.length() == 0 {
    return Some(root)
  }
  let mut current = root
  for segment in path {
    match current.get_field(segment) {
      Some(field) =>
        match field.map() {
          Some(next_map) => current = next_map
          None => return None
        }
      None => return None
    }
  }
  Some(current)
}

///|
fn find_field_by_path(root : @ir.Map, path : Array[String]) -> @ir.Field? {
  if path.length() == 0 {
    return None
  }
  let mut current = root
  let mut last_field : @ir.Field? = None
  for i, segment in path {
    match current.get_field(segment) {
      Some(field) => {
        last_field = Some(field)
        if i + 1 < path.length() {
          match field.map() {
            Some(next_map) => current = next_map
            None => return None
          }
        }
      }
      None => return None
    }
  }
  last_field
}

///|
fn board_path_at_map(
  map : @ast.Map,
  current_path : Array[String],
  line : Int,
  column : Int,
) -> Array[String]? {
  if !position_in_range(map.range, line, column) {
    return None
  }
  for node in map.nodes {
    match node {
      @ast.MapNode::Key(key) =>
        match (key.key, key.value) {
          (Some(key_path), Some(value)) => {
            if key_path.path.length() == 0 {
              continue
            }
            match child_map_from_value(value) {
              Some(child_map) => {
                if !position_in_range(child_map.range, line, column) {
                  continue
                }
                let segment = key_path.path[0].content()
                if current_path.length() % 2 == 0 && !is_board_keyword(segment) {
                  continue
                }
                let next_path = current_path.copy()
                next_path.push(segment)
                match board_path_at_map(child_map, next_path, line, column) {
                  Some(deeper_path) => return Some(deeper_path)
                  None =>
                    if next_path.length() % 2 == 0 {
                      return Some(next_path)
                    } else {
                      return None
                    }
                }
              }
              None => ()
            }
          }
          _ => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn child_map_from_value(value : @ast.Value) -> @ast.Map? {
  match value {
    @ast.Value::Map(m) => Some(m)
    @ast.Value::BlockScalar(_, m) => Some(m)
    _ => None
  }
}

///|
fn is_board_keyword(segment : String) -> Bool {
  segment == "layers" || segment == "scenarios" || segment == "steps"
}

///|
fn position_in_range(range : @lexer.Range, line : Int, column : Int) -> Bool {
  let after_start = line > range.start.line ||
    (line == range.start.line && column >= range.start.column)
  let before_end = line < range.end.line ||
    (line == range.end.line && column < range.end.column)
  after_start && before_end
}

///|
fn line_prefix_at(source : String, line : Int, column : Int) -> String {
  if line < 0 || column <= 0 {
    return ""
  }
  let mut index = 0
  for raw_line in source.split("\n") {
    if index == line {
      let line_text = raw_line.to_string()
      let end = if column < line_text.length() {
        column
      } else {
        line_text.length()
      }
      return slice_string(line_text, 0, end)
    }
    index = index + 1
  }
  ""
}

///|
fn detect_completion_context(prefix : String) -> CompletionContext? {
  let normalized = prefix.trim().to_lower().to_string()
  if normalized.length() == 0 {
    return None
  }
  if normalized.has_suffix("style.") || normalized.has_suffix("style:") {
    return Some(StyleProperties)
  }
  if normalized.has_suffix("shape:") || normalized.has_suffix(".shape:") {
    return Some(ShapeValues)
  }
  if normalized.has_suffix("fill-pattern:") ||
    normalized.has_suffix("style.fill-pattern:") {
    return Some(FillPatternValues)
  }
  if normalized.has_suffix("text-transform:") ||
    normalized.has_suffix("style.text-transform:") {
    return Some(TextTransformValues)
  }
  if normalized.has_suffix("source-arrowhead.shape:") ||
    normalized.has_suffix("target-arrowhead.shape:") {
    return Some(ArrowheadShapes)
  }
  if normalized.has_suffix("source-arrowhead.") ||
    normalized.has_suffix("target-arrowhead.") {
    return Some(ArrowheadProperties)
  }
  if normalized.has_suffix("label.") || normalized.has_suffix("icon.") {
    return Some(LabelProperties)
  }
  if normalized.has_suffix("near:") ||
    normalized.has_suffix("label.near:") ||
    normalized.has_suffix("icon.near:") {
    return Some(NearValues)
  }
  if normalized.has_suffix("tooltip:") {
    return Some(TooltipTemplate)
  }
  if normalized.has_suffix("icon:") {
    return Some(IconTemplate)
  }
  if normalized.has_suffix("direction:") {
    return Some(DirectionValues)
  }
  if is_boolean_value_context(normalized) {
    return Some(BooleanValues)
  }
  match detect_value_hint_property(normalized) {
    Some(property) => Some(ValueHint(property))
    None => None
  }
}

///|
fn is_boolean_value_context(normalized : String) -> Bool {
  let boolean_keys = [
    "shadow", "3d", "multiple", "animated", "bold", "italic", "underline", "filled",
    "double-border",
  ]
  for key in boolean_keys {
    if normalized.has_suffix("\{key}:") ||
      normalized.has_suffix("style.\{key}:") {
      return true
    }
  }
  false
}

///|
fn detect_value_hint_property(normalized : String) -> String? {
  let value_hint_keys = [
    "opacity", "stroke-width", "stroke-dash", "border-radius", "font-size", "stroke",
    "fill", "font-color", "width", "height", "top", "left",
  ]
  for key in value_hint_keys {
    if normalized.has_suffix("\{key}:") ||
      normalized.has_suffix("style.\{key}:") {
      return Some(key)
    }
  }
  None
}

///|
fn style_completion_items() -> Array[CompletionItem] {
  let items : Array[CompletionItem] = []
  for keyword in @ast.style_keywords {
    items.push({
      label: keyword,
      kind: Style,
      detail: "style property",
      insert_text: keyword + ": ",
    })
  }
  items
}

///|
fn shape_completion_items() -> Array[CompletionItem] {
  let shape_values = [
    "rectangle", "square", "circle", "oval", "diamond", "hexagon", "parallelogram",
    "cylinder", "queue", "package", "step", "callout", "stored_data", "person", "cloud",
    "page", "document", "class", "sql_table", "text", "code", "image", "sequence_diagram",
    "octagon", "c4_person", "c4_container",
  ]
  completion_items_from_values(shape_values, Shape, "shape", false)
}

///|
fn boolean_completion_items() -> Array[CompletionItem] {
  [
    { label: "true", kind: Value, detail: "boolean", insert_text: "true" },
    { label: "false", kind: Value, detail: "boolean", insert_text: "false" },
  ]
}

///|
fn fill_pattern_completion_items() -> Array[CompletionItem] {
  completion_items_from_values(@ast.fill_patterns, Value, "fill pattern", false)
}

///|
fn text_transform_completion_items() -> Array[CompletionItem] {
  completion_items_from_values(
    @ast.text_transforms,
    Value,
    "text transform",
    false,
  )
}

///|
fn near_completion_items() -> Array[CompletionItem] {
  let items : Array[CompletionItem] = [
    {
      label: "(object ID)",
      kind: Value,
      detail: "e.g. container.inner_shape",
      insert_text: "",
    },
  ]
  for pos in @ast.label_positions {
    items.push({
      label: pos,
      kind: Value,
      detail: "label position",
      insert_text: pos,
    })
  }
  items
}

///|
fn tooltip_completion_items() -> Array[CompletionItem] {
  [
    {
      label: "(markdown)",
      kind: Value,
      detail: "markdown formatted text",
      insert_text: "|md\n  # Tooltip\n  Hello world\n|",
    },
  ]
}

///|
fn icon_completion_items() -> Array[CompletionItem] {
  [
    {
      label: "(URL, e.g. https://icons.terrastruct.com/xyz.svg)",
      kind: Value,
      detail: "icon URL",
      insert_text: "https://icons.terrastruct.com/essentials%2F073-add.svg",
    },
  ]
}

///|
fn direction_completion_items() -> Array[CompletionItem] {
  completion_items_from_values(
    ["up", "down", "right", "left"],
    Value,
    "direction",
    false,
  )
}

///|
fn arrowhead_property_completion_items() -> Array[CompletionItem] {
  [
    {
      label: "shape",
      kind: Keyword,
      detail: "arrowhead property",
      insert_text: "shape: ",
    },
    {
      label: "label",
      kind: Keyword,
      detail: "arrowhead property",
      insert_text: "label: ",
    },
    {
      label: "style.filled",
      kind: Keyword,
      detail: "arrowhead style property",
      insert_text: "style.filled: ",
    },
  ]
}

///|
fn arrowhead_shape_completion_items() -> Array[CompletionItem] {
  completion_items_from_values(
    [
      "triangle", "arrow", "diamond", "circle", "cf-one", "cf-one-required", "cf-many",
      "cf-many-required",
    ],
    Shape,
    "arrowhead shape",
    false,
  )
}

///|
fn label_completion_items() -> Array[CompletionItem] {
  [
    {
      label: "near",
      kind: Keyword,
      detail: "label position",
      insert_text: "near: ",
    },
  ]
}

///|
fn value_hint_completion_item(property : String) -> CompletionItem {
  let label = match property {
    "opacity" => "(number between 0.0 and 1.0)"
    "stroke-width" => "(number between 0 and 15)"
    "font-size" => "(number between 8 and 100)"
    "stroke-dash" => "(number between 0 and 10)"
    "border-radius" => "(number greater than or equal to 0)"
    "font-color" | "stroke" | "fill" => "(color name or hex code)"
    "width" | "height" | "top" | "left" => "(pixels)"
    _ => "(value)"
  }
  { label, kind: Value, detail: "value hint", insert_text: "" }
}

///|
fn completion_items_from_values(
  values : Array[String],
  kind : CompletionKind,
  detail : String,
  append_colon : Bool,
) -> Array[CompletionItem] {
  let items : Array[CompletionItem] = []
  for value in values {
    items.push({
      label: value,
      kind,
      detail,
      insert_text: if append_colon {
        value + ": "
      } else {
        value
      },
    })
  }
  items
}

///|
fn slice_string(s : String, start : Int, end : Int) -> String {
  let from = if start < 0 { 0 } else { start }
  let to = if end < from {
    from
  } else if end > s.length() {
    s.length()
  } else {
    end
  }
  let sb = StringBuilder::new()
  for i in from..<to {
    sb.write_char(s.code_unit_at(i).to_int().unsafe_to_char())
  }
  sb.to_string()
}
