# Unified Inter-Module Types (AST/IR/Graph/Diagram) — Detailed Report

> Goal: make the types exchanged between internal modules (`lexer/ast/ir/graph/diagram/engine_api/...`) follow a single, unified “core data model”, and support:
>
> - **Traceability**: from IR/Graph nodes back to the source text `Range` (for errors, hints, and reference chains).
> - **Immutability**: no `mut` fields in public cross-module structs/enums; updates happen by returning new values (or by hiding internal mutability behind opaque types).
> - **0-based**: all `Position.line/column` are 0-based.
> - **Style value domain**: cross-module Style/attribute values are represented as `string + source range` (delayed validation / stronger traceability).
>
> This document defines the **type contract and refactoring scope** only; it does not include concrete implementation patches.

---

## 0. Terminology

- **Span/Range**: a source-code interval, at minimum `path + start + end`.
- **AST**: the parsed syntax tree (retains syntactic forms such as quoted/unquoted).
- **IR**: the semantic/normalized key-value tree (with reference context).
- **Graph**: a “layoutable graph” compiled from IR (objects, edges, board tree, theme, metadata).
- **Diagram**: the structure used for rendering/output (can attach layout info on top of Graph).

---

## 1. Current State (only conflicts with the target contract)

### 1.1 `lexer` position model is insufficient

Current public types: `lexer/pkg.generated.mbti` (`Position/Range`).

Main issues:
- `Range` does not include `path`; cross-file imports / error locations miss the root identifier.
- `Position.offset` semantics are unclear (byte offset vs UTF-16 compatibility), which is unfriendly for LSP / JS ecosystems.

### 1.2 `ast` does not expose a unified Node abstraction

`ast` currently exposes multiple `enum/struct` types (`Map/Key/KeyPath/...`), but lacks a unified `Node` abstraction (e.g., `Type/GetRange/Children`).

Impact:
- When `ir`/`graph` needs to carry an “arbitrary AST node reference”, the API becomes awkward (only a few specific structs can be carried).

### 1.3 `ir` is a value-object model; lacks parent/context and AST traceability

Current `ir/pkg.generated.mbti`: `Map(fields, edges)`, `Field(primary/composite/references)`, `Edge(...)`.

Main issues:
- Missing node-level capabilities such as `Parent/Copy/AST()`.
- `Reference` information lacks scope/context (insufficient to reconstruct a “reference chain” and precise semantics).
- Many path fields are `Array[String]`, losing the syntactic string form (quoted/unquoted, original key-path composition).

### 1.4 `graph` types look like “layout input”, not a compiled Graph product

Current `graph/pkg.generated.mbti`: `GraphInput/ObjectInput/EdgeInput/StyleInput`.

Main issues:
- `GraphInput` does not include compilation context such as `AST/BaseAST/Parent/Theme/Data`.
- `ObjectInput.id` does not separate `id_val`, and does not include `References` / `Map(AST)`.
- `StyleInput` is strongly typed (`Double?/Bool?`), conflicting with the target contract of `string + source range`.

### 1.5 `diagram` / `engine_api` interfaces will be reshaped as a consequence

- `engine_api.LayoutEngine.layout(GraphInput, ...) -> LayoutResult` depends on the current `graph.GraphInput`.
- If `graph` is refactored into a compiled Graph model, this interface must change to accept the new Graph. The layout result either writes back into Graph or produces an applicable patch.

---

## 2. Target Type Contract (suggested public API)

### 2.1 SourceSpan (unified source locations across modules)

Suggested to live in a “base package” (recommended location: `lexer/`, or introduce a new `source/` package).

#### Required types

- `pub struct Position { line : Int, column : Int, byte : Int }`
  - **0-based**: `line/column`.
  - `byte`: UTF-8 byte offset; when unavailable, use `-1` as a sentinel.

- `pub struct Range { path : String, start : Position, end : Position }`
  - `path` may be empty (REPL/in-memory input), but the field must exist.

#### Required capabilities

- `Range::one_line() -> Bool`
- `Position::advance(rune, by_utf16: Bool) -> Position` (if lexer/parser needs it)
- `Range::to_string()`: for diagnostics (at minimum include `path:start`).

> Compatibility strategy: keep existing `lexer.Position/Range` as deprecated (or rename to `LegacyPosition/LegacyRange`), and provide conversion functions during a transition window.

