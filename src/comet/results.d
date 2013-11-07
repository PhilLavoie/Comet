module comet.results;

import comet.sma;

import std.container;

struct Result {
  size_t start;
  size_t length;
  Cost cost;
  
  this( size_t start, size_t length, Cost cost ) {
    this.start = start;
    this.length = length;
    this.cost = cost;
  }
  
  int opCmp( Result rhs ) {
    if( cost < rhs.cost - Cost.epsilon ) { 
      return -1; 
    } else if( rhs.cost + Cost.epsilon < cost ) {
      return 1;
    }
    //If the cost is equals, then the longer period wins.
    auto cmp = rhs.length - length;
    if( cmp ) { return cmp; }
    //Arbitrary ordering otherwise.
    return start - rhs.start;
  }
}
auto result( size_t start, size_t length, Cost cost ) {
  return Result( start, length, cost );
}



/**
  A wrapper around a fast, ordered index (as of right now, the structure used is a red black tree).
  It keeps track of how many results were inserted so that it does not go beyond a maximum limit.
  When the limit is reached, if the new result to be inserted is better than the worse one held,
  then the latter is popped from the tree and the former is inserted, satisfying the limit.
*/
struct Results {
  private RedBlackTree!( Result ) _results;
  private size_t _max;

  @disable this();
  
  /**
    The number of results is intended to be bounded.
    The parameter provided is that bound (inclusive).
  */
  this( size_t maxResults ) {
    _results = new typeof( _results )();
    _max = maxResults;
  }
  
  /**
    Returns the number of results currently stored.
  */
  @property size_t length() { return _results.length; }
  
  /**
    This function adds the result only if:
      - The maximum number of results has not been reached, or
      - The worst duplication known is worse than the result to be
        inserted. In that case, the worst result is exchanged
        with the provided one.
  */
  void add( Result result ) {
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

  /**
    Returns a range of results in ascending order (the "lowest" result is the actual best).
  */
  auto opSlice() {
    return _results[];
  } 
  /**
    Returns a range of results in ascending order (the "lowest" result is the actual best).
  */  
  auto range() {
    return _results[];
  }
}
