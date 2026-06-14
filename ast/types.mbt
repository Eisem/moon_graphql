///|
pub(all) struct Document {
  definitions : Array[Definition]
} derive(Debug, Eq)

///|
pub(all) enum Definition {
  Operation(OperationDef)
  Fragment(FragmentDef)
  SchemaType(TypeSystemDef)
} derive(Debug, Eq)

///|
pub(all) enum OperationType {
  Query
  Mutation
  Subscription
} derive(Debug, Eq)

///|
pub(all) struct OperationDef {
  operation : OperationType
  name : String?
  variables : Array[VariableDef]
  directives : Array[Directive]
  selections : Array[Selection]
} derive(Debug, Eq)

///|
pub(all) struct FragmentDef {
  name : String
  type_condition : String
  directives : Array[Directive]
  selections : Array[Selection]
} derive(Debug, Eq)

///|
pub(all) enum Selection {
  Field(FieldNode)
  FragmentSpread(FragmentSpreadNode)
  InlineFragment(InlineFragmentNode)
} derive(Debug, Eq)

///|
pub(all) struct FieldNode {
  field_alias : String?
  name : String
  arguments : Array[Argument]
  directives : Array[Directive]
  selections : Array[Selection]
} derive(Debug, Eq)

///|
pub(all) struct FragmentSpreadNode {
  name : String
  directives : Array[Directive]
} derive(Debug, Eq)

///|
pub(all) struct InlineFragmentNode {
  type_condition : String?
  directives : Array[Directive]
  selections : Array[Selection]
} derive(Debug, Eq)

///|
pub(all) struct Argument {
  name : String
  value : Value
} derive(Debug, Eq)

///|
pub(all) struct VariableDef {
  name : String
  var_type : TypeRef
  default_value : Value?
  directives : Array[Directive]
} derive(Debug, Eq)

///|
pub(all) struct Directive {
  name : String
  arguments : Array[Argument]
} derive(Debug, Eq)

///|
pub(all) enum TypeRef {
  Named(String)
  List(TypeRef)
  NonNull(TypeRef)
} derive(Debug, Eq)

///|
pub(all) enum Value {
  IntVal(Int)
  FloatVal(Double)
  StringVal(String)
  BoolVal(Bool)
  NullVal
  EnumVal(String)
  ListVal(Array[Value])
  ObjectVal(Array[(String, Value)])
  Variable(String)
} derive(Debug, Eq)
