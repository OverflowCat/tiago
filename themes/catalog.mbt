///|
/// Built-in Theme Catalog
///
/// Contains all predefined D2 themes.

///|
/// Get a theme by ID
pub fn get_theme(id : Int) -> Theme {
  match id {
    0 => neutral_default()
    1 => neutral_grey()
    3 => flagship_terrastruct()
    4 => cool_classics()
    5 => mixed_berry_blue()
    6 => grape_soda()
    7 => aubergine()
    8 => colorblind_clear()
    100 => vanilla_nitro_cola()
    101 => orange_creamsicle()
    102 => shirley_temple()
    103 => earth_tones()
    104 => everglade_green()
    105 => buttered_toast()
    200 => dark_mauve()
    201 => dark_flagship()
    300 => terminal()
    301 => terminal_grayscale()
    302 => origami()
    _ => neutral_default()
  }
}

///|
/// Get theme by name (case-insensitive)
pub fn get_theme_by_name(name : String) -> Theme {
  let lower = name.to_lower()
  if lower.contains("dark") {
    if lower.contains("mauve") {
      return dark_mauve()
    }
    return dark_flagship()
  }
  if lower.contains("terminal") {
    if lower.contains("gray") {
      return terminal_grayscale()
    }
    return terminal()
  }
  if lower.contains("origami") {
    return origami()
  }
  if lower.contains("flagship") {
    return flagship_terrastruct()
  }
  if lower.contains("cool") {
    return cool_classics()
  }
  if lower.contains("berry") {
    return mixed_berry_blue()
  }
  if lower.contains("grape") {
    return grape_soda()
  }
  if lower.contains("aubergine") {
    return aubergine()
  }
  if lower.contains("colorblind") {
    return colorblind_clear()
  }
  if lower.contains("vanilla") {
    return vanilla_nitro_cola()
  }
  if lower.contains("orange") {
    return orange_creamsicle()
  }
  if lower.contains("shirley") {
    return shirley_temple()
  }
  if lower.contains("earth") {
    return earth_tones()
  }
  if lower.contains("everglade") {
    return everglade_green()
  }
  if lower.contains("toast") {
    return buttered_toast()
  }
  if lower.contains("grey") || lower.contains("gray") {
    return neutral_grey()
  }
  neutral_default()
}

///|
/// List all available theme names
pub fn list_themes() -> Array[String] {
  [
    "Neutral Default", "Neutral Grey", "Flagship Terrastruct", "Cool Classics", "Mixed Berry Blue",
    "Grape Soda", "Aubergine", "Colorblind Clear", "Vanilla Nitro Cola", "Orange Creamsicle",
    "Shirley Temple", "Earth Tones", "Everglade Green", "Buttered Toast", "Dark Mauve",
    "Dark Flagship", "Terminal", "Terminal Grayscale", "Origami",
  ]
}

// =============================================================================
// Light Themes
// =============================================================================

