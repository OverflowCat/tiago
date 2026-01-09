# D2Lang: Theoretical Challenges and Solutions

This document analyzes the core theoretical challenges in the D2 diagram scripting language and how the project addresses them.

## Table of Contents

1. [Graph Layout Algorithms](#1-graph-layout-algorithms)
2. [Bin Packing in Grid Layout](#2-bin-packing-in-grid-layout)
3. [Edge Routing and Geometric Computations](#3-edge-routing-and-geometric-computations)
4. [Nested Graph Layout](#4-nested-graph-layout)
5. [Sequence Diagram Layout](#5-sequence-diagram-layout)
6. [Text Measurement](#6-text-measurement)
7. [Label Placement](#7-label-placement)
8. [Summary](#8-summary)

---

## 1. Graph Layout Algorithms

### Problem Description

The fundamental challenge in automatic diagram generation is **graph layout** — determining optimal positions for nodes and routing paths for edges. The core sub-problem, **Edge Crossing Minimization**, is proven to be NP-Hard. Given a graph G = (V, E), finding an embedding that minimizes the number of edge crossings is computationally intractable for exact solutions.

For layered/hierarchical graphs (the most common type in D2), the problem involves:

1. **Cycle Breaking**: Removing cycles to create a DAG (Directed Acyclic Graph)
2. **Layer Assignment**: Assigning each vertex to a discrete layer
3. **Crossing Minimization**: Ordering vertices within each layer to minimize edge crossings
4. **Coordinate Assignment**: Computing actual x,y coordinates

### D2's Solution

D2 employs the **Sugiyama Framework** (also known as the layered graph drawing algorithm) through two pluggable layout engines:

#### Dagre Layout Engine (`engine_dagre/`)

In diago, `engine_dagre` is currently a stub (not implemented). The default
layout engine is ELK (`engine_elk`), described below. Dagre is included here as
background on the classic Sugiyama approach used by D2.

```go
// Configuration parameters in layout.go
ConfigurableOpts struct {
    ranksep   int  // Separation between layers
    edgesep   int  // Separation between edges
    nodesep   int  // Separation between nodes
    rankdir   string  // Direction: TB, BT, LR, RL
}
```

Key heuristics:
- **Greedy cycle breaking**: Remove back-edges based on DFS traversal order
- **Network simplex** for layer assignment
- **Barycenter heuristic** for crossing minimization: position each node at the average (barycenter) of its neighbors' positions

#### ELK Layout Engine (`engine_elk/`)

ELK (Eclipse Layout Kernel) provides a more sophisticated implementation:

```go
// ELK configuration in layout.go
elkOpts := map[string]string{
    "elk.layered.cycleBreaking.strategy": "GREEDY_MODEL_ORDER",
    "elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
    "elk.layered.nodePlacement.favorStraightEdges": "true",
    "elk.layered.crossingMinimization.forceNodeModelOrder": "false",
    "elk.layered.nodePlacement.bk.fixedAlignment": "BALANCED",
    "elk.layered.thoroughness": "8",  // Search depth 0-8
}
```

The `thoroughness` parameter controls the trade-off between layout quality and computation time. Higher values explore more permutations during crossing minimization.

### Complexity Analysis

| Phase | Exact Complexity | Heuristic Used |
|-------|-----------------|----------------|
| Cycle Breaking | NP-Hard (FAS problem) | Greedy DFS |
| Layer Assignment | Polynomial | Network Simplex |
| Crossing Minimization | NP-Hard | Barycenter/Median |
| Coordinate Assignment | Polynomial | Brandes-Köpf |

---

## 2. Bin Packing in Grid Layout

### Problem Description

The grid layout (`d2layouts/d2grid/`) faces a variant of the **2D Bin Packing Problem**: given a set of rectangles (diagram objects) with varying dimensions, arrange them into a grid that:

1. Minimizes total bounding box area
2. Maintains aspect ratio close to a target
3. Respects ordering constraints

This is a well-known NP-Hard optimization problem with no polynomial-time exact solution.

### D2's Solution

D2 implements a **two-phase hybrid algorithm**:

#### Phase 1: Fast Heuristic (O(n))

```go
// d2grid/layout.go - fastLayout function
func (gd *gridDiagram) fastLayout(targetSize float64, nCuts int, columns bool) *gridLayout {
    debt := 0.0
    cuts := make([]int, 0, nCuts)

    for i, obj := range gd.objects {
        size := getSize(obj)
        if size > targetSize - debt {
            // Make a cut here
            cuts = append(cuts, i)
            newDebt := size - targetSize
            debt += newDebt
        }
    }
    return buildLayout(cuts)
}
```

The "debt mechanism" tracks cumulative deviation from the target row/column size. When accumulated debt exceeds the threshold, a new row/column is started.

#### Phase 2: Bounded Exhaustive Search

```go
// d2grid/layout.go - iterDivisions function
const ATTEMPT_LIMIT = 100000
const SKIP_LIMIT = 10000

func iterDivisions(objects []*graph.Object, nCuts int,
                   tryFn func([]int) bool, skipFn func([]int) bool) {
    attempts := 0
    skips := 0

    // Generate all C(n, nCuts) combinations
    for combination := range combinations(len(objects), nCuts) {
        if skipFn(combination) {
            skips++
            if skips > SKIP_LIMIT { break }
            continue
        }

        if tryFn(combination) {
            return  // Found acceptable solution
        }

        attempts++
        if attempts > ATTEMPT_LIMIT { break }
    }
}
```

#### Adaptive Threshold

```go
// Dynamic threshold adjustment based on object size variance
okThreshold := STARTING_THRESHOLD
for i := 0; i < thresholdAttempts || bestLayout == nil; i++ {
    iterDivisions(objects, nCuts, tryDivision, rowOk)
    okThreshold += THRESHOLD_STEP_SIZE  // Relax constraints progressively
}
```

### Performance Characteristics

- **Best case**: O(n) when fast heuristic finds acceptable solution
- **Worst case**: O(min(C(n,k), 100000)) where k = number of cuts
- **Space**: O(n) for layout storage

---

## 3. Edge Routing and Geometric Computations

### Problem Description

Edge routing involves computing visually pleasing paths for connections that:
1. Avoid crossing through nodes
2. Minimize unnecessary bends
3. Minimize crossings with other edges
4. Handle curved segments (Bezier curves)

The geometric computations required include:
- Line segment intersection detection
- Bezier curve intersection with lines
- Ellipse intersection with lines
- Distance calculations

### D2's Solution

#### Cubic Bezier Curve Intersection (`lib/geo/bezier.go`)

Finding intersection points between a cubic Bezier curve and a line segment requires solving a cubic polynomial equation:

```go
// Bezier curve: B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
// Line: L(s) = A + s(B-A)

func (b Bezier) Intersections(segment Segment) []*Point {
    // Transform to polynomial form: at³ + bt² + ct + d = 0
    // Use Cardano's formula for cubic roots

    coeffs := computeCoefficients(b, segment)
    roots := cubicRoots(coeffs)

    // Filter roots to valid range [0, 1]
    validRoots := filterValidRoots(roots)
    return computeIntersectionPoints(b, validRoots)
}

func cubicRoots(a, b, c, d float64) []float64 {
    // Cardano's formula
    A := b / a
    B := c / a
    C := d / a

    Q := (3*B - A*A) / 9
    R := (9*A*B - 27*C - 2*A*A*A) / 54
    D := Q*Q*Q + R*R  // Discriminant

    if D >= 0 {
        // One real root + two complex conjugates
        S := cbrt(R + sqrt(D))
        T := cbrt(R - sqrt(D))
        return []float64{S + T - A/3}
    } else {
        // Three real roots (casus irreducibilis)
        theta := acos(R / sqrt(-Q*Q*Q))
        return []float64{
            2*sqrt(-Q)*cos(theta/3) - A/3,
            2*sqrt(-Q)*cos((theta+2*PI)/3) - A/3,
            2*sqrt(-Q)*cos((theta+4*PI)/3) - A/3,
        }
    }
}
```

#### Ellipse Intersection (`lib/geo/ellipse.go`)

```go
// Ellipse: (x-cx)²/a² + (y-cy)²/b² = 1
// Line: y = mx + k (or x = c for vertical lines)

func (e *Ellipse) Intersections(segment Segment) []*Point {
    // Handle vertical line special case
    if segment.Start.X == segment.End.X {
        return e.verticalLineIntersection(segment.Start.X)
    }

    // Substitute line equation into ellipse
    // Results in quadratic: Ax² + Bx + C = 0
    m := (segment.End.Y - segment.Start.Y) / (segment.End.X - segment.Start.X)
    k := segment.Start.Y - m*segment.Start.X

    A := 1/a² + m²/b²
    B := 2*m*(k-cy)/b² - 2*cx/a²
    C := cx²/a² + (k-cy)²/b² - 1

    discriminant := B*B - 4*A*C
    // Solve and filter to segment bounds
}
```

#### S-Shape and Ladder Elimination (`d2elklayout/layout.go`)

ELK sometimes produces suboptimal edge routing with unnecessary bends. D2 implements post-processing optimization:

```go
func deleteBends(g *graph.Graph, edges []*graph.Edge) {
    for _, edge := range edges {
        route := edge.Route

        for i := 0; i < len(route)-2; i++ {
            // Check if points i, i+1, i+2 form an S-shape
            if isSShape(route[i], route[i+1], route[i+2]) {
                // Compute metrics with and without middle point
                currentCrossings := countEdgeIntersects(g, edge, currentSegments)
                proposedCrossings := countEdgeIntersects(g, edge, proposedSegments)

                if proposedCrossings < currentCrossings {
                    // Remove the middle point
                    route = append(route[:i+1], route[i+2:]...)
                }
            }
        }
    }
}

func countEdgeIntersects(g *graph.Graph, edge *graph.Edge,
                         segment geo.Segment) (crossings, overlaps, closeOverlaps, touching int) {
    for _, otherEdge := range g.Edges {
        if otherEdge == edge { continue }

        for _, otherSegment := range otherEdge.Route.Segments() {
            intersection := segment.Intersect(otherSegment)
            if intersection != nil {
                crossings++
            }

            // Check for parallel overlaps
            if segment.IsParallel(otherSegment) {
                dist := segment.DistanceTo(otherSegment)
                if dist < edgeNodeSpacing/4 {
                    closeOverlaps++
                }
                if dist < 1 {
                    touching++
                }
            }
        }
    }
    return
}
```

---

## 4. Nested Graph Layout

### Problem Description

D2 supports **containers** — objects that contain other objects, creating hierarchical graph structures. This introduces complexity:

1. **Recursive layout**: Each container's contents must be laid out independently
2. **Size propagation**: Container sizes depend on their contents' layout
3. **Cross-boundary edges**: Edges connecting objects in different containers

The challenge is maintaining consistent coordinates while handling arbitrary nesting depth.

### D2's Solution

D2 implements a **recursive extraction and reinjection** strategy:

```go
// d2layouts/d2layouts.go - LayoutNested function

func LayoutNested(ctx context.Context, g *graph.Graph,
                  graphInfo GraphInfo, coreLayout graph.LayoutGraph,
                  edgeRouter graph.RouteEdges) error {

    // Phase 1: BFS to identify all nested containers
    containers := findContainers(g)

    // Phase 2: Process containers from deepest to shallowest
    sortByDepth(containers)  // Deepest first

    for _, container := range containers {
        // Extract subgraph
        subgraph := ExtractSubgraph(g, container, includeSelf)

        // Recursive layout
        err := LayoutNested(ctx, subgraph, graphInfo, coreLayout, edgeRouter)
        if err != nil { return err }

        // Reinject with coordinate transformation
        ReinjestSubgraph(g, container, subgraph)
    }

    // Phase 3: Layout the top-level graph
    return coreLayout(ctx, g)
}
```

#### Edge Classification

```go
func classifyEdges(g *graph.Graph, container *graph.Object) (
    internal, external, crossing []*graph.Edge) {

    for _, edge := range g.Edges {
        srcInside := isDescendant(edge.Src, container)
        dstInside := isDescendant(edge.Dst, container)

        switch {
        case srcInside && dstInside:
            internal = append(internal, edge)
        case !srcInside && !dstInside:
            external = append(external, edge)
        default:
            // One end inside, one outside
            crossing = append(crossing, edge)
        }
    }
    return
}
```

#### Coordinate Transformation

After laying out a nested graph, coordinates must be transformed to the parent's coordinate system:

```go
func ReinjestSubgraph(parent *graph.Graph, container *graph.Object,
                      child *graph.Graph) {
    // Compute offset based on container position
    offsetX := container.TopLeft.X + container.Padding
    offsetY := container.TopLeft.Y + container.Padding

    // Transform all object positions
    for _, obj := range child.Objects {
        obj.TopLeft.X += offsetX
        obj.TopLeft.Y += offsetY
    }

    // Transform edge routes
    for _, edge := range child.Edges {
        for _, point := range edge.Route {
            point.X += offsetX
            point.Y += offsetY
        }
    }
}
```

### Complexity Analysis

- **Time**: O(n × L) where n = total objects, L = layout algorithm complexity
- **Space**: O(d × n) where d = maximum nesting depth
- **Worst case**: Exponential in nesting depth if containers have many cross-boundary edges

---

## 5. Sequence Diagram Layout

### Problem Description

Sequence diagrams have unique layout constraints:

1. **Actors** (participants) must be arranged horizontally
2. **Messages** must maintain temporal ordering (vertical)
3. **Activation boxes** (spans) show object lifetimes
4. **Groups** can nest and must contain their children

The challenge is computing optimal horizontal spacing when message labels vary in width.

### D2's Solution (`d2layouts/d2sequence/`)

```go
// sequence_diagram.go

type sequenceDiagram struct {
    actors      []*graph.Object
    messages    []*graph.Edge
    spans       []*graph.Object
    groups      []*graph.Object
    objectRank  map[*graph.Object]int  // Horizontal position index
}

func (sd *sequenceDiagram) layout() error {
    sd.computeActorSpacing()    // 1. Determine horizontal gaps
    sd.placeActors()            // 2. Position actors
    sd.placeNotes()             // 3. Position note boxes
    sd.routeMessages()          // 4. Route message arrows
    sd.placeSpans()             // 5. Position activation boxes
    sd.adjustRouteEndpoints()   // 6. Fine-tune arrow endpoints
    sd.placeGroups()            // 7. Position group containers
    sd.addLifelineEdges()       // 8. Draw vertical lifelines
    return nil
}
```

#### Label Width Distribution

When a message spans multiple actors, its label width is distributed across the gaps:

```go
func (sd *sequenceDiagram) computeActorSpacing() {
    actorXStep := make([]float64, len(sd.actors)-1)

    // Initialize with minimum spacing
    for i := range actorXStep {
        actorXStep[i] = MIN_ACTOR_SPACING
    }

    // Distribute label widths
    for _, msg := range sd.messages {
        srcRank := sd.objectRank[msg.Src]
        dstRank := sd.objectRank[msg.Dst]
        rankDiff := math.Abs(float64(dstRank - srcRank))

        if rankDiff == 0 {
            // Self-message: add extra space
            continue
        }

        // Distribute label width across spanned gaps
        distributedWidth := float64(msg.LabelDimensions.Width) / rankDiff

        minRank := min(srcRank, dstRank)
        maxRank := max(srcRank, dstRank)
        for i := minRank; i < maxRank; i++ {
            actorXStep[i] = math.Max(actorXStep[i], distributedWidth + LABEL_PADDING)
        }
    }
}
```

#### Nested Group Handling

Groups are processed from deepest to shallowest to ensure proper containment:

```go
func (sd *sequenceDiagram) placeGroups() {
    // Sort by nesting level (deepest first)
    sort.SliceStable(sd.groups, func(i, j int) bool {
        return sd.groups[i].Level() > sd.groups[j].Level()
    })

    for _, group := range sd.groups {
        // Compute bounding box of all children
        bbox := computeChildrenBBox(group)

        // Add padding
        group.TopLeft = Point{
            X: bbox.TopLeft.X - GROUP_PADDING,
            Y: bbox.TopLeft.Y - GROUP_PADDING,
        }
        group.Width = bbox.Width + 2*GROUP_PADDING
        group.Height = bbox.Height + 2*GROUP_PADDING
    }
}
```

---

## 6. Text Measurement

### Problem Description

Accurate text measurement is critical for:
1. Computing node sizes to fit labels
2. Determining edge label positions
3. Ensuring consistent rendering across platforms

Challenges include:
- Font metrics vary between typefaces
- Unicode characters have different widths
- Text rendering differs between browsers/systems

### D2's Solution (`lib/textmeasure/`)

```go
// textmeasure.go

type Ruler struct {
    atlases     map[d2fonts.Font]*atlas      // Glyph width caches
    ttfs        map[d2fonts.Font]*truetype.Font  // Parsed font files
    tabWidths   map[d2fonts.Font]float64     // Tab character widths
    lineHeights map[d2fonts.Font]float64     // Line heights
}

func (r *Ruler) MeasureString(s string, font d2fonts.Font, fontSize float64) (width, height float64) {
    atlas := r.atlases[font]
    scale := fontSize / atlas.unitsPerEm

    var maxWidth float64
    var lines int = 1
    var currentWidth float64

    for _, char := range s {
        switch char {
        case '\n':
            lines++
            maxWidth = math.Max(maxWidth, currentWidth)
            currentWidth = 0
        case '\t':
            currentWidth += r.tabWidths[font] * scale
        default:
            currentWidth += atlas.getGlyphWidth(char) * scale
        }
    }

    maxWidth = math.Max(maxWidth, currentWidth)
    height = float64(lines) * r.lineHeights[font] * scale

    return maxWidth, height
}
```

#### Glyph Atlas (`atlas.go`)

Pre-computed glyph widths for common character ranges:

```go
type atlas struct {
    unitsPerEm float64
    glyphWidths map[rune]float64
}

func buildAtlas(ttf *truetype.Font) *atlas {
    a := &atlas{
        unitsPerEm:  float64(ttf.UnitsPerEm()),
        glyphWidths: make(map[rune]float64),
    }

    // ASCII range (U+0000 to U+007F)
    for r := rune(0x0000); r <= 0x007F; r++ {
        a.glyphWidths[r] = getGlyphWidth(ttf, r)
    }

    // Latin-1 Supplement (U+0080 to U+00FF)
    for r := rune(0x0080); r <= 0x00FF; r++ {
        a.glyphWidths[r] = getGlyphWidth(ttf, r)
    }

    // Geometric Shapes (U+25A0 to U+25FF) - for icons
    for r := rune(0x25A0); r <= 0x25FF; r++ {
        a.glyphWidths[r] = getGlyphWidth(ttf, r)
    }

    return a
}
```

---

## 7. Label Placement

### Problem Description

**Optimal label placement** is NP-Hard. Given a set of features (nodes, edges) and potential label positions, finding a placement that:
1. Avoids overlaps between labels
2. Keeps labels close to their features
3. Avoids crossing edges

...is computationally intractable.

### D2's Solution

D2 uses a **simplified fixed-position strategy** rather than solving the general problem:

```go
// Node labels: centered inside the node
func placeNodeLabel(node *graph.Object) {
    node.LabelPosition = Point{
        X: node.TopLeft.X + node.Width/2 - node.LabelWidth/2,
        Y: node.TopLeft.Y + node.Height/2 - node.LabelHeight/2,
    }
}

// Edge labels: at the midpoint of the edge
func placeEdgeLabel(edge *graph.Edge) {
    midpoint := edge.Route.Midpoint()
    edge.LabelPosition = Point{
        X: midpoint.X - edge.LabelWidth/2,
        Y: midpoint.Y - edge.LabelHeight/2,
    }
}
```

For special cases (sequence diagram messages, connection labels), D2 uses domain-specific heuristics rather than general optimization.

---

## 8. Summary

### Complexity Classification

| Problem | Complexity Class | D2's Approach |
|---------|-----------------|---------------|
| Edge Crossing Minimization | NP-Hard | Sugiyama heuristics (barycenter/median) |
| Bin Packing (Grid Layout) | NP-Hard | Fast heuristic + bounded exhaustive search |
| Label Placement | NP-Hard | Fixed-position strategy |
| Bezier-Line Intersection | O(1) | Cardano's formula (analytical) |
| Ellipse-Line Intersection | O(1) | Quadratic formula (analytical) |
| Nested Graph Layout | O(n × L × d) | Recursive extraction/reinjection |
| Sequence Diagram Layout | O(n log n) | Constraint-based positioning |

### Key Engineering Decisions

1. **Pluggable Layout Engines**: Dagre (fast) vs ELK (higher quality) allows users to choose the trade-off

2. **Bounded Search**: Hard limits on iterations (100k) prevent pathological cases from hanging

3. **Progressive Relaxation**: Threshold values increase iteratively until a solution is found

4. **Post-Processing Optimization**: S-shape and ladder elimination improve results without full re-layout

5. **Caching**: Glyph atlases and memoized computations reduce redundant work

### Trade-offs

| Aspect | D2's Choice | Alternative |
|--------|-------------|-------------|
| Layout Quality vs Speed | Configurable (thoroughness) | Fixed quality |
| Exact vs Approximate | Heuristic approximations | Exact solvers (slow) |
| Generality vs Specialization | Domain-specific (sequence, grid) | General-purpose only |
| Memory vs Computation | Cache glyph metrics | Compute on demand |

### Future Improvement Areas (from TODOs in code)

1. **Iterative S-shape removal**: Current implementation makes single pass
2. **Nested grid optimization**: Growing descendants according to inner grid layout
3. **Span labels**: Currently unsupported in sequence diagrams
4. **Edge routing**: Replace simple straight-line routing with spline-based

---

## References

1. Sugiyama, K., Tagawa, S., & Toda, M. (1981). Methods for visual understanding of hierarchical system structures. IEEE Transactions on Systems, Man, and Cybernetics.

2. Gansner, E. R., Koutsofios, E., North, S. C., & Vo, K. P. (1993). A technique for drawing directed graphs. IEEE Transactions on Software Engineering.

3. Ellson, J., Gansner, E., Koutsofios, L., North, S. C., & Woodhull, G. (2001). Graphviz—open source graph drawing tools. International Symposium on Graph Drawing.

4. Eclipse Layout Kernel (ELK) Documentation: https://www.eclipse.org/elk/

5. Coffman, E. G., Garey, M. R., & Johnson, D. S. (1996). Approximation algorithms for bin packing: A survey. Approximation Algorithms for NP-hard Problems.
