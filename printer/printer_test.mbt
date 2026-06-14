///|
test "print simple query" {
  let doc = @parser.parse("{ hero { name } }")
  inspect(
    @printer.print(doc),
    content=(
      #|{
      #|  hero {
      #|    name
      #|  }
      #|}
    ),
  )
}

///|
test "print named query" {
  let doc = @parser.parse("query HeroQuery { hero { name } }")
  inspect(
    @printer.print(doc),
    content=(
      #|query HeroQuery {
      #|  hero {
      #|    name
      #|  }
      #|}
    ),
  )
}

///|
test "print query with variables" {
  let doc = @parser.parse("query ($id: ID!) { hero(id: $id) { name } }")
  inspect(
    @printer.print(doc),
    content=(
      #|query($id: ID!) {
      #|  hero(id: $id) {
      #|    name
      #|  }
      #|}
    ),
  )
}

///|
test "print mutation" {
  let input =
    #|mutation { createUser(name: "John") { id } }
  let doc = @parser.parse(input)
  inspect(
    @printer.print(doc),
    content=(
      #|mutation {
      #|  createUser(name: "John") {
      #|    id
      #|  }
      #|}
    ),
  )
}

///|
test "print fragment" {
  let input =
    #|{ hero { ...heroFields } }
    #|fragment heroFields on Hero { name }
  let doc = @parser.parse(input)
  inspect(
    @printer.print(doc),
    content=(
      #|{
      #|  hero {
      #|    ...heroFields
      #|  }
      #|}
      #|
      #|fragment heroFields on Hero {
      #|  name
      #|}
    ),
  )
}

///|
test "print inline fragment" {
  let doc = @parser.parse("{ hero { ... on Human { height } } }")
  inspect(
    @printer.print(doc),
    content=(
      #|{
      #|  hero {
      #|    ... on Human {
      #|      height
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "print directives" {
  let doc = @parser.parse("{ hero @include(if: true) { name } }")
  inspect(
    @printer.print(doc),
    content=(
      #|{
      #|  hero @include(if: true) {
      #|    name
      #|  }
      #|}
    ),
  )
}

///|
test "print alias" {
  let doc = @parser.parse("{ smallHero: hero(size: SMALL) { name } }")
  inspect(
    @printer.print(doc),
    content=(
      #|{
      #|  smallHero: hero(size: SMALL) {
      #|    name
      #|  }
      #|}
    ),
  )
}

///|
test "print object type" {
  let doc = @parser.parse("type User { id: ID! name: String }")
  inspect(
    @printer.print(doc),
    content=(
      #|type User {
      #|  id: ID!
      #|  name: String
      #|}
    ),
  )
}

///|
test "print object type with implements" {
  let doc = @parser.parse("type User implements Node & Entity { id: ID! }")
  inspect(
    @printer.print(doc),
    content=(
      #|type User implements Node & Entity {
      #|  id: ID!
      #|}
    ),
  )
}

///|
test "print interface type" {
  let doc = @parser.parse("interface Node { id: ID! }")
  inspect(
    @printer.print(doc),
    content=(
      #|interface Node {
      #|  id: ID!
      #|}
    ),
  )
}

///|
test "print union type" {
  let doc = @parser.parse("union SearchResult = User | Post | Comment")
  inspect(
    @printer.print(doc),
    content=(
      #|union SearchResult = User | Post | Comment
    ),
  )
}

///|
test "print enum type" {
  let doc = @parser.parse("enum Role { ADMIN USER MODERATOR }")
  inspect(
    @printer.print(doc),
    content=(
      #|enum Role {
      #|  ADMIN
      #|  USER
      #|  MODERATOR
      #|}
    ),
  )
}

///|
test "print input object type" {
  let doc = @parser.parse(
    "input CreateUserInput { name: String! email: String }",
  )
  inspect(
    @printer.print(doc),
    content=(
      #|input CreateUserInput {
      #|  name: String!
      #|  email: String
      #|}
    ),
  )
}

///|
test "print scalar type" {
  let doc = @parser.parse("scalar DateTime")
  inspect(
    @printer.print(doc),
    content=(
      #|scalar DateTime
    ),
  )
}

///|
test "print schema def" {
  let doc = @parser.parse(
    "schema { query: Query mutation: Mutation subscription: Subscription }",
  )
  inspect(
    @printer.print(doc),
    content=(
      #|schema {
      #|  query: Query
      #|  mutation: Mutation
      #|  subscription: Subscription
      #|}
    ),
  )
}

///|
test "print directive def" {
  let input =
    #|directive @deprecated(reason: String = "No longer supported") on FIELD_DEFINITION | ENUM_VALUE
  let doc = @parser.parse(input)
  inspect(
    @printer.print(doc),
    content=(
      #|directive @deprecated(reason: String = "No longer supported") on FIELD_DEFINITION | ENUM_VALUE
    ),
  )
}

///|
test "print type with description" {
  let input =
    #|"A user in the system"
    #|type User { id: ID! }
  let doc = @parser.parse(input)
  inspect(
    @printer.print(doc),
    content=(
      #|"A user in the system"
      #|type User {
      #|  id: ID!
      #|}
    ),
  )
}

///|
test "print field with arguments" {
  let doc = @parser.parse("type Query { user(id: ID!): User }")
  inspect(
    @printer.print(doc),
    content=(
      #|type Query {
      #|  user(id: ID!): User
      #|}
    ),
  )
}

///|
test "print input value with default" {
  let doc = @parser.parse("type Query { users(limit: Int = 10): [User!]! }")
  inspect(
    @printer.print(doc),
    content=(
      #|type Query {
      #|  users(limit: Int = 10): [User!]!
      #|}
    ),
  )
}

///|
test "print roundtrip preserves AST" {
  let input = "type Query { hero(episode: Episode): Hero }"
  let doc1 = @parser.parse(input)
  let printed = @printer.print(doc1)
  let doc2 = @parser.parse(printed)
  assert_true(doc1 == doc2)
}

///|
test "print roundtrip schema" {
  let input =
    #|directive @deprecated(reason: String = "No longer supported") on FIELD_DEFINITION | ENUM_VALUE
  let doc1 = @parser.parse(input)
  let printed = @printer.print(doc1)
  let doc2 = @parser.parse(printed)
  assert_true(doc1 == doc2)
}

///|
test "print values" {
  let doc = @parser.parse(
    "{ f(a: 1, b: 2.5, c: \"hello\", d: true, e: null, f: ENUM, g: [1, 2], h: {x: 1}) }",
  )
  inspect(
    @printer.print(doc),
    content=(
      #|{
      #|  f(a: 1, b: 2.5, c: "hello", d: true, e: null, f: ENUM, g: [1, 2], h: {x: 1})
      #|}
    ),
  )
}
