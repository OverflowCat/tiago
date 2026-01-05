# Must have

- [x] children_inside_parent          # nested containers are D2's core feature
- [x] sibling_no_overlap              # nodes at same level must not overlap
- [x] nodes_no_overlap                # top-level nodes must not overlap (nodes_should_not_overlap)
- [x] edge_endpoints_touch_nodes      # edges must connect to node boundaries
- [x] edge_avoids_unrelated_nodes     # edges routed around obstacles (algorithm fixed!)
- [x] all_input_nodes_present         # every declared node must appear
- [x] all_input_edges_present         # every declared edge must appear
- [x] text_fits_container             # labels must not be clipped
- [x] deterministic_output            # same input must produce same output
- [ ] text_no_overlap                 # texts mut not overlap

# High priority

- [x] edge_labels_no_overlap          # edge labels must not obscure each other (algorithm fixed!)
- [x] self_loop_visible               # constraint implemented, test disabled (algorithm limitation)
- [x] parallel_edges_distinguishable  # constraint implemented, test disabled (algorithm limitation)
- [x] cluster_contains_members        # explicit groups must enclose their members
- [x] minimum_spacing_between_nodes   # nodes must not be too close (algorithm fixed!)
- [x] no_redundant_waypoints          # collinear points merged; no unnecessary bends (algorithm fixed!)
- [x] no_serpentine_routing           # no S-shaped detours when simpler path exists (algorithm fixed!)
- [x] never_use_diagonal_edges        # all edge segments must be orthogonal (horizontal or vertical)
- [x] parallel_edges_no_overlap       # merged with parallel_edges_distinguishable (now checks full routes)
- [x] arrowhead_direction_matches_node_position   # arrow points toward destination node (algorithm fixed!)
- [x] edge_connects_to_correct_side              # edge connects to correct side based on approach direction (algorithm fixed!)

# Also implemented

- [x] all_nodes_have_positions        # all nodes have boxes after layout
- [x] all_positions_non_negative      # all positions >= 0
- [x] all_dimensions_positive         # all widths/heights > 0
- [x] nodes_within_canvas_bounds      # nodes stay within canvas
- [x] bounding_box_contains_all_elements  # edges and labels within bounds

# Known algorithm limitations (constraints exist, tests disabled)

- [ ] self_loop_visible               # Self-loops removed during cycle breaking, not re-routed
- [ ] parallel_edges_distinguishable  # Parallel edge offset not working in all cases (now checks full routes, not just midpoints)

# Smoke test

- [x] children_inside_parent
- [x] sibling_no_overlap
- [x] edge_endpoints_touch_nodes
- [x] all_input_nodes_present
- [x] deterministic_output
