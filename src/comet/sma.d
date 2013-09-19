/**
  State Mutation Analysis (sma) module.
*/
module comet.sma;

import deimos.containers.tree;

import std.algorithm;

alias double Cost;

/**
  Every state's associated information.
  This structure does not hold the state only
  because it was meant to be used associatively.
  Every state has a cost and a number of occurrences.
  
  The number of occurrences is only valid for the
  subtree under the node holding the state. Therefore,
  if the node is the root, then the number of occurrences
  held will be the absolute value. For any other node,
  the absolute number has to be recalculated based on
  its parent node and the equivalent states that can
  be chosen as minimal mutation cost candidates.
  
  The default value is expected to hold the minimal
  number of occurrences and the maximum possibl cost.
*/
struct StateInfo {
  size_t count = 0;
  Cost cost = Cost.max;
}

/**
  States info is nothing more than an entity responsible for holding
  the state info of every known state for its embedding node. In other
  words, it acts as a map.
*/
struct StatesInfo( T ) {
  private StateInfo[ T ] _infos; //Each state is associated with a tuple of data.
  
  /**
    Creates an entry for every given state provided by the range and initializes
    their cost with the provided value.
  */
  this( Range )( Range states, Cost initialCost = 0 ) {
    foreach( s; states ) {
      _infos[ s ] = StateInfo( 0, initialCost );
    }
  }
  
  /**
    Indicates that the given state is known to be present, therefore
    favoring him when considering every possible states.
    Sets the state's cost to 0 and every other costs to the maximum value.
  */
  void fixState( T state ) {
    _infos[ state ] = StateInfo( 1, 0.0 );
    //Reset other states to the maximum cost
    //and remove their occurrences count.
    foreach( s, ref info; _infos ) {
      if( s != state ) {        
        info = StateInfo.init;
      }
    }
  }
  
  //TODO: refactor this code.
  
  ref Cost cost( T state ) {
    if( state !in _infos ) {
      _infos[ state ] = StateInfo.init;
    }
    return _infos[ state ].cost;
  }
  
  ref size_t count( T state ) {
    if( state !in _infos ) {
      _infos[ state ] = StateInfo.init;
    }
    return _infos[ state ].count;
  }
  
  @property Cost minCost() {
    auto min = Cost.max;
    foreach( s, info; _infos ) {
      if( info.cost < min ) { min = info.cost; }
    }
    return min;
  }
    
  int opApply( int delegate( ref T, ref StateInfo ) dg ) {
    int result = 0;
    foreach( s, info; _infos ) {
      result = dg( s, info );
      if( result ) break;
    }
    return result;
  }
    
  int opApply( int delegate( ref T, ref Cost ) dg ) {
    int result = 0;
    foreach( s, info; _infos ) {
      result = dg( s, info.cost );
      if( result ) break;
    }
    return result;
  }
  
  int opApply( int delegate( ref T, ref size_t ) dg ) {
    int result = 0;
    foreach( s, info; _infos ) {
      result = dg( s, info.count );
      if( result ) break;
    }
    return result;
  }
  
  int opApply( int delegate( ref T ) dg ) {
    int result = 0;
    foreach( s, _; _infos ) {
      result = dg( s );
      if( result ) break;
    }
    return result;
  }
  
  int opApply( int delegate( ref Cost ) dg ) {
    int result = 0;
    foreach( _, info; _infos ) {
      result = dg( info.cost );
      if( result ) break;
    }
    return result;
  }
  
  int opApply( int delegate( ref size_t ) dg ) {
    int result = 0;
    foreach( _, info; _infos ) {
      result = dg( info.count );
      if( result ) break;
    }
    return result;
  }
  
}

unittest {  
  import deimos.bio.dna;
  auto sc = StatesInfo!( Nucleotide )();
  
  Nucleotide[] nucleotides = [];
  foreach( str; __traits( allMembers, Nucleotide ) ) {
    nucleotides ~= mixin( "Nucleotide." ~ str );
  }
  auto counter = 0;
  foreach( n; nucleotides ) {
    sc.cost( n ) = counter;
    sc.count( n ) = counter * 2;
    ++counter;
  }
  counter = 0;
  foreach( n; nucleotides ) {
    assert( sc.cost( n ) == counter );
    assert( sc.count( n ) == counter * 2 );
    ++counter;
  } 
}

