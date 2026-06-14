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

///|
test "validate_against_schema valid query" {
  let schema_input =
    #|type Query { hero: Hero }
    #|type Hero { name: String }
  let query_input =
    #|{ hero { name } }
  let schema = @parser.parse(schema_input)
  let doc = @parser.parse(query_input)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "validate_against_schema unknown field" {
  let schema_input =
    #|type Query { hero: Hero }
    #|type Hero { name: String }
  let query_input =
    #|{ hero { age } }
  let schema = @parser.parse(schema_input)
  let doc = @parser.parse(query_input)
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0],
    content=(
      #|Field "age" is not defined on type "Hero"
    ),
  )
}

///|
test "validate_against_schema missing required argument" {
  let schema_input =
    #|type Query { user(id: ID!): User }
    #|type User { name: String }
  let query_input =
    #|{ user { name } }
  let schema = @parser.parse(schema_input)
  let doc = @parser.parse(query_input)
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0],
    content=(
      #|Missing required argument "id" on field "user"
    ),
  )
}

///|
test "validate_against_schema optional argument ok" {
  let schema_input =
    #|type Query { users(limit: Int = 10): User }
    #|type User { name: String }
  let query_input =
    #|{ users { name } }
  let schema = @parser.parse(schema_input)
  let doc = @parser.parse(query_input)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "validate_against_schema with schema definition" {
  let schema_input =
    #|schema { query: RootQuery }
    #|type RootQuery { hello: String }
  let query_input =
    #|{ hello }
  let schema = @parser.parse(schema_input)
  let doc = @parser.parse(query_input)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "validate_against_schema __typename is allowed" {
  let schema_input =
    #|type Query { hero: Hero }
    #|type Hero { name: String }
  let query_input =
    #|{ hero { __typename name } }
  let schema = @parser.parse(schema_input)
  let doc = @parser.parse(query_input)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "validate_against_schema nested field check" {
  let schema_input =
    #|type Query { hero: Hero }
    #|type Hero { name: String friends: [Hero] }
  let query_input =
    #|{ hero { friends { badField } } }
  let schema = @parser.parse(schema_input)
  let doc = @parser.parse(query_input)
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0],
    content=(
      #|Field "badField" is not defined on type "Hero"
    ),
  )
}
