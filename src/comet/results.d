/**
  Module providing facilities for handling results obtained by processing segments
  pairs in the context of state mutation analysis on sequences.
*/
module comet.results;

import std.container: RedBlackTree;
import std.range    : isInputRange, ElementType;
import std.traits   : isInstanceOf, hasMember;

import comet.typedefs;
import comet.sma: Result, isResult;

/**
  A wrapper around a fast, ordered index (as of right now, the structure used is a red black tree).
  It keeps track of how many results were inserted so that it does not go beyond a maximum limit.
  When the limit is reached, if the new result to be inserted is better than the worse one held,
  then the latter is popped from the tree and the former is inserted, satisfying the limit.
*/
struct Results(R) if(isResult!R) 
{
  private RedBlackTree!( R ) _results;
  private size_t _max; 
  
  /**
    The number of results is intended to be bounded.
  */
  this(NoResults maxResults) 
  {  
    _results = new typeof(_results)();
    _max = maxResults;    
  }
  
  /**
    Returns the number of results currently stored.
  */
  @property size_t length() {return _results.length;}
  
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
  alias range = opSlice;  
}