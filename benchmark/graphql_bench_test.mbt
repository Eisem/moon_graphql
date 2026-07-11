///|
let benchmark_schema =
  #|type Query { user(id: ID!): User }
  #|type User { id: ID! name: String email: String friends: [User!]! }

///|
fn make_query(field_count : Int) -> String {
  let output = StringBuilder::new()
  output.write_string("query Benchmark {\n")
  for i in 0..<field_count {
    output.write_string("  user")
    output.write_string(i.to_string())
    output.write_string(": user(id: ")
    output.write_string(i.to_string())
    output.write_string(") { id name email friends { id name } }\n")
  }
  output.write_string("}")
  output.to_string()
}

///|
test "bench parse query fields=10" (it : @bench.T) {
  let input = make_query(10)
  it.bench(fn() { it.keep(try! @parser.parse(input)) })
}

///|
test "bench parse query fields=100" (it : @bench.T) {
  let input = make_query(100)
  it.bench(fn() { it.keep(try! @parser.parse(input)) })
}

///|
test "bench print query fields=100" (it : @bench.T) {
  let document = try! @parser.parse(make_query(100))
  it.bench(fn() { it.keep(@printer.print(document)) })
}

///|
test "bench validate query fields=100" (it : @bench.T) {
  let schema = try! @parser.parse(benchmark_schema)
  let document = try! @parser.parse(make_query(100))
  it.bench(fn() {
    it.keep(@validation.validate_against_schema(document, schema))
  })
}

///|
test "bench parse validate print fields=100" (it : @bench.T) {
  let schema = try! @parser.parse(benchmark_schema)
  let input = make_query(100)
  it.bench(fn() {
    let document = try! @parser.parse(input)
    let errors = @validation.validate_against_schema(document, schema)
    let output = @printer.print(document)
    it.keep((errors.length(), output.length()))
  })
}
