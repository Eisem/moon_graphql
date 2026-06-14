///|
priv struct Lexer {
  input : String
  mut pos : Int
  mut line : Int
  mut col : Int
}

///|
pub fn tokenize(input : String) -> Array[Token] raise @ast.ParseError {
  let lexer : Lexer = { input, pos: 0, line: 1, col: 1 }
  let tokens : Array[Token] = []
  while lexer.pos < lexer.input.length() {
    lexer.skip_insignificant()
    if lexer.pos >= lexer.input.length() {
      break
    }
    let start_loc : @ast.Location = { line: lexer.line, col: lexer.col }
    let c = lexer.peek()
    if c == '#' {
      lexer.skip_comment()
      continue
    }
    if c == '!' {
      let _ = lexer.advance()
      tokens.push({ kind: Bang, loc: start_loc })
    } else if c == '$' {
      let _ = lexer.advance()
      tokens.push({ kind: Dollar, loc: start_loc })
    } else if c == '&' {
      let _ = lexer.advance()
      tokens.push({ kind: Amp, loc: start_loc })
    } else if c == '(' {
      let _ = lexer.advance()
      tokens.push({ kind: LParen, loc: start_loc })
    } else if c == ')' {
      let _ = lexer.advance()
      tokens.push({ kind: RParen, loc: start_loc })
    } else if c == ':' {
      let _ = lexer.advance()
      tokens.push({ kind: Colon, loc: start_loc })
    } else if c == '=' {
      let _ = lexer.advance()
      tokens.push({ kind: Equals, loc: start_loc })
    } else if c == '@' {
      let _ = lexer.advance()
      tokens.push({ kind: At, loc: start_loc })
    } else if c == '[' {
      let _ = lexer.advance()
      tokens.push({ kind: LBracket, loc: start_loc })
    } else if c == ']' {
      let _ = lexer.advance()
      tokens.push({ kind: RBracket, loc: start_loc })
    } else if c == '{' {
      let _ = lexer.advance()
      tokens.push({ kind: LBrace, loc: start_loc })
    } else if c == '}' {
      let _ = lexer.advance()
      tokens.push({ kind: RBrace, loc: start_loc })
    } else if c == '|' {
      let _ = lexer.advance()
      tokens.push({ kind: Pipe, loc: start_loc })
    } else if c == '.' {
      tokens.push(lexer.read_spread())
    } else if c == '"' {
      tokens.push(lexer.read_string_value())
    } else if (c >= '0' && c <= '9') || c == '-' {
      tokens.push(lexer.read_number())
    } else if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' {
      tokens.push(lexer.read_name(start_loc))
    } else {
      let _ = lexer.advance()
      raise @ast.ParseError::UnexpectedChar(char=c, loc=start_loc)
    }
  }
  tokens.push({ kind: Eof, loc: { line: lexer.line, col: lexer.col } })
  tokens
}

///|
fn Lexer::peek(self : Lexer) -> Char {
  if self.pos >= self.input.length() {
    '\u0000'
  } else {
    match self.input.get_char(self.pos) {
      Some(c) => c
      None => '\u0000'
    }
  }
}

///|
fn Lexer::advance(self : Lexer) -> Char {
  let c = self.peek()
  if c == '\n' {
    self.line = self.line + 1
    self.col = 1
  } else {
    self.col = self.col + 1
  }
  self.pos = self.pos + 1
  c
}

///|
fn Lexer::skip_insignificant(self : Lexer) -> Unit {
  while self.pos < self.input.length() {
    let c = self.peek()
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == ',' {
      let _ = self.advance()
    } else {
      break
    }
  }
}

///|
fn Lexer::skip_comment(self : Lexer) -> Unit {
  while self.pos < self.input.length() && self.peek() != '\n' {
    let _ = self.advance()
  }
}

///|
fn Lexer::read_name(self : Lexer, start_loc : @ast.Location) -> Token {
  let start = self.pos
  while self.pos < self.input.length() {
    let c = self.peek()
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' {
      let _ = self.advance()
    } else {
      break
    }
  }
  let name = self.input[start:self.pos].to_owned()
  { kind: Name(name), loc: start_loc }
}

