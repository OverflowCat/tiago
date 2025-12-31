///|
/// Graph representation for D2 diagrams
///
/// The Graph is the final representation used for layout and rendering.
/// It contains Objects (nodes) and Edges (connections) with their
/// visual properties.

///|
/// The main graph structure
pub struct Graph {
  name : String
  root : Object
  objects : Array[Object]
  edges : Array[Edge]
} derive(Show)

///|
/// A node/shape in the diagram
pub struct Object {
  /// Unique identifier
  id : String
  /// Display label
  mut label : String
  /// Shape type (rectangle, circle, etc.)
  mut shape : String
  /// Visual style
  style : Style
  /// Position and size
  mut box : Box?
  /// Child objects (for containers)
  children : Array[Object]
  /// Z-index for layering
  z_index : Int
  /// Icon URL if any
  mut icon : String?
  /// Tooltip text
  mut tooltip : String?
  /// Link URL
  mut link : String?
  /// CSS classes
  classes : Array[String]
  /// Grid layout: number of rows
  mut grid_rows : Int?
  /// Grid layout: number of columns
  mut grid_columns : Int?
  /// Grid layout: gap between cells
  mut grid_gap : Double?
  /// Grid layout: horizontal gap between cells
  mut horizontal_gap : Double?
  /// Grid layout: vertical gap between cells
  mut vertical_gap : Double?
} derive(Show)

///|
/// An edge/connection between objects
pub struct Edge {
  /// Index in the graph's edge list
  index : Int
  /// Source object ID
  src_id : String
  /// Destination object ID
  dst_id : String
  /// Has arrow at source
  src_arrow : Bool
  /// Has arrow at destination
  dst_arrow : Bool
  /// Edge label
  mut label : String
  /// Visual style
  style : Style
  /// Route points for the edge path
  route : Array[Point]
  /// Whether edge is curved
  is_curve : Bool
  /// Z-index for layering
  z_index : Int
} derive(Show)

///|
/// Bounding box for positioning
pub struct Box {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Show)

///|
/// A 2D point
pub struct Point {
  x : Double
  y : Double
} derive(Eq, Show)

///|
/// Visual styling properties
pub struct Style {
  mut opacity : Double?
  mut stroke : String?
  mut fill : String?
  mut stroke_width : Double?
  stroke_dash : Double?
  mut border_radius : Double?
  mut shadow : Bool?
  mut three_d : Bool?
  multiple : Bool?
  font : String?
  mut font_size : Int?
  mut font_color : String?
  mut bold : Bool?
  mut italic : Bool?
  underline : Bool?
  mut animated : Bool?
  filled : Bool?
  double_border : Bool?
} derive(Eq, Show)

// ============================================================================
// Constructors
// ============================================================================

///|
pub fn Graph::new(name : String) -> Graph {
  let root = Object::new("root")
  { name, root, objects: [], edges: [] }
}

///|
pub fn Object::new(id : String) -> Object {
  {
    id,
    label: id,
    shape: "rectangle",
    style: Style::new(),
    box: None,
    children: [],
    z_index: 0,
    icon: None,
    tooltip: None,
    link: None,
    classes: [],
    grid_rows: None,
    grid_columns: None,
    grid_gap: None,
    horizontal_gap: None,
    vertical_gap: None,
  }
}

///|
pub fn Object::with_label(id : String, label : String) -> Object {
  let obj = Object::new(id)
  obj.label = label
  obj
}

///|
pub fn Edge::new(
  index : Int,
  src_id : String,
  dst_id : String,
  src_arrow : Bool,
  dst_arrow : Bool,
) -> Edge {
  {
    index,
    src_id,
    dst_id,
    src_arrow,
    dst_arrow,
    label: "",
    style: Style::new(),
    route: [],
    is_curve: false,
    z_index: 0,
  }
}

///|
pub fn Box::new(x : Double, y : Double, width : Double, height : Double) -> Box {
  { x, y, width, height }
}

///|
pub fn Box::zero() -> Box {
  { x: 0.0, y: 0.0, width: 0.0, height: 0.0 }
}

///|
pub fn Point::new(x : Double, y : Double) -> Point {
  { x, y }
}

///|
pub fn Point::zero() -> Point {
  { x: 0.0, y: 0.0 }
}

///|
pub fn Style::new() -> Style {
  {
    opacity: None,
    stroke: None,
    fill: None,
    stroke_width: None,
    stroke_dash: None,
    border_radius: None,
    shadow: None,
    three_d: None,
    multiple: None,
    font: None,
    font_size: None,
    font_color: None,
    bold: None,
    italic: None,
    underline: None,
    animated: None,
    filled: None,
    double_border: None,
  }
}

