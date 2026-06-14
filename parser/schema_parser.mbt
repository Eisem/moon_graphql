///|
fn Parser::parse_description(self : Parser) -> String? raise @ast.ParseError {
  match self.peek() {
    StringValue(s) | BlockString(s) => {
      let _ = self.advance()
      Some(s)
    }
    _ => None
  }
}

///|
fn Parser::parse_type_system_def(
  self : Parser,
) -> @ast.TypeSystemDef raise @ast.ParseError {
  let description = self.parse_description()
  match self.peek() {
    Name("type") =>
      @ast.TypeSystemDef::ObjectType(self.parse_object_type_def(description))
    Name("interface") =>
      @ast.TypeSystemDef::InterfaceType(
        self.parse_interface_type_def(description),
      )
    Name("union") =>
      @ast.TypeSystemDef::UnionType(self.parse_union_type_def(description))
    Name("enum") =>
      @ast.TypeSystemDef::EnumType(self.parse_enum_type_def(description))
    Name("input") =>
      @ast.TypeSystemDef::InputObjectType(
        self.parse_input_object_type_def(description),
      )
    Name("scalar") =>
      @ast.TypeSystemDef::ScalarType(self.parse_scalar_type_def(description))
    Name("schema") =>
      @ast.TypeSystemDef::SchemaDefinition(self.parse_schema_def())
    Name("directive") =>
      @ast.TypeSystemDef::DirectiveDefinition(
        self.parse_directive_def(description),
      )
    _ => {
      let loc = self.peek_loc()
      raise @ast.ParseError::UnexpectedToken(
        expected="type system definition",
        got="\{self.peek()}",
        loc~,
      )
    }
  }
}

///|
fn Parser::parse_object_type_def(
  self : Parser,
  description : String?,
) -> @ast.ObjectTypeDef raise @ast.ParseError {
  let _ = self.advance()
  let name = self.expect_name()
  let interfaces = if self.peek() is Name("implements") {
    let _ = self.advance()
    self.parse_implements_interfaces()
  } else {
    []
  }
  let directives = self.parse_directives()
  let fields = self.parse_field_defs()
  { description, name, interfaces, directives, fields }
}

///|
fn Parser::parse_implements_interfaces(
  self : Parser,
) -> Array[String] raise @ast.ParseError {
  if self.peek() is Amp {
    let _ = self.advance()
  }
  let interfaces : Array[String] = []
  interfaces.push(self.expect_name())
  while self.peek() is Amp {
    let _ = self.advance()
    interfaces.push(self.expect_name())
  }
  interfaces
}

///|
fn Parser::parse_field_defs(
  self : Parser,
) -> Array[@ast.FieldDef] raise @ast.ParseError {
  self.expect_token(LBrace)
  let fields : Array[@ast.FieldDef] = []
  while !(self.peek() is RBrace) && !(self.peek() is Eof) {
    fields.push(self.parse_field_def())
  }
  self.expect_token(RBrace)
  fields
}

///|
fn Parser::parse_field_def(
  self : Parser,
) -> @ast.FieldDef raise @ast.ParseError {
  let description = self.parse_description()
  let name = self.expect_name()
  let arguments = if self.peek() is LParen {
    self.parse_input_value_defs()
  } else {
    []
  }
  self.expect_token(Colon)
  let field_type = self.parse_type_ref()
  let directives = self.parse_directives()
  { description, name, arguments, field_type, directives }
}

///|
fn Parser::parse_input_value_defs(
  self : Parser,
) -> Array[@ast.InputValueDef] raise @ast.ParseError {
  self.expect_token(LParen)
  let defs : Array[@ast.InputValueDef] = []
  while !(self.peek() is RParen) && !(self.peek() is Eof) {
    defs.push(self.parse_input_value_def())
  }
  self.expect_token(RParen)
  defs
}

///|
fn Parser::parse_input_value_def(
  self : Parser,
) -> @ast.InputValueDef raise @ast.ParseError {
  let description = self.parse_description()
  let name = self.expect_name()
  self.expect_token(Colon)
  let input_type = self.parse_type_ref()
  let default_value : @ast.Value? = if self.peek() is Equals {
    let _ = self.advance()
    Some(self.parse_value())
  } else {
    None
  }
  let directives = self.parse_directives()
  { description, name, input_type, default_value, directives }
}

