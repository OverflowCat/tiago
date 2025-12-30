# PRD: diago (MoonBit D2 Diagram Language)

## Problem

Modern software development requires extensive technical documentation including architecture diagrams, flowcharts, and sequence diagrams. Existing diagramming tools have the following limitations:

1. **GUI Tool Limitations**: Drag-and-drop tools (e.g., Visio, Draw.io) are difficult to version control, hard to automate, and expensive to maintain
2. **DSL Learning Curve**: Existing diagram-as-code tools (e.g., PlantUML, Mermaid) have complex syntax or limited functionality
3. **Lack of MoonBit Ecosystem Support**: There is currently no high-quality diagram language library implemented in MoonBit

D2 is a modern declarative diagram language with concise syntax and powerful features, but currently only has a Go implementation. Porting it to MoonBit enables:
- Professional-grade diagram generation capabilities for the MoonBit ecosystem
- Browser execution leveraging MoonBit's WASM compilation features
- A type-safe, high-performance diagram compiler

**Target Users**:
- Software developers needing to generate architecture and flow diagrams
- Technical documentation authors
- Developers integrating diagram rendering into web applications
- MoonBit ecosystem users

---

## Goal

Implement a complete D2 diagram language compilation and rendering pipeline in MoonBit, achieving feature parity with the official Go implementation while leveraging MoonBit's language features for better type safety and WASM support.

**Core Objectives**:
1. 100% D2 syntax compatibility (verified through official test cases)
2. SVG output format support
3. Support for all built-in shapes and themes
4. Compilable to WASM for browser execution
5. Clear API for use by other MoonBit projects

---

## Core Features

### Phase 1: Parser & AST (Core Parser)

#### F1.1 Lexer
- UTF-8 source input support
- Token types: keywords, identifiers, strings (4 variants), numbers, operators, comments
- Position tracking (line number, column, byte offset)
- Error recovery mechanism

#### F1.2 Parser
- Recursive descent parser
- Supported syntax elements:
  - Key-value pairs: `key: value`
  - Nested paths: `container.child.grandchild`
  - Edge declarations: `x -> y`, `x <- y`, `x <-> y`
  - Multi-segment edges: `a -> b -> c`
  - Containers: `{ }` nested structures
  - Arrays: `[ ]`
  - Comments: `#` single-line, `/* */` multi-line
  - Strings: unquoted, single-quoted, double-quoted, block strings
  - Variable substitution: `${var}` or `$var`
  - Imports: `@path/to/file.d2`
- Complete error reporting (position, context, suggestions)

#### F1.3 Abstract Syntax Tree (AST)
- `Map` - root node and nested mappings
- `Key` - key paths (including edge definitions)
- `Value` - scalar values, arrays, mappings
- `Scalar` - Null, Boolean, Number, String
- `String` - four string variants
- `Edge` - edge definitions (source, target, direction)
- `Comment` - comment nodes
- `Substitution` - variable substitution
- `Import` - file imports
- All nodes contain `Range` position information

### Phase 2: IR & Semantic Analysis (Intermediate Representation)

#### F2.1 IR Compilation
- AST to IR transformation
- Variable scope resolution
- Import file resolution and merging
- Glob pattern expansion (`*`, `**`, `***`)
- Filter expression processing (`&key`)

#### F2.2 Semantic Analysis
- Reference resolution and validation
- Type checking (shape types, style properties)
- Edge validity verification (source/destination must exist)
- Circular reference detection
- Reserved field validation

### Phase 3: Graph Compilation

#### F3.1 Graph Data Structure
```
Graph {
  root: Object           // Root container
  objects: Array[Object] // All objects
  edges: Array[Edge]     // All connections
  layers: Array[Graph]   // Layers
  scenarios: Array[Graph]// Scenarios
  steps: Array[Graph]    // Steps (animation)
  theme: Theme           // Theme
  config: Config         // Configuration
}

Object {
  id: String
  parent: Object?
  children: Map[String, Object]
  position: Point        // Filled after layout
  size: Size             // Filled after layout
  shape: ShapeType
  style: Style
  label: String?
  icon: String?
}

Edge {
  src: Object
  dst: Object
  src_arrow: ArrowType
  dst_arrow: ArrowType
  route: Array[Point]    // Filled after routing
  label: String?
  style: Style
}
```

