# Architecture Refactor Plan (ARCH_REFAC)

This document proposes a **package-level refactor** to make Diago’s architecture explicit, acyclic, and extensible—especially for adding new layout engines (e.g. `elk`, `dagre`) without tangling dependencies.

Implementation policy (updated): during the refactor we can **ignore the current implementation details** and we do **not** need to keep `moon test` passing while changes are in progress. The priority is to land a clean architecture first; correctness/test restoration happens afterwards.

## Goals

1. **Clear responsibilities per layer/package** (no “god package”).
2. **Strict one-way dependencies** (no cycles).
3. **Engines are pluggable**: `elk`, `dagre`, etc. implement a shared interface.
4. **Graph/data model is stable**; renderers and engines consume it without owning compilation logic.
5. Prefer **clean layering** over incremental compatibility.

## Target Stack (conceptual layering)

Target layering (from source to output):

`d2compiler -> d2ir -> engine interface (elk/dagre impls) -> d2graph -> d2exporter -> d2diagram -> d2renderer (svg/ascii/unicode) -> output`

Interpretation:

- The arrows above describe **ownership boundaries**, not strict runtime order.
- Package dependencies must remain **acyclic** (see next section).

## Target Runtime Pipeline (compile → layout → render)

At runtime the order should be explicit at API boundaries:

`d2compiler (parse/import) -> d2ir (semantic compile) -> d2exporter (IR→Graph) -> engine_* (GraphInput→LayoutOutputs) -> d2diagram (GraphInput+LayoutOutputs→Diagram) -> d2renderer_* (Diagram→String/bytes) -> output`

## Current State Snapshot (why it feels “mixed”)

Based on today’s `moon.pkg.json` dependencies:

- `graph/` and `layout/` legacy packages were removed; internal code uses `d2graph`/`d2exporter`/`engine_api`/`engine_elk`/`d2renderer_*` directly.
- `elk/` still imports `d2graph` → ELK algorithm library remains coupled to Diago graph types (split into `elk_core` is still optional).

This makes “add another engine” hard because:

- the engine interface is not clearly separated from D2-specific layout pipeline code;
- “ELK the algorithm” and “ELK the engine” are not separated;
- graph is not a stable “model layer” (it pulls in renderer/compiler concerns).

## Target Dependency Rules (compile-time)

### Core rule

Lower layers must never import higher layers.

### Recommended dependency DAG (packages)

```
lexer  -> (no deps)
ast    -> lexer
parser -> lexer, ast

d2ir (semantic IR) -> ast, parser

d2graph (pure model) -> (ideally no deps; maybe core only)

engine_api -> d2graph

engine_elk   -> engine_api, elk_core (or elk), d2graph
engine_dagre -> engine_api, dagre_core, d2graph

d2exporter -> d2ir, d2graph

d2diagram  -> d2graph, engine_api   (builds render-ready diagram from graph + layout)

renderer_svg     -> d2diagram, svg_backend, themes
renderer_ascii   -> d2diagram, ascii_backend, themes
renderer_unicode -> d2diagram, unicode_backend, themes

cmd/* -> d2compiler, d2ir, d2exporter, engine_elk|engine_dagre, d2diagram, renderer_*

sugiyama (legacy algos/tests) -> d2graph
```

Notes:

- `elk` today is an **algorithm library** that already depends on `graph`. Long-term it should be split:
  - `elk_core` (pure ELK types/algorithms; no Diago graph)
  - `engine_elk` (adapter from `d2graph` to `elk_core` + `engine_api` implementation)
- `layout` as a catch-all should disappear or be renamed into a **D2 diagram pipeline/orchestrator** package (`d2diagram` + helpers).

## Package Responsibilities (target end state)

### `d2compiler` (front-end façade)

Public façade for:

- parsing (`lexer/parser/ast`)
- import resolution
- error aggregation

Should **not** contain IR semantics, layout, or rendering.

### `d2ir`

Semantic compilation from AST to IR:

- symbol resolution, scoping, imports
- semantic errors
- “meaning” of D2 source

Must not depend on graph/layout/renderers.

### `d2graph`