///|
fn Lexer::read_number(self : Lexer) -> Token raise @ast.ParseError {
  let start_loc : @ast.Location = { line: self.line, col: self.col }
  let start = self.pos
  let mut is_float = false
  if self.peek() == '-' {
    let _ = self.advance()
  }
  while self.pos < self.input.length() &&
        self.peek() >= '0' &&
        self.peek() <= '9' {
    let _ = self.advance()
  }
  if self.pos < self.input.length() && self.peek() == '.' {
    is_float = true
    let _ = self.advance()
    while self.pos < self.input.length() &&
          self.peek() >= '0' &&
          self.peek() <= '9' {
      let _ = self.advance()
    }
  }
  if self.pos < self.input.length() &&
    (self.peek() == 'e' || self.peek() == 'E') {
    is_float = true
    let _ = self.advance()
    if self.pos < self.input.length() &&
      (self.peek() == '+' || self.peek() == '-') {
      let _ = self.advance()
    }
    while self.pos < self.input.length() &&
          self.peek() >= '0' &&
          self.peek() <= '9' {
      let _ = self.advance()
    }
  }
  let text = self.input[start:self.pos].to_owned()
  let kind = if is_float { FloatValue(text) } else { IntValue(text) }
  { kind, loc: start_loc }
}

///|
fn Lexer::read_string_value(self : Lexer) -> Token raise @ast.ParseError {
  let start_loc : @ast.Location = { line: self.line, col: self.col }
  let _ = self.advance()
  if self.pos + 1 < self.input.length() && self.peek() == '"' {
    let saved_pos = self.pos
    let _ = self.advance()
    if self.pos < self.input.length() && self.peek() == '"' {
      let _ = self.advance()
      return self.read_block_string(start_loc)
    }
    self.pos = saved_pos
    self.col = self.col - 1
  }
  if self.peek() == '"' {
    let _ = self.advance()
    return { kind: StringValue(""), loc: start_loc }
  }
  let buf = StringBuilder::new()
  while self.pos < self.input.length() {
    let c = self.advance()
    if c == '"' {
      return { kind: StringValue(buf.to_string()), loc: start_loc }
    }
    if c == '\\' {
      let escaped = self.advance()
      match escaped {
        'n' => buf.write_char('\n')
        't' => buf.write_char('\t')
        'r' => buf.write_char('\r')
        '\\' => buf.write_char('\\')
        '"' => buf.write_char('"')
        '/' => buf.write_char('/')
        _ => {
          buf.write_char('\\')
          buf.write_char(escaped)
        }
      }
    } else {
      buf.write_char(c)
    }
  }
  raise @ast.ParseError::UnterminatedString(loc=start_loc)
}

///|
fn Lexer::read_block_string(
  self : Lexer,
  start_loc : @ast.Location,
) -> Token raise @ast.ParseError {
  let buf = StringBuilder::new()
  while self.pos < self.input.length() {
    let c = self.advance()
    if c == '"' && self.pos < self.input.length() && self.peek() == '"' {
      let _ = self.advance()
      if self.pos < self.input.length() && self.peek() == '"' {
        let _ = self.advance()
        return { kind: BlockString(buf.to_string()), loc: start_loc }
      }
      buf.write_char('"')
      buf.write_char('"')
    } else {
      buf.write_char(c)
    }
  }
  raise @ast.ParseError::UnterminatedString(loc=start_loc)
}

///|
fn Lexer::read_spread(self : Lexer) -> Token raise @ast.ParseError {
  let start_loc : @ast.Location = { line: self.line, col: self.col }
  let _ = self.advance()
  if self.pos < self.input.length() && self.peek() == '.' {
    let _ = self.advance()
    if self.pos < self.input.length() && self.peek() == '.' {
      let _ = self.advance()
      return { kind: Spread, loc: start_loc }
    }
  }
  raise @ast.ParseError::InvalidSyntax(message="expected '...'", loc=start_loc)
}