#### F3.2 Shape Types (25+)
- **Geometric shapes**: rectangle, square, circle, oval, diamond, hexagon, parallelogram, cylinder, queue, document, page, callout, step, etc.
- **Special shapes**: person, cloud, package, stored_data
- **Container shapes**: rectangle (default container)
- **Domain-specific**:
  - `sql_table` - SQL table diagrams
  - `class` - UML class diagrams
  - `code` - code blocks
  - `text` - plain text

#### F3.3 Style System
```
Style {
  stroke: Color?
  stroke_width: Int?
  stroke_dash: Int?
  fill: Color?
  opacity: Float?
  font_size: Int?
  font_color: Color?
  bold: Bool?
  italic: Bool?
  underline: Bool?
  shadow: Bool?
  multiple: Bool?        // 3D stacking effect
  border_radius: Int?
}
```

### Phase 4: Layout Engine

#### F4.1 Dagre Layout (Priority Implementation)
- Hierarchical layout algorithm (Sugiyama)
- Node layering
- Crossing minimization
- Horizontal coordinate assignment
- Supported directions: TB (top-bottom), BT, LR, RL

#### F4.2 Grid Layout
- `grid-rows` / `grid-columns` properties
- Automatic cell sizing
- Cell spacing and alignment

#### F4.3 Sequence Diagram Layout
- Lifeline layout
- Actor position calculation
- Message arrow routing
- Group/fragment handling

#### F4.4 Edge Routing
- Orthogonal routing (right-angle turns)
- Obstacle avoidance algorithm
- Label placement optimization

### Phase 5: Rendering

#### F5.1 SVG Renderer
- Shape rendering (SVG path data)
- Edge/arrow rendering
- Text layout and rendering
- Icon embedding (base64)
- CSS style generation
- Theme application
- Legend rendering

#### F5.2 Theme System
- 25+ built-in themes
- Color palettes:
  - Neutrals (N1-N7)
  - Base colors (B1-B6)
  - Alternative colors (AA2-AA5, AB4-AB5)
- Special rules:
  - Mono (monospace font)
  - NoCornerRadius (sharp corners)
  - Sketch (hand-drawn style)
  - CapsLock (uppercase text)

### Phase 6: API & CLI (Interface)

#### F6.1 Library API
```moonbit
// Parse
pub fn parse(source: String) -> Result[Ast, ParseError]

// Compile
pub fn compile(source: String, opts: CompileOptions) -> Result[Graph, CompileError]

// Render
pub fn render(graph: Graph, opts: RenderOptions) -> Result[String, RenderError]

// All-in-one
pub fn d2_to_svg(source: String) -> Result[String, Error]
```

#### F6.2 CLI Tool
```bash
diago input.d2 output.svg        # Basic compilation
diago --theme=dark input.d2      # Specify theme
diago --layout=grid input.d2     # Specify layout
diago fmt input.d2               # Format
diago validate input.d2          # Validate syntax
```

---

## Acceptance Criteria

### AC1: Parser Correctness
- [ ] Pass official d2 parser test cases (100%)
- [ ] All 4 string types parsed correctly
- [ ] Edge declarations (`->`, `<-`, `<->`) parsed correctly
- [ ] Nested containers parsed correctly
- [ ] Error messages contain accurate position information
- [ ] UTF-8 multi-byte characters handled correctly

### AC2: IR & Semantic Correctness
- [ ] Variable substitutions expanded correctly
- [ ] Glob patterns matched correctly
- [ ] Import files parsed and merged correctly
- [ ] Semantic errors reported correctly (undefined references, type errors, etc.)

### AC3: Graph Compilation Correctness
- [ ] All 25+ shape types recognized correctly
- [ ] Style properties inherited and overridden correctly
- [ ] Multi-board (layers/scenarios/steps) compiled correctly
- [ ] Legends generated correctly

