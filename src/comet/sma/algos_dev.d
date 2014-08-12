//Algos'api is being currently reviewed here. Some important changes are expected
//to happen. This module is planned to replace alogs when finished.

/**
  Module encapsulating logic regarding the calculation of segment pairs cost.
  It provides an interface to the user in the form of algorithms that evaluate the
  cost of pairs of segments.

  Only one function is offered publicly and provides a unified way to receive an algorithm
  object based on a set of parameters.
*/
module comet.sma.algos_dev;

public import comet.sma.mutation_cost;
public import comet.typedefs: SequencesCount, sequencesCount;
public import comet.typedefs: SequenceLength, sequenceLength;
public import comet.configs.algos: Algo;
public import comet.sma.smtree: StatesInfo;

import comet.sma.pattern;
import comet.sma.segments;
import comet.sma.smtree;

import std.algorithm;
import range = std.range;

/**
  The user can request the algorithm to record intermediate data allowing
  for the calculation of a segments pairs cost. This data is the sankoff root nodes calculated for
  every position inside the segments pairs. Since keeping record of this data can affect performance
  noticeably, the user has the power to decide whether or not it should be used.
*/
alias TrackRootNodes = std.typecons.Flag!"TrackRootNodes";

/**
  Algorithm optimizations. The user can chose from no optimizations, the usage on a windowing system
  or a pattern matching algorithm for previously calculated values.
*/
enum Optimization {
  none,
  windowing,
  patterns,
  windowingPatterns
}

/**
  This algorithm structure encapsulate the logic behind the calculation of the pre speciation costs of a given segments pairs.
  The user specifies which optimization should be used, if any.
  
  It is also possible to track the intermediate results used to calculate such a cost, using the TrackRootNodes template parameter.
  
  This structure offers one main function, namely "costFor". This function takes a SegmentsPairs and return its calculated cost.
  
  Note: The patterns algorithm only makes sense if using the 0, 1 mutation costs function (0 cost if equals 1 otherwise).
  Note: When using the windowing pattern, the user must make use a scheme such that every positions for a given segments pairs length are
  calculated first before changing the length. Also, this calculation should start at index 0.
  Note: This structure was not intended to be used with the default constructor, use the factory function(s) provided.
*/
struct Algorithm(Optimization opt, TrackRootNodes trn, State, M,) 
{
  //Those are the fields shared by all algorithms.
  private M _mutationCosts;           //The callable used to evaluate the cost of mutatin a state to a given one.
  private SMTree!State _smTree;       //The state mutations analysis tree.

  private enum usingPatterns  = opt == Optimization.patterns  || opt == Optimization.windowingPatterns;
  private enum usingWindow    = opt == Optimization.windowing || opt == Optimization.windowingPatterns;
  
  static if(usingPatterns) 
  {
    //When the patterns optimization is used, a map is internally used to store a pattern's previously calculated cost.
    private Cost[ Pattern ] _patternsCost;
  }
  
  static if(usingWindow)
  {
    //The window used. Guaranteed to never be bigger than half of the sequences length. It is reused consistently for each calculation.
    private Cost[] _window;
    //The cost of the previously calculated segments pairs.
    private real _costSum;
  }  
  
  private this(States)( SequencesCount seqCount, SequenceLength length, States states, typeof( _mutationCosts ) mutationCosts ) 
  if(is(ElementType!States == State))
  {  
    _mutationCosts  = mutationCosts;
    _smTree         = SMTree!State(states[]);
   
    static if(usingWindow) 
    {
      _window   = new Cost[length.value];
      _costSum  = 0;
    }
   
    //Phylogenize the tree according to the sequences, see documentation to see
    //how it is done.  
    phylogenize( _smTree, seqCount );       
  }
  
  private this(Sequences, States, Phylo)(Sequences sequences, States states, typeof(_mutationCosts) mc, Phylo phylo)
  {
    _mutationCosts  = mutationCosts;
    _smTree         = SMTree!State(states[]);
    
    import std.range: walkLength;
    static if(usingWindow) 
    {
      auto sequencesLength = walkLength(sequences.front());
      _window   = new Cost[sequencesLength];
      _costSum  = 0;
    }
   
    auto noSequences = walkLength(sequences);
    
    makeDST(_smTree, phylo);       
  }
  
  //Duplication speciation tree.
  private void makeDST(Tree1, Tree2)(ref Tree1 dst, in Tree2 phylo)
  {
    dst.clear();
    
    Tree1 leftSubTree;
    Tree1 rightSubTree;
    leftSubTree.mimick(phylo);
    rightSubTree.mimick(phylo);
    
    auto root = dst.setRoot();
    dst.appendSubTree(root, leftSubTree);
    dst.appendSubTree(root, rightSubTree);    
    
    import std.range: walkLength;
    assert(walkLength(dst.leaves()) == (2 * walkLength(phylo.leaves())));
    
    auto dstLeaves = dst.leaves();
    auto phyloLeaves = phylo.leaves();
    
    //A mapping of the leaves to their corresponding sequences.
    alias NodeType = typeof(dst.root());
    alias SequenceType = typeof(phylo.root().element().get());
    SequenceType[NodeType] sequencesNodes;    
    
    scope(exit)
    {
      assert(sequencesNodes.length == walkLength(dst.leaves()));
    }
    
    for(int i = 0; i < 2; ++i)
    {
      foreach(phyloLeaf; phyloLeaves)
      {
        sequencesNodes[dstLeaves.front()] = phyloLeaf.element().get();      
        dstLeaves.popFront();
      }
    }
    assert(dstLeaves.empty());    
  }
  