// ============================================================================
// Graph operations
// ============================================================================

///|
/// Add an object to the graph
pub fn Graph::add_object(self : Graph, obj : Object) -> Unit {
  self.objects.push(obj)
}

///|
/// Get all objects in the graph
pub fn Graph::get_objects(self : Graph) -> Array[Object] {
  self.objects
}

///|
/// Get all edges in the graph
pub fn Graph::get_edges(self : Graph) -> Array[Edge] {
  self.edges
}

///|
/// Add an edge to the graph
pub fn Graph::add_edge(self : Graph, edge : Edge) -> Unit {
  self.edges.push(edge)
}

///|
/// Find an object by ID
pub fn Graph::find_object(self : Graph, id : String) -> Object? {
  for obj in self.objects {
    if obj.id == id {
      return Some(obj)
    }
  }
  None
}

///|
/// Get all edges from a source object
pub fn Graph::edges_from(self : Graph, src_id : String) -> Array[Edge] {
  let result : Array[Edge] = []
  for edge in self.edges {
    if edge.src_id == src_id {
      result.push(edge)
    }
  }
  result
}

///|
/// Get all edges to a destination object
pub fn Graph::edges_to(self : Graph, dst_id : String) -> Array[Edge] {
  let result : Array[Edge] = []
  for edge in self.edges {
    if edge.dst_id == dst_id {
      result.push(edge)
    }
  }
  result
}

// ============================================================================
// Object operations
// ============================================================================

///|
/// Add a child object
pub fn Object::add_child(self : Object, child : Object) -> Unit {
  self.children.push(child)
}

///|
/// Find a child by ID
pub fn Object::find_child(self : Object, id : String) -> Object? {
  for child in self.children {
    if child.id == id {
      return Some(child)
    }
  }
  None
}

///|
/// Check if this object is a container (has children)
pub fn Object::is_container(self : Object) -> Bool {
  self.children.length() > 0
}

///|
/// Check if this object is a grid diagram (has grid-rows or grid-columns)
pub fn Object::is_grid_diagram(self : Object) -> Bool {
  self.grid_rows is Some(_) || self.grid_columns is Some(_)
}

///|
/// Get grid rows count
pub fn Object::get_grid_rows(self : Object) -> Int? {
  self.grid_rows
}

///|
/// Get grid columns count
pub fn Object::get_grid_columns(self : Object) -> Int? {
  self.grid_columns
}

///|
/// Get horizontal gap (uses grid_gap as default)
pub fn Object::get_horizontal_gap(self : Object) -> Double {
  match self.horizontal_gap {
    Some(v) => v
    None =>
      match self.grid_gap {
        Some(v) => v
        None => 40.0 // Default gap
      }
  }
}

///|
/// Get vertical gap (uses grid_gap as default)
pub fn Object::get_vertical_gap(self : Object) -> Double {
  match self.vertical_gap {
    Some(v) => v
    None =>
      match self.grid_gap {
        Some(v) => v
        None => 40.0 // Default gap
      }
  }
}

///|
/// Set grid rows
pub fn Object::set_grid_rows(self : Object, rows : Int) -> Unit {
  self.grid_rows = Some(rows)
}

///|
/// Set grid columns
pub fn Object::set_grid_columns(self : Object, columns : Int) -> Unit {
  self.grid_columns = Some(columns)
}

///|
/// Set grid gap
pub fn Object::set_grid_gap(self : Object, gap : Double) -> Unit {
  self.grid_gap = Some(gap)
}

///|
/// Set the position and size of the object
pub fn Object::set_box(self : Object, box : Box) -> Unit {
  self.box = Some(box)
}

///|
/// Set the shape of the object
pub fn Object::set_shape(self : Object, shape : String) -> Unit {
  self.shape = shape
}

///|
/// Set the label of the object
pub fn Object::set_label(self : Object, label : String) -> Unit {
  self.label = label
}

///|
/// Get the object's ID
pub fn Object::get_id(self : Object) -> String {
  self.id
}

///|
/// Get the object's box (position and size)
pub fn Object::get_box(self : Object) -> Box? {
  self.box
}

///|
/// Get the object's children
pub fn Object::get_children(self : Object) -> Array[Object] {
  self.children
}

///|
/// Get the object's shape
pub fn Object::get_shape(self : Object) -> String {
  self.shape
}

