///|
test "validate valid document" {
  let doc = @parser.parse("{ hero { name } }")
  let errors = @validation.validate(doc)
  assert_eq(errors.length(), 0)
}

///|
test "validate duplicate fragment names" {
  let input =
    #|{ hero { ...f } }
    #|fragment f on Hero { name }
    #|fragment f on Villain { name }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  inspect(errors[0], content="Duplicate fragment name: f")
}

///|
test "validate undefined fragment spread" {
  let input =
    #|{ hero { ...missingFrag } }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  inspect(errors[0], content="Undefined fragment: missingFrag")
}

///|
test "validate duplicate operation names" {
  let input =
    #|query Foo { hero { name } }
    #|query Foo { villain { name } }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  inspect(errors[0], content="Duplicate operation name: Foo")
}

///|
test "validate undefined variable" {
  let input =
    #|query { hero(id: $missing) { name } }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  inspect(errors[0], content="Undefined variable: $missing")
}

///|
test "validate defined variable is ok" {
  let input =
    #|query ($id: ID!) { hero(id: $id) { name } }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  assert_eq(errors.length(), 0)
}

///|
test "validate multiple errors" {
  let input =
    #|query Foo { hero { ...missing } }
    #|query Foo { villain(id: $x) { name } }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  assert_true(errors.length() >= 2)
}

///|
test "validate unnamed operations no duplicate" {
  let input =
    #|{ hero { name } }
    #|mutation { createUser { id } }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  assert_eq(errors.length(), 0)
}
