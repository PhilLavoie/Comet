/**
  Module responsible for everything regarding the calculation of duplications cost.
  It acts as the "inner loop" of the main program.
*/
module comet.dup;

import comet.sma;
import comet.config;
import comet.pattern;

import deimos.bio.dna;
import deimos.containers.tree;

import std.stdio;
import std.container;
import std.algorithm;

//TODO: find a better name.
struct SequenceLeaves {
private:
  Sequence[] _sequences;
  size_t _seqIndex;
  size_t _maxIndex; //inclusive.
  
  size_t _currentPos;  
  size_t _period;

  public:
  this( Sequence[] seqs, size_t current, size_t period ) {
    _sequences = seqs;
    _seqIndex = 0;
    _maxIndex = 2 * seqs.length - 1;
    _currentPos = current;    
    _period = period;
    
  }

  @property auto front() {
    auto firstPass = _seqIndex < _sequences.length;
    if( firstPass ) {
      return _sequences[ _seqIndex ][ _currentPos ];
    }
    return _sequences[ _seqIndex - _sequences.length ][ _currentPos + _period ];
  }
  
  @property bool empty() {
    return _maxIndex < _seqIndex;
  }
  
  void popFront() {
    ++_seqIndex;
  } 
  
  @property size_t length() { return _sequences.length * 2; }

}

//Entry point.
auto calculateDuplicationsCosts( Seq )( Seq[] sequences, ref Config cfg ) {  
  size_t seqsCount = sequences.length;
  size_t seqLength = sequences[ 0 ].length;
  size_t midPosition = seqLength / 2;
  //Up to now, only nucleotides are supported.
  Nucleotide[] states = [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE ];  
  //Basic 0, 1 cost table.
  auto mutationCosts = ( Nucleotide initial, Nucleotide mutated ) { 
    if( initial != mutated ) { return 1; }
    return 0;
  };
  
  //Phylogenize the tree according to the sequences, see documentation to see
  //how it is done.
  
  //TODO: remove the phylogeny, just create it in the smtree directly instead.
  Tree!( Sequence ) phylogeny;
  phylogeny.phylogenize( sequences );  
  
  SMTree!Nucleotide smTree;
  smTree.mimic( phylogeny );
  auto results = Results( cfg.noResults );
  Cost[ Pattern ] patternsCost;
  Cost delegate( size_t, size_t ) algo;
  
  if( cfg.usePatterns ) {
    algo = ( size_t pos, size_t period ) {
      auto seqLeaves = SequenceLeaves( sequences, pos, period );
      auto pattern = Pattern( seqLeaves ); //Extract the leaf nucleotides, but first create a range that extracts the nucleotides.
      if( pattern in patternsCost ) {
        return patternsCost[ pattern ];
      } 
      //Start by extracting the states from the hierarchy: use them to set the
      //the leaves of the smtree.
      setLeaves( smTree, seqLeaves );
      
      //Process the state mutation algorithm then extrac the preSpeciation cost.
      smTree.update( states, mutationCosts );
      auto preSpecCost = preSpeciationCost( smTree, mutationCosts );
      patternsCost[ pattern ] = preSpecCost;
      return preSpecCost;    
    };
  } else {
    algo = ( size_t pos, size_t period ) {
      //Start by extracting the states from the hierarchy: use them to set the
      //the leaves of the smtree.
      setLeaves( smTree, SequenceLeaves( sequences, pos, period ) );
      
      //Process the state mutation algorithm then extrac the preSpeciation cost.
      smTree.update( states, mutationCosts );
      return preSpeciationCost( smTree, mutationCosts );
    };
  }
  
  //Main loop of the program.
  //For each period length, evaluate de duplication cost of every possible positions.
  foreach( 
    dup; 
    Duplications( 
      cfg.minPeriod, 
      cfg.maxPeriod, 
      cfg.periodStep, 
      seqLength,
      ( size_t period ){ if( 1 <= cfg.verbosity ) { writeln( "Doing period: ", period ); } } 
    )
  ) {
    foreach( current; dup.positions ) {      
        dup.cost += algo( current, dup.period );     
    }
    dup.cost /= dup.period;
    
    if( 0 < cfg.noResults ){ results.add( dup ); }
  }
    
  return results[];
}

/**
  A wrapper around a fast, ordered index (as of right now, the structure used is a red black tree).
  It keeps track of how many results were inserted so that it does not go beyond a maximum limit.
  When the limit is reached, if the new result to be inserted is better than the worse one held,
  then the latter is popped from the tree and the former is inserted, maintaining the number of
  results below the limit.
*/
struct Results {
  private RedBlackTree!( Duplication ) _results;
  private size_t _max;
  private size_t _noResults;
  
  this( size_t maxResults ) {
    _results = new typeof( _results )();
    _noResults = 0;
    _max = maxResults;
  }
  
  void add( Duplication result ) {
    //Store result.
    if( _noResults < _max ) {
      _results.insert( result );
      ++_noResults;
    //If we reached the maximum number of results, then we determine
    //if the current duplication result is better than the worst already known.
    //If so, we get rid of the worst and insert the better one.
    } else if( result < _results.back() ){
      _results.removeBack();
      _results.insert( result );
    }
  }

