# D2 Package Ownership Decision

This note records the package-boundary decision for diago's D2 alignment work.

## Decision

diago will keep the current `compiler` + `lib` split, but interpret it as a
MoonBit-native equivalent of D2's `d2compiler` + `d2lib`, not as a literal
package-for-package port.

The main rule is:

- `compiler` owns source-to-graph compilation concerns.
- `lib` owns graph-to-diagram-to-render orchestration concerns.
- `diago.mbt` remains the public facade package for ergonomic top-level APIs.
- file-system helpers stay outside `compiler` and `lib`.

This is intentionally close to D2 in responsibility shape, while still fitting
MoonBit's package model and the repository's public API surface.

## Boundary Rules

### `compiler`

`compiler` is the D2-compiler-equivalent layer in diago.

It owns:

- parsing source text into AST
- compiling AST into IR
- import resolution through an injected resolver capability
- extracting `vars.d2-config` source config
- exporting compiled IR into `graph.GraphInput`
- attaching graph-level metadata derived from source config

It does not own:

- file I/O
- CLI/environment/product flag semantics
- layout engine selection
- route/layout plugin execution
- diagram selection/render dispatch

### `lib`

`lib` is the D2-library-equivalent orchestration layer in diago.

It owns:

- layout engine resolution from explicit options and source config
- layout and route plugin execution
- graph-to-diagram conversion
- target board selection
- render-config resolution
- final renderer dispatch (`svg` / `ascii` / `unicode`)

It does not own:

- parsing or import resolution
- file I/O
- CLI flag parsing
- product workflows like watch, stdout/file decisions, or browser bootstrapping

### `diago.mbt` and `diago_io.mbt`

These stay as MoonBit-native facade layers.

They own:

- the public top-level API
- option translation between facade types and lower layers
- file-based helpers like `parse_file` / `compile_file`
- default file-system-backed import resolver wiring

This is the main deliberate divergence from D2's public package layout: D2's
public entrypoint is `d2lib`, while diago keeps a root facade package for
MoonBit users.

## Ownership Map

| D2 package / area | diago owner | Status / note |
| --- | --- | --- |
| `d2ast` | `ast` | Direct owner of syntax tree data types. |
| `d2parser` | `parser` | Direct owner of text-to-AST parsing helpers, including standalone key-path parsing. |
| `d2format` | `formatter` | Direct owner of source formatting. |
| `d2ir` | `ir` | Direct owner of semantic IR, references, and import-aware source tracing. |
| `d2exporter` | `exporter` | Internal compiler-stage owner of IR-to-graph lowering. |
| `d2compiler` | `compiler` | Source-to-graph orchestration owner. Depends on `parser`, `ir`, and `exporter`. |
| `d2graph` | `graph` | Direct owner of graph data models and engine-facing immutable inputs. |
| `d2target` | `diagram` | Direct owner of target/diagram data model and graph-to-diagram projection. |
| `d2lib` | `lib` | Graph-to-layout-to-render orchestration owner. |
| `d2layouts/*` | `engine_api` + `engine_dagre` + `engine_elk` + `graph` / `diagram` helpers | Split across engine packages and shared helpers; no single literal D2 package mirror. |
| `d2renderers/d2svg` | `renderer_svg` + `svg` + `xml_emit` + `text_metrics` + `font_subset` | SVG/rendering ownership is intentionally decomposed into MoonBit packages. |
| `d2renderers/d2ascii` | `renderer_ascii` | ASCII/text rendering owner. |
| `d2renderers/d2unicode`-like surface | `renderer_unicode` | diago extension; retained as a separate text renderer. |
| `d2themes/*` | `themes` + renderer config logic in `lib` | Theme catalog lives in `themes`; option resolution lives in `lib`. |
| `d2lsp` + `d2oracle` | `tooling.mbt` | Single-package owner for now; parity still incomplete. |
| `d2cli` | `cmd/diago` | Product CLI owner. |
| `d2js` / browser wasm surface | `cmd/wasm` + `web/` | Browser/wasm embedding owner. |
| `d2plugin` | intentionally omitted | Plugin-system integration is currently out of scope for alignment. |
| `d2renderers/d2latex` | intentionally omitted | LaTeX rendering is currently out of scope for alignment. |

## Consequences

- We should not move file-based helpers back into `compiler`.
- New source-compilation behavior should land in `compiler` or one of its owned
  stage packages, not in `lib`.
- New layout/render/product behavior should land in `lib`, renderer packages, or
  CLI packages, not in `compiler`.
- When a D2 area does not map 1:1 to one diago package, the owner should still
  be explicit in this document and in the alignment checklist.

## Follow-Through

With this decision in place, the architecture work item is considered settled.
Future alignment tasks should now target behavior gaps inside the mapped owner
packages instead of revisiting the `compiler` / `lib` boundary itself.
