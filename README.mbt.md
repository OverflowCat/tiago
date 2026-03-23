# Diago

Diago is a diagram toolkit for MoonBit.
It supports a D2-compatible text format and renders diagrams through multiple layout engines.

## Overview

This repository contains:

- A CLI (`cmd/diago`) with explicit subcommands (`render`, `fmt`, `validate`, `layout`, `themes`, `version`)
- A WASM-based playground (`web/`) deployed via GitHub Pages
- Multiple layout engines: `dagre`, `elk`, and `railway`

## Installation

```bash
moon update
moon build
```

## Quick Start

```bash
moon run cmd/diago -- render diagram.txt
```

## CLI

Show help:

```bash
moon run cmd/diago -- --help
```

Common usage:

```bash
# Render SVG (default output: input.svg)
moon run cmd/diago -- render diagram.txt
moon run cmd/diago -- render diagram.txt diagram.svg
moon run cmd/diago -- render diagram.txt --output diagram.svg

# Choose layout engine
moon run cmd/diago -- render --layout elk diagram.txt diagram.svg
moon run cmd/diago -- render -l dagre diagram.txt diagram.svg

# ASCII / Unicode text
moon run cmd/diago -- render --format ascii diagram.txt --output diagram.ascii.txt
moon run cmd/diago -- render --format unicode diagram.txt --output diagram.unicode.txt

# Format / validate
moon run cmd/diago -- fmt diagram.txt
moon run cmd/diago -- fmt --check diagram.txt
moon run cmd/diago -- validate diagram.txt

# Watch mode (rebuilds output on file changes)
moon run cmd/diago -- render --watch diagram.txt

# Introspection
moon run cmd/diago -- layout
moon run cmd/diago -- layout elk
moon run cmd/diago -- themes
moon run cmd/diago -- version
```

## Example

Create a file `example.txt`:

```text
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
moon run cmd/diago -- render example.txt example.svg
```

## Pipeline

At a high level:

```
Source → Lexer → Parser → AST → IR → Graph → Layout (dagre/elk/railway) → Render (SVG/ASCII/Unicode)
```

## Tests

```bash
moon test        # Run all tests
moon test -v     # Verbose output
```

## License

Apache-2.0 (see `LICENSE`).