  /**
    Returns a range of results in ascending order (the "lowest" result is actually the best).
  */
  auto opSlice() {
    return _results[];
  }  
}

     

/**
  The first sequences read are "older" (higher, in terms of levels, in the phylogeny).
  Every phylogeny node has either 2 children or is a leaf. 
  If there are 2 sequences, sequence 1 and sequence 2 share the same ancestors. If there
  are 3 sequences, sequence 2 and sequence 3 share a common ancestor. This ancestor shares
  a common ancestor with sequence 1. If there is 4 sequences, the same logic goes on.
  
  Ex: 3 sequences
  
                    root
                    |
        -------------------------
        |                       |
        node                    node
        |                       |
    ---------               ---------
    |       |               |       |
    seq1    node            seq1    node
            |                       |
        ---------               ---------
        |       |               |       |
        seq2    seq3            seq2    seq3
        
  The left subtree (from the root) represents the start of the duplication, whereas the right subtree represent the duplicated areas.
*/
void phylogenize( Tree )( ref Tree tree, Sequence[] sequences ) in {
  
} out {
  assert( count( tree.leaves ) == 2 * sequences.length );
} body {
  auto seqsCount = sequences.length;
  auto seqLength = sequences[ 0 ].length;
  
  tree.clear();
  
  auto root = tree.setRoot( null );
  
  auto leftCurrent = tree.appendChild( root, null );
  auto rightCurrent = tree.appendChild( root, null );
  
  size_t seqIndex = 0;
  foreach( s; sequences ) {
    tree.appendChild( leftCurrent, s );
    tree.appendChild( rightCurrent, s );
    
    //If we have more than one sequence left, we have to create
    //at least an additional branch.
    if( 2 < ( seqsCount - seqIndex ) ) {
      leftCurrent = tree.appendChild( leftCurrent, null );
      rightCurrent = tree.appendChild( rightCurrent, null );
    }
  
    ++seqIndex;
  }  
}

/**
  Sets the leaves of the state mutation tree using the provided sequences. The leaves are set according
  to the "leaves" range from the tree structure which, as of right now, reads leaves from "left" to "right"
  (left being the first child in insertion order and right being the last). The "left" half of the tree holds
  the values (read nucleotides if working with dna) of one homologous sequence, whereas the opposite half is a mirror
  image containg the values of the other sequence.
*/
void setLeaves( Tree, Range )( ref Tree smTree, Range sequences ) {
  //Of course, we expect both trees to have the exact same layout and therefore 
  //that the leaves iterator return the same number of leaves and in the same order.
  foreach( ref smLeaf; smTree.leaves ) {
    assert( !sequences.empty );
    smLeaf.element.fixState( sequences.front() );  
    sequences.popFront();
  }    
}


Cost preSpeciationCost( Tree, U )( Tree smTree, U mutationCosts ) {
  //The pre speciation cost is associated with the number of mutations
  //from the root to its children, accounting for every possible reconstructions.
  //That value is then averaged by the number of possible reconstructions.
  size_t noRecons = 0;
  Cost costSum = 0.0;
  
  //Extract the candidates that have the minimum cost.
  auto root = smTree.root;
  auto minCost = root.element.minCost;
  foreach( rootState, ref StateInfo rootInfo; root.element ) {
    //It is a candidate if its cost is the minimum.
    //For each candidates, we accumulate their number of occurrences and calculate
    //the total cost of pre speciation mutations.
    if( minCost == rootInfo.cost ) {
      noRecons += rootInfo.count;
      
      foreach( child; root.children ) {
        //We need to extract the number of equivalent sub choices from each children.      
        size_t equivalentsCount = 0;
        auto minMutCost = minMutationCost( rootState, child.element, mutationCosts );
        foreach( childState, ref StateInfo childInfo; child.element ) {
          if( mutationCost( childInfo.cost, rootState, childState, mutationCosts ) == minMutCost ) {
            equivalentsCount += childInfo.count;
          }
        }       
        assert( 0 < equivalentsCount );
        assert( rootInfo.count % equivalentsCount == 0 );
        size_t multiplier = rootInfo.count / equivalentsCount;      
        assert( 0 < multiplier );
      
        foreach( childState, ref StateInfo childInfo; child.element ) {
          if( mutationCost( childInfo.cost, rootState, childState, mutationCosts ) == minMutCost ) {
            costSum += mutationCosts( rootState, childState ) * childInfo.count * multiplier;
          }
        }       
      }    
    }
  }
  
  assert( 0 < noRecons );
  return costSum / noRecons;
}

//Known special case.
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
  auto mutationCosts = 
    ( Nucleotide n1, Nucleotide n2 ){ 
      if( n1 == n2 ) {
        return 0;
      }
      return 1;
    };

  tree.update(
    validStates,
    mutationCosts
  );
   
  auto zeCost = preSpeciationCost( tree, mutationCosts );
  auto zeExpected = cast( Cost )10 / 14;
  assert( zeExpected - Cost.epsilon <= zeCost && zeCost <= zeExpected + Cost.epsilon );
}

