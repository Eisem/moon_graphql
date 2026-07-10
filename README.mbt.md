# eisem/moon_graphql

A GraphQL language parser, validator, and printer toolkit for MoonBit.

This project provides language-processing infrastructure rather than a GraphQL server runtime. See the [conformance matrix](CONFORMANCE.md) for the exact specification coverage and current limitations.

## Installation

```sh
moon add eisem/moon_graphql
```

## Quick Start

### Parse a Query

```mbt check
///|
test "parse query example" {
  let input =
    #|query HeroQuery($id: ID!) {
    #|  hero(id: $id) {
    #|    name
    #|  }
    #|}
  let doc = @parser.parse(input)
  assert_true(doc.definitions.length() == 1)
}
```

### Parse a Schema

```mbt check
///|
test "parse schema example" {
  let input =
    #|type Query {
    #|  hero(episode: Episode): Hero
    #|}
    #|type Hero {
    #|  name: String
    #|  friends: [Hero]
    #|}
  let doc = @parser.parse(input)
  assert_true(doc.definitions.length() == 2)
}
```

### Print AST

```mbt check
///|
test "print AST example" {
  let doc = @parser.parse("{ hero { name } }")
  let output = @printer.print(doc)
  inspect(
    output,
    content=(
      #|{
      #|  hero {
      #|    name
      #|  }
      #|}
    ),
  )
}
```

### Validate a Query

```mbt check
///|
test "validate example" {
  let doc = @parser.parse("{ hero { ...missing } }")
  let errors = @validation.validate(doc)
  assert_true(errors.length() > 0)
}
```

### Validate Against a Schema

```mbt check
///|
test "validate against schema example" {
  let schema_input =
    #|type Query { hero: Hero }
    #|type Hero { name: String }
  let schema = @parser.parse(schema_input)
  let query = @parser.parse("{ hero { name } }")
  let errors = @validation.validate_against_schema(query, schema)
  assert_true(errors.is_empty())
}
```

## Supported Features

### Query Language
- Operations: query, mutation, subscription
- Named and anonymous operations
- Field selections with aliases
- Arguments with all value types (Int, Float, String, Boolean, Null, Enum, List, Object)
- Variables with types and default values
- Fragments (named spreads and inline fragments)
- Directives

### Schema Definition Language
- Type definitions: object, interface, union, enum, input, scalar
- Schema definition with root operation types
- Field arguments and input value definitions
- Type descriptions (string literals)
- Interface implementations
- Directive definitions with locations and repeatability

### Validation
- Unique fragment names
- Fragment spread references
- Fragment cycle detection
- Unique operation names
- Lone anonymous operation checks
- Unique variable names and undefined-variable checks across directives/fragments
- Variable input-type, default-value, and argument-position compatibility checks
- Field existence on types (schema-aware)
- Field argument uniqueness, existence, and required-argument checks
- Built-in scalar, enum, list, and input-object literal coercion checks
- Built-in and schema-defined Directive name, location, repeatability, and argument checks
- Leaf/composite field selection checks
- Named and inline fragment field validation
- Union selections through type-conditioned fragments
- Fragment type-condition checks
- Structured error types with error/warning classification

Validation is intentionally incremental and does not yet implement every executable-document or schema rule from the GraphQL specification. In particular, unused-variable detection, custom scalar coercion, field merging, possible-type overlap, and schema validation remain. See [GraphQL conformance](CONFORMANCE.md).

### Error Reporting
- Parse errors with line/column location information
- Validation errors as structured `ValidationError` types
  - `message()` - human-readable error description
  - `is_error()` / `is_warning()` - error severity check

## Project Structure

```
moon_graphql/
  ast/           - AST type definitions
  lexer/         - Tokenizer
  parser/        - Query and schema parsers
  printer/       - AST to GraphQL text
  validation/    - Document and schema validation (including cycle detection)
  integration/   - Integration tests
  cmd/main/      - CLI demo
```
