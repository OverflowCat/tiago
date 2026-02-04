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
/// Layered processor pipeline (internal).
///
/// This is a clean-room, MoonBit-native processor chain that mirrors the shape
/// of ELK layered's phase/intermediate-processor architecture.

///|
priv enum LayeredInternalSlot {
  BeforePhase1
  Phase1
  BeforePhase2
  Phase2
  BeforePhase3
  Phase3
  BeforePhase4
  Phase4
  BeforePhase5
  Phase5
  AfterPhase5
}

///|
fn LayeredInternalSlot::order(self : LayeredInternalSlot) -> Int {
  match self {
    BeforePhase1 => 10
    Phase1 => 15
    BeforePhase2 => 20
    Phase2 => 25
    BeforePhase3 => 30
    Phase3 => 35
    BeforePhase4 => 40
    Phase4 => 45
    BeforePhase5 => 50
    Phase5 => 55
    AfterPhase5 => 60
  }
}

///|
priv struct LayeredInternalContext {
  options : LayoutOptions
  direction : LayoutDirection
  thoroughness : Int
}

///|
fn internal_always_enabled(_ctx : LayeredInternalContext) -> Bool {
  true
}

///|
#warnings("-unused_field")
priv struct LayeredInternalProcessor {
  id : String
  slot : LayeredInternalSlot
  insertion_order : Int
  enabled : (LayeredInternalContext) -> Bool
  run : (LGraph, LayeredInternalContext) -> Unit
}

///|
fn LayeredInternalProcessor::new(
  id : String,
  slot : LayeredInternalSlot,
  insertion_order : Int,
  run : (LGraph, LayeredInternalContext) -> Unit,
) -> LayeredInternalProcessor {
  { id, slot, insertion_order, enabled: internal_always_enabled, run }
}

///|
fn LayeredInternalProcessor::new_when(
  id : String,
  slot : LayeredInternalSlot,
  insertion_order : Int,
  enabled : (LayeredInternalContext) -> Bool,
  run : (LGraph, LayeredInternalContext) -> Unit,
) -> LayeredInternalProcessor {
  { id, slot, insertion_order, enabled, run }
}

///|
priv struct LayeredInternalPipeline {
  processors : Array[LayeredInternalProcessor]
}

///|
fn LayeredInternalPipeline::run(
  self : LayeredInternalPipeline,
  graph : LGraph,
  ctx : LayeredInternalContext,
) -> Unit {
  fn debug_enabled(graph : LGraph) -> Bool {
    graph.properties.get_bool_or("diago.layered.debugTrace", false)
  }

  fn debug_snapshot(graph : LGraph) -> String {
    let ids : Array[String] = []
    for n in graph.nodes {
      ids.push(n.id)
    }
    ids.sort_by(fn(a, b) { a.compare(b) })
    let mut s = "w=\{graph.width} h=\{graph.height}"
    for id in ids {
      match graph.get_node(id) {
        Some(n) =>
          s = s +
            " " +
            id +
            ":\{n.node_type}(\{n.x},\{n.y},\{n.width},\{n.height})"
        None => ()
      }
    }
    s + "\n"
  }

  fn debug_append(graph : LGraph, msg : String) -> Unit {
    if !debug_enabled(graph) {
      return
    }
    let prev = graph.properties.get_string_or("diago.layered.debugTraceLog", "")
    graph.properties.set("diago.layered.debugTraceLog", String(prev + msg))
  }

  if debug_enabled(graph) {
    debug_append(graph, "BEGIN " + debug_snapshot(graph))
  }
  for processor in self.processors {
    if (processor.enabled)(ctx) {
      (processor.run)(graph, ctx)
      if debug_enabled(graph) {
        debug_append(graph, processor.id + " " + debug_snapshot(graph))
      }
    }
  }
}

///|
priv struct LayeredInternalPipelineBuilder {
  mut next_order : Int
  processors : Array[LayeredInternalProcessor]
}

///|
fn LayeredInternalPipelineBuilder::new() -> LayeredInternalPipelineBuilder {
  { next_order: 0, processors: [] }
}

///|
fn LayeredInternalPipelineBuilder::add(
  self : LayeredInternalPipelineBuilder,
  id : String,
  slot : LayeredInternalSlot,
  run : (LGraph, LayeredInternalContext) -> Unit,
) -> Unit {
  let processor = LayeredInternalProcessor::new(id, slot, self.next_order, run)
  self.next_order += 1
  self.processors.push(processor)
}

