/**
  Module encapsulating logic regarding the calculation of duplication cost.
  It provides an interface to the user in the form of algorithms. Algorithms
  all respond to a given interface and a factory method is provided to
  determine, according to program configuration, which algorithm is to be used.
*/
module comet.algos;

import deimos.bio.dna;

import comet.sma;
import comet.pattern;
import comet.config;
import comet.ranges;
public import comet.dup;

import std.algorithm;
import std.range;

/**
  This function constructs and returns an algorithm object based on the
  program configuration. 
*/
AlgoI algos( Range, U )( Range algos, Sequence[] sequences, Nucleotide[] states, U mutationCosts ) if( isForwardRange!Range ) {
  return algos.map!( 
    ( Algo algo ) {
      final switch( cfg.algo ) {
        case Algo.standard:
          return new Standard!U( sequences, states, mutationCosts );
          break;
        case Algo.cache:
          return new Cache!U( sequences, states, mutationCosts );
          break;
        case Algo.patterns:
          return new Patterns!U( sequences, states, mutationCosts );
          break;
        case Algo.cachePatterns:  
          return new CachePatterns!U( sequences, states, mutationCosts );
          break;
      }
      assert( false );  
    }
  );
}

/**
  Formal definition of the algorithms interface.
*/
interface AlgoI {
  void duplicationCost( ref Duplication );
}


class Standard( U ): AlgoI {
private:
  Sequence[] _sequences;
  Nucleotide[] _states;
  U _mutationCosts;
  SMTree!Nucleotide _smTree;
public:  
  this( typeof( _sequences ) seqs, typeof( _states ) states, typeof( _mutationCosts ) mutationCosts ) {
    _sequences = seqs;
    _states = states;
    _mutationCosts = mutationCosts;
   
    //Phylogenize the tree according to the sequences, see documentation to see
    //how it is done.  
    phylogenize( _smTree, _sequences );    
  }
  
  override void duplicationCost( ref Duplication dup ) {
    real sum = 0;
    foreach( current; dup.positions ) {      
        sum += positionCost( current, dup.period );     
    }
    dup.cost = sum / dup.period;
  }

  Cost positionCost( size_t pos, size_t period ) {
    //Start by extracting the states from the hierarchy: use them to set the
    //the leaves of the smtree.
    setLeaves( _smTree, SequenceLeaves( _sequences, pos, period ) );
    
    //Process the state mutation algorithm then extract the preSpeciation cost.
    _smTree.update( _states, _mutationCosts );
    return preSpeciationCost( _smTree, _mutationCosts );
  }
}

class Cache( U ): Standard!( U ) {
private:
  Cost[] _cache;
  real _costSum;
public:    
  this( typeof( _sequences ) seqs, typeof( _states ) states, typeof( _mutationCosts ) mutationCosts ) {
    super( seqs, states, mutationCosts );
    _cache = new Cost[ seqs[ 0 ].length ];
  }
  
  //Relies on the fact that the outer loop is on period length.
  //Relies on the face that the first duplication for a given length starts at position 0.
  override void duplicationCost( ref Duplication dup ) {
    if( dup.start == 0 ) {
      _costSum = 0;
      foreach( current; dup.positions ) {      
          auto posCost = positionCost( current, dup.period );          
          _cache[ current ] = posCost;
          _costSum += posCost;
      }
      dup.cost = _costSum / dup.period;
    } else {
      import std.stdio;
      //writeln( "initial cost sum: ", _costSum );
      //writeln( "previous pos cost: ", _cache[ dup.start - 1 ] );
      
      _costSum -= _cache[ dup.start - 1 ];
      auto posCost = positionCost( dup.stop, dup.period );
      
      //writeln( "position cost: ", posCost );
      
      _cache[ dup.stop ] = posCost;
      _costSum += posCost;
      
      dup.cost = _costSum / dup.period;
      
      //writeln( "final cost sum: ", _costSum );
      //writeln( "duplication cost: ", dup.cost );      
    }
  }  
}

class Patterns( U ): Standard!( U ) {
private:
  Cost[ Pattern ] _patternsCost;  
public:    
  this( typeof( _sequences ) seqs, typeof( _states ) states, typeof( _mutationCosts ) mutationCosts ) {
    super( seqs, states, mutationCosts );
  }
  
  override Cost positionCost( size_t pos, size_t period ) { 
    auto pattern = Pattern( SequenceLeaves( _sequences, pos, period ) ); 
    if( pattern !in _patternsCost ) {
      _patternsCost[ pattern ] = super.positionCost( pos, period );
    } 
    return _patternsCost[ pattern ];    
  }
}

class CachePatterns( U ): Cache!( U ) {
private:
  Cost[ Pattern ] _patternsCost;  
public:
  this( typeof( _sequences ) seqs, typeof( _states ) states, typeof( _mutationCosts ) mutationCosts ) {
    super( seqs, states, mutationCosts );
  }

  //Copied from Patterns algorithm.
  override Cost positionCost( size_t pos, size_t period ) { 
    auto pattern = Pattern( SequenceLeaves( _sequences, pos, period ) ); 
    if( pattern !in _patternsCost ) {
      _patternsCost[ pattern ] = super.positionCost( pos, period );
    } 
    return _patternsCost[ pattern ];    
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
private void phylogenize( Tree )( ref Tree tree, Sequence[] sequences ) in {
  assert( 2 <= sequences.length );
} out {
  assert( count( tree.leaves ) == 2 * sequences.length );
} body {
  
  tree.clear();  
  auto root = tree.setRoot();  
  auto leftCurrent = tree.appendChild( root );
  auto rightCurrent = tree.appendChild( root );
  
  auto seqsCount = sequences.length;
  for( size_t seqIndex = 0; seqIndex < seqsCount; ++seqIndex ) {
    tree.appendChild( leftCurrent );
    tree.appendChild( rightCurrent );
    
    //If we have more than one sequence left, we have to create
    //at least an additional branch.
    if( 2 < ( seqsCount - seqIndex ) ) {
      leftCurrent = tree.appendChild( leftCurrent );
      rightCurrent = tree.appendChild( rightCurrent );
    }
  }  
}

/**
  Sets the leaves of the state mutation tree using the provided sequences. The leaves are set according
  to the "leaves" range from the tree structure which, as of right now, reads leaves from "left" to "right"
  (left being the first child in insertion order and right being the last). The "left" half of the tree holds
  the values (read nucleotides if working with dna) of one homologous sequence, whereas the opposite half is a mirror
  image containg the values of the other sequence.
*/
private void setLeaves( Tree, Range )( ref Tree smTree, Range sequences ) {
  //Of course, we expect both trees to have the exact same layout and therefore 
  //that the leaves iterator return the same number of leaves and in the same order.
  foreach( ref smLeaf; smTree.leaves ) {
    assert( !sequences.empty );
    smLeaf.element.fixState( sequences.front() );  
    sequences.popFront();
  }    
}


private Cost preSpeciationCost( Tree, U )( Tree smTree, U mutationCosts ) {
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