/**
  A range iterating over every valid duplication given the parameters.
*/
struct Duplications {
  private static const size_t START_POS = 0;

  private size_t _currentPos;
  private size_t _maxPos;         //Inclusive.
  private size_t _currentPeriod;
  private size_t _maxPeriod;      //Inclusive.
  private size_t _periodStep;
  private size_t _seqLength;
  private void delegate( size_t ) _onPeriodChange;

  this( size_t minPeriod, size_t maxPeriod, size_t periodStep, size_t seqLength, typeof( _onPeriodChange ) onPeriodChange ) in {
    assert( 0 < minPeriod );
    assert( 0 < periodStep );
    assert( 0 < seqLength );    
    assert( minPeriod <= maxPeriod );
    assert( minPeriod % periodStep == 0 );
  } body {
    _currentPeriod = minPeriod;
    _maxPeriod = min( seqLength / 2, maxPeriod );
    _periodStep = periodStep;
    _seqLength = seqLength;
    _currentPos = START_POS;
    _onPeriodChange = onPeriodChange;
    adjustMaxPos();
    _onPeriodChange( _currentPeriod );
  }
  
  private void adjustMaxPos() {
    _maxPos = _seqLength - ( 2 * _currentPeriod ) - 1;
  }
  
  private void nextPeriod() {
    _currentPeriod += _periodStep;
    _currentPos = START_POS;
    adjustMaxPos();
    _onPeriodChange( _currentPeriod );
  }
  
  @property Duplication front() {
    return Duplication( _currentPos, _currentPeriod, 0.0 );
  }
  @property bool empty() { 
    return _maxPeriod < _currentPeriod;
  }
  void popFront() {
    if( _maxPos < _currentPos ) {
      nextPeriod();
    } else {
      ++_currentPos;
    }
  }

}

/**
  This structure holds summary information regarding a duplication. It holds its start position and the length
  of its period, idenfying it in a unique manner. The data also holds the cost of the duplication as provided by
  the user.
  
  A duplication can also offer a range iterating over every "inner" posisions of the duplication. For example,
  a duplication starting on index 50 and having a period of 10 will return a range iterating over these values:
  [ 50, 51, 52, 53, 54, 55, 56, 57, 58, 59 ] 
  Which are the indexes forming the lefthand homologous. In fact, the whole duplication (containing both homologous)
  is formed of indexes 50 through 69 inclusively. The user has to keep that in mind when using the range.
  
  Lastly, the comparison operator is overridden to order duplications according to their cost first. If two
  duplications have the same cost then the one with the longer period is considered "lower", where lower
  means better. If both values are equal, then it is ordered arbitrarily on the start position, where
  the lowest position comes first.
*/
struct Duplication {
  private size_t _start;
  private size_t _period;
  
  Cost cost = 0;
  
  this( size_t start, size_t period, Cost cost = 0.0 ) in {
    assert( 0 < period ); //This can help if the order of the parameters is incorrect.
  } body {
    _start = start;
    _period = period;
    this.cost = cost;
  }
  
  @property size_t start() { return _start; }
  @property size_t period() { return _period; }
  @property auto positions() {
    return Positions( this.start, this.start + this.period - 1 );
  }
  
  /**
  
  */
  int opCmp( Duplication rhs ) {
    if( cost < rhs.cost ) { 
      return -1; 
    } else if( rhs.cost < cost ) {
      return 1;
    }
    //If the cost is equals, then the longer period wins.
    auto cmp = rhs.period - period;
    if( cmp ) { return cmp; }
    //Arbitrary ordering otherwise.
    return start - rhs.start;
  }  
}

/**
  A range iterating over duplication positions.
*/
struct Positions {
  private size_t _current;
  private size_t _stop;   //Inclusive.
  
  /**
    The stop boundary is inclusive.
  */
  this( size_t start, size_t stop ) {
    _current = start;
    _stop = stop;
  }
  
  @property size_t front() {
    return _current;
  }
  
  void popFront() {
    ++_current;
  }
  
  @property bool empty() {
    return _stop < _current;
  }
}

unittest {
  Duplication d1, d2;
  d1._start = 0;
  d1._period = 100;
  d1.cost = 20.0;
  d2._start = 10;
  d2._period = 20;
  d2.cost = 21.0;
  
  //Cost based ordering.
  assert( d1 < d2 );
  d1.cost = d2.cost + 1;
  assert( d2 < d1 );
  
  //Period ordering.
  d2.cost = d1.cost;
  assert( d1 < d2 );
  d2._period = d1._period + 1;
  assert( d2 < d1 );
  
  //Start index ordering.
  d2.cost = d1.cost;
  d2._period = d1._period;
  assert( d1 < d2 );
  d1._start = d2._start + 1;
  assert( d2 < d1 );
  
  //Equality.
  d1 = d2;
  assert( d1 == d2 );
}

