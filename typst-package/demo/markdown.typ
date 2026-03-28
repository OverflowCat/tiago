#import "../lib.typ": *
#set page(width: auto, height: auto, margin: 1pt)

#let code = ```
style: {
  fill: Beige
  stroke: DarkBlue
  stroke-width: 8
  double-border: true
  fill-pattern: lines
}

report: |md
  # Report card

  - Computer science: B
  - Diagram making: A+
|
```.text

#render(code)
