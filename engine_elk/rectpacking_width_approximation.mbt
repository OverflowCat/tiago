///|
/// Rectpacking (ELK reference) width approximation logic.
///
/// This file ports the elk-reference greedy width approximation (phase 1):
/// - GreedyWidthApproximator
/// - AreaApproximation + its candidate filters and tie-breaking rules
///
/// The approximation both:
/// - assigns (x, y) coordinates to rectangles, and
/// - returns the approximated drawing width/height (excluding padding).

///|
priv enum RpOptimizationGoal {
  AspectRatioDriven
  MaxScaleDriven
  AreaDriven
}

///|
priv enum RpDrawingDataDescriptor {
  CandidatePositionLastPlacedRight
  CandidatePositionLastPlacedBelow
  CandidatePositionWholeDrawingRight
  CandidatePositionWholeDrawingBelow
  WholeDrawing
} derive(Eq)

///|
priv struct RpDrawingData {
  dar : Double
  drawing_width : Double
  drawing_height : Double
  placement_option : RpDrawingDataDescriptor
  next_x : Double
  next_y : Double
}

///|
fn RpDrawingData::new(
  dar : Double,
  drawing_width : Double,
  drawing_height : Double,
  placement_option : RpDrawingDataDescriptor,
  next_x : Double,
  next_y : Double,
) -> RpDrawingData {
  { dar, drawing_width, drawing_height, placement_option, next_x, next_y }
}

///|
fn rp_compute_scale_measure(
  width : Double,
  height : Double,
  dar : Double,
) -> Double {
  // elk-reference DrawingUtil.computeScaleMeasure
  min_double(dar / width, 1.0 / height)
}

///|
fn rp_vertical_order_constraint(
  placed_rect : ElkNode,
  x : Double,
  node_node_spacing : Double,
) -> Bool {
  // elk-reference Calculations.verticalOrderConstraint
  x < placed_rect.x + placed_rect.width + node_node_spacing
}

///|
fn rp_horizontal_order_constraint(
  placed_rect : ElkNode,
  y : Double,
  node_node_spacing : Double,
) -> Bool {
  // elk-reference Calculations.horizontalOrderConstraint
  y < placed_rect.y + placed_rect.height + node_node_spacing
}

///|
fn rp_calculate_y_for_lpr(
  x : Double,
  placed_rects : Array[ElkNode],
  last_placed : ElkNode,
  node_node_spacing : Double,
) -> Double {
  // elk-reference Calculations.calculateYforLPR
  let mut closest_upper_neighbor : ElkNode? = None
  let mut closest_neighbor_bottom_border = 0.0
  for placed_rect in placed_rects {
    let placed_bottom = placed_rect.y + placed_rect.height
    if rp_vertical_order_constraint(placed_rect, x, node_node_spacing) {
      match closest_upper_neighbor {
        None => closest_upper_neighbor = Some(placed_rect)
        Some(_) =>
          if last_placed.y - placed_bottom <
            last_placed.y - closest_neighbor_bottom_border {
            closest_upper_neighbor = Some(placed_rect)
          }
      }
      let neighbor = closest_upper_neighbor.unwrap()
      closest_neighbor_bottom_border = neighbor.y + neighbor.height
    }
  }
  match closest_upper_neighbor {
    None => 0.0
    Some(_) => closest_neighbor_bottom_border + node_node_spacing
  }
}

///|
fn rp_calculate_x_for_lpb(
  y : Double,
  placed_rects : Array[ElkNode],
  last_placed : ElkNode,
  node_node_spacing : Double,
) -> Double {
  // elk-reference Calculations.calculateXforLPB
  let mut closest_left_neighbor : ElkNode? = None
  let mut closest_neighbor_right_border = 0.0
  for placed_rect in placed_rects {
    let placed_right = placed_rect.x + placed_rect.width
    if rp_horizontal_order_constraint(placed_rect, y, node_node_spacing) {
      match closest_left_neighbor {
        None => closest_left_neighbor = Some(placed_rect)
        Some(_) =>
          if last_placed.x - placed_right <
            last_placed.x - closest_neighbor_right_border {
            closest_left_neighbor = Some(placed_rect)
          }
      }
      let neighbor = closest_left_neighbor.unwrap()
      closest_neighbor_right_border = neighbor.x + neighbor.width
    }
  }
  match closest_left_neighbor {
    None => 0.0
    Some(_) => closest_neighbor_right_border + node_node_spacing
  }
}

