///|
pub(all) struct Location {
  line : Int
  col : Int
} derive(Debug, Eq)

///|
pub(all) suberror ParseError {
  UnexpectedChar(char~ : Char, loc~ : Location)
  UnterminatedString(loc~ : Location)
  UnexpectedToken(expected~ : String, got~ : String, loc~ : Location)
  UnexpectedEof(expected~ : String)
  InvalidNumber(text~ : String, loc~ : Location)
  InvalidSyntax(message~ : String, loc~ : Location)
}

///|
pub impl Show for Location with fn output(self, logger) {
  logger.write_string("\{self.line}:\{self.col}")
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  match self {
    UnexpectedChar(char~, loc~) =>
      logger.write_string("unexpected char '\{char}' at \{loc}")
    UnterminatedString(loc~) =>
      logger.write_string("unterminated string at \{loc}")
    UnexpectedToken(expected~, got~, loc~) =>
      logger.write_string("expected \{expected}, got \{got} at \{loc}")
    UnexpectedEof(expected~) =>
      logger.write_string("unexpected EOF, expected \{expected}")
    InvalidNumber(text~, loc~) =>
      logger.write_string("invalid number '\{text}' at \{loc}")
    InvalidSyntax(message~, loc~) => logger.write_string("\{message} at \{loc}")
  }
}
