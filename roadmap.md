# Diago Roadmap

This document tracks features from the D2 reference implementation that are not yet implemented in diago.

## Legend
- [ ] Not started
- [x] Completed
- 🔴 High priority
- 🟡 Medium priority
- 🟢 Low priority

---

## Layout Engine

### 🔴 High Priority
- [ ] **Virtual/Dummy Nodes** - Split long edges spanning multiple layers with dummy nodes for proper edge routing
- [ ] **ELK Layout Engine** - Alternative layout engine with better handling of complex graphs
- [ ] **Near/Absolute Positioning** - `near` keyword for relative positioning, absolute coordinate placement
- [ ] **Constant Near Positions** - `near: top-left`, `near: center`, etc. for label positioning

### 🟡 Medium Priority
- [x] **Curved Edges** - Spline-based edge routing with configurable curvature
- [ ] **Edge Bend Points** - Manual control points for edge routing
- [ ] **Label Positioning** - Automatic label placement avoiding overlaps
- [x] **Connection Anchors** - Control edge connection points on shapes

### 🟢 Low Priority
- [x] **Animated Edges** - CSS animations for edges (`animated: true`)

---

## Shapes

### Currently Supported (24/24)
- [x] rectangle
- [x] square
- [x] circle
- [x] oval
- [x] diamond
- [x] hexagon
- [x] parallelogram
- [x] cylinder
- [x] queue
- [x] package
- [x] step
- [x] callout
- [x] stored_data
- [x] person
- [x] cloud
- [x] page
- [x] document
- [x] text
- [x] code
- [x] class
- [x] sql_table

### 🔴 Missing Core Shapes
- [x] **image** - External image embedding

### 🟢 Utility Shapes (Complete)
- [x] **c4_person** - C4 diagram person shape
- [x] **c4_container** - C4 diagram container shape

---

## Arrowheads

### Currently Supported (13/24)
- [x] triangle (default)
- [x] arrow (alias for triangle)
- [x] diamond
- [x] circle
- [x] cf-one (crow's foot one)
- [x] cf-many (crow's foot many)
- [x] cf-one-required (required crow's foot)
- [x] cf-many-required (required crow's foot)
- [x] cf-one-optional (optional crow's foot)
- [x] cf-many-optional (optional crow's foot)
- [x] line (simple line terminator)
- [x] open (open triangle)
- [x] none

### 🟢 Low Priority Arrowheads
- [ ] Custom arrowhead definitions via DSL

---

## Diagrams & Special Features

### 🔴 High Priority
- [ ] **Sequence Diagrams** - Full sequence diagram support with actors, messages, lifelines
  - [ ] Spans (activation boxes)
  - [ ] Notes
  - [ ] Groups/fragments
  - [ ] Self-referential messages

### 🟡 Medium Priority
- [ ] **Layers** - Multiple diagram layers (`layers: { ... }`)
- [ ] **Scenarios** - Diagram variants (`scenarios: { ... }`)
- [ ] **Steps** - Incremental diagram building (`steps: { ... }`)
- [ ] **Grid Layout** - Explicit grid-based positioning (`grid-rows`, `grid-columns`)
  - [x] Basic grid layout
  - [x] Grid gaps
  - [ ] Cell spanning

### 🟢 Low Priority
- [ ] **Icons** - Icon embedding and positioning
- [ ] **LaTeX** - Mathematical formula rendering
- [x] **Tooltips** - Interactive hover tooltips

---

## Styling

### Currently Supported
- [x] fill
- [x] stroke
- [x] stroke-width
- [x] stroke-dash
- [x] font-size
- [x] font-color
- [x] bold
- [x] italic
- [x] underline
- [x] opacity
- [x] border-radius
- [x] shadow
- [x] 3D effect

### 🟡 Missing Styles
- [x] **fill-pattern** - Pattern fills (dots, lines, cross-hatch, grain)
- [x] **sketch mode** - Hand-drawn appearance (`style.sketch: true`)
- [x] **double-border** - Double border lines
- [x] **text-transform** - uppercase, lowercase, capitalize
- [x] **font-family** - Custom font selection

---

## Themes

### Currently Supported (24/32)
All core themes implemented. Missing specialty themes:

### 🟢 Low Priority
- [x] Terminal theme
- [x] Terminal Grayscale theme
- [ ] Additional dark theme variants

---

## Language Features

### 🔴 High Priority
- [ ] **Imports** - `...@import` for modular diagrams
- [ ] **Globs** - Wildcard patterns for bulk styling (`*.style.fill: red`)

### 🟡 Medium Priority
- [ ] **Nested Variable Substitution** - `${parent.child}` syntax
- [ ] **Variable Overrides** - Override variables in nested scopes
- [ ] **Label Substitution** - Use variables in labels

### 🟢 Low Priority
- [ ] **Legend/Explanation** - Auto-generated diagram legend

---

## Tooling

### 🟡 Medium Priority
- [ ] **Watch Mode** - Auto-rebuild on file changes
- [ ] **Multiple Output Formats** - PNG, PDF export (currently SVG only)
- [ ] **CLI Improvements**
  - [ ] Input from stdin
  - [ ] Multiple file processing
  - [ ] Output to stdout

### 🟢 Low Priority
- [ ] **LSP Server** - Language Server Protocol for editor integration
- [ ] **Formatter** - Auto-format D2 source code
- [ ] **REPL** - Interactive diagram editing

---

## Performance & Quality

### 🟡 Medium Priority
- [ ] **Large Graph Optimization** - Handle 100+ node graphs efficiently
- [ ] **Incremental Layout** - Only re-layout changed portions
- [ ] **Text Measurement** - Accurate text bounding box calculation

### 🟢 Low Priority
- [ ] **Layout Caching** - Cache layout results for unchanged subgraphs
- [ ] **Parallel Processing** - Multi-threaded layout computation

---

## Documentation & Testing

- [ ] API documentation generation
- [ ] Visual regression tests
- [ ] Performance benchmarks
- [ ] More example diagrams

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 0.1.0 | - | Initial release with core D2 parsing, Sugiyama layout, SVG/ASCII export |

---

## Contributing

See [CLAUDE.md](./CLAUDE.md) for development guidelines and build commands.
