# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**diago** is a MoonBit implementation of the D2 diagram language (https://d2lang.com). It compiles D2 source code to SVG diagrams, with WASM compilation support for browser execution.

## Build Commands

```bash
moon check          # Type check
moon test           # Run tests
moon test --update  # Update snapshots when behavior changes
moon fmt            # Format code
moon build          # Build project
moon build --target wasm  # Build WASM target
moon info && moon fmt     # Update interface files and format (run before committing)
```

## Testing

- Use `inspect` for snapshot testing, then run `moon test --update` to update snapshots
- Only use `assert_eq` in loops where snapshots may vary
- Check coverage with `moon coverage analyze > uncovered.log`

## MoonBit Conventions

- Code is organized in blocks separated by `///|` - blocks can be processed independently
- Use `let mut` only for variables that will be reassigned; collections like arrays don't need `mut`
- Keep deprecated code in `deprecated.mbt` files
- Each package has a `moon.pkg.json` listing dependencies
- Test files: `*_test.mbt` (blackbox), `*_wbtest.mbt` (whitebox)
- `.mbti` files are generated interfaces - check diffs to verify API changes

## Architecture

The compilation pipeline follows:
```
D2 Source → Lexer → Parser → AST → IR → Graph → Layout → Exporter → SVG Renderer → SVG
```

Key modules (planned):
- `lexer/` - Tokenization
- `ast/` - AST node definitions
- `parser/` - Recursive descent parser
- `ir/` - Intermediate representation, variable substitution, imports
- `compiler/` - IR to Graph compilation, semantic validation
- `graph/` - Graph, Object, Edge data structures
- `layout/` - Dagre, Grid, Sequence diagram layouts
- `svg/` - SVG rendering, shape paths, arrows
- `themes/` - 25+ built-in themes

## D2 Language Reference

See `PRD.md` for full specification. Key syntax:
- Nodes: `server`, `server: Web Server`
- Edges: `x -> y`, `x <- y`, `x <-> y`, `a -> b -> c`
- Containers: `aws: { server; database }`
- Shapes: `database.shape: cylinder`
- Styles: `server.style.fill: "#f0f0f0"`

Reference implementation: `../d2/` (Go source)
