/**
  This module provide the formal interface that mutation cost calculators must
  implement.
*/
module comet.sma.mutation_cost;

public import comet.typedefs: Cost;

import comet.traits;

import std.traits;

/**
  Proxy function that returns the mutation cost of the inital state to
  the mutated state given the mutation cost provider.
  
  It is to be used to encapsulate how the mutation cost provider is really
  handled.
*/
Cost costFor( M, State )( M mCosts, State initial, State mutated ) if( isMutationCost!M ) {

  return mCosts( initial, mutated );

}

/**
  This interface formalize the interface of the callable object responsible
  for providing the cost of a mutation between two states.
  
  A mutation cost is a callable object that returns the cost of a mutation of
  an initial state to a mutated state.
*/
interface MutationCost( T ) {

  Cost opCall( T initialState, T mutatedState );
  
}

/**
  Returns true if the given callable object implements the mutation cost provider interface.
*/
template isMutationCost( T ) if( isCallable!T ) {
  
  alias Params = FuncInfo!T.Params;
  alias Return = FuncInfo!T.Return;  

  static if( isImplicitlyConvertible!( Return, Cost ) && Params.length == 2 && is( Params[ 0 ] == Params[ 1 ] ) ) {

    enum isMutationCost = true;
    
  } else {
  
    enum isMutationCost = false;
  
  }
  
}
///Ditto.
template isMutationCost( alias symbol ) if( !is( symbol ) ) {

  enum isMutationCost = isMutationCost!( typeof( symbol ) );

}

/**
  Returns true if the mutation cost callable passed provides mutation costs for the
  given type.
*/
template isMutationCostFor( T, State ) if( isMutationCost!T ) {
 
  alias Params = FuncInfo!T.Params;
  
  static if( is( Params[ 0 ] == State ) && is( Params[ 1 ] == State ) ) {
  
    enum isMutationCostFor = true;
    
  } else {
  
    enum isMutationCostFor = false;
  
  }

}
///Ditto.
template isMutationCostFor( alias T, State ) if( !is( T ) ) {
 
  enum isMutationCostFor = isMutationCostFor!( typeof( T ), State );

}

unittest {

  Cost foo( int s, int t ) { return 0; }

  static assert( isMutationCost!( foo ) );
  static assert( isMutationCost!( typeof( foo ) ) );
  static assert( isMutationCostFor!( foo, int ) );
  static assert( !isMutationCostFor!( foo, double ) );
  
  struct Bar {
  
    Cost opCall( double s, double t ) { return 0; }
  
  }
  
  static assert( isMutationCost!Bar );
  static assert( isMutationCostFor!( Bar, double ) );
  static assert( !isMutationCostFor!( Bar, int ) );

  void choochoo( float x, float y ) {}
  
  static assert( !isMutationCost!choochoo );
  static assert( !__traits( compiles, isMutationCostFor!( choochoo, float ) ) );


}

