/**
  Module providing general type and symbol compile time queries.
*/
module comet.traits;

/**
  Generates the fields presented by the associated templates.
*/
private mixin template funcInfoMixin( T ) if( isCallable!T ) {

  alias Params = ParameterTypeTuple!T;
  alias Return = ReturnType!T;
  enum arity = Params.length;

}

/**
  Provides the parameters of a callable object.
*/
template FuncInfo( T ) {

  mixin funcInfoMixin!T;
}
///Ditto.
template FuncInfo( alias T ) if( !is( T ) ) {

  mixin funcInfoMixin!( typeof( T ) );

}

