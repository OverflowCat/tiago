# Layout Comparison: D2 Reference vs diago

This document compares the layout implementations between the D2 reference (Go) and diago (MoonBit).

---

## Executive Summary

| Aspect | D2 Reference | diago | Impact |
|--------|-------------|-------|--------|
| **Core Algorithm** | Sugiyama via Dagre.js | Sugiyama native | Similar approach |
| **Edge Routing** | Sophisticated polyline + Bezier smoothing | Polyline + Catmull-Rom Bezier | ✅ Similar |
| **Label Positioning** | 25 discrete positions with collision avoidance | 5 perpendicular offsets with collision avoidance | Minor difference |
| **Container Layout** | Extract → Layout → Reinject recursively | Basic nested positioning | Container edges basic |
| **Crossing Minimization** | 4 alignment passes + barycenter | 4 alignment passes + barycenter | ✅ Equivalent |
| **Post-Processing** | S-shape elimination, edge endpoint extension | S-shape elimination, edge endpoint extension | ✅ Equivalent |

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
| Cubic Bezier smoothing | ✅ | ✅ | Catmull-Rom to Bezier |
| Short segment extension | ✅ | ⚠️ | Basic |
| S-shape elimination | ✅ | ✅ | Equivalent |
| Ladder elimination | ✅ | ✅ | Equivalent |
| Edge endpoint extension for arrows | ✅ | ✅ | Equivalent |
| Trace to shape border | ✅ | ⚠️ | Basic box only |
| 3D/modifier adjustment | ✅ | ❌ | **Missing** |

**Notes**:
- Bezier smoothing available via `style.curved: true` (straight lines by default)
- S-shape/ladder elimination implemented as post-processing
- Edge endpoints extended for arrow visibility

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
| adjustRankSpacing() | ✅ | ✅ | Dynamic rank spacing |
| adjustCrossRankSpacing() | ✅ | ⚠️ | Basic |
| fitContainerPadding() | ✅ | ⚠️ | Fixed padding |

**Notes**: Dynamic rank spacing implemented based on edge label heights

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
| ranksep (vertical_spacing) | 60-100 | 60 | ✅ Same range |
| nodesep (horizontal_spacing) | 60 | 60 | ✅ Same |
| edgesep (edge_padding) | 20 | 20 | ✅ Same |
| container_padding | Varies | 20 | Fixed in diago |

---

## Priority Fixes for diago

### ✅ Completed

1. **Edge Curve Smoothing** ✅
   - Catmull-Rom to Bezier interpolation implemented
   - Available via `style.curved: true`

2. **Dynamic Rank Spacing** ✅
   - Layer separation increases when edge labels are tall
   - Implemented in `compute_dynamic_rank_spacing()`

3. **S-Shape/Ladder Elimination** ✅
   - Post-process edge routes to remove unnecessary bends
   - Checks for object intersections before removing waypoints

4. **Edge Endpoint Extension** ✅
   - Edge endpoints extended past shape border for arrow visibility
   - Implemented in `extend_edge_endpoints()`

5. **Default Spacing Values** ✅
   - vertical_spacing: 60.0 (matches D2)
   - edge_padding: 20.0 (matches D2)

### Remaining High Priority

6. **Container Edge Routing**
   - Implement extract/reinject pattern for nested graphs
   - Route cross-boundary edges separately
   - "Chop" edges at container borders

7. **Label Position Options**
   - Implement 25-position label placement
   - Add outside/inside/border modes

8. **Actor Spacing Computation (Sequence)**
   - Compute actor spacing based on message label widths
   - Distribute label width across spanned actor gaps

### Medium Priority

9. **Grid Layout Optimization**
   - Add debt mechanism for row/column assignment
   - Consider aspect ratio constraints

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

### ✅ Completed

1. ~~Increase default `vertical_spacing` from 40 to 60~~ ✅
2. ~~Increase default `edge_padding` from 10 to 20~~ ✅
3. ~~Add simple Bezier curve interpolation for edge smoothing~~ ✅
4. ~~Implement dynamic rank spacing based on edge label heights~~ ✅
5. ~~Add S-shape elimination post-processing~~ ✅
6. ~~Implement edge endpoint extension for arrows~~ ✅

### Remaining Work

**Medium Effort (4-8 hours each)**
- Implement container extract/reinject pattern
- Add comprehensive label positioning system (25 positions)

**Major Effort (1-2 days each)**
- Add shape-specific edge routing (ellipse, polygon)
- Improve actor spacing computation for sequence diagrams

---

*Updated: 2025-01-04*
