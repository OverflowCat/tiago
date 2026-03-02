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
/// Layout results represented as an immutable patch.
///
/// Layout engines compute geometry from an immutable graph and return a patch.
/// The patch can then be applied to the graph to produce a new graph.

///|
pub struct FragmentOperandLayout {
  condition : String?
  separator_y : Double
} derive(Show)

///|
pub fn FragmentOperandLayout::new(
  condition : String?,
  separator_y : Double,
) -> FragmentOperandLayout {
  { condition, separator_y }
}

///|
pub struct SequenceFragmentLayout {
  fragment_type : String
  condition : String?
  bbox : Box?
  start_index : Int
  end_index : Int
  operands : Array[FragmentOperandLayout]
} derive(Show)

///|
pub fn SequenceFragmentLayout::new(
  fragment_type : String,
  condition : String?,
  bbox : Box?,
  start_index : Int,
  end_index : Int,
  operands : Array[FragmentOperandLayout],
) -> SequenceFragmentLayout {
  { fragment_type, condition, bbox, start_index, end_index, operands }
}

///|
pub struct LayoutPatch {
  nodes : Map[String, Box]
  node_labels : Map[String, Box]
  edges : Map[Int, Array[Point]]
  edge_bend_points : Map[Int, Array[Point]]
  edge_curves : Map[Int, Bool]
  edge_labels : Map[Int, Box]
  activation_boxes : Array[(String, Box)]
  sequence_notes : Array[(String, String, Box)]
  sequence_fragments : Array[SequenceFragmentLayout]
} derive(Show)

///|
pub fn LayoutPatch::new() -> LayoutPatch {
  {
    nodes: {},
    node_labels: {},
    edges: {},
    edge_bend_points: {},
    edge_curves: {},
    edge_labels: {},
    activation_boxes: [],
    sequence_notes: [],
    sequence_fragments: [],
  }
}
