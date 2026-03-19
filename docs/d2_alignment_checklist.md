# D2 Alignment Checklist

This document turns the current D2 vs. diago research into a concrete checklist for aligning diago with the upstream `../d2` project.

## Goal

Align diago with D2 across:

- architecture and module responsibilities
- language semantics and compiler behavior
- layout and rendering behavior
- CLI and product surface
- editor/tooling APIs
- test coverage and parity verification

The implementation language will remain MoonBit. Alignment therefore means parity of concepts, APIs, behavior, and package responsibilities, not literal Go source duplication.

## How To Use This Checklist

- Treat each unchecked item as a work package.
- Prefer behavior parity over cosmetic refactors.
- When an item is completed, add or update a parity test that compares diago against an equivalent D2 fixture.
- If we decide to keep an intentional divergence, document it explicitly instead of leaving the item ambiguous.

## Package Mapping Snapshot

| D2 package / area | diago counterpart | Current assessment |
| --- | --- | --- |
| `d2ast` | `ast` | Broadly equivalent in purpose; diago is lighter. |
| `d2parser` | `parser` | Broadly equivalent in purpose. |
| `d2format` | `formatter` | Broadly equivalent in purpose. |
| `d2ir` | `ir` | Major parity gap in node/reference/context richness. |
| `d2graph` | `graph` | Major parity gap in graph/object/reference metadata and orchestration hooks. |
| `d2target` | `diagram` | Similar role, but D2 target model is richer and more product-oriented. |
| `d2exporter` | `exporter` | Owned as an internal compiler-stage lowering package. |
| `d2compiler` | `compiler` | Owned as the source-to-graph orchestration layer; file-based facade helpers stay outside it by design. |
| `d2lib` | `lib` + `diago.mbt` facade | Ownership decision is now explicit: `lib` is the D2-library-equivalent layer, while `diago.mbt` remains a MoonBit-native public facade. |
| `d2layouts/*` | `engine_api` + `engine_*` + layout helpers in `graph` / `diagram` | Same broad responsibility, different control flow and missing D2 orchestration pieces. |
| `d2renderers/d2svg` | `renderer_svg` | Similar surface, but D2 still has several product features not fully matched. |
| `d2renderers/d2ascii` | `renderer_ascii` + `renderer_unicode` | Similar surface, behavior parity still needs systematic verification. |
| `d2lsp` + `d2oracle` | `tooling.mbt` | Major scope gap: diago tooling is useful but much narrower. |
| `d2cli` | `cmd/diago` | diago CLI is smaller and supports fewer product outputs/features. |
| `d2js` / browser-facing wasm types | `cmd/wasm` + `web/` | Similar intent, different API surface and smaller scope. |

## Checklist

## 1. Architecture And Package Boundaries

- [x] Split the current high-level orchestration in `diago.mbt` into D2-like responsibility layers.
  - D2 reference: `d2compiler` for AST/IR/Graph compilation, `d2lib` for layout/render orchestration, `d2cli` for product entrypoints.
  - Completed by introducing a dedicated `compiler` layer for source-to-graph compilation and a dedicated `lib` layer for layout/render orchestration, with `diago.mbt` reduced to a public facade and `cmd/wasm` updated to reuse the split.
  - Remaining follow-up lives in the next two architecture items: package ownership mapping and the final decision on how closely the MoonBit split should mirror D2 naming and boundaries.

- [x] Decide whether diago should mirror D2's explicit `compiler` + `lib` split or document a deliberate MoonBit-native equivalent.
  - Decision recorded in `docs/d2_package_ownership_decision.md`.
  - Chosen policy: keep the current split as a MoonBit-native equivalent of D2's `d2compiler` + `d2lib`, while retaining `diago.mbt` as the public facade and keeping file I/O outside `compiler`.

- [x] Create a package-level alignment map in code ownership terms.
  - Completed in `docs/d2_package_ownership_decision.md`.
  - Every D2 package area currently in scope now has an explicit diago owner or an explicit omitted/out-of-scope note.

