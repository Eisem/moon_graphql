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
  validate_no_unused_variables(doc, errors)
  validate_no_unused_fragments(doc, errors)
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
      for v in op.variables {
        check_variables_in_directives(v.directives, defined, errors)
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
  input_fields : Map[String, Array[@ast.InputValueDef]]
  enum_values : Map[String, Array[String]]
  has_type : Map[String, String]
  directive_defs : Map[String, @ast.DirectiveDef]
}

///|
priv struct VariableInfo {
  variable_type : @ast.TypeRef
  has_non_null_default : Bool
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
  let input_fields : Map[String, Array[@ast.InputValueDef]] = {}
  let enum_values : Map[String, Array[String]] = {}
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
        EnumType(e) => {
          has_type[e.name] = "enum"
          let values : Array[String] = []
          for value in e.values {
            values.push(value.name)
          }
          enum_values[e.name] = values
        }
        ScalarType(s) => has_type[s.name] = "scalar"
        InputObjectType(i) => {
          has_type[i.name] = "input-object"
          input_fields[i.name] = i.fields
        }
        DirectiveDefinition(d) => directive_defs[d.name] = d
        _ => ()
      }
    }
  }
  { object_fields, input_fields, enum_values, has_type, directive_defs }
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
        validate_operation_variable_positions(
          op, rt, schema_info, fragments, errors,
        )
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
        validate_directive_arguments(directive, definition, schema_info, errors)
      }
    }
    seen[directive.name] = true
  }
}

