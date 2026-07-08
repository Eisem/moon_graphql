///|
pub fn detect_fragment_cycles(doc : @ast.Document) -> Array[ValidationError] {
  let errors : Array[ValidationError] = []
  let fragment_map : Map[String, @ast.FragmentDef] = {}
  for def in doc.definitions {
    match def {
      Fragment(f) => fragment_map[f.name] = f
      _ => ()
    }
  }
  let visited : Map[String, Bool] = {}
  let in_stack : Map[String, Bool] = {}
  for name, _ in fragment_map {
    if !visited.contains(name) {
      detect_cycle(name, fragment_map, visited, in_stack, errors)
    }
  }
  errors
}

///|
fn detect_cycle(
  name : String,
  fragment_map : Map[String, @ast.FragmentDef],
  visited : Map[String, Bool],
  in_stack : Map[String, Bool],
  errors : Array[ValidationError],
) -> Unit {
  visited[name] = true
  in_stack[name] = true
  match fragment_map.get(name) {
    Some(frag) => {
      let spreads = collect_fragment_spreads(frag.selections)
      for spread_name in spreads {
        if in_stack.contains(spread_name) {
          errors.push({
            message: "Fragment cycle detected: '\{name}' references '\{spread_name}' which creates a cycle",
            ty: "error",
          })
        } else if !visited.contains(spread_name) {
          detect_cycle(spread_name, fragment_map, visited, in_stack, errors)
        }
      }
    }
    None => ()
  }
  in_stack.remove(name)
}

///|
fn collect_fragment_spreads(
  selections : Array[@ast.Selection],
) -> Array[String] {
  let spreads : Array[String] = []
  for sel in selections {
    match sel {
      FragmentSpread(fs) => spreads.push(fs.name)
      Field(f) => {
        let nested = collect_fragment_spreads(f.selections)
        for s in nested {
          spreads.push(s)
        }
      }
      InlineFragment(inf) => {
        let nested = collect_fragment_spreads(inf.selections)
        for s in nested {
          spreads.push(s)
        }
      }
    }
  }
  spreads
}
