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
/// Processor framework (internal).
///
/// This is the foundation for porting ELK layered as a processor pipeline.

///|
priv enum LayeredSlot {
  BeforePhase1
  BeforePhase2
  BeforePhase3
  BeforePhase4
  BeforePhase5
  AfterPhase5
} derive(Eq, Show)

///|
fn LayeredSlot::order(self : LayeredSlot) -> Int {
  match self {
    BeforePhase1 => 10
    BeforePhase2 => 20
    BeforePhase3 => 30
    BeforePhase4 => 40
    BeforePhase5 => 50
    AfterPhase5 => 60
  }
}

///|
priv struct LayeredProcessorContext {
  config : LayoutConfig
  direction : Direction
} derive(Show)

///|
fn always_enabled(_ctx : LayeredProcessorContext) -> Bool {
  true
}

///|
priv struct LayeredProcessor {
  id : String
  slot : LayeredSlot
  insertion_order : Int
  enabled : (LayeredProcessorContext) -> Bool
  run : (Graph, LayeredProcessorContext) -> Unit
}

///|
fn LayeredProcessor::new(
  id : String,
  slot : LayeredSlot,
  insertion_order : Int,
  run : (Graph, LayeredProcessorContext) -> Unit,
) -> LayeredProcessor {
  { id, slot, insertion_order, enabled: always_enabled, run }
}

///|
fn LayeredProcessor::new_when(
  id : String,
  slot : LayeredSlot,
  insertion_order : Int,
  enabled : (LayeredProcessorContext) -> Bool,
  run : (Graph, LayeredProcessorContext) -> Unit,
) -> LayeredProcessor {
  { id, slot, insertion_order, enabled, run }
}

///|
priv struct LayeredPipeline {
  processors : Array[LayeredProcessor]
}

///|
fn LayeredPipeline::run(
  self : LayeredPipeline,
  graph : Graph,
  ctx : LayeredProcessorContext,
) -> Unit {
  for processor in self.processors {
    if (processor.enabled)(ctx) {
      (processor.run)(graph, ctx)
    }
  }
}

///|
priv struct LayeredPipelineBuilder {
  mut next_order : Int
  processors : Array[LayeredProcessor]
}

///|
fn LayeredPipelineBuilder::new() -> LayeredPipelineBuilder {
  { next_order: 0, processors: [] }
}

///|
fn LayeredPipelineBuilder::add(
  self : LayeredPipelineBuilder,
  id : String,
  slot : LayeredSlot,
  run : (Graph, LayeredProcessorContext) -> Unit,
) -> Unit {
  let processor = LayeredProcessor::new(id, slot, self.next_order, run)
  self.next_order += 1
  self.processors.push(processor)
}

///|
fn LayeredPipelineBuilder::add_when(
  self : LayeredPipelineBuilder,
  id : String,
  slot : LayeredSlot,
  enabled : (LayeredProcessorContext) -> Bool,
  run : (Graph, LayeredProcessorContext) -> Unit,
) -> Unit {
  let processor = LayeredProcessor::new_when(
    id,
    slot,
    self.next_order,
    enabled,
    run,
  )
  self.next_order += 1
  self.processors.push(processor)
}

///|
fn LayeredPipelineBuilder::build(
  self : LayeredPipelineBuilder,
) -> LayeredPipeline {
  let processors = self.processors
  processors.sort_by(fn(a, b) {
    let da = a.slot.order() - b.slot.order()
    if da != 0 {
      da
    } else {
      a.insertion_order - b.insertion_order
    }
  })
  { processors, }
}