### 2.2 Unified AST Node abstraction

#### Goal

Any AST node can:
- `get_range() -> Range`
- `node_type() -> String`
- `children() -> Array[Node]`

#### Suggested implementation (no exposed `mut`)

Introduce a `pub(all) enum Node` as a boxed AST node container:
- `Node::Map(Map)` / `Node::Key(Key)` / `Node::Scalar(Scalar)` / ...

Externally, expose `pub type Node = ...` plus methods.

#### Syntax information that must be preserved

- String kinds (unquoted/single/double/block) must remain distinguishable and retain raw content.
- KeyPath elements should preserve the original token form, to support the future `ID` vs `IDVal` split.

### 2.3 IR: node tree + reference context

#### Goal

IR must support “tree-like, traceable” semantic capabilities:

- Node can:
  - `parent() -> Node?`
  - `copy(new_parent: Node?) -> Node`
  - `ast() -> ast.Node` (or `ast.Node?`)
  - `last_ref()/last_primary_ref()` (for error locations / display)

- Reference must be traceable to:
  - the most specific AST node (Range)
  - the context where the reference occurred (scope/map/key/edge, at least one representation)
  - `due_to_glob` / `due_to_lazy_glob`

#### Public type shape (suggested)

> Key constraint: no `mut` fields in public structs/enums.

- `pub type Node`: abstract/opaque (recommended) to avoid exposing parent-pointer implementation details as fields.
- `pub type Map` / `pub type Field` / `pub type Edge` / `pub type Scalar` / `pub type Array`: also opaque.

Provide necessary read-only accessors:
- `Map::fields() -> Array[Field]`
- `Map::edges() -> Array[Edge]`
- `Field::name() -> ast.String` (or a custom `SyntaxString`)
- `Field::primary() -> Scalar?`
- `Field::composite() -> Composite?`

#### Value domain (Scalar / attribute values)

- IR `Scalar` should not eagerly coerce numbers/bools into `Double/Bool` as the final representation;
- Keep `raw : String` and `source : Range`, and provide parsing helpers (`as_bool/as_int/as_float`) to validate at the point of use and produce good diagnostics.

### 2.4 Graph: compiled Graph product (boards + references + style strings)

#### Goal

Graph, as the main cross-module carrier, should include:
- board tree: `parent` + `layers/scenarios/steps` (recursive graphs)
- compilation context: `ast` (post-expansion) and `base_ast` (pre-expansion)
- theme + data (metadata)

#### Suggested public types (high-level)

- `pub type Graph` (opaque)
- `pub type Object` (opaque)
- `pub type Edge` (opaque)
- `pub type Style` (opaque, or `pub struct` with `string+range` fields)

#### Object ID semantics (required)

- `id : SyntaxString` (preserve syntactic string for key-path composition)
- `id_val : String` (actual value for comparisons/lookups)

#### Style semantics (required)

Each style field is:
- `value : String`
- `source : Range`
- (optional) `map_key : ast.Key?` or similar stronger linkage

> Note: even if rendering ultimately needs `Double/Bool`, parsing should happen at the renderer/layout stage, and errors should point back to `source`.

### 2.5 Diagram / Layout interaction contract

#### Goal

- `diagram` should take `graph.Graph` as input and build a renderable view model.
- `engine_api` / layout engines operate on `graph.Graph`:
  - recommended “write back in place” semantics (implementation can return a new Graph) to write `Box/Route` into objects/edges.

#### Two possible shapes (pick one and keep it stable)

- **Shape A (pure functional)**:
  - `layout(graph: Graph, config: LayoutConfig) -> (Graph, LayoutWarnings)`
- **Shape B (Graph + Patch)**:
  - `layout(graph: Graph, ...) -> LayoutPatch`
  - `Graph::apply_patch(patch) -> Graph`

Under “public types are immutable”, both A/B work. A is more direct but implies more copying; B is more performance- and increment-friendly.

---

## 3. Proposed package-level API changes (by package)

> Below lists the public API items to add/replace/deprecate (not concrete file patches).

### 3.1 `lexer/`

- Add: `Position/Range` (with `path` + `byte`, 0-based).
- Adjust: `LexError` range type replaced with the new `Range`.
- Compatibility: keep old `Position/Range` as deprecated and provide conversions.