### AC4: Layout Correctness
- [ ] Dagre layout produces no node overlap
- [ ] Edge routing minimizes crossings
- [ ] Grid layout cell alignment is correct
- [ ] Sequence diagram lifelines arranged correctly

### AC5: SVG Rendering Correctness
- [ ] All shapes rendered correctly (pixel-level comparison tests)
- [ ] Theme colors applied correctly
- [ ] Text does not overflow containers
- [ ] Icons embedded correctly
- [ ] SVG displays correctly in major browsers

### AC6: Performance Requirements
- [ ] 1000-node diagram compilation time < 1 second
- [ ] WASM bundle size < 2MB (gzipped)
- [ ] Memory usage grows linearly (relative to diagram size)

### AC7: API Usability
- [ ] All public APIs have documentation comments
- [ ] Error types are explicit and handleable
- [ ] Compilation options fully exposed

---

## Scope

### In Scope
1. Complete D2 syntax implementation (parser, AST, IR)
2. Graph structure compilation and validation
3. Dagre hierarchical layout algorithm
4. Grid layout
5. Sequence diagram layout
6. SVG rendering output
7. 25+ built-in themes
8. All 25+ built-in shapes
9. Basic CLI tool
10. Library API
11. WASM compilation support
12. Error recovery and friendly error messages

### Out of Scope
1. PNG/PDF rendering (requires external dependencies)
2. PPTX export
3. GIF animation generation
4. ELK/TALA layout engines (can be added as plugins later)
5. LSP language server (can be a separate project)
6. Watch mode and live preview
7. Image bundling (inline base64 is sufficient)
8. Custom font embedding (use system or web fonts)

### Deferred
1. Plugin system (layout/rendering plugins)
2. Incremental compilation
3. Source maps
4. Interactive SVG (click, hover events)

---

## Correctness Verification

### 1. Reference Implementation Comparison
- Use official d2 Go implementation as reference
- Same input should produce semantically equivalent output
- Visual regression testing for SVG output

### 2. Official Test Cases
- Port test cases from d2 repository
  - `d2parser/` parser tests
  - `d2compiler/` compiler tests
  - `d2exporter/` exporter tests
- Test file location: `testdata/` directory

### 3. Snapshot Testing
- Collect 100+ D2 example files
- Generate SVG snapshots
- Regression detection in CI

### 4. Fuzz Testing
- Fuzz test the parser
- Ensure no crashes, only errors returned

### 5. Edge Case Testing
- Empty input
- Very large files (10000+ lines)
- Deep nesting (100+ levels)
- Unicode edge cases (emoji, RTL text, zero-width characters)
- Circular references

---

## Reproduction Steps

### Environment Setup
```bash
cd /path/to/diago

# Check MoonBit toolchain
moon version

# Update dependencies (if any)
moon update
```

### Build and Check
```bash
# Type check
moon check

# Run tests
moon test

# Format code
moon fmt

# Build
moon build

# Build WASM
moon build --target wasm
```

### Run CLI (After Implementation)
```bash
# Compile D2 to SVG
moon run cmd/main -- examples/hello.d2 output.svg

# Validate syntax
moon run cmd/main -- validate examples/hello.d2

# Format D2 source
moon run cmd/main -- fmt examples/hello.d2
```

### Test Coverage
```bash
moon test --coverage
```

---

## Architecture Overview

### Module Structure

