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
  validate_lone_anonymous_operation(doc, errors)
  validate_unique_variable_names(doc, errors)
  validate_variables_defined(doc, errors)
  for error in detect_fragment_cycles(doc) {
    errors.push(error)
  }
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
fn validate_lone_anonymous_operation(
  doc : @ast.Document,
  errors : Array[ValidationError],
) -> Unit {
  let mut operation_count = 0
  let mut has_anonymous = false
  for def in doc.definitions {
    if def is Operation(operation) {
      operation_count += 1
      if operation.name is None {
        has_anonymous = true
      }
    }
  }
  if operation_count > 1 && has_anonymous {
    errors.push({
      message: "Anonymous operation must be the only operation in a document",
      ty: "error",
    })
  }
}

///|
fn validate_unique_variable_names(
  doc : @ast.Document,
  errors : Array[ValidationError],
) -> Unit {
  for def in doc.definitions {
    if def is Operation(operation) {
      let seen : Map[String, Bool] = {}
      for variable in operation.variables {
        if seen.contains(variable.name) {
          errors.push({
            message: "Duplicate variable name: $\{variable.name}",
            ty: "error",
          })
        } else {
          seen[variable.name] = true
        }
      }
    }
  }
}

///|
fn validate_variables_defined(
  doc : @ast.Document,
  errors : Array[ValidationError],
) -> Unit {
  let fragments : Map[String, @ast.FragmentDef] = {}
  for def in doc.definitions {
    if def is Fragment(fragment) {
      fragments[fragment.name] = fragment
    }
  }
  for def in doc.definitions {
    if def is Operation(op) {
      let defined : Map[String, Bool] = {}
      for v in op.variables {
        defined[v.name] = true
      }
      check_variables_in_directives(op.directives, defined, errors)
      let visited_fragments : Map[String, Bool] = {}
      for sel in op.selections {
        check_variables_in_selection(
          sel, defined, fragments, visited_fragments, errors,
        )
      }
    }
  }
}

///|
fn check_variables_in_selection(
  sel : @ast.Selection,
  defined : Map[String, Bool],
  fragments : Map[String, @ast.FragmentDef],
  visited_fragments : Map[String, Bool],
  errors : Array[ValidationError],
) -> Unit {
  match sel {
    Field(field) => {
      for arg in field.arguments {
        check_variables_in_value(arg.value, defined, errors)
      }
      check_variables_in_directives(field.directives, defined, errors)
      for s in field.selections {
        check_variables_in_selection(
          s, defined, fragments, visited_fragments, errors,
        )
      }
    }
    FragmentSpread(spread) => {
      check_variables_in_directives(spread.directives, defined, errors)
      if !visited_fragments.contains(spread.name) {
        visited_fragments[spread.name] = true
        if fragments.get(spread.name) is Some(fragment) {
          check_variables_in_directives(fragment.directives, defined, errors)
          for s in fragment.selections {
            check_variables_in_selection(
              s, defined, fragments, visited_fragments, errors,
            )
          }
        }
      }
    }
    InlineFragment(frag) => {
      check_variables_in_directives(frag.directives, defined, errors)
      for s in frag.selections {
        check_variables_in_selection(
          s, defined, fragments, visited_fragments, errors,
        )
      }
    }
  }
}

