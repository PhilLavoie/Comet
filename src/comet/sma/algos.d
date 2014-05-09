/**
  Module encapsulating logic regarding the calculation of segment pairs cost.
  It provides an interface to the user in the form of algorithms that evaluate the
  cost of pairs of segments.

  Only one function function is offered publicly and provides a unified way to receive an algorithm
  object based on a set of parameters.
*/
module comet.sma.algos;

public import comet.sma.mutation_cost;
public import comet.typedefs: SequencesCount, sequencesCount;
public import comet.typedefs: SequenceLength, sequenceLength;
public import comet.configs.algos: Algo;

import comet.sma.pattern;
import comet.sma.segments;
import comet.sma.smtree;

import std.algorithm;
import range = std.range;

/**
  This function constructs and returns an algorithm object based on the given parameters. 
*/
AlgoI!Molecule algorithmFor( Molecule, MutationCosts )( Algo algo, SequencesCount seqsCount, SequenceLength length, Molecule[] states, MutationCosts mutationCosts ) {

  final switch( algo ) {
  
    case Algo.standard:
    
      return standard( seqsCount, length, states, mutationCosts );
      break;
      
    case Algo.cache:
    
      return cache( seqsCount, length, states, mutationCosts );
      break;
      
    case Algo.patterns:
    
      return patterns( seqsCount, length, states, mutationCosts );
      break;
      
    case Algo.cachePatterns:  
    
      return cachePatterns( seqsCount, length, states, mutationCosts );
      break;
      
  }
  
  assert( false );  
  
}

/**
  Formal definition of the algorithms interface.
  An algorithm must be able to provide a cost for a given segments pairs.
*/
interface AlgoI( T ) {

  Cost costFor( SegmentPairs!( T ) pairs );
  
}

/**
  This mixin declares the column cost function for the standard algorithm.
*/
private mixin template standardColumnCost() {

  /**
    
  */
  private Cost columnCost( Range )( Range column ) if( range.isInputRange!Range ) {
    //Start by extracting the states from the hierarchy: use them to set the
    //the leaves of the smtree.
    _smTree.setLeaves( column );
    
    //Process the state mutation algorithm then extract the preSpeciation cost.
    //TODO: does the tree really need the states and mutation costs every time?
    _smTree.update( _mutationCosts );
    return preSpeciationCost( _smTree, _mutationCosts );
  }
  
}

private mixin template patternColumnCost() {

  protected Cost[ Pattern ] _patternsCost;
  
  private Cost columnCost( Range )( Range column ) if( range.isInputRange!Range ) {
  
    auto pattern = Pattern( column ); 
   
    if( pattern !in _patternsCost ) {
    
      _patternsCost[ pattern ] = super.columnCost( column );
      
    } 
    
    return _patternsCost[ pattern ];    
  }
}

private mixin template standardCostFor( T ) {

  public override Cost costFor( SegmentPairs!( T ) pairs ) {
  
    real sum = 0;
    foreach( column; pairs.byColumns ) {
    
      sum += columnCost( column );
      
    }
    
    //Normalized sum.
    return sum / pairs.segmentsLength;
    
  }
  
}

private mixin template cacheCostFor( T ) {
  
  protected Cost[] _cache;
  protected real _costSum;
  
  //Relies on the fact that the outer loop is on period length.
  //Relies on the face that the first duplication for a given length starts at position 0.
  public override Cost costFor( SegmentPairs!( T ) pairs ) {
  
    //If those are the first segment pairs of a given length.
    size_t segmentsStart = pairs.leftSegmentStart;
    if( segmentsStart == 0 ) {
    
      _costSum = 0;
      foreach( column; pairs.byColumns ) {      
      
        auto posCost = columnCost( column );          
        _cache[ column.index ] = posCost;
        _costSum += posCost;
        
      }
      
      return _costSum / pairs.segmentsLength;
      
    } 
    
    //Remove the first column cost of the previously processed segment pairs.
    _costSum -= _cache[ segmentsStart - 1 ];
    //Calculate the cost of this segment pairs last column.
    auto posCost = columnCost( pairs.byColumns[ $ - 1 ]  );
    //Store it.    
    _cache[ segmentsStart + pairs.segmentsLength - 1 ] = posCost;
    //Add it to the current cost.
    _costSum += posCost;
    
    return _costSum / pairs.segmentsLength;
    
  }
  
}

class Standard( T, U ): AlgoI!T {

protected:

  SequencesCount _seqCount;
  SequenceLength _seqLength;
  T[] _states;
  U _mutationCosts;
  SMTree!T _smTree;

  //TODO: receive the phylogeny or construct the tree elsewhere?
  this( SequencesCount seqCount, SequenceLength length, typeof( _states ) states, typeof( _mutationCosts ) mutationCosts ) {
  
    _seqCount = seqCount;
    _seqLength = length;
    _states = states;
    _mutationCosts = mutationCosts;
    _smTree = SMTree!T( _states[] );
   
    //Phylogenize the tree according to the sequences, see documentation to see
    //how it is done.  
    phylogenize( _smTree, _seqCount );   
    
  }
  
  mixin standardColumnCost;
    
public:  
  
