///|
test "grid new creates empty grid" {
  let grid = Grid::new(5, 3)
  assert_eq(grid.get_width(), 5)
  assert_eq(grid.get_height(), 3)
  assert_eq(grid.get(0, 0), ' ')
}

///|
test "grid set and get" {
  let grid = Grid::new(10, 10)
  grid.set(5, 5, 'X')
  assert_eq(grid.get(5, 5), 'X')
  assert_eq(grid.get(0, 0), ' ')
}

///|
test "grid text" {
  let grid = Grid::new(20, 3)
  grid.text(2, 1, "Hello")
  assert_eq(grid.get(2, 1), 'H')
  assert_eq(grid.get(3, 1), 'e')
  assert_eq(grid.get(6, 1), 'o')
}

///|
test "grid hline" {
  let grid = Grid::new(10, 5)
  grid.hline(2, 7, 2, '-')
  assert_eq(grid.get(2, 2), '-')
  assert_eq(grid.get(4, 2), '-')
  assert_eq(grid.get(7, 2), '-')
  assert_eq(grid.get(1, 2), ' ')
}

///|
test "grid vline" {
  let grid = Grid::new(10, 10)
  grid.vline(3, 1, 5, '|')
  assert_eq(grid.get(3, 1), '|')
  assert_eq(grid.get(3, 3), '|')
  assert_eq(grid.get(3, 5), '|')
  assert_eq(grid.get(3, 0), ' ')
}

///|
test "grid rect" {
  let grid = Grid::new(10, 6)
  grid.rect(1, 1, 8, 4, '+', '-', '|')
  // Corners
  assert_eq(grid.get(1, 1), '+')
  assert_eq(grid.get(8, 1), '+')
  assert_eq(grid.get(1, 4), '+')
  assert_eq(grid.get(8, 4), '+')
  // Edges
  assert_eq(grid.get(4, 1), '-')
  assert_eq(grid.get(1, 2), '|')
}

///|
test "grid to_string" {
  let grid = Grid::new(5, 3)
  grid.rect(0, 0, 4, 2, '+', '-', '|')
  inspect(
    grid.to_string(),
    content=(
      #|+---+
      #||   |
      #|+---+
      #|
    ),
  )
}

///|
test "grid line vertical" {
  let grid = Grid::new(5, 5)
  grid.line(2, 0, 2, 4, '-', '|', '\\', '/')
  assert_eq(grid.get(2, 0), '|')
  assert_eq(grid.get(2, 2), '|')
  assert_eq(grid.get(2, 4), '|')
}

///|
test "grid line horizontal" {
  let grid = Grid::new(10, 3)
  grid.line(1, 1, 8, 1, '-', '|', '\\', '/')
  assert_eq(grid.get(1, 1), '-')
  assert_eq(grid.get(4, 1), '-')
  assert_eq(grid.get(8, 1), '-')
}

///|
test "grid fill" {
  let grid = Grid::new(6, 4)
  grid.fill(1, 1, 4, 2, '#')
  assert_eq(grid.get(1, 1), '#')
  assert_eq(grid.get(4, 2), '#')
  assert_eq(grid.get(0, 0), ' ')
}

///|
test "box drawing" {
  let grid = Grid::new(20, 5)
  grid.rect(0, 0, 10, 4, '+', '-', '|')
  grid.text(2, 2, "Server")
  inspect(
    grid.to_string(),
    content=(
      #|+---------+
      #||         |
      #|| Server  |
      #||         |
      #|+---------+
      #|
    ),
  )
}
