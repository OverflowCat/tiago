///|
pub struct List[T] {
  items : Array[T]

  fn[T] new() -> List[T]
}

///|
pub fn[T] List::new() -> List[T] {
  { items: [] }
}

///|
pub fn[T] List::dequeue(self : List[T]) -> T? {
  if self.items.is_empty() {
    None
  } else {
    self.items.pop()
  }
}

///|
pub fn[T : Eq] List::enqueue(self : List[T], entry : T) -> Unit {
  let index = self.items.search_by(x => x == entry)
  if index is Some(i) {
    ignore(self.items.remove(i))
  }
  self.items.insert(0, entry)
}

///|
pub fn[T] List::to_array(self : List[T]) -> Array[T] {
  self.items.copy()
}

///|
pub fn[T] List::is_empty(self : List[T]) -> Bool {
  self.items.is_empty()
}

///|
pub fn[T : Show] List::to_string(self : List[T]) -> String {
  let values = self.items.copy()
  values.rev_in_place()
  "[" + values.map(v => v.to_string()).join(", ") + "]"
}
