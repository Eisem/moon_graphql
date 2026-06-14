///|
pub fn print(doc : @ast.Document) -> String {
  let sb = StringBuilder::new()
  for i, def in doc.definitions {
    if i > 0 {
      sb.write_string("\n\n")
    }
    print_definition(sb, def)
  }
  sb.to_string()
}

///|
fn print_definition(sb : StringBuilder, def : @ast.Definition) -> Unit {
  match def {
    Operation(op) => print_operation(sb, op)
    Fragment(frag) => print_fragment(sb, frag)
    SchemaType(ts) => print_type_system_def(sb, ts)
  }
}

///|
fn print_operation(sb : StringBuilder, op : @ast.OperationDef) -> Unit {
  let is_shorthand = op.operation is Query &&
    op.name is None &&
    op.variables.is_empty() &&
    op.directives.is_empty()
  if is_shorthand {
    print_selection_set(sb, op.selections, 0)
    return
  }
  match op.operation {
    Query => sb.write_string("query")
    Mutation => sb.write_string("mutation")
    Subscription => sb.write_string("subscription")
  }
  if op.name is Some(name) {
    sb.write_string(" ")
    sb.write_string(name)
  }
  if !op.variables.is_empty() {
    print_variable_defs(sb, op.variables)
  }
  print_directives_inline(sb, op.directives)
  sb.write_string(" ")
  print_selection_set(sb, op.selections, 0)
}

///|
fn print_fragment(sb : StringBuilder, frag : @ast.FragmentDef) -> Unit {
  sb.write_string("fragment ")
  sb.write_string(frag.name)
  sb.write_string(" on ")
  sb.write_string(frag.type_condition)
  print_directives_inline(sb, frag.directives)
  sb.write_string(" ")
  print_selection_set(sb, frag.selections, 0)
}

///|
fn print_selection_set(
  sb : StringBuilder,
  selections : Array[@ast.Selection],
  indent : Int,
) -> Unit {
  sb.write_string("{\n")
  for sel in selections {
    write_indent(sb, indent + 1)
    print_selection(sb, sel, indent + 1)
    sb.write_string("\n")
  }
  write_indent(sb, indent)
  sb.write_string("}")
}

///|
fn print_selection(
  sb : StringBuilder,
  sel : @ast.Selection,
  indent : Int,
) -> Unit {
  match sel {
    Field(field) => print_field_node(sb, field, indent)
    FragmentSpread(spread) => {
      sb.write_string("...")
      sb.write_string(spread.name)
      print_directives_inline(sb, spread.directives)
    }
    InlineFragment(frag) => {
      sb.write_string("...")
      if frag.type_condition is Some(tc) {
        sb.write_string(" on ")
        sb.write_string(tc)
      }
      print_directives_inline(sb, frag.directives)
      sb.write_string(" ")
      print_selection_set(sb, frag.selections, indent)
    }
  }
}

///|
fn print_field_node(
  sb : StringBuilder,
  field : @ast.FieldNode,
  indent : Int,
) -> Unit {
  if field.field_alias is Some(a) {
    sb.write_string(a)
    sb.write_string(": ")
  }
  sb.write_string(field.name)
  if !field.arguments.is_empty() {
    print_arguments(sb, field.arguments)
  }
  print_directives_inline(sb, field.directives)
  if !field.selections.is_empty() {
    sb.write_string(" ")
    print_selection_set(sb, field.selections, indent)
  }
}

///|
fn print_arguments(sb : StringBuilder, args : Array[@ast.Argument]) -> Unit {
  sb.write_string("(")
  for i, arg in args {
    if i > 0 {
      sb.write_string(", ")
    }
    sb.write_string(arg.name)
    sb.write_string(": ")
    print_value(sb, arg.value)
  }
  sb.write_string(")")
}

///|
fn print_value(sb : StringBuilder, value : @ast.Value) -> Unit {
  match value {
    IntVal(n) => sb.write_string(n.to_string())
    FloatVal(f) => print_float(sb, f)
    StringVal(s) => print_string_value(sb, s)
    BoolVal(b) => sb.write_string(if b { "true" } else { "false" })
    NullVal => sb.write_string("null")
    EnumVal(s) => sb.write_string(s)
    Variable(s) => {
      sb.write_string("$")
      sb.write_string(s)
    }
    ListVal(values) => {
      sb.write_string("[")
      for i, v in values {
        if i > 0 {
          sb.write_string(", ")
        }
        print_value(sb, v)
      }
      sb.write_string("]")
    }
    ObjectVal(fields) => {
      sb.write_string("{")
      for i, field in fields {
        if i > 0 {
          sb.write_string(", ")
        }
        sb.write_string(field.0)
        sb.write_string(": ")
        print_value(sb, field.1)
      }
      sb.write_string("}")
    }
  }
}

