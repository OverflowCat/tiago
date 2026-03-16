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
| `d2compiler` | `compiler` + `exporter` | Compiler-layer split now exists, but wider package ownership parity still needs cleanup. |
| `d2lib` | `lib` + `diago.mbt` facade | Library-layer orchestration now exists; the public facade still needs broader parity follow-through. |
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

- [ ] Decide whether diago should mirror D2's explicit `compiler` + `lib` split or document a deliberate MoonBit-native equivalent.
  - This is an architectural alignment decision and blocks several cleanup tasks.

- [ ] Create a package-level alignment map in code ownership terms.
  - Done when every D2 package we care about has one clearly named diago owner package or an explicit "not implemented / intentionally omitted" note.

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

- [ ] Align graph reference tracking for objects and edges.
  - This is required for true `d2lsp` / `d2oracle` parity.

- [ ] Implement or verify D2-style board compilation semantics.
  - Includes `layers`, `scenarios`, `steps`, inherited/base board behavior, and "folder only" boards.

- [ ] Align legend compilation behavior.
  - D2 builds legends from `vars.d2-legend` with explicit filtering and synthetic layout defaults.
  - Verify diago matches the same source semantics and output structure.

- [ ] Align AST-based sort order behavior.
  - D2 explicitly sorts objects and edges by AST order after compilation.
  - Verify whether diago preserves all the same ordering guarantees.

## 4. Layout Orchestration Parity

- [ ] Align the high-level nested layout orchestration model with D2.
  - D2 reference: `d2layouts.LayoutNested`, extracted subgraphs, child-order restore, constant-near handling, nested grid and sequence passes, routing after layout.
  - diago currently distributes some of this responsibility across `engine_api`, `graph`, and engine implementations.

- [ ] Add or verify explicit support for D2 layout capability checks.
  - D2 reference: the layout layer distinguishes capabilities such as `near_object`, `container_dimensions`, `top_left`, `descendant_edges`, and routed edges.
  - diago currently does not expose an equivalent compatibility contract.

- [ ] Validate Dagre behavior against D2 fixtures.
  - Note: implementation strategy may remain MoonBit-native, but behavior should align.

- [ ] Validate ELK behavior and supported options against D2 fixtures.
  - Includes container dimensions, descendant edges, and ELK option mapping.

- [ ] Align grid diagram behavior with D2.
  - Verify row/column layout rules, gap semantics, spans, nested containers, label/icon padding, and edge routing through grid content.

- [ ] Align sequence diagram behavior with D2.
  - Verify actor spacing, group handling, lifelines, message routing, notes, and nested sequence behavior.

- [ ] Align `near` behavior with D2.
  - Includes constant-near, object-near, and interactions with layout engines that may or may not support full D2 semantics.

- [ ] Decide how Railway fits into the parity plan.
  - Recommended policy: keep Railway as a diago-specific extension, but ensure it does not distort Dagre/ELK parity work.

## 5. Renderer And Target Model Parity

- [ ] Align `diagram` with D2's `d2target` model where behavior depends on target-level fields.
  - Includes root shape behavior, nested board packaging, config hashing inputs, legend structure, and board traversal APIs.

- [ ] Align SVG render configuration semantics with D2.
  - Verify `theme`, `dark-theme`, `pad`, `center`, `scale`, `no-xml-tag`, `salt`, `omit-version`, and bundled asset behavior.

- [ ] Align root canvas sizing and board bounding box behavior with D2.

- [ ] Align theme override semantics and type model with D2.
  - D2 uses a typed theme override structure.
  - diago currently uses string maps.

- [ ] Align SVG feature coverage.
  - Includes patterns, sketch mode, dark-theme switching, appendix rendering, links/tooltips behavior, legend rendering, markdown styling, and code block rendering.

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
- The new compiler/lib split exists, but the remaining package ownership map is still less explicit than D2's.
- D2's nested layout orchestration and layout capability gating are richer.
- diago does not yet expose D2's full product surface for LSP/oracle tooling and non-SVG export formats.
