/**
  Module providing facilities for handling results obtained by processing segments
  pairs in the context of state mutation analysis on sequences.
*/
module comet.results;

public import comet.typedefs: NoResults, noResults;
public import comet.typedefs: SegmentsLength, segmentsLength;
public import comet.typedefs: Cost;

import std.container;
import std.range: isInputRange, ElementType;
import std.traits: isInstanceOf, hasMember;

/**
  Returns if the given type is an instance of the Result template.
*/
template isResult( R ) {
  enum isResult = isInstanceOf!( Result, R );
}

/**
  Returns if the result holds per position values, which are held in a container.
*/
template hasContainer( R ) if( isResult!R ) {
  enum hasContainer = hasMember!(R, "_perPosition");
}

/**
  A structure built to represent a result of a segments pairs distance (cost) calculation. It holds the left segment
  start index position, the segments length, and the cost of the calculation.  
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
  public int opCmp(Result rhs)
  {  
    //First compare on the cost criteria.
    if( _cost < rhs._cost - Cost.epsilon ) { 
    
      return -1; 
      
    } else if( rhs._cost + Cost.epsilon < _cost ) {
    
      return 1;
      
    }
    
    //If the cost is equals, then the longer segments length wins.
    auto cmp = rhs._length - _length;
    if(cmp) {return cmp;}
    
    //Arbitrary ordering otherwise, based on left segment start.
    return _start - rhs._start;    
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
  r1.start = 0;
  r1.length = 100;
  r1.cost = 20.0;
  r2.start = 10;
  r2.length = 20;
  r2.cost = 21.0;
  
  //Cost based ordering.
  assert( r1 < r2 );
  r1.cost = r2.cost + 1;
  assert( r2 < r1 );
  
  //Length ordering.
  r2.cost = r1.cost;
  assert( r1 < r2 );
  r2.length = r1.length + 1;
  assert( r2 < r1 );
  
  //Start index ordering.
  r2.cost = r1.cost;
  r2.length = r1.length;
  assert( r1 < r2 );
  r1.start = r2.start + 1;
  assert( r2 < r1 );
  
  //Equality.
  r1 = r2;
  assert( r1 == r2 );
  assert( r1.isEquivalentTo( r2 ) );
  
  r1.cost = 0;
  r2.cost = 1;
  assert( r1.isEquivalentTo( r2, 1. ) );  
  
}

/**
  A wrapper around a fast, ordered index (as of right now, the structure used is a red black tree).
  It keeps track of how many results were inserted so that it does not go beyond a maximum limit.
  When the limit is reached, if the new result to be inserted is better than the worse one held,
  then the latter is popped from the tree and the former is inserted, satisfying the limit.
*/
struct Results( R ) if( isResult!R ) {

  private RedBlackTree!( R ) _results;
  private size_t _max;

  //@disable this();
  
  /**
    The number of results is intended to be bounded.
    The parameter provided is that bound (inclusive).
  */
  this( NoResults maxResults ) {
  
    _results = new typeof( _results )();
    _max = maxResults.value;
    
  }
  
  /**
    Returns the number of results currently stored.
  */
  @property size_t length() { return _results.length; }
  
  /**
    This function adds the results only if:
      - The maximum number of results has not been reached, or
      - The worst duplication known is worse than the result to be
        inserted. In that case, the worst result is exchanged
        with the provided one.
  */
  void add( Rez )( Rez result ) if( is( Rez == R ) ) {
  
    if( !_max ) { return; }
    
    //Store result.
    if( _results.length < _max ) {
    
      _results.insert( result );
      
    //If we reached the maximum number of results, then we determine
    //if the current duplication result is better than the worst already known.
    //If so, we get rid of the worst and insert the better one.
    } else if( result < _results.back() ){
    
      _results.removeBack();
      _results.insert( result );
      
    }
    
  }
  ///DITTO.
  void add( Rez )( Rez range ) if( isInputRange!Rez && is( ElementType!Rez == R ) ) 
  {  
    foreach( R res; range ) 
    {    
      add( res );    
    }  
  }

  /**
    Returns a range of results in ascending order (the "lowest" result is the actual best).
  */
  auto opSlice() 
  {  
    return _results[];    
  } 
  
  /**
    Returns a range of results in ascending order (the "lowest" result is the actual best).
  */  
  auto range() {
  
    return _results[];
    
  }
}