## 2. IR And Semantic Model Parity

- [x] Expand `ir` to match D2's node/reference model more closely.
  - D2 reference: `d2ir.Node`, `Copy(newParent)`, `Parent()`, `AST()`, `LastRef()`, `LastPrimaryRef()`, `LastPrimaryKey()`, reference context, glob and lazy-glob tracking.
  - Landed in diago: `NodePath`, `Map::get_node`, root-based `parent(...)` lookup, deep copy helpers, AST/reference context, and glob/lazy-glob metadata.
  - Remaining imported-source traceability is tracked by the next checklist item.

- [x] Add import-aware AST/source tracing to IR nodes.
  - Landed in diago: `Map/Field/Edge.import_ast()` now preserves the local import syntax while imported references still retain imported-file `source_path`.
  - Verified for both `field: @import` and `...@import` flows, including imported edges.

- [x] Align IR field/edge naming and path semantics with D2.
  - Landed in diago: `Field` now preserves `name_syntax`, reserved-keyword lookups are quote-aware, bare keys retain non-primary references, `NodePath` field steps keep quotedness, import selectors preserve syntax, and `EdgeID` now retains source/destination path syntax alongside scalar path strings.
  - Follow-through included glob/property/exporter updates so quoted reserved names are no longer treated like unquoted semantic keywords.

- [x] Upgrade `vars.d2-config.data` handling from `Map[String, String]`-like behavior to D2-compatible value support.
  - Landed in diago: `diagram.Config.data` now carries typed values that preserve D2's current `compileConfig` output shape: scalar strings and scalar string-arrays.
  - `compiler`, `cmd/diago`, and SVG config hashing now all preserve array-valued `vars.d2-config.data` entries instead of collapsing them to strings or dropping them.

## 3. Graph Model And Board Semantics

- [x] Expand `graph` to carry D2-level metadata.
  - Landed in diago: graph inputs/models now preserve D2-style folder-only board metadata, graph-scoped config `data`, and explicit object metadata for language and SQL constraints instead of relying only on encoded class names.
  - Remaining graph parity items still tracked separately below: `ID` vs `IDVal`, object/edge reference tracking, and broader board compilation semantics.

- [x] Align object identity semantics with D2's `ID` vs `IDVal` split.
  - Landed in diago: graph models/inputs now preserve compatibility semantic IDs, local `id_val`, canonical local `id_syntax`, canonical absolute `abs_id_syntax`, and syntax-aware edge endpoint IDs.
  - `GraphInput::find_object` now resolves canonical D2 absolute IDs before falling back to the legacy flattened semantic path string, which covers quoted-dot and quoted-key lookups.
  - Downstream layout and render code now also canonicalizes object and edge lookup IDs through the syntax-aware graph identity model instead of flattening quoted path segments back into ambiguous dotted strings.

- [x] Align graph reference tracking for objects and edges.
  - Landed in diago: object and edge references now flow from IR into graph inputs/models, are preserved through layout canonicalization and graph cloning helpers, and are used to restore D2-style source-order sorting.
  - This closes the graph-side prerequisite for broader `d2lsp` / `d2oracle` parity work, though the tooling surface itself is still tracked separately below.

- [x] Implement or verify D2-style board compilation semantics.
  - Landed in diago: board compilation now distinguishes isolated `layers` from inherited `scenarios` / `steps`, preserves D2-style folder-only behavior, applies board primary labels, rejects duplicate board names across kinds, and reports board keywords outside board-root scope.
  - Landed in diago: board links now canonicalize and validate against the compiled board tree, including D2-style relative `_` resolution, self-link removal, missing-board rejection, and quote-aware board paths.