Pure diagram graph model:

- nodes/edges/container structure
- styles, labels, metadata
- variants (layers/scenarios/steps) as pure structure (optional)

Design target:

- **No renderer code**
- **No layout algorithm code**
- Prefer: **no dependency on `d2ir`**

### `engine_api` (engine interface package)

Defines the engine contract and layout result types, e.g.:

- `LayoutConfig`, `Direction`, `LayoutError`
- `NodeLayout`, `EdgeLayout`, `LayoutResult`
- `trait LayoutEngine { layout(graph_input, config, direction) -> LayoutResult raise LayoutError }`
- Immutable engine input types: `d2graph.GraphInput` (no `mut` fields)
- Glue: `layout_with_engine(engine, graph_input, config, direction) -> LayoutOutputs` (recurses variants and does **not** mutate inputs)

Critical rule:

- `engine_api` must not depend on any engine implementation.

### `engine_elk`, `engine_dagre` (engine implementations)

Each engine package:

- depends on `engine_api` + its algorithm library
- converts `d2graph.GraphInput` to engine internal graph
- returns `LayoutResult`
- does not render; does not parse; does not compile IR

### `d2exporter`

Transforms `d2ir` into `d2graph`:

- resolves D2 semantics into concrete nodes/edges/containers/styles
- assigns stable `NodeId`/`EdgeId`

No rendering; no layout algorithms.

### `d2diagram`

Render-ready diagram construction:

- consumes `d2graph.GraphInput` + `LayoutOutputs`
- computes any render-only artifacts not owned by core graph (e.g. label boxes, guides, interaction metadata)
- normalizes coordinates (e.g. make all coords non-negative), determines drawing order

If D2 has special diagram types (sequence/grid/etc.), `d2diagram` is where orchestration belongs:

- detect diagram type
- decide whether to run a general-purpose engine or a specialized layout routine
- produce a consistent `LayoutResult`/diagram model for renderers

### `d2renderer_*`

Rendering backends:

- `d2renderer_svg`: emits SVG (via `svg_backend`/`xml_emit`)
- `d2renderer_ascii`: emits ASCII
- `d2renderer_unicode`: emits Unicode box drawing, etc.

Renderers should depend on `d2diagram` (or `d2graph + LayoutResult`) and backend-specific helpers only.

## Implementation Strategy (clean-slate; tests may be broken during refactor)

This refactor should be treated as a **rebuild of package boundaries**, not a careful extraction. We intentionally allow breakage while the new architecture is taking shape.

High-level approach:

1. Define **target packages + public APIs first** (compile-time boundaries).
2. Move/port code into the correct layer; delete cross-layer helpers instead of threading them across boundaries.
3. After layering is correct: restore missing behavior and then restore tests/snapshots.

## Refactor Roadmap (tracking)

This is the **living checklist** for the architecture refactor described in this document. Keep it updated as work lands.

Notes:

- This roadmap is **only** for the architecture refactor. The feature roadmap stays in `roadmap.md`.
- It’s OK for `moon test` to be broken during this roadmap; aim for `moon check` green whenever possible.

### Current status

- Last updated: 2026-01-09
- Current milestone: M5 in progress (diagram model hardening)
- Known temporary shims:
  - `d2diagram.Diagram::materialize()` applies `LayoutResult` onto a fresh mutable `d2graph.Graph` for legacy renderers; this is a bridge until renderers consume `LayoutOutputs` directly.
  - `engine_api.LayoutOutputs::from_graph(graph)` captures layout state from an already-laid-out `d2graph.Graph` (bridge for legacy/interop cases).

### Milestones

- [x] **M0: Land package skeletons**
  - [x] Create packages: `d2compiler`, `d2ir`, `d2graph`, `d2exporter`, `engine_api`, `engine_elk`, `engine_dagre`, `d2diagram`, `d2renderer_*`
  - [x] Ensure `moon check` passes (warnings allowed)

- [x] **M1: Establish stable model (`d2graph`)**
  - [x] Move graph model/variants/legend/route/shape/arrowhead into `d2graph/`
  - [x] (Removed) Keep `graph/` working via compatibility aliases where needed

