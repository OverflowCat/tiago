# Layout Comparison: D2 Reference vs diago

This document compares the layout implementations between the D2 reference (Go) and diago (MoonBit).

---

## Executive Summary

| Aspect | D2 Reference | diago | Impact |
|--------|-------------|-------|--------|
| **Core Algorithm** | Sugiyama via Dagre.js | Sugiyama native | Similar approach |
| **Edge Routing** | Sophisticated polyline + Bezier smoothing | Simple direct lines | **Major visual issue** |
| **Label Positioning** | 25 discrete positions with collision avoidance | Basic midpoint only | **Labels overlap** |
| **Container Layout** | Extract → Layout → Reinject recursively | Basic nested positioning | **Container edges wrong** |
| **Crossing Minimization** | 4 alignment passes + barycenter | Barycenter only | Minor quality difference |
| **Post-Processing** | S-shape elimination, edge endpoint extension | None | **Edges look messy** |

---

## Phase-by-Phase Comparison

### Phase 0: Cycle Breaking

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| DFS-based feedback arc set | ✅ | ✅ | Equivalent |
| Back-edge detection | ✅ | ✅ | Equivalent |
| Edge reversal marking | ✅ | ✅ | Equivalent |

**Verdict**: ✅ Equivalent implementation

---

### Phase 1: Layer Assignment

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| Longest path initial assignment | ✅ | ✅ | Equivalent |
| Network simplex optimization | ✅ | ✅ | Equivalent |
| Feasible tree construction | ✅ | ✅ | Equivalent |
| Cut value computation | ✅ | ✅ | Equivalent |
| Pivot operations | ✅ | ✅ | Equivalent |

**Verdict**: ✅ Equivalent implementation

---

### Phase 1.5: Virtual/Dummy Node Insertion

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| Long edge splitting | ✅ | ✅ | Equivalent |
| Edge label rank insertion | ✅ | ❌ | **Missing** |
| Container border nodes | ✅ | ❌ | **Missing** |

**Issues in diago**:
- Edge labels are not treated as nodes requiring space in the rank
- Container subgraph border nodes not created

---

### Phase 2: Ordering (Crossing Minimization)

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| Barycenter heuristic | ✅ | ✅ | Equivalent |
| Median heuristic option | ✅ | ❌ | Missing |
| Up/down sweeps | ✅ | ✅ | Equivalent |
| Iteration count | Configurable | Fixed 24 | Minor |
| Original order tie-breaker | ✅ | ✅ | Equivalent |

**Verdict**: ⚠️ Mostly equivalent, missing median option

---

### Phase 3: Coordinate Assignment (X-Position)

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| Brandes-Köpf algorithm | ✅ | ✅ | Equivalent |
| 4-directional alignment | ✅ | ✅ | Equivalent |
| Horizontal compaction | ✅ | ✅ | Equivalent |
| Median of 4 alignments | ✅ | ✅ | Equivalent |
| Conflict resolution | ✅ | ⚠️ | Simplified |

**Issues in diago**:
- Conflict resolution between blocks may be simplified

---

### Phase 4: Y-Coordinate Assignment

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| Rank-based stacking | ✅ | ✅ | Equivalent |
| Dynamic rank spacing for labels | ✅ | ❌ | **Missing** |
| Container padding adjustment | ✅ | ⚠️ | Basic only |

**Issues in diago**:
- Row separation does NOT increase when edge labels exceed rankSep
- This causes labels to overlap with nodes in adjacent layers

---

### Phase 5: Container/Nested Layout

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| Recursive BFS discovery | ✅ | ⚠️ | Simplified |
| Extract → Layout → Reinject | ✅ | ❌ | **Missing** |
| Cross-boundary edge classification | ✅ | ❌ | **Missing** |
| Size propagation | ✅ | ⚠️ | Basic |
| Grid cell containers | ✅ | ⚠️ | Basic |

**Major Issues in diago**:
1. No extraction/reinjection pattern - containers laid out in-place
2. Cross-boundary edges not classified or routed separately
3. Edges to nested objects not properly "chopped" at container border

---

### Phase 6: Edge Routing

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| Polyline through virtual nodes | ✅ | ✅ | Equivalent |
| Cubic Bezier smoothing | ✅ | ❌ | **Missing** |
| Short segment extension | ✅ | ❌ | **Missing** |
| S-shape elimination | ✅ | ❌ | **Missing** |
| Ladder elimination | ✅ | ❌ | **Missing** |
| Edge endpoint extension for arrows | ✅ | ❌ | **Missing** |
| Trace to shape border | ✅ | ⚠️ | Basic box only |
| 3D/modifier adjustment | ✅ | ❌ | **Missing** |

**Major Issues in diago**:
1. **No curve smoothing** - edges are jagged polylines
2. **No S-shape/ladder elimination** - unnecessary bends remain
3. **No endpoint adjustment** - arrows may not align properly
4. Edges only intersect basic box, not actual shape borders

---

### Phase 7: Edge Label Positioning

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| 25 discrete positions | ✅ | ❌ | **Missing** |
| Outside/inside/border options | ✅ | ❌ | **Missing** |
| Collision detection | ✅ | ⚠️ | Basic |
| Icon + label positioning | ✅ | ❌ | **Missing** |
| Edge label at 1/4, 1/2, 3/4 points | ✅ | ❌ | Only 1/2 |