///|
fn neutral_default() -> Theme {
  {
    id: 0,
    name: "Neutral Default",
    colors: {
      n1: "#0A0F25",
      n2: "#676C7E",
      n3: "#9499AB",
      n4: "#CFD2DD",
      n5: "#DEE1EB",
      n6: "#EEF1F8",
      n7: "#FFFFFF",
      b1: "#0D32B2",
      b2: "#0D32B2",
      b3: "#E3E9FD",
      b4: "#E3E9FD",
      b5: "#EDF0FD",
      b6: "#F7F8FE",
      aa2: "#4A6FF3",
      aa4: "#EDF0FD",
      aa5: "#F7F8FE",
      ab4: "#EDF0FD",
      ab5: "#F7F8FE",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn neutral_grey() -> Theme {
  {
    id: 1,
    name: "Neutral Grey",
    colors: {
      n1: "#170206",
      n2: "#535358",
      n3: "#787882",
      n4: "#ACAEB6",
      n5: "#C4C6CD",
      n6: "#E8E9ED",
      n7: "#FFFFFF",
      b1: "#4D4D4D",
      b2: "#4D4D4D",
      b3: "#E8E8E8",
      b4: "#E8E8E8",
      b5: "#F2F2F2",
      b6: "#F9F9F9",
      aa2: "#808080",
      aa4: "#F2F2F2",
      aa5: "#F9F9F9",
      ab4: "#F2F2F2",
      ab5: "#F9F9F9",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn flagship_terrastruct() -> Theme {
  {
    id: 3,
    name: "Flagship Terrastruct",
    colors: {
      n1: "#0A0F25",
      n2: "#676C7E",
      n3: "#9499AB",
      n4: "#CFD2DD",
      n5: "#DEE1EB",
      n6: "#EEF1F8",
      n7: "#FFFFFF",
      b1: "#0D32B2",
      b2: "#0D32B2",
      b3: "#E3E9FD",
      b4: "#E3E9FD",
      b5: "#EDF0FD",
      b6: "#F7F8FE",
      aa2: "#F25E02",
      aa4: "#FEF0E6",
      aa5: "#FFF8F3",
      ab4: "#ECFDF2",
      ab5: "#F5FDF8",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn cool_classics() -> Theme {
  {
    id: 4,
    name: "Cool Classics",
    colors: {
      n1: "#0B102B",
      n2: "#535972",
      n3: "#8F95A8",
      n4: "#CACDD8",
      n5: "#E4E6EC",
      n6: "#F2F3F6",
      n7: "#FFFFFF",
      b1: "#094374",
      b2: "#094374",
      b3: "#CADEF0",
      b4: "#CADEF0",
      b5: "#E7F0F8",
      b6: "#F5F9FC",
      aa2: "#147C3E",
      aa4: "#DCF5E4",
      aa5: "#F0FAF3",
      ab4: "#FAE7D4",
      ab5: "#FDF4ED",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn mixed_berry_blue() -> Theme {
  {
    id: 5,
    name: "Mixed Berry Blue",
    colors: {
      n1: "#12022F",
      n2: "#5C5180",
      n3: "#9188B0",
      n4: "#C5BFD9",
      n5: "#DBD6EB",
      n6: "#F0EDF7",
      n7: "#FFFFFF",
      b1: "#4F27B3",
      b2: "#4F27B3",
      b3: "#E2D9FA",
      b4: "#E2D9FA",
      b5: "#EFEBFC",
      b6: "#F9F7FE",
      aa2: "#A626A6",
      aa4: "#F9DEFA",
      aa5: "#FCEEFD",
      ab4: "#D2F3F9",
      ab5: "#EBF9FC",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn grape_soda() -> Theme {
  {
    id: 6,
    name: "Grape Soda",
    colors: {
      n1: "#1F0726",
      n2: "#644C6B",
      n3: "#98839D",
      n4: "#C9BECE",
      n5: "#DED6E1",
      n6: "#F1EDF2",
      n7: "#FFFFFF",
      b1: "#7B24A4",
      b2: "#7B24A4",
      b3: "#EED6FA",
      b4: "#EED6FA",
      b5: "#F7ECFD",
      b6: "#FCF7FE",
      aa2: "#CB2A5F",
      aa4: "#FAD6E4",
      aa5: "#FDECF2",
      ab4: "#C9F4E5",
      ab5: "#E7FAF3",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn aubergine() -> Theme {
  {
    id: 7,
    name: "Aubergine",
    colors: {
      n1: "#260619",
      n2: "#6B4C61",
      n3: "#9D8395",
      n4: "#CDBEC8",
      n5: "#E0D5DC",
      n6: "#F2EEEF",
      n7: "#FFFFFF",
      b1: "#9E2362",
      b2: "#9E2362",
      b3: "#F5D1E4",
      b4: "#F5D1E4",
      b5: "#FAE9F2",
      b6: "#FDF6F9",
      aa2: "#0C6E5A",
      aa4: "#CDF1E9",
      aa5: "#E8F9F5",
      ab4: "#F9E9CF",
      ab5: "#FCF4E9",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn colorblind_clear() -> Theme {
  {
    id: 8,
    name: "Colorblind Clear",
    colors: {
      n1: "#000000",
      n2: "#4D4D4D",
      n3: "#808080",
      n4: "#B3B3B3",
      n5: "#CCCCCC",
      n6: "#E6E6E6",
      n7: "#FFFFFF",
      b1: "#003366",
      b2: "#003366",
      b3: "#CCE0F5",
      b4: "#CCE0F5",
      b5: "#E6F0FA",
      b6: "#F5F9FD",
      aa2: "#CC6600",
      aa4: "#FFE6CC",
      aa5: "#FFF3E6",
      ab4: "#FFFFCC",
      ab5: "#FFFFE6",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn vanilla_nitro_cola() -> Theme {
  {
    id: 100,
    name: "Vanilla Nitro Cola",
    colors: {
      n1: "#170206",
      n2: "#5A4A4D",
      n3: "#8F8183",
      n4: "#C4B8BA",
      n5: "#DAD1D2",
      n6: "#F0ECED",
      n7: "#FFFFFF",
      b1: "#A41114",
      b2: "#A41114",
      b3: "#F8D0D0",
      b4: "#F8D0D0",
      b5: "#FCE9E9",
      b6: "#FEF5F5",
      aa2: "#714C11",
      aa4: "#F7E8D1",
      aa5: "#FBF4EA",
      ab4: "#E0F4F1",
      ab5: "#F2FAF8",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn orange_creamsicle() -> Theme {
  {
    id: 101,
    name: "Orange Creamsicle",
    colors: {
      n1: "#1A0E00",
      n2: "#5E4D3A",
      n3: "#928470",
      n4: "#C6BBAB",
      n5: "#DCD5C8",
      n6: "#F1EDE6",
      n7: "#FFFFFF",
      b1: "#B84705",
      b2: "#B84705",
      b3: "#FADAC5",
      b4: "#FADAC5",
      b5: "#FDEEE4",
      b6: "#FEF7F3",
      aa2: "#7A5E12",
      aa4: "#F4EAD0",
      aa5: "#FAF5EA",
      ab4: "#DDF0E7",
      ab5: "#F0F8F4",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn shirley_temple() -> Theme {
  {
    id: 102,
    name: "Shirley Temple",
    colors: {
      n1: "#200208",
      n2: "#5F484F",
      n3: "#937F85",
      n4: "#C6B7BB",
      n5: "#DDD1D4",
      n6: "#F2ECEE",
      n7: "#FFFFFF",
      b1: "#C91D4D",
      b2: "#C91D4D",
      b3: "#FAD2DD",
      b4: "#FAD2DD",
      b5: "#FDEBF0",
      b6: "#FEF6F8",
      aa2: "#127454",
      aa4: "#D0EFE5",
      aa5: "#EAF7F3",
      ab4: "#F3F2DA",
      ab5: "#F9F9EE",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn earth_tones() -> Theme {
  {
    id: 103,
    name: "Earth Tones",
    colors: {
      n1: "#150E09",
      n2: "#564C45",
      n3: "#8A827A",
      n4: "#BEB7B0",
      n5: "#D6D1CC",
      n6: "#EEEBE9",
      n7: "#FFFFFF",
      b1: "#6D4826",
      b2: "#6D4826",
      b3: "#E8D7C8",
      b4: "#E8D7C8",
      b5: "#F4EDE6",
      b6: "#FAF7F4",
      aa2: "#3B7341",
      aa4: "#D6EED8",
      aa5: "#ECF7ED",
      ab4: "#E9E2D2",
      ab5: "#F4F1EA",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn everglade_green() -> Theme {
  {
    id: 104,
    name: "Everglade Green",
    colors: {
      n1: "#041408",
      n2: "#435749",
      n3: "#788E7E",
      n4: "#AFC3B4",
      n5: "#CDDBD0",
      n6: "#E9F0EA",
      n7: "#FFFFFF",
      b1: "#155A27",
      b2: "#155A27",
      b3: "#CAEAD1",
      b4: "#CAEAD1",
      b5: "#E6F5E9",
      b6: "#F4FAF5",
      aa2: "#0D606C",
      aa4: "#CFF0F4",
      aa5: "#E9F8FA",
      ab4: "#E0E5D4",
      ab5: "#F1F3EB",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

///|
fn buttered_toast() -> Theme {
  {
    id: 105,
    name: "Buttered Toast",
    colors: {
      n1: "#1C1400",
      n2: "#5C5541",
      n3: "#8F8976",
      n4: "#C2BDAE",
      n5: "#D9D6CB",
      n6: "#EFEDE7",
      n7: "#FFFFFF",
      b1: "#997408",
      b2: "#997408",
      b3: "#F3E6C1",
      b4: "#F3E6C1",
      b5: "#F9F3E2",
      b6: "#FDFAF3",
      aa2: "#0F6E74",
      aa4: "#CEF1F4",
      aa5: "#E9F8FA",
      ab4: "#F4E5D6",
      ab5: "#FAF3EC",
    },
    rules: SpecialRules::default(),
    is_dark: false,
  }
}

// =============================================================================
// Dark Themes
// =============================================================================

///|
fn dark_mauve() -> Theme {
  {
    id: 200,
    name: "Dark Mauve",
    colors: {
      n1: "#FFFFFF",
      n2: "#DED7DD",
      n3: "#B6ACB4",
      n4: "#7D6F7A",
      n5: "#57495F",
      n6: "#2A2038",
      n7: "#120C1B",
      b1: "#9D70C6",
      b2: "#9D70C6",
      b3: "#332245",
      b4: "#332245",
      b5: "#22172E",
      b6: "#120C1B",
      aa2: "#D38AD3",
      aa4: "#2B2230",
      aa5: "#211929",
      ab4: "#1E3A2F",
      ab5: "#162E24",
    },
    rules: SpecialRules::default(),
    is_dark: true,
  }
}

///|
fn dark_flagship() -> Theme {
  {
    id: 201,
    name: "Dark Flagship",
    colors: {
      n1: "#FFFFFF",
      n2: "#D5D7E2",
      n3: "#ABB0C4",
      n4: "#696F8C",
      n5: "#4B4D64",
      n6: "#1F2038",
      n7: "#0D0E19",
      b1: "#5F7AE4",
      b2: "#5F7AE4",
      b3: "#283052",
      b4: "#283052",
      b5: "#1A1F38",
      b6: "#0D0E19",
      aa2: "#F77449",
      aa4: "#382318",
      aa5: "#2D1C14",
      ab4: "#1A372C",
      ab5: "#142D23",
    },
    rules: SpecialRules::default(),
    is_dark: true,
  }
}

// =============================================================================
// Special Themes
// =============================================================================

///|
fn terminal() -> Theme {
  {
    id: 300,
    name: "Terminal",
    colors: {
      n1: "#01F701",
      n2: "#01D901",
      n3: "#01BB01",
      n4: "#019D01",
      n5: "#017F01",
      n6: "#006100",
      n7: "#001900",
      b1: "#01F701",
      b2: "#01F701",
      b3: "#003900",
      b4: "#003900",
      b5: "#002500",
      b6: "#001900",
      aa2: "#01F701",
      aa4: "#003900",
      aa5: "#002500",
      ab4: "#003900",
      ab5: "#002500",
    },
    rules: {
      mono: true,
      no_corner_radius: true,
      outer_container_double_border: true,
      container_dots: true,
      caps_lock: true,
      all_paper: false,
    },
    is_dark: true,
  }
}

///|
fn terminal_grayscale() -> Theme {
  {
    id: 301,
    name: "Terminal Grayscale",
    colors: {
      n1: "#F5F5F5",
      n2: "#D7D7D7",
      n3: "#B9B9B9",
      n4: "#9B9B9B",
      n5: "#7D7D7D",
      n6: "#5F5F5F",
      n7: "#1A1A1A",
      b1: "#F5F5F5",
      b2: "#F5F5F5",
      b3: "#3C3C3C",
      b4: "#3C3C3C",
      b5: "#2A2A2A",
      b6: "#1A1A1A",
      aa2: "#F5F5F5",
      aa4: "#3C3C3C",
      aa5: "#2A2A2A",
      ab4: "#3C3C3C",
      ab5: "#2A2A2A",
    },
    rules: {
      mono: true,
      no_corner_radius: true,
      outer_container_double_border: true,
      container_dots: true,
      caps_lock: true,
      all_paper: false,
    },
    is_dark: true,
  }
}

///|
fn origami() -> Theme {
  {
    id: 302,
    name: "Origami",
    colors: {
      n1: "#1A1A1A",
      n2: "#525252",
      n3: "#858585",
      n4: "#B8B8B8",
      n5: "#D4D4D4",
      n6: "#EDEDED",
      n7: "#FFFFFF",
      b1: "#4A4A4A",
      b2: "#4A4A4A",
      b3: "#EBEBEB",
      b4: "#EBEBEB",
      b5: "#F3F3F3",
      b6: "#FAFAFA",
      aa2: "#6B6B6B",
      aa4: "#F3F3F3",
      aa5: "#FAFAFA",
      ab4: "#F3F3F3",
      ab5: "#FAFAFA",
    },
    rules: {
      mono: false,
      no_corner_radius: false,
      outer_container_double_border: false,
      container_dots: false,
      caps_lock: false,
      all_paper: true,
    },
    is_dark: false,
  }
}
