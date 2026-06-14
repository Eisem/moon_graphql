///|
pub(all) enum TokenKind {
  Bang
  Dollar
  Amp
  LParen
  RParen
  Spread
  Colon
  Equals
  At
  LBracket
  RBracket
  LBrace
  Pipe
  RBrace
  Name(String)
  IntValue(String)
  FloatValue(String)
  StringValue(String)
  BlockString(String)
  Eof
} derive(Debug, Eq)

///|
pub(all) struct Token {
  kind : TokenKind
  loc : @ast.Location
} derive(Debug, Eq)

///|
pub impl Show for TokenKind with fn output(self, logger) {
  match self {
    Bang => logger.write_string("!")
    Dollar => logger.write_string("$")
    Amp => logger.write_string("&")
    LParen => logger.write_string("(")
    RParen => logger.write_string(")")
    Spread => logger.write_string("...")
    Colon => logger.write_string(":")
    Equals => logger.write_string("=")
    At => logger.write_string("@")
    LBracket => logger.write_string("[")
    RBracket => logger.write_string("]")
    LBrace => logger.write_string("{")
    Pipe => logger.write_string("|")
    RBrace => logger.write_string("}")
    Name(s) => logger.write_string("Name(\{s})")
    IntValue(s) => logger.write_string("Int(\{s})")
    FloatValue(s) => logger.write_string("Float(\{s})")
    StringValue(s) => logger.write_string("String(\{s})")
    BlockString(s) => logger.write_string("BlockString(\{s})")
    Eof => logger.write_string("EOF")
  }
}
