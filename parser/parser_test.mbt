///|
test "simple query" {
  let doc = @parser.parse("{ hero { name } }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    Operation(
      #|      {
      #|        operation: Query,
      #|        name: None,
      #|        variables: [],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "hero",
      #|              arguments: [],
      #|              directives: [],
      #|              selections: [
      #|                Field(
      #|                  {
      #|                    field_alias: None,
      #|                    name: "name",
      #|                    arguments: [],
      #|                    directives: [],
      #|                    selections: [],
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "query with args" {
  let doc = @parser.parse("{ hero(id: 1) { name } }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    Operation(
      #|      {
      #|        operation: Query,
      #|        name: None,
      #|        variables: [],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "hero",
      #|              arguments: [{ name: "id", value: IntVal(1) }],
      #|              directives: [],
      #|              selections: [
      #|                Field(
      #|                  {
      #|                    field_alias: None,
      #|                    name: "name",
      #|                    arguments: [],
      #|                    directives: [],
      #|                    selections: [],
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "nested fields" {
  let doc = @parser.parse("{ hero { name friends { name } } }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    Operation(
      #|      {
      #|        operation: Query,
      #|        name: None,
      #|        variables: [],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "hero",
      #|              arguments: [],
      #|              directives: [],
      #|              selections: [
      #|                Field(
      #|                  {
      #|                    field_alias: None,
      #|                    name: "name",
      #|                    arguments: [],
      #|                    directives: [],
      #|                    selections: [],
      #|                  },
      #|                ),
      #|                Field(
      #|                  {
      #|                    field_alias: None,
      #|                    name: "friends",
      #|                    arguments: [],
      #|                    directives: [],
      #|                    selections: [
      #|                      Field(
      #|                        {
      #|                          field_alias: None,
      #|                          name: "name",
      #|                          arguments: [],
      #|                          directives: [],
      #|                          selections: [],
      #|                        },
      #|                      ),
      #|                    ],
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "named query" {
  let doc = @parser.parse("query HeroQuery { hero { name } }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    Operation(
      #|      {
      #|        operation: Query,
      #|        name: Some("HeroQuery"),
      #|        variables: [],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "hero",
      #|              arguments: [],
      #|              directives: [],
      #|              selections: [
      #|                Field(
      #|                  {
      #|                    field_alias: None,
      #|                    name: "name",
      #|                    arguments: [],
      #|                    directives: [],
      #|                    selections: [],
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "mutation" {
  let input =
    #|mutation { createUser(name: "John") { id } }
  let doc = @parser.parse(input)
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    Operation(
      #|      {
      #|        operation: Mutation,
      #|        name: None,
      #|        variables: [],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "createUser",
      #|              arguments: [{ name: "name", value: StringVal("John") }],
      #|              directives: [],
      #|              selections: [
      #|                Field(
      #|                  {
      #|                    field_alias: None,
      #|                    name: "id",
      #|                    arguments: [],
      #|                    directives: [],
      #|                    selections: [],
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "variables" {
  let doc = @parser.parse("query ($id: ID!) { hero(id: $id) { name } }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    Operation(
      #|      {
      #|        operation: Query,
      #|        name: None,
      #|        variables: [
      #|          {
      #|            name: "id",
      #|            var_type: NonNull(Named("ID")),
      #|            default_value: None,
      #|            directives: [],
      #|          },
      #|        ],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "hero",
      #|              arguments: [{ name: "id", value: Variable("id") }],
      #|              directives: [],
      #|              selections: [
      #|                Field(
      #|                  {
      #|                    field_alias: None,
      #|                    name: "name",
      #|                    arguments: [],
      #|                    directives: [],
      #|                    selections: [],
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "fragment spreads" {
  let input =
    #|{ hero { ...heroFields } }
    #|fragment heroFields on Hero { name }
  let doc = @parser.parse(input)
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    Operation(
      #|      {
      #|        operation: Query,
      #|        name: None,
      #|        variables: [],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "hero",
      #|              arguments: [],
      #|              directives: [],
      #|              selections: [FragmentSpread({ name: "heroFields", directives: [] })],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|    Fragment(
      #|      {
      #|        name: "heroFields",
      #|        type_condition: "Hero",
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "name",
      #|              arguments: [],
      #|              directives: [],
      #|              selections: [],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "inline fragments" {
  let doc = @parser.parse("{ hero { ... on Human { height } } }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    Operation(
      #|      {
      #|        operation: Query,
      #|        name: None,
      #|        variables: [],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "hero",
      #|              arguments: [],
      #|              directives: [],
      #|              selections: [
      #|                InlineFragment(
      #|                  {
      #|                    type_condition: Some("Human"),
      #|                    directives: [],
      #|                    selections: [
      #|                      Field(
      #|                        {
      #|                          field_alias: None,
      #|                          name: "height",
      #|                          arguments: [],
      #|                          directives: [],
      #|                          selections: [],
      #|                        },
      #|                      ),
      #|                    ],
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "directives" {
  let doc = @parser.parse("{ hero @include(if: true) { name } }")
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    Operation(
      #|      {
      #|        operation: Query,
      #|        name: None,
      #|        variables: [],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "hero",
      #|              arguments: [],
      #|              directives: [{ name: "include", arguments: [{ name: "if", value: BoolVal(true) }] }],
      #|              selections: [
      #|                Field(
      #|                  {
      #|                    field_alias: None,
      #|                    name: "name",
      #|                    arguments: [],
      #|                    directives: [],
      #|                    selections: [],
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|}
    ),
  )
}

///|
test "multiple operations" {
  let doc = @parser.parse(
    "query A { hero { name } } query B { villain { name } }",
  )
  debug_inspect(
    doc,
    content=(
      #|{
      #|  definitions: [
      #|    Operation(
      #|      {
      #|        operation: Query,
      #|        name: Some("A"),
      #|        variables: [],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "hero",
      #|              arguments: [],
      #|              directives: [],
      #|              selections: [
      #|                Field(
      #|                  {
      #|                    field_alias: None,
      #|                    name: "name",
      #|                    arguments: [],
      #|                    directives: [],
      #|                    selections: [],
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|    Operation(
      #|      {
      #|        operation: Query,
      #|        name: Some("B"),
      #|        variables: [],
      #|        directives: [],
      #|        selections: [
      #|          Field(
      #|            {
      #|              field_alias: None,
      #|              name: "villain",
      #|              arguments: [],
      #|              directives: [],
      #|              selections: [
      #|                Field(
      #|                  {
      #|                    field_alias: None,
      #|                    name: "name",
      #|                    arguments: [],
      #|                    directives: [],
      #|                    selections: [],
      #|                  },
      #|                ),
      #|              ],
      #|            },
      #|          ),
      #|        ],
      #|      },
      #|    ),
      #|  ],
      #|}
    ),
  )
}
