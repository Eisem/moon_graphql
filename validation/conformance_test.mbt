// Specification-oriented regression cases derived from the behavior described
// by the GraphQL Specification, October 2021 Edition. The cases are original
// minimal fixtures; no source code or fixture text was copied from graphql-js.

///|
test "conformance: validate includes fragment cycle detection" {
  let doc = @parser.parse(
    (
      #|query { hero { ...a } }
      #|fragment a on Hero { ...b }
      #|fragment b on Hero { ...a }
    ),
  )
  let errors = @validation.validate(doc)
  assert_true(errors.length() > 0)
  assert_true(errors[0].is_error())
}

///|
test "conformance: union supports typename and conditioned fragments" {
  let schema = @parser.parse(
    (
      #|type Query { search: SearchResult }
      #|union SearchResult = Hero | User
      #|type Hero { name: String }
      #|type User { email: String }
    ),
  )
  let doc = @parser.parse(
    (
      #|{
      #|  search {
      #|    __typename
      #|    ... on Hero { name }
      #|    ...userFields
      #|  }
      #|}
      #|fragment userFields on User { email }
    ),
  )
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "conformance: union rejects direct member fields" {
  let schema = @parser.parse(
    (
      #|type Query { search: SearchResult }
      #|union SearchResult = Hero | User
      #|type Hero { name: String }
      #|type User { name: String }
    ),
  )
  let doc = @parser.parse("{ search { name } }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Field "name" cannot be selected directly on union type "SearchResult"
    ),
  )
}

///|
test "conformance: validates fields inside named fragments" {
  let schema = @parser.parse(
    (
      #|type Query { hero: Hero }
      #|type Hero { name: String }
    ),
  )
  let doc = @parser.parse(
    (
      #|query { hero { ...heroFields } }
      #|fragment heroFields on Hero { unknown }
    ),
  )
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Field "unknown" is not defined on type "Hero"
    ),
  )
}

///|
test "conformance: validates fields inside inline fragments" {
  let schema = @parser.parse(
    (
      #|type Query { hero: Hero }
      #|type Hero { name: String }
    ),
  )
  let doc = @parser.parse("{ hero { ... on Hero { unknown } } }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Field "unknown" is not defined on type "Hero"
    ),
  )
}

///|
test "conformance: composite field requires a selection set" {
  let schema = @parser.parse(
    (
      #|type Query { hero: Hero }
      #|type Hero { name: String }
    ),
  )
  let doc = @parser.parse("{ hero }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Field "hero" of composite type "Hero" must have a selection set
    ),
  )
}

///|
test "conformance: leaf field rejects a selection set" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse("{ greeting { value } }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Field "greeting" of leaf type "String" must not have a selection set
    ),
  )
}

///|
test "conformance: fragment condition must reference a known type" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse(
    (
      #|query { greeting }
      #|fragment missingFields on Missing { value }
    ),
  )
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Fragment type condition references unknown type "Missing"
    ),
  )
}

///|
test "conformance: fragment condition must be composite" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse(
    (
      #|query { greeting }
      #|fragment invalidFields on String { value }
    ),
  )
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Fragment type condition "String" must be a composite type
    ),
  )
}

///|
test "conformance: anonymous operation must be alone" {
  let doc = @parser.parse(
    (
      #|{ greeting }
      #|query Named { greeting }
    ),
  )
  let errors = @validation.validate(doc)
  inspect(
    errors[0].message(),
    content="Anonymous operation must be the only operation in a document",
  )
}

///|
test "conformance: variable names are unique per operation" {
  let doc = @parser.parse(
    "query Duplicate($id: ID, $id: ID) { node(id: $id) { id } }",
  )
  let errors = @validation.validate(doc)
  inspect(errors[0].message(), content="Duplicate variable name: $id")
}

///|
test "conformance: variables used by directives must be defined" {
  let doc = @parser.parse("query Demo @skip(if: $skip) { greeting }")
  let errors = @validation.validate(doc)
  inspect(errors[0].message(), content="Undefined variable: $skip")
}