///|
/// Get the object's label
pub fn Object::get_label(self : Object) -> String {
  self.label
}

///|
/// Get the center point of the object's box
pub fn Object::center(self : Object) -> Point? {
  match self.box {
    Some(b) => Some(Point::new(b.x + b.width / 2.0, b.y + b.height / 2.0))
    None => None
  }
}

// ============================================================================
// Box operations
// ============================================================================

///|
/// Get the center point of the box
pub fn Box::center(self : Box) -> Point {
  Point::new(self.x + self.width / 2.0, self.y + self.height / 2.0)
}

///|
/// Get the top-left corner
pub fn Box::top_left(self : Box) -> Point {
  Point::new(self.x, self.y)
}

///|
/// Get the top-right corner
pub fn Box::top_right(self : Box) -> Point {
  Point::new(self.x + self.width, self.y)
}

///|
/// Get the bottom-left corner
pub fn Box::bottom_left(self : Box) -> Point {
  Point::new(self.x, self.y + self.height)
}

///|
/// Get the bottom-right corner
pub fn Box::bottom_right(self : Box) -> Point {
  Point::new(self.x + self.width, self.y + self.height)
}

///|
/// Check if a point is inside the box
pub fn Box::contains(self : Box, p : Point) -> Bool {
  p.x >= self.x &&
  p.x <= self.x + self.width &&
  p.y >= self.y &&
  p.y <= self.y + self.height
}

///|
/// Check if this box intersects another
pub fn Box::intersects(self : Box, other : Box) -> Bool {
  not(
    self.x + self.width < other.x ||
    other.x + other.width < self.x ||
    self.y + self.height < other.y ||
    other.y + other.height < self.y,
  )
}

///|
/// Get x coordinate
pub fn Box::get_x(self : Box) -> Double {
  self.x
}

///|
/// Get y coordinate
pub fn Box::get_y(self : Box) -> Double {
  self.y
}

///|
/// Get width
pub fn Box::get_width(self : Box) -> Double {
  self.width
}

///|
/// Get height
pub fn Box::get_height(self : Box) -> Double {
  self.height
}

///|
/// Get x coordinate
pub fn Point::get_x(self : Point) -> Double {
  self.x
}

///|
/// Get y coordinate
pub fn Point::get_y(self : Point) -> Double {
  self.y
}

// ============================================================================
// Edge operations
// ============================================================================

///|
/// Get the arrow string representation
pub fn Edge::arrow_string(self : Edge) -> String {
  if self.src_arrow && self.dst_arrow {
    "<->"
  } else if self.src_arrow {
    "<-"
  } else if self.dst_arrow {
    "->"
  } else {
    "--"
  }
}

///|
/// Set the label of the edge
pub fn Edge::set_label(self : Edge, label : String) -> Unit {
  self.label = label
}

///|
/// Get the source object ID
pub fn Edge::get_src_id(self : Edge) -> String {
  self.src_id
}

///|
/// Get the destination object ID
pub fn Edge::get_dst_id(self : Edge) -> String {
  self.dst_id
}

///|
/// Get the route points
pub fn Edge::get_route(self : Edge) -> Array[Point] {
  self.route
}

///|
/// Add a point to the route
pub fn Edge::add_route_point(self : Edge, p : Point) -> Unit {
  self.route.push(p)
}

///|
/// Get the midpoint of the edge route
pub fn Edge::midpoint(self : Edge) -> Point? {
  let len = self.route.length()
  if len == 0 {
    return None
  }
  if len == 1 {
    return Some(self.route[0])
  }
  // For even number of points, average the two middle points
  let mid = len / 2
  if len % 2 == 0 {
    let p1 = self.route[mid - 1]
    let p2 = self.route[mid]
    Some(Point::new((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0))
  } else {
    Some(self.route[mid])
  }
}

// ============================================================================
// Point operations
// ============================================================================

///|
/// Calculate distance to another point
pub fn Point::distance(self : Point, other : Point) -> Double {
  let dx = self.x - other.x
  let dy = self.y - other.y
  (dx * dx + dy * dy).sqrt()
}

///|
/// Add two points
pub fn Point::add(self : Point, other : Point) -> Point {
  Point::new(self.x + other.x, self.y + other.y)
}

///|
/// Subtract another point
pub fn Point::sub(self : Point, other : Point) -> Point {
  Point::new(self.x - other.x, self.y - other.y)
}

///|
/// Scale by a factor
pub fn Point::scale(self : Point, factor : Double) -> Point {
  Point::new(self.x * factor, self.y * factor)
}