///|
fn rp_calculate_area_lpr(
  last_placed : ElkNode,
  to_place : ElkNode,
  lpr_opt : RpDrawingData,
) -> Double {
  // elk-reference Calculations.calculateAreaLPR
  let last_bottom = last_placed.y + last_placed.height
  let place_bottom = lpr_opt.next_y + to_place.height
  let max_y = max_double(last_bottom, place_bottom)
  let height = max_y - min_double(last_placed.y, lpr_opt.next_y)
  let width = lpr_opt.next_x + to_place.width - last_placed.x
  width * height
}

///|
fn rp_calculate_area_lpb(
  last_placed : ElkNode,
  to_place : ElkNode,
  lpb_opt : RpDrawingData,
) -> Double {
  // elk-reference Calculations.calculateAreaLPB
  let last_right = last_placed.x + last_placed.width
  let place_right = lpb_opt.next_x + to_place.width
  let max_x = max_double(last_right, place_right)
  let width = max_x - min_double(last_placed.x, lpb_opt.next_x)
  let height = lpb_opt.next_y + to_place.height - last_placed.y
  width * height
}

///|
fn rp_filter_by_scale_measure(
  candidates : Array[RpDrawingData],
  padding : ElkPadding,
) -> Array[RpDrawingData] {
  // elk-reference ScaleMeasureFilter
  let pad_h = padding.left + padding.right
  let pad_v = padding.top + padding.bottom
  let mut max_scale = -@double.infinity
  for opt in candidates {
    max_scale = max_double(
      max_scale,
      rp_compute_scale_measure(
        opt.drawing_width + pad_h,
        opt.drawing_height + pad_v,
        opt.dar,
      ),
    )
  }
  let remaining : Array[RpDrawingData] = []
  for cand in candidates {
    if rp_compute_scale_measure(
        cand.drawing_width + pad_h,
        cand.drawing_height + pad_v,
        cand.dar,
      ) ==
      max_scale {
      remaining.push(cand)
    }
  }
  remaining
}

///|
fn rp_filter_by_area(
  candidates : Array[RpDrawingData],
  padding : ElkPadding,
) -> Array[RpDrawingData] {
  // elk-reference AreaFilter
  let pad_h = padding.left + padding.right
  let pad_v = padding.top + padding.bottom
  let mut min_area = @double.infinity
  for opt in candidates {
    min_area = min_double(
      min_area,
      (opt.drawing_width + pad_h) * (opt.drawing_height + pad_v),
    )
  }
  let remaining : Array[RpDrawingData] = []
  for cand in candidates {
    if (cand.drawing_width + pad_h) * (cand.drawing_height + pad_v) == min_area {
      remaining.push(cand)
    }
  }
  remaining
}

///|
fn rp_filter_by_aspect_ratio(
  candidates : Array[RpDrawingData],
  aspect_ratio : Double,
  padding : ElkPadding,
) -> Array[RpDrawingData] {
  // elk-reference AspectRatioFilter
  let pad_h = padding.left + padding.right
  let pad_v = padding.top + padding.bottom
  let mut smallest_deviation = @double.infinity
  for opt in candidates {
    smallest_deviation = min_double(
      smallest_deviation,
      ((opt.drawing_width + pad_h) / (opt.drawing_height + pad_v) - aspect_ratio).abs(),
    )
  }
  let remaining : Array[RpDrawingData] = []
  for cand in candidates {
    if ((cand.drawing_width + pad_h) / (cand.drawing_height + pad_v) -
      aspect_ratio).abs() ==
      smallest_deviation {
      remaining.push(cand)
    }
  }
  remaining
}