///|
fn Parser::parse_interface_type_def(
  self : Parser,
  description : String?,
) -> @ast.InterfaceTypeDef raise @ast.ParseError {
  let _ = self.advance()
  let name = self.expect_name()
  let interfaces = if self.peek() is Name("implements") {
    let _ = self.advance()
    self.parse_implements_interfaces()
  } else {
    []
  }
  let directives = self.parse_directives()
  let fields = self.parse_field_defs()
  { description, name, interfaces, directives, fields }
}

///|
fn Parser::parse_union_type_def(
  self : Parser,
  description : String?,
) -> @ast.UnionTypeDef raise @ast.ParseError {
  let _ = self.advance()
  let name = self.expect_name()
  let directives = self.parse_directives()
  self.expect_token(Equals)
  if self.peek() is Pipe {
    let _ = self.advance()
  }
  let members : Array[String] = []
  members.push(self.expect_name())
  while self.peek() is Pipe {
    let _ = self.advance()
    members.push(self.expect_name())
  }
  { description, name, directives, members }
}

///|
fn Parser::parse_enum_type_def(
  self : Parser,
  description : String?,
) -> @ast.EnumTypeDef raise @ast.ParseError {
  let _ = self.advance()
  let name = self.expect_name()
  let directives = self.parse_directives()
  self.expect_token(LBrace)
  let values : Array[@ast.EnumValueDef] = []
  while !(self.peek() is RBrace) && !(self.peek() is Eof) {
    let desc = self.parse_description()
    let val_name = self.expect_name()
    let val_directives = self.parse_directives()
    values.push({
      description: desc,
      name: val_name,
      directives: val_directives,
    })
  }
  self.expect_token(RBrace)
  { description, name, directives, values }
}

///|
fn Parser::parse_input_object_type_def(
  self : Parser,
  description : String?,
) -> @ast.InputObjectTypeDef raise @ast.ParseError {
  let _ = self.advance()
  let name = self.expect_name()
  let directives = self.parse_directives()
  self.expect_token(LBrace)
  let fields : Array[@ast.InputValueDef] = []
  while !(self.peek() is RBrace) && !(self.peek() is Eof) {
    fields.push(self.parse_input_value_def())
  }
  self.expect_token(RBrace)
  { description, name, directives, fields }
}

///|
fn Parser::parse_scalar_type_def(
  self : Parser,
  description : String?,
) -> @ast.ScalarTypeDef raise @ast.ParseError {
  let _ = self.advance()
  let name = self.expect_name()
  let directives = self.parse_directives()
  { description, name, directives }
}

///|
fn Parser::parse_schema_def(
  self : Parser,
) -> @ast.SchemaDef raise @ast.ParseError {
  let _ = self.advance()
  let directives = self.parse_directives()
  self.expect_token(LBrace)
  let mut query : String? = None
  let mut mutation : String? = None
  let mut subscription : String? = None
  while !(self.peek() is RBrace) && !(self.peek() is Eof) {
    let op_name = self.expect_name()
    self.expect_token(Colon)
    let type_name = self.expect_name()
    match op_name {
      "query" => query = Some(type_name)
      "mutation" => mutation = Some(type_name)
      "subscription" => subscription = Some(type_name)
      _ => {
        let loc = self.peek_loc()
        raise @ast.ParseError::InvalidSyntax(
          message="unknown schema operation: \{op_name}",
          loc~,
        )
      }
    }
  }
  self.expect_token(RBrace)
  { directives, query, mutation, subscription }
}

///|
fn Parser::parse_directive_def(
  self : Parser,
  description : String?,
) -> @ast.DirectiveDef raise @ast.ParseError {
  let _ = self.advance()
  self.expect_token(At)
  let name = self.expect_name()
  let arguments = if self.peek() is LParen {
    self.parse_input_value_defs()
  } else {
    []
  }
  let repeatable = if self.peek() is Name("repeatable") {
    let _ = self.advance()
    true
  } else {
    false
  }
  let on_keyword = self.expect_name()
  if on_keyword != "on" {
    let loc = self.peek_loc()
    raise @ast.ParseError::UnexpectedToken(expected="on", got=on_keyword, loc~)
  }
  if self.peek() is Pipe {
    let _ = self.advance()
  }
  let locations : Array[String] = []
  locations.push(self.expect_name())
  while self.peek() is Pipe {
    let _ = self.advance()
    locations.push(self.expect_name())
  }
  { description, name, arguments, repeatable, locations }
}