///|
test "conformance: fragment variable usage belongs to the operation" {
  let doc = @parser.parse(
    (
      #|query Demo { hero { ...heroFields } }
      #|fragment heroFields on Hero { name @include(if: $enabled) }
    ),
  )
  let errors = @validation.validate(doc)
  inspect(errors[0].message(), content="Undefined variable: $enabled")
}

///|
test "conformance: field rejects unknown arguments" {
  let schema = @parser.parse("type Query { user(id: ID): String }")
  let doc = @parser.parse("{ user(name: \"Ada\") }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Unknown argument "name" on field "user"
    ),
  )
}

///|
test "conformance: field argument names are unique" {
  let schema = @parser.parse("type Query { user(id: ID): String }")
  let doc = @parser.parse("{ user(id: 1, id: 2) }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Duplicate argument "id" on field "user"
    ),
  )
}

///|
test "conformance: built-in include directive is valid on fields" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse(
    "query Demo($enabled: Boolean!) { greeting @include(if: $enabled) }",
  )
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "conformance: unknown directives are rejected" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse("{ greeting @unknown }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(errors[0].message(), content="Unknown directive \"@unknown\"")
}

///|
test "conformance: directive locations are enforced" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse("query Demo @include(if: true) { greeting }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Directive "@include" is not allowed at location "QUERY"
    ),
  )
}

///|
test "conformance: non-repeatable directives cannot repeat" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse("{ greeting @skip(if: true) @skip(if: false) }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Directive "@skip" is not repeatable at location "FIELD"
    ),
  )
}

///|
test "conformance: directive required arguments are enforced" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse("{ greeting @include }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Missing required argument "if" on directive "@include"
    ),
  )
}

///|
test "conformance: directive arguments must be known and unique" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse(
    "{ greeting @include(if: true, extra: false, if: false) }",
  )
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 2)
  inspect(
    errors[0].message(),
    content=(
      #|Unknown argument "extra" on directive "@include"
    ),
  )
  inspect(
    errors[1].message(),
    content=(
      #|Duplicate argument "if" on directive "@include"
    ),
  )
}

///|
test "conformance: custom repeatable directives use schema definitions" {
  let schema = @parser.parse(
    (
      #|directive @tag(name: String!) repeatable on FIELD
      #|type Query { greeting: String }
    ),
  )
  let doc = @parser.parse(
    "{ greeting @tag(name: \"one\") @tag(name: \"two\") }",
  )
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "conformance: built-in scalar literals are type checked" {
  let schema = @parser.parse(
    "type Query { search(limit: Int, ratio: Float, id: ID): String }",
  )
  let doc = @parser.parse("{ search(limit: \"ten\", ratio: 2, id: 42) }")
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 1)
  inspect(
    errors[0].message(),
    content=(
      #|Expected value of type "Int" for argument "limit" on field "search", found String
    ),
  )
}

///|
test "conformance: non-null arguments reject null literals" {
  let schema = @parser.parse("type Query { user(id: ID!): String }")
  let doc = @parser.parse("{ user(id: null) }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Null is not allowed for non-null argument "id" on field "user"
    ),
  )
}

///|
test "conformance: enum literals must name a declared value" {
  let schema = @parser.parse(
    (
      #|enum Episode { NEWHOPE EMPIRE JEDI }
      #|type Query { hero(episode: Episode): String }
    ),
  )
  let doc = @parser.parse("{ hero(episode: FUTURE) }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Unknown value "FUTURE" for enum "Episode" in argument "episode" on field "hero"
    ),
  )
}

///|
test "conformance: enum input does not accept a string literal" {
  let schema = @parser.parse(
    (
      #|enum Episode { NEWHOPE EMPIRE JEDI }
      #|type Query { hero(episode: Episode): String }
    ),
  )
  let doc = @parser.parse("{ hero(episode: \"NEWHOPE\") }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Expected value of type "Episode" for argument "episode" on field "hero", found String
    ),
  )
}

