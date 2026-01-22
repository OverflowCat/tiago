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
/// D2-compatible size-to-fit logic for objects.
///
/// This mirrors D2's sizing pipeline (trimmed to what diago needs):
/// - d2graph.Object.GetDefaultSize
/// - lib/shape.GetDefaultPadding
/// - d2graph.Object.SizeToContent
///
/// Source of truth:
/// - ../d2/d2graph/d2graph.go
/// - ../d2/lib/shape/*.go

///|
const DEFAULT_PADDING : Double = 40.0 // d2/lib/shape/shape.go: defaultPadding

///|
const INNER_LABEL_PADDING : Double = 5.0 // d2graph: INNER_LABEL_PADDING

///|
const MIN_SHAPE_SIZE : Double = 5.0 // d2graph: MIN_SHAPE_SIZE

///|
const PERSON_AR_LIMIT : Double = 1.5 // d2/lib/shape/shape_person.go

///|
const OVAL_AR_LIMIT : Double = 3.0 // d2/lib/shape/shape_oval.go

///|
const DEFAULT_ARC_DEPTH : Double = 24.0 // d2/lib/shape/shape_cylinder.go

///|
const STORED_DATA_WEDGE_WIDTH : Double = 15.0 // d2/lib/shape/shape_stored_data.go

///|
const PARALLEL_WEDGE_WIDTH : Double = 26.0 // d2/lib/shape/shape_parallelogram.go

///|
const STEP_WEDGE_WIDTH : Double = 35.0 // d2/lib/shape/shape_step.go

///|
const CALLOUT_TIP_HEIGHT : Double = 45.0 // d2/lib/shape/shape_callout.go

///|
const PAGE_CORNER_WIDTH : Double = 20.8164 // d2/lib/shape/shape_page.go

///|
const PAGE_CORNER_HEIGHT : Double = 20.348 // d2/lib/shape/shape_page.go

///|
const DOC_PATH_HEIGHT : Double = 18.925 // d2/lib/shape/shape_document.go

///|
const DOC_PATH_INNER_BOTTOM : Double = 14.0 // d2/lib/shape/shape_document.go

///|
const PACKAGE_TOP_MAX_HEIGHT : Double = 55.0 // d2/lib/shape/shape_package.go

///|
const PACKAGE_VERTICAL_SCALAR : Double = 0.2 // d2/lib/shape/shape_package.go

///|
// The percentage values of the cloud's wide inner box (d2/lib/shape/shape_cloud.go)
const CLOUD_WIDE_INNER_WIDTH : Double = 0.819

///|
const CLOUD_WIDE_INNER_HEIGHT : Double = 0.548

///|
const CLOUD_WIDE_ASPECT_BOUNDARY : Double = (
    1.0 + CLOUD_WIDE_INNER_WIDTH / CLOUD_WIDE_INNER_HEIGHT
  ) /
  2.0

///|
// The percentage values of the cloud's tall inner box (d2/lib/shape/shape_cloud.go)
const CLOUD_TALL_INNER_WIDTH : Double = 0.549

///|
const CLOUD_TALL_INNER_HEIGHT : Double = 0.820

///|
const CLOUD_TALL_ASPECT_BOUNDARY : Double = (
    1.0 + CLOUD_TALL_INNER_WIDTH / CLOUD_TALL_INNER_HEIGHT
  ) /
  2.0

///|
// The percentage values of the cloud's square inner box (d2/lib/shape/shape_cloud.go)
const CLOUD_SQUARE_INNER_WIDTH : Double = 0.663

///|
const CLOUD_SQUARE_INNER_HEIGHT : Double = 0.663

///|
priv struct Size {
  width : Double
  height : Double
} derive(Eq, Show)

