///|
/// Shape types for D2 diagram objects
///
/// This enum represents all supported shape types in D2 diagrams.
/// Each shape has its own rendering logic for both SVG and ASCII outputs.

///|
/// All supported shape types
pub(all) enum ShapeType {
  // Basic shapes
  Rectangle
  Square
  Circle
  Oval
  Diamond
  Hexagon
  Parallelogram
  // Special 3D-like shapes
  Cylinder
  Queue
  Package
  Step
  Callout
  StoredData
  Person
  Cloud
  Page
  Document
  // Container shapes with structured content
  Class
  SqlTable
  // Text-only shapes (no border)
  Text
  Code
  // External content
  Image
  // Special diagram types
  SequenceDiagram
  // Additional shapes
  Octagon
  // C4 Model shapes
  C4Person
  C4Container
} derive(Eq, Show)

///|
/// Parse a shape type from a string
pub fn ShapeType::from_string(s : String) -> ShapeType {
  match s.to_lower() {
    "rectangle" | "rect" => Rectangle
    "square" => Square
    "circle" => Circle
    "oval" | "ellipse" => Oval
    "diamond" => Diamond
    "hexagon" => Hexagon
    "parallelogram" => Parallelogram
    "cylinder" => Cylinder
    "queue" => Queue
    "package" => Package
    "step" => Step
    "callout" => Callout
    "stored_data" | "storeddata" => StoredData
    "person" => Person
    "cloud" => Cloud
    "page" => Page
    "document" => Document
    "class" => Class
    "sql_table" | "sqltable" => SqlTable
    "text" => Text
    "code" => Code
    "image" => Image
    "sequence_diagram" | "sequencediagram" => SequenceDiagram
    "octagon" => Octagon
    "c4_person" | "c4person" => C4Person
    "c4_container" | "c4container" => C4Container
    _ => Rectangle // Default to rectangle for unknown shapes
  }
}

///|
/// Convert shape type to canonical string representation
pub fn ShapeType::to_shape_string(self : ShapeType) -> String {
  match self {
    Rectangle => "rectangle"
    Square => "square"
    Circle => "circle"
    Oval => "oval"
    Diamond => "diamond"
    Hexagon => "hexagon"
    Parallelogram => "parallelogram"
    Cylinder => "cylinder"
    Queue => "queue"
    Package => "package"
    Step => "step"
    Callout => "callout"
    StoredData => "stored_data"
    Person => "person"
    Cloud => "cloud"
    Page => "page"
    Document => "document"
    Class => "class"
    SqlTable => "sql_table"
    Text => "text"
    Code => "code"
    Image => "image"
    SequenceDiagram => "sequence_diagram"
    Octagon => "octagon"
    C4Person => "c4_person"
    C4Container => "c4_container"
  }
}

///|
/// Check if this shape is a container type (can have structured children)
pub fn ShapeType::is_container(self : ShapeType) -> Bool {
  match self {
    Class | SqlTable => true
    _ => false
  }
}

///|
/// Check if this shape is a text-only type (no border)
pub fn ShapeType::is_text_only(self : ShapeType) -> Bool {
  match self {
    Text | Code => true
    _ => false
  }
}

///|
/// Check if this shape renders its label inside the shape
pub fn ShapeType::has_inside_label(self : ShapeType) -> Bool {
  match self {
    Text | Code | Image => false
    _ => true
  }
}

///|
/// Check if this shape needs special 3D rendering
pub fn ShapeType::is_3d_shape(self : ShapeType) -> Bool {
  match self {
    Cylinder | Queue | Package | Step | Callout | StoredData => true
    _ => false
  }
}

///|
/// Get the default aspect ratio for the shape (width / height)
pub fn ShapeType::default_aspect_ratio(self : ShapeType) -> Double {
  match self {
    Circle => 1.0
    Square => 1.0
    Person => 0.6 // Taller than wide
    Cylinder => 0.8
    Document => 0.8
    _ => 1.5 // Default: wider than tall
  }
}