///|
fn rp_check_special_cases(
  drawing1 : RpDrawingData,
  drawing2 : RpDrawingData,
  last_placed : ElkNode,
  to_place : ElkNode,
) -> RpDrawingData {
  // elk-reference AreaApproximation.checkSpecialCases
  let first_opt = drawing1.placement_option
  let second_opt = drawing2.placement_option
  let first_opt_lpb_or_cdb = first_opt == CandidatePositionLastPlacedBelow ||
    first_opt == CandidatePositionWholeDrawingBelow
  let second_opt_lpb_or_cdb = second_opt == CandidatePositionLastPlacedBelow ||
    second_opt == CandidatePositionWholeDrawingBelow
  let first_opt_lpr_or_cdr = first_opt == CandidatePositionLastPlacedRight ||
    first_opt == CandidatePositionWholeDrawingRight
  let second_opt_lpr_or_cdr = second_opt == CandidatePositionLastPlacedRight ||
    second_opt == CandidatePositionWholeDrawingRight
  let first_opt_lpr_or_lpb = first_opt == CandidatePositionLastPlacedRight ||
    first_opt == CandidatePositionLastPlacedBelow
  let second_opt_lpr_or_lpb = second_opt == CandidatePositionLastPlacedRight ||
    second_opt == CandidatePositionLastPlacedBelow
  if first_opt_lpb_or_cdb && second_opt_lpb_or_cdb {
    // If placing it LPB and WDB produces the same values. Take WDB.
    if drawing1.placement_option == CandidatePositionWholeDrawingBelow {
      drawing1
    } else {
      drawing2
    }
  } else if first_opt_lpr_or_cdr && second_opt_lpr_or_cdr {
    // If placing it LPR and WDR produces the same values. Take WDR.
    if drawing1.placement_option == CandidatePositionWholeDrawingRight {
      drawing1
    } else {
      drawing2
    }
  } else if first_opt_lpr_or_lpb && second_opt_lpr_or_lpb {
    // If LPR AND LPB produce the same values. Take the option producing less area with the last placed
    // rectangle and rectangle to place.
    let (lpr_opt, lpb_opt) = if first_opt == CandidatePositionLastPlacedRight {
      (drawing1, drawing2)
    } else {
      (drawing2, drawing1)
    }
    let area_lpr = rp_calculate_area_lpr(last_placed, to_place, lpr_opt)
    let area_lpb = rp_calculate_area_lpb(last_placed, to_place, lpb_opt)
    if area_lpr <= area_lpb {
      if drawing1.placement_option == CandidatePositionLastPlacedRight {
        drawing1
      } else {
        drawing2
      }
    } else if drawing1.placement_option == CandidatePositionLastPlacedBelow {
      drawing1
    } else {
      drawing2
    }
  } else {
    drawing1
  }
}

///|
fn rp_calc_values_for_opt(
  option : RpDrawingDataDescriptor,
  to_place : ElkNode,
  last_placed : ElkNode,
  drawing : RpDrawingData,
  placed_rects : Array[ElkNode],
  node_node_spacing : Double,
  lp_shift : Bool,
  aspect_ratio : Double,
) -> RpDrawingData {
  // elk-reference AreaApproximation.calcValuesForOpt
  let mut x = 0.0
  let mut y = 0.0
  let drawing_width = drawing.drawing_width
  let drawing_height = drawing.drawing_height
  let height_to_place = to_place.height
  let width_to_place = to_place.width
  let (width, height) = match option {
    CandidatePositionLastPlacedRight => {
      x = last_placed.x + last_placed.width + node_node_spacing
      y = if lp_shift {
        rp_calculate_y_for_lpr(x, placed_rects, last_placed, node_node_spacing)
      } else {
        last_placed.y
      }
      (
        max_double(drawing_width, x + width_to_place),
        max_double(drawing_height, y + height_to_place),
      )
    }
    CandidatePositionLastPlacedBelow => {
      y = last_placed.y + last_placed.height + node_node_spacing
      x = if lp_shift {
        rp_calculate_x_for_lpb(y, placed_rects, last_placed, node_node_spacing)
      } else {
        last_placed.x
      }
      (
        max_double(drawing_width, x + width_to_place),
        max_double(drawing_height, y + height_to_place),
      )
    }
    CandidatePositionWholeDrawingRight => {
      x = drawing_width + node_node_spacing
      y = 0.0
      (
        drawing_width + node_node_spacing + width_to_place,
        max_double(drawing_height, height_to_place),
      )
    }
    CandidatePositionWholeDrawingBelow => {
      x = 0.0
      y = drawing_height + node_node_spacing
      (
        max_double(drawing_width, width_to_place),
        drawing_height + node_node_spacing + height_to_place,
      )
    }
    WholeDrawing => (drawing_width, drawing_height)
  }
  RpDrawingData::new(aspect_ratio, width, height, option, x, y)
}