///|
fn max_d(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_d(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn limit_ar(
  width : Double,
  height : Double,
  aspect_ratio : Double,
) -> (Double, Double) {
  if width > aspect_ratio * height {
    (width, (width / aspect_ratio).round())
  } else if height > aspect_ratio * width {
    ((height / aspect_ratio).round(), height)
  } else {
    (width, height)
  }
}

///|
fn default_padding_for_shape(shape : ShapeType) -> (Double, Double) {
  match shape {
    // d2/lib/shape/shape_text.go
    Text => (0.0, 0.0)
    // d2/lib/shape/shape_code.go
    Code => (0.0, 0.0)
    // d2/lib/shape/shape_image.go
    Image => (0.0, 0.0)
    // d2/lib/shape/shape_person.go
    Person => (10.0, DEFAULT_PADDING)
    // d2/lib/shape/shape_cloud.go
    Cloud => (DEFAULT_PADDING, DEFAULT_PADDING / 2.0)
    // d2/lib/shape/shape_hexagon.go
    Hexagon => (DEFAULT_PADDING / 2.0, DEFAULT_PADDING / 2.0)
    // d2/lib/shape/shape_cylinder.go
    Cylinder => (DEFAULT_PADDING, DEFAULT_PADDING / 2.0)
    // d2/lib/shape/shape_queue.go
    Queue => (DEFAULT_PADDING / 2.0, DEFAULT_PADDING)
    // d2/lib/shape/shape_package.go
    Package => (DEFAULT_PADDING, 0.8 * DEFAULT_PADDING)
    // d2/lib/shape/shape_step.go
    Step => (DEFAULT_PADDING / 4.0, DEFAULT_PADDING + STEP_WEDGE_WIDTH)
    // d2/lib/shape/shape_callout.go
    Callout => (DEFAULT_PADDING, DEFAULT_PADDING / 2.0)
    // d2/lib/shape/shape_stored_data.go
    StoredData => (DEFAULT_PADDING - 10.0, DEFAULT_PADDING)
    // d2/lib/shape/shape_diamond.go
    Diamond => (DEFAULT_PADDING / 4.0, DEFAULT_PADDING / 2.0)
    // d2/lib/shape/shape_circle.go
    Circle => {
      let sqrt2 = 2.0.sqrt()
      (DEFAULT_PADDING / sqrt2, DEFAULT_PADDING / sqrt2)
    }
    // d2/lib/shape/shape_page.go
    Page => (DEFAULT_PADDING, PAGE_CORNER_HEIGHT + DEFAULT_PADDING)
    // d2/lib/shape/shape_document.go
    Document =>
      (
        DEFAULT_PADDING,
        DEFAULT_PADDING * DOC_PATH_INNER_BOTTOM / DOC_PATH_HEIGHT,
      )
    _ => (DEFAULT_PADDING, DEFAULT_PADDING)
  }
}

///|
fn dimensions_to_fit(
  shape : ShapeType,
  content_w : Double,
  content_h : Double,
  pad_x : Double,
  pad_y : Double,
) -> Size {
  match shape {
    // d2/lib/shape/shape_circle.go
    Circle => {
      let sqrt2 = 2.0.sqrt()
      let length = max_d(content_w + pad_x, content_h + pad_y)
      let diameter = (sqrt2 * length).ceil()
      { width: diameter, height: diameter }
    }
    // d2/lib/shape/shape_oval.go
    Oval => {
      let sqrt2 = 2.0.sqrt()
      let theta = @math.atan2(content_h, content_w)
      let padded_w = content_w + pad_x * @math.cos(theta)
      let padded_h = content_h + pad_y * @math.sin(theta)
      let mut total_w = (sqrt2 * padded_w).ceil()
      let mut total_h = (sqrt2 * padded_h).ceil()
      let (w2, h2) = limit_ar(total_w, total_h, OVAL_AR_LIMIT)
      total_w = w2
      total_h = h2
      { width: total_w, height: total_h }
    }
    // d2/lib/shape/shape_diamond.go
    Diamond => {
      let total_w = (2.0 * (content_w + pad_x)).ceil()
      let total_h = (2.0 * (content_h + pad_y)).ceil()
      { width: total_w, height: total_h }
    }
    // d2/lib/shape/shape_hexagon.go
    Hexagon => {
      let total_w = (1.5 * (content_w + pad_x)).ceil()
      let total_h = (1.5 * (content_h + pad_y)).ceil()
      { width: total_w, height: total_h }
    }
    // d2/lib/shape/shape_cloud.go
    Cloud => {
      let w = content_w + pad_x
      let h = content_h + pad_y
      let ar = w / h
      if ar > CLOUD_WIDE_ASPECT_BOUNDARY {
        {
          width: (w / CLOUD_WIDE_INNER_WIDTH).ceil(),
          height: (h / CLOUD_WIDE_INNER_HEIGHT).ceil(),
        }
      } else if ar < CLOUD_TALL_ASPECT_BOUNDARY {
        {
          width: (w / CLOUD_TALL_INNER_WIDTH).ceil(),
          height: (h / CLOUD_TALL_INNER_HEIGHT).ceil(),
        }
      } else {
        {
          width: (w / CLOUD_SQUARE_INNER_WIDTH).ceil(),
          height: (h / CLOUD_SQUARE_INNER_HEIGHT).ceil(),
        }
      }
    }
    // d2/lib/shape/shape_cylinder.go
    Cylinder => {
      let total_h = (content_h + pad_y + 3.0 * DEFAULT_ARC_DEPTH).ceil()
      { width: (content_w + pad_x).ceil(), height: total_h }
    }
    // d2/lib/shape/shape_queue.go
    Queue => {
      let total_w = (3.0 * DEFAULT_ARC_DEPTH + content_w + pad_x).ceil()
      { width: total_w, height: (content_h + pad_y).ceil() }
    }
    // d2/lib/shape/shape_stored_data.go
    StoredData => {
      let total_w = (content_w + pad_x + 2.0 * STORED_DATA_WEDGE_WIDTH).ceil()
      { width: total_w, height: (content_h + pad_y).ceil() }
    }
    // d2/lib/shape/shape_parallelogram.go
    Parallelogram => {
      let total_w = (content_w + pad_x + 2.0 * PARALLEL_WEDGE_WIDTH).ceil()
      { width: total_w, height: (content_h + pad_y).ceil() }
    }
    // d2/lib/shape/shape_step.go
    Step => {
      let total_w = (content_w + pad_x + 2.0 * STEP_WEDGE_WIDTH).ceil()
      { width: total_w, height: (content_h + pad_y).ceil() }
    }
    // d2/lib/shape/shape_package.go
    Package => {
      let inner_h = content_h + pad_y
      let top_h = inner_h *
        PACKAGE_VERTICAL_SCALAR /
        (1.0 - PACKAGE_VERTICAL_SCALAR)
      let total_h = (inner_h + min_d(top_h, PACKAGE_TOP_MAX_HEIGHT)).ceil()
      { width: (content_w + pad_x).ceil(), height: total_h }
    }
    // d2/lib/shape/shape_callout.go
    Callout => {
      let mut base_h = content_h + pad_y
      if base_h < CALLOUT_TIP_HEIGHT {
        base_h = base_h * 2.0
      } else {
        base_h = base_h + CALLOUT_TIP_HEIGHT
      }
      { width: (content_w + pad_x).ceil(), height: base_h.ceil() }
    }
    // d2/lib/shape/shape_page.go
    Page => {
      let mut total_w = content_w + pad_x
      let mut total_h = content_h + pad_y
      if total_h < 3.0 * PAGE_CORNER_HEIGHT {
        total_w = total_w + PAGE_CORNER_WIDTH
      }
      total_w = max_d(total_w, 2.0 * PAGE_CORNER_WIDTH)
      total_h = max_d(total_h, PAGE_CORNER_HEIGHT)
      { width: total_w.ceil(), height: total_h.ceil() }
    }
    // d2/lib/shape/shape_document.go
    Document => {
      let base_h = (content_h + pad_y) * DOC_PATH_HEIGHT / DOC_PATH_INNER_BOTTOM
      { width: (content_w + pad_x).ceil(), height: base_h.ceil() }
    }
    _ =>
      { width: (content_w + pad_x).ceil(), height: (content_h + pad_y).ceil() }
  }
}

///|
fn default_size_for_object(
  shape : ShapeType,
  label_dims : Size,
  with_label_padding : Bool,
  font_size : Int,
) -> Size {
  let mut label_w = label_dims.width
  let mut label_h = label_dims.height
  if shape == Code {
    // d2graph: 0.5em padding on each side
    let fs = font_size.to_double()
    label_w = label_w + fs
    label_h = label_h + fs
  } else if with_label_padding {
    label_w = label_w + INNER_LABEL_PADDING
    label_h = label_h + INNER_LABEL_PADDING
  }
  match shape {
    Text =>
      {
        width: max_d(MIN_SHAPE_SIZE, label_w),
        height: max_d(MIN_SHAPE_SIZE, label_h),
      }
    Image => { width: 128.0, height: 128.0 }
    _ => { width: label_w, height: label_h }
  }
}

///|
fn size_to_content(
  shape : ShapeType,
  content_size : Size,
  pad_x : Double,
  pad_y : Double,
) -> Size {
  if shape == Person {
    // d2graph: special-case person (no shape.GetDimensionsToFit call)
    { width: content_size.width + pad_x, height: content_size.height + pad_y }
  } else {
    dimensions_to_fit(
      shape,
      content_size.width,
      content_size.height,
      pad_x,
      pad_y,
    )
  }
}

///|
fn object_font_size(obj : Object) -> Int {
  match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
}

///|
fn object_has_label(obj : Object) -> Bool {
  obj.label.length() > 0
}

///|
fn object_desired_size(obj : Object) -> (Double, Double) {
  match obj.box {
    Some(b) => (b.width, b.height)
    None => (0.0, 0.0)
  }
}

///|
fn has_some(a : String?) -> Bool {
  match a {
    Some(_) => true
    None => false
  }
}

///|
fn d2_size_object_to_content(obj : Object, label_dims : Size) -> Size {
  let (desired_w, desired_h) = object_desired_size(obj)
  let with_inner_label_padding = desired_w == 0.0 &&
    desired_h == 0.0 &&
    object_has_label(obj) &&
    obj.shape_type != Text
  let font_size = object_font_size(obj)
  let default_size = default_size_for_object(
    obj.shape_type,
    label_dims,
    with_inner_label_padding,
    font_size,
  )

  // d2graph: special case for images (skip further processing)
  if obj.shape_type == Image {
    let w = if desired_w == 0.0 { default_size.width } else { desired_w }
    let h = if desired_h == 0.0 { default_size.height } else { desired_h }
    return { width: max_d(MIN_SHAPE_SIZE, w), height: max_d(MIN_SHAPE_SIZE, h) }
  }
  let (pad_x0, pad_y0) = default_padding_for_shape(obj.shape_type)
  let mut pad_x = if desired_w != 0.0 { 0.0 } else { pad_x0 }
  let mut pad_y = if desired_h != 0.0 { 0.0 } else { pad_y0 }

  // d2graph: extra padding for icon+label shapes
  if obj.icon is Some(_) {
    match obj.shape_type {
      // these shapes already have special label layouts in d2; diago doesn't model them yet
      SqlTable | Class | Code | Text => ()
      _ => {
        let label_h = label_dims.height + INNER_LABEL_PADDING
        if desired_w == 0.0 {
          pad_x = pad_x + label_h
        }
        if desired_h == 0.0 {
          pad_y = pad_y + label_h
        }
      }
    }
  }

  // d2graph: link+tooltip reserve space for icon
  if desired_w == 0.0 {
    match obj.shape_type {
      SqlTable | Class | Code => ()
      _ =>
        if has_some(obj.link) && has_some(obj.tooltip) {
          pad_x = pad_x + 64.0
        }
    }
  }
  let fit = size_to_content(obj.shape_type, default_size, pad_x, pad_y)
  let mut width = if desired_w != 0.0 { desired_w } else { fit.width }
  let mut height = if desired_h != 0.0 { desired_h } else { fit.height }

  // d2graph: keep fit dims as minimum for these shapes
  match obj.shape_type {
    SqlTable | Class => {
      width = max_d(width, fit.width)
      height = max_d(height, fit.height)
    }
    _ => ()
  }

  // d2graph: aspect ratio / limits
  if obj.shape_type == Circle {
    let side = max_d(width, height)
    width = side
    height = side
  } else if desired_h == 0.0 || desired_w == 0.0 {
    match obj.shape_type {
      Person => {
        let (w2, h2) = limit_ar(width, height, PERSON_AR_LIMIT)
        width = w2
        height = h2
      }
      Oval => {
        let (w2, h2) = limit_ar(width, height, OVAL_AR_LIMIT)
        width = w2
        height = h2
      }
      _ => ()
    }
  }
  { width: max_d(MIN_SHAPE_SIZE, width), height: max_d(MIN_SHAPE_SIZE, height) }
}