- [x] Align legend compilation behavior.
  - Landed in diago: `vars.d2-legend` now follows the upstream D2 compiler path more closely by compiling a standalone legend graph, preserving the legend label from the field primary value, filtering zero-opacity shapes, keeping legend edges even when their opacity is zero, and preserving edge labels instead of synthesizing fallback arrow-text labels.
  - Landed in diago: the internal legend defaults used for exported legend structure now match D2's renderer-side synthetic constants more closely for border stroke, padding, entry gap, and icon size.
  - Verified with D2-derived exporter coverage for hidden shapes, preserved edge styles, zero-opacity legend edges, and legend default metadata.

- [x] Align AST-based sort order behavior.
  - Landed in diago: exporter graph compilation now sorts objects, nested children, and edges by reference/source ranges with stable fallback to encounter order.
  - Layout/render regression coverage also now verifies syntax-aware ordering for quoted-dot identities.

## 4. Layout Orchestration Parity

- [ ] Align the high-level nested layout orchestration model with D2.
  - D2 reference: `d2layouts.LayoutNested`, extracted subgraphs, child-order restore, constant-near handling, nested grid and sequence passes, routing after layout.
  - Landed in diago: the D2 constant-near branch is now partially mirrored for Dagre and ELK. Top-level constant-near containers now move their descendant subgraph together, keep internal edges aligned with the moved subtree, and reroute cross-subgraph edges after the near placement instead of leaving stale pre-near routes behind.
  - Landed in diago: `engine_api` now also mirrors the upstream extracted constant-near control flow instead of relying only on engine-local patch moves. Root-level D2 constant-near objects and subgraphs are extracted before core layout, recursively laid out with `near` temporarily cleared, then placed and re-injected in D2 set order before cross-subgraph edge restoration.
  - Verified with upstream-derived `grid_in_constant_near` and `multiple_constant_nears` stable-target regressions for both Dagre and ELK.
  - Landed in diago: leaf constant-near text/object cases now also preserve the upstream default label semantics when restored from the extracted graph. Diago no longer infers a synthetic inside-top label position for leaf constant-near objects whose source did not set one, which restores D2 parity for the `play_diagram_title` / constant-near title path in both Dagre and ELK.
  - Landed in diago: the upstream `constant_near_title` stable fixture is now locked as well for the `LayoutNested` portion of that path. Dagre and ELK both preserve D2's constant-near title placement and the surrounding connection geometry, and diago's markdown title measurement for that fixture now matches the upstream target boxes as well.
  - Landed in diago: Dagre and ELK now also mirror one D2 root-grid slice that previously depended on `LayoutNested` extraction. When a root grid child remains in the core layout because incident edges block the old semantic detachment path, diago now reapplies D2-style root grid placement after core layout, shifts nested descendants with their grid cell, and reroutes cross-cell edges with the same default-router strategy used by upstream nested reinjection. This is locked against the upstream `nested_layout_bug.d2` fixture.
  - Landed in diago: extracted-subgraph prelayout now also covers nested sequence and nested-grid containers strongly enough to match the upstream `nested_diagram_types.d2` fixture for both Dagre and ELK. Nested diagram containers are recursively laid out before outer layout, their fitted bounds are re-used as outer placeholders, and nested descendants / internal edges are restored relative to the laid-out container afterward.
  - Landed in diago: the root-grid reinjection path now also mirrors D2's `d2grid.sizeForOutsideLabels()` cleanup semantics more closely. Grid children still participate in row/column sizing with their expanded layout dimensions, but their final boxes are restored from the resolved cell size instead of snapping back to pre-layout semantic widths. This closes the `grid.d2` parity regression that appeared while landing nested root-grid extraction.
  - Landed in diago: final graph order restoration now mirrors upstream `d2layouts.SaveOrder` more closely, including object order, edge order, and immutable child-order restoration by syntax-aware IDs after nested/grid layout passes. This is locked against the upstream `grid_nested_simple_edges.d2` fixture for Dagre and ELK.
  - Landed in diago: non-root nested grids now use D2-style dynamic child-box estimation instead of a fixed rectangular `rows x cols` semantic plan. This restores the upstream `grid_nested_gap0.d2` behavior for Dagre and ELK, including zero-gap nested grid sizing and row balancing inside extracted grid containers.
  - Landed in diago: the upstream `nested_steps` regression is now locked at the same target layer as D2's committed `board.exp.json` fixtures instead of comparing raw layout floats directly. The regression now asserts `diagram.from_graph(...)` shape boxes for Dagre and ELK, which matches upstream `d2target` integer position serialization and avoids false ELK drift from float-only internal graph coordinates.
  - Landed in diago: the upstream `connected_container` and `container_edges` stable fixtures are now locked at the same target layer too. This adds explicit Dagre/ELK parity coverage for connected nested-container chains and cross-container edge routing without relying on engine-internal float coordinates.
  - Remaining gaps: full `ExtractSubgraph` / `InjectNested` style orchestration and the dedicated nested grid / sequence control flow still remain distributed across `engine_api`, `graph`, and engine-specific code.

