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

///|
pub fn validate_against_schema(
  doc : @ast.Document,
  schema : @ast.Document,
) -> Array[String] {
  let errors = validate(doc)
  let type_fields = build_type_fields(schema)
  let root_types = find_root_types(schema)
  for def in doc.definitions {
    if def is Operation(op) {
      let root_type = match op.operation {
        Query => root_types.0
        Mutation => root_types.1
        Subscription => root_types.2
      }
      if root_type is Some(rt) {
        validate_selections_on_type(op.selections, rt, type_fields, errors)
      }
    }
  }
  errors
}

///|
fn build_type_fields(
  schema : @ast.Document,
) -> Map[String, Array[@ast.FieldDef]] {
  let m : Map[String, Array[@ast.FieldDef]] = {}
  for def in schema.definitions {
    if def is SchemaType(ts) {
      match ts {
        ObjectType(obj) => m[obj.name] = obj.fields
        InterfaceType(iface) => m[iface.name] = iface.fields
        _ => ()
      }
    }
  }
  m
}

///|
fn find_root_types(
  schema : @ast.Document,
) -> (String?, String?, String?) {
  let mut query : String? = None
  let mut mutation : String? = None
  let mut subscription : String? = None
  for def in schema.definitions {
    if def is SchemaType(SchemaDefinition(s)) {
      query = s.query
      mutation = s.mutation
      subscription = s.subscription
    }
  }
  if query is None {
    for def in schema.definitions {
      if def is SchemaType(ObjectType({ name: "Query", .. })) {
        query = Some("Query")
      }
      if def is SchemaType(ObjectType({ name: "Mutation", .. })) {
        mutation = Some("Mutation")
      }
      if def is SchemaType(ObjectType({ name: "Subscription", .. })) {
        subscription = Some("Subscription")
      }
    }
  }
  (query, mutation, subscription)
}

///|
fn validate_selections_on_type(
  selections : Array[@ast.Selection],
  type_name : String,
  type_fields : Map[String, Array[@ast.FieldDef]],
  errors : Array[String],
) -> Unit {
  let fields_opt = type_fields.get(type_name)
  if fields_opt is None {
    return
  }
  guard fields_opt is Some(field_defs)
  for sel in selections {
    if sel is Field(field) {
      if field.name == "__typename" {
        continue
      }
      let found = find_field_def(field_defs, field.name)
      if found is None {
        errors.push(
          "Field \"\{field.name}\" is not defined on type \"\{type_name}\"",
        )
      } else {
        guard found is Some(fd)
        validate_required_arguments(field, fd, errors)
        let inner_type = unwrap_type_name(fd.field_type)
        if !field.selections.is_empty() {
          if inner_type is Some(it) {
            validate_selections_on_type(
              field.selections, it, type_fields, errors,
            )
          }
        }
      }
    }
  }
}

///|
fn find_field_def(
  fields : Array[@ast.FieldDef],
  name : String,
) -> @ast.FieldDef? {
  for f in fields {
    if f.name == name {
      return Some(f)
    }
  }
  None
}

///|
fn validate_required_arguments(
  field : @ast.FieldNode,
  field_def : @ast.FieldDef,
  errors : Array[String],
) -> Unit {
  for arg_def in field_def.arguments {
    if is_required_arg(arg_def) {
      let mut found = false
      for arg in field.arguments {
        if arg.name == arg_def.name {
          found = true
          break
        }
      }
      if !found {
        errors.push(
          "Missing required argument \"\{arg_def.name}\" on field \"\{field.name}\"",
        )
      }
    }
  }
}

///|
fn is_required_arg(arg : @ast.InputValueDef) -> Bool {
  arg.input_type is NonNull(_) && arg.default_value is None
}

///|
fn unwrap_type_name(tr : @ast.TypeRef) -> String? {
  match tr {
    Named(name) => Some(name)
    List(inner) => unwrap_type_name(inner)
    NonNull(inner) => unwrap_type_name(inner)
  }
}
