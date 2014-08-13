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
public import comet.configs.algos: Algo;
public import comet.sma.smtree: StatesInfo;

import comet.sma.pattern;
import comet.sma.segments;
import comet.sma.smtree;

import std.algorithm;
import std.range: ElementType, isInputRange;
import std.traits: isInstanceOf;
import std.typecons: Nullable;

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
struct Algorithm(Optimization opt, TrackRootNodes trn, Sequence, State, M) 
{
  //Those are the fields shared by all algorithms.
  private M _mutationCosts;           //The callable used to evaluate the cost of mutation a state to a given one.
  private SMTree!State _smTree;       //The state mutations analysis tree.
  
  private size_t _noSequences;
  private size_t _sequencesLength;
  
  //TODO:deprecate
  @property auto sequencesLength() {return _sequencesLength;}
  @property auto noSequences() {return _noSequences;}
  
  private alias NodeType = typeof(_smTree.root());
  
  private struct NodeSequence
  {
    NodeType node;
    Sequence sequence;
    
    void opAssign(typeof(this) rhs)
    {
      this.node = rhs.node;
      import std.traits: Unqual;
      auto sequenceP = cast(Unqual!(typeof(this.sequence))*)&this.sequence;
      *sequenceP = rhs.sequence;
    }
  }
  
  //private Sequence[NodeType] _nodesSequences;
  private NodeSequence[] _leftLeaves;
  private NodeSequence[] _rightLeaves;

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
  
  private this(Phylo, States)(Phylo phylo, States states, typeof(_mutationCosts) mc)
  {
    _mutationCosts  = mc;
    _smTree         = SMTree!State(states[]);
    
    auto leaves = phylo.leaves();
    import std.range: walkLength;
    _sequencesLength = walkLength(leaves.front().element().get());
    
    foreach(leaf; leaves)
    {
      import std.conv: to;
      auto leafSequenceLength = walkLength(leaf.element().get());
      assert( 
        leafSequenceLength == _sequencesLength, 
        "expected all sequences to be of length: " ~ to!string(_sequencesLength) 
        ~ " but found: " ~ to!string(leafSequenceLength)
      );
    }
    
    static if(usingWindow) 
    {
      _window   = new Cost[_sequencesLength];
      _costSum  = 0;
    }
   
    _noSequences = walkLength(leaves);
    assert(2 <= _noSequences);
    
    makeDST(_smTree, phylo);       
  }
  
  //Duplication speciation tree.
  private void makeDST(Tree1, Tree2)(ref Tree1 dst, in Tree2 phylo)
  {
    dst.clear();
    
    Tree1 leftSubTree = Tree1(dst.states());
    Tree1 rightSubTree = Tree1(dst.states());
    leftSubTree.mimic(phylo);
    rightSubTree.mimic(phylo);
    
    auto root = dst.setRoot();
    
    auto node = dst.appendSubTree(root, leftSubTree);
    assert(node !is null);
    assert(node == leftSubTree.root(), "node: " ~ to!string(node) ~ " leftSubTree.root(): " ~ to!string(leftSubTree.root()));
    assert(node.element() == leftSubTree.root().element());
    
    node = dst.appendSubTree(root, rightSubTree);    
    assert(node !is null);
    assert(node == rightSubTree.root(), "node: " ~ to!string(node) ~ " rightSubTree.root(): " ~ to!string(rightSubTree.root()));
    assert(node.element() == leftSubTree.root().element());
        
    auto dstLeaves = dst.leaves();
    auto phyloLeaves = phylo.leaves();
    
    import std.range: walkLength;
    auto noDSTLeaves = walkLength(dstLeaves);
    auto noPhyloLeaves = walkLength(phyloLeaves);
    
    assert(noDSTLeaves == (2 * noPhyloLeaves));
    
    scope(success)
    {
      assert(_leftLeaves.length == noPhyloLeaves);
      assert(_rightLeaves.length == noPhyloLeaves);
      assert(_leftLeaves.length + _rightLeaves.length == noDSTLeaves);
    }
    
    _leftLeaves = new NodeSequence[noPhyloLeaves];
    size_t index = 0;
    foreach(phyloLeaf; phyloLeaves)
    {
      _leftLeaves[index] = NodeSequence(dstLeaves.front(), phyloLeaf.element().get());
      dstLeaves.popFront();
      ++index;
    }
    
    _rightLeaves = new NodeSequence[noPhyloLeaves];
    index = 0;
    foreach(phyloLeaf; phyloLeaves)
    {
      _rightLeaves[index] = NodeSequence(dstLeaves.front(), phyloLeaf.element().get());
      dstLeaves.popFront();
      ++index;
    }

    assert(dstLeaves.empty());    
  }
  
  /**
    Calculates the cost of a single position inside the segments pairs.
    
    Params:
      useP = When set to true, this function uses the patterns optimization. Note that
        this will not compile if the user did not configure the algorithm to use the optimization
        in the first place.
      
      start = The index on which the segments pairs begin.
      segmentsLength = The length of each segment.
  */  
  private Cost columnCost(bool useP)(size_t start, size_t segmentsLength) if(useP) 
  {        
    import std.algorithm: map;
    auto left = _leftLeaves.map!(ns => ns.sequence[start]);
    auto right = _rightLeaves.map!(ns => ns.sequence[start + segmentsLength]);
    
    import std.algorithm: chain;    
    //Calculate the pattern of the leaves.
    //TODO: how does this work with nucleotide sequences?????
    auto pattern = Pattern(chain(left,right)); 
   
    //If a similar set of leaves have already been calculated, then use the previously stored cost.
    if(pattern !in _patternsCost) 
    {      
      _patternsCost[pattern] = columnCost!(false)(start, segmentsLength);        
    } 
    
    return _patternsCost[ pattern ];    
  }
  ///Ditto.  
  private Cost columnCost(bool useP)(size_t start, size_t segmentsLength) if(!useP)
  {
    foreach(ns; _leftLeaves)
    {
      ns.node.element().fixStates(ns.sequence[start]);
    }
    
    auto offset = start + segmentsLength;
    foreach(ns; _rightLeaves)
    {
      ns.node.element().fixStates(ns.sequence[offset]);
    }
    _smTree.update(_mutationCosts);
    return preSpeciationCost(_smTree, _mutationCosts);
  }
  
