///|
priv struct Parser {
  tokens : Array[@lexer.Token]
  mut pos : Int
}

///|
fn Parser::peek(self : Parser) -> @lexer.TokenKind {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos].kind
  } else {
    Eof
  }
}

///|
fn Parser::peek_loc(self : Parser) -> @ast.Location {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos].loc
  } else {
    { line: 0, col: 0 }
  }
}

///|
fn Parser::advance(self : Parser) -> @lexer.Token raise @ast.ParseError {
  if self.pos >= self.tokens.length() {
    raise @ast.ParseError::UnexpectedEof(expected="token")
  }
  let tok = self.tokens[self.pos]
  self.pos += 1
  tok
}

///|
fn Parser::expect_name(self : Parser) -> String raise @ast.ParseError {
  let tok = self.advance()
  match tok.kind {
    Name(s) => s
    _ =>
      raise @ast.ParseError::UnexpectedToken(
        expected="name",
        got="\{tok.kind}",
        loc=tok.loc,
      )
  }
}

///|
fn Parser::expect_token(
  self : Parser,
  expected : @lexer.TokenKind,
) -> Unit raise @ast.ParseError {
  let tok = self.advance()
  if tok.kind != expected {
    raise @ast.ParseError::UnexpectedToken(
      expected="\{expected}",
      got="\{tok.kind}",
      loc=tok.loc,
    )
  }
}

///|
fn parse_int_literal(s : String) -> Int {
  let mut result = 0
  let mut neg = false
  let mut first = true
  for c in s {
    if first && c == '-' {
      neg = true
      first = false
      continue
    }
    first = false
    result = result * 10 + (c.to_int() - 48)
  }
  if neg {
    -result
  } else {
    result
  }
}

///|
fn parse_float_literal(s : String) -> Double {
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let len = chars.length()
  let mut i = 0
  let mut neg = false
  if i < len && chars[i] == '-' {
    neg = true
    i += 1
  }
  let mut int_part = 0.0
  while i < len && chars[i] >= '0' && chars[i] <= '9' {
    int_part = int_part * 10.0 + (chars[i].to_int() - 48).to_double()
    i += 1
  }
  let mut frac_part = 0.0
  if i < len && chars[i] == '.' {
    i += 1
    let mut divisor = 10.0
    while i < len && chars[i] >= '0' && chars[i] <= '9' {
      frac_part = frac_part + (chars[i].to_int() - 48).to_double() / divisor
      divisor = divisor * 10.0
      i += 1
    }
  }
  let mut result = int_part + frac_part
  if i < len && (chars[i] == 'e' || chars[i] == 'E') {
    i += 1
    let mut exp_neg = false
    if i < len && chars[i] == '+' {
      i += 1
    } else if i < len && chars[i] == '-' {
      exp_neg = true
      i += 1
    }
    let mut exp = 0
    while i < len && chars[i] >= '0' && chars[i] <= '9' {
      exp = exp * 10 + (chars[i].to_int() - 48)
      i += 1
    }
    let mut factor = 1.0
    for _ in 0..<exp {
      factor = factor * 10.0
    }
    if exp_neg {
      result = result / factor
    } else {
      result = result * factor
    }
  }
  if neg {
    -result
  } else {
    result
  }
}

///|
pub fn parse(input : String) -> @ast.Document raise @ast.ParseError {
  let tokens = @lexer.tokenize(input)
  let parser : Parser = { tokens, pos: 0 }
  parser.parse_document()
}

///|
fn Parser::parse_document(self : Parser) -> @ast.Document raise @ast.ParseError {
  let definitions : Array[@ast.Definition] = []
  while !(self.peek() is Eof) {
    definitions.push(self.parse_definition())
  }
  { definitions, }
}

///|
fn Parser::parse_definition(
  self : Parser,
) -> @ast.Definition raise @ast.ParseError {
  match self.peek() {
    Name("query") | Name("mutation") | Name("subscription") =>
      @ast.Definition::Operation(self.parse_operation())
    Name("fragment") => @ast.Definition::Fragment(self.parse_fragment())
    LBrace => @ast.Definition::Operation(self.parse_operation())
    Name("type")
    | Name("interface")
    | Name("union")
    | Name("enum")
    | Name("input")
    | Name("scalar")
    | Name("schema")
    | Name("directive")
    | StringValue(_)
    | BlockString(_) =>
      @ast.Definition::SchemaType(self.parse_type_system_def())
    _ => {
      let loc = self.peek_loc()
      raise @ast.ParseError::UnexpectedToken(
        expected="definition",
        got="\{self.peek()}",
        loc~,
      )
    }
  }
}