///|
fn validate_directive_arguments(
  directive : @ast.Directive,
  definition : @ast.DirectiveDef,
  schema_info : SchemaInfo,
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
    match find_input_value_def(definition.arguments, argument.name) {
      None =>
        errors.push({
          message: "Unknown argument \"\{argument.name}\" on directive \"@\{directive.name}\"",
          ty: "error",
        })
      Some(argument_def) =>
        validate_literal_value(
          argument.value,
          argument_def.input_type,
          schema_info,
          "argument \"\{argument.name}\" on directive \"@\{directive.name}\"",
          errors,
        )
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
fn validate_operation_variable_positions(
  operation : @ast.OperationDef,
  root_type : String,
  schema_info : SchemaInfo,
  fragments : Map[String, @ast.FragmentDef],
  errors : Array[ValidationError],
) -> Unit {
  let variables : Map[String, VariableInfo] = {}
  for variable in operation.variables {
    validate_variable_declared_type(variable, schema_info, errors)
    if variable.default_value is Some(default_value) {
      if default_value is Variable(_) {
        errors.push({
          message: "Default value for variable \"$\{variable.name}\" must be a constant",
          ty: "error",
        })
      } else {
        validate_literal_value(
          default_value,
          variable.var_type,
          schema_info,
          "default value for variable \"$\{variable.name}\"",
          errors,
        )
      }
    }
    variables[variable.name] = {
      variable_type: variable.var_type,
      has_non_null_default: match variable.default_value {
        Some(NullVal) | None => false
        Some(_) => true
      },
    }
  }
  for variable in operation.variables {
    validate_variable_positions_in_directives(
      variable.directives,
      schema_info,
      variables,
      errors,
    )
  }
  validate_variable_positions_in_directives(
    operation.directives,
    schema_info,
    variables,
    errors,
  )
  let visited_fragments : Map[String, Bool] = {}
  validate_variable_positions_in_selections(
    operation.selections,
    root_type,
    schema_info,
    fragments,
    visited_fragments,
    variables,
    errors,
  )
}

///|
fn validate_variable_declared_type(
  variable : @ast.VariableDef,
  schema_info : SchemaInfo,
  errors : Array[ValidationError],
) -> Unit {
  guard unwrap_type_name(variable.var_type) is Some(type_name) else { return }
  match schema_info.has_type.get(type_name) {
    Some("scalar") | Some("enum") | Some("input-object") => ()
    Some(_) =>
      errors.push({
        message: "Variable \"$\{variable.name}\" cannot use non-input type \"\{type_ref_string(variable.var_type)}\"",
        ty: "error",
      })
    None =>
      errors.push({
        message: "Variable \"$\{variable.name}\" references unknown type \"\{type_name}\"",
        ty: "error",
      })
  }
}

///|
fn validate_variable_positions_in_selections(
  selections : Array[@ast.Selection],
  type_name : String,
  schema_info : SchemaInfo,
  fragments : Map[String, @ast.FragmentDef],
  visited_fragments : Map[String, Bool],
  variables : Map[String, VariableInfo],
  errors : Array[ValidationError],
) -> Unit {
  let field_defs = schema_info.object_fields.get(type_name)
  for selection in selections {
    match selection {
      Field(field) => {
        validate_variable_positions_in_directives(
          field.directives,
          schema_info,
          variables,
          errors,
        )
        if field_defs is Some(definitions) &&
          find_field_def(definitions, field.name) is Some(field_def) {
          for argument in field.arguments {
            if find_input_value_def(field_def.arguments, argument.name)
              is Some(argument_def) {
              validate_variables_in_typed_value(
                argument.value,
                argument_def.input_type,
                argument_def.default_value is Some(_),
                schema_info,
                variables,
                "argument \"\{argument.name}\" on field \"\{field.name}\"",
                errors,
              )
            }
          }
          if unwrap_type_name(field_def.field_type) is Some(inner_type) {
            validate_variable_positions_in_selections(
              field.selections,
              inner_type,
              schema_info,
              fragments,
              visited_fragments,
              variables,
              errors,
            )
          }
        }
      }
      FragmentSpread(spread) => {
        validate_variable_positions_in_directives(
          spread.directives,
          schema_info,
          variables,
          errors,
        )
        if !visited_fragments.contains(spread.name) {
          visited_fragments[spread.name] = true
          if fragments.get(spread.name) is Some(fragment) {
            validate_variable_positions_in_directives(
              fragment.directives,
              schema_info,
              variables,
              errors,
            )
            validate_variable_positions_in_selections(
              fragment.selections,
              fragment.type_condition,
              schema_info,
              fragments,
              visited_fragments,
              variables,
              errors,
            )
          }
        }
      }
      InlineFragment(fragment) => {
        validate_variable_positions_in_directives(
          fragment.directives,
          schema_info,
          variables,
          errors,
        )
        let fragment_type = match fragment.type_condition {
          Some(condition) => condition
          None => type_name
        }
        validate_variable_positions_in_selections(
          fragment.selections,
          fragment_type,
          schema_info,
          fragments,
          visited_fragments,
          variables,
          errors,
        )
      }
    }
  }
}

///|
fn validate_variable_positions_in_directives(
  directives : Array[@ast.Directive],
  schema_info : SchemaInfo,
  variables : Map[String, VariableInfo],
  errors : Array[ValidationError],
) -> Unit {
  for directive in directives {
    if schema_info.directive_defs.get(directive.name) is Some(definition) {
      for argument in directive.arguments {
        if find_input_value_def(definition.arguments, argument.name)
          is Some(argument_def) {
          validate_variables_in_typed_value(
            argument.value,
            argument_def.input_type,
            argument_def.default_value is Some(_),
            schema_info,
            variables,
            "argument \"\{argument.name}\" on directive \"@\{directive.name}\"",
            errors,
          )
        }
      }
    }
  }
}

///|
fn validate_variables_in_typed_value(
  value : @ast.Value,
  expected_type : @ast.TypeRef,
  location_has_default : Bool,
  schema_info : SchemaInfo,
  variables : Map[String, VariableInfo],
  context : String,
  errors : Array[ValidationError],
) -> Unit {
  if value is Variable(name) {
    if variables.get(name) is Some(variable) &&
      !is_variable_usage_allowed(variable, expected_type, location_has_default) {
      errors.push({
        message: "Variable \"$\{name}\" of type \"\{type_ref_string(variable.variable_type)}\" is not compatible with expected type \"\{type_ref_string(expected_type)}\" for \{context}",
        ty: "error",
      })
    }
    return
  }
  let unwrapped = match expected_type {
    NonNull(inner) => inner
    _ => expected_type
  }
  match (value, unwrapped) {
    (ListVal(values), List(inner)) =>
      for item in values {
        validate_variables_in_typed_value(
          item, inner, false, schema_info, variables, context, errors,
        )
      }
    (ObjectVal(fields), Named(type_name)) =>
      if schema_info.input_fields.get(type_name) is Some(field_defs) {
        for field in fields {
          if find_input_value_def(field_defs, field.0) is Some(field_def) {
            validate_variables_in_typed_value(
              field.1,
              field_def.input_type,
              field_def.default_value is Some(_),
              schema_info,
              variables,
              "input field \"\{field.0}\" of \"\{type_name}\"",
              errors,
            )
          }
        }
      }
    (_, List(inner)) =>
      validate_variables_in_typed_value(
        value, inner, false, schema_info, variables, context, errors,
      )
    _ => ()
  }
}

///|
fn is_variable_usage_allowed(
  variable : VariableInfo,
  expected_type : @ast.TypeRef,
  location_has_default : Bool,
) -> Bool {
  match expected_type {
    NonNull(inner) =>
      match variable.variable_type {
        NonNull(variable_inner) =>
          are_input_types_compatible(variable_inner, inner)
        _ =>
          (variable.has_non_null_default || location_has_default) &&
          are_input_types_compatible(variable.variable_type, inner)
      }
    _ => are_input_types_compatible(variable.variable_type, expected_type)
  }
}

///|
fn are_input_types_compatible(
  variable_type : @ast.TypeRef,
  expected_type : @ast.TypeRef,
) -> Bool {
  match (variable_type, expected_type) {
    (NonNull(variable_inner), NonNull(expected_inner)) =>
      are_input_types_compatible(variable_inner, expected_inner)
    (NonNull(variable_inner), _) =>
      are_input_types_compatible(variable_inner, expected_type)
    (List(variable_inner), List(expected_inner)) =>
      are_input_types_compatible(variable_inner, expected_inner)
    (Named(variable_name), Named(expected_name)) =>
      variable_name == expected_name
    _ => false
  }
}

///|
fn type_ref_string(type_ref : @ast.TypeRef) -> String {
  match type_ref {
    Named(name) => name
    List(inner) => "[\{type_ref_string(inner)}]"
    NonNull(inner) => "\{type_ref_string(inner)}!"
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
          validate_field_arguments(field, fd, schema_info, errors)
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
  schema_info : SchemaInfo,
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
    match find_input_value_def(field_def.arguments, argument.name) {
      None =>
        errors.push({
          message: "Unknown argument \"\{argument.name}\" on field \"\{field.name}\"",
          ty: "error",
        })
      Some(argument_def) =>
        validate_literal_value(
          argument.value,
          argument_def.input_type,
          schema_info,
          "argument \"\{argument.name}\" on field \"\{field.name}\"",
          errors,
        )
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
fn validate_literal_value(
  value : @ast.Value,
  expected_type : @ast.TypeRef,
  schema_info : SchemaInfo,
  context : String,
  errors : Array[ValidationError],
) -> Unit {
  // Variable compatibility depends on the operation's variable definition and
  // is checked in a separate schema-aware traversal.
  if value is Variable(_) {
    return
  }
  match expected_type {
    NonNull(inner) =>
      if value is NullVal {
        errors.push({
          message: "Null is not allowed for non-null \{context}",
          ty: "error",
        })
      } else {
        validate_literal_value(value, inner, schema_info, context, errors)
      }
    List(inner) =>
      match value {
        NullVal => ()
        ListVal(values) =>
          for item in values {
            validate_literal_value(item, inner, schema_info, context, errors)
          }
        // GraphQL permits a single input value where a list is expected.
        _ => validate_literal_value(value, inner, schema_info, context, errors)
      }
    Named(name) =>
      if !(value is NullVal) {
        validate_named_literal(value, name, schema_info, context, errors)
      }
  }
}

///|
fn validate_named_literal(
  value : @ast.Value,
  type_name : String,
  schema_info : SchemaInfo,
  context : String,
  errors : Array[ValidationError],
) -> Unit {
  match type_name {
    "Int" =>
      if !(value is IntVal(_)) {
        push_literal_type_error(value, type_name, context, errors)
      }
    "Float" =>
      if !(value is IntVal(_)) && !(value is FloatVal(_)) {
        push_literal_type_error(value, type_name, context, errors)
      }
    "String" =>
      if !(value is StringVal(_)) {
        push_literal_type_error(value, type_name, context, errors)
      }
    "Boolean" =>
      if !(value is BoolVal(_)) {
        push_literal_type_error(value, type_name, context, errors)
      }
    "ID" =>
      if !(value is StringVal(_)) && !(value is IntVal(_)) {
        push_literal_type_error(value, type_name, context, errors)
      }
    _ =>
      match schema_info.has_type.get(type_name) {
        Some("enum") =>
          validate_enum_literal(value, type_name, schema_info, context, errors)
        Some("input-object") =>
          validate_input_object_literal(
            value, type_name, schema_info, context, errors,
          )
        Some("scalar") => () // Custom scalar literal semantics are user-defined.
        Some(_) =>
          errors.push({
            message: "Type \"\{type_name}\" cannot be used as an input type for \{context}",
            ty: "error",
          })
        None =>
          errors.push({
            message: "Unknown input type \"\{type_name}\" for \{context}",
            ty: "error",
          })
      }
  }
}

///|
fn validate_enum_literal(
  value : @ast.Value,
  type_name : String,
  schema_info : SchemaInfo,
  context : String,
  errors : Array[ValidationError],
) -> Unit {
  guard value is EnumVal(enum_value) else {
    push_literal_type_error(value, type_name, context, errors)
    return
  }
  let mut known = false
  if schema_info.enum_values.get(type_name) is Some(values) {
    for candidate in values {
      if candidate == enum_value {
        known = true
        break
      }
    }
  }
  if !known {
    errors.push({
      message: "Unknown value \"\{enum_value}\" for enum \"\{type_name}\" in \{context}",
      ty: "error",
    })
  }
}

///|
fn validate_input_object_literal(
  value : @ast.Value,
  type_name : String,
  schema_info : SchemaInfo,
  context : String,
  errors : Array[ValidationError],
) -> Unit {
  guard value is ObjectVal(fields) else {
    push_literal_type_error(value, type_name, context, errors)
    return
  }
  guard schema_info.input_fields.get(type_name) is Some(field_defs) else {
    return
  }
  let seen : Map[String, Bool] = {}
  for field in fields {
    if seen.contains(field.0) {
      errors.push({
        message: "Duplicate input field \"\{field.0}\" for type \"\{type_name}\" in \{context}",
        ty: "error",
      })
    }
    seen[field.0] = true
    match find_input_value_def(field_defs, field.0) {
      None =>
        errors.push({
          message: "Unknown input field \"\{field.0}\" for type \"\{type_name}\" in \{context}",
          ty: "error",
        })
      Some(field_def) =>
        validate_literal_value(
          field.1,
          field_def.input_type,
          schema_info,
          "input field \"\{field.0}\" of \"\{type_name}\"",
          errors,
        )
    }
  }
  for field_def in field_defs {
    if is_required_arg(field_def) && !seen.contains(field_def.name) {
      errors.push({
        message: "Missing required input field \"\{field_def.name}\" for type \"\{type_name}\" in \{context}",
        ty: "error",
      })
    }
  }
}

///|
fn push_literal_type_error(
  value : @ast.Value,
  expected_type : String,
  context : String,
  errors : Array[ValidationError],
) -> Unit {
  errors.push({
    message: "Expected value of type \"\{expected_type}\" for \{context}, found \{literal_kind(value)}",
    ty: "error",
  })
}

///|
fn literal_kind(value : @ast.Value) -> String {
  match value {
    IntVal(_) => "Int"
    FloatVal(_) => "Float"
    StringVal(_) => "String"
    BoolVal(_) => "Boolean"
    NullVal => "null"
    EnumVal(_) => "enum"
    ListVal(_) => "list"
    ObjectVal(_) => "input object"
    Variable(_) => "variable"
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
