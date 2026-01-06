# ELK Port to MoonBit - Implementation Plan

## Overview

Port the Eclipse Layout Kernel (ELK) from Java to MoonBit. The full ELK layered algorithm consists of:

- **51+ intermediate processors**
- **9 layer assignment strategies**
- **16+ crossing minimization classes**
- **Multiple node placement strategies**
- **Multiple edge routing strategies**
- **Extensive graph data structures**

Estimated Java LOC: ~40,000 for layered algorithm alone
Current MoonBit LOC: ~4,874

## Architecture

```
elk/
├── core/                    # Core types and utilities
│   ├── types.mbt           # LGraph, LNode, LEdge, LPort, LLabel
│   ├── properties.mbt      # Property system
│   └── math.mbt            # Math utilities (vectors, geometry)
│
├── layered/                 # Layered (Sugiyama) algorithm
│   ├── phases/
│   │   ├── p1_cycle_breaking/
│   │   │   ├── greedy_cycle_breaker.mbt
│   │   │   ├── dfs_cycle_breaker.mbt
│   │   │   └── interactive_cycle_breaker.mbt
│   │   │
│   │   ├── p2_layering/
│   │   │   ├── longest_path.mbt
│   │   │   ├── network_simplex.mbt      # PRIORITY
│   │   │   ├── coffman_graham.mbt
│   │   │   └── min_width.mbt
│   │   │
│   │   ├── p3_crossing_min/
│   │   │   ├── layer_sweep.mbt
│   │   │   ├── barycenter.mbt
│   │   │   ├── greedy_switch.mbt        # PRIORITY
│   │   │   └── counting/
│   │   │       └── crossing_counter.mbt
│   │   │
│   │   ├── p4_node_placement/
│   │   │   ├── simple.mbt
│   │   │   ├── brandes_koepf.mbt        # PRIORITY
│   │   │   └── network_simplex.mbt
│   │   │
│   │   └── p5_edge_routing/
│   │       ├── orthogonal.mbt           # PRIORITY
│   │       ├── polyline.mbt
│   │       └── splines.mbt
│   │
│   ├── intermediate/        # Intermediate processors
│   │   ├── long_edge_splitter.mbt
│   │   ├── long_edge_joiner.mbt
│   │   ├── reversed_edge_restorer.mbt
│   │   ├── label_dummy.mbt
│   │   ├── self_loop.mbt
│   │   ├── port_side.mbt
│   │   └── ...
│   │
│   └── layered.mbt          # Main coordinator
│
├── force/                   # Force-directed algorithm
├── stress/                  # Stress majorization
├── radial/                  # Radial layout
├── tree/                    # Tree layout (Mr. Tree)
├── box/                     # Box packing
└── disco/                   # Disconnected components
```

## Phase 1: Critical Path (Fix Broken Layout)

### 1.1 Wire Up Existing Layered Module
The `elk/layered/layered.mbt` exists but ISN'T BEING CALLED from `elk/elk.mbt`.

**Fix**: Update `elk/elk.mbt:layout_layered()` to call `@layered.layout()` instead of the inline simplified version.

### 1.2 Network Simplex Layering
Replace the stub in `elk/layered/layered.mbt:network_simplex_layering()`.

Key concepts:
- Build spanning tree
- Calculate initial feasible tree
- Iterate: find leaving edge, find entering edge, exchange
- Assign layers based on tree structure

Reference: `NetworkSimplexLayerer.java`

### 1.3 Greedy Switch Crossing Minimization
Add after barycenter in `layer_sweep_crossing_min()`.

Key concepts:
- For each pair of adjacent nodes in a layer
- Count crossings if swapped vs not swapped
- Swap if it reduces crossings
- Repeat until no improvement

Reference: `org.eclipse.elk.alg.layered.intermediate.greedyswitch/`

### 1.4 Brandes-Koepf Node Placement
Replace the stub in `brandes_koepf_placement()`.

Key concepts:
1. Detect type-1 conflicts (short edges crossing long edges)
2. Build vertical alignment (group connected nodes into blocks)
3. Do 4 passes: (TOP, LEFT), (TOP, RIGHT), (BOTTOM, LEFT), (BOTTOM, RIGHT)
4. Compact blocks horizontally
5. Choose best of 4 layouts

Reference: `BKNodePlacer.java`

## Phase 2: Intermediate Processors

### Critical Processors (Minimum Viable)
1. `LongEdgeSplitter` - Insert dummy nodes for multi-layer edges
2. `LongEdgeJoiner` - Remove dummies and create bend points
3. `ReversedEdgeRestorer` - Restore edges reversed during cycle breaking
4. `PortSideProcessor` - Assign ports to sides (N/S/E/W)
5. `LabelDummyInserter/Remover` - Handle edge labels

### Secondary Processors
6. `SelfLoopPreProcessor/PostProcessor` - Handle self-loops
7. `NorthSouthPortPreprocessor/Postprocessor` - Handle N/S ports
8. `InLayerConstraintProcessor` - Handle in-layer ordering
9. `CommentPreprocessor/Postprocessor` - Handle comment nodes
10. `HierarchicalPortConstraintProcessor` - Handle compound graphs

## Phase 3: Enhanced Algorithms

### Layer Assignment
- [ ] Coffman-Graham layering (width-bounded)
- [ ] MinWidth layering
- [ ] Interactive layering (preserve user positions)

### Crossing Minimization
- [ ] Median heuristic (alternative to barycenter)
- [ ] Hierarchical greedy switch
- [ ] Sifting

### Node Placement
- [ ] Network simplex compaction
- [ ] Linear segments

### Edge Routing
- [ ] Spline routing
- [ ] Polyline routing
- [ ] Self-loop routing
- [ ] Hyperedge routing

## Phase 4: Other Algorithms

- [ ] Force-directed (Fruchterman-Reingold) - basic exists
- [ ] Stress majorization - basic exists
- [ ] Radial layout - basic exists
- [ ] Mr. Tree - basic exists
- [ ] Box packing - basic exists
- [ ] Rectangle packing - basic exists
- [ ] DisCo (disconnected components) - basic exists

## Implementation Priority

### P0: Fix Current Breakage
1. Wire up `elk/layered/layered.mbt` in `elk/elk.mbt`
2. Ensure dummy node handling works correctly

### P1: Core Algorithm Quality
1. Network Simplex layering
2. Greedy Switch crossing minimization
3. Brandes-Koepf node placement
4. Proper orthogonal edge routing with obstacle avoidance

### P2: Edge Cases
1. Self-loop handling
2. Port-aware routing
3. Label placement
4. Hierarchical/compound graphs

### P3: Polish
1. Interactive modes
2. Additional algorithms
3. Performance optimization

## Testing Strategy

1. Port ELK's test cases where applicable
2. Property-based tests for invariants:
   - No node overlaps
   - Edges connect to correct node sides
   - Edges are orthogonal/perpendicular at boundaries
   - No edge-node crossings
3. Visual regression tests with known-good layouts

## Resources

- ELK Source: https://github.com/eclipse-elk/elk
- ELK Docs: https://www.eclipse.dev/elk/
- ELK.js: https://github.com/kieler/elkjs
- Sugiyama paper: "Methods for Visual Understanding of Hierarchical System Structures" (1981)
- Brandes-Köpf paper: "Fast and Simple Horizontal Coordinate Assignment" (2001)
