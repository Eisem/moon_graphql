///|
test "roundtrip query parse-print-parse" {
  let input =
    #|query HeroQuery($id: ID!) {
    #|  hero(id: $id) {
    #|    name
    #|    friends {
    #|      name
    #|    }
    #|  }
    #|}
  let doc1 = @parser.parse(input)
  let printed = @printer.print(doc1)
  let doc2 = @parser.parse(printed)
  assert_true(doc1 == doc2)
}

///|
test "roundtrip schema parse-print-parse" {
  let input =
    #|type Query {
    #|  hero(episode: Episode): Hero
    #|}
    #|type Hero {
    #|  name: String
    #|  friends: [Hero]
    #|}
    #|enum Episode {
    #|  NEWHOPE
    #|  EMPIRE
    #|  JEDI
    #|}
  let doc1 = @parser.parse(input)
  let printed = @printer.print(doc1)
  let doc2 = @parser.parse(printed)
  assert_true(doc1 == doc2)
}

///|
test "roundtrip fragment" {
  let input =
    #|query {
    #|  hero {
    #|    ...heroFields
    #|  }
    #|}
    #|fragment heroFields on Hero {
    #|  name
    #|  friends {
    #|    name
    #|  }
    #|}
  let doc1 = @parser.parse(input)
  let printed = @printer.print(doc1)
  let doc2 = @parser.parse(printed)
  assert_true(doc1 == doc2)
}

///|
test "roundtrip directives" {
  let input =
    #|query ($withFriends: Boolean!) {
    #|  hero {
    #|    name
    #|    friends @include(if: $withFriends) {
    #|      name
    #|    }
    #|  }
    #|}
  let doc1 = @parser.parse(input)
  let printed = @printer.print(doc1)
  let doc2 = @parser.parse(printed)
  assert_true(doc1 == doc2)
}

///|
test "validation valid document" {
  let schema_str =
    #|type Query { hero(episode: Episode): Hero }
    #|type Hero { name: String friends: [Hero] }
    #|enum Episode { NEWHOPE EMPIRE JEDI }
  let query_str =
    #|query ($ep: Episode) { hero(episode: $ep) { name friends { name } } }
  let schema = @parser.parse(schema_str)
  let doc = @parser.parse(query_str)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "validation invalid field" {
  let schema_str =
    #|type Query { hero: Hero }
    #|type Hero { name: String }
  let query_str =
    #|{ hero { age } }
  let schema = @parser.parse(schema_str)
  let doc = @parser.parse(query_str)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_true(errors.length() > 0)
}

///|
test "validation missing required arg" {
  let schema_str =
    #|type Query { user(id: ID!): User }
    #|type User { name: String }
  let query_str =
    #|{ user { name } }
  let schema = @parser.parse(schema_str)
  let doc = @parser.parse(query_str)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_true(errors.length() > 0)
}

///|
test "error handling malformed query" {
  let result = Ok(@parser.parse("{ hero { }")) catch { _ => Err("parse error") }
  assert_true(result is Err(_))
}

///|
test "error handling unterminated string" {
  let result = Ok(@parser.parse("{ hero(name: \"unclosed) }")) catch {
    _ => Err("parse error")
  }
  assert_true(result is Err(_))
}

///|
test "full pipeline with all features" {
  let schema_str =
    #|schema { query: Query mutation: Mutation }
    #|type Query { hero(episode: Episode): Hero users(limit: Int = 10): [User!]! }
    #|type Mutation { createUser(input: CreateUserInput!): User }
    #|type Hero { name: String! friends: [Hero] }
    #|type User implements Node { id: ID! name: String email: String }
    #|interface Node { id: ID! }
    #|enum Episode { NEWHOPE EMPIRE JEDI }
    #|input CreateUserInput { name: String! email: String }
    #|union SearchResult = Hero | User
    #|scalar DateTime
    #|directive @deprecated(reason: String = "No longer supported") on FIELD_DEFINITION | ENUM_VALUE
  let query_str =
    #|query HeroQuery($ep: Episode!) {
    #|  hero(episode: $ep) {
    #|    name
    #|    ...heroDetails
    #|  }
    #|}
    #|fragment heroDetails on Hero {
    #|  friends {
    #|    name
    #|  }
    #|}
  let schema = @parser.parse(schema_str)
  let doc = @parser.parse(query_str)
  let schema_printed = @printer.print(schema)
  let query_printed = @printer.print(doc)
  let schema2 = @parser.parse(schema_printed)
  let doc2 = @parser.parse(query_printed)
  assert_true(schema == schema2)
  assert_true(doc == doc2)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
  let basic_errors = @validation.validate(doc)
  assert_eq(basic_errors.length(), 0)
}

///|
test "mutation roundtrip and validation" {
  let schema_str =
    #|type Query { user(id: ID!): User }
    #|type Mutation { createUser(name: String!): User }
    #|type User { id: ID! name: String }
  let query_str =
    #|mutation CreateUser {
    #|  createUser(name: "Alice") {
    #|    id
    #|    name
    #|  }
    #|}
  let schema = @parser.parse(schema_str)
  let doc = @parser.parse(query_str)
  let printed = @printer.print(doc)
  let doc2 = @parser.parse(printed)
  assert_true(doc == doc2)
  let errors = @validation.validate_against_schema(doc, schema)
  assert_eq(errors.length(), 0)
}

///|
test "inline fragment roundtrip" {
  let input =
    #|{
    #|  search {
    #|    ... on Hero {
    #|      name
    #|    }
    #|    ... on User {
    #|      email
    #|    }
    #|  }
    #|}
  let doc1 = @parser.parse(input)
  let printed = @printer.print(doc1)
  let doc2 = @parser.parse(printed)
  assert_true(doc1 == doc2)
}