//TODO: maybe find a better place than at module scope.
Cost mutationCost( T, U )( Cost base, T initial, T mutated, U mutationCosts ) {
  return base + mutationCosts( initial, mutated );
}

Cost minMutationCost( T, U )( T initialState, StatesInfo!T si, U mutationCosts ) {
  auto min = Cost.max;
  foreach( candidate, ref Cost itsCost; si ) {
    auto mutationCost = mutationCost( itsCost, initialState, candidate, mutationCosts );
    if( mutationCost < min ) { min = mutationCost; }
  }  
  return min;

} 

struct SMTree( T ) {
private:
  Tree!( StatesInfo!T ) _tree;
  
  //Expects the leaves to be set.
  private void gatherInfo( N, Range, U )( N node, Range states, U mutationCosts ) {
    //Do nothing if it is a leaf.
    if( !node.hasChildren() ) { return; }
    
    foreach( children; node.children ) {
      gatherInfo( children, states, mutationCosts );
    }
    foreach( state; states ) {
      Cost costSum = 0;
      //Reconstruction counts.
      size_t rCount = 1;
      foreach( children; node.children ) {
        auto minCost = minMutationCost( state, children.element, mutationCosts );
        assert( minCost < Cost.max );
        costSum += minCost;
        
        size_t minCostMutations = 0;        
        foreach( childState, ref StateInfo childInfo; children.element ) {
          if( mutationCost( childInfo.cost, state, childState, mutationCosts ) == minCost ) {
            minCostMutations += childInfo.count;
          }
        }
        assert( 0 < minCostMutations );
        rCount *= minCostMutations;
      }
      node.element.cost( state ) = costSum;
      node.element.count( state ) = rCount;
    }
  }  
    
public:
  auto opDispatch( string method, T... )( T args ) {
    return mixin( "_tree." ~ method )( args );
  }
  
  /**
    Updates the tree given the used states and the mutation costs
    provider, which has to respond to the MutationCosts interface
    for the given states type.
    
    This method is only to be used once the leaves have been set
    to a given state.
  */
  void update( Range, U )( Range states, U mutationCosts ) {
    assert( !_tree.empty );
    gatherInfo( _tree.root, states, mutationCosts );
  }
}

/**
  This interface represents the behavior must support the entity
  responsible for providing the cost of a mutation between two states.
*/
interface MutationCosts( T ) {
  Cost opCall( T initialState, T mutatedState );
}