///|
fn LayeredInternalPipelineBuilder::add_when(
  self : LayeredInternalPipelineBuilder,
  id : String,
  slot : LayeredInternalSlot,
  enabled : (LayeredInternalContext) -> Bool,
  run : (LGraph, LayeredInternalContext) -> Unit,
) -> Unit {
  let processor = LayeredInternalProcessor::new_when(
    id,
    slot,
    self.next_order,
    enabled,
    run,
  )
  self.next_order += 1
  self.processors.push(processor)
}

///|
fn LayeredInternalPipelineBuilder::build(
  self : LayeredInternalPipelineBuilder,
) -> LayeredInternalPipeline {
  let processors = self.processors
  processors.sort_by(fn(a, b) {
    let da = a.slot.order() - b.slot.order()
    if da != 0 {
      da
    } else {
      a.insertion_order - b.insertion_order
    }
  })
  { processors, }
}

///|
fn default_layered_internal_pipeline() -> LayeredInternalPipeline {
  let builder = LayeredInternalPipelineBuilder::new()

  // --------------------------------------------------------------------------
  // Intermediate processors (reference-aligned scaffolding)
  // --------------------------------------------------------------------------

  // Before Phase 1
  builder.add("elk.layered.intermediate.DIRECTION_PREPROCESSOR", BeforePhase1, fn(
    _,
    _,
  ) {
    ()
  })
  builder.add("elk.layered.intermediate.COMMENT_PREPROCESSOR", BeforePhase1, fn(
    _,
    _,
  ) {
    ()
  })
  builder.add(
    "elk.layered.intermediate.EDGE_AND_LAYER_CONSTRAINT_EDGE_REVERSER",
    BeforePhase1,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.INTERACTIVE_EXTERNAL_PORT_POSITIONER",
    BeforePhase1,
    fn(_, _) { () },
  )
  builder.add("elk.layered.intermediate.PARTITION_PREPROCESSOR", BeforePhase1, fn(
    _,
    _,
  ) {
    ()
  })

  // Before Phase 2
  builder.add("elk.layered.intermediate.LABEL_DUMMY_INSERTER", BeforePhase2, fn(
    graph,
    ctx,
  ) {
    insert_label_dummy_nodes(graph, ctx.options)
  })
  builder.add("elk.layered.intermediate.SELF_LOOP_PREPROCESSOR", BeforePhase2, fn(
    graph,
    _,
  ) {
    extract_self_loop_edges(graph)
  })
  builder.add(
    "elk.layered.intermediate.LAYER_CONSTRAINT_PREPROCESSOR",
    BeforePhase2,
    fn(_, _) { () },
  )
  builder.add("elk.layered.intermediate.PARTITION_MIDPROCESSOR", BeforePhase2, fn(
    _,
    _,
  ) {
    ()
  })

  // Before Phase 3
  builder.add(
    "elk.layered.intermediate.HIGH_DEGREE_NODE_LAYER_PROCESSOR",
    BeforePhase3,
    fn(_, _) { () },
  )
  builder.add("elk.layered.intermediate.NODE_PROMOTION", BeforePhase3, fn(
    _,
    _,
  ) {
    ()
  })
  builder.add(
    "elk.layered.intermediate.LAYER_CONSTRAINT_POSTPROCESSOR",
    BeforePhase3,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.PARTITION_POSTPROCESSOR",
    BeforePhase3,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.HIERARCHICAL_PORT_CONSTRAINT_PROCESSOR",
    BeforePhase3,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.SEMI_INTERACTIVE_CROSSMIN_PROCESSOR",
    BeforePhase3,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.BREAKING_POINT_INSERTER",
    BeforePhase3,
    fn(_, _) { () },
  )

  // Our current implementation inserts long-edge and label dummies here.
  builder.add("elk.layered.intermediate.LONG_EDGE_SPLITTER", BeforePhase3, fn(
    graph,
    ctx,
  ) {
    insert_dummy_nodes(graph, ctx.options)
  })
  builder.add("elk.layered.intermediate.PORT_SIDE_PROCESSOR", BeforePhase3, fn(
    graph,
    ctx,
  ) {
    process_port_sides(graph, ctx.options, ctx.direction)
  })
  builder.add(
    "elk.layered.intermediate.INVERTED_PORT_PROCESSOR",
    BeforePhase3,
    fn(graph, ctx) { invert_inferred_port_sides(graph, ctx.direction) },
  )
  builder.add("elk.layered.intermediate.PORT_LIST_SORTER", BeforePhase3, fn(
    graph,
    ctx,
  ) {
    sort_ports(graph, ctx.options)
  })
  builder.add(
    "elk.layered.intermediate.SORT_BY_INPUT_ORDER_OF_MODEL",
    BeforePhase3,
    fn(graph, ctx) {
      sort_layers_by_input_order(graph, ctx.options, ctx.direction)
    },
  )
  builder.add(
    "elk.layered.intermediate.NORTH_SOUTH_PORT_PREPROCESSOR",
    BeforePhase3,
    fn(_, _) { () },
  )

  // Before Phase 4
  builder.add(
    "elk.layered.intermediate.BREAKING_POINT_PROCESSOR",
    BeforePhase4,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.ONE_SIDED_GREEDY_SWITCH",
    BeforePhase4,
    fn(graph, ctx) {
      let greedy = match ctx.options.greedy_switch {
        Some(v) => v
        None => TwoSided
      }
      match greedy {
        OneSided => _greedy_switch(graph, ctx.thoroughness)
        _ => ()
      }
    },
  )
  builder.add(
    "elk.layered.intermediate.TWO_SIDED_GREEDY_SWITCH",
    BeforePhase4,
    fn(graph, ctx) {
      let greedy = match ctx.options.greedy_switch {
        Some(v) => v
        None => TwoSided
      }
      match greedy {
        TwoSided => greedy_switch_two_sided(graph, ctx.thoroughness)
        _ => ()
      }
    },
  )
  builder.add(
    "elk.layered.intermediate.SELF_LOOP_PORT_RESTORER",
    BeforePhase4,
    fn(graph, ctx) { assign_self_loop_ports(graph, ctx.direction) },
  )
  builder.add(
    "elk.layered.intermediate.ALTERNATING_LAYER_UNZIPPER",
    BeforePhase4,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.SINGLE_EDGE_GRAPH_WRAPPER",
    BeforePhase4,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.IN_LAYER_CONSTRAINT_PROCESSOR",
    BeforePhase4,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.END_NODE_PORT_LABEL_MANAGEMENT_PROCESSOR",
    BeforePhase4,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.LABEL_AND_NODE_SIZE_PROCESSOR",
    BeforePhase4,
    fn(graph, ctx) { position_ports(graph, ctx.options) },
  )
  builder.add(
    "elk.layered.intermediate.INNERMOST_NODE_MARGIN_CALCULATOR",
    BeforePhase4,
    fn(_, _) { () },
  )
  builder.add("elk.layered.intermediate.SELF_LOOP_ROUTER", BeforePhase4, fn(
    graph,
    _,
  ) {
    assign_self_loop_offsets(graph)
  })
  builder.add(
    "elk.layered.intermediate.COMMENT_NODE_MARGIN_CALCULATOR",
    BeforePhase4,
    fn(_, _) { () },
  )
  builder.add("elk.layered.intermediate.END_LABEL_PREPROCESSOR", BeforePhase4, fn(
    graph,
    ctx,
  ) {
    preprocess_end_labels(graph, ctx.options)
  })
  builder.add("elk.layered.intermediate.LABEL_DUMMY_SWITCHER", BeforePhase4, fn(
    _,
    _,
  ) {
    ()
  })
  builder.add(
    "elk.layered.intermediate.CENTER_LABEL_MANAGEMENT_PROCESSOR",
    BeforePhase4,
    fn(graph, ctx) { set_default_label_placement(graph, ctx.options) },
  )
  builder.add("elk.layered.intermediate.LABEL_SIDE_SELECTOR", BeforePhase4, fn(
    graph,
    ctx,
  ) {
    apply_label_side_selection(graph, ctx.options, ctx.direction)
  })
  builder.add("elk.layered.intermediate.HYPEREDGE_DUMMY_MERGER", BeforePhase4, fn(
    _,
    _,
  ) {
    ()
  })
  builder.add(
    "elk.layered.intermediate.HIERARCHICAL_PORT_DUMMY_SIZE_PROCESSOR",
    BeforePhase4,
    fn(_, _) { () },
  )

  // Before Phase 5
  builder.add(
    "elk.layered.intermediate.LAYER_SIZE_AND_GRAPH_HEIGHT_CALCULATOR",
    BeforePhase5,
    fn(_, _) { () },
  )
  builder.add(
    "elk.layered.intermediate.HIERARCHICAL_PORT_POSITION_PROCESSOR",
    BeforePhase5,
    fn(_, _) { () },
  )

  // After Phase 5
  builder.add(
    "elk.layered.intermediate.CONSTRAINTS_POSTPROCESSOR",
    AfterPhase5,
    fn(_, _) { () },
  )
  builder.add("elk.layered.intermediate.COMMENT_POSTPROCESSOR", AfterPhase5, fn(
    _,
    _,
  ) {
    ()
  })
  builder.add("elk.layered.intermediate.HYPERNODE_PROCESSOR", AfterPhase5, fn(
    _,
    _,
  ) {
    ()
  })
  builder.add(
    "elk.layered.intermediate.HIERARCHICAL_PORT_ORTHOGONAL_EDGE_ROUTER",
    AfterPhase5,
    fn(_, _) { () },
  )

  // Our current implementation joins/merges long-edge dummies here.
  builder.add("elk.layered.intermediate.LONG_EDGE_JOINER", AfterPhase5, fn(
    graph,
    _,
  ) {
    remove_long_edge_dummy_nodes(graph)
  })
  builder.add_when(
    "elk.layered.intermediate.SELF_LOOP_POSTPROCESSOR",
    AfterPhase5,
    fn(ctx) {
      let routing = match ctx.options.edge_routing {
        Some(r) => r
        None => Orthogonal
      }
      match routing {
        Orthogonal => true
        Undefined => true
        Polyline => false
        Splines => false
      }
    },
    fn(graph, ctx) { route_and_restore_self_loops(graph, ctx.direction) },
  )
  builder.add("elk.layered.intermediate.BREAKING_POINT_REMOVER", AfterPhase5, fn(
    _,
    _,
  ) {
    ()
  })
  builder.add(
    "elk.layered.intermediate.NORTH_SOUTH_PORT_POSTPROCESSOR",
    AfterPhase5,
    fn(_, _) { () },
  )
  builder.add("elk.layered.intermediate.HORIZONTAL_COMPACTOR", AfterPhase5, fn(
    _,
    _,
  ) {
    ()
  })
  builder.add("elk.layered.intermediate.LABEL_DUMMY_REMOVER", AfterPhase5, fn(
    graph,
    ctx,
  ) {
    remove_label_dummy_nodes(graph, ctx.options, ctx.direction)
  })
  builder.add(
    "elk.layered.intermediate.FINAL_SPLINE_BENDPOINTS_CALCULATOR",
    AfterPhase5,
    fn(_, _) { () },
  )
  builder.add("elk.layered.intermediate.END_LABEL_SORTER", AfterPhase5, fn(
    graph,
    ctx,
  ) {
    sort_end_labels(graph, ctx.options)
  })

  // Restore reversed edges.
  builder.add("elk.layered.intermediate.REVERSED_EDGE_RESTORER", AfterPhase5, fn(
    graph,
    _,
  ) {
    restore_reversed_edges(graph)
  })
  builder.add("elk.layered.intermediate.END_LABEL_POSTPROCESSOR", AfterPhase5, fn(
    graph,
    ctx,
  ) {
    place_end_labels(graph, ctx.options, ctx.direction)
  })
  builder.add(
    "elk.layered.intermediate.HIERARCHICAL_NODE_RESIZER",
    AfterPhase5,
    fn(graph, ctx) { hierarchical_node_resizer(graph, ctx.options) },
  )
  builder.add("elk.layered.intermediate.DIRECTION_POSTPROCESSOR", AfterPhase5, fn(
    _,
    _,
  ) {
    ()
  })

  // --------------------------------------------------------------------------
  // Phase processors
  // --------------------------------------------------------------------------

  builder.add("elk.layered.phase1.cycleBreaking", Phase1, fn(graph, ctx) {
    let cycle_strategy = match ctx.options.cycle_breaking_strategy {
      Some(s) => s
      None => GreedyModelOrder
    }
    break_cycles(graph, cycle_strategy)
  })
  builder.add("elk.layered.phase2.layering", Phase2, fn(graph, ctx) {
    let layer_strategy = match ctx.options.layering_strategy {
      Some(s) => s
      None => NetworkSimplex
    }
    assign_layers(graph, layer_strategy)
    graph.initialize_layers()
  })
  builder.add("elk.layered.phase3.crossingMinimization", Phase3, fn(
    graph,
    ctx,
  ) {
    let crossing_strategy = match ctx.options.crossing_min_strategy {
      Some(s) => s
      None => LayerSweep
    }
    minimize_crossings(graph, ctx.options, crossing_strategy, ctx.thoroughness)
  })
  builder.add("elk.layered.phase4.nodePlacement", Phase4, fn(graph, ctx) {
    let placement_strategy = match ctx.options.node_placement_strategy {
      Some(s) => s
      None => BrandesKoepf
    }
    place_nodes(graph, ctx.options, placement_strategy, ctx.direction)
  })
  builder.add("elk.layered.phase5.edgeRouting", Phase5, fn(graph, ctx) {
    let routing = match ctx.options.edge_routing {
      Some(r) => r
      None => Orthogonal
    }
    route_edges(graph, ctx.options, routing, ctx.direction)
  })
  builder.build()
}

