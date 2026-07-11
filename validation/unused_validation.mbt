///|
fn validate_no_unused_variables(
  doc : @ast.Document,
  errors : Array[ValidationError],
) -> Unit {
  let fragments = build_executable_fragment_map(doc)
  for def in doc.definitions {
    if def is Operation(operation) {
      let used_variables : Map[String, Bool] = {}
      let visited_fragments : Map[String, Bool] = {}
      collect_variables_in_directives(operation.directives, used_variables)
      for variable in operation.variables {
        collect_variables_in_directives(variable.directives, used_variables)
      }
      collect_variables_in_selections(
        operation.selections,
        fragments,
        visited_fragments,
        used_variables,
        None,
      )
      for variable in operation.variables {
        if !used_variables.contains(variable.name) {
          errors.push({
            message: "Variable \"$\{variable.name}\" is never used by operation \"\{operation_display_name(operation)}\"",
            ty: "error",
          })
        }
      }
    }
  }
}

///|
fn validate_no_unused_fragments(
  doc : @ast.Document,
  errors : Array[ValidationError],
) -> Unit {
  let fragments = build_executable_fragment_map(doc)
  let used_fragments : Map[String, Bool] = {}
  for def in doc.definitions {
    if def is Operation(operation) {
      let visited_fragments : Map[String, Bool] = {}
      let ignored_variables : Map[String, Bool] = {}
      collect_variables_in_selections(
        operation.selections,
        fragments,
        visited_fragments,
        ignored_variables,
        Some(used_fragments),
      )
    }
  }
  for name, _ in fragments {
    if !used_fragments.contains(name) {
      errors.push({
        message: "Fragment \"\{name}\" is never used by an operation",
        ty: "error",
      })
    }
  }
}

///|
fn build_executable_fragment_map(
  doc : @ast.Document,
) -> Map[String, @ast.FragmentDef] {
  let fragments : Map[String, @ast.FragmentDef] = {}
  for def in doc.definitions {
    if def is Fragment(fragment) {
      fragments[fragment.name] = fragment
    }
  }
  fragments
}

///|
fn collect_variables_in_selections(
  selections : Array[@ast.Selection],
  fragments : Map[String, @ast.FragmentDef],
  visited_fragments : Map[String, Bool],
  used_variables : Map[String, Bool],
  used_fragments : Map[String, Bool]?,
) -> Unit {
  for selection in selections {
    match selection {
      Field(field) => {
        for argument in field.arguments {
          collect_variables_in_value(argument.value, used_variables)
        }
        collect_variables_in_directives(field.directives, used_variables)
        collect_variables_in_selections(
          field.selections,
          fragments,
          visited_fragments,
          used_variables,
          used_fragments,
        )
      }
      FragmentSpread(spread) => {
        collect_variables_in_directives(spread.directives, used_variables)
        if used_fragments is Some(fragment_names) {
          fragment_names[spread.name] = true
        }
        if !visited_fragments.contains(spread.name) {
          visited_fragments[spread.name] = true
          if fragments.get(spread.name) is Some(fragment) {
            collect_variables_in_directives(fragment.directives, used_variables)
            collect_variables_in_selections(
              fragment.selections,
              fragments,
              visited_fragments,
              used_variables,
              used_fragments,
            )
          }
        }
      }
      InlineFragment(fragment) => {
        collect_variables_in_directives(fragment.directives, used_variables)
        collect_variables_in_selections(
          fragment.selections,
          fragments,
          visited_fragments,
          used_variables,
          used_fragments,
        )
      }
    }
  }
}

///|
fn collect_variables_in_directives(
  directives : Array[@ast.Directive],
  used_variables : Map[String, Bool],
) -> Unit {
  for directive in directives {
    for argument in directive.arguments {
      collect_variables_in_value(argument.value, used_variables)
    }
  }
}

///|
fn collect_variables_in_value(
  value : @ast.Value,
  used_variables : Map[String, Bool],
) -> Unit {
  match value {
    Variable(name) => used_variables[name] = true
    ListVal(values) =>
      for item in values {
        collect_variables_in_value(item, used_variables)
      }
    ObjectVal(fields) =>
      for field in fields {
        collect_variables_in_value(field.1, used_variables)
      }
    _ => ()
  }
}

///|
fn operation_display_name(operation : @ast.OperationDef) -> String {
  match operation.name {
    Some(name) => name
    None => "<anonymous>"
  }
}
