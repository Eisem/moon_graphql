///|
pub(all) enum TypeSystemDef {
  SchemaDefinition(SchemaDef)
  ScalarType(ScalarTypeDef)
  ObjectType(ObjectTypeDef)
  InterfaceType(InterfaceTypeDef)
  UnionType(UnionTypeDef)
  EnumType(EnumTypeDef)
  InputObjectType(InputObjectTypeDef)
  DirectiveDefinition(DirectiveDef)
} derive(Debug, Eq)

///|
pub(all) struct SchemaDef {
  directives : Array[Directive]
  query : String?
  mutation : String?
  subscription : String?
} derive(Debug, Eq)

///|
pub(all) struct ScalarTypeDef {
  description : String?
  name : String
  directives : Array[Directive]
} derive(Debug, Eq)

///|
pub(all) struct FieldDef {
  description : String?
  name : String
  arguments : Array[InputValueDef]
  field_type : TypeRef
  directives : Array[Directive]
} derive(Debug, Eq)

///|
pub(all) struct InputValueDef {
  description : String?
  name : String
  input_type : TypeRef
  default_value : Value?
  directives : Array[Directive]
} derive(Debug, Eq)

///|
pub(all) struct ObjectTypeDef {
  description : String?
  name : String
  interfaces : Array[String]
  directives : Array[Directive]
  fields : Array[FieldDef]
} derive(Debug, Eq)

///|
pub(all) struct InterfaceTypeDef {
  description : String?
  name : String
  interfaces : Array[String]
  directives : Array[Directive]
  fields : Array[FieldDef]
} derive(Debug, Eq)

///|
pub(all) struct UnionTypeDef {
  description : String?
  name : String
  directives : Array[Directive]
  members : Array[String]
} derive(Debug, Eq)

///|
pub(all) struct EnumTypeDef {
  description : String?
  name : String
  directives : Array[Directive]
  values : Array[EnumValueDef]
} derive(Debug, Eq)

///|
pub(all) struct EnumValueDef {
  description : String?
  name : String
  directives : Array[Directive]
} derive(Debug, Eq)

///|
pub(all) struct InputObjectTypeDef {
  description : String?
  name : String
  directives : Array[Directive]
  fields : Array[InputValueDef]
} derive(Debug, Eq)

///|
pub(all) struct DirectiveDef {
  description : String?
  name : String
  arguments : Array[InputValueDef]
  repeatable : Bool
  locations : Array[String]
} derive(Debug, Eq)
