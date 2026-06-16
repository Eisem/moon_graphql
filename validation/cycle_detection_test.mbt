///|
test "detect no cycles in valid fragments" {
  let input =
    #|fragment A on User { ...B }
    #|fragment B on User { name }
    #|{ ...A }
  let doc = @parser.parse(input)
  let errors = @validation.detect_fragment_cycles(doc)
  assert_eq(errors.length(), 0)
}

///|
test "detect direct cycle" {
  let input =
    #|fragment A on User { ...B }
    #|fragment B on User { ...A }
    #|{ ...A }
  let doc = @parser.parse(input)
  let errors = @validation.detect_fragment_cycles(doc)
  assert_true(errors.length() > 0)
}

///|
test "detect self-referencing fragment" {
  let input =
    #|fragment A on User { ...A }
    #|{ ...A }
  let doc = @parser.parse(input)
  let errors = @validation.detect_fragment_cycles(doc)
  assert_true(errors.length() > 0)
}

///|
test "detect indirect cycle" {
  let input =
    #|fragment A on User { ...B }
    #|fragment B on User { ...C }
    #|fragment C on User { ...A }
    #|{ ...A }
  let doc = @parser.parse(input)
  let errors = @validation.detect_fragment_cycles(doc)
  assert_true(errors.length() > 0)
}
