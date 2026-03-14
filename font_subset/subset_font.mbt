// Copyright 2026
//
// Ported from ../d2/lib/font/subsetFont.go.

///|
let symbol_words : Int = 1 << 0

///|
let symbol_scale : Int = 1 << 3

///|
let symbol_continue : Int = 1 << 5

///|
let symbol_all_scale : Int = 1 << 6

///|
let symbol_2x2 : Int = 1 << 7

///|
#warnings("-unused_field")
priv struct FontBox {
  x_min : Int
  y_min : Int
  x_max : Int
  y_max : Int
}

///|
#warnings("-unused_field")
priv struct TableDescription {
  name : String
  checksum_hi : Int
  checksum_lo : Int
  position : Int
  size : Int
}

///|
priv struct FileReader {
  mut reader_position : Int
  array : Array[Byte]
}

///|
fn FileReader::read(self : FileReader, n : Int) -> Array[Byte] {
  let start = self.reader_position
  let end_ = start + n
  self.reader_position = end_
  self.array[start:end_].to_array()
}

///|
fn FileReader::seek(self : FileReader, shift : Int, flag : Int) -> Int {
  if flag == 0 {
    self.reader_position = shift
  } else if flag == 1 {
    self.reader_position = self.reader_position + shift
  } else if flag == 2 {
    self.reader_position = self.array.length() - shift
  }
  self.reader_position
}

///|
#warnings("-unused_field")
priv struct Utf8FontFile {
  file_reader : FileReader
  mut last_rune : Int
  mut table_descriptions : Map[String, TableDescription]
  mut out_tables_data : Map[String, Array[Byte]]
  mut symbol_position : Array[Int]
  mut char_symbol_dictionary : Map[Int, Int]
  mut ascent : Int
  mut descent : Int
  mut bbox : FontBox
  mut cap_height : Int
  mut stem_v : Int
  mut italic_angle : Int
  mut flags : Int
  mut underline_position : Double
  mut underline_thickness : Double
  mut char_widths : Array[Int]
  mut default_width : Double
  mut symbol_data : Map[Int, Map[String, Array[Int]]]
  mut code_symbol_dictionary : Map[Int, Int]
}

///|
fn new_utf8_font(reader : FileReader) -> Utf8FontFile {
  Utf8FontFile::{
    file_reader: reader,
    last_rune: 0,
    table_descriptions: {},
    out_tables_data: {},
    symbol_position: [],
    char_symbol_dictionary: {},
    ascent: 0,
    descent: 0,
    bbox: FontBox::{ x_min: 0, y_min: 0, x_max: 0, y_max: 0 },
    cap_height: 0,
    stem_v: 0,
    italic_angle: 0,
    flags: 0,
    underline_position: 0.0,
    underline_thickness: 0.0,
    char_widths: [],
    default_width: 0.0,
    symbol_data: {},
    code_symbol_dictionary: {},
  }
}

///|
fn read_u16_be(data : Array[Byte], at : Int) -> Int {
  (data[at].to_int() << 8) + data[at + 1].to_int()
}

///|
fn read_u32_be(data : Array[Byte], at : Int) -> Int {
  (data[at].to_int() << 24) +
  (data[at + 1].to_int() << 16) +
  (data[at + 2].to_int() << 8) +
  data[at + 3].to_int()
}

///|
fn write_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v & 0xFFFF
  out.push(((u >> 8) & 0xFF).to_byte())
  out.push((u & 0xFF).to_byte())
}

///|
fn write_u32_be(out : Array[Byte], v : Int) -> Unit {
  let u = v & 0xFFFFFFFF
  out.push(((u >> 24) & 0xFF).to_byte())
  out.push(((u >> 16) & 0xFF).to_byte())
  out.push(((u >> 8) & 0xFF).to_byte())
  out.push((u & 0xFF).to_byte())
}

