/**
  Module providing general type and symbol compile time queries.
*/
module comet.traits;

import std.traits;

/**
  Returns the string name of the identifier as provided by __traits( identifier, var ).
*/
template identifier( alias var ) {
  enum identifier = __traits( identifier, var );  
}


/**
  Generates the fields presented by the associated templates.
*/
private mixin template funcInfoMixin( T ) if( isCallable!T ) {

  alias Params = ParameterTypeTuple!T;
  alias Return = ReturnType!T;
  enum arity = Params.length;
  
  template hasReturn() {
    
    static if( !is( Return == void ) ) {
    
      enum hasReturn = true;
      
    } else {
    
      enum hasReturn = false;
    
    }
  
  }

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

