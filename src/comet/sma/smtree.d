/**
  The states mutations tree.
  This is a tree like container based to evaluate the minimum state mutations cost based
  on Sankoff's algorithm.
*/
module comet.sma.smtree;

public import comet.sma.mutation_cost;

import deimos.containers.tree;

import std.algorithm;
import std.range: isInputRange, ElementType;


/**
  This structure is nothing more than an entity responsible for holding
  the state tuples of every known state of its embedding node. 
*/
struct StatesInfo( T ) {

  /**
    Structure holding the local cost and a the number of occurrences
    (tree labelings) in which the associated state is chosen in its node.
    
    Those fields represent the values for the subtree under the node holding the state. 
    Therefore, if the node is the root, then the values
    held are the absolute ones. 
    
    For any other node, the absolute numbers has to be recalculated based on
    its parent node and the equivalent states that can
    be chosen as minimal mutation cost candidates.
    
    The default value holds the minimal number of occurrences and the maximum possible cost.
  */
  private static struct StateInfo {

    size_t count = 0;
    Cost cost = Cost.max;
    
  }


  private StateInfo[ T ] _infos; //Each state is associated with a tuple of data.
  
  /**
    Creates an entry for every given state provided by the range and initializes
    their cost with the provided value.
  */
  this( Range )( Range states, Cost initialCost = 0 ) if( isInputRange!Range && is( ElementType!Range == T ) ) {
  
    foreach( s; states ) {
    
      _infos[ s ] = StateInfo( 0, initialCost );
      
    }
    
  }
  
public:
  
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
  
  /**
    Returns the cost of the given state.
  */
  ref Cost costOf( T state ) {
  
    if( state !in _infos ) {
    
      _infos[ state ] = StateInfo.init;
      
    }
    
    return _infos[ state ].cost;
  }
  
  /**
    Returns the count of the given state.
  */
  ref size_t countOf( T state ) {
    if( state !in _infos ) {
      _infos[ state ] = StateInfo.init;
    }
    return _infos[ state ].count;
  }
  
  /**
    Finds the lowest cost amongst the ones held.
  */
  @property Cost minCost() {
    
    auto min = Cost.max;
    
    foreach( s, info; _infos ) {
    
      if( info.cost < min ) { min = info.cost; }
      
    }
    
    return min;
  }
    
  alias StateTuple = std.typecons.Tuple!( T, "state", size_t, "count", Cost, "cost" );
    
  /**
    Foreach function delegates.
  */
  int opApply( int delegate( ref StateTuple ) dg ) {
  
    int result = 0;
    
    foreach( s, info; _infos ) {
      
      StateTuple st;
      st.state = s;
      st.count = info.count;
      st.cost = info.cost;
      
      result = dg( st );
      
      if( result ) { break; }
    
    }
    
    return result;
  
  }
  
}

unittest {  

  import deimos.bio.dna;
  auto sc = StatesInfo!( Nucleotide )();
  
  import std.traits: EnumMembers;
  
  Nucleotide[] nucleotides = [ EnumMembers!Nucleotide ];
  
  auto counter = 0;
  foreach( n; nucleotides ) {
  
    sc.costOf( n ) = counter;
    sc.countOf( n ) = counter * 2;
    ++counter;
    
  }
  
  counter = 0;
  foreach( n; nucleotides ) {
  
    assert( sc.costOf( n ) == counter );
    assert( sc.countOf( n ) == counter * 2 );
    ++counter;
    
  } 
  
}