### 3.2 `ast/`

- Add: unified boxed `Node` abstraction.
- Adjust: existing `Map/Key/...` `range` fields to use the new `lexer.Range` (with `path`).
- Must: String/KeyPath elements preserve syntactic info (cannot degrade to plain `String`).

### 3.3 `ir/`

- Goal: migrate from `pub struct Map { fields : Array[Field] ... }` to `pub type Map` (opaque).
- Add: `Node`/`Reference`/`RefContext` (or equivalent).
- Adjust:
  - `EdgeID` / path fields from `Array[String]` to syntax-string arrays (e.g., `Array[ast.StringValue]` or a new `SyntaxString`).
  - `Scalar` becomes `raw:String + range:Range + kind` (or equivalent).
- Deprecate/remove: exposing `Map/Field/Edge` with public fields (expected to break downstream).

### 3.4 `graph/`

- Goal: introduce compiled `Graph/Object/Edge/Style` as the primary interaction types, replacing `GraphInput/ObjectInput/EdgeInput/StyleInput`.
- Key changes:
  - Object: add `id_val`, `map/refs`, child structure (at least stable order + lookup).
  - Graph: add `parent`, `ast/base_ast`, `theme`, `data`.
  - Style: switch to `string+range` per field.

### 3.5 `compiler/`

- Goal: upgrade from “parse only” to “compile into Graph”.
- Add a top-level entry (suggested):
  - `compile(path: String, input: String, opts: CompileOptions) -> (graph.Graph, CompileWarnings) raise CompileError`
  - `CompileOptions` includes at least: `utf16_pos : Bool`, filesystem/import resolver.

### 3.6 `engine_api/` + `diagram/`

- `engine_api`:
  - `LayoutEngine` trait input changes from `graph.GraphInput` to the new `graph.Graph`.
  - Output: return a new `graph.Graph` or return a patch.

- `diagram`:
  - `build(graph: graph.Graph) -> Diagram` (or `build(graph, layout)` depending on the final interface).
  - `RenderGraph/RenderObject` fields (e.g., `style`) should use the new Graph style representation or its parsed result.

---

## 4. Breaking-change impact (expected)

This refactor will cause large `.mbti` changes in:
- `lexer/pkg.generated.mbti`
- `ast/pkg.generated.mbti`
- `ir/pkg.generated.mbti`
- `graph/pkg.generated.mbti`
- `compiler/pkg.generated.mbti`
- `engine_api/pkg.generated.mbti`
- `diagram/pkg.generated.mbti`

Directly affected downstream:
- layout engines (`engine_elk/engine_dagre/engine_railway/...`)
- renderers (`renderer_svg/renderer_ascii/renderer_unicode`)
- tests (nearly the whole suite)

---

## 5. Suggested implementation order (trackable milestones)

> The goal is for each step to “compile + keep `moon test` runnable when possible”.

### M0: Span unification (lexer)

- Introduce the new `Position/Range` and make lexer/parser/ast use it.

### M1: Unified AST Node

- Introduce boxed `ast.Node`.
- Make parser output traversable via `ast.Node`.

### M2: Refactor IR into a Node model

- Introduce `ir.Node/Map/Field/Edge/Reference/RefContext`.
- Make `ir.compile` produce the new IR first, while keeping the old IR for a short time (can live in `ir/deprecated.mbt`).

### M3: Refactor Graph as a compiled product

- Add `compiler.compile -> graph.Graph`.
- Add new `graph.Graph/Object/Edge/Style`.

### M4: Adapt Layout/Diagram/Render

- `engine_api` takes the new Graph.
- `diagram` builds a renderable model from Graph.

---

## 6. Key design decisions (confirmed)

- `Position.line/column`: 0-based.
- Style: cross-module interaction uses `string + source range`; parsing happens at the point of use.
- Immutability: no `mut` fields in public structs/enums; internal mutability is hidden behind opaque types.

---

## 7. Next step: I need concrete instructions

To start landing real implementation, please specify:
1) **Which milestone to do next** (recommended: M0 → M1 → M2).
2) The final role of `graph`:
   - “Graph is the compiled product and layout writes back box/route”, or
   - “Graph and LayoutResult are separate but still traceable”.

Once confirmed, I will implement milestone-by-milestone and run `moon info && moon fmt && moon test` at each stage.
