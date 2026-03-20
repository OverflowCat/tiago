# Milky2018/moon_dagre

A MoonBit port of the dagre graph layout engine.

Repository: <https://github.com/moonbit-community/moon_dagre>

## Install

```bash
moon add Milky2018/moon_dagre
```

## Basic Usage

`moon.pkg`:
```json
import {
  "Milky2018/moon_dagre" @dagre,
}
```

`main.mbt`:
```moonbit nocheck
///|
fn main {
  let g = dagre.new_graph(directed=true, multigraph=true, compound=true)
  g.set_node(
    "a",
    label=dagre
      .empty_attrs()
      .tap(n => {
        n.set_float("width", 80.0)
        n.set_float("height", 40.0)
      }),
  )
  g.set_node(
    "b",
    label=dagre
      .empty_attrs()
      .tap(n => {
        n.set_float("width", 80.0)
        n.set_float("height", 40.0)
      }),
  )
  g.set_edge("a", "b", label=dagre.attrs_value(dagre.empty_attrs()))

  dagre.layout(g)

  // Read computed coordinates from node labels:
  // g.node("a").get_float("x"), g.node("a").get_float("y"), ...
}
```

## API

- Entry points:
  - `dagre.new_graph(...)`
  - `dagre.layout(g)`
- Version:
  - `dagre.version()`

For full exported symbols, check `pkg.generated.mbti`.
