///|
test "parse object type" {
  let doc = @parser.parse("type User { id: ID! name: String }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      ObjectType(
      #|        {
      #|          description: None,
      #|          name: "User",
      #|          interfaces: [],
      #|          directives: [],
      #|          fields: [
      #|            {
      #|              description: None,
      #|              name: "id",
      #|              arguments: [],
      #|              field_type: NonNull(Named("ID")),
      #|              directives: [],
      #|            },
      #|            {
      #|              description: None,
      #|              name: "name",
      #|              arguments: [],
      #|              field_type: Named("String"),
      #|              directives: [],
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse object type with implements" {
  let doc = @parser.parse("type User implements Node & Entity { id: ID! }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      ObjectType(
      #|        {
      #|          description: None,
      #|          name: "User",
      #|          interfaces: ["Node", "Entity"],
      #|          directives: [],
      #|          fields: [
      #|            {
      #|              description: None,
      #|              name: "id",
      #|              arguments: [],
      #|              field_type: NonNull(Named("ID")),
      #|              directives: [],
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse interface type" {
  let doc = @parser.parse("interface Node { id: ID! }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      InterfaceType(
      #|        {
      #|          description: None,
      #|          name: "Node",
      #|          interfaces: [],
      #|          directives: [],
      #|          fields: [
      #|            {
      #|              description: None,
      #|              name: "id",
      #|              arguments: [],
      #|              field_type: NonNull(Named("ID")),
      #|              directives: [],
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse union type" {
  let doc = @parser.parse("union SearchResult = User | Post | Comment")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      UnionType(
      #|        {
      #|          description: None,
      #|          name: "SearchResult",
      #|          directives: [],
      #|          members: ["User", "Post", "Comment"],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse enum type" {
  let doc = @parser.parse("enum Role { ADMIN USER MODERATOR }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      EnumType(
      #|        {
      #|          description: None,
      #|          name: "Role",
      #|          directives: [],
      #|          values: [
      #|            { description: None, name: "ADMIN", directives: [] },
      #|            { description: None, name: "USER", directives: [] },
      #|            { description: None, name: "MODERATOR", directives: [] },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse input object type" {
  let doc = @parser.parse(
    "input CreateUserInput { name: String! email: String }",
  )
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      InputObjectType(
      #|        {
      #|          description: None,
      #|          name: "CreateUserInput",
      #|          directives: [],
      #|          fields: [
      #|            {
      #|              description: None,
      #|              name: "name",
      #|              input_type: NonNull(Named("String")),
      #|              default_value: None,
      #|              directives: [],
      #|            },
      #|            {
      #|              description: None,
      #|              name: "email",
      #|              input_type: Named("String"),
      #|              default_value: None,
      #|              directives: [],
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse scalar type" {
  let doc = @parser.parse("scalar DateTime")
  debug_inspect(
    doc,
    content=(
      #|{ definitions: [SchemaType(ScalarType({ description: None, name: "DateTime", directives: [] }))] }
    ),
  )
}

///|
test "parse schema def" {
  let doc = @parser.parse(
    "schema { query: Query mutation: Mutation subscription: Subscription }",
  )
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      SchemaDefinition(
      #|        {
      #|          directives: [],
      #|          query: Some("Query"),
      #|          mutation: Some("Mutation"),
      #|          subscription: Some("Subscription"),
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse directive def" {
  let input =
    #|directive @deprecated(reason: String = "No longer supported") on FIELD_DEFINITION | ENUM_VALUE
  let doc = @parser.parse(input)
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      DirectiveDefinition(
      #|        {
      #|          description: None,
      #|          name: "deprecated",
      #|          arguments: [
      #|            {
      #|              description: None,
      #|              name: "reason",
      #|              input_type: Named("String"),
      #|              default_value: Some(StringVal("No longer supported")),
      #|              directives: [],
      #|            },
      #|          ],
      #|          repeatable: false,
      #|          locations: ["FIELD_DEFINITION", "ENUM_VALUE"],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse field with arguments" {
  let doc = @parser.parse("type Query { user(id: ID!): User }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      ObjectType(
      #|        {
      #|          description: None,
      #|          name: "Query",
      #|          interfaces: [],
      #|          directives: [],
      #|          fields: [
      #|            {
      #|              description: None,
      #|              name: "user",
      #|              arguments: [
      #|                {
      #|                  description: None,
      #|                  name: "id",
      #|                  input_type: NonNull(Named("ID")),
      #|                  default_value: None,
      #|                  directives: [],
      #|                },
      #|              ],
      #|              field_type: Named("User"),
      #|              directives: [],
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse type with description" {
  let input =
    #|"A user in the system"
    #|type User { id: ID! }
  let doc = @parser.parse(input)
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      ObjectType(
      #|        {
      #|          description: Some("A user in the system"),
      #|          name: "User",
      #|          interfaces: [],
      #|          directives: [],
      #|          fields: [
      #|            {
      #|              description: None,
      #|              name: "id",
      #|              arguments: [],
      #|              field_type: NonNull(Named("ID")),
      #|              directives: [],
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse input value with default" {
  let doc = @parser.parse("type Query { users(limit: Int = 10): [User!]! }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      ObjectType(
      #|        {
      #|          description: None,
      #|          name: "Query",
      #|          interfaces: [],
      #|          directives: [],
      #|          fields: [
      #|            {
      #|              description: None,
      #|              name: "users",
      #|              arguments: [
      #|                {
      #|                  description: None,
      #|                  name: "limit",
      #|                  input_type: Named("Int"),
      #|                  default_value: Some(IntVal(10)),
      #|                  directives: [],
      #|                },
      #|              ],
      #|              field_type: NonNull(List(NonNull(Named("User")))),
      #|              directives: [],
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse repeatable directive" {
  let doc = @parser.parse(
    "directive @tag(name: String!) repeatable on OBJECT | INTERFACE",
  )
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      DirectiveDefinition(
      #|        {
      #|          description: None,
      #|          name: "tag",
      #|          arguments: [
      #|            {
      #|              description: None,
      #|              name: "name",
      #|              input_type: NonNull(Named("String")),
      #|              default_value: None,
      #|              directives: [],
      #|            },
      #|          ],
      #|          repeatable: true,
      #|          locations: ["OBJECT", "INTERFACE"],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "parse mixed definitions" {
  let input =
    #|type Query { hero: Hero }
    #|type Hero { name: String }
  let doc = @parser.parse(input)
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    SchemaType(
      #|      ObjectType(
      #|        {
      #|          description: None,
      #|          name: "Query",
      #|          interfaces: [],
      #|          directives: [],
      #|          fields: [
      #|            {
      #|              description: None,
      #|              name: "hero",
      #|              arguments: [],
      #|              field_type: Named("Hero"),
      #|              directives: [],
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|    SchemaType(
      #|      ObjectType(
      #|        {
      #|          description: None,
      #|          name: "Hero",
      #|          interfaces: [],
      #|          directives: [],
      #|          fields: [
      #|            {
      #|              description: None,
      #|              name: "name",
      #|              arguments: [],
      #|              field_type: Named("String"),
      #|              directives: [],
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|  ],
      #|}
    ),
  )
}