**Major Issues in diago**:
1. Labels always at edge midpoint - no positioning options
2. No outside/inside/border label modes
3. Limited collision avoidance (only 5 perpendicular offsets)

---

### Phase 8: Post-Processing Adjustments

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| adjustRankSpacing() | ✅ | ❌ | **Missing** |
| adjustCrossRankSpacing() | ✅ | ❌ | **Missing** |
| fitContainerPadding() | ✅ | ❌ | **Missing** |

**Impact**: Containers may not have proper padding, ranks may be too close

---

## Special Layout Types

### Grid Layout

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| 2D bin packing | ✅ | ⚠️ | Simpler |
| Debt mechanism heuristic | ✅ | ❌ | **Missing** |
| Bounded exhaustive search | ✅ | ❌ | **Missing** |
| Aspect ratio constraints | ✅ | ❌ | **Missing** |
| Cell spanning | ✅ | ✅ | Equivalent |

**Issues in diago**:
- Grid layout uses simple row-by-row allocation
- No optimization for aspect ratio or visual balance

---

### Sequence Diagram Layout

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| Actor spacing computation | ✅ | ⚠️ | Fixed spacing |
| Label width distribution | ✅ | ❌ | **Missing** |
| Message routing | ✅ | ✅ | Equivalent |
| Activation boxes | ✅ | ✅ | Equivalent |
| Notes positioning | ✅ | ✅ | Equivalent |
| Group/fragment layout | ✅ | ✅ | Equivalent |
| Lifeline drawing | ✅ | ⚠️ | Basic |

**Issues in diago**:
- Actor spacing is fixed, not computed based on message label widths
- May cause label overlap in dense diagrams

---

## Geometric Computations

| Feature | D2 | diago | Status |
|---------|----|----|--------|
| Line-line intersection | ✅ | ✅ | Equivalent |
| Box-line intersection | ✅ | ✅ | Equivalent |
| Ellipse-line intersection | ✅ | ❌ | **Missing** |
| Bezier-line intersection | ✅ | ❌ | **Missing** |
| Polygon-line intersection | ✅ | ⚠️ | Basic |

**Impact**: Edges don't properly connect to non-rectangular shapes

---

## Configuration Differences

| Parameter | D2 Default | diago Default | Notes |
|-----------|-----------|---------------|-------|
| ranksep | 60-100 | 40 | diago uses smaller spacing |
| nodesep | 60 | 60 | Same |
| edgesep | 20 | 10 | diago uses smaller edge padding |
| container_padding | Varies | 20 | Fixed in diago |

---

## Priority Fixes for diago

### Critical (Major Visual Impact)

1. **Edge Curve Smoothing**
   - Add cubic Bezier interpolation to edge routes
   - Remove sharp corners between segments

2. **Dynamic Rank Spacing**
   - Increase layer separation when edge labels are tall
   - Prevents labels overlapping nodes

3. **Container Edge Routing**
   - Implement extract/reinject pattern for nested graphs
   - Route cross-boundary edges separately
   - "Chop" edges at container borders

4. **S-Shape/Ladder Elimination**
   - Post-process edge routes to remove unnecessary bends
   - Count edge crossings to decide if removal improves layout

### High Priority

5. **Edge Endpoint Extension**
   - Extend edge endpoints past shape border for arrow visibility
   - Trace to actual shape border, not just bounding box

6. **Label Position Options**
   - Implement 25-position label placement
   - Add outside/inside/border modes

7. **Actor Spacing Computation (Sequence)**
   - Compute actor spacing based on message label widths
   - Distribute label width across spanned actor gaps

### Medium Priority

8. **Grid Layout Optimization**
   - Add debt mechanism for row/column assignment
   - Consider aspect ratio constraints

9. **Post-Layout Adjustments**
   - Implement adjustRankSpacing()
   - Implement fitContainerPadding()

10. **Shape-Specific Edge Routing**
    - Add ellipse-line intersection for ovals/circles
    - Add polygon intersection for hexagons/diamonds

---

## Code Size Comparison

| Module | D2 (Go) | diago (MoonBit) | Ratio |
|--------|---------|-----------------|-------|
| Core Layout | ~3,000 LOC | ~1,156 LOC | 2.6x |
| Edge Routing | ~1,500 LOC | ~200 LOC | 7.5x |
| Grid Layout | ~800 LOC | ~150 LOC | 5.3x |
| Sequence Layout | ~600 LOC | ~685 LOC | 0.9x |
| Geometry | ~1,200 LOC | ~300 LOC | 4x |
| **Total** | **~7,100 LOC** | **~2,500 LOC** | **2.8x** |

The D2 implementation is roughly 2.8x larger, primarily due to sophisticated edge routing and post-processing.

---

## Recommendations

### Quick Wins (1-2 hours each)

1. Increase default `vertical_spacing` from 40 to 60
2. Increase default `edge_padding` from 10 to 20
3. Add simple Bezier curve interpolation for edge smoothing

### Medium Effort (4-8 hours each)

4. Implement dynamic rank spacing based on edge label heights
5. Add S-shape elimination post-processing
6. Implement edge endpoint extension for arrows

### Major Effort (1-2 days each)

7. Implement container extract/reinject pattern
8. Add comprehensive label positioning system
9. Add shape-specific edge routing (ellipse, polygon)

---

*Generated: 2025-01-03*
