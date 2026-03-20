///|
priv struct ParentDummyNums {
  low : Int
  lim : Int
}

///|
priv struct ParentDummyPath {
  path : Array[String?]
  lca : String?
}

///|
priv struct ParentDummyCounter {
  mut lim : Int
}

///|
let parent_dummy_inf = 1_000_000_000

///|
pub fn parent_dummy_chains(g : Graph) -> Unit {
  let postorder_nums = parent_dummy_postorder(g)
  if g.graph().get_strings("dummyChains") is Some(chains) {
    for chain_start in chains {
      let start_node = g.node(chain_start)
      if start_node.get_edge("edgeObj") is Some(edge_obj) {
        let path_data = parent_dummy_find_path(
          g,
          postorder_nums,
          edge_obj.v,
          edge_obj.w,
        )
        if path_data.path.is_empty() {
          continue
        }
        let mut path_idx = 0
        let mut path_v = path_data.path[path_idx]
        let mut ascending = true
        let mut v = chain_start
        while v != edge_obj.w {
          let node = g.node(v)
          let rank = node.get_int_or("rank", 0)
          if ascending {
            while path_v != path_data.lca &&
                  parent_dummy_max_rank(g, path_v) < rank {
              path_idx = path_idx + 1
              path_v = path_data.path[path_idx]
            }
            if path_v == path_data.lca {
              ascending = false
            }
          }
          if !ascending {
            while path_idx < path_data.path.length() - 1 &&
                  parent_dummy_min_rank(g, path_data.path[path_idx + 1]) <= rank {
              path_idx = path_idx + 1
            }
            path_v = path_data.path[path_idx]
          }
          let parent = path_v
          g.set_parent(v, parent?)
          let successors = g.successors(v)
          if successors.is_empty() {
            break
          }
          v = successors[0]
        }
      }
    }
  }
}

///|
fn parent_dummy_find_path(
  g : Graph,
  postorder_nums : Map[String, ParentDummyNums],
  v : String,
  w : String,
) -> ParentDummyPath {
  let v_nums = postorder_nums.get_or_default(v, { low: 0, lim: 0 })
  let w_nums = postorder_nums.get_or_default(w, { low: 0, lim: 0 })
  let low = parent_dummy_min(v_nums.low, w_nums.low)
  let lim = parent_dummy_max(v_nums.lim, w_nums.lim)
  let v_path : Array[String?] = []
  let w_path : Array[String?] = []
  let mut parent : String? = Some(v)
  let mut lca : String? = None
  while true {
    parent = if parent is Some(parent_node) {
      g.parent(parent_node)
    } else {
      None
    }
    v_path.push(parent)
    if parent is Some(parent_node) {
      if postorder_nums.get(parent_node) is Some(nums) {
        if nums.low > low || lim > nums.lim {
          continue
        }
      }
      lca = parent
      break
    } else {
      lca = None
      break
    }
  }
  parent = Some(w)
  while true {
    parent = if parent is Some(parent_node) {
      g.parent(parent_node)
    } else {
      None
    }
    if parent == lca {
      break
    }
    w_path.push(parent)
  }
  let reversed_w_path : Array[String?] = []
  if !w_path.is_empty() {
    let mut i = w_path.length() - 1
    while true {
      reversed_w_path.push(w_path[i])
      if i == 0 {
        break
      }
      i = i - 1
    }
  }
  let path = v_path + reversed_w_path
  { path, lca }
}

///|
fn parent_dummy_postorder(g : Graph) -> Map[String, ParentDummyNums] {
  let result : Map[String, ParentDummyNums] = Map::new()
  let counter : ParentDummyCounter = { lim: 0 }
  fn dfs(
    g : Graph,
    result : Map[String, ParentDummyNums],
    counter : ParentDummyCounter,
    v : String,
  ) -> Unit {
    let low = counter.lim
    for child in g.children(v~) {
      dfs(g, result, counter, child)
    }
    result.set(v, { low, lim: counter.lim })
    counter.lim = counter.lim + 1
  }

  for root in g.children() {
    dfs(g, result, counter, root)
  }
  result
}

///|
fn parent_dummy_min_rank(g : Graph, node : String?) -> Int {
  if node is Some(node) {
    g.node(node).get_int_or("minRank", parent_dummy_inf)
  } else {
    parent_dummy_inf
  }
}

///|
fn parent_dummy_max_rank(g : Graph, node : String?) -> Int {
  if node is Some(node) {
    g.node(node).get_int_or("maxRank", parent_dummy_inf)
  } else {
    parent_dummy_inf
  }
}

///|
fn parent_dummy_min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn parent_dummy_max(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
