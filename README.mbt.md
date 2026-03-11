# Diago

Diago is a MoonBit implementation of the [D2](https://d2lang.com) diagram language.
It compiles `.d2` files into SVG (and optionally ASCII/Unicode text) using multiple
layout engines.

## Overview

This repository contains:

- A CLI (`cmd/diago`) to render, format, validate, and watch `.d2` files
- A WASM-based playground (`web/`) deployed via GitHub Pages
- Multiple layout engines: `dagre`, `elk`, and `railway`

## Installation

```bash
moon update
moon build
```

## Quick Start

```bash
moon run cmd/diago -- diagram.d2 > diagram.svg
```

## CLI

Show help:

```bash
moon run cmd/diago -- --help
```

Common usage:

```bash
# Render SVG (default)
moon run cmd/diago -- diagram.d2 > diagram.svg
moon run cmd/diago -- diagram.d2 diagram.svg

# Choose layout engine
moon run cmd/diago -- --layout elk diagram.d2 diagram.svg
moon run cmd/diago -- -l dagre diagram.d2 diagram.svg

# ASCII / Unicode text
moon run cmd/diago -- --ascii diagram.d2 > diagram.ascii.txt
moon run cmd/diago -- --unicode diagram.d2 > diagram.unicode.txt

# Format / validate
moon run cmd/diago -- fmt -w diagram.d2
moon run cmd/diago -- validate diagram.d2

# Dump layout engine input JSON (for debugging)
moon run cmd/diago -- dump-input --engine elk --out-dir /tmp/diag-elk-input diagram.d2
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
moon run cmd/diago -- example.d2 example.svg
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
