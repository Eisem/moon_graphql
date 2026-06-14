///|
fn main {
  println("=== moon_graphql Demo ===\n")
  let query_str =
    #|query HeroQuery($episode: Episode!) {
    #|  hero(episode: $episode) {
    #|    name
    #|    friends {
    #|      name
    #|    }
    #|  }
    #|}
  let schema_str =
    #|type Query {
    #|  hero(episode: Episode!): Hero
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
  println("--- Parsing query ---")
  let query_doc = try {
    @parser.parse(query_str)
  } catch {
    err => {
      println("Parse error: \{err}")
      return
    }
  }
  println("Query parsed successfully.\n")
  println("--- Parsing schema ---")
  let schema_doc = try {
    @parser.parse(schema_str)
  } catch {
    err => {
      println("Parse error: \{err}")
      return
    }
  }
  println("Schema parsed successfully.\n")
  println("--- Validating query against schema ---")
  let errors = @validation.validate_against_schema(query_doc, schema_doc)
  if errors.is_empty() {
    println("Validation passed: no errors.\n")
  } else {
    println("Validation errors:")
    for err in errors {
      println("  - \{err}")
    }
    println("")
  }
  println("--- Printing formatted query ---")
  println(@printer.print(query_doc))
  println("")
  println("--- Printing formatted schema ---")
  println(@printer.print(schema_doc))
}
