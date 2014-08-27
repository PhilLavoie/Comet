/**
  Module encapsulating logic regarding the calculation of segment pairs cost.
  It provides an interface to the user in the form of algorithms that evaluate the
  cost of pairs of segments.
*/
module comet.sma.algos;

public import comet.sma.mutation_cost;
public import comet.configs.algos: Algo;
public import comet.sma.smtree: StatesInfo;

import comet.sma.pattern;
import comet.sma.segments;
import comet.sma.smtree;
import comet.results;

import std.algorithm;
import std.range: ElementType, isInputRange;
import std.traits: isInstanceOf;
import std.typecons: Nullable;
import std.conv: to;

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
  private enum usingPatterns  = opt == Optimization.patterns  || opt == Optimization.windowingPatterns;
  private enum usingWindow    = opt == Optimization.windowing || opt == Optimization.windowingPatterns;
  
  //Up to now, supports only the tracking of root nodes when not using patterns.
  static assert(!trn || !usingPatterns);

  //Those are the fields shared by all algorithms.
  private M _mutationCosts;           //The callable used to evaluate the cost of mutation a state to a given one.
  private SMTree!State _smTree;       //The state mutations analysis tree.
  
  private const size_t _noSequences;
  private const size_t _sequencesLength;
  
  //TODO:deprecate
  @property private auto sequencesLength() {return _sequencesLength;}
  @property private auto noSequences() {return _noSequences;}
  
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
      assert(this.sequence == rhs.sequence);
    }
  }
  
  private NodeSequence[] _leftLeaves;
  private NodeSequence[] _rightLeaves;

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
  
  static if(trn)
  {
    alias RootData = typeof(_smTree.root().element());
    //We need to make a deep copy of the data, because it is reused for every analysis.
    RootData[] _rootNodes;
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

    static if(trn)
    {
      _rootNodes = new RootData[_sequencesLength];  //It will never be bigger than the sequences length, no matter what algorithm is used.
    }
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
  
  static if(trn)
  {
    import std.typecons: Tuple;
    alias Return = Result!(typeof(_rootNodes[]));
  }
  else
  {
    alias Return = Result!void;
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
    private Return costFor(in size_t start, in size_t segmentsLength) 
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
          
          static if(trn)
          {
            _rootNodes[i] = _smTree.root().element().clone();
          }
          
          _window[i] = posCost;          
          _costSum += posCost;
        }
        
        auto cost = _costSum / segmentsLength;      
        
        static if(trn)
        {
          return result(start, .segmentsLength(segmentsLength), cost, _rootNodes[start .. segmentsEnd].dup);
        }
        else
        {
          return result(start, .segmentsLength(segmentsLength), cost);
        
        }
      } 
      
      //Remove the first column cost of the previously processed segment pairs.
      _costSum -= _window[start - 1];
      //Calculate the cost of this segment pairs last column.
      auto lastColumn = start + segmentsLength - 1;
      
      auto posCost = columnCost!usingPatterns(lastColumn, segmentsLength);
      static if(trn)
      {
        _rootNodes[lastColumn] = _smTree.root().element().clone();
      }
      
      //Store it.    
      _window[lastColumn] = posCost;
      //Add it to the current cost.
      _costSum += posCost;
      
      auto cost = _costSum / segmentsLength;      
      static if(trn)
      {
        return result(start, .segmentsLength(segmentsLength), cost, _rootNodes[start .. lastColumn + 1].dup);
      }
      else
      {
        return result(start, .segmentsLength(segmentsLength), cost);
      }
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
    private Return costFor(in size_t start, in size_t segmentsLength)
    in
    {
      assert(0 < segmentsLength);
      assert(start + 2 * segmentsLength <= _sequencesLength, "start: " ~ to!string(start) ~ " segmentsLength: " ~ to!string(segmentsLength));
    }
    body
    {
      real sum = 0;
      
      static if(trn)
      {
        _rootNodes.length = segmentsLength;
      }
      
      auto segmentsEnd = start + segmentsLength;
      for(size_t i = start; i < segmentsEnd; ++i)
      {
        sum += columnCost!usingPatterns(i, segmentsLength);
        static if(trn)
        {
          _rootNodes[i - start] = _smTree.root().element().clone();
        }
      }      
      
      //Normalized sum.
      auto cost = sum / segmentsLength;      
      
      static if(trn)
      {
        return result(start, .segmentsLength(segmentsLength), cost, _rootNodes.dup);
      }
      else
      {
        return result(start, .segmentsLength(segmentsLength), cost);
      }
    }  
  }  
  
  private alias Algo = typeof(this);
  
  private struct Results {
    
    Algo* _algoP;
    
    //Segments length loop parameters.
    size_t _segmentsLength;
    const size_t _maxLength;
    const size_t _lengthStep;
    
    //Position loop parameters.
    size_t _current;
    size_t _end; 
    
    this(typeof(_algoP) algo, LengthParameters length) 
    {
      _algoP = algo; 
    
      import std.algorithm: min;   
      //The maximum is inclusive.
      _maxLength = min(length.max.value(), _algoP.sequencesLength() / 2);
      assert(length.min <= _maxLength);
      _segmentsLength = length.min;
      _lengthStep = length.step;
      
      _current = 0;
      //Inclusive last position.
      _end = _algoP.sequencesLength() - (2 * _segmentsLength);
    }
    
    @property auto save() {return this;}
    @property auto front() 
    {
      return _algoP.costFor(_current, _segmentsLength);     
    }
    @property bool empty() const {return _maxLength < _segmentsLength;}
    
    void popFront()
    {
      //Move the current position.
      ++_current;
      //If we reached the end, move on to next segments length.
      if(_end < _current)
      {
        _segmentsLength += _lengthStep;
        _current = 0;
        _end = _algoP.sequencesLength() - (2 * _segmentsLength);
      }     
    }     
  }
  
  auto resultsFor(LengthParameters length)
  {
    return Results(&this, length);
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
  
  auto results = algo.resultsFor(lengthParameters(minLength(1), maxLength(10000), lengthStep(1)));
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

/**
  Returns if the given type is an instance of the Result template.
*/
template isResult( R ) {
  enum isResult = isInstanceOf!( Result, R );
}

/**
  Returns if the result holds per position values, which are held in a container.
*/
template hasContainer(R) if( isResult!R ) {
  enum hasContainer = R.hasContainer;
}

/**
  A structure built to represent a result of a segments pairs cost calculation. It holds the left segment
  start index position, the segments length, and the cost of the calculation.  
  
  In the event the user wants to track the root data of the state mutation tree that produced the given
  result, this structure will also hold said root nodes.
*/
struct Result(C = void) 
{
  private enum hasContainer = !is(C == void); 

  private size_t _start;    //The left segment start index of the segments pairs.
  private size_t _length;   //The length of each segment.
  private Cost _cost;       //The total cost of the segments pairs associated with the previous fields.
  
  static if(hasContainer) 
  {  
    private C _perPosition;    
    @property public auto perPosition() {return _perPosition[];}  
  }  
  
  @property public auto start()  { return _start; }
  @property public auto length() { return _length; }
  @property public auto cost()   { return _cost; }
  
  /**
    A cost based comparison ordering. When the cost is equals, the
    longest segments length wins. When both fields are equals, then
    there is an arbitrary ordering on the left index start.
    
    Unless every field are the same for both results, this function
    will return an unequal comparison.
  */
  public ptrdiff_t opCmp(Result rhs)
  {  
    //First compare on the cost criteria.
    if( _cost < rhs._cost - Cost.epsilon ) { 
    
      return -1; 
      
    } else if( rhs._cost + Cost.epsilon < _cost ) {
    
      return 1;
      
    }
    
    //If the cost is equals, then the longer segments length wins.
    auto cmp = rhs._length - _length;
    if(cmp) {return cast(ptrdiff_t)cmp;}
    
    //Arbitrary ordering otherwise, based on left segment start.
    return cast(ptrdiff_t)(_start - rhs._start);    
  }
  
  /**
    Because it isn't rare that two calculations done with floats
    should give the exact same result but doesn't, this method is used
    to compare two results on the basis of their cost but with an
    epsilon parameter to be more flexible.
  */
  public bool isEquivalentTo(Result rhs, Cost epsilon) 
  in 
  {  
    assert(epsilon > 0);    
  } 
  body 
  {  
    return ((_cost - epsilon <= rhs._cost && rhs._cost <= _cost + epsilon));    
  }  
}

/**
  Factory function to create results.
*/
auto result( size_t start, SegmentsLength length, Cost cost ) {
  return Result!(void)( start, length.value, cost );
}
auto result(C)(size_t start, SegmentsLength length, Cost cost, C rootNodes)
{
  return Result!(C)(start, length.value, cost, rootNodes);
}

unittest {
  
  Result!void r1, r2;
  static assert( isResult!(typeof(r1)) );
  static assert( isResult!(typeof(r2)) );
  static assert( !hasContainer!(typeof(r1)) );
  static assert( !hasContainer!(typeof(r2)) );
  r1._start = 0u;
  r1._length = 100;
  r1._cost = 20.0;
  r2._start = 10;
  r2._length = 20;
  r2._cost = 21.0;
  
  //Cost based ordering.
  assert( r1 < r2 );
  r1._cost = r2._cost + 1;
  assert( r2 < r1 );
  
  //Length ordering.
  r2._cost = r1._cost;
  assert( r1 < r2 );
  r2._length = r1._length + 1;
  assert( r2 < r1 );
  
  //Start index ordering.
  r2._cost = r1._cost;
  r2._length = r1._length;
  assert( r1 < r2 );
  r1._start = r2._start + 1;
  assert( r2 < r1 );
  
  //Equality.
  r1 = r2;
  assert( r1 == r2 );
  assert( r1.isEquivalentTo(r2, double.epsilon ) );
  
  r1._cost = 0;
  r2._cost = 1;
  assert( r1.isEquivalentTo(r2, 1. ) );  
  
}