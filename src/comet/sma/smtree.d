/**
  The states mutations tree.
  This is a tree like container based to evaluate the minimum state mutations cost based
  on Sankoff's algorithm.
*/
module comet.sma.smtree;

public import comet.sma.mutation_cost;

import comet.containers.tree;

import std.algorithm;
import std.range: isInputRange, ElementType, hasLength;

import std.conv: to;


/**
  This structure is nothing more than an entity responsible for holding
  the state tuples of every known state of its embedding node. 
*/
struct StatesInfo( T ) {

  //private StateInfo[ T ] _infos; //Each state is associated with a tuple of data.
  private StateTuple[] _infos;
  
  /**
    Creates an entry for every given state provided by the range and initializes
    their cost with the provided value.
  */
  this( Range )( Range states ) if( isInputRange!Range && is( ElementType!Range == T ) && hasLength!Range ) in {
  
    assert( states.length );
  
  } body {
  
    _infos = new StateTuple[ states.length ];
  
    for( int i = 0; i < states.length; ++i ) {
    
      _infos[ i ] = StateTuple( states[ i ], 0, Cost.max );
    
    }
  
  }
  
public:
  
  alias StateTuple = std.typecons.Tuple!( T, "state", size_t, "count", Cost, "cost" );
  
  /**
    Indicates that the given states are known to be present, therefore
    favoring it when considering every possible states.
    Sets the state's cost to 0 and every other costs to the maximum value.
  */  
  void fixStates( R )( R range ) if( isInputRange!R ) in {
  
    assert( _infos.length );
  
  } body {
  
    //Reset other states to the maximum cost
    //and remove their occurrences count.
    foreach( ref t; _infos ) {
    
      //O(n^2) algorithm but small values of n are expected.
      import std.algorithm: canFind;      
      if( range.canFind( t.state ) ) {
      
        t.count = 1;
        t.cost = 0.;
      
      } else {
      
        t.count = 0;
        t.cost = Cost.max;
      
      }    
      
    }
  
  }  
  /**
    Overload for single state, was used before the support of the more general solution, which is to support
    sets of initial states. It's mostly useful now to support the unit tests, which are still very relevant.
  **/  
  void fixStates( T state ) {

    immutable T[ 1 ] artificialRange = [ state ];
    fixStates( artificialRange[] );  
        
  }
 
  auto opSlice() { return _infos[]; }
  
  /**
    Finds the lowest cost amongst the ones held.
  */
  @property Cost minCost() {
    
    auto min = Cost.max;
    
    foreach( tup; _infos[] ) {
    
      if( tup.cost < min ) { min = tup.cost; }
      
    }
    
    return min;
    
  }   
  
  typeof(this) clone() {
    auto copy = StatesInfo!T();
    copy._infos = this._infos.dup;  
    return copy;
  }
  
}