- [x] Add or verify explicit support for D2 layout capability checks.
  - D2 reference: the layout layer distinguishes capabilities such as `near_object`, `container_dimensions`, `top_left`, `descendant_edges`, and routed edges.
  - Landed in diago: `engine_api.LayoutEngine` now exposes an explicit D2-style capability contract, and `layout_with_engine(...)` performs the same pre-layout validation categories as upstream `d2plugin.FeatureSupportCheck`.
  - Landed in diago: built-in Dagre and ELK now advertise the same effective support surface as upstream D2 (`dagre`: none of the gated features, `elk`: `container_dimensions` and `descendant_edges`), while Railway now declares its currently supported extension surface explicitly instead of relying on silent best-effort behavior.
  - Verified with D2-derived engine API coverage for rejected `near_object`, rejected locked `top/left`, rejected Dagre descendant/container-dimension cases, and accepted ELK container-dimension / descendant-edge cases.

- [ ] Validate Dagre behavior against D2 fixtures.
  - Note: implementation strategy may remain MoonBit-native, but behavior should align.

- [ ] Validate ELK behavior and supported options against D2 fixtures.
  - Includes container dimensions, descendant edges, and ELK option mapping.
  - Update: `moon_elk` `0.1.13` fixes the reduced layered `INCLUDE_CHILDREN` include-self repro from `grid_edge_across_cell.d2`. Diago now tracks that upstream fix directly without carrying any local ELK parity shim.

- [ ] Align grid diagram behavior with D2.
  - Verify row/column layout rules, gap semantics, spans, nested containers, label/icon padding, and edge routing through grid content.
  - Landed in diago: root-grid layouts with incident child edges now preserve D2's nested-cell behavior for Dagre and ELK, including the upstream `nested_layout_bug.d2` case where a nested grid container must still occupy a grid column and cross-cell edges are rerouted after the cell reposition.
  - Landed in diago: root-grid cell cleanup now preserves D2's final column/row sizing after outside-label margin rollback, which restores parity for the upstream `grid.d2` fixture in Dagre and ELK instead of shrinking plain cells back to their semantic minimum widths.
  - Landed in diago: exporter-side edge map handling now follows the upstream `compileEdgeMap(...)` class-expansion path closely enough for `grid_nested_simple_edges.d2` to compile. Edge `class` values on nested grid descendants are now accepted and expanded through `classes.*` before reserved-key validation, which restores the upstream red-stroke fixture edges instead of failing with `edge map keys must be reserved keywords`.
  - Landed in diago: nested grid containers with explicit `grid-gap: 0` now preserve D2's zero-gap dynamic row balancing as well. `grid_nested_gap0.d2` is now locked against the upstream Dagre and ELK stable board geometry.
  - Landed in diago: include-self grid-cell container handling now recovers effective label positions from the laid out `label_box`/`box` state before the outer grid pass. That restores the ELK geometry from the upstream `grid_nested.d2` `grid w/ container` slice, where the placeholder cell must preserve D2's inner-label sizing rather than re-deriving an outside label margin.
  - Landed in diago: the upstream `grid_nested.d2` `grid in grid` slice is now locked as well, covering the case where a nested 2x2 grid container is itself a single outer grid cell and must keep the same Dagre/ELK stable box geometry as `../d2`.
  - Landed in diago: the remaining recursive grid slices from `grid_nested.d2` are now locked too. `grid w/ nested containers` and `grid w/ grid w/ grid` both match the upstream Dagre and ELK stable board geometry, which gives explicit regression coverage for repeated nested container fitting, repeated include-self grid-cell extraction, and deep zero-gap placeholder restoration.
  - Landed in diago: the upstream regression `empty_nested_grid` now matches Dagre and ELK stable board geometry as well. Closing that gap required two D2-backed fixes outside the layout loop itself: exporter text defaults now treat grid-diagram objects like `Object.Text()` does upstream (`IsContainer() || IsGridDiagram()` with sequence-aware bold suppression), and text measurement now includes size-specific bold metrics at D2 container label sizes so empty nested-grid placeholders reuse the same 24px bold sizing as upstream instead of a scaled fallback.

