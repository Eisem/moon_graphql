///|
pub fn validate(doc : @ast.Document) -> Array[String] {
  let errors : Array[String] = []
  validate_unique_fragment_names(doc, errors)
  validate_fragment_spreads(doc, errors)
  validate_unique_operation_names(doc, errors)
  validate_variables_defined(doc, errors)
  errors
}

///|
fn validate_unique_fragment_names(
  doc : @ast.Document,
  errors : Array[String],
) -> Unit {
  let seen : Map[String, Bool] = {}
  for def in doc.definitions {
    if def is Fragment({ name, .. }) {
      if seen.contains(name) {
        errors.push("Duplicate fragment name: \{name}")
      } else {
        seen[name] = true
      }
    }
  }
}

///|
fn validate_fragment_spreads(
  doc : @ast.Document,
  errors : Array[String],
) -> Unit {
  let defined : Map[String, Bool] = {}
  for def in doc.definitions {
    if def is Fragment({ name, .. }) {
      defined[name] = true
    }
  }
  for def in doc.definitions {
    match def {
      Operation(op) =>
        for sel in op.selections {
          check_fragment_spreads_in_selection(sel, defined, errors)
        }
      Fragment(frag) =>
        for sel in frag.selections {
          check_fragment_spreads_in_selection(sel, defined, errors)
        }
      SchemaType(_) => ()
    }
  }
}

///|
fn check_fragment_spreads_in_selection(
  sel : @ast.Selection,
  defined : Map[String, Bool],
  errors : Array[String],
) -> Unit {
  match sel {
    Field(field) =>
      for s in field.selections {
        check_fragment_spreads_in_selection(s, defined, errors)
      }
    FragmentSpread(spread) =>
      if !defined.contains(spread.name) {
        errors.push("Undefined fragment: \{spread.name}")
      }
    InlineFragment(frag) =>
      for s in frag.selections {
        check_fragment_spreads_in_selection(s, defined, errors)
      }
  }
}

///|
fn validate_unique_operation_names(
  doc : @ast.Document,
  errors : Array[String],
) -> Unit {
  let seen : Map[String, Bool] = {}
  for def in doc.definitions {
    if def is Operation({ name: Some(name), .. }) {
      if seen.contains(name) {
        errors.push("Duplicate operation name: \{name}")
      } else {
        seen[name] = true
      }
    }
  }
}

///|
fn validate_variables_defined(
  doc : @ast.Document,
  errors : Array[String],
) -> Unit {
  for def in doc.definitions {
    if def is Operation(op) {
      let defined : Map[String, Bool] = {}
      for v in op.variables {
        defined[v.name] = true
      }
      for sel in op.selections {
        check_variables_in_selection(sel, defined, errors)
      }
    }
  }
}

///|
fn check_variables_in_selection(
  sel : @ast.Selection,
  defined : Map[String, Bool],
  errors : Array[String],
) -> Unit {
  match sel {
    Field(field) => {
      for arg in field.arguments {
        check_variables_in_value(arg.value, defined, errors)
      }
      for s in field.selections {
        check_variables_in_selection(s, defined, errors)
      }
    }
    FragmentSpread(_) => ()
    InlineFragment(frag) =>
      for s in frag.selections {
        check_variables_in_selection(s, defined, errors)
      }
  }
}

///|
fn check_variables_in_value(
  value : @ast.Value,
  defined : Map[String, Bool],
  errors : Array[String],
) -> Unit {
  match value {
    Variable(name) =>
      if !defined.contains(name) {
        errors.push("Undefined variable: $\{name}")
      }
    ListVal(values) =>
      for v in values {
        check_variables_in_value(v, defined, errors)
      }
    ObjectVal(fields) =>
      for field in fields {
        check_variables_in_value(field.1, defined, errors)
      }
    _ => ()
  }
}
