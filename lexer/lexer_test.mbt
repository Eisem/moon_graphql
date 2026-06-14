///|
test "tokenize simple query" {
  let tokens = @lexer.tokenize("{ user { name } }")
  assert_true(tokens[0].kind == LBrace)
  assert_true(tokens[1].kind == Name("user"))
  assert_true(tokens[2].kind == LBrace)
  assert_true(tokens[3].kind == Name("name"))
  assert_true(tokens[4].kind == RBrace)
  assert_true(tokens[5].kind == RBrace)
  assert_true(tokens[6].kind == Eof)
}

///|
test "tokenize punctuators" {
  let tokens = @lexer.tokenize("! $ & ( ) : = @ [ ] { | }")
  assert_true(tokens[0].kind == Bang)
  assert_true(tokens[1].kind == Dollar)
  assert_true(tokens[2].kind == Amp)
  assert_true(tokens[3].kind == LParen)
  assert_true(tokens[4].kind == RParen)
  assert_true(tokens[5].kind == Colon)
  assert_true(tokens[6].kind == Equals)
  assert_true(tokens[7].kind == At)
  assert_true(tokens[8].kind == LBracket)
  assert_true(tokens[9].kind == RBracket)
  assert_true(tokens[10].kind == LBrace)
  assert_true(tokens[11].kind == Pipe)
  assert_true(tokens[12].kind == RBrace)
}

///|
test "tokenize spread" {
  let tokens = @lexer.tokenize("...UserFields")
  assert_true(tokens[0].kind == Spread)
  assert_true(tokens[1].kind == Name("UserFields"))
}

///|
test "tokenize integers" {
  let tokens = @lexer.tokenize("42 -17 0")
  assert_true(tokens[0].kind == IntValue("42"))
  assert_true(tokens[1].kind == IntValue("-17"))
  assert_true(tokens[2].kind == IntValue("0"))
}

///|
test "tokenize floats" {
  let tokens = @lexer.tokenize("3.14 -0.5 1e10 2.5E-3")
  assert_true(tokens[0].kind == FloatValue("3.14"))
  assert_true(tokens[1].kind == FloatValue("-0.5"))
  assert_true(tokens[2].kind == FloatValue("1e10"))
  assert_true(tokens[3].kind == FloatValue("2.5E-3"))
}

///|
test "tokenize strings" {
  let tokens = @lexer.tokenize("\"hello\" \"world\"")
  assert_true(tokens[0].kind == StringValue("hello"))
  assert_true(tokens[1].kind == StringValue("world"))
}

///|
test "tokenize empty string" {
  let tokens = @lexer.tokenize("\"\"")
  assert_true(tokens[0].kind == StringValue(""))
}

///|
test "tokenize string with escapes" {
  let tokens = @lexer.tokenize("\"line1\\nline2\"")
  assert_true(tokens[0].kind == StringValue("line1\nline2"))
}

///|
test "tokenize comments ignored" {
  let tokens = @lexer.tokenize("{ # this is a comment\n name }")
  assert_true(tokens[0].kind == LBrace)
  assert_true(tokens[1].kind == Name("name"))
  assert_true(tokens[2].kind == RBrace)
}

///|
test "commas are insignificant" {
  let tokens = @lexer.tokenize("{ name, age, email }")
  assert_true(tokens[0].kind == LBrace)
  assert_true(tokens[1].kind == Name("name"))
  assert_true(tokens[2].kind == Name("age"))
  assert_true(tokens[3].kind == Name("email"))
  assert_true(tokens[4].kind == RBrace)
}

///|
test "tokenize query with arguments" {
  let tokens = @lexer.tokenize("user(id: 123)")
  assert_true(tokens[0].kind == Name("user"))
  assert_true(tokens[1].kind == LParen)
  assert_true(tokens[2].kind == Name("id"))
  assert_true(tokens[3].kind == Colon)
  assert_true(tokens[4].kind == IntValue("123"))
  assert_true(tokens[5].kind == RParen)
}

///|
test "tokenize directive" {
  let tokens = @lexer.tokenize("@include(if: true)")
  assert_true(tokens[0].kind == At)
  assert_true(tokens[1].kind == Name("include"))
  assert_true(tokens[2].kind == LParen)
  assert_true(tokens[3].kind == Name("if"))
  assert_true(tokens[4].kind == Colon)
  assert_true(tokens[5].kind == Name("true"))
  assert_true(tokens[6].kind == RParen)
}

///|
test "tokenize variable" {
  let tokens = @lexer.tokenize("$userId")
  assert_true(tokens[0].kind == Dollar)
  assert_true(tokens[1].kind == Name("userId"))
}

///|
test "tokenize type with non-null and list" {
  let tokens = @lexer.tokenize("[String!]!")
  assert_true(tokens[0].kind == LBracket)
  assert_true(tokens[1].kind == Name("String"))
  assert_true(tokens[2].kind == Bang)
  assert_true(tokens[3].kind == RBracket)
  assert_true(tokens[4].kind == Bang)
}

///|
test "tokenize full query" {
  let input =
    #|query GetUser($id: ID!) {
    #|  user(id: $id) {
    #|    name
    #|    age
    #|    posts {
    #|      title
    #|    }
    #|  }
    #|}
  let tokens = @lexer.tokenize(input)
  assert_true(tokens[0].kind == Name("query"))
  assert_true(tokens[1].kind == Name("GetUser"))
  assert_true(tokens[2].kind == LParen)
  assert_true(tokens[3].kind == Dollar)
  assert_true(tokens[4].kind == Name("id"))
  assert_true(tokens[5].kind == Colon)
  assert_true(tokens[6].kind == Name("ID"))
  assert_true(tokens[7].kind == Bang)
  assert_true(tokens[8].kind == RParen)
  assert_true(tokens[9].kind == LBrace)
}

///|
test "location tracking" {
  let tokens = @lexer.tokenize("{\n  name\n}")
  assert_eq(tokens[0].loc.line, 1)
  assert_eq(tokens[0].loc.col, 1)
  assert_eq(tokens[1].loc.line, 2)
  assert_eq(tokens[2].loc.line, 3)
}