unittest {
  import deimos.bio.dna;
  
  auto validStates = [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE ];
  auto initCosts = () { return StatesInfo!( Nucleotide )( validStates ); };
  
  auto tree = SMTree!( Nucleotide )();
  tree.clear();
  
  //First level.
  auto root = tree.setRoot( initCosts() );  
  
  //Second level.
  auto left = tree.appendChild( root, initCosts() );
  auto right = tree.appendChild( root, initCosts() );
  
  //Third level.
  auto leftLeft = tree.appendChild( left, initCosts() );
  //Third leaf.
  auto leftRight = tree.appendChild( left, initCosts() );
  leftRight.element.fixState( Nucleotide.CYTOSINE );
  auto rightLeft = tree.appendChild( right, initCosts() );
  //Sixth leaf.
  auto rightRight = tree.appendChild( right, initCosts() );
  rightRight.element.fixState( Nucleotide.CYTOSINE );
    
  //Fourth level.
  //First leaf.
  auto leftLeftLeft = tree.appendChild( leftLeft, initCosts() );
  leftLeftLeft.element.fixState( Nucleotide.ADENINE );
  //Second leaf.
  auto leftLeftRight = tree.appendChild( leftLeft, initCosts() );
  leftLeftRight.element.fixState( Nucleotide.GUANINE );
  //Fourth leaf.
  auto rightLeftLeft = tree.appendChild( rightLeft, initCosts() );
  rightLeftLeft.element.fixState( Nucleotide.THYMINE );
  //Fifth leaf.
  auto rightLeftRight = tree.appendChild( rightLeft, initCosts() );
  rightLeftRight.element.fixState( Nucleotide.ADENINE );
   
  tree.update( 
    validStates,
    ( Nucleotide n1, Nucleotide n2 ){ 
      if( n1 == n2 ) {
        return 0;
      }
      return 1;
    } 
  );
  
  //First leaf: [ A: 0, C: max, G: max, T: max ]  
  assert( leftLeftLeft.element.cost( Nucleotide.ADENINE )  == 0 );
  assert( leftLeftLeft.element.cost( Nucleotide.CYTOSINE ) == Cost.max );
  assert( leftLeftLeft.element.cost( Nucleotide.GUANINE )  == Cost.max );
  assert( leftLeftLeft.element.cost( Nucleotide.THYMINE )  == Cost.max );
  
  //Second leaf: [ A: max, C: max, G: 0, T: max ]  
  assert( leftLeftRight.element.cost( Nucleotide.ADENINE )  == Cost.max );
  assert( leftLeftRight.element.cost( Nucleotide.CYTOSINE ) == Cost.max );
  assert( leftLeftRight.element.cost( Nucleotide.GUANINE )  == 0 );
  assert( leftLeftRight.element.cost( Nucleotide.THYMINE )  == Cost.max );
  
  //Third leaf: [ A: max, C: 0, G: max, T: max ]  
  assert( leftRight.element.cost( Nucleotide.ADENINE )  == Cost.max );
  assert( leftRight.element.cost( Nucleotide.CYTOSINE ) == 0 );
  assert( leftRight.element.cost( Nucleotide.GUANINE )  == Cost.max );
  assert( leftRight.element.cost( Nucleotide.THYMINE )  == Cost.max );
  
  //Fourth leaf: [ A: max, C: max, G: max, T: 0 ]  
  assert( rightLeftLeft.element.cost( Nucleotide.ADENINE )  == Cost.max );
  assert( rightLeftLeft.element.cost( Nucleotide.CYTOSINE ) == Cost.max );
  assert( rightLeftLeft.element.cost( Nucleotide.GUANINE )  == Cost.max );
  assert( rightLeftLeft.element.cost( Nucleotide.THYMINE )  == 0 );
  
  //Fifth leaf: [ A: 0, C: max, G: max, T: max ]  
  assert( rightLeftRight.element.cost( Nucleotide.ADENINE )  == 0 );
  assert( rightLeftRight.element.cost( Nucleotide.CYTOSINE ) == Cost.max );
  assert( rightLeftRight.element.cost( Nucleotide.GUANINE )  == Cost.max );
  assert( rightLeftRight.element.cost( Nucleotide.THYMINE )  == Cost.max );
  
  //Sixth leaf: [ A: max, C: 0, G: max, T: max ]  
  assert( rightRight.element.cost( Nucleotide.ADENINE )  == Cost.max );
  assert( rightRight.element.cost( Nucleotide.CYTOSINE ) == 0 );
  assert( rightRight.element.cost( Nucleotide.GUANINE )  == Cost.max );
  assert( rightRight.element.cost( Nucleotide.THYMINE )  == Cost.max );
    
  //Root: [ A: 4, C: 4, G: 5, T: 5 ]  
  assert( root.element.cost( Nucleotide.ADENINE )  == 4 );
  assert( root.element.cost( Nucleotide.CYTOSINE ) == 4 );
  assert( root.element.cost( Nucleotide.GUANINE )  == 5 );
  assert( root.element.cost( Nucleotide.THYMINE )  == 5 );
  assert( root.element.count( Nucleotide.ADENINE )  == 1 );
  assert( root.element.count( Nucleotide.CYTOSINE )  == 9 );
  assert( root.element.count( Nucleotide.GUANINE )  == 8 );
  assert( root.element.count( Nucleotide.THYMINE )  == 8 );
}