  /**
    Calculates the cost of a single position inside the segments pairs.
    A specialization exist when using patterns.
  */
  //Patterns version.
  private Cost columnCost( bool useP, Range )( Range column ) if( range.isInputRange!Range && useP ) 
  {        
    //Calculate the pattern of the leaves.
    //TODO: how does this work with nucleotide sequences?????
    auto pattern = Pattern( column ); 
   
    //If a similar set of leaves have already been calculated, then use the previously stored cost.
    if( pattern !in _patternsCost ) 
    {      
      _patternsCost[ pattern ] = columnCost!(false)( column );        
    } 
    
    return _patternsCost[ pattern ];    
  }
  ///Ditto.
  //No patterns version.
  private Cost columnCost( bool useP, Range )( Range column ) if( range.isInputRange!Range && !useP) 
  {    
    //Start by extracting the states from the hierarchy: use them to set the leaves of the smtree.
    _smTree.setLeaves( column );
    
    //Process the state mutation algorithm then extract the preSpeciation cost.
    _smTree.update( _mutationCosts );
    return preSpeciationCost( _smTree, _mutationCosts );
  } 
  
  static if(usingWindow)
  {
    /**
      Calculates the average pre speciations cost of the given segments pairs.
      The segments can hold the same type as the state type or a range over this type, i.e. a slice of state for example.
      
      Relies on the fact that the outer loop is on period length.
      Relies on the fact that the first duplication for a given length starts at position 0.
    */    
    public Cost costFor( T )( SegmentPairs!( T ) pairs ) 
    {    
      //If those are the first segment pairs of a given length.
      size_t segmentsStart = pairs.leftSegmentStart;
      if( segmentsStart == 0 ) 
      {
        _costSum = 0;
        foreach( column; pairs.byColumns ) 
        {              
          auto posCost = columnCost!usingPatterns( column );          
          _window[ column.index ] = posCost;
          _costSum += posCost;          
        }
        
        return _costSum / pairs.segmentsLength;        
      } 
      
      //Remove the first column cost of the previously processed segment pairs.
      _costSum -= _window[ segmentsStart - 1 ];
      //Calculate the cost of this segment pairs last column.
      auto posCost = columnCost!usingPatterns( pairs.byColumns[ $ - 1 ]  );
      //Store it.    
      _window[ segmentsStart + pairs.segmentsLength - 1 ] = posCost;
      //Add it to the current cost.
      _costSum += posCost;
      
      return _costSum / pairs.segmentsLength;      
    }  
  }
  else
  {
    /**
      Calculates the average pre speciations cost of the given segments pairs.
      The segments can hold the same type as the state type or a range over this type, i.e. a slice of state for example.
    */
    public Cost costFor( T )( SegmentPairs!( T ) pairs ) 
    {
      real sum = 0;
      foreach( column; pairs.byColumns ) 
      {      
        sum += columnCost!usingPatterns( column );        
      }
      
      //Normalized sum.
      return sum / pairs.segmentsLength;      
    }
  
  }  
}

/**
  Factory function for easy type inference of the construction parameters.
  This function will become deprecated.
*/
//TODO: deprecate.
auto makeAlgorithm(Optimization opt, TrackRootNodes trn, State, M)(SequencesCount seqCount, SequenceLength length, State[] states, M mutationCosts) 
{
  return Algorithm!(opt, trn, State, M)(seqCount, length, states, mutationCosts);
}

/**
  Overload with phylogenetic tree as a parameter.
  New code is expected to use this one.
*/
/* auto makeAlgorithm(
  Optimization opt, 
  TrackRootNodes trn,
  State, 
  M
  )(
  SequencesCount seqCount,
  SequenceLength length,
  State[] states, 
  M mutationCosts
) {
  return Algorithm!(opt, trn, State, M)(seqCount, length, states, mutationCosts);
} */

/**
  Returns if the given type refers to an algorithm provided by this module.
*/
template isAlgorithm(A) 
{
  enum isAlgorithm = std.traits.isInstanceOf!(Algorithm, A);
}

unittest 
{
  //Instantiate all combinations to see if it compiles.
  enum noTrn = TrackRootNodes.no;
  enum trn   = TrackRootNodes.yes;
  
  alias Func = Cost function(int, int);
  
  auto algo1 = Algorithm!(Optimization.none, noTrn, int, Func).init;
  auto algo2 = Algorithm!(Optimization.none, trn, int, Func).init;
  
  auto algo3 = Algorithm!(Optimization.windowing, noTrn, int, Func).init;
  auto algo4 = Algorithm!(Optimization.windowing, trn, int, Func).init;
  
  auto algo5 = Algorithm!(Optimization.patterns, noTrn, int, Func).init;
  auto algo6 = Algorithm!(Optimization.patterns, trn, int, Func).init;
  
  auto algo7 = Algorithm!(Optimization.windowingPatterns, noTrn, int, Func).init;
  auto algo8 = Algorithm!(Optimization.windowingPatterns, trn, int, Func).init; 
  
  auto algo9 = makeAlgorithm!(Optimization.windowingPatterns, TrackRootNodes.yes)(sequencesCount(4), sequenceLength(10), [ 1, 2, 3, 4], (int x, int y) => 0.0);
  
  static assert(isAlgorithm!(typeof(algo1)));
  static assert(isAlgorithm!(typeof(algo9)));
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
  assert(zeExpected - Cost.epsilon <= zeCost && zeCost <= zeExpected + Cost.epsilon);  
}