///|
fn rp_find_best_candidate(
  opt1 : RpDrawingData,
  opt2 : RpDrawingData,
  opt3 : RpDrawingData,
  opt4 : RpDrawingData,
  to_place : ElkNode,
  last_placed : ElkNode,
  padding : ElkPadding,
  goal : RpOptimizationGoal,
  aspect_ratio : Double,
) -> RpDrawingData {
  // elk-reference AreaApproximation.findBestCandidate
  let mut candidates : Array[RpDrawingData] = [opt1, opt2, opt3, opt4]
  let mut filter_order : Array[Int] = []
  match goal {
    MaxScaleDriven => filter_order = [0, 1, 2] // scale, area, aspect
    AspectRatioDriven => filter_order = [2, 1, 0] // aspect, area, scale
    AreaDriven => filter_order = [1, 0, 2] // area, scale, aspect
  }
  for f in filter_order {
    if candidates.length() <= 1 {
      break
    }
    candidates = match f {
      0 => rp_filter_by_scale_measure(candidates, padding)
      1 => rp_filter_by_area(candidates, padding)
      _ => rp_filter_by_aspect_ratio(candidates, aspect_ratio, padding)
    }
  }
  if candidates.length() == 1 {
    candidates[0]
  } else if candidates.length() == 2 {
    rp_check_special_cases(candidates[0], candidates[1], last_placed, to_place)
  } else {
    candidates[0]
  }
}

///|
fn rp_parse_optimization_goal(goal : String?) -> RpOptimizationGoal {
  match goal {
    Some("ASPECT_RATIO_DRIVEN") => AspectRatioDriven
    Some("AREA_DRIVEN") => AreaDriven
    _ => MaxScaleDriven
  }
}

///|
fn rp_greedy_width_approximation(
  rectangles : Array[ElkNode],
  aspect_ratio : Double,
  optimization_goal : RpOptimizationGoal,
  last_place_shift : Bool,
  node_node_spacing : Double,
  padding : ElkPadding,
) -> (Double, Double) {
  // elk-reference GreedyWidthApproximator + AreaApproximation.approxBoundingBox
  if rectangles.is_empty() {
    return (0.0, 0.0)
  }
  rp_reset_coordinates(rectangles)
  let first = rectangles[0]
  first.x = 0.0
  first.y = 0.0
  let placed : Array[ElkNode] = [first]
  let mut last_placed = first
  let mut current = RpDrawingData::new(
    aspect_ratio,
    first.width,
    first.height,
    WholeDrawing,
    0.0,
    0.0,
  )
  for i in 1..<rectangles.length() {
    let to_place = rectangles[i]
    let opt1 = rp_calc_values_for_opt(
      CandidatePositionLastPlacedRight,
      to_place,
      last_placed,
      current,
      placed,
      node_node_spacing,
      last_place_shift,
      aspect_ratio,
    )
    let opt2 = rp_calc_values_for_opt(
      CandidatePositionLastPlacedBelow,
      to_place,
      last_placed,
      current,
      placed,
      node_node_spacing,
      last_place_shift,
      aspect_ratio,
    )
    let opt3 = rp_calc_values_for_opt(
      CandidatePositionWholeDrawingRight,
      to_place,
      last_placed,
      current,
      placed,
      node_node_spacing,
      last_place_shift,
      aspect_ratio,
    )
    let opt4 = rp_calc_values_for_opt(
      CandidatePositionWholeDrawingBelow,
      to_place,
      last_placed,
      current,
      placed,
      node_node_spacing,
      last_place_shift,
      aspect_ratio,
    )
    let best = rp_find_best_candidate(
      opt1, opt2, opt3, opt4, to_place, last_placed, padding, optimization_goal,
      aspect_ratio,
    )
    to_place.x = best.next_x
    to_place.y = best.next_y
    current = RpDrawingData::new(
      best.dar,
      best.drawing_width,
      best.drawing_height,
      WholeDrawing,
      best.next_x,
      best.next_y,
    )
    last_placed = to_place
    placed.push(to_place)
  }
  (current.drawing_width, current.drawing_height)
}