```
diago/
├── moon.mod.json           # Project configuration
├── moon.pkg.json           # Root package configuration
├── diago.mbt               # Main entry (re-exports)
│
├── lexer/                  # Lexical analysis
│   ├── token.mbt           # Token definitions
│   ├── lexer.mbt           # Lexer implementation
│   └── lexer_test.mbt      # Tests
│
├── ast/                    # Abstract Syntax Tree
│   ├── ast.mbt             # AST node definitions
│   ├── keywords.mbt        # Keyword table
│   ├── visitor.mbt         # Visitor pattern
│   └── ast_test.mbt        # Tests
│
├── parser/                 # Syntax parsing
│   ├── parser.mbt          # Recursive descent parser
│   ├── error.mbt           # Parse errors
│   └── parser_test.mbt     # Tests
│
├── ir/                     # Intermediate Representation
│   ├── ir.mbt              # IR node definitions
│   ├── compile.mbt         # AST -> IR compilation
│   ├── pattern.mbt         # Glob pattern handling
│   ├── import.mbt          # Import resolution
│   └── ir_test.mbt         # Tests
│
├── compiler/               # Graph structure compilation
│   ├── compiler.mbt        # IR -> Graph compilation
│   ├── validate.mbt        # Semantic validation
│   └── compiler_test.mbt   # Tests
│
├── graph/                  # Graph data structures
│   ├── graph.mbt           # Graph, Object, Edge
│   ├── shape.mbt           # Shape types
│   ├── style.mbt           # Style definitions
│   └── graph_test.mbt      # Tests
│
├── layout/                 # Layout engines
│   ├── layout.mbt          # Layout interface
│   ├── dagre/              # Dagre layout
│   │   ├── dagre.mbt
│   │   ├── ranking.mbt     # Node layering
│   │   ├── ordering.mbt    # Crossing minimization
│   │   └── position.mbt    # Coordinate assignment
│   ├── grid/               # Grid layout
│   │   └── grid.mbt
│   ├── sequence/           # Sequence diagram layout
│   │   └── sequence.mbt
│   └── routing/            # Edge routing
│       └── routing.mbt
│
├── target/                 # Render target structures
│   ├── diagram.mbt         # Renderable diagram
│   ├── shape.mbt           # Render shapes
│   └── connection.mbt      # Render connections
│
├── exporter/               # Graph to target conversion
│   ├── export.mbt          # Graph -> Diagram
│   └── export_test.mbt     # Tests
│
├── svg/                    # SVG rendering
│   ├── svg.mbt             # SVG renderer
│   ├── shapes/             # Shape SVG paths
│   │   ├── rectangle.mbt
│   │   ├── circle.mbt
│   │   ├── diamond.mbt
│   │   └── ...
│   ├── arrows.mbt          # Arrow rendering
│   └── svg_test.mbt        # Tests
│
├── themes/                 # Theme system
│   ├── theme.mbt           # Theme definition
│   ├── catalog.mbt         # Built-in theme catalog
│   └── themes/             # Individual theme definitions
│       ├── default.mbt
│       ├── dark.mbt
│       └── ...
│
├── lib/                    # Utility libraries
│   ├── geo/                # Geometry calculations
│   │   ├── point.mbt
│   │   ├── box.mbt
│   │   └── vector.mbt
│   ├── color/              # Color handling
│   │   └── color.mbt
│   └── text/               # Text measurement
│       └── measure.mbt
│
├── cmd/                    # CLI
│   └── main/
│       ├── main.mbt        # CLI entry point
│       └── moon.pkg.json
│
├── testdata/               # Test data
│   ├── parser/             # Parser test cases
│   ├── compiler/           # Compiler test cases
│   └── snapshots/          # SVG snapshots
│
└── examples/               # Example files
    ├── hello.d2
    ├── sequence.d2
    ├── grid.d2
    └── ...
```

### Data Flow

```
┌─────────────┐
│ D2 Source   │
└──────┬──────┘
       ↓
┌──────────────┐     ┌─────────────┐
│    Lexer     │────→│   Tokens    │
└──────────────┘     └──────┬──────┘
                            ↓
┌──────────────┐     ┌─────────────┐
│    Parser    │────→│    AST      │
└──────────────┘     └──────┬──────┘
                            ↓
┌──────────────┐     ┌─────────────┐
│  IR Compile  │────→│     IR      │
└──────────────┘     └──────┬──────┘
                            ↓
┌──────────────┐     ┌─────────────┐
│Graph Compile │────→│   Graph     │
└──────────────┘     └──────┬──────┘
                            ↓
┌──────────────┐     ┌─────────────┐
│    Layout    │────→│Graph + Pos  │
└──────────────┘     └──────┬──────┘
                            ↓
┌──────────────┐     ┌─────────────┐
│   Exporter   │────→│  Diagram    │
└──────────────┘     └──────┬──────┘
                            ↓
┌──────────────┐     ┌─────────────┐
│ SVG Renderer │────→│    SVG      │
└──────────────┘     └─────────────┘
```