///|
fn Parser::parse_operation(
  self : Parser,
) -> @ast.OperationDef raise @ast.ParseError {
  if self.peek() is LBrace {
    let selections = self.parse_selection_set()
    return {
      operation: Query,
      name: None,
      variables: [],
      directives: [],
      selections,
    }
  }
  let op_type = match self.peek() {
    Name("query") => {
      let _ = self.advance()
      @ast.OperationType::Query
    }
    Name("mutation") => {
      let _ = self.advance()
      @ast.OperationType::Mutation
    }
    Name("subscription") => {
      let _ = self.advance()
      @ast.OperationType::Subscription
    }
    _ => {
      let loc = self.peek_loc()
      raise @ast.ParseError::UnexpectedToken(
        expected="operation type",
        got="\{self.peek()}",
        loc~,
      )
    }
  }
  let name : String? = if self.peek() is Name(_) &&
    !(self.peek() is Name("query")) &&
    !(self.peek() is Name("mutation")) &&
    !(self.peek() is Name("subscription")) &&
    !(self.peek() is Name("on")) {
    match self.peek() {
      Name(_) => Some(self.expect_name())
      _ => None
    }
  } else {
    None
  }
  let variables = if self.peek() is LParen {
    self.parse_variable_definitions()
  } else {
    []
  }
  let directives = self.parse_directives()
  let selections = self.parse_selection_set()
  { operation: op_type, name, variables, directives, selections }
}

///|
fn Parser::parse_selection_set(
  self : Parser,
) -> Array[@ast.Selection] raise @ast.ParseError {
  self.expect_token(LBrace)
  let selections : Array[@ast.Selection] = []
  while !(self.peek() is RBrace) && !(self.peek() is Eof) {
    selections.push(self.parse_selection())
  }
  self.expect_token(RBrace)
  selections
}

///|
fn Parser::parse_selection(
  self : Parser,
) -> @ast.Selection raise @ast.ParseError {
  if self.peek() is Spread {
    let _ = self.advance()
    if self.peek() is Name("on") {
      return @ast.Selection::InlineFragment(self.parse_inline_fragment())
    }
    if self.peek() is LBrace {
      return @ast.Selection::InlineFragment(
        self.parse_inline_fragment_no_type(),
      )
    }
    if self.peek() is At {
      return @ast.Selection::InlineFragment(
        self.parse_inline_fragment_no_type(),
      )
    }
    let name = self.expect_name()
    let directives = self.parse_directives()
    @ast.Selection::FragmentSpread({ name, directives })
  } else {
    @ast.Selection::Field(self.parse_field())
  }
}

///|
fn Parser::parse_inline_fragment(
  self : Parser,
) -> @ast.InlineFragmentNode raise @ast.ParseError {
  let _ = self.advance()
  let type_name = self.expect_name()
  let directives = self.parse_directives()
  let selections = self.parse_selection_set()
  { type_condition: Some(type_name), directives, selections }
}

///|
fn Parser::parse_inline_fragment_no_type(
  self : Parser,
) -> @ast.InlineFragmentNode raise @ast.ParseError {
  let directives = self.parse_directives()
  let selections = self.parse_selection_set()
  { type_condition: None, directives, selections }
}

///|
fn Parser::parse_field(self : Parser) -> @ast.FieldNode raise @ast.ParseError {
  let first_name = self.expect_name()
  let mut field_alias : String? = None
  let mut name = first_name
  if self.peek() is Colon {
    let _ = self.advance()
    field_alias = Some(first_name)
    name = self.expect_name()
  }
  let arguments = if self.peek() is LParen {
    self.parse_arguments()
  } else {
    []
  }
  let directives = self.parse_directives()
  let selections = if self.peek() is LBrace {
    self.parse_selection_set()
  } else {
    []
  }
  { field_alias, name, arguments, directives, selections }
}

///|
fn Parser::parse_arguments(
  self : Parser,
) -> Array[@ast.Argument] raise @ast.ParseError {
  self.expect_token(LParen)
  let args : Array[@ast.Argument] = []
  while !(self.peek() is RParen) && !(self.peek() is Eof) {
    let name = self.expect_name()
    self.expect_token(Colon)
    let value = self.parse_value()
    args.push({ name, value })
  }
  self.expect_token(RParen)
  args
}

