#import "lib.typ": *

= Tiago: typst wrapper of Diago

Diago is a MoonBit port of #link("https://d2lang.com/")[D2].

== Source code

#let code = ```
"a -> b: hello, typst"
```

#code

#let source = code.text

== SVG Output

#render(
  source,
  // Optional parameters
  engine: "elk",
  width: 250pt,
  height: 100pt,
)

== ASCII Output

#raw(render-ascii(source))

== Unicode Output

#raw(render-unicode(source))
