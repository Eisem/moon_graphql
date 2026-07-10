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
fn Lexer::peek_offset(self : Lexer, offset : Int) -> Char {
  let index = self.pos + offset
  if index >= self.input.length() {
    '\u0000'
  } else {
    match self.input.get_char(index) {
      Some(c) => c
      None => '\u0000'
    }
  }
}

///|
fn Lexer::advance(self : Lexer) -> Char {
  let c = self.peek()
  if c == '\r' {
    self.line += 1
    self.col = 1
  } else if c == '\n' {
    let follows_cr = self.pos > 0 &&
      self.input.get_char(self.pos - 1) == Some('\r')
    if !follows_cr {
      self.line += 1
    }
    self.col = 1
  } else {
    self.col += 1
  }
  self.pos += 1
  c
}

///|
fn Lexer::skip_insignificant(self : Lexer) -> Unit {
  while self.pos < self.input.length() {
    let c = self.peek()
    if c == ' ' ||
      c == '\t' ||
      c == '\r' ||
      c == '\n' ||
      c == ',' ||
      c == '\uFEFF' {
      let _ = self.advance()
    } else {
      break
    }
  }
}

///|
fn Lexer::skip_comment(self : Lexer) -> Unit {
  while self.pos < self.input.length() &&
        self.peek() != '\n' &&
        self.peek() != '\r' {
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
  if self.pos >= self.input.length() || !is_digit(self.peek()) {
    return self.invalid_number(start, start_loc)
  }
  if self.peek() == '0' {
    let _ = self.advance()
    if self.pos < self.input.length() && is_digit(self.peek()) {
      return self.invalid_number(start, start_loc)
    }
  } else {
    while self.pos < self.input.length() && is_digit(self.peek()) {
      let _ = self.advance()
    }
  }
  if self.pos < self.input.length() && self.peek() == '.' {
    is_float = true
    let _ = self.advance()
    if self.pos >= self.input.length() || !is_digit(self.peek()) {
      return self.invalid_number(start, start_loc)
    }
    while self.pos < self.input.length() && is_digit(self.peek()) {
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
    if self.pos >= self.input.length() || !is_digit(self.peek()) {
      return self.invalid_number(start, start_loc)
    }
    while self.pos < self.input.length() && is_digit(self.peek()) {
      let _ = self.advance()
    }
  }
  if self.pos < self.input.length() &&
    (self.peek() == '.' || is_name_start(self.peek())) {
    return self.invalid_number(start, start_loc)
  }
  let text = self.input[start:self.pos].to_owned()
  let kind = if is_float { FloatValue(text) } else { IntValue(text) }
  { kind, loc: start_loc }
}

///|
fn Lexer::invalid_number(
  self : Lexer,
  start : Int,
  loc : @ast.Location,
) -> Token raise @ast.ParseError {
  while self.pos < self.input.length() {
    let c = self.peek()
    if is_name_continue(c) || c == '.' || c == '+' || c == '-' {
      let _ = self.advance()
    } else {
      break
    }
  }
  let text = self.input[start:self.pos].to_owned()
  raise @ast.ParseError::InvalidNumber(text~, loc~)
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_name_start(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn is_name_continue(c : Char) -> Bool {
  is_name_start(c) || is_digit(c)
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
      let escape_loc : @ast.Location = { line: self.line, col: self.col - 1 }
      if self.pos >= self.input.length() {
        raise @ast.ParseError::UnterminatedString(loc=start_loc)
      }
      let escaped = self.advance()
      match escaped {
        'b' => buf.write_char('\b')
        'f' => buf.write_char('\u000c')
        'n' => buf.write_char('\n')
        't' => buf.write_char('\t')
        'r' => buf.write_char('\r')
        '\\' => buf.write_char('\\')
        '"' => buf.write_char('"')
        '/' => buf.write_char('/')
        'u' => buf.write_char(self.read_unicode_escape(escape_loc))
        _ =>
          raise @ast.ParseError::InvalidSyntax(
            message="invalid string escape for character '\{escaped}'",
            loc=escape_loc,
          )
      }
    } else if c == '\n' || c == '\r' {
      raise @ast.ParseError::InvalidSyntax(
        message="line terminator is not allowed in a quoted string",
        loc=start_loc,
      )
    } else if c.to_int() < 0x20 && c != '\t' {
      raise @ast.ParseError::InvalidSyntax(
        message="control character is not allowed in a quoted string",
        loc=start_loc,
      )
    } else {
      buf.write_char(c)
    }
  }
  raise @ast.ParseError::UnterminatedString(loc=start_loc)
}

///|
fn Lexer::read_unicode_escape(
  self : Lexer,
  loc : @ast.Location,
) -> Char raise @ast.ParseError {
  let first = self.read_four_hex_digits(loc)
  if first >= 0xD800 && first <= 0xDBFF {
    if self.pos + 1 >= self.input.length() || self.peek() != '\\' {
      raise @ast.ParseError::InvalidSyntax(
        message="high surrogate must be followed by a low surrogate",
        loc~,
      )
    }
    let _ = self.advance()
    if self.peek() != 'u' {
      raise @ast.ParseError::InvalidSyntax(
        message="high surrogate must be followed by a Unicode escape",
        loc~,
      )
    }
    let _ = self.advance()
    let second = self.read_four_hex_digits(loc)
    if second < 0xDC00 || second > 0xDFFF {
      raise @ast.ParseError::InvalidSyntax(
        message="high surrogate must be followed by a low surrogate",
        loc~,
      )
    }
    return (0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)).unsafe_to_char()
  }
  if first >= 0xDC00 && first <= 0xDFFF {
    raise @ast.ParseError::InvalidSyntax(
      message="unexpected low surrogate in Unicode escape",
      loc~,
    )
  }
  first.unsafe_to_char()
}

///|
fn Lexer::read_four_hex_digits(
  self : Lexer,
  loc : @ast.Location,
) -> Int raise @ast.ParseError {
  let mut value = 0
  for _ in 0..<4 {
    if self.pos >= self.input.length() {
      raise @ast.ParseError::InvalidSyntax(
        message="incomplete Unicode escape",
        loc~,
      )
    }
    let c = self.advance()
    let digit = hex_value(c)
    if digit < 0 {
      raise @ast.ParseError::InvalidSyntax(
        message="invalid hexadecimal digit in Unicode escape",
        loc~,
      )
    }
    value = value * 16 + digit
  }
  value
}

///|
fn hex_value(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
fn Lexer::read_block_string(
  self : Lexer,
  start_loc : @ast.Location,
) -> Token raise @ast.ParseError {
  let buf = StringBuilder::new()
  while self.pos < self.input.length() {
    if self.peek() == '\\' &&
      self.peek_offset(1) == '"' &&
      self.peek_offset(2) == '"' &&
      self.peek_offset(3) == '"' {
      let _ = self.advance()
      let _ = self.advance()
      let _ = self.advance()
      let _ = self.advance()
      buf.write_string("\"\"\"")
      continue
    }
    if self.peek() == '"' &&
      self.peek_offset(1) == '"' &&
      self.peek_offset(2) == '"' {
      let _ = self.advance()
      let _ = self.advance()
      let _ = self.advance()
      return {
        kind: BlockString(normalize_block_string_value(buf.to_string())),
        loc: start_loc,
      }
    }
    let c = self.advance()
    if c == '\r' {
      if self.peek() == '\n' {
        let _ = self.advance()
      }
      buf.write_char('\n')
    } else {
      buf.write_char(c)
    }
  }
  raise @ast.ParseError::UnterminatedString(loc=start_loc)
}

///|
fn normalize_block_string_value(raw : String) -> String {
  let lines : Array[String] = raw
    .split("\n")
    .map(line => line.to_owned())
    .collect()
  let mut common_indent = -1
  for i = 1; i < lines.length(); i = i + 1 {
    let indent = leading_whitespace(lines[i])
    if indent < lines[i].length() &&
      (common_indent < 0 || indent < common_indent) {
      common_indent = indent
    }
  }
  if common_indent > 0 {
    for i = 1; i < lines.length(); i = i + 1 {
      let removable = if leading_whitespace(lines[i]) < common_indent {
        leading_whitespace(lines[i])
      } else {
        common_indent
      }
      lines[i] = lines[i][removable:].to_owned()
    }
  }
  let mut first = 0
  while first < lines.length() && is_blank_line(lines[first]) {
    first += 1
  }
  let mut last = lines.length()
  while last > first && is_blank_line(lines[last - 1]) {
    last -= 1
  }
  let result = StringBuilder::new()
  for i = first; i < last; i = i + 1 {
    if i > first {
      result.write_char('\n')
    }
    result.write_string(lines[i])
  }
  result.to_string()
}

///|
fn leading_whitespace(line : String) -> Int {
  let mut count = 0
  while count < line.length() {
    match line.get_char(count) {
      Some(' ') | Some('\t') => count += 1
      _ => break
    }
  }
  count
}

///|
fn is_blank_line(line : String) -> Bool {
  leading_whitespace(line) == line.length()
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