///|
fn check_variables_in_directives(
  directives : Array[@ast.Directive],
  defined : Map[String, Bool],
  errors : Array[ValidationError],
) -> Unit {
  for directive in directives {
    for argument in directive.arguments {
      check_variables_in_value(argument.value, defined, errors)
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
  directive_defs : Map[String, @ast.DirectiveDef]
}

///|
fn is_composite_kind(kind : String) -> Bool {
  kind == "object" || kind == "interface" || kind == "union"
}

///|
fn is_leaf_kind(kind : String) -> Bool {
  kind == "scalar" || kind == "enum"
}

///|
fn builtin_directive_definitions() -> Array[@ast.DirectiveDef] {
  let required_boolean : @ast.InputValueDef = {
    description: None,
    name: "if",
    input_type: NonNull(Named("Boolean")),
    default_value: None,
    directives: [],
  }
  [
    {
      description: None,
      name: "skip",
      arguments: [required_boolean],
      repeatable: false,
      locations: ["FIELD", "FRAGMENT_SPREAD", "INLINE_FRAGMENT"],
    },
    {
      description: None,
      name: "include",
      arguments: [required_boolean],
      repeatable: false,
      locations: ["FIELD", "FRAGMENT_SPREAD", "INLINE_FRAGMENT"],
    },
    {
      description: None,
      name: "deprecated",
      arguments: [
        {
          description: None,
          name: "reason",
          input_type: Named("String"),
          default_value: Some(StringVal("No longer supported")),
          directives: [],
        },
      ],
      repeatable: false,
      locations: [
        "FIELD_DEFINITION", "ARGUMENT_DEFINITION", "INPUT_FIELD_DEFINITION", "ENUM_VALUE",
      ],
    },
    {
      description: None,
      name: "specifiedBy",
      arguments: [
        {
          description: None,
          name: "url",
          input_type: NonNull(Named("String")),
          default_value: None,
          directives: [],
        },
      ],
      repeatable: false,
      locations: ["SCALAR"],
    },
  ]
}

///|
fn build_schema_info(schema : @ast.Document) -> SchemaInfo {
  let object_fields : Map[String, Array[@ast.FieldDef]] = {}
  let has_type : Map[String, String] = {}
  let directive_defs : Map[String, @ast.DirectiveDef] = {}
  for directive in builtin_directive_definitions() {
    directive_defs[directive.name] = directive
  }
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
        DirectiveDefinition(d) => directive_defs[d.name] = d
        _ => ()
      }
    }
  }
  { object_fields, has_type, directive_defs }
}

///|
pub fn validate_against_schema(
  doc : @ast.Document,
  schema : @ast.Document,
) -> Array[ValidationError] {
  let errors = validate(doc)
  let schema_info = build_schema_info(schema)
  validate_document_directives(doc, schema_info, errors)
  let root_types = find_root_types(schema)
  let fragments : Map[String, @ast.FragmentDef] = {}
  for def in doc.definitions {
    if def is Fragment(fragment) {
      fragments[fragment.name] = fragment
    }
  }
  let validating_fragments : Map[String, Bool] = {}
  let validated_fragments : Map[String, Bool] = {}
  for def in doc.definitions {
    if def is Operation(op) {
      let root_type = match op.operation {
        Query => root_types.0
        Mutation => root_types.1
        Subscription => root_types.2
      }
      if root_type is Some(rt) {
        validate_selections_on_type(
          op.selections,
          rt,
          schema_info,
          fragments,
          validating_fragments,
          validated_fragments,
          errors,
        )
      }
    }
  }
  // Validate unused fragments too: executable-document validation applies to
  // every definition, not only definitions reachable from an operation.
  for name, _ in fragments {
    validate_named_fragment(
      name, schema_info, fragments, validating_fragments, validated_fragments, errors,
    )
  }
  errors
}

///|
fn validate_document_directives(
  doc : @ast.Document,
  schema_info : SchemaInfo,
  errors : Array[ValidationError],
) -> Unit {
  for def in doc.definitions {
    match def {
      Operation(operation) => {
        let location = match operation.operation {
          Query => "QUERY"
          Mutation => "MUTATION"
          Subscription => "SUBSCRIPTION"
        }
        validate_directive_list(
          operation.directives,
          location,
          schema_info,
          errors,
        )
        for variable in operation.variables {
          validate_directive_list(
            variable.directives,
            "VARIABLE_DEFINITION",
            schema_info,
            errors,
          )
        }
        validate_directives_in_selections(
          operation.selections,
          schema_info,
          errors,
        )
      }
      Fragment(fragment) => {
        validate_directive_list(
          fragment.directives,
          "FRAGMENT_DEFINITION",
          schema_info,
          errors,
        )
        validate_directives_in_selections(
          fragment.selections,
          schema_info,
          errors,
        )
      }
      SchemaType(_) => ()
    }
  }
}