///|
fn bytes4_to_string(bs : Array[Byte]) -> String {
  let sb = StringBuilder::new()
  for b in bs {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if b > a {
    b
  } else {
    a
  }
}

///|
fn align4(v : Int) -> Int {
  (v + 3) / 4 * 4
}

///|
fn safe_read_u16_be(data : Array[Byte], at : Int) -> Int? {
  if at < 0 || at + 1 >= data.length() {
    return None
  }
  Some((data[at].to_int() << 8) + data[at + 1].to_int())
}

///|
fn safe_read_u32_be(data : Array[Byte], at : Int) -> Int? {
  if at < 0 || at + 3 >= data.length() {
    return None
  }
  Some(
    (data[at].to_int() << 24) +
    (data[at + 1].to_int() << 16) +
    (data[at + 2].to_int() << 8) +
    data[at + 3].to_int(),
  )
}

///|
fn has_required_tables(tags : Map[String, Bool]) -> Bool {
  tags.contains("head") &&
  tags.contains("hhea") &&
  tags.contains("maxp") &&
  tags.contains("cmap") &&
  tags.contains("loca") &&
  tags.contains("glyf") &&
  tags.contains("hmtx")
}

///|
fn is_plausible_sfnt(data : Array[Byte]) -> Bool {
  if data.length() < 12 {
    return false
  }
  let num_tables = match safe_read_u16_be(data, 4) {
    Some(v) => v
    None => return false
  }
  if num_tables <= 0 {
    return false
  }
  let table_dir_len = 12 + num_tables * 16
  if table_dir_len > data.length() {
    return false
  }

  let tags : Map[String, Bool] = {}
  for i in 0..<num_tables {
    let rec = 12 + i * 16
    let tag = bytes4_to_string(data[rec:rec + 4].to_array())
    tags[tag] = true
    let offset = match safe_read_u32_be(data, rec + 8) {
      Some(v) => v
      None => return false
    }
    let size = match safe_read_u32_be(data, rec + 12) {
      Some(v) => v
      None => return false
    }
    if offset < 0 ||
      size < 0 ||
      offset > data.length() ||
      size > data.length() - offset {
      return false
    }
  }

  has_required_tables(tags)
}

///|
fn Utf8FontFile::read_table_name(self : Utf8FontFile) -> String {
  bytes4_to_string(self.file_reader.read(4))
}

///|
fn Utf8FontFile::read_uint16(self : Utf8FontFile) -> Int {
  let s = self.file_reader.read(2)
  (s[0].to_int() << 8) + s[1].to_int()
}

///|
fn Utf8FontFile::read_uint32(self : Utf8FontFile) -> Int {
  let s = self.file_reader.read(4)
  (s[0].to_int() << 24) +
  (s[1].to_int() << 16) +
  (s[2].to_int() << 8) +
  s[3].to_int()
}

///|
fn Utf8FontFile::read_int16(self : Utf8FontFile) -> Int {
  let s = self.file_reader.read(2)
  let a = (s[0].to_int() << 8) + s[1].to_int()
  if (a & (1 << 15)) != 0 {
    a - (1 << 16)
  } else {
    a
  }
}

///|
fn Utf8FontFile::calc_int32(
  _self : Utf8FontFile,
  x_hi : Int,
  x_lo : Int,
  y_hi : Int,
  y_lo : Int,
) -> (Int, Int) {
  let mut xh = x_hi
  let mut xl = x_lo
  if y_lo > xl {
    xl = xl + (1 << 16)
    xh = xh + 1
  }
  let ans_lo = xl - y_lo
  if y_hi > xh {
    xh = xh + (1 << 16)
  }
  let ans_hi = (xh - y_hi) & 0xFFFF
  (ans_hi, ans_lo)
}

///|
fn Utf8FontFile::generate_checksum(
  _self : Utf8FontFile,
  data : Array[Byte],
) -> (Int, Int) {
  let data2 = data.copy()
  while data2.length() % 4 != 0 {
    data2.push(b'\x00')
  }
  let mut hi = 0x0000
  let mut lo = 0x0000
  let mut i = 0
  while i < data2.length() {
    hi = hi + ((data2[i].to_int() << 8) + data2[i + 1].to_int())
    lo = lo + ((data2[i + 2].to_int() << 8) + data2[i + 3].to_int())
    hi = hi + (lo >> 16)
    lo = lo & 0xFFFF
    hi = hi & 0xFFFF
    i = i + 4
  }
  (hi, lo)
}

///|
fn Utf8FontFile::seek(self : Utf8FontFile, shift : Int) -> Unit {
  ignore(self.file_reader.seek(shift, 0))
}

///|
fn Utf8FontFile::skip(self : Utf8FontFile, delta : Int) -> Unit {
  ignore(self.file_reader.seek(delta, 1))
}

///|
fn Utf8FontFile::seek_table(
  self : Utf8FontFile,
  name : String,
  offset_in_table : Int,
) -> Int {
  let desc = self.table_descriptions.get(name).unwrap()
  ignore(self.file_reader.seek(desc.position + offset_in_table, 0))
  self.file_reader.reader_position
}

///|
fn Utf8FontFile::seek_table_start(self : Utf8FontFile, name : String) -> Int {
  self.seek_table(name, 0)
}

///|
fn Utf8FontFile::get_uint16(self : Utf8FontFile, pos : Int) -> Int {
  ignore(self.file_reader.seek(pos, 0))
  let s = self.file_reader.read(2)
  (s[0].to_int() << 8) + s[1].to_int()
}

///|
fn splice_bytes(
  stream : Array[Byte],
  offset : Int,
  value : Array[Byte],
) -> Array[Byte] {
  let out : Array[Byte] = []
  for i in 0..<offset {
    out.push(stream[i])
  }
  out.append(value)
  let suffix_start = offset + value.length()
  let mut i = suffix_start
  while i < stream.length() {
    out.push(stream[i])
    i = i + 1
  }
  out
}

///|
fn Utf8FontFile::insert_uint16(
  _self : Utf8FontFile,
  stream : Array[Byte],
  offset : Int,
  value : Int,
) -> Array[Byte] {
  let rep : Array[Byte] = []
  write_u16_be(rep, value)
  splice_bytes(stream, offset, rep)
}

///|
fn Utf8FontFile::get_range(
  self : Utf8FontFile,
  pos : Int,
  length : Int,
) -> Array[Byte] {
  ignore(self.file_reader.seek(pos, 0))
  if length < 1 {
    return []
  }
  self.file_reader.read(length)
}

///|
fn Utf8FontFile::get_table_data(
  self : Utf8FontFile,
  name : String,
) -> Array[Byte]? {
  match self.table_descriptions.get(name) {
    None => None
    Some(desc) =>
      if desc.size == 0 {
        None
      } else {
        ignore(self.file_reader.seek(desc.position, 0))
        Some(self.file_reader.read(desc.size))
      }
  }
}

///|
fn Utf8FontFile::set_out_table(
  self : Utf8FontFile,
  name : String,
  data : Array[Byte]?,
) -> Unit {
  match data {
    None => ()
    Some(data0) => {
      let mut d = data0.copy()
      if name == "head" {
        if d.length() >= 12 {
          d = splice_bytes(d, 8, [b'\x00', b'\x00', b'\x00', b'\x00'])
        }
      }
      self.out_tables_data[name] = d
    }
  }
}

///|
fn Utf8FontFile::generate_table_descriptions(self : Utf8FontFile) -> Unit {
  let tables_count = self.read_uint16()
  ignore(self.read_uint16())
  ignore(self.read_uint16())
  ignore(self.read_uint16())
  self.table_descriptions = {}
  for _ in 0..<tables_count {
    let name = self.read_table_name()
    let checksum_hi = self.read_uint16()
    let checksum_lo = self.read_uint16()
    let position = self.read_uint32()
    let size = self.read_uint32()
    self.table_descriptions[name] = TableDescription::{
      name,
      checksum_hi,
      checksum_lo,
      position,
      size,
    }
  }
}

///|
fn key_sort_strings_map_bytes(s : Map[String, Array[Byte]]) -> Array[String] {
  let keys : Array[String] = []
  for k, _ in s {
    keys.push(k)
  }
  keys.sort_by(fn(a, b) { a.compare(b) })
  keys
}

///|
fn key_sort_int_map_int(s : Map[Int, Int]) -> Array[Int] {
  let keys : Array[Int] = []
  for k, _ in s {
    keys.push(k)
  }
  keys.sort_by(fn(a, b) { a - b })
  keys
}

///|
fn key_sort_int_map_array(s : Map[Int, Array[Int]]) -> Array[Int] {
  let keys : Array[Int] = []
  for k, _ in s {
    keys.push(k)
  }
  keys.sort_by(fn(a, b) { a - b })
  keys
}

///|
fn unpack_uint16(data : Array[Byte]) -> Int {
  read_u16_be(data, 0)
}

///|
fn unpack_uint16_array(data : Array[Byte]) -> Array[Int] {
  let answer : Array[Int] = [0]
  let mut i = 0
  while i + 1 < data.length() {
    answer.push(read_u16_be(data, i))
    i = i + 2
  }
  answer
}

///|
fn unpack_uint32_array(data : Array[Byte]) -> Array[Int] {
  let answer : Array[Int] = [0]
  let mut i = 0
  while i + 3 < data.length() {
    answer.push(read_u32_be(data, i))
    i = i + 4
  }
  answer
}

///|
fn pack_header(n : Int, n1 : Int, n2 : Int, n3 : Int, n4 : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  write_u32_be(out, n)
  write_u16_be(out, n1)
  write_u16_be(out, n2)
  write_u16_be(out, n3)
  write_u16_be(out, n4)
  out
}

///|
fn pack2_uint16(n1 : Int, n2 : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  write_u16_be(out, n1)
  write_u16_be(out, n2)
  out
}

///|
fn pack2_uint32(n1 : Int, n2 : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  write_u32_be(out, n1)
  write_u32_be(out, n2)
  out
}

///|
fn pack_uint16(n1 : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  write_u16_be(out, n1)
  out
}

///|
fn pack_uint32(n1 : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  write_u32_be(out, n1)
  out
}

///|
fn Utf8FontFile::generate_sccs_dictionaries(
  self : Utf8FontFile,
  rune_cmap_position : Int,
  symbol_char_dictionary : Map[Int, Array[Int]],
  char_symbol_dictionary : Map[Int, Int],
) -> Unit {
  let mut max_rune = 0
  self.seek(rune_cmap_position + 2)
  let size = self.read_uint16()
  let rim = rune_cmap_position + size
  self.skip(2)

  let segment_size = self.read_uint16() / 2
  self.skip(6)

  let completers : Array[Int] = []
  for _ in 0..<segment_size {
    completers.push(self.read_uint16())
  }
  self.skip(2)

  let beginners : Array[Int] = []
  for _ in 0..<segment_size {
    beginners.push(self.read_uint16())
  }

  let sizes : Array[Int] = []
  for _ in 0..<segment_size {
    sizes.push(self.read_int16())
  }

  let reader_position_start = self.file_reader.reader_position

  let positions : Array[Int] = []
  for _ in 0..<segment_size {
    positions.push(self.read_uint16())
  }

  let mut symbol = 0
  for n in 0..<segment_size {
    let complete_position = completers[n] + 1
    let mut ch = beginners[n]
    while ch < complete_position {
      if positions[n] == 0 {
        symbol = (ch + sizes[n]) & 0xFFFF
      } else {
        let mut position = (ch - beginners[n]) * 2 + positions[n]
        position = reader_position_start + 2 * n + position
        if position >= rim {
          symbol = 0
        } else {
          symbol = self.get_uint16(position)
          if symbol != 0 {
            symbol = (symbol + sizes[n]) & 0xFFFF
          }
        }
      }

      char_symbol_dictionary[ch] = symbol
      if ch < 196608 {
        max_rune = max_int(ch, max_rune)
      }

      let arr = symbol_char_dictionary.get_or_default(symbol, [])
      arr.push(ch)
      symbol_char_dictionary[symbol] = arr

      ch = ch + 1
    }
  }
}

///|
fn Utf8FontFile::generate_cmap(self : Utf8FontFile) -> Map[Int, Array[Int]]? {
  let cmap_position = self.seek_table_start("cmap")
  self.skip(2)
  let cmap_table_count = self.read_uint16()
  let mut rune_cmap_position = 0
  for _ in 0..<cmap_table_count {
    let system = self.read_uint16()
    let coder = self.read_uint16()
    let position = self.read_uint32()
    let old_position = self.file_reader.reader_position
    if (system == 3 && coder == 1) || system == 0 {
      let format = self.get_uint16(cmap_position + position)
      if format == 4 {
        rune_cmap_position = cmap_position + position
        break
      }
    }
    self.seek(old_position)
  }

  if rune_cmap_position == 0 {
    return None
  }

  let symbol_char_dictionary : Map[Int, Array[Int]] = {}
  let char_symbol_dictionary : Map[Int, Int] = {}
  self.generate_sccs_dictionaries(
    rune_cmap_position, symbol_char_dictionary, char_symbol_dictionary,
  )
  self.char_symbol_dictionary = char_symbol_dictionary
  Some(symbol_char_dictionary)
}

///|
fn Utf8FontFile::get_symbols(
  self : Utf8FontFile,
  original_symbol_idx : Int,
  start : Int,
  symbol_set : Map[Int, Int],
  symbols_collection : Map[Int, Int],
  symbols_collection_keys : Array[Int],
) -> (Map[Int, Int], Map[Int, Int], Array[Int]) {
  let symbol_pos = self.symbol_position[original_symbol_idx]
  let symbol_size = self.symbol_position[original_symbol_idx + 1] - symbol_pos
  if symbol_size == 0 {
    return (symbol_set, symbols_collection, symbols_collection_keys)
  }

  self.seek(start + symbol_pos)
  let line_count = self.read_int16()

  if line_count < 0 {
    self.skip(8)
    let mut flags = symbol_continue
    let mut symbol_set_mut = symbol_set
    let mut symbols_collection_mut = symbols_collection
    let mut keys_mut = symbols_collection_keys
    while (flags & symbol_continue) != 0 {
      flags = self.read_uint16()
      let symbol_index = self.read_uint16()
      if !symbol_set_mut.contains(symbol_index) {
        symbol_set_mut[symbol_index] = symbols_collection_mut.length()
        symbols_collection_mut[symbol_index] = 1
        keys_mut.push(symbol_index)
      }

      let old_position = self.file_reader.seek(0, 1)
      let (s2, c2, k2) = self.get_symbols(
        symbol_index, start, symbol_set_mut, symbols_collection_mut, keys_mut,
      )
      symbol_set_mut = s2
      symbols_collection_mut = c2
      keys_mut = k2
      self.seek(old_position)

      if (flags & symbol_words) != 0 {
        self.skip(4)
      } else {
        self.skip(2)
      }
      if (flags & symbol_scale) != 0 {
        self.skip(2)
      } else if (flags & symbol_all_scale) != 0 {
        self.skip(4)
      } else if (flags & symbol_2x2) != 0 {
        self.skip(8)
      }
    }
    return (symbol_set_mut, symbols_collection_mut, keys_mut)
  }

  (symbol_set, symbols_collection, symbols_collection_keys)
}

///|
fn Utf8FontFile::parse_symbols(
  self : Utf8FontFile,
  used_runes : Map[Int, Int],
) -> (Map[Int, Int], Map[Int, Int], Map[Int, Int], Array[Int]) {
  let symbol_collection : Map[Int, Int] = { 0: 0 }
  let char_symbol_pair_collection : Map[Int, Int] = {}
  for _, ch in used_runes {
    match self.char_symbol_dictionary.get(ch) {
      Some(symbol) => {
        symbol_collection[symbol] = ch
        char_symbol_pair_collection[ch] = symbol
      }
      None => ()
    }
    self.last_rune = max_int(self.last_rune, ch)
  }

  let begin = self.table_descriptions.get("glyf").unwrap().position
  let symbol_array : Map[Int, Int] = {}
  let symbol_collection_keys = key_sort_int_map_int(symbol_collection)

  let mut symbol_counter = 0
  let mut max_rune = 0
  for old_symbol_index in symbol_collection_keys {
    max_rune = max_int(max_rune, symbol_collection[old_symbol_index])
    symbol_array[old_symbol_index] = symbol_counter
    symbol_counter = symbol_counter + 1
  }

  let char_symbol_pair_collection_keys = key_sort_int_map_int(
    char_symbol_pair_collection,
  )
  let rune_symbol_pair_collection : Map[Int, Int] = {}
  for runa in char_symbol_pair_collection_keys {
    rune_symbol_pair_collection[runa] = symbol_array[char_symbol_pair_collection[runa]]
  }
  self.code_symbol_dictionary = rune_symbol_pair_collection

  let mut symbol_set = symbol_array
  let mut collection = symbol_collection
  let mut keys = key_sort_int_map_int(collection)
  for old_symbol_index in keys {
    let (s2, c2, k2) = self.get_symbols(
      old_symbol_index, begin, symbol_set, collection, keys,
    )
    symbol_set = s2
    collection = c2
    keys = k2
  }

  (rune_symbol_pair_collection, symbol_set, collection, keys)
}

///|
fn Utf8FontFile::generate_cmap_table(
  _self : Utf8FontFile,
  cid_symbol_pair_collection : Map[Int, Int],
  _num_symbols : Int,
) -> Array[Byte] {
  let cid_symbol_pair_collection_keys = key_sort_int_map_int(
    cid_symbol_pair_collection,
  )
  let mut cid_id = 0
  let cid_array : Map[Int, Array[Int]] = {}
  let mut prev_cid = -2
  let mut prev_symbol = -1

  for cid in cid_symbol_pair_collection_keys {
    if cid == prev_cid + 1 && cid_symbol_pair_collection[cid] == prev_symbol + 1 {
      let arr = cid_array.get_or_default(cid_id, [])
      arr.push(cid_symbol_pair_collection[cid])
      cid_array[cid_id] = arr
    } else {
      cid_id = cid
      let arr : Array[Int] = [cid_symbol_pair_collection[cid]]
      cid_array[cid_id] = arr
    }
    prev_cid = cid
    prev_symbol = cid_symbol_pair_collection[cid]
  }

  let cid_array_keys = key_sort_int_map_array(cid_array)
  let seg_count = cid_array.length() + 1

  let mut search_range = 1
  let mut entry_selector = 0
  while search_range * 2 <= seg_count {
    search_range = search_range * 2
    entry_selector = entry_selector + 1
  }
  search_range = search_range * 2
  let range_shift = seg_count * 2 - search_range

  let data : Array[Int] = [0, 1, 3, 1, 0, 12, 4]

  let cmap : Array[Int] = [
    seg_count * 2,
    search_range,
    entry_selector,
    range_shift,
  ]
  for start in cid_array_keys {
    let end_code = start + (cid_array[start].length() - 1)
    cmap.push(end_code)
  }
  cmap.push(0xFFFF)
  cmap.push(0)

  cmap.append(cid_array_keys)
  cmap.push(0xFFFF)

  for cid_key in cid_array_keys {
    let id_delta = -(cid_key - cid_array[cid_key][0])
    cmap.push(id_delta)
  }
  cmap.push(1)

  for _k, _v in cid_array {
    cmap.push(0)
  }
  cmap.push(0)

  for start in cid_array_keys {
    cmap.append(cid_array[start])
  }
  cmap.push(0)

  let length = (3 + cmap.length()) * 2
  data.push(length)
  data.push(0)
  data.append(cmap)

  let cmapstr : Array[Byte] = []
  for cm in data {
    cmapstr.append(pack_uint16(cm))
  }
  cmapstr
}

///|
fn Utf8FontFile::parse_hmtx_table(
  self : Utf8FontFile,
  number_of_h_metrics : Int,
  num_symbols : Int,
  symbol_to_char : Map[Int, Array[Int]],
  scale : Double,
) -> Unit {
  let start = self.seek_table_start("hmtx")
  let mut array_widths = 0
  self.char_widths = []
  for _ in 0..<(256 * 256) {
    self.char_widths.push(0)
  }
  let mut char_count = 0

  let arr = unpack_uint16_array(self.get_range(start, number_of_h_metrics * 4))

  for symbol in 0..<number_of_h_metrics {
    array_widths = arr[symbol * 2 + 1]
    if symbol_to_char.contains(symbol) || symbol == 0 {
      if array_widths >= 1 << 15 {
        array_widths = 0
      }
      if symbol == 0 {
        self.default_width = scale * array_widths.to_double()
        continue
      }
      for ch in symbol_to_char.get_or_default(symbol, []) {
        if ch != 0 && ch != 65535 {
          let mut widths = (scale * array_widths.to_double()).round().to_int()
          if widths == 0 {
            widths = 65535
          }
          if ch < 196608 {
            self.char_widths[ch] = widths
            char_count = char_count + 1
          }
        }
      }
    }
  }

  let diff = num_symbols - number_of_h_metrics
  for pos in 0..<diff {
    let symbol = pos + number_of_h_metrics
    if symbol_to_char.contains(symbol) {
      for ch in symbol_to_char.get_or_default(symbol, []) {
        if ch != 0 && ch != 65535 {
          let mut widths = (scale * array_widths.to_double()).round().to_int()
          if widths == 0 {
            widths = 65535
          }
          if ch < 196608 {
            self.char_widths[ch] = widths
            char_count = char_count + 1
          }
        }
      }
    }
  }

  self.char_widths[0] = char_count
}

///|
fn Utf8FontFile::get_metrics(
  self : Utf8FontFile,
  metric_count : Int,
  gid : Int,
) -> Array[Byte] {
  let start = self.seek_table_start("hmtx")
  if gid < metric_count {
    self.seek(start + gid * 4)
    self.file_reader.read(4)
  } else {
    self.seek(start + (metric_count - 1) * 4)
    let metrics = self.file_reader.read(2)
    self.seek(start + metric_count * 2 + gid * 2)
    metrics.append(self.file_reader.read(2))
    metrics
  }
}

///|
fn Utf8FontFile::parse_loca_table(
  self : Utf8FontFile,
  format : Int,
  num_symbols : Int,
) -> Unit {
  let start = self.seek_table_start("loca")
  self.symbol_position = []
  if format == 0 {
    let data = self.get_range(start, num_symbols * 2 + 2)
    let arr = unpack_uint16_array(data)
    for n in 0..<=num_symbols {
      self.symbol_position.push(arr[n + 1] * 2)
    }
  } else if format == 1 {
    let data = self.get_range(start, num_symbols * 4 + 4)
    let arr = unpack_uint32_array(data)
    for n in 0..<=num_symbols {
      self.symbol_position.push(arr[n + 1])
    }
  }
}

///|
fn Utf8FontFile::assemble_tables(self : Utf8FontFile) -> Array[Byte] {
  let answer : Array[Byte] = []
  let tables_count = self.out_tables_data.length()
  let mut find_size = 1
  let mut writer = 0
  while find_size * 2 <= tables_count {
    find_size = find_size * 2
    writer = writer + 1
  }
  find_size = find_size * 16
  let r_offset = tables_count * 16 - find_size

  answer.append(
    pack_header(0x00010000, tables_count, find_size, writer, r_offset),
  )

  let tables_names = key_sort_strings_map_bytes(self.out_tables_data)

  let mut offset = 12 + tables_count * 16
  let mut begin = 0

  for name in tables_names {
    if name == "head" {
      begin = offset
    }
    let name_bs = @utf8.encode(name[:]).to_array()
    answer.append(name_bs)

    let (sum_hi, sum_lo) = self.generate_checksum(self.out_tables_data[name])
    answer.append(pack2_uint16(sum_hi, sum_lo))
    answer.append(pack2_uint32(offset, self.out_tables_data[name].length()))

    let padded_length = align4(self.out_tables_data[name].length())
    offset = offset + padded_length
  }

  for key in tables_names {
    let data = self.out_tables_data[key].copy()
    data.append([b'\x00', b'\x00', b'\x00'])
    let padded = data.length() / 4 * 4
    answer.append(data[0:padded].to_array())
  }

  let (sum_hi, sum_lo) = self.generate_checksum(answer)
  let (adj_hi, adj_lo) = self.calc_int32(0xB1B0, 0xAFBA, sum_hi, sum_lo)
  let replacement = pack2_uint16(adj_hi, adj_lo)
  let patched = splice_bytes(answer, begin + 8, replacement)
  patched
}

///|
fn Utf8FontFile::generate_cut_font(
  self : Utf8FontFile,
  used_runes : Map[Int, Int],
) -> Array[Byte]? {
  self.file_reader.reader_position = 0
  self.symbol_position = []
  self.char_symbol_dictionary = {}
  self.table_descriptions = {}
  self.out_tables_data = {}
  self.ascent = 0
  self.descent = 0
  self.skip(4)
  self.last_rune = 0
  self.generate_table_descriptions()

  ignore(self.seek_table_start("head"))
  self.skip(50)
  let mut loca_format = self.read_uint16()

  ignore(self.seek_table_start("hhea"))
  self.skip(34)
  let mut metrics_count = self.read_uint16()
  let old_metrics = metrics_count

  ignore(self.seek_table_start("maxp"))
  self.skip(4)
  let mut num_symbols = self.read_uint16()

  let symbol_char_dictionary = match self.generate_cmap() {
    Some(v) => v
    None => return None
  }

  self.parse_hmtx_table(metrics_count, num_symbols, symbol_char_dictionary, 1.0)
  self.parse_loca_table(loca_format, num_symbols)

  let (
    cid_symbol_pair_collection,
    symbol_array,
    symbol_collection,
    symbol_collection_keys,
  ) = self.parse_symbols(used_runes)

  metrics_count = symbol_collection.length()
  num_symbols = metrics_count

  self.set_out_table("name", self.get_table_data("name"))
  self.set_out_table("cvt ", self.get_table_data("cvt "))
  self.set_out_table("fpgm", self.get_table_data("fpgm"))
  self.set_out_table("prep", self.get_table_data("prep"))
  self.set_out_table("gasp", self.get_table_data("gasp"))

  match self.get_table_data("post") {
    None => ()
    Some(post_table0) => {
      let post_table : Array[Byte] = [b'\x00', b'\x03', b'\x00', b'\x00']
      post_table.append(post_table0[4:16].to_array())
      post_table.append([
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      ])
      self.set_out_table("post", Some(post_table))
    }
  }

  let cid_no_zero : Map[Int, Int] = {}
  for k, v in cid_symbol_pair_collection {
    if k != 0 {
      cid_no_zero[k] = v
    }
  }
  self.set_out_table(
    "cmap",
    Some(self.generate_cmap_table(cid_no_zero, num_symbols)),
  )

  let symbol_data = match self.get_table_data("glyf") {
    Some(v) => v
    None => return None
  }

  let offsets : Array[Int] = []
  let glyf_data : Array[Byte] = []
  let mut pos = 0
  let hmtx_data : Array[Byte] = []
  self.symbol_data = {}

  for original_symbol_idx in symbol_collection_keys {
    let hm = self.get_metrics(old_metrics, original_symbol_idx)
    hmtx_data.append(hm)

    offsets.push(pos)
    let symbol_pos = self.symbol_position[original_symbol_idx]
    let symbol_len = self.symbol_position[original_symbol_idx + 1] - symbol_pos
    let mut data = symbol_data[symbol_pos:symbol_pos + symbol_len].to_array()
    let mut up = 0
    if symbol_len > 0 {
      up = unpack_uint16(data[0:2].to_array())
    }

    if symbol_len > 2 && (up & (1 << 15)) != 0 {
      let mut pos_in_symbol = 10
      let mut flags = symbol_continue
      while (flags & symbol_continue) != 0 {
        up = unpack_uint16(data[pos_in_symbol:pos_in_symbol + 2].to_array())
        flags = up
        up = unpack_uint16(data[pos_in_symbol + 2:pos_in_symbol + 4].to_array())
        let symbol_idx = up

        let x0 = self.symbol_data.get_or_default(original_symbol_idx, {})
        let arr = x0.get_or_default("compSymbols", [])
        arr.push(symbol_idx)
        x0["compSymbols"] = arr
        self.symbol_data[original_symbol_idx] = x0

        data = self.insert_uint16(
          data,
          pos_in_symbol + 2,
          symbol_array[symbol_idx],
        )

        pos_in_symbol = pos_in_symbol + 4
        if (flags & symbol_words) != 0 {
          pos_in_symbol = pos_in_symbol + 4
        } else {
          pos_in_symbol = pos_in_symbol + 2
        }
        if (flags & symbol_scale) != 0 {
          pos_in_symbol = pos_in_symbol + 2
        } else if (flags & symbol_all_scale) != 0 {
          pos_in_symbol = pos_in_symbol + 4
        } else if (flags & symbol_2x2) != 0 {
          pos_in_symbol = pos_in_symbol + 8
        }
      }
    }

    glyf_data.append(data)
    pos = pos + symbol_len
    if pos % 4 != 0 {
      let padding = 4 - pos % 4
      for _ in 0..<padding {
        glyf_data.push(b'\x00')
      }
      pos = pos + padding
    }
  }

  offsets.push(pos)
  self.set_out_table("glyf", Some(glyf_data))
  self.set_out_table("hmtx", Some(hmtx_data))

  let loca_data : Array[Byte] = []
  if (pos + 1) >> 1 > 0xFFFF {
    loca_format = 1
    for offset in offsets {
      loca_data.append(pack_uint32(offset))
    }
  } else {
    loca_format = 0
    for offset in offsets {
      loca_data.append(pack_uint16(offset / 2))
    }
  }
  self.set_out_table("loca", Some(loca_data))

  let head_data0 = self.get_table_data("head").unwrap()
  let head_data = self.insert_uint16(head_data0, 50, loca_format)
  self.set_out_table("head", Some(head_data))

  let hhea_data0 = self.get_table_data("hhea").unwrap()
  let hhea_data = self.insert_uint16(hhea_data0, 34, metrics_count)
  self.set_out_table("hhea", Some(hhea_data))

  let maxp0 = self.get_table_data("maxp").unwrap()
  let maxp = self.insert_uint16(maxp0, 4, num_symbols)
  self.set_out_table("maxp", Some(maxp))

  self.set_out_table("OS/2", self.get_table_data("OS/2"))

  Some(self.assemble_tables())
}

///|
fn decode_utf8_codepoints(s : String) -> Array[Int] {
  let bytes = @utf8.encode(s[:]).to_array()
  let cps : Array[Int] = []
  let mut i = 0
  while i < bytes.length() {
    let b0 = bytes[i].to_int()
    if b0 < 0x80 {
      cps.push(b0)
      i = i + 1
    } else if (b0 & 0xE0) == 0xC0 && i + 1 < bytes.length() {
      let b1 = bytes[i + 1].to_int()
      cps.push(((b0 & 0x1F) << 6) | (b1 & 0x3F))
      i = i + 2
    } else if (b0 & 0xF0) == 0xE0 && i + 2 < bytes.length() {
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      cps.push(((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F))
      i = i + 3
    } else if (b0 & 0xF8) == 0xF0 && i + 3 < bytes.length() {
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      let b3 = bytes[i + 3].to_int()
      cps.push(
        ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F),
      )
      i = i + 4
    } else {
      cps.push(0xFFFD)
      i = i + 1
    }
  }
  cps
}

///|
priv struct SfntTableEntry {
  tag : String
  tag_u32 : Int
  check_sum : Int
  offset : Int
  length : Int
}

///|
fn u32_add(a : Int, b : Int) -> Int {
  (a + b) & 0xFFFFFFFF
}

///|
fn u32_sub(a : Int, b : Int) -> Int {
  (a - b) & 0xFFFFFFFF
}

///|
fn write_u16_be_at(out : Array[Byte], at : Int, v : Int) -> Unit {
  let u = v & 0xFFFF
  out[at] = ((u >> 8) & 0xFF).to_byte()
  out[at + 1] = (u & 0xFF).to_byte()
}

///|
fn write_u32_be_at(out : Array[Byte], at : Int, v : Int) -> Unit {
  let u = v & 0xFFFFFFFF
  out[at] = ((u >> 24) & 0xFF).to_byte()
  out[at + 1] = ((u >> 16) & 0xFF).to_byte()
  out[at + 2] = ((u >> 8) & 0xFF).to_byte()
  out[at + 3] = (u & 0xFF).to_byte()
}

///|
fn sfnt_calc_checksum(buf : Array[Byte]) -> Int {
  let mut sum = 0
  let nlongs = buf.length() / 4
  let mut i = 0
  while i < nlongs {
    let t = read_u32_be(buf, i * 4)
    sum = u32_add(sum, t)
    i = i + 1
  }
  sum
}

///|
fn parse_sfnt_entries(data : Array[Byte]) -> Array[SfntTableEntry]? {
  if data.length() < 12 {
    return None
  }
  let num_tables = match safe_read_u16_be(data, 4) {
    Some(v) => v
    None => return None
  }
  if num_tables <= 0 {
    return None
  }
  let table_dir_len = 12 + num_tables * 16
  if table_dir_len > data.length() {
    return None
  }
  let entries : Array[SfntTableEntry] = []
  for i in 0..<num_tables {
    let rec = 12 + i * 16
    let tag_u32 = match safe_read_u32_be(data, rec) {
      Some(v) => v
      None => return None
    }
    let check_sum = match safe_read_u32_be(data, rec + 4) {
      Some(v) => v
      None => return None
    }
    let offset = match safe_read_u32_be(data, rec + 8) {
      Some(v) => v
      None => return None
    }
    let length = match safe_read_u32_be(data, rec + 12) {
      Some(v) => v
      None => return None
    }
    if offset < 0 ||
      length < 0 ||
      offset > data.length() ||
      length > data.length() - offset {
      return None
    }
    let tag = bytes4_to_string(data[rec:rec + 4].to_array())
    entries.push({ tag, tag_u32, check_sum, offset, length })
  }
  Some(entries)
}

///|
fn sort_sfnt_entries(entries : Array[SfntTableEntry]) -> Array[SfntTableEntry] {
  let sorted = entries.copy()
  let mut i = 1
  while i < sorted.length() {
    let cur = sorted[i]
    let mut j = i - 1
    while j >= 0 && sorted[j].tag > cur.tag {
      sorted[j + 1] = sorted[j]
      j = j - 1
    }
    sorted[j + 1] = cur
    i = i + 1
  }
  sorted
}

///|
fn sfnt_table_data(data : Array[Byte], entry : SfntTableEntry) -> Array[Byte]? {
  if entry.offset < 0 ||
    entry.length < 0 ||
    entry.offset > data.length() ||
    entry.length > data.length() - entry.offset {
    return None
  }
  Some(data[entry.offset:entry.offset + entry.length].to_array())
}

///|
fn sfnt_aligned_table_for_checksum(
  data : Array[Byte],
  entry : SfntTableEntry,
) -> Array[Byte]? {
  let aligned = align4(entry.length)
  if entry.offset < 0 ||
    entry.length < 0 ||
    entry.offset > data.length() ||
    entry.length > data.length() - entry.offset {
    return None
  }
  if entry.offset + aligned <= data.length() {
    return Some(data[entry.offset:entry.offset + aligned].to_array())
  }
  let padded = data[entry.offset:entry.offset + entry.length].to_array()
  while padded.length() < aligned {
    padded.push(b'\x00')
  }
  Some(padded)
}

///|
fn compress_zlib_default(data : Array[Byte]) -> Array[Byte]? {
  let compressed = @moon_yazi.compress(
    Bytes::from_array(data[:]),
    @moon_yazi.Format::Zlib,
    @moon_yazi.CompressionLevel::Default,
  ) catch {
    _ => return None
  }
  Some(compressed)
}

///|
pub fn sfnt_to_woff(in_buf : Bytes) -> Bytes? {
  let data = in_buf.to_array()
  let entries = match parse_sfnt_entries(data) {
    Some(v) => v
    None => return None
  }
  let sorted_entries = sort_sfnt_entries(entries)
  if sorted_entries.length() == 0 {
    return None
  }

  for entry in sorted_entries {
    if entry.tag == "head" {
      continue
    }
    let aligned = match sfnt_aligned_table_for_checksum(data, entry) {
      Some(v) => v
      None => return None
    }
    if sfnt_calc_checksum(aligned) != entry.check_sum {
      return None
    }
  }

  let mut sfnt_size = (12 + sorted_entries.length() * 16) & 0xFFFFFFFF
  for entry in sorted_entries {
    sfnt_size = u32_add(sfnt_size, align4(entry.length))
  }

  let mut csum = sfnt_calc_checksum(data[0:12].to_array())
  let mut sfnt_offset = 12 + sorted_entries.length() * 16
  for entry in sorted_entries {
    let dir_entry : Array[Byte] = []
    write_u32_be(dir_entry, entry.tag_u32)
    write_u32_be(dir_entry, entry.check_sum)
    write_u32_be(dir_entry, sfnt_offset)
    write_u32_be(dir_entry, entry.length)
    csum = u32_add(csum, sfnt_calc_checksum(dir_entry))
    csum = u32_add(csum, entry.check_sum)
    sfnt_offset = sfnt_offset + align4(entry.length)
  }
  let checksum_adjustment = u32_sub(0xB1B0AFBA, csum)

  let woff_header = Array::make(44, b'\x00')
  let table_info = Array::make(sorted_entries.length() * 20, b'\x00')
  let table_bytes : Array[Byte] = []

  let mut major_version = 0
  let mut minor_version = 1
  let mut flavor = 0
  let mut offset = 44 + sorted_entries.length() * 20
  for i = 0; i < sorted_entries.length(); i = i + 1 {
    let entry = sorted_entries[i]
    let sfnt_data = match sfnt_table_data(data, entry) {
      Some(v) => v
      None => return None
    }
    if entry.tag == "head" {
      if sfnt_data.length() < 12 {
        return None
      }
      major_version = read_u16_be(sfnt_data, 4)
      minor_version = read_u16_be(sfnt_data, 6)
      flavor = read_u32_be(sfnt_data, 0)
      write_u32_be_at(sfnt_data, 8, checksum_adjustment)
    }

    let compressed = match compress_zlib_default(sfnt_data) {
      Some(v) => v
      None => return None
    }
    let use_compressed = compressed.length() < sfnt_data.length()
    let comp_length = if use_compressed {
      compressed.length()
    } else {
      sfnt_data.length()
    }
    let aligned_length = align4(comp_length)
    let table = Array::make(aligned_length, b'\x00')
    if use_compressed {
      for j = 0; j < compressed.length(); j = j + 1 {
        table[j] = compressed[j]
      }
    } else {
      for j = 0; j < sfnt_data.length(); j = j + 1 {
        table[j] = sfnt_data[j]
      }
    }

    let rec = i * 20
    write_u32_be_at(table_info, rec + 0, entry.tag_u32)
    write_u32_be_at(table_info, rec + 4, offset)
    write_u32_be_at(table_info, rec + 8, comp_length)
    write_u32_be_at(table_info, rec + 12, entry.length)
    write_u32_be_at(table_info, rec + 16, entry.check_sum)
    table_bytes.append(table)
    offset = offset + table.length()
  }

  let woff_size = 44 + table_info.length() + table_bytes.length()
  write_u32_be_at(woff_header, 0, 0x774F4646)
  write_u32_be_at(woff_header, 4, flavor)
  write_u32_be_at(woff_header, 8, woff_size)
  write_u16_be_at(woff_header, 12, sorted_entries.length())
  write_u16_be_at(woff_header, 14, 0)
  write_u32_be_at(woff_header, 16, sfnt_size)
  write_u16_be_at(woff_header, 20, major_version)
  write_u16_be_at(woff_header, 22, minor_version)
  write_u32_be_at(woff_header, 24, 0)
  write_u32_be_at(woff_header, 28, 0)
  write_u32_be_at(woff_header, 32, 0)
  write_u32_be_at(woff_header, 36, 0)
  write_u32_be_at(woff_header, 40, 0)

  let out : Array[Byte] = []
  out.append(woff_header)
  out.append(table_info)
  out.append(table_bytes)
  Some(Bytes::from_array(out[:]))
}

///|
pub fn utf8_cut_font(in_buf : Bytes, cutset : String) -> Bytes? {
  if in_buf.length() == 0 {
    return None
  }
  let input = in_buf.to_array()
  if !is_plausible_sfnt(input) {
    return None
  }
  let runes : Map[Int, Int] = {}
  let cps = decode_utf8_codepoints(cutset)
  for i, cp in cps {
    runes[i] = cp
  }
  let reader = FileReader::{ reader_position: 0, array: input }
  let font = new_utf8_font(reader)
  match font.generate_cut_font(runes) {
    Some(out) => Some(Bytes::from_array(out[:]))
    None => None
  }
}
