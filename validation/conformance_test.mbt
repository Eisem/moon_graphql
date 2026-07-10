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
