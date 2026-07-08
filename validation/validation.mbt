///|
pub struct ValidationError {
  message : String
  ty : String
} derive(Debug, Eq)

///|
pub fn ValidationError::message(self : ValidationError) -> String {
  self.message
}

///|
pub fn ValidationError::is_error(self : ValidationError) -> Bool {
  self.ty == "error"
}

///|
pub fn ValidationError::is_warning(self : ValidationError) -> Bool {
  self.ty == "warning"
}

///|
pub fn validate(doc : @ast.Document) -> Array[ValidationError] {
  let errors : Array[ValidationError] = []
  validate_unique_fragment_names(doc, errors)
  validate_fragment_spreads(doc, errors)
  validate_unique_operation_names(doc, errors)
  validate_variables_defined(doc, errors)
  errors
}

///|
fn validate_unique_fragment_names(
  doc : @ast.Document,
  errors : Array[ValidationError],
) -> Unit {
  let seen : Map[String, Bool] = {}
  for def in doc.definitions {
    if def is Fragment({ name, .. }) {
      if seen.contains(name) {
        errors.push({ message: "Duplicate fragment name: \{name}", ty: "error" })
      } else {
        seen[name] = true
      }
    }
  }
}

///|
fn validate_fragment_spreads(
  doc : @ast.Document,
  errors : Array[ValidationError],
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
  errors : Array[ValidationError],
) -> Unit {
  match sel {
    Field(field) =>
      for s in field.selections {
        check_fragment_spreads_in_selection(s, defined, errors)
      }
    FragmentSpread(spread) =>
      if !defined.contains(spread.name) {
        errors.push({
          message: "Undefined fragment: \{spread.name}",
          ty: "error",
        })
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
  errors : Array[ValidationError],
) -> Unit {
  let seen : Map[String, Bool] = {}
  for def in doc.definitions {
    if def is Operation({ name: Some(name), .. }) {
      if seen.contains(name) {
        errors.push({
          message: "Duplicate operation name: \{name}",
          ty: "error",
        })
      } else {
        seen[name] = true
      }
    }
  }
}

///|
fn validate_variables_defined(
  doc : @ast.Document,
  errors : Array[ValidationError],
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
  errors : Array[ValidationError],
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
  errors : Array[ValidationError],
) -> Unit {
  match value {
    Variable(name) =>
      if !defined.contains(name) {
        errors.push({ message: "Undefined variable: $\{name}", ty: "error" })
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
priv struct SchemaInfo {
  object_fields : Map[String, Array[@ast.FieldDef]]
  has_type : Map[String, String]
}

///|
fn build_schema_info(schema : @ast.Document) -> SchemaInfo {
  let object_fields : Map[String, Array[@ast.FieldDef]] = {}
  let has_type : Map[String, String] = {}
  let builtin_scalars = ["String", "Int", "Float", "Boolean", "ID"]
  for s in builtin_scalars {
    has_type[s] = "scalar"
  }
  let builtin_introspection = [
    "__Schema", "__Type", "__TypeKind", "__Field", "__InputValue", "__EnumValue",
    "__Directive",
  ]
  for s in builtin_introspection {
    has_type[s] = "object"
  }
  for def in schema.definitions {
    if def is SchemaType(ts) {
      match ts {
        ObjectType(obj) => {
          object_fields[obj.name] = obj.fields
          has_type[obj.name] = "object"
        }
        InterfaceType(iface) => {
          object_fields[iface.name] = iface.fields
          has_type[iface.name] = "interface"
        }
        UnionType(u) => has_type[u.name] = "union"
        EnumType(e) => has_type[e.name] = "enum"
        ScalarType(s) => has_type[s.name] = "scalar"
        InputObjectType(i) => has_type[i.name] = "input-object"
        _ => ()
      }
    }
  }
  { object_fields, has_type }
}

///|
pub fn validate_against_schema(
  doc : @ast.Document,
  schema : @ast.Document,
) -> Array[ValidationError] {
  let errors = validate(doc)
  let schema_info = build_schema_info(schema)
  let root_types = find_root_types(schema)
  for def in doc.definitions {
    if def is Operation(op) {
      let root_type = match op.operation {
        Query => root_types.0
        Mutation => root_types.1
        Subscription => root_types.2
      }
      if root_type is Some(rt) {
        validate_selections_on_type(op.selections, rt, schema_info, errors)
      }
    }
  }
  errors
}

///|
fn find_root_types(schema : @ast.Document) -> (String?, String?, String?) {
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
  schema_info : SchemaInfo,
  errors : Array[ValidationError],
) -> Unit {
  let type_kind = schema_info.has_type.get(type_name)
  if type_kind is None {
    return
  }
  guard type_kind is Some(kind)
  if kind == "scalar" ||
    kind == "enum" ||
    kind == "union" ||
    kind == "input-object" {
    for sel in selections {
      if sel is Field(field) {
        errors.push({
          message: "Cannot query field \"\{field.name}\" on type \"\{type_name}\" (\{kind}) because it is a leaf type",
          ty: "error",
        })
      }
    }
    return
  }
  let fields_opt = schema_info.object_fields.get(type_name)
  for sel in selections {
    if sel is Field(field) {
      if field.name == "__typename" {
        continue
      }
      if fields_opt is None {
        return
      }
      guard fields_opt is Some(field_defs)
      let found = find_field_def(field_defs, field.name)
      if found is None {
        errors.push({
          message: "Field \"\{field.name}\" is not defined on type \"\{type_name}\"",
          ty: "error",
        })
      } else {
        guard found is Some(fd)
        validate_required_arguments(field, fd, errors)
        let inner_type = unwrap_type_name(fd.field_type)
        if !field.selections.is_empty() {
          if inner_type is Some(it) {
            validate_selections_on_type(
              field.selections,
              it,
              schema_info,
              errors,
            )
          } else {
            errors.push({
              message: "Field \"\{field.name}\" on type \"\{type_name}\" has sub-selections but its return type is not an object type",
              ty: "error",
            })
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
  errors : Array[ValidationError],
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
        errors.push({
          message: "Missing required argument \"\{arg_def.name}\" on field \"\{field.name}\"",
          ty: "error",
        })
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