- [x] **M2: Split exporter (`d2exporter`) from renderers**
  - [x] Move IR→Graph compilation into `d2exporter/` (export `to_graph`)
  - [x] Keep `graph.compile` as a temporary shim (until renderers move out)

- [x] **M3: Make engine contract explicit (`engine_api`)**
  - [x] Define `LayoutEngine`, `LayoutConfig`, `Direction`, `LayoutResult`
  - [x] Provide `layout_with_engine` glue (variants recursion; returns `LayoutOutputs` without mutating inputs)
  - [x] Introduce immutable engine input type (`d2graph.GraphInput`)

- [ ] **M4: Engines are true plugins**
  - [x] `engine_elk` implements `engine_api.LayoutEngine` (self-contained)
  - [x] Move ELK adapter code out of legacy `layout/` into `engine_elk/`
  - [ ] `engine_dagre` implements the same interface with a real dagre core (keep stub until core exists)
  - [ ] Optional: split `elk/` into `elk_core/` + `engine_elk/` adapter

- [ ] **M5: Diagram + renderers extraction**
  - [x] Implement `d2diagram` as the render-ready model (`GraphInput + LayoutOutputs -> Diagram`)
  - [ ] Extend `d2diagram` with render-only artifacts (draw order, normalization, etc.)
  - [x] Move SVG renderer out of `graph/` into `d2renderer_svg/`
  - [x] Move ASCII/Unicode renderers out of `graph/` into `d2renderer_ascii/` and `d2renderer_unicode/`
  - [x] Ensure renderers depend only on `d2diagram` (or `d2graph + LayoutResult`)

- [x] **M6: Rewrite entrypoints + retire legacy**
  - [x] `cmd/*` uses the explicit pipeline (`d2compiler -> d2ir -> d2exporter -> engine_* -> render`)
  - [x] Delete/retire legacy packages (`graph/` and `layout/`) or reduce them to thin re-export shells
  - [x] Remove all temporary alias/shim files once the new packages fully own their responsibilities

- [ ] **M7: Restore correctness + tests**
  - [ ] Restore `moon test` and snapshots (run `moon test --update` when expected behavior changes)
  - [ ] Add/adjust regression tests for engine API, exporter, and renderers

### Post-refactor cleanup (optional)

- [ ] Fix web ASCII rendering (`TODO.md`)
- [ ] Route SVG output through `xml_emit` (`TODO.md`)
- [ ] Improve SVG formatting/structure (`TODO.md`)
- [ ] Replace ad-hoc I/O with `moonbitlang/async` (`TODO.md`)
- [ ] Remove `unsafe_to_char` patterns (`TODO.md`)

### Phase A — Define the new package skeleton (no code migration yet)

Create packages (directories + `moon.pkg.json` + minimal entry files) for:

- `d2compiler`
- `d2ir`
- `d2graph`
- `engine_api`
- `engine_elk`
- `engine_dagre` (stub)
- `d2exporter`
- `d2diagram`
- `d2renderer_svg`
- `d2renderer_ascii`
- `d2renderer_unicode`

Acceptance criteria:

- Dependency DAG matches the “Recommended dependency DAG (packages)” section.
- `engine_api` compiles independently and depends only on `d2graph`.

### Phase B — Establish the stable “model + interface” core

1. Put pure graph model types in `d2graph`:
   - nodes/edges/containers
   - styles/metadata
   - IDs and variants (if variants belong to graph; otherwise they move to `d2diagram`)
2. Put the engine contract in `engine_api`:
   - `LayoutConfig`, `Direction`, `LayoutError`
   - `NodeLayout`, `EdgeLayout`, `LayoutResult`
   - `trait LayoutEngine { layout(graph_input, config, direction) -> LayoutResult raise LayoutError }`
   - `layout_with_engine(...) -> LayoutOutputs` glue (variant recursion; does not mutate inputs)
   - immutable engine input type: `d2graph.GraphInput` (no `mut` fields)

Acceptance criteria:

- `d2graph` depends on no compiler/IR/renderer/engine packages.
- A new engine can be implemented in a standalone package by depending only on `engine_api` (and an algorithm lib).

