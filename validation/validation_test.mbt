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
  inspect(errors[0].message(), content="Duplicate fragment name: f")
}

///|
test "validate undefined fragment spread" {
  let input =
    #|{ hero { ...missingFrag } }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  inspect(errors[0].message(), content="Undefined fragment: missingFrag")
}

///|
test "validate duplicate operation names" {
  let input =
    #|query Foo { hero { name } }
    #|query Foo { villain { name } }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  inspect(errors[0].message(), content="Duplicate operation name: Foo")
}

///|
test "validate undefined variable" {
  let input =
    #|query { hero(id: $missing) { name } }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  inspect(errors[0].message(), content="Undefined variable: $missing")
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
test "validate multiple unnamed operations are rejected" {
  let input =
    #|{ hero { name } }
    #|mutation { createUser { id } }
  let doc = @parser.parse(input)
  let errors = @validation.validate(doc)
  inspect(
    errors[0].message(),
    content="Anonymous operation must be the only operation in a document",
  )
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
    errors[0].message(),
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
    errors[0].message(),
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
test "validate_schema accepts a structurally valid schema" {
  let schema = @parser.parse(
    (
      #|interface Node { id: ID! }
      #|type User implements Node { id: ID! name: String }
      #|union SearchResult = User
      #|input UserInput { name: String! }
      #|type Query { user(input: UserInput): User search: SearchResult }
      #|schema { query: Query }
    ),
  )
  let errors = @validation.validate_schema(schema)
  assert_eq(errors.length(), 0)
}

///|
test "validate_schema enforces implemented interface fields and arguments" {
  let schema = @parser.parse(
    (
      #|interface Node { id: ID! search(limit: Int): String }
      #|type User implements Node { search: String }
    ),
  )
  let errors = @validation.validate_schema(schema)
  assert_eq(errors.length(), 2)
  inspect(
    errors[0].message(),
    content="object type \"User\" must define field \"id\" required by interface \"Node\"",
  )
  inspect(
    errors[1].message(),
    content="Field \"search\" on object type \"User\" must define argument \"limit\" required by interface \"Node\"",
  )
}

///|
test "validate_schema rejects incompatible interface field contracts" {
  let schema = @parser.parse(
    (
      #|interface Node { id: ID! search(limit: Int): String }
      #|type User implements Node {
      #|  id: ID
      #|  search(limit: String, required: Boolean!): String
      #|}
    ),
  )
  let errors = @validation.validate_schema(schema)
  assert_eq(errors.length(), 3)
  inspect(
    errors[0].message(),
    content="Field \"id\" on object type \"User\" has type \"ID\" which is not compatible with interface \"Node\" type \"ID!\"",
  )
  inspect(
    errors[1].message(),
    content="Argument \"limit\" on field \"search\" of object type \"User\" has type \"String\" which is not compatible with interface \"Node\" type \"Int\"",
  )
  inspect(
    errors[2].message(),
    content="Additional argument \"required\" on field \"search\" of object type \"User\" must not be required when implementing interface \"Node\"",
  )
}

///|
test "validate_schema accepts covariant interface field return types" {
  let schema = @parser.parse(
    (
      #|interface Node { id: ID! }
      #|type User implements Node { id: ID! }
      #|interface Container { item: Node }
      #|type UserContainer implements Container { item: User! }
    ),
  )
  let errors = @validation.validate_schema(schema)
  assert_eq(errors.length(), 0)
}

///|
test "validate_schema rejects duplicate names inside definitions" {
  let schema = @parser.parse(
    (
      #|type Query { user(id: ID, id: ID): String user: String }
      #|input Filter { name: String name: String }
      #|enum Role { USER USER }
      #|type User { id: ID }
      #|union SearchResult = User | User
    ),
  )
  let errors = @validation.validate_schema(schema)
  assert_eq(errors.length(), 5)
  inspect(
    errors[0].message(),
    content="Duplicate field \"user\" in object type \"Query\"",
  )
  inspect(
    errors[1].message(),
    content="Duplicate input value \"id\" in field of object type \"Query\" \"user\"",
  )
  inspect(
    errors[2].message(),
    content="Duplicate input value \"name\" in input object \"Filter\"",
  )
  inspect(
    errors[3].message(),
    content="Duplicate enum value \"USER\" in enum type \"Role\"",
  )
  inspect(
    errors[4].message(),
    content="Duplicate union member \"User\" in union \"SearchResult\"",
  )
}

///|
test "validate_schema checks root types and union members" {
  let schema = @parser.parse(
    (
      #|schema { query: Node mutation: Missing }
      #|interface Node { id: ID }
      #|type User { id: ID }
      #|union SearchResult = User | Node | Missing
    ),
  )
  let errors = @validation.validate_schema(schema)
  assert_eq(errors.length(), 4)
  inspect(
    errors[0].message(),
    content="Schema query root type \"Node\" must be an object type",
  )
  inspect(
    errors[1].message(),
    content="Schema mutation root type \"Missing\" is not defined",
  )
  inspect(
    errors[2].message(),
    content="Union member \"Node\" of union \"SearchResult\" must be an object type",
  )
  inspect(
    errors[3].message(),
    content="Union member \"Missing\" of union \"SearchResult\" is not defined",
  )
}

///|
test "validate_schema checks input output and implemented interface positions" {
  let schema = @parser.parse(
    (
      #|scalar Token
      #|type Query { user(filter: User): UserInput missing: Missing }
      #|type User implements Token { id: ID }
      #|input UserInput { owner: User }
    ),
  )
  let errors = @validation.validate_schema(schema)
  assert_eq(errors.length(), 5)
  inspect(
    errors[0].message(),
    content="Output type \"UserInput\" for field \"user\" of object type \"Query\" is not an output type",
  )
  inspect(
    errors[1].message(),
    content="Input type \"User\" for argument of field \"user\" on object type \"Query\" \"filter\" is not an input type",
  )
  inspect(
    errors[2].message(),
    content="Output type \"Missing\" for field \"missing\" of object type \"Query\" is not defined",
  )
  inspect(
    errors[3].message(),
    content="Implemented type \"Token\" on object type \"User\" must be an interface",
  )
  inspect(
    errors[4].message(),
    content="Input type \"User\" for input field of input object \"UserInput\" \"owner\" is not an input type",
  )
}

///|
test "validate_against_schema includes schema validation errors" {
  let schema = @parser.parse("type Query { greeting: String greeting: String }")
  let doc = @parser.parse("{ greeting }")
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 1)
  inspect(
    errors[0].message(),
    content="Duplicate field \"greeting\" in object type \"Query\"",
  )
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
    errors[0].message(),
    content=(
      #|Field "badField" is not defined on type "Hero"
    ),
  )
}

///|
test "validate leaf field no sub-selections on scalar" {
  let schema_input =
    #|type Query { hero: Hero }
    #|type Hero { name: String friends: [Hero] }
  let query_input =
    #|{ hero { name { first } } }
  let schema = @parser.parse(schema_input)
  let doc = @parser.parse(query_input)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_true(errors.length() > 0)
}

///|
test "validate leaf field no sub-selections on enum" {
  let schema_input =
    #|type Query { hero: Hero }
    #|type Hero { name: String episode: Episode }
    #|enum Episode { NEWHOPE EMPIRE JEDI }
  let query_input =
    #|{ hero { episode { name } } }
  let schema = @parser.parse(schema_input)
  let doc = @parser.parse(query_input)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_true(errors.length() > 0)
}