/**
  Given a states information holder, returns the minimal possible cost of a mutation from
  a given state to any of the provided states. The local costs of the states held by the states
  information holder are taken into the calculation.
*/
Cost minMutationCost( T, U )( T initialState, StatesInfo!T si, U mutationCosts ) if( isMutationCost!U ) {
  
  auto min = Cost.max;
  
  //For every state tuple held by the holder.
  foreach( st; si ) {
  
    auto currCost = st.cost + mutationCosts.costFor( initialState, st.state  );
    if( currCost < min ) { min = currCost; }
    
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
        
        debug {
        
          assert( minCost < Cost.max );
          
        }
        
        costSum += minCost;
        
        size_t minCostMutations = 0;        
        foreach( st; children.element ) {
        
          auto childState = st.state;
          
          if( st.cost + mutationCosts.costFor( state, childState ) == minCost ) {
          
            minCostMutations += st.count;
            
          }
          
        }
        
        debug {
        
          assert( 0 < minCostMutations );
          
        }
        
        rCount *= minCostMutations;
        
      }
      
      node.element.costOf( state ) = costSum;
      node.element.countOf( state ) = rCount;
      
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
  assert( leftLeftLeft.element.costOf( Nucleotide.ADENINE )  == 0 );
  assert( leftLeftLeft.element.costOf( Nucleotide.CYTOSINE ) == Cost.max );
  assert( leftLeftLeft.element.costOf( Nucleotide.GUANINE )  == Cost.max );
  assert( leftLeftLeft.element.costOf( Nucleotide.THYMINE )  == Cost.max );
  
  //Second leaf: [ A: max, C: max, G: 0, T: max ]  
  assert( leftLeftRight.element.costOf( Nucleotide.ADENINE )  == Cost.max );
  assert( leftLeftRight.element.costOf( Nucleotide.CYTOSINE ) == Cost.max );
  assert( leftLeftRight.element.costOf( Nucleotide.GUANINE )  == 0 );
  assert( leftLeftRight.element.costOf( Nucleotide.THYMINE )  == Cost.max );
  
  //Third leaf: [ A: max, C: 0, G: max, T: max ]  
  assert( leftRight.element.costOf( Nucleotide.ADENINE )  == Cost.max );
  assert( leftRight.element.costOf( Nucleotide.CYTOSINE ) == 0 );
  assert( leftRight.element.costOf( Nucleotide.GUANINE )  == Cost.max );
  assert( leftRight.element.costOf( Nucleotide.THYMINE )  == Cost.max );
  
  //Fourth leaf: [ A: max, C: max, G: max, T: 0 ]  
  assert( rightLeftLeft.element.costOf( Nucleotide.ADENINE )  == Cost.max );
  assert( rightLeftLeft.element.costOf( Nucleotide.CYTOSINE ) == Cost.max );
  assert( rightLeftLeft.element.costOf( Nucleotide.GUANINE )  == Cost.max );
  assert( rightLeftLeft.element.costOf( Nucleotide.THYMINE )  == 0 );
  
  //Fifth leaf: [ A: 0, C: max, G: max, T: max ]  
  assert( rightLeftRight.element.costOf( Nucleotide.ADENINE )  == 0 );
  assert( rightLeftRight.element.costOf( Nucleotide.CYTOSINE ) == Cost.max );
  assert( rightLeftRight.element.costOf( Nucleotide.GUANINE )  == Cost.max );
  assert( rightLeftRight.element.costOf( Nucleotide.THYMINE )  == Cost.max );
  
  //Sixth leaf: [ A: max, C: 0, G: max, T: max ]  
  assert( rightRight.element.costOf( Nucleotide.ADENINE )  == Cost.max );
  assert( rightRight.element.costOf( Nucleotide.CYTOSINE ) == 0 );
  assert( rightRight.element.costOf( Nucleotide.GUANINE )  == Cost.max );
  assert( rightRight.element.costOf( Nucleotide.THYMINE )  == Cost.max );
    
  //Root: [ A: 4, C: 4, G: 5, T: 5 ]  
  assert( root.element.costOf( Nucleotide.ADENINE )  == 4 );
  assert( root.element.costOf( Nucleotide.CYTOSINE ) == 4 );
  assert( root.element.costOf( Nucleotide.GUANINE )  == 5 );
  assert( root.element.costOf( Nucleotide.THYMINE )  == 5 );
  assert( root.element.countOf( Nucleotide.ADENINE )  == 1 );
  assert( root.element.countOf( Nucleotide.CYTOSINE )  == 9 );
  assert( root.element.countOf( Nucleotide.GUANINE )  == 8 );
  assert( root.element.countOf( Nucleotide.THYMINE )  == 8 );
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
  assert( leftLeft.element.costOf( Nucleotide.ADENINE )  == Cost.max );
  assert( leftLeft.element.costOf( Nucleotide.CYTOSINE ) == 0 );
  assert( leftLeft.element.costOf( Nucleotide.GUANINE )  == Cost.max );
  assert( leftLeft.element.costOf( Nucleotide.THYMINE )  == Cost.max );
  assert( leftLeft.element.countOf( Nucleotide.ADENINE )  == 0 );
  assert( leftLeft.element.countOf( Nucleotide.CYTOSINE ) == 1 );
  assert( leftLeft.element.countOf( Nucleotide.GUANINE )  == 0 );
  assert( leftLeft.element.countOf( Nucleotide.THYMINE )  == 0 );
  
  //Second leaf.
  assert( leftRightLeft.element.costOf( Nucleotide.ADENINE )  == 0 );
  assert( leftRightLeft.element.costOf( Nucleotide.CYTOSINE ) == Cost.max );
  assert( leftRightLeft.element.costOf( Nucleotide.GUANINE )  == Cost.max );
  assert( leftRightLeft.element.costOf( Nucleotide.THYMINE )  == Cost.max );
  assert( leftRightLeft.element.countOf( Nucleotide.ADENINE )  == 1 );
  assert( leftRightLeft.element.countOf( Nucleotide.CYTOSINE ) == 0 );
  assert( leftRightLeft.element.countOf( Nucleotide.GUANINE )  == 0 );
  assert( leftRightLeft.element.countOf( Nucleotide.THYMINE )  == 0 );
  
  //Third leaf.
  assert( leftRightRight.element.costOf( Nucleotide.ADENINE )  == Cost.max );
  assert( leftRightRight.element.costOf( Nucleotide.CYTOSINE ) == 0 );
  assert( leftRightRight.element.costOf( Nucleotide.GUANINE )  == Cost.max );
  assert( leftRightRight.element.costOf( Nucleotide.THYMINE )  == Cost.max );
  assert( leftRightRight.element.countOf( Nucleotide.ADENINE )  == 0 );
  assert( leftRightRight.element.countOf( Nucleotide.CYTOSINE ) == 1 );
  assert( leftRightRight.element.countOf( Nucleotide.GUANINE )  == 0 );
  assert( leftRightRight.element.countOf( Nucleotide.THYMINE )  == 0 );
  
  //Fourth leaf.
  assert( rightLeft.element.costOf( Nucleotide.ADENINE )  == Cost.max );
  assert( rightLeft.element.costOf( Nucleotide.CYTOSINE ) == Cost.max );
  assert( rightLeft.element.costOf( Nucleotide.GUANINE )  == Cost.max );
  assert( rightLeft.element.costOf( Nucleotide.THYMINE )  == 0 );
  assert( rightLeft.element.countOf( Nucleotide.ADENINE )  == 0 );
  assert( rightLeft.element.countOf( Nucleotide.CYTOSINE ) == 0 );
  assert( rightLeft.element.countOf( Nucleotide.GUANINE )  == 0 );
  assert( rightLeft.element.countOf( Nucleotide.THYMINE )  == 1 );
  
  //Fifth leaf.
  assert( rightRightLeft.element.costOf( Nucleotide.ADENINE )  == Cost.max );
  assert( rightRightLeft.element.costOf( Nucleotide.CYTOSINE ) == Cost.max );
  assert( rightRightLeft.element.costOf( Nucleotide.GUANINE )  == 0 );
  assert( rightRightLeft.element.costOf( Nucleotide.THYMINE )  == Cost.max );
  assert( rightRightLeft.element.countOf( Nucleotide.ADENINE )  == 0 );
  assert( rightRightLeft.element.countOf( Nucleotide.CYTOSINE ) == 0 );
  assert( rightRightLeft.element.countOf( Nucleotide.GUANINE )  == 1 );
  assert( rightRightLeft.element.countOf( Nucleotide.THYMINE )  == 0 );
  
  //Sixth leaf.
  assert( rightRightRight.element.costOf( Nucleotide.ADENINE )  == 0 );
  assert( rightRightRight.element.costOf( Nucleotide.CYTOSINE ) == Cost.max );
  assert( rightRightRight.element.costOf( Nucleotide.GUANINE )  == Cost.max );
  assert( rightRightRight.element.costOf( Nucleotide.THYMINE )  == Cost.max );
  assert( rightRightRight.element.countOf( Nucleotide.ADENINE )  == 1 );
  assert( rightRightRight.element.countOf( Nucleotide.CYTOSINE ) == 0 );
  assert( rightRightRight.element.countOf( Nucleotide.GUANINE )  == 0 );
  assert( rightRightRight.element.countOf( Nucleotide.THYMINE )  == 0 );
  
  //Third level nodes.
  assert( leftRight.element.costOf( Nucleotide.ADENINE )  == 1 );
  assert( leftRight.element.costOf( Nucleotide.CYTOSINE ) == 1 );
  assert( leftRight.element.costOf( Nucleotide.GUANINE )  == 2 );
  assert( leftRight.element.costOf( Nucleotide.THYMINE )  == 2 );
  assert( leftRight.element.countOf( Nucleotide.ADENINE )  == 1 );
  assert( leftRight.element.countOf( Nucleotide.CYTOSINE ) == 1 );
  assert( leftRight.element.countOf( Nucleotide.GUANINE )  == 1 );
  assert( leftRight.element.countOf( Nucleotide.THYMINE )  == 1 );
  
  assert( rightRight.element.costOf( Nucleotide.ADENINE )  == 1 );
  assert( rightRight.element.costOf( Nucleotide.CYTOSINE ) == 2 );
  assert( rightRight.element.costOf( Nucleotide.GUANINE )  == 1 );
  assert( rightRight.element.costOf( Nucleotide.THYMINE )  == 2 );
  assert( rightRight.element.countOf( Nucleotide.ADENINE )  == 1 );
  assert( rightRight.element.countOf( Nucleotide.CYTOSINE ) == 1 );
  assert( rightRight.element.countOf( Nucleotide.GUANINE )  == 1 );
  assert( rightRight.element.countOf( Nucleotide.THYMINE )  == 1 );
  
  //Second level nodes.
  assert( left.element.costOf( Nucleotide.ADENINE )  == 2 );
  assert( left.element.costOf( Nucleotide.CYTOSINE ) == 1 );
  assert( left.element.costOf( Nucleotide.GUANINE )  == 3 );
  assert( left.element.costOf( Nucleotide.THYMINE )  == 3 );
  assert( left.element.countOf( Nucleotide.ADENINE )  == 1 );
  assert( left.element.countOf( Nucleotide.CYTOSINE ) == 1 );
  assert( left.element.countOf( Nucleotide.GUANINE )  == 3 );
  assert( left.element.countOf( Nucleotide.THYMINE )  == 3 );
  
  assert( right.element.costOf( Nucleotide.ADENINE )  == 2 );
  assert( right.element.costOf( Nucleotide.CYTOSINE ) == 3 );
  assert( right.element.costOf( Nucleotide.GUANINE )  == 2 );
  assert( right.element.costOf( Nucleotide.THYMINE )  == 2 );
  assert( right.element.countOf( Nucleotide.ADENINE )  == 1 );
  assert( right.element.countOf( Nucleotide.CYTOSINE ) == 3 );
  assert( right.element.countOf( Nucleotide.GUANINE )  == 1 );
  assert( right.element.countOf( Nucleotide.THYMINE )  == 3 );
  
  //Root.
  assert( root.element.costOf( Nucleotide.ADENINE )  == 4 );
  assert( root.element.costOf( Nucleotide.CYTOSINE ) == 4 );
  assert( root.element.costOf( Nucleotide.GUANINE )  == 4 );
  assert( root.element.costOf( Nucleotide.THYMINE )  == 4 );
  assert( root.element.countOf( Nucleotide.ADENINE )  == 2 );
  assert( root.element.countOf( Nucleotide.CYTOSINE ) == 8 );
  assert( root.element.countOf( Nucleotide.GUANINE )  == 1 );
  assert( root.element.countOf( Nucleotide.THYMINE )  == 3 );
 
}