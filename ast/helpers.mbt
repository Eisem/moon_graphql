///|
pub fn Document::operations(self : Document) -> Array[OperationDef] {
  let ops : Array[OperationDef] = []
  for def in self.definitions {
    match def {
      Operation(op) => ops.push(op)
      _ => ()
    }
  }
  ops
}

///|
pub fn Document::fragments(self : Document) -> Array[FragmentDef] {
  let frags : Array[FragmentDef] = []
  for def in self.definitions {
    match def {
      Fragment(f) => frags.push(f)
      _ => ()
    }
  }
  frags
}

///|
pub fn Document::type_defs(self : Document) -> Array[TypeSystemDef] {
  let types : Array[TypeSystemDef] = []
  for def in self.definitions {
    match def {
      SchemaType(t) => types.push(t)
      _ => ()
    }
  }
  types
}

///|
pub fn TypeRef::name(self : TypeRef) -> String {
  match self {
    Named(n) => n
    List(inner) => inner.name()
    NonNull(inner) => inner.name()
  }
}

///|
pub fn TypeRef::is_non_null(self : TypeRef) -> Bool {
  match self {
    NonNull(_) => true
    _ => false
  }
}

///|
pub fn TypeRef::is_list(self : TypeRef) -> Bool {
  match self {
    List(_) => true
    NonNull(List(_)) => true
    _ => false
  }
}

///|
pub fn OperationDef::has_variables(self : OperationDef) -> Bool {
  !self.variables.is_empty()
}

///|
pub fn OperationDef::has_directives(self : OperationDef) -> Bool {
  !self.directives.is_empty()
}

///|
pub fn FieldNode::has_arguments(self : FieldNode) -> Bool {
  !self.arguments.is_empty()
}

///|
pub fn FieldNode::has_selections(self : FieldNode) -> Bool {
  !self.selections.is_empty()
}

///|
pub fn Value::is_null(self : Value) -> Bool {
  match self {
    NullVal => true
    _ => false
  }
}

///|
pub fn Value::as_int(self : Value) -> Int? {
  match self {
    IntVal(n) => Some(n)
    _ => None
  }
}

///|
pub fn Value::as_string(self : Value) -> String? {
  match self {
    StringVal(s) => Some(s)
    _ => None
  }
}

///|
pub fn Value::as_bool(self : Value) -> Bool? {
  match self {
    BoolVal(b) => Some(b)
    _ => None
  }
}

///|
pub fn Value::as_list(self : Value) -> Array[Value]? {
  match self {
    ListVal(arr) => Some(arr)
    _ => None
  }
}