  mixin standardCostFor!T;  
  
}

private auto standard( T, U )( SequencesCount seqCount, SequenceLength length, T[] states, U mutationCosts ) {

  return new Standard!( T, U )( seqCount, length, states, mutationCosts );

}

class Cache( T, U ): Standard!( T, U ) {
protected:
  
  this( Args... )( Args args ) {
    super( args );
    _cache = new Cost[ _seqLength.value ];
  }

  mixin standardColumnCost;
  
public:    
  
  mixin cacheCostFor!T;
    
}
auto cache( T, U )( SequencesCount seqCount, SequenceLength length, T[] states, U mutationCosts ) {

  return new Cache!( T, U )( seqCount, length, states, mutationCosts );

}

class Patterns( T, U ): Standard!( T, U ) {
protected:    
  
  this( Args... )( Args args ) {
    super( args );
  }
  
  mixin patternColumnCost;
  mixin standardCostFor!T; 
  
}
auto patterns( T, U )( SequencesCount seqCount, SequenceLength length, T[] states, U mutationCosts ) {

  return new Patterns!( T, U )( seqCount, length, states, mutationCosts );

}

class CachePatterns( T, U ): Standard!( T, U ) {
protected:
  
  this( Args... )( Args args ) {
    super( args );
    _cache = new Cost[ _seqLength.value ];
  }

  mixin patternColumnCost;
  mixin cacheCostFor!T;
  
}
auto cachePatterns( T, U )( SequencesCount seqCount, SequenceLength length, T[] states, U mutationCosts ) {

  return new CachePatterns!( T, U )( seqCount, length, states, mutationCosts );

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
private void phylogenize( Tree )( ref Tree tree, SequencesCount seqCount ) in {
  
  assert( 2 <= seqCount );
  
} out {

  assert( count( tree.leaves ) == 2 * seqCount );
  
} body {
  
  tree.clear();  
  auto root = tree.setRoot();  
  auto leftCurrent = tree.appendChild( root );
  auto rightCurrent = tree.appendChild( root );
  
  for( size_t seqIndex = 0; seqIndex < seqCount; ++seqIndex ) {
    tree.appendChild( leftCurrent );
    tree.appendChild( rightCurrent );
    
    //If we have more than one sequence left, we have to create
    //at least an additional branch.
    if( 2 < ( seqCount - seqIndex ) ) {
      leftCurrent = tree.appendChild( leftCurrent );
      rightCurrent = tree.appendChild( rightCurrent );
    }
  }
  
  
}

private Cost preSpeciationCost( Tree, U )( Tree smTree, U mutationCosts ) {
  
  /*The pre speciation cost is associated with the number of mutations
    from the root to its children, accounting for every possible reconstructions.
    That value is then averaged by the number of possible reconstructions.*/
  size_t noRecons = 0;
  Cost costSum = 0.0;
  
  //Extract the candidates that have the minimum cost.
  auto root = smTree.root;
  auto minCost = root.element.minCost;
  
  foreach( rootStateTuple; root.element[] ) {
  
    auto rootState = rootStateTuple.state;
    auto rootCost  = rootStateTuple.cost;
    auto rootCount = rootStateTuple.count;
  
    //It is a candidate if its cost is the minimum.
    //For each candidates, we accumulate their number of occurrences and calculate
    //the total cost of pre speciation mutations.
    if( minCost == rootCost ) {
      
      noRecons += rootCount;
      
      foreach( child; root.children ) {
        
        //We need to extract the number of equivalent sub choices from each children.      
        size_t equivalentsCount = 0;
        
        auto minMutCost = minMutationCost( rootState, child.element, mutationCosts );
        
        foreach( childStateTuple; child.element[] ) {
          
          auto childState = childStateTuple.state;
          auto childCost = childStateTuple.cost;
          auto childCount = childStateTuple.count;
          
          if( childCost + mutationCosts.costFor( rootState, childState ) == minMutCost ) {
          
            equivalentsCount += childCount;
          
          }
          
        } 
 
        size_t multiplier = rootCount / equivalentsCount;      
      
        assert( 0 < equivalentsCount );
        assert( rootCount % equivalentsCount == 0 );
        assert( 0 < multiplier );
      
        foreach( childStateTuple; child.element[] ) {
        
          auto childState = childStateTuple.state;
          auto childCost = childStateTuple.cost;
          auto childCount = childStateTuple.count;
        
          if( childCost + mutationCosts.costFor( rootState, childState ) == minMutCost ) {
          
            costSum += mutationCosts( rootState, childState ) * childCount * multiplier;
            
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

  import comet.bio.dna;
  
  auto validStates = [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE ];
  auto tree = SMTree!Nucleotide( validStates[] );
  
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
  
  
  auto mutationCosts = 
    ( Nucleotide n1, Nucleotide n2 ){ 
      if( n1 == n2 ) {
        return 0;
      }
      return 1;
    };

  tree.update(
    mutationCosts
  );
   
  auto zeCost = preSpeciationCost( tree, mutationCosts );
  auto zeExpected = cast( Cost )10 / 14;
  assert( zeExpected - Cost.epsilon <= zeCost && zeCost <= zeExpected + Cost.epsilon );
  
}