///|
fn validate_directives_in_selections(
  selections : Array[@ast.Selection],
  schema_info : SchemaInfo,
  errors : Array[ValidationError],
) -> Unit {
  for selection in selections {
    match selection {
      Field(field) => {
        validate_directive_list(field.directives, "FIELD", schema_info, errors)
        validate_directives_in_selections(field.selections, schema_info, errors)
      }
      FragmentSpread(spread) =>
        validate_directive_list(
          spread.directives,
          "FRAGMENT_SPREAD",
          schema_info,
          errors,
        )
      InlineFragment(fragment) => {
        validate_directive_list(
          fragment.directives,
          "INLINE_FRAGMENT",
          schema_info,
          errors,
        )
        validate_directives_in_selections(
          fragment.selections,
          schema_info,
          errors,
        )
      }
    }
  }
}

///|
fn validate_directive_list(
  directives : Array[@ast.Directive],
  location : String,
  schema_info : SchemaInfo,
  errors : Array[ValidationError],
) -> Unit {
  let seen : Map[String, Bool] = {}
  for directive in directives {
    match schema_info.directive_defs.get(directive.name) {
      None =>
        errors.push({
          message: "Unknown directive \"@\{directive.name}\"",
          ty: "error",
        })
      Some(definition) => {
        let mut allowed = false
        for allowed_location in definition.locations {
          if allowed_location == location {
            allowed = true
            break
          }
        }
        if !allowed {
          errors.push({
            message: "Directive \"@\{directive.name}\" is not allowed at location \"\{location}\"",
            ty: "error",
          })
        }
        if seen.contains(directive.name) && !definition.repeatable {
          errors.push({
            message: "Directive \"@\{directive.name}\" is not repeatable at location \"\{location}\"",
            ty: "error",
          })
        }
        validate_directive_arguments(directive, definition, errors)
      }
    }
    seen[directive.name] = true
  }
}

///|
fn validate_directive_arguments(
  directive : @ast.Directive,
  definition : @ast.DirectiveDef,
  errors : Array[ValidationError],
) -> Unit {
  let seen : Map[String, Bool] = {}
  for argument in directive.arguments {
    if seen.contains(argument.name) {
      errors.push({
        message: "Duplicate argument \"\{argument.name}\" on directive \"@\{directive.name}\"",
        ty: "error",
      })
    }
    seen[argument.name] = true
    if find_input_value_def(definition.arguments, argument.name) is None {
      errors.push({
        message: "Unknown argument \"\{argument.name}\" on directive \"@\{directive.name}\"",
        ty: "error",
      })
    }
  }
  for argument_def in definition.arguments {
    if is_required_arg(argument_def) && !seen.contains(argument_def.name) {
      errors.push({
        message: "Missing required argument \"\{argument_def.name}\" on directive \"@\{directive.name}\"",
        ty: "error",
      })
    }
  }
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
  fragments : Map[String, @ast.FragmentDef],
  validating_fragments : Map[String, Bool],
  validated_fragments : Map[String, Bool],
  errors : Array[ValidationError],
) -> Unit {
  let type_kind = schema_info.has_type.get(type_name)
  if type_kind is None {
    errors.push({
      message: "Unknown type \"\{type_name}\" in selection context",
      ty: "error",
    })
    return
  }
  guard type_kind is Some(kind)
  if is_leaf_kind(kind) || kind == "input-object" {
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
    match sel {
      Field(field) => {
        if field.name == "__typename" {
          continue
        }
        // Union fields can only be selected through type-conditioned
        // fragments. __typename is handled above.
        if kind == "union" {
          errors.push({
            message: "Field \"\{field.name}\" cannot be selected directly on union type \"\{type_name}\"",
            ty: "error",
          })
          continue
        }
        guard fields_opt is Some(field_defs) else { continue }
        let found = find_field_def(field_defs, field.name)
        if found is None {
          errors.push({
            message: "Field \"\{field.name}\" is not defined on type \"\{type_name}\"",
            ty: "error",
          })
        } else {
          guard found is Some(fd)
          validate_field_arguments(field, fd, errors)
          guard unwrap_type_name(fd.field_type) is Some(inner_type) else {
            continue
          }
          let inner_kind = schema_info.has_type.get(inner_type)
          if inner_kind is Some(result_kind) {
            if is_leaf_kind(result_kind) && !field.selections.is_empty() {
              errors.push({
                message: "Field \"\{field.name}\" of leaf type \"\{inner_type}\" must not have a selection set",
                ty: "error",
              })
            } else if is_composite_kind(result_kind) &&
              field.selections.is_empty() {
              errors.push({
                message: "Field \"\{field.name}\" of composite type \"\{inner_type}\" must have a selection set",
                ty: "error",
              })
            } else if is_composite_kind(result_kind) {
              validate_selections_on_type(
                field.selections,
                inner_type,
                schema_info,
                fragments,
                validating_fragments,
                validated_fragments,
                errors,
              )
            }
          } else {
            errors.push({
              message: "Field \"\{field.name}\" references unknown type \"\{inner_type}\"",
              ty: "error",
            })
          }
        }
      }
      FragmentSpread(spread) =>
        validate_named_fragment(
          spread.name,
          schema_info,
          fragments,
          validating_fragments,
          validated_fragments,
          errors,
        )
      InlineFragment(fragment) => {
        let fragment_type = match fragment.type_condition {
          Some(condition) => condition
          None => type_name
        }
        validate_fragment_type_condition(fragment_type, schema_info, errors)
        match schema_info.has_type.get(fragment_type) {
          Some(fragment_kind) =>
            if is_composite_kind(fragment_kind) {
              validate_selections_on_type(
                fragment.selections,
                fragment_type,
                schema_info,
                fragments,
                validating_fragments,
                validated_fragments,
                errors,
              )
            }
          None => ()
        }
      }
    }
  }
}