///|
fn print_float(sb : StringBuilder, f : Double) -> Unit {
  let s = f.to_string()
  sb.write_string(s)
  let mut has_dot = false
  let mut has_e = false
  for c in s {
    if c == '.' {
      has_dot = true
    }
    if c == 'e' || c == 'E' {
      has_e = true
    }
  }
  if !has_dot && !has_e {
    sb.write_string(".0")
  }
}

///|
fn print_string_value(sb : StringBuilder, s : String) -> Unit {
  sb.write_string("\"")
  for c in s {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(c)
    }
  }
  sb.write_string("\"")
}

///|
fn print_type_ref(sb : StringBuilder, tr : @ast.TypeRef) -> Unit {
  match tr {
    Named(name) => sb.write_string(name)
    List(inner) => {
      sb.write_string("[")
      print_type_ref(sb, inner)
      sb.write_string("]")
    }
    NonNull(inner) => {
      print_type_ref(sb, inner)
      sb.write_string("!")
    }
  }
}

///|
fn print_directives_inline(
  sb : StringBuilder,
  directives : Array[@ast.Directive],
) -> Unit {
  for dir in directives {
    sb.write_string(" @")
    sb.write_string(dir.name)
    if !dir.arguments.is_empty() {
      print_arguments(sb, dir.arguments)
    }
  }
}

///|
fn print_variable_defs(
  sb : StringBuilder,
  vars : Array[@ast.VariableDef],
) -> Unit {
  sb.write_string("(")
  for i, v in vars {
    if i > 0 {
      sb.write_string(", ")
    }
    sb.write_string("$")
    sb.write_string(v.name)
    sb.write_string(": ")
    print_type_ref(sb, v.var_type)
    if v.default_value is Some(dv) {
      sb.write_string(" = ")
      print_value(sb, dv)
    }
    print_directives_inline(sb, v.directives)
  }
  sb.write_string(")")
}

///|
fn print_type_system_def(sb : StringBuilder, ts : @ast.TypeSystemDef) -> Unit {
  match ts {
    SchemaDefinition(schema) => print_schema_def(sb, schema)
    ScalarType(scalar) => print_scalar_type_def(sb, scalar)
    ObjectType(obj) => print_object_type_def(sb, obj)
    InterfaceType(iface) => print_interface_type_def(sb, iface)
    UnionType(u) => print_union_type_def(sb, u)
    EnumType(e) => print_enum_type_def(sb, e)
    InputObjectType(inp) => print_input_object_type_def(sb, inp)
    DirectiveDefinition(dir) => print_directive_def(sb, dir)
  }
}

///|
fn print_description(sb : StringBuilder, desc : String?, indent : Int) -> Unit {
  if desc is Some(d) {
    write_indent(sb, indent)
    print_string_value(sb, d)
    sb.write_string("\n")
  }
}

///|
fn print_schema_def(sb : StringBuilder, schema : @ast.SchemaDef) -> Unit {
  sb.write_string("schema")
  print_directives_inline(sb, schema.directives)
  sb.write_string(" {\n")
  if schema.query is Some(q) {
    sb.write_string("  query: ")
    sb.write_string(q)
    sb.write_string("\n")
  }
  if schema.mutation is Some(m) {
    sb.write_string("  mutation: ")
    sb.write_string(m)
    sb.write_string("\n")
  }
  if schema.subscription is Some(s) {
    sb.write_string("  subscription: ")
    sb.write_string(s)
    sb.write_string("\n")
  }
  sb.write_string("}")
}

///|
fn print_scalar_type_def(
  sb : StringBuilder,
  scalar : @ast.ScalarTypeDef,
) -> Unit {
  print_description(sb, scalar.description, 0)
  sb.write_string("scalar ")
  sb.write_string(scalar.name)
  print_directives_inline(sb, scalar.directives)
}

///|
fn print_object_type_def(sb : StringBuilder, obj : @ast.ObjectTypeDef) -> Unit {
  print_description(sb, obj.description, 0)
  sb.write_string("type ")
  sb.write_string(obj.name)
  if !obj.interfaces.is_empty() {
    sb.write_string(" implements ")
    for i, iface in obj.interfaces {
      if i > 0 {
        sb.write_string(" & ")
      }
      sb.write_string(iface)
    }
  }
  print_directives_inline(sb, obj.directives)
  sb.write_string(" ")
  print_field_defs(sb, obj.fields)
}

