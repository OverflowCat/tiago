# Diago

A D2 diagram language compiler written in MoonBit.

## Overview

Diago compiles [D2](https://d2lang.com) diagram source files to SVG. It implements the core D2 language features including objects, edges, labels, shapes, and styling.

## Installation

```bash
moon build
```

## Usage

```bash
# Compile D2 to SVG (output to stdout)
moon run cmd/main -- diagram.d2

# Compile D2 to SVG file
moon run cmd/main -- diagram.d2 output.svg
```

## Example

Create a file `example.d2`:

```d2
server: Web Server
database: Database {
  shape: cylinder
}
cache: Cache {
  shape: oval
}

server -> database: queries
server -> cache: reads
cache -> database: fallback
```

Compile it:

```bash
moon run cmd/main -- example.d2 example.svg
```

## Architecture

The compiler pipeline:

```
D2 Source → Lexer → Parser → AST → IR → Graph → Layout → SVG
```

| Module | Description |
|--------|-------------|
| `lexer` | Tokenizes D2 source into tokens |
| `parser` | Parses tokens into AST |
| `ast` | Abstract syntax tree definitions |
| `ir` | Intermediate representation |
| `graph` | Graph data structures (objects, edges) |
| `layout` | Positions objects and routes edges |
| `svg` | Renders graph to SVG |

## Supported Features

- Objects with labels
- Nested objects (containers)
- Edges with labels and arrows (`->`, `<-`, `<->`, `--`)
- Shapes: rectangle, circle, oval, cylinder, diamond, hexagon
- Style properties: fill, stroke, stroke-width, border-radius
- Edge chains: `a -> b -> c`

## Tests

```bash
moon test        # Run all tests
moon test -v     # Verbose output
```

## License

MIT
