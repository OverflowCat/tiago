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
test "properties: typed getters" {
  let props = ElkProperties::new()
  props.set("b", Bool(true))
  props.set("i", Int(3))
  props.set("d", Double(1.25))
  props.set("s", String("hi"))
  props.set("e", Enum("Down"))
  props.set("p", Point(ElkPoint::new(1.0, 2.0)))
  props.set("pad", Padding(ElkPadding::uniform(4.0)))
  props.set("arr", Array([Int(1), String("x")]))
  let m : Map[String, PropertyValue] = {}
  m["k"] = Int(1)
  props.set("m", Map(m))
  assert_eq(props.get_bool("b"), Some(true))
  assert_eq(props.get_int("i"), Some(3))
  assert_eq(props.get_double("d"), Some(1.25))
  assert_eq(props.get_string("s"), Some("hi"))
  assert_eq(props.get_string("e"), Some("Down"))
  assert_eq(props.get_enum("e"), Some("Down"))
  assert_eq(props.get_point("p"), Some(ElkPoint::new(1.0, 2.0)))
  assert_eq(props.get_padding("pad"), Some(ElkPadding::uniform(4.0)))
  assert_eq(props.get_array("arr"), Some([Int(1), String("x")]))
  assert_true(props.get_map("m").unwrap().get("k").unwrap() == Int(1))
}

///|
test "properties: default getters" {
  let props = ElkProperties::new()
  assert_eq(props.get_bool_or("missing", true), true)
  assert_eq(props.get_int_or("missing", 7), 7)
  assert_eq(props.get_double_or("missing", 2.0), 2.0)
  assert_eq(props.get_string_or("missing", "fallback"), "fallback")
}
