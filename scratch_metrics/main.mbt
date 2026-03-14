///|
fn main {
  let a = @text_metrics.measure_text("Hello Friends", 29, false, true, false).dimensions
  println("Hello Friends => \{a.width.to_int()}, \{a.height.to_int()}")
  let b = @text_metrics.measure_text("Report card", 32, false, true, false).dimensions
  println("Report card => \{b.width.to_int()}, \{b.height.to_int()}")
  let c = @text_metrics.measure_text(
      "Computer science: B", 16, false, false, false,
    ).dimensions
  println("Computer science: B => \{c.width.to_int()}, \{c.height.to_int()}")
  let d = @text_metrics.measure_text(
      "Diagram making: A+", 16, false, false, false,
    ).dimensions
  println("Diagram making: A+ => \{d.width.to_int()}, \{d.height.to_int()}")
  let e = @text_metrics.measure_text_mono_plain(
      "peekn(n int)(s string, eof bool)", 20,
    ).dimensions
  println("peekn mono plain => \{e.width.to_int()}, \{e.height.to_int()}")
  let f = @text_metrics.measure_text("1", 16, false, false, true).dimensions
  println("1 italic => \{f.width.to_int()}, \{f.height.to_int()}")
  let g = @text_metrics.measure_text("*", 16, false, false, true).dimensions
  println("* italic => \{g.width.to_int()}, \{g.height.to_int()}")
}