---

## Implementation Phases

### Phase 1: Core Parser
1. Lexer implementation
2. AST data structures
3. Recursive descent parser
4. Basic error handling
5. Port official parser tests

### Phase 2: IR & Compiler
1. IR data structures
2. AST -> IR compilation
3. Variable substitution
4. Basic semantic validation
5. Graph data structures
6. IR -> Graph compilation

### Phase 3: Basic Rendering
1. Basic shape SVG paths
2. Simple SVG renderer
3. Static output without layout
4. Basic theme support

### Phase 4: Layout Engine
1. Dagre algorithm implementation
2. Edge routing
3. Grid layout
4. Sequence diagram layout

### Phase 5: Polish & API
1. All shapes implemented
2. All themes
3. CLI tool
4. Library API
5. Documentation

### Phase 6: Testing & Release
1. Complete test coverage
2. Performance optimization
3. WASM build verification
4. Documentation completion
5. Release v0.1.0

---

## References

### Official Resources
- D2 Language Website: https://d2lang.com
- D2 Syntax Documentation: https://d2lang.com/tour/intro
- D2 GitHub: https://github.com/terrastruct/d2
- D2 Playground: https://play.d2lang.com

### Related Implementations
- D2 Go Source: `../d2/` (local reference)
- Dagre Algorithm: https://github.com/dagrejs/dagre
- SVG Specification: https://www.w3.org/TR/SVG2/

### MoonBit Resources
- MoonBit Documentation: https://www.moonbitlang.com/docs
- MoonBit Standard Library: https://mooncakes.io/docs/#/moonbitlang/core/

---

## Appendix A: D2 Syntax Quick Reference

```d2
# Basic nodes
server
database

# With labels
server: Web Server
database: PostgreSQL

# Connections
server -> database

# Connections with labels
server -> database: queries

# Bidirectional connections
server <-> cache

# Containers
aws: AWS {
  server: EC2
  database: RDS
}

# Styling
server.style.fill: "#f0f0f0"
server.style.stroke: red

# Shapes
database.shape: cylinder
user.shape: person

# Sequence diagrams
shape: sequence_diagram
alice -> bob: Hello
bob -> alice: Hi

# Grid layout
grid-rows: 2
grid-columns: 3
cell1
cell2
cell3
cell4
cell5
cell6
```

---

## Appendix B: Shape Type List

| Shape Name | Description | Special Properties |
|------------|-------------|-------------------|
| rectangle | Rectangle (default) | - |
| square | Square | - |
| circle | Circle | - |
| oval | Oval | - |
| diamond | Diamond | - |
| hexagon | Hexagon | - |
| octagon | Octagon | - |
| parallelogram | Parallelogram | - |
| cylinder | Cylinder (database) | - |
| queue | Queue | - |
| document | Document | - |
| page | Page | - |
| callout | Callout | - |
| step | Step | - |
| person | Person | - |
| cloud | Cloud | - |
| package | Package | - |
| stored_data | Stored Data | - |
| sql_table | SQL Table | columns |
| class | UML Class | fields, methods |
| code | Code Block | language |
| text | Plain Text | - |
| image | Image | icon |
| sequence_diagram | Sequence Diagram Container | - |

---

## Appendix C: Theme List

| ID | Name | Type |
|----|------|------|
| 0 | Default | Light |
| 1 | Neutral Grey | Light |
| 3 | Flagship Terrastruct | Light |
| 4 | Cool Classics | Light |
| 5 | Mixed Berry Blue | Light |
| 6 | Grape Soda | Light |
| 7 | Aubergine | Light |
| 8 | Colorblind Clear | Light |
| 100 | Vanilla Nitro Cola | Light |
| 101 | Orange Creamsicle | Light |
| 102 | Shirley Temple | Light |
| 103 | Earth Tones | Light |
| 104 | Everglade Green | Light |
| 105 | Buttered Toast | Light |
| 200 | Dark Flagship | Dark |
| 201 | Dark Mauve | Dark |
| 300 | Terminal | Dark |
| 301 | Terminal Grayscale | Dark |
| 302 | Origami | Light |