unittest {  

  import comet.bio.dna;
  
  
  import std.traits: EnumMembers;
  
  Nucleotide[] nucleotides = [ EnumMembers!Nucleotide ];
  auto sc = StatesInfo!( Nucleotide )( nucleotides[] );
  
  auto counter = 0;
  foreach( ref t; sc[] ) {
  
    t.cost = counter;
    t.count = counter * 2;
    ++counter;
    
  }
  
  counter = 0;
  foreach( t; sc[] ) {
  
    assert( t.cost == counter );
    assert( t.count == counter * 2 );
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
  T[] _states;

  
  //Expects the leaves to be set.
  private void gatherInfo(Range, U )( typeof(_tree.root()) node, Range states, U mutationCosts ) {   
  
    //Do nothing if it is a leaf.
    if( !node.hasChildren() ) { return; }
    
    foreach( children; node.children ) {
    
      gatherInfo( children, states, mutationCosts );
      
    }
    
    foreach( ref t; node.element[] ) {
    
      auto state = t.state;
      Cost costSum = 0;
    
      //Reconstruction counts.
      size_t rCount = 1;
      
      foreach( children; node.children ) {
      
        //Find the minimal cost of a mutation.
        auto minCost = minMutationCost( state, children.element, mutationCosts );
        
        assert( minCost < Cost.max );
        
        costSum += minCost;
        
        //Count the number of mutations of minimal cost.
        size_t minCostMutations = 0;        
        foreach( ct; children.element[] ) {
        
          auto childState = ct.state;
          
          if( ct.cost + mutationCosts.costFor( state, childState ) == minCost ) {
          
            minCostMutations += ct.count;
            
          }
          
        }
        
        assert( 0 < minCostMutations );
        
        rCount *= minCostMutations;
        
      }
      
      t.cost = costSum;
      t.count = rCount;
      
    }
    
  }
    
public:
  
  this( R )( R states ) {
  
    //Make an internal copy of the available states.
    _states = new T[ states.length ];    
    for( int i = 0; i < states.length; ++i ) {
    
      _states[ i ] = states[ i ];
    
    }
  
  }
  
  auto setRoot() in {
  
    assert( _states.length );
  
  } body {
  
    auto node = _tree.setRoot();
    node.element = StatesInfo!T( _states[] );
    return node;
  
  } 
  
  auto appendChild( typeof( _tree ).Node * node ) in {
  
    assert( _states.length );
  
  } body {

    return _tree.appendChild( node, StatesInfo!T( _states[] ) );
  
  }
  
  auto opDispatch( string method, T... )( T args ) {
  
    return mixin( "_tree." ~ method )( args );
  
  }
    
  /**
    Sets the leaves of the state mutation tree using the provided values. The leaves are set according
    to the "leaves" range from the tree structure which, as of right now, reads leaves from "left" to "right"
    (left being the first child in insertion order and right being the last). 
    
    The "left" half of the tree should hold the values (read nucleotides if working with dna) of one homologous sequence, 
    whereas the opposite half is a mirror image containing the values of the other sequence.
  */
  //TODO for speedups: instead of traversing the leaves everytime, just hold pointers to them and set them directly.
  void setLeaves( Range )( Range leaves ) if( isInputRange!Range ) {
    
    foreach( ref smLeaf; this.leaves ) {
      assert( !leaves.empty );
      smLeaf.element.fixStates( leaves.front() );  
      leaves.popFront();
    }       
    
  }
  
  /**
    Updates the tree given the mutation costs
    provider.
    
    This method is only to be used once the leaves have been set
    to a given state.
  */
  void update( U )( U mutationCosts ) if( isMutationCost!U ) in {
  
    assert( !_tree.empty );    
  
  } body {
        
    gatherInfo( _tree.root, _states[], mutationCosts );
    
  }  
  
}

unittest {

  import comet.bio.dna;
  
  auto validStates = [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE ];
  
  auto tree = SMTree!( Nucleotide )( validStates[] );
  tree.clear();
  
  //First level.
  auto root = tree.setRoot();  
  
  //Second level.
  auto left = tree.appendChild( root );
  auto right = tree.appendChild( root );
  
  //Third level.
  auto leftLeft = tree.appendChild( left );
  //Third leaf.
  auto leftRight = tree.appendChild( left );
  leftRight.element.fixStates( Nucleotide.CYTOSINE );
  auto rightLeft = tree.appendChild( right );
  //Sixth leaf.
  auto rightRight = tree.appendChild( right );
  rightRight.element.fixStates( Nucleotide.CYTOSINE );
    
  //Fourth level.
  //First leaf.
  auto leftLeftLeft = tree.appendChild( leftLeft );
  leftLeftLeft.element.fixStates( Nucleotide.ADENINE );
  //Second leaf.
  auto leftLeftRight = tree.appendChild( leftLeft );
  leftLeftRight.element.fixStates( Nucleotide.GUANINE );
  //Fourth leaf.
  auto rightLeftLeft = tree.appendChild( rightLeft );
  rightLeftLeft.element.fixStates( Nucleotide.THYMINE );
  //Fifth leaf.
  auto rightLeftRight = tree.appendChild( rightLeft );
  rightLeftRight.element.fixStates( Nucleotide.ADENINE );
   
  tree.update( 
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

private auto costOf( T )( StatesInfo!T self, T state ) {
  
  foreach( tup; self[] ) {
  
    if( tup.state == state ) { 
      return tup.cost; 
    } 
    
  }
  assert( false );

}
  
private auto countOf( T )( StatesInfo!T self, T state ) {

  foreach( tup; self[] ) {
  
    if( tup.state == state ) { return tup.count; }
    
  }
  assert( false );

}

//Redo with a known special case.
//cactga
unittest {
  import comet.bio.dna;

  auto validStates = [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE ];
  auto tree = SMTree!Nucleotide( validStates[] );
  
  tree.clear();
  auto root = tree.setRoot();
  
  //Left subtree.
  auto left = tree.appendChild( root );  
  //First leaf.
  auto leftLeft = tree.appendChild( left );
  leftLeft.element.fixStates( Nucleotide.CYTOSINE );
  auto leftRight = tree.appendChild( left );
  //Second leaf.
  auto leftRightLeft = tree.appendChild( leftRight );
  leftRightLeft.element.fixStates( Nucleotide.ADENINE );
  //Third leaf.
  auto leftRightRight = tree.appendChild( leftRight );
  leftRightRight.element.fixStates( Nucleotide.CYTOSINE );
  
  //Right subtree.
  auto right = tree.appendChild( root );
  //Fourth leaf.
  auto rightLeft = tree.appendChild( right );
  rightLeft.element.fixStates( Nucleotide.THYMINE );
  auto rightRight = tree.appendChild( right );
  //Fifth leaf.
  auto rightRightLeft = tree.appendChild( rightRight );
  rightRightLeft.element.fixStates( Nucleotide.GUANINE );
  //Sixth leaf.
  auto rightRightRight = tree.appendChild( rightRight );
  rightRightRight.element.fixStates( Nucleotide.ADENINE );
  
  
  
  tree.update(
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