- [ ] Align sequence diagram behavior with D2.
  - Verify actor spacing, group handling, lifelines, message routing, notes, and nested sequence behavior.
  - Landed in diago: compact edge tokenization/parsing/IR compilation now follows D2 for `A->B` and `A--B` forms without surrounding spaces, which closes the upstream `empty_sequence` regression path where standalone sequence-diagram-shaped objects are connected by a compact edge.

- [ ] Align `near` behavior with D2.
  - Includes constant-near, object-near, and interactions with layout engines that may or may not support full D2 semantics.
  - Landed in diago: compiler-side near validation now mirrors the upstream D2 checks for targeting constant-near objects, targeting grid descendants, targeting objects inside sequence diagrams, and rejecting self-entering edges from constant-near containers, grid diagrams, grid cells, and sequence diagrams.
  - Landed in diago: D2-style constant-near placement for Dagre and ELK now keeps near containers, descendants, internal edges, and cross-subgraph edges coherent after the near move, matching the `d2near.Layout` + post-injection reroute behavior more closely.
  - Landed in diago: constant-near placement now also follows the upstream extraction path more closely. Constant-near objects and subgraphs are removed from the outer layout input, laid out recursively as non-near, then placed and re-injected in D2 set order, which restores the upstream `grid_in_constant_near`, `multiple_constant_nears`, and constant-near title geometry for Dagre and ELK.
  - Landed in diago: the `d2near.place(...)` outside-label compensation branches are now mirrored for Dagre and ELK as well, so constant-near boxes offset for `OUTSIDE_*` / `BORDER_*` label positions on the same `_TOP_` / `_LEFT_` / `_RIGHT_` / `_BOTTOM_` conditions as upstream.
  - Landed in diago: built-in engine handling of object-near now matches the current upstream support surface as well. Dagre and ELK reject it through the same capability gate categories as D2, and plugin-based object-near support remains out of scope with plugin integration.
  - Remaining gaps: full nested/grid/sequence interactions still depend on the unfinished `LayoutNested` orchestration parity work above.

- [ ] Decide how Railway fits into the parity plan.
  - Recommended policy: keep Railway as a diago-specific extension, but ensure it does not distort Dagre/ELK parity work.

## 5. Renderer And Target Model Parity

- [x] Align `diagram` with D2's `d2target` model where behavior depends on target-level fields.
  - Includes root shape behavior, nested board packaging, config hashing inputs, legend structure, and board traversal APIs.
  - Landed in diago: target board selection is now parser-backed and quote-aware instead of using raw `.` splitting.
  - Landed in diago: `diagram.Diagram` now carries D2-style target fields and helpers for `description`, font-family metadata, `has_shape`, `bytes`, `hash_id`, `get_corpus`, and `get_nested_corpus`.
  - Landed in diago: SVG scope hashing and font-subset corpus generation now consume `diagram` target APIs instead of renderer-private hash/corpus logic.
  - Landed in diago: committed Dagre and ELK SVG snapshots were refreshed to the new D2-style target hash/corpus semantics.