///|
fn print_interface_type_def(
  sb : StringBuilder,
  iface : @ast.InterfaceTypeDef,
) -> Unit {
  print_description(sb, iface.description, 0)
  sb.write_string("interface ")
  sb.write_string(iface.name)
  if !iface.interfaces.is_empty() {
    sb.write_string(" implements ")
    for i, impl_iface in iface.interfaces {
      if i > 0 {
        sb.write_string(" & ")
      }
      sb.write_string(impl_iface)
    }
  }
  print_directives_inline(sb, iface.directives)
  sb.write_string(" ")
  print_field_defs(sb, iface.fields)
}

///|
fn print_union_type_def(sb : StringBuilder, u : @ast.UnionTypeDef) -> Unit {
  print_description(sb, u.description, 0)
  sb.write_string("union ")
  sb.write_string(u.name)
  print_directives_inline(sb, u.directives)
  sb.write_string(" = ")
  for i, mem in u.members {
    if i > 0 {
      sb.write_string(" | ")
    }
    sb.write_string(mem)
  }
}

///|
fn print_enum_type_def(sb : StringBuilder, e : @ast.EnumTypeDef) -> Unit {
  print_description(sb, e.description, 0)
  sb.write_string("enum ")
  sb.write_string(e.name)
  print_directives_inline(sb, e.directives)
  sb.write_string(" {\n")
  for val in e.values {
    print_description(sb, val.description, 1)
    sb.write_string("  ")
    sb.write_string(val.name)
    print_directives_inline(sb, val.directives)
    sb.write_string("\n")
  }
  sb.write_string("}")
}

///|
fn print_input_object_type_def(
  sb : StringBuilder,
  inp : @ast.InputObjectTypeDef,
) -> Unit {
  print_description(sb, inp.description, 0)
  sb.write_string("input ")
  sb.write_string(inp.name)
  print_directives_inline(sb, inp.directives)
  sb.write_string(" {\n")
  for field in inp.fields {
    print_description(sb, field.description, 1)
    sb.write_string("  ")
    sb.write_string(field.name)
    sb.write_string(": ")
    print_type_ref(sb, field.input_type)
    if field.default_value is Some(dv) {
      sb.write_string(" = ")
      print_value(sb, dv)
    }
    print_directives_inline(sb, field.directives)
    sb.write_string("\n")
  }
  sb.write_string("}")
}

///|
fn print_directive_def(sb : StringBuilder, dir : @ast.DirectiveDef) -> Unit {
  print_description(sb, dir.description, 0)
  sb.write_string("directive @")
  sb.write_string(dir.name)
  if !dir.arguments.is_empty() {
    print_input_value_defs_inline(sb, dir.arguments)
  }
  if dir.repeatable {
    sb.write_string(" repeatable")
  }
  sb.write_string(" on ")
  for i, loc in dir.locations {
    if i > 0 {
      sb.write_string(" | ")
    }
    sb.write_string(loc)
  }
}

///|
fn print_field_defs(sb : StringBuilder, fields : Array[@ast.FieldDef]) -> Unit {
  sb.write_string("{\n")
  for field in fields {
    print_description(sb, field.description, 1)
    sb.write_string("  ")
    sb.write_string(field.name)
    if !field.arguments.is_empty() {
      print_input_value_defs_inline(sb, field.arguments)
    }
    sb.write_string(": ")
    print_type_ref(sb, field.field_type)
    print_directives_inline(sb, field.directives)
    sb.write_string("\n")
  }
  sb.write_string("}")
}

///|
fn print_input_value_defs_inline(
  sb : StringBuilder,
  defs : Array[@ast.InputValueDef],
) -> Unit {
  sb.write_string("(")
  for i, def in defs {
    if i > 0 {
      sb.write_string(", ")
    }
    sb.write_string(def.name)
    sb.write_string(": ")
    print_type_ref(sb, def.input_type)
    if def.default_value is Some(dv) {
      sb.write_string(" = ")
      print_value(sb, dv)
    }
    print_directives_inline(sb, def.directives)
  }
  sb.write_string(")")
}

///|
fn write_indent(sb : StringBuilder, level : Int) -> Unit {
  for _ in 0..<level {
    sb.write_string("  ")
  }
}
