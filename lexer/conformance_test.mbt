// Original minimal fixtures derived from the lexical grammar and BlockStringValue
// algorithm in the GraphQL Specification, October 2021 Edition.

///|
fn rejects_lexically(input : String) -> Bool {
  let result = Ok(@lexer.tokenize(input)) catch { _ => Err("lexical error") }
  result is Err(_)
}

///|
test "conformance: valid GraphQL number forms" {
  let tokens = @lexer.tokenize("0 -0 1 -1 1.0 1e2 1E+2 -1.2e-3")
  assert_true(tokens[0].kind == IntValue("0"))
  assert_true(tokens[1].kind == IntValue("-0"))
  assert_true(tokens[2].kind == IntValue("1"))
  assert_true(tokens[3].kind == IntValue("-1"))
  assert_true(tokens[4].kind == FloatValue("1.0"))
  assert_true(tokens[5].kind == FloatValue("1e2"))
  assert_true(tokens[6].kind == FloatValue("1E+2"))
  assert_true(tokens[7].kind == FloatValue("-1.2e-3"))
}

///|
test "conformance: invalid GraphQL number forms are rejected" {
  let invalid = ["01", "-01", ".1", "1.", "1e", "1e+", "1a", "1.2.3", "-"]
  for input in invalid {
    assert_true(rejects_lexically(input))
  }
}

///|
test "conformance: all quoted-string escapes are decoded" {
  let tokens = @lexer.tokenize("\"\\b\\f\\n\\r\\t\\\\\\\"\\/\"")
  assert_true(tokens[0].kind == StringValue("\b\u000c\n\r\t\\\"/"))
}

///|
test "conformance: BMP Unicode escapes are decoded" {
  let tokens = @lexer.tokenize("\"\\u0041\\u03A9\"")
  assert_true(tokens[0].kind == StringValue("AΩ"))
}

///|
test "conformance: Unicode surrogate pairs are decoded" {
  let tokens = @lexer.tokenize("\"\\uD83D\\uDE00\"")
  assert_true(tokens[0].kind == StringValue("😀"))
}

///|
test "conformance: invalid string escapes are rejected" {
  let invalid = [
    "\"\\x\"", "\"\\u12\"", "\"\\u12XZ\"", "\"\\uD83D\"", "\"\\uD83D\\u0041\"", "\"\\uDE00\"",
  ]
  for input in invalid {
    assert_true(rejects_lexically(input))
  }
}

///|
test "conformance: quoted strings reject raw line terminators" {
  assert_true(rejects_lexically("\"line\nbreak\""))
  assert_true(rejects_lexically("\"line\rbreak\""))
}

///|
test "conformance: block strings remove common indentation" {
  let input =
    #|"""
    #|    Hello,
    #|      World!
    #|
    #|    Yours,
    #|      GraphQL.
    #|"""
  let tokens = @lexer.tokenize(input)
  assert_true(
    tokens[0].kind == BlockString("Hello,\n  World!\n\nYours,\n  GraphQL."),
  )
}

///|
test "conformance: block strings normalize CRLF and CR" {
  let tokens = @lexer.tokenize("\"\"\"\r\n  a\r\n  b\r  c\r\n\"\"\"")
  assert_true(tokens[0].kind == BlockString("a\nb\nc"))
}

///|
test "conformance: block strings support escaped triple quotes" {
  let input =
    #|"""contains \""" quotes"""
  let tokens = @lexer.tokenize(input)
  assert_true(tokens[0].kind == BlockString("contains \"\"\" quotes"))
}

///|
test "conformance: unterminated block strings are rejected" {
  assert_true(rejects_lexically("\"\"\"never closed"))
}

///|
test "conformance: BOM is ignored" {
  let tokens = @lexer.tokenize("\uFEFF{ greeting }")
  assert_true(tokens[0].kind == LBrace)
  assert_true(tokens[1].kind == Name("greeting"))
}

///|
test "conformance: comments end at CR and CRLF" {
  let cr_tokens = @lexer.tokenize("# comment\rgreeting")
  assert_true(cr_tokens[0].kind == Name("greeting"))
  assert_eq(cr_tokens[0].loc.line, 2)
  let crlf_tokens = @lexer.tokenize("# comment\r\ngreeting")
  assert_true(crlf_tokens[0].kind == Name("greeting"))
  assert_eq(crlf_tokens[0].loc.line, 2)
}

///|
test "conformance: CRLF counts as one line terminator" {
  let tokens = @lexer.tokenize("{\r\n  greeting\r  name\n}")
  assert_eq(tokens[0].loc.line, 1)
  assert_eq(tokens[1].loc.line, 2)
  assert_eq(tokens[2].loc.line, 3)
  assert_eq(tokens[3].loc.line, 4)
}