///|
/// Apply minimum-size constraints and content alignment after edge routing.
///
/// Mirrors ELK's `HierarchicalNodeResizingProcessor` behavior:
/// - grow graph size to at least NODE_SIZE_MINIMUM (when enabled)
/// - shift content according to CONTENT_ALIGNMENT (center)
/// - keep east/south external ports on the new border
fn hierarchical_node_resizer(graph : LGraph, options : LayoutOptions) -> Unit {
  let size_constraints = options.node_size_constraints.unwrap_or([])
  let apply_min = size_constraints.contains(MinimumSize) ||
    size_constraints.contains(MinimumSizeAccountsForPadding)
  if !apply_min {
    return
  }
  let old_w = graph.width
  let old_h = graph.height
  let (min_w, min_h) = match options.node_size_minimum {
    Some((w, h)) => (w, h)
    None => (0.0, 0.0)
  }
  let new_w = max_double(old_w, min_w)
  let new_h = max_double(old_h, min_h)
  if new_w == old_w && new_h == old_h {
    return
  }
  let content_alignment = options.content_alignment.unwrap_or(None)
  let mut dx = 0.0
  let mut dy = 0.0
  match content_alignment {
    Horizontal | HorizontalVertical =>
      if new_w > old_w {
        dx = (new_w - old_w) / 2.0
      }
    _ => ()
  }
  match content_alignment {
    Vertical | HorizontalVertical =>
      if new_h > old_h {
        dy = (new_h - old_h) / 2.0
      }
    _ => ()
  }

  // Apply the offset to all content (nodes + routes + labels).
  if dx != 0.0 || dy != 0.0 {
    for node in graph.nodes {
      node.x = node.x + dx
      node.y = node.y + dy
      for label in node.labels {
        label.x = label.x + dx
        label.y = label.y + dy
      }
      for port in node.ports {
        for label in port.labels {
          label.x = label.x + dx
          label.y = label.y + dy
        }
      }
    }
    for edge in graph.edges {
      for i = 0; i < edge.bend_points.length(); i = i + 1 {
        let p = edge.bend_points[i]
        edge.bend_points[i] = ElkPoint::new(p.x + dx, p.y + dy)
      }
      for label in edge.labels {
        label.x = label.x + dx
        label.y = label.y + dy
      }
    }
  }

  // Correct eastern/southern hierarchical ports for increased size.
  //
  // Mirrors ELK's `HierarchicalNodeResizingProcessor`: external-port dummy
  // nodes on EAST/SOUTH must stay on the outer border after the graph grows.
  fn parse_side(raw : String) -> ElkPortSide? {
    match raw {
      "North" | "NORTH" => Some(North)
      "South" | "SOUTH" => Some(South)
      "East" | "EAST" => Some(East)
      "West" | "WEST" => Some(West)
      _ => None
    }
  }

  let dw = new_w - old_w
  let dh = new_h - old_h
  if dw != 0.0 || dh != 0.0 {
    for node in graph.nodes {
      if node.node_type != ExternalPort {
        continue
      }
      let side_raw = node.properties.get_string("diago.layered.extPortSide")
      guard side_raw is Some(sr) else { continue }
      let side = parse_side(sr)
      guard side is Some(s) else { continue }
      if s == East && dw != 0.0 {
        node.x = node.x + dw
      } else if s == South && dh != 0.0 {
        node.y = node.y + dh
      }
    }
  }
  graph.width = new_w
  graph.height = new_h
}

///|
fn run_layered_internal_pipeline(
  graph : LGraph,
  options : LayoutOptions,
  direction : LayoutDirection,
  thoroughness : Int,
) -> Unit {
  let pipeline = default_layered_internal_pipeline()
  pipeline.run(graph, { options, direction, thoroughness })
}