//Redo with a known special case.
//cactga
unittest {
  import deimos.bio.dna;

  SMTree!Nucleotide tree;
  
  tree.clear();
  auto root = tree.setRoot();
  
  //Left subtree.
  auto left = tree.appendChild( root );  
  //First leaf.
  auto leftLeft = tree.appendChild( left );
  leftLeft.element.fixState( Nucleotide.CYTOSINE );
  auto leftRight = tree.appendChild( left );
  //Second leaf.
  auto leftRightLeft = tree.appendChild( leftRight );
  leftRightLeft.element.fixState( Nucleotide.ADENINE );
  //Third leaf.
  auto leftRightRight = tree.appendChild( leftRight );
  leftRightRight.element.fixState( Nucleotide.CYTOSINE );
  
  //Right subtree.
  auto right = tree.appendChild( root );
  //Fourth leaf.
  auto rightLeft = tree.appendChild( right );
  rightLeft.element.fixState( Nucleotide.THYMINE );
  auto rightRight = tree.appendChild( right );
  //Fifth leaf.
  auto rightRightLeft = tree.appendChild( rightRight );
  rightRightLeft.element.fixState( Nucleotide.GUANINE );
  //Sixth leaf.
  auto rightRightRight = tree.appendChild( rightRight );
  rightRightRight.element.fixState( Nucleotide.ADENINE );
  
  auto validStates = [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE ];
  
  tree.update(
    validStates,
    ( Nucleotide n1, Nucleotide n2 ){ 
      if( n1 == n2 ) {
        return 0;
      }
      return 1;
    }
  );
  
  //Here we go.
  //Starting with the leaves, from left to right.
  //First leaf.
  assert( leftLeft.element.cost( Nucleotide.ADENINE )  == Cost.max );
  assert( leftLeft.element.cost( Nucleotide.CYTOSINE ) == 0 );
  assert( leftLeft.element.cost( Nucleotide.GUANINE )  == Cost.max );
  assert( leftLeft.element.cost( Nucleotide.THYMINE )  == Cost.max );
  assert( leftLeft.element.count( Nucleotide.ADENINE )  == 0 );
  assert( leftLeft.element.count( Nucleotide.CYTOSINE ) == 1 );
  assert( leftLeft.element.count( Nucleotide.GUANINE )  == 0 );
  assert( leftLeft.element.count( Nucleotide.THYMINE )  == 0 );
  
  //Second leaf.
  assert( leftRightLeft.element.cost( Nucleotide.ADENINE )  == 0 );
  assert( leftRightLeft.element.cost( Nucleotide.CYTOSINE ) == Cost.max );
  assert( leftRightLeft.element.cost( Nucleotide.GUANINE )  == Cost.max );
  assert( leftRightLeft.element.cost( Nucleotide.THYMINE )  == Cost.max );
  assert( leftRightLeft.element.count( Nucleotide.ADENINE )  == 1 );
  assert( leftRightLeft.element.count( Nucleotide.CYTOSINE ) == 0 );
  assert( leftRightLeft.element.count( Nucleotide.GUANINE )  == 0 );
  assert( leftRightLeft.element.count( Nucleotide.THYMINE )  == 0 );
  
  //Third leaf.
  assert( leftRightRight.element.cost( Nucleotide.ADENINE )  == Cost.max );
  assert( leftRightRight.element.cost( Nucleotide.CYTOSINE ) == 0 );
  assert( leftRightRight.element.cost( Nucleotide.GUANINE )  == Cost.max );
  assert( leftRightRight.element.cost( Nucleotide.THYMINE )  == Cost.max );
  assert( leftRightRight.element.count( Nucleotide.ADENINE )  == 0 );
  assert( leftRightRight.element.count( Nucleotide.CYTOSINE ) == 1 );
  assert( leftRightRight.element.count( Nucleotide.GUANINE )  == 0 );
  assert( leftRightRight.element.count( Nucleotide.THYMINE )  == 0 );
  
  //Fourth leaf.
  assert( rightLeft.element.cost( Nucleotide.ADENINE )  == Cost.max );
  assert( rightLeft.element.cost( Nucleotide.CYTOSINE ) == Cost.max );
  assert( rightLeft.element.cost( Nucleotide.GUANINE )  == Cost.max );
  assert( rightLeft.element.cost( Nucleotide.THYMINE )  == 0 );
  assert( rightLeft.element.count( Nucleotide.ADENINE )  == 0 );
  assert( rightLeft.element.count( Nucleotide.CYTOSINE ) == 0 );
  assert( rightLeft.element.count( Nucleotide.GUANINE )  == 0 );
  assert( rightLeft.element.count( Nucleotide.THYMINE )  == 1 );
  
  //Fifth leaf.
  assert( rightRightLeft.element.cost( Nucleotide.ADENINE )  == Cost.max );
  assert( rightRightLeft.element.cost( Nucleotide.CYTOSINE ) == Cost.max );
  assert( rightRightLeft.element.cost( Nucleotide.GUANINE )  == 0 );
  assert( rightRightLeft.element.cost( Nucleotide.THYMINE )  == Cost.max );
  assert( rightRightLeft.element.count( Nucleotide.ADENINE )  == 0 );
  assert( rightRightLeft.element.count( Nucleotide.CYTOSINE ) == 0 );
  assert( rightRightLeft.element.count( Nucleotide.GUANINE )  == 1 );
  assert( rightRightLeft.element.count( Nucleotide.THYMINE )  == 0 );
  
  //Sixth leaf.
  assert( rightRightRight.element.cost( Nucleotide.ADENINE )  == 0 );
  assert( rightRightRight.element.cost( Nucleotide.CYTOSINE ) == Cost.max );
  assert( rightRightRight.element.cost( Nucleotide.GUANINE )  == Cost.max );
  assert( rightRightRight.element.cost( Nucleotide.THYMINE )  == Cost.max );
  assert( rightRightRight.element.count( Nucleotide.ADENINE )  == 1 );
  assert( rightRightRight.element.count( Nucleotide.CYTOSINE ) == 0 );
  assert( rightRightRight.element.count( Nucleotide.GUANINE )  == 0 );
  assert( rightRightRight.element.count( Nucleotide.THYMINE )  == 0 );
  
  //Third level nodes.
  assert( leftRight.element.cost( Nucleotide.ADENINE )  == 1 );
  assert( leftRight.element.cost( Nucleotide.CYTOSINE ) == 1 );
  assert( leftRight.element.cost( Nucleotide.GUANINE )  == 2 );
  assert( leftRight.element.cost( Nucleotide.THYMINE )  == 2 );
  assert( leftRight.element.count( Nucleotide.ADENINE )  == 1 );
  assert( leftRight.element.count( Nucleotide.CYTOSINE ) == 1 );
  assert( leftRight.element.count( Nucleotide.GUANINE )  == 1 );
  assert( leftRight.element.count( Nucleotide.THYMINE )  == 1 );
  
  assert( rightRight.element.cost( Nucleotide.ADENINE )  == 1 );
  assert( rightRight.element.cost( Nucleotide.CYTOSINE ) == 2 );
  assert( rightRight.element.cost( Nucleotide.GUANINE )  == 1 );
  assert( rightRight.element.cost( Nucleotide.THYMINE )  == 2 );
  assert( rightRight.element.count( Nucleotide.ADENINE )  == 1 );
  assert( rightRight.element.count( Nucleotide.CYTOSINE ) == 1 );
  assert( rightRight.element.count( Nucleotide.GUANINE )  == 1 );
  assert( rightRight.element.count( Nucleotide.THYMINE )  == 1 );
  
  //Second level nodes.
  assert( left.element.cost( Nucleotide.ADENINE )  == 2 );
  assert( left.element.cost( Nucleotide.CYTOSINE ) == 1 );
  assert( left.element.cost( Nucleotide.GUANINE )  == 3 );
  assert( left.element.cost( Nucleotide.THYMINE )  == 3 );
  assert( left.element.count( Nucleotide.ADENINE )  == 1 );
  assert( left.element.count( Nucleotide.CYTOSINE ) == 1 );
  assert( left.element.count( Nucleotide.GUANINE )  == 3 );
  assert( left.element.count( Nucleotide.THYMINE )  == 3 );
  
  assert( right.element.cost( Nucleotide.ADENINE )  == 2 );
  assert( right.element.cost( Nucleotide.CYTOSINE ) == 3 );
  assert( right.element.cost( Nucleotide.GUANINE )  == 2 );
  assert( right.element.cost( Nucleotide.THYMINE )  == 2 );
  assert( right.element.count( Nucleotide.ADENINE )  == 1 );
  assert( right.element.count( Nucleotide.CYTOSINE ) == 3 );
  assert( right.element.count( Nucleotide.GUANINE )  == 1 );
  assert( right.element.count( Nucleotide.THYMINE )  == 3 );
  
  //Root.
  assert( root.element.cost( Nucleotide.ADENINE )  == 4 );
  assert( root.element.cost( Nucleotide.CYTOSINE ) == 4 );
  assert( root.element.cost( Nucleotide.GUANINE )  == 4 );
  assert( root.element.cost( Nucleotide.THYMINE )  == 4 );
  assert( root.element.count( Nucleotide.ADENINE )  == 2 );
  assert( root.element.count( Nucleotide.CYTOSINE ) == 8 );
  assert( root.element.count( Nucleotide.GUANINE )  == 1 );
  assert( root.element.count( Nucleotide.THYMINE )  == 3 );
 
}