### Phase C — Move front-end compilation into explicit layers

1. `d2compiler`: parse + imports + error aggregation.
2. `d2ir`: semantic compilation from AST.
3. `d2exporter`: IR→Graph.

Acceptance criteria:

- Exporter produces a `d2graph.Graph` with stable IDs.
- No renderer imports in compiler/IR/exporter.

### Phase D — Engines become true plugin implementations

1. `engine_elk`:
   - owns Graph↔ELK adapter
   - implements `engine_api.LayoutEngine`
   - depends on `engine_api` + `elk` (or `elk_core`) + `d2graph`
2. `engine_dagre`:
   - stub initially; later wire a Dagre algorithm library

Acceptance criteria:

- `engine_api` has zero knowledge of ELK/Dagre.
- Engines do not parse/compile/render.

### Phase E — Diagram model + renderers

1. `d2diagram`: consumes `d2graph` + `LayoutResult`, produces a render-ready diagram model.
2. `d2renderer_*`: consumes `d2diagram` and emits output.

Acceptance criteria:

- Renderers do not depend on compiler/IR/exporter/engine implementations.

### Phase F — Rewrite CLI entrypoints, then delete legacy packages

1. Rewrite `cmd/*` to use the new pipeline explicitly.
2. Delete/retire legacy catch-all packages (`graph/`, `layout/` as they exist today), or keep them only as temporary re-export shells if needed.

Acceptance criteria:

- Repo structure matches the target stack and dependency DAG.
- Only after this: restore test suite and snapshots.

## Package naming map (existing → target)

Suggested mapping to keep the rebuild concrete:

- `lexer/` → `lexer/` (or `d2lexer/`) (no functional change)
- `ast/` → `ast/` (or `d2ast/`)
- `parser/` → `parser/` (or `d2parser/`)
- `ir/` → `d2ir/`
- `graph/` → split into `d2graph/` + `d2exporter/` + `d2diagram/` + `d2renderer_*`
- `layout/` → replaced by `engine_api/` + `engine_elk/` (+ optional `d2layout_pipeline/` if desired)
- `elk/` → optionally split later into `elk_core/` + `engine_elk/` adapter (recommended), or keep as-is short-term

## Public API Sketches (target)

### Compilation (front-end)

- `d2compiler.parse(source) -> Ast`
- `d2ir.compile(ast, resolver) -> Ir`
- `d2exporter.to_graph(ir) -> d2graph.Graph`

### Layout

- `engine_api.LayoutEngine::layout(graph_input, config, dir) -> LayoutResult raise LayoutError`
- `engine_api.layout_with_engine(engine, graph_input, config, dir) -> LayoutOutputs raise LayoutError`
- `d2diagram.build(graph_input, layout_outputs) -> Diagram`
  - convenience: `d2diagram.layout_with_engine(engine, graph, config, dir) -> Diagram raise LayoutError`
  - or `d2diagram.layout(graph_input, engine, config, dir) -> Diagram raise LayoutError`

### Rendering

- `renderer_svg.render(diagram, cfg) -> String`
- `renderer_ascii.render(diagram, cfg) -> String`
- `renderer_unicode.render(diagram, cfg) -> String`

## Risks / Trade-offs

1. **Large moves**: moving renderer code out of `graph` will touch many files.
2. **ID stability**: must guarantee stable `NodeId`/`EdgeId` across exporter/layout/renderer.
3. **Variants** (layers/scenarios/steps): decide whether variants belong in `d2graph` or `d2diagram`.
4. **ELK split**: turning `elk` into a clean algorithm lib is ideal but can be deferred.

## “Definition of Done”

1. Engine interface lives in `engine_api` and is imported by both `engine_elk` and `engine_dagre`.
2. `d2graph` contains no compiler or renderer code.
3. All renderers depend on `d2diagram` (or `d2graph + LayoutResult`) only.
4. CLI flow matches the target pipeline.
5. No dependency cycles; `moon check` passes for the final architecture.
6. Tests/snapshots are restored as a follow-up milestone.