///|
test "conformance: a single value can be coerced to a list input" {
  let schema = @parser.parse("type Query { nodes(ids: [ID!]!): String }")
  let doc = @parser.parse("{ nodes(ids: 1) }")
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "conformance: list elements are checked recursively" {
  let schema = @parser.parse("type Query { nodes(ids: [ID!]!): String }")
  let doc = @parser.parse("{ nodes(ids: [1, true]) }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Expected value of type "ID" for argument "ids" on field "nodes", found Boolean
    ),
  )
}

///|
test "conformance: input object fields are known unique and complete" {
  let schema = @parser.parse(
    (
      #|input UserInput { name: String! age: Int }
      #|type Query { create(input: UserInput!): String }
    ),
  )
  let doc = @parser.parse(
    "{ create(input: { age: 10, age: 11, extra: true }) }",
  )
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 3)
  inspect(
    errors[0].message(),
    content=(
      #|Duplicate input field "age" for type "UserInput" in argument "input" on field "create"
    ),
  )
  inspect(
    errors[1].message(),
    content=(
      #|Unknown input field "extra" for type "UserInput" in argument "input" on field "create"
    ),
  )
  inspect(
    errors[2].message(),
    content=(
      #|Missing required input field "name" for type "UserInput" in argument "input" on field "create"
    ),
  )
}

///|
test "conformance: nullable variable cannot satisfy non-null argument" {
  let schema = @parser.parse("type Query { user(id: ID!): String }")
  let doc = @parser.parse("query Demo($id: ID) { user(id: $id) }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Variable "$id" of type "ID" is not compatible with expected type "ID!" for argument "id" on field "user"
    ),
  )
}

///|
test "conformance: variable non-null default permits non-null position" {
  let schema = @parser.parse("type Query { user(id: ID!): String }")
  let doc = @parser.parse(
    "query Demo($id: ID = \"fallback\") { user(id: $id) }",
  )
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "conformance: location default permits nullable variable" {
  let schema = @parser.parse(
    "type Query { user(id: ID! = \"fallback\"): String }",
  )
  let doc = @parser.parse("query Demo($id: ID) { user(id: $id) }")
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "conformance: variable named types must match" {
  let schema = @parser.parse("type Query { user(id: ID): String }")
  let doc = @parser.parse("query Demo($id: String) { user(id: $id) }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Variable "$id" of type "String" is not compatible with expected type "ID" for argument "id" on field "user"
    ),
  )
}

///|
test "conformance: variables nested in input objects are checked" {
  let schema = @parser.parse(
    (
      #|input UserInput { id: ID! }
      #|type Query { user(input: UserInput!): String }
    ),
  )
  let doc = @parser.parse("query Demo($id: ID) { user(input: { id: $id }) }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Variable "$id" of type "ID" is not compatible with expected type "ID!" for input field "id" of "UserInput"
    ),
  )
}

///|
test "conformance: directive variable positions are type checked" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse(
    "query Demo($enabled: String!) { greeting @include(if: $enabled) }",
  )
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Variable "$enabled" of type "String!" is not compatible with expected type "Boolean!" for argument "if" on directive "@include"
    ),
  )
}

///|
test "conformance: variable defaults match the declared type" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse("query Demo($count: Int = \"many\") { greeting }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Expected value of type "Int" for default value for variable "$count", found String
    ),
  )
}

///|
test "conformance: variable defaults must be constant" {
  let schema = @parser.parse("type Query { greeting: String }")
  let doc = @parser.parse(
    "query Demo($first: ID, $second: ID = $first) { greeting }",
  )
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content="Default value for variable \"$second\" must be a constant",
  )
}

///|
test "conformance: variables require input types" {
  let schema = @parser.parse(
    (
      #|type User { id: ID! }
      #|type Query { greeting: String }
    ),
  )
  let doc = @parser.parse("query Demo($user: User) { greeting }")
  let errors = @validation.validate_against_schema(doc, schema)
  inspect(
    errors[0].message(),
    content=(
      #|Variable "$user" cannot use non-input type "User"
    ),
  )
}
