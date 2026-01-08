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
/// Container Rank Spacing
///
/// Tracks which ranks each container spans and adjusts spacing
/// to ensure children have proper internal padding within containers.

///|
/// Track which ranks each container spans
pub(all) struct ContainerRanks {
  /// First rank containing a child
  starting_rank : Map[String, Int]
  /// Last rank containing a child
  ending_rank : Map[String, Int]
}

///|
/// Compute which ranks each container spans based on child positions
pub fn compute_container_ranks(
  graph : @graph.Graph,
  layers : Array[Array[String]],
) -> ContainerRanks {
  // Build rank map for all nodes
  let node_ranks : Map[String, Int] = {}
  for i, layer in layers {
    for node in layer {
      node_ranks[node] = i
    }
  }
  let starting : Map[String, Int] = {}
  let ending : Map[String, Int] = {}
  // Process each container object
  for obj in graph.objects {
    if obj.children.length() == 0 {
      continue
    }
    // Find min/max ranks of children (recursively)
    let (min_rank, max_rank) = find_child_rank_range(obj, node_ranks)
    if min_rank <= max_rank {
      starting[obj.id] = min_rank
      ending[obj.id] = max_rank
    }
  }
  { starting_rank: starting, ending_rank: ending }
}

///|
/// Find the rank range spanned by a container's children
fn find_child_rank_range(
  container : @graph.Object,
  node_ranks : Map[String, Int],
) -> (Int, Int) {
  let mut min_rank = 1000000
  let mut max_rank = -1
  for child in container.children {
    // Check child's direct rank
    match node_ranks.get(child.id) {
      Some(rank) => {
        if rank < min_rank {
          min_rank = rank
        }
        if rank > max_rank {
          max_rank = rank
        }
      }
      None => ()
    }
    // Recursively check nested containers
    if child.children.length() > 0 {
      let (child_min, child_max) = find_child_rank_range(child, node_ranks)
      if child_min < min_rank {
        min_rank = child_min
      }
      if child_max > max_rank {
        max_rank = child_max
      }
    }
  }
  (min_rank, max_rank)
}

///|
/// Expand containers to properly fit their children
/// Adjusts container boundaries and shifts content as needed
pub fn expand_containers_to_fit(
  coords : CoordinateResult,
  graph : @graph.Graph,
  layers : Array[Array[String]],
  container_ranks : ContainerRanks,
  padding : Double,
) -> Unit {
  // Process containers from innermost to outermost (by nesting depth)
  let containers = collect_containers_by_depth(graph)
  // Process bottom-up (deepest containers first)
  for container in containers {
    expand_single_container(coords, container, layers, container_ranks, padding)
  }
}

///|
/// Collect containers ordered by nesting depth (deepest first)
fn collect_containers_by_depth(graph : @graph.Graph) -> Array[@graph.Object] {
  let result : Array[@graph.Object] = []
  let depths : Map[String, Int] = {}
  // Calculate depth for each container
  for obj in graph.objects {
    if obj.children.length() > 0 {
      depths[obj.id] = calculate_container_depth(obj)
      result.push(obj)
    }
  }
  // Sort by depth descending (deepest first)
  sort_containers_by_depth(result, depths)
  result
}

///|
/// Calculate nesting depth of a container
fn calculate_container_depth(container : @graph.Object) -> Int {
  let mut max_child_depth = 0
  for child in container.children {
    if child.children.length() > 0 {
      let child_depth = calculate_container_depth(child)
      if child_depth > max_child_depth {
        max_child_depth = child_depth
      }
    }
  }
  max_child_depth + 1
}

///|
/// Sort containers by depth (insertion sort)
fn sort_containers_by_depth(
  containers : Array[@graph.Object],
  depths : Map[String, Int],
) -> Unit {
  let n = containers.length()
  for i = 1; i < n; i = i + 1 {
    let key = containers[i]
    let key_depth = depths.get(key.id).unwrap_or(0)
    let mut j = i - 1
    while j >= 0 {
      let j_depth = depths.get(containers[j].id).unwrap_or(0)
      if j_depth < key_depth {
        containers[j + 1] = containers[j]
        j = j - 1
      } else {
        break
      }
    }
    containers[j + 1] = key
  }
}

///|
/// Expand a single container to fit its children
fn expand_single_container(
  coords : CoordinateResult,
  container : @graph.Object,
  _layers : Array[Array[String]],
  _container_ranks : ContainerRanks,
  padding : Double,
) -> Unit {
  if container.children.length() == 0 {
    return
  }
  // Get container bounds
  let container_x = coords.x_coords.get(container.id).unwrap_or(0.0)
  let container_y = coords.y_coords.get(container.id).unwrap_or(0.0)
  // Compute bounding box of children
  let (min_x, min_y, max_x, max_y) = compute_child_bounds(
    container, coords, padding,
  )
  // Check if children extend beyond container with padding
  let required_left = min_x - padding
  let required_top = min_y - padding
  // Shift children if they're too close to container edge
  if required_left < container_x {
    let shift = container_x - required_left + padding
    shift_container_children_x(container, coords, shift)
  }
  if required_top < container_y {
    let shift = container_y - required_top + padding
    shift_container_children_y(container, coords, shift)
  }
  ignore(max_x)
  ignore(max_y)
}

///|
/// Compute bounding box of a container's children
fn compute_child_bounds(
  container : @graph.Object,
  coords : CoordinateResult,
  padding : Double,
) -> (Double, Double, Double, Double) {
  let mut min_x = 1.0e10
  let mut min_y = 1.0e10
  let mut max_x = -1.0e10
  let mut max_y = -1.0e10
  for child in container.children {
    let x = coords.x_coords.get(child.id).unwrap_or(0.0)
    let y = coords.y_coords.get(child.id).unwrap_or(0.0)
    let width = match child.box {
      Some(b) => b.width
      None => 100.0
    }
    let height = match child.box {
      Some(b) => b.height
      None => 60.0
    }
    if x < min_x {
      min_x = x
    }
    if y < min_y {
      min_y = y
    }
    if x + width > max_x {
      max_x = x + width
    }
    if y + height > max_y {
      max_y = y + height
    }
    // Recursively include nested container children
    if child.children.length() > 0 {
      let (child_min_x, child_min_y, child_max_x, child_max_y) = compute_child_bounds(
        child, coords, padding,
      )
      if child_min_x < min_x {
        min_x = child_min_x
      }
      if child_min_y < min_y {
        min_y = child_min_y
      }
      if child_max_x > max_x {
        max_x = child_max_x
      }
      if child_max_y > max_y {
        max_y = child_max_y
      }
    }
  }
  (min_x, min_y, max_x, max_y)
}

///|
/// Shift all children of a container horizontally
fn shift_container_children_x(
  container : @graph.Object,
  coords : CoordinateResult,
  shift : Double,
) -> Unit {
  for child in container.children {
    let old_x = coords.x_coords.get(child.id).unwrap_or(0.0)
    coords.x_coords[child.id] = old_x + shift
    // Recursively shift nested children
    if child.children.length() > 0 {
      shift_container_children_x(child, coords, shift)
    }
  }
}

///|
/// Shift all children of a container vertically
fn shift_container_children_y(
  container : @graph.Object,
  coords : CoordinateResult,
  shift : Double,
) -> Unit {
  for child in container.children {
    let old_y = coords.y_coords.get(child.id).unwrap_or(0.0)
    coords.y_coords[child.id] = old_y + shift
    // Recursively shift nested children
    if child.children.length() > 0 {
      shift_container_children_y(child, coords, shift)
    }
  }
}
