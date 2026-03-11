# Diago

Diago is a MoonBit implementation of the [D2](https://d2lang.com) diagram language.
It compiles `.d2` files into SVG (and optionally ASCII/Unicode text) using multiple
layout engines.

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
moon run cmd/diago -- render diagram.d2
```

## CLI

Show help:

```bash
moon run cmd/diago -- --help
```

Common usage:

```bash
# Render SVG (default output: input.svg)
moon run cmd/diago -- render diagram.d2
moon run cmd/diago -- render diagram.d2 diagram.svg
moon run cmd/diago -- render diagram.d2 --output diagram.svg

# Choose layout engine
moon run cmd/diago -- render --layout elk diagram.d2 diagram.svg
moon run cmd/diago -- render -l dagre diagram.d2 diagram.svg

# ASCII / Unicode text
moon run cmd/diago -- render --format ascii diagram.d2 --output diagram.ascii.txt
moon run cmd/diago -- render --format unicode diagram.d2 --output diagram.unicode.txt

# Format / validate
moon run cmd/diago -- fmt diagram.d2
moon run cmd/diago -- fmt --check diagram.d2
moon run cmd/diago -- validate diagram.d2

# Watch mode
moon run cmd/diago -- render --watch diagram.d2

# Introspection
moon run cmd/diago -- layout
moon run cmd/diago -- layout elk
moon run cmd/diago -- themes
moon run cmd/diago -- version
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
moon run cmd/diago -- render example.d2 example.svg
```

## Pipeline

At a high level:

```
D2 Source → Lexer → Parser → AST → IR → Graph → Layout (dagre/elk/railway) → Render (SVG/ASCII/Unicode)
```

## Tests

```bash
moon test        # Run all tests
moon test -v     # Verbose output
```

## License

Apache-2.0 (see `LICENSE`).