- [ ] Align SVG render configuration semantics with D2.
  - Verify `theme`, `dark-theme`, `pad`, `center`, `scale`, `no-xml-tag`, `salt`, `omit-version`, and bundled asset behavior.
  - Landed in diago: CLI/lib/render option plumbing now carries D2-style `pad` and `center`, and SVG `preserveAspectRatio` now follows D2's `xMinYMin` vs `xMidYMid` behavior.
  - Landed in diago: source config, facade/lib render options, and CLI `--sketch` now follow D2's global sketch precedence more closely as well. Explicit render options override `vars.d2-config.sketch`, the default still falls back to `false`, and the effective `theme` / `dark-theme` / `sketch` values are now fed back into `diagram.Config` before SVG hashing just like `d2lib.Compile`.
  - Landed in diago: SVG asset bundling now mirrors D2's `imgbundler` split more closely, with local assets always bundled for SVG output, remote assets gated by the bundle option, D2-style relative local path resolution, duplicate remote URL de-duplication, optional cross-run cache plumbing, and explicit oversized/error fetch coverage.
  - Landed in diago: SVG bundling failure propagation now follows the upstream D2 CLI contract more closely as well. The bundler preserves already-produced SVG, keeps successful image replacements, leaves failed image refs untouched, and returns aggregated local/remote bundling warnings separately so the CLI can still write SVG output before surfacing the bundling error.
  - Remaining gap: diago still renders sketch mode through its local SVG filter-based path instead of D2's `d2sketch` renderer pipeline, so full sketch output parity is still open even though global config and hash semantics now line up more closely.

- [x] Align root canvas sizing and board bounding box behavior with D2.
  - Landed in diago: D2-style `label.near`, `icon.near`, and `tooltip.near` now compile through `exporter -> graph -> diagram` as target metadata instead of being lost in renderer heuristics.
  - Landed in diago: SVG label placement, icon placement, positioned tooltip rendering, target hashing, and root bound calculations now consume those target fields directly, including D2-style outside/border label positions, outside icon extents, and positioned tooltip bounds.
  - Verified with D2-derived compiler cases plus renderer whitebox coverage for explicit label positioning, positioned tooltip rendering, and root-bound expansion from outside icons/tooltips.

- [x] Align theme override semantics and type model with D2.
  - Landed in diago: source config parsing, CLI render options, facade/lib render options, SVG config, renderer hashing, and target config serialization now use a typed `diagram.ThemeOverrides` model that mirrors `../d2/d2target.ThemeOverrides` instead of generic string maps.
  - Landed in diago: source-level `theme-overrides` / `dark-theme-overrides` compilation still follows `compileThemeOverrides` key and color validation, while target/config bytes now encode override objects with D2-style fixed lower-case field names and declaration order.
  - Verified with compiler config tests, CLI override parsing coverage, and target-bytes coverage that locks the D2-style config JSON shape.

- [ ] Align SVG feature coverage.
  - Includes patterns, sketch mode, dark-theme switching, appendix rendering, links/tooltips behavior, legend rendering, markdown styling, and code block rendering.
  - Landed in diago: markdown label sizing now flows through a shared D2-style measurement path instead of engine-local plain-text fallback sizing. Shared markdown block metrics and semibold heading text metrics now drive both layout-time object sizing and SVG foreignObject dimensions, and this is locked by D2-derived `constant_near_title` geometry plus Dagre SVG snapshot parity for `play_markdown_text` and `play_root_styles`.

- [ ] Align ASCII rendering output with D2 fixtures.
  - Verify shape geometry, label placement, routing, and standard vs extended charset behavior.

- [ ] Decide whether Unicode output should remain a diago extension or be folded into D2-aligned ASCII/text mode semantics.

- [ ] Align font packaging and font selection behavior.
  - D2 exposes custom font-path configuration and ships a richer font subsystem.
  - diago has embedded fonts and subsetting, but its product surface is narrower.