///|
fn validate_named_fragment(
  name : String,
  schema_info : SchemaInfo,
  fragments : Map[String, @ast.FragmentDef],
  validating_fragments : Map[String, Bool],
  validated_fragments : Map[String, Bool],
  errors : Array[ValidationError],
) -> Unit {
  if validated_fragments.contains(name) || validating_fragments.contains(name) {
    return
  }
  guard fragments.get(name) is Some(fragment) else { return }
  validating_fragments[name] = true
  validate_fragment_type_condition(fragment.type_condition, schema_info, errors)
  match schema_info.has_type.get(fragment.type_condition) {
    Some(kind) =>
      if is_composite_kind(kind) {
        validate_selections_on_type(
          fragment.selections,
          fragment.type_condition,
          schema_info,
          fragments,
          validating_fragments,
          validated_fragments,
          errors,
        )
      }
    None => ()
  }
  validating_fragments.remove(name)
  validated_fragments[name] = true
}

///|
fn validate_fragment_type_condition(
  type_name : String,
  schema_info : SchemaInfo,
  errors : Array[ValidationError],
) -> Unit {
  match schema_info.has_type.get(type_name) {
    None =>
      errors.push({
        message: "Fragment type condition references unknown type \"\{type_name}\"",
        ty: "error",
      })
    Some(kind) =>
      if !is_composite_kind(kind) {
        errors.push({
          message: "Fragment type condition \"\{type_name}\" must be a composite type",
          ty: "error",
        })
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
fn validate_field_arguments(
  field : @ast.FieldNode,
  field_def : @ast.FieldDef,
  errors : Array[ValidationError],
) -> Unit {
  let seen : Map[String, Bool] = {}
  for argument in field.arguments {
    if seen.contains(argument.name) {
      errors.push({
        message: "Duplicate argument \"\{argument.name}\" on field \"\{field.name}\"",
        ty: "error",
      })
    }
    seen[argument.name] = true
    if find_input_value_def(field_def.arguments, argument.name) is None {
      errors.push({
        message: "Unknown argument \"\{argument.name}\" on field \"\{field.name}\"",
        ty: "error",
      })
    }
  }
  for arg_def in field_def.arguments {
    if is_required_arg(arg_def) && !seen.contains(arg_def.name) {
      errors.push({
        message: "Missing required argument \"\{arg_def.name}\" on field \"\{field.name}\"",
        ty: "error",
      })
    }
  }
}

///|
fn find_input_value_def(
  definitions : Array[@ast.InputValueDef],
  name : String,
) -> @ast.InputValueDef? {
  for definition in definitions {
    if definition.name == name {
      return Some(definition)
    }
  }
  None
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
