// Original boundary cases derived from the GraphQL Int input type definition
// in the GraphQL Specification, October 2021 Edition.

///|
fn parse_rejects(input : String) -> Bool {
  let result = Ok(@parser.parse(input)) catch { _ => Err("parse error") }
  result is Err(_)
}

///|
test "conformance: GraphQL Int accepts signed 32-bit boundaries" {
  let doc = @parser.parse("{ field(min: -2147483648, max: 2147483647) }")
  guard doc.definitions[0] is Operation(operation)
  guard operation.selections[0] is Field(field)
  assert_true(field.arguments[0].value == IntVal(-2147483648))
  assert_true(field.arguments[1].value == IntVal(2147483647))
}

///|
test "conformance: GraphQL Int rejects values outside signed 32-bit range" {
  assert_true(parse_rejects("{ field(value: 2147483648) }"))
  assert_true(parse_rejects("{ field(value: -2147483649) }"))
  assert_true(parse_rejects("{ field(value: 99999999999999999999) }"))
}