- [ ] Add missing export formats if full product parity is required.
  - D2 supports PNG, PDF, PPTX, and GIF in addition to SVG and text outputs.
  - diago currently focuses on SVG, ASCII, and Unicode.

## 6. CLI And Product Surface Parity

- [ ] Align CLI subcommand coverage with D2 where appropriate.
  - D2 includes `layout`, `themes`, `fmt`, `play`, `validate`, `version`, and product-level export flows.
  - diago currently covers a smaller set and uses a different execution structure.

- [ ] Align CLI flag surface and semantics.
  - Verify layout selection, theme flags, dark theme, pad, center, scale, watch, bundle, force appendix, font overrides, output format, target board selection, and timeout behavior.
  - Landed in diago: target board flags now reject invalid D2 path syntax, accept quoted board names, and distinguish D2's `board only` vs `board with children` target forms (`layers.x` vs `layers.x.*`, plus `--target=''` for root only).

- [ ] Align watch mode behavior with D2.
  - D2 has a richer embedded watch server and reload protocol.
  - diago currently has a smaller watch preview flow.

- [ ] Decide whether to implement D2's `play` command behavior in diago.
  - D2 can open the hosted playground directly.
  - diago currently ships a local static playground instead.

- [ ] Decide whether to align diago's CLI around D2's product command model or keep the current command UX and document the divergence.

## 7. Tooling, LSP, And Oracle Parity

- [ ] Split tooling responsibilities to mirror D2's `d2lsp` and `d2oracle` surfaces.
  - diago currently concentrates tooling in `tooling.mbt`.

- [ ] Align `get_ref_ranges` behavior with D2's reference and import range behavior.

- [ ] Align completion behavior with D2's completion context rules.

- [ ] Add missing oracle/editing helpers if D2 parity is desired.
  - Examples: board replacement, object/edge lookup, child/parent lookup, writable reference discovery, imported object detection, object order queries.

- [ ] Align source position conventions where editor interoperability depends on them.
  - D2 exposes UTF-16-aware parsing options for editor clients.
  - Verify whether diago needs equivalent configurability.

## 8. Browser And WASM Surface Parity

- [ ] Compare diago's `cmd/wasm` API with D2's browser-facing wasm/JS types and decide the target parity surface.

- [ ] Align browser playground capabilities if parity is desired.
  - Example loading, theme/layout selection, error reporting, multi-format rendering, and public API conventions.

- [ ] Decide whether local static playground behavior is sufficient or whether diago should expose a D2-like JS embedding surface.

## 9. Tests, Fixtures, And Verification

- [ ] Build a cross-project parity fixture suite sourced from D2 examples, e2e tests, and regression cases.

- [ ] Add fixture comparison at multiple layers where practical:
  - parse / AST
  - IR
  - graph / layout
  - diagram / target model
  - SVG output
  - ASCII output

- [ ] Tag every checklist item with one or more parity fixtures before calling it done.

- [ ] Add regression coverage for every intentionally retained divergence.

## 10. Documentation And Cleanup

- [ ] Remove or update stale docs that no longer match the codebase.
  - Example: `docs/d2analysis.md` still describes `engine_dagre` as a stub, which is no longer true.

- [ ] Document every accepted divergence from D2 in one place.

- [ ] Keep this checklist updated as decisions are made.

## Suggested Sweep Order

The recommended order is:

1. IR and graph model parity
2. compiler/library/package-boundary alignment
3. board semantics and nested layout orchestration
4. SVG target and renderer parity
5. ASCII/text parity
6. CLI surface parity
7. tooling/LSP/oracle parity
8. browser/WASM parity
9. output format expansion
10. documentation cleanup and long-tail regressions

## Current High-Risk Gaps

These are the gaps most likely to block broad parity:

- IR/reference/context richness is below D2's model.
- Graph/object metadata and board semantics are below D2's model.
- D2's nested layout orchestration and layout capability gating are richer.
- diago does not yet expose D2's full product surface for LSP/oracle tooling and non-SVG export formats.
