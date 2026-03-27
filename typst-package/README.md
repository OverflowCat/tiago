# Tiago

Tiago is a Typst package for rendering diagrams with [Diago](https://github.com/OverflowCat/tiago), a D2-compatible diagram engine implemented in MoonBit.

It can render the same diagram source as:

- SVG
- ASCII text
- Unicode text

## Installation

```typst
#import "@preview/tiago:0.1.0": *
```

## API

### `render(source, engine: none, ..args)`

Renders diagram source to an SVG-backed Typst image. Extra arguments are forwarded to Typst's `image(...)`, so you can pass values like `width`, `height`, or `alt`.

```typst
#render(
  "a -> b: hello",
  // engine: "elk",
  // width: 220pt,
  // height: ...
)
```

### `render-svg(source, engine: none)`

Renders diagram source to raw SVG bytes.

```typst
#let svg = render-svg("a -> b")
```

### `render-ascii(source)`

Renders diagram source to ASCII text.

```typst
#raw(render-ascii("a -> b"))
```

### `render-unicode(source)`

Renders diagram source to Unicode box-drawing text.

```typst
#raw(render-unicode("a -> b"))
```

## Layout Engines

`engine` is optional. When omitted, the package uses Diago's default layout engine.

Supported engine names:

- `dagre`
- `elk`
- `railway`

## Example

```typst
#import "@preview/tiago:0.1.0": *

= Tiago Example

#let source = ```
server: Web Server
database: Database {
  shape: cylinder
}
cache: Cache

server -> database: queries
server -> cache: reads
cache -> database: fallback
```.text

== SVG

#render(
  source,
  engine: "elk",
  width: 300pt,
)

== ASCII

#raw(render-ascii(source))

== Unicode

#raw(render-unicode(source))
```

For a sample document, see `example.typ`.

## License

Apache-2.0. See `LICENSE`.
