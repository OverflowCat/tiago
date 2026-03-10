// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Class definition tests

///|
test "class applies shape" {
  let source =
    #|classes: {
    #|  user: {
    #|    shape: person
    #|  }
    #|}
    #|alice: Alice { class: user }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("Alice"))
}

///|
test "class applies style" {
  let source =
    #|classes: {
    #|  styled: {
    #|    style: {
    #|      fill: "#ff0000"
    #|    }
    #|  }
    #|}
    #|box: Box { class: styled }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("fill=\"#ff0000\""))
}

///|
test "multiple classes" {
  let source =
    #|classes: {
    #|  user: {
    #|    shape: person
    #|  }
    #|  server: {
    #|    shape: rectangle
    #|  }
    #|}
    #|alice: Alice { class: user }
    #|web: Web Server { class: server }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("Alice"))
  assert_true(svg.contains("Web Server"))
}

///|
test "class applies cylinder shape" {
  let source =
    #|classes: {
    #|  db: {
    #|    shape: cylinder
    #|  }
    #|}
    #|postgres: PostgreSQL { class: db }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("PostgreSQL"))
}

///|
test "class applies multiple style properties" {
  let source =
    #|classes: {
    #|  styled: {
    #|    style: {
    #|      fill: "#e3f2fd"
    #|      stroke: "#1976diago"
    #|      stroke-width: 3
    #|    }
    #|  }
    #|}
    #|box: Box { class: styled }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("fill=\"#e3f2fd\""))
  assert_true(svg.contains("stroke=\"#1976diago\""))
  assert_true(svg.contains("stroke-width:3;"))
}

///|
test "object property overrides class property" {
  let source =
    #|classes: {
    #|  default: {
    #|    shape: circle
    #|    style: {
    #|      fill: "#ff0000"
    #|    }
    #|  }
    #|}
    #|obj: Object {
    #|  class: default
    #|  shape: rectangle
    #|  style: {
    #|    fill: "#00ff00"
    #|  }
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<rect"))
  assert_true(svg.contains("fill=\"#00ff00\""))
}

///|
test "class with hexagon shape" {
  let source =
    #|classes: {
    #|  decision: {
    #|    shape: hexagon
    #|  }
    #|}
    #|choice: Decision Point { class: decision }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("Decision Point"))
}

///|
test "class with diamond shape" {
  let source =
    #|classes: {
    #|  condition: {
    #|    shape: diamond
    #|  }
    #|}
    #|check: Check Condition { class: condition }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("Check Condition"))
}

///|
test "nonexistent class does not crash" {
  let source =
    #|classes: {
    #|  existing: {
    #|    shape: circle
    #|  }
    #|}
    #|obj: Object { class: nonexistent }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<rect"))
  assert_true(svg.contains("Object"))
}

///|
test "class applies to nested objects" {
  let source =
    #|classes: {
    #|  user: {
    #|    shape: person
    #|  }
    #|}
    #|team: {
    #|  alice: Alice { class: user }
    #|  bob: Bob { class: user }
    #|}
  let svg = compile(source).unwrap()
  assert_true(svg.contains("Alice"))
  assert_true(svg.contains("Bob"))
}

///|
test "class with oval shape" {
  let source =
    #|classes: {
    #|  start: {
    #|    shape: oval
    #|  }
    #|}
    #|begin: Start { class: start }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<ellipse"))
  assert_true(svg.contains("Start"))
}

///|
test "class applies border-radius" {
  let source =
    #|classes: {
    #|  rounded: {
    #|    style: {
    #|      border-radius: 10
    #|    }
    #|  }
    #|}
    #|box: Rounded Box { class: rounded }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("rx=\"10.000000\"") || svg.contains("rx=\"10\""))
}

///|
test "class with cloud shape" {
  let source =
    #|classes: {
    #|  service: {
    #|    shape: cloud
    #|  }
    #|}
    #|aws: AWS Cloud { class: service }
  let svg = compile(source).unwrap()
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("AWS Cloud"))
}

///|
test "classes block not rendered as object" {
  let source =
    #|classes: {
    #|  user: {
    #|    shape: person
    #|  }
    #|}
    #|alice: Alice { class: user }
  let svg = compile(source).unwrap()
  assert_true(!svg.contains(">classes<"))
}