///|
fn Parser::parse_value(self : Parser) -> @ast.Value raise @ast.ParseError {
  match self.peek() {
    Dollar => {
      let _ = self.advance()
      let name = self.expect_name()
      @ast.Value::Variable(name)
    }
    IntValue(s) => {
      let _ = self.advance()
      @ast.Value::IntVal(parse_int_literal(s))
    }
    FloatValue(s) => {
      let _ = self.advance()
      @ast.Value::FloatVal(parse_float_literal(s))
    }
    StringValue(s) => {
      let _ = self.advance()
      @ast.Value::StringVal(s)
    }
    BlockString(s) => {
      let _ = self.advance()
      @ast.Value::StringVal(s)
    }
    Name("true") => {
      let _ = self.advance()
      @ast.Value::BoolVal(true)
    }
    Name("false") => {
      let _ = self.advance()
      @ast.Value::BoolVal(false)
    }
    Name("null") => {
      let _ = self.advance()
      @ast.Value::NullVal
    }
    Name(s) => {
      let _ = self.advance()
      @ast.Value::EnumVal(s)
    }
    LBracket => {
      let _ = self.advance()
      let values : Array[@ast.Value] = []
      while !(self.peek() is RBracket) && !(self.peek() is Eof) {
        values.push(self.parse_value())
      }
      self.expect_token(RBracket)
      @ast.Value::ListVal(values)
    }
    LBrace => {
      let _ = self.advance()
      let fields : Array[(String, @ast.Value)] = []
      while !(self.peek() is RBrace) && !(self.peek() is Eof) {
        let field_name = self.expect_name()
        self.expect_token(Colon)
        let field_value = self.parse_value()
        fields.push((field_name, field_value))
      }
      self.expect_token(RBrace)
      @ast.Value::ObjectVal(fields)
    }
    _ => {
      let loc = self.peek_loc()
      raise @ast.ParseError::UnexpectedToken(
        expected="value",
        got="\{self.peek()}",
        loc~,
      )
    }
  }
}

///|
fn Parser::parse_type_ref(self : Parser) -> @ast.TypeRef raise @ast.ParseError {
  let base = if self.peek() is LBracket {
    let _ = self.advance()
    let inner = self.parse_type_ref()
    self.expect_token(RBracket)
    @ast.TypeRef::List(inner)
  } else {
    let name = self.expect_name()
    @ast.TypeRef::Named(name)
  }
  if self.peek() is Bang {
    let _ = self.advance()
    @ast.TypeRef::NonNull(base)
  } else {
    base
  }
}

///|
fn Parser::parse_directives(
  self : Parser,
) -> Array[@ast.Directive] raise @ast.ParseError {
  let directives : Array[@ast.Directive] = []
  while self.peek() is At {
    let _ = self.advance()
    let name = self.expect_name()
    let arguments = if self.peek() is LParen {
      self.parse_arguments()
    } else {
      []
    }
    directives.push({ name, arguments })
  }
  directives
}

///|
fn Parser::parse_variable_definitions(
  self : Parser,
) -> Array[@ast.VariableDef] raise @ast.ParseError {
  self.expect_token(LParen)
  let vars : Array[@ast.VariableDef] = []
  while !(self.peek() is RParen) && !(self.peek() is Eof) {
    self.expect_token(Dollar)
    let name = self.expect_name()
    self.expect_token(Colon)
    let var_type = self.parse_type_ref()
    let default_value : @ast.Value? = if self.peek() is Equals {
      let _ = self.advance()
      Some(self.parse_value())
    } else {
      None
    }
    let directives = self.parse_directives()
    vars.push({ name, var_type, default_value, directives })
  }
  self.expect_token(RParen)
  vars
}

///|
fn Parser::parse_fragment(
  self : Parser,
) -> @ast.FragmentDef raise @ast.ParseError {
  let _ = self.advance()
  let name = self.expect_name()
  let on_tok = self.expect_name()
  if on_tok != "on" {
    let loc = self.peek_loc()
    raise @ast.ParseError::UnexpectedToken(expected="on", got=on_tok, loc~)
  }
  let type_condition = self.expect_name()
  let directives = self.parse_directives()
  let selections = self.parse_selection_set()
  { name, type_condition, directives, selections }
}
