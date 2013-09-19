/**
  This module defines the main structure of concern for this program: the duplication.
*/
module comet.dup;

import comet.sma;
import comet.config;
import comet.algos;

import deimos.bio.dna;
import deimos.containers.tree;

import std.stdio;
import std.container;
import std.algorithm;

/**
  This structure holds summary information regarding a duplication. It holds its start position and the length
  of its period, idenfying it in a unique manner. The data also holds the cost of the duplication as provided by
  the user.
  
  This structure defines the comparison operator to order duplications according to their cost first. If two
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
  //Inclusive boundary.
  @property size_t stop() { return _start + _period - 1; }
  @property size_t period() { return _period; }
  
  /**
    if( rhs.cost - Cost.epsilon <= cost && cost <= rhs.cost + Cost.epsilon )
  */
  int opCmp( Duplication rhs ) {
    if( cost < rhs.cost - Cost.epsilon ) { 
      return -1; 
    } else if( rhs.cost + Cost.epsilon < cost ) {
      return 1;
    }
    //If the cost is equals, then the longer period wins.
    auto cmp = rhs.period - period;
    if( cmp ) { return cmp; }
    //Arbitrary ordering otherwise.
    return start - rhs.start;
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

