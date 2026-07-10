# GraphQL conformance

`moon_graphql` currently targets the [GraphQL Specification, October 2021 Edition](https://spec.graphql.org/October2021/). This document separates implemented syntax support from semantic validation and runtime features so users can evaluate the library without assuming full GraphQL server support.

Status meanings:

- **Supported**: implemented and covered by automated tests.
- **Partial**: useful coverage exists, but important specification behavior remains.
- **Not implemented**: outside the current implementation.

## Language support

| Area | Status | Notes |
| --- | --- | --- |
| Executable definitions | Supported | Query, mutation, subscription, shorthand query, variables, aliases, arguments, directives, named and inline fragments |
| Value and type syntax | Supported | Scalars, enum values, null, lists, input objects, variables, list/non-null type references |
| Type-system definitions | Supported | Schema, scalar, object, interface, union, enum, input object, and directive definitions |
| Type-system extensions | Not implemented | `extend schema`, `extend type`, and the other SDL extension forms are not represented in the AST |
| String lexical semantics | Partial | Common escapes and block strings parse; Unicode escape decoding, invalid-escape rejection, and block-string value normalization are incomplete |
| Number lexical semantics | Partial | Integer, float, and exponent forms parse; every invalid GraphQL numeric spelling is not yet rejected lexically |
| AST printer | Supported | Executable and SDL definitions round-trip through parse → print → parse; comments and original whitespace are intentionally not preserved |

## Validation support

| Rule family | Status | Notes |
| --- | --- | --- |
| Operation and fragment name uniqueness | Supported | Duplicate named operations/fragments and documents mixing anonymous with other operations are rejected |
| Fragment spread existence and cycles | Supported | Undefined spreads and direct/indirect cycles are rejected by `validate()` |
| Variables | Partial | Names, declared input types, constant/default values, undefined references, transitive fragment/directive usage, and argument-position type compatibility are checked; unused-variable detection remains |
| Field existence | Partial | Object/interface fields and fields inside named/inline fragments are checked; field merging and type-overlap rules remain |
| Leaf/composite selection shape | Supported | Leaf fields reject sub-selections; object/interface/union fields require them |
| Union selections | Supported | `__typename` and type-conditioned fragments are accepted; direct member-field selection is rejected |
| Field arguments | Supported | Missing required, unknown, and duplicate arguments are rejected |
| Fragment type conditions | Partial | Unknown and non-composite conditions are rejected; possible-type overlap checks remain |
| Directives | Partial | October 2021 built-ins and schema-defined directives are checked for name, executable location, repeatability, and arguments; argument value coercion and SDL directive validation remain |
| Input coercion | Partial | Built-in scalars, enums, nullability, list single-value coercion, and nested input objects are checked; custom scalar semantics are application-defined |
| Schema validation | Not implemented | Type uniqueness, interface implementation, union members, input/output positions, and root-type validation remain |

## Runtime scope

The project is a GraphQL language toolkit, not a GraphQL server runtime. Execution, resolvers, introspection execution, HTTP/WebSocket transport, subscriptions, federation, code generation, and client caching are not implemented.

## Test provenance

The focused cases in `validation/conformance_test.mbt` are original minimal fixtures derived from specification behavior. No test fixture or implementation source was copied from `graphql-js` or other GraphQL libraries. Run all checks with:

```sh
moon check --deny-warn
moon test --deny-warn
moon fmt --check
```

This is a capability matrix, not a claim of official GraphQL certification. Future conformance work should add a larger categorized corpus and report pass counts by specification section.