  static if(usingWindow)
  {
    /**
      Calculates the average pre speciations cost of the given segments pairs starting at the given position
      and of the given length.
      
      This function uses the windowing optimization.
      Relies on the fact that the outer loop is on period length.
      Relies on the fact that the first duplication for a given length starts at position 0.
            
      Params:
        start = The start index of the segments pairs.
        segmentsLength = The length of the segments.
        
      Return:
        The average pre speciation cost of the given segments pairs.
    */    
    public Cost costFor(in size_t start, in size_t segmentsLength) 
    in
    {
      assert(0 < segmentsLength);
      assert(start + 2 * segmentsLength <= _sequencesLength);
    }
    body
    {    
      //If those are the first segment pairs of a given length.
      if(start == 0) 
      {
        _costSum = 0;
        
        auto segmentsEnd = start + segmentsLength;
        
        for(size_t i = start; i < segmentsEnd; ++i)
        {
          auto posCost = columnCost!usingPatterns(i, segmentsLength);
          _window[i] = posCost;
          _costSum += posCost;
        }
        
        return _costSum / segmentsLength;        
      } 
      
      //Remove the first column cost of the previously processed segment pairs.
      _costSum -= _window[start - 1];
      //Calculate the cost of this segment pairs last column.
      auto lastColumn = start + segmentsLength - 1;
      auto posCost = columnCost!usingPatterns(lastColumn, segmentsLength);
      //Store it.    
      _window[lastColumn] = posCost;
      //Add it to the current cost.
      _costSum += posCost;
      
      return _costSum / segmentsLength;      
    }  
  }
  else
  {
    /**
      Calculates the average pre speciations cost of the given segments pairs starting at the given position
      and of the given length.
      
      Params:
        start = The start index of the segments pairs.
        segmentsLength = The length of the segments.
        
      Return:
        The average pre speciation cost of the given segments pairs.
    */    
    public Cost costFor(in size_t start, in size_t segmentsLength)
    in
    {
      assert(0 < segmentsLength);
      assert(start + 2 * segmentsLength <= _sequencesLength);
    }
    body
    {
      real sum = 0;
      auto segmentsEnd = start + segmentsLength;
      for(size_t i = start; i < segmentsEnd; ++i)
      {
        sum += columnCost!usingPatterns(i, segmentsLength);
      }
      //Normalized sum.
      return sum / segmentsLength;      
    }  
  }  
}

/**
  Returns if the given type refers to an algorithm provided by this module.
*/
template isAlgorithm(A) 
{
  enum isAlgorithm = isInstanceOf!(Algorithm, A);
}

auto makeAlgorithm
  (
    Optimization opt,
    TrackRootNodes trn, 
    Phylo,
    State, 
    M
  ) (
    Phylo phylo,
    State[] states, 
    M mutationCosts,
)
out(ret)
{
  static assert(isAlgorithm!(typeof(ret)));
}
body
{
  return Algorithm!(opt, trn, typeof(phylo.root().element().get()), State, M)(phylo, states, mutationCosts);
}

unittest
{
  auto sequences = [[1,2,3,4], [2,4,6,8], [1,3,5,7]];
  import comet.loader: defaultPhylogeny;
  auto phylo = defaultPhylogeny(sequences);
  auto states = [1,2,3,4,5,6,7,8];
  auto mc = (int a, int b) {
      if(a == b){return 0;}
      return 1;
    };
  
  auto algo = makeAlgorithm!(Optimization.windowingPatterns, TrackRootNodes.no)(phylo, states, mc);
  
  {
    auto leaves = algo._smTree.leaves();
    
    import std.range: walkLength;
    assert(walkLength(leaves) == 6);
    
    auto counter = 0;
    foreach(leaf; leaves) 
    {
      if(counter < 3)
      {
        auto index = counter;
        assert(algo._leftLeaves[index].node == leaf);
        assert(algo._leftLeaves[index].sequence == sequences[index]);
      }
      else
      {
        auto index = counter - 3;
        assert(algo._rightLeaves[index].node == leaf);
        assert(algo._rightLeaves[index].sequence == sequences[index]);
      }
      ++counter;
    }
  }
  
  auto cost1 = algo.columnCost!false(0,2);  
  auto cost2 = algo.columnCost!true(0,2);  
  
  assert(cost1 == cost2);
  
  {
    auto cost = algo.costFor(0, 2);  
  }
}

/+
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
+/

//TODO: known bug for very high values.
private Cost preSpeciationCost( Tree, U )( Tree smTree, U mutationCosts ) {
  
  /*
    The pre speciation cost is associated with the number of mutations
    from the root to its children, accounting for every possible reconstructions.
    That value is then averaged by the number of possible reconstructions.
  */
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
        assert(rootCount % equivalentsCount == 0, "rootCount: " ~ to!string(rootCount) ~ " equivalentsCount: " ~ to!string(equivalentsCount));
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